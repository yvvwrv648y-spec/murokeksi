class_name PUWBattleTestsV5
extends SceneTree
## Headless test runner for the Pokemon Ultimate World battle
## engine v5 (the 374 flagged moves fix).
##
## Run it in Godot 4.7 (headless, no game window needed) with:
##   godot --headless --script res://battle/battle_tests_v5.gd
## (from the project folder, with this file saved at
## res://battle/battle_tests_v5.gd, the battle_controller.gd and
## move_effects.gd from the v3 pack overlaid (they carry the v5
## wiring), and the v5 data files at
## res://data/move_database_954.json, res://data/weight_power.json
## and res://data/base_atk.json, plus variable_power.gd and
## move_database_loader.gd in res://battle/.)
##
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW battle engine v5 tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://battle/battle_tests_v5.gd")
		quit(1)
		return
	_run("test_v5_loader_counts", Callable(self, "test_v5_loader_counts"))
	_run("test_v5_loader_damage_rules", Callable(self, "test_v5_loader_damage_rules"))
	_run("test_v5_loader_always_hits", Callable(self, "test_v5_loader_always_hits"))
	_run("test_v5_loader_multihit", Callable(self, "test_v5_loader_multihit"))
	_run("test_v5_loader_flags_preserved", Callable(self, "test_v5_loader_flags_preserved"))
	_run("test_v5_loader_volatile_boosts", Callable(self, "test_v5_loader_volatile_boosts"))
	_run("test_v5_loader_field_markers", Callable(self, "test_v5_loader_field_markers"))
	_run("test_v5_weight_power", Callable(self, "test_v5_weight_power"))
	_run("test_v5_weight_ratio_power", Callable(self, "test_v5_weight_ratio_power"))
	_run("test_v5_gyro_ball_power", Callable(self, "test_v5_gyro_ball_power"))
	_run("test_v5_electro_ball_power", Callable(self, "test_v5_electro_ball_power"))
	_run("test_v5_flail_power", Callable(self, "test_v5_flail_power"))
	_run("test_v5_crush_grip_power", Callable(self, "test_v5_crush_grip_power"))
	_run("test_v5_fixed_damage", Callable(self, "test_v5_fixed_damage"))
	_run("test_v5_level_damage", Callable(self, "test_v5_level_damage"))
	_run("test_v5_fraction_damage", Callable(self, "test_v5_fraction_damage"))
	_run("test_v5_ohko_damage", Callable(self, "test_v5_ohko_damage"))
	_run("test_v5_counter_damage", Callable(self, "test_v5_counter_damage"))
	_run("test_v5_friendship_power", Callable(self, "test_v5_friendship_power"))
	_run("test_v5_frustration_power", Callable(self, "test_v5_frustration_power"))
	_run("test_v5_fling_natural_gift", Callable(self, "test_v5_fling_natural_gift"))
	_run("test_v5_bide_damage", Callable(self, "test_v5_bide_damage"))
	_run("test_v5_endeavor_final_gambit", Callable(self, "test_v5_endeavor_final_gambit"))
	_run("test_v5_magnitude", Callable(self, "test_v5_magnitude"))
	_run("test_v5_present", Callable(self, "test_v5_present"))
	_run("test_v5_psywave", Callable(self, "test_v5_psywave"))
	_run("test_v5_spit_up_trump_card", Callable(self, "test_v5_spit_up_trump_card"))
	_run("test_v5_beat_up_punishment", Callable(self, "test_v5_beat_up_punishment"))
	_run("test_v5_resolver_weight", Callable(self, "test_v5_resolver_weight"))
	_run("test_v5_resolver_fixed", Callable(self, "test_v5_resolver_fixed"))
	_run("test_v5_resolver_level", Callable(self, "test_v5_resolver_level"))
	_run("test_v5_resolver_fraction", Callable(self, "test_v5_resolver_fraction"))
	_run("test_v5_resolver_ohko", Callable(self, "test_v5_resolver_ohko"))
	_run("test_v5_resolver_counter_fails", Callable(self, "test_v5_resolver_counter_fails"))
	_run("test_v5_resolver_counter_hits", Callable(self, "test_v5_resolver_counter_hits"))
	_run("test_v5_resolver_bide", Callable(self, "test_v5_resolver_bide"))
	_run("test_v5_resolver_endeavor", Callable(self, "test_v5_resolver_endeavor"))
	_run("test_v5_resolver_trump_card", Callable(self, "test_v5_resolver_trump_card"))
	_run("test_v5_resolver_beat_up", Callable(self, "test_v5_resolver_beat_up"))
	_run("test_v5_resolver_punishment", Callable(self, "test_v5_resolver_punishment"))
	_run("test_v5_resolver_magnitude_present", Callable(self, "test_v5_resolver_magnitude_present"))
	_run("test_v5_protect_first_use_always_succeeds", Callable(self, "test_v5_protect_first_use_always_succeeds"))
	_run("test_v5_protect_consecutive_use_can_fail", Callable(self, "test_v5_protect_consecutive_use_can_fail"))
	_run("test_v5_protect_counter_ladder", Callable(self, "test_v5_protect_counter_ladder"))
	_run("test_v5_protect_counter_resets_after_other_move", Callable(self, "test_v5_protect_counter_resets_after_other_move"))
	_run("test_v5_stall_counter_shared_with_detect", Callable(self, "test_v5_stall_counter_shared_with_detect"))
	_run("test_v5_fling_table_power", Callable(self, "test_v5_fling_table_power"))
	_run("test_v5_fling_table_effects", Callable(self, "test_v5_fling_table_effects"))
	_run("test_v5_natural_gift_table", Callable(self, "test_v5_natural_gift_table"))
	_run("test_v5_mega_weight_lookup", Callable(self, "test_v5_mega_weight_lookup"))
	print("PUW battle engine v5 tests — done: %d passed, %d failed." % [_passed, _failed])
	if not _failed_names.is_empty():
		print("Failed tests: %s" % ", ".join(_failed_names))
	quit(1)
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = test.call()
	if ok:
		_passed += 1
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: %s" % test_name)


func _mon(mon_name: String, types: Array, moves: Array, extra: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": 50, "hp": 100, "max_hp": 100,
		"atk": 100, "def": 50, "spa": 200, "spd": 50, "spe": 100,
		"types": types, "ability": "", "item": "", "status": "",
		"moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for key in extra.keys():
		mon[key] = extra[key]
	return mon


func _new_controller() -> BattleController:
	var c: BattleController = BattleController.new()
	root.add_child(c)
	return c


func _load_v5() -> Dictionary:
	return MoveDatabaseLoader.load_official("res://data/move_database_954.json")


func test_v5_loader_counts() -> bool:
	var res: Dictionary = _load_v5()
	if int(res.get("total", -1)) != 954:
		print("  loader total was %s, wanted 954." % str(res.get("total", -1)))
		return false
	if int(res.get("mapped_clean", -1)) != 954:
		print("  loader mapped_clean was %s, wanted 954." % str(res.get("mapped_clean", -1)))
		return false
	var notes: Array = res.get("needs_attention", [])
	if not notes.is_empty():
		print("  loader needs_attention was not empty: %s" % str(notes.slice(0, 3)))
		return false
	return true


func test_v5_loader_damage_rules() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var want: Dictionary = {"weight": 2, "weight_ratio": 2, "gyro_ball": 1, "electro_ball": 1, "low_hp": 2, "target_hp": 3, "fixed": 2, "level": 2, "fraction": 4, "ohko": 4, "counter": 4, "friendship": 4, "item": 2, "bide": 1, "endeavor": 1, "final_gambit": 1, "magnitude": 1, "present": 1, "psywave": 1, "spit_up": 1, "trump_card": 1, "beat_up": 1, "punishment": 1}
	var got: Dictionary = {}
	for key in moves.keys():
		var m: Dictionary = moves[key]
		var rule: String = str(m.get("damage_rule", ""))
		if rule != "":
			got[rule] = int(got.get(rule, 0)) + 1
			if rule == "unknown":
				print("  move %s has damage_rule unknown." % str(key))
				return false
	var total: int = 0
	for rule in got.keys():
		total += int(got[rule])
	if total != 43:
		print("  damage_rule moves total %s, wanted 43." % str(total))
		return false
	for rule in want.keys():
		if int(got.get(rule, 0)) != int(want[rule]):
			print("  damage_rule %s count %s, wanted %s." % [rule, str(got.get(rule, 0)), str(want[rule])])
			return false
	return true


func test_v5_loader_always_hits() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var count: int = 0
	for key in moves.keys():
		if bool(Dictionary(moves[key]).get("always_hits", false)):
			count += 1
	if count != 303:
		print("  always_hits moves %s, wanted 303." % str(count))
		return false
	var swift: Dictionary = moves.get("swift", {})
	if not bool(swift.get("always_hits", false)) or int(swift.get("power", -1)) != 60:
		print("  Swift always_hits/power wrong: %s" % str(swift))
		return false
	return true


func test_v5_loader_multihit() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var count: int = 0
	for key in moves.keys():
		if Dictionary(moves[key]).has("multihit"):
			count += 1
	if count != 31:
		print("  multihit moves %s, wanted 31." % str(count))
		return false
	var seed: Dictionary = moves.get("bulletseed", {})
	if int(seed.get("power", -1)) != 25:
		print("  Bullet Seed power %s, wanted 25 (per hit)." % str(seed.get("power", -1)))
		return false
	var mh: Array = seed.get("multihit", [])
	if mh.size() != 2 or int(mh[0]) != 2 or int(mh[1]) != 5:
		print("  Bullet Seed multihit %s, wanted [2, 5]." % str(mh))
		return false
	return true


func test_v5_loader_flags_preserved() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var with_flags: int = 0
	var contact: int = 0
	for key in moves.keys():
		var m: Dictionary = moves[key]
		if m.has("flags"):
			with_flags += 1
			if bool(Dictionary(m.get("flags", {})).get("contact", false)):
				contact += 1
	if with_flags != 867:
		print("  moves with flags %s, wanted 867." % str(with_flags))
		return false
	if contact != 278:
		print("  contact moves %s, wanted 278." % str(contact))
		return false
	var tackle: Dictionary = moves.get("tackle", {})
	if not bool(Dictionary(tackle.get("flags", {})).get("contact", false)):
		print("  Tackle has no contact flag.")
		return false
	return true


func test_v5_loader_volatile_boosts() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var swagger: Dictionary = moves.get("swagger", {})
	if str(swagger.get("volatileStatus", "")) != "confusion":
		print("  Swagger volatileStatus %s, wanted confusion." % str(swagger.get("volatileStatus", "")))
		return false
	var sw_boosts: Dictionary = swagger.get("boosts", {})
	if int(sw_boosts.get("atk", -9)) != 2:
		print("  Swagger boosts atk %s, wanted 2." % str(sw_boosts.get("atk", -9)))
		return false
	var dance: Dictionary = moves.get("swordsdance", {})
	var d_boosts: Dictionary = dance.get("boosts", {})
	if int(d_boosts.get("atk", -9)) != 2:
		print("  Swords Dance boosts atk %s, wanted 2." % str(d_boosts.get("atk", -9)))
		return false
	var protect: Dictionary = moves.get("protect", {})
	if str(protect.get("volatileStatus", "")) != "protect":
		print("  Protect volatileStatus %s, wanted protect." % str(protect.get("volatileStatus", "")))
		return false
	var vs_count: int = 0
	var b_count: int = 0
	for key in moves.keys():
		var m: Dictionary = moves[key]
		if m.has("volatileStatus"):
			vs_count += 1
		if m.has("boosts"):
			b_count += 1
	if vs_count != 73:
		print("  volatileStatus moves %s, wanted 73." % str(vs_count))
		return false
	if b_count != 72:
		print("  boosts moves %s, wanted 72." % str(b_count))
		return false
	return true


func test_v5_loader_field_markers() -> bool:
	var res: Dictionary = _load_v5()
	var moves: Dictionary = res.get("moves", {})
	var tailwind: Dictionary = moves.get("tailwind", {})
	if str(tailwind.get("sideCondition", "")) != "tailwind":
		print("  Tailwind sideCondition %s, wanted tailwind." % str(tailwind.get("sideCondition", "")))
		return false
	var trick: Dictionary = moves.get("trickroom", {})
	if str(trick.get("pseudoWeather", "")) != "trickroom":
		print("  Trick Room pseudoWeather %s, wanted trickroom." % str(trick.get("pseudoWeather", "")))
		return false
	var sc: int = 0
	var pw: int = 0
	for key in moves.keys():
		var m: Dictionary = moves[key]
		if m.has("sideCondition"):
			sc += 1
		if m.has("pseudoWeather"):
			pw += 1
	if sc != 15:
		print("  sideCondition moves %s, wanted 15." % str(sc))
		return false
	if pw != 9:
		print("  pseudoWeather moves %s, wanted 9." % str(pw))
		return false
	return true


func test_v5_weight_power() -> bool:
	var cases: Array = [[2000, 120], [4600, 120], [1000, 100], [1500, 100], [500, 80], [700, 80], [250, 60], [300, 60], [100, 40], [150, 40], [99, 20], [69, 20], [0, 20]]
	for pair in cases:
		var got: int = VariablePower.weight_power(int(pair[0]))
		if got != int(pair[1]):
			print("  weight_power(%s) was %s, wanted %s." % [str(pair[0]), str(got), str(pair[1])])
			return false
	return true


func test_v5_weight_ratio_power() -> bool:
	var cases: Array = [[500, 100, 120], [400, 100, 100], [300, 100, 80], [200, 100, 60], [150, 100, 40], [100, 100, 40], [100, 0, 40], [0, 100, 40]]
	for pair in cases:
		var got: int = VariablePower.weight_ratio_power(int(pair[0]), int(pair[1]))
		if got != int(pair[2]):
			print("  weight_ratio_power(%s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(got), str(pair[2])])
			return false
	return true


func test_v5_gyro_ball_power() -> bool:
	var cases: Array = [[100, 100, 26], [50, 200, 101], [10, 100, 150], [200, 50, 7], [0, 100, 150], [100, 0, 1]]
	for pair in cases:
		var got: int = VariablePower.gyro_ball_power(int(pair[0]), int(pair[1]))
		if got != int(pair[2]):
			print("  gyro_ball_power(%s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(got), str(pair[2])])
			return false
	return true


func test_v5_electro_ball_power() -> bool:
	var cases: Array = [[50, 100, 40], [100, 100, 60], [200, 100, 80], [300, 100, 120], [400, 100, 150], [500, 100, 150], [100, 0, 150]]
	for pair in cases:
		var got: int = VariablePower.electro_ball_power(int(pair[0]), int(pair[1]))
		if got != int(pair[2]):
			print("  electro_ball_power(%s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(got), str(pair[2])])
			return false
	return true


func test_v5_flail_power() -> bool:
	var cases: Array = [[100, 100, 20], [70, 100, 20], [50, 100, 40], [33, 100, 80], [20, 100, 100], [10, 100, 150], [1, 100, 200], [0, 100, 200], [100, 0, 20]]
	for pair in cases:
		var got: int = VariablePower.flail_power(int(pair[0]), int(pair[1]))
		if got != int(pair[2]):
			print("  flail_power(%s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(got), str(pair[2])])
			return false
	return true


func test_v5_crush_grip_power() -> bool:
	var cases: Array = [[100, 100, 120, 120], [50, 100, 120, 60], [1, 100, 120, 1], [0, 100, 120, 1], [100, 100, 100, 100], [50, 100, 100, 50], [100, 0, 120, 1]]
	for pair in cases:
		var got: int = VariablePower.crush_grip_power(int(pair[0]), int(pair[1]), int(pair[2]))
		if got != int(pair[3]):
			print("  crush_grip_power(%s, %s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(pair[2]), str(got), str(pair[3])])
			return false
	return true


func test_v5_fixed_damage() -> bool:
	if VariablePower.dragon_rage_damage() != 40:
		print("  Dragon Rage damage was %s, wanted 40." % str(VariablePower.dragon_rage_damage()))
		return false
	if VariablePower.sonic_boom_damage() != 20:
		print("  Sonic Boom damage was %s, wanted 20." % str(VariablePower.sonic_boom_damage()))
		return false
	return true


func test_v5_level_damage() -> bool:
	if VariablePower.level_damage(50) != 50:
		print("  level_damage(50) was %s, wanted 50." % str(VariablePower.level_damage(50)))
		return false
	if VariablePower.level_damage(100) != 100:
		print("  level_damage(100) was %s, wanted 100." % str(VariablePower.level_damage(100)))
		return false
	if VariablePower.level_damage(0) != 0:
		print("  level_damage(0) was %s, wanted 0." % str(VariablePower.level_damage(0)))
		return false
	return true


func test_v5_fraction_damage() -> bool:
	var cases: Array = [[100, 1, 2, 50], [1, 1, 2, 1], [0, 1, 2, 1], [100, 3, 4, 75], [99, 3, 4, 74], [100, 1, 2, 50]]
	for pair in cases:
		var got: int = VariablePower.fraction_damage(int(pair[0]), int(pair[1]), int(pair[2]))
		if got != int(pair[3]):
			print("  fraction_damage(%s, %s, %s) was %s, wanted %s." % [str(pair[0]), str(pair[1]), str(pair[2]), str(got), str(pair[3])])
			return false
	if VariablePower.fraction_damage(100, 1, 0) != 1:
		print("  fraction_damage with den 0 was not 1.")
		return false
	return true


func test_v5_ohko_damage() -> bool:
	if VariablePower.ohko_damage(100) != 100:
		print("  ohko_damage(100) was %s, wanted 100." % str(VariablePower.ohko_damage(100)))
		return false
	if VariablePower.ohko_damage(0) != 1:
		print("  ohko_damage(0) was %s, wanted 1." % str(VariablePower.ohko_damage(0)))
		return false
	return true


func test_v5_counter_damage() -> bool:
	if VariablePower.counter_damage(50, 2, 1, true) != 100:
		print("  Counter 2x of 50 was %s, wanted 100." % str(VariablePower.counter_damage(50, 2, 1, true)))
		return false
	if VariablePower.counter_damage(50, 3, 2, true) != 75:
		print("  Metal Burst 1.5x of 50 was %s, wanted 75." % str(VariablePower.counter_damage(50, 3, 2, true)))
		return false
	if VariablePower.counter_damage(50, 2, 1, false) != 0:
		print("  Counter with no stored hit was %s, wanted 0." % str(VariablePower.counter_damage(50, 2, 1, false)))
		return false
	if VariablePower.counter_damage(0, 2, 1, true) != 1:
		print("  Counter with 0 stored damage was %s, wanted 1." % str(VariablePower.counter_damage(0, 2, 1, true)))
		return false
	return true


func test_v5_friendship_power() -> bool:
	var cases: Array = [[255, 102], [128, 51], [70, 28], [0, 1], [300, 102], [-5, 1]]
	for pair in cases:
		var got: int = VariablePower.friendship_power(int(pair[0]))
		if got != int(pair[1]):
			print("  friendship_power(%s) was %s, wanted %s." % [str(pair[0]), str(got), str(pair[1])])
			return false
	return true


func test_v5_frustration_power() -> bool:
	var cases: Array = [[0, 102], [128, 50], [70, 74], [255, 1], [300, 1], [-5, 102]]
	for pair in cases:
		var got: int = VariablePower.frustration_power(int(pair[0]))
		if got != int(pair[1]):
			print("  frustration_power(%s) was %s, wanted %s." % [str(pair[0]), str(got), str(pair[1])])
			return false
	return true


func test_v5_fling_natural_gift() -> bool:
	if VariablePower.fling_power(0) != 0:
		print("  fling_power(0) was not 0 (no item must fail).")
		return false
	if VariablePower.fling_power(80) != 80:
		print("  fling_power(80) was %s, wanted 80." % str(VariablePower.fling_power(80)))
		return false
	if VariablePower.natural_gift_power(100) != 100:
		print("  natural_gift_power(100) was %s, wanted 100." % str(VariablePower.natural_gift_power(100)))
		return false
	if VariablePower.natural_gift_type("") != "Normal":
		print("  natural_gift_type('') was %s, wanted Normal." % VariablePower.natural_gift_type(""))
		return false
	if VariablePower.natural_gift_type("Dragon") != "Dragon":
		print("  natural_gift_type('Dragon') was %s, wanted Dragon." % VariablePower.natural_gift_type("Dragon"))
		return false
	return true


func test_v5_bide_damage() -> bool:
	if VariablePower.bide_damage(50) != 100:
		print("  bide_damage(50) was %s, wanted 100." % str(VariablePower.bide_damage(50)))
		return false
	if VariablePower.bide_damage(0) != 0:
		print("  bide_damage(0) was %s, wanted 0." % str(VariablePower.bide_damage(0)))
		return false
	if VariablePower.bide_damage(-5) != 0:
		print("  bide_damage(-5) was %s, wanted 0." % str(VariablePower.bide_damage(-5)))
		return false
	return true


func test_v5_endeavor_final_gambit() -> bool:
	if VariablePower.endeavor_damage(100, 30) != 70:
		print("  endeavor_damage(100, 30) was %s, wanted 70." % str(VariablePower.endeavor_damage(100, 30)))
		return false
	if VariablePower.endeavor_damage(30, 100) != 0:
		print("  endeavor_damage(30, 100) was %s, wanted 0." % str(VariablePower.endeavor_damage(30, 100)))
		return false
	if VariablePower.final_gambit_damage(75) != 75:
		print("  final_gambit_damage(75) was %s, wanted 75." % str(VariablePower.final_gambit_damage(75)))
		return false
	if VariablePower.final_gambit_damage(0) != 0:
		print("  final_gambit_damage(0) was %s, wanted 0." % str(VariablePower.final_gambit_damage(0)))
		return false
	return true


func test_v5_magnitude() -> bool:
	var cases: Array = [[0, 10, 4], [4, 10, 4], [5, 30, 5], [14, 30, 5], [15, 50, 6], [34, 50, 6], [35, 70, 7], [64, 70, 7], [65, 90, 8], [84, 90, 8], [85, 110, 9], [94, 110, 9], [95, 150, 10], [99, 150, 10]]
	for pair in cases:
		var got_p: int = VariablePower.magnitude_power(int(pair[0]))
		var got_n: int = VariablePower.magnitude_number(int(pair[0]))
		if got_p != int(pair[1]) or got_n != int(pair[2]):
			print("  magnitude roll %s gave power %s number %s, wanted %s / %s." % [str(pair[0]), str(got_p), str(got_n), str(pair[1]), str(pair[2])])
			return false
	return true


func test_v5_present() -> bool:
	if not VariablePower.present_heals(0) or not VariablePower.present_heals(1):
		print("  Present rolls 0-1 must heal.")
		return false
	if VariablePower.present_heals(2):
		print("  Present roll 2 must not heal.")
		return false
	var cases: Array = [[2, 40], [5, 40], [6, 80], [8, 80], [9, 120], [0, 0], [1, 0]]
	for pair in cases:
		var got: int = VariablePower.present_power(int(pair[0]))
		if got != int(pair[1]):
			print("  present_power(%s) was %s, wanted %s." % [str(pair[0]), str(got), str(pair[1])])
			return false
	if VariablePower.present_heal_amount(100) != 25:
		print("  present_heal_amount(100) was %s, wanted 25." % str(VariablePower.present_heal_amount(100)))
		return false
	if VariablePower.present_heal_amount(3) != 1:
		print("  present_heal_amount(3) was %s, wanted 1." % str(VariablePower.present_heal_amount(3)))
		return false
	return true


func test_v5_psywave() -> bool:
	if VariablePower.psywave_damage(50, 100) != 50:
		print("  psywave_damage(50, 100) was %s, wanted 50." % str(VariablePower.psywave_damage(50, 100)))
		return false
	if VariablePower.psywave_damage(50, 50) != 25:
		print("  psywave_damage(50, 50) was %s, wanted 25." % str(VariablePower.psywave_damage(50, 50)))
		return false
	if VariablePower.psywave_damage(50, 150) != 75:
		print("  psywave_damage(50, 150) was %s, wanted 75." % str(VariablePower.psywave_damage(50, 150)))
		return false
	if VariablePower.psywave_damage(0, 100) != 0:
		print("  psywave_damage(0, 100) was %s, wanted 0." % str(VariablePower.psywave_damage(0, 100)))
		return false
	return true


func test_v5_spit_up_trump_card() -> bool:
	if VariablePower.spit_up_power(0) != 0:
		print("  spit_up_power(0) was not 0 (no Stockpile must fail).")
		return false
	if VariablePower.spit_up_power(1) != 100:
		print("  spit_up_power(1) was %s, wanted 100." % str(VariablePower.spit_up_power(1)))
		return false
	if VariablePower.spit_up_power(3) != 300:
		print("  spit_up_power(3) was %s, wanted 300." % str(VariablePower.spit_up_power(3)))
		return false
	var cases: Array = [[1, 200], [2, 80], [3, 60], [4, 50], [5, 40], [10, 40], [0, 200]]
	for pair in cases:
		var got: int = VariablePower.trump_card_power(int(pair[0]))
		if got != int(pair[1]):
			print("  trump_card_power(%s) was %s, wanted %s." % [str(pair[0]), str(got), str(pair[1])])
			return false
	return true


func test_v5_beat_up_punishment() -> bool:
	if VariablePower.beat_up_power(100) != 15:
		print("  beat_up_power(100) was %s, wanted 15." % str(VariablePower.beat_up_power(100)))
		return false
	if VariablePower.beat_up_power(0) != 5:
		print("  beat_up_power(0) was %s, wanted 5." % str(VariablePower.beat_up_power(0)))
		return false
	if VariablePower.beat_up_power(55) != 10:
		print("  beat_up_power(55) was %s, wanted 10." % str(VariablePower.beat_up_power(55)))
		return false
	if VariablePower.beat_up_hit_count(3) != 3:
		print("  beat_up_hit_count(3) was %s, wanted 3." % str(VariablePower.beat_up_hit_count(3)))
		return false
	if VariablePower.beat_up_hit_count(0) != 0:
		print("  beat_up_hit_count(0) was %s, wanted 0." % str(VariablePower.beat_up_hit_count(0)))
		return false
	if VariablePower.punishment_power(0) != 60:
		print("  punishment_power(0) was %s, wanted 60." % str(VariablePower.punishment_power(0)))
		return false
	if VariablePower.punishment_power(3) != 120:
		print("  punishment_power(3) was %s, wanted 120." % str(VariablePower.punishment_power(3)))
		return false
	if VariablePower.punishment_power(7) != 200:
		print("  punishment_power(7) was %s, wanted 200 (cap)." % str(VariablePower.punishment_power(7)))
		return false
	if VariablePower.punishment_power(10) != 200:
		print("  punishment_power(10) was %s, wanted 200 (cap)." % str(VariablePower.punishment_power(10)))
		return false
	return true


func test_v5_resolver_weight() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Grass Knot"], {})
	var heavy: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	var light: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle"], {})
	c.start_battle([attacker], [heavy], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Grass Knot", "power": 0, "type": "Grass", "cat": "Special", "acc": 100, "damage_rule": "weight"}
	var r_heavy: Dictionary = c._resolve_variable_power(move, attacker, heavy, logs)
	if str(r_heavy.get("kind", "")) != "power" or int(r_heavy.get("power", -1)) != 120:
		print("  Grass Knot vs Snorlax (4600 hg) resolved to %s, wanted power 120." % str(r_heavy))
		return false
	var r_light: Dictionary = c._resolve_variable_power(move, attacker, light, logs)
	if str(r_light.get("kind", "")) != "power" or int(r_light.get("power", -1)) != 20:
		print("  Grass Knot vs Bulbasaur (69 hg) resolved to %s, wanted power 20." % str(r_light))
		return false
	return true


func test_v5_resolver_fixed() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Charizard", ["fire", "flying"], ["Dragon Rage"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Dragon Rage", true, logs, {"power": 0, "type": "Dragon", "cat": "Special", "acc": 100, "damage_rule": "fixed", "rule_amount": 40})
	if int(defender.get("hp", -1)) != 60:
		print("  Dragon Rage left defender at %s HP, wanted 60 (40 flat)." % str(defender.get("hp", -1)))
		return false
	return true


func test_v5_resolver_level() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Seismic Toss"], {"level": 50})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100, "level": 50})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Seismic Toss", true, logs, {"power": 0, "type": "Fighting", "cat": "Physical", "acc": 100, "damage_rule": "level"})
	if int(defender.get("hp", -1)) != 50:
		print("  Seismic Toss left defender at %s HP, wanted 50 (level 50 flat)." % str(defender.get("hp", -1)))
		return false
	return true


func test_v5_resolver_fraction() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Raticate", ["normal"], ["Super Fang"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Super Fang", true, logs, {"power": 0, "type": "Normal", "cat": "Physical", "acc": 90, "damage_rule": "fraction", "rule_num": 1, "rule_den": 2})
	if int(defender.get("hp", -1)) != 50:
		print("  Super Fang left defender at %s HP, wanted 50 (half of 100)." % str(defender.get("hp", -1)))
		return false
	return true


func test_v5_resolver_ohko() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Lapras", ["water", "ice"], ["Fissure"], {"level": 50})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100, "level": 50})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Fissure", "power": 0, "type": "Ground", "cat": "Physical", "acc": 30, "damage_rule": "ohko"}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r.get("kind", "")) != "flat" or int(r.get("damage", -1)) != 100:
		print("  Fissure resolved to %s, wanted flat 100." % str(r))
		return false
	var higher: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100, "level": 60})
	var r2: Dictionary = c._resolve_variable_power(move, attacker, higher, logs)
	if str(r2.get("kind", "")) != "fail":
		print("  Fissure vs a higher-level foe resolved to %s, wanted fail." % str(r2))
		return false
	return true


func test_v5_resolver_counter_fails() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Wobbuffet", ["psychic"], ["Counter"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Counter", "power": 0, "type": "Fighting", "cat": "Physical", "acc": 100, "damage_rule": "counter", "rule_mult_num": 2, "rule_mult_den": 1, "rule_category": "Physical"}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r.get("kind", "")) != "fail":
		print("  Counter with no stored hit resolved to %s, wanted fail." % str(r))
		return false
	return true


func test_v5_resolver_counter_hits() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Wobbuffet", ["psychic"], ["Counter"], {"last_damage_taken": 40, "last_damage_cat": "Physical", "damaged_this_turn": true})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var counter: Dictionary = {"name": "Counter", "power": 0, "type": "Fighting", "cat": "Physical", "acc": 100, "damage_rule": "counter", "rule_mult_num": 2, "rule_mult_den": 1, "rule_category": "Physical"}
	var r: Dictionary = c._resolve_variable_power(counter, attacker, defender, logs)
	if str(r.get("kind", "")) != "flat" or int(r.get("damage", -1)) != 80:
		print("  Counter after a 40 Physical hit resolved to %s, wanted flat 80." % str(r))
		return false
	var coat: Dictionary = {"name": "Mirror Coat", "power": 0, "type": "Psychic", "cat": "Special", "acc": 100, "damage_rule": "counter", "rule_mult_num": 2, "rule_mult_den": 1, "rule_category": "Special"}
	var r2: Dictionary = c._resolve_variable_power(coat, attacker, defender, logs)
	if str(r2.get("kind", "")) != "fail":
		print("  Mirror Coat after a Physical hit resolved to %s, wanted fail." % str(r2))
		return false
	attacker["last_damage_cat"] = "Special"
	var r3: Dictionary = c._resolve_variable_power(coat, attacker, defender, logs)
	if str(r3.get("kind", "")) != "flat" or int(r3.get("damage", -1)) != 80:
		print("  Mirror Coat after a 40 Special hit resolved to %s, wanted flat 80." % str(r3))
		return false
	var burst: Dictionary = {"name": "Metal Burst", "power": 0, "type": "Steel", "cat": "Physical", "acc": 100, "damage_rule": "counter", "rule_mult_num": 3, "rule_mult_den": 2, "rule_category": "any"}
	var r4: Dictionary = c._resolve_variable_power(burst, attacker, defender, logs)
	if str(r4.get("kind", "")) != "flat" or int(r4.get("damage", -1)) != 60:
		print("  Metal Burst after a 40 hit resolved to %s, wanted flat 60 (1.5x)." % str(r4))
		return false
	return true


func test_v5_resolver_bide() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Blastoise", ["water"], ["Bide"], {"hp": 100, "max_hp": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Bide", "power": 0, "type": "Normal", "cat": "Physical", "acc": 100, "damage_rule": "bide"}
	var out1: Dictionary = c._execute_bide(attacker, move, true, logs)
	if not bool(attacker.get("bide_active", false)) or int(attacker.get("bide_turns", -1)) != 2:
		print("  Bide first use did not set up (active %s, turns %s)." % [str(attacker.get("bide_active", false)), str(attacker.get("bide_turns", -1))])
		return false
	attacker["bide_stored"] = 30
	attacker["bide_last_attacker"] = defender
	var out2: Dictionary = c._execute_bide(attacker, move, true, logs)
	if int(attacker.get("bide_turns", -1)) != 1 or int(defender.get("hp", -1)) != 100:
		print("  Bide wait turn wrong (turns %s, defender HP %s)." % [str(attacker.get("bide_turns", -1)), str(defender.get("hp", -1))])
		return false
	var out3: Dictionary = c._execute_bide(attacker, move, true, logs)
	if int(out3.get("damage", -1)) != 60:
		print("  Bide unleash dealt %s, wanted 60 (2x stored 30)." % str(out3.get("damage", -1)))
		return false
	if int(defender.get("hp", -1)) != 40:
		print("  Bide unleash left defender at %s HP, wanted 40." % str(defender.get("hp", -1)))
		return false
	if bool(attacker.get("bide_active", true)):
		print("  Bide was still active after the unleash.")
		return false
	return true


func test_v5_resolver_endeavor() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Raticate", ["normal"], ["Endeavor"], {"hp": 30, "max_hp": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Endeavor", "power": 0, "type": "Normal", "cat": "Physical", "acc": 100, "damage_rule": "endeavor"}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r.get("kind", "")) != "flat" or int(r.get("damage", -1)) != 70:
		print("  Endeavor at 30 HP vs 100 HP resolved to %s, wanted flat 70." % str(r))
		return false
	attacker["hp"] = 100
	var r2: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r2.get("kind", "")) != "fail":
		print("  Endeavor at equal HP resolved to %s, wanted fail." % str(r2))
		return false
	return true


func test_v5_resolver_trump_card() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Trump Card"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Trump Card", "power": 0, "type": "Normal", "cat": "Special", "acc": 100, "damage_rule": "trump_card", "pp_left_at_pick": 1}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r.get("kind", "")) != "power" or int(r.get("power", -1)) != 200:
		print("  Trump Card with 1 PP left resolved to %s, wanted power 200." % str(r))
		return false
	move["pp_left_at_pick"] = 5
	var r2: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r2.get("kind", "")) != "power" or int(r2.get("power", -1)) != 40:
		print("  Trump Card with 5 PP left resolved to %s, wanted power 40." % str(r2))
		return false
	return true


func test_v5_resolver_beat_up() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Beat Up"], {})
	var snorlax: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	var bulbasaur: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle"], {})
	var party: Array = [attacker, snorlax, bulbasaur]
	var defender: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {})
	c.start_battle(party, [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Beat Up", "power": 0, "type": "Dark", "cat": "Physical", "acc": 100, "damage_rule": "beat_up"}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs, party)
	if str(r.get("kind", "")) != "beat_up":
		print("  Beat Up resolved to %s, wanted beat_up." % str(r))
		return false
	if int(r.get("hits", -1)) != 3:
		print("  Beat Up hits %s, wanted 3 (one per able party member)." % str(r.get("hits", -1)))
		return false
	var powers: Array = r.get("powers", [])
	if powers != [10, 16, 9]:
		print("  Beat Up powers %s, wanted [10, 16, 9] (Pikachu 55, Snorlax 110, Bulbasaur 49 base Attack)." % str(powers))
		return false
	return true


func test_v5_resolver_punishment() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Absol", ["dark"], ["Punishment"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"stages": {"atk": 2, "def": 0, "spa": 0, "spd": 0, "spe": 1}})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var move: Dictionary = {"name": "Punishment", "power": 0, "type": "Dark", "cat": "Physical", "acc": 100, "damage_rule": "punishment"}
	var r: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r.get("kind", "")) != "power" or int(r.get("power", -1)) != 120:
		print("  Punishment vs +2 Attack +1 Speed resolved to %s, wanted power 120." % str(r))
		return false
	defender["stages"] = {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var r2: Dictionary = c._resolve_variable_power(move, attacker, defender, logs)
	if str(r2.get("kind", "")) != "power" or int(r2.get("power", -1)) != 60:
		print("  Punishment vs no boosts resolved to %s, wanted power 60." % str(r2))
		return false
	return true


func test_v5_resolver_magnitude_present() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Geodude", ["rock", "ground"], ["Magnitude"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var mag: Dictionary = {"name": "Magnitude", "power": 0, "type": "Ground", "cat": "Physical", "acc": 100, "damage_rule": "magnitude", "v5_roll": 50}
	var r: Dictionary = c._resolve_variable_power(mag, attacker, defender, logs)
	if str(r.get("kind", "")) != "power" or int(r.get("power", -1)) != 70:
		print("  Magnitude roll 50 resolved to %s, wanted power 70." % str(r))
		return false
	var present: Dictionary = {"name": "Present", "power": 0, "type": "Normal", "cat": "Physical", "acc": 90, "damage_rule": "present", "v5_roll": 0}
	var r2: Dictionary = c._resolve_variable_power(present, attacker, defender, logs)
	if str(r2.get("kind", "")) != "heal" or int(r2.get("amount", -1)) != 25:
		print("  Present roll 0 resolved to %s, wanted heal 25." % str(r2))
		return false
	present["v5_roll"] = 9
	var r3: Dictionary = c._resolve_variable_power(present, attacker, defender, logs)
	if str(r3.get("kind", "")) != "power" or int(r3.get("power", -1)) != 120:
		print("  Present roll 9 resolved to %s, wanted power 120." % str(r3))
		return false
	return true


## Protect family (stall counter) tests. The rule is
## Showdown's "stall" volatile (data/conditions.ts): the
## first use in a row always works and starts the counter
## at 3; each later use in a row rolls 1/counter (1/3,
## 1/9, 1/27, ... capped at 1/729); a failed roll ends
## the chain at once; a turn without a stalling move ends
## it too. The seeds below are picked for the first
## randf() draw of a fresh RandomNumberGenerator: seed 14
## draws 0.996 (fails any of these rolls), seed 13 draws
## 0.062 (passes 1/3 and 1/9, fails 1/27), seed 1638
## draws 0.0003 (passes even 1/729). A Protect use makes
## no other draw before the stall roll, so the first
## draw after seeding is the roll itself.

func test_v5_protect_first_use_always_succeeds() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {})
	var foe: Dictionary = _mon("Raticate", ["normal"], ["Tackle"], {})
	c.start_battle([player], [foe], "singles")
	# Seed 14 would fail any stall roll; a first use makes
	# no roll at all, so it still succeeds.
	c.rng.seed = 14
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	if not bool(player.get("protect_active", false)):
		print("  First Protect did not set protect_active.")
		return false
	if str(logs).contains("But it failed!"):
		print("  First Protect logged a failure.")
		return false
	if int(player.get("stall_counter", -1)) != 3:
		print("  First Protect left stall_counter at %s, wanted 3." % str(player.get("stall_counter", -1)))
		return false
	return true


func test_v5_protect_consecutive_use_can_fail() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {})
	var foe: Dictionary = _mon("Raticate", ["normal"], ["Tackle"], {})
	c.start_battle([player], [foe], "singles")
	var logs1: Array = []
	c._execute_move(player, foe, "Protect", true, logs1)
	if not bool(player.get("protect_active", false)):
		print("  First Protect did not set protect_active.")
		return false
	# The turn ends: the Protect flag clears, the chain
	# stays up for one more turn.
	c._clear_protect_flags()
	c._tick_stall_chains()
	if int(player.get("stall_counter", -1)) != 3:
		print("  Chain did not survive the turn: stall_counter %s, wanted 3." % str(player.get("stall_counter", -1)))
		return false
	# Second use in a row, on a seed whose first draw
	# (0.996) beats the 1/3 success chance: the move fails
	# and the chain is deleted at once.
	c.rng.seed = 14
	var logs2: Array = []
	c._execute_move(player, foe, "Protect", true, logs2)
	if not str(logs2).contains("But it failed!"):
		print("  Second Protect in a row did not fail on the failing seed.")
		return false
	if bool(player.get("protect_active", false)):
		print("  Failed Protect still set protect_active.")
		return false
	if int(player.get("stall_counter", -1)) != 0:
		print("  Failed Protect left stall_counter at %s, wanted 0 (chain deleted)." % str(player.get("stall_counter", -1)))
		return false
	# A third use starts a fresh chain, so it succeeds
	# even on the same failing seed.
	c.rng.seed = 14
	var logs3: Array = []
	c._execute_move(player, foe, "Protect", true, logs3)
	if not bool(player.get("protect_active", false)):
		print("  Protect after a failed use did not succeed as a fresh first use.")
		return false
	return true


func test_v5_protect_counter_ladder() -> bool:
	var c: BattleController = _new_controller()
	var mon: Dictionary = {"name": "Testmon", "stall_counter": 0, "stall_used_this_turn": false}
	# First use: no roll, the counter starts at 3.
	if not c._stall_move_succeeds(mon):
		print("  Stall roll failed on a fresh mon.")
		return false
	if int(mon.get("stall_counter", -1)) != 3:
		print("  Counter after first use is %s, wanted 3." % str(mon.get("stall_counter", -1)))
		return false
	# Seed 13 draws 0.062: passes 1/3 (counter 3 -> 9) and
	# 1/9 (counter 9 -> 27), then fails 1/27, which
	# deletes the chain.
	c.rng.seed = 13
	if not c._stall_move_succeeds(mon):
		print("  Stall roll at counter 3 failed on seed 13 (draw 0.062 < 1/3).")
		return false
	if int(mon.get("stall_counter", -1)) != 9:
		print("  Counter after second use is %s, wanted 9." % str(mon.get("stall_counter", -1)))
		return false
	c.rng.seed = 13
	if not c._stall_move_succeeds(mon):
		print("  Stall roll at counter 9 failed on seed 13 (draw 0.062 < 1/9).")
		return false
	if int(mon.get("stall_counter", -1)) != 27:
		print("  Counter after third use is %s, wanted 27." % str(mon.get("stall_counter", -1)))
		return false
	c.rng.seed = 13
	if c._stall_move_succeeds(mon):
		print("  Stall roll at counter 27 passed on seed 13 (draw 0.062 >= 1/27).")
		return false
	if int(mon.get("stall_counter", -1)) != 0:
		print("  Counter after a failed roll is %s, wanted 0." % str(mon.get("stall_counter", -1)))
		return false
	# The cap: counter 243 succeeds on seed 1638 (draw
	# 0.0003 < 1/243) and rises to exactly 729; at 729 a
	# success leaves it at 729, never above (counterMax).
	mon["stall_counter"] = 243
	c.rng.seed = 1638
	if not c._stall_move_succeeds(mon):
		print("  Stall roll at counter 243 failed on seed 1638 (draw 0.0003 < 1/243).")
		return false
	if int(mon.get("stall_counter", -1)) != 729:
		print("  Counter after use at 243 is %s, wanted 729." % str(mon.get("stall_counter", -1)))
		return false
	c.rng.seed = 1638
	if not c._stall_move_succeeds(mon):
		print("  Stall roll at counter 729 failed on seed 1638 (draw 0.0003 < 1/729).")
		return false
	if int(mon.get("stall_counter", -1)) != 729:
		print("  Counter at the cap is %s, wanted 729 (counterMax)." % str(mon.get("stall_counter", -1)))
		return false
	return true


func test_v5_protect_counter_resets_after_other_move() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect", "Tackle"], {})
	var foe: Dictionary = _mon("Raticate", ["normal"], ["Tackle"], {"hp": 200, "max_hp": 200})
	c.start_battle([player], [foe], "singles")
	var logs1: Array = []
	c._execute_move(player, foe, "Protect", true, logs1)
	if int(player.get("stall_counter", -1)) != 3:
		print("  Protect left stall_counter at %s, wanted 3." % str(player.get("stall_counter", -1)))
		return false
	c._clear_protect_flags()
	c._tick_stall_chains()
	# A different move: the chain is not fed this turn.
	var logs2: Array = []
	c._execute_move(player, foe, "Tackle", true, logs2)
	if int(foe.get("hp", -1)) >= 200:
		print("  Tackle dealt no damage; the reset test did not really run a different move.")
		return false
	c._clear_protect_flags()
	c._tick_stall_chains()
	if int(player.get("stall_counter", -1)) != 0:
		print("  Stall counter after a Tackle turn is %s, wanted 0 (chain reset)." % str(player.get("stall_counter", -1)))
		return false
	# Protect now is a fresh first use: it succeeds even
	# on the failing seed, because no roll is made.
	c.rng.seed = 14
	var logs3: Array = []
	c._execute_move(player, foe, "Protect", true, logs3)
	if not bool(player.get("protect_active", false)):
		print("  Protect after the reset did not succeed.")
		return false
	if str(logs3).contains("But it failed!"):
		print("  Protect after the reset logged a failure; the chain was still live.")
		return false
	return true


func test_v5_stall_counter_shared_with_detect() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect", "Detect"], {})
	var foe: Dictionary = _mon("Raticate", ["normal"], ["Tackle"], {})
	c.start_battle([player], [foe], "singles")
	var logs1: Array = []
	c._execute_move(player, foe, "Protect", true, logs1)
	if int(player.get("stall_counter", -1)) != 3:
		print("  Protect left stall_counter at %s, wanted 3." % str(player.get("stall_counter", -1)))
		return false
	c._clear_protect_flags()
	c._tick_stall_chains()
	# Detect shares Protect's counter (Showdown marks
	# both stallingMove: true, and Detect's volatileStatus
	# is "protect"): after a Protect, a Detect is a second
	# consecutive use and fails on the failing seed. The
	# override carries Detect's real v5 data (Status, power
	# 0, Fighting): the controller's built-in 94-move
	# database has no Detect entry and would fall back to a
	# stock damaging move, the same reason the other v5
	# tests pass their move data in.
	var detect_data: Dictionary = {"power": 0, "cat": "Status", "type": "Fighting", "acc": 100}
	c.rng.seed = 14
	var logs2: Array = []
	c._execute_move(player, foe, "Detect", true, logs2, detect_data)
	if not str(logs2).contains("But it failed!"):
		print("  Detect after Protect did not fail; the counter is not shared.")
		return false
	if bool(player.get("protect_active", false)):
		print("  Failed Detect still set protect_active.")
		return false
	# And Detect on its own protects just like Protect.
	c.rng.seed = 14
	var logs3: Array = []
	c._execute_move(player, foe, "Detect", true, logs3, detect_data)
	if not bool(player.get("protect_active", false)):
		print("  Fresh Detect did not set protect_active.")
		return false
	return true


## Fling's power must come from fling_table.json (Showdown
## data/items.ts): Iron Ball is the heaviest fling at 130,
## Light Ball is 30, and with no held item at all Fling fails.
## The table file must be at res://data/fling_table.json.
func test_v5_fling_table_power() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Snorlax", ["normal"], ["Fling"], {"item": "Iron Ball"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var fling: Dictionary = {"name": "Fling", "power": 0, "type": "Dark", "cat": "Physical", "acc": 100, "damage_rule": "item", "rule_kind": "fling"}
	var r: Dictionary = c._resolve_variable_power(fling, attacker, defender, logs)
	if str(r.get("kind", "")) != "power" or int(r.get("power", -1)) != 130:
		print("  Fling with an Iron Ball resolved to %s, wanted power 130 from fling_table.json." % str(r))
		return false
	attacker["item"] = "Light Ball"
	var r2: Dictionary = c._resolve_variable_power(fling, attacker, defender, logs)
	if str(r2.get("kind", "")) != "power" or int(r2.get("power", -1)) != 30:
		print("  Fling with a Light Ball resolved to %s, wanted power 30 from fling_table.json." % str(r2))
		return false
	attacker["item"] = ""
	var r3: Dictionary = c._resolve_variable_power(fling, attacker, defender, logs)
	if str(r3.get("kind", "")) != "fail":
		print("  Fling with no item resolved to %s, wanted fail." % str(r3))
		return false
	return true


## A flung item's table effect must land on the target: a
## Light Ball paralyzes, a King's Rock makes the target
## flinch, and the item is used up either way.
func test_v5_fling_table_effects() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Fling"], {"item": "Light Ball"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([attacker], [defender], "singles")
	c.rng.seed = 7
	var logs: Array = []
	var fling: Dictionary = {"name": "Fling", "power": 0, "type": "Dark", "cat": "Physical", "acc": 100, "damage_rule": "item", "rule_kind": "fling"}
	c._execute_move(attacker, defender, "Fling", true, logs, fling)
	if str(defender.get("status", "")) != "PAR":
		print("  Flung Light Ball left the target's status as '%s', wanted PAR." % str(defender.get("status", "")))
		return false
	if str(attacker.get("item", "")) != "":
		print("  Fling did not use up the Light Ball; item is '%s'." % str(attacker.get("item", "")))
		return false
	var attacker2: Dictionary = _mon("Pikachu", ["electric"], ["Fling"], {"item": "King's Rock"})
	var defender2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([attacker2], [defender2], "singles")
	c.rng.seed = 7
	var logs2: Array = []
	c._execute_move(attacker2, defender2, "Fling", true, logs2, fling)
	if not bool(defender2.get("flinched", false)):
		print("  Flung King's Rock did not make the target flinch.")
		return false
	return true


## Natural Gift's power and type must come from
## natural_gift_table.json: a Liechi Berry gives a 100 power
## Grass move (super effective against Water, where the
## move's printed Normal type would be neutral), and the
## berry is used up.
func test_v5_natural_gift_table() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Snorlax", ["normal"], ["Natural Gift"], {"item": "Liechi Berry"})
	var defender: Dictionary = _mon("Squirtle", ["water"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	var gift: Dictionary = {"name": "Natural Gift", "power": 0, "type": "Normal", "cat": "Physical", "acc": 100, "damage_rule": "item", "rule_kind": "natural_gift"}
	var gift_copy: Dictionary = gift.duplicate()
	var r: Dictionary = c._resolve_variable_power(gift_copy, attacker, defender, logs)
	if str(r.get("kind", "")) != "power" or int(r.get("power", -1)) != 100:
		print("  Natural Gift with a Liechi Berry resolved to %s, wanted power 100." % str(r))
		return false
	if str(gift_copy.get("type", "")) != "Grass":
		print("  Natural Gift with a Liechi Berry kept type '%s', wanted Grass." % str(gift_copy.get("type", "")))
		return false
	c.rng.seed = 7
	var logs2: Array = []
	c._execute_move(attacker, defender, "Natural Gift", true, logs2, gift)
	if float(defender.get("last_effectiveness", 0.0)) != 2.0:
		print("  Natural Gift hit Water with effectiveness %s, wanted 2.0 (Grass from the table)." % str(defender.get("last_effectiveness", 0.0)))
		return false
	if str(attacker.get("item", "")) != "":
		print("  Natural Gift did not use up the Liechi Berry; item is '%s'." % str(attacker.get("item", "")))
		return false
	return true


## The full-form weight table must answer for Megas through
## the controller's own lookup: "Charizard-Mega-X" finds the
## Showdown key "charizardmegax" (1105 hectograms), a base
## species still finds its own row, and an unknown species
## stays 0 (unknown, not a guess).
func test_v5_mega_weight_lookup() -> bool:
	var mega: Dictionary = {"species": "Charizard-Mega-X", "name": "Charizard-Mega-X"}
	if BattleController._weight_of(mega) != 1105:
		print("  Charizard-Mega-X weighed %d, wanted 1105." % BattleController._weight_of(mega))
		return false
	var gyarados: Dictionary = {"species": "Gyarados-Mega", "name": "Gyarados-Mega"}
	if BattleController._weight_of(gyarados) != 3050:
		print("  Gyarados-Mega weighed %d, wanted 3050." % BattleController._weight_of(gyarados))
		return false
	var pikachu: Dictionary = {"species": "Pikachu", "name": "Pikachu"}
	if BattleController._weight_of(pikachu) != 60:
		print("  Pikachu weighed %d, wanted 60." % BattleController._weight_of(pikachu))
		return false
	var unknown: Dictionary = {"species": "No Such Mon", "name": "No Such Mon"}
	if BattleController._weight_of(unknown) != 0:
		print("  An unknown species weighed %d, wanted 0." % BattleController._weight_of(unknown))
		return false
	return true
