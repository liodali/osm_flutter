#!/usr/bin/env python3
"""Validate or publish coordinated package versions for repository releases."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from release_packages import (
    INNER_PACKAGE_KEYS,
    PACKAGE_REGISTRY,
    REPOSITORY_ROOT,
    assert_root_excludes_jni,
    read_pubspec_version,
    topological_keys,
    validate_package_dependency_constraints,
    validate_tag_version,
)
import update_versions


PUB_DEV_API = "https://pub.dev/api/packages"
DEFAULT_REQUEST_TIMEOUT = 10
DEFAULT_VISIBILITY_TIMEOUT = 900


class PubDevError(RuntimeError):
    pass


def package_version_exists(
    package_name: str,
    version: str,
    request_timeout: int = DEFAULT_REQUEST_TIMEOUT,
    opener=urlopen,
) -> bool:
    url = f"{PUB_DEV_API}/{quote(package_name)}/versions/{quote(version)}"
    request = Request(url, headers={"User-Agent": "flutter-osm-release-tools"})
    try:
        response = opener(request, timeout=request_timeout)
        try:
            status = getattr(response, "status", 200)
            if status == 200:
                return True
            raise PubDevError(
                f"pub.dev returned HTTP {status} for {package_name} {version}"
            )
        finally:
            close = getattr(response, "close", None)
            if close is not None:
                close()
    except HTTPError as error:
        error.close()
        if error.code == 404:
            return False
        raise PubDevError(
            f"pub.dev returned HTTP {error.code} for {package_name} {version}"
        ) from error
    except (URLError, TimeoutError) as error:
        raise PubDevError(
            f"Could not query pub.dev for {package_name} {version}: {error}"
        ) from error


def wait_for_version(
    package_name: str,
    version: str,
    visibility_timeout: int = DEFAULT_VISIBILITY_TIMEOUT,
    poll_interval: int = 5,
) -> None:
    deadline = time.monotonic() + visibility_timeout
    while time.monotonic() < deadline:
        if package_version_exists(package_name, version):
            print(f"{package_name} {version} is visible on pub.dev")
            return
        time.sleep(poll_interval)
    raise TimeoutError(
        f"{package_name} {version} was not visible on pub.dev within "
        f"{visibility_timeout} seconds"
    )


def publish_package(package_key: str, repository_root: Path = REPOSITORY_ROOT) -> None:
    package = PACKAGE_REGISTRY[package_key]
    subprocess.run(
        ["flutter", "pub", "publish", "-f"],
        cwd=repository_root / package.directory,
        check=True,
    )


def selected_package_keys(scope: str, include_optional_jni: bool) -> tuple[str, ...]:
    if scope == "root-release":
        return INNER_PACKAGE_KEYS
    keys = ["interface", "web", "android"]
    if include_optional_jni:
        keys.append("jni")
    return tuple(keys)


def validate_versions(
    package_keys: tuple[str, ...],
    publish: bool,
    visibility_timeout: int,
    repository_root: Path = REPOSITORY_ROOT,
) -> list[str]:
    missing = []
    for package_key in topological_keys(package_keys):
        package = PACKAGE_REGISTRY[package_key]
        version = read_pubspec_version(package.pubspec_path(repository_root))
        exists = package_version_exists(package.name, version)
        print(f"{package.name} {version}: {'exists' if exists else 'missing'}")
        if exists:
            continue
        if not publish:
            missing.append(package_key)
            continue

        validate_package_dependency_constraints(
            package_key,
            "caret",
            repository_root,
        )
        for dependency_key in package.dependencies:
            dependency = PACKAGE_REGISTRY[dependency_key]
            dependency_version = read_pubspec_version(
                dependency.pubspec_path(repository_root)
            )
            if not package_version_exists(dependency.name, dependency_version):
                raise RuntimeError(
                    f"Cannot publish {package.name}: dependency {dependency.name} "
                    f"{dependency_version} is not visible on pub.dev"
                )
        publish_package(package_key, repository_root)
        wait_for_version(package.name, version, visibility_timeout)
    return missing


def run(
    scope: str,
    publish: bool = False,
    include_optional_jni: bool = False,
    visibility_timeout: int = DEFAULT_VISIBILITY_TIMEOUT,
    tag: str | None = None,
    repository_root: Path = REPOSITORY_ROOT,
) -> None:
    if publish and scope != "inner":
        raise ValueError("--publish is only valid with --scope inner")

    package_keys = selected_package_keys(scope, include_optional_jni)
    if tag is not None:
        tagged_key = validate_tag_version(tag, repository_root)
        if tagged_key not in package_keys and not (
            scope == "root-release" and tagged_key == "osm"
        ):
            raise ValueError(f"Tag {tag} is outside the selected {scope} scope")

    missing = validate_versions(
        package_keys,
        publish,
        visibility_timeout,
        repository_root,
    )
    if missing:
        package_names = ", ".join(PACKAGE_REGISTRY[key].name for key in missing)
        raise RuntimeError(f"Package versions missing from pub.dev: {package_names}")

    if scope == "root-release":
        assert_root_excludes_jni(repository_root)
        update_versions.update_osm("caret", repository_root)
        assert_root_excludes_jni(repository_root)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check coordinated package versions on pub.dev"
    )
    parser.add_argument(
        "--scope",
        choices=("inner", "root-release"),
        default="root-release",
        help="Validation scope (default: root-release)",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Publish missing packages in dependency order for inner scope",
    )
    parser.add_argument(
        "--include-optional-jni",
        action="store_true",
        help="Include JNI in inner scope; root-release always requires it",
    )
    parser.add_argument(
        "--visibility-timeout",
        type=int,
        default=DEFAULT_VISIBILITY_TIMEOUT,
        help="Seconds to wait for a newly published package",
    )
    parser.add_argument(
        "--tag",
        help="Optional release tag whose version must match its pubspec",
    )
    args = parser.parse_args()

    try:
        run(
            scope=args.scope,
            publish=args.publish,
            include_optional_jni=args.include_optional_jni,
            visibility_timeout=args.visibility_timeout,
            tag=args.tag,
        )
    except (OSError, PubDevError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Release package validation completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
