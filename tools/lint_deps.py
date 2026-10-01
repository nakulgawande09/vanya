#!/usr/bin/env python3
"""Enforces the client dependency rules (docs/standards.md §A.2).

- core/ must not reference themes/, ui/, services/, gameplay/ or addons/, or the service and theme autoloads.
- Gameplay code must not hard-code theme paths (use ThemeRegistry.visual_for).
- Theme folders must not contain scripts or native code (App Store 2.5.2).
- No Godot 3 APIs (yield, KinematicBody2D, `export var`, ...).
- No more than 6 autoloads.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

CLIENT = Path(__file__).resolve().parent.parent / "client"

FORBIDDEN_IN_CORE = [
    (re.compile(r"res://(themes|ui|services|gameplay|addons)/"), "core/ may not load from themes/, ui/, services/, gameplay/ or addons/"),
    (re.compile(r"\b(ThemeRegistry|Services|SceneRouter)\b"), "core/ may not use the ThemeRegistry, Services or SceneRouter autoloads"),
]
THEME_PATH_IN_CODE = re.compile(r"res://themes/")
GODOT3_APIS = [
    (re.compile(r"\byield\s*\("), "yield() is Godot 3; use await"),
    (re.compile(r"\bKinematicBody2D\b"), "KinematicBody2D is Godot 3; use CharacterBody2D"),
    (re.compile(r"^\s*export\s+(var|\()", re.M), "`export var` is Godot 3; use @export"),
    (re.compile(r"^\s*onready\s+var", re.M), "`onready var` is Godot 3; use @onready"),
    (re.compile(r"\.instance\(\)"), ".instance() is Godot 3; use .instantiate()"),
]
FORBIDDEN_THEME_EXT = {".gd", ".gdc", ".cs", ".gdextension", ".so", ".dylib", ".dll", ".jar", ".aar"}
MAX_AUTOLOADS = 6
SKIP_DIRS = {"addons", ".godot", "android", "reports"}


def gd_files() -> list[Path]:
    return [
        p for p in CLIENT.rglob("*.gd")
        if not (set(p.relative_to(CLIENT).parts) & SKIP_DIRS)
    ]


def main() -> int:
    errors: list[str] = []

    for path in gd_files():
        rel = path.relative_to(CLIENT).as_posix()
        text = path.read_text(encoding="utf-8")
        if rel.startswith("core/"):
            for pattern, message in FORBIDDEN_IN_CORE:
                if pattern.search(text):
                    errors.append(f"{rel}: {message}")
        if rel.startswith("gameplay/") and THEME_PATH_IN_CODE.search(text):
            errors.append(f"{rel}: gameplay must not reference theme paths; use ThemeRegistry.visual_for()")
        for pattern, message in GODOT3_APIS:
            if pattern.search(text):
                errors.append(f"{rel}: {message}")

    for path in (CLIENT / "themes").rglob("*"):
        if path.is_file() and path.suffix in FORBIDDEN_THEME_EXT:
            errors.append(f"{path.relative_to(CLIENT).as_posix()}: theme packs may not contain scripts or native code")

    project = (CLIENT / "project.godot").read_text(encoding="utf-8")
    autoload_section = re.search(r"^\[autoload\]\n(.*?)(?=^\[|\Z)", project, re.M | re.S)
    autoloads = [l for l in (autoload_section.group(1) if autoload_section else "").splitlines() if "=" in l]
    if len(autoloads) > MAX_AUTOLOADS:
        errors.append(f"project.godot: {len(autoloads)} autoloads (max {MAX_AUTOLOADS}; adding one needs an ADR)")

    for e in errors:
        print(f"lint_deps: {e}", file=sys.stderr)
    if errors:
        return 1
    print(f"lint_deps: OK ({len(gd_files())} scripts checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
