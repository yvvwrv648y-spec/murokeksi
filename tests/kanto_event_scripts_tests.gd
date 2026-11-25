extends SceneTree
## Kanto + Sevii story event scripts: every authored script in
## data/events/ played end-to-end on the real machinery
## (PUWEventRunner + PUWCampaignStitch state + the stage-4
## PUWSpawner over the real Kanto/Sevii dialogue banks and
## bridges + PUWBattleEntry), the gym-gate wiring for gyms 3
## and 6, and the Mewtwo fixed-encounter record.
## Run: godot --headless --script res://tests/kanto_event_scripts_tests.gd
##
## All expectations come from the real data: bank entry texts
## (never retyped), data/trainers.json class parties via
## PUWBattleEntry.trainer_base_identity, data/gym_requirements
## .json via PUWGymRequirements / PUWCampaignStitch, the
## restored Sevii bank, and data/fixed_encounters.json itself.

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


# ----------------------------------------------------------------
# State builders
# ----------------------------------------------------------------

func _story_state() -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "RED")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	PUWCampaignStitch.grant_oak_picks(state,
		{"species_id": 1, "variant": "pokemon"},
		{"species_id": 7, "variant": "pokemon"})
	return state


func _champion_state() -> Dictionary:
	# The state the stitch itself produces at the champion
	# moment (campaign_stitch.gd's gauntlet resolution): the
	# "champion" story flag set AND campaign_stage advanced to
	# "champion" via its _set_stage bookkeeping.
	var state: Dictionary = _story_state()
	var flags: Dictionary = state.get("story_flags", {})
	flags["champion"] = true
	flags["campaign_stage"] = "champion"
	state["story_flags"] = flags
	return state


func _flags(state: Dictionary) -> Dictionary:
	var flags_v: Variant = state.get("story_flags", {})
	if flags_v is Dictionary:
		var flags: Dictionary = flags_v
		return flags
	return {}


func _bag(state: Dictionary) -> Dictionary:
	var bag_v: Variant = state.get("bag", {})
	if bag_v is Dictionary:
		var bag: Dictionary = bag_v
		return bag
	return {}


func _rig(actor_id: String, tile: Vector2i) -> PUWEventActor:
	return PUWEventActor.create(actor_id, null, tile, 8, "down")


func _actors(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	for id_v in ids:
		out[str(id_v)] = _rig(str(id_v), Vector2i(4 + i, 4))
		i += 1
	return out


func _run_script(state: Dictionary, actors: Dictionary, path: String, battle_won: bool, subs: Dictionary = {}) -> Dictionary:
	_lines = []
	_warps = []
	var runner: PUWEventRunner = PUWEventRunner.new()
	runner.configure(state, actors,
		{"present_line": Callable(self, "_record_line"), "on_warp": Callable(self, "_record_warp")},
		subs, 4242)
	var script: Dictionary = PUWEventRunner.load_script_file(path)
	var load_ok: bool = not script.is_empty() and bool(runner.load_script(script).get("ok", false))
	var run_result: Dictionary = runner.run()
	var battle_seen: Dictionary = _drive(runner, battle_won)
	return {"runner": runner, "load_ok": load_ok, "run_ok": bool(run_result.get("ok", false)),
		"battle": battle_seen, "lines": _lines.duplicate()}


# ----------------------------------------------------------------
# Expected texts, read from the banks themselves
# ----------------------------------------------------------------

func _bank_text(bank_path: String, group: String, label: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(bank_path))
	if not (parsed is Dictionary):
		return ""
	var groups_v: Variant = (parsed as Dictionary).get("groups", {})
	if not (groups_v is Dictionary):
		return ""
	var group_v: Variant = (groups_v as Dictionary).get(group, {})
	if not (group_v is Dictionary):
		return ""
	var entries_v: Variant = (group_v as Dictionary).get("entries", {})
	if not (entries_v is Dictionary):
		return ""
	return str((entries_v as Dictionary).get(label, ""))


func _kanto(label_group: String, label: String) -> String:
	return _bank_text("res://data/dialogue_database.json", label_group, label).replace("<PLAYER>", "RED")


func _sevii(group: String, label: String) -> String:
	return _bank_text("res://data/sevii_dialogue_database.json", group, label).replace("{PLAYER}", "RED")


func _line_texts(lines: Array) -> Array:
	var out: Array = []
	for line_v in lines:
		out.append(str((line_v as Dictionary).get("text", "")))
	return out


func _party_slugs(battle: Dictionary) -> Array:
	var out: Array = []
	var party_v: Variant = battle.get("enemy_party", [])
	if party_v is Array:
		var party: Array = party_v
		for mon_v in party:
			if mon_v is Dictionary:
				out.append(str((mon_v as Dictionary).get("species_slug", "")))
	return out


func _identity_slugs(trainer_class: String, party_index: int) -> Array:
	var entry: PUWBattleEntry = PUWBattleEntry.new()
	var identity: Array = entry.trainer_base_identity(trainer_class, party_index)
	var out: Array = []
	for entry_v in identity:
		if entry_v is Dictionary:
			out.append(PUWTeamBuilder.slugify(str((entry_v as Dictionary).get("species", ""))))
	return out


func _identity_present(battle: Dictionary, trainer_class: String, party_index: int) -> bool:
	var slugs: Array = _party_slugs(battle)
	for slug_v in _identity_slugs(trainer_class, party_index):
		if not slugs.has(str(slug_v)):
			return false
	return true


func _battle_valid(battle: Dictionary) -> bool:
	if not bool(battle.get("ok", false)):
		return false
	var party_v: Variant = battle.get("enemy_party", [])
	var party: Array = party_v if party_v is Array else []
	return not party.is_empty() and bool(PUWBattleEntry.validate_built_party(party, 0, {}).get("ok", false))


const EVENTS_DIR: String = "res://data/events/"
const SEVII_SUBS: Dictionary = {"{PLAYER}": "RED"}
const CELIO: String = "OneIsland_PokemonCenter_1F"
const CELIO_P: String = "OneIsland_PokemonCenter_1F_Text_"


func _init() -> void:
	# ------------------------------------------------------------
	# Every authored script loads through the real loader.
	# ------------------------------------------------------------
	var script_ids: Array = [
		"mt_moon_fossil_choice", "celadon_game_corner_poster",
		"rocket_hideout_giovanni", "pokemon_tower_fuji_rescue",
		"mr_fujis_house_flute", "silph_co_liberation", "ss_anne_captain",
		"sevii_celio_request", "sevii_ruby_pickup", "sevii_celio_ruby_delivery",
		"sevii_sapphire_theft", "sevii_gideon_reclaim", "sevii_celio_sapphire_delivery",
		"gym_gate_kanto_gym_3_surge", "gym_gate_kanto_gym_6_sabrina",
	]
	var all_load: bool = true
	for id_v in script_ids:
		var s: Dictionary = PUWEventRunner.load_script_file(EVENTS_DIR + str(id_v) + ".json")
		if s.is_empty() or str(s.get("id", "")) != str(id_v):
			all_load = false
	_check("all_15_scripts_load", all_load)

	# ------------------------------------------------------------
	# Mt. Moon fossil choice - dome pick.
	# ------------------------------------------------------------
	var st: Dictionary = _story_state()
	var fl: Dictionary = _flags(st)
	fl["mt_moon_pick_dome"] = true
	st["story_flags"] = fl
	var r: Dictionary = _run_script(st, _actors(["player", "super_nerd"]), EVENTS_DIR + "mt_moon_fossil_choice.json", true)
	var runner: PUWEventRunner = r["runner"]
	_check("mtmoon_dome_finished", runner.is_finished() and not runner.has_error())
	_check("mtmoon_dome_transcript", _line_texts(r["lines"]) == [
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdTheyreBothMineText"),
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdOkIllShareText"),
		_kanto("MtMoonB2F", "_MtMoonB2fSuperNerdEachTakeOneText"),
		_kanto("MtMoonB2F", "_MtMoonB2FDomeFossilYouWantText"),
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdThenThisIsMineText")])
	_check("mtmoon_battle_is_super_nerd_2", _identity_present(r["battle"], "SUPER_NERD", 2))
	_check("mtmoon_battle_valid", _battle_valid(r["battle"]))
	_check("mtmoon_dome_granted", int(_bag(st).get("dome-fossil", 0)) == 1 and int(_bag(st).get("helix-fossil", 0)) == 0)
	_check("mtmoon_flag_set", bool(_flags(st).get("mt_moon_fossil_taken", false)))
	var replay: Dictionary = _run_script(st, _actors(["player", "super_nerd"]), EVENTS_DIR + "mt_moon_fossil_choice.json", true)
	_check("mtmoon_replay_refused", not bool(replay["run_ok"]))

	# Mt. Moon - helix pick shows the other prompt and grant.
	var st_h: Dictionary = _story_state()
	var fl_h: Dictionary = _flags(st_h)
	fl_h["mt_moon_pick_helix"] = true
	st_h["story_flags"] = fl_h
	var r_h: Dictionary = _run_script(st_h, _actors(["player", "super_nerd"]), EVENTS_DIR + "mt_moon_fossil_choice.json", true)
	_check("mtmoon_helix_transcript", _line_texts(r_h["lines"]) == [
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdTheyreBothMineText"),
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdOkIllShareText"),
		_kanto("MtMoonB2F", "_MtMoonB2fSuperNerdEachTakeOneText"),
		_kanto("MtMoonB2F", "_MtMoonB2FHelixFossilYouWantText"),
		_kanto("MtMoonB2F", "_MtMoonB2FSuperNerdThenThisIsMineText")])
	_check("mtmoon_helix_granted", int(_bag(st_h).get("helix-fossil", 0)) == 1 and int(_bag(st_h).get("dome-fossil", 0)) == 0)

	# Mt. Moon - losing grants nothing, sets nothing, and retries.
	var st_l: Dictionary = _story_state()
	var fl_l: Dictionary = _flags(st_l)
	fl_l["mt_moon_pick_dome"] = true
	st_l["story_flags"] = fl_l
	var r_l: Dictionary = _run_script(st_l, _actors(["player", "super_nerd"]), EVENTS_DIR + "mt_moon_fossil_choice.json", false)
	var runner_l: PUWEventRunner = r_l["runner"]
	_check("mtmoon_lose_finished_clean", runner_l.is_finished() and not runner_l.has_error())
	_check("mtmoon_lose_no_grant_no_flag", int(_bag(st_l).get("dome-fossil", 0)) == 0 and not bool(_flags(st_l).get("mt_moon_fossil_taken", false)))
	var r_l2: Dictionary = _run_script(st_l, _actors(["player", "super_nerd"]), EVENTS_DIR + "mt_moon_fossil_choice.json", true)
	_check("mtmoon_retry_after_lose_grants", int(_bag(st_l).get("dome-fossil", 0)) == 1)

	# ------------------------------------------------------------
	# Game Corner poster guard.
	# ------------------------------------------------------------
	var st_g: Dictionary = _story_state()
	var actors_g: Dictionary = _actors(["player", "rocket"])
	var r_g: Dictionary = _run_script(st_g, actors_g, EVENTS_DIR + "celadon_game_corner_poster.json", true)
	_check("corner_transcript", _line_texts(r_g["lines"]) == [
		_kanto("GameCorner", "_GameCornerRocketImGuardingThisPosterText"),
		_kanto("GameCorner", "_GameCornerRocketBattleEndText"),
		_kanto("GameCorner", "_GameCornerRocketAfterBattleText"),
		_kanto("GameCorner", "_GameCornerPosterSwitchBehindPosterText")])
	_check("corner_battle_is_rocket_7", _identity_present(r_g["battle"], "ROCKET", 7))
	_check("corner_rocket_fled", not (actors_g["rocket"] as PUWEventActor).is_visible)
	_check("corner_flag_set", bool(_flags(st_g).get("rocket_hideout_revealed", false)))

	# ------------------------------------------------------------
	# Rocket Hideout Giovanni + Silph Scope.
	# ------------------------------------------------------------
	var st_r: Dictionary = _story_state()
	var actors_r: Dictionary = _actors(["player", "giovanni"])
	var r_r: Dictionary = _run_script(st_r, actors_r, EVENTS_DIR + "rocket_hideout_giovanni.json", true)
	_check("hideout_transcript", _line_texts(r_r["lines"]) == [
		_kanto("RocketHideoutB4F", "_RocketHideoutB4FGiovanniImpressedYouGotHereText"),
		_kanto("RocketHideoutB4F", "_RocketHideoutB4FGiovanniWhatCannotBeText"),
		_kanto("RocketHideoutB4F", "_RocketHideoutB4FGiovanniHopeWeMeetAgainText")])
	_check("hideout_battle_is_giovanni_1", _identity_present(r_r["battle"], "GIOVANNI", 1))
	_check("hideout_silph_scope_granted", int(_bag(st_r).get("silph-scope", 0)) == 1)
	_check("hideout_flag_set", bool(_flags(st_r).get("rocket_hideout_cleared", false)))
	_check("hideout_giovanni_gone", not (actors_r["giovanni"] as PUWEventActor).is_visible)

	# ------------------------------------------------------------
	# Pokemon Tower rescue, then the flute at Fuji's house.
	# ------------------------------------------------------------
	var st_t: Dictionary = _story_state()
	var r_t: Dictionary = _run_script(st_t, _actors(["player", "mr_fuji"]), EVENTS_DIR + "pokemon_tower_fuji_rescue.json", true)
	var runner_t: PUWEventRunner = r_t["runner"]
	_check("tower_rescue_line", _line_texts(r_t["lines"]) == [_kanto("PokemonTower7F", "_PokemonTower7FMrFujiRescueText")])
	_check("tower_flag_and_fade", bool(_flags(st_t).get("fuji_rescued", false)) and absf(runner_t.fade_level - 1.0) < 0.001)

	var st_f0: Dictionary = _story_state()
	var r_f0: Dictionary = _run_script(st_f0, _actors(["player", "mr_fuji"]), EVENTS_DIR + "mr_fujis_house_flute.json", true)
	_check("flute_refused_before_rescue", not bool(r_f0["run_ok"]))
	var r_f: Dictionary = _run_script(st_t, _actors(["player", "mr_fuji"]), EVENTS_DIR + "mr_fujis_house_flute.json", true)
	_check("flute_transcript", _line_texts(r_f["lines"]) == [
		_kanto("MrFujisHouse", "_MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText"),
		_kanto("MrFujisHouse", "_MrFujisHouseMrFujiPokeFluteExplanationText")])
	_check("flute_granted", int(_bag(st_t).get("poke-flute", 0)) == 1 and bool(_flags(st_t).get("poke_flute_received", false)))

	# ------------------------------------------------------------
	# Silph Co. liberation - sets both gym-6 flags; the gym gate
	# itself flips from refused to allowed on the same state.
	# ------------------------------------------------------------
	var st_s: Dictionary = _story_state()
	_check("gym6_gate_closed_before_silph", not PUWGymRequirements.can_start_gym(st_s, "kanto_gym_6_sabrina"))
	var actors_s: Dictionary = _actors(["player", "giovanni", "president"])
	var r_s: Dictionary = _run_script(st_s, actors_s, EVENTS_DIR + "silph_co_liberation.json", true)
	_check("silph_transcript", _line_texts(r_s["lines"]) == [
		_kanto("SilphCo11F", "_SilphCo11FGiovanniText"),
		_kanto("SilphCo11F", "_SilphCo11FGiovanniILostAgainText"),
		_kanto("SilphCo11F", "_SilphCo11FGiovanniYouRuinedOurPlansText"),
		_kanto("SilphCo11F", "_SilphCo11FSilphPresidentText"),
		_kanto("SilphCo11F", "_SilphCo11FSilphPresidentMasterBallDescriptionText")])
	_check("silph_battle_is_giovanni_2", _identity_present(r_s["battle"], "GIOVANNI", 2))
	_check("silph_master_ball_granted", int(_bag(st_s).get("master-ball", 0)) == 1)
	_check("silph_both_flags_set", bool(_flags(st_s).get("silph_co_cleared", false)) and bool(_flags(st_s).get("saffron_access", false)))
	_check("gym6_gate_open_after_silph", PUWGymRequirements.can_start_gym(st_s, "kanto_gym_6_sabrina"))

	var st_sl: Dictionary = _story_state()
	var r_sl: Dictionary = _run_script(st_sl, _actors(["player", "giovanni", "president"]), EVENTS_DIR + "silph_co_liberation.json", false)
	_check("silph_lose_sets_nothing", int(_bag(st_sl).get("master-ball", 0)) == 0 and not bool(_flags(st_sl).get("silph_co_cleared", false)))

	# ------------------------------------------------------------
	# S.S. Anne captain - HM01 + ss_anne_cleared; gym 3's gate
	# then needs only the Cut field action the HM feeds.
	# ------------------------------------------------------------
	var st_a: Dictionary = _story_state()
	_check("gym3_gate_closed_before_anne", not PUWGymRequirements.can_start_gym(st_a, "kanto_gym_3_surge"))
	var r_a: Dictionary = _run_script(st_a, _actors(["player", "captain"]), EVENTS_DIR + "ss_anne_captain.json", true)
	_check("anne_transcript", _line_texts(r_a["lines"]) == [
		_kanto("SSAnneCaptainsRoom", "_SSAnneCaptainsRoomRubCaptainsBackText"),
		_kanto("SSAnneCaptainsRoom", "_SSAnneCaptainsRoomCaptainIFeelMuchBetterText"),
		_kanto("SSAnneCaptainsRoom", "_SSAnneCaptainsRoomCaptainNotSickAnymoreText")])
	_check("anne_hm01_and_flag", int(_bag(st_a).get("hm01", 0)) == 1 and bool(_flags(st_a).get("ss_anne_cleared", false)))
	_check("gym3_gate_still_needs_cut", not PUWGymRequirements.can_start_gym(st_a, "kanto_gym_3_surge"))
	var fl_a: Dictionary = _flags(st_a)
	fl_a["field_actions"] = ["cut"]
	st_a["story_flags"] = fl_a
	_check("gym3_gate_open_with_cut", PUWGymRequirements.can_start_gym(st_a, "kanto_gym_3_surge"))
	var r_a2: Dictionary = _run_script(st_a, _actors(["player", "captain"]), EVENTS_DIR + "ss_anne_captain.json", true)
	_check("anne_replay_refused", not bool(r_a2["run_ok"]))

	# ------------------------------------------------------------
	# Gym gate scripts: refused before the flags, live after,
	# and record_gym_win lands the badge through the stitch.
	# ------------------------------------------------------------
	var st_g3: Dictionary = _story_state()
	var r_g3_bad: Dictionary = _run_script(st_g3, _actors(["player", "lt_surge"]), EVENTS_DIR + "gym_gate_kanto_gym_3_surge.json", true)
	var runner_g3_bad: PUWEventRunner = r_g3_bad["runner"]
	_check("gym3_script_refused_pre_gate", runner_g3_bad.has_error() and not runner_g3_bad.is_finished())
	_check("gym3_refusal_is_the_gate", runner_g3_bad.error_text().contains("gym availability gate refused"))
	_check("gym3_record_win_refused_pre_gate", not PUWCampaignStitch.record_gym_win(st_g3, "kanto_gym_3_surge"))

	var r_g3: Dictionary = _run_script(st_a, _actors(["player", "lt_surge"]), EVENTS_DIR + "gym_gate_kanto_gym_3_surge.json", true)
	var runner_g3: PUWEventRunner = r_g3["runner"]
	_check("gym3_script_finished_post_gate", runner_g3.is_finished() and not runner_g3.has_error())
	_check("gym3_battle_built", str((r_g3["battle"] as Dictionary).get("kind", "")) == "gym" and str((r_g3["battle"] as Dictionary).get("roster_id", "")) == "kanto_gym_3_surge" and _battle_valid(r_g3["battle"]))
	_check("gym3_record_win_lands_badge", PUWCampaignStitch.record_gym_win(st_a, "kanto_gym_3_surge") and (st_a.get("badges", []) as Array).has("kanto_gym_3_surge"))

	var st_g6: Dictionary = _story_state()
	var r_g6_bad: Dictionary = _run_script(st_g6, _actors(["player", "sabrina"]), EVENTS_DIR + "gym_gate_kanto_gym_6_sabrina.json", true)
	var runner_g6_bad: PUWEventRunner = r_g6_bad["runner"]
	_check("gym6_script_refused_pre_silph", runner_g6_bad.has_error() and runner_g6_bad.error_text().contains("gym availability gate refused"))
	var r_g6: Dictionary = _run_script(st_s, _actors(["player", "sabrina"]), EVENTS_DIR + "gym_gate_kanto_gym_6_sabrina.json", true)
	var runner_g6: PUWEventRunner = r_g6["runner"]
	_check("gym6_script_finished_post_silph", runner_g6.is_finished() and not runner_g6.has_error())
	_check("gym6_battle_built", str((r_g6["battle"] as Dictionary).get("roster_id", "")) == "kanto_gym_6_sabrina" and _battle_valid(r_g6["battle"]))
	_check("gym6_win_lines_played", _line_texts(r_g6["lines"]) == [
		_kanto("SaffronGym", "_SaffronGymSabrinaText"),
		_kanto("SaffronGym", "_SaffronGymSabrinaPostBattleAdviceText")])
	_check("gym6_record_win_lands_badge", PUWCampaignStitch.record_gym_win(st_s, "kanto_gym_6_sabrina") and (st_s.get("badges", []) as Array).has("kanto_gym_6_sabrina"))

	# The triggers file agrees with gym_requirements.json itself.
	var trig_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gym_gate_triggers.json"))
	var trig_ok: bool = trig_parsed is Dictionary
	var trig_records: Array = []
	if trig_ok:
		var tv: Variant = (trig_parsed as Dictionary).get("triggers", [])
		if tv is Array:
			trig_records = tv
	_check("triggers_file_loads_two_records", trig_ok and trig_records.size() == 2)
	var trig_flags_match: bool = trig_records.size() == 2
	for rec_v in trig_records:
		var rec: Dictionary = rec_v
		var gym_id: String = str(rec.get("gym_id", ""))
		var gate_v: Variant = rec.get("gate", {})
		var gate: Dictionary = gate_v if gate_v is Dictionary else {}
		var reqs_v: Variant = gate.get("requirements", [])
		var wired_flags: Array = []
		if reqs_v is Array:
			for req_v in (reqs_v as Array):
				if (req_v as Dictionary).get("type", "") == "story_flag":
					wired_flags.append(str((req_v as Dictionary).get("flag", "")))
		var sourced_flags: Array = []
		for req2_v in PUWGymRequirements.requirements_for(gym_id):
			if (req2_v as Dictionary).get("type", "") == "story_flag":
				sourced_flags.append(str((req2_v as Dictionary).get("flag", "")))
		if wired_flags != sourced_flags:
			trig_flags_match = false
		var win_v: Variant = rec.get("on_win", {})
		if str((win_v as Dictionary).get("caller", "")) != "PUWCampaignStitch.record_gym_win":
			trig_flags_match = false
	_check("triggers_flags_match_requirements_file", trig_flags_match)

	# ------------------------------------------------------------
	# Sevii chain, end to end on one champion state.
	# ------------------------------------------------------------
	var st_v0: Dictionary = _story_state()
	var r_v0: Dictionary = _run_script(st_v0, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_request.json", true, SEVII_SUBS)
	_check("sevii_request_refused_pre_champion", not bool(r_v0["run_ok"]))

	var st_v: Dictionary = _champion_state()
	_check("sevii_state_is_champion_stage", PUWCampaignStitch.stage(st_v) == "champion")
	var r_vp0: Dictionary = _run_script(st_v, _actors(["player"]), EVENTS_DIR + "sevii_ruby_pickup.json", true, SEVII_SUBS)
	_check("sevii_pickup_refused_before_request", not bool(r_vp0["run_ok"]))
	var r_v1: Dictionary = _run_script(st_v, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_request.json", true, SEVII_SUBS)
	var runner_v1: PUWEventRunner = r_v1["runner"]
	_check("sevii_request_finished", runner_v1.is_finished() and not runner_v1.has_error())
	_check("sevii_request_transcript", _line_texts(r_v1["lines"]) == [
		_sevii(CELIO, CELIO_P + "CelioCaughtMoreMonMaybeICanBeUseful"),
		_sevii(CELIO, CELIO_P + "YoullBeTradingFromTrainersFarAway"),
		_sevii(CELIO, CELIO_P + "NeedsSpecialGemstone")])
	_check("sevii_request_flag", bool(_flags(st_v).get("sevii_celio_quest_started", false)))

	var r_vd0: Dictionary = _run_script(st_v, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_ruby_delivery.json", true, SEVII_SUBS)
	_check("sevii_delivery_refused_before_pickup", not bool(r_vd0["run_ok"]))
	var r_v2: Dictionary = _run_script(st_v, _actors(["player"]), EVENTS_DIR + "sevii_ruby_pickup.json", true, SEVII_SUBS)
	var runner_v2: PUWEventRunner = r_v2["runner"]
	_check("sevii_pickup_grants_ruby", runner_v2.is_finished() and int(_bag(st_v).get("ruby", 0)) == 1 and bool(_flags(st_v).get("sevii_ruby_held", false)))

	var bag_v: Dictionary = _bag(st_v)
	bag_v["tri-pass"] = 1
	st_v["bag"] = bag_v
	var r_v3: Dictionary = _run_script(st_v, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_ruby_delivery.json", true, SEVII_SUBS)
	_check("sevii_delivery_transcript", _line_texts(r_v3["lines"]) == [
		_sevii(CELIO, CELIO_P + "OhThats"),
		_sevii(CELIO, CELIO_P + "MayIAskOneMoreFavor"),
		_sevii(CELIO, CELIO_P + "AnotherGemstoneInSeviiIslands"),
		_sevii(CELIO, CELIO_P + "PassLetYouGetToAllIslands")])
	_check("sevii_delivery_exchange", int(_bag(st_v).get("ruby", 0)) == 0 and int(_bag(st_v).get("tri-pass", 0)) == 0 and int(_bag(st_v).get("rainbow-pass", 0)) == 1)
	_check("sevii_delivery_flag", bool(_flags(st_v).get("sevii_ruby_delivered", false)))

	var actors_t: Dictionary = _actors(["player", "gideon"])
	var r_v4: Dictionary = _run_script(st_v, actors_t, EVENTS_DIR + "sevii_sapphire_theft.json", true, SEVII_SUBS)
	_check("sevii_theft_transcript", _line_texts(r_v4["lines"]) == [
		_sevii("SixIsland_DottedHole_SapphireRoom", "SixIsland_DottedHole_SapphireRoom_Text_IWasRightInTailingYou"),
		_sevii("SixIsland_DottedHole_SapphireRoom", "SixIsland_DottedHole_SapphireRoom_Text_SellToTeamRocketTellPassword")])
	_check("sevii_theft_no_item_flag_set", int(_bag(st_v).get("sapphire", 0)) == 0 and bool(_flags(st_v).get("sevii_sapphire_stolen", false)))
	_check("sevii_theft_gideon_gone", not (actors_t["gideon"] as PUWEventActor).is_visible)

	var r_v5l: Dictionary = _run_script(st_v, _actors(["player", "gideon"]), EVENTS_DIR + "sevii_gideon_reclaim.json", false, SEVII_SUBS)
	_check("sevii_reclaim_lose_no_sapphire", int(_bag(st_v).get("sapphire", 0)) == 0 and not bool(_flags(st_v).get("sevii_sapphire_recovered", false)))
	var r_v5: Dictionary = _run_script(st_v, _actors(["player", "gideon"]), EVENTS_DIR + "sevii_gideon_reclaim.json", true, SEVII_SUBS)
	_check("sevii_reclaim_transcript", _line_texts(r_v5["lines"]) == [
		_sevii("FiveIsland_RocketWarehouse", "FiveIsland_RocketWarehouse_Text_GideonIntro"),
		_sevii("FiveIsland_RocketWarehouse", "FiveIsland_RocketWarehouse_Text_GideonDefeat")])
	var gideon_slugs: Array = _party_slugs(r_v5["battle"])
	var gideon_ok: bool = _battle_valid(r_v5["battle"])
	for slug_v in ["voltorb", "electrode", "magnemite", "magneton", "porygon"]:
		if not gideon_slugs.has(str(slug_v)):
			gideon_ok = false
	_check("sevii_reclaim_battle_is_gideons_party", gideon_ok)
	_check("sevii_reclaim_grants_sapphire", int(_bag(st_v).get("sapphire", 0)) == 1 and bool(_flags(st_v).get("sevii_sapphire_recovered", false)))

	var r_v6: Dictionary = _run_script(st_v, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_sapphire_delivery.json", true, SEVII_SUBS)
	_check("sevii_completion_transcript", _line_texts(r_v6["lines"]) == [
		_sevii(CELIO, CELIO_P + "ThankYouGiveMeTime"),
		_sevii(CELIO, CELIO_P + "OkayThisIsGood"),
		_sevii(CELIO, CELIO_P + "LinkedUpWithLanette"),
		_sevii(CELIO, CELIO_P + "ManagedToLinkWithHoennThankYou")])
	_check("sevii_completion_effect", int(_bag(st_v).get("sapphire", 0)) == 0 and bool(_flags(st_v).get("sevii_network_machine_complete", false)))
	var r_v7: Dictionary = _run_script(st_v, _actors(["player", "celio"]), EVENTS_DIR + "sevii_celio_sapphire_delivery.json", true, SEVII_SUBS)
	_check("sevii_completion_replay_refused", not bool(r_v7["run_ok"]))

	# ------------------------------------------------------------
	# Mewtwo fixed encounter: record, gate, once semantics.
	# ------------------------------------------------------------
	var record: Dictionary = PUWFixedEncounters.record_for("cerulean_cave_mewtwo")
	_check("mewtwo_record_loads", not record.is_empty())
	_check("mewtwo_record_params", str(record.get("species", "")) == "MEWTWO" and int(record.get("species_id", 0)) == 150 and int(record.get("level", 0)) == 70 and str(record.get("map", "")) == "CeruleanCaveB1F")
	var obj_v: Variant = record.get("object", {})
	var obj: Dictionary = obj_v if obj_v is Dictionary else {}
	_check("mewtwo_record_object", int(obj.get("x", 0)) == 54 and int(obj.get("y", 0)) == 26 and str(obj.get("text_id", "")) == "TEXT_CERULEANCAVEB1F_MEWTWO")

	var st_m0: Dictionary = _story_state()
	_check("mewtwo_gate_refuses_pre_champion", not PUWFixedEncounters.access_allowed(st_m0, record))
	_check("mewtwo_gate_unmet_names_champion", str(PUWFixedEncounters.access_gate_result(st_m0, record).get("unmet", "")).contains("champion"))
	var st_m: Dictionary = _champion_state()
	_check("mewtwo_gate_allows_champion", PUWFixedEncounters.access_allowed(st_m, record))
	_check("mewtwo_available_before_outcome", PUWFixedEncounters.is_available(st_m, record))
	_check("mewtwo_run_does_not_consume", not PUWFixedEncounters.record_outcome(st_m, record, "ran") and PUWFixedEncounters.is_available(st_m, record))
	_check("mewtwo_teleport_does_not_consume", not PUWFixedEncounters.record_outcome(st_m, record, "player_teleported") and PUWFixedEncounters.is_available(st_m, record))
	_check("mewtwo_defeat_consumes", PUWFixedEncounters.record_outcome(st_m, record, "defeated") and not PUWFixedEncounters.is_available(st_m, record))
	var st_m2: Dictionary = _champion_state()
	_check("mewtwo_caught_consumes", PUWFixedEncounters.record_outcome(st_m2, record, "caught") and not PUWFixedEncounters.is_available(st_m2, record))

	var entry_m: PUWBattleEntry = PUWBattleEntry.new()
	var rng_m: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_m.seed = 777
	var identity_v: Variant = record.get("battle_identity", [])
	var identity_m: Array = identity_v if identity_v is Array else []
	var built_m: Dictionary = entry_m.start_scripted_battle(identity_m, 50, "singles", rng_m, "")
	_check("mewtwo_identity_builds", bool(built_m.get("ok", false)) and _party_slugs(built_m).has("mewtwo") and _battle_valid(built_m))

	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)
