#!/usr/bin/env python3
"""Sets Godot import flags on the generated audio (Audio Bible A5) after a first `godot --import`.

- Loop SFX (WAV): forward loop over the whole file. One-shots keep the defaults (QOA, no loop).
- Music stems and camp tracks (OGG): BPM, Beat Count and Bar Beats, so AudioStreamInteractive can
  switch on the next bar; stems and ambience beds loop.
- LICENSES.csv is kept as a plain file (Godot would otherwise import any CSV as a translation).
Run `godot --headless --path client --import` again afterwards so the flags take effect.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
CLIENT = HERE.parent.parent / "client"
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def _set(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    if pattern.search(text):
        return pattern.sub(f"{key}={value}", text)
    return text.rstrip("\n") + f"\n{key}={value}\n"


def _patch(res_path: str, values: dict) -> bool:
    imp = CLIENT / (res_path.removeprefix("res://") + ".import")
    if not imp.exists():
        print(f"import_flags: {imp} missing — run godot --import first")
        return False
    text = imp.read_text(encoding="utf-8")
    new = text
    for k, v in values.items():
        new = _set(new, k, v)
    if new != text:
        imp.write_text(new, encoding="utf-8")
    return True


def main() -> int:
    for index_path in sorted((HERE / "index").glob("*.json")):
        index = json.loads(index_path.read_text(encoding="utf-8"))
        theme = index["theme_id"]
        (CLIENT / "themes" / theme / "audio" / "LICENSES.csv.import").write_text(KEEP_IMPORT, encoding="utf-8")
        for entry in index["sfx"].values():
            for f in entry["files"]:
                if f.endswith(".wav"):
                    _patch(f, {"edit/loop_mode": "2" if entry["loop"] else "0", "edit/loop_begin": "0", "edit/loop_end": "-1"})
                else:
                    _patch(f, {"loop": "true" if entry["loop"] else "false", "loop_offset": "0"})
        for cue in index["music"].values():
            beats = str(cue.get("bars", 0) * cue.get("bar_beats", 4))
            bpm = str(cue.get("bpm", 0))
            for f in cue.get("files", []) + cue.get("low_files", []):
                _patch(f, {"loop": "true", "loop_offset": "0", "bpm": bpm, "beat_count": beats, "bar_beats": "4"})
            for f in cue.get("playlist", []):
                _patch(f, {"loop": "false", "bpm": bpm, "beat_count": beats, "bar_beats": "4"})
            if "file" in cue:
                _patch(cue["file"], {"loop": "false"})
    print("import_flags: done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
