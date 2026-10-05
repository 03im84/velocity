from __future__ import annotations

import fnmatch
import json
import locale
import os
import queue
import re
import subprocess
import threading
import time

from collections import deque
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

from velocity_test_dashboard_logic import (
    infer_suite,
    ordered_suites,
    parse_runner_metrics,
)


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
    "roadmap": "docs/project_state/velocity_roadmap.json",
}

DEFAULT_LOCAL_CONFIG: dict[str, Any] = {
    "godot_console": "",
    "last_selected_test": "",
    "last_suite": "All",
    "repeat": 1,
    "timeout_seconds": 10,
    "auto_scroll": True,
    "theme": "dark",
    "browser": {
        "mode": "system_default",
        "executable": "",
        "window_mode": "tab",
    },
    "server": {
        "host": "127.0.0.1",
        "port": 0,
        "shutdown_delay_ms": 750,
    },
}

VALID_THEMES = {"light", "dark", "reading"}
VALID_BROWSER_MODES = {
    "system_default",
    "edge",
    "chrome",
    "firefox",
    "custom",
}
VALID_WINDOW_MODES = {"tab", "application"}


@dataclass(frozen=True, slots=True)
class TestScene:
    name: str
    resource_path: str
    filesystem_path: Path
    relative_path: str
    suite: str

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "resource_path": self.resource_path,
            "relative_path": self.relative_path,
            "suite": self.suite,
        }


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

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["test"] = self.test.to_dict()
        data.pop("output", None)
        return data


@dataclass(frozen=True, slots=True)
class DashboardEvent:
    event_id: int
    event_type: str
    data: dict[str, Any]


class EventBroker:
    def __init__(self, history_limit: int = 2000) -> None:
        self._lock = threading.Lock()
        self._next_id = 1
        self._history: deque[DashboardEvent] = deque(
            maxlen=history_limit
        )
        self._subscribers: set[
            queue.Queue[DashboardEvent]
        ] = set()

    def publish(
        self,
        event_type: str,
        data: Mapping[str, Any],
    ) -> DashboardEvent:
        with self._lock:
            event = DashboardEvent(
                self._next_id,
                event_type,
                dict(data),
            )
            self._next_id += 1
            self._history.append(event)
            subscribers = tuple(self._subscribers)

        for subscriber in subscribers:
            try:
                subscriber.put_nowait(event)
            except queue.Full:
                pass

        return event

    def get_latest_event_id(self) -> int:
        with self._lock:
            return self._next_id - 1

    def subscribe(
        self,
        last_event_id: int = 0,
    ) -> queue.Queue[DashboardEvent]:
        subscriber: queue.Queue[DashboardEvent] = queue.Queue(
            maxsize=5000
        )

        with self._lock:
            missed = [
                event
                for event in self._history
                if event.event_id > last_event_id
            ]
            self._subscribers.add(subscriber)

        for event in missed:
            try:
                subscriber.put_nowait(event)
            except queue.Full:
                break

        return subscriber

    def unsubscribe(
        self,
        subscriber: queue.Queue[DashboardEvent],
    ) -> None:
        with self._lock:
            self._subscribers.discard(subscriber)


class DashboardConfiguration:
    def __init__(
        self,
        tools_directory: Path,
    ) -> None:
        self.tools_directory = tools_directory
        self.shared_path = tools_directory / "test_dashboard.json"
        self.local_path = tools_directory / "test_dashboard.local.json"
        self.shared = read_json_file(
            self.shared_path,
            DEFAULT_SHARED_CONFIG,
        )
        self.local = deep_merge(
            DEFAULT_LOCAL_CONFIG,
            read_json_file(self.local_path, {}),
        )
        validate_local_config(self.local)

        project_value = str(
            self.shared.get("project_root", "../..")
        )
        self.project_root = (
            tools_directory / project_value
        ).resolve()
        runner_value = str(
            self.shared.get(
                "runner",
                "test/tools/run_godot_tests.ps1",
            )
        )
        self.runner_path = (
            self.project_root / runner_value
        ).resolve()

    def save_local(self) -> None:
        validate_local_config(self.local)
        write_json_file(self.local_path, self.local)

    def public_settings(self) -> dict[str, Any]:
        return {
            "godot_console": str(
                self.local.get("godot_console", "")
            ),
            "repeat": int(self.local.get("repeat", 1)),
            "timeout_seconds": int(
                self.local.get("timeout_seconds", 10)
            ),
            "auto_scroll": bool(
                self.local.get("auto_scroll", True)
            ),
            "theme": str(self.local.get("theme", "dark")),
            "browser": dict(self.local["browser"]),
            "server": dict(self.local["server"]),
        }

    def update_settings(
        self,
        value: Mapping[str, Any],
    ) -> bool:
        previous_port = int(self.local["server"]["port"])
        updated = deep_merge(self.local, dict(value))
        validate_local_config(updated)
        self.local = updated
        self.save_local()
        return int(self.local["server"]["port"]) != previous_port


def deep_merge(
    base: Mapping[str, Any],
    override: Mapping[str, Any],
) -> dict[str, Any]:
    result: dict[str, Any] = {}

    for key, value in base.items():
        if isinstance(value, Mapping):
            override_value = override.get(key, {})
            if not isinstance(override_value, Mapping):
                override_value = {}
            result[key] = deep_merge(value, override_value)
        else:
            result[key] = override.get(key, value)

    for key, value in override.items():
        if key not in result:
            result[key] = value

    return result


def read_json_file(
    path: Path,
    default_value: Mapping[str, Any],
) -> dict[str, Any]:
    if not path.exists():
        return dict(default_value)

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(
            "Could not read JSON file: "
            + str(path)
            + ": "
            + str(error)
        ) from error

    if not isinstance(data, dict):
        raise ValueError("JSON root must be an object: " + str(path))

    return dict(data)


def write_json_file(
    path: Path,
    value: Mapping[str, Any],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def validate_local_config(config: Mapping[str, Any]) -> None:
    theme = str(config.get("theme", ""))
    if theme not in VALID_THEMES:
        raise ValueError("Invalid theme: " + theme)

    browser = config.get("browser")
    if not isinstance(browser, Mapping):
        raise ValueError("Browser config must be an object.")

    browser_mode = str(browser.get("mode", ""))
    if browser_mode not in VALID_BROWSER_MODES:
        raise ValueError("Invalid browser mode: " + browser_mode)

    window_mode = str(browser.get("window_mode", ""))
    if window_mode not in VALID_WINDOW_MODES:
        raise ValueError("Invalid browser window mode: " + window_mode)

    executable = str(browser.get("executable", ""))
    if browser_mode == "custom":
        if not executable:
            raise ValueError("Custom browser requires executable path.")

        path = Path(executable)
        if not path.is_file():
            raise ValueError("Browser executable does not exist.")
        if os.name == "nt" and path.suffix.lower() != ".exe":
            raise ValueError("Windows browser executable must be .exe.")

    server = config.get("server")
    if not isinstance(server, Mapping):
        raise ValueError("Server config must be an object.")

    if str(server.get("host", "")) != "127.0.0.1":
        raise ValueError("VTD server host must be 127.0.0.1.")

    port = int(server.get("port", 0))
    if port != 0 and not 1024 <= port <= 65535:
        raise ValueError("Server port must be 0 or 1024–65535.")

    delay = int(server.get("shutdown_delay_ms", 750))
    if not 100 <= delay <= 5000:
        raise ValueError("Shutdown delay must be 100–5000 ms.")

    repeat = int(config.get("repeat", 1))
    timeout = int(config.get("timeout_seconds", 10))
    if not 1 <= repeat <= 100:
        raise ValueError("Repeat must be 1–100.")
    if not 1 <= timeout <= 3600:
        raise ValueError("Timeout must be 1–3600 seconds.")


def discover_tests(
    configuration: DashboardConfiguration,
) -> list[TestScene]:
    project_root = configuration.project_root
    test_roots = [
        str(value)
        for value in configuration.shared.get(
            "test_roots",
            ["test/core"],
        )
    ]
    include_patterns = [
        str(value)
        for value in configuration.shared.get(
            "include_patterns",
            ["*Test.tscn", "*_test.tscn"],
        )
    ]
    exclude_patterns = [
        str(value).replace("\\", "/")
        for value in configuration.shared.get(
            "exclude_patterns",
            [],
        )
    ]
    aliases = dict(
        configuration.shared.get("suite_aliases", {})
    )
    overrides = dict(
        configuration.shared.get("suite_overrides", {})
    )
    scenes: list[TestScene] = []
    seen_paths: set[str] = set()

    for root_value in test_roots:
        root = (project_root / root_value).resolve()
        if not root.is_dir():
            continue

        for scene_path in sorted(root.rglob("*.tscn")):
            relative = scene_path.relative_to(project_root).as_posix()
            if relative in seen_paths:
                continue
            if not any(
                fnmatch.fnmatch(scene_path.name, pattern)
                for pattern in include_patterns
            ):
                continue
            if any(
                excluded in relative
                for excluded in exclude_patterns
            ):
                continue

            name = scene_path.stem
            suite = infer_suite(
                relative,
                test_roots,
                aliases,
                overrides,
                name,
            )
            scenes.append(
                TestScene(
                    name=name,
                    resource_path="res://" + relative,
                    filesystem_path=scene_path,
                    relative_path=relative,
                    suite=suite,
                )
            )
            seen_paths.add(relative)

    return scenes


def suite_names(
    configuration: DashboardConfiguration,
    tests: Sequence[TestScene],
) -> list[str]:
    return ordered_suites(
        [test.suite for test in tests],
        [
            str(value)
            for value in configuration.shared.get(
                "suite_order",
                [],
            )
        ],
    )


def load_roadmap(
    configuration: DashboardConfiguration,
) -> dict[str, Any]:
    relative = str(
        configuration.shared.get(
            "roadmap",
            "docs/project_state/velocity_roadmap.json",
        )
    )
    path = (configuration.project_root / relative).resolve()
    try:
        path.relative_to(configuration.project_root)
    except ValueError as error:
        raise ValueError("Roadmap path escapes project root.") from error

    roadmap = read_json_file(path, {})
    validate_roadmap(roadmap)
    return roadmap


def validate_roadmap(roadmap: Mapping[str, Any]) -> None:
    if roadmap.get("schema") != "velocity-roadmap/v1":
        raise ValueError("Unsupported roadmap schema.")
    phase_count = roadmap.get("phase_count")
    if not isinstance(phase_count, int) or not 1 <= phase_count <= 100:
        raise ValueError("Roadmap phase_count must be 1–100.")
    milestones = roadmap.get("milestones")
    if not isinstance(milestones, list) or not milestones:
        raise ValueError("Roadmap milestones must be a non-empty array.")
    valid_statuses = {"completed", "active", "planned", "blocked", "deferred"}
    seen: set[str] = set()

    for item in milestones:
        if not isinstance(item, dict):
            raise ValueError("Roadmap milestone must be an object.")
        milestone_id = item.get("id")
        if not isinstance(milestone_id, str) or not milestone_id:
            raise ValueError("Roadmap milestone ID is required.")
        if milestone_id in seen:
            raise ValueError("Duplicate roadmap milestone: " + milestone_id)
        seen.add(milestone_id)
        if item.get("status") not in valid_statuses:
            raise ValueError("Invalid milestone status: " + milestone_id)
        phase = item.get("phase")
        duration = item.get("duration")
        progress = item.get("progress")
        if not isinstance(phase, int) or not 1 <= phase <= phase_count:
            raise ValueError("Invalid milestone phase: " + milestone_id)
        if not isinstance(duration, int) or duration <= 0:
            raise ValueError("Invalid milestone duration: " + milestone_id)
        if phase + duration - 1 > phase_count:
            raise ValueError("Milestone exceeds phase range: " + milestone_id)
        if not isinstance(progress, int) or not 0 <= progress <= 100:
            raise ValueError("Invalid milestone progress: " + milestone_id)
        dependencies = item.get("dependencies", [])
        if not isinstance(dependencies, list) or not all(
            isinstance(value, str) for value in dependencies
        ):
            raise ValueError("Invalid dependencies: " + milestone_id)

    for item in milestones:
        for dependency in item.get("dependencies", []):
            if dependency not in seen:
                raise ValueError(
                    "Unknown roadmap dependency: "
                    + item["id"]
                    + " -> "
                    + dependency
                )

    current = roadmap.get("current_milestone")
    target = roadmap.get("target")
    if current not in seen:
        raise ValueError("Current roadmap milestone is unknown.")
    if target not in seen:
        raise ValueError("Roadmap target is unknown.")


class TestExecutionService:
    def __init__(
        self,
        configuration: DashboardConfiguration,
        broker: EventBroker,
    ) -> None:
        self.configuration = configuration
        self.broker = broker
        self._lock = threading.RLock()
        self._process: subprocess.Popen[str] | None = None
        self._thread: threading.Thread | None = None
        self._running = False
        self._pause_requested = False
        self._stop_requested = False
        self._plan: list[PlanResult] = []
        self._plan_label = ""
        self._current_index = -1
        self._repeat = 1
        self._timeout = 10
        self._final_status = "IDLE"

    def is_running(self) -> bool:
        with self._lock:
            return self._running

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "running": self._running,
                "pause_requested": self._pause_requested,
                "stop_requested": self._stop_requested,
                "label": self._plan_label,
                "current_index": self._current_index,
                "planned": len(self._plan),
                "final_status": self._final_status,
                "results": [result.to_dict() for result in self._plan],
                "summary": self._summary_locked(),
            }

    def start(
        self,
        tests: Sequence[TestScene],
        label: str,
        repeat: int,
        timeout_seconds: int,
    ) -> None:
        if not tests:
            raise ValueError("Execution plan is empty.")
        if not 1 <= repeat <= 100:
            raise ValueError("Repeat must be 1–100.")
        if not 1 <= timeout_seconds <= 3600:
            raise ValueError("Timeout must be 1–3600 seconds.")

        with self._lock:
            if self._running:
                raise RuntimeError("A test plan is already running.")
            self._plan = [PlanResult(test=test) for test in tests]
            self._plan_label = label
            self._current_index = 0
            self._repeat = repeat
            self._timeout = timeout_seconds
            self._pause_requested = False
            self._stop_requested = False
            self._running = True
            self._final_status = "RUNNING"
            self._thread = threading.Thread(
                target=self._worker_plan,
                daemon=True,
                name="vtd-test-plan",
            )
            self._thread.start()

        self.broker.publish("plan_started", self.snapshot())

    def request_pause(self) -> None:
        with self._lock:
            if self._running:
                self._pause_requested = True
        self.broker.publish("plan_state", self.snapshot())

    def resume(self) -> None:
        with self._lock:
            if self._running:
                return
            next_index = next(
                (
                    index
                    for index, result in enumerate(self._plan)
                    if result.status in ("NOT_RUN", "STOPPED")
                ),
                None,
            )
            if next_index is None:
                raise RuntimeError("No resumable test plan exists.")
            for result in self._plan[next_index:]:
                if result.status in ("NOT_RUN", "STOPPED"):
                    result.status = "PENDING"
            self._current_index = next_index
            self._pause_requested = False
            self._stop_requested = False
            self._running = True
            self._final_status = "RUNNING"
            self._thread = threading.Thread(
                target=self._worker_plan,
                daemon=True,
                name="vtd-test-plan-resume",
            )
            self._thread.start()
        self.broker.publish("plan_resumed", self.snapshot())

    def request_stop(self) -> None:
        process: subprocess.Popen[str] | None
        with self._lock:
            self._stop_requested = True
            process = self._process
        if process is not None and process.poll() is None:
            terminate_process_tree(process)
        self.broker.publish("plan_state", self.snapshot())

    def wait(self, timeout: float | None = None) -> bool:
        thread: threading.Thread | None
        with self._lock:
            thread = self._thread
        if thread is None:
            return True
        thread.join(timeout)
        return not thread.is_alive()

    def _worker_plan(self) -> None:
        while True:
            with self._lock:
                if self._stop_requested:
                    self._mark_remaining_locked("NOT_RUN")
                    self._finish_locked("STOPPED")
                    break
                if self._current_index >= len(self._plan):
                    self._finish_locked(None)
                    break
                result = self._plan[self._current_index]
                result.status = "RUNNING"
                index = self._current_index

            self.broker.publish(
                "test_started",
                {
                    "index": index,
                    "result": result.to_dict(),
                    "plan": self.snapshot(),
                },
            )
            self._run_test(result)

            with self._lock:
                self._current_index += 1
                self.broker.publish(
                    "test_finished",
                    {
                        "index": index,
                        "result": result.to_dict(),
                        "plan": self.snapshot(),
                    },
                )
                if self._stop_requested:
                    self._mark_remaining_locked("NOT_RUN")
                    self._finish_locked("STOPPED")
                    break
                if (
                    self._pause_requested
                    and self._current_index < len(self._plan)
                ):
                    self._pause_requested = False
                    self._mark_remaining_locked("NOT_RUN")
                    self._finish_locked("PAUSED")
                    break

        self.broker.publish("plan_finished", self.snapshot())

    def _run_test(self, result: PlanResult) -> None:
        command = self._command_for(result.test)
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

        started = time.monotonic()
        lines: list[str] = []

        try:
            process = subprocess.Popen(
                command,
                cwd=self.configuration.project_root,
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
            with self._lock:
                self._process = process

            assert process.stdout is not None
            stream_buffer: list[str] = []
            stream_size = 0
            last_publish = time.monotonic()

            for line in process.stdout:
                lines.append(line)
                stream_buffer.append(line)
                stream_size += len(line)

                now = time.monotonic()

                if (
                    stream_size >= 16_384
                    or now - last_publish >= 0.05
                ):
                    self._publish_output_batch(
                        result.test.resource_path,
                        stream_buffer,
                    )
                    stream_buffer = []
                    stream_size = 0
                    last_publish = now

            if stream_buffer:
                self._publish_output_batch(
                    result.test.resource_path,
                    stream_buffer,
                )

            exit_code = process.wait()
        except Exception as error:
            lines.append("DASHBOARD ERROR: " + str(error) + "\n")
            exit_code = 1
        finally:
            with self._lock:
                self._process = None

        output = "".join(lines)
        result.exit_code = exit_code
        result.output = output[-65_536:]
        result.duration_seconds = time.monotonic() - started
        result.status = status_from_output(exit_code, output)

        summary = parse_runner_summary(output)
        result.total_runs = summary.get("total_runs", 0)
        result.passed = summary.get("passed", 0)
        result.failed = summary.get("failed", 0)

        metrics = parse_runner_metrics(
            output,
            expected_attempts=self._repeat,
            expected_scene=result.test.resource_path,
        )
        result.checks = metrics.checks
        result.check_failures = metrics.check_failures
        result.metrics_runs = metrics.metrics_runs
        result.missing_metrics = metrics.missing_metrics
        result.protocol_errors = metrics.protocol_errors

    def _publish_output_batch(
        self,
        resource_path: str,
        lines: Sequence[str],
    ) -> None:
        if not lines:
            return

        self.broker.publish(
            "output",
            {
                "text": "".join(lines),
                "scene": resource_path,
            },
        )

    def _command_for(self, test: TestScene) -> list[str]:
        godot = str(
            self.configuration.local.get("godot_console", "")
        ).strip()
        if not godot:
            godot = os.environ.get("GODOT_CONSOLE", "").strip()
        if not godot:
            raise ValueError("Godot Console is not configured.")

        powershell = "powershell.exe" if os.name == "nt" else "pwsh"
        return [
            powershell,
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(self.configuration.runner_path),
            "-Scene",
            test.resource_path,
            "-GodotPath",
            godot,
            "-Repeat",
            str(self._repeat),
            "-TimeoutSeconds",
            str(self._timeout),
        ]

    def _mark_remaining_locked(self, status: str) -> None:
        for result in self._plan[self._current_index:]:
            if result.status == "PENDING":
                result.status = status

    def _finish_locked(self, forced_status: str | None) -> None:
        self._running = False
        self._pause_requested = False
        if forced_status is not None:
            status = forced_status
        else:
            failing = {"FAIL", "TIMEOUT", "ENGINE_ERROR", "CONFIG_ERROR"}
            status = (
                "FAIL"
                if any(result.status in failing for result in self._plan)
                else "PASS"
            )
        self._final_status = status

    def _summary_locked(self) -> dict[str, Any]:
        return build_execution_summary(
            self._plan,
            self._final_status,
        )


def build_execution_summary(
    plan: Sequence[PlanResult],
    final_status: str,
) -> dict[str, Any]:
    completed = [
        result
        for result in plan
        if result.status not in ("PENDING", "RUNNING", "NOT_RUN")
    ]
    passed = sum(result.status == "PASS" for result in completed)
    failed = sum(
        result.status
        in ("FAIL", "TIMEOUT", "ENGINE_ERROR", "CONFIG_ERROR")
        for result in completed
    )

    if final_status in ("PAUSED", "STOPPED", "RUNNING", "IDLE"):
        plan_exit_code: int | None = None
    else:
        plan_exit_code = 0 if final_status == "PASS" else 1

    return {
        "planned": len(plan),
        "completed": len(completed),
        "passed": passed,
        "failed": failed,
        "timeout": sum(result.status == "TIMEOUT" for result in plan),
        "engine_error": sum(
            result.status == "ENGINE_ERROR" for result in plan
        ),
        "not_run": sum(result.status == "NOT_RUN" for result in plan),
        "total_runs": sum(result.total_runs for result in plan),
        "checks": sum(result.checks for result in completed),
        "check_failures": sum(
            result.check_failures for result in completed
        ),
        "missing_metrics": sum(
            result.missing_metrics for result in completed
        ),
        "plan_exit_code": plan_exit_code,
        "result": final_status,
    }


def status_from_output(exit_code: int, output: str) -> str:
    if exit_code == 0:
        return "PASS"
    if "TIMEOUT" in output or "ExitCode 124" in output:
        return "TIMEOUT"
    if "ENGINE_ERROR" in output or "ExitCode 126" in output:
        return "ENGINE_ERROR"
    return "FAIL"


def parse_runner_summary(output: str) -> dict[str, int]:
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


def terminate_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return

    if os.name == "nt":
        subprocess.run(
            [
                "taskkill",
                "/PID",
                str(process.pid),
                "/T",
                "/F",
            ],
            capture_output=True,
            shell=False,
            check=False,
        )
    else:
        process.terminate()
