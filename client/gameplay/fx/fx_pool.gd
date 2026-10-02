class_name FxPool
extends Node2D
## Pooled one-shot effects from the theme: hit sparks, ash bursts on death, rot stains on the floor
## (Blight beasts board). Each effect scales/fades over its life; stains linger for 20 s.

const SIZES: Dictionary[StringName, int] = {&"hit_spark": 12, &"ash_burst": 10, &"rot_stain": 16}
const LIFE: Dictionary[StringName, float] = {&"hit_spark": 0.18, &"ash_burst": 0.42, &"rot_stain": 20.0}

var _nodes: Array[Node2D] = []
var _kinds: Array[StringName] = []
var _t: PackedFloat32Array = PackedFloat32Array()
var _stains: Node2D


func setup(decal_layer: Node2D) -> void:
	_stains = decal_layer
	for kind: StringName in SIZES:
		var scene: PackedScene = ThemeRegistry.prop_for(kind)
		if scene == null:
			continue
		for i: int in SIZES[kind]:
			var n: Node2D = scene.instantiate() as Node2D
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
			(decal_layer if kind == &"rot_stain" else self).add_child(n)
			_nodes.append(n)
			_kinds.append(kind)
	_t.resize(_nodes.size())
	_t.fill(-1.0)


func play(kind: StringName, at: Vector2, quality_scale: float = 1.0) -> void:
	var oldest: int = -1
	for i: int in _nodes.size():
		if _kinds[i] != kind:
			continue
		if _t[i] < 0.0:
			_start(i, at, quality_scale)
			return
		if oldest < 0 or _t[i] > _t[oldest]:
			oldest = i
	if oldest >= 0 and kind == &"rot_stain":
		_start(oldest, at, quality_scale)


func clear() -> void:
	for i: int in _nodes.size():
		_t[i] = -1.0
		_nodes[i].visible = false


func tick(delta: float) -> void:
	for i: int in _nodes.size():
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		var life: float = LIFE[_kinds[i]]
		var k: float = _t[i] / life
		var n: Node2D = _nodes[i]
		if k >= 1.0:
			_t[i] = -1.0
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
			continue
		if _kinds[i] == &"rot_stain":
			n.modulate.a = 0.85 * (1.0 - maxf(0.0, k - 0.6) / 0.4)
		else:
			n.scale = Vector2.ONE * lerpf(0.6, 1.2, k)
			n.modulate.a = 1.0 - k


func _start(i: int, at: Vector2, quality_scale: float) -> void:
	_t[i] = 0.0
	var n: Node2D = _nodes[i]
	n.position = at
	n.visible = quality_scale > 0.0
	n.modulate.a = 1.0
	n.scale = Vector2.ONE * (0.6 if _kinds[i] != &"rot_stain" else 1.0)
	n.process_mode = Node.PROCESS_MODE_INHERIT
