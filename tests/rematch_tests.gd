extends SceneTree
## Rematch system (Vs. Seeker) tests — code prep.
## Run with Godot 4.7.2 headless against test_project/, which
## holds COPIES of batch 5's item files (ItemEngine,
## PUWItemServices, PUWInventoryManager) plus this prep's
## PUWRematchSystem. All rolls are injected; no RNG is drawn.
## Fixture parties are transcribed from held pokefirered source
## (see rematch_fixture_frlg.json provenance).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const BEN: String = "youngster_ben_route3"
const CALVIN: String = "youngster_calvin_route3"

func _init() -> void:
	print("PUW rematch system tests — starting.")
	_run("test_eligibility_requires_defeat", Callable(self, "test_eligibility_requires_defeat"))
	_run("test_fixture_shape_and_tiers", Callable(self, "test_fixture_shape_and_tiers"))
	_run("test_charge_and_batch5_bridge", Callable(self, "test_charge_and_batch5_bridge"))
	_run("test_charge_requires_item_and_caps", Callable(self, "test_charge_requires_item_and_caps"))
	_run("test_use_refusals_keep_charge", Callable(self, "test_use_refusals_keep_charge"))
	_run("test_scan_willing_and_window", Callable(self, "test_scan_willing_and_window"))
	_run("test_scan_declined_consumes_charge", Callable(self, "test_scan_declined_consumes_charge"))
	_run("test_scan_refusal_reasons", Callable(self, "test_scan_refusal_reasons"))
	_run("test_duplicate_instance_refused", Callable(self, "test_duplicate_instance_refused"))
	_run("test_tier_progression_gates_frlg", Callable(self, "test_tier_progression_gates_frlg"))
	_run("test_tier_exhaustion_and_no_unique", Callable(self, "test_tier_exhaustion_and_no_unique"))
	_run("test_party_copy_isolation", Callable(self, "test_party_copy_isolation"))
	_run("test_window_expiry_clears_wants", Callable(self, "test_window_expiry_clears_wants"))
	_run("test_map_reset_clears_wants", Callable(self, "test_map_reset_clears_wants"))
	_run("test_begin_and_record_win_advances", Callable(self, "test_begin_and_record_win_advances"))
	_run("test_record_loss_does_not_advance", Callable(self, "test_record_loss_does_not_advance"))
	_run("test_permadeath_context_path", Callable(self, "test_permadeath_context_path"))
	_run("test_prize_money_seam", Callable(self, "test_prize_money_seam"))
	_run("test_dppt_profile_separate", Callable(self, "test_dppt_profile_separate"))
	_run("test_dppt_radius_and_levels", Callable(self, "test_dppt_radius_and_levels"))
	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("FAILED: ", _failed_names)
	quit(1 if _failed > 0 else 0)

func _run(name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_failed_names.append(name)
		print("FAIL: ", name)

func _tables() -> Dictionary:
	var ben_tiers: Array = [
		{"trainer_id": "youngster_ben", "party": [
			{"species": "rattata", "level": 11, "iv": 0},
			{"species": "ekans", "level": 11, "iv": 0}]},
		{"trainer_id": "youngster_ben_2", "party": [
			{"species": "rattata", "level": 17, "iv": 20},
			{"species": "ekans", "level": 17, "iv": 20}]},
		null,
		{"trainer_id": "youngster_ben_3", "party": [
			{"species": "raticate", "level": 28, "iv": 60},
			{"species": "ekans", "level": 28, "iv": 60}]},
		{"trainer_id": "youngster_ben_4", "party": [
			{"species": "raticate", "level": 48, "iv": 120},
			{"species": "arbok", "level": 48, "iv": 120}]},
	]
	var calvin_tiers: Array = [
		{"trainer_id": "youngster_calvin", "party": [
			{"species": "spearow", "level": 14, "iv": 0}]},
		{"trainer_id": "youngster_calvin", "party": [
			{"species": "spearow", "level": 14, "iv": 0}]},
	]
	return {BEN: {"region": "kanto", "tiers": ben_tiers},
		CALVIN: {"region": "kanto", "tiers": calvin_tiers}}

func _full_progression() -> Dictionary:
	return {"got_vs_seeker": true, "world_map_celadon": true,
		"world_map_fuchsia": true, "game_clear": true, "can_link_rs": true}

func _defeated_state(key: String) -> Dictionary:
	var state: Dictionary = {}
	PUWRematchSystem.record_battle_result(state, key, true, 0)
	return state

func _charge_full(state: Dictionary, profile_name: String = "frlg") -> void:
	for i in 100:
		PUWRematchSystem.on_step(state, true, profile_name)

func _near(key: String) -> Array:
	return [{"trainer_key": key, "visible": true, "dx": 0, "dy": 0}]

func test_eligibility_requires_defeat() -> bool:
	var state: Dictionary = {}
	var e1: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), _full_progression(), "frlg")
	if bool(e1["eligible"]) or str(e1["reason"]) != "not_defeated":
		return false
	var lost: Dictionary = {}
	PUWRematchSystem.record_battle_result(lost, BEN, false, 0)
	if PUWRematchSystem.is_defeated(lost, BEN):
		return false
	PUWRematchSystem.record_battle_result(state, BEN, true, 0)
	var e2: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), _full_progression(), "frlg")
	if not bool(e2["eligible"]) or int(e2["tier_index"]) != 1:
		return false
	var e3: Dictionary = PUWRematchSystem.eligibility(state, "nobody", _tables(), _full_progression(), "frlg")
	return not bool(e3["eligible"]) and str(e3["reason"]) == "not_defeated"

func test_fixture_shape_and_tiers() -> bool:
	var f: FileAccess = FileAccess.open("res://systems/rematch/rematch_fixture_frlg.json", FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	var trainers: Dictionary = data["trainers"]
	var ben: Dictionary = trainers[BEN]
	var tiers: Array = ben["tiers"]
	if tiers.size() != 5 or tiers[2] != null:
		return false
	var t1: Dictionary = tiers[1]
	var party: Array = t1["party"]
	var mon0: Dictionary = party[0]
	if str(mon0["species"]) != "rattata" or int(mon0["level"]) != 17 or int(mon0["iv"]) != 20:
		return false
	var t4: Dictionary = tiers[4]
	var party4: Array = t4["party"]
	var mon41: Dictionary = party4[1]
	return str(mon41["species"]) == "arbok" and int(mon41["level"]) == 48

func test_charge_and_batch5_bridge() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	for i in 99:
		PUWRematchSystem.on_step(state, true, "frlg")
	if PUWRematchSystem.is_charged(state, "frlg"):
		return false
	if PUWRematchSystem.steps_until_charged(state, "frlg") != 1:
		return false
	PUWRematchSystem.on_step(state, true, "frlg")
	if not PUWRematchSystem.is_charged(state, "frlg"):
		return false
	# Batch-5 core agreement: the flat state this system
	# maintains must give the same answer via vs_seeker_charge.
	var root: Dictionary = state["rematch"]
	var seeker: Dictionary = root["vs_seeker"]
	var flat: Dictionary = {"vs_seeker_last_use_step": int(seeker["vs_seeker_last_use_step"])}
	return PUWItemServices.vs_seeker_charge(flat, int(seeker["total_steps"]))

func test_charge_requires_item_and_caps() -> bool:
	var state: Dictionary = {}
	for i in 150:
		PUWRematchSystem.on_step(state, false, "frlg")
	if PUWRematchSystem.charge_amount(state) != 0:
		return false
	_charge_full(state)
	for i in 50:
		PUWRematchSystem.on_step(state, true, "frlg")
	return PUWRematchSystem.charge_amount(state) == 100

func test_use_refusals_keep_charge() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	var r1: Dictionary = PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0})
	if str(r1["reason"]) != "not_charged":
		return false
	_charge_full(state)
	var r2: Dictionary = PUWRematchSystem.use_vs_seeker(state, [], _tables(), _full_progression(), "frlg", {})
	if str(r2["reason"]) != "no_one_in_range":
		return false
	if not PUWRematchSystem.is_charged(state, "frlg"):
		return false
	var hidden: Array = [{"trainer_key": BEN, "visible": false, "dx": 0, "dy": 0}]
	var r3: Dictionary = PUWRematchSystem.use_vs_seeker(state, hidden, _tables(), _full_progression(), "frlg", {BEN: 0})
	if str(r3["reason"]) != "no_one_in_range":
		return false
	var r4: Dictionary = PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0}, false)
	if str(r4["reason"]) != "map_not_allowed":
		return false
	return PUWRematchSystem.is_charged(state, "frlg")

func test_scan_willing_and_window() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	var r: Dictionary = PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 69})
	if not bool(r["ok"]):
		return false
	var willing: Array = r["willing"]
	if willing.size() != 1 or str(willing[0]) != BEN:
		return false
	if PUWRematchSystem.charge_amount(state) != 0:
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	if not bool(rec["wants_rematch"]) or int(rec["active_tier"]) != 1:
		return false
	var root: Dictionary = state["rematch"]
	var seeker: Dictionary = root["vs_seeker"]
	return int(seeker["active_steps_left"]) == 100

func test_scan_declined_consumes_charge() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	# FRLG willingness is 70%: roll 70 is the first refusing draw.
	var r: Dictionary = PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 70})
	if bool(r["ok"]) or str(r["reason"]) != "no_trainers_picked":
		return false
	var refused: Dictionary = r["refused"]
	if str(refused.get(BEN, "")) != "declined_roll":
		return false
	if PUWRematchSystem.trainer_record(state, BEN).get("wants_rematch", false):
		return false
	return PUWRematchSystem.charge_amount(state) == 0

func test_scan_refusal_reasons() -> bool:
	var state: Dictionary = {}
	PUWRematchSystem.record_battle_result(state, BEN, true, 0)
	_charge_full(state)
	var mixed: Array = [
		{"trainer_key": BEN, "visible": true, "dx": 0, "dy": 0},
		{"trainer_key": CALVIN, "visible": true, "dx": 1, "dy": 0},
	]
	var r: Dictionary = PUWRematchSystem.use_vs_seeker(state, mixed, _tables(), _full_progression(), "frlg", {BEN: 0})
	var refused: Dictionary = r["refused"]
	if str(refused.get(CALVIN, "")) != "not_defeated":
		return false
	# No roll supplied for a valid candidate.
	var state2: Dictionary = _defeated_state(BEN)
	_charge_full(state2)
	var r2: Dictionary = PUWRematchSystem.use_vs_seeker(state2, _near(BEN), _tables(), _full_progression(), "frlg", {})
	var refused2: Dictionary = r2["refused"]
	if str(refused2.get(BEN, "")) != "no_roll_supplied":
		return false
	# Unfought-only area reports its own reason.
	var state3: Dictionary = {}
	_charge_full(state3)
	var r3: Dictionary = PUWRematchSystem.use_vs_seeker(state3, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0})
	return str(r3["reason"]) == "unfought_in_range"

func test_duplicate_instance_refused() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	var dup: Array = [
		{"trainer_key": BEN, "visible": true, "dx": 0, "dy": 0},
		{"trainer_key": BEN, "visible": true, "dx": 2, "dy": 0},
	]
	var r: Dictionary = PUWRematchSystem.use_vs_seeker(state, dup, _tables(), _full_progression(), "frlg", {BEN: 0})
	if not bool(r["ok"]):
		return false
	var refused: Dictionary = r["refused"]
	return str(refused.get(BEN, "")) == "duplicate_instance"

func test_tier_progression_gates_frlg() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	# No flags: tier 1 itself is gated by FLAG_GOT_VS_SEEKER.
	var e0: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), {}, "frlg")
	if bool(e0["eligible"]) or str(e0["reason"]) != "progression_locked":
		return false
	var p1: Dictionary = {"got_vs_seeker": true}
	var e1: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), p1, "frlg")
	if not bool(e1["eligible"]) or int(e1["tier_index"]) != 1:
		return false
	# Fight tier 1 (via record path), then tier 3 is next
	# (tier 2 is the SKIP hole) but Fuchsia gate is shut.
	var rec_state: Dictionary = state
	var t: Dictionary = {}
	var root: Dictionary = rec_state["rematch"]
	t = root["trainers"]
	var rec: Dictionary = t[BEN]
	rec["highest_tier_fought"] = 1
	t[BEN] = rec
	root["trainers"] = t
	rec_state["rematch"] = root
	var e2: Dictionary = PUWRematchSystem.eligibility(rec_state, BEN, _tables(), p1, "frlg")
	if bool(e2["eligible"]) or str(e2["reason"]) != "progression_locked" or int(e2["tier_index"]) != 3:
		return false
	var e3: Dictionary = PUWRematchSystem.eligibility(rec_state, BEN, _tables(), _full_progression(), "frlg")
	return bool(e3["eligible"]) and int(e3["tier_index"]) == 3

func test_tier_exhaustion_and_no_unique() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	var root: Dictionary = state["rematch"]
	var t: Dictionary = root["trainers"]
	var rec: Dictionary = t[BEN]
	rec["highest_tier_fought"] = 4
	t[BEN] = rec
	root["trainers"] = t
	state["rematch"] = root
	var e: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), _full_progression(), "frlg")
	if bool(e["eligible"]) or str(e["reason"]) != "no_next_tier":
		return false
	var cal: Dictionary = _defeated_state(CALVIN)
	var e2: Dictionary = PUWRematchSystem.eligibility(cal, CALVIN, _tables(), _full_progression(), "frlg")
	return not bool(e2["eligible"]) and str(e2["reason"]) == "no_next_tier"

func test_party_copy_isolation() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	var tables: Dictionary = _tables()
	var sel: Dictionary = PUWRematchSystem.select_rematch_party(state, BEN, tables, _full_progression(), "frlg")
	if not bool(sel["ok"]) or int(sel["tier_index"]) != 1:
		return false
	var party: Array = sel["party"]
	var mon0: Dictionary = party[0]
	mon0["level"] = 99
	var ben_entry: Dictionary = tables[BEN]
	var tiers: Array = ben_entry["tiers"]
	var t1: Dictionary = tiers[1]
	var src_party: Array = t1["party"]
	var src0: Dictionary = src_party[0]
	return int(src0["level"]) == 17

func test_window_expiry_clears_wants() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0})
	var expired_at: int = -1
	for i in 100:
		if PUWRematchSystem.on_step(state, true, "frlg"):
			expired_at = i
	if expired_at != 99:
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	if bool(rec["wants_rematch"]) or int(rec["active_tier"]) != -1:
		return false
	var begin: Dictionary = PUWRematchSystem.begin_rematch(state, BEN, _tables(), _full_progression(), "frlg")
	return not bool(begin["ok"]) and str(begin["reason"]) == "not_willing"

func test_map_reset_clears_wants() -> bool:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0})
	PUWRematchSystem.on_map_reset(state)
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	return not bool(rec["wants_rematch"]) and int(rec["active_tier"]) == -1

func _willing_state() -> Dictionary:
	var state: Dictionary = _defeated_state(BEN)
	_charge_full(state)
	PUWRematchSystem.use_vs_seeker(state, _near(BEN), _tables(), _full_progression(), "frlg", {BEN: 0})
	return state

func test_begin_and_record_win_advances() -> bool:
	var state: Dictionary = _willing_state()
	var begin: Dictionary = PUWRematchSystem.begin_rematch(state, BEN, _tables(), _full_progression(), "frlg")
	if not bool(begin["ok"]) or int(begin["tier_index"]) != 1:
		return false
	var ctx: Dictionary = begin["context"]
	var res: Dictionary = PUWRematchSystem.record_rematch_result(state, BEN, true, 500, ctx)
	if not bool(res["ok"]):
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	if int(rec["highest_tier_fought"]) != 1 or int(rec["rematches_won"]) != 1:
		return false
	if bool(rec["wants_rematch"]):
		return false
	var last: Dictionary = rec["last_rematch"]
	return str(last["result"]) == "won" and int(last["tier"]) == 1 and int(last["step"]) == 500

func test_record_loss_does_not_advance() -> bool:
	var state: Dictionary = _willing_state()
	var begin: Dictionary = PUWRematchSystem.begin_rematch(state, BEN, _tables(), _full_progression(), "frlg")
	var ctx: Dictionary = begin["context"]
	var res: Dictionary = PUWRematchSystem.record_rematch_result(state, BEN, false, 500, ctx)
	if not bool(res["ok"]):
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	if int(rec["highest_tier_fought"]) != 0 or int(rec["rematches_lost"]) != 1:
		return false
	var e: Dictionary = PUWRematchSystem.eligibility(state, BEN, _tables(), _full_progression(), "frlg")
	return bool(e["eligible"]) and int(e["tier_index"]) == 1

func test_permadeath_context_path() -> bool:
	var ctx: Dictionary = PUWRematchSystem.battle_context(BEN, 1)
	if bool(ctx["simulation"]) or not bool(ctx["permadeath_applies"]):
		return false
	if bool(ctx["grants_progression"]) or bool(ctx["region_lock_bypass"]):
		return false
	if str(ctx["battle_kind"]) != "rematch":
		return false
	# A simulation-flavoured result is refused and changes nothing.
	var state: Dictionary = _willing_state()
	var sim_ctx: Dictionary = {"simulation": true, "battle_kind": "rematch"}
	var res: Dictionary = PUWRematchSystem.record_rematch_result(state, BEN, true, 500, sim_ctx)
	if bool(res["ok"]) or str(res["reason"]) != "simulation_context_refused":
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, BEN)
	if not bool(rec["wants_rematch"]) or int(rec.get("rematches_won", 0)) != 0:
		return false
	# A non-rematch context is refused too.
	var res2: Dictionary = PUWRematchSystem.record_rematch_result(state, BEN, true, 500, {"simulation": false, "battle_kind": "vexa"})
	return not bool(res2["ok"]) and str(res2["reason"]) == "not_a_rematch_context"

func test_prize_money_seam() -> bool:
	var tier: Dictionary = {"trainer_id": "x", "prize_base": 100, "party": []}
	var plain: Array = [{"species": "pikachu", "item": "", "participated": true}]
	if PUWRematchSystem.prize_money(plain, tier) != 100:
		return false
	var amulet: Array = [{"species": "pikachu", "item": "Amulet Coin", "participated": true}]
	if PUWRematchSystem.prize_money(amulet, tier) != 200:
		return false
	var sat_out: Array = [{"species": "pikachu", "item": "Amulet Coin", "participated": false}]
	if PUWRematchSystem.prize_money(sat_out, tier) != 100:
		return false
	# Roto Prize Money (batch-5 framework) composes on top.
	var roto_state: Dictionary = {}
	PUWItemServices.roto_activate(roto_state, "roto-prize-money", 3, 100)
	if PUWRematchSystem.prize_money(amulet, tier, roto_state) != 400:
		return false
	# No prize_base in the tier data => no money invented.
	var no_base: Dictionary = {"trainer_id": "youngster_ben_2", "party": []}
	return PUWRematchSystem.prize_money(amulet, no_base) == 0

func test_dppt_profile_separate() -> bool:
	var frlg: Dictionary = PUWRematchSystem.profile("frlg")
	var dppt: Dictionary = PUWRematchSystem.profile("dppt")
	if int(frlg["willing_chance"]) != 70 or int(dppt["willing_chance"]) != 50:
		return false
	if int(dppt["charge_max"]) != 100 or int(dppt["active_steps"]) != 100:
		return false
	# DPPt willingness boundary: roll 49 accepts, roll 50 refuses.
	var prog: Dictionary = {"unlocked_vs_seeker_lvl_1": true}
	var s1: Dictionary = _defeated_state(BEN)
	_charge_full(s1, "dppt")
	var near_r: Array = [{"trainer_key": BEN, "visible": false, "dx": 3, "dy": -2}]
	var r1: Dictionary = PUWRematchSystem.use_vs_seeker(s1, near_r, _tables(), prog, "dppt", {BEN: 49})
	if not bool(r1["ok"]):
		return false
	var s2: Dictionary = _defeated_state(BEN)
	_charge_full(s2, "dppt")
	var r2: Dictionary = PUWRematchSystem.use_vs_seeker(s2, near_r, _tables(), prog, "dppt", {BEN: 50})
	return not bool(r2["ok"]) and str(r2["reason"]) == "no_trainers_picked"

func test_dppt_radius_and_levels() -> bool:
	var prog: Dictionary = {"unlocked_vs_seeker_lvl_1": true}
	# Down radius is 6 in Platinum: dy +7 is out of range.
	var s1: Dictionary = _defeated_state(BEN)
	_charge_full(s1, "dppt")
	var far: Array = [{"trainer_key": BEN, "visible": false, "dx": 0, "dy": 7}]
	var r1: Dictionary = PUWRematchSystem.use_vs_seeker(s1, far, _tables(), prog, "dppt", {BEN: 0})
	if str(r1["reason"]) != "no_one_in_range":
		return false
	# No unlocked level flags: tier 1 is progression-locked.
	var s2: Dictionary = _defeated_state(BEN)
	var e: Dictionary = PUWRematchSystem.eligibility(s2, BEN, _tables(), {}, "dppt")
	if bool(e["eligible"]) or str(e["reason"]) != "progression_locked":
		return false
	# Level cap from the highest flag: L3 set (L2 unset) still caps at 3.
	var prog3: Dictionary = {"unlocked_vs_seeker_lvl_3": true}
	return PUWRematchSystem.tier_cap("dppt", prog3) == 3
