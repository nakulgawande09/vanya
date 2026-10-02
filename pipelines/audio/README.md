# pipelines/audio — placeholder sound and music

Implements the placeholder pipeline from the Audio Bible (`docs/audio/audio-bible.md`, A2–A4).
Every file is **original procedural work (CC0)**. There are no samples, no ritual recordings and no
borrowed melodies.

| File | What it does |
|---|---|
| `bom.json` | The A2 SFX bill of materials: ID, variants, tier, polyphony, pan, loop, cooldown, haptic key, loudness class and synth recipe |
| `bom_deep_reef.json` | Deep Reef overrides (a test theme); everything else falls back to `grove_default` |
| `sfx.py`, `dsp.py` | The recipes (drum, pluck, bell, squeal, grunt, creak, crack, zap, fizz, breath, …) and a small DSP kit, including a BS.1770 loudness meter |
| `music.py` | Bar-exact stems. Grove: D minor pentatonic, 96 BPM, 16 bars, 5 stems. Boss: D Phrygian, 120 BPM, 4 stems. Camp: 72 BPM, 32 bars, 2 tracks. Also stingers and ambience beds |
| `synth.py` | Renders everything, levels it (SFX to the A1 momentary-loudness classes, stems to −23 LUFS-I, ambience to −26), limits to −1 dBTP, writes WAV/OGG plus `LICENSES.csv` and `index/<theme>.json` |
| `import_flags.py` | Sets Godot import flags: WAV loops, and OGG loop/BPM/beat count/bar beats. Also keeps `LICENSES.csv` out of the translation importer |

Rebuild (needs `pip install -r pipelines/audio/requirements.txt` and ffmpeg):

```
just audio          # synth → import → flags → import → tools/build_audio_manifest.gd
just audio-check    # memory budget per quality tier (tools/audio_budget.py) + loudness report
```

To replace a placeholder with a recorded or composed file:
1. Name the source `<archetype_id>__<nn>.wav`.
2. List it in `raw/LICENSES.csv` (CC0, Sonniss-GDC or original only).
3. Run `tools/audio_batch.sh raw client/themes/<theme>/audio/sfx`.
4. Point the BOM entry at it, or drop the entry so the batch file is used.
5. Rebuild the manifest.

`tools/lint_deps.py` fails the build if any audio file has no licence row.
