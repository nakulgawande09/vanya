class_name Darkness
extends CanvasLayer
## Screen-space darkness veil with light holes. Callers add world-space holes each frame;
## the veil converts them to screen space. Emissives live on a layer above this one.

const MAX_HOLES: int = 16

var _rect: ColorRect
var _material: ShaderMaterial
var _holes: PackedVector4Array = PackedVector4Array()
var _out: PackedVector4Array = PackedVector4Array()
var _count: int = 0


func _init() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://gameplay/lighting/darkness.gdshader")
	_rect.material = _material
	add_child(_rect)
	_holes.resize(MAX_HOLES)
	_out.resize(MAX_HOLES)


func set_veil(c: Color) -> void:
	_material.set_shader_parameter(&"veil", c)


func begin() -> void:
	_count = 0


## World position and radius in world px; strength 0-1.
func add_hole(canvas_xform: Transform2D, world_pos: Vector2, radius: float, strength: float = 1.0) -> void:
	if _count >= MAX_HOLES:
		return
	var screen: Vector2 = canvas_xform * world_pos
	var zoom: float = canvas_xform.get_scale().x
	_holes[_count] = Vector4(screen.x, screen.y, radius * zoom, strength)
	_count += 1


func commit() -> void:
	# FRAGCOORD is in window pixels; convert from the stretched viewport.
	var vp: Viewport = get_viewport()
	var to_window: Transform2D = vp.get_final_transform() if vp != null else Transform2D.IDENTITY
	var s: float = to_window.get_scale().x
	for i: int in _count:
		var h: Vector4 = _holes[i]
		var w: Vector2 = to_window * Vector2(h.x, h.y)
		_out[i] = Vector4(w.x, w.y, h.z * s, h.w)
	_material.set_shader_parameter(&"holes", _out)
	_material.set_shader_parameter(&"hole_count", _count)
