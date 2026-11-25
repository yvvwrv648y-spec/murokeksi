class_name PUWPermadeathBridge
extends RefCounted
## The live-battle permadeath bridge (mechanics-completeness
## prep F2, 2026-11-24).
##
## The gap this closes: PUWCombatConsequences.apply_faint_
## consequences is the canon decision point for permanent
## fainting (story + co-op count; simulations and rentals are
## exempt), but it had NO production caller. A story battle
## could end with a fainted party member and nothing removed
## the mon, locked its evolution family, or wrote the
## fainting ledger. BattleController._handle_faint_slot only
## grants EXP and prompts a switch.
##
## This bridge is the application point the battle scene
## calls once, when a battle ends. It is deliberately thin:
## every decision (does permadeath apply here, which ledger
## format id, how a faint is recorded) stays inside
## PUWCombatConsequences / PartyAndStorageManager. The bridge
## only finds the fainted mons in the finished battle party
## and routes each one through.
##
## party_state is the save-shaped Dictionary
## PUWCombatConsequences works on: keys "party",
## "locked_evo_families", "fainting_ledger" (missing keys are
## treated as empty). battle_party is the controller's
## finished player party (mon dicts; a mon with hp <= 0 has
## fainted). context is the battle context Dictionary
## PUWCombatConsequences.permadeath_applies reads:
## {simulation, rental, story, coop} -- missing keys count as
## false, so an ordinary battle ({} context) counts.
##
## Returns {state, removed, applied, exempt_reason}:
## - state: the updated party_state (its "party" is the
##   post-battle party with permanent faints removed; the
##   input Dictionary is never mutated).
## - removed: the mon dicts that were permanently removed,
##   in party order.
## - applied: true when permadeath applied (even if nothing
##   fainted); false when the context exempts the battle.
## - exempt_reason: "simulation" / "rental" when exempt,
##   "" otherwise.


static func apply_battle_end(party_state: Dictionary, battle_party: Array, context: Dictionary) -> Dictionary:
	var state: Dictionary = party_state.duplicate(true)
	state["party"] = battle_party.duplicate(true)
	if not PUWCombatConsequences.permadeath_applies(context):
		var reason: String = "simulation" if bool(context.get("simulation", false)) else "rental"
		return {"state": state, "removed": [], "applied": false, "exempt_reason": reason}
	var removed: Array = []
	for mon_value in battle_party:
		if not (mon_value is Dictionary):
			continue
		var mon: Dictionary = mon_value
		if int(mon.get("hp", 0)) > 0:
			continue
		var before: int = (state.get("party", []) as Array).size()
		state = PUWCombatConsequences.apply_faint_consequences(state, mon, context)
		var after: int = (state.get("party", []) as Array).size()
		if after < before:
			removed.append(mon.duplicate(true))
	return {"state": state, "removed": removed, "applied": true, "exempt_reason": ""}
