class_name FloatingJoystick
extends Control
## Floating joystick (Grove mock): appears where the thumb lands on the movement side of the
## screen and reports a direction. Left-handed players can swap it to the right side.

signal moved(vector: Vector2)

const RADIUS: float = 50.0
const KNOB: float = 18.0

@export var left_handed: bool = false

var _touch: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _rest: Vector2 = Vector2.ZERO
var _ring: Color = Color(0.95, 0.92, 0.84, 0.55)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest = Vector2(70.0, size.y - 80.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rest = Vector2(size.x - 70.0 if left_handed else 70.0, size.y - 80.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * t.position
		if t.pressed and _touch < 0 and _in_zone(local):
			_touch = t.index
			_origin = local
			_knob = local
			queue_redraw()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			moved.emit(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index != _touch:
			return
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * d.position
		var offset: Vector2 = (local - _origin).limit_length(RADIUS)
		_knob = _origin + offset
		moved.emit(offset / RADIUS)
		queue_redraw()


func is_active() -> bool:
	return _touch >= 0


func _in_zone(p: Vector2) -> bool:
	var side_ok: bool = p.x > size.x * 0.4 if left_handed else p.x < size.x * 0.6
	return side_ok and p.y > size.y * 0.35 and p.y < size.y - 4.0


func _draw() -> void:
	var c: Vector2 = _origin if _touch >= 0 else _rest
	var k: Vector2 = _knob if _touch >= 0 else _rest
	draw_circle(c, RADIUS, Color(0.05, 0.03, 0.07, 0.25))
	draw_arc(c, RADIUS, 0.0, TAU, 48, _ring, 3.0, true)
	draw_circle(k, KNOB, Color(0.95, 0.92, 0.84, 0.85 if _touch >= 0 else 0.6))
