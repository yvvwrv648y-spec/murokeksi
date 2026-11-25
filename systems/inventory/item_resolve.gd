class_name PUWItemResolve
extends RefCounted
## Source-constant item resolution (code_prep_kanto_item_fixes).
##
## The bound map data names items by their SOURCE constants
## (Gen-1 "TM_WATER_GUN", "ELIXER"; FRLG "ITEM_STAR_PIECE"), and
## PUWItemRegistry.canonical_id_for alone cannot resolve all of
## them — the code_prep_kanto_items audit proved 29 Kanto pickup
## constants have no registry entry through it. This resolver is
## the one path every consumer here (pickups, mart stock, gates)
## uses, in a fixed order:
##
##   1. FRLG spelling: a leading "ITEM_" is stripped.
##   2. Gen-1 TM/HM constants resolve through
##      res://data/gen1_tm_alias.json — extracted from pokered's
##      add_tm/add_hm table and joined to the registry BY MOVE,
##      never by TM number (the numbering differs; a number join
##      teaches wrong moves — audit-proven).
##   3. Gen-1 spelling aliases through res://data/item_aliases.json
##      (ELIXER -> elixir, MAX_ELIXER -> max-elixir,
##      PARLYZ_HEAL -> paralyze-heal, X_DEFEND -> x-defense,
##      X_SPECIAL -> x-sp-atk — each with its evidence in the
##      data file; the file also carries the keys build 6 merges
##      into the registry's source_to_canonical).
##   4. The registry itself (canonical_id_for), accepted only
##      when a canonical entry actually exists.
##
## A constant no stage resolves returns "" — callers report it
## unresolved and change nothing. No name is ever guessed.

const TM_ALIAS_PATH: String = "res://data/gen1_tm_alias.json"
const SPELLING_ALIAS_PATH: String = "res://data/item_aliases.json"

static var _tm_targets: Dictionary = {}
static var _tm_records: Dictionary = {}
static var _tm_loaded: bool = false
static var _spelling: Dictionary = {}
static var _spelling_loaded: bool = false


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


static func _ensure_tm() -> void:
	if _tm_loaded:
		return
	_tm_loaded = true
	_tm_targets = {}
	_tm_records = {}
	var data: Dictionary = _load_json(TM_ALIAS_PATH)
	var entries_value: Variant = data.get("entries", [])
	if entries_value is Array:
		var entries: Array = entries_value
		for entry_value in entries:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var const_name: String = str(entry.get("source_const", ""))
				if const_name == "":
					continue
				_tm_records[const_name] = entry
				_tm_targets[const_name] = str(entry.get("target_canonical", ""))


static func _ensure_spelling() -> void:
	if _spelling_loaded:
		return
	_spelling_loaded = true
	_spelling = {}
	var data: Dictionary = _load_json(SPELLING_ALIAS_PATH)
	var entries_value: Variant = data.get("entries", [])
	if entries_value is Array:
		var entries: Array = entries_value
		for entry_value in entries:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var const_name: String = str(entry.get("source_const", ""))
				if const_name != "":
					_spelling[const_name] = str(entry.get("canonical", ""))


## Resolve any source spelling of an item to its canonical
## registry id, or "" when no held data resolves it.
static func resolve_const(raw: String) -> String:
	if raw == "":
		return ""
	var name: String = raw
	if name.begins_with("ITEM_"):
		name = name.substr(5)
	_ensure_tm()
	if _tm_targets.has(name):
		var tm_target: String = str(_tm_targets[name])
		if tm_target != "" and not PUWItemRegistry.get_entry(tm_target).is_empty():
			return tm_target
		return ""
	_ensure_spelling()
	if _spelling.has(name):
		var alias_target: String = str(_spelling[name])
		if alias_target != "" and not PUWItemRegistry.get_entry(alias_target).is_empty():
			return alias_target
		return ""
	var canonical: String = PUWItemRegistry.canonical_id_for(name)
	if canonical != "" and not PUWItemRegistry.get_entry(canonical).is_empty():
		return canonical
	return ""


## True when resolve_const can resolve the constant.
static func is_resolved(raw: String) -> bool:
	return resolve_const(raw) != ""


## The Gen-1 TM/HM alias record for a source constant
## ({source_const, gen1_number, move_const, move_slug,
## target_canonical, join_evidence, ...}), or {} when the
## constant is not a Gen-1 machine.
static func gen1_machine_record(raw: String) -> Dictionary:
	_ensure_tm()
	var name: String = raw
	if name.begins_with("ITEM_"):
		name = name.substr(5)
	var record_value: Variant = _tm_records.get(name, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return record
	return {}


## Display name for a canonical id: the registry entry's name,
## falling back to the id itself (the registry's own rule).
static func display_name_for(canonical: String) -> String:
	var entry: Dictionary = PUWItemRegistry.get_entry(canonical)
	var display: String = str(entry.get("name", ""))
	if display != "":
		return display
	return canonical
