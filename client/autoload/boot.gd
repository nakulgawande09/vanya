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
	var saved: Variant = Services.save.load_game().get("settings", {})
	var settings: GameSettings = GameSettings.from_dict(_dict(saved))
	TranslationServer.set_locale(settings.locale)
	AdaptiveQuality.apply_setting(settings.graphics)
	_install_audio(settings)
	# TODO(week 11): UMP consent → (iOS) ATT → MobileAds.initialize(), only once consent allows ads.
	Services.ads.initialize()
	Services.iap.initialize()
	Services.thermal.thermal_changed.connect(AdaptiveQuality.on_thermal_changed)
	Services.thermal.start()
	Services.analytics.log_event(&"app_started", {"quality_rung": AdaptiveQuality.current_rung()})
	EventBus.boot_completed.emit()


## Real audio and haptics adapters (ADR-0007), configured from settings and the feel tuning.
func _install_audio(settings: GameSettings) -> void:
	var tuning: FeelTuning = FeelTuning.load_active()
	var haptics: HapticsService = DeviceHaptics.new()
	haptics.configure(tuning)
	Services.haptics = haptics
	Services.ads.ad_opened.connect(func(_p: StringName) -> void: Services.haptics.suppressed = true)
	Services.ads.ad_closed.connect(func(_p: StringName) -> void: Services.haptics.suppressed = false)
	Services.ads.ad_failed.connect(func(_p: StringName, _r: String) -> void: Services.haptics.suppressed = false)
	var audio: GodotAudio = GodotAudio.new()
	audio.tuning = tuning
	Services.swap_audio(audio).queue_free()
	apply_audio_settings(settings)


## Volumes, haptics level and "let my music play" (also called by the settings screen).
static func apply_audio_settings(settings: GameSettings) -> void:
	Services.audio.set_volumes(GameSettings.level(settings.master_vol), GameSettings.level(settings.music_vol),
			GameSettings.level(settings.sfx_vol), GameSettings.level(settings.ui_vol), GameSettings.level(settings.amb_vol))
	Services.audio.set_let_music_play(settings.let_my_music_play)
	var haptics_level: int = settings.haptics
	Services.haptics.level = haptics_level as HapticsService.Level


static func _dict(v: Variant) -> Dictionary:
	var d: Dictionary = v if v is Dictionary else {}
	return d
