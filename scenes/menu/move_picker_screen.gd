class_name PUWMovePickerScreen
extends Control

## Move picker for the BW2 menu stack: the second step of the
## item-target flow for the two items that work on one chosen
## move — PP Up and PP Max (code prep code_prep_pp_max).
##
## The bag opens the party picker first (PUWPartyPickerScreen);
## when the picked item needs a move (PUWItemTarget.
## requires_move_choice), the host pushes this screen for the
## chosen mon instead of resolving. Each of the mon's moves is
## one button showing its current / max PP (and, for a move the
## item can still raise, the max PP one use would leave). A
## move already at its PP ceiling is greyed with the short
## reason, exactly as the party picker greys its targets; the
## verdicts come from PUWItemTarget.move_options /
## move_validity, which mirror the ItemEngine PP Up / PP Max
## arms — the screen itself decides nothing about effects.
##
## The screen PICKS; it never resolves. On a valid pick it
## emits move_chosen(move_name) and the host resolves through
## PUWItemTarget.use_on_mon(state, slug, slot, {"move": name}).
## On an invalid pick it plays ui_cancel, shows the refusal
## reason on the message strip, and emits move_refused — nothing
## is consumed either way. Back emits picker_cancelled; the
## host pops back to the party picker untouched.

signal move_chosen(move_name: String)
signal move_refused(move_name: String, reason: String)
signal picker_cancelled

var _state: Dictionary = {}
var _item_slug: String = ""
var _slot: int = -1
var _rows: Array = []  # PUWItemTarget.move_options rows
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
	_message_label = PUWUiTheme.make_label("Which move?", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
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


## Present the move step for one picked mon. Re-callable: the
## buttons are rebuilt from the live state every time.
func present_moves(state: Dictionary, item_slug: String, slot: int) -> void:
	_state = state
	_item_slug = item_slug
	_slot = slot
	_rows = PUWItemTarget.move_options(state, item_slug, slot)
	_rebuild_buttons()
	if _rows.is_empty():
		_message_label.text = "It has no moves with PP recorded."
		return
	_message_label.text = "Use the %s on which move?" % PUWLiveBag.display_name_for(item_slug)


func _rebuild_buttons() -> void:
	for b in _buttons:
		(b as Button).queue_free()
	_buttons.clear()
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var text: String = str(row.get("label", str(row.get("move", ""))))
		if bool(row.get("valid", false)):
			text += " -> %d" % int(row.get("new_pp_max", 0))
		else:
			text += " (%s)" % str(row.get("short", "Can't use"))
		var button: Button = PUWUiTheme.make_button(text)
		var idx: int = i
		button.pressed.connect(func() -> void: choose_move(idx))
		if not bool(row.get("valid", false)):
			button.disabled = true
			button.modulate = Color(0.55, 0.55, 0.6, 0.9)
		_list.add_child(button)
		_buttons.append(button)


## Single pick entry point (buttons route here; tests call it
## directly). Validity is recomputed against the live state at
## pick time, like the party picker's choose_slot.
func choose_move(index: int) -> void:
	if _state.is_empty() or index < 0 or index >= _rows.size():
		return
	var move_name: String = str((_rows[index] as Dictionary).get("move", ""))
	var v: Dictionary = PUWItemTarget.move_validity(_state, _item_slug, _slot, move_name)
	if not bool(v.get("valid", false)):
		PUWUiSound.play("ui_cancel")
		_message_label.text = str(v.get("reason_text", "It can't be used."))
		move_refused.emit(move_name, str(v.get("reason", "")))
		return
	PUWUiSound.play("ui_confirm")
	move_chosen.emit(move_name)


## Back / B: leave the move step without choosing. Nothing is
## consumed; the host pops back to the party picker.
func cancel() -> void:
	PUWUiSound.play("ui_cancel")
	picker_cancelled.emit()


func is_move_enabled(index: int) -> bool:
	if index < 0 or index >= _buttons.size():
		return false
	return not (_buttons[index] as Button).disabled


func move_short_reason(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	return str((_rows[index] as Dictionary).get("short", ""))


func move_label(index: int) -> String:
	if index < 0 or index >= _buttons.size():
		return ""
	return (_buttons[index] as Button).text


func message_text() -> String:
	return _message_label.text if _message_label != null else ""


func get_initial_focus_control() -> Control:
	for b in _buttons:
		var button: Button = b
		if button.visible and not button.disabled:
			return button
	return _back_button
