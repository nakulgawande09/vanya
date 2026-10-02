extends GdUnitTestSuite

var _out: PackedInt32Array = PackedInt32Array()


func before_test() -> void:
	_out.resize(16)


func _grid() -> SpatialHash:
	var h: SpatialHash = SpatialHash.new(Rect2(0, 0, 704, 960), 64.0, 32)
	h.clear()
	h.insert(1, Vector2(100, 100), 10.0)
	h.insert(2, Vector2(130, 100), 10.0)
	h.insert(3, Vector2(600, 900), 10.0)
	h.commit()
	return h


func test_query_finds_overlaps_only() -> void:
	var h: SpatialHash = _grid()
	var n: int = h.query_circle(Vector2(100, 100), 5.0, _out)
	assert_int(n).is_equal(1)
	assert_int(_out[0]).is_equal(1)
	n = h.query_circle(Vector2(115, 100), 10.0, _out)
	assert_int(n).is_equal(2)


func test_query_across_cells_and_edges() -> void:
	var h: SpatialHash = _grid()
	assert_int(h.query_circle(Vector2(704, 960), 120.0, _out)).is_equal(1)
	assert_int(h.query_circle(Vector2(-50, -50), 10.0, _out)).is_equal(0)


func test_nearest() -> void:
	var h: SpatialHash = _grid()
	assert_int(h.nearest(Vector2(140, 100), 200.0)).is_equal(2)
	assert_int(h.nearest(Vector2(400, 500), 50.0)).is_equal(-1)


func test_rebuild_clears_previous_entries() -> void:
	var h: SpatialHash = _grid()
	h.clear()
	h.insert(9, Vector2(10, 10), 4.0)
	h.commit()
	assert_int(h.size()).is_equal(1)
	assert_int(h.nearest(Vector2(100, 100), 500.0)).is_equal(9)


func test_out_buffer_bounds_results() -> void:
	var h: SpatialHash = SpatialHash.new(Rect2(0, 0, 200, 200), 50.0, 64)
	h.clear()
	for i: int in 40:
		h.insert(i, Vector2(100, 100), 5.0)
	h.commit()
	assert_int(h.query_circle(Vector2(100, 100), 5.0, _out)).is_equal(_out.size())
