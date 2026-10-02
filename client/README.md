# client/

The Godot 4.7.2 project. Its layout follows [docs/standards.md §A.2](../docs/standards.md).

| Folder | Contents |
|---|---|
| `autoload/` | The 6 autoloads: `Boot`, `EventBus`, `Services`, `AdaptiveQuality`, `ThemeRegistry`, `SceneRouter` |
| `core/` | Pure logic: archetype/arrow/god/shrine/wave defs, `SpatialHash`, `SwarmSim`, `RunState`, `Profile` economy, `WavePlanner`, `SeededRng`, CRC32 |
| `gameplay/` | The run (`run/grove_run`), `combat/CombatWorld` (fixed-order tick), swarm MultiMesh flipbook, projectiles, scene enemies + Rotheart, pickups, fx, gods, guides, room layout/waves/cages, darkness veil + emissives |
| `pcg/`, `dda/` | Room generator and difficulty adjustment (empty) |
| `ui/` | Camp (shop + shrine + theme toggle), defeat/revive, HUD (pills, frenzy, joystick, god buttons) |
| `services/` | Interfaces and fake adapters: ads, iap, analytics, thermal; the real `SaveService` |
| `data/` | Typed `.tres` data: archetypes, arrows, gods, shrine, waves, quality ladder |
| `themes/` | `grove_default` (the Asset Bible) and `deep_reef` (test theme, inherits the rest): SVG art, generated scenes, manifest v2, strings |
| `localization/` | `strings.csv` (en/hi/mr) |
| `platform/` | Android/iOS native plugin notes (ADPF thermal, Game State) |
| `bench/` | `bench_swarm_40.tscn`: headless CPU benchmark |
| `tests/` | GdUnit4 suites: `unit/`, `scene/`, `golden/` |
| `addons/` | Third-party plugins. `gdUnit4` is installed by `tools/setup_godot.sh` and gitignored |

## Where the prototypes go
Port prototype logic into `gameplay/` and `core/`, keeping the typing and dependency rules. The first-playable systems are deliberately small, so they can be swapped piece by piece. Art changes go through `pipelines/asset/`, never by hand-editing the generated theme scenes.
