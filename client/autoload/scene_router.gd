extends Node
## Threaded scene loading and swapping. Scenes are always changed at safe boundaries.

signal load_started(path: String)
signal load_finished(path: String)

var _pending_path: String = ""


func _ready() -> void:
	set_process(false)


func change_to(path: String) -> void:
	if _pending_path != "":
		push_warning("SceneRouter: already loading %s, ignoring %s" % [_pending_path, path])
		return
	var err: Error = ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		push_error("SceneRouter: cannot load %s (%s)" % [path, error_string(err)])
		return
	_pending_path = path
	load_started.emit(path)
	set_process(true)


func is_loading() -> bool:
	return _pending_path != ""


func _process(_delta: float) -> void:
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_pending_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	set_process(false)
	var path: String = _pending_path
	_pending_path = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("SceneRouter: failed to load %s" % path)
		return
	var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	get_tree().change_scene_to_packed(scene)
	load_finished.emit(path)
