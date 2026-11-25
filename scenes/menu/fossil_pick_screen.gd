class_name PUWFossilPickScreen
extends Control

## Fossil pick for the BW2 menu stack (build6_remainders,
## build 6 remainder 5): the choice UI the Mt. Moon Super Nerd
## beat was missing. The game host's fossil seam was already
## wired — try_interact emits story_handoff("fossil_pick") and
## run_fossil_choice(pick) sets the ONE transient pick flag and
## runs data/events/mt_moon_fossil_choice.json — but nothing
## ever asked the player which fossil. This screen asks.
##
## Built on the PUWMovePickerScreen pattern (A-43): the screen
## PICKS; it never resolves. On a pick it emits
## fossil_chosen("dome" | "helix") and the menu host routes it
## to the game host's run_fossil_choice. Back emits
## picker_cancelled; no flag is set either way, so the beat
## simply re-offers on the next interact, exactly like the
## source (the Super Nerd keeps the unpicked fossil).

signal fossil_chosen(pick: String)
signal picker_cancelled

const PICKS: Array = [
	{"pick": "dome", "label": "Dome Fossil"},
	{"pick": "helix", "label": "Helix Fossil"},
]

var _buttons: Array = []
var _message_label: Label = null
var _list: VBoxContainer = null
var _back_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()


func _build() -> void:
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 12)
	add_child(root_box)
	var strip: PanelContainer = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	var strip_row: HBoxContainer = HBoxContainer.new()
	strip.add_child(strip_row)
	_message_label = PUWUiTheme.make_label("Which fossil?", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(_message_label)
	root_box.add_child(strip)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_list)
	_back_button = PUWUiTheme.make_button("Back")
	_back_button.pressed.connect(func() -> void: cancel())
	root_box.add_child(_back_button)


## Present the pick. Re-callable: the buttons are rebuilt
## every time, like the move picker's present_moves.
func present_pick() -> void:
	_rebuild_buttons()
	_message_label.text = "You can have one of these fossils. Which one?"


func _rebuild_buttons() -> void:
	for b in _buttons:
		(b as Button).queue_free()
	_buttons.clear()
	for i in PICKS.size():
		var row: Dictionary = PICKS[i]
		var button: Button = PUWUiTheme.make_button(str(row.get("label", "")))
		var idx: int = i
		button.pressed.connect(func() -> void: choose_pick(idx))
		_list.add_child(button)
		_buttons.append(button)


## Single pick entry point (buttons route here; tests call it
## directly).
func choose_pick(index: int) -> void:
	if index < 0 or index >= PICKS.size():
		return
	var pick: String = str((PICKS[index] as Dictionary).get("pick", ""))
	if pick == "":
		return
	PUWUiSound.play("ui_confirm")
	fossil_chosen.emit(pick)


## Back / B: leave without choosing. Nothing is consumed and
## no flag is set; the host pops back to the field.
func cancel() -> void:
	PUWUiSound.play("ui_cancel")
	picker_cancelled.emit()


func pick_label(index: int) -> String:
	if index < 0 or index >= _buttons.size():
		return ""
	return (_buttons[index] as Button).text


func pick_count() -> int:
	return _buttons.size()


func message_text() -> String:
	return _message_label.text if _message_label != null else ""


func get_initial_focus_control() -> Control:
	for b in _buttons:
		var button: Button = b
		if button.visible and not button.disabled:
			return button
	return _back_button
