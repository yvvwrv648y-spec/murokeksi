class_name PUWSpawner
extends Node
## Spawner for Pokemon Ultimate World (Build A, part 2).
##
## Places NPCs, trainers, signs and objects for one map from the
## sourced data files, and provides the trainer sight / interaction
## trigger logic plus dialogue lookup. Standalone by design: it
## needs only a parent Node2D and a map name; it does not depend on
## the player controller or the map loader.
##
## Data sources (all read-only, nothing invented):
##   res://maps/data/maps/<MapName>.json
##       keys: objects (people events), bg_events (signs),
##       warps (not spawned here — warp routing is the map
##       loader's job), tile_size, width_tiles, height_tiles.
##       Object fields: x, y (tile coords, see below), sprite,
##       movement, direction, text_id, trainer ({class, party} or
##       null), item (item id string, "0" for script-give objects,
##       or null).
##   res://data/trainers.json
##       placements: 334 entries with map, x, y (half-tile units),
##       x_tiles, y_tiles (tile units), sprite, movement,
##       direction, text_id, class, party_index, and sight_range
##       on 252 of them (82 have no sight_range key at all; 13 of
##       the 252 carry sight_range 0, e.g. Elite Four rooms).
##   res://data/dialogue_database.json
##       groups keyed by map name; each group holds entries keyed
##       by pokered text label ("_PalletTownGirlText"). Two
##       entries (ColosseumOpponentText, TradeCenterOpponentText)
##       are dicts flagged unresolved_far with empty text.
##
## COORDINATES: map-object x/y are already in the same tile units
## as placement x_tiles/y_tiles (verified: every placement matches
## exactly one map object on map + x + y + class). Node positions
## are tile * the map JSON's tile_size.
##
## DEDUPE RULE (from inspecting the overlap): trainers are spawned
## from the MAP OBJECTS, never from placements directly. A map
## object whose trainer block matches a placement on
## (map, x, y, class) is enriched with that placement's
## sight_range and party_index. All 334 placements match exactly
## one map object, so no trainer is double-spawned and none is
## lost. 12 map objects carry a trainer block with NO placement
## (Mewtwo in CeruleanCaveB1F and the Voltorb/Electrode item balls
## in PowerPlant): they have no sourced sight_range or party
## placement, so they spawn as kind "object" (stationary encounter
## objects) and are named in the report's object_only_trainers
## list instead of being silently treated as trainers.
##
## Object kind classification:
##   trainer block + matching placement -> "trainer"
##   trainer block, no placement        -> "object" (see above)
##   item is a real item id             -> "item"
##   item == "0" (script-give object)   -> "object"
##   anything else                      -> "npc"
##   bg_events                          -> "sign"

const MAPS_DIR: String = "res://maps/data/maps/"
const TRAINERS_PATH: String = "res://data/trainers.json"
const DIALOGUE_PATH: String = "res://data/dialogue_database.json"
# Dialogue prep additions: the Johto bank (bound in build 3 but never
# loaded by the shipped spawner) and the two sourced bridge files
# recovered from the games' own scripts by the dialogue prep
# (hidden_files/code_prep_dialogue). Missing files are tolerated:
# every lookup falls back to the behaviour below.
const JOHTO_DIALOGUE_PATH: String = "res://data/johto/dialogue_database.json"
const KANTO_BRIDGE_PATH: String = "res://data/kanto_text_bridge.json"
const JOHTO_BRIDGE_PATH: String = "res://data/johto_script_bridge.json"
# Sevii restoration additions (sevii_dialogue production): the
# third bank + bridge, recovered from pret/pokefirered's Sevii
# scripts.inc/text.inc after the bound conversion dropped every
# Sevii object script and all 163 signs. Missing files are
# tolerated exactly like the Johto pair above.
const SEVII_DIALOGUE_PATH: String = "res://data/sevii_dialogue_database.json"
const SEVII_BRIDGE_PATH: String = "res://data/sevii_script_bridge.json"
# Binding build 6 (A-16): the service dialogue bank - a
# placement-keyed resolver for mart/nurse/trade/special
# service conversations. Missing file tolerated like the
# banks above.
const SERVICE_BANK_PATH: String = "res://data/service_dialogue_bank.json"

const CARDINAL_DIRECTIONS: Array = ["UP", "DOWN", "LEFT", "RIGHT"]

# Label suffixes stripped when matching a text_id to dialogue
# entry labels, longest first so "BattleText" never eats the
# "End" / "After" / "Before" / "Pre" prefix of a longer suffix.
const LABEL_SUFFIXES: Array = [
	"BeforeBattleText", "AfterBattleText", "EndBattleText",
	"PreBattleText", "BattleText", "Text",
]

# Crystal label suffixes, longest first (AfterBattleText before
# BattleText-style shorter forms, SeenText / BeatenText are the
# Crystal trainer pair).
const JOHTO_LABEL_SUFFIXES: Array = [
	"AfterBattleText", "SeenText", "BeatenText", "Text",
]

var _trainers_data: Dictionary = {}
var _scripted_battles_index: Dictionary = {}
var _placements_index: Dictionary = {}
var _placements_by_object: Dictionary = {}
var _placements_loaded: bool = false
var _dialogue_groups: Dictionary = {}
var _johto_groups: Dictionary = {}
var _kanto_global: Dictionary = {}
var _johto_global: Dictionary = {}
var _kanto_bridge: Dictionary = {}
var _johto_bridge: Dictionary = {}
var _sevii_groups: Dictionary = {}
var _sevii_global: Dictionary = {}
var _sevii_bridge: Dictionary = {}
var _service_kinds: Dictionary = {}
var _service_placements: Dictionary = {}
var _choice_assembler: PUWChoiceAssembler = null
var _dialogue_loaded: bool = false
var _unresolved_dialogue: Array = []
var _unresolved_keys: Dictionary = {}


# ----------------------------------------------------------------
# Loading helpers
# ----------------------------------------------------------------

func _load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _ensure_trainers() -> void:
	if _placements_loaded:
		return
	_placements_loaded = true
	var data_v: Variant = _load_json(TRAINERS_PATH)
	if not (data_v is Dictionary):
		return
	_trainers_data = data_v
	var placements: Array = _trainers_data.get("placements", [])
	for raw_p in placements:
		var p: Dictionary = raw_p
		var key: String = _placement_key(
			String(p.get("map", "")),
			int(p.get("x_tiles", 0)),
			int(p.get("y_tiles", 0)),
			String(p.get("class", "")))
		_placements_index[key] = p
		if p.has("object_index"):
			_placements_by_object[String(p.get("map", "")) + "|" + str(int(p.get("object_index", -1)))] = p
	# Binding build 7 (Stage 5): scripted_battles_johto — the 66
	# NEW-FORMAT script-triggered battle records. Keyed by
	# (map, script) because (map, trainer_id, party_index) is not
	# unique in the source set; each key holds an Array of records.
	var scripted: Array = _trainers_data.get("scripted_battles_johto", [])
	for raw_r in scripted:
		var r: Dictionary = raw_r
		var skey: String = String(r.get("map", "")) + "|" + String(r.get("script", ""))
		var bucket: Array = _scripted_battles_index.get(skey, [])
		bucket.append(r)
		_scripted_battles_index[skey] = bucket


func _placement_key(map_name: String, x: int, y: int, cls: String) -> String:
	return map_name + "|" + str(x) + "|" + str(y) + "|" + cls


func _ensure_dialogue() -> void:
	if _dialogue_loaded:
		return
	_dialogue_loaded = true
	var data_v: Variant = _load_json(DIALOGUE_PATH)
	if data_v is Dictionary:
		var data: Dictionary = data_v
		var groups_v: Variant = data.get("groups", {})
		if groups_v is Dictionary:
			_dialogue_groups = groups_v
	_kanto_global = _global_index(_dialogue_groups)
	var johto_v: Variant = _load_json(JOHTO_DIALOGUE_PATH)
	if johto_v is Dictionary:
		var jdata: Dictionary = johto_v
		var jgroups_v: Variant = jdata.get("groups", {})
		if jgroups_v is Dictionary:
			_johto_groups = jgroups_v
	_johto_global = _global_index(_johto_groups)
	var kb_v: Variant = _load_json(KANTO_BRIDGE_PATH)
	if kb_v is Dictionary:
		_kanto_bridge = kb_v
	var jb_v: Variant = _load_json(JOHTO_BRIDGE_PATH)
	if jb_v is Dictionary:
		_johto_bridge = jb_v
	var sevii_v: Variant = _load_json(SEVII_DIALOGUE_PATH)
	if sevii_v is Dictionary:
		var sdata: Dictionary = sevii_v
		var sgroups_v: Variant = sdata.get("groups", {})
		if sgroups_v is Dictionary:
			_sevii_groups = sgroups_v
	_sevii_global = _global_index(_sevii_groups)
	var sb_v: Variant = _load_json(SEVII_BRIDGE_PATH)
	if sb_v is Dictionary:
		_sevii_bridge = sb_v
	var svc_v: Variant = _load_json(SERVICE_BANK_PATH)
	if svc_v is Dictionary:
		var svc: Dictionary = svc_v
		var kinds_v: Variant = svc.get("kinds", {})
		if kinds_v is Dictionary:
			_service_kinds = kinds_v
		for kind_name_v in _service_kinds:
			var kind_name: String = kind_name_v
			var kind_rec: Dictionary = _service_kinds[kind_name_v]
			var places_v: Variant = kind_rec.get("placements", [])
			if places_v is Array:
				for raw_pl in places_v:
					var pl: Dictionary = raw_pl
					var pkey: String = String(pl.get("map", "")) + "|" + String(pl.get("ref", ""))
					_service_placements[pkey] = String(kind_rec.get("kind", kind_name))


## label -> text across every group of a bank (first non-empty
## string wins; the two Kanto unresolved_far dicts are skipped).
static func _global_index(groups: Dictionary) -> Dictionary:
	var idx: Dictionary = {}
	for map_name_v in groups:
		var g_v: Variant = groups[map_name_v]
		if not (g_v is Dictionary):
			continue
		var g: Dictionary = g_v
		var e_v: Variant = g.get("entries", {})
		if not (e_v is Dictionary):
			continue
		var entries: Dictionary = e_v
		for label_v in entries:
			var label: String = label_v
			if idx.has(label):
				continue
			var v: Variant = entries[label]
			if v is String:
				var t: String = v
				if t != "":
					idx[label] = t
	return idx


func get_trainers_data() -> Dictionary:
	_ensure_trainers()
	return _trainers_data


## Binding build 7 (Stage 5): the scripted-battle trigger records
## for one (map, script) pair, in file order; empty when the map
## script fires no scripted battle. Identity only — the party is
## built by the difficulty layer at battle time (canon D4/D5).
func get_scripted_battles(map_name: String, script: String) -> Array:
	_ensure_trainers()
	var bucket: Array = _scripted_battles_index.get(map_name + "|" + script, [])
	return bucket


# ----------------------------------------------------------------
# Directions
# ----------------------------------------------------------------

static func facing_vector(direction: String) -> Vector2i:
	match direction:
		"UP":
			return Vector2i(0, -1)
		"DOWN":
			return Vector2i(0, 1)
		"LEFT":
			return Vector2i(-1, 0)
		"RIGHT":
			return Vector2i(1, 0)
	return Vector2i.ZERO


# Build the plain trainer Dictionary the trigger functions take,
# from one trainers.json placement. sight_range is -1 when the
# placement has no sight_range key (the data omits the key rather
# than storing a sentinel).
static func trainer_dict_from_placement(p: Dictionary) -> Dictionary:
	var direction: String = String(p.get("direction", "NONE"))
	var sight: int = -1
	if p.has("sight_range"):
		sight = int(p.get("sight_range", -1))
	return {
		"map": String(p.get("map", "")),
		"tile": Vector2i(int(p.get("x_tiles", 0)), int(p.get("y_tiles", 0))),
		"direction": direction,
		"facing": facing_vector(direction),
		"trainer_class": String(p.get("class", "")),
		"party_index": int(p.get("party_index", 0)),
		"sight_range": sight,
		"has_sight_range": p.has("sight_range"),
		"text_id": String(p.get("text_id", "")),
		"sprite": String(p.get("sprite", "")),
	}


# ----------------------------------------------------------------
# Trainer triggers (pure functions)
# ----------------------------------------------------------------

## True only when the trainer HAS a sight_range greater than 0,
## the player stands on the trainer's facing row/column within
## sight_range tiles, and no tile strictly between trainer and
## player is blocked. is_blocked is a Callable taking a Vector2i
## and returning bool; an invalid Callable means nothing blocks.
## Trainers without a sight_range key (or with sight_range 0)
## always return false here — interaction is their only trigger.
static func check_sight(trainer: Dictionary, player_tile: Vector2i, is_blocked: Callable = Callable()) -> bool:
	if not bool(trainer.get("has_sight_range", false)):
		return false
	var sight: int = int(trainer.get("sight_range", -1))
	if sight <= 0:
		return false
	var facing: Vector2i = trainer.get("facing", Vector2i.ZERO)
	if facing == Vector2i.ZERO:
		return false
	var origin: Vector2i = trainer.get("tile", Vector2i.ZERO)
	var delta: Vector2i = player_tile - origin
	var dist: int = 0
	if facing.x != 0:
		if delta.y != 0 or delta.x * facing.x <= 0:
			return false
		dist = absi(delta.x)
	else:
		if delta.x != 0 or delta.y * facing.y <= 0:
			return false
		dist = absi(delta.y)
	if dist < 1 or dist > sight:
		return false
	if is_blocked.is_valid():
		var step: int = 1
		while step < dist:
			var between: Vector2i = origin + facing * step
			var blocked_v: Variant = is_blocked.call(between)
			if bool(blocked_v):
				return false
			step += 1
	return true


## Set-based variant of check_sight: blocked_tiles is a Dictionary
## used as a set of Vector2i keys.
static func check_sight_with_set(trainer: Dictionary, player_tile: Vector2i, blocked_tiles: Dictionary) -> bool:
	var predicate: Callable = func(t: Vector2i) -> bool:
		return blocked_tiles.has(t)
	return check_sight(trainer, player_tile, predicate)


# ----------------------------------------------------------------
# Stealth detection (canon audit gap G2 wiring, 2026-11-23)
# ----------------------------------------------------------------
## Two-channel detection model. The numbers come from Neon's
## core/movement_and_stealth_controller.gd and are published by
## PUWPlayerController (NOISE / DETECTION_MULT):
##   mode       noise   detection_mult
##   sneak      0.00    0.35
##   walk       0.45    1.00
##   run        0.85    1.45
##   bike_acro  1.00    1.75
##   bike_mach  1.00    1.90
##
## SIGHT channel (check_sight_stealth): exactly check_sight's
## facing-line + blocked-tile logic, but the trainer's
## sight_range is scaled by the player's detection_mult, so a
## sneaking player (0.35x) must get much closer to be seen and
## a running player (1.45x, bikes more) is spotted farther
## away. Sneaking is NOT invisibility: at 1 tile in front of a
## sight_range 5 trainer, 1 <= 5 * 0.35 and the player is seen.
##
## NOISE channel (check_noise): noise is hearing, not sight —
## it ignores facing and blocked tiles. The source defines
## noise as a unitless LEVEL, not a radius, so one conversion
## is needed: NOISE_RADIUS_TILES_PER_LEVEL below is a DESIGN
## CONSTANT (not sourced), chosen so the radii land between
## the sight ranges real trainers carry: walk 1.8 tiles,
## run 3.4, bikes 4.0, sneak 0.0 (level 0.00 -> radius 0:
## a crouch-sneaking player is never heard, at any distance).
##
## check_detection is the combined entry point live play
## should call (with the player controller's current_noise()
## and current_detection_mult()): the trainer detects the
## player when EITHER channel fires. Both channels keep
## check_sight's documented gate: a trainer with no
## sight_range key, or sight_range 0, never detects this way —
## interaction stays their only trigger, as before.
##
## check_sight itself is unchanged, so existing behaviour and
## the existing spawner suite are untouched; check_detection
## is purely additive.

## DESIGN CONSTANT (not from the source controller, which
## defines noise levels only): tiles of hearing radius per
## 1.0 of noise level.
const NOISE_RADIUS_TILES_PER_LEVEL: float = 4.0


## Hearing radius in tiles for a noise level. A level of
## 0.0 (sneak) is exactly 0.0: silent.
static func noise_radius_tiles(noise_level: float) -> float:
	if noise_level <= 0.0:
		return 0.0
	return noise_level * NOISE_RADIUS_TILES_PER_LEVEL


## The trainer's sight_range scaled by a detection
## multiplier. 0.0 when the trainer cannot sight-detect at
## all (no sight_range key, or sight_range <= 0).
static func effective_sight_range(trainer: Dictionary, detection_mult: float) -> float:
	if not bool(trainer.get("has_sight_range", false)):
		return 0.0
	var sight: int = int(trainer.get("sight_range", -1))
	if sight <= 0:
		return 0.0
	return float(sight) * detection_mult


## check_sight with the sight_range scaled by detection_mult
## (the player's current movement-mode multiplier). Same
## facing-line and blocked-tile rules; the range comparison
## is float, so 5 * 0.35 = 1.75 still catches a player 1 tile
## away but not 2.
static func check_sight_stealth(trainer: Dictionary, player_tile: Vector2i, detection_mult: float, is_blocked: Callable = Callable()) -> bool:
	var effective: float = effective_sight_range(trainer, detection_mult)
	if effective <= 0.0:
		return false
	var facing: Vector2i = trainer.get("facing", Vector2i.ZERO)
	if facing == Vector2i.ZERO:
		return false
	var origin: Vector2i = trainer.get("tile", Vector2i.ZERO)
	var delta: Vector2i = player_tile - origin
	var dist: int = 0
	if facing.x != 0:
		if delta.y != 0 or delta.x * facing.x <= 0:
			return false
		dist = absi(delta.x)
	else:
		if delta.x != 0 or delta.y * facing.y <= 0:
			return false
		dist = absi(delta.y)
	if dist < 1 or float(dist) > effective:
		return false
	if is_blocked.is_valid():
		var step: int = 1
		while step < dist:
			var between: Vector2i = origin + facing * step
			var blocked_v: Variant = is_blocked.call(between)
			if bool(blocked_v):
				return false
			step += 1
	return true


## True when the trainer hears the player: the player's
## noise radius (from their noise level) reaches the
## trainer's tile. Euclidean distance in tiles; facing and
## blocked tiles do not apply to hearing. Keeps the
## sight-gate: trainers with no sight_range key or
## sight_range 0 never detect (see the section header).
static func check_noise(trainer: Dictionary, player_tile: Vector2i, noise_level: float) -> bool:
	if effective_sight_range(trainer, 1.0) <= 0.0:
		return false
	var radius: float = noise_radius_tiles(noise_level)
	if radius <= 0.0:
		return false
	var origin: Vector2i = trainer.get("tile", Vector2i.ZERO)
	var delta: Vector2 = Vector2(player_tile - origin)
	return delta.length() <= radius


## Combined stealth detection: sight (scaled by
## detection_mult) OR noise. Live play calls this with
## PUWPlayerController.current_detection_mult() and
## current_noise() for the player's current movement mode.
static func check_detection(trainer: Dictionary, player_tile: Vector2i, detection_mult: float, noise_level: float, is_blocked: Callable = Callable()) -> bool:
	if check_sight_stealth(trainer, player_tile, detection_mult, is_blocked):
		return true
	return check_noise(trainer, player_tile, noise_level)


## True when the player stands on the tile adjacent to the
## trainer in the direction the player is facing — i.e. the
## player faces the trainer from an adjacent tile. This is the
## ONLY trigger path for trainers without a sight_range, and it
## also works for sighted trainers.
static func check_interaction(trainer: Dictionary, player_tile: Vector2i, player_facing: Vector2i) -> bool:
	if player_facing == Vector2i.ZERO:
		return false
	var origin: Vector2i = trainer.get("tile", Vector2i.ZERO)
	return player_tile + player_facing == origin


# ----------------------------------------------------------------
# Spawning
# ----------------------------------------------------------------

## Spawn every object / bg_event / trainer of one map under
## parent. Returns a report Dictionary:
##   {map, tile_size, counts {npc, trainer, sign, object, item,
##    total}, trainers_with_sight, trainers_without_sight,
##    trainers_sight_zero, object_only_trainers [],
##    unresolved []}
## trainers_with_sight counts placements that carry a
## sight_range key (252 across all maps); trainers_sight_zero
## separately counts those whose value is 0 (13), which never
## trigger check_sight. unresolved names every ref that did not
## resolve, honestly: trainer objects with no placement and
## text_ids with no dialogue lines.
func spawn_map(parent: Node2D, map_name: String) -> Dictionary:
	_ensure_trainers()
	var report: Dictionary = {
		"map": map_name,
		"tile_size": 0,
		"counts": {"npc": 0, "trainer": 0, "sign": 0, "object": 0, "item": 0, "total": 0},
		"trainers_with_sight": 0,
		"trainers_without_sight": 0,
		"trainers_sight_zero": 0,
		"object_only_trainers": [],
		"unresolved": [],
	}
	var map_v: Variant = _load_json(MAPS_DIR + map_name + ".json")
	if not (map_v is Dictionary):
		report["unresolved"] = ["map_json_missing:" + map_name]
		return report
	var map_data: Dictionary = map_v
	var tile_size: int = int(map_data.get("tile_size", 16))
	report["tile_size"] = tile_size
	var counts: Dictionary = report["counts"]
	var unresolved: Array = report["unresolved"]
	var object_only: Array = report["object_only_trainers"]

	var objects: Array = map_data.get("objects", [])
	var idx: int = 0
	for raw_o in objects:
		var o: Dictionary = raw_o
		var tile: Vector2i = Vector2i(int(o.get("x", 0)), int(o.get("y", 0)))
		var kind: String = "npc"
		var trainer_class: String = ""
		var party_index: int = 0
		var sight: int = -1
		var has_sight: bool = false
		var trainer_v: Variant = o.get("trainer", null)
		if trainer_v is Dictionary:
			var tb: Dictionary = trainer_v
			trainer_class = String(tb.get("class", ""))
			party_index = int(tb.get("party", 0))
			var key: String = _placement_key(map_name, tile.x, tile.y, trainer_class)
			if _placements_index.has(key):
				kind = "trainer"
				var p: Dictionary = _placements_index[key]
				party_index = int(p.get("party_index", party_index))
				has_sight = p.has("sight_range")
				if has_sight:
					sight = int(p.get("sight_range", -1))
					report["trainers_with_sight"] = int(report["trainers_with_sight"]) + 1
					if sight == 0:
						report["trainers_sight_zero"] = int(report["trainers_sight_zero"]) + 1
				else:
					report["trainers_without_sight"] = int(report["trainers_without_sight"]) + 1
			else:
				kind = "object"
				var label: String = "trainer_object_without_placement:" + map_name + ":" + trainer_class + "@" + str(tile.x) + "," + str(tile.y)
				object_only.append(label)
				unresolved.append(label)
		else:
			# Build 6 (A-46 join): FRLG-sourced objects (the Sevii
			# set) carry no trainer block — their trainer identity
			# lives in the placement record keyed by object_index,
			# verified against the object's own script. The object
			# remains the spawn source; the placement supplies
			# class, party and sight, as in the block path above.
			var joined: bool = false
			var okey: String = map_name + "|" + str(idx)
			if _placements_by_object.has(okey):
				var p2: Dictionary = _placements_by_object[okey]
				var obj_script: String = String(o.get("script", ""))
				if obj_script == "" or obj_script == String(p2.get("script", "")):
					joined = true
					kind = "trainer"
					trainer_class = String(p2.get("class", ""))
					party_index = int(p2.get("party_index", 0))
					has_sight = p2.has("sight_range")
					if has_sight:
						sight = int(p2.get("sight_range", -1))
						report["trainers_with_sight"] = int(report["trainers_with_sight"]) + 1
						if sight == 0:
							report["trainers_sight_zero"] = int(report["trainers_sight_zero"]) + 1
					else:
						report["trainers_without_sight"] = int(report["trainers_without_sight"]) + 1
			if not joined:
				var item_v: Variant = o.get("item", null)
				if item_v is String:
					var item_id: String = item_v
					if item_id == "0":
						kind = "object"
					elif item_id != "":
						kind = "item"
		var node: Node2D = _make_node(kind, o, map_name, tile, tile_size, idx)
		if kind == "trainer":
			node.set_meta("trainer_class", trainer_class)
			node.set_meta("party_index", party_index)
			node.set_meta("sight_range", sight)
			node.set_meta("has_sight_range", has_sight)
		parent.add_child(node)
		counts[kind] = int(counts[kind]) + 1
		counts["total"] = int(counts["total"]) + 1
		_note_dialogue(map_name, _ref_of(o), unresolved)
		idx += 1

	var bg_events: Array = map_data.get("bg_events", [])
	for raw_b in bg_events:
		var b: Dictionary = raw_b
		var tile: Vector2i = Vector2i(int(b.get("x", 0)), int(b.get("y", 0)))
		var node: Node2D = _make_node("sign", b, map_name, tile, tile_size, idx)
		parent.add_child(node)
		counts["sign"] = int(counts["sign"]) + 1
		counts["total"] = int(counts["total"]) + 1
		_note_dialogue(map_name, _ref_of(b), unresolved)
		idx += 1

	report["counts"] = counts
	report["unresolved"] = unresolved
	report["object_only_trainers"] = object_only
	return report


func _make_node(kind: String, src: Dictionary, map_name: String, tile: Vector2i, tile_size: int, idx: int) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = kind + "_" + str(idx)
	node.position = Vector2(tile) * float(tile_size)
	var direction: String = String(src.get("direction", ""))
	node.set_meta("kind", kind)
	node.set_meta("map", map_name)
	node.set_meta("source_id", _ref_of(src))
	node.set_meta("tile", tile)
	node.set_meta("sprite", String(src.get("sprite", "")))
	node.set_meta("direction", direction)
	node.set_meta("facing", facing_vector(direction))
	node.set_meta("movement", String(src.get("movement", "")))
	node.set_meta("dialogue_ref", _ref_of(src))
	node.set_meta("script", String(src.get("script", "")))
	var item_v: Variant = src.get("item", null)
	if item_v is String:
		node.set_meta("item", item_v)
	return node


## Extract the trigger-ready trainer Dictionary from a spawned
## trainer node's metadata.
static func trainer_dict_from_node(node: Node) -> Dictionary:
	var direction: String = String(node.get_meta("direction", "NONE"))
	return {
		"map": String(node.get_meta("map", "")),
		"tile": node.get_meta("tile", Vector2i.ZERO),
		"direction": direction,
		"facing": node.get_meta("facing", Vector2i.ZERO),
		"trainer_class": String(node.get_meta("trainer_class", "")),
		"party_index": int(node.get_meta("party_index", 0)),
		"sight_range": int(node.get_meta("sight_range", -1)),
		"has_sight_range": bool(node.get_meta("has_sight_range", false)),
		"text_id": String(node.get_meta("source_id", "")),
		"sprite": String(node.get_meta("sprite", "")),
	}


## The dialogue ref of a placement: its text_id when it carries
## one (Kanto), else its script name (Johto), else "".
static func _ref_of(src: Dictionary) -> String:
	var text_id: String = String(src.get("text_id", ""))
	if text_id != "":
		return text_id
	return String(src.get("script", ""))


func _note_dialogue(map_name: String, text_id: String, unresolved: Array) -> void:
	if text_id == "":
		return
	var lines: Array = dialogue_for(map_name, text_id)
	if lines.is_empty():
		unresolved.append("dialogue_unresolved:" + map_name + ":" + text_id)


# ----------------------------------------------------------------
# Dialogue lookup
# ----------------------------------------------------------------

## The originally shipped Kanto-bank lookup (stage 2 of
## dialogue_for's resolution order; see the end of this file).
## ref is normally a map JSON text_id ("TEXT_PALLETTOWN_GIRL");
## a raw entry label ("ColosseumOpponentText") is also accepted.
## Matching: the ref's core name (map prefix and underscores
## removed) is compared against each entry label's core name
## (map prefix and one trailing suffix such as Text / BattleText /
## BeforeBattleText removed). Exact core matches come first,
## then labels whose core starts with the ref core (multi-part
## scripts such as a clerk's Welcome / DoYouLikeIt / ComeAgain
## lines). Returns [] when nothing resolves — including the two
## known unresolved far-refs, whose database entries are dicts
## flagged unresolved_far with empty text. Recording of
## unresolved refs happens once, in dialogue_for().
func _bound_dialogue_for(map_name: String, ref: String) -> Array:
	_ensure_dialogue()
	var lines: Array = []
	var group_v: Variant = _dialogue_groups.get(map_name, {})
	var entries: Dictionary = {}
	if group_v is Dictionary:
		var g: Dictionary = group_v
		var e_v: Variant = g.get("entries", {})
		if e_v is Dictionary:
			entries = e_v

	# Direct label hit (covers the far-ref entries).
	if entries.has(ref):
		var direct_v: Variant = entries[ref]
		if direct_v is String:
			var direct_text: String = direct_v
			if direct_text != "":
				lines.append(direct_text)
				return lines
		return lines

	# text_id -> label core matching within the map's group.
	var ref_core: String = _ref_core(map_name, ref)
	if ref_core != "" and not entries.is_empty():
		var labels: Array = entries.keys()
		labels.sort()
		var exact: Array = []
		var prefix: Array = []
		for raw_label in labels:
			var label: String = raw_label
			var entry_v: Variant = entries[label]
			if not (entry_v is String):
				continue
			var text: String = entry_v
			if text == "":
				continue
			var core: String = _label_core(map_name, label)
			if core == ref_core:
				exact.append(text)
			elif core.begins_with(ref_core):
				prefix.append(text)
		lines.append_array(exact)
		lines.append_array(prefix)
	return lines


func _ref_core(map_name: String, ref: String) -> String:
	var rest: String = ref
	if rest.begins_with("TEXT_"):
		rest = rest.substr(5)
	var prefix: String = map_name.to_upper() + "_"
	if rest.begins_with(prefix):
		rest = rest.substr(prefix.length())
	return rest.replace("_", "").to_upper()


func _label_core(map_name: String, label: String) -> String:
	var body: String = label
	if body.begins_with("_"):
		body = body.substr(1)
	if body.begins_with(map_name):
		body = body.substr(map_name.length())
	for raw_s in LABEL_SUFFIXES:
		var suffix: String = raw_s
		if body.ends_with(suffix) and body.length() > suffix.length():
			body = body.substr(0, body.length() - suffix.length())
			break
	return body.replace("_", "").to_upper()


func _record_unresolved(map_name: String, ref: String) -> void:
	var key: String = map_name + "|" + ref
	if _unresolved_keys.has(key):
		return
	_unresolved_keys[key] = true
	_unresolved_dialogue.append({"map": map_name, "ref": ref})


## Every dialogue ref that failed to resolve on this spawner,
## as {map, ref} dictionaries, in first-seen order.
func get_unresolved_dialogue() -> Array:
	return _unresolved_dialogue.duplicate()


# ----------------------------------------------------------------
# Dialogue lookup — full resolution order (dialogue prep)
#
# 1. The sourced Kanto bridge: exact label lists recovered from
#    pret/pokered's own scripts (trainer headers, shared roots in
#    data/items/marts.asm and home/overworld_text.asm), played in
#    source order.
# 2. The bound Kanto bank exactly as originally shipped
#    (_bound_dialogue_for: direct label hit, then core matching).
# 3. The Johto bank: the sourced script bridge (labels recovered
#    from pret/pokecrystal's map scripts, in source order), then
#    core matching of the script name against the map's Crystal
#    text labels.
# 4. The Sevii bank (sevii_dialogue production): the sourced
#    script bridge (labels recovered from pret/pokefirered's
#    Sevii scripts, in source order), then core matching of the
#    script name against the map's FRLG text labels. Sevii map
#    names collide with no Kanto/Johto map, and stages 1–3 are
#    per-map, so this stage cannot change Kanto/Johto behaviour.
# A ref that no stage resolves is recorded once in
# get_unresolved_dialogue().
# ----------------------------------------------------------------

func dialogue_for(map_name: String, ref: String) -> Array:
	_ensure_dialogue()
	if _choice_assembler == null:
		_choice_assembler = PUWChoiceAssembler.new()
	var assembled: Array = _choice_assembler.assemble(map_name, ref)
	if not assembled.is_empty():
		return assembled
	var lines: Array = _bridge_lines(_kanto_bridge, _dialogue_groups,
			_kanto_global, map_name, ref)
	if lines.is_empty():
		lines = _bound_dialogue_for(map_name, ref)
	if lines.is_empty():
		lines = _johto_dialogue_for(map_name, ref)
	if lines.is_empty():
		lines = _sevii_dialogue_for(map_name, ref)
	if lines.is_empty():
		lines = _service_dialogue_for(map_name, ref)
	if lines.is_empty():
		_record_unresolved(map_name, ref)
	return lines


## Binding build 6 (A-16): the service-bank resolver.
## A placement listed in the bank resolves to its kind's
## sourced label texts, in bank order. Kinds are the
## mart/nurse/trade conversations and the engine specials
## (21 kinds / 314 label records / 107 placements).
func _service_dialogue_for(map_name: String, ref: String) -> Array:
	var lines: Array = []
	var kind_v: Variant = _service_placements.get(map_name + "|" + ref, "")
	if not (kind_v is String):
		return lines
	var kind_name: String = kind_v
	if kind_name == "":
		return lines
	var rec_v: Variant = _service_kinds.get(kind_name, {})
	if not (rec_v is Dictionary):
		return lines
	var rec: Dictionary = rec_v
	var labels_v: Variant = rec.get("labels", [])
	if labels_v is Array:
		for raw_l in labels_v:
			var lrec: Dictionary = raw_l
			var t_v: Variant = lrec.get("text", "")
			if t_v is String:
				var t: String = t_v
				if t != "":
					lines.append(t)
	return lines


## Script-ref entry point: Johto placements carry a script name
## instead of a text_id. Same resolution as dialogue_for(); named
## for call-site clarity.
func dialogue_for_script(map_name: String, script: String) -> Array:
	return dialogue_for(map_name, script)


## Play a bridge entry: the exact bank labels for (map, ref), in
## bridge order, each resolved in the map's own group first and
## then in the bank-wide index.
func _bridge_lines(bridge: Dictionary, groups: Dictionary,
		global_idx: Dictionary, map_name: String, ref: String) -> Array:
	var lines: Array = []
	var per_map_v: Variant = bridge.get(map_name, {})
	if not (per_map_v is Dictionary):
		return lines
	var per_map: Dictionary = per_map_v
	var labels_v: Variant = per_map.get(ref, [])
	if not (labels_v is Array):
		return lines
	var group_entries: Dictionary = {}
	var g_v: Variant = groups.get(map_name, {})
	if g_v is Dictionary:
		var g: Dictionary = g_v
		var e_v: Variant = g.get("entries", {})
		if e_v is Dictionary:
			group_entries = e_v
	for label_v in labels_v:
		var label: String = label_v
		var text: String = ""
		var own_v: Variant = group_entries.get(label, "")
		if own_v is String:
			text = own_v
		if text == "":
			var glob_v: Variant = global_idx.get(label, "")
			if glob_v is String:
				text = glob_v
		if text != "":
			lines.append(text)
	return lines


func _johto_dialogue_for(map_name: String, ref: String) -> Array:
	var lines: Array = _bridge_lines(_johto_bridge, _johto_groups,
			_johto_global, map_name, ref)
	if not lines.is_empty():
		return lines
	var g_v: Variant = _johto_groups.get(map_name, {})
	if not (g_v is Dictionary):
		return lines
	var g: Dictionary = g_v
	var e_v: Variant = g.get("entries", {})
	if not (e_v is Dictionary):
		return lines
	var entries: Dictionary = e_v
	var ref_core: String = _johto_ref_core(map_name, ref)
	if ref_core == "":
		return lines
	var labels: Array = entries.keys()
	labels.sort()
	var by_rank: Dictionary = {0: [], 1: [], 2: [], 3: []}
	var prefix: Array = []
	for label_v in labels:
		var label: String = label_v
		var v: Variant = entries[label]
		if not (v is String):
			continue
		var text: String = v
		if text == "":
			continue
		var core: String = _johto_label_core(map_name, label)
		if core == ref_core:
			var bucket: Array = by_rank[_johto_suffix_rank(label)]
			bucket.append(text)
		elif core.begins_with(ref_core):
			prefix.append(text)
	for r in range(4):
		var bucket_r: Array = by_rank[r]
		lines.append_array(bucket_r)
	lines.append_array(prefix)
	return lines


func _johto_ref_core(map_name: String, ref: String) -> String:
	var rest: String = ref
	if rest.begins_with("Trainer"):
		rest = rest.substr(7)
	if rest.begins_with(map_name):
		rest = rest.substr(map_name.length())
	return rest.replace("_", "").to_upper()


func _johto_label_core(map_name: String, label: String) -> String:
	var body: String = label
	if body.begins_with(map_name):
		body = body.substr(map_name.length())
	for raw_s in JOHTO_LABEL_SUFFIXES:
		var suffix: String = raw_s
		if body.ends_with(suffix) and body.length() > suffix.length():
			body = body.substr(0, body.length() - suffix.length())
			break
	return body.replace("_", "").to_upper()


## Playback rank for Crystal trainer text: seen, then beaten,
## then after-battle, then anything else.
static func _johto_suffix_rank(label: String) -> int:
	if label.ends_with("SeenText"):
		return 0
	if label.ends_with("BeatenText") or label.ends_with("EndBattleText"):
		return 1
	if label.ends_with("AfterBattleText"):
		return 2
	return 3


# ----------------------------------------------------------------
# Dialogue lookup — Sevii stage (sevii_dialogue production)
#
# FRLG naming: a placement's ref is its event script
# (<Map>_EventScript_<Name>); the map's text labels are
# <Map>_Text_<Name>. Bridge first (exact sourced label lists,
# played in source order, own group then bank-wide index — the
# shared labels live in the bank's "_common" group), then core
# matching within the map's own group, exact cores before
# prefix cores, mirroring the Kanto/Johto stages.
# ----------------------------------------------------------------

func _sevii_dialogue_for(map_name: String, ref: String) -> Array:
	var lines: Array = _bridge_lines(_sevii_bridge, _sevii_groups,
			_sevii_global, map_name, ref)
	if not lines.is_empty():
		return lines
	var g_v: Variant = _sevii_groups.get(map_name, {})
	if not (g_v is Dictionary):
		return lines
	var g: Dictionary = g_v
	var e_v: Variant = g.get("entries", {})
	if not (e_v is Dictionary):
		return lines
	var entries: Dictionary = e_v
	var ref_core: String = _sevii_ref_core(map_name, ref)
	if ref_core == "":
		return lines
	var labels: Array = entries.keys()
	labels.sort()
	var exact: Array = []
	var prefix: Array = []
	for label_v in labels:
		var label: String = label_v
		var v: Variant = entries[label]
		if not (v is String):
			continue
		var text: String = v
		if text == "":
			continue
		var core: String = _sevii_label_core(map_name, label)
		if core == ref_core:
			exact.append(text)
		elif core.begins_with(ref_core):
			prefix.append(text)
	lines.append_array(exact)
	lines.append_array(prefix)
	return lines


func _sevii_ref_core(map_name: String, ref: String) -> String:
	var rest: String = ref
	var prefix: String = map_name + "_EventScript_"
	if rest.begins_with(prefix):
		rest = rest.substr(prefix.length())
	elif rest.begins_with(map_name):
		rest = rest.substr(map_name.length())
	return rest.replace("_", "").to_upper()


func _sevii_label_core(map_name: String, label: String) -> String:
	var body: String = label
	var prefix: String = map_name + "_Text_"
	if body.begins_with(prefix):
		body = body.substr(prefix.length())
	elif body.begins_with(map_name):
		body = body.substr(map_name.length())
	return body.replace("_", "").to_upper()
