# Asset pipeline: Asset Bible → theme folders

The Asset Bible is a design canvas (`*.dc.html` boards). Every asset in it is either a named `<symbol>` or an `<svg>` with a descriptive `aria-label`. Two scripts turn it into engine-ready, script-free theme content:

```bash
# 1. Fetch the boards (e.g. download the canvas's project/*.dc.html files into a folder), then:
python3 pipelines/asset/extract_bible.py <boards_dir> --godot .tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64
python3 pipelines/asset/build_scenes.py
# or: just art <boards_dir>
```

## `extract_bible.py`
- Resolves `<use>`, gradients and the floor `<pattern>` (ThorVG has no patterns) into standalone SVGs.
- Gives each SVG a width/height of in-game size × 3. The scales come from the Grove board's phone mock and scale notes: hunter 78 px tall, Rotling about 54 px wide, Thornback 88 px, Rotheart 190 px, 32 px tiles.
- Crops each asset to its painted bounds by rendering it through Godot (`tools/svg_bounds.gd`).
- Splits Rig spec's exploded hunter into 14 parts using the board's layer table, pivots and parent bones, and writes `rigs/hunter/rig.json`.
- Bakes Rig spec's rotling clips (run 6, lunge 3, death 5) into `rigs/rotling_sheet.svg` with `.json` frame metadata.
- Writes the Play icon to `client/icon.svg`.
- Fails loudly on SVG features Godot can't rasterize: `filter`, `mask`, `foreignObject`.

## `build_scenes.py`
- Generates one visual scene per archetype, prop, god, guide and fx. Each is a `Sprite2D` anchored at the feet, plus an `AnimationPlayer` holding the board's CSS loop (trot, heavy, float, stomp, hover, sway, glide, twinkle, flicker, pulse, spin), plus an `Emissive` node with additive glows at the eyes, hearts, flames and spirit. Rooms lift the `Emissive` node above the darkness veil.
- Builds `rigs/hunter.tscn`: a `Skeleton2D` with 14 `Bone2D`s and idle / run / shoot / hurt / down / revive clips timed from the Hunter board.
- Builds `tiles/tiles.tres` (96 px tiles; the room draws its `TileMapLayer` at 1/3), the Baloo 2 font variations and `ui_theme.tres` from the Screens board's UI kit.
- Writes theme manifest v2 for `grove_default` and the `deep_reef` test theme.

Theme folders must never contain scripts. `tools/lint_deps.py` and a unit test both enforce this.
Visual QA: `tools/theme_preview.gd` renders every archetype of a theme; `tools/screenshot_tour.gd` captures camp, grove, fight and defeat (both need Xvfb or a display).
