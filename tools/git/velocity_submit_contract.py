from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import tempfile
import zipfile

from contextlib import contextmanager
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path, PurePosixPath
from typing import Any, Iterator


TOOL_VERSION = "1.0.0"
MANIFEST_SCHEMA = "velocity-submit-manifest/v1"
RECEIPT_SCHEMA = "velocity-submit-receipt/v1"
PROJECT_NAME = "velocity"
UID_POLICY = "required_for_new_gd"

MAX_ARCHIVE_ENTRIES = 10_000
MAX_UNCOMPRESSED_BYTES = 128 * 1024 * 1024
MAX_MANIFEST_BYTES = 1024 * 1024

DELIVERY_ID_PATTERN = re.compile(
    r"^[a-z0-9][a-z0-9-]{2,79}$"
)

GIT_NAME_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._/-]*$"
)

REMOTE_NAME_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._-]*$"
)

COMMIT_HASH_PATTERN = re.compile(
    r"^[0-9a-f]{7,40}$"
)

FULL_COMMIT_HASH_PATTERN = re.compile(
    r"^[0-9a-f]{40}$"
)

SHA256_PATTERN = re.compile(
    r"^[0-9a-f]{64}$"
)

COMMIT_MESSAGE_PATTERN = re.compile(
    r"^(feat|fix|docs|test|refactor|chore|build|ci|perf|revert)"
    r"(?:\([a-z0-9_-]+\))?: .+\S$"
)

UID_CONTENT_PATTERN = re.compile(
    r"^uid://[a-z0-9]+$"
)

TOP_LEVEL_FIELDS = {
    "schema",
    "delivery_id",
    "project",
    "expected_branch",
    "expected_head",
    "remote",
    "commit_message",
    "godot_uid_policy",
    "verification_summary",
    "files",
}

REQUIRED_TOP_LEVEL_FIELDS = TOP_LEVEL_FIELDS - {
    "verification_summary",
}

FILE_ENTRY_FIELDS = {
    "path",
    "sha256",
    "action",
}

PACKAGE_METADATA_FILES = {
    "README.txt",
    "SHA256SUMS.txt",
    "SUBMIT_MANIFEST.json",
}


class ExitCode(IntEnum):
    PASS = 0
    PACKAGE_ERROR = 2
    MANIFEST_ERROR = 3
    REPOSITORY_ERROR = 4
    BASELINE_ERROR = 5
    INSTALL_STATE_ERROR = 6
    INSTALL_ERROR = 7
    WORKTREE_ERROR = 8
    HASH_ERROR = 9
    UID_ERROR = 10
    STAGING_ERROR = 11
    COMMIT_ERROR = 12
    PUSH_ERROR = 13
    FINAL_STATE_ERROR = 14
    CANCELLED = 15


class SubmitError(Exception):
    def __init__(
        self,
        code: ExitCode,
        category: str,
        message: str,
        action: str,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.category = category
        self.message = message
        self.action = action


@dataclass(frozen=True)
class ManifestFile:
    path: str
    sha256: str
    action: str


@dataclass(frozen=True)
class SubmitManifest:
    schema: str
    delivery_id: str
    project: str
    expected_branch: str
    expected_head: str
    remote: str
    commit_message: str
    godot_uid_policy: str
    verification_summary: tuple[str, ...]
    files: tuple[ManifestFile, ...]


@dataclass(frozen=True)
class ValidatedPackage:
    zip_path: Path
    package_root: str
    package_sha256: str
    manifest_sha256: str
    manifest: SubmitManifest
    temporary_directory: Path
    source_root: Path

    def source_for(
        self,
        relative_path: str,
    ) -> Path:
        return self.source_root.joinpath(
            *PurePosixPath(relative_path).parts
        )


@dataclass(frozen=True)
class ReceiptFile:
    path: str
    sha256: str
    action: str
    previous_sha256: str | None


@dataclass(frozen=True)
class InstallReceipt:
    schema: str
    state: str
    delivery_id: str
    manifest_sha256: str
    package_sha256: str
    package_path: str
    base_commit: str
    branch: str
    remote: str
    commit_message: str
    verification_summary: tuple[str, ...]
    files: tuple[ReceiptFile, ...]
    commit_hash: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema": self.schema,
            "state": self.state,
            "delivery_id": self.delivery_id,
            "manifest_sha256": self.manifest_sha256,
            "package_sha256": self.package_sha256,
            "package_path": self.package_path,
            "base_commit": self.base_commit,
            "branch": self.branch,
            "remote": self.remote,
            "commit_message": self.commit_message,
            "verification_summary": list(
                self.verification_summary
            ),
            "files": [
                {
                    "path": file_entry.path,
                    "sha256": file_entry.sha256,
                    "action": file_entry.action,
                    "previous_sha256": (
                        file_entry.previous_sha256
                    ),
                }
                for file_entry in self.files
            ],
            "commit_hash": self.commit_hash,
        }


@dataclass(frozen=True)
class PackageEntry:
    info: zipfile.ZipInfo
    normalized_path: str
    is_directory: bool


@contextmanager
def open_validated_package(
    zip_path: Path,
) -> Iterator[ValidatedPackage]:
    package_path = _validate_external_zip(zip_path)
    package_sha256 = sha256_file(package_path)
    temporary = tempfile.TemporaryDirectory(
        prefix="velocity-delivery-"
    )

    try:
        temporary_path = Path(temporary.name)
        validated = _validate_and_extract_package(
            package_path,
            package_sha256,
            temporary_path,
        )
        yield validated
    finally:
        temporary.cleanup()


def load_manifest_bytes(
    raw: bytes,
) -> SubmitManifest:
    if len(raw) > MAX_MANIFEST_BYTES:
        raise package_error(
            "SUBMIT_MANIFEST.json exceeds the maximum size."
        )

    try:
        text = raw.decode("utf-8", errors="strict")
        data = json.loads(text)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise manifest_error(
            "Submit manifest is not valid UTF-8 JSON: "
            + str(error)
        ) from error

    return parse_manifest_data(data)


def parse_manifest_data(
    data: object,
) -> SubmitManifest:
    if not isinstance(data, dict):
        raise manifest_error(
            "Manifest root must be an object."
        )

    keys = set(data)
    missing = REQUIRED_TOP_LEVEL_FIELDS - keys
    unknown = keys - TOP_LEVEL_FIELDS

    if missing:
        raise manifest_error(
            "Manifest is missing fields: "
            + ", ".join(sorted(missing))
            + "."
        )

    if unknown:
        raise manifest_error(
            "Manifest contains unknown fields: "
            + ", ".join(sorted(unknown))
            + "."
        )

    schema = _require_string(data, "schema")
    delivery_id = _require_string(data, "delivery_id")
    project = _require_string(data, "project")
    expected_branch = _require_string(
        data,
        "expected_branch",
    )
    expected_head = _require_string(data, "expected_head")
    remote = _require_string(data, "remote")
    commit_message = _require_string(
        data,
        "commit_message",
    )
    uid_policy = _require_string(
        data,
        "godot_uid_policy",
    )

    if schema != MANIFEST_SCHEMA:
        raise manifest_error(
            "Unsupported manifest schema: " + schema + "."
        )

    if not DELIVERY_ID_PATTERN.fullmatch(delivery_id):
        raise manifest_error(
            "delivery_id has invalid format."
        )

    if project != PROJECT_NAME:
        raise manifest_error(
            "project must be velocity."
        )

    if (
        not GIT_NAME_PATTERN.fullmatch(expected_branch)
        or expected_branch.startswith("-")
        or ".." in expected_branch
        or "@{" in expected_branch
    ):
        raise manifest_error(
            "expected_branch has invalid format."
        )

    if not COMMIT_HASH_PATTERN.fullmatch(expected_head):
        raise manifest_error(
            "expected_head must be a 7 to 40 character "
            "lowercase Git hash."
        )

    if (
        not REMOTE_NAME_PATTERN.fullmatch(remote)
        or remote.startswith("-")
    ):
        raise manifest_error(
            "remote has invalid format."
        )

    if not COMMIT_MESSAGE_PATTERN.fullmatch(commit_message):
        raise manifest_error(
            "commit_message is not an accepted "
            "Conventional Commit subject."
        )

    if uid_policy != UID_POLICY:
        raise manifest_error(
            "Unsupported godot_uid_policy: "
            + uid_policy
            + "."
        )

    verification_summary = _parse_verification_summary(
        data.get("verification_summary", [])
    )
    files = _parse_manifest_files(data["files"])

    return SubmitManifest(
        schema=schema,
        delivery_id=delivery_id,
        project=project,
        expected_branch=expected_branch,
        expected_head=expected_head,
        remote=remote,
        commit_message=commit_message,
        godot_uid_policy=uid_policy,
        verification_summary=verification_summary,
        files=files,
    )


def validate_manifest_path(
    path: str,
) -> None:
    if not path:
        raise manifest_error(
            "Manifest path cannot be empty."
        )

    if "\x00" in path:
        raise manifest_error(
            "Manifest path contains NUL."
        )

    if "\\" in path:
        raise manifest_error(
            "Manifest paths must use forward slashes: "
            + path
            + "."
        )

    if path.startswith("/"):
        raise manifest_error(
            "Manifest path cannot be absolute: "
            + path
            + "."
        )

    if re.match(r"^[A-Za-z]:", path):
        raise manifest_error(
            "Manifest path cannot contain a drive letter: "
            + path
            + "."
        )

    parts = path.split("/")

    if any(part in ("", ".", "..") for part in parts):
        raise manifest_error(
            "Manifest path contains an empty or dot segment: "
            + path
            + "."
        )

    if PurePosixPath(path).parts[0].casefold() == ".git":
        raise manifest_error(
            "Manifest path cannot access .git: "
            + path
            + "."
        )


def validate_repository_target(
    repository_root: Path,
    relative_path: str,
    *,
    require_exists: bool,
) -> Path:
    validate_manifest_path(relative_path)
    candidate = repository_root.joinpath(
        *PurePosixPath(relative_path).parts
    )
    root_resolved = repository_root.resolve(strict=True)
    current = repository_root

    for part in PurePosixPath(relative_path).parts:
        current = current / part

        if current.is_symlink():
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "Target path traverses a symlink: "
                + relative_path
                + ".",
                "Replace it with a regular repository path.",
            )

        if not current.exists():
            break

    if require_exists and not candidate.exists():
        raise SubmitError(
            ExitCode.WORKTREE_ERROR,
            "WORKTREE_ERROR",
            "Required target is missing: "
            + relative_path
            + ".",
            "Use a package matching the current baseline.",
        )

    if candidate.exists() and not candidate.is_file():
        raise SubmitError(
            ExitCode.WORKTREE_ERROR,
            "WORKTREE_ERROR",
            "Target is not a regular file: "
            + relative_path
            + ".",
            "Resolve the target path before installing.",
        )

    existing_parent = candidate.parent

    while not existing_parent.exists():
        existing_parent = existing_parent.parent

    try:
        existing_parent.resolve(strict=True).relative_to(
            root_resolved
        )
    except ValueError as error:
        raise SubmitError(
            ExitCode.WORKTREE_ERROR,
            "WORKTREE_ERROR",
            "Target resolves outside repository: "
            + relative_path
            + ".",
            "Regenerate the delivery package.",
        ) from error

    return candidate


def sha256_file(
    path: Path,
) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file_handle:
        while True:
            block = file_handle.read(1024 * 1024)

            if not block:
                break

            digest.update(block)

    return digest.hexdigest()


def canonical_manifest_bytes(
    manifest: SubmitManifest,
) -> bytes:
    data = {
        "schema": manifest.schema,
        "delivery_id": manifest.delivery_id,
        "project": manifest.project,
        "expected_branch": manifest.expected_branch,
        "expected_head": manifest.expected_head,
        "remote": manifest.remote,
        "commit_message": manifest.commit_message,
        "godot_uid_policy": manifest.godot_uid_policy,
        "verification_summary": list(
            manifest.verification_summary
        ),
        "files": [
            {
                "path": file_entry.path,
                "sha256": file_entry.sha256,
                "action": file_entry.action,
            }
            for file_entry in manifest.files
        ],
    }
    return (
        json.dumps(
            data,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        )
        + "\n"
    ).encode("utf-8")


def manifest_digest(
    manifest: SubmitManifest,
) -> str:
    return hashlib.sha256(
        canonical_manifest_bytes(manifest)
    ).hexdigest()


def write_receipt(
    receipt_path: Path,
    receipt: InstallReceipt,
) -> None:
    temporary_path = receipt_path.with_name(
        receipt_path.name + ".tmp"
    )
    serialized = (
        json.dumps(
            receipt.to_dict(),
            indent=2,
            ensure_ascii=False,
        )
        + "\n"
    )

    try:
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path.write_text(
            serialized,
            encoding="utf-8",
        )
        os.replace(temporary_path, receipt_path)
    except OSError as error:
        if temporary_path.exists():
            try:
                temporary_path.unlink()
            except OSError:
                pass

        raise install_state_error(
            "Could not write installation receipt: "
            + str(error)
        ) from error


def load_receipt(
    receipt_path: Path,
) -> InstallReceipt | None:
    if not receipt_path.exists():
        return None

    if not receipt_path.is_file() or receipt_path.is_symlink():
        raise install_state_error(
            "Installation receipt is not a regular file."
        )

    try:
        data = json.loads(
            receipt_path.read_text(
                encoding="utf-8",
                errors="strict",
            )
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise install_state_error(
            "Installation receipt is invalid: " + str(error)
        ) from error

    return parse_receipt_data(data)


def parse_receipt_data(
    data: object,
) -> InstallReceipt:
    if not isinstance(data, dict):
        raise install_state_error(
            "Installation receipt root must be an object."
        )

    expected_fields = {
        "schema",
        "state",
        "delivery_id",
        "manifest_sha256",
        "package_sha256",
        "package_path",
        "base_commit",
        "branch",
        "remote",
        "commit_message",
        "verification_summary",
        "files",
        "commit_hash",
    }

    if set(data) != expected_fields:
        raise install_state_error(
            "Installation receipt fields are invalid."
        )

    schema = _receipt_string(data, "schema")
    state_value = _receipt_string(data, "state")

    if schema != RECEIPT_SCHEMA:
        raise install_state_error(
            "Unsupported installation receipt schema."
        )

    if state_value not in (
        "installing",
        "installed",
        "local_commit_only",
    ):
        raise install_state_error(
            "Installation receipt state is invalid."
        )

    delivery_id = _receipt_string(data, "delivery_id")
    manifest_sha = _receipt_string(
        data,
        "manifest_sha256",
    )
    package_sha = _receipt_string(
        data,
        "package_sha256",
    )
    package_path = _receipt_string(data, "package_path")
    base_commit = _receipt_string(data, "base_commit")
    branch = _receipt_string(data, "branch")
    remote = _receipt_string(data, "remote")
    commit_message = _receipt_string(
        data,
        "commit_message",
    )

    if not SHA256_PATTERN.fullmatch(manifest_sha):
        raise install_state_error(
            "Receipt manifest SHA-256 is invalid."
        )

    if not SHA256_PATTERN.fullmatch(package_sha):
        raise install_state_error(
            "Receipt package SHA-256 is invalid."
        )

    if not FULL_COMMIT_HASH_PATTERN.fullmatch(base_commit):
        raise install_state_error(
            "Receipt base commit is invalid."
        )

    summary_raw = data["verification_summary"]

    if not isinstance(summary_raw, list):
        raise install_state_error(
            "Receipt verification summary is invalid."
        )

    summary: list[str] = []

    for value in summary_raw:
        if not isinstance(value, str) or not value:
            raise install_state_error(
                "Receipt verification item is invalid."
            )
        summary.append(value)

    files_raw = data["files"]

    if not isinstance(files_raw, list) or not files_raw:
        raise install_state_error(
            "Receipt files are invalid."
        )

    files: list[ReceiptFile] = []

    for value in files_raw:
        if not isinstance(value, dict):
            raise install_state_error(
                "Receipt file entry is invalid."
            )

        if set(value) != {
            "path",
            "sha256",
            "action",
            "previous_sha256",
        }:
            raise install_state_error(
                "Receipt file fields are invalid."
            )

        relative_path = _receipt_string(value, "path")
        sha256 = _receipt_string(value, "sha256")
        action = _receipt_string(value, "action")
        previous = value["previous_sha256"]

        validate_manifest_path(relative_path)

        if not SHA256_PATTERN.fullmatch(sha256):
            raise install_state_error(
                "Receipt file SHA-256 is invalid."
            )

        if action not in ("add", "replace"):
            raise install_state_error(
                "Receipt file action is invalid."
            )

        if previous is not None:
            if (
                not isinstance(previous, str)
                or not SHA256_PATTERN.fullmatch(previous)
            ):
                raise install_state_error(
                    "Receipt previous SHA-256 is invalid."
                )

        if action == "replace" and previous is None:
            raise install_state_error(
                "Replace receipt entry lacks previous hash."
            )

        if action == "add" and previous is not None:
            raise install_state_error(
                "Add receipt entry has unexpected previous hash."
            )

        files.append(
            ReceiptFile(
                path=relative_path,
                sha256=sha256,
                action=action,
                previous_sha256=previous,
            )
        )

    commit_hash_raw = data["commit_hash"]

    if commit_hash_raw is not None:
        if (
            not isinstance(commit_hash_raw, str)
            or not FULL_COMMIT_HASH_PATTERN.fullmatch(
                commit_hash_raw
            )
        ):
            raise install_state_error(
                "Receipt commit hash is invalid."
            )

    if state_value == "local_commit_only":
        if commit_hash_raw is None:
            raise install_state_error(
                "Local commit receipt lacks commit hash."
            )
    elif commit_hash_raw is not None:
        raise install_state_error(
            "Uncommitted receipt has a commit hash."
        )

    return InstallReceipt(
        schema=schema,
        state=state_value,
        delivery_id=delivery_id,
        manifest_sha256=manifest_sha,
        package_sha256=package_sha,
        package_path=package_path,
        base_commit=base_commit,
        branch=branch,
        remote=remote,
        commit_message=commit_message,
        verification_summary=tuple(summary),
        files=tuple(files),
        commit_hash=commit_hash_raw,
    )


def package_error(
    message: str,
) -> SubmitError:
    return SubmitError(
        ExitCode.PACKAGE_ERROR,
        "PACKAGE_ERROR",
        message,
        "Select an intact Velocity delivery ZIP.",
    )


def manifest_error(
    message: str,
) -> SubmitError:
    return SubmitError(
        ExitCode.MANIFEST_ERROR,
        "MANIFEST_ERROR",
        message,
        "Use SUBMIT_MANIFEST.json from a valid delivery package.",
    )


def install_state_error(
    message: str,
) -> SubmitError:
    return SubmitError(
        ExitCode.INSTALL_STATE_ERROR,
        "INSTALL_STATE_ERROR",
        message,
        "Do not install another package until the active delivery is recovered.",
    )


def _validate_external_zip(
    zip_path: Path,
) -> Path:
    package_path = Path(
        os.path.abspath(
            os.fspath(zip_path.expanduser())
        )
    )

    if package_path.is_symlink():
        raise package_error(
            "Delivery ZIP cannot be a symlink."
        )

    if not package_path.is_file():
        raise package_error(
            "Delivery ZIP does not exist: "
            + str(package_path)
        )

    if package_path.suffix.casefold() != ".zip":
        raise package_error(
            "Selected delivery is not a .zip file."
        )

    return package_path


def _validate_and_extract_package(
    package_path: Path,
    package_sha256: str,
    temporary_path: Path,
) -> ValidatedPackage:
    try:
        archive = zipfile.ZipFile(package_path, mode="r")
    except (OSError, zipfile.BadZipFile) as error:
        raise package_error(
            "Delivery ZIP cannot be opened: " + str(error)
        ) from error

    with archive:
        entries = _validate_archive_entries(archive)
        package_root = _find_package_root(entries)
        manifest_archive_path = (
            package_root + "/SUBMIT_MANIFEST.json"
        )
        manifest_info = _file_info_by_path(
            entries,
            manifest_archive_path,
        )

        try:
            manifest_raw = archive.read(manifest_info)
        except (OSError, RuntimeError, zipfile.BadZipFile) as error:
            raise package_error(
                "Could not read SUBMIT_MANIFEST.json: "
                + str(error)
            ) from error

        manifest = load_manifest_bytes(manifest_raw)
        manifest_sha256 = manifest_digest(manifest)

        _validate_archive_allowlist(
            entries,
            package_root,
            manifest,
        )

        source_root = temporary_path / "repository_files"
        source_root.mkdir(parents=True, exist_ok=True)

        for file_entry in manifest.files:
            archive_path = (
                package_root
                + "/repository_files/"
                + file_entry.path
            )
            info = _file_info_by_path(entries, archive_path)
            destination = source_root.joinpath(
                *PurePosixPath(file_entry.path).parts
            )
            destination.parent.mkdir(
                parents=True,
                exist_ok=True,
            )

            try:
                with archive.open(info, mode="r") as source:
                    with destination.open("wb") as target:
                        digest = hashlib.sha256()

                        while True:
                            block = source.read(1024 * 1024)

                            if not block:
                                break

                            digest.update(block)
                            target.write(block)
            except (OSError, RuntimeError, zipfile.BadZipFile) as error:
                raise package_error(
                    "Could not extract declared file: "
                    + file_entry.path
                    + ": "
                    + str(error)
                ) from error

            if digest.hexdigest() != file_entry.sha256:
                raise SubmitError(
                    ExitCode.HASH_ERROR,
                    "HASH_ERROR",
                    "Source SHA-256 mismatch for "
                    + file_entry.path
                    + ".",
                    "Download the delivery ZIP again.",
                )

    return ValidatedPackage(
        zip_path=package_path,
        package_root=package_root,
        package_sha256=package_sha256,
        manifest_sha256=manifest_sha256,
        manifest=manifest,
        temporary_directory=temporary_path,
        source_root=source_root,
    )


def _validate_archive_entries(
    archive: zipfile.ZipFile,
) -> tuple[PackageEntry, ...]:
    infos = archive.infolist()

    if not infos:
        raise package_error("Delivery ZIP is empty.")

    if len(infos) > MAX_ARCHIVE_ENTRIES:
        raise package_error(
            "Delivery ZIP exceeds the entry limit."
        )

    total_size = 0
    seen: set[str] = set()
    entries: list[PackageEntry] = []

    for info in infos:
        raw_name = info.filename

        if info.flag_bits & 0x1:
            raise package_error(
                "Encrypted ZIP entries are not supported: "
                + raw_name
            )

        if "\\" in raw_name:
            raise package_error(
                "ZIP entry uses backslashes: " + raw_name
            )

        normalized = raw_name.rstrip("/")

        if not normalized:
            raise package_error(
                "ZIP entry has an empty path."
            )

        _validate_archive_path(normalized)
        case_key = normalized.casefold()

        if case_key in seen:
            raise package_error(
                "ZIP contains duplicate or case-colliding path: "
                + normalized
            )

        seen.add(case_key)

        mode = (info.external_attr >> 16) & 0xFFFF

        if mode and stat.S_ISLNK(mode):
            raise package_error(
                "ZIP contains a symlink entry: "
                + normalized
            )

        total_size += info.file_size

        if total_size > MAX_UNCOMPRESSED_BYTES:
            raise package_error(
                "Delivery ZIP exceeds the uncompressed size limit."
            )

        entries.append(
            PackageEntry(
                info=info,
                normalized_path=normalized,
                is_directory=info.is_dir(),
            )
        )

    return tuple(entries)


def _validate_archive_path(
    path: str,
) -> None:
    if path.startswith("/"):
        raise package_error(
            "ZIP entry is absolute: " + path
        )

    if re.match(r"^[A-Za-z]:", path):
        raise package_error(
            "ZIP entry contains a drive letter: " + path
        )

    parts = path.split("/")

    if any(part in ("", ".", "..") for part in parts):
        raise package_error(
            "ZIP entry contains an empty or dot segment: "
            + path
        )


def _find_package_root(
    entries: tuple[PackageEntry, ...],
) -> str:
    roots = {
        PurePosixPath(entry.normalized_path).parts[0]
        for entry in entries
    }

    if len(roots) != 1:
        raise package_error(
            "Delivery ZIP must contain exactly one package root."
        )

    root = next(iter(roots))

    if root.casefold() in ("repository_files", ".git"):
        raise package_error(
            "Delivery ZIP package root is invalid."
        )

    return root


def _validate_archive_allowlist(
    entries: tuple[PackageEntry, ...],
    package_root: str,
    manifest: SubmitManifest,
) -> None:
    expected_files = {
        package_root + "/" + metadata
        for metadata in PACKAGE_METADATA_FILES
    }

    for file_entry in manifest.files:
        expected_files.add(
            package_root
            + "/repository_files/"
            + file_entry.path
        )

    expected_directories = {package_root}

    for file_path in expected_files:
        parent = PurePosixPath(file_path).parent

        while str(parent) not in (".", ""):
            expected_directories.add(str(parent))
            parent = parent.parent

    actual_files = {
        entry.normalized_path
        for entry in entries
        if not entry.is_directory
    }
    actual_directories = {
        entry.normalized_path
        for entry in entries
        if entry.is_directory
    }

    missing = sorted(expected_files - actual_files)
    extra = sorted(actual_files - expected_files)
    unexpected_directories = sorted(
        actual_directories - expected_directories
    )

    if missing or extra or unexpected_directories:
        details: list[str] = []

        if missing:
            details.append(
                "Missing archive files: "
                + ", ".join(missing)
                + "."
            )

        if extra:
            details.append(
                "Unexpected archive files: "
                + ", ".join(extra)
                + "."
            )

        if unexpected_directories:
            details.append(
                "Unexpected archive directories: "
                + ", ".join(unexpected_directories)
                + "."
            )

        raise package_error(" ".join(details))


def _file_info_by_path(
    entries: tuple[PackageEntry, ...],
    path: str,
) -> zipfile.ZipInfo:
    for entry in entries:
        if (
            not entry.is_directory
            and entry.normalized_path == path
        ):
            return entry.info

    raise package_error(
        "Required archive file is missing: " + path
    )


def _parse_verification_summary(
    value: object,
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise manifest_error(
            "verification_summary must be an array."
        )

    summary: list[str] = []

    for item in value:
        if not isinstance(item, str) or not item.strip():
            raise manifest_error(
                "verification_summary items must be "
                "non-empty strings."
            )

        if item != item.strip():
            raise manifest_error(
                "verification_summary items cannot contain "
                "surrounding whitespace."
            )

        summary.append(item)

    return tuple(summary)


def _parse_manifest_files(
    value: object,
) -> tuple[ManifestFile, ...]:
    if not isinstance(value, list) or not value:
        raise manifest_error(
            "files must be a non-empty array."
        )

    files: list[ManifestFile] = []
    seen_paths: set[str] = set()

    for index, item in enumerate(value):
        if not isinstance(item, dict):
            raise manifest_error(
                "files[" + str(index) + "] must be an object."
            )

        keys = set(item)

        if keys != FILE_ENTRY_FIELDS:
            raise manifest_error(
                "files["
                + str(index)
                + "] must contain exactly path, sha256 and action."
            )

        relative_path = _require_entry_string(
            item,
            "path",
            index,
        )
        sha256 = _require_entry_string(
            item,
            "sha256",
            index,
        )
        action = _require_entry_string(
            item,
            "action",
            index,
        )

        validate_manifest_path(relative_path)

        if relative_path.endswith(".gd.uid"):
            raise manifest_error(
                "Godot UID sidecars must be derived, not listed: "
                + relative_path
                + "."
            )

        case_key = relative_path.casefold()

        if case_key in seen_paths:
            raise manifest_error(
                "Duplicate or case-colliding path: "
                + relative_path
                + "."
            )

        seen_paths.add(case_key)

        if not SHA256_PATTERN.fullmatch(sha256):
            raise manifest_error(
                "Invalid SHA-256 for "
                + relative_path
                + "."
            )

        if action not in ("add", "replace"):
            raise manifest_error(
                "Unsupported action for "
                + relative_path
                + ": "
                + action
                + "."
            )

        files.append(
            ManifestFile(
                path=relative_path,
                sha256=sha256,
                action=action,
            )
        )

    return tuple(files)


def _require_string(
    data: dict[str, Any],
    field: str,
) -> str:
    value = data[field]

    if not isinstance(value, str) or not value.strip():
        raise manifest_error(
            field + " must be a non-empty string."
        )

    if value != value.strip():
        raise manifest_error(
            field + " cannot contain surrounding whitespace."
        )

    return value


def _require_entry_string(
    data: dict[str, Any],
    field: str,
    index: int,
) -> str:
    value = data[field]

    if not isinstance(value, str) or not value.strip():
        raise manifest_error(
            "files["
            + str(index)
            + "]."
            + field
            + " must be a non-empty string."
        )

    if value != value.strip():
        raise manifest_error(
            "files["
            + str(index)
            + "]."
            + field
            + " cannot contain surrounding whitespace."
        )

    return value


def _receipt_string(
    data: dict[str, Any],
    field: str,
) -> str:
    value = data[field]

    if not isinstance(value, str) or not value:
        raise install_state_error(
            "Receipt field is invalid: " + field
        )

    return value
