class_name AnalyticsService
extends RefCounted
## Analytics interface. Event names use object_action (room_cleared, ad_reward_granted).
## Events are batched and only sent at room end or in menus, never per frame (docs/standards.md §C8).
## Real sinks: Firebase (after consent) plus the Vanya backend telemetry queue.


func log_event(_event_name: StringName, _params: Dictionary = {}) -> void:
	pass


func set_user_property(_key: StringName, _value: String) -> void:
	pass


func flush() -> void:
	pass
