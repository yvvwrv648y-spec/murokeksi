class_name PUWItemRegistry
extends RefCounted
## Canonical item registry for Pokemon Ultimate World — the one
## item list the game loads (systems/inventory/item_registry.json,
## generated from the sourced data: items_full.json's 2,241 rows
## plus the 58 project entries in complete_item_database.json;
## the master data files themselves are never edited).
##
## Riley's item-integrity rules (2026-11-23), enforced here:
## 1. EVERY ITEM WORKS OR IS FLAGGED: each canonical entry carries
##    "status": "implemented" (its effect is handled by real engine
##    code, listed in "implemented_via") or "flagged_unimplemented"
##    (no engine code handles it — it is never presented as
##    working, and no effect was invented for it).
## 2. NO DUPLICATES: one canonical entry per (name, effect) pair.
##    Source rows that share a name AND an effect merge into one
##    canonical entry; every source row's mapping is recorded in
##    the JSON's "source_to_canonical" table and in each entry's
##    "source_rows". Rows whose source effect text is empty or a
##    source placeholder adopt the single real effect of their
##    name group when there is exactly one (documented in
##    ITEM_AUDIT.md). The bag (MartShop) keys on the canonical id,
##    so the same item can never sit in the bag as two stacks.
##
## Source slugs come in two spellings (PokeAPI "poke-ball" and
## project "poke_ball"); canonical ids use the hyphenated
## PokeAPI spelling when a PokeAPI row exists.

const REGISTRY_PATH: String = "res://systems/inventory/item_registry.json"
const STATUS_IMPLEMENTED: String = "implemented"
const STATUS_FLAGGED: String = "flagged_unimplemented"

static var _cache: Dictionary = {}
static var _cache_loaded: bool = false

## ItemEngine-style normalisation: lowercase, then spaces,
## hyphens, underscores and apostrophes removed. Used to match
## any spelling of a source slug or display name.
static func norm_key(raw: String) -> String:
	var s: String = raw.to_lower()
	s = s.replace(" ", "").replace("-", "").replace("_", "").replace("'", "")
	s = s.replace("é", "e").replace("♀", "f").replace("♂", "m")
	return s

## Load (once) and cache the registry JSON. Returns {} when the
## file is missing or does not parse — callers then fall back to
## the raw id, so the game never crashes on a missing registry.
static func _load() -> Dictionary:
	if _cache_loaded:
		return _cache
	_cache_loaded = true
	_cache = {}
	if not FileAccess.file_exists(REGISTRY_PATH):
		return _cache
	var raw: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_cache = parsed
	return _cache

## All canonical entries (Array of Dictionaries).
static func all_entries() -> Array:
	var data: Dictionary = _load()
	var entries_value: Variant = data.get("canonical_items", [])
	if entries_value is Array:
		return entries_value
	return []

## Registry metadata (counts, sources) from the JSON header.
static func metadata() -> Dictionary:
	var data: Dictionary = _load()
	var meta_value: Variant = data.get("metadata", {})
	if meta_value is Dictionary:
		return meta_value
	return {}

## The canonical entry for a canonical id, or {} when unknown.
static func get_entry(canonical_id: String) -> Dictionary:
	for entry_value in all_entries():
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if str(entry.get("id", "")) == canonical_id:
				return entry
	return {}

## Resolve ANY source spelling to the canonical id: a canonical
## id itself, a source slug ("poke-ball", "poke_ball",
## "lapoke-ball"), or a display name ("Poké Ball"). Unknown ids
## are returned unchanged (normalised only when they match a
## source row), so foreign ids never crash the bag.
static func canonical_id_for(raw_id: String) -> String:
	if raw_id == "":
		return ""
	var data: Dictionary = _load()
	var map_value: Variant = data.get("source_to_canonical", {})
	if map_value is Dictionary:
		var map: Dictionary = map_value
		var direct_value: Variant = map.get(raw_id, "")
		if str(direct_value) != "":
			return str(direct_value)
		var wanted: String = norm_key(raw_id)
		for key_value in map.keys():
			var key: String = str(key_value)
			# Source keys are stored as "source:slug"; match on the
			# slug part, normalised.
			var slug_part: String = key
			var colon: int = key.find(":")
			if colon >= 0:
				slug_part = key.substr(colon + 1)
			var hash_mark: int = slug_part.find("#")
			if hash_mark >= 0:
				slug_part = slug_part.substr(0, hash_mark)
			if norm_key(slug_part) == wanted:
				return str(map[key_value])
		# Display-name match against canonical entries.
		for entry_value in all_entries():
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if norm_key(str(entry.get("name", ""))) == wanted:
					return str(entry.get("id", ""))
				if norm_key(str(entry.get("id", ""))) == wanted:
					return str(entry.get("id", ""))
	return raw_id

## True when the item's effect is implemented in the engine.
static func is_implemented(raw_id: String) -> bool:
	var entry: Dictionary = get_entry(canonical_id_for(raw_id))
	if entry.is_empty():
		return false
	return str(entry.get("status", "")) == STATUS_IMPLEMENTED

## The item's audit status ("implemented" /
## "flagged_unimplemented"), or "" for an unknown id.
static func status_of(raw_id: String) -> String:
	var entry: Dictionary = get_entry(canonical_id_for(raw_id))
	if entry.is_empty():
		return ""
	return str(entry.get("status", ""))

## Counts: {"total", "implemented", "flagged"} over canonical
## entries. Implemented + flagged always sums to total.
static func counts() -> Dictionary:
	var implemented: int = 0
	var flagged: int = 0
	for entry_value in all_entries():
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if str(entry.get("status", "")) == STATUS_IMPLEMENTED:
				implemented += 1
			else:
				flagged += 1
	return {"total": implemented + flagged, "implemented": implemented, "flagged": flagged}
