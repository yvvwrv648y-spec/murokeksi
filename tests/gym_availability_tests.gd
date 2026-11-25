extends SceneTree
## Gym AVAILABILITY tests (Riley canon, 2026-11-22 14:56 CST):
## availability is a separate axis from power scaling.
## Run: godot --headless --script res://tests/gym_availability_tests.gd
##
## POWER axis (untouched by this suite's subject): gym levels and
## obedience caps scale on the GLOBAL badge count --
## EXPSystem.level_cap_for_badges (battle/exp_system.gd) is the
## cap function the project actually ships; the task brief named
## it as GymProgression.level_cap_for_badges, but GymProgression
## (campaign/gym_progression.gd) holds badge storage only and has
## no cap function, so the cap is read from EXPSystem here.
##
## AVAILABILITY axis (this suite): PUWGymRequirements over
## data/gym_requirements.json, gated through
## PUWCampaignStitch.can_start_gym_battle. Availability is
## regional and requirement-based and is never waived by progress
## in other regions.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _fresh_state() -> Dictionary:
	return {"badges": [], "story_flags": {}, "bag": {}}


func _foreign_state() -> Dictionary:
	# A state whose ONLY badge is a foreign one, built through the
	# same badge store the stitch uses (GymProgression.award_badge
	# writes state["badges"], exactly as record_gym_win does).
	var state: Dictionary = _fresh_state()
	GymProgression.award_badge(state, "galar_gym_1")
	return state


func _set_flag(state: Dictionary, flag_id: String, value: Variant) -> void:
	var flags: Dictionary = state.get("story_flags", {})
	flags[flag_id] = value
	state["story_flags"] = flags


func _unmet_text(unmet: Array) -> String:
	var parts: Array = []
	for req_value: Variant in unmet:
		var req: Dictionary = req_value
		parts.append(str(req.get("description", "")))
	return " | ".join(parts)


func _init() -> void:
	print("PUW gym availability tests -- starting.")

	# --- Data: one record per Kanto gym, ids match the stitch ---
	# Binding build 3: the data file now carries Johto's 8 records
	# alongside Kanto's 8. The Kanto-scoped assertions filter by the
	# record region; Johto's own count is asserted alongside.
	var kanto_ids: Array = []
	var johto_ids: Array = []
	for gym_value: Variant in PUWGymRequirements.gym_ids():
		var gym_id: String = str(gym_value)
		if PUWGymRequirements.region_of_gym_id(gym_id) == "johto":
			johto_ids.append(gym_id)
		else:
			kanto_ids.append(gym_id)
	_check("data_has_8_gym_records", kanto_ids.size() == 8)
	_check("data_has_8_johto_gym_records", johto_ids.size() == 8)
	_check("data_ids_match_stitch_gym_order", kanto_ids == PUWCampaignStitch.gym_order())

	# --- THE REFUSAL (Riley's example): foreign badge only -------
	var foreign: Dictionary = _foreign_state()
	var vermilion_gate: Dictionary = PUWCampaignStitch.can_start_gym_battle(foreign, "kanto_gym_3_surge")
	_check("foreign_badge_refused_at_vermilion", not PUWGymRequirements.can_start_gym(foreign, "kanto_gym_3_surge") and not bool(vermilion_gate.get("allowed", true)))
	var vermilion_unmet: Array = PUWGymRequirements.unmet_requirements(foreign, "kanto_gym_3_surge")
	var vermilion_text: String = _unmet_text(vermilion_unmet)
	_check("foreign_vermilion_unmet_names_ss_anne_cut_chain", vermilion_unmet.size() == 3 and vermilion_text.contains("S.S. Anne") and vermilion_text.contains("HM01") and vermilion_text.contains("Cut"))
	var gate_unmet: Array = vermilion_gate.get("unmet", [])
	_check("stitch_gate_unmet_lists_descriptions", gate_unmet.size() == 3 and str(gate_unmet[0]).contains("S.S. Anne"))

	var viridian_gate: Dictionary = PUWCampaignStitch.can_start_gym_battle(foreign, "kanto_gym_8_giovanni")
	_check("foreign_badge_refused_at_viridian", not bool(viridian_gate.get("allowed", true)))
	var viridian_unmet: Array = PUWGymRequirements.unmet_requirements(foreign, "kanto_gym_8_giovanni")
	var viridian_req: Dictionary = viridian_unmet[0] if viridian_unmet.size() == 1 else {}
	_check("foreign_viridian_region_badges_unmet_foreign_does_not_count", viridian_unmet.size() == 1 and str(viridian_req.get("type", "")) == "region_badges" and PUWGymRequirements.badge_count_for_region(foreign, "kanto") == 0)

	# --- POWER AXIS UNTOUCHED -------------------------------------
	# The foreign badge DID raise the global count and the cap,
	# while opening nothing above.
	_check("foreign_state_global_badge_count_is_1", GymProgression.badge_count(foreign) == 1)
	_check("power_axis_cap_for_1_badge_still_20", EXPSystem.level_cap_for_badges(1) == 20 and EXPSystem.level_cap_for_badges(GymProgression.badge_count(foreign)) == 20)

	# --- Empty-requirements gyms are open to a fresh state --------
	var fresh: Dictionary = _fresh_state()
	_check("fresh_pewter_allowed", PUWGymRequirements.can_start_gym(fresh, "kanto_gym_1_brock"))
	_check("fresh_cerulean_allowed", PUWGymRequirements.can_start_gym(fresh, "kanto_gym_2_misty"))
	_check("fresh_fuchsia_allowed", PUWGymRequirements.can_start_gym(fresh, "kanto_gym_5_koga"))

	# --- Vermilion: unmet list shrinks one requirement at a time --
	var verm: Dictionary = _fresh_state()
	_check("vermilion_fresh_unmet_3", PUWGymRequirements.unmet_requirements(verm, "kanto_gym_3_surge").size() == 3)
	_set_flag(verm, "ss_anne_cleared", true)
	_check("vermilion_after_ss_anne_flag_unmet_2", PUWGymRequirements.unmet_requirements(verm, "kanto_gym_3_surge").size() == 2)
	var bag: Dictionary = verm.get("bag", {})
	bag["hm01"] = 1
	verm["bag"] = bag
	_check("vermilion_after_hm01_item_unmet_1", PUWGymRequirements.unmet_requirements(verm, "kanto_gym_3_surge").size() == 1)
	_set_flag(verm, "field_actions", ["cut"])
	_check("vermilion_allowed_with_flag_item_and_cut", PUWGymRequirements.can_start_gym(verm, "kanto_gym_3_surge"))

	# --- Celadon: Cut at the gym entrance --------------------------
	_check("celadon_refused_without_cut", not PUWGymRequirements.can_start_gym(_fresh_state(), "kanto_gym_4_erika"))
	var celadon: Dictionary = _fresh_state()
	_set_flag(celadon, "field_actions", ["cut"])
	_check("celadon_allowed_with_cut", PUWGymRequirements.can_start_gym(celadon, "kanto_gym_4_erika"))

	# --- Saffron: both story flags ---------------------------------
	_check("saffron_refused_without_story_flags", PUWGymRequirements.unmet_requirements(_fresh_state(), "kanto_gym_6_sabrina").size() == 2)
	var saffron: Dictionary = _fresh_state()
	_set_flag(saffron, "saffron_access", true)
	_check("saffron_refused_with_only_city_access", not PUWGymRequirements.can_start_gym(saffron, "kanto_gym_6_sabrina"))
	_set_flag(saffron, "silph_co_cleared", true)
	_check("saffron_allowed_with_both_story_flags", PUWGymRequirements.can_start_gym(saffron, "kanto_gym_6_sabrina"))

	# --- Cinnabar: the Secret Key ----------------------------------
	_check("cinnabar_refused_without_secret_key", not PUWGymRequirements.can_start_gym(_fresh_state(), "kanto_gym_7_blaine"))
	var cinnabar: Dictionary = _fresh_state()
	var cinnabar_bag: Dictionary = cinnabar.get("bag", {})
	cinnabar_bag["secret_key"] = 1
	cinnabar["bag"] = cinnabar_bag
	_check("cinnabar_allowed_with_secret_key", PUWGymRequirements.can_start_gym(cinnabar, "kanto_gym_7_blaine"))

	# --- Viridian: exactly the other 7 Kanto badges -----------------
	var six_kanto: Dictionary = _fresh_state()
	var order: Array = PUWCampaignStitch.gym_order()
	for i: int in range(6):
		GymProgression.award_badge(six_kanto, str(order[i]))
	_check("viridian_refused_with_only_6_kanto_badges", not PUWGymRequirements.can_start_gym(six_kanto, "kanto_gym_8_giovanni"))
	var seven_kanto: Dictionary = _fresh_state()
	for i2: int in range(7):
		GymProgression.award_badge(seven_kanto, str(order[i2]))
	_check("viridian_allowed_with_other_7_kanto_badges", PUWGymRequirements.can_start_gym(seven_kanto, "kanto_gym_8_giovanni"))

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
