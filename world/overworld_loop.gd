class_name OverworldLoop
extends Node
## Tall-grass encounters and trainer line of sight for Pokemon
## Ultimate World. Plain words: this file rolls which wild
## Pokemon appears, how likely a step is to start a battle, and
## whether a trainer standing nearby can see the player. It holds
## no game state and it never starts a battle by itself.

## ------------------------------------------------------------------
## Encounter rows: the real fields in encounters_1025.json
## ------------------------------------------------------------------
## The file is one Dictionary with an "entries" list of 1,025
## species. Each species entry has "id", "name", "encounter_count"
## and "encounters": a list of encounter rows. One row looks like
## this (115,237 rows in total, from PokeAPI):
##   {"location_area_name": "friend-safari-grass",
##    "location_area_url": "https://pokeapi.co/api/v2/location-area/1327/",
##    "version_name": "x", "method_name": "walk",
##    "min_level": 30, "max_level": 30, "chance": 33,
##    "condition_values": ["friend-safari-slot-2"]}
## So the real fields are:
##   "chance"    - the weight for this row, a whole number (0-100
##                 in this file). There is NO field called "rate".
##   "min_level" - lowest level for this row.
##   "max_level" - highest level for this row.
##   There is NO "species" field on a row: the species lives on
##   the parent species entry ("name", e.g. "bulbasaur"). Callers
##   that pass rows for one species should add "species" to each
##   row themselves, or read the species from the parent entry.
## For safety this file also accepts rows that use "rate" instead
## of "chance", "level" instead of "min_level"/"max_level", and
## "species" or "name" for the species, so hand-made test rows in
## that shape still work. The file's own fields always win first.

## Pick one wild encounter from a list of encounter rows, weighted
## by each row's "chance" (or "rate" when "chance" is missing).
## Returns {"species": String, "level": int, "rate": float} where
## "rate" is the picked row's weight, or {} when the list is empty
## or every row has a weight of 0.
static func roll_encounter(encounter_rows: Array, rng: RandomNumberGenerator) -> Dictionary:
	if encounter_rows.is_empty():
		return {}
	var use_rng: RandomNumberGenerator = rng
	if use_rng == null:
		use_rng = RandomNumberGenerator.new()
		use_rng.randomize()
	var total: float = 0.0
	for raw_row in encounter_rows:
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		total += _row_weight(row)
	if total <= 0.0:
		return {}
	var roll: float = use_rng.randf() * total
	for raw_row in encounter_rows:
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		var weight: float = _row_weight(row)
		roll -= weight
		if roll <= 0.0 and weight > 0.0:
			var species: String = _row_species(row)
			var min_level: int = _row_min_level(row)
			var max_level: int = _row_max_level(row)
			var level: int = pick_wild_level(min_level, max_level, use_rng)
			return {"species": species, "level": level, "rate": weight}
	return {}

## The weight of one encounter row: its "chance" field, or its
## "rate" field when "chance" is missing. Anything else is 0.
static func _row_weight(row: Dictionary) -> float:
	if row.has("chance"):
		return maxf(0.0, float(row.get("chance", 0)))
	if row.has("rate"):
		return maxf(0.0, float(row.get("rate", 0)))
	return 0.0

## The species for one encounter row: "species" first, then
## "name". "" when the row has neither (in encounters_1025.json
## the species lives on the parent species entry, not the row).
static func _row_species(row: Dictionary) -> String:
	if row.has("species"):
		return str(row.get("species", ""))
	if row.has("name"):
		return str(row.get("name", ""))
	return ""

## Lowest level for one encounter row: "min_level", or "level"
## when there is only one level.
static func _row_min_level(row: Dictionary) -> int:
	if row.has("min_level"):
		return int(row.get("min_level", 1))
	if row.has("level"):
		return int(row.get("level", 1))
	return 1

## Highest level for one encounter row: "max_level", or "level"
## when there is only one level.
static func _row_max_level(row: Dictionary) -> int:
	if row.has("max_level"):
		return int(row.get("max_level", 1))
	if row.has("level"):
		return int(row.get("level", 1))
	return 1

## Chance that one step starts a wild battle, read from the
## current area's own encounter data.
##
## The rate is a designer number, per area: the area's data
## dictionary may carry "encounter_rate", a fraction from 0.0
## to 1.0 (0.1 means about one step in ten starts a battle).
## When the area carries no "encounter_rate", this returns 0.0
## and a step never starts a battle there. The terrain string
## is accepted so callers can pass it, but the number comes
## from the area data only — terrain alone sets nothing.
##
## NO DEFAULT RATE IS BUILT IN, on purpose. No single standard
## number exists to use: the real games change the rate by
## game and by tile. Bulbapedia, "Wild Pokemon"
## (https://m.bulbapedia.bulbagarden.net/wiki/Wild_Pok%C3%A9mon),
## says Generation I tall grass varies from 15 to 25 out of 256
## per step, caves from 10 to 15, and water is 5, and
## Generation III uses a different roll (320 out of 2879 for
## tall grass, 160 for caves and deep sand, 64 for water).
## There is no verified per-step rate at all for "sand" or
## "snow" as plain terrains in that source. So the game
## designer sets "encounter_rate" per area, and until they do,
## the honest answer stays 0.0.
static func step_encounter_chance(terrain: String, area_data: Dictionary = {}) -> float:
	if not area_data.has("encounter_rate"):
		return 0.0
	var rate: float = float(area_data.get("encounter_rate", 0.0))
	return clampf(rate, 0.0, 1.0)

## ------------------------------------------------------------------
## Real wild encounter data: per-area rates and pools from the
## world pack (data/wild_encounters.json)
## ------------------------------------------------------------------
## The world pack's data/wild_encounters.json carries the REAL
## wild tables extracted from the open disassemblies: pret/pokered
## for Kanto (data/wild/maps/*.asm, reached through the
## WildDataPointers table in data/wild/grass_water.asm) and
## pret/pokefirered for the Sevii Islands
## (src/data/wild_encounters.json). Entries are keyed by the map
## id_const the map scenes themselves carry (ROUTE_1,
## MAP_SEVEN_ISLAND, ...). Load the file once and hand it over:
##
##   var f: FileAccess = FileAccess.open(
##       "res://data/wild_encounters.json", FileAccess.READ)
##   loop.set_wild_encounters_data(JSON.parse_string(f.get_as_text()))
##   var chance: float = loop.wild_step_encounter_chance("ROUTE_1", "grass")
##
## Rate semantics, taken from each source engine's own code (the
## conversion lives in rate_byte_to_step_chance below):
## - pokered (Gen 1): engine/battle/wild_encounters.asm,
##   TryDoWildEncounter, compares a random byte (0-255) with the
##   rate byte; an encounter starts when random < rate, so the
##   per-step chance is rate / 256.
## - pokefirered (Gen 3): src/wild_encounter.c,
##   DoWildEncounterRateTest, multiplies the rate by 16 and rolls
##   Random() % 1600 (MAX_ENCOUNTER_RATE) against it, so the base
##   per-step chance is rate * 16 / 1600 = rate / 100. The
##   ability, flute and Cleanse Tag modifiers in that function
##   are NOT modelled here.
## Maps with no entry have no wild table in the source, and
## blocks whose sourced rate is 0 (Route 1's water, Pokemon
## Tower 1F) honestly stay at 0.0: nothing is filled in.

var _wild_maps: Dictionary = {}
var _wild_slot_chances: Dictionary = {}

## ------------------------------------------------------------------
## Global habitat encounters (Phase 3 item E): the PRIMARY wild
## path when habitat data is present. wild_encounters.json is now
## the ENVIRONMENT RECORD (see systems/overworld/habitat_encounters.gd,
## PUWHabitatEncounters): pools are generated globally from PokeAPI
## habitat + type fit, evolution-gated, with persisted per-area type
## rotation. The legacy weighted roll_encounter path above is
## unchanged and still used by callers passing sourced rows (smoke
## test v2 stage 6). Per-step chance semantics are unchanged either
## way: wild_step_encounter_chance still reads the sourced rate byte.
## ------------------------------------------------------------------

var _habitat: PUWHabitatEncounters = null


## Hand over a loaded PUWHabitatEncounters (or pass null to clear).
func set_habitat_encounters(habitat: PUWHabitatEncounters) -> void:
	_habitat = habitat


## Build and load the default habitat encounter system from the
## project's data files. Returns true when it loaded.
func enable_habitat_encounters() -> bool:
	if _habitat == null:
		_habitat = PUWHabitatEncounters.new()
	return _habitat.load_data()


## True when habitat data is present and loaded.
func habitat_encounters_active() -> bool:
	return _habitat != null and _habitat.is_loaded()


## Roll one wild encounter for a map through the habitat system:
## a uniform pick from the area's eligible pool (habitat + type fit,
## evolution gate at party_max, type rotation applied; the encounter
## itself rotates the species). Returns the pool entry
## {"species": <dex id>, "slug", "dex_family", "species_slug"} or {}
## when habitat data is absent or nothing is eligible. The caller
## builds the actual wild mon through PUWTeamBuilder.build_wild_mon
## (level = player_max +1..3, IV 31), exactly as with the legacy path.
func roll_habitat_encounter(map_id_const: String, terrain: String, party_max: int, rng: RandomNumberGenerator) -> Dictionary:
	if _habitat == null:
		return {}
	return _habitat.roll_habitat_encounter(map_id_const, party_max, rng, terrain)


## --- Follower overworld-ability integration (Worker C) ---
## An optional PUWFollowerController whose ACTIVE followers'
## encounter-rate abilities scale the per-step wild chance:
## follower_modified_step_chance(base) = base *
## controller.encounter_rate_multiplier() (Illuminate / Arena
## Trap x2, Stench / White Smoke x0.5; 1.0 with no controller
## or no such follower). Composition influences (Static /
## Magnet Pull attraction, Synchronize, Compound Eyes) live on
## the controller's follower_roll_encounter(). See
## docs/OVERWORLD_ABILITIES.md. No player-facing text here.
var _follower_controller: PUWFollowerController = null


func set_follower_controller(controller: PUWFollowerController) -> void:
	_follower_controller = controller


func follower_modified_step_chance(base_chance: float) -> float:
	if _follower_controller == null:
		return base_chance
	return clampf(base_chance * _follower_controller.encounter_rate_multiplier(), 0.0, 1.0)


## Store the parsed contents of data/wild_encounters.json.
## Anything that is not the expected shape leaves the stored
## data empty, and every lookup then answers 0.0 / {} / [].
func set_wild_encounters_data(data: Dictionary) -> void:
	var maps_value: Variant = data.get("maps", {})
	if maps_value is Dictionary:
		_wild_maps = (maps_value as Dictionary).duplicate()
	else:
		_wild_maps = {}
	var chances_value: Variant = data.get("slot_chances", {})
	if chances_value is Dictionary:
		_wild_slot_chances = (chances_value as Dictionary).duplicate()
	else:
		_wild_slot_chances = {}


## Convert one sourced encounter rate byte into a per-step
## chance (0.0 to 1.0), using the source engine's own semantics
## (see the section comment above for the exact code citations).
## Unknown semantics strings answer 0.0 rather than guessing.
static func rate_byte_to_step_chance(rate_byte: int, semantics: String) -> float:
	if rate_byte <= 0:
		return 0.0
	if semantics == "pokered_gen1":
		return clampf(float(rate_byte) / 256.0, 0.0, 1.0)
	if semantics == "pokefirered_gen3":
		return clampf(float(rate_byte) * 16.0 / 1600.0, 0.0, 1.0)
	return 0.0


## The stored wild entry for one map id_const ("ROUTE_1",
## "MAP_SEVEN_ISLAND", ...), or {} when the map has no wild
## table in the source data.
func get_wild_encounter_entry(map_id_const: String) -> Dictionary:
	var entry_value: Variant = _wild_maps.get(map_id_const, {})
	if entry_value is Dictionary:
		return (entry_value as Dictionary).duplicate()
	return {}


## The terrain block ("grass"/"water" for Kanto, "land"/"water"
## for Sevii) of one map's wild entry. "grass" and "land" answer
## for each other, so callers can always ask for "grass".
## Pokefirered entries whose FireRed and LeafGreen tables differ
## keep both under "firered"/"leafgreen" keys: version picks
## which one answers ("leafgreen" for LeafGreen; anything else
## gets the FireRed table, the pack's default).
func _wild_terrain_block(entry: Dictionary, terrain: String, version: String) -> Dictionary:
	var root: Dictionary = entry
	if entry.has("firered"):
		var key: String = "leafgreen" if version == "leafgreen" else "firered"
		var sub_value: Variant = entry.get(key, {})
		if sub_value is Dictionary:
			root = sub_value as Dictionary
	var block_key: String = terrain
	if terrain == "grass" and not root.has("grass") and root.has("land"):
		block_key = "land"
	elif terrain == "land" and not root.has("land") and root.has("grass"):
		block_key = "grass"
	var block_value: Variant = root.get(block_key, {})
	if block_value is Dictionary:
		return block_value as Dictionary
	return {}


## Chance that one step in terrain ("grass" or "water") starts
## a wild battle on the given map, from the REAL sourced rate:
## the map's rate byte converted by rate_byte_to_step_chance
## with the semantics of the game the table came from. Maps
## with no wild data, and blocks whose sourced rate is 0,
## answer 0.0.
func wild_step_encounter_chance(map_id_const: String, terrain: String, version: String = "") -> float:
	var entry: Dictionary = get_wild_encounter_entry(map_id_const)
	if entry.is_empty():
		return 0.0
	var block: Dictionary = _wild_terrain_block(entry, terrain, version)
	if block.is_empty():
		return 0.0
	var rate: int = int(block.get("rate", 0))
	return rate_byte_to_step_chance(rate, str(entry.get("semantics", "")))


## The map's wild pool for one terrain as rows in the shape
## roll_encounter and the encounter cycle already use:
## {"species", "min_level", "max_level", "chance"}, where
## "chance" is the slot's own weight from the source's slot
## table (pokered: data/wild/probabilities.asm, out of 256;
## pokefirered: the fields arrays in its data file, out of
## 100). Pokered tables whose Red and Blue versions differ keep
## slots_red / slots_blue: version "blue" picks the Blue table,
## anything else the Red one. Empty when the map or terrain
## has no sourced pool.
func wild_encounter_rows(map_id_const: String, terrain: String, version: String = "") -> Array:
	var entry: Dictionary = get_wild_encounter_entry(map_id_const)
	if entry.is_empty():
		return []
	var block: Dictionary = _wild_terrain_block(entry, terrain, version)
	if block.is_empty():
		return []
	var slots_value: Variant = null
	if block.has("slots"):
		slots_value = block.get("slots")
	elif block.has("slots_red") or block.has("slots_blue"):
		var slot_key: String = "slots_blue" if version == "blue" else "slots_red"
		slots_value = block.get(slot_key, [])
	if not (slots_value is Array):
		return []
	var slots: Array = slots_value as Array
	var weights: Array = _wild_slot_weights(str(entry.get("semantics", "")), terrain)
	var rows: Array = []
	for i in slots.size():
		var slot_value: Variant = slots[i]
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = slot_value as Dictionary
		var weight: float = 0.0
		if i < weights.size():
			weight = float(weights[i])
		var min_level: int = int(slot.get("min_level", slot.get("level", 1)))
		var max_level: int = int(slot.get("max_level", slot.get("level", 1)))
		rows.append({
			"species": str(slot.get("species", "")),
			"min_level": min_level,
			"max_level": max_level,
			"chance": weight,
		})
	return rows


## The per-slot weights for one semantics + terrain, from the
## "slot_chances" section of the loaded wild data file.
func _wild_slot_weights(semantics: String, terrain: String) -> Array:
	var table_value: Variant = _wild_slot_chances.get(semantics, {})
	if not (table_value is Dictionary):
		return []
	var table: Dictionary = table_value as Dictionary
	var key: String = terrain
	if terrain == "grass" and not table.has("grass") and table.has("land"):
		key = "land"
	elif terrain == "land" and not table.has("land") and table.has("grass"):
		key = "grass"
	var weights_value: Variant = table.get(key, [])
	if weights_value is Array:
		return weights_value as Array
	return []

## True only when the player is in the trainer's line of sight:
## on the same row (trainer facing left or right) or the same
## column (trainer facing up or down), strictly in front of the
## trainer (not on the trainer's own tile), and within range_tiles
## steps. Walls and other blocks are NOT checked: no obstacle data
## exists, so a trainer can "see" through a wall for now.
static func trainer_sees_player(trainer_pos: Vector2, player_pos: Vector2, facing: Vector2, range_tiles: int) -> bool:
	if range_tiles <= 0:
		return false
	if facing == Vector2.ZERO:
		return false
	if player_pos == trainer_pos:
		return false
	var delta: Vector2 = player_pos - trainer_pos
	# Facing left or right: the player must be on the same row.
	if absf(facing.x) >= absf(facing.y):
		if player_pos.y != trainer_pos.y:
			return false
		if facing.x > 0.0 and delta.x <= 0.0:
			return false
		if facing.x < 0.0 and delta.x >= 0.0:
			return false
		return absf(delta.x) <= float(range_tiles)
	# Facing up or down: the player must be on the same column.
	if player_pos.x != trainer_pos.x:
		return false
	if facing.y > 0.0 and delta.y <= 0.0:
		return false
	if facing.y < 0.0 and delta.y >= 0.0:
		return false
	return absf(delta.y) <= float(range_tiles)

## ------------------------------------------------------------------
## Encounter cycle (vision mode): seeded, equal-probability,
## no-repeat draws over an area's eligible species pool.
## ------------------------------------------------------------------
## This is an ADDED mode. The weighted roll_encounter above is
## unchanged and still governs the default behaviour. The cycle
## governs WHICH species appears when a caller chooses this mode:
## every eligible species is equally likely, drawn WITHOUT
## replacement until the pool is exhausted, then the cycle
## reshuffles and starts over. The pool is built from the SAME
## encounter rows roll_encounter uses, reading the species with
## the same _row_species helper, so there is no second
## eligibility rule. State is kept per area id in _encounter_cycles
## as {pool: Array, remaining: Array, drawn: Array} and can be
## read out as a plain Dictionary and loaded back for save files;
## loading resumes mid-cycle exactly.

var _encounter_cycles: Dictionary = {}


## Fisher-Yates shuffle of a copy of pool, using the caller's rng
## (seeded, so tests are repeatable). Returns the shuffled copy.
static func _shuffled_copy(pool: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = pool.duplicate()
	var use_rng: RandomNumberGenerator = rng
	if use_rng == null:
		use_rng = RandomNumberGenerator.new()
		use_rng.randomize()
	var i: int = out.size() - 1
	while i > 0:
		var j: int = use_rng.randi_range(0, i)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
		i -= 1
	return out


## Start (or reset) the encounter cycle for an area. The pool is
## the distinct species in encounter_rows, in first-seen order.
## Returns the cycle state Dictionary, or {} when the rows hold
## no species at all.
func start_encounter_cycle(area_id: String, encounter_rows: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	for raw_row in encounter_rows:
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		var species: String = _row_species(row)
		if species == "":
			continue
		if not pool.has(species):
			pool.append(species)
	if pool.is_empty():
		_encounter_cycles.erase(area_id)
		return {}
	var state: Dictionary = {
		"pool": pool,
		"remaining": _shuffled_copy(pool, rng),
		"drawn": [],
	}
	_encounter_cycles[area_id] = state
	return get_encounter_cycle_state(area_id)


## Next species in the area's cycle, or "" when the area has no
## cycle (or its pool is empty). When the remaining list runs
## out, it is refilled with a fresh shuffle of the whole pool
## and the drawn list resets, starting a new cycle.
func next_in_encounter_cycle(area_id: String, rng: RandomNumberGenerator) -> String:
	if not _encounter_cycles.has(area_id):
		return ""
	var state: Dictionary = _encounter_cycles[area_id]
	var pool: Array = state.get("pool", [])
	if pool.is_empty():
		return ""
	var remaining: Array = state.get("remaining", [])
	var drawn: Array = state.get("drawn", [])
	if remaining.is_empty():
		remaining = _shuffled_copy(pool, rng)
		drawn = []
	var species: String = str(remaining[remaining.size() - 1])
	remaining.remove_at(remaining.size() - 1)
	drawn.append(species)
	state["remaining"] = remaining
	state["drawn"] = drawn
	_encounter_cycles[area_id] = state
	return species


## The current cycle state for one area as a plain Dictionary
## ({pool, remaining, drawn}, deep-copied), or {} when the area
## has no cycle. Suitable for putting in a save file.
func get_encounter_cycle_state(area_id: String) -> Dictionary:
	if not _encounter_cycles.has(area_id):
		return {}
	var state: Dictionary = _encounter_cycles[area_id]
	return {
		"pool": (state.get("pool", []) as Array).duplicate(),
		"remaining": (state.get("remaining", []) as Array).duplicate(),
		"drawn": (state.get("drawn", []) as Array).duplicate(),
	}


## Every area's cycle state as one plain Dictionary keyed by
## area id, for save files.
func get_all_encounter_cycle_states() -> Dictionary:
	var out: Dictionary = {}
	for area_id in _encounter_cycles.keys():
		out[str(area_id)] = get_encounter_cycle_state(str(area_id))
	return out


## Load a cycle state Dictionary back (one area, or a whole
## Dictionary of area id -> state as made by
## get_all_encounter_cycle_states when area_id is ""). Loading
## resumes mid-cycle exactly: remaining and drawn are restored
## as saved, so no species repeats until the pool is exhausted.
func load_encounter_cycle_state(state_data: Dictionary, area_id: String = "") -> void:
	if area_id != "":
		_store_cycle_state(area_id, state_data)
		return
	for key in state_data.keys():
		var value: Variant = state_data[key]
		if value is Dictionary:
			_store_cycle_state(str(key), value)


func _store_cycle_state(area_id: String, state_data: Dictionary) -> void:
	var pool_value: Variant = state_data.get("pool", [])
	var remaining_value: Variant = state_data.get("remaining", [])
	var drawn_value: Variant = state_data.get("drawn", [])
	if not (pool_value is Array):
		return
	var pool: Array = (pool_value as Array).duplicate()
	if pool.is_empty():
		return
	var remaining: Array = []
	if remaining_value is Array:
		remaining = (remaining_value as Array).duplicate()
	var drawn: Array = []
	if drawn_value is Array:
		drawn = (drawn_value as Array).duplicate()
	_encounter_cycles[area_id] = {"pool": pool, "remaining": remaining, "drawn": drawn}


## Pick a wild level, evenly, between min_level and max_level
## (both ends included). When min is above max they are swapped,
## so min is always <= max. Levels below 1 are raised to 1.
static func pick_wild_level(min_level: int, max_level: int, rng: RandomNumberGenerator) -> int:
	var low: int = mini(min_level, max_level)
	var high: int = maxi(min_level, max_level)
	low = maxi(1, low)
	high = maxi(1, high)
	var use_rng: RandomNumberGenerator = rng
	if use_rng == null:
		use_rng = RandomNumberGenerator.new()
		use_rng.randomize()
	return use_rng.randi_range(low, high)
