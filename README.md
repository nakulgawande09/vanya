# Vanya: Guardians of the Grove

A Warli-inspired 2D action roguelite for Android (iOS later), built with **Godot 4.7.2** (Compatibility renderer, GDScript) as one re-skinnable app with theme packs.

| Path | What | Status |
|---|---|---|
| `client/` | Godot project (`project.godot`) | First playable: Asset Bible art (forest + Deep Reef test theme), hunter rig, swarm/enemies/boss, waves, cages, gods, guides, camp shop and shrine, HUD, defeat/revive, Android export |
| `pipelines/asset/` | Asset Bible boards → theme SVGs, rigs and scenes | Working (see its README) |
| `server/`, `shared/`, `infra/` | Backend, shared schemas, Azure infra | Placeholders |
| `docs/` | `standards.md` (engineering standards), `dev-plan.md` (cross-platform plan), `adr/`, `art-bible/` | |
| `tools/` | `setup_godot.sh`, `lint_deps.py`, `check_scripts.gd`, `check_16kb.sh`, `render_icons.gd`, `svg_bounds.gd`, visual QA (`theme_preview.gd`, `screenshot_tour.gd`) | |

## Quick start

```bash
tools/setup_godot.sh                 # pinned Godot 4.7.2 + GdUnit4 into .tools/ and client/addons/
python3 tools/lint_deps.py           # dependency rules
just client-test                     # import + GdUnit4 tests (or see the justfile for the raw commands)
```

Open `client/project.godot` in the Godot 4.7.2 editor. The main scene is the camp (`ui/screens/main.tscn`), and a run is `gameplay/run/grove_run.tscn`. On desktop, move with WASD; on a phone, use the floating joystick. Provisional balance is documented in [docs/gdd/first-playable.md](docs/gdd/first-playable.md).

## Android

- Package `com.curiosapien.vanya`, min SDK 24, target SDK 36, arm64-v8a + armeabi-v7a, Gradle build, portrait.
- CI (`.github/workflows/android-build.yml`) builds a debug APK on every push, checks 16 KB page-size alignment, and uploads the APK as an artifact. Version tags (`v*`) also build a signed release AAB.
- For local builds, see [client/platform/android/README.md](client/platform/android/README.md).

## Conventions

Trunk-based on `main`, Conventional Commits, SemVer, and `versionCode = MAJOR*10000 + MINOR*100 + PATCH`. Coding rules: [CLAUDE.md](CLAUDE.md) and [docs/standards.md](docs/standards.md).
