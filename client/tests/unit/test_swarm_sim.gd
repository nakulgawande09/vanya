extends GdUnitTestSuite

const BOUNDS: Rect2 = Rect2(0, 0, 704, 960)


func _run(sim: SwarmSim, grid: SpatialHash, steps: int, target: Vector2) -> int:
	var contacts: int = 0
	for s: int in steps:
		grid.clear()
		for i: int in sim.capacity:
			if sim.is_active(i):
				grid.insert(i, sim.pos[i], sim.radius)
		grid.commit()
		contacts += sim.tick(1.0 / 30.0, target, 14.0, grid)
	return contacts


func test_units_spawn_then_seek_target() -> void:
	var sim: SwarmSim = SwarmSim.new(8, 14.0, 72.0, BOUNDS)
	var grid: SpatialHash = SpatialHash.new(BOUNDS, 64.0, 8)
	var i: int = sim.spawn(Vector2(100, 100), 30)
	assert_int(sim.state[i]).is_equal(SwarmSim.State.SPAWN)
	var start: float = sim.pos[i].distance_to(Vector2(400, 600))
	_run(sim, grid, 60, Vector2(400, 600))
	assert_int(sim.state[i]).is_not_equal(SwarmSim.State.SPAWN)
	assert_float(sim.pos[i].distance_to(Vector2(400, 600))).is_less(start - 50.0)


func test_deterministic() -> void:
	var a: SwarmSim = SwarmSim.new(8, 14.0, 72.0, BOUNDS)
	var b: SwarmSim = SwarmSim.new(8, 14.0, 72.0, BOUNDS)
	for sim: SwarmSim in [a, b]:
		for k: int in 5:
			sim.spawn(Vector2(100 + k * 20, 100), 30)
	_run(a, SpatialHash.new(BOUNDS, 64.0, 8), 90, Vector2(350, 500))
	_run(b, SpatialHash.new(BOUNDS, 64.0, 8), 90, Vector2(350, 500))
	assert_array(Array(a.pos)).is_equal(Array(b.pos))


func test_separation_keeps_units_apart() -> void:
	var sim: SwarmSim = SwarmSim.new(8, 14.0, 72.0, BOUNDS)
	for k: int in 6:
		sim.spawn(Vector2(300, 300), 30)
	_run(sim, SpatialHash.new(BOUNDS, 64.0, 8), 120, Vector2(300, 700))
	var min_d: float = INF
	for i: int in 6:
		for j: int in range(i + 1, 6):
			min_d = minf(min_d, sim.pos[i].distance_to(sim.pos[j]))
	assert_float(min_d).is_greater(8.0)


func test_damage_kill_and_free_slot() -> void:
	var sim: SwarmSim = SwarmSim.new(2, 14.0, 72.0, BOUNDS)
	var i: int = sim.spawn(Vector2(100, 100), 30)
	assert_bool(sim.damage(i, 10)).is_false()
	assert_bool(sim.damage(i, 25)).is_true()
	assert_bool(sim.is_active(i)).is_false()
	_run(sim, SpatialHash.new(BOUNDS, 64.0, 2), 20, Vector2.ZERO)
	assert_int(sim.state[i]).is_equal(SwarmSim.State.FREE)
	assert_int(sim.alive).is_equal(0)


func test_contacts_reported_and_rooted_units_stay() -> void:
	var sim: SwarmSim = SwarmSim.new(2, 14.0, 72.0, BOUNDS)
	var i: int = sim.spawn(Vector2(300, 300), 30)
	var grid: SpatialHash = SpatialHash.new(BOUNDS, 64.0, 2)
	_run(sim, grid, 15, Vector2(300, 300))
	assert_int(_run(sim, grid, 5, Vector2(305, 300))).is_greater(0)
	sim.root(i, 3.0)
	var before: Vector2 = sim.pos[i]
	_run(sim, grid, 30, Vector2(600, 800))
	assert_float(sim.pos[i].distance_to(before)).is_less(2.0)
