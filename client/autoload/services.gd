extends Node
## Service locator. Gameplay and UI talk to these interfaces only, never to SDK plugins.
## Fake adapters are installed by default so every scene runs in the editor, in tests and offline.
## Real adapters (AdMob, godot-iap, Firebase, ADPF) are swapped in by Boot once their plugins are vendored.

var ads: AdsService = FakeAds.new()
var iap: IapService = FakeStore.new()
var analytics: AnalyticsService = FakeAnalytics.new()
var thermal: ThermalService = FakeThermal.new()
var save: SaveService = SaveService.new()


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
