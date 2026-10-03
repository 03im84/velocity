from __future__ import annotations

import argparse
import http.cookies
import json
import mimetypes
import os
import queue
import secrets
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Mapping

from velocity_dashboard_delivery import (
    DeliveryService,
    run_native_picker,
)
from velocity_dashboard_service import (
    DashboardConfiguration,
    DashboardEvent,
    EventBroker,
    TestExecutionService,
    TestScene,
    discover_tests,
    suite_names,
    write_json_file,
)


APP_NAME = "Velocity Tooling Dashboard"
APP_VERSION = "0.5.0"
MAX_REQUEST_BYTES = 1024 * 1024
COOKIE_NAME = "vtd_session"
STATIC_ALLOWLIST = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/styles.css": ("styles.css", "text/css; charset=utf-8"),
    "/app.js": ("app.js", "text/javascript; charset=utf-8"),
}


@dataclass(frozen=True, slots=True)
class ServerIdentity:
    host: str
    port: int
    session_token: str
    csrf_token: str

    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"


class VelocityWebApplication:
    def __init__(
        self,
        tools_directory: Path,
    ) -> None:
        self.tools_directory = tools_directory
        self.web_directory = tools_directory / "web"
        self.configuration = DashboardConfiguration(tools_directory)
        self.broker = EventBroker()
        self.tests: list[TestScene] = []
        self.tests_lock = threading.RLock()
        self.execution = TestExecutionService(
            self.configuration,
            self.broker,
        )
        self.delivery = DeliveryService(
            self.configuration.project_root,
            self.broker,
            self.refresh_tests,
        )
        self.server: ThreadingHTTPServer | None = None
        self.identity: ServerIdentity | None = None
        self.server_state_path = (
            tools_directory
            / ".test_dashboard"
            / "server.json"
        )
        self.shutting_down = False
        self.refresh_tests()

    def refresh_tests(self) -> list[TestScene]:
        discovered = discover_tests(self.configuration)
        with self.tests_lock:
            self.tests = discovered
        self.broker.publish(
            "tests_refreshed",
            {
                "tests": [test.to_dict() for test in discovered],
                "suites": suite_names(
                    self.configuration,
                    discovered,
                ),
            },
        )
        return discovered

    def state(self) -> dict[str, Any]:
        with self.tests_lock:
            tests = [test.to_dict() for test in self.tests]
            suites = suite_names(
                self.configuration,
                self.tests,
            )

        identity = self.identity
        return {
            "app": {
                "name": APP_NAME,
                "version": APP_VERSION,
            },
            "server": {
                "host": "" if identity is None else identity.host,
                "port": 0 if identity is None else identity.port,
                "url": "" if identity is None else identity.base_url,
                "shutting_down": self.shutting_down,
            },
            "tests": tests,
            "suites": suites,
            "execution": self.execution.snapshot(),
            "delivery": self.delivery.snapshot(),
            "settings": self.configuration.public_settings(),
            "environment": {
                "project_root": str(self.configuration.project_root),
                "runner": str(self.configuration.runner_path),
                "python": sys.version.split()[0],
            },
        }

    def bootstrap(self) -> dict[str, Any]:
        identity = self.identity
        if identity is None:
            raise RuntimeError("Server identity is unavailable.")
        data = self.state()
        data["csrf_token"] = identity.csrf_token
        return data

    def start_plan(self, payload: Mapping[str, Any]) -> None:
        if self.delivery.is_busy():
            raise RuntimeError("Delivery operation is active.")
        mode = str(payload.get("mode", "selected"))
        repeat = int(
            payload.get(
                "repeat",
                self.configuration.local.get("repeat", 1),
            )
        )
        timeout = int(
            payload.get(
                "timeout_seconds",
                self.configuration.local.get("timeout_seconds", 10),
            )
        )
        with self.tests_lock:
            tests = list(self.tests)

        if mode == "all":
            selected = tests
            label = "All Tests"
        elif mode == "suite":
            suite = str(payload.get("suite", "All"))
            selected = (
                tests
                if suite == "All"
                else [test for test in tests if test.suite == suite]
            )
            label = "Suite: " + suite
        else:
            resource_path = str(payload.get("resource_path", ""))
            selected = [
                test
                for test in tests
                if test.resource_path == resource_path
            ]
            label = (
                "Selected: "
                + (selected[0].name if selected else resource_path)
            )

        self.execution.start(selected, label, repeat, timeout)

    def update_settings(
        self,
        payload: Mapping[str, Any],
    ) -> dict[str, Any]:
        if self.execution.is_running() or self.delivery.is_busy():
            raise RuntimeError("Cannot change settings during an operation.")
        restart_required = self.configuration.update_settings(payload)
        self.broker.publish(
            "settings_changed",
            {
                "settings": self.configuration.public_settings(),
                "restart_required": restart_required,
            },
        )
        return {
            "settings": self.configuration.public_settings(),
            "restart_required": restart_required,
        }

    def select_browser_executable(self) -> str:
        selected = run_native_picker("browser")
        return "" if selected is None else str(selected)

    def launch_browser(self, url: str | None = None) -> None:
        identity = self.identity

        if url is not None:
            target_url = url
        elif identity is not None:
            target_url = (
                identity.base_url
                + "/?"
                + urllib.parse.urlencode(
                    {"token": identity.session_token}
                )
            )
        else:
            target_url = ""

        if not target_url:
            raise RuntimeError("Dashboard URL is unavailable.")

        launch_browser(
            self.configuration.public_settings()["browser"],
            target_url,
        )

    def request_shutdown(self) -> int:
        if self.delivery.is_busy():
            raise RuntimeError(
                "Shutdown is disabled during Delivery operations."
            )
        if self.execution.is_running():
            raise RuntimeError(
                "Stop the active test plan before shutdown."
            )
        if self.shutting_down:
            return int(
                self.configuration.local["server"][
                    "shutdown_delay_ms"
                ]
            )

        self.shutting_down = True
        delay_ms = int(
            self.configuration.local["server"][
                "shutdown_delay_ms"
            ]
        )
        self.broker.publish(
            "shutdown",
            {"delay_ms": delay_ms},
        )
        threading.Thread(
            target=self._shutdown_worker,
            args=(delay_ms,),
            daemon=True,
            name="vtd-shutdown",
        ).start()
        return delay_ms

    def _shutdown_worker(self, delay_ms: int) -> None:
        time.sleep(delay_ms / 1000.0)
        try:
            if self.server_state_path.exists():
                self.server_state_path.unlink()
        except OSError:
            pass
        server = self.server
        if server is not None:
            server.shutdown()


class VelocityHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False

    def __init__(
        self,
        address: tuple[str, int],
        application: VelocityWebApplication,
    ) -> None:
        self.application = application
        super().__init__(address, VelocityRequestHandler)


class VelocityRequestHandler(BaseHTTPRequestHandler):
    server_version = "VelocityVTD/0.5"

    @property
    def app(self) -> VelocityWebApplication:
        server = self.server
        assert isinstance(server, VelocityHTTPServer)
        return server.application

    def do_GET(self) -> None:
        parsed = urllib.parse.urlsplit(self.path)

        if parsed.path == "/api/health":
            query = urllib.parse.parse_qs(parsed.query)
            token = query.get("token", [""])[0]
            identity = self.app.identity
            if identity is not None and secrets.compare_digest(
                token,
                identity.session_token,
            ):
                self._json_response(
                    HTTPStatus.OK,
                    {"ok": True, "version": APP_VERSION},
                )
            else:
                self._json_response(
                    HTTPStatus.UNAUTHORIZED,
                    {"error": "unauthorized"},
                )
            return

        if parsed.path in STATIC_ALLOWLIST:
            if not self._authenticated():
                if parsed.path in ("/", "/index.html"):
                    query = urllib.parse.parse_qs(parsed.query)
                    token = query.get("token", [""])[0]
                    identity = self.app.identity
                    if identity is not None and secrets.compare_digest(
                        token,
                        identity.session_token,
                    ):
                        self.send_response(HTTPStatus.SEE_OTHER)
                        self.send_header("Location", "/")
                        self.send_header(
                            "Set-Cookie",
                            f"{COOKIE_NAME}={token}; HttpOnly; "
                            "SameSite=Strict; Path=/",
                        )
                        self._security_headers()
                        self.end_headers()
                        return
                self._forbidden()
                return
            self._serve_static(parsed.path)
            return

        if not self._authenticated():
            self._forbidden()
            return

        if parsed.path == "/api/bootstrap":
            self._json_response(HTTPStatus.OK, self.app.bootstrap())
        elif parsed.path == "/api/state":
            self._json_response(HTTPStatus.OK, self.app.state())
        elif parsed.path == "/api/tests":
            state = self.app.state()
            self._json_response(
                HTTPStatus.OK,
                {
                    "tests": state["tests"],
                    "suites": state["suites"],
                },
            )
        elif parsed.path == "/api/settings":
            self._json_response(
                HTTPStatus.OK,
                self.app.configuration.public_settings(),
            )
        elif parsed.path == "/api/events":
            self._serve_events()
        else:
            self._json_response(
                HTTPStatus.NOT_FOUND,
                {"error": "not_found"},
            )

    def do_POST(self) -> None:
        parsed = urllib.parse.urlsplit(self.path)

        if not self._authenticated() or not self._valid_mutation_request():
            self._discard_request_body()
            self._forbidden()
            return

        try:
            payload = self._read_json_body()
            result = self._dispatch_post(parsed.path, payload)
            self._json_response(HTTPStatus.OK, result)
        except ValueError as error:
            self._json_response(
                HTTPStatus.BAD_REQUEST,
                {"error": str(error)},
            )
        except RuntimeError as error:
            self._json_response(
                HTTPStatus.CONFLICT,
                {"error": str(error)},
            )
        except Exception as error:
            self._json_response(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"error": str(error)},
            )

    def _dispatch_post(
        self,
        path: str,
        payload: Mapping[str, Any],
    ) -> dict[str, Any]:
        if path == "/api/tests/refresh":
            tests = self.app.refresh_tests()
            return {"tests": [test.to_dict() for test in tests]}
        if path == "/api/run":
            self.app.start_plan(payload)
            return {"execution": self.app.execution.snapshot()}
        if path == "/api/run/pause":
            self.app.execution.request_pause()
            return {"execution": self.app.execution.snapshot()}
        if path == "/api/run/resume":
            self.app.execution.resume()
            return {"execution": self.app.execution.snapshot()}
        if path == "/api/run/stop":
            self.app.execution.request_stop()
            return {"execution": self.app.execution.snapshot()}
        if path == "/api/delivery/select":
            selected = self.app.delivery.select_package()
            return {
                "selected_package": selected,
                "delivery": self.app.delivery.snapshot(),
            }
        if path == "/api/delivery/install":
            if self.app.execution.is_running():
                raise RuntimeError("A test plan is active.")
            self.app.delivery.start_install()
            return {"delivery": self.app.delivery.snapshot()}
        if path == "/api/delivery/prepare-submit":
            if self.app.execution.is_running():
                raise RuntimeError("A test plan is active.")
            self.app.delivery.start_submit()
            return {"delivery": self.app.delivery.snapshot()}
        if path == "/api/delivery/answer":
            self.app.delivery.answer_prompt(str(payload.get("answer", "")))
            return {"delivery": self.app.delivery.snapshot()}
        if path == "/api/settings":
            return self.app.update_settings(payload)
        if path == "/api/browser/select":
            return {
                "executable": self.app.select_browser_executable()
            }
        if path == "/api/browser/test":
            self.app.launch_browser()
            return {"ok": True}
        if path == "/api/shutdown/request":
            delay = self.app.request_shutdown()
            return {"accepted": True, "delay_ms": delay}
        raise ValueError("Unknown endpoint: " + path)

    def _serve_static(self, request_path: str) -> None:
        filename, content_type = STATIC_ALLOWLIST[request_path]
        path = self.app.web_directory / filename
        if not path.is_file():
            self._json_response(
                HTTPStatus.NOT_FOUND,
                {"error": "asset_missing"},
            )
            return
        content = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self._security_headers()
        self.end_headers()
        self.wfile.write(content)

    def _serve_events(self) -> None:
        last_event_text = self.headers.get("Last-Event-ID", "0")
        try:
            last_event_id = int(last_event_text)
        except ValueError:
            last_event_id = 0
        subscriber = self.app.broker.subscribe(last_event_id)
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self._security_headers()
        self.end_headers()

        try:
            while not self.app.shutting_down:
                try:
                    event = subscriber.get(timeout=15.0)
                    self._write_event(event)
                except queue.Empty:
                    self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            self.app.broker.unsubscribe(subscriber)

    def _write_event(self, event: DashboardEvent) -> None:
        payload = json.dumps(
            event.data,
            ensure_ascii=False,
            separators=(",", ":"),
        )
        message = (
            f"id: {event.event_id}\n"
            f"event: {event.event_type}\n"
            f"data: {payload}\n\n"
        )
        self.wfile.write(message.encode("utf-8"))
        self.wfile.flush()

    def _discard_request_body(self) -> None:
        length_text = self.headers.get("Content-Length", "0")

        try:
            length = int(length_text)
        except ValueError:
            return

        if length <= 0:
            return

        remaining = min(length, MAX_REQUEST_BYTES)

        while remaining > 0:
            block = self.rfile.read(min(remaining, 64 * 1024))

            if not block:
                break

            remaining -= len(block)

    def _read_json_body(self) -> dict[str, Any]:
        length_text = self.headers.get("Content-Length", "0")
        try:
            length = int(length_text)
        except ValueError as error:
            raise ValueError("Invalid Content-Length.") from error
        if length < 0 or length > MAX_REQUEST_BYTES:
            raise ValueError("Request body is too large.")
        raw = self.rfile.read(length)
        if not raw:
            return {}
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as error:
            raise ValueError("Request body must be UTF-8 JSON.") from error
        if not isinstance(data, dict):
            raise ValueError("JSON request root must be an object.")
        return data

    def _authenticated(self) -> bool:
        identity = self.app.identity
        if identity is None:
            return False
        cookie_header = self.headers.get("Cookie", "")
        cookie = http.cookies.SimpleCookie()
        try:
            cookie.load(cookie_header)
        except http.cookies.CookieError:
            return False
        morsel = cookie.get(COOKIE_NAME)
        return (
            morsel is not None
            and secrets.compare_digest(
                morsel.value,
                identity.session_token,
            )
        )

    def _valid_mutation_request(self) -> bool:
        identity = self.app.identity
        if identity is None:
            return False
        origin = self.headers.get("Origin", "")
        if origin and origin != identity.base_url:
            return False
        token = self.headers.get("X-VTD-CSRF", "")
        return secrets.compare_digest(token, identity.csrf_token)

    def _forbidden(self) -> None:
        self._json_response(
            HTTPStatus.FORBIDDEN,
            {"error": "forbidden"},
        )

    def _json_response(
        self,
        status: HTTPStatus,
        value: Mapping[str, Any],
    ) -> None:
        content = json.dumps(
            value,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self._security_headers()
        self.end_headers()
        self.wfile.write(content)

    def _security_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "connect-src 'self'; img-src 'self' data:; object-src 'none'; "
            "base-uri 'none'; frame-ancestors 'none'",
        )

    def log_message(self, format_text: str, *args: object) -> None:
        del format_text, args


def launch_browser(settings: Mapping[str, Any], url: str) -> None:
    mode = str(settings.get("mode", "system_default"))
    window_mode = str(settings.get("window_mode", "tab"))
    executable = resolve_browser_executable(mode, settings)

    if executable is None:
        webbrowser.open(url, new=1)
        return

    arguments = [str(executable)]
    if window_mode == "application" and mode in ("edge", "chrome"):
        arguments.append("--app=" + url)
    else:
        arguments.append(url)
    subprocess.Popen(
        arguments,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        shell=False,
    )


def resolve_browser_executable(
    mode: str,
    settings: Mapping[str, Any],
) -> Path | None:
    if mode == "system_default":
        return None
    if mode == "custom":
        value = str(settings.get("executable", ""))
        path = Path(value)
        if not path.is_file():
            raise RuntimeError("Custom browser executable is unavailable.")
        return path

    candidates = browser_candidates(mode)
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise RuntimeError(mode.title() + " executable was not found.")


def browser_candidates(mode: str) -> list[Path]:
    program_files = Path(os.environ.get("ProgramFiles", "C:/Program Files"))
    program_files_x86 = Path(
        os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")
    )
    local_app = Path(os.environ.get("LOCALAPPDATA", ""))
    if mode == "edge":
        return [
            program_files_x86 / "Microsoft/Edge/Application/msedge.exe",
            program_files / "Microsoft/Edge/Application/msedge.exe",
        ]
    if mode == "chrome":
        return [
            program_files / "Google/Chrome/Application/chrome.exe",
            program_files_x86 / "Google/Chrome/Application/chrome.exe",
            local_app / "Google/Chrome/Application/chrome.exe",
        ]
    if mode == "firefox":
        return [
            program_files / "Mozilla Firefox/firefox.exe",
            program_files_x86 / "Mozilla Firefox/firefox.exe",
        ]
    return []


def create_server(
    application: VelocityWebApplication,
) -> VelocityHTTPServer:
    server_config = application.configuration.local["server"]
    host = str(server_config["host"])
    port = int(server_config["port"])
    if host != "127.0.0.1":
        raise RuntimeError("VTD host must be 127.0.0.1.")
    try:
        server = VelocityHTTPServer((host, port), application)
    except OSError as error:
        raise RuntimeError(
            f"Could not bind VTD to {host}:{port}: {error}"
        ) from error
    actual_port = int(server.server_address[1])
    application.server = server
    application.identity = ServerIdentity(
        host=host,
        port=actual_port,
        session_token=secrets.token_urlsafe(32),
        csrf_token=secrets.token_urlsafe(32),
    )
    return server


def write_server_state(application: VelocityWebApplication) -> None:
    identity = application.identity
    if identity is None:
        raise RuntimeError("Server identity is unavailable.")
    value = {
        "pid": os.getpid(),
        "host": identity.host,
        "port": identity.port,
        "session_id": identity.session_token,
        "started_at": time.time(),
    }
    write_json_file(application.server_state_path, value)


def active_instance_url(state_path: Path) -> str | None:
    if not state_path.is_file():
        return None
    try:
        data = json.loads(state_path.read_text(encoding="utf-8"))
        host = str(data["host"])
        port = int(data["port"])
        token = str(data["session_id"])
        url = f"http://{host}:{port}"
        health = url + "/api/health?" + urllib.parse.urlencode(
            {"token": token}
        )
        with urllib.request.urlopen(health, timeout=0.5) as response:
            if response.status == HTTPStatus.OK:
                return url + "/?" + urllib.parse.urlencode(
                    {"token": token}
                )
    except (
        OSError,
        ValueError,
        KeyError,
        json.JSONDecodeError,
        urllib.error.URLError,
    ):
        try:
            state_path.unlink()
        except OSError:
            pass
    return None


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--print-url", action="store_true")
    return parser


def main(arguments: list[str] | None = None) -> int:
    args = build_argument_parser().parse_args(arguments)
    tools_directory = Path(__file__).resolve().parent
    state_path = tools_directory / ".test_dashboard" / "server.json"
    active_url = active_instance_url(state_path)
    if active_url is not None:
        if args.print_url:
            print(active_url)
        if not args.no_browser:
            configuration = DashboardConfiguration(tools_directory)
            launch_browser(
                configuration.public_settings()["browser"],
                active_url,
            )
        return 0

    application = VelocityWebApplication(tools_directory)
    server = create_server(application)
    write_server_state(application)
    assert application.identity is not None
    launch_url = (
        application.identity.base_url
        + "/?"
        + urllib.parse.urlencode(
            {"token": application.identity.session_token}
        )
    )
    if args.print_url:
        print(launch_url)
    if not args.no_browser:
        application.launch_browser(launch_url)

    try:
        server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        try:
            if application.server_state_path.exists():
                application.server_state_path.unlink()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
