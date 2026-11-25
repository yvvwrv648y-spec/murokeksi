class_name PUWBattleScreen
extends Control
## Battle command UI (MENU_AUDIT_AND_REBUILD_SPEC §3.5) — a
## presentation re-skin only; battle logic stays in the working
## BattleScene/BattleController and binds to these named parts at
## adoption. Layout is BW2's, fixed: enemy info box top-left,
## player info box bottom-right above the command window, bright
## message window across the bottom, and the 2x2 command grid
## (FIGHT / BAG / POKEMON / RUN) in the dark panel at its right.
## FIGHT swaps in the 2x2 move grid: each move shows name, PP
## current/max, and a type chip in the type's color; focusing a
## move puts its detail card (power / accuracy / category, from
## the real move database) in the message window. The gimmick
## slot beside the move grid is reserved in layout and stays
## empty until the canon unlock flags allow (none in Kanto), so
## later regions never reflow the grid. The backdrop texture is
## a staging stand-in for the live 3D field the UI overlays.

signal command_chosen(command_id: String)
signal move_chosen(move_index: int)

var player_mon: Dictionary = {
	"name": "Pikachu", "level": 24, "hp": 58, "max_hp": 64, "exp_frac": 0.62,
	"status": "", "sprite": "res://art/sprites/0025_pikachu_back.png",
	"moves": [
		{"name": "Thunder Shock", "pp": 30},
		{"name": "Quick Attack", "pp": 30},
		{"name": "Thunderbolt", "pp": 15},
		{"name": "Tail Whip", "pp": 30},
	],
}
var enemy_mon: Dictionary = {
	"name": "Charizard", "level": 26, "hp": 62, "max_hp": 86,
	"status": "", "sprite": "res://art/sprites/0006_charizard_front.png",
}

var _move_data: Dictionary = {}
var _state: String = "command"
var _message_label: Label = null
var _command_box: VBoxContainer = null
var _fight_button: Button = null
var _move_buttons: Array[Button] = []
var _default_message: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_load_move_data()
	_default_message = "What will " + str(player_mon.get("name", "your Pokémon")) + " do?"
	_build()
	set_state("command")


func _load_move_data() -> void:
	var path: String = "res://data/move_database_954.json"
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_move_data = (parsed as Dictionary).get("moves", {})


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = PUWUiTheme.tex("res://art/ui/battle_backdrop.png")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# Sprites standing on the backdrop's platforms.
	var enemy_sprite := TextureRect.new()
	enemy_sprite.texture = PUWUiTheme.tex(str(enemy_mon.get("sprite", "")))
	enemy_sprite.position = Vector2(820, 168)
	enemy_sprite.size = Vector2(230, 230)
	enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_sprite)
	var player_sprite := TextureRect.new()
	player_sprite.texture = PUWUiTheme.tex(str(player_mon.get("sprite", "")))
	player_sprite.position = Vector2(185, 330)
	player_sprite.size = Vector2(270, 270)
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_sprite)

	add_child(_make_info_box(enemy_mon, false))
	add_child(_make_info_box(player_mon, true))

	# Bottom zone: bright message window + dark command panel.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -168
	bottom.offset_bottom = -20
	bottom.add_theme_constant_override("separation", 14)
	add_child(bottom)

	var message_panel := PanelContainer.new()
	message_panel.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(message_panel)
	var message_row := HBoxContainer.new()
	message_panel.add_child(message_row)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_row.add_child(_message_label)
	var arrow := TextureRect.new()
	arrow.texture = PUWUiTheme.tex("res://art/ui/advance_arrow.png")
	arrow.custom_minimum_size = Vector2(24, 24)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.size_flags_vertical = Control.SIZE_SHRINK_END
	message_row.add_child(arrow)

	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size = Vector2(452, 0)
	command_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	bottom.add_child(command_panel)
	_command_box = VBoxContainer.new()
	_command_box.add_theme_constant_override("separation", 8)
	command_panel.add_child(_command_box)


func _make_info_box(mon: Dictionary, is_player: bool) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	if is_player:
		box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		box.offset_left = -448
		box.offset_top = -300
		box.offset_right = -28
		box.offset_bottom = -184
	else:
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.offset_left = 28
		box.offset_top = 28
		box.offset_right = 448
		box.offset_bottom = 128
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	box.add_child(vbox)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	var name_label: Label = PUWUiTheme.make_label(str(mon.get("name", "")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var status: String = str(mon.get("status", ""))
	var chip_data: Dictionary = PUWUiTheme.status_chip(status)
	if not chip_data.is_empty():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", PUWUiTheme.chip_style(chip_data.get("color", PUWUiTheme.PANEL_LIGHT) as Color, 8))
		chip.add_child(PUWUiTheme.make_label(str(chip_data.get("text", "")), PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT, true))
		top.add_child(chip)
	top.add_child(PUWUiTheme.make_label("Lv " + str(mon.get("level", 1)), PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM))
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 14)
	hp_bar.show_percentage = false
	PUWUiTheme.update_hp_bar(hp_bar, int(mon.get("hp", 0)), int(mon.get("max_hp", 1)))
	vbox.add_child(hp_bar)
	if is_player:
		var hp_label: Label = PUWUiTheme.make_label(str(mon.get("hp", 0)) + " / " + str(mon.get("max_hp", 1)), PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(hp_label)
		var exp_bar := ProgressBar.new()
		exp_bar.custom_minimum_size = Vector2(0, 8)
		exp_bar.show_percentage = false
		PUWUiTheme.update_exp_bar(exp_bar, float(mon.get("exp_frac", 0.0)))
		vbox.add_child(exp_bar)
	return box


func set_state(state: String) -> void:
	_state = state
	for child in _command_box.get_children():
		_command_box.remove_child(child)
		child.free()
	_move_buttons.clear()
	if state == "command":
		_message_label.text = _default_message
		_build_command_grid()
	else:
		_build_move_grid()
		_show_move_detail(0)


func _build_command_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_command_box.add_child(grid)
	for command_value in ["FIGHT", "BAG", "POKÉMON", "RUN"]:
		var command_id: String = command_value
		var button: Button = PUWUiTheme.make_button(command_id, Vector2(196, 62))
		button.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
		button.pressed.connect(func() -> void: _on_command_pressed(command_id))
		grid.add_child(button)
		if command_id == "FIGHT":
			_fight_button = button


func _on_command_pressed(command_id: String) -> void:
	PUWUiSound.play("ui_confirm")
	if command_id == "FIGHT":
		set_state("moves")
		if not _move_buttons.is_empty():
			_move_buttons[0].grab_focus()
		return
	command_chosen.emit(command_id.to_lower())


func _build_move_grid() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_command_box.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(grid)
	var moves: Array = player_mon.get("moves", [])
	for i in 4:
		var button: Button = _make_move_button(i, moves)
		grid.add_child(button)
		_move_buttons.append(button)
	# Reserved gimmick slot + Back, in a side column (§3.5).
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	var gimmick_slot := PanelContainer.new()
	gimmick_slot.custom_minimum_size = Vector2(64, 62)
	gimmick_slot.add_theme_stylebox_override("panel", PUWUiTheme._flat(Color(0, 0, 0, 0.25), PUWUiTheme.TEXT_DIM.darkened(0.3), 8, 1))
	var gimmick_label: Label = PUWUiTheme.make_label("—", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM)
	gimmick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gimmick_slot.add_child(gimmick_label)
	gimmick_slot.tooltip_text = "Gimmick slot — unlocks with the region's gimmick (none in Kanto)."
	side.add_child(gimmick_slot)
	var back_button: Button = PUWUiTheme.make_button("Back", Vector2(64, 62))
	back_button.pressed.connect(func() -> void:
		PUWUiSound.play("ui_cancel")
		set_state("command")
		if _fight_button != null:
			_fight_button.grab_focus()
	)
	side.add_child(back_button)


func _make_move_button(index: int, moves: Array) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(168, 62)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT, Color(0, 0, 0, 0), 8, 0))
	button.add_theme_stylebox_override("hover", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT.lightened(0.08), Color(0, 0, 0, 0), 8, 0))
	button.add_theme_stylebox_override("pressed", PUWUiTheme._flat(PUWUiTheme.ACCENT.darkened(0.35), Color(0, 0, 0, 0), 8, 0))
	button.add_theme_stylebox_override("focus", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT, PUWUiTheme.ACCENT, 8, 2))
	button.add_theme_stylebox_override("disabled", PUWUiTheme._flat(PUWUiTheme.PANEL, Color(0, 0, 0, 0), 8, 0))
	if index >= moves.size():
		button.text = "—"
		button.disabled = true
		return button
	var move: Dictionary = moves[index]
	var move_name: String = str(move.get("name", ""))
	var data: Dictionary = _move_data.get(move_name, {})
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var name_label: Label = PUWUiTheme.make_label(move_name, PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT, true)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)
	var type_name: String = str(data.get("type", "Normal"))
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", PUWUiTheme.chip_style(PUWUiTheme.type_color(type_name), 6))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_label: Label = PUWUiTheme.make_label(type_name.to_upper(), PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT, true)
	chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_label)
	meta.add_child(chip)
	var pp_max: int = int(data.get("base_pp", data.get("pp", 0)))
	var pp_label: Label = PUWUiTheme.make_label("PP " + str(move.get("pp", pp_max)) + "/" + str(pp_max), PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM)
	pp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(pp_label)
	button.focus_entered.connect(func() -> void:
		PUWUiSound.play("ui_cursor")
		_show_move_detail(index)
	)
	button.pressed.connect(func() -> void:
		PUWUiSound.play("ui_confirm")
		move_chosen.emit(index)
	)
	return button


func _show_move_detail(index: int) -> void:
	var moves: Array = player_mon.get("moves", [])
	if index < 0 or index >= moves.size():
		return
	var move: Dictionary = moves[index]
	var data: Dictionary = _move_data.get(str(move.get("name", "")), {})
	if data.is_empty():
		_message_label.text = str(move.get("name", ""))
		return
	var power_text: String = str(int(data.get("power", 0)))
	if int(data.get("power", 0)) <= 0:
		power_text = "—"
	var acc_text: String = str(int(data.get("acc", 0)))
	if bool(data.get("always_hits", false)):
		acc_text = "—"
	_message_label.text = str(move.get("name", "")) + "  ·  Power " + power_text + "  ·  Accuracy " + acc_text + "  ·  " + str(data.get("cat", ""))


func get_initial_focus_control() -> Control:
	if _state == "moves" and not _move_buttons.is_empty():
		return _move_buttons[0]
	return _fight_button
