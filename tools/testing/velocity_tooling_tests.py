from __future__ import annotations

import argparse
import importlib
import sys
import time
import unittest

from pathlib import Path
from typing import Sequence


TOOL_VERSION = "1.0.2"
TOOLING_TEST_VERBOSITY = 2
PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLING_TEST_FILES = (
    "test_velocity_submit.py",
    "test_velocity_dashboard_web.py",
    "test_velocity_test_dashboard_logic.py",
)


def get_tooling_test_module_names() -> tuple[str, ...]:
    return tuple(
        Path(filename).stem
        for filename in TOOLING_TEST_FILES
    )


def load_tooling_test_suite(
    project_root: Path = PROJECT_ROOT,
) -> unittest.TestSuite:
    root = project_root.resolve()
    test_tools_directory = root / "test" / "tools"

    if not test_tools_directory.is_dir():
        raise FileNotFoundError(
            "test/tools directory was not found."
        )

    tools_path = str(test_tools_directory)
    if tools_path not in sys.path:
        sys.path.insert(0, tools_path)

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    for module_name in get_tooling_test_module_names():
        module = importlib.import_module(module_name)
        suite.addTests(loader.loadTestsFromModule(module))

    return suite


def run_tooling_tests(
    *,
    project_root: Path = PROJECT_ROOT,
) -> int:
    root = project_root.resolve()

    if not (root / "project.godot").is_file():
        print("VELOCITY TOOLING TESTS: PROJECT_ERROR", flush=True)
        print("project.godot was not found.", flush=True)
        return 2

    started = time.monotonic()
    module_names = get_tooling_test_module_names()

    print("VELOCITY TOOLING TEST PLAN", flush=True)
    print("==========================", flush=True)
    print("Modules: " + str(len(module_names)), flush=True)
    for module_name in module_names:
        print("- " + module_name, flush=True)
    print("", flush=True)

    try:
        suite = load_tooling_test_suite(root)
    except (ImportError, OSError) as error:
        print("TOOLING TEST LOAD ERROR: " + str(error), flush=True)
        print("", flush=True)
        print("VELOCITY TOOLING TEST SUMMARY", flush=True)
        print("=============================", flush=True)
        print("Modules: " + str(len(module_names)), flush=True)
        print("ExitCode: 2", flush=True)
        print("RESULT: FAIL", flush=True)
        return 2

    result = unittest.TextTestRunner(
        stream=sys.stderr,
        verbosity=TOOLING_TEST_VERBOSITY,
    ).run(suite)
    duration = time.monotonic() - started
    exit_code = 0 if result.wasSuccessful() else 1
    final_result = "PASS" if exit_code == 0 else "FAIL"

    print("", flush=True)
    print("VELOCITY TOOLING TEST SUMMARY", flush=True)
    print("=============================", flush=True)
    print("Modules: " + str(len(module_names)), flush=True)
    print("TestsRun: " + str(result.testsRun), flush=True)
    print("Failures: " + str(len(result.failures)), flush=True)
    print("Errors: " + str(len(result.errors)), flush=True)
    print("Skipped: " + str(len(result.skipped)), flush=True)
    print("DurationSeconds: " + f"{duration:.3f}", flush=True)
    print("ExitCode: " + str(exit_code), flush=True)
    print("RESULT: " + final_result, flush=True)
    return exit_code


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run the canonical Velocity tooling test baseline."
    )
    parser.add_argument(
        "--version",
        action="version",
        version="Velocity Tooling Tests " + TOOL_VERSION,
    )
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    build_argument_parser().parse_args(arguments)
    return run_tooling_tests()


if __name__ == "__main__":
    sys.exit(main())
