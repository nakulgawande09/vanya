class_name MusicDirector
extends Node
## Adaptive music (Audio Bible A3). One AudioStreamPlayer on the Music bus:
## - run: an AudioStreamInteractive with clips grove / boss (each an AudioStreamSynchronized of
##   stems) and the victory / defeat stingers. Clip switches land on the next bar with a 2-beat
##   cross-fade; stingers cut in at once.
## - camp: an AudioStreamPlaylist of the camp tracks.
## Only the current context is loaded. Stem levels come from StemMixer and are applied with
## AudioStreamSynchronized.set_sync_stream_volume.

const CONTEXT_FADE: float = 0.4
## Headroom under the game (A1): five stems at −23 LUFS each sum to about −17 LUFS at PEAK;
## this trim keeps the full mix near −20 so player hurt, telegraphs and arrows stay on top.
const MUSIC_TRIM_DB: float = -3.0

var mixer: StemMixer = StemMixer.new()
var context: StringName = &""
var clip: StringName = &""
var low_tier: bool = false
## Bytes of music data loaded for the current context.
var resident_bytes: int = 0
var phase: int = IntensityDirector.Phase.BUILD_UP
var intensity: float = 0.0
var frenzy: int = 0
var _player: AudioStreamPlayer
var _cues: Dictionary[StringName, MusicCue] = {}
var _sync: Dictionary[StringName, AudioStreamSynchronized] = {}
var _applied: PackedFloat32Array = PackedFloat32Array()
var _fade: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = &"Music"
	add_child(_player)


## Cues from the theme chain, active theme first (the first definition of a cue wins).
func set_cues(manifests: Array[AudioManifest]) -> void:
	_cues.clear()
	for m: AudioManifest in manifests:
		for c: MusicCue in m.music:
			if not _cues.has(c.cue):
				_cues[c.cue] = c
	if context != &"":
		var ctx: StringName = context
		context = &""
		set_context(ctx, low_tier)


func has_cue(cue: StringName) -> bool:
	return _cues.has(cue)


func set_context(new_context: StringName, low: bool) -> void:
	if new_context == context and low == low_tier:
		return
	context = new_context
	low_tier = low
	_sync.clear()
	clip = &""
	resident_bytes = 0
	var stream: AudioStream = null
	match new_context:
		&"run":
			stream = _build_run()
			clip = &"grove"
		&"camp":
			stream = _build_camp()
	if _fade != null:
		_fade.kill()
	if not _player.playing or stream == null:
		_swap(stream)
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -40.0, CONTEXT_FADE)
	_fade.tween_callback(_swap.bind(stream))


func switch_clip(new_clip: StringName) -> void:
	if context != &"run" or new_clip == clip:
		return
	var pb: AudioStreamPlaybackInteractive = _player.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	clip = new_clip
	pb.switch_to_clip_by_name(new_clip)
	var cue: MusicCue = _cues.get(new_clip)
	if cue != null and cue.bpm > 0.0:
		mixer.reset(cue.bpm, cue.bar_beats, phase, intensity, frenzy)
		_applied.clear()


func set_intensity(new_phase: int, new_intensity: float, new_frenzy: int) -> void:
	phase = new_phase
	intensity = new_intensity
	frenzy = new_frenzy


func tick(delta: float) -> void:
	var stream: AudioStreamSynchronized = _sync.get(clip)
	if stream == null or not _player.playing:
		return
	mixer.step(delta, phase, intensity, frenzy)
	var lv: PackedFloat32Array = mixer.low_levels() if low_tier else mixer.levels
	var n: int = mini(stream.stream_count, lv.size())
	if _applied.size() != n:
		_applied.resize(n)
		_applied.fill(999.0)
	for i: int in n:
		if absf(_applied[i] - lv[i]) > 0.05:
			_applied[i] = lv[i]
			stream.set_sync_stream_volume(i, lv[i])


## Current stem levels in dB (debug overlay, tests).
func stem_levels() -> PackedFloat32Array:
	var stream: AudioStreamSynchronized = _sync.get(clip)
	var out: PackedFloat32Array = PackedFloat32Array()
	if stream != null:
		for i: int in stream.stream_count:
			out.append(stream.get_sync_stream_volume(i))
	return out


func _swap(stream: AudioStream) -> void:
	_player.stop()
	_player.stream = stream
	_player.volume_db = MUSIC_TRIM_DB
	if stream != null:
		var cue: MusicCue = _cues.get(clip)
		if cue != null:
			mixer.reset(cue.bpm, cue.bar_beats, phase, intensity, frenzy)
		_applied.clear()
		_player.play()


func _build_run() -> AudioStream:
	var clips: Array[StringName] = []
	var streams: Array[AudioStream] = []
	for cue_name: StringName in [&"grove", &"boss"]:
		var cue: MusicCue = _cues.get(cue_name)
		if cue == null:
			continue
		var paths: PackedStringArray = cue.low_stem_paths if low_tier and not cue.low_stem_paths.is_empty() else cue.stem_paths
		var sync: AudioStreamSynchronized = AudioStreamSynchronized.new()
		sync.stream_count = paths.size()
		for i: int in paths.size():
			sync.set_sync_stream(i, load(paths[i]) as AudioStream)
		resident_bytes += cue.low_bytes if low_tier and not cue.low_stem_paths.is_empty() else cue.bytes
		_sync[cue_name] = sync
		clips.append(cue_name)
		streams.append(sync)
	for cue_name: StringName in [&"victory", &"defeat"]:
		var cue: MusicCue = _cues.get(cue_name)
		if cue != null and cue.path != "":
			clips.append(cue_name)
			streams.append(load(cue.path) as AudioStream)
			resident_bytes += cue.bytes
	if clips.is_empty():
		return null
	var ia: AudioStreamInteractive = AudioStreamInteractive.new()
	ia.clip_count = clips.size()
	for i: int in clips.size():
		ia.set_clip_name(i, clips[i])
		ia.set_clip_stream(i, streams[i])
	for i: int in clips.size():
		if clips[i] == &"victory" or clips[i] == &"defeat":
			ia.add_transition(AudioStreamInteractive.CLIP_ANY, i, AudioStreamInteractive.TRANSITION_FROM_TIME_IMMEDIATE,
					AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_OUT, 1.0)
		else:
			ia.add_transition(AudioStreamInteractive.CLIP_ANY, i, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
					AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_CROSS, 2.0)
	ia.initial_clip = 0
	return ia


func _build_camp() -> AudioStream:
	var cue: MusicCue = _cues.get(&"camp")
	if cue == null or cue.playlist_paths.is_empty():
		return null
	var pl: AudioStreamPlaylist = AudioStreamPlaylist.new()
	pl.stream_count = cue.playlist_paths.size()
	for i: int in cue.playlist_paths.size():
		pl.set_list_stream(i, load(cue.playlist_paths[i]) as AudioStream)
	pl.loop = true
	pl.shuffle = false
	pl.fade_time = 1.5
	resident_bytes = cue.bytes
	return pl
