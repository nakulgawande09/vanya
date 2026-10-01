extends GdUnitTestSuite

const GIB: int = 1024 * 1024 * 1024


func test_all_profiles_load_with_matching_rung() -> void:
	for rung: int in QualityProfile.Rung.values():
		var profile: QualityProfile = AdaptiveQuality.load_profile(rung as QualityProfile.Rung)
		assert_object(profile).is_not_null()
		assert_int(profile.rung).is_equal(rung)


func test_ladder_is_monotonic() -> void:
	var high: QualityProfile = AdaptiveQuality.load_profile(QualityProfile.Rung.HIGH)
	var low: QualityProfile = AdaptiveQuality.load_profile(QualityProfile.Rung.LOW)
	var thermal: QualityProfile = AdaptiveQuality.load_profile(QualityProfile.Rung.THERMAL)
	assert_int(low.combat_max_fps).is_equal(30)
	assert_float(low.render_scale).is_equal(0.75)
	assert_int(low.real_lights).is_equal(0)
	assert_bool(high.fake_lights > low.fake_lights and low.fake_lights > thermal.fake_lights).is_true()
	assert_bool(thermal.max_enemies < low.max_enemies).is_true()


func test_tier_from_ram() -> void:
	assert_int(AdaptiveQuality.tier_for(2 * GIB, "Adreno (TM) 650")).is_equal(QualityProfile.Rung.LOW)
	assert_int(AdaptiveQuality.tier_for(4 * GIB, "Adreno (TM) 650")).is_equal(QualityProfile.Rung.MEDIUM)
	assert_int(AdaptiveQuality.tier_for(8 * GIB, "Adreno (TM) 740")).is_equal(QualityProfile.Rung.HIGH)
	assert_int(AdaptiveQuality.tier_for(0, "")).is_equal(QualityProfile.Rung.MEDIUM)


func test_low_end_gpu_caps_tier() -> void:
	assert_int(AdaptiveQuality.tier_for(8 * GIB, "PowerVR Rogue GE8320")).is_equal(QualityProfile.Rung.LOW)
	assert_int(AdaptiveQuality.tier_for(4 * GIB, "Mali-G57 MC2")).is_equal(QualityProfile.Rung.LOW)
