#!/usr/bin/env python3
"""Summarises a feel-test CSV from the debug overlay (docs/feel-test/feel-test-plan.md, B6).

    python3 tools/feeltest_report.py out/feeltest/feeltest_20261002_181500.csv

Prints the metrics block for results-template.md and flags the scorecard thresholds
(p99 ≤ 20 ms, ≤ 1 jank/min, thermal headroom < 0.8, battery ≤ 4 %/10 min).
"""
from __future__ import annotations

import csv
import statistics
import sys
from pathlib import Path


def _floats(rows: list[dict], key: str) -> list[float]:
    out = []
    for r in rows:
        try:
            v = float(r.get(key, ""))
        except ValueError:
            continue
        out.append(v)
    return out


def summarise(path: Path) -> str:
    with path.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        return f"{path}: no rows"
    minutes = max(_floats(rows, "t_s") or [0.0]) / 60.0
    fps = _floats(rows, "fps")
    p99 = _floats(rows, "frame_ms_p99")
    jank = _floats(rows, "jank_per_min")
    voices = _floats(rows, "voices")
    steals = _floats(rows, "steals")
    audio = _floats(rows, "audio_mb")
    thermal = [v for v in _floats(rows, "thermal_headroom") if v >= 0.0]
    battery = [v for v in _floats(rows, "battery_pct") if v >= 0.0]
    drain = (battery[0] - battery[-1]) / minutes * 10.0 if len(battery) > 1 and minutes > 0 else float("nan")
    lines = [
        f"FEELTEST {path.name}: {len(rows)} rows, {minutes:.1f} min",
        f"FPS avg {statistics.mean(fps):.1f} (min {min(fps):.0f})" if fps else "FPS n/a",
        f"p99 frame median {statistics.median(p99):.1f} ms, worst {max(p99):.1f} ms {'OK' if statistics.median(p99) <= 20 else 'RED'}" if p99 else "p99 n/a",
        f"jank/min last {jank[-1]:.1f}, peak {max(jank):.1f} {'OK' if jank[-1] <= 1 else 'RED'}" if jank else "jank n/a",
        f"peak voices {max(voices):.0f}, steals {max(steals):.0f}, audio {max(audio):.2f} MB" if voices else "audio n/a",
        f"thermal headroom max {max(thermal):.2f} {'OK' if max(thermal) < 0.8 else 'RED'}" if thermal else "thermal n/a",
        f"battery {battery[0]:.0f}% → {battery[-1]:.0f}%, {drain:.1f}%/10 min {'OK' if drain <= 4 else 'RED'}" if len(battery) > 1 else "battery n/a",
    ]
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for arg in sys.argv[1:]:
        print(summarise(Path(arg)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
