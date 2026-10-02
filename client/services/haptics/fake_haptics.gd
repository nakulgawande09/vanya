class_name FakeHaptics
extends HapticsService
## Records pulses instead of vibrating (editor, tests, desktop).

var pulses: Array[Vector2] = []  # x = duration ms, y = amplitude


func _vibrate(duration_ms: int, amplitude: float) -> void:
	pulses.append(Vector2(duration_ms, amplitude))
