# Theme: grove_default

The bundled default theme. Downloadable theme packs use the same layout and mount under `res://themes/<theme_id>/`.

**Packs contain no scripts.** No `.gd`, `.gdc`, `.cs`, `.gdextension` or native libraries are allowed (App Store 2.5.2, Play device-abuse policy). `tools/lint_deps.py` enforces this.

- `manifest.json`: theme ID, palette tokens, and the archetype → visual mapping read by `ThemeRegistry`
- `rigs/`: one scene per archetype. These are **placeholder** flat Warli shapes (circles, triangles, lines) in Asset Bible palette colours, until the real cut-out rigs are exported.
- `ui_theme.tres`: the Godot `Theme` built from palette tokens
- `fonts/`: Baloo 2 ExtraBold (display) and Hind Medium (body), both with Devanagari. Not added yet; they need Git LFS.
- `audio/`, `strings/`, `shaders/`: empty for now

Path convention: `res://themes/<theme_id>/<category>/<archetype_id>_<part>.<ext>`.
