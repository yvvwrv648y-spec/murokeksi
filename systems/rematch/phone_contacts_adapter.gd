class_name PUWPhoneContactsAdapter
extends RefCounted
## Binding build 7, Stage 6 (§4/§4a): the runtime contacts
## adapter for the gsc_phone profile. Builds the runtime
## `contacts` dict from the bound data files exactly as the
## gsc_phone prep's test adapter does (join on map slug +
## name slug against rematch_tables_johto; gates re-based to
## 0-based tier indices; caller_time ANYTIME), then joins
## §4a's sourced wants-battle chances on (name, map_slug),
## REPLACING the profile's three hard-coded anchors and
## retiring the labeled default for wired contacts. The four
## unwired contacts carry no chance field (the profile does
## not consume one for them; readiness comes only from the
## labeled PUW-side rule, via "puw_unwired_rule").
##
## §4a Option B (PM ruling 2026-11-24): the six computed
## contacts' variant_values are applied AT CALL TIME by
## effective_wants_battle_chance() from progression/clock
## state the caller already holds. Conditions, verbatim from
## the chances file:
## - RALPH / ANTHONY / TODD / LIZ / WADE / GINA: chance 0
##   while ENGINE_FLYPOINT_GOLDENROD is unset.
## - GINA: chance 0 while ENGINE_ROCKETS_IN_RADIO_TOWER is
##   set; 30 once EVENT_GINA_GAVE_LEAF_STONE is set.
## - WADE: 13 on a Bug-Catching-Contest weekday (Tue/Thu/Sat)
##   while ENGINE_DAILY_BUG_CONTEST is clear (flypoint open).
## Per-contact blocker-flag episodes (weekday flavor /
## has-item) are NOT modeled — the profile does not model
## those flags (chances file, recorded deviation).
##
## Call-site wirings (§4 Bind 3a-3d) are provided here as the
## single seam a host calls; the bound tree has no live
## overworld host consuming rematch state yet, so 3a-3c have
## no host call site to attach to in this build (named
## remainder in BUILD7_REPORT Stage 6). 3d needs no code:
## the phone slice lives in state["rematch"], plain data in
## the same root the caller already persists.

const TABLES_PATH: String = "res://data/rematch_tables_johto.json"
const MAPPING_PATH: String = "res://data/phone_contact_tier_mapping.json"
const CHANCES_PATH: String = "res://data/phone_wants_battle_chances.json"

const FLYPOINT_GOLDENROD: String = "ENGINE_FLYPOINT_GOLDENROD"
const ROCKETS_RADIO_TOWER: String = "ENGINE_ROCKETS_IN_RADIO_TOWER"
const GINA_GAVE_LEAF_STONE: String = "EVENT_GINA_GAVE_LEAF_STONE"
const DAILY_BUG_CONTEST: String = "ENGINE_DAILY_BUG_CONTEST"

static func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var root: Dictionary = parsed
	return root

static func load_tables() -> Dictionary:
	var root: Dictionary = _load_json(TABLES_PATH)
	var trainers: Dictionary = root.get("trainers", {})
	return trainers

## The bind's join, performed on the bound files.
static func build_contacts() -> Dictionary:
	var tables: Dictionary = load_tables()
	var mapping: Dictionary = _load_json(MAPPING_PATH)
	var chances_root: Dictionary = _load_json(CHANCES_PATH)
	var chance_by_key: Dictionary = {}
	var chance_list: Array = chances_root.get("contacts", [])
	for craw in chance_list:
		var c: Dictionary = craw
		chance_by_key[str(c.get("name", "")) + "|" + str(c.get("map_slug", ""))] = c
	var out: Dictionary = {}
	var mcontacts: Array = mapping.get("contacts", [])
	for raw in mcontacts:
		var c: Dictionary = raw
		var name_slug: String = str(c.get("name", "")).to_lower()
		var map_slug: String = str(c.get("map_slug", ""))
		var key: String = ""
		for k in tables.keys():
			var ks: String = str(k)
			var e: Dictionary = tables[k]
			if str(e.get("map", "")) == map_slug and (ks.contains("_" + name_slug + "_") or ks.ends_with("_" + name_slug)):
				key = ks
				break
		if key.is_empty():
			continue
		var gates: Dictionary = {}
		var mtiers: Array = c.get("tiers", [])
		for traw in mtiers:
			var t: Dictionary = traw
			var g: Variant = t.get("gate_event")
			if g != null and str(g) != "":
				gates[int(t.get("tier", 0)) - 1] = str(g)
		var contact: Dictionary = {"caller_id": str(c.get("caller_id", "")),
			"map": map_slug, "caller_time": "ANYTIME",
			"ladder_wired": bool(c.get("ladder_wired_in_crystal", true)),
			"gates": gates}
		# §4a join: wired contacts get their sourced chance;
		# unwired contacts (chance null) get NO field.
		var crec: Dictionary = chance_by_key.get(str(c.get("name", "")) + "|" + map_slug, {})
		var chance_v: Variant = crec.get("wants_battle_chance")
		if chance_v != null:
			contact["wants_battle_chance"] = int(chance_v)
			contact["chance_source"] = "crystal_caller_script"
		else:
			contact["chance_source"] = "none_unwired"
		out[key] = contact
	return out

## §4a Option B: the chance in force for one call, given the
## progression flags the caller holds and the contest clock.
## weekday: 0=Sunday .. 6=Saturday (caller-supplied).
static func effective_wants_battle_chance(contact_name: String, base_chance: int, progression: Dictionary, weekday: int) -> int:
	match contact_name:
		"RALPH", "ANTHONY", "TODD", "LIZ":
			if not bool(progression.get(FLYPOINT_GOLDENROD, false)):
				return 0
			return base_chance
		"WADE":
			if not bool(progression.get(FLYPOINT_GOLDENROD, false)):
				return 0
			var contest_day: bool = weekday == 2 or weekday == 4 or weekday == 6
			if contest_day and not bool(progression.get(DAILY_BUG_CONTEST, false)):
				return 13
			return base_chance
		"GINA":
			if not bool(progression.get(FLYPOINT_GOLDENROD, false)):
				return 0
			if bool(progression.get(ROCKETS_RADIO_TOWER, false)):
				return 0
			if bool(progression.get(GINA_GAVE_LEAF_STONE, false)):
				return 30
			return base_chance
	return base_chance

## §4 Bind 3a seam: first-battle resolution + registration
## offer acceptance, for a host's Johto phone trainers.
static func on_first_battle_won(state: Dictionary, key: String, won: bool, seed_val: int) -> Dictionary:
	return PUWRematchSystem.phone_record_first_battle(state, key, won, seed_val)

static func on_number_exchange_accepted(state: Dictionary, key: String) -> Dictionary:
	return PUWRematchSystem.phone_register_contact(state, key)

## §4 Bind 3b seam: the game-minute time hook.
static func tick_game_minutes(state: Dictionary, minutes: int) -> void:
	PUWRematchSystem.phone_call_timer_tick(state, minutes)
