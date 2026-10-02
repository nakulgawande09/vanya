class_name Player
extends CharacterBody2D
## The hunter. Moves with the floating joystick (or arrow keys / WASD on desktop), and the
## auto-aim bow looses at the nearest beast in range at the equipped tier's rate.
## Drives the cut-out rig's idle / run / shoot / hurt / down / revive clips.

signal shot
signal hurt(amount: int)

const IFRAMES: float = 0.6
const TWIN_SPREAD: float = 0.12

@export var hitbox_radius: float = 14.0

var speed: float = 150.0
var arrow: ArrowDef
var world: CombatWorld
var light_scale: float = 1.0
## Auto-aim knobs (range scale, retarget delay) come from here.
var tuning: FeelTuning = FeelTuning.new()
var input_vector: Vector2 = Vector2.ZERO
var downed: bool = false
var _visual: Node2D
var _anim: AnimationPlayer
var _glow: Node2D
var _fire_t: float = 0.0
var _iframe_t: float = 0.0
var _facing: float = 1.0
var _shooting_t: float = 0.0
var _target: int = -1
var _target_age: float = 0.0


func setup(arrow_def: ArrowDef, move_speed: float, emissive_layer: Node) -> void:
	arrow = arrow_def
	speed = move_speed
	if _visual == null:
		_visual = ThemeRegistry.visual_for(Ids.HUNTER).instantiate() as Node2D
		add_child(_visual)
		_anim = _visual.get_node("AnimationPlayer") as AnimationPlayer
		_glow = Emissive.lift(_visual, emissive_layer)


func set_move_input(v: Vector2) -> void:
	input_vector = v.limit_length(1.0)


func is_invulnerable() -> bool:
	return _iframe_t > 0.0 or downed


## Applies damage with i-frames; returns the damage the run should take.
func receive_damage(amount: int) -> int:
	if amount <= 0 or is_invulnerable():
		return 0
	_iframe_t = IFRAMES
	_play(&"hurt")
	hurt.emit(amount)
	return amount


func knock_down() -> void:
	downed = true
	velocity = Vector2.ZERO
	_play(&"down")


func revive() -> void:
	downed = false
	_iframe_t = 2.0
	_play(&"revive")


## Movement + bow. Called by the run in its fixed tick (not _physics_process).
func tick(delta: float) -> void:
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_shooting_t = maxf(0.0, _shooting_t - delta)
	if downed:
		return
	var v: Vector2 = input_vector
	if v == Vector2.ZERO:
		# Keys, or the built-in VirtualJoystick when it is on (it applies its own dead zone).
		v = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.05)
	var pace: float = speed * (world.field.speed_factor(global_position) if world != null else 1.0)
	velocity = v * pace
	move_and_slide()
	if absf(v.x) > 0.1 and _shooting_t <= 0.0:
		_facing = signf(v.x)
	_visual.scale.x = _facing
	modulate.a = 0.55 if _iframe_t > 0.0 and int(_iframe_t * 20.0) % 2 == 0 else 1.0
	_fire_t -= delta
	_target_age += delta
	if _fire_t <= 0.0 and world != null:
		var aim_range: float = arrow.aim_range * tuning.aim_range_scale
		var target: int = world.nearest_enemy(global_position, aim_range)
		# Retarget delay (feel-test #6): stay on the current beast for a moment while it lives.
		if _target >= 0 and target != _target and _target_age < tuning.aim_retarget_delay and world.is_alive(_target) \
				and world.handle_position(_target).distance_to(global_position) <= aim_range:
			target = _target
		if target != _target:
			_target = target
			_target_age = 0.0
		if target >= 0:
			_loose(world.handle_position(target))
			_fire_t = arrow.fire_interval
	if _shooting_t <= 0.0 and (_anim.current_animation != &"hurt" or not _anim.is_playing()):
		_play(&"run" if v.length() > 0.1 else &"idle")


func _loose(at: Vector2) -> void:
	var from: Vector2 = global_position + Vector2(0, -36)
	var dir: Vector2 = (at - from).normalized()
	_facing = 1.0 if dir.x >= 0.0 else -1.0
	var dmg: int = Damage.arrow(arrow, world.damage_bonus)
	if arrow.twin_shot:
		world.projectiles.fire_arrow(from, dir.rotated(-TWIN_SPREAD), arrow.speed, dmg, arrow.pierce)
		world.projectiles.fire_arrow(from, dir.rotated(TWIN_SPREAD), arrow.speed, dmg, arrow.pierce)
	else:
		world.projectiles.fire_arrow(from, dir, arrow.speed, dmg, arrow.pierce)
	_shooting_t = 6.0 / 14.0
	_play(&"shoot", true)
	shot.emit()


func _play(anim: StringName, restart: bool = false) -> void:
	if _anim == null:
		return
	if restart or _anim.current_animation != anim:
		_anim.play(anim)
