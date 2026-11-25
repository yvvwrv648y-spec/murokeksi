class_name PUWFieldActions
extends RefCounted
## BADGE-LOCKED FIELD ACTIONS (Riley canon, 2026-11-22, Phase 3
## item C) -- newest-generation style, NOT classic HMs.
##
## In the newest games there are no HM slaves and no HM items:
## a partner Pokemon simply DOES the thing in the field when it
## is able. PUW keeps that shape and adds Riley's hard rule:
## EVERY field action is also BADGE-LOCKED. A follower/partner
## Pokemon can perform an action only when BOTH axes pass:
##
##   CAPABILITY axis -- the Pokemon either
##     (a) KNOWS the matching move (a real move id from
##         data/move_database_954.json), or
##     (b) has the NATURAL capability for the action (a rule
##         computed from species data this project actually
##         holds: types, abilities, level-up learnsets).
##   BADGE axis -- the player holds the badge that unlocks the
##     action. Without it the action is refused even when a
##     fully qualifying Pokemon is standing right there.
##
## The moves themselves are unchanged: Cut, Flash, Fly, Surf,
## Strength, Teleport, Dig, Rock Smash and Waterfall still exist
## as ordinary battle moves. This system only governs their use
## as field actions. The full rule table, the badge map with its
## sources, and the slicing-move derivation are written down in
## docs/FIELD_ACTIONS.md.
##
## PARTY / FOLLOWER ASSUMPTION (documented, per the brief): the
## follower system (1-6 followers) draws its followers FROM the
## party, so for this system "a follower/partner Pokemon" is any
## member of the party Array the caller passes in. There is no
## separate follower roster in the save state to read.
##
## PARTY REPRESENTATION: this reads the campaign stitch's actual
## party entries (systems/campaign/campaign_stitch.gd builds them
## through CampaignFlow.build_starter): Dictionaries carrying
##   "species_id"  int, the national dex number,
##   "name"        String, the species slug ("bulbasaur"),
##   "types"       Array of type names (may be lowercase),
##   "moves"       Array of {"name": move id, "pp", "max_pp"}
##                 Dictionaries (move ids are Showdown-style,
##                 e.g. "vinewhip").
## Entries in the looser battle shape ({"species": "Pikachu",
## "moves": ["Fly"], "ability": "Levitate"}) are also accepted:
## species resolves from "species"/"name"/"species_id", moves may
## be plain Strings (display names are normalized to move ids),
## and "ability"/"abilities" are read when present. Anything the
## entry itself does not carry (types, abilities) is filled from
## the project's real species data (see DATA below).
##
## BADGE RESOLUTION: state["badges"] holds GYM IDS (the stitch
## awards the gym id as the badge id; see GymProgression.
## award_badge). Each action names its unlocking gym id; the
## badge NAME is resolved from that gym's record in
## data/gym_requirements.json through PUWGymRequirements, never
## hardcoded here.
##
## BADGE MAP (full reasoning in docs/FIELD_ACTIONS.md):
##   source-defined (the Gen 1 games gate the matching HM move
##   behind exactly this badge):
##     illuminate -> Boulder Badge   (Flash,    Pewter)
##     cut        -> Cascade Badge   (Cut,      Cerulean)
##     fly        -> Thunder Badge   (Fly,      Vermilion)
##     strength   -> Rainbow Badge   (Strength, Celadon)
##     surf       -> Soul Badge      (Surf,     Fuchsia)
##   PUW design (no Gen 1 gate exists for these four; assigned to
##   the three remaining Kanto badges by theme):
##     teleport   -> Marsh Badge     (Sabrina's Psychic gym;
##                   Teleport is the Psychic escape move)
##     dig        -> Volcano Badge   ("earth-breaking": digging
##     rock_smash -> Volcano Badge    and rock-breaking are the
##                   same field family, so one badge gates both)
##     waterfall  -> Earth Badge     (the final badge gates the
##                   final traversal class)
##
## DATA (all real, all in-project):
## - data/move_database_954.json: move records; a move's field
##   id is its display name normalized (lowercase, non-alnum
##   stripped: "Rock Smash" -> "rocksmash"). The SLICING move
##   set is exactly the moves whose record carries
##   flags.slicing == 1 -- the Gen 9 Sharpness flag, present in
##   our data on 26 moves.
## - data/learnsets_compact.json: per-species learnsets; a move
##   is a LEVEL-UP move for a species when any of its source
##   codes is a level code ("9L14" style: generation digit(s),
##   "L", level). TM/tutor/egg codes do NOT count for the cut
##   natural rule -- the rule is about the body the species
##   grows, not what it can be taught.
## - data/competitive_sets.json: types for all 1,025 species
##   (keyed by slug). pokemon/registry/master_species_registry
##   .json takes precedence where it has an entry and is also
##   the ability source (it holds only 25 curated species, so
##   ability coverage beyond the party entry's own recorded
##   ability is honestly partial -- see the fly rule).
## - data/evolution_triggers.json: national dex id <-> slug for
##   all 1,025 species (used to resolve "species_id" entries).
## - data/gym_requirements.json (via PUWGymRequirements): gym
##   records carrying the badge names.
##
## CONTROLLER HOOK (WIRED, Worker B): PUWPlayerController
## (systems/overworld/player_controller.gd) now implements
## this hook. Live play binds a save state + party through
## PUWPlayerController.set_field_context(state, party); the
## controller's attempt_field_action(action_id) calls
##   PUWFieldActions.perform(state, party, action_id)
## and proceeds with the traversal change only when the returned
## Dictionary has "allowed" == true; on refusal it surfaces the
## "reason" ("badge_missing" names the badge to earn;
## "no_qualifying_pokemon" means bring a capable partner) as
## its last_block_reason. Ride crossings over water / gap
## terrain through the controller are likewise checked first
## through PUWFieldActions.can_perform for the crossing's
## action (surf-class / fly-class, via
## PUWRideSystem.crossing_action). The gate itself is
## unchanged: the controller calls it, never reimplements it.

const MOVE_DB_PATH: String = "res://data/move_database_954.json"
const LEARNSETS_PATH: String = "res://data/learnsets_compact.json"
const SETS_PATH: String = "res://data/competitive_sets.json"
const EVO_PATH: String = "res://data/evolution_triggers.json"
const REGISTRY_PATH: String = "res://pokemon/registry/master_species_registry.json"

const ACTION_ORDER: Array = [
	"cut", "illuminate", "fly", "surf", "strength",
	"teleport", "dig", "rock_smash", "waterfall",
]

# action_id -> {"move", "gym_id", "badge_source", "natural_rule"}
# "natural_rule" is "" for move-only actions.
const ACTIONS: Dictionary = {
	"cut": {"move": "cut", "gym_id": "kanto_gym_2_misty", "badge_source": "source", "natural_rule": "slicing_learnset"},
	"illuminate": {"move": "flash", "gym_id": "kanto_gym_1_brock", "badge_source": "source", "natural_rule": "illumination_type"},
	"fly": {"move": "fly", "gym_id": "kanto_gym_3_surge", "badge_source": "source", "natural_rule": "flight"},
	"surf": {"move": "surf", "gym_id": "kanto_gym_5_koga", "badge_source": "source", "natural_rule": "water_type"},
	"strength": {"move": "strength", "gym_id": "kanto_gym_4_erika", "badge_source": "source", "natural_rule": ""},
	"teleport": {"move": "teleport", "gym_id": "kanto_gym_6_sabrina", "badge_source": "puw_design", "natural_rule": "psychic_type"},
	"dig": {"move": "dig", "gym_id": "kanto_gym_7_blaine", "badge_source": "puw_design", "natural_rule": "ground_type"},
	"rock_smash": {"move": "rocksmash", "gym_id": "kanto_gym_7_blaine", "badge_source": "puw_design", "natural_rule": ""},
	"waterfall": {"move": "waterfall", "gym_id": "kanto_gym_8_giovanni", "badge_source": "puw_design", "natural_rule": ""},
}

static var _loaded: bool = false
static var _move_ids: Dictionary = {}        # move id -> true
static var _slicing_moves: Dictionary = {}   # move id -> true
static var _learnsets: Dictionary = {}       # slug -> {move id: [codes]}
static var _types_by_slug: Dictionary = {}   # slug -> [type names, capitalized]
static var _abilities_by_slug: Dictionary = {}  # slug -> [ability names]
static var _slug_by_dex: Dictionary = {}     # dex int -> slug
static var _slug_by_norm: Dictionary = {}    # normalized name -> slug


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


static func _normalize_id(raw: String) -> String:
	var out: String = ""
	var lower: String = raw.to_lower()
	for i: int in range(lower.length()):
		var ch: String = lower.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	# Moves + the slicing set (the Gen 9 Sharpness flag in our
	# own move records).
	var move_db: Dictionary = _load_json(MOVE_DB_PATH)
	var moves_value: Variant = move_db.get("moves", {})
	if moves_value is Dictionary:
		var moves: Dictionary = moves_value
		for name_value: Variant in moves.keys():
			var record_value: Variant = moves[name_value]
			if record_value is Dictionary:
				var record: Dictionary = record_value
				var move_id: String = _normalize_id(str(record.get("name", str(name_value))))
				_move_ids[move_id] = true
				var flags_value: Variant = record.get("flags", {})
				if flags_value is Dictionary:
					var flags: Dictionary = flags_value
					if int(flags.get("slicing", 0)) == 1:
						_slicing_moves[move_id] = true
	# Learnsets.
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
					_learnsets[str(slug_value)] = learnset
	# Dex id -> slug (all 1,025).
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
	# Types for all species (competitive sets, keyed by slug).
	var sets: Dictionary = _load_json(SETS_PATH)
	var sets_species_value: Variant = sets.get("species", {})
	if sets_species_value is Dictionary:
		var sets_species: Dictionary = sets_species_value
		for slug_value: Variant in sets_species.keys():
			var entry_value: Variant = sets_species[slug_value]
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var types_value: Variant = entry.get("types", [])
				if types_value is Array:
					var types: Array = types_value
					var clean: Array = []
					for type_value: Variant in types:
						clean.append(str(type_value).capitalize())
					_types_by_slug[str(slug_value)] = clean
	# Master registry takes precedence and carries abilities.
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
					_abilities_by_slug[slug] = clean_abilities
	# Normalized-name -> slug, for display-name species strings.
	for slug_value: Variant in _types_by_slug.keys():
		_slug_by_norm[_normalize_id(str(slug_value))] = str(slug_value)
	for slug_value: Variant in _learnsets.keys():
		if not _slug_by_norm.has(_normalize_id(str(slug_value))):
			_slug_by_norm[_normalize_id(str(slug_value))] = str(slug_value)


# ------------------------------------------------------------------
# Public table lookups
# ------------------------------------------------------------------

## The 9 field action ids, in table order.
static func actions() -> Array:
	return ACTION_ORDER.duplicate()


## True when action_id is one of the 9 field actions.
static func is_action(action_id: String) -> bool:
	return ACTIONS.has(action_id)


## The matching move id for an action ("" for an unknown action).
static func action_move(action_id: String) -> String:
	var record_value: Variant = ACTIONS.get(action_id, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return str(record.get("move", ""))
	return ""


## The natural rule name for an action, or "" when the action is
## move-only (no natural rule is defined for it).
static func natural_rule(action_id: String) -> String:
	var record_value: Variant = ACTIONS.get(action_id, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return str(record.get("natural_rule", ""))
	return ""


## Whether the action's badge gate is "source" (the Gen 1 games
## define it) or "puw_design" (assigned by PUW, documented).
static func badge_source(action_id: String) -> String:
	var record_value: Variant = ACTIONS.get(action_id, {})
	if record_value is Dictionary:
		var record: Dictionary = record_value
		return str(record.get("badge_source", ""))
	return ""


## The badge that unlocks an action, resolved through the gym
## records: {"gym_id", "badge", "source"}. An unknown action
## returns {}.
static func required_badge(action_id: String) -> Dictionary:
	var record_value: Variant = ACTIONS.get(action_id, {})
	if not (record_value is Dictionary):
		return {}
	var record: Dictionary = record_value
	var gym_id: String = str(record.get("gym_id", ""))
	var gym_record: Dictionary = PUWGymRequirements.record_for(gym_id)
	return {
		"gym_id": gym_id,
		"badge": str(gym_record.get("badge", "")),
		"source": str(record.get("badge_source", "")),
	}


## True when the player holds the badge that unlocks the action.
## Badges in state["badges"] are gym ids (see the header).
static func has_required_badge(state: Dictionary, action_id: String) -> bool:
	var badge: Dictionary = required_badge(action_id)
	if badge.is_empty():
		return false
	var badges_value: Variant = state.get("badges", [])
	if badges_value is Array:
		var badges: Array = badges_value
		return badges.has(str(badge.get("gym_id", "")))
	return false


## The derived SLICING move set: exactly the move ids whose
## record in data/move_database_954.json carries flags.slicing
## == 1 (the Gen 9 Sharpness flag), sorted.
static func slicing_moves() -> Array:
	_ensure_loaded()
	var out: Array = _slicing_moves.keys()
	out.sort()
	return out


## True when move_id is a real move in our 954-move data.
static func move_exists(move_id: String) -> bool:
	_ensure_loaded()
	return _move_ids.has(move_id)


# ------------------------------------------------------------------
# Species / party-entry resolution
# ------------------------------------------------------------------

## The species slug for a party entry: "species" (slug or display
## name), else "name", else the national dex "species_id"
## resolved through the real roster data. "" when unresolvable.
static func species_slug(pokemon: Dictionary) -> String:
	_ensure_loaded()
	var raw: String = str(pokemon.get("species", ""))
	if raw == "":
		raw = str(pokemon.get("name", ""))
	if raw != "":
		var lower: String = raw.to_lower()
		if _types_by_slug.has(lower) or _learnsets.has(lower):
			return lower
		var norm: String = _normalize_id(raw)
		if _slug_by_norm.has(norm):
			return str(_slug_by_norm[norm])
		return lower
	var dex_id: int = int(pokemon.get("species_id", 0))
	if dex_id > 0 and _slug_by_dex.has(dex_id):
		return str(_slug_by_dex[dex_id])
	return ""


## The species' types (capitalized names): the party entry's own
## "types" when it carries them, else the real species data.
static func species_types(pokemon: Dictionary) -> Array:
	_ensure_loaded()
	var own_value: Variant = pokemon.get("types", [])
	if own_value is Array and not (own_value as Array).is_empty():
		var own: Array = own_value
		var clean: Array = []
		for type_value: Variant in own:
			clean.append(str(type_value).capitalize())
		return clean
	var slug: String = species_slug(pokemon)
	var data_value: Variant = _types_by_slug.get(slug, [])
	if data_value is Array:
		var data_types: Array = data_value
		return data_types.duplicate()
	return []


## The species' ability names: the entry's own "ability" /
## "abilities" when recorded, else the master registry's list
## for the species (registry coverage is 25 curated species, so
## this can honestly come back empty for other species).
static func species_abilities(pokemon: Dictionary) -> Array:
	_ensure_loaded()
	var out: Array = []
	var single: String = str(pokemon.get("ability", ""))
	if single != "":
		out.append(single)
	var many_value: Variant = pokemon.get("abilities", [])
	if many_value is Array:
		var many: Array = many_value
		for ability_value: Variant in many:
			var ability_name: String = str(ability_value)
			if not out.has(ability_name):
				out.append(ability_name)
	if not out.is_empty():
		return out
	var slug: String = species_slug(pokemon)
	var data_value: Variant = _abilities_by_slug.get(slug, [])
	if data_value is Array:
		var data_abilities: Array = data_value
		return data_abilities.duplicate()
	return []


## The move ids a party entry KNOWS: its "moves" list, whose
## entries are {"name": id} Dictionaries (the stitch shape) or
## plain Strings (display names are normalized to ids).
static func known_move_ids(pokemon: Dictionary) -> Array:
	var out: Array = []
	var moves_value: Variant = pokemon.get("moves", [])
	if moves_value is Array:
		var moves: Array = moves_value
		for move_value: Variant in moves:
			if move_value is Dictionary:
				var move_entry: Dictionary = move_value
				var move_id: String = _normalize_id(str(move_entry.get("name", "")))
				if move_id != "":
					out.append(move_id)
			elif move_value is String:
				var move_id: String = _normalize_id(str(move_value))
				if move_id != "":
					out.append(move_id)
	return out


static func _is_levelup_code(code: String) -> bool:
	# Showdown learnset source codes: "<gen>L<level>" for level-up
	# (e.g. "9L14"), "<gen>M" TM, "<gen>T" tutor, "<gen>E" egg.
	var l_pos: int = code.find("L")
	if l_pos <= 0:
		return false
	var gen_part: String = code.substr(0, l_pos)
	var level_part: String = code.substr(l_pos + 1)
	return gen_part.is_valid_int() and level_part.is_valid_int()


## The slicing moves in a species' LEVEL-UP learnset (real data:
## learnsets_compact.json intersected with the slicing flag set
## from move_database_954.json), sorted.
static func levelup_slicing_moves(slug: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	var learnset_value: Variant = _learnsets.get(slug, {})
	if learnset_value is Dictionary:
		var learnset: Dictionary = learnset_value
		for move_value: Variant in learnset.keys():
			var move_id: String = str(move_value)
			if not _slicing_moves.has(move_id):
				continue
			var codes_value: Variant = learnset[move_value]
			if codes_value is Array:
				var codes: Array = codes_value
				for code_value: Variant in codes:
					if _is_levelup_code(str(code_value)):
						out.append(move_id)
						break
	out.sort()
	return out


# ------------------------------------------------------------------
# Capability
# ------------------------------------------------------------------

static func _natural_qualifies(pokemon: Dictionary, action_id: String) -> bool:
	var rule: String = natural_rule(action_id)
	if rule == "":
		return false
	var types: Array = species_types(pokemon)
	match rule:
		"illumination_type":
			# Any Electric-type or Fire-type follower gives off
			# light of its own (Riley's rule, Phase 3 item C).
			return types.has("Electric") or types.has("Fire")
		"slicing_learnset":
			# Body-based: the species grows a blade -- at least
			# one slicing move in its LEVEL-UP learnset.
			return not levelup_slicing_moves(species_slug(pokemon)).is_empty()
		"flight":
			if types.has("Flying"):
				return true
			var abilities: Array = species_abilities(pokemon)
			for ability_value: Variant in abilities:
				if str(ability_value).to_lower() == "levitate":
					return true
			return false
		"water_type":
			return types.has("Water")
		"psychic_type":
			return types.has("Psychic")
		"ground_type":
			return types.has("Ground")
	return false


## Every path by which ONE party entry qualifies for an action:
## a list of {"path": "move", "move": move id} and/or
## {"path": "natural", "rule": rule name} Dictionaries. An empty
## list means this Pokemon cannot perform the action. (The badge
## axis is NOT checked here -- it is a player axis, checked by
## can_perform.)
static func qualifying_paths(pokemon: Dictionary, action_id: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	if not ACTIONS.has(action_id):
		return out
	var move_id: String = action_move(action_id)
	var known: Array = known_move_ids(pokemon)
	if move_id != "" and known.has(move_id):
		out.append({"path": "move", "move": move_id})
	var rule: String = natural_rule(action_id)
	if rule != "" and _natural_qualifies(pokemon, action_id):
		out.append({"path": "natural", "rule": rule})
	return out


# ------------------------------------------------------------------
# The gate
# ------------------------------------------------------------------

## Can any party member perform the action right now?
## Returns {"allowed", "reason", "via", "species"}:
##   reason "ok"                     -- allowed; "via" is "move"
##     or "natural" (the move path is reported first when a
##     Pokemon qualifies both ways) and "species" is the slug of
##     the first qualifying party member.
##   reason "badge_missing"          -- the unlocking badge is
##     not held. Checked FIRST: the badge axis is independent of
##     capability, so this is the answer even with a qualifying
##     Pokemon in the party.
##   reason "no_qualifying_pokemon"  -- badge held, but no party
##     member knows the move or has the natural capability.
##   reason "unknown_action"         -- not one of the 9 actions.
static func can_perform(state: Dictionary, party: Array, action_id: String) -> Dictionary:
	if not ACTIONS.has(action_id):
		return {"allowed": false, "reason": "unknown_action", "via": "", "species": ""}
	if not has_required_badge(state, action_id):
		return {"allowed": false, "reason": "badge_missing", "via": "", "species": ""}
	for entry_value: Variant in party:
		if entry_value is Dictionary:
			var pokemon: Dictionary = entry_value
			var paths: Array = qualifying_paths(pokemon, action_id)
			if not paths.is_empty():
				var first_value: Variant = paths[0]
				var first: Dictionary = first_value
				return {
					"allowed": true,
					"reason": "ok",
					"via": str(first.get("path", "")),
					"species": species_slug(pokemon),
				}
	return {"allowed": false, "reason": "no_qualifying_pokemon", "via": "", "species": ""}


## Perform the action: runs can_perform and, ONLY when allowed,
## records the use by appending the action id to
## state["story_flags"]["field_actions_used"]. A refused attempt
## records nothing. Returns the same Dictionary as can_perform.
static func perform(state: Dictionary, party: Array, action_id: String) -> Dictionary:
	var result: Dictionary = can_perform(state, party, action_id)
	if not bool(result.get("allowed", false)):
		return result
	var flags_value: Variant = state.get("story_flags", {})
	var flags: Dictionary = {}
	if flags_value is Dictionary:
		var existing_flags: Dictionary = flags_value
		flags = existing_flags
	var used_value: Variant = flags.get("field_actions_used", [])
	var used: Array = []
	if used_value is Array:
		var existing_used: Array = used_value
		used = existing_used
	used.append(action_id)
	flags["field_actions_used"] = used
	state["story_flags"] = flags
	return result


## Transport wrapper (Worker C, Part A, 2026-11-23): runs the
## UNCHANGED perform() gate; when a teleport-class action is
## allowed, the follower controller transports the whole team
## to the destination (followers land in their formation
## slots under the controller's placement rules). A refused
## action transports nobody. The gate's refusal logic above
## is untouched.
static func perform_transport(state: Dictionary, party: Array, action_id: String, controller: PUWFollowerController, dest_trainer_pos: Vector2, facing: String) -> Dictionary:
	var result: Dictionary = perform(state, party, action_id)
	if not bool(result.get("allowed", false)):
		return result
	if controller != null and PUWFollowerController.TRANSPORT_ACTIONS.has(action_id):
		result["followers_arrived"] = controller.transport_followers_to(dest_trainer_pos, facing).size()
	else:
		result["followers_arrived"] = 0
	return result
