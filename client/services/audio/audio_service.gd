class_name AudioService
extends Node
## Audio interface (Audio Bible A5; ADR-0007). Gameplay and UI ask for sounds by ID
## (`sfx.<domain>.<entity>.<action>`), never by file. This base class is silent; RecordingAudio
## (tests, default) records requests, GodotAudio plays them.

## "No position": a sound that is not panned by screen X.
const NO_POS: Vector2 = Vector2.INF


## One-shot. `at` is a world position for panned entries; `pitch` multiplies the random pitch.
func play(_id: StringName, _at: Vector2 = NO_POS, _pitch: float = 1.0) -> void:
	pass


## Starts a looping sound owned by `key` (an instance id or a fixed constant); idempotent.
func start_loop(_id: StringName, _key: int, _at: Vector2 = NO_POS, _pitch: float = 1.0) -> void:
	pass


func stop_loop(_key: int) -> void:
	pass


func set_loop_pitch(_key: int, _pitch: float) -> void:
	pass


func stop_all_loops() -> void:
	pass


## &"camp", &"run" or &"" (silence). Loads only that context's music (memory budget).
func music_context(_context: StringName) -> void:
	pass


## Within the run context: &"grove", &"boss", &"victory", &"defeat".
func music_clip(_clip: StringName) -> void:
	pass


## The DDA intensity director's phase (IntensityDirector.Phase), its value, and the frenzy count.
func set_intensity(_phase: int, _intensity: float, _frenzy: int) -> void:
	pass


## Boss telegraph: drop the melody stem so the warning reads.
func set_telegraph(_on: bool) -> void:
	pass


## Low-HP state: heartbeat loop is gameplay's; this low-passes the music bus.
func set_low_hp(_on: bool) -> void:
	pass


## Ambience bed ID (&"" for none) and how much of the blight bed to blend in (0–1).
func ambience(_bed: StringName, _blight: float) -> void:
	pass


## Pause menu open: duck the music.
func set_paused(_on: bool) -> void:
	pass


## Linear 0–1 bus levels from the settings sliders.
func set_volumes(_master: float, _music: float, _sfx: float, _ui: float, _ambience: float) -> void:
	pass


## "Let my music play": mute game music while another app plays music.
func set_let_music_play(_on: bool) -> void:
	pass


## Mute everything (backgrounded, ad showing) or fade back in over `fade` seconds.
func mute(_on: bool, _fade: float = 0.0) -> void:
	pass


## Debug overlay counters: voices, steals, drops, audio_mb, latency_ms, clip.
func stats() -> Dictionary:
	return {}
