# ADR-0003: Gameplay written against archetype IDs; themes are script-free packs

- **Status:** Accepted (2026-10-01)
- **Context:** Re-skinning (forest, underwater, space…) is tested inside one app. Apple 2.5.2 and 4.3(a) and Google's repetitive-content policy forbid downloading code and publishing one app per skin.
- **Decision:** Gameplay refers only to the immutable `StringName` IDs in `core/archetypes/ids.gd`. `ThemeRegistry.visual_for(id)` resolves visuals from `res://themes/<theme_id>/manifest.json`. Theme folders and packs contain no scripts or native code; `tools/lint_deps.py` enforces this, and so does a unit test. Downloaded packs mount with `load_resource_pack(path, false)` at scene boundaries, after verifying SHA-256 and the Ed25519 signature.
- **Consequences:** The default theme (`grove_default`) is bundled and follows the same layout as a downloadable pack. Placeholder rigs keep the game runnable until the Asset Bible art is exported.
