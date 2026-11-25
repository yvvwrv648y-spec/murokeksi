extends SceneTree
## Headless tests for the PUW character setup flow, the
## protagonist canon data, the pokedex (PKDX + MDX), and the
## opening / in-game menu structure.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/menu_character_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.
##
## What is checked:
## - The opening menu labels equal the PUW_UI_UX_SPEC list
##   exactly, in order, and so do the in-game menu labels.
## - Every menu entry with no system yet resolves to status
##   "not_yet_built" with its exact label and message, and every
##   system-backed entry resolves to status "system".
## - Character setup: an identity outside the canon list is
##   refused; walking all 11 steps with values completes;
##   build_character() returns the chosen identity; saving
##   through a real PUWSaveManager state and loading it back
##   returns the same character dict; a setup with identity
##   unset refuses to finish.
## - Canon data: protagonist_canon.json loads, and the
##   riley/tasha/custom house values are
##   "top-left"/"top-right"/"bottom-right"; the identity
##   options match the canon list verbatim and the ball rig
##   counts match the doc (3 left hip, 3 right hip, 1 signature).
## - Pokedex: with a fresh save-manager-shaped state a species
##   is "unseen"; after mark_seen it is "seen"; after
##   mark_caught it is "caught". MDX entries list exactly the
##   one pikachu seed and the register carries the mapping note.
## The save test uses the normal user:// save paths and cleans
## up with PUWSaveManager.delete_save(), like
## tests/save_party_tests.gd.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW menu + character + pokedex tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/menu_character_tests.gd")
		quit(1)
		return
	_run("test_opening_menu_labels", Callable(self, "test_opening_menu_labels"))
	_run("test_game_menu_labels", Callable(self, "test_game_menu_labels"))
	_run("test_menu_target_resolution", Callable(self, "test_menu_target_resolution"))
	_run("test_character_setup_flow_and_save", Callable(self, "test_character_setup_flow_and_save"))
	_run("test_protagonist_canon_data", Callable(self, "test_protagonist_canon_data"))
	_run("test_pokedex_pkdx_and_mdx", Callable(self, "test_pokedex_pkdx_and_mdx"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
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


## Load and parse a project JSON file. Empty dict on failure.
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	return data


## Find one dict in a list by a String field. Empty dict if absent.
func _find_by(list: Array, key: String, wanted: String) -> Dictionary:
	for item_value in list:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			if str(item.get(key, "")) == wanted:
				return item
	return {}


## Find one pokedex entry by species id. Empty dict if absent.
func _entry_by_id(list: Array, wanted_id: int) -> Dictionary:
	for item_value in list:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			if int(item.get("id", 0)) == wanted_id:
				return item
	return {}


# Test 1: opening menu labels equal the spec list exactly, in order.
func test_opening_menu_labels() -> bool:
	var expected: Array = ["New Game", "Continue", "Load Game", "Character Setup", "Settings", "Accessibility", "Credits"]
	return _expect(JSON.stringify(MainScene.OPENING_MENU) == JSON.stringify(expected), "opening menu must equal the spec list in order, got " + JSON.stringify(MainScene.OPENING_MENU))


# Test 2: in-game menu labels equal the spec list exactly, in order.
func test_game_menu_labels() -> bool:
	var expected: Array = ["Pokedex", "Party", "Bag", "Trainer Profile", "Map", "Quest Log", "Character Wardrobe", "Pokemon Info", "Settings", "Save", "Help"]
	return _expect(JSON.stringify(MainScene.GAME_MENU) == JSON.stringify(expected), "in-game menu must equal the spec list in order, got " + JSON.stringify(MainScene.GAME_MENU))


# Test 3: every not-yet-built entry resolves to status
# "not_yet_built" with its exact label and message, and every
# system-backed entry resolves to status "system" with a target.
func test_menu_target_resolution() -> bool:
	var ok: bool = true
	var not_yet: Dictionary = {
		"settings": "Settings",
		"accessibility": "Accessibility",
		"credits": "Credits",
		"trainer_profile": "Trainer Profile",
		"map": "Map",
		"quest_log": "Quest Log",
		"character_wardrobe": "Character Wardrobe",
		"help": "Help"
	}
	for id_value in not_yet.keys():
		var entry_id: String = str(id_value)
		var label: String = str(not_yet[entry_id])
		var resolved: Dictionary = MainScene.menu_target(entry_id)
		ok = _expect(str(resolved.get("status", "")) == "not_yet_built", entry_id + " must resolve to not_yet_built, got " + str(resolved.get("status", ""))) and ok
		ok = _expect(str(resolved.get("label", "")) == label, entry_id + " label must be " + label + ", got " + str(resolved.get("label", ""))) and ok
		ok = _expect(str(resolved.get("message", "")) == label + " is not built yet.", entry_id + " message must name the label, got " + str(resolved.get("message", ""))) and ok
	var system_ids: Array = ["new_game", "continue", "load_game", "character_setup", "pokedex", "party", "bag", "pokemon_info", "save"]
	for id_value in system_ids:
		var entry_id: String = str(id_value)
		var resolved: Dictionary = MainScene.menu_target(entry_id)
		ok = _expect(str(resolved.get("status", "")) == "system", entry_id + " must resolve to system, got " + str(resolved.get("status", ""))) and ok
		ok = _expect(str(resolved.get("target", "")) == entry_id, entry_id + " target must be its own id, got " + str(resolved.get("target", ""))) and ok
	return ok


# Test 4: character setup end to end. An off-list identity is
# refused; walking all 11 steps with values completes and
# navigation refuses to advance past confirm; build_character
# returns the chosen identity; saving through a real
# PUWSaveManager state and loading with the save manager
# returns the same character dict. A second setup with identity
# unset refuses to finish, build, or save.
func test_character_setup_flow_and_save() -> bool:
	var ok: bool = true
	var setup: PUWCharacterSetup = PUWCharacterSetup.new()
	var expected_steps: Array = ["identity", "pronouns", "body_silhouette", "face", "eyes", "heterochromia", "hair_style", "hair_color", "clothing", "signature_ball", "confirm"]
	ok = _expect(JSON.stringify(setup.get_steps()) == JSON.stringify(expected_steps), "setup must have exactly the 11 steps in order, got " + JSON.stringify(setup.get_steps())) and ok
	ok = _expect(setup.current_step() == "identity", "setup must start on identity, got " + setup.current_step()) and ok
	ok = _expect(not setup.set_value("identity", "Wizard"), "an identity outside the canon list must be refused") and ok
	ok = _expect(not setup.set_value("not_a_step", "x"), "an unknown step id must be refused") and ok
	var values: Dictionary = {
		"identity": "Nonbinary",
		"pronouns": "they/them",
		"body_silhouette": "slim",
		"face": "soft",
		"eyes": "green",
		"hair_style": "tousled bob",
		"hair_color": "blonde",
		"clothing": "charcoal cropped tee, white frayed shorts, orange boots",
		"signature_ball": "signature ball",
		"confirm": "confirmed"
	}
	var steps: Array = setup.get_steps()
	for i in steps.size():
		var step_id: String = str(steps[i])
		if step_id == "heterochromia":
			ok = _expect(setup.set_value(step_id, true), "heterochromia must accept a bool") and ok
		else:
			ok = _expect(setup.set_value(step_id, str(values[step_id])), "set_value must accept " + step_id) and ok
		if i < steps.size() - 1:
			ok = _expect(setup.next_step(), "next_step must advance from " + step_id) and ok
	ok = _expect(setup.current_step() == "confirm", "walking all steps must end on confirm, got " + setup.current_step()) and ok
	ok = _expect(not setup.next_step(), "next_step must refuse to advance past confirm") and ok
	ok = _expect(setup.previous_step(), "previous_step must go back from confirm") and ok
	ok = _expect(setup.next_step(), "next_step must return to confirm") and ok
	ok = _expect(setup.is_complete(), "setup with all steps filled must be complete") and ok
	ok = _expect(setup.finish(), "finish must succeed when complete") and ok
	var built: Dictionary = setup.build_character()
	ok = _expect(str(built.get("identity", "")) == "Nonbinary", "build_character must return the chosen identity, got " + str(built.get("identity", ""))) and ok
	ok = _expect(bool(built.get("heterochromia", false)), "build_character must keep the heterochromia bool") and ok
	# Save through a real save-manager state, then load fresh.
	PUWSaveManager.delete_save()
	var state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	ok = _expect(setup.save_character(state), "save_character must succeed through the save manager") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	ok = _expect(not loaded.is_empty(), "the saved game must load back") and ok
	var flags_value: Variant = loaded.get("story_flags", {})
	var saved_character: Dictionary = {}
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		var char_value: Variant = flags.get(PUWCharacterSetup.SAVE_FLAG_KEY, {})
		if char_value is Dictionary:
			var char_dict: Dictionary = char_value
			saved_character = char_dict
	ok = _expect(not saved_character.is_empty(), "the loaded state must hold the character under story_flags") and ok
	ok = _expect(str(saved_character.get("identity", "")) == "Nonbinary", "the loaded character must keep the chosen identity, got " + str(saved_character.get("identity", ""))) and ok
	var expected_text: String = JSON.stringify(built)
	var expected_parsed: Variant = JSON.parse_string(expected_text)
	if typeof(expected_parsed) == TYPE_DICTIONARY:
		var expected_dict: Dictionary = expected_parsed
		ok = _expect(JSON.stringify(expected_dict) == JSON.stringify(saved_character), "the loaded character must equal the built character after the JSON round trip") and ok
	else:
		ok = _expect(false, "the built character must survive a JSON round trip") and ok
	PUWSaveManager.delete_save()
	ok = _expect(not PUWSaveManager.has_save(), "the test save must be cleaned up") and ok
	setup.free()
	# Identity unset: finishing, building, and saving all refuse.
	var bare: PUWCharacterSetup = PUWCharacterSetup.new()
	ok = _expect(bare.set_value("pronouns", "she/her"), "pronouns must accept a free-form string") and ok
	ok = _expect(not bare.is_complete(), "a setup with identity unset must not be complete") and ok
	ok = _expect(not bare.finish(), "finish must refuse with identity unset") and ok
	ok = _expect(bare.build_character().is_empty(), "build_character must return nothing with identity unset") and ok
	var bare_state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	ok = _expect(not bare.save_character(bare_state), "save_character must refuse with identity unset") and ok
	bare.free()
	return ok


# Test 5: canon data. protagonist_canon.json loads; the three
# houses are top-left / top-right / bottom-right; the custom
# identity options match the canon list verbatim; both named
# protagonists carry the doc's ball rig (3 left hip, 3 right
# hip, 1 signature); the top-level note flags the sprite sheets
# as ASSET_CANDIDATE pending the M1 camera gate.
func test_protagonist_canon_data() -> bool:
	var ok: bool = true
	var data: Dictionary = _load_json("res://characters/protagonist_canon.json")
	ok = _expect(not data.is_empty(), "protagonist_canon.json must load") and ok
	if data.is_empty():
		return false
	ok = _expect(str(data.get("note", "")).find("ASSET_CANDIDATE") >= 0, "the canon note must flag ASSET_CANDIDATE sprite sheets") and ok
	ok = _expect(str(data.get("note", "")).find("M1") >= 0, "the canon note must name the M1 camera gate") and ok
	var list_value: Variant = data.get("protagonists", [])
	if not (list_value is Array):
		return _expect(false, "canon data must hold a protagonists list")
	var protagonists: Array = list_value
	var riley: Dictionary = _find_by(protagonists, "id", "riley")
	var tasha: Dictionary = _find_by(protagonists, "id", "tasha")
	var custom: Dictionary = _find_by(protagonists, "id", "custom")
	ok = _expect(str(riley.get("house", "")) == "top-left", "riley house must be top-left, got " + str(riley.get("house", ""))) and ok
	ok = _expect(str(tasha.get("house", "")) == "top-right", "tasha house must be top-right, got " + str(tasha.get("house", ""))) and ok
	ok = _expect(str(custom.get("house", "")) == "bottom-right", "custom house must be bottom-right, got " + str(custom.get("house", ""))) and ok
	ok = _expect(str(riley.get("hair", "")) == "blonde tousled bob", "riley hair must match the doc") and ok
	ok = _expect(str(riley.get("eyes", "")) == "green", "riley eyes must match the doc") and ok
	ok = _expect(str(tasha.get("hair", "")) == "long copper-orange wavy hair", "tasha hair must match the doc") and ok
	ok = _expect(str(tasha.get("eyes", "")) == "blue", "tasha eyes must match the doc") and ok
	for hero in [riley, tasha]:
		var hero_dict: Dictionary = hero
		var rig_value: Variant = hero_dict.get("ball_rig", {})
		if rig_value is Dictionary:
			var rig: Dictionary = rig_value
			ok = _expect(int(rig.get("left_hip", 0)) == 3, "ball rig left_hip must be 3") and ok
			ok = _expect(int(rig.get("right_hip", 0)) == 3, "ball rig right_hip must be 3") and ok
			ok = _expect(int(rig.get("signature", 0)) == 1, "ball rig signature must be 1") and ok
			ok = _expect(str(rig.get("description", "")) == "6 individual custom Poké Balls (3 left hip, 3 right hip, 1 signature)", "ball rig description must carry the doc sentence verbatim") and ok
		else:
			ok = _expect(false, "each named protagonist must carry a ball_rig object") and ok
	var options_value: Variant = custom.get("identity_options", [])
	var expected_options: Array = ["Male", "Female", "Nonbinary", "Trans man", "Trans woman", "Femboy", "Futanari", "Custom", "Prefer not to specify"]
	ok = _expect(JSON.stringify(options_value) == JSON.stringify(expected_options), "custom identity options must match the canon list verbatim, got " + JSON.stringify(options_value)) and ok
	return ok


# Test 6: pokedex. A fresh save-manager-shaped state reports
# pikachu "unseen"; mark_seen makes it "seen"; mark_caught
# makes it "caught"; the state arrays hold the slug in the save
# manager's own shape. MDX entries list exactly the one pikachu
# seed, and the register carries the mapping note.
func test_pokedex_pkdx_and_mdx() -> bool:
	var ok: bool = true
	var dex: PUWPokedex = PUWPokedex.new()
	ok = _expect(dex.species_count() == 1025, "PKDX must list the full 1,025 species, got " + str(dex.species_count())) and ok
	var state: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	var entries: Array = dex.pokedex_entries(state)
	ok = _expect(entries.size() == 1025, "pokedex_entries must return 1,025 entries, got " + str(entries.size())) and ok
	var pikachu: Dictionary = _entry_by_id(entries, 25)
	ok = _expect(str(pikachu.get("slug", "")) == "pikachu", "entry 25 must be pikachu, got " + str(pikachu.get("slug", ""))) and ok
	ok = _expect(str(pikachu.get("status", "")) == "unseen", "a fresh state must report pikachu unseen, got " + str(pikachu.get("status", ""))) and ok
	ok = _expect(dex.mark_seen(state, "pikachu"), "mark_seen must accept pikachu") and ok
	var seen_list_value: Variant = state.get("dex_seen", [])
	ok = _expect(seen_list_value is Array and (seen_list_value as Array).has("pikachu"), "dex_seen must hold the pikachu slug in the save manager shape") and ok
	var after_seen: Dictionary = _entry_by_id(dex.pokedex_entries(state), 25)
	ok = _expect(str(after_seen.get("status", "")) == "seen", "after mark_seen pikachu must be seen, got " + str(after_seen.get("status", ""))) and ok
	ok = _expect(dex.mark_caught(state, 25), "mark_caught must accept species id 25") and ok
	var caught_list_value: Variant = state.get("dex_caught", [])
	ok = _expect(caught_list_value is Array and (caught_list_value as Array).has("pikachu"), "dex_caught must hold the pikachu slug in the save manager shape") and ok
	var after_caught: Dictionary = _entry_by_id(dex.pokedex_entries(state), 25)
	ok = _expect(str(after_caught.get("status", "")) == "caught", "after mark_caught pikachu must be caught, got " + str(after_caught.get("status", ""))) and ok
	ok = _expect(not dex.mark_seen(state, "not_a_species"), "mark_seen must refuse an unknown species") and ok
	# MDX: exactly the one sourced pikachu seed, kept separate.
	var mdx_entries: Array = dex.pokedex_entries_mdx()
	ok = _expect(mdx_entries.size() == 1, "MDX must list exactly one entry, got " + str(mdx_entries.size())) and ok
	if mdx_entries.size() == 1:
		var seed_value: Variant = mdx_entries[0]
		if seed_value is Dictionary:
			var seed: Dictionary = seed_value
			ok = _expect(int(seed.get("species_id", 0)) == 25, "the MDX seed species_id must be 25") and ok
			ok = _expect(str(seed.get("slug", "")) == "pikachu", "the MDX seed must be pikachu") and ok
			ok = _expect(str(seed.get("family", "")) == "MDX", "the MDX seed family must be MDX") and ok
			ok = _expect(str(seed.get("locomotion", "")) == "ground_biped_moemon", "the MDX seed locomotion must be ground_biped_moemon") and ok
			ok = _expect(str(seed.get("status", "")) == "ASSET_CANDIDATE", "the MDX seed status must be ASSET_CANDIDATE") and ok
			var habitat_value: Variant = seed.get("habitat", [])
			ok = _expect(habitat_value is Array and (habitat_value as Array).has("kanto_route_01"), "the MDX seed habitat must include kanto_route_01") and ok
		else:
			ok = _expect(false, "the MDX seed must be a dictionary") and ok
	ok = _expect(dex.mdx_mapping_note().find("otherwise empty") >= 0, "the MDX mapping note must state the mapping is otherwise empty") and ok
	var register: Dictionary = _load_json("res://systems/pokedex/mdx_register.json")
	ok = _expect(str(register.get("mapping_note", "")).find("no further sourced mapping exists") >= 0, "mdx_register.json must carry the mapping note at top level") and ok
	return ok
