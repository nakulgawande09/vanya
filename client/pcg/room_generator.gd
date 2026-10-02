class_name RoomGenerator
extends RefCounted
## PCG v1 (dev-plan §6.2): stack three authored chunks between the gate and start strips with
## WFC-lite edge matching and random mirroring, scatter torches and bushes, pick portals and the
## cage by distance rules, then validate. Up to `max_attempts` reseeds, then a hand-made room.
## Integer grid math only and no nodes, so it runs on a WorkerThreadPool and can be ported to
## Python for server-side validation.


static func generate(rules: RoomRules, run_seed: int, grove: int) -> RoomPlan:
	var index: Dictionary[StringName, ChunkDef] = _index(rules)
	for attempt: int in rules.max_attempts:
		var rng: SeededRng = SeededRng.new(run_seed + attempt * 7919, grove, &"layout")
		var ids: PackedStringArray = _pick_chunks(rules, index, rng, grove)
		if ids.is_empty():
			continue
		var plan: RoomPlan = _build(rules, index, ids, rng, grove)
		if RoomValidator.validate(plan, rules).is_empty():
			plan.attempts = attempt + 1
			return plan
	var fallback_ids: PackedStringArray = rules.fallback_rooms[posmod(grove + run_seed, rules.fallback_rooms.size())]
	var plan: RoomPlan = _build(rules, index, fallback_ids, SeededRng.new(run_seed, grove, &"fallback"), grove, false)
	plan.fallback = true
	plan.attempts = rules.max_attempts
	return plan


## The fixed first-run tutorial room: one portal, a log, a caged bird.
static func tutorial(rules: RoomRules) -> RoomPlan:
	var plan: RoomPlan = _build(rules, _index(rules), rules.tutorial_room, SeededRng.new(1, 0, &"tutorial"), 0, false)
	plan.family = &"tutorial"
	return plan


static func _index(rules: RoomRules) -> Dictionary[StringName, ChunkDef]:
	var index: Dictionary[StringName, ChunkDef] = {}
	for c: ChunkDef in rules.chunks:
		index[c.id] = c
	return index


static func _pick_chunks(rules: RoomRules, index: Dictionary[StringName, ChunkDef], rng: SeededRng, grove: int) -> PackedStringArray:
	var boss: bool = rules.boss_every > 0 and grove % rules.boss_every == 0
	var family: StringName = rules.boss_family if boss else StringName(rules.families[rng.pick_index(rules.families.size())])
	var own: Array[ChunkDef] = []
	var glade: Array[ChunkDef] = []
	for c: ChunkDef in rules.chunks:
		if c.family == family:
			own.append(c)
		if c.family == &"open_glade":
			glade.append(c)
	var ids: PackedStringArray = PackedStringArray()
	var prev: ChunkDef = null
	var prev_mirror: bool = false
	for slot: int in RoomPlan.CHUNK_ROWS.size():
		var placed: bool = false
		for tries: int in 8:
			var pool: Array[ChunkDef] = own if (own.size() > 0 and rng.chance(rules.family_share)) else glade
			var c: ChunkDef = _weighted(pool, rng)
			var mirror: bool = rng.chance(0.5)
			if prev != null and _passages(prev, prev_mirror, c, mirror) < rules.min_edge_passages:
				continue
			ids.append(("~" if mirror else "") + String(c.id))
			prev = c
			prev_mirror = mirror
			placed = true
			break
		if not placed:
			return PackedStringArray()
	return ids


static func _passages(upper: ChunkDef, upper_mirror: bool, lower: ChunkDef, lower_mirror: bool) -> int:
	var a: int = _mask(upper, ChunkDef.HEIGHT - 1, upper_mirror)
	var b: int = _mask(lower, 0, lower_mirror)
	var both: int = a & b
	var n: int = 0
	while both != 0:
		n += both & 1
		both >>= 1
	return n


static func _mask(c: ChunkDef, y: int, mirror: bool) -> int:
	var m: int = 0
	for x: int in ChunkDef.WIDTH:
		var ch: String = c.at(x, y, mirror)
		if ch != "#" and ch != "I":
			m |= 1 << x
	return m


static func _weighted(pool: Array[ChunkDef], rng: SeededRng) -> ChunkDef:
	var total: float = 0.0
	for c: ChunkDef in pool:
		total += c.weight
	var r: float = rng.next_float() * total
	for c: ChunkDef in pool:
		r -= c.weight
		if r <= 0.0:
			return c
	return pool[pool.size() - 1]


## Paints walls, strips and chunks, then places portals, cage, torches and bushes.
## `ids` may prefix a chunk id with "~" to mirror it.
static func _build(rules: RoomRules, index: Dictionary[StringName, ChunkDef], ids: PackedStringArray,
		rng: SeededRng, grove: int, random_cage: bool = true) -> RoomPlan:
	var plan: RoomPlan = RoomPlan.new()
	plan.grove = grove
	plan.chunk_ids = ids
	var interior: Rect2i = RoomPlan.INTERIOR
	for y: int in range(interior.position.y, interior.end.y):
		for x: int in range(interior.position.x, interior.end.x):
			plan.set_tile(Vector2i(x, y), RoomPlan.Tile.FLOOR)
	plan.set_tile(RoomPlan.GATE_CELL, RoomPlan.Tile.GATE)
	var spots_p: Array[Vector2i] = []
	var spots_c: Array[Vector2i] = []
	for slot: int in ids.size():
		var raw: String = ids[slot]
		var mirror: bool = raw.begins_with("~")
		var c: ChunkDef = index[StringName(raw.trim_prefix("~"))]
		if c.family != &"open_glade" or plan.family == &"":
			plan.family = c.family
		var top: int = RoomPlan.CHUNK_ROWS[slot]
		for y: int in ChunkDef.HEIGHT:
			var x: int = 0
			while x < ChunkDef.WIDTH:
				var ch: String = c.at(x, y, mirror)
				var cell: Vector2i = Vector2i(interior.position.x + x, top + y)
				match ch:
					"#":
						plan.set_tile(cell, RoomPlan.Tile.OBSTACLE)
						if x + 1 < ChunkDef.WIDTH and c.at(x + 1, y, mirror) == "#":
							plan.set_tile(cell + Vector2i.RIGHT, RoomPlan.Tile.OBSTACLE)
							plan.logs.append(cell)
							x += 1
					"I":
						plan.set_tile(cell, RoomPlan.Tile.OBSTACLE)
						plan.idols.append(cell)
					"~":
						plan.set_tile(cell, RoomPlan.Tile.SLOW)
						if x + 1 < ChunkDef.WIDTH and c.at(x + 1, y, mirror) == "~":
							plan.set_tile(cell + Vector2i.RIGHT, RoomPlan.Tile.SLOW)
							plan.roots.append(cell)
							x += 1
						else:
							plan.roots.append(cell)
					"P":
						spots_p.append(cell)
					"C":
						spots_c.append(cell)
				x += 1
	_place_portals(plan, rules, rng, spots_p, grove)
	_place_cage(plan, rules, rng, spots_c, grove, random_cage)
	_place_torches(plan, rules, rng)
	_place_bushes(plan, rng)
	return plan


static func _place_portals(plan: RoomPlan, rules: RoomRules, rng: SeededRng, spots: Array[Vector2i], grove: int) -> void:
	var want: int = clampi(rules.portals_min + grove / 3, rules.portals_min, rules.portals_max)
	_shuffle(spots, rng)
	for s: Vector2i in spots:
		if plan.portals.size() >= want:
			break
		if _far_from(s, plan.portals, rules.portal_min_apart):
			plan.portals.append(s)
	var guard: int = 0
	while plan.portals.size() < want and guard < 60:
		guard += 1
		var c: Vector2i = Vector2i(rng.next_int(2, 10), rng.next_int(RoomPlan.CHUNK_ROWS[0], RoomPlan.CHUNK_ROWS[1] + 4))
		if plan.tile(c) == RoomPlan.Tile.FLOOR and _far_from(c, plan.portals, rules.portal_min_apart):
			plan.portals.append(c)


static func _place_cage(plan: RoomPlan, rules: RoomRules, rng: SeededRng, spots: Array[Vector2i], grove: int, random_cage: bool) -> void:
	var wants: bool = not spots.is_empty() if not random_cage else (grove == 1 or rng.chance(rules.cage_chance))
	if not wants:
		return
	_shuffle(spots, rng)
	for s: Vector2i in spots:
		if _far_from(s, plan.portals, rules.cage_min_portal_distance):
			plan.cage = s
			return
	for guard: int in 60:
		var c: Vector2i = Vector2i(rng.next_int(2, 10), rng.next_int(RoomPlan.CHUNK_ROWS[0] + 2, RoomPlan.CHUNK_ROWS[2] + 4))
		if plan.tile(c) == RoomPlan.Tile.FLOOR and _far_from(c, plan.portals, rules.cage_min_portal_distance):
			plan.cage = c
			return


## Poisson-style scatter along the side walls: alternating sides, at least N rows apart.
static func _place_torches(plan: RoomPlan, rules: RoomRules, rng: SeededRng) -> void:
	var count: int = rng.next_int(rules.torches_min, rules.torches_max)
	var side: int = rng.next_int(0, 1)
	var row: int = RoomPlan.CHUNK_ROWS[0] + rng.next_int(0, 3)
	while plan.torches.size() < count and row < RoomPlan.INTERIOR.end.y - 2:
		var col: int = 1 if side == 0 else RoomPlan.COLS - 2
		var c: Vector2i = Vector2i(col, row)
		if plan.tile(c) == RoomPlan.Tile.FLOOR and c != plan.cage and not plan.portals.has(c):
			plan.torches.append(c)
			side = 1 - side
			row += rules.torch_min_rows_apart + rng.next_int(0, 2)
		else:
			row += 1


static func _place_bushes(plan: RoomPlan, rng: SeededRng) -> void:
	var row: int = 4 + rng.next_int(0, 2)
	var side: int = rng.next_int(0, 1)
	while row < RoomPlan.ROWS - 2:
		plan.bushes.append(Vector2i(0 if side == 0 else RoomPlan.COLS - 1, row))
		side = 1 - side
		row += rng.next_int(3, 5)


static func _far_from(c: Vector2i, others: Array[Vector2i], min_dist: int) -> bool:
	for o: Vector2i in others:
		if absi(o.x - c.x) + absi(o.y - c.y) < min_dist:
			return false
	return true


static func _shuffle(arr: Array[Vector2i], rng: SeededRng) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.next_int(0, i)
		var t: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = t
