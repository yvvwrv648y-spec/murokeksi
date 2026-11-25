extends SceneTree
## Difficulty wiring tests: PUWBattleEntry (audit closure B1–B8).
## Run: godot --headless --script res://tests/difficulty_wiring_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW difficulty wiring tests — starting.")
	_run("b1_route_trainer_from_spawner_trigger", Callable(self, "b1_route_trainer_from_spawner_trigger"))
	_run("b1_route_trainer_johto_loader", Callable(self, "b1_route_trainer_johto_loader"))
	_run("b1_unknown_trainer_refused", Callable(self, "b1_unknown_trainer_refused"))
	_run("b2_gym_brock_badge_band", Callable(self, "b2_gym_brock_badge_band"))
	_run("b2_gym_gate_refusal", Callable(self, "b2_gym_gate_refusal"))
	_run("b3_rival_route22", Callable(self, "b3_rival_route22"))
	_run("b4_roster_champion_lance", Callable(self, "b4_roster_champion_lance"))
	_run("b4_elite_four_kanto_lorelei", Callable(self, "b4_elite_four_kanto_lorelei"))
	_run("b4_champion_via_rival3", Callable(self, "b4_champion_via_rival3"))
	_run("b5_scripted_builds_and_refuses_empty", Callable(self, "b5_scripted_builds_and_refuses_empty"))
	_run("b6_rematch_d4_sanitize_and_build", Callable(self, "b6_rematch_d4_sanitize_and_build"))
	_run("b7_habitat_roll_to_built_wild", Callable(self, "b7_habitat_roll_to_built_wild"))
	_run("b8_mdx_stamp_identical_build", Callable(self, "b8_mdx_stamp_identical_build"))
	_run("b8_mdx_trainer_identity", Callable(self, "b8_mdx_trainer_identity"))
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


func _entry() -> PUWBattleEntry:
	return PUWBattleEntry.new()


func _built_ok(party: Array, expect_size: int, level_rule: Dictionary) -> bool:
	var verdict: Dictionary = PUWBattleEntry.validate_built_party(party, expect_size, level_rule)
	if not bool(verdict.get("ok", false)):
		print("  problems: " + str(verdict.get("problems", [])))
		return false
	return true


# B1: a real spawner placement (the first YOUNGSTER placement,
# Mt. Moon, party_index 3 in the data's 1-based convention)
# becomes a trigger dict, and the entry builds a full 6-mon
# maxed team at player max from its small source identity.
func b1_route_trainer_from_spawner_trigger() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainers.json"))
	var placements: Array = data.get("placements", [])
	var placement: Dictionary = {}
	for p_v in placements:
		var p: Dictionary = p_v
		if str(p.get("class", "")) == "YOUNGSTER":
			placement = p
			break
	if placement.is_empty():
		print("  no YOUNGSTER placement found")
		return false
	var trigger: Dictionary = PUWSpawner.trainer_dict_from_placement(placement)
	var res: Dictionary = _entry().start_route_trainer_battle(trigger, 37, "singles", _rng(42))
	if not bool(res.get("ok", false)):
		print("  entry refused: " + str(res.get("error", "")))
		return false
	var party: Array = res.get("enemy_party", [])
	return _built_ok(party, 6, {"exact": 37})


# B1 (loader half): the Johto trainer file the spawner never read
# resolves through the same door.
func b1_route_trainer_johto_loader() -> bool:
	var trigger: Dictionary = {"trainer_class": "FALKNER", "party_index": 1, "source": "johto"}
	var res: Dictionary = _entry().start_route_trainer_battle(trigger, 20, "singles", _rng(7))
	if not bool(res.get("ok", false)):
		print("  johto entry refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 20})


func b1_unknown_trainer_refused() -> bool:
	var trigger: Dictionary = {"trainer_class": "NO_SUCH_CLASS", "party_index": 0}
	var res: Dictionary = _entry().start_route_trainer_battle(trigger, 20, "singles", _rng(1))
	return not bool(res.get("ok", true)) and (res.get("enemy_party", []) as Array).is_empty()


# B2: Brock at global badge count 0 — roster identity in order,
# levels inside the first band (12..14), all maxed.
func b2_gym_brock_badge_band() -> bool:
	var res: Dictionary = _entry().start_gym_battle("BROCK", 0, "singles")
	if not bool(res.get("ok", false)):
		print("  gym refused: " + str(res.get("error", "")))
		return false
	if str(res.get("roster_id", "")) != "kanto_gym_1_brock":
		print("  wrong roster: " + str(res.get("roster_id", "")))
		return false
	var party: Array = res.get("enemy_party", [])
	if not _built_ok(party, 6, {"min": 12, "max": 14}):
		return false
	# Identity: the roster's own species, in roster order,
	# auto-evolve OFF (geodude stays geodude at band levels).
	var slugs: Array = []
	for mon_v in party:
		slugs.append(str((mon_v as Dictionary).get("species_slug", "")))
	return slugs == ["geodude", "aron", "rolycoly", "rhyhorn", "kabuto", "onix"]


func b2_gym_gate_refusal() -> bool:
	var gate: Dictionary = {"allowed": false, "gym_id": "kanto_gym_1_brock", "unmet": ["test gate"]}
	var res: Dictionary = _entry().start_gym_battle("BROCK", 0, "singles", gate)
	return not bool(res.get("ok", true))


# B3: Rival1's Route 22 party (Pidgey + starter) at player max 20.
func b3_rival_route22() -> bool:
	var res: Dictionary = _entry().start_rival_battle("RIVAL1", 4, 20, "singles", _rng(3))
	if not bool(res.get("ok", false)):
		print("  rival refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 20})


# B4: the roster path — Johto Champion Lance at player max 50.
func b4_roster_champion_lance() -> bool:
	var res: Dictionary = _entry().start_roster_battle("johto_champion_lance", 50, "singles")
	if not bool(res.get("ok", false)):
		print("  roster refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 50})


# B4: Kanto gauntlet member through elite_four.json identity.
func b4_elite_four_kanto_lorelei() -> bool:
	var res: Dictionary = _entry().start_elite_four_battle("LORELEI", 55, "singles", _rng(5))
	if not bool(res.get("ok", false)):
		print("  e4 refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 55})


# B4: the Champion is the scripted RIVAL3 battle in the source;
# it goes through the same door.
func b4_champion_via_rival3() -> bool:
	var res: Dictionary = _entry().start_elite_four_battle("CHAMPION", 60, "singles", _rng(6), "kanto", 1)
	if not bool(res.get("ok", false)):
		print("  champion refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 60})


# B5: scripted battles build from identity only; an empty
# identity is a refused battle, never a raw one.
func b5_scripted_builds_and_refuses_empty() -> bool:
	var res: Dictionary = _entry().start_scripted_battle(["Abra", "Machop"], 25, "singles", _rng(9))
	if not bool(res.get("ok", false)):
		return false
	if not _built_ok(res.get("enemy_party", []), 6, {"exact": 25}):
		return false
	var refused: Dictionary = _entry().start_scripted_battle([], 25, "singles", _rng(9))
	return not bool(refused.get("ok", true))


# B6 / D4: tier tables carry source iv values (FRLG fixture
# shape). Sanitizing drops every iv (and level) at load; the
# rematch party is then built at battle time at current max.
func b6_rematch_d4_sanitize_and_build() -> bool:
	var tables: Dictionary = {
		"youngster_ben_route3": {"region": "kanto", "tiers": [
			{"party": [{"species": "Rattata", "level": 11, "iv": 0}, {"species": "Ekans", "level": 11, "iv": 0}]},
			{"party": [{"species": "Rattata", "level": 19, "iv": 20}, {"species": "Ekans", "level": 19, "iv": 20}, {"species": "Arbok", "level": 21, "iv": 20}]},
		]},
	}
	var cleaned: Dictionary = PUWBattleEntry.sanitize_rematch_tables(tables)
	if int(cleaned.get("dropped_iv_fields", 0)) != 5:
		print("  dropped iv count wrong: " + str(cleaned.get("dropped_iv_fields", -1)))
		return false
	if int(cleaned.get("dropped_level_fields", 0)) != 5:
		return false
	var clean_tables: Dictionary = cleaned.get("tables", {})
	if JSON.stringify(clean_tables).contains("\"iv\""):
		print("  iv survived sanitizing")
		return false
	# The caller's original table is untouched (deep-clean copy).
	if not JSON.stringify(tables).contains("\"iv\""):
		print("  sanitizer mutated the caller's table")
		return false
	var res: Dictionary = _entry().start_rematch_battle(clean_tables, "youngster_ben_route3", 1, 44, "singles", _rng(11))
	if not bool(res.get("ok", false)):
		print("  rematch refused: " + str(res.get("error", "")))
		return false
	return _built_ok(res.get("enemy_party", []), 6, {"exact": 44})


# B7: the real habitat path — roll on ROUTE_1, build the wild
# mon, levels in player_max +1..3, IV 31.
func b7_habitat_roll_to_built_wild() -> bool:
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	if not habitat.load_data():
		print("  habitat data failed to load")
		return false
	var entry: PUWBattleEntry = _entry()
	for seed_val in range(1, 41):
		var roll: Dictionary = habitat.roll_habitat_encounter("ROUTE_1", 20, _rng(seed_val))
		if roll.is_empty():
			continue
		var mon: Dictionary = entry.build_habitat_wild_mon(roll, 20, _rng(100 + seed_val))
		if mon.is_empty():
			return false
		if not _built_ok([mon], 1, {"min": 21, "max": 23}):
			return false
		var family: String = str(mon.get("family", ""))
		if family != "PKDX" and family != "MDX":
			print("  wild mon family unstamped: " + family)
			return false
		return true
	print("  no habitat roll in 40 seeds")
	return false


# B8: an MDX roll stamps family "MDX" and changes NOTHING else —
# the build is identical to the PKDX build of the same species.
func b8_mdx_stamp_identical_build() -> bool:
	var entry: PUWBattleEntry = _entry()
	var pkdx: Dictionary = entry.build_habitat_wild_mon({"slug": "bulbasaur", "dex_family": "PKDX"}, 20, _rng(77))
	var mdx: Dictionary = entry.build_habitat_wild_mon({"slug": "bulbasaur", "dex_family": "MDX"}, 20, _rng(77))
	if pkdx.is_empty() or mdx.is_empty():
		return false
	if str(mdx.get("family", "")) != "MDX" or str(pkdx.get("family", "")) != "PKDX":
		return false
	var a: Dictionary = pkdx.duplicate(true)
	var b: Dictionary = mdx.duplicate(true)
	a.erase("family")
	b.erase("family")
	return JSON.stringify(a) == JSON.stringify(b)


# B8 inside a trainer-shaped entry: an MDX identity in a
# scripted battle is stamped; its build matches the PKDX build
# of the same species at the same level.
func b8_mdx_trainer_identity() -> bool:
	var entry: PUWBattleEntry = _entry()
	var res: Dictionary = entry.start_scripted_battle([{"species": "Bulbasaur", "dex_family": "MDX"}], 30, "singles", _rng(13))
	if not bool(res.get("ok", false)):
		return false
	var party: Array = res.get("enemy_party", [])
	var found_mdx: bool = false
	for mon_v in party:
		var mon: Dictionary = mon_v
		if str(mon.get("species_slug", "")) == "ivysaur":
			if str(mon.get("family", "")) != "MDX":
				print("  evolved MDX identity lost its family")
				return false
			found_mdx = true
			var plain: Dictionary = PUWTeamBuilder.new().build_mon("Bulbasaur", 30, "singles")
			if int(mon.get("hp", 0)) != int(plain.get("hp", -1)):
				return false
	return found_mdx
