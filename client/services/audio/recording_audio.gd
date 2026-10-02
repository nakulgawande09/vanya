class_name RecordingAudio
extends AudioService
## Records what the game asked for instead of playing it (the default; tests assert on it).

const MAX_RECORDED: int = 512

var played: Array[StringName] = []
var pitches: PackedFloat32Array = PackedFloat32Array()
var loops: Dictionary[int, StringName] = {}
var context: StringName = &""
var clip: StringName = &""
var phase: int = -1
var frenzy: int = 0
var telegraph: bool = false
var low_hp: bool = false
var paused: bool = false
var muted: bool = false
var bed: StringName = &""
var blight: float = 0.0


func play(id: StringName, _at: Vector2 = NO_POS, pitch: float = 1.0) -> void:
	if played.size() >= MAX_RECORDED:
		played.remove_at(0)
		pitches.remove_at(0)
	played.append(id)
	pitches.append(pitch)


func start_loop(id: StringName, key: int, _at: Vector2 = NO_POS, _pitch: float = 1.0) -> void:
	loops[key] = id


func stop_loop(key: int) -> void:
	loops.erase(key)


func stop_all_loops() -> void:
	loops.clear()


func music_context(new_context: StringName) -> void:
	context = new_context
	clip = &"grove" if new_context == &"run" else &""


func music_clip(new_clip: StringName) -> void:
	clip = new_clip


func set_intensity(new_phase: int, _intensity: float, new_frenzy: int) -> void:
	phase = new_phase
	frenzy = new_frenzy


func set_telegraph(on: bool) -> void:
	telegraph = on


func set_low_hp(on: bool) -> void:
	low_hp = on


func ambience(new_bed: StringName, new_blight: float) -> void:
	bed = new_bed
	blight = new_blight


func set_paused(on: bool) -> void:
	paused = on


func mute(on: bool, _fade: float = 0.0) -> void:
	muted = on


func count(id: StringName) -> int:
	return played.count(id)


func clear() -> void:
	played.clear()
	pitches.clear()
