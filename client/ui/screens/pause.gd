class_name PauseScreen
extends Control
## Pause menu (opened from the HUD, Android back, or when the app is backgrounded):
## resume, settings, or abandon the run (which banks it like a defeat).

signal resume_pressed
signal settings_pressed
signal abandon_pressed

@onready var _resume: Button = %ResumeButton
@onready var _settings: Button = %SettingsButton
@onready var _abandon: Button = %AbandonButton


func _ready() -> void:
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_abandon.pressed.connect(func() -> void: abandon_pressed.emit())
	UiSounds.wire(self)
	visible = false


func open() -> void:
	visible = true
	_resume.grab_focus()
