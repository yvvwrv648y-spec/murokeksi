class_name PUWSaveManager
extends RefCounted
## Section 22: Atomic versioned save manager (v2) with backup, corruption recovery, and v1 migration.
##
## Full version: build_state() packs the whole game state (party, boxes,
## bag, money, badges, dex lists, story flags, player info) into one plain
## dictionary, save_game() writes it with write_atomic(), and load_game()
## reads it back. If the main save file is missing or damaged, load_game()
## falls back to the backup file. If there is no v2 save at all but an old
## v1 save exists, load_game() loads that and migrates it to v2.
## Mon dicts are plain JSON-safe dictionaries and are treated as opaque:
## this manager never looks inside them — with ONE exception, added for
## canon audit gap G1 (per-mon identity): ensure_state_mon_ids() reads
## and writes only the "mon_id" key of mon dicts in a state dict, plus
## the state's "mon_id_state" bookkeeping key. build_state() carries
## "mon_id_state" as an additive key (default {}), so saves written
## before it existed load exactly as before; the game's load path
## (PartyAndStorageManager.adopt_collections) runs the id pass once
## and the backfilled ids persist from the next save onward.

const SCHEMA_VERSION: int = 2
const PRIMARY_PATH: String = "user://puw_save_v2.json"
const BACKUP_PATH: String = "user://puw_save_v2.bak.json"
const LEGACY_V1_PATH: String = "user://puw_hybrid_v001.json"

static func migrate_v1_to_v2(v1: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"region_id": "kanto",
		"location_id": str(v1.get("map_id", "kanto_pallet_town")),
		"protagonist_id": str(v1.get("protagonist_id", "riley")),
		"position": v1.get("position", [11.0, 15.0]),
		"followers": clampi(int(v1.get("followers", 1)), 1, 6),
		"dex_ledger": v1.get("dex_ledger", {"pkdx_seen": [], "pkdx_caught": [], "mdx_seen": [], "mdx_caught": [], "singleton_ledger": {}}),
		"omni_bracelet_unlocked": false,
		"migrated_from_v1": true
	}

static func write_atomic(payload: Dictionary) -> bool:
	payload["schema_version"] = SCHEMA_VERSION
	var serialized: String = JSON.stringify(payload, "	")
	if FileAccess.file_exists(PRIMARY_PATH):
		var old_txt: String = FileAccess.get_file_as_string(PRIMARY_PATH)
		var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if bak:
			bak.store_string(old_txt)
			bak.close()
	var f := FileAccess.open(PRIMARY_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(serialized)
	f.close()
	return true

## Pack the whole game state into one payload dictionary.
## The schema_version is stamped here too (write_atomic stamps it again
## when saving), so the returned dict already shows the version.
## Arrays and dicts are deep-copied so later changes to the caller's
## values do not change the packed state by accident.
static func build_state(party: Array, boxes: Array, bag: Dictionary, money: int, badges: Array, dex_seen: Array, dex_caught: Array, story_flags: Dictionary, player: Dictionary = {}, mon_id_state: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"party": party.duplicate(true),
		"boxes": boxes.duplicate(true),
		"bag": bag.duplicate(true),
		"money": money,
		"badges": badges.duplicate(true),
		"dex_seen": dex_seen.duplicate(true),
		"dex_caught": dex_caught.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"player": player.duplicate(true),
		# Additive key (canon audit gap G1): per-mon id bookkeeping
		# owned by PartyAndStorageManager (its mon_id_state() /
		# restore_mon_id_state()). Callers that do not pass it get
		# an empty dict, which ensure_state_mon_ids() treats as
		# "derive from the mons present". Saves written before this
		# key existed load fine: a missing key is the same empty
		# default.
		"mon_id_state": mon_id_state.duplicate(true),
		# Additive key (Phase 3 item E): per-area type-rotation state
		# for global habitat encounters, owned by PUWHabitatEncounters
		# (attach_rotation_to_save overwrites this default). Saves
		# written before this key existed load fine: a missing key is
		# treated as empty rotation by the reader.
		"habitat_rotation": {},
		# Additive key (quest board system, binding build 4):
		# per-region board state owned by PUWQuestBoard
		# (ensure_quests creates/mends it; register_board fills
		# it at new-game). Saves written before this key existed
		# load fine: a missing key is treated as an empty board
		# set by ensure_quests.
		"quests": {}
	}

## The serial embedded in a mon id of our shape ("puw-000001-a1b2c3"),
## or 0 when the id is not one of ours. Mirrors
## PartyAndStorageManager.mon_id_serial().
static func _mon_id_serial(mon_id: String) -> int:
	if not mon_id.begins_with("puw-"):
		return 0
	var rest: String = mon_id.trim_prefix("puw-")
	var dash: int = rest.find("-")
	var serial_text: String = rest
	if dash >= 0:
		serial_text = rest.substr(0, dash)
	if not serial_text.is_valid_int():
		return 0
	return int(serial_text)


## Run the per-mon id pass over a state dict, in place, and return
## it. This is the ONE place this manager looks inside mon dicts,
## and it touches only their "mon_id" key:
## - A mon with no id (or an empty one) is assigned a fresh id —
##   this is the one-time backfill for saves written before ids
##   existed.
## - A mon whose id is retired (its id is listed in the state's
##   retired set) or already carried by an earlier mon in the same
##   state (a duplicate) is assigned a fresh id, so a loaded state
##   can never hold two live mons with one identity.
## - Every other id is left exactly as it is: ids are stable
##   across save/load and across party/box moves.
## Serials continue from the state's "mon_id_state" bookkeeping
## ({"next_serial": int, "retired_ids": Array}), floored past the
## highest serial present, and the bookkeeping is written back
## into the state. Id shape matches PartyAndStorageManager's:
## "puw-" + zero-padded serial + "-" + 6 random hex chars.
static func ensure_state_mon_ids(state: Dictionary) -> Dictionary:
	var book: Dictionary = {}
	var book_value: Variant = state.get("mon_id_state", {})
	if book_value is Dictionary:
		var book_dict: Dictionary = book_value
		book = book_dict
	var retired: Dictionary = {}
	var retired_value: Variant = book.get("retired_ids", [])
	if retired_value is Array:
		var retired_list: Array = retired_value
		for id_value in retired_list:
			retired[str(id_value)] = true
	var next_serial: int = int(book.get("next_serial", 1))
	# Gather every mon list in the state: party, the legacy
	# pc_storage list when present, and each box in boxes.
	var mon_lists: Array = []
	var party_value: Variant = state.get("party", [])
	if party_value is Array:
		var party_list: Array = party_value
		mon_lists.append(party_list)
	var storage_value: Variant = state.get("pc_storage", [])
	if storage_value is Array:
		var storage_list: Array = storage_value
		mon_lists.append(storage_list)
	var boxes_value: Variant = state.get("boxes", [])
	if boxes_value is Array:
		var boxes_list: Array = boxes_value
		for box_value in boxes_list:
			if box_value is Array:
				var box_list: Array = box_value
				mon_lists.append(box_list)
	# Floor the serial past every serial already present, live or
	# retired, so a fresh id can never reissue one.
	for list_value in mon_lists:
		var mons: Array = list_value
		for mon_value in mons:
			if mon_value is Dictionary:
				var mon: Dictionary = mon_value
				var present_serial: int = _mon_id_serial(str(mon.get("mon_id", "")))
				if present_serial + 1 > next_serial:
					next_serial = present_serial + 1
	for id_value in retired.keys():
		var retired_serial: int = _mon_id_serial(str(id_value))
		if retired_serial + 1 > next_serial:
			next_serial = retired_serial + 1
	next_serial = maxi(next_serial, 1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var seen: Dictionary = {}
	for list_value in mon_lists:
		var mons: Array = list_value
		for mon_value in mons:
			if mon_value is Dictionary:
				var mon: Dictionary = mon_value
				var existing: String = str(mon.get("mon_id", ""))
				if existing != "" and not retired.has(existing) and not seen.has(existing):
					seen[existing] = true
					continue
				var suffix: String = "%06x" % (rng.randi() & 0xFFFFFF)
				var fresh: String = "puw-" + ("%06d" % next_serial) + "-" + suffix
				next_serial += 1
				mon["mon_id"] = fresh
				seen[fresh] = true
	var retired_out: Array = retired.keys()
	retired_out.sort()
	state["mon_id_state"] = {"next_serial": next_serial, "retired_ids": retired_out}
	return state


## Save a state dict built by build_state() (or any plain dict).
## Returns true when the file was written.
static func save_game(state: Dictionary) -> bool:
	var ok: bool = write_atomic(state)
	# Audio wiring build: a successful save fires the ui_save
	# hook (the index maps it to the FRLG "GUI save game" SE)
	# through PUWUiSound, the one entry point for menu/event
	# sounds. save_game is the single choke point every save
	# caller passes through, so the hook lives here, not in
	# any one menu.
	if ok:
		PUWUiSound.play("ui_save")
	return ok

## Read and JSON-parse one save file. Returns an empty dict when the
## file is missing, empty, or does not parse into a dictionary.
static func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	return data

## Load the saved game.
## Order: main v2 file first, then the v2 backup file (used when the
## main file is missing or damaged), then an old v1 file migrated to v2.
## Returns an empty dict when there is no save at all.
static func load_game() -> Dictionary:
	var primary: Dictionary = _read_save_file(PRIMARY_PATH)
	if not primary.is_empty():
		return primary
	var backup: Dictionary = _read_save_file(BACKUP_PATH)
	if not backup.is_empty():
		return backup
	var legacy: Dictionary = _read_save_file(LEGACY_V1_PATH)
	if not legacy.is_empty():
		return migrate_v1_to_v2(legacy)
	return {}

## True when a v2 save exists (main file or backup file).
static func has_save() -> bool:
	return FileAccess.file_exists(PRIMARY_PATH) or FileAccess.file_exists(BACKUP_PATH)

## Remove the main save file and the backup file.
## Used by the tests and by a future new-game flow.
static func delete_save() -> void:
	if FileAccess.file_exists(PRIMARY_PATH):
		var primary_abs: String = ProjectSettings.globalize_path(PRIMARY_PATH)
		DirAccess.remove_absolute(primary_abs)
	if FileAccess.file_exists(BACKUP_PATH):
		var backup_abs: String = ProjectSettings.globalize_path(BACKUP_PATH)
		DirAccess.remove_absolute(backup_abs)
