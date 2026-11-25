class_name PUWCombatConsequences
extends RefCounted
## The single decision point for Riley's two canon decisions of
## 2026-11-22 (see CANON_DECISIONS.md in the playable-kanto pack):
##
## 1. PERMADEATH — STORY AND CO-OP COUNT. Permanent fainting plus
##    evolution-family lockout apply in scripted story battles and
##    in multiplayer co-op battles, exactly as in ordinary battles.
##    The ONLY exemptions are simulations (isSimulation = true,
##    e.g. VEXA) and rentals. This resolves the
##    scripted_story_battle / multiplayer_coop_battle
##    REQUIRES_CANON_DECISION flags in Neon's
##    core/master_rules_engine.gd: NO exceptions. That file is
##    Neon's verbatim source and is NOT edited; this module is the
##    operative implementation.
##
## 2. GIMMICKS — OFFICIAL ONLY. The Omni Bracelet channels exactly
##    five per-side budget families: Mega Evolution, Z-Moves,
##    ordinary Dynamax, Gigantamax, Terastallization. There is NO
##    fifth gimmick slot: Neon's gimmick_slot_5_pending_canon flag
##    is closed as "does not exist".
##
## How faint recording really works today (investigated 2026-11-22):
## PartyAndStorageManager.handle_faint(slot, is_simulation, format)
## is the one place a faint is recorded. It removes the mon from
## the party, sets locked_evo_families[mon.evo_family] = true, and
## appends {"name", "evo_family", "format"} to fainting_ledger.
## Its only exemption is is_simulation. PUWSaveManager itself never
## records faints (mon dicts are opaque to it); a save-shaped party
## state therefore carries the same three keys used here:
## "party", "locked_evo_families", "fainting_ledger".
## apply_faint_consequences() below DELEGATES to handle_faint so
## the recording representation can never drift from the house
## rules.

## The five per-side gimmick budget keys, exactly as they appear in
## BattleController's battle_state["gimmick_budgets"] (the v3
## engine): "mega", "zmove", "dynamax", "gigantamax", "tera".
## Plain names: Mega Evolution, Z-Move, Dynamax, Gigantamax,
## Terastallization. There is no sixth key and no slot 5.
const GIMMICK_FAMILY_KEYS: Array = ["mega", "zmove", "dynamax", "gigantamax", "tera"]


## True when a faint in this battle context is permanent.
## Context keys (missing keys count as false):
##   simulation, rental, story, coop.
## Returns false ONLY when simulation or rental is true;
## simulation wins even combined with story/coop. Ordinary, story,
## and co-op battles all count.
static func permadeath_applies(context: Dictionary) -> bool:
	if bool(context.get("simulation", false)):
		return false
	if bool(context.get("rental", false)):
		return false
	return true


## The format id written into the fainting ledger for a context,
## using the battle-kind names from Neon's
## PERMANENT_FAINTING_EXCEPTIONS register.
static func format_id_for_context(context: Dictionary) -> String:
	if bool(context.get("coop", false)):
		return "multiplayer_coop_battle"
	if bool(context.get("story", false)):
		return "scripted_story_battle"
	return "standard"


## Record one faint's consequences on a deep copy of party_state
## and return the copy; the caller's state is never mutated.
## party_state keys: "party" (Array of mon dicts),
## "locked_evo_families" (Dictionary family -> true),
## "fainting_ledger" (Array of {"name", "evo_family", "format"}).
## Missing keys are treated as empty and are only added to the
## returned state when a faint is actually recorded.
## When permadeath does not apply (simulation / rental), the
## returned state is identical to the input.
## The recording itself is delegated to
## PartyAndStorageManager.handle_faint with is_simulation = false.
static func apply_faint_consequences(party_state: Dictionary, mon: Dictionary, context: Dictionary) -> Dictionary:
	var result: Dictionary = party_state.duplicate(true)
	if not permadeath_applies(context):
		return result
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		var party_copy: Array = party_value
		mgr.party = party_copy.duplicate(true)
	var locked_value: Variant = result.get("locked_evo_families", {})
	if locked_value is Dictionary:
		var locked_copy: Dictionary = locked_value
		mgr.locked_evo_families = locked_copy.duplicate(true)
	var ledger_value: Variant = result.get("fainting_ledger", [])
	if ledger_value is Array:
		var ledger_copy: Array = ledger_value
		mgr.fainting_ledger = ledger_copy.duplicate(true)
	var slot: int = _find_slot(mgr.party, mon)
	if slot >= 0:
		mgr.handle_faint(slot, false, format_id_for_context(context))
	else:
		# The fainted mon is not in this party state (for example a
		# co-op partner's mon recorded into the shared ledger):
		# record the lockout and ledger entry in exactly the same
		# representation handle_faint uses, minus the removal.
		var fam: String = str(mon.get("evo_family", "unknown"))
		mgr.locked_evo_families[fam] = true
		mgr.fainting_ledger.append({"name": str(mon.get("name", "")), "evo_family": fam, "format": format_id_for_context(context)})
	result["party"] = mgr.party
	result["locked_evo_families"] = mgr.locked_evo_families
	result["fainting_ledger"] = mgr.fainting_ledger
	mgr.free()
	return result


## Find the party slot of the fainted mon: exact dict match first,
## then a name + species + evo_family match. -1 when absent.
static func _find_slot(party: Array, mon: Dictionary) -> int:
	for i in party.size():
		var candidate_value: Variant = party[i]
		if candidate_value is Dictionary:
			var candidate: Dictionary = candidate_value
			if candidate == mon:
				return i
	for i in party.size():
		var candidate_value: Variant = party[i]
		if candidate_value is Dictionary:
			var candidate: Dictionary = candidate_value
			if str(candidate.get("name", "")) == str(mon.get("name", "")) \
					and str(candidate.get("species", "")) == str(mon.get("species", "")) \
					and str(candidate.get("evo_family", "")) == str(mon.get("evo_family", "")):
				return i
	return -1


## The exact five gimmick budget families, in budget order.
## No fifth slot, no pending entry, nothing else.
static func gimmick_families() -> Array:
	return GIMMICK_FAMILY_KEYS.duplicate()


## The standing Omni rule (same rule as
## PUWCampaignStitch.can_use_omni and GameManager's
## can_activate_omni_bracelet): usable only outside Kanto AND
## unlocked. VEXA's auto-enable inside a simulation is the
## simulator's own context, not this function.
static func omni_can_use(region: String, unlocked: bool) -> bool:
	return region != "kanto" and unlocked
