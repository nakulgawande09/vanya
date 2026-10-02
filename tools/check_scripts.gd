extends SceneTree
## Loads every project script (outside addons/) so parse and strict-typing errors fail fast in CI.
## Usage: godot --headless --path client -s ../tools/check_scripts.gd


func _initialize() -> void:
	var failed: int = 0
	var count: int = 0
	for path: String in _scripts("res://"):
		count += 1
		var s: Script = load(path) as Script
		if s == null or not s.can_instantiate():
			failed += 1
			printerr("check_scripts: failed to compile ", path)
	print("check_scripts: %d scripts, %d failed" % [count, failed])
	quit(1 if failed > 0 else 0)


func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if d in ["addons", ".godot", "android"]:
			continue
		out.append_array(_scripts(dir.path_join(d)))
	return out
