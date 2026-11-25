class_name PUWTripleBattle
extends RefCounted
## PUWTripleBattle — one Triple Battle for VEXA (gap G4).
##
## Rules are the official Generation V / VI Triple Battle rules
## (Pokemon Black and White onward), as documented on
## Bulbapedia, "Triple Battle" (read 2026-11-23 for this prep),
## plus the project's own move data:
## - Three Pokemon per side on the field. They are sent out in
##   party order: "the first Pokemon able to battle in the party
##   becomes the leftmost Pokemon on the field, the second
##   becomes the center Pokemon, and the third becomes the
##   Pokemon on the far right." The rest of the party is the
##   bench (Triple Battles use the whole party — all six are
##   selected even under the Flat Rule).
## - Placement decides range: see PUWTripleTargeting, which
##   holds the targeting rules and their sources.
## - Shifting: a Pokemon in the left or right position may
##   shift — swap places with the Pokemon in the middle (or
##   move into the middle when it is empty). Shifting is an
##   action INSTEAD of a move for that Pokemon, with priority 0
##   like a normal move, ordered by Speed (Bulbapedia: shifting
##   "has no priority"; the gamerguides battle guide: "instead
##   of using a move... when it reaches their turn, the two
##   Pokemon switch places"). None of the effects of switching
##   apply: stat modifiers, volatile conditions and battle
##   statuses all stay, no entry hazards trigger, no switch-in
##   or switch-out Ability fires. A Pokemon in the center
##   cannot shift. A move whose target is out of range when the
##   move executes fails — including because a shift moved
##   someone first.
## - Fainted Pokemon are replaced at the END of the turn, after
##   every action has resolved, into the exact position they
##   vacated (the multi-battle convention documented for Double
##   Battles in the gamerguides battle guide: replacements come
##   "not immediately after they faint, but before anyone else
##   performs their action" of the next turn). In this runner
##   the replacement is the first living bench Pokemon in party
##   order: in the games the Trainer chooses, and the choice is
##   a UI concern; the sim rule is stated here plainly.
## - End-of-turn auto-shift: "If there are only two Pokemon
##   left on the field and they are non-adjacent to each other,
##   both Pokemon will automatically be shifted to the center
##   of the field at the end of the turn" (Bulbapedia) — the
##   1-vs-1 endgame at opposite corners, where neither could
##   ever reach the other.
##
## Damage is never invented: every hit is priced by
## PUWBattleEngine.calculate_damage, turn order comes from
## TurnResolver (the same comparator the doubles controller
## uses, run over six combatants), move data comes from
## MoveDatabase, and target classes come from the "target"
## field of res://data/moves.json (the 954 Showdown moves).
##
## Simplifications, stated plainly (the same class as
## PUWRaidBattle's): accuracy is not rolled; PP is not tracked;
## non-damaging moves have no engine effect here (secondary
## effects, stat stages from moves, hazards and field moves
## live in MoveEffects / the controller layer); switch-in
## Abilities do not fire (AbilityEngine's layer — so the
## Triple Battle rule that Intimidate only hits adjacent foes
## matters only once that layer runs these battles); gimmicks
## are not offered (the controller owns them). End-of-turn
## status and weather damage DOES run, through the project's
## own StatusAndFieldEngine.apply_end_of_turn, because a
## format runner that ignores a poisoned Pokemon's tick would
## misreport real battles.
##
## Safety: setup_battle deep-copies both parties unless the
## caller passes copy_mons=false (PUWVexaSimulator does, with
## copies it made itself). The engine never touches a save and
## never calls PartyAndStorageManager.handle_faint: a faint
## here is a sim faint and retires nothing.

const SLOT_COUNT: int = 3
const CENTER_SLOT: int = 1

var player_active: Array = [] ## Exactly 3 entries: a mon dict, or {} for an empty slot.
var enemy_active: Array = []
var player_bench: Array = []
var enemy_bench: Array = []
var player_out: Array = [] ## Fainted mons, kept for reporting.
var enemy_out: Array = []
var turn: int = 0
var status: String = "ongoing" ## "ongoing" | "player_won" | "enemy_won" | "not_started"
var logs: Array = []
var field: Dictionary = {}

var _rng: RandomNumberGenerator = null
var _move_db: MoveDatabase = null
var _target_classes: Dictionary = {}
var _targets_loaded: bool = false


static func _mon_name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))


## Set up one Triple Battle. The first three living mons of
## each party take slots 0, 1, 2 in order; the remaining living
## mons form the bench; mons already fainted are set aside.
## Returns {"status": "started"} or {"status": "not_started"}
## when a side has no living Pokemon at all.
func setup_battle(player_party: Array, enemy_party: Array, rng: RandomNumberGenerator, copy_mons: bool = true) -> Dictionary:
	if rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = rng
	field = StatusAndFieldEngine.create_field_state()
	turn = 0
	logs = []
	player_active = _split_party(player_party, copy_mons, player_bench, player_out)
	enemy_active = _split_party(enemy_party, copy_mons, enemy_bench, enemy_out)
	if _side_living_count(true) == 0 or _side_living_count(false) == 0:
		status = "not_started"
		return {"status": "not_started"}
	status = "ongoing"
	return {"status": "started"}


## Split one party into [actives (padded to 3), bench, out].
## bench_out and out_out are filled by reference through the
## return's side arrays: this helper returns the actives and
## appends to the two arrays passed in.
func _split_party(party: Array, copy_mons: bool, bench_out: Array, out_out: Array) -> Array:
	var actives: Array = []
	bench_out.clear()
	out_out.clear()
	for entry_v in party:
		if not (entry_v is Dictionary):
			continue
		var mon: Dictionary = entry_v
		if copy_mons:
			mon = mon.duplicate(true)
		if int(mon.get("hp", 0)) <= 0:
			out_out.append(mon)
		elif actives.size() < SLOT_COUNT:
			actives.append(mon)
		else:
			bench_out.append(mon)
	while actives.size() < SLOT_COUNT:
		actives.append({})
	return actives


func _actives_of(is_player: bool) -> Array:
	return player_active if is_player else enemy_active


func _bench_of(is_player: bool) -> Array:
	return player_bench if is_player else enemy_bench


func _out_of(is_player: bool) -> Array:
	return player_out if is_player else enemy_out


func _mon_at(is_player: bool, slot: int) -> Dictionary:
	var actives: Array = _actives_of(is_player)
	if slot < 0 or slot >= actives.size():
		return {}
	var mon: Dictionary = actives[slot]
	return mon


func _side_living_count(is_player: bool) -> int:
	var count: int = 0
	for entry_v in _actives_of(is_player):
		if entry_v is Dictionary:
			var mon: Dictionary = entry_v
			if not mon.is_empty() and int(mon.get("hp", 0)) > 0:
				count += 1
	for entry_v2 in _bench_of(is_player):
		if entry_v2 is Dictionary:
			var mon2: Dictionary = entry_v2
			if int(mon2.get("hp", 0)) > 0:
				count += 1
	return count


## Everyone on one side, for reporting: actives in slot order
## (empty slots skipped), then the bench, then the fainted.
func party_of(is_player: bool) -> Array:
	var out: Array = []
	for entry_v in _actives_of(is_player):
		if entry_v is Dictionary:
			var mon: Dictionary = entry_v
			if not mon.is_empty():
				out.append(mon)
	out.append_array(_bench_of(is_player))
	out.append_array(_out_of(is_player))
	return out


func is_over() -> bool:
	return status != "ongoing"


func battle_result() -> Dictionary:
	var p_names: Array = []
	var e_names: Array = []
	for slot in range(SLOT_COUNT):
		var pm: Dictionary = _mon_at(true, slot)
		p_names.append("" if pm.is_empty() else _mon_name(pm))
		var em: Dictionary = _mon_at(false, slot)
		e_names.append("" if em.is_empty() else _mon_name(em))
	return {
		"status": status, "turns": turn,
		"player_active": p_names, "enemy_active": e_names,
		"player_party": party_of(true), "enemy_party": party_of(false),
		"logs": logs,
	}


## --- Move data -------------------------------------------------

func _slug(move_name: String) -> String:
	return move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "")


func _ensure_target_classes() -> void:
	if _targets_loaded:
		return
	_targets_loaded = true
	var path: String = "res://data/moves.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var root: Dictionary = parsed
		var moves_v: Variant = root.get("moves", {})
		if moves_v is Dictionary:
			var moves: Dictionary = moves_v
			for slug_v in moves.keys():
				var entry_v: Variant = moves[slug_v]
				if entry_v is Dictionary:
					var entry: Dictionary = entry_v
					_target_classes[str(slug_v)] = str(entry.get("target", "normal"))


## The move dict the engine prices with (MoveDatabase, the same
## source every other VEXA path uses), plus the "target" class
## from the 954-move data. A move with no entry there defaults
## to "normal", DoublesTargeting's unknown-target rule.
func _move_data(move_name: String) -> Dictionary:
	if _move_db == null:
		_move_db = MoveDatabase.new()
		_move_db.load_database()
	var md: Dictionary = _move_db.get_move(move_name).duplicate(true)
	md["name"] = move_name
	_ensure_target_classes()
	md["target"] = str(_target_classes.get(_slug(move_name), "normal"))
	return md


func _field_view() -> Dictionary:
	return {"player_active": player_active, "enemy_active": enemy_active}


## The current slot of one exact mon dict on one side, or -1
## when it is not on the field (switched out, or fainted and
## replaced). Identity is by reference (is_same): two identical
## dicts must never be confused after a shift.
func _locate(is_player: bool, mon: Dictionary) -> int:
	var actives: Array = _actives_of(is_player)
	for slot in range(SLOT_COUNT):
		var cand: Dictionary = actives[slot]
		if not cand.is_empty() and is_same(cand, mon):
			return slot
	return -1


## --- The sim AI ------------------------------------------------
## One simple driver brain for both sides (PUWVexaSimulator
## uses it for the player's slots too): the first damaging move
## that is not immune against at least one foe the mon can
## legally reach, aimed at that foe. Mirrors the singles
## driver's _pick_move rule. The AI never shifts and never
## switches: shifting is exercised directly in the tests, and a
## driver that repositions would make sim outcomes harder to
## reason about — stated plainly, not hidden.

func choose_ai_action(is_player: bool, slot: int) -> Dictionary:
	var mon: Dictionary = _mon_at(is_player, slot)
	if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
		return {"type": "none"}
	var side_name: String = "player" if is_player else "enemy"
	var moves: Array = mon.get("moves", [])
	for move_v in moves:
		var move_name: String = str(move_v)
		var md: Dictionary = _move_data(move_name)
		if int(md.get("power", 0)) <= 0:
			continue
		var legal: Array = PUWTripleTargeting.legal_single_targets(md, slot, side_name, _field_view())
		for t_v in legal:
			var t: Dictionary = t_v
			if str(t.get("side", "")) == side_name:
				continue
			var foe: Dictionary = _mon_at(not is_player, int(t.get("slot", 0)))
			var foe_types := PackedStringArray()
			for tv in foe.get("types", []):
				foe_types.append(str(tv))
			if PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), foe_types) > 0.0:
				return {"type": "move", "move_name": move_name, "target_side": str(t.get("side", "")), "target_slot": int(t.get("slot", 0))}
	for move_v2 in moves:
		var move_name2: String = str(move_v2)
		var md2: Dictionary = _move_data(move_name2)
		var resolved: Array = PUWTripleTargeting.resolve_targets(md2, slot, side_name, _field_view(), {})
		for t2_v in resolved:
			var t2: Dictionary = t2_v
			if str(t2.get("side", "")) != side_name:
				return {"type": "move", "move_name": move_name2, "target_side": str(t2.get("side", "")), "target_slot": int(t2.get("slot", 0))}
	return {"type": "none"}


## --- Turn flow -------------------------------------------------

func _combatant(mon: Dictionary, action: Dictionary, is_player: bool, slot: int) -> Dictionary:
	var move: Dictionary = {"name": str(action.get("type", "none")), "priority": 0}
	var atype: String = str(action.get("type", "none"))
	if atype == "move":
		move = _move_data(str(action.get("move_name", "")))
	elif atype == "switch":
		# Switching keeps its usual priority bracket (the main
		# controller's _action_move gives switches priority 6).
		move = {"name": "switch", "priority": 6}
	# A shift keeps priority 0: it is ordered by Speed like a
	# normal move (sourced, see the header).
	return {"mon": mon, "move": move, "side": "player" if is_player else "enemy", "slot": slot, "action": action}


## One full Triple Battle turn. player_actions holds one action
## per player slot, in slot order; each is {"type": "move",
## "move_name": ..., "target_side": ..., "target_slot": ...},
## {"type": "shift"}, {"type": "switch", "target_idx": bench
## index}, or {"type": "none"}. The enemy's actions come from
## choose_ai_action. Returns {"status", "logs", "turn",
## "events"}; events are structured records (hit / faint /
## shift / switch / move_failed / sent_out / auto_shift) so
## callers and tests can verify mechanics without parsing logs.
func run_turn(player_actions: Array) -> Dictionary:
	var turn_logs: Array = []
	var events: Array = []
	if status != "ongoing":
		return {"status": status, "logs": turn_logs, "turn": turn, "events": events}
	turn += 1
	var combatants: Array = []
	for slot in range(SLOT_COUNT):
		var p_mon: Dictionary = _mon_at(true, slot)
		if not p_mon.is_empty() and int(p_mon.get("hp", 0)) > 0:
			var p_action: Dictionary = {"type": "none"}
			if slot < player_actions.size() and player_actions[slot] is Dictionary:
				p_action = player_actions[slot]
			combatants.append(_combatant(p_mon, p_action, true, slot))
	for slot2 in range(SLOT_COUNT):
		var e_mon: Dictionary = _mon_at(false, slot2)
		if not e_mon.is_empty() and int(e_mon.get("hp", 0)) > 0:
			combatants.append(_combatant(e_mon, choose_ai_action(false, slot2), false, slot2))
	for c_v in combatants:
		var c: Dictionary = c_v
		var c_mon: Dictionary = c.get("mon", {})
		c_mon["field"] = field
		c_mon["side"] = str(c.get("side", ""))
	var order: Array = TurnResolver.resolve_order_4(combatants, field)
	for c2_v in order:
		var c2: Dictionary = c2_v
		var mon2: Dictionary = c2.get("mon", {})
		if int(mon2.get("hp", 0)) <= 0:
			continue
		var is_player2: bool = str(c2.get("side", "")) == "player"
		var action2: Dictionary = c2.get("action", {"type": "none"})
		_execute_action(action2, mon2, is_player2, turn_logs, events)
		if _battle_over_now():
			break
	if status == "ongoing":
		_end_of_turn(turn_logs, events)
	logs.append_array(turn_logs)
	return {"status": status, "logs": turn_logs, "turn": turn, "events": events}


func _execute_action(action: Dictionary, mon: Dictionary, is_player: bool, turn_logs: Array, events: Array) -> void:
	var atype: String = str(action.get("type", "none"))
	if atype == "shift":
		_execute_shift(mon, is_player, turn_logs, events)
	elif atype == "switch":
		_execute_switch(mon, is_player, int(action.get("target_idx", -1)), turn_logs, events)
	elif atype == "move":
		_execute_move(mon, is_player, str(action.get("move_name", "")), action, turn_logs, events)


## Shift: swap with the center slot. The mon dicts themselves
## are untouched — stat stages, status and volatiles all ride
## along, because nothing about a shift is a switch.
func _execute_shift(mon: Dictionary, is_player: bool, turn_logs: Array, events: Array) -> void:
	var slot: int = _locate(is_player, mon)
	if slot < 0 or slot == CENTER_SLOT:
		turn_logs.append("%s couldn't shift!" % _mon_name(mon))
		events.append({"kind": "shift_failed", "side": "player" if is_player else "enemy", "slot": slot})
		return
	var actives: Array = _actives_of(is_player)
	var center: Dictionary = actives[CENTER_SLOT]
	actives[CENTER_SLOT] = mon
	actives[slot] = center
	turn_logs.append("%s shifted position!" % _mon_name(mon))
	events.append({"kind": "shift", "side": "player" if is_player else "enemy", "from": slot, "to": CENTER_SLOT})


## An ordinary switch with a bench Pokemon (legal in Triple
## Battles, as in every format). The outgoing mon goes to the
## bench; the incoming mon does not act this turn.
func _execute_switch(mon: Dictionary, is_player: bool, bench_idx: int, turn_logs: Array, events: Array) -> void:
	var slot: int = _locate(is_player, mon)
	var bench: Array = _bench_of(is_player)
	if slot < 0 or bench_idx < 0 or bench_idx >= bench.size():
		turn_logs.append("%s couldn't switch!" % _mon_name(mon))
		return
	var incoming: Dictionary = bench[bench_idx]
	if incoming.is_empty() or int(incoming.get("hp", 0)) <= 0:
		turn_logs.append("%s couldn't switch!" % _mon_name(mon))
		return
	var actives: Array = _actives_of(is_player)
	bench[bench_idx] = mon
	actives[slot] = incoming
	turn_logs.append("%s was switched out. Go, %s!" % [_mon_name(mon), _mon_name(incoming)])
	events.append({"kind": "switch", "side": "player" if is_player else "enemy", "slot": slot})


func _execute_move(mon: Dictionary, is_player: bool, move_name: String, action: Dictionary, turn_logs: Array, events: Array) -> void:
	var slot: int = _locate(is_player, mon)
	if slot < 0:
		# The mon was switched out before its turn came: its
		# move is lost, as in the games.
		return
	var move: Dictionary = _move_data(move_name)
	var side_name: String = "player" if is_player else "enemy"
	var desired: Dictionary = {}
	if action.has("target_side") or action.has("target_slot"):
		var default_side: String = "enemy" if is_player else "player"
		desired = {"side": str(action.get("target_side", default_side)), "slot": int(action.get("target_slot", slot))}
	var targets: Array = PUWTripleTargeting.resolve_targets(move, slot, side_name, _field_view(), desired)
	turn_logs.append("%s used %s!" % [_mon_name(mon), move_name])
	if targets.is_empty():
		# No legal target — most often the intended target is
		# outside the user's range when the move executes (the
		# sourced failure case, shifts included).
		turn_logs.append("But it failed!")
		events.append({"kind": "move_failed", "side": side_name, "slot": slot, "move": move_name, "user": _mon_name(mon)})
		return
	var mult: float = PUWTripleTargeting.spread_mult(targets.size())
	for t_v in targets:
		var t: Dictionary = t_v
		var t_side: String = str(t.get("side", ""))
		var t_slot: int = int(t.get("slot", 0))
		var t_mon: Dictionary = _mon_at(t_side == "player", t_slot)
		if t_mon.is_empty() or int(t_mon.get("hp", 0)) <= 0:
			continue
		if int(move.get("power", 0)) <= 0:
			events.append({"kind": "no_effect", "side": t_side, "slot": t_slot, "move": move_name, "user": _mon_name(mon)})
			continue
		var result: Dictionary = PUWBattleEngine.calculate_damage(mon, t_mon, move, _rng)
		var dmg: int = int(result.get("damage", 0))
		if mult < 1.0:
			dmg = int(float(dmg) * mult)
		t_mon["hp"] = maxi(0, int(t_mon.get("hp", 0)) - dmg)
		events.append({"kind": "hit", "side": t_side, "slot": t_slot, "move": move_name, "user": _mon_name(mon), "damage": dmg, "mult": mult, "effectiveness": float(result.get("effectiveness", 1.0)), "critical": bool(result.get("critical", false))})
		if int(t_mon.get("hp", 0)) <= 0:
			turn_logs.append("%s fainted!" % _mon_name(t_mon))
			events.append({"kind": "faint", "side": t_side, "slot": t_slot})


## End of turn, in the games' order of business for this
## runner: status / weather ticks for the living actives,
## replacements into the vacated slots, then the auto-shift.
func _end_of_turn(turn_logs: Array, events: Array) -> void:
	for is_player_v in [true, false]:
		var is_player: bool = bool(is_player_v)
		var actives: Array = _actives_of(is_player)
		for slot in range(SLOT_COUNT):
			var mon: Dictionary = actives[slot]
			if not mon.is_empty() and int(mon.get("hp", 0)) > 0:
				var tick_logs: Array = StatusAndFieldEngine.apply_end_of_turn(mon, field)
				turn_logs.append_array(tick_logs)
				if int(mon.get("hp", 0)) <= 0:
					turn_logs.append("%s fainted!" % _mon_name(mon))
					events.append({"kind": "faint", "side": "player" if is_player else "enemy", "slot": slot})
	if _battle_over_now():
		return
	_send_replacements(true, turn_logs, events)
	_send_replacements(false, turn_logs, events)
	_auto_shift(turn_logs, events)
	_battle_over_now()


## Move the first living bench Pokemon into each empty or
## fainted slot, in slot order. Fainted actives are set aside
## into the side's out list.
func _send_replacements(is_player: bool, turn_logs: Array, events: Array) -> void:
	var actives: Array = _actives_of(is_player)
	var bench: Array = _bench_of(is_player)
	var out: Array = _out_of(is_player)
	for slot in range(SLOT_COUNT):
		var mon: Dictionary = actives[slot]
		var needs: bool = mon.is_empty() or int(mon.get("hp", 0)) <= 0
		if not needs:
			continue
		if not mon.is_empty():
			out.append(mon)
			actives[slot] = {}
		var bench_idx: int = -1
		for i in range(bench.size()):
			var cand: Dictionary = bench[i]
			if not cand.is_empty() and int(cand.get("hp", 0)) > 0:
				bench_idx = i
				break
		if bench_idx < 0:
			continue
		var incoming: Dictionary = bench[bench_idx]
		bench.remove_at(bench_idx)
		actives[slot] = incoming
		turn_logs.append("%s was sent out!" % _mon_name(incoming))
		events.append({"kind": "sent_out", "side": "player" if is_player else "enemy", "slot": slot})


## The sourced endgame rule: exactly two Pokemon left on the
## whole field, one per side, in opposite corner columns —
## both move to their own side's center.
func _auto_shift(turn_logs: Array, events: Array) -> void:
	var living: Array = []
	for is_player_v in [true, false]:
		var is_player: bool = bool(is_player_v)
		for slot in range(SLOT_COUNT):
			var mon: Dictionary = _mon_at(is_player, slot)
			if not mon.is_empty() and int(mon.get("hp", 0)) > 0:
				living.append({"is_player": is_player, "slot": slot, "mon": mon})
	if living.size() != 2:
		return
	var a: Dictionary = living[0]
	var b: Dictionary = living[1]
	if bool(a.get("is_player", true)) == bool(b.get("is_player", false)):
		return
	if absi(int(a.get("slot", 0)) - int(b.get("slot", 0))) != 2:
		return
	for entry_v in living:
		var entry: Dictionary = entry_v
		var actives: Array = _actives_of(bool(entry.get("is_player", true)))
		actives[int(entry.get("slot", 0))] = {}
		var entry_mon: Dictionary = entry.get("mon", {})
		actives[CENTER_SLOT] = entry_mon
	turn_logs.append("The remaining Pokemon moved to the center of the field!")
	events.append({"kind": "auto_shift"})


## Set the result the moment a side has no living Pokemon
## anywhere. A simultaneous wipe is scored as the player's
## loss, the main games' blackout rule; it is stated here
## because the sources do not address the sim case.
func _battle_over_now() -> bool:
	if status != "ongoing":
		return true
	var p_alive: bool = _side_living_count(true) > 0
	var e_alive: bool = _side_living_count(false) > 0
	if p_alive and e_alive:
		return false
	if not e_alive and p_alive:
		status = "player_won"
	else:
		status = "enemy_won"
	return true
