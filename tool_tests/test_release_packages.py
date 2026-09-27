import tempfile
import unittest
from pathlib import Path

from release_packages import (
    PACKAGE_REGISTRY,
    build_constraint,
    get_dependency_state,
    get_next_minor,
    package_key_from_tag,
    read_pubspec_version,
    set_dependency_constraint,
    topological_keys,
    validate_tag_version,
)


class ReleasePackagesTest(unittest.TestCase):
    def test_registry_has_expected_topological_order(self):
        self.assertEqual(
            topological_keys(PACKAGE_REGISTRY),
            ["interface", "web", "android", "jni", "osm"],
        )

    def test_reads_version_by_key_instead_of_line_number(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text(
                "name: fixture\ndescription: test\npublish_to: none\n"
                "version: 1.4.0-beta.2+7\n",
                encoding="utf-8",
            )
            self.assertEqual(read_pubspec_version(pubspec), "1.4.0-beta.2+7")
            self.assertEqual(get_next_minor("1.4.0-beta.2+7"), "1.5.0")
            self.assertEqual(
                build_constraint("1.4.0-beta.2+7", "upperbound"),
                '">=1.4.0-beta.2+7 <1.5.0"',
            )

    def test_replaces_path_block_with_intervening_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text(
                "name: fixture\nversion: 1.0.0\ndependencies:\n"
                "  flutter_osm_interface:\n"
                "    # ignore: invalid_dependency\n"
                "    # local workspace package\n"
                "    path: ../flutter_osm_interface/\n"
                "  collection: ^1.0.0\n",
                encoding="utf-8",
            )
            self.assertEqual(
                get_dependency_state(pubspec, "flutter_osm_interface").kind,
                "path",
            )
            self.assertTrue(
                set_dependency_constraint(
                    pubspec,
                    "flutter_osm_interface",
                    "^1.5.0",
                )
            )
            content = pubspec.read_text(encoding="utf-8")
            self.assertIn("  flutter_osm_interface: ^1.5.0\n", content)
            self.assertNotIn("local workspace", content)
            self.assertIn("  collection: ^1.0.0\n", content)

    def test_hosted_dependency_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text(
                "name: fixture\nversion: 1.0.0\ndependencies:\n"
                "  flutter_osm_interface: ^1.5.0\n",
                encoding="utf-8",
            )
            self.assertFalse(
                set_dependency_constraint(
                    pubspec,
                    "flutter_osm_interface",
                    "^1.5.0",
                )
            )
            self.assertTrue(
                set_dependency_constraint(
                    pubspec,
                    "flutter_osm_interface",
                    "^1.6.0",
                )
            )

    def test_missing_dependency_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text(
                "name: fixture\nversion: 1.0.0\ndependencies:\n"
                "  collection: ^1.0.0\n",
                encoding="utf-8",
            )
            with self.assertRaises(KeyError):
                set_dependency_constraint(
                    pubspec,
                    "flutter_osm_interface",
                    "^1.5.0",
                )

    def test_package_tags_are_explicit(self):
        self.assertEqual(
            package_key_from_tag("flutter_osm_android-v0.1.0"),
            ("android", "0.1.0"),
        )
        self.assertEqual(package_key_from_tag("v2.0.1+1"), ("osm", "2.0.1+1"))
        with self.assertRaises(ValueError):
            package_key_from_tag("unknown-v1.0.0")

    def test_tag_version_must_match_pubspec(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = PACKAGE_REGISTRY["android"].pubspec_path(root)
            pubspec.parent.mkdir(parents=True)
            pubspec.write_text(
                "name: flutter_osm_android\nversion: 0.1.0\ndependencies:\n",
                encoding="utf-8",
            )
            self.assertEqual(
                validate_tag_version("flutter_osm_android-v0.1.0", root),
                "android",
            )
            with self.assertRaises(ValueError):
                validate_tag_version("flutter_osm_android-v0.2.0", root)


if __name__ == "__main__":
    unittest.main()
