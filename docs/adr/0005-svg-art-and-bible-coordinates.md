# ADR-0005: Art ships as SVG source; the game uses the bible's 390 × 844 coordinates

- **Status:** Accepted (2026-10-02). Supersedes the viewport size in ADR-0002.
- **Context:** The Asset Bible v1.1 is a design canvas whose boards draw every asset as inline SVG, at sizes given for a 390-wide phone. The standards doc proposed resvg → PNG at 1×/0.75× committed through Git LFS.
- **Decision:**
  - `pipelines/asset/extract_bible.py` extracts the boards into standalone SVGs under `client/themes/<theme_id>/`. Each SVG's width/height is its in-game size × 3, and the file is committed as text.
  - Godot rasterizes each SVG **at import time** (Lossless, no mipmaps, checked by `tools/lint_deps.py`). The game never parses SVG at runtime. Scenes draw the sprites at 1/3 scale.
  - `pipelines/asset/build_scenes.py` generates the script-free theme scenes, the 14-bone hunter rig, the TileSet, the UI themes and the manifests.
  - The base viewport is **390 × 844** (`canvas_items`, `expand`), so every pixel value in the bible maps 1:1.
  - A grove room is **13 × 30 tiles of 32 px**, with the canopy wall around a walkable 11 × 26. This follows the phone mock, where the room fills the screen width. The 22 × 30 grid in the dev plan would have needed a horizontally scrolling camera.
  - Fonts (Baloo 2 variable, Hind; OFL) are committed as plain files. There is no Git LFS yet.
- **Consequences:**
  - Art diffs are reviewable and the repo stays LFS-free.
  - Re-running the extractor after a bible change gives a deterministic diff.
  - Texture density is fixed at 3× for now. Tier C 0.75× variants can come later through a second import scale.
  - Android launcher PNGs are rendered in CI from `client/icon.svg` (`tools/render_icons.gd`).
- **Revisit if:** import times or APK size grow past budget (then bake PNG atlases in CI), or Tier C needs lower-density textures.
