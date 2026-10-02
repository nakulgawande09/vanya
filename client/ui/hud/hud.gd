class_name Hud
extends Control
## In-run HUD (Screens board, HUD parts): health bar, grove pill, meat / spirit / guide pills,
## the frenzy counter, the floating joystick and the battle-god buttons.

signal move_input(vector: Vector2)
signal god_pressed(god: StringName)

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _grove_label: Label = %GroveLabel
@onready var _meat_icon: TextureRect = %MeatIcon
@onready var _meat_label: Label = %MeatLabel
@onready var _spirit_icon: TextureRect = %SpiritIcon
@onready var _spirit_label: Label = %SpiritLabel
@onready var _guide_pill: PanelContainer = %GuidePill
@onready var _guide_icon: TextureRect = %GuideIcon
@onready var _guide_label: Label = %GuideLabel
@onready var _frenzy_label: Label = %FrenzyLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _heart: TextureRect = %HeartIcon
@onready var _joystick: FloatingJoystick = %Joystick
@onready var _gods: HBoxContainer = %Gods
@onready var _flash: ColorRect = %Flash

var _buttons: Dictionary[StringName, GodButton] = {}
var _flash_t: float = 0.0
var _guide: StringName = &"-"
var _frenzy: int = -1


func _ready() -> void:
	_heart.texture = ThemeRegistry.icon_for(&"health")
	_meat_icon.texture = ThemeRegistry.icon_for(Ids.MEAT)
	_spirit_icon.texture = ThemeRegistry.icon_for(Ids.SPIRIT)
	_spirit_label.add_theme_color_override(&"font_color", ThemeRegistry.color(&"spirit_jade"))
	_guide_label.add_theme_color_override(&"font_color", ThemeRegistry.color(&"spirit_jade"))
	_guide_pill.visible = false
	_frenzy_label.visible = false
	_wave_label.visible = false
	_joystick.moved.connect(func(v: Vector2) -> void: move_input.emit(v))
	var rings: Dictionary[StringName, Color] = {
		Ids.MEGHRA: ThemeRegistry.color(&"storm_sky"),
		Ids.DHORU: ThemeRegistry.color(&"rice_white"),
		Ids.VAYLI: ThemeRegistry.color(&"spirit_jade"),
	}
	for id: StringName in GameData.GODS:
		var b: GodButton = GodButton.new()
		b.setup(id, rings[id], GameData.god(id).spirit_cost)
		b.pressed.connect(func(g: StringName) -> void: god_pressed.emit(g))
		_gods.add_child(b)
		_buttons[id] = b


func set_health(hp: int, max_hp: int) -> void:
	_health_bar.max_value = max_hp
	_health_bar.value = hp
	_health_label.text = str(hp)


func set_grove(grove: int) -> void:
	_grove_label.text = tr(&"HUD_GROVE") % grove


func set_currencies(meat: int, spirit: int) -> void:
	_meat_label.text = str(meat)
	_spirit_label.text = str(spirit)


func set_guide(guide: StringName) -> void:
	if guide == _guide:
		return
	_guide = guide
	_guide_pill.visible = guide != &""
	if guide != &"":
		_guide_icon.texture = ThemeRegistry.icon_for(guide)
		_guide_label.text = tr(ThemeRegistry.name_key_for(guide))


func set_frenzy(count: int) -> void:
	if count == _frenzy:
		return
	_frenzy = count
	_frenzy_label.visible = count >= 3
	if count >= 3:
		_frenzy_label.text = tr(&"HUD_FRENZY") % count


func set_wave(index: int, total: int) -> void:
	_wave_label.visible = true
	_wave_label.text = tr(&"HUD_WAVE") % [index + 1, total]
	_wave_label.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_wave_label, "modulate:a", 0.0, 0.5)


func set_god_state(god: StringName, is_ready: bool, left: float, fraction: float) -> void:
	var b: GodButton = _buttons.get(god)
	if b != null:
		b.set_state(is_ready, left, fraction)


func flash(c: Color) -> void:
	_flash.color = c
	_flash_t = 0.25


func set_left_handed(value: bool) -> void:
	_joystick.left_handed = value


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.modulate.a = clampf(_flash_t / 0.25, 0.0, 1.0)
	elif _flash.modulate.a > 0.0:
		_flash.modulate.a = 0.0
