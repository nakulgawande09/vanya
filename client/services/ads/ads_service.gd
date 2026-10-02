class_name AdsService
extends RefCounted
## Ads interface. Grant rewards only from rewarded_earned, never from a "closed" event.
## Real adapter: Poing Studios AdMob v5.x (pinned, vendored under addons/admob), see docs/dev-plan.md §5.

@warning_ignore_start("unused_signal")
## A fullscreen ad is on screen: mute game audio and haptics until ad_closed / ad_failed.
signal ad_opened(placement: StringName)
signal rewarded_earned(placement: StringName)
signal ad_closed(placement: StringName)
signal ad_failed(placement: StringName, reason: String)
@warning_ignore_restore("unused_signal")


func initialize() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


func show_rewarded(_placement: StringName) -> void:
	pass


func is_interstitial_ready() -> bool:
	return false


func show_interstitial(_placement: StringName) -> void:
	pass
