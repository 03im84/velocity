from __future__ import annotations

import fnmatch
import json
import locale
import os
import queue
import re
import subprocess
import sys
import threading
import time
import tkinter as tk

from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Any

from velocity_test_dashboard_logic import (
    infer_suite,
    ordered_suites,
    parse_runner_metrics,
)


APP_NAME = "Velocity Test Dashboard"
APP_VERSION = "0.4.0"
PHASE_LABEL = "Phase 4 — Metrics and Automatic Suites"

SHARED_CONFIG_NAME = "test_dashboard.json"
LOCAL_CONFIG_NAME = "test_dashboard.local.json"

POLL_INTERVAL_MS = 50


DEFAULT_SHARED_CONFIG: dict[str, Any] = {
    "project_root": "../..",
    "runner": "test/tools/run_godot_tests.ps1",
    "test_roots": ["test/core"],
    "include_patterns": ["*Test.tscn", "*_test.tscn"],
    "exclude_patterns": [
        "test/infrastructure",
        "device_bus_failure_isolation_test.tscn",
    ],
    "default_timeout_seconds": 10,
    "default_repeat": 1,
    "automatic_suites": True,
    "suite_aliases": {
        "device_bus": "DeviceBus",
        "device_core": "DeviceCore",
        "device": "DeviceCore",
        "provider": "Providers",
        "profile": "Profiles",
        "message_contract": "Message Contracts",
        "device_graph": "DeviceGraph",
        "composition": "Composition",
        "catalog": "DeviceCatalog",
        "runtime": "Runtime",
        "debug": "Debug",
    },
    "suite_order": [
        "DeviceBus",
        "DeviceCore",
        "Providers",
        "Profiles",
        "Message Contracts",
        "DeviceGraph",
        "Composition",
        "DeviceCatalog",
        "Runtime",
        "Debug",
    ],
    "suite_overrides": {},
}


DEFAULT_LOCAL_CONFIG: dict[str, Any] = {
    "godot_console": "",
    "window_geometry": "1440x900",
    "last_selected_test": "",
    "last_suite": "All",
    "repeat": 1,
    "timeout_seconds": 10,
    "auto_scroll": True,
}


@dataclass(frozen=True, slots=True)
class TestScene:
    name: str
    resource_path: str
    filesystem_path: Path
    relative_path: str
    suite: str


@dataclass(slots=True)
class PlanResult:
    test: TestScene
    status: str = "PENDING"
    exit_code: int | None = None
    total_runs: int = 0
    passed: int = 0
    failed: int = 0
    checks: int = 0
    check_failures: int = 0
    metrics_runs: int = 0
    missing_metrics: int = 0
    protocol_errors: int = 0
    duration_seconds: float = 0.0
    output: str = ""

    def reset_for_resume(self) -> None:
        self.status = "PENDING"
        self.exit_code = None
        self.total_runs = 0
        self.passed = 0
        self.failed = 0
        self.checks = 0
        self.check_failures = 0
        self.metrics_runs = 0
        self.missing_metrics = 0
        self.protocol_errors = 0
        self.duration_seconds = 0.0
        self.output = ""


def read_json_file(
    path: Path,
    default_value: dict[str, Any],
) -> dict[str, Any]:
    if not path.exists():
        return dict(default_value)

    try:
        with path.open("r", encoding="utf-8") as handle:
            loaded = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(
            f"Could not read JSON file:\n{path}\n\n{error}"
        ) from error

    if not isinstance(loaded, dict):
        raise ValueError(f"JSON root must be an object:\n{path}")

    merged = dict(default_value)
    merged.update(loaded)
    return merged


def write_json_file(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_suffix(path.suffix + ".tmp")

    with temporary_path.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    temporary_path.replace(path)


class VelocityTestDashboard:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.tools_directory = Path(__file__).resolve().parent
        self.shared_config_path = self.tools_directory / SHARED_CONFIG_NAME
        self.local_config_path = self.tools_directory / LOCAL_CONFIG_NAME

        self.shared_config: dict[str, Any] = {}
        self.local_config: dict[str, Any] = {}

        self.project_root = Path()
        self.runner_path = Path()
        self.godot_console: Path | None = None

        self.tests: list[TestScene] = []
        self.filtered_tests: list[TestScene] = []
        self.test_tree_items: dict[str, TestScene] = {}
        self.result_tree_items: dict[int, str] = {}

        self.execution_plan: list[PlanResult] = []
        self.current_plan_index = -1
        self.plan_label = ""
        self.plan_repeat = 1
        self.plan_timeout = 10

        self.current_test_output: list[str] = []
        self.complete_output: list[str] = []
        self.event_queue: queue.Queue[tuple[str, Any]] = queue.Queue()

        self.process: subprocess.Popen[str] | None = None
        self.process_lock = threading.Lock()
        self.worker_thread: threading.Thread | None = None

        self.running = False
        self.pause_requested = False
        self.stop_requested = False
        self.pending_close = False
        self.current_test_started_at = 0.0

        self.search_var = tk.StringVar()
        self.suite_var = tk.StringVar(value="All")
        self.repeat_var = tk.IntVar(value=1)
        self.timeout_var = tk.IntVar(value=10)
        self.auto_scroll_var = tk.BooleanVar(value=True)

        self.selected_name_var = tk.StringVar(value="No test selected")
        self.selected_resource_var = tk.StringVar()
        self.selected_suite_var = tk.StringVar()
        self.config_status_var = tk.StringVar()
        self.execution_status_var = tk.StringVar(value="IDLE")
        self.summary_var = tk.StringVar(value="No execution plan.")
        self.test_count_var = tk.StringVar(value="Tests: 0")
        self.status_bar_var = tk.StringVar(value="Starting...")

        self._configure_window()
        self._configure_styles()
        self._build_interface()
        self._load_configuration()
        self._apply_configuration()
        self.refresh_tests()

        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        self.root.after(POLL_INTERVAL_MS, self._poll_events)

    # ============================================================
    # WINDOW AND STYLES
    # ============================================================

    def _configure_window(self) -> None:
        self.root.title(f"{APP_NAME} {APP_VERSION}")
        self.root.minsize(1280, 760)

    def _configure_styles(self) -> None:
        style = ttk.Style(self.root)

        if "clam" in style.theme_names():
            style.theme_use("clam")

        style.configure("Title.TLabel", font=("Segoe UI", 16, "bold"))
        style.configure("Section.TLabel", font=("Segoe UI", 10, "bold"))
        style.configure("Status.TLabel", font=("Segoe UI", 11, "bold"))

        self.status_colors = {
            "IDLE": "#666666",
            "RUNNING": "#1565c0",
            "PAUSE_REQUESTED": "#795548",
            "PAUSED": "#6a1b9a",
            "PASS": "#16833f",
            "FAIL": "#b3261e",
            "TIMEOUT": "#a15c00",
            "ENGINE_ERROR": "#7f0000",
            "STOPPED": "#b05a00",
            "CONFIG_ERROR": "#b3261e",
        }

    # ============================================================
    # UI BUILD
    # ============================================================

    def _build_interface(self) -> None:
        main = ttk.Frame(self.root, padding=10)
        main.pack(fill=tk.BOTH, expand=True)

        self._build_header(main)
        self._build_toolbar(main)

        paned = ttk.Panedwindow(main, orient=tk.HORIZONTAL)
        paned.pack(fill=tk.BOTH, expand=True, pady=(8, 8))

        left = ttk.Frame(paned, padding=6)
        right = ttk.Frame(paned, padding=6)

        paned.add(left, weight=3)
        paned.add(right, weight=5)

        self._build_browser(left)
        self._build_execution_panel(right)
        self._build_status_bar(main)

    def _build_header(self, parent: ttk.Frame) -> None:
        frame = ttk.Frame(parent)
        frame.pack(fill=tk.X)

        ttk.Label(frame, text=APP_NAME, style="Title.TLabel").pack(
            side=tk.LEFT
        )
        ttk.Label(frame, text=PHASE_LABEL).pack(
            side=tk.LEFT,
            padx=(12, 0),
        )

    def _build_toolbar(self, parent: ttk.Frame) -> None:
        frame = ttk.Frame(parent)
        frame.pack(fill=tk.X, pady=(8, 0))

        self.refresh_button = ttk.Button(
            frame,
            text="Refresh Tests",
            command=self.refresh_tests,
        )
        self.refresh_button.pack(side=tk.LEFT)

        self.run_selected_button = ttk.Button(
            frame,
            text="Run Selected",
            command=self.run_selected,
        )
        self.run_selected_button.pack(side=tk.LEFT, padx=(6, 0))

        self.run_suite_button = ttk.Button(
            frame,
            text="Run Suite",
            command=self.run_suite,
        )
        self.run_suite_button.pack(side=tk.LEFT, padx=(6, 0))

        self.run_all_button = ttk.Button(
            frame,
            text="Run All",
            command=self.run_all,
        )
        self.run_all_button.pack(side=tk.LEFT, padx=(6, 0))

        self.pause_resume_button = ttk.Button(
            frame,
            text="Pause",
            command=self.toggle_pause_resume,
            state=tk.DISABLED,
        )
        self.pause_resume_button.pack(side=tk.LEFT, padx=(6, 0))

        self.stop_button = ttk.Button(
            frame,
            text="Stop",
            command=self.stop_execution,
            state=tk.DISABLED,
        )
        self.stop_button.pack(side=tk.LEFT, padx=(6, 0))

        self.select_godot_button = ttk.Button(
            frame,
            text="Select Godot Console",
            command=self.select_godot_console,
        )
        self.select_godot_button.pack(side=tk.LEFT, padx=(6, 0))

        ttk.Button(
            frame,
            text="Clear Output",
            command=self.clear_output,
        ).pack(side=tk.RIGHT)

        ttk.Button(
            frame,
            text="Copy Output",
            command=self.copy_output,
        ).pack(side=tk.RIGHT, padx=(0, 6))

        ttk.Button(
            frame,
            text="Copy Command",
            command=self.copy_command,
        ).pack(side=tk.RIGHT, padx=(0, 6))

    def _build_browser(self, parent: ttk.Frame) -> None:
        ttk.Label(
            parent,
            text="Test Browser",
            style="Section.TLabel",
        ).pack(anchor=tk.W)

        ttk.Label(parent, text="Search").pack(
            anchor=tk.W,
            pady=(8, 2),
        )

        search_entry = ttk.Entry(parent, textvariable=self.search_var)
        search_entry.pack(fill=tk.X)
        search_entry.bind("<KeyRelease>", self._on_filter_changed)

        ttk.Label(parent, text="Suite").pack(
            anchor=tk.W,
            pady=(8, 2),
        )

        self.suite_combo = ttk.Combobox(
            parent,
            textvariable=self.suite_var,
            state="readonly",
        )
        self.suite_combo.pack(fill=tk.X)
        self.suite_combo.bind(
            "<<ComboboxSelected>>",
            self._on_filter_changed,
        )

        tree_frame = ttk.Frame(parent)
        tree_frame.pack(fill=tk.BOTH, expand=True, pady=(8, 0))

        self.test_tree = ttk.Treeview(
            tree_frame,
            columns=("suite", "path"),
            show="tree headings",
            selectmode="browse",
        )
        self.test_tree.heading("#0", text="Test")
        self.test_tree.heading("suite", text="Suite")
        self.test_tree.heading("path", text="Path")
        self.test_tree.column("#0", width=220)
        self.test_tree.column("suite", width=120)
        self.test_tree.column("path", width=340)

        y_scroll = ttk.Scrollbar(
            tree_frame,
            orient=tk.VERTICAL,
            command=self.test_tree.yview,
        )
        x_scroll = ttk.Scrollbar(
            tree_frame,
            orient=tk.HORIZONTAL,
            command=self.test_tree.xview,
        )

        self.test_tree.configure(
            yscrollcommand=y_scroll.set,
            xscrollcommand=x_scroll.set,
        )
        self.test_tree.grid(row=0, column=0, sticky="nsew")
        y_scroll.grid(row=0, column=1, sticky="ns")
        x_scroll.grid(row=1, column=0, sticky="ew")
        tree_frame.rowconfigure(0, weight=1)
        tree_frame.columnconfigure(0, weight=1)

        self.test_tree.bind(
            "<<TreeviewSelect>>",
            self._on_test_selected,
        )

        ttk.Label(parent, textvariable=self.test_count_var).pack(
            anchor=tk.W,
            pady=(5, 0),
        )

    def _build_execution_panel(self, parent: ttk.Frame) -> None:
        selected_frame = ttk.LabelFrame(
            parent,
            text="Selected Test",
            padding=6,
        )
        selected_frame.pack(fill=tk.X)

        self._add_row(selected_frame, "Name", self.selected_name_var, 0)
        self._add_row(selected_frame, "Suite", self.selected_suite_var, 1)
        self._add_row(
            selected_frame,
            "Resource",
            self.selected_resource_var,
            2,
        )

        controls = ttk.LabelFrame(parent, text="Execution", padding=6)
        controls.pack(fill=tk.X, pady=(6, 0))

        ttk.Label(controls, text="Repeat").grid(
            row=0,
            column=0,
            sticky=tk.W,
        )
        self.repeat_spinbox = ttk.Spinbox(
            controls,
            from_=1,
            to=100,
            textvariable=self.repeat_var,
            width=7,
        )
        self.repeat_spinbox.grid(row=0, column=1, padx=(5, 18))

        ttk.Label(controls, text="Timeout").grid(
            row=0,
            column=2,
            sticky=tk.W,
        )
        self.timeout_spinbox = ttk.Spinbox(
            controls,
            from_=1,
            to=3600,
            textvariable=self.timeout_var,
            width=7,
        )
        self.timeout_spinbox.grid(row=0, column=3, padx=(5, 18))

        ttk.Checkbutton(
            controls,
            text="Auto-scroll",
            variable=self.auto_scroll_var,
        ).grid(row=0, column=4, sticky=tk.W)

        result_frame = ttk.LabelFrame(
            parent,
            text="Execution Plan",
            padding=6,
        )
        result_frame.pack(fill=tk.X, pady=(6, 0))

        status_row = ttk.Frame(result_frame)
        status_row.pack(fill=tk.X)

        self.execution_status_label = ttk.Label(
            status_row,
            textvariable=self.execution_status_var,
            style="Status.TLabel",
        )
        self.execution_status_label.pack(side=tk.LEFT)

        ttk.Label(
            status_row,
            textvariable=self.summary_var,
            wraplength=860,
        ).pack(side=tk.LEFT, padx=(16, 0))

        result_tree_frame = ttk.Frame(result_frame)
        result_tree_frame.pack(fill=tk.X, pady=(6, 0))

        self.result_tree = ttk.Treeview(
            result_tree_frame,
            columns=(
                "status",
                "exit",
                "runs",
                "checks",
                "check_failures",
                "metrics",
                "duration",
            ),
            show="tree headings",
            height=8,
        )

        headings = {
            "#0": "Test",
            "status": "Status",
            "exit": "Exit",
            "runs": "Runs",
            "checks": "Checks",
            "check_failures": "Check Failures",
            "metrics": "Metrics",
            "duration": "Seconds",
        }
        for column, text in headings.items():
            self.result_tree.heading(column, text=text)

        self.result_tree.column("#0", width=260)
        self.result_tree.column("status", width=100)
        self.result_tree.column("exit", width=55)
        self.result_tree.column("runs", width=55)
        self.result_tree.column("checks", width=70)
        self.result_tree.column("check_failures", width=100)
        self.result_tree.column("metrics", width=90)
        self.result_tree.column("duration", width=75)

        result_y = ttk.Scrollbar(
            result_tree_frame,
            orient=tk.VERTICAL,
            command=self.result_tree.yview,
        )
        result_x = ttk.Scrollbar(
            result_tree_frame,
            orient=tk.HORIZONTAL,
            command=self.result_tree.xview,
        )

        self.result_tree.configure(
            yscrollcommand=result_y.set,
            xscrollcommand=result_x.set,
        )
        self.result_tree.grid(row=0, column=0, sticky="ew")
        result_y.grid(row=0, column=1, sticky="ns")
        result_x.grid(row=1, column=0, sticky="ew")
        result_tree_frame.columnconfigure(0, weight=1)

        for status, color in self.status_colors.items():
            self.result_tree.tag_configure(status, foreground=color)
        self.result_tree.tag_configure("PENDING", foreground="#666666")
        self.result_tree.tag_configure("NOT_RUN", foreground="#777777")

        config_frame = ttk.LabelFrame(
            parent,
            text="Configuration",
            padding=6,
        )
        config_frame.pack(fill=tk.X, pady=(6, 0))
        ttk.Label(
            config_frame,
            textvariable=self.config_status_var,
            wraplength=900,
        ).pack(anchor=tk.W)

        output_frame = ttk.LabelFrame(
            parent,
            text="Output",
            padding=5,
        )
        output_frame.pack(fill=tk.BOTH, expand=True, pady=(6, 0))

        self.output_text = tk.Text(
            output_frame,
            wrap=tk.NONE,
            font=("Consolas", 10),
            background="#111111",
            foreground="#e8e8e8",
            insertbackground="#ffffff",
            state=tk.DISABLED,
        )
        output_y = ttk.Scrollbar(
            output_frame,
            orient=tk.VERTICAL,
            command=self.output_text.yview,
        )
        output_x = ttk.Scrollbar(
            output_frame,
            orient=tk.HORIZONTAL,
            command=self.output_text.xview,
        )
        self.output_text.configure(
            yscrollcommand=output_y.set,
            xscrollcommand=output_x.set,
        )
        self.output_text.grid(row=0, column=0, sticky="nsew")
        output_y.grid(row=0, column=1, sticky="ns")
        output_x.grid(row=1, column=0, sticky="ew")
        output_frame.rowconfigure(0, weight=1)
        output_frame.columnconfigure(0, weight=1)

    def _add_row(
        self,
        parent: ttk.LabelFrame,
        label_text: str,
        variable: tk.StringVar,
        row: int,
    ) -> None:
        ttk.Label(
            parent,
            text=f"{label_text}:",
            style="Section.TLabel",
        ).grid(
            row=row,
            column=0,
            sticky=tk.NW,
            padx=(0, 8),
            pady=2,
        )
        ttk.Label(
            parent,
            textvariable=variable,
            wraplength=820,
        ).grid(row=row, column=1, sticky=tk.NW, pady=2)
        parent.columnconfigure(1, weight=1)

    def _build_status_bar(self, parent: ttk.Frame) -> None:
        ttk.Separator(parent, orient=tk.HORIZONTAL).pack(fill=tk.X)
        frame = ttk.Frame(parent, padding=(0, 5, 0, 0))
        frame.pack(fill=tk.X)
        ttk.Label(frame, textvariable=self.status_bar_var).pack(
            side=tk.LEFT
        )
        ttk.Label(frame, text=f"v{APP_VERSION}").pack(side=tk.RIGHT)

    # ============================================================
    # CONFIGURATION
    # ============================================================

    def _load_configuration(self) -> None:
        try:
            self.shared_config = read_json_file(
                self.shared_config_path,
                DEFAULT_SHARED_CONFIG,
            )
            self.local_config = read_json_file(
                self.local_config_path,
                DEFAULT_LOCAL_CONFIG,
            )
        except ValueError as error:
            messagebox.showerror(
                "Configuration Error",
                str(error),
                parent=self.root,
            )
            self.shared_config = dict(DEFAULT_SHARED_CONFIG)
            self.local_config = dict(DEFAULT_LOCAL_CONFIG)

    def _apply_configuration(self) -> None:
        project_root_text = str(
            self.shared_config.get("project_root", "../..")
        )
        self.project_root = (
            self.tools_directory / project_root_text
        ).resolve()

        runner_text = str(
            self.shared_config.get(
                "runner",
                "test/tools/run_godot_tests.ps1",
            )
        )
        self.runner_path = (self.project_root / runner_text).resolve()

        environment_godot = os.environ.get(
            "GODOT_CONSOLE",
            "",
        ).strip()
        local_godot = str(
            self.local_config.get("godot_console", "")
        ).strip()
        godot_text = environment_godot or local_godot

        self.godot_console = (
            Path(godot_text).expanduser().resolve()
            if godot_text
            else None
        )

        geometry = str(
            self.local_config.get("window_geometry", "1440x900")
        )
        try:
            self.root.geometry(geometry)
        except tk.TclError:
            self.root.geometry("1440x900")

        self.repeat_var.set(
            self._clamp_int(
                self.local_config.get(
                    "repeat",
                    self.shared_config.get("default_repeat", 1),
                ),
                1,
                100,
                1,
            )
        )
        self.timeout_var.set(
            self._clamp_int(
                self.local_config.get(
                    "timeout_seconds",
                    self.shared_config.get(
                        "default_timeout_seconds",
                        10,
                    ),
                ),
                1,
                3600,
                10,
            )
        )
        self.auto_scroll_var.set(
            bool(self.local_config.get("auto_scroll", True))
        )
        self.suite_var.set(
            str(self.local_config.get("last_suite", "All"))
        )
        self._update_config_status()

    @staticmethod
    def _clamp_int(
        value: Any,
        minimum: int,
        maximum: int,
        default: int,
    ) -> int:
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return default
        return max(minimum, min(maximum, parsed))

    def _valid_godot_console(self) -> bool:
        return bool(
            self.godot_console
            and self.godot_console.is_file()
            and self.godot_console.suffix.lower() == ".exe"
        )

    def _configuration_valid(self) -> bool:
        return (
            (self.project_root / "project.godot").is_file()
            and self.runner_path.is_file()
            and self._valid_godot_console()
        )

    def _update_config_status(self) -> None:
        project_ok = (self.project_root / "project.godot").is_file()
        runner_ok = self.runner_path.is_file()
        godot_ok = self._valid_godot_console()

        self.config_status_var.set(
            " | ".join(
                [
                    f"Project: {'OK' if project_ok else 'ERROR'}",
                    f"Runner: {'OK' if runner_ok else 'ERROR'}",
                    f"Godot: {'OK' if godot_ok else 'ERROR'}",
                ]
            )
        )
        self._update_button_states()

    def select_godot_console(self) -> None:
        if self.running:
            return

        selected = filedialog.askopenfilename(
            parent=self.root,
            title="Select Godot Console",
            filetypes=[
                ("Executable", "*.exe"),
                ("All files", "*.*"),
            ],
        )
        if not selected:
            return

        selected_path = Path(selected).resolve()
        if not selected_path.is_file():
            messagebox.showerror(
                "Invalid Godot Console",
                "The selected file does not exist.",
                parent=self.root,
            )
            return

        self.godot_console = selected_path
        self.local_config["godot_console"] = str(selected_path)
        self._save_local_configuration()
        self._update_config_status()

    # ============================================================
    # DISCOVERY AND SUITES
    # ============================================================

    def refresh_tests(self) -> None:
        if self.running:
            return

        selected = self._selected_test()
        previous_path = (
            selected.resource_path
            if selected
            else str(
                self.local_config.get("last_selected_test", "")
            )
        )

        try:
            self.shared_config = read_json_file(
                self.shared_config_path,
                DEFAULT_SHARED_CONFIG,
            )
            self.tests = self._discover_tests()
            self._refresh_suite_values()
            self._apply_filters(previous_path)
            self.status_bar_var.set(
                f"Discovered {len(self.tests)} tests."
            )
        except Exception as error:
            self.tests = []
            self.filtered_tests = []
            self._rebuild_test_tree()
            messagebox.showerror(
                "Discovery Error",
                str(error),
                parent=self.root,
            )

        self._update_button_states()

    def _discover_tests(self) -> list[TestScene]:
        discovered: dict[str, TestScene] = {}
        roots = self._string_list("test_roots", ["test/core"])
        includes = self._string_list(
            "include_patterns",
            ["*Test.tscn", "*_test.tscn"],
        )
        excludes = self._string_list("exclude_patterns", [])
        aliases = self._string_mapping("suite_aliases")
        overrides = self._string_mapping("suite_overrides")
        automatic_suites = bool(
            self.shared_config.get("automatic_suites", True)
        )

        for root_text in roots:
            test_root = (self.project_root / root_text).resolve()
            if not test_root.is_dir():
                continue

            for scene_path in test_root.rglob("*.tscn"):
                relative = scene_path.relative_to(
                    self.project_root
                ).as_posix()

                if not self._included(scene_path.name, includes):
                    continue
                if self._excluded(relative, excludes):
                    continue

                if automatic_suites:
                    suite = infer_suite(
                        relative,
                        roots,
                        aliases,
                        overrides,
                        scene_path.stem,
                    )
                else:
                    suite = self._legacy_suite_for(relative)

                resource = f"res://{relative}"
                discovered[resource] = TestScene(
                    name=scene_path.stem,
                    resource_path=resource,
                    filesystem_path=scene_path.resolve(),
                    relative_path=relative,
                    suite=suite,
                )

        return sorted(
            discovered.values(),
            key=lambda item: (
                item.suite.lower(),
                item.name.lower(),
                item.resource_path.lower(),
            ),
        )

    def _string_list(
        self,
        key: str,
        default: list[str],
    ) -> list[str]:
        value = self.shared_config.get(key, default)
        if not isinstance(value, list):
            return list(default)
        return [str(item) for item in value]

    def _string_mapping(self, key: str) -> dict[str, str]:
        value = self.shared_config.get(key, {})
        if not isinstance(value, dict):
            return {}
        return {
            str(item_key): str(item_value)
            for item_key, item_value in value.items()
        }

    @staticmethod
    def _included(name: str, patterns: list[str]) -> bool:
        lower_name = name.lower()
        return any(
            fnmatch.fnmatchcase(lower_name, pattern.lower())
            for pattern in patterns
        )

    @staticmethod
    def _excluded(relative: str, patterns: list[str]) -> bool:
        normalized = relative.replace("\\", "/").lower()
        for pattern in patterns:
            candidate = pattern.replace("\\", "/").lower()
            if candidate in normalized:
                return True
            if fnmatch.fnmatchcase(normalized, candidate):
                return True
        return False

    def _legacy_suite_for(self, relative: str) -> str:
        normalized = relative.replace("\\", "/").lower()
        suites = self.shared_config.get("suites", {})
        if not isinstance(suites, dict):
            return "Other"

        for suite_name, roots in suites.items():
            if str(suite_name) == "All" or not isinstance(roots, list):
                continue
            for root_text in roots:
                suite_root = str(root_text).replace(
                    "\\",
                    "/",
                ).strip("/").lower()
                if normalized.startswith(suite_root + "/"):
                    return str(suite_name)
        return "Other"

    def _refresh_suite_values(self) -> None:
        discovered = [item.suite for item in self.tests]
        configured_order = self._string_list("suite_order", [])
        values = ordered_suites(discovered, configured_order)
        self.suite_combo.configure(values=values)

        if self.suite_var.get() not in values:
            self.suite_var.set("All")

    # ============================================================
    # FILTERING AND SELECTION
    # ============================================================

    def _on_filter_changed(
        self,
        _event: object | None = None,
    ) -> None:
        self._apply_filters()

    def _apply_filters(self, preferred_path: str = "") -> None:
        search = self.search_var.get().strip().lower()
        suite = self.suite_var.get() or "All"
        filtered: list[TestScene] = []

        for test in self.tests:
            if suite != "All" and test.suite != suite:
                continue
            searchable = " ".join(
                [test.name, test.resource_path, test.suite]
            ).lower()
            if search and search not in searchable:
                continue
            filtered.append(test)

        self.filtered_tests = filtered
        self._rebuild_test_tree(preferred_path)

    def _rebuild_test_tree(self, preferred_path: str = "") -> None:
        for item_id in self.test_tree.get_children():
            self.test_tree.delete(item_id)
        self.test_tree_items.clear()

        counts: dict[str, int] = {}
        for test in self.filtered_tests:
            key = test.name.lower()
            counts[key] = counts.get(key, 0) + 1

        preferred_item = ""
        for test in self.filtered_tests:
            display = test.name
            if counts[test.name.lower()] > 1:
                display = f"{test.name} — {test.relative_path}"

            item_id = self.test_tree.insert(
                "",
                tk.END,
                text=display,
                values=(test.suite, test.relative_path),
            )
            self.test_tree_items[item_id] = test
            if test.resource_path == preferred_path:
                preferred_item = item_id

        self.test_count_var.set(
            f"Visible: {len(self.filtered_tests)} / "
            f"Total: {len(self.tests)}"
        )

        target_item = preferred_item
        if not target_item:
            children = self.test_tree.get_children()
            if children:
                target_item = children[0]

        if target_item:
            self.test_tree.selection_set(target_item)
            self.test_tree.focus(target_item)
            self.test_tree.see(target_item)
            self._update_selected_details()
        else:
            self._clear_selected_details()

        self._update_button_states()

    def _on_test_selected(
        self,
        _event: object | None = None,
    ) -> None:
        self._update_selected_details()

    def _selected_test(self) -> TestScene | None:
        selected_ids = self.test_tree.selection()
        if not selected_ids:
            return None
        return self.test_tree_items.get(selected_ids[0])

    def _update_selected_details(self) -> None:
        selected = self._selected_test()
        if selected is None:
            self._clear_selected_details()
            return

        self.selected_name_var.set(selected.name)
        self.selected_suite_var.set(selected.suite)
        self.selected_resource_var.set(selected.resource_path)
        self.local_config["last_selected_test"] = selected.resource_path
        self._update_button_states()

    def _clear_selected_details(self) -> None:
        self.selected_name_var.set("No test selected")
        self.selected_suite_var.set("")
        self.selected_resource_var.set("")
        self._update_button_states()

    # ============================================================
    # COMMANDS
    # ============================================================

    def _repeat(self) -> int:
        value = int(self.repeat_var.get())
        if value < 1 or value > 100:
            raise ValueError("Repeat must be between 1 and 100.")
        return value

    def _timeout(self) -> int:
        value = int(self.timeout_var.get())
        if value < 1 or value > 3600:
            raise ValueError("Timeout must be between 1 and 3600.")
        return value

    def _command_for(
        self,
        test: TestScene,
        repeat: int,
        timeout: int,
    ) -> list[str]:
        if not self._configuration_valid():
            raise ValueError(
                "Project, runner, or Godot Console "
                "configuration is invalid."
            )

        assert self.godot_console is not None

        return [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(self.runner_path),
            "-GodotPath",
            str(self.godot_console),
            "-Scene",
            test.resource_path,
            "-Repeat",
            str(repeat),
            "-TimeoutSeconds",
            str(timeout),
        ]

    def copy_command(self) -> None:
        selected = self._selected_test()
        if selected is None:
            self.status_bar_var.set("No test selected.")
            return

        try:
            command = self._command_for(
                selected,
                self._repeat(),
                self._timeout(),
            )
        except (ValueError, tk.TclError) as error:
            messagebox.showerror(
                "Command Error",
                str(error),
                parent=self.root,
            )
            return

        self.root.clipboard_clear()
        self.root.clipboard_append(subprocess.list2cmdline(command))
        self.status_bar_var.set("Command copied.")

    # ============================================================
    # PLAN CREATION
    # ============================================================

    def run_selected(self) -> None:
        selected = self._selected_test()
        if selected is None:
            return
        self._start_new_plan(
            [selected],
            f"Selected: {selected.name}",
        )

    def run_suite(self) -> None:
        if self.running:
            return
        self.refresh_tests()
        suite = self.suite_var.get() or "All"
        plan_tests = (
            list(self.tests)
            if suite == "All"
            else [test for test in self.tests if test.suite == suite]
        )
        self._start_new_plan(plan_tests, f"Suite: {suite}")

    def run_all(self) -> None:
        if self.running:
            return
        self.refresh_tests()
        self._start_new_plan(list(self.tests), "All Tests")

    def _start_new_plan(
        self,
        tests: list[TestScene],
        label: str,
    ) -> None:
        if self.running:
            return

        if self._has_resumable_plan():
            discard = messagebox.askyesno(
                "Paused Plan",
                "A paused or stopped plan exists.\n\n"
                "Discard it and start a new plan?",
                parent=self.root,
            )
            if not discard:
                return

        if not tests:
            messagebox.showwarning(
                "Empty Execution Plan",
                "No tests were selected.",
                parent=self.root,
            )
            return

        try:
            self.plan_repeat = self._repeat()
            self.plan_timeout = self._timeout()
            if not self._configuration_valid():
                raise ValueError(
                    "Project, runner, or Godot configuration is invalid."
                )
        except (ValueError, tk.TclError) as error:
            messagebox.showerror(
                "Cannot Start Plan",
                str(error),
                parent=self.root,
            )
            return

        self.execution_plan = [PlanResult(test=test) for test in tests]
        self.current_plan_index = 0
        self.plan_label = label
        self.pause_requested = False
        self.stop_requested = False
        self.pending_close = False
        self.running = True
        self.complete_output.clear()
        self.current_test_output.clear()

        self.clear_output()
        self._rebuild_result_tree()
        self.execution_status_var.set("RUNNING")
        self._set_status_color("RUNNING")
        self.summary_var.set(f"{label} | Planned: {len(tests)}")
        self.status_bar_var.set("Execution plan started.")
        self._update_button_states()
        self.root.after(10, self._start_current_plan_item)

    # ============================================================
    # PAUSE AND RESUME
    # ============================================================

    def toggle_pause_resume(self) -> None:
        if self.running:
            if self.pause_requested:
                return
            self.pause_requested = True
            self.execution_status_var.set("PAUSE_REQUESTED")
            self._set_status_color("PAUSE_REQUESTED")
            self.status_bar_var.set(
                "Plan will pause after current test."
            )
            self._update_button_states()
            return

        if self._has_resumable_plan():
            self._resume_plan()

    def _has_resumable_plan(self) -> bool:
        return any(
            result.status in ("STOPPED", "NOT_RUN")
            for result in self.execution_plan
        )

    def _resume_plan(self) -> None:
        if self.running:
            return

        resumable_indices: list[int] = []
        for index, result in enumerate(self.execution_plan):
            if result.status in ("STOPPED", "NOT_RUN"):
                result.reset_for_resume()
                resumable_indices.append(index)
                self._update_result_row(index)

        if not resumable_indices:
            return

        self.current_plan_index = resumable_indices[0]
        self.pause_requested = False
        self.stop_requested = False
        self.pending_close = False
        self.running = True
        self.execution_status_var.set("RUNNING")
        self._set_status_color("RUNNING")

        resume_header = (
            "\n============================================================\n"
            "DASHBOARD PLAN RESUMED\n"
            f"Next test: "
            f"{self.execution_plan[self.current_plan_index].test.name}\n"
            "============================================================\n"
        )
        self._append_output(resume_header)
        self.status_bar_var.set("Execution plan resumed.")
        self._update_live_summary()
        self._update_button_states()
        self.root.after(10, self._start_current_plan_item)

    # ============================================================
    # PLAN EXECUTION
    # ============================================================

    def _start_current_plan_item(self) -> None:
        if self.stop_requested:
            self._mark_remaining_not_run()
            self._finish_plan("STOPPED")
            return

        if self.current_plan_index >= len(self.execution_plan):
            self._finish_plan()
            return

        result = self.execution_plan[self.current_plan_index]
        result.status = "RUNNING"
        self._update_result_row(self.current_plan_index)
        self.current_test_output.clear()
        self.current_test_started_at = time.monotonic()

        header = (
            "\n============================================================\n"
            f"DASHBOARD TEST {self.current_plan_index + 1} / "
            f"{len(self.execution_plan)}\n"
            f"{result.test.name}\n"
            f"{result.test.resource_path}\n"
            "============================================================\n"
        )
        self._append_output(header)

        try:
            command = self._command_for(
                result.test,
                self.plan_repeat,
                self.plan_timeout,
            )
        except ValueError as error:
            result.status = "CONFIG_ERROR"
            result.exit_code = 1
            result.output = str(error)
            self._append_output(f"DASHBOARD ERROR: {error}\n")
            self._update_result_row(self.current_plan_index)
            self.current_plan_index += 1
            self.root.after(10, self._start_current_plan_item)
            return

        self.worker_thread = threading.Thread(
            target=self._worker,
            args=(command,),
            daemon=True,
        )
        self.worker_thread.start()

    def _worker(self, command: list[str]) -> None:
        encoding = locale.getpreferredencoding(False)
        creation_flags = 0
        startup_info = None

        if os.name == "nt":
            creation_flags = getattr(
                subprocess,
                "CREATE_NO_WINDOW",
                0,
            )
            startup_info = subprocess.STARTUPINFO()
            startup_info.dwFlags |= getattr(
                subprocess,
                "STARTF_USESHOWWINDOW",
                0,
            )
            startup_info.wShowWindow = getattr(
                subprocess,
                "SW_HIDE",
                0,
            )

        try:
            process = subprocess.Popen(
                command,
                cwd=self.project_root,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding=encoding,
                errors="replace",
                bufsize=1,
                shell=False,
                creationflags=creation_flags,
                startupinfo=startup_info,
            )
            with self.process_lock:
                self.process = process

            assert process.stdout is not None
            for line in process.stdout:
                self.event_queue.put(("line", line))

            exit_code = process.wait()
            self.event_queue.put(("finished", exit_code))
        except Exception as error:
            self.event_queue.put(("worker_error", str(error)))

    def _poll_events(self) -> None:
        try:
            while True:
                event_type, value = self.event_queue.get_nowait()
                if event_type == "line":
                    self._append_output(
                        str(value),
                        capture_for_current=True,
                    )
                elif event_type == "finished":
                    self._complete_current_test(int(value))
                elif event_type == "worker_error":
                    self._fail_current_test(str(value))
        except queue.Empty:
            pass

        self.root.after(POLL_INTERVAL_MS, self._poll_events)

    def _complete_current_test(self, exit_code: int) -> None:
        with self.process_lock:
            self.process = None

        if self.current_plan_index >= len(self.execution_plan):
            return

        result = self.execution_plan[self.current_plan_index]
        result.exit_code = exit_code
        result.duration_seconds = (
            time.monotonic() - self.current_test_started_at
        )
        result.output = "".join(self.current_test_output)

        if self.stop_requested:
            result.status = "STOPPED"
        else:
            result.status = self._status_from_output(
                exit_code,
                result.output,
            )

        runner_summary = self._parse_runner_summary(result.output)
        result.total_runs = runner_summary.get("total_runs", 0)
        result.passed = runner_summary.get("passed", 0)
        result.failed = runner_summary.get("failed", 0)

        metrics = parse_runner_metrics(
            result.output,
            expected_attempts=self.plan_repeat,
            expected_scene=result.test.resource_path,
        )
        result.checks = metrics.checks
        result.check_failures = metrics.check_failures
        result.metrics_runs = metrics.metrics_runs
        result.missing_metrics = metrics.missing_metrics
        result.protocol_errors = metrics.protocol_errors

        self._update_result_row(self.current_plan_index)
        self.current_plan_index += 1
        self._update_live_summary()

        if self.stop_requested:
            self._mark_remaining_not_run()
            self._finish_plan("STOPPED")
            return

        if (
            self.pause_requested
            and self.current_plan_index < len(self.execution_plan)
        ):
            self.pause_requested = False
            self._mark_remaining_not_run()
            self._finish_plan("PAUSED")
            return

        if self.current_plan_index >= len(self.execution_plan):
            self.pause_requested = False
            self._finish_plan()
            return

        self.root.after(80, self._start_current_plan_item)

    def _fail_current_test(self, error_message: str) -> None:
        with self.process_lock:
            self.process = None

        if self.current_plan_index >= len(self.execution_plan):
            return

        result = self.execution_plan[self.current_plan_index]
        result.status = "CONFIG_ERROR"
        result.exit_code = 1
        result.output = error_message
        result.duration_seconds = (
            time.monotonic() - self.current_test_started_at
        )

        self._append_output(f"\nDASHBOARD ERROR:\n{error_message}\n")
        self._update_result_row(self.current_plan_index)
        self.current_plan_index += 1
        self._update_live_summary()

        if self.stop_requested:
            self._mark_remaining_not_run()
            self._finish_plan("STOPPED")
            return

        if (
            self.pause_requested
            and self.current_plan_index < len(self.execution_plan)
        ):
            self.pause_requested = False
            self._mark_remaining_not_run()
            self._finish_plan("PAUSED")
            return

        self.root.after(80, self._start_current_plan_item)

    # ============================================================
    # RESULT PARSING
    # ============================================================

    @staticmethod
    def _status_from_output(exit_code: int, output: str) -> str:
        if exit_code == 0:
            return "PASS"
        if "TIMEOUT" in output or "ExitCode 124" in output:
            return "TIMEOUT"
        if "ENGINE_ERROR" in output or "ExitCode 126" in output:
            return "ENGINE_ERROR"
        return "FAIL"

    @staticmethod
    def _parse_runner_summary(output: str) -> dict[str, int]:
        result: dict[str, int] = {}
        patterns = {
            "total_runs": r"Total runs:\s+(\d+)",
            "passed": r"Passed:\s+(\d+)",
            "failed": r"Failed:\s+(\d+)",
        }
        for key, pattern in patterns.items():
            matches = re.findall(pattern, output, flags=re.IGNORECASE)
            if matches:
                result[key] = int(matches[-1])
        return result

    # ============================================================
    # RESULT TREE AND SUMMARY
    # ============================================================

    def _rebuild_result_tree(self) -> None:
        for item_id in self.result_tree.get_children():
            self.result_tree.delete(item_id)
        self.result_tree_items.clear()

        for index, result in enumerate(self.execution_plan):
            item_id = self.result_tree.insert(
                "",
                tk.END,
                text=result.test.name,
                values=(
                    result.status,
                    "",
                    "",
                    "",
                    "",
                    "—",
                    "",
                ),
                tags=(result.status,),
            )
            self.result_tree_items[index] = item_id

    def _update_result_row(self, index: int) -> None:
        item_id = self.result_tree_items.get(index)
        if not item_id:
            return

        result = self.execution_plan[index]
        pending = result.status in ("PENDING", "RUNNING")
        exit_text = "" if result.exit_code is None else str(result.exit_code)
        runs_text = "" if result.total_runs == 0 else str(result.total_runs)
        checks_text = "" if pending or result.metrics_runs == 0 else str(result.checks)
        failures_text = (
            ""
            if pending or result.metrics_runs == 0
            else str(result.check_failures)
        )
        metrics_text = self._metrics_text(result)
        duration_text = (
            ""
            if result.duration_seconds == 0.0
            else f"{result.duration_seconds:.2f}"
        )

        self.result_tree.item(
            item_id,
            values=(
                result.status,
                exit_text,
                runs_text,
                checks_text,
                failures_text,
                metrics_text,
                duration_text,
            ),
            tags=(result.status,),
        )
        self.result_tree.see(item_id)

    @staticmethod
    def _metrics_text(result: PlanResult) -> str:
        if result.status in ("PENDING", "RUNNING", "NOT_RUN"):
            return "—"
        if result.protocol_errors > 0:
            return f"Error {result.protocol_errors}"
        if result.missing_metrics > 0:
            return f"Missing {result.missing_metrics}"
        if result.metrics_runs > 0:
            return "OK"
        return "—"

    def _completed_results(self) -> list[PlanResult]:
        return [
            result
            for result in self.execution_plan
            if result.status not in ("PENDING", "RUNNING", "NOT_RUN")
        ]

    def _metrics_totals(
        self,
        results: list[PlanResult],
    ) -> tuple[int, int, int]:
        checks = sum(result.checks for result in results)
        failures = sum(result.check_failures for result in results)
        missing = sum(result.missing_metrics for result in results)
        return checks, failures, missing

    def _update_live_summary(self) -> None:
        completed = self._completed_results()
        passed = sum(result.status == "PASS" for result in completed)
        failed = sum(
            result.status
            in ("FAIL", "TIMEOUT", "ENGINE_ERROR", "CONFIG_ERROR")
            for result in completed
        )
        checks, check_failures, missing = self._metrics_totals(completed)

        self.summary_var.set(
            f"{self.plan_label} | "
            f"Completed: {len(completed)} / {len(self.execution_plan)} | "
            f"Passed: {passed} | Failed: {failed} | "
            f"Checks: {checks} | Check Failures: {check_failures} | "
            f"Missing Metrics: {missing}"
        )

    def _mark_remaining_not_run(self) -> None:
        for index in range(
            self.current_plan_index,
            len(self.execution_plan),
        ):
            result = self.execution_plan[index]
            if result.status == "PENDING":
                result.status = "NOT_RUN"
                self._update_result_row(index)

    def _finish_plan(self, forced_status: str | None = None) -> None:
        self.running = False
        self.pause_requested = False

        if forced_status is not None:
            final_status = forced_status
        else:
            failing_statuses = {
                "FAIL",
                "TIMEOUT",
                "ENGINE_ERROR",
                "CONFIG_ERROR",
            }
            final_status = (
                "FAIL"
                if any(
                    result.status in failing_statuses
                    for result in self.execution_plan
                )
                else "PASS"
            )

        self.execution_status_var.set(final_status)
        self._set_status_color(final_status)

        completed = sum(
            result.status not in ("PENDING", "RUNNING", "NOT_RUN")
            for result in self.execution_plan
        )
        passed = sum(
            result.status == "PASS"
            for result in self.execution_plan
        )
        failed = sum(
            result.status
            in ("FAIL", "TIMEOUT", "ENGINE_ERROR", "CONFIG_ERROR")
            for result in self.execution_plan
        )
        timed_out = sum(
            result.status == "TIMEOUT"
            for result in self.execution_plan
        )
        engine_errors = sum(
            result.status == "ENGINE_ERROR"
            for result in self.execution_plan
        )
        not_run = sum(
            result.status == "NOT_RUN"
            for result in self.execution_plan
        )
        total_runs = sum(result.total_runs for result in self.execution_plan)
        checks, check_failures, missing = self._metrics_totals(
            self.execution_plan
        )

        plan_exit_text = (
            "N/A"
            if final_status in ("PAUSED", "STOPPED")
            else "0" if final_status == "PASS" else "1"
        )

        summary = (
            f"{self.plan_label} | "
            f"Planned: {len(self.execution_plan)} | "
            f"Completed: {completed} | Passed: {passed} | "
            f"Failed: {failed} | Timeout: {timed_out} | "
            f"Engine Error: {engine_errors} | Not Run: {not_run} | "
            f"Total Runs: {total_runs} | Checks: {checks} | "
            f"Check Failures: {check_failures} | "
            f"Missing Metrics: {missing} | "
            f"Plan ExitCode: {plan_exit_text}"
        )

        self.summary_var.set(summary)
        self._append_output(
            "\n============================================================\n"
            "DASHBOARD EXECUTION PLAN SUMMARY\n"
            "============================================================\n"
            f"{summary}\n"
            f"RESULT: {final_status}\n"
            "============================================================\n"
        )
        self.status_bar_var.set(
            f"Execution plan finished: {final_status}"
        )
        self._update_button_states()

        if self.pending_close:
            self._save_local_configuration()
            self.root.destroy()

    def _set_status_color(self, status: str) -> None:
        self.execution_status_label.configure(
            foreground=self.status_colors.get(status, "#666666")
        )

    # ============================================================
    # OUTPUT
    # ============================================================

    def _append_output(
        self,
        text: str,
        capture_for_current: bool = False,
    ) -> None:
        self.complete_output.append(text)
        if capture_for_current:
            self.current_test_output.append(text)

        self.output_text.configure(state=tk.NORMAL)
        self.output_text.insert(tk.END, text)
        self.output_text.configure(state=tk.DISABLED)

        if self.auto_scroll_var.get():
            self.output_text.see(tk.END)

    def clear_output(self) -> None:
        self.output_text.configure(state=tk.NORMAL)
        self.output_text.delete("1.0", tk.END)
        self.output_text.configure(state=tk.DISABLED)
        self.complete_output.clear()
        if not self.running:
            self.current_test_output.clear()

    def copy_output(self) -> None:
        text = self.output_text.get("1.0", tk.END).strip()
        if not text:
            self.status_bar_var.set("Output is empty.")
            return
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        self.status_bar_var.set("Output copied.")

    # ============================================================
    # STOP
    # ============================================================

    def stop_execution(self) -> None:
        if not self.running:
            return

        self.stop_requested = True
        self.pause_requested = False

        with self.process_lock:
            process = self.process

        if process is not None and process.poll() is None:
            try:
                subprocess.run(
                    [
                        "taskkill",
                        "/PID",
                        str(process.pid),
                        "/T",
                        "/F",
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                    shell=False,
                    creationflags=getattr(
                        subprocess,
                        "CREATE_NO_WINDOW",
                        0,
                    ),
                )
            except OSError:
                try:
                    process.terminate()
                except OSError:
                    pass
        else:
            self._mark_remaining_not_run()
            self._finish_plan("STOPPED")

        self.status_bar_var.set("Stop requested.")

    # ============================================================
    # BUTTON STATES
    # ============================================================

    def _update_button_states(self) -> None:
        selected = self._selected_test()
        valid_config = self._configuration_valid()
        idle = not self.running
        resumable = self._has_resumable_plan()

        self.run_selected_button.configure(
            state=(
                tk.NORMAL
                if idle and valid_config and selected is not None
                else tk.DISABLED
            )
        )

        suite = self.suite_var.get() or "All"
        suite_has_tests = any(
            suite == "All" or test.suite == suite
            for test in self.tests
        )
        self.run_suite_button.configure(
            state=(
                tk.NORMAL
                if idle and valid_config and suite_has_tests
                else tk.DISABLED
            )
        )
        self.run_all_button.configure(
            state=(
                tk.NORMAL
                if idle and valid_config and bool(self.tests)
                else tk.DISABLED
            )
        )

        if self.running:
            if self.pause_requested:
                self.pause_resume_button.configure(
                    text="Pausing...",
                    state=tk.DISABLED,
                )
            else:
                self.pause_resume_button.configure(
                    text="Pause",
                    state=tk.NORMAL,
                )
        elif resumable:
            self.pause_resume_button.configure(
                text="Resume",
                state=tk.NORMAL,
            )
        else:
            self.pause_resume_button.configure(
                text="Pause",
                state=tk.DISABLED,
            )

        self.stop_button.configure(
            state=tk.NORMAL if self.running else tk.DISABLED
        )
        normal_state = tk.NORMAL if idle else tk.DISABLED
        self.refresh_button.configure(state=normal_state)
        self.select_godot_button.configure(state=normal_state)
        self.repeat_spinbox.configure(state=normal_state)
        self.timeout_spinbox.configure(state=normal_state)
        self.test_tree.configure(
            selectmode="browse" if idle else "none"
        )

    # ============================================================
    # LOCAL PERSISTENCE
    # ============================================================

    def _save_local_configuration(self) -> None:
        self.local_config["window_geometry"] = self.root.geometry()
        self.local_config["last_suite"] = self.suite_var.get()

        selected = self._selected_test()
        if selected:
            self.local_config["last_selected_test"] = (
                selected.resource_path
            )

        try:
            self.local_config["repeat"] = self._repeat()
        except (ValueError, tk.TclError):
            self.local_config["repeat"] = 1

        try:
            self.local_config["timeout_seconds"] = self._timeout()
        except (ValueError, tk.TclError):
            self.local_config["timeout_seconds"] = 10

        self.local_config["auto_scroll"] = self.auto_scroll_var.get()

        if self.godot_console is not None:
            self.local_config["godot_console"] = str(
                self.godot_console
            )

        try:
            write_json_file(
                self.local_config_path,
                self.local_config,
            )
        except OSError as error:
            messagebox.showerror(
                "Save Error",
                str(error),
                parent=self.root,
            )

    # ============================================================
    # CLOSE
    # ============================================================

    def on_close(self) -> None:
        if self.running:
            should_stop = messagebox.askyesno(
                "Execution Plan Running",
                "An execution plan is running.\n\n"
                "Stop it and exit?",
                parent=self.root,
            )
            if not should_stop:
                return
            self.pending_close = True
            self.stop_execution()
            return

        if self._has_resumable_plan():
            should_exit = messagebox.askyesno(
                "Paused Plan",
                "A paused or stopped plan exists.\n\n"
                "It will be lost when the Dashboard closes.\n\n"
                "Exit anyway?",
                parent=self.root,
            )
            if not should_exit:
                return

        self._save_local_configuration()
        self.root.destroy()


def main() -> int:
    root = tk.Tk()

    try:
        VelocityTestDashboard(root)
    except Exception as error:
        messagebox.showerror(
            APP_NAME,
            str(error),
            parent=root,
        )
        root.destroy()
        return 1

    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
