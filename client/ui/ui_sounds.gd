class_name UiSounds
extends RefCounted
## Gives every button in a screen its UI sound (Audio Bible A2 UI rows): a wooden tap, or a soft
## "back" for Done / Back / Resume buttons. Idempotent, so screens call it again after rebuilding.

const TAP: StringName = &"ui.tap"
const BACK: StringName = &"ui.back"
const WIRED: StringName = &"ui_sfx_wired"


static func wire(root: Node) -> void:
	for b: Node in root.find_children("*", "BaseButton", true, false):
		_wire_one(b as BaseButton)
	if root is BaseButton:
		_wire_one(root as BaseButton)


static func _wire_one(b: BaseButton) -> void:
	if b.has_meta(WIRED):
		return
	b.set_meta(WIRED, true)
	var n: String = String(b.name)
	var id: StringName = BACK if n.contains("Done") or n.contains("Back") or n.contains("Resume") else TAP
	b.pressed.connect(func() -> void: Services.audio.play(id))
