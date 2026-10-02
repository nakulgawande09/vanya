class_name FlowField
extends RefCounted
## Distance field toward one target over a room grid (BFS, 4-neighbour), so beasts walk around
## logs and idols instead of into them (dev-plan §6.1 pathing). Rebuilt when the target changes
## cell or every `refresh` seconds; all arrays are reused, nothing allocates per tick.
## Cell codes: 0 blocked, 1 free, 2 slow (walkable at SLOW_FACTOR speed).

const BLOCKED: int = 0
const FREE: int = 1
const SLOW: int = 2
const SLOW_FACTOR: float = 0.6
const UNREACHED: int = 1 << 20

var cols: int
var rows: int
var cell_size: float
var refresh: float = 0.2

var _grid: PackedByteArray = PackedByteArray()
var _dist: PackedInt32Array = PackedInt32Array()
var _queue: PackedInt32Array = PackedInt32Array()
var _target: Vector2i = Vector2i(-1, -1)
var _age: float = 0.0
var _offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


func _init(grid_cols: int, grid_rows: int, cell: float) -> void:
	cols = grid_cols
	rows = grid_rows
	cell_size = cell
	_grid.resize(cols * rows)
	_grid.fill(FREE)
	_dist.resize(cols * rows)
	_queue.resize(cols * rows)


## Sets passability from codes (BLOCKED / FREE / SLOW), one byte per cell, row-major.
func set_grid(codes: PackedByteArray) -> void:
	_grid = codes.duplicate()
	_target = Vector2i(-1, -1)


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / cell_size), 0, cols - 1), clampi(floori(p.y / cell_size), 0, rows - 1))


func code_at(p: Vector2) -> int:
	var c: Vector2i = cell_of(p)
	return _grid[c.y * cols + c.x]


func is_blocked(p: Vector2) -> bool:
	return p.x < 0.0 or p.y < 0.0 or code_at(p) == BLOCKED


func speed_factor(p: Vector2) -> float:
	return SLOW_FACTOR if code_at(p) == SLOW else 1.0


## Rebuilds the field if the target moved to another cell or the field is stale.
func update(delta: float, target: Vector2) -> void:
	_age += delta
	var t: Vector2i = cell_of(target)
	if t == _target and _age < refresh:
		return
	_age = 0.0
	_target = t
	_dist.fill(UNREACHED)
	var start: int = t.y * cols + t.x
	_dist[start] = 0
	_queue[0] = start
	var head: int = 0
	var tail: int = 1
	while head < tail:
		var i: int = _queue[head]
		head += 1
		var cx: int = i % cols
		var cy: int = i / cols
		for k: int in 4:
			var nx: int = cx + _offsets[k].x
			var ny: int = cy + _offsets[k].y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var ni: int = ny * cols + nx
			if _grid[ni] == BLOCKED or _dist[ni] != UNREACHED:
				continue
			_dist[ni] = _dist[i] + 1
			_queue[tail] = ni
			tail += 1


func distance_at(p: Vector2) -> int:
	var c: Vector2i = cell_of(p)
	return _dist[c.y * cols + c.x]


## Unit direction to walk from `p` toward the target, following the field; the straight line
## when already in (or next to) the target's cell or when the cell is unreachable.
func direction(p: Vector2, target: Vector2) -> Vector2:
	var c: Vector2i = cell_of(p)
	var here: int = _dist[c.y * cols + c.x]
	if here <= 1 or here >= UNREACHED:
		return (target - p).normalized()
	var best: int = here
	var best_cell: Vector2i = c
	for k: int in 8:
		var o: Vector2i = _offsets[k]
		var n: Vector2i = c + o
		if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
			continue
		var d: int = _dist[n.y * cols + n.x]
		if d >= best:
			continue
		# No corner cutting past a blocked cell.
		if k >= 4 and (_grid[c.y * cols + n.x] == BLOCKED or _grid[n.y * cols + c.x] == BLOCKED):
			continue
		best = d
		best_cell = n
	if best_cell == c:
		return (target - p).normalized()
	var aim: Vector2 = (Vector2(best_cell) + Vector2(0.5, 0.5)) * cell_size
	return (aim - p).normalized()


## The centre of the nearest walkable cell to `p` (itself if already walkable).
func nearest_free(p: Vector2) -> Vector2:
	if not is_blocked(p):
		return p
	var c: Vector2i = cell_of(p)
	for r: int in range(1, maxi(cols, rows)):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or _grid[n.y * cols + n.x] == BLOCKED:
					continue
				return (Vector2(n) + Vector2(0.5, 0.5)) * cell_size
	return p


## Moves `p` by `step`, sliding along blocked cells instead of entering them.
func slide(p: Vector2, step: Vector2) -> Vector2:
	var full: Vector2 = p + step
	if not is_blocked(full):
		return full
	var x_only: Vector2 = Vector2(p.x + step.x, p.y)
	if not is_blocked(x_only):
		return x_only
	var y_only: Vector2 = Vector2(p.x, p.y + step.y)
	if not is_blocked(y_only):
		return y_only
	return p
