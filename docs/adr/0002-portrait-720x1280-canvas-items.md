# ADR-0002: Portrait, 720×1280 base, `canvas_items` stretch, `expand` aspect

- **Status:** Accepted (2026-10-01); viewport size superseded by ADR-0005 (390 × 844)
- **Context:** One-thumb play on budget phones. The room grid is 22×30 tiles. Screens range from 18:9 to 20:9 phones and 4:3 tablets.
- **Decision:** `display/window/handheld/orientation = portrait`, a 720×1280 base viewport, `stretch/mode = canvas_items` and `stretch/aspect = expand`. UI anchors to the safe area. Gameplay keeps the 720-wide play field centred.
- **Consequences:** Crisp UI at any resolution. Taller phones show more vertical space, so the HUD must anchor to the edges. Render scale per quality rung (0.6–1.0) applies to the room through a SubViewport, not to the UI.
