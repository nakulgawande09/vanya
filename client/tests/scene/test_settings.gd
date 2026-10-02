extends GdUnitTestSuite

const SETTINGS: String = "res://ui/screens/settings.tscn"

var _save_before: SaveService


func before_test() -> void:
	_save_before = Services.save
	Services.save = SaveService.new("user://test_settings_%d/" % Time.get_ticks_usec())


func after_test() -> void:
	Services.save = _save_before
	TranslationServer.set_locale("en")
	ThemeRegistry.activate(ThemeRegistry.DEFAULT_THEME_ID)
	AdaptiveQuality.apply_setting(GameSettings.Graphics.AUTO)


func _button(root: Node, text: String) -> Button:
	for b: Node in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b as Button
	return null


func test_language_and_hand_choices_apply_and_persist() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SETTINGS)
	var screen: SettingsScreen = runner.scene() as SettingsScreen
	screen.open()
	await runner.simulate_frames(2)
	_button(screen, "Left").pressed.emit()
	_button(screen, "हिन्दी").pressed.emit()
	await runner.simulate_frames(2)
	assert_str(TranslationServer.get_locale()).is_equal("hi")
	var saved: GameSettings = GameSettings.from_dict(Services.save.load_game()["settings"] as Dictionary)
	assert_bool(saved.left_handed).is_true()
	assert_str(saved.locale).is_equal("hi")
	# Rebuilt in Hindi.
	assert_object(_button(screen, "चालू")).is_not_null()


func test_graphics_override_sets_the_quality_ceiling() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SETTINGS)
	var screen: SettingsScreen = runner.scene() as SettingsScreen
	screen.open()
	await runner.simulate_frames(2)
	_button(screen, "Low").pressed.emit()
	assert_int(AdaptiveQuality.current_rung()).is_equal(QualityProfile.Rung.LOW)
	_button(screen, "High").pressed.emit()
	assert_int(AdaptiveQuality.current_rung()).is_equal(QualityProfile.Rung.HIGH)


func test_world_choice_switches_theme_and_reports_reload() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SETTINGS)
	var screen: SettingsScreen = runner.scene() as SettingsScreen
	var reloads: Array[bool] = []
	screen.closed.connect(func(r: bool) -> void: reloads.append(r))
	screen.open()
	await runner.simulate_frames(2)
	_button(screen, "Deep reef").pressed.emit()
	assert_str(String(ThemeRegistry.theme_id)).is_equal("deep_reef")
	(screen.get_node("%DoneButton") as Button).pressed.emit()
	assert_array(reloads).is_equal([true])
