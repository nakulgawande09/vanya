class_name CombatWorld
extends Node2D
## Owns everything that fights in a room and ticks it in a fixed order (standards §A.7):
## broadphase → swarm → scene enemies → projectiles → pickups → effects → render sync.
## Enemies are addressed by handle: swarm unit i → i, pooled scene enemy j → SCENE_BASE + j.

signal enemy_killed(archetype: StringName, at: Vector2)
signal shake_requested(amount: float)

const SWARM_CAPACITY: int = 40
const SCENE_BASE: int = 1000
const POOL_SIZES: Dictionary[StringName, int] = {&"thornback": 6, &"wisp": 6, &"rotheart": 1}
const SPAWN_JITTER: float = 18.0

var bounds: Rect2
var run: RunState
var hunter: Player
var damage_bonus: float = 0.0
var projectiles: ProjectileManager
var pickups: PickupPool
var fx: FxPool
var numbers: DamageNumbers
var swarm: SwarmSim
var swarm_renderer: SwarmRenderer
## Room pathing shared by every beast; rebuilt per room from the RoomPlan.
var field: FlowField = FlowField.new(RoomPlan.COLS, RoomPlan.ROWS, RoomPlan.TILE)
var defs: Dictionary[StringName, ArchetypeDef] = {}
var enemies: Array[SceneEnemy] = []
var _grid: SpatialHash
var _rng: SeededRng
var _quality: QualityProfile
var _scratch: PackedInt32Array = PackedInt32Array()


func setup(room_bounds: Rect2, layers: Dictionary, the_run: RunState, the_hunter: Player, bonus: float, run_seed: int) -> void:
	bounds = room_bounds
	run = the_run
	hunter = the_hunter
	damage_bonus = bonus
	defs = GameData.archetypes()
	_rng = SeededRng.new(run_seed, 0, &"combat")
	_scratch.resize(48)
	var emissive: Node = layers.get("emissive")
	var decals: Node2D = layers.get("decals")
	var entities: Node2D = layers.get("entities")
	_grid = SpatialHash.new(bounds, 64.0, SWARM_CAPACITY + 16)
	var rot: ArchetypeDef = defs[Ids.ROTLING]
	swarm = SwarmSim.new(SWARM_CAPACITY, rot.hitbox_radius, rot.move_speed, bounds)
	swarm.field = field
	swarm_renderer = SwarmRenderer.new()
	swarm_renderer.name = "Swarm"
	entities.add_child(swarm_renderer)
	swarm_renderer.setup(swarm, Ids.ROTLING, emissive)
	for id: StringName in POOL_SIZES:
		var scene: PackedScene = ThemeRegistry.visual_for(id)
		for i: int in POOL_SIZES[id]:
			var e: SceneEnemy = _make_enemy(id)
			e.name = "%s_%d" % [id, i]
			entities.add_child(e)
			e.setup(defs[id], scene, emissive, bounds)
			e.handle = SCENE_BASE + enemies.size()
			e.died.connect(_on_scene_enemy_died)
			enemies.append(e)
	projectiles = ProjectileManager.new()
	projectiles.name = "Projectiles"
	entities.add_child(projectiles)
	projectiles.setup(ThemeRegistry.texture_for(&"arrow_stone"), ThemeRegistry.texture_for(&"wisp_orb"), emissive)
	projectiles.arrow_hit.connect(_on_arrow_hit)
	pickups = PickupPool.new()
	pickups.name = "Pickups"
	entities.add_child(pickups)
	pickups.setup(emissive, run_seed)
	pickups.collected.connect(_on_collected)
	fx = FxPool.new()
	fx.name = "Fx"
	entities.add_child(fx)
	fx.setup(decals)
	numbers = DamageNumbers.new()
	numbers.name = "Numbers"
	emissive.add_child(numbers)
	set_quality(AdaptiveQuality.profile)


func set_quality(profile: QualityProfile) -> void:
	_quality = profile
	swarm_renderer.set_quality(profile)


## Loads a room's passability (logs, idols, roots) into the shared flow field.
func set_room(plan: RoomPlan) -> void:
	field.set_grid(plan.flow_codes())


## Spawns an archetype at a point (portal). Returns false if its pool is exhausted.
func spawn(id: StringName, at: Vector2) -> bool:
	at = field.nearest_free(at)
	var jitter: Vector2 = Vector2(_rng.next_float() - 0.5, _rng.next_float() - 0.5) * SPAWN_JITTER * 2.0
	if field.is_blocked(at + jitter):
		jitter = Vector2.ZERO
	if id == Ids.ROTLING:
		if swarm.alive >= mini(SWARM_CAPACITY, _quality.max_enemies):
			return false
		return swarm.spawn(at + jitter, defs[id].max_hp, _rng.next_float()) >= 0
	for e: SceneEnemy in enemies:
		if not e.active and e.def.id == id and not e.visible:
			e.activate(at + jitter)
			return true
	return false


## Boss summons ignore the room's wave count.
func summon(id: StringName, at: Vector2) -> void:
	spawn(id, Vector2(clampf(at.x, bounds.position.x + 20, bounds.end.x - 20), clampf(at.y, bounds.position.y + 20, bounds.end.y - 20)))


func alive_count() -> int:
	var n: int = swarm.alive
	for e: SceneEnemy in enemies:
		if e.active:
			n += 1
	return n


func boss() -> RotheartBoss:
	for e: SceneEnemy in enemies:
		if e is RotheartBoss and e.active:
			return e as RotheartBoss
	return null


func hunter_position() -> Vector2:
	return hunter.global_position


func hunter_radius() -> float:
	return hunter.hitbox_radius


func nearest_enemy(from: Vector2, max_range: float) -> int:
	return _grid.nearest(from, max_range)


func is_alive(handle: int) -> bool:
	if handle < 0:
		return false
	if handle < SCENE_BASE:
		return swarm.is_active(handle)
	return enemies[handle - SCENE_BASE].active


func handle_position(handle: int) -> Vector2:
	if handle < SCENE_BASE:
		return swarm.pos[handle]
	var e: SceneEnemy = enemies[handle - SCENE_BASE]
	return e.position - Vector2(0, e.def.hitbox_radius * 0.6)


## Handles of live enemies within `radius`. Returns how many were written into `out`.
func enemies_near(center: Vector2, radius: float, out: PackedInt32Array) -> int:
	return _grid.query_circle(center, radius, out)


## Up to `count` live handles nearest to `from`, nearest first (Meghra's six bolts).
func nearest_handles(from: Vector2, count: int) -> Array[int]:
	var all: Array[Vector2] = []  # x = distance², y = handle
	for i: int in swarm.capacity:
		if swarm.is_active(i):
			all.append(Vector2(from.distance_squared_to(swarm.pos[i]), i))
	for e: SceneEnemy in enemies:
		if e.active:
			all.append(Vector2(from.distance_squared_to(e.position), e.handle))
	all.sort()
	var out: Array[int] = []
	for k: int in mini(count, all.size()):
		out.append(int(all[k].y))
	return out


func hit(handle: int, amount: int, direction: Vector2, kind: DamageNumbers.Kind = DamageNumbers.Kind.HIT) -> void:
	if not is_alive(handle):
		return
	var at: Vector2 = handle_position(handle)
	var dealt: int = amount
	if handle < SCENE_BASE:
		swarm.push(handle, direction * 140.0)
		if swarm.damage(handle, amount):
			_on_killed(Ids.ROTLING, swarm.pos[handle])
	else:
		var e: SceneEnemy = enemies[handle - SCENE_BASE]
		if e is RotheartBoss and (e as RotheartBoss).is_stunned():
			dealt = amount * Damage.WEAK_POINT_MULT
		e.take_damage(amount, direction)
	numbers.show_number(at + Vector2(0, -14), dealt, kind)
	fx.play(&"hit_spark", at, 1.0)


func push(handle: int, impulse: Vector2) -> void:
	if handle < SCENE_BASE:
		swarm.push(handle, impulse)
	elif is_alive(handle):
		enemies[handle - SCENE_BASE].push(impulse)


func root(handle: int, seconds: float) -> void:
	if handle < SCENE_BASE:
		swarm.root(handle, seconds)
	elif is_alive(handle):
		enemies[handle - SCENE_BASE].root(seconds)


func shake(amount: float) -> void:
	if _quality == null or _quality.screen_shake:
		shake_requested.emit(amount)


func clear() -> void:
	for i: int in swarm.capacity:
		if swarm.state[i] != SwarmSim.State.FREE:
			swarm.state[i] = SwarmSim.State.FREE
	swarm.alive = 0
	for e: SceneEnemy in enemies:
		e.park()
	projectiles.clear_all()
	pickups.clear()
	fx.clear()
	numbers.clear()
	swarm_renderer.sync(hunter_position())


## One fixed-order step. Returns damage the hunter should take (contacts + orbs), before i-frames.
func tick(delta: float) -> int:
	_grid.clear()
	for i: int in swarm.capacity:
		if swarm.is_active(i):
			_grid.insert(i, swarm.pos[i], swarm.radius)
	for e: SceneEnemy in enemies:
		if e.active:
			_grid.insert(e.handle, e.position, e.def.hitbox_radius)
	_grid.commit()
	var hp: Vector2 = hunter_position()
	field.update(delta, hp)
	var incoming: int = 0
	var contacts: int = swarm.tick(delta, hp, hunter_radius(), _grid)
	if contacts > 0:
		incoming += defs[Ids.ROTLING].contact_damage
	for e: SceneEnemy in enemies:
		if e.active:
			incoming = maxi(incoming, e.tick(delta, self))
		elif e.visible:
			e.modulate.a -= delta * 3.0
			if e.modulate.a <= 0.0:
				e.park()
	incoming += projectiles.tick(delta, _grid, bounds.grow(40.0), hp, hunter_radius())
	pickups.tick(delta, hp)
	fx.tick(delta)
	numbers.tick(delta)
	swarm_renderer.sync(hp)
	return incoming


func _make_enemy(id: StringName) -> SceneEnemy:
	match id:
		&"thornback":
			return ThornbackEnemy.new()
		&"wisp":
			return WispEnemy.new()
		&"rotheart":
			return RotheartBoss.new()
	return SceneEnemy.new()


func _on_arrow_hit(handle: int, amount: int, direction: Vector2) -> void:
	hit(handle, amount, direction)


func _on_scene_enemy_died(e: SceneEnemy) -> void:
	_on_killed(e.def.id, e.position)
	if e is RotheartBoss:
		shake(10.0)


func _on_killed(id: StringName, at: Vector2) -> void:
	var def: ArchetypeDef = defs[id]
	run.register_kill()
	fx.play(&"ash_burst", at, 1.0)
	fx.play(&"rot_stain", at + Vector2(0, 4), 1.0)
	var meat_pickups: int = mini(def.meat_drop, 8)
	pickups.drop(Ids.MEAT, at, meat_pickups)
	if def.meat_drop > meat_pickups:
		run.add_meat(def.meat_drop - meat_pickups)
	if _rng.chance(def.spirit_chance):
		pickups.drop(Ids.SPIRIT, at, 1 if def.role != ArchetypeDef.Role.BOSS else 5)
	enemy_killed.emit(id, at)


func _on_collected(kind: StringName, amount: int) -> void:
	if kind == Ids.MEAT:
		run.add_meat(amount)
	else:
		run.add_spirit(amount)
