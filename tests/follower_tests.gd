extends SceneTree
## Headless tests for the Pokemon Ultimate World follower
## system (PUWFollowerController).
##
## The controller under test is PUWFollowerController
## (puw_follower_controller.gd), merged at
## res://systems/followers/puw_follower_controller.gd, reading
## the seed locomotion data at
## res://systems/followers/follower_locomotion.json.
## (It does not replace the existing FollowerController
## Node3D at res://systems/followers/follower_controller.gd.)
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/follower_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW follower tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/follower_tests.gd")
		quit(1)
		return
	_run("test_select_three_followers", Callable(self, "test_select_three_followers"))
	_run("test_select_seven_refused", Callable(self, "test_select_seven_refused"))
	_run("test_registered_locomotion", Callable(self, "test_registered_locomotion"))
	_run("test_unregistered_default_locomotion", Callable(self, "test_unregistered_default_locomotion"))
	_run("test_trailing_positions", Callable(self, "test_trailing_positions"))
	print("PUW follower tests — done: %d passed, %d failed." % [_passed, _failed])
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


# Test 1: selecting 3 followers from a party tracks exactly
# 3 records, in the chosen order, with trail offsets 1, 2, 3.
func test_select_three_followers() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = [
		{"name": "Pikachu", "species": "Pikachu"},
		{"name": "Bulbasaur", "species": "Bulbasaur"},
		{"name": "Pidgey", "species": "Pidgey"},
		{"name": "Rattata", "species": "Rattata"},
	]
	var result: Dictionary = controller.select_followers(party, [0, 2, 3])
	ok = _expect(bool(result.get("ok", false)), "selecting 3 followers must succeed") and ok
	var followers: Array = controller.get_followers()
	ok = _expect(followers.size() == 3, "exactly 3 follower records must be tracked, got " + str(followers.size())) and ok
	if followers.size() == 3:
		var first: Dictionary = followers[0]
		var second: Dictionary = followers[1]
		var third: Dictionary = followers[2]
		ok = _expect(str(first.get("slug", "")) == "pikachu", "first follower must be pikachu, got " + str(first.get("slug", ""))) and ok
		ok = _expect(str(second.get("slug", "")) == "pidgey", "second follower must be pidgey, got " + str(second.get("slug", ""))) and ok
		ok = _expect(str(third.get("slug", "")) == "rattata", "third follower must be rattata, got " + str(third.get("slug", ""))) and ok
		ok = _expect(int(first.get("trail_offset", 0)) == 1, "first trail_offset must be 1") and ok
		ok = _expect(int(second.get("trail_offset", 0)) == 2, "second trail_offset must be 2") and ok
		ok = _expect(int(third.get("trail_offset", 0)) == 3, "third trail_offset must be 3") and ok
	controller.free()
	return ok


# Test 2: selecting 7 followers is refused: the party has 7
# members and all 7 indices are chosen, but the cap is 6.
func test_select_seven_refused() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = []
	for i in range(7):
		party.append({"name": "Mon" + str(i), "species": "Mon" + str(i)})
	var result: Dictionary = controller.select_followers(party, [0, 1, 2, 3, 4, 5, 6])
	ok = _expect(not bool(result.get("ok", true)), "selecting 7 followers must be refused") and ok
	ok = _expect(str(result.get("reason", "")).length() > 0, "a refusal must carry a reason") and ok
	ok = _expect(controller.get_followers().is_empty(), "a refused selection must track no followers") and ok
	controller.free()
	return ok


# Test 3: a registered species uses its registered locomotion
# class from the seed data: Pikachu (PKDX) is "ground_agile"
# and Pidgey (PKDX) is "flying_avian".
func test_registered_locomotion() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = [
		{"name": "Pikachu", "species": "Pikachu"},
		{"name": "Pidgey", "species": "Pidgey"},
	]
	var result: Dictionary = controller.select_followers(party, [0, 1])
	ok = _expect(bool(result.get("ok", false)), "selecting Pikachu and Pidgey must succeed") and ok
	var followers: Array = controller.get_followers()
	if followers.size() == 2:
		var pikachu: Dictionary = followers[0]
		var pidgey: Dictionary = followers[1]
		ok = _expect(str(pikachu.get("locomotion", "")) == "ground_agile", "Pikachu locomotion must be ground_agile, got " + str(pikachu.get("locomotion", ""))) and ok
		ok = _expect(str(pidgey.get("locomotion", "")) == "flying_avian", "Pidgey locomotion must be flying_avian, got " + str(pidgey.get("locomotion", ""))) and ok
	else:
		ok = _expect(false, "expected exactly 2 follower records") and ok
	controller.free()
	return ok


# Test 4: an unregistered species gets the labeled placeholder
# default: Bulbasaur has no register entry, so its locomotion
# is "ground_follow".
func test_unregistered_default_locomotion() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = [
		{"name": "Bulbasaur", "species": "Bulbasaur"},
	]
	var result: Dictionary = controller.select_followers(party, [0])
	ok = _expect(bool(result.get("ok", false)), "selecting Bulbasaur must succeed") and ok
	var followers: Array = controller.get_followers()
	if followers.size() == 1:
		var bulbasaur: Dictionary = followers[0]
		ok = _expect(str(bulbasaur.get("locomotion", "")) == "ground_follow", "Bulbasaur locomotion must be the ground_follow placeholder, got " + str(bulbasaur.get("locomotion", ""))) and ok
	else:
		ok = _expect(false, "expected exactly 1 follower record") and ok
	controller.free()
	return ok


# Test 5: after the player walks east step by step, the 3
# followers occupy 3 distinct trailing positions behind the
# player, in order: the first follower is closest to the
# player, the third is furthest back.
func test_trailing_positions() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = [
		{"name": "Pikachu", "species": "Pikachu"},
		{"name": "Pidgey", "species": "Pidgey"},
		{"name": "Rattata", "species": "Rattata"},
	]
	var result: Dictionary = controller.select_followers(party, [0, 1, 2])
	ok = _expect(bool(result.get("ok", false)), "selecting 3 followers must succeed") and ok
	# Walk east: one recorded position per step, 16 units apart.
	for step in range(10):
		controller.record_player_position(Vector2(float(step) * 16.0, 0.0))
	var positions: Array = controller.follower_positions()
	ok = _expect(positions.size() == 3, "3 followers must give 3 positions, got " + str(positions.size())) and ok
	if positions.size() == 3:
		var first_pos: Vector2 = positions[0]
		var second_pos: Vector2 = positions[1]
		var third_pos: Vector2 = positions[2]
		ok = _expect(first_pos != second_pos and second_pos != third_pos and first_pos != third_pos, "the 3 follower positions must be distinct") and ok
		# Player's newest position is (144, 0); followers trail
		# 1, 2 and 3 steps back: (128, 0), (112, 0), (96, 0).
		ok = _expect(first_pos == Vector2(128.0, 0.0), "first follower must stand 1 step back at (128, 0), got " + str(first_pos)) and ok
		ok = _expect(second_pos == Vector2(112.0, 0.0), "second follower must stand 2 steps back at (112, 0), got " + str(second_pos)) and ok
		ok = _expect(third_pos == Vector2(96.0, 0.0), "third follower must stand 3 steps back at (96, 0), got " + str(third_pos)) and ok
		ok = _expect(first_pos.x > second_pos.x and second_pos.x > third_pos.x, "followers must be ordered behind the player, closest first") and ok
	controller.free()
	return ok
