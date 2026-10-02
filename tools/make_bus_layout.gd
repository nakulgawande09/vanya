extends SceneTree
## Writes client/audio/default_bus_layout.tres (Audio Bible A5). Re-run after changing buses:
##   godot --headless --path client -s ../tools/make_bus_layout.gd

const OUT: String = "res://audio/default_bus_layout.tres"


func _init() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	# Music: static −2 dB around 2.5 kHz so arrow transients cut through; a low-pass the
	# low-HP heartbeat switches on (disabled by default).
	var music: int = _bus(&"Music")
	var eq: AudioEffectEQ21 = AudioEffectEQ21.new()
	eq.set_band_gain_db(13, -1.5)  # 2000 Hz
	eq.set_band_gain_db(14, -2.0)  # 2800 Hz
	AudioServer.add_bus_effect(music, eq)
	var lowhp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	lowhp.cutoff_hz = 800.0
	AudioServer.add_bus_effect(music, lowhp)
	AudioServer.set_bus_effect_enabled(music, 1, false)
	var sfx: int = _bus(&"SFX")
	var sfx_hpf: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	sfx_hpf.cutoff_hz = 80.0
	AudioServer.add_bus_effect(sfx, sfx_hpf)
	_bus(&"UI")
	var amb: int = _bus(&"Ambience")
	var amb_hpf: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	amb_hpf.cutoff_hz = 150.0
	AudioServer.add_bus_effect(amb, amb_hpf)
	# Low tier trims ambience highs (Audio Bible A1 chart); disabled by default.
	var amb_lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	amb_lpf.cutoff_hz = 10000.0
	AudioServer.add_bus_effect(amb, amb_lpf)
	AudioServer.set_bus_effect_enabled(amb, 1, false)
	_bus(&"Voice")
	var err: Error = ResourceSaver.save(AudioServer.generate_bus_layout(), OUT)
	print("bus layout -> ", OUT, " (", error_string(err), ")")
	quit(0 if err == OK else 1)


func _bus(bus_name: StringName) -> int:
	AudioServer.add_bus()
	var i: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Master")
	return i
