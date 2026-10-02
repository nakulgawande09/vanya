#!/usr/bin/env python3
"""Renders Vanya's placeholder audio (Audio Bible A2–A4) into the theme folders.

    python3 pipelines/audio/synth.py            # render everything (needs numpy, scipy, ffmpeg)
    python3 pipelines/audio/synth.py --report   # print loudness / true-peak / size per file

Output per theme (client/themes/<theme>/audio/):
  sfx/<id_with_underscores>_<nn>.wav|ogg  short one-shots and short loops as WAV, the rest OGG
  music/<cue>_<stem>.ogg                    bar-exact stems (+ *_low_* 3-stem variants for the low tier)
  amb/<id>.ogg                              ambience beds
  LICENSES.csv                              one row per file (all original, CC0)
and pipelines/audio/index/<theme>.json, the index tools/build_audio_manifest.gd turns into
audio_manifest.tres. Everything is seeded per ID, so a re-run reproduces the same samples.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import shutil
import subprocess
import sys
import tempfile
import wave
import zlib
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import music  # noqa: E402
from dsp import SR, db, limit_true_peak, lufs_integrated, lufs_momentary_max, n_of, true_peak_db, wrap  # noqa: E402
from sfx import apply_post, render_layers  # noqa: E402

ROOT = HERE.parent.parent
THEMES = ROOT / "client" / "themes"
BUILD = HERE / "index"
WAV_MAX_SECONDS = 1.0      # A5: short SFX as WAV (no decode cost, lowest latency)
WAV_LOOP_MAX_SECONDS = 2.0
STEM_LUFS = -23.0          # A1: each stem −23…−20 LUFS-I solo
CAMP_LUFS = -20.0
STINGER_LUFS = -19.0
AMB_LUFS = -26.0           # A4 batch target for ambience beds
OGG_QUALITY = {"sfx": 3, "music": 3, "amb": 2}
LICENSE_HEADER = ["file", "archetype_id", "source", "url", "author", "licence", "attribution_required", "modified", "notes"]
BUS_BY_PREFIX = {"sfx": "SFX", "ui": "UI", "amb": "Ambience", "mus": "Music"}


def seed_of(key: str, variant: int = 0) -> int:
    return (zlib.crc32(key.encode()) ^ (variant * 7919)) & 0xFFFFFFFF


# ----------------------------------------------------------------------------- writers

def _pcm16(x: np.ndarray) -> bytes:
    return (np.clip(x, -1.0, 1.0) * 32767.0).round().astype("<i2").tobytes()


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(_pcm16(x))


def write_ogg(path: Path, x: np.ndarray, quality: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "in.wav"
        write_wav(src, x)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", str(quality),
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", str(path)], check=True)


def res_path(p: Path) -> str:
    return "res://" + p.relative_to(ROOT / "client").as_posix()


# ----------------------------------------------------------------------------- SFX

def render_entry(e: dict, levels: dict, variant: int) -> np.ndarray:
    rng = np.random.default_rng(seed_of(e["id"], variant))
    pf = 1.0 if e.get("prand", 1.06) == 1.0 else 1.0 + rng.uniform(-0.04, 0.04)
    layers = e["alts"][variant % len(e["alts"])] if "alts" in e else e["layers"]
    x = render_layers(layers, rng, pf)
    x = apply_post(x, e.get("post", []), rng)
    if e.get("loop"):
        x = wrap(x, n_of(e["len"]))
    target = levels[e.get("level", "focus")]
    loud = lufs_momentary_max(np.concatenate([x, x]) if e.get("loop") else x)
    x = x * db(target - loud)
    return limit_true_peak(x, -1.0)


def render_sfx(theme: str, bom: dict, rows: list, index: dict) -> None:
    out_dir = THEMES / theme / "audio" / "sfx"
    for e in bom["entries"]:
        files = []
        for v in range(e.get("var", 1)):
            x = render_entry(e, bom["levels"], v)
            seconds = len(x) / SR
            as_wav = seconds <= (WAV_LOOP_MAX_SECONDS if e.get("loop") else WAV_MAX_SECONDS)
            name = f"{e['id'].replace('.', '_')}_{v + 1:02d}.{'wav' if as_wav else 'ogg'}"
            path = out_dir / name
            (write_wav(path, x) if as_wav else write_ogg(path, x, OGG_QUALITY["sfx"]))
            files.append(res_path(path))
            rows.append(_license_row(path, e["id"], f"seed={seed_of(e['id'], v)}"))
        prefix = e["id"].split(".")[0]
        index["sfx"][e["id"]] = {
            "files": files, "bus": e.get("bus", BUS_BY_PREFIX[prefix]), "tier": e.get("tier", 2), "poly": e.get("poly", 1),
            "pan": e.get("pan", False), "loop": e.get("loop", False), "cooldown_ms": e.get("cd", 0),
            "haptic": e.get("haptic", ""), "random_pitch": e.get("prand", 1.06), "random_volume_db": e.get("vrand", 2.0),
        }


# ----------------------------------------------------------------------------- music + ambience

def _level(x: np.ndarray, lufs: float) -> np.ndarray:
    return limit_true_peak(x * db(lufs - lufs_integrated(x)), -1.0)


def _stems(theme: str, cue: str, data: dict, rows: list, index: dict) -> None:
    out_dir = THEMES / theme / "audio" / "music"
    stems = dict(data["stems"])
    names = [s for s, _ in data["stems"]]
    paths = []
    for name in names:
        p = out_dir / f"{cue}_{name}.ogg"
        write_ogg(p, _level(stems[name], STEM_LUFS), OGG_QUALITY["music"])
        rows.append(_license_row(p, f"mus.{cue}.{name}", "bar-exact stem"))
        paths.append(res_path(p))
    # Low tier (A3): 3 stems — the same bed and melody, plus percussion + tension merged into one
    # "drive" stem; the frenzy stem is dropped.
    p = out_dir / f"{cue}_low_drive.ogg"
    drive = _level(stems["perc"], STEM_LUFS) + _level(stems["tension"], STEM_LUFS)
    write_ogg(p, _level(drive, STEM_LUFS), OGG_QUALITY["music"])
    rows.append(_license_row(p, f"mus.{cue}.low.drive", "bar-exact stem, low tier"))
    low = {"bed": paths[names.index("bed")], "melody": paths[names.index("melody")], "drive": res_path(p)}
    low_paths = list(low.values())
    index["music"][cue] = {"bpm": data["bpm"], "bars": data["bars"], "bar_beats": 4, "stems": names, "files": paths,
                           "low_stems": list(low.keys()), "low_files": low_paths}


def render_music(theme: str, rows: list, index: dict) -> None:
    _stems(theme, "grove", music.grove(np.random.default_rng(seed_of("mus.grove"))), rows, index)
    _stems(theme, "boss", music.boss(np.random.default_rng(seed_of("mus.boss"))), rows, index)
    out_dir = THEMES / theme / "audio" / "music"
    camp_files = []
    for v, tag in enumerate(("a", "b")):
        c = music.camp(np.random.default_rng(seed_of("mus.camp", v)), v)
        p = out_dir / f"camp_{tag}.ogg"
        write_ogg(p, _level(c["mix"], CAMP_LUFS), OGG_QUALITY["music"])
        rows.append(_license_row(p, f"mus.camp.{tag}", "bar-exact track"))
        camp_files.append(res_path(p))
    index["music"]["camp"] = {"bpm": 72, "bars": 32, "bar_beats": 4, "playlist": camp_files}
    for win in (True, False):
        name = "victory" if win else "defeat"
        x = music.stinger(np.random.default_rng(seed_of(f"mus.{name}")), win)
        p = out_dir / f"{name}.ogg"
        write_ogg(p, _level(x, STINGER_LUFS), OGG_QUALITY["music"])
        rows.append(_license_row(p, f"mus.{name}", "stinger"))
        index["music"][name] = {"file": res_path(p)}
    amb_dir = THEMES / theme / "audio" / "amb"
    grove_bed = music.amb_grove(np.random.default_rng(seed_of("amb.grove")))
    blight_bed = music.amb_blight(np.random.default_rng(seed_of("amb.blight")), grove_bed)
    for amb_id, x in (("amb.grove.default.bed", grove_bed), ("amb.blight.bed", blight_bed)):
        p = amb_dir / f"{amb_id.replace('.', '_')}.ogg"
        write_ogg(p, _level(x, AMB_LUFS), OGG_QUALITY["amb"])
        rows.append(_license_row(p, amb_id, "loop"))
        index["sfx"][amb_id] = {"files": [res_path(p)], "bus": "Ambience", "tier": 4, "poly": 1, "pan": False, "loop": True,
                                "cooldown_ms": 0, "haptic": "", "random_pitch": 1.0, "random_volume_db": 0.0}


# ----------------------------------------------------------------------------- bookkeeping

def _license_row(path: Path, archetype_id: str, notes: str) -> list:
    return [path.relative_to(path.parents[1]).as_posix(), archetype_id, "original: pipelines/audio/synth.py", "",
            "Vanya team (procedural)", "CC0-1.0", "false", "false", notes]


def _clean(theme: str) -> None:
    for sub in ("sfx", "music", "amb"):
        d = THEMES / theme / "audio" / sub
        if d.exists():
            shutil.rmtree(d)


def build_theme(theme: str, bom_path: Path, with_music: bool) -> None:
    bom = json.loads(bom_path.read_text(encoding="utf-8"))
    _clean(theme)
    rows: list = []
    index: dict = {"theme_id": theme, "sfx": {}, "music": {}}
    render_sfx(theme, bom, rows, index)
    if with_music:
        render_music(theme, rows, index)
    lic = THEMES / theme / "audio" / "LICENSES.csv"
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(LICENSE_HEADER)
    w.writerows(sorted(rows))
    lic.write_text(buf.getvalue(), encoding="utf-8")
    # Keep the CSV as a plain file: Godot imports any CSV as a translation by default.
    (lic.parent / "LICENSES.csv.import").write_text('[remap]\n\nimporter="keep"\n', encoding="utf-8")
    BUILD.mkdir(exist_ok=True)
    (BUILD / f"{theme}.json").write_text(json.dumps(index, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"synth: {theme}: {len(rows)} files, {len(index['sfx'])} sfx ids, {len(index['music'])} music cues")


def report() -> None:
    import subprocess as sp
    for theme in ("grove_default", "deep_reef"):
        for p in sorted((THEMES / theme / "audio").rglob("*")):
            if p.suffix not in (".wav", ".ogg"):
                continue
            raw = sp.run(["ffmpeg", "-loglevel", "error", "-i", str(p), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
            x = np.frombuffer(raw, dtype="<f4").astype(float)
            print(f"{p.relative_to(THEMES)}  {len(x) / SR:6.2f}s  I={lufs_integrated(x):6.1f}  M={lufs_momentary_max(x):6.1f}  "
                  f"TP={true_peak_db(x):5.1f}  {p.stat().st_size / 1024:7.1f} KB")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()
    if args.report:
        report()
        return 0
    if shutil.which("ffmpeg") is None:
        print("synth: ffmpeg not found", file=sys.stderr)
        return 1
    build_theme("grove_default", HERE / "bom.json", with_music=True)
    build_theme("deep_reef", HERE / "bom_deep_reef.json", with_music=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
