class_name GodDef
extends Resource
## A battle god called with spirit (Gods board).

enum Effect { STORM, STAMPEDE, VINES }

@export var id: StringName = &""
@export var effect: Effect = Effect.STORM
@export var spirit_cost: int = 3
@export var cooldown: float = 9.0
@export var damage: int = 0
## STORM: number of nearest beasts struck.
@export var targets: int = 0
## STAMPEDE / VINES: effect radius in px.
@export var radius: float = 0.0
@export var knockback: float = 0.0
@export var heal: int = 0
@export var root_time: float = 0.0
