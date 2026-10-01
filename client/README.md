# client/

The Godot 4.7.2 project. Its layout follows [docs/standards.md §A.2](../docs/standards.md).

| Folder | Contents |
|---|---|
| `autoload/` | The 6 autoloads: `Boot`, `EventBus`, `Services`, `AdaptiveQuality`, `ThemeRegistry`, `SceneRouter` |
| `core/` | Pure logic: archetype IDs and defs, `SeededRng`, CRC32, typed conversions. Later: combat math and swarm sim |
| `gameplay/` | Nodes that use `core/`: player, enemies, swarm, projectiles, room, fx, lighting. Today only the placeholder player, grove room and fake light exist |
| `pcg/`, `dda/` | Room generator and difficulty adjustment (empty) |
| `ui/` | Screens, widgets, HUD, accessibility. Today only the camp screen stub |
| `services/` | Interfaces and fake adapters: ads, iap, analytics, thermal; the real `SaveService` |
| `data/` | Typed `.tres` data: the quality ladder; archetype defs come later |
| `themes/grove_default/` | Bundled default theme: manifest, placeholder Warli-shape rigs, UI theme |
| `localization/` | `strings.csv` (en/hi/mr) |
| `platform/` | Android/iOS native plugin notes (ADPF thermal, Game State) |
| `bench/` | Headless benchmark scenes (empty) |
| `tests/` | GdUnit4 suites: `unit/`, `scene/`, `golden/` |
| `addons/` | Third-party plugins. `gdUnit4` is installed by `tools/setup_godot.sh` and gitignored |

## Where the prototypes and art go
- Prototype gameplay ports into `gameplay/` and `core/`, behind the typing and dependency rules.
- Exported Asset Bible art replaces the placeholder `themes/grove_default/rigs/*.tscn` scenes. Keep the same archetype IDs and paths so no code changes are needed. Raster files need Git LFS (see `.gitattributes`).
