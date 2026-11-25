extends SceneTree
## Pokeathlon system tests (code prep, 2026-11-23).
## Run: godot --headless --script res://tests/pokeathlon_tests.gd
##
## Covers, against COPIES of the real pack systems it integrates
## with (PUWRegionState, PUWSaveManager):
## - the [DC] profile derivation from [HELD] battle base stats;
## - the [PUB] authentic daily-variation formula, nature table
##   and star-delta bands, with min/max clamping;
## - Aprijuice blending / drinking / boxing-clear [PUB + HELD];
## - all ten [PUB] event Athlete-Point conversions + record
##   thresholds;
## - course flow: entry gating (Johto only), team/mode refusals,
##   bonuses, placement, win payout, medals, records, the
##   [HELD] global-score formula and trophy thresholds;
## - the points ledger: cap 99,999 [HELD], spending, Data Cards,
##   once-daily Athlete Shop flags;
## - canon: no badge, no Champion credit, ever;
## - PERMADEATH: the collection + faint projection of a rich
##   save is byte-identical across a full session, and a save
##   round-trip keeps the Pokeathlon record intact.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _finish() -> void:
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _init() -> void:
	_run.call_deferred()


# ----------------------------------------------------------------
# Fixtures
# ----------------------------------------------------------------

func _mon(species: String, serial: String) -> Dictionary:
	return {
		"name": species,
		"species": species,
		"mon_id": "puw-" + serial + "-a1b2c3",
		"evo_family": species + "_family",
		"hp": 20,
		"max_hp": 20,
		"friendship": 0,
	}


func _fresh_state(region_id: String = "johto") -> Dictionary:
	var party: Array = [_mon("pikachu", "000001")]
	var boxes: Array = [_mon("eevee", "000002")]
	var flags: Dictionary = {"region_id": region_id}
	var state: Dictionary = PUWSaveManager.build_state(party, boxes, {"poke-ball": 5}, 1000, [], [], [], flags, {})
	state["locked_evo_families"] = {"pidgey_family": true}
	state["fainting_ledger"] = [{"name": "pidgey", "evo_family": "pidgey_family", "format": "standard"}]
	PUWRegionState.ensure_regions(state)
	PUWRegionState.enter_region(state, region_id)
	return state


func _team_mon(base_stats: Dictionary) -> Dictionary:
	var mon: Dictionary = _mon("athlete", "000100")
	mon["base_stats"] = base_stats
	return mon


func _pikachu_stats() -> Dictionary:
	# [HELD] Showdown conversion values for Pikachu.
	return {"hp": 35, "atk": 55, "def": 40, "spa": 50, "spd": 50, "spe": 90}


func _team() -> Array:
	return [
		{"species_id": 25, "species": "pikachu", "mon": _team_mon(_pikachu_stats())},
		{"species_id": 150, "species": "mewtwo", "mon": _team_mon({"hp": 106, "atk": 110, "def": 90, "spa": 154, "spd": 90, "spe": 130})},
		{"species_id": 6, "species": "charizard", "mon": _team_mon({"hp": 78, "atk": 84, "def": 78, "spa": 109, "spd": 85, "spe": 100})},
	]


func _projection(state: Dictionary) -> String:
	var proj: Dictionary = {
		"party": state.get("party", []),
		"boxes": state.get("boxes", []),
		"badges": state.get("badges", []),
		"locked": state.get("locked_evo_families", {}),
		"ledger": state.get("fainting_ledger", []),
	}
	var root_value: Variant = state.get("regions", {})
	if root_value is Dictionary:
		var root: Dictionary = root_value
		var records_value: Variant = root.get("regions", {})
		var records: Dictionary = {}
		if records_value is Dictionary:
			records = records_value
		var slim: Dictionary = {}
		for region_id: Variant in records.keys():
			var record_value: Variant = records.get(region_id, {})
			if record_value is Dictionary:
				var record: Dictionary = record_value
				slim[str(region_id)] = {
					"party": record.get("party", []),
					"boxes": record.get("boxes", []),
					"badges": record.get("badges", []),
					"champion_beaten": record.get("champion_beaten", false),
				}
		proj["region_records"] = slim
	return JSON.stringify(proj)


# ----------------------------------------------------------------
# Suite
# ----------------------------------------------------------------

func _run() -> void:
	# --- Derivation [DC] from [HELD] base stats ---
	var pika_profile: Dictionary = PUWPokeathlonPerf.derive_profile(_pikachu_stats())
	_check("derive: pikachu speed base 4 (spe 90)", int((pika_profile["speed"] as Dictionary)["base"]) == 4)
	_check("derive: pikachu speed min/max 3/5", int((pika_profile["speed"] as Dictionary)["min"]) == 3 and int((pika_profile["speed"] as Dictionary)["max"]) == 5)
	_check("derive: pikachu power base 2 (atk 55)", int((pika_profile["power"] as Dictionary)["base"]) == 2)
	_check("derive: pikachu skill from spd, stamina from def, jump from spa", int((pika_profile["skill"] as Dictionary)["base"]) == 2 and int((pika_profile["stamina"] as Dictionary)["base"]) == 2 and int((pika_profile["jump"] as Dictionary)["base"]) == 2)
	_check("derive: total base stars pikachu 12", PUWPokeathlonPerf.total_base_stars(pika_profile) == 12)
	_check("derive: bands floor/ceiling", PUWPokeathlonPerf.stars_for_base_stat(30) == 1 and PUWPokeathlonPerf.stars_for_base_stat(255) == 5)
	var explicit_mon: Dictionary = {"pokeathlon_profile": {"skill": {"min": 1, "base": 2, "max": 3}}, "base_stats": _pikachu_stats()}
	var explicit_profile: Dictionary = PUWPokeathlonPerf.profile_of(explicit_mon)
	_check("profile: explicit profile wins over derivation", int((explicit_profile["skill"] as Dictionary)["max"]) == 3)
	var bare_profile: Dictionary = PUWPokeathlonPerf.profile_of({})
	_check("profile: bare mon fallback 2/3/4", int((bare_profile["speed"] as Dictionary)["base"]) == 3)

	# --- Star-delta bands [PUB] ---
	_check("bands: -120 -> -4, -119 -> -3", PUWPokeathlonPerf.star_delta(-120) == -4 and PUWPokeathlonPerf.star_delta(-119) == -3)
	_check("bands: -40 -> -2, -39 -> -1, -15 -> -1", PUWPokeathlonPerf.star_delta(-40) == -2 and PUWPokeathlonPerf.star_delta(-39) == -1 and PUWPokeathlonPerf.star_delta(-15) == -1)
	_check("bands: -14..14 -> 0", PUWPokeathlonPerf.star_delta(-14) == 0 and PUWPokeathlonPerf.star_delta(14) == 0)
	_check("bands: 15 -> 1, 40 -> 2, 80 -> 3, 120 -> 4", PUWPokeathlonPerf.star_delta(15) == 1 and PUWPokeathlonPerf.star_delta(40) == 2 and PUWPokeathlonPerf.star_delta(80) == 3 and PUWPokeathlonPerf.star_delta(120) == 4)

	# --- Raw daily formula [PUB] ---
	# pid 12345: power digit (ones) = 5, X=0, D=23:
	# ((26*30 + 5) mod 10)*2-9 = 1; adamant Z(power) = +35.
	_check("raw: adamant power pid 12345 D23 = 36", PUWPokeathlonPerf.raw_value("power", 23, 12345, "adamant", 0) == 36)
	# speed digit (ten-thousands) = 1, X=4: ((27*20 + 1) mod 10)*2-9 = -7; adamant Z(speed) = 0.
	_check("raw: adamant speed pid 12345 D23 = -7", PUWPokeathlonPerf.raw_value("speed", 23, 12345, "adamant", 0) == -7)
	_check("raw: neutral natures use 10 (hardy power)", PUWPokeathlonPerf.nature_z("hardy", "power") == 10 and PUWPokeathlonPerf.nature_z("hardy", "speed") == -10)
	_check("raw: unknown nature Z 0", PUWPokeathlonPerf.nature_z("???", "power") == 0)
	_check("pid digits", PUWPokeathlonPerf.pid_digit(12345, 0) == 5 and PUWPokeathlonPerf.pid_digit(12345, 4) == 1)

	# --- Effective stars with clamping ---
	var jumper: Dictionary = {
		"pokeathlon_profile": {"jump": {"min": 1, "base": 2, "max": 3}},
		"nature": "modest", "pid": 9000,
	}
	var jump_stars: Dictionary = PUWPokeathlonPerf.effective_stars(jumper, 23)
	_check("effective: modest jump rises to species max 3", int(jump_stars["jump"]) == 3)
	jumper["aprijuice"] = {"modifiers": {"jump": 80}}
	var juiced_stars: Dictionary = PUWPokeathlonPerf.effective_stars(jumper, 23)
	_check("effective: aprijuice cannot pass species max", int(juiced_stars["jump"]) == 3)

	# --- Aprijuice blending [PUB] ---
	var red2: Dictionary = PUWPokeathlonPerf.blend(["red", "red"])
	var red2_flavors: Dictionary = red2["flavors"]
	_check("blend: 2x red = spicy 8, sour clamped 0", int(red2_flavors["spicy"]) == 8 and int(red2_flavors["sour"]) == 0)
	_check("blend: uses reset to 3, type power", int(red2["uses"]) == 3 and PUWPokeathlonPerf.juice_type(red2) == "power")
	var black1: Dictionary = PUWPokeathlonPerf.blend(["black"])
	_check("blend: black = +2 all", int((black1["flavors"] as Dictionary)["dry"]) == 2 and PUWPokeathlonPerf.juice_level(black1) == 10)
	var mild_start: Dictionary = {"flavors": {"spicy": 20, "sour": 10, "dry": 0, "bitter": 0, "sweet": 0}, "mildness": 50, "uses": 1}
	var mild_blend: Dictionary = PUWPokeathlonPerf.blend(["blue"], mild_start)
	_check("blend: off-flavor raise costs 10 mildness", int(mild_blend["mildness"]) == 40 and int((mild_blend["flavors"] as Dictionary)["dry"]) == 4)
	var big_start: Dictionary = {"flavors": {"spicy": 63, "sour": 63, "dry": 0, "bitter": 0, "sweet": 0}, "mildness": 0, "uses": 1}
	var big_blend: Dictionary = PUWPokeathlonPerf.blend(["black"], big_start)
	_check("blend: sum trimmed to level 100", PUWPokeathlonPerf.juice_level(big_blend) == 100)
	var walked: Dictionary = PUWPokeathlonPerf.walk_steps({"flavors": {}, "mildness": 250, "uses": 1}, 1000)
	_check("blend: 100 steps = +1 mildness, cap 255", int(walked["mildness"]) == 255)

	# --- Aprijuice drinking [PUB] ---
	var holden: Dictionary = {"flavors": {"spicy": 22, "sour": 10, "dry": 0, "bitter": 0, "sweet": 0}, "mildness": 116, "uses": 3}
	var holden_mods: Dictionary = PUWPokeathlonPerf.drink_modifiers(holden)
	_check("drink: highest flavor floor(22*1.5)+10 = 43 power", int(holden_mods["power"]) == 43)
	_check("drink: second flavor floor(10*1.5) = 15 stamina", int(holden_mods["stamina"]) == 15)
	_check("drink: lowest flavor mildness penalty -19 speed", int(holden_mods["speed"]) == -19)
	var max_mild: Dictionary = {"flavors": {"spicy": 22, "sour": 10, "dry": 0, "bitter": 0, "sweet": 0}, "mildness": 255, "uses": 3}
	_check("drink: mildness 255 penalty is 0.1x = -3", int(PUWPokeathlonPerf.drink_modifiers(max_mild)["speed"]) == -3)
	var drinker: Dictionary = _mon("eevee", "000777")
	_check("drink: zero-use juice refused", not PUWPokeathlonPerf.apply_juice(drinker, {"flavors": {}, "mildness": 0, "uses": 0}))
	_check("drink: apply sets modifiers", PUWPokeathlonPerf.apply_juice(drinker, holden) and int(PUWPokeathlonPerf.aprijuice_modifiers_of(drinker)["power"]) == 43)
	PUWPokeathlonPerf.clear_juice(drinker)
	_check("drink: boxing clears juice", PUWPokeathlonPerf.aprijuice_modifiers_of(drinker).is_empty())
	_check("vendor price: fame 0 clamps to 100", PUWPokeathlonPerf.vendor_price(0, holden) == 100)
	_check("vendor price: fame 10000 + level 32 = 1016", PUWPokeathlonPerf.vendor_price(10000, holden) == 1016)

	# --- Event conversions [PUB] ---
	_check("points: hurdle 100s = 115", PUWPokeathlonSystem.athlete_points("hurdle_dash", 100.0) == 115)
	_check("points: hurdle 80s = 143, 0s = 0", PUWPokeathlonSystem.athlete_points("hurdle_dash", 80.0) == 143 and PUWPokeathlonSystem.athlete_points("hurdle_dash", 0.0) == 0)
	_check("points: ring drop 50 = 75, capped", PUWPokeathlonSystem.athlete_points("ring_drop", 50.0) == 75 and PUWPokeathlonSystem.athlete_points("ring_drop", 200.0) == 200)
	_check("points: snow 30 = 90, capped", PUWPokeathlonSystem.athlete_points("snow_throw", 30.0) == 90 and PUWPokeathlonSystem.athlete_points("snow_throw", 100.0) == 200)
	_check("points: lamp 350 = 100", PUWPokeathlonSystem.athlete_points("lamp_jump", 350.0) == 100)
	_check("points: relay 15.5 laps = 155", PUWPokeathlonSystem.athlete_points("relay_run", 15.5) == 155)
	_check("points: block = raw, capped", PUWPokeathlonSystem.athlete_points("block_smash", 130.0) == 130 and PUWPokeathlonSystem.athlete_points("block_smash", 250.0) == 200)
	_check("points: circle 66 perfect = 198", PUWPokeathlonSystem.athlete_points("circle_push", 66.0) == 198)
	_check("points: disc 0 = 30, 40 = 121", PUWPokeathlonSystem.athlete_points("disc_catch", 0.0) == 30 and PUWPokeathlonSystem.athlete_points("disc_catch", 40.0) == 121)
	_check("points: pennant 35 = 105, capped", PUWPokeathlonSystem.athlete_points("pennant_capture", 35.0) == 105 and PUWPokeathlonSystem.athlete_points("pennant_capture", 70.0) == 200)
	_check("points: goal roll 3 vs [1,2,5] = 95", PUWPokeathlonSystem.athlete_points("goal_roll", 3.0, {"opponent_scores": [1, 2, 5]}) == 95)
	_check("points: goal roll 9 vs [0,0,0] = 145", PUWPokeathlonSystem.athlete_points("goal_roll", 9.0, {"opponent_scores": [0, 0, 0]}) == 145)
	_check("points: unknown event = 0", PUWPokeathlonSystem.athlete_points("nope", 10.0) == 0)
	var hurdle_flags: Dictionary = PUWPokeathlonSystem.record_flags("hurdle_dash", 80.0)
	_check("records: hurdle 80s = record + potential", bool(hurdle_flags["record"]) and bool(hurdle_flags["potential"]))
	var snow_flags: Dictionary = PUWPokeathlonSystem.record_flags("snow_throw", 30.0)
	_check("records: snow 30 = record only", bool(snow_flags["record"]) and not bool(snow_flags["potential"]))

	# --- Entry gating + refusals ---
	var kanto_state: Dictionary = _fresh_state("kanto")
	_check("gate: cannot enter outside johto", not PUWPokeathlonSystem.can_enter(kanto_state))
	_check("gate: begin refused outside johto", PUWPokeathlonSystem.begin_course(kanto_state, "speed", _team()).is_empty())
	var state: Dictionary = _fresh_state("johto")
	_check("gate: can enter in johto", PUWPokeathlonSystem.can_enter(state))
	_check("refusal: team of 2", PUWPokeathlonSystem.begin_course(state, "speed", _team().slice(0, 2)).is_empty())
	_check("refusal: bad course", PUWPokeathlonSystem.begin_course(state, "nope", _team()).is_empty())
	_check("refusal: link mode stubbed out", PUWPokeathlonSystem.begin_course(state, "speed", _team(), "link").is_empty())
	_check("refusal: supreme locked", PUWPokeathlonSystem.begin_course(state, "speed", _team(), "supreme").is_empty())
	PUWPokeathlonSystem.set_supreme_unlocked(state, true)
	_check("supreme: begins once unlocked", not PUWPokeathlonSystem.begin_course(state, "speed", _team(), "supreme").is_empty())
	PUWPokeathlonSystem.cancel_run(state)

	# --- Full course run (permadeath projection around it) ---
	var before: String = _projection(state)
	var run: Dictionary = PUWPokeathlonSystem.begin_course(state, "speed", _team())
	_check("run: begins", not run.is_empty())
	_check("run: challenge stars = team total", int(run["challenge_stars"]) == 12 + 22 + 17)
	_check("run: second begin refused while active", PUWPokeathlonSystem.begin_course(state, "jump", _team()).is_empty())
	_check("run: wrong event refused", PUWPokeathlonSystem.record_event_result(state, "block_smash", 10.0) == -1)
	_check("run: hurdle recorded 115", PUWPokeathlonSystem.record_event_result(state, "hurdle_dash", 100.0, {"placed_first": true, "minutes": 2}) == 115)
	_check("run: duplicate event refused", PUWPokeathlonSystem.record_event_result(state, "hurdle_dash", 90.0) == -1)
	_check("run: finish refused while incomplete", PUWPokeathlonSystem.finish_course(state, [1, 2, 3]).is_empty())
	_check("run: pennant recorded 105", PUWPokeathlonSystem.record_event_result(state, "pennant_capture", 35.0) == 105)
	_check("run: relay recorded 120", PUWPokeathlonSystem.record_event_result(state, "relay_run", 12.0) == 120)
	var result: Dictionary = PUWPokeathlonSystem.finish_course(state, [300, 350, 200], {"no_miss": [true, false, false], "individual_scores": [5, 3, 2], "opponent_individual_best": 4.0, "effort_winner_is_player": false})
	_check("finish: event points 340", int(result["event_points"]) == 340)
	_check("finish: challenge bonus 75-51 = 24", int(result["challenge_bonus"]) == 24)
	_check("finish: no-miss 10 + leading 20", int(result["no_miss_bonus"]) == 10 and int(result["leading_bonus"]) == 20)
	_check("finish: total 394, placement 1, payout 494", int(result["total"]) == 394 and int(result["placement"]) == 1 and int(result["payout"]) == 494)
	_check("finish: balance 494", PUWPokeathlonSystem.points_balance(state) == 494)
	_check("medals: speed bit on all three species", PUWPokeathlonSystem.medal_bits(state, 25) == 1 and PUWPokeathlonSystem.medal_bits(state, 150) == 1 and PUWPokeathlonSystem.medal_bits(state, 6) == 1)
	_check("records: course max 394, event bests set", PUWPokeathlonSystem.global_score(state) == 394 + 340 + 3)
	_check("records: attempts + firsts + time", int(PUWPokeathlonSystem.athlon_state(state)["event_attempts"]["hurdle_dash"]) == 1 and int(PUWPokeathlonSystem.athlon_state(state)["event_firsts"]["hurdle_dash"]) == 1 and int(PUWPokeathlonSystem.athlon_state(state)["time_minutes"]) == 2)
	_check("canon: no badge, no champion from a win", PUWRegionState.region_badges(state, "johto").is_empty() and not PUWRegionState.region_beaten(state, "johto"))
	_check("permadeath: projection byte-identical across the run", _projection(state) == before)

	# --- Second run: collective trophy + placement loss ---
	var run2: Dictionary = PUWPokeathlonSystem.begin_course(state, "jump", _team())
	_check("run2: begins after finish", not run2.is_empty())
	PUWPokeathlonSystem.record_event_result(state, "lamp_jump", 500.0)
	PUWPokeathlonSystem.record_event_result(state, "disc_catch", 70.0)
	PUWPokeathlonSystem.record_event_result(state, "hurdle_dash", 80.0)
	var result2: Dictionary = PUWPokeathlonSystem.finish_course(state, [600, 100, 100], {})
	_check("run2: total 440 earns collective trophy", int(result2["total"]) == 440 and bool(result2["collective_trophy"]))
	_check("run2: placement 2, no win bonus, no medal", int(result2["placement"]) == 2 and int(result2["win_bonus"]) == 0 and PUWPokeathlonSystem.medal_bits(state, 25) == 1)
	_check("run2: payout is total only", PUWPokeathlonSystem.points_balance(state) == 494 + 440)

	# --- Ledger: spending, cards, daily shop ---
	_check("ledger: overspend refused", not PUWPokeathlonSystem.spend_points(state, 100000))
	_check("ledger: spend 34 ok", PUWPokeathlonSystem.spend_points(state, 34) and PUWPokeathlonSystem.points_balance(state) == 900)
	_check("cards: buy card 0 for 200", PUWPokeathlonSystem.buy_data_card(state, 0) and PUWPokeathlonSystem.points_balance(state) == 700)
	_check("cards: duplicate refused", not PUWPokeathlonSystem.buy_data_card(state, 0))
	_check("cards: index 27 refused", not PUWPokeathlonSystem.buy_data_card(state, 27))
	_check("shop: buy slot 0 day 1", PUWPokeathlonSystem.buy_daily_shop_item(state, 0, 100, 1) and PUWPokeathlonSystem.points_balance(state) == 600)
	_check("shop: same slot same day refused", not PUWPokeathlonSystem.buy_daily_shop_item(state, 0, 100, 1))
	_check("shop: same slot next day ok", PUWPokeathlonSystem.buy_daily_shop_item(state, 0, 100, 2) and PUWPokeathlonSystem.points_balance(state) == 500)
	_check("shop: slot 12 refused", not PUWPokeathlonSystem.buy_daily_shop_item(state, 12, 100, 2))

	# --- Points cap [HELD 99,999] ---
	PUWPokeathlonSystem.athlon_state(state)["points"] = 99995
	var run3: Dictionary = PUWPokeathlonSystem.begin_course(state, "power", _team())
	PUWPokeathlonSystem.record_event_result(state, "block_smash", 80.0)
	PUWPokeathlonSystem.record_event_result(state, "circle_push", 40.0)
	PUWPokeathlonSystem.record_event_result(state, "goal_roll", 3.0, {"opponent_scores": [0, 0, 0]})
	PUWPokeathlonSystem.finish_course(state, [0, 0, 0], {})
	_check("ledger: balance clamps at 99,999", PUWPokeathlonSystem.points_balance(state) == 99999)
	_check("medals: power bit added (bits 1|2 = 3)", PUWPokeathlonSystem.medal_bits(state, 25) == 3)

	# --- Medalist / trophies ---
	var champ_state: Dictionary = _fresh_state("johto")
	var medals: Dictionary = {}
	medals["25"] = 0b11111
	PUWPokeathlonSystem.athlon_state(champ_state)["medals"] = medals
	_check("medalist: all five bits", PUWPokeathlonSystem.is_medalist(champ_state, 25) and PUWPokeathlonSystem.medalist_count(champ_state) == 1)
	_check("trophies: 1 medalist = 1 trust trophy", PUWPokeathlonSystem.trust_trophy_count(champ_state) == 1)
	_check("trophies: low global score = 0 friendship trophies", PUWPokeathlonSystem.friendship_trophy_count(champ_state) == 0)

	# --- Save round-trip ---
	_check("save: writes", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("save: pokeathlon record survives round-trip", PUWPokeathlonSystem.points_balance(loaded) == 99999 and PUWPokeathlonSystem.medal_bits(loaded, 25) == 3)

	_finish()
