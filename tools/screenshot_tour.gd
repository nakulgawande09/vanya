extends SceneTree
## Visual QA tour for one theme: camp → tutorial tip → generated grove → fight → feel-test
## overlay → pause → settings (in Hindi) → defeat. Needs a renderer (Xvfb):
##   godot --path client -s ../tools/screenshot_tour.gd -- <out_dir> [theme_id]

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
			var save: Object = root.get_node("Services").get("save")
			save.call("set_value", "theme_id", String(_theme))
			save.call("set_value", "settings", {})
			save.call("set_value", "profile", {"meat": 184, "spirit": 23, "owned_arrows": ["stone", "flint"],
					"equipped_arrow": "flint", "shrine_levels": {"suryak": 2, "tamba": 1, "kaja": 3}})
			save.call("save_game")
			change_scene_to_file("res://ui/screens/main.tscn")
		40:
			_shot("camp")
			change_scene_to_file("res://gameplay/run/grove_run.tscn")
		70:
			_run = current_scene
			_shot("tutorial")
			_run.call("skip_tutorial")
		130:
			_shot("grove")
			(_run.get("run") as Object).call("add_spirit", 7)
			_player().call("set_move_input", Vector2(0.3, -1))
		220:
			_player().call("set_move_input", Vector2(-0.4, -0.3))
		330:
			_player().call("set_move_input", Vector2.ZERO)
			(_run.get("gods") as Object).call("try_cast", &"meghra")
		336:
			_shot("fight")
			var hud: Object = _run.call("hud")
			((hud.get("overlay") as Object).get("_tune_box") as CanvasItem).visible = true
			(hud.get("overlay") as Object).call("toggle")
		410:
			_shot("overlay")
			((_run.call("hud") as Object).get("overlay") as Object).call("toggle")
			_run.call("open_pause")
		416:
			_shot("pause")
			(_run.get_node("%Settings") as Object).call("open")
			TranslationServer.set_locale("hi")
			(_run.get_node("%Settings") as Object).call("_build")
		424:
			_shot("settings_hi")
			TranslationServer.set_locale("en")
			(_run.get_node("%Settings") as CanvasItem).visible = false
			_run.call("resume")
			(_run.get("run") as Object).call("take_damage", 999)
		514:
			_shot("defeat")
			return true
	return false


func _player() -> Object:
	return _run.get_node("%Player")


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _theme, name])
