extends SceneTree
## Headless tests for the EXP Candy implementation (code prep
## code_prep_exp_candy, binding build 6): the five EXP Candies
## (XS 100 / S 800 / M 3,000 / L 10,000 / XL 30,000 EXP —
## triple-sourced by the hunt desk: Bulbapedia's Exp. yield
## table, PokémonDB's item pages and Serebii's ItemDex, in
## exact agreement) gained a real ItemEngine arm and an
## "exp_candy" class in PUWItemTarget, replacing the item
## engine gaps prep's refusal. The arm follows the Rare Candy
## arm's conventions: the amount is added to the mon's total
## EXP, the level is re-derived through EXPSystem and clamped
## by the badge hard caps — the caps stop the LEVEL only, EXP
## keeps accruing past them. The Dynamax Candy and the Let's
## Go candies stay refused by Bossy ruling; the gaps suite's
## updated test 8 pins that boundary.
##
## All level math below is the medium-fast curve (EXP =
## level^3, EXPSystem's fallback and the fixtures' curve)
## unless a test says otherwise: L5 = 125, L6 = 216,
## L9 = 729, L10 = 1,000, L14 = 2,744, L15 = 3,375,
## L21 = 9,261, L22 = 10,648, L31 = 29,791, L32 = 32,768.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/exp_candy_tests.gd
## It prints one PASS or FAIL line per test, then a summary
## line, then quits. Exit code 0 means every test passed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW EXP candy tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/exp_candy_tests.gd")
		quit(1)
		return
	_main()


func _main() -> void:
	await process_frame
	await _run("test_exp_candy_exact_values", Callable(self, "test_exp_candy_exact_values"))
	await _run("test_exp_candy_multi_level_gain", Callable(self, "test_exp_candy_multi_level_gain"))
	await _run("test_exp_candy_badge_cap_accrues", Callable(self, "test_exp_candy_badge_cap_accrues"))
	await _run("test_exp_candy_refusals", Callable(self, "test_exp_candy_refusals"))
	await _run("test_exp_candy_through_item_target", Callable(self, "test_exp_candy_through_item_target"))
	await _run("test_exp_candy_growth_rate_honored", Callable(self, "test_exp_candy_growth_rate_honored"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var result: Variant = await fn.call()
	var ok: bool = bool(result)
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


## The gaps suite's fixture dialect (Oak-grant shape).
func _mon(name: String, level: int, hp: int, max_hp: int, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"name": name, "species": name, "species_slug": name.to_lower(), "species_id": 0,
		"family": "PKDX", "level": level, "hp": hp, "max_hp": max_hp,
		"status": "", "confused": false, "item": "", "held_item": "",
		"moves": [], "exp": 0, "exp_frac": 0.0,
		"evs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for k in extra.keys():
		m[k] = extra[k]
	return m


## NOTE (the sibling suites' warning): build_state deep-copies
## the party, so tests rebind fixtures from state["party"]
## before inspecting them.
func _state(party: Array, bag: Dictionary, badges: Array = []) -> Dictionary:
	return PUWSaveManager.build_state(party, [], bag, 0, badges, [], [], {}, {"name": "Riley"})


func _eight_badges() -> Array:
	return [1, 2, 3, 4, 5, 6, 7, 8]


# Test 1: each candy grants exactly its sourced value at the
# engine level, and the level lands where the medium-fast
# curve puts the new total (8 badges, so the cap is 100 and
# never interferes). Base mon: level 5, 125 total EXP.
func test_exp_candy_exact_values() -> bool:
	var ok: bool = true
	var ctx: Dictionary = {"badges": 8}
	var cases: Array = [
		["Exp. Candy XS", 100, 225, 6],
		["Exp. Candy S", 800, 925, 9],
		["Exp. Candy M", 3000, 3125, 14],
		["Exp. Candy L", 10000, 10125, 21],
		["Exp. Candy XL", 30000, 30125, 31],
	]
	for row in cases:
		var item_name: String = str(row[0])
		var want_exp: int = int(row[2])
		var want_level: int = int(row[3])
		var logs: Array = []
		var mon: Dictionary = _mon("Pikachu", 5, 20, 20, {"exp": 125})
		ok = _expect(ItemEngine.use_battle_item(item_name, mon, logs, ctx), item_name + " must work on a level 5 mon") and ok
		ok = _expect(int(mon.get("exp", -1)) == want_exp, item_name + " must grant exactly " + str(int(row[1])) + " EXP (total " + str(want_exp) + "), got " + str(mon.get("exp", -1))) and ok
		ok = _expect(int(mon.get("level", -1)) == want_level, item_name + " must land the mon at level " + str(want_level) + ", got " + str(mon.get("level", -1))) and ok
		var grew: bool = false
		for line in logs:
			if str(line) == "Pikachu grew to Lv. " + str(want_level) + "!":
				grew = true
		ok = _expect(grew, item_name + " must log the level-up line, got " + str(logs)) and ok
		ok = _expect(str(logs[logs.size() - 1]).begins_with("Used " + item_name + " on"), item_name + "'s final log line must be the engine's Used line") and ok
	return ok


# Test 2: one candy, many levels — an XL on a level 1 mon
# (0 EXP) is a 30-level gain in a single use, and an S on a
# fresh mon is 8 levels. No per-level iteration is faked:
# the arm adds once and re-derives the level once.
func test_exp_candy_multi_level_gain() -> bool:
	var ok: bool = true
	var ctx: Dictionary = {"badges": 8}
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 1, 10, 10, {"exp": 0})
	ok = _expect(ItemEngine.use_battle_item("Exp. Candy XL", mon, logs, ctx), "XL on a level 1 mon must work") and ok
	ok = _expect(int(mon.get("exp", -1)) == 30000, "the total must be exactly 30000, got " + str(mon.get("exp", -1))) and ok
	ok = _expect(int(mon.get("level", -1)) == 31, "one XL must take a level 1 mon to level 31, got " + str(mon.get("level", -1))) and ok
	var logs2: Array = []
	var mon2: Dictionary = _mon("Pikachu", 1, 10, 10, {"exp": 0})
	ok = _expect(ItemEngine.use_battle_item("Exp. Candy S", mon2, logs2, ctx), "S on a level 1 mon must work") and ok
	ok = _expect(int(mon2.get("level", -1)) == 9, "one S must take a level 1 mon to level 9 (729 <= 800 < 1000), got " + str(mon2.get("level", -1))) and ok
	return ok


# Test 3: the badge hard caps stop the LEVEL only — EXP
# accrues in full past them (EXPSystem's documented rule,
# the same one battle_controller._give_exp follows). At 0
# badges (cap 10) a level 9 mon fed an XL stops at level 10
# with the full 30,000 banked, and a second XL at the cap
# still succeeds and banks 30,000 more. Through the bag
# flow, a mon AT the cap is a valid target (no level_cap
# refusal — the deliberate divergence from Rare Candy).
func test_exp_candy_badge_cap_accrues() -> bool:
	var ok: bool = true
	var ctx: Dictionary = {"badges": 0}
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 9, 30, 30, {"exp": 729})
	ok = _expect(ItemEngine.use_battle_item("Exp. Candy XL", mon, logs, ctx), "XL under the 0-badge cap must work") and ok
	ok = _expect(int(mon.get("exp", -1)) == 30729, "the full 30000 must bank (729 + 30000), got " + str(mon.get("exp", -1))) and ok
	ok = _expect(int(mon.get("level", -1)) == 10, "the level must stop at the cap of 10, got " + str(mon.get("level", -1))) and ok
	ok = _expect(ItemEngine.use_battle_item("Exp. Candy XL", mon, logs, ctx), "a candy at the cap must still work — the EXP accrues") and ok
	ok = _expect(int(mon.get("exp", -1)) == 60729, "the second 30000 must bank too, got " + str(mon.get("exp", -1))) and ok
	ok = _expect(int(mon.get("level", -1)) == 10, "the level must stay at the cap, got " + str(mon.get("level", -1))) and ok
	# Through the flow: validity at the cap is VALID.
	var state: Dictionary = _state([_mon("Pikachu", 10, 30, 30, {"exp": 1000})], {"exp-candy-xs": 1})
	var fmon: Dictionary = state["party"][0]
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "exp-candy-xs", 0)
	ok = _expect(bool(v.get("valid", false)), "a mon at the badge cap must be a valid EXP candy target, got " + str(v)) and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "exp-candy-xs", 0)
	ok = _expect(bool(res.get("ok", false)), "the at-cap use must resolve, got " + str(res)) and ok
	ok = _expect(int(fmon.get("exp", -1)) == 1100, "the flow must bank the 100 EXP, got " + str(fmon.get("exp", -1))) and ok
	ok = _expect(int(fmon.get("level", -1)) == 10, "the flow must hold the level at the cap") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "exp-candy-xs") == 0, "the successful at-cap use must consume the candy") and ok
	return ok


# Test 4: refusal paths — level 100 and fainted at the
# engine level; max_level, fainted and egg through the bag
# flow, each leaving the mon byte-identical and the candy
# unconsumed.
func test_exp_candy_refusals() -> bool:
	var ok: bool = true
	var ctx: Dictionary = {"badges": 8}
	var logs: Array = []
	var maxed: Dictionary = _mon("Pikachu", 100, 300, 300, {"exp": 1000000})
	ok = _expect(not ItemEngine.use_battle_item("Exp. Candy XS", maxed, logs, ctx), "a level 100 mon must refuse (no EXP can be gained)") and ok
	ok = _expect(int(maxed.get("exp", -1)) == 1000000, "the level 100 refusal must change nothing") and ok
	var fainted: Dictionary = _mon("Pikachu", 5, 0, 20, {"exp": 125})
	ok = _expect(not ItemEngine.use_battle_item("Exp. Candy XS", fainted, logs, ctx), "a fainted mon must refuse (the engine's medicine-arm precedent)") and ok
	ok = _expect(int(fainted.get("exp", -1)) == 125 and int(fainted.get("level", -1)) == 5, "the fainted refusal must change nothing") and ok
	var leveless: Dictionary = _mon("Pikachu", 0, 20, 20, {"exp": 0})
	ok = _expect(not ItemEngine.use_battle_item("Exp. Candy XS", leveless, logs, ctx), "a level 0 mon must refuse") and ok
	# Through the flow.
	var state: Dictionary = _state([_mon("Pikachu", 100, 300, 300, {"exp": 1000000})], {"exp-candy-xs": 1}, _eight_badges())
	var fmon: Dictionary = state["party"][0]
	var before: String = JSON.stringify(fmon)
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "exp-candy-xs", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "max_level", "level 100 must grey max_level, got " + str(v)) and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "exp-candy-xs", 0)
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "max_level", "the flow must refuse max_level") and ok
	ok = _expect(JSON.stringify(fmon) == before, "the max_level refusal must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "exp-candy-xs") == 1, "the max_level refusal must not consume") and ok
	var fstate: Dictionary = _state([_mon("Pikachu", 5, 0, 20, {"exp": 125})], {"exp-candy-s": 1}, _eight_badges())
	var fv: Dictionary = PUWItemTarget.target_validity(fstate, "use", "exp-candy-s", 0)
	ok = _expect(not bool(fv.get("valid", true)) and str(fv.get("reason", "")) == "fainted", "a fainted mon must grey fainted, got " + str(fv)) and ok
	var fres: Dictionary = PUWItemTarget.use_on_mon(fstate, "exp-candy-s", 0)
	ok = _expect(not bool(fres.get("ok", true)) and str(fres.get("reason", "")) == "fainted", "the flow must refuse fainted") and ok
	ok = _expect(PUWLiveBag.count_in_state(fstate, "exp-candy-s") == 1, "the fainted refusal must not consume") and ok
	var estate: Dictionary = _state([_mon("Pikachu", 5, 20, 20, {"exp": 125, "is_egg": true})], {"exp-candy-m": 1}, _eight_badges())
	var emon: Dictionary = estate["party"][0]
	var ebefore: String = JSON.stringify(emon)
	var ev: Dictionary = PUWItemTarget.target_validity(estate, "use", "exp-candy-m", 0)
	ok = _expect(not bool(ev.get("valid", true)) and str(ev.get("reason", "")) == "egg", "an egg must grey egg, got " + str(ev)) and ok
	var eres: Dictionary = PUWItemTarget.use_on_mon(estate, "exp-candy-m", 0)
	ok = _expect(not bool(eres.get("ok", true)) and str(eres.get("reason", "")) == "egg", "the flow must refuse an egg") and ok
	ok = _expect(JSON.stringify(emon) == ebefore, "the egg refusal must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(estate, "exp-candy-m") == 1, "the egg refusal must not consume") and ok
	return ok


# Test 5: the whole bag flow — all five candies are targeted
# items, a use resolves through the engine with exactly one
# consumed, the message carries the engine's own lines, and
# an unheld candy refuses not_held.
func test_exp_candy_through_item_target() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([
		_mon("Pikachu", 5, 20, 20, {"exp": 125}),
		_mon("Bulbasaur", 1, 10, 10, {"exp": 0}),
	], {"exp-candy-xs": 2, "exp-candy-xl": 1}, _eight_badges())
	var pika: Dictionary = state["party"][0]
	var bulb: Dictionary = state["party"][1]
	for slug in ["exp-candy-xs", "exp-candy-s", "exp-candy-m", "exp-candy-l", "exp-candy-xl"]:
		ok = _expect(PUWItemTarget.use_mode(state, slug) == "target", slug + " must be a targeted item") and ok
		ok = _expect(PUWItemTarget.class_of(slug) == "exp_candy", slug + " must classify exp_candy") and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "exp-candy-xs", 0)
	ok = _expect(bool(res.get("ok", false)), "the XS use must resolve, got " + str(res)) and ok
	ok = _expect(int(pika.get("exp", -1)) == 225 and int(pika.get("level", -1)) == 6, "Pikachu must hold 225 EXP at level 6, got exp " + str(pika.get("exp", -1)) + " level " + str(pika.get("level", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "exp-candy-xs") == 1, "exactly one XS must be consumed") and ok
	ok = _expect(str(res.get("message", "")).contains("Pikachu grew to Lv. 6!"), "the message must carry the level-up line, got: " + str(res.get("message", ""))) and ok
	ok = _expect(str(res.get("message", "")).contains("Used Exp. Candy XS on Pikachu."), "the message must carry the engine's Used line, got: " + str(res.get("message", ""))) and ok
	res = PUWItemTarget.use_on_mon(state, "exp-candy-xl", 1)
	ok = _expect(bool(res.get("ok", false)), "the XL use must resolve, got " + str(res)) and ok
	ok = _expect(int(bulb.get("exp", -1)) == 30000 and int(bulb.get("level", -1)) == 31, "Bulbasaur must hold 30000 EXP at level 31, got exp " + str(bulb.get("exp", -1)) + " level " + str(bulb.get("level", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "exp-candy-xl") == 0, "the XL must be consumed") and ok
	var missing: Dictionary = PUWItemTarget.use_on_mon(state, "exp-candy-m", 0)
	ok = _expect(not bool(missing.get("ok", true)) and str(missing.get("reason", "")) == "not_held", "an unheld candy must refuse not_held, got " + str(missing)) and ok
	ok = _expect(int(pika.get("exp", -1)) == 225, "the not_held refusal must change nothing") and ok
	return ok


# Test 6: the species' own growth curve is honored, not the
# fallback — a Slow-curve mon (EXP for level n = 5n^3/4:
# L5 = 156, L6 = 270, L9 = 911, L10 = 1250) gains the same
# EXP but levels by its own curve. 256 total EXP is level 6
# on medium-fast but still level 5 on Slow.
func test_exp_candy_growth_rate_honored() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_mon("Pikachu", 5, 20, 20, {"exp": 156, "growth_rate": "slow"})], {"exp-candy-xs": 1, "exp-candy-s": 1}, _eight_badges())
	var mon: Dictionary = state["party"][0]
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "exp-candy-xs", 0)
	ok = _expect(bool(res.get("ok", false)), "the XS use must resolve, got " + str(res)) and ok
	ok = _expect(int(mon.get("exp", -1)) == 256, "the total must be 256, got " + str(mon.get("exp", -1))) and ok
	ok = _expect(int(mon.get("level", -1)) == 5, "256 EXP is still level 5 on the Slow curve (L6 = 270), got " + str(mon.get("level", -1))) and ok
	res = PUWItemTarget.use_on_mon(state, "exp-candy-s", 0)
	ok = _expect(bool(res.get("ok", false)), "the S use must resolve, got " + str(res)) and ok
	ok = _expect(int(mon.get("exp", -1)) == 1056 and int(mon.get("level", -1)) == 9, "1056 EXP must be level 9 on the Slow curve (911 <= 1056 < 1250), got exp " + str(mon.get("exp", -1)) + " level " + str(mon.get("level", -1))) and ok
	return ok
