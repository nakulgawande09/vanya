extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	_dir = "user://test_saves_%d/" % Time.get_ticks_usec()


func after_test() -> void:
	for name: String in [SaveService.FILE_NAME, SaveService.BACKUP_NAME, SaveService.TEMP_NAME]:
		if FileAccess.file_exists(_dir + name):
			DirAccess.remove_absolute(_dir + name)
	DirAccess.remove_absolute(_dir)


func test_missing_file_gives_fresh_save() -> void:
	var save: SaveService = SaveService.new(_dir)
	assert_dict(save.load_game()).is_empty()
	assert_int(save.last_load_source).is_equal(SaveService.LoadSource.FRESH)


func test_round_trip() -> void:
	var save: SaveService = SaveService.new(_dir)
	save.set_value("meat", 184)
	save.set_value("spirit", 23)
	assert_int(save.save_game()).is_equal(OK)

	var loaded: SaveService = SaveService.new(_dir)
	var data: Dictionary = loaded.load_game()
	assert_int(loaded.last_load_source).is_equal(SaveService.LoadSource.PRIMARY)
	assert_int(VarUtil.to_int(data.get("meat"))).is_equal(184)
	assert_int(VarUtil.to_int(data.get("spirit"))).is_equal(23)


func test_corrupt_primary_falls_back_to_backup() -> void:
	var save: SaveService = SaveService.new(_dir)
	save.set_value("meat", 10)
	save.save_game()
	save.set_value("meat", 20)
	save.save_game()  # save.bak now holds meat=10

	var file: FileAccess = FileAccess.open(_dir + SaveService.FILE_NAME, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()

	var loaded: SaveService = SaveService.new(_dir)
	var data: Dictionary = loaded.load_game()
	assert_int(loaded.last_load_source).is_equal(SaveService.LoadSource.BACKUP)
	assert_int(VarUtil.to_int(data.get("meat"))).is_equal(10)


func test_crc_mismatch_is_rejected() -> void:
	var save: SaveService = SaveService.new(_dir)
	save.set_value("meat", 5)
	save.save_game()
	var text: String = FileAccess.get_file_as_string(_dir + SaveService.FILE_NAME)
	var file: FileAccess = FileAccess.open(_dir + SaveService.FILE_NAME, FileAccess.WRITE)
	file.store_string(text.replace("5", "9"))
	file.close()

	var loaded: SaveService = SaveService.new(_dir)
	loaded.load_game()
	assert_int(loaded.last_load_source).is_not_equal(SaveService.LoadSource.PRIMARY)


func test_flush_skips_when_clean() -> void:
	var save: SaveService = SaveService.new(_dir)
	assert_int(save.flush()).is_equal(OK)
	assert_bool(FileAccess.file_exists(_dir + SaveService.FILE_NAME)).is_false()
