class_name GameSettings
extends RefCounted
## Player settings (accessibility, language, difficulty, graphics), stored in the save under
## "settings". Plain data: Boot applies locale and quality at start; scenes read the rest.

enum Difficulty { STORY, NORMAL, HUNTER }
enum Graphics { AUTO, HIGH, MEDIUM, LOW }

const LOCALES: PackedStringArray = ["en", "hi", "mr"]
## Target room-clear probability per difficulty (dev-plan §7.5).
const TARGET_SUCCESS: Dictionary[int, float] = {Difficulty.STORY: 0.85, Difficulty.NORMAL: 0.75, Difficulty.HUNTER: 0.6}

var left_handed: bool = false
var screen_shake: bool = true
## 1.0 / 0.5 / 0.0 — scales hit flashes, god flashes and the hurt vignette.
var flash_intensity: float = 1.0
var damage_numbers: bool = true
var haptics: bool = true
var locale: String = "en"
var difficulty: Difficulty = Difficulty.NORMAL
var adaptive_challenge: bool = true
var graphics: Graphics = Graphics.AUTO


static func from_dict(d: Dictionary) -> GameSettings:
	var s: GameSettings = GameSettings.new()
	s.left_handed = d.get("left_handed", false) == true
	s.screen_shake = d.get("screen_shake", true) != false
	s.flash_intensity = clampf(VarUtil.to_float(d.get("flash_intensity"), 1.0), 0.0, 1.0)
	s.damage_numbers = d.get("damage_numbers", true) != false
	s.haptics = d.get("haptics", true) != false
	var loc: String = str(d.get("locale", "en"))
	s.locale = loc if LOCALES.has(loc) else "en"
	s.difficulty = clampi(VarUtil.to_int(d.get("difficulty"), Difficulty.NORMAL), 0, 2) as Difficulty
	s.adaptive_challenge = d.get("adaptive_challenge", true) != false
	s.graphics = clampi(VarUtil.to_int(d.get("graphics"), Graphics.AUTO), 0, 3) as Graphics
	return s


func to_dict() -> Dictionary:
	return {"left_handed": left_handed, "screen_shake": screen_shake, "flash_intensity": flash_intensity,
			"damage_numbers": damage_numbers, "haptics": haptics, "locale": locale, "difficulty": difficulty,
			"adaptive_challenge": adaptive_challenge, "graphics": graphics}


func target_success() -> float:
	return TARGET_SUCCESS[difficulty]
