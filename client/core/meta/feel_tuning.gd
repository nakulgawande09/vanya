class_name FeelTuning
extends Resource
## Every feel knob in one place (feel-test plan B4/B6): hit-stop, shake, flash, haptics, joystick,
## auto-aim and music ducking. Code reads these instead of magic numbers; a tuning ticket changes
## one value here ("shake_god.x 8 → 6"). On a test phone, the debug overlay's Tune tab saves an
## override to user://feel_tuning.tres, which wins over the shipped data/feel/feel_tuning.tres.

enum JoystickMode { FIXED, DYNAMIC, FOLLOWING }

const DEFAULT_PATH: String = "res://data/feel/feel_tuning.tres"
const OVERRIDE_PATH: String = "user://feel_tuning.tres"

@export_group("Hit-stop (seconds)")
@export var hitstop_normal_hit: float = 0.0
## Reserved: there are no crits yet.
@export var hitstop_crit: float = 0.045
@export var hitstop_rotling_kill: float = 0.03
@export var hitstop_elite_kill: float = 0.07
@export var hitstop_hurt: float = 0.06
@export var hitstop_god: float = 0.08
@export var hitstop_boss: float = 0.09
## At most one stop per this many seconds, so a swarm dying at once doesn't stutter.
@export var hitstop_min_gap: float = 0.1
@export var hitstop_scale: float = 1.0

@export_group("Shake (x = px, y = seconds)")
@export var shake_crit: Vector2 = Vector2(2.0, 0.08)
@export var shake_rotling_kill: Vector2 = Vector2(1.5, 0.06)
@export var shake_elite_kill: Vector2 = Vector2(5.0, 0.2)
@export var shake_hurt: Vector2 = Vector2(4.0, 0.15)
@export var shake_god: Vector2 = Vector2(8.0, 0.3)
@export var shake_boss: Vector2 = Vector2(10.0, 0.35)
@export var shake_scale: float = 1.0

@export_group("Flash (frames)")
@export var flash_hit: int = 1
@export var flash_kill: int = 2
@export var flash_elite: int = 3
@export var flash_god: int = 2

@export_group("Haptics")
## key → (duration ms, amplitude 0–1, cooldown ms). Keys are the AudioEntry.haptic values.
@export var haptics: Dictionary[StringName, Vector3] = {
	&"crit": Vector3(20, 0.4, 80),
	&"hurt": Vector3(40, 0.7, 250),
	&"slam": Vector3(60, 0.9, 400),
	&"god": Vector3(80, 1.0, 1000),
	&"frenzy": Vector3(25, 0.5, 1000),
	&"cage": Vector3(30, 0.5, 0),
	&"gate": Vector3(50, 0.6, 0),
	&"purchase": Vector3(30, 0.5, 0),
}
## Global budget: at most this many pulses in any one second.
@export var haptic_budget_per_s: int = 4
@export var haptic_scale: float = 1.0

@export_group("Joystick")
@export var joystick_mode: JoystickMode = JoystickMode.DYNAMIC
## A/B Godot 4.7's built-in VirtualJoystick (same modes, dead zone and size) against our stick.
@export var joystick_builtin: bool = false
## Fraction of the radius ignored at rest (no drift).
@export_range(0.0, 0.5) var joystick_deadzone: float = 0.12
## Clamp radius in px: the knob never travels further.
@export var joystick_radius: float = 50.0
## Full speed is reached at this fraction of the radius.
@export_range(0.3, 1.0) var joystick_full_speed_at: float = 0.65
## Response curve exponent: 1 linear, > 1 finer control near the centre.
@export_range(0.5, 2.5) var joystick_curve: float = 1.0

@export_group("Auto-aim")
## Seconds before the bow may switch to a different target.
@export var aim_retarget_delay: float = 0.0
## Multiplies the equipped arrow's aim range.
@export var aim_range_scale: float = 1.0

@export_group("Music ducking")
@export var duck_db: float = -5.0
@export var duck_attack: float = 0.03
@export var duck_release: float = 0.4
@export var pause_duck_db: float = -8.0


## The override on the test phone, else the shipped tuning.
static func load_active() -> FeelTuning:
	if ResourceLoader.exists(OVERRIDE_PATH):
		var o: FeelTuning = ResourceLoader.load(OVERRIDE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FeelTuning
		if o != null:
			return o
	var d: FeelTuning = load(DEFAULT_PATH) as FeelTuning
	return d if d != null else FeelTuning.new()


## Joystick offset (fraction of the radius, any length) → move vector, after dead zone and curve.
func shape_stick(offset: Vector2) -> Vector2:
	var mag: float = minf(offset.length(), 1.0)
	if mag <= joystick_deadzone:
		return Vector2.ZERO
	var t: float = clampf((mag - joystick_deadzone) / maxf(0.01, joystick_full_speed_at - joystick_deadzone), 0.0, 1.0)
	return offset.normalized() * pow(t, joystick_curve)
