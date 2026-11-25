extends SceneTree
## Headless tests for the code-prep fixes from the canon audit
## (hidden_files/canon_audit_20261123/NEON_RULEBOOK_AUDIT.md):
##
##   G1 — per-mon UUIDs in PartyAndStorageManager + PUWSaveManager
##   G5 — the X / Rotom Menu VEXA shortcut in PUWLiveWiring
##   G7 — hairstyle exclusivity in PUWCharacterSetup.set_value()
##
## Run it in Godot 4.7 (headless, no game window needed) with:
##   godot --headless --script res://tests/code_prep_uuid_tests.gd
##
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed. The save tests write to the normal user://
## save paths and clean up with PUWSaveManager.delete_save(),
## like tests/save_party_tests.gd.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW code-prep tests (G1 UUIDs, G5 VEXA shortcut, G7 hairstyle lock) — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/code_prep_uuid_tests.gd")
		quit(1)
		return
	_run("test_uuid_uniqueness_1000", Callable(self, "test_uuid_uniqueness_1000"))
	_run("test_uuid_stable_across_moves", Callable(self, "test_uuid_stable_across_moves"))
	_run("test_uuid_save_round_trip_stability", Callable(self, "test_uuid_save_round_trip_stability"))
	_run("test_permadeath_id_never_reused", Callable(self, "test_permadeath_id_never_reused"))
	_run("test_old_save_backfill_once", Callable(self, "test_old_save_backfill_once"))
	_run("test_duplicate_and_retired_ids_replaced", Callable(self, "test_duplicate_and_retired_ids_replaced"))
	_run("test_vexa_shortcut_opens_state", Callable(self, "test_vexa_shortcut_opens_state"))
	_run("test_hairstyle_lock", Callable(self, "test_hairstyle_lock"))
	_run("test_signature_profiles_unaffected", Callable(self, "test_signature_profiles_unaffected"))
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


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


## One test Pokemon, as a plain dict like the engine uses (same
## shape as tests/save_party_tests.gd).
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


func _id_of(mon: Dictionary) -> String:
	return str(mon.get(PartyAndStorageManager.MON_ID_KEY, ""))


## The ids of a list of mon dicts, in order.
func _ids_of(mons: Array) -> Array:
	var ids: Array = []
	for mon_value in mons:
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			ids.append(_id_of(mon))
	return ids


# ----------------------------------------------------------------
# G1 — per-mon UUIDs
# ----------------------------------------------------------------

## 1,000 content-identical mons (same species, name, level — the
## hardest case for identity) each get a distinct, non-empty id
## through the real entry point, and a stored mon can be found
## again by its id alone.
func test_uuid_uniqueness_1000() -> bool:
	var ok: bool = true
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	for i in 1000:
		mgr.add_pokemon(_mon("Twin", "Emberfox", 5))
	ok = _expect(mgr.party.size() == 6, "party must hold 6, got " + str(mgr.party.size())) and ok
	ok = _expect(mgr.pc_storage.size() == 994, "pc_storage must hold 994, got " + str(mgr.pc_storage.size())) and ok
	var seen: Dictionary = {}
	var all: Array = []
	all.append_array(mgr.party)
	all.append_array(mgr.pc_storage)
	for mon_value in all:
		var mon: Dictionary = mon_value
		var mon_id: String = _id_of(mon)
		ok = _expect(mon_id != "", "every mon must carry an id") and ok
		ok = _expect(not seen.has(mon_id), "ids must be unique, duplicate: " + mon_id) and ok
		seen[mon_id] = true
		if not ok:
			break
	ok = _expect(seen.size() == 1000, "exactly 1,000 distinct ids, got " + str(seen.size())) and ok
	var stored_mon: Dictionary = mgr.pc_storage[500]
	var stored_id: String = _id_of(stored_mon)
	var found: Dictionary = mgr.find_mon_by_id(stored_id)
	ok = _expect(str(found.get("where", "")) == "pc_storage", "find_mon_by_id must locate the stored mon") and ok
	ok = _expect(int(found.get("index", -1)) == 500, "find_mon_by_id must return its index") and ok
	ok = _expect(mgr.find_mon_by_id("puw-999999-ffffff").is_empty(), "an unknown id must find nothing") and ok
	mgr.free()
	return ok


## A mon's id does not change when it moves: party -> box ->
## party, and box -> box.
func test_uuid_stable_across_moves() -> bool:
	var ok: bool = true
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	mgr.add_pokemon(_mon("Anchor", "Emberfox", 9))
	mgr.add_pokemon(_mon("Mover", "Aquaff", 9))
	var mover: Dictionary = mgr.party[1]
	var mover_id: String = _id_of(mover)
	ok = _expect(mover_id != "", "the mover must start with an id") and ok
	var dep: Dictionary = mgr.deposit(1, 3)
	ok = _expect(bool(dep.get("ok", false)), "deposit must succeed") and ok
	var boxed: Dictionary = mgr.pc_boxes[3][0]
	ok = _expect(_id_of(boxed) == mover_id, "id must survive deposit") and ok
	var found: Dictionary = mgr.find_mon_by_id(mover_id)
	ok = _expect(str(found.get("where", "")) == "box" and int(found.get("box", -1)) == 3, "find_mon_by_id must locate the boxed mon") and ok
	var mv: Dictionary = mgr.move_in_storage(3, 0, 7)
	ok = _expect(bool(mv.get("ok", false)), "box-to-box move must succeed") and ok
	var moved: Dictionary = mgr.pc_boxes[7][0]
	ok = _expect(_id_of(moved) == mover_id, "id must survive a box-to-box move") and ok
	var wd: Dictionary = mgr.withdraw(7, 0)
	ok = _expect(bool(wd.get("ok", false)), "withdraw must succeed") and ok
	var back: Dictionary = wd.get("mon", {})
	ok = _expect(_id_of(back) == mover_id, "id must survive withdraw") and ok
	mgr.free()
	return ok


## Ids persist through a real save/load round trip: build the
## state the way the game does (with the manager's mon_id_state),
## save it, load it, adopt the collections into a fresh manager,
## and every mon's id — party and boxed — is exactly what it was.
func test_uuid_save_round_trip_stability() -> bool:
	var ok: bool = true
	PUWSaveManager.delete_save()
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	mgr.add_pokemon(_mon("Ember", "Emberfox", 12))
	mgr.add_pokemon(_mon("Splash", "Aquaff", 10))
	mgr.add_pokemon(_mon("Stored", "Terrapup", 5))
	var dep: Dictionary = mgr.deposit(2, 0)
	ok = _expect(bool(dep.get("ok", false)), "deposit before save must succeed") and ok
	var party_ids_before: Array = _ids_of(mgr.party)
	var box_ids_before: Array = _ids_of(mgr.pc_boxes[0])
	var state: Dictionary = PUWSaveManager.build_state(mgr.party, mgr.pc_boxes, {}, 777, [], [], [], {}, {}, mgr.mon_id_state())
	ok = _expect(PUWSaveManager.save_game(state), "save_game must succeed") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	ok = _expect(not loaded.is_empty(), "the save must load back") and ok
	var loaded_book_value: Variant = loaded.get("mon_id_state", {})
	ok = _expect(loaded_book_value is Dictionary and not (loaded_book_value as Dictionary).is_empty(), "the loaded state must carry mon_id_state") and ok
	var mgr2: PartyAndStorageManager = PartyAndStorageManager.new()
	var loaded_party: Array = loaded.get("party", [])
	var loaded_boxes: Array = loaded.get("boxes", [])
	var loaded_book: Dictionary = {}
	if loaded_book_value is Dictionary:
		var book_dict: Dictionary = loaded_book_value
		loaded_book = book_dict
	mgr2.adopt_collections(loaded_party, loaded_boxes, [], loaded_book)
	ok = _expect(JSON.stringify(_ids_of(mgr2.party)) == JSON.stringify(party_ids_before), "party ids must be identical after the round trip") and ok
	ok = _expect(JSON.stringify(_ids_of(mgr2.pc_boxes[0])) == JSON.stringify(box_ids_before), "boxed ids must be identical after the round trip") and ok
	mgr.free()
	mgr2.free()
	PUWSaveManager.delete_save()
	ok = _expect(not PUWSaveManager.has_save(), "the test save must be cleaned up") and ok
	return ok


## Permadeath does not free the id: after a mon faints for good,
## its id is retired, the ledger names it, and no mon created
## afterwards — in the same manager, or in a fresh manager that
## adopted the saved state — ever receives that id again.
func test_permadeath_id_never_reused() -> bool:
	var ok: bool = true
	PUWSaveManager.delete_save()
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	mgr.add_pokemon(_mon("Doomed", "Emberfox", 20))
	mgr.add_pokemon(_mon("Survivor", "Aquaff", 20))
	var doomed: Dictionary = mgr.party[0]
	var doomed_id: String = _id_of(doomed)
	var doomed_serial: int = PartyAndStorageManager.mon_id_serial(doomed_id)
	ok = _expect(doomed_id != "" and doomed_serial > 0, "the doomed mon must carry a serial id") and ok
	var result: Dictionary = mgr.handle_faint(0, false, "standard")
	ok = _expect(bool(result.get("permanent", false)), "the faint must be permanent") and ok
	ok = _expect(str(result.get("mon_id", "")) == doomed_id, "the faint result must name the fallen id") and ok
	ok = _expect(mgr.is_mon_id_retired(doomed_id), "the fallen id must be retired") and ok
	var ledger: Array = mgr.fainting_ledger
	ok = _expect(ledger.size() == 1, "the faint must write one ledger entry") and ok
	if ledger.size() == 1:
		var entry: Dictionary = ledger[0]
		ok = _expect(str(entry.get("mon_id", "")) == doomed_id, "the ledger entry must carry the fallen id") and ok
	ok = _expect(mgr.find_mon_by_id(doomed_id).is_empty(), "the fallen mon must no longer be findable") and ok
	# Same manager: 50 fresh mons, none may reuse the retired id,
	# and every new serial must be past the fallen mon's serial.
	for i in 50:
		var fresh_mon: Dictionary = _mon("Fresh" + str(i), "Terrapup", 3)
		mgr.add_pokemon(fresh_mon)
		var fresh_id: String = _id_of(fresh_mon)
		ok = _expect(fresh_id != doomed_id, "a new mon must never reuse the retired id") and ok
		ok = _expect(PartyAndStorageManager.mon_id_serial(fresh_id) > doomed_serial, "new serials must advance past the retired serial") and ok
		if not ok:
			break
	# Across a save/load: the retired set and the counter persist.
	var state: Dictionary = PUWSaveManager.build_state(mgr.party, mgr.pc_boxes, {}, 0, [], [], [], {}, {}, mgr.mon_id_state())
	ok = _expect(PUWSaveManager.save_game(state), "save_game must succeed") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	var mgr2: PartyAndStorageManager = PartyAndStorageManager.new()
	var loaded_book_value: Variant = loaded.get("mon_id_state", {})
	var loaded_book: Dictionary = {}
	if loaded_book_value is Dictionary:
		var book_dict: Dictionary = loaded_book_value
		loaded_book = book_dict
	mgr2.adopt_collections(loaded.get("party", []), loaded.get("boxes", []), [], loaded_book)
	ok = _expect(mgr2.is_mon_id_retired(doomed_id), "the retired id must survive save/load") and ok
	var post_load: Dictionary = _mon("PostLoad", "Terrapup", 3)
	mgr2.add_pokemon(post_load)
	ok = _expect(_id_of(post_load) != doomed_id, "a post-load mon must not reuse the retired id") and ok
	ok = _expect(PartyAndStorageManager.mon_id_serial(_id_of(post_load)) > doomed_serial, "the post-load serial must stay past the retired serial") and ok
	mgr.free()
	mgr2.free()
	PUWSaveManager.delete_save()
	return ok


## A save written before ids existed (no mon_id on any mon, no
## mon_id_state key at all) loads with ids backfilled ONCE: the
## first adoption assigns distinct ids, and after the next save
## those exact ids — not new ones — come back.
func test_old_save_backfill_once() -> bool:
	var ok: bool = true
	PUWSaveManager.delete_save()
	var legacy_party: Array = [_mon("Old1", "Emberfox", 7), _mon("Old2", "Aquaff", 8)]
	var legacy_boxes: Array = [[_mon("Old3", "Terrapup", 4)]]
	var legacy: Dictionary = PUWSaveManager.build_state(legacy_party, legacy_boxes, {}, 42, [], [], [], {}, {})
	legacy.erase("mon_id_state")
	ok = _expect(PUWSaveManager.save_game(legacy), "the legacy save must write") and ok
	var loaded: Dictionary = PUWSaveManager.load_game()
	ok = _expect(not loaded.is_empty(), "the legacy save must load") and ok
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	mgr.adopt_collections(loaded.get("party", []), loaded.get("boxes", []), [], {})
	var backfilled_party_ids: Array = _ids_of(mgr.party)
	var backfilled_box_ids: Array = _ids_of(mgr.pc_boxes[0])
	for id_value in backfilled_party_ids + backfilled_box_ids:
		ok = _expect(str(id_value) != "", "every legacy mon must be backfilled an id") and ok
	var distinct: Dictionary = {}
	for id_value in backfilled_party_ids + backfilled_box_ids:
		distinct[str(id_value)] = true
	ok = _expect(distinct.size() == 3, "backfilled ids must be distinct, got " + str(distinct.size())) and ok
	# Running the id pass again changes nothing (idempotent).
	var again: Dictionary = {"party": mgr.party, "boxes": mgr.pc_boxes, "pc_storage": mgr.pc_storage, "mon_id_state": mgr.mon_id_state()}
	PUWSaveManager.ensure_state_mon_ids(again)
	ok = _expect(JSON.stringify(_ids_of(mgr.party)) == JSON.stringify(backfilled_party_ids), "a second id pass must not change party ids") and ok
	# Save with the bookkeeping and reload: the SAME ids return.
	var state2: Dictionary = PUWSaveManager.build_state(mgr.party, mgr.pc_boxes, {}, 42, [], [], [], {}, {}, mgr.mon_id_state())
	ok = _expect(PUWSaveManager.save_game(state2), "the second save must write") and ok
	var loaded2: Dictionary = PUWSaveManager.load_game()
	var mgr2: PartyAndStorageManager = PartyAndStorageManager.new()
	var book2_value: Variant = loaded2.get("mon_id_state", {})
	var book2: Dictionary = {}
	if book2_value is Dictionary:
		var book2_dict: Dictionary = book2_value
		book2 = book2_dict
	mgr2.adopt_collections(loaded2.get("party", []), loaded2.get("boxes", []), [], book2)
	ok = _expect(JSON.stringify(_ids_of(mgr2.party)) == JSON.stringify(backfilled_party_ids), "backfilled party ids must be stable across the next save/load") and ok
	ok = _expect(JSON.stringify(_ids_of(mgr2.pc_boxes[0])) == JSON.stringify(backfilled_box_ids), "backfilled box ids must be stable across the next save/load") and ok
	mgr.free()
	mgr2.free()
	PUWSaveManager.delete_save()
	return ok


## Anti-duplication at the door: a mon arriving with an id that a
## live mon already carries (a duplicated dict, a copied trade)
## is given a fresh id and the original keeps its own; a mon
## arriving with a RETIRED id is likewise given a fresh one; a
## mon arriving with a genuinely new foreign id keeps it.
func test_duplicate_and_retired_ids_replaced() -> bool:
	var ok: bool = true
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	var first: Dictionary = _mon("First", "Emberfox", 11)
	mgr.add_pokemon(first)
	var first_id: String = _id_of(first)
	# A copy of the same mon dict content, id included.
	var copy: Dictionary = first.duplicate(true)
	mgr.add_pokemon(copy)
	ok = _expect(_id_of(copy) != "", "the copy must carry an id") and ok
	ok = _expect(_id_of(copy) != first_id, "the copy must NOT share the original's id") and ok
	ok = _expect(_id_of(first) == first_id, "the original must keep its id") and ok
	# A foreign id (not our shape) is kept as the mon's identity.
	var foreign: Dictionary = _mon("Foreign", "Aquaff", 6)
	foreign[PartyAndStorageManager.MON_ID_KEY] = "other-save-1234"
	mgr.add_pokemon(foreign)
	ok = _expect(_id_of(foreign) == "other-save-1234", "a trade-in must keep its foreign id") and ok
	# Retire the first mon by release, then present its id again.
	var rel: Dictionary = mgr.release_from_party(0)
	ok = _expect(bool(rel.get("ok", false)), "release must succeed") and ok
	ok = _expect(mgr.is_mon_id_retired(first_id), "the released mon's id must be retired") and ok
	var zombie: Dictionary = _mon("Zombie", "Terrapup", 6)
	zombie[PartyAndStorageManager.MON_ID_KEY] = first_id
	mgr.add_pokemon(zombie)
	ok = _expect(_id_of(zombie) != first_id, "a retired id presented again must be replaced") and ok
	ok = _expect(_id_of(zombie) != "", "the replacement id must be present") and ok
	mgr.free()
	return ok


# ----------------------------------------------------------------
# G5 — VEXA menu shortcut
# ----------------------------------------------------------------

## The X / Rotom Menu shortcut opens the VEXA state: the entry is
## served as data, X toggles it (press only — releases and other
## keys do not), and the open state is backed by the real
## simulator (its formats and their honest build statuses).
func test_vexa_shortcut_opens_state() -> bool:
	var ok: bool = true
	var wiring: PUWLiveWiring = PUWLiveWiring.new()
	root.add_child(wiring)
	var entries: Array = wiring.rotom_menu_entries()
	ok = _expect(entries.size() == 1, "the wiring must serve exactly the VEXA entry, got " + str(entries.size())) and ok
	if entries.size() == 1:
		var entry: Dictionary = entries[0]
		ok = _expect(str(entry.get("id", "")) == "vexa_simulator", "the entry id must be vexa_simulator") and ok
		ok = _expect(str(entry.get("label", "")) == "VEXA Simulator", "the entry label must be VEXA Simulator") and ok
		ok = _expect(str(entry.get("menu", "")) == "rotom_menu", "the entry must name the Rotom Menu") and ok
		ok = _expect(str(entry.get("shortcut_key", "")) == "X", "the entry shortcut must be X") and ok
	ok = _expect(not wiring.is_vexa_menu_open(), "the VEXA state must start closed") and ok
	# A different key does not open it.
	var other_key: InputEventKey = InputEventKey.new()
	other_key.keycode = KEY_Z
	other_key.pressed = true
	wiring._unhandled_input(other_key)
	ok = _expect(not wiring.is_vexa_menu_open(), "a non-X key must not open the VEXA state") and ok
	# X press opens it.
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_X
	press.pressed = true
	wiring._unhandled_input(press)
	ok = _expect(wiring.is_vexa_menu_open(), "pressing X must open the VEXA state") and ok
	var state: Dictionary = wiring.vexa_menu_state()
	ok = _expect(bool(state.get("open", false)), "the state must report open") and ok
	var formats: Array = state.get("formats", [])
	for wanted in ["singles", "doubles", "vgc", "sky", "inverse"]:
		ok = _expect(formats.has(wanted), "the state formats must include " + wanted) and ok
	var statuses: Dictionary = state.get("format_status", {})
	ok = _expect(str(statuses.get("singles", "")) == "built", "singles must report built") and ok
	ok = _expect(str(statuses.get("triple", "")) == "built", "triple must honestly report built") and ok
	ok = _expect(str(statuses.get("tera_raid", "")) == "built", "tera_raid must honestly report built") and ok
	ok = _expect(wiring.vexa_simulator != null, "a real simulator instance must back the state") and ok
	# A key RELEASE does not toggle it shut.
	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_X
	release.pressed = false
	wiring._unhandled_input(release)
	ok = _expect(wiring.is_vexa_menu_open(), "releasing X must not close the VEXA state") and ok
	# A second X press closes it (toggle).
	var press2: InputEventKey = InputEventKey.new()
	press2.keycode = KEY_X
	press2.pressed = true
	wiring._unhandled_input(press2)
	ok = _expect(not wiring.is_vexa_menu_open(), "a second X press must close the VEXA state") and ok
	# The direct entry point opens it too and returns the state.
	var opened: Dictionary = wiring.open_vexa_via_shortcut()
	ok = _expect(bool(opened.get("open", false)), "open_vexa_via_shortcut must return the open state") and ok
	ok = _expect(wiring.is_vexa_menu_open(), "open_vexa_via_shortcut must open the state") and ok
	wiring.free()
	return ok


# ----------------------------------------------------------------
# G7 — hairstyle exclusivity in the shipping creator
# ----------------------------------------------------------------

## The two locked signature style ids are refused by set_value()
## (and nothing is stored), while other styles — ids and the
## free-text descriptions the existing flow uses — are accepted,
## and a full setup with a legal style still completes.
func test_hairstyle_lock() -> bool:
	var ok: bool = true
	ok = _expect(PUWCharacterSetup.is_hairstyle_locked("riley_tousled_bob"), "riley_tousled_bob must be locked") and ok
	ok = _expect(PUWCharacterSetup.is_hairstyle_locked("tasha_copper_waves"), "tasha_copper_waves must be locked") and ok
	ok = _expect(not PUWCharacterSetup.is_hairstyle_locked("high_ponytail"), "high_ponytail must not be locked") and ok
	var locked: Array = PUWCharacterSetup.locked_hairstyles()
	ok = _expect(locked.size() == 2 and locked.has("riley_tousled_bob") and locked.has("tasha_copper_waves"), "locked_hairstyles must list exactly the two signature ids") and ok
	var setup: PUWCharacterSetup = PUWCharacterSetup.new()
	ok = _expect(not setup.set_value("hair_style", "riley_tousled_bob"), "set_value must refuse riley_tousled_bob") and ok
	ok = _expect(setup.get_value("hair_style") == null, "a refused style must not be stored") and ok
	ok = _expect(not setup.set_value("hair_style", "tasha_copper_waves"), "set_value must refuse tasha_copper_waves") and ok
	ok = _expect(setup.get_value("hair_style") == null, "a refused style must not be stored") and ok
	ok = _expect(setup.set_value("hair_style", "high_ponytail"), "set_value must accept an unlocked style id") and ok
	ok = _expect(str(setup.get_value("hair_style")) == "high_ponytail", "the accepted style must be stored") and ok
	setup.free()
	# A complete flow with a legal style still finishes, and the
	# free-text description form the existing suite uses ("tousled
	# bob" — a description, not the locked id) is still accepted.
	var full: PUWCharacterSetup = PUWCharacterSetup.new()
	var values: Dictionary = {
		"identity": "Female",
		"pronouns": "she/her",
		"body_silhouette": "female",
		"face": "soft",
		"eyes": "green",
		"hair_style": "wolf_cut",
		"hair_color": "blonde",
		"clothing": "league jacket",
		"signature_ball": "signature ball",
		"confirm": "confirmed"
	}
	for step_value in full.get_steps():
		var step_id: String = str(step_value)
		if step_id == "heterochromia":
			ok = _expect(full.set_value(step_id, false), "heterochromia must accept a bool") and ok
		else:
			ok = _expect(full.set_value(step_id, str(values[step_id])), "the full flow must accept " + step_id) and ok
	ok = _expect(full.is_complete(), "the full flow with a legal style must complete") and ok
	var built: Dictionary = full.build_character()
	ok = _expect(str(built.get("hair_style", "")) == "wolf_cut", "the built character must keep the legal style") and ok
	full.free()
	var text_setup: PUWCharacterSetup = PUWCharacterSetup.new()
	ok = _expect(text_setup.set_value("hair_style", "tousled bob"), "the free-text description must still be accepted (the lock is on ids)") and ok
	text_setup.free()
	return ok


## The lock lives in the creator only: the named protagonists'
## own canon data is untouched (their signature hair is still
## theirs), and the 2D lock list matches the 3D rig's lock list
## exactly, so the two creators can never drift apart silently.
func test_signature_profiles_unaffected() -> bool:
	var ok: bool = true
	var text: String = FileAccess.get_file_as_string("res://characters/protagonist_canon.json")
	var parsed: Variant = JSON.parse_string(text)
	ok = _expect(typeof(parsed) == TYPE_DICTIONARY, "protagonist_canon.json must parse") and ok
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	var protagonists: Array = data.get("protagonists", [])
	var riley_hair: String = ""
	var tasha_hair: String = ""
	for hero_value in protagonists:
		if hero_value is Dictionary:
			var hero: Dictionary = hero_value
			if str(hero.get("id", "")) == "riley":
				riley_hair = str(hero.get("hair", ""))
			if str(hero.get("id", "")) == "tasha":
				tasha_hair = str(hero.get("hair", ""))
	ok = _expect(riley_hair == "blonde tousled bob", "Riley's canon hair must be untouched, got " + riley_hair) and ok
	ok = _expect(tasha_hair == "long copper-orange wavy hair", "Tasha's canon hair must be untouched, got " + tasha_hair) and ok
	var rig_locked: Array = []
	for style_value in ModularCharacterRig.LOCKED_CANON_HAIRSTYLES:
		rig_locked.append(str(style_value))
	ok = _expect(JSON.stringify(rig_locked) == JSON.stringify(PUWCharacterSetup.locked_hairstyles()), "the 2D lock list must match the 3D rig's lock list exactly") and ok
	return ok
