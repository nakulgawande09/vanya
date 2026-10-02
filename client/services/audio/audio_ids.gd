class_name AudioIds
extends RefCounted
## Sound IDs built from archetype IDs (`sfx.enemy.rotling.death`, `sfx.boss.rotheart.hurt`), cached
## so hot paths never build strings. Gameplay asks for a sound by archetype + action; the theme's
## AudioManifest decides what it sounds like.

## Arrow impact material per archetype (sfx.player.arrow.impact.<material>).
const IMPACT: Dictionary[StringName, StringName] = {
	&"rotling": &"sfx.player.arrow.impact.flesh",
	&"thornback": &"sfx.player.arrow.impact.armor",
	&"wisp": &"sfx.player.arrow.impact.stone",
	&"rotheart": &"sfx.player.arrow.impact.flesh",
}
const IMPACT_DEFAULT: StringName = &"sfx.player.arrow.impact.bark"
## Bow release per arrow tier (stone, flint, bone, rapid).
const RELEASE: Array[StringName] = [&"sfx.player.bow.release.t1", &"sfx.player.bow.release.t2",
		&"sfx.player.bow.release.t3", &"sfx.player.bow.release.t4"]

static var _enemy: Dictionary[StringName, Dictionary] = {}


## `sfx.<enemy|boss>.<archetype>.<action>` for an archetype.
static func enemy(def: ArchetypeDef, action: StringName) -> StringName:
	var table: Dictionary = _enemy.get(def.id, {})
	if table.is_empty():
		_enemy[def.id] = table
	var hit: Variant = table.get(action)
	if hit != null:
		return hit
	var domain: String = "boss" if def.role == ArchetypeDef.Role.BOSS else "enemy"
	var id: StringName = StringName("sfx.%s.%s.%s" % [domain, def.id, action])
	table[action] = id
	return id


static func impact(archetype: StringName) -> StringName:
	return IMPACT.get(archetype, IMPACT_DEFAULT)


static func release(tier: int) -> StringName:
	return RELEASE[clampi(tier, 0, RELEASE.size() - 1)]
