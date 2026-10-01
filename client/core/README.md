# core/

Pure logic. It depends on nothing outside `core/`. It must not load anything from `themes/`, `ui/`, `services/` or `addons/`; `tools/lint_deps.py` enforces this.

- `archetypes/`: `ArchetypeDef` resources and the immutable `Ids` table
- `combat/`: damage calculation, status effects and hitbox math (no nodes)
- `rng/`: `SeededRng` streams
- `sim/`: `SwarmSim` (struct-of-arrays), `ProjectileSim` and the spatial hash
- `util/`: small static helpers
