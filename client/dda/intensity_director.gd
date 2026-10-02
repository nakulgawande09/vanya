class_name IntensityDirector
extends RefCounted
## In-room pacing after Left 4 Dead's director (dev-plan §7.3): intensity rises with damage taken,
## near-death moments and beasts close by, and decays over time. BUILD_UP → PEAK (≤ 8 s, no new
## waves) → RELAX (6–12 s, no new waves, one spirit wisp if the hunter is low) → BUILD_UP.

enum Phase { BUILD_UP, PEAK, RELAX }

const PEAK_AT: float = 0.8
const CALM_AT: float = 0.3
const PEAK_MAX: float = 8.0
const RELAX_MIN: float = 6.0
const RELAX_MAX: float = 12.0
## Per-second decay. The dev plan's 0.97 is too slow to ever relax inside a 12 s window at our
## damage scale; 0.85 lets a quiet stretch fall from PEAK_AT to CALM_AT in about 6 s.
const DECAY: float = 0.85
const CLOSE_WEIGHT: float = 0.05
const LOW_HP: float = 0.35

var intensity: float = 0.0
var phase: Phase = Phase.BUILD_UP
var phase_t: float = 0.0
var _relief_given: bool = false


## Feed one tick: share of max HP lost, whether the hunter just dipped near death, beasts within 4 tiles.
func feed(delta: float, damage_frac: float, near_death: bool, close_beasts: int) -> void:
	intensity += damage_frac * 1.0 + (0.5 if near_death else 0.0) + close_beasts * CLOSE_WEIGHT * delta
	intensity *= pow(DECAY, delta)
	intensity = clampf(intensity, 0.0, 1.5)
	phase_t += delta
	match phase:
		Phase.BUILD_UP:
			if intensity >= PEAK_AT:
				_enter(Phase.PEAK)
		Phase.PEAK:
			if phase_t >= PEAK_MAX or intensity < CALM_AT:
				_enter(Phase.RELAX)
		Phase.RELAX:
			if phase_t >= RELAX_MAX or (phase_t >= RELAX_MIN and intensity < CALM_AT):
				_enter(Phase.BUILD_UP)


## New waves may start only while building up.
func allows_new_wave() -> bool:
	return phase == Phase.BUILD_UP


## True once per relax window when the hunter is low: the room should offer a spirit wisp.
func wants_relief(hp_frac: float) -> bool:
	if phase == Phase.RELAX and hp_frac < LOW_HP and not _relief_given:
		_relief_given = true
		return true
	return false


func _enter(p: Phase) -> void:
	phase = p
	phase_t = 0.0
	if p == Phase.RELAX:
		_relief_given = false
