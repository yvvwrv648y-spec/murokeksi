class_name PUWStorageScreen
extends Control
## Pokémon storage (PC boxes) screen (ui_screens production).
##
## The bound tree's PartyAndStorageManager is data-only — no UI
## existed anywhere. This screen is that UI, in the BW2 stack's
## own idiom (same header/back pattern, theme, panels, cursor
## sounds and button factories as PUWPartyScreen / PUWBagScreen).
##
## State contract (the live-bag bind pattern): bind_state(state)
## adopts the save state's real collections into the manager
## (PartyAndStorageManager.adopt_collections over state["party"],
## state["boxes"], state["pc_storage"], state["mon_id_state"]),
## and every successful operation writes the collections back
## into the state immediately (sync_to_state), so what the
## screen shows is the save, not a copy of it. A refused
## operation (the manager's own rules: the party keeps at least
## one mon, boxes hold 30, the party holds 6) shows the reason
## and leaves the state untouched.
##
## Layout: left = the party (6 rows); right = one box (30 slots
## in a 6x5 grid) with Prev/Next box navigation; bottom action
## bar = Deposit / Withdraw / Move / Close, enabled only when
## the current selection makes them meaningful.

signal close_requested
signal storage_changed

const REASON_TEXT: Dictionary = {
	"party_must_keep_one": "You must keep at least one Pokémon in your party.",
	"box_full": "That box is full.",
	"all_boxes_full": "Every box is full.",
	"party_full": "Your party is full.",
	"invalid_party_index": "Choose a party Pokémon first.",
	"invalid_box_index": "That box does not exist.",
	"invalid_slot": "Choose a box slot first.",
}

var _state: Dictionary = {}
var _manager: PartyAndStorageManager = null
var _built: bool = false

var _box_index: int = 0
var _selected_party: int = -1
var _selected_slot: int = -1
var _move_source: Dictionary = {}

var _back_button: Button = null
var _box_label: Label = null
var _party_rows: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _deposit_button: Button = null
var _withdraw_button: Button = null
var _move_button: Button = null
var _pkhex_export_button: Button = null
var _pkhex_import_button: Button = null
var _message_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()
	refresh()


## Bind the real save state. Safe before or after _ready; the
## manager adopts the state's collections (mon ids backfilled
## once by the save manager's own pass, exactly as on load).
func bind_state(state: Dictionary) -> void:
	_state = state
	if _manager == null:
		_manager = PartyAndStorageManager.new()
	var party_value: Variant = state.get("party", [])
	var boxes_value: Variant = state.get("boxes", [])
	var storage_value: Variant = state.get("pc_storage", [])
	var id_state_value: Variant = state.get("mon_id_state", {})
	var party_list: Array = party_value if party_value is Array else []
	var boxes_list: Array = boxes_value if boxes_value is Array else []
	var storage_list: Array = storage_value if storage_value is Array else []
	var id_state: Dictionary = id_state_value if id_state_value is Dictionary else {}
	_manager.adopt_collections(party_list, boxes_list, storage_list, id_state)
	_selected_party = -1
	_selected_slot = -1
	_move_source = {}
	refresh()


## Write the manager's collections back into the bound state.
## Called after every successful operation (and only then).
func sync_to_state() -> void:
	if _state.is_empty() or _manager == null:
		return
	_state["party"] = _manager.party.duplicate(true)
	_state["boxes"] = _manager.pc_boxes.duplicate(true)
	_state["pc_storage"] = _manager.pc_storage.duplicate(true)
	_state["mon_id_state"] = _manager.mon_id_state()


func manager() -> PartyAndStorageManager:
	return _manager


func current_box() -> int:
	return _box_index


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
	header.add_child(PUWUiTheme.make_label("POKÉMON STORAGE", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	# Party column.
	var party_box := VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 10)
	party_box.custom_minimum_size = Vector2(360, 0)
	main.add_child(party_box)
	party_box.add_child(PUWUiTheme.make_label("PARTY", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM, true))
	for i in PartyAndStorageManager.MAX_PARTY:
		var slot_index: int = i
		var row: Button = PUWUiTheme.make_button("", Vector2(0, 64))
		row.pressed.connect(func() -> void: select_party(slot_index))
		row.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
		party_box.add_child(row)
		_party_rows.append(row)

	# Box column: navigation + 6x5 slot grid.
	var box_column := VBoxContainer.new()
	box_column.add_theme_constant_override("separation", 10)
	box_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(box_column)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	box_column.add_child(nav)
	var prev_button: Button = PUWUiTheme.make_button("< Prev Box", Vector2(150, 56))
	prev_button.pressed.connect(func() -> void: change_box(-1))
	nav.add_child(prev_button)
	_box_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	_box_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_box_label)
	var next_button: Button = PUWUiTheme.make_button("Next Box >", Vector2(150, 56))
	next_button.pressed.connect(func() -> void: change_box(1))
	nav.add_child(next_button)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box_column.add_child(grid)
	for i in PartyAndStorageManager.BOX_CAPACITY:
		var slot_index: int = i
		var slot_button: Button = PUWUiTheme.make_button("", Vector2(0, 56))
		slot_button.add_theme_font_size_override("font_size", PUWUiTheme.MICRO_SIZE)
		slot_button.pressed.connect(func() -> void: select_slot(slot_index))
		slot_button.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
		grid.add_child(slot_button)
		_slot_buttons.append(slot_button)

	# Action bar.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	_deposit_button = PUWUiTheme.make_button("Deposit", Vector2(160, 56))
	_deposit_button.pressed.connect(func() -> void: press_deposit())
	actions.add_child(_deposit_button)
	_withdraw_button = PUWUiTheme.make_button("Withdraw", Vector2(160, 56))
	_withdraw_button.pressed.connect(func() -> void: press_withdraw())
	actions.add_child(_withdraw_button)
	_move_button = PUWUiTheme.make_button("Move", Vector2(160, 56))
	_move_button.pressed.connect(func() -> void: press_move())
	actions.add_child(_move_button)
	# PKHeX bridge (fold-in round, step 2.7): the live caller
	# for PUWPKHexBridge — export the bound save's Pokémon as
	# .pk9 files to the bridge folder, import edited files
	# back. Audit 2 found the bridge seam-only (no caller
	# outside tests); this is the player-reachable surface.
	_pkhex_export_button = PUWUiTheme.make_button("PKHeX Export", Vector2(170, 56))
	_pkhex_export_button.pressed.connect(func() -> void: press_pkhex_export())
	actions.add_child(_pkhex_export_button)
	_pkhex_import_button = PUWUiTheme.make_button("PKHeX Import", Vector2(170, 56))
	_pkhex_import_button.pressed.connect(func() -> void: press_pkhex_import())
	actions.add_child(_pkhex_import_button)
	var close_button: Button = PUWUiTheme.make_button("Close", Vector2(160, 56))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	actions.add_child(close_button)

	# Bright message strip (the party screen's idiom).
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	_message_label = PUWUiTheme.make_label("Choose a Pokémon.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	strip.add_child(_message_label)


func select_party(index: int) -> void:
	_selected_party = index
	_selected_slot = -1
	refresh()


func select_slot(index: int) -> void:
	# While a move is armed, choosing a slot is choosing the
	# destination: run the move through the manager.
	if not _move_source.is_empty():
		var from_box: int = int(_move_source.get("box", -1))
		var from_slot: int = int(_move_source.get("slot", -1))
		if from_box == _box_index and from_slot == index:
			_move_source = {}
			_selected_slot = index
			_set_message("Move cancelled.")
			refresh()
			return
		_finish_move(_box_index, index)
		return
	_selected_slot = index
	_selected_party = -1
	refresh()


func change_box(delta: int) -> void:
	_box_index = wrapi(_box_index + delta, 0, PartyAndStorageManager.BOX_COUNT)
	_selected_slot = -1
	refresh()


## Deposit the selected party mon into the current box.
func press_deposit() -> void:
	if _manager == null:
		return
	var result: Dictionary = _manager.deposit(_selected_party, _box_index)
	if bool(result.get("ok", false)):
		var mon: Dictionary = _manager.pc_boxes[int(result.get("box", _box_index))][int(result.get("slot", 0))]
		_set_message("Deposited " + _mon_name(mon) + " into Box " + str(int(result.get("box", _box_index)) + 1) + ".")
		_selected_party = -1
		sync_to_state()
		storage_changed.emit()
		PUWUiSound.play("ui_confirm")
	else:
		_set_message(_reason_text(result))
		PUWUiSound.play("ui_error")
	refresh()


## Withdraw the selected box slot's mon into the party.
func press_withdraw() -> void:
	if _manager == null:
		return
	var result: Dictionary = _manager.withdraw(_box_index, _selected_slot)
	if bool(result.get("ok", false)):
		var mon_value: Variant = result.get("mon", {})
		var mon: Dictionary = mon_value if mon_value is Dictionary else {}
		_set_message("Withdrew " + _mon_name(mon) + " to the party.")
		_selected_slot = -1
		sync_to_state()
		storage_changed.emit()
		PUWUiSound.play("ui_confirm")
	else:
		_set_message(_reason_text(result))
		PUWUiSound.play("ui_error")
	refresh()


## Arm a move from the selected box slot; the next slot chosen
## (in any box) is the destination. Pressing Move again disarms.
func press_move() -> void:
	if not _move_source.is_empty():
		_move_source = {}
		_set_message("Move cancelled.")
		refresh()
		return
	if _manager == null or _selected_slot < 0:
		_set_message("Choose a box slot first.")
		return
	var box: Array = _manager.pc_boxes[_box_index]
	if _selected_slot >= box.size():
		_set_message("That slot is empty.")
		return
	_move_source = {"box": _box_index, "slot": _selected_slot}
	_set_message("Choose where to move it.")
	refresh()


## The PKHeX bridge folder (bridge spec §11): a real folder
## on desktop, the browser-sandboxed user folder on Web.
func _pkhex_bridge_dir() -> String:
	return ProjectSettings.globalize_path("user://pkhex_bridge")


## Export every party/boxed Pokémon in the bound save state
## as a .pk9 + sidecar pair in the bridge folder, through
## PUWPKHexBridge.export_state. Mons the bridge cannot
## represent (no SV personal-table entry, per the spec) are
## refused with their named reason shown — never written as
## a wrong file.
func press_pkhex_export() -> void:
	if _state.is_empty():
		_set_message("No save is bound to this screen yet.")
		return
	var tables: Dictionary = PUWPKHexBridge.load_tables()
	var result: Dictionary = PUWPKHexBridge.export_state(_state, _pkhex_bridge_dir(), tables)
	if not bool(result.get("ok", false)):
		_set_message("PKHeX export failed: " + str(result.get("error", "unknown error")))
		PUWUiSound.play("ui_error")
		return
	var exported: int = int(result.get("exported", 0))
	var refused_v: Variant = result.get("refused", [])
	var refused: Array = refused_v if refused_v is Array else []
	if refused.is_empty():
		_set_message("Exported " + str(exported) + " Pokémon to the PKHeX bridge folder.")
		PUWUiSound.play("ui_confirm")
	else:
		_set_message("Exported " + str(exported) + " Pokémon. Refused: " + _pkhex_refusal_text(refused))
		PUWUiSound.play("ui_error")
	refresh()


## Import edited .pk9 files from the bridge folder through
## PUWPKHexBridge.import_state. The bridge merges into a
## COPY of the state and never adopts new Pokémon; the
## caller-side save decision (bridge spec) is taken here:
## when at least one entry applied, the merged collections
## are adopted into the live state and the screen rebinds,
## so what the player sees is the merged save. Refusals
## (mon_id mismatch, eggs, unmappable fields) surface their
## named reasons and leave the state untouched.
func press_pkhex_import() -> void:
	if _state.is_empty():
		_set_message("No save is bound to this screen yet.")
		return
	var tables: Dictionary = PUWPKHexBridge.load_tables()
	var result: Dictionary = PUWPKHexBridge.import_state(_state, _pkhex_bridge_dir(), tables)
	if not bool(result.get("ok", false)):
		_set_message("PKHeX import: " + str(result.get("error", "no bridge export found — export first.")))
		PUWUiSound.play("ui_error")
		return
	var applied: int = int(result.get("applied", 0))
	var unchanged: int = int(result.get("unchanged", 0))
	var refused_v: Variant = result.get("refused", [])
	var refused: Array = refused_v if refused_v is Array else []
	if applied > 0:
		var merged_v: Variant = result.get("state", {})
		if merged_v is Dictionary:
			var merged: Dictionary = merged_v
			var party_v: Variant = merged.get("party", [])
			var boxes_v: Variant = merged.get("boxes", [])
			var storage_v: Variant = merged.get("pc_storage", [])
			var id_state_v: Variant = merged.get("mon_id_state", {})
			_state["party"] = (party_v if party_v is Array else []).duplicate(true)
			_state["boxes"] = (boxes_v if boxes_v is Array else []).duplicate(true)
			_state["pc_storage"] = (storage_v if storage_v is Array else []).duplicate(true)
			_state["mon_id_state"] = (id_state_v if id_state_v is Dictionary else {}).duplicate(true)
			bind_state(_state)
			sync_to_state()
			storage_changed.emit()
	var text: String = "PKHeX import: " + str(applied) + " applied, " + str(unchanged) + " unchanged."
	if not refused.is_empty():
		text += " Refused: " + _pkhex_refusal_text(refused)
	_set_message(text)
	PUWUiSound.play("ui_confirm" if applied > 0 else "ui_cursor")
	refresh()


## Join a refusal list's named reasons for the message strip
## (export entries carry "error", import entries "reason").
func _pkhex_refusal_text(refused: Array) -> String:
	var parts: Array = []
	for entry_v in refused:
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v
			var why: String = str(entry.get("reason", entry.get("error", "refused")))
			if why != "":
				parts.append(why)
	if parts.is_empty():
		return str(refused.size()) + " refused."
	return "; ".join(parts)


func _finish_move(to_box: int, to_slot: int) -> void:
	var from_box: int = int(_move_source.get("box", -1))
	var from_slot: int = int(_move_source.get("slot", -1))
	_move_source = {}
	var result: Dictionary = _manager.move_in_storage(from_box, from_slot, to_box, to_slot)
	if bool(result.get("ok", false)):
		_set_message("Moved to Box " + str(to_box + 1) + ".")
		_selected_slot = int(result.get("slot", to_slot))
		sync_to_state()
		storage_changed.emit()
		PUWUiSound.play("ui_confirm")
	else:
		_set_message(_reason_text(result))
		PUWUiSound.play("ui_error")
	refresh()


func refresh() -> void:
	if not _built:
		return
	if _manager == null:
		_box_label.text = "Box 1 (0/" + str(PartyAndStorageManager.BOX_CAPACITY) + ")"
		for row in _party_rows:
			row.text = "—"
			row.disabled = true
		for slot_button in _slot_buttons:
			slot_button.text = "·"
			slot_button.disabled = true
		_deposit_button.disabled = true
		_withdraw_button.disabled = true
		_move_button.disabled = true
		_pkhex_export_button.disabled = _state.is_empty()
		_pkhex_import_button.disabled = _state.is_empty()
		return
	_box_label.text = "Box " + str(_box_index + 1) + " (" + str(_manager.box_count_used(_box_index)) + "/" + str(PartyAndStorageManager.BOX_CAPACITY) + ")"
	for i in _party_rows.size():
		var row: Button = _party_rows[i]
		if i < _manager.party.size():
			var mon: Dictionary = _manager.party[i]
			row.text = _mon_name(mon) + "  Lv " + str(int(mon.get("level", 1)))
			row.disabled = false
		else:
			row.text = "— Empty —"
			row.disabled = true
	var box: Array = _manager.pc_boxes[_box_index]
	for i in _slot_buttons.size():
		var slot_button: Button = _slot_buttons[i]
		if i < box.size():
			var mon: Dictionary = box[i]
			slot_button.text = _mon_name(mon)
			slot_button.disabled = false
		else:
			slot_button.text = "·"
			slot_button.disabled = true
	_deposit_button.disabled = _selected_party < 0
	_withdraw_button.disabled = _selected_slot < 0 or _selected_slot >= box.size()
	_move_button.disabled = _selected_slot < 0 or _selected_slot >= box.size()
	_pkhex_export_button.disabled = _state.is_empty()
	_pkhex_import_button.disabled = _state.is_empty()


func _mon_name(mon: Dictionary) -> String:
	var name_text: String = str(mon.get("name", ""))
	if name_text == "":
		name_text = str(mon.get("species", ""))
	if name_text == "":
		name_text = "Pokémon"
	return name_text


func _reason_text(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if REASON_TEXT.has(reason):
		return str(REASON_TEXT[reason])
	return "That can't be done."


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func message_text() -> String:
	if _message_label == null:
		return ""
	return _message_label.text


func get_initial_focus_control() -> Control:
	if not _party_rows.is_empty():
		return _party_rows[0]
	return _back_button
