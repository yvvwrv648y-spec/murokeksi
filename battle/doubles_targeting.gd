class_name DoublesTargeting
extends RefCounted
## Doubles targeting for Pokemon Ultimate World, battle engine v3.
## Plain rules, no made-up numbers. Target values come from the real
## "target" field in moves.json (954 Showdown moves). Counts checked
## 2026-11-22: normal 632, self 99, allAdjacentFoes 62,
## adjacentFoe 53, any 24, all 24, allAdjacent 20, allySide 14,
## randomNormal 6, adjacentAlly 5, scripted 4, allies 4, foeSide 4,
## allyTeam 2, adjacentAllyOrSelf 1.
##
## The field dict passed to resolve_targets is the normal battle
## field state plus two keys built by the controller:
## field["player_active"] and field["enemy_active"], each an Array of
## the live mon dicts by slot (slot 0, slot 1), with {} when a slot
## is empty. A mon is a valid target only while it is alive
## (hp > 0). Fainted targets are never returned.
##
## Targets are returned as a list of {"side": String, "slot": int}
## dicts, where side is "player" or "enemy" and slot is 0 or 1.
##
## Notes on the less common values:
## - "randomNormal" picks one living foe at random (Outrage and
##   friends in doubles). A fixed pick would be wrong here.
## - "foeSide" (Spikes, Stealth Rock, Sticky Web, Toxic Spikes)
##   targets a side, not a Pokemon, so no Pokemon target is
##   returned. The controller handles those through its hazard path.
## - "scripted" (Counter, Mirror Coat, Metal Burst, Comeuppance)
##   hits whoever hit the user last. That last attacker is not
##   tracked anywhere in v2, so no target is returned here either.
## - "allAdjacent" also hits both foes, but is_spread stays false
##   for it on purpose: the v3 spec counts only "allAdjacentFoes"
##   as a spread move for the 0.75x cut. If the real-game rule is
##   wanted (any move hitting more than one target takes 0.75x),
##   change is_spread to also accept "allAdjacent".
## - "ally", "allyTeam" and "allies" are not in moves.json; they are
##   accepted as aliases for the ally target so older move data
##   still works.

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

## The other slot on the same side: 1 when the attacker is in
## slot 0, 0 when the attacker is in slot 1.
static func _ally_slot(attacker_slot: int) -> int:
	if attacker_slot == 0:
		return 1
	return 0

## The slot numbers of the living mons on one side, in slot order.
static func _living_slots(field: Dictionary, side: String) -> Array:
	var out: Array = []
	for slot in range(2):
		if _alive(_slot_mon(field, side, slot)):
			out.append(slot)
	return out

## Work out which slots a move hits, from the move's real "target"
## value. "normal" / "any" / "adjacentFoe" hit one foe: the foe in
## the same slot, or the other foe when the same-slot foe has
## fainted. "randomNormal" hits one living foe at random.
## "allAdjacentFoes" hits both foes. "allAdjacent" hits both foes
## plus the ally. "all" hits everyone alive: both foes, the ally,
## and the attacker. "allySide" / "adjacentAlly" / "ally" /
## "allyTeam" / "allies" hit the ally. "adjacentAllyOrSelf" hits
## the ally when it is alive, else the attacker. "self" hits the
## attacker. "foeSide" and "scripted" hit no Pokemon, so they
## return an empty list. An unknown target value is treated like
## "normal".
## The ability that draws a move of one type to its holder:
## Lightning Rod draws Electric moves, Storm Drain draws Water
## moves (Showdown abilities.ts, onAnyRedirectTarget). The move
## type that the ability draws, or "" when the ability draws
## nothing.
static func _redirect_type(ability: String) -> String:
	if ability == "Lightning Rod":
		return "electric"
	if ability == "Storm Drain":
		return "water"
	return ""

## Redirection for single-target moves aimed at a foe (Showdown
## Battle#getTarget, plus Lightning Rod / Storm Drain
## onAnyRedirectTarget). Runs after the normal target pick, so
## it only ever replaces one foe target with the other foe.
## Rules, all from the Showdown entries named above:
## - A move marked ignores_redirection (Propeller Tail /
##   Stalwart, set in before_move) is never redirected.
## - Mold Breaker, Teravolt and Turboblaze ignore the redirect
##   (both abilities are breakable in Showdown).
## - Only Electric moves go to a Lightning Rod mon and only
##   Water moves go to a Storm Drain mon. Pledge combos are
##   skipped in Showdown; this engine has no pledge-combo state,
##   so no move is ever treated as one.
## - The drawing mon must be alive, on the foe side, and not
##   commanding (a Tatsugiri in Dondozo's mouth cannot be hit).
##   When both foes draw the move, the lower slot wins; that
##   tie break is this engine's own rule, stated plainly.
## - Spread moves, ally moves, self moves and side moves are
##   never redirected: they do not resolve to exactly one foe.
## The Sp. Atk +1 on the hit is NOT done here: the redirected
## target goes through the normal is_immune path in the
## controller, which raises it (Patch B makes that path reach
## the batch arms).
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
	for slot in range(2):
		var cand: Dictionary = _slot_mon(field, foe_side, slot)
		if not _alive(cand):
			continue
		if bool(cand.get("commanding", false)):
			continue
		if _redirect_type(str(cand.get("ability", ""))) == mtype:
			if slot == chosen_slot:
				return targets
			return [{"side": foe_side, "slot": slot}]
	return targets

static func resolve_targets(move: Dictionary, attacker_slot: int, attacker_side: String, field: Dictionary) -> Array:

	var out: Array = []
	var target: String = str(move.get("target", "normal")).to_lower()
	var foe_side: String = "enemy" if attacker_side == "player" else "player"
	var ally_slot: int = _ally_slot(attacker_slot)
	match target:
		"normal", "any", "adjacentfoe":
			var foe: Dictionary = _slot_mon(field, foe_side, attacker_slot)
			if _alive(foe):
				out.append({"side": foe_side, "slot": attacker_slot})
			else:
				var other: Dictionary = _slot_mon(field, foe_side, ally_slot)
				if _alive(other):
					out.append({"side": foe_side, "slot": ally_slot})
		"randomnormal":
			var living_foes: Array = _living_slots(field, foe_side)
			if not living_foes.is_empty():
				var pick: int = int(living_foes[randi() % living_foes.size()])
				out.append({"side": foe_side, "slot": pick})
		"alladjacentfoes":
			for slot in _living_slots(field, foe_side):
				out.append({"side": foe_side, "slot": int(slot)})
		"alladjacent":
			for slot in _living_slots(field, foe_side):
				out.append({"side": foe_side, "slot": int(slot)})
			var ally: Dictionary = _slot_mon(field, attacker_side, ally_slot)
			if _alive(ally):
				out.append({"side": attacker_side, "slot": ally_slot})
		"all":
			for slot in _living_slots(field, foe_side):
				out.append({"side": foe_side, "slot": int(slot)})
			var ally2: Dictionary = _slot_mon(field, attacker_side, ally_slot)
			if _alive(ally2):
				out.append({"side": attacker_side, "slot": ally_slot})
			out.append({"side": attacker_side, "slot": attacker_slot})
		"self":
			out.append({"side": attacker_side, "slot": attacker_slot})
		"ally", "allyside", "adjacentally", "allyteam", "allies":
			var ally3: Dictionary = _slot_mon(field, attacker_side, ally_slot)
			if _alive(ally3):
				out.append({"side": attacker_side, "slot": ally_slot})
		"adjacentallyorself":
			var ally4: Dictionary = _slot_mon(field, attacker_side, ally_slot)
			if _alive(ally4):
				out.append({"side": attacker_side, "slot": ally_slot})
			else:
				out.append({"side": attacker_side, "slot": attacker_slot})
		"foeside", "scripted":
			pass
		_:
			var foe2: Dictionary = _slot_mon(field, foe_side, attacker_slot)
			if _alive(foe2):
				out.append({"side": foe_side, "slot": attacker_slot})
			else:
				var other2: Dictionary = _slot_mon(field, foe_side, ally_slot)
				if _alive(other2):
					out.append({"side": foe_side, "slot": ally_slot})
	out = _apply_redirect(move, attacker_slot, attacker_side, field, out)
	return out


## True when the move hits both foes ("allAdjacentFoes" in
## moves.json). See the header note: "allAdjacent" also hits both
## foes, but it is not counted as spread here, per the v3 spec.
static func is_spread(move: Dictionary) -> bool:
	return str(move.get("target", "")).to_lower() == "alladjacentfoes"

## The spread damage cut: 0.75x when a move hits 2 or more targets,
## else 1.0x (no cut).
static func spread_mult(target_count: int) -> float:
	if target_count >= 2:
		return 0.75
	return 1.0

## The living targets a move can legally hit, for UI or AI use.
## party_player and party_enemy are the full parties; the active
## mons are party[0] and party[1], the bench is ignored. Same
## return shape as resolve_targets.
static func valid_targets(move: Dictionary, attacker_slot: int, attacker_side: String, party_player: Array, party_enemy: Array) -> Array:
	var field: Dictionary = {}
	var pa: Array = []
	var ea: Array = []
	for slot in range(2):
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
