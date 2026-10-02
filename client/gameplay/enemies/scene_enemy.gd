class_name SceneEnemy
extends Node2D
## A pooled scene-per-entity beast (tank, ranged, boss). Created at room load, parked out of
## play when dead, driven by CombatWorld.tick() — never by its own _process (standards §A.7).

signal died(enemy: SceneEnemy)

var def: ArchetypeDef
var hp: int = 0
var active: bool = false
var handle: int = -1
var visual: Node2D
var glow: Node2D
var root_t: float = 0.0
var knock: Vector2 = Vector2.ZERO
var flash_t: float = 0.0
var bounds: Rect2
var _body: Node2D


func setup(archetype: ArchetypeDef, scene: PackedScene, emissive_layer: Node, room_bounds: Rect2) -> void:
	def = archetype
	bounds = room_bounds
	visual = scene.instantiate() as Node2D
	add_child(visual)
	_body = visual.get_node_or_null("Body") as Node2D
	glow = Emissive.lift(visual, emissive_layer)
	park()


func activate(at: Vector2) -> void:
	position = at
	hp = def.max_hp
	active = true
	root_t = 0.0
	knock = Vector2.ZERO
	visible = true
	modulate = Color(1, 1, 1, 0)
	process_mode = Node.PROCESS_MODE_INHERIT
	if glow != null:
		glow.visible = true
	_on_activate()


func park() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	position = Vector2(-9999, -9999)
	if glow != null:
		glow.visible = false


## Returns true if this hit killed it.
func take_damage(amount: int, direction: Vector2) -> bool:
	if not active:
		return false
	hp -= amount
	flash_t = 0.06
	knock += direction * _knock_strength()
	if hp <= 0:
		active = false
		died.emit(self)
		return true
	return false


func push(impulse: Vector2) -> void:
	knock += impulse * _knock_strength() / 200.0


func root(seconds: float) -> void:
	root_t = maxf(root_t, seconds)


func is_rooted() -> bool:
	return root_t > 0.0


## Advances behaviour; returns contact damage dealt to the hunter this tick (0 if not touching).
func tick(delta: float, world: CombatWorld) -> int:
	modulate.a = minf(1.0, modulate.a + delta * 3.0)
	flash_t = maxf(0.0, flash_t - delta)
	if _body != null:
		_body.modulate = Color(3, 3, 3, 1) if flash_t > 0.0 else Color.WHITE
	root_t = maxf(0.0, root_t - delta)
	knock = knock * maxf(0.0, 1.0 - 6.0 * delta)
	var move: Vector2 = Vector2.ZERO if root_t > 0.0 else _behave(delta, world)
	var p: Vector2 = position + (move + knock) * delta
	var r: float = def.hitbox_radius
	position = Vector2(clampf(p.x, bounds.position.x + r, bounds.end.x - r), clampf(p.y, bounds.position.y + r, bounds.end.y - r))
	visual.scale.x = -1.0 if world.hunter_position().x < position.x else 1.0
	var touch: float = r + world.hunter_radius()
	if position.distance_squared_to(world.hunter_position()) <= touch * touch:
		return _contact_damage()
	return 0


func _on_activate() -> void:
	pass


## Returns the desired velocity for this tick.
func _behave(_delta: float, world: CombatWorld) -> Vector2:
	return (world.hunter_position() - position).normalized() * def.move_speed


func _contact_damage() -> int:
	return def.contact_damage


func _knock_strength() -> float:
	return 120.0
