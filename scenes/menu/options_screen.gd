class_name PUWOptionsScreen
extends Control
## Options / settings screen (ui_screens production).
##
## The bound tree's settings were a stub shell with no values
## (ChallengeAndAudioSettingsController) and the audio prep
## graded audio settings "Unwired". This screen is the UI over
## the real model, PUWGameSettings (patched/systems/settings/):
## settings live in the save state under the additive
## "settings" key, so changes persist through the real save
## flow, and every control applies immediately:
##
##   Text Speed       cycles Slow/Mid/Fast in the state; the
##                    dialogue box reads the rate through
##                    PUWGameSettings.text_speed_cps(state).
##   Music / SFX      toggles applied to the AudioServer buses
##                    at once via PUWGameSettings.apply_audio()
##                    (buses by name; the result dict is shown
##                    honestly when a bus does not exist yet).
##   Battle Animation On/Off in the state;
##                    PUWGameSettings.animations_enabled(state)
##                    is the playback contract build 5/6's
##                    playback entry points check.
##
## Every change emits settings_changed with a copy of the new
## settings dict. Rows are single wide buttons (label + value),
## the bag screen's full-row idiom: one press = one change,
## every button traced to the handler named beside it.

signal close_requested
signal settings_changed(settings: Dictionary)

var _state: Dictionary = {}
var _built: bool = false

var _back_button: Button = null
var _text_speed_button: Button = null
var _music_button: Button = null
var _sfx_button: Button = null
var _animation_button: Button = null
var _message_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()
	refresh()


func bind_state(state: Dictionary) -> void:
	_state = state
	PUWGameSettings.ensure_settings(_state)
	PUWGameSettings.apply_audio(_state)
	refresh()


func settings() -> Dictionary:
	return PUWGameSettings.get_settings(_state)


func cycle_text_speed() -> void:
	var current: String = PUWGameSettings.text_speed(_state)
	PUWGameSettings.set_value(_state, "text_speed", PUWGameSettings.next_text_speed(current))
	_changed("Text speed: " + PUWGameSettings.text_speed(_state).capitalize() + ".")


func toggle_music() -> void:
	PUWGameSettings.set_value(_state, "music_on", not PUWGameSettings.music_on(_state))
	var applied: Dictionary = PUWGameSettings.apply_audio(_state)
	if bool(applied.get("music_applied", false)):
		_changed("Music " + _on_off(PUWGameSettings.music_on(_state)) + ".")
	else:
		_changed("Music " + _on_off(PUWGameSettings.music_on(_state)) + " (saved; no Music bus in this build yet).")


func toggle_sfx() -> void:
	PUWGameSettings.set_value(_state, "sfx_on", not PUWGameSettings.sfx_on(_state))
	var applied: Dictionary = PUWGameSettings.apply_audio(_state)
	if bool(applied.get("sfx_applied", false)):
		_changed("Sound effects " + _on_off(PUWGameSettings.sfx_on(_state)) + ".")
	else:
		_changed("Sound effects " + _on_off(PUWGameSettings.sfx_on(_state)) + " (saved; no SFX bus in this build yet).")


func toggle_battle_animation() -> void:
	var next_value: bool = not PUWGameSettings.animations_enabled(_state)
	PUWGameSettings.set_value(_state, "battle_animation", next_value)
	_changed("Battle animation " + _on_off(next_value) + ".")


func _changed(message: String) -> void:
	_set_message(message)
	PUWUiSound.play("ui_confirm")
	settings_changed.emit(settings())
	refresh()


func _on_off(value: bool) -> String:
	return "On" if value else "Off"


func _build() -> void:
	_built = true
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(56, 56)
	_back_button.icon = PUWUiTheme.tex("res://art/ui/back_chevron.png")
	_back_button.expand_icon = true
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(_back_button)
	header.add_child(PUWUiTheme.make_label("OPTIONS", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	root.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	_text_speed_button = _make_row(rows, func() -> void: cycle_text_speed())
	_music_button = _make_row(rows, func() -> void: toggle_music())
	_sfx_button = _make_row(rows, func() -> void: toggle_sfx())
	_animation_button = _make_row(rows, func() -> void: toggle_battle_animation())

	root.add_child(PUWUiTheme.make_label("Settings are saved with your game.", PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM))

	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	strip.add_child(_message_label)


func _make_row(parent: Container, handler: Callable) -> Button:
	var row: Button = PUWUiTheme.make_button("", Vector2(0, 64))
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.pressed.connect(handler)
	row.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
	parent.add_child(row)
	return row


func refresh() -> void:
	if not _built:
		return
	var current: Dictionary = settings()
	_text_speed_button.text = "Text Speed:  " + str(current.get("text_speed", "mid")).capitalize()
	_music_button.text = "Music:  " + _on_off(bool(current.get("music_on", true)))
	_sfx_button.text = "Sound Effects:  " + _on_off(bool(current.get("sfx_on", true)))
	_animation_button.text = "Battle Animation:  " + _on_off(bool(current.get("battle_animation", true)))


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func message_text() -> String:
	if _message_label == null:
		return ""
	return _message_label.text


func get_initial_focus_control() -> Control:
	return _text_speed_button
