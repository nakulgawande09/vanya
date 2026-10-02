class_name ProjectileManager
extends Node2D
## Pooled arrows (player) and blight orbs (wisps) as struct-of-arrays, drawn with one MultiMesh each.
## Arrows test against the combat world's spatial hash; orbs test against the hunter.

signal arrow_hit(handle: int, damage: int, direction: Vector2)

const ARROWS: int = 64
const ORBS: int = 32
const ARROW_RADIUS: float = 5.0
const ORB_RADIUS: float = 7.0
const ARROW_LIFE: float = 0.9
const ORB_LIFE: float = 3.5

var _a_pos: PackedVector2Array = PackedVector2Array()
var _a_vel: PackedVector2Array = PackedVector2Array()
var _a_life: PackedFloat32Array = PackedFloat32Array()
var _a_damage: PackedInt32Array = PackedInt32Array()
var _a_pierce: PackedInt32Array = PackedInt32Array()
var _a_last_hit: PackedInt32Array = PackedInt32Array()
var _o_pos: PackedVector2Array = PackedVector2Array()
var _o_vel: PackedVector2Array = PackedVector2Array()
var _o_life: PackedFloat32Array = PackedFloat32Array()
var _o_damage: PackedInt32Array = PackedInt32Array()
var _arrow_mm: MultiMeshInstance2D
var _trail_mm: MultiMeshInstance2D
var _orb_mm: MultiMeshInstance2D
## Two fading ghosts behind each arrow (High / Medium rungs only).
var trails: bool = true
var _hits: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_a_pos.resize(ARROWS)
	_a_vel.resize(ARROWS)
	_a_life.resize(ARROWS)
	_a_damage.resize(ARROWS)
	_a_pierce.resize(ARROWS)
	_a_last_hit.resize(ARROWS)
	_o_pos.resize(ORBS)
	_o_vel.resize(ORBS)
	_o_life.resize(ORBS)
	_o_damage.resize(ORBS)
	_hits.resize(4)


func setup(arrow_texture: Texture2D, orb_texture: Texture2D, emissive_layer: Node) -> void:
	_trail_mm = _make(arrow_texture, ARROWS * 2, true)
	add_child(_trail_mm)
	_arrow_mm = _make(arrow_texture, ARROWS)
	add_child(_arrow_mm)
	_orb_mm = _make(orb_texture, ORBS)
	# Orbs glow (blight emits light), so they draw above the darkness.
	if emissive_layer != null:
		emissive_layer.add_child(_orb_mm)
	else:
		add_child(_orb_mm)


func set_arrow_texture(tex: Texture2D) -> void:
	for mmi: MultiMeshInstance2D in [_arrow_mm, _trail_mm]:
		mmi.texture = tex
		(mmi.multimesh.mesh as QuadMesh).size = tex.get_size() / 3.0


func fire_arrow(from: Vector2, direction: Vector2, speed: float, damage: int, pierce: int) -> void:
	for i: int in ARROWS:
		if _a_life[i] <= 0.0:
			_a_pos[i] = from
			_a_vel[i] = direction.normalized() * speed
			_a_life[i] = ARROW_LIFE
			_a_damage[i] = damage
			_a_pierce[i] = pierce
			_a_last_hit[i] = -1
			return


func fire_orb(from: Vector2, direction: Vector2, speed: float, damage: int) -> void:
	for i: int in ORBS:
		if _o_life[i] <= 0.0:
			_o_pos[i] = from
			_o_vel[i] = direction.normalized() * speed
			_o_life[i] = ORB_LIFE
			_o_damage[i] = damage
			return


## Removes every orb (Dhoru's stampede wipes blight orbs from the air).
func clear_orbs() -> void:
	_o_life.fill(0.0)


func clear_all() -> void:
	_a_life.fill(0.0)
	_o_life.fill(0.0)
	_sync()


## Active orb positions, for light holes. Returns how many were written into `out`.
func orb_positions(out: PackedVector2Array) -> int:
	var n: int = 0
	for i: int in ORBS:
		if _o_life[i] > 0.0 and n < out.size():
			out[n] = _o_pos[i]
			n += 1
	return n


## Moves everything one step. Returns total orb damage dealt to the hunter this tick.
func tick(delta: float, grid: SpatialHash, bounds: Rect2, hunter_pos: Vector2, hunter_radius: float) -> int:
	for i: int in ARROWS:
		if _a_life[i] <= 0.0:
			continue
		_a_life[i] -= delta
		_a_pos[i] += _a_vel[i] * delta
		if not bounds.has_point(_a_pos[i]):
			_a_life[i] = 0.0
			continue
		var n: int = grid.query_circle(_a_pos[i], ARROW_RADIUS, _hits)
		for k: int in n:
			var h: int = _hits[k]
			if h == _a_last_hit[i]:
				continue
			_a_last_hit[i] = h
			arrow_hit.emit(h, _a_damage[i], _a_vel[i].normalized())
			_a_pierce[i] -= 1
			if _a_pierce[i] < 0:
				_a_life[i] = 0.0
			break
	var orb_damage: int = 0
	var touch: float = ORB_RADIUS + hunter_radius
	for i: int in ORBS:
		if _o_life[i] <= 0.0:
			continue
		_o_life[i] -= delta
		_o_pos[i] += _o_vel[i] * delta
		if not bounds.has_point(_o_pos[i]):
			_o_life[i] = 0.0
		elif _o_pos[i].distance_squared_to(hunter_pos) <= touch * touch:
			orb_damage += _o_damage[i]
			_o_life[i] = 0.0
	_sync()
	return orb_damage


func _sync() -> void:
	var am: MultiMesh = _arrow_mm.multimesh
	var tm: MultiMesh = _trail_mm.multimesh
	var hidden: Transform2D = Transform2D(0.0, Vector2(-9999, -9999))
	for i: int in ARROWS:
		if _a_life[i] > 0.0:
			var angle: float = _a_vel[i].angle()
			am.set_instance_transform_2d(i, Transform2D(angle, _a_pos[i]))
			if trails:
				tm.set_instance_transform_2d(i * 2, Transform2D(angle, _a_pos[i] - _a_vel[i] * 0.018))
				tm.set_instance_transform_2d(i * 2 + 1, Transform2D(angle, _a_pos[i] - _a_vel[i] * 0.036))
				tm.set_instance_color(i * 2, Color(1, 1, 1, 0.45))
				tm.set_instance_color(i * 2 + 1, Color(1, 1, 1, 0.2))
			else:
				tm.set_instance_transform_2d(i * 2, hidden)
				tm.set_instance_transform_2d(i * 2 + 1, hidden)
		else:
			am.set_instance_transform_2d(i, hidden)
			tm.set_instance_transform_2d(i * 2, hidden)
			tm.set_instance_transform_2d(i * 2 + 1, hidden)
	var om: MultiMesh = _orb_mm.multimesh
	for i: int in ORBS:
		if _o_life[i] > 0.0:
			om.set_instance_transform_2d(i, Transform2D(_o_vel[i].angle(), _o_pos[i]))
		else:
			om.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-9999, -9999)))


func _make(tex: Texture2D, count: int, colors: bool = false) -> MultiMeshInstance2D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = tex.get_size() / 3.0
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = colors
	mm.mesh = quad
	mm.instance_count = count
	var inst: MultiMeshInstance2D = MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	var flip: ShaderMaterial = ShaderMaterial.new()
	flip.shader = preload("res://gameplay/projectiles/quad_flip.gdshader")
	inst.material = flip
	for i: int in count:
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-9999, -9999)))
	return inst
