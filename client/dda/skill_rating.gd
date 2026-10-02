class_name SkillRating
extends RefCounted
## Elo-style player rating against room difficulty (dev-plan §7.3).
## E = 1 / (1 + 10^((D − R) / 400)); R ← R + K·(S − E), K = 40 for the first 10 rooms, then 24.
## Rooms are rated on one scale with the player, so a room's D is "the rating that clears it half
## the time".

const START: float = 1000.0
const K_EARLY: float = 40.0
const K_LATE: float = 24.0
const EARLY_ROOMS: int = 10
## A death after dealing less than this share of the room's damage doesn't lower the rating
## (anti-sandbag: dying on purpose must not farm easy rooms).
const SANDBAG_RATIO: float = 0.2

var rating: float = START
var rooms: int = 0


static func expected(r: float, d: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (d - r) / 400.0))


## Room performance in [0, 1]: 0.55·cleared + 0.25·hp_end + 0.10·(1 − near_death) + 0.10·time.
static func performance(cleared: bool, hp_end_frac: float, near_death_norm: float, time_score: float) -> float:
	var s: float = 0.55 * (1.0 if cleared else 0.0) + 0.25 * clampf(hp_end_frac, 0.0, 1.0) \
			+ 0.10 * (1.0 - clampf(near_death_norm, 0.0, 1.0)) + 0.10 * clampf(time_score, 0.0, 1.0)
	return clampf(s, 0.0, 1.0)


## The room difficulty this player clears with probability `p`.
func target_difficulty(p: float) -> float:
	var q: float = clampf(p, 0.05, 0.95)
	return rating - 400.0 * log(q / (1.0 - q)) / log(10.0)


## Updates the rating from one room; returns the change.
func update(room_difficulty: float, s: float, cleared: bool, damage_dealt_ratio: float = 1.0) -> float:
	var e: float = expected(rating, room_difficulty)
	var k: float = K_EARLY if rooms < EARLY_ROOMS else K_LATE
	var change: float = k * (s - e)
	if change < 0.0 and not cleared and damage_dealt_ratio < SANDBAG_RATIO:
		change = 0.0
	rating += change
	rooms += 1
	return change


static func from_dict(d: Dictionary) -> SkillRating:
	var r: SkillRating = SkillRating.new()
	r.rating = VarUtil.to_float(d.get("rating"), START)
	r.rooms = VarUtil.to_int(d.get("rooms"), 0)
	return r


func to_dict() -> Dictionary:
	return {"rating": snappedf(rating, 0.01), "rooms": rooms}
