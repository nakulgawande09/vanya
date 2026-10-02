class_name WaveDirector
extends RefCounted
## Runs a room's waves through its spawn portals: open → spawn the wave's beasts one by one →
## wait until they fall → relax → next wave. The intensity director (dev-plan §7.3) will later
## stretch or shorten the relax windows; for now it guarantees a spirit drop when the hunter is low.

signal wave_started(index: int, total: int)
signal portals_changed(open: bool)
signal room_cleared

enum Phase { WARMUP, SPAWNING, FIGHTING, RELAX, CLEARED }

const WARMUP: float = 1.2
const SPAWN_INTERVAL: float = 0.28

var phase: Phase = Phase.WARMUP
var waves: Array[Array] = []
var wave_index: int = -1
var relax_time: float = 5.0
var _portals: Array[Vector2] = []
var _queue: Array = []
var _t: float = 0.0
var _portal_cursor: int = 0


func _init(planned: Array[Array], portals: Array[Vector2], relax: float) -> void:
	waves = planned
	_portals = portals
	relax_time = relax


func total_waves() -> int:
	return waves.size()


func tick(delta: float, world: CombatWorld) -> void:
	_t += delta
	match phase:
		Phase.WARMUP:
			if _t >= WARMUP:
				_next_wave()
		Phase.SPAWNING:
			if _t >= SPAWN_INTERVAL:
				_t = 0.0
				if _queue.is_empty():
					phase = Phase.FIGHTING
					portals_changed.emit(false)
				else:
					var id: StringName = _queue.pop_front()
					var at: Vector2 = _portals[_portal_cursor % _portals.size()]
					_portal_cursor += 1
					if not world.spawn(id, at):
						_queue.push_front(id)  # pool full: retry on the next interval
		Phase.FIGHTING:
			if world.alive_count() == 0:
				if wave_index + 1 >= waves.size():
					phase = Phase.CLEARED
					room_cleared.emit()
				else:
					phase = Phase.RELAX
					_t = 0.0
					if world.run.hp < world.run.max_hp * 0.35:
						world.pickups.drop(Ids.SPIRIT, world.hunter_position() + Vector2(0, -60), 1)
		Phase.RELAX:
			if _t >= relax_time:
				_next_wave()


func _next_wave() -> void:
	wave_index += 1
	_t = 0.0
	_queue = waves[wave_index].duplicate()
	phase = Phase.SPAWNING
	portals_changed.emit(true)
	wave_started.emit(wave_index, waves.size())
