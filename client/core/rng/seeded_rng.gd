class_name SeededRng
extends RefCounted
## Deterministic RNG stream. One per subsystem (layout, scatter, waves).
## Never use the global randi()/randf() in gameplay code (docs/standards.md §C4).

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(run_seed: int, room_index: int = 0, stream: StringName = &"") -> void:
	_rng.seed = derive_seed(run_seed, room_index, stream)


## Mixes the run seed with room index and stream name using integer math only.
static func derive_seed(run_seed: int, room_index: int, stream: StringName) -> int:
	var h: int = hash(String(stream))
	return run_seed ^ (room_index * 0x9E3779B1) ^ (h * 0x85EBCA77)


func next_int(min_inclusive: int, max_inclusive: int) -> int:
	return _rng.randi_range(min_inclusive, max_inclusive)


func next_float() -> float:
	return _rng.randf()


func chance(p: float) -> bool:
	return _rng.randf() < p


func pick_index(size: int) -> int:
	assert(size > 0)
	return _rng.randi_range(0, size - 1)


func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state
