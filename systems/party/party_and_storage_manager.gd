class_name PartyAndStorageManager
extends Node
## Manages 6-slot active party, 40-box PC Storage, Permanent Fainting + Evolution-Family Lockout,
## Safe VEXA Holo-Sim bypass, and 6 Exclusive Rival-Defeat Shiny Multi-Gimmick Eggs.
##
## Box system: pc_boxes holds BOX_COUNT boxes, each holding up to
## BOX_CAPACITY mons. BOX_CAPACITY is 30, the series-standard box size.
## pc_storage stays as the legacy overflow list used by add_pokemon();
## that behavior is the old contract and is not changed.
## Game rule: a player must always keep at least 1 mon in the party, so
## deposit() and release_from_party() refuse to empty the party.
##
## Individual identity (canon audit gap G1): every mon that enters
## the collection gets a permanent id under the "mon_id" key,
## assigned by ensure_mon_id() at the entry points (add_pokemon()
## here; catch/hatch/gift/trade-in code elsewhere calls
## register_mon() before placing a mon). An id never changes while
## the mon lives, rides along inside the mon dict through every
## party/box move, and is NEVER reused: when a mon is removed for
## good (permanent faint, release) its id is retired into
## _retired_mon_ids. The id counter + retired set persist through
## the save file via mon_id_state()/restore_mon_id_state() and the
## save manager's "mon_id_state" state key; collections restored
## from a save are adopted through adopt_collections(), which
## backfills ids for mons saved before ids existed.

const MAX_PARTY: int = 6
const BOX_COUNT: int = 40
const BOX_CAPACITY: int = 30
## Dictionary key carrying a mon's permanent individual id.
const MON_ID_KEY: String = "mon_id"
## Id shape: "puw-000001-a1b2c3" — prefix, zero-padded serial,
## random suffix. The serial makes ids unique within a save's
## lineage and monotonic; the suffix keeps ids from two different
## saves (for example a trade between saves) from colliding.
const MON_ID_PREFIX: String = "puw-"
var party: Array = []
var pc_storage: Array = []
var pc_boxes: Array = []
var locked_evo_families: Dictionary = {}
var fainting_ledger: Array = []
var exclusive_eggs: Array = []
var _next_mon_serial: int = 1
var _retired_mon_ids: Dictionary = {}
var _id_rng: RandomNumberGenerator = null

func _init() -> void:
	_ensure_boxes()

## Make sure pc_boxes has BOX_COUNT box arrays. Safe to call any time;
## existing boxes are kept as they are.
func _ensure_boxes() -> void:
	while pc_boxes.size() < BOX_COUNT:
		var empty_box: Array = []
		pc_boxes.append(empty_box)

func add_pokemon(mon: Dictionary) -> String:
	ensure_mon_id(mon)
	if party.size() < MAX_PARTY:
		party.append(mon)
		return "party"
	pc_storage.append(mon)
	return "pc_storage"

# ----------------------------------------------------------------
# Individual identity (mon ids)
# ----------------------------------------------------------------

func _rng() -> RandomNumberGenerator:
	if _id_rng == null:
		_id_rng = RandomNumberGenerator.new()
		_id_rng.randomize()
	return _id_rng


## The serial embedded in an id of our shape, or 0 when the id is
## not one of ours (for example a foreign id a trade brought in).
static func mon_id_serial(mon_id: String) -> int:
	if not mon_id.begins_with(MON_ID_PREFIX):
		return 0
	var rest: String = mon_id.trim_prefix(MON_ID_PREFIX)
	var dash: int = rest.find("-")
	var serial_text: String = rest
	if dash >= 0:
		serial_text = rest.substr(0, dash)
	if not serial_text.is_valid_int():
		return 0
	return int(serial_text)


## Generate the next permanent mon id and advance the counter.
## Ids are never generated twice: the serial only moves forward,
## and restore_mon_id_state() floors it past every live and
## retired serial after a load.
func new_mon_id() -> String:
	var serial: int = _next_mon_serial
	_next_mon_serial += 1
	var suffix: String = "%06x" % (_rng().randi() & 0xFFFFFF)
	return MON_ID_PREFIX + ("%06d" % serial) + "-" + suffix


## Every id currently carried by a held mon (party, pc_storage,
## boxes, eggs), as a set (id -> true). Empty ids are skipped.
func _live_mon_ids() -> Dictionary:
	var ids: Dictionary = {}
	_collect_ids(party, ids)
	_collect_ids(pc_storage, ids)
	_collect_ids(exclusive_eggs, ids)
	_ensure_boxes()
	for i in pc_boxes.size():
		var box: Array = pc_boxes[i]
		_collect_ids(box, ids)
	return ids


func _collect_ids(mons: Array, ids: Dictionary) -> void:
	for mon_value in mons:
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			var mon_id: String = str(mon.get(MON_ID_KEY, ""))
			if mon_id != "":
				ids[mon_id] = true


## True when this exact mon dict is already held in a collection.
func _is_held(mon: Dictionary) -> bool:
	if _held_in(party, mon):
		return true
	if _held_in(pc_storage, mon):
		return true
	if _held_in(exclusive_eggs, mon):
		return true
	_ensure_boxes()
	for i in pc_boxes.size():
		var box: Array = pc_boxes[i]
		if _held_in(box, mon):
			return true
	return false


func _held_in(mons: Array, mon: Dictionary) -> bool:
	for mon_value in mons:
		if mon_value is Dictionary:
			var held: Dictionary = mon_value
			if is_same(held, mon):
				return true
	return false


## Give a mon its permanent id and return the id. Contract: call
## BEFORE the mon is placed in a collection (add_pokemon() does).
## An existing id is kept exactly as it is — a trade-in keeps the
## id it arrived with, and a mon that is already held keeps its
## own id — UNLESS the id is empty, already retired, or carried
## by a DIFFERENT held mon; in those cases a fresh id is assigned
## so two live mons can never share one identity.
func ensure_mon_id(mon: Dictionary) -> String:
	var existing: String = str(mon.get(MON_ID_KEY, ""))
	if existing != "" and not _retired_mon_ids.has(existing):
		if _is_held(mon):
			return existing
		if not _live_mon_ids().has(existing):
			return existing
	var fresh: String = new_mon_id()
	mon[MON_ID_KEY] = fresh
	return fresh


## Entry-point helper for every way a mon joins the collection
## outside add_pokemon(): catches resolved elsewhere, hatches,
## gifts, and trade-ins all call this before placing the mon.
## Same contract and result as ensure_mon_id().
func register_mon(mon: Dictionary) -> String:
	return ensure_mon_id(mon)


## Retire a mon's id: it will never be issued again.
func _retire_mon_id(mon: Dictionary) -> String:
	var mon_id: String = str(mon.get(MON_ID_KEY, ""))
	if mon_id != "":
		_retired_mon_ids[mon_id] = true
	return mon_id


## True when an id has been retired (its mon is gone for good).
func is_mon_id_retired(mon_id: String) -> bool:
	return _retired_mon_ids.has(mon_id)


## Find a held mon by its permanent id. Returns {} when no live
## mon carries it, otherwise {"where": "party"|"pc_storage"|"box",
## "index" or "box"+"slot", "mon": Dictionary}.
func find_mon_by_id(mon_id: String) -> Dictionary:
	if mon_id == "":
		return {}
	for i in party.size():
		var party_mon: Dictionary = party[i]
		if str(party_mon.get(MON_ID_KEY, "")) == mon_id:
			return {"where": "party", "index": i, "mon": party_mon}
	for i in pc_storage.size():
		var stored_mon: Dictionary = pc_storage[i]
		if str(stored_mon.get(MON_ID_KEY, "")) == mon_id:
			return {"where": "pc_storage", "index": i, "mon": stored_mon}
	_ensure_boxes()
	for b in pc_boxes.size():
		var box: Array = pc_boxes[b]
		for s in box.size():
			var boxed_mon: Dictionary = box[s]
			if str(boxed_mon.get(MON_ID_KEY, "")) == mon_id:
				return {"where": "box", "box": b, "slot": s, "mon": boxed_mon}
	return {}


## The id bookkeeping that must persist in the save file:
## {"next_serial": int, "retired_ids": Array of String}.
## Hand it to PUWSaveManager.build_state(..., mon_id_state).
func mon_id_state() -> Dictionary:
	var retired: Array = _retired_mon_ids.keys()
	retired.sort()
	return {"next_serial": _next_mon_serial, "retired_ids": retired}


## Restore the counter and retired set saved by mon_id_state().
## The counter is also floored past every serial still carried by
## a live mon or a retired id, so a stale or hand-edited counter
## can never reissue an id.
func restore_mon_id_state(state: Dictionary) -> void:
	var retired_value: Variant = state.get("retired_ids", [])
	if retired_value is Array:
		var retired_list: Array = retired_value
		for id_value in retired_list:
			_retired_mon_ids[str(id_value)] = true
	var floor_serial: int = int(state.get("next_serial", 1))
	for id_value in _live_mon_ids().keys():
		var live_serial: int = mon_id_serial(str(id_value))
		if live_serial + 1 > floor_serial:
			floor_serial = live_serial + 1
	for id_value in _retired_mon_ids.keys():
		var retired_serial: int = mon_id_serial(str(id_value))
		if retired_serial + 1 > floor_serial:
			floor_serial = retired_serial + 1
	_next_mon_serial = maxi(floor_serial, 1)


## Adopt collections restored from a save file (the load path).
## The arrays are deep-copied in, then every mon is run through
## the save manager's id pass: mons saved before ids existed are
## backfilled once, mons that already carry ids keep them, and
## the counter + retired set end consistent with the save's
## mon_id_state. After adoption, saving again through
## build_state(..., mon_id_state()) persists the backfilled ids,
## so the backfill happens exactly once.
func adopt_collections(new_party: Array, new_boxes: Array, new_pc_storage: Array, saved_mon_id_state: Dictionary) -> void:
	party = new_party.duplicate(true)
	pc_boxes = new_boxes.duplicate(true)
	pc_storage = new_pc_storage.duplicate(true)
	_ensure_boxes()
	var temp: Dictionary = {
		"party": party,
		"boxes": pc_boxes,
		"pc_storage": pc_storage,
		"mon_id_state": saved_mon_id_state.duplicate(true),
	}
	PUWSaveManager.ensure_state_mon_ids(temp)
	var ensured_value: Variant = temp.get("mon_id_state", {})
	if ensured_value is Dictionary:
		var ensured: Dictionary = ensured_value
		restore_mon_id_state(ensured)

func handle_faint(slot_idx: int, is_simulation: bool, format_id: String) -> Dictionary:
	if is_simulation:
		return {"permanent": false, "reason": "VEXA Safe Holo-Sim"}
	if slot_idx < 0 or slot_idx >= party.size():
		return {"permanent": false, "reason": "invalid_slot"}
	var fallen: Dictionary = party.pop_at(slot_idx)
	var fam: String = fallen.get("evo_family", "unknown")
	locked_evo_families[fam] = true
	var fallen_id: String = _retire_mon_id(fallen)
	fainting_ledger.append({"name": fallen.get("name", ""), "evo_family": fam, "format": format_id, "mon_id": fallen_id})
	return {"permanent": true, "evo_family_locked": fam, "mon_id": fallen_id}

func is_capture_legal(evo_family: String) -> bool:
	return not locked_evo_families.get(evo_family, false)

## How many mons are in one box. Returns -1 for a bad box number.
func box_count_used(box_index: int) -> int:
	_ensure_boxes()
	if box_index < 0 or box_index >= BOX_COUNT:
		return -1
	var box: Array = pc_boxes[box_index]
	return box.size()

## Total mons in storage: all boxes plus the legacy pc_storage list.
func total_stored() -> int:
	_ensure_boxes()
	var total: int = pc_storage.size()
	for i in pc_boxes.size():
		var box: Array = pc_boxes[i]
		total += box.size()
	return total

## Move a party mon into a box. With box_index -1, the first box with
## space is used. Fails cleanly when the party would be left empty
## (a player must keep at least 1 mon) or when the box is full.
## Returns {"ok": bool, "reason": String, "box": int, "slot": int}.
## On failure box and slot are -1.
func deposit(party_index: int, box_index: int = -1) -> Dictionary:
	_ensure_boxes()
	if party_index < 0 or party_index >= party.size():
		return {"ok": false, "reason": "invalid_party_index", "box": -1, "slot": -1}
	if party.size() <= 1:
		return {"ok": false, "reason": "party_must_keep_one", "box": -1, "slot": -1}
	var target_box: int = box_index
	if target_box == -1:
		target_box = -1
		for i in pc_boxes.size():
			var candidate: Array = pc_boxes[i]
			if candidate.size() < BOX_CAPACITY:
				target_box = i
				break
		if target_box == -1:
			return {"ok": false, "reason": "all_boxes_full", "box": -1, "slot": -1}
	elif target_box < 0 or target_box >= BOX_COUNT:
		return {"ok": false, "reason": "invalid_box_index", "box": -1, "slot": -1}
	var box: Array = pc_boxes[target_box]
	if box.size() >= BOX_CAPACITY:
		return {"ok": false, "reason": "box_full", "box": target_box, "slot": -1}
	var mon: Dictionary = party[party_index]
	party.remove_at(party_index)
	box.append(mon)
	# Binding build 7 (Stage 6, §13): boxing a mon clears its
	# Pokéathlon juice state (code_prep_pokeathlon merge step 3).
	PUWPokeathlonPerf.clear_juice(mon)
	return {"ok": true, "reason": "", "box": target_box, "slot": box.size() - 1}

## Move a boxed mon into the party. Fails cleanly when the party is full.
## Returns {"ok": bool, "reason": String, "slot": int, "mon": Dictionary}.
## On failure slot is -1 and mon is empty.
func withdraw(box_index: int, slot: int) -> Dictionary:
	_ensure_boxes()
	if box_index < 0 or box_index >= BOX_COUNT:
		return {"ok": false, "reason": "invalid_box_index", "slot": -1, "mon": {}}
	var box: Array = pc_boxes[box_index]
	if slot < 0 or slot >= box.size():
		return {"ok": false, "reason": "invalid_slot", "slot": -1, "mon": {}}
	if party.size() >= MAX_PARTY:
		return {"ok": false, "reason": "party_full", "slot": -1, "mon": {}}
	var mon: Dictionary = box[slot]
	box.remove_at(slot)
	party.append(mon)
	return {"ok": true, "reason": "", "slot": party.size() - 1, "mon": mon}

## Move a mon within the boxes. With to_slot -1, the mon goes to the end
## of the target box. With a to_slot that already holds a mon, the two
## mons swap places. Fails cleanly on bad indexes or a full target box.
## Returns {"ok": bool, "reason": String, "box": int, "slot": int}.
## On failure box and slot are -1.
func move_in_storage(from_box: int, from_slot: int, to_box: int, to_slot: int = -1) -> Dictionary:
	_ensure_boxes()
	if from_box < 0 or from_box >= BOX_COUNT or to_box < 0 or to_box >= BOX_COUNT:
		return {"ok": false, "reason": "invalid_box_index", "box": -1, "slot": -1}
	var source: Array = pc_boxes[from_box]
	var target: Array = pc_boxes[to_box]
	if from_slot < 0 or from_slot >= source.size():
		return {"ok": false, "reason": "invalid_slot", "box": -1, "slot": -1}
	if from_box == to_box and (to_slot == -1 or to_slot == from_slot):
		return {"ok": true, "reason": "", "box": to_box, "slot": from_slot}
	if to_slot == -1:
		if from_box != to_box and target.size() >= BOX_CAPACITY:
			return {"ok": false, "reason": "box_full", "box": to_box, "slot": -1}
		var moved: Dictionary = source[from_slot]
		source.remove_at(from_slot)
		target.append(moved)
		return {"ok": true, "reason": "", "box": to_box, "slot": target.size() - 1}
	if to_slot < 0 or to_slot > target.size():
		return {"ok": false, "reason": "invalid_slot", "box": -1, "slot": -1}
	if to_slot == target.size():
		if from_box == to_box:
			return {"ok": false, "reason": "invalid_slot", "box": -1, "slot": -1}
		var appended: Dictionary = source[from_slot]
		source.remove_at(from_slot)
		target.append(appended)
		return {"ok": true, "reason": "", "box": to_box, "slot": target.size() - 1}
	var mon_a: Dictionary = source[from_slot]
	var mon_b: Dictionary = target[to_slot]
	target[to_slot] = mon_a
	source[from_slot] = mon_b
	return {"ok": true, "reason": "", "box": to_box, "slot": to_slot}

## Remove a party mon for good and return it.
## Refuses to empty the party (a player must keep at least 1 mon).
## Returns {"ok": bool, "reason": String, "mon": Dictionary}.
func release_from_party(party_index: int) -> Dictionary:
	if party_index < 0 or party_index >= party.size():
		return {"ok": false, "reason": "invalid_party_index", "mon": {}}
	if party.size() <= 1:
		return {"ok": false, "reason": "party_must_keep_one", "mon": {}}
	var mon: Dictionary = party[party_index]
	party.remove_at(party_index)
	_retire_mon_id(mon)
	return {"ok": true, "reason": "", "mon": mon}

## Remove a boxed mon for good and return it.
## Returns {"ok": bool, "reason": String, "mon": Dictionary}.
func release_from_box(box_index: int, slot: int) -> Dictionary:
	_ensure_boxes()
	if box_index < 0 or box_index >= BOX_COUNT:
		return {"ok": false, "reason": "invalid_box_index", "mon": {}}
	var box: Array = pc_boxes[box_index]
	if slot < 0 or slot >= box.size():
		return {"ok": false, "reason": "invalid_slot", "mon": {}}
	var mon: Dictionary = box[slot]
	box.remove_at(slot)
	_retire_mon_id(mon)
	return {"ok": true, "reason": "", "mon": mon}
