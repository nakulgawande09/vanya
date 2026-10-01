extends Node2D
## Placeholder grove room: dark floor, torches, a few idle rotlings and the player.
## The PCG room, wave director and swarm manager replace the hard-coded setup.

const CAMP_SCENE: String = "res://ui/screens/main.tscn"
const ROOM_SIZE: Vector2 = Vector2(720, 1280)
const TORCH_POSITIONS: Array[Vector2] = [Vector2(120, 260), Vector2(600, 260), Vector2(120, 1020), Vector2(600, 1020)]
const IDLE_ROTLINGS: int = 6

@export var run_seed: int = 1

@onready var _world: Node2D = %World
@onready var _lights: CanvasLayer = %Lights
@onready var _back_button: Button = %BackButton

var _fake_light: PackedScene = preload("res://gameplay/lighting/fake_light.tscn")


func _ready() -> void:
	AdaptiveQuality.set_combat(true)
	_back_button.pressed.connect(_on_back_pressed)
	_place_torches()
	_place_rotlings()
	EventBus.run_started.emit(run_seed)


func _exit_tree() -> void:
	AdaptiveQuality.set_combat(false)


func _place_torches() -> void:
	var torch: PackedScene = ThemeRegistry.visual_for(Ids.TORCH) as PackedScene
	for pos: Vector2 in TORCH_POSITIONS:
		if torch != null:
			var visual: Node2D = torch.instantiate() as Node2D
			visual.position = pos
			visual.scale = Vector2(2, 2)
			_world.add_child(visual)
		var glow: Sprite2D = _fake_light.instantiate() as Sprite2D
		glow.position = pos + Vector2(0, -24)
		glow.scale = Vector2(1.4, 1.4)
		_lights.add_child(glow)


func _place_rotlings() -> void:
	var rotling: PackedScene = ThemeRegistry.visual_for(Ids.ROTLING) as PackedScene
	if rotling == null:
		return
	var rng: SeededRng = SeededRng.new(run_seed, 0, &"scatter")
	for i: int in IDLE_ROTLINGS:
		var visual: Node2D = rotling.instantiate() as Node2D
		visual.position = Vector2(rng.next_int(80, int(ROOM_SIZE.x) - 80), rng.next_int(120, 480))
		visual.scale = Vector2(2, 2)
		_world.add_child(visual)


func _on_back_pressed() -> void:
	SceneRouter.change_to(CAMP_SCENE)
