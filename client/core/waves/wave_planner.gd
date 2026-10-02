class_name WavePlanner
extends RefCounted
## Turns a room's difficulty budget into waves by point-buy (dev-plan §6.2, §7.3). Deterministic
## for a given seed stream. The DDA will later scale `budget_scale` within its safety rails.


## Returns waves as arrays of archetype ids. A boss grove's first wave is just the boss.
static func plan(def: WaveDef, grove: int, defs: Dictionary[StringName, ArchetypeDef], rng: SeededRng,
		budget_scale: float = 1.0) -> Array[Array]:
	var waves: Array[Array] = []
	var budget: int = room_budget(def, grove, budget_scale)
	var boss: bool = is_boss_grove(def, grove)
	if boss:
		waves.append([def.boss_id])
		budget = int(budget * def.boss_escort_share)
	var pool: Array[StringName] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	for id: StringName in def.mix_weights:
		var arche: ArchetypeDef = defs.get(id)
		if arche != null and arche.first_grove <= grove and arche.role != ArchetypeDef.Role.BOSS:
			pool.append(id)
			weights.append(def.mix_weights[id])
	if pool.is_empty():
		return waves
	var shares: PackedFloat32Array = def.wave_shares
	for w: int in shares.size():
		var wave_budget: int = maxi(1, roundi(budget * shares[w]))
		var wave: Array[StringName] = []
		var guard: int = 0
		while wave_budget > 0 and guard < 200:
			guard += 1
			var pick: StringName = pool[_weighted(weights, rng)]
			var cost: int = defs[pick].budget_cost
			if cost > wave_budget:
				pick = _cheapest(pool, defs)
				cost = defs[pick].budget_cost
				if cost > wave_budget:
					break
			wave.append(pick)
			wave_budget -= cost
		waves.append(wave)
	return waves


static func room_budget(def: WaveDef, grove: int, budget_scale: float = 1.0) -> int:
	return maxi(1, roundi((def.budget_base + def.budget_per_grove * (grove - 1)) * budget_scale))


static func is_boss_grove(def: WaveDef, grove: int) -> bool:
	return def.boss_every > 0 and grove % def.boss_every == 0


static func _weighted(weights: PackedFloat32Array, rng: SeededRng) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = rng.next_float() * total
	for i: int in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


static func _cheapest(pool: Array[StringName], defs: Dictionary[StringName, ArchetypeDef]) -> StringName:
	var best: StringName = pool[0]
	for id: StringName in pool:
		if defs[id].budget_cost < defs[best].budget_cost:
			best = id
	return best
