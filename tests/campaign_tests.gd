extends SceneTree
## Campaign flow tests for Pokemon Ultimate World.
## Run: godot --headless --script campaign_tests.gd
## Uses the real starters.json data file. Gym ids and the E4 sequence
## below are logic fixtures (labelled FIXTURE) that stand in for the
## gym/trainer data file; they test the rules, not game data.

var _passed: int = 0
var _failed: int = 0


func _load_starters() -> Dictionary:
	var f: FileAccess = FileAccess.open("res://starters.json", FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	print("PUW campaign flow tests — starting.")
	var starters_data: Dictionary = _load_starters()
	_check("starters_data_loaded", not starters_data.is_empty() and starters_data.get("starters", []).size() == 3)

	# --- Starter choice sets the right party ---
	var state: Dictionary = CampaignFlow.new_game_state("RED")
	var mon: Dictionary = CampaignFlow.choose_starter(state, starters_data, 1)
	_check("starter_species_is_bulbasaur", int(mon.get("species_id", 0)) == 1)
	_check("starter_level_5", int(mon.get("level", 0)) == 5)
	# Bulbasaur base HP 45 at level 5: floor(2*45*5/100) + 5 + 10 = 19.
	_check("starter_max_hp_from_base_stats", int(mon.get("max_hp", 0)) == 19)
	_check("starter_hp_full", int(mon.get("hp", 0)) == int(mon.get("max_hp", 0)))
	var party: Array = state.get("party", [])
	_check("party_has_one_member", party.size() == 1)
	var moves: Array = mon.get("moves", [])
	_check("starter_has_moves", moves.size() == 3)
	var first_move: Dictionary = moves[0]
	_check("starter_move_pp_set", int(first_move.get("pp", 0)) == int(first_move.get("max_pp", -1)) and int(first_move.get("pp", 0)) > 0)
	# A second starter choice must be refused.
	var second: Dictionary = CampaignFlow.choose_starter(state, starters_data, 4)
	_check("second_starter_refused", second.is_empty() and state.get("party", []).size() == 1)
	# A non-starter species must be refused on a fresh state.
	var state_b: Dictionary = CampaignFlow.new_game_state("BLUE")
	var bad: Dictionary = CampaignFlow.choose_starter(state_b, starters_data, 25)
	_check("non_starter_refused", bad.is_empty() and state_b.get("party", []).is_empty())

	# --- Rival picks the type-advantaged starter ---
	_check("rival_counters_grass_with_fire", CampaignFlow.rival_starter_for(starters_data, 1) == 4)
	_check("rival_counters_fire_with_water", CampaignFlow.rival_starter_for(starters_data, 4) == 7)
	_check("rival_counters_water_with_grass", CampaignFlow.rival_starter_for(starters_data, 7) == 1)

	# --- Rival trigger fires once, only when requirements are met ---
	var trig: Dictionary = {"id": "rival_route1", "required_flags": ["starter_chosen"], "min_badges": 0}
	_check("trigger_blocked_before_starter", not CampaignFlow.should_trigger(state_b, trig))
	_check("trigger_ready_after_starter", CampaignFlow.should_trigger(state, trig))
	CampaignFlow.mark_triggered(state, "rival_route1")
	_check("trigger_fires_once", not CampaignFlow.should_trigger(state, trig))

	# --- Pokemon Center heal restores HP / PP / status ---
	var hurt: Dictionary = CampaignFlow.build_starter(CampaignFlow.find_starter(starters_data, 4))
	hurt["hp"] = 3
	hurt["status"] = "PSN"
	var hurt_moves: Array = hurt.get("moves", [])
	var hm: Dictionary = hurt_moves[0]
	hm["pp"] = 0
	hurt["moves"] = hurt_moves
	var heal_party: Array = [hurt]
	_check("party_needs_healing_true", PokemonCenter.party_needs_healing(heal_party))
	PokemonCenter.heal_party(heal_party)
	_check("heal_restores_hp", int(hurt.get("hp", 0)) == int(hurt.get("max_hp", 0)))
	_check("heal_clears_status", str(hurt.get("status", "?")) == "")
	var healed_moves: Array = hurt.get("moves", [])
	var hmd: Dictionary = healed_moves[0]
	_check("heal_restores_pp", int(hmd.get("pp", 0)) == int(hmd.get("max_pp", 0)))
	_check("party_needs_healing_false_after", not PokemonCenter.party_needs_healing(heal_party))

	# --- Badge gates (FIXTURE gym ids) ---
	var prog: Dictionary = CampaignFlow.new_game_state("RED")
	for i: int in range(7):
		GymProgression.award_badge(prog, "fixture_badge_%d" % i)
	_check("seven_badges_counted", GymProgression.badge_count(prog) == 7)
	_check("e4_locked_at_seven_badges", not GymProgression.can_challenge_elite_four(prog))
	_check("duplicate_badge_refused", not GymProgression.award_badge(prog, "fixture_badge_0") and GymProgression.badge_count(prog) == 7)
	GymProgression.award_badge(prog, "fixture_badge_7")
	_check("e4_open_at_eight_badges", GymProgression.can_challenge_elite_four(prog))
	var gating: Dictionary = {"surf": "fixture_badge_4"}
	_check("field_move_gated_by_badge", GymProgression.can_use_field_move(prog, "surf", gating))
	_check("ungated_field_move_free", GymProgression.can_use_field_move(prog, "cut", gating))
	var prog_b: Dictionary = CampaignFlow.new_game_state("BLUE")
	_check("field_move_blocked_without_badge", not GymProgression.can_use_field_move(prog_b, "surf", gating))

	# --- Elite Four gauntlet + Hall of Fame (FIXTURE sequence) ---
	var champ: Dictionary = CampaignFlow.new_game_state("RED")
	CampaignFlow.choose_starter(champ, starters_data, 7)
	for i2: int in range(8):
		GymProgression.award_badge(champ, "fixture_badge_%d" % i2)
	var sequence: Array = ["fixture_e4_1", "fixture_e4_2", "fixture_e4_3", "fixture_e4_4", "fixture_champion"]
	_check("gauntlet_starts_with_badges", EliteFourFlow.start_gauntlet(champ, sequence))
	_check("gauntlet_first_opponent", EliteFourFlow.current_opponent(champ) == "fixture_e4_1")
	EliteFourFlow.record_win(champ)
	EliteFourFlow.record_win(champ)
	_check("gauntlet_advances", EliteFourFlow.current_opponent(champ) == "fixture_e4_3")
	EliteFourFlow.record_loss(champ)
	_check("loss_ends_run", EliteFourFlow.current_opponent(champ) == "" and champ.get("e4_run", {}).is_empty())
	EliteFourFlow.start_gauntlet(champ, sequence)
	for w: int in range(5):
		EliteFourFlow.record_win(champ)
	var hof: Array = champ.get("hall_of_fame", [])
	_check("hall_of_fame_entry_written", hof.size() == 1)
	if hof.size() == 1:
		var entry: Dictionary = hof[0]
		_check("hall_of_fame_has_party", entry.get("party", []).size() == 1 and int(entry.get("badge_count", 0)) == 8)
	var cflags: Dictionary = champ.get("flags", {})
	_check("champion_flag_set", bool(cflags.get("champion", false)))
	var locked: Dictionary = CampaignFlow.new_game_state("BLUE")
	_check("gauntlet_blocked_without_badges", not EliteFourFlow.start_gauntlet(locked, sequence))

	print("PUW campaign flow tests — done: %d passed, %d failed." % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
