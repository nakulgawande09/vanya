class_name StemMixer
extends RefCounted
## Vertical layering (Audio Bible A3), pure logic: turns the intensity director's phase and the
## frenzy count into per-stem levels. The director state must hold 4 s before the music follows
## (hysteresis); at most one stem changes per bar; fades start on the beat, rising over 2 beats
## and falling over 4. A boss telegraph drops the melody at once.

enum Stem { BED, PERC, MELODY, TENSION, FRENZY }

const SILENT: float = -60.0
const HYSTERESIS: float = 4.0
const STEMS: int = 5
const FADE_UP_BEATS: float = 2.0
const FADE_DOWN_BEATS: float = 4.0
## Order in which pending stem changes are taken, one per bar: drops that clear the mix first.
const ORDER: Array[int] = [Stem.MELODY, Stem.FRENZY, Stem.TENSION, Stem.PERC, Stem.BED]
## A3 stem table: [RELAX, BUILD_UP, PEAK] × stems (dB). BUILD_UP percussion rises −6 → 0 dB.
const RELAX_DB: Array[float] = [0.0, SILENT, -6.0, SILENT, SILENT]
const BUILD_DB: Array[float] = [0.0, -6.0, 0.0, -12.0, SILENT]
const PEAK_DB: Array[float] = [-3.0, 0.0, -3.0, 0.0, SILENT]

var beat: float = 0.625
var bar_beats: int = 4
var levels: PackedFloat32Array = PackedFloat32Array()
var phase: int = IntensityDirector.Phase.BUILD_UP
var frenzy: bool = false
var telegraph: bool = false
var _time: float = 0.0
var _bar: int = 0
var _pending_state: int = -1
var _pending_t: float = 0.0
var _from: PackedFloat32Array = PackedFloat32Array()
var _to: PackedFloat32Array = PackedFloat32Array()
var _fade_t: PackedFloat32Array = PackedFloat32Array()
var _fade_len: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	# Packed arrays are values: resize each member directly.
	levels.resize(STEMS)
	_from.resize(STEMS)
	_to.resize(STEMS)
	_fade_t.resize(STEMS)
	_fade_len.resize(STEMS)
	reset(96.0, 4, IntensityDirector.Phase.BUILD_UP, 0.0, 0)


## Starts a cue: levels jump straight to the current state's targets.
func reset(bpm: float, beats_per_bar: int, start_phase: int, intensity: float, frenzy_count: int) -> void:
	beat = 60.0 / maxf(1.0, bpm)
	bar_beats = maxi(1, beats_per_bar)
	phase = start_phase
	frenzy = frenzy_count >= 3
	telegraph = false
	_time = 0.0
	_bar = 0
	_pending_state = -1
	_pending_t = 0.0
	var t: PackedFloat32Array = targets(phase, intensity, frenzy)
	for s: int in STEMS:
		levels[s] = t[s]
		_from[s] = t[s]
		_to[s] = t[s]
		_fade_t[s] = 0.0
		_fade_len[s] = 0.0


static func targets(p: int, intensity: float, frenzy_on: bool) -> PackedFloat32Array:
	var src: Array[float] = BUILD_DB
	if p == IntensityDirector.Phase.RELAX:
		src = RELAX_DB
	elif p == IntensityDirector.Phase.PEAK:
		src = PEAK_DB
	var out: PackedFloat32Array = PackedFloat32Array(src)
	if p == IntensityDirector.Phase.BUILD_UP and intensity >= 0.5:
		out[Stem.PERC] = 0.0
	if p == IntensityDirector.Phase.PEAK and frenzy_on:
		out[Stem.FRENZY] = 0.0
	return out


## Advances the mix by `delta` seconds of music time.
func step(delta: float, want_phase: int, intensity: float, frenzy_count: int) -> void:
	_time += delta
	var want_frenzy: bool = frenzy_count >= 3
	var want_state: int = want_phase * 2 + (1 if want_frenzy else 0)
	if want_state != phase * 2 + (1 if frenzy else 0):
		if want_state == _pending_state:
			_pending_t += delta
		else:
			_pending_state = want_state
			_pending_t = delta
		if _pending_t >= HYSTERESIS:
			phase = want_phase
			frenzy = want_frenzy
			_pending_state = -1
	else:
		_pending_state = -1
	var tgt: PackedFloat32Array = targets(phase, intensity, frenzy)
	if telegraph:
		tgt[Stem.MELODY] = SILENT
		if absf(_to[Stem.MELODY] - SILENT) > 0.01:
			_start_fade(Stem.MELODY, SILENT, beat)
	var bar: int = int(_time / (beat * bar_beats))
	if bar != _bar:
		_bar = bar
		for s: int in ORDER:
			if absf(_to[s] - tgt[s]) > 0.5:
				_start_fade(s, tgt[s], beat * (FADE_UP_BEATS if tgt[s] > _to[s] else FADE_DOWN_BEATS))
				break
	for s: int in STEMS:
		if _fade_len[s] > 0.0:
			_fade_t[s] = minf(_fade_t[s] + delta, _fade_len[s])
			levels[s] = lerpf(_from[s], _to[s], _fade_t[s] / _fade_len[s])
			if _fade_t[s] >= _fade_len[s]:
				_fade_len[s] = 0.0


## The three low-tier stems: bed, melody, drive (percussion + tension).
func low_levels() -> PackedFloat32Array:
	return PackedFloat32Array([levels[Stem.BED], levels[Stem.MELODY], maxf(levels[Stem.PERC], levels[Stem.TENSION])])


## True while any stem is still moving towards a pending target (tests).
func is_fading() -> bool:
	for s: int in STEMS:
		if _fade_len[s] > 0.0:
			return true
	return false


func _start_fade(s: int, to_db: float, seconds: float) -> void:
	_from[s] = levels[s]
	_to[s] = to_db
	_fade_t[s] = 0.0
	_fade_len[s] = maxf(0.01, seconds)
