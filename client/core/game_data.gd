class_name GameData
## Read-only catalogue of the gameplay data resources under res://data (typed .tres, no magic numbers).

const ARCHETYPES: Dictionary[StringName, String] = {
	&"hunter": "res://data/archetypes/hunter.tres",
	&"rotling": "res://data/archetypes/rotling.tres",
	&"thornback": "res://data/archetypes/thornback.tres",
	&"wisp": "res://data/archetypes/wisp.tres",
	&"rotheart": "res://data/archetypes/rotheart.tres",
}
const ARROWS: Array[StringName] = [&"stone", &"flint", &"bone", &"rapid"]
const GODS: Array[StringName] = [&"meghra", &"dhoru", &"vayli"]
const SHRINE: Array[StringName] = [&"suryak", &"tamba", &"kaja", &"anjor"]
const WAVES: String = "res://data/waves/grove.tres"


static func archetype(id: StringName) -> ArchetypeDef:
	return load(ARCHETYPES[id]) as ArchetypeDef


static func archetypes() -> Dictionary[StringName, ArchetypeDef]:
	var out: Dictionary[StringName, ArchetypeDef] = {}
	for id: StringName in ARCHETYPES:
		out[id] = archetype(id)
	return out


static func arrow(id: StringName) -> ArrowDef:
	return load("res://data/arrows/%s.tres" % id) as ArrowDef


static func god(id: StringName) -> GodDef:
	return load("res://data/gods/%s.tres" % id) as GodDef


static func shrine(id: StringName) -> ShrineDef:
	return load("res://data/shrine/%s.tres" % id) as ShrineDef


static func waves() -> WaveDef:
	return load(WAVES) as WaveDef


## Shrine bonus of one stat for a profile (e.g. DAMAGE → +0.2 at Suryak level 2).
static func shrine_bonus(profile: Profile, stat: ShrineDef.Stat) -> float:
	var total: float = 0.0
	for id: StringName in SHRINE:
		var def: ShrineDef = shrine(id)
		if def.stat == stat:
			total += profile.bonus(def)
	return total
