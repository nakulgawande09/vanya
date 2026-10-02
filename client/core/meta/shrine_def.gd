class_name ShrineDef
extends Resource
## An elder god at the camp shrine. Each level costs more spirit and lights one more band.

enum Stat { DAMAGE, HEALTH, SPEED, LIGHT }

@export var id: StringName = &""
@export var stat: Stat = Stat.DAMAGE
## Bonus per level: a fraction for DAMAGE / SPEED / LIGHT, flat HP for HEALTH.
@export var per_level: float = 0.1
@export var level_costs: PackedInt32Array = PackedInt32Array([4, 8, 14, 22, 32])


func max_level() -> int:
	return level_costs.size()


## Spirit needed to go from `level` to `level + 1`, or -1 at max level.
func cost_for(level: int) -> int:
	return level_costs[level] if level >= 0 and level < level_costs.size() else -1
