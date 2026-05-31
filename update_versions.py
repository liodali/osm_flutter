#!/usr/bin/env python3
"""
Update pubspec dependency versions without publishing.

Reads versions from flutter_osm_interface and flutter_osm_web,
updates dependency constraints in pubspec.yaml files.

Modes:
    web       - update flutter_osm_web's dependency on flutter_osm_interface
    interface - no-op (no internal dependencies)
    osm       - update root pubspec dependencies on both packages
    all       - web + osm (default)

Version types:
    caret      - ^version (default)
    upperbound - >=version <nextMinor

Usage:
    python3 update_versions.py --mode all
    python3 update_versions.py --mode web --version-type caret
    python3 update_versions.py --mode osm --version-type upperbound
"""

import argparse
import re

LINE_VERSION = 2  # 0-indexed line where "version: x.y.z" is located

FILE_PUBSPEC_INTERFACE = "flutter_osm_interface/pubspec.yaml"
FILE_PUBSPEC_WEB = "flutter_osm_web/pubspec.yaml"
FILE_PUBSPEC_ROOT = "pubspec.yaml"


def get_version(package_path):
    with open(package_path, "r") as f:
        lines = f.readlines()
        version_line = lines[LINE_VERSION]
        version = version_line.split(":")[-1].strip().replace("\n", "")
        return version


def get_next_minor(version):
    """Compute next minor version: 1.4.4 -> 1.5.0"""
    package_v = version
    if "+" in package_v:
        package_v = package_v.split("+")[0]
    if "-" in package_v:
        package_v = package_v.split("-")[0]
    parts = package_v.split(".")
    if len(parts) != 3:
        raise ValueError(f"Expected semver x.y.z, got: {version}")
    x, y, z = [int(i) for i in parts]
    y += 1
    z = 0
    return f"{x}.{y}.{z}"


def build_constraint(version, version_type):
    if version_type == "caret":
        return f"^{version}"
    else:  # upperbound
        max_version = get_next_minor(version)
        return f'">={version} <{max_version}"'


def get_dep_state(pubspec_path, dep_name):
    """Returns (kind, version) where kind is 'path', 'version', or 'missing'."""
    with open(pubspec_path, "r") as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        if re.match(rf"^\s+{re.escape(dep_name)}\s*:", line):
            stripped = line.lstrip()
            if stripped.startswith("#"):
                continue

            parts = line.split(":")[-1].strip()
            # Empty after colon, check next line for path
            if not parts:
                if i + 1 < len(lines):
                    next_stripped = lines[i + 1].lstrip()
                    if next_stripped.startswith("path:"):
                        return ("path", None)
                return ("missing", None)

            # Has content on same line - it's a version constraint
            if not parts.startswith("path"):
                ver = parts.replace("^", "").replace('"', "").replace(">=", "")
                ver = ver.split("<")[0].strip()
                return ("version", ver)

            return ("missing", None)

    return ("missing", None)


def update_dependency_in_place(pubspec_path, dep_name, version, version_type="upperbound"):
    """
    Replace the dependency line with the chosen constraint.
    Removes a single uncommented 'path:' line that directly follows the dependency.
    """
    constraint = build_constraint(version, version_type)
    new_line = f"  {dep_name}: {constraint}\n"

    with open(pubspec_path, "r") as f:
        lines = f.readlines()

    updated_lines = []
    skip_next = False

    for line in lines:
        if skip_next:
            skip_next = False
            stripped = line.lstrip()
            if stripped.startswith("path:"):
                continue
            else:
                updated_lines.append(line)
            continue

        if re.match(rf"^\s+{re.escape(dep_name)}\s*:", line):
            updated_lines.append(new_line)
            skip_next = True
        else:
            updated_lines.append(line)

    with open(pubspec_path, "w") as f:
        f.writelines(updated_lines)


def update_osm_dependencies(deps_to_update, version_type="caret"):
    """
    Update root pubspec: for deps in deps_to_update, comment out current lines
    (including a following path line if present) and add new version constraint
    lines right before dev_dependencies.
    """
    if not deps_to_update:
        print("Nothing to update in root pubspec")
        return

    with open(FILE_PUBSPEC_ROOT, "r") as f:
        lines = f.readlines()

    # 1) Comment out existing dependency lines for deps we're updating
    updated = []
    i = 0
    while i < len(lines):
        line = lines[i]
        matched_dep = None
        for dep_name in deps_to_update:
            if re.match(rf"^\s+{re.escape(dep_name)}\s*:", line):
                stripped = line.lstrip()
                if not stripped.startswith("#"):
                    matched_dep = dep_name
                    break

        if matched_dep:
            stripped = line.lstrip()
            indent = line[:len(line) - len(stripped)]
            updated.append(f"{indent}# {stripped}")
            i += 1
            # Comment out following path line if present
            if i < len(lines):
                next_line = lines[i]
                next_stripped = next_line.lstrip()
                if next_stripped.startswith("path:"):
                    indent_next = next_line[:len(next_line) - len(next_stripped)]
                    updated.append(f"{indent_next}# {next_stripped}")
                    i += 1
        else:
            updated.append(line)
            i += 1

    # 2) Find dev_dependencies index and insert new lines before it
    dev_index = None
    for i, line in enumerate(updated):
        if re.match(r"^dev_dependencies\s*:", line):
            dev_index = i
            break

    if dev_index is None:
        raise RuntimeError("Could not find 'dev_dependencies:' in root pubspec.yaml")

    new_lines = []
    for dep_name, version in deps_to_update.items():
        constraint = build_constraint(version, version_type)
        new_lines.append(f"  {dep_name}: {constraint}\n")

    final = updated[:dev_index] + new_lines + updated[dev_index:]

    with open(FILE_PUBSPEC_ROOT, "w") as f:
        f.writelines(final)


def update_web(version_type):
    version_interface = get_version(FILE_PUBSPEC_INTERFACE)
    print(f"flutter_osm_interface version: {version_interface}")
    update_dependency_in_place(FILE_PUBSPEC_WEB, "flutter_osm_interface", version_interface, version_type)
    print(f"Updated {FILE_PUBSPEC_WEB}")


def update_osm(version_type):
    version_interface = get_version(FILE_PUBSPEC_INTERFACE)
    version_web = get_version(FILE_PUBSPEC_WEB)
    print(f"flutter_osm_interface version: {version_interface}")
    print(f"flutter_osm_web version: {version_web}")

    deps_to_update = {}
    for dep_name, target_version in [
        ("flutter_osm_interface", version_interface),
        ("flutter_osm_web", version_web),
    ]:
        kind, current_ver = get_dep_state(FILE_PUBSPEC_ROOT, dep_name)

        if kind == "path":
            print(f"  {dep_name}: path -> {target_version}")
            deps_to_update[dep_name] = target_version
        elif kind == "version":
            if current_ver == target_version:
                print(f"  {dep_name}: up-to-date ({current_ver})")
            else:
                print(f"  {dep_name}: {current_ver} -> {target_version}")
                deps_to_update[dep_name] = target_version
        else:
            print(f"  {dep_name}: not found or commented, skipping")

    if deps_to_update:
        update_osm_dependencies(deps_to_update, version_type)
        print(f"Updated {FILE_PUBSPEC_ROOT}")
    else:
        print("No changes needed for root pubspec")


def main():
    parser = argparse.ArgumentParser(
        description="Update pubspec dependency versions without publishing"
    )
    parser.add_argument(
        "--mode",
        choices=["web", "interface", "osm", "all"],
        default="all",
        help="Which packages to update (default: all)"
    )
    parser.add_argument(
        "--version-type",
        choices=["caret", "upperbound"],
        default="caret",
        dest="version_type",
        help="Constraint style: '^version' or '>=version <nextMinor' (default: caret)"
    )
    args = parser.parse_args()

    print(f"Running update_versions in '{args.mode}' mode with version-type='{args.version_type}'...\n")

    if args.mode == "web":
        update_web(args.version_type)
    elif args.mode == "interface":
        print("flutter_osm_interface has no internal dependencies to update.")
    elif args.mode == "osm":
        update_osm(args.version_type)
    elif args.mode == "all":
        update_web(args.version_type)
        print()
        update_osm(args.version_type)

    print("\nDone (no publish performed).")


if __name__ == "__main__":
    main()
