class_name Hud
extends Control
## In-run HUD (Screens board, HUD parts): health bar, grove pill, meat / spirit / guide pills,
## the frenzy counter, the floating joystick and the battle-god buttons.

signal move_input(vector: Vector2)
signal god_pressed(god: StringName)
signal pause_pressed
signal skip_pressed

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
@onready var _pause: Button = %PauseButton
@onready var _tip: PanelContainer = %Tip
@onready var _tip_label: Label = %TipLabel
@onready var _skip: Button = %SkipButton

var flash_intensity: float = 1.0
var _buttons: Dictionary[StringName, GodButton] = {}
var _vignette: TextureRect
var _vignette_t: float = 0.0
var _flyers: Array[TextureRect] = []
var _fly_cursor: int = 0
var _pointer: Polygon2D
var _pointer_at: Vector2 = Vector2(-100, -100)
var _pointer_t: float = 0.0
var _flash_t: float = 0.0
var _guide: StringName = &"-"
var _frenzy: int = -1


func _ready() -> void:
	_heart.texture = ThemeRegistry.icon_for(&"health")
	_pause.pressed.connect(func() -> void: pause_pressed.emit())
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	_pointer = Polygon2D.new()
	_pointer.polygon = PackedVector2Array([Vector2(-12, -16), Vector2(12, -16), Vector2(0, 0)])
	_pointer.color = ThemeRegistry.color(&"spirit_jade")
	_pointer.visible = false
	add_child(_pointer)
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
	_build_vignette()
	for i: int in 12:
		var f: TextureRect = TextureRect.new()
		f.custom_minimum_size = Vector2(18, 18)
		f.size = Vector2(18, 18)
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.visible = false
		add_child(f)
		_flyers.append(f)
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
	_grove_label.text = tr(&"HUD_TUTORIAL") if grove == 0 else tr(&"HUD_GROVE") % grove


## Tutorial tip card under the HUD rows (with a Skip button).
func show_tip(key: StringName) -> void:
	_tip_label.text = tr(key)
	_tip.visible = true


func hide_tip() -> void:
	_tip.visible = false
	_pointer.visible = false


## A bobbing jade arrow pointing down at a screen position (off-screen hides it).
func point_at(screen_pos: Vector2) -> void:
	_pointer_at = screen_pos
	_pointer.visible = _tip.visible and screen_pos.x >= 0.0 and screen_pos.y >= 0.0


func joystick_rest() -> Vector2:
	return _joystick.position + Vector2(70.0 if not _joystick.left_handed else _joystick.size.x - 70.0,
			_joystick.size.y - 80.0 - FloatingJoystick.RADIUS - 8.0)


func god_button_position(god: StringName) -> Vector2:
	var b: GodButton = _buttons.get(god)
	return b.global_position - global_position + b.size / 2.0 if b != null else Vector2(-100, -100)


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
	if flash_intensity <= 0.0:
		return
	_flash.color = Color(c, c.a * flash_intensity)
	_flash_t = 0.25


## Red edge pulse when the hunter is hit (scaled by the flash-intensity setting).
func hurt() -> void:
	_vignette_t = 0.35 * flash_intensity


## A collected meat/spirit icon flies from its screen position to its pill, which then bumps.
func fly_pickup(kind: StringName, from_screen: Vector2) -> void:
	var f: TextureRect = _flyers[_fly_cursor]
	_fly_cursor = (_fly_cursor + 1) % _flyers.size()
	var pill_icon: TextureRect = _meat_icon if kind == Ids.MEAT else _spirit_icon
	f.texture = pill_icon.texture
	f.position = from_screen - f.size / 2.0
	f.visible = true
	var to: Vector2 = pill_icon.global_position - global_position
	var tw: Tween = create_tween()
	tw.tween_property(f, "position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		f.visible = false
		pill_icon.pivot_offset = pill_icon.size / 2.0
		var bump: Tween = create_tween()
		bump.tween_property(pill_icon, "scale", Vector2(1.35, 1.35), 0.06)
		bump.tween_property(pill_icon, "scale", Vector2.ONE, 0.12)
	)


func set_left_handed(value: bool) -> void:
	_joystick.left_handed = value


func _build_vignette() -> void:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var red: Color = ThemeRegistry.color(&"kumkum_red", Color("#C8372D"))
	g.colors = PackedColorArray([Color(red, 0.0), Color(red, 0.0), Color(red, 0.75)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_vignette = TextureRect.new()
	_vignette.texture = t
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	move_child(_vignette, 0)


func _process(delta: float) -> void:
	if _pointer.visible:
		_pointer_t += delta
		_pointer.position = _pointer_at + Vector2(0, -6.0 * absf(sin(_pointer_t * 5.0)))
	if _vignette_t > 0.0:
		_vignette_t = maxf(0.0, _vignette_t - delta)
		_vignette.modulate.a = clampf(_vignette_t / 0.35, 0.0, 1.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.modulate.a = clampf(_flash_t / 0.25, 0.0, 1.0)
	elif _flash.modulate.a > 0.0:
		_flash.modulate.a = 0.0
