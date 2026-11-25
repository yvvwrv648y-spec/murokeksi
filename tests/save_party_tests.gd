extends SceneTree
## Headless test runner for the PUW save manager and party/storage manager.
##
## Run it in Godot 4.7 (headless, no game window needed) with:
##   godot --headless --script res://tests/save_party_tests.gd
##
## It prints one PASS or FAIL line per test, then a summary line, then
## quits. Exit code 0 means every test passed, 1 means at least one failed.
##
## What the tests need in the project:
## - save_manager.gd at res://core/save_manager.gd
##   (class PUWSaveManager)
## - party_and_storage_manager.gd at
##   res://systems/party/party_and_storage_manager.gd
##   (class PartyAndStorageManager)
## The save tests write to the normal user:// save paths and clean up
## after themselves with PUWSaveManager.delete_save().

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW save + party/storage tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/save_party_tests.gd")
		quit(1)
		return
	_run("test_save_round_trip", Callable(self, "test_save_round_trip"))
	_run("test_corruption_fallback", Callable(self, "test_corruption_fallback"))
	_run("test_party_and_storage", Callable(self, "test_party_and_storage"))
	_run("test_house_rules_still_work", Callable(self, "test_house_rules_still_work"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = bool(test.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


## One test Pokemon, as a plain dict like the engine uses.
func _mon(mon_name: String, species: String, level: int) -> Dictionary:
	return {
		"name": mon_name,
		"species": species,
		"level": level,
		"hp": 40,
		"max_hp": 40,
		"moves": ["Tackle", "Growl"],
		"held_item": "",
		"shiny": false,
		"nature": {"name": "Hardy", "up": "", "down": ""},
		"evo_family": species + "_line"
	}


## A small save state used by the save tests.
func _sample_state() -> Dictionary:
	var party: Array = [_mon("Ember", "Emberfox", 12), _mon("Splash", "Aquaff", 10)]
	var boxed_mon: Dictionary = _mon("Stored", "Terrapup", 5)
	var boxes: Array = [[boxed_mon]]
	var bag: Dictionary = {"potion": 3}
	var badges: Array = ["boulder", "cascade"]
	var dex_seen: Array = ["Emberfox", "Aquaff", "Terrapup"]
	var dex_caught: Array = ["Emberfox", "Aquaff"]
	var story_flags: Dictionary = {"got_starter": true}
	var player: Dictionary = {"name": "Riley", "location_id": "kanto_pallet_town"}
	return PUWSaveManager.build_state(party, boxes, bag, 12345, badges, dex_seen, dex_caught, story_flags, player)


## Test 1: save a full state, load it back, and prove it matches field
## by field. Then delete the save and prove it is really gone.
## Note on numbers: JSON turns whole numbers into floats when parsing,
## so the field-by-field check compares the loaded dict against the
## saved dict after the saved dict has been through the same JSON
## round trip. Money and other spot checks use int() for the same reason.
func test_save_round_trip() -> bool:
	PUWSaveManager.delete_save()
	if PUWSaveManager.has_save():
		return false
	var state: Dictionary = _sample_state()
	if int(state.get("schema_version", 0)) != PUWSaveManager.SCHEMA_VERSION:
		return false
	if not PUWSaveManager.save_game(state):
		return false
	if not PUWSaveManager.has_save():
		return false
	var loaded: Dictionary = PUWSaveManager.load_game()
	if loaded.is_empty():
		return false
	var expected_text: String = JSON.stringify(state)
	var expected_parsed: Variant = JSON.parse_string(expected_text)
	if typeof(expected_parsed) != TYPE_DICTIONARY:
		return false
	var expected: Dictionary = expected_parsed
	if JSON.stringify(expected) != JSON.stringify(loaded):
		return false
	if int(loaded.get("money", 0)) != 12345:
		return false
	var badges: Array = loaded.get("badges", [])
	if JSON.stringify(badges) != JSON.stringify(["boulder", "cascade"]):
		return false
	var flags: Dictionary = loaded.get("story_flags", {})
	if bool(flags.get("got_starter", false)) != true:
		return false
	var bag: Dictionary = loaded.get("bag", {})
	if int(bag.get("potion", 0)) != 3:
		return false
	var party: Array = loaded.get("party", [])
	if party.size() != 2:
		return false
	var first_mon: Dictionary = party[0]
	if str(first_mon.get("name", "")) != "Ember":
		return false
	var nature: Dictionary = first_mon.get("nature", {})
	if str(nature.get("name", "")) != "Hardy":
		return false
	PUWSaveManager.delete_save()
	if PUWSaveManager.has_save():
		return false
	var after_delete: Dictionary = PUWSaveManager.load_game()
	return after_delete.is_empty()


## Test 2: a damaged main save file falls back to the backup file.
## How the backup gets there: write_atomic() copies the PREVIOUS main
## file into the backup path before writing the new main file. So the
## sequence is: save once (main file only, no backup yet), save the same
## state again (backup now holds the first good save, main file holds
## the second good save), then overwrite the main file with garbage.
## load_game() must then return the good state from the backup.
func test_corruption_fallback() -> bool:
	PUWSaveManager.delete_save()
	var state: Dictionary = _sample_state()
	if not PUWSaveManager.save_game(state):
		return false
	var state_again: Dictionary = _sample_state()
	if not PUWSaveManager.save_game(state_again):
		return false
	if not FileAccess.file_exists(PUWSaveManager.BACKUP_PATH):
		return false
	var f: FileAccess = FileAccess.open(PUWSaveManager.PRIMARY_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("this is not json {{{ garbage")
	f.close()
	var loaded: Dictionary = PUWSaveManager.load_game()
	if loaded.is_empty():
		return false
	if int(loaded.get("money", 0)) != 12345:
		return false
	var badges: Array = loaded.get("badges", [])
	if JSON.stringify(badges) != JSON.stringify(["boulder", "cascade"]):
		return false
	var party: Array = loaded.get("party", [])
	if party.size() != 2:
		return false
	PUWSaveManager.delete_save()
	return not PUWSaveManager.has_save()


## Test 3: party fills first, overflow goes to the legacy pc_storage
## list, and the box moves (deposit, withdraw, move, release) all keep
## the counts right. Withdrawing into a full party fails, and the last
## party mon can not be deposited or released.
func test_party_and_storage() -> bool:
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	var names: Array = ["One", "Two", "Three", "Four", "Five", "Six", "Seven"]
	for i in names.size():
		var mon_name: String = names[i]
		var where: String = mgr.add_pokemon(_mon(mon_name, "Emberfox", 5 + i))
		if i < 6 and where != "party":
			mgr.free()
			return false
		if i == 6 and where != "pc_storage":
			mgr.free()
			return false
	if mgr.party.size() != 6 or mgr.pc_storage.size() != 1:
		mgr.free()
		return false
	if mgr.total_stored() != 1:
		mgr.free()
		return false
	if mgr.pc_boxes.size() != PartyAndStorageManager.BOX_COUNT:
		mgr.free()
		return false
	# Deposit party slot 0 into the first box with space (box 0).
	var dep: Dictionary = mgr.deposit(0)
	if not bool(dep.get("ok", false)) or int(dep.get("box", -1)) != 0 or int(dep.get("slot", -1)) != 0:
		mgr.free()
		return false
	if mgr.party.size() != 5 or mgr.box_count_used(0) != 1 or mgr.total_stored() != 2:
		mgr.free()
		return false
	# Withdraw it straight back into the party.
	var wd: Dictionary = mgr.withdraw(0, 0)
	if not bool(wd.get("ok", false)):
		mgr.free()
		return false
	var wd_mon: Dictionary = wd.get("mon", {})
	if str(wd_mon.get("name", "")) != "One":
		mgr.free()
		return false
	if mgr.party.size() != 6 or mgr.box_count_used(0) != 0 or mgr.total_stored() != 1:
		mgr.free()
		return false
	# Deposit again, then move the mon from box 0 to box 1.
	var dep2: Dictionary = mgr.deposit(0, 0)
	if not bool(dep2.get("ok", false)):
		mgr.free()
		return false
	var mv: Dictionary = mgr.move_in_storage(0, 0, 1)
	if not bool(mv.get("ok", false)) or int(mv.get("box", -1)) != 1 or int(mv.get("slot", -1)) != 0:
		mgr.free()
		return false
	if mgr.box_count_used(0) != 0 or mgr.box_count_used(1) != 1 or mgr.total_stored() != 2:
		mgr.free()
		return false
	# Release the boxed mon and get it back in the result.
	var rel: Dictionary = mgr.release_from_box(1, 0)
	if not bool(rel.get("ok", false)):
		mgr.free()
		return false
	var rel_mon: Dictionary = rel.get("mon", {})
	# Slot 0 held "Two" at this point: "One" was withdrawn to the end of
	# the party earlier, so the second deposit moved "Two", not "One".
	if str(rel_mon.get("name", "")) != "Two":
		mgr.free()
		return false
	if mgr.box_count_used(1) != 0 or mgr.total_stored() != 1:
		mgr.free()
		return false
	# Box a mon, refill the party, and prove withdraw now fails.
	var dep3: Dictionary = mgr.deposit(0, 2)
	if not bool(dep3.get("ok", false)):
		mgr.free()
		return false
	# Party is at 4 after that deposit, so two more mons refill it to 6.
	var fill_where: String = mgr.add_pokemon(_mon("Eight", "Emberfox", 9))
	if fill_where != "party":
		mgr.free()
		return false
	var fill_where_2: String = mgr.add_pokemon(_mon("Nine", "Emberfox", 10))
	if fill_where_2 != "party" or mgr.party.size() != 6:
		mgr.free()
		return false
	var wd_fail: Dictionary = mgr.withdraw(2, 0)
	if bool(wd_fail.get("ok", true)) or str(wd_fail.get("reason", "")) != "party_full":
		mgr.free()
		return false
	if mgr.party.size() != 6 or mgr.box_count_used(2) != 1:
		mgr.free()
		return false
	mgr.free()
	# A fresh manager with a single mon: the last party mon can not be
	# deposited and can not be released (keep-at-least-1 game rule).
	var solo: PartyAndStorageManager = PartyAndStorageManager.new()
	var solo_where: String = solo.add_pokemon(_mon("Solo", "Emberfox", 3))
	if solo_where != "party" or solo.party.size() != 1:
		solo.free()
		return false
	var dep_fail: Dictionary = solo.deposit(0)
	if bool(dep_fail.get("ok", true)) or str(dep_fail.get("reason", "")) != "party_must_keep_one":
		solo.free()
		return false
	var rel_fail: Dictionary = solo.release_from_party(0)
	if bool(rel_fail.get("ok", true)) or str(rel_fail.get("reason", "")) != "party_must_keep_one":
		solo.free()
		return false
	if solo.party.size() != 1:
		solo.free()
		return false
	solo.free()
	return true


## Test 4: the stub's house rules still work. A faint in a simulation is
## not permanent and locks nothing. A real faint is permanent, removes
## the mon, writes the ledger, and locks its evolution family so
## is_capture_legal flips to false for that family.
func test_house_rules_still_work() -> bool:
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	var where: String = mgr.add_pokemon(_mon("Hero", "Emberfox", 20))
	if where != "party":
		mgr.free()
		return false
	if not mgr.is_capture_legal("Emberfox_line"):
		mgr.free()
		return false
	var sim: Dictionary = mgr.handle_faint(0, true, "vexa_sim")
	if bool(sim.get("permanent", true)):
		mgr.free()
		return false
	if mgr.party.size() != 1 or mgr.fainting_ledger.size() != 0:
		mgr.free()
		return false
	if not mgr.is_capture_legal("Emberfox_line"):
		mgr.free()
		return false
	var real: Dictionary = mgr.handle_faint(0, false, "standard")
	if not bool(real.get("permanent", false)):
		mgr.free()
		return false
	if str(real.get("evo_family_locked", "")) != "Emberfox_line":
		mgr.free()
		return false
	if mgr.party.size() != 0 or mgr.fainting_ledger.size() != 1:
		mgr.free()
		return false
	if mgr.is_capture_legal("Emberfox_line"):
		mgr.free()
		return false
	if not mgr.is_capture_legal("Aquaff_line"):
		mgr.free()
		return false
	mgr.free()
	return true
