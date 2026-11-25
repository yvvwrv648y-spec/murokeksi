class_name PUWRotationBattle
extends RefCounted
## PUWRotationBattle — one Rotation Battle for VEXA (gap G4).
##
## Rules are the official Rotation Battle rules (introduced in
## Pokemon Black and White), as documented on Bulbapedia,
## "Rotation Battle", and in Smogon's "Introduction to Rotation
## Battles" (both read 2026-11-23 for this prep):
## - Each side fields a team of three; only one is the active
##   Pokemon. "In a Rotation Battle, only the frontmost Pokemon
##   takes part in the battle" (Bulbapedia).
## - Rotating is a FREE action: the active Pokemon may be
##   rotated out for either of the other two fielded Pokemon
##   "without wasting the turn — meaning the rotated-in Pokemon
##   can still attack that turn". Both sides may rotate on the
##   same turn; rotating resolves before moves, at priority +6
##   (Bulbapedia, Pokemon battle / rotation mechanics).
## - "Rotating is not the same as switching" (Smogon):
##   rotating does NOT reset stat stage changes, confusion, the
##   badly poisoned counter, or the Slow Start counter, and the
##   rotated-in Pokemon does NOT activate its Ability — weather
##   starters must start as the active Pokemon to set weather.
## - Only the active Pokemon plays any part: multi-target moves
##   and Abilities affect only the active Pokemon, and inactive
##   Pokemon take no damage at all — including no status damage
##   (Smogon's rotation introduction).
## - In the games a Trainer may also switch to a Pokemon that
##   is not among the three fielded, using the turn as usual.
##   The format's own structure is the fielded three (every
##   in-game Rotation Battle uses exactly three), so this runner
##   fields the first three living Pokemon of each party and the
##   rest of the party does not participate — stated plainly so
##   the scope is honest.
##
## Because rotation here only moves an INDEX (the fielded mons
## are never swapped, copied, or rebuilt), the persistence
## rules hold by construction: a rotated-out Pokemon's HP, stat
## stages, status and counters are exactly what they were when
## it comes back.
##
## Damage is never invented: every hit is priced by
## PUWBattleEngine.calculate_damage, turn order between the two
## actives comes from TurnResolver (rotations resolve first),
## and move data comes from MoveDatabase — the same sources as
## every other VEXA path. End-of-turn status and weather
## damage runs through StatusAndFieldEngine.apply_end_of_turn,
## applied to the two ACTIVES ONLY (the inactive exemption
## above is the format's whole point).
##
## Simplifications, stated plainly (the same class as
## PUWRaidBattle's): accuracy is not rolled; PP is not tracked;
## non-damaging moves have no engine effect here (secondary
## effects, stat stages from moves, entry hazards and
## switch-in Abilities live in MoveEffects / AbilityEngine /
## the controller layer — and rotating in does not trigger
## Abilities in the games either); gimmicks are not offered
## (the controller owns them). StatusAndFieldEngine.
## can_act_this_turn is not consulted, matching PUWRaidBattle.
##
## Safety: setup_battle deep-copies both parties unless the
## caller passes copy_mons=false (PUWVexaSimulator does, with
## copies it made itself). The engine never touches a save and
## never calls PartyAndStorageManager.handle_faint: a faint
## here is a sim faint and retires nothing.

const FIELDED_COUNT: int = 3

var player_fielded: Array = [] ## The participating mons (up to 3), party order.
var enemy_fielded: Array = []
var player_active_idx: int = 0
var enemy_active_idx: int = 0
var turn: int = 0
var status: String = "ongoing" ## "ongoing" | "player_won" | "enemy_won" | "not_started"
var logs: Array = []
var field: Dictionary = {}

var _rng: RandomNumberGenerator = null
var _move_db: MoveDatabase = null


static func _mon_name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))


## Set up one Rotation Battle. The fielded three are the first
## three LIVING mons of each party, in party order; the first
## is active. Returns {"status": "started"} or
## {"status": "not_started"} when a side has no living Pokemon.
func setup_battle(player_party: Array, enemy_party: Array, rng: RandomNumberGenerator, copy_mons: bool = true) -> Dictionary:
	if rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = rng
	field = StatusAndFieldEngine.create_field_state()
	turn = 0
	logs = []
	player_active_idx = 0
	enemy_active_idx = 0
	player_fielded = _fielded_of_party(player_party, copy_mons)
	enemy_fielded = _fielded_of_party(enemy_party, copy_mons)
	if player_fielded.is_empty() or enemy_fielded.is_empty():
		status = "not_started"
		return {"status": "not_started"}
	status = "ongoing"
	return {"status": "started"}


func _fielded_of_party(party: Array, copy_mons: bool) -> Array:
	var out: Array = []
	for entry_v in party:
		if not (entry_v is Dictionary):
			continue
		var mon: Dictionary = entry_v
		if int(mon.get("hp", 0)) <= 0:
			continue
		if copy_mons:
			mon = mon.duplicate(true)
		out.append(mon)
		if out.size() >= FIELDED_COUNT:
			break
	return out


func _fielded(is_player: bool) -> Array:
	return player_fielded if is_player else enemy_fielded


## The side's active Pokemon right now, or {} when its slot is
## empty (never, once the battle has started).
func active_mon(is_player: bool) -> Dictionary:
	var fielded: Array = _fielded(is_player)
	var idx: int = player_active_idx if is_player else enemy_active_idx
	if idx < 0 or idx >= fielded.size():
		return {}
	var mon: Dictionary = fielded[idx]
	return mon


func _side_has_living(is_player: bool) -> bool:
	for entry_v in _fielded(is_player):
		if entry_v is Dictionary:
			var mon: Dictionary = entry_v
			if int(mon.get("hp", 0)) > 0:
				return true
	return false


func _first_living_idx(is_player: bool) -> int:
	var fielded: Array = _fielded(is_player)
	for i in range(fielded.size()):
		var mon: Dictionary = fielded[i]
		if not mon.is_empty() and int(mon.get("hp", 0)) > 0:
			return i
	return -1


func is_over() -> bool:
	return status != "ongoing"


func battle_result() -> Dictionary:
	return {
		"status": status, "turns": turn,
		"player_fielded": player_fielded, "enemy_fielded": enemy_fielded,
		"player_active_idx": player_active_idx, "enemy_active_idx": enemy_active_idx,
		"player_active": _mon_name(active_mon(true)), "enemy_active": _mon_name(active_mon(false)),
		"logs": logs,
	}


## --- Move data -------------------------------------------------

func _move_data(move_name: String) -> Dictionary:
	if _move_db == null:
		_move_db = MoveDatabase.new()
		_move_db.load_database()
	var md: Dictionary = _move_db.get_move(move_name).duplicate(true)
	md["name"] = move_name
	return md


## The best offensive type multiplier one mon can manage
## against another: the best of its damaging moves' types on
## the project's real type chart, falling back to the mon's own
## types when it has no damaging move data.
func _best_multiplier(mon: Dictionary, foe: Dictionary) -> float:
	if mon.is_empty() or foe.is_empty():
		return 0.0
	var foe_types := PackedStringArray()
	for t_v in foe.get("types", []):
		foe_types.append(str(t_v))
	var best: float = 0.0
	var moves: Array = mon.get("moves", [])
	for move_v in moves:
		var md: Dictionary = _move_data(str(move_v))
		if int(md.get("power", 0)) <= 0:
			continue
		var eff: float = PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), foe_types)
		if eff > best:
			best = eff
	if best <= 0.0:
		for t2_v in mon.get("types", []):
			var eff2: float = PUWBattleEngine.type_multiplier(str(t2_v), foe_types)
			if eff2 > best:
				best = eff2
	return best


## Which fielded index a driver would rotate to: a different
## living fielded mon only when it strictly improves the
## offensive matchup against the opposing active, else the
## current active index ("stay"). Used by this runner's enemy
## AI and by PUWVexaSimulator's player driver, so the rule
## lives in one place.
func suggest_rotation(is_player: bool) -> int:
	var cur_idx: int = player_active_idx if is_player else enemy_active_idx
	var foe_active: Dictionary = active_mon(not is_player)
	if foe_active.is_empty():
		return cur_idx
	var best_idx: int = cur_idx
	var best_score: float = _best_multiplier(active_mon(is_player), foe_active)
	var fielded: Array = _fielded(is_player)
	for i in range(fielded.size()):
		if i == cur_idx:
			continue
		var mon: Dictionary = fielded[i]
		if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
			continue
		var score: float = _best_multiplier(mon, foe_active)
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx


## The first damaging move that is not immune against the foe
## (the singles driver's rule in PUWVexaSimulator._pick_move);
## falls back to the mon's first move, else "".
func _pick_move(mon: Dictionary, foe: Dictionary) -> String:
	if mon.is_empty():
		return ""
	var moves: Array = mon.get("moves", [])
	var foe_types := PackedStringArray()
	for t_v in foe.get("types", []):
		foe_types.append(str(t_v))
	for move_v in moves:
		var move_name: String = str(move_v)
		var md: Dictionary = _move_data(move_name)
		if int(md.get("power", 0)) <= 0:
			continue
		if PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), foe_types) > 0.0:
			return move_name
	if not moves.is_empty():
		return str(moves[0])
	return ""


## --- Rotation --------------------------------------------------

## Rotate one side's active Pokemon. Only the index changes —
## the incoming mon's dict is exactly as it was left, which is
## what makes the format's persistence rules (stat stages,
## poison counter, Slow Start) hold by construction. Returns
## false for an illegal rotation: out of range, the current
## active, or a fainted mon.
func rotate(is_player: bool, to_idx: int) -> bool:
	var fielded: Array = _fielded(is_player)
	if to_idx < 0 or to_idx >= fielded.size():
		return false
	var cur_idx: int = player_active_idx if is_player else enemy_active_idx
	if to_idx == cur_idx:
		return false
	var mon: Dictionary = fielded[to_idx]
	if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
		return false
	if is_player:
		player_active_idx = to_idx
	else:
		enemy_active_idx = to_idx
	return true


## --- Turn flow -------------------------------------------------

## One full Rotation Battle turn. player_action is
## {"move_name": String, "rotate_to": int (optional, -1 or
## missing = no rotation)}. Rotations resolve first for both
## sides (priority +6, free), then the two actives exchange
## moves, then end-of-turn ticks land on the actives only.
## When the player's active has fainted, a rotation is forced:
## the player's rotate_to when legal, else the first living
## fielded mon. Returns {"status", "logs", "turn", "events",
## "player_active", "enemy_active"}.
func run_turn(player_action: Dictionary) -> Dictionary:
	var turn_logs: Array = []
	var events: Array = []
	if status != "ongoing":
		return {"status": status, "logs": turn_logs, "turn": turn, "events": events, "player_active": _mon_name(active_mon(true)), "enemy_active": _mon_name(active_mon(false))}
	turn += 1
	# 1) Rotations, before any move (free, priority +6).
	var p_forced: bool = int(active_mon(true).get("hp", 0)) <= 0
	var p_rotate_to: int = int(player_action.get("rotate_to", -1))
	if p_rotate_to >= 0:
		if rotate(true, p_rotate_to):
			events.append({"kind": "rotate", "side": "player", "to": p_rotate_to})
			turn_logs.append("Player rotated to %s!" % _mon_name(active_mon(true)))
	if p_forced and int(active_mon(true).get("hp", 0)) <= 0:
		var auto_idx: int = _first_living_idx(true)
		if auto_idx >= 0 and rotate(true, auto_idx):
			events.append({"kind": "rotate", "side": "player", "to": auto_idx, "forced": true})
			turn_logs.append("Player rotated to %s!" % _mon_name(active_mon(true)))
	var e_forced: bool = int(active_mon(false).get("hp", 0)) <= 0
	if e_forced:
		var e_auto: int = _first_living_idx(false)
		if e_auto >= 0 and rotate(false, e_auto):
			events.append({"kind": "rotate", "side": "enemy", "to": e_auto, "forced": true})
			turn_logs.append("Enemy rotated to %s!" % _mon_name(active_mon(false)))
	else:
		var e_suggest: int = suggest_rotation(false)
		if e_suggest != enemy_active_idx and rotate(false, e_suggest):
			events.append({"kind": "rotate", "side": "enemy", "to": e_suggest})
			turn_logs.append("Enemy rotated to %s!" % _mon_name(active_mon(false)))
	# 2) The move exchange between the two actives.
	var p_mon: Dictionary = active_mon(true)
	var e_mon: Dictionary = active_mon(false)
	var p_move_name: String = str(player_action.get("move_name", ""))
	var e_move_name: String = ""
	if not e_mon.is_empty() and int(e_mon.get("hp", 0)) > 0:
		e_move_name = _pick_move(e_mon, p_mon)
	var p_move: Dictionary = _move_data(p_move_name) if not p_move_name.is_empty() else {}
	var e_move: Dictionary = _move_data(e_move_name) if not e_move_name.is_empty() else {}
	if not p_mon.is_empty():
		p_mon["field"] = field
		p_mon["side"] = "player"
	if not e_mon.is_empty():
		e_mon["field"] = field
		e_mon["side"] = "enemy"
	if not p_move_name.is_empty() or not e_move_name.is_empty():
		var order: Array = TurnResolver.resolve_order(p_mon, p_move, e_mon, e_move, field)
		for side_v in order:
			var side_name: String = str(side_v)
			var attacker: Dictionary = p_mon if side_name == "player" else e_mon
			var defender: Dictionary = e_mon if side_name == "player" else p_mon
			var mname: String = p_move_name if side_name == "player" else e_move_name
			if mname.is_empty():
				continue
			if attacker.is_empty() or int(attacker.get("hp", 0)) <= 0:
				continue
			if defender.is_empty() or int(defender.get("hp", 0)) <= 0:
				continue
			_execute_move(attacker, defender, mname, side_name, turn_logs, events)
			if _battle_over_now():
				break
	# 3) End of turn: status / weather ticks for the two
	# ACTIVES only. Inactive Pokemon take no status damage —
	# the format's own rule.
	if status == "ongoing":
		for is_player_v in [true, false]:
			var is_player: bool = bool(is_player_v)
			var mon: Dictionary = active_mon(is_player)
			if not mon.is_empty() and int(mon.get("hp", 0)) > 0:
				var tick_logs: Array = StatusAndFieldEngine.apply_end_of_turn(mon, field)
				turn_logs.append_array(tick_logs)
				if int(mon.get("hp", 0)) <= 0:
					turn_logs.append("%s fainted!" % _mon_name(mon))
					events.append({"kind": "faint", "side": "player" if is_player else "enemy"})
		_battle_over_now()
	logs.append_array(turn_logs)
	return {"status": status, "logs": turn_logs, "turn": turn, "events": events, "player_active": _mon_name(active_mon(true)), "enemy_active": _mon_name(active_mon(false))}


## One hit on the active defender. Only the active can ever be
## a defender in this runner, which is the format's "multi-
## target moves affect only the active" rule made structural.
func _execute_move(attacker: Dictionary, defender: Dictionary, move_name: String, side_name: String, turn_logs: Array, events: Array) -> void:
	var move: Dictionary = _move_data(move_name)
	turn_logs.append("%s used %s!" % [_mon_name(attacker), move_name])
	if int(move.get("power", 0)) <= 0:
		events.append({"kind": "no_effect", "side": "enemy" if side_name == "player" else "player", "move": move_name, "user": _mon_name(attacker)})
		return
	var result: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, move, _rng)
	var dmg: int = int(result.get("damage", 0))
	defender["hp"] = maxi(0, int(defender.get("hp", 0)) - dmg)
	events.append({"kind": "hit", "side": "enemy" if side_name == "player" else "player", "move": move_name, "user": _mon_name(attacker), "damage": dmg, "mult": 1.0, "effectiveness": float(result.get("effectiveness", 1.0)), "critical": bool(result.get("critical", false))})
	if int(defender.get("hp", 0)) <= 0:
		turn_logs.append("%s fainted!" % _mon_name(defender))
		events.append({"kind": "faint", "side": "enemy" if side_name == "player" else "player"})


## The battle ends when one side's three fielded Pokemon have
## all fainted. A simultaneous faint is scored as the player's
## loss, the main games' blackout rule; stated because the
## sources do not address the sim case.
func _battle_over_now() -> bool:
	if status != "ongoing":
		return true
	var p_alive: bool = _side_has_living(true)
	var e_alive: bool = _side_has_living(false)
	if p_alive and e_alive:
		return false
	if not e_alive and p_alive:
		status = "player_won"
	else:
		status = "enemy_won"
	return true
