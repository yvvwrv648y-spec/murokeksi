class_name CampaignFlow
extends RefCounted
## Campaign state, game start, starter selection, and rival triggers
## for Pokemon Ultimate World.
##
## All species and move data comes from data files (starters.json,
## built from PokeAPI stats + Showdown learnsets). This script holds
## rules and state only; it hardcodes no story text and no parties.
##
## Party members are plain Dictionaries in the same shape the battle
## engine uses: {species_id, name, level, types, base_stats, hp,
## max_hp, status, moves: [{name, pp, max_pp}]}.
##
## STARTER SYSTEM (Riley ruling 2026-11-23 22:53 CST;
## STARTER_SYSTEM_SPEC.md): a CUSTOM character starts with no
## Pokemon and receives TWO Oak grants (build_oak_grant /
## grant_oak_picks below) chosen from campaign/oak_pool.json with
## builds resolved at bind time in campaign/oak_builds.json. The
## Kanto-trio picker (build_starter / choose_starter) is
## SUPERSEDED for custom characters and unreachable from the
## custom new-game path; the fixed protagonists (riley / tasha)
## bypass both pickers and receive their verified six-Pokemon
## records by direct grant in PUWCampaignStitch.

const STARTER_LEVEL: int = 5

## Nature -> [boosted stat, cut stat] ("" = neutral). Same table
## shape PUWTeamBuilder uses for its stat computation.
const NATURE_EFFECTS: Dictionary = {
	"Adamant": ["atk", "spa"], "Brave": ["atk", "spe"],
	"Lonely": ["atk", "def"], "Naughty": ["atk", "spd"],
	"Bold": ["def", "atk"], "Impish": ["def", "spa"],
	"Lax": ["def", "spd"], "Relaxed": ["def", "spe"],
	"Modest": ["spa", "atk"], "Mild": ["spa", "def"],
	"Quiet": ["spa", "spe"], "Rash": ["spa", "spd"],
	"Calm": ["spd", "atk"], "Careful": ["spd", "spa"],
	"Gentle": ["spd", "def"], "Sassy": ["spd", "spe"],
	"Hasty": ["spe", "def"], "Jolly": ["spe", "spa"],
	"Naive": ["spe", "spd"], "Timid": ["spe", "atk"],
}


## A fresh campaign state dictionary.
static func new_game_state(player_name: String) -> Dictionary:
	return {
		"player_name": player_name,
		"badges": [],
		"flags": {},
		"party": [],
		"hall_of_fame": [],
		"e4_run": {},
		"started": true,
	}


## Find one starter entry in starters.json data by species id.
static func find_starter(starters_data: Dictionary, species_id: int) -> Dictionary:
	var starters: Array = starters_data.get("starters", [])
	for entry: Variant in starters:
		var e: Dictionary = entry
		if int(e.get("species_id", -1)) == species_id:
			return e
	return {}


## Build a level-5 party member from a starters.json entry.
## Stats use the standard stat formula with IV 0 and EV 0 (a fresh
## starter before any training); max HP = floor((2 * base * level)
## / 100) + level + 10.
## SUPERSEDED for custom characters by the Oak grant builder
## (build_oak_grant below) per STARTER_SYSTEM_SPEC.md C3: kept as
## the legacy trio-picker builder; do not re-wire it into any
## new-game path.
static func build_starter(entry: Dictionary) -> Dictionary:
	var level: int = int(entry.get("level", STARTER_LEVEL))
	var base_stats: Dictionary = entry.get("base_stats", {})
	var base_hp: int = int(base_stats.get("hp", 0))
	var max_hp: int = int(floor(float(2 * base_hp * level) / 100.0)) + level + 10
	var moves: Array = []
	var move_entries: Array = entry.get("moves_at_level_5", [])
	for m: Variant in move_entries:
		var md: Dictionary = m
		var pp: int = int(md.get("pp", 0))
		moves.append({"name": str(md.get("name", "")), "pp": pp, "max_pp": pp})
	return {
		"species_id": int(entry.get("species_id", 0)),
		"name": str(entry.get("name", "")),
		"level": level,
		"types": entry.get("types", []),
		"base_stats": base_stats,
		"hp": max_hp,
		"max_hp": max_hp,
		"status": "",
		"moves": moves,
	}


## Give the player their starter. Returns the new party member, or an
## empty Dictionary if the species is not a starter or a starter was
## already chosen.
## SUPERSEDED for custom characters (STARTER_SYSTEM_SPEC.md C3):
## the custom new-game path calls grant_oak_picks instead. Kept
## for the legacy trio data and its unit tests.
static func choose_starter(state: Dictionary, starters_data: Dictionary, species_id: int) -> Dictionary:
	var flags: Dictionary = state.get("flags", {})
	if bool(flags.get("starter_chosen", false)):
		return {}
	var entry: Dictionary = find_starter(starters_data, species_id)
	if entry.is_empty():
		return {}
	var mon: Dictionary = build_starter(entry)
	var party: Array = state.get("party", [])
	party.append(mon)
	state["party"] = party
	flags["starter_chosen"] = true
	flags["starter_species_id"] = species_id
	state["flags"] = flags
	return mon


## The rival picks the starter with a type edge over the player's:
## fire beats grass, water beats fire, grass beats water. Decided
## from the starters' own type data, not a hardcoded species list.
## Returns the rival's species id, or 0 if it cannot be decided.
## RETIRED (STARTER_SYSTEM_SPEC.md C4): no player picks a Kanto
## trio member anymore, so there is no trio pick to counter.
## Story rival encounters use the other protagonist's scaling
## table (campaign/scaling_tables.json, encountered variant).
## Left in place, marked retired, until the story-binding lane
## removes its callers; do not extend it.
static func rival_starter_for(starters_data: Dictionary, player_species_id: int) -> int:
	var beats: Dictionary = {"fire": "grass", "water": "fire", "grass": "water"}
	var player_entry: Dictionary = find_starter(starters_data, player_species_id)
	if player_entry.is_empty():
		return 0
	var player_types: Array = player_entry.get("types", [])
	if player_types.is_empty():
		return 0
	var player_type: String = str(player_types[0]).to_lower()
	var starters: Array = starters_data.get("starters", [])
	for entry: Variant in starters:
		var e: Dictionary = entry
		var types: Array = e.get("types", [])
		if types.is_empty():
			continue
		var t: String = str(types[0]).to_lower()
		if str(beats.get(t, "")) == player_type:
			return int(e.get("species_id", 0))
	return 0


## Data-driven story/rival trigger check. A trigger is a Dictionary:
## {id, required_flags: [...], forbidden_flags: [...],
##  min_badges: int}. Returns true when every requirement is met and
## the trigger has not already fired (firing is recorded under
## "fired_<id>" so a trigger fires once unless its data says
## otherwise by omitting the record step in the caller).
static func should_trigger(state: Dictionary, trigger: Dictionary) -> bool:
	var flags: Dictionary = state.get("flags", {})
	var trigger_id: String = str(trigger.get("id", ""))
	if trigger_id == "":
		return false
	if bool(flags.get("fired_" + trigger_id, false)):
		return false
	var required: Array = trigger.get("required_flags", [])
	for f: Variant in required:
		if not bool(flags.get(str(f), false)):
			return false
	var forbidden: Array = trigger.get("forbidden_flags", [])
	for f2: Variant in forbidden:
		if bool(flags.get(str(f2), false)):
			return false
	var badges: Array = state.get("badges", [])
	if badges.size() < int(trigger.get("min_badges", 0)):
		return false
	return true


## Record that a trigger fired so should_trigger will not repeat it.
static func mark_triggered(state: Dictionary, trigger_id: String) -> void:
	var flags: Dictionary = state.get("flags", {})
	flags["fired_" + trigger_id] = true
	state["flags"] = flags


# ------------------------------------------------------------------
# Oak grants (STARTER_SYSTEM_SPEC.md sections 1-3; changes C1/C2/C7)
# ------------------------------------------------------------------

## One computed stat at a level, standard formula (the same one
## PUWTeamBuilder._compute_stats uses): HP adds level + 10, other
## stats add 5 and take the nature multiplier.
static func _oak_stat(base: int, iv: int, ev: int, level: int, nature: String, key: String) -> int:
	var core: int = int(floor((2.0 * float(base) + float(iv) + floor(float(ev) / 4.0)) * float(level) / 100.0))
	if key == "hp":
		return core + level + 10
	var val: float = float(core + 5)
	var mods_value: Variant = NATURE_EFFECTS.get(nature, ["", ""])
	if mods_value is Array:
		var mods: Array = mods_value
		if mods.size() == 2:
			if str(mods[0]) == key:
				val = floor(val * 1.1)
			elif str(mods[1]) == key:
				val = floor(val * 0.9)
	return int(val)


## C1: build one Oak grant -- a Level 5 party member in the
## starter shape extended with the competitive fields (nature,
## ability, ability_slot, ivs, evs, held_item) exactly as the
## verified protagonist records carry them, plus the computed
## battle stats. pool_entry is one campaign/oak_pool.json entry;
## variant is "pokemon" or "moemon"; build_data is the species'
## resolved build from campaign/oak_builds.json (computed at
## bind time by the section 3.6 pass -- the game never derives
## tiers at runtime). The Moemon variant is an art/form choice
## (family "MDX"), never a mechanical one: same build, same
## moveset. Oak grants hold no item (spec section 3.7).
static func build_oak_grant(pool_entry: Dictionary, variant: String, build_data: Dictionary) -> Dictionary:
	var species_id: int = int(pool_entry.get("species_id", 0))
	var slug: String = str(pool_entry.get("name", ""))
	var level: int = STARTER_LEVEL
	var base_stats: Dictionary = build_data.get("base_stats", {})
	var ivs: Dictionary = build_data.get("ivs", {})
	var evs: Dictionary = build_data.get("evs", {})
	var nature: String = str(build_data.get("nature", ""))
	var stats: Dictionary = {}
	for key_value: Variant in ["hp", "atk", "def", "spa", "spd", "spe"]:
		var key: String = str(key_value)
		stats[key] = _oak_stat(int(base_stats.get(key, 0)), int(ivs.get(key, 31)), int(evs.get(key, 0)), level, nature, key)
	var moves: Array = []
	var move_entries: Array = build_data.get("moves", [])
	for m: Variant in move_entries:
		var md: Dictionary = m
		var pp: int = int(md.get("pp", 0))
		moves.append({"name": str(md.get("name", "")), "pp": pp, "max_pp": pp})
	return {
		"species_id": species_id,
		"name": slug,
		"species_slug": slug,
		"level": level,
		"types": build_data.get("types", []),
		"base_stats": base_stats,
		"hp": int(stats.get("hp", 0)),
		"max_hp": int(stats.get("hp", 0)),
		"atk": int(stats.get("atk", 0)),
		"def": int(stats.get("def", 0)),
		"spa": int(stats.get("spa", 0)),
		"spd": int(stats.get("spd", 0)),
		"spe": int(stats.get("spe", 0)),
		"status": "",
		"moves": moves,
		"nature": nature,
		"ability": str(build_data.get("ability", "")),
		"ability_slot": str(build_data.get("ability_slot", "regular")),
		"ivs": ivs,
		"evs": evs,
		"held_item": "",
		"family": "MDX" if variant == "moemon" else "PKDX",
		"build_tier": int(build_data.get("resolved_tier", build_data.get("tier", 0))),
	}


## C2: grant a custom character their two Oak picks. pick_1 /
## pick_2 are {species_id: int, variant: "pokemon"|"moemon"}.
## pool_data is {pool: [...], builds: {...}} assembled by the
## caller from campaign/oak_pool.json + campaign/oak_builds.json.
## Validates: the Oak flow has not already run, the party is
## empty (a custom character starts with NO Pokemon), both
## picks are in the pool, the two picks are DIFFERENT species
## (spec section 1.2 rule), and each variant is legal for its
## pick (moemon only where the pool entry offers it). Builds
## both grants before touching the state: any refusal returns
## an empty Array with the state untouched -- partial grants
## are impossible. On success the section 1.3 flags are set,
## including the legacy starter_chosen flag (starter_species_id
## is NOT set: it names a trio pick and nothing may read it as
## one).
static func grant_oak_picks(state: Dictionary, pool_data: Dictionary, pick_1: Dictionary, pick_2: Dictionary) -> Array:
	var flags: Dictionary = state.get("flags", {})
	if bool(flags.get("oak_picks_done", false)):
		return []
	var party: Array = state.get("party", [])
	if not party.is_empty():
		return []
	var id_1: int = int(pick_1.get("species_id", 0))
	var id_2: int = int(pick_2.get("species_id", 0))
	if id_1 <= 0 or id_2 <= 0 or id_1 == id_2:
		return []
	var pool_entries: Array = pool_data.get("pool", [])
	var builds_value: Variant = pool_data.get("builds", {})
	if not (builds_value is Dictionary):
		return []
	var builds: Dictionary = builds_value
	var entry_1: Dictionary = {}
	var entry_2: Dictionary = {}
	for entry_value: Variant in pool_entries:
		var e: Dictionary = entry_value
		if int(e.get("species_id", -1)) == id_1:
			entry_1 = e
		if int(e.get("species_id", -1)) == id_2:
			entry_2 = e
	if entry_1.is_empty() or entry_2.is_empty():
		return []
	var variant_1: String = str(pick_1.get("variant", "pokemon"))
	var variant_2: String = str(pick_2.get("variant", "pokemon"))
	if not _oak_variant_legal(entry_1, variant_1) or not _oak_variant_legal(entry_2, variant_2):
		return []
	var build_1_value: Variant = builds.get(str(entry_1.get("name", "")), {})
	var build_2_value: Variant = builds.get(str(entry_2.get("name", "")), {})
	if not (build_1_value is Dictionary) or not (build_2_value is Dictionary):
		return []
	var build_1: Dictionary = build_1_value
	var build_2: Dictionary = build_2_value
	if build_1.is_empty() or build_2.is_empty():
		return []
	var mon_1: Dictionary = build_oak_grant(entry_1, variant_1, build_1)
	var mon_2: Dictionary = build_oak_grant(entry_2, variant_2, build_2)
	party.append(mon_1)
	party.append(mon_2)
	state["party"] = party
	flags["oak_picks_done"] = true
	flags["oak_pick_1_species_id"] = id_1
	flags["oak_pick_2_species_id"] = id_2
	flags["oak_pick_1_variant"] = variant_1
	flags["oak_pick_2_variant"] = variant_2
	flags["starter_chosen"] = true
	state["flags"] = flags
	return [mon_1, mon_2]


## A pick's variant is legal when it is "pokemon" (always), or
## "moemon" where the pool entry's Moemon variant is ready
## (both its MDX battle front and follower set bound).
static func _oak_variant_legal(pool_entry: Dictionary, variant: String) -> bool:
	if variant == "pokemon":
		return true
	if variant == "moemon":
		var variants_value: Variant = pool_entry.get("variants", {})
		if variants_value is Dictionary:
			var variants: Dictionary = variants_value
			return bool(variants.get("moemon", false))
	return false


## C7 world gate: Pallet Town's exits and Route 1 access for a
## custom character require the Oak flow to be complete. Fixed
## protagonists never pass through here (their grants complete
## during their intros); world code checks this for custom
## characters in the same flag style should_trigger uses.
static func oak_gate_open(state: Dictionary) -> bool:
	var flags: Dictionary = state.get("flags", {})
	return bool(flags.get("oak_picks_done", false))
