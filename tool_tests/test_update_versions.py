import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from release_packages import PACKAGE_REGISTRY, get_dependency_state
import update_versions


class UpdateVersionsTest(unittest.TestCase):
    def setUp(self):
        self.temp_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_directory.name)
        self._write_package("interface", "1.5.0", "")
        self._write_package(
            "web",
            "2.0.1",
            "  flutter_osm_interface:\n"
            "    # ignore: invalid_dependency\n"
            "    path: ../flutter_osm_interface/\n",
        )
        self._write_package(
            "android",
            "0.1.0",
            "  flutter_osm_interface: ^1.4.0\n",
        )
        self._write_package(
            "jni",
            "0.1.0",
            "  flutter_osm_interface: ^1.4.0\n"
            "  flutter_osm_android:\n"
            "    # ignore: invalid_dependency\n"
            "    path: ../flutter_osm_android/\n",
        )
        self._write_package(
            "osm",
            "2.0.1+1",
            "  flutter_osm_interface:\n"
            "    # ignore: invalid_dependency\n"
            "    path: flutter_osm_interface/\n"
            "  flutter_osm_android:\n"
            "    path: flutter_osm_android/\n"
            "  flutter_osm_web: ^1.9.0\n",
        )

    def tearDown(self):
        self.temp_directory.cleanup()

    def _write_package(self, key, version, dependencies):
        pubspec = PACKAGE_REGISTRY[key].pubspec_path(self.root)
        pubspec.parent.mkdir(parents=True, exist_ok=True)
        pubspec.write_text(
            f"name: {PACKAGE_REGISTRY[key].name}\n"
            "description: fixture\n"
            f"version: {version}\n"
            "dependencies:\n"
            f"{dependencies}"
            "dev_dependencies:\n"
            "  test: any\n",
            encoding="utf-8",
        )

    def test_all_updates_every_package_in_dependency_order(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            changed = update_versions.update_mode("all", "caret", self.root)

        self.assertEqual(
            [path.relative_to(self.root).as_posix() for path in changed],
            [
                "flutter_osm_web/pubspec.yaml",
                "flutter_osm_android/pubspec.yaml",
                "flutter_osm_android_jni/pubspec.yaml",
                "pubspec.yaml",
            ],
        )
        text = output.getvalue()
        positions = [
            text.index(f"Updating {PACKAGE_REGISTRY[key].name}")
            for key in ("web", "android", "jni", "osm")
        ]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(
            get_dependency_state(
                PACKAGE_REGISTRY["jni"].pubspec_path(self.root),
                "flutter_osm_android",
            ).constraint,
            "^0.1.0",
        )
        self.assertEqual(
            get_dependency_state(
                PACKAGE_REGISTRY["osm"].pubspec_path(self.root),
                "flutter_osm_web",
            ).constraint,
            "^2.0.1",
        )
        self.assertNotIn(
            "flutter_osm_android_jni:",
            PACKAGE_REGISTRY["osm"].pubspec_path(self.root).read_text(
                encoding="utf-8"
            ),
        )

    def test_root_with_jni_dependency_fails_without_mutating(self):
        root_pubspec = PACKAGE_REGISTRY["osm"].pubspec_path(self.root)
        content = root_pubspec.read_text(encoding="utf-8")
        content = content.replace(
            "dev_dependencies:",
            "  flutter_osm_android_jni: ^0.1.0\ndev_dependencies:",
        )
        root_pubspec.write_text(content, encoding="utf-8")

        with self.assertRaises(ValueError):
            update_versions.update_osm("caret", self.root)
        self.assertEqual(root_pubspec.read_text(encoding="utf-8"), content)

    def test_upper_bound_preserves_prerelease_and_build_metadata(self):
        self._write_package("interface", "1.5.0-beta.1+9", "")
        update_versions.update_web("upperbound", self.root)
        state = get_dependency_state(
            PACKAGE_REGISTRY["web"].pubspec_path(self.root),
            "flutter_osm_interface",
        )
        self.assertEqual(state.constraint, '">=1.5.0-beta.1+9 <1.6.0"')


if __name__ == "__main__":
    unittest.main()
