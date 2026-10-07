from __future__ import annotations

import os
import signal
import subprocess
import sys
import threading
import time

from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
GIT_TOOL_DIRECTORY = PROJECT_ROOT / "tools" / "git"

if str(GIT_TOOL_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(GIT_TOOL_DIRECTORY))

from velocity_submit_git import hidden_subprocess_options  # noqa: E402
from velocity_dashboard_service import EventBroker  # noqa: E402


class ToolingTestService:
    def __init__(
        self,
        project_root: Path,
        broker: EventBroker,
        runner_path: Path | None = None,
    ) -> None:
        self.project_root = project_root.resolve()
        self.broker = broker
        self.runner_path = (
            runner_path
            if runner_path is not None
            else self.project_root
            / "tools"
            / "testing"
            / "velocity_tooling_tests.py"
        )
        self._lock = threading.RLock()
        self._process: subprocess.Popen[str] | None = None
        self._thread: threading.Thread | None = None
        self._running = False
        self._stop_requested = False
        self._status = "IDLE"
        self._exit_code: int | None = None
        self._duration_seconds = 0.0

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "running": self._running,
                "stop_requested": self._stop_requested,
                "status": self._status,
                "exit_code": self._exit_code,
                "duration_seconds": self._duration_seconds,
            }

    def is_running(self) -> bool:
        with self._lock:
            return self._running

    def start(self) -> None:
        with self._lock:
            if self._running:
                raise RuntimeError("Tooling tests are already running.")
            if not self.runner_path.is_file():
                raise RuntimeError("Canonical tooling test runner is missing.")
            self._running = True
            self._stop_requested = False
            self._status = "RUNNING"
            self._exit_code = None
            self._duration_seconds = 0.0
            self._thread = threading.Thread(
                target=self._worker,
                daemon=True,
                name="vtd-tooling-tests",
            )
            self._thread.start()
        self._publish_state()

    def request_stop(self) -> None:
        with self._lock:
            if not self._running:
                raise RuntimeError("Tooling tests are not running.")
            self._stop_requested = True
            process = self._process

        if process is not None and process.poll() is None:
            _terminate_process_tree(process)

        self._publish_state()

    def wait(self, timeout: float | None = None) -> bool:
        with self._lock:
            thread = self._thread
        if thread is None:
            return True
        thread.join(timeout)
        return not thread.is_alive()

    def _worker(self) -> None:
        started = time.monotonic()
        command = [sys.executable, str(self.runner_path)]
        options = hidden_subprocess_options()

        if os.name == "nt":
            options["creationflags"] = int(
                options.get("creationflags", 0)
            ) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
        else:
            options["start_new_session"] = True

        try:
            process = subprocess.Popen(
                command,
                cwd=self.project_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                shell=False,
                **options,
            )

            with self._lock:
                self._process = process

            if process.stdout is not None:
                try:
                    for line in process.stdout:
                        self.broker.publish(
                            "tooling_output",
                            {"text": line},
                        )
                finally:
                    process.stdout.close()

            exit_code = process.wait()
        except OSError as error:
            self.broker.publish(
                "tooling_output",
                {"text": "TOOLING RUNNER ERROR: " + str(error) + "\n"},
            )
            exit_code = 2

        with self._lock:
            stopped = self._stop_requested
            self._process = None
            self._running = False
            self._exit_code = exit_code
            self._duration_seconds = time.monotonic() - started
            self._status = (
                "STOPPED"
                if stopped
                else "PASS"
                if exit_code == 0
                else "FAIL"
            )

        self._publish_state()

    def _publish_state(self) -> None:
        self.broker.publish(
            "tooling_state",
            self.snapshot(),
        )


def _terminate_process_tree(
    process: subprocess.Popen[str],
) -> None:
    if os.name == "nt":
        subprocess.run(
            [
                "taskkill.exe",
                "/PID",
                str(process.pid),
                "/T",
                "/F",
            ],
            capture_output=True,
            text=True,
            shell=False,
            check=False,
            **hidden_subprocess_options(),
        )
        return

    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
