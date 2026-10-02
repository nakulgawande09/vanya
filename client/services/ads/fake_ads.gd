class_name FakeAds
extends AdsService
## Instantly "shows" ads and grants rewards. Used in the editor, tests and offline builds.

var shown: Array[StringName] = []


func is_rewarded_ready() -> bool:
	return true


func show_rewarded(placement: StringName) -> void:
	shown.append(placement)
	ad_opened.emit(placement)
	rewarded_earned.emit(placement)
	ad_closed.emit(placement)


func is_interstitial_ready() -> bool:
	return true


func show_interstitial(placement: StringName) -> void:
	shown.append(placement)
	ad_opened.emit(placement)
	ad_closed.emit(placement)
