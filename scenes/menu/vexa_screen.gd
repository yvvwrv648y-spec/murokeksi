class_name PUWVexaScreen
extends Control
## VEXA entry screen (ui_screens production).
##
## PUWVexaSimulator is bound logic (the composed format set);
## live_wiring exposed its state as dictionaries and KEY_X
## toggled data — no screen existed. This screen is the entry
## point in the BW2 stack idiom:
##
##   Format list — PUWVexaSimulator.supported_formats(), the
##   composed set (singles / doubles / vgc / sky / inverse /
##   tera_raid / triple / rotation). Each row's availability is
##   read LIVE from format_status(): a format the simulator
##   does not report "built" is shown disabled with its real
##   status, never presented as playable. (Today all eight are
##   built and NOT_YET_BUILT_FORMATS is empty — the screen
##   still reads the status every refresh, so it stays honest
##   if that ever changes.)
##
##   Options — exactly the keys run_simulation reads, nothing
##   else: "level" (5-100, stepped by 5; VGC shows 50 flat
##   because the simulator forces it), "shiny" (bool),
##   "opponent" ("counter" for the dynamic super-effective
##   counter team, or the species name the player types for a
##   chosen opponent), "star" (tera_raid only, 1-5, default
##   PUWVexaSimulator.DEFAULT_RAID_STAR).
##
##   Simulation flag — HONEST BY CONSTRUCTION: VEXA battles
##   are simulations. simulation_options() always carries
##   "is_simulation": true, the header strip says so on the
##   screen itself, and the simulator's own safety rule backs
##   it (it snapshots the live party through PUWSaveManager,
##   battles deep copies only, and reports
##   "snapshot_unchanged"). There is no non-simulation VEXA
##   mode and the screen offers none.
##
## The screen does NOT run the battle: the simulator creates
## a BattleController node and needs a host inside the scene
## tree (its own docs: "the game passes the battle scene").
## Pressing Enter emits simulation_requested(options); build 6
## binds that to the battle flow, which calls
## PUWVexaSimulator.setup(battle_scene) and
## run_simulation(state party, options). Entering requires a
## non-empty party in the bound state — with none, Enter is
## disabled and the strip says why, instead of handing the
## simulator a party it cannot build a counter team against.

signal close_requested
signal simulation_requested(options: Dictionary)

const FORMAT_NAMES: Dictionary = {
	"singles": "Singles",
	"doubles": "Doubles",
	"vgc": "VGC (Doubles, Lv 50 Flat)",
	"sky": "Sky Battle",
	"inverse": "Inverse Battle",
	"tera_raid": "Tera Raid",
	"triple": "Triple Battle",
	"rotation": "Rotation Battle",
}

const LEVEL_MIN: int = 5
const LEVEL_MAX: int = 100
const LEVEL_STEP: int = 5
const LEVEL_DEFAULT: int = 50
const VGC_LEVEL: int = 50

var _state: Dictionary = {}
var _simulator: PUWVexaSimulator = null
var _built: bool = false

var _format_id: String = "singles"
var _level: int = LEVEL_DEFAULT
var _shiny: bool = false
var _opponent_mode: String = "counter"
var _star: int = PUWVexaSimulator.DEFAULT_RAID_STAR

var _back_button: Button = null
var _format_buttons: Dictionary = {}
var _level_label: Label = null
var _level_minus: Button = null
var _level_plus: Button = null
var _counter_button: Button = null
var _chosen_button: Button = null
var _species_edit: LineEdit = null
var _shiny_button: Button = null
var _star_row: HBoxContainer = null
var _star_label: Label = null
var _enter_button: Button = null
var _message_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_ensure_simulator()
	_build()
	refresh()


func bind_state(state: Dictionary) -> void:
	_state = state
	refresh()


func _ensure_simulator() -> void:
	if _simulator == null:
		_simulator = PUWVexaSimulator.new()


## The formats the screen offers, read live from the
## simulator: [{"id", "name", "status", "engine_format"}].
## A format appears here exactly when supported_formats()
## lists it; its row is selectable only when status is
## "built".
func format_rows() -> Array:
	_ensure_simulator()
	var rows: Array = []
	for format_value in _simulator.supported_formats():
		var format_id: String = str(format_value)
		rows.append({
			"id": format_id,
			"name": str(FORMAT_NAMES.get(format_id, format_id.capitalize())),
			"status": _simulator.format_status(format_id),
			"engine_format": _simulator.engine_format(format_id),
		})
	return rows


func selected_format() -> String:
	return _format_id


## Select a format. Refused (returns false) when the
## simulator does not report the format "built" — the same
## refusal run_simulation would give, one step earlier.
func select_format(format_id: String) -> bool:
	_ensure_simulator()
	if _simulator.format_status(format_id) != "built":
		_set_message("That format isn't available.")
		PUWUiSound.play("ui_error")
		return false
	_format_id = format_id
	_set_message("")
	refresh()
	return true


func level() -> int:
	if _format_id == "vgc":
		return VGC_LEVEL
	return _level


func change_level(delta_steps: int) -> void:
	_level = clampi(_level + delta_steps * LEVEL_STEP, LEVEL_MIN, LEVEL_MAX)
	refresh()


func opponent_mode() -> String:
	return _opponent_mode


func set_opponent_mode(mode: String) -> void:
	if mode != "counter" and mode != "chosen":
		return
	_opponent_mode = mode
	refresh()


func set_species_name(species_name: String) -> void:
	if _species_edit != null:
		_species_edit.text = species_name


func species_name() -> String:
	if _species_edit == null:
		return ""
	return _species_edit.text.strip_edges()


func toggle_shiny() -> void:
	_shiny = not _shiny
	refresh()


func star() -> int:
	return _star


func change_star(delta: int) -> void:
	_star = clampi(_star + delta, 1, 5)
	refresh()


func party_size() -> int:
	var party_value: Variant = _state.get("party", [])
	if party_value is Array:
		var party: Array = party_value
		return party.size()
	return 0


## The options dict for PUWVexaSimulator.run_simulation,
## built from the screen's current picks — the single source
## both the Enter press and the tests read. "is_simulation"
## is always true (see the header). "star" is included only
## for tera_raid, the only runner that reads it.
func simulation_options() -> Dictionary:
	var opponent: String = "counter"
	if _opponent_mode == "chosen":
		opponent = species_name()
	var options: Dictionary = {
		"format": _format_id,
		"level": level(),
		"shiny": _shiny,
		"opponent": opponent,
		"is_simulation": true,
	}
	if _format_id == "tera_raid":
		options["star"] = _star
	return options


## Why Enter is currently unavailable, or "" when it is
## available: no party, or chosen mode with no species named.
func enter_block_reason() -> String:
	if party_size() <= 0:
		return "You need a party to enter a simulation."
	if _opponent_mode == "chosen" and species_name() == "":
		return "Name the species to face, or pick Counter Team."
	return ""


func can_enter() -> bool:
	return enter_block_reason() == ""


## Press Enter: emits simulation_requested with
## simulation_options() when can_enter(), otherwise shows
## the block reason and emits nothing.
func press_enter() -> void:
	var reason: String = enter_block_reason()
	if reason != "":
		_set_message(reason)
		PUWUiSound.play("ui_error")
		return
	PUWUiSound.play("ui_confirm")
	simulation_requested.emit(simulation_options())


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
	header.add_child(PUWUiTheme.make_label("VEXA SIMULATOR", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(PUWUiTheme.make_label("Simulation — your real party is safe.", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM))

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	# Format list (left).
	var format_panel := PanelContainer.new()
	format_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	format_panel.custom_minimum_size = Vector2(430, 0)
	main.add_child(format_panel)
	var format_column := VBoxContainer.new()
	format_column.add_theme_constant_override("separation", 8)
	format_panel.add_child(format_column)
	format_column.add_child(PUWUiTheme.make_label("FORMAT", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM, true))
	_format_buttons.clear()
	for row_value in format_rows():
		if row_value is Dictionary:
			var row: Dictionary = row_value
			var format_id: String = str(row.get("id", ""))
			var button: Button = PUWUiTheme.make_button("", Vector2(0, 52))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func() -> void: select_format(format_id))
			button.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
			format_column.add_child(button)
			_format_buttons[format_id] = button

	# Options (right).
	var options_panel := PanelContainer.new()
	options_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	options_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(options_panel)
	var options_column := VBoxContainer.new()
	options_column.add_theme_constant_override("separation", 10)
	options_panel.add_child(options_column)
	options_column.add_child(PUWUiTheme.make_label("OPTIONS", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM, true))

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	options_column.add_child(level_row)
	level_row.add_child(PUWUiTheme.make_label("Level", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM, true))
	_level_minus = PUWUiTheme.make_button("-", Vector2(56, 52))
	_level_minus.pressed.connect(func() -> void: change_level(-1))
	level_row.add_child(_level_minus)
	_level_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	_level_label.custom_minimum_size = Vector2(150, 0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_row.add_child(_level_label)
	_level_plus = PUWUiTheme.make_button("+", Vector2(56, 52))
	_level_plus.pressed.connect(func() -> void: change_level(1))
	level_row.add_child(_level_plus)

	var opponent_row := HBoxContainer.new()
	opponent_row.add_theme_constant_override("separation", 10)
	options_column.add_child(opponent_row)
	opponent_row.add_child(PUWUiTheme.make_label("Opponent", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM, true))
	_counter_button = PUWUiTheme.make_button("Counter Team", Vector2(190, 52))
	_counter_button.pressed.connect(func() -> void: set_opponent_mode("counter"))
	opponent_row.add_child(_counter_button)
	_chosen_button = PUWUiTheme.make_button("Chosen Species", Vector2(190, 52))
	_chosen_button.pressed.connect(func() -> void: set_opponent_mode("chosen"))
	opponent_row.add_child(_chosen_button)
	_species_edit = LineEdit.new()
	_species_edit.placeholder_text = "Species name"
	_species_edit.custom_minimum_size = Vector2(0, 52)
	_species_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_species_edit.text_changed.connect(func(_new_text: String) -> void: refresh())
	options_column.add_child(_species_edit)

	_shiny_button = PUWUiTheme.make_button("", Vector2(0, 52))
	_shiny_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_shiny_button.pressed.connect(func() -> void: toggle_shiny())
	options_column.add_child(_shiny_button)

	_star_row = HBoxContainer.new()
	_star_row.add_theme_constant_override("separation", 10)
	options_column.add_child(_star_row)
	_star_row.add_child(PUWUiTheme.make_label("Raid Star", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM, true))
	var star_minus: Button = PUWUiTheme.make_button("-", Vector2(56, 52))
	star_minus.pressed.connect(func() -> void: change_star(-1))
	_star_row.add_child(star_minus)
	_star_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	_star_label.custom_minimum_size = Vector2(60, 0)
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_row.add_child(_star_label)
	var star_plus: Button = PUWUiTheme.make_button("+", Vector2(56, 52))
	star_plus.pressed.connect(func() -> void: change_star(1))
	_star_row.add_child(star_plus)

	_enter_button = PUWUiTheme.make_button("Enter Simulation", Vector2(0, 60))
	_enter_button.pressed.connect(func() -> void: press_enter())
	root.add_child(_enter_button)

	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	strip.add_child(_message_label)


func refresh() -> void:
	if not _built:
		return
	for format_id_value in _format_buttons.keys():
		var format_id: String = str(format_id_value)
		var button: Button = _format_buttons[format_id]
		_ensure_simulator()
		var status: String = _simulator.format_status(format_id)
		var name_text: String = str(FORMAT_NAMES.get(format_id, format_id.capitalize()))
		if status == "built":
			button.text = ("» " if format_id == _format_id else "") + name_text
			button.disabled = false
		else:
			button.text = name_text + "  (" + status.replace("_", " ") + ")"
			button.disabled = true
	if _format_id == "vgc":
		_level_label.text = "50 (flat)"
		_level_minus.disabled = true
		_level_plus.disabled = true
	else:
		_level_label.text = str(_level)
		_level_minus.disabled = _level <= LEVEL_MIN
		_level_plus.disabled = _level >= LEVEL_MAX
	_counter_button.text = ("» " if _opponent_mode == "counter" else "") + "Counter Team"
	_chosen_button.text = ("» " if _opponent_mode == "chosen" else "") + "Chosen Species"
	_species_edit.editable = _opponent_mode == "chosen"
	_shiny_button.text = "Shiny Opponents:  " + ("On" if _shiny else "Off")
	_star_row.visible = _format_id == "tera_raid"
	_star_label.text = str(_star)
	_enter_button.disabled = not can_enter()


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func message_text() -> String:
	if _message_label == null:
		return ""
	return _message_label.text


func get_initial_focus_control() -> Control:
	var button_value: Variant = _format_buttons.get(_format_id, null)
	if button_value is Button:
		var button: Button = button_value
		return button
	return _back_button
