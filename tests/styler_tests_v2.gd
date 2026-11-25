extends SceneTree
## Styler V2 sourced-data tests (2026-11-23): pins hunt
## rotation 7's sourced values against the revised prep --
## per-region level tables (endpoints + totals), the Ranger
## Points economy arithmetic incl. the 2,100 / 2,101 buyout,
## Field Move caps incl. Gust's absence in Almia, the Oblivia
## past track's separation, per-species Browser data loaded
## from the landed JSONs, and the design constants rotation 7
## left unsourced (still DCs, unchanged).
## Run: godot --headless --script res://tests/styler_tests_v2.gd

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _finish() -> void:
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _init() -> void:
	_run.call_deferred()


func _fresh_state() -> Dictionary:
	var party: Array = [{"name": "pikachu", "species": "pikachu", "mon_id": "puw-000001-a1b2c3", "evo_family": "pikachu_family", "hp": 20, "max_hp": 20, "friendship": 0}]
	var boxes: Array = []
	var flags: Dictionary = {"region_id": "kanto"}
	var state: Dictionary = PUWSaveManager.build_state(party, boxes, {"poke-ball": 5}, 1000, [], [], [], flags, {})
	PUWRegionState.ensure_regions(state)
	return state


func _load(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _run() -> void:
	_test_level_tables()
	_test_past_track()
	_test_rp_economy()
	_test_field_moves()
	_test_species_data()
	_test_design_constants_remain()
	_finish()


func _test_level_tables() -> void:
	_check("v2_fiore_table_20_rows", PUWStylerLevelTables.table_for("fiore").size() == 20)
	_check("v2_fiore_endpoints", PUWStylerSystem.energy_max("fiore", 1) == 4 and PUWStylerSystem.energy_max("fiore", 20) == 60 and PUWStylerSystem.line_length("fiore", 1) == 100 and PUWStylerSystem.line_length("fiore", 20) == 200)
	_check("v2_fiore_exp_total", PUWStylerSystem.exp_for_level("fiore", 20) == 70800 and PUWStylerSystem.exp_for_level("fiore", 3) == 300)
	_check("v2_fiore_midtable_exact", PUWStylerSystem.energy_max("fiore", 13) == 34 and PUWStylerSystem.line_length("fiore", 13) == 160)
	_check("v2_almia_table_50_rows", PUWStylerLevelTables.table_for("almia").size() == 50)
	_check("v2_almia_endpoints", PUWStylerSystem.energy_max("almia", 1) == 10 and PUWStylerSystem.energy_max("almia", 50) == 104 and PUWStylerSystem.power_at_level("almia", 1) == 10 and PUWStylerSystem.power_at_level("almia", 50) == 205)
	_check("v2_almia_exp_total", PUWStylerSystem.exp_for_level("almia", 50) == 564113 and PUWStylerSystem.exp_for_level("almia", 2) == 44)
	_check("v2_almia_maxed_with_power_up_data", int(PUWStylerParams.params_for("almia").get("energy_maxed", 0)) == 109 and int(PUWStylerParams.params_for("almia").get("power_maxed", 0)) == 210)
	_check("v2_oblivia_table_99_rows", PUWStylerLevelTables.table_for("oblivia").size() == 99)
	_check("v2_oblivia_endpoints", PUWStylerSystem.energy_max("oblivia", 1) == 10 and PUWStylerSystem.energy_max("oblivia", 99) == 164 and PUWStylerSystem.power_at_level("oblivia", 1) == 10 and PUWStylerSystem.power_at_level("oblivia", 99) == 327)
	_check("v2_oblivia_exp_total", PUWStylerSystem.exp_for_level("oblivia", 99) == 3700829 and PUWStylerSystem.exp_for_level("oblivia", 2) == 50)
	# A fresh Almia capture loop gains exactly the sourced L1 Power.
	var state: Dictionary = _fresh_state()
	PUWRegionState.enter_region(state, "almia")
	var session: Dictionary = PUWStylerSystem.begin_capture(state, {"species": "bidoof", "types": ["normal"], "friendship_required": 100000.0, "location_id": "test"})
	var loop_result: Dictionary = PUWStylerSystem.session_loop(state, session)
	_check("v2_almia_first_loop_gain_is_sourced_power_10", absf(float(loop_result.get("gain", 0.0)) - 10.0) < 0.001)


func _test_past_track() -> void:
	_check("v2_past_table_99_rows", PUWStylerLevelTables.table_for("oblivia", "past").size() == 99)
	_check("v2_past_endpoints", PUWStylerSystem.energy_max("oblivia", 1, "past") == 30 and PUWStylerSystem.energy_max("oblivia", 99, "past") == 250 and PUWStylerSystem.power_at_level("oblivia", 1, "past") == 5 and PUWStylerSystem.power_at_level("oblivia", 99, "past") == 300)
	_check("v2_past_exp_total", PUWStylerSystem.exp_for_level("oblivia", 99, "past") == 547546)
	_check("v2_past_params_separate", int(PUWStylerParams.OBLIVIA_PAST.get("styler_levels", 0)) == 99 and int(PUWStylerParams.OBLIVIA_PAST.get("energy_base", 0)) == 30)
	var state: Dictionary = _fresh_state()
	PUWRegionState.enter_region(state, "oblivia")
	_check("v2_past_starts_independent", PUWStylerSystem.past_styler_level(state) == 1 and PUWStylerSystem.past_energy(state) == 30 and PUWStylerSystem.past_power(state) == 5 and PUWStylerSystem.styler_level(state) == 1 and PUWStylerSystem.current_energy(state) == 10)
	PUWStylerSystem.award_past_styler_exp(state, 547546)
	_check("v2_past_levels_alone", PUWStylerSystem.past_styler_level(state) == 99 and PUWStylerSystem.past_energy(state) == 250 and PUWStylerSystem.past_power(state) == 300)
	_check("v2_present_untouched_by_past", PUWStylerSystem.styler_level(state) == 1 and PUWStylerSystem.current_energy(state) == 10)
	PUWStylerSystem.award_styler_exp(state, 50)
	_check("v2_present_levels_alone", PUWStylerSystem.styler_level(state) == 2 and PUWStylerSystem.past_styler_level(state) == 99)


func _test_rp_economy() -> void:
	_check("v2_rp_economy_arithmetic", PUWStylerParams.POINTS_SRANK_SPECIES_TOTAL * PUWStylerParams.POINTS_PER_SRANK_SPECIES + 16 * PUWStylerParams.POINTS_PER_MISSION_CLEAR + PUWStylerParams.POINTS_QUEST_TOTAL == PUWStylerParams.POINTS_TOTAL_AVAILABLE and PUWStylerParams.POINTS_TOTAL_AVAILABLE == 2101)
	var track_sum: int = 0
	for track_value: Variant in PUWStylerParams.MODIFICATION_TRACKS.values():
		if track_value is Array:
			var prices: Array = track_value
			for price_value: Variant in prices:
				track_sum += int(price_value)
	_check("v2_rp_catalog_total_params", track_sum == 2100 and PUWStylerParams.MODIFICATION_CATALOG_TOTAL == 2100)
	_check("v2_rp_catalog_total_from_landed_json", PUWStylerSpeciesData.modification_catalog_total(_load("res://data/oblivia_styler_modification.json")) == 2100)
	_check("v2_rp_spare_is_exactly_1", PUWStylerParams.POINTS_TOTAL_AVAILABLE - track_sum == 1)
	var unresolved: Dictionary = PUWStylerParams.OBLIVIA_MISSION_COUNT_UNRESOLVED
	_check("v2_mission_count_unresolved_flagged", not bool(unresolved.get("resolved", true)) and int(unresolved.get("register_ranger_deep", 0)) == 14 and int(unresolved.get("economy_table_r7", 0)) == 16)
	# All 301 species S-Rank awards accumulate to exactly 301.
	var state: Dictionary = _fresh_state()
	PUWRegionState.enter_region(state, "oblivia")
	for i in 301:
		PUWStylerSystem.award_srank_points(state, "species_%d" % i)
	_check("v2_rp_301_species_route", PUWStylerSystem.points(state) == 301)
	# Full buyout: 2,101 in, 2,100 spent, 1 left, tracks maxed.
	var rich: Dictionary = _fresh_state()
	PUWRegionState.enter_region(rich, "oblivia")
	var ranger: Dictionary = PUWStylerSystem.ranger_state(rich)
	ranger["points"] = 2101
	var buys: int = 0
	for track_id_value: Variant in PUWStylerParams.MODIFICATION_TRACKS.keys():
		var track_id: String = str(track_id_value)
		var guard: int = 0
		while guard < 20:
			guard += 1
			var result: Dictionary = PUWStylerSystem.buy_modification(rich, track_id)
			if not bool(result.get("ok", false)):
				break
			buys += 1
	_check("v2_rp_buyout_buys_33_levels", buys == 33)
	_check("v2_rp_buyout_leaves_exactly_1", PUWStylerSystem.points(rich) == 1)
	var after: Dictionary = PUWStylerSystem.buy_modification(rich, "energy_plus")
	_check("v2_rp_buyout_tracks_maxed", not bool(after.get("ok", true)) and str(after.get("reason", "")) == "track_maxed")


func _test_field_moves() -> void:
	var almia: Dictionary = PUWStylerParams.field_moves_for("almia")
	_check("v2_almia_gust_absent", not almia.has("gust"))
	_check("v2_almia_cross_absent", not almia.has("cross"))
	_check("v2_almia_caps", int(almia.get("burn", 0)) == 5 and int(almia.get("crush", 0)) == 5 and int(almia.get("cut", 0)) == 5 and int(almia.get("recharge", 0)) == 5 and int(almia.get("tackle", 0)) == 5 and int(almia.get("electrify", 0)) == 3 and int(almia.get("psy_power", 0)) == 3 and int(almia.get("soak", 0)) == 3 and int(almia.get("tunnel", 0)) == 1)
	var almia_specific: Array = PUWStylerParams.species_specific_moves_for("almia")
	_check("v2_almia_species_specific_moves", almia_specific.has("teleport") and almia_specific.has("swim") and almia_specific.has("magma_flow") and almia_specific.has("dark_power") and almia_specific.has("fly") and almia_specific.has("rain_dance"))
	var oblivia: Dictionary = PUWStylerParams.field_moves_for("oblivia")
	_check("v2_oblivia_caps_differ_from_almia", int(oblivia.get("burn", 0)) == 4 and int(oblivia.get("crush", 0)) == 4 and int(oblivia.get("cut", 0)) == 4 and int(oblivia.get("tackle", 0)) == 4 and int(oblivia.get("recharge", 0)) == 5 and int(oblivia.get("electrify", 0)) == 3)
	_check("v2_oblivia_species_specific", PUWStylerParams.species_specific_moves_for("oblivia").has("fly") and PUWStylerParams.species_specific_moves_for("oblivia").has("teleport"))
	var fiore: Dictionary = PUWStylerParams.field_moves_for("fiore")
	_check("v2_fiore_moves_confirmed", int(fiore.get("gust", 0)) == 3 and int(fiore.get("cross", 0)) == 1 and int(fiore.get("flash", 0)) == 1)


func _test_species_data() -> void:
	var fiore_records: Array = PUWStylerSpeciesData.parse_browser_json(_load("res://data/fiore_browser.json"))
	_check("v2_fiore_browser_168_rows", fiore_records.size() == 168)
	var metagross_f: Dictionary = PUWStylerSpeciesData.find_species(fiore_records, "metagross")
	_check("v2_fiore_metagross_30_loops", int(metagross_f.get("loops_required", 0)) == 30 and not metagross_f.has("gauge_points"))
	var almia_records: Array = PUWStylerSpeciesData.parse_browser_json(_load("res://data/almia_browser.json"))
	_check("v2_almia_browser_270_rows", almia_records.size() == 270)
	var pikachu_a: Dictionary = PUWStylerSpeciesData.find_species(almia_records, "pikachu")
	_check("v2_almia_pikachu_gauge_contexts", (pikachu_a.get("gauge_points", []) as Array) == [645, 60])
	var wailord: Dictionary = PUWStylerSpeciesData.find_species(almia_records, "wailord")
	_check("v2_almia_wailord_na_gauge_empty_not_zero", (wailord.get("gauge_points", [1]) as Array).is_empty())
	var garchomp_a: Dictionary = PUWStylerSpeciesData.find_species(almia_records, "garchomp")
	_check("v2_almia_garchomp_crush_5", int((garchomp_a.get("field_moves", {}) as Dictionary).get("crush", 0)) == 5)
	var oblivia_records: Array = PUWStylerSpeciesData.parse_browser_json(_load("res://data/oblivia_browser_present.json"))
	_check("v2_oblivia_browser_279_rows", oblivia_records.size() == 279)
	var agitated_count: int = 0
	for record_value: Variant in oblivia_records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if bool(record.get("has_agitated_gauge", false)):
				agitated_count += 1
	_check("v2_oblivia_agitated_rows_93", agitated_count == 93)
	var pichu_o: Dictionary = PUWStylerSpeciesData.find_browser_no(oblivia_records, "R-004")
	_check("v2_oblivia_pichu_agitated_60_of_100", (pichu_o.get("agitated_gauge_points", []) as Array) == [60] and (pichu_o.get("gauge_points", []) as Array) == [100])
	var feraligatr: Dictionary = PUWStylerSpeciesData.find_species(oblivia_records, "feraligatr")
	_check("v2_oblivia_feraligatr_agitated_contexts", (feraligatr.get("agitated_gauge_points", []) as Array) == [2800, 6133])
	var garchomp_o: Dictionary = PUWStylerSpeciesData.find_species(oblivia_records, "garchomp")
	_check("v2_oblivia_garchomp_crush_1_not_almia_5", int((garchomp_o.get("field_moves", {}) as Dictionary).get("crush", 0)) == 1)
	# The session carries the agitated dimension as data.
	var state: Dictionary = _fresh_state()
	PUWRegionState.enter_region(state, "oblivia")
	var target: Dictionary = {"species": "pichu", "types": ["electric"], "friendship_required": 100.0, "gauge_points": [100], "agitated_gauge_points": [60], "location_id": "test"}
	var session: Dictionary = PUWStylerSystem.begin_capture(state, target)
	_check("v2_session_agitated_requirement_carried", absf(PUWStylerSystem.session_agitated_requirement(session) - 60.0) < 0.001)
	# Field Move string parsing.
	var parsed_levelled: Dictionary = PUWStylerSpeciesData.parse_field_move("Crush 5")
	_check("v2_parse_field_move_levelled", str(parsed_levelled.get("move_id", "")) == "crush" and int(parsed_levelled.get("level", 0)) == 5 and bool(parsed_levelled.get("levelled", false)))
	var parsed_specific: Dictionary = PUWStylerSpeciesData.parse_field_move("Teleport")
	_check("v2_parse_field_move_species_specific", str(parsed_specific.get("move_id", "")) == "teleport" and not bool(parsed_specific.get("levelled", true)))
	_check("v2_parse_field_move_none", PUWStylerSpeciesData.parse_field_move("None").is_empty())
	# Power-Up Data + quest structure files land consistently.
	var power_ups: Variant = JSON.parse_string(_load("res://data/almia_power_up_data.json"))
	var power_up_count: int = -1
	if power_ups is Dictionary:
		var pu_root: Dictionary = power_ups
		var pu_list_value: Variant = pu_root.get("power_ups", [])
		if pu_list_value is Array:
			var pu_list: Array = pu_list_value
			power_up_count = pu_list.size()
	_check("v2_almia_power_up_data_25_entries", power_up_count == 25)
	var quests: Variant = JSON.parse_string(_load("res://data/quest_mission_structure.json"))
	var quest_ok: bool = false
	if quests is Dictionary:
		var q_root: Dictionary = quests
		var q_almia_value: Variant = q_root.get("almia", {})
		var q_oblivia_value: Variant = q_root.get("oblivia", {})
		if q_almia_value is Dictionary and q_oblivia_value is Dictionary:
			var q_almia: Dictionary = q_almia_value
			var q_oblivia: Dictionary = q_oblivia_value
			var qa_value: Variant = q_almia.get("quests", {})
			var qo_value: Variant = q_oblivia.get("quests", {})
			if qa_value is Dictionary and qo_value is Dictionary:
				var qa: Dictionary = qa_value
				var qo: Dictionary = qo_value
				quest_ok = int(qa.get("count_total", 0)) == 61 and int(qa.get("count_completable", 0)) == 60 and int(qo.get("count_total", 0)) == 52
	_check("v2_quest_structure_counts", quest_ok)


func _test_design_constants_remain() -> void:
	_check("v2_dc_uninterrupted_loop_power", PUWStylerParams.UNINTERRUPTED_LOOP_POWER == 10 and PUWStylerParams.UNINTERRUPTED_LOOP_CAP == 6)
	_check("v2_dc_assist_fraction_and_stages", absf(PUWStylerParams.ASSIST_GAUGE_FRACTION - 0.15) < 0.001 and absf(float(PUWStylerParams.ASSIST_STAGE_MULT.get(2, 0.0)) - 1.75) < 0.001 and absf(float(PUWStylerParams.ASSIST_STAGE_DURATION.get(3, 0.0)) - 50.0) < 0.001)
	_check("v2_dc_partner_values", PUWStylerParams.FIORE_LOOPS_PER_PARTNER_SEGMENT == 10 and absf(PUWStylerParams.FIORE_DISCHARGE_STUN_PER_SEGMENT - 5.0) < 0.001 and absf(PUWStylerParams.PARTNER_GAUGE_FILL_PER_LOOP - 0.25) < 0.001)
	_check("v2_dc_assistant_rest_and_past_prices", absf(PUWStylerParams.ASSISTANT_REST_SECONDS - 10.0) < 0.001 and PUWStylerParams.PAST_TRACK_COST_PER_LEVEL == 100)
	var almia: Dictionary = PUWStylerParams.params_for("almia")
	var charge_value: Variant = almia.get("charge_mult", {})
	var charge: Dictionary = {}
	if charge_value is Dictionary:
		charge = charge_value
	_check("v2_dc_charge_and_drain_and_agitation", absf(float(charge.get(1, 0.0)) - 1.5) < 0.001 and absf(float(charge.get(2, 0.0)) - 2.0) < 0.001 and absf(float(almia.get("gauge_drain_fraction_per_sec", 0.0)) - 0.01) < 0.001 and absf(float(almia.get("agitation_power_mult", 0.0)) - 0.5) < 0.001)
