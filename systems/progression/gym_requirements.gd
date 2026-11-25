class_name PUWGymRequirements
extends RefCounted
## Gym AVAILABILITY gating -- the second axis of the two-axis gym
## model (Riley canon, 2026-11-22 14:56 CST).
##
## POWER axis (NOT this file, do not confuse the two): gym levels
## and obedience caps scale on the player's GLOBAL badge count --
## the first gym fought anywhere uses the first-gym band, and
## EXPSystem.level_cap_for_badges (battle/exp_system.gd) returns
## the cap for the total badge count. A badge from any region
## raises that count, the band, and the cap.
##
## AVAILABILITY axis (this file): whether a specific gym may be
## started at all is REGIONAL and requirement-based, and is NEVER
## waived by progress in other regions. A foreign badge raises
## your level band and cap but opens NOTHING in Kanto. Each gym's
## own requirements live in data/gym_requirements.json, one record
## per gym, keyed by the same gym ids PUWCampaignStitch uses.
## The schema is region-extensible: every record carries its own
## "region" and nothing in this checker is Kanto-hardcoded.
##
## Requirement types (data-driven, "type" field):
##   "story_flag"    {"flag": id} -- met when the campaign story
##                   flag is true (see state lookups below).
##   "item"          {"item": id} -- met when the player holds
##                   the item.
##   "field_action"  {"action": id} -- met when the field action
##                   is usable, e.g. "cut".
##   "region_badges" {"region": r, "count": n} -- met when the
##                   player holds at least n badges whose gym
##                   belongs to region r. Foreign badges NEVER
##                   count toward it.
##
## State lookups (the campaign state Dictionary the stitch uses,
## built by PUWSaveManager.build_state):
##   story flags: state["story_flags"] -- the same flags store
##     PUWCampaignStitch._flags reads. A story_flag requirement is
##     met when flags[flag_id] is true.
##   badges: state["badges"] -- the same top-level badge list
##     GymProgression.award_badge (campaign/gym_progression.gd)
##     writes. Entries in that list are gym ids (the stitch awards
##     the gym id as the badge id), so a badge's REGION is the
##     prefix of its gym id before "_gym_" (e.g. "kanto_gym_1_brock"
##     -> "kanto", "galar_gym_1" -> "galar").
##   items: the save state has no separate inventory store beyond
##     the bag, so an item requirement is met when the item id is
##     held in state["bag"] (count > 0, the real bag the stitch's
##     new_game_state builds) OR listed in flags["items"] (an Array
##     of item ids, or a Dictionary keyed by item id with a true /
##     positive value) for flows that track items as flags.
##   field actions: there is no field-action store in the state
##     yet, so a field_action requirement is met when the action id
##     is listed in flags["field_actions"] (an Array of action ids,
##     or a Dictionary keyed by action id with a true value). The
##     field-action system writes that key when an action becomes
##     usable.

const REQUIREMENTS_PATH: String = "res://data/gym_requirements.json"


static func _load_data() -> Dictionary:
	var f: FileAccess = FileAccess.open(REQUIREMENTS_PATH, FileAccess.READ)
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


## The full requirements record for a gym id, or {} if the data
## file has no record for it.
static func record_for(gym_id: String) -> Dictionary:
	var data: Dictionary = _load_data()
	var gyms: Array = data.get("gyms", [])
	for entry_value: Variant in gyms:
		var entry: Dictionary = entry_value
		if str(entry.get("gym_id", "")) == gym_id:
			return entry
	return {}


## All gym ids that have a requirements record, in data order.
static func gym_ids() -> Array:
	var data: Dictionary = _load_data()
	var gyms: Array = data.get("gyms", [])
	var out: Array = []
	for entry_value: Variant in gyms:
		var entry: Dictionary = entry_value
		out.append(str(entry.get("gym_id", "")))
	return out


## The requirements list for a gym id ([] when the gym has no
## requirements, and also [] when there is no record -- callers
## that must tell the two apart use record_for()).
static func requirements_for(gym_id: String) -> Array:
	var record: Dictionary = record_for(gym_id)
	var reqs: Array = record.get("requirements", [])
	return reqs


## The region a badge/gym id belongs to: the prefix before
## "_gym_" ("kanto_gym_1_brock" -> "kanto"). An id with no
## "_gym_" marker has no known region ("").
static func region_of_gym_id(gym_id: String) -> String:
	var marker: int = gym_id.find("_gym_")
	if marker <= 0:
		return ""
	return gym_id.substr(0, marker)


## How many of the player's badges belong to a region. Badges are
## the gym ids in state["badges"] (see the header); only ids whose
## region matches count -- foreign badges never count.
static func badge_count_for_region(state: Dictionary, region: String) -> int:
	var badges: Array = state.get("badges", [])
	var count: int = 0
	for badge_value: Variant in badges:
		var badge_id: String = str(badge_value)
		if region_of_gym_id(badge_id) == region:
			count += 1
	return count


static func _has_item(state: Dictionary, item_id: String) -> bool:
	var bag_value: Variant = state.get("bag", {})
	if bag_value is Dictionary:
		var bag: Dictionary = bag_value
		if int(bag.get(item_id, 0)) > 0:
			return true
	var flags: Dictionary = _flags(state)
	var items_value: Variant = flags.get("items", null)
	if items_value is Array:
		var items: Array = items_value
		return items.has(item_id)
	if items_value is Dictionary:
		var items_dict: Dictionary = items_value
		var held: Variant = items_dict.get(item_id, false)
		if held is bool:
			return bool(held)
		if held is int or held is float:
			return int(held) > 0
	return false


static func _has_field_action(state: Dictionary, action_id: String) -> bool:
	var flags: Dictionary = _flags(state)
	var actions_value: Variant = flags.get("field_actions", null)
	if actions_value is Array:
		var actions: Array = actions_value
		return actions.has(action_id)
	if actions_value is Dictionary:
		var actions_dict: Dictionary = actions_value
		return bool(actions_dict.get(action_id, false))
	return false


static func _requirement_met(state: Dictionary, requirement: Dictionary) -> bool:
	var req_type: String = str(requirement.get("type", ""))
	match req_type:
		"story_flag":
			var flags: Dictionary = _flags(state)
			return bool(flags.get(str(requirement.get("flag", "")), false))
		"item":
			return _has_item(state, str(requirement.get("item", "")))
		"field_action":
			return _has_field_action(state, str(requirement.get("action", "")))
		"region_badges":
			var region: String = str(requirement.get("region", ""))
			var needed: int = int(requirement.get("count", 0))
			return badge_count_for_region(state, region) >= needed
	return false


## The requirements of a gym that the state does NOT meet yet.
## Each returned Dictionary is the requirement itself, still
## carrying its human-readable "description" and "source_basis".
## A gym id with no record is never available: it returns one
## synthetic unmet requirement saying so, instead of silently
## treating an unknown gym as open.
static func unmet_requirements(state: Dictionary, gym_id: String) -> Array:
	var record: Dictionary = record_for(gym_id)
	if record.is_empty():
		return [{
			"type": "unknown_gym",
			"description": "No gym requirements record exists for gym id '%s'" % gym_id,
			"source_basis": "data/gym_requirements.json has no record with this gym_id; an unknown gym is refused, never silently opened.",
		}]
	var unmet: Array = []
	var reqs: Array = record.get("requirements", [])
	for req_value: Variant in reqs:
		var req: Dictionary = req_value
		if not _requirement_met(state, req):
			unmet.append(req)
	return unmet


## True when every requirement of the gym is met (including the
## empty-requirements case: Pewter, Cerulean, Fuchsia).
static func can_start_gym(state: Dictionary, gym_id: String) -> bool:
	return unmet_requirements(state, gym_id).is_empty()
