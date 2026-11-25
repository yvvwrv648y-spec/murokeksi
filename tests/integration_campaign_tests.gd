extends SceneTree
## Integration tests: cast registry, bikes, campaign stitch.
## Run: godot --headless --script res://tests/integration_campaign_tests.gd
## All expectations come from the real project data files
## (protagonist canon, Pallet Town warps, starters.json, rival
## story JSON, 6-mon rosters, bicycle registry, tandem spec).
##
## CHANGED ASSERTIONS -- canon reconciliation, 2026-11-22
## (Riley canon 14:56 CST; Phase 3 item D):
## PUWCampaignStitch.record_gym_win no longer enforces roster
## order. It is gated by gym AVAILABILITY (PUWGymRequirements via
## can_start_gym_battle): any available gym may be beaten in any
## order. Exactly these expectations changed, and no others:
## 1. "stitch_gym_out_of_order_refused" (expected beating Misty
##    before Brock to be REFUSED) is replaced by
##    "stitch_gym_out_of_order_allowed_when_available": Misty has
##    no requirements in data/gym_requirements.json, so the win
##    now SUCCEEDS out of order and awards the Cascade Badge.
## 2. New assertion "stitch_gym_gated_refused_until_requirements
##    _met": Surge (Vermilion) IS refused on a fresh run, because
##    his requirements (S.S. Anne flag, HM01, Cut) are unmet --
##    the refusal reason changed from order to availability.
##    (Suite total therefore grows by one check: 64 -> 65.)
## 3. Helper "_grant_all_badges" changed (not an assertion): it
##    now honestly satisfies the gym requirements first -- story
##    flags ss_anne_cleared / saffron_access / silph_co_cleared,
##    field action "cut", bag items hm01 and secret_key -- then
##    wins the gyms through the gate in roster order, which also
##    earns the 7 Kanto badges Giovanni's region_badges
##    requirement demands before his win is recorded.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _dir_has_images(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return false
	for file_name: String in dir.get_files():
		var lower: String = file_name.to_lower()
		if lower.ends_with(".jpg") or lower.ends_with(".png") or lower.ends_with(".jpeg"):
			return true
	return false


func _run_to_starter(cast_id: String) -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state(cast_id, "TEST")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	return state


func _grant_all_badges(state: Dictionary) -> void:
	# Canon update (2026-11-22, see header): record_gym_win is
	# gated by gym AVAILABILITY, so the requirements are honestly
	# satisfied first -- S.S. Anne chain + HM01 + Cut (Surge), Cut
	# (Erika), Saffron access + Silph Co. (Sabrina), Secret Key
	# (Blaine) -- then every gym is won through the gate. Roster
	# order is used only so Giovanni's "other 7 Kanto badges"
	# requirement is earned before his win; any other order that
	# respects the requirements would work too. A gym already won
	# (Misty, in the out-of-order check above) simply refuses the
	# duplicate award inside the loop, which is fine here.
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


func _init() -> void:
	print("PUW integration campaign tests -- starting.")

	# --- Cast registry: every cast member x state resolves ------
	var all_resolve: bool = true
	var all_status: bool = true
	for cast_value: Variant in PUWCastRegistry.cast_ids():
		var cast_id: String = str(cast_value)
		for state_value: Variant in PUWCastRegistry.states():
			var state_name: String = str(state_value)
			var resolved: Dictionary = PUWCastRegistry.sheet_for(cast_id, state_name)
			if str(resolved.get("path", "")) == "":
				all_resolve = false
				print("  no sheet: ", cast_id, " / ", state_name)
			if str(resolved.get("status", "")) != "waits_on_neon_art_merge":
				all_status = false
	_check("cast_every_member_every_state_resolves_sheet", all_resolve)
	_check("cast_every_sheet_status_waits_on_neon_art_merge", all_status)
	var riley_walk: Dictionary = PUWCastRegistry.sheet_for("riley", "walk")
	_check("cast_riley_walk_sheet_name", str(riley_walk.get("path", "")) == "characters/animations/anim_riley_8frame_sheet.jpg")
	var custom_battle: Dictionary = PUWCastRegistry.sheet_for("custom_futanari", "battle")
	_check("cast_custom_futanari_battle_sheet_name", str(custom_battle.get("path", "")) == "characters/protagonists/custom/custom_futanari_battle.png")

	# No art shipped under systems/cast (project or pack).
	_check("cast_no_art_in_project_systems_cast", not _dir_has_images("res://systems/cast"))
	var pack_cast_dir: String = "/home/hatch/workspace/goals/pok-mon-ultimate-world-sprint-006-emberfox-walk/files/pokemon-full/playable-kanto/systems/cast"
	if DirAccess.dir_exists_absolute(pack_cast_dir):
		_check("cast_no_art_in_pack_systems_cast", not _dir_has_images(pack_cast_dir))

	# --- Spawns match canon houses -------------------------------
	var riley_spawn: Dictionary = PUWCastRegistry.spawn_for_protagonist("riley")
	_check("spawn_riley_reds_house", str(riley_spawn.get("map_id_const", "")) == "REDS_HOUSE_1F")
	var tasha_spawn: Dictionary = PUWCastRegistry.spawn_for_protagonist("tasha")
	_check("spawn_tasha_blues_house", str(tasha_spawn.get("map_id_const", "")) == "BLUES_HOUSE")
	var custom_spawn: Dictionary = PUWCastRegistry.spawn_for_protagonist("custom_femboy")
	_check("spawn_custom_pallet_exterior", str(custom_spawn.get("map_id_const", "")) == "PALLET_TOWN" and str(custom_spawn.get("kind", "")) == "exterior_cell")

	# --- Schema validation ---------------------------------------
	_check("schema_accepts_femboy_identity", PUWCastRegistry.valid_identity("Femboy"))
	_check("schema_accepts_futanari_preset", PUWCastRegistry.valid_preset("futanari"))
	_check("schema_rejects_invented_identity", not PUWCastRegistry.valid_identity("Sparkle Princess"))
	_check("schema_rejects_invented_preset", not PUWCastRegistry.valid_preset("sparkle"))

	# --- Bikes ----------------------------------------------------
	_check("tandem_locked_without_coop", PUWBikes.tandem_available(false) == false)
	_check("tandem_available_with_coop", PUWBikes.tandem_available(true) == true)
	_check("solo_acro_speed_exact", PUWBikes.speed_for(PUWBikes.MODE_SOLO_ACRO) == 10.67)
	_check("solo_mach_speed_exact", PUWBikes.speed_for(PUWBikes.MODE_SOLO_MACH) == 16.0)
	var speeds: Dictionary = PUWBikes.movement_speeds()
	_check("spec_speeds_sneak_walk_run", float(speeds.get("crouch_sneak", 0.0)) == 2.2 and float(speeds.get("walk", 0.0)) == 4.0 and float(speeds.get("running_shoes", 0.0)) == 8.0)
	_check("pose_matrix_has_11_entries", PUWBikes.pose_matrix_keys().size() == 11)
	var pose: Dictionary = PUWBikes.pose_for("tasha", "riley")
	_check("pose_known_pairing_resolves", not pose.is_empty() and str(pose.get("intimacy", "")) == "HIGHEST_CANON")
	var custom_pose: Dictionary = PUWBikes.pose_for("riley", "custom_female")
	_check("pose_custom_passenger_standard", str(custom_pose.get("intimacy", "")) == "STANDARD")
	_check("solo_theme_riley_from_registry", PUWBikes.solo_theme_for("riley").contains("Meowth"))
	_check("tandem_theme_driver_tasha_from_registry", PUWBikes.tandem_theme("tasha").contains("Tasha"))
	var outfit: Dictionary = PUWBikes.outfit_preservation()
	_check("outfit_zero_default_reversion", bool(outfit.get("zero_default_reversion", false)) == true and str(outfit.get("rule", "")).contains("ZERO_DEFAULT_REVERSION"))

	# --- Stitch: full Custom run ---------------------------------
	var state: Dictionary = _run_to_starter("custom_female")
	_check("stitch_stage_clues_seen", PUWCampaignStitch.stage(state) == "clues_seen")
	var clues: Dictionary = PUWCampaignStitch.home_clues(state)
	var expected_book: Dictionary = PalletHomeClues.get_riley_drawing_book("custom")
	var expected_note: Dictionary = PalletHomeClues.get_tasha_fridge_note("custom")
	_check("stitch_clues_drawing_book_verbatim", clues.get("riley_drawing_book", {}) == expected_book)
	_check("stitch_clues_fridge_note_verbatim", clues.get("tasha_fridge_note", {}) == expected_note)
	# ---- starter: the Oak grant flow (binding build 4; the
	# Kanto-trio picker is superseded for custom characters) ----
	var grants: Array = PUWCampaignStitch.grant_oak_picks(state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"})
	_check("stitch_oak_grants_two", grants.size() == 2)
	var mon: Dictionary = grants[0] if grants.size() > 0 else {}
	_check("stitch_starter_squirtle_lv5", str(mon.get("name", "")) == "squirtle" and int(mon.get("level", 0)) == 5)
	var mon_moves: Array = mon.get("moves", [])
	var move_names: Array = []
	for m_value: Variant in mon_moves:
		var m: Dictionary = m_value
		move_names.append(str(m.get("name", "")))
	_check("stitch_squirtle_oak_moveset", move_names.has("watergun") and move_names.has("tackle"))
	_check("stitch_stage_starter_chosen", PUWCampaignStitch.stage(state) == "starter_chosen")
	var fresh_state: Dictionary = _run_to_starter("custom_female")
	_check("stitch_bad_starter_refused", PUWCampaignStitch.grant_oak_picks(fresh_state, {"species_id": 150, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"}).is_empty())
	_check("stitch_duplicate_pick_refused", PUWCampaignStitch.grant_oak_picks(fresh_state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 7, "variant": "pokemon"}).is_empty())

	# E4 refused before badges.
	_check("stitch_e4_refused_before_badges", not PUWCampaignStitch.start_elite_four(state))
	_check("stitch_gatekeeper_refused_before_badges", not PUWCampaignStitch.record_gatekeeper_win(state))

	# Gym availability + badge grants via roster gym ids.
	# CANON UPDATE (2026-11-22, see header): no roster order --
	# Misty has no requirements, so her win succeeds out of order;
	# Surge is refused only because his requirements are unmet.
	_check("stitch_gym_out_of_order_allowed_when_available", PUWCampaignStitch.record_gym_win(state, "kanto_gym_2_misty"))
	_check("stitch_gym_gated_refused_until_requirements_met", not PUWCampaignStitch.record_gym_win(state, "kanto_gym_3_surge"))
	_grant_all_badges(state)
	_check("stitch_eight_badges", GymProgression.badge_count(state) == 8)
	_check("stitch_gym_order_size_8", PUWCampaignStitch.gym_order().size() == 8)

	# Gatekeeper required before E4.
	_check("stitch_e4_refused_without_gatekeeper", not PUWCampaignStitch.can_enter_elite_four(state) and not PUWCampaignStitch.start_elite_four(state))
	_check("stitch_gatekeeper_win", PUWCampaignStitch.record_gatekeeper_win(state))
	_check("stitch_e4_refused_without_runner_up", not PUWCampaignStitch.can_enter_elite_four(state))
	_check("stitch_runner_up_win", PUWCampaignStitch.record_runner_up_win(state))
	_check("stitch_e4_starts_after_gates", PUWCampaignStitch.start_elite_four(state))

	# Rival track: Custom faces both rivals, 3 each.
	var totals: Dictionary = PUWCampaignStitch.rival_totals(state)
	_check("stitch_custom_rival_totals", int(totals.get("riley", 0)) == 3 and int(totals.get("tasha", 0)) == 3)
	for i: int in range(3):
		PUWCampaignStitch.record_rival_fight(state, "riley")
		PUWCampaignStitch.record_rival_fight(state, "tasha")
	_check("stitch_rival_track_complete", PUWCampaignStitch.rival_track_complete(state))
	_check("stitch_rival_beyond_total_refused", not PUWCampaignStitch.record_rival_fight(state, "riley"))
	var award_data: Dictionary = PUWCampaignStitch.awards(state)
	var mdx_eggs: Array = award_data.get("mdx_eggs", [])
	var pkdx_eggs: Array = award_data.get("pkdx_eggs", [])
	_check("stitch_awards_3_mdx_and_3_pkdx_for_custom", mdx_eggs.size() == 3 and pkdx_eggs.size() == 3)
	var first_egg: Dictionary = mdx_eggs[0] if mdx_eggs.size() > 0 else {}
	_check("stitch_award_egg_verbatim_id", str(first_egg.get("egg_id", "")) == "egg_mdx_charmander")

	# Gauntlet: 4 E4 + champion = 5 wins to Hall of Fame.
	var sequence: Array = PUWCampaignStitch.elite_four_sequence(state)
	_check("stitch_e4_sequence_5", sequence.size() == 5 and str(sequence[0]) == "e4_lorelei")
	for i: int in range(5):
		PUWCampaignStitch.record_elite_four_win(state)
	_check("stitch_hall_of_fame_stage", PUWCampaignStitch.stage(state) == "hall_of_fame")
	var hof_flags: Dictionary = state.get("story_flags", {})
	_check("stitch_hall_of_fame_flag", bool(hof_flags.get("hall_of_fame_entered", false)))

	# Omni: in bag, locked in Kanto, usable outside Kanto + unlocked.
	_check("stitch_omni_in_bag", PUWCampaignStitch.omni_bracelet_in_bag(state))
	_check("stitch_omni_locked_in_kanto", PUWCampaignStitch.can_use_omni(state) == false)
	PUWCampaignStitch.set_omni_unlocked(state, true)
	_check("stitch_omni_still_locked_in_kanto_when_unlocked", PUWCampaignStitch.can_use_omni(state) == false)
	PUWCampaignStitch.set_region(state, "johto")
	_check("stitch_omni_usable_outside_kanto_unlocked", PUWCampaignStitch.can_use_omni(state) == true)

	# Centers / Marts / supply trainers.
	_check("stitch_center_available_real_map", PUWCampaignStitch.center_available("CeruleanPokecenter"))
	_check("stitch_mart_available_real_map", PUWCampaignStitch.mart_available("CeruleanMart"))
	_check("stitch_center_unavailable_invented_map", not PUWCampaignStitch.center_available("NowherePokecenter"))
	var supply: Array = PUWCampaignStitch.supply_trainers()
	_check("stitch_supply_trainers_3", supply.size() == 3)
	_check("stitch_supply_towns_28_approved_spots", PUWCampaignStitch.towns_with_supply_trainers().size() == 28)

	# Save round-trip keeps stage + badges.
	PUWSaveManager.delete_save()
	_check("stitch_save_written", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("stitch_roundtrip_stage", PUWCampaignStitch.stage(loaded) == "hall_of_fame")
	_check("stitch_roundtrip_badges", GymProgression.badge_count(loaded) == 8)
	PUWSaveManager.delete_save()

	# --- Champion differs by protagonist (rival manager data) ----
	var riley_state: Dictionary = _run_to_starter("riley")
	var tasha_state: Dictionary = _run_to_starter("tasha")
	var riley_flags: Dictionary = riley_state.get("story_flags", {})
	var tasha_flags: Dictionary = tasha_state.get("story_flags", {})
	_check("stitch_champion_differs_riley_vs_tasha", str(riley_flags.get("champion_id", "")) != str(tasha_flags.get("champion_id", "")))
	_check("stitch_rival_branches_riley_vs_tasha", str(riley_flags.get("league_resolution", {}).get("rival", "")) == "tasha" and str(tasha_flags.get("league_resolution", {}).get("rival", "")) == "riley")
	# Riley protagonist: fridge note present, drawing book absent.
	var riley_clues: Dictionary = PUWCampaignStitch.home_clues(riley_state)
	var riley_book: Dictionary = riley_clues.get("riley_drawing_book", {})
	_check("stitch_riley_run_book_absent_in_own_home", bool(riley_book.get("present", true)) == false)

	print("Integration campaign tests: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)
