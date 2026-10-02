class_name Damage
## Damage rules shared by arrows, gods and guides.

## Heart weak point while Rotheart is stunned (Rotheart board: "Arrows that land while it is stunned deal double damage").
const WEAK_POINT_MULT: int = 2


static func arrow(arrow_def: ArrowDef, damage_bonus: float, weak_point: bool = false) -> int:
	var dmg: int = roundi(arrow_def.damage * (1.0 + damage_bonus))
	return dmg * WEAK_POINT_MULT if weak_point else dmg


static func scaled(base: int, damage_bonus: float) -> int:
	return roundi(base * (1.0 + damage_bonus))
