extends SceneTree
## Oak starter system tests (binding build 4, stage 8;
## STARTER_SYSTEM_SPEC.md sections 1-3, changes C1-C7).
##
## Proves: a custom character starts with NO Pokemon; the Oak
## grant flow gives exactly two distinct pool picks at Level 5
## with the bind-time resolved builds (nature / ability / IVs /
## EVs / moveset from campaign/oak_builds.json); the Moemon
## variant is legal only where the pool offers it and changes
## only the family tag; invalid pairs (duplicate species,
## non-pool species, illegal variant, second run) refuse with
## the state untouched; the fixed protagonists refuse the Oak
## flow (their verified teams arrive by direct grant); the C7
## gate accessor reads the completion flag.
##
## Run: godot --headless --path . --script res://tests/oak_starter_tests.gd

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS ", name)
	else:
		_failed += 1
		print("FAIL ", name)


func _custom_state_at_lab() -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "TEST")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	return state


func _init() -> void:
	# ---- pool + builds data landed and consistent ----
	var pool_file: Dictionary = PUWCampaignStitch._load_json(PUWCampaignStitch.OAK_POOL_PATH)
	var builds_file: Dictionary = PUWCampaignStitch._load_json(PUWCampaignStitch.OAK_BUILDS_PATH)
	var pool: Array = pool_file.get("pool", [])
	var builds: Dictionary = builds_file.get("builds", {})
	_check("oak_pool_loaded_279", pool.size() == 279)
	_check("oak_builds_loaded_279", builds.size() == 279)
	var pool_ids: Dictionary = {}
	var moemonless_id: int = 0
	for entry_value: Variant in pool:
		var e: Dictionary = entry_value
		pool_ids[int(e.get("species_id", 0))] = e
		var variants: Dictionary = e.get("variants", {})
		if moemonless_id == 0 and not bool(variants.get("moemon", false)):
			moemonless_id = int(e.get("species_id", 0))
	# A-45 (build 6): the regenerated 279 pool carries a Moemon
	# variant for every pooled species, so the illegal-variant
	# probe below uses Pecharunt (1025 — no Moemon design exists,
	# per the rig-motion lane record), a non-pool species.
	_check("oak_pool_all_species_have_moemon_variants", moemonless_id == 0)
	moemonless_id = 1025
	_check("oak_pool_excludes_mewtwo", not pool_ids.has(150))
	_check("oak_pool_includes_squirtle_pichu_beldum", pool_ids.has(7) and pool_ids.has(172) and pool_ids.has(374))

	# ---- custom character: empty party, gate closed ----
	var state: Dictionary = _custom_state_at_lab()
	_check("oak_custom_starts_empty", (state.get("party", []) as Array).is_empty())
	_check("oak_gate_closed_before", not PUWCampaignStitch.oak_picks_done(state))

	# ---- the grant flow ----
	var grants: Array = PUWCampaignStitch.grant_oak_picks(state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 172, "variant": "moemon"})
	_check("oak_grants_two", grants.size() == 2)
	_check("oak_party_now_two", (state.get("party", []) as Array).size() == 2)
	_check("oak_gate_open_after", PUWCampaignStitch.oak_picks_done(state))
	_check("oak_stage_starter_chosen", PUWCampaignStitch.stage(state) == "starter_chosen")
	var squirtle: Dictionary = grants[0] if grants.size() > 0 else {}
	var pichu: Dictionary = grants[1] if grants.size() > 1 else {}
	_check("oak_squirtle_identity", str(squirtle.get("name", "")) == "squirtle" and int(squirtle.get("level", 0)) == 5 and str(squirtle.get("family", "")) == "PKDX")
	_check("oak_pichu_moemon_family_only", str(pichu.get("name", "")) == "pichu" and str(pichu.get("family", "")) == "MDX")
	# Build fields ride the bind-time resolution verbatim.
	var squirtle_build: Dictionary = builds.get("squirtle", {})
	_check("oak_squirtle_build_verbatim", str(squirtle.get("nature", "")) == str(squirtle_build.get("nature", "?")) and str(squirtle.get("ability", "")) == str(squirtle_build.get("ability", "?")) and str(squirtle.get("held_item", "?")) == "")
	var move_names: Array = []
	var squirtle_moves: Array = squirtle.get("moves", [])
	for m_value: Variant in squirtle_moves:
		var m: Dictionary = m_value
		move_names.append(str(m.get("name", "")))
	_check("oak_squirtle_moves_watergun_tackle", move_names.has("watergun") and move_names.has("tackle"))
	var evs: Dictionary = squirtle.get("evs", {})
	var ev_total: int = 0
	for k: Variant in evs.keys():
		ev_total += int(evs[k])
	_check("oak_squirtle_ev_budget", ev_total > 0 and ev_total <= 510)
	var ivs: Dictionary = squirtle.get("ivs", {})
	var iv_ok: bool = ivs.size() == 6
	for k2: Variant in ivs.keys():
		iv_ok = iv_ok and int(ivs[k2]) >= 0 and int(ivs[k2]) <= 31
	_check("oak_squirtle_ivs_legal", iv_ok)
	_check("oak_squirtle_stats_computed", int(squirtle.get("max_hp", 0)) > 0 and int(squirtle.get("spe", 0)) > 0)

	# ---- beldum: the one-move edge (its only Lv<=5 move) ----
	var state2: Dictionary = _custom_state_at_lab()
	var grants2: Array = PUWCampaignStitch.grant_oak_picks(state2, {"species_id": 374, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"})
	var beldum: Dictionary = grants2[0] if grants2.size() > 0 else {}
	var beldum_moves: Array = beldum.get("moves", [])
	_check("oak_beldum_tackle_only", beldum_moves.size() == 1 and str((beldum_moves[0] as Dictionary).get("name", "")) == "tackle")

	# ---- refusals leave the state untouched ----
	var state3: Dictionary = _custom_state_at_lab()
	_check("oak_refuse_duplicate_species", PUWCampaignStitch.grant_oak_picks(state3, {"species_id": 7, "variant": "pokemon"}, {"species_id": 7, "variant": "pokemon"}).is_empty())
	_check("oak_refuse_non_pool_species", PUWCampaignStitch.grant_oak_picks(state3, {"species_id": 150, "variant": "pokemon"}, {"species_id": 7, "variant": "pokemon"}).is_empty())
	_check("oak_refuse_illegal_moemon_variant", PUWCampaignStitch.grant_oak_picks(state3, {"species_id": moemonless_id, "variant": "moemon"}, {"species_id": 7, "variant": "pokemon"}).is_empty())
	_check("oak_refusals_left_state_untouched", (state3.get("party", []) as Array).is_empty() and not PUWCampaignStitch.oak_picks_done(state3))
	_check("oak_refuse_second_run", PUWCampaignStitch.grant_oak_picks(state, {"species_id": 1, "variant": "pokemon"}, {"species_id": 4, "variant": "pokemon"}).is_empty() and (state.get("party", []) as Array).size() == 2)

	# ---- fixed protagonists bypass (C5) ----
	var riley_state: Dictionary = PUWCampaignStitch.new_game_state("riley", "TEST")
	_check("oak_fixed_starts_with_six", (riley_state.get("party", []) as Array).size() == 6)
	PUWCampaignStitch.record_clues_seen(riley_state)
	_check("oak_refuse_fixed_protagonist", PUWCampaignStitch.grant_oak_picks(riley_state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"}).is_empty())
	_check("oak_fixed_party_untouched", (riley_state.get("party", []) as Array).size() == 6)

	# ---- scaling tables bound for both teams x both variants ----
	# Bound shape (campaign/scaling_tables.json): teams ->
	# {riley, tasha} -> {played, encountered} -> beat dict
	# ("0".."8" + "postgame"), each beat a 6-member list:
	# 10 beats x 6 members = 60 cells per variant, 240 total.
	var scaling_file: Dictionary = PUWCampaignStitch._load_json("res://campaign/scaling_tables.json")
	var teams: Dictionary = scaling_file.get("teams", {})
	var scaling_ok: bool = teams.size() == 2
	for team_id: Variant in ["riley", "tasha"]:
		var team: Dictionary = teams.get(team_id, {})
		for variant: Variant in ["played", "encountered"]:
			var beats: Dictionary = team.get(variant, {})
			var cells: int = 0
			for beat: Variant in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "postgame"]:
				var members_value: Variant = beats.get(beat, [])
				if members_value is Array:
					var members: Array = members_value
					cells += members.size()
			scaling_ok = scaling_ok and cells == 60
	_check("oak_scaling_tables_4x60", scaling_ok)

	print("OAK_STARTER_TESTS: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)
