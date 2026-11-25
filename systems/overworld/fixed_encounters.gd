class_name PUWFixedEncounters
extends RefCounted
## FIXED (STATIC) ENCOUNTERS -- the placed, one-off wild
## encounters that live outside every map's wild table (the
## Mewtwo in Cerulean Cave is the Kanto instance). Records live
## in data/fixed_encounters.json, one per encounter, in the
## house record style of data/gym_requirements.json (record +
## source_basis per claim); this file is only the reader and
## the two predicates the host needs:
##
##   access_allowed(state, record) -- the encounter's access
##     gate against the save state. The one gate type the data
##     uses today is "story_flag": met when the named flag in
##     state["story_flags"] (the PUWCampaignStitch flag store)
##     is true. This is the check the Cerulean Cave entrance
##     applies BEFORE the player can reach the encounter at
##     all: pre-Champion, entry is refused.
##   is_available(state, record) -- the encounter has not been
##     resolved yet: its once.resolved_flag is not set.
##   record_outcome(state, record, outcome) -- writes the
##     resolution the SOURCE semantics dictate: only outcomes
##     in the record's once.consumed_by list set the resolved
##     flag (for Mewtwo: "caught" and "defeated"); outcomes in
##     once.not_consumed_by (fleeing, teleporting out) leave
##     the encounter available for another attempt, exactly as
##     the source's FLAG_FOUGHT_MEWTWO behaves. Returns true
##     when the outcome resolved the encounter.
##
## The battle itself is not built here: the record's
## battle_identity is a PUWBattleEntry scripted-battle identity
## (species only), so the host starts it through the same B5
## door as every other scripted battle and reports the battle
## scene's outcome back through record_outcome.

const FIXED_ENCOUNTERS_PATH: String = "res://data/fixed_encounters.json"


static func _load_data() -> Dictionary:
	var f: FileAccess = FileAccess.open(FIXED_ENCOUNTERS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func _flags(state: Dictionary) -> Dictionary:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		return flags
	return {}


## All fixed-encounter records, in data order.
static func records() -> Array:
	var data: Dictionary = _load_data()
	var out: Array = []
	var list_v: Variant = data.get("fixed_encounters", [])
	if list_v is Array:
		var list: Array = list_v
		for entry_v in list:
			if entry_v is Dictionary:
				out.append(entry_v)
	return out


## The record for an encounter id, or {} if there is none.
static func record_for(encounter_id: String) -> Dictionary:
	for record_v in records():
		var record: Dictionary = record_v
		if str(record.get("id", "")) == encounter_id:
			return record
	return {}


## The encounter's access gate against the live state.
## Returns {"allowed": bool, "gate": {...}, "unmet": String} --
## unmet names the gate that failed, for the host's refusal
## presentation. An encounter with no access_gate is open.
static func access_gate_result(state: Dictionary, record: Dictionary) -> Dictionary:
	var gate_v: Variant = record.get("access_gate", {})
	if not (gate_v is Dictionary):
		return {"allowed": true, "gate": {}, "unmet": ""}
	var gate: Dictionary = gate_v
	var gate_type: String = str(gate.get("type", ""))
	match gate_type:
		"story_flag":
			var flag: String = str(gate.get("flag", ""))
			var flags: Dictionary = _flags(state)
			if flag != "" and bool(flags.get(flag, false)):
				return {"allowed": true, "gate": gate, "unmet": ""}
			return {"allowed": false, "gate": gate,
				"unmet": "story flag '" + flag + "' is not set"}
		_:
			return {"allowed": false, "gate": gate,
				"unmet": "unknown access gate type '" + gate_type + "'"}
	return {"allowed": false, "gate": gate, "unmet": "unreachable gate state"}


static func access_allowed(state: Dictionary, record: Dictionary) -> bool:
	return bool(access_gate_result(state, record).get("allowed", false))


## True while the encounter is unresolved in this save.
static func is_available(state: Dictionary, record: Dictionary) -> bool:
	var once_v: Variant = record.get("once", {})
	if not (once_v is Dictionary):
		return true
	var once: Dictionary = once_v
	var resolved_flag: String = str(once.get("resolved_flag", ""))
	if resolved_flag == "":
		return true
	var flags: Dictionary = _flags(state)
	return not bool(flags.get(resolved_flag, false))


## Record a finished battle's outcome ("caught", "defeated",
## "ran", "player_teleported", ...). Sets the encounter's
## resolved flag ONLY when the record's once.consumed_by list
## names the outcome -- the source's once-only semantics, read
## from the data, never hardcoded per species. Returns true
## when this outcome resolved the encounter.
static func record_outcome(state: Dictionary, record: Dictionary, outcome: String) -> bool:
	var once_v: Variant = record.get("once", {})
	if not (once_v is Dictionary):
		return false
	var once: Dictionary = once_v
	var consumed_v: Variant = once.get("consumed_by", [])
	if not (consumed_v is Array):
		return false
	var consumed: Array = consumed_v
	if not consumed.has(outcome):
		return false
	var resolved_flag: String = str(once.get("resolved_flag", ""))
	if resolved_flag == "":
		return false
	var flags: Dictionary = _flags(state)
	flags[resolved_flag] = true
	state["story_flags"] = flags
	return true
