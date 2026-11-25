class_name TurnResolver
extends Node
## Deterministic Gen IX Turn Order Resolver (Priority > Speed w/ Paralysis & Trick Room).
##
## v3 adds resolve_order_4 for doubles: the same priority-then-speed
## rules, run over four combatants instead of two. Speed still comes
## only from effective_speed, so the paralysis and weather ability
## rules live in exactly one place.

static func effective_speed(mon: Dictionary, field: Dictionary) -> float:
	var spe := float(mon.get("spe", 100))
	if mon.get("status", "") == "PAR":
		spe *= 0.5
	var w: String = field.get("weather", "none")
	var ab: String = mon.get("ability", "")
	# The weather speed abilities below do not fire under
	# Neutralizing Gas. Paralysis halving above stays: paralysis
	# is a status, not an ability.
	var gas: bool = bool(field.get("abilities_suppressed", false))
	if not gas and ((w == "sun" and ab == "Chlorophyll") or (w == "rain" and ab == "Swift Swim") or (w == "sand" and ab == "Sand Rush") or (w == "snow" and ab == "Slush Rush")):
		spe *= 2.0
	# Ability speed multipliers NOT owned here: Unburden, Quick
	# Feet, Slow Start, Protosynthesis / Quark Drive (Speed). The
	# weather abilities above stay here, so nothing is doubled.
	spe *= AbilityEngine.get_speed_multiplier(mon, field)
	return spe


## Priority is a float here: a move dict may carry frac_priority
## (Quick Draw +0.1) alongside its int priority, and the sum decides
## the order. The resolver never rolls; the controller sets
## frac_priority before calling it.
static func resolve_order(p_mon: Dictionary, p_move: Dictionary, e_mon: Dictionary, e_move: Dictionary, field: Dictionary) -> Array:
	var p_pri: float = float(p_move.get("priority", 0)) + float(p_move.get("frac_priority", 0.0))
	var e_pri: float = float(e_move.get("priority", 0)) + float(e_move.get("frac_priority", 0.0))
	if p_pri != e_pri:
		return ["player", "enemy"] if p_pri > e_pri else ["enemy", "player"]
	# Stall moves last in its own priority bracket (Showdown
	# onFractionalPriority -0.1): same priority, the mon with
	# moves_last goes after the other one, whatever the Speeds
	# are. The flag is set by before_move, but turn order is
	# worked out before before_move runs on turn 1, so the
	# ability name is checked too.
	var p_last: bool = bool(p_mon.get("moves_last", false)) or str(p_mon.get("ability", "")) == "Stall"
	var e_last: bool = bool(e_mon.get("moves_last", false)) or str(e_mon.get("ability", "")) == "Stall"
	if p_last != e_last:
		return ["enemy", "player"] if p_last else ["player", "enemy"]
	var p_spe := effective_speed(p_mon, field)

	var e_spe := effective_speed(e_mon, field)
	if int(field.get("trick_room", 0)) > 0:
		return ["player", "enemy"] if p_spe <= e_spe else ["enemy", "player"]
	return ["player", "enemy"] if p_spe >= e_spe else ["enemy", "player"]

## Speed multiplier for one mon, worked out only through
## effective_speed. This is a thin pass-through: no paralysis rule
## and no weather ability rule is written here, so the speed rules
## are not duplicated.
static func get_speed_multiplier(mon: Dictionary, field: Dictionary) -> float:
	var base: float = float(mon.get("spe", 100))
	if base <= 0.0:
		return 1.0
	return effective_speed(mon, field) / base

## True when combatant a acts before combatant b. Order: move
## priority first, then effective speed (Trick Room flips it so the
## slowest goes first), then slot (slot 0 before slot 1), then side
## ("player" before "enemy"). Slot then side only break exact ties,
## so the order is always the same for the same input.
static func _acts_before(a: Dictionary, b: Dictionary, field: Dictionary) -> bool:
	var a_move: Dictionary = a.get("move", {})
	var b_move: Dictionary = b.get("move", {})
	var a_pri: float = float(a_move.get("priority", 0)) + float(a_move.get("frac_priority", 0.0))
	var b_pri: float = float(b_move.get("priority", 0)) + float(b_move.get("frac_priority", 0.0))
	if a_pri != b_pri:
		return a_pri > b_pri
	# Stall moves last in its own priority bracket (see
	# resolve_order): same priority, the moves_last mon acts
	# after the other one, whatever the Speeds are.
	var a_mon: Dictionary = a.get("mon", {})
	var b_mon: Dictionary = b.get("mon", {})
	var a_last: bool = bool(a_mon.get("moves_last", false)) or str(a_mon.get("ability", "")) == "Stall"
	var b_last: bool = bool(b_mon.get("moves_last", false)) or str(b_mon.get("ability", "")) == "Stall"
	if a_last != b_last:
		return not a_last
	var a_spe: float = effective_speed(a.get("mon", {}), field)

	var b_spe: float = effective_speed(b.get("mon", {}), field)
	if a_spe != b_spe:
		if int(field.get("trick_room", 0)) > 0:
			return a_spe < b_spe
		return a_spe > b_spe
	var a_slot: int = int(a.get("slot", 0))
	var b_slot: int = int(b.get("slot", 0))
	if a_slot != b_slot:
		return a_slot < b_slot
	return str(a.get("side", "player")) < str(b.get("side", "player"))

## Order four combatants for a doubles turn. Each combatant is a
## Dictionary: {"mon": Dictionary, "move": Dictionary,
## "side": "player" or "enemy", "slot": 0 or 1, "action": Dictionary}.
## "move" is the move data from BattleController._action_move, so
## switches and items carry priority 6 and go before moves, exactly
## like the singles resolver. Returns the same combatant dicts,
## sorted in action order. The input array is not changed.
static func resolve_order_4(combatants: Array, field: Dictionary) -> Array:
	var ordered: Array = combatants.duplicate()
	var n: int = ordered.size()
	for i in range(n):
		var best: int = i
		for j in range(i + 1, n):
			var later: Dictionary = ordered[j]
			var current: Dictionary = ordered[best]
			if _acts_before(later, current, field):
				best = j
		if best != i:
			var tmp: Dictionary = ordered[i]
			ordered[i] = ordered[best]
			ordered[best] = tmp
	return ordered
