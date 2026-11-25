extends SceneTree
## Quest board tests for Pokemon Ultimate World (code prep,
## 2026-11-23). Run: godot --headless --script res://tests/quest_board_tests.gd
##
## Covers the ruled quest spine (design_decisions/
## MEMO_1_QUEST_SPINE.md): PUWQuestBoard + PUWQuestGenerator
## against COPIES of the real pack systems they integrate
## with (PUWSaveManager, PUWRegionState, PUWFollowerCare,
## MartShop):
## - grammar/sample data loads; boards register by their real
##   supply-placement ids;
## - per-place board flow: morning refresh (deterministic,
##   same-day no-op), accept, event progress, turn-in paying
##   data rewards into the real money/bag;
## - stamp -> breakthrough cadence (7 stamps, GO cadence);
## - care-layer seam: progress driven by the REAL
##   PUWFollowerCare groom/treat outcomes;
## - delivery hand-over consuming the real bag;
## - rescue escort seam (requester travels, then goes home);
## - in-world windows (weather) refusing/showing postings;
## - special postings: gated multi-step chains, rank refusal;
## - REGION LOCKS: writes refuse outside the active region,
##   sealed jobs neither advance nor pay out across a border,
##   and survive the round trip home;
## - save round-trip through the real PUWSaveManager.

var _passed: int = 0
var _failed: int = 0

var _grammar: Dictionary = {}
var _sample: Dictionary = {}
var _state: Dictionary = {}

const CTX_CLEAR: Dictionary = {"world_day": 1, "time_of_day": "day", "weather": "clear", "festival": ""}
const CTX_RAIN: Dictionary = {"world_day": 1, "time_of_day": "day", "weather": "rain", "festival": ""}


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _finish() -> void:
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _init() -> void:
	_run.call_deferred()


func _pools() -> Dictionary:
	return {
		"species": [
			{"slug": "pidgey", "dex": 16},
			{"slug": "rattata", "dex": 19},
			{"slug": "caterpie", "dex": 10},
		],
		"items": ["oran-berry", "pecha-berry", "potion"],
		"actions": ["cut", "surf", "strength"],
		"habitats": ["forest", "grassland"],
		"formats": ["single"],
		"locations": ["viridian_forest"],
	}


func _sample_posting(id: String) -> Dictionary:
	var list_value: Variant = _sample.get("postings", [])
	if list_value is Array:
		var list: Array = list_value
		for entry_value: Variant in list:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if str(entry.get("id", "")) == id:
					return entry
	return {}


func _sample_chain(id: String) -> Dictionary:
	var list_value: Variant = _sample.get("special_chains", [])
	if list_value is Array:
		var list: Array = list_value
		for entry_value: Variant in list:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if str(entry.get("id", "")) == id:
					return entry
	return {}


func _posting_ids(postings: Array) -> Array:
	var out: Array = []
	for entry_value: Variant in postings:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			out.append(str(entry.get("instance_id", "")))
	return out


func _accepted_job(instance_id: String, region_id: String = "") -> Dictionary:
	for job_value: Variant in PUWQuestBoard.accepted_jobs(_state, region_id):
		var job: Dictionary = job_value
		if str(job.get("instance_id", "")) == instance_id:
			return job
	return {}


func _run() -> void:
	_grammar = PUWQuestGenerator.load_grammar()
	_check("grammar_loads", not _grammar.is_empty())
	_check("grammar_stamps_7", int(_grammar.get("stamps_per_card", 0)) == 7)
	var templates_value: Variant = _grammar.get("templates", [])
	var template_count: int = 0
	if templates_value is Array:
		var templates: Array = templates_value
		template_count = templates.size()
	_check("grammar_templates_12", template_count == 12, str(template_count))

	var sample_text: String = FileAccess.get_file_as_string("res://tests/quest_sample_postings.json")
	var sample_parsed: Variant = JSON.parse_string(sample_text)
	if sample_parsed is Dictionary:
		_sample = sample_parsed
	_check("sample_loads", not _sample.is_empty())

	_state = PUWSaveManager.build_state([], [], {}, 500, [], [], [], {"region_id": "kanto"}, {})
	PUWRegionState.ensure_regions(_state)
	PUWQuestBoard.ensure_quests(_state)
	_check("active_region_kanto", PUWRegionState.active_region(_state) == "kanto")

	# --- Boards register by real supply-placement ids -------
	_check("register_pallet", PUWQuestBoard.register_board(_state, "kanto", "pallet_town"))
	_check("register_viridian", PUWQuestBoard.register_board(_state, "kanto", "viridian_city"))
	_check("register_one_island", PUWQuestBoard.register_board(_state, "sevii", "one_island"))
	_check("register_duplicate_refused", not PUWQuestBoard.register_board(_state, "kanto", "pallet_town"))
	_check("kanto_boards_2", PUWQuestBoard.registered_boards(_state, "kanto").size() == 2)
	_check("board_region_lookup", PUWQuestBoard.board_region(_state, "one_island") == "sevii")

	# --- Morning refresh: per-place, deterministic ----------
	var refresh: Dictionary = PUWQuestBoard.refresh_board(_state, _grammar, "pallet_town", 1, CTX_CLEAR, _pools())
	_check("refresh_ok", bool(refresh.get("ok", false)))
	var day1_postings: Array = refresh.get("postings", [])
	_check("refresh_count_4", day1_postings.size() == int(_grammar.get("postings_per_board", 4)), str(day1_postings.size()))
	var shapes_ok: bool = true
	var saw_vexa: bool = false
	for posting_value: Variant in day1_postings:
		var posting: Dictionary = posting_value
		var task_value: Variant = posting.get("task", {})
		if not (task_value is Dictionary):
			shapes_ok = false
		else:
			var task: Dictionary = task_value
			if str(task.get("type", "")) == "":
				shapes_ok = false
		if str(posting.get("template_id", "")) == "vexa_sim_clear":
			saw_vexa = true
	_check("refresh_posting_shapes", shapes_ok)
	_check("refresh_rank_gates_vexa", not saw_vexa) # vexa template is rank_min 1; fresh region is rank 0

	var refresh_again: Dictionary = PUWQuestBoard.refresh_board(_state, _grammar, "pallet_town", 1, CTX_CLEAR, _pools())
	_check("refresh_same_day_noop", str(refresh_again.get("reason", "")) == "already_fresh")
	_check("refresh_same_day_same_postings", _posting_ids(refresh_again.get("postings", [])) == _posting_ids(day1_postings))

	var ctx: Dictionary = {"board_id": "pallet_town", "region_id": "kanto", "rank": 0, "world_day": 1, "context": CTX_CLEAR}
	var gen_a: Array = PUWQuestGenerator.generate_postings(_grammar, ctx, _pools(), 424242)
	var gen_b: Array = PUWQuestGenerator.generate_postings(_grammar, ctx, _pools(), 424242)
	_check("generator_deterministic", _posting_ids(gen_a) == _posting_ids(gen_b) and gen_a.size() == gen_b.size())

	var sevii_refresh: Dictionary = PUWQuestBoard.refresh_board(_state, _grammar, "one_island", 1, CTX_CLEAR, _pools())
	_check("refresh_wrong_region_refused", not bool(sevii_refresh.get("ok", true)) and str(sevii_refresh.get("reason", "")) == "wrong_region")

	# --- Accept + care seam (real PUWFollowerCare) ----------
	var groom_def: Dictionary = _sample_posting("sample_groom_pallet")
	_check("authored_posted", bool(PUWQuestBoard.post_authored(_state, groom_def, 1).get("ok", false)))
	var groom_accept: Dictionary = PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "sample_groom_pallet", CTX_CLEAR)
	_check("groom_accepted", bool(groom_accept.get("ok", false)))
	_check("groom_left_board", not _posting_ids(PUWQuestBoard.postings(_state, "kanto", "pallet_town")).has("sample_groom_pallet"))

	var care: PUWFollowerCare = PUWFollowerCare.new()
	var mon: Dictionary = {"slug": "eevee", "nickname": "Testee", "friendship": 10}
	var groom_1: Dictionary = care.groom(mon, 1000.0)
	_check("care_groom_real_gain", bool(groom_1.get("ok", false)) and int(groom_1.get("gain", 0)) == PUWFollowerCare.GROOM_GAIN and int(mon.get("friendship", 0)) == 13)
	var updates: Array = PUWQuestBoard.record_event(_state, {"type": "care", "action": "groom"})
	_check("groom_progress_1", updates.size() == 1 and int(updates[0].get("progress", 0)) == 1 and not bool(updates[0].get("ready", true)))
	var groom_2: Dictionary = care.groom(mon, 1000.0 + PUWFollowerCare.GROOM_COOLDOWN_SECONDS + 1.0)
	_check("care_groom_after_cooldown", bool(groom_2.get("ok", false)))
	updates = PUWQuestBoard.record_event(_state, {"type": "care", "action": "groom"})
	_check("groom_ready", updates.size() == 1 and bool(updates[0].get("ready", false)))

	var money_before: int = int(_state.get("money", 0))
	var turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "sample_groom_pallet")
	_check("groom_turn_in_ok", bool(turn.get("ok", false)))
	_check("groom_reward_money", int(_state.get("money", 0)) == money_before + 200)
	_check("groom_rank_points", PUWQuestBoard.region_rank_points(_state, "kanto") == 6)
	_check("groom_stamp_1", int(turn.get("stamps", 0)) == 1)
	_check("groom_accepted_empty", PUWQuestBoard.accepted_jobs(_state).is_empty())

	# --- Treat seam with the real MartShop bag --------------
	var shop: MartShop = MartShop.new()
	shop.bag = {"oran-berry": 1}
	var treat_mon: Dictionary = {"slug": "pikachu", "nickname": "Treatmon", "friendship": 0}
	var treat_result: Dictionary = care.treat(treat_mon, shop, "oran-berry")
	_check("care_treat_real", bool(treat_result.get("ok", false)) and int(treat_result.get("gain", 0)) == PUWFollowerCare.FEED_GAIN and shop.bag.is_empty())
	shop.free()

	# --- Delivery: bag-checked hand-over --------------------
	_check("deliver_posted", bool(PUWQuestBoard.post_authored(_state, _sample_posting("sample_deliver_pallet"), 1).get("ok", false)))
	_check("deliver_accepted", bool(PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "sample_deliver_pallet", CTX_CLEAR).get("ok", false)))
	var deliver_early: Dictionary = PUWQuestBoard.complete_delivery(_state, "sample_deliver_pallet")
	_check("deliver_missing_item_refused", not bool(deliver_early.get("ok", true)) and str(deliver_early.get("reason", "")) == "missing_item")
	_state["bag"] = {"pecha-berry": 1}
	var deliver_done: Dictionary = PUWQuestBoard.complete_delivery(_state, "sample_deliver_pallet")
	_check("deliver_consumes_item", bool(deliver_done.get("ok", false)) and not (_state.get("bag", {}) as Dictionary).has("pecha-berry"))
	money_before = int(_state.get("money", 0))
	var deliver_turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "sample_deliver_pallet")
	var bag_after: Dictionary = _state.get("bag", {})
	_check("deliver_turn_in", bool(deliver_turn.get("ok", false)) and int(_state.get("money", 0)) == money_before + 300 and int(bag_after.get("poke-ball", 0)) == 2)

	# --- Rescue: escort seam --------------------------------
	_check("rescue_posted", bool(PUWQuestBoard.post_authored(_state, _sample_posting("sample_rescue_viridian"), 1).get("ok", false)))
	_check("rescue_accepted", bool(PUWQuestBoard.accept_job(_state, _grammar, "viridian_city", "sample_rescue_viridian", CTX_CLEAR).get("ok", false)))
	var escorts: Array = PUWQuestBoard.active_escorts(_state)
	_check("escort_active", escorts.size() == 1)
	if escorts.size() == 1:
		var escort: Dictionary = escorts[0]
		_check("escort_is_requester", str(escort.get("species", "")) == "pidgey" and str(escort.get("portrait", "")) == "0016")
	updates = PUWQuestBoard.record_event(_state, {"type": "rescue_reach", "location": "viridian_forest"})
	_check("rescue_ready", updates.size() == 1 and bool(updates[0].get("ready", false)))
	var rescue_turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "sample_rescue_viridian")
	_check("rescue_turn_in", bool(rescue_turn.get("ok", false)) and PUWQuestBoard.active_escorts(_state).is_empty())
	_check("rank_after_rescue", PUWQuestBoard.region_rank_points(_state, "kanto") == 6 + 10 + 20)

	# --- In-world window: rain posting ----------------------
	_check("rain_posted", bool(PUWQuestBoard.post_authored(_state, _sample_posting("sample_rain_watch"), 1).get("ok", false)))
	var rain_clear: Dictionary = PUWQuestBoard.accept_job(_state, _grammar, "viridian_city", "sample_rain_watch", CTX_CLEAR)
	_check("rain_window_closed_in_clear", not bool(rain_clear.get("ok", true)) and str(rain_clear.get("reason", "")) == "window_closed")
	var rain_open: Dictionary = PUWQuestBoard.accept_job(_state, _grammar, "viridian_city", "sample_rain_watch", CTX_RAIN)
	_check("rain_window_open_in_rain", bool(rain_open.get("ok", false)))
	_check("rain_abandoned", PUWQuestBoard.abandon_job(_state, "sample_rain_watch"))

	# --- Stamp card: breakthrough on the 7th stamp ----------
	var pallet_board: Dictionary = PUWQuestBoard.board_state(_state, "kanto", "pallet_town")
	_check("stamps_before_breakthrough_fixture", int(pallet_board.get("stamps", 0)) == 2)
	# Fixture: set the card to 6 stamps directly in the save
	# shape (the board's own state), then earn the 7th.
	var quests_root: Dictionary = _state.get("quests", {})
	var regions: Dictionary = quests_root.get("regions", {})
	var kanto_record: Dictionary = regions.get("kanto", {})
	var boards: Dictionary = kanto_record.get("boards", {})
	var pallet_record: Dictionary = boards.get("pallet_town", {})
	pallet_record["stamps"] = 6
	boards["pallet_town"] = pallet_record
	kanto_record["boards"] = boards
	regions["kanto"] = kanto_record
	quests_root["regions"] = regions
	_state["quests"] = quests_root

	var bt_def: Dictionary = {
		"id": "fixture_seventh_stamp", "board_id": "pallet_town", "region_id": "kanto",
		"kind": "job", "rank_min": 0,
		"requester": {"name": "", "species": "", "portrait": ""},
		"reward": {"money": 10, "items": {}, "rank_points": 1},
		"task": {"type": "battle_win", "target": "", "count": 1},
		"title": "Fixture: seventh stamp", "window": {},
	}
	_check("bt_posted", bool(PUWQuestBoard.post_authored(_state, bt_def, 1).get("ok", false)))
	_check("bt_accepted", bool(PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "fixture_seventh_stamp", CTX_CLEAR).get("ok", false)))
	PUWQuestBoard.record_event(_state, {"type": "battle_win"})
	money_before = int(_state.get("money", 0))
	var bt_turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "fixture_seventh_stamp")
	var bt_reward: Dictionary = bt_turn.get("breakthrough", {})
	_check("breakthrough_fired", bool(bt_turn.get("ok", false)) and not bt_reward.is_empty())
	_check("breakthrough_paid", int(_state.get("money", 0)) == money_before + 10 + 1000)
	_check("breakthrough_card_reset", int(bt_turn.get("stamps", -1)) == 0)
	var pallet_after: Dictionary = PUWQuestBoard.board_state(_state, "kanto", "pallet_town")
	_check("breakthrough_claimed_1", int(pallet_after.get("breakthroughs_claimed", 0)) == 1)

	# --- Special postings: gated chains ---------------------
	var chain_accept: Dictionary = PUWQuestBoard.accept_special(_state, _grammar, _sample_chain("sample_chain_lab_helper"))
	_check("special_accepted", bool(chain_accept.get("ok", false)))
	updates = PUWQuestBoard.record_event(_state, {"type": "catch", "species": "rattata"})
	var saw_special_step: bool = false
	for update_value: Variant in updates:
		var update: Dictionary = update_value
		if str(update.get("kind", "")) == "special" and int(update.get("step_index", 0)) == 1:
			saw_special_step = true
	_check("special_step_1_done", saw_special_step)
	PUWQuestBoard.record_event(_state, {"type": "catch", "species": "rattata"})
	var special_now: Dictionary = PUWQuestBoard.special_state(_state)
	var chain_now: Dictionary = special_now.get("sample_chain_lab_helper", {})
	_check("special_wrong_task_no_advance", int(chain_now.get("step_index", -1)) == 1 and str(chain_now.get("status", "")) == "active")
	updates = PUWQuestBoard.record_event(_state, {"type": "battle_win"})
	special_now = PUWQuestBoard.special_state(_state)
	chain_now = special_now.get("sample_chain_lab_helper", {})
	_check("special_ready", str(chain_now.get("status", "")) == "ready")
	money_before = int(_state.get("money", 0))
	var special_turn: Dictionary = PUWQuestBoard.turn_in_special(_state, "sample_chain_lab_helper")
	bag_after = _state.get("bag", {})
	_check("special_paid", bool(special_turn.get("ok", false)) and int(_state.get("money", 0)) == money_before + 500 and int(bag_after.get("potion", 0)) == 2)
	var locked_chain: Dictionary = PUWQuestBoard.accept_special(_state, _grammar, _sample_chain("sample_chain_locked_example"))
	_check("special_rank_gate_refused", not bool(locked_chain.get("ok", true)) and str(locked_chain.get("reason", "")) == "rank_too_low")

	# --- Accepted cap ---------------------------------------
	var cap_ok: bool = true
	for i: int in range(8):
		var cap_def: Dictionary = {
			"id": "cap_%d" % i, "board_id": "pallet_town", "region_id": "kanto",
			"kind": "job", "rank_min": 0,
			"requester": {"name": "", "species": "", "portrait": ""},
			"reward": {"money": 1, "items": {}, "rank_points": 0},
			"task": {"type": "battle_win", "target": "", "count": 99},
			"title": "Fixture: cap", "window": {},
		}
		if not bool(PUWQuestBoard.post_authored(_state, cap_def, 1).get("ok", false)):
			cap_ok = false
		if not bool(PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "cap_%d" % i, CTX_CLEAR).get("ok", false)):
			cap_ok = false
	_check("cap_accept_8", cap_ok and PUWQuestBoard.accepted_jobs(_state).size() == 8)
	var cap_def_9: Dictionary = {
		"id": "cap_9", "board_id": "pallet_town", "region_id": "kanto",
		"kind": "job", "rank_min": 0,
		"requester": {"name": "", "species": "", "portrait": ""},
		"reward": {"money": 1, "items": {}, "rank_points": 0},
		"task": {"type": "battle_win", "target": "", "count": 99},
		"title": "Fixture: cap 9", "window": {},
	}
	PUWQuestBoard.post_authored(_state, cap_def_9, 1)
	var cap_9: Dictionary = PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "cap_9", CTX_CLEAR)
	_check("cap_9th_refused", not bool(cap_9.get("ok", true)) and str(cap_9.get("reason", "")) == "accepted_full")
	var abandoned_all: bool = true
	for i: int in range(8):
		if not PUWQuestBoard.abandon_job(_state, "cap_%d" % i):
			abandoned_all = false
	_check("cap_cleanup", abandoned_all and PUWQuestBoard.accepted_jobs(_state).is_empty())

	# --- Region locks ---------------------------------------
	var lock_def: Dictionary = {
		"id": "lock_job", "board_id": "pallet_town", "region_id": "kanto",
		"kind": "job", "rank_min": 0,
		"requester": {"name": "", "species": "", "portrait": ""},
		"reward": {"money": 50, "items": {}, "rank_points": 5},
		"task": {"type": "battle_win", "target": "", "count": 1},
		"title": "Fixture: sealed job", "window": {},
	}
	PUWQuestBoard.post_authored(_state, lock_def, 1)
	_check("lock_job_accepted", bool(PUWQuestBoard.accept_job(_state, _grammar, "pallet_town", "lock_job", CTX_CLEAR).get("ok", false)))
	var kanto_points_before: int = PUWQuestBoard.region_rank_points(_state, "kanto")
	PUWRegionState.enter_region(_state, "johto")
	_check("now_in_johto", PUWRegionState.active_region(_state) == "johto")
	_check("johto_accepted_empty", PUWQuestBoard.accepted_jobs(_state).is_empty())
	_check("kanto_job_sealed_not_lost", PUWQuestBoard.accepted_jobs(_state, "kanto").size() == 1)
	PUWQuestBoard.record_event(_state, {"type": "battle_win"})
	var sealed_job: Dictionary = _accepted_job("lock_job", "kanto")
	_check("sealed_job_no_progress", int(sealed_job.get("progress", -1)) == 0 and str(sealed_job.get("status", "")) == "active")
	var johto_turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "lock_job")
	_check("sealed_job_no_turn_in", not bool(johto_turn.get("ok", true)))
	var johto_refresh_pallet: Dictionary = PUWQuestBoard.refresh_board(_state, _grammar, "pallet_town", 2, CTX_CLEAR, _pools())
	_check("sealed_board_no_refresh", not bool(johto_refresh_pallet.get("ok", true)) and str(johto_refresh_pallet.get("reason", "")) == "wrong_region")
	_check("johto_board_registers", PUWQuestBoard.register_board(_state, "johto", "new_bark_town"))
	var johto_refresh: Dictionary = PUWQuestBoard.refresh_board(_state, _grammar, "new_bark_town", 1, CTX_CLEAR, _pools())
	_check("johto_board_refreshes", bool(johto_refresh.get("ok", false)) and (johto_refresh.get("postings", []) as Array).size() == 4)
	_check("johto_rank_independent", PUWQuestBoard.region_rank_points(_state, "johto") == 0 and PUWQuestBoard.region_rank_points(_state, "kanto") == kanto_points_before)
	PUWRegionState.enter_region(_state, "kanto")
	_check("back_in_kanto", PUWRegionState.active_region(_state) == "kanto")
	_check("kanto_job_intact", PUWQuestBoard.accepted_jobs(_state).size() == 1)
	PUWQuestBoard.record_event(_state, {"type": "battle_win"})
	var lock_turn: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, "lock_job")
	_check("kanto_job_completes_at_home", bool(lock_turn.get("ok", false)))

	# --- Save round-trip through the real save manager ------
	var points_before_save: int = PUWQuestBoard.region_rank_points(_state, "kanto")
	_state["quests"] = PUWQuestBoard.to_payload(_state)
	_check("save_writes", PUWSaveManager.save_game(_state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("save_loads", not loaded.is_empty() and loaded.has("quests"))
	_check("save_rank_survives", PUWQuestBoard.region_rank_points(loaded, "kanto") == points_before_save)
	_check("save_boards_survive", PUWQuestBoard.registered_boards(loaded, "kanto").size() == 2)
	var loaded_board: Dictionary = PUWQuestBoard.board_state(loaded, "kanto", "pallet_town")
	_check("save_stamps_survive", int(loaded_board.get("breakthroughs_claimed", 0)) == 1)
	var loaded_special: Dictionary = PUWQuestBoard.special_state(loaded, "kanto")
	var loaded_chain: Dictionary = loaded_special.get("sample_chain_lab_helper", {})
	_check("save_special_survives", str(loaded_chain.get("status", "")) == "done")
	# The loaded state is fully operational, not just data:
	PUWRegionState.ensure_regions(loaded)
	var loaded_refresh: Dictionary = PUWQuestBoard.refresh_board(loaded, _grammar, "pallet_town", 2, CTX_CLEAR, _pools())
	_check("loaded_state_operational", bool(loaded_refresh.get("ok", false)) and (loaded_refresh.get("postings", []) as Array).size() == 4)

	_finish()
