class_name RoomRules
extends Resource
## Tunables for room generation and validation (dev-plan §6.2). Read-only at runtime.

@export var chunks: Array[ChunkDef] = []
## Families the generator draws from, and how often a room uses its family's own chunks
## (the rest come from open_glade).
@export var families: PackedStringArray = PackedStringArray(["open_glade", "idol_maze", "river_split", "ring_arena"])
@export var boss_family: StringName = &"boss_hollow"
@export_range(0.0, 1.0) var family_share: float = 0.67
@export var boss_every: int = 5
@export var portals_min: int = 2
@export var portals_max: int = 4
@export var torches_min: int = 2
@export var torches_max: int = 4
@export var torch_min_rows_apart: int = 6
@export var portal_min_apart: int = 4
@export var cage_chance: float = 0.55
@export var cage_min_portal_distance: int = 6
@export var min_open_ratio: float = 0.55
@export var min_portal_path: int = 8
## Upper and lower chunk edges must share at least this many open columns.
@export var min_edge_passages: int = 4
@export var max_attempts: int = 5
## Hand-made rooms (chunk ids top → bottom) used when every attempt fails validation.
@export var fallback_rooms: Array[PackedStringArray] = []
## The first-run tutorial room (chunk ids top → bottom).
@export var tutorial_room: PackedStringArray = PackedStringArray()
