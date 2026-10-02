class_name GameSettings
extends RefCounted
## Player settings (accessibility, audio, haptics, language, difficulty, graphics), stored in the
## save under "settings". Plain data: Boot applies locale, quality, volumes and haptics at start;
## scenes read the rest.

enum Difficulty { STORY, NORMAL, HUNTER }
enum Graphics { AUTO, HIGH, MEDIUM, LOW }
## Matches HapticsService.Level (Audio Bible A2: amplitude ×0 / ×0.5 / ×1).
enum Haptics { OFF, LOW, FULL }

const LOCALES: PackedStringArray = ["en", "hi", "mr"]
const VOLUME_STEPS: int = 10
## Target room-clear probability per difficulty (dev-plan §7.5).
const TARGET_SUCCESS: Dictionary[int, float] = {Difficulty.STORY: 0.85, Difficulty.NORMAL: 0.75, Difficulty.HUNTER: 0.6}

var left_handed: bool = false
var screen_shake: bool = true
## 1.0 / 0.5 / 0.0 — scales hit flashes, god flashes and the hurt vignette.
var flash_intensity: float = 1.0
var damage_numbers: bool = true
var haptics: Haptics = Haptics.FULL
## Volume steps 0–10 per bus (Audio Bible A5).
var master_vol: int = 10
var music_vol: int = 10
var sfx_vol: int = 10
var ui_vol: int = 8
var amb_vol: int = 8
## Mute game music while another app plays music.
var let_my_music_play: bool = false
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
	if d.has("haptics_level"):
		s.haptics = clampi(VarUtil.to_int(d.get("haptics_level"), Haptics.FULL), 0, 2) as Haptics
	else:  # saves before audio: a plain on/off switch
		s.haptics = Haptics.OFF if d.get("haptics", true) == false else Haptics.FULL
	s.master_vol = _vol(d, "master_vol", 10)
	s.music_vol = _vol(d, "music_vol", 10)
	s.sfx_vol = _vol(d, "sfx_vol", 10)
	s.ui_vol = _vol(d, "ui_vol", 8)
	s.amb_vol = _vol(d, "amb_vol", 8)
	s.let_my_music_play = d.get("let_my_music_play", false) == true
	var loc: String = str(d.get("locale", "en"))
	s.locale = loc if LOCALES.has(loc) else "en"
	s.difficulty = clampi(VarUtil.to_int(d.get("difficulty"), Difficulty.NORMAL), 0, 2) as Difficulty
	s.adaptive_challenge = d.get("adaptive_challenge", true) != false
	s.graphics = clampi(VarUtil.to_int(d.get("graphics"), Graphics.AUTO), 0, 3) as Graphics
	return s


func to_dict() -> Dictionary:
	return {"left_handed": left_handed, "screen_shake": screen_shake, "flash_intensity": flash_intensity,
			"damage_numbers": damage_numbers, "haptics_level": haptics, "locale": locale, "difficulty": difficulty,
			"adaptive_challenge": adaptive_challenge, "graphics": graphics, "master_vol": master_vol,
			"music_vol": music_vol, "sfx_vol": sfx_vol, "ui_vol": ui_vol, "amb_vol": amb_vol,
			"let_my_music_play": let_my_music_play}


func target_success() -> float:
	return TARGET_SUCCESS[difficulty]


## A volume step as a linear 0–1 level.
static func level(steps: int) -> float:
	return clampf(float(steps) / VOLUME_STEPS, 0.0, 1.0)


static func _vol(d: Dictionary, key: String, fallback: int) -> int:
	return clampi(VarUtil.to_int(d.get(key), fallback), 0, VOLUME_STEPS)
