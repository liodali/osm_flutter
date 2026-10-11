import unittest
from urllib.error import HTTPError, URLError

from check_pubspec_release import (
    PubDevError,
    package_version_exists,
    selected_package_keys,
)


class Response:
    status = 200


class CheckPubspecReleaseTest(unittest.TestCase):
    def test_request_uses_timeout(self):
        calls = []

        def opener(request, timeout):
            calls.append((request.full_url, timeout))
            return Response()

        self.assertTrue(package_version_exists("fixture", "1.0.0", 7, opener))
        self.assertEqual(calls, [("https://pub.dev/api/packages/fixture/versions/1.0.0", 7)])

    def test_404_is_missing(self):
        def opener(request, timeout):
            error = HTTPError(request.full_url, 404, "missing", {}, None)
            error.close()
            raise error

        self.assertFalse(package_version_exists("fixture", "1.0.0", opener=opener))

    def test_server_and_network_errors_are_not_missing(self):
        def server_error(request, timeout):
            error = HTTPError(request.full_url, 500, "server error", {}, None)
            error.close()
            raise error

        def network_error(request, timeout):
            raise URLError("offline")

        with self.assertRaises(PubDevError):
            package_version_exists("fixture", "1.0.0", opener=server_error)
        with self.assertRaises(PubDevError):
            package_version_exists("fixture", "1.0.0", opener=network_error)

    def test_root_release_checks_root_dependencies_only(self):
        self.assertEqual(
            selected_package_keys("root-release", False),
            ("interface", "web", "android"),
        )
        self.assertEqual(
            selected_package_keys("inner", False),
            ("interface", "web", "android"),
        )

    def test_optional_jni_is_included_only_when_requested(self):
        self.assertEqual(
            selected_package_keys("root-release", True),
            ("interface", "web", "android", "jni"),
        )
        self.assertEqual(
            selected_package_keys("inner", True),
            ("interface", "web", "android", "jni"),
        )

    def test_unknown_scope_is_rejected(self):
        with self.assertRaises(ValueError):
            selected_package_keys("unknown", False)


if __name__ == "__main__":
    unittest.main()
