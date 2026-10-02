extends Node
## Headless CPU benchmark (standards §B.6): a grove with 40 beasts (30 Rotlings, 6 Thornbacks,
## 4 Wisps) and the hunter shooting, ticked at 30 Hz for 600 ticks. Measures the gameplay tick only
## (headless has no GPU) and prints one JSON line for the CI perf gate, then quits.
##   godot --headless --path client res://bench/bench_swarm_40.tscn

const TICKS: int = 600
const STEP: float = 1.0 / 30.0


func _ready() -> void:
	_run_bench.call_deferred()


func _run_bench() -> void:
	var run: GroveRun = (load("res://gameplay/run/grove_run.tscn") as PackedScene).instantiate() as GroveRun
	run.run_seed = 1234
	run.auto_start = false
	add_child(run)
	run.set_physics_process(false)
	run.start_grove(4)
	run.run.max_hp = 1000000
	run.run.hp = 1000000
	run.director.waves = [[]]
	var room: Rect2 = run.layout.walkable
	for i: int in 30:
		run.world.spawn(Ids.ROTLING, room.position + Vector2(40 + (i % 10) * 30, 60 + (i / 10) * 40))
	for i: int in 6:
		run.world.spawn(Ids.THORNBACK, room.position + Vector2(50 + i * 50, 300))
	for i: int in 4:
		run.world.spawn(Ids.WISP, room.position + Vector2(60 + i * 70, 200))
	await get_tree().process_frame
	var times: PackedFloat64Array = PackedFloat64Array()
	var mem_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	for t: int in TICKS:
		var start: int = Time.get_ticks_usec()
		run._physics_process(STEP)
		times.append((Time.get_ticks_usec() - start) / 1000.0)
		if run.world.alive_count() < 30:
			run.world.spawn(Ids.ROTLING, run.layout.portals[t % run.layout.portals.size()])
	times.sort()
	var total: float = 0.0
	for v: float in times:
		total += v
	var result: Dictionary = {
		"bench": "swarm_40", "ticks": TICKS,
		"tick_ms_mean": snappedf(total / TICKS, 0.001),
		"tick_ms_p95": snappedf(times[int(TICKS * 0.95)], 0.001),
		"tick_ms_max": snappedf(times[TICKS - 1], 0.001),
		"kills": run.run.kills,
		"static_mem_mb_delta": snappedf((Performance.get_monitor(Performance.MEMORY_STATIC) - mem_before) / 1048576.0, 0.01),
	}
	print(JSON.stringify(result))
	get_tree().quit()
