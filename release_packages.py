#!/usr/bin/env python3
"""Shared package graph and pubspec helpers for repository release scripts."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Iterable


REPOSITORY_ROOT = Path(__file__).resolve().parent
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


@dataclass(frozen=True)
class PackageSpec:
    key: str
    name: str
    directory: str
    dependencies: tuple[str, ...]
    required_before_root: bool

    def pubspec_path(self, repository_root: Path = REPOSITORY_ROOT) -> Path:
        return repository_root / self.directory / "pubspec.yaml"

    @property
    def tag_prefix(self) -> str:
        return "v" if self.key == "osm" else f"{self.name}-v"


PACKAGE_REGISTRY = {
    "interface": PackageSpec(
        key="interface",
        name="flutter_osm_interface",
        directory="flutter_osm_interface",
        dependencies=(),
        required_before_root=True,
    ),
    "web": PackageSpec(
        key="web",
        name="flutter_osm_web",
        directory="flutter_osm_web",
        dependencies=("interface",),
        required_before_root=True,
    ),
    "android": PackageSpec(
        key="android",
        name="flutter_osm_android",
        directory="flutter_osm_android",
        dependencies=("interface",),
        required_before_root=True,
    ),
    "jni": PackageSpec(
        key="jni",
        name="flutter_osm_android_jni",
        directory="flutter_osm_android_jni",
        dependencies=("interface", "android"),
        required_before_root=True,
    ),
    "osm": PackageSpec(
        key="osm",
        name="flutter_osm_plugin",
        directory=".",
        dependencies=("interface", "android", "web"),
        required_before_root=False,
    ),
}
INNER_PACKAGE_KEYS = ("interface", "web", "android", "jni")
UPDATE_MODE_ORDER = ("web", "android", "jni", "osm")


@dataclass(frozen=True)
class DependencyState:
    kind: str
    constraint: str | None = None


def validate_version(version: str) -> str:
    if not SEMVER_PATTERN.fullmatch(version):
        raise ValueError(f"Expected semantic version x.y.z, got: {version}")
    return version


def read_pubspec_version(pubspec_path: Path | str) -> str:
    path = Path(pubspec_path)
    matches = []
    pattern = re.compile(r'^version:\s*["\']?([^\s#"\']+)["\']?\s*(?:#.*)?$')
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = pattern.fullmatch(line)
        if match:
            matches.append((line_number, match.group(1)))
    if len(matches) != 1:
        raise ValueError(
            f"Expected exactly one top-level version in {path}, found {len(matches)}"
        )
    return validate_version(matches[0][1])


def get_next_minor(version: str) -> str:
    validate_version(version)
    stable = re.split(r"[-+]", version, maxsplit=1)[0]
    major, minor, _ = (int(part) for part in stable.split("."))
    return f"{major}.{minor + 1}.0"


def build_constraint(version: str, version_type: str) -> str:
    validate_version(version)
    if version_type == "caret":
        return f"^{version}"
    if version_type == "upperbound":
        return f'">={version} <{get_next_minor(version)}"'
    raise ValueError(f"Unsupported version type: {version_type}")


def topological_keys(keys: Iterable[str]) -> list[str]:
    requested = list(dict.fromkeys(keys))
    unknown = set(requested) - PACKAGE_REGISTRY.keys()
    if unknown:
        raise ValueError(f"Unknown package keys: {', '.join(sorted(unknown))}")

    requested_set = set(requested)
    result = []
    visiting = set()
    visited = set()

    def visit(key: str) -> None:
        if key in visited:
            return
        if key in visiting:
            raise ValueError(f"Dependency cycle detected at {key}")
        visiting.add(key)
        for dependency in PACKAGE_REGISTRY[key].dependencies:
            if dependency in requested_set:
                visit(dependency)
        visiting.remove(key)
        visited.add(key)
        result.append(key)

    for key in requested:
        visit(key)
    return result


def package_key_from_tag(tag: str) -> tuple[str, str]:
    for key, package in PACKAGE_REGISTRY.items():
        if tag.startswith(package.tag_prefix):
            version = tag[len(package.tag_prefix) :]
            return key, validate_version(version)
    raise ValueError(f"Unsupported release tag: {tag}")


def validate_tag_version(
    tag: str,
    repository_root: Path = REPOSITORY_ROOT,
) -> str:
    key, tag_version = package_key_from_tag(tag)
    pubspec_version = read_pubspec_version(
        PACKAGE_REGISTRY[key].pubspec_path(repository_root)
    )
    if tag_version != pubspec_version:
        raise ValueError(
            f"Tag {tag} does not match {PACKAGE_REGISTRY[key].name} "
            f"pubspec version {pubspec_version}"
        )
    return key


def _dependencies_bounds(lines: list[str], path: Path) -> tuple[int, int]:
    dependencies_header = re.compile(r"^dependencies\s*:\s*(?:#.*)?$")
    start = next(
        (
            index + 1
            for index, line in enumerate(lines)
            if dependencies_header.fullmatch(line.rstrip())
        ),
        None,
    )
    if start is None:
        raise ValueError(f"Missing dependencies section in {path}")
    top_level_key = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*\s*:")
    end = next(
        (index for index in range(start, len(lines)) if top_level_key.match(lines[index])),
        len(lines),
    )
    return start, end


def _dependency_bounds(
    lines: list[str],
    path: Path,
    dependency_name: str,
) -> tuple[int, int, str]:
    section_start, section_end = _dependencies_bounds(lines, path)
    pattern = re.compile(
        rf"^(?P<indent> +){re.escape(dependency_name)}\s*:(?P<value>.*)$"
    )
    matches = []
    for index in range(section_start, section_end):
        match = pattern.match(lines[index])
        if match:
            matches.append((index, match))
    if len(matches) != 1:
        raise KeyError(
            f"Expected dependency {dependency_name} exactly once in {path}, "
            f"found {len(matches)}"
        )

    entry_start, match = matches[0]
    indent = len(match.group("indent"))
    entry_end = entry_start + 1
    while entry_end < section_end:
        line = lines[entry_end]
        if not line.strip():
            entry_end += 1
            continue
        current_indent = len(line) - len(line.lstrip(" "))
        if current_indent <= indent:
            break
        entry_end += 1
    return entry_start, entry_end, match.group("value").strip()


def get_dependency_state(
    pubspec_path: Path | str,
    dependency_name: str,
) -> DependencyState:
    path = Path(pubspec_path)
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    start, end, inline_value = _dependency_bounds(lines, path, dependency_name)
    if inline_value:
        return DependencyState("version", inline_value.split(" #", maxsplit=1)[0].strip())

    child_pattern = re.compile(r"^\s+(path|version)\s*:\s*(.*?)\s*(?:#.*)?$")
    child_values = {}
    for line in lines[start + 1 : end]:
        if line.lstrip().startswith("#"):
            continue
        match = child_pattern.match(line.rstrip("\n"))
        if match:
            child_values[match.group(1)] = match.group(2)
    if "path" in child_values:
        return DependencyState("path")
    if child_values.get("version"):
        return DependencyState("version", child_values["version"])
    raise ValueError(f"Unsupported dependency declaration for {dependency_name} in {path}")


def _normalized_constraint(constraint: str) -> str:
    value = constraint.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    return " ".join(value.split())


def validate_package_dependency_constraints(
    package_key: str,
    version_type: str = "caret",
    repository_root: Path = REPOSITORY_ROOT,
) -> None:
    package = PACKAGE_REGISTRY[package_key]
    pubspec_path = package.pubspec_path(repository_root)
    if package_key == "osm":
        assert_root_excludes_jni(repository_root)
    for dependency_key in package.dependencies:
        dependency = PACKAGE_REGISTRY[dependency_key]
        version = read_pubspec_version(dependency.pubspec_path(repository_root))
        expected = build_constraint(version, version_type)
        state = get_dependency_state(pubspec_path, dependency.name)
        if state.kind != "version" or state.constraint is None:
            raise ValueError(
                f"{package.name} dependency {dependency.name} must use hosted "
                f"constraint {expected}; run update_versions.py --mode {package_key}"
            )
        if _normalized_constraint(state.constraint) != _normalized_constraint(expected):
            raise ValueError(
                f"{package.name} dependency {dependency.name} is "
                f"{state.constraint}, expected {expected}; run update_versions.py "
                f"--mode {package_key}"
            )


def set_dependency_constraint(
    pubspec_path: Path | str,
    dependency_name: str,
    constraint: str,
) -> bool:
    path = Path(pubspec_path)
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    start, end, _ = _dependency_bounds(lines, path, dependency_name)
    state = get_dependency_state(path, dependency_name)
    if state.kind == "version" and state.constraint is not None:
        if _normalized_constraint(state.constraint) == _normalized_constraint(constraint):
            return False

    indent = lines[start][: len(lines[start]) - len(lines[start].lstrip(" "))]
    lines[start:end] = [f"{indent}{dependency_name}: {constraint}\n"]
    path.write_text("".join(lines), encoding="utf-8")
    return True


def assert_root_excludes_jni(repository_root: Path = REPOSITORY_ROOT) -> None:
    root_pubspec = PACKAGE_REGISTRY["osm"].pubspec_path(repository_root)
    try:
        get_dependency_state(root_pubspec, PACKAGE_REGISTRY["jni"].name)
    except KeyError:
        return
    except ValueError as error:
        raise ValueError(
            f"{PACKAGE_REGISTRY['jni'].name} must not be a root dependency "
            f"in {root_pubspec}"
        ) from error
    raise ValueError(
        f"{PACKAGE_REGISTRY['jni'].name} must not be a root dependency in {root_pubspec}"
    )
