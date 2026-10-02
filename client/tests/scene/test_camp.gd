extends GdUnitTestSuite

const CAMP: String = "res://ui/screens/main.tscn"

var _save_before: SaveService


func before_test() -> void:
	_save_before = Services.save
	Services.save = SaveService.new("user://test_camp_%d/" % Time.get_ticks_usec())


func after_test() -> void:
	Services.save = _save_before
	ThemeRegistry.activate(ThemeRegistry.DEFAULT_THEME_ID)


func test_camp_shows_profile_and_buys_an_arrow() -> void:
	Services.save.set_value("profile", {"meat": 184, "spirit": 23})
	Services.save.save_game()
	var runner: GdUnitSceneRunner = scene_runner(CAMP)
	await runner.simulate_frames(2)
	assert_str((runner.find_child("MeatLabel") as Label).text).is_equal("184")
	var camp: Control = runner.scene() as Control
	var bone: ArrowDef = GameData.arrow(&"bone")
	camp.call("_buy", bone)
	var p: Profile = camp.get("profile") as Profile
	assert_int(p.meat).is_equal(114)
	assert_str(String(p.equipped_arrow)).is_equal("bone")
	var saved: Dictionary = Services.save.load_game()
	assert_int(VarUtil.to_int((saved["profile"] as Dictionary)["meat"])).is_equal(114)


func test_checkpoint_from_killed_run_is_banked() -> void:
	Services.save.set_value("profile", {"meat": 10, "spirit": 1})
	Services.save.set_value("run_checkpoint", {"grove": 4, "meat": 30, "spirit": 6})
	Services.save.save_game()
	var runner: GdUnitSceneRunner = scene_runner(CAMP)
	await runner.simulate_frames(2)
	var p: Profile = runner.scene().get("profile") as Profile
	assert_int(p.meat).is_equal(40)
	assert_int(p.spirit).is_equal(7)
	assert_object(Services.save.load_game().get("run_checkpoint")).is_null()


func test_theme_swap_changes_names_and_currency() -> void:
	ThemeRegistry.activate(&"deep_reef")
	Services.save.set_value("theme_id", "deep_reef")
	Services.save.save_game()
	var runner: GdUnitSceneRunner = scene_runner(CAMP)
	await runner.simulate_frames(2)
	assert_str((runner.find_child("ArrowsPaid") as Label).text).contains("pearls")
	assert_str(ThemeRegistry.visual_for(Ids.ROTLING).resource_path).contains("piranha")
