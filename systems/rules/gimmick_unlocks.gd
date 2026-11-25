class_name PUWGimmickUnlocks
extends RefCounted
## Progression unlocks for gimmick families (Riley canon,
## 2026-11-22 14:05 CST): each gimmick family is locked until it
## is reached in the journey. In Kanto NO gimmick is active --
## the same rule as the Omni Bracelet lock. No unlock points are
## defined in this Kanto build; set_flag() exists so future
## region phases can grant a family when its point is reached.
##
## Families (save-flag names) and the v3 engine's per-side budget
## keys in BattleController.battle_state["gimmick_budgets"]:
##   budget "mega"         -> family "mega"
##   budget "zmove"        -> family "z_move"
##   budget "dynamax"      -> family "dynamax"
##   budget "gigantamax"   -> family "dynamax"
##   budget "tera"         -> family "terastallization"
## Primal Reversion and Ultra Burst are unbudgeted engine
## mechanics (see CANON_DECISIONS.md); they have no budget key
## and are not gated here.
##
## Flags live in the save state built by
## PUWSaveManager.build_state, under
## story_flags["gimmick_unlocks"] = {mega, z_move, dynamax,
## terastallization} (all bool). A state that lacks the key is
## treated as all locked -- never default to unlocked.
##
## Battle seam: BattleController.run_turn actions carry a
## "gimmick" field and BattleController._apply_gimmick() /
## _apply_z_move() are the engine entry points that spend a
## budget and call PUWGimmicks. Pack code (the campaign stitch)
## never attempts a gimmick in a real battle, so the mandatory
## pre-check is attempt_gimmick() below, in this file: it is the
## only integration-layer route to the engine's gimmick path,
## and it calls the engine ONLY when the gate allows.

const FAMILIES: Array = ["mega", "z_move", "dynamax", "terastallization"]

const BUDGET_TO_FAMILY: Dictionary = {
	"mega": "mega",
	"zmove": "z_move",
	"dynamax": "dynamax",
	"gigantamax": "dynamax",
	"tera": "terastallization",
}

const FAMILY_NAMES: Dictionary = {
	"mega": "Mega Evolution",
	"z_move": "Z-Moves",
	"dynamax": "Dynamax/Gigantamax",
	"terastallization": "Terastallization",
}


## The Kanto start state: every family locked.
static func default_flags() -> Dictionary:
	return {"mega": false, "z_move": false, "dynamax": false, "terastallization": false}


## The family that owns a budget key, or "" for a key that is
## not a budgeted gimmick (unknown, primal, ultra, ...).
static func family_for_budget(budget_key: String) -> String:
	return str(BUDGET_TO_FAMILY.get(budget_key, ""))


static func _sanitize(flags_value: Variant) -> Dictionary:
	var out: Dictionary = default_flags()
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		for family_value: Variant in FAMILIES:
			var family: String = str(family_value)
			out[family] = bool(flags.get(family, false))
	return out


## Read the unlock flags from a save state. Missing story_flags
## or a missing gimmick_unlocks key means all locked.
static func read_flags(save_state: Dictionary) -> Dictionary:
	var flags_value: Variant = save_state.get("story_flags", {})
	if flags_value is Dictionary:
		var story_flags: Dictionary = flags_value
		return _sanitize(story_flags.get("gimmick_unlocks", {}))
	return default_flags()


## A copy of save_state with its gimmick unlock flags replaced
## by the given flags (sanitized to the four families). The
## caller's state is never mutated.
static func with_flags(save_state: Dictionary, flags: Dictionary) -> Dictionary:
	var result: Dictionary = save_state.duplicate(true)
	var story_value: Variant = result.get("story_flags", {})
	var story_flags: Dictionary = {}
	if story_value is Dictionary:
		var existing: Dictionary = story_value
		story_flags = existing.duplicate(true)
	story_flags["gimmick_unlocks"] = _sanitize(flags)
	result["story_flags"] = story_flags
	return result


## A copy of save_state with one family's flag set. For future
## region phases; no unlock points are defined in Kanto.
## Unknown families return an unchanged copy.
static func set_flag(save_state: Dictionary, family: String, value: bool) -> Dictionary:
	var flags: Dictionary = read_flags(save_state)
	if FAMILIES.has(family):
		flags[family] = value
	return with_flags(save_state, flags)


## True when this budget key may be used in this save state.
## Simulations are always allowed: VEXA's sim auto-enables the
## Omni Ring by Neon's spec -- the sim is a sandbox, documented
## in CANON_DECISIONS.md. Otherwise the family flag must be
## true. Unknown budget keys are never allowed.
static func is_budget_allowed(budget_key: String, save_state: Dictionary, simulation: bool) -> bool:
	if simulation:
		return BUDGET_TO_FAMILY.has(budget_key)
	var family: String = family_for_budget(budget_key)
	if family == "":
		return false
	var flags: Dictionary = read_flags(save_state)
	return bool(flags.get(family, false))


## The mandatory battle-facing pre-check. Callers must route
## every real-battle gimmick attempt through here.
##   battle:     a started BattleController (its active mon for
##               the acting side is party slot 0)
##   budget_key: one of "mega", "zmove", "dynamax",
##               "gigantamax", "tera"
##   action:     the run_turn-style action dict for the attempt
##               (move_name, plus tera_type / z_crystal as the
##               engine's own _apply_gimmick/_apply_z_move read)
## Returns {allowed: bool, reason: String, logs: Array} (plus
## "z_result" for a Z-Move attempt). When the gate refuses, the
## engine is never called: no budget is spent and the mon does
## not transform. When the gate allows, the engine's real path
## runs (BattleController._apply_gimmick, or _apply_z_move for
## "zmove"); the engine may still refuse for its own reasons,
## which land in logs.
static func attempt_gimmick(battle: BattleController, budget_key: String, save_state: Dictionary, simulation: bool, action: Dictionary = {}, is_player: bool = true) -> Dictionary:
	var family: String = family_for_budget(budget_key)
	if family == "":
		return {"allowed": false, "reason": "Unknown gimmick budget key '" + budget_key + "': not a budgeted gimmick family.", "logs": []}
	if not is_budget_allowed(budget_key, save_state, simulation):
		var family_name: String = str(FAMILY_NAMES.get(family, family))
		return {"allowed": false, "reason": "Gimmick locked: " + family_name + " (family '" + family + "', budget '" + budget_key + "') is locked until its progression unlock is reached. In Kanto no gimmick is active.", "logs": []}
	var party: Array = battle.player_party if is_player else battle.enemy_party
	if party.is_empty():
		return {"allowed": false, "reason": "Gimmick attempt allowed by the unlock gate, but the acting side has no Pokemon in the battle.", "logs": []}
	var attacker_value: Variant = party[0]
	if not (attacker_value is Dictionary):
		return {"allowed": false, "reason": "Gimmick attempt allowed by the unlock gate, but the acting Pokemon is not a mon dict.", "logs": []}
	var attacker: Dictionary = attacker_value
	var logs: Array = []
	var effective: Dictionary = action.duplicate(true)
	if budget_key == "zmove":
		var move_name: String = str(effective.get("move_name", ""))
		var z_result: Dictionary = battle._apply_z_move(effective, move_name, logs, attacker, is_player)
		return {"allowed": true, "reason": "", "logs": logs, "z_result": z_result}
	effective["gimmick"] = budget_key
	battle._apply_gimmick(effective, attacker, logs, is_player)
	return {"allowed": true, "reason": "", "logs": logs}
