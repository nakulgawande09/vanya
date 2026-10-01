# Art bible: palette, type and asset rules

Extracted from the *Vanya Asset Bible v1* (style guide board). The full boards (Hunter, Blight beasts, Rotheart, Gods and the shrine, Guides and cages, Grove tiles, Screens and UI kit, Store assets) will be exported later. These tokens are already in `client/themes/grove_default/manifest.json` (`palette`) and `ui_theme.tres`.

## Palette

| Token | Hex | Use |
|---|---|---|
| `night_ink` | `#1C1016` | outlines |
| `deep_grove` | `#16241F` | night background |
| `canopy` | `#2F5A44` | foliage |
| `trail_clay` | `#6B4430` | floor |
| `geru_earth` | `#9B3B1F` | Warli wall |
| `rice_white` | `#F3EAD6` | figures, text |
| `skin_umber` | `#7A4A2F` | hero |
| `spirit_jade` | `#6FF2B0` | spirit, grace, primary button |
| `meat_amber` | `#E0913F` | meat, reward-ad button |
| `torch_gold` | `#FFC54A` | fire, light |
| `blight_violet` | `#4A1F5E` | corruption |
| `blight_glow` | `#E56BFF` | eyes, veins |
| `storm_sky` | `#8FD3FF` | Meghra |
| `kumkum_red` | `#C8372D` | health, headband |

## Type
- **Baloo 2 ExtraBold:** titles, numbers, buttons, banners (has Devanagari for hi/mr)
- **Hind Medium:** body copy, descriptions, tooltips, store copy (has Devanagari)

The fonts are not in the repo yet. Add them under `client/themes/grove_default/fonts/` through Git LFS and wire them into `ui_theme.tres`.

## Rules for every asset
1. Build figures from triangles, circles and lines, the Warli vocabulary. Never copy a specific painting.
2. Night Ink outline, 4 px at 200 px character height; it scales with the sprite.
3. Two-tone shading: base colour plus one shadow on the side away from the top-left key light.
4. Only three things glow: spirit (jade), blight (violet-pink) and fire (gold). Nothing else emits light.
5. Spirit and blight must read apart in lightness as well as hue; test every screen in greyscale.
6. Deliver layered SVG plus PNG at 1×, 2× and 3×, with limbs on separate layers for Godot cut-out rigs.

## UI kit notes (Screens board)
- Camp: "Enter the grove". Arrows are paid in meat (e.g. Bone arrows: 18 damage, pierce one beast). The shrine of the elder gods (Suryak, Tamba, Kaja, Anjor) is paid in spirit.
- Defeat: "The blight took you", with "Watch ad to rise again" (meat-amber reward-ad button) and "Back to camp".
- Buttons: primary is spirit jade, reward ad is meat amber, then secondary, and locked ("not enough spirit").
- Floating numbers: arrow hit, god strike, heal (+), you are hit (−). Icons are 48 px.
