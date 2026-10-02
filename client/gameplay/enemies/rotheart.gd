class_name RotheartBoss
extends SceneEnemy
## Boss of every fifth grove, a corrupted great boar (Rotheart board). Fight loop, in order:
## 1 Stalk → 2 Telegraph (three eyes flare, 0.75 s) → 3 Charge (0.65 s dash) → 4 Stunned after
## hitting a wall (2.5 s; arrows on the heart deal ×2) → back to Stalk; every third cycle it
## 5 Summons instead: roots sink, two portals open, two Rotlings crawl out.

signal phase_changed(phase: int)

enum Phase { STALK, TELEGRAPH, CHARGE, STUNNED, SUMMON }

const CHARGE_TIME: float = 0.65
const STUN_TIME: float = 2.5
const SUMMON_TIME: float = 1.2

var phase: Phase = Phase.STALK
var _t: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _cycles: int = 0


func _on_activate() -> void:
	_set_phase(Phase.STALK)
	_cycles = 0


func is_stunned() -> bool:
	return phase == Phase.STUNNED


func take_damage(amount: int, direction: Vector2) -> bool:
	return super.take_damage(amount * Damage.WEAK_POINT_MULT if is_stunned() else amount, direction)


func _behave(delta: float, world: CombatWorld) -> Vector2:
	_t += delta
	var to_h: Vector2 = world.hunter_position() - position
	match phase:
		Phase.STALK:
			if _t >= def.attack_cooldown:
				_cycles += 1
				_set_phase(Phase.SUMMON if _cycles % 3 == 0 else Phase.TELEGRAPH)
			return world.field.direction(position, world.hunter_position()) * def.move_speed
		Phase.TELEGRAPH:
			if glow != null:
				glow.scale = Vector2.ONE * (1.0 + 0.6 * absf(sin(_t * 18.0)))
			if _t >= def.tell_time:
				_charge_dir = to_h.normalized()
				if glow != null:
					glow.scale = Vector2.ONE
				_set_phase(Phase.CHARGE)
			return Vector2.ZERO
		Phase.CHARGE:
			var r: float = def.hitbox_radius
			var next: Vector2 = position + _charge_dir * def.projectile_speed * delta
			var hit_wall: bool = next.x < bounds.position.x + r or next.x > bounds.end.x - r \
					or next.y < bounds.position.y + r or next.y > bounds.end.y - r \
					or world.field.is_blocked(next + _charge_dir * r * 0.6)
			if hit_wall:
				_set_phase(Phase.STUNNED)  # CombatWorld adds the wall-hit sound, shake and hit-stop
				return Vector2.ZERO
			if _t >= CHARGE_TIME:
				_set_phase(Phase.STALK)
			return _charge_dir * def.projectile_speed
		Phase.STUNNED:
			if _body != null:
				_body.rotation = deg_to_rad(4.0)
			if _t >= STUN_TIME:
				if _body != null:
					_body.rotation = 0.0
				_set_phase(Phase.STALK)
			return Vector2.ZERO
		Phase.SUMMON:
			if _t >= SUMMON_TIME:
				world.summon(Ids.ROTLING, position + Vector2(-90, 40))
				world.summon(Ids.ROTLING, position + Vector2(90, 40))
				_set_phase(Phase.STALK)
			return Vector2.ZERO
	return Vector2.ZERO


func _contact_damage() -> int:
	return def.projectile_damage if phase == Phase.CHARGE else def.contact_damage


func _knock_strength() -> float:
	return 0.0


func _set_phase(p: Phase) -> void:
	phase = p
	_t = 0.0
	phase_changed.emit(p)
