extends GdUnitTestSuite

const CELL: float = 32.0


func _field(blocked: Array[Vector2i], slow: Array[Vector2i] = []) -> FlowField:
	var f: FlowField = FlowField.new(8, 8, CELL)
	var codes: PackedByteArray = PackedByteArray()
	codes.resize(64)
	codes.fill(FlowField.FREE)
	for c: Vector2i in blocked:
		codes[c.y * 8 + c.x] = FlowField.BLOCKED
	for c: Vector2i in slow:
		codes[c.y * 8 + c.x] = FlowField.SLOW
	f.set_grid(codes)
	return f


func _at(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func test_distances_go_around_a_wall() -> void:
	var wall: Array[Vector2i] = []
	for y: int in range(0, 7):
		wall.append(Vector2i(4, y))
	var f: FlowField = _field(wall)
	f.update(0.0, _at(Vector2i(6, 0)))
	assert_int(f.distance_at(_at(Vector2i(2, 0)))).is_equal(4 + 2 * 7)
	# From behind the wall the field points down toward the gap, not straight at the target.
	var dir: Vector2 = f.direction(_at(Vector2i(3, 0)), _at(Vector2i(6, 0)))
	assert_float(dir.y).is_greater(0.5)


func test_slide_never_enters_blocked_cells() -> void:
	var f: FlowField = _field([Vector2i(3, 3)])
	var p: Vector2 = _at(Vector2i(2, 3))
	for i: int in 20:
		p = f.slide(p, Vector2(4, 1))
		assert_bool(f.is_blocked(p)).is_false()


func test_slow_cells_and_rebuild_on_target_move() -> void:
	var f: FlowField = _field([], [Vector2i(1, 1)])
	assert_float(f.speed_factor(_at(Vector2i(1, 1)))).is_equal(FlowField.SLOW_FACTOR)
	assert_float(f.speed_factor(_at(Vector2i(2, 2)))).is_equal(1.0)
	f.update(0.0, _at(Vector2i(0, 0)))
	assert_int(f.distance_at(_at(Vector2i(7, 7)))).is_equal(14)
	f.update(0.0, _at(Vector2i(7, 7)))
	assert_int(f.distance_at(_at(Vector2i(7, 7)))).is_equal(0)
