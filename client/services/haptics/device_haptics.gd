class_name DeviceHaptics
extends HapticsService
## Godot's one-shot vibration (Android needs the VIBRATE permission; iOS 13+ honours duration).
## Rich primitives (click / thud / quick rise) need a plugin and are a later step (ADR-0007).


func _vibrate(duration_ms: int, amplitude: float) -> void:
	if amplitude > 0.0:
		Input.vibrate_handheld(duration_ms, amplitude)
