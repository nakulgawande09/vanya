class_name GodotAudio
extends AudioService
## The real audio adapter (Audio Bible A5, ADR-0007). Parented under Services by Boot, so it lives
## across scenes. Owns:
## - the registry (theme AudioManifests along the inherit chain, ID fallback `a.b.c.d` → `a.b.c`),
## - the 16-voice SfxPool, keyed loops, off-screen rules,
## - bus levels: settings volumes, script ducking (P0/P1 one-shots duck music −5 dB), pause duck,
##   low-HP low-pass, master mute / fade-in for backgrounding and ads,
## - two ambience players (grove bed + blight bed crossfade) and the MusicDirector.

const OFFSCREEN_DB: float = -6.0
const OFFSCREEN_MARGIN: float = 24.0
const AMB_FADE: float = 2.0
const LOWHP_EFFECT: int = 1  # Music bus effect index (tools/make_bus_layout.gd)
const AMB_LPF_EFFECT: int = 1  # Ambience bus effect index

var tuning: FeelTuning = FeelTuning.new()
var pool: SfxPool
var music: MusicDirector
var resident_bytes: int = 0
var _entries: Dictionary[StringName, AudioEntry] = {}
var _resolved: Dictionary[StringName, AudioEntry] = {}
var _missing: Dictionary[StringName, bool] = {}
var _loops: Dictionary[int, int] = {}
var _pending: PackedStringArray = PackedStringArray()
var _bus_master: int = 0
var _bus_music: int = -1
var _bus_sfx: int = -1
var _bus_ui: int = -1
var _bus_amb: int = -1
var _vol_music_db: float = 0.0
var _music_off: bool = false
var _master_user: float = 1.0
var _master_gain: float = 1.0
var _master_target: float = 1.0
var _master_rate: float = 0.0
var _duck_db: float = 0.0
var _duck_hold: float = 0.0
var _paused: bool = false
var _let_music_play: bool = false
var _external_music: bool = false
var _amb_bed: AudioStreamPlayer
var _amb_blight: AudioStreamPlayer
var _bed_id: StringName = &""
var _blight_target: float = 0.0
var _blight: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_master = AudioServer.get_bus_index(&"Master")
	_bus_music = AudioServer.get_bus_index(&"Music")
	_bus_sfx = AudioServer.get_bus_index(&"SFX")
	_bus_ui = AudioServer.get_bus_index(&"UI")
	_bus_amb = AudioServer.get_bus_index(&"Ambience")
	pool = SfxPool.new()
	pool.name = "Pool"
	add_child(pool)
	music = MusicDirector.new()
	music.name = "MusicDirector"
	add_child(music)
	_amb_bed = _amb_player("AmbBed")
	_amb_blight = _amb_player("AmbBlight")
	reload()
	EventBus.theme_changed.connect(func(_id: StringName) -> void: _request_reload())
	Services.ads.ad_opened.connect(func(_p: StringName) -> void: mute(true))
	Services.ads.ad_closed.connect(func(_p: StringName) -> void: mute(false, 0.5))
	Services.ads.ad_failed.connect(func(_p: StringName, _r: String) -> void: mute(false, 0.5))


## Backgrounding mutes at once; coming back fades in (the game itself stays paused).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			mute(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_external_music = _let_music_play and AndroidProbe.music_active()
			mute(false, 0.4)


## Loads the active theme chain's manifests synchronously (boot).
func reload() -> void:
	var manifests: Array[AudioManifest] = []
	for path: String in ThemeRegistry.audio_manifest_paths():
		var m: AudioManifest = load(path) as AudioManifest
		if m != null:
			manifests.append(m)
	_apply(manifests)


func play(id: StringName, at: Vector2 = NO_POS, pitch: float = 1.0) -> void:
	var e: AudioEntry = resolve(id)
	if e == null or e.loop:
		return
	var vol: float = 0.0
	if at.is_finite() and e.pan and not _on_screen(at):
		if e.tier > AudioEntry.Tier.P2:
			return
		vol = OFFSCREEN_DB
	var voice: int = pool.play(e, at, pitch, vol)
	if voice >= 0 and e.tier <= AudioEntry.Tier.P1:
		_duck_hold = tuning.duck_release
	if e.haptic != &"":
		Services.haptics.pulse(e.haptic)  # haptics keep their own cooldowns and budget


func start_loop(id: StringName, key: int, _at: Vector2 = NO_POS, pitch: float = 1.0) -> void:
	if _loops.has(key) and pool.entry_at(_loops[key]) != null and pool.entry_at(_loops[key]).id == id:
		return
	stop_loop(key)
	var e: AudioEntry = resolve(id)
	if e == null:
		return
	# Loops play non-positional: the four panned voices stay free for one-shots (A5 pool rules).
	var voice: int = pool.play(e, NO_POS, pitch, 0.0)
	if voice >= 0:
		_loops[key] = voice


func stop_loop(key: int) -> void:
	if _loops.has(key):
		pool.stop(_loops[key])
		_loops.erase(key)


func set_loop_pitch(key: int, pitch: float) -> void:
	if _loops.has(key):
		pool.set_pitch(_loops[key], pitch)


func stop_all_loops() -> void:
	for key: int in _loops.keys():
		pool.stop(_loops[key])
	_loops.clear()


func music_context(context: StringName) -> void:
	var low: bool = AdaptiveQuality.current_rung() >= QualityProfile.Rung.LOW
	music.set_context(context, low)
	if _bus_amb >= 0:
		AudioServer.set_bus_effect_enabled(_bus_amb, AMB_LPF_EFFECT, low)
	_update_resident()


func music_clip(clip: StringName) -> void:
	music.switch_clip(clip)


func set_intensity(phase: int, intensity: float, frenzy: int) -> void:
	music.set_intensity(phase, intensity, frenzy)


func set_telegraph(on: bool) -> void:
	music.mixer.telegraph = on


func set_low_hp(on: bool) -> void:
	if _bus_music >= 0:
		AudioServer.set_bus_effect_enabled(_bus_music, LOWHP_EFFECT, on)


func ambience(bed: StringName, blight: float) -> void:
	_blight_target = clampf(blight, 0.0, 1.0)
	if bed == _bed_id:
		return
	_bed_id = bed
	_set_amb(_amb_bed, bed)
	_set_amb(_amb_blight, &"amb.blight.bed" if bed != &"" else &"")


func set_paused(on: bool) -> void:
	_paused = on


func set_volumes(master: float, music_level: float, sfx: float, ui: float, amb: float) -> void:
	_master_user = clampf(master, 0.0, 1.0)
	_apply_master()
	_set_bus(_bus_sfx, sfx)
	_set_bus(_bus_ui, ui)
	_set_bus(_bus_amb, amb)
	_music_off = music_level <= 0.001
	_vol_music_db = linear_to_db(maxf(music_level, 0.0001))


func set_let_music_play(on: bool) -> void:
	_let_music_play = on
	_external_music = on and AndroidProbe.music_active()


func mute(on: bool, fade: float = 0.0) -> void:
	_master_target = 0.0 if on else 1.0
	if fade <= 0.0:
		_master_gain = _master_target
		_master_rate = 0.0
	else:
		_master_rate = 1.0 / fade
	_apply_master()


func stats() -> Dictionary:
	return {"voices": pool.active_count(), "steals": pool.steals, "drops": pool.drops,
			"audio_mb": snappedf(float(resident_bytes) / 1048576.0, 0.01),
			"latency_ms": roundi(AudioServer.get_output_latency() * 1000.0), "clip": String(music.clip)}


## The entry for `id`, falling back by dropping trailing segments (`…release.t3` → `…release`);
## null (and a one-time debug warning) when nothing matches.
func resolve(id: StringName) -> AudioEntry:
	var hit: AudioEntry = _resolved.get(id)
	if hit != null:
		return hit
	if _missing.has(id):
		return null
	var key: String = String(id)
	while true:
		var e: AudioEntry = _entries.get(StringName(key))
		if e != null:
			_resolved[id] = e
			return e
		var cut: int = key.rfind(".")
		if cut <= 0 or key.count(".") < 2:
			break
		key = key.substr(0, cut)
	_missing[id] = true
	if OS.is_debug_build():
		push_warning("Audio: no sound for '%s' in theme '%s'" % [id, ThemeRegistry.theme_id])
	return null


func _process(delta: float) -> void:
	if _master_rate > 0.0:
		_master_gain = move_toward(_master_gain, _master_target, _master_rate * delta)
		if is_equal_approx(_master_gain, _master_target):
			_master_rate = 0.0
		_apply_master()
	# Script ducking (A5): P0/P1 one-shots pull music down fast and let it back slowly.
	if _duck_hold > 0.0:
		_duck_hold -= delta
		_duck_db = move_toward(_duck_db, tuning.duck_db, absf(tuning.duck_db) / maxf(0.001, tuning.duck_attack) * delta)
	else:
		_duck_db = move_toward(_duck_db, 0.0, absf(tuning.duck_db) / maxf(0.001, tuning.duck_release) * delta)
	if _bus_music >= 0:
		var db: float = _vol_music_db + _duck_db + (tuning.pause_duck_db if _paused else 0.0)
		AudioServer.set_bus_volume_db(_bus_music, db)
		AudioServer.set_bus_mute(_bus_music, _music_off or _external_music)
	if not is_equal_approx(_blight, _blight_target):
		_blight = move_toward(_blight, _blight_target, delta / AMB_FADE)
		_amb_blight.volume_db = linear_to_db(maxf(_blight, 0.001))
		_amb_bed.volume_db = linear_to_db(maxf(1.0 - _blight * 0.6, 0.001))
	if not get_tree().paused:
		music.tick(delta)
	if not _pending.is_empty():
		_poll_pending()


func _apply(manifests: Array[AudioManifest]) -> void:
	_entries.clear()
	_resolved.clear()
	_missing.clear()
	for i: int in range(manifests.size() - 1, -1, -1):  # ancestors first; the active theme overrides
		for e: AudioEntry in manifests[i].entries:
			_entries[e.id] = e
	stop_all_loops()
	pool.stop_all()
	music.set_cues(manifests)
	var bed: StringName = _bed_id
	_bed_id = &"-"
	ambience(bed, _blight_target)
	_update_resident()


## Theme switch (camp only): load the new chain's manifests on worker threads, swap when ready.
func _request_reload() -> void:
	_pending = ThemeRegistry.audio_manifest_paths()
	for path: String in _pending:
		ResourceLoader.load_threaded_request(path)


func _poll_pending() -> void:
	for path: String in _pending:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
	var manifests: Array[AudioManifest] = []
	for path: String in _pending:
		var m: AudioManifest = ResourceLoader.load_threaded_get(path) as AudioManifest
		if m != null:
			manifests.append(m)
	_pending.clear()
	_apply(manifests)


func _update_resident() -> void:
	var n: int = 0
	for e: AudioEntry in _entries.values():
		n += e.bytes
	resident_bytes = n + music.resident_bytes


func _on_screen(world_pos: Vector2) -> bool:
	var vp: Viewport = get_viewport()
	var p: Vector2 = vp.get_canvas_transform() * world_pos
	return vp.get_visible_rect().grow(OFFSCREEN_MARGIN).has_point(p)


func _amb_player(node_name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = &"Ambience"
	add_child(p)
	return p


func _set_amb(player: AudioStreamPlayer, id: StringName) -> void:
	var e: AudioEntry = resolve(id) if id != &"" else null
	if e == null:
		player.stop()
		player.stream = null
		return
	if player.stream != e.stream:
		player.stream = e.stream
		player.play()


func _set_bus(bus: int, level: float) -> void:
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(bus, level <= 0.001)


func _apply_master() -> void:
	# The settings master level times the mute / fade-in gain.
	var g: float = _master_gain * _master_user
	AudioServer.set_bus_mute(_bus_master, g <= 0.001)
	AudioServer.set_bus_volume_db(_bus_master, linear_to_db(maxf(g, 0.0001)))
