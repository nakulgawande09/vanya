extends SceneTree
## Visual QA tour: camp → grove fight → defeat, for each bundled theme. Needs a renderer (Xvfb).
##   godot --path client -s ../tools/screenshot_tour.gd -- <out_dir> [theme_id]
## Writes <theme>_camp.png, <theme>_grove.png, <theme>_fight.png, <theme>_defeat.png.

var _out: String
var _theme: StringName
var _frame: int = 0
var _run: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	_theme = StringName(args[1]) if args.size() > 1 else &"grove_default"


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		2:
			root.get_node("ThemeRegistry").call("activate", _theme)
			var save: SaveService = root.get_node("Services").get("save") as SaveService
			save.set_value("theme_id", String(_theme))
			save.set_value("profile", {"meat": 184, "spirit": 23, "owned_arrows": ["stone", "flint"], "equipped_arrow": "flint", "shrine_levels": {"suryak": 2, "tamba": 1, "anjor": 3}})
			save.save_game()
			change_scene_to_file("res://ui/screens/main.tscn")
		40:
			_shot("camp")
			change_scene_to_file("res://gameplay/run/grove_run.tscn")
		50:
			_run = current_scene
			_run.set("run_seed", 3)
		60:
			_shot("grove")
		61:
			(_run.get("run") as RefCounted).call("add_spirit", 7)
			(_run.get_node("%Player") as Node).call("set_move_input", Vector2(0.3, -1))
		150:
			(_run.get_node("%Player") as Node).call("set_move_input", Vector2(-0.4, -0.3))
		260:
			(_run.get_node("%Player") as Node).call("set_move_input", Vector2.ZERO)
			(_run.get("gods") as Node).call("try_cast", &"meghra")
		266:
			_shot("fight")
		268:
			(_run.get("run") as RefCounted).call("take_damage", 999)
		360:
			_shot("defeat")
			return true
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _theme, name])
