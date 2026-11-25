extends SceneTree
## Headless tests for the PP Max move-picker flow (code prep
## code_prep_pp_max, binding build 6):
##   - ItemEngine gained the PP Max arm: a selected move's max
##     PP straight to its ceiling under the engine's own PP Up
##     accounting (+60% of base = 3 PP Up steps; PokeAPI item
##     prose id 53), topping up partly-raised moves and
##     refusing maxed ones.
##   - The PP Up arm is untouched: its outcomes are pinned
##     step by step as the regression.
##   - PUWItemTarget answers validity at two levels for PP Up
##     / PP Max (mon level for the party picker, move level
##     for the new PUWMovePickerScreen), and use_on_mon
##     resolves only with a chosen move — consuming exactly
##     one item, refusing untouched otherwise.
##   - The full flow runs end to end through a real
##     BW2MenuStack: bag -> party picker -> move picker ->
##     resolution -> back to the bag.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/pp_max_tests.gd
## It prints one PASS or FAIL line per test, then a summary
## line, then quits. Exit code 0 means every test passed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW PP Max move-picker tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/pp_max_tests.gd")
		quit(1)
		return
	_main()


func _main() -> void:
	await process_frame
	await _run("test_ppmax_engine_arm", Callable(self, "test_ppmax_engine_arm"))
	await _run("test_ppmax_engine_refusals", Callable(self, "test_ppmax_engine_refusals"))
	await _run("test_ppup_engine_regression", Callable(self, "test_ppup_engine_regression"))
	await _run("test_ppmax_full_flow_through_stack", Callable(self, "test_ppmax_full_flow_through_stack"))
	await _run("test_move_picker_refusal_and_cancel", Callable(self, "test_move_picker_refusal_and_cancel"))
	await _run("test_ppmax_oak_dialect_flow", Callable(self, "test_ppmax_oak_dialect_flow"))
	await _run("test_ppmax_refusals_through_flow", Callable(self, "test_ppmax_refusals_through_flow"))
	await _run("test_ppup_through_flow", Callable(self, "test_ppup_through_flow"))
	await _run("test_classification_and_reclassification", Callable(self, "test_classification_and_reclassification"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var result: Variant = await fn.call()
	var ok: bool = bool(result)
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


## A party mon in the battle controller's dialect: moves as
## name strings, PP in mon["pp"] / mon["pp_max"] with the
## PP Up records mon["pp_base"] / mon["pp_ups"] beside them.
## Tackle: base 35, never raised. Growl: base 40, fully raised
## (3 PP Ups, max 64). Thunder Shock: base 30, raised once
## (max 36). Perish Song rides along at base 5 for the small-
## base step floor (step max(1, floor(5 x 0.2)) = 1, ceiling 8).
func _battle_mon() -> Dictionary:
	return {
		"name": "Pikachu", "species": "Pikachu", "species_slug": "pikachu", "species_id": 25,
		"family": "PKDX", "level": 24, "hp": 30, "max_hp": 64,
		"status": "", "confused": false, "item": "", "held_item": "",
		"moves": ["Tackle", "Growl", "Thunder Shock", "Perish Song"],
		"pp": {"Tackle": 20, "Growl": 40, "Thunder Shock": 30, "Perish Song": 5},
		"pp_max": {"Tackle": 35, "Growl": 64, "Thunder Shock": 36, "Perish Song": 5},
		"pp_base": {"Tackle": 35, "Growl": 40, "Thunder Shock": 30, "Perish Song": 5},
		"pp_ups": {"Tackle": 0, "Growl": 3, "Thunder Shock": 1, "Perish Song": 0},
		"exp": 0, "exp_frac": 0.0,
		"evs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}


## A party mon in the Oak-grant dialect: moves as dicts with
## their own pp / max_pp, no PP Up records anywhere (the
## engine derives the base from the current max, its own
## fallback).
func _oak_mon() -> Dictionary:
	return {
		"name": "Pikachu", "species": "Pikachu", "species_slug": "pikachu", "species_id": 25,
		"family": "PKDX", "level": 24, "hp": 30, "max_hp": 64,
		"status": "", "confused": false, "item": "", "held_item": "",
		"moves": [
			{"name": "Tackle", "pp": 20, "max_pp": 35},
			{"name": "Growl", "pp": 40, "max_pp": 40},
		],
		"exp": 0, "exp_frac": 0.0,
		"evs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}


## NOTE (the item-target prep's own warning): build_state
## deep-copies the party, so tests rebind fixtures from
## state["party"] before inspecting them.
func _state(party: Array, bag: Dictionary, badges: Array = []) -> Dictionary:
	return PUWSaveManager.build_state(party, [], bag, 0, badges, [], [], {}, {"name": "Riley"})


## The build-6 host contract WITH the move step, played by
## the test: bag_target_requested pushes the party picker;
## target_chosen pushes the move picker when the item needs
## a move (otherwise resolves at once, the item-target
## contract unchanged); move_chosen resolves with the move,
## pops both pickers, and reports through the bag;
## either picker cancelling pops one level, consuming nothing.
func _make_host(state: Dictionary) -> Dictionary:
	var stack: BW2MenuStack = BW2MenuStack.new()
	root.add_child(stack)
	var bag: PUWBagScreen = PUWBagScreen.new()
	var picker: PUWPartyPickerScreen = PUWPartyPickerScreen.new()
	var moves: PUWMovePickerScreen = PUWMovePickerScreen.new()
	stack.add_child(bag)
	stack.add_child(picker)
	stack.add_child(moves)
	stack.register_panel("bag", bag)
	stack.register_panel("party_picker", picker)
	stack.register_panel("move_picker", moves)
	var pending: Dictionary = {"action": "", "slug": "", "slot": -1}
	var resolved: Array = []
	var refused: Array = []
	var move_refused: Array = []
	bag.bag_target_requested.connect(func(action_id: String, slug: String) -> void:
		pending["action"] = action_id
		pending["slug"] = slug
		stack.push_panel("party_picker")
		picker.present_target(state, action_id, slug)
	)
	picker.target_chosen.connect(func(slot: int) -> void:
		pending["slot"] = slot
		if str(pending["action"]) == "use" and PUWItemTarget.requires_move_choice(str(pending["slug"])):
			stack.push_panel("move_picker")
			moves.present_moves(state, str(pending["slug"]), slot)
			return
		var result: Dictionary = {}
		if str(pending["action"]) == "give":
			result = PUWItemTarget.give_to_mon(state, str(pending["slug"]), slot)
		elif str(pending["action"]) == "take":
			result = PUWItemTarget.take_from_mon(state, slot)
		else:
			result = PUWItemTarget.use_on_mon(state, str(pending["slug"]), slot)
		stack.pop_panel()
		bag.apply_target_result(str(pending["action"]), str(pending["slug"]), result)
		resolved.append(result)
	)
	moves.move_chosen.connect(func(move_name: String) -> void:
		var result: Dictionary = PUWItemTarget.use_on_mon(state, str(pending["slug"]), int(pending["slot"]), {"move": move_name})
		stack.pop_panel()
		stack.pop_panel()
		bag.apply_target_result(str(pending["action"]), str(pending["slug"]), result)
		resolved.append(result)
	)
	moves.move_refused.connect(func(move_name: String, reason: String) -> void:
		move_refused.append({"move": move_name, "reason": reason})
	)
	moves.picker_cancelled.connect(func() -> void:
		stack.pop_panel()
	)
	picker.target_refused.connect(func(slot: int, reason: String) -> void:
		refused.append({"slot": slot, "reason": reason})
	)
	picker.picker_cancelled.connect(func() -> void:
		stack.pop_panel()
	)
	bag.bind_state(state)
	stack.push_panel("bag")
	return {"stack": stack, "bag": bag, "picker": picker, "moves": moves,
		"resolved": resolved, "refused": refused, "move_refused": move_refused,
		"pending": pending}


func _free_host(host: Dictionary) -> void:
	(host["stack"] as Node).queue_free()


# Test 1: the PP Max engine arm — a fresh move goes straight
# to its ceiling (base 35 + 3 steps of 7 = 56), a partly
# raised move tops up to the same kind of ceiling (base 30,
# one PP Up spent, 36 -> 48), current PP never moves, the
# small-base step floor holds (base 5 -> 8), and the log
# carries the engine's own lines.
func test_ppmax_engine_arm() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _battle_mon()
	ok = _expect(ItemEngine.use_battle_item("PP Max", mon, logs, {"move": "Tackle"}), "PP Max must work on a fresh move") and ok
	ok = _expect(int(mon["pp_max"]["Tackle"]) == 56, "Tackle's max PP must be 56 (35 + 3x7), got " + str(mon["pp_max"])) and ok
	ok = _expect(int(mon["pp_ups"]["Tackle"]) == 3, "all 3 PP Up uses must be recorded, got " + str(mon["pp_ups"])) and ok
	ok = _expect(int(mon["pp"]["Tackle"]) == 20, "current PP must not change, got " + str(mon["pp"])) and ok
	ok = _expect(str(logs[0]) == "Pikachu's Tackle max PP rose!", "the first log line must be the engine's rose line, got: " + str(logs)) and ok
	ok = _expect(str(logs[logs.size() - 1]) == "Used PP Max on Pikachu.", "the final log line must be the engine's Used line, got: " + str(logs)) and ok
	logs.clear()
	ok = _expect(ItemEngine.use_battle_item("pp-max", mon, logs, {"move": "Thunder Shock"}), "PP Max (slug form) must top up a partly raised move") and ok
	ok = _expect(int(mon["pp_max"]["Thunder Shock"]) == 48, "Thunder Shock's max PP must be 48 (30 + 3x6), got " + str(mon["pp_max"])) and ok
	ok = _expect(int(mon["pp_ups"]["Thunder Shock"]) == 3, "the top-up must record all 3 uses") and ok
	logs.clear()
	ok = _expect(ItemEngine.use_battle_item("PP Max", mon, logs, {"move": "Perish Song"}), "PP Max must work at base 5") and ok
	ok = _expect(int(mon["pp_max"]["Perish Song"]) == 8, "Perish Song's max PP must be 8 (5 + 3x1), got " + str(mon["pp_max"])) and ok
	return ok


# Test 2: the arm's refusals — no chosen move, a maxed move,
# a move with no PP record, and a max already standing at
# the ceiling despite a use count below 3. Every refusal
# leaves the mon byte-identical.
func test_ppmax_engine_refusals() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _battle_mon()
	var before: String = JSON.stringify(mon)
	ok = _expect(not ItemEngine.use_battle_item("PP Max", mon, logs), "PP Max with no move chosen must refuse") and ok
	ok = _expect(not ItemEngine.use_battle_item("PP Max", mon, logs, {"move": "Growl"}), "PP Max on a maxed move (3 PP Ups) must refuse") and ok
	ok = _expect(not ItemEngine.use_battle_item("PP Max", mon, logs, {"move": "Surf"}), "PP Max on an unrecorded move must refuse") and ok
	ok = _expect(JSON.stringify(mon) == before, "the refusals must leave the mon byte-identical") and ok
	var odd: Dictionary = _battle_mon()
	odd["pp_max"]["Thunder Shock"] = 48
	odd["pp_ups"]["Thunder Shock"] = 0
	var odd_before: String = JSON.stringify(odd)
	ok = _expect(not ItemEngine.use_battle_item("PP Max", odd, logs, {"move": "Thunder Shock"}), "PP Max must refuse when the max already stands at the ceiling") and ok
	ok = _expect(JSON.stringify(odd) == odd_before, "the ceiling refusal must change nothing") and ok
	return ok


# Test 3: PP Up regression — the arm this prep did NOT touch
# keeps its exact outcomes: +7 per use on base 35 (42, 49,
# 56), one recorded use each, the fourth use refused, and
# PP Max after three PP Ups refuses (same ceiling, shared
# accounting).
func test_ppup_engine_regression() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _battle_mon()
	for step in range(3):
		ok = _expect(ItemEngine.use_battle_item("PP Up", mon, logs, {"move": "Tackle"}), "PP Up use " + str(step + 1) + " must work") and ok
		ok = _expect(int(mon["pp_max"]["Tackle"]) == 42 + 7 * step, "Tackle's max PP after PP Up " + str(step + 1) + " must be " + str(42 + 7 * step) + ", got " + str(mon["pp_max"])) and ok
		ok = _expect(int(mon["pp_ups"]["Tackle"]) == step + 1, "the use count must be " + str(step + 1)) and ok
	ok = _expect(int(mon["pp"]["Tackle"]) == 20, "PP Up must never change current PP") and ok
	ok = _expect(not ItemEngine.use_battle_item("PP Up", mon, logs, {"move": "Tackle"}), "a fourth PP Up must refuse") and ok
	ok = _expect(not ItemEngine.use_battle_item("PP Max", mon, logs, {"move": "Tackle"}), "PP Max after three PP Ups must refuse (same ceiling)") and ok
	ok = _expect(not ItemEngine.use_battle_item("PP Up", mon, logs), "PP Up with no move chosen must still refuse") and ok
	return ok


# Test 4: the headline flow, end to end through the real
# stack — bag Use PP Max, the party picker leaves the mon
# enabled (it has a raisable move), the pick opens the MOVE
# picker (nothing resolved yet, nothing consumed), the move
# rows show current/max PP with the maxed move greyed, the
# move pick resolves: max PP at the ceiling, exactly one
# PP Max consumed, the bag back on top carrying the
# engine's message.
func test_ppmax_full_flow_through_stack() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_battle_mon()], {"pp-max": 2})
	var mon: Dictionary = state["party"][0]
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	var moves: PUWMovePickerScreen = host["moves"]
	ok = _expect(bag.select_item("pp-max"), "pp-max must select") and ok
	bag.activate_action("use")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "pp-max must open the party picker") and ok
	ok = _expect(picker.is_slot_enabled(0), "a mon with a raisable move must stay enabled for pp-max") and ok
	picker.choose_slot(0)
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "move_picker", "the party pick must open the move picker, not resolve") and ok
	ok = _expect((host["resolved"] as Array).is_empty(), "nothing may resolve before the move is chosen") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-max") == 2, "nothing may be consumed before the move is chosen") and ok
	ok = _expect(moves.move_label(0).contains("Tackle") and moves.move_label(0).contains("PP 20/35"), "the Tackle row must show PP 20/35, got: " + moves.move_label(0)) and ok
	ok = _expect(moves.move_label(0).contains("56"), "the Tackle row must show the 56 it would reach, got: " + moves.move_label(0)) and ok
	ok = _expect(moves.is_move_enabled(0), "Tackle must be pickable") and ok
	ok = _expect(not moves.is_move_enabled(1), "Growl (maxed) must be greyed") and ok
	ok = _expect(moves.move_short_reason(1) == "Max PP", "Growl's grey-out reason must be Max PP, got: " + moves.move_short_reason(1)) and ok
	moves.choose_move(0)
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "bag", "resolution must land back on the bag") and ok
	var resolved: Array = host["resolved"]
	ok = _expect(resolved.size() == 1 and bool((resolved[0] as Dictionary).get("ok", false)), "the move pick must resolve ok, got " + str(resolved)) and ok
	if resolved.size() == 1:
		ok = _expect(str((resolved[0] as Dictionary).get("move", "")) == "Tackle", "the result must name the chosen move") and ok
	ok = _expect(int(mon["pp_max"]["Tackle"]) == 56, "Tackle's max PP must be 56 after the flow, got " + str(mon["pp_max"])) and ok
	ok = _expect(int(mon["pp_ups"]["Tackle"]) == 3, "the flow must record all 3 PP Up uses") and ok
	ok = _expect(int(mon["pp"]["Tackle"]) == 20, "current PP must stay 20") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-max") == 1, "exactly one pp-max must be consumed") and ok
	ok = _expect(bag.message_text().contains("Pikachu's Tackle max PP rose!"), "the strip must carry the engine's rose line, got: " + bag.message_text()) and ok
	ok = _expect(bag.message_text().contains("Used PP Max on Pikachu."), "the strip must carry the engine's Used line, got: " + bag.message_text()) and ok
	_free_host(host)
	await process_frame
	return ok


# Test 5: the move step's own refusals — picking the maxed
# move refuses on the strip with the engine-style reason and
# stays on the move picker; cancelling out of both pickers
# lands back on the bag with the state byte-identical and
# nothing consumed.
func test_move_picker_refusal_and_cancel() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_battle_mon()], {"pp-max": 1})
	var mon: Dictionary = state["party"][0]
	var before: String = JSON.stringify(mon)
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	var moves: PUWMovePickerScreen = host["moves"]
	ok = _expect(bag.select_item("pp-max"), "pp-max must select") and ok
	bag.activate_action("use")
	picker.choose_slot(0)
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "move_picker", "the move picker must be open") and ok
	moves.choose_move(1)
	var move_refused: Array = host["move_refused"]
	ok = _expect(move_refused.size() == 1 and str((move_refused[0] as Dictionary).get("reason", "")) == "pp_maxed", "picking the maxed move must refuse pp_maxed, got " + str(move_refused)) and ok
	ok = _expect(moves.message_text() == "Its max PP can't go any higher.", "the strip must show the refusal reason, got: " + moves.message_text()) and ok
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "move_picker", "a refused move pick must stay on the move picker") and ok
	moves.cancel()
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "cancelling the move step must return to the party picker") and ok
	picker.choose_slot(0)
	moves.cancel()
	picker.picker_cancelled.emit()
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "bag", "cancelling the party picker must return to the bag") and ok
	ok = _expect(JSON.stringify(mon) == before, "the refusals and cancels must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-max") == 1, "nothing may be consumed") and ok
	ok = _expect((host["resolved"] as Array).is_empty(), "nothing may resolve") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 6: the Oak dialect through the resolver — move rows
# read the per-move dicts, PP Max resolves with the chosen
# move, and the raised max is written back into the move
# dict itself (the dialect's own record), with mon["pp_max"]
# in agreement and exactly one item consumed.
func test_ppmax_oak_dialect_flow() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_oak_mon()], {"pp-max": 2})
	var mon: Dictionary = state["party"][0]
	var rows: Array = PUWItemTarget.move_options(state, "pp-max", 0)
	ok = _expect(rows.size() == 2, "the Oak mon must offer its two moves, got " + str(rows)) and ok
	if rows.size() == 2:
		var tackle_row: Dictionary = rows[0]
		ok = _expect(str(tackle_row.get("move", "")) == "Tackle" and int(tackle_row.get("pp", -1)) == 20 and int(tackle_row.get("pp_max", -1)) == 35, "the Tackle row must read PP 20/35 from the move dict, got " + str(tackle_row)) and ok
		ok = _expect(bool(tackle_row.get("valid", false)) and int(tackle_row.get("new_pp_max", -1)) == 56, "the Tackle row must project 56, got " + str(tackle_row)) and ok
		var growl_row: Dictionary = rows[1]
		ok = _expect(bool(growl_row.get("valid", false)) and int(growl_row.get("new_pp_max", -1)) == 64, "Growl (no PP Ups recorded) must project its own ceiling 64, got " + str(growl_row)) and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "pp-max", 0, {"move": "Tackle"})
	ok = _expect(bool(res.get("ok", false)), "pp-max on the Oak mon must resolve, got " + str(res)) and ok
	var tackle: Dictionary = (mon["moves"] as Array)[0]
	ok = _expect(int(tackle.get("max_pp", -1)) == 56, "the move dict's max_pp must be written back at 56, got " + str(tackle)) and ok
	ok = _expect(int(tackle.get("pp", -1)) == 20, "the move dict's pp must stay 20") and ok
	ok = _expect(int((mon["pp_max"] as Dictionary).get("Tackle", -1)) == 56, "mon[pp_max] must agree at 56") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-max") == 1, "exactly one pp-max must be consumed") and ok
	ok = _expect(str(res.get("message", "")).contains("Used PP Max on Pikachu."), "the message must carry the engine's Used line, got: " + str(res.get("message", ""))) and ok
	return ok


# Test 7: the flow's refusal paths — resolving without a
# move refuses needs_move_choice; a maxed move refuses
# pp_maxed; an empty bag refuses not_held before validity;
# a mon with no PP recorded greys no_pp_data at both levels
# and offers no move rows; a mon whose every move is maxed
# greys pp_maxed at the mon level. Nothing refused is
# consumed or changed.
func test_ppmax_refusals_through_flow() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_battle_mon()], {"pp-max": 1})
	var mon: Dictionary = state["party"][0]
	var before: String = JSON.stringify(mon)
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "pp-max", 0)
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "needs_move_choice", "resolving without a move must refuse needs_move_choice, got " + str(res)) and ok
	res = PUWItemTarget.use_on_mon(state, "pp-max", 0, {"move": "Growl"})
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "pp_maxed", "a maxed move must refuse pp_maxed, got " + str(res)) and ok
	ok = _expect(JSON.stringify(mon) == before, "the refusals must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-max") == 1, "the refusals must not consume") and ok
	var poor_state: Dictionary = _state([_battle_mon()], {})
	res = PUWItemTarget.use_on_mon(poor_state, "pp-max", 0, {"move": "Tackle"})
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "not_held", "an empty bag must refuse not_held, got " + str(res)) and ok
	var blank: Dictionary = _battle_mon()
	blank["moves"] = []
	blank.erase("pp")
	blank.erase("pp_max")
	blank.erase("pp_base")
	blank.erase("pp_ups")
	var blank_state: Dictionary = _state([blank], {"pp-max": 1})
	var v: Dictionary = PUWItemTarget.target_validity(blank_state, "use", "pp-max", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "no_pp_data", "a mon with no PP recorded must grey no_pp_data, got " + str(v)) and ok
	ok = _expect(PUWItemTarget.move_options(blank_state, "pp-max", 0).is_empty(), "a mon with no moves must offer no move rows") and ok
	var maxed: Dictionary = _battle_mon()
	maxed["pp_ups"] = {"Tackle": 3, "Growl": 3, "Thunder Shock": 3, "Perish Song": 3}
	maxed["pp_max"] = {"Tackle": 56, "Growl": 64, "Thunder Shock": 48, "Perish Song": 8}
	var maxed_state: Dictionary = _state([maxed], {"pp-max": 1, "pp-up": 1})
	v = PUWItemTarget.target_validity(maxed_state, "use", "pp-max", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "pp_maxed", "an all-maxed mon must grey pp_maxed for pp-max, got " + str(v)) and ok
	v = PUWItemTarget.target_validity(maxed_state, "use", "pp-up", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "pp_maxed", "an all-maxed mon must grey pp_maxed for pp-up, got " + str(v)) and ok
	return ok


# Test 8: PP Up through the new flow — with a chosen move it
# applies exactly one step (35 -> 42, one use recorded, one
# item consumed); without a move it keeps the old
# needs_move_choice refusal; on a maxed move it refuses
# pp_maxed. The engine arm's outcomes are unchanged (test 3
# pins them at the engine level).
func test_ppup_through_flow() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_battle_mon()], {"pp-up": 2})
	var mon: Dictionary = state["party"][0]
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "pp-up", 0)
	ok = _expect(bool(v.get("valid", false)) and bool(v.get("needs_move", false)), "the mon-level verdict must pass and flag the move step, got " + str(v)) and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "pp-up", 0)
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "needs_move_choice", "pp-up without a move must refuse needs_move_choice, got " + str(res)) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-up") == 2, "the refusal must not consume") and ok
	res = PUWItemTarget.use_on_mon(state, "pp-up", 0, {"move": "Tackle"})
	ok = _expect(bool(res.get("ok", false)), "pp-up with a move must resolve, got " + str(res)) and ok
	ok = _expect(int(mon["pp_max"]["Tackle"]) == 42, "one PP Up step must land (35 -> 42), got " + str(mon["pp_max"])) and ok
	ok = _expect(int(mon["pp_ups"]["Tackle"]) == 1, "exactly one PP Up use must be recorded") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-up") == 1, "exactly one pp-up must be consumed") and ok
	res = PUWItemTarget.use_on_mon(state, "pp-up", 0, {"move": "Growl"})
	ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "pp_maxed", "pp-up on a maxed move must refuse pp_maxed, got " + str(res)) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-up") == 1, "the pp_maxed refusal must not consume") and ok
	return ok


# Test 9: classification — PP Max joins PP Up as a targeted,
# move-choice item; the direct not_usable_result path
# reclassifies both to needs_move_choice (the gaps prep
# assigned that reclassification to this work; PP Max
# previously reported engine_gap by its pp-recovery
# category).
func test_classification_and_reclassification() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_battle_mon()], {})
	ok = _expect(PUWItemTarget.use_mode(state, "pp-max") == "target", "pp-max must be a targeted item now") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "pp-up") == "target", "pp-up must stay a targeted item") and ok
	ok = _expect(PUWItemTarget.requires_move_choice("pp-max"), "pp-max must require a move choice") and ok
	ok = _expect(PUWItemTarget.requires_move_choice("pp-up"), "pp-up must require a move choice") and ok
	ok = _expect(not PUWItemTarget.requires_move_choice("ether"), "ether must not require a move choice (the engine picks)") and ok
	var nu: Dictionary = PUWItemTarget.not_usable_result(state, "pp-max")
	ok = _expect(str(nu.get("reason", "")) == "needs_move_choice", "pp-max's direct refusal must be needs_move_choice now, got " + str(nu)) and ok
	nu = PUWItemTarget.not_usable_result(state, "pp-up")
	ok = _expect(str(nu.get("reason", "")) == "needs_move_choice", "pp-up's direct refusal must be needs_move_choice, got " + str(nu)) and ok
	nu = PUWItemTarget.not_usable_result(state, "exp-candy-xl")
	ok = _expect(str(nu.get("reason", "")) == "engine_gap", "exp-candy-xl must keep refusing engine_gap, got " + str(nu)) and ok
	return ok
