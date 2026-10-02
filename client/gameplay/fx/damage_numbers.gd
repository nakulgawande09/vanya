class_name DamageNumbers
extends Node2D
## Pooled floating numbers (Screens board): arrow hit in rice white, god strike in torch gold,
## heal in spirit jade with "+", the hunter's own damage in red with "−". Lives on the emissive
## layer so numbers stay readable in the dark.

enum Kind { HIT, GOD, HEAL, HURT }

const POOL: int = 32
const LIFE: float = 0.75
const RISE: float = 30.0

var _labels: Array[Label] = []
var _t: PackedFloat32Array = PackedFloat32Array()
var _origin: PackedVector2Array = PackedVector2Array()
var _colors: Array[Color] = []
var _cursor: int = 0
var enabled: bool = true


func _ready() -> void:
	_colors = [ThemeRegistry.color(&"rice_white", Color.WHITE), ThemeRegistry.color(&"torch_gold", Color.GOLD),
			ThemeRegistry.color(&"spirit_jade", Color.AQUAMARINE), Color("#ff6d5e")]
	for i: int in POOL:
		var l: Label = Label.new()
		l.theme_type_variation = &"NumberLabel"
		l.visible = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(60, 24)
		l.pivot_offset = Vector2(30, 12)
		add_child(l)
		_labels.append(l)
	_t.resize(POOL)
	_t.fill(-1.0)
	_origin.resize(POOL)


func show_number(at: Vector2, amount: int, kind: Kind) -> void:
	if not enabled and kind == Kind.HIT:
		return
	var i: int = _cursor
	_cursor = (_cursor + 1) % POOL
	var l: Label = _labels[i]
	match kind:
		Kind.HEAL:
			l.text = "+%d" % amount
		Kind.HURT:
			l.text = "−%d" % amount
		_:
			l.text = str(amount)
	l.add_theme_color_override(&"font_color", _colors[kind])
	l.add_theme_font_size_override(&"font_size", 24 if kind == Kind.GOD else 18)
	_origin[i] = at - Vector2(30, 24)
	l.position = _origin[i]
	l.modulate.a = 1.0
	l.visible = true
	_t[i] = 0.0


func clear() -> void:
	for i: int in POOL:
		_t[i] = -1.0
		_labels[i].visible = false


func tick(delta: float) -> void:
	for i: int in POOL:
		if _t[i] < 0.0:
			continue
		_t[i] += delta
		var k: float = _t[i] / LIFE
		if k >= 1.0:
			_t[i] = -1.0
			_labels[i].visible = false
			continue
		_labels[i].position = _origin[i] - Vector2(0, RISE * ease(k, 0.4))
		_labels[i].modulate.a = 1.0 - maxf(0.0, k - 0.5) * 2.0
