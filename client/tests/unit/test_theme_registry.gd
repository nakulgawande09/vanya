extends GdUnitTestSuite


func test_default_theme_is_active() -> void:
	assert_str(String(ThemeRegistry.theme_id)).is_equal("grove_default")


func test_every_archetype_in_manifest_resolves_to_a_scene() -> void:
	var covered: Array[StringName] = ThemeRegistry.covered_archetypes()
	assert_array(covered).contains([Ids.HUNTER, Ids.ROTLING, Ids.THORNBACK, Ids.WISP, Ids.ROTHEART])
	for id: StringName in covered:
		var visual: Resource = ThemeRegistry.visual_for(id)
		assert_object(visual).is_instanceof(PackedScene)


func test_palette_tokens() -> void:
	assert_object(ThemeRegistry.color(&"spirit_jade")).is_equal(Color("#6FF2B0"))
	assert_object(ThemeRegistry.color(&"no_such_token", Color.BLACK)).is_equal(Color.BLACK)


func test_unknown_theme_is_rejected() -> void:
	assert_dict(ThemeRegistry.read_manifest(&"does_not_exist")).is_empty()


func test_ui_theme_loads() -> void:
	assert_object(ThemeRegistry.ui_theme()).is_not_null()


func test_theme_folders_contain_no_scripts() -> void:
	var offenders: PackedStringArray = _find_scripts("res://themes/")
	assert_array(offenders).is_empty()


func _find_scripts(path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(path):
		var ext: String = file.get_extension()
		if ext in ["gd", "gdc", "cs", "gdextension", "so", "dylib", "dll"]:
			found.append(path + file)
	for dir: String in DirAccess.get_directories_at(path):
		found.append_array(_find_scripts(path + dir + "/"))
	return found
