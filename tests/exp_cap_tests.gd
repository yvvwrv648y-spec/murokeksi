extends SceneTree
## Headless tests for the Pokemon Ultimate World hard badge
## level caps (battle engine, EXP system).
##
## The code under test is EXPSystem.level_cap_for_badges /
## EXPSystem.BADGE_LEVEL_CAPS (battle/exp_system.gd) and the
## enforcement inside BattleController._give_exp
## (battle/battle_controller.gd).
##
## The cap table is transcribed from the RC1 formats doc,
## docs/PUW_BATTLE_FORMATS_GIMMICKS_AND_CAPS.json, key
## "hard_badge_level_caps_zero_disobedience":
##   0 badges -> 10, 1 -> 20, 2 -> 24, 3 -> 29, 4 -> 40,
##   5 -> 43, 6 -> 47, 7 -> 50, 8 -> 100.
## The cap is a HARD STOP on the level only: EXP points keep
## accruing in mon["exp"], a mon's level is never lowered, and
## there are no disobedience mechanics.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/exp_cap_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.
##
## Layering checked here: the cap applies only when a badge
## count is supplied — through set_badge_count() or through a
## "badges" value in the controller's field_state. With no
## count supplied at all, no cap applies (the engine standalone
## has no badge concept until the game/campaign supplies one).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW hard badge level cap tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/exp_cap_tests.gd")
		quit(1)
		return
	_run("test_cap_table", Callable(self, "test_cap_table"))
	_run("test_zero_badges_clamps_to_10", Callable(self, "test_zero_badges_clamps_to_10"))
	_run("test_field_state_badges_clamp", Callable(self, "test_field_state_badges_clamp"))
	_run("test_eight_badges_grow_past_50", Callable(self, "test_eight_badges_grow_past_50"))
	_run("test_eight_badges_reach_100", Callable(self, "test_eight_badges_reach_100"))
	_run("test_no_badge_count_no_cap", Callable(self, "test_no_badge_count_no_cap"))
	print("PUW hard badge level cap tests — done: %d passed, %d failed." % [_passed, _failed])
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


## A BattleController that is in the tree, so its _ready() has
## run and its MoveDatabase is loaded. Same construction as
## battle_tests.gd's _new_controller(). Freeing is not needed:
## quit() ends the run right after the tests.
func _new_controller() -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	return controller


## One test Pokemon, as a plain dict, in the total-EXP style
## _give_exp expects: "exp" holds TOTAL EXP and "exp_is_total"
## is true. The growth rate is set on the mon itself so
## BattleController._growth_rate_for resolves it directly.
func _mon(mon_name: String, growth_rate: String, level: int) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": level, "hp": 100, "max_hp": 100,
		"atk": 100, "def": 50, "spa": 100, "spd": 50, "spe": 100,
		"types": ["normal"], "ability": "", "item": "", "status": "",
		"moves": ["Tackle"],
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
		"growth_rate": growth_rate,
		"exp": EXPSystem.exp_for_level(growth_rate, level),
		"exp_is_total": true,
	}
	return mon


# Test 1: the cap table itself. level_cap_for_badges returns
# exactly 10/20/24/29/40/43/47/50/100 for 0..8 badges, and 100
# for a count past 8.
func test_cap_table() -> bool:
	var ok: bool = true
	var expected: Array = [10, 20, 24, 29, 40, 43, 47, 50, 100]
	for badges in range(0, 9):
		var cap: int = EXPSystem.level_cap_for_badges(badges)
		ok = _expect(cap == int(expected[badges]), "cap for %d badges must be %d, got %d" % [badges, int(expected[badges]), cap]) and ok
	ok = _expect(EXPSystem.level_cap_for_badges(12) == 100, "cap for 12 badges must be 100, got %d" % EXPSystem.level_cap_for_badges(12)) and ok
	return ok


# Test 2: at 0 badges (cap 10) a level 9 mon given a huge
# amount of EXP stops at exactly level 10. The EXP points
# still accrue in full — only the level is clamped — and the
# clamp log line is written. Bulbasaur is used because it
# does not evolve until level 16, so the evolution hook
# stays quiet at the cap.
func test_zero_badges_clamps_to_10() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	c.set_badge_count(0)
	var mon: Dictionary = _mon("Bulbasaur", "medium-slow", 9)
	var start_exp: int = int(mon.get("exp", 0))
	var logs: Array = []
	c._give_exp(mon, 1000000, logs)
	ok = _expect(int(mon.get("level", 0)) == 10, "level must stop at exactly 10, got %d" % int(mon.get("level", 0))) and ok
	ok = _expect(int(mon.get("exp", 0)) == start_exp + 1000000, "EXP must accrue in full past the cap, got %d" % int(mon.get("exp", 0))) and ok
	ok = _expect(_logs_have(logs, "can't grow past level 10"), "the clamp log line must be written, logs: " + str(logs)) and ok
	return ok


## True when any log line contains the given text. (Checking
## str(logs) instead would miss apostrophes: the array's
## string form escapes them.)
func _logs_have(logs: Array, needle: String) -> bool:
	for line_value in logs:
		if str(line_value).find(needle) >= 0:
			return true
	return false


# Test 3: the field_state route. No set_badge_count call, but
# a "badges" value of 0 in field_state supplies the count, so
# the same clamp to level 10 applies.
func test_field_state_badges_clamp() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	c.field_state["badges"] = 0
	var mon: Dictionary = _mon("Bulbasaur", "medium-slow", 9)
	var logs: Array = []
	c._give_exp(mon, 1000000, logs)
	ok = _expect(int(mon.get("level", 0)) == 10, "field_state badges 0 must clamp the level to 10, got %d" % int(mon.get("level", 0))) and ok
	return ok


# Test 4: at 8 badges (cap 100) a level 50 mon gains levels
# past 50. Snorlax is used because it never evolves, so the
# evolution hook stays quiet. The EXP given is exactly the
# slow-curve distance from level 50 to level 60.
func test_eight_badges_grow_past_50() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	c.set_badge_count(8)
	var mon: Dictionary = _mon("Snorlax", "slow", 50)
	var amount: int = EXPSystem.exp_for_level("slow", 60) - EXPSystem.exp_for_level("slow", 50)
	var logs: Array = []
	c._give_exp(mon, amount, logs)
	ok = _expect(int(mon.get("level", 0)) > 50, "level must pass 50 at 8 badges, got %d" % int(mon.get("level", 0))) and ok
	ok = _expect(int(mon.get("level", 0)) == 60, "level must land on 60, got %d" % int(mon.get("level", 0))) and ok
	return ok


# Test 5: at 8 badges a level 99 mon with enough EXP reaches
# exactly level 100 — the cap and the game maximum agree.
func test_eight_badges_reach_100() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	c.set_badge_count(8)
	var mon: Dictionary = _mon("Snorlax", "slow", 99)
	var logs: Array = []
	c._give_exp(mon, 1000000, logs)
	ok = _expect(int(mon.get("level", 0)) == 100, "level must reach exactly 100, got %d" % int(mon.get("level", 0))) and ok
	return ok


# Test 6: no badge count supplied by either route — the same
# level 9 mon with the same huge EXP passes level 10 freely
# (all the way to 100). This documents the layering: the
# engine standalone has no badge concept until the game or
# campaign supplies the count.
func test_no_badge_count_no_cap() -> bool:
	var ok: bool = true
	var c: BattleController = _new_controller()
	var mon: Dictionary = _mon("Snorlax", "slow", 9)
	var logs: Array = []
	# The slow curve needs 1,250,000 total EXP for level 100,
	# so the amount has to clear that from a level 9 start.
	c._give_exp(mon, 2000000, logs)
	ok = _expect(int(mon.get("level", 0)) > 10, "with no badge count the level must pass 10, got %d" % int(mon.get("level", 0))) and ok
	ok = _expect(int(mon.get("level", 0)) == 100, "with no badge count the level must reach 100, got %d" % int(mon.get("level", 0))) and ok
	ok = _expect(not _logs_have(logs, "can't grow past"), "no clamp log line may appear without a badge count, logs: " + str(logs)) and ok
	return ok
