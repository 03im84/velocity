from __future__ import annotations

import os
import subprocess

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Sequence

from velocity_submit_contract import (
    COMMIT_HASH_PATTERN,
    UID_CONTENT_PATTERN,
    ExitCode,
    InstallReceipt,
    SubmitError,
    SubmitManifest,
    load_receipt,
    sha256_file,
    validate_repository_target,
)


GIT_OPERATION_MARKERS = (
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "BISECT_LOG",
    "rebase-apply",
    "rebase-merge",
)


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class GitStatusEntry:
    index_status: str
    worktree_status: str
    path: str
    secondary_path: str | None = None

    def is_untracked(self) -> bool:
        return (
            self.index_status == "?"
            and self.worktree_status == "?"
        )

    def is_staged(self) -> bool:
        return self.index_status not in (" ", "?")

    def is_rename_or_copy(self) -> bool:
        return (
            self.index_status in ("R", "C")
            or self.worktree_status in ("R", "C")
        )


@dataclass(frozen=True)
class RepositoryPaths:
    root: Path
    git_directory: Path
    state_directory: Path
    receipt_path: Path
    backup_directory: Path
    prepared_directory: Path


@dataclass(frozen=True)
class SubmitPreflight:
    manifest_paths: tuple[str, ...]
    uid_paths: tuple[str, ...]
    allowed_paths: tuple[str, ...]


@dataclass(frozen=True)
class CommitResult:
    previous_head: str
    commit_hash: str
    subject: str


class GitRunner:
    def __init__(
        self,
        repository_root: Path,
    ) -> None:
        self.repository_root = repository_root

    def run(
        self,
        arguments: Sequence[str],
        *,
        check: bool = True,
    ) -> CommandResult:
        process = subprocess.run(
            ["git", *arguments],
            cwd=self.repository_root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            shell=False,
            check=False,
        )
        result = CommandResult(
            process.returncode,
            process.stdout,
            process.stderr,
        )

        if check and result.returncode != 0:
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Git command failed: git "
                + " ".join(arguments)
                + command_error_detail(result),
                "Review the Git error before retrying.",
            )

        return result

    def run_bytes(
        self,
        arguments: Sequence[str],
        *,
        check: bool = True,
    ) -> subprocess.CompletedProcess[bytes]:
        process = subprocess.run(
            ["git", *arguments],
            cwd=self.repository_root,
            capture_output=True,
            text=False,
            shell=False,
            check=False,
        )

        if check and process.returncode != 0:
            detail = os.fsdecode(process.stderr).strip()
            suffix = "" if not detail else ": " + detail
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Git command failed: git "
                + " ".join(arguments)
                + suffix,
                "Review the Git error before retrying.",
            )

        return process


class RepositoryController:
    def __init__(
        self,
        paths: RepositoryPaths,
    ) -> None:
        self.paths = paths
        self.git = GitRunner(paths.root)

    @classmethod
    def discover(
        cls,
        start_directory: Path,
    ) -> RepositoryController:
        root = discover_repository_root(start_directory)
        runner = GitRunner(root)
        git_path_text = runner.run(
            ["rev-parse", "--absolute-git-dir"],
        ).stdout.strip()
        git_directory = Path(git_path_text).resolve()
        state_directory = git_directory / "velocity-submit"

        return cls(
            RepositoryPaths(
                root=root,
                git_directory=git_directory,
                state_directory=state_directory,
                receipt_path=(
                    state_directory / "active_delivery.json"
                ),
                backup_directory=(
                    state_directory / "backups"
                ),
                prepared_directory=(
                    state_directory / "prepared"
                ),
            )
        )

    def load_receipt(self) -> InstallReceipt | None:
        return load_receipt(self.paths.receipt_path)

    def validate_project(self) -> None:
        inside = self.git.run(
            ["rev-parse", "--is-inside-work-tree"],
        ).stdout.strip()

        if inside != "true":
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Current directory is not a Git working tree.",
                "Run the tool from the Velocity repository.",
            )

        marker = self.paths.root / "project.godot"

        if not marker.is_file():
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "project.godot is missing from repository root.",
                "Run the tool from the Velocity repository.",
            )

        marker_text = marker.read_text(
            encoding="utf-8",
            errors="strict",
        )

        if 'config/name="velocity"' not in marker_text:
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Repository marker does not identify Velocity.",
                "Do not apply this delivery to another repository.",
            )

    def validate_no_git_operation(self) -> None:
        active: list[str] = []

        for marker in GIT_OPERATION_MARKERS:
            path_text = self.git.run(
                ["rev-parse", "--git-path", marker],
            ).stdout.strip()
            path = Path(path_text)

            if not path.is_absolute():
                path = self.paths.root / path

            if path.exists():
                active.append(marker)

        if active:
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Active Git operation detected: "
                + ", ".join(active),
                "Finish or abort it manually before continuing.",
            )

    def validate_baseline(
        self,
        manifest: SubmitManifest,
        *,
        fetch_remote: bool,
    ) -> str:
        branch_process = self.git.run(
            ["symbolic-ref", "--quiet", "--short", "HEAD"],
            check=False,
        )

        if branch_process.returncode != 0:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Detached HEAD is not allowed.",
                "Checkout the expected branch.",
            )

        branch = branch_process.stdout.strip()

        if branch != manifest.expected_branch:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Current branch is "
                + branch
                + "; expected "
                + manifest.expected_branch
                + ".",
                "Checkout the expected branch.",
            )

        expected_process = self.git.run(
            [
                "rev-parse",
                "--verify",
                manifest.expected_head + "^{commit}",
            ],
            check=False,
        )

        if expected_process.returncode != 0:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Manifest expected_head cannot be resolved.",
                "Use a package built for the current baseline.",
            )

        expected = expected_process.stdout.strip()
        current = self.head_commit()

        if current != expected:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "HEAD does not match manifest expected_head.",
                "Do not apply this delivery over another baseline.",
            )

        remote_check = self.git.run(
            ["remote", "get-url", manifest.remote],
            check=False,
        )

        if remote_check.returncode != 0:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Manifest remote does not exist.",
                "Configure the declared remote first.",
            )

        if fetch_remote:
            remote_ref = (
                "refs/heads/"
                + manifest.expected_branch
                + ":refs/remotes/"
                + manifest.remote
                + "/"
                + manifest.expected_branch
            )
            fetch = self.git.run(
                [
                    "fetch",
                    "--quiet",
                    manifest.remote,
                    remote_ref,
                ],
                check=False,
            )

            if fetch.returncode != 0:
                raise SubmitError(
                    ExitCode.BASELINE_ERROR,
                    "BASELINE_ERROR",
                    "Could not fetch remote branch"
                    + command_error_detail(fetch),
                    "Resolve network or authentication first.",
                )

        remote = self.remote_commit(manifest)

        if remote != current:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Local HEAD and remote branch are not synchronized.",
                "Resolve ahead, behind or divergence first.",
            )

        return current

    def require_clean_for_install(self) -> None:
        status = self.read_status()

        if status:
            paths = sorted(status_paths(status), key=str.casefold)
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "Install requires a clean working tree. Changes: "
                + ", ".join(paths),
                "Resolve all changes before installing a package.",
            )

    def is_tracked(
        self,
        relative_path: str,
    ) -> bool:
        result = self.git.run(
            [
                "ls-files",
                "--error-unmatch",
                "--",
                relative_path,
            ],
            check=False,
        )
        return result.returncode == 0

    def read_status(self) -> tuple[GitStatusEntry, ...]:
        process = self.git.run_bytes(
            [
                "status",
                "--porcelain=v1",
                "-z",
                "--untracked-files=all",
            ]
        )
        return parse_porcelain_status(process.stdout)

    def submit_preflight(
        self,
        receipt: InstallReceipt,
        manifest: SubmitManifest,
    ) -> SubmitPreflight:
        self.validate_project()
        self.validate_no_git_operation()
        self.validate_baseline(
            manifest,
            fetch_remote=True,
        )

        if receipt.state != "installed":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Receipt is not in installed state.",
                "Resolve the active delivery before submit.",
            )

        status_entries = self.read_status()
        self._reject_unsupported_status(status_entries)
        self._reject_pre_staged(status_entries)

        status_by_path = {
            entry.path: entry
            for entry in status_entries
        }
        manifest_paths: list[str] = []
        uid_paths: list[str] = []

        for file_entry in manifest.files:
            target = validate_repository_target(
                self.paths.root,
                file_entry.path,
                require_exists=True,
            )

            if sha256_file(target) != file_entry.sha256:
                raise SubmitError(
                    ExitCode.HASH_ERROR,
                    "HASH_ERROR",
                    "Installed target drifted: "
                    + file_entry.path
                    + ".",
                    "Do not submit. Restore or reinstall the delivery.",
                )

            if file_entry.path not in status_by_path:
                raise SubmitError(
                    ExitCode.WORKTREE_ERROR,
                    "WORKTREE_ERROR",
                    "Installed target has no Git change: "
                    + file_entry.path
                    + ".",
                    "Do not submit a delivery over the wrong baseline.",
                )

            manifest_paths.append(file_entry.path)

            if not file_entry.path.endswith(".gd"):
                continue

            uid_path = file_entry.path + ".uid"
            uid_status = status_by_path.get(uid_path)

            if file_entry.action == "add" and uid_status is None:
                raise SubmitError(
                    ExitCode.UID_ERROR,
                    "UID_ERROR",
                    "New GDScript is missing UID: "
                    + uid_path
                    + ".",
                    "Refresh Godot and preserve the generated UID.",
                )

            if uid_status is None:
                continue

            uid_target = validate_repository_target(
                self.paths.root,
                uid_path,
                require_exists=True,
            )
            content = uid_target.read_text(
                encoding="utf-8",
                errors="strict",
            ).strip()

            if not UID_CONTENT_PATTERN.fullmatch(content):
                raise SubmitError(
                    ExitCode.UID_ERROR,
                    "UID_ERROR",
                    "Godot UID sidecar is invalid: "
                    + uid_path
                    + ".",
                    "Refresh Godot and do not edit UID manually.",
                )

            uid_paths.append(uid_path)

        allowed_paths = tuple(
            sorted(
                {*manifest_paths, *uid_paths},
                key=str.casefold,
            )
        )
        actual_paths = status_paths(status_entries)
        expected_paths = set(allowed_paths)

        if actual_paths != expected_paths:
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                set_mismatch_message(
                    "Working tree does not match installed delivery.",
                    sorted(
                        expected_paths - actual_paths,
                        key=str.casefold,
                    ),
                    sorted(
                        actual_paths - expected_paths,
                        key=str.casefold,
                    ),
                ),
                "Resolve unexpected changes before submit.",
            )

        diff_check = self.git.run(
            ["diff", "--check"],
            check=False,
        )

        if diff_check.returncode != 0:
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "git diff --check failed"
                + command_error_detail(diff_check),
                "Correct the complete delivered files.",
            )

        return SubmitPreflight(
            manifest_paths=tuple(manifest_paths),
            uid_paths=tuple(uid_paths),
            allowed_paths=allowed_paths,
        )

    def stage_and_audit(
        self,
        preflight: SubmitPreflight,
    ) -> str:
        self._run_path_chunks(
            ["add", "--"],
            preflight.allowed_paths,
            ExitCode.STAGING_ERROR,
            "STAGING_ERROR",
            "Explicit staging failed.",
        )

        staged = set(self._read_staged_paths())
        expected = set(preflight.allowed_paths)

        if staged != expected:
            self.unstage(preflight.allowed_paths)
            raise SubmitError(
                ExitCode.STAGING_ERROR,
                "STAGING_ERROR",
                set_mismatch_message(
                    "Staged paths do not match allowlist.",
                    sorted(expected - staged),
                    sorted(staged - expected),
                ),
                "Inspect repository state before retrying.",
            )

        cached = self.git.run(
            ["diff", "--cached", "--check"],
            check=False,
        )

        if cached.returncode != 0:
            self.unstage(preflight.allowed_paths)
            raise SubmitError(
                ExitCode.STAGING_ERROR,
                "STAGING_ERROR",
                "git diff --cached --check failed"
                + command_error_detail(cached),
                "Correct the delivered files before retrying.",
            )

        output = self.git.run(
            ["diff", "--cached", "--name-status"]
        ).stdout.rstrip()

        if not output:
            self.unstage(preflight.allowed_paths)
            raise SubmitError(
                ExitCode.STAGING_ERROR,
                "STAGING_ERROR",
                "Cached audit produced no changes.",
                "Inspect the installed delivery.",
            )

        return output

    def unstage(
        self,
        paths: Sequence[str],
    ) -> None:
        self._run_path_chunks(
            ["restore", "--staged", "--"],
            paths,
            ExitCode.STAGING_ERROR,
            "STAGING_ERROR",
            "Could not restore tool-created staging.",
        )

    def commit(
        self,
        message: str,
    ) -> CommitResult:
        previous_head = self.head_commit()
        process = self.git.run(
            ["commit", "-m", message],
            check=False,
        )

        if process.returncode != 0:
            raise SubmitError(
                ExitCode.COMMIT_ERROR,
                "COMMIT_ERROR",
                "Git commit failed"
                + command_error_detail(process),
                "Do not push. Preserve staging for diagnosis.",
            )

        commit_hash = self.head_commit()

        if commit_hash == previous_head:
            raise SubmitError(
                ExitCode.COMMIT_ERROR,
                "COMMIT_ERROR",
                "Git reported success but HEAD did not change.",
                "Do not push. Inspect repository history.",
            )

        subject = self.git.run(
            ["log", "-1", "--format=%s"]
        ).stdout.strip()

        if subject != message:
            raise SubmitError(
                ExitCode.COMMIT_ERROR,
                "COMMIT_ERROR",
                "Commit subject differs from manifest.",
                "Do not push. Inspect hooks and history.",
            )

        return CommitResult(
            previous_head=previous_head,
            commit_hash=commit_hash,
            subject=subject,
        )

    def push_and_verify(
        self,
        manifest: SubmitManifest,
        expected_commit: str,
    ) -> str:
        process = self.git.run(
            [
                "push",
                manifest.remote,
                manifest.expected_branch,
            ],
            check=False,
        )

        if process.returncode != 0:
            raise SubmitError(
                ExitCode.PUSH_ERROR,
                "PUSH_ERROR",
                "Push failed; local commit is preserved"
                + command_error_detail(process),
                "Resolve the remote error, then retry push.",
            )

        local = self.head_commit()
        remote = self.remote_commit(manifest)

        if local != expected_commit or remote != local:
            raise SubmitError(
                ExitCode.FINAL_STATE_ERROR,
                "FINAL_STATE_ERROR",
                "Local and remote commits are not synchronized.",
                "Stop and inspect repository history.",
            )

        if self.read_status():
            raise SubmitError(
                ExitCode.FINAL_STATE_ERROR,
                "FINAL_STATE_ERROR",
                "Working tree is not clean after push.",
                "Inspect repository state.",
            )

        return self.git.run(
            ["status", "-sb"]
        ).stdout.strip()

    def retry_push_preflight(
        self,
        receipt: InstallReceipt,
        manifest: SubmitManifest,
    ) -> None:
        self.validate_project()
        self.validate_no_git_operation()

        if receipt.state != "local_commit_only":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Receipt is not waiting for push retry.",
                "Use the normal guided workflow.",
            )

        if receipt.commit_hash is None:
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Push retry receipt lacks commit hash.",
                "Inspect repository state manually.",
            )

        if self.head_commit() != receipt.commit_hash:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "HEAD changed after the preserved local commit.",
                "Inspect history before any push.",
            )

        branch = self.git.run(
            ["symbolic-ref", "--quiet", "--short", "HEAD"]
        ).stdout.strip()

        if branch != receipt.branch:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Branch changed after local commit.",
                "Checkout the recorded branch before retrying.",
            )

        if self.read_status():
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "Working tree must be clean before push retry.",
                "Resolve local changes first.",
            )

        remote_check = self.git.run(
            ["remote", "get-url", manifest.remote],
            check=False,
        )

        if remote_check.returncode != 0:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Recorded remote is unavailable.",
                "Restore remote configuration before retrying.",
            )

    def head_commit(self) -> str:
        return self.git.run(
            ["rev-parse", "HEAD"]
        ).stdout.strip()

    def remote_commit(
        self,
        manifest: SubmitManifest,
    ) -> str:
        result = self.git.run(
            [
                "rev-parse",
                "refs/remotes/"
                + manifest.remote
                + "/"
                + manifest.expected_branch,
            ],
            check=False,
        )

        if result.returncode != 0:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Remote tracking branch is unavailable.",
                "Fetch the expected remote branch.",
            )

        return result.stdout.strip()

    def _reject_unsupported_status(
        self,
        entries: Sequence[GitStatusEntry],
    ) -> None:
        unsupported = [
            entry.path
            for entry in entries
            if entry.is_rename_or_copy()
        ]

        if unsupported:
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "Rename or copy is outside tool 1.0: "
                + ", ".join(unsupported),
                "Use a successor design for destructive changes.",
            )

    def _reject_pre_staged(
        self,
        entries: Sequence[GitStatusEntry],
    ) -> None:
        staged = sorted(
            (
                entry.path
                for entry in entries
                if entry.is_staged()
            ),
            key=str.casefold,
        )

        if staged:
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                "Pre-existing staging is not allowed: "
                + ", ".join(staged),
                "Commit or unstage it manually first.",
            )

    def _read_staged_paths(self) -> tuple[str, ...]:
        process = self.git.run_bytes(
            ["diff", "--cached", "--name-only", "-z"]
        )
        return tuple(
            os.fsdecode(value)
            for value in process.stdout.split(b"\0")
            if value
        )

    def _run_path_chunks(
        self,
        prefix: Sequence[str],
        paths: Sequence[str],
        code: ExitCode,
        category: str,
        message: str,
    ) -> None:
        if not paths:
            raise SubmitError(
                code,
                category,
                message + " No paths were provided.",
                "Regenerate the delivery package.",
            )

        current: list[str] = []
        length = sum(len(value) + 1 for value in prefix)

        for path in paths:
            added = len(path) + 1

            if current and length + added > 7000:
                self._run_path_command(
                    prefix,
                    current,
                    code,
                    category,
                    message,
                )
                current = []
                length = sum(
                    len(value) + 1
                    for value in prefix
                )

            current.append(path)
            length += added

        if current:
            self._run_path_command(
                prefix,
                current,
                code,
                category,
                message,
            )

    def _run_path_command(
        self,
        prefix: Sequence[str],
        paths: Sequence[str],
        code: ExitCode,
        category: str,
        message: str,
    ) -> None:
        result = self.git.run(
            [*prefix, *paths],
            check=False,
        )

        if result.returncode != 0:
            raise SubmitError(
                code,
                category,
                message + command_error_detail(result),
                "Inspect Git state before retrying.",
            )


def discover_repository_root(
    start_directory: Path,
) -> Path:
    process = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=start_directory,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=False,
        check=False,
    )

    if process.returncode != 0:
        detail = process.stderr.strip()
        suffix = "" if not detail else ": " + detail
        raise SubmitError(
            ExitCode.REPOSITORY_ERROR,
            "REPOSITORY_ERROR",
            "Could not discover Git repository root" + suffix,
            "Run the tool from inside Velocity.",
        )

    return Path(process.stdout.strip()).resolve()


def parse_porcelain_status(
    output: bytes,
) -> tuple[GitStatusEntry, ...]:
    values = output.split(b"\0")
    entries: list[GitStatusEntry] = []
    index = 0

    while index < len(values):
        value = values[index]

        if not value:
            index += 1
            continue

        if len(value) < 4 or value[2:3] != b" ":
            raise SubmitError(
                ExitCode.REPOSITORY_ERROR,
                "REPOSITORY_ERROR",
                "Could not parse Git porcelain status.",
                "Inspect git status --short manually.",
            )

        index_status = chr(value[0])
        worktree_status = chr(value[1])
        path = os.fsdecode(value[3:])
        secondary: str | None = None

        if (
            index_status in ("R", "C")
            or worktree_status in ("R", "C")
        ):
            index += 1

            if index >= len(values) or not values[index]:
                raise SubmitError(
                    ExitCode.REPOSITORY_ERROR,
                    "REPOSITORY_ERROR",
                    "Rename status lacks secondary path.",
                    "Inspect repository state manually.",
                )

            secondary = os.fsdecode(values[index])

        entries.append(
            GitStatusEntry(
                index_status,
                worktree_status,
                path,
                secondary,
            )
        )
        index += 1

    return tuple(entries)


def status_paths(
    entries: Sequence[GitStatusEntry],
) -> set[str]:
    paths: set[str] = set()

    for entry in entries:
        paths.add(entry.path)

        if entry.secondary_path is not None:
            paths.add(entry.secondary_path)

    return paths


def command_error_detail(
    result: CommandResult,
) -> str:
    detail = result.stderr.strip() or result.stdout.strip()
    return "" if not detail else ": " + detail


def set_mismatch_message(
    prefix: str,
    missing: Sequence[str],
    extra: Sequence[str],
) -> str:
    details = [prefix]

    if missing:
        details.append(
            "Missing: " + ", ".join(missing) + "."
        )

    if extra:
        details.append(
            "Unexpected: " + ", ".join(extra) + "."
        )

    return " ".join(details)
