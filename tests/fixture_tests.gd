extends SceneTree
## Zero-move safety rule — fixture suite, run in test_project_fixture.
## The fixture data is the real data cut down to six Water species
## (verbatim entries), with the "keldeo" learnset DELIBERATELY absent:
## keldeoordinary is in the dex with no set and, in this fixture, no
## reachable learnset — a forced zero-move fill candidate even with
## the patched resolver. The fill must skip it, log the skip in
## last_fill_skips, and return the honest short team (base + the
## four sound fillers = 5) instead of dealing a mon that cannot act.
## Run: godot --headless --path test_project_fixture --script res://tests/fixture_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW zero-move fixture tests — starting.")
	_run("fixture_really_forces_zero_move", Callable(self, "fixture_really_forces_zero_move"))
	_run("fill_skips_and_logs_forced_zero_move", Callable(self, "fill_skips_and_logs_forced_zero_move"))
	_run("skip_is_shuffle_independent", Callable(self, "skip_is_shuffle_independent"))
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = bool(test.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _rng(seed_val: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_val
	return r


## Premise check: in the fixture, keldeoordinary itself still builds
## with zero moves — so any clean team came from the safety rule,
## not from the candidate secretly having moves.
func fixture_really_forces_zero_move() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var mon: Dictionary = builder.build_mon("keldeoordinary", 50, "singles")
	var moves: Variant = mon.get("moves", [])
	if not (moves is Array):
		print("  moves field is not an Array")
		return false
	if not (moves as Array).is_empty():
		print("  fixture premise broken: keldeoordinary has moves " + str(moves))
		return false
	return true


func fill_skips_and_logs_forced_zero_move() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var team: Array = builder.build_trainer_team(["blastoise"], 50, "singles", _rng(42))
	if team.size() != 5:
		print("  expected the honest short team of 5, got " + str(team.size()))
		return false
	for mon_v in team:
		var mon: Dictionary = mon_v
		if str(mon.get("species_slug", "")) == "keldeoordinary":
			print("  keldeoordinary was dealt into the team")
			return false
		var moves: Variant = mon.get("moves", [])
		if not (moves is Array) or (moves as Array).is_empty():
			print("  team contains a zero-move mon: " + str(mon.get("species_slug", "")))
			return false
	if builder.last_fill_skips.size() != 1:
		print("  expected exactly 1 logged skip, got " + str(builder.last_fill_skips))
		return false
	var skip: Variant = builder.last_fill_skips[0]
	if not (skip is Dictionary):
		print("  skip record is not a Dictionary")
		return false
	if str((skip as Dictionary).get("slug", "")) != "keldeoordinary":
		print("  skip record names the wrong slug: " + str(skip))
		return false
	if str((skip as Dictionary).get("reason", "")) != "zero_moves":
		print("  skip record has the wrong reason: " + str(skip))
		return false
	return true


func skip_is_shuffle_independent() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	for seed_val in [1, 7, 99, 12345]:
		var team: Array = builder.build_trainer_team(["blastoise"], 50, "singles", _rng(seed_val))
		if team.size() != 5:
			print("  seed " + str(seed_val) + ": team size " + str(team.size()))
			return false
		if builder.last_fill_skips.size() != 1:
			print("  seed " + str(seed_val) + ": skips " + str(builder.last_fill_skips))
			return false
		for mon_v in team:
			var moves: Variant = (mon_v as Dictionary).get("moves", [])
			if not (moves is Array) or (moves as Array).is_empty():
				print("  seed " + str(seed_val) + ": zero-move mon dealt")
				return false
	return true
