class_name WaveDef
extends Resource
## Difficulty budget for a room, spent point-buy on archetypes (dev-plan §6.2). Provisional numbers.

@export var budget_base: int = 10
@export var budget_per_grove: int = 4
## Share of the room budget per wave: wave 1 builds, wave 2 peaks, the last wave is the highest peak.
@export var wave_shares: PackedFloat32Array = PackedFloat32Array([0.25, 0.35, 0.4])
## Seconds of relax time between waves.
@export var wave_spacing: float = 5.0
## Relative pick weights per archetype id.
@export var mix_weights: Dictionary[StringName, float] = {}
## Every n-th grove is a boss grove.
@export var boss_every: int = 5
@export var boss_id: StringName = &"rotheart"
## Budget for the escort waves in a boss grove, as a share of a normal room's.
@export var boss_escort_share: float = 0.35
