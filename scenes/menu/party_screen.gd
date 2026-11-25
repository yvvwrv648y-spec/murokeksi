class_name PUWPartyScreen
extends Control
## Party screen (MENU_AUDIT_AND_REBUILD_SPEC §3.2). BW2 arrangement:
## lead Pokemon large on the left (sprite on a platform disc, name,
## level, held item, HP bar with numbers, EXP bar, status chip),
## five compact 72 px rows on the right, and a bright dialogue-style
## message strip along the bottom. Picking a row opens the action
## sub-panel (Summary / Switch / Item / Care / Close) anchored to
## the bottom-right; the host stack-pushes it in the real game, here
## it is an in-screen panel so B pops it first. Fainted is a
## first-class visual: desaturated sprite + FAINTED chip, with the
## permadeath ledger state in a darker red than a battle faint.

signal close_requested
signal action_chosen(action_id: String, slot: int)

var party: Array = []

var _lead_button: Button = null
var _lead_sprite: TextureRect = null
var _lead_name: Label = null
var _lead_meta: Label = null
var _lead_hp_bar: ProgressBar = null
var _lead_hp_label: Label = null
var _lead_exp_bar: ProgressBar = null
var _lead_chip: PanelContainer = null
var _lead_chip_label: Label = null
var _rows: Array[Button] = []
var _message_label: Label = null
var _action_panel: PanelContainer = null
var _action_first: Button = null
var _action_slot: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	if party.is_empty():
		party = demo_party()
	_build()
	refresh()


static func demo_party() -> Array:
	return [
		{"name": "Pikachu", "level": 24, "hp": 58, "max_hp": 64, "exp_frac": 0.62,
			"status": "", "held_item": "Light Ball",
			"icon": "res://art/icons/0025_pikachu_icon.png", "sprite": "res://art/sprites/0025_pikachu_front.png"},
		{"name": "Charizard", "level": 23, "hp": 71, "max_hp": 78, "exp_frac": 0.31,
			"status": "", "held_item": "",
			"icon": "res://art/icons/0006_charizard_icon.png", "sprite": "res://art/sprites/0006_charizard_front.png"},
		{"name": "Gengar", "level": 22, "hp": 34, "max_hp": 66, "exp_frac": 0.80,
			"status": "psn", "held_item": "",
			"icon": "res://art/icons/0094_gengar_icon.png", "sprite": ""},
		{"name": "Eevee", "level": 18, "hp": 45, "max_hp": 45, "exp_frac": 0.12,
			"status": "", "held_item": "Soothe Bell",
			"icon": "res://art/icons/0133_eevee_icon.png", "sprite": ""},
		{"name": "Pidgey", "level": 16, "hp": 0, "max_hp": 38, "exp_frac": 0.44,
			"status": "permadeath", "held_item": "",
			"icon": "res://art/icons/0016_pidgey_icon.png", "sprite": ""},
		{"name": "Snorlax", "level": 21, "hp": 118, "max_hp": 124, "exp_frac": 0.05,
			"status": "", "held_item": "Leftovers",
			"icon": "res://art/icons/0143_snorlax_icon.png", "sprite": ""},
	]


func _build() -> void:
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

	# Header: on-screen Back (touch) + title.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var back_button := Button.new()
	back_button.custom_minimum_size = Vector2(56, 56)
	back_button.icon = PUWUiTheme.tex("res://art/ui/back_chevron.png")
	back_button.expand_icon = true
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back_button)
	header.add_child(PUWUiTheme.make_label("PARTY", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))

	# Main row: lead panel + five compact rows.
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	main.add_child(_build_lead_panel())
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 10)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(rows_box)
	for i in range(1, 6):
		var row: Button = _make_row(i)
		rows_box.add_child(row)
		_rows.append(row)
	var rows_spacer := Control.new()
	rows_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_box.add_child(rows_spacer)

	# Bright message strip.
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	var strip_row := HBoxContainer.new()
	strip.add_child(strip_row)
	_message_label = PUWUiTheme.make_label("Choose a Pokémon.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(_message_label)
	var arrow := TextureRect.new()
	arrow.texture = PUWUiTheme.tex("res://art/ui/advance_arrow.png")
	arrow.custom_minimum_size = Vector2(24, 24)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	strip_row.add_child(arrow)

	_build_action_panel()


func _build_lead_panel() -> Button:
	_lead_button = Button.new()
	_lead_button.custom_minimum_size = Vector2(420, 0)
	_lead_button.focus_mode = Control.FOCUS_ALL
	_lead_button.add_theme_stylebox_override("normal", PUWUiTheme.dark_panel_style())
	_lead_button.add_theme_stylebox_override("hover", PUWUiTheme.dark_panel_style())
	_lead_button.add_theme_stylebox_override("pressed", PUWUiTheme.dark_panel_style())
	_lead_button.add_theme_stylebox_override("focus", PUWUiTheme._flat(Color(0, 0, 0, 0), PUWUiTheme.ACCENT, 8, 3))
	_lead_button.pressed.connect(func() -> void: open_action_panel(0))
	_lead_button.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lead_button.add_child(box)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top_spacer)
	# Stage: the sprite stands ON the platform disc (disc anchored
	# to the stage floor, sprite bottomed just below disc center).
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 250)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stage)
	var disc := TextureRect.new()
	disc.texture = PUWUiTheme.tex("res://art/ui/platform_disc.png")
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.anchor_left = 0.5
	disc.anchor_right = 0.5
	disc.anchor_top = 1.0
	disc.anchor_bottom = 1.0
	disc.offset_left = -150
	disc.offset_right = 150
	disc.offset_top = -120
	disc.offset_bottom = -8
	stage.add_child(disc)
	_lead_sprite = TextureRect.new()
	_lead_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lead_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lead_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lead_sprite.anchor_left = 0.5
	_lead_sprite.anchor_right = 0.5
	_lead_sprite.anchor_top = 1.0
	_lead_sprite.anchor_bottom = 1.0
	_lead_sprite.offset_left = -88
	_lead_sprite.offset_right = 88
	_lead_sprite.offset_top = -224
	_lead_sprite.offset_bottom = -48
	stage.add_child(_lead_sprite)
	_lead_name = PUWUiTheme.make_label("", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true)
	_lead_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lead_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lead_name)
	_lead_meta = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	_lead_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lead_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lead_meta)
	_lead_hp_bar = _make_bar()
	box.add_child(_lead_hp_bar)
	_lead_hp_label = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT)
	_lead_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lead_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lead_hp_label)
	_lead_exp_bar = _make_bar()
	box.add_child(_lead_exp_bar)
	_lead_chip = _make_chip()
	_lead_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_lead_chip)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bottom_spacer)
	return _lead_button


func _make_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _make_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = PUWUiTheme.make_label("", PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT, true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	chip.set_meta("label", label)
	return chip


func _set_chip(chip: PanelContainer, status: String) -> void:
	var data: Dictionary = PUWUiTheme.status_chip(status)
	var label: Label = chip.get_meta("label") as Label
	if data.is_empty():
		chip.visible = false
		return
	chip.visible = true
	label.text = str(data.get("text", ""))
	chip.add_theme_stylebox_override("panel", PUWUiTheme.chip_style(data.get("color", PUWUiTheme.PANEL_LIGHT) as Color, 8))


func _make_row(slot: int) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override("normal", PUWUiTheme.row_style(false))
	row.add_theme_stylebox_override("hover", PUWUiTheme.row_style(true))
	row.add_theme_stylebox_override("pressed", PUWUiTheme.row_style(true))
	row.add_theme_stylebox_override("focus", PUWUiTheme._flat(Color(0.23, 0.31, 0.47), PUWUiTheme.ACCENT, 6, 2))
	row.pressed.connect(func() -> void: open_action_panel(slot))
	row.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
	var box := HBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var name_label: Label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	name_label.name = "Name"
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var level_label: Label = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	level_label.name = "Level"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(level_label)
	var bar_box := VBoxContainer.new()
	bar_box.name = "BarBox"
	bar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_box)
	var bar: ProgressBar = _make_bar()
	bar.name = "HPBar"
	bar_box.add_child(bar)
	var hp_label: Label = PUWUiTheme.make_label("", PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM)
	hp_label.name = "HPLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_child(hp_label)
	var chip: PanelContainer = _make_chip()
	chip.name = "Chip"
	box.add_child(chip)
	return row


func _build_action_panel() -> void:
	_action_panel = PanelContainer.new()
	_action_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_panel.offset_left = -316
	_action_panel.offset_top = -436
	_action_panel.offset_right = -28
	_action_panel.offset_bottom = -96
	_action_panel.visible = false
	add_child(_action_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_action_panel.add_child(box)
	for action_value in ["Summary", "Switch", "Item", "Care", "Close"]:
		var action_id: String = action_value
		var button: Button = PUWUiTheme.make_button(action_id, Vector2(0, 56))
		button.pressed.connect(func() -> void: _on_action_pressed(action_id.to_lower()))
		box.add_child(button)
		if _action_first == null:
			_action_first = button


func open_action_panel(slot: int) -> void:
	_action_slot = slot
	_action_panel.visible = true
	if slot >= 0 and slot < party.size():
		var mon: Dictionary = party[slot]
		_message_label.text = "What do you want to do with " + str(mon.get("name", "it")) + "?"
	if _action_first != null:
		_action_first.grab_focus()


func close_action_panel() -> void:
	_action_panel.visible = false
	_message_label.text = "Choose a Pokémon."


func _on_action_pressed(action_id: String) -> void:
	if action_id == "close":
		PUWUiSound.play("ui_cancel")
		close_action_panel()
		return
	PUWUiSound.play("ui_confirm")
	action_chosen.emit(action_id, _action_slot)
	close_action_panel()


func refresh() -> void:
	if party.is_empty():
		return
	var lead: Dictionary = party[0]
	_lead_sprite.texture = PUWUiTheme.tex(str(lead.get("sprite", "")))
	_apply_faint_visual(_lead_sprite, str(lead.get("status", "")))
	_lead_name.text = str(lead.get("name", ""))
	var meta_text: String = "Lv " + str(lead.get("level", 1))
	var held: String = str(lead.get("held_item", ""))
	if held != "":
		meta_text += "   ·   " + held
	_lead_meta.text = meta_text
	PUWUiTheme.update_hp_bar(_lead_hp_bar, int(lead.get("hp", 0)), int(lead.get("max_hp", 1)))
	_lead_hp_label.text = str(lead.get("hp", 0)) + " / " + str(lead.get("max_hp", 1))
	PUWUiTheme.update_exp_bar(_lead_exp_bar, float(lead.get("exp_frac", 0.0)))
	_set_chip(_lead_chip, str(lead.get("status", "")))
	for i in _rows.size():
		var slot: int = i + 1
		var row: Button = _rows[i]
		if slot >= party.size():
			row.visible = false
			continue
		row.visible = true
		var mon: Dictionary = party[slot]
		var icon: TextureRect = row.get_node("Box/Icon") as TextureRect
		icon.texture = PUWUiTheme.tex(str(mon.get("icon", "")))
		_apply_faint_visual(icon, str(mon.get("status", "")))
		(row.get_node("Box/Name") as Label).text = str(mon.get("name", ""))
		(row.get_node("Box/Level") as Label).text = "Lv " + str(mon.get("level", 1))
		PUWUiTheme.update_hp_bar(row.get_node("Box/BarBox/HPBar") as ProgressBar, int(mon.get("hp", 0)), int(mon.get("max_hp", 1)))
		(row.get_node("Box/BarBox/HPLabel") as Label).text = str(mon.get("hp", 0)) + " / " + str(mon.get("max_hp", 1))
		_set_chip(row.get_node("Box/Chip") as PanelContainer, str(mon.get("status", "")))


func _apply_faint_visual(rect: TextureRect, status: String) -> void:
	if status == "permadeath" or status == "fainted":
		rect.modulate = Color(0.42, 0.42, 0.48, 0.85)
	else:
		rect.modulate = Color.WHITE


func get_initial_focus_control() -> Control:
	return _lead_button
