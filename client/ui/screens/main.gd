extends Control
## Camp screen stub: title, currencies and the way into the grove.

const GROVE_SCENE: String = "res://gameplay/room/grove_room.tscn"

@onready var _enter_button: Button = %EnterButton
@onready var _meat_label: Label = %MeatLabel
@onready var _spirit_label: Label = %SpiritLabel


func _ready() -> void:
	var save: Dictionary = Services.save.load_game()
	_meat_label.text = "%s  %d" % [tr(&"CURRENCY_MEAT"), VarUtil.to_int(save.get("meat"))]
	_spirit_label.text = "%s  %d" % [tr(&"CURRENCY_SPIRIT"), VarUtil.to_int(save.get("spirit"))]
	_meat_label.add_theme_color_override(&"font_color", ThemeRegistry.color(&"meat_amber"))
	_spirit_label.add_theme_color_override(&"font_color", ThemeRegistry.color(&"spirit_jade"))
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.grab_focus()


func _on_enter_pressed() -> void:
	_enter_button.disabled = true
	SceneRouter.change_to(GROVE_SCENE)
