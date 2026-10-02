extends GdUnitTestSuite


func test_damage_heal_and_death() -> void:
	var run: RunState = RunState.new(100)
	assert_int(run.take_damage(30)).is_equal(30)
	assert_int(run.heal(50)).is_equal(30)
	assert_int(run.take_damage(500)).is_equal(100)
	assert_bool(run.is_dead()).is_true()
	assert_int(run.heal(10)).is_equal(0)


func test_revive_once_per_grove() -> void:
	var run: RunState = RunState.new(100)
	run.take_damage(100)
	assert_bool(run.revive()).is_true()
	assert_int(run.hp).is_equal(50)
	run.take_damage(100)
	assert_bool(run.revive()).is_false()
	run.next_grove()
	assert_bool(run.revive()).is_true()


func test_spirit_spending_and_frenzy() -> void:
	var run: RunState = RunState.new(100, 2)
	assert_bool(run.spend_spirit(3)).is_false()
	run.add_spirit(3)
	assert_bool(run.spend_spirit(3)).is_true()
	assert_int(run.spirit).is_equal(2)
	for i: int in 6:
		run.register_kill()
	assert_int(run.frenzy).is_equal(6)
	run.tick(RunState.FRENZY_WINDOW + 0.1)
	assert_int(run.frenzy).is_equal(0)


func test_arrow_purchase_and_equip() -> void:
	var p: Profile = Profile.new()
	var bone: ArrowDef = GameData.arrow(&"bone")
	assert_int(bone.meat_cost).is_equal(70)
	assert_bool(p.buy_arrow(bone)).is_false()
	p.meat = 184
	assert_bool(p.buy_arrow(bone)).is_true()
	assert_int(p.meat).is_equal(114)
	assert_str(String(p.equipped_arrow)).is_equal("bone")
	assert_bool(p.buy_arrow(bone)).is_false()


func test_shrine_levels_cost_4_8_14_22_32() -> void:
	var p: Profile = Profile.new()
	var suryak: ShrineDef = GameData.shrine(&"suryak")
	p.spirit = 80
	var spent: Array[int] = []
	while p.can_level(suryak):
		var before: int = p.spirit
		p.level_up(suryak)
		spent.append(before - p.spirit)
	assert_array(spent).is_equal([4, 8, 14, 22, 32])
	assert_int(p.shrine_level(&"suryak")).is_equal(5)
	assert_float(GameData.shrine_bonus(p, ShrineDef.Stat.DAMAGE)).is_equal_approx(0.5, 0.0001)


func test_profile_round_trip_and_banking() -> void:
	var p: Profile = Profile.new()
	p.meat = 10
	p.owned_arrows.append(&"flint")
	p.equipped_arrow = &"flint"
	p.shrine_levels[&"tamba"] = 2
	var run: RunState = RunState.new(100)
	run.add_meat(64)
	run.add_spirit(12)
	run.grove = 7
	p.bank_run(run)
	var q: Profile = Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())) as Dictionary)
	assert_int(q.meat).is_equal(74)
	assert_int(q.spirit).is_equal(12)
	assert_int(q.best_grove).is_equal(7)
	assert_str(String(q.equipped_arrow)).is_equal("flint")
	assert_int(q.shrine_level(&"tamba")).is_equal(2)


func test_damage_rules() -> void:
	var bone: ArrowDef = GameData.arrow(&"bone")
	assert_int(Damage.arrow(bone, 0.0)).is_equal(18)
	assert_int(Damage.arrow(bone, 0.5, true)).is_equal(54)
