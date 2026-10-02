extends GdUnitTestSuite


func test_expected_and_target_for_75_percent() -> void:
	assert_float(SkillRating.expected(1000.0, 1000.0)).is_equal_approx(0.5, 0.0001)
	var r: SkillRating = SkillRating.new()
	var d: float = r.target_difficulty(0.75)
	assert_float(d).is_equal_approx(1000.0 - 190.85, 0.1)
	assert_float(SkillRating.expected(r.rating, d)).is_equal_approx(0.75, 0.0001)


func test_performance_weights() -> void:
	assert_float(SkillRating.performance(true, 1.0, 0.0, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(SkillRating.performance(false, 0.0, 1.0, 0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(SkillRating.performance(true, 0.5, 0.0, 0.0)).is_equal_approx(0.55 + 0.125 + 0.1, 0.0001)


func test_rating_rises_on_easy_clears_and_k_drops_after_ten_rooms() -> void:
	var r: SkillRating = SkillRating.new()
	var first: float = r.update(900.0, 0.9, true)
	assert_float(first).is_greater(0.0)
	for i: int in 10:
		r.update(900.0, 0.9, true)
	var later: float = r.update(r.rating, 0.9, true)
	assert_float(later).is_equal_approx(SkillRating.K_LATE * (0.9 - 0.5), 0.01)


func test_anti_sandbag_ignores_idle_deaths() -> void:
	var r: SkillRating = SkillRating.new()
	assert_float(r.update(1000.0, 0.05, false, 0.05)).is_equal(0.0)
	assert_float(r.update(1000.0, 0.05, false, 0.6)).is_less(0.0)


func test_rails_limit_steps_and_range() -> void:
	var rails: DdaRails = DdaRails.new()
	# A much stronger player wants far harder rooms; the rails allow +8% per room.
	assert_float(rails.next_scale(1, 2000.0)).is_equal_approx(1.08, 0.0001)
	assert_float(rails.next_scale(2, 2000.0)).is_equal_approx(1.16, 0.0001)
	for g: int in range(3, 6):
		rails.next_scale(g, 9000.0)
	# Arc limit (+20% from the arc start) and the 1.25 ceiling.
	assert_float(rails.last_scale).is_less_equal(1.2 + 0.0001)
	for g: int in range(6, 20):
		rails.next_scale(g, 9000.0)
	assert_float(rails.last_scale).is_equal_approx(DdaRails.MAX_SCALE, 0.0001)


func test_mercy_and_relief_room() -> void:
	var rails: DdaRails = DdaRails.new()
	rails.next_scale(3, DdaRails.room_difficulty(3, 1.0))
	rails.on_death()
	rails.on_death()
	assert_float(rails.next_scale(3, DdaRails.room_difficulty(3, 1.0))).is_equal_approx(0.92, 0.0001)
	rails.on_death()
	assert_float(rails.next_scale(3, DdaRails.room_difficulty(3, 1.0))).is_equal(DdaRails.MIN_SCALE)
	assert_float(rails.supply_chance()).is_equal_approx(DdaRails.SUPPLY_MAX, 0.0001)


func test_adaptive_off_is_fixed() -> void:
	var rails: DdaRails = DdaRails.new()
	rails.adaptive = false
	assert_float(rails.next_scale(4, 5000.0)).is_equal(1.0)


func test_intensity_peaks_then_relaxes_with_relief_once() -> void:
	var d: IntensityDirector = IntensityDirector.new()
	assert_bool(d.allows_new_wave()).is_true()
	d.feed(0.1, 0.5, true, 6)
	assert_int(d.phase).is_equal(IntensityDirector.Phase.PEAK)
	assert_bool(d.allows_new_wave()).is_false()
	for i: int in 90:
		d.feed(0.1, 0.0, false, 0)
	assert_int(d.phase).is_equal(IntensityDirector.Phase.RELAX)
	assert_bool(d.wants_relief(0.2)).is_true()
	assert_bool(d.wants_relief(0.2)).is_false()
	for i: int in 130:
		d.feed(0.1, 0.0, false, 0)
	assert_int(d.phase).is_equal(IntensityDirector.Phase.BUILD_UP)


func test_settings_round_trip_and_clamping() -> void:
	var s: GameSettings = GameSettings.new()
	s.left_handed = true
	s.locale = "mr"
	s.difficulty = GameSettings.Difficulty.STORY
	s.flash_intensity = 0.5
	var t: GameSettings = GameSettings.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary)
	assert_bool(t.left_handed).is_true()
	assert_str(t.locale).is_equal("mr")
	assert_float(t.target_success()).is_equal(0.85)
	assert_float(t.flash_intensity).is_equal(0.5)
	var bad: GameSettings = GameSettings.from_dict({"locale": "xx", "difficulty": 9, "flash_intensity": 3})
	assert_str(bad.locale).is_equal("en")
	assert_int(bad.difficulty).is_equal(GameSettings.Difficulty.HUNTER)
	assert_float(bad.flash_intensity).is_equal(1.0)
