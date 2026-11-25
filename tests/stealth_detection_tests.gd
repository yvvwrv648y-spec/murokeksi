extends SceneTree
## Stealth detection tests (canon audit gap G2 wiring prep).
## Run: godot --headless --script res://tests/stealth_detection_tests.gd
##
## Fixture trainer: tile (10,10), facing RIGHT, sight_range 5
## (built through PUWSpawner.trainer_dict_from_placement, the
## same shape live play uses). The "documented ranges" below
## are the source controller's numbers applied to sight 5:
## sneak effective sight 5 * 0.35 = 1.75, walk 5.0, run 7.25,
## bike_mach 9.5; noise radii (design constant 4.0 tiles per
## 1.0 level): sneak 0.0, walk 1.8, run 3.4, bikes 4.0.
##
## A: the ported tables match the source controller verbatim.
## B: sight channel — sneak past undetected, walk detected on
##    the same path, run detected farther, blocked tiles still
##    block, original check_sight untouched.
## C: noise channel — heard from behind inside the radius,
##    silent while sneaking at any distance.
## D: the old gates hold — no-sight and sight-0 trainers never
##    detect through either channel.

const Spawner = preload("res://systems/overworld/spawner.gd")
const PlayerController = preload("res://systems/overworld/player_controller.gd")

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _trainer(sight: int, has_sight: bool) -> Dictionary:
	var placement: Dictionary = {
		"map": "PrepRoute",
		"x_tiles": 10,
		"y_tiles": 10,
		"direction": "RIGHT",
		"class": "YOUNGSTER",
		"party_index": 0,
		"text_id": "",
		"sprite": "",
	}
	if has_sight:
		placement["sight_range"] = sight
	return Spawner.trainer_dict_from_placement(placement)


func _detect(pc: Node, trainer: Dictionary, tile: Vector2i, mode: String, is_blocked: Callable = Callable()) -> bool:
	pc.current_mode = mode
	return Spawner.check_detection(trainer, tile, pc.current_detection_mult(), pc.current_noise(), is_blocked)


func _init() -> void:
	var pc: Node = PlayerController.new()
	var trainer: Dictionary = _trainer(5, true)

	# --- A: tables faithful to the source controller ---
	_check("A1 noise sneak == 0.00", _approx(pc.noise_for_mode("sneak"), 0.00))
	_check("A2 noise walk == 0.45", _approx(pc.noise_for_mode("walk"), 0.45))
	_check("A3 noise run == 0.85", _approx(pc.noise_for_mode("run"), 0.85))
	_check("A4 noise bike_acro == 1.00", _approx(pc.noise_for_mode("bike_acro"), 1.00))
	_check("A5 noise bike_mach == 1.00", _approx(pc.noise_for_mode("bike_mach"), 1.00))
	_check("A6 mult sneak == 0.35", _approx(pc.detection_mult_for_mode("sneak"), 0.35))
	_check("A7 mult walk == 1.00", _approx(pc.detection_mult_for_mode("walk"), 1.00))
	_check("A8 mult run == 1.45", _approx(pc.detection_mult_for_mode("run"), 1.45))
	_check("A9 mult bike_acro == 1.75", _approx(pc.detection_mult_for_mode("bike_acro"), 1.75))
	_check("A10 mult bike_mach == 1.90", _approx(pc.detection_mult_for_mode("bike_mach"), 1.90))
	_check("A11 speed sneak still 2.2", _approx(pc.speed_for_mode("sneak"), 2.2))
	pc.current_mode = "sneak"
	_check("A12 current accessors follow current_mode", _approx(pc.current_noise(), 0.0) and _approx(pc.current_detection_mult(), 0.35))
	_check("A13 resolve_mode bike beats sneak", PlayerController.resolve_mode(true, "mach", true, false, false) == "bike_mach")
	_check("A14 resolve_mode acro default gear", PlayerController.resolve_mode(true, "", false, false, false) == "bike_acro")
	_check("A15 resolve_mode sneak beats run", PlayerController.resolve_mode(false, "", true, true, false) == "sneak")
	_check("A16 resolve_mode run", PlayerController.resolve_mode(false, "", false, true, false) == "run")
	_check("A17 resolve_mode auto_run", PlayerController.resolve_mode(false, "", false, false, true) == "run")
	_check("A18 resolve_mode walk", PlayerController.resolve_mode(false, "", false, false, false) == "walk")

	# --- B: sight channel on a path in front of the trainer ---
	# Path tiles at distance 2, 3, 4 in the facing line.
	for raw_x in [12, 13, 14]:
		var x: int = int(raw_x)
		var tile: Vector2i = Vector2i(x, 10)
		_check("B sneak past at dist %d undetected" % (x - 10), not _detect(pc, trainer, tile, "sneak"))
		_check("B walk at dist %d detected" % (x - 10), _detect(pc, trainer, tile, "walk"))
	_check("B sneak adjacent (dist 1) IS seen", _detect(pc, trainer, Vector2i(11, 10), "sneak"))
	_check("B walk at dist 7 not detected", not _detect(pc, trainer, Vector2i(17, 10), "walk"))
	_check("B run at dist 7 detected (farther)", _detect(pc, trainer, Vector2i(17, 10), "run"))
	_check("B run at dist 8 not detected", not _detect(pc, trainer, Vector2i(18, 10), "run"))
	_check("B bike_mach at dist 9 detected", _detect(pc, trainer, Vector2i(19, 10), "bike_mach"))
	_check("B walk at dist 9 not detected", not _detect(pc, trainer, Vector2i(19, 10), "walk"))
	var blocked: Callable = func(t: Vector2i) -> bool:
		return t == Vector2i(12, 10)
	_check("B blocked tile still blocks walk sight at dist 3", not _detect(pc, trainer, Vector2i(13, 10), "walk", blocked))
	_check("B regression: plain check_sight dist 4 true", Spawner.check_sight(trainer, Vector2i(14, 10)))
	_check("B regression: plain check_sight dist 6 false", not Spawner.check_sight(trainer, Vector2i(16, 10)))

	# --- C: noise channel (player BEHIND the trainer) ---
	_check("C walk behind dist 1 heard (sight alone false)", not Spawner.check_sight_stealth(trainer, Vector2i(9, 10), 1.0) and _detect(pc, trainer, Vector2i(9, 10), "walk"))
	_check("C walk behind dist 2 not heard (radius 1.8)", not _detect(pc, trainer, Vector2i(8, 10), "walk"))
	_check("C sneak behind dist 1 silent", not _detect(pc, trainer, Vector2i(9, 10), "sneak"))
	_check("C run behind dist 3 heard (radius 3.4)", _detect(pc, trainer, Vector2i(7, 10), "run"))
	_check("C walk behind dist 3 not heard", not _detect(pc, trainer, Vector2i(7, 10), "walk"))
	_check("C radius sneak == 0.0", _approx(Spawner.noise_radius_tiles(0.0), 0.0))
	_check("C radius walk == 1.8", _approx(Spawner.noise_radius_tiles(0.45), 1.8))
	_check("C radius run == 3.4", _approx(Spawner.noise_radius_tiles(0.85), 3.4))
	_check("C radius bike == 4.0", _approx(Spawner.noise_radius_tiles(1.0), 4.0))

	# --- D: gates preserved ---
	var no_sight: Dictionary = _trainer(-1, false)
	_check("D no-sight trainer never detects (run, adjacent)", not _detect(pc, no_sight, Vector2i(11, 10), "run"))
	var zero_sight: Dictionary = _trainer(0, true)
	_check("D sight-0 trainer never detects (run, adjacent)", not _detect(pc, zero_sight, Vector2i(11, 10), "run"))
	_check("D effective range sneak == 1.75", _approx(Spawner.effective_sight_range(trainer, 0.35), 1.75))
	_check("D effective range run == 7.25", _approx(Spawner.effective_sight_range(trainer, 1.45), 7.25))
	_check("D effective range no-sight == 0.0", _approx(Spawner.effective_sight_range(no_sight, 1.45), 0.0))

	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	pc.free()
	quit(1 if _failed > 0 else 0)
