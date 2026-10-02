extends GdUnitTestSuite
## Voice pool rules (Audio Bible A5): polyphony, cooldowns, stealing by tier, P0 never stolen.

var _pool: SfxPool


func before_test() -> void:
	_pool = auto_free(SfxPool.new()) as SfxPool
	add_child(_pool)


func _entry(id: StringName, tier: AudioEntry.Tier, poly: int = 8, cooldown: int = 0) -> AudioEntry:
	var e: AudioEntry = AudioEntry.new()
	e.id = id
	e.tier = tier
	e.poly = poly
	e.cooldown_ms = cooldown
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	e.stream = gen
	return e


func test_polyphony_cap_restarts_the_oldest_instance() -> void:
	var e: AudioEntry = _entry(&"a", AudioEntry.Tier.P2, 2)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 0)).is_equal(0)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 1)).is_equal(1)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 2)).is_equal(0)
	assert_int(_pool.voices_of(&"a")).is_equal(2)


func test_cooldown_skips_rapid_repeats() -> void:
	var e: AudioEntry = _entry(&"b", AudioEntry.Tier.P2, 8, 100)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 1000)).is_greater_equal(0)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 1050)).is_equal(-1)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 1101)).is_greater_equal(0)
	assert_int(_pool.cooldown_skips).is_equal(1)


func test_full_pool_steals_lowest_tier_oldest_first_and_never_p0() -> void:
	var p0: AudioEntry = _entry(&"p0", AudioEntry.Tier.P0)
	var p4: AudioEntry = _entry(&"p4", AudioEntry.Tier.P4)
	for i: int in 6:
		_pool.play(p0, AudioService.NO_POS, 1.0, 0.0, i)
	for i: int in 6:
		_pool.play(p4, AudioService.NO_POS, 1.0, 0.0, 10 + i)
	assert_int(_pool.active_count()).is_equal(SfxPool.FLAT)
	var p2: AudioEntry = _entry(&"p2", AudioEntry.Tier.P2)
	var v: int = _pool.play(p2, AudioService.NO_POS, 1.0, 0.0, 100)
	assert_int(v).is_equal(6)  # the oldest P4 voice
	assert_int(_pool.steals).is_equal(1)
	for i: int in 5:
		_pool.play(p2, AudioService.NO_POS, 1.0, 0.0, 200 + i)
	assert_int(_pool.voices_of(&"p0")).is_equal(6)
	# Only P0 and P2 left: a new P3 is dropped, never steals a more important voice.
	assert_int(_pool.play(_entry(&"p3", AudioEntry.Tier.P3), AudioService.NO_POS, 1.0, 0.0, 300)).is_equal(-1)
	assert_int(_pool.drops).is_equal(1)


func test_all_p0_and_p1_drops_new_p2() -> void:
	var p1: AudioEntry = _entry(&"p1", AudioEntry.Tier.P1, SfxPool.FLAT)
	for i: int in SfxPool.FLAT:
		_pool.play(p1, AudioService.NO_POS, 1.0, 0.0, i)
	assert_int(_pool.play(_entry(&"x", AudioEntry.Tier.P2), AudioService.NO_POS, 1.0, 0.0, 50)).is_equal(-1)
	assert_int(_pool.play(_entry(&"y", AudioEntry.Tier.P0), AudioService.NO_POS, 1.0, 0.0, 51)).is_greater_equal(0)


func test_panned_entries_use_the_four_2d_voices() -> void:
	var e: AudioEntry = _entry(&"pan", AudioEntry.Tier.P2)
	e.pan = true
	var v: int = _pool.play(e, Vector2(100, 100), 1.0, 0.0, 0)
	assert_int(v).is_greater_equal(SfxPool.FLAT)
	assert_int(_pool.play(e, AudioService.NO_POS, 1.0, 0.0, 1)).is_less(SfxPool.FLAT)


func test_loops_are_never_stolen() -> void:
	var loop: AudioEntry = _entry(&"loop", AudioEntry.Tier.P4)
	loop.loop = true
	for i: int in SfxPool.FLAT:
		var e: AudioEntry = _entry(StringName("l%d" % i), AudioEntry.Tier.P4)
		e.loop = true
		_pool.play(e, AudioService.NO_POS, 1.0, 0.0, i)
	assert_int(_pool.play(_entry(&"z", AudioEntry.Tier.P1), AudioService.NO_POS, 1.0, 0.0, 99)).is_equal(-1)
