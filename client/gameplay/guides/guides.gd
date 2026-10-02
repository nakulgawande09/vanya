class_name Guides
extends Node2D
## Animals freed from cages who stay for the run (Guides board):
## Pira, the guide bird, flies at the shoulder and pecks the nearest beast every second.
## Jugnu, six fireflies, orbit the hunter, widen the light by about a third and slowly mend wounds
## while no beast is touching the hunter.

const PIRA_PECK: int = 6
const PIRA_RANGE: float = 140.0
const PIRA_INTERVAL: float = 1.0
const JUGNU_COUNT: int = 6
const JUGNU_LIGHT: float = 1.33
const JUGNU_REGEN_DELAY: float = 2.0
const JUGNU_REGEN_INTERVAL: float = 0.75

var world: CombatWorld
var _pira: Node2D
var _flies: Array[Node2D] = []
var _peck_t: float = 0.0
var _orbit_t: float = 0.0
var _calm_t: float = 0.0
var _regen_t: float = 0.0
var _emissive: Node


func setup(combat: CombatWorld, emissive_layer: Node) -> void:
	world = combat
	_emissive = emissive_layer


func has(id: StringName) -> bool:
	return (id == Ids.PIRA and _pira != null) or (id == Ids.JUGNU and not _flies.is_empty())


func add(id: StringName) -> void:
	if has(id):
		return
	if id == Ids.PIRA:
		_pira = ThemeRegistry.visual_for(Ids.PIRA).instantiate() as Node2D
		add_child(_pira)
		_pira.position = world.hunter_position() + Vector2(-26, -70)
	elif id == Ids.JUGNU:
		var scene: PackedScene = ThemeRegistry.visual_for(Ids.JUGNU)
		for i: int in JUGNU_COUNT:
			var f: Node2D = scene.instantiate() as Node2D
			_emissive.add_child(f)
			_flies.append(f)


func light_scale() -> float:
	return JUGNU_LIGHT if not _flies.is_empty() else 1.0


func light_points(out: Array[Vector2]) -> void:
	if _pira != null:
		out.append(_pira.position)


## `touched` is true when a beast reached the hunter this tick.
func tick(delta: float, touched: bool) -> void:
	var hunter: Vector2 = world.hunter_position()
	if _pira != null:
		var shoulder: Vector2 = hunter + Vector2(-26, -70)
		_pira.position = _pira.position.lerp(shoulder, minf(1.0, delta * 6.0))
		_peck_t -= delta
		if _peck_t <= 0.0:
			var target: int = world.nearest_enemy(hunter, PIRA_RANGE)
			if target >= 0:
				var at: Vector2 = world.handle_position(target)
				_pira.position = at + Vector2(0, -20)
				world.hit(target, PIRA_PECK, (at - hunter).normalized())
				_peck_t = PIRA_INTERVAL
	if not _flies.is_empty():
		_orbit_t += delta
		for i: int in _flies.size():
			var a: float = _orbit_t * 1.6 + TAU * i / _flies.size()
			_flies[i].position = hunter + Vector2(cos(a) * 38.0, sin(a) * 22.0 - 38.0)
		_calm_t = 0.0 if touched else _calm_t + delta
		if _calm_t >= JUGNU_REGEN_DELAY:
			_regen_t += delta
			if _regen_t >= JUGNU_REGEN_INTERVAL:
				_regen_t = 0.0
				world.run.heal(1)


func clear() -> void:
	if _pira != null:
		_pira.queue_free()
		_pira = null
	for f: Node2D in _flies:
		f.queue_free()
	_flies.clear()
