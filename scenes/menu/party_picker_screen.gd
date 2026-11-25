class_name PUWPartyPickerScreen
extends PUWPartyScreen

## Party target picker for the BW2 menu stack: the screen the bag's Use and
## Give actions open when an item needs a target Pokémon.
##
## It reuses PUWPartyScreen's rendering wholesale (lead panel + five rows +
## bright message strip). The base screen's row/lead presses call
## open_action_panel(slot); this subclass overrides that single method to
## route presses to choose_slot() instead, so the action sub-panel never
## opens and no connection rewiring is needed. The demo party is never
## shown: _ready() deliberately does not call super._ready() (which fills
## demo_party() when party is empty) — the picker only ever displays the
## real party from PUWItemTarget.rows_for_screen(state).
##
## The screen PICKS; it never resolves. On a valid pick it emits
## target_chosen(slot) and the host resolves through PUWItemTarget and
## reports back through the bag. On an invalid pick it plays ui_cancel,
## shows the refusal reason on the message strip, and emits
## target_refused(slot, reason) — nothing is consumed either way. Back /
## B (close_requested from the base screen) is re-emitted as
## picker_cancelled; the host pops back to the bag untouched.

signal target_chosen(slot: int)
signal target_refused(slot: int, reason: String)
signal picker_cancelled

var _state: Dictionary = {}
var _action: String = "use"
var _item_slug: String = ""
var _context: Dictionary = {}
var _validity: Dictionary = {}  # slot -> PUWItemTarget.target_validity result


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	party = []
	_build()
	close_requested.connect(func() -> void: picker_cancelled.emit())


## Present the picker for one bag action. action: "use" | "give" | "take"
## (take carries no item; item_slug is ""). Re-callable: all grey-outs from
## a previous presentation are reset first.
func present_target(state: Dictionary, action: String, item_slug: String, context: Dictionary = {}) -> void:
	_state = state
	_action = action
	_item_slug = item_slug
	_context = context
	_validity.clear()
	party = PUWItemTarget.rows_for_screen(state)
	refresh()
	_reset_slot_visuals()
	if party.is_empty():
		_message_label.text = "There are no Pokémon."
		return
	for i in party.size():
		var v: Dictionary = PUWItemTarget.target_validity(state, action, item_slug, i, context)
		_validity[i] = v
		if not bool(v.get("valid", false)):
			_apply_invalid_visual(i, str(v.get("short", "Can't use")))
	match action:
		"give":
			_message_label.text = "Give the %s to which Pokémon?" % PUWLiveBag.display_name_for(item_slug)
		"take":
			_message_label.text = "Take an item from which Pokémon?"
		_:
			_message_label.text = "Use %s on which Pokémon?" % PUWLiveBag.display_name_for(item_slug)


func _reset_slot_visuals() -> void:
	if _lead_button != null:
		_lead_button.disabled = false
		_lead_button.modulate = Color.WHITE
		_remove_reason_labels(_lead_button.get_child(0) as Container)
	for row in _rows:
		(row as Button).disabled = false
		(row as Button).modulate = Color.WHITE
		_remove_reason_labels((row as Button).get_node("Box") as Container)


func _remove_reason_labels(box: Container) -> void:
	if box == null:
		return
	for child in box.get_children():
		if child.name == "PickerReason":
			child.queue_free()


func _apply_invalid_visual(slot: int, short: String) -> void:
	var label: Label = PUWUiTheme.make_label(short, PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM, true)
	label.name = "PickerReason"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot == 0:
		_lead_button.disabled = true
		_lead_button.modulate = Color(0.55, 0.55, 0.6, 0.9)
		if _lead_sprite != null:
			_lead_sprite.modulate = Color(0.5, 0.5, 0.55, 0.9)
		(_lead_button.get_child(0) as Container).add_child(label)
	else:
		var row: Button = _rows[slot - 1]
		row.disabled = true
		row.modulate = Color(0.55, 0.55, 0.6, 0.9)
		(row.get_node("Box") as Container).add_child(label)


## The base screen's press route, overridden: a press is a pick.
func open_action_panel(slot: int) -> void:
	choose_slot(slot)


## Single pick entry point (buttons route here; tests call it directly).
## Validity is recomputed against the live state at pick time.
func choose_slot(slot: int) -> void:
	if _state.is_empty():
		return
	var v: Dictionary = PUWItemTarget.target_validity(_state, _action, _item_slug, slot, _context)
	if not bool(v.get("valid", false)):
		PUWUiSound.play("ui_cancel")
		_message_label.text = str(v.get("reason_text", "It can't be used."))
		target_refused.emit(slot, str(v.get("reason", "")))
		return
	PUWUiSound.play("ui_confirm")
	target_chosen.emit(slot)


func is_slot_enabled(slot: int) -> bool:
	if slot == 0:
		return _lead_button != null and not _lead_button.disabled
	if slot - 1 < _rows.size():
		return not (_rows[slot - 1] as Button).disabled
	return false


func slot_short_reason(slot: int) -> String:
	var v = _validity.get(slot, {})
	if v is Dictionary:
		return str((v as Dictionary).get("short", ""))
	return ""


func get_initial_focus_control() -> Control:
	if _lead_button != null and not _lead_button.disabled:
		return _lead_button
	for row in _rows:
		var b: Button = row
		if b.visible and not b.disabled:
			return b
	return _lead_button
