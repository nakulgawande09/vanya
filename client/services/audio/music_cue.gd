class_name MusicCue
extends Resource
## A music cue (Audio Bible A3). Stems are referenced by path and loaded only when their
## context plays (camp vs run), so the low tier keeps one cue set resident at a time.

@export var cue: StringName = &""
@export var bpm: float = 0.0
@export var bars: int = 0
@export var bar_beats: int = 4
## Layered stems (grove, boss), in mixer order.
@export var stem_names: PackedStringArray = []
@export var stem_paths: PackedStringArray = []
## The 3-stem low-tier variant: bed, melody, drive (percussion + tension).
@export var low_stem_paths: PackedStringArray = []
## Playlist tracks (camp).
@export var playlist_paths: PackedStringArray = []
## A single file (stingers).
@export var path: String = ""
## Resident size when loaded: full stems (or playlist / stinger) and the low-tier stem set.
@export var bytes: int = 0
@export var low_bytes: int = 0
