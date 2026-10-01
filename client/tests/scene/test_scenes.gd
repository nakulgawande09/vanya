extends GdUnitTestSuite


func test_camp_screen_shows_currencies() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://ui/screens/main.tscn")
	await runner.simulate_frames(2)
	var meat: Label = runner.find_child("MeatLabel") as Label
	var enter: Button = runner.find_child("EnterButton") as Button
	assert_object(meat).is_not_null()
	assert_str(meat.text).contains("0")
	assert_bool(enter.disabled).is_false()


func test_grove_room_builds_placeholder_scene() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://gameplay/room/grove_room.tscn")
	await runner.simulate_frames(2)
	var lights: CanvasLayer = runner.find_child("Lights") as CanvasLayer
	var player: Player = runner.find_child("Player") as Player
	assert_object(player).is_not_null()
	# Player light plus one glow per torch.
	assert_int(lights.get_child_count()).is_equal(1 + 4)
	# Theme visual was attached to the player.
	assert_int(player.get_child_count()).is_greater(1)
	assert_int(Engine.max_fps).is_equal(AdaptiveQuality.profile.combat_max_fps)
