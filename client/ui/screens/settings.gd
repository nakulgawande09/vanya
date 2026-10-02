class_name SettingsScreen
extends Control
## Settings (standards §C15, Audio Bible A5): joystick hand, screen shake, flashes, damage numbers,
## vibration level, volumes, "let my music play", language, difficulty, adaptive challenge,
## graphics and the world (theme). Every change is
## saved at once; `closed` reports whether the language or world changed (callers rebuild).

signal closed(needs_reload: bool)

var settings: GameSettings
var _locale_at_open: String = ""
var _theme_at_open: StringName = &""

@onready var _rows: VBoxContainer = %Rows
@onready var _done: Button = %DoneButton


func _ready() -> void:
	_done.pressed.connect(_close)
	UiSounds.wire(self)
	visible = false


func open() -> void:
	var saved: Variant = Services.save.load_game().get("settings", {})
	settings = GameSettings.from_dict(_dict(saved))
	_locale_at_open = settings.locale
	_theme_at_open = ThemeRegistry.theme_id
	_build()
	visible = true
	_done.grab_focus()


func _build() -> void:
	for c: Node in _rows.get_children():
		c.queue_free()
	_choice(&"SET_HAND", [&"SET_LEFT", &"SET_RIGHT"], 0 if settings.left_handed else 1,
			func(i: int) -> void: settings.left_handed = i == 0)
	_choice(&"SET_SHAKE", [&"SET_ON", &"SET_OFF"], 0 if settings.screen_shake else 1,
			func(i: int) -> void: settings.screen_shake = i == 0)
	var flash_index: int = 0 if settings.flash_intensity > 0.75 else (1 if settings.flash_intensity > 0.25 else 2)
	_choice(&"SET_FLASH", [&"SET_FULL", &"SET_HALF", &"SET_OFF"], flash_index,
			func(i: int) -> void: settings.flash_intensity = [1.0, 0.5, 0.0][i])
	_choice(&"SET_NUMBERS", [&"SET_ON", &"SET_OFF"], 0 if settings.damage_numbers else 1,
			func(i: int) -> void: settings.damage_numbers = i == 0)
	_choice(&"SET_HAPTICS", [&"SET_OFF", &"SET_LOW", &"SET_FULL"], settings.haptics,
			func(i: int) -> void:
				settings.haptics = i as GameSettings.Haptics
				Boot.apply_audio_settings(settings)
				Services.haptics.pulse(&"purchase"))
	_stepper(&"SET_MASTER", settings.master_vol, func(v: int) -> void: settings.master_vol = v)
	_stepper(&"SET_MUSIC", settings.music_vol, func(v: int) -> void: settings.music_vol = v)
	_stepper(&"SET_SFX", settings.sfx_vol, func(v: int) -> void: settings.sfx_vol = v)
	_stepper(&"SET_AMBIENCE", settings.amb_vol, func(v: int) -> void: settings.amb_vol = v)
	_stepper(&"SET_UI_SOUNDS", settings.ui_vol, func(v: int) -> void: settings.ui_vol = v)
	_choice(&"SET_LET_MUSIC", [&"SET_ON", &"SET_OFF"], 0 if settings.let_my_music_play else 1,
			func(i: int) -> void:
				settings.let_my_music_play = i == 0
				Boot.apply_audio_settings(settings))
	_choice(&"SET_LANGUAGE", [&"LANG_EN", &"LANG_HI", &"LANG_MR"], GameSettings.LOCALES.find(settings.locale),
			func(i: int) -> void:
				settings.locale = GameSettings.LOCALES[i]
				TranslationServer.set_locale(settings.locale)
				_build.call_deferred())
	_choice(&"SET_DIFFICULTY", [&"DIFF_STORY", &"DIFF_NORMAL", &"DIFF_HUNTER"], settings.difficulty,
			func(i: int) -> void: settings.difficulty = i as GameSettings.Difficulty)
	_choice(&"SET_ADAPTIVE", [&"SET_ON", &"SET_OFF"], 0 if settings.adaptive_challenge else 1,
			func(i: int) -> void: settings.adaptive_challenge = i == 0)
	_choice(&"SET_GRAPHICS", [&"GFX_AUTO", &"GFX_HIGH", &"GFX_MEDIUM", &"GFX_LOW"], settings.graphics,
			func(i: int) -> void:
				settings.graphics = i as GameSettings.Graphics
				AdaptiveQuality.apply_setting(i))
	var themes: Array[StringName] = ThemeRegistry.available_themes()
	_choice(&"SET_WORLD", _theme_labels(themes), themes.find(ThemeRegistry.theme_id),
			func(i: int) -> void:
				if ThemeRegistry.activate(themes[i]):
					Services.save.set_value("theme_id", String(themes[i]))
					Services.analytics.log_event(&"theme_switched", {"theme_id": String(themes[i])})
					_build.call_deferred())
	UiSounds.wire(_rows)


func _theme_labels(themes: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for t: StringName in themes:
		out.append(StringName("WORLD_" + String(t).to_upper()))
	return out


## One labelled row of segmented choices; the selected one uses the primary button style.
func _choice(label_key: StringName, options: Array[StringName], selected: int, on_pick: Callable) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var label: Label = Label.new()
	label.theme_type_variation = &"TitleLabel"
	label.text = tr(label_key)
	row.add_child(label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	row.add_child(buttons)
	for i: int in options.size():
		var b: Button = Button.new()
		b.text = tr(options[i])
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.theme_type_variation = &"" if i == selected else &"SecondaryButton"
		b.add_theme_font_size_override(&"font_size", 16)
		b.pressed.connect(func() -> void:
			on_pick.call(i)
			_save()
			for k: int in buttons.get_child_count():
				(buttons.get_child(k) as Button).theme_type_variation = &"" if k == i else &"SecondaryButton"
		)
		buttons.add_child(b)
	_rows.add_child(row)


## A labelled volume row: − value + (0–10). Applies at once and plays a sample on the UI bus.
func _stepper(label_key: StringName, value: int, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var label: Label = Label.new()
	label.theme_type_variation = &"TitleLabel"
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var shown: Label = Label.new()
	shown.text = str(value)
	shown.custom_minimum_size = Vector2(32, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var current: Array[int] = [value]
	for step: int in [-1, 1]:
		var b: Button = Button.new()
		b.text = "−" if step < 0 else "+"
		b.custom_minimum_size = Vector2(48, 44)
		b.theme_type_variation = &"SecondaryButton"
		b.pressed.connect(func() -> void:
			current[0] = clampi(current[0] + step, 0, GameSettings.VOLUME_STEPS)
			shown.text = str(current[0])
			on_change.call(current[0])
			Boot.apply_audio_settings(settings)
			_save())
		row.add_child(b)
		if step < 0:
			row.add_child(shown)
	_rows.add_child(row)


func _save() -> void:
	Services.save.set_value("settings", settings.to_dict())
	Services.save.save_game()


func _close() -> void:
	visible = false
	closed.emit(settings.locale != _locale_at_open or ThemeRegistry.theme_id != _theme_at_open)


static func _dict(v: Variant) -> Dictionary:
	var d: Dictionary = v if v is Dictionary else {}
	return d
