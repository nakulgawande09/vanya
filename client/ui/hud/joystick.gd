class_name FloatingJoystick
extends Control
## Movement stick (Grove mock), tuned from FeelTuning (feel-test #1–#3):
## - FIXED: the base stays at its rest spot; a touch anywhere in the zone steers from there.
## - DYNAMIC: the base appears where the thumb lands (the default).
## - FOLLOWING: like DYNAMIC, and the base trails the thumb once it passes the radius.
## Output goes through FeelTuning.shape_stick (dead zone, full-speed point, response curve).
## Left-handed players get it on the right side.

signal moved(vector: Vector2)

const KNOB: float = 18.0
const REST_X: float = 70.0
const REST_Y: float = 80.0

@export var left_handed: bool = false

var tuning: FeelTuning = FeelTuning.new()
var _touch: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _rest: Vector2 = Vector2.ZERO
var _ring: Color = Color(0.95, 0.92, 0.84, 0.55)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_rest()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh_rest()


func radius() -> float:
	return tuning.joystick_radius


func set_tuning(t: FeelTuning) -> void:
	tuning = t
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * t.position
		if t.pressed and _touch < 0 and _in_zone(local):
			_touch = t.index
			_origin = _rest if tuning.joystick_mode == FeelTuning.JoystickMode.FIXED else local
			_drag(local)
		elif not t.pressed and t.index == _touch:
			_touch = -1
			moved.emit(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _touch:
			_drag(get_global_transform_with_canvas().affine_inverse() * d.position)


func is_active() -> bool:
	return _touch >= 0


## Re-places the resting stick (after a resize or a hand switch).
func refresh_rest() -> void:
	_rest = Vector2(size.x - REST_X if left_handed else REST_X, size.y - REST_Y)
	queue_redraw()


func _drag(local: Vector2) -> void:
	var r: float = radius()
	var raw: Vector2 = local - _origin
	if tuning.joystick_mode == FeelTuning.JoystickMode.FOLLOWING and raw.length() > r:
		_origin = local - raw.normalized() * r
		raw = local - _origin
	var offset: Vector2 = raw.limit_length(r)
	_knob = _origin + offset
	moved.emit(tuning.shape_stick(offset / r))
	queue_redraw()


func _in_zone(p: Vector2) -> bool:
	var side_ok: bool = p.x > size.x * 0.4 if left_handed else p.x < size.x * 0.6
	return side_ok and p.y > size.y * 0.35 and p.y < size.y - 4.0


func _draw() -> void:
	var r: float = radius()
	var c: Vector2 = _origin if _touch >= 0 else _rest
	var k: Vector2 = _knob if _touch >= 0 else _rest
	draw_circle(c, r, Color(0.05, 0.03, 0.07, 0.25))
	draw_arc(c, r, 0.0, TAU, 48, _ring, 3.0, true)
	if tuning.joystick_deadzone > 0.0:
		draw_arc(c, r * tuning.joystick_deadzone, 0.0, TAU, 24, Color(_ring, 0.25), 1.0, true)
	draw_circle(k, KNOB, Color(0.95, 0.92, 0.84, 0.85 if _touch >= 0 else 0.6))
