extends SceneTree
## Styler system tests for Pokemon Ultimate World (code prep,
## 2026-11-23; V2 the same day -- checks that pinned v1 design
## constants contradicted by hunt rotation 7's sourced data
## were updated to the sourced values in place, each marked
## "v2 SOURCED-R7" / "v2:" inline; no check was deleted).
## Run: godot --headless --script res://tests/styler_tests.gd
##
## Covers Ranger Variant A (ruling P1, adopted 2026-11-23;
## ranger_deep/RANGER_DEEP.md section 1-2, build prep section
## 5.4) against COPIES of the real pack systems it integrates
## with (PUWRegionState, PUWFollowerCare, PUWSaveManager):
## - availability: the Styler exists only in Fiore/Almia/
##   Oblivia; Poke Balls are inert exactly there (the gate the
##   battle_controller patch calls) and work everywhere else;
## - Fiore's loop-count model: consecutive loops, the
##   all-or-nothing lift, line cuts, extra-loop bonus, assist
##   specials (Recharge / Fighting / Dark), Partner Gauge
##   Discharge, Rank capacity, the pre-credits habitat rule;
## - Almia's gauge model: gauge fill, free lifts, drain and
##   the Tired state, Power Charge (Rank 6 / Rank 8), the
##   four assist states, agitation, the 17-partner roster;
## - Oblivia's model: agitation at one tenth, physically
##   present assists with the rest rule, combined clears,
##   Ranger Points and the past-temple upgrade track;
## - Friend lifecycle: one help then release, partner never
##   released, transfer-reward-only permanence;
## - Ranger Rank: finales wire to record_champion_win as
##   Champion-equivalents; NO badge credit, ever;
## - PERMADEATH: the collection + faint projection of a rich
##   save is byte-identical across a full Styler session, and
##   a save round-trip keeps the Ranger records intact.

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


# ----------------------------------------------------------------
# Fixtures
# ----------------------------------------------------------------

func _mon(species: String, serial: String) -> Dictionary:
	return {
		"name": species,
		"species": species,
		"mon_id": "puw-" + serial + "-a1b2c3",
		"evo_family": species + "_family",
		"hp": 20,
		"max_hp": 20,
		"friendship": 0,
	}


func _fresh_state() -> Dictionary:
	var party: Array = [_mon("pikachu", "000001")]
	var boxes: Array = [_mon("eevee", "000002")]
	var flags: Dictionary = {"region_id": "kanto"}
	var state: Dictionary = PUWSaveManager.build_state(party, boxes, {"poke-ball": 5}, 1000, [], [], [], flags, {})
	state["locked_evo_families"] = {"pidgey_family": true}
	state["fainting_ledger"] = [{"name": "pidgey", "evo_family": "pidgey_family", "format": "standard"}]
	PUWRegionState.ensure_regions(state)
	return state


func _enter(state: Dictionary, region_id: String) -> void:
	PUWRegionState.enter_region(state, region_id)


func _target(species: String, types: Array, opts: Dictionary = {}) -> Dictionary:
	var target: Dictionary = {
		"species": species,
		"types": types,
		"location_id": "test_habitat",
	}
	for key_value: Variant in opts.keys():
		target[str(key_value)] = opts[key_value]
	return target


## Befriend one Friend through a full Fiore capture (1 loop).
func _befriend_fiore(state: Dictionary, species: String, types: Array, opts: Dictionary = {}) -> Dictionary:
	var target: Dictionary = _target(species, types, opts)
	target["loops_required"] = 1
	var session: Dictionary = PUWStylerSystem.begin_capture(state, target)
	PUWStylerSystem.session_loop(state, session)
	var result: Dictionary = PUWStylerSystem.session_lift(state, session)
	return result


## Befriend one Friend through a full gauge capture (one loop
## at base power fills a small requirement).
func _befriend_gauge(state: Dictionary, species: String, types: Array, opts: Dictionary = {}) -> Dictionary:
	var target: Dictionary = _target(species, types, opts)
	target["friendship_required"] = 10.0  # v2: one L1 loop at sourced Power 10 fills it
	var session: Dictionary = PUWStylerSystem.begin_capture(state, target)
	var result: Dictionary = PUWStylerSystem.session_loop(state, session)
	return result


## The permadeath projection: exactly the save content the
## Styler must never touch -- top-level party / boxes / badge
## list / evolution lockouts / fainting ledger, plus every
## region record's party / boxes / badge list.
func _projection(state: Dictionary) -> String:
	var proj: Dictionary = {}
	proj["party"] = state.get("party", [])
	proj["boxes"] = state.get("boxes", [])
	proj["badges"] = state.get("badges", [])
	proj["locked_evo_families"] = state.get("locked_evo_families", {})
	proj["fainting_ledger"] = state.get("fainting_ledger", [])
	var root: Dictionary = PUWRegionState.ensure_regions(state)
	var records_value: Variant = root.get("regions", {})
	var records: Dictionary = {}
	if records_value is Dictionary:
		records = records_value
	var ids: Array = records.keys()
	ids.sort()
	var per_region: Dictionary = {}
	for id_value: Variant in ids:
		var rid: String = str(id_value)
		var record_value: Variant = records.get(rid, {})
		var record: Dictionary = {}
		if record_value is Dictionary:
			record = record_value
		per_region[rid] = {
			"party": record.get("party", []),
			"boxes": record.get("boxes", []),
			"badges": record.get("badges", []),
		}
	proj["records"] = per_region
	return JSON.stringify(proj)


func _run() -> void:
	_test_availability()
	_test_records()
	_test_fiore()
	_test_almia()
	_test_oblivia()
	_test_target_clear()
	_test_rank_and_gates()
	_test_transfer_rewards()
	_test_tool_levels()
	_test_permadeath_isolation()
	_test_save_round_trip()
	_finish()


# ----------------------------------------------------------------
# Availability: region gating + the ball gate
# ----------------------------------------------------------------

func _test_availability() -> void:
	for region_value: Variant in ["fiore", "almia", "oblivia"]:
		var rid: String = str(region_value)
		_check("avail_ranger_region_" + rid, PUWRangerAvailability.is_ranger_region(rid))
		_check("avail_styler_exists_" + rid, PUWRangerAvailability.styler_exists_in(rid))
		_check("avail_balls_inert_" + rid, PUWRangerAvailability.balls_inert_in(rid))
		_check("avail_method_styler_" + rid, PUWRangerAvailability.capture_method_in(rid) == "styler")
	for region_value: Variant in ["kanto", "johto", "hoenn", "sinnoh", ""]:
		var rid: String = str(region_value)
		var label: String = rid if rid != "" else "empty"
		_check("avail_not_ranger_" + label, not PUWRangerAvailability.is_ranger_region(rid))
		_check("avail_balls_work_" + label, not PUWRangerAvailability.balls_inert_in(rid))
		_check("avail_method_ball_" + label, PUWRangerAvailability.capture_method_in(rid) == "ball")
	var state: Dictionary = _fresh_state()
	_check("avail_state_kanto_no_styler", not PUWRangerAvailability.styler_active(state))
	_check("avail_state_kanto_balls_work", not PUWRangerAvailability.balls_inert(state))
	_enter(state, "almia")
	_check("avail_state_almia_styler", PUWRangerAvailability.styler_active(state))
	_check("avail_state_almia_balls_inert", PUWRangerAvailability.balls_inert(state))
	_check("avail_state_almia_method", PUWRangerAvailability.capture_method(state) == "styler")
	_enter(state, "kanto")
	_check("avail_state_back_to_kanto", not PUWRangerAvailability.styler_active(state))
	# A capture session cannot even open outside the regions.
	_check("avail_no_session_in_kanto", PUWStylerSystem.begin_capture(state, _target("pidgey", ["normal"], {"loops_required": 1})).is_empty())


# ----------------------------------------------------------------
# Region records: fresh-start defaults + independence
# ----------------------------------------------------------------

func _test_records() -> void:
	var state: Dictionary = _fresh_state()
	_check("record_none_in_kanto", PUWStylerSystem.ranger_state(state).is_empty())
	_enter(state, "fiore")
	var fiore: Dictionary = PUWStylerSystem.ranger_state(state)
	_check("record_fiore_rank1", int(fiore.get("rank", 0)) == 1)
	_check("record_fiore_level1", int(fiore.get("styler_level", 0)) == 1)
	_check("record_fiore_energy_base", int(fiore.get("energy", 0)) == 4)  # v2 SOURCED-R7: Fiore L1 Energy = 4 (v1 DC 20 contradicted)
	_check("record_fiore_no_friends", PUWStylerSystem.friends(state).is_empty())
	PUWStylerSystem.complete_mission(state, {"id": "m1", "grants_rank": true})
	_check("record_fiore_rank2", PUWStylerSystem.current_rank(state) == 2)
	_enter(state, "almia")
	var almia: Dictionary = PUWStylerSystem.ranger_state(state)
	_check("record_almia_independent_rank1", int(almia.get("rank", 0)) == 1)
	_check("record_fiore_kept_rank2", PUWStylerSystem.current_rank(state, "fiore") == 2)
	_check("record_capacity_fiore_rank2", PUWStylerSystem.friend_capacity(state, "fiore") == 4)


# ----------------------------------------------------------------
# Fiore: the loop-count model
# ----------------------------------------------------------------

func _test_fiore() -> void:
	var state: Dictionary = _fresh_state()
	_enter(state, "fiore")
	PUWStylerSystem.assign_fixed_partner(state, "female")
	var partner_rec: Dictionary = PUWStylerSystem.partner(state)
	_check("fiore_partner_plusle_female", str(partner_rec.get("species", "")) == "plusle")
	_check("fiore_partner_discharge", str(partner_rec.get("assist_type", "")) == "discharge")

	# Consecutive loops + the all-or-nothing lift.
	var session: Dictionary = PUWStylerSystem.begin_capture(state, _target("rattata", ["normal"], {"loops_required": 3}))
	_check("fiore_model", str(session.get("model", "")) == "loop_count")
	PUWStylerSystem.session_loop(state, session)
	var two: Dictionary = PUWStylerSystem.session_loop(state, session)
	_check("fiore_two_loops", int(two.get("consecutive_loops", 0)) == 2 and not bool(two.get("requirement_met", true)))
	var lifted: Dictionary = PUWStylerSystem.session_lift(state, session)
	_check("fiore_early_lift_resets", bool(lifted.get("reset", false)) and int(session.get("consecutive_loops", -1)) == 0)
	# Line cut resets the count too.
	PUWStylerSystem.session_loop(state, session)
	PUWStylerSystem.session_loop(state, session)
	PUWStylerSystem.session_line_cut(state, session)
	_check("fiore_line_cut_resets", int(session.get("consecutive_loops", -1)) == 0)
	# Reach the count, draw one extra loop, lift: befriended,
	# with the extra-loop Exp. bonus.
	PUWStylerSystem.session_loop(state, session)
	PUWStylerSystem.session_loop(state, session)
	PUWStylerSystem.session_loop(state, session)
	PUWStylerSystem.session_loop(state, session)
	var done: Dictionary = PUWStylerSystem.session_lift(state, session)
	_check("fiore_capture_on_lift", bool(done.get("captured", false)))
	_check("fiore_extra_loop_counted", int(done.get("exp_gained", 0)) == PUWStylerSystem.EXP_PER_CAPTURE + PUWStylerSystem.EXP_PER_EXTRA_LOOP)
	var roster: Array = PUWStylerSystem.friends(state)
	_check("fiore_one_friend", roster.size() == 1)
	var friend: Dictionary = roster[0]
	_check("fiore_friend_shape_not_a_mon", not friend.has("mon_id") and not friend.has("evo_family") and not friend.has("hp"))
	_check("fiore_friend_via_styler", str(friend.get("via", "")) == "styler")

	# Line hits cost Energy (persisted) and reset the count.
	var s2: Dictionary = PUWStylerSystem.begin_capture(state, _target("pidgey", ["normal", "flying"], {"loops_required": 5}))
	PUWStylerSystem.session_loop(state, s2)
	var energy_pre_hit: int = PUWStylerSystem.current_energy(state)
	var hit: Dictionary = PUWStylerSystem.session_line_hit(state, s2, 2)
	_check("fiore_line_hit_energy", int(hit.get("energy", -1)) == energy_pre_hit - 2 and PUWStylerSystem.current_energy(state) == energy_pre_hit - 2)  # v2: sourced L1 Energy is 4, so the hit is 2, asserted relatively
	_check("fiore_line_hit_resets", int(s2.get("consecutive_loops", -1)) == 0)
	PUWStylerSystem.session_flee(state, s2)

	# Assist duration tiers (documented 10/20/30/60).
	_check("fiore_duration_immune", PUWStylerSystem.fiore_assist_duration(0.0) == 0.0)
	_check("fiore_duration_resisted", PUWStylerSystem.fiore_assist_duration(0.5) == 10.0)
	_check("fiore_duration_neutral", PUWStylerSystem.fiore_assist_duration(1.0) == 20.0)
	_check("fiore_duration_super", PUWStylerSystem.fiore_assist_duration(2.0) == 30.0)
	_check("fiore_duration_double_super", PUWStylerSystem.fiore_assist_duration(4.0) == 60.0)

	# Grass assist: Immobilized state, target cannot act.
	_befriend_fiore(state, "oddish", ["grass", "poison"], {"assist_type": "grass"})
	var s3: Dictionary = PUWStylerSystem.begin_capture(state, _target("zubat", ["poison", "flying"], {"loops_required": 9}))
	var grass_idx: int = PUWStylerSystem.friends(state).size() - 1
	var grass_result: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, s3, grass_idx, 2.0)
	_check("fiore_grass_assist_immobilized", str(grass_result.get("state", "")) == "immobilized" and float(s3.get("status_seconds", 0.0)) == 30.0)
	_check("fiore_immobilized_target_cannot_act", not PUWStylerSystem.target_can_act(s3))
	_check("fiore_assist_releases_friend", PUWStylerSystem.friends(state).size() == 1)
	PUWStylerSystem.session_flee(state, s3)

	# Fighting assist unlocks at Rank 2: each loop counts as two.
	PUWStylerSystem.complete_mission(state, {"id": "rank_up_fighting", "grants_rank": true})
	_befriend_fiore(state, "machop", ["fighting"], {"assist_type": "fighting"})
	var s4: Dictionary = PUWStylerSystem.begin_capture(state, _target("onix", ["rock", "ground"], {"loops_required": 3}))
	PUWStylerSystem.session_apply_friend_assist(state, s4, PUWStylerSystem.friends(state).size() - 1, 1.0)
	var one_loop: Dictionary = PUWStylerSystem.session_loop(state, s4)
	_check("fiore_fighting_loop_counts_two", int(one_loop.get("consecutive_loops", 0)) == 2)
	PUWStylerSystem.session_flee(state, s4)

	# Recharge assist: +5 Energy instead of attacking.
	_befriend_fiore(state, "pikachu", ["electric"], {"assist_type": "electric"})
	var energy_before: int = PUWStylerSystem.current_energy(state)
	var s5: Dictionary = PUWStylerSystem.begin_capture(state, _target("geodude", ["rock", "ground"], {"loops_required": 9}))
	var rec_result: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, s5, PUWStylerSystem.friends(state).size() - 1, 1.0)
	_check("fiore_recharge_plus5", int(rec_result.get("energy_restored", 0)) == 5 and PUWStylerSystem.current_energy(state) == mini(PUWStylerSystem.energy_max("fiore", PUWStylerSystem.styler_level(state)), energy_before + 5))  # v2: clamp is the sourced per-level max, not v1's base 20
	PUWStylerSystem.session_flee(state, s5)

	# Dark assist is Rank-gated (unlocks at Rank 7).
	_befriend_fiore(state, "umbreon", ["dark"], {"assist_type": "dark"})
	var s6: Dictionary = PUWStylerSystem.begin_capture(state, _target("abra", ["psychic"], {"loops_required": 9}))
	var dark_early: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, s6, PUWStylerSystem.friends(state).size() - 1, 1.0)
	_check("fiore_dark_locked_at_rank1", not bool(dark_early.get("ok", true)) and str(dark_early.get("reason", "")) == "assist_not_unlocked_at_rank")
	PUWStylerSystem.session_flee(state, s6)
	for i in 5:
		PUWStylerSystem.complete_mission(state, {"id": "rank_up_" + str(i), "grants_rank": true})
	_check("fiore_rank7_reached", PUWStylerSystem.current_rank(state) == 7)
	var s7: Dictionary = PUWStylerSystem.begin_capture(state, _target("abra", ["psychic"], {"loops_required": 9}))
	PUWStylerSystem.restore_energy(state, 999)  # v2: top up first -- sourced Fiore Energy is small and Dark's price is 5
	var energy_pre_dark: int = PUWStylerSystem.current_energy(state)
	var dark_ok: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, s7, PUWStylerSystem.friends(state).size() - 1, 1.0)
	_check("fiore_dark_trades_energy_for_line", bool(dark_ok.get("ok", false)) and bool(s7.get("double_line", false)) and PUWStylerSystem.current_energy(state) == energy_pre_dark - 5)
	PUWStylerSystem.session_flee(state, s7)

	# Ice assist unlocks at Rank 8: the Frozen state.
	PUWStylerSystem.complete_mission(state, {"id": "rank_up_ice", "grants_rank": true})
	_befriend_fiore(state, "seel", ["water", "ice"], {"assist_type": "ice"})
	var s8i: Dictionary = PUWStylerSystem.begin_capture(state, _target("zubat", ["poison", "flying"], {"loops_required": 9}))
	var ice_result: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, s8i, PUWStylerSystem.friends(state).size() - 1, 2.0)
	_check("fiore_ice_assist_frozen", str(ice_result.get("state", "")) == "frozen" and float(s8i.get("status_seconds", 0.0)) == 30.0)
	_check("fiore_frozen_target_cannot_act", not PUWStylerSystem.target_can_act(s8i))
	PUWStylerSystem.session_flee(state, s8i)

	# Capacity at Rank 7 is 6; the roster refuses beyond it.
	while PUWStylerSystem.friends(state).size() < 6:
		_befriend_fiore(state, "caterpie", ["bug"], {})
	_check("fiore_roster_at_capacity", PUWStylerSystem.friends(state).size() == 6 and PUWStylerSystem.friend_capacity(state) == 6)
	var overflow: Dictionary = _befriend_fiore(state, "weedle", ["bug", "poison"], {})
	_check("fiore_roster_full_refuses", not bool(overflow.get("captured", true)) and str(overflow.get("reason", "")) == "roster_full")
	_check("fiore_roster_still_6", PUWStylerSystem.friends(state).size() == 6)

	# Pre-credits habitat rule: leaving releases every Friend.
	var left: Dictionary = PUWStylerSystem.leave_habitat(state)
	_check("fiore_habitat_releases_all", int(left.get("released", 0)) == 6 and PUWStylerSystem.friends(state).is_empty())
	_befriend_fiore(state, "caterpie", ["bug"], {})
	PUWStylerSystem.complete_mission(state, {"id": "fiore_finale", "is_finale": true})
	var left2: Dictionary = PUWStylerSystem.leave_habitat(state)
	_check("fiore_post_credits_carry_out", int(left2.get("released", -1)) == 0 and PUWStylerSystem.friends(state).size() == 1)

	# Partner Gauge Discharge: Rank 7 = 4 segments = 40 loops.
	var s8: Dictionary = PUWStylerSystem.begin_capture(state, _target("snorlax", ["normal"], {"loops_required": 99}))
	var early_discharge: Dictionary = PUWStylerSystem.session_apply_partner_assist(state, s8, 1.0)
	_check("fiore_discharge_needs_full_gauge", not bool(early_discharge.get("ok", true)) and str(early_discharge.get("reason", "")) == "partner_gauge_not_full")
	for i in 40:
		PUWStylerSystem.session_loop(state, s8)
	var discharge: Dictionary = PUWStylerSystem.session_apply_partner_assist(state, s8, 1.0)
	_check("fiore_discharge_fires", bool(discharge.get("ok", false)) and str(discharge.get("state", "")) == "immobilized" and float(s8.get("status_seconds", 0.0)) == 20.0)
	_check("fiore_partner_never_released", not PUWStylerSystem.partner(state).is_empty())
	PUWStylerSystem.session_flee(state, s8)


# ----------------------------------------------------------------
# Almia: the gauge + Power Charge model
# ----------------------------------------------------------------

func _test_almia() -> void:
	var state: Dictionary = _fresh_state()
	_enter(state, "almia")
	_check("almia_capacity_rank1_base", PUWStylerSystem.friend_capacity(state) == 3)

	# Gauge fill, free lifts, drain.
	var session: Dictionary = PUWStylerSystem.begin_capture(state, _target("starly", ["normal", "flying"], {"friendship_required": 1000.0}))
	_check("almia_model", str(session.get("model", "")) == "gauge")
	PUWStylerSystem.session_loop(state, session)
	_check("almia_first_loop_power", absf(float(session.get("gauge", 0.0)) - 10.0) < 0.001)  # v2 SOURCED-R7: Almia L1 Power = 10 (v1's 350 base contradicted)
	PUWStylerSystem.session_loop(state, session)
	_check("almia_chain_bonus", absf(float(session.get("gauge", 0.0)) - 30.0) < 0.001)  # v2: 10 + (10 + 10/loop DC chain)
	PUWStylerSystem.session_lift(state, session)
	_check("almia_lift_keeps_gauge", absf(float(session.get("gauge", 0.0)) - 30.0) < 0.001 and int(session.get("consecutive_loops", -1)) == 0)
	PUWStylerSystem.session_tick(state, session, 1.0)
	_check("almia_gauge_drains", absf(float(session.get("gauge", 0.0)) - 20.0) < 0.001)  # v2: 1s at the DC drain rate on a 1000 requirement

	# Fire assist (Rank 2 unlock): the Tired state stops drain.
	PUWStylerSystem.complete_mission(state, {"id": "almia_rank2", "grants_rank": true})
	_befriend_gauge(state, "chimchar", ["fire"], {"assist_type": "fire"})
	var fire_result: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, session, PUWStylerSystem.friends(state).size() - 1, 1.0)
	_check("almia_fire_assist_tired", str(fire_result.get("state", "")) == "tired" and absf(float(fire_result.get("gauge_gain", 0.0)) - 150.0) < 0.001)
	_check("almia_assist_releases_friend", PUWStylerSystem.friends(state).is_empty())
	PUWStylerSystem.session_tick(state, session, 10.0)
	_check("almia_tired_stops_drain", absf(float(session.get("gauge", 0.0)) - 170.0) < 0.001)  # v2: 20 + 150 assist gain, drain held by Tired
	PUWStylerSystem.session_flee(state, session)

	# Power Charge: ready time, Rank 6 speed, Rank 8 level 2.
	var cs: Dictionary = PUWStylerSystem.begin_capture(state, _target("bidoof", ["normal"], {"friendship_required": 100000.0}))
	var c0: Dictionary = PUWStylerSystem.session_charge(state, cs, 1.0)
	_check("almia_charge_not_ready", int(c0.get("charge_level", -1)) == 0)
	var c1: Dictionary = PUWStylerSystem.session_charge(state, cs, 2.0)
	_check("almia_charge_level1", int(c1.get("charge_level", -1)) == 1)
	var charged_loop: Dictionary = PUWStylerSystem.session_loop(state, cs)
	_check("almia_charged_loop_mult", absf(float(charged_loop.get("gain", 0.0)) - float(PUWStylerSystem.power_at_level("almia", PUWStylerSystem.styler_level(state))) * 1.5) < 0.001 and int(cs.get("charge_level", -1)) == 0)  # v2: sourced per-level Power x the DC charge mult
	for i in 4:
		PUWStylerSystem.complete_mission(state, {"id": "almia_rank_up_" + str(i), "grants_rank": true})
	_check("almia_rank6", PUWStylerSystem.current_rank(state) == 6)
	var c2: Dictionary = PUWStylerSystem.session_charge(state, cs, 1.0)
	_check("almia_charge_faster_at_rank6", int(c2.get("charge_level", -1)) == 1)
	PUWStylerSystem.session_charge(state, cs, 0.0)
	for i in 2:
		PUWStylerSystem.complete_mission(state, {"id": "almia_rank_up2_" + str(i), "grants_rank": true})
	var c3: Dictionary = PUWStylerSystem.session_charge(state, cs, 2.0)
	_check("almia_charge_level2_at_rank8", int(c3.get("charge_level", -1)) == 2 and PUWStylerSystem.current_rank(state) == 8)
	PUWStylerSystem.session_flee(state, cs)

	# Agitation halves Styler Power (design constant 0.5);
	# assist power is never cut.
	var ag: Dictionary = PUWStylerSystem.begin_capture(state, _target("zubat", ["poison", "flying"], {"friendship_required": 100000.0}))
	var calm_power: float = PUWStylerSystem.loop_power(state, ag)
	PUWStylerSystem.session_set_agitated(ag, true)
	var agitated_power: float = PUWStylerSystem.loop_power(state, ag)
	_check("almia_agitation_halves_power", absf(agitated_power - calm_power * 0.5) < 0.001)
	var dummy_friend: Dictionary = {"assist_type": "grass", "evo_stage": 2}
	var gain_agitated: float = PUWStylerSystem.assist_gauge_gain(ag, dummy_friend, 1.0)
	PUWStylerSystem.session_set_agitated(ag, false)
	var gain_calm: float = PUWStylerSystem.assist_gauge_gain(ag, dummy_friend, 1.0)
	_check("almia_assist_power_immune_to_agitation", absf(gain_agitated - gain_calm) < 0.001 and gain_calm > 0.0)
	PUWStylerSystem.session_flee(state, ag)

	# Fighting assist doubles every loop's damage.
	_befriend_gauge(state, "machop", ["fighting"], {"assist_type": "fighting"})
	var fs: Dictionary = PUWStylerSystem.begin_capture(state, _target("onix", ["rock", "ground"], {"friendship_required": 100000.0}))
	PUWStylerSystem.session_apply_friend_assist(state, fs, PUWStylerSystem.friends(state).size() - 1, 1.0)
	var fight_loop: Dictionary = PUWStylerSystem.session_loop(state, fs)
	_check("almia_fighting_doubles_loop", absf(float(fight_loop.get("gain", 0.0)) - float(PUWStylerSystem.power_at_level("almia", PUWStylerSystem.styler_level(state))) * 2.0) < 0.001)  # v2: sourced per-level Power, doubled
	PUWStylerSystem.session_flee(state, fs)

	# Ice assist is Rank-gated at 5 -- this state is Rank 8, so
	# use a fresh low-rank state for the refusal, then the
	# success at Rank 5 in the capacity state below.
	var low: Dictionary = _fresh_state()
	_enter(low, "almia")
	PUWStylerSystem.complete_mission(low, {"id": "low_rank2", "grants_rank": true})
	_befriend_gauge(low, "snover", ["grass", "ice"], {"assist_type": "ice"})
	var ls: Dictionary = PUWStylerSystem.begin_capture(low, _target("gible", ["dragon", "ground"], {"friendship_required": 100000.0}))
	var ice_early: Dictionary = PUWStylerSystem.session_apply_friend_assist(low, ls, 0, 1.0)
	_check("almia_ice_locked_before_rank5", not bool(ice_early.get("ok", true)) and str(ice_early.get("reason", "")) == "assist_not_unlocked_at_rank")
	for i in 3:
		PUWStylerSystem.complete_mission(low, {"id": "low_rank_up_" + str(i), "grants_rank": true})
	var ice_ok: Dictionary = PUWStylerSystem.session_apply_friend_assist(low, ls, 0, 1.0)
	_check("almia_ice_stopped_at_rank5", bool(ice_ok.get("ok", false)) and str(ice_ok.get("state", "")) == "stopped")
	PUWStylerSystem.session_flee(low, ls)

	# Capacity milestones on a fresh track: 3 (base, design
	# constant) -> 4 at Rank 3 -> 7 at Rank 9.
	var cap: Dictionary = _fresh_state()
	_enter(cap, "almia")
	_check("almia_capacity_base3", PUWStylerSystem.friend_capacity(cap) == 3)
	for i in 2:
		PUWStylerSystem.complete_mission(cap, {"id": "cap_up_" + str(i), "grants_rank": true})
	_check("almia_capacity_rank3_is4", PUWStylerSystem.friend_capacity(cap) == 4)
	for i in 6:
		PUWStylerSystem.complete_mission(cap, {"id": "cap_up2_" + str(i), "grants_rank": true})
	_check("almia_capacity_rank9_is7", PUWStylerSystem.friend_capacity(cap) == 7)

	# The 17-partner roster: channels, the Farm swap, and the
	# partner assist riding its Partner Energy gauge.
	var ps: Dictionary = _fresh_state()
	_enter(ps, "almia")
	var wrong_channel: Dictionary = PUWStylerSystem.unlock_partner(ps, "pachirisu", "quest")
	_check("almia_partner_wrong_channel", not bool(wrong_channel.get("ok", true)) and str(wrong_channel.get("reason", "")) == "wrong_acquisition_channel")
	var starter: Dictionary = PUWStylerSystem.unlock_partner(ps, "pachirisu", "starter")
	_check("almia_partner_starter_active", bool(starter.get("ok", false)) and str(PUWStylerSystem.partner(ps).get("species", "")) == "pachirisu")
	PUWStylerSystem.unlock_partner(ps, "turtwig", "quest")
	_check("almia_partner_farm_waits", str(PUWStylerSystem.partner(ps).get("species", "")) == "pachirisu")
	var locked_swap: Dictionary = PUWStylerSystem.set_active_partner(ps, "gible")
	_check("almia_partner_swap_locked_refused", not bool(locked_swap.get("ok", true)))
	var swap: Dictionary = PUWStylerSystem.set_active_partner(ps, "turtwig")
	_check("almia_partner_swap_by_talking", bool(swap.get("ok", false)) and str(PUWStylerSystem.partner(ps).get("assist_type", "")) == "grass")
	PUWStylerSystem.set_active_partner(ps, "pachirisu")
	var pgs: Dictionary = PUWStylerSystem.begin_capture(ps, _target("starly", ["normal", "flying"], {"friendship_required": 100000.0}))
	var p_early: Dictionary = PUWStylerSystem.session_apply_partner_assist(ps, pgs, 1.0)
	_check("almia_partner_gauge_gate", not bool(p_early.get("ok", true)) and str(p_early.get("reason", "")) == "partner_gauge_not_full")
	for i in 4:
		PUWStylerSystem.session_loop(ps, pgs)
	var p_ok: Dictionary = PUWStylerSystem.session_apply_partner_assist(ps, pgs, 1.0)
	_check("almia_partner_assist_fires", bool(p_ok.get("ok", false)) and str(p_ok.get("state", "")) == "stopped" and float(pgs.get("partner_gauge", -1.0)) == 0.0)
	_check("almia_partner_still_traveling", str(PUWStylerSystem.partner(ps).get("species", "")) == "pachirisu")
	PUWStylerSystem.session_flee(ps, pgs)


# ----------------------------------------------------------------
# Oblivia: agitation at one tenth, presence assists, points
# ----------------------------------------------------------------

func _test_oblivia() -> void:
	var state: Dictionary = _fresh_state()
	_enter(state, "oblivia")
	_check("oblivia_energy_opens_at_10", PUWStylerSystem.current_energy(state) == 10)
	_check("oblivia_capacity_flat_7", PUWStylerSystem.friend_capacity(state) == 7)
	PUWStylerSystem.assign_fixed_partner(state)
	var pichu: Dictionary = PUWStylerSystem.partner(state)
	_check("oblivia_partner_ukulele_pichu", str(pichu.get("species", "")) == "pichu" and str(pichu.get("accessory", "")) == "ukulele" and bool(pichu.get("is_partner", false)))

	# Agitation: Styler Power to one tenth (documented).
	var session: Dictionary = PUWStylerSystem.begin_capture(state, _target("pidgey", ["normal", "flying"], {"friendship_required": 100000.0}))
	var calm: float = PUWStylerSystem.loop_power(state, session)
	PUWStylerSystem.session_set_agitated(session, true)
	var agitated: float = PUWStylerSystem.loop_power(state, session)
	_check("oblivia_agitation_one_tenth", absf(agitated - calm * 0.1) < 0.001)
	PUWStylerSystem.session_flee(state, session)

	# Ranger Points: SOURCED-R7 economy (v1's DC grade table
	# {S:100, A:60, B:30, C:10} x 0.25 repeat was contradicted
	# and removed -- see PREP_REPORT.md change log).
	var a1: Dictionary = PUWStylerSystem.award_srank_points(state, "pidgey")
	_check("oblivia_points_srank_first_species_1rp", int(a1.get("awarded", 0)) == 1 and PUWStylerSystem.points(state) == 1)
	var a2: Dictionary = PUWStylerSystem.award_srank_points(state, "pidgey")
	_check("oblivia_points_srank_repeat_species_zero", int(a2.get("awarded", -1)) == 0 and PUWStylerSystem.points(state) == 1)
	PUWStylerSystem.award_mission_clear_points(state, "oblivia_m1")
	_check("oblivia_points_mission_clear_50", PUWStylerSystem.points(state) == 51)
	PUWStylerSystem.award_quest_clear_points(state, "oblivia_q1", 30)
	_check("oblivia_points_quest_in_range", PUWStylerSystem.points(state) == 81)
	var bad_quest: Dictionary = PUWStylerSystem.award_quest_clear_points(state, "oblivia_q2", 5)
	_check("oblivia_points_quest_out_of_range_refused", not bool(bad_quest.get("ok", true)) and PUWStylerSystem.points(state) == 81)
	var buy: Dictionary = PUWStylerSystem.buy_modification(state, "recovery_plus")
	_check("oblivia_points_buy_modification", bool(buy.get("ok", false)) and int(buy.get("cost", 0)) == 50 and PUWStylerSystem.points(state) == 31 and PUWStylerSystem.modification_level(state, "recovery_plus") == 1)
	var poor: Dictionary = PUWStylerSystem.buy_modification(state, "line_plus")
	_check("oblivia_points_insufficient", not bool(poor.get("ok", true)) and PUWStylerSystem.points(state) == 31)
	var almia_state: Dictionary = _fresh_state()
	_enter(almia_state, "almia")
	_check("oblivia_points_track_is_oblivia_only", not bool(PUWStylerSystem.award_srank_points(almia_state, "pidgey").get("ok", true)))

	# Past-temple track: three axes, each to level 5.
	PUWStylerSystem.award_past_points(state, 2000)
	var up1: Dictionary = PUWStylerSystem.upgrade_past_partner(state, "assist")
	_check("oblivia_past_upgrade", bool(up1.get("ok", false)) and int(up1.get("level", 0)) == 1)
	for i in 4:
		PUWStylerSystem.upgrade_past_partner(state, "assist")
	var maxed: Dictionary = PUWStylerSystem.upgrade_past_partner(state, "assist")
	_check("oblivia_past_axis_maxed_at_5", not bool(maxed.get("ok", true)) and str(maxed.get("reason", "")) == "axis_maxed")
	var bad_axis: Dictionary = PUWStylerSystem.upgrade_past_partner(state, "speed")
	_check("oblivia_past_unknown_axis", not bool(bad_axis.get("ok", true)))

	# Physically present assists: the Friend steps on the
	# field, can be hit and must rest, and is released when
	# the session ends -- not before.
	_befriend_gauge(state, "oddish", ["grass", "poison"], {"assist_type": "grass"})
	var ps: Dictionary = PUWStylerSystem.begin_capture(state, _target("rattata", ["normal"], {"friendship_required": 100000.0}))
	var present: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, ps, 0, 1.0)
	_check("oblivia_assist_present", bool(present.get("assistant_present", false)) and PUWStylerSystem.friends(state).size() == 1)
	_check("oblivia_assist_state_slowed", str(present.get("state", "")) == "slowed")
	var hit: Dictionary = PUWStylerSystem.session_assistant_hit(state, ps)
	_check("oblivia_assistant_hit_rests", bool(hit.get("ok", false)) and bool(ps.get("assistant_rested", false)))
	var while_resting: Dictionary = PUWStylerSystem.session_apply_friend_assist(state, ps, 0, 1.0)
	_check("oblivia_no_assist_while_resting", not bool(while_resting.get("ok", true)) and str(while_resting.get("reason", "")) == "assistant_resting")
	PUWStylerSystem.session_tick(state, ps, 10.0)
	_check("oblivia_rest_elapses", not bool(ps.get("assistant_rested", true)))
	PUWStylerSystem.session_flee(state, ps)
	_check("oblivia_assistant_released_at_session_end", PUWStylerSystem.friends(state).is_empty())

	# Charged signs ride the real care threshold (160).
	_check("sign_charge_at_threshold", PUWStylerSystem.charged_sign_allowed({"friendship": 160}))
	_check("sign_charge_below_threshold", not PUWStylerSystem.charged_sign_allowed({"friendship": 159}))
	_check("sign_charge_happiness_fallback", PUWStylerSystem.charged_sign_allowed({"happiness": 200}))


# ----------------------------------------------------------------
# Target Clear: tier grading, combined clears, release rule
# ----------------------------------------------------------------

func _test_target_clear() -> void:
	_check("clear_qualifies_at_tier", PUWStylerSystem.field_qualifies(3, 3))
	_check("clear_refuses_below_tier", not PUWStylerSystem.field_qualifies(2, 3))

	var state: Dictionary = _fresh_state()
	_enter(state, "fiore")
	_befriend_fiore(state, "machop", ["fighting"], {"field_moves": {"crush": 3}})
	_befriend_fiore(state, "geodude", ["rock", "ground"], {"field_moves": {"crush": 2}})
	var weak: Dictionary = PUWStylerSystem.friend_target_clear(state, {"move": "crush", "tier": 3}, [1])
	_check("clear_weak_helper_refused_and_kept", not bool(weak.get("ok", true)) and PUWStylerSystem.friends(state).size() == 2)
	var cleared: Dictionary = PUWStylerSystem.friend_target_clear(state, {"move": "crush", "tier": 3}, [0])
	_check("clear_success_releases_helper", bool(cleared.get("cleared", false)) and int(cleared.get("released", 0)) == 1 and PUWStylerSystem.friends(state).size() == 1)

	# Combined clears exist only in Oblivia.
	var almia_state: Dictionary = _fresh_state()
	_enter(almia_state, "almia")
	_befriend_gauge(almia_state, "machop", ["fighting"], {"field_moves": {"cut": 3}})
	_befriend_gauge(almia_state, "scyther", ["bug", "flying"], {"field_moves": {"cut": 3}})
	var not_gs: Dictionary = PUWStylerSystem.friend_target_clear(almia_state, {"move": "cut", "tier": 5}, [0, 1])
	_check("clear_combined_not_in_almia", not bool(not_gs.get("ok", true)) and str(not_gs.get("reason", "")) == "combined_clears_not_in_region")
	var single: Dictionary = PUWStylerSystem.friend_target_clear(almia_state, {"move": "cut", "tier": 3}, [0])
	_check("clear_single_in_almia", bool(single.get("cleared", false)) and PUWStylerSystem.friends(almia_state).size() == 1)

	var oblivia_state: Dictionary = _fresh_state()
	_enter(oblivia_state, "oblivia")
	_befriend_gauge(oblivia_state, "machop", ["fighting"], {"field_moves": {"cut": 3}})
	_befriend_gauge(oblivia_state, "scyther", ["bug", "flying"], {"field_moves": {"cut": 3}})
	var one_short: Dictionary = PUWStylerSystem.friend_target_clear(oblivia_state, {"move": "cut", "tier": 5}, [0])
	_check("clear_combined_one_short", not bool(one_short.get("ok", true)) and PUWStylerSystem.friends(oblivia_state).size() == 2)
	var combined: Dictionary = PUWStylerSystem.friend_target_clear(oblivia_state, {"move": "cut", "tier": 5}, [0, 1])
	_check("clear_combined_succeeds_releases_both", bool(combined.get("cleared", false)) and int(combined.get("released", 0)) == 2 and PUWStylerSystem.friends(oblivia_state).is_empty())


# ----------------------------------------------------------------
# Rank, finales, and the no-badge-credit rule
# ----------------------------------------------------------------

func _test_rank_and_gates() -> void:
	var state: Dictionary = _fresh_state()
	state["badges"] = ["boulder_badge"]
	_enter(state, "almia")
	PUWStylerSystem.complete_mission(state, {"id": "school_exam"})
	_check("gate_mission_counts", int(PUWStylerSystem.ranger_state(state).get("missions_completed", 0)) == 1)
	_check("gate_not_open_before_finale", not PUWRegionState.region_beaten(state, "almia"))
	var finale: Dictionary = PUWStylerSystem.complete_mission(state, {"id": "operation_brighton", "is_finale": true})
	_check("gate_finale_opens_region", bool(finale.get("gate_opened", false)) and PUWRegionState.region_beaten(state, "almia"))
	_check("gate_no_badge_credit_global", state.get("badges", []) == ["boulder_badge"])
	_check("gate_no_badge_credit_region", PUWRegionState.region_badges(state, "almia").is_empty())

	var cap_state: Dictionary = _fresh_state()
	_enter(cap_state, "fiore")
	for i in 15:
		PUWStylerSystem.complete_mission(cap_state, {"id": "cap_mission_" + str(i), "grants_rank": true})
	_check("rank_caps_at_10", PUWStylerSystem.current_rank(cap_state) == 10)


# ----------------------------------------------------------------
# Transfer rewards: the only permanent gains
# ----------------------------------------------------------------

func _test_transfer_rewards() -> void:
	var state: Dictionary = _fresh_state()
	var in_kanto: Dictionary = PUWStylerSystem.grant_transfer_reward(state, "manaphy_egg")
	_check("reward_none_outside_ranger_regions", not bool(in_kanto.get("ok", true)))
	_enter(state, "almia")
	var wrong_region: Dictionary = PUWStylerSystem.grant_transfer_reward(state, "deoxys")
	_check("reward_wrong_source_region", not bool(wrong_region.get("ok", true)) and str(wrong_region.get("reason", "")) == "reward_not_from_this_region")
	var granted: Dictionary = PUWStylerSystem.grant_transfer_reward(state, "aura_sphere_riolu")
	_check("reward_granted_in_almia", bool(granted.get("ok", false)))
	var duplicate: Dictionary = PUWStylerSystem.grant_transfer_reward(state, "aura_sphere_riolu")
	_check("reward_once_only_grant", not bool(duplicate.get("ok", true)))
	PUWStylerSystem.grant_transfer_reward(state, "manaphy_egg")
	_check("reward_two_pending", PUWStylerSystem.pending_transfer_rewards(state).size() == 2)
	# Captures never produce a reward.
	_befriend_gauge(state, "bidoof", ["normal"], {})
	_befriend_gauge(state, "starly", ["normal", "flying"], {})
	_check("reward_captures_grant_nothing", PUWStylerSystem.pending_transfer_rewards(state).size() == 2)
	var claim_in_region: Dictionary = PUWStylerSystem.claim_transfer_reward(state, "aura_sphere_riolu")
	_check("reward_claim_refused_in_region", not bool(claim_in_region.get("ok", true)) and str(claim_in_region.get("reason", "")) == "received_in_the_wider_game")
	_enter(state, "kanto")
	var boxes_before: int = (state.get("boxes", []) as Array).size()
	var claimed: Dictionary = PUWStylerSystem.claim_transfer_reward(state, "aura_sphere_riolu")
	_check("reward_claimed_in_wider_game", bool(claimed.get("ok", false)))
	var boxes_after: Array = state.get("boxes", [])
	_check("reward_exactly_one_mon_added", boxes_after.size() == boxes_before + 1)
	var added: Dictionary = boxes_after[boxes_after.size() - 1]
	_check("reward_mon_identity", str(added.get("species", "")) == "riolu" and str(added.get("transfer_reward", "")) == "aura_sphere_riolu" and str(added.get("origin", "")) == "ranger_transfer")
	var reclaimed: Dictionary = PUWStylerSystem.claim_transfer_reward(state, "aura_sphere_riolu")
	_check("reward_claim_once_only", not bool(reclaimed.get("ok", true)))
	var egg: Dictionary = PUWStylerSystem.claim_transfer_reward(state, "manaphy_egg")
	_check("reward_manaphy_egg", bool(egg.get("ok", false)) and bool(egg.get("mon", {}).get("egg", false)) and str(egg.get("mon", {}).get("species", "")) == "manaphy")
	_check("reward_none_pending_after", PUWStylerSystem.pending_transfer_rewards(state).is_empty())


# ----------------------------------------------------------------
# Styler levels, energy, the broken-Styler rule
# ----------------------------------------------------------------

func _test_tool_levels() -> void:
	_check("tool_exp_curve_endpoints", PUWStylerSystem.exp_for_level("fiore", 1) == 0 and PUWStylerSystem.exp_for_level("fiore", 20) == 70800 and PUWStylerSystem.exp_for_level("fiore", 2) == 100)  # v2 SOURCED-R7 table: L2 total = 100 (v1 interpolated 3726)
	_check("tool_energy_endpoints", PUWStylerSystem.energy_max("fiore", 1) == 4 and PUWStylerSystem.energy_max("fiore", 20) == 60)  # v2 SOURCED-R7: L1 Energy = 4
	_check("tool_line_endpoints", PUWStylerSystem.line_length("fiore", 1) == 100 and PUWStylerSystem.line_length("fiore", 20) == 200)  # v2 SOURCED-R7: L1 Line = 100

	var state: Dictionary = _fresh_state()
	_enter(state, "fiore")
	var session: Dictionary = PUWStylerSystem.begin_capture(state, _target("onix", ["rock", "ground"], {"loops_required": 99}))
	var broken: Dictionary = PUWStylerSystem.session_line_hit(state, session, 20)
	_check("tool_broken_at_zero_energy", bool(broken.get("styler_broken", false)) and PUWStylerSystem.current_energy(state) == 0)
	_check("tool_no_capture_while_broken", PUWStylerSystem.begin_capture(state, _target("pidgey", ["normal"], {"loops_required": 1})).is_empty())
	PUWStylerSystem.restore_energy(state, 10)
	_check("tool_restore_revives", PUWStylerSystem.current_energy(state) == 4 and not PUWStylerSystem.begin_capture(state, _target("pidgey", ["normal"], {"loops_required": 1})).is_empty())  # v2: restore clamps to the sourced L1 max of 4

	var level_state: Dictionary = _fresh_state()
	_enter(level_state, "fiore")
	var ls: Dictionary = PUWStylerSystem.begin_capture(level_state, _target("onix", ["rock", "ground"], {"loops_required": 99}))
	PUWStylerSystem.session_line_hit(level_state, ls, 2)
	PUWStylerSystem.session_flee(level_state, ls)
	var up: Dictionary = PUWStylerSystem.award_styler_exp(level_state, 100)
	_check("tool_level_up_fiore", int(up.get("levels_gained", 0)) == 1 and PUWStylerSystem.styler_level(level_state) == 2)  # v2 SOURCED-R7: L2 stands at 100 total Exp
	_check("tool_level_up_energy_delta", PUWStylerSystem.current_energy(level_state) == 4)  # v2: 2 left + (L2 max 6 - L1 max 4) delta

	var gs_state: Dictionary = _fresh_state()
	_enter(gs_state, "oblivia")
	var gs: Dictionary = PUWStylerSystem.begin_capture(gs_state, _target("onix", ["rock", "ground"], {"friendship_required": 100000.0}))
	PUWStylerSystem.session_line_hit(gs_state, gs, 5)
	PUWStylerSystem.session_flee(gs_state, gs)
	PUWStylerSystem.award_styler_exp(gs_state, 3726)
	_check("tool_level_up_oblivia_full_restore", PUWStylerSystem.styler_level(gs_state) > 1 and PUWStylerSystem.current_energy(gs_state) == PUWStylerSystem.energy_max("oblivia", PUWStylerSystem.styler_level(gs_state)))  # v2: sourced 99-level table; full restore to the reached level's exact max


# ----------------------------------------------------------------
# Permadeath: structurally untouched, proven byte-for-byte
# ----------------------------------------------------------------

func _test_permadeath_isolation() -> void:
	var state: Dictionary = _fresh_state()
	# Create all three Ranger region records up front so the
	# projection's region set is stable across the session.
	_enter(state, "fiore")
	_enter(state, "almia")
	_enter(state, "oblivia")
	_enter(state, "kanto")
	var before: String = _projection(state)

	# A full Styler session across all three regions:
	# captures, assists, target clears, habitat releases,
	# partner roster work, points, upgrades, a reward GRANT
	# (pending only -- the claim is the one sanctioned write
	# and is tested separately above).
	_enter(state, "fiore")
	PUWStylerSystem.assign_fixed_partner(state, "male")
	PUWStylerSystem.complete_mission(state, {"id": "iso_fiore_mission", "grants_rank": true})
	_befriend_fiore(state, "rattata", ["normal"], {"field_moves": {"tackle": 2}})
	_befriend_fiore(state, "machop", ["fighting"], {"assist_type": "fighting", "field_moves": {"crush": 3}})
	var fs: Dictionary = PUWStylerSystem.begin_capture(state, _target("onix", ["rock", "ground"], {"loops_required": 99}))
	PUWStylerSystem.session_apply_friend_assist(state, fs, 1, 1.0)
	PUWStylerSystem.session_line_hit(state, fs, 3)
	PUWStylerSystem.session_flee(state, fs)
	PUWStylerSystem.friend_target_clear(state, {"move": "tackle", "tier": 2}, [0])
	_befriend_fiore(state, "caterpie", ["bug"], {})
	PUWStylerSystem.leave_habitat(state)

	_enter(state, "almia")
	PUWStylerSystem.unlock_partner(state, "pachirisu", "starter")
	PUWStylerSystem.unlock_partner(state, "turtwig", "quest")
	_befriend_gauge(state, "bidoof", ["normal"], {"field_moves": {"cut": 3}})
	_befriend_gauge(state, "starly", ["normal", "flying"], {})
	var as_: Dictionary = PUWStylerSystem.begin_capture(state, _target("luxio", ["electric"], {"friendship_required": 100000.0}))
	PUWStylerSystem.session_charge(state, as_, 2.0)
	PUWStylerSystem.session_loop(state, as_)
	PUWStylerSystem.session_apply_friend_assist(state, as_, 1, 1.0)
	PUWStylerSystem.session_flee(state, as_)
	PUWStylerSystem.friend_target_clear(state, {"move": "cut", "tier": 3}, [0])
	PUWStylerSystem.complete_mission(state, {"id": "iso_almia_mission", "grants_rank": true})
	PUWStylerSystem.grant_transfer_reward(state, "manaphy_egg")

	_enter(state, "oblivia")
	PUWStylerSystem.assign_fixed_partner(state)
	_befriend_gauge(state, "pidgey", ["normal", "flying"], {"assist_type": "grass", "field_moves": {"cut": 3}})
	var os_: Dictionary = PUWStylerSystem.begin_capture(state, _target("rattata", ["normal"], {"friendship_required": 100000.0}))
	PUWStylerSystem.session_set_agitated(os_, true)
	PUWStylerSystem.session_loop(state, os_)
	PUWStylerSystem.session_apply_friend_assist(state, os_, 0, 1.0)
	PUWStylerSystem.session_assistant_hit(state, os_)
	PUWStylerSystem.session_flee(state, os_)
	PUWStylerSystem.award_mission_clear_points(state, "iso_oblivia_points")
	PUWStylerSystem.award_past_points(state, 300)
	PUWStylerSystem.upgrade_past_partner(state, "power")
	PUWStylerSystem.complete_mission(state, {"id": "iso_oblivia_mission"})

	_enter(state, "kanto")
	var after: String = _projection(state)
	_check("permadeath_projection_byte_identical", before == after)
	_check("permadeath_no_faints_recorded", (state.get("fainting_ledger", []) as Array).size() == 1)
	_check("permadeath_lockouts_untouched", (state.get("locked_evo_families", {}) as Dictionary) == {"pidgey_family": true})


# ----------------------------------------------------------------
# Save round-trip through the real save manager
# ----------------------------------------------------------------

func _test_save_round_trip() -> void:
	var state: Dictionary = _fresh_state()
	_enter(state, "almia")
	PUWStylerSystem.complete_mission(state, {"id": "rt_1", "grants_rank": true})
	PUWStylerSystem.complete_mission(state, {"id": "rt_2", "grants_rank": true})
	_befriend_gauge(state, "bidoof", ["normal"], {})
	_enter(state, "oblivia")
	PUWStylerSystem.award_mission_clear_points(state, "rt_oblivia_mission")
	_enter(state, "kanto")
	_check("save_writes", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("save_loads", not loaded.is_empty())
	_check("save_almia_rank_survives", PUWStylerSystem.current_rank(loaded, "almia") == 3)
	_check("save_almia_friend_survives", PUWStylerSystem.friends(loaded, "almia").size() == 1)
	_check("save_oblivia_points_survive", PUWStylerSystem.points(loaded, "oblivia") == 50)  # v2 SOURCED-R7: one Mission Clear = 50 RP
	PUWSaveManager.delete_save()
