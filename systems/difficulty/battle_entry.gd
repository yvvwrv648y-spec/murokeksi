class_name PUWBattleEntry
extends RefCounted
## BATTLE ENTRY WIRING — the missing consumer half of the difficulty
## layer (DIFFICULTY_WIRING_AUDIT §5, closure items B1–B8).
##
## The difficulty layer (PUWTeamBuilder) is built and correct, but
## before this file it had ZERO production callers for opponents:
## no live trainer-battle path routed through it, and the one live
## wild hand-off was a hardcoded placeholder. This class is the
## single door every opponent party must walk through:
##
##   identity (species/class/roster/tier/roll — data, never builds)
##     -> PUWTeamBuilder build at battle time
##     -> MDX stamping where the identity says Moemon (B8)
##     -> hand_off() validation guard (B5/B9 runtime half)
##     -> BattleScene / BattleController.start_battle
##
## Raw stored parties (trainers.json classes, roster lv fields,
## rematch tier rows) NEVER reach a battle: they are identity
## inputs only, and every function here returns BUILT mons or an
## error. A battle with no buildable identity is REFUSED
## ({ok: false}) — a built party or no battle (B5).
##
## Canon enforced (Riley 2026-11-23 23:10–23:15 CST + rulings
## D4/D5): every trainer challenge fields 6 Pokémon at the best
## competitive standard (best sourced sets, IV 31, EV <= 510,
## egg moves carried by the sourced sets), opponents level and
## evolve with the player, re-challenge under the same standard,
## applying identically to Pokémon (PKDX) and Moemon (MDX).
## VEXA-internal simulation is the ONLY exception, and it already
## builds through the layer (PUWVexaSimulator); it is registered
## in EXEMPT_ENTRY_POINTS so the guard test can assert the list
## stays exactly that long.

const TRAINERS_PATH: String = "res://data/trainers.json"
const JOHTO_TRAINERS_PATH: String = "res://data/johto/trainers.json"
const RIVAL_PATH: String = "res://data/rival.json"
const ELITE_FOUR_PATH: String = "res://data/elite_four.json"
const GYM_LEADERS_PATH: String = "res://data/gym_leaders.json"
const ROSTERS_PATH: String = "res://systems/progression/trainer_6mon_rosters.json"

const FAMILY_PKDX: String = "PKDX"
const FAMILY_MDX: String = "MDX"

## Every opponent entry point this wiring provides (B9 walks it).
const ENTRY_POINTS: Array = [
	"route_trainer", "gym", "rival", "elite_four", "roster",
	"scripted", "rematch", "habitat_wild",
]

## The complete list of battle paths exempt from this wiring.
## Canon: VEXA-internal content only. The guard test asserts
## this list never grows without a canon ruling.
const EXEMPT_ENTRY_POINTS: Array = ["vexa_simulation"]

## Johto Elite Four / Champion roster ids in
## trainer_6mon_rosters.json, by member id (the Kanto members of
## the same names resolve through data/elite_four.json instead;
## see start_elite_four_battle's context parameter).
const JOHTO_ROSTER_BY_MEMBER: Dictionary = {
	"WILL": "johto_elite_1_will",
	"KOGA": "johto_elite_2_koga",
	"BRUNO": "johto_elite_3_bruno",
	"KAREN": "johto_elite_4_karen",
	"LANCE": "johto_champion_lance",
}

var _builder: PUWTeamBuilder = null
var _mdx: PUWMDXData = null
var _json_cache: Dictionary = {}


# ----------------------------------------------------------------
# Shared pieces
# ----------------------------------------------------------------

func builder() -> PUWTeamBuilder:
	if _builder == null:
		_builder = PUWTeamBuilder.new()
	return _builder


func _mdx_data() -> PUWMDXData:
	if _mdx == null:
		_mdx = PUWMDXData.new()
	return _mdx


func _load_json(path: String) -> Dictionary:
	if _json_cache.has(path):
		var cached: Variant = _json_cache[path]
		if cached is Dictionary:
			return cached
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
	_json_cache[path] = out
	return out


## Player max level from a party of built/caught mon dicts
## (the level every opponent build keys off). 1 for an empty
## party — callers with no party have no battle to start.
static func player_max_level(player_party: Array) -> int:
	var best: int = 0
	for mon_v in player_party:
		if mon_v is Dictionary:
			var lv: int = int((mon_v as Dictionary).get("level", 0))
			if lv > best:
				best = lv
	return maxi(best, 1)


## B8 — the Moemon stamping rule. A built mon whose source
## identity is MDX passes through PUWMDXData.build_mdx_mon:
## family becomes "MDX", the build (stats/IVs/EVs/set) is
## byte-identical to its PKDX build. PKDX mons are stamped
## "PKDX" explicitly so the family is never ambiguous in a
## battle party.
func stamp_family(mon: Dictionary, family: String) -> Dictionary:
	if family == FAMILY_MDX:
		return _mdx_data().build_mdx_mon(mon)
	var out: Dictionary = mon.duplicate(true)
	out["family"] = FAMILY_PKDX
	return out


## Normalize a caller identity list into [{species, dex_family}].
## Entries may be plain species names (PKDX) or dicts carrying
## "species" plus "dex_family"/"family". Source level/iv fields
## on dict entries are IGNORED here — identity is species and
## family only; levels and builds come from the layer.
static func normalize_identity(raw_list: Array) -> Array:
	var out: Array = []
	for entry_v in raw_list:
		if entry_v is Dictionary:
			var entry: Dictionary = entry_v
			var species: String = str(entry.get("species", ""))
			if species.is_empty():
				continue
			var family: String = str(entry.get("dex_family", entry.get("family", FAMILY_PKDX)))
			out.append({"species": species, "dex_family": family})
		else:
			var name_text: String = str(entry_v)
			if not name_text.is_empty():
				out.append({"species": name_text, "dex_family": FAMILY_PKDX})
	return out


## Apply B8 to a built team: identity slugs are resolved at the
## team's build level (so an evolved form still matches its base
## identity), and any built mon whose resolved identity is MDX
## is stamped. Fill species added by the builder's shared-type
## rule have no MDX identity and stay PKDX.
func _apply_families(team: Array, identity: Array, build_level: int) -> Array:
	var b: PUWTeamBuilder = builder()
	var family_by_slug: Dictionary = {}
	for entry_v in identity:
		var entry: Dictionary = entry_v
		var slug: String = PUWTeamBuilder.slugify(str(entry.get("species", "")))
		var resolved: String = b.resolve_evolved_species(slug, build_level)
		family_by_slug[resolved] = str(entry.get("dex_family", FAMILY_PKDX))
	var out: Array = []
	for mon_v in team:
		var mon: Dictionary = mon_v
		var slug2: String = str(mon.get("species_slug", ""))
		out.append(stamp_family(mon, str(family_by_slug.get(slug2, FAMILY_PKDX))))
	return out


## Build a trainer-shaped team from an identity list and finish
## it: family stamping (B8), then the challenge mode when one is
## active. Returns [] when the identity is empty — callers turn
## that into a refusal, never a raw battle.
func _build_from_identity(identity: Array, player_max_level: int, mode: String, rng: RandomNumberGenerator, challenge_mode: String) -> Array:
	if identity.is_empty():
		return []
	var b: PUWTeamBuilder = builder()
	var names: Array = []
	for entry_v in identity:
		names.append(str((entry_v as Dictionary).get("species", "")))
	var team: Array = b.build_trainer_team(names, player_max_level, mode, rng)
	var level: int = PUWCompetitiveScalingEngine.scale_opponent_level(player_max_level)
	team = _apply_families(team, identity, level)
	if not challenge_mode.is_empty() and challenge_mode != "STANDARD_MAX_DIFFICULTY":
		team = b.apply_challenge_mode(team, challenge_mode)
	return team


func _result(kind: String, team: Array, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"ok": not team.is_empty(),
		"kind": kind,
		"enemy_party": team,
		"error": "" if not team.is_empty() else "no buildable identity for entry '" + kind + "' — battle refused (a built party or no battle)",
	}
	for key in extra.keys():
		out[key] = extra[key]
	return out


# ----------------------------------------------------------------
# B1 — Route trainers: spawner trigger -> identity -> build.
# ----------------------------------------------------------------

## The base identity (species + family, party order) for one
## trainer class party from the trainer data files. Source
## levels are dropped here: they are provenance, not a build.
## source is "kanto" (data/trainers.json) or "johto"
## (data/johto/trainers.json) — the B1 loader for the Johto
## file the spawner never read.
## party_index is the PLACEMENT convention: 1-based (placement
## party_index N selects parties[N-1]). Proven from the data:
## both files' placements run 1..len(parties) — 51 Kanto
## placements carry party_index == len(parties), which is only
## valid 1-based; neither file has a real 0 placement.
func trainer_base_identity(trainer_class: String, party_index: int, source: String = "kanto") -> Array:
	var path: String = JOHTO_TRAINERS_PATH if source == "johto" else TRAINERS_PATH
	var data: Dictionary = _load_json(path)
	var classes_v: Variant = data.get("classes", {})
	if not (classes_v is Dictionary):
		return []
	var class_v: Variant = (classes_v as Dictionary).get(trainer_class, {})
	if not (class_v is Dictionary):
		return []
	var parties_v: Variant = (class_v as Dictionary).get("parties", [])
	if not (parties_v is Array):
		return []
	var parties: Array = parties_v
	var idx: int = party_index - 1
	if idx < 0 or idx >= parties.size():
		return []
	var raw_party_v: Variant = parties[idx]
	if not (raw_party_v is Array):
		return []
	return normalize_identity(raw_party_v)


## B1 entry. trigger is a PUWSpawner trainer dict (as built by
## PUWSpawner.trainer_dict_from_placement: trainer_class +
## party_index), optionally carrying "source" ("kanto"/"johto").
## The raw classes party NEVER reaches the battle: only its
## species list does, as build_trainer_team input.
func start_route_trainer_battle(trigger: Dictionary, player_max_level: int, mode: String, rng: RandomNumberGenerator, challenge_mode: String = "") -> Dictionary:
	var trainer_class: String = str(trigger.get("trainer_class", ""))
	var party_index: int = int(trigger.get("party_index", 0))
	var source: String = str(trigger.get("source", "kanto"))
	var identity: Array = trainer_base_identity(trainer_class, party_index, source)
	var team: Array = _build_from_identity(identity, player_max_level, mode, rng, challenge_mode)
	return _result("route_trainer", team, {
		"trainer_class": trainer_class, "party_index": party_index, "source": source,
	})


# ----------------------------------------------------------------
# B2 — Gyms: identity from gym data, levels from global bands.
# ----------------------------------------------------------------

func _load_json_array(path: String) -> Array:
	var cache_key: String = path + "#array"
	if _json_cache.has(cache_key):
		var cached: Variant = _json_cache[cache_key]
		if cached is Array:
			return cached
	var out: Array = []
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			out = parsed
	_json_cache[cache_key] = out
	return out


## Resolve a gym reference (roster id, leader class, or leader
## display name) to a roster id in trainer_6mon_rosters.json.
## gym_leaders.json is in badge order and the roster ids are
## numbered in the same order, so the fallback is positional
## and data-derived, never a hardcoded pairing.
func gym_roster_id(gym_ref: String) -> String:
	var rosters: Array = _roster_ids()
	if rosters.has(gym_ref):
		return gym_ref
	var leaders: Array = _load_json_array(GYM_LEADERS_PATH)
	for i in range(leaders.size()):
		var leader_v: Variant = leaders[i]
		if not (leader_v is Dictionary):
			continue
		var leader: Dictionary = leader_v
		if str(leader.get("class", "")) == gym_ref or str(leader.get("name", "")) == gym_ref:
			var prefix: String = "kanto_gym_" + str(i + 1) + "_"
			for roster_id_v in rosters:
				if str(roster_id_v).begins_with(prefix):
					return str(roster_id_v)
	return ""


func _roster_ids() -> Array:
	var data: Dictionary = _load_json(ROSTERS_PATH)
	var out: Array = []
	var lists_v: Variant = data.get("gyms_and_coronation", [])
	if lists_v is Array:
		for entry_v in lists_v:
			if entry_v is Dictionary:
				out.append(str((entry_v as Dictionary).get("id", "")))
	return out


## B2 entry. gate is PUWCampaignStitch.can_start_gym_battle's
## result when the caller has one: a gate that does not allow
## the battle refuses it here too. Levels come from
## build_gym_team's global badge bands — badge_count is the
## GLOBAL count (GymProgression.badge_count(state)).
func start_gym_battle(gym_ref: String, badge_count: int, mode: String, gate: Dictionary = {}) -> Dictionary:
	if not gate.is_empty() and not bool(gate.get("allowed", false)):
		return {"ok": false, "kind": "gym", "enemy_party": [],
			"error": "gym availability gate refused the battle", "roster_id": ""}
	var roster_id: String = gym_roster_id(gym_ref)
	if roster_id.is_empty():
		return {"ok": false, "kind": "gym", "enemy_party": [],
			"error": "unknown gym reference '" + gym_ref + "' — battle refused", "roster_id": ""}
	var team: Array = builder().build_gym_team(roster_id, badge_count, mode)
	# Gym rosters carry no family field; identity is PKDX unless a
	# future roster gains one. Stamp explicitly (B8 shape).
	var stamped: Array = []
	for mon_v in team:
		stamped.append(stamp_family(mon_v, FAMILY_PKDX))
	return _result("gym", stamped, {"roster_id": roster_id})


# ----------------------------------------------------------------
# B3 — Rivals: current species list at player max.
# ----------------------------------------------------------------

## B3 entry. Rival identity comes from data/rival.json stages:
## stage_key (e.g. "RIVAL1") + party_index picks the encounter's
## species list; the build is at the player's current max, so
## the rival levels and evolves with the player. Post-battle
## bookkeeping stays PUWCampaignStitch.record_rival_fight's job.
func start_rival_battle(stage_key: String, party_index: int, player_max_level: int, mode: String, rng: RandomNumberGenerator, challenge_mode: String = "") -> Dictionary:
	var data: Dictionary = _load_json(RIVAL_PATH)
	var stages_v: Variant = data.get("stages", {})
	var identity: Array = []
	if stages_v is Dictionary:
		var stage_v: Variant = (stages_v as Dictionary).get(stage_key, {})
		if stage_v is Dictionary:
			var parties_v: Variant = (stage_v as Dictionary).get("parties", [])
			if parties_v is Array:
				for party_v in parties_v:
					if party_v is Dictionary and int((party_v as Dictionary).get("party_index", -1)) == party_index:
						var mons_v: Variant = (party_v as Dictionary).get("party", [])
						if mons_v is Array:
							identity = normalize_identity(mons_v)
						break
	var team: Array = _build_from_identity(identity, player_max_level, mode, rng, challenge_mode)
	return _result("rival", team, {"stage_key": stage_key, "party_index": party_index})


# ----------------------------------------------------------------
# B4 — Elite Four / Champion: roster path first.
# ----------------------------------------------------------------

## B4 entry (pure roster path): build_roster_team for any
## roster id — Johto Elite Four, Johto Champion Lance, the
## Coronation Leon roster (endgame data, placed only by the
## Coronation flow that owns it).
func start_roster_battle(roster_id: String, player_max_level: int, mode: String) -> Dictionary:
	var team: Array = builder().build_roster_team(roster_id, player_max_level, mode)
	var stamped: Array = []
	for mon_v in team:
		stamped.append(stamp_family(mon_v, FAMILY_PKDX))
	return _result("roster", stamped, {"roster_id": roster_id})


## B4 entry (gauntlet path). context "johto" resolves members
## through the roster file (JOHTO_ROSTER_BY_MEMBER). context
## "kanto" resolves members through data/elite_four.json
## identity (species only) built by build_trainer_team, and
## member "CHAMPION" resolves through the RIVAL3 class parties
## in data/trainers.json — the Champion battle is a scripted
## battle in the source, and it goes through the same door.
func start_elite_four_battle(member_id: String, player_max_level: int, mode: String, rng: RandomNumberGenerator, context: String = "kanto", party_index: int = 1, challenge_mode: String = "") -> Dictionary:
	if context == "johto" and JOHTO_ROSTER_BY_MEMBER.has(member_id):
		var roster_result: Dictionary = start_roster_battle(str(JOHTO_ROSTER_BY_MEMBER[member_id]), player_max_level, mode)
		roster_result["kind"] = "elite_four"
		roster_result["member_id"] = member_id
		return roster_result
	var identity: Array = []
	if member_id == "CHAMPION":
		identity = trainer_base_identity("RIVAL3", party_index, "kanto")
	else:
		var data: Dictionary = _load_json(ELITE_FOUR_PATH)
		var members_v: Variant = data.get("members", {})
		if members_v is Dictionary:
			var member_v: Variant = (members_v as Dictionary).get(member_id, {})
			if member_v is Dictionary:
				var parties_v: Variant = (member_v as Dictionary).get("parties", [])
				if parties_v is Array:
					for party_v in parties_v:
						if party_v is Dictionary and int((party_v as Dictionary).get("party_index", -1)) == party_index:
							var mons_v: Variant = (party_v as Dictionary).get("party", [])
							if mons_v is Array:
								identity = normalize_identity(mons_v)
							break
	var team: Array = _build_from_identity(identity, player_max_level, mode, rng, challenge_mode)
	return _result("elite_four", team, {"member_id": member_id, "context": context})


# ----------------------------------------------------------------
# B5 — Scripted / event battles: the one helper.
# ----------------------------------------------------------------

## B5 entry — THE scripted-battle hand-off. Every scripted or
## event battle in the game starts here: the script supplies
## species identity (names, or {species, dex_family} dicts for
## Moemon identities), never a party. An empty identity is a
## refused battle, not a raw one.
func start_scripted_battle(identity_list: Array, player_max_level: int, mode: String, rng: RandomNumberGenerator, challenge_mode: String = "") -> Dictionary:
	var identity: Array = normalize_identity(identity_list)
	var team: Array = _build_from_identity(identity, player_max_level, mode, rng, challenge_mode)
	return _result("scripted", team)


# ----------------------------------------------------------------
# B6 — Rematch: D4 enforced in code.
# ----------------------------------------------------------------

## D4 load-time enforcement: walk a caller-supplied rematch
## tier table set (the code_prep_rematch shape:
## {trainer_key: {tiers: [{party: [{species, level, iv}]}]}})
## and return a DEEP-CLEANED copy whose tier party entries
## carry ONLY "species". The source iv values are dropped here,
## at load — they cannot reach a battle because they no longer
## exist in the data the battle entry reads. Level is dropped
## on the same rule (rematch levels are the player's current
## max at battle time, not the tier's recorded history).
## Returns {tables, dropped_iv_fields, dropped_level_fields}.
static func sanitize_rematch_tables(tables: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}
	var dropped_iv: int = 0
	var dropped_level: int = 0
	for key_v in tables.keys():
		var key: String = str(key_v)
		var entry_v: Variant = tables[key_v]
		if not (entry_v is Dictionary):
			cleaned[key] = entry_v
			continue
		var entry: Dictionary = (entry_v as Dictionary).duplicate(true)
		var tiers_v: Variant = entry.get("tiers", [])
		if tiers_v is Array:
			var new_tiers: Array = []
			for tier_v in tiers_v:
				if not (tier_v is Dictionary):
					new_tiers.append(tier_v)
					continue
				var tier: Dictionary = (tier_v as Dictionary).duplicate(true)
				var party_v: Variant = tier.get("party", [])
				if party_v is Array:
					var new_party: Array = []
					for mon_v in party_v:
						if mon_v is Dictionary:
							var mon: Dictionary = mon_v
							if mon.has("iv"):
								dropped_iv += 1
							if mon.has("level"):
								dropped_level += 1
							new_party.append({"species": str(mon.get("species", ""))})
						else:
							new_party.append({"species": str(mon_v)})
					tier["party"] = new_party
				new_tiers.append(tier)
			entry["tiers"] = new_tiers
		cleaned[key] = entry
	return {"tables": cleaned, "dropped_iv_fields": dropped_iv, "dropped_level_fields": dropped_level}


## B6 entry. sanitized_tables MUST be sanitize_rematch_tables'
## output: identity is read from the cleaned tiers, and the
## party is built by the layer at battle time at the player's
## current max — the D4 ruling as code, not as a comment.
func start_rematch_battle(sanitized_tables: Dictionary, trainer_key: String, tier_index: int, player_max_level: int, mode: String, rng: RandomNumberGenerator, challenge_mode: String = "") -> Dictionary:
	var identity: Array = []
	var entry_v: Variant = sanitized_tables.get(trainer_key, {})
	if entry_v is Dictionary:
		var tiers_v: Variant = (entry_v as Dictionary).get("tiers", [])
		if tiers_v is Array:
			var tiers: Array = tiers_v
			if tier_index >= 0 and tier_index < tiers.size():
				var tier_v: Variant = tiers[tier_index]
				if tier_v is Dictionary:
					var party_v: Variant = (tier_v as Dictionary).get("party", [])
					if party_v is Array:
						identity = normalize_identity(party_v)
	var team: Array = _build_from_identity(identity, player_max_level, mode, rng, challenge_mode)
	return _result("rematch", team, {"trainer_key": trainer_key, "tier_index": tier_index})


# ----------------------------------------------------------------
# B7 — Wild: habitat roll -> build_wild_mon -> stamped mon.
# ----------------------------------------------------------------

## B7 build step. roll is a PUWHabitatEncounters /
## OverworldLoop roll entry {slug/species_slug, dex_family}.
## The family survives the build (B8): an MDX roll produces a
## battled mon with family == "MDX" and a build identical to
## its PKDX counterpart. An empty roll builds nothing.
func build_habitat_wild_mon(roll: Dictionary, player_max_level: int, rng: RandomNumberGenerator) -> Dictionary:
	if roll.is_empty():
		return {}
	var slug: String = str(roll.get("slug", roll.get("species_slug", "")))
	if slug.is_empty():
		return {}
	var mon: Dictionary = builder().build_wild_mon(slug, player_max_level, rng)
	return stamp_family(mon, str(roll.get("dex_family", FAMILY_PKDX)))


# ----------------------------------------------------------------
# B9 runtime half — the hand-off guard.
# ----------------------------------------------------------------

## Validate a built enemy party before it may be handed to a
## battle. Checks: party size (when expect_size > 0), every mon
## IV 31 in all stats, EV total <= 510 per mon, and levels
## against level_rule — {"exact": int} for trainer-shaped
## entries, {"min": int, "max": int} for wild/gym ranges, {}
## to skip the level check. Returns {ok, problems}.
static func validate_built_party(party: Array, expect_size: int, level_rule: Dictionary = {}) -> Dictionary:
	var problems: Array = []
	if party.is_empty():
		problems.append("party is empty")
	if expect_size > 0 and party.size() != expect_size:
		problems.append("party size " + str(party.size()) + " != expected " + str(expect_size))
	for mon_v in party:
		if not (mon_v is Dictionary):
			problems.append("party entry is not a Dictionary")
			continue
		var mon: Dictionary = mon_v
		var label: String = str(mon.get("species", "?"))
		var ivs_v: Variant = mon.get("ivs", {})
		if not (ivs_v is Dictionary):
			problems.append(label + ": no ivs (unbuilt mon)")
		else:
			for stat in PUWTeamBuilder.STAT_KEYS:
				if int((ivs_v as Dictionary).get(stat, 0)) != 31:
					problems.append(label + ": iv " + str(stat) + " != 31")
		var evs_v: Variant = mon.get("evs", {})
		if not (evs_v is Dictionary):
			problems.append(label + ": no evs (unbuilt mon)")
		elif PUWTeamBuilder.ev_total(evs_v) > PUWTeamBuilder.EV_BUDGET:
			problems.append(label + ": ev total " + str(PUWTeamBuilder.ev_total(evs_v)) + " > 510")
		var level: int = int(mon.get("level", 0))
		if level_rule.has("exact") and level != int(level_rule["exact"]):
			problems.append(label + ": level " + str(level) + " != " + str(int(level_rule["exact"])))
		if level_rule.has("min") and level < int(level_rule["min"]):
			problems.append(label + ": level " + str(level) + " < " + str(int(level_rule["min"])))
		if level_rule.has("max") and level > int(level_rule["max"]):
			problems.append(label + ": level " + str(level) + " > " + str(int(level_rule["max"])))
	return {"ok": problems.is_empty(), "problems": problems}


## THE hand-off. Scenes call this with the player's party and
## an entry-built enemy party; on success the caller sets
## BattleScene.pending_* and changes scene. On failure the
## battle does not start — this is what stops a future raw-load
## path from shipping silently (B9's runtime half; the
## integration guard test is the other half).
static func hand_off(enemy_party: Array, expect_size: int, level_rule: Dictionary = {}) -> Dictionary:
	var verdict: Dictionary = validate_built_party(enemy_party, expect_size, level_rule)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "error": "hand-off refused unbuilt/invalid enemy party", "problems": verdict.get("problems", [])}
	return {"ok": true, "error": "", "problems": []}
