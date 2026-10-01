class_name QualityProfile
extends Resource
## One rung of the quality ladder (docs/standards.md §B.3). Values are read-only at runtime.

enum Rung { HIGH, MEDIUM, LOW, THERMAL }

@export var rung: Rung = Rung.MEDIUM
@export var combat_max_fps: int = 60
@export var menu_max_fps: int = 30
@export var physics_ticks: int = 60
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
@export var real_lights: int = 1
@export var shadows_enabled: bool = false
@export var fake_lights: int = 24
@export var gpu_particles: bool = false
@export_range(0.0, 1.0, 0.05) var particle_ratio: float = 0.7
@export var swarm_anim_fps: int = 20
@export var max_enemies: int = 40
@export var audio_voices: int = 24
@export var screen_shake: bool = true
@export var rim_and_dissolve_shaders: bool = true
