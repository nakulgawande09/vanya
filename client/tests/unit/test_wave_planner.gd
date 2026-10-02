extends GdUnitTestSuite


func _plan(grove: int, run_seed: int = 7) -> Array[Array]:
	return WavePlanner.plan(GameData.waves(), grove, GameData.archetypes(), SeededRng.new(run_seed, grove, &"waves"))


func _cost(waves: Array[Array]) -> int:
	var defs: Dictionary[StringName, ArchetypeDef] = GameData.archetypes()
	var total: int = 0
	for wave: Array in waves:
		for id: Variant in wave:
			total += defs[id as StringName].budget_cost
	return total


func test_grove_one_is_rotlings_only_within_budget() -> void:
	var waves: Array[Array] = _plan(1)
	assert_int(waves.size()).is_equal(3)
	for wave: Array in waves:
		for id: Variant in wave:
			assert_str(str(id)).is_equal("rotling")
	assert_int(_cost(waves)).is_less_equal(WavePlanner.room_budget(GameData.waves(), 1) + 1)


func test_later_groves_unlock_archetypes_and_grow() -> void:
	var seen: Dictionary = {}
	for s: int in 10:
		for wave: Array in _plan(4, s):
			for id: Variant in wave:
				seen[str(id)] = true
	assert_bool(seen.has("thornback") and seen.has("wisp")).is_true()
	assert_int(_cost(_plan(4))).is_greater(_cost(_plan(1)))


func test_boss_every_fifth_grove() -> void:
	var waves: Array[Array] = _plan(5)
	assert_array(waves[0]).is_equal([&"rotheart"])
	assert_bool(WavePlanner.is_boss_grove(GameData.waves(), 10)).is_true()
	assert_bool(WavePlanner.is_boss_grove(GameData.waves(), 6)).is_false()


func test_deterministic_per_seed() -> void:
	assert_array(_plan(6, 42)).is_equal(_plan(6, 42))
