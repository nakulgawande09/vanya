class_name ThermalService
extends RefCounted
## Thermal bridge interface. Android: PowerManager.getThermalHeadroom() polled every 10 s plus the
## status listener (Kotlin plugin, week 3). iOS: ProcessInfo.thermalState notifications.
## headroom: 0.0 = cool, 1.0 = severe throttling threshold. status: platform thermal status code.

@warning_ignore("unused_signal")
signal thermal_changed(headroom: float, status: int)


func start() -> void:
	pass


func get_headroom() -> float:
	return 0.0
