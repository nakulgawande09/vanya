# Vanya: Guardians of the Grove

A Warli-inspired 2D action roguelite for Android (iOS later), built with **Godot 4.7.2** (Compatibility renderer, GDScript) as one re-skinnable app with theme packs.

| Path | What | Status |
|---|---|---|
| `client/` | Godot project (`project.godot`) | Week-1 skeleton: autoloads, services, quality ladder, placeholder theme, camp and grove screens, Android export |
| `server/`, `pipelines/`, `shared/`, `infra/` | Backend, asset/theme-pack pipelines, shared schemas, Azure infra | Placeholders |
| `docs/` | `standards.md` (engineering standards), `dev-plan.md` (cross-platform plan), `adr/`, `art-bible/` | |
| `tools/` | `setup_godot.sh`, `lint_deps.py`, `check_16kb.sh` | |

## Quick start

```bash
tools/setup_godot.sh                 # pinned Godot 4.7.2 + GdUnit4 into .tools/ and client/addons/
python3 tools/lint_deps.py           # dependency rules
just client-test                     # import + GdUnit4 tests (or see the justfile for the raw commands)
```

Open `client/project.godot` in the Godot 4.7.2 editor to work on scenes. The main scene is `ui/screens/main.tscn`.

## Android

- Package `com.curiosapien.vanya`, min SDK 24, target SDK 36, arm64-v8a + armeabi-v7a, Gradle build, portrait.
- CI (`.github/workflows/android-build.yml`) builds a debug APK on every push, checks 16 KB page-size alignment, and uploads the APK as an artifact. Version tags (`v*`) also build a signed release AAB.
- For local builds, see [client/platform/android/README.md](client/platform/android/README.md).

## Conventions

Trunk-based on `main`, Conventional Commits, SemVer, and `versionCode = MAJOR*10000 + MINOR*100 + PATCH`. Coding rules: [CLAUDE.md](CLAUDE.md) and [docs/standards.md](docs/standards.md).
