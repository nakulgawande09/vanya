class_name SwarmRenderer
extends MultiMeshInstance2D
## Draws every swarm unit of a SwarmSim in one MultiMesh using the theme's flipbook sheet
## (Rig spec: run 6 · lunge 3 · death 5). The flipbook rate follows the quality rung
## (30 / 20 / 12 / 8 fps). Themes without a flipbook draw their sprite as a single frame.
## A second MultiMesh on the emissive layer draws the eye glows above the darkness.

const SHADER: Shader = preload("res://gameplay/swarm/flipbook.gdshader")

var sim: SwarmSim
var fps: float = 20.0
var _clips: Dictionary = {}
var _frames: int = 1
var _cell: Vector2 = Vector2(54, 40)
var _eyes: MultiMeshInstance2D
var _eye_offset: Vector2 = Vector2.ZERO
var _eye_size: float = 0.0


func setup(swarm: SwarmSim, archetype: StringName, emissive_layer: Node) -> void:
	sim = swarm
	var book: Dictionary = ThemeRegistry.flipbook_for(archetype)
	var tex: Texture2D
	var stride_uv: float = 1.0
	var cell_uv: float = 1.0
	var visual: Node2D = ThemeRegistry.visual_for(archetype).instantiate() as Node2D
	var sprite: Sprite2D = visual.get_node("Body/Sprite") as Sprite2D
	if book.is_empty():
		tex = sprite.texture
		_cell = tex.get_size() * sprite.scale
		_frames = 1
	else:
		tex = book["texture"]
		var meta: Dictionary = book["meta"]
		var density: float = VarUtil.to_float(meta.get("density"), 3.0)
		var cell_px: Array = meta["cell_size_px"]
		_cell = Vector2(VarUtil.to_float(cell_px[0]), VarUtil.to_float(cell_px[1])) / density
		_frames = VarUtil.to_int(meta.get("frames"), 1)
		_clips = meta.get("clips", {})
		var sheet_w: float = tex.get_width()
		stride_uv = VarUtil.to_float(meta.get("cell_stride_px")) / sheet_w
		cell_uv = VarUtil.to_float(cell_px[0]) / sheet_w
	var glow: Node2D = visual.find_child("Glow0", true, false) as Node2D
	if glow != null:
		# Glow position relative to the feet anchor; the quad is centred, so shift by half a cell.
		_eye_offset = glow.position + Vector2(0, _cell.y / 2)
		_eye_size = 64.0 * glow.scale.x
	visual.free()
	texture = tex
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"stride_uv", stride_uv)
	mat.set_shader_parameter(&"cell_uv", cell_uv)
	material = mat
	multimesh = _make_multimesh(_cell, sim.capacity)
	if _eye_size > 0.0 and emissive_layer != null:
		_eyes = MultiMeshInstance2D.new()
		_eyes.multimesh = _make_multimesh(Vector2(_eye_size, _eye_size), sim.capacity, false)
		_eyes.texture = _glow_texture()
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_eyes.material = add
		emissive_layer.add_child(_eyes)


func set_quality(profile: QualityProfile) -> void:
	fps = float(profile.swarm_anim_fps)


## Writes this tick's transforms and frames; inactive slots are hidden (alpha 0).
func sync(target: Vector2) -> void:
	var mm: MultiMesh = multimesh
	var eyes: MultiMesh = _eyes.multimesh if _eyes != null else null
	for i: int in sim.capacity:
		var s: int = sim.state[i]
		if s == SwarmSim.State.FREE:
			mm.set_instance_custom_data(i, Color(0, 1, 0, 0))
			if eyes != null:
				eyes.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var facing: float = -1.0 if target.x < sim.pos[i].x else 1.0
		var alpha: float = 1.0
		var frame: int = 0
		if s == SwarmSim.State.SPAWN:
			alpha = clampf(sim.state_t[i] / SwarmSim.SPAWN_TIME, 0.0, 1.0)
			frame = _clip_frame(&"run", sim.anim_t[i])
		elif s == SwarmSim.State.LUNGE:
			frame = _clip_frame(&"lunge", sim.anim_t[i])
		elif s == SwarmSim.State.DYING:
			frame = _clip_frame(&"death", sim.anim_t[i])
		else:
			frame = _clip_frame(&"run", sim.anim_t[i])
		var at: Vector2 = sim.pos[i] - Vector2(0, _cell.y / 2)
		mm.set_instance_transform_2d(i, Transform2D(0.0, at))
		var flash: float = 1.0 if sim.flash_t[i] > 0.0 else 0.0
		mm.set_instance_custom_data(i, Color(float(frame), facing, flash, alpha))
		if eyes != null:
			var eye_alpha: float = 0.0 if s == SwarmSim.State.DYING else alpha
			eyes.set_instance_transform_2d(i, Transform2D(0.0, at + Vector2(_eye_offset.x * facing, _eye_offset.y)))
			eyes.set_instance_color(i, Color(1, 1, 1, eye_alpha))


func _clip_frame(clip: StringName, t: float) -> int:
	if _frames <= 1 or not _clips.has(String(clip)):
		return 0
	var c: Dictionary = _clips[String(clip)]
	var start: int = VarUtil.to_int(c.get("start"))
	var count: int = VarUtil.to_int(c.get("count"), 1)
	var loop: bool = c.get("loop", false) == true
	var rate: float = fps if clip == &"run" else maxf(fps, 12.0)
	var f: int = int(t * rate)
	return start + (f % count if loop else mini(f, count - 1))


func _make_multimesh(size: Vector2, count: int, custom: bool = true) -> MultiMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = custom
	mm.use_colors = not custom
	mm.mesh = quad
	mm.instance_count = count
	for i: int in count:
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-9999, -9999)))
	return mm


func _glow_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	var c: Color = ThemeRegistry.color(&"foe_glow", Color("#E56BFF"))
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(c, 0.95), Color(c, 0.45), Color(c, 0.0)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
