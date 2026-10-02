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

## Fixed seed for tests and benchmarks; 0 picks a fresh one per run.
@export var run_seed: int = 0
@export var auto_start: bool = true

var run: RunState
var profile: Profile
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

@onready var _floor: TileMapLayer = %Floor
@onready var _decals: Node2D = %Decals
@onready var _entities: Node2D = %Entities
@onready var _player: Player = %Player
@onready var _camera: Camera2D = %Camera
@onready var _emissive: CanvasLayer = %Emissive
@onready var _hud: Hud = %Hud
@onready var _fade: ColorRect = %Fade
@onready var _defeat: DefeatScreen = %Defeat

var _darkness: Darkness
var _builder: RoomBuilder
var _next_plan: RoomPlan
var _next_task: int = -1
var _defeat_t: float = -1.0
var _shake: float = 0.0
var _orbs: PackedVector2Array = PackedVector2Array()
var _extra_lights: Array[Vector2] = []
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	profile = Profile.from_dict(_saved_profile())
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
	add_child(world)
	_builder = RoomBuilder.new(_emissive)
	plan = RoomGenerator.generate(rules, run_seed, 1)
	world.setup(plan.walkable_rect(), {"emissive": _emissive, "decals": _decals, "entities": _entities}, run, _player,
			GameData.shrine_bonus(profile, ShrineDef.Stat.DAMAGE), run_seed)
	world.projectiles.set_arrow_texture(ThemeRegistry.texture_for(GameData.arrow(profile.equipped_arrow).texture_id))
	world.shake_requested.connect(func(a: float) -> void: _shake = maxf(_shake, a))
	_player.world = world
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
	_defeat.revive_pressed.connect(_on_revive_pressed)
	_defeat.camp_pressed.connect(end_run)
	_defeat.visible = false
	EventBus.quality_changed.connect(_on_quality_changed)
	AdaptiveQuality.set_combat(true)
	EventBus.run_started.emit(run_seed)
	Services.analytics.log_event(&"run_started", {"theme_id": String(ThemeRegistry.theme_id)})
	if auto_start:
		start_grove(1)


func _exit_tree() -> void:
	if _next_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_next_task)
		_next_task = -1
	AdaptiveQuality.set_combat(false)


## Backgrounding pauses the run and flushes a checkpoint (standards §B.4); focus resumes it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if run != null:
			_save_checkpoint()
		if is_inside_tree():
			get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_inside_tree():
			get_tree().paused = false


## Builds a fresh room for `grove` (between rooms only: never instantiates during waves).
## `room` is a plan generated ahead of time (off the main thread); null generates one now.
func start_grove(grove: int, room: RoomPlan = null) -> void:
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
	var defs: Dictionary[StringName, ArchetypeDef] = world.defs
	var waves: Array[Array] = WavePlanner.plan(GameData.waves(), grove, defs, SeededRng.new(run_seed, grove, &"waves"))
	director = WaveDirector.new(waves, _builder.portal_positions(plan), GameData.waves().wave_spacing)
	director.portals_changed.connect(_on_portals_changed)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)
	AdaptiveQuality.commit_pending()
	_hud.set_grove(grove)


func _physics_process(delta: float) -> void:
	if director == null:
		return
	run.tick(delta)
	_player.tick(delta)
	var incoming: int = world.tick(delta)
	if not in_transition and not run.is_dead():
		var taken: int = _player.receive_damage(incoming)
		if taken > 0:
			run.take_damage(taken)
			world.numbers.show_number(_player.global_position + Vector2(0, -90), taken, DamageNumbers.Kind.HURT)
			world.shake(3.0)
		director.tick(delta, world)
	if cage != null and cage.tick(delta, _player.global_position):
		_on_cage_freed(cage)
	guides.tick(delta, incoming > 0)
	gods.tick(delta)
	if gate_open and not in_transition and _player.global_position.distance_to(plan.gate_position() + Vector2(0, 12)) < GATE_RANGE:
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
	_hud.set_guide(Ids.PIRA if guides.has(Ids.PIRA) else (Ids.JUGNU if guides.has(Ids.JUGNU) else &""))


func _update_camera(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		_camera.offset = Vector2(_shake_rng.randf_range(-_shake, _shake), _shake_rng.randf_range(-_shake, _shake))
	else:
		_camera.offset = Vector2.ZERO


func _on_portals_changed(open: bool) -> void:
	for p: Node2D in _builder.portals:
		p.visible = open


func _on_wave_started(index: int, total: int) -> void:
	_hud.set_wave(index, total)
	if index > 0:
		AdaptiveQuality.commit_pending()


func _on_room_cleared() -> void:
	gate_open = true
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
	match c.kind:
		Ids.CAGE_BIRD:
			guides.add(Ids.PIRA)
			run.add_guide(Ids.PIRA)
		Ids.CAGE_JAR:
			guides.add(Ids.JUGNU)
			run.add_guide(Ids.JUGNU)
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
	_defeat.visible = false
	_hud.set_health(run.hp, run.max_hp)


func _on_quality_changed(_old: int, _new: int) -> void:
	world.set_quality(AdaptiveQuality.profile)


func _save_checkpoint() -> void:
	Services.save.set_value(CHECKPOINT_KEY, {"grove": run.grove, "meat": run.meat, "spirit": run.spirit})
	Services.save.flush()


func _saved_profile() -> Dictionary:
	var data: Dictionary = Services.save.load_game()
	var p: Variant = data.get("profile", {})
	return p if p is Dictionary else {}
