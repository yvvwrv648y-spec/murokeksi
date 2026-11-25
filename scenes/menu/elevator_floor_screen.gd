class_name PUWElevatorFloorScreen
extends Control

## Elevator floor-select for the BW2 menu stack
## (build6_remainders, build 6 remainder 5): the choice UI
## the Silph Co. and Trainer Tower elevators were missing.
## Both elevator maps were bound with their floor-select
## bg_events (SilphCoElevator's TEXT_SILPHCOELEVATOR_ELEVATOR
## panel, TrainerTower_Elevator's FloorSelect script) but the
## A-51 amendment removed the elevators' own warps, so the
## panel had nothing behind it. This screen is what the panel
## opens.
##
## Data: data/elevator_floors.json (this production) — per
## building, the floors with a real elevator-door warp in the
## bound tree and that warp's 1-based index on the floor map.
## The screen PICKS; it never warps. On a pick it emits
## floor_chosen(map_name, door_warp_id) and the game host
## answers with change_map(map_name, door_warp_id), which
## spawns the player at that floor's elevator door
## (map_loader.spawn_tile_for is 1-based). The floor the
## player is already on is shown disabled, as in the source
## games. Back emits picker_cancelled and nothing moves.
##
## Trainer Tower note: 1F has no elevator-door warp in the
## bound tree and is not in the table — FRLG serves it from
## the Lobby stairs. Every listed floor has a real door warp.

signal floor_chosen(map_name: String, warp_id: int)
signal picker_cancelled

var _building: Dictionary = {}
var _floors: Array = []
var _current_map: String = ""
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
	_message_label = PUWUiTheme.make_label("Which floor?", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
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


## Present one building's floor list. building is one entry
## of elevator_floors.json's "buildings" ({id, label,
## elevator_map, floors}); current_map is the map the player
## is standing on (its button is disabled). Re-callable.
func present_floors(building: Dictionary, current_map: String) -> void:
	_building = building
	_current_map = current_map
	var floors_value: Variant = building.get("floors", [])
	_floors = floors_value if floors_value is Array else []
	_rebuild_buttons()
	_message_label.text = "%s elevator. Which floor?" % str(building.get("label", ""))


func _rebuild_buttons() -> void:
	for b in _buttons:
		(b as Button).queue_free()
	_buttons.clear()
	for i in _floors.size():
		var floor_row: Dictionary = _floors[i]
		var text: String = str(floor_row.get("label", ""))
		var button: Button = PUWUiTheme.make_button(text)
		var idx: int = i
		button.pressed.connect(func() -> void: choose_floor(idx))
		if str(floor_row.get("map", "")) == _current_map:
			button.disabled = true
			button.modulate = Color(0.55, 0.55, 0.6, 0.9)
			button.text = text + " (now)"
		_list.add_child(button)
		_buttons.append(button)


## Single pick entry point (buttons route here; tests call it
## directly). The pick is re-validated at pick time: the
## current floor and rows without a door warp never emit.
func choose_floor(index: int) -> void:
	if index < 0 or index >= _floors.size():
		return
	var floor_row: Dictionary = _floors[index]
	var map_name: String = str(floor_row.get("map", ""))
	var warp_id: int = int(floor_row.get("door_warp_id", -1))
	if map_name == "" or warp_id < 1 or map_name == _current_map:
		PUWUiSound.play("ui_cancel")
		return
	PUWUiSound.play("ui_confirm")
	floor_chosen.emit(map_name, warp_id)


## Back / B: stay on this floor. The host pops back to the
## field; no warp happens.
func cancel() -> void:
	PUWUiSound.play("ui_cancel")
	picker_cancelled.emit()


func floor_label(index: int) -> String:
	if index < 0 or index >= _buttons.size():
		return ""
	return (_buttons[index] as Button).text


func floor_count() -> int:
	return _buttons.size()


func is_floor_enabled(index: int) -> bool:
	if index < 0 or index >= _buttons.size():
		return false
	return not (_buttons[index] as Button).disabled


func message_text() -> String:
	return _message_label.text if _message_label != null else ""


func get_initial_focus_control() -> Control:
	for b in _buttons:
		var button: Button = b
		if button.visible and not button.disabled:
			return button
	return _back_button
