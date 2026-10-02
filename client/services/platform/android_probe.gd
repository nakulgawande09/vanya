class_name AndroidProbe
extends RefCounted
## Small Android system queries through JavaClassWrapper / the AndroidRuntime singleton (no plugin):
## is another app playing music (Audio Bible A5 "let my music play"), battery level and thermal
## headroom (feel-test overlay, B3). Every call returns a neutral value off Android or on failure.


static func music_active() -> bool:
	var audio: Object = _service("audio")
	return audio != null and audio.call(&"isMusicActive") == true


## 0–100, or -1 when unknown.
static func battery_percent() -> int:
	var bm: Object = _service("batterymanager")
	if bm == null:
		return -1
	return VarUtil.to_int(bm.call(&"getIntProperty", 4), -1)  # BATTERY_PROPERTY_CAPACITY


## PowerManager.getThermalHeadroom(forecast): 1.0 ≈ severe throttling; -1 when unavailable (< Android 11).
static func thermal_headroom(forecast_seconds: int = 10) -> float:
	var pm: Object = _service("power")
	if pm == null:
		return -1.0
	var v: Variant = pm.call(&"getThermalHeadroom", forecast_seconds)
	return VarUtil.to_float(v, -1.0)


static func _service(service_name: String) -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return null
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var context: Variant = runtime.call(&"getApplicationContext")
	if not context is Object or context == null:
		return null
	var svc: Variant = (context as Object).call(&"getSystemService", service_name)
	return svc as Object if svc is Object else null
