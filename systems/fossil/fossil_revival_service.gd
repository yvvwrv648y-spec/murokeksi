class_name PUWFossilRevivalService
extends RefCounted
## Fossil-revival NPC service -- code prep, 2026-11-23.
##
## WHY THIS EXISTS: the item top-batch prep (code_prep_items,
## graded PASS) implemented 38/100 top-batch items but held the
## 3 Kanto fossils as class (c): a fossil has no bag use path --
## it is used at a lab, by an NPC revival SERVICE that did not
## exist anywhere in the engine. This file is that service.
##
## SCOPE: every fossil item the held registry carries
## (data/items_full_compact.json / item_registry.json):
## - 11 single fossils (Gen I-VI), each mapped to its species
##   by the registry's own effect text (verbatim in
##   data/fossil_revival_index.json, per record "source").
## - The 4 Galar component fossils (fossilized bird/fish/drake/
##   dino), which revive only as PAIRS. The registry carries
##   them with null effect text, so the pairings are the
##   canonical Sword/Shield restoration combinations, labeled
##   as such in the index. A single component alone is refused.
##
## FLOW (revive / revive_combination):
##   1. Validate the item id(s) against the index. A non-fossil
##      item is refused ("not_a_fossil") and nothing is consumed.
##   2. Validate the service point (when one is named) against
##      data/fossil_service_points.json; combinations only run
##      at the Galar restoration point.
##   3. Check the bag actually holds the fossil(s)
##      (PUWInventoryManager.count_item, canonical registry ids).
##   4. Build the revived mon through the REAL creation path:
##      PUWTeamBuilder.build_mon(species, level, "singles",
##      auto_evolve=false) -- the exact species, never evolved
##      past its fossil form. If the build yields no mon, the
##      service refuses ("species_build_failed") and the fossil
##      is NOT consumed.
##   5. Stamp provenance (plain JSON-safe fields, below), then
##      consume the fossil(s) through the real bag -- exactly
##      once each -- and hand the mon to the REAL collection
##      path: PartyAndStorageManager.add_pokemon(), which
##      assigns the G1 UUID (mon_id) via ensure_mon_id(),
##      places the mon in the party when there is space, and
##      routes it to pc_storage when the party is full. The
##      result reports which destination was used.
##
## PERMADEATH / REGISTRY: a revived mon is an ordinary owned
## mon. It carries a normal G1 mon_id, sits in the same party /
## storage arrays, rides PUWSaveManager build/save/load as an
## opaque dict, and PartyAndStorageManager.handle_faint applies
## to it exactly as to any other mon. There is NO exemption,
## no special faint handling, and no revival-specific save key:
## the only additions are three provenance fields ON the mon:
##   "origin":         "fossil_revival"
##   "revived_from":   the fossil item id (singles), or the
##                     two component ids joined with "+"
##   "revival_point":  the service point id used ("" if none)
## OT/OWNERSHIP: the pack's mon dicts carry no OT field at all
## (PUWTeamBuilder.build_mon writes none, and no owned-mon path
## in the pack reads one), so ownership is by construction --
## the mon is created directly into the player's collection
## through add_pokemon(), the same as a gift mon. No OT field
## is invented here.
##
## LEVELS: per index record, the debut service's revival level
## for that fossil (Gen I/FRLG 5, RSE 20, DPPt 20, BW 25, XY 20,
## SwSh 10), stored in the data file with a per-record basis
## string. No held gift-level table exists in the registry
## (checked 2026-11-23), so the levels live in data, ready to
## be rescaled by a sourced pass without code changes.
##
## PLACEMENT: service points are DATA
## (data/fossil_service_points.json), registered by
## register_service_points_from_data() / the built-in defaults.
## Kanto's primary point is the Cinnabar Lab (the canon Gen I
## pattern); Pewter's Museum of Science is Kanto's second point
## because the held registry's own effect text names it. This
## prep builds the system + registration only -- no map edits.

const INDEX_PATH: String = "res://data/fossil_revival_index.json"
const POINTS_PATH: String = "res://data/fossil_service_points.json"
const GALAR_POINT_ID: String = "galar_route6_restoration"

var _party_manager: PartyAndStorageManager = null
var _inventory: PUWInventoryManager = null
var _team_builder: PUWTeamBuilder = null
var _singles: Dictionary = {}
var _combinations: Array = []
var _points: Dictionary = {}
var _index_loaded: bool = false


func _init(party_manager: PartyAndStorageManager = null, inventory: PUWInventoryManager = null, team_builder: PUWTeamBuilder = null) -> void:
	_party_manager = party_manager
	_inventory = inventory
	_team_builder = team_builder
	_register_default_points()


func set_party_manager(party_manager: PartyAndStorageManager) -> void:
	_party_manager = party_manager


func set_inventory(inventory: PUWInventoryManager) -> void:
	_inventory = inventory


func set_team_builder(team_builder: PUWTeamBuilder) -> void:
	_team_builder = team_builder


# ------------------------------------------------------------------
# Index loading (data-driven; tests may inject records directly)
# ------------------------------------------------------------------

func _ensure_index() -> bool:
	if _index_loaded:
		return true
	_index_loaded = true
	if FileAccess.file_exists(INDEX_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			load_index(data)
	return not _singles.is_empty()


## Load index records from a parsed fossil_revival_index.json dict.
func load_index(data: Dictionary) -> void:
	_singles.clear()
	_combinations.clear()
	var singles_v: Variant = data.get("singles", [])
	if singles_v is Array:
		var singles: Array = singles_v
		for row_v in singles:
			if row_v is Dictionary:
				var row: Dictionary = row_v
				_singles[str(row.get("item_id", ""))] = row
	var combos_v: Variant = data.get("galar_combinations", [])
	if combos_v is Array:
		var combos: Array = combos_v
		for row_v in combos:
			if row_v is Dictionary:
				_combinations.append(row_v)
	_index_loaded = true


func fossil_record(item_id: String) -> Dictionary:
	_ensure_index()
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	var rec_v: Variant = _singles.get(key, {})
	if rec_v is Dictionary:
		return rec_v
	return {}


func is_fossil_item(item_id: String) -> bool:
	return not fossil_record(item_id).is_empty()


func is_galar_component(item_id: String) -> bool:
	_ensure_index()
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	for combo_v in _combinations:
		if combo_v is Dictionary:
			var combo: Dictionary = combo_v
			var ids_v: Variant = combo.get("item_ids", [])
			if ids_v is Array:
				var ids: Array = ids_v
				for id_v in ids:
					if str(id_v) == key:
						return true
	return false


func combination_record(item_a: String, item_b: String) -> Dictionary:
	_ensure_index()
	var key_a: String = PUWItemRegistry.canonical_id_for(item_a)
	var key_b: String = PUWItemRegistry.canonical_id_for(item_b)
	if key_a == key_b:
		return {}
	for combo_v in _combinations:
		if combo_v is Dictionary:
			var combo: Dictionary = combo_v
			var ids_v: Variant = combo.get("item_ids", [])
			if ids_v is Array:
				var ids: Array = ids_v
				if ids.size() == 2 and ((str(ids[0]) == key_a and str(ids[1]) == key_b) or (str(ids[0]) == key_b and str(ids[1]) == key_a)):
					return combo
	return {}


func known_fossil_items() -> Array:
	_ensure_index()
	var out: Array = []
	for key in _singles.keys():
		out.append(str(key))
	out.sort()
	return out


# ------------------------------------------------------------------
# Service points (placement data + registration)
# ------------------------------------------------------------------

func _register_default_points() -> void:
	if FileAccess.file_exists(POINTS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINTS_PATH))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			register_service_points(data)
			return
	# Built-in fallback: Kanto's two sourced points, so the
	# service still registers if the data file is not yet bound.
	register_service_point({
		"id": "kanto_cinnabar_lab", "region": "kanto",
		"settlement": "Cinnabar Island", "building_name": "Cinnabar Lab",
		"host_kind": "lab", "accepts_all_fossils": true,
	})
	register_service_point({
		"id": "kanto_pewter_museum", "region": "kanto",
		"settlement": "Pewter City", "building_name": "Museum of Science",
		"host_kind": "museum", "accepts_all_fossils": true,
	})


## Register every point in a parsed fossil_service_points.json dict.
func register_service_points(data: Dictionary) -> void:
	var points_v: Variant = data.get("points", [])
	if points_v is Array:
		var points: Array = points_v
		for row_v in points:
			if row_v is Dictionary:
				register_service_point(row_v)


func register_service_point(point: Dictionary) -> void:
	var pid: String = str(point.get("id", ""))
	if not pid.is_empty():
		_points[pid] = point


func service_point(point_id: String) -> Dictionary:
	var rec_v: Variant = _points.get(point_id, {})
	if rec_v is Dictionary:
		return rec_v
	return {}


func service_points() -> Array:
	var out: Array = []
	var ids: Array = _points.keys()
	ids.sort()
	for pid_v in ids:
		var pid: String = str(pid_v)
		out.append(_points[pid])
	return out


func is_registered_point(point_id: String) -> bool:
	return _points.has(point_id)


# ------------------------------------------------------------------
# The revival flow
# ------------------------------------------------------------------

## Revive one single fossil at a service point ("" = the caller
## is already at a point and does not name it). Returns:
## {"ok": bool, "reason": String, "mon": Dictionary,
##  "destination": "party"|"pc_storage"|"", "species": String,
##  "item_consumed": String}
## On any refusal nothing is consumed and no mon is created.
func revive(item_id: String, service_point_id: String = "") -> Dictionary:
	_ensure_index()
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	var record: Dictionary = fossil_record(key)
	if record.is_empty():
		if is_galar_component(key):
			return _refusal("incomplete_fossil_pair", key)
		return _refusal("not_a_fossil", key)
	var point_check: Dictionary = _check_point(service_point_id, false)
	if not bool(point_check.get("ok", false)):
		return _refusal(str(point_check.get("reason", "unknown_service_point")), key)
	if _inventory == null or _party_manager == null or _team_builder == null:
		return _refusal("service_not_wired", key)
	if _inventory.count_item(key) < 1:
		return _refusal("fossil_not_held", key)
	var species_slug: String = str(record.get("species_slug", ""))
	var level: int = int(record.get("level", 0))
	var mon: Dictionary = _build_revived_mon(species_slug, level)
	if mon.is_empty():
		return _refusal("species_build_failed", key)
	mon["origin"] = "fossil_revival"
	mon["revived_from"] = key
	mon["revival_point"] = service_point_id
	if not _inventory.consume_item(key, 1):
		return _refusal("fossil_not_held", key)
	var destination: String = _party_manager.add_pokemon(mon)
	return {
		"ok": true, "reason": "", "mon": mon,
		"destination": destination,
		"species": str(record.get("species", "")),
		"item_consumed": key,
	}


## Revive a Galar two-component combination. Both components
## are consumed exactly once, and only at the Galar restoration
## point when a point is named. Same result shape as revive(),
## with "items_consumed": [id_a, id_b].
func revive_combination(item_a: String, item_b: String, service_point_id: String = "") -> Dictionary:
	_ensure_index()
	var key_a: String = PUWItemRegistry.canonical_id_for(item_a)
	var key_b: String = PUWItemRegistry.canonical_id_for(item_b)
	var record: Dictionary = combination_record(key_a, key_b)
	if record.is_empty():
		var out: Dictionary = _refusal("invalid_combination", key_a)
		out["items_consumed"] = []
		return out
	var point_check: Dictionary = _check_point(service_point_id, true)
	if not bool(point_check.get("ok", false)):
		var out2: Dictionary = _refusal(str(point_check.get("reason", "unknown_service_point")), key_a)
		out2["items_consumed"] = []
		return out2
	if _inventory == null or _party_manager == null or _team_builder == null:
		var out3: Dictionary = _refusal("service_not_wired", key_a)
		out3["items_consumed"] = []
		return out3
	if _inventory.count_item(key_a) < 1 or _inventory.count_item(key_b) < 1:
		var out4: Dictionary = _refusal("fossil_not_held", key_a)
		out4["items_consumed"] = []
		return out4
	var species_slug: String = str(record.get("species_slug", ""))
	var level: int = int(record.get("level", 0))
	var mon: Dictionary = _build_revived_mon(species_slug, level)
	if mon.is_empty():
		var out5: Dictionary = _refusal("species_build_failed", key_a)
		out5["items_consumed"] = []
		return out5
	mon["origin"] = "fossil_revival"
	mon["revived_from"] = key_a + "+" + key_b
	mon["revival_point"] = service_point_id
	if not _inventory.consume_item(key_a, 1):
		var out6: Dictionary = _refusal("fossil_not_held", key_a)
		out6["items_consumed"] = []
		return out6
	if not _inventory.consume_item(key_b, 1):
		# Defensive: counts were pre-checked, so this cannot be
		# reached in normal flow. If it ever is, restore the
		# first component so the pair is never half-consumed.
		_inventory.add_item(key_a, 1)
		var out7: Dictionary = _refusal("fossil_not_held", key_b)
		out7["items_consumed"] = []
		return out7
	var destination: String = _party_manager.add_pokemon(mon)
	return {
		"ok": true, "reason": "", "mon": mon,
		"destination": destination,
		"species": str(record.get("species", "")),
		"item_consumed": key_a + "+" + key_b,
		"items_consumed": [key_a, key_b],
	}


func _check_point(service_point_id: String, for_combination: bool) -> Dictionary:
	if service_point_id.is_empty():
		return {"ok": true, "reason": ""}
	if not _points.has(service_point_id):
		return {"ok": false, "reason": "unknown_service_point"}
	if for_combination and service_point_id != GALAR_POINT_ID:
		return {"ok": false, "reason": "combination_wrong_point"}
	return {"ok": true, "reason": ""}


func _build_revived_mon(species_slug: String, level: int) -> Dictionary:
	if species_slug.is_empty() or level < 1:
		return {}
	var mon: Dictionary = _team_builder.build_mon(species_slug, level, "singles", false)
	if mon.is_empty():
		return {}
	# The creation path must yield exactly the fossil species:
	# auto_evolve=false is passed, and this guard refuses rather
	# than hand out a different species than the index promises.
	if str(mon.get("species_slug", "")) != species_slug:
		return {}
	return mon


func _refusal(reason: String, item_key: String) -> Dictionary:
	return {
		"ok": false, "reason": reason, "mon": {},
		"destination": "", "species": "", "item_consumed": "",
		"item": item_key,
	}
