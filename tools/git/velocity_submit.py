from __future__ import annotations

import argparse
import shutil
import sys

from dataclasses import replace
from pathlib import Path, PurePosixPath
from typing import Callable, Sequence

from velocity_submit_contract import (
    RECEIPT_SCHEMA,
    TOOL_VERSION,
    ExitCode,
    InstallReceipt,
    ManifestFile,
    ReceiptFile,
    SubmitError,
    SubmitManifest,
    ValidatedPackage,
    atomic_copy,
    delete_verified_external_zip,
    manifest_digest,
    open_validated_package,
    remove_tree,
    sha256_file,
    validate_repository_target,
    write_receipt,
)

from velocity_submit_git import (
    CommitResult,
    RepositoryController,
    SubmitPreflight,
)

from velocity_submit_rollback import DeliveryRollback


OutputFunction = Callable[[str], None]
InputFunction = Callable[[str], str]
PackageSelector = Callable[[], Path | None]


class DeliveryInstaller:
    def __init__(
        self,
        repository: RepositoryController,
    ) -> None:
        self.repository = repository

    def install(
        self,
        package: ValidatedPackage,
    ) -> InstallReceipt:
        self.repository.validate_project()
        self.repository.validate_no_git_operation()
        base_commit = self.repository.validate_baseline(
            package.manifest,
            fetch_remote=True,
        )
        self._require_package_outside_repository(package.zip_path)

        existing_receipt = self.repository.load_receipt()

        if existing_receipt is not None:
            return self._handle_existing_receipt(
                existing_receipt,
                package,
            )

        self.repository.require_clean_for_install()
        state_directory = self.repository.paths.state_directory

        if state_directory.exists():
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Velocity Submit state directory exists without "
                "a valid receipt.",
                "Inspect .git/velocity-submit before continuing.",
            )

        receipt_files = self._validate_install_actions(package)
        receipt = InstallReceipt(
            schema=RECEIPT_SCHEMA,
            state="installing",
            delivery_id=package.manifest.delivery_id,
            manifest_sha256=package.manifest_sha256,
            package_sha256=package.package_sha256,
            package_path=str(package.zip_path),
            base_commit=base_commit,
            branch=package.manifest.expected_branch,
            remote=package.manifest.remote,
            commit_message=package.manifest.commit_message,
            verification_summary=(
                package.manifest.verification_summary
            ),
            files=receipt_files,
            commit_hash=None,
        )

        applied: list[ReceiptFile] = []
        created_directories: list[Path] = []

        try:
            self._prepare_installation(package, receipt)
            write_receipt(
                self.repository.paths.receipt_path,
                receipt,
            )

            for file_entry in receipt.files:
                target = validate_repository_target(
                    self.repository.paths.root,
                    file_entry.path,
                    require_exists=(
                        file_entry.action == "replace"
                    ),
                )
                self._create_parent_directories(
                    target.parent,
                    created_directories,
                )
                prepared = (
                    self.repository.paths.prepared_directory
                    .joinpath(
                        *PurePosixPath(file_entry.path).parts
                    )
                )
                atomic_copy(prepared, target)
                applied.append(file_entry)

            self._verify_installed_files(receipt)
            installed_receipt = replace(
                receipt,
                state="installed",
            )
            write_receipt(
                self.repository.paths.receipt_path,
                installed_receipt,
            )
            remove_tree(
                self.repository.paths.prepared_directory
            )
            return installed_receipt

        except BaseException as error:
            rollback_errors = self._rollback_install(
                applied,
                created_directories,
            )

            if not rollback_errors:
                remove_tree(
                    self.repository.paths.state_directory
                )

            if isinstance(error, SubmitError):
                if rollback_errors:
                    raise SubmitError(
                        ExitCode.INSTALL_ERROR,
                        "INSTALL_ERROR",
                        error.message
                        + " Rollback also failed: "
                        + "; ".join(rollback_errors),
                        "Stop. Inspect receipt and backups before "
                        "changing repository files.",
                    ) from error
                raise

            if isinstance(error, KeyboardInterrupt):
                if rollback_errors:
                    raise SubmitError(
                        ExitCode.INSTALL_ERROR,
                        "INSTALL_ERROR",
                        "Install was interrupted and rollback failed: "
                        + "; ".join(rollback_errors),
                        "Stop. Inspect receipt and backups.",
                    ) from error
                raise

            message = str(error) or error.__class__.__name__

            if rollback_errors:
                message += (
                    ". Rollback also failed: "
                    + "; ".join(rollback_errors)
                )

            raise SubmitError(
                ExitCode.INSTALL_ERROR,
                "INSTALL_ERROR",
                "Package installation failed: " + message,
                (
                    "Stop and inspect receipt and backups."
                    if rollback_errors
                    else "The repository was restored; inspect the "
                    "package before retrying."
                ),
            ) from error

    def verify_installed_receipt(
        self,
        receipt: InstallReceipt,
    ) -> None:
        if receipt.state != "installed":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Active receipt is not installed.",
                "Recover the active delivery before continuing.",
            )

        self._verify_installed_files(receipt)

    def _handle_existing_receipt(
        self,
        receipt: InstallReceipt,
        package: ValidatedPackage,
    ) -> InstallReceipt:
        if receipt.state == "installing":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "An interrupted installation requires recovery.",
                "Do not install another package. Inspect backups.",
            )

        if receipt.state == "local_commit_only":
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "A local commit is waiting for push retry.",
                "Run guided mode to retry the preserved push.",
            )

        compare_package_to_receipt(package, receipt)
        self.verify_installed_receipt(receipt)
        return receipt

    def _validate_install_actions(
        self,
        package: ValidatedPackage,
    ) -> tuple[ReceiptFile, ...]:
        receipt_files: list[ReceiptFile] = []

        for file_entry in package.manifest.files:
            target = validate_repository_target(
                self.repository.paths.root,
                file_entry.path,
                require_exists=(file_entry.action == "replace"),
            )
            tracked = self.repository.is_tracked(file_entry.path)

            if file_entry.action == "add":
                if target.exists() or tracked:
                    raise SubmitError(
                        ExitCode.INSTALL_ERROR,
                        "INSTALL_ERROR",
                        "Add target already exists or is tracked: "
                        + file_entry.path
                        + ".",
                        "Use a package built for the current baseline.",
                    )

                previous_hash = None
            else:
                if not target.exists() or not tracked:
                    raise SubmitError(
                        ExitCode.INSTALL_ERROR,
                        "INSTALL_ERROR",
                        "Replace target is missing or untracked: "
                        + file_entry.path
                        + ".",
                        "Use a package built for the current baseline.",
                    )

                previous_hash = sha256_file(target)

            receipt_files.append(
                ReceiptFile(
                    path=file_entry.path,
                    sha256=file_entry.sha256,
                    action=file_entry.action,
                    previous_sha256=previous_hash,
                )
            )

        return tuple(receipt_files)

    def _prepare_installation(
        self,
        package: ValidatedPackage,
        receipt: InstallReceipt,
    ) -> None:
        state = self.repository.paths.state_directory
        backups = self.repository.paths.backup_directory
        prepared = self.repository.paths.prepared_directory
        backups.mkdir(parents=True, exist_ok=False)
        prepared.mkdir(parents=True, exist_ok=False)

        for file_entry in receipt.files:
            relative_parts = PurePosixPath(
                file_entry.path
            ).parts
            source = package.source_for(file_entry.path)
            prepared_target = prepared.joinpath(*relative_parts)
            prepared_target.parent.mkdir(
                parents=True,
                exist_ok=True,
            )
            shutil.copyfile(source, prepared_target)

            if sha256_file(prepared_target) != file_entry.sha256:
                raise SubmitError(
                    ExitCode.HASH_ERROR,
                    "HASH_ERROR",
                    "Prepared copy hash mismatch: "
                    + file_entry.path
                    + ".",
                    "Do not install this package.",
                )

            if file_entry.action != "replace":
                continue

            original = self.repository.paths.root.joinpath(
                *relative_parts
            )
            backup = backups.joinpath(*relative_parts)
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, backup)

            if (
                file_entry.previous_sha256 is None
                or sha256_file(backup)
                != file_entry.previous_sha256
            ):
                raise SubmitError(
                    ExitCode.HASH_ERROR,
                    "HASH_ERROR",
                    "Backup hash mismatch: "
                    + file_entry.path
                    + ".",
                    "Do not install this package.",
                )

        if not state.is_dir():
            raise SubmitError(
                ExitCode.INSTALL_ERROR,
                "INSTALL_ERROR",
                "Installation state directory was not created.",
                "Inspect .git permissions.",
            )

    def _verify_installed_files(
        self,
        receipt: InstallReceipt,
    ) -> None:
        for file_entry in receipt.files:
            target = validate_repository_target(
                self.repository.paths.root,
                file_entry.path,
                require_exists=True,
            )

            if sha256_file(target) != file_entry.sha256:
                raise SubmitError(
                    ExitCode.HASH_ERROR,
                    "HASH_ERROR",
                    "Installed target hash mismatch: "
                    + file_entry.path
                    + ".",
                    "Do not submit. Restore or reinstall.",
                )

    def _rollback_install(
        self,
        applied: Sequence[ReceiptFile],
        created_directories: Sequence[Path],
    ) -> list[str]:
        errors: list[str] = []

        for file_entry in reversed(applied):
            target = self.repository.paths.root.joinpath(
                *PurePosixPath(file_entry.path).parts
            )

            try:
                if file_entry.action == "add":
                    if target.exists():
                        target.unlink()
                    continue

                backup = (
                    self.repository.paths.backup_directory
                    .joinpath(
                        *PurePosixPath(file_entry.path).parts
                    )
                )

                if not backup.is_file():
                    raise OSError("backup is missing")

                atomic_copy(backup, target)

                if (
                    file_entry.previous_sha256 is None
                    or sha256_file(target)
                    != file_entry.previous_sha256
                ):
                    raise OSError(
                        "restored hash does not match"
                    )
            except OSError as error:
                errors.append(
                    file_entry.path + ": " + str(error)
                )

        for directory in reversed(created_directories):
            try:
                directory.rmdir()
            except OSError:
                pass

        return errors

    def _create_parent_directories(
        self,
        parent: Path,
        created_directories: list[Path],
    ) -> None:
        missing: list[Path] = []
        current = parent

        while (
            current != self.repository.paths.root
            and not current.exists()
        ):
            missing.append(current)
            current = current.parent

        if current.is_symlink():
            raise SubmitError(
                ExitCode.INSTALL_ERROR,
                "INSTALL_ERROR",
                "Target parent traverses a symlink.",
                "Resolve repository paths before installing.",
            )

        for directory in reversed(missing):
            directory.mkdir()
            created_directories.append(directory)

    def _require_package_outside_repository(
        self,
        package_path: Path,
    ) -> None:
        try:
            package_path.resolve(strict=True).relative_to(
                self.repository.paths.root.resolve(strict=True)
            )
        except ValueError:
            return

        raise SubmitError(
            ExitCode.PACKAGE_ERROR,
            "PACKAGE_ERROR",
            "Delivery ZIP must remain outside Velocity.",
            "Move the ZIP outside the repository and retry.",
        )


class SubmitCoordinator:
    def __init__(
        self,
        repository: RepositoryController,
    ) -> None:
        self.repository = repository

    def submit(
        self,
        package: ValidatedPackage,
        receipt: InstallReceipt,
        *,
        input_function: InputFunction,
        output_function: OutputFunction,
    ) -> tuple[CommitResult, str]:
        compare_package_to_receipt(package, receipt)
        preflight = self.repository.submit_preflight(
            receipt,
            package.manifest,
        )
        staged = False

        try:
            staged = True
            name_status = self.repository.stage_and_audit(
                preflight
            )
            self._print_submit_summary(
                package,
                receipt,
                preflight,
                name_status,
                output_function,
            )
            confirmation = input_function(
                "Type SUBMIT to confirm tests passed, "
                "commit and push: "
            )

            if confirmation != "SUBMIT":
                self.repository.unstage(
                    preflight.allowed_paths
                )
                staged = False
                raise SubmitError(
                    ExitCode.CANCELLED,
                    "CANCELLED",
                    "Submit cancelled by user.",
                    "Installed files and receipt were preserved.",
                )

            commit = self.repository.commit(
                package.manifest.commit_message
            )
            staged = False
            local_receipt = replace(
                receipt,
                state="local_commit_only",
                commit_hash=commit.commit_hash,
            )
            try:
                write_receipt(
                    self.repository.paths.receipt_path,
                    local_receipt,
                )
            except SubmitError as error:
                output_function("")
                output_function(
                    "VELOCITY SUBMIT RESULT: "
                    "LOCAL_COMMIT_ONLY"
                )
                output_function(
                    "Commit: "
                    + commit.commit_hash[:7]
                    + " "
                    + commit.subject
                )
                raise SubmitError(
                    ExitCode.FINAL_STATE_ERROR,
                    "FINAL_STATE_ERROR",
                    "Local commit exists but receipt update failed: "
                    + error.message,
                    "Do not create another commit or push until "
                    "repository state is inspected.",
                ) from error

            remaining_status = self.repository.read_status()

            if remaining_status:
                output_function("")
                output_function(
                    "VELOCITY SUBMIT RESULT: "
                    "LOCAL_COMMIT_ONLY"
                )
                output_function(
                    "Commit: "
                    + commit.commit_hash[:7]
                    + " "
                    + commit.subject
                )
                raise SubmitError(
                    ExitCode.FINAL_STATE_ERROR,
                    "FINAL_STATE_ERROR",
                    "Working tree is not clean after commit.",
                    "Do not push. Inspect changes created by hooks.",
                )

            try:
                status = self.repository.push_and_verify(
                    package.manifest,
                    commit.commit_hash,
                )
            except SubmitError as error:
                if error.code == ExitCode.PUSH_ERROR:
                    output_function("")
                    output_function(
                        "VELOCITY SUBMIT RESULT: "
                        "LOCAL_COMMIT_ONLY"
                    )
                    output_function(
                        "Commit: "
                        + commit.commit_hash[:7]
                        + " "
                        + commit.subject
                    )
                raise

            remove_tree(
                self.repository.paths.state_directory
            )
            return commit, status

        except KeyboardInterrupt as error:
            if staged:
                try:
                    self.repository.unstage(
                        preflight.allowed_paths
                    )
                except SubmitError:
                    pass

            raise SubmitError(
                ExitCode.CANCELLED,
                "CANCELLED",
                "Submit interrupted by user.",
                "Installed files and receipt were preserved.",
            ) from error

        except SubmitError as error:
            if (
                staged
                and error.code
                not in (
                    ExitCode.COMMIT_ERROR,
                    ExitCode.CANCELLED,
                )
            ):
                try:
                    self.repository.unstage(
                        preflight.allowed_paths
                    )
                except SubmitError:
                    pass
            raise

    def retry_push(
        self,
        package: ValidatedPackage,
        receipt: InstallReceipt,
        *,
        input_function: InputFunction,
    ) -> tuple[str, str]:
        compare_package_to_receipt(package, receipt)
        self.repository.retry_push_preflight(
            receipt,
            package.manifest,
        )
        confirmation = input_function(
            "Type PUSH to retry the preserved local commit: "
        )

        if confirmation != "PUSH":
            raise SubmitError(
                ExitCode.CANCELLED,
                "CANCELLED",
                "Push retry cancelled by user.",
                "The local commit and receipt were preserved.",
            )

        if receipt.commit_hash is None:
            raise SubmitError(
                ExitCode.INSTALL_STATE_ERROR,
                "INSTALL_STATE_ERROR",
                "Receipt lacks local commit hash.",
                "Inspect repository state manually.",
            )

        status = self.repository.push_and_verify(
            package.manifest,
            receipt.commit_hash,
        )
        commit_hash = receipt.commit_hash
        remove_tree(self.repository.paths.state_directory)
        return commit_hash, status

    def _print_submit_summary(
        self,
        package: ValidatedPackage,
        receipt: InstallReceipt,
        preflight: SubmitPreflight,
        name_status: str,
        output_function: OutputFunction,
    ) -> None:
        output_function("")
        output_function("VELOCITY DELIVERY READY TO SUBMIT")
        output_function("---------------------------------")
        output_function(
            "Delivery: " + receipt.delivery_id
        )
        output_function(
            "Package: " + str(package.zip_path)
        )
        output_function(
            "Branch: " + receipt.branch
        )
        output_function(
            "Base: " + receipt.base_commit[:7]
        )
        output_function(
            "Commit: " + receipt.commit_message
        )
        output_function(
            "Files: " + str(len(preflight.allowed_paths))
        )
        output_function(
            "Godot UID sidecars: "
            + str(len(preflight.uid_paths))
        )

        if receipt.verification_summary:
            output_function("Required verification:")

            for item in receipt.verification_summary:
                output_function("- " + item)

        output_function("")
        output_function("STAGED DELIVERY")
        output_function("----------------")
        output_function(name_status)
        output_function("")


def compare_package_to_receipt(
    package: ValidatedPackage,
    receipt: InstallReceipt,
) -> None:
    mismatches: list[str] = []

    if package.package_sha256 != receipt.package_sha256:
        mismatches.append("package SHA-256")

    if package.manifest_sha256 != receipt.manifest_sha256:
        mismatches.append("manifest SHA-256")

    if package.manifest.delivery_id != receipt.delivery_id:
        mismatches.append("delivery ID")

    if package.manifest.commit_message != receipt.commit_message:
        mismatches.append("commit message")

    if package.manifest.expected_branch != receipt.branch:
        mismatches.append("branch")

    if package.manifest.remote != receipt.remote:
        mismatches.append("remote")

    if not receipt.base_commit.startswith(
        package.manifest.expected_head
    ):
        mismatches.append("base commit")

    expected_files = tuple(
        (
            file_entry.path,
            file_entry.sha256,
            file_entry.action,
        )
        for file_entry in package.manifest.files
    )
    receipt_files = tuple(
        (
            file_entry.path,
            file_entry.sha256,
            file_entry.action,
        )
        for file_entry in receipt.files
    )

    if expected_files != receipt_files:
        mismatches.append("file contract")

    if mismatches:
        raise SubmitError(
            ExitCode.INSTALL_STATE_ERROR,
            "INSTALL_STATE_ERROR",
            "Selected package does not match active receipt: "
            + ", ".join(mismatches)
            + ".",
            "Select the exact ZIP used during Install.",
        )


def select_package_file() -> Path | None:
    try:
        import tkinter
        from tkinter import filedialog
    except ImportError as error:
        raise SubmitError(
            ExitCode.PACKAGE_ERROR,
            "PACKAGE_ERROR",
            "Native file picker is unavailable: " + str(error),
            "Use -Package with an explicit ZIP path.",
        ) from error

    try:
        root = tkinter.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        selected = filedialog.askopenfilename(
            parent=root,
            title="Select Velocity delivery ZIP",
            filetypes=(
                ("Velocity delivery packages", "*.zip"),
                ("All files", "*.*"),
            ),
        )
        root.destroy()
    except tkinter.TclError as error:
        raise SubmitError(
            ExitCode.PACKAGE_ERROR,
            "PACKAGE_ERROR",
            "Native file picker could not open: " + str(error),
            "Use -Package with an explicit ZIP path.",
        ) from error

    if not selected:
        return None

    return Path(selected)


def resolve_package_path(
    receipt: InstallReceipt | None,
    explicit_path: Path | None,
    package_selector: PackageSelector,
) -> Path:
    if explicit_path is not None:
        return explicit_path

    if receipt is not None:
        remembered = Path(receipt.package_path)

        if remembered.is_file() and not remembered.is_symlink():
            if sha256_file(remembered) == receipt.package_sha256:
                return remembered

    selected = package_selector()

    if selected is None:
        raise SubmitError(
            ExitCode.CANCELLED,
            "CANCELLED",
            "Package selection was cancelled.",
            "Repository files were not modified.",
        )

    return selected


def validate_package_only(
    package_path: Path,
    output_function: OutputFunction,
) -> None:
    with open_validated_package(package_path) as package:
        output_function("VELOCITY PACKAGE VALIDATION: PASS")
        output_function(
            "Delivery: " + package.manifest.delivery_id
        )
        output_function(
            "Package SHA-256: " + package.package_sha256
        )
        output_function(
            "Manifest files: "
            + str(len(package.manifest.files))
        )


def delete_original_package(
    package_path: Path,
    package_sha256: str,
    repository_root: Path,
    *,
    input_function: InputFunction,
    output_function: OutputFunction,
) -> None:
    answer = input_function(
        "Delete the original ZIP now? [y/N]: "
    ).strip().casefold()

    if answer not in ("y", "yes", "s", "si", "sí"):
        output_function("Package cleanup: kept original ZIP")
        return

    try:
        delete_verified_external_zip(
            package_path,
            package_sha256,
            repository_root,
        )
        output_function("Package cleanup: original ZIP deleted")
    except OSError as error:
        output_function(
            "PACKAGE CLEANUP: WARNING — " + str(error)
        )


def run_tool(
    *,
    start_directory: Path,
    package_path: Path | None = None,
    mode: str = "guided",
    input_function: InputFunction = input,
    output_function: OutputFunction = print,
    package_selector: PackageSelector = select_package_file,
) -> ExitCode:
    try:
        repository = RepositoryController.discover(
            start_directory
        )
        receipt = repository.load_receipt()

        if mode == "validate-package":
            selected = resolve_package_path(
                None,
                package_path,
                package_selector,
            )
            validate_package_only(selected, output_function)
            return ExitCode.PASS

        if mode == "rollback":
            if receipt is None:
                raise SubmitError(
                    ExitCode.INSTALL_STATE_ERROR,
                    "INSTALL_STATE_ERROR",
                    "No active delivery receipt exists.",
                    "Nothing to roll back.",
                )

            coordinator = DeliveryRollback(repository)
            result = coordinator.rollback(
                receipt,
                input_function=input_function,
            )
            output_function("VELOCITY DELIVERY ROLLBACK: PASS")
            output_function(
                "Delivery: " + result.delivery_id
            )
            output_function(
                "Baseline restored: "
                + result.base_commit[:7]
            )
            output_function(
                "Replacements restored: "
                + str(result.replacements_restored)
            )
            output_function(
                "Additions removed: "
                + str(result.additions_removed)
            )
            output_function(
                "UID sidecars removed: "
                + str(result.uid_sidecars_removed)
            )
            output_function(
                "State: receipt and backups cleared"
            )
            output_function(result.package_cleanup_message)
            return ExitCode.PASS

        if mode == "guided":
            if receipt is None:
                actual_mode = "install"
            elif receipt.state == "installed":
                actual_mode = "submit"
            elif receipt.state == "local_commit_only":
                actual_mode = "retry-push"
            else:
                raise SubmitError(
                    ExitCode.INSTALL_STATE_ERROR,
                    "INSTALL_STATE_ERROR",
                    "An interrupted installation requires recovery.",
                    "Inspect .git/velocity-submit and backups.",
                )
        else:
            actual_mode = mode

        selected = resolve_package_path(
            receipt,
            package_path,
            package_selector,
        )

        with open_validated_package(selected) as package:
            if actual_mode == "install":
                installer = DeliveryInstaller(repository)
                installed = installer.install(package)
                output_function("VELOCITY DELIVERY INSTALL: PASS")
                output_function(
                    "Delivery: " + installed.delivery_id
                )
                output_function(
                    "Files installed: "
                    + str(len(installed.files))
                )
                output_function(
                    "Temporary extraction: cleaned"
                )
                output_function(
                    "Next: run the declared verification, then "
                    "invoke the tool again."
                )
                return ExitCode.PASS

            if receipt is None:
                raise SubmitError(
                    ExitCode.INSTALL_STATE_ERROR,
                    "INSTALL_STATE_ERROR",
                    "Submit requires an installed delivery receipt.",
                    "Run Install first.",
                )

            coordinator = SubmitCoordinator(repository)

            if actual_mode == "retry-push":
                commit_hash, status = coordinator.retry_push(
                    package,
                    receipt,
                    input_function=input_function,
                )
                output_function("")
                output_function("VELOCITY SUBMIT RESULT: PASS")
                output_function(
                    "Delivery: " + receipt.delivery_id
                )
                output_function(
                    "Commit: " + commit_hash[:7]
                )
                output_function("Remote: synchronized")
                output_function("Status: " + status)
                delete_original_package(
                    package.zip_path,
                    package.package_sha256,
                    repository.paths.root,
                    input_function=input_function,
                    output_function=output_function,
                )
                return ExitCode.PASS

            if actual_mode != "submit":
                raise SubmitError(
                    ExitCode.PACKAGE_ERROR,
                    "PACKAGE_ERROR",
                    "Unknown tool mode: " + actual_mode,
                    "Use guided mode or a supported explicit mode.",
                )

            commit, status = coordinator.submit(
                package,
                receipt,
                input_function=input_function,
                output_function=output_function,
            )
            output_function("")
            output_function("VELOCITY SUBMIT RESULT: PASS")
            output_function(
                "Delivery: " + receipt.delivery_id
            )
            output_function(
                "Commit: "
                + commit.commit_hash[:7]
                + " "
                + commit.subject
            )
            output_function(
                "Files: " + str(len(receipt.files))
            )
            output_function("Remote: synchronized")
            output_function("Status: " + status)
            delete_original_package(
                package.zip_path,
                package.package_sha256,
                repository.paths.root,
                input_function=input_function,
                output_function=output_function,
            )
            return ExitCode.PASS

    except KeyboardInterrupt:
        error = SubmitError(
            ExitCode.CANCELLED,
            "CANCELLED",
            "Operation interrupted by user.",
            "Repository state was preserved or rolled back.",
        )
        print_error(error, output_function)
        return error.code

    except SubmitError as error:
        print_error(error, output_function)
        return error.code


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Install and submit a Velocity delivery ZIP."
        )
    )
    parser.add_argument(
        "--package",
        type=Path,
        help="External Velocity delivery ZIP.",
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument(
        "--install",
        action="store_true",
        help="Install package files without Git staging.",
    )
    modes.add_argument(
        "--submit",
        action="store_true",
        help="Submit an installed delivery.",
    )
    modes.add_argument(
        "--validate-package",
        action="store_true",
        help="Validate package without repository changes.",
    )
    modes.add_argument(
        "--rollback",
        action="store_true",
        help=(
            "Restore the baseline of the installed delivery "
            "and clear its receipt."
        ),
    )
    parser.add_argument(
        "--version",
        action="version",
        version="Velocity Submit Tool " + TOOL_VERSION,
    )
    return parser


def main(
    arguments: Sequence[str] | None = None,
) -> int:
    parsed = build_argument_parser().parse_args(arguments)

    if parsed.install:
        mode = "install"
    elif parsed.submit:
        mode = "submit"
    elif parsed.validate_package:
        mode = "validate-package"
    elif parsed.rollback:
        mode = "rollback"
    else:
        mode = "guided"

    code = run_tool(
        start_directory=Path.cwd(),
        package_path=parsed.package,
        mode=mode,
    )
    return int(code)


def print_error(
    error: SubmitError,
    output_function: OutputFunction,
) -> None:
    output_function("")
    output_function(
        "VELOCITY SUBMIT RESULT: " + error.category
    )
    output_function("Error: " + error.message)
    output_function("Safe action: " + error.action)


if __name__ == "__main__":
    sys.exit(main())
