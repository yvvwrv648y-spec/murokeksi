extends SceneTree
## VEXA raid tests (gap G4): PUWRaidBattle (Max Raid-style
## battle), PUWRaidRun (Dynamax Adventures run structure), and
## the PUWVexaSimulator wiring — format availability, raid flow,
## shield/cheer/Dynamax rules, permadeath exemption (snapshot
## byte-equality), and existing-format regressions.
## Run: godot --headless --script res://tests/raid_vexa_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW VEXA raid tests — starting.")
	_run("test_raid_format_available", Callable(self, "test_raid_format_available"))
	_run("test_raid_battle_wins_and_rewards", Callable(self, "test_raid_battle_wins_and_rewards"))
	_run("test_raid_turn_limit_loss", Callable(self, "test_raid_turn_limit_loss"))
	_run("test_raid_faint_limit_loss", Callable(self, "test_raid_faint_limit_loss"))
	_run("test_shield_bars_and_break", Callable(self, "test_shield_bars_and_break"))
	_run("test_cheer_and_revive_cycle", Callable(self, "test_cheer_and_revive_cycle"))
	_run("test_dynamax_rotation_rules", Callable(self, "test_dynamax_rotation_rules"))
	_run("test_nullify_resets_stages", Callable(self, "test_nullify_resets_stages"))
	_run("test_raid_sim_snapshot_safety", Callable(self, "test_raid_sim_snapshot_safety"))
	_run("test_existing_formats_regression", Callable(self, "test_existing_formats_regression"))
	_run("test_run_structure_clears_and_keeps_one", Callable(self, "test_run_structure_clears_and_keeps_one"))
	_run("test_run_endless_lock_and_keep_nothing", Callable(self, "test_run_endless_lock_and_keep_nothing"))
	_run("test_run_hearts_and_failure", Callable(self, "test_run_hearts_and_failure"))
	_run("test_raid_run_sim_wrapper", Callable(self, "test_raid_run_sim_wrapper"))
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


func _mon(mon_name: String, types: Array, moves: Array, hp: int, atk: int, def: int, spe: int) -> Dictionary:
	return {
		"name": mon_name, "species": mon_name, "species_slug": mon_name.to_lower(),
		"level": 50, "hp": hp, "max_hp": hp,
		"atk": atk, "def": def, "spa": atk, "spd": def, "spe": spe,
		"types": types, "ability": "", "item": "", "status": "", "moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}, "shiny": false,
	}


func _entries(mons: Array) -> Array:
	var out: Array = []
	for i in range(mons.size()):
		out.append({"trainer": "T%d" % i, "is_player": i == 0, "mon": mons[i]})
	return out


func _sim() -> PUWVexaSimulator:
	var s := PUWVexaSimulator.new()
	s.setup(root)
	return s


func _none_actions() -> Array:
	return [{"type": "none"}, {"type": "none"}, {"type": "none"}, {"type": "none"}]


# 1. COMPOSED UPDATE (composed G4 state): the raid format reports
# built; triple/rotation are built too (they refuse only in the
# raid-prep-alone state, which this composed copy supersedes).
func test_raid_format_available() -> bool:
	var s := PUWVexaSimulator.new()
	if s.format_status("tera_raid") != "built":
		print("  tera_raid labeled %s, wanted built" % s.format_status("tera_raid"))
		return false
	if not ("tera_raid" in s.supported_formats()):
		print("  tera_raid missing from supported_formats")
		return false
	if s.engine_format("tera_raid") != "raid":
		print("  tera_raid engine_format %s, wanted raid" % s.engine_format("tera_raid"))
		return false
	for f in ["triple", "rotation"]:
		if s.format_status(f) != "built":
			print("  %s labeled %s, wanted built (composed state)" % [f, s.format_status(f)])
			return false
		if not (f in s.supported_formats()):
			return false
	if s.format_status("made_up_format") != "unknown_format":
		return false
	var hosted: PUWVexaSimulator = _sim()
	var player: Array = [_mon("Pikachu", ["Electric"], ["Thunderbolt"], 300, 100, 100, 100)]
	for f in ["triple", "rotation"]:
		var result: Dictionary = hosted.run_simulation(player, {"format": f, "level": 50})
		if str(result.get("status", "")) in ["not_yet_built", "unknown_format"]:
			print("  format %s refused with status %s in the composed state" % [f, str(result.get("status", ""))])
			return false
	return true


# 2. A raid battle runs to a win; the boss was Dynamaxed through
# the project's gimmick engine (HP doubled); victory reports one
# catch attempt per Trainer plus the reward bundle.
func test_raid_battle_wins_and_rewards() -> bool:
	var boss: Dictionary = _mon("Rattata", ["Normal"], ["Quick Attack"], 100, 30, 20, 30)
	var raiders: Array = []
	for i in range(4):
		raiders.append(_mon("Machamp", ["Fighting"], ["Close Combat"], 400, 500, 200, 200))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 3, _rng(11))
	if int(raid.boss.get("max_hp", 0)) != 200:
		print("  boss max_hp %s after Dynamax, wanted 200" % str(raid.boss.get("max_hp", 0)))
		return false
	if not bool(raid.boss.get("dynamax_active", false)):
		print("  boss not dynamax_active")
		return false
	var guard: int = 0
	while not raid.is_over() and guard < 12:
		guard += 1
		var actions: Array = []
		for i in range(4):
			actions.append(raid.choose_action(i))
		raid.run_round(actions)
	var result: Dictionary = raid.battle_result()
	if str(result.get("status", "")) != "player_won":
		print("  raid status %s, wanted player_won (turns %s)" % [str(result.get("status", "")), str(result.get("turns", 0))])
		return false
	if int(result.get("catch_attempts", 0)) != 4:
		print("  catch_attempts %s, wanted 4" % str(result.get("catch_attempts", 0)))
		return false
	if (result.get("rewards", []) as Array).is_empty():
		print("  no reward bundle reported")
		return false
	return true


# 3. The sourced 10-turn clock: a boss nobody can hurt and
# raiders nobody can drop ends as a turn-limit loss at turn 10.
func test_raid_turn_limit_loss() -> bool:
	var boss: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"], 100000, 10, 500, 10)
	var raiders: Array = []
	for i in range(4):
		raiders.append(_mon("Chansey", ["Normal"], ["Thunder Wave"], 10000, 10, 500, 10))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 3, _rng(12))
	var guard: int = 0
	while not raid.is_over() and guard < 15:
		guard += 1
		var actions: Array = []
		for i in range(4):
			actions.append(raid.choose_action(i))
		raid.run_round(actions)
	var result: Dictionary = raid.battle_result()
	if str(result.get("status", "")) != "enemy_won":
		print("  status %s, wanted enemy_won" % str(result.get("status", "")))
		return false
	if str(result.get("lose_reason", "")) != "turn_limit":
		print("  lose_reason %s, wanted turn_limit" % str(result.get("lose_reason", "")))
		return false
	if int(result.get("turns", 0)) != PUWRaidBattle.MAX_TURNS:
		print("  turns %s, wanted %d" % [str(result.get("turns", 0)), PUWRaidBattle.MAX_TURNS])
		return false
	return int(result.get("faints_used", -1)) == 0


# 4. The sourced shared faint budget: 4 total faints loses the
# raid even though fainted raiders would have revived.
func test_raid_faint_limit_loss() -> bool:
	var boss: Dictionary = _mon("Gengar", ["Ghost", "Poison"], ["Quick Attack"], 100000, 999, 500, 999)
	var raiders: Array = []
	for i in range(4):
		raiders.append(_mon("Pidgey", ["Normal", "Flying"], ["Quick Attack"], 30, 10, 10, 10))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 5, _rng(13))
	var guard: int = 0
	while not raid.is_over() and guard < 12:
		guard += 1
		var actions: Array = []
		for i in range(4):
			actions.append(raid.choose_action(i))
		raid.run_round(actions)
	var result: Dictionary = raid.battle_result()
	if str(result.get("status", "")) != "enemy_won":
		print("  status %s, wanted enemy_won" % str(result.get("status", "")))
		return false
	if str(result.get("lose_reason", "")) != "faint_limit":
		print("  lose_reason %s, wanted faint_limit" % str(result.get("lose_reason", "")))
		return false
	if int(result.get("faints_used", 0)) != PUWRaidBattle.MAX_FAINTS:
		print("  faints_used %s, wanted %d" % [str(result.get("faints_used", 0)), PUWRaidBattle.MAX_FAINTS])
		return false
	return true


# 5. Shield rules, priced hit by hit: bars by star inside the
# sourced 2-8 range; a normal hit removes 1 bar, a Max Move hit
# removes 2; damage through the shield is exactly the shield
# multiplier of the same hit unshielded (same-seed RNGs); a
# break drops the boss's Def/Sp. Def stages.
func test_shield_bars_and_break() -> bool:
	var boss_a: Dictionary = _mon("Lapras", ["Water", "Ice"], ["Surf"], 10000, 50, 50, 50)
	var boss_b: Dictionary = _mon("Lapras", ["Water", "Ice"], ["Surf"], 10000, 50, 50, 50)
	var mk_raiders := func() -> Array:
		var arr: Array = []
		for i in range(4):
			arr.append(_mon("Dragonite", ["Dragon", "Flying"], ["Outrage"], 500, 300, 100, 100))
		return arr
	var raid_a := PUWRaidBattle.new()
	raid_a.setup_raid(boss_a, _entries(mk_raiders.call()), 5, _rng(42))
	var raid_b := PUWRaidBattle.new()
	raid_b.setup_raid(boss_b, _entries(mk_raiders.call()), 5, _rng(42))
	raid_b.shield_bars = 4
	var hit_a: Dictionary = raid_a.apply_hit_to_boss(0, "Outrage")
	var hit_b: Dictionary = raid_b.apply_hit_to_boss(0, "Outrage")
	var dmg_a: int = int(hit_a.get("damage", 0))
	var dmg_b: int = int(hit_b.get("damage", 0))
	if dmg_a <= 10:
		print("  unshielded damage %d too small to compare" % dmg_a)
		return false
	if dmg_b != int(floor(float(dmg_a) * PUWRaidBattle.SHIELD_DAMAGE_MULT)):
		print("  shielded damage %d, wanted %d (half of %d)" % [dmg_b, int(floor(float(dmg_a) * PUWRaidBattle.SHIELD_DAMAGE_MULT)), dmg_a])
		return false
	if int(hit_b.get("bars_removed", 0)) != 1:
		print("  normal hit removed %s bars, wanted 1" % str(hit_b.get("bars_removed", 0)))
		return false
	# Max Move hit removes 2 bars: Dynamax raider 0 through the
	# project's gimmick engine, then hit again.
	var mon0: Dictionary = (raid_b.raiders[0] as Dictionary).get("mon", {})
	var glogs: Array = []
	PUWGimmicks.dynamax(mon0, glogs, {})
	if not bool(mon0.get("dynamax_active", false)):
		print("  raider Dynamax did not take")
		return false
	var bars_before: int = raid_b.shield_bars
	var hit_max: Dictionary = raid_b.apply_hit_to_boss(0, "Outrage")
	if not bool(hit_max.get("is_max_move", false)):
		print("  dynamaxed hit not flagged as Max Move")
		return false
	if int(hit_max.get("bars_removed", 0)) != mini(2, bars_before):
		print("  Max Move removed %s bars, wanted %d" % [str(hit_max.get("bars_removed", 0)), mini(2, bars_before)])
		return false
	# Keep hitting until a break: Def/Sp. Def stages must drop.
	var def_before: int = int((raid_b.boss.get("stages", {}) as Dictionary).get("def", 0))
	var guard: int = 0
	while raid_b.shield_breaks == 0 and guard < 60:
		guard += 1
		if raid_b.shield_bars == 0:
			raid_b.shield_bars = 2
		raid_b.apply_hit_to_boss(1, "Outrage")
	if raid_b.shield_breaks == 0:
		print("  shield never broke")
		return false
	var def_after: int = int((raid_b.boss.get("stages", {}) as Dictionary).get("def", 0))
	if def_after != def_before - PUWRaidBattle.SHIELD_BREAK_DEF_DROP * raid_b.shield_breaks:
		print("  boss def stage %d after %d breaks, wanted %d" % [def_after, raid_b.shield_breaks, def_before - PUWRaidBattle.SHIELD_BREAK_DEF_DROP * raid_b.shield_breaks])
		return false
	# The star table itself stays inside the sourced 2-8 range.
	for star_v in PUWRaidBattle.SHIELD_BARS_BY_STAR.keys():
		var bars: int = int(PUWRaidBattle.SHIELD_BARS_BY_STAR.get(star_v, 0))
		if bars < 2 or bars > 8:
			print("  star %s gives %d bars, outside sourced 2-8" % [str(star_v), bars])
			return false
	return true


# 6. Faint -> cheer (one turn) -> revive at full HP (following
# turn), exactly the sourced cycle.
func test_cheer_and_revive_cycle() -> bool:
	var boss: Dictionary = _mon("Machamp", ["Fighting"], ["Quick Attack"], 100000, 60, 500, 50)
	var raiders: Array = []
	raiders.append(_mon("TankA", ["Steel"], ["Quick Attack"], 10000, 10, 500, 10))
	var frail: Dictionary = _mon("FrailB", ["Normal"], ["Quick Attack"], 200, 10, 1, 10)
	raiders.append(frail)
	raiders.append(_mon("TankC", ["Steel"], ["Quick Attack"], 10000, 10, 500, 10))
	raiders.append(_mon("TankD", ["Steel"], ["Quick Attack"], 10000, 10, 500, 10))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 3, _rng(14))
	# Drop raider 1 to 1 HP, then land the boss's hit directly.
	var entry1: Dictionary = raid.raiders[1]
	(entry1.get("mon", {}) as Dictionary)["hp"] = 1
	var hit: Dictionary = raid.apply_hit_to_raider("Quick Attack", 1)
	if not bool(hit.get("fainted", false)):
		print("  direct boss hit did not faint raider 1")
		return false
	if str(entry1.get("state", "")) != "fainted":
		print("  raider 1 state %s, wanted fainted" % str(entry1.get("state", "")))
		return false
	if raid.faints_used != 1:
		print("  faints_used %d, wanted 1" % raid.faints_used)
		return false
	# Disarm the boss for the cycle rounds (a status move only):
	# the revived raider is frail and must not be re-fainted by a
	# random boss target before the assertions run.
	raid.boss["moves"] = ["Thunder Wave"]
	# Round 1: raider 1 cheers instead of acting.
	raid.run_round(_none_actions())
	if str(entry1.get("state", "")) != "revive_pending":
		print("  after cheer round state %s, wanted revive_pending" % str(entry1.get("state", "")))
		return false
	var cheered: bool = false
	for log_v in raid.logs:
		if str(log_v).contains("cheered"):
			cheered = true
	if not cheered:
		print("  no cheer in the raid log")
		return false
	# Round 2: raider 1 revives at full HP.
	raid.run_round(_none_actions())
	if str(entry1.get("state", "")) != "active":
		print("  after revive round state %s, wanted active" % str(entry1.get("state", "")))
		return false
	var mon1: Dictionary = entry1.get("mon", {})
	return int(mon1.get("hp", 0)) == int(mon1.get("max_hp", -1))


# 7. Dynamax rotation: only the holder may Dynamax, the
# opportunity passes when unused, only one Trainer per battle,
# and a used Dynamax ends after 3 turns.
func test_dynamax_rotation_rules() -> bool:
	var boss: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"], 100000, 10, 500, 10)
	var raiders: Array = []
	for i in range(4):
		raiders.append(_mon("Tank", ["Steel"], ["Quick Attack"], 5000, 10, 500, 10))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 3, _rng(15))
	if raid.dynamax_holder() != 0:
		print("  holder starts at %d, wanted 0 (host)" % raid.dynamax_holder())
		return false
	# Round 1: non-holder (slot 1) tries to Dynamax — refused;
	# the opportunity passes to slot 1.
	var actions1: Array = _none_actions()
	actions1[1] = {"type": "none", "dynamax": true}
	raid.run_round(actions1)
	var mon1: Dictionary = (raid.raiders[1] as Dictionary).get("mon", {})
	if bool(mon1.get("dynamax_active", false)):
		print("  non-holder Dynamaxed")
		return false
	if raid.dynamax_spent():
		print("  dynamax spent by a refused attempt")
		return false
	if raid.dynamax_holder() != 1:
		print("  holder after pass %d, wanted 1" % raid.dynamax_holder())
		return false
	# Round 2: the holder Dynamaxes. HP doubles (gimmick engine).
	var hp_before: int = int(mon1.get("max_hp", 0))
	var actions2: Array = _none_actions()
	actions2[1] = {"type": "none", "dynamax": true}
	raid.run_round(actions2)
	if not bool(mon1.get("dynamax_active", false)):
		print("  holder's Dynamax did not take")
		return false
	if int(mon1.get("max_hp", 0)) != hp_before * 2:
		print("  dynamaxed max_hp %s, wanted %d" % [str(mon1.get("max_hp", 0)), hp_before * 2])
		return false
	if not raid.dynamax_spent():
		print("  dynamax not marked spent")
		return false
	# Rounds 3-4: Dynamax (3 turns: rounds 2,3,4) ends.
	raid.run_round(_none_actions())
	raid.run_round(_none_actions())
	if bool(mon1.get("dynamax_active", false)):
		print("  Dynamax still active after 3 turns")
		return false
	if int(mon1.get("max_hp", 0)) != hp_before:
		print("  max_hp %s after Dynamax ended, wanted %d" % [str(mon1.get("max_hp", 0)), hp_before])
		return false
	return true


# 8. The boss's periodic nullification resets every raider's
# stat stages (and flags abilities nullified for a turn).
func test_nullify_resets_stages() -> bool:
	var boss: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"], 100000, 10, 500, 10)
	var raiders: Array = []
	for i in range(4):
		raiders.append(_mon("Tank", ["Steel"], ["Quick Attack"], 10000, 10, 500, 10))
	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss, _entries(raiders), 3, _rng(16))
	var entry0: Dictionary = raid.raiders[0]
	(entry0.get("mon", {}) as Dictionary)["stages"] = {"atk": 2, "def": 1, "spa": 0, "spd": 0, "spe": -1}
	for r in range(PUWRaidBattle.NULLIFY_EVERY_TURNS):
		raid.run_round(_none_actions())
	var stages: Dictionary = (entry0.get("mon", {}) as Dictionary).get("stages", {})
	for key in ["atk", "def", "spa", "spd", "spe"]:
		if int(stages.get(key, 0)) != 0:
			print("  stage %s = %s after nullify, wanted 0" % [key, str(stages.get(key, 0))])
			return false
	if not bool(entry0.get("ability_nullified", false)):
		print("  ability_nullified flag not set on the nullify turn")
		return false
	return true


# 9. Exemption proof, mirroring the existing VEXA safety test:
# a raid sim where the player's copies faint leaves the real
# party and the save state byte-identical, and records no
# permadeath / lockout data anywhere.
func test_raid_sim_snapshot_safety() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = []
	for i in range(3):
		var mon: Dictionary = _mon("Pidgey", ["Normal", "Flying"], ["Quick Attack"], 300, 100, 100, 100)
		mon["hp"] = 1
		mon["max_hp"] = 1
		mon["instance_id"] = "real-mon-%d" % i
		mon["evo_family"] = "pidgey-family"
		player.append(mon)
	var co_op_mon: Dictionary = _mon("Eevee", ["Normal"], ["Quick Attack"], 200, 100, 100, 100)
	var co_op: Array = [co_op_mon]
	var co_op_before: String = JSON.stringify(co_op)
	var before: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	var result: Dictionary = s.run_simulation(player, {
		"format": "tera_raid", "level": 100, "boss": "charizard", "seed": 3,
		"co_op_parties": [co_op],
	})
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  raid sim status %s" % status)
		return false
	if str(result.get("format", "")) != "tera_raid" or str(result.get("engine_format", "")) != "raid":
		print("  raid result format fields wrong: %s / %s" % [str(result.get("format", "")), str(result.get("engine_format", ""))])
		return false
	if not bool(result.get("snapshot_unchanged", false)):
		print("  simulator reports snapshot changed")
		return false
	if str(result.get("snapshot_before", "")) != str(result.get("snapshot_after", "")):
		print("  snapshot strings differ")
		return false
	var after: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	if after != before:
		print("  real save state changed during raid sim")
		return false
	if after.contains("PERMA") or after.contains("locked_evo") or after.contains("fainting_ledger"):
		print("  lockout record appeared in save state")
		return false
	for mon_v in player:
		if int((mon_v as Dictionary).get("hp", 0)) != 1:
			print("  real mon HP changed")
			return false
	if JSON.stringify(co_op) != co_op_before:
		print("  co-op party was mutated by the raid sim")
		return false
	# The battle really happened inside the sim.
	var raid_info: Dictionary = result.get("raid", {})
	if int(raid_info.get("turns", 0)) < 1:
		print("  raid ran 0 turns; safety proof is vacuous")
		return false
	return true


# 10. Existing formats unchanged: statuses, engine mapping, and
# a singles sim that completes with byte-equal snapshots.
func test_existing_formats_regression() -> bool:
	var s: PUWVexaSimulator = _sim()
	var expected: Dictionary = {
		"singles": "singles", "doubles": "doubles", "vgc": "doubles",
		"sky": "singles", "inverse": "inverse_battle",
	}
	for f_v in expected.keys():
		var f: String = str(f_v)
		if s.format_status(f) != "built":
			print("  %s no longer built" % f)
			return false
		if s.engine_format(f) != str(expected.get(f, "")):
			print("  %s engine_format changed" % f)
			return false
	var player: Array = [
		_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"], 300, 500, 100, 200),
		_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"], 300, 500, 100, 200),
	]
	var result: Dictionary = s.run_simulation(player, {"format": "singles", "level": 30, "opponent": "counter", "seed": 7})
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  singles sim status %s" % status)
		return false
	if not bool(result.get("snapshot_unchanged", false)):
		print("  singles snapshot changed")
		return false
	return str(result.get("snapshot_before", "")) == str(result.get("snapshot_after", ""))


func _buffed(mon: Dictionary) -> Dictionary:
	mon["max_hp"] = 5000
	mon["hp"] = 5000
	mon["atk"] = 900
	mon["spa"] = 900
	mon["def"] = 500
	mon["spd"] = 500
	mon["spe"] = 900
	return mon


func _started_run(seed_val: int) -> PUWRaidRun:
	var builder := PUWTeamBuilder.new()
	var run := PUWRaidRun.new()
	var player_mon: Dictionary = _buffed(builder.build_mon("pikachu", 50, "singles"))
	var started: Dictionary = run.start({
		"builder": builder, "rng": _rng(seed_val), "level": 50, "star": 3,
		"player_mon": player_mon, "npc_species": ["eevee", "snorlax", "gengar"],
	})
	if str(started.get("status", "")) != "started":
		return null
	for e_v in run.entries:
		var e: Dictionary = e_v
		_buffed(e.get("mon", {}))
	return run


# 11. Run structure: 3 battles + a Legendary final, HP carries
# over, one swap for a fresh catch per battle, keep exactly one.
func test_run_structure_clears_and_keeps_one() -> bool:
	var run: PUWRaidRun = _started_run(21)
	if run == null:
		print("  run did not start")
		return false
	if run.path_options().size() != 2:
		print("  first path offers %d options, wanted 2" % run.path_options().size())
		return false
	var battles: int = 0
	var swapped: bool = false
	while run.status == "in_progress" and battles < 8:
		if run.is_final_next():
			if run.path_options().size() != 1:
				print("  final path offers %d options, wanted 1 (Legendary)" % run.path_options().size())
				return false
			var boss_slug: String = str(run.peek_path_species()[0])
			if not (boss_slug in PUWRaidRun.LEGENDARY_POOL):
				print("  final boss %s not in the Legendary pool" % boss_slug)
				return false
		run.choose_path(0)
		var result: Dictionary = run.fight_current_battle()
		battles += 1
		if str(result.get("status", "")) != "player_won":
			print("  battle %d lost with buffed team: %s" % [battles, str(result.get("status", ""))])
			return false
		if battles == 1:
			# One swap for the fresh catch; a second must refuse.
			if not run.swap_for_catch(1):
				print("  swap_for_catch refused after a win")
				return false
			swapped = true
			if run.swap_for_catch(2):
				print("  second swap in one battle allowed")
				return false
			var entry1: Dictionary = run.entries[1]
			if str((entry1.get("mon", {}) as Dictionary).get("species", "")) != str(run.catches[0]):
				print("  swapped mon is not the fresh catch")
				return false
			# Wound slot 0: battle 2 must NOT reset it (carry-over).
			var entry0: Dictionary = run.entries[0]
			(entry0.get("mon", {}) as Dictionary)["hp"] = 100
		if battles == 2:
			var entry0b: Dictionary = run.entries[0]
			if int((entry0b.get("mon", {}) as Dictionary).get("hp", 0)) != 100:
				print("  HP did not carry over: slot 0 at %s after battle 2, wanted 100" % str((entry0b.get("mon", {}) as Dictionary).get("hp", 0)))
				return false
	if not swapped:
		return false
	if battles != PUWRaidRun.BATTLES_BEFORE_FINAL + 1:
		print("  run took %d battles, wanted %d" % [battles, PUWRaidRun.BATTLES_BEFORE_FINAL + 1])
		return false
	if run.status != "cleared":
		print("  run status %s, wanted cleared" % run.status)
		return false
	if run.catches.size() != 4:
		print("  catches %d, wanted 4" % run.catches.size())
		return false
	if run.hearts != PUWRaidRun.HEARTS:
		print("  hearts %d, wanted %d (buffed team should not faint)" % [run.hearts, PUWRaidRun.HEARTS])
		return false
	var keep: String = str(run.catches[1])
	var settlement: Dictionary = run.finish(keep)
	if str(settlement.get("kept_species", "")) != keep:
		print("  kept %s, wanted %s" % [str(settlement.get("kept_species", "")), keep])
		return false
	if (settlement.get("released", []) as Array).size() != 3:
		print("  released %d, wanted 3" % (settlement.get("released", []) as Array).size())
		return false
	var expected_ore: int = 4 * PUWRaidRun.ORE_PER_WIN + PUWRaidRun.ORE_CLEAR_BONUS
	if int(settlement.get("dynite_ore", 0)) != expected_ore:
		print("  ore %s, wanted %d" % [str(settlement.get("dynite_ore", 0)), expected_ore])
		return false
	return true


# 12. Endless: locked below 5 clears (sourced), and an Endless
# run keeps nothing (sourced).
func test_run_endless_lock_and_keep_nothing() -> bool:
	var builder := PUWTeamBuilder.new()
	var locked_run := PUWRaidRun.new()
	var locked: Dictionary = locked_run.start({
		"builder": builder, "rng": _rng(22), "level": 50,
		"player_mon": builder.build_mon("pikachu", 50, "singles"),
		"endless": true, "prior_clears": PUWRaidRun.ENDLESS_UNLOCK_CLEARS - 1,
	})
	if str(locked.get("status", "")) != "endless_locked":
		print("  endless below 5 clears gave %s, wanted endless_locked" % str(locked.get("status", "")))
		return false
	var run := PUWRaidRun.new()
	var started: Dictionary = run.start({
		"builder": builder, "rng": _rng(23), "level": 50, "star": 3,
		"player_mon": _buffed(builder.build_mon("pikachu", 50, "singles")),
		"npc_species": ["eevee", "snorlax", "gengar"],
		"endless": true, "prior_clears": PUWRaidRun.ENDLESS_UNLOCK_CLEARS,
	})
	if str(started.get("status", "")) != "started":
		print("  endless run did not start at 5 clears")
		return false
	for e_v in run.entries:
		var e: Dictionary = e_v
		_buffed(e.get("mon", {}))
	var battles: int = 0
	while run.status == "in_progress" and battles < 6:
		run.choose_path(0)
		run.fight_current_battle()
		battles += 1
	if battles < PUWRaidRun.BATTLES_BEFORE_FINAL + 2:
		print("  endless run ended after %d battles; wanted it to continue past the final" % battles)
		return false
	if run.catches.is_empty():
		print("  endless run caught nothing; keep-nothing proof is vacuous")
		return false
	# Force the run's end (a loss) and settle: Endless keeps
	# nothing even when a kept species is named.
	run.status = "run_failed"
	var settlement: Dictionary = run.finish(str(run.catches[0]))
	if str(settlement.get("kept_species", "")) != "":
		print("  endless run kept %s, wanted nothing" % str(settlement.get("kept_species", "")))
		return false
	return (settlement.get("released", []) as Array).size() == run.catches.size()


# 13. Hearts: faints across a run spend the shared 4 hearts;
# losing the raid on faints ends the run with 0 hearts.
func test_run_hearts_and_failure() -> bool:
	var builder := PUWTeamBuilder.new()
	var run := PUWRaidRun.new()
	var started: Dictionary = run.start({
		"builder": builder, "rng": _rng(24), "level": 100, "star": 5,
		"player_mon": builder.build_mon("pikachu", 50, "singles"),
		"npc_species": ["eevee", "snorlax", "gengar"],
	})
	if str(started.get("status", "")) != "started":
		print("  run did not start")
		return false
	# Make every raider frail against the level-100 boss.
	for e_v in run.entries:
		var e: Dictionary = e_v
		var m: Dictionary = e.get("mon", {})
		m["hp"] = 10
		m["max_hp"] = 10
		m["def"] = 10
		m["spd"] = 10
		m["atk"] = 10
		m["spa"] = 10
	run.choose_path(0)
	var result: Dictionary = run.fight_current_battle()
	if str(result.get("status", "")) != "enemy_won":
		print("  frail run battle status %s, wanted enemy_won" % str(result.get("status", "")))
		return false
	if run.status != "run_failed":
		print("  run status %s, wanted run_failed" % run.status)
		return false
	if run.hearts != 0:
		print("  hearts %d after faint-limit loss, wanted 0" % run.hearts)
		return false
	var settlement: Dictionary = run.finish("")
	if str(settlement.get("kept_species", "")) != "" or int(settlement.get("dynite_ore", -1)) != 0:
		print("  failed run settled wrong: %s" % str(settlement))
		return false
	return true


# 14. The simulator's run wrapper: rentals in, settlement out,
# real party untouched.
func test_raid_run_sim_wrapper() -> bool:
	var s: PUWVexaSimulator = _sim()
	var player: Array = [_mon("Pidgey", ["Normal", "Flying"], ["Quick Attack"], 300, 100, 100, 100)]
	var before: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	var result: Dictionary = s.run_raid_run(player, {"level": 30, "seed": 5, "rental_pick": 0})
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  run wrapper status %s" % status)
		return false
	if not bool(result.get("snapshot_unchanged", false)):
		print("  run wrapper changed the snapshot")
		return false
	var after: String = JSON.stringify(PUWSaveManager.build_state(player, [], {}, 0, [], [], [], {}))
	if after != before:
		print("  real save state changed during run")
		return false
	var settlement: Dictionary = result.get("run", {})
	if not settlement.has("dynite_ore") or not settlement.has("kept_species"):
		print("  settlement missing fields: %s" % str(settlement.keys()))
		return false
	return true
