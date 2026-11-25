class_name PUWRegionState
extends RefCounted
## REGION-LOCK CAMPAIGNS (Riley canon, 2026-11-22 14:46-14:52 CST).
##
## The world is open -- the player may travel to any region -- but
## CAMPAIGNS are locked per region:
##
## - Entering a region the player has NOT beaten starts a FRESH
##   campaign there: that region's own party/boxes start new, and
##   Pokemon from other regions are INACCESSIBLE. They are never
##   deleted; they stay stored in their home region's party/boxes
##   inside the save.
## - Leaving an unbeaten region leaves the Pokemon caught there
##   behind in that region's storage.
## - The unlock gate is the regional CHAMPION. Only when a
##   region's Champion is beaten does the region join the shared
##   pool: beaten regions restore the team left there, and beaten
##   regions may use each other's Pokemon freely.
## - A region at 99% (everything but its Champion beaten) stays
##   sealed BOTH ways: no importing a cleared region's team to
##   finish it, and no exporting its Pokemon.
##
## Storage model (additive; nothing else in the save changes):
##   state["regions"] = {
##       "active_region": <region id String>,
##       "regions": {
##           <region id>: {
##               "champion_beaten": bool,
##               "badges": [gym ids won in this region],
##               "party": [mon dicts belonging to this region],
##               "boxes": [mon dicts belonging to this region],
##           }, ...
##       },
##   }
## The save's top-level state["party"] / state["boxes"] are the
## ACTIVE region's working party/boxes: enter_region() first
## writes them back into the outgoing region's record (sync-out),
## then loads the incoming region's record into them (sync-in).
## Callers keep using state["party"] exactly as before while a
## region is active; this module moves the data at the borders.
##
## Badges: the save's top-level state["badges"] stays the GLOBAL
## badge list GymProgression reads (global badge count drives gym
## level bands and obedience caps -- the power axis). Each region
## record ALSO keeps the list of gym ids won in that region;
## note_badge() maintains it. PUWCampaignStitch.record_gym_win
## calls note_badge() when the regions structure exists.
##
## Availability rule (available_party / available_boxes), stated
## precisely:
## - If the ACTIVE region is beaten (its Champion has fallen):
##   accessible = the active region's own Pokemon PLUS every other
##   BEATEN region's Pokemon. Unbeaten regions' Pokemon stay
##   sealed in their home records.
## - If the ACTIVE region is unbeaten: accessible = ONLY the
##   active region's own Pokemon -- even if other regions are
##   beaten. A 99% region therefore cannot import a cleared
##   region's team, and its Pokemon cannot be reached from a
##   beaten region either (they are not in any beaten record's
##   pool while their home region is unbeaten... they become
##   reachable only from inside their own region, or everywhere
##   once their region is beaten).
##
## Region-generic: no region id is hardcoded except the "kanto"
## default for a brand-new save (the only region with full game
## data, and the stitch's own default region).

const DEFAULT_REGION: String = "kanto"


static func _flags(state: Dictionary) -> Dictionary:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		return flags
	return {}


static func _empty_record() -> Dictionary:
	return {
		"champion_beaten": false,
		"badges": [],
		"party": [],
		"boxes": [],
	}


## Make sure state["regions"] exists and is well-formed. On first
## call, the active region is taken from story_flags["region_id"]
## (falling back to DEFAULT_REGION) and the save's current
## top-level party/boxes are adopted as that region's own -- so a
## save built before this module existed (e.g. a stitch new-game
## state with a starter already chosen) loses nothing.
## Returns the regions root Dictionary (also stored in state).
static func ensure_regions(state: Dictionary) -> Dictionary:
	var root_value: Variant = state.get("regions", {})
	var root: Dictionary = {}
	if root_value is Dictionary:
		root = root_value
	var records_value: Variant = root.get("regions", {})
	var records: Dictionary = {}
	if records_value is Dictionary:
		records = records_value
	var active: String = str(root.get("active_region", ""))
	if active == "":
		active = str(_flags(state).get("region_id", DEFAULT_REGION))
		if active == "":
			active = DEFAULT_REGION
	if not records.has(active):
		var seed: Dictionary = _empty_record()
		var party_value: Variant = state.get("party", [])
		if party_value is Array:
			var party: Array = party_value
			seed["party"] = party.duplicate(true)
		var boxes_value: Variant = state.get("boxes", [])
		if boxes_value is Array:
			var boxes: Array = boxes_value
			seed["boxes"] = boxes.duplicate(true)
		records[active] = seed
	root["regions"] = records
	root["active_region"] = active
	state["regions"] = root
	return root


static func _records(state: Dictionary) -> Dictionary:
	var root: Dictionary = ensure_regions(state)
	var records: Dictionary = root.get("regions", {})
	return records


static func _record(state: Dictionary, region_id: String) -> Dictionary:
	var records: Dictionary = _records(state)
	var record_value: Variant = records.get(region_id, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return record
	return {}


static func _store_record(state: Dictionary, region_id: String, record: Dictionary) -> void:
	var root: Dictionary = ensure_regions(state)
	var records: Dictionary = root.get("regions", {})
	records[region_id] = record
	root["regions"] = records
	state["regions"] = root


## The region the player is currently campaigning in.
static func active_region(state: Dictionary) -> String:
	var root: Dictionary = ensure_regions(state)
	return str(root.get("active_region", DEFAULT_REGION))


## True when region_id's Champion has been beaten.
static func region_beaten(state: Dictionary, region_id: String) -> bool:
	var record: Dictionary = _record(state, region_id)
	return bool(record.get("champion_beaten", false))


## Record a regional Champion win: the region joins the shared
## pool from this moment. Returns false for an empty region id or
## a region already beaten.
static func record_champion_win(state: Dictionary, region_id: String) -> bool:
	if region_id == "":
		return false
	var record: Dictionary = _record(state, region_id)
	if record.is_empty():
		record = _empty_record()
	if bool(record.get("champion_beaten", false)):
		return false
	record["champion_beaten"] = true
	_store_record(state, region_id, record)
	return true


## Maintain a region record's own badge list (gym ids won there).
## The global list in state["badges"] is GymProgression's and is
## NOT touched here. Returns false on a duplicate or empty id.
static func note_badge(state: Dictionary, region_id: String, gym_id: String) -> bool:
	if region_id == "" or gym_id == "":
		return false
	var record: Dictionary = _record(state, region_id)
	if record.is_empty():
		record = _empty_record()
	var badges_value: Variant = record.get("badges", [])
	var badges: Array = []
	if badges_value is Array:
		badges = badges_value
	if badges.has(gym_id):
		return false
	badges.append(gym_id)
	record["badges"] = badges
	_store_record(state, region_id, record)
	return true


static func region_badges(state: Dictionary, region_id: String) -> Array:
	var record: Dictionary = _record(state, region_id)
	var badges_value: Variant = record.get("badges", [])
	if badges_value is Array:
		var badges: Array = badges_value
		return badges.duplicate()
	return []


## Write the save's top-level party/boxes back into the ACTIVE
## region's record. Called by enter_region before switching, and
## by the available_* readers so a caller that edited
## state["party"] directly is never read stale.
static func _sync_out(state: Dictionary) -> void:
	var active: String = active_region(state)
	var record: Dictionary = _record(state, active)
	if record.is_empty():
		record = _empty_record()
	var party_value: Variant = state.get("party", [])
	if party_value is Array:
		var party: Array = party_value
		record["party"] = party.duplicate(true)
	var boxes_value: Variant = state.get("boxes", [])
	if boxes_value is Array:
		var boxes: Array = boxes_value
		record["boxes"] = boxes.duplicate(true)
	_store_record(state, active, record)


## Load a region record into the save's top-level party/boxes.
static func _sync_in(state: Dictionary, region_id: String) -> void:
	var record: Dictionary = _record(state, region_id)
	var party_value: Variant = record.get("party", [])
	if party_value is Array:
		var party: Array = party_value
		state["party"] = party.duplicate(true)
	else:
		state["party"] = []
	var boxes_value: Variant = record.get("boxes", [])
	if boxes_value is Array:
		var boxes: Array = boxes_value
		state["boxes"] = boxes.duplicate(true)
	else:
		state["boxes"] = []


## Enter a region: the border crossing that enforces the lock.
## 1. The outgoing region's record absorbs the current top-level
##    party/boxes (nothing is deleted, ever).
## 2. A region with no record yet gets a fresh empty one -- the
##    fresh start: no party, no boxes, no badges of its own.
## 3. The incoming region's record becomes the top-level
##    party/boxes, and story_flags["region_id"] follows (the
##    stitch's region flag, e.g. for the Omni lock).
## Returns the now-active campaign context:
##   {"region_id", "champion_beaten", "fresh_start" (true when
##   the region is unbeaten -- its campaign stands alone),
##   "badges" (the region's own), "party" (its working party),
##   "available_party" (see the header rule)}.
static func enter_region(state: Dictionary, region_id: String) -> Dictionary:
	if region_id == "":
		return {}
	ensure_regions(state)
	_sync_out(state)
	if _record(state, region_id).is_empty():
		_store_record(state, region_id, _empty_record())
	var root: Dictionary = ensure_regions(state)
	root["active_region"] = region_id
	state["regions"] = root
	var flags: Dictionary = _flags(state)
	flags["region_id"] = region_id
	state["story_flags"] = flags
	_sync_in(state, region_id)
	var record: Dictionary = _record(state, region_id)
	var beaten: bool = bool(record.get("champion_beaten", false))
	return {
		"region_id": region_id,
		"champion_beaten": beaten,
		"fresh_start": not beaten,
		"badges": region_badges(state, region_id),
		"party": state.get("party", []),
		"available_party": available_party(state),
	}


static func _available(state: Dictionary, key: String) -> Array:
	_sync_out(state)
	var active: String = active_region(state)
	var out: Array = []
	var active_record: Dictionary = _record(state, active)
	var own_value: Variant = active_record.get(key, [])
	if own_value is Array:
		var own: Array = own_value
		for mon_value: Variant in own:
			out.append(mon_value)
	if bool(active_record.get("champion_beaten", false)):
		var records: Dictionary = _records(state)
		for region_value: Variant in records.keys():
			var region_id: String = str(region_value)
			if region_id == active:
				continue
			var record: Dictionary = _record(state, region_id)
			if not bool(record.get("champion_beaten", false)):
				continue
			var pool_value: Variant = record.get(key, [])
			if pool_value is Array:
				var pool: Array = pool_value
				for mon_value: Variant in pool:
					out.append(mon_value)
	return out


## The Pokemon accessible right now (see the header for the exact
## rule): the active region's own party, plus -- only when the
## active region is beaten -- every other beaten region's party.
static func available_party(state: Dictionary) -> Array:
	return _available(state, "party")


## Same rule as available_party, for boxed Pokemon.
static func available_boxes(state: Dictionary) -> Array:
	return _available(state, "boxes")


## The party stored under a region's own record, whether or not
## it is accessible right now. This is how a test (or a save
## inspector) proves sealed Pokemon were stored, not deleted.
static func stored_party(state: Dictionary, region_id: String) -> Array:
	_sync_out(state)
	var record: Dictionary = _record(state, region_id)
	var party_value: Variant = record.get("party", [])
	if party_value is Array:
		var party: Array = party_value
		return party.duplicate(true)
	return []


## Same as stored_party, for a region record's boxes.
static func stored_boxes(state: Dictionary, region_id: String) -> Array:
	_sync_out(state)
	var record: Dictionary = _record(state, region_id)
	var boxes_value: Variant = record.get("boxes", [])
	if boxes_value is Array:
		var boxes: Array = boxes_value
		return boxes.duplicate(true)
	return []
