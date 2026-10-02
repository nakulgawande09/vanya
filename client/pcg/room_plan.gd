class_name RoomPlan
extends RefCounted
## A generated grove room: a 13 × 30 grid of tile semantics plus where things go. Pure data,
## built off the main thread by RoomGenerator and turned into nodes by gameplay's RoomBuilder.
## Layout (rows top → bottom): 0–2 canopy wall (gate in row 1), 3–5 gate apron, 6–23 three chunks,
## 24–28 start strip, 29 wall. Columns 0 and 12 are canopy wall.

enum Tile { WALL, FLOOR, OBSTACLE, SLOW, GATE }

const COLS: int = 13
const ROWS: int = 30
const TILE: int = 32
const INTERIOR: Rect2i = Rect2i(1, 3, 11, 26)
const CHUNK_ROWS: Array[int] = [6, 12, 18]
const GATE_CELL: Vector2i = Vector2i(6, 1)
const GATE_APRON: Vector2i = Vector2i(6, 3)
const START_CELL: Vector2i = Vector2i(6, 27)
const NONE: Vector2i = Vector2i(-1, -1)

var tiles: PackedByteArray = PackedByteArray()
var grove: int = 1
var family: StringName = &""
var chunk_ids: PackedStringArray = PackedStringArray()
var portals: Array[Vector2i] = []
var torches: Array[Vector2i] = []
var idols: Array[Vector2i] = []
## Left cell of each two-tile fallen log.
var logs: Array[Vector2i] = []
## Left cell of each two-tile blight-roots decal.
var roots: Array[Vector2i] = []
## Wall cells (column 0 or 12) that get a bush.
var bushes: Array[Vector2i] = []
var cage: Vector2i = NONE
var attempts: int = 0
var fallback: bool = false


func _init() -> void:
	tiles.resize(COLS * ROWS)
	tiles.fill(Tile.WALL)


func tile(c: Vector2i) -> int:
	return tiles[c.y * COLS + c.x] if in_bounds(c) else Tile.WALL


func set_tile(c: Vector2i, t: Tile) -> void:
	if in_bounds(c):
		tiles[c.y * COLS + c.x] = t


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func is_walkable(c: Vector2i) -> bool:
	var t: int = tile(c)
	return t == Tile.FLOOR or t == Tile.SLOW


func has_cage() -> bool:
	return cage != NONE


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func size_px() -> Vector2:
	return Vector2(COLS * TILE, ROWS * TILE)


func walkable_rect() -> Rect2:
	return Rect2(INTERIOR.position * TILE, INTERIOR.size * TILE)


## Where the gate art stands (feet on the apron's top edge).
func gate_position() -> Vector2:
	return Vector2(COLS * TILE / 2.0, INTERIOR.position.y * TILE)


func start_position() -> Vector2:
	return cell_center(START_CELL)


func center() -> Vector2:
	return Vector2(COLS * TILE / 2.0, (CHUNK_ROWS[1] + 3) * TILE)


## Stable fingerprint for golden-seed tests (tiles, portals, cage, torches).
func digest() -> int:
	var parts: Array = [tiles, portals, cage, torches, idols, logs]
	return hash(var_to_str(parts))


## Passability codes for FlowField (0 blocked, 1 free, 2 slow).
func flow_codes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(tiles.size())
	for i: int in tiles.size():
		match tiles[i]:
			Tile.FLOOR, Tile.GATE:
				out[i] = FlowField.FREE
			Tile.SLOW:
				out[i] = FlowField.SLOW
			_:
				out[i] = FlowField.BLOCKED
	return out
