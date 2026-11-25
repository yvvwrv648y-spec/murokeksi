class_name PUWQuestBoard
extends RefCounted
## The PUW quest spine: per-settlement JOB BOARDS
## (code prep, 2026-11-23). Ruled in
## design_decisions/MEMO_1_QUEST_SPINE.md (Bossy, 2026-11-23):
## the Pokemon Mystery Dungeon job board is the structure --
## a physical board at each settlement's supply-trio / Vexa
## cluster, per-region postings and a per-region rank ladder --
## and Pokemon GO research supplies the task grammar posted
## on it (catch / care / walk / field-action / habitat /
## battle / VEXA-sim / deliver / rescue tasks, the stamp ->
## breakthrough cadence, and gated multi-step "special
## postings"). GO's placeless global profile and real-clock
## timing are rejected: everything here is scoped to a region
## and windows are in-world only.
##
## REGION LOCKS (the reason the board is the spine): all quest
## state lives per region inside the save, mirroring
## PUWRegionState's storage model. Writes (refresh, accept,
## event progress, turn-in) apply ONLY to the ACTIVE region
## (PUWRegionState.active_region). A fresh-start region starts
## with empty boards, no accepted jobs, rank zero -- nothing
## leaks across the border, and the sealed region's jobs wait
## untouched in its own record. Reads may name any region (a
## save inspector can prove sealed state was kept, not lost).
##
## Save shape (additive key "quests" in the save state; the
## merge follows the habitat_rotation precedent -- see
## PREP_REPORT.md):
##   state["quests"] = {
##     "version": 1,
##     "regions": {
##       <region id>: {
##         "rank_points": int,
##         "completed_count": int,
##         "boards": {
##           <board id (= supply placement id)>: {
##             "region_id": String,
##             "postings": [posting instances on the board],
##             "stamps": int,               # current stamp card
##             "breakthroughs_claimed": int,
##             "last_refresh_day": int,
##           }, ...
##         },
##         "accepted": {<instance id>: accepted job record},
##         "special":  {<chain id>: special chain record},
##       }, ...
##     },
##   }
## Rewards are DATA ({"money": int, "items": {slug: count},
## "rank_points": int}) applied to the save's real money/bag
## at turn-in. Battles inside jobs run at full canon rules --
## a failed rescue is a failed JOB, never a softened battle;
## nothing in this module touches battle state.
##
## Follower care integration: care tasks (groom / treat /
## talk / feed) advance through the same event seam as every
## other task -- the caller performs the real
## PUWFollowerCare action and then posts
## {"type": "care", "action": "groom"} here. Rescue jobs put
## their requester in "escort" while accepted;
## active_escorts() is the seam the follower controller reads
## to spawn the temporary follower (the spawn itself is a
## binding-build wiring step, see PREP_REPORT.md).

const STATE_KEY: String = "quests"
const STATE_VERSION: int = 1


# ------------------------------------------------------------------
# State plumbing
# ------------------------------------------------------------------

static func ensure_quests(state: Dictionary) -> Dictionary:
	var root_value: Variant = state.get(STATE_KEY, {})
	var root: Dictionary = {}
	if root_value is Dictionary:
		root = root_value
	if not root.has("version"):
		root["version"] = STATE_VERSION
	if not root.has("regions"):
		root["regions"] = {}
	state[STATE_KEY] = root
	return root


static func _empty_region_record() -> Dictionary:
	return {
		"rank_points": 0,
		"completed_count": 0,
		"boards": {},
		"accepted": {},
		"special": {},
	}


static func _region_record(state: Dictionary, region_id: String) -> Dictionary:
	var root: Dictionary = ensure_quests(state)
	var regions_value: Variant = root.get("regions", {})
	var regions: Dictionary = {}
	if regions_value is Dictionary:
		regions = regions_value
	var record_value: Variant = regions.get(region_id, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return record
	var fresh: Dictionary = _empty_region_record()
	regions[region_id] = fresh
	root["regions"] = regions
	state[STATE_KEY] = root
	return fresh


static func _store_region(state: Dictionary, region_id: String, record: Dictionary) -> void:
	var root: Dictionary = ensure_quests(state)
	var regions_value: Variant = root.get("regions", {})
	var regions: Dictionary = {}
	if regions_value is Dictionary:
		regions = regions_value
	regions[region_id] = record
	root["regions"] = regions
	state[STATE_KEY] = root


static func _empty_board(region_id: String) -> Dictionary:
	return {
		"region_id": region_id,
		"postings": [],
		"stamps": 0,
		"breakthroughs_claimed": 0,
		"last_refresh_day": 0,
	}


static func _board_record(state: Dictionary, region_id: String, board_id: String) -> Dictionary:
	var record: Dictionary = _region_record(state, region_id)
	var boards_value: Variant = record.get("boards", {})
	if boards_value is Dictionary:
		var boards: Dictionary = boards_value
		var board_value: Variant = boards.get(board_id, {})
		if board_value is Dictionary:
			var board: Dictionary = board_value
			return board
	return {}


static func _store_board(state: Dictionary, region_id: String, board_id: String, board: Dictionary) -> void:
	var record: Dictionary = _region_record(state, region_id)
	var boards_value: Variant = record.get("boards", {})
	var boards: Dictionary = {}
	if boards_value is Dictionary:
		boards = boards_value
	boards[board_id] = board
	record["boards"] = boards
	_store_region(state, region_id, record)


## The active region per the region-lock module. All write
## paths resolve through this.
static func _active(state: Dictionary) -> String:
	return PUWRegionState.active_region(state)


## Deep copy of the whole quest subtree, for the save
## builder's additive key (merge step in PREP_REPORT.md).
static func to_payload(state: Dictionary) -> Dictionary:
	var root: Dictionary = ensure_quests(state)
	return root.duplicate(true)


# ------------------------------------------------------------------
# Boards and rank
# ------------------------------------------------------------------

## Register a board for a region. Board ids are the supply
## placement ids (data/supply_placements.json) -- the board
## stands at the trio/Vexa cluster the placements already
## bound. Registration is bookkeeping and is allowed for any
## region; USING a board is region-guarded below.
## Returns false when the board already exists.
static func register_board(state: Dictionary, region_id: String, board_id: String) -> bool:
	if region_id == "" or board_id == "":
		return false
	if not _board_record(state, region_id, board_id).is_empty():
		return false
	_store_board(state, region_id, board_id, _empty_board(region_id))
	return true


static func registered_boards(state: Dictionary, region_id: String) -> Array:
	var record: Dictionary = _region_record(state, region_id)
	var boards_value: Variant = record.get("boards", {})
	var out: Array = []
	if boards_value is Dictionary:
		var boards: Dictionary = boards_value
		out = boards.keys()
	out.sort()
	return out


## Which region a board belongs to ("" when unregistered).
static func board_region(state: Dictionary, board_id: String) -> String:
	var root: Dictionary = ensure_quests(state)
	var regions_value: Variant = root.get("regions", {})
	if regions_value is Dictionary:
		var regions: Dictionary = regions_value
		for region_value: Variant in regions.keys():
			var region_id: String = str(region_value)
			if not _board_record(state, region_id, board_id).is_empty():
				return region_id
	return ""


## A copy of one board's state (postings, stamps, refresh
## day), or {} when unregistered. Read-only inspection; any
## region may be named.
static func board_state(state: Dictionary, region_id: String, board_id: String) -> Dictionary:
	var board: Dictionary = _board_record(state, region_id, board_id)
	return board.duplicate(true)


static func region_rank_points(state: Dictionary, region_id: String) -> int:
	var record: Dictionary = _region_record(state, region_id)
	return int(record.get("rank_points", 0))


## The rank a points total earns on the grammar's ladder:
## {"rank": int, "name": String, "points": int (the total)}.
static func rank_for_points(grammar: Dictionary, points: int) -> Dictionary:
	var ladder_value: Variant = grammar.get("rank_ladder", [])
	var best: Dictionary = {"rank": 0, "name": "Normal Rank", "points": points}
	if ladder_value is Array:
		var ladder: Array = ladder_value
		for rung_value: Variant in ladder:
			if rung_value is Dictionary:
				var rung: Dictionary = rung_value
				if points >= int(rung.get("points", 0)):
					best = {
						"rank": int(rung.get("rank", 0)),
						"name": str(rung.get("name", "")),
						"points": points,
					}
	return best


static func region_rank(state: Dictionary, grammar: Dictionary, region_id: String) -> Dictionary:
	return rank_for_points(grammar, region_rank_points(state, region_id))


# ------------------------------------------------------------------
# Postings: refresh (generated) and authored
# ------------------------------------------------------------------

## The morning refresh: regenerate a board's postings for a
## new world day (PUWWorldClock day, passed in). Same-day
## refresh is a no-op ("already_fresh"). Region-guarded: the
## board must belong to the ACTIVE region.
static func refresh_board(state: Dictionary, grammar: Dictionary, board_id: String, world_day: int, context: Dictionary, pools: Dictionary) -> Dictionary:
	var region_id: String = board_region(state, board_id)
	if region_id == "":
		return {"ok": false, "reason": "unknown_board", "postings": []}
	if region_id != _active(state):
		return {"ok": false, "reason": "wrong_region", "postings": []}
	var board: Dictionary = _board_record(state, region_id, board_id)
	if int(board.get("last_refresh_day", 0)) == world_day:
		var current_value: Variant = board.get("postings", [])
		var current: Array = []
		if current_value is Array:
			current = current_value
		return {"ok": true, "reason": "already_fresh", "postings": current.duplicate(true)}
	var rank: Dictionary = region_rank(state, grammar, region_id)
	var board_ctx: Dictionary = {
		"board_id": board_id,
		"region_id": region_id,
		"rank": int(rank.get("rank", 0)),
		"world_day": world_day,
		"context": context,
	}
	var seed_value: int = absi(board_id.hash()) * 131 + world_day * 1000003
	var generated: Array = PUWQuestGenerator.generate_postings(grammar, board_ctx, pools, seed_value)
	board["postings"] = generated
	board["last_refresh_day"] = world_day
	_store_board(state, region_id, board_id, board)
	return {"ok": true, "reason": "", "postings": generated.duplicate(true)}


## Copies of the postings currently on a board. Any region
## may be named (read-only).
static func postings(state: Dictionary, region_id: String, board_id: String) -> Array:
	var board: Dictionary = _board_record(state, region_id, board_id)
	var list_value: Variant = board.get("postings", [])
	if list_value is Array:
		var list: Array = list_value
		return list.duplicate(true)
	return []


## Post an AUTHORED posting (sample content, NPC-posted
## story jobs, event postings) onto a board. The definition
## follows the sample file's shape (data/
## quest_sample_postings.json): it carries its own id,
## board_id, region_id, task, reward, requester, window.
## Region-guarded like every write. Authored postings live
## until accepted or until the next morning refresh replaces
## the board (documented board behavior).
static func post_authored(state: Dictionary, posting_def: Dictionary, world_day: int) -> Dictionary:
	var board_id: String = str(posting_def.get("board_id", ""))
	var region_id: String = str(posting_def.get("region_id", ""))
	if board_id == "" or region_id == "":
		return {"ok": false, "reason": "bad_posting"}
	if region_id != _active(state):
		return {"ok": false, "reason": "wrong_region"}
	var board: Dictionary = _board_record(state, region_id, board_id)
	if board.is_empty():
		return {"ok": false, "reason": "unknown_board"}
	var instance: Dictionary = posting_def.duplicate(true)
	instance["instance_id"] = str(posting_def.get("id", ""))
	if str(instance.get("instance_id", "")) == "":
		return {"ok": false, "reason": "bad_posting"}
	instance["template_id"] = "authored"
	instance["posted_day"] = world_day
	var list_value: Variant = board.get("postings", [])
	var list: Array = []
	if list_value is Array:
		list = list_value
	for existing_value: Variant in list:
		if existing_value is Dictionary:
			var existing: Dictionary = existing_value
			if str(existing.get("instance_id", "")) == str(instance.get("instance_id", "")):
				return {"ok": false, "reason": "duplicate"}
	list.append(instance)
	board["postings"] = list
	_store_board(state, region_id, board_id, board)
	return {"ok": true, "reason": "", "posting": instance.duplicate(true)}


# ------------------------------------------------------------------
# Accept / progress / turn-in
# ------------------------------------------------------------------

## Accept a posting from a board. Region-guarded; the
## posting's in-world window must be open under the caller's
## context; the region's accepted cap (grammar) applies.
## Rescue jobs gain their "escort" (the requester travels
## with the party until turn-in or abandonment).
static func accept_job(state: Dictionary, grammar: Dictionary, board_id: String, instance_id: String, context: Dictionary) -> Dictionary:
	var region_id: String = board_region(state, board_id)
	if region_id == "":
		return {"ok": false, "reason": "unknown_board"}
	if region_id != _active(state):
		return {"ok": false, "reason": "wrong_region"}
	var record: Dictionary = _region_record(state, region_id)
	var accepted_value: Variant = record.get("accepted", {})
	var accepted: Dictionary = {}
	if accepted_value is Dictionary:
		accepted = accepted_value
	if accepted.has(instance_id):
		return {"ok": false, "reason": "already_accepted"}
	if accepted.size() >= int(grammar.get("max_accepted_per_region", 8)):
		return {"ok": false, "reason": "accepted_full"}
	var board: Dictionary = _board_record(state, region_id, board_id)
	var list_value: Variant = board.get("postings", [])
	var list: Array = []
	if list_value is Array:
		list = list_value
	var found_index: int = -1
	var posting: Dictionary = {}
	for index: int in range(list.size()):
		var entry_value: Variant = list[index]
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if str(entry.get("instance_id", "")) == instance_id:
				found_index = index
				posting = entry
				break
	if found_index < 0:
		return {"ok": false, "reason": "not_posted"}
	var window_value: Variant = posting.get("window", {})
	if window_value is Dictionary:
		var window: Dictionary = window_value
		if not PUWQuestGenerator.window_open(window, context):
			return {"ok": false, "reason": "window_closed"}
	if region_rank_points(state, region_id) < int(posting.get("rank_min", 0)):
		return {"ok": false, "reason": "rank_too_low"}
	list.remove_at(found_index)
	board["postings"] = list
	_store_board(state, region_id, board_id, board)
	var job: Dictionary = posting.duplicate(true)
	job["status"] = "active"
	job["progress"] = 0
	if str(job.get("kind", "job")) == "rescue":
		var requester_value: Variant = job.get("requester", {})
		if requester_value is Dictionary:
			var requester: Dictionary = requester_value
			job["escort"] = requester.duplicate(true)
	accepted[instance_id] = job
	record["accepted"] = accepted
	_store_region(state, region_id, record)
	return {"ok": true, "reason": "", "job": job.duplicate(true)}


## Copies of the region's accepted jobs. Defaults to the
## ACTIVE region; naming another region is read-only proof
## of sealed state.
static func accepted_jobs(state: Dictionary, region_id: String = "") -> Array:
	var region: String = region_id
	if region == "":
		region = _active(state)
	var record: Dictionary = _region_record(state, region)
	var accepted_value: Variant = record.get("accepted", {})
	var out: Array = []
	if accepted_value is Dictionary:
		var accepted: Dictionary = accepted_value
		var keys: Array = accepted.keys()
		keys.sort()
		for key_value: Variant in keys:
			var job_value: Variant = accepted.get(key_value, {})
			if job_value is Dictionary:
				var job: Dictionary = job_value
				out.append(job.duplicate(true))
	return out


## The escorts currently traveling with the party (accepted
## rescue requesters, ACTIVE region). The follower
## controller's spawn seam.
static func active_escorts(state: Dictionary) -> Array:
	var out: Array = []
	for job_value: Variant in accepted_jobs(state):
		var job: Dictionary = job_value
		var escort_value: Variant = job.get("escort", {})
		if escort_value is Dictionary:
			var escort: Dictionary = escort_value
			if not escort.is_empty():
				out.append(escort.duplicate(true))
	return out


static func _task_delta(task: Dictionary, event: Dictionary) -> int:
	var task_type: String = str(task.get("type", ""))
	var event_type: String = str(event.get("type", ""))
	if task_type == "deliver":
		return 0 # deliveries complete via complete_delivery()
	if task_type == "care":
		if event_type != "care":
			return 0
		return 1 if str(event.get("action", "")) == str(task.get("action", "")) else 0
	if event_type != task_type:
		return 0
	match task_type:
		"walk":
			return maxi(0, int(event.get("steps", 0)))
		"catch":
			var target: String = str(task.get("target", ""))
			if target == "" or target == str(event.get("species", "")):
				return 1
			return 0
		"field_action":
			var action_target: String = str(task.get("target", ""))
			if action_target == "" or action_target == str(event.get("action", "")):
				return 1
			return 0
		"habitat":
			var habitat_target: String = str(task.get("target", ""))
			if habitat_target == "" or habitat_target == str(event.get("habitat", "")):
				return 1
			return 0
		"vexa_clear":
			var format_target: String = str(task.get("target", ""))
			if format_target == "" or format_target == str(event.get("format", "")):
				return 1
			return 0
		"rescue_reach":
			return 1 if str(task.get("target", "")) == str(event.get("location", "")) else 0
		"battle_win":
			return 1
	return 0


static func _advance(job: Dictionary, event: Dictionary) -> Dictionary:
	var task_value: Variant = job.get("task", {})
	if not (task_value is Dictionary):
		return {}
	var task: Dictionary = task_value
	var delta: int = _task_delta(task, event)
	if delta <= 0:
		return {}
	var count: int = int(task.get("count", 1))
	var progress: int = mini(count, int(job.get("progress", 0)) + delta)
	job["progress"] = progress
	if progress >= count and str(job.get("status", "")) == "active":
		job["status"] = "ready"
	return {
		"progress": progress,
		"count": count,
		"ready": str(job.get("status", "")) == "ready",
	}


## Post a gameplay event; every matching accepted job and
## the current step of every active special chain IN THE
## ACTIVE REGION advances. Event shapes:
##   {"type": "catch", "species": slug}
##   {"type": "care", "action": "groom"|"treat"|"talk"|"feed"}
##   {"type": "walk", "steps": int}
##   {"type": "field_action", "action": action id}
##   {"type": "habitat", "habitat": habitat id}
##   {"type": "battle_win"}
##   {"type": "vexa_clear", "format": format id}
##   {"type": "rescue_reach", "location": location id}
## Returns update records ({"kind": "job"|"special", "id",
## "progress", "count", "ready", ...}).
static func record_event(state: Dictionary, event: Dictionary) -> Array:
	var updates: Array = []
	var region_id: String = _active(state)
	var record: Dictionary = _region_record(state, region_id)
	var accepted_value: Variant = record.get("accepted", {})
	if accepted_value is Dictionary:
		var accepted: Dictionary = accepted_value
		for key_value: Variant in accepted.keys():
			var job_value: Variant = accepted.get(key_value, {})
			if job_value is Dictionary:
				var job: Dictionary = job_value
				var update: Dictionary = _advance(job, event)
				if not update.is_empty():
					accepted[key_value] = job
					update["kind"] = "job"
					update["id"] = str(key_value)
					updates.append(update)
		record["accepted"] = accepted
	var special_value: Variant = record.get("special", {})
	if special_value is Dictionary:
		var special: Dictionary = special_value
		for chain_key: Variant in special.keys():
			var chain_value: Variant = special.get(chain_key, {})
			if chain_value is Dictionary:
				var chain: Dictionary = chain_value
				var update: Dictionary = _advance_chain(chain, event)
				if not update.is_empty():
					special[chain_key] = chain
					updates.append(update)
		record["special"] = special
	_store_region(state, region_id, record)
	return updates


## Complete a delivery job's hand-over: the items must be in
## the save's real bag; they are consumed and the job becomes
## ready to turn in. (Payment happens at turn_in, like every
## job -- the board pays, the client receives the goods.)
static func complete_delivery(state: Dictionary, instance_id: String) -> Dictionary:
	var region_id: String = _active(state)
	var record: Dictionary = _region_record(state, region_id)
	var accepted_value: Variant = record.get("accepted", {})
	if not (accepted_value is Dictionary):
		return {"ok": false, "reason": "not_accepted"}
	var accepted: Dictionary = accepted_value
	if not accepted.has(instance_id):
		return {"ok": false, "reason": "not_accepted"}
	var job_value: Variant = accepted.get(instance_id, {})
	var job: Dictionary = {}
	if job_value is Dictionary:
		job = job_value
	var task_value: Variant = job.get("task", {})
	var task: Dictionary = {}
	if task_value is Dictionary:
		task = task_value
	if str(task.get("type", "")) != "deliver":
		return {"ok": false, "reason": "not_delivery"}
	var item: String = str(task.get("target", ""))
	var count: int = int(task.get("count", 1))
	var bag_value: Variant = state.get("bag", {})
	var bag: Dictionary = {}
	if bag_value is Dictionary:
		bag = bag_value
	if int(bag.get(item, 0)) < count:
		return {"ok": false, "reason": "missing_item"}
	bag[item] = int(bag.get(item, 0)) - count
	if int(bag[item]) <= 0:
		bag.erase(item)
	state["bag"] = bag
	job["progress"] = count
	job["status"] = "ready"
	accepted[instance_id] = job
	record["accepted"] = accepted
	_store_region(state, region_id, record)
	return {"ok": true, "reason": "", "job": job.duplicate(true)}


static func _grant(state: Dictionary, record: Dictionary, reward: Dictionary) -> void:
	var money: int = int(reward.get("money", 0))
	if money != 0:
		state["money"] = int(state.get("money", 0)) + money
	var items_value: Variant = reward.get("items", {})
	if items_value is Dictionary:
		var items: Dictionary = items_value
		if not items.is_empty():
			var bag_value: Variant = state.get("bag", {})
			var bag: Dictionary = {}
			if bag_value is Dictionary:
				bag = bag_value
			for slug_value: Variant in items.keys():
				var slug: String = str(slug_value)
				bag[slug] = int(bag.get(slug, 0)) + int(items.get(slug_value, 0))
			state["bag"] = bag
	var rank_points: int = int(reward.get("rank_points", 0))
	if rank_points != 0:
		record["rank_points"] = int(record.get("rank_points", 0)) + rank_points


## Turn in a ready job at its board: the reward (data) is
## paid into the save's money/bag, the region gains the
## job's rank points, and the origin board's stamp card
## gains a stamp. A filled card (grammar.stamps_per_card,
## GO's 7) pays the board's breakthrough reward and the card
## resets. Region-guarded through the active region's
## accepted set.
static func turn_in(state: Dictionary, grammar: Dictionary, instance_id: String) -> Dictionary:
	var region_id: String = _active(state)
	var record: Dictionary = _region_record(state, region_id)
	var accepted_value: Variant = record.get("accepted", {})
	if not (accepted_value is Dictionary):
		return {"ok": false, "reason": "not_accepted"}
	var accepted: Dictionary = accepted_value
	if not accepted.has(instance_id):
		return {"ok": false, "reason": "not_accepted"}
	var job_value: Variant = accepted.get(instance_id, {})
	var job: Dictionary = {}
	if job_value is Dictionary:
		job = job_value
	if str(job.get("status", "")) != "ready":
		return {"ok": false, "reason": "not_ready"}
	var reward_value: Variant = job.get("reward", {})
	var reward: Dictionary = {}
	if reward_value is Dictionary:
		reward = reward_value
	_grant(state, record, reward)
	accepted.erase(instance_id)
	record["accepted"] = accepted
	record["completed_count"] = int(record.get("completed_count", 0)) + 1
	var breakthrough: Dictionary = {}
	var board_id: String = str(job.get("board_id", ""))
	var board: Dictionary = _board_record(state, region_id, board_id)
	if not board.is_empty():
		var stamps: int = int(board.get("stamps", 0)) + 1
		var per_card: int = maxi(1, int(grammar.get("stamps_per_card", 7)))
		while stamps >= per_card:
			stamps -= per_card
			board["breakthroughs_claimed"] = int(board.get("breakthroughs_claimed", 0)) + 1
			var bt_value: Variant = grammar.get("breakthrough_reward", {})
			if bt_value is Dictionary:
				var bt_reward: Dictionary = bt_value
				_grant(state, record, bt_reward)
				breakthrough = bt_reward.duplicate(true)
		board["stamps"] = stamps
		_store_board(state, region_id, board_id, board)
	_store_region(state, region_id, record)
	return {
		"ok": true,
		"reason": "",
		"reward": reward.duplicate(true),
		"breakthrough": breakthrough,
		"stamps": int(board.get("stamps", 0)) if not board.is_empty() else 0,
	}


## Abandon an accepted job (ACTIVE region). The posting is
## NOT returned to the board (the morning refresh replaces
## it); an escort goes home. No penalty -- design note in
## PREP_REPORT.md.
static func abandon_job(state: Dictionary, instance_id: String) -> bool:
	var region_id: String = _active(state)
	var record: Dictionary = _region_record(state, region_id)
	var accepted_value: Variant = record.get("accepted", {})
	if accepted_value is Dictionary:
		var accepted: Dictionary = accepted_value
		if accepted.has(instance_id):
			accepted.erase(instance_id)
			record["accepted"] = accepted
			_store_region(state, region_id, record)
			return true
	return false


# ------------------------------------------------------------------
# Special postings (gated multi-step chains)
# ------------------------------------------------------------------

## Start a special posting chain. The definition is DATA
## (sample shape: {id, region_id, board_id, title, posted_by,
## steps: [task...], reward, unlock: {min_rank, flag}}).
## Region-guarded; the unlock (region rank and/or a story
## flag) must hold.
static func accept_special(state: Dictionary, grammar: Dictionary, chain_def: Dictionary) -> Dictionary:
	var chain_id: String = str(chain_def.get("id", ""))
	var region_id: String = str(chain_def.get("region_id", ""))
	if chain_id == "" or region_id == "":
		return {"ok": false, "reason": "bad_chain"}
	if region_id != _active(state):
		return {"ok": false, "reason": "wrong_region"}
	var unlock_value: Variant = chain_def.get("unlock", {})
	var unlock: Dictionary = {}
	if unlock_value is Dictionary:
		unlock = unlock_value
	var rank: Dictionary = region_rank(state, grammar, region_id)
	if int(rank.get("rank", 0)) < int(unlock.get("min_rank", 0)):
		return {"ok": false, "reason": "rank_too_low"}
	var flag: String = str(unlock.get("flag", ""))
	if flag != "":
		var flags_value: Variant = state.get("story_flags", {})
		var flags: Dictionary = {}
		if flags_value is Dictionary:
			flags = flags_value
		if not bool(flags.get(flag, false)):
			return {"ok": false, "reason": "locked"}
	var record: Dictionary = _region_record(state, region_id)
	var special_value: Variant = record.get("special", {})
	var special: Dictionary = {}
	if special_value is Dictionary:
		special = special_value
	if special.has(chain_id):
		return {"ok": false, "reason": "already_started"}
	special[chain_id] = {
		"chain_id": chain_id,
		"status": "active",
		"step_index": 0,
		"progress": 0,
		"def": chain_def.duplicate(true),
	}
	record["special"] = special
	_store_region(state, region_id, record)
	return {"ok": true, "reason": "", "chain_id": chain_id}


static func _advance_chain(chain: Dictionary, event: Dictionary) -> Dictionary:
	if str(chain.get("status", "")) != "active":
		return {}
	var def_value: Variant = chain.get("def", {})
	if not (def_value is Dictionary):
		return {}
	var chain_def: Dictionary = def_value
	var steps_value: Variant = chain_def.get("steps", [])
	if not (steps_value is Array):
		return {}
	var steps: Array = steps_value
	var step_index: int = int(chain.get("step_index", 0))
	if step_index < 0 or step_index >= steps.size():
		return {}
	var step_value: Variant = steps[step_index]
	if not (step_value is Dictionary):
		return {}
	var step: Dictionary = step_value
	# Reuse the job matcher: a step IS a task plus a title.
	var probe: Dictionary = {"task": step, "progress": int(chain.get("progress", 0)), "status": "active"}
	var update: Dictionary = _advance(probe, event)
	if update.is_empty():
		return {}
	chain["progress"] = int(probe.get("progress", 0))
	if bool(update.get("ready", false)):
		step_index += 1
		chain["step_index"] = step_index
		chain["progress"] = 0
		if step_index >= steps.size():
			chain["status"] = "ready"
	return {
		"kind": "special",
		"id": str(chain.get("chain_id", "")),
		"step_index": int(chain.get("step_index", 0)),
		"ready": str(chain.get("status", "")) == "ready",
	}


## Copies of the region's special chain records. Defaults
## to the ACTIVE region.
static func special_state(state: Dictionary, region_id: String = "") -> Dictionary:
	var region: String = region_id
	if region == "":
		region = _active(state)
	var record: Dictionary = _region_record(state, region)
	var special_value: Variant = record.get("special", {})
	if special_value is Dictionary:
		var special: Dictionary = special_value
		return special.duplicate(true)
	return {}


## Turn in a finished special chain: pays the chain reward
## (data) into money/bag/rank and marks the chain done.
## Specials earn no stamp (stamps are the field-task card).
static func turn_in_special(state: Dictionary, chain_id: String) -> Dictionary:
	var region_id: String = _active(state)
	var record: Dictionary = _region_record(state, region_id)
	var special_value: Variant = record.get("special", {})
	if not (special_value is Dictionary):
		return {"ok": false, "reason": "not_started"}
	var special: Dictionary = special_value
	if not special.has(chain_id):
		return {"ok": false, "reason": "not_started"}
	var chain_value: Variant = special.get(chain_id, {})
	var chain: Dictionary = {}
	if chain_value is Dictionary:
		chain = chain_value
	if str(chain.get("status", "")) != "ready":
		return {"ok": false, "reason": "not_ready"}
	var def_value: Variant = chain.get("def", {})
	var chain_def: Dictionary = {}
	if def_value is Dictionary:
		chain_def = def_value
	var reward_value: Variant = chain_def.get("reward", {})
	var reward: Dictionary = {}
	if reward_value is Dictionary:
		reward = reward_value
	_grant(state, record, reward)
	chain["status"] = "done"
	special[chain_id] = chain
	record["special"] = special
	record["completed_count"] = int(record.get("completed_count", 0)) + 1
	_store_region(state, region_id, record)
	return {"ok": true, "reason": "", "reward": reward.duplicate(true)}
