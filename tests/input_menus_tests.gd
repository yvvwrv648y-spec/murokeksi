extends Node
## Input + menus prep tests. Drives the REAL screens (BW2 stack
## screens, battle screen) and the REAL spawner data with
## simulated input events and direct handler calls. Prints one
## PASS/FAIL line per check and a final INPUT_MENUS_TESTS summary;
## exit code = number of failures (capped).

var _pass: int = 0
var _fail: int = 0
var _failures: Array[String] = []


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		_failures.append(name + (" :: " + detail if detail != "" else ""))
		print("FAIL ", name, " :: ", detail)


func _key_event(physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	# Real hardware events carry BOTH fields; the bound stack's
	# raw-key path reads keycode while the action map binds
	# physical_keycode, so a faithful event sets both.
	e.keycode = physical
	e.physical_keycode = physical
	e.pressed = true
	return e


func _pad_event(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		var b: Button = child as Button
		if b != null and b.text == text:
			return b
		var nested: Button = _find_button(child, text)
		if nested != null:
			return nested
	return null


func _ready() -> void:
	await get_tree().process_frame
	_test_input_map()
	_test_movement_and_run()
	await _test_focus_helper()
	await _test_interaction()
	await _test_menu_host()
	await _test_battle_screen()
	print("INPUT_MENUS_TESTS passed=", _pass, " failed=", _fail)
	for f in _failures:
		print("  FAILED: ", f)
	get_tree().quit(mini(_fail, 120))


func _test_input_map() -> void:
	for action in ["puw_up", "puw_down", "puw_left", "puw_right", "puw_confirm", "puw_cancel", "puw_menu", "puw_run"]:
		_check("map_has_" + action, InputMap.has_action(action))
	_check("key_Z_is_confirm", _key_event(KEY_Z).is_action_pressed("puw_confirm"))
	_check("key_Enter_is_confirm", _key_event(KEY_ENTER).is_action_pressed("puw_confirm"))
	_check("key_Space_is_confirm", _key_event(KEY_SPACE).is_action_pressed("puw_confirm"))
	_check("key_X_is_cancel", _key_event(KEY_X).is_action_pressed("puw_cancel"))
	_check("key_Escape_is_cancel", _key_event(KEY_ESCAPE).is_action_pressed("puw_cancel"))
	_check("key_Tab_is_menu", _key_event(KEY_TAB).is_action_pressed("puw_menu"))
	_check("key_W_is_up", _key_event(KEY_W).is_action_pressed("puw_up"))
	_check("key_ArrowDown_is_down", _key_event(KEY_DOWN).is_action_pressed("puw_down"))
	_check("pad_A_is_confirm", _pad_event(JOY_BUTTON_A).is_action_pressed("puw_confirm"))
	_check("pad_B_is_cancel", _pad_event(JOY_BUTTON_B).is_action_pressed("puw_cancel"))
	_check("pad_B_is_run", _pad_event(JOY_BUTTON_B).is_action_pressed("puw_run"))
	_check("pad_Start_is_menu", _pad_event(JOY_BUTTON_START).is_action_pressed("puw_menu"))
	_check("pad_DpadRight_is_right", _pad_event(JOY_BUTTON_DPAD_RIGHT).is_action_pressed("puw_right"))
	_check("pad_DpadUp_is_up", _pad_event(JOY_BUTTON_DPAD_UP).is_action_pressed("puw_up"))
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	_check("stick_right_is_right", motion.is_action_pressed("puw_right"))
	_check("confirm_event_predicates", PUWInputInteraction.confirm_pressed(_key_event(KEY_Z))
		and PUWInputInteraction.cancel_pressed(_pad_event(JOY_BUTTON_B))
		and PUWInputInteraction.menu_pressed(_pad_event(JOY_BUTTON_START)))


func _test_movement_and_run() -> void:
	Input.action_press("puw_right")
	var v: Vector2 = PUWInputInteraction.movement_vector()
	_check("vector_right", v == Vector2(1, 0), str(v))
	Input.action_release("puw_right")
	Input.action_press("puw_up")
	v = PUWInputInteraction.movement_vector()
	_check("vector_up", v == Vector2(0, -1), str(v))
	Input.action_release("puw_up")
	_check("run_not_held_by_default", not PUWInputInteraction.run_held())
	Input.action_press("puw_run")
	_check("run_held_with_action", PUWInputInteraction.run_held())
	Input.action_release("puw_run")
	# The exact call PUWPlayerController._physics_process makes.
	Input.action_press("ui_right")
	var ui_v: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_check("controller_ui_vector_right", ui_v == Vector2(1, 0), str(ui_v))
	Input.action_release("ui_right")


func _test_focus_helper() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var b1 := Button.new()
	b1.text = "One"
	b1.disabled = true
	var b2 := Button.new()
	b2.text = "Two"
	box.add_child(b1)
	box.add_child(b2)
	await get_tree().process_frame
	_check("focus_skips_disabled", PUWFocus.grab_first_enabled([b1, b2])
		and get_viewport().gui_get_focus_owner() == b2)
	b2.disabled = true
	_check("focus_none_when_all_disabled", not PUWFocus.grab_first_enabled([b1, b2]))
	box.queue_free()


func _test_interaction() -> void:
	var spawner := PUWSpawner.new()
	add_child(spawner)
	var data: Dictionary = spawner.get_trainers_data()
	var placements: Array = data.get("placements", [])
	_check("placements_loaded", placements.size() > 0, str(placements.size()))
	var chosen: Dictionary = {}
	var chosen_lines: Array = []
	for raw_p in placements:
		if not (raw_p is Dictionary):
			continue
		var p: Dictionary = raw_p
		var lines: Array = spawner.dialogue_for(str(p.get("map", "")), str(p.get("text_id", "")))
		if not lines.is_empty():
			chosen = p
			chosen_lines = lines
			break
	_check("a_placement_with_real_lines_exists", not chosen.is_empty())
	if chosen.is_empty():
		return
	var trainer: Dictionary = PUWSpawner.trainer_dict_from_placement(chosen)
	var tile: Vector2i = trainer.get("tile", Vector2i.ZERO)
	# Stand one tile BELOW the actor, facing UP onto it.
	var player_tile: Vector2i = tile + Vector2i(0, 1)
	var hit: Dictionary = PUWInputInteraction.try_interact(spawner, player_tile, Vector2i(0, -1))
	_check("interact_finds_actor", bool(hit.get("found", false)))
	_check("interact_returns_real_lines", (hit.get("lines", []) as Array) == chosen_lines,
		str(hit.get("lines", [])))
	var away: Dictionary = PUWInputInteraction.try_interact(spawner, player_tile, Vector2i(0, 1))
	# Facing away must not return THIS actor (another placed actor
	# on the faced tile would be a legitimate different hit).
	var away_trainer: Dictionary = away.get("trainer", {})
	var away_ok: bool = not bool(away.get("found", false)) or away_trainer.get("tile", Vector2i(-999, -999)) != tile
	_check("interact_facing_away_misses_this_actor", away_ok)
	spawner.queue_free()


func _test_menu_host() -> void:
	var host := PUWMenuHost.new()
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("host_built_stack", host.stack != null and host.stack.depth() == 0)
	# Start opens the menu (host's own handler, InputEventAction).
	var start_event := InputEventAction.new()
	start_event.action = "puw_menu"
	start_event.pressed = true
	host._unhandled_input(start_event)
	await get_tree().process_frame
	_check("start_opens_xmenu", host.stack.depth() == 1 and host.stack.current_panel_id() == "xmenu",
		host.stack.current_panel_id())
	# The stack grabbed focus on the first X-menu cell.
	await get_tree().process_frame
	var owner: Control = get_viewport().gui_get_focus_owner()
	_check("xmenu_first_cell_focused", owner == host.xmenu._cells[0], str(owner))
	# Real D-pad event through the viewport moves focus down a row.
	Input.parse_input_event(_key_event(KEY_DOWN))
	await get_tree().process_frame
	await get_tree().process_frame
	owner = get_viewport().gui_get_focus_owner()
	var owner_idx: int = host.xmenu._cells.find(owner)
	_check("dpad_down_moves_focus", owner == host.xmenu._cells[3], "owner_cell_index=" + str(owner_idx))
	# A on the Party cell pushes the party panel.
	(host.xmenu._cells[0] as Button).pressed.emit()
	await get_tree().process_frame
	_check("party_entry_pushes_party", host.stack.depth() == 2 and host.stack.current_panel_id() == "party",
		host.stack.current_panel_id())
	# B backs out to the X-menu (the stack's own handler).
	host.stack._unhandled_input(_key_event(KEY_X))
	await get_tree().process_frame
	_check("B_backs_out_to_xmenu", host.stack.depth() == 1 and host.stack.current_panel_id() == "xmenu",
		host.stack.current_panel_id())
	# Bag entry, then the bag's Use action reaches the host.
	host._on_xmenu_entry("bag")
	await get_tree().process_frame
	_check("bag_entry_pushes_bag", host.stack.depth() == 2 and host.stack.current_panel_id() == "bag")
	var bag_hits: Array = []
	host.bag_action_chosen.connect(func(a: String, s: String) -> void: bag_hits.append(a + ":" + s))
	var use_button: Button = _find_button(host.bag_screen, "Use")
	_check("bag_use_button_exists", use_button != null)
	if use_button != null:
		use_button.pressed.emit()
		_check("bag_use_reaches_host", bag_hits.size() == 1 and str(bag_hits[0]).begins_with("use"),
			str(bag_hits))
	host.stack._unhandled_input(_key_event(KEY_X))
	await get_tree().process_frame
	# Unbuilt entries are refused honestly, stack untouched.
	var unbuilt: Array[String] = []
	host.unbuilt_entry.connect(func(id: String) -> void: unbuilt.append(id))
	host._on_xmenu_entry("dex")
	_check("dex_entry_unbuilt_not_pushed", unbuilt == ["dex"] and host.stack.depth() == 1,
		str(unbuilt) + " depth=" + str(host.stack.depth()))
	# Save emits its request instead of faking a save.
	var saves: Array[int] = []
	host.save_requested.connect(func() -> void: saves.append(1))
	host._on_xmenu_entry("save")
	_check("save_entry_requests_save", saves.size() == 1 and host.stack.depth() == 1)
	# B at the X-menu closes the whole menu.
	host.stack._unhandled_input(_key_event(KEY_B))
	await get_tree().process_frame
	_check("B_at_xmenu_closes", host.stack.depth() == 0 and not host.is_open())
	# Mart route: open_mart lands on the mart panel.
	host.open_mart()
	await get_tree().process_frame
	_check("open_mart_pushes_mart", host.stack.current_panel_id() == "mart", host.stack.current_panel_id())
	host.queue_free()


func _test_battle_screen() -> void:
	var bs := PUWBattleScreen.new()
	add_child(bs)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("battle_starts_on_command", bs._state == "command", bs._state)
	_check("fight_button_exists", bs._fight_button != null)
	var commands: Array[String] = []
	bs.command_chosen.connect(func(id: String) -> void: commands.append(id))
	var moves: Array[int] = []
	bs.move_chosen.connect(func(i: int) -> void: moves.append(i))
	bs._fight_button.pressed.emit()
	await get_tree().process_frame
	_check("fight_opens_move_grid", bs._state == "moves" and bs._move_buttons.size() == 4, bs._state)
	bs._move_buttons[0].pressed.emit()
	_check("move_press_emits_choice", moves == [0], str(moves))
	var back: Button = _find_button(bs, "Back")
	_check("move_grid_has_back", back != null)
	if back != null:
		back.pressed.emit()
		await get_tree().process_frame
		_check("back_returns_to_command", bs._state == "command", bs._state)
	var bag_button: Button = _find_button(bs, "BAG")
	_check("command_grid_has_bag", bag_button != null)
	if bag_button != null:
		bag_button.pressed.emit()
		_check("bag_command_emitted", commands == ["bag"], str(commands))
	bs.queue_free()
