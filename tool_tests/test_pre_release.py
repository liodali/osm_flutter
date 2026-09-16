import tempfile
import unittest
from pathlib import Path
from unittest.mock import call, patch

import pre_release
from release_packages import PACKAGE_REGISTRY


class PreReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_directory.name)
        for key, package in PACKAGE_REGISTRY.items():
            pubspec = package.pubspec_path(self.root)
            pubspec.parent.mkdir(parents=True, exist_ok=True)
            pubspec.write_text(
                f"name: {package.name}\nversion: 1.0.0\ndependencies:\n"
                + "".join(
                    f"  {PACKAGE_REGISTRY[dependency].name}: ^1.0.0\n"
                    for dependency in package.dependencies
                ),
                encoding="utf-8",
            )

    def tearDown(self):
        self.temp_directory.cleanup()

    @patch("pre_release.wait_for_version")
    @patch("pre_release.push_release_tag", return_value="fixture-v1.0.0")
    @patch("pre_release.ensure_dependencies_visible")
    @patch("pre_release.validate_package_dependency_constraints")
    @patch("pre_release.package_version_exists", return_value=False)
    def test_missing_package_validates_before_tagging(
        self,
        version_exists,
        validate_constraints,
        ensure_dependencies,
        push_tag,
        wait_for_version,
    ):
        pre_release.process_package("android", 30, self.root)

        version_exists.assert_called_once_with("flutter_osm_android", "1.0.0")
        validate_constraints.assert_called_once_with("android", "caret", self.root)
        ensure_dependencies.assert_called_once_with("android", self.root)
        push_tag.assert_called_once_with("android", "1.0.0", self.root)
        wait_for_version.assert_called_once_with(
            "flutter_osm_android",
            "1.0.0",
            30,
        )

    @patch("pre_release.push_release_tag")
    @patch("pre_release.package_version_exists", return_value=True)
    def test_existing_package_does_not_create_tag(self, version_exists, push_tag):
        pre_release.process_package("jni", 30, self.root)
        push_tag.assert_not_called()

    @patch("pre_release.subprocess.run")
    def test_pushes_only_the_explicit_tag_with_checked_commands(self, run):
        tag = pre_release.push_release_tag("android", "1.0.0", self.root)
        self.assertEqual(tag, "flutter_osm_android-v1.0.0")
        self.assertEqual(
            run.call_args_list,
            [
                call(
                    ["git", "tag", "flutter_osm_android-v1.0.0", "HEAD"],
                    cwd=self.root,
                    check=True,
                ),
                call(
                    ["git", "push", "origin", "flutter_osm_android-v1.0.0"],
                    cwd=self.root,
                    check=True,
                ),
            ],
        )


if __name__ == "__main__":
    unittest.main()
