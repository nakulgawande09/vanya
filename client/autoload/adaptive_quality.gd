extends Node
## Thermal/frame-time governor. Picks a starting rung from the device tier and steps the
## quality ladder (docs/standards.md §B.3). Step-downs wait for a safe moment (between waves or on
## room change), except the jump to THERMAL, which applies immediately.

const PROFILE_PATHS: Dictionary[int, String] = {
	QualityProfile.Rung.HIGH: "res://data/quality/quality_high.tres",
	QualityProfile.Rung.MEDIUM: "res://data/quality/quality_medium.tres",
	QualityProfile.Rung.LOW: "res://data/quality/quality_low.tres",
	QualityProfile.Rung.THERMAL: "res://data/quality/quality_thermal.tres",
}
const GIB: int = 1024 * 1024 * 1024
## GPUs from the Tier C floor (docs/standards.md §B.1). Matching any of these caps the tier at LOW.
const LOW_TIER_GPU_HINTS: PackedStringArray = ["PowerVR", "Mali-G52", "Mali-G57", "Adreno (TM) 610"]
const THERMAL_HEADROOM_EMERGENCY: float = 0.95
const THERMAL_HEADROOM_STEP_DOWN: float = 0.85

var profile: QualityProfile
var device_ceiling: QualityProfile.Rung = QualityProfile.Rung.MEDIUM
var _pending_rung: int = -1
var _in_combat: bool = false


func _ready() -> void:
	var ram: int = VarUtil.to_int(OS.get_memory_info().get("physical"), 0)
	var adapter: String = RenderingServer.get_video_adapter_name()
	device_ceiling = tier_for(ram, adapter)
	_apply(device_ceiling)


## Starting rung from RAM and GPU name. Unknown RAM (0 or -1) is treated as mid-range.
static func tier_for(ram_bytes: int, adapter_name: String) -> QualityProfile.Rung:
	var rung: QualityProfile.Rung = QualityProfile.Rung.MEDIUM
	if ram_bytes > 0:
		if ram_bytes <= 3 * GIB + GIB / 4:
			rung = QualityProfile.Rung.LOW
		elif ram_bytes >= 6 * GIB - GIB / 2:
			rung = QualityProfile.Rung.HIGH
	for hint: String in LOW_TIER_GPU_HINTS:
		if adapter_name.containsn(hint):
			rung = QualityProfile.Rung.LOW
	return rung


static func load_profile(rung: QualityProfile.Rung) -> QualityProfile:
	return load(PROFILE_PATHS[rung]) as QualityProfile


func current_rung() -> int:
	return profile.rung


func set_combat(active: bool) -> void:
	_in_combat = active
	Engine.max_fps = profile.combat_max_fps if active else profile.menu_max_fps


## Called by the thermal bridge (ADPF on Android, thermalState on iOS). Headroom 1.0 = severe throttling.
func on_thermal_changed(headroom: float, _status: int) -> void:
	if headroom >= THERMAL_HEADROOM_EMERGENCY:
		_pending_rung = -1
		_apply(QualityProfile.Rung.THERMAL)
	elif headroom >= THERMAL_HEADROOM_STEP_DOWN and profile.rung < QualityProfile.Rung.THERMAL:
		_pending_rung = profile.rung + 1


## Call at safe moments (between waves, on room transitions) to apply a queued step.
func commit_pending() -> void:
	if _pending_rung >= 0:
		var next: QualityProfile.Rung = _pending_rung as QualityProfile.Rung
		_pending_rung = -1
		_apply(next)


func _apply(rung: QualityProfile.Rung) -> void:
	var old_rung: int = profile.rung if profile != null else -1
	profile = load_profile(rung)
	Engine.physics_ticks_per_second = profile.physics_ticks
	Engine.max_fps = profile.combat_max_fps if _in_combat else profile.menu_max_fps
	if old_rung != rung:
		EventBus.quality_changed.emit(old_rung, rung)
