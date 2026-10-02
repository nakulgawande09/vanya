class_name FeelOverlay
extends Control
## Real-phone feel-test overlay (feel-test plan B3), debug builds only. A 3-finger tap or F3
## toggles it. Shows FPS, frame time avg / p95 / p99, jank (> 25 ms) per minute, process / physics
## time, draw calls, memory, audio voices / steals / MB, reported output latency, battery and
## thermal headroom. REC writes one CSV row per second to user://feeltest_<date>.csv. The Tune tab
## edits FeelTuning live (joystick, hit-stop, shake, haptics, aim) and saves user://feel_tuning.tres.

signal tuning_changed

const RING: int = 240
const JANK_MS: float = 25.0
const PROBE_EVERY: float = 10.0
const CSV_HEADER: PackedStringArray = ["t_s", "fps", "frame_ms_avg", "frame_ms_p95", "frame_ms_p99", "jank_per_min",
		"process_ms", "physics_ms", "draw_calls", "static_mb", "video_mb", "voices", "steals", "drops", "audio_mb",
		"latency_ms", "battery_pct", "thermal_headroom", "quality_rung", "music_clip"]

var tuning: FeelTuning = FeelTuning.new()
var recording: bool = false
var csv_path: String = ""
var _frames: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _filled: int = 0
var _janks: PackedFloat64Array = PackedFloat64Array()
var _t: float = 0.0
var _row_t: float = 0.0
var _probe_t: float = PROBE_EVERY
var _battery: int = -1
var _thermal: float = -1.0
var _touches: Dictionary[int, bool] = {}
var _file: FileAccess
var _panel: PanelContainer
var _text: Label
var _rec: Button
var _tune_box: VBoxContainer
var _last: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frames.resize(RING)
	_build()
	visible = false


func _exit_tree() -> void:
	stop_recording()


func toggle() -> void:
	visible = not visible


func start_recording() -> void:
	if recording:
		return
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace(" ", "_")
	csv_path = "user://feeltest_%s.csv" % stamp
	_file = FileAccess.open(csv_path, FileAccess.WRITE)
	if _file == null:
		return
	_file.store_csv_line(CSV_HEADER)
	_file.flush()
	recording = true
	_row_t = 0.0
	_t = 0.0
	_update_rec_button()


func stop_recording() -> void:
	recording = false
	if _file != null:
		_file.close()
		_file = null
	_update_rec_button()


## The latest metrics (also what the CSV row holds).
func snapshot() -> Dictionary:
	return _last


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touches[t.index] = true
			if _touches.size() >= 3:
				_touches.clear()
				toggle()
		else:
			_touches.erase(t.index)
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and not k.echo and k.keycode == KEY_F3:
			toggle()


func _process(delta: float) -> void:
	var ms: float = delta * 1000.0
	_frames[_cursor] = ms
	_cursor = (_cursor + 1) % RING
	_filled = mini(_filled + 1, RING)
	_t += delta
	if ms > JANK_MS:
		_janks.append(_t)
	_probe_t += delta
	if _probe_t >= PROBE_EVERY:
		_probe_t = 0.0
		_battery = AndroidProbe.battery_percent()
		_thermal = AndroidProbe.thermal_headroom()
		if _thermal < 0.0:
			_thermal = Services.thermal.get_headroom()
	_row_t += delta
	if _row_t >= 1.0:
		_row_t -= 1.0
		_last = _measure()
		if recording and _file != null:
			var row: PackedStringArray = PackedStringArray()
			for key: String in CSV_HEADER:
				row.append(str(_last.get(key, "")))
			_file.store_csv_line(row)
			_file.flush()
		if visible:
			_text.text = _format(_last)


func _measure() -> Dictionary:
	var window: PackedFloat32Array = _frames.slice(0, _filled)
	window.sort()
	var total: float = 0.0
	for v: float in window:
		total += v
	while not _janks.is_empty() and _t - _janks[0] > 60.0:
		_janks.remove_at(0)
	var minutes: float = clampf(_t / 60.0, 1.0 / 60.0, 1.0)
	var audio: Dictionary = Services.audio.stats()
	return {
		"t_s": snappedf(_t, 0.1),
		"fps": Engine.get_frames_per_second(),
		"frame_ms_avg": snappedf(total / maxf(1.0, window.size()), 0.01),
		"frame_ms_p95": snappedf(_pct(window, 0.95), 0.01),
		"frame_ms_p99": snappedf(_pct(window, 0.99), 0.01),
		"jank_per_min": snappedf(_janks.size() / minutes, 0.1),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"voices": audio.get("voices", 0), "steals": audio.get("steals", 0), "drops": audio.get("drops", 0),
		"audio_mb": audio.get("audio_mb", 0.0), "latency_ms": audio.get("latency_ms", 0),
		"battery_pct": _battery, "thermal_headroom": snappedf(_thermal, 0.01),
		"quality_rung": AdaptiveQuality.current_rung(), "music_clip": audio.get("clip", ""),
	}


static func _pct(sorted: PackedFloat32Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)]


func _format(m: Dictionary) -> String:
	return ("FPS %s  avg %s  p95 %s  p99 %s ms  jank %s/min\n" % [m["fps"], m["frame_ms_avg"], m["frame_ms_p95"], m["frame_ms_p99"], m["jank_per_min"]]
			+ "proc %s  phys %s ms  draws %s  mem %s MB  vram %s MB\n" % [m["process_ms"], m["physics_ms"], m["draw_calls"], m["static_mb"], m["video_mb"]]
			+ "voices %s  steals %s  drops %s  audio %s MB  latency %s ms  %s\n" % [m["voices"], m["steals"], m["drops"], m["audio_mb"], m["latency_ms"], m["music_clip"]]
			+ "battery %s  thermal %s  rung %s%s" % [_or_na(m["battery_pct"], "%"), _or_na(m["thermal_headroom"], ""), m["quality_rung"],
					("  REC " + csv_path.get_file()) if recording else ""])


## Probes report -1 when the platform can't answer (desktop, old Android).
static func _or_na(v: Variant, unit: String) -> String:
	return "n/a" if VarUtil.to_float(v, -1.0) < 0.0 else "%s%s" % [v, unit]


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(6, 132)
	_panel.custom_minimum_size = Vector2(378, 0)
	_panel.self_modulate = Color(1, 1, 1, 0.85)
	add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	_panel.add_child(box)
	_text = Label.new()
	_text.add_theme_font_size_override(&"font_size", 11)
	_text.text = "…"
	box.add_child(_text)
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	_rec = _button(row, "REC", func() -> void:
		if recording:
			stop_recording()
		else:
			start_recording())
	_button(row, "TUNE", func() -> void: _tune_box.visible = not _tune_box.visible)
	_button(row, "HIDE", toggle)
	_tune_box = VBoxContainer.new()
	_tune_box.visible = false
	box.add_child(_tune_box)
	_build_tune()


func _build_tune() -> void:
	_slider("Stick mode (fixed/dyn/follow)", 0, 2, 1, func() -> float: return tuning.joystick_mode,
			func(v: float) -> void: tuning.joystick_mode = int(v) as FeelTuning.JoystickMode)
	_slider("Built-in VirtualJoystick (0/1)", 0, 1, 1, func() -> float: return 1.0 if tuning.joystick_builtin else 0.0,
			func(v: float) -> void: tuning.joystick_builtin = v > 0.5)
	_slider("Dead zone", 0.0, 0.4, 0.01, func() -> float: return tuning.joystick_deadzone,
			func(v: float) -> void: tuning.joystick_deadzone = v)
	_slider("Radius px", 30, 90, 1, func() -> float: return tuning.joystick_radius,
			func(v: float) -> void: tuning.joystick_radius = v)
	_slider("Full speed at", 0.3, 1.0, 0.05, func() -> float: return tuning.joystick_full_speed_at,
			func(v: float) -> void: tuning.joystick_full_speed_at = v)
	_slider("Curve", 0.5, 2.5, 0.1, func() -> float: return tuning.joystick_curve,
			func(v: float) -> void: tuning.joystick_curve = v)
	_slider("Hit-stop ×", 0.0, 2.0, 0.05, func() -> float: return tuning.hitstop_scale,
			func(v: float) -> void: tuning.hitstop_scale = v)
	_slider("Shake ×", 0.0, 2.0, 0.05, func() -> float: return tuning.shake_scale,
			func(v: float) -> void: tuning.shake_scale = v)
	_slider("Haptics ×", 0.0, 1.5, 0.05, func() -> float: return tuning.haptic_scale,
			func(v: float) -> void: tuning.haptic_scale = v)
	_slider("Aim retarget s", 0.0, 0.6, 0.05, func() -> float: return tuning.aim_retarget_delay,
			func(v: float) -> void: tuning.aim_retarget_delay = v)
	var row: HBoxContainer = HBoxContainer.new()
	_tune_box.add_child(row)
	_button(row, "SAVE", func() -> void:
		ResourceSaver.save(tuning, FeelTuning.OVERRIDE_PATH))
	_button(row, "RESET", func() -> void:
		if FileAccess.file_exists(FeelTuning.OVERRIDE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(FeelTuning.OVERRIDE_PATH)))


func _slider(label: String, lo: float, hi: float, step: float, read: Callable, write: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_tune_box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.add_theme_font_size_override(&"font_size", 11)
	row.add_child(name_label)
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(40, 0)
	value.add_theme_font_size_override(&"font_size", 11)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 28)
	row.add_child(s)
	row.add_child(value)
	visibility_changed.connect(func() -> void:
		s.set_value_no_signal(VarUtil.to_float(read.call(), lo))
		value.text = str(snappedf(s.value, step)))
	s.value_changed.connect(func(v: float) -> void:
		write.call(v)
		value.text = str(snappedf(v, step))
		Services.haptics.configure(tuning)
		tuning_changed.emit())


func _button(row: HBoxContainer, label: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(64, 36)
	b.add_theme_font_size_override(&"font_size", 12)
	b.pressed.connect(func() -> void: on_press.call())
	row.add_child(b)
	return b


func _update_rec_button() -> void:
	if _rec != null:
		_rec.text = "STOP" if recording else "REC"
