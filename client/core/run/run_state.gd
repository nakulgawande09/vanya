class_name RunState
extends RefCounted
## One run from camp to defeat (or quitting): health, the grove counter, what was earned.
## Meat and spirit carried in a run are banked to the profile when it ends; spirit can also be
## spent mid-run to call gods. Plain data + rules, owned by the grove run scene (never an autoload).

signal health_changed(hp: int, max_hp: int)
signal currency_changed(meat: int, spirit: int)
signal died

const FRENZY_WINDOW: float = 2.0

var max_hp: int
var hp: int
var grove: int = 1
var meat: int = 0
var spirit: int = 0
var kills: int = 0
var animals_freed: int = 0
var revive_used: bool = false
var guides: Array[StringName] = []
var frenzy: int = 0
var _frenzy_t: float = 0.0


func _init(start_hp: int, start_spirit: int = 0) -> void:
	max_hp = start_hp
	hp = start_hp
	spirit = start_spirit


func is_dead() -> bool:
	return hp <= 0


## Returns the damage actually taken.
func take_damage(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var taken: int = mini(amount, hp)
	hp -= taken
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return taken


## Returns the HP actually restored.
func heal(amount: int) -> int:
	if is_dead():
		return 0
	var healed: int = mini(amount, max_hp - hp)
	hp += healed
	if healed > 0:
		health_changed.emit(hp, max_hp)
	return healed


func add_meat(amount: int) -> void:
	meat += amount
	currency_changed.emit(meat, spirit)


func add_spirit(amount: int) -> void:
	spirit += amount
	currency_changed.emit(meat, spirit)


func spend_spirit(amount: int) -> bool:
	if amount > spirit:
		return false
	spirit -= amount
	currency_changed.emit(meat, spirit)
	return true


## A kill within FRENZY_WINDOW of the previous one extends the frenzy counter (HUD "×6 frenzy").
func register_kill() -> void:
	kills += 1
	frenzy = frenzy + 1 if _frenzy_t > 0.0 else 1
	_frenzy_t = FRENZY_WINDOW


func tick(delta: float) -> void:
	if _frenzy_t > 0.0:
		_frenzy_t -= delta
		if _frenzy_t <= 0.0:
			frenzy = 0


## Revive once per grove (rewarded ad or a guide's gift). Returns false if already used.
func revive(fraction: float = 0.5) -> bool:
	if revive_used or not is_dead():
		return false
	revive_used = true
	hp = maxi(1, int(max_hp * fraction))
	health_changed.emit(hp, max_hp)
	return true


func next_grove() -> void:
	grove += 1
	revive_used = false


func has_guide(id: StringName) -> bool:
	return guides.has(id)


func add_guide(id: StringName) -> void:
	if not guides.has(id):
		guides.append(id)
