class_name PUWXMenuScreen
extends Control
## X-menu (MENU_AUDIT_AND_REBUILD_SPEC §3.1). Centered dark panel,
## header strip carrying trainer state (name / time / badges /
## money — the BW2 X-menu carries trainer state), a 3x2 grid of
## icon-chip entries plus a full-width Challenge Rules row, footer
## hint line, and an on-screen Close button (touch parity with B).
## Entries emit entry_chosen(id); the host routes that to the menu
## stack. Selection = focus: accent border + 1.04 pop (§3.0 grids),
## and every focus move plays ui_cursor.

signal entry_chosen(entry_id: String)
signal close_requested

const ENTRIES: Array = [
	{"id": "party", "label": "Party", "icon": "res://art/icons/x_party.png"},
	{"id": "bag", "label": "Bag", "icon": "res://art/icons/x_bag.png"},
	{"id": "dex", "label": "Pokédex", "icon": "res://art/icons/x_dex.png"},
	{"id": "map", "label": "Map", "icon": "res://art/icons/x_map.png"},
	{"id": "settings", "label": "Settings", "icon": "res://art/icons/x_settings.png"},
	{"id": "save", "label": "Save", "icon": "res://art/icons/x_save.png"},
]

## Header trainer state. bind_state() feeds it from the live
## save state (name / badge count / money — binding build 6,
## code prep code_prep_live_bag); unbound it keeps these demo
## values for panel probes. The save state carries no play
## clock, so bind_state() erases "time" and the header omits
## the segment rather than showing a staged time.
var trainer: Dictionary = {
	"name": "Riley", "time": "12:47", "badges": 3, "money": 12480,
}

var _cells: Array[Button] = []
var _first_cell: Button = null
var _state_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 540)
	panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	# Header strip: title + trainer state.
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", PUWUiTheme.header_style())
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header.add_child(header_row)
	header_row.add_child(PUWUiTheme.make_label("MENU", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	_state_label = PUWUiTheme.make_label(_state_text(), PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	header_row.add_child(_state_label)

	# 3x2 entry grid.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	root.add_child(grid)
	for entry_value in ENTRIES:
		var entry: Dictionary = entry_value
		var cell: Button = _make_cell(entry)
		grid.add_child(cell)
		_cells.append(cell)
		if _first_cell == null:
			_first_cell = cell

	# Full-width Challenge Rules row (horizontal cell: chip + label).
	var challenge: Button = _make_cell({"id": "challenge", "label": "Challenge Rules", "icon": "res://art/icons/x_challenge.png"}, true)
	challenge.custom_minimum_size = Vector2(0, 76)
	root.add_child(challenge)
	_cells.append(challenge)

	# Footer: hint line + on-screen Close (touch).
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	footer.add_child(PUWUiTheme.make_label("B: Close  ·  Confirm: Open", PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM))
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var close_button: Button = PUWUiTheme.make_button("Close", Vector2(140, 56))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	footer.add_child(close_button)

	_wire_focus_neighbours()


func _make_cell(entry: Dictionary, wide: bool = false) -> Button:
	var entry_id: String = str(entry.get("id", ""))
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(216, 118)
	cell.focus_mode = Control.FOCUS_ALL
	cell.add_theme_stylebox_override("normal", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT, Color(0, 0, 0, 0), 10, 0))
	cell.add_theme_stylebox_override("hover", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT.lightened(0.08), Color(0, 0, 0, 0), 10, 0))
	cell.add_theme_stylebox_override("pressed", PUWUiTheme._flat(PUWUiTheme.ACCENT.darkened(0.35), Color(0, 0, 0, 0), 10, 0))
	cell.add_theme_stylebox_override("focus", PUWUiTheme._flat(Color(0, 0, 0, 0), PUWUiTheme.ACCENT, 10, 3))
	var box: BoxContainer
	if wide:
		box = HBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		box = VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(56, 56) if wide else Vector2(64, 64)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_color: Color = PUWUiTheme.CHIP_COLORS.get(entry_id, PUWUiTheme.PANEL_LIGHT)
	chip.add_theme_stylebox_override("panel", PUWUiTheme.chip_style(chip_color, 12))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chip)
	var icon := TextureRect.new()
	icon.texture = PUWUiTheme.tex(str(entry.get("icon", "")))
	icon.custom_minimum_size = Vector2(40, 40) if wide else Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var label: Label = PUWUiTheme.make_label(str(entry.get("label", "")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	cell.pressed.connect(func() -> void:
		PUWUiSound.play("ui_confirm")
		entry_chosen.emit(entry_id)
	)
	cell.focus_entered.connect(func() -> void:
		PUWUiSound.play("ui_cursor")
		PUWMenuTransitions.focus_pop(self, cell, true)
	)
	cell.focus_exited.connect(func() -> void:
		PUWMenuTransitions.focus_pop(self, cell, false)
	)
	return cell


func _wire_focus_neighbours() -> void:
	# Grid order: 0 1 2 / 3 4 5, then 6 = challenge row, full width.
	for i in _cells.size():
		var cell: Button = _cells[i]
		if i < 6:
			var col: int = i % 3
			var row: int = i / 3
			cell.focus_neighbor_left = _cells[row * 3 + ((col + 2) % 3)].get_path()
			cell.focus_neighbor_right = _cells[row * 3 + ((col + 1) % 3)].get_path()
			if row == 0:
				cell.focus_neighbor_top = _cells[i + 3].get_path()
				cell.focus_neighbor_bottom = _cells[i + 3].get_path()
			else:
				cell.focus_neighbor_top = _cells[i - 3].get_path()
				cell.focus_neighbor_bottom = _cells[6].get_path()
		else:
			cell.focus_neighbor_top = _cells[4].get_path()
			cell.focus_neighbor_bottom = _cells[1].get_path()
			cell.focus_neighbor_left = _cells[6].get_path()
			cell.focus_neighbor_right = _cells[6].get_path()


## The header's state line: name, then the time segment only
## when a time is actually known, then badges and money.
func _state_text() -> String:
	var text: String = str(trainer.get("name", "Trainer"))
	if trainer.has("time"):
		text += "   ·   " + str(trainer.get("time", "0:00"))
	text += "   ·   Badges: " + str(trainer.get("badges", 0))
	text += "   ·   " + PUWUiTheme.format_money(int(trainer.get("money", 0)))
	return text


## Feed the header from a live save state: the player's name
## (state["player"]["name"]), the badge count (the size of
## state["badges"], the same list the gym rules read) and
## state["money"]. Safe before or after _ready.
func bind_state(state: Dictionary) -> void:
	var player_value: Variant = state.get("player", {})
	if player_value is Dictionary:
		var player: Dictionary = player_value
		var player_name: String = str(player.get("name", ""))
		if player_name != "":
			trainer["name"] = player_name
	var badges_value: Variant = state.get("badges", [])
	if badges_value is Array:
		var badges: Array = badges_value
		trainer["badges"] = badges.size()
	trainer["money"] = int(state.get("money", int(trainer.get("money", 0))))
	trainer.erase("time")
	_refresh_state_label()


func _refresh_state_label() -> void:
	if _state_label != null:
		_state_label.text = _state_text()


func get_initial_focus_control() -> Control:
	return _first_cell
