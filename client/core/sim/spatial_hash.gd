class_name SpatialHash
extends RefCounted
## Fixed-grid broadphase over a bounded room. Rebuilt once per tick with a counting sort, so
## inserting and querying never allocate (docs/standards.md §B.4). Handles are caller-defined ints.

var cell_size: float
var cols: int
var rows: int
var origin: Vector2

var _cell_start: PackedInt32Array = PackedInt32Array()
var _cell_count: PackedInt32Array = PackedInt32Array()
var _cell_of: PackedInt32Array = PackedInt32Array()
var _sorted: PackedInt32Array = PackedInt32Array()
var _handles: PackedInt32Array = PackedInt32Array()
var _positions: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0


func _init(bounds: Rect2, cell: float, capacity: int) -> void:
	cell_size = cell
	origin = bounds.position
	cols = maxi(1, ceili(bounds.size.x / cell))
	rows = maxi(1, ceili(bounds.size.y / cell))
	_cell_start.resize(cols * rows + 1)
	_cell_count.resize(cols * rows)
	_cell_of.resize(capacity)
	_sorted.resize(capacity)
	_handles.resize(capacity)
	_positions.resize(capacity)
	_radii.resize(capacity)


func capacity() -> int:
	return _handles.size()


func size() -> int:
	return _count


## Start a rebuild. Call insert() for every live entity, then commit().
func clear() -> void:
	_count = 0


func insert(handle: int, pos: Vector2, radius: float) -> void:
	if _count >= _handles.size():
		push_error("SpatialHash: capacity %d exceeded" % _handles.size())
		return
	_handles[_count] = handle
	_positions[_count] = pos
	_radii[_count] = radius
	_count += 1


func commit() -> void:
	_cell_count.fill(0)
	for i: int in _count:
		var c: int = _cell_index(_positions[i])
		_cell_of[i] = c
		_cell_count[c] += 1
	var run: int = 0
	for c: int in _cell_count.size():
		_cell_start[c] = run
		run += _cell_count[c]
	_cell_start[_cell_count.size()] = run
	_cell_count.fill(0)
	for i: int in _count:
		var c: int = _cell_of[i]
		_sorted[_cell_start[c] + _cell_count[c]] = i
		_cell_count[c] += 1


## Writes the handles of entries whose circle overlaps (center, radius) into `out` (pre-sized).
## Returns how many were written; stops when `out` is full.
func query_circle(center: Vector2, radius: float, out: PackedInt32Array) -> int:
	var n: int = 0
	var reach: float = radius + cell_size
	var c0: Vector2i = _cell_coords(center - Vector2(reach, reach))
	var c1: Vector2i = _cell_coords(center + Vector2(reach, reach))
	for cy: int in range(c0.y, c1.y + 1):
		for cx: int in range(c0.x, c1.x + 1):
			var c: int = cy * cols + cx
			for k: int in range(_cell_start[c], _cell_start[c + 1]):
				var i: int = _sorted[k]
				var r: float = radius + _radii[i]
				if center.distance_squared_to(_positions[i]) <= r * r:
					if n >= out.size():
						return n
					out[n] = _handles[i]
					n += 1
	return n


## The handle nearest to `center` within `max_range` (by centre distance), or -1.
func nearest(center: Vector2, max_range: float) -> int:
	var best: int = -1
	var best_d: float = max_range * max_range
	var c0: Vector2i = _cell_coords(center - Vector2(max_range, max_range))
	var c1: Vector2i = _cell_coords(center + Vector2(max_range, max_range))
	for cy: int in range(c0.y, c1.y + 1):
		for cx: int in range(c0.x, c1.x + 1):
			var c: int = cy * cols + cx
			for k: int in range(_cell_start[c], _cell_start[c + 1]):
				var i: int = _sorted[k]
				var d: float = center.distance_squared_to(_positions[i])
				if d <= best_d:
					best_d = d
					best = _handles[i]
	return best


func _cell_coords(p: Vector2) -> Vector2i:
	var local: Vector2 = (p - origin) / cell_size
	return Vector2i(clampi(floori(local.x), 0, cols - 1), clampi(floori(local.y), 0, rows - 1))


func _cell_index(p: Vector2) -> int:
	var c: Vector2i = _cell_coords(p)
	return c.y * cols + c.x
