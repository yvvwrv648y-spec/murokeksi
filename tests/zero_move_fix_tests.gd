extends SceneTree
## Zero-move species fix (defect S1) — main suite, run against the
## PATCHED code on the REAL bound data.
## Run: godot --headless --path test_project --script res://tests/zero_move_fix_tests.gd
##
## Asserts:
## 1. The resolver reaches the base species' learnset (the sourced
##    record) for all 24 S1 forme species, and the learnset it
##    returns is exactly the base entry.
## 2. Formes whose held learnsets genuinely differ still resolve to
##    their OWN entries (exact keys win over the base route).
## 3. All 24 species build with >= 1 sourced move at levels 5/50/100
##    in both modes, via the learnset fallback (no set exists for
##    them anywhere in the held data — layer 2 found nothing).
## 4. Wild builds of the 24 have moves.
## 5. The fill on real hazard pools never deals a zero-move mon and
##    needs no safety skips once the resolver route is in.
## 6. Full-dex hazard census: NO species in competitive_sets builds
##    with zero moves at level 50 in either mode.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const PAIRS: Array = [
	["aegislashshield", "aegislash"], ["basculegionmale", "basculegion"],
	["basculinredstriped", "basculin"], ["darmanitanstandard", "darmanitan"],
	["dudunsparcetwosegment", "dudunsparce"], ["eiscueice", "eiscue"],
	["frillishmale", "frillish"], ["gourgeistaverage", "gourgeist"],
	["indeedeemale", "indeedee"], ["jellicentmale", "jellicent"],
	["keldeoordinary", "keldeo"], ["mausholdfamilyoffour", "maushold"],
	["meloettaaria", "meloetta"], ["meowsticmale", "meowstic"],
	["miniorredmeteor", "minior"], ["morpekofullbelly", "morpeko"],
	["oinkolognemale", "oinkologne"], ["oricoriobaile", "oricorio"],
	["palafinzero", "palafin"], ["pumpkabooaverage", "pumpkaboo"],
	["pyroarmale", "pyroar"], ["squawkabillygreenplumage", "squawkabilly"],
	["tatsugiricurly", "tatsugiri"], ["urshifusinglestrike", "urshifu"],
]


func _init() -> void:
	print("PUW zero-move fix tests — starting.")
	_run("resolver_reaches_base_for_all_24", Callable(self, "resolver_reaches_base_for_all_24"))
	_run("forme_specific_learnsets_still_win", Callable(self, "forme_specific_learnsets_still_win"))
	_run("all_24_build_with_moves", Callable(self, "all_24_build_with_moves"))
	_run("wild_builds_of_24_have_moves", Callable(self, "wild_builds_of_24_have_moves"))
	_run("fill_never_deals_zero_move_on_real_data", Callable(self, "fill_never_deals_zero_move_on_real_data"))
	_run("hazard_census_empty_full_dex", Callable(self, "hazard_census_empty_full_dex"))
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = bool(test.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _rng(seed_val: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_val
	return r


func resolver_reaches_base_for_all_24() -> bool:
	var resolver: LearnsetResolver = LearnsetResolver.new()
	if not resolver.is_loaded():
		print("  resolver did not load learnsets_compact.json")
		return false
	for pair_v in PAIRS:
		var pair: Array = pair_v
		var forme_ls: Dictionary = resolver.get_learnset(str(pair[0]))
		var base_ls: Dictionary = resolver.get_learnset(str(pair[1]))
		if forme_ls.is_empty():
			print("  " + str(pair[0]) + ": still resolves to no learnset")
			return false
		if JSON.stringify(forme_ls) != JSON.stringify(base_ls):
			print("  " + str(pair[0]) + ": learnset differs from base " + str(pair[1]))
			return false
	return true


func forme_specific_learnsets_still_win() -> bool:
	var resolver: LearnsetResolver = LearnsetResolver.new()
	# Indeedee-F has its OWN entry in the held data (Follow Me is
	# female-only there); the male forme routes to the base entry
	# (Extrasensory is in the base entry, Follow Me is not).
	if not resolver.can_learn("indeedeef", "Follow Me"):
		print("  indeedeef lost its own learnset (Follow Me)")
		return false
	if resolver.can_learn("indeedeemale", "Follow Me"):
		print("  indeedeemale wrongly gained the female-only move Follow Me")
		return false
	if not resolver.can_learn("indeedeemale", "Extrasensory"):
		print("  indeedeemale did not reach the base learnset (Extrasensory)")
		return false
	# Urshifu Rapid Strike has its own entry (Aqua Jet); Single
	# Strike routes to the base entry (Darkest Lariat, no Aqua Jet).
	if not resolver.can_learn("urshifurapidstrike", "Aqua Jet"):
		print("  urshifurapidstrike lost its own learnset (Aqua Jet)")
		return false
	if resolver.can_learn("urshifusinglestrike", "Aqua Jet"):
		print("  urshifusinglestrike wrongly gained the Rapid Strike move Aqua Jet")
		return false
	if not resolver.can_learn("urshifusinglestrike", "Darkest Lariat"):
		print("  urshifusinglestrike did not reach the base learnset (Darkest Lariat)")
		return false
	return true


func all_24_build_with_moves() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	for pair_v in PAIRS:
		var slug: String = str((pair_v as Array)[0])
		for level in [5, 50, 100]:
			for mode in ["singles", "vgc"]:
				var mon: Dictionary = builder.build_mon(slug, level, mode)
				var moves: Variant = mon.get("moves", [])
				if not (moves is Array) or (moves as Array).is_empty():
					print("  " + slug + " level " + str(level) + " " + mode + ": zero moves")
					return false
				if str(mon.get("set_source", "")) != "learnset_fallback":
					print("  " + slug + ": expected learnset_fallback route, got " + str(mon.get("set_source", "")))
					return false
	return true


func wild_builds_of_24_have_moves() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	for pair_v in PAIRS:
		var slug: String = str((pair_v as Array)[0])
		var mon: Dictionary = builder.build_wild_mon(slug, 50, _rng(1234))
		var moves: Variant = mon.get("moves", [])
		if not (moves is Array) or (moves as Array).is_empty():
			print("  wild " + slug + ": zero moves")
			return false
	return true


func fill_never_deals_zero_move_on_real_data() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var bases: Array = [
		["gengar", "alakazam"],
		["dewgong", "cloyster", "slowbro", "jynx", "lapras"],
		["gengar", "golbat", "haunter", "arbok", "gengar"],
		["gyarados", "dragonair", "dragonair", "aerodactyl", "dragonite"],
	]
	for base_v in bases:
		for seed_val in range(1, 26):
			var team: Array = builder.build_trainer_team(base_v, 50, "singles", _rng(seed_val))
			if team.size() != 6:
				print("  base " + str(base_v) + " seed " + str(seed_val) + ": team size " + str(team.size()))
				return false
			for mon_v in team:
				var mon: Dictionary = mon_v
				var moves: Variant = mon.get("moves", [])
				if not (moves is Array) or (moves as Array).is_empty():
					print("  base " + str(base_v) + " seed " + str(seed_val) + ": zero-move mon " + str(mon.get("species_slug", "")))
					return false
			if not builder.last_fill_skips.is_empty():
				print("  base " + str(base_v) + " seed " + str(seed_val) + ": unexpected fill skips " + str(builder.last_fill_skips))
				return false
	return true


func hazard_census_empty_full_dex() -> bool:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var text: String = FileAccess.get_file_as_string("res://data/competitive_sets.json")
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		print("  competitive_sets.json did not parse")
		return false
	var species: Variant = (parsed as Dictionary).get("species", {})
	if not (species is Dictionary):
		print("  competitive_sets.json has no species map")
		return false
	var checked: int = 0
	for slug_v in (species as Dictionary).keys():
		var slug: String = str(slug_v)
		for mode in ["singles", "vgc"]:
			var mon: Dictionary = builder.build_mon(slug, 50, mode)
			var moves: Variant = mon.get("moves", [])
			if not (moves is Array) or (moves as Array).is_empty():
				print("  census: " + slug + " (" + mode + ") builds with zero moves")
				return false
		checked += 1
	print("  census checked " + str(checked) + " species x 2 modes at level 50: zero-move count 0")
	return checked == 1025
