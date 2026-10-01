class_name FakeThermal
extends ThermalService
## Always cool. Tests can call simulate() to drive the quality ladder.

var _headroom: float = 0.0


func get_headroom() -> float:
	return _headroom


func simulate(headroom: float, status: int = 0) -> void:
	_headroom = headroom
	thermal_changed.emit(headroom, status)
