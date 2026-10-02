class_name SfxPool
extends Node
## Sixteen voices created once (Audio Bible A5): 12 non-positional AudioStreamPlayers and 4
## AudioStreamPlayer2Ds for panned entries. Playing never allocates nodes. Rules:
## - per-sound polyphony: at the cap, the oldest voice of the same sound restarts;
## - per-sound cooldown;
## - when full, steal the lowest-priority voice (P4 → P3 → …), oldest first, never P0 and never a
##   voice more important than the new sound; otherwise drop the new sound.

const FLAT: int = 12
const PANNED: int = 4
const MAX_DISTANCE: float = 1688.0  # 2 × the 844 px portrait height
const ATTENUATION: float = 0.5

var steals: int = 0
var drops: int = 0
var cooldown_skips: int = 0
var _players: Array[Node] = []
var _entry: Array[AudioEntry] = []
var _order: PackedInt64Array = PackedInt64Array()
var _last_start: Dictionary[StringName, int] = {}
var _serial: int = 0


func _ready() -> void:
	for i: int in FLAT + PANNED:
		var p: Node
		if i < FLAT:
			p = AudioStreamPlayer.new()
		else:
			var p2: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
			p2.max_distance = MAX_DISTANCE
			p2.attenuation = ATTENUATION
			p = p2
		p.name = "Voice%d" % i
		add_child(p)
		p.connect(&"finished", _on_finished.bind(i))
		_players.append(p)
		_entry.append(null)
	_order.resize(FLAT + PANNED)


## Starts `e`; returns the voice index or -1 (cooldown, cap or no voice to steal).
func play(e: AudioEntry, at: Vector2, pitch: float, volume_db: float, now_ms: int = -1) -> int:
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if e.cooldown_ms > 0 and _last_start.has(e.id) and now - _last_start[e.id] < e.cooldown_ms:
		cooldown_skips += 1
		return -1
	var panned: bool = e.pan and at.is_finite()
	var lo: int = FLAT if panned else 0
	var hi: int = FLAT + PANNED if panned else FLAT
	var same: int = 0
	var oldest_same: int = -1
	var free: int = -1
	var victim: int = -1
	for i: int in range(lo, hi):
		var cur: AudioEntry = _entry[i]
		if cur == null:
			if free < 0:
				free = i
			continue
		if cur.id == e.id:
			same += 1
			if oldest_same < 0 or _order[i] < _order[oldest_same]:
				oldest_same = i
		if cur.tier == AudioEntry.Tier.P0 or cur.loop:
			continue
		if victim < 0 or cur.tier > _entry[victim].tier or (cur.tier == _entry[victim].tier and _order[i] < _order[victim]):
			victim = i
	var slot: int = -1
	if same >= e.poly:
		if e.loop:
			return -1
		slot = oldest_same
	elif free >= 0:
		slot = free
	elif victim >= 0 and _entry[victim].tier >= e.tier:
		slot = victim
		steals += 1
	else:
		drops += 1
		return -1
	_start(slot, e, at, pitch, volume_db)
	_last_start[e.id] = now
	return slot


func stop(voice: int) -> void:
	if voice < 0 or voice >= _players.size():
		return
	_players[voice].call(&"stop")
	_entry[voice] = null


func stop_all() -> void:
	for i: int in _players.size():
		stop(i)


func set_pitch(voice: int, pitch: float) -> void:
	if voice >= 0 and voice < _players.size():
		_players[voice].set(&"pitch_scale", pitch)


func entry_at(voice: int) -> AudioEntry:
	return _entry[voice] if voice >= 0 and voice < _entry.size() else null


func active_count() -> int:
	var n: int = 0
	for e: AudioEntry in _entry:
		if e != null:
			n += 1
	return n


func voices_of(id: StringName) -> int:
	var n: int = 0
	for e: AudioEntry in _entry:
		if e != null and e.id == id:
			n += 1
	return n


func _start(slot: int, e: AudioEntry, at: Vector2, pitch: float, volume_db: float) -> void:
	var p: Node = _players[slot]
	p.call(&"stop")
	p.set(&"stream", e.stream)
	p.set(&"bus", e.bus)
	p.set(&"pitch_scale", pitch)
	p.set(&"volume_db", volume_db)
	if p is AudioStreamPlayer2D:
		(p as AudioStreamPlayer2D).global_position = at
	p.call(&"play")
	_entry[slot] = e
	_serial += 1
	_order[slot] = _serial


func _on_finished(i: int) -> void:
	if _entry[i] != null and not _entry[i].loop:
		_entry[i] = null
