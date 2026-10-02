class_name RoomBuilder
extends RefCounted
## Turns a RoomPlan into nodes between rooms (never during waves): paints the tile layer, places
## the theme's props, and adds collision for logs and idols so the hunter walks around them.
## Beasts avoid the same cells through the combat world's FlowField.

const SRC_FLOOR: int = 0
const SRC_GRASS: int = 1
const SRC_WALL: int = 2
const SRC_EDGE: int = 3
const OBSTACLE_LAYER: int = 64  # "walls" physics layer

var nodes: Array[Node] = []
var portals: Array[Node2D] = []
var gate_sealed: Node2D
var gate_open: Node2D
var torches: Array[Vector2] = []
var _emissive: Node


func _init(emissive_layer: Node) -> void:
	_emissive = emissive_layer


func build(plan: RoomPlan, tiles: TileMapLayer, decals: Node2D, entities: Node2D, run_seed: int) -> void:
	_paint(plan, tiles, run_seed)
	_add(ThemeRegistry.prop_for(&"dance_ring"), plan.center(), decals)
	for c: Vector2i in plan.bushes:
		var b: Node2D = _add(ThemeRegistry.prop_for(&"bush"), RoomPlan.cell_center(c) + Vector2(0, 10), entities)
		if b != null:
			b.scale = Vector2(-0.8 if c.x > RoomPlan.COLS / 2 else 0.8, 0.8)
	torches.clear()
	for c: Vector2i in plan.torches:
		var at: Vector2 = RoomPlan.cell_center(c) + Vector2(0, 12)
		_add(ThemeRegistry.visual_for(Ids.TORCH), at, entities)
		torches.append(at)
	for c: Vector2i in plan.idols:
		_add(ThemeRegistry.prop_for(&"idol"), RoomPlan.cell_center(c) + Vector2(0, 12), entities)
	for c: Vector2i in plan.logs:
		_add(ThemeRegistry.prop_for(&"log"), RoomPlan.cell_center(c) + Vector2(RoomPlan.TILE / 2.0, 10), entities)
	for c: Vector2i in plan.roots:
		var r: Node2D = _add(ThemeRegistry.prop_for(&"roots"), RoomPlan.cell_center(c) + Vector2(RoomPlan.TILE / 2.0, 0), decals)
		if r != null:
			r.scale = Vector2(1.0, 0.75)
	portals.clear()
	for c: Vector2i in plan.portals:
		var p: Node2D = _add(ThemeRegistry.prop_for(&"portal"), RoomPlan.cell_center(c), decals)
		if p != null:
			p.visible = false
			p.scale = Vector2(0.9, 0.6)
			portals.append(p)
	gate_sealed = _add(ThemeRegistry.prop_for(&"gate_sealed"), plan.gate_position(), entities)
	gate_open = _add(ThemeRegistry.prop_for(&"gate_open"), plan.gate_position(), entities)
	if gate_open != null:
		gate_open.visible = false
	_add_obstacle_collision(plan, entities)


func portal_positions(plan: RoomPlan) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c: Vector2i in plan.portals:
		out.append(RoomPlan.cell_center(c))
	return out


func clear() -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	portals.clear()
	torches.clear()
	gate_sealed = null
	gate_open = null


func track(n: Node) -> void:
	nodes.append(n)


func _paint(plan: RoomPlan, tiles: TileMapLayer, run_seed: int) -> void:
	var rng: SeededRng = SeededRng.new(run_seed, plan.grove, &"tiles")
	tiles.clear()
	for y: int in RoomPlan.ROWS:
		for x: int in RoomPlan.COLS:
			var c: Vector2i = Vector2i(x, y)
			match plan.tile(c):
				RoomPlan.Tile.WALL:
					tiles.set_cell(c, SRC_EDGE if y == 2 else SRC_WALL, Vector2i.ZERO, _flip(rng) if y != 2 else 0)
				_:
					var src: int = SRC_GRASS if rng.chance(0.18) else SRC_FLOOR
					tiles.set_cell(c, src, Vector2i.ZERO, _flip(rng))


func _add_obstacle_collision(plan: RoomPlan, parent: Node2D) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Obstacles"
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	for y: int in RoomPlan.ROWS:
		for x: int in RoomPlan.COLS:
			var c: Vector2i = Vector2i(x, y)
			if plan.tile(c) != RoomPlan.Tile.OBSTACLE:
				continue
			var shape: CollisionShape2D = CollisionShape2D.new()
			var rect: RectangleShape2D = RectangleShape2D.new()
			rect.size = Vector2(RoomPlan.TILE, RoomPlan.TILE * 0.7)
			shape.shape = rect
			shape.position = RoomPlan.cell_center(c) + Vector2(0, RoomPlan.TILE * 0.15)
			body.add_child(shape)
	parent.add_child(body)
	nodes.append(body)


func _add(scene: PackedScene, at: Vector2, parent: Node2D) -> Node2D:
	if scene == null:
		return null
	var n: Node2D = scene.instantiate() as Node2D
	n.position = at
	parent.add_child(n)
	var glow: Node2D = Emissive.lift(n, _emissive)
	if glow != null:
		nodes.append(glow)
	nodes.append(n)
	return n


static func _flip(rng: SeededRng) -> int:
	var alt: int = 0
	if rng.chance(0.5):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if rng.chance(0.5):
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	return alt
