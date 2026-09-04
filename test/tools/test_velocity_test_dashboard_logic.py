from __future__ import annotations

import json
import sys
import unittest

from pathlib import Path


TOOLS_DIRECTORY = Path(__file__).resolve().parent

if str(TOOLS_DIRECTORY) not in sys.path:
    sys.path.insert(
        0,
        str(TOOLS_DIRECTORY),
    )


from velocity_test_dashboard_logic import (  # noqa: E402
    METRICS_PREFIX,
    humanize_name,
    infer_suite,
    normalize_path,
    ordered_suites,
    parse_runner_metrics,
)


class PathAndSuiteTests(unittest.TestCase):
    def test_normalize_path(self) -> None:
        self.assertEqual(
            normalize_path(
                r".\test\core\runtime\ExampleTest.tscn"
            ),
            "test/core/runtime/ExampleTest.tscn",
        )

        self.assertEqual(
            normalize_path(
                "res://test//core/runtime/ExampleTest.tscn"
            ),
            "res://test/core/runtime/ExampleTest.tscn",
        )

    def test_humanize_names(self) -> None:
        self.assertEqual(
            humanize_name(
                "measurement_contract"
            ),
            "Measurement Contract",
        )

        self.assertEqual(
            humanize_name(
                "runtime-safety"
            ),
            "Runtime Safety",
        )

        self.assertEqual(
            humanize_name(
                "RuntimeFactoryKeyTest.tscn"
            ),
            "Runtime Factory Key",
        )

    def test_suite_aliases(self) -> None:
        aliases = {
            "runtime": "Runtime",
            "device": "DeviceCore",
        }

        self.assertEqual(
            infer_suite(
                "test/core/runtime/RuntimeFactoryKeyTest.tscn",
                ["test/core"],
                aliases,
                {},
                "RuntimeFactoryKeyTest",
            ),
            "Runtime",
        )

        self.assertEqual(
            infer_suite(
                "test/core/device/DeviceStateTest.tscn",
                ["test/core"],
                aliases,
                {},
                "DeviceStateTest",
            ),
            "DeviceCore",
        )

    def test_unknown_directory_is_humanized(
        self,
    ) -> None:
        self.assertEqual(
            infer_suite(
                "test/core/measurement_contract/MeasurementTest.tscn",
                ["test/core"],
                {},
                {},
                "MeasurementTest",
            ),
            "Measurement Contract",
        )

    def test_suite_override_has_priority(
        self,
    ) -> None:
        aliases = {
            "runtime": "Runtime",
        }

        overrides = {
            "res://test/core/runtime/SpecialTest.tscn": (
                "Special Runtime"
            ),
        }

        self.assertEqual(
            infer_suite(
                "test/core/runtime/SpecialTest.tscn",
                ["test/core"],
                aliases,
                overrides,
                "SpecialTest",
            ),
            "Special Runtime",
        )

    def test_root_level_test_uses_test_name(
        self,
    ) -> None:
        self.assertEqual(
            infer_suite(
                "test/core/MeasurementIdentityTest.tscn",
                ["test/core"],
                {},
                {},
                "MeasurementIdentityTest",
            ),
            "Measurement Identity",
        )

    def test_ordered_suites(self) -> None:
        self.assertEqual(
            ordered_suites(
                [
                    "Runtime",
                    "Other Suite",
                    "DeviceBus",
                    "Runtime",
                ],
                [
                    "DeviceBus",
                    "DeviceCore",
                    "Runtime",
                ],
            ),
            [
                "All",
                "DeviceBus",
                "Runtime",
                "Other Suite",
            ],
        )


class RunnerMetricsTests(unittest.TestCase):
    def test_valid_marker(self) -> None:
        scene = (
            "res://test/core/runtime/"
            "RuntimeFactoryKeyTest.tscn"
        )

        output = self._marker(
            {
                "version": 1,
                "scene": scene,
                "attempt": 1,
                "available": True,
                "checks": 24,
                "check_failures": 0,
            }
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
            expected_scene=scene,
        )

        self.assertEqual(
            summary.checks,
            24,
        )

        self.assertEqual(
            summary.check_failures,
            0,
        )

        self.assertEqual(
            summary.metrics_runs,
            1,
        )

        self.assertEqual(
            summary.missing_metrics,
            0,
        )

        self.assertEqual(
            summary.markers_found,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            0,
        )

        self.assertEqual(
            len(summary.attempts),
            1,
        )

        self.assertEqual(
            summary.attempts[0].attempt,
            1,
        )

    def test_unavailable_marker(self) -> None:
        output = self._marker(
            {
                "version": 1,
                "scene": "res://test/Test.tscn",
                "attempt": 1,
                "available": False,
                "checks": None,
                "check_failures": None,
            }
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
        )

        self.assertEqual(
            summary.checks,
            0,
        )

        self.assertEqual(
            summary.check_failures,
            0,
        )

        self.assertEqual(
            summary.metrics_runs,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            0,
        )

    def test_missing_marker(self) -> None:
        summary = parse_runner_metrics(
            "RESULT: PASS\n",
            expected_attempts=1,
        )

        self.assertEqual(
            summary.markers_found,
            0,
        )

        self.assertEqual(
            summary.metrics_runs,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            0,
        )

    def test_malformed_marker(self) -> None:
        output = (
            METRICS_PREFIX
            + "{invalid-json}"
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
        )

        self.assertEqual(
            summary.markers_found,
            1,
        )

        self.assertEqual(
            summary.metrics_runs,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            1,
        )

    def test_unsupported_protocol_version(
        self,
    ) -> None:
        output = self._marker(
            {
                "version": 2,
                "scene": "res://test/Test.tscn",
                "attempt": 1,
                "available": True,
                "checks": 1,
                "check_failures": 0,
            }
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
        )

        self.assertEqual(
            summary.metrics_runs,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            1,
        )

    def test_wrong_scene_is_protocol_error(
        self,
    ) -> None:
        output = self._marker(
            {
                "version": 1,
                "scene": "res://test/WrongTest.tscn",
                "attempt": 1,
                "available": True,
                "checks": 5,
                "check_failures": 0,
            }
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
            expected_scene=(
                "res://test/ExpectedTest.tscn"
            ),
        )

        self.assertEqual(
            summary.checks,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            1,
        )

    def test_repeat_metrics_are_aggregated(
        self,
    ) -> None:
        scene = "res://test/RepeatedTest.tscn"

        output = "\n".join(
            [
                self._marker(
                    {
                        "version": 1,
                        "scene": scene,
                        "attempt": 1,
                        "available": True,
                        "checks": 10,
                        "check_failures": 0,
                    }
                ),
                self._marker(
                    {
                        "version": 1,
                        "scene": scene,
                        "attempt": 2,
                        "available": True,
                        "checks": 12,
                        "check_failures": 1,
                    }
                ),
            ]
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=2,
            expected_scene=scene,
        )

        self.assertEqual(
            summary.checks,
            22,
        )

        self.assertEqual(
            summary.check_failures,
            1,
        )

        self.assertEqual(
            summary.metrics_runs,
            2,
        )

        self.assertEqual(
            summary.missing_metrics,
            0,
        )

        self.assertEqual(
            summary.protocol_errors,
            0,
        )

    def test_duplicate_attempt_is_protocol_error(
        self,
    ) -> None:
        payload = {
            "version": 1,
            "scene": "res://test/DuplicateTest.tscn",
            "attempt": 1,
            "available": True,
            "checks": 8,
            "check_failures": 0,
        }

        output = "\n".join(
            [
                self._marker(payload),
                self._marker(payload),
            ]
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
        )

        self.assertEqual(
            summary.checks,
            8,
        )

        self.assertEqual(
            summary.metrics_runs,
            1,
        )

        self.assertEqual(
            summary.missing_metrics,
            0,
        )

        self.assertEqual(
            summary.markers_found,
            2,
        )

        self.assertEqual(
            summary.protocol_errors,
            1,
        )

    def test_attempt_over_expected_count_is_rejected(
        self,
    ) -> None:
        output = self._marker(
            {
                "version": 1,
                "scene": "res://test/ExtraTest.tscn",
                "attempt": 2,
                "available": True,
                "checks": 4,
                "check_failures": 0,
            }
        )

        summary = parse_runner_metrics(
            output,
            expected_attempts=1,
        )

        self.assertEqual(
            summary.checks,
            0,
        )

        self.assertEqual(
            summary.metrics_runs,
            0,
        )

        self.assertEqual(
            summary.missing_metrics,
            1,
        )

        self.assertEqual(
            summary.protocol_errors,
            1,
        )

    def test_invalid_metric_values_are_rejected(
        self,
    ) -> None:
        boolean_checks = self._marker(
            {
                "version": 1,
                "scene": "res://test/BooleanTest.tscn",
                "attempt": 1,
                "available": True,
                "checks": True,
                "check_failures": 0,
            }
        )

        unavailable_with_values = self._marker(
            {
                "version": 1,
                "scene": "res://test/UnavailableTest.tscn",
                "attempt": 1,
                "available": False,
                "checks": 0,
                "check_failures": 0,
            }
        )

        first_summary = parse_runner_metrics(
            boolean_checks,
            expected_attempts=1,
        )

        second_summary = parse_runner_metrics(
            unavailable_with_values,
            expected_attempts=1,
        )

        self.assertEqual(
            first_summary.protocol_errors,
            1,
        )

        self.assertEqual(
            first_summary.missing_metrics,
            1,
        )

        self.assertEqual(
            second_summary.protocol_errors,
            1,
        )

        self.assertEqual(
            second_summary.missing_metrics,
            1,
        )

    @staticmethod
    def _marker(
        payload: dict[str, object],
    ) -> str:
        return (
            METRICS_PREFIX
            + json.dumps(
                payload,
                separators=(",", ":"),
            )
        )


if __name__ == "__main__":
    unittest.main()