class_name PUWTripleTargeting
extends RefCounted
## Triple Battle targeting for Pokemon Ultimate World (VEXA).
##
## Rules are the official Generation V / VI Triple Battle rules
## (introduced in Pokemon Black and White), as documented on
## Bulbapedia, "Triple Battle" (read 2026-11-23 for this prep):
## - Three Pokemon per side stand in positions 0 (left), 1
##   (center) and 2 (right). Columns line up straight across the
##   field: a Pokemon may only target Pokemon in its own column
##   or an adjacent one, INCLUDING allies — the left Pokemon
##   cannot reach the right Pokemon on either side, and the
##   center Pokemon can reach everyone but can be reached by
##   everyone.
## - Some moves ignore that range limit. Bulbapedia: all
##   single-target damaging Flying-type moves, Flying Press, and
##   all single-target aura and pulse moves can hit any Pokemon
##   regardless of adjacency. In the project's own move data
##   (res://data/moves.json, the 954 Showdown moves) those exact
##   moves carry target "any" (checked 2026-11-23: Acrobatics,
##   Aerial Ace, Air Slash, Aura Sphere, Dark Pulse, Dragon
##   Pulse, Flying Press, Hurricane, Water Pulse all read
##   "any"), so this module keys the exception off the data's
##   "target" field instead of re-listing move names.
## - Moves that hit multiple Pokemon only affect the ones in
##   range, and their damage is cut by 25% unless only one
##   target remains when the move is executed. The cut itself is
##   DoublesTargeting.spread_mult, reused so the number lives in
##   exactly one place.
##
## The field dict passed in follows DoublesTargeting's shape,
## widened to three slots: field["player_active"] and
## field["enemy_active"], each an Array of exactly 3 mon dicts
## by slot, with {} when a slot is empty. A mon is a valid
## target only while alive (hp > 0). Targets are returned as
## {"side": String, "slot": int} dicts.
##
## Target classes come from the same "target" field
## DoublesTargeting reads:
## - "normal" / "adjacentFoe": one foe, adjacency-limited. When
##   the desired foe has fainted, the pick falls to the nearest
##   reachable living foe (the doubles module's same-slot-then-
##   other fallback, widened to three slots).
## - "any": one Pokemon (foe or ally, never the user),
##   range-free.
## - "randomNormal": one living foe in range, at random
##   (Outrage and friends pick a random ADJACENT foe in Triple
##   Battles, per Bulbapedia's target table).
## - "allAdjacentFoes": every living foe in range.
## - "allAdjacent": every living foe in range plus every living
##   ally in range (not the user), mirroring DoublesTargeting.
## - "all": every living Pokemon on the field, user included,
##   range-free (mirrors DoublesTargeting).
## - "self": the user. "adjacentAlly": the living allies in
##   range. "adjacentAllyOrSelf": an adjacent ally when one is
##   alive, else the user (Acupressure reads "self or adjacent
##   ally" in Bulbapedia's table; with two adjacent allies the
##   lowest slot is picked — a runner convenience, stated
##   plainly). "ally": the lowest-slot living ally in range.
## - "foeSide" / "allySide" / "allyTeam" / "allies" /
##   "scripted" target a side, the whole team, or a stored last
##   attacker — never one Pokemon — so they return no targets,
##   exactly as DoublesTargeting treats "foeSide" and
##   "scripted". (Bulbapedia notes Counter / Mirror Coat and
##   friends can be ACTIVATED by a non-adjacent foe; the
##   retaliation bookkeeping itself is the controller layer's,
##   not this module's.)
## - An unknown target value is treated like "normal", as in
##   DoublesTargeting.
##
## Redirection (Lightning Rod / Storm Drain) follows
## DoublesTargeting._apply_redirect, generalized: it applies to
## single-target moves that resolved to exactly one foe, the
## drawing mon must be alive, not commanding, and itself a
## legal target of the move from the attacker's position
## (Showdown's validity rule — in a Triple Battle a Lightning
## Rod two columns away cannot draw a range-limited move), and
## the lowest slot wins a tie, the doubles module's stated
## engine rule.

const SLOT_COUNT: int = 3
const CENTER_SLOT: int = 1


## The mon dict in one slot of one side, or {} when the slot is
## empty or out of range.
static func _slot_mon(field: Dictionary, side: String, slot: int) -> Dictionary:
	var key: String = "player_active" if side == "player" else "enemy_active"
	var actives: Array = field.get(key, [])
	if slot < 0 or slot >= actives.size():
		return {}
	var mon: Dictionary = actives[slot]
	return mon


## True when the mon dict is a living mon.
static func _alive(mon: Dictionary) -> bool:
	return not mon.is_empty() and int(mon.get("hp", 0)) > 0


## The slot numbers of the living mons on one side, in slot
## order.
static func _living_slots(field: Dictionary, side: String) -> Array:
	var out: Array = []
	for slot in range(SLOT_COUNT):
		if _alive(_slot_mon(field, side, slot)):
			out.append(slot)
	return out


## The move's target class, lower-cased ("normal" when the move
## carries none), the same default DoublesTargeting uses.
static func target_class(move: Dictionary) -> String:
	return str(move.get("target", "normal")).to_lower()


## The placement rule: two positions can interact when their
## columns are at most one apart.
static func positions_in_range(attacker_slot: int, target_slot: int) -> bool:
	return absi(attacker_slot - target_slot) <= 1


## True when the move ignores the placement rule for single
## targets (its data class is "any": the Flying / aura / pulse
## exception, already encoded in the move data).
static func ignores_range(move: Dictionary) -> bool:
	return target_class(move) == "any"


## The living foe slots a move can reach from attacker_slot, in
## slot order (all three for a range-free move).
static func _foes_in_range(move: Dictionary, attacker_slot: int, foe_side: String, field: Dictionary) -> Array:
	var out: Array = []
	for slot_v in _living_slots(field, foe_side):
		var slot: int = int(slot_v)
		if ignores_range(move) or positions_in_range(attacker_slot, slot):
			out.append(slot)
	return out


## The living ally slots (never the attacker's own) next to the
## attacker, in slot order. Ally targeting is adjacency-limited
## even for range-free foe classes: the "any" exception in the
## games is about reaching across the field, and the ally
## classes with their own names (adjacentAlly and friends) are
## adjacency classes by definition.
static func _allies_in_range(attacker_slot: int, attacker_side: String, field: Dictionary) -> Array:
	var out: Array = []
	for slot_v in _living_slots(field, attacker_side):
		var slot: int = int(slot_v)
		if slot != attacker_slot and positions_in_range(attacker_slot, slot):
			out.append(slot)
	return out


## True when one specific Pokemon is a legal target of the move
## from the attacker's position right now. Side / team /
## scripted classes never target one Pokemon, so they are
## always false here.
static func can_target(move: Dictionary, attacker_slot: int, attacker_side: String, target_side: String, target_slot: int, field: Dictionary) -> bool:
	var mon: Dictionary = _slot_mon(field, target_side, target_slot)
	if not _alive(mon):
		return false
	var cls: String = target_class(move)
	if cls == "self":
		return target_side == attacker_side and target_slot == attacker_slot
	if cls == "all":
		return true
	if cls == "foeside" or cls == "allyside" or cls == "allyteam" or cls == "allies" or cls == "scripted":
		return false
	if cls == "any":
		return not (target_side == attacker_side and target_slot == attacker_slot)
	if cls == "adjacentallyorself":
		if target_side == attacker_side and target_slot == attacker_slot:
			return true
		return target_side == attacker_side and positions_in_range(attacker_slot, target_slot)
	return positions_in_range(attacker_slot, target_slot)


## Every legal single target of the move from this position, as
## {"side", "slot"} dicts (empty for spread, side and scripted
## classes). For UI / AI / test use.
static func legal_single_targets(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary) -> Array:
	var out: Array = []
	var cls: String = target_class(move)
	if cls == "foeside" or cls == "allyside" or cls == "allyteam" or cls == "allies" or cls == "scripted" or cls == "alladjacentfoes" or cls == "alladjacent" or cls == "all":
		return out
	for side in ["player", "enemy"]:
		for slot in range(SLOT_COUNT):
			if can_target(move, attacker_slot, attacker_side, side, slot, field):
				out.append({"side": side, "slot": slot})
	return out


## Pick one foe for a single-target foe move: the desired slot
## when it is a living foe the move can reach, else the
## reachable living foe nearest the desired slot (ties to the
## lower slot). Returns {} when no foe is reachable — the move
## then fails, which is the games' answer to a target outside
## the user's range.
static func _pick_single_foe(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary, desired: Dictionary) -> Dictionary:
	var foe_side: String = "enemy" if attacker_side == "player" else "player"
	var reachable: Array = _foes_in_range(move, attacker_slot, foe_side, field)
	if reachable.is_empty():
		return {}
	var desired_slot: int = attacker_slot
	if str(desired.get("side", "")) == foe_side:
		desired_slot = int(desired.get("slot", attacker_slot))
	if desired_slot in reachable:
		return {"side": foe_side, "slot": desired_slot}
	var best_slot: int = int(reachable[0])
	var best_dist: int = absi(best_slot - desired_slot)
	for slot_v in reachable:
		var slot: int = int(slot_v)
		var dist: int = absi(slot - desired_slot)
		if dist < best_dist:
			best_dist = dist
			best_slot = slot
	return {"side": foe_side, "slot": best_slot}


## Pick the one target of an "any" move: the desired Pokemon
## when it is legal (any living foe, or any living ally but
## never the user), else the foe in the attacker's own column,
## else the lowest-slot living foe. Returns {} when nothing is
## targetable.
static func _pick_any_target(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary, desired: Dictionary) -> Dictionary:
	var foe_side: String = "enemy" if attacker_side == "player" else "player"
	if not desired.is_empty():
		var d_side: String = str(desired.get("side", ""))
		var d_slot: int = int(desired.get("slot", -1))
		if (d_side == foe_side or d_side == attacker_side) and can_target(move, attacker_slot, attacker_side, d_side, d_slot, field):
			return {"side": d_side, "slot": d_slot}
	var own_column: Dictionary = _slot_mon(field, foe_side, attacker_slot)
	if _alive(own_column):
		return {"side": foe_side, "slot": attacker_slot}
	var foes: Array = _living_slots(field, foe_side)
	if not foes.is_empty():
		return {"side": foe_side, "slot": int(foes[0])}
	return {}


## The ability that draws a move of one type to its holder:
## Lightning Rod draws Electric moves, Storm Drain draws Water
## moves (same rule as DoublesTargeting).
static func _redirect_type(ability: String) -> String:
	if ability == "Lightning Rod":
		return "electric"
	if ability == "Storm Drain":
		return "water"
	return ""


## Redirection for single-target moves aimed at a foe,
## generalized from DoublesTargeting._apply_redirect (see the
## header for the one Triple Battle difference: the drawing
## mon must be within the move's own range).
static func _apply_redirect(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary, targets: Array) -> Array:
	if targets.size() != 1:
		return targets
	var foe_side: String = "enemy" if attacker_side == "player" else "player"
	var first: Dictionary = targets[0]
	if str(first.get("side", "")) != foe_side:
		return targets
	if bool(move.get("ignores_redirection", false)):
		return targets
	var attacker: Dictionary = _slot_mon(field, attacker_side, attacker_slot)
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Mold Breaker" or a_ab == "Teravolt" or a_ab == "Turboblaze":
		return targets
	var mtype: String = str(move.get("type", "")).to_lower()
	if mtype != "electric" and mtype != "water":
		return targets
	var chosen_slot: int = int(first.get("slot", 0))
	for slot in range(SLOT_COUNT):
		var cand: Dictionary = _slot_mon(field, foe_side, slot)
		if not _alive(cand):
			continue
		if bool(cand.get("commanding", false)):
			continue
		if _redirect_type(str(cand.get("ability", ""))) == mtype:
			if slot == chosen_slot:
				return targets
			if not ignores_range(move) and not positions_in_range(attacker_slot, slot):
				continue
			return [{"side": foe_side, "slot": slot}]
	return targets


## Work out which slots a move hits. desired is the intended
## single target as {"side", "slot"} ({} for none); it only
## steers the single-target classes. See the header for the
## class-by-class rules.
static func resolve_targets(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary, desired: Dictionary = {}) -> Array:
	var out: Array = []
	var cls: String = target_class(move)
	var foe_side: String = "enemy" if attacker_side == "player" else "player"
	match cls:
		"normal", "adjacentfoe":
			var pick: Dictionary = _pick_single_foe(move, attacker_slot, attacker_side, field, desired)
			if not pick.is_empty():
				out.append(pick)
		"any":
			var pick_any: Dictionary = _pick_any_target(move, attacker_slot, attacker_side, field, desired)
			if not pick_any.is_empty():
				out.append(pick_any)
		"randomnormal":
			var foes: Array = _foes_in_range(move, attacker_slot, foe_side, field)
			if not foes.is_empty():
				var pick_slot: int = int(foes[randi() % foes.size()])
				out.append({"side": foe_side, "slot": pick_slot})
		"alladjacentfoes":
			for slot_v in _foes_in_range(move, attacker_slot, foe_side, field):
				out.append({"side": foe_side, "slot": int(slot_v)})
		"alladjacent":
			for slot_v2 in _foes_in_range(move, attacker_slot, foe_side, field):
				out.append({"side": foe_side, "slot": int(slot_v2)})
			for ally_v in _allies_in_range(attacker_slot, attacker_side, field):
				out.append({"side": attacker_side, "slot": int(ally_v)})
		"all":
			for side2 in [attacker_side, foe_side]:
				for slot_v3 in _living_slots(field, side2):
					out.append({"side": side2, "slot": int(slot_v3)})
		"self":
			out.append({"side": attacker_side, "slot": attacker_slot})
		"adjacentally":
			for ally_v2 in _allies_in_range(attacker_slot, attacker_side, field):
				out.append({"side": attacker_side, "slot": int(ally_v2)})
		"adjacentallyorself":
			var allies: Array = _allies_in_range(attacker_slot, attacker_side, field)
			if not allies.is_empty():
				out.append({"side": attacker_side, "slot": int(allies[0])})
			else:
				out.append({"side": attacker_side, "slot": attacker_slot})
		"ally":
			var allies2: Array = _allies_in_range(attacker_slot, attacker_side, field)
			if not allies2.is_empty():
				out.append({"side": attacker_side, "slot": int(allies2[0])})
		"foeside", "allyside", "allyteam", "allies", "scripted":
			pass
		_:
			var pick2: Dictionary = _pick_single_foe(move, attacker_slot, attacker_side, field, desired)
			if not pick2.is_empty():
				out.append(pick2)
	out = _apply_redirect(move, attacker_slot, attacker_side, field, out)
	return out


## True when the move's class hits more than one Pokemon at
## once ("allAdjacentFoes" / "allAdjacent"). Whether the 25%
## cut actually applies is decided by the target count at
## execution time (Bulbapedia: the cut applies unless there is
## only one target when the move is executed), via spread_mult.
static func is_spread(move: Dictionary) -> bool:
	var cls: String = target_class(move)
	return cls == "alladjacentfoes" or cls == "alladjacent"


## The spread damage cut, delegated to DoublesTargeting so the
## 0.75 rule lives in exactly one place.
static func spread_mult(target_count: int) -> float:
	return DoublesTargeting.spread_mult(target_count)


## The targets a move can legally hit, for UI or AI use.
## party_player and party_enemy are the full parties; the
## active mons are party[0], party[1] and party[2]. Same return
## shape as resolve_targets, with no desired target.
static func valid_targets(move: Dictionary, attacker_slot: int, attacker_side: String, party_player: Array, party_enemy: Array) -> Array:
	var field: Dictionary = {}
	var pa: Array = []
	var ea: Array = []
	for slot in range(SLOT_COUNT):
		if slot < party_player.size():
			pa.append(party_player[slot])
		else:
			pa.append({})
		if slot < party_enemy.size():
			ea.append(party_enemy[slot])
		else:
			ea.append({})
	field["player_active"] = pa
	field["enemy_active"] = ea
	return resolve_targets(move, attacker_slot, attacker_side, field)
