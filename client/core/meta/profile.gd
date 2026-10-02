class_name Profile
extends RefCounted
## The player's banked progress: currencies, owned and equipped arrows, shrine levels.
## Serialized into the save under "profile". Arrow and shrine rules come from data resources.

var meat: int = 0
var spirit: int = 0
var owned_arrows: Array[StringName] = [&"stone"]
var equipped_arrow: StringName = &"stone"
var shrine_levels: Dictionary[StringName, int] = {}
var best_grove: int = 0
var runs: int = 0
var tutorial_done: bool = false
## Adaptive-difficulty state (SkillRating.to_dict()).
var skill: Dictionary = {}


static func from_dict(d: Dictionary) -> Profile:
	var p: Profile = Profile.new()
	p.meat = VarUtil.to_int(d.get("meat"), 0)
	p.spirit = VarUtil.to_int(d.get("spirit"), 0)
	p.best_grove = VarUtil.to_int(d.get("best_grove"), 0)
	p.runs = VarUtil.to_int(d.get("runs"), 0)
	p.tutorial_done = d.get("tutorial_done", false) == true
	var sk: Variant = d.get("skill", {})
	p.skill = sk if sk is Dictionary else {}
	var arrows: Variant = d.get("owned_arrows", [])
	if arrows is Array:
		for a: Variant in arrows:
			var id: StringName = StringName(str(a))
			if not p.owned_arrows.has(id):
				p.owned_arrows.append(id)
	var eq: StringName = StringName(str(d.get("equipped_arrow", "stone")))
	p.equipped_arrow = eq if p.owned_arrows.has(eq) else &"stone"
	var levels: Variant = d.get("shrine_levels", {})
	if levels is Dictionary:
		for k: Variant in (levels as Dictionary).keys():
			p.shrine_levels[StringName(str(k))] = VarUtil.to_int((levels as Dictionary)[k], 0)
	return p


func to_dict() -> Dictionary:
	var levels: Dictionary = {}
	for k: StringName in shrine_levels:
		levels[String(k)] = shrine_levels[k]
	var arrows: Array = []
	for a: StringName in owned_arrows:
		arrows.append(String(a))
	return {"meat": meat, "spirit": spirit, "owned_arrows": arrows, "equipped_arrow": String(equipped_arrow),
			"shrine_levels": levels, "best_grove": best_grove, "runs": runs, "tutorial_done": tutorial_done,
			"skill": skill}


func can_buy_arrow(arrow: ArrowDef) -> bool:
	return not owned_arrows.has(arrow.id) and meat >= arrow.meat_cost


## Buys and equips an arrow tier. Returns false if owned already or meat is short.
func buy_arrow(arrow: ArrowDef) -> bool:
	if not can_buy_arrow(arrow):
		return false
	meat -= arrow.meat_cost
	owned_arrows.append(arrow.id)
	equipped_arrow = arrow.id
	return true


func equip_arrow(id: StringName) -> bool:
	if not owned_arrows.has(id):
		return false
	equipped_arrow = id
	return true


func shrine_level(id: StringName) -> int:
	return shrine_levels.get(id, 0)


func can_level(shrine: ShrineDef) -> bool:
	var cost: int = shrine.cost_for(shrine_level(shrine.id))
	return cost >= 0 and spirit >= cost


## Spends spirit to light the next band on a totem.
func level_up(shrine: ShrineDef) -> bool:
	if not can_level(shrine):
		return false
	spirit -= shrine.cost_for(shrine_level(shrine.id))
	shrine_levels[shrine.id] = shrine_level(shrine.id) + 1
	return true


## Total bonus from a shrine stat at the current levels.
func bonus(shrine: ShrineDef) -> float:
	return shrine.per_level * shrine_level(shrine.id)


## Banks what a run carried home.
func bank_run(run: RunState) -> void:
	meat += run.meat
	spirit += run.spirit
	best_grove = maxi(best_grove, run.grove)
	runs += 1
