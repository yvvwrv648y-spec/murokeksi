class_name PUWQuestBoardGlue
extends RefCounted
## The quest board scene glue (mechanics-completeness prep
## F7, 2026-11-24).
##
## The gap this closes: PUWQuestBoard + PUWQuestGenerator are
## complete and bound (build 4) with full bound content
## (data/quest_postings_<region>.json, 1,050 authored
## postings project-wide), and PUWSaveManager reserves the
## "quests" state key -- but no scene or UI ever calls the
## board: no board is registered, refreshed, accepted from,
## or turned in anywhere in production code.
##
## This glue is the composition the quest prep's own merge
## steps prescribed (code_prep_quests PREP_REPORT step 4):
## register the settlement's board, refresh it for the world
## day with pools built from real world data, post the
## region's authored postings for that board, and expose the
## posting lifecycle (postings / accept / record_event /
## turn_in) for the board UI. It invents no content: authored
## postings come verbatim from the bound data files, and the
## generator only ever fills templates from the pools below.
##
## Pool construction (real data only):
## - species: the global roster from
##   data/evolution_triggers.json ({slug, dex} records -- the
##   same roster source PUWHabitatEncounters uses; encounters
##   are global by canon, so the pool is not region-cut).
## - items: every entry id in PUWItemRegistry.
## - actions: PUWFieldActions.ACTION_ORDER.
## - locations: the region's board ids from its authored
##   postings file (real settlement board ids).
## - formats: ONLY the VEXA format ids the caller passes as
##   honestly built (default: none -- an unbuilt format must
##   never be posted, per the quest prep's rule).
## - habitats: the environment vocabulary keys of
##   PUWHabitatEncounters.HABITAT_TO_ENVIRONMENTS.

const POSTINGS_PATH_FMT: String = "res://data/quest_postings_%s.json"
const ROSTER_PATH: String = "res://data/evolution_triggers.json"

var _grammar: Dictionary = {}


## The quest grammar, loaded once from the bound data file.
func grammar() -> Dictionary:
	if _grammar.is_empty():
		_grammar = PUWQuestGenerator.load_grammar()
	return _grammar


## The bound authored-content file for a region:
## {metadata, postings, special_chains} ({} when absent).
static func load_region_content(region_id: String) -> Dictionary:
	var path: String = POSTINGS_PATH_FMT % region_id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


## Every board id named by a region's authored postings.
static func board_ids_for_region(region_id: String) -> Array:
	var content: Dictionary = load_region_content(region_id)
	var seen: Dictionary = {}
	var out: Array = []
	var postings_value: Variant = content.get("postings", [])
	if postings_value is Array:
		var postings: Array = postings_value
		for posting_value in postings:
			if posting_value is Dictionary:
				var posting: Dictionary = posting_value
				var board_id: String = str(posting.get("board_id", ""))
				if board_id != "" and not seen.has(board_id):
					seen[board_id] = true
					out.append(board_id)
	out.sort()
	return out


## Build the generator pools from real world data (see the
## header). built_vexa_formats is the caller's honest list
## of built VEXA format ids; it defaults to none.
static func build_pools(region_id: String, built_vexa_formats: Array = []) -> Dictionary:
	var species: Array = []
	if FileAccess.file_exists(ROSTER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
		if parsed is Dictionary:
			var roster: Dictionary = parsed
			for key_value in roster.keys():
				var entry_value: Variant = roster[key_value]
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					var slug: String = str(entry.get("slug", entry.get("species_slug", "")))
					if slug != "":
						species.append({"slug": slug, "dex": int(entry.get("id", entry.get("dex", 0)))})
	var items: Array = []
	for entry_value in PUWItemRegistry.all_entries():
		if entry_value is Dictionary:
			var item_entry: Dictionary = entry_value
			var item_id: String = str(item_entry.get("id", ""))
			if item_id != "":
				items.append(item_id)
	var habitats: Array = PUWHabitatEncounters.HABITAT_TO_ENVIRONMENTS.keys()
	return {
		"species": species,
		"items": items,
		"actions": PUWFieldActions.ACTION_ORDER.duplicate(),
		"habitats": habitats,
		"locations": board_ids_for_region(region_id),
		"formats": built_vexa_formats.duplicate(),
	}


## Stand up one board in the save state: ensure the quest
## root, register the board, refresh it for world_day
## (generated postings for the day), then post the region's
## authored postings for this board (post_authored refuses
## duplicates, so re-running setup on a later day re-posts
## authored content a refresh rotated out). The region must
## be the state's active region (PUWQuestBoard's own rule).
## Returns {ok, board_id, generated, authored_posted,
## postings} with the board's live posting list.
func setup_board(state: Dictionary, region_id: String, board_id: String, world_day: int, context: Dictionary = {}, built_vexa_formats: Array = []) -> Dictionary:
	PUWQuestBoard.ensure_quests(state)
	if not PUWQuestBoard.register_board(state, region_id, board_id):
		return {"ok": false, "reason": "register_failed", "board_id": board_id}
	var pools: Dictionary = build_pools(region_id, built_vexa_formats)
	var refresh: Dictionary = PUWQuestBoard.refresh_board(state, grammar(), board_id, world_day, context, pools)
	var authored_posted: int = 0
	var content: Dictionary = load_region_content(region_id)
	var postings_value: Variant = content.get("postings", [])
	if postings_value is Array:
		var authored: Array = postings_value
		for posting_value in authored:
			if posting_value is Dictionary:
				var posting: Dictionary = posting_value
				if str(posting.get("board_id", "")) != board_id:
					continue
				var posted: Dictionary = PUWQuestBoard.post_authored(state, posting, world_day)
				if bool(posted.get("ok", false)):
					authored_posted += 1
	return {
		"ok": true,
		"board_id": board_id,
		"generated": (refresh.get("postings", []) as Array).size(),
		"authored_posted": authored_posted,
		"postings": PUWQuestBoard.postings(state, region_id, board_id),
	}


## The board's current postings.
func postings(state: Dictionary, region_id: String, board_id: String) -> Array:
	return PUWQuestBoard.postings(state, region_id, board_id)


## Accept a posting (PUWQuestBoard.accept_job with the
## loaded grammar).
func accept(state: Dictionary, board_id: String, instance_id: String, context: Dictionary = {}) -> Dictionary:
	return PUWQuestBoard.accept_job(state, grammar(), board_id, instance_id, context)


## Record a world event against accepted jobs (catch /
## defeat / visit / ... -- PUWQuestBoard.record_event).
func record_event(state: Dictionary, event: Dictionary) -> Array:
	return PUWQuestBoard.record_event(state, event)


## Turn in a completed job (grants its reward through
## PUWQuestBoard's own _grant).
func turn_in(state: Dictionary, instance_id: String) -> Dictionary:
	return PUWQuestBoard.turn_in(state, grammar(), instance_id)
