extends GdUnitTestSuite

const REQUIRED: Array[StringName] = [
	Ids.HUNTER, Ids.ROTLING, Ids.THORNBACK, Ids.WISP, Ids.ROTHEART, Ids.MEAT, Ids.SPIRIT, Ids.TORCH,
	Ids.CAGE_BIRD, Ids.CAGE_HARE, Ids.CAGE_JAR, Ids.MEGHRA, Ids.DHORU, Ids.VAYLI, Ids.SURYAK, Ids.TAMBA,
	Ids.KAJA, Ids.ANJOR, Ids.PIRA, Ids.JUGNU, Ids.HARE,
]


func after_test() -> void:
	ThemeRegistry.activate(ThemeRegistry.DEFAULT_THEME_ID)


func test_default_theme_is_active() -> void:
	assert_str(String(ThemeRegistry.theme_id)).is_equal("grove_default")


func test_both_themes_cover_every_archetype() -> void:
	assert_array(ThemeRegistry.available_themes()).contains([&"grove_default", &"deep_reef"])
	for theme: StringName in ThemeRegistry.available_themes():
		assert_bool(ThemeRegistry.activate(theme)).is_true()
		for id: StringName in REQUIRED:
			assert_object(ThemeRegistry.visual_for(id)).override_failure_message("%s lacks %s" % [theme, id]).is_not_null()
		for icon: StringName in [Ids.MEAT, Ids.SPIRIT, &"health", Ids.MEGHRA]:
			assert_object(ThemeRegistry.icon_for(icon)).is_not_null()
		assert_object(ThemeRegistry.tileset()).is_not_null()
		assert_object(ThemeRegistry.ui_theme()).is_not_null()


func test_reef_overrides_and_inherits() -> void:
	ThemeRegistry.activate(&"deep_reef")
	assert_bool(ThemeRegistry.defines("archetypes", Ids.ROTLING)).is_true()
	assert_bool(ThemeRegistry.defines("archetypes", Ids.HUNTER)).is_false()
	assert_str(ThemeRegistry.visual_for(Ids.ROTLING).resource_path).contains("deep_reef/rigs/piranha")
	assert_str(ThemeRegistry.visual_for(Ids.HUNTER).resource_path).contains("grove_default/rigs/hunter")
	assert_object(ThemeRegistry.color(&"spirit_jade")).is_equal(Color("#7FE8FF"))


func test_theme_strings_swap() -> void:
	TranslationServer.set_locale("en")
	assert_str(tr(&"ENEMY_SWARM_NAME")).is_equal("Rotling")
	ThemeRegistry.activate(&"deep_reef")
	assert_str(tr(&"ENEMY_SWARM_NAME")).is_equal("Piranha shoal")
	# Inherited from grove_default
	assert_str(tr(&"GOD_MEGHRA_NAME")).is_equal("Meghra")
	ThemeRegistry.activate(&"grove_default")
	assert_str(tr(&"ENEMY_SWARM_NAME")).is_equal("Rotling")


func test_rotling_flipbook_and_textures() -> void:
	var book: Dictionary = ThemeRegistry.flipbook_for(Ids.ROTLING)
	assert_object(book.get("texture")).is_not_null()
	var meta: Dictionary = book["meta"]
	assert_int(VarUtil.to_int(meta["frames"])).is_equal(14)
	for t: StringName in [&"arrow_stone", &"arrow_bone", &"wisp_orb"]:
		assert_object(ThemeRegistry.texture_for(t)).is_not_null()


func test_unknown_theme_is_rejected() -> void:
	assert_bool(ThemeRegistry.activate(&"does_not_exist")).is_false()
	assert_str(String(ThemeRegistry.theme_id)).is_equal("grove_default")


func test_hunter_rig_has_14_bones() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://themes/grove_default/rigs/hunter/rig.json"))
	var bones: Array = rig["bones"]
	assert_int(bones.size()).is_equal(14)
	var hunter: Node = ThemeRegistry.visual_for(Ids.HUNTER).instantiate()
	assert_int(hunter.find_children("*", "Bone2D", true, false).size()).is_equal(14)
	assert_object(hunter.get_node_or_null("AnimationPlayer")).is_not_null()
	for anim: String in ["idle", "run", "shoot", "hurt", "down", "revive"]:
		assert_bool((hunter.get_node("AnimationPlayer") as AnimationPlayer).has_animation(anim)).is_true()
	hunter.free()


func test_theme_folders_contain_no_scripts() -> void:
	assert_array(_find_scripts("res://themes/")).is_empty()


func _find_scripts(path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd", "gdc", "cs", "gdextension", "so", "dylib", "dll"]:
			found.append(path + file)
	for dir: String in DirAccess.get_directories_at(path):
		found.append_array(_find_scripts(path + dir + "/"))
	return found
