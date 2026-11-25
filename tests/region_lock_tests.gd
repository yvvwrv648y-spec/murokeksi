extends SceneTree
## Region-lock campaign tests (Riley canon, 2026-11-22 14:46-14:56
## CST; Phase 3 item D). Run:
##   godot --headless --script res://tests/region_lock_tests.gd
##
## Code under test:
## - PUWRegionState (systems/campaign/region_state.gd): per-region
##   campaign records in state["regions"], fresh-start entry,
##   the Champion gate, the both-ways seal at 99%, the shared pool.
## - PUWTeamBuilder.build_gym_team / gym_level_bands
##   (systems/difficulty/team_builder.gd): gym leader levels follow
##   the player's GLOBAL badge-count band; species/sets unchanged.
## - PUWCampaignStitch.record_gym_win (systems/campaign/
##   campaign_stitch.gd): the availability gate, no roster order.
##
## JOHTO NOTE: when this suite was written, only Kanto had full
## game data in this project, and the Johto side used a synthetic
## second-region record to prove the region-generic STRUCTURE.
## Since binding build 3 the Johto fixtures use the REAL gym ids
## authored in data/gym_requirements.json (johto_gym_1_falkner ..
## johto_gym_8_clair); the mon names remain placeholders because
## the suite tests region state, not Johto rosters.
##
## OBEDIENCE HARD STOP (item D4): already proven by
## tests/exp_cap_tests.gd (6/0, protected baseline, unchanged):
## its test_zero_badges_clamps_to_10 gives a level 9 mon
## 1,000,000 EXP at 0 badges and asserts the EXP is stored IN
## FULL (mon["exp"] == start + 1,000,000) while the level stops
## at exactly EXPSystem.level_cap_for_badges(0) == 10;
## test_field_state_badges_clamp proves the same clamp through
## the field_state route. That is exactly the canon rule (EXP
## calculated and stored, level never past the cap for the
## current global badge count), so no duplicate proof is added
## here and that suite is not edited.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW region lock tests -- starting.")
	_run("test_fresh_start_johto_hides_kanto_party_but_keeps_it_stored", Callable(self, "test_fresh_start_johto_hides_kanto_party_but_keeps_it_stored"))
	_run("test_johto_catches_stay_in_johto_when_leaving", Callable(self, "test_johto_catches_stay_in_johto_when_leaving"))
	_run("test_99_percent_johto_sealed_both_ways", Callable(self, "test_99_percent_johto_sealed_both_ways"))
	_run("test_champion_win_joins_shared_pool", Callable(self, "test_champion_win_joins_shared_pool"))
	_run("test_reenter_beaten_kanto_restores_exact_team", Callable(self, "test_reenter_beaten_kanto_restores_exact_team"))
	_run("test_gym_scaling_brock_badge_0_vs_2", Callable(self, "test_gym_scaling_brock_badge_0_vs_2"))
	_run("test_out_of_order_gym_win_through_stitch", Callable(self, "test_out_of_order_gym_win_through_stitch"))
	_run("test_fresh_start_fiore_sealed_pool", Callable(self, "test_fresh_start_fiore_sealed_pool"))
	_run("test_ranger_finale_joins_shared_pool_oblivia", Callable(self, "test_ranger_finale_joins_shared_pool_oblivia"))
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


func _mon(mon_name: String, level: int) -> Dictionary:
	return {"name": mon_name, "species": mon_name, "level": level}


func _names(mons: Array) -> Array:
	var out: Array = []
	for mon_value: Variant in mons:
		var mon: Dictionary = mon_value
		out.append(str(mon.get("name", "")))
	return out


## A save state whose Kanto party/boxes are already populated.
## Built through the stitch's new_game_state so the regions
## structure grows on a real save shape.
func _kanto_state() -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state("riley", "TEST")
	state["party"] = [_mon("KantoAce", 40), _mon("KantoTwo", 38)]
	state["boxes"] = [_mon("KantoBoxed", 20)]
	return state


# Test 1: entering unbeaten Johto is a fresh start -- the working
# party is empty and the Kanto party is inaccessible -- while the
# Kanto Pokemon remain STORED under Kanto (not deleted).
func test_fresh_start_johto_hides_kanto_party_but_keeps_it_stored() -> bool:
	var ok: bool = true
	var state: Dictionary = _kanto_state()
	var home: Dictionary = PUWRegionState.enter_region(state, "kanto")
	ok = _expect(str(home.get("region_id", "")) == "kanto", "first entry is kanto") and ok
	ok = _expect(_names(state.get("party", [])) == ["KantoAce", "KantoTwo"], "kanto party live in kanto") and ok
	var ctx: Dictionary = PUWRegionState.enter_region(state, "johto")
	ok = _expect(bool(ctx.get("fresh_start", false)), "unbeaten johto entry is a fresh start") and ok
	ok = _expect(not bool(ctx.get("champion_beaten", true)), "johto champion not beaten") and ok
	var party_now: Array = state.get("party", [])
	ok = _expect(party_now.is_empty(), "fresh johto working party is empty, got " + str(_names(party_now))) and ok
	ok = _expect(PUWRegionState.available_party(state).is_empty(), "no pokemon accessible in fresh johto") and ok
	ok = _expect(PUWRegionState.available_boxes(state).is_empty(), "no boxed pokemon accessible in fresh johto") and ok
	ok = _expect(_names(PUWRegionState.stored_party(state, "kanto")) == ["KantoAce", "KantoTwo"], "kanto party still stored under kanto, got " + str(_names(PUWRegionState.stored_party(state, "kanto")))) and ok
	ok = _expect(_names(PUWRegionState.stored_boxes(state, "kanto")) == ["KantoBoxed"], "kanto box still stored under kanto") and ok
	ok = _expect(not PUWRegionState.region_beaten(state, "kanto"), "kanto not beaten in this state") and ok
	return ok


# Test 2: a Pokemon caught in unbeaten Johto stays in Johto's
# storage when the player leaves for Kanto.
func test_johto_catches_stay_in_johto_when_leaving() -> bool:
	var ok: bool = true
	var state: Dictionary = _kanto_state()
	PUWRegionState.enter_region(state, "johto")
	var party: Array = state.get("party", [])
	party.append(_mon("JohtoCatch", 5))
	state["party"] = party
	PUWRegionState.enter_region(state, "kanto")
	ok = _expect(_names(state.get("party", [])) == ["KantoAce", "KantoTwo"], "back in kanto the kanto party is the working party") and ok
	ok = _expect(not _names(PUWRegionState.available_party(state)).has("JohtoCatch"), "johto catch is not accessible from kanto") and ok
	ok = _expect(_names(PUWRegionState.stored_party(state, "johto")) == ["JohtoCatch"], "johto catch stored under johto, got " + str(_names(PUWRegionState.stored_party(state, "johto")))) and ok
	return ok


## Shared setup for tests 3-4: Kanto beaten, Johto at 99%
## (SYNTHETIC johto record: all 8 synthetic gym badges noted, its
## own caught mon in storage, Champion NOT beaten). Ends with
## Kanto active.
func _state_kanto_beaten_johto_99() -> Dictionary:
	var state: Dictionary = _kanto_state()
	PUWRegionState.enter_region(state, "johto")
	var party: Array = state.get("party", [])
	party.append(_mon("JohtoCatch", 30))
	state["party"] = party
	var johto_gyms: Array = [
		"johto_gym_1_falkner", "johto_gym_2_bugsy",
		"johto_gym_3_whitney", "johto_gym_4_morty",
		"johto_gym_5_chuck", "johto_gym_6_jasmine",
		"johto_gym_7_pryce", "johto_gym_8_clair"]
	for gym_value: Variant in johto_gyms:
		PUWRegionState.note_badge(state, "johto", str(gym_value))
	PUWRegionState.enter_region(state, "kanto")
	PUWRegionState.record_champion_win(state, "kanto")
	return state


# Test 3: Kanto beaten + Johto at 99% is sealed BOTH ways: from
# beaten Kanto, Johto's Pokemon cannot be exported; inside
# unbeaten Johto, the cleared Kanto team cannot be imported.
func test_99_percent_johto_sealed_both_ways() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_kanto_beaten_johto_99()
	ok = _expect(PUWRegionState.region_beaten(state, "kanto"), "kanto beaten") and ok
	ok = _expect(not PUWRegionState.region_beaten(state, "johto"), "johto champion unbeaten (99 percent)") and ok
	ok = _expect(PUWRegionState.region_badges(state, "johto").size() == 8, "johto has all 8 synthetic badges") and ok
	# Export seal: standing in beaten Kanto, Johto's mon is absent.
	var from_kanto: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(from_kanto.has("KantoAce"), "kanto ace available in beaten kanto") and ok
	ok = _expect(not from_kanto.has("JohtoCatch"), "johto catch NOT exportable to beaten kanto while johto is unbeaten") and ok
	# Import seal: entering 99% Johto, only Johto's own mon is
	# accessible -- the cleared Kanto team cannot be brought in.
	PUWRegionState.enter_region(state, "johto")
	var in_johto: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(in_johto == ["JohtoCatch"], "inside 99 percent johto only its own mon is accessible, got " + str(in_johto)) and ok
	ok = _expect(_names(PUWRegionState.stored_party(state, "kanto")) == ["KantoAce", "KantoTwo"], "kanto team still stored, untouched") and ok
	return ok


# Test 4: once Johto's Champion falls, Johto joins the shared
# pool and both regions' Pokemon are mutually available from
# either beaten region.
func test_champion_win_joins_shared_pool() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_kanto_beaten_johto_99()
	PUWRegionState.enter_region(state, "johto")
	ok = _expect(PUWRegionState.record_champion_win(state, "johto"), "johto champion win records") and ok
	ok = _expect(not PUWRegionState.record_champion_win(state, "johto"), "duplicate champion win refused") and ok
	ok = _expect(PUWRegionState.region_beaten(state, "johto"), "johto beaten") and ok
	var in_johto: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(in_johto.has("JohtoCatch") and in_johto.has("KantoAce") and in_johto.has("KantoTwo"), "from beaten johto both regions' parties are available, got " + str(in_johto)) and ok
	PUWRegionState.enter_region(state, "kanto")
	var in_kanto: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(in_kanto.has("KantoAce") and in_kanto.has("JohtoCatch"), "from beaten kanto both regions' parties are available, got " + str(in_kanto)) and ok
	return ok


# Test 5: re-entering beaten Kanto restores the exact team left
# there (names and levels, in order).
func test_reenter_beaten_kanto_restores_exact_team() -> bool:
	var ok: bool = true
	var state: Dictionary = _kanto_state()
	var left_behind: Array = []
	var original: Array = state.get("party", [])
	for mon_value: Variant in original:
		var mon: Dictionary = mon_value
		left_behind.append({"name": str(mon.get("name", "")), "level": int(mon.get("level", 0))})
	PUWRegionState.enter_region(state, "kanto")
	PUWRegionState.record_champion_win(state, "kanto")
	PUWRegionState.enter_region(state, "johto")
	var johto_party: Array = state.get("party", [])
	johto_party.append(_mon("JohtoCatch", 7))
	state["party"] = johto_party
	PUWRegionState.enter_region(state, "kanto")
	var restored: Array = state.get("party", [])
	ok = _expect(restored.size() == left_behind.size(), "restored team size matches") and ok
	for i: int in range(mini(restored.size(), left_behind.size())):
		var mon_now: Dictionary = restored[i]
		var mon_left: Dictionary = left_behind[i]
		ok = _expect(str(mon_now.get("name", "")) == str(mon_left.get("name", "")) and int(mon_now.get("level", 0)) == int(mon_left.get("level", 0)), "restored mon %d matches the team left behind" % i) and ok
	return ok


# Test 6: gym scaling. Brock's team at global badge count 0 uses
# his own 12-14 band; the SAME team at badge count 2 uses the
# third band (Surge's 22-24), species identical, in-band pattern
# preserved. A badge count past 7 clamps to the last band.
func test_gym_scaling_brock_badge_0_vs_2() -> bool:
	var ok: bool = true
	var b: PUWTeamBuilder = PUWTeamBuilder.new()
	var bands: Array = b.gym_level_bands()
	ok = _expect(bands.size() == 8, "8 gym bands, got %d" % bands.size()) and ok
	if bands.size() == 8:
		var band0: Dictionary = bands[0]
		var band2: Dictionary = bands[2]
		ok = _expect(int(band0.get("low", 0)) == 12 and int(band0.get("high", 0)) == 14, "band 0 is brock 12-14") and ok
		ok = _expect(int(band2.get("low", 0)) == 22 and int(band2.get("high", 0)) == 24, "band 2 is surge 22-24") and ok
	var team0: Array = b.build_gym_team("kanto_gym_1_brock", 0, "singles")
	var team2: Array = b.build_gym_team("kanto_gym_1_brock", 2, "singles")
	ok = _expect(team0.size() == 6 and team2.size() == 6, "both brock teams are 6 mons") and ok
	var slugs0: Array = []
	var levels0: Array = []
	for mon_value: Variant in team0:
		var mon: Dictionary = mon_value
		slugs0.append(str(mon.get("species_slug", "")))
		levels0.append(int(mon.get("level", 0)))
	var slugs2: Array = []
	var levels2: Array = []
	for mon_value: Variant in team2:
		var mon: Dictionary = mon_value
		slugs2.append(str(mon.get("species_slug", "")))
		levels2.append(int(mon.get("level", 0)))
	ok = _expect(slugs0 == slugs2, "species identical at badge counts 0 and 2: " + str(slugs0) + " vs " + str(slugs2)) and ok
	ok = _expect(slugs0 == ["geodude", "aron", "rolycoly", "rhyhorn", "kabuto", "onix"], "brock roster species unchanged (no auto-evolve), got " + str(slugs0)) and ok
	ok = _expect(levels0 == [12, 12, 13, 13, 13, 14], "badge count 0 levels are the 12-14 band pattern, got " + str(levels0)) and ok
	ok = _expect(levels2 == [22, 22, 23, 23, 23, 24], "badge count 2 levels are the 22-24 band pattern, got " + str(levels2)) and ok
	var team9: Array = b.build_gym_team("kanto_gym_1_brock", 12, "singles")
	for mon_value: Variant in team9:
		var mon: Dictionary = mon_value
		var lv: int = int(mon.get("level", 0))
		ok = _expect(lv >= 48 and lv <= 50, "badge count past 7 clamps to the 48-50 band, got %d" % lv) and ok
	return ok


# Test 7: a gym win recorded out of roster order for an AVAILABLE
# gym succeeds through the stitch: Fuchsia (Koga, no
# requirements) before Vermilion (Surge), as the run's FIRST gym
# win. Surge stays refused -- his requirements are unmet, not his
# position in the order. The win is also noted in Kanto's region
# record (region-lock integration).
func test_out_of_order_gym_win_through_stitch() -> bool:
	var ok: bool = true
	var state: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "TEST")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	var grants: Array = PUWCampaignStitch.grant_oak_picks(state, {"species_id": 7, "variant": "pokemon"}, {"species_id": 1, "variant": "pokemon"})
	ok = _expect(grants.size() == 2, "oak grants chosen (binding build 4: trio picker superseded for custom characters)") and ok
	PUWRegionState.enter_region(state, "kanto")
	ok = _expect(not PUWCampaignStitch.record_gym_win(state, "kanto_gym_3_surge"), "surge refused: requirements unmet (not order)") and ok
	ok = _expect(PUWCampaignStitch.record_gym_win(state, "kanto_gym_5_koga"), "fuchsia win before vermilion succeeds through the stitch") and ok
	ok = _expect(GymProgression.has_badge(state, "kanto_gym_5_koga"), "soul badge held") and ok
	ok = _expect(GymProgression.badge_count(state) == 1, "exactly one badge held") and ok
	ok = _expect(PUWRegionState.region_badges(state, "kanto") == ["kanto_gym_5_koga"], "win noted in kanto's region record") and ok
	var gate: Dictionary = PUWCampaignStitch.can_start_gym_battle(state, "kanto_gym_1_brock")
	ok = _expect(bool(gate.get("allowed", false)), "brock still available afterwards (any order)") and ok
	return ok


# Test 8 (binding build 4, Styler merge step 5): entering
# unbeaten Fiore is a fresh start with a sealed pool, exactly
# like any other unbeaten region -- the Kanto party stays
# stored under Kanto, nothing is accessible in Fiore, and a
# Friend befriended in Fiore stays in Fiore's storage when the
# player leaves.
func test_fresh_start_fiore_sealed_pool() -> bool:
	var ok: bool = true
	var state: Dictionary = _kanto_state()
	PUWRegionState.enter_region(state, "kanto")
	var ctx: Dictionary = PUWRegionState.enter_region(state, "fiore")
	ok = _expect(bool(ctx.get("fresh_start", false)), "unbeaten fiore entry is a fresh start") and ok
	ok = _expect(not bool(ctx.get("champion_beaten", true)), "fiore champion-equivalent not beaten") and ok
	ok = _expect(state.get("party", []).is_empty(), "fresh fiore working party is empty") and ok
	ok = _expect(PUWRegionState.available_party(state).is_empty(), "no pokemon accessible in fresh fiore") and ok
	ok = _expect(PUWRegionState.available_boxes(state).is_empty(), "no boxed pokemon accessible in fresh fiore") and ok
	ok = _expect(_names(PUWRegionState.stored_party(state, "kanto")) == ["KantoAce", "KantoTwo"], "kanto party still stored under kanto") and ok
	var fiore_party: Array = state.get("party", [])
	fiore_party.append(_mon("FioreFriend", 12))
	state["party"] = fiore_party
	PUWRegionState.enter_region(state, "kanto")
	ok = _expect(not _names(PUWRegionState.available_party(state)).has("FioreFriend"), "fiore friend is not accessible from kanto while fiore is unbeaten") and ok
	ok = _expect(_names(PUWRegionState.stored_party(state, "fiore")) == ["FioreFriend"], "fiore friend stored under fiore") and ok
	return ok


# Test 9 (binding build 4, Styler merge step 5): Oblivia's
# finale, completed through the Styler system, is a
# Champion-equivalent gate -- it beats the region through
# PUWRegionState.record_champion_win, joins the shared pool
# both ways, and grants NO badge credit anywhere.
func test_ranger_finale_joins_shared_pool_oblivia() -> bool:
	var ok: bool = true
	var state: Dictionary = _kanto_state()
	PUWRegionState.enter_region(state, "kanto")
	PUWRegionState.record_champion_win(state, "kanto")
	PUWRegionState.enter_region(state, "oblivia")
	var oblivia_party: Array = state.get("party", [])
	oblivia_party.append(_mon("ObliviaFriend", 20))
	state["party"] = oblivia_party
	ok = _expect(not PUWRegionState.region_beaten(state, "oblivia"), "oblivia not beaten before its finale") and ok
	var finale: Dictionary = PUWStylerSystem.complete_mission(state, {"id": "acceptance_sky_fortress", "is_finale": true})
	ok = _expect(bool(finale.get("ok", false)), "oblivia finale completes through the styler system") and ok
	ok = _expect(bool(finale.get("gate_opened", false)), "oblivia finale opens the champion-equivalent gate") and ok
	ok = _expect(PUWRegionState.region_beaten(state, "oblivia"), "oblivia beaten after its finale") and ok
	ok = _expect(PUWRegionState.region_badges(state, "oblivia").is_empty(), "ranger finale grants no oblivia badge credit") and ok
	ok = _expect(GymProgression.badge_count(state) == 0, "ranger finale grants no gym badges at all") and ok
	var in_oblivia: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(in_oblivia.has("ObliviaFriend") and in_oblivia.has("KantoAce"), "from beaten oblivia both regions' parties are available, got " + str(in_oblivia)) and ok
	PUWRegionState.enter_region(state, "kanto")
	var in_kanto: Array = _names(PUWRegionState.available_party(state))
	ok = _expect(in_kanto.has("KantoAce") and in_kanto.has("ObliviaFriend"), "from beaten kanto the oblivia friend is available too, got " + str(in_kanto)) and ok
	return ok
