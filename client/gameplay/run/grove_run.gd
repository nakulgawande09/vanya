class_name GroveRun
extends Node2D
## One run from camp: grove after grove until the hunter falls. Owns the RunState and drives
## every gameplay system from a single fixed tick (_physics_process), in order:
## run → hunter → combat world → waves → cages → guides → gods → gate → lighting → HUD.
## The darkness follows the bible's "how the scene is lit": a night-ink veil with light holes,
## emissives above it.

const CAMP_SCENE: String = "res://ui/screens/main.tscn"
const BASE_LIGHT: float = 175.0
const TORCH_LIGHT: float = 95.0
const GATE_RANGE: float = 30.0
const DEFEAT_DELAY: float = 1.1
const CHECKPOINT_KEY: String = "run_checkpoint"
## Loop keys for Services.audio.
const LOOP_GATE: int = 2001
const LOOP_TORCH: int = 2002
const LOOP_PORTAL: int = 2003
const LOOP_LOWHP: int = 2004
const LOOP_COMPANION: int = 2005
const STEP_INTERVAL: float = 0.32
const LOW_HP: float = 0.25
## Spirit pickups climb a pentatonic ladder inside a 0.6 s combo window (Audio Bible A2).
const SPIRIT_COMBO: float = 0.6
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16]
const FRENZY_TIERS: Array[int] = [3, 6, 10, 15, 20]
const FRENZY_SOUNDS: Array[StringName] = [&"sfx.fb.frenzy.tier1", &"sfx.fb.frenzy.tier2", &"sfx.fb.frenzy.tier3",
		&"sfx.fb.frenzy.tier4", &"sfx.fb.frenzy.tier5"]
const AMBIENCE_BED: StringName = &"amb.grove.default.bed"

## Fixed seed for tests and benchmarks; 0 picks a fresh one per run.
@export var run_seed: int = 0
@export var auto_start: bool = true
## Run the first-run tutorial grove when the profile hasn't finished it (tests turn this off).
@export var tutorial_enabled: bool = true

var run: RunState
var profile: Profile
var settings: GameSettings
var skill: SkillRating
var rails: DdaRails = DdaRails.new()
var intensity: IntensityDirector
var tutorial: TutorialFlow
var world: CombatWorld
var gods: GodCaster
var guides: Guides
var director: WaveDirector
var rules: RoomRules = preload("res://pcg/room_rules.tres")
var plan: RoomPlan
var cage: Cage
var light_bonus: float = 0.0
var gate_open: bool = false
var in_transition: bool = false
## Every feel knob (hit-stop, shake, haptics, joystick): data/feel/feel_tuning.tres.
var tuning: FeelTuning

@onready var _floor: TileMapLayer = %Floor
@onready var _decals: Node2D = %Decals
@onready var _entities: Node2D = %Entities
@onready var _player: Player = %Player
@onready var _camera: Camera2D = %Camera
@onready var _emissive: CanvasLayer = %Emissive
@onready var _hud: Hud = %Hud
@onready var _fade: ColorRect = %Fade
@onready var _defeat: DefeatScreen = %Defeat
@onready var _pause: PauseScreen = %Pause
@onready var _settings_screen: SettingsScreen = %Settings

var _darkness: Darkness
var _builder: RoomBuilder
var _next_plan: RoomPlan
var _next_task: int = -1
var _defeat_t: float = -1.0
var _shake_px: float = 0.0
var _shake_t: float = 0.0
var _shake_len: float = 0.0
var _orbs: PackedVector2Array = PackedVector2Array()
var _extra_lights: Array[Vector2] = []
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _near: PackedInt32Array = PackedInt32Array()
# Per-room DDA bookkeeping.
var _room_d: float = 0.0
var _room_scale: float = 1.0
var _room_t: float = 0.0
var _room_damage: int = 0
var _room_min_hp: float = 1.0
var _room_near_deaths: int = 0
var _room_rated: bool = false
var _was_low: bool = false
var _hitstop: float = 0.0
var _since_stop: float = 1.0
var _step_t: float = 0.0
var _spirit_step: int = -1
var _spirit_t: float = 0.0
var _low_hp: bool = false
var _frenzy_tier: int = 0
var _arrow_tier: int = 0


func _ready() -> void:
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	profile = Profile.from_dict(_saved_profile())
	settings = GameSettings.from_dict(_saved_settings())
	tuning = FeelTuning.load_active()
	skill = SkillRating.from_dict(profile.skill)
	rails.adaptive = settings.adaptive_challenge
	_near.resize(48)
	var hunter_def: ArchetypeDef = GameData.archetype(Ids.HUNTER)
	var max_hp: int = hunter_def.max_hp + int(GameData.shrine_bonus(profile, ShrineDef.Stat.HEALTH))
	run = RunState.new(max_hp)
	light_bonus = GameData.shrine_bonus(profile, ShrineDef.Stat.LIGHT)
	_darkness = Darkness.new()
	_darkness.name = "Darkness"
	add_child(_darkness)
	_darkness.set_veil(ThemeRegistry.darkness())
	_floor.tile_set = ThemeRegistry.tileset()
	_player.setup(GameData.arrow(profile.equipped_arrow),
			hunter_def.move_speed * (1.0 + GameData.shrine_bonus(profile, ShrineDef.Stat.SPEED)), _emissive)
	_player.hitbox_radius = hunter_def.hitbox_radius
	world = CombatWorld.new()
	world.name = "Combat"
	world.tuning = tuning
	add_child(world)
	_builder = RoomBuilder.new(_emissive)
	plan = RoomGenerator.generate(rules, run_seed, 1)
	world.setup(plan.walkable_rect(), {"emissive": _emissive, "decals": _decals, "entities": _entities}, run, _player,
			GameData.shrine_bonus(profile, ShrineDef.Stat.DAMAGE), run_seed)
	world.projectiles.set_arrow_texture(ThemeRegistry.texture_for(GameData.arrow(profile.equipped_arrow).texture_id))
	world.shake_requested.connect(_on_shake)
	world.impact.connect(_on_impact)
	world.pickups.collected.connect(_on_pickup_collected)
	world.numbers.enabled = settings.damage_numbers
	_player.world = world
	_player.tuning = tuning
	_player.shot.connect(_on_shot)
	_arrow_tier = maxi(0, GameData.ARROWS.find(profile.equipped_arrow))
	gods = GodCaster.new()
	gods.name = "Gods"
	_emissive.add_child(gods)
	gods.setup(world)
	gods.flash.connect(_hud.flash)
	guides = Guides.new()
	guides.name = "Guides"
	_entities.add_child(guides)
	guides.setup(world, _emissive)
	_orbs.resize(6)
	run.health_changed.connect(_hud.set_health)
	run.currency_changed.connect(_hud.set_currencies)
	run.died.connect(_on_died)
	_hud.move_input.connect(_player.set_move_input)
	_hud.god_pressed.connect(func(g: StringName) -> void: gods.try_cast(g))
	_hud.set_health(run.hp, run.max_hp)
	_hud.set_currencies(run.meat, run.spirit)
	_hud.flash_intensity = settings.flash_intensity
	_hud.set_left_handed(settings.left_handed)
	_hud.pause_pressed.connect(open_pause)
	_pause.resume_pressed.connect(resume)
	_pause.settings_pressed.connect(func() -> void:
		_pause.visible = false
		_settings_screen.open())
	_pause.abandon_pressed.connect(func() -> void:
		get_tree().paused = false
		end_run())
	_settings_screen.closed.connect(_on_settings_closed)
	_defeat.revive_pressed.connect(_on_revive_pressed)
	_defeat.camp_pressed.connect(end_run)
	_defeat.visible = false
	EventBus.quality_changed.connect(_on_quality_changed)
	AdaptiveQuality.set_combat(true)
	Services.audio.music_context(&"run")
	Services.audio.ambience(AMBIENCE_BED, 0.0)
	EventBus.run_started.emit(run_seed)
	Services.analytics.log_event(&"run_started", {"theme_id": String(ThemeRegistry.theme_id)})
	_hud.skip_pressed.connect(skip_tutorial)
	if auto_start:
		if tutorial_enabled and not profile.tutorial_done:
			start_tutorial()
		else:
			start_grove(1)


func _exit_tree() -> void:
	if _next_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_next_task)
		_next_task = -1
	AdaptiveQuality.set_combat(false)
	Services.audio.stop_all_loops()
	Services.audio.set_low_hp(false)
	Services.audio.set_paused(false)
	Services.audio.ambience(&"", 0.0)


## Backgrounding or Android back opens the pause menu and flushes a checkpoint (standards §B.4).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST:
			if run != null:
				_save_checkpoint()
			open_pause()


func open_pause() -> void:
	if not is_inside_tree() or _pause == null or run == null or run.is_dead() or _settings_screen.visible:
		return
	get_tree().paused = true
	Services.audio.set_paused(true)
	_pause.open()


func resume() -> void:
	_pause.visible = false
	get_tree().paused = false
	Services.audio.set_paused(false)


func _on_settings_closed(_needs_reload: bool) -> void:
	_apply_settings()
	_pause.open()


func _apply_settings() -> void:
	settings = GameSettings.from_dict(_saved_settings())
	rails.adaptive = settings.adaptive_challenge
	world.numbers.enabled = settings.damage_numbers
	_hud.flash_intensity = settings.flash_intensity
	_hud.set_left_handed(settings.left_handed)
	Boot.apply_audio_settings(settings)


## The first-run tutorial: a fixed room, three Rotlings held until the hunter has moved.
func start_tutorial() -> void:
	var rotlings: Array[Array] = [[Ids.ROTLING, Ids.ROTLING, Ids.ROTLING]]
	start_grove(0, RoomGenerator.tutorial(rules), rotlings)
	_room_rated = true
	director.hold = true
	tutorial = TutorialFlow.new(self)
	tutorial.begin()
	Services.analytics.log_event(&"tutorial_started", {})


func skip_tutorial() -> void:
	if tutorial == null:
		return
	Services.analytics.log_event(&"tutorial_skipped", {"step": tutorial.step})
	_finish_tutorial()
	_go_to_next_grove()


## Builds a fresh room for `grove` (between rooms only: never instantiates during waves).
## `room` is a plan generated ahead of time (off the main thread); null generates one now.
## `fixed_waves` replaces the planner (tutorial).
func start_grove(grove: int, room: RoomPlan = null, fixed_waves: Array[Array] = []) -> void:
	world.clear()
	_builder.clear()
	run.grove = grove
	plan = room if room != null else RoomGenerator.generate(rules, run_seed, grove)
	_builder.build(plan, _floor, _decals, _entities, run_seed)
	world.set_room(plan)
	_place_cage()
	_player.position = plan.start_position()
	_player.velocity = Vector2.ZERO
	var size: Vector2 = plan.size_px()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)
	_camera.reset_smoothing()
	gate_open = false
	_room_scale = rails.next_scale(grove, skill.target_difficulty(settings.target_success()))
	_room_d = DdaRails.room_difficulty(grove, _room_scale)
	world.extra_spirit_chance = rails.supply_chance()
	_room_t = 0.0
	_room_damage = 0
	_room_min_hp = float(run.hp) / run.max_hp
	_room_near_deaths = 0
	_room_rated = false
	var defs: Dictionary[StringName, ArchetypeDef] = world.defs
	var waves: Array[Array] = fixed_waves if not fixed_waves.is_empty() else WavePlanner.plan(
			GameData.waves(), grove, defs, SeededRng.new(run_seed, grove, &"waves"), _room_scale)
	intensity = IntensityDirector.new()
	director = WaveDirector.new(waves, _builder.portal_positions(plan), GameData.waves().wave_spacing, intensity)
	director.portals_changed.connect(_on_portals_changed)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)
	AdaptiveQuality.commit_pending()
	_hud.set_grove(grove)
	Services.audio.stop_loop(LOOP_PORTAL)
	Services.audio.start_loop(&"sfx.world.gate.seal_hum", LOOP_GATE)
	if _builder.torches.is_empty():
		Services.audio.stop_loop(LOOP_TORCH)
	else:
		Services.audio.start_loop(&"sfx.world.torch.loop", LOOP_TORCH)
	Services.audio.ambience(AMBIENCE_BED, 0.0)
	Services.audio.music_clip(&"grove")


func _physics_process(delta: float) -> void:
	if director == null:
		return
	if _hitstop > 0.0:
		# Hit-stop: freeze the simulation for a few frames, keep the camera and HUD alive.
		_hitstop -= delta
		_update_camera(delta)
		return
	_since_stop += delta
	_spirit_t = maxf(0.0, _spirit_t - delta)
	run.tick(delta)
	_player.tick(delta)
	_footsteps(delta)
	var incoming: int = world.tick(delta)
	if not in_transition and not run.is_dead():
		var taken: int = _player.receive_damage(incoming)
		if taken > 0:
			run.take_damage(taken)
			world.numbers.show_number(_player.global_position + Vector2(0, -90), taken, DamageNumbers.Kind.HURT)
			world.shake(tuning.shake_hurt)
			_hud.hurt()
			_on_impact(tuning.hitstop_hurt)
			Services.audio.play(&"sfx.player.hurt")
		_feed_dda(delta, taken)
		director.tick(delta, world)
		if tutorial != null:
			tutorial.tick()
	if cage != null:
		var was: float = cage.progress
		if cage.tick(delta, _player.global_position):
			_on_cage_freed(cage)
		elif was <= 0.0 and cage.progress > 0.0:
			Services.audio.play(&"sfx.rescue.cage.creak", cage.position)
	guides.tick(delta, incoming > 0)
	gods.tick(delta)
	if gate_open and not in_transition and _player.global_position.distance_to(plan.gate_position() + Vector2(0, 12)) < GATE_RANGE:
		if tutorial != null:
			Services.analytics.log_event(&"tutorial_completed", {})
			_finish_tutorial()
		_go_to_next_grove()
	if _defeat_t >= 0.0:
		_defeat_t += delta
		if _defeat_t >= DEFEAT_DELAY:
			_defeat_t = -1.0
			_defeat.show_summary(run, not run.revive_used)
	_update_light()
	_update_hud()
	_update_camera(delta)


## Banks the run and returns to camp.
func end_run() -> void:
	Services.audio.stop_all_loops()
	Services.audio.set_low_hp(false)
	profile.bank_run(run)
	Services.save.set_value("profile", profile.to_dict())
	Services.save.set_value(CHECKPOINT_KEY, null)
	Services.save.save_game()
	Services.analytics.log_event(&"run_ended", {"grove": run.grove, "kills": run.kills, "meat": run.meat,
			"spirit": run.spirit, "theme_id": String(ThemeRegistry.theme_id)})
	EventBus.run_ended.emit(false, run.grove - 1)
	SceneRouter.change_to(CAMP_SCENE)


func _place_cage() -> void:
	cage = null
	if not plan.has_cage():
		return
	cage = Cage.new()
	cage.name = "Cage"
	cage.position = RoomPlan.cell_center(plan.cage) + Vector2(0, 12)
	_entities.add_child(cage)
	var kind: StringName = Ids.CAGE_HARE
	if not guides.has(Ids.PIRA):
		kind = Ids.CAGE_BIRD
	elif not guides.has(Ids.JUGNU) and ThemeRegistry.has_visual(Ids.CAGE_JAR):
		kind = Ids.CAGE_JAR
	cage.setup(kind)
	_builder.track(cage)


func _update_light() -> void:
	var xf: Transform2D = get_viewport().get_canvas_transform()
	_darkness.begin()
	var hunter_light: float = BASE_LIGHT * (1.0 + light_bonus) * guides.light_scale()
	_darkness.add_hole(xf, _player.global_position + Vector2(0, -30), hunter_light, 1.0)
	for p: Vector2 in _builder.torches:
		_darkness.add_hole(xf, p + Vector2(0, -40), TORCH_LIGHT, 0.95)
	if cage != null and not cage.is_free:
		_darkness.add_hole(xf, cage.position + Vector2(0, -20), 60.0, 0.8)
	if gate_open:
		_darkness.add_hole(xf, plan.gate_position() + Vector2(0, -20), 80.0, 0.9)
	var n: int = world.projectiles.orb_positions(_orbs)
	for i: int in n:
		_darkness.add_hole(xf, _orbs[i], 34.0, 0.7)
	_extra_lights.clear()
	guides.light_points(_extra_lights)
	for p: Vector2 in _extra_lights:
		_darkness.add_hole(xf, p, 30.0, 0.6)
	_darkness.commit()


func _update_hud() -> void:
	for id: StringName in GameData.GODS:
		_hud.set_god_state(id, gods.can_cast(id), gods.cooldowns[id], gods.cooldown_fraction(id))
	_hud.set_frenzy(run.frenzy)
	var tier: int = 0
	while tier < FRENZY_TIERS.size() and run.frenzy >= FRENZY_TIERS[tier]:
		tier += 1
	if tier > _frenzy_tier:
		Services.audio.play(FRENZY_SOUNDS[tier - 1])
	_frenzy_tier = tier
	_hud.set_guide(Ids.PIRA if guides.has(Ids.PIRA) else (Ids.JUGNU if guides.has(Ids.JUGNU) else &""))


func _update_camera(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t = maxf(0.0, _shake_t - delta)
		var a: float = _shake_px * _shake_t / maxf(0.001, _shake_len)
		_camera.offset = Vector2(_shake_rng.randf_range(-a, a), _shake_rng.randf_range(-a, a))
	else:
		_camera.offset = Vector2.ZERO


## Shake (px, seconds) from FeelTuning; a stronger shake replaces a weaker one in progress.
func _on_shake(px: float, seconds: float) -> void:
	if not settings.screen_shake or px <= 0.0:
		return
	var current: float = _shake_px * _shake_t / maxf(0.001, _shake_len)
	if px >= current:
		_shake_px = px
		_shake_t = seconds
		_shake_len = seconds
	if px >= 8.0:
		Services.audio.play(&"sfx.fb.shake.rumble")


## Hit-stop request. Short stops (swarm kills) respect a minimum gap so a dying swarm doesn't
## stutter; elite, hurt, god and boss stops always land (feel-test B4).
func _on_impact(seconds: float) -> void:
	var s: float = seconds * tuning.hitstop_scale
	if s <= 0.0:
		return
	if _hitstop > 0.0:
		_hitstop = maxf(_hitstop, s)
	elif _since_stop >= tuning.hitstop_min_gap or seconds >= tuning.hitstop_elite_kill:
		_hitstop = s
		_since_stop = 0.0


func _on_shot() -> void:
	Services.audio.play(AudioIds.release(_arrow_tier), _player.global_position)


func _footsteps(delta: float) -> void:
	if _player.velocity.length_squared() < 400.0 or _player.downed:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = STEP_INTERVAL
		var slow: bool = world.field.speed_factor(_player.global_position) < 1.0
		Services.audio.play(&"sfx.player.step.earth" if slow else &"sfx.player.step.grass")


func hud() -> Hud:
	return _hud


func hunter_position() -> Vector2:
	return _player.global_position


func to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _finish_tutorial() -> void:
	tutorial.finish()
	tutorial = null
	profile.tutorial_done = true
	Services.save.set_value("profile", profile.to_dict())
	Services.save.save_game()


func _on_pickup_collected(kind: StringName, _amount: int, at: Vector2) -> void:
	_hud.fly_pickup(kind, get_viewport().get_canvas_transform() * at)
	if kind == Ids.SPIRIT:
		_spirit_step = mini(_spirit_step + 1, PENTATONIC.size() - 1) if _spirit_t > 0.0 else 0
		_spirit_t = SPIRIT_COMBO
		Services.audio.play(&"sfx.pickup.spirit.collect", AudioService.NO_POS, pow(2.0, PENTATONIC[_spirit_step] / 12.0))
	else:
		Services.audio.play(&"sfx.pickup.meat.collect")


func _on_portals_changed(open: bool) -> void:
	for p: Node2D in _builder.portals:
		p.visible = open
	if not _builder.portals.is_empty():
		Services.audio.play(&"sfx.world.portal.open" if open else &"sfx.world.portal.close", _builder.portals[0].position)
	if open:
		Services.audio.start_loop(&"sfx.world.portal.loop", LOOP_PORTAL)
	else:
		Services.audio.stop_loop(LOOP_PORTAL)
	Services.audio.ambience(AMBIENCE_BED, 1.0 if open else 0.0)


func _on_wave_started(index: int, total: int) -> void:
	_hud.set_wave(index, total)
	if index > 0:
		AdaptiveQuality.commit_pending()


func _on_room_cleared() -> void:
	if tutorial != null:
		return  # the tutorial opens its gate after the god step
	_rate_room(true)
	rails.on_grove_cleared()
	open_gate()


func open_gate() -> void:
	gate_open = true
	Services.audio.stop_loop(LOOP_GATE)
	Services.audio.play(&"sfx.world.gate.open")
	if plan.family == rules.boss_family:
		Services.audio.music_clip(&"victory")
	if _builder.gate_sealed != null:
		_builder.gate_sealed.visible = false
	if _builder.gate_open != null:
		_builder.gate_open.visible = true
	_save_checkpoint()
	Services.analytics.log_event(&"room_cleared", {"grove": run.grove, "hp": run.hp, "kills": run.kills})


func _on_cage_freed(c: Cage) -> void:
	run.animals_freed += 1
	world.pickups.drop(Ids.SPIRIT, c.position + Vector2(0, -10), Cage.SPIRIT_REWARD)
	world.fx.play(&"ash_burst", c.position + Vector2(0, -20), 1.0)
	Services.audio.play(&"sfx.rescue.cage.break", c.position)
	match c.kind:
		Ids.CAGE_BIRD:
			guides.add(Ids.PIRA)
			run.add_guide(Ids.PIRA)
			Services.audio.play(&"sfx.rescue.freed.pira")
			Services.audio.start_loop(&"sfx.companion.pira.chirp_loop", LOOP_COMPANION)
		Ids.CAGE_JAR:
			guides.add(Ids.JUGNU)
			run.add_guide(Ids.JUGNU)
			Services.audio.play(&"sfx.rescue.freed.jugnu")
			if not guides.has(Ids.PIRA):
				Services.audio.start_loop(&"sfx.companion.jugnu.shimmer_loop", LOOP_COMPANION)
		_:
			Services.audio.play(&"sfx.rescue.freed.hare")
	Services.analytics.log_event(&"animal_freed", {"cage": String(c.kind), "grove": run.grove})


func _go_to_next_grove() -> void:
	in_transition = true
	# Generate the next room on a worker while the screen fades (standards §C4); the main thread
	# only instantiates.
	var next_grove: int = run.grove + 1
	_next_task = WorkerThreadPool.add_task(func() -> void:
		_next_plan = RoomGenerator.generate(rules, run_seed, next_grove), false, "room_generation")
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		WorkerThreadPool.wait_for_task_completion(_next_task)
		_next_task = -1
		run.next_grove()
		start_grove(run.grove, _next_plan)
		_next_plan = null
	)
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: in_transition = false)


func _on_died() -> void:
	Services.audio.play(&"sfx.player.death")
	Services.audio.music_clip(&"defeat")
	Services.audio.stop_loop(LOOP_LOWHP)
	Services.audio.set_low_hp(false)
	_low_hp = false
	_rate_room(false)
	rails.on_death()
	_player.knock_down()
	_defeat_t = 0.0
	Services.analytics.log_event(&"hunter_down", {"grove": run.grove})


func _on_revive_pressed() -> void:
	if run.revive_used:
		return
	Services.ads.rewarded_earned.connect(_on_revive_rewarded, CONNECT_ONE_SHOT)
	Services.ads.show_rewarded(&"revive")


func _on_revive_rewarded(placement: StringName) -> void:
	if placement != &"revive" or not run.revive():
		return
	Services.analytics.log_event(&"ad_reward_granted", {"placement": String(placement), "grove": run.grove})
	_player.revive()
	Services.audio.play(&"sfx.player.revive")
	Services.audio.music_clip(&"boss" if world.boss() != null else &"grove")
	_defeat.visible = false
	_hud.set_health(run.hp, run.max_hp)


func _on_quality_changed(_old: int, _new: int) -> void:
	world.set_quality(AdaptiveQuality.profile)


func _save_checkpoint() -> void:
	Services.save.set_value(CHECKPOINT_KEY, {"grove": run.grove, "meat": run.meat, "spirit": run.spirit})
	profile.skill = skill.to_dict()
	Services.save.set_value("profile", profile.to_dict())
	Services.save.flush()


## DDA inputs each tick: damage share, near-death dips, beasts within 4 tiles (dev-plan §7.3).
func _feed_dda(delta: float, taken: int) -> void:
	_room_t += delta
	_room_damage += taken
	var hp_frac: float = float(run.hp) / run.max_hp
	_room_min_hp = minf(_room_min_hp, hp_frac)
	var low: bool = hp_frac < 0.2
	var near_death: bool = low and not _was_low
	_was_low = low
	if near_death:
		_room_near_deaths += 1
	var close: int = world.enemies_near(_player.global_position, 128.0, _near)
	intensity.feed(delta, float(taken) / run.max_hp, near_death, close)
	Services.audio.set_intensity(intensity.phase, intensity.intensity, run.frenzy)
	var low_now: bool = hp_frac < LOW_HP and not run.is_dead()
	if low_now != _low_hp:
		_low_hp = low_now
		Services.audio.set_low_hp(low_now)
		if low_now:
			Services.audio.start_loop(&"sfx.fb.lowhp.heartbeat_loop", LOOP_LOWHP)
		else:
			Services.audio.stop_loop(LOOP_LOWHP)
	if intensity.wants_relief(hp_frac):
		world.pickups.drop(Ids.SPIRIT, _player.global_position + Vector2(0, -60), 1)


## Rates the room once (clear or the first death) and logs the §7.2 room telemetry.
func _rate_room(cleared: bool) -> void:
	if _room_rated:
		return
	_room_rated = true
	var hp_frac: float = float(maxi(run.hp, 0)) / run.max_hp
	var expected_time: float = 30.0 + 15.0 * director.total_waves()
	var time_score: float = clampf(1.0 - (_room_t - expected_time) / expected_time, 0.0, 1.0)
	var s: float = SkillRating.performance(cleared, hp_frac, _room_near_deaths / 3.0, time_score)
	var ratio: float = float(world.room_kills) / maxf(1.0, float(world.room_spawned))
	var before: float = skill.rating
	skill.update(_room_d, s, cleared, ratio)
	profile.skill = skill.to_dict()
	Services.analytics.log_event(&"room_result", {
		"grove": run.grove, "template": String(plan.family), "fallback_room": plan.fallback,
		"budget_scale": snappedf(_room_scale, 0.01), "difficulty": roundi(_room_d), "rating_before": roundi(before),
		"rating_after": roundi(skill.rating), "performance": snappedf(s, 0.01), "outcome": "clear" if cleared else "death",
		"time_s": roundi(_room_t), "damage_taken": _room_damage, "hp_end": snappedf(hp_frac, 0.01),
		"hp_min": snappedf(_room_min_hp, 0.01), "near_deaths": _room_near_deaths, "kills": world.room_kills,
		"spawned": world.room_spawned, "theme_id": String(ThemeRegistry.theme_id),
		"difficulty_setting": settings.difficulty, "adaptive": settings.adaptive_challenge,
	})


func _saved_settings() -> Dictionary:
	var s: Variant = Services.save.load_game().get("settings", {})
	return s if s is Dictionary else {}


func _saved_profile() -> Dictionary:
	var data: Dictionary = Services.save.load_game()
	var p: Variant = data.get("profile", {})
	return p if p is Dictionary else {}
