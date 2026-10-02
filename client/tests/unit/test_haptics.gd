extends GdUnitTestSuite
## Haptics map rules (Audio Bible A2): per-key cooldown, ≤ 4 pulses/s, Off/Low/Full, none in ads.


func _haptics() -> FakeHaptics:
	var h: FakeHaptics = FakeHaptics.new()
	h.configure(FeelTuning.new())
	return h


func test_per_key_cooldown() -> void:
	var h: FakeHaptics = _haptics()
	assert_bool(h.pulse(&"hurt", 1000)).is_true()
	assert_bool(h.pulse(&"hurt", 1100)).is_false()  # hurt cooldown 250 ms
	assert_bool(h.pulse(&"hurt", 1300)).is_true()


func test_global_budget_four_per_second() -> void:
	var h: FakeHaptics = _haptics()
	var keys: Array[StringName] = [&"cage", &"gate", &"purchase", &"crit", &"slam"]
	var fired: int = 0
	for i: int in keys.size():
		if h.pulse(keys[i], 1000 + i * 10):
			fired += 1
	assert_int(fired).is_equal(4)
	assert_bool(h.pulse(&"cage", 2100)).is_true()


func test_levels_scale_amplitude_and_off_silences() -> void:
	var h: FakeHaptics = _haptics()
	h.level = HapticsService.Level.LOW
	h.pulse(&"god", 0)
	assert_float(h.pulses[0].y).is_equal_approx(0.5, 0.001)
	assert_float(h.pulses[0].x).is_equal(80.0)
	h.level = HapticsService.Level.OFF
	assert_bool(h.pulse(&"slam", 5000)).is_false()


func test_never_during_ads_and_unknown_keys_ignored() -> void:
	var h: FakeHaptics = _haptics()
	h.suppressed = true
	assert_bool(h.pulse(&"hurt", 0)).is_false()
	h.suppressed = false
	assert_bool(h.pulse(&"nope", 0)).is_false()
	assert_int(h.pulses.size()).is_equal(0)
