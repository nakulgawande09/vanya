class_name Cage
extends Node2D
## A caged animal (Guides board): stand close for 0.9 s to free it — a jade ring fills — then the
## bars scatter, +3 spirit rises, and a bird or firefly jar may join the run as a guide.

signal freed(cage: Cage)

const FREE_TIME: float = 0.9
const RANGE: float = 46.0
const SPIRIT_REWARD: int = 3

var kind: StringName = Ids.CAGE_BIRD
var progress: float = 0.0
var is_free: bool = false
var _visual: Node2D
var _jade: Color = Color("#6FF2B0")


func setup(cage_kind: StringName) -> void:
	kind = cage_kind
	_jade = ThemeRegistry.color(&"spirit_jade", _jade)
	_visual = ThemeRegistry.visual_for(kind).instantiate() as Node2D
	add_child(_visual)


## Returns true on the tick the animal is freed.
func tick(delta: float, hunter: Vector2) -> bool:
	if is_free:
		_visual.modulate.a = maxf(0.0, _visual.modulate.a - delta * 2.0)
		_visual.scale = _visual.scale * (1.0 + delta)
		return false
	var near: bool = position.distance_to(hunter) <= RANGE
	var before: float = progress
	progress = clampf(progress + (delta if near else -delta * 2.0), 0.0, FREE_TIME)
	if progress != before:
		queue_redraw()
	if progress >= FREE_TIME:
		is_free = true
		queue_redraw()
		freed.emit(self)
		return true
	return false


func _draw() -> void:
	if is_free or progress <= 0.0:
		return
	draw_arc(Vector2(0, -26), 34.0, -PI / 2, -PI / 2 + TAU * progress / FREE_TIME, 40, _jade, 4.0, true)
