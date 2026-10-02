extends GdUnitTestSuite

var _rules: RoomRules


func before() -> void:
	_rules = load("res://pcg/room_rules.tres") as RoomRules


func test_every_chunk_is_well_formed() -> void:
	assert_int(_rules.chunks.size()).is_greater_equal(15)
	for c: ChunkDef in _rules.chunks:
		assert_bool(c.is_valid()).override_failure_message("chunk %s malformed" % c.id).is_true()
		for r: String in c.rows:
			# Logs are two tiles wide.
			var runs: PackedStringArray = r.split(".", false)
			for run: String in runs:
				if run.contains("#"):
					assert_int(run.count("#") % 2).override_failure_message("odd log in %s" % c.id).is_equal(0)


func test_many_rooms_are_valid_and_rarely_fall_back() -> void:
	var fallbacks: int = 0
	var count: int = 0
	for s: int in 120:
		for g: int in [1, 2, 3, 5, 8]:
			var plan: RoomPlan = RoomGenerator.generate(_rules, s * 131 + 3, g)
			count += 1
			if plan.fallback:
				fallbacks += 1
			assert_array(Array(RoomValidator.validate(plan, _rules))).is_empty()
	assert_float(float(fallbacks) / count).is_less(0.05)


func test_deterministic_per_seed_and_grove() -> void:
	var a: RoomPlan = RoomGenerator.generate(_rules, 42, 3)
	var b: RoomPlan = RoomGenerator.generate(_rules, 42, 3)
	assert_int(a.digest()).is_equal(b.digest())
	assert_int(RoomGenerator.generate(_rules, 42, 4).digest()).is_not_equal(a.digest())


func test_boss_groves_use_the_hollow() -> void:
	for s: int in 10:
		var plan: RoomPlan = RoomGenerator.generate(_rules, s, 5)
		if not plan.fallback:
			assert_bool(plan.family == &"boss_hollow" or plan.family == &"open_glade").is_true()


func test_room_rules_hold() -> void:
	var plan: RoomPlan = RoomGenerator.generate(_rules, 7, 6)
	assert_int(plan.portals.size()).is_between(_rules.portals_min, _rules.portals_max)
	var dist: PackedInt32Array = RoomValidator.distances(plan, RoomPlan.START_CELL)
	for p: Vector2i in plan.portals:
		assert_int(dist[p.y * RoomPlan.COLS + p.x]).is_greater_equal(_rules.min_portal_path)
	assert_int(plan.torches.size()).is_between(_rules.torches_min, _rules.torches_max)
	assert_int(plan.tile(RoomPlan.GATE_CELL)).is_equal(RoomPlan.Tile.GATE)


func test_validator_rejects_a_walled_off_gate() -> void:
	var plan: RoomPlan = RoomGenerator.generate(_rules, 1, 1)
	for x: int in range(1, 12):
		plan.set_tile(Vector2i(x, 10), RoomPlan.Tile.OBSTACLE)
	var problems: PackedStringArray = RoomValidator.validate(plan, _rules)
	assert_bool(problems.has("gate unreachable")).is_true()


func test_tutorial_room_has_a_cage_and_portal() -> void:
	var plan: RoomPlan = RoomGenerator.tutorial(_rules)
	assert_bool(plan.has_cage()).is_true()
	assert_int(plan.portals.size()).is_greater_equal(1)
	assert_array(Array(RoomValidator.validate(plan, _rules))).is_empty()


func test_golden_seeds_match() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/rooms.json"))
	for key: Variant in golden.keys():
		var parts: PackedStringArray = str(key).split(":")
		var plan: RoomPlan = RoomGenerator.generate(_rules, parts[0].to_int(), parts[1].to_int())
		assert_str(str(plan.digest())).override_failure_message("room %s changed; regenerate tests/golden/rooms.json if intended" % key) \
				.is_equal(str(golden[key]))
