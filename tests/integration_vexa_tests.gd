extends SceneTree
## VEXA simulator tests: formats, option effects, safety proofs.
## Run: godot --headless --script res://tests/integration_vexa_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW integration VEXA tests — starting.")
	_run("test_format_labels", Callable(self, "test_format_labels"))
	_run("test_counter_team_super_effective", Callable(self, "test_counter_team_super_effective"))
	_run("test_counter_differs_from_chosen", Callable(self, "test_counter_differs_from_chosen"))
	_run("test_level_option_takes_effect", Callable(self, "test_level_option_takes_effect"))
	_run("test_sim_runs_to_completion", Callable(self, "test_sim_runs_to_completion"))
	_run("test_safety_faint_leaves_save_identical", Callable(self, "test_safety_faint_leaves_save_identical"))
	_run("test_safety_no_evolution_in_real_party", Callable(self, "test_safety_no_evolution_in_real_party"))
	_run("test_shiny_toggle_sim_only", Callable(self, "test_shiny_toggle_sim_only"))
	_run("test_vgc_forces_level_50_and_pick4", Callable(self, "test_vgc_forces_level_50_and_pick4"))
	_run("test_not_yet_built_refused", Callable(self, "test_not_yet_built_refused"))
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


func _player_mon(mon_name: String, types: Array, moves: Array) -> Dictionary:
	return {
		"name": mon_name, "species": mon_name, "level": 50,
		"hp": 300, "max_hp": 300, "atk": 100, "def": 100, "spa": 100, "spd": 100, "spe": 100,
		"types": types, "ability": "", "item": "", "status": "", "moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}, "shiny": false,
	}


func _sim() -> PUWVexaSimulator:
	var s := PUWVexaSimulator.new()
	s.setup(root)
	return s


func test_format_labels() -> bool:
	var s := PUWVexaSimulator.new()
	var supported: Array = s.supported_formats()
	# STEP-6 UPDATE (composed G4 state, code_prep_vexa_raid/composed/):
	# all nine formats are built; nothing is not_yet_built.
	for f in ["singles", "doubles", "vgc", "sky", "inverse", "triple", "rotation", "tera_raid"]:
		if not (f in supported):
			return false
		if s.format_status(f) != "built":
			print("  %s labeled %s, wanted built" % [f, s.format_status(f)])
			return false
	if s.format_status("definitely_not_a_format") != "unknown_format":
		return false
	return true


func test_counter_team_super_effective() -> bool:
	var s := PUWVexaSimulator.new()
	var player: Array = [_player_mon("Charizard", ["Fire", "Flying"], ["Flamethrower"])]
	var team: Array = s.build_counter_team(player, 50, _rng(1))
	if team.size() != 6:
		print("  counter team size %d" % team.size())
		return false
	# Every counter mon must have at least one type super-effective
	# vs the pure-Fire-typed check below, verified through the chart.
	# (Player mon here is Fire/Flying; assert vs its Fire side using
	# a pure Fire defender so Water/Ground/Rock all qualify.)
	var fire_only := PackedStringArray(["Fire"])
	for mon_v in team:
		var mon: Dictionary = mon_v
		var ok: bool = false
		for t in mon.get("types", []):
			if PUWBattleEngine.type_multiplier(str(t), fire_only) > 1.0:
				ok = true
		if not ok:
			# Also accept SE vs the full Fire/Flying typing.
			var both := PackedStringArray(["Fire", "Flying"])
			for t2 in mon.get("types", []):
				if PUWBattleEngine.type_multiplier(str(t2), both) > 1.0:
					ok = true
		if not ok:
			print("  counter mon %s types %s not SE vs Fire" % [str(mon.get("species", "")), str(mon.get("types", []))])
			return false
	return true


func test_counter_differs_from_chosen() -> bool:
	var s := PUWVexaSimulator.new()
	var player: Array = [_player_mon("Charizard", ["Fire", "Flying"], ["Flamethrower"])]
	var counter: Array = s.build_counter_team(player, 50, _rng(2))
	var chosen: Array = s.build_chosen_team("pikachu", 50, "singles", _rng(2))
	if chosen.is_empty() or counter.is_empty():
		return false
	# Pikachu evolves by Thunder Stone, not level-up, so the chosen
	# lead stays pikachu (only level-up evolutions are auto-applied).
	if str((chosen[0] as Dictionary).get("species_slug", "")) != "pikachu":
		print("  chosen lead %s, wanted pikachu" % str((chosen[0] as Dictionary).get("species_slug", "")))
		return false
	var counter_slugs: Array = []
	for mon_v in counter:
		counter_slugs.append(str((mon_v as Dictionary).get("species_slug", "")))
	var chosen_slugs: Array = []
	for mon_v in chosen:
		chosen_slugs.append(str((mon_v as Dictionary).get("species_slug", "")))
	if counter_slugs == chosen_slugs:
		print("  counter and chosen teams identical")
		return false
	return true


func test_level_option_takes_effect() -> bool:
	var s := PUWVexaSimulator.new()
	var player: Array = [_player_mon("Bulbasaur", ["Grass", "Poison"], ["Energy Ball"])]
	var low: Array = s.build_counter_team(player, 20, _rng(4))
	var high: Array = s.build_counter_team(player, 80, _rng(4))
	for mon_v in low:
		if int((mon_v as Dictionary).get("level", 0)) != 20:
			return false
	for mon_v in high:
		if int((mon_v as Dictionary).get("level", 0)) != 80:
			return false
	return true


func test_sim_runs_to_completion() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = [
		_player_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"]),
		_player_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"]),
	]
	# Strong attackers so the sim battle decisively ends (the point
	# of this test is completion, not balance).
	for mon_v in player:
		(mon_v as Dictionary)["atk"] = 500
		(mon_v as Dictionary)["spa"] = 500
		(mon_v as Dictionary)["spe"] = 200
	var result: Dictionary = s.run_simulation(player, {"format": "singles", "level": 30, "opponent": "counter", "seed": 7})
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  sim status %s after %s turns" % [status, str(result.get("turns", 0))])
		return false
	return true


func test_safety_faint_leaves_save_identical() -> bool:
	var s: PUWVexaSimulator = _sim()
	# A frail party that will faint in the sim: 1 HP mons vs a
	# level-100 counter team.
	var player: Array = []
	for i in range(3):
		var mon: Dictionary = _player_mon("Pidgey", ["Normal", "Flying"], ["Quick Attack"])
		mon["hp"] = 1
		mon["max_hp"] = 1
		mon["instance_id"] = "real-mon-%d" % i
		mon["evo_family"] = "pidgey-family"
		player.append(mon)
	var before: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	var result: Dictionary = s.run_simulation(player, {"format": "singles", "level": 100, "opponent": "counter", "seed": 3})
	if str(result.get("status", "")) == "no_host" or str(result.get("status", "")) == "not_started":
		print("  sim did not run: " + str(result.get("status", "")))
		return false
	# The sim player copies must show the battle really happened:
	# at least one sim copy fainted.
	var sim_party: Array = result.get("player_team", [])
	var fainted: int = 0
	for mon_v in sim_party:
		if int((mon_v as Dictionary).get("hp", 0)) <= 0:
			fainted += 1
	if fainted == 0:
		print("  no sim mon fainted; safety proof is vacuous")
		return false
	if not bool(result.get("snapshot_unchanged", false)):
		print("  simulator reports snapshot changed")
		return false
	var after: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	if after != before:
		print("  real save state changed during sim")
		return false
	# No permadeath / family-lockout record anywhere in the state.
	if after.contains("PERMA") or after.contains("locked_evo") or after.contains("fainting_ledger"):
		print("  lockout record appeared in save state")
		return false
	# Real mons keep their HP (the sim fainted only copies).
	for mon_v in player:
		if int((mon_v as Dictionary).get("hp", 0)) != 1:
			print("  real mon HP changed")
			return false
	return true


func test_safety_no_evolution_in_real_party() -> bool:
	var s: PUWVexaSimulator = _sim()
	# Charmander at level 15 with huge stats so it can win EXP and
	# level past its level-16 evolution trigger inside the sim.
	var mon: Dictionary = _player_mon("Charmander", ["Fire"], ["Flamethrower"])
	mon["level"] = 15
	mon["species_slug"] = "charmander"
	mon["exp"] = 0
	mon["spa"] = 900
	mon["spe"] = 300
	mon["hp"] = 500
	mon["max_hp"] = 500
	var player: Array = [mon]
	var before: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	var result: Dictionary = s.run_simulation(player, {"format": "singles", "level": 5, "opponent": "rattata", "seed": 8})
	if str(result.get("status", "")) in ["no_host", "not_started", "not_yet_built"]:
		print("  sim did not run: " + str(result.get("status", "")))
		return false
	var after: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	if after != before:
		print("  real party changed during sim")
		return false
	if str(player[0].get("species", "")) != "Charmander":
		print("  real Charmander evolved to " + str(player[0].get("species", "")))
		return false
	return int(player[0].get("level", 0)) == 15


func test_shiny_toggle_sim_only() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = [_player_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"])]
	var on: Dictionary = s.run_simulation(player, {"format": "singles", "level": 20, "opponent": "counter", "seed": 9, "shiny": true})
	for mon_v in on.get("enemy_team", []):
		if not bool((mon_v as Dictionary).get("shiny", false)):
			print("  shiny toggle on but a sim enemy lacks shiny=true")
			return false
	for mon_v in on.get("player_team", []):
		if not bool((mon_v as Dictionary).get("shiny", false)):
			print("  shiny toggle on but a sim player copy lacks shiny=true")
			return false
	var off: Dictionary = s.run_simulation(player, {"format": "singles", "level": 20, "opponent": "counter", "seed": 9, "shiny": false})
	for mon_v in off.get("enemy_team", []):
		if bool((mon_v as Dictionary).get("shiny", false)):
			print("  shiny toggle off but a sim enemy is shiny")
			return false
	# The real party never gained the flag.
	return not bool(player[0].get("shiny", false))


func test_vgc_forces_level_50_and_pick4() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = [
		_player_mon("Pikachu", ["Electric"], ["Thunderbolt"]),
		_player_mon("Charizard", ["Fire", "Flying"], ["Flamethrower"]),
		_player_mon("Blastoise", ["Water"], ["Surf"]),
		_player_mon("Venusaur", ["Grass", "Poison"], ["Energy Ball"]),
	]
	# Level option deliberately set to 90: VGC must force 50 flat.
	var result: Dictionary = s.run_simulation(player, {"format": "vgc", "level": 90, "opponent": "counter", "seed": 10})
	var enemy: Array = result.get("enemy_team", [])
	if enemy.size() != 4:
		print("  VGC enemy team size %d, wanted 4 (bring-6-pick-4)" % enemy.size())
		return false
	for mon_v in enemy:
		if int((mon_v as Dictionary).get("level", 0)) != 50:
			print("  VGC mon level %s, wanted flat 50" % str((mon_v as Dictionary).get("level", 0)))
			return false
	return str(result.get("engine_format", "")) == "doubles"


func test_not_yet_built_refused() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = [_player_mon("Pikachu", ["Electric"], ["Thunderbolt"])]
	# STEP-6 UPDATE (composed G4 state): no built format may refuse;
	# refusal coverage is now the unknown-format case.
	for f in ["triple", "rotation", "tera_raid"]:
		var ran: Dictionary = s.run_simulation(player, {"format": f, "level": 50})
		if str(ran.get("status", "")) == "not_yet_built":
			print("  format %s refused as not_yet_built in the composed state" % f)
			return false
	var result: Dictionary = s.run_simulation(player, {"format": "definitely_not_a_format", "level": 50})
	if str(result.get("status", "")) != "unknown_format":
		print("  unknown format ran with status %s instead of refusing" % str(result.get("status", "")))
		return false
	return true
