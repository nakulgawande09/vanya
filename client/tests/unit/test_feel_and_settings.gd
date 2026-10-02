extends GdUnitTestSuite
## FeelTuning carries the feel-test starting values (B4); settings migrate the old haptics switch.


func test_feel_tuning_defaults_match_the_feel_test_plan() -> void:
	var t: FeelTuning = load(FeelTuning.DEFAULT_PATH) as FeelTuning
	assert_float(t.hitstop_normal_hit).is_equal(0.0)
	assert_float(t.hitstop_crit).is_equal(0.045)
	assert_float(t.hitstop_rotling_kill).is_equal(0.03)
	assert_float(t.hitstop_elite_kill).is_equal(0.07)
	assert_float(t.hitstop_hurt).is_equal(0.06)
	assert_float(t.hitstop_god).is_equal(0.08)
	assert_float(t.hitstop_boss).is_equal(0.09)
	assert_vector(t.shake_hurt).is_equal(Vector2(4.0, 0.15))
	assert_vector(t.shake_god).is_equal(Vector2(8.0, 0.3))
	assert_vector(t.shake_boss).is_equal(Vector2(10.0, 0.35))
	assert_vector(t.haptics[&"hurt"]).is_equal(Vector3(40, 0.7, 250))
	assert_int(t.haptic_budget_per_s).is_equal(4)


func test_stick_shaping_dead_zone_full_speed_and_curve() -> void:
	var t: FeelTuning = FeelTuning.new()
	t.joystick_deadzone = 0.1
	t.joystick_full_speed_at = 0.6
	assert_vector(t.shape_stick(Vector2(0.08, 0.0))).is_equal(Vector2.ZERO)
	assert_float(t.shape_stick(Vector2(0.6, 0.0)).length()).is_equal_approx(1.0, 0.001)
	assert_float(t.shape_stick(Vector2(0.0, 0.35)).length()).is_equal_approx(0.5, 0.001)
	t.joystick_curve = 2.0
	assert_float(t.shape_stick(Vector2(0.0, 0.35)).length()).is_equal_approx(0.25, 0.001)


func test_old_haptics_switch_migrates_to_levels() -> void:
	assert_int(GameSettings.from_dict({"haptics": false}).haptics).is_equal(GameSettings.Haptics.OFF)
	assert_int(GameSettings.from_dict({"haptics": true}).haptics).is_equal(GameSettings.Haptics.FULL)
	assert_int(GameSettings.from_dict({"haptics_level": 1}).haptics).is_equal(GameSettings.Haptics.LOW)


func test_volumes_round_trip_and_clamp() -> void:
	var s: GameSettings = GameSettings.from_dict({"music_vol": 4, "sfx_vol": 99, "let_my_music_play": true})
	assert_int(s.music_vol).is_equal(4)
	assert_int(s.sfx_vol).is_equal(GameSettings.VOLUME_STEPS)
	var back: GameSettings = GameSettings.from_dict(s.to_dict())
	assert_int(back.music_vol).is_equal(4)
	assert_bool(back.let_my_music_play).is_true()
	assert_float(GameSettings.level(5)).is_equal(0.5)
