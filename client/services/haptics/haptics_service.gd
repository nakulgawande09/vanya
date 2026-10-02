class_name HapticsService
extends RefCounted
## Haptics (Audio Bible A2 haptics map): keyed pulses with per-key cooldowns, a global budget of a
## few pulses per second, an Off / Low / Full level (amplitude ×0 / ×0.5 / ×1), and silence while
## an ad is showing. Subclasses only implement _vibrate(); the default is a recording fake.

enum Level { OFF, LOW, FULL }

const LEVEL_SCALE: Array[float] = [0.0, 0.5, 1.0]

var level: Level = Level.FULL
## True while a fullscreen ad is up (never vibrate during ads).
var suppressed: bool = false
var tuning: FeelTuning = FeelTuning.new()
var _last: Dictionary[StringName, int] = {}
var _recent: PackedInt64Array = PackedInt64Array()


func configure(feel: FeelTuning) -> void:
	tuning = feel


## Fires the pulse for `key` if allowed. `now_ms` < 0 uses the engine clock (tests pass their own).
func pulse(key: StringName, now_ms: int = -1) -> bool:
	if key == &"" or level == Level.OFF or suppressed or not tuning.haptics.has(key):
		return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var spec: Vector3 = tuning.haptics[key]
	if _last.has(key) and now - _last[key] < int(spec.z):
		return false
	var budget: int = maxi(1, tuning.haptic_budget_per_s)
	if _recent.size() >= budget and now - _recent[_recent.size() - budget] < 1000:
		return false
	_last[key] = now
	_recent.append(now)
	if _recent.size() > budget * 2:
		_recent = _recent.slice(_recent.size() - budget)
	var amplitude: float = clampf(spec.y * LEVEL_SCALE[level] * tuning.haptic_scale, 0.0, 1.0)
	_vibrate(int(spec.x), amplitude)
	return true


func _vibrate(_duration_ms: int, _amplitude: float) -> void:
	pass
