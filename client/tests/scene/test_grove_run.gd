extends GdUnitTestSuite
## Scripted playthrough of the core loop. The run's fixed tick is driven by hand (60 Hz), so the
## test is deterministic and does not depend on real time.

const RUN_SCENE: String = "res://gameplay/run/grove_run.tscn"
const STEP: float = 1.0 / 60.0

var _save_before: SaveService
var _audio_before: AudioService
var _haptics_before: HapticsService
var _audio: RecordingAudio
var _haptics: FakeHaptics


func before_test() -> void:
	_audio = RecordingAudio.new()
	_audio_before = Services.swap_audio(_audio)
	_haptics_before = Services.haptics
	_haptics = FakeHaptics.new()
	_haptics.configure(FeelTuning.new())
	Services.haptics = _haptics
	_save_before = Services.save
	Services.save = SaveService.new("user://test_grove_run_%d/" % Time.get_ticks_usec())
	Services.save.set_value("profile", {"meat": 0, "spirit": 0})


func after_test() -> void:
	Services.save = _save_before
	Services.swap_audio(_audio_before).free()
	Services.haptics = _haptics_before


func _start(run_seed: int = 11, with_tutorial: bool = false) -> GroveRun:
	var scene: GroveRun = (load(RUN_SCENE) as PackedScene).instantiate() as GroveRun
	scene.run_seed = run_seed
	scene.tutorial_enabled = with_tutorial
	scene_runner(auto_free(scene))
	scene.set_physics_process(false)
	return scene


func _step(run: GroveRun, seconds: float) -> void:
	for i: int in int(seconds / STEP):
		run._physics_process(STEP)


func _tough(run: GroveRun) -> void:
	run.run.max_hp = 100000
	run.run.hp = 100000


func test_grove_one_spawns_waves_and_clears() -> void:
	var run: GroveRun = _start()
	_tough(run)
	_step(run, 2.0)
	assert_int(run.world.alive_count()).is_greater(0)
	assert_int(run.director.total_waves()).is_equal(3)
	var guard: int = 0
	while run.director.phase != WaveDirector.Phase.CLEARED and guard < 120:
		_step(run, 1.0)
		guard += 1
	assert_int(run.director.phase).is_equal(WaveDirector.Phase.CLEARED)
	assert_bool(run.gate_open).is_true()
	assert_int(run.run.kills).is_greater_equal(8)
	assert_int(run.world.alive_count()).is_equal(0)


func test_gate_leads_to_next_grove() -> void:
	var run: GroveRun = _start()
	_tough(run)
	var guard: int = 0
	while not run.gate_open and guard < 120:
		_step(run, 1.0)
		guard += 1
	(run.get_node("%Player") as Player).global_position = run.plan.gate_position() + Vector2(0, 12)
	_step(run, 0.1)
	assert_bool(run.in_transition).is_true()
	await get_tree().create_timer(1.0).timeout
	assert_int(run.run.grove).is_equal(2)
	assert_bool(run.gate_open).is_false()


func test_death_revive_once_then_camp_banks() -> void:
	var run: GroveRun = _start()
	run.run.add_meat(12)
	run.run.add_spirit(5)
	run.run.take_damage(9999)
	_step(run, GroveRun.DEFEAT_DELAY + 0.2)
	var defeat: DefeatScreen = run.get_node("%Defeat") as DefeatScreen
	assert_bool(defeat.visible).is_true()
	run._on_revive_pressed()  # fake rewarded ad grants immediately
	assert_bool(run.run.is_dead()).is_false()
	assert_bool(defeat.visible).is_false()
	run.run.take_damage(9999)
	_step(run, GroveRun.DEFEAT_DELAY + 0.2)
	assert_bool((defeat.get_node("%ReviveButton") as Button).disabled).is_true()
	run.profile.bank_run(run.run)
	assert_int(run.profile.meat).is_equal(12)
	assert_int(run.profile.spirit).is_equal(5)


func test_god_spends_spirit_and_cools_down() -> void:
	var run: GroveRun = _start()
	_tough(run)
	_step(run, 3.0)
	assert_bool(run.gods.try_cast(Ids.MEGHRA)).is_false()  # no spirit yet
	run.run.add_spirit(5)
	assert_bool(run.gods.try_cast(Ids.VAYLI)).is_true()
	assert_int(run.run.spirit).is_equal(3)
	assert_bool(run.gods.can_cast(Ids.VAYLI)).is_false()
	_step(run, GameData.god(Ids.VAYLI).cooldown + 0.1)
	assert_bool(run.gods.can_cast(Ids.VAYLI)).is_true()


func test_cage_frees_after_standing_close() -> void:
	var run: GroveRun = _start()
	assert_bool(run.plan.has_cage()).is_true()  # grove 1 always has the bird cage
	var player: Player = run.get_node("%Player") as Player
	player.global_position = run.cage.position + Vector2(10, 0)
	var spirit_before: int = run.run.spirit
	_step(run, 0.5)
	assert_bool(run.cage.is_free).is_false()
	_step(run, 0.6)
	assert_bool(run.cage.is_free).is_true()
	assert_bool(run.guides.has(Ids.PIRA)).is_true()
	_step(run, 1.5)
	assert_int(run.run.spirit).is_greater(spirit_before)


func test_ten_room_transitions_leave_no_orphans() -> void:
	var run: GroveRun = _start()
	await get_tree().process_frame
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for g: int in range(2, 12):
		run.start_grove(g)
		_step(run, 0.5)
		await get_tree().process_frame
	await get_tree().process_frame
	assert_int(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))).is_equal(before)
	assert_int(run.run.grove).is_equal(11)


func test_fifth_grove_brings_rotheart_and_its_fight_loop() -> void:
	var run: GroveRun = _start()
	_tough(run)
	run.start_grove(5)
	_step(run, 2.5)
	var boss: RotheartBoss = run.world.boss()
	assert_object(boss).is_not_null()
	var phases: Array[int] = []
	boss.phase_changed.connect(func(p: int) -> void: phases.append(p))
	_step(run, 12.0)
	assert_array(phases).contains([RotheartBoss.Phase.TELEGRAPH])
	# Heart weak point: double damage while stunned.
	boss._set_phase(RotheartBoss.Phase.STUNNED)
	var hp: int = boss.hp
	boss.take_damage(10, Vector2.RIGHT)
	assert_int(hp - boss.hp).is_equal(20)


func test_first_run_tutorial_walks_through_every_step_once() -> void:
	var run: GroveRun = _start(11, true)
	_tough(run)
	assert_object(run.tutorial).is_not_null()
	assert_int(run.run.grove).is_equal(0)
	assert_bool(run.director.hold).is_true()
	var player: Player = run.get_node("%Player") as Player
	player.global_position += Vector2(0, -70)
	_step(run, 0.2)
	assert_int(run.tutorial.step).is_equal(TutorialFlow.Step.SHOOT)
	assert_bool(run.director.hold).is_false()
	var guard: int = 0
	while run.tutorial.step == TutorialFlow.Step.SHOOT and guard < 60:
		_step(run, 1.0)
		guard += 1
	assert_int(run.tutorial.step).is_equal(TutorialFlow.Step.CAGE)
	player.global_position = run.cage.position + Vector2(10, 0)
	_step(run, 1.2)
	assert_int(run.tutorial.step).is_equal(TutorialFlow.Step.GOD)
	assert_int(run.run.spirit).is_greater_equal(TutorialFlow.GOD_SPIRIT)
	assert_bool(run.gods.try_cast(Ids.MEGHRA)).is_true()
	_step(run, 0.1)
	assert_int(run.tutorial.step).is_equal(TutorialFlow.Step.GATE)
	guard = 0
	while not run.gate_open and guard < 60:
		_step(run, 1.0)
		guard += 1
	assert_bool(run.gate_open).is_true()
	player.global_position = run.plan.gate_position() + Vector2(0, 12)
	_step(run, 0.1)
	assert_object(run.tutorial).is_null()
	assert_bool(run.profile.tutorial_done).is_true()
	await get_tree().create_timer(1.0).timeout
	assert_int(run.run.grove).is_equal(1)
	var saved: Dictionary = Services.save.load_game()["profile"]
	assert_bool(saved.get("tutorial_done", false) == true).is_true()


func test_tutorial_is_skipped_once_done() -> void:
	Services.save.set_value("profile", {"tutorial_done": true})
	Services.save.save_game()
	var run: GroveRun = _start(11, true)
	assert_object(run.tutorial).is_null()
	assert_int(run.run.grove).is_equal(1)


func test_pause_and_resume() -> void:
	var run: GroveRun = _start()
	run.open_pause()
	assert_bool(get_tree().paused).is_true()
	assert_bool((run.get_node("%Pause") as Control).visible).is_true()
	run.resume()
	assert_bool(get_tree().paused).is_false()
	assert_bool((run.get_node("%Pause") as Control).visible).is_false()


func test_dda_rates_the_cleared_room() -> void:
	var run: GroveRun = _start()
	_tough(run)
	var guard: int = 0
	while not run.gate_open and guard < 120:
		_step(run, 1.0)
		guard += 1
	assert_int(run.skill.rooms).is_equal(1)
	assert_float(run.skill.rating).is_not_equal(SkillRating.START)


func test_a_grove_sounds_like_the_audio_bible() -> void:
	var run: GroveRun = _start()
	_tough(run)
	assert_str(String(_audio.context)).is_equal("run")
	assert_str(String(_audio.bed)).is_equal("amb.grove.default.bed")
	assert_bool(_audio.loops.values().has(&"sfx.world.gate.seal_hum")).is_true()
	var guard: int = 0
	while not run.gate_open and guard < 120:
		_step(run, 1.0)
		guard += 1
	assert_int(_audio.count(&"sfx.player.bow.release.t1")).is_greater(0)
	assert_int(_audio.count(&"sfx.player.arrow.impact.flesh")).is_greater(0)
	assert_int(_audio.count(&"sfx.enemy.rotling.death")).is_greater_equal(8)
	assert_int(_audio.count(&"sfx.world.portal.open")).is_greater(0)
	assert_int(_audio.count(&"sfx.world.gate.open")).is_equal(1)
	assert_bool(_audio.loops.values().has(&"sfx.world.gate.seal_hum")).is_false()
	assert_int(_audio.phase).is_greater_equal(0)


func test_spirit_pickups_climb_a_pentatonic_ladder() -> void:
	var run: GroveRun = _start()
	for i: int in 3:
		run._on_pickup_collected(Ids.SPIRIT, 1, Vector2.ZERO)
	var idx: int = _audio.played.rfind(&"sfx.pickup.spirit.collect")
	assert_float(_audio.pitches[idx]).is_equal_approx(pow(2.0, 4.0 / 12.0), 0.001)
	run._spirit_t = 0.0
	run._on_pickup_collected(Ids.SPIRIT, 1, Vector2.ZERO)
	assert_float(_audio.pitches[_audio.pitches.size() - 1]).is_equal_approx(1.0, 0.001)


func test_hurt_plays_feedback_hitstop_and_low_hp_heartbeat() -> void:
	var run: GroveRun = _start()
	run.run.hp = 3
	run._feed_dda(0.1, 0)
	assert_bool(_audio.low_hp).is_true()
	assert_bool(_audio.loops.values().has(&"sfx.fb.lowhp.heartbeat_loop")).is_true()
	run._on_impact(run.tuning.hitstop_hurt)
	assert_float(run._hitstop).is_equal_approx(0.06, 0.0001)


func test_pause_ducks_music_and_death_plays_defeat() -> void:
	var run: GroveRun = _start()
	run.open_pause()
	assert_bool(_audio.paused).is_true()
	run.resume()
	assert_bool(_audio.paused).is_false()
	run.run.take_damage(run.run.hp)
	assert_int(_audio.count(&"sfx.player.death")).is_equal(1)
	assert_str(String(_audio.clip)).is_equal("defeat")
