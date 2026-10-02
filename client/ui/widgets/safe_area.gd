class_name SafeArea
extends RefCounted
## Notch / punch-hole / gesture-bar insets (feel-test #19) in viewport units:
## DisplayServer.get_display_safe_area() is in screen pixels, the HUD lives in the 390-wide
## canvas_items viewport. Returns (left, top, right, bottom); zero on desktop and headless.


static func insets(vp: Viewport) -> Vector4:
	if DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var local: Rect2i = Rect2i(safe.position - win_pos, safe.size).intersection(Rect2i(Vector2i.ZERO, win))
	var view: Vector2 = vp.get_visible_rect().size
	var k: Vector2 = Vector2(view.x / win.x, view.y / win.y)
	return Vector4(local.position.x * k.x, local.position.y * k.y, (win.x - local.end.x) * k.x, (win.y - local.end.y) * k.y)


## The control's own offsets, to pass back to shift() whenever the insets change.
static func base_of(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


## Moves `c` (laid out by anchors) inside the insets: top-anchored rows down, bottom-anchored ones
## up, full-height ones shrink, all of them in from the sides.
static func shift(c: Control, base: Vector4, inset: Vector4) -> void:
	c.offset_left = base.x + inset.x
	c.offset_right = base.z - inset.z
	if c.anchor_top < 0.5 and c.anchor_bottom > 0.5:
		c.offset_top = base.y + inset.y
		c.offset_bottom = base.w - inset.w
	elif c.anchor_top < 0.5:
		c.offset_top = base.y + inset.y
		c.offset_bottom = base.w + inset.y
	else:
		c.offset_top = base.y - inset.w
		c.offset_bottom = base.w - inset.w
