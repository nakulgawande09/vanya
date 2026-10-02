class_name RoomLayout
extends RefCounted
## A grove room on a 13 × 30 grid of 32 px tiles (the bible's phone mock shows the room filling the
## screen width, with the gate at the top). Deterministic for (run_seed, grove).
## PCG v1 will replace the hand-tuned scatter below with chunk templates + validation (dev-plan §6.2).

const TILE: int = 32
const COLS: int = 13
const ROWS: int = 30
const SRC_FLOOR: int = 0
const SRC_GRASS: int = 1
const SRC_WALL: int = 2
const SRC_EDGE: int = 3

var grove: int
var walkable: Rect2
var size: Vector2
var start: Vector2
var gate: Vector2
var center: Vector2
var torches: Array[Vector2] = []
var bushes: Array[Vector2] = []
var idols: Array[Vector2] = []
var portals: Array[Vector2] = []
var decor: Array[Dictionary] = []  # {"id": StringName, "at": Vector2}
var cage_at: Vector2 = Vector2.ZERO
var has_cage: bool = false


static func generate(run_seed: int, grove_index: int) -> RoomLayout:
	var l: RoomLayout = RoomLayout.new()
	var rng: SeededRng = SeededRng.new(run_seed, grove_index, &"layout")
	l.grove = grove_index
	l.size = Vector2(COLS * TILE, ROWS * TILE)
	l.walkable = Rect2(TILE, TILE * 3, (COLS - 2) * TILE, (ROWS - 4) * TILE)
	l.start = Vector2(l.size.x / 2, l.walkable.end.y - 60)
	l.gate = Vector2(l.size.x / 2, TILE * 3)
	l.center = Vector2(l.size.x / 2, l.size.y * 0.55)
	var y: float = 150.0
	var side: int = rng.next_int(0, 1)
	while y < l.size.y - 60:
		l.bushes.append(Vector2(14.0 if side == 0 else l.size.x - 14.0, y))
		side = 1 - side
		y += float(rng.next_int(90, 150))
	for i: int in rng.next_int(2, 4):
		var left: bool = i % 2 == 0
		l.torches.append(Vector2(48.0 if left else l.size.x - 48.0, float(rng.next_int(200 + i * 150, 300 + i * 170))))
	for i: int in rng.next_int(2, 3):
		l.idols.append(Vector2(float(rng.next_int(70, int(l.size.x) - 70)), float(rng.next_int(200, 820))))
	var portal_count: int = 2 + mini(2, grove_index / 3)
	for i: int in portal_count:
		l.portals.append(Vector2(float(rng.next_int(70, int(l.size.x) - 70)), float(rng.next_int(170, 560))))
	if rng.chance(0.5):
		l.decor.append({"id": &"log", "at": Vector2(float(rng.next_int(80, 330)), float(rng.next_int(620, 780)))})
	if grove_index >= 2 and rng.chance(0.6):
		l.decor.append({"id": &"roots", "at": Vector2(float(rng.next_int(80, 330)), float(rng.next_int(300, 700)))})
	l.has_cage = grove_index == 1 or rng.chance(0.55)
	if l.has_cage:
		l.cage_at = Vector2(float(rng.next_int(80, 330)), float(rng.next_int(320, 640)))
	return l


## Fills a TileMapLayer (96 px tiles drawn at 1/3) with floor, grass decals and canopy walls.
func paint(tiles: TileMapLayer, run_seed: int) -> void:
	var rng: SeededRng = SeededRng.new(run_seed, grove, &"tiles")
	tiles.clear()
	for y: int in ROWS:
		for x: int in COLS:
			var c: Vector2i = Vector2i(x, y)
			if x == 0 or x == COLS - 1 or y < 2 or y == ROWS - 1:
				if y < 2 and absi(x - COLS / 2) <= 0 and y == 1:
					tiles.set_cell(c, SRC_FLOOR, Vector2i.ZERO, 0)
				else:
					tiles.set_cell(c, SRC_WALL, Vector2i.ZERO, _flip(rng))
			elif y == 2:
				tiles.set_cell(c, SRC_EDGE, Vector2i.ZERO, 0)
			else:
				var src: int = SRC_GRASS if rng.chance(0.18) else SRC_FLOOR
				tiles.set_cell(c, src, Vector2i.ZERO, _flip(rng))


static func _flip(rng: SeededRng) -> int:
	var alt: int = 0
	if rng.chance(0.5):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if rng.chance(0.5):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	return alt
