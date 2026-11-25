class_name PUWDifficultyLayer
extends RefCounted
## PUWDifficultyLayer — the ONE difficulty-layer entry point for
## party building (code_prep_difficulty, 2026-11-23).
##
## Why this exists: Riley's restated difficulty canon
## (2026-11-23 23:10-23:13 CST; qa_desk/RULES_REFRESHER.md) plus
## PM rulings D4 (rematch tier tables supply species/identity
## ONLY) and D5 (Frontier opponents are 6 mons built by the
## difficulty layer; player entry is the full party; Factory
## rentals are built at the same standard) require every consumer
## to build battle parties the same way. Consumers must call
## build_party_from_identity() — never field a party from stored
## level/iv/ev data.
##
## Identity input: an Array whose entries are either a species
## name/slug String, or a Dictionary carrying at least "species"
## (or "slug"). A Dictionary may also carry "variant" /
## "family" / "dex_family" ("MDX", "moemon", "moemon_mdx" mark
## the Moemon variant; anything else is PKDX). EVERY other field
## in an identity Dictionary — "level", "iv", "ivs", "evs",
## "nature", "moves", "ability", "item" — is identity-history /
## provenance and is DELIBERATELY IGNORED as a build value.
##
## Build standard (delegated to PUWTeamBuilder, the operative
## layer; this class adds no second standard):
## - exactly 6 mons for trainer/challenge parties (the builder's
##   shared-type fill rule; short only when the sourced pool is
##   genuinely exhausted — never padded with inventions)
## - IV 31 in every stat, unconditionally
## - EV spread = the final species' best sourced set, per-stat
##   <= 252, total <= 510 (never 516)
## - level = player's max level (trainers); wilds +1..3
## - species auto-evolved by level-up rows at the built level;
##   the set is re-sourced for the EVOLVED species, so EV
##   redistribution happens only where the evolution's own
##   sourced set differs — never by editing a stored spread
## - moves = the sourced set's moves, egg moves included where
##   the sourced set carries them; egg_moves_in_set() reports
##   which of a built mon's moves are egg moves for its species
## - EV provenance (PM ruling 2026-11-23, ev_sets wiring): the
##   register now includes the 562 sourced rows from
##   data_registry/ev_sets/sets.json. For the 124 remainder
##   species with no sourced set anywhere staged, the builder
##   applies the labeled DESIGN CONSTANT heuristic (252/252 in
##   the two highest base stats) — every such mon's build record
##   carries "ev_source": "DC_HEURISTIC, NOT SOURCED". Sourced
##   always wins; EV 0 is retired as a fallback.
##
## Moemon (Riley 2026-11-23 23:15 CST): the canon applies
## IDENTICALLY to Pokemon and Moemon. MDX mirrors PKDX stats /
## moves / evolutions, so an MDX identity is built by the exact
## same builder call from the same sourced set, then wrapped the
## way PUWMDXData.build_mdx_mon() wraps: a deep copy whose ONLY
## battle-data change is the family axis (family / dex_family
## "MDX", variant "moemon_mdx"). No separate, weaker Moemon
## path exists in this layer.

const MDX_TOKENS: Array = ["mdx", "moemon", "moemon_mdx", "moemon-mdx"]

var _builder: PUWTeamBuilder = null
var _learnsets: LearnsetResolver = null


func _get_builder() -> PUWTeamBuilder:
	if _builder == null:
		_builder = PUWTeamBuilder.new()
	return _builder


static func is_mdx_identity(entry_v: Variant) -> bool:
	if entry_v is Dictionary:
		var entry: Dictionary = entry_v
		for key in ["variant", "family", "dex_family"]:
			var token: String = str(entry.get(key, "")).strip_edges().to_lower()
			if MDX_TOKENS.has(token):
				return true
	return false


static func identity_species(entry_v: Variant) -> String:
	if entry_v is String:
		return str(entry_v)
	if entry_v is Dictionary:
		var entry: Dictionary = entry_v
		var species: String = str(entry.get("species", ""))
		if species.is_empty():
			species = str(entry.get("slug", ""))
		return species
	return ""


## THE party builder for D4/D5 consumers (rematch, Frontier,
## rentals, ordinary trainers, challenges).
## identities: identity-only input as documented above.
## Returns an Array of exactly 6 built mon Dictionaries (fewer
## only under the builder's documented pool-exhaustion rule).
func build_party_from_identity(identities: Array, player_max_level: int, mode: String, rng: RandomNumberGenerator) -> Array:
	var builder: PUWTeamBuilder = _get_builder()
	var level: int = PUWCompetitiveScalingEngine.scale_opponent_level(player_max_level)
	# Which evolved slugs belong to MDX identities (first wins).
	var mdx_slugs: Dictionary = {}
	var base_species: Array = []
	for entry_v in identities:
		var species: String = identity_species(entry_v)
		if species.is_empty():
			continue
		base_species.append(species)
		if is_mdx_identity(entry_v):
			var evolved: String = builder.resolve_evolved_species(PUWTeamBuilder.slugify(species), level)
			if not mdx_slugs.has(evolved):
				mdx_slugs[evolved] = true
	var team: Array = builder.build_trainer_team(base_species, player_max_level, mode, rng)
	var out: Array = []
	for mon_v in team:
		var mon: Dictionary = mon_v
		if mdx_slugs.has(str(mon.get("species_slug", ""))):
			mon = wrap_mdx(mon)
		out.append(mon)
	return out


## Factory / rental parties at the SAME standard (ruling D5).
## The only extra stamp is "rental": true — the permadeath
## exemption axis (rentals are not the player's to lose). It
## changes no battle-build value.
func build_rental_party(identities: Array, player_max_level: int, mode: String, rng: RandomNumberGenerator) -> Array:
	var team: Array = build_party_from_identity(identities, player_max_level, mode, rng)
	var out: Array = []
	for mon_v in team:
		var mon: Dictionary = (mon_v as Dictionary).duplicate(true)
		mon["rental"] = true
		out.append(mon)
	return out


## One built mon from identity (species + optional MDX variant).
func build_mon_from_identity(entry_v: Variant, player_max_level: int, mode: String) -> Dictionary:
	var builder: PUWTeamBuilder = _get_builder()
	var level: int = PUWCompetitiveScalingEngine.scale_opponent_level(player_max_level)
	var mon: Dictionary = builder.build_mon(identity_species(entry_v), level, mode)
	if is_mdx_identity(entry_v):
		mon = wrap_mdx(mon)
	return mon


## A maxed wild mon (level = player max + rng 1..3, clamped 100),
## PKDX or MDX by identity.
func build_wild_from_identity(entry_v: Variant, player_max_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var builder: PUWTeamBuilder = _get_builder()
	var mon: Dictionary = builder.build_wild_mon(identity_species(entry_v), player_max_level, rng)
	if is_mdx_identity(entry_v):
		mon = wrap_mdx(mon)
	return mon


## The MDX wrap: identical in effect to
## PUWMDXData.build_mdx_mon() — a deep copy; stats, types,
## abilities, moves, IVs, EVs, nature, level are UNCHANGED; only
## the family axis changes.
static func wrap_mdx(pkdx_mon: Dictionary) -> Dictionary:
	var mon: Dictionary = pkdx_mon.duplicate(true)
	mon["family"] = "MDX"
	mon["dex_family"] = "MDX"
	mon["variant"] = "moemon_mdx"
	return mon


## Which of a built mon's moves are egg moves ("E" learn method)
## for its (final) species, per LearnsetResolver real data.
## Sourced Smogon sets routinely carry egg moves; this reports
## them instead of guessing. Returns display names as built.
func egg_moves_in_set(mon: Dictionary) -> Array:
	if _learnsets == null:
		_learnsets = LearnsetResolver.new()
	var species_name: String = str(mon.get("species", ""))
	var out: Array = []
	var moves_v: Variant = mon.get("moves", [])
	if moves_v is Array:
		var moves: Array = moves_v
		for move_v in moves:
			var move_name: String = str(move_v)
			var methods: Array = _learnsets.get_learn_methods(species_name, move_name)
			for method_v in methods:
				if method_v is Dictionary and str((method_v as Dictionary).get("method", "")) == "egg":
					out.append(move_name)
					break
	return out


## Hard level cap for a GLOBAL badge count (EXPSystem table:
## [10, 20, 24, 29, 40, 43, 47, 50, 100]).
static func level_cap_for_badges(badges: int) -> int:
	return EXPSystem.level_cap_for_badges(badges)


## The level a mon with this total EXP displays under the badge
## cap: EXP accrues in full past the cap (the caller's stored
## EXP is never touched by this function); only the LEVEL stops.
## A mon already above the cap is never lowered by gaining EXP
## handling elsewhere — this helper only maps EXP -> capped
## level for a mon growing from at/below the cap.
static func capped_level_for_exp(growth_rate: String, total_exp: int, badges: int) -> int:
	var raw_level: int = EXPSystem.level_for_exp(growth_rate, total_exp)
	return mini(raw_level, EXPSystem.level_cap_for_badges(badges))
