extends SceneTree
## Canon decision tests (Riley, 2026-11-22): permadeath counts in
## story and co-op battles; only simulations and rentals are
## exempt; the Omni gimmick families are exactly the five official
## budget keys, with no fifth slot.
## Run: godot --headless --script res://tests/integration_canon_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW integration canon tests — starting.")
	_run("test_permadeath_truth_table", Callable(self, "test_permadeath_truth_table"))
	_run("test_story_battles_run_without_simulation_flag", Callable(self, "test_story_battles_run_without_simulation_flag"))
	_run("test_story_faint_records_lockout", Callable(self, "test_story_faint_records_lockout"))
	_run("test_coop_faint_records_lockout", Callable(self, "test_coop_faint_records_lockout"))
	_run("test_sim_faint_leaves_state_identical", Callable(self, "test_sim_faint_leaves_state_identical"))
	_run("test_rental_faint_leaves_state_identical", Callable(self, "test_rental_faint_leaves_state_identical"))
	_run("test_gimmick_families_exactly_five_budgets", Callable(self, "test_gimmick_families_exactly_five_budgets"))
	_run("test_omni_can_use", Callable(self, "test_omni_can_use"))
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


func _mon(mon_name: String, species: String, level: int) -> Dictionary:
	return {
		"name": mon_name,
		"species": species,
		"level": level,
		"hp": 40,
		"max_hp": 40,
		"moves": ["Tackle", "Growl"],
		"evo_family": species + "_line",
	}


## A save-shaped party state carrying the house faint records:
## "party", "locked_evo_families", "fainting_ledger" (the exact
## representation PartyAndStorageManager.handle_faint writes).
func _party_state() -> Dictionary:
	return {
		"party": [_mon("Hero", "Emberfox", 20), _mon("Splash", "Aquaff", 18)],
		"locked_evo_families": {},
		"fainting_ledger": [],
		"story_flags": {"campaign_stage": "starter_chosen"},
	}


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


## The full decision truth table: ordinary, story, and co-op all
## count; simulation and rental are the only exemptions, and
## simulation wins even when combined with story.
func test_permadeath_truth_table() -> bool:
	if not PUWCombatConsequences.permadeath_applies({}):
		print("  ordinary battle should count")
		return false
	if not PUWCombatConsequences.permadeath_applies({"story": true}):
		print("  story battle should count")
		return false
	if not PUWCombatConsequences.permadeath_applies({"coop": true}):
		print("  co-op battle should count")
		return false
	if not PUWCombatConsequences.permadeath_applies({"story": true, "coop": true}):
		print("  story+coop battle should count")
		return false
	if not PUWCombatConsequences.permadeath_applies({"coop": true, "simulation": false}):
		print("  co-op battle context {coop:true, simulation:false} should count")
		return false
	if PUWCombatConsequences.permadeath_applies({"simulation": true}):
		print("  simulation should be exempt")
		return false
	if PUWCombatConsequences.permadeath_applies({"rental": true}):
		print("  rental should be exempt")
		return false
	if PUWCombatConsequences.permadeath_applies({"simulation": true, "story": true}):
		print("  simulation+story should be exempt (simulation wins)")
		return false
	if PUWCombatConsequences.permadeath_applies({"simulation": true, "coop": true}):
		print("  simulation+coop should be exempt (simulation wins)")
		return false
	return true


## Wiring proof for the story side: PUWCampaignStitch's battle
## entry points (rival fights, gym wins, gatekeeper, runner-up,
## Elite Four) record story progress only — the stitch never sets
## or passes a simulation flag, and BattleController.start_battle
## defaults simulation to false. So a campaign battle is a real
## battle, and its faints go through the story context below.
func test_story_battles_run_without_simulation_flag() -> bool:
	var stitch_src: String = _read_source("res://systems/campaign/campaign_stitch.gd")
	if stitch_src == "":
		print("  campaign_stitch.gd not readable")
		return false
	if stitch_src.to_lower().contains("simulation"):
		print("  campaign_stitch.gd mentions simulation; story battles must not use the sim flag")
		return false
	var controller_src: String = _read_source("res://battle/battle_controller.gd")
	if not controller_src.contains("simulation: bool = false"):
		print("  BattleController.start_battle no longer defaults simulation to false")
		return false
	return true


## A mon fainted in a story-context battle, recorded through
## PUWCombatConsequences, lands in the real lockout
## representation: removed from the party, its evolution family
## locked, and a ledger entry under the story battle format.
func test_story_faint_records_lockout() -> bool:
	var state: Dictionary = _party_state()
	var party_before: Array = state.get("party", [])
	var mon: Dictionary = party_before[0]
	var result: Dictionary = PUWCombatConsequences.apply_faint_consequences(state, mon, {"story": true, "simulation": false})
	var locked: Dictionary = result.get("locked_evo_families", {})
	if not bool(locked.get("Emberfox_line", false)):
		print("  story faint did not lock Emberfox_line: " + str(locked))
		return false
	var party_after: Array = result.get("party", [])
	if party_after.size() != 1:
		print("  story faint should remove the mon from the party, party size " + str(party_after.size()))
		return false
	var remaining: Dictionary = party_after[0]
	if str(remaining.get("name", "")) != "Splash":
		print("  wrong mon removed from the party")
		return false
	var ledger: Array = result.get("fainting_ledger", [])
	if ledger.size() != 1:
		print("  story faint should write exactly one ledger entry")
		return false
	var entry: Dictionary = ledger[0]
	if str(entry.get("evo_family", "")) != "Emberfox_line" or str(entry.get("format", "")) != "scripted_story_battle":
		print("  ledger entry wrong: " + str(entry))
		return false
	# The caller's state is never mutated (deep-copy rule).
	var original_party: Array = state.get("party", [])
	if original_party.size() != 2:
		print("  input state was mutated")
		return false
	var original_locked: Dictionary = state.get("locked_evo_families", {})
	if not original_locked.is_empty():
		print("  input lockout dict was mutated")
		return false
	return true


## Same recording for a co-op battle context
## {coop: true, simulation: false} — the context a battle fought
## over PUWCoopNetworkManager carries. No live network session is
## needed: the context decision + recording path is the contract.
func test_coop_faint_records_lockout() -> bool:
	var state: Dictionary = _party_state()
	var party: Array = state.get("party", [])
	var mon: Dictionary = party[1]
	var result: Dictionary = PUWCombatConsequences.apply_faint_consequences(state, mon, {"coop": true, "simulation": false})
	var locked: Dictionary = result.get("locked_evo_families", {})
	if not bool(locked.get("Aquaff_line", false)):
		print("  co-op faint did not lock Aquaff_line: " + str(locked))
		return false
	var party_after: Array = result.get("party", [])
	if party_after.size() != 1:
		print("  co-op faint should remove the mon from the party")
		return false
	var ledger: Array = result.get("fainting_ledger", [])
	if ledger.size() != 1:
		print("  co-op faint should write exactly one ledger entry")
		return false
	var entry: Dictionary = ledger[0]
	if str(entry.get("format", "")) != "multiplayer_coop_battle":
		print("  co-op ledger format wrong: " + str(entry))
		return false
	return true


## A simulation faint (the VEXA context) leaves the state
## byte-identical: no removal, no lockout, no ledger entry.
func test_sim_faint_leaves_state_identical() -> bool:
	var state: Dictionary = _party_state()
	var party: Array = state.get("party", [])
	var mon: Dictionary = party[0]
	var result: Dictionary = PUWCombatConsequences.apply_faint_consequences(state, mon, {"simulation": true})
	if JSON.stringify(result) != JSON.stringify(state):
		print("  sim faint changed the state")
		return false
	return true


## A rental faint is the other exemption: state byte-identical.
func test_rental_faint_leaves_state_identical() -> bool:
	var state: Dictionary = _party_state()
	var party: Array = state.get("party", [])
	var mon: Dictionary = party[0]
	var result: Dictionary = PUWCombatConsequences.apply_faint_consequences(state, mon, {"rental": true})
	if JSON.stringify(result) != JSON.stringify(state):
		print("  rental faint changed the state")
		return false
	return true


## Exactly the five per-side budget keys of the v3 battle engine,
## cross-checked against BattleController's own gimmick_budgets
## table, and no fifth slot / pending entry anywhere in the list.
func test_gimmick_families_exactly_five_budgets() -> bool:
	var families: Array = PUWCombatConsequences.gimmick_families()
	var expected: Array = ["mega", "zmove", "dynamax", "gigantamax", "tera"]
	if families.size() != 5:
		print("  gimmick_families size is " + str(families.size()) + ", want 5")
		return false
	if families != expected:
		print("  gimmick_families is " + str(families) + ", want " + str(expected))
		return false
	for fam_value: Variant in families:
		var fam: String = str(fam_value)
		if fam.contains("slot_5") or fam.contains("pending"):
			print("  a fifth-slot / pending entry leaked in: " + fam)
			return false
	var controller_src: String = _read_source("res://battle/battle_controller.gd")
	if not controller_src.contains("\"gimmick_budgets\""):
		print("  BattleController gimmick_budgets table not found")
		return false
	for fam_value in expected:
		var key: String = str(fam_value)
		if not controller_src.contains("\"" + key + "\": false"):
			print("  budget key " + key + " not found in BattleController's budgets")
			return false
	return true


## The standing Omni rule: locked in Kanto, usable outside Kanto
## only when unlocked.
func test_omni_can_use() -> bool:
	if PUWCombatConsequences.omni_can_use("kanto", true):
		print("  Omni must stay locked in Kanto even when unlocked")
		return false
	if not PUWCombatConsequences.omni_can_use("johto", true):
		print("  Omni should work in Johto when unlocked")
		return false
	if PUWCombatConsequences.omni_can_use("johto", false):
		print("  Omni must not work while locked")
		return false
	return true
