extends SceneTree
## Champion-win wiring tests (Worker B, job (a)).
## Run: godot --headless --script res://tests/champion_wiring_tests.gd
##
## Proves PUWCampaignStitch.record_elite_four_win now calls
## PUWRegionState.record_champion_win(state, "kanto") at the
## Champion / Hall of Fame point:
## (1) before the champion flow completes, Kanto is NOT beaten;
## (2) after driving the stitch's Elite Four -> Champion
##     completion path (5 gauntlet wins), Kanto IS beaten:
##     PUWRegionState.region_beaten(state, "kanto") and the raw
##     state["regions"]["regions"]["kanto"]["champion_beaten"];
## (3) the flag survives a PUWSaveManager save/load round-trip.
## The badge-grant helper mirrors integration_campaign_tests'
## _grant_all_badges (availability requirements honestly met
## first); that suite and region_lock_tests are NOT edited.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _run_to_starter(cast_id: String) -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state(cast_id, "TEST")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	return state


func _grant_all_badges(state: Dictionary) -> void:
	var flags: Dictionary = state.get("story_flags", {})
	flags["ss_anne_cleared"] = true
	flags["saffron_access"] = true
	flags["silph_co_cleared"] = true
	flags["field_actions"] = ["cut"]
	state["story_flags"] = flags
	var bag: Dictionary = state.get("bag", {})
	bag["hm01"] = 1
	bag["secret_key"] = 1
	state["bag"] = bag
	for gym_value: Variant in PUWCampaignStitch.gym_order():
		PUWCampaignStitch.record_gym_win(state, str(gym_value))


func _raw_champion_beaten(state: Dictionary) -> bool:
	return _raw_champion_beaten_for(state, "kanto")


func _raw_champion_beaten_for(state: Dictionary, region_id: String) -> bool:
	var root_value: Variant = state.get("regions", {})
	if not (root_value is Dictionary):
		return false
	var root: Dictionary = root_value
	var records_value: Variant = root.get("regions", {})
	if not (records_value is Dictionary):
		return false
	var records: Dictionary = records_value
	var record_value: Variant = records.get(region_id, {})
	if not (record_value is Dictionary):
		return false
	var record: Dictionary = record_value
	return bool(record.get("champion_beaten", false))


func _init() -> void:
	print("PUW champion wiring tests -- starting.")
	var state: Dictionary = _run_to_starter("custom_female")
	# Binding build 4 (starter system C3): the trio picker is
	# superseded for custom characters -- the starter beat is
	# the Oak grant flow (two picks).
	var grants: Array = PUWCampaignStitch.grant_oak_picks(state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"})
	_check("champion_wiring_starter_chosen", grants.size() == 2)
	# Grow the regions structure on the real save shape.
	PUWRegionState.enter_region(state, "kanto")

	# (1) Before the champion flow completes: not beaten.
	_check("champion_wiring_kanto_not_beaten_at_start", not PUWRegionState.region_beaten(state, "kanto"))
	_check("champion_wiring_raw_flag_false_at_start", not _raw_champion_beaten(state))

	_grant_all_badges(state)
	_check("champion_wiring_eight_badges", GymProgression.badge_count(state) == 8)
	_check("champion_wiring_gatekeeper_win", PUWCampaignStitch.record_gatekeeper_win(state))
	_check("champion_wiring_runner_up_win", PUWCampaignStitch.record_runner_up_win(state))
	_check("champion_wiring_e4_starts", PUWCampaignStitch.start_elite_four(state))
	_check("champion_wiring_kanto_not_beaten_after_e4_start", not PUWRegionState.region_beaten(state, "kanto"))

	# Four Elite Four wins: still not the Champion.
	for i: int in range(4):
		PUWCampaignStitch.record_elite_four_win(state)
	_check("champion_wiring_stage_still_elite_four_after_4_wins", PUWCampaignStitch.stage(state) == "elite_four")
	_check("champion_wiring_kanto_not_beaten_after_4_wins", not PUWRegionState.region_beaten(state, "kanto"))

	# (2) Fifth win is the Champion: Kanto becomes beaten.
	_check("champion_wiring_fifth_win_records", PUWCampaignStitch.record_elite_four_win(state))
	_check("champion_wiring_stage_hall_of_fame", PUWCampaignStitch.stage(state) == "hall_of_fame")
	_check("champion_wiring_kanto_beaten_after_champion", PUWRegionState.region_beaten(state, "kanto"))
	_check("champion_wiring_raw_flag_true_after_champion", _raw_champion_beaten(state))

	# (3) Save/load round-trip keeps the flag.
	PUWSaveManager.delete_save()
	_check("champion_wiring_save_written", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("champion_wiring_loaded_not_empty", not loaded.is_empty())
	_check("champion_wiring_kanto_beaten_after_roundtrip", PUWRegionState.region_beaten(loaded, "kanto"))
	_check("champion_wiring_raw_flag_true_after_roundtrip", _raw_champion_beaten(loaded))
	_check("champion_wiring_stage_after_roundtrip", PUWCampaignStitch.stage(loaded) == "hall_of_fame")
	PUWSaveManager.delete_save()

	# --- Johto case (binding build 3): the same gauntlet driven with
	# the campaign region set to Johto must beat JOHTO (Lance's
	# league), never Kanto — the champion call is parameterized on
	# the story flag region_id, not a region literal.
	var jstate: Dictionary = _run_to_starter("custom_male")
	PUWCampaignStitch.grant_oak_picks(jstate, {"species_id": 1, "variant": "pokemon"}, {"species_id": 7, "variant": "pokemon"})
	PUWRegionState.enter_region(jstate, "johto")
	PUWCampaignStitch.set_region(jstate, "johto")
	_check("champion_wiring_johto_not_beaten_at_start", not PUWRegionState.region_beaten(jstate, "johto"))
	_grant_all_badges(jstate)
	_check("champion_wiring_johto_gatekeeper_win", PUWCampaignStitch.record_gatekeeper_win(jstate))
	_check("champion_wiring_johto_runner_up_win", PUWCampaignStitch.record_runner_up_win(jstate))
	_check("champion_wiring_johto_e4_starts", PUWCampaignStitch.start_elite_four(jstate))
	for i: int in range(4):
		PUWCampaignStitch.record_elite_four_win(jstate)
	_check("champion_wiring_johto_not_beaten_after_4_wins", not PUWRegionState.region_beaten(jstate, "johto"))
	_check("champion_wiring_johto_fifth_win_records", PUWCampaignStitch.record_elite_four_win(jstate))
	_check("champion_wiring_johto_beaten_after_champion", PUWRegionState.region_beaten(jstate, "johto"))
	_check("champion_wiring_johto_raw_flag_true", _raw_champion_beaten_for(jstate, "johto"))
	_check("champion_wiring_kanto_still_not_beaten_in_johto_run", not PUWRegionState.region_beaten(jstate, "kanto"))

	# --- Ranger finale cases (binding build 4, Styler merge
	# step 5): Fiore / Almia / Oblivia finales are
	# Champion-equivalent gates. PUWStylerSystem.complete_mission
	# with is_finale wires to PUWRegionState.record_champion_win
	# for the ACTIVE region and grants NO badge, ever. A
	# non-finale mission opens nothing.
	for region_value: Variant in ["fiore", "almia", "oblivia"]:
		var region_id: String = str(region_value)
		var rstate: Dictionary = _run_to_starter("custom_female")
		PUWRegionState.enter_region(rstate, region_id)
		_check("champion_wiring_%s_not_beaten_at_start" % region_id, not PUWRegionState.region_beaten(rstate, region_id))
		_check("champion_wiring_%s_raw_flag_false_at_start" % region_id, not _raw_champion_beaten_for(rstate, region_id))
		var plain: Dictionary = PUWStylerSystem.complete_mission(rstate, {"id": "acceptance_plain_mission", "is_finale": false})
		_check("champion_wiring_%s_plain_mission_ok" % region_id, bool(plain.get("ok", false)))
		_check("champion_wiring_%s_plain_mission_no_gate" % region_id, not bool(plain.get("gate_opened", true)))
		_check("champion_wiring_%s_not_beaten_after_plain_mission" % region_id, not PUWRegionState.region_beaten(rstate, region_id))
		var finale: Dictionary = PUWStylerSystem.complete_mission(rstate, {"id": "acceptance_finale", "is_finale": true})
		_check("champion_wiring_%s_finale_ok" % region_id, bool(finale.get("ok", false)))
		_check("champion_wiring_%s_finale_opens_gate" % region_id, bool(finale.get("gate_opened", false)))
		_check("champion_wiring_%s_beaten_after_finale" % region_id, PUWRegionState.region_beaten(rstate, region_id))
		_check("champion_wiring_%s_raw_flag_true_after_finale" % region_id, _raw_champion_beaten_for(rstate, region_id))
		_check("champion_wiring_%s_no_badges_from_ranger_track" % region_id, GymProgression.badge_count(rstate) == 0 and PUWRegionState.region_badges(rstate, region_id).is_empty())

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
