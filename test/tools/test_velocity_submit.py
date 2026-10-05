from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

from pathlib import Path
from typing import Any
from unittest import mock


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOL_DIRECTORY = PROJECT_ROOT / "tools" / "git"

if str(TOOL_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(TOOL_DIRECTORY))


import velocity_submit  # noqa: E402
import velocity_submit_contract as contract  # noqa: E402
import velocity_submit_rollback  # noqa: E402

from velocity_submit import (  # noqa: E402
    DeliveryInstaller,
    delete_original_package,
)

from velocity_submit_rollback import DeliveryRollback  # noqa: E402

from velocity_submit_contract import (  # noqa: E402
    ExitCode,
    SubmitError,
    open_validated_package,
    parse_manifest_data,
    sha256_file,
)

from velocity_submit_git import (  # noqa: E402
    RepositoryController,
)


EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()


def run_command(
    arguments: list[str],
    *,
    cwd: Path,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    process = subprocess.run(
        arguments,
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=False,
        check=False,
    )

    if check and process.returncode != 0:
        raise RuntimeError(
            "Command failed: "
            + " ".join(arguments)
            + "\n"
            + process.stdout
            + process.stderr
        )

    return process


class VelocityFixture:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.remote = self.root / "remote.git"
        self.work = self.root / "velocity"
        self.packages = self.root / "packages"
        self.packages.mkdir()

        run_command(
            [
                "git",
                "init",
                "--bare",
                "--initial-branch=main",
                str(self.remote),
            ],
            cwd=self.root,
        )
        run_command(
            [
                "git",
                "init",
                "--initial-branch=main",
                str(self.work),
            ],
            cwd=self.root,
        )

        self.git("config", "user.name", "Velocity Test")
        self.git(
            "config",
            "user.email",
            "velocity-test@example.invalid",
        )
        self.write(
            "project.godot",
            '[application]\nconfig/name="velocity"\n',
        )
        self.write("docs/replace.txt", "baseline\n")
        self.write(
            "core/existing.gd",
            "extends RefCounted\n",
        )
        self.write(
            "core/existing.gd.uid",
            "uid://existing123\n",
        )
        self.git("add", "--", ".")
        self.git("commit", "-m", "chore(test): create baseline")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-u", "origin", "main")
        self.base_commit = self.head()

    def cleanup(self) -> None:
        self.temporary.cleanup()

    def git(
        self,
        *arguments: str,
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        return run_command(
            ["git", *arguments],
            cwd=self.work,
            check=check,
        )

    def head(self) -> str:
        return self.git("rev-parse", "HEAD").stdout.strip()

    def write(
        self,
        relative_path: str,
        content: str,
    ) -> Path:
        target = self.work.joinpath(*relative_path.split("/"))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def build_package(
        self,
        files: list[tuple[str, str, str]],
        *,
        delivery_id: str = "velocity-test-delivery",
        commit_message: str = "test(tools): delivery fixture",
        manifest_overrides: dict[str, Any] | None = None,
        extra_files: dict[str, bytes] | None = None,
        package_root: str | None = None,
    ) -> Path:
        root_name = package_root or delivery_id
        source_root = self.root / (
            "source-" + next(tempfile._get_candidate_names())
        )
        package_directory = source_root / root_name
        repository_files = package_directory / "repository_files"
        repository_files.mkdir(parents=True)
        manifest_files: list[dict[str, str]] = []

        for relative_path, content, action in files:
            source = repository_files.joinpath(
                *relative_path.split("/")
            )
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text(content, encoding="utf-8")
            manifest_files.append(
                {
                    "path": relative_path,
                    "sha256": sha256_file(source),
                    "action": action,
                }
            )

        manifest: dict[str, Any] = {
            "schema": "velocity-submit-manifest/v1",
            "delivery_id": delivery_id,
            "project": "velocity",
            "expected_branch": "main",
            "expected_head": self.base_commit[:7],
            "remote": "origin",
            "commit_message": commit_message,
            "godot_uid_policy": "required_for_new_gd",
            "verification_summary": [
                "Temporary delivery verification: PASS",
            ],
            "files": manifest_files,
        }

        if manifest_overrides:
            manifest.update(manifest_overrides)

        (package_directory / "SUBMIT_MANIFEST.json").write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
        )
        (package_directory / "README.txt").write_text(
            "Temporary Velocity delivery.\n",
            encoding="utf-8",
        )
        (package_directory / "SHA256SUMS.txt").write_text(
            "Temporary test sums.\n",
            encoding="utf-8",
        )

        if extra_files:
            for relative_path, content in extra_files.items():
                target = package_directory.joinpath(
                    *relative_path.split("/")
                )
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)

        zip_path = self.packages / (delivery_id + ".zip")

        with zipfile.ZipFile(
            zip_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
        ) as archive:
            for path in sorted(package_directory.rglob("*")):
                if path.is_file():
                    archive.write(
                        path,
                        path.relative_to(source_root).as_posix(),
                    )

        shutil.rmtree(source_root)
        return zip_path

    def advance_remote(self) -> None:
        clone = self.root / (
            "remote-clone-"
            + next(tempfile._get_candidate_names())
        )
        run_command(
            ["git", "clone", str(self.remote), str(clone)],
            cwd=self.root,
        )
        run_command(
            ["git", "config", "user.name", "Remote Test"],
            cwd=clone,
        )
        run_command(
            [
                "git",
                "config",
                "user.email",
                "remote-test@example.invalid",
            ],
            cwd=clone,
        )
        (clone / "remote.txt").write_text(
            "remote ahead\n",
            encoding="utf-8",
        )
        run_command(
            ["git", "add", "--", "remote.txt"],
            cwd=clone,
        )
        run_command(
            ["git", "commit", "-m", "test: remote ahead"],
            cwd=clone,
        )
        run_command(
            ["git", "push", "origin", "main"],
            cwd=clone,
        )


class ManifestTests(unittest.TestCase):
    def valid_data(self) -> dict[str, Any]:
        return {
            "schema": "velocity-submit-manifest/v1",
            "delivery_id": "velocity-test-delivery",
            "project": "velocity",
            "expected_branch": "main",
            "expected_head": "1234567",
            "remote": "origin",
            "commit_message": "docs(test): manifest fixture",
            "godot_uid_policy": "required_for_new_gd",
            "verification_summary": [],
            "files": [
                {
                    "path": "docs/test.md",
                    "sha256": EMPTY_SHA256,
                    "action": "add",
                }
            ],
        }

    def test_valid_manifest(self) -> None:
        manifest = parse_manifest_data(self.valid_data())
        self.assertEqual(manifest.delivery_id, "velocity-test-delivery")
        self.assertEqual(manifest.files[0].action, "add")

    def test_unknown_schema_is_rejected(self) -> None:
        data = self.valid_data()
        data["schema"] = "velocity-submit-manifest/v2"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_unknown_field_is_rejected(self) -> None:
        data = self.valid_data()
        data["command"] = "git add ."
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_invalid_commit_message_is_rejected(self) -> None:
        data = self.valid_data()
        data["commit_message"] = "quick update"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_path_traversal_is_rejected(self) -> None:
        data = self.valid_data()
        data["files"][0]["path"] = "../outside.txt"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_git_path_is_rejected(self) -> None:
        data = self.valid_data()
        data["files"][0]["path"] = ".git/config"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_backslash_path_is_rejected(self) -> None:
        data = self.valid_data()
        data["files"][0]["path"] = r"docs\test.md"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_case_collision_is_rejected(self) -> None:
        data = self.valid_data()
        second = dict(data["files"][0])
        second["path"] = "DOCS/TEST.MD"
        data["files"].append(second)
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_upsert_action_is_rejected(self) -> None:
        data = self.valid_data()
        data["files"][0]["action"] = "upsert"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)

    def test_uid_sidecar_cannot_be_declared(self) -> None:
        data = self.valid_data()
        data["files"][0]["path"] = "core/test.gd.uid"
        with self.assertRaises(SubmitError):
            parse_manifest_data(data)


class PackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = VelocityFixture()

    def tearDown(self) -> None:
        self.fixture.cleanup()

    def test_valid_package_extracts_declared_files(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        temporary_path: Path | None = None

        with open_validated_package(package_path) as package:
            temporary_path = package.temporary_directory
            self.assertTrue(
                package.source_for("docs/new.txt").is_file()
            )
            self.assertEqual(
                package.source_for("docs/new.txt").read_text(
                    encoding="utf-8"
                ),
                "new\n",
            )

        self.assertIsNotNone(temporary_path)
        self.assertFalse(temporary_path.exists())

    def test_non_zip_is_rejected(self) -> None:
        path = self.fixture.packages / "not-a-zip.txt"
        path.write_text("text\n", encoding="utf-8")
        with self.assertRaises(SubmitError):
            with open_validated_package(path):
                pass

    def test_extra_archive_file_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")],
            extra_files={"unexpected.bin": b"x"},
        )
        with self.assertRaises(SubmitError):
            with open_validated_package(package_path):
                pass

    def test_source_hash_mismatch_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )

        with zipfile.ZipFile(package_path, "r") as source:
            items = {
                info.filename: source.read(info)
                for info in source.infolist()
                if not info.is_dir()
            }

        manifest_name = next(
            name
            for name in items
            if name.endswith("/SUBMIT_MANIFEST.json")
        )
        manifest = json.loads(items[manifest_name])
        manifest["files"][0]["sha256"] = "0" * 64
        items[manifest_name] = (
            json.dumps(manifest).encode("utf-8")
        )

        with zipfile.ZipFile(package_path, "w") as target:
            for name, content in items.items():
                target.writestr(name, content)

        with self.assertRaises(SubmitError) as context:
            with open_validated_package(package_path):
                pass

        self.assertEqual(context.exception.code, ExitCode.HASH_ERROR)

    def test_multiple_package_roots_are_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        with zipfile.ZipFile(package_path, "a") as archive:
            archive.writestr("other-root/file.txt", "x")

        with self.assertRaises(SubmitError):
            with open_validated_package(package_path):
                pass

    def test_zip_slip_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        with zipfile.ZipFile(package_path, "a") as archive:
            archive.writestr("../escape.txt", "x")

        with self.assertRaises(SubmitError):
            with open_validated_package(package_path):
                pass

    def test_case_colliding_archive_path_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        with zipfile.ZipFile(package_path, "a") as archive:
            archive.writestr(
                "velocity-test-delivery/README.TXT",
                "duplicate",
            )

        with self.assertRaises(SubmitError):
            with open_validated_package(package_path):
                pass

    def test_symlink_archive_entry_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        info = zipfile.ZipInfo(
            "velocity-test-delivery/repository_files/link"
        )
        info.create_system = 3
        info.external_attr = (0o120777 << 16)

        with zipfile.ZipFile(package_path, "a") as archive:
            archive.writestr(info, "docs/new.txt")

        with self.assertRaises(SubmitError):
            with open_validated_package(package_path):
                pass

    def test_entry_limit_is_enforced(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        with mock.patch.object(contract, "MAX_ARCHIVE_ENTRIES", 1):
            with self.assertRaises(SubmitError):
                with open_validated_package(package_path):
                    pass

    def test_uncompressed_size_limit_is_enforced(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        with mock.patch.object(contract, "MAX_UNCOMPRESSED_BYTES", 8):
            with self.assertRaises(SubmitError):
                with open_validated_package(package_path):
                    pass

    @unittest.skipIf(
        not hasattr(os, "symlink"),
        "symlink unavailable",
    )
    def test_zip_symlink_path_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        link = self.fixture.packages / "package-link.zip"

        try:
            os.symlink(package_path, link)
        except OSError as error:
            self.skipTest("symlink creation unavailable: " + str(error))

        with self.assertRaises(SubmitError):
            with open_validated_package(link):
                pass


class InstallTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = VelocityFixture()
        self.repository = RepositoryController.discover(
            self.fixture.work
        )
        self.installer = DeliveryInstaller(self.repository)

    def tearDown(self) -> None:
        self.fixture.cleanup()

    def install_package(
        self,
        package_path: Path,
    ) -> Any:
        with open_validated_package(package_path) as package:
            return self.installer.install(package)

    def test_add_and_replace_install_transactionally(self) -> None:
        package_path = self.fixture.build_package(
            [
                ("docs/new.txt", "new\n", "add"),
                ("docs/replace.txt", "replacement\n", "replace"),
            ]
        )

        receipt = self.install_package(package_path)

        self.assertEqual(receipt.state, "installed")
        self.assertEqual(
            (self.fixture.work / "docs/new.txt").read_text(),
            "new\n",
        )
        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "replacement\n",
        )
        self.assertTrue(self.repository.paths.receipt_path.is_file())
        self.assertFalse(
            self.repository.paths.prepared_directory.exists()
        )
        self.assertTrue(
            self.repository.paths.backup_directory.joinpath(
                "docs",
                "replace.txt",
            ).is_file()
        )

    def test_install_creates_no_staging(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        self.install_package(package_path)

        self.assertEqual(
            self.fixture.git(
                "diff",
                "--cached",
                "--name-only",
            ).stdout,
            "",
        )

    def test_add_existing_target_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/replace.txt", "bad\n", "add")]
        )

        with self.assertRaises(SubmitError):
            self.install_package(package_path)

        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "baseline\n",
        )

    def test_replace_missing_target_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/missing.txt", "bad\n", "replace")]
        )

        with self.assertRaises(SubmitError):
            self.install_package(package_path)

    def test_dirty_repository_is_rejected(self) -> None:
        self.fixture.write("local.txt", "unexpected\n")
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )

        with self.assertRaises(SubmitError) as context:
            self.install_package(package_path)

        self.assertEqual(
            context.exception.code,
            ExitCode.WORKTREE_ERROR,
        )

    def test_remote_ahead_is_rejected(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.advance_remote()

        with self.assertRaises(SubmitError) as context:
            self.install_package(package_path)

        self.assertEqual(
            context.exception.code,
            ExitCode.BASELINE_ERROR,
        )

    def test_package_inside_repository_is_rejected(self) -> None:
        external = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        internal = self.fixture.work / "delivery.zip"
        shutil.copyfile(external, internal)

        with self.assertRaises(SubmitError):
            self.install_package(internal)

    def test_repeated_install_reports_same_receipt(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        first = self.install_package(package_path)
        second = self.install_package(package_path)

        self.assertEqual(first, second)

    def test_conflicting_receipt_blocks_other_package(self) -> None:
        first_path = self.fixture.build_package(
            [("docs/first.txt", "first\n", "add")],
            delivery_id="velocity-first-delivery",
        )
        second_path = self.fixture.build_package(
            [("docs/second.txt", "second\n", "add")],
            delivery_id="velocity-second-delivery",
        )
        self.install_package(first_path)

        with self.assertRaises(SubmitError) as context:
            self.install_package(second_path)

        self.assertEqual(
            context.exception.code,
            ExitCode.INSTALL_STATE_ERROR,
        )

    def test_partial_failure_rolls_back_all_files(self) -> None:
        package_path = self.fixture.build_package(
            [
                ("docs/replace.txt", "replacement\n", "replace"),
                ("docs/new.txt", "new\n", "add"),
            ]
        )
        original_atomic_copy = velocity_submit.atomic_copy
        call_count = 0

        def fail_second(source: Path, target: Path) -> None:
            nonlocal call_count
            call_count += 1

            if call_count == 2:
                raise OSError("controlled copy failure")

            original_atomic_copy(source, target)

        with mock.patch.object(
            velocity_submit,
            "atomic_copy",
            side_effect=fail_second,
        ):
            with self.assertRaises(SubmitError):
                self.install_package(package_path)

        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "baseline\n",
        )
        self.assertFalse(
            (self.fixture.work / "docs/new.txt").exists()
        )
        self.assertFalse(
            self.repository.paths.state_directory.exists()
        )
        self.assertEqual(
            self.fixture.git("status", "--porcelain").stdout,
            "",
        )


class RollbackTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = VelocityFixture()
        self.repository = RepositoryController.discover(
            self.fixture.work
        )
        self.installer = DeliveryInstaller(self.repository)
        self.coordinator = DeliveryRollback(self.repository)

    def tearDown(self) -> None:
        self.fixture.cleanup()

    def install_files(
        self,
        files: list[tuple[str, str, str]],
    ) -> Any:
        package_path = self.fixture.build_package(files)

        with open_validated_package(package_path) as package:
            return self.installer.install(package)

    def rollback(
        self,
        answer: str = "ROLLBACK",
    ) -> Any:
        receipt = self.repository.load_receipt()
        self.assertIsNotNone(receipt)
        return self.coordinator.rollback(
            receipt,
            input_function=lambda _prompt: answer,
        )

    def assert_clean_without_state(self) -> None:
        self.assertEqual(
            self.fixture.git("status", "--porcelain").stdout,
            "",
        )
        self.assertFalse(
            self.repository.paths.state_directory.exists()
        )

    def assert_delivery_preserved(self) -> None:
        receipt = self.repository.load_receipt()
        self.assertIsNotNone(receipt)
        self.assertEqual(receipt.state, "installed")

    def test_rollback_restores_baseline(self) -> None:
        self.install_files(
            [
                ("docs/new.txt", "new\n", "add"),
                ("docs/replace.txt", "replacement\n", "replace"),
            ]
        )

        result = self.rollback()

        self.assertEqual(result.replacements_restored, 1)
        self.assertEqual(result.additions_removed, 1)
        self.assertEqual(result.uid_sidecars_removed, 0)
        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "baseline\n",
        )
        self.assertFalse(
            (self.fixture.work / "docs/new.txt").exists()
        )
        self.assert_clean_without_state()

    def test_rollback_removes_created_directories(self) -> None:
        self.install_files(
            [("docs/created/deep/new.txt", "new\n", "add")]
        )

        self.rollback()

        self.assertFalse(
            (self.fixture.work / "docs/created").exists()
        )
        self.assert_clean_without_state()

    def test_rollback_removes_derived_untracked_uid(self) -> None:
        self.install_files(
            [("core/feature.gd", "extends RefCounted\n", "add")]
        )
        self.fixture.write(
            "core/feature.gd.uid",
            "uid://feature123\n",
        )

        result = self.rollback()

        self.assertEqual(result.uid_sidecars_removed, 1)
        self.assertFalse(
            (self.fixture.work / "core/feature.gd").exists()
        )
        self.assertFalse(
            (self.fixture.work / "core/feature.gd.uid").exists()
        )
        self.assert_clean_without_state()

    def test_rollback_rejects_invalid_derived_uid(self) -> None:
        self.install_files(
            [("core/feature.gd", "extends RefCounted\n", "add")]
        )
        self.fixture.write(
            "core/feature.gd.uid",
            "not a godot uid\n",
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.UID_ERROR,
        )
        self.assertTrue(
            (self.fixture.work / "core/feature.gd").exists()
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_tracked_derived_uid(self) -> None:
        self.fixture.write(
            "core/feature.gd.uid",
            "uid://trackedfeature123\n",
        )
        self.fixture.git("add", "--", "core/feature.gd.uid")
        self.fixture.git(
            "commit",
            "-m",
            "test: add tracked derived uid fixture",
        )
        self.fixture.git("push", "origin", "main")
        self.fixture.base_commit = self.fixture.head()
        self.install_files(
            [("core/feature.gd", "extends RefCounted\n", "add")]
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.UID_ERROR,
        )
        self.assertTrue(
            (self.fixture.work / "core/feature.gd").exists()
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_unexpected_changes(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.write("local.txt", "unexpected\n")

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.WORKTREE_ERROR,
        )
        self.assertTrue(
            (self.fixture.work / "docs/new.txt").exists()
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_staged_changes(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.git("add", "--", "docs/new.txt")

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.STAGING_ERROR,
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_drifted_target(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.write("docs/new.txt", "edited on top\n")

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.HASH_ERROR,
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_missing_addition(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        (self.fixture.work / "docs/new.txt").unlink()

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.HASH_ERROR,
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_missing_backup(self) -> None:
        self.install_files(
            [("docs/replace.txt", "replacement\n", "replace")]
        )
        backup = self.repository.paths.backup_directory.joinpath(
            "docs",
            "replace.txt",
        )
        backup.unlink()

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.INSTALL_STATE_ERROR,
        )
        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "replacement\n",
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_moved_head(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.git(
            "commit",
            "--allow-empty",
            "-m",
            "test: move head",
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.BASELINE_ERROR,
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_branch_mismatch(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        self.fixture.git("switch", "-c", "other")

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.BASELINE_ERROR,
        )
        self.assertTrue(
            (self.fixture.work / "docs/new.txt").exists()
        )
        self.assert_delivery_preserved()

    def test_rollback_rejects_installing_state(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        receipt_path = self.repository.paths.receipt_path
        data = json.loads(
            receipt_path.read_text(encoding="utf-8")
        )
        data["state"] = "installing"
        receipt_path.write_text(
            json.dumps(data, indent=2) + "\n",
            encoding="utf-8",
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.INSTALL_STATE_ERROR,
        )
        self.assertTrue(
            (self.fixture.work / "docs/new.txt").exists()
        )

    def test_rollback_rejects_local_commit_only_state(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        receipt_path = self.repository.paths.receipt_path
        data = json.loads(
            receipt_path.read_text(encoding="utf-8")
        )
        data["state"] = "local_commit_only"
        receipt_path.write_text(
            json.dumps(data, indent=2) + "\n",
            encoding="utf-8",
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.INSTALL_STATE_ERROR,
        )

    def test_cancelled_confirmation_preserves_delivery(self) -> None:
        self.install_files(
            [("docs/replace.txt", "replacement\n", "replace")]
        )

        with self.assertRaises(SubmitError) as context:
            self.rollback(answer="no")

        self.assertEqual(
            context.exception.code,
            ExitCode.CANCELLED,
        )
        self.assertEqual(
            (self.fixture.work / "docs/replace.txt").read_text(),
            "replacement\n",
        )
        self.assert_delivery_preserved()

    def test_partial_failure_preserves_evidence(self) -> None:
        self.install_files(
            [("docs/replace.txt", "replacement\n", "replace")]
        )

        with mock.patch.object(
            velocity_submit_rollback,
            "atomic_copy",
            side_effect=OSError("controlled restore failure"),
        ):
            with self.assertRaises(SubmitError) as context:
                self.rollback()

        self.assertEqual(
            context.exception.code,
            ExitCode.INSTALL_ERROR,
        )
        self.assertTrue(
            self.repository.paths.backup_directory.joinpath(
                "docs",
                "replace.txt",
            ).is_file()
        )
        self.assert_delivery_preserved()

    def test_run_tool_rollback_reports_pass(self) -> None:
        self.install_files(
            [("docs/new.txt", "new\n", "add")]
        )
        lines: list[str] = []

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            mode="rollback",
            input_function=lambda _prompt: "ROLLBACK",
            output_function=lines.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.PASS)
        self.assertIn(
            "VELOCITY DELIVERY ROLLBACK: PASS",
            lines,
        )
        self.assert_clean_without_state()

    def test_run_tool_rollback_without_receipt_fails(self) -> None:
        lines: list[str] = []

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            mode="rollback",
            input_function=lambda _prompt: "ROLLBACK",
            output_function=lines.append,
            package_selector=lambda: None,
        )

        self.assertEqual(
            code,
            ExitCode.INSTALL_STATE_ERROR,
        )


class SubmitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = VelocityFixture()
        self.package_path = self.fixture.build_package(
            [
                ("docs/new.txt", "new\n", "add"),
                ("docs/replace.txt", "replacement\n", "replace"),
            ],
            commit_message="docs(test): guided delivery",
        )

    def tearDown(self) -> None:
        self.fixture.cleanup()

    def install_guided(self) -> list[str]:
        output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            package_selector=lambda: self.package_path,
            input_function=lambda _prompt: "",
            output_function=output.append,
        )
        self.assertEqual(code, ExitCode.PASS)
        return output

    def test_guided_install_then_submit(self) -> None:
        install_output = self.install_guided()
        self.assertIn(
            "VELOCITY DELIVERY INSTALL: PASS",
            install_output,
        )
        answers = iter(["SUBMIT", "n"])
        submit_output: list[str] = []

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: next(answers),
            output_function=submit_output.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.PASS)
        self.assertIn(
            "VELOCITY SUBMIT RESULT: PASS",
            submit_output,
        )
        self.assertEqual(
            self.fixture.git(
                "log",
                "-1",
                "--format=%s",
            ).stdout.strip(),
            "docs(test): guided delivery",
        )
        self.assertEqual(
            self.fixture.git("status", "--porcelain").stdout,
            "",
        )
        self.assertEqual(
            self.fixture.git("rev-parse", "HEAD").stdout,
            self.fixture.git(
                "rev-parse",
                "origin/main",
            ).stdout,
        )
        repository = RepositoryController.discover(
            self.fixture.work
        )
        self.assertFalse(repository.paths.state_directory.exists())
        self.assertTrue(self.package_path.exists())

    def test_submit_cancellation_preserves_install(self) -> None:
        self.install_guided()
        output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: "NO",
            output_function=output.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.CANCELLED)
        self.assertEqual(self.fixture.head(), self.fixture.base_commit)
        self.assertEqual(
            self.fixture.git(
                "diff",
                "--cached",
                "--name-only",
            ).stdout,
            "",
        )
        repository = RepositoryController.discover(
            self.fixture.work
        )
        self.assertTrue(repository.paths.receipt_path.is_file())

    def test_unexpected_change_blocks_submit(self) -> None:
        self.install_guided()
        self.fixture.write("--help", "")
        output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: "SUBMIT",
            output_function=output.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.WORKTREE_ERROR)
        self.assertTrue(
            any("--help" in line for line in output)
        )

    def test_new_gd_requires_uid_before_submit(self) -> None:
        package_path = self.fixture.build_package(
            [
                (
                    "core/new_script.gd",
                    "extends RefCounted\n",
                    "add",
                )
            ],
            delivery_id="velocity-gd-delivery",
        )
        velocity_submit.run_tool(
            start_directory=self.fixture.work,
            package_selector=lambda: package_path,
            output_function=lambda _line: None,
        )
        output: list[str] = []

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: "SUBMIT",
            output_function=output.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.UID_ERROR)

    def test_new_gd_uid_is_staged_and_submitted(self) -> None:
        package_path = self.fixture.build_package(
            [
                (
                    "core/new_script.gd",
                    "extends RefCounted\n",
                    "add",
                )
            ],
            delivery_id="velocity-gd-delivery",
            commit_message="feat(test): add gd with uid",
        )
        velocity_submit.run_tool(
            start_directory=self.fixture.work,
            package_selector=lambda: package_path,
            output_function=lambda _line: None,
        )
        self.fixture.write(
            "core/new_script.gd.uid",
            "uid://newscript123\n",
        )
        answers = iter(["SUBMIT", "n"])

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: next(answers),
            output_function=lambda _line: None,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.PASS)
        tracked = self.fixture.git(
            "ls-files",
            "core/new_script.gd.uid",
        ).stdout.strip()
        self.assertEqual(tracked, "core/new_script.gd.uid")

    def test_moved_zip_is_reselected_by_digest(self) -> None:
        self.install_guided()
        moved = self.fixture.packages / "moved-package.zip"
        self.package_path.rename(moved)
        answers = iter(["SUBMIT", "n"])

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: next(answers),
            output_function=lambda _line: None,
            package_selector=lambda: moved,
        )

        self.assertEqual(code, ExitCode.PASS)

    def test_different_zip_is_rejected_for_active_receipt(self) -> None:
        self.install_guided()
        self.package_path.unlink()
        different = self.fixture.build_package(
            [("docs/other.txt", "other\n", "add")],
            delivery_id="velocity-other-delivery",
        )

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: "SUBMIT",
            output_function=lambda _line: None,
            package_selector=lambda: different,
        )

        self.assertEqual(code, ExitCode.INSTALL_STATE_ERROR)

    def test_push_failure_preserves_commit_and_retry(self) -> None:
        self.install_guided()
        hidden_remote = self.fixture.root / "hidden-remote.git"
        answers = iter(["SUBMIT"])

        def break_remote(_prompt: str) -> str:
            self.fixture.remote.rename(hidden_remote)
            return next(answers)

        first_output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=break_remote,
            output_function=first_output.append,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.PUSH_ERROR)
        repository = RepositoryController.discover(
            self.fixture.work
        )
        receipt = repository.load_receipt()
        self.assertIsNotNone(receipt)
        self.assertEqual(receipt.state, "local_commit_only")
        self.fixture.remote.parent.mkdir(parents=True, exist_ok=True)
        hidden_remote.rename(self.fixture.remote)
        retry_answers = iter(["PUSH", "n"])

        retry_code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: next(retry_answers),
            output_function=lambda _line: None,
            package_selector=lambda: None,
        )

        self.assertEqual(retry_code, ExitCode.PASS)
        self.assertFalse(repository.paths.state_directory.exists())

    def test_success_can_delete_original_zip(self) -> None:
        self.install_guided()
        answers = iter(["SUBMIT", "y"])

        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            input_function=lambda _prompt: next(answers),
            output_function=lambda _line: None,
            package_selector=lambda: None,
        )

        self.assertEqual(code, ExitCode.PASS)
        self.assertFalse(self.package_path.exists())


class GuidedAndCleanupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = VelocityFixture()

    def tearDown(self) -> None:
        self.fixture.cleanup()

    def test_picker_cancellation_changes_nothing(self) -> None:
        output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            package_selector=lambda: None,
            output_function=output.append,
        )

        self.assertEqual(code, ExitCode.CANCELLED)
        self.assertEqual(
            self.fixture.git("status", "--porcelain").stdout,
            "",
        )

    def test_validate_package_mode_changes_nothing(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        output: list[str] = []
        code = velocity_submit.run_tool(
            start_directory=self.fixture.work,
            package_path=package_path,
            mode="validate-package",
            output_function=output.append,
        )

        self.assertEqual(code, ExitCode.PASS)
        self.assertIn(
            "VELOCITY PACKAGE VALIDATION: PASS",
            output,
        )
        self.assertEqual(
            self.fixture.git("status", "--porcelain").stdout,
            "",
        )

    def test_delete_original_rejects_changed_zip(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        original_hash = sha256_file(package_path)
        package_path.write_bytes(package_path.read_bytes() + b"changed")
        output: list[str] = []

        delete_original_package(
            package_path,
            original_hash,
            self.fixture.work,
            input_function=lambda _prompt: "y",
            output_function=output.append,
        )

        self.assertTrue(package_path.exists())
        self.assertTrue(
            any("WARNING" in line for line in output)
        )

    def test_delete_original_default_keeps_zip(self) -> None:
        package_path = self.fixture.build_package(
            [("docs/new.txt", "new\n", "add")]
        )
        output: list[str] = []

        delete_original_package(
            package_path,
            sha256_file(package_path),
            self.fixture.work,
            input_function=lambda _prompt: "",
            output_function=output.append,
        )

        self.assertTrue(package_path.exists())
        self.assertIn(
            "Package cleanup: kept original ZIP",
            output,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
