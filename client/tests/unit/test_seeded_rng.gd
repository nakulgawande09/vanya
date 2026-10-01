extends GdUnitTestSuite


func _sequence(rng: SeededRng, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in count:
		out.append(rng.next_int(0, 1_000_000))
	return out


func test_same_seed_same_sequence() -> void:
	var a: SeededRng = SeededRng.new(42, 3, &"layout")
	var b: SeededRng = SeededRng.new(42, 3, &"layout")
	assert_array(_sequence(a, 50)).is_equal(_sequence(b, 50))


func test_streams_are_independent() -> void:
	var layout: SeededRng = SeededRng.new(42, 3, &"layout")
	var waves: SeededRng = SeededRng.new(42, 3, &"waves")
	assert_array(_sequence(layout, 20)).is_not_equal(_sequence(waves, 20))


func test_room_index_changes_sequence() -> void:
	var room_a: SeededRng = SeededRng.new(42, 0, &"layout")
	var room_b: SeededRng = SeededRng.new(42, 1, &"layout")
	assert_array(_sequence(room_a, 20)).is_not_equal(_sequence(room_b, 20))


func test_state_restore_replays() -> void:
	var rng: SeededRng = SeededRng.new(7)
	var state: int = rng.get_state()
	var first: Array[int] = _sequence(rng, 10)
	rng.set_state(state)
	assert_array(_sequence(rng, 10)).is_equal(first)


func test_next_int_stays_in_range() -> void:
	var rng: SeededRng = SeededRng.new(99)
	for i: int in 500:
		assert_int(rng.next_int(-3, 3)).is_between(-3, 3)
