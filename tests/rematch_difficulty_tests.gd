extends SceneTree
## Rematch DIFFICULTY tests — PM ruling D4 (2026-11-23).
## Proves the D4 bind path end to end: a rematch tier supplies
## species identity ONLY (its level/iv fields are the source
## game's recorded history), and the battle party built from
## that identity by the difficulty layer (PUWTeamBuilder) comes
## out at the full standard — exactly 6 Pokémon, IV 31 in every
## stat, EV spread sourced from the species' own competitive
## set under the locked 510 cap, level scaled to the player
## (NOT the tier's recorded level), moves = the sourced set's
## moves. The 510 budget itself is pinned through the builder's
## deterministic cap rule.
##
## SCOPE (Riley 2026-11-23 23:15 CST): the ruling covers
## Pokémon AND Moemon parties identically — Moemon mirror PKDX
## stats/moves/evolutions, so the same builder keyed by species
## identity and the same sourced sets produce Moemon parties at
## the same standard. Both are pinned here: the Moemon test
## builds a tier whose slots carry the moemon_mdx variant
## marker through the SAME build_rematch_party() call and
## requires the tier species' mons to match their PKDX builds
## on every battle value (IV/EV/level/moves), differing only
## on the family axis.
##
## The party-construction path under test is the prep's own:
## PUWRematchSystem.build_rematch_party() ->
## PUWDifficultyLayer.build_party_from_identity() (the
## difficulty layer landed in code_prep_difficulty and is
## consumed verbatim) -> PUWTeamBuilder.
##
## Run with Godot 4.7.2 headless via run_d4_tests.sh, which
## assembles test_project_d4/ (the plain test_project plus the
## res://data/ files the builder loads:
## competitive_sets.json + evolution_triggers.json +
## learnsets_compact.json).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const BEN: String = "youngster_ben_route3"

func _init() -> void:
	print("PUW rematch difficulty (D4) tests — starting.")
	_run("test_tier_identity_extraction_is_species_only", Callable(self, "test_tier_identity_extraction_is_species_only"))
	_run("test_tier_party_identity_drops_build_history", Callable(self, "test_tier_party_identity_drops_build_history"))
	_run("test_rematch_party_built_at_full_standard", Callable(self, "test_rematch_party_built_at_full_standard"))
	_run("test_moemon_rematch_party_built_at_full_standard", Callable(self, "test_moemon_rematch_party_built_at_full_standard"))
	_run("test_ev_budget_cap_is_510", Callable(self, "test_ev_budget_cap_is_510"))
	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("FAILED: ", _failed_names)
	quit(1 if _failed > 0 else 0)

func _run(name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_failed_names.append(name)
		print("FAIL: ", name)

func _tables() -> Dictionary:
	var ben_tiers: Array = [
		{"trainer_id": "youngster_ben", "party": [
			{"species": "rattata", "level": 11, "iv": 0},
			{"species": "ekans", "level": 11, "iv": 0}]},
		{"trainer_id": "youngster_ben_2", "party": [
			{"species": "rattata", "level": 17, "iv": 20},
			{"species": "ekans", "level": 17, "iv": 20}]},
		null,
		{"trainer_id": "youngster_ben_3", "party": [
			{"species": "raticate", "level": 28, "iv": 60},
			{"species": "ekans", "level": 28, "iv": 60}]},
		{"trainer_id": "youngster_ben_4", "party": [
			{"species": "raticate", "level": 48, "iv": 120},
			{"species": "arbok", "level": 48, "iv": 120}]},
	]
	return {BEN: {"region": "kanto", "tiers": ben_tiers}}

func _full_progression() -> Dictionary:
	return {"got_vs_seeker": true, "world_map_celadon": true,
		"world_map_fuchsia": true, "game_clear": true, "can_link_rs": true}

func _rng(seed_val: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func _sorted_joined(values: Array) -> String:
	var parts: Array = []
	for v in values:
		parts.append(str(v))
	parts.sort()
	return ",".join(parts)

# The identity extraction returns species strings ONLY — the
# tier's recorded level/iv history never leaves the table.
func test_tier_identity_extraction_is_species_only() -> bool:
	var tables: Dictionary = _tables()
	var entry: Dictionary = tables[BEN]
	var tiers: Array = entry["tiers"]
	var tier4: Dictionary = tiers[4]
	# The tier row itself still carries its source history
	# (level 48, iv 120 on the FRLG 0-255 scale) — provenance.
	var party: Array = tier4["party"]
	var mon0: Dictionary = party[0]
	if int(mon0["level"]) != 48 or int(mon0["iv"]) != 120:
		return false
	var species: Array = PUWRematchSystem.tier_species_identity(tier4)
	if species.size() != 2:
		return false
	if str(species[0]) != "raticate" or str(species[1]) != "arbok":
		return false
	for s in species:
		if typeof(s) != TYPE_STRING:
			return false
	return true

# The difficulty-layer identity shape: tier_party_identity()
# returns species (+ variant markers) ONLY. The tier's stored
# level/iv (and any other stored build field) must not survive
# into the identity handed to the builder.
func test_tier_party_identity_drops_build_history() -> bool:
	var tier: Dictionary = {"trainer_id": "youngster_ben_4", "party": [
		{"species": "raticate", "level": 48, "iv": 120, "moves": ["Hyper Fang"]},
		{"species": "arbok", "level": 48, "iv": 120, "variant": "moemon_mdx"}]}
	var identity: Array = PUWRematchSystem.tier_party_identity(tier)
	if identity.size() != 2:
		return false
	var first: Dictionary = identity[0]
	if str(first.get("species", "")) != "raticate":
		return false
	if first.has("level") or first.has("iv") or first.has("moves"):
		return false
	if first.has("variant"):
		return false
	var second: Dictionary = identity[1]
	if str(second.get("species", "")) != "arbok":
		return false
	if str(second.get("variant", "")) != "moemon_mdx":
		return false
	if second.has("level") or second.has("iv"):
		return false
	return true

# The D4 battle path: select the tier (identity), build with
# build_rematch_party() (difficulty layer) at player_max 37.
# The built party must be 6 mons at the full standard, and
# NONE of the tier's recorded build history (level 48,
# iv 120) may appear in it.
func test_rematch_party_built_at_full_standard() -> bool:
	var state: Dictionary = {}
	PUWRematchSystem.record_battle_result(state, BEN, true, 0)
	# Walk the record to tier 3 fought so tier 4 is next.
	var root: Dictionary = state["rematch"]
	var t: Dictionary = root["trainers"]
	var rec: Dictionary = t[BEN]
	rec["highest_tier_fought"] = 3
	t[BEN] = rec
	root["trainers"] = t
	state["rematch"] = root
	var tables: Dictionary = _tables()
	var sel: Dictionary = PUWRematchSystem.select_rematch_party(state, BEN, tables, _full_progression(), "frlg")
	if not bool(sel["ok"]) or int(sel["tier_index"]) != 4:
		return false
	var entry: Dictionary = tables[BEN]
	var tiers: Array = entry["tiers"]
	var tier4: Dictionary = tiers[4]
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	if not builder.is_loaded():
		print("  builder data not loaded (data folder missing?)")
		return false
	var team: Array = PUWRematchSystem.build_rematch_party(tier4, 37, "singles", _rng(42))
	if team.size() != 6:
		print("  team size %d, wanted 6" % team.size())
		return false
	var arbok: Dictionary = {}
	var raticate: Dictionary = {}
	for mon_v in team:
		var mon: Dictionary = mon_v
		# Level comes from player scaling (37), never the
		# tier's recorded 48.
		if int(mon["level"]) != 37:
			print("  mon level %d, wanted 37 (player scaling)" % int(mon["level"]))
			return false
		# IV 31 in EVERY stat — the tier's iv 120 (0-255
		# scale) appears nowhere.
		var ivs: Dictionary = mon["ivs"]
		for stat in ["hp", "atk", "def", "spa", "spd", "spe"]:
			if int(ivs.get(stat, -1)) != 31:
				print("  mon %s iv %s = %d, wanted 31" % [str(mon.get("species_slug", "")), stat, int(ivs.get(stat, -1))])
				return false
		# EV total respects the locked 510 budget.
		var evs: Dictionary = mon["evs"]
		if PUWTeamBuilder.ev_total(evs) > 510:
			print("  mon %s ev total over 510" % str(mon.get("species_slug", "")))
			return false
		var slug: String = str(mon.get("species_slug", ""))
		if slug == "arbok":
			arbok = mon
		if slug == "raticate":
			raticate = mon
	if arbok.is_empty() or raticate.is_empty():
		print("  tier species missing from built team")
		return false
	# Set sourced: the tier species' moves are exactly their
	# sourced competitive sets' moves (competitive_sets.json).
	if str(arbok.get("set_source", "")) != "smogon":
		return false
	if _sorted_joined(arbok["moves"]) != _sorted_joined(["Sludge Bomb", "Glare", "Earthquake", "Giga Drain"]):
		print("  arbok moves not the sourced set: ", arbok["moves"])
		return false
	if str(raticate.get("set_source", "")) != "smogon":
		return false
	if _sorted_joined(raticate["moves"]) != _sorted_joined(["Super Fang", "Substitute", "Mimic", "Body Slam"]):
		print("  raticate moves not the sourced set: ", raticate["moves"])
		return false
	return true

# Moemon parity (Riley 2026-11-23 23:15 CST): the SAME tier
# identity with moemon_mdx variant markers, built through the
# SAME build_rematch_party() call at player_max 37, must field
# the tier species as MDX mons at the identical standard —
# IV 31 in every stat, level 37 (never the tier's stored 48),
# EV spread and moveset exactly equal to the PKDX build of
# the same identity with the same seed. Only the family axis
# may differ.
func test_moemon_rematch_party_built_at_full_standard() -> bool:
	var pkdx_tier: Dictionary = {"trainer_id": "youngster_ben_4", "party": [
		{"species": "raticate", "level": 48, "iv": 120},
		{"species": "arbok", "level": 48, "iv": 120}]}
	var mdx_tier: Dictionary = {"trainer_id": "youngster_ben_4_mdx", "party": [
		{"species": "raticate", "level": 48, "iv": 120, "variant": "moemon_mdx"},
		{"species": "arbok", "level": 48, "iv": 120, "variant": "moemon_mdx"}]}
	var pkdx_team: Array = PUWRematchSystem.build_rematch_party(pkdx_tier, 37, "singles", _rng(42))
	var mdx_team: Array = PUWRematchSystem.build_rematch_party(mdx_tier, 37, "singles", _rng(42))
	if pkdx_team.size() != 6 or mdx_team.size() != 6:
		print("  team sizes %d / %d, wanted 6 / 6" % [pkdx_team.size(), mdx_team.size()])
		return false
	var pkdx_by_slug: Dictionary = {}
	for mon_v in pkdx_team:
		var pm: Dictionary = mon_v
		pkdx_by_slug[str(pm.get("species_slug", ""))] = pm
	var saw_raticate: bool = false
	var saw_arbok: bool = false
	for mon_v2 in mdx_team:
		var mon: Dictionary = mon_v2
		if int(mon["level"]) != 37:
			print("  MDX mon level %d, wanted 37 (player scaling)" % int(mon["level"]))
			return false
		var ivs: Dictionary = mon["ivs"]
		for stat in ["hp", "atk", "def", "spa", "spd", "spe"]:
			if int(ivs.get(stat, -1)) != 31:
				print("  MDX mon %s iv %s = %d, wanted 31" % [str(mon.get("species_slug", "")), stat, int(ivs.get(stat, -1))])
				return false
		var evs: Dictionary = mon["evs"]
		if PUWTeamBuilder.ev_total(evs) > 510:
			print("  MDX mon %s ev total over 510" % str(mon.get("species_slug", "")))
			return false
		var slug: String = str(mon.get("species_slug", ""))
		if slug == "raticate" or slug == "arbok":
			# The tier's own species: MDX-stamped, and equal
			# to the PKDX build on every battle value.
			if str(mon.get("family", "")) != "MDX" or str(mon.get("dex_family", "")) != "MDX":
				print("  MDX tier mon %s not MDX-stamped" % slug)
				return false
			if str(mon.get("variant", "")) != "moemon_mdx":
				return false
			var twin: Dictionary = pkdx_by_slug.get(slug, {})
			if twin.is_empty():
				return false
			if str(mon.get("evs", {})) != str(twin.get("evs", {})):
				print("  MDX %s EV spread differs from PKDX" % slug)
				return false
			if _sorted_joined(mon["moves"]) != _sorted_joined(twin["moves"]):
				print("  MDX %s moveset differs from PKDX" % slug)
				return false
			if str(mon.get("nature", "")) != str(twin.get("nature", "")):
				return false
			if slug == "raticate":
				saw_raticate = true
			else:
				saw_arbok = true
	return saw_raticate and saw_arbok

# The locked EV budget itself: a 520-total spread trims
# deterministically to exactly 510, cutting the smallest
# nonzero stat first and leaving the 252s untouched.
func test_ev_budget_cap_is_510() -> bool:
	var capped: Dictionary = PUWTeamBuilder.cap_evs({"hp": 252, "atk": 252, "spe": 16})
	if PUWTeamBuilder.ev_total(capped) != 510:
		return false
	if int(capped.get("hp", 0)) != 252 or int(capped.get("atk", 0)) != 252:
		return false
	return int(capped.get("spe", 0)) == 6
