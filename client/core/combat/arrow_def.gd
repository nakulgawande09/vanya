class_name ArrowDef
extends Resource
## An arrow tier, bought with meat at camp (Hunter board: Stone, Flint, Bone · pierces, Rapid bow · twin shot).

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var texture_id: StringName = &""
@export var damage: int = 10
## Seconds between shots.
@export var fire_interval: float = 0.6
@export var speed: float = 520.0
@export var aim_range: float = 240.0
## Extra beasts an arrow passes through.
@export var pierce: int = 0
@export var twin_shot: bool = false
@export var meat_cost: int = 0
