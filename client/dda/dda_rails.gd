class_name DdaRails
extends RefCounted
## Turns a target difficulty into the room's budget scale, inside the dev plan's safety rails
## (§7.5): at most ±8% per room and ±20% per five-grove arc, 0.75–1.25 overall; after 2 deaths in
## one grove the next attempt is one band easier, after 3 the next room is a relief room.
## Adaptive challenge off = a fixed 1.0. Supply-side help (spirit drop chance 2–12%) moves first.

const MIN_SCALE: float = 0.75
const MAX_SCALE: float = 1.25
const ROOM_STEP: float = 0.08
const ARC_STEP: float = 0.2
const ARC_LENGTH: int = 5
## Room difficulty on the rating scale: grove 1 at scale 1.0 is what a 1000-rated player clears
## 75% of the time; each grove adds 120; each +10% budget adds 60.
const D_GROVE_ONE: float = 810.0
const D_PER_GROVE: float = 120.0
const D_PER_SCALE: float = 600.0
const SUPPLY_MIN: float = 0.02
const SUPPLY_MAX: float = 0.12

var adaptive: bool = true
var last_scale: float = 1.0
var arc_start_scale: float = 1.0
var deaths_in_grove: int = 0
var relief_next: bool = false
var _arc: int = -1


static func room_difficulty(grove: int, scale: float) -> float:
	return D_GROVE_ONE + D_PER_GROVE * (grove - 1) + D_PER_SCALE * (scale - 1.0)


## Budget scale for the next room of `grove`, given the difficulty the player should face.
func next_scale(grove: int, target_difficulty: float) -> float:
	if not adaptive:
		last_scale = 1.0
		return 1.0
	var arc: int = (grove - 1) / ARC_LENGTH
	if arc != _arc:
		_arc = arc
		arc_start_scale = last_scale
	var desired: float = 1.0 + (target_difficulty - room_difficulty(grove, 1.0)) / D_PER_SCALE
	if relief_next:
		relief_next = false
		last_scale = MIN_SCALE
		return last_scale
	if deaths_in_grove >= 2:
		desired = minf(desired, last_scale - ROOM_STEP)
	var scale: float = clampf(desired, last_scale - ROOM_STEP, last_scale + ROOM_STEP)
	scale = clampf(scale, arc_start_scale - ARC_STEP, arc_start_scale + ARC_STEP)
	scale = clampf(scale, MIN_SCALE, MAX_SCALE)
	last_scale = scale
	return scale


func on_death() -> void:
	deaths_in_grove += 1
	if deaths_in_grove >= 3:
		relief_next = true


func on_grove_cleared() -> void:
	deaths_in_grove = 0


## Chance a fallen beast leaves a spirit wisp on top of its own: more help when the room is easier.
func supply_chance() -> float:
	if not adaptive:
		return SUPPLY_MIN
	var k: float = (last_scale - MIN_SCALE) / (MAX_SCALE - MIN_SCALE)
	return lerpf(SUPPLY_MAX, SUPPLY_MIN, clampf(k, 0.0, 1.0))
