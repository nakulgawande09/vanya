class_name SwarmSim
extends RefCounted
## Struct-of-arrays simulation for swarm units (Rotlings): seek the hunter, keep apart, lunge,
## get knocked back or rooted, die. One tick per physics step; no per-unit nodes, no allocations
## after construction (docs/standards.md §A.7). Rendering reads the arrays (SwarmRenderer).

enum State { FREE, SPAWN, RUN, LUNGE, DYING }

const SPAWN_TIME: float = 0.4
const LUNGE_TIME: float = 0.35
const LUNGE_COOLDOWN: float = 1.2
const LUNGE_SPEED_MULT: float = 2.2
const DEATH_TIME: float = 0.42
const KNOCK_DECAY: float = 6.0

var capacity: int
var alive: int = 0
var pos: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var knock: PackedVector2Array = PackedVector2Array()
var lunge_dir: PackedVector2Array = PackedVector2Array()
var hp: PackedInt32Array = PackedInt32Array()
var state: PackedByteArray = PackedByteArray()
var state_t: PackedFloat32Array = PackedFloat32Array()
var anim_t: PackedFloat32Array = PackedFloat32Array()
var cooldown: PackedFloat32Array = PackedFloat32Array()
var root_t: PackedFloat32Array = PackedFloat32Array()
var flash_t: PackedFloat32Array = PackedFloat32Array()
## Indices that finished dying this tick (for drops), valid until the next tick.
var died: PackedInt32Array = PackedInt32Array()
var died_count: int = 0

var radius: float
var speed: float
var lunge_range: float
var bounds: Rect2

var _neighbours: PackedInt32Array = PackedInt32Array()


func _init(max_units: int, unit_radius: float, move_speed: float, room_bounds: Rect2) -> void:
	capacity = max_units
	radius = unit_radius
	speed = move_speed
	lunge_range = unit_radius * 3.0
	bounds = room_bounds
	pos.resize(max_units)
	vel.resize(max_units)
	knock.resize(max_units)
	lunge_dir.resize(max_units)
	hp.resize(max_units)
	state.resize(max_units)
	state_t.resize(max_units)
	anim_t.resize(max_units)
	cooldown.resize(max_units)
	root_t.resize(max_units)
	flash_t.resize(max_units)
	died.resize(max_units)
	_neighbours.resize(8)


## Returns the unit index, or -1 when the swarm is full.
func spawn(at: Vector2, max_hp: int, anim_offset: float = 0.0) -> int:
	for i: int in capacity:
		if state[i] == State.FREE:
			pos[i] = at
			vel[i] = Vector2.ZERO
			knock[i] = Vector2.ZERO
			hp[i] = max_hp
			state[i] = State.SPAWN
			state_t[i] = 0.0
			anim_t[i] = anim_offset
			cooldown[i] = LUNGE_COOLDOWN * 0.5
			root_t[i] = 0.0
			flash_t[i] = 0.0
			alive += 1
			return i
	return -1


func is_active(i: int) -> bool:
	return state[i] != State.FREE and state[i] != State.DYING


## Applies damage; returns true if this hit killed the unit.
func damage(i: int, amount: int) -> bool:
	if not is_active(i):
		return false
	hp[i] -= amount
	flash_t[i] = 0.06
	if hp[i] <= 0:
		state[i] = State.DYING
		state_t[i] = 0.0
		anim_t[i] = 0.0
		return true
	return false


func push(i: int, impulse: Vector2) -> void:
	if is_active(i):
		knock[i] += impulse


func root(i: int, seconds: float) -> void:
	if is_active(i):
		root_t[i] = maxf(root_t[i], seconds)


## Advances every unit. `grid` holds this tick's swarm units (handle = unit index) for separation.
## Returns how many units touch the target this tick (contact hits).
func tick(delta: float, target: Vector2, target_radius: float, grid: SpatialHash) -> int:
	died_count = 0
	var contacts: int = 0
	var touch: float = radius + target_radius
	for i: int in capacity:
		var s: int = state[i]
		if s == State.FREE:
			continue
		state_t[i] += delta
		anim_t[i] += delta
		flash_t[i] = maxf(0.0, flash_t[i] - delta)
		if s == State.DYING:
			if state_t[i] >= DEATH_TIME:
				state[i] = State.FREE
				alive -= 1
				died[died_count] = i
				died_count += 1
			continue
		if s == State.SPAWN:
			if state_t[i] >= SPAWN_TIME:
				state[i] = State.RUN
				state_t[i] = 0.0
			continue
		cooldown[i] = maxf(0.0, cooldown[i] - delta)
		root_t[i] = maxf(0.0, root_t[i] - delta)
		var to_target: Vector2 = target - pos[i]
		var dist: float = to_target.length()
		var dir: Vector2 = to_target / dist if dist > 0.001 else Vector2.ZERO
		var desired: Vector2 = Vector2.ZERO
		if s == State.LUNGE:
			desired = lunge_dir[i] * speed * LUNGE_SPEED_MULT
			if state_t[i] >= LUNGE_TIME:
				state[i] = State.RUN
				state_t[i] = 0.0
				cooldown[i] = LUNGE_COOLDOWN
		else:
			desired = dir * speed
			if dist < lunge_range and cooldown[i] <= 0.0:
				state[i] = State.LUNGE
				state_t[i] = 0.0
				anim_t[i] = 0.0
				lunge_dir[i] = dir
		desired += _separation(i, grid) * speed
		if root_t[i] > 0.0:
			desired = Vector2.ZERO
		vel[i] = vel[i].lerp(desired, minf(1.0, delta * 10.0))
		knock[i] = knock[i] * maxf(0.0, 1.0 - KNOCK_DECAY * delta)
		var p: Vector2 = pos[i] + (vel[i] + knock[i]) * delta
		pos[i] = Vector2(clampf(p.x, bounds.position.x + radius, bounds.end.x - radius),
				clampf(p.y, bounds.position.y + radius, bounds.end.y - radius))
		if dist < touch:
			contacts += 1
	return contacts


func _separation(i: int, grid: SpatialHash) -> Vector2:
	var push_v: Vector2 = Vector2.ZERO
	var n: int = grid.query_circle(pos[i], radius, _neighbours)
	for k: int in n:
		var j: int = _neighbours[k]
		if j == i or j >= capacity:
			continue  # self, or a non-swarm handle sharing the broadphase
		var away: Vector2 = pos[i] - pos[j]
		var d: float = away.length()
		if d > 0.001:
			push_v += away / d * (1.0 - d / (radius * 2.0))
		else:
			push_v += Vector2(1.0 if i > j else -1.0, 0.0)
	return push_v.limit_length(1.0)
