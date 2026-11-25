extends SceneTree
## BINDING BUILD 6 MERGED COPY (A-27/A-28): PP Max test-14 update + EXP candy test-16 update in one file.
## Base: code_prep_pp_max copy: this is the
## item-target prep's suite with the gap closures' two
## expectation updates (from code_prep_item_engine_gaps:
## test 14 and test 16 pinned HP Up to the old engine_gap
## refusal; gap G1 wires the vitamin arm, so HP Up now opens
## the picker and resolves, and test 16's engine_gap pin
## moves to Exp. Candy XL, which stays unsourced) plus ONE
## further update for the move picker: test 14's PP Up pin.
## PP Up no longer greys every target with needs_move_choice
## — the party picker now asks the mon-level question (can
## any move take the item), and this test's fixture knows no
## moves and has no PP recorded, so it greys no_pp_data
## instead. The full move-step behaviour is pinned by
## tests/pp_max_tests.gd. Every other assertion is the
## item-target prep's own, unchanged. The original suite
## lives in code_prep_item_target/tests/.
##
## Headless tests for the item-on-Pokémon flows (code prep
## code_prep_item_target, binding build 6): the party target
## picker (PUWPartyPickerScreen), the resolution paths
## through the bound engines (PUWItemTarget over
## ItemEngine.use_battle_item and DynamicEvolutionEngine),
## give / take / swap for held items, and the bag's message
## surface — closing the gaps code_prep_live_bag named.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/item_target_tests.gd
## It prints one PASS or FAIL line per test, then a summary
## line, then quits. Exit code 0 means every test passed.
##
## The screen tests play host exactly as build 6's hand-over
## contract prescribes: bag_target_requested pushes the
## picker and presents the target; target_chosen resolves
## through PUWItemTarget, pops, and reports back through
## bag.apply_target_result; picker_cancelled just pops.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW item target tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/item_target_tests.gd")
		quit(1)
		return
	_main()


func _main() -> void:
	await process_frame
	await _run("test_heal_full_loop_through_stack", Callable(self, "test_heal_full_loop_through_stack"))
	await _run("test_cancel_consumes_nothing", Callable(self, "test_cancel_consumes_nothing"))
	await _run("test_invalid_targets_refused_in_picker", Callable(self, "test_invalid_targets_refused_in_picker"))
	await _run("test_status_cure_and_wrong_status", Callable(self, "test_status_cure_and_wrong_status"))
	await _run("test_revive_rules", Callable(self, "test_revive_rules"))
	await _run("test_pp_restore_and_no_pp_data", Callable(self, "test_pp_restore_and_no_pp_data"))
	await _run("test_rare_candy_and_level_cap", Callable(self, "test_rare_candy_and_level_cap"))
	await _run("test_evolution_stone_flow", Callable(self, "test_evolution_stone_flow"))
	await _run("test_ev_berry_rules", Callable(self, "test_ev_berry_rules"))
	await _run("test_give_take_swap_round_trip", Callable(self, "test_give_take_swap_round_trip"))
	await _run("test_egg_refused", Callable(self, "test_egg_refused"))
	await _run("test_sacred_ash_party_wide", Callable(self, "test_sacred_ash_party_wide"))
	await _run("test_save_load_preserves_held_item", Callable(self, "test_save_load_preserves_held_item"))
	await _run("test_gap_refusals", Callable(self, "test_gap_refusals"))
	await _run("test_unbound_bag_give_legacy", Callable(self, "test_unbound_bag_give_legacy"))
	await _run("test_use_mode_table", Callable(self, "test_use_mode_table"))
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


## A party mon in the Oak-grant dialect the save state
## actually carries (held item under both keys here so the
## fixture starts in sync; moves/pp shapes vary per test).
func _mon(name: String, slug: String, level: int, hp: int, max_hp: int, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"name": name, "species": name, "species_slug": slug, "species_id": 0,
		"family": "PKDX", "level": level, "hp": hp, "max_hp": max_hp,
		"status": "", "confused": false, "item": "", "held_item": "",
		"moves": [], "exp": 0, "exp_frac": 0.0,
		"evs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for k in extra.keys():
		m[k] = extra[k]
	return m


## NOTE (resume fix, 2026-11-24): build_state deep-copies the
## party by design, so a fixture dict is NOT the dict inside the
## state. Tests rebind their fixtures from state["party"] right
## after _state(...) before inspecting them.
func _state(party: Array, bag: Dictionary, badges: Array = []) -> Dictionary:
	return PUWSaveManager.build_state(party, [], bag, 0, badges, [], [], {}, {"name": "Riley"})


## The build-6 host contract, played by the test: a real
## BW2MenuStack with the bag and the picker registered.
func _make_host(state: Dictionary) -> Dictionary:
	var stack: BW2MenuStack = BW2MenuStack.new()
	root.add_child(stack)
	var bag: PUWBagScreen = PUWBagScreen.new()
	var picker: PUWPartyPickerScreen = PUWPartyPickerScreen.new()
	stack.add_child(bag)
	stack.add_child(picker)
	stack.register_panel("bag", bag)
	stack.register_panel("party_picker", picker)
	var pending: Dictionary = {"action": "", "slug": ""}
	var resolved: Array = []
	var refused: Array = []
	bag.bag_target_requested.connect(func(action_id: String, slug: String) -> void:
		pending["action"] = action_id
		pending["slug"] = slug
		stack.push_panel("party_picker")
		picker.present_target(state, action_id, slug)
	)
	picker.target_chosen.connect(func(slot: int) -> void:
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
	picker.target_refused.connect(func(slot: int, reason: String) -> void:
		refused.append({"slot": slot, "reason": reason})
	)
	picker.picker_cancelled.connect(func() -> void:
		stack.pop_panel()
	)
	bag.bind_state(state)
	stack.push_panel("bag")
	return {"stack": stack, "bag": bag, "picker": picker,
		"resolved": resolved, "refused": refused, "pending": pending}


func _free_host(host: Dictionary) -> void:
	(host["stack"] as Node).queue_free()


# Test 1: the headline loop, end to end through the real
# stack — bound bag, Use a Potion, the picker shows the real
# party, the pick heals through the bound engine, exactly one
# potion is consumed, and the bag's message strip carries the
# engine's own log line plus the measured HP delta. A second
# use at 60/64 clamps to +4 and the message says 4.
func test_heal_full_loop_through_stack() -> bool:
	var ok: bool = true
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 30, 64)
	var state: Dictionary = _state([pikachu], {"potion": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	pikachu = (state["party"] as Array)[0]
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	ok = _expect(bag.select_item("potion"), "the held potion must select") and ok
	bag.activate_action("use")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "Use on a targeted item must open the picker") and ok
	ok = _expect(picker.party.size() == 1, "the picker must show the real party (1 mon)") and ok
	ok = _expect(str((picker.party[0] as Dictionary).get("name", "")) == "Pikachu", "the picker row must be the state's Pikachu") and ok
	ok = _expect(picker.is_slot_enabled(0), "a hurt Pikachu must be a valid potion target") and ok
	picker.choose_slot(0)
	var resolved: Array = host["resolved"]
	ok = _expect(resolved.size() == 1, "the pick must resolve exactly once") and ok
	if resolved.size() == 1:
		var result: Dictionary = resolved[0]
		ok = _expect(bool(result.get("ok", false)), "the heal must succeed") and ok
		ok = _expect(int(result.get("healed", -1)) == 20, "the measured heal must be 20, got " + str(result.get("healed", -1))) and ok
		var message: String = str(result.get("message", ""))
		ok = _expect(message.find("Used Potion on Pikachu.") >= 0, "the message must carry the engine log line, got: " + message) and ok
		ok = _expect(message.find("HP was restored by 20") >= 0, "the message must carry the measured delta, got: " + message) and ok
		ok = _expect(bag.message_text() == message, "the bag message strip must show the resolution message") and ok
	ok = _expect(int(pikachu.get("hp", 0)) == 50, "Pikachu must be at 50 HP, got " + str(pikachu.get("hp", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 1, "exactly one potion must be consumed") and ok
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "bag", "the stack must be back on the bag") and ok
	# Clamp: 60/64 heals by exactly 4.
	pikachu["hp"] = 60
	bag.select_item("potion")
	bag.activate_action("use")
	picker.choose_slot(0)
	ok = _expect(int(pikachu.get("hp", 0)) == 64, "the heal must clamp at max HP") and ok
	if resolved.size() == 2:
		ok = _expect(str((resolved[1] as Dictionary).get("message", "")).find("restored by 4") >= 0, "the clamp message must say 4") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 0, "the second potion must be consumed") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 2: B / Back out of the picker returns to the bag with
# the state byte-identical — nothing consumed, nothing healed.
func test_cancel_consumes_nothing() -> bool:
	var ok: bool = true
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 30, 64)
	var state: Dictionary = _state([pikachu], {"potion": 2})
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	bag.select_item("potion")
	bag.activate_action("use")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "the picker must be open") and ok
	var before: String = JSON.stringify(state)
	picker.close_requested.emit()  # the picker's own Back/B path
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "bag", "cancel must return to the bag") and ok
	ok = _expect(JSON.stringify(state) == before, "a cancelled pick must leave the state byte-identical") and ok
	ok = _expect((host["resolved"] as Array).is_empty(), "a cancelled pick must resolve nothing") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 2, "both potions must remain") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 3: invalid targets are greyed WITH the reason and a
# forced pick is refused unconsumed, state byte-identical;
# the valid row next to it still resolves.
func test_invalid_targets_refused_in_picker() -> bool:
	var ok: bool = true
	var fainted: Dictionary = _mon("Pikachu", "pikachu", 24, 0, 64)
	var hurt: Dictionary = _mon("Bulbasaur", "bulbasaur", 20, 20, 45)
	var state: Dictionary = _state([fainted, hurt], {"potion": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	fainted = (state["party"] as Array)[0]
	hurt = (state["party"] as Array)[1]
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	bag.select_item("potion")
	bag.activate_action("use")
	ok = _expect(not picker.is_slot_enabled(0), "the fainted lead must be greyed out") and ok
	ok = _expect(picker.slot_short_reason(0) == "Fainted", "the grey-out must carry the reason, got: " + picker.slot_short_reason(0)) and ok
	ok = _expect(picker.is_slot_enabled(1), "the hurt Bulbasaur must stay enabled") and ok
	var before: String = JSON.stringify(state)
	picker.choose_slot(0)
	var refused: Array = host["refused"]
	ok = _expect(refused.size() == 1, "the invalid pick must be refused once") and ok
	if refused.size() == 1:
		ok = _expect(str((refused[0] as Dictionary).get("reason", "")) == "fainted", "the refusal reason must be fainted") and ok
	ok = _expect(JSON.stringify(state) == before, "a refused pick must leave the state byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 2, "a refused pick must consume nothing") and ok
	picker.choose_slot(1)
	ok = _expect(int(hurt.get("hp", 0)) == 40, "the valid pick must heal Bulbasaur to 40") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 1, "the valid pick must consume one potion") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 4: status cures through the engine — Antidote cures
# poison; on a paralyzed mon the same Antidote is refused
# wrong_status, unconsumed, state untouched.
func test_status_cure_and_wrong_status() -> bool:
	var ok: bool = true
	var poisoned: Dictionary = _mon("Pikachu", "pikachu", 24, 40, 64, {"status": "PSN"})
	var state: Dictionary = _state([poisoned], {"antidote": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	poisoned = (state["party"] as Array)[0]
	var cured: Dictionary = PUWItemTarget.use_on_mon(state, "antidote", 0)
	ok = _expect(bool(cured.get("ok", false)), "antidote on a poisoned mon must succeed") and ok
	ok = _expect(str(poisoned.get("status", "?")) == "", "the poison must be cured") and ok
	ok = _expect(str(cured.get("message", "")).find("Used Antidote on Pikachu.") >= 0, "the message must carry the engine log line") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "antidote") == 1, "one antidote must be consumed") and ok
	var paralyzed: Dictionary = _mon("Bulbasaur", "bulbasaur", 20, 40, 45, {"status": "PAR"})
	var state2: Dictionary = _state([paralyzed], {"antidote": 1})
	var before: String = JSON.stringify(state2)
	var refused: Dictionary = PUWItemTarget.use_on_mon(state2, "antidote", 0)
	ok = _expect(not bool(refused.get("ok", true)), "antidote on paralysis must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "wrong_status", "the reason must be wrong_status, got " + str(refused.get("reason", ""))) and ok
	ok = _expect(JSON.stringify(state2) == before, "the refused cure must leave the state byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "antidote") == 1, "the refused antidote must not be consumed") and ok
	return ok


# Test 5: revive rules as the engine defines them — a
# fainted mon revives at half HP; a healthy mon refuses.
func test_revive_rules() -> bool:
	var ok: bool = true
	var fainted: Dictionary = _mon("Pikachu", "pikachu", 24, 0, 64)
	var state: Dictionary = _state([fainted], {"revive": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	fainted = (state["party"] as Array)[0]
	var revived: Dictionary = PUWItemTarget.use_on_mon(state, "revive", 0)
	ok = _expect(bool(revived.get("ok", false)), "revive on a fainted mon must succeed") and ok
	ok = _expect(int(fainted.get("hp", 0)) == 32, "revive must restore half of max HP (32), got " + str(fainted.get("hp", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "revive") == 1, "one revive must be consumed") and ok
	var refused: Dictionary = PUWItemTarget.use_on_mon(state, "revive", 0)
	ok = _expect(not bool(refused.get("ok", true)), "revive on a healthy mon must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "not_fainted", "the reason must be not_fainted") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "revive") == 1, "the refused revive must not be consumed") and ok
	return ok


# Test 6: PP restore on an Oak-dialect mon (moves as dicts):
# Ether lands in BOTH the move dict and the battle-shaped
# mon["pp"], consuming one. A string-move mon with no PP
# recorded anywhere refuses no_pp_data, unconsumed.
func test_pp_restore_and_no_pp_data() -> bool:
	var ok: bool = true
	var moves: Array = [
		{"name": "Tackle", "pp": 0, "max_pp": 35},
		{"name": "Growl", "pp": 40, "max_pp": 40},
	]
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64, {"moves": moves})
	var state: Dictionary = _state([pikachu], {"ether": 1})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	pikachu = (state["party"] as Array)[0]
	var used: Dictionary = PUWItemTarget.use_on_mon(state, "ether", 0)
	ok = _expect(bool(used.get("ok", false)), "ether on a mon with a spent move must succeed") and ok
	var tackle: Dictionary = (pikachu["moves"] as Array)[0]
	ok = _expect(int(tackle.get("pp", -1)) == 10, "Tackle must be back to 10 PP in the move dict, got " + str(tackle.get("pp", -1))) and ok
	var pp_map: Dictionary = pikachu.get("pp", {})
	ok = _expect(int(pp_map.get("Tackle", -1)) == 10, "mon[pp] must agree at 10") and ok
	var growl: Dictionary = (pikachu["moves"] as Array)[1]
	ok = _expect(int(growl.get("pp", -1)) == 40, "the full move must stay untouched") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "ether") == 0, "the ether must be consumed") and ok
	var stringy: Dictionary = _mon("Bulbasaur", "bulbasaur", 20, 40, 45, {"moves": ["Tackle"]})
	var state2: Dictionary = _state([stringy], {"ether": 1})
	var refused: Dictionary = PUWItemTarget.use_on_mon(state2, "ether", 0)
	ok = _expect(not bool(refused.get("ok", true)), "ether with no PP recorded must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "no_pp_data", "the reason must be no_pp_data, got " + str(refused.get("reason", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "ether") == 1, "the refused ether must not be consumed") and ok
	return ok


# Test 7: Rare Candy through the engine — a level 5 mon
# under the 0-badge cap of 10 levels up and the candy is
# consumed; a mon AT the cap refuses level_cap, unconsumed.
func test_rare_candy_and_level_cap() -> bool:
	var ok: bool = true
	var young: Dictionary = _mon("Pikachu", "pikachu", 5, 20, 20)
	var state: Dictionary = _state([young], {"rare-candy": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	young = (state["party"] as Array)[0]
	var used: Dictionary = PUWItemTarget.use_on_mon(state, "rare-candy", 0)
	ok = _expect(bool(used.get("ok", false)), "rare candy under the cap must succeed") and ok
	ok = _expect(int(young.get("level", 0)) == 6, "the mon must reach level 6, got " + str(young.get("level", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "rare-candy") == 1, "one candy must be consumed") and ok
	var capped: Dictionary = _mon("Bulbasaur", "bulbasaur", 10, 30, 30)
	var state2: Dictionary = _state([capped], {"rare-candy": 1})
	var refused: Dictionary = PUWItemTarget.use_on_mon(state2, "rare-candy", 0)
	ok = _expect(not bool(refused.get("ok", true)), "rare candy at the badge cap must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "level_cap", "the reason must be level_cap, got " + str(refused.get("reason", ""))) and ok
	ok = _expect(int(capped.get("level", 0)) == 10, "the capped mon must stay level 10") and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "rare-candy") == 1, "the refused candy must not be consumed") and ok
	return ok


# Test 8: evolution stones trigger the BOUND evolution flow
# (DynamicEvolutionEngine), not a parallel one — Eevee plus
# Water Stone becomes Vaporeon and the stone is consumed;
# the same stone on Pikachu refuses with the engine's own
# reason, unconsumed, state byte-identical.
func test_evolution_stone_flow() -> bool:
	var ok: bool = true
	var eevee: Dictionary = _mon("Eevee", "eevee", 18, 45, 45)
	var state: Dictionary = _state([eevee], {"water-stone": 1})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	eevee = (state["party"] as Array)[0]
	var used: Dictionary = PUWItemTarget.use_on_mon(state, "water-stone", 0)
	ok = _expect(bool(used.get("ok", false)), "water stone on Eevee must succeed") and ok
	ok = _expect(str(eevee.get("name", "")) == "Vaporeon", "Eevee must become Vaporeon, got " + str(eevee.get("name", ""))) and ok
	ok = _expect(str(used.get("message", "")) == "Eevee evolved into Vaporeon!", "the message must announce the evolution, got: " + str(used.get("message", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "water-stone") == 0, "the stone must be consumed") and ok
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64)
	var state2: Dictionary = _state([pikachu], {"water-stone": 1})
	var before: String = JSON.stringify(state2)
	var refused: Dictionary = PUWItemTarget.use_on_mon(state2, "water-stone", 0)
	ok = _expect(not bool(refused.get("ok", true)), "water stone on Pikachu must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "no_evolution", "the reason must be no_evolution, got " + str(refused.get("reason", ""))) and ok
	ok = _expect(str(refused.get("message", "")).find("no use-item evolution") >= 0, "the refusal must carry the engine's own reason, got: " + str(refused.get("message", ""))) and ok
	ok = _expect(JSON.stringify(state2) == before, "the refused stone must leave the state byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "water-stone") == 1, "the refused stone must not be consumed") and ok
	return ok


# Test 9: EV berries through the engine — a Pomeg Berry
# lowers HP EVs by 10; at 0 EVs it refuses no_ev.
func test_ev_berry_rules() -> bool:
	var ok: bool = true
	var evs: Dictionary = {"hp": 20, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64, {"evs": evs})
	var state: Dictionary = _state([pikachu], {"pomeg-berry": 2})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	pikachu = (state["party"] as Array)[0]
	var used: Dictionary = PUWItemTarget.use_on_mon(state, "pomeg-berry", 0)
	ok = _expect(bool(used.get("ok", false)), "pomeg berry with HP EVs must succeed") and ok
	ok = _expect(int((pikachu["evs"] as Dictionary).get("hp", -1)) == 10, "HP EVs must drop to 10, got " + str((pikachu["evs"] as Dictionary).get("hp", -1))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pomeg-berry") == 1, "one berry must be consumed") and ok
	var plain: Dictionary = _mon("Bulbasaur", "bulbasaur", 20, 40, 45)
	var state2: Dictionary = _state([plain], {"pomeg-berry": 1})
	var refused: Dictionary = PUWItemTarget.use_on_mon(state2, "pomeg-berry", 0)
	ok = _expect(not bool(refused.get("ok", true)), "pomeg berry at 0 EVs must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "no_ev", "the reason must be no_ev") and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "pomeg-berry") == 1, "the refused berry must not be consumed") and ok
	return ok


# Test 10: give / take / swap round trip through the stack.
# Give writes BOTH held keys; take returns the item to the
# bag and clears both; a second give against a held item
# swaps (the old item lands back in the bag); a Key Item
# refuses in the picker with its reason.
func test_give_take_swap_round_trip() -> bool:
	var ok: bool = true
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64)
	var state: Dictionary = _state([pikachu], {"leftovers": 1, "quick-claw": 1})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	pikachu = (state["party"] as Array)[0]
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	var pending: Dictionary = host["pending"]
	# Give Leftovers.
	ok = _expect(bag.select_item("leftovers"), "leftovers must select") and ok
	bag.activate_action("give")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "Give must open the picker") and ok
	picker.choose_slot(0)
	ok = _expect(str(pikachu.get("item", "")) == "leftovers", "give must write mon[item]") and ok
	ok = _expect(str(pikachu.get("held_item", "")) == "leftovers", "give must write mon[held_item]") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "leftovers") == 0, "the given item must leave the bag") and ok
	ok = _expect(bag.message_text() == "Gave the Leftovers to Pikachu.", "the give message must show, got: " + bag.message_text()) and ok
	# Take it back (host launches the picker in take mode).
	pending["action"] = "take"
	pending["slug"] = ""
	(host["stack"] as BW2MenuStack).push_panel("party_picker")
	picker.present_target(state, "take", "")
	picker.choose_slot(0)
	ok = _expect(str(pikachu.get("item", "?")) == "" and str(pikachu.get("held_item", "?")) == "", "take must clear both held keys") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "leftovers") == 1, "the taken item must return to the bag") and ok
	ok = _expect(bag.message_text() == "Took the Leftovers from Pikachu.", "the take message must show, got: " + bag.message_text()) and ok
	# Give again, then swap for the Quick Claw.
	bag.select_item("leftovers")
	bag.activate_action("give")
	picker.choose_slot(0)
	bag.select_item("quick-claw")
	bag.activate_action("give")
	picker.choose_slot(0)
	ok = _expect(str(pikachu.get("item", "")) == "quick-claw", "the swap must leave the Quick Claw held") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "quick-claw") == 0, "the claw must leave the bag") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "leftovers") == 1, "the swapped-out Leftovers must land back in the bag") and ok
	ok = _expect(bag.message_text().find("Swapped") >= 0, "the swap message must say so, got: " + bag.message_text()) and ok
	# A Key Item refuses in the picker.
	PUWLiveBag.grant_to_state(state, "bicycle", 1)
	bag.refresh_holdings()
	ok = _expect(bag.select_item("bicycle"), "the bicycle must select") and ok
	bag.activate_action("give")
	ok = _expect(not picker.is_slot_enabled(0), "a Key Item give must grey the target") and ok
	ok = _expect(picker.slot_short_reason(0) == "Key item", "the grey-out reason must be Key item") and ok
	picker.choose_slot(0)
	var refused: Array = host["refused"]
	ok = _expect(refused.size() == 1 and str((refused[0] as Dictionary).get("reason", "")) == "key_item", "the key item pick must refuse key_item") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "bicycle") == 1, "the bicycle must stay in the bag") and ok
	ok = _expect(str(pikachu.get("item", "")) == "quick-claw", "the refused give must not disturb the held item") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 11: an Egg is refused for both Use and Give, in the
# picker and at the resolver, with nothing consumed.
func test_egg_refused() -> bool:
	var ok: bool = true
	var egg: Dictionary = _mon("Egg", "togepi", 1, 20, 20, {"is_egg": true})
	var state: Dictionary = _state([egg], {"potion": 1, "leftovers": 1})
	var v_use: Dictionary = PUWItemTarget.target_validity(state, "use", "potion", 0)
	ok = _expect(not bool(v_use.get("valid", true)) and str(v_use.get("reason", "")) == "egg", "picker validity must refuse the egg for use") and ok
	var used: Dictionary = PUWItemTarget.use_on_mon(state, "potion", 0)
	ok = _expect(not bool(used.get("ok", true)) and str(used.get("reason", "")) == "egg", "the resolver must refuse the egg for use") and ok
	var given: Dictionary = PUWItemTarget.give_to_mon(state, "leftovers", 0)
	ok = _expect(not bool(given.get("ok", true)) and str(given.get("reason", "")) == "egg", "the resolver must refuse the egg for give") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 1 and PUWLiveBag.count_in_state(state, "leftovers") == 1, "nothing must be consumed for an egg") and ok
	return ok


# Test 12: Sacred Ash resolves party-wide from the bag's Use
# (no picker): two fainted mons revive at full HP, one is
# consumed, the message counts the revived. With nobody
# fainted it refuses no_fainted on the message strip.
func test_sacred_ash_party_wide() -> bool:
	var ok: bool = true
	var a: Dictionary = _mon("Pikachu", "pikachu", 24, 0, 64)
	var b: Dictionary = _mon("Bulbasaur", "bulbasaur", 20, 0, 45)
	var c: Dictionary = _mon("Eevee", "eevee", 18, 30, 45)
	var state: Dictionary = _state([a, b, c], {"sacred-ash": 1})
	# build_state deep-copies the party: from here on,
	# inspect the state's own mons, not the fixtures.
	a = (state["party"] as Array)[0]
	b = (state["party"] as Array)[1]
	c = (state["party"] as Array)[2]
	var screen: PUWBagScreen = PUWBagScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var resolved: Array = []
	screen.bag_action_resolved.connect(func(action_id: String, slug: String, result: Dictionary) -> void: resolved.append(result))
	screen.bind_state(state)
	ok = _expect(screen.select_item("sacred-ash"), "the sacred ash must select") and ok
	screen.activate_action("use")
	ok = _expect(resolved.size() == 1, "the ash must resolve in place exactly once (no picker)") and ok
	if resolved.size() == 1:
		var result: Dictionary = resolved[0]
		ok = _expect(bool(result.get("ok", false)), "the ash use must succeed") and ok
		ok = _expect(int(result.get("revived", -1)) == 2, "exactly 2 mons must be counted revived, got " + str(result.get("revived", -1))) and ok
		ok = _expect(str(result.get("message", "")).find("2 Pokémon were revived.") >= 0, "the message must count the revived") and ok
	ok = _expect(int(a.get("hp", 0)) == 64 and int(b.get("hp", 0)) == 45, "both fainted mons must revive at full HP") and ok
	ok = _expect(int(c.get("hp", 0)) == 30, "the healthy mon must be untouched") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "sacred-ash") == 0, "the ash must be consumed") and ok
	screen.queue_free()
	await process_frame
	# Nobody fainted: refusal on the strip, unconsumed.
	var healthy: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64)
	var state2: Dictionary = _state([healthy], {"sacred-ash": 1})
	var screen2: PUWBagScreen = PUWBagScreen.new()
	root.add_child(screen2)
	await process_frame
	await process_frame
	screen2.bind_state(state2)
	screen2.select_item("sacred-ash")
	screen2.activate_action("use")
	ok = _expect(screen2.message_text() == "No Pokémon in the party has fainted.", "the refusal must show on the strip, got: " + screen2.message_text()) and ok
	ok = _expect(PUWLiveBag.count_in_state(state2, "sacred-ash") == 1, "the refused ash must not be consumed") and ok
	screen2.queue_free()
	await process_frame
	return ok


# Test 13: the held item a give placed survives a real
# PUWSaveManager save / load round trip, under both keys,
# with the bag counts intact.
func test_save_load_preserves_held_item() -> bool:
	var ok: bool = true
	PUWSaveManager.delete_save()
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 50, 64)
	var state: Dictionary = _state([pikachu], {"leftovers": 1, "potion": 3})
	var given: Dictionary = PUWItemTarget.give_to_mon(state, "leftovers", 0)
	ok = _expect(bool(given.get("ok", false)), "the give must succeed before saving") and ok
	ok = _expect(PUWSaveManager.save_game(state), "save_game must write the state") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	ok = _expect(not loaded.is_empty(), "the saved game must load back") and ok
	var loaded_party: Array = loaded.get("party", [])
	ok = _expect(loaded_party.size() == 1, "the loaded party must hold the one mon") and ok
	if loaded_party.size() == 1:
		var mon: Dictionary = loaded_party[0]
		ok = _expect(str(mon.get("item", "")) == "leftovers", "the loaded mon must hold leftovers under item") and ok
		ok = _expect(str(mon.get("held_item", "")) == "leftovers", "the loaded mon must hold leftovers under held_item") and ok
	ok = _expect(PUWLiveBag.count_in_state(loaded, "leftovers") == 0, "the loaded bag must not resurrect the given item") and ok
	ok = _expect(PUWLiveBag.count_in_state(loaded, "potion") == 3, "the loaded bag must keep its potions") and ok
	PUWSaveManager.delete_save()
	ok = _expect(not PUWSaveManager.has_save(), "the test save must be cleaned up") and ok
	return ok


# Test 14: the named engine gaps refuse honestly — X Attack
# is battle-only through the bag and PP Up greys this target
# (the fixture has no PP recorded; with the move picker the
# party-level verdict is the mon's own PP state, no longer a
# blanket needs_move_choice); nothing refused is consumed.
# UPDATED for code_prep_item_engine_gaps: HP Up is wired now
# (gap G1) — it opens the picker and resolves through the
# vitamin arm.
func test_gap_refusals() -> bool:
	var ok: bool = true
	var pikachu: Dictionary = _mon("Pikachu", "pikachu", 24, 30, 64)
	var state: Dictionary = _state([pikachu], {"x-attack": 1, "pp-up": 1, "hp-up": 1})
	pikachu = (state["party"] as Array)[0]
	var host: Dictionary = _make_host(state)
	await process_frame
	await process_frame
	var bag: PUWBagScreen = host["bag"]
	var picker: PUWPartyPickerScreen = host["picker"]
	ok = _expect(bag.select_item("x-attack"), "x-attack must select") and ok
	bag.activate_action("use")
	ok = _expect(bag.message_text() == "That item can only be used in battle.", "x-attack must refuse battle_only on the strip, got: " + bag.message_text()) and ok
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "bag", "a battle-only item must not open the picker") and ok
	ok = _expect(bag.select_item("hp-up"), "hp-up must select") and ok
	bag.activate_action("use")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "hp-up is a targeted item and must open the picker") and ok
	ok = _expect(picker.is_slot_enabled(0), "hp-up must leave the fresh target enabled") and ok
	picker.choose_slot(0)
	ok = _expect(int(pikachu["evs"]["hp"]) == 10, "hp-up must raise HP EV by 10 through the flow, got " + str(pikachu["evs"])) and ok
	ok = _expect(bag.message_text().contains("Used HP Up on Pikachu."), "the strip must carry the engine's Used line, got: " + bag.message_text()) and ok
	ok = _expect(bag.select_item("pp-up"), "pp-up must select") and ok
	bag.activate_action("use")
	ok = _expect((host["stack"] as BW2MenuStack).current_panel_id() == "party_picker", "pp-up is a targeted item and must open the picker") and ok
	# UPDATED for code_prep_pp_max: the move picker exists
	# now, so the party picker's verdict is the mon-level
	# one — this fixture knows no moves and has no PP
	# recorded, so it greys no_pp_data. (A mon with a
	# raisable move proceeds to the move step; that flow is
	# pinned by tests/pp_max_tests.gd.)
	ok = _expect(not picker.is_slot_enabled(0), "pp-up must grey a target with no PP recorded") and ok
	ok = _expect(picker.slot_short_reason(0) == "No PP record", "the grey-out reason must be No PP record, got: " + picker.slot_short_reason(0)) and ok
	picker.choose_slot(0)
	var refused: Array = host["refused"]
	ok = _expect(refused.size() == 1 and str((refused[0] as Dictionary).get("reason", "")) == "no_pp_data", "the pp-up pick must refuse no_pp_data, got " + str(refused)) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "x-attack") == 1, "x-attack must not be consumed") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "hp-up") == 0, "hp-up must be consumed exactly once by its successful use") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "pp-up") == 1, "pp-up must not be consumed") and ok
	_free_host(host)
	await process_frame
	return ok


# Test 15: legacy behaviour is byte-preserved — an UNBOUND
# bag's Give still routes to the host through action_chosen
# and never asks for a picker.
func test_unbound_bag_give_legacy() -> bool:
	var ok: bool = true
	var screen: PUWBagScreen = PUWBagScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var chosen: Array = []
	var targeted: Array = []
	screen.action_chosen.connect(func(action_id: String, slug: String) -> void: chosen.append([action_id, slug]))
	screen.bag_target_requested.connect(func(action_id: String, slug: String) -> void: targeted.append([action_id, slug]))
	screen.holdings = [{"slug": "potion", "qty": 1, "pocket": 1}]
	screen.refresh_holdings()
	ok = _expect(screen.select_item("potion"), "the staged holding must select") and ok
	screen.activate_action("give")
	ok = _expect(chosen.size() == 1, "unbound Give must emit action_chosen exactly once") and ok
	if chosen.size() == 1:
		ok = _expect(str((chosen[0] as Array)[0]) == "give" and str((chosen[0] as Array)[1]) == "potion", "action_chosen must carry (give, potion)") and ok
	ok = _expect(targeted.is_empty(), "an unbound bag must never request a target") and ok
	screen.queue_free()
	await process_frame
	return ok


# Test 16: the mode table the bag routes by — field items
# stay with PUWLiveBag, targeted classes and stones ask for
# the picker, Sacred Ash is party-wide, and everything else
# is none (with battle_only named for the X items).
func test_use_mode_table() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_mon("Pikachu", "pikachu", 24, 30, 64)], {})
	ok = _expect(PUWItemTarget.use_mode(state, "repel") == "field", "repel must be field") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "escape-rope") == "field", "escape rope must be field") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "potion") == "target", "potion must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "antidote") == "target", "antidote must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "ether") == "target", "ether must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "rare-candy") == "target", "rare candy must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "water-stone") == "target", "a stone must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "linking-cord") == "target", "the linking cord must be target") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "sacred-ash") == "party", "sacred ash must be party") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "poke-ball") == "none", "a ball must be none") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "x-attack") == "none", "x-attack must be none") and ok
	var x: Dictionary = PUWItemTarget.not_usable_result(state, "x-attack")
	ok = _expect(str(x.get("reason", "")) == "battle_only", "x-attack's refusal must be battle_only") and ok
	# UPDATED for code_prep_item_engine_gaps: hp-up is a
	# targeted item now (gap G1); the engine_gap pin moved to
	# Exp. Candy XL. UPDATED AGAIN for code_prep_exp_candy:
	# the EXP Candies are implemented (the hunt desk sourced
	# their amounts), so exp-candy-xl is a targeted item too,
	# and the pin moves to Dynamax Candy, which stays
	# refused by Bossy ruling (no Dynamax Level field until
	# the Galar build).
	ok = _expect(PUWItemTarget.use_mode(state, "hp-up") == "target", "hp-up must be target after the G1 closure") and ok
	ok = _expect(PUWItemTarget.use_mode(state, "exp-candy-xl") == "target", "exp-candy-xl must be target after the EXP Candy closure") and ok
	var vit: Dictionary = PUWItemTarget.not_usable_result(state, "dynamax-candy")
	ok = _expect(str(vit.get("reason", "")) == "engine_gap", "dynamax-candy's refusal must be engine_gap, got " + str(vit.get("reason", ""))) and ok
	var ball: Dictionary = PUWItemTarget.not_usable_result(state, "poke-ball")
	ok = _expect(str(ball.get("reason", "")) == "not_field_usable", "a ball's refusal must be not_field_usable") and ok
	return ok
