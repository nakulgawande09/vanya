#!/usr/bin/env python3
"""Enforces the client dependency rules (docs/standards.md §A.2).

- core/, pcg/ and dda/ must not reference themes/, ui/, services/, gameplay/ or addons/, or the service and theme autoloads.
- Gameplay code must not hard-code theme paths (use ThemeRegistry.visual_for).
- Theme folders must not contain scripts or native code (App Store 2.5.2).
- No Godot 3 APIs (yield, KinematicBody2D, `export var`, ...).
- No more than 6 autoloads.
- Theme audio: every file has a CC0 / Sonniss-GDC / original licence row; music stems carry beat metadata.
"""
from __future__ import annotations

import csv
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
ALLOWED_AUDIO_LICENCES = {"CC0-1.0", "Sonniss-GDC", "original"}
SKIP_DIRS = {"addons", ".godot", "android", "reports"}


def gd_files() -> list[Path]:
    return [
        p for p in CLIENT.rglob("*.gd")
        if not (set(p.relative_to(CLIENT).parts) & SKIP_DIRS)
    ]


def audio_errors() -> list[str]:
    """Audio Bible A4/A5: every shipped sound has a licence row (CC0, Sonniss GDC or original work);
    music stems carry the beat metadata AudioStreamInteractive needs."""
    errors: list[str] = []
    for audio_dir in (CLIENT / "themes").glob("*/audio"):
        files = [p for p in audio_dir.rglob("*") if p.suffix in (".wav", ".ogg")]
        if not files:
            continue
        lic = audio_dir / "LICENSES.csv"
        rows: dict[str, dict[str, str]] = {}
        if lic.exists():
            with lic.open(encoding="utf-8", newline="") as f:
                rows = {r["file"]: r for r in csv.DictReader(f)}
        for p in files:
            rel = p.relative_to(audio_dir).as_posix()
            row = rows.get(rel)
            where = p.relative_to(CLIENT).as_posix()
            if row is None:
                errors.append(f"{where}: no row in {lic.relative_to(CLIENT).as_posix()}")
            elif row.get("licence") not in ALLOWED_AUDIO_LICENCES:
                errors.append(f"{where}: licence '{row.get('licence')}' is not allowed (CC0, Sonniss GDC or original only)")
            if p.suffix == ".ogg" and p.parent.name == "music" and re.search(r"_(bed|perc|melody|tension|frenzy|drive)\.ogg$", p.name):
                imp = p.with_name(p.name + ".import")
                text = imp.read_text(encoding="utf-8") if imp.exists() else ""
                if "loop=true" not in text or re.search(r"^bpm=0$", text, re.M) or "beat_count=0" in text:
                    errors.append(f"{where}: music stems must import looping with BPM and beat count set")
    return errors


def main() -> int:
    errors: list[str] = []

    for path in gd_files():
        rel = path.relative_to(CLIENT).as_posix()
        text = path.read_text(encoding="utf-8")
        if rel.startswith(("core/", "pcg/", "dda/")):
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

    # Art imports: SVGs rasterize Lossless with no mipmaps (standards §B.4); theme strings stay
    # uncompressed so ThemeRegistry can merge them.
    for imp in (CLIENT / "themes").rglob("*.svg.import"):
        text = imp.read_text(encoding="utf-8")
        if "compress/mode=0" not in text or "mipmaps/generate=false" not in text:
            errors.append(f"{imp.relative_to(CLIENT).as_posix()}: SVG must import Lossless with mipmaps off")
    for imp in (CLIENT / "themes").rglob("*.csv.import"):
        if imp.name == "LICENSES.csv.import":
            if 'importer="keep"' not in imp.read_text(encoding="utf-8"):
                errors.append(f"{imp.relative_to(CLIENT).as_posix()}: LICENSES.csv must import as 'keep' (not a translation)")
        elif "compress=0" not in imp.read_text(encoding="utf-8"):
            errors.append(f"{imp.relative_to(CLIENT).as_posix()}: theme strings must import with compress=0")
    errors += audio_errors()

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
