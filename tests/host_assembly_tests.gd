extends SceneTree
## Host assembly prep tests (2026-11-24): the plug the mechanics
## audit found missing -- boot flow -> REAL overworld host ->
## walk -> A talks (a real sourced line) -> menu opens/closes
## bound to the live state -> wild battle hands off and returns
## -> the Oak event plays through the host for a custom
## character. Everything runs on the merged prep copies in this
## harness; expectations come from the real data (the stitch's
## verified teams, the Pallet Town dialogue bank, the Oak pool
## picks 1 + 7, the habitat table's ROUTE_1 area).
## Run: godot --headless --script res://tests/host_assembly_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_failed_names.append(name)
		print("FAIL: ", name)


func _init() -> void:
	print("PUW host assembly prep tests -- starting.")
	await _test_bootflow_fixed_protagonist()
	await _test_bootflow_custom()
	await _test_bootflow_continue_roundtrip()
	await _test_host_pallet_session()
	await _test_host_oak_event()
	await _test_pending_boot_and_scene()
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


# ----------------------------------------------------------------
# Boot flow: new game for a fixed protagonist.
# ----------------------------------------------------------------

func _test_bootflow_fixed_protagonist() -> void:
	var result: Dictionary = PUWBootFlow.new_game("riley", "Riley")
	_check("bootflow_riley_ok", bool(result.get("ok", false)))
	var party: Array = result.get("party", [])
	_check("bootflow_riley_party_six", party.size() == 6)
	_check("bootflow_riley_no_oak_flow", not bool(result.get("needs_oak_flow", true)))
	_check("bootflow_riley_starts_pallet", str(result.get("start_map", "")) == "PalletTown")
	var state: Dictionary = result.get("state", {})
	var bag: Dictionary = state.get("bag", {})
	_check("bootflow_riley_omni_ring_in_bag", int(bag.get("omni_ring", 0)) == 1)
	_check("bootflow_channels_published", (BagScene.save_state as Dictionary).size() == state.size() and (PartyScene.party as Array).size() == 6)


func _test_bootflow_custom() -> void:
	var result: Dictionary = PUWBootFlow.new_game("custom_female", "Ash")
	_check("bootflow_custom_ok", bool(result.get("ok", false)))
	_check("bootflow_custom_party_empty", (result.get("party", []) as Array).is_empty())
	_check("bootflow_custom_needs_oak_flow", bool(result.get("needs_oak_flow", false)))
	_check("bootflow_custom_starts_oak_lab", str(result.get("start_map", "")) == "OaksLab")


func _test_bootflow_continue_roundtrip() -> void:
	PUWSaveManager.delete_save()
	var missing: Dictionary = PUWBootFlow.continue_game()
	_check("continue_no_save_refused", not bool(missing.get("ok", true)))
	var made: Dictionary = PUWBootFlow.new_game("tasha", "Tasha")
	var state: Dictionary = made.get("state", {})
	PUWBootFlow.record_current_map(state, "Route1")
	_check("continue_save_written", PUWSaveManager.save_game(state))
	var back: Dictionary = PUWBootFlow.continue_game()
	_check("continue_ok", bool(back.get("ok", false)))
	_check("continue_party_six", (back.get("party", []) as Array).size() == 6)
	_check("continue_returns_to_saved_map", str(back.get("start_map", "")) == "Route1")
	_check("continue_cast_remembered", str(back.get("cast_id", "")) == "tasha")
	PUWSaveManager.delete_save()
	_check("continue_cleanup", not PUWSaveManager.has_save())


# ----------------------------------------------------------------
# The host session on Pallet Town: boot, walk, talk, menu,
# then Route 1 for the wild battle hand-off and return.
# ----------------------------------------------------------------

func _test_host_pallet_session() -> void:
	var made: Dictionary = PUWBootFlow.new_game("riley", "Riley")
	var state: Dictionary = made.get("state", {})
	var party: Array = made.get("party", [])
	var host: PUWGameHost = PUWGameHost.new()
	root.add_child(host)
	await process_frame
	var report: Dictionary = host.boot(state, party, "PalletTown", "riley")
	_check("host_boot_ok", bool(report.get("ok", false)))
	if not bool(report.get("ok", false)):
		print("  boot report: ", report)
	_check("host_current_map", host.current_map == "PalletTown")
	_check("host_systems_live", host.glue != null and host.glue.player != null and host.glue.spawner != null and host.menu_host != null and host.dialogue_box != null and host.music_director != null and host.event_runner != null)
	print("  boot report: npc_views=", report.get("npc_views", -1), " follower_views=", report.get("follower_views", -1), " ambient=", report.get("ambient_tiles", -1))
	_check("host_npc_views_attached", int(report.get("npc_views", 0)) >= 1)
	_check("host_follower_view_attached", int(report.get("follower_views", 0)) == 1)
	_check("host_ambient_animator_live", host.glue.map_loader.ambient_animator != null and host.glue.map_loader.ambient_animator.active_cycle_count() >= 1)

	# The menu host was fed the live state at boot: the X-menu
	# header carries the player's real name, never the staged
	# demo clock.
	var xmenu: PUWXMenuScreen = host.menu_host.xmenu
	_check("host_xmenu_bound_name", str(xmenu.trainer.get("name", "")) == "Riley")
	_check("host_xmenu_no_demo_time", not xmenu.trainer.has("time") and xmenu._state_text().find("12:47") < 0)
	var omni_held: bool = false
	for row_v in PUWLiveBag.holdings_for_screen(state):
		var row: Dictionary = row_v
		if str(row.get("slug", "")) == "omni_ring" and int(row.get("qty", 0)) == 1:
			omni_held = true
	_check("host_bag_holdings_live", omni_held)

	# Walk: at least one direction must move the player tile.
	var start_pos: Vector2 = host.glue.player.position
	var moved: bool = false
	var dirs: Array = ["puw_right", "puw_down", "puw_left", "puw_up"]
	for action in dirs:
		Input.action_press(action)
		for i in range(40):
			host.host_tick(0.1)
		Input.action_release(action)
		if host.glue.player.position.distance_to(start_pos) > 4.0:
			moved = true
			break
	_check("host_walk_moves_player", moved)
	_check("host_follower_records_tick", host.glue.followers.behavior_tick(0.1, host.glue.player.position, host.glue.player.facing, false).size() == 1)

	# Talk: the Pallet Town girl, a real bank line through the
	# real box.
	var girl: Node2D = null
	for child in host.glue.get_children():
		if child.has_meta("dialogue_ref") and str(child.get_meta("dialogue_ref")) == "TEXT_PALLETTOWN_GIRL":
			girl = child
			break
	_check("host_girl_spawned", girl != null)
	if girl != null:
		var girl_tile: Vector2i = girl.get_meta("tile")
		host.glue.player.place_at_tile(girl_tile + Vector2i(0, 1))
		host.glue.player.facing = "up"
		var talk: Dictionary = host.try_interact()
		_check("host_talk_found", bool(talk.get("found", false)))
		_check("host_talk_box_showing", host.dialogue_box.is_showing())
		# The interaction resolves the faced placement's own
		# text_id through the spawner (the dialogue prep's
		# banks; for this girl the FRLG script text, not the
		# pokered bank entry her dialogue_ref names -- both are
		# held, the placement's id is the live one). The host
		# seam proven here: the box shows exactly the resolved
		# lines, in order, to the end.
		var resolved_texts: Array = []
		for line_value in talk.get("lines", []):
			if line_value is Dictionary:
				resolved_texts.append(str((line_value as Dictionary).get("text", "")))
			else:
				resolved_texts.append(str(line_value))
		_check("host_girl_lines_exist", not resolved_texts.is_empty())
		var shown_lines: Array = []
		var guard: int = 0
		while host.dialogue_box.is_showing() and guard < 200:
			guard += 1
			var current_text: String = host.dialogue_box.current_line_text()
			if shown_lines.is_empty() or str(shown_lines[shown_lines.size() - 1]) != current_text:
				shown_lines.append(current_text)
			host.advance_dialogue()
		_check("host_talk_box_closes", not host.dialogue_box.is_showing())
		var shown_joined: String = "\n".join(shown_lines)
		var resolved_joined: String = "\n".join(resolved_texts)
		if shown_joined != resolved_joined:
			print("  talk mismatch: shown=", shown_lines, " resolved=", resolved_texts)
		_check("host_talk_real_line", shown_joined == resolved_joined and shown_joined != "")

	# Menu opens and closes through the host.
	host.toggle_menu()
	_check("host_menu_opens", host.menu_host.is_open())
	host.toggle_menu()
	_check("host_menu_closes", not host.menu_host.is_open())

	# Wild battle: hand-off out on Route 1, return back.
	var hop: Dictionary = host.change_map("Route1")
	_check("host_change_map_route1", bool(hop.get("ok", false)))
	host.rng.seed = 20261124
	var captured: Array = []
	host.battle_requested.connect(func(handoff: Dictionary) -> void: captured.append(handoff))
	var wild: Dictionary = host.start_wild_battle("ROUTE_1", 300)
	_check("host_wild_battle_ok", bool(wild.get("ok", false)))
	if not bool(wild.get("ok", false)):
		print("  wild result: ", wild)
	_check("host_wild_signal_fired", captured.size() == 1 and str((captured[0] as Dictionary).get("kind", "")) == "wild")
	_check("host_wild_enemy_set", BattleScene.pending_enemy_party.size() == 1)
	_check("host_wild_player_set", BattleScene.pending_player_party.size() == 6)
	_check("host_wild_context_empty_wild", (BattleScene.pending_battle_context as Dictionary).is_empty())
	# The battle scene's return contract: it leaves the
	# post-battle party on PartyScene.party.
	PartyScene.party = host.party
	var back: Dictionary = host.apply_battle_return()
	_check("host_battle_return_ok", bool(back.get("ok", false)) and int(back.get("party_size", 0)) == 6)
	_check("host_battle_return_state_synced", (BagScene.save_state as Dictionary).size() == (host.state as Dictionary).size())
	host.queue_free()


# ----------------------------------------------------------------
# The Oak event through the host, for a custom character:
# the two picks are granted and the terminal warp lands the
# host on Pallet Town.
# ----------------------------------------------------------------

func _test_host_oak_event() -> void:
	var made: Dictionary = PUWBootFlow.new_game("custom_female", "Ash")
	var state: Dictionary = made.get("state", {})
	# The beats that precede the lab in the real flow: setup
	# completed, spawn recorded, home clues seen (the stitch's
	# own record calls, exactly as its suite stages them).
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	var party: Array = made.get("party", [])
	var host: PUWGameHost = PUWGameHost.new()
	root.add_child(host)
	await process_frame
	var report: Dictionary = host.boot(state, party, "OaksLab", "custom_female")
	_check("oak_host_boot_ok", bool(report.get("ok", false)))
	_check("oak_host_no_followers_yet", int(report.get("follower_views", -1)) == 0)

	var cast: Dictionary = {}
	for child in host.glue.get_children():
		if not child.has_meta("tile"):
			continue
		var tile: Vector2i = child.get_meta("tile")
		if tile == Vector2i(10, 4):
			cast["oak"] = child
		elif tile == Vector2i(8, 6):
			cast["rival"] = child
	_check("oak_cast_found_on_map", cast.has("oak") and cast.has("rival"))
	if not cast.has("starter_ball"):
		var ball: Node2D = Node2D.new()
		host.add_child(ball)
		cast["starter_ball"] = ball

	var totals: Dictionary = PUWCampaignStitch.rival_totals(state)
	var rival_name: String = ""
	for key_v in totals.keys():
		rival_name = str(key_v).capitalize()
	var script: Dictionary = PUWEventRunner.load_script_file("res://data/events/oak_lab_opening.json")
	_check("oak_script_loaded", not script.is_empty())
	var started: Dictionary = host.start_event(script, cast, {"<RIVAL>": rival_name})
	_check("oak_event_started", bool(started.get("ok", false)))
	if not bool(started.get("ok", false)):
		print("  start_event: ", started)

	var battle_ok: bool = true
	var battles: int = 0
	var guard: int = 0
	while guard < 400:
		guard += 1
		var drive: Dictionary = host._drive_event_to_pause()
		if bool(drive.get("finished", false)):
			break
		if str(drive.get("paused", "")) == "battle":
			battles += 1
			var handoff: Dictionary = host.start_event_battle()
			battle_ok = battle_ok and bool(handoff.get("ok", false))
			host.resolve_event_battle(true)
			continue
		if drive.has("error"):
			print("  drive error: ", drive)
			break
		if not host.event_runner.is_running():
			break
	_check("oak_event_battle_handed_off", battles == 1 and battle_ok)
	_check("oak_event_no_error", not host.event_runner.has_error())
	if host.event_runner.has_error():
		print("  runner error: ", host.event_runner.error_text())
	_check("oak_event_finished", host.event_runner.is_finished())
	var granted: Array = state.get("party", [])
	_check("oak_grant_two_picks", granted.size() == 2)
	if granted.size() == 2:
		_check("oak_grant_bulbasaur", int((granted[0] as Dictionary).get("species_id", 0)) == 1)
		_check("oak_grant_squirtle", int((granted[1] as Dictionary).get("species_id", 0)) == 7)
	_check("oak_stage_advanced", PUWCampaignStitch.stage(state) == "starter_chosen")
	_check("oak_five_poke_balls", int((state.get("bag", {}) as Dictionary).get("poke-ball", 0)) == 5)
	_check("oak_warp_landed_pallet", host.current_map == "PalletTown")
	_check("oak_warp_tile_is_lab_door", host.glue != null and host.glue.player.player_tile() == Vector2i(24, 22))
	_check("oak_input_restored", host.glue != null and host.glue.player.input_enabled)
	host.queue_free()


# ----------------------------------------------------------------
# The scene hand-off: pending_boot consumption by a host added
# to the tree, the host scene loading as a PackedScene, and
# the boot scene driving a real scene change into it.
# ----------------------------------------------------------------

func _test_pending_boot_and_scene() -> void:
	PUWBootFlow.pending_boot = PUWBootFlow.new_game("tasha", "Tasha")
	var host: PUWGameHost = PUWGameHost.new()
	root.add_child(host)
	await process_frame
	await process_frame
	_check("pending_boot_consumed", PUWBootFlow.pending_boot.is_empty())
	_check("pending_boot_host_booted", host.glue != null and host.current_map == "PalletTown")
	host.queue_free()
	await process_frame

	var packed: PackedScene = load("res://scenes/host/game_host.tscn")
	_check("host_scene_loads", packed != null)
	if packed != null:
		var instance: Node = packed.instantiate()
		_check("host_scene_is_game_host", instance is PUWGameHost)
		instance.free()

	var scene: PUWBootScene = PUWBootScene.new()
	root.add_child(scene)
	await process_frame
	scene._on_start_pressed()
	await process_frame
	await process_frame
	await process_frame
	# PM ruling (Bossy, 2026-11-24 23:41 CST): the boot
	# scene's default cast is custom_female, and custom
	# casts route to the character creator screen by
	# design (fold-in step 2.3) - the old direct-to-host
	# expectation is stale. Assert the directed routing:
	# a creator screen child appears on the boot scene.
	var creator_found: bool = false
	for child_node: Node in scene.get_children():
		if child_node is PUWCharacterCreatorScreen:
			creator_found = true
	_check("boot_scene_custom_routes_to_creator", creator_found)
	var current: Node = current_scene
	if current is PUWGameHost:
		var live_host: PUWGameHost = current
		_check("boot_scene_host_on_oak_lab", live_host.glue != null and live_host.current_map == "OaksLab")
