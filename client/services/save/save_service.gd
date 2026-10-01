class_name SaveService
extends RefCounted
## JSON save with an integrity envelope: {"schema", "written_at", "crc32", "data"}.
## Writes are atomic (save.tmp → rename) and keep the previous good file as save.bak.
## Load order: save.json → save.bak → fresh save (docs/standards.md §C10).

enum LoadSource { PRIMARY, BACKUP, FRESH }

const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "save.json"
const BACKUP_NAME: String = "save.bak"
const TEMP_NAME: String = "save.tmp"

var data: Dictionary = {}
var last_load_source: LoadSource = LoadSource.FRESH
var _dir: String
var _dirty: bool = false


func _init(dir: String = "user://") -> void:
	_dir = dir if dir.ends_with("/") else dir + "/"


func load_game() -> Dictionary:
	var primary: Variant = _read_envelope(_dir + FILE_NAME)
	if primary is Dictionary:
		data = primary
		last_load_source = LoadSource.PRIMARY
		return data
	var backup: Variant = _read_envelope(_dir + BACKUP_NAME)
	if backup is Dictionary:
		data = backup
		last_load_source = LoadSource.BACKUP
		return data
	data = {}
	last_load_source = LoadSource.FRESH
	return data


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	_dirty = true


func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


## Writes only if something changed since the last save.
func flush() -> Error:
	return save_game() if _dirty else OK


func save_game() -> Error:
	# Round-trip through JSON first so the CRC is computed over the same types the loader sees
	# (JSON has no int type: 3 comes back as 3.0).
	var normalized: Variant = JSON.parse_string(JSON.stringify(data))
	var envelope: Dictionary = {
		"schema": SCHEMA_VERSION,
		"written_at": int(Time.get_unix_time_from_system()),
		"crc32": Crc32.of_string(JSON.stringify(normalized, "", true, true)),
		"data": normalized,
	}
	DirAccess.make_dir_recursive_absolute(_dir)
	var tmp_path: String = _dir + TEMP_NAME
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "", true, true))
	file.flush()
	file.close()
	var main_path: String = _dir + FILE_NAME
	var bak_path: String = _dir + BACKUP_NAME
	if FileAccess.file_exists(main_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err: Error = DirAccess.rename_absolute(main_path, bak_path)
		if bak_err != OK:
			return bak_err
	var err: Error = DirAccess.rename_absolute(tmp_path, main_path)
	if err == OK:
		_dirty = false
	return err


## Returns the data Dictionary, or null if the file is missing, corrupt or fails its CRC.
func _read_envelope(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var envelope: Dictionary = parsed
	var payload: Variant = envelope.get("data")
	if not payload is Dictionary:
		return null
	# TODO: run migrations/vN_to_vN+1.gd in a chain when SCHEMA_VERSION increases.
	if VarUtil.to_int(envelope.get("schema"), 0) > SCHEMA_VERSION:
		return null
	var expected: int = VarUtil.to_int(envelope.get("crc32"), -1)
	if Crc32.of_string(JSON.stringify(payload, "", true, true)) != expected:
		return null
	return payload
