extends SceneTree
## KANTO SPINE-WALK CERTIFICATION SUITE (code prep, staging only).
##
## BIND_PLAN §9.5's scripted spine-walk: ONE save state is played
## programmatically through the whole Kanto campaign spine on the
## merged prep copies (campaign stitch + event runner + authored
## story scripts + gym gates + difficulty/entry layer + fixed
## encounters):
##
##   new game (custom character) -> Oak two-pick -> gyms 1-8 in
##   order, with the story beats that gate them played in
##   dependency order (Mt. Moon fossil, S.S. Anne -> HM01 -> Cut
##   before gym 3; Game Corner -> Hideout -> Silph Scope; Tower
##   rescue before the Flute; Silph Co. before gym 6; the Secret
##   Key gate at gym 7) -> Victory Road gatekeeper + Runner-Up ->
##   Elite Four gauntlet -> Champion (record_champion_win(state,
##   "kanto") effect asserted) -> Mewtwo's gate opens.
##
## At every step the suite asserts the flag state, and every enemy
## party the walk builds is validated at the difficulty standard
## through PUWBattleEntry.validate_built_party (exactly 6 mons for
## trainer-class battles, IV 31 in every stat, EV total <= 510).
## The final section computes the FLAG SETTER MAP from the real
## data files: every story flag consumed by a gym requirement, a
## fixed-encounter gate, or an event script's requires must have a
## named setter (an authored script's set_flag step or a stitch
## API the walk itself exercised) -- the story audit's original
## break ("flags set by NO production code anywhere") proven
## closed, flag by flag.
##
## NAMED IN-FLIGHT DEPENDENCIES (asserted as seams, never faked):
##   * gym 7's secret_key: in the bound data the Secret Key is an
##     item-ball placement in PokemonMansionB1F, and the pickup
##     system that grants it (code_prep_kanto_item_fixes F1) is
##     still in flight. The walk asserts the gate REFUSES without
##     it, then places the key in the bag as the documented seam
##     and asserts the gate opens. The gate, battle, and win are
##     proven; the pickup trigger is the named dependency.
##   * the "cut" field action: PUWFieldActions' badge half is
##     proven live (Cascade Badge unlocks has_required_badge);
##     flags["field_actions"] is the representation
##     gym_requirements.gd itself documents until the field-action
##     system writes it (the events prep used the same seam after
##     the HM01 grant). Teaching Cut to a party member is host
##     work.
##   * Sevii access (ferry / Tri-Pass grant) is a separate lane
##     still in flight; the walk asserts the Kanto-only path. The
##     authored Sevii chain scripts are covered by the events
##     suite in this same harness (regression below), and their
##     consumed flags are included in the setter map.
##
## Harness play-simulation, stated plainly: between segments the
## walk sets the player party's level the way play would (never
## above the hard cap for the badge count held). Enemy builds do
## not read it except where the canon says they do (Elite Four /
## Champion / scripted encounters build at the player's max).
##
## Run: godot --headless --script res://tests/spine_walk_tests.gd

const EVENTS_DIR: String = "res://data/events/"

var _passed: int = 0
var _failed: int = 0
var _lines: Array = []
var _warps: Array = []
var _entry: PUWBattleEntry = PUWBattleEntry.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _record_line(speaker: String, text: String) -> void:
	_lines.append({"speaker": speaker, "text": text})


func _record_warp(map_name: String, warp_id: int, _tile: Vector2i) -> void:
	_warps.append([map_name, warp_id])


func _flags(state: Dictionary) -> Dictionary:
	var f_v: Variant = state.get("story_flags", {})
	return f_v if f_v is Dictionary else {}


func _bag(state: Dictionary) -> Dictionary:
	var b_v: Variant = state.get("bag", {})
	return b_v if b_v is Dictionary else {}


func _party(state: Dictionary) -> Array:
	var p_v: Variant = state.get("party", [])
	return p_v if p_v is Array else []


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Actors for every actor id a script references (plus "player"),
## built the way the events suites build them.
func _actors_for(script: Dictionary) -> Dictionary:
	var ids: Dictionary = {"player": true}
	var steps_v: Variant = script.get("steps", [])
	var steps: Array = steps_v if steps_v is Array else []
	for step_v in steps:
		if step_v is Dictionary:
			var step: Dictionary = step_v
			var actor_id: String = str(step.get("actor", ""))
			if actor_id != "":
				ids[actor_id] = true
	var actors: Dictionary = {}
	var i: int = 0
	for id_v in ids.keys():
		var actor_id: String = str(id_v)
		actors[actor_id] = PUWEventActor.create(
			actor_id, Node2D.new(), Vector2i(2 + i, 2), 8, "down")
		i += 1
	return actors


func _drive(runner: PUWEventRunner, battle_won: bool) -> Dictionary:
	var seen: Dictionary = {}
	var guard: int = 0
	while not runner.is_finished() and not runner.has_error() and guard < 20000:
		guard += 1
		if runner.is_waiting_line():
			runner.advance_line()
		elif runner.is_waiting_battle():
			seen = runner.pending_battle()
			runner.resolve_battle(battle_won)
		else:
			runner.tick(0.05)
	return seen


## Run one authored script on the walk state. badge_override >= 0
## rewrites the script's gym-battle step in memory -- the
## documented host contract (the host overwrites badge_count with
## the live GLOBAL badge count before running).
func _run_script(state: Dictionary, file_name: String, battle_won: bool,
		badge_override: int = -1) -> Dictionary:
	_lines = []
	_warps = []
	var script: Dictionary = _load_json(EVENTS_DIR + file_name)
	if badge_override >= 0:
		var steps_v: Variant = script.get("steps", [])
		var steps: Array = steps_v if steps_v is Array else []
		for step_v in steps:
			if step_v is Dictionary and str((step_v as Dictionary).get("op", "")) == "battle":
				(step_v as Dictionary)["badge_count"] = badge_override
	var runner: PUWEventRunner = PUWEventRunner.new()
	runner.configure(state, _actors_for(script), {
		"present_line": Callable(self, "_record_line"),
		"on_warp": Callable(self, "_record_warp"),
	}, {}, 4242)
	var loaded: bool = bool(runner.load_script(script).get("ok", false))
	var run_ok: bool = loaded and bool(runner.run().get("ok", false))
	return {
		"loaded": loaded and run_ok,
		"runner": runner,
		"battle": _drive(runner, battle_won) if run_ok else {},
	}


func _battle_valid(battle: Dictionary, expect_size: int) -> bool:
	if not bool(battle.get("ok", false)):
		return false
	var party_v: Variant = battle.get("enemy_party", battle.get("party", []))
	var party: Array = party_v if party_v is Array else []
	var verdict: Dictionary = PUWBattleEntry.validate_built_party(
		party, expect_size, {})
	return bool(verdict.get("ok", false))


## Set the player party's level (harness play-simulation; see the
## header). Never above the hard cap for the badges held.
func _level_party(state: Dictionary, level: int) -> void:
	var party: Array = _party(state)
	for mon_v in party:
		if mon_v is Dictionary:
			(mon_v as Dictionary)["level"] = level
	state["party"] = party


## The stitch stores the gauntlet's run record at
## flags["e4_run"] (its EliteFourFlow shim); read the current
## opponent through EliteFourFlow's own logic on that record.
func _current_opponent(state: Dictionary) -> String:
	var run_v: Variant = _flags(state).get("e4_run", {})
	var view: Dictionary = {"e4_run": run_v if run_v is Dictionary else {}}
	return EliteFourFlow.current_opponent(view)


func _unmet_text(gate: Dictionary) -> String:
	var out: String = ""
	var unmet_v: Variant = gate.get("unmet", [])
	var unmet: Array = unmet_v if unmet_v is Array else []
	for u_v in unmet:
		out += str(u_v) + " | "
	return out


## One gym through the direct doors the runner itself uses:
## stitch gate -> PUWBattleEntry build -> validate at the
## difficulty standard -> stitch record (which re-checks the gate
## and refuses a gated or out-of-order win).
func _gym_win_direct(state: Dictionary, gym_id: String, label: String) -> void:
	var gate: Dictionary = PUWCampaignStitch.can_start_gym_battle(state, gym_id)
	_check(label + ": gate allows the battle", bool(gate.get("allowed", false)))
	var badges_before: int = GymProgression.badge_count(state)
	var battle: Dictionary = _entry.start_gym_battle(
		gym_id, badges_before, "singles", gate)
	_check(label + ": enemy party is 6 mons at the difficulty standard",
		_battle_valid(battle, 6))
	_check(label + ": stitch records the win",
		PUWCampaignStitch.record_gym_win(state, gym_id))
	_check(label + ": badge count advanced",
		GymProgression.badge_count(state) == badges_before + 1)


func _init() -> void:
	_rng.seed = 20261124

	# ------------------------------------------------ S0: new game
	var state: Dictionary = PUWCampaignStitch.new_game_state(
		"custom_female", "RED")
	_check("S0 new game: a custom character starts with NO Pokemon (starter ruling)",
		_party(state).is_empty())
	_check("S0 new game: campaign stage not yet begun",
		PUWCampaignStitch.stage(state) == "")

	# --------------------------------------- S1: setup -> clues
	_check("S1 complete_setup runs", PUWCampaignStitch.complete_setup(state))
	_check("S1 spawn recorded", not PUWCampaignStitch.record_spawn(state).is_empty())
	_check("S1 home clues produced (both Pallet home clue texts)",
		not PUWCampaignStitch.record_clues_seen(state).is_empty())
	_check("S1 stage is clues_seen",
		PUWCampaignStitch.stage(state) == "clues_seen")

	# ----------------------------- S2: Oak's Lab opening + picks
	var oak: Dictionary = _run_script(state, "oak_lab_opening.json", true)
	var oak_runner: PUWEventRunner = oak["runner"]
	_check("S2 Oak opening script loads", bool(oak.get("loaded", false)))
	_check("S2 Oak opening plays to completion",
		oak_runner.is_finished() and not oak_runner.has_error())
	var oak_battle: Dictionary = oak["battle"]
	_check("S2 the rival battle built through the difficulty layer",
		bool(oak_battle.get("ok", false)) and _battle_valid(oak_battle, 0))
	_check("S2 two-pick grant landed: party of exactly 2",
		_party(state).size() == 2)
	var grant_verdict: Dictionary = PUWBattleEntry.validate_built_party(
		_party(state), 2, {"exact": 5})
	_check("S2 Oak picks are at the standard (level 5, IV 31, EV <= 510)",
		bool(grant_verdict.get("ok", false)))
	_check("S2 oak_picks_done set by the grant",
		bool(_flags(state).get("oak_picks_done", false)))
	_check("S2 stage advanced to starter_chosen",
		PUWCampaignStitch.stage(state) == "starter_chosen")
	_check("S2 five Poke Balls in the bag",
		int(_bag(state).get("poke-ball", 0)) == 5)
	_check("S2 the opening warps back to Pallet Town",
		_warps.size() == 1 and str(_warps[0][0]) == "PalletTown")

	# ------------------------------------------------- S3: gym 1
	_gym_win_direct(state, "kanto_gym_1_brock", "S3 gym 1 Brock")
	_level_party(state, 20)  # hard cap at 1 badge

	# ------------------------------------------------- S4: gym 2
	_gym_win_direct(state, "kanto_gym_2_misty", "S4 gym 2 Misty")
	_check("S4 the real field system now counts the Cascade Badge for Cut",
		PUWFieldActions.has_required_badge(state, "cut"))
	var cut_probe: Dictionary = PUWFieldActions.can_perform(
		state, _party(state), "cut")
	print("INFO: can_perform(cut) after Cascade Badge = ", cut_probe)
	_check("S4 Cut's remaining blocker is no longer the badge",
		str(cut_probe.get("reason", "")) != "badge_missing")
	_level_party(state, 24)  # hard cap at 2 badges

	# ------------------------------------- S5: Mt. Moon fossil
	# The host's fossil choice is a transient pick flag (the
	# runner has no choice op -- events prep convention).
	var flags5: Dictionary = _flags(state)
	flags5["mt_moon_pick_dome"] = true
	state["story_flags"] = flags5
	var fossil: Dictionary = _run_script(state, "mt_moon_fossil_choice.json", true)
	var fossil_runner: PUWEventRunner = fossil["runner"]
	_check("S5 Mt. Moon fossil script completes",
		fossil_runner.is_finished() and not fossil_runner.has_error())
	_check("S5 the Dome Fossil is in the bag",
		int(_bag(state).get("dome-fossil", 0)) == 1)
	_check("S5 mt_moon_fossil_taken set",
		bool(_flags(state).get("mt_moon_fossil_taken", false)))

	# --------------------------- S6: gym 3 gate refuses early
	var gate3_early: Dictionary = PUWCampaignStitch.can_start_gym_battle(
		state, "kanto_gym_3_surge")
	_check("S6 gym 3 gate REFUSES before the S.S. Anne beat",
		not bool(gate3_early.get("allowed", true)))
	_check("S6 the refusal names the S.S. Anne requirement",
		_unmet_text(gate3_early).contains("S.S. Anne"))
	_check("S6 stitch refuses to record a gated gym 3 win",
		not PUWCampaignStitch.record_gym_win(state, "kanto_gym_3_surge"))
	var gate3_script: Dictionary = _run_script(
		state, "gym_gate_kanto_gym_3_surge.json", true,
		GymProgression.badge_count(state))
	var gate3_runner: PUWEventRunner = gate3_script["runner"]
	_check("S6 the authored gym 3 gate script is refused by the same gate",
		gate3_runner.has_error()
		and gate3_runner.error_text().contains("gym availability gate refused"))

	# --------------------- S7: S.S. Anne -> HM01 -> Cut -> open
	var anne: Dictionary = _run_script(state, "ss_anne_captain.json", true)
	var anne_runner: PUWEventRunner = anne["runner"]
	_check("S7 S.S. Anne captain script completes",
		anne_runner.is_finished() and not anne_runner.has_error())
	_check("S7 HM01 granted by the captain",
		int(_bag(state).get("hm01", 0)) == 1)
	_check("S7 ss_anne_cleared set (the flag the gym 3 gate consumes)",
		bool(_flags(state).get("ss_anne_cleared", false)))
	var gate3_mid: Dictionary = PUWCampaignStitch.can_start_gym_battle(
		state, "kanto_gym_3_surge")
	_check("S7 gym 3 gate still closed: Cut is the remaining requirement",
		not bool(gate3_mid.get("allowed", true))
		and _unmet_text(gate3_mid).contains("Cut field action"))
	# Documented seam (see header): flags["field_actions"] is the
	# representation gym_requirements.gd specifies until the
	# field-action system writes it; the badge half of that system
	# was proven live at S4.
	var flags7: Dictionary = _flags(state)
	flags7["field_actions"] = ["cut"]
	state["story_flags"] = flags7
	_check("S7 gym 3 gate OPENS once Anne + Cut are both satisfied",
		bool(PUWCampaignStitch.can_start_gym_battle(
			state, "kanto_gym_3_surge").get("allowed", false)))

	# --------------------- S8: gym 3 through its authored script
	var gym3: Dictionary = _run_script(
		state, "gym_gate_kanto_gym_3_surge.json", true,
		GymProgression.badge_count(state))
	var gym3_runner: PUWEventRunner = gym3["runner"]
	var gym3_battle: Dictionary = gym3["battle"]
	_check("S8 gym 3 gate script completes",
		gym3_runner.is_finished() and not gym3_runner.has_error())
	_check("S8 gym 3 battle is Surge's roster battle",
		str(gym3_battle.get("roster_id", "")) == "kanto_gym_3_surge")
	_check("S8 gym 3 enemy party is 6 mons at the difficulty standard",
		_battle_valid(gym3_battle, 6))
	_check("S8 stitch records the gym 3 win",
		PUWCampaignStitch.record_gym_win(state, "kanto_gym_3_surge"))
	_level_party(state, 29)  # hard cap at 3 badges

	# ------------------------------------------------- S9: gym 4
	_gym_win_direct(state, "kanto_gym_4_erika", "S9 gym 4 Erika (Cut gate met)")
	_level_party(state, 40)  # hard cap at 4 badges

	# --------------------------- S10/S11: Rocket arc -> Scope
	var poster: Dictionary = _run_script(
		state, "celadon_game_corner_poster.json", true)
	var poster_runner: PUWEventRunner = poster["runner"]
	_check("S10 Game Corner poster script completes",
		poster_runner.is_finished() and not poster_runner.has_error())
	_check("S10 rocket_hideout_revealed set",
		bool(_flags(state).get("rocket_hideout_revealed", false)))
	var hideout: Dictionary = _run_script(
		state, "rocket_hideout_giovanni.json", true)
	var hideout_runner: PUWEventRunner = hideout["runner"]
	_check("S11 Hideout Giovanni script completes",
		hideout_runner.is_finished() and not hideout_runner.has_error())
	_check("S11 the Silph Scope is in the bag",
		int(_bag(state).get("silph-scope", 0)) == 1)
	_check("S11 rocket_hideout_cleared set",
		bool(_flags(state).get("rocket_hideout_cleared", false)))
	_check("S11 the Hideout battle built at the standard",
		_battle_valid(hideout["battle"], 0))

	# --------------------- S12: Tower rescue BEFORE the Flute
	var flute_early: Dictionary = _run_script(
		state, "mr_fujis_house_flute.json", true)
	var flute_early_runner: PUWEventRunner = flute_early["runner"]
	_check("S12 the Flute script REFUSES before the Tower rescue",
		not flute_early_runner.is_finished())
	var tower: Dictionary = _run_script(
		state, "pokemon_tower_fuji_rescue.json", true)
	var tower_runner: PUWEventRunner = tower["runner"]
	_check("S12 Tower Fuji rescue completes",
		tower_runner.is_finished() and not tower_runner.has_error())
	_check("S12 fuji_rescued set",
		bool(_flags(state).get("fuji_rescued", false)))
	var flute: Dictionary = _run_script(state, "mr_fujis_house_flute.json", true)
	var flute_runner: PUWEventRunner = flute["runner"]
	_check("S12 the Flute script completes after the rescue",
		flute_runner.is_finished() and not flute_runner.has_error())
	_check("S12 the Poke Flute is in the bag",
		int(_bag(state).get("poke-flute", 0)) == 1)
	_check("S12 poke_flute_received set",
		bool(_flags(state).get("poke_flute_received", false)))

	# ------------------------------------------------ S13: gym 5
	_gym_win_direct(state, "kanto_gym_5_koga", "S13 gym 5 Koga")
	_level_party(state, 43)  # hard cap at 5 badges

	# --------------------------- S14: gym 6 gate refuses early
	var gate6_early: Dictionary = PUWCampaignStitch.can_start_gym_battle(
		state, "kanto_gym_6_sabrina")
	_check("S14 gym 6 gate REFUSES before Silph Co.",
		not bool(gate6_early.get("allowed", true)))
	_check("S14 the refusal names both Silph requirements",
		_unmet_text(gate6_early).contains("Silph Co")
		and _unmet_text(gate6_early).contains("Saffron"))
	_check("S14 stitch refuses to record a gated gym 6 win",
		not PUWCampaignStitch.record_gym_win(state, "kanto_gym_6_sabrina"))

	# --------------------- S15: Silph Co. -> Saffron access
	var silph: Dictionary = _run_script(state, "silph_co_liberation.json", true)
	var silph_runner: PUWEventRunner = silph["runner"]
	_check("S15 Silph Co. liberation completes",
		silph_runner.is_finished() and not silph_runner.has_error())
	_check("S15 silph_co_cleared set (consumed by the gym 6 gate)",
		bool(_flags(state).get("silph_co_cleared", false)))
	_check("S15 saffron_access set (consumed by the gym 6 gate)",
		bool(_flags(state).get("saffron_access", false)))
	_check("S15 the Master Ball is in the bag",
		int(_bag(state).get("master-ball", 0)) == 1)
	_check("S15 the Silph rival battle built at the standard",
		_battle_valid(silph["battle"], 0))
	_check("S15 gym 6 gate OPENS after Silph Co.",
		bool(PUWCampaignStitch.can_start_gym_battle(
			state, "kanto_gym_6_sabrina").get("allowed", false)))

	# -------------------- S16: gym 6 through its authored script
	var gym6: Dictionary = _run_script(
		state, "gym_gate_kanto_gym_6_sabrina.json", true,
		GymProgression.badge_count(state))
	var gym6_runner: PUWEventRunner = gym6["runner"]
	var gym6_battle: Dictionary = gym6["battle"]
	_check("S16 gym 6 gate script completes",
		gym6_runner.is_finished() and not gym6_runner.has_error())
	_check("S16 gym 6 battle is Sabrina's roster battle",
		str(gym6_battle.get("roster_id", "")) == "kanto_gym_6_sabrina")
	_check("S16 gym 6 enemy party is 6 mons at the difficulty standard",
		_battle_valid(gym6_battle, 6))
	_check("S16 stitch records the gym 6 win",
		PUWCampaignStitch.record_gym_win(state, "kanto_gym_6_sabrina"))
	_level_party(state, 47)  # hard cap at 6 badges

	# --------------------- S17: gym 8 refuses at 6 badges (order)
	_check("S17 gym 8 gate REFUSES with only 6 Kanto badges",
		not bool(PUWCampaignStitch.can_start_gym_battle(
			state, "kanto_gym_8_giovanni").get("allowed", true)))

	# --------------------- S18: gym 7 and the Secret Key gate
	var gate7_early: Dictionary = PUWCampaignStitch.can_start_gym_battle(
		state, "kanto_gym_7_blaine")
	_check("S18 gym 7 gate REFUSES without the Secret Key",
		not bool(gate7_early.get("allowed", true)))
	_check("S18 the refusal names the Secret Key item",
		_unmet_text(gate7_early).contains("Secret Key"))
	# NAMED IN-FLIGHT DEPENDENCY (see header): the Secret Key is
	# an item-ball placement in PokemonMansionB1F; the pickup
	# system that grants it (code_prep_kanto_item_fixes F1) is
	# still in flight. The walk places the key as that system's
	# documented seam -- the same convention the events suite
	# used for the Tri-Pass -- and proves everything downstream.
	var bag18: Dictionary = _bag(state)
	bag18["secret_key"] = 1
	state["bag"] = bag18
	_check("S18 gym 7 gate OPENS with the key (pickup trigger = named dependency)",
		bool(PUWCampaignStitch.can_start_gym_battle(
			state, "kanto_gym_7_blaine").get("allowed", false)))
	_gym_win_direct(state, "kanto_gym_7_blaine", "S18 gym 7 Blaine")
	_level_party(state, 50)  # hard cap at 7 badges

	# ------------------------------------------------ S19: gym 8
	_gym_win_direct(state, "kanto_gym_8_giovanni", "S19 gym 8 Giovanni")
	_check("S19 all 8 Kanto badges held",
		GymProgression.badge_count(state) == 8
		and PUWGymRequirements.badge_count_for_region(state, "kanto") == 8)

	# --------------------- S20: Victory Road beats -> the League
	_check("S20 the League refuses before the gatekeeper beat",
		not PUWCampaignStitch.can_enter_elite_four(state))
	_check("S20 gatekeeper win records (Victory Road rival beat)",
		PUWCampaignStitch.record_gatekeeper_win(state))
	_check("S20 the League still refuses before the Runner-Up beat",
		not PUWCampaignStitch.can_enter_elite_four(state))
	_check("S20 Runner-Up win records",
		PUWCampaignStitch.record_runner_up_win(state))
	_check("S20 the League OPENS with 8 badges + both beats",
		PUWCampaignStitch.can_enter_elite_four(state))
	_check("S20 start_elite_four runs",
		PUWCampaignStitch.start_elite_four(state))
	_check("S20 stage is elite_four",
		PUWCampaignStitch.stage(state) == "elite_four")
	var sequence: Array = PUWCampaignStitch.elite_four_sequence(state)
	_check("S20 the gauntlet is 4 Elite Four + the resolved Champion",
		sequence.size() == 5
		and str(sequence[4]) == str(_flags(state).get("champion_id", "")))

	# --------------------- S21: the gauntlet at the standard
	_level_party(state, 55)
	var members: Array = ["LORELEI", "BRUNO", "AGATHA", "LANCE"]
	for i in range(4):
		_check("S21 current opponent is sequence entry " + str(i),
			_current_opponent(state)
			== str(sequence[i]))
		var e4_battle: Dictionary = _entry.start_elite_four_battle(
			str(members[i]), 55, "singles", _rng, "kanto", 1, "")
		_check("S21 " + str(members[i]) + " fields 6 mons at the difficulty standard",
			_battle_valid(e4_battle, 6))
		_check("S21 win over " + str(members[i]) + " records",
			PUWCampaignStitch.record_elite_four_win(state))
	_check("S21 current opponent is the Champion",
		_current_opponent(state)
		== str(sequence[4]))
	var champ_battle: Dictionary = _entry.start_elite_four_battle(
		"CHAMPION", 55, "singles", _rng, "kanto", 1, "")
	_check("S21 the Champion fields 6 mons at the difficulty standard",
		_battle_valid(champ_battle, 6))
	_check("S21 the Champion win records",
		PUWCampaignStitch.record_elite_four_win(state))
	_check("S21 the champion story flag is set",
		bool(_flags(state).get("champion", false)))
	_check("S21 record_champion_win(state, \"kanto\") took effect: region beaten",
		PUWRegionState.region_beaten(state, "kanto"))
	_check("S21 the Hall of Fame was entered",
		bool(_flags(state).get("hall_of_fame_entered", false)))
	_check("S21 stage is hall_of_fame",
		PUWCampaignStitch.stage(state) == "hall_of_fame")

	# --------------------- S22: Mewtwo's gate opens post-Champion
	var record: Dictionary = PUWFixedEncounters.record_for(
		"cerulean_cave_mewtwo")
	_check("S22 the Mewtwo fixed-encounter record exists",
		not record.is_empty())
	var fresh: Dictionary = PUWCampaignStitch.new_game_state(
		"custom_female", "RED")
	PUWCampaignStitch.complete_setup(fresh)
	_check("S22 Mewtwo's gate REFUSES a pre-Champion state, naming the flag",
		not PUWFixedEncounters.access_allowed(fresh, record)
		and PUWFixedEncounters.access_gate_result(fresh, record)["unmet"]
			.contains("champion"))
	_check("S22 Mewtwo's gate OPENS on the walk's post-Champion state",
		PUWFixedEncounters.access_allowed(state, record))
	_check("S22 the encounter is available",
		PUWFixedEncounters.is_available(state, record))
	_level_party(state, 70)
	var identity_v: Variant = record.get("battle_identity", [])
	var identity: Array = identity_v if identity_v is Array else []
	var mewtwo_battle: Dictionary = _entry.start_scripted_battle(
		identity, 70, "singles", _rng, "")
	var m_party_v: Variant = mewtwo_battle.get("enemy_party", [])
	var m_party: Array = m_party_v if m_party_v is Array else []
	_check("S22 the encounter's own mon leads the built party: Mewtwo",
		m_party.size() >= 1
		and str((m_party[0] as Dictionary).get("species_slug", "")) == "mewtwo")
	_check("S22 Mewtwo stands at the record's level 70 (= the player's max)",
		m_party.size() >= 1
		and int((m_party[0] as Dictionary).get("level", 0)) == 70)
	var m_verdict: Dictionary = PUWBattleEntry.validate_built_party(
		m_party, 6, {})
	_check("S22 the built party validates at the standard (the layer fills scripted parties to 6)",
		bool(m_verdict.get("ok", false)))
	_check("S22 fleeing does NOT consume the encounter (source semantics)",
		not PUWFixedEncounters.record_outcome(state, record, "ran")
		and PUWFixedEncounters.is_available(state, record))
	_check("S22 catching consumes it, once per save",
		PUWFixedEncounters.record_outcome(state, record, "caught")
		and bool(_flags(state).get("mewtwo_resolved", false))
		and not PUWFixedEncounters.is_available(state, record))

	# --------------------- S23: the FLAG SETTER MAP (computed)
	# Setters from the authored scripts themselves.
	var script_setters: Dictionary = {}
	var consumed: Dictionary = {}
	var dir: DirAccess = DirAccess.open(EVENTS_DIR)
	_check("S23 the events directory reads", dir != null)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var script: Dictionary = _load_json(EVENTS_DIR + file_name)
				var steps_v: Variant = script.get("steps", [])
				var steps: Array = steps_v if steps_v is Array else []
				for step_v in steps:
					if step_v is Dictionary:
						var step: Dictionary = step_v
						if str(step.get("op", "")) == "set_flag":
							script_setters[str(step.get("flag", ""))] = file_name
				var req_v: Variant = script.get("requires", {})
				var req: Dictionary = req_v if req_v is Dictionary else {}
				var req_flags_v: Variant = req.get("flags", [])
				var req_flags: Array = req_flags_v if req_flags_v is Array else []
				for rf_v in req_flags:
					consumed[str(rf_v)] = "event script " + file_name
				if str(req.get("min_stage", "")) == "champion":
					consumed["champion"] = "event script " + file_name + " (min_stage)"
			file_name = dir.get_next()
		dir.list_dir_end()
	# Setters inside the stitch (each one exercised by this walk).
	var stitch_setters: Dictionary = {
		"clues_seen": "PUWCampaignStitch.record_clues_seen",
		"oak_picks_done": "PUWCampaignStitch.grant_oak_picks",
		"gatekeeper_beat": "PUWCampaignStitch.record_gatekeeper_win",
		"runner_up_beat": "PUWCampaignStitch.record_runner_up_win",
		"champion": "PUWCampaignStitch.record_elite_four_win -> PUWRegionState.record_champion_win",
	}
	# Consumed flags: gym requirements (story_flag type).
	var gym_data: Dictionary = _load_json("res://data/gym_requirements.json")
	var gyms_v: Variant = gym_data.get("gyms", [])
	var gym_list: Array = gyms_v if gyms_v is Array else []
	for gym_v in gym_list:
		if gym_v is Dictionary:
			var gym_rec: Dictionary = gym_v
			var reqs_v: Variant = gym_rec.get("requirements", [])
			var reqs: Array = reqs_v if reqs_v is Array else []
			for req_v2 in reqs:
				if req_v2 is Dictionary:
					var req2: Dictionary = req_v2
					if str(req2.get("type", "")) == "story_flag":
						consumed[str(req2.get("flag", ""))] = "gym " + str(gym_rec.get("gym_id", ""))
	# Consumed flags: fixed-encounter gates.
	var fe_data: Dictionary = _load_json("res://data/fixed_encounters.json")
	var fe_v: Variant = fe_data.get("fixed_encounters", [])
	var fe_list: Array = fe_v if fe_v is Array else []
	for rec_v in fe_list:
		if rec_v is Dictionary:
			var rec: Dictionary = rec_v
			var gate_v: Variant = rec.get("access_gate", {})
			if gate_v is Dictionary:
				var gate: Dictionary = gate_v
				if str(gate.get("type", "")) == "story_flag":
					consumed[str(gate.get("flag", ""))] = "fixed encounter " + str(rec.get("id", ""))
	# The verdict: every consumed flag has a named setter.
	var unmapped: Array = []
	for flag_v in consumed.keys():
		var flag: String = str(flag_v)
		var setter: String = ""
		if script_setters.has(flag):
			setter = "script " + str(script_setters[flag])
		elif stitch_setters.has(flag):
			setter = str(stitch_setters[flag])
		print("SETTER: ", flag, " <- ", setter,
			"  (consumed by ", str(consumed[flag]), ")")
		if setter == "":
			unmapped.append(flag)
	_check("S23 EVERY consumed story flag has a named setter (the audit break is closed)",
		unmapped.is_empty())
	_check("S23 the audit's three orphan flags specifically: ss_anne_cleared",
		str(script_setters.get("ss_anne_cleared", "")) == "ss_anne_captain.json")
	_check("S23 the audit's three orphan flags specifically: silph_co_cleared",
		str(script_setters.get("silph_co_cleared", "")) == "silph_co_liberation.json")
	_check("S23 the audit's three orphan flags specifically: saffron_access",
		str(script_setters.get("saffron_access", "")) == "silph_co_liberation.json")

	print("SUMMARY: spine_walk_tests passed=", _passed, " failed=", _failed)
	quit(1 if _failed > 0 else 0)
