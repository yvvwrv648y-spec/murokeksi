class_name PUWFerryMenuScreen
extends Control

## Ferry destination menu for the BW2 menu stack
## (build6_remainders, build 6 remainder 5): the choice UI the
## Sevii ferry beat was missing. The game host's ferry seam
## was already wired — a ferry sailor's interact derives the
## pass tier from the live bag (ferry_options) and emits
## story_handoff("ferry_menu", options), and run_ferry(origin,
## dest) sets the ONE ferry_dest_* flag and runs the origin's
## sailing script with the route's Seagallop number — but
## nothing ever showed the destination list. This screen
## shows it.
##
## Built on the PUWMovePickerScreen pattern (A-43): the
## screen PICKS; it never resolves. It renders exactly the
## destinations the host's wiring matrix offered for this
## origin + tier (data/sevii_ferry_wiring.json, read by the
## host, never by the screen) and emits ferry_chosen(origin,
## dest) with the raw destination slug run_ferry expects.
## Display names are presentation only. Back emits
## picker_cancelled; no flag is set either way.

signal ferry_chosen(origin: String, dest: String)
signal picker_cancelled

const DISPLAY_NAMES: Dictionary = {
	"one_island": "One Island",
	"two_island": "Two Island",
	"three_island": "Three Island",
	"four_island": "Four Island",
	"five_island": "Five Island",
	"six_island": "Six Island",
	"seven_island": "Seven Island",
	"vermilion": "Vermilion City",
	"navel_rock": "Navel Rock",
	"birth_island": "Birth Island",
}

var _origin: String = ""
var _tier: String = ""
var _destinations: Array = []
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
	_message_label = PUWUiTheme.make_label("Where to?", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
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


static func display_name_for(slug: String) -> String:
	return str(DISPLAY_NAMES.get(slug, slug))


## Present the destination list for one ferry_options()
## hand-off ({origin, tier, destinations}). Re-callable: the
## buttons are rebuilt from the offered options every time.
func present_options(options: Dictionary) -> void:
	_origin = str(options.get("origin", ""))
	_tier = str(options.get("tier", ""))
	var dest_value: Variant = options.get("destinations", [])
	_destinations = dest_value if dest_value is Array else []
	_rebuild_buttons()
	if _destinations.is_empty():
		_message_label.text = "No ferry can sail from here yet."
		return
	var pass_name: String = "Rainbow Pass" if _tier == "rainbow_pass" else "Tri-Pass"
	_message_label.text = "Seagallop ferry from %s (%s). Where to?" % [
		display_name_for(_origin), pass_name]


func _rebuild_buttons() -> void:
	for b in _buttons:
		(b as Button).queue_free()
	_buttons.clear()
	for i in _destinations.size():
		var dest: String = str(_destinations[i])
		var button: Button = PUWUiTheme.make_button(display_name_for(dest))
		var idx: int = i
		button.pressed.connect(func() -> void: choose_destination(idx))
		_list.add_child(button)
		_buttons.append(button)


## Single pick entry point (buttons route here; tests call it
## directly). The destination is re-validated against the
## offered list at pick time, like the move picker's
## choose_move.
func choose_destination(index: int) -> void:
	if _origin == "" or index < 0 or index >= _destinations.size():
		return
	var dest: String = str(_destinations[index])
	if dest == "" or dest == _origin:
		PUWUiSound.play("ui_cancel")
		return
	PUWUiSound.play("ui_confirm")
	ferry_chosen.emit(_origin, dest)


## Back / B: leave without sailing. No ferry_dest_* flag is
## set; the host pops back to the field.
func cancel() -> void:
	PUWUiSound.play("ui_cancel")
	picker_cancelled.emit()


func destination_label(index: int) -> String:
	if index < 0 or index >= _buttons.size():
		return ""
	return (_buttons[index] as Button).text


func destination_count() -> int:
	return _buttons.size()


func origin() -> String:
	return _origin


func message_text() -> String:
	return _message_label.text if _message_label != null else ""


func get_initial_focus_control() -> Control:
	for b in _buttons:
		var button: Button = b
		if button.visible and not button.disabled:
			return button
	return _back_button
