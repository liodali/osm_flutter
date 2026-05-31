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


def update_osm_dependencies(version_interface, version_web, version_type="upperbound"):
    """
    Update root pubspec: comment out current dependency lines for
    flutter_osm_interface and flutter_osm_web, then add new version
    constraint lines right before dev_dependencies.
    """
    deps = {
        "flutter_osm_interface": version_interface,
        "flutter_osm_web": version_web,
    }

    with open(FILE_PUBSPEC_ROOT, "r") as f:
        lines = f.readlines()

    # 1) Comment out existing dependency lines
    updated = []
    for line in lines:
        for dep_name in deps:
            if re.match(rf"^\s+{re.escape(dep_name)}\s*:", line):
                # Preserve indentation, just add '# ' before the content
                stripped = line.lstrip()
                indent = line[:len(line) - len(stripped)]
                line = f"{indent}# {stripped}"
                break
        updated.append(line)

    # 2) Find dev_dependencies index and insert new lines before it
    dev_index = None
    for i, line in enumerate(updated):
        if re.match(r"^dev_dependencies\s*:", line):
            dev_index = i
            break

    if dev_index is None:
        raise RuntimeError("Could not find 'dev_dependencies:' in root pubspec.yaml")

    new_lines = []
    for dep_name, version in deps.items():
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
    update_osm_dependencies(version_interface, version_web, version_type)
    print(f"Updated {FILE_PUBSPEC_ROOT}")


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
