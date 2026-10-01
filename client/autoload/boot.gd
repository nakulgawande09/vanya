extends Node
## Startup order: mount theme packs (in _init, as early as possible) → consent → SDK init.
## Runs first in the autoload list. Other autoloads finish their own setup in _ready,
## so anything that depends on them is deferred to _start().


func _init() -> void:
	# TODO(week 13): mount downloaded, signature-verified theme packs from user://packs/
	# with ProjectSettings.load_resource_pack(path, false) so a pack never shadows core files.
	pass


func _ready() -> void:
	_start.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			Services.save.flush()


func _start() -> void:
	# TODO(week 11): UMP consent → (iOS) ATT → MobileAds.initialize(), only once consent allows ads.
	Services.ads.initialize()
	Services.iap.initialize()
	Services.thermal.thermal_changed.connect(AdaptiveQuality.on_thermal_changed)
	Services.thermal.start()
	Services.analytics.log_event(&"app_started", {"quality_rung": AdaptiveQuality.current_rung()})
	EventBus.boot_completed.emit()
