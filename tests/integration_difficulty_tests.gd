extends SceneTree
## Difficulty layer tests: PUWTeamBuilder.
## Run: godot --headless --script res://tests/integration_difficulty_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW integration difficulty tests — starting.")
	_run("test_six_mons_from_two_mon_base", Callable(self, "test_six_mons_from_two_mon_base"))
	_run("test_brock_roster_six", Callable(self, "test_brock_roster_six"))
	_run("test_ivs_all_31_and_ev_cap", Callable(self, "test_ivs_all_31_and_ev_cap"))
	_run("test_levels_equal_player_max_37", Callable(self, "test_levels_equal_player_max_37"))
	_run("test_auto_evolve_charmander_40", Callable(self, "test_auto_evolve_charmander_40"))
	_run("test_vgc_mode_uses_vgc_sets", Callable(self, "test_vgc_mode_uses_vgc_sets"))
	_run("test_wild_level_range_and_clamp", Callable(self, "test_wild_level_range_and_clamp"))
	_run("test_no_healing_or_moves_strips_recover", Callable(self, "test_no_healing_or_moves_strips_recover"))
	_run("test_challenge_modes_items", Callable(self, "test_challenge_modes_items"))
	_run("test_ev_cap_trim_rule", Callable(self, "test_ev_cap_trim_rule"))
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
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


func test_six_mons_from_two_mon_base() -> bool:
	var b := PUWTeamBuilder.new()
	var team: Array = b.build_trainer_team(["rattata", "ekans"], 37, "singles", _rng(42))
	if team.size() != 6:
		print("  team size %d, wanted 6" % team.size())
		return false
	var seen: Dictionary = {}
	for mon_v in team:
		var mon: Dictionary = mon_v
		var slug: String = str(mon.get("species_slug", ""))
		if seen.has(slug):
			print("  repeated species " + slug)
			return false
		seen[slug] = true
	return true


func test_brock_roster_six() -> bool:
	var b := PUWTeamBuilder.new()
	var team: Array = b.build_roster_team("kanto_gym_1_brock", 37, "singles")
	if team.size() != 6:
		print("  Brock team size %d, wanted 6" % team.size())
		return false
	# Brock's sourced roster species, auto-evolved at 37 where the
	# level-up data allows (geodude->graveler at 25; onix stays).
	var slugs: Array = []
	for mon_v in team:
		slugs.append(str((mon_v as Dictionary).get("species_slug", "")))
	return "graveler" in slugs and "onix" in slugs


func test_ivs_all_31_and_ev_cap() -> bool:
	var b := PUWTeamBuilder.new()
	var team: Array = b.build_trainer_team(["rattata", "ekans"], 37, "singles", _rng(7))
	# DATA-PATH TEST ONLY: Leon's roster is loaded as stored
	# endgame (World Coronation) data to check IV/EV rules on a
	# real 6-mon roster. This does NOT place Leon in Kanto.
	team.append_array(b.build_roster_team("world_coronation_finale_leon", 90, "singles"))
	for mon_v in team:
		var mon: Dictionary = mon_v
		var ivs: Dictionary = mon.get("ivs", {})
		for key in ["hp", "atk", "def", "spa", "spd", "spe"]:
			if int(ivs.get(key, 0)) != 31:
				print("  IV %s = %s on %s" % [key, str(ivs.get(key, 0)), str(mon.get("species", ""))])
				return false
		if PUWTeamBuilder.ev_total(mon.get("evs", {})) > 510:
			print("  EV total over 510 on " + str(mon.get("species", "")))
			return false
	return true


func test_levels_equal_player_max_37() -> bool:
	var b := PUWTeamBuilder.new()
	var team: Array = b.build_trainer_team(["rattata", "ekans"], 37, "singles", _rng(3))
	for mon_v in team:
		if int((mon_v as Dictionary).get("level", 0)) != 37:
			print("  level %s, wanted 37" % str((mon_v as Dictionary).get("level", 0)))
			return false
	return true


func test_auto_evolve_charmander_40() -> bool:
	var b := PUWTeamBuilder.new()
	var mon: Dictionary = b.build_mon("charmander", 40, "singles")
	if str(mon.get("species", "")) != "Charizard":
		print("  species %s, wanted Charizard" % str(mon.get("species", "")))
		return false
	var young: Dictionary = b.build_mon("charmander", 10, "singles")
	return str(young.get("species", "")) == "Charmander"


func test_vgc_mode_uses_vgc_sets() -> bool:
	var b := PUWTeamBuilder.new()
	# Charizard has a sourced gen9 VGC set (vgc2025) in the data.
	var mon: Dictionary = b.build_mon("charizard", 50, "vgc")
	if str(mon.get("set_format", "")) != "vgc2025":
		print("  set_format %s, wanted vgc2025" % str(mon.get("set_format", "")))
		return false
	var singles: Dictionary = b.build_mon("charizard", 50, "singles")
	return str(singles.get("set_format", "")) != "vgc2025"


func test_wild_level_range_and_clamp() -> bool:
	var b := PUWTeamBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(30):
		var mon: Dictionary = b.build_wild_mon("pidgey", 20, rng)
		var lv: int = int(mon.get("level", 0))
		if lv < 21 or lv > 23:
			print("  wild level %d outside [21,23]" % lv)
			return false
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	for i in range(10):
		var mon2: Dictionary = b.build_wild_mon("pidgey", 99, rng2)
		if int(mon2.get("level", 0)) != 100:
			print("  wild level %s at player_max 99, wanted clamp 100" % str(mon2.get("level", 0)))
			return false
	return true


func test_no_healing_or_moves_strips_recover() -> bool:
	var b := PUWTeamBuilder.new()
	# Toxapex's sourced OU set carries Recover.
	var team: Array = b.build_trainer_team(["toxapex"], 50, "singles", _rng(11))
	var had_recover: bool = false
	for mon_v in team:
		if "Recover" in (mon_v as Dictionary).get("moves", []):
			had_recover = true
	if not had_recover:
		print("  built team never had Recover; test premise broken")
		return false
	var stripped: Array = b.apply_challenge_mode(team, "NO_HEALING_OR_MOVES")
	for mon_v in stripped:
		var moves: Array = (mon_v as Dictionary).get("moves", [])
		for healing in PUWTeamBuilder.HEALING_MOVES:
			if healing in moves:
				print("  healing move %s survived on %s" % [healing, str((mon_v as Dictionary).get("species", ""))])
				return false
	# Original team untouched by apply_challenge_mode.
	for mon_v in team:
		if "Recover" in (mon_v as Dictionary).get("moves", []):
			return true
	print("  apply_challenge_mode mutated its input")
	return false


func test_challenge_modes_items() -> bool:
	var b := PUWTeamBuilder.new()
	var team: Array = b.build_trainer_team(["charizard"], 50, "singles", _rng(13))
	var no_items: Array = b.apply_challenge_mode(team, "NO_TRAINER_ITEMS")
	for mon_v in no_items:
		if str((mon_v as Dictionary).get("item", "")) != "":
			return false
	var standard: Array = b.apply_challenge_mode(team, "STANDARD_MAX_DIFFICULTY")
	for i in range(team.size()):
		if str((standard[i] as Dictionary).get("item", "")) != str((team[i] as Dictionary).get("item", "")):
			return false
	return true


func test_ev_cap_trim_rule() -> bool:
	var over: Dictionary = {"hp": 252, "atk": 252, "def": 4, "spa": 4, "spd": 4, "spe": 4}
	var capped: Dictionary = PUWTeamBuilder.cap_evs(over)
	if PUWTeamBuilder.ev_total(capped) > 510:
		return false
	# 520 total, trim 10 from the smallest nonzero stats first
	# (4-EV stats in fixed order): def/spa/spd drop before the 252s.
	if int(capped.get("spe", 0)) != 4 or int(capped.get("hp", 0)) != 252:
		print("  unexpected trim result " + str(capped))
		return false
	return true
