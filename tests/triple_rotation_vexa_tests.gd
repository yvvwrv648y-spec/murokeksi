extends SceneTree
## VEXA Triple + Rotation format tests (code prep
## code_prep_vexa_formats): PUWTripleTargeting's placement
## rules, PUWTripleBattle's turn flow (shift, spread cut,
## replacements, auto-shift), PUWRotationBattle's semantics
## (free rotation, persistence, inactive exemption, forced
## rotation), and PUWVexaSimulator's wiring + safety snapshot
## for both formats.
## Run: godot --headless --script res://tests/triple_rotation_vexa_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW VEXA triple + rotation tests — starting.")
	_run("test_targeting_adjacency", Callable(self, "test_targeting_adjacency"))
	_run("test_targeting_any_ignores_range", Callable(self, "test_targeting_any_ignores_range"))
	_run("test_targeting_spread_classes", Callable(self, "test_targeting_spread_classes"))
	_run("test_targeting_redirect", Callable(self, "test_targeting_redirect"))
	_run("test_spread_mult_values", Callable(self, "test_spread_mult_values"))
	_run("test_triple_setup_positions", Callable(self, "test_triple_setup_positions"))
	_run("test_triple_battle_completes", Callable(self, "test_triple_battle_completes"))
	_run("test_triple_move_fails_when_nothing_in_range", Callable(self, "test_triple_move_fails_when_nothing_in_range"))
	_run("test_triple_shift", Callable(self, "test_triple_shift"))
	_run("test_triple_spread_mult_applied", Callable(self, "test_triple_spread_mult_applied"))
	_run("test_triple_replacement_same_slot", Callable(self, "test_triple_replacement_same_slot"))
	_run("test_triple_auto_shift", Callable(self, "test_triple_auto_shift"))
	_run("test_rotation_setup_fields_three", Callable(self, "test_rotation_setup_fields_three"))
	_run("test_rotation_free_rotate_and_attack", Callable(self, "test_rotation_free_rotate_and_attack"))
	_run("test_rotation_state_persists", Callable(self, "test_rotation_state_persists"))
	_run("test_rotation_only_active_takes_damage", Callable(self, "test_rotation_only_active_takes_damage"))
	_run("test_rotation_inactive_no_status_damage", Callable(self, "test_rotation_inactive_no_status_damage"))
	_run("test_rotation_forced_rotation", Callable(self, "test_rotation_forced_rotation"))
	_run("test_rotation_win_condition", Callable(self, "test_rotation_win_condition"))
	_run("test_formats_status", Callable(self, "test_formats_status"))
	_run("test_sim_triple_runs_and_snapshot", Callable(self, "test_sim_triple_runs_and_snapshot"))
	_run("test_sim_rotation_runs_and_snapshot", Callable(self, "test_sim_rotation_runs_and_snapshot"))
	_run("test_sim_shiny_triple", Callable(self, "test_sim_shiny_triple"))
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


func _mon(species: String, types: Array, moves: Array, hp: int = 300, atk: int = 100, def: int = 100, spe: int = 100) -> Dictionary:
	return {
		"name": species, "species": species, "species_slug": species.to_lower(),
		"level": 50, "hp": hp, "max_hp": hp,
		"atk": atk, "def": def, "spa": atk, "spd": def, "spe": spe,
		"types": types, "ability": "", "item": "", "status": "",
		"moves": moves, "stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}, "shiny": false,
	}


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


func _sim_party() -> Array:
	var party: Array = [
		_player_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"]),
		_player_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"]),
		_player_mon("Blastoise", ["Water"], ["Surf", "Quick Attack"]),
		_player_mon("Venusaur", ["Grass", "Poison"], ["Energy Ball", "Quick Attack"]),
		_player_mon("Snorlax", ["Normal"], ["Body Slam", "Quick Attack"]),
		_player_mon("Gengar", ["Ghost", "Poison"], ["Shadow Ball", "Quick Attack"]),
	]
	for mon_v in party:
		(mon_v as Dictionary)["atk"] = 400
		(mon_v as Dictionary)["spa"] = 400
		(mon_v as Dictionary)["spe"] = 200
	return party


func _field3() -> Dictionary:
	var p: Array = []
	var e: Array = []
	for i in range(3):
		p.append(_mon("P%d" % i, ["Normal"], ["Tackle"]))
		e.append(_mon("E%d" % i, ["Normal"], ["Tackle"]))
	return {"player_active": p, "enemy_active": e}


func _slots_of(targets: Array, side: String) -> Array:
	var out: Array = []
	for t_v in targets:
		var t: Dictionary = t_v
		if str(t.get("side", "")) == side:
			out.append(int(t.get("slot", -1)))
	out.sort()
	return out


func _has_event(events: Array, kind: String) -> bool:
	for e_v in events:
		var e: Dictionary = e_v
		if str(e.get("kind", "")) == kind:
			return true
	return false


func _hits_for(events: Array, move_name: String) -> Array:
	var out: Array = []
	for e_v in events:
		var e: Dictionary = e_v
		if str(e.get("kind", "")) == "hit" and str(e.get("move", "")) == move_name:
			out.append(e)
	return out


# --- Targeting ---------------------------------------------------

func test_targeting_adjacency() -> bool:
	var f: Dictionary = _field3()
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "power": 40, "target": "normal"}
	# Left reaches foe left + center, never foe right.
	if not PUWTripleTargeting.can_target(tackle, 0, "player", "enemy", 0, f):
		return false
	if not PUWTripleTargeting.can_target(tackle, 0, "player", "enemy", 1, f):
		return false
	if PUWTripleTargeting.can_target(tackle, 0, "player", "enemy", 2, f):
		return false
	# Center reaches everyone.
	for slot in range(3):
		if not PUWTripleTargeting.can_target(tackle, 1, "player", "enemy", slot, f):
			return false
	# Right cannot reach foe left.
	if PUWTripleTargeting.can_target(tackle, 2, "player", "enemy", 0, f):
		return false
	# Allies are placement-limited too.
	var ally_move: Dictionary = {"name": "Helping Hand", "type": "Normal", "power": 0, "target": "adjacentAlly"}
	if _slots_of(PUWTripleTargeting.resolve_targets(ally_move, 0, "player", f), "player") != [1]:
		return false
	if _slots_of(PUWTripleTargeting.resolve_targets(ally_move, 1, "player", f), "player") != [0, 2]:
		return false
	# A desired foe outside range falls back to the nearest
	# reachable living foe (the doubles fallback, widened).
	var picked: Array = PUWTripleTargeting.resolve_targets(tackle, 0, "player", f, {"side": "enemy", "slot": 2})
	if picked.size() != 1:
		return false
	var pick: Dictionary = picked[0]
	return str(pick.get("side", "")) == "enemy" and int(pick.get("slot", -1)) == 1


func test_targeting_any_ignores_range() -> bool:
	var f: Dictionary = _field3()
	var pulse: Dictionary = {"name": "Dark Pulse", "type": "Dark", "power": 80, "target": "any"}
	# The aura/pulse exception: corner to far corner is legal.
	if not PUWTripleTargeting.can_target(pulse, 0, "player", "enemy", 2, f):
		return false
	var picked: Array = PUWTripleTargeting.resolve_targets(pulse, 0, "player", f, {"side": "enemy", "slot": 2})
	if picked.size() != 1:
		return false
	var pick: Dictionary = picked[0]
	if str(pick.get("side", "")) != "enemy" or int(pick.get("slot", -1)) != 2:
		return false
	# "any" never targets the user, but a far ALLY is legal.
	if PUWTripleTargeting.can_target(pulse, 0, "player", "player", 0, f):
		return false
	return PUWTripleTargeting.can_target(pulse, 0, "player", "player", 2, f)


func test_targeting_spread_classes() -> bool:
	var f: Dictionary = _field3()
	var slide: Dictionary = {"name": "Rock Slide", "type": "Rock", "power": 75, "target": "allAdjacentFoes"}
	if _slots_of(PUWTripleTargeting.resolve_targets(slide, 0, "player", f), "enemy") != [0, 1]:
		return false
	if _slots_of(PUWTripleTargeting.resolve_targets(slide, 1, "player", f), "enemy") != [0, 1, 2]:
		return false
	if _slots_of(PUWTripleTargeting.resolve_targets(slide, 2, "player", f), "enemy") != [1, 2]:
		return false
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "power": 100, "target": "allAdjacent"}
	var from_center: Array = PUWTripleTargeting.resolve_targets(quake, 1, "player", f)
	if _slots_of(from_center, "enemy") != [0, 1, 2]:
		return false
	if _slots_of(from_center, "player") != [0, 2]:
		return false
	var from_left: Array = PUWTripleTargeting.resolve_targets(quake, 0, "player", f)
	if _slots_of(from_left, "enemy") != [0, 1]:
		return false
	if _slots_of(from_left, "player") != [1]:
		return false
	# The user is never its own allAdjacent target.
	for t_v in from_center:
		var t: Dictionary = t_v
		if str(t.get("side", "")) == "player" and int(t.get("slot", -1)) == 1:
			return false
	return true


func test_targeting_redirect() -> bool:
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "power": 90, "target": "normal"}
	# Lightning Rod in the center draws a bolt aimed at the left
	# foe (the drawing mon is inside the move's range).
	var f: Dictionary = _field3()
	(f["enemy_active"][1] as Dictionary)["ability"] = "Lightning Rod"
	var picked: Array = PUWTripleTargeting.resolve_targets(bolt, 0, "player", f, {"side": "enemy", "slot": 0})
	if picked.size() != 1:
		return false
	var pick: Dictionary = picked[0]
	if int(pick.get("slot", -1)) != 1:
		return false
	# Lightning Rod in the FAR corner cannot draw a
	# range-limited move from the opposite corner.
	var f2: Dictionary = _field3()
	(f2["enemy_active"][2] as Dictionary)["ability"] = "Lightning Rod"
	var picked2: Array = PUWTripleTargeting.resolve_targets(bolt, 0, "player", f2, {"side": "enemy", "slot": 0})
	if picked2.size() != 1:
		return false
	var pick2: Dictionary = picked2[0]
	return int(pick2.get("slot", -1)) == 0


func test_spread_mult_values() -> bool:
	if PUWTripleTargeting.spread_mult(1) != 1.0:
		return false
	if PUWTripleTargeting.spread_mult(2) != 0.75:
		return false
	if PUWTripleTargeting.spread_mult(3) != 0.75:
		return false
	var slide: Dictionary = {"name": "Rock Slide", "type": "Rock", "power": 75, "target": "allAdjacentFoes"}
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "power": 40, "target": "normal"}
	return PUWTripleTargeting.is_spread(slide) and not PUWTripleTargeting.is_spread(tackle)


# --- Triple Battle runner ----------------------------------------

func test_triple_setup_positions() -> bool:
	var player: Array = []
	var enemy: Array = []
	for i in range(6):
		player.append(_mon("P%d" % i, ["Normal"], ["Tackle"]))
		enemy.append(_mon("E%d" % i, ["Normal"], ["Tackle"]))
	var battle := PUWTripleBattle.new()
	var setup: Dictionary = battle.setup_battle(player, enemy, _rng(11))
	if str(setup.get("status", "")) != "started":
		return false
	for slot in range(3):
		if str((battle.player_active[slot] as Dictionary).get("species", "")) != "P%d" % slot:
			return false
		if str((battle.enemy_active[slot] as Dictionary).get("species", "")) != "E%d" % slot:
			return false
	return battle.player_bench.size() == 3 and battle.enemy_bench.size() == 3


func test_triple_battle_completes() -> bool:
	var player: Array = []
	var enemy: Array = []
	for i in range(6):
		player.append(_mon("P%d" % i, ["Normal"], ["Tackle"], 400, 220, 120, 160))
		enemy.append(_mon("E%d" % i, ["Normal"], ["Tackle"], 90, 60, 50, 40))
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(12))
	var guard: int = 0
	while not battle.is_over() and guard < 200:
		guard += 1
		var actions: Array = []
		for slot in range(3):
			actions.append(battle.choose_ai_action(true, slot))
		battle.run_turn(actions)
	return battle.status == "player_won"


func test_triple_move_fails_when_nothing_in_range() -> bool:
	var player: Array = [
		_mon("Lefty", ["Normal"], ["Tackle"], 500, 100, 100, 300),
		_mon("Mid", ["Normal"], ["Tackle"], 500),
		_mon("Right", ["Normal"], ["Tackle"], 500),
	]
	var enemy: Array = [
		_mon("E0", ["Normal"], [], 500),
		_mon("E1", ["Normal"], [], 500),
		_mon("FarTank", ["Normal"], [], 500),
	]
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(13))
	# Only the far-corner foe is left standing: from the left
	# corner, a range-limited move has no legal target at all.
	(battle.enemy_active[0] as Dictionary)["hp"] = 0
	(battle.enemy_active[1] as Dictionary)["hp"] = 0
	var actions: Array = [
		{"type": "move", "move_name": "Tackle", "target_side": "enemy", "target_slot": 2},
		{"type": "none"}, {"type": "none"},
	]
	var result: Dictionary = battle.run_turn(actions)
	var events: Array = result.get("events", [])
	if not _has_event(events, "move_failed"):
		return false
	return int((battle.enemy_active[2] as Dictionary).get("hp", 0)) == 500


func test_triple_shift() -> bool:
	var player: Array = [
		_mon("Shifter", ["Normal"], ["Tackle"], 500),
		_mon("CenterMon", ["Normal"], ["Tackle"], 500),
		_mon("RightMon", ["Normal"], ["Tackle"], 500),
	]
	var enemy: Array = [
		_mon("E0", ["Normal"], [], 500),
		_mon("E1", ["Normal"], [], 500),
		_mon("E2", ["Normal"], [], 500),
	]
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(14))
	(battle.player_active[0] as Dictionary)["stages"] = {"atk": 2, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var result: Dictionary = battle.run_turn([{"type": "shift"}, {"type": "none"}, {"type": "none"}])
	var events: Array = result.get("events", [])
	if not _has_event(events, "shift"):
		return false
	# The shift replaced the move: nobody was hit this turn.
	if _has_event(events, "hit"):
		return false
	if str((battle.player_active[1] as Dictionary).get("species", "")) != "Shifter":
		return false
	if str((battle.player_active[0] as Dictionary).get("species", "")) != "CenterMon":
		return false
	# A shift is not a switch: stat stages ride along.
	var stages: Dictionary = (battle.player_active[1] as Dictionary).get("stages", {})
	return int(stages.get("atk", 0)) == 2


func test_triple_spread_mult_applied() -> bool:
	# Three living targets: every Rock Slide hit carries the
	# 0.75 spread cut.
	var player: Array = [
		_mon("P0", ["Normal"], [], 500),
		_mon("Quaker", ["Rock"], ["Rock Slide"], 500, 150, 100, 300),
		_mon("P2", ["Normal"], [], 500),
	]
	var enemy: Array = [
		_mon("E0", ["Normal"], [], 1000),
		_mon("E1", ["Normal"], [], 1000),
		_mon("E2", ["Normal"], [], 1000),
	]
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(15))
	var actions: Array = [{"type": "none"}, {"type": "move", "move_name": "Rock Slide"}, {"type": "none"}]
	var result: Dictionary = battle.run_turn(actions)
	var hits: Array = _hits_for(result.get("events", []), "Rock Slide")
	if hits.size() != 3:
		return false
	for h_v in hits:
		var h: Dictionary = h_v
		if absf(float(h.get("mult", 1.0)) - 0.75) > 0.001:
			return false
	# One living target at execution: no cut.
	var battle2 := PUWTripleBattle.new()
	battle2.setup_battle(player.duplicate(true), enemy.duplicate(true), _rng(16))
	(battle2.enemy_active[0] as Dictionary)["hp"] = 0
	(battle2.enemy_active[2] as Dictionary)["hp"] = 0
	var result2: Dictionary = battle2.run_turn(actions)
	var hits2: Array = _hits_for(result2.get("events", []), "Rock Slide")
	if hits2.size() != 1:
		return false
	var only: Dictionary = hits2[0]
	return absf(float(only.get("mult", 0.0)) - 1.0) < 0.001


func test_triple_replacement_same_slot() -> bool:
	var player: Array = [
		_mon("GhostA", ["Ghost"], [], 500),
		_mon("Fragile", ["Normal"], [], 30),
		_mon("GhostB", ["Ghost"], [], 500),
		_mon("BenchMon", ["Normal"], [], 400),
	]
	var enemy: Array = [
		_mon("E0", ["Normal"], [], 500),
		_mon("Killer", ["Normal"], ["Tackle"], 500, 250, 100, 300),
		_mon("E2", ["Normal"], [], 500),
	]
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(17))
	# Killer's Tackle cannot touch the Ghost corners, so the AI
	# aims at Fragile in the center and knocks it out.
	battle.run_turn([{"type": "none"}, {"type": "none"}, {"type": "none"}])
	# The bench mon enters at end of turn, in the vacated slot,
	# untouched by the turn's fighting.
	if str((battle.player_active[1] as Dictionary).get("species", "")) != "BenchMon":
		return false
	if int((battle.player_active[1] as Dictionary).get("hp", 0)) != 400:
		return false
	if battle.player_out.size() != 1:
		return false
	return str((battle.player_out[0] as Dictionary).get("species", "")) == "Fragile"


func test_triple_auto_shift() -> bool:
	var player: Array = [
		_mon("PL", ["Normal"], [], 500),
		_mon("PC", ["Normal"], [], 500),
		_mon("PR", ["Normal"], [], 500),
	]
	var enemy: Array = [
		_mon("EL", ["Normal"], [], 500),
		_mon("EC", ["Normal"], [], 500),
		_mon("ER", ["Normal"], [], 500),
	]
	var battle := PUWTripleBattle.new()
	battle.setup_battle(player, enemy, _rng(18))
	# One survivor per side, in opposite corners.
	(battle.player_active[0] as Dictionary)["hp"] = 0
	(battle.player_active[1] as Dictionary)["hp"] = 0
	(battle.enemy_active[1] as Dictionary)["hp"] = 0
	(battle.enemy_active[2] as Dictionary)["hp"] = 0
	var result: Dictionary = battle.run_turn([{"type": "none"}, {"type": "none"}, {"type": "none"}])
	if not _has_event(result.get("events", []), "auto_shift"):
		return false
	if str((battle.player_active[1] as Dictionary).get("species", "")) != "PR":
		return false
	if str((battle.enemy_active[1] as Dictionary).get("species", "")) != "EL":
		return false
	return (battle.player_active[2] as Dictionary).is_empty() and (battle.enemy_active[0] as Dictionary).is_empty()


# --- Rotation Battle runner --------------------------------------

func test_rotation_setup_fields_three() -> bool:
	var party: Array = []
	for i in range(6):
		party.append(_mon("R%d" % i, ["Normal"], ["Tackle"]))
	var battle := PUWRotationBattle.new()
	var setup: Dictionary = battle.setup_battle(party, party.duplicate(true), _rng(21))
	if str(setup.get("status", "")) != "started":
		return false
	if battle.player_fielded.size() != 3:
		return false
	if str(battle.active_mon(true).get("species", "")) != "R0":
		return false
	# The rest of the party does not participate.
	for entry_v in battle.player_fielded:
		var entry: Dictionary = entry_v
		if str(entry.get("species", "")) in ["R3", "R4", "R5"]:
			return false
	var small := PUWRotationBattle.new()
	small.setup_battle(party.slice(0, 2), party.slice(0, 2), _rng(22))
	return small.player_fielded.size() == 2


func test_rotation_free_rotate_and_attack() -> bool:
	var player: Array = [
		_mon("Weakling", ["Normal"], ["Tackle"], 300, 100, 100, 40),
		_mon("Striker", ["Fire"], ["Flamethrower"], 300, 180, 100, 160),
		_mon("Third", ["Normal"], ["Tackle"], 300),
	]
	var enemy: Array = [
		_mon("GrassMon", ["Grass"], ["Tackle"], 300, 100, 80, 90),
		_mon("E1", ["Grass"], ["Tackle"], 300),
		_mon("E2", ["Grass"], ["Tackle"], 300),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(23))
	# Rotation is free: the rotated-in mon still attacks on the
	# same turn.
	battle.run_turn({"rotate_to": 1, "move_name": "Flamethrower"})
	if battle.player_active_idx != 1:
		return false
	return int(battle.active_mon(false).get("hp", 0)) < 300


func test_rotation_state_persists() -> bool:
	var player: Array = [
		_mon("Stager", ["Normal"], ["Tackle"], 200),
		_mon("Other", ["Normal"], ["Tackle"], 300),
		_mon("Third", ["Normal"], ["Tackle"], 300),
	]
	var enemy: Array = [
		_mon("Bag", ["Normal"], [], 500),
		_mon("E1", ["Normal"], [], 500),
		_mon("E2", ["Normal"], [], 500),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(24))
	(battle.player_fielded[0] as Dictionary)["hp"] = 150
	(battle.player_fielded[0] as Dictionary)["stages"] = {"atk": 2, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var before: String = JSON.stringify(battle.player_fielded[0])
	battle.run_turn({"rotate_to": 1, "move_name": ""})
	# Rotating out touched nothing at all on the mon's record.
	if JSON.stringify(battle.player_fielded[0]) != before:
		return false
	battle.run_turn({"rotate_to": 0, "move_name": ""})
	if battle.player_active_idx != 0:
		return false
	var stages: Dictionary = (battle.player_fielded[0] as Dictionary).get("stages", {})
	if int(stages.get("atk", 0)) != 2:
		return false
	return int((battle.player_fielded[0] as Dictionary).get("hp", 0)) == 150


func test_rotation_only_active_takes_damage() -> bool:
	var player: Array = [
		_mon("Front", ["Normal"], ["Tackle"], 300, 100, 100, 100),
		_mon("Back1", ["Normal"], ["Tackle"], 300),
		_mon("Back2", ["Normal"], ["Tackle"], 300),
	]
	var enemy: Array = [
		_mon("Quaker", ["Ground"], ["Earthquake"], 400, 180, 100, 90),
		_mon("E1", ["Normal"], ["Tackle"], 300),
		_mon("E2", ["Normal"], ["Tackle"], 300),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(25))
	battle.run_turn({})
	# Earthquake is a multi-target move in singles terms; in a
	# Rotation Battle it can only ever reach the active mon.
	if int((battle.player_fielded[0] as Dictionary).get("hp", 0)) >= 300:
		return false
	if int((battle.player_fielded[1] as Dictionary).get("hp", 0)) != 300:
		return false
	return int((battle.player_fielded[2] as Dictionary).get("hp", 0)) == 300


func test_rotation_inactive_no_status_damage() -> bool:
	var player: Array = [
		_mon("Front", ["Normal"], [], 300),
		_mon("Poisoned", ["Poison"], [], 200),
		_mon("Third", ["Normal"], [], 300),
	]
	var enemy: Array = [
		_mon("Bag", ["Normal"], [], 500),
		_mon("E1", ["Normal"], [], 500),
		_mon("E2", ["Normal"], [], 500),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(26))
	(battle.player_fielded[1] as Dictionary)["status"] = "PSN"
	# Inactive: poison does not tick.
	battle.run_turn({})
	if int((battle.player_fielded[1] as Dictionary).get("hp", 0)) != 200:
		return false
	# Active: the same poison ticks for max_hp / 8 = 25.
	battle.run_turn({"rotate_to": 1, "move_name": ""})
	return int((battle.player_fielded[1] as Dictionary).get("hp", 0)) == 175


func test_rotation_forced_rotation() -> bool:
	var player: Array = [
		_mon("Frail", ["Normal"], ["Tackle"], 1, 100, 100, 10),
		_mon("Second", ["Fire"], ["Flamethrower"], 300, 180, 100, 120),
		_mon("Third", ["Normal"], ["Tackle"], 300),
	]
	var enemy: Array = [
		_mon("Bruiser", ["Normal"], ["Tackle"], 300, 250, 80, 300),
		_mon("E1", ["Normal"], ["Tackle"], 300),
		_mon("E2", ["Normal"], ["Tackle"], 300),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(27))
	battle.run_turn({"move_name": "Tackle"})
	if int((battle.player_fielded[0] as Dictionary).get("hp", 0)) != 0:
		return false
	if battle.status != "ongoing":
		return false
	# No rotate_to given: the runner must rotate the next living
	# mon in, and that mon still gets its move.
	var result: Dictionary = battle.run_turn({"move_name": "Flamethrower"})
	var forced: bool = false
	for e_v in result.get("events", []):
		var e: Dictionary = e_v
		if str(e.get("kind", "")) == "rotate" and bool(e.get("forced", false)):
			forced = true
	if not forced:
		return false
	if battle.player_active_idx != 1:
		return false
	return int(battle.active_mon(false).get("hp", 0)) < 300


func test_rotation_win_condition() -> bool:
	var player: Array = [
		_mon("F1", ["Normal"], ["Tackle"], 1),
		_mon("F2", ["Normal"], ["Tackle"], 1),
		_mon("F3", ["Normal"], ["Tackle"], 1),
	]
	var enemy: Array = [
		_mon("Bruiser", ["Normal"], ["Tackle"], 500, 250, 100, 300),
		_mon("E1", ["Normal"], ["Tackle"], 500),
		_mon("E2", ["Normal"], ["Tackle"], 500),
	]
	var battle := PUWRotationBattle.new()
	battle.setup_battle(player, enemy, _rng(28))
	var guard: int = 0
	while not battle.is_over() and guard < 10:
		guard += 1
		battle.run_turn({})
	return battle.status == "enemy_won"


# --- Simulator wiring ----------------------------------------------

func test_formats_status() -> bool:
	var bare := PUWVexaSimulator.new()
	if bare.format_status("triple") != "built":
		return false
	if bare.format_status("rotation") != "built":
		return false
	# COMPOSED UPDATE (composed G4 state): tera_raid is built too.
	if bare.format_status("tera_raid") != "built":
		return false
	if bare.format_status("bogus") != "unknown_format":
		return false
	if bare.engine_format("triple") != "triple":
		return false
	if bare.engine_format("rotation") != "rotation":
		return false
	if bare.engine_format("tera_raid") != "raid":
		return false
	var supported: Array = bare.supported_formats()
	if not supported.has("triple") or not supported.has("rotation"):
		return false
	if not supported.has("tera_raid"):
		return false
	# Without a host the new formats refuse exactly like the old.
	var party: Array = _sim_party()
	var no_host: Dictionary = bare.run_simulation(party, {"format": "triple"})
	if str(no_host.get("status", "")) != "no_host":
		return false
	var hosted := _sim()
	var raid: Dictionary = hosted.run_simulation(party, {"format": "tera_raid"})
	if str(raid.get("status", "")) in ["not_yet_built", "unknown_format"]:
		return false
	var bogus: Dictionary = hosted.run_simulation(party, {"format": "bogus"})
	return str(bogus.get("status", "")) == "unknown_format"


func test_sim_triple_runs_and_snapshot() -> bool:
	var party: Array = _sim_party()
	var before: String = JSON.stringify(party)
	var res: Dictionary = _sim().run_simulation(party, {"format": "triple", "opponent": "counter", "level": 50, "seed": 7})
	if not (str(res.get("status", "")) in ["player_won", "enemy_won"]):
		return false
	if not bool(res.get("snapshot_unchanged", false)):
		return false
	if (res.get("enemy_species", []) as Array).size() != 6:
		return false
	if not res.has("triple"):
		return false
	# The live party was never battled: byte-identical after.
	return JSON.stringify(party) == before


func test_sim_rotation_runs_and_snapshot() -> bool:
	var party: Array = _sim_party()
	var before: String = JSON.stringify(party)
	var res: Dictionary = _sim().run_simulation(party, {"format": "rotation", "opponent": "counter", "level": 50, "seed": 9})
	if not (str(res.get("status", "")) in ["player_won", "enemy_won"]):
		return false
	if not bool(res.get("snapshot_unchanged", false)):
		return false
	if not res.has("rotation"):
		return false
	var rot: Dictionary = res.get("rotation", {})
	if (rot.get("player_fielded", []) as Array).size() != 3:
		return false
	return JSON.stringify(party) == before


func test_sim_shiny_triple() -> bool:
	var party: Array = _sim_party()
	var res: Dictionary = _sim().run_simulation(party, {"format": "triple", "opponent": "counter", "level": 50, "seed": 3, "shiny": true})
	for mon_v in res.get("enemy_team", []):
		if not bool((mon_v as Dictionary).get("shiny", false)):
			return false
	for mon_v2 in party:
		if bool((mon_v2 as Dictionary).get("shiny", false)):
			return false
	return true
