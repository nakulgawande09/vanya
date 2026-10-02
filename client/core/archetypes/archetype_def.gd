class_name ArchetypeDef
extends Resource
## Gameplay-owned definition of an archetype. Stats and hitbox only; visuals come from the theme
## and never change them (Theme map board: "a theme redraws the creature inside it, never resizes it").
## Read-only at runtime: duplicate() before mutating.

enum Role { SWARM, TANK, RANGED, BOSS, PLAYER }

@export var id: StringName = &""
@export var role: Role = Role.SWARM
@export var max_hp: int = 10
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var hitbox_radius: float = 12.0
@export var meat_drop: int = 0
## Chance (0-1) to drop one spirit on death.
@export_range(0.0, 1.0, 0.01) var spirit_chance: float = 0.0
@export var budget_cost: int = 1
## Ranged and boss tuning (unused by melee archetypes).
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 0.0
@export var tell_time: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_damage: int = 0
## Grove index from which this archetype may appear in waves.
@export var first_grove: int = 1
