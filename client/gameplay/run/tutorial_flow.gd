class_name TutorialFlow
extends RefCounted
## First-run tutorial grove: tips with pointers that advance on what the player does, not on
## timers — move, watch the bow, free the caged bird, call Meghra, walk into the opened gate.

enum Step { MOVE, SHOOT, CAGE, GOD, GATE, DONE }

const MOVE_DISTANCE: float = 50.0
const FIRST_KILLS: int = 3
const GOD_SPIRIT: int = 3
const TIPS: Dictionary[int, StringName] = {
	Step.MOVE: &"TUT_MOVE", Step.SHOOT: &"TUT_SHOOT", Step.CAGE: &"TUT_CAGE", Step.GOD: &"TUT_GOD", Step.GATE: &"TUT_GATE",
}

var step: Step = Step.MOVE
var _run: GroveRun
var _start: Vector2


func _init(run_scene: GroveRun) -> void:
	_run = run_scene
	_start = run_scene.plan.start_position()


func begin() -> void:
	_show()


## Advances when the current step's goal is met. Called from the run's fixed tick.
func tick() -> void:
	match step:
		Step.MOVE:
			if _run.hunter_position().distance_to(_start) > MOVE_DISTANCE:
				_advance()
		Step.SHOOT:
			if _run.run.kills >= FIRST_KILLS:
				_advance()
		Step.CAGE:
			if _run.cage == null or _run.cage.is_free:
				_advance()
		Step.GOD:
			if _run.gods.cooldowns[Ids.MEGHRA] > 0.0:
				_advance()
		Step.GATE:
			if not _run.gate_open and _run.world.alive_count() == 0:
				_run.open_gate()
	_point()


func is_active() -> bool:
	return step != Step.DONE


func finish() -> void:
	step = Step.DONE
	_run.hud().hide_tip()


func _advance() -> void:
	step = (step + 1) as Step
	match step:
		Step.SHOOT:
			_run.director.hold = false
		Step.GOD:
			_run.run.add_spirit(maxi(0, GOD_SPIRIT - _run.run.spirit))
			for i: int in 2:
				_run.world.spawn(Ids.ROTLING, RoomPlan.cell_center(_run.plan.portals[0]))
	_show()


func _show() -> void:
	if TIPS.has(step):
		_run.hud().show_tip(TIPS[step])


func _point() -> void:
	var hud: Hud = _run.hud()
	match step:
		Step.MOVE:
			hud.point_at(hud.joystick_rest())
		Step.CAGE:
			if _run.cage != null:
				hud.point_at(_run.to_screen(_run.cage.position + Vector2(0, -70)))
		Step.GOD:
			hud.point_at(hud.god_button_position(Ids.MEGHRA) + Vector2(0, -44))
		Step.GATE:
			hud.point_at(_run.to_screen(_run.plan.gate_position() + Vector2(0, -80)) if _run.gate_open else Vector2(-100, -100))
		_:
			hud.point_at(Vector2(-100, -100))
