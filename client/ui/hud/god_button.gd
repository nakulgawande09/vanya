class_name GodButton
extends Control
## Round battle-god button (Screens board, HUD parts): the god's icon in a ring that lights up
## when ready; while cooling down the ring dims and the seconds left are shown.

signal pressed(god: StringName)

const SIZE: float = 54.0

var god: StringName = &""
var ring_color: Color = Color("#8FD3FF")
var ready_to_cast: bool = false
var cooldown_left: float = 0.0
var cooldown_fraction: float = 0.0
var cost: int = 0
var _icon: Texture2D
var _font: Font
var _cool: Color = Color("#3D6A4A")


func setup(god_id: StringName, ring: Color, spirit_cost: int) -> void:
	god = god_id
	ring_color = ring
	cost = spirit_cost
	_icon = ThemeRegistry.icon_for(god_id)
	_cool = ThemeRegistry.color(&"god_cooling", _cool)
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_font(&"font", &"NumberLabel")
	tooltip_text = String(god)


func set_state(is_ready: bool, left: float, fraction: float) -> void:
	if is_ready == ready_to_cast and absf(left - cooldown_left) < 0.05 and absf(fraction - cooldown_fraction) < 0.01:
		return
	ready_to_cast = is_ready
	cooldown_left = left
	cooldown_fraction = fraction
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if tap:
		pressed.emit(god)
		accept_event()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = SIZE / 2.0
	draw_circle(c, r, Color(0.05, 0.03, 0.07, 0.8))
	var ring: Color = ring_color if ready_to_cast else _cool
	draw_arc(c, r - 2.0, 0.0, TAU, 48, ring, 3.0, true)
	if cooldown_fraction > 0.0:
		draw_arc(c, r - 2.0, -PI / 2, -PI / 2 + TAU * (1.0 - cooldown_fraction), 48, ring_color.darkened(0.2), 3.0, true)
	if _icon != null:
		var s: float = 26.0
		draw_texture_rect(_icon, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false,
				Color(1, 1, 1, 1.0 if ready_to_cast else 0.45))
	if cooldown_left > 0.0 and _font != null:
		var txt: String = str(ceili(cooldown_left))
		var w: float = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
		draw_string_outline(_font, c + Vector2(-w / 2.0, 7.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.05, 0.03, 0.07))
		draw_string(_font, c + Vector2(-w / 2.0, 7.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
