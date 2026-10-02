extends Control
## The hunters' camp (Screens board): currencies, the way into the grove, arrows paid in meat and
## the shrine of the elder gods paid in spirit. Also recovers a run the OS killed mid-grove.

const GROVE_SCENE: String = "res://gameplay/run/grove_run.tscn"
const CAMP_SCENE: String = "res://ui/screens/main.tscn"
const PIPS: int = 5

var profile: Profile

@onready var _art: TextureRect = %Art
@onready var _meat_icon: TextureRect = %MeatIcon
@onready var _meat_label: Label = %MeatLabel
@onready var _spirit_icon: TextureRect = %SpiritIcon
@onready var _spirit_label: Label = %SpiritLabel
@onready var _enter_button: Button = %EnterButton
@onready var _arrows_paid: Label = %ArrowsPaid
@onready var _shrine_paid: Label = %ShrinePaid
@onready var _arrow_list: VBoxContainer = %ArrowList
@onready var _shrine_grid: GridContainer = %ShrineGrid
@onready var _theme_button: Button = %ThemeButton
@onready var _settings_screen: SettingsScreen = %Settings


func _ready() -> void:
	var data: Dictionary = Services.save.load_game()
	var saved_theme: StringName = StringName(str(data.get("theme_id", ThemeRegistry.DEFAULT_THEME_ID)))
	if saved_theme != ThemeRegistry.theme_id:
		ThemeRegistry.activate(saved_theme)
	var p: Variant = data.get("profile", {})
	var saved: Dictionary = p if p is Dictionary else {}
	profile = Profile.from_dict(saved)
	_recover_checkpoint(data)
	_art.texture = ThemeRegistry.screen_art(&"camp")
	_meat_icon.texture = ThemeRegistry.icon_for(Ids.MEAT)
	_spirit_icon.texture = ThemeRegistry.icon_for(Ids.SPIRIT)
	_spirit_label.add_theme_color_override(&"font_color", ThemeRegistry.color(&"spirit_jade"))
	_arrows_paid.text = tr(&"PAID_IN") % tr(&"CURRENCY_A_NAME").to_lower()
	_shrine_paid.text = tr(&"PAID_IN") % tr(&"CURRENCY_B_NAME").to_lower()
	_enter_button.text = tr(&"ENTER_GROVE")
	_enter_button.pressed.connect(_on_enter_pressed)
	_theme_button.pressed.connect(_settings_screen.open)
	_theme_button.text = tr(&"SETTINGS_TITLE")
	_settings_screen.closed.connect(func(reload: bool) -> void:
		if reload:
			SceneRouter.change_to(CAMP_SCENE))
	_refresh()
	UiSounds.wire(self)
	Services.audio.music_context(&"camp")
	Services.audio.ambience(&"", 0.0)
	_enter_button.grab_focus()


func _refresh() -> void:
	_meat_label.text = str(profile.meat)
	_spirit_label.text = str(profile.spirit)
	for c: Node in _arrow_list.get_children():
		c.queue_free()
	for c: Node in _shrine_grid.get_children():
		c.queue_free()
	for id: StringName in GameData.ARROWS:
		_arrow_list.add_child(_arrow_card(GameData.arrow(id)))
	for id: StringName in GameData.SHRINE:
		_shrine_grid.add_child(_shrine_card(GameData.shrine(id)))
	UiSounds.wire(_arrow_list)
	UiSounds.wire(_shrine_grid)


func _arrow_card(arrow: ArrowDef) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	card.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ThemeRegistry.texture_for(arrow.texture_id)
	icon.custom_minimum_size = Vector2(48, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", -2)
	row.add_child(text)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.text = tr(arrow.name_key)
	text.add_child(name_label)
	var desc: Label = Label.new()
	desc.theme_type_variation = &"MutedLabel"
	var key: StringName = &"ARROW_DESC_PIERCE" if arrow.pierce > 0 else (&"ARROW_DESC_TWIN" if arrow.twin_shot else &"ARROW_DESC")
	desc.text = tr(key) % arrow.damage
	text.add_child(desc)
	var action: Button = Button.new()
	action.custom_minimum_size = Vector2(84, 40)
	if profile.equipped_arrow == arrow.id:
		action.text = tr(&"EQUIPPED")
		action.theme_type_variation = &"SecondaryButton"
		action.disabled = true
	elif profile.owned_arrows.has(arrow.id):
		action.text = tr(&"EQUIP")
		action.theme_type_variation = &"SecondaryButton"
		action.pressed.connect(func() -> void: _equip(arrow))
	else:
		action.text = str(arrow.meat_cost)
		action.icon = ThemeRegistry.icon_for(Ids.MEAT)
		action.add_theme_constant_override(&"icon_max_width", 18)
		action.theme_type_variation = &"RewardButton"
		action.disabled = not profile.can_buy_arrow(arrow)
		action.pressed.connect(func() -> void: _buy(arrow))
	row.add_child(action)
	return card


func _shrine_card(shrine: ShrineDef) -> Control:
	var level: int = profile.shrine_level(shrine.id)
	var cost: int = shrine.cost_for(level)
	var card: Button = Button.new()
	card.theme_type_variation = &"CardButton"
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not profile.can_level(shrine)
	card.pressed.connect(func() -> void: _level_up(shrine))
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	card.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var icon: TextureRect = TextureRect.new()
	icon.texture = ThemeRegistry.icon_for(shrine.id)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var title: Label = Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = tr(ThemeRegistry.name_key_for(shrine.id))
	head.add_child(title)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override(&"separation", 4)
	box.add_child(foot)
	var jade: Color = ThemeRegistry.color(&"spirit_jade")
	for i: int in PIPS:
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = jade if i < level else Color(0.05, 0.03, 0.07, 0.8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(pip)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)
	var next: Label = Label.new()
	next.theme_type_variation = &"MutedLabel"
	next.text = tr(&"SHRINE_MAX") if cost < 0 else "%s %d" % [tr(&"SHRINE_NEXT"), cost]
	foot.add_child(next)
	card.tooltip_text = _shrine_effect(shrine)
	return card


func _shrine_effect(shrine: ShrineDef) -> String:
	match shrine.stat:
		ShrineDef.Stat.DAMAGE:
			return tr(&"SHRINE_DAMAGE") % roundi(shrine.per_level * 100.0)
		ShrineDef.Stat.HEALTH:
			return tr(&"SHRINE_HEALTH") % roundi(shrine.per_level)
		ShrineDef.Stat.SPEED:
			return tr(&"SHRINE_SPEED") % roundi(shrine.per_level * 100.0)
	return tr(&"SHRINE_LIGHT") % roundi(shrine.per_level * 100.0)


func _buy(arrow: ArrowDef) -> void:
	if profile.buy_arrow(arrow):
		Services.audio.play(&"ui.purchase")
		Services.analytics.log_event(&"arrow_bought", {"arrow": String(arrow.id), "cost": arrow.meat_cost})
		_save_and_refresh()
	else:
		Services.audio.play(&"ui.error")


func _equip(arrow: ArrowDef) -> void:
	if profile.equip_arrow(arrow.id):
		Services.audio.play(&"ui.confirm")
		_save_and_refresh()


func _level_up(shrine: ShrineDef) -> void:
	if profile.level_up(shrine):
		Services.audio.play(StringName("sfx.shrine.%s.purchase" % shrine.id))
		Services.analytics.log_event(&"shrine_levelled", {"god": String(shrine.id), "level": profile.shrine_level(shrine.id)})
		_save_and_refresh()


func _save_and_refresh() -> void:
	Services.save.set_value("profile", profile.to_dict())
	Services.save.save_game()
	_refresh()


## A run the OS killed mid-grove still banks what it carried at its last cleared room.
func _recover_checkpoint(data: Dictionary) -> void:
	var cp: Variant = data.get("run_checkpoint")
	if not cp is Dictionary:
		return
	var checkpoint: Dictionary = cp
	profile.meat += VarUtil.to_int(checkpoint.get("meat"))
	profile.spirit += VarUtil.to_int(checkpoint.get("spirit"))
	profile.best_grove = maxi(profile.best_grove, VarUtil.to_int(checkpoint.get("grove")))
	Services.save.set_value("run_checkpoint", null)
	Services.save.set_value("profile", profile.to_dict())
	Services.save.save_game()


func _on_enter_pressed() -> void:
	_enter_button.disabled = true
	Services.audio.play(&"ui.confirm")
	SceneRouter.change_to(GROVE_SCENE)
