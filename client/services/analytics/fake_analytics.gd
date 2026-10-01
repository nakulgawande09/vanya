class_name FakeAnalytics
extends AnalyticsService
## Keeps events in memory and prints them in debug builds.

const MAX_EVENTS: int = 500

var events: Array[Dictionary] = []


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	if events.size() >= MAX_EVENTS:
		events.pop_front()
	events.append({"name": event_name, "params": params})
	if OS.is_debug_build():
		print_verbose("[analytics] %s %s" % [event_name, params])
