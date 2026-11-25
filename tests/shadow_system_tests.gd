extends SceneTree
## Shadow / snag / purification tests (Orre code prep,
## 2026-11-23). Run: godot --headless --script res://tests/shadow_system_tests.gd
##
## Covers ORRE_BUILD_PREP.md SS4.6's required list, against
## COPIES of the real systems the prep integrates with
## (BattleController with the snag patch, PUWFollowerCare with
## the care-routing patch, PUWSaveManager, PUWRegionState,
## PartyAndStorageManager, PUWCombatConsequences, MartShop):
## - the generated register index (131 records, XD001, the
##   Voltorb recovery exception);
## - stamping + the four mon fields + five-stage derivation;
## - the snag legality matrix, at the system level AND through
##   the patched battle capture path (incl. _perform_action
##   routing and unchanged wild capture);
## - gauge flow through the REAL follower-care calls (talk /
##   groom / treat), the battle path, and the walking path;
## - stage-gated normal-move unlocking (data-shaped seam);
## - purification: Relic Stone gate, Time Flute, provenance
##   permanence;
## - the Purify Chamber: set placement refusals, tempo from
##   the real type chart, chamber purification, and XD001's
##   chamber-only rule (refused at the Relic Stone, refused by
##   Time Flute, refused in the chamber until all nine
##   chambers stand at maximum tempo);
## - the missed-snag ledger and the Miror B. recovery pool,
##   incl. the Voltorb exception;
## - permadeath interaction: Orre story context applies,
##   simulation does not, and a permanently fainted snagged
##   mon's record closes forever;
## - save round-trip of all four fields through the real
##   PUWSaveManager, and region-lock pool carriage through
##   the real PUWRegionState;
## - non-Orre snapshot discipline: build_state gains no shadow
##   keys and a fresh BattleController carries no snag state.

var _passed: int = 0
var _failed: int = 0

const KEY_MAKUHITA: String = "orre:colosseum:phenac_city:makuhita:Miror B. Peon Trudly"
const KEY_XD001: String = "orre:xd:citadark_isle:lugia:Grand Master Greevil (Cipher Boss Greevil)"
const KEY_VOLTORB: String = "orre:xd:cave_poke_spot:voltorb:Wanderer Miror B."


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


func _mon(slug: String, species: String) -> Dictionary:
	return {
		"mon_id": "puw-000001-abc123",
		"slug": slug,
		"species": species,
		"name": species,
		"level": 30,
		"hp": 50,
		"max_hp": 60,
		"friendship": 50,
		"catch_rate": 255,
		"types": ["fighting"],
		"evo_family": slug,
		"moves": ["Tackle", "Growl", "Leer", "Focus Energy"],
	}


func _shadow_mon(slug: String, species: String, origin_key: String) -> Dictionary:
	var mon: Dictionary = _mon(slug, species)
	PUWShadowSystem.stamp_shadow(mon, origin_key)
	return mon


func _load_index() -> Array:
	var text: String = FileAccess.get_file_as_string("res://data/shadow_register_index.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var records_value: Variant = data.get("records", [])
		if records_value is Array:
			var records: Array = records_value
			return records
	return []


func _record_for(records: Array, origin_key: String) -> Dictionary:
	for record_value in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("origin_key", "")) == origin_key:
				return record
	return {}


func _first_record(records: Array, game: String, recovery: String, skip_key: String = "") -> Dictionary:
	for record_value in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("game", "")) == game and str(record.get("recovery", "")) == recovery and str(record.get("origin_key", "")) != skip_key:
				return record
	return {}


func _test_index() -> void:
	var records: Array = _load_index()
	_check("index loads with 131 records", records.size() == 131, str(records.size()))
	var colo: int = 0
	var xd: int = 0
	var xd001: int = 0
	var no_recovery: int = 0
	var keys: Dictionary = {}
	for record_value in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("game", "")) == "colosseum":
				colo += 1
			if str(record.get("game", "")) == "xd":
				xd += 1
			if bool(record.get("is_xd001", false)):
				xd001 += 1
			if str(record.get("recovery", "")) == "none":
				no_recovery += 1
			keys[str(record.get("origin_key", ""))] = true
	_check("index split is Colosseum 48 / XD 83", colo == 48 and xd == 83, "%d/%d" % [colo, xd])
	_check("index has exactly one XD001 record", xd001 == 1)
	_check("index origin keys are unique", keys.size() == 131)
	_check("exactly two records carry no recovery pool (Voltorb + XD001)", no_recovery == 2)
	var voltorb: Dictionary = _record_for(records, KEY_VOLTORB)
	_check("the XD Voltorb record is the sourced recovery exception", not voltorb.is_empty() and str(voltorb.get("recovery", "")) == "none" and int(voltorb.get("level", 0)) == 19)
	var lugia: Dictionary = _record_for(records, KEY_XD001)
	_check("XD001 record is the SHADOW_LUGIA_XD001 form record", not lugia.is_empty() and str(lugia.get("form_code", "")) == "SHADOW_LUGIA_XD001" and int(lugia.get("level", 0)) == 50)
	var makuhita: Dictionary = _record_for(records, KEY_MAKUHITA)
	_check("ordinary records are the treatment class", not makuhita.is_empty() and str(makuhita.get("form_code", "")) == "SHADOW_TREATMENT_CLASS" and str(makuhita.get("recovery", "")) == "lab_hideout")


func _test_stamp_and_stages() -> void:
	var mon: Dictionary = _mon("makuhita", "Makuhita")
	_check("un-stamped mon is not shadow", not PUWShadowSystem.is_shadow(mon) and PUWShadowSystem.shadow_state_of(mon) == "")
	var stamped: Dictionary = PUWShadowSystem.stamp_shadow(mon, KEY_MAKUHITA)
	_check("stamp succeeds", bool(stamped.get("ok", false)))
	_check("stamp writes shadow_state", PUWShadowSystem.shadow_state_of(mon) == "shadow")
	_check("stamp writes the default gauge full", PUWShadowSystem.heart_gauge_of(mon) == PUWShadowSystem.DEFAULT_HEART_GAUGE_MAX and PUWShadowSystem.heart_gauge_max_of(mon) == PUWShadowSystem.DEFAULT_HEART_GAUGE_MAX)
	_check("stamp writes stage 0 and origin, formerly false", PUWShadowSystem.heart_stage_of(mon) == 0 and PUWShadowSystem.shadow_origin_of(mon) == KEY_MAKUHITA and not PUWShadowSystem.was_shadow(mon))
	_check("the G1 UUID rides untouched alongside", str(mon.get("mon_id", "")) == "puw-000001-abc123")
	var again: Dictionary = PUWShadowSystem.stamp_shadow(mon, KEY_MAKUHITA)
	_check("re-stamping a shadow mon refuses", not bool(again.get("ok", true)) and str(again.get("reason", "")) == "already_shadow")
	var custom: Dictionary = _mon("teddiursa", "Teddiursa")
	PUWShadowSystem.stamp_shadow(custom, KEY_MAKUHITA, 250)
	_check("an explicit per-individual gauge max is honored", PUWShadowSystem.heart_gauge_max_of(custom) == 250 and PUWShadowSystem.heart_gauge_of(custom) == 250)
	_check("stage derivation: full gauge is stage 0", PUWShadowSystem.heart_stage_for(100, 100) == 0)
	_check("stage derivation: each emptied fifth advances one stage", PUWShadowSystem.heart_stage_for(80, 100) == 1 and PUWShadowSystem.heart_stage_for(60, 100) == 2 and PUWShadowSystem.heart_stage_for(40, 100) == 3 and PUWShadowSystem.heart_stage_for(20, 100) == 4)
	_check("stage derivation: empty gauge is stage 5", PUWShadowSystem.heart_stage_for(0, 100) == 5)
	_check("stage derivation: a sliver left is still stage 4", PUWShadowSystem.heart_stage_for(1, 100) == 4)


func _test_snag_legality() -> void:
	var shadow: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	var plain: Dictionary = _mon("zigzagoon", "Zigzagoon")
	var purified: Dictionary = _shadow_mon("teddiursa", "Teddiursa", KEY_MAKUHITA)
	purified["heart_gauge"] = 0
	PUWShadowSystem.purify_at_relic_stone(purified)
	_check("matrix: shadow + machine is legal", PUWShadowSystem.snag_refusal(shadow, true) == "" and PUWShadowSystem.snag_legal(shadow, true))
	_check("matrix: shadow without machine refuses no_machine", PUWShadowSystem.snag_refusal(shadow, false) == "no_machine")
	_check("matrix: non-shadow with machine refuses not_shadow", PUWShadowSystem.snag_refusal(plain, true) == "not_shadow")
	_check("matrix: non-shadow without machine still refuses not_shadow (target checked first)", PUWShadowSystem.snag_refusal(plain, false) == "not_shadow")
	_check("matrix: a purified mon is not snaggable", PUWShadowSystem.snag_refusal(purified, true) == "not_shadow")


func _test_battle_patch() -> void:
	var bc: BattleController = BattleController.new()
	bc.is_wild = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var target: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	target["hp"] = 1
	target["max_hp"] = 10
	var no_machine: Dictionary = bc.attempt_snag("master-ball", target, rng)
	_check("battle patch: no machine stamp refuses the snag", not bool(no_machine.get("caught", true)) and str(no_machine.get("refused", "")) == "no_machine")
	bc.battle_state["snag_machine_held"] = true
	bc.battle_state["snag_arc"] = "xd"
	var plain: Dictionary = _mon("zigzagoon", "Zigzagoon")
	plain["hp"] = 1
	plain["max_hp"] = 10
	var not_shadow: Dictionary = bc.attempt_snag("master-ball", plain, rng)
	_check("battle patch: non-shadow target refuses not_shadow", not bool(not_shadow.get("caught", true)) and str(not_shadow.get("refused", "")) == "not_shadow")
	var chance_probe: Dictionary = bc.attempt_snag("poke-ball", target, rng)
	_check("battle patch: snag chance reuses the species' normal catch-rate math", absf(float(chance_probe.get("chance", 0.0)) - 0.9333) < 0.01, str(chance_probe.get("chance", 0.0)))
	var caught: Dictionary = bc.attempt_snag("master-ball", target, rng)
	_check("battle patch: a legal master-ball snag catches", bool(caught.get("caught", false)) and bool(caught.get("snag", false)))
	_check("battle patch: the snag result carries the target dict", (caught.get("target", {}) as Dictionary).get("slug", "") == "makuhita")
	_check("battle patch: is_wild is restored after the throw", not bc.is_wild)
	# Routing through _perform_action: an Orre arc ball throw at
	# the foe becomes a capture result; without the arc stamp a
	# ball in a trainer battle does not.
	var bc2: BattleController = BattleController.new()
	bc2.is_wild = false
	bc2.player_party = [_mon("espeon", "Espeon")]
	var foe: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	foe["hp"] = 1
	foe["max_hp"] = 10
	bc2.enemy_party = [foe]
	bc2.battle_state["snag_machine_held"] = true
	bc2.battle_state["snag_arc"] = "colosseum"
	var logs: Array = []
	var routed: Dictionary = bc2._perform_action({"type": "item", "item_id": "master-ball"}, true, logs)
	_check("battle patch: _perform_action routes an arc ball throw to the snag", routed.has("capture") and bool((routed.get("capture", {}) as Dictionary).get("snag", false)) and bool((routed.get("capture", {}) as Dictionary).get("caught", false)))
	var bc3: BattleController = BattleController.new()
	bc3.is_wild = false
	bc3.player_party = [_mon("espeon", "Espeon")]
	bc3.enemy_party = [_shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)]
	var logs3: Array = []
	var unrouted: Dictionary = bc3._perform_action({"type": "item", "item_id": "master-ball"}, true, logs3)
	_check("battle patch: without the arc stamp a trainer-battle ball is not a capture", not unrouted.has("capture"))
	# Wild capture is unchanged by the patch.
	var bc4: BattleController = BattleController.new()
	bc4.is_wild = true
	var wild_mon: Dictionary = _mon("pidgey", "Pidgey")
	wild_mon["hp"] = 1
	wild_mon["max_hp"] = 10
	var wild: Dictionary = bc4.attempt_capture("master-ball", wild_mon, rng)
	_check("battle patch: wild capture still works exactly as before", bool(wild.get("caught", false)) and not wild.has("snag"))
	bc.free()
	bc2.free()
	bc3.free()
	bc4.free()


func _test_care_routing() -> void:
	var care: PUWFollowerCare = PUWFollowerCare.new()
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	var talked: Dictionary = care.talk(mon, 1000.0)
	_check("care: talk on a shadow follower succeeds", bool(talked.get("ok", false)))
	_check("care: talk routes +2 into the heart gauge", PUWShadowSystem.heart_gauge_of(mon) == 98, str(PUWShadowSystem.heart_gauge_of(mon)))
	_check("care: talk leaves shadow friendship untouched", int(mon.get("friendship", 0)) == 50)
	_check("care: the reported gain is the gauge reduction", int(talked.get("gain", 0)) == 2)
	var groomed: Dictionary = care.groom(mon, 1000.0)
	_check("care: groom routes +3 into the heart gauge", bool(groomed.get("ok", false)) and PUWShadowSystem.heart_gauge_of(mon) == 95)
	var shop: MartShop = MartShop.new()
	shop.bag["oran-berry"] = 1
	var treated: Dictionary = care.treat(mon, shop, "oran-berry")
	_check("care: treat routes +5 into the heart gauge and consumes the berry", bool(treated.get("ok", false)) and PUWShadowSystem.heart_gauge_of(mon) == 90 and int(shop.bag.get("oran-berry", 0)) == 0)
	var plain: Dictionary = _mon("pidgey", "Pidgey")
	care.talk(plain, 1000.0)
	_check("care: a non-shadow mon still gains friendship and grows no gauge fields", int(plain.get("friendship", 0)) == 52 and not plain.has("heart_gauge"))
	mon["heart_gauge"] = 0
	PUWShadowSystem.purify_at_relic_stone(mon)
	care.talk(mon, 5000.0)
	_check("care: after purification the same call routes to friendship again", int(mon.get("friendship", 0)) == 52)
	care.free()
	shop.free()


func _test_battle_and_walk_paths() -> void:
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	PUWShadowSystem.apply_battle_participation(mon)
	_check("battle path: one participated battle opens the gauge by the design constant", PUWShadowSystem.heart_gauge_of(mon) == 100 - PUWShadowSystem.BATTLE_PARTICIPATION_POINTS)
	var walked: Dictionary = PUWShadowSystem.apply_walk_steps(mon, 250)
	_check("walk path: 250 steps open 2 points", int(walked.get("applied", 0)) == 2 and PUWShadowSystem.heart_gauge_of(mon) == 88)
	var walked2: Dictionary = PUWShadowSystem.apply_walk_steps(mon, 50)
	_check("walk path: the step remainder carries across calls", int(walked2.get("applied", 0)) == 1 and PUWShadowSystem.heart_gauge_of(mon) == 87)
	var plain: Dictionary = _mon("pidgey", "Pidgey")
	_check("gauge paths refuse non-shadow mons", not bool(PUWShadowSystem.apply_battle_participation(plain).get("ok", true)) and not bool(PUWShadowSystem.apply_walk_steps(plain, 500).get("ok", true)) and not bool(PUWShadowSystem.apply_gauge_points(plain, 10).get("ok", true)))
	var floor_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	PUWShadowSystem.apply_gauge_points(floor_mon, 9999)
	_check("gauge never drops below zero and reports ready", PUWShadowSystem.heart_gauge_of(floor_mon) == 0 and PUWShadowSystem.ready_to_purify(floor_mon))


func _test_move_unlock() -> void:
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	mon["shadow_moves"] = ["shadow-move-fixture"]
	var normals: Array = ["Tackle", "Growl", "Leer", "Focus Energy"]
	var at_full: Dictionary = PUWShadowSystem.active_move_set(mon, normals)
	_check("moves: at stage 0 only the staged shadow moves are active", int(at_full.get("unlocked_normal", -1)) == 0 and (at_full.get("moves", []) as Array).size() == 1)
	PUWShadowSystem.apply_gauge_points(mon, 40)
	var at_stage2: Dictionary = PUWShadowSystem.active_move_set(mon, normals)
	_check("moves: stage 2 unlocks two normal moves in order", int(at_stage2.get("unlocked_normal", -1)) == 2 and (at_stage2.get("moves", []) as Array) == ["shadow-move-fixture", "Tackle", "Growl"])
	PUWShadowSystem.apply_gauge_points(mon, 60)
	PUWShadowSystem.purify_at_relic_stone(mon)
	var after: Dictionary = PUWShadowSystem.active_move_set(mon, normals)
	_check("moves: purification completes the normal set", int(after.get("unlocked_normal", -1)) == 4 and int(after.get("shadow_moves", -1)) == 0)


func _test_purification_paths() -> void:
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	var early: Dictionary = PUWShadowSystem.purify_at_relic_stone(mon)
	_check("relic stone: a non-empty gauge refuses", not bool(early.get("ok", true)) and str(early.get("reason", "")) == "gauge_not_empty")
	PUWShadowSystem.apply_gauge_points(mon, 100)
	var done: Dictionary = PUWShadowSystem.purify_at_relic_stone(mon)
	_check("relic stone: an empty gauge purifies", bool(done.get("ok", false)) and PUWShadowSystem.is_purified(mon))
	_check("purification sets formerly_shadow permanently", PUWShadowSystem.was_shadow(mon))
	_check("purification EXP bonus is honestly unstaged, never faked", int(done.get("exp_bonus", 0)) == -1 and str(done.get("exp_bonus_status", "")) == "not_staged_gap_d7")
	var restamp: Dictionary = PUWShadowSystem.stamp_shadow(mon, KEY_MAKUHITA)
	_check("a purified mon can never be re-stamped shadow", not bool(restamp.get("ok", true)) and str(restamp.get("reason", "")) == "already_purified")
	_check("gauge writes after purification refuse and provenance survives", not bool(PUWShadowSystem.apply_gauge_points(mon, 10).get("ok", true)) and PUWShadowSystem.was_shadow(mon))
	_check("aura drops at purification; the mark is data, not a visual", not PUWShadowSystem.aura_visible(mon) and PUWShadowSystem.was_shadow(mon))
	var flute_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	var bag: Dictionary = {}
	var no_flute: Dictionary = PUWShadowSystem.purify_with_time_flute(flute_mon, bag)
	_check("time flute: without a flute it refuses and changes nothing", not bool(no_flute.get("ok", true)) and str(no_flute.get("reason", "")) == "no_flute" and PUWShadowSystem.heart_gauge_of(flute_mon) == 100)
	bag["time-flute"] = 1
	var fluted: Dictionary = PUWShadowSystem.purify_with_time_flute(flute_mon, bag)
	_check("time flute: one flute purifies instantly past a full gauge and is consumed", bool(fluted.get("ok", false)) and PUWShadowSystem.is_purified(flute_mon) and not bag.has("time-flute"))
	var shadow2: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	_check("aura treatment is visible while shadow", PUWShadowSystem.aura_visible(shadow2))
	_check("the aura marker is story-gated", not PUWShadowSystem.marker_visible(shadow2, false) and PUWShadowSystem.marker_visible(shadow2, true))


func _max_tempo_set(shadow_mon: Dictionary) -> Array:
	shadow_mon["types"] = ["water"]
	return [shadow_mon, {"name": "Net A", "types": ["fire"]}, {"name": "Net B", "types": ["grass"]}]


func _test_chamber() -> void:
	var state: Dictionary = {}
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	_check("chamber: an empty set refuses", not bool(PUWPurifyChamber.place_set(state, 0, []).get("ok", true)))
	_check("chamber: a set with no shadow mon refuses", not bool(PUWPurifyChamber.place_set(state, 0, [{"name": "A", "types": ["fire"]}]).get("ok", true)))
	_check("chamber: a set with two shadow mons refuses", not bool(PUWPurifyChamber.place_set(state, 0, [mon, _shadow_mon("teddiursa", "Teddiursa", KEY_MAKUHITA)]).get("ok", true)))
	_check("chamber: an oversized set refuses", not bool(PUWPurifyChamber.place_set(state, 0, [mon, {}, {}, {}, {}]).get("ok", true)))
	_check("chamber: a bad chamber index refuses", not bool(PUWPurifyChamber.place_set(state, 9, [mon]).get("ok", true)))
	var placed: Dictionary = PUWPurifyChamber.place_set(state, 0, _max_tempo_set(mon))
	_check("chamber: a flowing circle places at maximum tempo", bool(placed.get("ok", false)) and int(placed.get("tempo", -1)) == PUWPurifyChamber.TEMPO_MAX)
	var dull_state: Dictionary = {}
	var dull_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	dull_mon["types"] = ["normal"]
	PUWPurifyChamber.place_set(dull_state, 0, [dull_mon, {"name": "A", "types": ["normal"]}, {"name": "B", "types": ["normal"]}])
	_check("chamber: a circle with no super-effective pair has tempo 0", PUWPurifyChamber.tempo_of(dull_state, 0) == 0)
	_check("chamber: all-max is false while any chamber stands empty", not PUWPurifyChamber.all_chambers_max_tempo(state))
	# Chamber purification of an ordinary mon.
	var tick_state: Dictionary = {}
	var tick_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	tick_mon["heart_gauge"] = 10
	PUWShadowSystem._sync_stage(tick_mon)
	PUWPurifyChamber.place_set(tick_state, 0, _max_tempo_set(tick_mon))
	var events: Array = PUWPurifyChamber.chamber_tick(tick_state, 1)
	_check("chamber: a tick at max tempo empties a 10-point gauge and purifies", events.size() == 1 and PUWShadowSystem.is_purified(tick_mon) and PUWShadowSystem.was_shadow(tick_mon))


func _test_xd001() -> void:
	var lugia: Dictionary = _mon("lugia", "Lugia")
	lugia["types"] = ["psychic", "flying"]
	PUWShadowSystem.stamp_shadow(lugia, KEY_XD001)
	_check("xd001: the XD Lugia individual is recognized from its origin key", PUWShadowSystem.is_xd001(lugia))
	var other: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	_check("xd001: ordinary shadow mons are not XD001", not PUWShadowSystem.is_xd001(other))
	lugia["heart_gauge"] = 0
	PUWShadowSystem._sync_stage(lugia)
	var relic: Dictionary = PUWShadowSystem.purify_at_relic_stone(lugia)
	_check("xd001: the Relic Stone refuses it even at an empty gauge", not bool(relic.get("ok", true)) and str(relic.get("reason", "")) == "xd001_chamber_only")
	var bag: Dictionary = {"time-flute": 1}
	var flute: Dictionary = PUWShadowSystem.purify_with_time_flute(lugia, bag)
	_check("xd001: a Time Flute refuses it and is not consumed", not bool(flute.get("ok", true)) and str(flute.get("reason", "")) == "xd001_chamber_only" and int(bag.get("time-flute", 0)) == 1)
	# Chamber path: all nine chambers at maximum tempo.
	var state: Dictionary = {}
	PUWShadowSystem.stamp_shadow(lugia, KEY_XD001) # no-op safeguard: still shadow
	lugia["heart_gauge"] = PUWShadowSystem.DEFAULT_HEART_GAUGE_MAX
	PUWShadowSystem._sync_stage(lugia)
	PUWPurifyChamber.place_set(state, 0, _max_tempo_set(lugia))
	for i in range(1, PUWPurifyChamber.CHAMBER_COUNT):
		var filler: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
		PUWPurifyChamber.place_set(state, i, _max_tempo_set(filler))
	var early: Dictionary = PUWPurifyChamber.try_purify_xd001(state, lugia)
	_check("xd001: max tempo everywhere still refuses while its gauge is full", not bool(early.get("ok", true)) and str(early.get("reason", "")) == "gauge_not_empty")
	var events: Array = PUWPurifyChamber.chamber_tick(state, 5)
	_check("xd001: chamber ticks empty its gauge without auto-purifying it", PUWShadowSystem.heart_gauge_of(lugia) == 0 and PUWShadowSystem.is_shadow(lugia))
	_check("xd001: the same ticks purified the ordinary chamber mons", events.size() == 8, str(events.size()))
	var done: Dictionary = PUWPurifyChamber.try_purify_xd001(state, lugia)
	_check("xd001: all nine at max tempo + empty gauge purifies it, provenance kept", bool(done.get("ok", false)) and PUWShadowSystem.is_purified(lugia) and PUWShadowSystem.was_shadow(lugia))
	# And the negative: one chamber below max blocks it.
	var state2: Dictionary = {}
	var lugia2: Dictionary = _mon("lugia", "Lugia")
	PUWShadowSystem.stamp_shadow(lugia2, KEY_XD001)
	lugia2["heart_gauge"] = 0
	PUWShadowSystem._sync_stage(lugia2)
	PUWPurifyChamber.place_set(state2, 0, _max_tempo_set(lugia2))
	for i in range(1, PUWPurifyChamber.CHAMBER_COUNT):
		var filler2: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
		PUWPurifyChamber.place_set(state2, i, _max_tempo_set(filler2))
	PUWPurifyChamber.clear_set(state2, 8)
	var blocked: Dictionary = PUWPurifyChamber.try_purify_xd001(state2, lugia2)
	_check("xd001: one chamber below maximum blocks the purification", not bool(blocked.get("ok", true)) and str(blocked.get("reason", "")) == "chambers_not_max_tempo" and PUWShadowSystem.is_shadow(lugia2))


func _test_ledger_and_recovery() -> void:
	var records: Array = _load_index()
	var state: Dictionary = {}
	var xd_record: Dictionary = _first_record(records, "xd", "miror_b")
	var xd_key: String = str(xd_record.get("origin_key", ""))
	var colo_record: Dictionary = _first_record(records, "colosseum", "lab_hideout")
	var colo_key: String = str(colo_record.get("origin_key", ""))
	PUWShadowSystem.record_missed(state, xd_key)
	PUWShadowSystem.record_missed(state, colo_key)
	PUWShadowSystem.record_missed(state, KEY_VOLTORB)
	PUWShadowSystem.record_missed(state, KEY_XD001)
	var pool: Array = PUWShadowSystem.recovery_pool(state, records)
	var pool_keys: Dictionary = {}
	for entry_value in pool:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			pool_keys[str(entry.get("origin_key", ""))] = str(entry.get("pool", ""))
	_check("recovery: a missed XD mon re-offers with Miror B.", pool_keys.has(xd_key) and str(pool_keys.get(xd_key, "")) == "miror_b")
	_check("recovery: Miror B. venues are the sourced colosseums and Poke Spots", (xd_record.get("recovery_venues", []) as Array).has("pyrite_colosseum") and (xd_record.get("recovery_venues", []) as Array).has("realgam_colosseum"))
	_check("recovery: a missed Colosseum mon re-offers at the Lab / Hideout", pool_keys.has(colo_key) and str(pool_keys.get(colo_key, "")) == "lab_hideout")
	_check("recovery: the Voltorb exception -- marked missed, never in the pool", not pool_keys.has(KEY_VOLTORB))
	_check("recovery: XD001 never enters the Miror B. pool", not pool_keys.has(KEY_XD001))
	PUWShadowSystem.record_snag(state, xd_key)
	var pool2: Array = PUWShadowSystem.recovery_pool(state, records)
	var still_there: bool = false
	for entry_value in pool2:
		if entry_value is Dictionary:
			var entry2: Dictionary = entry_value
			if str(entry2.get("origin_key", "")) == xd_key:
				still_there = true
	_check("recovery: a snagged record never re-offers", not still_there and PUWShadowSystem.record_closed(state, xd_key))
	PUWShadowSystem.record_missed(state, xd_key)
	_check("recovery: a snagged record cannot be re-marked missed", PUWShadowSystem.record_closed(state, xd_key) and PUWShadowSystem.recovery_pool(state, records).size() == pool2.size())


func _test_permadeath() -> void:
	_check("permadeath: an Orre story context applies (colosseums are in-world, not sims)", PUWCombatConsequences.permadeath_applies({"story": true}))
	_check("permadeath: a simulation context does not apply (the VEXA contrast)", not PUWCombatConsequences.permadeath_applies({"simulation": true, "story": true}))
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	var party_state: Dictionary = {"party": [mon], "locked_evo_families": {}, "fainting_ledger": []}
	var after: Dictionary = PUWCombatConsequences.apply_faint_consequences(party_state, mon, {"story": true})
	_check("permadeath: a story faint removes the snagged shadow mon and writes the ledger", (after.get("party", []) as Array).is_empty() and (after.get("fainting_ledger", []) as Array).size() == 1)
	var sim_after: Dictionary = PUWCombatConsequences.apply_faint_consequences(party_state, mon, {"simulation": true})
	_check("permadeath: the same faint inside a sim changes nothing", (sim_after.get("party", []) as Array).size() == 1)
	var state: Dictionary = {}
	PUWShadowSystem.record_snag(state, KEY_MAKUHITA)
	_check("permadeath: recording the faint closes the register record", PUWShadowSystem.record_permanent_faint(state, mon) and PUWShadowSystem.record_closed(state, KEY_MAKUHITA))
	PUWShadowSystem.record_missed(state, KEY_MAKUHITA)
	var records: Array = _load_index()
	_check("permadeath: a permanently fainted snagged mon never respawns into the pool", PUWShadowSystem.recovery_pool(state, records).is_empty())
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	mgr.party = [_shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)]
	var faint_result: Dictionary = mgr.handle_faint(0, false, "scripted_story_battle")
	_check("permadeath: the house faint handler removes it for real outside sims", bool(faint_result.get("permanent", false)) and mgr.party.is_empty())
	mgr.party = [_shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)]
	var sim_result: Dictionary = mgr.handle_faint(0, true, "vexa_sim")
	_check("permadeath: the house faint handler spares it inside sims", not bool(sim_result.get("permanent", true)) and mgr.party.size() == 1)
	mgr.free()


func _test_save_round_trip() -> void:
	var party_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	PUWShadowSystem.apply_gauge_points(party_mon, 63)
	var box_mon: Dictionary = _shadow_mon("teddiursa", "Teddiursa", KEY_MAKUHITA)
	box_mon["heart_gauge"] = 0
	PUWShadowSystem._sync_stage(box_mon)
	PUWShadowSystem.purify_at_relic_stone(box_mon)
	var state: Dictionary = PUWSaveManager.build_state([party_mon], [[box_mon]], {"time-flute": 2}, 100, [], [], [], {}, {})
	PUWShadowSystem.record_snag(state, KEY_MAKUHITA)
	PUWShadowSystem.record_missed(state, KEY_VOLTORB)
	var chamber_mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	PUWPurifyChamber.place_set(state, 0, _max_tempo_set(chamber_mon))
	_check("save: the real save manager writes the state", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("save: the state loads back", not loaded.is_empty())
	var loaded_party: Array = loaded.get("party", [])
	var loaded_mon: Dictionary = loaded_party[0]
	_check("save: shadow_state survives the round trip", str(loaded_mon.get("shadow_state", "")) == "shadow")
	_check("save: heart gauge and max survive", int(loaded_mon.get("heart_gauge", -1)) == 37 and int(loaded_mon.get("heart_gauge_max", -1)) == 100)
	_check("save: heart stage survives", int(loaded_mon.get("heart_stage", -1)) == PUWShadowSystem.heart_stage_for(37, 100))
	_check("save: shadow_origin survives", str(loaded_mon.get("shadow_origin", "")) == KEY_MAKUHITA)
	_check("save: formerly_shadow=false survives as false", loaded_mon.has("formerly_shadow") and not bool(loaded_mon.get("formerly_shadow", true)))
	var loaded_boxes: Array = loaded.get("boxes", [])
	var loaded_box_mon: Dictionary = (loaded_boxes[0] as Array)[0]
	_check("save: a purified box mon keeps state + provenance", str(loaded_box_mon.get("shadow_state", "")) == "purified" and bool(loaded_box_mon.get("formerly_shadow", false)))
	var ledger_value: Variant = loaded.get("shadow_ledger", {})
	var ledger_ok: bool = false
	if ledger_value is Dictionary:
		var ledger: Dictionary = ledger_value
		var snagged_value: Variant = ledger.get("snagged", {})
		if snagged_value is Dictionary:
			var snagged: Dictionary = snagged_value
			ledger_ok = bool(snagged.get(KEY_MAKUHITA, false))
	_check("save: the shadow ledger survives", ledger_ok)
	_check("save: the chamber state survives", PUWPurifyChamber.set_of(loaded, 0).size() == 3)


func _test_region_lock_carry() -> void:
	var mon: Dictionary = _shadow_mon("makuhita", "Makuhita", KEY_MAKUHITA)
	PUWShadowSystem.apply_gauge_points(mon, 25)
	var state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	PUWRegionState.enter_region(state, "orre")
	state["party"] = [mon]
	PUWRegionState.enter_region(state, "kanto")
	var sealed: Array = PUWRegionState.stored_party(state, "orre")
	_check("region lock: the shadow mon is sealed into Orre's record, not deleted", sealed.size() == 1)
	_check("region lock: an unbeaten region's pool does not leak the sealed mon", PUWRegionState.available_party(state).is_empty())
	var sealed_mon: Dictionary = sealed[0]
	_check("region lock: all four fields ride the sync untouched", str(sealed_mon.get("shadow_state", "")) == "shadow" and int(sealed_mon.get("heart_gauge", -1)) == 75 and str(sealed_mon.get("shadow_origin", "")) == KEY_MAKUHITA and sealed_mon.has("formerly_shadow"))
	PUWRegionState.enter_region(state, "orre")
	var back: Array = state.get("party", [])
	_check("region lock: returning to Orre restores the mon with its gauge intact", back.size() == 1 and int((back[0] as Dictionary).get("heart_gauge", -1)) == 75)


func _test_non_orre_snapshots() -> void:
	var plain_state: Dictionary = PUWSaveManager.build_state([_mon("pidgey", "Pidgey")], [], {}, 0, [], [], [], {}, {})
	var expected_keys: Array = ["schema_version", "party", "boxes", "bag", "money", "badges", "dex_seen", "dex_caught", "story_flags", "player", "habitat_rotation", "quests", "mon_id_state"]
	var keys_ok: bool = plain_state.size() == expected_keys.size()
	for key in expected_keys:
		if not plain_state.has(key):
			keys_ok = false
	_check("snapshot: build_state gains no shadow keys for non-Orre play", keys_ok and not plain_state.has("shadow_ledger") and not plain_state.has("purify_chamber"))
	var party_value: Variant = plain_state.get("party", [])
	if party_value is Array:
		var party: Array = party_value
		var plain_mon: Dictionary = party[0]
		_check("snapshot: a plain mon gains no shadow fields", not plain_mon.has("shadow_state") and not plain_mon.has("heart_gauge") and not plain_mon.has("shadow_origin"))
	var bc: BattleController = BattleController.new()
	_check("snapshot: a fresh battle carries no snag state until the launcher stamps it", not bc.battle_state.has("snag_arc") and not bc.battle_state.has("snag_machine_held"))
	bc.free()


func _run() -> void:
	_test_index()
	_test_stamp_and_stages()
	_test_snag_legality()
	_test_battle_patch()
	_test_care_routing()
	_test_battle_and_walk_paths()
	_test_move_unlock()
	_test_purification_paths()
	_test_chamber()
	_test_xd001()
	_test_ledger_and_recovery()
	_test_permadeath()
	_test_save_round_trip()
	_test_region_lock_carry()
	_test_non_orre_snapshots()
	_finish()
