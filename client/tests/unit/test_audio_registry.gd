extends GdUnitTestSuite
## Theme audio registry (Audio Bible A5): every gameplay ID resolves, IDs fall back by trimming
## segments, Deep Reef overrides a few sounds and inherits the rest, the manifests stay in budget.

const GAMEPLAY_IDS: Array[StringName] = [
	&"sfx.player.hurt", &"sfx.player.death", &"sfx.player.revive", &"sfx.player.step.grass", &"sfx.player.step.earth",
	&"sfx.player.bow.release.t1", &"sfx.player.bow.release.t4", &"sfx.player.arrow.impact.flesh",
	&"sfx.player.arrow.impact.armor", &"sfx.player.arrow.impact.stone", &"sfx.enemy.rotling.death",
	&"sfx.enemy.rotling.hurt", &"sfx.enemy.rotling.alert", &"sfx.enemy.rotling.attack", &"sfx.enemy.rotling.idle",
	&"sfx.enemy.thornback.death", &"sfx.enemy.thornback.stomp", &"sfx.enemy.wisp.spit", &"sfx.enemy.wisp.float_loop",
	&"sfx.boss.rotheart.heart_loop", &"sfx.boss.rotheart.telegraph", &"sfx.boss.rotheart.charge_loop",
	&"sfx.boss.rotheart.wall_hit", &"sfx.boss.rotheart.stunned", &"sfx.boss.rotheart.summon", &"sfx.boss.rotheart.death",
	&"sfx.god.meghra.impact", &"sfx.god.dhoru.impact", &"sfx.god.vayli.heal", &"sfx.rescue.cage.break",
	&"sfx.rescue.freed.pira", &"sfx.pickup.spirit.collect", &"sfx.pickup.meat.collect", &"sfx.world.gate.open",
	&"sfx.world.gate.seal_hum", &"sfx.world.portal.open", &"sfx.world.portal.loop", &"sfx.world.torch.loop",
	&"sfx.fb.hitstop.crunch", &"sfx.fb.frenzy.tier5", &"sfx.fb.lowhp.heartbeat_loop", &"ui.tap", &"ui.back",
	&"ui.purchase", &"ui.error", &"ui.confirm", &"sfx.shrine.suryak.purchase", &"amb.grove.default.bed", &"amb.blight.bed",
]


func _audio() -> GodotAudio:
	var a: GodotAudio = Services.audio as GodotAudio
	if a == null:
		a = auto_free(GodotAudio.new()) as GodotAudio
		add_child(a)
	return a


func after_test() -> void:
	ThemeRegistry.activate(ThemeRegistry.DEFAULT_THEME_ID)
	_audio().reload()


func test_every_gameplay_id_resolves_in_the_default_theme() -> void:
	var a: GodotAudio = _audio()
	for id: StringName in GAMEPLAY_IDS:
		assert_object(a.resolve(id)).override_failure_message("missing sound %s" % id).is_not_null()


func test_ids_fall_back_by_trimming_segments() -> void:
	var a: GodotAudio = _audio()
	var e: AudioEntry = a.resolve(&"sfx.player.hurt.extra_variant")
	assert_object(e).is_not_null()
	assert_str(String(e.id)).is_equal("sfx.player.hurt")
	assert_object(a.resolve(&"sfx.nothing.here")).is_null()


func test_entries_carry_bible_rules() -> void:
	var a: GodotAudio = _audio()
	assert_int(a.resolve(&"sfx.player.hurt").tier).is_equal(AudioEntry.Tier.P0)
	assert_str(String(a.resolve(&"sfx.player.hurt").haptic)).is_equal("hurt")
	assert_int(a.resolve(&"sfx.enemy.rotling.death").poly).is_equal(3)
	assert_bool(a.resolve(&"sfx.enemy.rotling.death").pan).is_true()
	assert_bool(a.resolve(&"sfx.boss.rotheart.heart_loop").loop).is_true()
	assert_str(String(a.resolve(&"ui.tap").bus)).is_equal("UI")
	assert_object(a.resolve(&"sfx.enemy.rotling.death").stream).is_instanceof(AudioStreamRandomizer)


func test_deep_reef_overrides_rotling_and_inherits_the_rest() -> void:
	var a: GodotAudio = _audio()
	var grove_death: AudioEntry = a.resolve(&"sfx.enemy.rotling.death")
	assert_bool(ThemeRegistry.activate(&"deep_reef")).is_true()
	a.reload()
	var reef_death: AudioEntry = a.resolve(&"sfx.enemy.rotling.death")
	assert_object(reef_death).is_not_same(grove_death)
	assert_object(a.resolve(&"sfx.player.hurt")).is_not_null()
	assert_bool(a.music.has_cue(&"grove")).is_true()


func test_resident_audio_fits_the_low_tier_budget() -> void:
	var a: GodotAudio = _audio()
	a.music_context(&"run")
	assert_float(a.resident_bytes / 1048576.0).is_less(10.5)
	a.music_context(&"")
