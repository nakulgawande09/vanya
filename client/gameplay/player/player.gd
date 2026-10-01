class_name Player
extends CharacterBody2D
## Placeholder hunter: moves toward the held touch point. The floating joystick and
## auto-aim bow replace this when the prototype is ported.

@export var move_speed: float = 260.0
@export var visual_scale: float = 2.0

var _target: Vector2 = Vector2.ZERO
var _moving: bool = false


func _ready() -> void:
	var scene: PackedScene = ThemeRegistry.visual_for(Ids.HUNTER) as PackedScene
	if scene != null:
		var visual: Node2D = scene.instantiate() as Node2D
		visual.scale = Vector2.ONE * visual_scale
		add_child(visual)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_moving = touch.pressed
		_target = get_canvas_transform().affine_inverse() * touch.position
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_target = get_canvas_transform().affine_inverse() * drag.position


func _physics_process(_delta: float) -> void:
	var to_target: Vector2 = _target - global_position
	if _moving and to_target.length() > 6.0:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
