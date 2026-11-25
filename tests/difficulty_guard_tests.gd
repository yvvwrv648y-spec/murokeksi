extends SceneTree
## B9 GUARD TEST — walks EVERY battle entry point and asserts
## the canon on what would actually be handed to a battle:
## team size 6 (trainer-shaped entries), IV 31 in all stats,
## EV total <= 510, the level rule per entry, family == "MDX"
## on Moemon entries — plus the hand-off guard's refusal of
## raw/unbuilt parties, and VEXA asserted as the ONLY exempt
## path (which still builds through the layer anyway).
## Run: godot --headless --script res://tests/difficulty_guard_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW difficulty guard tests (B9) — starting.")
	_run("guard_walks_every_entry_point", Callable(self, "guard_walks_every_entry_point"))
	_run("guard_gym_levels_follow_badge_bands", Callable(self, "guard_gym_levels_follow_badge_bands"))
	_run("guard_wild_level_rule", Callable(self, "guard_wild_level_rule"))
	_run("guard_moemon_entries_stay_mdx", Callable(self, "guard_moemon_entries_stay_mdx"))
	_run("guard_handoff_refuses_raw_parties", Callable(self, "guard_handoff_refuses_raw_parties"))
	_run("guard_vexa_is_the_only_exemption", Callable(self, "guard_vexa_is_the_only_exemption"))
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


func _check_party(label: String, party: Array, expect_size: int, level_rule: Dictionary) -> bool:
	var verdict: Dictionary = PUWBattleEntry.validate_built_party(party, expect_size, level_rule)
	if not bool(verdict.get("ok", false)):
		print("  " + label + ": " + str(verdict.get("problems", [])))
		return false
	# The hand-off guard must accept what the entries produce.
	var off: Dictionary = PUWBattleEntry.hand_off(party, expect_size, level_rule)
	if not bool(off.get("ok", false)):
		print("  " + label + ": hand-off refused a built party")
		return false
	return true


## One walk over every trainer-shaped entry in
## PUWBattleEntry.ENTRY_POINTS at player max 40.
func guard_walks_every_entry_point() -> bool:
	var entry: PUWBattleEntry = PUWBattleEntry.new()
	var player_max: int = 40
	var walked: Dictionary = {}

	var r1: Dictionary = entry.start_route_trainer_battle({"trainer_class": "YOUNGSTER", "party_index": 1}, player_max, "singles", _rng(21))
	if not _check_party("route_trainer", r1.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["route_trainer"] = true

	var r2: Dictionary = entry.start_gym_battle("kanto_gym_1_brock", 3, "singles")
	# Gym levels follow badge bands, not player max: checked
	# for size/build only here; bands pinned in their own test.
	if not _check_party("gym", r2.get("enemy_party", []), 6, {}):
		return false
	walked["gym"] = true

	var r3: Dictionary = entry.start_rival_battle("RIVAL1", 4, player_max, "singles", _rng(22))
	if not _check_party("rival", r3.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["rival"] = true

	var r4: Dictionary = entry.start_elite_four_battle("LORELEI", player_max, "singles", _rng(23))
	if not _check_party("elite_four", r4.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["elite_four"] = true

	var r5: Dictionary = entry.start_roster_battle("johto_champion_lance", player_max, "singles")
	if not _check_party("roster", r5.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["roster"] = true

	var r6: Dictionary = entry.start_scripted_battle(["Gengar", "Alakazam"], player_max, "singles", _rng(24))
	if not _check_party("scripted", r6.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["scripted"] = true

	var tables: Dictionary = {"t": {"tiers": [{"party": [{"species": "Rattata", "level": 11, "iv": 0}]}]}}
	var cleaned: Dictionary = PUWBattleEntry.sanitize_rematch_tables(tables)
	var r7: Dictionary = entry.start_rematch_battle(cleaned.get("tables", {}), "t", 0, player_max, "singles", _rng(25))
	if not _check_party("rematch", r7.get("enemy_party", []), 6, {"exact": player_max}):
		return false
	walked["rematch"] = true

	var r8: Dictionary = entry.build_habitat_wild_mon({"slug": "pidgey", "dex_family": "PKDX"}, player_max, _rng(26))
	if not _check_party("habitat_wild", [r8], 1, {"min": player_max + 1, "max": player_max + 3}):
		return false
	walked["habitat_wild"] = true

	# The walk covered exactly the registered entry points.
	for name_v in PUWBattleEntry.ENTRY_POINTS:
		if not walked.has(str(name_v)):
			print("  entry point never walked: " + str(name_v))
			return false
	return walked.size() == PUWBattleEntry.ENTRY_POINTS.size()


## Gym exception to the level rule is the BADGE BAND rule, and
## it is pinned: badge 0 -> band 12..14, badge 7 -> band 48..50.
func guard_gym_levels_follow_badge_bands() -> bool:
	var entry: PUWBattleEntry = PUWBattleEntry.new()
	var early: Dictionary = entry.start_gym_battle("BROCK", 0, "singles")
	if not _check_party("gym badge 0", early.get("enemy_party", []), 6, {"min": 12, "max": 14}):
		return false
	var late: Dictionary = entry.start_gym_battle("BROCK", 7, "singles")
	if not _check_party("gym badge 7", late.get("enemy_party", []), 6, {"min": 48, "max": 50}):
		return false
	return true


func guard_wild_level_rule() -> bool:
	var entry: PUWBattleEntry = PUWBattleEntry.new()
	for seed_val in range(1, 13):
		var mon: Dictionary = entry.build_habitat_wild_mon({"slug": "rattata", "dex_family": "PKDX"}, 30, _rng(seed_val))
		var level: int = int(mon.get("level", 0))
		if level < 31 or level > 33:
			print("  wild level out of rule: " + str(level))
			return false
	return true


## Moemon entries keep family == "MDX" through both the wild
## path and a trainer-shaped path, with maxed builds.
func guard_moemon_entries_stay_mdx() -> bool:
	var entry: PUWBattleEntry = PUWBattleEntry.new()
	var wild: Dictionary = entry.build_habitat_wild_mon({"slug": "pikachu", "dex_family": "MDX"}, 30, _rng(31))
	if str(wild.get("family", "")) != "MDX":
		return false
	if not _check_party("mdx wild", [wild], 1, {"min": 31, "max": 33}):
		return false
	var res: Dictionary = entry.start_scripted_battle([{"species": "Pikachu", "dex_family": "MDX"}], 30, "singles", _rng(32))
	var party: Array = res.get("enemy_party", [])
	for mon_v in party:
		var mon: Dictionary = mon_v
		if str(mon.get("species_slug", "")) == "pikachu" and str(mon.get("family", "")) != "MDX":
			print("  MDX identity arrived as PKDX")
			return false
	return _check_party("mdx scripted", party, 6, {"exact": 30})


## The runtime half of B9: parties that did NOT come from the
## layer are refused at the hand-off — the raw trainers.json
## shape (species + level only), a hand-made IV-0 dict, and an
## empty party.
func guard_handoff_refuses_raw_parties() -> bool:
	var raw: Array = [{"species": "Rattata", "level": 11}, {"species": "Ekans", "level": 11}]
	if bool(PUWBattleEntry.hand_off(raw, 6, {"exact": 40}).get("ok", true)):
		print("  raw source party was accepted")
		return false
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var mon: Dictionary = builder.build_mon("Rattata", 40, "singles")
	mon["ivs"] = {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	if bool(PUWBattleEntry.hand_off([mon], 1, {"exact": 40}).get("ok", true)):
		print("  IV-0 party was accepted")
		return false
	if bool(PUWBattleEntry.hand_off([], 6, {}).get("ok", true)):
		print("  empty party was accepted")
		return false
	return true


## VEXA is the only exemption, the exemption list is exactly
## one entry long, and the exempt path STILL builds through
## the layer (its counter team is maxed like everything else).
func guard_vexa_is_the_only_exemption() -> bool:
	if PUWBattleEntry.EXEMPT_ENTRY_POINTS != ["vexa_simulation"]:
		print("  exemption list changed: " + str(PUWBattleEntry.EXEMPT_ENTRY_POINTS))
		return false
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var player_party: Array = [builder.build_mon("Charizard", 50, "singles"), builder.build_mon("Blastoise", 50, "singles")]
	var sim: PUWVexaSimulator = PUWVexaSimulator.new()
	var counter: Array = sim.build_counter_team(player_party, 50, _rng(41))
	if counter.is_empty():
		print("  vexa counter team empty")
		return false
	var verdict: Dictionary = PUWBattleEntry.validate_built_party(counter, counter.size(), {"exact": 50})
	if not bool(verdict.get("ok", false)):
		print("  vexa builds not maxed: " + str(verdict.get("problems", [])))
		return false
	return true
