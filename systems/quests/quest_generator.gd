class_name PUWQuestGenerator
extends RefCounted
## Quest posting GENERATOR for the PUW job-board system
## (code prep, 2026-11-23). Turns the quest GRAMMAR
## (data/quest_grammar.json: the GO-research task taxonomy
## ruled in design_decisions/MEMO_1_QUEST_SPINE.md) into
## concrete postings for one settlement board.
##
## Deterministic: the same (grammar, board, world day, rank,
## context, pools) always generates the same postings, so a
## board's morning refresh is reproducible and testable.
##
## Honest-content rules:
## - The generator invents NO requester names. Generated jobs
##   carry an empty requester; naming requesters is content
##   production. The one exception is PMD-flavored by design:
##   a RESCUE posting's requester is a Pokemon drawn from the
##   caller's species pool, with its SpriteCollab portrait id
##   (the pool entry's dex number) -- a Pokemon asking for
##   help, exactly as PMD rescue letters work.
## - Targets come ONLY from the caller's pools (real world
##   data: species present in the region, real item slugs,
##   PUWFieldActions action ids, the VEXA simulator's honestly
##   built formats, real location ids). A template whose pool
##   is empty is skipped, never filled with a fabricated
##   target.
## - Windowed templates (in-world windows only: weather /
##   time of day / world day / festival -- never the real
##   clock) are only posted while their window is open.

const GRAMMAR_PATH: String = "res://data/quest_grammar.json"


## Load and parse a grammar file. Returns {} on any failure;
## callers treat an empty grammar as "no quest system data"
## and refuse to generate.
static func load_grammar(path: String = GRAMMAR_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var grammar: Dictionary = parsed
		return grammar
	return {}


## True when a posting window is open under the caller's
## world context. Context shape (PUWWorldClock vocabulary):
##   {"world_day": int, "time_of_day": "day"|"dusk"|"night",
##    "weather": "clear"|"rain"|"sun"|"snow", "festival": String}
## An empty window is always open. Unknown window kinds are
## treated as CLOSED (never silently open).
static func window_open(window: Dictionary, context: Dictionary) -> bool:
	if window.is_empty():
		return true
	var kind: String = str(window.get("kind", ""))
	var value: String = str(window.get("value", ""))
	match kind:
		"weather":
			return str(context.get("weather", "")) == value
		"time_of_day":
			return str(context.get("time_of_day", "")) == value
		"festival":
			return str(context.get("festival", "")) == value
		"day":
			return int(context.get("world_day", -1)) == int(window.get("value", -2))
	return false


static func _pool_for(pools: Dictionary, target_kind: String) -> Array:
	var key: String = ""
	match target_kind:
		"species":
			key = "species"
		"item":
			key = "items"
		"action":
			key = "actions"
		"habitat":
			key = "habitats"
		"format":
			key = "formats"
		"location":
			key = "locations"
		_:
			return []
	var pool_value: Variant = pools.get(key, [])
	if pool_value is Array:
		var pool: Array = pool_value
		return pool
	return []


## A species pool entry is either a slug String or a
## {"slug": String, "dex": int} Dictionary.
static func _species_slug(entry: Variant) -> String:
	if entry is Dictionary:
		var record: Dictionary = entry
		return str(record.get("slug", ""))
	return str(entry)


static func _species_portrait(entry: Variant) -> String:
	if entry is Dictionary:
		var record: Dictionary = entry
		var dex: int = int(record.get("dex", 0))
		if dex > 0:
			return "%04d" % dex
	return ""


static func _eligible(template: Dictionary, rank: int, context: Dictionary, pools: Dictionary) -> bool:
	if rank < int(template.get("rank_min", 0)):
		return false
	var window_value: Variant = template.get("window", {})
	if window_value is Dictionary:
		var window: Dictionary = window_value
		if not window_open(window, context):
			return false
	var task_value: Variant = template.get("task", {})
	if task_value is Dictionary:
		var task: Dictionary = task_value
		var target_kind: String = str(task.get("target_kind", "none"))
		if target_kind != "none" and target_kind != "any_species":
			if _pool_for(pools, target_kind).is_empty():
				return false
		# A rescue also needs a requester species.
		if str(template.get("kind", "job")) == "rescue":
			if _pool_for(pools, "species").is_empty():
				return false
		return true
	return false


static func _pick_weighted(candidates: Array, rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value
		total += maxi(1, int(candidate.get("weight", 1)))
	if total <= 0:
		return -1
	var roll: int = rng.randi_range(1, total)
	var running: int = 0
	for index: int in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		running += maxi(1, int(candidate.get("weight", 1)))
		if roll <= running:
			return index
	return candidates.size() - 1


static func _fill_posting(template: Dictionary, board_id: String, region_id: String, world_day: int, index: int, pools: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var task_template_value: Variant = template.get("task", {})
	var task_template: Dictionary = {}
	if task_template_value is Dictionary:
		task_template = task_template_value
	var target_kind: String = str(task_template.get("target_kind", "none"))
	var count_range_value: Variant = task_template.get("count_range", [1, 1])
	var count_range: Array = [1, 1]
	if count_range_value is Array:
		count_range = count_range_value
	var count: int = rng.randi_range(int(count_range[0]), int(count_range[1]))

	var target: String = ""
	if target_kind != "none" and target_kind != "any_species":
		var pool: Array = _pool_for(pools, target_kind)
		var entry: Variant = pool[rng.randi_range(0, pool.size() - 1)]
		if target_kind == "species":
			target = _species_slug(entry)
		else:
			target = str(entry)

	var requester: Dictionary = {"name": "", "species": "", "portrait": ""}
	if str(template.get("kind", "job")) == "rescue":
		var species_pool: Array = _pool_for(pools, "species")
		var rescued: Variant = species_pool[rng.randi_range(0, species_pool.size() - 1)]
		requester = {
			"name": _species_slug(rescued),
			"species": _species_slug(rescued),
			"portrait": _species_portrait(rescued),
		}

	var reward_template_value: Variant = template.get("reward", {})
	var reward_template: Dictionary = {}
	if reward_template_value is Dictionary:
		reward_template = reward_template_value
	var money_range_value: Variant = reward_template.get("money_range", [0, 0])
	var money_range: Array = [0, 0]
	if money_range_value is Array:
		money_range = money_range_value
	var reward_items_value: Variant = reward_template.get("items", {})
	var reward_items: Dictionary = {}
	if reward_items_value is Dictionary:
		reward_items = reward_items_value

	var task: Dictionary = {
		"type": str(task_template.get("type", "")),
		"target": target,
		"count": count,
	}
	if task_template.has("action"):
		task["action"] = str(task_template.get("action", ""))

	var title: String = str(template.get("title", ""))
	title = title.replace("{target}", target).replace("{count}", str(count))

	var window_value: Variant = template.get("window", {})
	var window: Dictionary = {}
	if window_value is Dictionary:
		window = window_value

	return {
		"instance_id": "%s-%d-%02d-%s" % [board_id, world_day, index, str(template.get("id", "job"))],
		"template_id": str(template.get("id", "")),
		"kind": str(template.get("kind", "job")),
		"board_id": board_id,
		"region_id": region_id,
		"title": title,
		"requester": requester,
		"task": task,
		"reward": {
			"money": rng.randi_range(int(money_range[0]), int(money_range[1])),
			"items": reward_items.duplicate(true),
			"rank_points": int(reward_template.get("rank_points", 0)),
		},
		"rank_min": int(template.get("rank_min", 0)),
		"window": window.duplicate(true),
		"posted_day": world_day,
	}


## Generate one board's postings for one world day.
## board_ctx: {"board_id", "region_id", "rank", "world_day",
##             "context": {world clock context}}
## Returns up to grammar.postings_per_board postings (fewer
## when the eligible template pool runs out -- never padded
## with fabricated jobs).
static func generate_postings(grammar: Dictionary, board_ctx: Dictionary, pools: Dictionary, seed_value: int) -> Array:
	var out: Array = []
	if grammar.is_empty():
		return out
	var context_value: Variant = board_ctx.get("context", {})
	var context: Dictionary = {}
	if context_value is Dictionary:
		context = context_value
	var rank: int = int(board_ctx.get("rank", 0))
	var templates_value: Variant = grammar.get("templates", [])
	var candidates: Array = []
	if templates_value is Array:
		var templates: Array = templates_value
		for template_value: Variant in templates:
			if template_value is Dictionary:
				var template: Dictionary = template_value
				if _eligible(template, rank, context, pools):
					candidates.append(template)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wanted: int = int(grammar.get("postings_per_board", 4))
	var board_id: String = str(board_ctx.get("board_id", ""))
	var region_id: String = str(board_ctx.get("region_id", ""))
	var world_day: int = int(board_ctx.get("world_day", 1))
	while out.size() < wanted and not candidates.is_empty():
		var pick: int = _pick_weighted(candidates, rng)
		if pick < 0:
			break
		var template: Dictionary = candidates[pick]
		candidates.remove_at(pick)
		out.append(_fill_posting(template, board_id, region_id, world_day, out.size(), pools, rng))
	return out
