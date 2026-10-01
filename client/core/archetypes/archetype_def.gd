class_name ArchetypeDef
extends Resource
## Gameplay-owned definition of an archetype. Stats only; visuals come from the theme.
## Read-only at runtime: duplicate() before mutating.

enum Role { SWARM, TANK, RANGED, BOSS, PLAYER }

@export var id: StringName = &""
@export var role: Role = Role.SWARM
@export var max_hp: int = 10
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var hitbox_radius: float = 12.0
@export var meat_drop: int = 0
@export var spirit_drop: int = 0
@export var budget_cost: int = 1
