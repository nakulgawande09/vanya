extends GdUnitTestSuite
## Feel-test tooling (B3): the overlay logs a CSV row per second and toggles with F3 or a
## 3-finger tap; the joystick honours FIXED / DYNAMIC / FOLLOWING and the dead zone.


func _touch(index: int, pressed: bool, at: Vector2) -> InputEventScreenTouch:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = at
	return e


func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = at
	return e


func test_overlay_records_one_csv_row_per_second() -> void:
	var o: FeelOverlay = auto_free(FeelOverlay.new()) as FeelOverlay
	add_child(o)
	o.start_recording()
	for i: int in 7:
		o._process(0.5)
	o.stop_recording()
	var lines: PackedStringArray = FileAccess.get_file_as_string(o.csv_path).strip_edges().split("\n")
	assert_str(lines[0]).starts_with("t_s,fps,frame_ms_avg,frame_ms_p95,frame_ms_p99,jank_per_min")
	assert_int(lines.size()).is_equal(1 + 3)
	assert_float(VarUtil.to_float(o.snapshot().get("frame_ms_p99"), 0.0)).is_equal_approx(500.0, 0.01)
	assert_float(VarUtil.to_float(o.snapshot().get("jank_per_min"), 0.0)).is_greater(0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(o.csv_path))


func test_overlay_toggles_with_f3_and_three_fingers() -> void:
	var o: FeelOverlay = auto_free(FeelOverlay.new()) as FeelOverlay
	add_child(o)
	assert_bool(o.visible).is_false()
	var k: InputEventKey = InputEventKey.new()
	k.keycode = KEY_F3
	k.pressed = true
	o._input(k)
	assert_bool(o.visible).is_true()
	for i: int in 3:
		o._input(_touch(i, true, Vector2(100 + i * 40, 400)))
	assert_bool(o.visible).is_false()


func _stick(mode: FeelTuning.JoystickMode) -> Array:
	var j: FloatingJoystick = auto_free(FloatingJoystick.new()) as FloatingJoystick
	add_child(j)
	j.size = Vector2(390, 844)
	var t: FeelTuning = FeelTuning.new()
	t.joystick_mode = mode
	t.joystick_deadzone = 0.1
	t.joystick_full_speed_at = 1.0
	j.set_tuning(t)
	var out: Array[Vector2] = []
	j.moved.connect(func(v: Vector2) -> void: out.append(v))
	return [j, out]


func test_dynamic_stick_centres_on_the_thumb_and_respects_the_dead_zone() -> void:
	var pair: Array = _stick(FeelTuning.JoystickMode.DYNAMIC)
	var j: FloatingJoystick = pair[0]
	var out: Array[Vector2] = pair[1]
	j._input(_touch(0, true, Vector2(150, 600)))
	assert_vector(out.back()).is_equal(Vector2.ZERO)
	j._input(_drag(0, Vector2(152, 600)))  # 0.04 of the radius: inside the dead zone
	assert_vector(out.back()).is_equal(Vector2.ZERO)
	j._input(_drag(0, Vector2(200, 600)))  # full radius
	assert_float(out.back().x).is_equal_approx(1.0, 0.001)
	j._input(_touch(0, false, Vector2(200, 600)))
	assert_vector(out.back()).is_equal(Vector2.ZERO)


func test_fixed_stick_steers_from_its_rest_spot() -> void:
	var pair: Array = _stick(FeelTuning.JoystickMode.FIXED)
	var j: FloatingJoystick = pair[0]
	var out: Array[Vector2] = pair[1]
	var rest: Vector2 = Vector2(FloatingJoystick.REST_X, 844 - FloatingJoystick.REST_Y)
	j._input(_touch(0, true, rest + Vector2(0, -50)))
	assert_float(out.back().y).is_equal_approx(-1.0, 0.001)


func test_following_stick_drags_its_base_along() -> void:
	var pair: Array = _stick(FeelTuning.JoystickMode.FOLLOWING)
	var j: FloatingJoystick = pair[0]
	var out: Array[Vector2] = pair[1]
	j._input(_touch(0, true, Vector2(100, 600)))
	j._input(_drag(0, Vector2(220, 600)))  # 120 px right: the base follows to 170
	j._input(_drag(0, Vector2(150, 600)))  # back 70 px: now 20 px left of the base
	assert_float(out.back().x).is_less(0.0)
