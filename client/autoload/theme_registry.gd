extends Node
## Resolves archetype IDs to presentation from the active theme (manifest v2).
## Gameplay never references a theme path: it calls visual_for(Ids.ROTLING), icon_for(Ids.MEAT), ...
## A theme may inherit from another (Deep Reef inherits the hunter, gods, guides and tiles from
## grove_default); lookups fall back along that chain. Each theme brings its own strings
## (enemy and currency names), merged parent-first into one Translation per locale.
## Switch themes only at scene boundaries (camp screen), never mid-room.

const DEFAULT_THEME_ID: StringName = &"grove_default"
const THEMES_ROOT: String = "res://themes/"
const SCHEMA_VERSION: int = 2
const MAX_INHERIT_DEPTH: int = 3

var theme_id: StringName = &""
## Active manifest first, then its ancestors.
var _chain: Array[Dictionary] = []
var _cache: Dictionary[String, Resource] = {}
var _translations: Array[Translation] = []


func _init() -> void:
	activate(DEFAULT_THEME_ID)


func _ready() -> void:
	_apply_ui_theme()


## Loads a theme and its ancestors. Returns false (and keeps the current theme) on any error.
func activate(new_theme_id: StringName) -> bool:
	var chain: Array[Dictionary] = []
	var id: StringName = new_theme_id
	while id != &"" and chain.size() <= MAX_INHERIT_DEPTH:
		var manifest: Dictionary = read_manifest(id)
		if manifest.is_empty():
			push_error("ThemeRegistry: missing or invalid manifest for theme '%s'" % id)
			return false
		chain.append(manifest)
		id = StringName(str(manifest.get("inherits", "")))
	if id != &"":
		push_error("ThemeRegistry: inheritance too deep for theme '%s'" % new_theme_id)
		return false
	var old: StringName = theme_id
	_chain = chain
	_cache.clear()
	theme_id = new_theme_id
	_swap_translations()
	if is_inside_tree():
		_apply_ui_theme()
		if old != &"" and old != theme_id:
			EventBus.theme_changed.emit(theme_id)
	return true


static func read_manifest(id: StringName) -> Dictionary:
	var path: String = THEMES_ROOT + String(id) + "/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var manifest: Dictionary = parsed
	if StringName(str(manifest.get("theme_id", ""))) != id:
		return {}
	if VarUtil.to_int(manifest.get("schema_version"), 0) != SCHEMA_VERSION:
		return {}
	return manifest


## Every theme folder under res://themes/ with a valid manifest.
static func available_themes() -> Array[StringName]:
	var out: Array[StringName] = []
	for dir: String in DirAccess.get_directories_at(THEMES_ROOT):
		if not read_manifest(StringName(dir)).is_empty():
			out.append(StringName(dir))
	return out


func has_visual(archetype_id: StringName) -> bool:
	return _lookup("archetypes", archetype_id).has("visual")


## The visual scene for an archetype (rotling, cage_bird, meat, meghra, ...) or null.
func visual_for(archetype_id: StringName) -> PackedScene:
	return _load(str(_lookup("archetypes", archetype_id).get("visual", ""))) as PackedScene


## A decoration or effect scene (bush, gate_open, hit_spark, ...) or null.
func prop_for(prop_id: StringName) -> PackedScene:
	return _load(_lookup_value("props", prop_id)) as PackedScene


## A 48 px UI icon (meat, spirit, health, god and guide icons) or null.
func icon_for(icon_id: StringName) -> Texture2D:
	return _load(_lookup_value("icons", icon_id)) as Texture2D


## A raw texture drawn by code (arrows, orbs, sparks) or null.
func texture_for(texture_id: StringName) -> Texture2D:
	return _load(_lookup_value("textures", texture_id)) as Texture2D


## Swarm flipbook for an archetype: {"texture": Texture2D, "meta": Dictionary}, or empty
## when the active theme only has a sprite scene (then swarms draw that scene's sprite).
func flipbook_for(archetype_id: StringName) -> Dictionary:
	var entry: Dictionary = _lookup("archetypes", archetype_id)
	var book: Variant = entry.get("flipbook", {})
	if not book is Dictionary or (book as Dictionary).is_empty():
		return {}
	var spec: Dictionary = book
	var tex: Texture2D = _load(str(spec.get("texture", ""))) as Texture2D
	var meta_path: String = str(spec.get("meta", ""))
	if tex == null or not _is_allowed_path(meta_path) or not FileAccess.file_exists(meta_path):
		return {}
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if not meta is Dictionary:
		return {}
	return {"texture": tex, "meta": meta}


func tileset() -> TileSet:
	return _load(_first_string("tiles")) as TileSet


func screen_art(screen_id: StringName) -> Texture2D:
	return _load(_lookup_value("screens", screen_id)) as Texture2D


func name_key_for(archetype_id: StringName) -> StringName:
	return StringName(str(_lookup("archetypes", archetype_id).get("name_key", "")))


func role_of(archetype_id: StringName) -> StringName:
	return StringName(str(_lookup("archetypes", archetype_id).get("role", "")))


func color(token: StringName, fallback: Color = Color.MAGENTA) -> Color:
	var hex: String = _lookup_value("palette", token)
	return Color.from_string(hex, fallback) if hex != "" else fallback


## Darkness colour (alpha = strength) and the warm light colour for rooms.
func darkness() -> Color:
	var lighting: Dictionary = _first_dict("lighting")
	var c: Color = Color.from_string(str(lighting.get("darkness", "#1C1016")), Color.BLACK)
	c.a = VarUtil.to_float(lighting.get("darkness_strength"), 0.74)
	return c


## AudioManifest paths along the chain, active theme first (Services.audio loads them).
func audio_manifest_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for manifest: Dictionary in _chain:
		var p: String = str(manifest.get("audio_manifest", ""))
		if p != "" and _is_allowed_path(p) and ResourceLoader.exists(p):
			out.append(p)
	return out


func ui_theme() -> Theme:
	return _load(_first_string("ui_theme")) as Theme


func covered_archetypes() -> Array[StringName]:
	var out: Array[StringName] = []
	for manifest: Dictionary in _chain:
		var archetypes: Dictionary = manifest.get("archetypes", {})
		for key: Variant in archetypes.keys():
			var id: StringName = StringName(str(key))
			if not out.has(id):
				out.append(id)
	return out


## Theme the active manifest itself defines a value for (not inherited), for tests and tools.
func defines(section: String, key: StringName) -> bool:
	if _chain.is_empty():
		return false
	var dict: Variant = _chain[0].get(section, {})
	return dict is Dictionary and (dict as Dictionary).has(String(key))


func _lookup(section: String, key: StringName) -> Dictionary:
	for manifest: Dictionary in _chain:
		var dict: Variant = manifest.get(section, {})
		if dict is Dictionary:
			var entry: Variant = (dict as Dictionary).get(String(key))
			if entry is Dictionary:
				return entry
	return {}


func _lookup_value(section: String, key: StringName) -> String:
	for manifest: Dictionary in _chain:
		var dict: Variant = manifest.get(section, {})
		if dict is Dictionary and (dict as Dictionary).has(String(key)):
			return str((dict as Dictionary)[String(key)])
	return ""


func _first_string(key: String) -> String:
	for manifest: Dictionary in _chain:
		var value: String = str(manifest.get(key, ""))
		if value != "":
			return value
	return ""


func _first_dict(key: String) -> Dictionary:
	for manifest: Dictionary in _chain:
		var value: Variant = manifest.get(key, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			return value
	return {}


func _load(path: String) -> Resource:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	if not _is_allowed_path(path):
		push_error("ThemeRegistry: '%s' is outside the theme chain of '%s'" % [path, theme_id])
		return null
	var res: Resource = load(path)
	_cache[path] = res
	return res


## A theme may only reference files inside its own folder or an ancestor's.
func _is_allowed_path(path: String) -> bool:
	for manifest: Dictionary in _chain:
		if path.begins_with(THEMES_ROOT + str(manifest.get("theme_id", "")) + "/"):
			return true
	return false


func _swap_translations() -> void:
	for t: Translation in _translations:
		TranslationServer.remove_translation(t)
	_translations.clear()
	var merged: Dictionary[String, Translation] = {}
	for i: int in range(_chain.size() - 1, -1, -1):  # ancestors first, so the theme overrides them
		var paths: Variant = _chain[i].get("translations", [])
		if not paths is Array:
			continue
		for p: Variant in paths:
			var path: String = str(p)
			if not _is_allowed_path(path) or not ResourceLoader.exists(path):
				continue
			var source: Translation = load(path) as Translation
			if source == null:
				continue
			var target: Translation = merged.get(source.locale)
			if target == null:
				target = Translation.new()
				target.locale = source.locale
				merged[source.locale] = target
			for key: String in source.get_message_list():
				target.add_message(key, source.get_message(key))
	for t: Translation in merged.values():
		TranslationServer.add_translation(t)
		_translations.append(t)


func _apply_ui_theme() -> void:
	var ui: Theme = ui_theme()
	if ui != null and is_inside_tree():
		get_tree().root.theme = ui
