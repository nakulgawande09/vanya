class_name DefeatScreen
extends Control
## "The blight took you" (Screens board): run summary, what is carried home, a rewarded-ad revive
## (once per grove) and the way back to camp.

signal revive_pressed
signal camp_pressed

@onready var _art: TextureRect = %Art
@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _meat_icon: TextureRect = %MeatIcon
@onready var _meat: Label = %MeatGain
@onready var _spirit_icon: TextureRect = %SpiritIcon
@onready var _spirit: Label = %SpiritGain
@onready var _revive: Button = %ReviveButton
@onready var _caption: Label = %ReviveCaption
@onready var _camp: Button = %CampButton


func _ready() -> void:
	_art.texture = ThemeRegistry.screen_art(&"defeat")
	_meat_icon.texture = ThemeRegistry.icon_for(Ids.MEAT)
	_spirit_icon.texture = ThemeRegistry.icon_for(Ids.SPIRIT)
	_spirit.add_theme_color_override(&"font_color", ThemeRegistry.color(&"spirit_jade"))
	_revive.pressed.connect(func() -> void: revive_pressed.emit())
	_camp.pressed.connect(func() -> void: camp_pressed.emit())
	UiSounds.wire(self)


func show_summary(run: RunState, can_revive: bool) -> void:
	_title.text = tr(&"DEFEAT_TITLE")
	_summary.text = tr(&"DEFEAT_SUMMARY") % [run.grove, run.kills, run.animals_freed]
	_meat.text = "+%d" % run.meat
	_spirit.text = "+%d" % run.spirit
	_revive.disabled = not can_revive or not Services.ads.is_rewarded_ready()
	_caption.text = tr(&"REVIVE_CAPTION")
	visible = true
	_revive.grab_focus() if not _revive.disabled else _camp.grab_focus()
