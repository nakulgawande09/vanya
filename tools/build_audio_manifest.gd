extends SceneTree
## Turns pipelines/audio/index/<theme>.json (written by pipelines/audio/synth.py) into
## res://themes/<theme>/audio/audio_manifest.tres (Audio Bible A5). Run after importing:
##   godot --headless --path client -s ../tools/build_audio_manifest.gd

const INDEX_DIR: String = "../pipelines/audio/index"


func _init() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join(INDEX_DIR).simplify_path()
	var failed: bool = false
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "json":
			failed = not _build(dir.path_join(file)) or failed
	quit(1 if failed else 0)


func _build(index_path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		push_error("build_audio_manifest: cannot parse %s" % index_path)
		return false
	var index: Dictionary = parsed
	var manifest: AudioManifest = AudioManifest.new()
	manifest.theme_id = StringName(str(index.get("theme_id", "")))
	var sfx: Dictionary = index.get("sfx", {})
	var ids: Array = sfx.keys()
	ids.sort()
	for id: Variant in ids:
		var spec: Dictionary = sfx[id]
		var entry: AudioEntry = AudioEntry.new()
		entry.id = StringName(str(id))
		entry.bus = StringName(str(spec.get("bus", "SFX")))
		entry.tier = clampi(VarUtil.to_int(spec.get("tier"), 2), 0, 4) as AudioEntry.Tier
		entry.poly = maxi(1, VarUtil.to_int(spec.get("poly"), 1))
		entry.pan = spec.get("pan", false) == true
		entry.loop = spec.get("loop", false) == true
		entry.cooldown_ms = VarUtil.to_int(spec.get("cooldown_ms"), 0)
		entry.haptic = StringName(str(spec.get("haptic", "")))
		var files: Array = spec.get("files", [])
		var rnd: AudioStreamRandomizer = AudioStreamRandomizer.new()
		rnd.random_pitch = VarUtil.to_float(spec.get("random_pitch"), 1.06)
		rnd.random_volume_offset_db = VarUtil.to_float(spec.get("random_volume_db"), 2.0)
		rnd.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if files.size() > 1 \
				else AudioStreamRandomizer.PLAYBACK_RANDOM
		for f: Variant in files:
			var stream: AudioStream = load(str(f)) as AudioStream
			if stream == null:
				push_error("build_audio_manifest: cannot load %s" % f)
				return false
			rnd.add_stream(-1, stream)
			entry.bytes += _bytes(str(f), stream)
		entry.stream = rnd
		manifest.entries.append(entry)
	var music: Dictionary = index.get("music", {})
	var cues: Array = music.keys()
	cues.sort()
	for key: Variant in cues:
		var spec: Dictionary = music[key]
		var cue: MusicCue = MusicCue.new()
		cue.cue = StringName(str(key))
		cue.bpm = VarUtil.to_float(spec.get("bpm"), 0.0)
		cue.bars = VarUtil.to_int(spec.get("bars"), 0)
		cue.bar_beats = VarUtil.to_int(spec.get("bar_beats"), 4)
		cue.stem_names = _strings(spec.get("stems", []))
		cue.stem_paths = _strings(spec.get("files", []))
		cue.low_stem_paths = _strings(spec.get("low_files", []))
		cue.playlist_paths = _strings(spec.get("playlist", []))
		cue.path = str(spec.get("file", ""))
		for p: String in cue.stem_paths + cue.playlist_paths + (PackedStringArray([cue.path]) if cue.path != "" else PackedStringArray()):
			cue.bytes += _bytes(p, load(p) as AudioStream)
		for p: String in cue.low_stem_paths:
			cue.low_bytes += _bytes(p, load(p) as AudioStream)
		manifest.music.append(cue)
	var out: String = "res://themes/%s/audio/audio_manifest.tres" % manifest.theme_id
	var err: Error = ResourceSaver.save(manifest, out)
	print("build_audio_manifest: %s (%d sounds, %d cues) %s" % [out, manifest.entries.size(), manifest.music.size(),
			error_string(err)])
	return err == OK


## Resident bytes: decoded/compressed sample data for WAV (QOA), packet data ≈ file size for OGG.
static func _bytes(path: String, stream: AudioStream) -> int:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).data.size()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return int(f.get_length()) if f != null else 0


static func _strings(v: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if v is Array:
		for s: Variant in v:
			out.append(str(s))
	return out
