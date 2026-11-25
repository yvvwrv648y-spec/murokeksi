class_name PUWPokeathlonSystem
extends RefCounted
## POKEATHLON CORE SYSTEM (code prep, 2026-11-23).
##
## Course/event scoring shell + points ledger + records/medals,
## on the [HELD] PKHeX HGSS save-structure shape (DESIGN.md).
##
## STATE: everything lives in the JOHTO region record
## (PUWRegionState) under its "pokeathlon" key -- the Dome is a
## Johto location, so a Johto fresh start is a fresh Pokathlon
## record, per region-lock canon. Entry requires the active
## region to be Johto.
##
## STUB BOUNDARY (honest): there is NO minigame presentation or
## input in this prep. The future minigame layer produces raw
## metrics (seconds, flags, hits, laps...) and placement context
## (opponent totals, no-miss flags, individual scores, effort
## tallies); this core converts, bonuses, places, pays, medals
## and records them. Opponents are inputs, never simulated.
##
## CANON: no battles are ever started; event "fainting" in the
## source games is a seconds-long minigame stun and is recorded
## only as a no-miss flag. PERMADEATH IS STRUCTURALLY UNTOUCHED:
## this module writes only the Johto record's "pokeathlon" key
## (juice writes to a mon dict live in PUWPokeathlonPerf). No
## badge is ever noted and no Champion win is ever recorded --
## medals are a local track. The suite proves the permadeath
## projection of a rich save byte-identical across a full
## session, and badges/champion flags unchanged.

const HOME_REGION: String = "johto"


# ----------------------------------------------------------------
# Region record access
# ----------------------------------------------------------------

static func _default_athlon_state() -> Dictionary:
	return {
		"points": 0,
		"lifetime_points_earned": 0,
		"sessions": 0,
		"placed_first": 0,
		"placed_last": 0,
		"bonuses_earned": 0,
		"time_minutes": 0,
		"counters": {},
		"event_firsts": {},
		"event_attempts": {},
		"event_best": {},
		"event_records": {},
		"course_records": {},
		"medals": {},
		"data_cards": 0,
		"daily_shop": 0,
		"daily_shop_day": -1,
		"supreme_unlocked": false,
		"current_run": {},
		"last_run": {},
	}


## The pokeathlon sub-record inside Johto's region record,
## created with fresh-start defaults on first touch.
static func athlon_state(state: Dictionary) -> Dictionary:
	var root: Dictionary = PUWRegionState.ensure_regions(state)
	var records_value: Variant = root.get("regions", {})
	var records: Dictionary = {}
	if records_value is Dictionary:
		records = records_value
	var record_value: Variant = records.get(HOME_REGION, {})
	var record: Dictionary = {}
	if record_value is Dictionary:
		record = record_value
	if record.is_empty():
		record = {
			"champion_beaten": false,
			"badges": [],
			"party": [],
			"boxes": [],
		}
	var athlon_value: Variant = record.get("pokeathlon", {})
	if athlon_value is Dictionary:
		var existing: Dictionary = athlon_value
		if not existing.is_empty():
			return existing
	var fresh: Dictionary = _default_athlon_state()
	record["pokeathlon"] = fresh
	records[HOME_REGION] = record
	root["regions"] = records
	state["regions"] = root
	return fresh


static func can_enter(state: Dictionary) -> bool:
	return PUWRegionState.active_region(state) == HOME_REGION


# ----------------------------------------------------------------
# Event scoring shell [PUB conversions]
# ----------------------------------------------------------------

## Convert one event's raw metric to Athlete Points, capped at
## EVENT_POINTS_CAP. context (goal_roll only): "opponent_scores"
## Array of the three opponents' goal-roll scores.
static func athlete_points(event_id: String, raw: float, context: Dictionary = {}) -> int:
	var points: int = 0
	match event_id:
		"hurdle_dash":
			if raw <= 0.0:
				return 0
			points = int(floor(11500.0 / raw))
		"ring_drop":
			points = int(floor(raw * 1.5))
		"snow_throw":
			points = int(raw) * 3
		"lamp_jump":
			points = int(floor(raw / 3.5))
		"relay_run":
			points = int(floor(raw * 10.0))
		"block_smash":
			points = int(raw)
		"circle_push":
			points = int(raw) * 3
		"disc_catch":
			# Flagged reading F2: typeset ambiguously in [PUB];
			# read as floor(30 + 120p / (12.5 + p)).
			if raw <= 0.0:
				points = 30
			else:
				points = int(floor(30.0 + 120.0 * raw / (12.5 + raw)))
		"pennant_capture":
			points = int(raw) * 3
		"goal_roll":
			var beaten: int = 0
			var opp_value: Variant = context.get("opponent_scores", [])
			if opp_value is Array:
				var opponents: Array = opp_value
				for opp: Variant in opponents:
					if raw > float(opp):
						beaten += 1
			var placing_bonus: int = int([0, 10, 20, 40][beaten])
			points = 60 + 5 * int(raw) + placing_bonus
		_:
			return 0
	return clampi(points, 0, PUWPokeathlonParams.EVENT_POINTS_CAP)


## Did a raw metric earn the event's 1st-place record /
## Potential trophy thresholds? [PUB]
static func record_flags(event_id: String, raw: float) -> Dictionary:
	var spec_value: Variant = PUWPokeathlonParams.EVENTS.get(event_id, {})
	if not (spec_value is Dictionary):
		return {"record": false, "potential": false}
	var spec: Dictionary = spec_value
	var record_line: float = float(spec.get("record", 0.0))
	var potential_line: float = float(spec.get("potential", 0.0))
	if bool(spec.get("lower_is_better", false)):
		return {"record": raw <= record_line, "potential": raw <= potential_line}
	return {"record": raw >= record_line, "potential": raw >= potential_line}


# ----------------------------------------------------------------
# Course runs
# ----------------------------------------------------------------

## Begin a course. team: exactly 3 entries, each
## {"species_id": int, "species": String, "mon": Dictionary}.
## mode: "single" | "supreme" | "link" (link is a constant-only
## stub -- no link courses in this prep; refused).
## Returns {} on refusal, else the run dict.
static func begin_course(state: Dictionary, course_id: String, team: Array, mode: String = "single") -> Dictionary:
	if not can_enter(state):
		return {}
	if not PUWPokeathlonParams.is_valid_course(course_id):
		return {}
	if team.size() != 3:
		return {}
	if mode == "link":
		return {}
	if not PUWPokeathlonParams.WIN_BONUS.has(mode):
		return {}
	var athlon: Dictionary = athlon_state(state)
	if mode == "supreme" and not bool(athlon.get("supreme_unlocked", false)):
		return {}
	var current_value: Variant = athlon.get("current_run", {})
	if current_value is Dictionary:
		var current: Dictionary = current_value
		if not current.is_empty():
			return {}
	var team_records: Array = []
	var challenge_stars: int = 0
	for entry_value: Variant in team:
		if not (entry_value is Dictionary):
			return {}
		var entry: Dictionary = entry_value
		var mon_value: Variant = entry.get("mon", {})
		var mon: Dictionary = {}
		if mon_value is Dictionary:
			mon = mon_value
		var profile: Dictionary = PUWPokeathlonPerf.profile_of(mon)
		challenge_stars += PUWPokeathlonPerf.total_base_stars(profile)
		team_records.append({
			"species_id": int(entry.get("species_id", 0)),
			"species": str(entry.get("species", "")),
			"profile": profile,
		})
	var run: Dictionary = {
		"course": course_id,
		"mode": mode,
		"team": team_records,
		"challenge_stars": challenge_stars,
		"events": {},
	}
	athlon["current_run"] = run
	athlon["sessions"] = mini(int(athlon.get("sessions", 0)) + 1, PUWPokeathlonParams.MAX_COUNTER)
	return run


## Record one finished event of the current run. raw is the
## event's raw metric; context carries presentation outputs:
## "opponent_scores" (goal_roll), "placed_first" (bool),
## "minutes" (int, time spent). Returns the Athlete Points,
## or -1 on refusal (no run / wrong event / duplicate).
static func record_event_result(state: Dictionary, event_id: String, raw: float, context: Dictionary = {}) -> int:
	var athlon: Dictionary = athlon_state(state)
	var run_value: Variant = athlon.get("current_run", {})
	if not (run_value is Dictionary):
		return -1
	var run: Dictionary = run_value
	if run.is_empty():
		return -1
	var course_id: String = str(run.get("course", ""))
	if not PUWPokeathlonParams.course_events(course_id).has(event_id):
		return -1
	var events_value: Variant = run.get("events", {})
	var events: Dictionary = {}
	if events_value is Dictionary:
		events = events_value
	if events.has(event_id):
		return -1
	var points: int = athlete_points(event_id, raw, context)
	var flags: Dictionary = record_flags(event_id, raw)
	events[event_id] = {
		"raw": raw,
		"points": points,
		"record": bool(flags.get("record", false)),
		"potential": bool(flags.get("potential", false)),
	}
	run["events"] = events
	# Bookkeeping [HELD shapes]: attempts, best, firsts, time.
	var attempts_value: Variant = athlon.get("event_attempts", {})
	var attempts: Dictionary = {}
	if attempts_value is Dictionary:
		attempts = attempts_value
	attempts[event_id] = mini(int(attempts.get(event_id, 0)) + 1, PUWPokeathlonParams.MAX_ATTEMPTS)
	athlon["event_attempts"] = attempts
	var best_value: Variant = athlon.get("event_best", {})
	var best: Dictionary = {}
	if best_value is Dictionary:
		best = best_value
	if points > int(best.get(event_id, 0)):
		best[event_id] = points
		var records_value: Variant = athlon.get("event_records", {})
		var records: Dictionary = {}
		if records_value is Dictionary:
			records = records_value
		var team_species: Array = []
		var team_value: Variant = run.get("team", [])
		if team_value is Array:
			var team: Array = team_value
			for member_value: Variant in team:
				if member_value is Dictionary:
					var member: Dictionary = member_value
					team_species.append(int(member.get("species_id", 0)))
		records[event_id] = {"points": points, "raw": raw, "team": team_species}
		athlon["event_records"] = records
	athlon["event_best"] = best
	if bool(context.get("placed_first", false)):
		var firsts_value: Variant = athlon.get("event_firsts", {})
		var firsts: Dictionary = {}
		if firsts_value is Dictionary:
			firsts = firsts_value
		firsts[event_id] = mini(int(firsts.get(event_id, 0)) + 1, PUWPokeathlonParams.MAX_COUNTER)
		athlon["event_firsts"] = firsts
	athlon["time_minutes"] = mini(int(athlon.get("time_minutes", 0)) + int(context.get("minutes", 0)), PUWPokeathlonParams.MAX_TIME_MINUTES)
	return points


## Finish the current run. opponent_totals: the three opponents'
## course totals (event points + their bonuses, as computed by
## the presentation layer). bonus_context (presentation inputs):
##   "no_miss": Array of 3 bools (per team member, all 3 events)
##   "individual_scores": Array of 3 numbers (team members)
##   "opponent_individual_best": float
##   "effort_winner_is_player": bool
## Returns the result dict, or {} if the run is incomplete.
static func finish_course(state: Dictionary, opponent_totals: Array, bonus_context: Dictionary = {}) -> Dictionary:
	var athlon: Dictionary = athlon_state(state)
	var run_value: Variant = athlon.get("current_run", {})
	if not (run_value is Dictionary):
		return {}
	var run: Dictionary = run_value
	if run.is_empty():
		return {}
	var course_id: String = str(run.get("course", ""))
	var events_value: Variant = run.get("events", {})
	var events: Dictionary = {}
	if events_value is Dictionary:
		events = events_value
	if events.size() != 3:
		return {}
	var event_points: int = 0
	var event_scores: Array = []
	for event_id: String in PUWPokeathlonParams.course_events(course_id):
		var entry_value: Variant = events.get(event_id, {})
		var entry: Dictionary = {}
		if entry_value is Dictionary:
			entry = entry_value
		var pts: int = int(entry.get("points", 0))
		event_points += pts
		event_scores.append(pts)
	# Bonuses [PUB].
	var challenge: int = PUWPokeathlonParams.CHALLENGE_BONUS_BASE - int(run.get("challenge_stars", 0))
	var no_miss_bonus: int = 0
	var no_miss_value: Variant = bonus_context.get("no_miss", [])
	if no_miss_value is Array:
		var no_miss: Array = no_miss_value
		for flag: Variant in no_miss:
			if bool(flag):
				no_miss_bonus += PUWPokeathlonParams.NO_MISS_BONUS
	var leading_bonus: int = 0
	var indiv_value: Variant = bonus_context.get("individual_scores", [])
	if indiv_value is Array:
		var indiv: Array = indiv_value
		var best_indiv: float = -1.0
		for score: Variant in indiv:
			best_indiv = maxf(best_indiv, float(score))
		if best_indiv >= 0.0 and best_indiv >= float(bonus_context.get("opponent_individual_best", 0.0)):
			leading_bonus = PUWPokeathlonParams.LEADING_BONUS
	var effort_bonus: int = 0
	if bool(bonus_context.get("effort_winner_is_player", false)):
		effort_bonus = PUWPokeathlonParams.EFFORT_BONUS
	var bonus_total: int = challenge + no_miss_bonus + leading_bonus + effort_bonus
	var total: int = event_points + bonus_total
	# Placement against the three opponents.
	var placement: int = 1
	for opp: Variant in opponent_totals:
		if int(opp) > total:
			placement += 1
	var mode: String = str(run.get("mode", "single"))
	var win_bonus: int = 0
	if placement == 1:
		win_bonus = int(PUWPokeathlonParams.WIN_BONUS.get(mode, 100))
	var payout: int = total + win_bonus
	_add_points(athlon, payout)
	if placement == 1:
		athlon["placed_first"] = mini(int(athlon.get("placed_first", 0)) + 1, PUWPokeathlonParams.MAX_COUNTER)
	if placement >= 4:
		athlon["placed_last"] = mini(int(athlon.get("placed_last", 0)) + 1, PUWPokeathlonParams.MAX_COUNTER)
	if bonus_total > 0:
		athlon["bonuses_earned"] = mini(int(athlon.get("bonuses_earned", 0)) + 1, PUWPokeathlonParams.MAX_COUNTER)
	# Course record [HELD shape: 3 event scores + max + team].
	var course_records_value: Variant = athlon.get("course_records", {})
	var course_records: Dictionary = {}
	if course_records_value is Dictionary:
		course_records = course_records_value
	var record: Dictionary = {
		"last_scores": event_scores,
		"last_total": total,
		"score_max": int((course_records.get(course_id, {}) as Dictionary).get("score_max", 0)),
		"team": [],
	}
	var team_value: Variant = run.get("team", [])
	var team_species: Array = []
	if team_value is Array:
		var team: Array = team_value
		for member_value: Variant in team:
			if member_value is Dictionary:
				var member: Dictionary = member_value
				team_species.append(int(member.get("species_id", 0)))
	if total > int(record.get("score_max", 0)):
		record["score_max"] = total
		record["team"] = team_species
	else:
		var prev_value: Variant = course_records.get(course_id, {})
		if prev_value is Dictionary:
			var prev: Dictionary = prev_value
			var prev_team: Variant = prev.get("team", [])
			if prev_team is Array:
				record["team"] = prev_team
	course_records[course_id] = record
	athlon["course_records"] = course_records
	# Medals on a win: one course bit per participating species.
	if placement == 1:
		var medals_value: Variant = athlon.get("medals", {})
		var medals: Dictionary = {}
		if medals_value is Dictionary:
			medals = medals_value
		var bit: int = 1 << PUWPokeathlonParams.course_index(course_id)
		for species_id: Variant in team_species:
			var key: String = str(int(species_id))
			medals[key] = int(medals.get(key, 0)) | bit
		athlon["medals"] = medals
	var result: Dictionary = {
		"course": course_id,
		"mode": mode,
		"event_points": event_points,
		"event_scores": event_scores,
		"challenge_bonus": challenge,
		"no_miss_bonus": no_miss_bonus,
		"leading_bonus": leading_bonus,
		"effort_bonus": effort_bonus,
		"total": total,
		"placement": placement,
		"win_bonus": win_bonus,
		"payout": payout,
		"collective_trophy": total >= PUWPokeathlonParams.COLLECTIVE_TROPHY_SCORE,
	}
	athlon["last_run"] = result
	athlon["current_run"] = {}
	return result


static func cancel_run(state: Dictionary) -> void:
	var athlon: Dictionary = athlon_state(state)
	athlon["current_run"] = {}


# ----------------------------------------------------------------
# Points ledger [HELD cap]
# ----------------------------------------------------------------

static func _add_points(athlon: Dictionary, amount: int) -> void:
	athlon["points"] = clampi(int(athlon.get("points", 0)) + amount, 0, PUWPokeathlonParams.MAX_POINTS)
	athlon["lifetime_points_earned"] = int(athlon.get("lifetime_points_earned", 0)) + amount


static func points_balance(state: Dictionary) -> int:
	return int(athlon_state(state).get("points", 0))


## Spend points (Athlete Shop / Data Cards). Refuses on
## insufficient balance; never goes negative.
static func spend_points(state: Dictionary, amount: int) -> bool:
	if amount <= 0:
		return false
	var athlon: Dictionary = athlon_state(state)
	if int(athlon.get("points", 0)) < amount:
		return false
	athlon["points"] = int(athlon.get("points", 0)) - amount
	return true


## Buy one once-daily Athlete Shop slot [HELD: 12 bits, reset
## when the day changes]. price is the item's listed price.
static func buy_daily_shop_item(state: Dictionary, slot: int, price: int, day_index: int) -> bool:
	if slot < 0 or slot >= PUWPokeathlonParams.DAILY_SHOP_SLOTS:
		return false
	var athlon: Dictionary = athlon_state(state)
	if int(athlon.get("daily_shop_day", -1)) != day_index:
		athlon["daily_shop"] = 0
		athlon["daily_shop_day"] = day_index
	var flags: int = int(athlon.get("daily_shop", 0))
	if flags & (1 << slot) != 0:
		return false
	if not spend_points(state, price):
		return false
	athlon["daily_shop"] = flags | (1 << slot)
	return true


## Buy a Data Card [HELD: 27 cards, bitmask]. Price [DC].
static func buy_data_card(state: Dictionary, card_index: int) -> bool:
	if card_index < 0 or card_index >= PUWPokeathlonParams.DATA_CARD_COUNT:
		return false
	var athlon: Dictionary = athlon_state(state)
	var owned: int = int(athlon.get("data_cards", 0))
	if owned & (1 << card_index) != 0:
		return false
	if not spend_points(state, PUWPokeathlonParams.DATA_CARD_PRICE):
		return false
	athlon["data_cards"] = owned | (1 << card_index)
	return true


# ----------------------------------------------------------------
# Medals, global score, trophies
# ----------------------------------------------------------------

static func medal_bits(state: Dictionary, species_id: int) -> int:
	var athlon: Dictionary = athlon_state(state)
	var medals_value: Variant = athlon.get("medals", {})
	if medals_value is Dictionary:
		var medals: Dictionary = medals_value
		return int(medals.get(str(species_id), 0))
	return 0


static func is_medalist(state: Dictionary, species_id: int) -> bool:
	return medal_bits(state, species_id) == 0b11111


static func medalist_count(state: Dictionary) -> int:
	var athlon: Dictionary = athlon_state(state)
	var medals_value: Variant = athlon.get("medals", {})
	var count: int = 0
	if medals_value is Dictionary:
		var medals: Dictionary = medals_value
		for key: Variant in medals.keys():
			if int(medals.get(key, 0)) & 0b11111 == 0b11111:
				count += 1
	return count


static func total_medal_count(state: Dictionary) -> int:
	var athlon: Dictionary = athlon_state(state)
	var medals_value: Variant = athlon.get("medals", {})
	var total: int = 0
	if medals_value is Dictionary:
		var medals: Dictionary = medals_value
		for key: Variant in medals.keys():
			var bits: int = int(medals.get(key, 0)) & 0b11111
			for i: int in range(5):
				if bits & (1 << i) != 0:
					total += 1
	return total


## Global score [HELD formula]: sum of course bests + sum of
## event bests + total medal count.
static func global_score(state: Dictionary) -> int:
	var athlon: Dictionary = athlon_state(state)
	var total: int = total_medal_count(state)
	var course_records_value: Variant = athlon.get("course_records", {})
	if course_records_value is Dictionary:
		var course_records: Dictionary = course_records_value
		for course_id: Variant in course_records.keys():
			var record_value: Variant = course_records.get(course_id, {})
			if record_value is Dictionary:
				var record: Dictionary = record_value
				total += int(record.get("score_max", 0))
	var best_value: Variant = athlon.get("event_best", {})
	if best_value is Dictionary:
		var best: Dictionary = best_value
		for event_id: Variant in best.keys():
			total += int(best.get(event_id, 0))
	return total


static func friendship_trophy_count(state: Dictionary) -> int:
	var score: int = global_score(state)
	var count: int = 0
	for threshold_value: Variant in PUWPokeathlonParams.FRIENDSHIP_TROPHY_THRESHOLDS:
		if score >= int(threshold_value):
			count += 1
		else:
			break
	return count


static func trust_trophy_count(state: Dictionary) -> int:
	var medalists: int = medalist_count(state)
	var count: int = 0
	for threshold_value: Variant in PUWPokeathlonParams.TRUST_TROPHY_THRESHOLDS:
		if medalists >= int(threshold_value):
			count += 1
		else:
			break
	return count


## Unlock the Supreme Cup (bind-time content sets this after the
## National Dex + Magnus conditions are met [PUB]).
static func set_supreme_unlocked(state: Dictionary, unlocked: bool) -> void:
	athlon_state(state)["supreme_unlocked"] = unlocked
