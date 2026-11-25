extends SceneTree
## Global habitat encounter tests (Phase 3 item E).
## Run: godot --headless --script res://tests/habitat_encounter_tests.gd
##
## Proves, against the REAL project data:
## (a) Caterpie is in the habitat pool of ROUTE_1, an area whose
##     ORIGINAL sourced table (data/wild_encounters.json) does NOT
##     contain Caterpie -- Route 1's sourced grass table is only
##     Pidgey/Rattata; Caterpie (Bug, PokeAPI habitat forest) fits
##     Route 1's grassland environment by type fit.
## (b) Beedrill is evolution-gated: not eligible at party_max 5,
##     eligible at party_max 10 (Kakuna -> Beedrill at level 10).
## (c) Type rotation in a small controlled pool, driven through the
##     direct eligibility API (deterministic, not statistical).
## (d) Equal odds: pool entries carry no weights.
## (e) Rotation state survives a PUWSaveManager save/load round-trip.
## (f) A habitat-rolled wild still builds at player_max +1..3 with
##     IV 31 through PUWTeamBuilder (the existing difficulty path).

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _pool_has(pool: Array, species_id: int) -> bool:
	for entry_v in pool:
		if entry_v is Dictionary and int((entry_v as Dictionary).get("species", 0)) == species_id:
			return true
	return false


func _init() -> void:
	print("PUW habitat encounter tests — starting.")
	var hab: PUWHabitatEncounters = PUWHabitatEncounters.new()
	_check("habitat_data_loaded", hab.load_data())
	# 1,025 PokeAPI species + the registry's 3 Gen 10 starters
	# (nat_dex 1026-1028, not in PokeAPI) = 1,028 known species.
	_check("species_roster_is_1028", hab.species_count() == 1028)
	_check("habitat_coverage_is_386_of_1025", hab.habitat_coverage_count() == 386)
	_check("route1_environment_is_grassland", hab.area_environments("ROUTE_1") == ["grassland"])
	_check("tower_1f_honestly_has_no_environment", hab.area_environments("POKEMON_TOWER_1F").is_empty())
	_check("tower_1f_pool_is_empty", hab.build_pool("POKEMON_TOWER_1F").is_empty())

	# ---- (a) Caterpie in a pool its sourced table never had ----
	var loop: OverworldLoop = OverworldLoop.new()
	var wild_text: String = FileAccess.get_file_as_string("res://data/wild_encounters.json")
	var wild_parsed: Variant = JSON.parse_string(wild_text)
	if wild_parsed is Dictionary:
		var wd: Dictionary = wild_parsed
		loop.set_wild_encounters_data(wd)
	var sourced_rows: Array = loop.wild_encounter_rows("ROUTE_1", "grass")
	var sourced_species: Array = []
	for row_v in sourced_rows:
		if row_v is Dictionary:
			sourced_species.append(str((row_v as Dictionary).get("species", "")))
	_check("route1_sourced_table_has_no_caterpie", not sourced_species.has("CATERPIE"))
	var caterpie_id: int = hab.species_id_for_slug("caterpie")
	_check("caterpie_id_is_10", caterpie_id == 10)
	var route1_pool: Array = hab.build_pool("ROUTE_1")
	_check("caterpie_in_route1_habitat_pool", _pool_has(route1_pool, caterpie_id))
	_check("route1_pool_is_global_not_the_sourced_list", route1_pool.size() > 100)

	# ---- (d) equal odds: no weights anywhere in the pool ----
	var no_weights: bool = true
	for entry_v in route1_pool:
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v
			if entry.has("weight") or entry.has("chance") or entry.has("rate"):
				no_weights = false
			if not entry.has("species") or not entry.has("dex_family"):
				no_weights = false
	_check("pool_entries_carry_no_weights", no_weights)
	var families: Dictionary = {}
	for entry_v2 in route1_pool:
		if entry_v2 is Dictionary:
			families[str((entry_v2 as Dictionary).get("dex_family", ""))] = true
	_check("pool_has_both_pkdx_and_mdx_entries", families.has("PKDX") and families.has("MDX"))

	# ---- (b) evolution gating: Beedrill ----
	var beedrill_id: int = hab.species_id_for_slug("beedrill")
	_check("beedrill_gate_is_10", hab.evolution_gate(beedrill_id) == 10)
	_check("caterpie_gate_is_0_base_species", hab.evolution_gate(caterpie_id) == 0)
	_check("beedrill_not_eligible_at_party_max_5", not hab.is_eligible("VIRIDIAN_FOREST", beedrill_id, 5))
	_check("beedrill_eligible_at_party_max_10", hab.is_eligible("VIRIDIAN_FOREST", beedrill_id, 10))

	# ---- (c) type rotation, controlled pool, direct API ----
	var rot: PUWHabitatEncounters = PUWHabitatEncounters.new()
	rot.load_data()
	var pidgey_id: int = rot.species_id_for_slug("pidgey")
	var rattata_id: int = rot.species_id_for_slug("rattata")
	var spearow_id: int = rot.species_id_for_slug("spearow")
	rot.set_pool_override("TEST_ROTATION", [
		{"species": pidgey_id, "slug": "pidgey", "dex_family": "PKDX", "types": ["Normal", "Flying"]},
		{"species": rattata_id, "slug": "rattata", "dex_family": "PKDX", "types": ["Normal"]},
		{"species": spearow_id, "slug": "spearow", "dex_family": "PKDX", "types": ["Normal", "Flying"]},
		{"species": caterpie_id, "slug": "caterpie", "dex_family": "PKDX", "types": ["Bug"]},
	])
	_check("rotation_pidgey_eligible_before_any_encounter", rot.is_eligible("TEST_ROTATION", pidgey_id, 100))
	rot.mark_encountered("TEST_ROTATION", pidgey_id)
	_check("rotation_pidgey_blocked_after_its_encounter", not rot.is_eligible("TEST_ROTATION", pidgey_id, 100))
	_check("rotation_unrelated_bug_species_stays_eligible", rot.is_eligible("TEST_ROTATION", caterpie_id, 100))
	var rng_c: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_c.seed = 99
	var rolled_c: Dictionary = rot.roll_habitat_encounter("TEST_ROTATION", 100, rng_c)
	_check("rotation_roll_never_returns_blocked_pidgey", int(rolled_c.get("species", 0)) != pidgey_id and not rolled_c.is_empty())
	# Drive the rest deterministically through the eligibility API on
	# a fresh builder so the roll above cannot interfere.
	var rot2: PUWHabitatEncounters = PUWHabitatEncounters.new()
	rot2.load_data()
	rot2.set_pool_override("TEST_ROTATION", [
		{"species": pidgey_id, "slug": "pidgey", "dex_family": "PKDX", "types": ["Normal", "Flying"]},
		{"species": rattata_id, "slug": "rattata", "dex_family": "PKDX", "types": ["Normal"]},
		{"species": spearow_id, "slug": "spearow", "dex_family": "PKDX", "types": ["Normal", "Flying"]},
		{"species": caterpie_id, "slug": "caterpie", "dex_family": "PKDX", "types": ["Bug"]},
	])
	rot2.mark_encountered("TEST_ROTATION", pidgey_id)
	rot2.mark_encountered("TEST_ROTATION", rattata_id)
	_check("rotation_pidgey_still_blocked_until_all_sharers_seen", not rot2.is_eligible("TEST_ROTATION", pidgey_id, 100))
	rot2.mark_encountered("TEST_ROTATION", spearow_id)
	_check("rotation_pidgey_eligible_again_once_all_sharers_seen", rot2.is_eligible("TEST_ROTATION", pidgey_id, 100))

	# ---- (e) rotation survives a save/load round-trip ----
	var saver: PUWHabitatEncounters = PUWHabitatEncounters.new()
	saver.load_data()
	saver.mark_encountered("ROUTE_1", caterpie_id)
	saver.mark_encountered("ROUTE_1", pidgey_id)
	var state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	saver.attach_rotation_to_save(state)
	PUWSaveManager.delete_save()
	_check("save_written_with_rotation", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	var restorer: PUWHabitatEncounters = PUWHabitatEncounters.new()
	restorer.load_data()
	restorer.restore_rotation_from_save(loaded)
	var restored: Dictionary = restorer.get_rotation_state()
	var restored_route1: Dictionary = restored.get("ROUTE_1", {})
	var restored_ids: Array = restored_route1.get("encountered", [])
	_check("rotation_state_survives_save_load", restored_ids.has(caterpie_id) and restored_ids.has(pidgey_id))
	PUWSaveManager.delete_save()

	# ---- (f) habitat roll -> difficulty wild build ----
	_check("loop_habitat_activation", loop.enable_habitat_encounters())
	_check("loop_step_chance_unchanged_by_habitat", loop.wild_step_encounter_chance("ROUTE_1", "grass") > 0.0)
	var rng_f: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_f.seed = 20261122
	var rolled_f: Dictionary = loop.roll_habitat_encounter("ROUTE_1", "grass", 5, rng_f)
	_check("loop_habitat_roll_returns_a_species", not rolled_f.is_empty() and str(rolled_f.get("species_slug", "")) != "")
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var wild_mon: Dictionary = builder.build_wild_mon(str(rolled_f.get("species_slug", "")), 5, rng_f)
	var wild_level: int = int(wild_mon.get("level", 0))
	var ivs: Dictionary = wild_mon.get("ivs", {})
	var ivs_ok: bool = ivs.size() == 6
	for iv_v in ivs.values():
		if int(iv_v) != 31:
			ivs_ok = false
	_check("habitat_wild_builds_at_player_max_plus_1_to_3_iv31", wild_level >= 6 and wild_level <= 8 and ivs_ok)

	print("HABITAT SUMMARY: %d passed, %d failed." % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
