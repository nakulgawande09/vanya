class_name PickupPool
extends Node2D
## Pooled meat and spirit drops: they bounce out of a fallen beast, then the hunter's magnet
## pulls them in (Blight beasts board: "Meat drop · bounce 3 · magnet trail").

signal collected(kind: StringName, amount: int)

const PER_KIND: int = 24
const MAGNET_RANGE: float = 80.0
const MAGNET_SPEED: float = 420.0
const COLLECT_RANGE: float = 14.0
const BOUNCE_TIME: float = 0.45

var _nodes: Array[Node2D] = []
var _kinds: Array[StringName] = []
var _active: PackedByteArray = PackedByteArray()
var _vel: PackedVector2Array = PackedVector2Array()
var _t: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(emissive_layer: Node, run_seed: int) -> void:
	_rng.seed = run_seed
	for kind: StringName in [Ids.MEAT, Ids.SPIRIT]:
		var scene: PackedScene = ThemeRegistry.visual_for(kind)
		for i: int in PER_KIND:
			var n: Node2D = scene.instantiate() as Node2D
			n.scale = Vector2(0.55, 0.55)
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = false
			add_child(n)
			if kind == Ids.SPIRIT:
				Emissive.lift(n, emissive_layer)
			_nodes.append(n)
			_kinds.append(kind)
	_active.resize(_nodes.size())
	_vel.resize(_nodes.size())
	_t.resize(_nodes.size())


func drop(kind: StringName, at: Vector2, count: int) -> void:
	for c: int in count:
		for i: int in _nodes.size():
			if _active[i] == 0 and _kinds[i] == kind:
				_active[i] = 1
				_t[i] = 0.0
				_vel[i] = Vector2.from_angle(_rng.randf_range(0, TAU)) * _rng.randf_range(40.0, 90.0)
				_nodes[i].position = at
				_nodes[i].visible = true
				_nodes[i].process_mode = Node.PROCESS_MODE_INHERIT
				break


func clear() -> void:
	for i: int in _nodes.size():
		_park(i)


func tick(delta: float, hunter: Vector2) -> void:
	for i: int in _nodes.size():
		if _active[i] == 0:
			continue
		_t[i] += delta
		var n: Node2D = _nodes[i]
		var to_h: Vector2 = hunter - n.position
		var d: float = to_h.length()
		if _t[i] > BOUNCE_TIME and d < MAGNET_RANGE:
			n.position += to_h / maxf(d, 0.001) * minf(d, MAGNET_SPEED * delta)
			if d < COLLECT_RANGE:
				collected.emit(_kinds[i], 1)
				_park(i)
		elif _t[i] <= BOUNCE_TIME:
			n.position += _vel[i] * delta
			_vel[i] *= 0.9


func _park(i: int) -> void:
	_active[i] = 0
	_nodes[i].visible = false
	_nodes[i].process_mode = Node.PROCESS_MODE_DISABLED
