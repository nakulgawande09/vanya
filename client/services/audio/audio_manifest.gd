class_name AudioManifest
extends Resource
## A theme's sounds and music (Audio Bible A5), generated from pipelines/audio by
## tools/build_audio_manifest.gd. Lookups fall back along the theme chain (ThemeRegistry).

@export var theme_id: StringName = &""
@export var entries: Array[AudioEntry] = []
@export var music: Array[MusicCue] = []
