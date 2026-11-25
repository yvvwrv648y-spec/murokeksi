class_name PUWHabitatEncounters
extends RefCounted
## GLOBAL HABITAT ENCOUNTERS (Riley canon, 2026-11-22, Phase 3 item E).
##
## data/wild_encounters.json is NO LONGER a species list. It is the
## ENVIRONMENT RECORD: what kind of place each area is. Which species
## can appear in an area is generated here, globally:
##
##   An area's pool = EVERY species whose PokeAPI habitat fits the
##   area's environment tags OR whose typing fits the environment.
##   Region and game of origin are IRRELEVANT. Equal odds: the pool
##   is a flat list of entries with NO weights.
##
## ------------------------------------------------------------------
## DATA
## ------------------------------------------------------------------
## - res://data/species_habitats.json (tools/build_species_habitats.py,
##   PokeAPI CSV dumps, fetched 2026-11-22): per species id, the
##   PokeAPI habitat name or null. HONEST COVERAGE: 386 of 1,025
##   species have a non-null habitat; the other 639 have none in
##   PokeAPI and join pools by TYPE FIT ONLY.
## - res://data/area_environments.json (tools/build_area_environments.py):
##   per map id_const, the environment tags derived from the map's own
##   rate>0 encounter blocks in wild_encounters.json plus documented
##   name rules. 115 of 117 areas carry tags; POKEMON_TOWER_1F/2F have
##   no live block in the source and honestly get no pool.
## - Species roster + types: the master registry
##   (res://pokemon/registry/master_species_registry.json) is the
##   primary registry, but in this project snapshot it holds only 25
##   curated species entries. The full 1,025-species roster is
##   therefore merged from the in-project real data that does cover
##   all 1,025: data/evolution_triggers.json (id + slug for every
##   species) and data/competitive_sets.json (types for every
##   species). Registry entries take precedence where both exist,
##   and the registry adds its 3 Gen 10 starters (nat_dex 1026-1028,
##   not in PokeAPI; habitat null, types from the registry), so the
##   full known roster here is 1,028 species.
## - data/mdx_mapping.json: MDX (Moemon) counterparts.
## - data/evolution_triggers.json: evolution gates (below).
##
## ------------------------------------------------------------------
## ENVIRONMENT VOCABULARY + FIT TABLES (written down, in field terms)
## ------------------------------------------------------------------
## Environments: grassland (open fields and meadows), forest (woods),
## water (surfing/fishing water), coastal (shores and beaches), cave
## (caves and tunnels), mountain (peaks and high ground),
## rough-terrain (rocky, broken ground), urban (towns, buildings and
## the Power Plant), cold (ice caves and snowy ground).
##
## HABITAT -> ENVIRONMENT (a species fits an area when its PokeAPI
## habitat maps to one of the area's tags):
##   grassland    -> grassland
##   forest       -> forest, grassland
##   waters-edge  -> water, coastal, grassland
##   sea          -> water, coastal
##   cave         -> cave
##   mountain     -> mountain, rough-terrain, cave
##   rough-terrain-> rough-terrain, mountain, grassland
##   urban        -> urban
##   rare         -> (none: PokeAPI's "rare" bucket is mostly
##                   legendaries; it maps to no field environment, so
##                   those species enter pools by type fit only)
##
## TYPE -> ENVIRONMENT (a species also fits when EITHER of its types
## maps to one of the area's tags):
##   Normal   -> grassland, forest        Fire     -> mountain, rough-terrain
##   Water    -> water, coastal           Electric -> urban, grassland
##   Grass    -> grassland, forest        Ice      -> cold, water
##   Fighting -> mountain, rough-terrain, urban
##   Poison   -> grassland, forest        Ground   -> cave, mountain, rough-terrain
##   Flying   -> grassland, forest, mountain, coastal
##   Psychic  -> urban, forest            Bug      -> grassland, forest
##   Rock     -> cave, mountain, rough-terrain
##   Ghost    -> cave, urban              Dragon   -> mountain, cave, water
##   Dark     -> forest, cave, urban      Steel    -> cave, mountain, urban
##   Fairy    -> grassland, forest
## Every one of the 18 types maps to at least one environment, so no
## type is shut out of the world; per-area pools still differ because
## areas carry different tag sets.
##
## SOURCE PLACEMENT PRESERVATION (Bossy ruling, 2026-11-24, Kanto
## encounter fixes): a species the SOURCE places on a map must be
## reachable on that map -- source placement wins over habitat-fit
## tags. The generated pool above is unchanged (habitat + type fit
## still decides the general pool, and evolution gating + type
## rotation still govern every entry, members included). In
## ADDITION, every species appearing in an area's own sourced
## encounter tables (data/wild_encounters.json: every live block of
## the merged record, top-level and firered/leafgreen sub-tables)
## is a MEMBER of that area's pool, and stays eligible for rolls on
## the terrain whose block places it (grass/land blocks ->
## grassland rolls, water/fishing blocks -> water rolls, rock_smash
## blocks -> rough-terrain rolls) even when its habitat and types
## do not fit the area's tags. This is what keeps Unown in the
## Tanoby chambers (PokeAPI habitat "rare" maps to no environment),
## Seel on Seafoam's land tables, and Horsea in the pond routes'
## fishing tables. Membership never removes a fit species, and the
## preserved cases are enumerable via source_preserved_species().
##
## R-1 LAYER (Kanto encounter R-1 closure, Bossy ruling 2026-11-24):
## twelve Kanto entries whose bound land layer is pokered's carry a
## "frlg_land_membership" layer in the record: the pokefirered land
## tables for those maps, verbatim (firered/leafgreen sub-tables).
## The version-union rule governs -- the species FRLG places on those
## maps belong in the game -- BUT pokered's tables stay the rate/step
## source, so the layer is consumed HERE ONLY, as membership (the
## same source_members mechanism): it never enters the legacy
## step-rate path, which reads only the entry root and the
## firered/leafgreen roots and never this key, and no rate, slot
## order or block of the bound record changes. Without this layer
## the 18 FRLG land placements on those maps (Primeape/Marowak on
## Victory Road, Machoke/Primeape/Wobbuffet/Kadabra in Cerulean
## Cave, Mankey in Rock Tunnel and on Routes 3/4/22/23, Dewgong on
## Seafoam B4F, Primeape on Route 23) were unreachable, because
## membership can only preserve what the record carries.
##
## MDX RULE: where data/mdx_mapping.json gives a species a Moemon
## counterpart (its first/base slot for that slug), the MDX variant is
## its OWN pool entry alongside the PKDX entry -- same flat odds, so a
## species with a counterpart effectively appears in both dex families.
## Pool entries are {"species": <national dex id int>, "slug": String,
## "dex_family": "PKDX"|"MDX"}. There is deliberately NO weight,
## chance or rate key on any entry.
##
## ------------------------------------------------------------------
## EVOLUTION GATING (Riley: no wild Beedrill for a level 5 player)
## ------------------------------------------------------------------
## Gates are computed at load from data/evolution_triggers.json:
## - A species reached by a LEVEL-UP evolution at level L is eligible
##   only when party_max >= L (Kakuna -> Beedrill at 10, so Beedrill's
##   gate is 10).
## - A species reached by a TRADE evolution gets gate 30: PUW canon
##   gives every trade evolution a natural level-up branch at 30.
## - A species reached by any OTHER trigger (stone, happiness, ...)
##   imposes NO extra gate: its gate is its pre-evolution's own gate.
##   Only level-up evolutions (and the documented trade branch) impose
##   a gate. This is stated plainly because it is a rule choice.
## - When several incoming edges exist, the LOWEST resulting gate
##   wins (the easiest real path). Base species: gate 0 (no gate).
##
## ------------------------------------------------------------------
## TYPE ROTATION (persisted, per-area scope)
## ------------------------------------------------------------------
## Rotation scope is PER AREA: each area has its own encountered set.
## When a species is ENCOUNTERED in an area (the roll returns it --
## caught or not is the caller's outcome; the encounter itself is what
## rotates), it moves to the bottom of its type group: it is
## ineligible in that area until every other pool species sharing at
## least one of its types (either type if dual) has also been
## encountered there. Once all of them have been encountered it
## becomes eligible again. Rotation state is a plain Dictionary
## ({area_id: {"encountered": [species ids]}}), exported/imported
## here and stored in the save under the additive key
## "habitat_rotation" (see PUWSaveManager.build_state's default and
## attach_rotation_to_save / restore_rotation_from_save below).

const HABITATS_PATH: String = "res://data/species_habitats.json"
const AREAS_PATH: String = "res://data/area_environments.json"
const WILD_PATH: String = "res://data/wild_encounters.json"
const EVO_PATH: String = "res://data/evolution_triggers.json"
const SETS_PATH: String = "res://data/competitive_sets.json"
const REGISTRY_PATH: String = "res://pokemon/registry/master_species_registry.json"
const MDX_PATH: String = "res://data/mdx_mapping.json"
const SAVE_KEY: String = "habitat_rotation"
const TRADE_BRANCH_LEVEL: int = 30

const HABITAT_TO_ENVIRONMENTS: Dictionary = {
	"grassland": ["grassland"],
	"forest": ["forest", "grassland"],
	"waters-edge": ["water", "coastal", "grassland"],
	"sea": ["water", "coastal"],
	"cave": ["cave"],
	"mountain": ["mountain", "rough-terrain", "cave"],
	"rough-terrain": ["rough-terrain", "mountain", "grassland"],
	"urban": ["urban"],
	"rare": [],
}

const TYPE_TO_ENVIRONMENTS: Dictionary = {
	"normal": ["grassland", "forest"],
	"fire": ["mountain", "rough-terrain"],
	"water": ["water", "coastal"],
	"electric": ["urban", "grassland"],
	"grass": ["grassland", "forest"],
	"ice": ["cold", "water"],
	"fighting": ["mountain", "rough-terrain", "urban"],
	"poison": ["grassland", "forest"],
	"ground": ["cave", "mountain", "rough-terrain"],
	"flying": ["grassland", "forest", "mountain", "coastal"],
	"psychic": ["urban", "forest"],
	"bug": ["grassland", "forest"],
	"rock": ["cave", "mountain", "rough-terrain"],
	"ghost": ["cave", "urban"],
	"dragon": ["mountain", "cave", "water"],
	"dark": ["forest", "cave", "urban"],
	"steel": ["cave", "mountain", "urban"],
	"fairy": ["grassland", "forest"],
}

## Terrain string (OverworldLoop vocabulary) -> the environment a
## step in that terrain draws from.
const TERRAIN_TO_ENVIRONMENT: Dictionary = {
	"grass": "grassland", "land": "grassland",
	"water": "water", "fishing": "water",
	"rock_smash": "rough-terrain",
}

## Encounter-record block key -> the environment whose rolls the
## block's species are source-placed for (membership, above). The
## fishing block places species for water rolls, matching
## TERRAIN_TO_ENVIRONMENT's fishing -> water.
const SOURCE_BLOCK_TO_ENVIRONMENT: Dictionary = {
	"grass": "grassland", "land": "grassland",
	"water": "water", "fishing": "water",
	"rock_smash": "rough-terrain",
}

var _loaded: bool = false
var _species: Dictionary = {}        # id int -> {"slug","types","habitat"}
var _id_by_slug: Dictionary = {}     # slug -> id int
var _area_envs: Dictionary = {}      # map_id_const -> Array of env tags
var _source_members: Dictionary = {} # map_id_const -> {environment -> Array of species ids}
var _gates: Dictionary = {}          # id int -> min party_max (0 = none)
var _mdx_slugs: Dictionary = {}      # slug -> true
var _pool_cache: Dictionary = {}     # area_id -> Array of pool entries
var _pool_overrides: Dictionary = {} # area_id -> Array (tests/custom)
var _rotation: Dictionary = {}       # area_id -> {"encountered": Array[int]}
var _repel_steps: int = 0            # Repel steps remaining (top-batch prep)


static func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func load_data() -> bool:
	if _loaded:
		return true
	# Roster + slugs from evolution_triggers (all 1,025).
	var evo: Dictionary = _load_json_dict(EVO_PATH)
	var evo_rows: Variant = evo.get("data", [])
	if evo_rows is Array:
		var rows: Array = evo_rows
		for row_v in rows:
			if row_v is Dictionary:
				var row: Dictionary = row_v
				var sid: int = int(row.get("id", 0))
				if sid > 0:
					_species[sid] = {"slug": str(row.get("slug", "")), "types": [], "habitat": null}
					_id_by_slug[str(row.get("slug", ""))] = sid
	# Types from competitive_sets (all 1,025).
	var sets: Dictionary = _load_json_dict(SETS_PATH)
	var sets_species: Variant = sets.get("species", {})
	if sets_species is Dictionary:
		var by_slug: Dictionary = sets_species
		for slug_v in by_slug.keys():
			var slug: String = str(slug_v)
			if not _id_by_slug.has(slug):
				continue
			var entry_v: Variant = by_slug[slug_v]
			if entry_v is Dictionary:
				var entry: Dictionary = entry_v
				var types_v: Variant = entry.get("types", [])
				if types_v is Array:
					var rec: Dictionary = _species[int(_id_by_slug[slug])]
					rec["types"] = (types_v as Array).duplicate()
					_species[int(_id_by_slug[slug])] = rec
	# Master registry takes precedence where it has an entry.
	var registry: Dictionary = _load_json_dict(REGISTRY_PATH)
	var reg_species: Variant = registry.get("species", [])
	if reg_species is Array:
		var reg_rows: Array = reg_species
		for reg_v in reg_rows:
			if reg_v is Dictionary:
				var reg: Dictionary = reg_v
				var rid: int = int(reg.get("nat_dex", 0))
				if rid <= 0:
					continue
				var rec2: Dictionary = _species.get(rid, {"slug": "", "types": [], "habitat": null})
				rec2["slug"] = str(reg.get("species_id", rec2.get("slug", "")))
				var rtypes: Variant = reg.get("types", [])
				if rtypes is Array and not (rtypes as Array).is_empty():
					rec2["types"] = (rtypes as Array).duplicate()
				_species[rid] = rec2
				_id_by_slug[str(rec2.get("slug", ""))] = rid
	# PokeAPI habitats.
	var habitats: Dictionary = _load_json_dict(HABITATS_PATH)
	var hab_species: Variant = habitats.get("species", {})
	if hab_species is Dictionary:
		var by_id: Dictionary = hab_species
		for id_v in by_id.keys():
			var hid: int = int(id_v)
			if not _species.has(hid):
				continue
			var hentry_v: Variant = by_id[id_v]
			if hentry_v is Dictionary:
				var hentry: Dictionary = hentry_v
				var rec3: Dictionary = _species[hid]
				rec3["habitat"] = hentry.get("habitat", null)
				_species[hid] = rec3
	# Area environments.
	var areas: Dictionary = _load_json_dict(AREAS_PATH)
	var area_rows: Variant = areas.get("areas", {})
	if area_rows is Dictionary:
		var by_area: Dictionary = area_rows
		for area_v in by_area.keys():
			var aentry_v: Variant = by_area[area_v]
			if aentry_v is Dictionary:
				var aentry: Dictionary = aentry_v
				var envs_v: Variant = aentry.get("environments", [])
				if envs_v is Array:
					_area_envs[str(area_v)] = (envs_v as Array).duplicate()
	# MDX counterparts (first/base slot per slug).
	var mdx: Dictionary = _load_json_dict(MDX_PATH)
	var mdx_rows: Variant = mdx.get("entries", [])
	if mdx_rows is Array:
		var mrows: Array = mdx_rows
		for mrow_v in mrows:
			if mrow_v is Dictionary:
				var mrow: Dictionary = mrow_v
				_mdx_slugs[str(mrow.get("species_slug", ""))] = true
	_load_source_membership()
	_compute_gates(evo)
	_loaded = not _species.is_empty()
	return _loaded


## Source placement membership (see the header ruling): read the
## encounter record and, per area, collect the species each live
## block places there, keyed by the environment that block's rolls
## draw from. Slots carry species_id where the record has one
## (pokefirered-format blocks); pokered-format slots name the
## species, resolved through the roster's slug table. The R-1
## frlg_land_membership layer (twelve Kanto entries) is collected
## the same way, for membership only.
func _load_source_membership() -> void:
	_source_members = {}
	var wild: Dictionary = _load_json_dict(WILD_PATH)
	var maps_v: Variant = wild.get("maps", {})
	if not (maps_v is Dictionary):
		return
	var maps: Dictionary = maps_v
	for area_v in maps.keys():
		var entry_v: Variant = maps[area_v]
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var per_env: Dictionary = {}
		_collect_membership(entry, per_env)
		for version in ["firered", "leafgreen"]:
			var sub_v: Variant = entry.get(version, {})
			if sub_v is Dictionary:
				_collect_membership(sub_v as Dictionary, per_env)
		# R-1 layer: pokefirered land tables carried as membership
		# only (see header). Collected through the same block walker;
		# the layer's own rate is its source encounter_rate and gates
		# nothing here beyond the walker's live-block rule.
		var layer_v: Variant = entry.get("frlg_land_membership", {})
		if layer_v is Dictionary:
			var layer: Dictionary = layer_v
			for lversion in ["firered", "leafgreen"]:
				var lsub_v: Variant = layer.get(lversion, {})
				if lsub_v is Dictionary:
					_collect_membership(lsub_v as Dictionary, per_env)
		if not per_env.is_empty():
			_source_members[str(area_v)] = per_env


func _collect_membership(root: Dictionary, per_env: Dictionary) -> void:
	for block_key_v in SOURCE_BLOCK_TO_ENVIRONMENT.keys():
		var block_key: String = str(block_key_v)
		var block_v: Variant = root.get(block_key, {})
		if not (block_v is Dictionary):
			continue
		var block: Dictionary = block_v
		if int(block.get("rate", 0)) <= 0:
			continue  # a rate-0 block places nothing (honest zero)
		var env: String = str(SOURCE_BLOCK_TO_ENVIRONMENT[block_key])
		for slots_key in ["slots", "slots_red", "slots_blue"]:
			var slots_v: Variant = block.get(slots_key, [])
			if not (slots_v is Array):
				continue
			var slots: Array = slots_v
			for slot_v in slots:
				if not (slot_v is Dictionary):
					continue
				var slot: Dictionary = slot_v
				var sid: int = int(slot.get("species_id", 0))
				if sid <= 0:
					sid = _species_id_for_slot_name(str(slot.get("species", "")))
				if sid <= 0 or not _species.has(sid):
					continue
				var list_v: Variant = per_env.get(env, [])
				var list: Array = list_v if list_v is Array else []
				if not list.has(sid):
					list.append(sid)
				per_env[env] = list


## Record slot name ("GOLBAT", "SPECIES_GOLBAT") -> roster id, via
## the slug table (lowercase, underscores as hyphens). 0 when the
## name is not a roster species.
func _species_id_for_slot_name(raw_name: String) -> int:
	var slug: String = raw_name
	if slug.begins_with("SPECIES_"):
		slug = slug.trim_prefix("SPECIES_")
	slug = slug.to_lower().replace("_", "-")
	return int(_id_by_slug.get(slug, 0))


## True when the species is source-placed in the area for rolls
## drawing from the given environment.
func _is_source_member(area_id: String, species_id: int, environment: String) -> bool:
	var per_env_v: Variant = _source_members.get(area_id, {})
	if per_env_v is Dictionary:
		var list_v: Variant = (per_env_v as Dictionary).get(environment, [])
		if list_v is Array:
			return (list_v as Array).has(species_id)
	return false


## The area's source-table membership: {environment: [species ids
## in record order]}. Empty when the area has no sourced tables.
func source_membership(area_id: String) -> Dictionary:
	load_data()
	var per_env_v: Variant = _source_members.get(area_id, {})
	if per_env_v is Dictionary:
		return (per_env_v as Dictionary).duplicate(true)
	return {}


## Species in the area's pool ONLY because the source tables place
## them there (their habitat and types do not fit the area's
## environment tags) -- the preserved cases of the header ruling,
## sorted by national dex id. The verification log for this prep
## enumerates these per area from the same data.
func source_preserved_species(area_id: String) -> Array:
	load_data()
	var envs: Array = area_environments(area_id)
	var per_env: Dictionary = source_membership(area_id)
	var seen: Dictionary = {}
	var out: Array = []
	for env_v in per_env.keys():
		var list_v: Variant = per_env[env_v]
		if list_v is Array:
			var list: Array = list_v
			for sid_v in list:
				var sid: int = int(sid_v)
				if seen.has(sid):
					continue
				seen[sid] = true
				if not species_fits(sid, envs):
					out.append(sid)
	out.sort()
	return out


func is_loaded() -> bool:
	return load_data()


func species_count() -> int:
	load_data()
	return _species.size()


## Species with a non-null PokeAPI habitat (honest coverage count).
func habitat_coverage_count() -> int:
	load_data()
	var count: int = 0
	for id_v in _species.keys():
		var rec: Dictionary = _species[id_v]
		if rec.get("habitat", null) != null:
			count += 1
	return count


func _compute_gates(evo: Dictionary) -> void:
	# -1 = not computed yet. After the fixpoint, anything still -1 is
	# a base species (or unreachable by any recorded edge): gate 0.
	_gates = {}
	for id_v in _species.keys():
		_gates[int(id_v)] = -1
	var edges: Array = []  # {from_id, to_id, trigger, min_level, trade}
	var rows_v: Variant = evo.get("data", [])
	if rows_v is Array:
		var rows: Array = rows_v
		for row_v in rows:
			if not (row_v is Dictionary):
				continue
			var row: Dictionary = row_v
			var from_id: int = int(row.get("id", 0))
			var options_v: Variant = row.get("evolves_to", [])
			if not (options_v is Array):
				continue
			var options: Array = options_v
			for opt_v in options:
				if opt_v is Dictionary:
					var opt: Dictionary = opt_v
					edges.append({
						"from_id": from_id,
						"to_id": int(opt.get("to_id", 0)),
						"trigger": str(opt.get("trigger", "")),
						"min_level": opt.get("min_level", null),
						"trade": bool(opt.get("trade", false)),
					})
	# Fixpoint: propagate the "no extra gate" edges (the gate of the
	# pre-evolution) until nothing changes, taking the LOWEST gate
	# any real incoming path gives each species (0 included: an
	# ungated path beats a gated one).
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 12:
		changed = false
		guard += 1
		for edge_v in edges:
			var edge: Dictionary = edge_v
			var to_id: int = int(edge.get("to_id", 0))
			if to_id <= 0 or not _gates.has(to_id):
				continue
			var candidate: int = -1
			if str(edge.get("trigger", "")) == "level-up" and edge.get("min_level", null) != null:
				candidate = int(edge.get("min_level", 0))
			elif bool(edge.get("trade", false)) or str(edge.get("trigger", "")) == "trade":
				candidate = TRADE_BRANCH_LEVEL
			else:
				var from_gate: int = int(_gates.get(int(edge.get("from_id", 0)), -1))
				if from_gate < 0:
					continue  # pre-evolution's gate not final yet
				candidate = from_gate
			var current: int = int(_gates.get(to_id, -1))
			if current < 0 or candidate < current:
				_gates[to_id] = candidate
				changed = true
	for id_v2 in _gates.keys():
		if int(_gates[id_v2]) < 0:
			_gates[id_v2] = 0


## The minimum party_max at which a species may be encountered
## (0 = no gate). Unknown species answer 0.
func evolution_gate(species_id: int) -> int:
	load_data()
	return maxi(0, int(_gates.get(species_id, 0)))


func species_id_for_slug(slug: String) -> int:
	load_data()
	return int(_id_by_slug.get(slug.to_lower(), 0))


func species_types(species_id: int) -> Array:
	load_data()
	var rec_v: Variant = _species.get(species_id, {})
	if rec_v is Dictionary:
		var rec: Dictionary = rec_v
		var types_v: Variant = rec.get("types", [])
		if types_v is Array:
			return types_v
	return []


func area_environments(area_id: String) -> Array:
	load_data()
	var envs_v: Variant = _area_envs.get(area_id, [])
	if envs_v is Array:
		return (envs_v as Array).duplicate()
	return []


## True when the species fits at least one of the given environments
## by habitat OR by either of its types.
func species_fits(species_id: int, environments: Array) -> bool:
	load_data()
	var rec_v: Variant = _species.get(species_id, {})
	if not (rec_v is Dictionary):
		return false
	var rec: Dictionary = rec_v
	var habitat_v: Variant = rec.get("habitat", null)
	if habitat_v != null:
		var hab_envs_v: Variant = HABITAT_TO_ENVIRONMENTS.get(str(habitat_v), [])
		if hab_envs_v is Array:
			var hab_envs: Array = hab_envs_v
			for env_v in hab_envs:
				if environments.has(str(env_v)):
					return true
	var types_v: Variant = rec.get("types", [])
	if types_v is Array:
		var types: Array = types_v
		for type_v in types:
			var type_envs_v: Variant = TYPE_TO_ENVIRONMENTS.get(str(type_v).to_lower(), [])
			if type_envs_v is Array:
				var type_envs: Array = type_envs_v
				for env_v2 in type_envs:
					if environments.has(str(env_v2)):
						return true
	return false


## The area's full pool (no gating, no rotation): a flat list of
## {"species": id, "slug": String, "dex_family": "PKDX"|"MDX"}
## entries in national-dex order, PKDX entry first, MDX entry right
## after it when a counterpart exists. NO weights on any entry.
## The pool is the habitat/type-fit species UNION the area's
## source-placed members (see the header ruling).
func build_pool(area_id: String) -> Array:
	load_data()
	if _pool_overrides.has(area_id):
		var override_v: Variant = _pool_overrides[area_id]
		if override_v is Array:
			return (override_v as Array).duplicate(true)
	if _pool_cache.has(area_id):
		var cached_v: Variant = _pool_cache[area_id]
		if cached_v is Array:
			return (cached_v as Array).duplicate(true)
	var envs: Array = area_environments(area_id)
	var member_ids: Dictionary = {}
	var per_env_v: Variant = _source_members.get(area_id, {})
	if per_env_v is Dictionary:
		var per_env: Dictionary = per_env_v
		for env_v in per_env.keys():
			var list_v: Variant = per_env[env_v]
			if list_v is Array:
				var list: Array = list_v
				for sid_v in list:
					member_ids[int(sid_v)] = true
	var pool: Array = []
	if not envs.is_empty() or not member_ids.is_empty():
		var ids: Array = _species.keys()
		ids.sort()
		for id_v in ids:
			var sid: int = int(id_v)
			if not member_ids.has(sid) and not species_fits(sid, envs):
				continue
			var rec: Dictionary = _species[sid]
			var slug: String = str(rec.get("slug", ""))
			pool.append({"species": sid, "slug": slug, "dex_family": "PKDX"})
			if _mdx_slugs.has(slug):
				pool.append({"species": sid, "slug": slug, "dex_family": "MDX"})
	_pool_cache[area_id] = pool.duplicate(true)
	return pool


## Replace an area's pool with a caller-supplied one (tests and
## hand-authored areas). Entries keep the pool entry shape; an entry
## may carry "types" to define rotation sharing for species the
## loaded data does not know.
func set_pool_override(area_id: String, entries: Array) -> void:
	load_data()
	_pool_overrides[area_id] = entries.duplicate(true)
	_pool_cache.erase(area_id)


## The pool after evolution gating at party_max and type rotation.
## terrain (optional, OverworldLoop vocabulary) restricts the pool
## to species fitting that terrain's single environment.
func get_eligible_pool(area_id: String, party_max: int, terrain: String = "") -> Array:
	load_data()
	var pool: Array = build_pool(area_id)
	var env_filter: Array = []
	if terrain != "":
		var env_v: Variant = TERRAIN_TO_ENVIRONMENT.get(terrain, "")
		if str(env_v) != "":
			env_filter = [str(env_v)]
	var encountered: Array = _encountered_ids(area_id)
	var pool_ids: Array = []
	for entry_v in pool:
		if entry_v is Dictionary:
			var eid: int = int((entry_v as Dictionary).get("species", 0))
			if not pool_ids.has(eid):
				pool_ids.append(eid)
	var out: Array = []
	for entry_v2 in pool:
		if not (entry_v2 is Dictionary):
			continue
		var entry: Dictionary = entry_v2
		var sid2: int = int(entry.get("species", 0))
		if evolution_gate(sid2) > party_max:
			continue
		if not env_filter.is_empty() and not species_fits(sid2, env_filter) \
				and not _is_source_member(area_id, sid2, str(env_filter[0])):
			continue
		if _rotation_blocked(area_id, sid2, pool_ids, encountered):
			continue
		out.append(entry)
	return out


func _encountered_ids(area_id: String) -> Array:
	var state_v: Variant = _rotation.get(area_id, {})
	if state_v is Dictionary:
		var state: Dictionary = state_v
		var ids_v: Variant = state.get("encountered", [])
		if ids_v is Array:
			return (ids_v as Array).duplicate()
	return []


func _types_for_rotation(area_id: String, species_id: int) -> Array:
	# A pool override entry may define types for a controlled pool.
	if _pool_overrides.has(area_id):
		var entries_v: Variant = _pool_overrides[area_id]
		if entries_v is Array:
			var entries: Array = entries_v
			for entry_v in entries:
				if entry_v is Dictionary:
					var entry: Dictionary = entry_v
					if int(entry.get("species", 0)) == species_id:
						var types_v: Variant = entry.get("types", [])
						if types_v is Array and not (types_v as Array).is_empty():
							var lowered: Array = []
							for t_v in types_v:
								lowered.append(str(t_v).to_lower())
							return lowered
	var types: Array = species_types(species_id)
	var out: Array = []
	for t_v2 in types:
		out.append(str(t_v2).to_lower())
	return out


## True when species_id has been encountered in the area and at
## least one other pool species sharing one of its types has not.
func _rotation_blocked(area_id: String, species_id: int, pool_ids: Array, encountered: Array) -> bool:
	if not encountered.has(species_id):
		return false
	var my_types: Array = _types_for_rotation(area_id, species_id)
	if my_types.is_empty():
		return false
	for other_v in pool_ids:
		var other: int = int(other_v)
		if other == species_id or encountered.has(other):
			continue
		var other_types: Array = _types_for_rotation(area_id, other)
		for t_v in other_types:
			if my_types.has(str(t_v)):
				return true
	return false


## Direct eligibility check for one species in one area (used by the
## deterministic rotation tests; the roll uses the same rule).
func is_eligible(area_id: String, species_id: int, party_max: int) -> bool:
	var eligible: Array = get_eligible_pool(area_id, party_max)
	for entry_v in eligible:
		if entry_v is Dictionary and int((entry_v as Dictionary).get("species", 0)) == species_id:
			return true
	return false


## Record an encounter: the species rotates to the bottom of its
## type group in this area. Idempotent per species per area.
func mark_encountered(area_id: String, species_id: int) -> void:
	var encountered: Array = _encountered_ids(area_id)
	if not encountered.has(species_id):
		encountered.append(species_id)
	_rotation[area_id] = {"encountered": encountered}


## Roll one habitat encounter: a uniform pick from the eligible pool
## (flat list, equal odds), which is then marked encountered.
## Returns the pool entry plus "species_slug", or {} when nothing is
## eligible. The RESULT is a species only -- level/IVs are the
## difficulty layer's job (PUWTeamBuilder.build_wild_mon).
func roll_habitat_encounter(area_id: String, party_max: int, rng: RandomNumberGenerator, terrain: String = "", has_shiny_charm: bool = false) -> Dictionary:
	load_data()
	var eligible: Array = get_eligible_pool(area_id, party_max, terrain)
	if eligible.is_empty():
		return {}
	var use_rng: RandomNumberGenerator = rng
	if use_rng == null:
		use_rng = RandomNumberGenerator.new()
		use_rng.randomize()
	var idx: int = use_rng.randi_range(0, eligible.size() - 1)
	var entry: Dictionary = (eligible[idx] as Dictionary).duplicate()
	mark_encountered(area_id, int(entry.get("species", 0)))
	entry["species_slug"] = str(entry.get("slug", ""))
	# Shiny determination (ShinyOdds, Gen 6+ canon): base 1/4096,
	# +2 extra rolls when the player holds the Shiny Charm. The
	# roll uses this encounter's own RNG stream, after the species
	# pick, so existing seeded species picks are unchanged.
	entry["shiny"] = ShinyOdds.roll_shiny(use_rng, has_shiny_charm)
	return entry


## Rotation state as a plain Dictionary for a save file.
func get_rotation_state() -> Dictionary:
	var out: Dictionary = {}
	for area_v in _rotation.keys():
		out[str(area_v)] = {"encountered": _encountered_ids(str(area_v))}
	return out


## ------------------------------------------------------------------
## Repel state (item triage top batch, staged by code prep
## code_prep_items). A Repel's own rule (its effect text): for
## its step count, wild encounters of a level LOWER than the
## party lead's level do not happen. The step count comes from
## ItemEngine.repel_steps_for (100/200/250). Levels are rolled
## by the difficulty layer after the species pick, so the level
## test itself is the predicate below, applied where the wild
## level is known; this class owns the counter and the rule.
## ------------------------------------------------------------------

## Start (or extend) a Repel. A fresh Repel used while one is
## active keeps the longer remaining count, never shortens it.
func apply_repel(steps: int) -> void:
	_repel_steps = maxi(_repel_steps, maxi(0, steps))


func repel_steps_remaining() -> int:
	return _repel_steps


func repel_active() -> bool:
	return _repel_steps > 0


## True when an active Repel blocks an encounter of wild_level
## against a lead of lead_level: strictly lower levels only,
## the item's own wording.
func repel_would_block(wild_level: int, lead_level: int) -> bool:
	return _repel_steps > 0 and wild_level < lead_level


## Spend one step of Repel. The overworld loop calls this once
## per player step; at 0 the Repel has worn off.
func tick_repel_step() -> void:
	if _repel_steps > 0:
		_repel_steps -= 1


## Repel state as a plain Dictionary for a save file.
func get_repel_state() -> Dictionary:
	return {"steps": _repel_steps}


## Load Repel state back (from get_repel_state or a save).
func set_repel_state(state: Dictionary) -> void:
	_repel_steps = maxi(0, int(state.get("steps", 0)))


## Store the Repel counter into a save state dict under the
## additive "habitat_repel" key. Returns the dict.
func attach_repel_to_save(state: Dictionary) -> Dictionary:
	state["habitat_repel"] = get_repel_state()
	return state


## Restore the Repel counter from a save state dict. A state
## without the key leaves the counter at 0, never an error.
func restore_repel_from_save(state: Dictionary) -> void:
	var saved_v: Variant = state.get("habitat_repel", {})
	if saved_v is Dictionary:
		set_repel_state(saved_v as Dictionary)
	else:
		_repel_steps = 0


## Load rotation state back (from get_rotation_state or a save).
func set_rotation_state(state: Dictionary) -> void:
	_rotation = {}
	for area_v in state.keys():
		var entry_v: Variant = state[area_v]
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v
			var ids_v: Variant = entry.get("encountered", [])
			if ids_v is Array:
				var ids: Array = []
				for id_v in ids_v:
					ids.append(int(id_v))
				_rotation[str(area_v)] = {"encountered": ids}


## Store this pool builder's rotation state into a save state dict
## under the additive "habitat_rotation" key. Returns the dict.
func attach_rotation_to_save(state: Dictionary) -> Dictionary:
	state[SAVE_KEY] = get_rotation_state()
	return state


## Restore rotation state from a save state dict. A state without
## the key leaves rotation empty (fresh game), never an error.
func restore_rotation_from_save(state: Dictionary) -> void:
	var saved_v: Variant = state.get(SAVE_KEY, {})
	if saved_v is Dictionary:
		set_rotation_state(saved_v as Dictionary)
	else:
		_rotation = {}
