extends SceneTree
## Renders every archetype and prop of a theme into one PNG contact sheet, for art review.
## Needs a renderer (not --headless), e.g. under Xvfb:
##   godot --path client -s ../tools/theme_preview.gd -- <theme_id> <out.png>

const CELL: Vector2 = Vector2(150, 150)
const COLS: int = 6
const SCALE: float = 1.6

var _out: String = ""
var _frames: int = 0


func _setup() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var registry: Node = root.get_node("ThemeRegistry")
	registry.call("activate", StringName(args[0]))
	_out = args[1]
	root.size = Vector2i(int(CELL.x * COLS), 1400)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b3530")
	bg.size = Vector2(root.size)
	root.add_child(bg)
	var ids: Array[StringName] = registry.call("covered_archetypes")
	var i: int = 0
	for id: StringName in ids:
		_place(registry.call("visual_for", id) as PackedScene, String(id), i)
		i += 1
	for prop: String in ["bush", "idol", "gate_sealed", "gate_open", "log", "roots", "dance_ring", "portal", "ash_burst", "hit_spark", "rot_stain", "wisp_orb"]:
		_place(registry.call("prop_for", StringName(prop)) as PackedScene, prop, i)
		i += 1


func _place(scene: PackedScene, label: String, i: int) -> void:
	if scene == null:
		return
	var cell: Vector2 = Vector2(i % COLS, i / COLS) * CELL
	var node: Node2D = scene.instantiate() as Node2D
	node.position = cell + Vector2(CELL.x / 2, CELL.y - 34)
	node.scale = Vector2.ONE * SCALE
	root.add_child(node)
	var l: Label = Label.new()
	l.text = label
	l.position = cell + Vector2(6, CELL.y - 26)
	root.add_child(l)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_setup()
	if _frames == 20:
		root.get_texture().get_image().save_png(_out)
		return true
	return false
