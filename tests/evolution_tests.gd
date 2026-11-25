extends SceneTree
## Headless tests for the Pokemon Ultimate World evolution
## manager (battle engine v6 pack).
##
## The manager under test is DynamicEvolutionEngine
## (evolution_manager.gd), merged at
## res://pokemon/evolution/evolution_manager.gd, reading the real
## table at res://data/evolution_triggers.json.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/evolution_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.
##
## What is checked, all against the real data rows:
## - Magikarp needs level 20 for Gyarados: level 19 fails, 20 works.
## - Pikachu evolves to Raichu with a Thunder Stone and does not
##   evolve with a Water Stone.
## - Eevee needs friendship 160 (the value in its own rows):
##   at 160 with day in the context it becomes Espeon, at 160 with
##   night it becomes Umbreon, and below 160 it does not evolve.
## - Trade species now follow Riley's 2026-11-22 rule: a trade
##   row with no held item also evolves on a level-up at level
##   30 (Machoke, Kadabra), a trade row with a held item also
##   evolves on a level-up while holding it (Onix, Seadra), and
##   a Linking Cord works through the trade rows for all of
##   them. check_trade reports needs_trade_rule false.
## - Inkay evolves at level 30 even without the upside-down
##   context; Meltan evolves at level 30.
## - Special triggers run through check_special: Basculin needs
##   294 recoil damage, Kubfu needs the right scroll for its
##   tower, and Milcery's spin names the Alcremie form.
## - Nincada at level 20 with a free party slot and a Poke Ball
##   in the bag also brings Shedinja as a bonus evolution.
## - apply_evolution returns a new dict: the input mon is left
##   exactly as it was, and level and moves carry over.
## - on_level_up is the full hook: a level 20 Magikarp comes back
##   evolved, a level 19 one comes back unchanged.
## - Display names are cleaned to slugs the same way the battle
##   controller does it: "Mime Jr." finds the mime-jr row and its
##   known-move condition (Mimic) is honored.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []
var _engine: DynamicEvolutionEngine = null


func _init() -> void:
	print("PUW battle engine v6 evolution tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/evolution_tests.gd")
		quit(1)
		return
	_engine = DynamicEvolutionEngine.new()
	_run("test_magikarp_level_gate", Callable(self, "test_magikarp_level_gate"))
	_run("test_pikachu_thunder_stone", Callable(self, "test_pikachu_thunder_stone"))
	_run("test_eevee_friendship_and_time", Callable(self, "test_eevee_friendship_and_time"))
	_run("test_machoke_trade_branches", Callable(self, "test_machoke_trade_branches"))
	_run("test_onix_held_item_trade_branch", Callable(self, "test_onix_held_item_trade_branch"))
	_run("test_seadra_dragon_scale_branches", Callable(self, "test_seadra_dragon_scale_branches"))
	_run("test_inkay_upside_down_branch", Callable(self, "test_inkay_upside_down_branch"))
	_run("test_kadabra_and_meltan_level_30", Callable(self, "test_kadabra_and_meltan_level_30"))
	_run("test_basculin_recoil", Callable(self, "test_basculin_recoil"))
	_run("test_nincada_shed_bonus", Callable(self, "test_nincada_shed_bonus"))
	_run("test_kubfu_towers_and_scrolls", Callable(self, "test_kubfu_towers_and_scrolls"))
	_run("test_milcery_spin_forms", Callable(self, "test_milcery_spin_forms"))
	_run("test_apply_evolution_keeps_input", Callable(self, "test_apply_evolution_keeps_input"))
	_run("test_on_level_up_hook", Callable(self, "test_on_level_up_hook"))
	_run("test_display_name_and_known_move", Callable(self, "test_display_name_and_known_move"))
	_engine.free()
	_engine = null
	print("PUW battle engine v6 evolution tests — done: %d passed, %d failed." % [_passed, _failed])
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


# Test 1: Magikarp at level 19 does NOT evolve on a level-up
# check; at level 20 it evolves to Gyarados. The data row for
# magikarp says min_level 20, trigger level-up, to gyarados.
func test_magikarp_level_gate() -> bool:
	var ok: bool = true
	var young: Dictionary = {"species": "Magikarp", "name": "Magikarp", "level": 19, "moves": ["Splash"]}
	var young_check: Dictionary = _engine.check_level_up(young)
	ok = _expect(not bool(young_check.get("can_evolve", true)), "level 19 Magikarp must not evolve") and ok
	var grown: Dictionary = {"species": "Magikarp", "name": "Magikarp", "level": 20, "moves": ["Splash", "Tackle"]}
	var grown_check: Dictionary = _engine.check_level_up(grown)
	ok = _expect(bool(grown_check.get("can_evolve", false)), "level 20 Magikarp must evolve") and ok
	ok = _expect(str(grown_check.get("to_slug", "")) == "gyarados", "Magikarp evolves to gyarados, got " + str(grown_check.get("to_slug", ""))) and ok
	ok = _expect(int(grown_check.get("to_id", 0)) == 130, "Gyarados id is 130, got " + str(grown_check.get("to_id", 0))) and ok
	return ok


# Test 2: Pikachu + "Thunder Stone" evolves to Raichu through the
# use-item check; Pikachu + "Water Stone" does not. The data
# stores the trigger item as the slug "thunder-stone", so this
# also proves display item names are cleaned before comparing.
func test_pikachu_thunder_stone() -> bool:
	var ok: bool = true
	var pikachu: Dictionary = {"species": "Pikachu", "name": "Pikachu", "level": 10, "moves": ["Thunder Shock"]}
	var thunder: Dictionary = _engine.check_use_item(pikachu, "Thunder Stone")
	ok = _expect(bool(thunder.get("can_evolve", false)), "Pikachu with a Thunder Stone must evolve") and ok
	ok = _expect(str(thunder.get("to_slug", "")) == "raichu", "Pikachu evolves to raichu, got " + str(thunder.get("to_slug", ""))) and ok
	var water: Dictionary = _engine.check_use_item(pikachu, "Water Stone")
	ok = _expect(not bool(water.get("can_evolve", true)), "Pikachu with a Water Stone must not evolve") and ok
	# A plain level-up check must not evolve Pikachu either: its
	# only row is the use-item one.
	var level_check: Dictionary = _engine.check_level_up(pikachu)
	ok = _expect(not bool(level_check.get("can_evolve", true)), "Pikachu must not evolve on a level-up check") and ok
	return ok


# Test 3: Eevee friendship evolution, using the data's own
# numbers. Eevee's level-up rows for Espeon and Umbreon both say
# min_happiness 160; Espeon needs time_of_day day, Umbreon needs
# night. At friendship 160 with day in the context Eevee becomes
# Espeon; with night it becomes Umbreon; below 160 it stays Eevee.
func test_eevee_friendship_and_time() -> bool:
	var ok: bool = true
	var happy_day: Dictionary = {"species": "Eevee", "name": "Eevee", "level": 10, "friendship": 160, "moves": ["Tackle"]}
	var day_check: Dictionary = _engine.check_level_up(happy_day, {"time_of_day": "day"})
	ok = _expect(bool(day_check.get("can_evolve", false)), "Eevee at friendship 160 by day must evolve") and ok
	ok = _expect(str(day_check.get("to_slug", "")) == "espeon", "Eevee by day evolves to espeon, got " + str(day_check.get("to_slug", ""))) and ok
	var night_check: Dictionary = _engine.check_level_up(happy_day, {"time_of_day": "night"})
	ok = _expect(bool(night_check.get("can_evolve", false)), "Eevee at friendship 160 by night must evolve") and ok
	ok = _expect(str(night_check.get("to_slug", "")) == "umbreon", "Eevee by night evolves to umbreon, got " + str(night_check.get("to_slug", ""))) and ok
	var shy: Dictionary = {"species": "Eevee", "name": "Eevee", "level": 10, "friendship": 159, "moves": ["Tackle"]}
	var shy_check: Dictionary = _engine.check_level_up(shy, {"time_of_day": "day"})
	ok = _expect(not bool(shy_check.get("can_evolve", true)), "Eevee below friendship 160 must not evolve") and ok
	# The "happiness" name for the same value works too.
	var happy_alt: Dictionary = {"species": "Eevee", "name": "Eevee", "level": 10, "happiness": 160, "moves": ["Tackle"]}
	var alt_check: Dictionary = _engine.check_level_up(happy_alt, {"time_of_day": "day"})
	ok = _expect(bool(alt_check.get("can_evolve", false)), "Eevee with happiness 160 by day must evolve") and ok
	return ok


# Test 4 (rewritten for Riley's 2026-11-22 design decision):
# Machoke's trade row names no held item, so it also evolves on
# a level-up at level 30 (TRADE_LEVEL_UP_LEVEL), and a Linking
# Cord evolves it at any level. At level 29 it does not evolve.
# An unrelated stone still does nothing. check_trade itself
# never evolves, and now reports needs_trade_rule false with a
# note naming the Linking Cord and the level-up branch.
func test_machoke_trade_branches() -> bool:
	var ok: bool = true
	var young: Dictionary = {"species": "Machoke", "name": "Machoke", "level": 29, "moves": ["Karate Chop"]}
	var young_check: Dictionary = _engine.check_level_up(young)
	ok = _expect(not bool(young_check.get("can_evolve", true)), "Machoke at level 29 must not evolve on a level-up check") and ok
	var grown: Dictionary = {"species": "Machoke", "name": "Machoke", "level": 30, "moves": ["Karate Chop"]}
	var grown_check: Dictionary = _engine.check_level_up(grown)
	ok = _expect(bool(grown_check.get("can_evolve", false)), "Machoke at level 30 must evolve on a level-up check") and ok
	ok = _expect(str(grown_check.get("to_slug", "")) == "machamp", "Machoke at 30 evolves to machamp, got " + str(grown_check.get("to_slug", ""))) and ok
	var cord_mon: Dictionary = {"species": "Machoke", "name": "Machoke", "level": 10, "moves": ["Karate Chop"]}
	var cord_check: Dictionary = _engine.check_use_item(cord_mon, "linking-cord")
	ok = _expect(bool(cord_check.get("can_evolve", false)), "Machoke with a Linking Cord at level 10 must evolve") and ok
	ok = _expect(str(cord_check.get("to_slug", "")) == "machamp", "Machoke with a Linking Cord evolves to machamp, got " + str(cord_check.get("to_slug", ""))) and ok
	var stone_check: Dictionary = _engine.check_use_item(cord_mon, "Thunder Stone")
	ok = _expect(not bool(stone_check.get("can_evolve", true)), "Machoke must not evolve with a Thunder Stone") and ok
	var trade_check: Dictionary = _engine.check_trade(grown)
	ok = _expect(not bool(trade_check.get("can_evolve", true)), "check_trade must never say can_evolve") and ok
	ok = _expect(not bool(trade_check.get("needs_trade_rule", true)), "check_trade must report needs_trade_rule false") and ok
	ok = _expect(str(trade_check.get("blocked", "")) == "trade", "check_trade must report blocked trade, got " + str(trade_check.get("blocked", ""))) and ok
	ok = _expect(str(trade_check.get("to_slug", "")) == "machamp", "Machoke trade row points to machamp, got " + str(trade_check.get("to_slug", ""))) and ok
	ok = _expect(str(trade_check.get("note", "")).find("Linking Cord") >= 0, "check_trade note must name the Linking Cord") and ok
	return ok


# Test 5: Onix's trade row names the Metal Coat, so the held
# item is the gate: holding it, Onix evolves on a level-up at
# any level; the plain level-30 branch does NOT apply to a
# held-item row, and a Linking Cord without the coat does
# nothing.
func test_onix_held_item_trade_branch() -> bool:
	var ok: bool = true
	var coated: Dictionary = {"species": "Onix", "name": "Onix", "level": 12, "item": "Metal Coat", "moves": ["Tackle"]}
	var coated_check: Dictionary = _engine.check_level_up(coated)
	ok = _expect(bool(coated_check.get("can_evolve", false)), "Onix holding a Metal Coat must evolve on a level-up at level 12") and ok
	ok = _expect(str(coated_check.get("to_slug", "")) == "steelix", "Onix evolves to steelix, got " + str(coated_check.get("to_slug", ""))) and ok
	var bare: Dictionary = {"species": "Onix", "name": "Onix", "level": 10, "moves": ["Tackle"]}
	var cord_check: Dictionary = _engine.check_use_item(bare, "linking-cord")
	ok = _expect(not bool(cord_check.get("can_evolve", true)), "Onix with a Linking Cord but no Metal Coat must not evolve") and ok
	var bare_grown: Dictionary = {"species": "Onix", "name": "Onix", "level": 30, "moves": ["Tackle"]}
	var grown_check: Dictionary = _engine.check_level_up(bare_grown)
	ok = _expect(not bool(grown_check.get("can_evolve", true)), "Onix at level 30 without the Metal Coat must not evolve (held-item row)") and ok
	return ok


# Test 6: Seadra's trade row names the Dragon Scale. Holding
# it, Seadra evolves both with a Linking Cord and on a level-up
# at any level.
func test_seadra_dragon_scale_branches() -> bool:
	var ok: bool = true
	var seadra: Dictionary = {"species": "Seadra", "name": "Seadra", "level": 5, "item": "dragon-scale", "moves": ["Bubble"]}
	var cord_check: Dictionary = _engine.check_use_item(seadra, "linking-cord")
	ok = _expect(bool(cord_check.get("can_evolve", false)), "Seadra holding a Dragon Scale must evolve with a Linking Cord") and ok
	ok = _expect(str(cord_check.get("to_slug", "")) == "kingdra", "Seadra evolves to kingdra, got " + str(cord_check.get("to_slug", ""))) and ok
	var level_check: Dictionary = _engine.check_level_up(seadra)
	ok = _expect(bool(level_check.get("can_evolve", false)), "Seadra holding a Dragon Scale must evolve on a level-up at any level") and ok
	ok = _expect(str(level_check.get("to_slug", "")) == "kingdra", "Seadra on level-up evolves to kingdra, got " + str(level_check.get("to_slug", ""))) and ok
	return ok


# Test 7: Inkay's row is level-up at 30 with turn_upside_down.
# Riley's branch drops only that one condition: at 30 Inkay
# evolves with an empty context and with the flag set; at 29 it
# does not evolve either way.
func test_inkay_upside_down_branch() -> bool:
	var ok: bool = true
	var inkay: Dictionary = {"species": "Inkay", "name": "Inkay", "level": 30, "moves": ["Peck"]}
	var plain_check: Dictionary = _engine.check_level_up(inkay)
	ok = _expect(bool(plain_check.get("can_evolve", false)), "Inkay at 30 with no upside-down context must evolve") and ok
	ok = _expect(str(plain_check.get("to_slug", "")) == "malamar", "Inkay evolves to malamar, got " + str(plain_check.get("to_slug", ""))) and ok
	var flipped_check: Dictionary = _engine.check_level_up(inkay, {"turn_upside_down": true})
	ok = _expect(bool(flipped_check.get("can_evolve", false)), "Inkay at 30 turned upside down must evolve") and ok
	var young: Dictionary = {"species": "Inkay", "name": "Inkay", "level": 29, "moves": ["Peck"]}
	var young_check: Dictionary = _engine.check_level_up(young, {"turn_upside_down": true})
	ok = _expect(not bool(young_check.get("can_evolve", true)), "Inkay at 29 must not evolve") and ok
	return ok


# Test 8: Kadabra (trade row, no held item) evolves on a
# level-up at 30, and Meltan's meltan-candies row also evolves
# on a level-up at 30.
func test_kadabra_and_meltan_level_30() -> bool:
	var ok: bool = true
	var kadabra: Dictionary = {"species": "Kadabra", "name": "Kadabra", "level": 30, "moves": ["Confusion"]}
	var kadabra_check: Dictionary = _engine.check_level_up(kadabra)
	ok = _expect(bool(kadabra_check.get("can_evolve", false)), "Kadabra at level 30 must evolve on a level-up check") and ok
	ok = _expect(str(kadabra_check.get("to_slug", "")) == "alakazam", "Kadabra evolves to alakazam, got " + str(kadabra_check.get("to_slug", ""))) and ok
	var meltan: Dictionary = {"species": "Meltan", "name": "Meltan", "level": 30, "moves": ["Thunder Shock"]}
	var meltan_check: Dictionary = _engine.check_level_up(meltan)
	ok = _expect(bool(meltan_check.get("can_evolve", false)), "Meltan at level 30 must evolve on a level-up check") and ok
	ok = _expect(str(meltan_check.get("to_slug", "")) == "melmetal", "Meltan evolves to melmetal, got " + str(meltan_check.get("to_slug", ""))) and ok
	var young_meltan: Dictionary = {"species": "Meltan", "name": "Meltan", "level": 29, "moves": ["Thunder Shock"]}
	var young_check: Dictionary = _engine.check_level_up(young_meltan)
	ok = _expect(not bool(young_check.get("can_evolve", true)), "Meltan at level 29 must not evolve") and ok
	return ok


# Test 9: Basculin's recoil-damage rows need 294 recoil damage
# taken and the right gender (the rows carry gender_id 2 for
# male and 1 for female in their notes). 293 is not enough, a
# missing recoil value fails, and 294 evolves to Basculegion.
func test_basculin_recoil() -> bool:
	var ok: bool = true
	var basculin: Dictionary = {"species": "Basculin", "name": "Basculin", "level": 30, "gender": "male", "moves": ["Tackle"]}
	var low_check: Dictionary = _engine.check_special(basculin, {"recoil_damage_taken": 293})
	ok = _expect(not bool(low_check.get("can_evolve", true)), "Basculin with 293 recoil damage must not evolve") and ok
	var hit_check: Dictionary = _engine.check_special(basculin, {"recoil_damage_taken": 294})
	ok = _expect(bool(hit_check.get("can_evolve", false)), "Basculin with 294 recoil damage must evolve") and ok
	ok = _expect(str(hit_check.get("to_slug", "")) == "basculegion", "Basculin evolves to basculegion, got " + str(hit_check.get("to_slug", ""))) and ok
	var missing_check: Dictionary = _engine.check_special(basculin)
	ok = _expect(not bool(missing_check.get("can_evolve", true)), "Basculin with no recoil context must not evolve") and ok
	return ok


# Helper for the shed test: does the bonus list hold a slug?
func _bonus_has(check: Dictionary, slug: String) -> bool:
	var bonus_value: Variant = check.get("bonus_evolutions", [])
	if not (bonus_value is Array):
		return false
	var bonus_list: Array = bonus_value
	for entry_value in bonus_list:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if str(entry.get("to_slug", "")) == slug:
				return true
	return false


# Test 10: Nincada at level 20 evolves to Ninjask, and when the
# context shows a free party slot (party of 5) and a Poke Ball
# in the bag, Shedinja comes along in bonus_evolutions. A full
# party, a bag with no Poke Ball, or no party/bag context at
# all means Ninjask only.
func test_nincada_shed_bonus() -> bool:
	var ok: bool = true
	var nincada: Dictionary = {"species": "Nincada", "name": "Nincada", "level": 20, "moves": ["Scratch"]}
	var party_five: Array = [{"species": "A"}, {"species": "B"}, {"species": "C"}, {"species": "D"}, {"species": "E"}]
	var shed_check: Dictionary = _engine.check_level_up(nincada, {"party": party_five, "bag": ["poke-ball"]})
	ok = _expect(bool(shed_check.get("can_evolve", false)), "Nincada at 20 must evolve") and ok
	ok = _expect(str(shed_check.get("to_slug", "")) == "ninjask", "Nincada evolves to ninjask, got " + str(shed_check.get("to_slug", ""))) and ok
	ok = _expect(_bonus_has(shed_check, "shedinja"), "with a free slot and a Poke Ball, bonus_evolutions must hold shedinja") and ok
	var party_six: Array = party_five.duplicate()
	party_six.append({"species": "F"})
	var full_check: Dictionary = _engine.check_level_up(nincada, {"party": party_six, "bag": ["poke-ball"]})
	ok = _expect(bool(full_check.get("can_evolve", false)), "Nincada at 20 with a full party must still evolve to Ninjask") and ok
	ok = _expect(not _bonus_has(full_check, "shedinja"), "with a full party there must be no shedinja bonus") and ok
	var no_ball_check: Dictionary = _engine.check_level_up(nincada, {"party": party_five, "bag": ["great-ball"]})
	ok = _expect(not _bonus_has(no_ball_check, "shedinja"), "with no Poke Ball in the bag there must be no shedinja bonus") and ok
	var bare_check: Dictionary = _engine.check_level_up(nincada)
	ok = _expect(bool(bare_check.get("can_evolve", false)), "Nincada at 20 with no context must still evolve to Ninjask") and ok
	ok = _expect(not _bonus_has(bare_check, "shedinja"), "with no party/bag context there must be no shedinja bonus") and ok
	return ok


# Test 11: Kubfu's tower rows run through check_special with
# the scroll named in the context: scroll-of-darkness and
# scroll-of-waters both lead to Urshifu, and no scroll means no
# evolution. The older use-item path with a scroll also works.
func test_kubfu_towers_and_scrolls() -> bool:
	var ok: bool = true
	var kubfu: Dictionary = {"species": "Kubfu", "name": "Kubfu", "level": 10, "moves": ["Rock Smash"]}
	var dark_check: Dictionary = _engine.check_special(kubfu, {"scroll_used": "scroll-of-darkness"})
	ok = _expect(bool(dark_check.get("can_evolve", false)), "Kubfu with scroll-of-darkness used must evolve") and ok
	ok = _expect(str(dark_check.get("to_slug", "")) == "urshifu", "Kubfu evolves to urshifu, got " + str(dark_check.get("to_slug", ""))) and ok
	var waters_check: Dictionary = _engine.check_special(kubfu, {"scroll_used": "scroll-of-waters"})
	ok = _expect(bool(waters_check.get("can_evolve", false)), "Kubfu with scroll-of-waters used must evolve") and ok
	ok = _expect(str(waters_check.get("to_slug", "")) == "urshifu", "Kubfu with the waters scroll evolves to urshifu, got " + str(waters_check.get("to_slug", ""))) and ok
	var none_check: Dictionary = _engine.check_special(kubfu)
	ok = _expect(not bool(none_check.get("can_evolve", true)), "Kubfu with no scroll in the context must not evolve") and ok
	var item_check: Dictionary = _engine.check_use_item(kubfu, "scroll-of-darkness")
	ok = _expect(bool(item_check.get("can_evolve", false)), "Kubfu must evolve through check_use_item with scroll-of-darkness") and ok
	ok = _expect(str(item_check.get("to_slug", "")) == "urshifu", "Kubfu through the scroll item evolves to urshifu, got " + str(item_check.get("to_slug", ""))) and ok
	return ok


# Test 12: Milcery's spin. Holding a Strawberry Sweet and
# spinning clockwise (SPIN_DIR 0, the documented convention)
# for 3 seconds by day gives Alcremie, Vanilla Cream form with
# the Strawberry decoration. A longer spin (7 seconds) matches
# the >= 5 row instead and gives Matcha Cream. Holding no Sweet
# fails, and missing spin context fails.
func test_milcery_spin_forms() -> bool:
	var ok: bool = true
	var milcery: Dictionary = {"species": "Milcery", "name": "Milcery", "level": 10, "item": "strawberry-sweet", "moves": ["Tackle"]}
	var short_check: Dictionary = _engine.check_special(milcery, {"time_of_day": "day", "spin_dir": 0, "spin_seconds": 3})
	ok = _expect(bool(short_check.get("can_evolve", false)), "Milcery spinning 3 seconds by day must evolve") and ok
	ok = _expect(str(short_check.get("to_slug", "")) == "alcremie", "Milcery evolves to alcremie, got " + str(short_check.get("to_slug", ""))) and ok
	ok = _expect(str(short_check.get("form", "")) == "Vanilla Cream", "day clockwise short spin form must be Vanilla Cream, got " + str(short_check.get("form", ""))) and ok
	ok = _expect(str(short_check.get("form_detail", "")) == "Vanilla Cream (Strawberry decoration)", "form_detail must name the Strawberry decoration, got " + str(short_check.get("form_detail", ""))) and ok
	var long_check: Dictionary = _engine.check_special(milcery, {"time_of_day": "day", "spin_dir": 0, "spin_seconds": 7})
	ok = _expect(bool(long_check.get("can_evolve", false)), "Milcery spinning 7 seconds by day must evolve") and ok
	ok = _expect(str(long_check.get("form", "")) == "Matcha Cream", "day clockwise long spin form must be Matcha Cream, got " + str(long_check.get("form", ""))) and ok
	var no_sweet: Dictionary = {"species": "Milcery", "name": "Milcery", "level": 10, "item": "metal-coat", "moves": ["Tackle"]}
	var no_sweet_check: Dictionary = _engine.check_special(no_sweet, {"time_of_day": "day", "spin_dir": 0, "spin_seconds": 3})
	ok = _expect(not bool(no_sweet_check.get("can_evolve", true)), "Milcery holding no Sweet must not evolve") and ok
	var missing_check: Dictionary = _engine.check_special(milcery, {"time_of_day": "day"})
	ok = _expect(not bool(missing_check.get("can_evolve", true)), "Milcery with no spin context must not evolve") and ok
	return ok


# Test 13: apply_evolution returns a NEW mon dict. The input mon
# keeps its species and gains no new keys; the new mon is a
# Gyarados with the same level and the same moves, and it records
# where it came from.
func test_apply_evolution_keeps_input() -> bool:
	var ok: bool = true
	var magikarp: Dictionary = {"species": "Magikarp", "name": "Magikarp", "level": 20, "exp": 1234, "moves": ["Splash", "Tackle"], "hp": 30, "max_hp": 40}
	var check: Dictionary = _engine.check_level_up(magikarp)
	ok = _expect(bool(check.get("can_evolve", false)), "level 20 Magikarp must pass the check before applying") and ok
	var row_value: Variant = check.get("row", {})
	if not (row_value is Dictionary):
		return _expect(false, "check result carries no row dict")
	var row: Dictionary = row_value
	var evolved: Dictionary = _engine.apply_evolution(magikarp, row)
	ok = _expect(str(magikarp.get("species", "")) == "Magikarp", "input mon species must stay Magikarp") and ok
	ok = _expect(not magikarp.has("evolved_from"), "input mon must not gain evolved_from") and ok
	ok = _expect(str(evolved.get("species", "")) == "Gyarados", "new mon species must be Gyarados, got " + str(evolved.get("species", ""))) and ok
	ok = _expect(str(evolved.get("name", "")) == "Gyarados", "new mon name must be Gyarados, got " + str(evolved.get("name", ""))) and ok
	ok = _expect(str(evolved.get("evolved_from", "")) == "magikarp", "evolved_from must be magikarp, got " + str(evolved.get("evolved_from", ""))) and ok
	ok = _expect(int(evolved.get("level", 0)) == 20, "level must carry over at 20") and ok
	ok = _expect(int(evolved.get("exp", 0)) == 1234, "exp must carry over") and ok
	var moves_value: Variant = evolved.get("moves", [])
	var moves_ok: bool = moves_value is Array and (moves_value as Array).size() == 2 and str((moves_value as Array)[0]) == "Splash"
	ok = _expect(moves_ok, "moves must carry over unchanged") and ok
	ok = _expect(int(evolved.get("hp", 0)) == 30, "current hp must carry over at 30") and ok
	return ok


# Test 14: on_level_up is the hook the game calls after a level
# gain. A Magikarp that just reached level 20 comes back evolved
# with the new mon inside the answer; one at level 19 comes back
# not evolved and unchanged.
func test_on_level_up_hook() -> bool:
	var ok: bool = true
	var grown: Dictionary = {"species": "Magikarp", "name": "Magikarp", "level": 20, "moves": ["Splash"]}
	var grown_result: Dictionary = _engine.on_level_up(grown)
	ok = _expect(bool(grown_result.get("evolved", false)), "on_level_up must evolve a level 20 Magikarp") and ok
	ok = _expect(str(grown_result.get("to_slug", "")) == "gyarados", "on_level_up to_slug must be gyarados") and ok
	var new_mon_value: Variant = grown_result.get("mon", {})
	if new_mon_value is Dictionary:
		var new_mon: Dictionary = new_mon_value
		ok = _expect(str(new_mon.get("species", "")) == "Gyarados", "the returned mon must be a Gyarados") and ok
	else:
		ok = _expect(false, "on_level_up must return the new mon dict") and ok
	ok = _expect(str(grown.get("species", "")) == "Magikarp", "on_level_up must not change the input mon") and ok
	var young: Dictionary = {"species": "Magikarp", "name": "Magikarp", "level": 19, "moves": ["Splash"]}
	var young_result: Dictionary = _engine.on_level_up(young)
	ok = _expect(not bool(young_result.get("evolved", true)), "on_level_up must not evolve a level 19 Magikarp") and ok
	return ok


# Test 15: display names are cleaned to slugs the battle
# controller's way, and the known-move condition is honored.
# "Mime Jr." must find the mime-jr rows; its level-up row needs
# the move Mimic and leads to Mr. Mime (slug mr-mime). Without
# Mimic there is no evolution; with Mimic stored as a move dict
# there is.
func test_display_name_and_known_move() -> bool:
	var ok: bool = true
	var rows: Array = _engine.evolutions_for("Mime Jr.")
	ok = _expect(not rows.is_empty(), "evolutions_for must find rows for the display name Mime Jr.") and ok
	var no_move: Dictionary = {"species": "Mime Jr.", "name": "Mime Jr.", "level": 10, "moves": ["Pound"]}
	var no_move_check: Dictionary = _engine.check_level_up(no_move)
	ok = _expect(not bool(no_move_check.get("can_evolve", true)), "Mime Jr. without Mimic must not evolve") and ok
	var with_move: Dictionary = {"species": "Mime Jr.", "name": "Mime Jr.", "level": 10, "moves": [{"name": "Mimic"}]}
	var with_move_check: Dictionary = _engine.check_level_up(with_move)
	ok = _expect(bool(with_move_check.get("can_evolve", false)), "Mime Jr. with Mimic must evolve") and ok
	ok = _expect(str(with_move_check.get("to_slug", "")) == "mr-mime", "Mime Jr. evolves to mr-mime, got " + str(with_move_check.get("to_slug", ""))) and ok
	return ok
