class_name PUWRideSystem
extends RefCounted
## RIDEABLE POKEMON (Riley canon, 2026-11-22, Phase 3 item B).
##
## A partner Pokemon can carry the player in 11 ride modes (the
## mode vocabulary is systems/cast/rider_poses.json, read through
## PUWCastRegistry.ride_mode_ids()). Eligibility for every mode is
## DERIVED from real species data this project holds -- types
## (data/competitive_sets.json, 1,025 species; the 25-species
## master registry takes precedence), weight (data/weight_power
## .json, hectograms, converted to kg), abilities (master
## registry + the ability recorded on competitive sets), level-up
## / full learnsets (data/learnsets_compact.json), PokeAPI habitat
## (data/species_habitats.json) and follower locomotion
## (systems/followers/follower_locomotion.json). MDX (Moemon)
## counterparts share their PKDX counterpart's slug in
## data/mdx_mapping.json, so an MDX entry resolves to the same
## species data and is rideable on exactly the same rules.
##
## ELIGIBILITY RULES (thresholds are PUW DESIGN PARAMETERS -- round
## numbers chosen for this project, stated here and in
## docs/RIDES.md; they are NOT sourced facts):
## - land_riding: weight >= LAND_MIN_KG (50 kg) AND not an
##   aquatic-only species (PokeAPI habitat "sea" or "waters-edge"
##   excludes; species with no recorded habitat are not excluded).
##   50 kg is roughly the smallest body that can carry a rider on
##   its back without the ride being a carry instead.
## - surfing: Water-type AND weight >= SURF_MIN_KG (20 kg -- a
##   surf mount must displace enough water to float a rider;
##   this is what keeps Magikarp, 10 kg, out of every mode).
## - ferrying: Water-type AND weight >= FERRY_MIN_KG (100 kg --
##   the large, placid subset that can ferry a seated passenger;
##   Lapras, 220 kg, qualifies for surfing AND ferrying).
## - diving: Water-type AND qualifies for surfing.
## - mounted_flight: Flying-type or Levitate ability AND weight
##   >= MOUNTED_FLIGHT_MIN_KG (25 kg -- big enough to sit on).
## - carried_flight: Flying-type or Levitate ability AND weight
##   < MOUNTED_FLIGHT_MIN_KG. The split is a hard weight line, so
##   no species is claimed by both flight modes: Pidgey (1.8 kg)
##   is carried_flight only; Charizard (90.5 kg) mounted only.
## - hover_carrying: Levitate ability, OR a hover/float
##   locomotion entry in follower_locomotion.json, OR the explicit
##   canon table CANON_HOVER below (per-entry basis citations).
##   Metagross qualifies through the canon table: Riley named it
##   as the hover-carrier example on 2026-11-22.
## - held_carrying: weight >= HELD_MIN_KG (50 kg, the land line)
##   AND not aquatic-only (same habitat exclusion as land).
##   Machamp (130 kg, mountain habitat) qualifies.
## - climbing_cliff: the species' learnset contains a
##   rock-climb-class move ("rockclimb") or "rocksmash", OR it is
##   Ground/Rock-type with weight >= CLIFF_MIN_KG (20 kg).
## - climbing_waterfall: Water-type AND qualifies for surfing
##   (it climbs the fall while swimming).
## - burrowing: Ground-type OR the learnset contains "dig".
##
## HONEST COVERAGE NOTE: ability data is thin. The master
## registry holds abilities for only 25 curated species and most
## competitive-set records carry no ability, so Levitate-based
## eligibility (hover, and the Levitate branch of flight) only
## resolves for species whose ability is actually recorded
## (e.g. Gastly, Levitate, in the registry). No ability is ever
## invented to widen coverage; the canon table is the documented
## exception path, and each entry carries its basis.
##
## SPEEDS (tiles/sec, PUW design, tied to the movement spec in
## PUWPlayerController: walk 4.0 / run 8.0 / bike 10.67-16.0):
## see SPEEDS below and docs/RIDES.md.
##
## MOUNT STATE: mount() records state["current_mount"] =
## {"species": slug, "mode": mode_id} and mirrors the follower
## line in state["followers"] (an Array of species slugs, the
## same species identity PUWFollowerController records in its
## follower records): a mounted follower leaves the line, and
## dismount() returns it when there is room (max 6, the follower
## controller's MAX_FOLLOWERS). The follower controller itself is
## instance state, not save state, so the save-state follower
## line is modelled here in its shape and documented as such.
##
## BADGE-LOCKED CROSSINGS: riding itself is not a field action.
## Only CROSSINGS are gated, through PUWFieldActions.can_perform
## (see docs/RIDES.md for the crossing -> field-action map).

const SETS_PATH: String = "res://data/competitive_sets.json"
const WEIGHT_PATH: String = "res://data/weight_power.json"
const LEARNSETS_PATH: String = "res://data/learnsets_compact.json"
const HABITATS_PATH: String = "res://data/species_habitats.json"
const EVO_PATH: String = "res://data/evolution_triggers.json"
const REGISTRY_PATH: String = "res://pokemon/registry/master_species_registry.json"
const LOCOMOTION_PATH: String = "res://systems/followers/follower_locomotion.json"

const LAND_MIN_KG: float = 50.0
const SURF_MIN_KG: float = 20.0
const FERRY_MIN_KG: float = 100.0
const MOUNTED_FLIGHT_MIN_KG: float = 25.0
const HELD_MIN_KG: float = 50.0
const CLIFF_MIN_KG: float = 20.0
const MAX_FOLLOWERS: int = 6

## Per-mode speeds in tiles/sec (PUW design; see header).
const SPEEDS: Dictionary = {
	"land_riding": 8.0,
	"surfing": 6.0,
	"ferrying": 5.0,
	"mounted_flight": 12.0,
	"carried_flight": 10.0,
	"diving": 6.0,
	"climbing_cliff": 3.0,
	"climbing_waterfall": 4.0,
	"hover_carrying": 8.0,
	"held_carrying": 4.0,
	"burrowing": 5.0,
}

const WATER_MODES: Array = ["surfing", "ferrying", "diving"]
const AIRBORNE_MODES: Array = ["mounted_flight", "carried_flight", "hover_carrying"]

## Explicit canon table for hover_carrying. Each entry carries
## its basis citation; this is the ONLY place a species is made
## eligible by name rather than by a data rule.
const CANON_HOVER: Dictionary = {
	"metagross": "Riley canon example, 2026-11-22",
}

## Crossing -> field action map (PUW design, docs/RIDES.md).
## "" means no badge gate (plain land riding on open ground).
const CROSSING_ACTIONS: Dictionary = {
	"surfing": "surf",
	"ferrying": "surf",
	"diving": "surf",
	"mounted_flight": "fly",
	"carried_flight": "fly",
	"hover_carrying": "fly",
	"climbing_waterfall": "waterfall",
	"climbing_cliff": "rock_smash",
	"burrowing": "dig",
	"held_carrying": "strength",
	"land_riding": "",
}

static var _loaded: bool = false
static var _types_by_slug: Dictionary = {}
static var _abilities_by_slug: Dictionary = {}
static var _weight_kg_by_slug: Dictionary = {}
static var _habitat_by_slug: Dictionary = {}
static var _learnset_moves_by_slug: Dictionary = {}
static var _locomotion_by_slug: Dictionary = {}
static var _slug_by_dex: Dictionary = {}


static func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func _normalize_slug(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	out = out.replace("♀", "-f").replace("♂", "-m")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var sets: Dictionary = _load_json(SETS_PATH)
	var species_value: Variant = sets.get("species", {})
	if species_value is Dictionary:
		var species: Dictionary = species_value
		for slug_value: Variant in species.keys():
			var entry_value: Variant = species[slug_value]
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var types_value: Variant = entry.get("types", [])
				if types_value is Array:
					var types: Array = types_value
					var clean: Array = []
					for type_value: Variant in types:
						clean.append(str(type_value).capitalize())
					_types_by_slug[str(slug_value)] = clean
				var abilities: Array = []
				for fmt_value: Variant in ["singles", "vgc"]:
					var fmt_rec_value: Variant = entry.get(str(fmt_value), null)
					if fmt_rec_value is Dictionary:
						var fmt_rec: Dictionary = fmt_rec_value
						var ability_name: String = str(fmt_rec.get("ability", ""))
						if ability_name != "" and ability_name != "None" and not abilities.has(ability_name):
							abilities.append(ability_name)
				if not abilities.is_empty():
					_abilities_by_slug[str(slug_value)] = abilities
	var weights: Dictionary = _load_json(WEIGHT_PATH)
	for slug_value: Variant in weights.keys():
		_weight_kg_by_slug[str(slug_value)] = float(int(weights[slug_value])) / 10.0
	var learnsets_data: Dictionary = _load_json(LEARNSETS_PATH)
	var learnsets_value: Variant = learnsets_data.get("learnsets", {})
	if learnsets_value is Dictionary:
		var all_learnsets: Dictionary = learnsets_value
		for slug_value: Variant in all_learnsets.keys():
			var entry_value: Variant = all_learnsets[slug_value]
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var learnset_value: Variant = entry.get("learnset", {})
				if learnset_value is Dictionary:
					var learnset: Dictionary = learnset_value
					var moves: Dictionary = {}
					for move_value: Variant in learnset.keys():
						moves[str(move_value)] = true
					_learnset_moves_by_slug[str(slug_value)] = moves
	var habitats_data: Dictionary = _load_json(HABITATS_PATH)
	var hab_species_value: Variant = habitats_data.get("species", {})
	if hab_species_value is Dictionary:
		var hab_species: Dictionary = hab_species_value
		for dex_value: Variant in hab_species.keys():
			var rec_value: Variant = hab_species[dex_value]
			if rec_value is Dictionary:
				var rec: Dictionary = rec_value
				var slug: String = str(rec.get("slug", ""))
				var habitat_value: Variant = rec.get("habitat", null)
				if slug != "" and habitat_value is String:
					_habitat_by_slug[slug] = str(habitat_value)
	var evo: Dictionary = _load_json(EVO_PATH)
	var rows_value: Variant = evo.get("data", [])
	if rows_value is Array:
		var rows: Array = rows_value
		for row_value: Variant in rows:
			if row_value is Dictionary:
				var row: Dictionary = row_value
				var dex_id: int = int(row.get("id", 0))
				var slug: String = str(row.get("slug", ""))
				if dex_id > 0 and slug != "":
					_slug_by_dex[dex_id] = slug
	var registry: Dictionary = _load_json(REGISTRY_PATH)
	var reg_species_value: Variant = registry.get("species", [])
	if reg_species_value is Array:
		var reg_species: Array = reg_species_value
		for reg_value: Variant in reg_species:
			if reg_value is Dictionary:
				var reg: Dictionary = reg_value
				var slug: String = str(reg.get("species_id", ""))
				if slug == "":
					continue
				var dex_id: int = int(reg.get("nat_dex", 0))
				if dex_id > 0:
					_slug_by_dex[dex_id] = slug
				var types_value: Variant = reg.get("types", [])
				if types_value is Array and not (types_value as Array).is_empty():
					var types: Array = types_value
					var clean: Array = []
					for type_value: Variant in types:
						clean.append(str(type_value).capitalize())
					_types_by_slug[slug] = clean
				var abilities_value: Variant = reg.get("abilities", [])
				if abilities_value is Array:
					var abilities: Array = abilities_value
					var clean_abilities: Array = []
					for ability_value: Variant in abilities:
						clean_abilities.append(str(ability_value))
					if not clean_abilities.is_empty():
						_abilities_by_slug[slug] = clean_abilities
	var loco_data: Dictionary = _load_json(LOCOMOTION_PATH)
	var seed_value: Variant = loco_data.get("pallet_and_route1_seed", [])
	if seed_value is Array:
		var seed: Array = seed_value
		for entry_value: Variant in seed:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var slug: String = str(entry.get("slug", ""))
				if slug != "":
					_locomotion_by_slug[slug] = str(entry.get("locomotion", ""))


# ------------------------------------------------------------------
# Species resolution + raw data access
# ------------------------------------------------------------------

## Resolve a species reference (slug/display String or national
## dex int) to a slug. "" when unresolvable.
static func resolve_slug(species_ref: Variant) -> String:
	_ensure_loaded()
	if species_ref is int or species_ref is float:
		var dex_id: int = int(species_ref)
		if _slug_by_dex.has(dex_id):
			return str(_slug_by_dex[dex_id])
		return ""
	var slug: String = _normalize_slug(str(species_ref))
	return slug


## The slug of a party entry (same resolution PUWFieldActions
## uses: "species", else "name", else dex "species_id"; an "slug"
## key, the follower-controller shape, is also accepted).
static func party_species_slug(pokemon: Dictionary) -> String:
	_ensure_loaded()
	var raw: String = str(pokemon.get("slug", ""))
	if raw == "":
		raw = str(pokemon.get("species", ""))
	if raw == "":
		raw = str(pokemon.get("name", ""))
	if raw != "":
		return _normalize_slug(raw)
	var dex_id: int = int(pokemon.get("species_id", 0))
	if dex_id > 0 and _slug_by_dex.has(dex_id):
		return str(_slug_by_dex[dex_id])
	return ""


static func species_types(slug: String) -> Array:
	_ensure_loaded()
	var value: Variant = _types_by_slug.get(slug, [])
	if value is Array:
		var types: Array = value
		return types.duplicate()
	return []


static func species_abilities(slug: String) -> Array:
	_ensure_loaded()
	var value: Variant = _abilities_by_slug.get(slug, [])
	if value is Array:
		var abilities: Array = value
		return abilities.duplicate()
	return []


## Real weight in kg from data/weight_power.json (hectograms
## / 10). -1.0 when the species has no recorded weight.
static func species_weight_kg(slug: String) -> float:
	_ensure_loaded()
	if _weight_kg_by_slug.has(slug):
		return float(_weight_kg_by_slug[slug])
	return -1.0


static func species_habitat(slug: String) -> String:
	_ensure_loaded()
	return str(_habitat_by_slug.get(slug, ""))

## True when the species' real learnset (data/learnsets_compact.json)
## contains move_id (e.g. "dive", "odorsleuth"). Public wrapper around
## the learnset table the ride rules already load; used by the
## follower sense/domain derivation (FOLLOWER_SENSES.md).
static func species_learns(slug: String, move_id: String) -> bool:
	return _learns(slug, move_id)


## Every species slug with type data (the followable roster).
static func all_species_slugs() -> Array:
	_ensure_loaded()
	var slugs: Array = _types_by_slug.keys()
	slugs.sort()
	return slugs


static func _has_ability(slug: String, ability_name: String) -> bool:
	var abilities: Array = species_abilities(slug)
	for ability_value: Variant in abilities:
		if str(ability_value).to_lower() == ability_name.to_lower():
			return true
	return false


static func _learns(slug: String, move_id: String) -> bool:
	_ensure_loaded()
	var value: Variant = _learnset_moves_by_slug.get(slug, {})
	if value is Dictionary:
		var moves: Dictionary = value
		return moves.has(move_id)
	return false


static func _is_aquatic_only(slug: String) -> bool:
	var habitat: String = species_habitat(slug)
	return habitat == "sea" or habitat == "waters-edge"


static func _can_fly(slug: String) -> bool:
	return species_types(slug).has("Flying") or _has_ability(slug, "levitate")


static func _can_surf(slug: String) -> bool:
	return species_types(slug).has("Water") and species_weight_kg(slug) >= SURF_MIN_KG


# ------------------------------------------------------------------
# Eligibility
# ------------------------------------------------------------------

## True when the species qualifies for one ride mode under the
## documented rules in the header.
static func is_eligible(slug: String, mode_id: String) -> bool:
	_ensure_loaded()
	if slug == "" or not _types_by_slug.has(slug):
		return false
	var types: Array = species_types(slug)
	var weight_kg: float = species_weight_kg(slug)
	match mode_id:
		"land_riding":
			return weight_kg >= LAND_MIN_KG and not _is_aquatic_only(slug)
		"surfing":
			return _can_surf(slug)
		"ferrying":
			return types.has("Water") and weight_kg >= FERRY_MIN_KG
		"diving":
			return types.has("Water") and _can_surf(slug)
		"mounted_flight":
			return _can_fly(slug) and weight_kg >= MOUNTED_FLIGHT_MIN_KG
		"carried_flight":
			return _can_fly(slug) and weight_kg >= 0.0 and weight_kg < MOUNTED_FLIGHT_MIN_KG
		"hover_carrying":
			if CANON_HOVER.has(slug):
				return true
			if _has_ability(slug, "levitate"):
				return true
			var locomotion: String = str(_locomotion_by_slug.get(slug, ""))
			return locomotion.contains("hover") or locomotion.contains("float") or locomotion.contains("levitat")
		"held_carrying":
			return weight_kg >= HELD_MIN_KG and not _is_aquatic_only(slug)
		"climbing_cliff":
			if _learns(slug, "rockclimb") or _learns(slug, "rocksmash"):
				return true
			return (types.has("Ground") or types.has("Rock")) and weight_kg >= CLIFF_MIN_KG
		"climbing_waterfall":
			return types.has("Water") and _can_surf(slug)
		"burrowing":
			return types.has("Ground") or _learns(slug, "dig")
	return false


## Every ride mode a species qualifies for, in rider_poses.json
## mode order. species_ref is a slug String or a dex int.
static func eligible_modes(species_ref: Variant) -> Array:
	var slug: String = resolve_slug(species_ref)
	var out: Array = []
	if slug == "":
		return out
	for mode_value: Variant in PUWCastRegistry.ride_mode_ids():
		var mode_id: String = str(mode_value)
		if is_eligible(slug, mode_id):
			out.append(mode_id)
	return out


## The documented basis for a species' eligibility in a mode:
## "canon: <citation>" for canon-table entries, "data_rule" for
## rule-derived eligibility, "" when not eligible.
static func basis_for(species_ref: Variant, mode_id: String) -> String:
	var slug: String = resolve_slug(species_ref)
	if slug == "" or not is_eligible(slug, mode_id):
		return ""
	if mode_id == "hover_carrying" and CANON_HOVER.has(slug):
		return "canon: " + str(CANON_HOVER[slug])
	return "data_rule"


## Speed in tiles/sec for a ride mode (0.0 for an unknown mode).
static func speed_for_mode(mode_id: String) -> float:
	var speed_value: Variant = SPEEDS.get(mode_id, 0.0)
	return float(speed_value)


static func is_water_mode(mode_id: String) -> bool:
	return WATER_MODES.has(mode_id)


static func is_airborne_mode(mode_id: String) -> bool:
	return AIRBORNE_MODES.has(mode_id)


## The field action a crossing in this mode is gated by (""
## when the mode has no badge gate).
static func crossing_action(mode_id: String) -> String:
	return str(CROSSING_ACTIONS.get(mode_id, ""))


static func _party_has_species(party: Array, slug: String) -> bool:
	for entry_value: Variant in party:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if party_species_slug(entry) == slug:
				return true
	return false


## Can this species be mounted in this mode right now?
## {"allowed", "reason"}: reason "ok", "unknown_species",
## "unknown_mode", "not_in_party", or "not_eligible".
static func can_mount(state: Dictionary, party: Array, species_ref: Variant, mode_id: String) -> Dictionary:
	var slug: String = resolve_slug(species_ref)
	if slug == "" or not _types_by_slug.has(slug):
		return {"allowed": false, "reason": "unknown_species"}
	if not PUWCastRegistry.ride_mode_ids().has(mode_id):
		return {"allowed": false, "reason": "unknown_mode"}
	if not _party_has_species(party, slug):
		return {"allowed": false, "reason": "not_in_party"}
	if not is_eligible(slug, mode_id):
		return {"allowed": false, "reason": "not_eligible"}
	return {"allowed": true, "reason": "ok"}


# ------------------------------------------------------------------
# Pose binding
# ------------------------------------------------------------------

## The rider pose binding for a cast member in a ride mode: the
## mode's primary pose resolved through the cast member's pose
## set, with the honest art status from PUWCastRigLoader.
## {"pose", "pose_set", "art_status", "frame_count"}.
static func pose_binding(cast_id: String, mode_id: String) -> Dictionary:
	var pose_id: String = PUWCastRegistry.pose_for_mode(mode_id)
	if pose_id == "":
		return {"pose": "", "pose_set": "", "art_status": "", "frame_count": 0}
	var built: Dictionary = PUWCastRigLoader.build_rider_frames(cast_id, pose_id)
	return {
		"pose": pose_id,
		"pose_set": str(built.get("pose_set", PUWCastRegistry.pose_set_for_cast(cast_id))),
		"art_status": str(built.get("status", "")),
		"frame_count": int(built.get("frame_count", 0)),
	}


# ------------------------------------------------------------------
# Mount / dismount + follower transition
# ------------------------------------------------------------------

## Mount a party species in a ride mode. On success records
## state["current_mount"], removes the species from the
## state["followers"] line when it was following (follower-to-
## ride transition), and returns {"allowed": true, "reason": "ok",
## "species", "mode", "speed", "pose", "pose_set", "art_status"}.
## The cast used for the pose binding is state["cast_id"] when
## recorded, else cast_id_if_any, else "riley". A refused mount
## changes nothing.
static func mount(state: Dictionary, party: Array, species_ref: Variant, mode_id: String, cast_id_if_any: String = "") -> Dictionary:
	var check: Dictionary = can_mount(state, party, species_ref, mode_id)
	if not bool(check.get("allowed", false)):
		return {"allowed": false, "reason": str(check.get("reason", ""))}
	var slug: String = resolve_slug(species_ref)
	var cast_id: String = cast_id_if_any
	if cast_id == "":
		cast_id = str(state.get("cast_id", ""))
	if cast_id == "":
		cast_id = "riley"
	state["current_mount"] = {"species": slug, "mode": mode_id}
	var followers_value: Variant = state.get("followers", [])
	if followers_value is Array:
		var followers: Array = followers_value
		if followers.has(slug):
			followers.erase(slug)
			state["followers"] = followers
	var binding: Dictionary = pose_binding(cast_id, mode_id)
	return {
		"allowed": true,
		"reason": "ok",
		"species": slug,
		"mode": mode_id,
		"speed": speed_for_mode(mode_id),
		"pose": str(binding.get("pose", "")),
		"pose_set": str(binding.get("pose_set", "")),
		"art_status": str(binding.get("art_status", "")),
		"frame_count": int(binding.get("frame_count", 0)),
	}


## Dismount: clears state["current_mount"] and returns the mount
## to the state["followers"] line when it was following before
## the mount OR when there is room and it is not already there --
## concretely: the species is appended when it is not already a
## follower and the line has fewer than MAX_FOLLOWERS entries.
## Returns {"allowed", "reason", "species", "mode",
## "returned_to_followers"}.
static func dismount(state: Dictionary) -> Dictionary:
	var mount_value: Variant = state.get("current_mount", {})
	if not (mount_value is Dictionary) or (mount_value as Dictionary).is_empty():
		return {"allowed": false, "reason": "not_mounted", "species": "", "mode": "", "returned_to_followers": false}
	var mount_rec: Dictionary = mount_value
	var slug: String = str(mount_rec.get("species", ""))
	var mode_id: String = str(mount_rec.get("mode", ""))
	state.erase("current_mount")
	var returned: bool = false
	var followers_value: Variant = state.get("followers", [])
	var followers: Array = []
	if followers_value is Array:
		var existing: Array = followers_value
		followers = existing
	if slug != "" and not followers.has(slug) and followers.size() < MAX_FOLLOWERS:
		followers.append(slug)
		state["followers"] = followers
		returned = true
	return {"allowed": true, "reason": "ok", "species": slug, "mode": mode_id, "returned_to_followers": returned}


## The current mount record from state ({} when not mounted).
static func current_mount(state: Dictionary) -> Dictionary:
	var mount_value: Variant = state.get("current_mount", {})
	if mount_value is Dictionary:
		var mount_rec: Dictionary = mount_value
		return mount_rec.duplicate()
	return {}


# ------------------------------------------------------------------
# Badge-locked crossings
# ------------------------------------------------------------------

## Attempt a crossing in a ride mode over an obstacle kind
## ("water", "gap", "waterfall", "cliff", "burrow", "obstacle",
## "open_ground" -- the obstacle is descriptive; the gate is
## decided by the mode's crossing action). The crossing is gated
## by PUWFieldActions.can_perform for the mapped action and its
## result is passed through: {"allowed", "reason", "action",
## "via", "species"}. Plain land riding has no action and is
## allowed whenever a party member is eligible for land riding.
## For gated modes the field-action result decides first (so a
## missing badge reports "badge_missing" exactly as the field
## action reports it); when the field action allows, the mount
## side is also checked -- at least one party member must be
## eligible for the ride mode, else "not_rideable_for_mode".
static func attempt_crossing(state: Dictionary, party: Array, mode_id: String, obstacle: String) -> Dictionary:
	if not PUWCastRegistry.ride_mode_ids().has(mode_id):
		return {"allowed": false, "reason": "unknown_mode", "action": "", "via": "", "species": ""}
	var action_id: String = crossing_action(mode_id)
	if action_id == "":
		for entry_value: Variant in party:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var slug: String = party_species_slug(entry)
				if slug != "" and is_eligible(slug, mode_id):
					return {"allowed": true, "reason": "ok", "action": "", "via": "ride", "species": slug}
		return {"allowed": false, "reason": "not_rideable_for_mode", "action": "", "via": "", "species": ""}
	var gate: Dictionary = PUWFieldActions.can_perform(state, party, action_id)
	if not bool(gate.get("allowed", false)):
		return {
			"allowed": false,
			"reason": str(gate.get("reason", "")),
			"action": action_id,
			"via": str(gate.get("via", "")),
			"species": str(gate.get("species", "")),
		}
	for entry_value: Variant in party:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var slug: String = party_species_slug(entry)
			if slug != "" and is_eligible(slug, mode_id):
				return {
					"allowed": true,
					"reason": "ok",
					"action": action_id,
					"via": str(gate.get("via", "")),
					"species": str(gate.get("species", "")),
				}
	return {"allowed": false, "reason": "not_rideable_for_mode", "action": action_id, "via": "", "species": ""}
