from __future__ import annotations

import json
import re

from dataclasses import dataclass
from typing import Mapping, Sequence


METRICS_PREFIX = "VELOCITY_TEST_METRICS_JSON:"
METRICS_PROTOCOL_VERSION = 1


@dataclass(frozen=True, slots=True)
class RunnerAttemptMetrics:
    version: int
    scene: str
    attempt: int
    available: bool
    checks: int | None
    check_failures: int | None


@dataclass(frozen=True, slots=True)
class RunnerMetricsSummary:
    attempts: tuple[RunnerAttemptMetrics, ...]
    checks: int
    check_failures: int
    metrics_runs: int
    missing_metrics: int
    markers_found: int
    protocol_errors: int


def normalize_path(value: str) -> str:
    text = str(value).strip().replace("\\", "/")

    if not text:
        return ""

    is_resource_path = text.lower().startswith(
        "res://"
    )

    if is_resource_path:
        text = text[6:]

    while text.startswith("./"):
        text = text[2:]

    text = re.sub(
        r"/+",
        "/",
        text,
    )

    text = text.strip("/")

    if is_resource_path:
        return "res://" + text

    return text


def humanize_name(value: str) -> str:
    text = normalize_path(value)

    if text.lower().startswith("res://"):
        text = text[6:]

    if "/" in text:
        text = text.rsplit(
            "/",
            1,
        )[-1]

    if "." in text:
        text = text.rsplit(
            ".",
            1,
        )[0]

    text = re.sub(
        r"(?i)(?:[_\-\s]?test)$",
        "",
        text,
    )

    text = re.sub(
        r"(?<=[a-z0-9])(?=[A-Z])",
        " ",
        text,
    )

    text = text.replace(
        "_",
        " ",
    )

    text = text.replace(
        "-",
        " ",
    )

    text = re.sub(
        r"\s+",
        " ",
        text,
    ).strip()

    if not text:
        return "Other"

    return " ".join(
        word[:1].upper() + word[1:]
        for word in text.split(" ")
        if word
    )


def infer_suite(
    relative_path: str,
    test_roots: Sequence[str],
    suite_aliases: Mapping[str, str],
    suite_overrides: Mapping[str, str],
    test_name: str = "",
) -> str:
    normalized_path = normalize_path(
        relative_path
    )

    if normalized_path.lower().startswith(
        "res://"
    ):
        normalized_relative = normalized_path[6:]
    else:
        normalized_relative = normalized_path

    override = _suite_override_for(
        normalized_relative,
        suite_overrides,
    )

    if override:
        return override

    matching_roots = sorted(
        (
            normalize_path(root)[6:]
            if normalize_path(root).lower().startswith(
                "res://"
            )
            else normalize_path(root)
            for root in test_roots
        ),
        key=len,
        reverse=True,
    )

    relative_under_root = normalized_relative

    for root in matching_roots:
        if not root:
            continue

        if normalized_relative == root:
            relative_under_root = ""
            break

        root_prefix = root.rstrip("/") + "/"

        if normalized_relative.startswith(
            root_prefix
        ):
            relative_under_root = (
                normalized_relative[
                    len(root_prefix):
                ]
            )
            break

    path_parts = [
        part
        for part in relative_under_root.split(
            "/"
        )
        if part
    ]

    if len(path_parts) >= 2:
        directory_name = path_parts[0]

        alias_key = _normalize_alias_key(
            directory_name
        )

        alias = str(
            suite_aliases.get(
                alias_key,
                "",
            )
        ).strip()

        if alias:
            return alias

        return humanize_name(
            directory_name
        )

    fallback_name = test_name.strip()

    if not fallback_name and path_parts:
        fallback_name = path_parts[-1]

    if fallback_name:
        return humanize_name(
            fallback_name
        )

    return "Other"


def ordered_suites(
    discovered_suites: Sequence[str],
    configured_order: Sequence[str],
) -> list[str]:
    discovered_by_lower: dict[str, str] = {}

    for suite in discovered_suites:
        clean_suite = str(suite).strip()

        if not clean_suite:
            continue

        if clean_suite.lower() == "all":
            continue

        discovered_by_lower.setdefault(
            clean_suite.lower(),
            clean_suite,
        )

    result = ["All"]

    for configured_suite in configured_order:
        clean_suite = str(
            configured_suite
        ).strip()

        key = clean_suite.lower()

        if key in discovered_by_lower:
            result.append(
                discovered_by_lower.pop(key)
            )

    remaining = sorted(
        discovered_by_lower.values(),
        key=str.lower,
    )

    result.extend(
        remaining
    )

    return result


def parse_runner_metrics(
    output: str,
    expected_attempts: int,
    expected_scene: str = "",
) -> RunnerMetricsSummary:
    expected_count = max(
        0,
        int(expected_attempts),
    )

    normalized_expected_scene = normalize_path(
        expected_scene
    )

    attempts_by_number: dict[
        int,
        RunnerAttemptMetrics,
    ] = {}

    markers_found = 0
    protocol_errors = 0

    for line in output.splitlines():
        stripped_line = line.strip()

        if not stripped_line.startswith(
            METRICS_PREFIX
        ):
            continue

        markers_found += 1

        payload_text = stripped_line[
            len(METRICS_PREFIX):
        ].strip()

        try:
            metrics = _parse_metrics_payload(
                payload_text
            )
        except (
            TypeError,
            ValueError,
            json.JSONDecodeError,
        ):
            protocol_errors += 1
            continue

        if (
            expected_count > 0
            and metrics.attempt > expected_count
        ):
            protocol_errors += 1
            continue

        if (
            normalized_expected_scene
            and normalize_path(metrics.scene)
            != normalized_expected_scene
        ):
            protocol_errors += 1
            continue

        if metrics.attempt in attempts_by_number:
            protocol_errors += 1
            continue

        attempts_by_number[
            metrics.attempt
        ] = metrics

    ordered_attempts = tuple(
        attempts_by_number[attempt]
        for attempt in sorted(
            attempts_by_number
        )
    )

    checks = sum(
        metrics.checks or 0
        for metrics in ordered_attempts
        if metrics.available
    )

    check_failures = sum(
        metrics.check_failures or 0
        for metrics in ordered_attempts
        if metrics.available
    )

    metrics_runs = sum(
        metrics.available
        for metrics in ordered_attempts
    )

    unavailable_metrics = sum(
        not metrics.available
        for metrics in ordered_attempts
    )

    missing_markers = max(
        expected_count
        - len(ordered_attempts),
        0,
    )

    missing_metrics = (
        unavailable_metrics
        + missing_markers
    )

    return RunnerMetricsSummary(
        attempts=ordered_attempts,
        checks=checks,
        check_failures=check_failures,
        metrics_runs=metrics_runs,
        missing_metrics=missing_metrics,
        markers_found=markers_found,
        protocol_errors=protocol_errors,
    )


def _parse_metrics_payload(
    payload_text: str,
) -> RunnerAttemptMetrics:
    payload = json.loads(
        payload_text
    )

    if not isinstance(payload, dict):
        raise ValueError(
            "Metrics payload must be an object."
        )

    version = payload.get("version")
    scene = payload.get("scene")
    attempt = payload.get("attempt")
    available = payload.get("available")
    checks = payload.get("checks")
    check_failures = payload.get(
        "check_failures"
    )

    if not _is_integer(version):
        raise ValueError(
            "Metrics version must be an integer."
        )

    if version != METRICS_PROTOCOL_VERSION:
        raise ValueError(
            "Unsupported metrics protocol version."
        )

    if (
        not isinstance(scene, str)
        or not scene.strip()
    ):
        raise ValueError(
            "Metrics scene must be a non-empty string."
        )

    if (
        not _is_integer(attempt)
        or attempt <= 0
    ):
        raise ValueError(
            "Metrics attempt must be positive."
        )

    if not isinstance(available, bool):
        raise ValueError(
            "Metrics available must be boolean."
        )

    if available:
        if not _is_non_negative_integer(
            checks
        ):
            raise ValueError(
                "Metrics checks must be non-negative."
            )

        if not _is_non_negative_integer(
            check_failures
        ):
            raise ValueError(
                "Metrics check_failures "
                "must be non-negative."
            )
    else:
        if (
            checks is not None
            or check_failures is not None
        ):
            raise ValueError(
                "Unavailable metrics must "
                "contain null values."
            )

    return RunnerAttemptMetrics(
        version=version,
        scene=normalize_path(scene),
        attempt=attempt,
        available=available,
        checks=checks,
        check_failures=check_failures,
    )


def _suite_override_for(
    normalized_relative_path: str,
    suite_overrides: Mapping[str, str],
) -> str:
    candidate_paths = {
        normalized_relative_path,
        "res://" + normalized_relative_path,
    }

    normalized_candidates = {
        normalize_path(candidate)
        for candidate in candidate_paths
    }

    for (
        override_path,
        suite_name,
    ) in suite_overrides.items():
        normalized_override = normalize_path(
            str(override_path)
        )

        if (
            normalized_override
            not in normalized_candidates
        ):
            continue

        clean_suite = str(
            suite_name
        ).strip()

        if clean_suite:
            return clean_suite

    return ""


def _normalize_alias_key(
    value: str,
) -> str:
    text = str(value).strip().lower()

    text = text.replace(
        "-",
        "_",
    )

    text = re.sub(
        r"\s+",
        "_",
        text,
    )

    return text


def _is_integer(
    value: object,
) -> bool:
    return (
        isinstance(value, int)
        and not isinstance(value, bool)
    )


def _is_non_negative_integer(
    value: object,
) -> bool:
    return (
        _is_integer(value)
        and int(value) >= 0
    )