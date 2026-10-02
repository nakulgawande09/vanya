class_name WispEnemy
extends SceneEnemy
## Ranged: drifts at the edge of the light and spits blight orbs. Its one eye flares for
## tell_time (0.4 s) before each spit — the only warning (Blight beasts board).

enum Phase { DRIFT, TELL }

const PREFERRED_MIN: float = 120.0
const PREFERRED_MAX: float = 190.0

var _phase: Phase = Phase.DRIFT
var _cooldown: float = 0.0
var _t: float = 0.0
var _strafe: float = 1.0


func _on_activate() -> void:
	_phase = Phase.DRIFT
	_cooldown = def.attack_cooldown * 0.6
	_strafe = 1.0 if int(position.x) % 2 == 0 else -1.0


func _behave(delta: float, world: CombatWorld) -> Vector2:
	var to_h: Vector2 = world.hunter_position() - position
	var d: float = to_h.length()
	var dir: Vector2 = to_h / maxf(d, 0.001)
	if _phase == Phase.TELL:
		_t += delta
		if glow != null:
			glow.scale = Vector2.ONE * (1.0 + _t / def.tell_time)
		if _t >= def.tell_time:
			world.projectiles.fire_orb(position + Vector2(0, -def.hitbox_radius), dir, def.projectile_speed, def.projectile_damage)
			_phase = Phase.DRIFT
			_cooldown = def.attack_cooldown
			if glow != null:
				glow.scale = Vector2.ONE
		return Vector2.ZERO
	_cooldown -= delta
	if _cooldown <= 0.0 and d <= def.attack_range:
		_phase = Phase.TELL
		_t = 0.0
		return Vector2.ZERO
	var radial: float = 0.0
	if d > PREFERRED_MAX:
		radial = 1.0
	elif d < PREFERRED_MIN:
		radial = -1.0
	return (dir * radial + dir.orthogonal() * _strafe * 0.6).normalized() * def.move_speed
