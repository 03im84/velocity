from __future__ import annotations

import subprocess
import sys
import threading

from pathlib import Path
from typing import Any, Callable


PROJECT_ROOT = Path(__file__).resolve().parents[2]
GIT_TOOL_DIRECTORY = PROJECT_ROOT / "tools" / "git"

if str(GIT_TOOL_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(GIT_TOOL_DIRECTORY))

from velocity_submit import run_tool  # noqa: E402
from velocity_submit_contract import ExitCode  # noqa: E402
from velocity_submit_git import (  # noqa: E402
    RepositoryController,
    hidden_subprocess_options,
)

from velocity_dashboard_service import EventBroker  # noqa: E402


class DeliveryService:
    def __init__(
        self,
        project_root: Path,
        broker: EventBroker,
        refresh_callback: Callable[[], None],
    ) -> None:
        self.project_root = project_root
        self.broker = broker
        self.refresh_callback = refresh_callback
        self._lock = threading.RLock()
        self._prompt_condition = threading.Condition(self._lock)
        self._busy = False
        self._operation = "IDLE"
        self._selected_package: Path | None = None
        self._pending_prompt = ""
        self._prompt_answer: str | None = None
        self._last_result = ""
        self._thread: threading.Thread | None = None

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            receipt_state = "none"
            delivery_id = ""
            try:
                repository = RepositoryController.discover(
                    self.project_root
                )
                receipt = repository.load_receipt()
                if receipt is not None:
                    receipt_state = receipt.state
                    delivery_id = receipt.delivery_id
            except Exception:
                receipt_state = "error"

            return {
                "busy": self._busy,
                "operation": self._operation,
                "selected_package": (
                    ""
                    if self._selected_package is None
                    else str(self._selected_package)
                ),
                "pending_prompt": self._pending_prompt,
                "last_result": self._last_result,
                "receipt_state": receipt_state,
                "delivery_id": delivery_id,
            }

    def select_package(self) -> str:
        selected = run_native_picker("zip")
        if selected is None:
            return ""
        with self._lock:
            if self._busy:
                raise RuntimeError("Delivery operation is active.")
            self._selected_package = selected
        self._publish_state()
        return str(selected)

    def start_install(self) -> None:
        with self._lock:
            if self._busy:
                raise RuntimeError("Delivery operation is active.")
            if self._selected_package is None:
                raise ValueError("Select a delivery ZIP first.")
            self._busy = True
            self._operation = "INSTALLING"
            self._last_result = ""
            package = self._selected_package
            self._thread = threading.Thread(
                target=self._worker,
                args=("install", package),
                daemon=True,
                name="vtd-delivery-install",
            )
            self._thread.start()
        self._publish_state()

    def start_submit(self) -> None:
        with self._lock:
            if self._busy:
                raise RuntimeError("Delivery operation is active.")
            self._busy = True
            self._operation = "PREPARING_SUBMIT"
            self._last_result = ""
            self._thread = threading.Thread(
                target=self._worker,
                args=("submit", self._selected_package),
                daemon=True,
                name="vtd-delivery-submit",
            )
            self._thread.start()
        self._publish_state()

    def start_rollback(self) -> None:
        with self._lock:
            if self._busy:
                raise RuntimeError("Delivery operation is active.")
            self._busy = True
            self._operation = "ROLLING_BACK"
            self._last_result = ""
            self._thread = threading.Thread(
                target=self._worker,
                args=("rollback", None),
                daemon=True,
                name="vtd-delivery-rollback",
            )
            self._thread.start()
        self._publish_state()

    def answer_prompt(self, answer: str) -> None:
        with self._prompt_condition:
            if not self._pending_prompt:
                raise RuntimeError("No Delivery prompt is pending.")
            self._prompt_answer = answer
            self._prompt_condition.notify_all()

    def wait(self, timeout: float | None = None) -> bool:
        with self._lock:
            thread = self._thread
        if thread is None:
            return True
        thread.join(timeout)
        return not thread.is_alive()

    def is_busy(self) -> bool:
        with self._lock:
            return self._busy

    def _worker(
        self,
        mode: str,
        package: Path | None,
    ) -> None:
        code = run_tool(
            start_directory=self.project_root,
            package_path=package,
            mode=mode,
            input_function=self._request_input,
            output_function=self._output,
            package_selector=lambda: package,
        )

        with self._lock:
            self._busy = False
            self._operation = (
                "COMPLETE"
                if code == ExitCode.PASS
                else "ERROR"
            )
            self._last_result = ExitCode(code).name
            self._pending_prompt = ""
            self._prompt_answer = None

        if mode == "install" and code == ExitCode.PASS:
            self.refresh_callback()

        self._publish_state()

    def _request_input(self, prompt: str) -> str:
        with self._prompt_condition:
            self._pending_prompt = prompt
            self._prompt_answer = None
            self._operation = "AWAITING_CONFIRMATION"
            self.broker.publish(
                "delivery_prompt",
                {
                    "prompt": prompt,
                    "state": self.snapshot(),
                },
            )

            while self._prompt_answer is None:
                self._prompt_condition.wait()

            answer = self._prompt_answer
            self._pending_prompt = ""
            self._prompt_answer = None
            self._operation = "RUNNING"
            return answer

    def _output(self, line: str) -> None:
        self.broker.publish(
            "delivery_output",
            {"text": line + "\n"},
        )

    def _publish_state(self) -> None:
        self.broker.publish(
            "delivery_state",
            self.snapshot(),
        )


def run_native_picker(kind: str) -> Path | None:
    helper = (
        PROJECT_ROOT
        / "tools"
        / "git"
        / "velocity_native_picker.py"
    )
    process = subprocess.run(
        [sys.executable, str(helper), "--kind", kind],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=False,
        check=False,
        **hidden_subprocess_options(),
    )

    if process.returncode != 0:
        return None

    selected = process.stdout.strip()
    if not selected:
        return None

    return Path(selected)
