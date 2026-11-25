extends Node
## UI screens production tests. Drives the REAL screens (the six
## this production adds + the settings model + the extended
## PUWMenuHost) against REAL save states built by
## PUWSaveManager.build_state and the REAL bound modules
## (PartyAndStorageManager, PUWPokedex, PUWQuestBoard,
## PUWVexaSimulator). Prints one PASS/FAIL line per check and a
## final UI_SCREENS_TESTS summary; exit code = failures (capped).

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


func _mon(species: String, mon_name: String, level: int) -> Dictionary:
	return {"species": species, "name": mon_name, "level": level}


## A real save state in PUWSaveManager's own shape: party of 3,
## 12,345 money, 2 badges, 3 seen / 1 caught, player "Riley".
func _real_state() -> Dictionary:
	var party: Array = [
		_mon("bulbasaur", "Bulbasaur", 5),
		_mon("squirtle", "Squirtle", 5),
		_mon("pikachu", "Pikachu", 6),
	]
	return PUWSaveManager.build_state(
		party, [], {}, 12345,
		[{"name": "Boulder Badge"}, {"name": "Cascade Badge"}],
		["bulbasaur", "squirtle", "pikachu"], ["bulbasaur"],
		{}, {"name": "Riley"})


class CryDouble:
	extends Node
	var calls: Array = []

	func play_cry_for_mon(mon: Dictionary) -> bool:
		calls.append(mon.duplicate(true))
		return true


func _ready() -> void:
	await get_tree().process_frame
	await _test_storage()
	await _test_pokedex()
	_test_trainer_card()
	await _test_options()
	await _test_quest_board()
	await _test_vexa()
	await _test_host()
	print("UI_SCREENS_TESTS passed=", _pass, " failed=", _fail)
	for failure in _failures:
		print("FAILED: ", failure)
	get_tree().quit(mini(_fail, 125))


# ------------------------------------------------------------------
# Storage
# ------------------------------------------------------------------

func _test_storage() -> void:
	var state: Dictionary = _real_state()
	var screen := PUWStorageScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var changed: Array = []
	screen.storage_changed.connect(func() -> void: changed.append(1))
	screen.bind_state(state)
	_check("storage_party_adopted", screen.manager().party.size() == 3,
		"party=" + str(screen.manager().party.size()))
	_check("storage_focus", screen.get_initial_focus_control() != null)
	# Deposit two, one at a time; the state itself must change.
	screen.select_party(0)
	screen.press_deposit()
	_check("storage_deposit_1_state", (state.get("party", []) as Array).size() == 2
		and (state.get("boxes", []) as Array).size() > 0
		and ((state.get("boxes", []) as Array)[0] as Array).size() == 1,
		"party=" + str((state.get("party", []) as Array).size()))
	screen.select_party(0)
	screen.press_deposit()
	_check("storage_deposit_2_box", screen.manager().box_count_used(0) == 2,
		"box=" + str(screen.manager().box_count_used(0)))
	_check("storage_changed_emitted", changed.size() == 2, "emitted=" + str(changed.size()))
	# The party must keep one: the third deposit refuses and the
	# state is untouched.
	screen.select_party(0)
	screen.press_deposit()
	_check("storage_keep_one_refused",
		screen.message_text() == "You must keep at least one Pokémon in your party."
		and (state.get("party", []) as Array).size() == 1,
		"msg=" + screen.message_text())
	# Withdraw the first box mon back.
	screen.select_slot(0)
	screen.press_withdraw()
	_check("storage_withdraw", (state.get("party", []) as Array).size() == 2
		and screen.manager().box_count_used(0) == 1,
		"party=" + str((state.get("party", []) as Array).size()))
	# Move: deposit once more (box = [squirtle, pikachu]), then
	# swap the two box slots through the screen's move flow.
	screen.select_party(0)
	screen.press_deposit()
	screen.select_slot(0)
	screen.press_move()
	screen.select_slot(1)
	var box0: Array = screen.manager().pc_boxes[0]
	_check("storage_move_swap",
		box0.size() == 2 and str((box0[0] as Dictionary).get("species", "")) == "pikachu"
		and str((box0[1] as Dictionary).get("species", "")) == "squirtle",
		"box0=" + str(box0))
	# Box navigation wraps over the real box count.
	screen.change_box(-1)
	_check("storage_box_wrap_back", screen.current_box() == PartyAndStorageManager.BOX_COUNT - 1,
		"box=" + str(screen.current_box()))
	screen.change_box(1)
	_check("storage_box_wrap_fwd", screen.current_box() == 0)
	screen.queue_free()


# ------------------------------------------------------------------
# Pokédex
# ------------------------------------------------------------------

func _test_pokedex() -> void:
	var state: Dictionary = _real_state()
	var screen := PUWPokedexScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var cries: Array = []
	screen.cry_requested.connect(func(slug: String) -> void: cries.append(slug))
	screen.bind_state(state)
	var dex := PUWPokedex.new()
	_check("dex_entry_count", screen.entry_count() == dex.species_count(),
		"entries=" + str(screen.entry_count()) + " species=" + str(dex.species_count()))
	var totals: Dictionary = screen.counts()
	_check("dex_counts", int(totals.get("seen", 0)) == 3 and int(totals.get("caught", 0)) == 1,
		str(totals))
	# Find Bulbasaur (caught in the fixture) by walking the list.
	var found: int = -1
	for i in screen.entry_count():
		screen.select_entry(i)
		if str(screen.selected_entry().get("slug", "")) == "bulbasaur":
			found = i
			break
	_check("dex_bulbasaur_found", found >= 0)
	_check("dex_bulbasaur_detail", screen._detail_name.text == "Bulbasaur",
		"detail=" + screen._detail_name.text)
	# Cry with no player bound: emitted + honestly reported.
	screen.press_cry()
	_check("dex_cry_unbound", cries == ["bulbasaur"]
		and screen.message_text() == "No cry player is bound yet.",
		"msg=" + screen.message_text())
	# Cry with a player bound: the real hook shape is called.
	var double := CryDouble.new()
	add_child(double)
	screen.bind_cry_player(double)
	screen.press_cry()
	_check("dex_cry_bound", double.calls.size() == 1
		and str((double.calls[0] as Dictionary).get("species", "")) == "bulbasaur"
		and int((double.calls[0] as Dictionary).get("dex_id", 0)) == 1,
		str(double.calls))
	# An unseen species hides its name and cannot cry.
	var unseen_found: bool = false
	for i in screen.entry_count():
		screen.select_entry(i)
		if str(screen.selected_entry().get("status", "")) == "unseen":
			unseen_found = screen._detail_name.text == "?????"
			break
	_check("dex_unseen_hidden", unseen_found)
	# MDX mode lists the register's own entries, nothing borrowed.
	screen.set_family(PUWPokedexScreen.FAMILY_MDX)
	_check("dex_mdx_register", screen.entry_count() == dex.pokedex_entries_mdx().size()
		and screen.family() == "mdx",
		"mdx=" + str(screen.entry_count()))
	var mdx_totals: Dictionary = screen.counts()
	_check("dex_mdx_no_state", int(mdx_totals.get("seen", 0)) == 0 and int(mdx_totals.get("caught", 0)) == 0)
	screen.queue_free()
	double.queue_free()


# ------------------------------------------------------------------
# Trainer card
# ------------------------------------------------------------------

func _row_map(screen: PUWTrainerCardScreen) -> Dictionary:
	var map: Dictionary = {}
	for row_value in screen.card_rows():
		if row_value is Dictionary:
			var row: Dictionary = row_value
			map[str(row.get("key", ""))] = str(row.get("value", ""))
	return map


func _test_trainer_card() -> void:
	var state: Dictionary = _real_state()
	var screen := PUWTrainerCardScreen.new()
	add_child(screen)
	screen.bind_state(state)
	var rows: Dictionary = _row_map(screen)
	_check("card_name", str(rows.get("name", "")) == "Riley", str(rows))
	_check("card_money", str(rows.get("money", "")) == PUWUiTheme.format_money(12345),
		str(rows.get("money", "")))
	_check("card_badges", str(rows.get("badges", "")) == "2", str(rows.get("badges", "")))
	var badge_names: Array = []
	for row_value in screen.card_rows():
		if row_value is Dictionary:
			var row: Dictionary = row_value
			if str(row.get("key", "")) == "badge":
				badge_names.append(str(row.get("value", "")))
	_check("card_badge_names", badge_names == ["Boulder Badge", "Cascade Badge"], str(badge_names))
	_check("card_dex", str(rows.get("dex", "")) == "Seen 3  ·  Caught 1", str(rows.get("dex", "")))
	# NO INVENTED DATA: the schema records no play time, so the
	# row is omitted — never filled with a plausible value.
	_check("card_no_play_time", not screen.has_play_time_row() and not rows.has("play_time"))
	# When a state DOES carry play time, it renders honestly.
	var timed: Dictionary = state.duplicate(true)
	timed["play_time_seconds"] = 3661
	screen.bind_state(timed)
	_check("card_play_time_shown", screen.has_play_time_row()
		and str(_row_map(screen).get("play_time", "")) == "1:01",
		str(_row_map(screen)))
	_check("card_format_time", PUWTrainerCardScreen.format_play_time(3661) == "1:01"
		and PUWTrainerCardScreen.format_play_time(0) == "0:00"
		and PUWTrainerCardScreen.format_play_time(36000) == "10:00")
	# An empty state invents nothing either.
	screen.bind_state({})
	var empty_rows: Dictionary = _row_map(screen)
	_check("card_empty_state", not empty_rows.has("name") and not empty_rows.has("play_time"),
		str(empty_rows))
	screen.queue_free()


# ------------------------------------------------------------------
# Options / settings model
# ------------------------------------------------------------------

func _test_options() -> void:
	var state: Dictionary = {}
	var screen := PUWOptionsScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var emissions: Array = []
	screen.settings_changed.connect(func(s: Dictionary) -> void: emissions.append(s.duplicate(true)))
	screen.bind_state(state)
	_check("options_defaults", screen.settings() == PUWGameSettings.defaults(),
		str(screen.settings()))
	_check("options_state_key", state.has("settings"))
	# Text speed cycles slow -> mid -> fast -> slow off the
	# dialogue box's bound 60 cps mid rate.
	_check("options_cps_mid", PUWGameSettings.text_speed_cps(state) == 60.0)
	screen.cycle_text_speed()
	_check("options_speed_fast", PUWGameSettings.text_speed(state) == "fast"
		and PUWGameSettings.text_speed_cps(state) == 120.0)
	screen.cycle_text_speed()
	_check("options_speed_slow", PUWGameSettings.text_speed(state) == "slow"
		and PUWGameSettings.text_speed_cps(state) == 30.0)
	screen.cycle_text_speed()
	_check("options_speed_cycle", PUWGameSettings.text_speed(state) == "mid")
	# Music toggle: state flips, the change is emitted, and the
	# audio application is honest — headless has only the Master
	# bus, so no Music bus can be claimed applied.
	screen.toggle_music()
	_check("options_music_off", PUWGameSettings.music_on(state) == false
		and emissions.size() >= 4
		and bool((emissions[emissions.size() - 1] as Dictionary).get("music_on", true)) == false,
		"emissions=" + str(emissions.size()))
	_check("options_music_bus_honest",
		bool(PUWGameSettings.apply_audio(state).get("music_applied", true)) == false
		and screen.message_text().contains("no Music bus"),
		"msg=" + screen.message_text())
	screen.toggle_sfx()
	_check("options_sfx_off", PUWGameSettings.sfx_on(state) == false
		and bool(PUWGameSettings.apply_audio(state).get("sfx_applied", true)) == false)
	# The playback contract: battle animation off is read live.
	screen.toggle_battle_animation()
	_check("options_animation_contract_off", PUWGameSettings.animations_enabled(state) == false)
	screen.toggle_battle_animation()
	_check("options_animation_contract_on", PUWGameSettings.animations_enabled(state) == true)
	# Invalid writes are refused, settings unchanged.
	var before: Dictionary = PUWGameSettings.get_settings(state)
	PUWGameSettings.set_value(state, "text_speed", "ludicrous")
	PUWGameSettings.set_value(state, "nonsense", true)
	_check("options_invalid_refused", PUWGameSettings.get_settings(state) == before,
		str(PUWGameSettings.get_settings(state)))
	_check("options_focus", screen.get_initial_focus_control() != null)
	screen.queue_free()


# ------------------------------------------------------------------
# Quest board
# ------------------------------------------------------------------

func _test_quest_board() -> void:
	var state: Dictionary = _real_state()
	_check("quest_register", PUWQuestBoard.register_board(state, "kanto", "pallet_supply"))
	var posted: Dictionary = PUWQuestBoard.post_authored(state, {
		"id": "job_test_1", "board_id": "pallet_supply", "region_id": "kanto",
		"title": "Deliver the Parcel",
		"task": {"type": "deliver", "target": "parcel", "count": 1},
		"reward": {"money": 300, "rank_points": 10},
	}, 1)
	_check("quest_posted", bool(posted.get("ok", false)), str(posted))
	var screen := PUWQuestBoardScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var changed: Array = []
	screen.quests_changed.connect(func() -> void: changed.append(1))
	screen.bind_board(state, "pallet_supply")
	_check("quest_board_bound", screen.region_id() == "kanto" and screen.posting_count() == 1,
		"region=" + screen.region_id() + " postings=" + str(screen.posting_count()))
	_check("quest_rank_label", screen._rank_label.text.contains("pts"),
		"rank=" + screen._rank_label.text)
	var accepted: Dictionary = screen.accept_posting("job_test_1")
	_check("quest_accept", bool(accepted.get("ok", false)) and screen.accepted_count() == 1,
		str(accepted))
	var refused: Dictionary = screen.accept_posting("job_test_1")
	_check("quest_accept_twice_refused", not bool(refused.get("ok", true))
		and screen.message_text() != "",
		str(refused))
	var early: Dictionary = screen.turn_in_job("job_test_1")
	_check("quest_turn_in_not_ready", not bool(early.get("ok", true)), str(early))
	_check("quest_abandon", screen.abandon_job("job_test_1") and screen.accepted_count() == 0)
	_check("quest_changed_emitted", changed.size() >= 2, "emitted=" + str(changed.size()))
	# An unregistered board resolves to no region and no rows.
	screen.bind_board(state, "nowhere_board")
	_check("quest_unknown_board", screen.region_id() == "" and screen.posting_count() == 0,
		"region=" + screen.region_id())
	_check("quest_focus", screen.get_initial_focus_control() != null)
	screen.queue_free()


# ------------------------------------------------------------------
# VEXA entry
# ------------------------------------------------------------------

func _test_vexa() -> void:
	var state: Dictionary = _real_state()
	var screen := PUWVexaScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.bind_state(state)
	var rows: Array = screen.format_rows()
	var all_built: bool = rows.size() == 8
	for row_value in rows:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			if str(row.get("status", "")) != "built":
				all_built = false
	_check("vexa_formats_built", all_built and rows.size() == 8, "rows=" + str(rows.size()))
	var options: Dictionary = screen.simulation_options()
	_check("vexa_default_options",
		str(options.get("format", "")) == "singles" and int(options.get("level", 0)) == 50
		and bool(options.get("shiny", true)) == false
		and str(options.get("opponent", "")) == "counter"
		and bool(options.get("is_simulation", false)) == true
		and not options.has("star"),
		str(options))
	# Level stepping clamps to the simulator's own 5..100.
	screen.change_level(30)
	_check("vexa_level_max", screen.level() == 100, "level=" + str(screen.level()))
	screen.change_level(-40)
	_check("vexa_level_min", screen.level() == 5, "level=" + str(screen.level()))
	screen.change_level(9)
	# VGC is flat 50 whatever the stepper says.
	_check("vexa_select_vgc", screen.select_format("vgc") and screen.level() == 50)
	# Raid carries the star rating, defaulting to the
	# simulator's own DEFAULT_RAID_STAR; other formats don't.
	_check("vexa_select_raid", screen.select_format("tera_raid"))
	var raid_options: Dictionary = screen.simulation_options()
	_check("vexa_raid_star_default", int(raid_options.get("star", 0)) == PUWVexaSimulator.DEFAULT_RAID_STAR,
		str(raid_options))
	screen.change_star(10)
	_check("vexa_star_clamp", screen.star() == 5 and int(screen.simulation_options().get("star", 0)) == 5)
	_check("vexa_back_to_singles", screen.select_format("singles")
		and not screen.simulation_options().has("star"))
	# An unbuilt/unknown format is refused at the screen, the
	# same refusal the simulator would give.
	_check("vexa_unknown_refused", not screen.select_format("bogus")
		and screen.message_text() != "")
	# Chosen opponent: no name, no entry; named, entry emits.
	var emissions: Array = []
	screen.simulation_requested.connect(func(o: Dictionary) -> void: emissions.append(o.duplicate(true)))
	screen.set_opponent_mode("chosen")
	_check("vexa_chosen_needs_name", not screen.can_enter())
	screen.press_enter()
	_check("vexa_chosen_blocked", emissions.is_empty())
	screen.set_species_name("pikachu")
	_check("vexa_chosen_named", screen.can_enter()
		and str(screen.simulation_options().get("opponent", "")) == "pikachu")
	screen.press_enter()
	_check("vexa_enter_emits", emissions.size() == 1
		and bool((emissions[0] as Dictionary).get("is_simulation", false)) == true,
		str(emissions))
	# Shiny toggle rides the options.
	screen.toggle_shiny()
	_check("vexa_shiny", bool(screen.simulation_options().get("shiny", false)) == true)
	# No party, no entry.
	var empty_state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {"name": "Riley"})
	screen.bind_state(empty_state)
	_check("vexa_no_party_blocked", not screen.can_enter() and screen.enter_block_reason() != "")
	_check("vexa_focus", screen.get_initial_focus_control() != null)
	screen.queue_free()


# ------------------------------------------------------------------
# Host: the register calls build 6 makes
# ------------------------------------------------------------------

func _test_host() -> void:
	var state: Dictionary = _real_state()
	PUWQuestBoard.register_board(state, "kanto", "pallet_supply")
	PUWQuestBoard.post_authored(state, {
		"id": "job_host_1", "board_id": "pallet_supply", "region_id": "kanto",
		"title": "Host Job",
		"task": {"type": "deliver", "target": "parcel", "count": 1},
		"reward": {"money": 100},
	}, 1)
	var host := PUWMenuHost.new()
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	host.bind_state(state)
	_check("host_built", host.stack != null and host.pokedex_screen != null
		and host.options_screen != null and host.trainer_card_screen != null
		and host.storage_screen != null and host.quest_board_screen != null
		and host.vexa_screen != null)
	# Every new panel is registered: push + pop each by id.
	var ids: Array[String] = ["pokedex", "options", "trainer_card", "storage", "quest_board", "vexa"]
	var all_registered: bool = true
	for panel_id in ids:
		host.stack.push_panel(panel_id)
		if host.stack.current_panel_id() != panel_id:
			all_registered = false
		host.stack.pop_panel()
	_check("host_panels_registered", all_registered)
	# Start opens the X-menu; the dex entry now pushes a panel
	# instead of reporting unbuilt; B backs out and closes.
	var unbuilt: Array = []
	host.unbuilt_entry.connect(func(entry_id: String) -> void: unbuilt.append(entry_id))
	host.toggle_menu()
	_check("host_menu_opens", host.stack.depth() == 1 and host.stack.current_panel_id() == "xmenu",
		"depth=" + str(host.stack.depth()))
	host.xmenu.entry_chosen.emit("dex")
	_check("host_dex_pushes", host.stack.current_panel_id() == "pokedex" and host.stack.depth() == 2,
		"current=" + host.stack.current_panel_id())
	host.stack.handle_b_button()
	_check("host_b_backs_out", host.stack.depth() == 1 and host.stack.current_panel_id() == "xmenu")
	host.xmenu.entry_chosen.emit("settings")
	_check("host_settings_pushes", host.stack.current_panel_id() == "options")
	host.stack.handle_b_button()
	# Map still has no panel anywhere: honestly unbuilt.
	host.xmenu.entry_chosen.emit("map")
	_check("host_map_unbuilt", unbuilt == ["map"] and host.stack.depth() == 1, str(unbuilt))
	var saves: Array = []
	host.save_requested.connect(func() -> void: saves.append(1))
	host.xmenu.entry_chosen.emit("save")
	_check("host_save_request", saves.size() == 1)
	host.stack.handle_b_button()
	_check("host_b_closes", host.stack.depth() == 0)
	# Field entries push over a fresh X-menu root.
	host.open_storage()
	_check("host_open_storage", host.stack.current_panel_id() == "storage" and host.stack.depth() == 2,
		"current=" + host.stack.current_panel_id())
	host.storage_screen.close_requested.emit()
	_check("host_storage_close_pops", host.stack.current_panel_id() == "xmenu")
	host.open_quest_board("pallet_supply")
	_check("host_open_quest_board", host.stack.current_panel_id() == "quest_board"
		and host.quest_board_screen.posting_count() == 1,
		"postings=" + str(host.quest_board_screen.posting_count()))
	host.stack.handle_b_button()
	# The VEXA request crosses the host untouched, flag intact.
	var sims: Array = []
	host.vexa_simulation_requested.connect(func(o: Dictionary) -> void: sims.append(o.duplicate(true)))
	host.open_vexa()
	host.vexa_screen.press_enter()
	_check("host_vexa_request", host.stack.current_panel_id() == "vexa" and sims.size() == 1
		and bool((sims[0] as Dictionary).get("is_simulation", false)) == true,
		str(sims))
	host.queue_free()
