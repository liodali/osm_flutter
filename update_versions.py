#!/usr/bin/env python3
"""Update internal pubspec dependencies to hosted release constraints."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from release_packages import (
    PACKAGE_REGISTRY,
    REPOSITORY_ROOT,
    UPDATE_MODE_ORDER,
    assert_root_excludes_jni,
    build_constraint,
    get_dependency_state,
    get_next_minor,
    read_pubspec_version,
    set_dependency_constraint,
)


MODES = ("interface", "web", "android", "jni", "osm", "all")


def get_version(package_path: Path | str) -> str:
    return read_pubspec_version(package_path)


def get_dep_state(pubspec_path: Path | str, dep_name: str) -> tuple[str, str | None]:
    try:
        state = get_dependency_state(pubspec_path, dep_name)
    except KeyError:
        return "missing", None
    if state.kind == "path":
        return "path", None
    constraint = state.constraint or ""
    current_version = constraint.strip("\"'")
    if current_version.startswith("^"):
        current_version = current_version[1:]
    elif current_version.startswith(">="):
        current_version = current_version[2:].split("<", maxsplit=1)[0].strip()
    return "version", current_version


def update_dependency_in_place(
    pubspec_path: Path | str,
    dep_name: str,
    version: str,
    version_type: str = "upperbound",
) -> bool:
    return set_dependency_constraint(
        pubspec_path,
        dep_name,
        build_constraint(version, version_type),
    )


def update_package(
    package_key: str,
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    if package_key not in PACKAGE_REGISTRY:
        raise ValueError(f"Unknown package key: {package_key}")
    package = PACKAGE_REGISTRY[package_key]
    pubspec_path = package.pubspec_path(repository_root)
    changed = False

    if package_key == "osm":
        assert_root_excludes_jni(repository_root)

    for dependency_key in package.dependencies:
        dependency = PACKAGE_REGISTRY[dependency_key]
        dependency_version = read_pubspec_version(
            dependency.pubspec_path(repository_root)
        )
        constraint = build_constraint(dependency_version, version_type)
        dependency_changed = set_dependency_constraint(
            pubspec_path,
            dependency.name,
            constraint,
        )
        status = "updated" if dependency_changed else "up-to-date"
        print(f"  {package.name} -> {dependency.name}: {constraint} ({status})")
        changed = dependency_changed or changed

    if package_key == "osm":
        assert_root_excludes_jni(repository_root)
    return [pubspec_path] if changed else []


def update_web(
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    return update_package("web", version_type, repository_root)


def update_android(
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    return update_package("android", version_type, repository_root)


def update_jni(
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    return update_package("jni", version_type, repository_root)


def update_osm(
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    return update_package("osm", version_type, repository_root)


def update_mode(
    mode: str,
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> list[Path]:
    if mode not in MODES:
        raise ValueError(f"Unsupported mode: {mode}")
    if mode == "interface":
        print("flutter_osm_interface has no internal dependencies to update.")
        return []

    package_keys = UPDATE_MODE_ORDER if mode == "all" else (mode,)
    changed = []
    for package_key in package_keys:
        print(f"Updating {PACKAGE_REGISTRY[package_key].name} dependencies...")
        changed.extend(update_package(package_key, version_type, repository_root))
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update internal pubspec dependencies without publishing"
    )
    parser.add_argument(
        "--mode",
        choices=MODES,
        default="all",
        help="Package dependency set to update (default: all)",
    )
    parser.add_argument(
        "--version-type",
        choices=("caret", "upperbound"),
        default="caret",
        dest="version_type",
        help="Constraint style: '^version' or '>=version <nextMinor'",
    )
    args = parser.parse_args()

    print(
        f"Running update_versions in '{args.mode}' mode "
        f"with version-type='{args.version_type}'...\n"
    )
    try:
        changed = update_mode(args.mode, args.version_type)
    except (KeyError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    if changed:
        print("\nUpdated:")
        for path in dict.fromkeys(changed):
            print(f"  {path.relative_to(REPOSITORY_ROOT)}")
    else:
        print("\nNo dependency changes needed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
