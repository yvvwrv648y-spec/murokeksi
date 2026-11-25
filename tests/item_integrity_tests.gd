extends SceneTree
## Headless tests for the Pokemon Ultimate World item-integrity
## pass (Riley's rules, 2026-11-23): every item works or is
## flagged, no duplicate items, and odds/EXP items stack the way
## the real games stack them.
##
## Code under test:
## - PUWItemRegistry (systems/inventory/item_registry.gd) over
##   systems/inventory/item_registry.json: 2,299 source rows
##   (2,241 from items_full.json + 58 from
##   complete_item_database.json) canonicalised to 2,183 entries,
##   346 implemented + 1,837 flagged_unimplemented (post-A-35 audit, build 6).
## - MartShop canonical bag API (add_item / count_item /
##   consume_item) in systems/inventory/mart_shop.gd.
## - ShinyOdds (systems/inventory/shiny_odds.gd): Gen 6+ canon,
##   base 1/4096, Shiny Charm +2 rolls = 3/4096, composition is
##   additive in rolls (charm + a +2 second source = 5/4096).
## - Lucky Egg through EXPSystem.exp_gain_for_holder and the real
##   grant path BattleController.grant_exp / _give_exp: holder
##   earns floor(share x 1.5); the badge level cap still stores
##   EXP in full and clamps only the level (exp_cap behaviour).
##
## How to run it (Godot 4.7, headless):
##   godot --headless --script res://tests/item_integrity_tests.gd
## Prints one PASS or FAIL line per test, then a summary, then
## quits. Exit code 0 means every test passed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW item integrity tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/item_integrity_tests.gd")
		quit(1)
		return
	_run("test_audit_coverage_counts", Callable(self, "test_audit_coverage_counts"))
	_run("test_every_entry_carries_status", Callable(self, "test_every_entry_carries_status"))
	_run("test_no_duplicate_name_effect_pairs", Callable(self, "test_no_duplicate_name_effect_pairs"))
	_run("test_bag_dedupe_one_stack", Callable(self, "test_bag_dedupe_one_stack"))
	_run("test_bag_consume_and_count_canonical", Callable(self, "test_bag_consume_and_count_canonical"))
	_run("test_shiny_base_rate", Callable(self, "test_shiny_base_rate"))
	_run("test_shiny_charm_rate", Callable(self, "test_shiny_charm_rate"))
	_run("test_shiny_combined_rate", Callable(self, "test_shiny_combined_rate"))
	_run("test_lucky_egg_exp_system_multiplier", Callable(self, "test_lucky_egg_exp_system_multiplier"))
	_run("test_lucky_egg_real_grant", Callable(self, "test_lucky_egg_real_grant"))
	_run("test_lucky_egg_grant_respects_level_cap", Callable(self, "test_lucky_egg_grant_respects_level_cap"))
	print("PUW item integrity tests — done: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("Failed tests: " + str(_failed_names))
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


# Test 1: audit coverage. The registry's implemented + flagged
# counts sum to the canonical total, and the totals match the
# generated audit exactly (2,183 canonical entries from 2,299
# source rows; 346 implemented, 1,837 flagged after build 6 A-35).
func test_audit_coverage_counts() -> bool:
	var ok: bool = true
	var counts: Dictionary = PUWItemRegistry.counts()
	ok = _expect(int(counts.get("total", 0)) == 2183, "canonical total must be 2183, got %d" % int(counts.get("total", 0))) and ok
	ok = _expect(int(counts.get("implemented", 0)) == 346, "implemented must be 346, got %d" % int(counts.get("implemented", 0))) and ok
	ok = _expect(int(counts.get("flagged", 0)) == 1837, "flagged must be 1837, got %d" % int(counts.get("flagged", 0))) and ok
	ok = _expect(int(counts.get("implemented", 0)) + int(counts.get("flagged", 0)) == int(counts.get("total", 0)), "implemented + flagged must sum to the registry total") and ok
	var meta: Dictionary = PUWItemRegistry.metadata()
	var sources: Dictionary = meta.get("sources", {})
	ok = _expect(int(sources.get("total_source_rows", 0)) == 2299, "source rows must be 2299, got %d" % int(sources.get("total_source_rows", 0))) and ok
	ok = _expect(int(sources.get("items_full_rows", 0)) == 2241, "items_full rows must be 2241, got %d" % int(sources.get("items_full_rows", 0))) and ok
	return ok


# Test 2: every canonical entry carries a status, and the two
# items this pass implemented report "implemented" while a known
# unimplemented item (Oval Charm — no breeding/daycare exists in
# this engine) reports "flagged_unimplemented".
func test_every_entry_carries_status() -> bool:
	var ok: bool = true
	for entry_value in PUWItemRegistry.all_entries():
		var entry: Dictionary = entry_value
		var status: String = str(entry.get("status", ""))
		if status != PUWItemRegistry.STATUS_IMPLEMENTED and status != PUWItemRegistry.STATUS_FLAGGED:
			ok = _expect(false, "entry %s carries no valid status" % str(entry.get("id", "?"))) and ok
			break
		if status == PUWItemRegistry.STATUS_IMPLEMENTED:
			var via: Array = entry.get("implemented_via", [])
			if via.is_empty():
				ok = _expect(false, "implemented entry %s lists no implementing file" % str(entry.get("id", "?"))) and ok
				break
	ok = _expect(PUWItemRegistry.status_of("shiny-charm") == "implemented", "Shiny Charm must be implemented") and ok
	ok = _expect(PUWItemRegistry.status_of("lucky-egg") == "implemented", "Lucky Egg must be implemented") and ok
	ok = _expect(PUWItemRegistry.status_of("oval-charm") == "flagged_unimplemented", "Oval Charm must be flagged (no breeding in this engine)") and ok
	ok = _expect(PUWItemRegistry.is_implemented("leftovers"), "Leftovers must be implemented") and ok
	ok = _expect(not PUWItemRegistry.is_implemented("x-attack"), "X Attack must be flagged (only a mart price list mentions it)") and ok
	return ok


# Test 3: dedupe proof. Scanning the canonical registry finds
# zero pairs of entries with identical (name, effect), using the
# registry's own normalisation (which keeps Nidoran F/M candy
# distinct via the gender-sign mapping), and zero duplicate ids.
func test_no_duplicate_name_effect_pairs() -> bool:
	var ok: bool = true
	var seen_pairs: Dictionary = {}
	var seen_ids: Dictionary = {}
	for entry_value in PUWItemRegistry.all_entries():
		var entry: Dictionary = entry_value
		var pair_key: String = PUWItemRegistry.norm_key(str(entry.get("name", ""))) + "|" + PUWItemRegistry.norm_key(str(entry.get("effect", "")))
		if seen_pairs.has(pair_key):
			ok = _expect(false, "duplicate (name, effect) pair: %s and %s" % [str(seen_pairs[pair_key]), str(entry.get("id", ""))]) and ok
		seen_pairs[pair_key] = str(entry.get("id", ""))
		var entry_id: String = str(entry.get("id", ""))
		if seen_ids.has(entry_id):
			ok = _expect(false, "duplicate canonical id: " + entry_id) and ok
		seen_ids[entry_id] = true
	return ok


# Test 4: bag-level dedupe proof. Granting the same canonical
# item through two different source mappings — the PokeAPI slug
# "poke-ball" and its Let's Go source row "lapoke-ball" (plus the
# project spelling "poke_ball") — yields ONE bag stack with the
# quantities summed.
func test_bag_dedupe_one_stack() -> bool:
	var ok: bool = true
	ok = _expect(PUWItemRegistry.canonical_id_for("lapoke-ball") == "poke-ball", "lapoke-ball must resolve to canonical poke-ball, got " + PUWItemRegistry.canonical_id_for("lapoke-ball")) and ok
	ok = _expect(PUWItemRegistry.canonical_id_for("poke_ball") == "poke-ball", "poke_ball must resolve to canonical poke-ball") and ok
	var shop: MartShop = MartShop.new()
	var r1: Dictionary = shop.add_item("poke-ball", 3)
	var r2: Dictionary = shop.add_item("lapoke-ball", 4)
	var r3: Dictionary = shop.add_item("poke_ball", 1)
	ok = _expect(bool(r1.get("ok", false)) and bool(r2.get("ok", false)) and bool(r3.get("ok", false)), "all three grants must succeed") and ok
	ok = _expect(shop.bag.size() == 1, "bag must hold exactly ONE stack, got %d stacks: %s" % [shop.bag.size(), str(shop.bag)]) and ok
	ok = _expect(int(shop.bag.get("poke-ball", 0)) == 8, "the one stack must sum to 8, got %d" % int(shop.bag.get("poke-ball", 0))) and ok
	ok = _expect(shop.count_item("lapoke-ball") == 8, "count via the variant spelling must also be 8") and ok
	shop.free()
	return ok


# Test 5: count/consume honour the canonical key, including a
# variant key written directly into bag (the way follower code
# writes shop.bag[slug] itself).
func test_bag_consume_and_count_canonical() -> bool:
	var ok: bool = true
	var shop: MartShop = MartShop.new()
	shop.bag["lapoke-ball"] = 2
	var added: Dictionary = shop.add_item("poke-ball", 1)
	ok = _expect(bool(added.get("ok", false)), "add must succeed") and ok
	ok = _expect(shop.count_item("poke-ball") == 3, "count must sum canonical + variant keys to 3, got %d" % shop.count_item("poke-ball")) and ok
	ok = _expect(shop.consume_item("poke_ball", 3), "consuming all 3 through a third spelling must succeed") and ok
	ok = _expect(shop.count_item("poke-ball") == 0, "bag must be empty of Poke Balls after consuming all") and ok
	ok = _expect(not shop.consume_item("poke-ball", 1), "consuming from an empty stack must fail") and ok
	shop.free()
	return ok


# Test 6: shiny stacking — base rate. No sources: exactly 1/4096.
func test_shiny_base_rate() -> bool:
	var ok: bool = true
	var frac: Dictionary = ShinyOdds.shiny_chance_fraction(false)
	ok = _expect(int(frac.get("numerator", 0)) == 1 and int(frac.get("denominator", 0)) == 4096, "base fraction must be 1/4096, got %s" % str(frac)) and ok
	ok = _expect(ShinyOdds.shiny_chance(false) == 1.0 / 4096.0, "base chance must be exactly 1/4096") and ok
	ok = _expect(ShinyOdds.total_rolls(false) == 1, "base rolls must be 1") and ok
	return ok


# Test 7: shiny stacking — Shiny Charm. Gen 6+ canon: +2 extra
# rolls, so exactly 3/4096 (about 1/1365.67).
func test_shiny_charm_rate() -> bool:
	var ok: bool = true
	var frac: Dictionary = ShinyOdds.shiny_chance_fraction(true)
	ok = _expect(int(frac.get("numerator", 0)) == 3 and int(frac.get("denominator", 0)) == 4096, "charm fraction must be 3/4096, got %s" % str(frac)) and ok
	ok = _expect(ShinyOdds.shiny_chance(true) == 3.0 / 4096.0, "charm chance must be exactly 3/4096") and ok
	ok = _expect(ShinyOdds.extra_rolls_for_sources({"shiny_charm": true}) == 2, "the charm source must grant exactly +2 rolls") and ok
	ok = _expect(ShinyOdds.extra_rolls_for_sources({}) == 0, "no active source must grant +0 rolls") and ok
	return ok


# Test 8: shiny stacking — composition. Sources compose by
# adding rolls: Shiny Charm (+2) together with a second +2
# roll-granting source gives exactly 5/4096. This engine has no
# second odds source today (no breeding/Masuda, no chains — see
# shiny_odds.gd header), so the second source is exercised
# through the documented additional-rolls composition channel
# that any future source will use.
func test_shiny_combined_rate() -> bool:
	var ok: bool = true
	var frac: Dictionary = ShinyOdds.shiny_chance_fraction(true, 2)
	ok = _expect(int(frac.get("numerator", 0)) == 5 and int(frac.get("denominator", 0)) == 4096, "combined fraction must be 5/4096, got %s" % str(frac)) and ok
	ok = _expect(ShinyOdds.shiny_chance(true, 2) == 5.0 / 4096.0, "combined chance must be exactly 5/4096") and ok
	ok = _expect(ShinyOdds.total_rolls(true, 2) == 5, "combined rolls must be 1 + 2 + 2 = 5") and ok
	ok = _expect(ShinyOdds.shiny_chance(false, 2) == 3.0 / 4096.0, "a lone +2 source without the charm must give 3/4096 (additive, not multiplicative)") and ok
	return ok


# Test 9: Lucky Egg at the EXPSystem level. exp_gain_for_holder
# returns floor(share x 1.5) for a Lucky Egg holder (any spelling
# of the name) and the untouched share for everyone else.
func test_lucky_egg_exp_system_multiplier() -> bool:
	var ok: bool = true
	# Bulbasaur base EXP 64, fainted level 7, one participant:
	# total = 64 * 7 / 7 = 64, share 64, Lucky Egg = 96.
	var plain: int = EXPSystem.exp_gain_for_holder(64, 7, 1, false, "")
	var held: int = EXPSystem.exp_gain_for_holder(64, 7, 1, false, "Lucky Egg")
	var held_slug: int = EXPSystem.exp_gain_for_holder(64, 7, 1, false, "lucky-egg")
	ok = _expect(plain == 64, "plain share must be 64, got %d" % plain) and ok
	ok = _expect(held == 96, "Lucky Egg share must be 96 (64 x 1.5), got %d" % held) and ok
	ok = _expect(held_slug == 96, "slug spelling must give the same 96, got %d" % held_slug) and ok
	ok = _expect(float(held) == float(plain) * 1.5, "held must be exactly 1.5x plain for this even share") and ok
	# Odd share floors: base 45, level 7 -> total 45, share 45,
	# Lucky Egg floor(67.5) = 67.
	ok = _expect(EXPSystem.exp_gain_for_holder(45, 7, 1, false, "Lucky Egg") == 67, "odd share must floor to 67") and ok
	# Other held items change nothing.
	ok = _expect(EXPSystem.exp_gain_for_holder(64, 7, 1, false, "Leftovers") == 64, "Leftovers holder must get the plain share") and ok
	return ok


## A BattleController in the tree, so _ready() has run. Same
## construction as exp_cap_tests.gd.
func _new_controller() -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	return controller


## One earner mon in the total-EXP style _give_exp expects.
func _earner(mon_name: String, held_item: String) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": 5, "hp": 100, "max_hp": 100,
		"atk": 100, "def": 50, "spa": 100, "spd": 50, "spe": 100,
		"types": ["normal"], "ability": "", "item": held_item, "status": "",
		"moves": ["Tackle"], "participated": true,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
		"growth_rate": "medium-slow",
		"exp": EXPSystem.exp_for_level("medium-slow", 5),
		"exp_is_total": true,
	}
	return mon


# Test 10: Lucky Egg through the REAL grant path. Two identical
# participated earners split a fainted Bulbasaur's EXP through
# BattleController.grant_exp; the Lucky Egg holder's stored EXP
# grows by exactly 1.5x the plain earner's growth.
# Bulbasaur base EXP 64 (exp_yield.json), fainted level 14:
# total = 64 * 14 / 7 = 128, split by 2 = 64 each; holder = 96.
func test_lucky_egg_real_grant() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	var plain_mon: Dictionary = _earner("PlainMon", "")
	var held_mon: Dictionary = _earner("HeldMon", "Lucky Egg")
	var plain_start: int = int(plain_mon.get("exp", 0))
	var held_start: int = int(held_mon.get("exp", 0))
	var fainted: Dictionary = {"name": "Bulbasaur", "species": "Bulbasaur", "level": 14}
	var logs: Array = []
	c.grant_exp([plain_mon, held_mon], fainted, logs)
	var plain_gain: int = int(plain_mon.get("exp", 0)) - plain_start
	var held_gain: int = int(held_mon.get("exp", 0)) - held_start
	ok = _expect(plain_gain == 64, "plain earner must gain 64, got %d (logs: %s)" % [plain_gain, str(logs)]) and ok
	ok = _expect(held_gain == 96, "Lucky Egg earner must gain 96, got %d" % held_gain) and ok
	ok = _expect(float(held_gain) == float(plain_gain) * 1.5, "real grant must be exactly 1.5x with the Lucky Egg") and ok
	return ok


# Test 11: the Lucky Egg grant respects the protected obedience
# cap behaviour (exp_cap_tests): at 0 badges the level clamps to
# 10, but the full multiplied EXP is stored.
func test_lucky_egg_grant_respects_level_cap() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	c.set_badge_count(0)
	var mon: Dictionary = _earner("CappedMon", "Lucky Egg")
	mon["level"] = 9
	mon["exp"] = EXPSystem.exp_for_level("medium-slow", 9)
	var start_exp: int = int(mon.get("exp", 0))
	var logs: Array = []
	c._give_exp(mon, EXPSystem.exp_gain_for_holder(64, 7, 1, false, "Lucky Egg"), logs)
	ok = _expect(int(mon.get("exp", 0)) == start_exp + 96, "the full Lucky Egg amount (96) must be stored, got %d" % (int(mon.get("exp", 0)) - start_exp)) and ok
	# A huge multiplied grant: level clamps to 10, EXP in full.
	var mon2: Dictionary = _earner("CappedMon2", "Lucky Egg")
	mon2["level"] = 9
	mon2["name"] = "Bulbasaur"
	mon2["species"] = "Bulbasaur"
	mon2["exp"] = EXPSystem.exp_for_level("medium-slow", 9)
	var start2: int = int(mon2.get("exp", 0))
	var logs2: Array = []
	c._give_exp(mon2, 1000000, logs2)
	ok = _expect(int(mon2.get("level", 0)) == 10, "level must clamp to the 0-badge cap of 10, got %d" % int(mon2.get("level", 0))) and ok
	ok = _expect(int(mon2.get("exp", 0)) == start2 + 1000000, "EXP must accrue in full past the cap") and ok
	return ok
