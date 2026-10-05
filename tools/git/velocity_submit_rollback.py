from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Callable

from velocity_submit_contract import (
    ExitCode,
    InstallReceipt,
    ReceiptFile,
    SubmitError,
    UID_CONTENT_PATTERN,
    atomic_copy,
    remove_tree,
    sha256_file,
    validate_repository_target,
)
from velocity_submit_git import (
    RepositoryController,
    set_mismatch_message,
    status_paths,
)


InputFunction = Callable[[str], str]
OutputFunction = Callable[[str], None]

ROLLBACK_CONFIRMATION = "ROLLBACK"


@dataclass(frozen=True)
class RollbackPlan:
    receipt: InstallReceipt
    replace_entries: tuple[ReceiptFile, ...]
    add_entries: tuple[ReceiptFile, ...]
    derived_uid_paths: tuple[str, ...]
    allowed_paths: tuple[str, ...]


@dataclass(frozen=True)
class RollbackResult:
    delivery_id: str
    base_commit: str
    replacements_restored: int
    additions_removed: int
    uid_sidecars_removed: int


class DeliveryRollback:
    def __init__(
        self,
        repository: RepositoryController,
    ) -> None:
        self.repository = repository

    def rollback(
        self,
        receipt: InstallReceipt,
        *,
        input_function: InputFunction,
    ) -> RollbackResult:
        self.repository.validate_project()
        self.repository.validate_no_git_operation()
        self._require_installed_state(receipt)
        self._require_receipt_baseline(receipt)
        plan = self._build_plan(receipt)
        self._audit_working_tree(plan)
        self._require_confirmation(
            plan,
            input_function,
        )
        return self._execute(plan)

    def _require_installed_state(
        self,
        receipt: InstallReceipt,
    ) -> None:
        if receipt.state == "installing":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "An interrupted installation requires manual "
                "recovery.",
                "Inspect .git/velocity-submit and backups before "
                "rolling back.",
            )

        if receipt.state == "local_commit_only":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "A local commit exists for this delivery. Rollback "
                "does not undo commits.",
                "Use Retry Push to synchronize the preserved "
                "commit.",
            )

        if receipt.state != "installed":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Active receipt state does not allow rollback: "
                + receipt.state
                + ".",
                "Inspect .git/velocity-submit before continuing.",
            )

    def _require_receipt_baseline(
        self,
        receipt: InstallReceipt,
    ) -> None:
        branch_process = self.repository.git.run(
            ["symbolic-ref", "--quiet", "--short", "HEAD"],
            check=False,
        )
        current_branch = branch_process.stdout.strip()

        if (
            branch_process.returncode != 0
            or current_branch != receipt.branch
        ):
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "Current branch does not match the delivery "
                "receipt.",
                "Return to branch "
                + receipt.branch
                + " before rolling back.",
            )

        head = self.repository.head_commit()

        if head != receipt.base_commit:
            raise SubmitError(
                ExitCode.BASELINE_ERROR,
                "BASELINE_ERROR",
                "HEAD moved after the delivery was installed.",
                "Do not roll back. Inspect the repository history "
                "before continuing.",
            )

    def _build_plan(
        self,
        receipt: InstallReceipt,
    ) -> RollbackPlan:
        replace_entries: list[ReceiptFile] = []
        add_entries: list[ReceiptFile] = []
        derived_uid_paths: list[str] = []

        for file_entry in receipt.files:
            target = validate_repository_target(
                self.repository.paths.root,
                file_entry.path,
                require_exists=False,
            )

            if file_entry.action == "replace":
                self._validate_replace_entry(file_entry, target)
                replace_entries.append(file_entry)
                continue

            self._validate_add_entry(file_entry, target)
            add_entries.append(file_entry)

            if not file_entry.path.endswith(".gd"):
                continue

            uid_path = file_entry.path + ".uid"

            if self._derived_uid_is_removable(uid_path):
                derived_uid_paths.append(uid_path)

        allowed_paths = tuple(
            sorted(
                {
                    *(entry.path for entry in receipt.files),
                    *derived_uid_paths,
                },
                key=str.casefold,
            )
        )

        return RollbackPlan(
            receipt=receipt,
            replace_entries=tuple(replace_entries),
            add_entries=tuple(add_entries),
            derived_uid_paths=tuple(derived_uid_paths),
            allowed_paths=allowed_paths,
        )

    def _validate_replace_entry(
        self,
        file_entry: ReceiptFile,
        target: Path,
    ) -> None:
        if not target.is_file():
            raise SubmitError(
                ExitCode.HASH_ERROR,
                "HASH_ERROR",
                "Installed replacement is missing: "
                + file_entry.path
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

        if sha256_file(target) != file_entry.sha256:
            raise SubmitError(
                ExitCode.HASH_ERROR,
                "HASH_ERROR",
                "Installed target drifted after install: "
                + file_entry.path
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

        backup = self.repository.paths.backup_directory.joinpath(
            *PurePosixPath(file_entry.path).parts
        )

        if not backup.is_file() or backup.is_symlink():
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Backup is missing for replacement: "
                + file_entry.path
                + ".",
                "Stop. Do not modify repository files manually.",
            )

        if (
            file_entry.previous_sha256 is None
            or sha256_file(backup) != file_entry.previous_sha256
        ):
            raise SubmitError(
                ExitCode.HASH_ERROR,
                "HASH_ERROR",
                "Backup hash does not match the receipt: "
                + file_entry.path
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

    def _validate_add_entry(
        self,
        file_entry: ReceiptFile,
        target: Path,
    ) -> None:
        if not target.is_file():
            raise SubmitError(
                ExitCode.HASH_ERROR,
                "HASH_ERROR",
                "Installed addition is missing: "
                + file_entry.path
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

        if sha256_file(target) != file_entry.sha256:
            raise SubmitError(
                ExitCode.HASH_ERROR,
                "HASH_ERROR",
                "Installed addition drifted after install: "
                + file_entry.path
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

    def _derived_uid_is_removable(
        self,
        uid_path: str,
    ) -> bool:
        target = validate_repository_target(
            self.repository.paths.root,
            uid_path,
            require_exists=False,
        )

        if not target.exists():
            return False

        if self.repository.is_tracked(uid_path):
            raise SubmitError(
                ExitCode.UID_ERROR,
                "UID_ERROR",
                "Derived UID sidecar is tracked unexpectedly: "
                + uid_path
                + ".",
                "Stop. Inspect the repository before rolling back.",
            )

        content = target.read_text(
            encoding="utf-8",
            errors="strict",
        ).strip()

        if not UID_CONTENT_PATTERN.fullmatch(content):
            raise SubmitError(
                ExitCode.UID_ERROR,
                "UID_ERROR",
                "Derived UID sidecar content is invalid: "
                + uid_path
                + ".",
                "Stop. Inspect the file before rolling back.",
            )

        return True

    def _audit_working_tree(
        self,
        plan: RollbackPlan,
    ) -> None:
        status_entries = self.repository.read_status()

        staged = sorted(
            {
                entry.path
                for entry in status_entries
                if entry.is_staged() and not entry.is_untracked()
            },
            key=str.casefold,
        )

        if staged:
            raise SubmitError(
                ExitCode.STAGING_ERROR,
                "STAGING_ERROR",
                "Rollback requires an empty Git index. Staged: "
                + ", ".join(staged)
                + ".",
                "Unstage those paths manually before rolling back.",
            )

        actual_paths = status_paths(status_entries)
        unexpected = sorted(
            actual_paths - set(plan.allowed_paths),
            key=str.casefold,
        )

        if unexpected:
            raise SubmitError(
                ExitCode.WORKTREE_ERROR,
                "WORKTREE_ERROR",
                set_mismatch_message(
                    "Working tree contains changes outside the "
                    "installed delivery.",
                    [],
                    unexpected,
                ),
                "Resolve unexpected changes before rolling back.",
            )

    def _require_confirmation(
        self,
        plan: RollbackPlan,
        input_function: InputFunction,
    ) -> None:
        confirmation = input_function(
            "Type "
            + ROLLBACK_CONFIRMATION
            + " to restore baseline "
            + plan.receipt.base_commit[:7]
            + " and discard delivery "
            + plan.receipt.delivery_id
            + ": "
        ).strip()

        if confirmation != ROLLBACK_CONFIRMATION:
            raise SubmitError(
                ExitCode.CANCELLED,
                "CANCELLED",
                "Rollback was cancelled.",
                "Repository files were not modified.",
            )

    def _execute(
        self,
        plan: RollbackPlan,
    ) -> RollbackResult:
        errors: list[str] = []
        replacements_restored = 0
        additions_removed = 0
        uid_sidecars_removed = 0
        removed_add_parents: list[Path] = []
        uid_paths = set(plan.derived_uid_paths)

        for file_entry in reversed(plan.receipt.files):
            relative_parts = PurePosixPath(
                file_entry.path
            ).parts
            target = self.repository.paths.root.joinpath(
                *relative_parts
            )

            try:
                if file_entry.action == "add":
                    uid_path = file_entry.path + ".uid"

                    if uid_path in uid_paths:
                        uid_target = (
                            self.repository.paths.root.joinpath(
                                *PurePosixPath(uid_path).parts
                            )
                        )

                        if uid_target.exists():
                            uid_target.unlink()
                            uid_sidecars_removed += 1

                    if target.exists():
                        target.unlink()
                        additions_removed += 1

                    removed_add_parents.append(target.parent)
                    continue

                backup = (
                    self.repository.paths.backup_directory
                    .joinpath(*relative_parts)
                )
                atomic_copy(backup, target)

                if (
                    file_entry.previous_sha256 is None
                    or sha256_file(target)
                    != file_entry.previous_sha256
                ):
                    raise OSError(
                        "restored hash does not match"
                    )

                replacements_restored += 1
            except OSError as error:
                errors.append(
                    file_entry.path + ": " + str(error)
                )

        self._prune_empty_directories(removed_add_parents)

        if errors:
            raise SubmitError(
                ExitCode.INSTALL_ERROR,
                "INSTALL_ERROR",
                "Rollback failed: " + "; ".join(errors),
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

        remaining = self.repository.read_status()

        if remaining:
            paths = sorted(
                status_paths(remaining),
                key=str.casefold,
            )
            raise SubmitError(
                ExitCode.FINAL_STATE_ERROR,
                "FINAL_STATE_ERROR",
                "Working tree is not clean after rollback: "
                + ", ".join(paths)
                + ".",
                "Stop. Backups and receipt were preserved as "
                "evidence.",
            )

        try:
            remove_tree(
                self.repository.paths.state_directory
            )
        except OSError as error:
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Could not remove the delivery state directory: "
                + str(error),
                "Remove .git/velocity-submit manually after "
                "verifying git status is clean.",
            ) from error

        return RollbackResult(
            delivery_id=plan.receipt.delivery_id,
            base_commit=plan.receipt.base_commit,
            replacements_restored=replacements_restored,
            additions_removed=additions_removed,
            uid_sidecars_removed=uid_sidecars_removed,
        )

    def _prune_empty_directories(
        self,
        parents: list[Path],
    ) -> None:
        root = self.repository.paths.root

        for parent in parents:
            current = parent

            while current != root:
                try:
                    current.rmdir()
                except OSError:
                    break

                current = current.parent
