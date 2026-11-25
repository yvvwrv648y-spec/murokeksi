class_name PUWTeamBuilder
extends RefCounted
## Difficulty layer: builds competitive 6-mon trainer teams and maxed
## wild mons from real data only.
##
## Data sources (all real, all in-project):
## - res://data/competitive_sets.json — extracted from the Smogon
##   gen1-9 sets file by tools/build_competitive_sets.py. Per species:
##   types + PokeAPI base stats, the best singles set (gen9 OU, else
##   latest earlier-gen OU, else the in-project curated set) and the
##   best gen9 VGC set (or null when the data has none).
## - res://data/evolution_triggers.json — PokeAPI evolution rows, used
##   for auto-evolve (level-up rows only; trade/item/happiness rows are
##   NOT guessed at — a species whose next form needs one of those
##   stays in its current form, documented here honestly).
## - LearnsetResolver (res://data/learnsets_compact.json) — fallback
##   moves for species with NO Smogon set (see _build_mon).
## - res://systems/progression/trainer_6mon_rosters.json — gym leader
##   rosters, already 6 mons; build_roster_team() uses them
##   directly. That file also holds the World Coronation finale
##   Leon roster as STORED ENDGAME DATA ONLY (Riley canon
##   2026-11-22): Leon is never placed in any Kanto map, gym, or
##   the Kanto Elite Four flow; Kanto's champion is the dynamic
##   rival-story Champion/Runner-Up.
##   directly so a named trainer's species are never invented.
##
## Rules enforced (Riley's difficulty rules + lead decision):
## - Opponent level = player_max_level clamped 1..100
##   (PUWCompetitiveScalingEngine.scale_opponent_level).
## - Wild level = player_max + rng 1..3, clamped 100 (scale_wild_level).
## - IVs are 31 in every stat on every built mon.
## - EV total is capped at 510 (official Gen 9, confirmed by Riley
##   2026-11-22). Smogon sets are legal by construction; if a sourced
##   spread ever exceeds 510, _cap_evs() deterministically trims EVs
##   from the stat with the smallest nonzero EV (ties broken by the
##   fixed stat order hp, atk, def, spa, spd, spe) until total <= 510.
## - Species are auto-evolved to the highest form reachable by a
##   level-up row at the built level.
##
## Fill rule for short base parties (build_trainer_team): the base
## species come first, in order. Remaining slots are filled with
## species that share a type with any base species, taken from the
## competitive_sets dex data (the only in-project species pool with
## sourced types), shuffled with the caller's rng (deterministic for
## a seeded rng) and never repeating a species already on the team.
## No species is ever invented; if the shared-type pool runs out the
## team is returned short rather than padded with fabrications.
##
## SAFETY RULE (defect S1, Kanto trainer completeness prep,
## 2026-11-24): a fill candidate that builds with ZERO moves is
## never dealt. The fill probe-builds each candidate; a zero-move
## candidate is skipped for the next candidate and the skip is
## recorded in last_fill_skips (and push_warning). A short team is
## honest; a moveless mon is a broken battle. Base-party species
## are the trainer's own sourced party and are not subject to the
## skip — the rule guards the fill, which is where unvetted pool
## species enter a team.

const SETS_PATH: String = "res://data/competitive_sets.json"
const EVO_PATH: String = "res://data/evolution_triggers.json"
const ROSTERS_PATH: String = "res://systems/progression/trainer_6mon_rosters.json"
const EV_BUDGET: int = 510
const STAT_KEYS: Array = ["hp", "atk", "def", "spa", "spd", "spe"]

## The 12 healing moves stripped by NO_HEALING_OR_MOVES, verbatim
## from core/competitive_scaling_engine.gd HEALING_MOVES.
const HEALING_MOVES: Array = ["Roost", "Recover", "Synthesis", "Soft-Boiled", "Moonlight", "Morning Sun", "Slack Off", "Strength Sap", "Giga Drain", "Drain Punch", "Wish", "Protect"]

## The 5 challenge mode ids (master_rules / competitive_scaling).
const CHALLENGE_MODES: Array = ["STANDARD_MAX_DIFFICULTY", "NO_TRAINER_ITEMS", "NO_ITEMS_UNIVERSAL", "NO_HEALING_ITEMS", "NO_HEALING_OR_MOVES"]

## Nature table: nature -> [plus_stat, minus_stat] ("" = neutral).
const NATURES: Dictionary = {
	"Hardy": ["", ""], "Lonely": ["atk", "def"], "Brave": ["atk", "spe"],
	"Adamant": ["atk", "spa"], "Naughty": ["atk", "spd"],
	"Bold": ["def", "atk"], "Docile": ["", ""], "Relaxed": ["def", "spe"],
	"Impish": ["def", "spa"], "Lax": ["def", "spd"],
	"Timid": ["spe", "atk"], "Hasty": ["spe", "def"], "Serious": ["", ""],
	"Jolly": ["spe", "spa"], "Naive": ["spe", "spd"],
	"Modest": ["spa", "atk"], "Mild": ["spa", "def"], "Quiet": ["spa", "spe"],
	"Rash": ["spa", "spd"], "Bashful": ["", ""],
	"Calm": ["spd", "atk"], "Gentle": ["spd", "def"], "Sassy": ["spd", "spe"],
	"Careful": ["spd", "spa"], "Quirky": ["", ""],
}

var _species: Dictionary = {}
var _evo_rows: Dictionary = {}
var _loaded: bool = false
var _learnsets: LearnsetResolver = null
var _move_db: MoveDatabase = null

## Fill candidates skipped by the most recent build_trainer_team
## call under the zero-move safety rule: one Dictionary per skip,
## {"slug": String, "evolved_slug": String, "reason": "zero_moves"}.
## Reset at the start of every build_trainer_team call.
var last_fill_skips: Array = []


func _ensure_loaded() -> bool:
	if _loaded:
		return true
	if FileAccess.file_exists(SETS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETS_PATH))
		if parsed is Dictionary:
			var data: Dictionary = parsed
			var sp: Variant = data.get("species", {})
			if sp is Dictionary:
				_species = sp
	if FileAccess.file_exists(EVO_PATH):
		var parsed2: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVO_PATH))
		if parsed2 is Dictionary:
			var rows: Variant = (parsed2 as Dictionary).get("data", [])
			if rows is Array:
				for row_v in rows:
					if row_v is Dictionary:
						var row: Dictionary = row_v
						_evo_rows[str(row.get("slug", ""))] = row
	_loaded = true
	return not _species.is_empty()


func is_loaded() -> bool:
	return _ensure_loaded()


static func slugify(text: String) -> String:
	var out: String = text.strip_edges().to_lower().replace("♀", "f").replace("♂", "m")
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9"):
			clean += ch
	return clean


## Display name for a slug: the competitive_sets "species" field when
## present (sourced name), else the slug with its first letter raised.
func display_name(slug: String) -> String:
	_ensure_loaded()
	var entry: Dictionary = _species.get(slug, {})
	var sourced: String = str(entry.get("species", ""))
	if not sourced.is_empty():
		return sourced.substr(0, 1).to_upper() + sourced.substr(1)
	if slug.is_empty():
		return ""
	return slug.substr(0, 1).to_upper() + slug.substr(1)


func species_entry(slug: String) -> Dictionary:
	_ensure_loaded()
	var entry: Variant = _species.get(slug, {})
	if entry is Dictionary:
		return entry
	return {}


func species_types(slug: String) -> Array:
	var entry: Dictionary = species_entry(slug)
	var types: Variant = entry.get("types", [])
	if types is Array:
		return types
	return []


## Highest form reachable from slug by level-up evolution rows whose
## min_level <= level. Mirrors PUWCompetitiveScalingEngine's
## resolve_evolved_species idea over the real triggers data. Only
## "level-up" rows with a concrete min_level are followed: trade,
## item and happiness evolutions are never guessed.
func resolve_evolved_species(slug: String, level: int) -> String:
	_ensure_loaded()
	var current: String = slug
	var guard: int = 0
	while guard < 10:
		guard += 1
		var row: Variant = _evo_rows.get(current, {})
		if not (row is Dictionary):
			break
		var options: Variant = (row as Dictionary).get("evolves_to", [])
		if not (options is Array):
			break
		var next_slug: String = ""
		for opt_v in options:
			if opt_v is Dictionary:
				var opt: Dictionary = opt_v
				if str(opt.get("trigger", "")) == "level-up" and opt.get("min_level") != null:
					if level >= int(opt.get("min_level", 999)):
						next_slug = str(opt.get("to_slug", ""))
						break
		if next_slug.is_empty() or next_slug == current:
			break
		current = next_slug
	return current


## Deterministic 510 cap: trim from the smallest nonzero EV stat
## (ties: fixed STAT_KEYS order) until the total fits.
static func cap_evs(evs_in: Dictionary) -> Dictionary:
	var evs: Dictionary = {}
	var total: int = 0
	for key in STAT_KEYS:
		var v: int = int(evs_in.get(key, 0))
		if v > 0:
			evs[key] = v
			total += v
	while total > EV_BUDGET:
		var smallest_key: String = ""
		var smallest_val: int = 999999
		for key in STAT_KEYS:
			var v2: int = int(evs.get(key, 0))
			if v2 > 0 and v2 < smallest_val:
				smallest_val = v2
				smallest_key = key
		if smallest_key.is_empty():
			break
		var cut: int = mini(smallest_val, total - EV_BUDGET)
		evs[smallest_key] = smallest_val - cut
		if int(evs[smallest_key]) <= 0:
			evs.erase(smallest_key)
		total -= cut
	return evs


static func ev_total(evs: Dictionary) -> int:
	var total: int = 0
	for key in STAT_KEYS:
		total += int(evs.get(key, 0))
	return total


## One engine-ready mon dict (same shape battle_tests.gd uses:
## name/species/level/hp/max_hp/atk/def/spa/spd/spe/types/ability/
## item/status/moves/stages, plus ivs/evs/nature/species_slug/shiny).
## mode "vgc" prefers the species' VGC set; anything else prefers its
## singles set; when the preferred set is missing the other one is
## used. When the species has NO Smogon set at all, the documented
## fallback is: moves = the species' level-up learnset moves at this
## level (newest first, up to 4, from LearnsetResolver real data),
## EVs = {} (0 total — no spread is invented), nature/ability/item
## empty. IVs are still 31 (Riley's maxed rule is a game rule, not
## set data).
func build_mon(species_in: String, level: int, mode: String, auto_evolve: bool = true) -> Dictionary:
	_ensure_loaded()
	var slug: String = slugify(species_in)
	var final_slug: String = resolve_evolved_species(slug, level) if auto_evolve else slug
	var entry: Dictionary = species_entry(final_slug)
	var set_data: Dictionary = {}
	if mode == "vgc":
		var v: Variant = entry.get("vgc", null)
		if v is Dictionary:
			set_data = v
		if set_data.is_empty():
			var s2: Variant = entry.get("singles", null)
			if s2 is Dictionary:
				set_data = s2
	else:
		var s3: Variant = entry.get("singles", null)
		if s3 is Dictionary:
			set_data = s3
		if set_data.is_empty():
			var v2: Variant = entry.get("vgc", null)
			if v2 is Dictionary:
				set_data = v2
	var nature: String = str(set_data.get("nature", ""))
	var evs: Dictionary = cap_evs(set_data.get("evs", {}))
	var moves: Array = []
	var raw_moves: Variant = set_data.get("moves", [])
	if raw_moves is Array:
		for m in raw_moves:
			moves.append(str(m))
	var used_fallback: bool = false
	if moves.is_empty():
		used_fallback = true
		moves = _learnset_fallback_moves(final_slug, level)
	var ivs: Dictionary = {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31}
	var base: Dictionary = entry.get("base_stats", {})
	var stats: Dictionary = _compute_stats(base, ivs, evs, level, nature)
	var disp: String = display_name(final_slug)
	var mon: Dictionary = {
		"name": disp, "species": disp, "species_slug": final_slug,
		"level": level, "hp": int(stats.get("hp", 100)), "max_hp": int(stats.get("hp", 100)),
		"atk": int(stats.get("atk", 50)), "def": int(stats.get("def", 50)),
		"spa": int(stats.get("spa", 50)), "spd": int(stats.get("spd", 50)),
		"spe": int(stats.get("spe", 50)),
		"types": species_types(final_slug),
		"ability": str(set_data.get("ability", "")), "item": str(set_data.get("item", "")),
		"status": "", "moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
		"ivs": ivs, "evs": evs, "nature": nature, "shiny": false,
		"set_format": str(set_data.get("format", "learnset_fallback" if used_fallback else "")),
		"set_source": "learnset_fallback" if used_fallback else "smogon",
	}
	return mon


func _compute_stats(base: Dictionary, ivs: Dictionary, evs: Dictionary, level: int, nature: String) -> Dictionary:
	var out: Dictionary = {}
	var mods: Array = NATURES.get(nature, ["", ""])
	for key in STAT_KEYS:
		var bs: int = int(base.get(key, 50))
		var iv: int = int(ivs.get(key, 31))
		var ev: int = int(evs.get(key, 0))
		var core: int = int(floor((2.0 * float(bs) + float(iv) + floor(float(ev) / 4.0)) * float(level) / 100.0))
		if key == "hp":
			out[key] = core + level + 10
		else:
			var val: float = float(core + 5)
			if str(mods[0]) == key:
				val = floor(val * 1.1)
			elif str(mods[1]) == key:
				val = floor(val * 0.9)
			out[key] = int(val)
	return out


func _learnset_fallback_moves(slug: String, level: int) -> Array:
	if _learnsets == null:
		_learnsets = LearnsetResolver.new()
	var names: Array = _learnsets.moves_learned_by_level(display_name(slug), level)
	var out: Array = []
	for n in names:
		out.append(str(n))
		if out.size() >= 4:
			break
	return out


## Exactly-6 trainer team from a base party (slugs or display names,
## in party order). See the header for the honest fill rule.
func build_trainer_team(base_species: Array, player_max_level: int, mode: String, rng: RandomNumberGenerator) -> Array:
	_ensure_loaded()
	last_fill_skips = []
	var prebuilt: Dictionary = {}
	var level: int = PUWCompetitiveScalingEngine.scale_opponent_level(player_max_level)
	var chosen: Array = []
	var used: Dictionary = {}
	for raw in base_species:
		var slug: String = slugify(str(raw))
		var evolved: String = resolve_evolved_species(slug, level)
		if not used.has(evolved):
			used[evolved] = true
			chosen.append(slug)
		if chosen.size() >= 6:
			break
	if chosen.size() < 6:
		# Shared-type pool from the dex data in competitive_sets.json.
		var theme_types: Dictionary = {}
		for raw2 in base_species:
			for t in species_types(resolve_evolved_species(slugify(str(raw2)), level)):
				theme_types[str(t).to_lower()] = true
		var pool: Array = []
		for slug_v in _species.keys():
			var slug2: String = str(slug_v)
			var evolved2: String = resolve_evolved_species(slug2, level)
			if used.has(evolved2):
				continue
			for t2 in species_types(slug2):
				if theme_types.has(str(t2).to_lower()):
					pool.append(slug2)
					break
		pool.sort()
		# Deterministic Fisher-Yates with the caller's rng.
		var use_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
		var i: int = pool.size() - 1
		while i > 0:
			var j: int = use_rng.randi_range(0, i)
			var tmp: Variant = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
			i -= 1
		for slug3 in pool:
			if chosen.size() >= 6:
				break
			var evolved3: String = resolve_evolved_species(str(slug3), level)
			if used.has(evolved3):
				continue
			# SAFETY RULE (defect S1): probe-build the candidate.
			# A zero-move build is skipped for the next candidate
			# and logged in last_fill_skips — never dealt.
			var probe: Dictionary = build_mon(str(slug3), level, mode)
			var probe_moves: Variant = probe.get("moves", [])
			if not (probe_moves is Array) or (probe_moves as Array).is_empty():
				last_fill_skips.append({"slug": str(slug3), "evolved_slug": evolved3, "reason": "zero_moves"})
				push_warning("PUWTeamBuilder: fill candidate '" + str(slug3) + "' builds with zero moves; skipped.")
				continue
			used[evolved3] = true
			chosen.append(str(slug3))
			prebuilt[str(slug3)] = probe
	var team: Array = []
	for slug4 in chosen:
		if prebuilt.has(str(slug4)):
			team.append(prebuilt[str(slug4)])
		else:
			team.append(build_mon(str(slug4), level, mode))
	return team


## A named roster team (gym leaders; the Coronation Leon
## roster is stored endgame data, not a Kanto placement) straight from
## trainer_6mon_rosters.json: the roster's own species, rebuilt as
## competitive mons at the scaled level. roster_id matches the
## roster "id" (e.g. "kanto_gym_1_brock"). Returns [] for unknown id.
func build_roster_team(roster_id: String, player_max_level: int, mode: String) -> Array:
	if not FileAccess.file_exists(ROSTERS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTERS_PATH))
	if not (parsed is Dictionary):
		return []
	var lists: Variant = (parsed as Dictionary).get("gyms_and_coronation", [])
	if not (lists is Array):
		return []
	for entry_v in lists:
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v
			if str(entry.get("id", "")) == roster_id:
				var base: Array = []
				var party: Variant = entry.get("party", [])
				if party is Array:
					for mon_v in party:
						if mon_v is Dictionary:
							base.append(str((mon_v as Dictionary).get("species", "")))
				var level: int = PUWCompetitiveScalingEngine.scale_opponent_level(player_max_level)
				var team: Array = []
				for slug in base:
					team.append(build_mon(str(slug), level, mode))
				return team
	return []


## The 8 gym level bands, in roster order, read from the roster
## file itself: band i is the [min lv, max lv] span of the i-th
## Kanto gym's sourced party (Brock 12-14 first, Giovanni 48-50
## last). These are the bands for GLOBAL badge counts 0..7 in the
## gym-scaling rule (Riley canon, 2026-11-22 14:46 CST): whichever
## gym is fought at a given global badge count uses that count's
## band, wherever the gym is. The Coronation Leon roster is not a
## badge gym and contributes no band. Returns an Array of
## {"gym_id": String, "low": int, "high": int}.
func gym_level_bands() -> Array:
	var bands: Array = []
	if not FileAccess.file_exists(ROSTERS_PATH):
		return bands
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTERS_PATH))
	if not (parsed is Dictionary):
		return bands
	var lists: Variant = (parsed as Dictionary).get("gyms_and_coronation", [])
	if not (lists is Array):
		return bands
	for entry_v in lists:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var gym_id: String = str(entry.get("id", ""))
		if not gym_id.begins_with("kanto_gym_"):
			continue
		var low: int = 0
		var high: int = 0
		var party: Variant = entry.get("party", [])
		if party is Array:
			for mon_v in party:
				if mon_v is Dictionary:
					var lv: int = int((mon_v as Dictionary).get("lv", 0))
					if lv > 0:
						if low == 0 or lv < low:
							low = lv
						if lv > high:
							high = lv
		bands.append({"gym_id": gym_id, "low": low, "high": high})
	return bands


## A gym leader team under GYM SCALING (Riley canon, 2026-11-22
## 14:46-14:56 CST): the leader keeps their identity -- the exact
## roster species, in roster order, with the sets build_mon sources
## for those species -- but their LEVELS follow the player's
## current GLOBAL badge count. The band is
## gym_level_bands()[min(badge_count, 7)], and each mon keeps its
## position inside the band the same way the roster assigns it:
## a mon's level is the target band's low plus the mon's own
## offset above its home band's low (every sourced band spans 3
## levels, so offsets carry over exactly). Gym teams are built
## with auto-evolve OFF: a leader's roster species are their
## identity and are never evolved away by the scaling rule.
## badge_count is the GLOBAL count (GymProgression.badge_count) --
## a badge from any region moves the band; availability of the
## gym itself is a separate axis (PUWGymRequirements).
## Returns [] for an unknown roster id.
func build_gym_team(roster_id: String, badge_count: int, mode: String) -> Array:
	if not FileAccess.file_exists(ROSTERS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTERS_PATH))
	if not (parsed is Dictionary):
		return []
	var lists: Variant = (parsed as Dictionary).get("gyms_and_coronation", [])
	if not (lists is Array):
		return []
	var bands: Array = gym_level_bands()
	if bands.is_empty():
		return []
	var band_index: int = clampi(badge_count, 0, bands.size() - 1)
	var band: Dictionary = bands[band_index]
	var band_low: int = int(band.get("low", 1))
	for entry_v in lists:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		if str(entry.get("id", "")) != roster_id:
			continue
		var party: Variant = entry.get("party", [])
		if not (party is Array):
			return []
		var own_low: int = 0
		for mon_v in party:
			if mon_v is Dictionary:
				var own_lv: int = int((mon_v as Dictionary).get("lv", 0))
				if own_lv > 0 and (own_low == 0 or own_lv < own_low):
					own_low = own_lv
		if own_low == 0:
			own_low = band_low
		var team: Array = []
		for mon_v2 in party:
			if mon_v2 is Dictionary:
				var mon_entry: Dictionary = mon_v2
				var own_lv2: int = int(mon_entry.get("lv", own_low))
				var level: int = clampi(band_low + (own_lv2 - own_low), 1, 100)
				team.append(build_mon(str(mon_entry.get("species", "")), level, mode, false))
		return team
	return []


## Maxed wild mon: level = player_max + rng 1..3 clamped 100.
func build_wild_mon(species_in: String, player_max_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var use_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var offset: int = use_rng.randi_range(1, 3)
	var level: int = PUWCompetitiveScalingEngine.scale_wild_level(player_max_level, offset)
	var mon: Dictionary = build_mon(species_in, level, "singles")
	mon["wild"] = true
	return mon


## Apply one of the 5 master-rules challenge modes to a built team.
## Returns a NEW team (deep copies); the input is never changed.
## - STANDARD_MAX_DIFFICULTY: unchanged.
## - NO_TRAINER_ITEMS: every held item removed (these are trainer
##   teams; the mode's own name scopes it to trainers).
## - NO_ITEMS_UNIVERSAL: every held item removed.
## - NO_HEALING_ITEMS: healing held items removed (Leftovers and
##   Sitrus Berry — the healing items present in the engine's item
##   data); other items stay.
## - NO_HEALING_OR_MOVES: each of the 12 HEALING_MOVES is removed.
##   Replacement order (real data only): (1) the species' sourced
##   set alternate for that slot (move_alternates in
##   competitive_sets.json), (2) the strongest damaging move in the
##   species' learnset per LearnsetResolver + the move database,
##   (3) if neither exists the slot is left empty (moves array
##   shrinks) — documented, never filled with an invented move.
func apply_challenge_mode(team: Array, mode_id: String) -> Array:
	var out: Array = []
	for entry_v in team:
		if entry_v is Dictionary:
			out.append((entry_v as Dictionary).duplicate(true))
	match mode_id:
		"STANDARD_MAX_DIFFICULTY":
			pass
		"NO_TRAINER_ITEMS", "NO_ITEMS_UNIVERSAL":
			for mon_v in out:
				(mon_v as Dictionary)["item"] = ""
		"NO_HEALING_ITEMS":
			for mon_v in out:
				var mon: Dictionary = mon_v
				if str(mon.get("item", "")) in ["Leftovers", "Sitrus Berry"]:
					mon["item"] = ""
		"NO_HEALING_OR_MOVES":
			for mon_v in out:
				var mon2: Dictionary = mon_v
				mon2["moves"] = _strip_healing_moves(mon2)
		_:
			push_warning("PUWTeamBuilder: unknown challenge mode '" + mode_id + "', team returned unchanged.")
	return out


func _strip_healing_moves(mon: Dictionary) -> Array:
	var slug: String = str(mon.get("species_slug", slugify(str(mon.get("species", "")))))
	var entry: Dictionary = species_entry(resolve_evolved_species(slug, int(mon.get("level", 50))))
	var mode: String = "vgc" if str(mon.get("set_format", "")).begins_with("vgc") else "singles"
	var set_data: Variant = entry.get(mode, {})
	var alternates: Array = []
	if set_data is Dictionary:
		var alt: Variant = (set_data as Dictionary).get("move_alternates", [])
		if alt is Array:
			alternates = alt
	var moves: Array = mon.get("moves", [])
	var out: Array = []
	for idx in range(moves.size()):
		var mv: String = str(moves[idx])
		if mv in HEALING_MOVES:
			var replacement: String = ""
			if idx < alternates.size() and alternates[idx] is Array:
				for cand_v in alternates[idx]:
					var cand: String = str(cand_v)
					if not (cand in HEALING_MOVES) and not (cand in out) and not (cand in moves):
						replacement = cand
						break
			if replacement.is_empty():
				replacement = _strongest_learnset_damaging_move(slug, moves, out)
			if not replacement.is_empty():
				out.append(replacement)
			# else: slot left empty on purpose (documented in header).
		else:
			out.append(mv)
	return out


func _strongest_learnset_damaging_move(slug: String, current_moves: Array, already_out: Array) -> String:
	if _learnsets == null:
		_learnsets = LearnsetResolver.new()
	if _move_db == null:
		_move_db = MoveDatabase.new()
		_move_db.load_database()
	var all_moves: Array = _learnsets.get_all_moves(display_name(slug))
	var best: String = ""
	var best_power: int = 0
	for name_v in all_moves:
		var name: String = str(name_v)
		if name in HEALING_MOVES or name in current_moves or name in already_out:
			continue
		var md: Dictionary = _move_db.get_move(name)
		var power: int = int(md.get("power", 0))
		if power > best_power:
			best_power = power
			best = name
	return best
