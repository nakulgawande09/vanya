class_name RoomValidator
extends RefCounted
## Rejects rooms that would play badly (dev-plan §6.2): the gate, every portal and the cage
## must be reachable from the start; enough open floor; portals far enough (by path) from the
## start to react; the gate apron clear. Returns the list of problems (empty = valid).


static func validate(plan: RoomPlan, rules: RoomRules) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var dist: PackedInt32Array = distances(plan, RoomPlan.START_CELL)
	if _d(dist, RoomPlan.GATE_APRON) < 0:
		problems.append("gate unreachable")
	for x: int in range(5, 8):
		for y: int in range(3, 5):
			if not plan.is_walkable(Vector2i(x, y)):
				problems.append("gate apron blocked at %d,%d" % [x, y])
	if plan.portals.size() < rules.portals_min:
		problems.append("only %d portals" % plan.portals.size())
	for p: Vector2i in plan.portals:
		var d: int = _d(dist, p)
		if d < 0:
			problems.append("portal %s unreachable" % p)
		elif d < rules.min_portal_path:
			problems.append("portal %s only %d tiles from start" % [p, d])
		if plan.tile(p) != RoomPlan.Tile.FLOOR:
			problems.append("portal %s not on floor" % p)
	if plan.has_cage() and _d(dist, plan.cage) < 0:
		problems.append("cage unreachable")
	var open: int = 0
	var total: int = 0
	var interior: Rect2i = RoomPlan.INTERIOR
	for y: int in range(interior.position.y, interior.end.y):
		for x: int in range(interior.position.x, interior.end.x):
			total += 1
			if plan.is_walkable(Vector2i(x, y)):
				open += 1
	if float(open) / total < rules.min_open_ratio:
		problems.append("open floor %.0f%% below minimum" % (100.0 * open / total))
	return problems


## 4-neighbour BFS path lengths in tiles from `from` (-1 = unreachable).
static func distances(plan: RoomPlan, from: Vector2i) -> PackedInt32Array:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(RoomPlan.COLS * RoomPlan.ROWS)
	dist.fill(-1)
	var queue: PackedInt32Array = PackedInt32Array()
	queue.append(from.y * RoomPlan.COLS + from.x)
	dist[queue[0]] = 0
	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var c: Vector2i = Vector2i(i % RoomPlan.COLS, i / RoomPlan.COLS)
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if not plan.is_walkable(n):
				continue
			var ni: int = n.y * RoomPlan.COLS + n.x
			if dist[ni] < 0:
				dist[ni] = dist[i] + 1
				queue.append(ni)
	return dist


static func _d(dist: PackedInt32Array, c: Vector2i) -> int:
	return dist[c.y * RoomPlan.COLS + c.x] if RoomPlan.in_bounds(c) else -1
