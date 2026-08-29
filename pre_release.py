#!/usr/bin/env python3
"""Create package release tags in dependency order and wait for pub.dev."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

from check_pubspec_release import (
    DEFAULT_VISIBILITY_TIMEOUT,
    PubDevError,
    package_version_exists,
    wait_for_version,
)
from release_packages import (
    INNER_PACKAGE_KEYS,
    PACKAGE_REGISTRY,
    REPOSITORY_ROOT,
    read_pubspec_version,
    topological_keys,
    validate_package_dependency_constraints,
)


MODE_PACKAGES = {
    "onlyinterface": ("interface",),
    "onlyweb": ("web",),
    "onlyandroid": ("android",),
    "onlyjni": ("jni",),
    "all": INNER_PACKAGE_KEYS,
}


def push_release_tag(
    package_key: str,
    version: str,
    repository_root: Path = REPOSITORY_ROOT,
) -> str:
    tag = f"{PACKAGE_REGISTRY[package_key].tag_prefix}{version}"
    subprocess.run(["git", "tag", tag, "HEAD"], cwd=repository_root, check=True)
    subprocess.run(["git", "push", "origin", tag], cwd=repository_root, check=True)
    return tag


def ensure_dependencies_visible(
    package_key: str,
    repository_root: Path = REPOSITORY_ROOT,
) -> None:
    package = PACKAGE_REGISTRY[package_key]
    for dependency_key in package.dependencies:
        dependency = PACKAGE_REGISTRY[dependency_key]
        version = read_pubspec_version(dependency.pubspec_path(repository_root))
        if not package_version_exists(dependency.name, version):
            raise RuntimeError(
                f"Cannot release {package.name}: dependency {dependency.name} "
                f"{version} is not visible on pub.dev"
            )


def process_package(
    package_key: str,
    visibility_timeout: int,
    repository_root: Path = REPOSITORY_ROOT,
) -> None:
    package = PACKAGE_REGISTRY[package_key]
    version = read_pubspec_version(package.pubspec_path(repository_root))
    if package_version_exists(package.name, version):
        print(f"{package.name} {version} already exists on pub.dev")
        return

    validate_package_dependency_constraints(package_key, "caret", repository_root)
    ensure_dependencies_visible(package_key, repository_root)
    tag = push_release_tag(package_key, version, repository_root)
    print(f"Pushed {tag}; waiting for pub.dev publication...")
    wait_for_version(package.name, version, visibility_timeout)


def run(
    mode: str,
    visibility_timeout: int = DEFAULT_VISIBILITY_TIMEOUT,
    repository_root: Path = REPOSITORY_ROOT,
) -> None:
    package_keys = MODE_PACKAGES[mode]
    for package_key in topological_keys(package_keys):
        process_package(package_key, visibility_timeout, repository_root)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Tag inner packages in dependency order and wait for publication"
    )
    parser.add_argument(
        "--mode",
        choices=tuple(MODE_PACKAGES),
        default="all",
        help="Package set to release (default: all)",
    )
    parser.add_argument(
        "--visibility-timeout",
        type=int,
        default=DEFAULT_VISIBILITY_TIMEOUT,
        help="Seconds to wait for each package to appear on pub.dev",
    )
    args = parser.parse_args()

    try:
        run(args.mode, args.visibility_timeout)
    except (KeyError, OSError, PubDevError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Pre-release package sequence completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
