# ADR-0007: Audio and haptics behind `Services`, theme audio manifests, synthesised placeholders

- **Status:** Accepted (2026-10-02)
- **Context:** The Audio Bible (`docs/audio/audio-bible.md`) asks for one `Audio` autoload that resolves sounds by archetype ID from a theme manifest, pools voices, ducks music, drives adaptive stems and fires haptics. The project already has the six autoloads CLAUDE.md allows (Boot, EventBus, Services, AdaptiveQuality, ThemeRegistry, SceneRouter). The container that builds placeholders has ffmpeg but no sox, DAW or sample library, and shipped audio must be CC0, Sonniss-GDC or original.
- **Decision:**
  - **No seventh autoload.** Audio and haptics are services, like ads and analytics:
    - `Services.audio: AudioService` and `Services.haptics: HapticsService`.
    - The fakes (`RecordingAudio`, `FakeHaptics`) are the defaults and record what was asked for, so tests can assert on sound IDs.
    - `Boot` installs the real adapters: `GodotAudio` (a node parented under `Services`, so it outlives scene changes) and `DeviceHaptics`.
    - `GodotAudio` owns the registry, the 16-voice pool, ducking and the `MusicDirector` (a child node).
  - **Theme audio manifests:**
    - Each theme folder has a generated `audio/audio_manifest.tres` (`AudioManifest`: `Dictionary[StringName, AudioEntry]`, each stream an `AudioStreamRandomizer`), plus `music_run.tres` / `music_camp.tres`. `manifest.json` points at them.
    - Lookups walk the ID fallback (`a.b.c.d` → `a.b.c`) and then the theme inheritance chain.
    - Theme folders stay data-only: the `.tres` files reference scripts in `client/services/audio/`, and contain none.
  - **Placeholders are synthesised:**
    - `pipelines/audio/synth.py` is stdlib-only and seeded per ID. It renders every BOM entry and the music stems: bar-exact, D pentatonic, original melodies, no samples.
    - `tools/audio_batch.sh` (ffmpeg only) trims, filters and normalises them.
    - `LICENSES.csv` lists every file as original work (CC0).
    - Real recordings or composer stems replace files under the same IDs with no code change.
  - **Adaptive music:** a pure `StemMixer` turns `IntensityDirector` phase + frenzy into per-stem target dB, following the Bible's table:
    - 2-beat fade up, 4-beat fade down, starting on the next beat
    - 4 s hysteresis
    - one change per bar

    `MusicDirector` applies those targets with `AudioStreamSynchronized.set_sync_stream_volume` and switches `AudioStreamInteractive` clips on the next bar. Only the current context's music is loaded (camp vs run), which keeps the low tier under the 10.5 MB audio budget.
- **Consequences:**
  - Gameplay calls `Services.audio.play(id, at)` with precomputed `StringName` IDs. It never touches players or theme paths.
  - Deep Reef overrides a few IDs to prove the swap. Everything else falls back to `grove_default`.
  - The budget and licence checks run in CI. A file without a licence row, or an over-budget tier, fails the build.
  - The placeholders are deliberately simple. Their job is timing, mix hierarchy and memory, not final sound.
  - The generated placeholder WAV/OGG files (~13 MB) are committed as plain files, not Git LFS, so CI and fresh clones work without LFS (`.gitattributes`). Recorded or composed audio can move to LFS later.
- **Not done / revisit:**
  - iOS Ambient session and "let my music play" on iOS (the setting exists; Android checks `AudioManager.isMusicActive()`).
  - Android audio focus and headphone-unplug handling (needs a small plugin if the feel test fails them).
  - Rich haptics plugins.
  - Oboe: Godot 4.7 still uses OpenSL ES on Android.
