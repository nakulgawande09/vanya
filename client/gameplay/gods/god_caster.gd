class_name GodCaster
extends Node2D
## Calls the battle gods with spirit (Gods board):
## Meghra, the Storm Mother — lightning strikes the six nearest beasts; pale-blue flash.
## Dhoru, the Stone Bull — a stampede shockwave hurls every beast back and wipes blight orbs.
## Vayli, the Vine Keeper — heals the hunter for 35 and roots nearby beasts in vines for 3 s.
## Lives on the emissive layer: gods are light.

signal cast(god: StringName)
signal flash(color: Color)

const BOLTS: int = 6
const APPARITION_TIME: float = 1.1
const RING_TIME: float = 0.5

var world: CombatWorld
var defs: Dictionary[StringName, GodDef] = {}
var cooldowns: Dictionary[StringName, float] = {}
var _bolts: Array[Line2D] = []
var _bolt_t: float = 0.0
var _ring: Line2D
var _ring_t: float = -1.0
var _ring_radius: float = 0.0
var _apparitions: Dictionary[StringName, Node2D] = {}
var _apparition_t: float = -1.0
var _current: StringName = &""
var _near: PackedInt32Array = PackedInt32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(combat: CombatWorld) -> void:
	world = combat
	_near.resize(48)
	for id: StringName in GameData.GODS:
		defs[id] = GameData.god(id)
		cooldowns[id] = 0.0
		var scene: PackedScene = ThemeRegistry.visual_for(id)
		if scene != null:
			var a: Node2D = scene.instantiate() as Node2D
			a.visible = false
			a.scale = Vector2(0.6, 0.6)
			add_child(a)
			_apparitions[id] = a
	for i: int in BOLTS:
		var b: Line2D = Line2D.new()
		b.width = 4.0
		b.default_color = ThemeRegistry.color(&"storm_sky", Color("#8FD3FF"))
		b.visible = false
		add_child(b)
		_bolts.append(b)
	_ring = Line2D.new()
	_ring.closed = true
	_ring.width = 6.0
	_ring.visible = false
	add_child(_ring)


func can_cast(id: StringName) -> bool:
	return cooldowns.has(id) and cooldowns[id] <= 0.0 and world.run.spirit >= defs[id].spirit_cost and not world.run.is_dead()


func cooldown_fraction(id: StringName) -> float:
	return clampf(cooldowns[id] / defs[id].cooldown, 0.0, 1.0) if cooldowns.has(id) else 0.0


func try_cast(id: StringName) -> bool:
	if not can_cast(id) or not world.run.spend_spirit(defs[id].spirit_cost):
		return false
	var def: GodDef = defs[id]
	cooldowns[id] = def.cooldown
	var at: Vector2 = world.hunter_position()
	match def.effect:
		GodDef.Effect.STORM:
			_storm(def, at)
		GodDef.Effect.STAMPEDE:
			_stampede(def, at)
		GodDef.Effect.VINES:
			_vines(def, at)
	_show_apparition(id, at)
	cast.emit(id)
	return true


func tick(delta: float) -> void:
	for id: StringName in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	if _bolt_t > 0.0:
		_bolt_t -= delta
		for b: Line2D in _bolts:
			b.modulate.a = clampf(_bolt_t / 0.25, 0.0, 1.0)
			b.visible = b.visible and _bolt_t > 0.0
	if _ring_t >= 0.0:
		_ring_t += delta
		var k: float = _ring_t / RING_TIME
		_set_ring(_ring.position, lerpf(20.0, _ring_radius, ease(k, 0.4)))
		_ring.modulate.a = 1.0 - k
		if k >= 1.0:
			_ring_t = -1.0
			_ring.visible = false
	if _apparition_t >= 0.0:
		_apparition_t += delta
		var a: Node2D = _apparitions.get(_current)
		if a != null:
			a.modulate.a = 1.0 - maxf(0.0, _apparition_t - 0.6) / 0.5
			a.position.y -= delta * 20.0
			if _apparition_t >= APPARITION_TIME:
				a.visible = false
				_apparition_t = -1.0


func _storm(def: GodDef, at: Vector2) -> void:
	var targets: Array[int] = world.nearest_handles(at, def.targets)
	var top: float = at.y - 460.0
	for i: int in _bolts.size():
		var b: Line2D = _bolts[i]
		b.visible = i < targets.size()
		if not b.visible:
			continue
		var to: Vector2 = world.handle_position(targets[i])
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 7
		for s: int in steps + 1:
			var k: float = float(s) / steps
			var p: Vector2 = Vector2(to.x, top).lerp(to, k)
			if s > 0 and s < steps:
				p.x += _rng.randf_range(-14.0, 14.0)
			pts.append(p)
		b.points = pts
		world.hit(targets[i], Damage.scaled(def.damage, world.damage_bonus), Vector2.DOWN, DamageNumbers.Kind.GOD)
	_bolt_t = 0.35
	flash.emit(Color(ThemeRegistry.color(&"storm_sky", Color("#8FD3FF")), 0.35))
	world.shake(5.0)


func _stampede(def: GodDef, at: Vector2) -> void:
	var n: int = world.enemies_near(at, def.radius, _near)
	for k: int in n:
		var h: int = _near[k]
		var dir: Vector2 = (world.handle_position(h) - at).normalized()
		world.hit(h, Damage.scaled(def.damage, world.damage_bonus), dir, DamageNumbers.Kind.GOD)
		world.push(h, dir * def.knockback)
	world.projectiles.clear_orbs()
	_start_ring(at, def.radius, ThemeRegistry.color(&"rice_white", Color.WHITE))
	world.shake(7.0)


func _vines(def: GodDef, at: Vector2) -> void:
	var healed: int = world.run.heal(def.heal)
	world.numbers.show_number(at + Vector2(0, -90), healed, DamageNumbers.Kind.HEAL)
	var n: int = world.enemies_near(at, def.radius, _near)
	for k: int in n:
		world.root(_near[k], def.root_time)
	_start_ring(at, def.radius, ThemeRegistry.color(&"spirit_jade", Color("#6FF2B0")))


func _start_ring(at: Vector2, radius: float, c: Color) -> void:
	_ring.default_color = c
	_ring.position = at
	_ring_radius = radius
	_ring_t = 0.0
	_ring.visible = true


func _set_ring(at: Vector2, radius: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 40:
		pts.append(Vector2.from_angle(TAU * i / 40.0) * radius)
	_ring.points = pts
	_ring.position = at


func _show_apparition(id: StringName, at: Vector2) -> void:
	for a: Node2D in _apparitions.values():
		a.visible = false
	var a: Node2D = _apparitions.get(id)
	if a == null:
		return
	_current = id
	a.position = at + Vector2(0, -70)
	a.modulate.a = 1.0
	a.visible = true
	_apparition_t = 0.0
