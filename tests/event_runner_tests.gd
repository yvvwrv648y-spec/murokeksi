extends SceneTree
## Event runner tests: the Oak's Lab opening played end-to-end
## on the real machinery (PUWCampaignStitch state + Oak grant,
## PUWSpawner dialogue over the real dialogue_database.json,
## PUWBattleEntry rival battle), plus gate / refusal / actor
## unit checks.
## Run: godot --headless --script res://tests/event_runner_tests.gd
##
## All expectations come from the real data files: the OaksLab
## dialogue entries (pokered text), the OaksLab map object
## tiles, campaign/oak_pool.json picks 1 + 7, data/rival.json
## RIVAL1, and the item id "poke-ball".

var _passed: int = 0
var _failed: int = 0
var _lines: Array = []
var _warps: Array = []


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _record_line(speaker: String, text: String) -> void:
	_lines.append({"speaker": speaker, "text": text})


func _record_warp(map_name: String, warp_id: int, _tile: Vector2i) -> void:
	_warps.append([map_name, warp_id])


func _fresh_state() -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "RED")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	return state


func _lab_actors() -> Dictionary:
	return {
		"player": PUWEventActor.create("player", Node2D.new(), Vector2i(10, 21), 8, "up"),
		"oak": PUWEventActor.create("oak", Node2D.new(), Vector2i(10, 4), 8, "down"),
		"rival": PUWEventActor.create("rival", Node2D.new(), Vector2i(8, 6), 8, "down"),
		"starter_ball": PUWEventActor.create("starter_ball", null, Vector2i(16, 6), 8, "down"),
	}


func _drive(runner: PUWEventRunner, battle_won: bool) -> Dictionary:
	var seen: Dictionary = {}
	var guard: int = 0
	while not runner.is_finished() and not runner.has_error() and guard < 20000:
		guard += 1
		if runner.is_waiting_line():
			runner.advance_line()
		elif runner.is_waiting_battle():
			seen = runner.pending_battle()
			runner.resolve_battle(battle_won)
		else:
			runner.tick(0.05)
	return seen


func _dialogue_entry(label: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_database.json"))
	if not (parsed is Dictionary):
		return ""
	var groups_v: Variant = (parsed as Dictionary).get("groups", {})
	if not (groups_v is Dictionary):
		return ""
	var group_v: Variant = (groups_v as Dictionary).get("OaksLab", {})
	if not (group_v is Dictionary):
		return ""
	var entries_v: Variant = (group_v as Dictionary).get("entries", {})
	if not (entries_v is Dictionary):
		return ""
	return str((entries_v as Dictionary).get(label, ""))


func _expected_line(label: String, rival_name: String) -> String:
	return _dialogue_entry(label).replace("<PLAYER>", "RED").replace("<RIVAL>", rival_name)


func _init() -> void:
	# ------------------------------------------------------------
	# The fixture, win path, end to end.
	# ------------------------------------------------------------
	var state: Dictionary = _fresh_state()
	_check("setup_stage_clues_seen", PUWCampaignStitch.stage(state) == "clues_seen")
	_check("setup_party_empty", (state.get("party", []) as Array).is_empty())
	var totals: Dictionary = PUWCampaignStitch.rival_totals(state)
	var rival_name: String = ""
	for key_v in totals.keys():
		rival_name = str(key_v).capitalize()
	_check("rival_name_from_resolution", rival_name != "")

	var actors: Dictionary = _lab_actors()
	_lines = []
	_warps = []
	var runner: PUWEventRunner = PUWEventRunner.new()
	runner.configure(state, actors, {"present_line": Callable(self, "_record_line"), "on_warp": Callable(self, "_record_warp")}, {"<RIVAL>": rival_name}, 12345)
	var script: Dictionary = PUWEventRunner.load_script_file("res://data/events/oak_lab_opening.json")
	_check("script_loaded", not script.is_empty())
	_check("script_load_ok", bool(runner.load_script(script).get("ok", false)))
	_check("run_ok", bool(runner.run().get("ok", false)))
	var battle_seen: Dictionary = _drive(runner, true)
	_check("run_no_error", not runner.has_error())
	_check("run_finished", runner.is_finished())

	# The battle the runner paused on: a real layer-built rival
	# party through the hand-off guard's own validator.
	_check("battle_kind_rival", str(battle_seen.get("kind", "")) == "rival")
	_check("battle_ok", bool(battle_seen.get("ok", false)))
	var enemy_v: Variant = battle_seen.get("enemy_party", [])
	var enemy: Array = enemy_v if enemy_v is Array else []
	_check("battle_party_built", enemy.size() >= 1)
	_check("battle_party_valid", bool(PUWBattleEntry.validate_built_party(enemy, 0, {}).get("ok", false)))

	# Transcript: the exact sourced lines, in order, substituted.
	var win_labels: Array = [
		"_OaksLabRivalFedUpWithWaitingText", "_OaksLabOakChooseMonText",
		"_OaksLabRivalWhatAboutMeText", "_OaksLabOakBePatientText",
		"_OaksLabOak1WhichPokemonDoYouWantText", "_OaksLabOak1RaiseYourYoungPokemonText",
		"_OaksLabOak1ReceivedPokeballsText", "_OaksLabRivalIllTakeYouOnText",
		"_OaksLabRivalIPickedTheWrongPokemonText", "_OaksLabRivalSmellYouLaterText",
	]
	var win_speakers: Array = ["rival", "oak", "rival", "oak", "oak", "oak", "oak", "rival", "rival", "rival"]
	_check("transcript_line_count", _lines.size() == win_labels.size())
	var transcript_ok: bool = _lines.size() == win_labels.size()
	for i in range(win_labels.size()):
		if i >= _lines.size():
			break
		var line: Dictionary = _lines[i]
		if str(line.get("speaker", "")) != str(win_speakers[i]):
			transcript_ok = false
		if str(line.get("text", "")) != _expected_line(str(win_labels[i]), rival_name):
			transcript_ok = false
	_check("transcript_exact_sourced_lines", transcript_ok)
	var any_token_left: bool = false
	for line_v in _lines:
		if str((line_v as Dictionary).get("text", "")).contains("<PLAYER>"):
			any_token_left = true
	_check("transcript_player_token_substituted", not any_token_left)

	# The grant really happened, through the stitch.
	var party: Array = state.get("party", [])
	_check("party_two_grants", party.size() == 2)
	if party.size() == 2:
		_check("grant_pick_1_bulbasaur", int((party[0] as Dictionary).get("species_id", 0)) == 1)
		_check("grant_pick_2_squirtle", int((party[1] as Dictionary).get("species_id", 0)) == 7)
	_check("stage_starter_chosen", PUWCampaignStitch.stage(state) == "starter_chosen")
	_check("oak_picks_done", PUWCampaignStitch.oak_picks_done(state))
	var bag: Dictionary = state.get("bag", {})
	_check("gave_five_poke_balls", int(bag.get("poke-ball", 0)) == 5)
	_check("omni_ring_untouched", int(bag.get("omni_ring", 0)) == 1)

	# Actors, camera, fade, warp, once-flag: the scene state the
	# script promised.
	var rival_rig: PUWEventActor = actors["rival"]
	var player_rig: PUWEventActor = actors["player"]
	_check("rival_walked_to_door", rival_rig.tile == Vector2i(10, 21))
	_check("rival_despawned", not rival_rig.is_visible)
	_check("player_at_ball_row", player_rig.tile == Vector2i(15, 5))
	_check("player_facing_down", player_rig.facing == "down")
	_check("camera_released_to_player", str(runner.camera_state.get("target", "")) == "player")
	_check("faded_to_black_for_warp", absf(runner.fade_level - 1.0) < 0.001)
	_check("warp_fired_to_pallet", _warps.size() == 1 and str(_warps[0][0]) == "PalletTown" and int(_warps[0][1]) == 3)
	var flags: Dictionary = state.get("story_flags", {})
	_check("once_flag_set", bool(flags.get("oak_lab_opening_done", false)))

	# Replay refused.
	var runner2: PUWEventRunner = PUWEventRunner.new()
	runner2.configure(state, actors, {}, {"<RIVAL>": rival_name}, 12345)
	runner2.load_script(script)
	_check("replay_refused_once_flag", not bool(runner2.run().get("ok", true)))

	# ------------------------------------------------------------
	# The fixture, lose path: only the post-battle line changes.
	# ------------------------------------------------------------
	var state_l: Dictionary = _fresh_state()
	var actors_l: Dictionary = _lab_actors()
	_lines = []
	_warps = []
	var runner_l: PUWEventRunner = PUWEventRunner.new()
	runner_l.configure(state_l, actors_l, {"present_line": Callable(self, "_record_line"), "on_warp": Callable(self, "_record_warp")}, {"<RIVAL>": rival_name}, 999)
	runner_l.load_script(script)
	runner_l.run()
	_drive(runner_l, false)
	_check("lose_run_finished", runner_l.is_finished() and not runner_l.has_error())
	var lose_texts: Array = []
	for line_v2 in _lines:
		lose_texts.append(str((line_v2 as Dictionary).get("text", "")))
	_check("lose_line_is_am_i_great", lose_texts.has(_expected_line("_OaksLabRivalAmIGreatOrWhatText", rival_name)))
	_check("lose_line_not_wrong_pokemon", not lose_texts.has(_expected_line("_OaksLabRivalIPickedTheWrongPokemonText", rival_name)))
	_check("lose_grant_still_done", (state_l.get("party", []) as Array).size() == 2)

	# ------------------------------------------------------------
	# Requirements gate: the fixture refuses before clues_seen.
	# ------------------------------------------------------------
	var state_g: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "RED")
	PUWCampaignStitch.complete_setup(state_g)
	var runner_g: PUWEventRunner = PUWEventRunner.new()
	runner_g.configure(state_g, _lab_actors(), {}, {}, 7)
	runner_g.load_script(script)
	_check("gate_refuses_before_clues", not bool(runner_g.run().get("ok", true)))

	# ------------------------------------------------------------
	# Step modifiers + relative movement + inline say.
	# ------------------------------------------------------------
	var state_m: Dictionary = _fresh_state()
	var actors_m: Dictionary = _lab_actors()
	_lines = []
	var mod_script: Dictionary = {"id": "mod_test", "steps": [
		{"op": "say", "speaker": "test", "text": "SHOULD_NOT_SHOW", "if_flag": "never_set_flag"},
		{"op": "set_flag", "flag": "gate_open", "value": true},
		{"op": "say", "speaker": "test", "text": "SHOWN", "if_flag": "gate_open"},
		{"op": "say", "speaker": "test", "text": "ALSO_NOT_SHOWN", "if_not_flag": "gate_open"},
		{"op": "move", "actor": "player", "dir": "up", "tiles": 2},
		{"op": "face", "actor": "player", "dir": "left"},
		{"op": "wait", "seconds": 0.2},
	]}
	var runner_m: PUWEventRunner = PUWEventRunner.new()
	runner_m.configure(state_m, actors_m, {"present_line": Callable(self, "_record_line")}, {}, 7)
	runner_m.load_script(mod_script)
	runner_m.run()
	_drive(runner_m, true)
	_check("mod_finished", runner_m.is_finished() and not runner_m.has_error())
	_check("mod_only_gated_line_shown", _lines.size() == 1 and str((_lines[0] as Dictionary).get("text", "")) == "SHOWN")
	var player_m: PUWEventActor = actors_m["player"]
	_check("mod_relative_move", player_m.tile == Vector2i(10, 19))
	_check("mod_facing_left", player_m.facing == "left")

	# ------------------------------------------------------------
	# Refusals: unbuildable battle and unknown op halt honestly.
	# ------------------------------------------------------------
	var runner_b: PUWEventRunner = PUWEventRunner.new()
	runner_b.configure(_fresh_state(), _lab_actors(), {}, {}, 7)
	runner_b.load_script({"id": "bad_battle", "steps": [{"op": "battle", "entry": "scripted", "identity": []}]})
	runner_b.run()
	_check("empty_identity_battle_halts_with_error", runner_b.has_error() and not runner_b.is_finished())

	var runner_u: PUWEventRunner = PUWEventRunner.new()
	runner_u.configure(_fresh_state(), _lab_actors(), {}, {}, 7)
	runner_u.load_script({"id": "bad_op", "steps": [{"op": "explode"}]})
	runner_u.run()
	_check("unknown_op_halts_with_error", runner_u.has_error())

	# ------------------------------------------------------------
	# Actor rig units: waypoint path, facing from travel, turns.
	# ------------------------------------------------------------
	var rig: PUWEventActor = PUWEventActor.create("unit", null, Vector2i(0, 0), 8, "down")
	rig.queue_path([Vector2i(2, 0), Vector2i(2, 2)])
	var guard2: int = 0
	while rig.is_moving() and guard2 < 1000:
		guard2 += 1
		rig.tick(0.05)
	_check("rig_path_end_tile", rig.tile == Vector2i(2, 2))
	_check("rig_facing_from_travel", rig.facing == "down")
	rig.face_toward(Vector2i(5, 2))
	_check("rig_face_toward_right", rig.facing == "right")
	rig.place(Vector2i(1, 1))
	_check("rig_place_teleports", rig.tile == Vector2i(1, 1) and not rig.is_moving())

	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)
