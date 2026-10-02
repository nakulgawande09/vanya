#!/usr/bin/env python3
"""Audio memory budget (Audio Bible A5), measured on the imported data Godot keeps resident.

Run after `godot --import`. Reads pipelines/audio/index/<theme>.json and the imported file each
source maps to (.godot/imported/*.sample for QOA WAVs, *.oggvorbisstr for OGG). Music counts the
current context only (camp or run), so the larger of the two is checked.

    python3 tools/audio_budget.py            # fail (exit 1) when a tier is over budget
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"
INDEX = ROOT / "pipelines" / "audio" / "index"
MB = 1024 * 1024
# bucket → (low tier, mid/high tier) in MB; total cap.
BUDGET = {"music": (3.0, 5.0), "ambience": (1.5, 2.5), "sfx": (5.0, 7.0), "ui_stingers": (1.0, 1.0)}
TOTAL = (10.5, 16.0)


def resident_bytes(res: str) -> int:
    src = CLIENT / res.removeprefix("res://")
    imp = src.with_name(src.name + ".import")
    if imp.exists():
        m = re.search(r'^path="res://(.+?)"', imp.read_text(encoding="utf-8"), re.M)
        if m and (CLIENT / m.group(1)).exists():
            return (CLIENT / m.group(1)).stat().st_size
    return src.stat().st_size  # not imported yet: the source size is an upper bound for OGG


def measure(index: dict) -> dict[str, tuple[float, float]]:
    sfx = amb = ui = 0
    for sound_id, e in index["sfx"].items():
        size = sum(resident_bytes(f) for f in e["files"])
        if e["bus"] == "Ambience" and e["loop"]:
            amb += size
        elif sound_id.startswith("ui."):
            ui += size
        else:
            sfx += size
    music = index["music"]
    stingers = sum(resident_bytes(music[k]["file"]) for k in ("victory", "defeat") if k in music)
    run_high = sum(resident_bytes(f) for k in ("grove", "boss") if k in music for f in music[k]["files"])
    run_low = sum(resident_bytes(f) for k in ("grove", "boss") if k in music for f in music[k]["low_files"])
    camp = sum(resident_bytes(f) for f in music.get("camp", {}).get("playlist", []))
    return {
        "music": (max(run_low, camp) / MB, max(run_high, camp) / MB),
        "ambience": (amb / MB, amb / MB),
        "sfx": (sfx / MB, sfx / MB),
        "ui_stingers": ((ui + stingers) / MB, (ui + stingers) / MB),
    }


def main() -> int:
    path = INDEX / "grove_default.json"
    if not path.exists():
        print("audio_budget: no index — run pipelines/audio/synth.py", file=sys.stderr)
        return 1
    m = measure(json.loads(path.read_text(encoding="utf-8")))
    failed = False
    for tier, k in (("low", 0), ("mid/high", 1)):
        total = sum(v[k] for v in m.values())
        parts = []
        for bucket, values in m.items():
            over = values[k] > BUDGET[bucket][k]
            failed |= over
            parts.append(f"{bucket} {values[k]:.2f}/{BUDGET[bucket][k]:.1f}{' OVER' if over else ''}")
        over = total > TOTAL[k]
        failed |= over
        print(f"audio_budget [{tier}]: total {total:.2f}/{TOTAL[k]:.1f} MB{' OVER' if over else ''} — " + ", ".join(parts))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
