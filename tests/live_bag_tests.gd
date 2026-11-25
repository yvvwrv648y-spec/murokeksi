extends SceneTree
## Headless tests for the live bag wiring (code prep
## code_prep_live_bag, binding build 6): PUWLiveBag feeding
## the bound BW2 bag / X-menu screens from a real
## PUWSaveManager save state, and the overworld item-use
## path for the repel / escape classes build 4 named.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/live_bag_tests.gd
## It prints one PASS or FAIL line per test, then a summary
## line, then quits. Exit code 0 means every test passed.
##
## What is checked:
## - holdings_for_screen turns a state bag into screen rows:
##   spellings merged through the item registry, pockets from
##   the item data, zero counts skipped, nothing held hidden.
## - The task's headline flow: grant an item into the state,
##   the bound bag screen's data shows it, Use consumes it.
## - Repel use: consumes one, the habitat counter starts at
##   the item's own step count and the steps persist into
##   the state; without a habitat the state key is written
##   directly in the same shape.
## - Escape Rope: with a recorded entrance it consumes and
##   returns the target (and spends the entrance); without
##   one it refuses and consumes nothing.
## - Poké Doll refuses in the overworld (battle-only, its
##   path is the battle controller's) and is not consumed;
##   an unheld item and a non-field item refuse untouched.
## - Toss consumes, except Key Items, which refuse.
## - A real save round trip through PUWSaveManager keeps the
##   bag and the persisted repel steps.
## - The X-menu header binds name / badges / money from the
##   same state, and PUWLiveBag's pocket list stays equal to
##   PUWBagScreen.POCKETS.
## The save test uses the normal user:// save paths and
## cleans up with PUWSaveManager.delete_save(), like
## tests/menu_character_tests.gd.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW live bag wiring tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/live_bag_tests.gd")
		quit(1)
		return
	_main()


## The screen tests await frames, so the suite runs as a
## coroutine kicked off from _init; quit() fires at its end.
func _main() -> void:
	await process_frame
	await _run("test_holdings_from_state", Callable(self, "test_holdings_from_state"))
	await _run("test_screen_shows_granted_item", Callable(self, "test_screen_shows_granted_item"))
	await _run("test_repel_use_consumes_and_persists", Callable(self, "test_repel_use_consumes_and_persists"))
	await _run("test_repel_without_habitat_writes_state", Callable(self, "test_repel_without_habitat_writes_state"))
	await _run("test_escape_rope_use_and_refusal", Callable(self, "test_escape_rope_use_and_refusal"))
	await _run("test_battle_only_and_unusable_refuse", Callable(self, "test_battle_only_and_unusable_refuse"))
	await _run("test_toss_rules", Callable(self, "test_toss_rules"))
	await _run("test_save_round_trip", Callable(self, "test_save_round_trip"))
	await _run("test_xmenu_binds_state", Callable(self, "test_xmenu_binds_state"))
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


## A save state in the real shape, built by the save manager
## itself, with the given bag.
func _state_with_bag(bag: Dictionary) -> Dictionary:
	return PUWSaveManager.build_state([], [], bag, 0, [], [], [], {}, {"name": "Riley"})


## One screen row for a slug, or {} when absent.
func _row_for(rows: Array, slug: String) -> Dictionary:
	for row_value in rows:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			if str(row.get("slug", "")) == slug:
				return row
	return {}


# Test 1: holdings_for_screen. The two spellings of the Poké
# Ball merge into one stack; pockets come from the item
# data (medicine / balls / berries / key); a zero count is
# skipped; an item no data source knows still lists.
func test_holdings_from_state() -> bool:
	var ok: bool = true
	var bag: Dictionary = {
		"poke-ball": 2, "poke_ball": 3,
		"potion": 4, "repel": 1, "escape-rope": 2,
		"cheri-berry": 6, "omni_ring": 1, "bicycle": 1,
		"full-restore": 0, "made-up-item": 7,
	}
	var rows: Array = PUWLiveBag.holdings_for_screen(_state_with_bag(bag))
	ok = _expect(rows.size() == 8, "8 held stacks must list (zero count skipped), got " + str(rows.size())) and ok
	var ball: Dictionary = _row_for(rows, "poke-ball")
	ok = _expect(int(ball.get("qty", 0)) == 5, "poke-ball spellings must merge to 5, got " + str(ball.get("qty", -1))) and ok
	ok = _expect(int(ball.get("pocket", -1)) == PUWLiveBag.POCKET_BALLS, "poke-ball must sit in the balls pocket") and ok
	ok = _expect(int(_row_for(rows, "potion").get("pocket", -1)) == PUWLiveBag.POCKET_MEDICINE, "potion must sit in medicine") and ok
	ok = _expect(int(_row_for(rows, "cheri-berry").get("pocket", -1)) == PUWLiveBag.POCKET_BERRIES, "cheri-berry must sit in berries") and ok
	ok = _expect(int(_row_for(rows, "omni_ring").get("pocket", -1)) == PUWLiveBag.POCKET_KEY, "omni_ring must sit in key items (registry category)") and ok
	ok = _expect(int(_row_for(rows, "bicycle").get("pocket", -1)) == PUWLiveBag.POCKET_KEY, "bicycle must sit in key items") and ok
	ok = _expect(int(_row_for(rows, "repel").get("pocket", -1)) == PUWLiveBag.POCKET_ITEMS, "repel must sit in items, matching the build-3 demo grouping") and ok
	ok = _expect(int(_row_for(rows, "made-up-item").get("qty", 0)) == 7, "an unknown held item must still list with its count") and ok
	ok = _expect(_row_for(rows, "full-restore").is_empty(), "a zero-count stack must not list") and ok
	ok = _expect(JSON.stringify(PUWLiveBag.POCKET_NAMES) == JSON.stringify(PUWBagScreen.POCKETS), "PUWLiveBag pocket names must equal PUWBagScreen.POCKETS") and ok
	return ok


# Test 2 (the headline flow): grant an item into the state,
# the bound bag screen's data shows it; the screen was built
# and bound inside the tree like the host will do.
func test_screen_shows_granted_item() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_with_bag({"potion": 1})
	var screen: PUWBagScreen = PUWBagScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.bind_state(state)
	ok = _expect(screen.holdings.size() == 1, "bound screen must show the one held stack, got " + str(screen.holdings.size())) and ok
	var granted: int = PUWLiveBag.grant_to_state(state, "super-repel", 2)
	ok = _expect(granted == 2, "grant must report the new total 2, got " + str(granted)) and ok
	screen.refresh_holdings()
	var row: Dictionary = _row_for(screen.holdings, "super-repel")
	ok = _expect(int(row.get("qty", 0)) == 2, "after grant + refresh the screen must show super-repel x2") and ok
	ok = _expect(screen.select_item("super-repel"), "select_item must find the granted item") and ok
	# Granting under the other spelling grows the same stack.
	PUWLiveBag.grant_to_state(state, "super_repel", 1)
	screen.refresh_holdings()
	row = _row_for(screen.holdings, "super-repel")
	ok = _expect(int(row.get("qty", 0)) == 3, "the other spelling must grow the same stack to 3, got " + str(row.get("qty", -1))) and ok
	screen.queue_free()
	await process_frame
	return ok


# Test 3: repel use through the SCREEN's action path (the
# exact flow the task names): select the repel, Use, one is
# consumed, the habitat counter runs at the item's own 100
# steps and the steps are persisted into the state.
func test_repel_use_consumes_and_persists() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_with_bag({"repel": 2})
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	var screen: PUWBagScreen = PUWBagScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	var resolved: Array = []
	screen.bag_action_resolved.connect(func(action_id: String, slug: String, result: Dictionary) -> void: resolved.append(result))
	screen.bind_state(state, {"habitat": habitat})
	ok = _expect(screen.select_item("repel"), "the held repel must select") and ok
	screen.activate_action("use")
	ok = _expect(resolved.size() == 1, "the use must resolve exactly once") and ok
	if resolved.size() == 1:
		var result: Dictionary = resolved[0]
		ok = _expect(bool(result.get("ok", false)), "repel use must succeed") and ok
		ok = _expect(str(result.get("effect", "")) == "repel", "the effect must be repel") and ok
		ok = _expect(int(result.get("steps", 0)) == 100, "repel must run 100 steps (ItemEngine's own count)") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "repel") == 1, "one repel must be consumed, 1 left") and ok
	ok = _expect(habitat.repel_steps_remaining() == 100, "the habitat counter must hold the 100 steps") and ok
	var saved_value: Variant = state.get("habitat_repel", {})
	var saved_steps: int = -1
	if saved_value is Dictionary:
		var saved: Dictionary = saved_value
		saved_steps = int(saved.get("steps", -1))
	ok = _expect(saved_steps == 100, "the steps must persist into state[habitat_repel], got " + str(saved_steps)) and ok
	ok = _expect(int(_row_for(screen.holdings, "repel").get("qty", 0)) == 1, "the screen must refresh to x1 after the use") and ok
	screen.queue_free()
	await process_frame
	return ok


# Test 4: repel with NO live habitat in context still works:
# the steps land in the state key in the habitat system's
# own shape, and a fresh habitat restores them from it.
func test_repel_without_habitat_writes_state() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_with_bag({"max-repel": 1})
	var result: Dictionary = PUWLiveBag.use_in_overworld(state, "max-repel")
	ok = _expect(bool(result.get("ok", false)), "max repel use must succeed without a habitat") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "max-repel") == 0, "the max repel must be consumed") and ok
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	habitat.restore_repel_from_save(state)
	ok = _expect(habitat.repel_steps_remaining() == 250, "a fresh habitat must restore the persisted 250 steps, got " + str(habitat.repel_steps_remaining())) and ok
	return ok


# Test 5: escape rope. With an entrance recorded on the map
# loader, use consumes the rope, returns that target and
# spends the entrance. With none recorded, use refuses
# "no_target" and the rope stays in the bag.
func test_escape_rope_use_and_refusal() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	var state: Dictionary = _state_with_bag({"escape-rope": 1})
	var refused: Dictionary = PUWLiveBag.use_in_overworld(state, "escape-rope", {"map_loader": loader})
	ok = _expect(not bool(refused.get("ok", true)), "rope use with no entrance must refuse") and ok
	ok = _expect(str(refused.get("reason", "")) == "no_target", "the refusal reason must be no_target, got " + str(refused.get("reason", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "escape-rope") == 1, "a refused rope must not be consumed") and ok
	loader.record_entrance("kanto_mt_moon", 3)
	var used: Dictionary = PUWLiveBag.use_in_overworld(state, "escape_rope", {"map_loader": loader})
	ok = _expect(bool(used.get("ok", false)), "rope use with an entrance must succeed (either spelling)") and ok
	var target_value: Variant = used.get("target", {})
	var target: Dictionary = {}
	if target_value is Dictionary:
		target = target_value
	ok = _expect(str(target.get("map", "")) == "kanto_mt_moon", "the target must be the recorded entrance map") and ok
	ok = _expect(int(target.get("warp_id", 0)) == 3, "the target must be the recorded entrance warp") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "escape-rope") == 0, "the rope must be consumed") and ok
	ok = _expect(loader.escape_rope_target().is_empty(), "the entrance must be spent after the use") and ok
	return ok


# Test 6: refusals that must never consume. The Poké Doll is
# battle-only (guarantees_escape is the battle controller's
# path, wired in build 4); a healing item is not field-
# usable through this path; an unheld repel reports
# not_held.
func test_battle_only_and_unusable_refuse() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_with_bag({"poke-doll": 1, "potion": 2})
	var doll: Dictionary = PUWLiveBag.use_in_overworld(state, "poke-doll")
	ok = _expect(not bool(doll.get("ok", true)), "poké doll must refuse in the overworld") and ok
	ok = _expect(str(doll.get("reason", "")) == "battle_only", "poké doll reason must be battle_only, got " + str(doll.get("reason", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "poke-doll") == 1, "the doll must not be consumed") and ok
	var potion: Dictionary = PUWLiveBag.use_in_overworld(state, "potion")
	ok = _expect(not bool(potion.get("ok", true)), "potion must refuse through the field path (it needs a target)") and ok
	ok = _expect(str(potion.get("reason", "")) == "not_field_usable", "potion reason must be not_field_usable") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 2, "the potions must not be consumed") and ok
	var missing: Dictionary = PUWLiveBag.use_in_overworld(state, "repel")
	ok = _expect(str(missing.get("reason", "")) == "not_held", "an unheld repel must report not_held") and ok
	return ok


# Test 7: toss consumes an ordinary item and refuses a key
# item, leaving the key item held.
func test_toss_rules() -> bool:
	var ok: bool = true
	var state: Dictionary = _state_with_bag({"potion": 2, "omni_ring": 1})
	var tossed: Dictionary = PUWLiveBag.toss_from_state(state, "potion")
	ok = _expect(bool(tossed.get("ok", false)), "tossing a potion must succeed") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 1, "one potion must remain") and ok
	var key_toss: Dictionary = PUWLiveBag.toss_from_state(state, "omni_ring")
	ok = _expect(not bool(key_toss.get("ok", true)), "tossing the Omni Ring must refuse") and ok
	ok = _expect(str(key_toss.get("reason", "")) == "key_item", "the refusal reason must be key_item") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "omni_ring") == 1, "the Omni Ring must stay held") and ok
	return ok


# Test 8: a real save round trip. The state (bag + persisted
# repel steps) goes through PUWSaveManager.save_game /
# load_game and the loaded state feeds the same holdings.
func test_save_round_trip() -> bool:
	var ok: bool = true
	PUWSaveManager.delete_save()
	var state: Dictionary = _state_with_bag({"repel": 3, "poke-ball": 5, "omni_ring": 1})
	PUWLiveBag.use_in_overworld(state, "repel")
	ok = _expect(PUWSaveManager.save_game(state), "save_game must write the state") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	ok = _expect(not loaded.is_empty(), "the saved game must load back") and ok
	ok = _expect(PUWLiveBag.count_in_state(loaded, "repel") == 2, "the loaded bag must hold the 2 remaining repels") and ok
	ok = _expect(PUWLiveBag.count_in_state(loaded, "poke-ball") == 5, "the loaded bag must hold the 5 balls") and ok
	var before: Array = PUWLiveBag.holdings_for_screen(state)
	var after: Array = PUWLiveBag.holdings_for_screen(loaded)
	ok = _expect(JSON.stringify(before) == JSON.stringify(after), "holdings must be identical across the save round trip") and ok
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	habitat.restore_repel_from_save(loaded)
	ok = _expect(habitat.repel_steps_remaining() == 100, "the loaded state must restore the repel steps") and ok
	PUWSaveManager.delete_save()
	ok = _expect(not PUWSaveManager.has_save(), "the test save must be cleaned up") and ok
	return ok


# Test 9: the X-menu header binds the same state: player
# name, badge count from the badges list, money; and the
# staged demo time disappears instead of posing as real.
func test_xmenu_binds_state() -> bool:
	var ok: bool = true
	var state: Dictionary = PUWSaveManager.build_state([], [], {}, 777, ["kanto_gym_1_brock", "kanto_gym_2_misty"], [], [], {}, {"name": "Tasha"})
	var menu: PUWXMenuScreen = PUWXMenuScreen.new()
	root.add_child(menu)
	await process_frame
	await process_frame
	menu.bind_state(state)
	ok = _expect(str(menu.trainer.get("name", "")) == "Tasha", "the header name must come from the state, got " + str(menu.trainer.get("name", ""))) and ok
	ok = _expect(int(menu.trainer.get("badges", -1)) == 2, "the badge count must be the badges list size") and ok
	ok = _expect(int(menu.trainer.get("money", -1)) == 777, "the money must come from the state") and ok
	ok = _expect(not menu.trainer.has("time"), "a bound header must not carry the staged demo time") and ok
	ok = _expect(menu._state_text().find("Tasha") >= 0, "the header text must show the bound name") and ok
	ok = _expect(menu._state_text().find("12:47") < 0, "the header text must not show the demo time") and ok
	menu.queue_free()
	await process_frame
	return ok
