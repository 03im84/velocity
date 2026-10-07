from __future__ import annotations

import http.cookiejar
import json
import queue
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

from pathlib import Path
from unittest import mock


TOOLS_DIRECTORY = Path(__file__).resolve().parent
PROJECT_ROOT = TOOLS_DIRECTORY.parents[1]

if str(TOOLS_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIRECTORY))

from velocity_dashboard_service import (  # noqa: E402
    DEFAULT_LOCAL_CONFIG,
    DashboardConfiguration,
    EventBroker,
    PlanResult,
    TestScene,
    build_execution_summary,
    deep_merge,
    discover_tests,
    load_roadmap,
    parse_runner_summary,
    status_from_output,
    suite_names,
    validate_local_config,
    validate_roadmap,
)
from velocity_dashboard_delivery import DeliveryService  # noqa: E402
from velocity_submit_contract import ExitCode  # noqa: E402
from velocity_dashboard_web import (  # noqa: E402
    STATIC_ALLOWLIST,
    VelocityWebApplication,
    create_server,
    resolve_event_resume_cursor,
)


class ConfigurationTests(unittest.TestCase):
    def test_deep_merge_preserves_nested_defaults(self) -> None:
        merged = deep_merge(
            DEFAULT_LOCAL_CONFIG,
            {
                "theme": "reading",
                "browser": {"mode": "firefox"},
            },
        )
        self.assertEqual(merged["theme"], "reading")
        self.assertEqual(merged["browser"]["mode"], "firefox")
        self.assertEqual(merged["browser"]["window_mode"], "tab")
        self.assertEqual(merged["server"]["host"], "127.0.0.1")

    def test_three_themes_are_valid(self) -> None:
        for theme in ("light", "dark", "reading"):
            config = deep_merge(DEFAULT_LOCAL_CONFIG, {"theme": theme})
            validate_local_config(config)

    def test_unknown_theme_is_rejected(self) -> None:
        config = deep_merge(DEFAULT_LOCAL_CONFIG, {"theme": "neon"})
        with self.assertRaises(ValueError):
            validate_local_config(config)

    def test_browser_modes_are_valid(self) -> None:
        for mode in (
            "system_default",
            "edge",
            "chrome",
            "firefox",
        ):
            config = deep_merge(
                DEFAULT_LOCAL_CONFIG,
                {"browser": {"mode": mode}},
            )
            validate_local_config(config)

    def test_custom_browser_requires_path(self) -> None:
        config = deep_merge(
            DEFAULT_LOCAL_CONFIG,
            {"browser": {"mode": "custom"}},
        )
        with self.assertRaises(ValueError):
            validate_local_config(config)

    def test_host_cannot_be_exposed(self) -> None:
        config = deep_merge(
            DEFAULT_LOCAL_CONFIG,
            {"server": {"host": "0.0.0.0"}},
        )
        with self.assertRaises(ValueError):
            validate_local_config(config)

    def test_port_zero_and_explicit_are_valid(self) -> None:
        for port in (0, 1024, 8000, 65535):
            config = deep_merge(
                DEFAULT_LOCAL_CONFIG,
                {"server": {"port": port}},
            )
            validate_local_config(config)

    def test_invalid_port_is_rejected(self) -> None:
        for port in (1, 1023, 65536):
            config = deep_merge(
                DEFAULT_LOCAL_CONFIG,
                {"server": {"port": port}},
            )
            with self.assertRaises(ValueError):
                validate_local_config(config)

    def test_local_json_is_written_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            tools = Path(temporary) / "test" / "tools"
            tools.mkdir(parents=True)
            (tools / "test_dashboard.json").write_text(
                json.dumps(
                    {
                        "project_root": "../..",
                        "runner": "test/tools/run_godot_tests.ps1",
                        "test_roots": ["test/core"],
                    }
                ),
                encoding="utf-8",
            )
            project = tools.parents[1]
            (project / "test" / "core").mkdir(parents=True)
            configuration = DashboardConfiguration(tools)
            configuration.local["theme"] = "light"
            configuration.save_local()
            loaded = json.loads(
                configuration.local_path.read_text(encoding="utf-8")
            )
            self.assertEqual(loaded["theme"], "light")
            self.assertFalse(
                configuration.local_path.with_suffix(".json.tmp").exists()
            )


class DiscoveryAndLogicTests(unittest.TestCase):
    def setUp(self) -> None:
        self.configuration = DashboardConfiguration(TOOLS_DIRECTORY)

    def test_web_candidate_discovers_current_tests(self) -> None:
        tests = discover_tests(self.configuration)
        self.assertGreaterEqual(len(tests), 85)
        self.assertTrue(
            any(test.name == "ManagedRuntimeAdapterIntegrationTest" for test in tests)
        )

    def test_suite_order_preserves_runtime(self) -> None:
        tests = discover_tests(self.configuration)
        suites = suite_names(self.configuration, tests)
        self.assertEqual(suites[0], "All")
        self.assertIn("Runtime", suites)
        self.assertIn("Composition", suites)

    def test_runner_status_mapping(self) -> None:
        self.assertEqual(status_from_output(0, "RESULT: PASS"), "PASS")
        self.assertEqual(status_from_output(124, "TIMEOUT"), "TIMEOUT")
        self.assertEqual(
            status_from_output(126, "ENGINE_ERROR"),
            "ENGINE_ERROR",
        )
        self.assertEqual(status_from_output(1, "RESULT: FAIL"), "FAIL")

    def test_runner_summary_uses_last_values(self) -> None:
        summary = parse_runner_summary(
            "Total runs: 1\nPassed: 1\nFailed: 0\n"
            "Total runs: 2\nPassed: 2\nFailed: 0\n"
        )
        self.assertEqual(summary["total_runs"], 2)
        self.assertEqual(summary["passed"], 2)
        self.assertEqual(summary["failed"], 0)

    def test_event_broker_replays_after_event_id(self) -> None:
        broker = EventBroker()
        first = broker.publish("output", {"text": "one"})
        second = broker.publish("output", {"text": "two"})
        subscriber = broker.subscribe(first.event_id)
        replayed = subscriber.get(timeout=0.2)
        self.assertEqual(replayed.event_id, second.event_id)
        self.assertEqual(replayed.data["text"], "two")
        broker.unsubscribe(subscriber)

    def test_fresh_event_cursor_skips_history_and_receives_live(self) -> None:
        broker = EventBroker()
        broker.publish("delivery_prompt", {"prompt": "old"})
        cursor = broker.get_latest_event_id()
        subscriber = broker.subscribe(cursor)

        with self.assertRaises(queue.Empty):
            subscriber.get_nowait()

        live = broker.publish("delivery_state", {"busy": False})
        received = subscriber.get(timeout=0.2)
        self.assertEqual(received.event_id, live.event_id)
        self.assertEqual(received.event_type, "delivery_state")
        broker.unsubscribe(subscriber)

    def test_event_cursor_prefers_resume_values(self) -> None:
        self.assertEqual(
            resolve_event_resume_cursor(None, None, 12),
            12,
        )
        self.assertEqual(
            resolve_event_resume_cursor("9", "7", 12),
            9,
        )
        self.assertEqual(
            resolve_event_resume_cursor("invalid", "7", 12),
            7,
        )

    def test_public_plan_result_excludes_raw_output(self) -> None:
        test = TestScene(
            name="ExampleTest",
            resource_path="res://test/ExampleTest.tscn",
            filesystem_path=Path("test/ExampleTest.tscn"),
            relative_path="test/ExampleTest.tscn",
            suite="Example",
        )
        result = PlanResult(test=test, output="very large output")
        public = result.to_dict()
        self.assertNotIn("output", public)
        self.assertEqual(public["test"]["name"], "ExampleTest")

    def test_execution_summary_contains_authoritative_metrics(self) -> None:
        test = TestScene(
            name="ExampleTest",
            resource_path="res://test/ExampleTest.tscn",
            filesystem_path=Path("test/ExampleTest.tscn"),
            relative_path="test/ExampleTest.tscn",
            suite="Example",
        )
        result = PlanResult(
            test=test,
            status="PASS",
            exit_code=0,
            total_runs=1,
            passed=1,
            checks=12,
            check_failures=0,
            metrics_runs=1,
        )
        summary = build_execution_summary([result], "PASS")
        self.assertEqual(summary["planned"], 1)
        self.assertEqual(summary["completed"], 1)
        self.assertEqual(summary["passed"], 1)
        self.assertEqual(summary["timeout"], 0)
        self.assertEqual(summary["engine_error"], 0)
        self.assertEqual(summary["not_run"], 0)
        self.assertEqual(summary["total_runs"], 1)
        self.assertEqual(summary["checks"], 12)
        self.assertEqual(summary["plan_exit_code"], 0)
        self.assertEqual(summary["result"], "PASS")


class RoadmapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.configuration = DashboardConfiguration(TOOLS_DIRECTORY)

    def test_versioned_roadmap_is_valid(self) -> None:
        roadmap = load_roadmap(self.configuration)
        self.assertEqual(roadmap["schema"], "velocity-roadmap/v1")
        self.assertEqual(roadmap["version"], "1.3")
        self.assertEqual(roadmap["target"], "playable_vertical_slice")
        self.assertEqual(
            roadmap["current_milestone"],
            "vehicle_composition",
        )
        self.assertGreaterEqual(len(roadmap["milestones"]), 10)
        input_milestone = next(
            item
            for item in roadmap["milestones"]
            if item["id"] == "input_runtime_slice"
        )
        self.assertEqual(input_milestone["status"], "completed")
        self.assertEqual(input_milestone["progress"], 100)
        self.assertEqual(input_milestone["commit"], "80c5118")
        propulsion_milestone = next(
            item
            for item in roadmap["milestones"]
            if item["id"] == "propulsion_runtime_slice"
        )
        self.assertEqual(propulsion_milestone["status"], "completed")
        self.assertEqual(propulsion_milestone["progress"], 100)
        self.assertEqual(propulsion_milestone["commit"], "bc838d8")
        hover_milestone = next(
            item
            for item in roadmap["milestones"]
            if item["id"] == "hover_physics_slice"
        )
        self.assertEqual(hover_milestone["status"], "completed")
        self.assertEqual(hover_milestone["progress"], 100)
        self.assertEqual(hover_milestone["commit"], "adca199")

    def test_current_milestone_is_active(self) -> None:
        roadmap = load_roadmap(self.configuration)
        current = next(
            item
            for item in roadmap["milestones"]
            if item["id"] == roadmap["current_milestone"]
        )
        self.assertEqual(current["status"], "active")
        self.assertEqual(current["progress"], 0)

    def test_unknown_dependency_is_rejected(self) -> None:
        roadmap = load_roadmap(self.configuration)
        copied = json.loads(json.dumps(roadmap))
        copied["milestones"][0]["dependencies"] = ["missing"]
        with self.assertRaises(ValueError):
            validate_roadmap(copied)

    def test_delivery_refresh_reloads_roadmap_and_publishes(self) -> None:
        application = VelocityWebApplication(TOOLS_DIRECTORY)
        updated = load_roadmap(self.configuration)
        updated["version"] = "test-refresh"
        cursor = application.broker.get_latest_event_id()
        subscriber = application.broker.subscribe(cursor)

        with mock.patch(
            "velocity_dashboard_web.load_roadmap",
            return_value=updated,
        ):
            application.refresh_after_delivery_install()

        events = [
            subscriber.get(timeout=0.2),
            subscriber.get(timeout=0.2),
        ]
        roadmap_event = next(
            event
            for event in events
            if event.event_type == "roadmap_updated"
        )
        self.assertEqual(application.roadmap["version"], "test-refresh")
        self.assertEqual(roadmap_event.data["version"], "test-refresh")
        application.broker.unsubscribe(subscriber)


class DeliveryBridgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.project = Path(self.temporary.name)
        self.broker = EventBroker()
        self.refresh_count = 0
        self.service = DeliveryService(
            self.project,
            self.broker,
            self._refresh,
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _refresh(self) -> None:
        self.refresh_count += 1

    def test_native_selection_updates_state(self) -> None:
        package = self.project.with_suffix(".zip")
        package.write_bytes(b"zip")
        with mock.patch(
            "velocity_dashboard_delivery.run_native_picker",
            return_value=package,
        ):
            selected = self.service.select_package()
        self.assertEqual(selected, str(package))
        self.assertEqual(
            self.service.snapshot()["selected_package"],
            str(package),
        )
        package.unlink()

    def test_install_runs_in_worker_and_refreshes(self) -> None:
        package = self.project.with_suffix(".zip")
        package.write_bytes(b"zip")
        with mock.patch(
            "velocity_dashboard_delivery.run_native_picker",
            return_value=package,
        ):
            self.service.select_package()

        def fake_run_tool(**kwargs: object) -> ExitCode:
            output = kwargs["output_function"]
            assert callable(output)
            output("install complete")
            return ExitCode.PASS

        with mock.patch(
            "velocity_dashboard_delivery.run_tool",
            side_effect=fake_run_tool,
        ):
            self.service.start_install()
            self.assertTrue(self.service.wait(1.0))

        snapshot = self.service.snapshot()
        self.assertEqual(snapshot["operation"], "COMPLETE")
        self.assertEqual(snapshot["last_result"], "PASS")
        self.assertEqual(self.refresh_count, 1)
        package.unlink()

    def test_rollback_runs_in_worker(self) -> None:
        captured: dict[str, object] = {}

        def fake_run_tool(**kwargs: object) -> ExitCode:
            captured.update(kwargs)
            output = kwargs["output_function"]
            assert callable(output)
            output("VELOCITY DELIVERY ROLLBACK: PASS")
            return ExitCode.PASS

        with mock.patch(
            "velocity_dashboard_delivery.run_tool",
            side_effect=fake_run_tool,
        ):
            self.service.start_rollback()
            self.assertTrue(self.service.wait(1.0))

        self.assertEqual(captured["mode"], "rollback")
        self.assertIsNone(captured["package_path"])
        snapshot = self.service.snapshot()
        self.assertEqual(snapshot["operation"], "COMPLETE")
        self.assertEqual(snapshot["last_result"], "PASS")
        self.assertEqual(self.refresh_count, 0)

    def test_rollback_prompt_waits_for_ui_answer(self) -> None:
        answers: list[str] = []

        def fake_run_tool(**kwargs: object) -> ExitCode:
            input_function = kwargs["input_function"]
            assert callable(input_function)
            answers.append(
                input_function("Type ROLLBACK to restore")
            )
            return ExitCode.PASS

        with mock.patch(
            "velocity_dashboard_delivery.run_tool",
            side_effect=fake_run_tool,
        ):
            self.service.start_rollback()
            for _ in range(50):
                if self.service.snapshot()["pending_prompt"]:
                    break
                threading.Event().wait(0.01)
            self.assertIn(
                "ROLLBACK",
                self.service.snapshot()["pending_prompt"],
            )
            self.service.answer_prompt("ROLLBACK")
            self.assertTrue(self.service.wait(1.0))

        self.assertEqual(answers, ["ROLLBACK"])

    def test_submit_prompt_waits_for_ui_answer(self) -> None:
        answers: list[str] = []

        def fake_run_tool(**kwargs: object) -> ExitCode:
            input_function = kwargs["input_function"]
            assert callable(input_function)
            answers.append(input_function("Type SUBMIT now"))
            return ExitCode.PASS

        with mock.patch(
            "velocity_dashboard_delivery.run_tool",
            side_effect=fake_run_tool,
        ):
            self.service.start_submit()
            for _ in range(50):
                if self.service.snapshot()["pending_prompt"]:
                    break
                threading.Event().wait(0.01)
            self.assertIn(
                "SUBMIT",
                self.service.snapshot()["pending_prompt"],
            )
            self.service.answer_prompt("SUBMIT")
            self.assertTrue(self.service.wait(1.0))

        self.assertEqual(answers, ["SUBMIT"])
        self.assertEqual(
            self.service.snapshot()["last_result"],
            "PASS",
        )


class StaticFrontendContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        web = TOOLS_DIRECTORY / "web"
        cls.html = (web / "index.html").read_text(encoding="utf-8")
        cls.css = (web / "styles.css").read_text(encoding="utf-8")
        cls.js = (web / "app.js").read_text(encoding="utf-8")
        cls.runner = (
            TOOLS_DIRECTORY / "run_godot_tests.ps1"
        ).read_text(encoding="utf-8")
        cls.git_tool = (
            PROJECT_ROOT / "tools" / "git" / "velocity_submit_git.py"
        ).read_text(encoding="utf-8")
        cls.delivery_bridge = (
            TOOLS_DIRECTORY / "velocity_dashboard_delivery.py"
        ).read_text(encoding="utf-8")

    def test_required_tabs_exist(self) -> None:
        for tab in ("tests", "delivery", "history", "roadmap", "settings"):
            self.assertIn(f'data-tab="{tab}"', self.html)

    def test_roadmap_gantt_contract_exists(self) -> None:
        self.assertIn('id="gantt-grid"', self.html)
        self.assertIn('id="milestone-detail"', self.html)
        self.assertIn("renderRoadmap", self.js)
        self.assertIn("YOU ARE HERE", self.js)

    def test_reload_safety_contract_exists(self) -> None:
        self.assertIn("event_cursor", self.js)
        self.assertIn("/api/events?after=", self.js)
        self.assertIn("handleDeliveryPrompt", self.js)
        self.assertIn('api("/api/state")', self.js)
        self.assertIn("state.delivery.pending_prompt", self.js)
        self.assertIn('"roadmap_updated"', self.js)

    def test_browser_uses_select(self) -> None:
        self.assertIn('<select id="browser-select">', self.html)
        for mode in (
            "system_default",
            "edge",
            "chrome",
            "firefox",
            "custom",
        ):
            self.assertIn(f'value="{mode}"', self.html)

    def test_shutdown_button_exists(self) -> None:
        self.assertIn('id="shutdown-button"', self.html)
        self.assertIn("/api/shutdown/request", self.js)

    def test_three_theme_blocks_exist(self) -> None:
        for theme in ("light", "dark", "reading"):
            self.assertIn(f'data-theme="{theme}"', self.css)
            self.assertIn(f'value="{theme}"', self.html)

    def test_frontend_has_no_external_assets(self) -> None:
        self.assertNotIn("https://", self.html)
        self.assertNotIn("http://", self.html)
        self.assertNotIn("@import", self.css)

    def test_delivery_endpoints_are_wired(self) -> None:
        for endpoint in (
            "/api/delivery/select",
            "/api/delivery/install",
            "/api/delivery/prepare-submit",
            "/api/delivery/rollback",
            "/api/delivery/answer",
        ):
            self.assertIn(endpoint, self.js)

    def test_rollback_control_contract(self) -> None:
        self.assertIn('id="rollback-delivery"', self.html)
        self.assertIn(
            'receipt_state !== "installed"',
            self.js,
        )
        self.assertIn(
            'promptText.includes("ROLLBACK")',
            self.js,
        )
        self.assertIn(
            "start_rollback",
            self.delivery_bridge,
        )

    def test_delivery_layout_and_environment_version(self) -> None:
        self.assertIn('id="env-version"', self.html)
        self.assertIn("state.app = data.app", self.js)
        self.assertIn('$("#env-version")', self.js)
        self.assertIn('$("#env-delivery").title', self.js)
        self.assertIn(
            "grid-template-columns: repeat(4, max-content);",
            self.css,
        )

    def test_terminal_preserves_fixed_width_formatting(self) -> None:
        self.assertIn("white-space: pre;", self.css)
        self.assertNotIn("white-space: pre-wrap;", self.css)

    def test_clear_controls_and_batched_output_exist(self) -> None:
        for control in (
            'id="clear-test-output"',
            'id="clear-delivery-output"',
            'id="clear-history"',
        ):
            self.assertIn(control, self.html)
        self.assertIn("outputQueues", self.js)
        self.assertIn("flushOutput", self.js)
        self.assertIn("document.createTextNode", self.js)

    def test_runner_summary_is_width_independent(self) -> None:
        self.assertNotIn("Format-Table", self.runner)
        self.assertIn('Write-Host "Scene:', self.runner)
        self.assertIn("Metrics Available:", self.runner)

    def test_windows_console_children_are_hidden(self) -> None:
        self.assertIn("CREATE_NO_WINDOW", self.git_tool)
        self.assertIn(
            "hidden_subprocess_options",
            self.delivery_bridge,
        )

    def test_authoritative_final_summary_is_rendered(self) -> None:
        self.assertIn('id="final-summary"', self.html)
        self.assertIn("DASHBOARD EXECUTION PLAN SUMMARY", self.js)
        for field in (
            "Planned:",
            "Completed:",
            "Passed:",
            "Failed:",
            "Timeout:",
            "Engine Error:",
            "Not Run:",
            "Total Runs:",
            "Checks:",
            "Check Failures:",
            "Missing Metrics:",
            "Plan ExitCode:",
            "RESULT:",
        ):
            self.assertIn(field, self.js)


class HttpSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.application = VelocityWebApplication(TOOLS_DIRECTORY)
        cls.server = create_server(cls.application)
        cls.thread = threading.Thread(
            target=cls.server.serve_forever,
            kwargs={"poll_interval": 0.05},
            daemon=True,
        )
        cls.thread.start()
        assert cls.application.identity is not None
        cls.base_url = cls.application.identity.base_url
        cls.token = cls.application.identity.session_token

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=1.0)

    def _opener(self) -> urllib.request.OpenerDirector:
        jar = http.cookiejar.CookieJar()
        return urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(jar)
        )

    def test_unauthenticated_bootstrap_is_forbidden(self) -> None:
        with self.assertRaises(urllib.error.HTTPError) as context:
            urllib.request.urlopen(
                self.base_url + "/api/bootstrap",
                timeout=1.0,
            )
        self.assertEqual(context.exception.code, 403)

    def test_token_bootstrap_sets_cookie_and_returns_state(self) -> None:
        opener = self._opener()
        response = opener.open(
            self.base_url + "/?token=" + self.token,
            timeout=1.0,
        )
        self.assertEqual(response.status, 200)
        data = json.load(
            opener.open(
                self.base_url + "/api/bootstrap",
                timeout=1.0,
            )
        )
        self.assertEqual(data["app"]["version"], "0.5.2")
        self.assertEqual(data["server"]["host"], "127.0.0.1")
        self.assertGreaterEqual(len(data["tests"]), 85)
        self.assertIsInstance(data["event_cursor"], int)
        self.assertGreaterEqual(data["event_cursor"], 0)
        self.assertEqual(
            data["roadmap"]["target"],
            "playable_vertical_slice",
        )
        self.assertTrue(data["csrf_token"])

    def test_post_requires_csrf(self) -> None:
        opener = self._opener()
        opener.open(self.base_url + "/?token=" + self.token, timeout=1.0)
        request = urllib.request.Request(
            self.base_url + "/api/tests/refresh",
            data=b"{}",
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Origin": self.base_url,
            },
        )
        with self.assertRaises(urllib.error.HTTPError) as context:
            opener.open(request, timeout=1.0)
        self.assertEqual(context.exception.code, 403)

    def test_valid_csrf_allows_refresh(self) -> None:
        opener = self._opener()
        opener.open(self.base_url + "/?token=" + self.token, timeout=1.0)
        bootstrap = json.load(
            opener.open(
                self.base_url + "/api/bootstrap",
                timeout=1.0,
            )
        )
        request = urllib.request.Request(
            self.base_url + "/api/tests/refresh",
            data=b"{}",
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Origin": self.base_url,
                "X-VTD-CSRF": bootstrap["csrf_token"],
            },
        )
        response = json.load(opener.open(request, timeout=2.0))
        self.assertGreaterEqual(len(response["tests"]), 76)

    def test_security_headers_are_present(self) -> None:
        opener = self._opener()
        response = opener.open(
            self.base_url + "/?token=" + self.token,
            timeout=1.0,
        )
        self.assertEqual(response.headers["X-Frame-Options"], "DENY")
        self.assertIn(
            "default-src 'self'",
            response.headers["Content-Security-Policy"],
        )
        self.assertEqual(
            response.headers["X-Content-Type-Options"],
            "nosniff",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
