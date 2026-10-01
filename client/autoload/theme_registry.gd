extends Node
## Resolves archetype IDs to presentation resources from the active theme.
## Gameplay never references a theme path; it calls visual_for(&"rotling").
## Theme manifests live at res://themes/<theme_id>/manifest.json (docs/standards.md §C3).

const DEFAULT_THEME_ID: StringName = &"grove_default"
const THEMES_ROOT: String = "res://themes/"

var theme_id: StringName = &""
var _manifest: Dictionary = {}
var _cache: Dictionary[StringName, Resource] = {}


func _init() -> void:
	activate(DEFAULT_THEME_ID)


## Switch themes only at scene boundaries (camp screen), never mid-room.
func activate(new_theme_id: StringName) -> bool:
	var manifest: Dictionary = read_manifest(new_theme_id)
	if manifest.is_empty():
		push_error("ThemeRegistry: missing or invalid manifest for theme '%s'" % new_theme_id)
		return false
	_manifest = manifest
	_cache.clear()
	theme_id = new_theme_id
	var ui: Theme = ui_theme()
	if ui != null and is_inside_tree():
		get_tree().root.theme = ui
	return true


func _ready() -> void:
	var ui: Theme = ui_theme()
	if ui != null:
		get_tree().root.theme = ui


static func read_manifest(id: StringName) -> Dictionary:
	var path: String = THEMES_ROOT + String(id) + "/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var manifest: Dictionary = parsed
		if StringName(str(manifest.get("theme_id", ""))) == id:
			return manifest
	return {}


func has_visual(archetype_id: StringName) -> bool:
	return _archetype_entry(archetype_id).has("visual")


## The visual (usually a PackedScene) for an archetype, or null if the theme lacks one.
func visual_for(archetype_id: StringName) -> Resource:
	if _cache.has(archetype_id):
		return _cache[archetype_id]
	var path: String = str(_archetype_entry(archetype_id).get("visual", ""))
	if not _is_theme_path(path):
		push_error("ThemeRegistry: no visual for '%s' in theme '%s'" % [archetype_id, theme_id])
		return null
	var res: Resource = load(path)
	_cache[archetype_id] = res
	return res


func name_key_for(archetype_id: StringName) -> StringName:
	return StringName(str(_archetype_entry(archetype_id).get("name_key", "")))


func color(token: StringName, fallback: Color = Color.MAGENTA) -> Color:
	var palette: Dictionary = _manifest.get("palette", {})
	var hex: String = str(palette.get(String(token), ""))
	return Color.from_string(hex, fallback)


func ui_theme() -> Theme:
	var path: String = str(_manifest.get("ui_theme", ""))
	return load(path) as Theme if _is_theme_path(path) else null


func covered_archetypes() -> Array[StringName]:
	var out: Array[StringName] = []
	var archetypes: Dictionary = _manifest.get("archetypes", {})
	for key: Variant in archetypes.keys():
		out.append(StringName(str(key)))
	return out


func _archetype_entry(archetype_id: StringName) -> Dictionary:
	var archetypes: Dictionary = _manifest.get("archetypes", {})
	var entry: Variant = archetypes.get(String(archetype_id), {})
	return entry if entry is Dictionary else {}


## Packs may only reference files inside their own namespace.
func _is_theme_path(path: String) -> bool:
	return path.begins_with(THEMES_ROOT + String(theme_id) + "/")
