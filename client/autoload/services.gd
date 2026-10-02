extends Node
## Service locator. Gameplay and UI talk to these interfaces only, never to SDK plugins.
## Fake adapters are installed by default so every scene runs in the editor, in tests and offline.
## Real adapters (AdMob, godot-iap, Firebase, ADPF) are swapped in by Boot once their plugins are vendored.

var ads: AdsService = FakeAds.new()
var iap: IapService = FakeStore.new()
var analytics: AnalyticsService = FakeAnalytics.new()
var thermal: ThermalService = FakeThermal.new()
var save: SaveService = SaveService.new()
## Audio and haptics (ADR-0007): recording fakes by default; Boot installs GodotAudio / DeviceHaptics.
var audio: AudioService = RecordingAudio.new()
var haptics: HapticsService = FakeHaptics.new()


func _ready() -> void:
	audio.name = "Audio"
	add_child(audio)


## Installs another audio adapter and returns the previous one, detached but not freed
## (tests swap a RecordingAudio in and restore the original afterwards).
func swap_audio(impl: AudioService) -> AudioService:
	var old: AudioService = audio
	if old != null and old.get_parent() == self:
		remove_child(old)
	audio = impl
	impl.name = "Audio"
	add_child(impl)
	return old


func install(
	ads_impl: AdsService = null,
	iap_impl: IapService = null,
	analytics_impl: AnalyticsService = null,
	thermal_impl: ThermalService = null,
) -> void:
	if ads_impl != null:
		ads = ads_impl
	if iap_impl != null:
		iap = iap_impl
	if analytics_impl != null:
		analytics = analytics_impl
	if thermal_impl != null:
		thermal = thermal_impl
