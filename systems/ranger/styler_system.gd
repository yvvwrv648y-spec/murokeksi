class_name PUWStylerSystem
extends RefCounted
## RANGER VARIANT A — THE STYLER SYSTEM, **V2** (Bossy's
## ruling P1, adopted 2026-11-23; v2 revision 2026-11-23
## applying hunt rotation 7's sourced data). SUPERSESSION:
## this file supersedes v1's code_prep_styler styler_system.gd
## at bind, together with v2's styler_params.gd (see its
## header). One system, three per-region parameter
## sets (PUWStylerParams):
##
## - FIORE: the loop-count model. A number appears over the
##   target: that many CONSECUTIVE loops, unbroken. Lift the
##   stylus early or let the line be cut and the count resets
##   to zero. Reaching the count and then lifting completes
##   the befriending; extra loops beyond the count earn bonus
##   Styler Exp.
## - ALMIA: the Friendship Gauge model. Every loop adds
##   friendship equal to Styler Power; the stylus may lift
##   between loops; the gauge drains while not being looped.
##   Power Charge multiplies a loop's power. Agitation cuts
##   Styler power (assist power is untouched).
## - OBLIVIA: the gauge model plus the agitation state at its
##   documented strength (Styler Power to one tenth) and the
##   Ranger Points track. Assists are physically present: the
##   assistant stands on the field, can be hit, and must rest.
##
## FRIEND LIFECYCLE (the regulation contract, all regions):
## a befriended Pokemon is a Friend -- temporary, never owned.
## One help (one Poke Assist or one Target Clear), then it is
## released. The Partner is the exception: permanent, never
## released, its assist on call. Fiore's pre-credits rule also
## releases every Friend when the Ranger leaves a habitat.
##
## PERMANENT GAINS leave a Ranger region ONLY through the
## transfer-reward pattern (grant_transfer_reward /
## claim_transfer_reward): earned in a Ranger mission,
## received as a Pokemon in the wider game. Capture code never
## grants one.
##
## PERMADEATH IS STRUCTURALLY UNTOUCHED. Friend records are a
## deliberately different shape from party Pokemon records
## (no identity serial, no health, no evolution family), this
## module never calls the party/storage manager and never
## records a faint, and the only write it ever makes to a
## collection is claim_transfer_reward appending exactly one
## reward template to the boxes of a NON-Ranger active region.
## The test suite proves the collection + faint projection of
## a rich save is byte-identical across a full Styler session.
##
## All state lives in the active Ranger region's own region
## record (PUWRegionState), under its "ranger" key: a fresh
## start in a Ranger region is Rank 1 / base Styler there,
## independently per region, exactly as the build prep
## specifies. Ranger Rank is a LOCAL track: missions promote,
## finales wire to PUWRegionState.record_champion_win as
## Champion-equivalents, and no Ranger operation ever records
## a badge.

# Styler Exp. awarded per successful befriending, and Fiore's
# per-extra-loop bonus (the bonus's existence is sourced --
# RANGER_DEEP 1.1; amounts are DESIGN CONSTANTS).
const EXP_PER_CAPTURE: int = 100
const EXP_PER_EXTRA_LOOP: int = 25
const EXP_PER_MULTI_CAPTURE: int = 50


# ----------------------------------------------------------------
# Region record access
# ----------------------------------------------------------------

static func _default_ranger_state(region_id: String) -> Dictionary:
	var params: Dictionary = PUWStylerParams.params_for(region_id)
	return {
		"rank": 1,
		"missions_completed": 0,
		"styler_level": 1,
		"styler_exp": 0,
		"energy": int(params.get("energy_base", 10)),
		"friends": [],
		"partner": {},
		"partners_unlocked": [],
		"points": 0,
		"points_srank_species": [],
		"points_missions": [],
		"points_quests": [],
		"modification_levels": {},
		"past_styler": {"styler_level": 1, "styler_exp": 0, "energy": 30},
		"past_points": 0,
		"points_upgrades": {},
		"past_upgrades": {"assist": 0, "healing": 0, "power": 0},
		"species_seen": [],
		"transfer_pending": [],
		"transfer_claimed": [],
		"finale_done": false,
	}


## The ranger sub-record inside a region's own region record,
## created with fresh-start defaults on first touch. Returns {}
## for a non-Ranger region (the system does not exist there).
static func ranger_state(state: Dictionary, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	if not PUWRangerAvailability.is_ranger_region(rid):
		return {}
	var root: Dictionary = PUWRegionState.ensure_regions(state)
	var records_value: Variant = root.get("regions", {})
	var records: Dictionary = {}
	if records_value is Dictionary:
		records = records_value
	var record_value: Variant = records.get(rid, {})
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
	var ranger_value: Variant = record.get("ranger", {})
	if ranger_value is Dictionary:
		var existing: Dictionary = ranger_value
		if not existing.is_empty():
			return existing
	var fresh: Dictionary = _default_ranger_state(rid)
	record["ranger"] = fresh
	records[rid] = record
	root["regions"] = records
	state["regions"] = root
	return fresh


static func _friends_of(ranger: Dictionary) -> Array:
	var value: Variant = ranger.get("friends", [])
	if value is Array:
		var friends: Array = value
		return friends
	return []


# ----------------------------------------------------------------
# Styler tool: levels, energy, power
# ----------------------------------------------------------------

## Cumulative Styler Exp. required to stand at a level --
## read from the SOURCED per-level table
## (PUWStylerLevelTables, generated from rotation 7's
## styler_levels.json), not interpolated. The Oblivia past
## table's printed totals are shifted (its L1 prints 10);
## thresholds therefore take the running maximum so the
## printed anomaly cannot invert the curve, and level 1
## always stands at 0.
static func exp_for_level(region_id: String, level: int, track: String = "present") -> int:
	var table: Array = PUWStylerLevelTables.table_for(region_id, track)
	if table.is_empty() or level <= 1:
		return 0
	var clamped: int = mini(level, table.size())
	var best: int = 0
	for i in range(1, clamped):
		var row_value: Variant = table[i]
		if row_value is Dictionary:
			var row: Dictionary = row_value
			best = maxi(best, int(row.get("total_exp", 0)))
	return best


## Max Styler Energy at a level: the sourced table's exact
## per-level value (Fiore 4 -> 60, Almia 10 -> 104, Oblivia
## present 10 -> 164, Oblivia past 30 -> 250).
static func energy_max(region_id: String, level: int, track: String = "present") -> int:
	var row: Dictionary = PUWStylerLevelTables.row_for(region_id, level, track)
	if row.is_empty():
		return int(PUWStylerParams.params_for(region_id).get("energy_base", 10))
	return int(row.get("energy", 0))


## Styler Power at a level (gauge models): the sourced
## table's exact per-level value (Almia 10 -> 205, Oblivia
## present 10 -> 327, Oblivia past 5 -> 300). Fiore has no
## per-level Power stat and reads 0.
static func power_at_level(region_id: String, level: int, track: String = "present") -> int:
	var row: Dictionary = PUWStylerLevelTables.row_for(region_id, level, track)
	if row.is_empty():
		return 0
	return int(row.get("power", 0))


## Fiore's Capture Line length at a level: the sourced
## table's exact per-level value (100 at L1 -> 200 at L20).
static func line_length(region_id: String, level: int) -> int:
	var row: Dictionary = PUWStylerLevelTables.row_for(region_id, level)
	if row.is_empty():
		return 0
	return int(row.get("line_length", 0))


static func styler_level(state: Dictionary, region_id: String = "") -> int:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return 0
	return int(ranger.get("styler_level", 1))


static func current_energy(state: Dictionary, region_id: String = "") -> int:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return 0
	return int(ranger.get("energy", 0))


## Restore Styler Energy (a save point, a Recharge effect, a
## battery). Clamped to the current level's maximum. Returns
## the amount actually restored.
static func restore_energy(state: Dictionary, amount: int, region_id: String = "") -> int:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return 0
	var before: int = int(ranger.get("energy", 0))
	var cap: int = energy_max(rid, int(ranger.get("styler_level", 1)))
	var after: int = mini(cap, before + maxi(0, amount))
	ranger["energy"] = after
	return after - before


## Award Styler Exp.; applies any level-ups (raising max
## Energy; Guardian Signs also restores Energy on level-up,
## as documented for that game). Returns {"levels_gained"}.
static func award_styler_exp(state: Dictionary, amount: int, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"levels_gained": 0}
	var params: Dictionary = PUWStylerParams.params_for(rid)
	var levels_cap: int = int(params.get("styler_levels", 20))
	var old_level: int = int(ranger.get("styler_level", 1))
	var total_exp: int = int(ranger.get("styler_exp", 0)) + maxi(0, amount)
	ranger["styler_exp"] = total_exp
	var new_level: int = old_level
	while new_level < levels_cap and total_exp >= exp_for_level(rid, new_level + 1):
		new_level += 1
	if new_level > old_level:
		ranger["styler_level"] = new_level
		if bool(params.get("level_up_full_restore", false)):
			ranger["energy"] = energy_max(rid, new_level)
		else:
			var delta: int = energy_max(rid, new_level) - energy_max(rid, old_level)
			ranger["energy"] = mini(energy_max(rid, new_level), int(ranger.get("energy", 0)) + delta)
	return {"levels_gained": new_level - old_level}


# ----------------------------------------------------------------
# Rank and progression (ruling P8)
# ----------------------------------------------------------------

static func current_rank(state: Dictionary, region_id: String = "") -> int:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return 0
	return int(ranger.get("rank", 1))


## Friend capacity at the region's current Rank (Fiore/Almia)
## or its documented flat roster (Oblivia).
static func friend_capacity(state: Dictionary, region_id: String = "") -> int:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return 0
	var params: Dictionary = PUWStylerParams.params_for(rid)
	if params.has("capacity_flat"):
		return int(params.get("capacity_flat", PUWStylerParams.FRIEND_CAPACITY_MAX))
	var table_value: Variant = params.get("capacity_by_rank", {})
	if table_value is Dictionary:
		var table: Dictionary = table_value
		var rank: int = int(ranger.get("rank", 1))
		if table.has(rank):
			return int(table.get(rank, 0))
	return PUWStylerParams.FRIEND_CAPACITY_MAX


## Complete a mission in the active Ranger region. Mission
## keys: "id", "grants_rank" (the mission promotes the Ranger,
## per content), "is_finale" (the region's story finale).
## A finale wires to PUWRegionState.record_champion_win --
## the Champion-equivalent gate -- and sets the region's
## finale flag (Fiore's carry-out right keys off it).
## NO badge is ever recorded here: Ranger Rank is a local
## track, and Champion-equivalents award no badges either
## (build prep section 5.2, prep position recorded).
static func complete_mission(state: Dictionary, mission: Dictionary) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"ok": false, "reason": "not_a_ranger_region"}
	ranger["missions_completed"] = int(ranger.get("missions_completed", 0)) + 1
	var promoted: bool = false
	if bool(mission.get("grants_rank", false)):
		var rank: int = int(ranger.get("rank", 1))
		if rank < 10:
			ranger["rank"] = rank + 1
			promoted = true
	var gate_opened: bool = false
	if bool(mission.get("is_finale", false)):
		ranger["finale_done"] = true
		gate_opened = PUWRegionState.record_champion_win(state, rid)
	return {
		"ok": true,
		"region_id": rid,
		"promoted": promoted,
		"rank": int(ranger.get("rank", 1)),
		"gate_opened": gate_opened,
	}


# ----------------------------------------------------------------
# Capture sessions
# ----------------------------------------------------------------

## Open a capture session against a wild target in the ACTIVE
## region. Returns {} when the Styler does not exist here or
## the Styler is broken (Energy at 0 -- restore it first).
## Target keys (content-supplied; per-species capture values
## are data, build prep D5/D11):
##   "species" String, "types" Array of type ids,
##   "assist_type" String (defaults to the first type),
##   "evo_stage" int 1..3 (default 1),
##   "field_moves" Dictionary move id -> level,
##   "loops_required" int (Fiore model),
##   "friendship_required" float (gauge models),
##   "location_id" String (the befriending pool it came from).
static func begin_capture(state: Dictionary, target: Dictionary) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	if not PUWRangerAvailability.styler_exists_in(rid):
		return {}
	var ranger: Dictionary = ranger_state(state, rid)
	if int(ranger.get("energy", 0)) <= 0:
		return {}
	var params: Dictionary = PUWStylerParams.params_for(rid)
	var types_value: Variant = target.get("types", [])
	var types: Array = []
	if types_value is Array:
		types = types_value
	var assist_type: String = str(target.get("assist_type", ""))
	if assist_type == "" and not types.is_empty():
		assist_type = str(types[0])
	return {
		"region_id": rid,
		"model": str(params.get("model", "")),
		"species": str(target.get("species", "")),
		"types": types.duplicate(),
		"assist_type": assist_type,
		"evo_stage": clampi(int(target.get("evo_stage", 1)), 1, 3),
		"field_moves": target.get("field_moves", {}),
		"location_id": str(target.get("location_id", "")),
		"required": float(target.get("friendship_required", 0.0)),
		"gauge_points": target.get("gauge_points", []),
		"agitated_gauge_points": target.get("agitated_gauge_points", []),
		"loops_required": int(target.get("loops_required", 0)),
		"gauge": 0.0,
		"consecutive_loops": 0,
		"loops_total": 0,
		"extra_loops": 0,
		"requirement_met": false,
		"agitated": false,
		"status_state": "",
		"status_seconds": 0.0,
		"fighting_loops": false,
		"double_line": false,
		"charge_level": 0,
		"partner_gauge": 0.0,
		"assistant": {},
		"assistant_rested": false,
		"assistant_rest_seconds": 0.0,
		"assistant_helped": false,
		"captured": false,
		"broken": false,
		"over": false,
	}


static func _session_region(session: Dictionary) -> String:
	return str(session.get("region_id", ""))


## Styler Power for one loop right now (gauge models): the
## region's base power, plus the documented uninterrupted-loop
## component, times the charge multiplier, times the agitation
## multiplier, times Fighting's documented doubling. Assist
## power is computed separately and is NEVER agitation-cut.
static func loop_power(state: Dictionary, session: Dictionary) -> float:
	var rid: String = _session_region(session)
	var params: Dictionary = PUWStylerParams.params_for(rid)
	# SOURCED-R7: Power is the Styler's per-level table value
	# (Almia L1 = 10, not v1's contradicted 350 base).
	var power: float = float(power_at_level(rid, styler_level(state, rid)))
	var chain: int = mini(int(session.get("consecutive_loops", 0)), PUWStylerParams.UNINTERRUPTED_LOOP_CAP)
	power += float(PUWStylerParams.UNINTERRUPTED_LOOP_POWER * chain)
	var charge: int = int(session.get("charge_level", 0))
	if charge > 0:
		var mults_value: Variant = params.get("charge_mult", {})
		if mults_value is Dictionary:
			var mults: Dictionary = mults_value
			power *= float(mults.get(charge, 1.0))
	if bool(session.get("agitated", false)):
		power *= float(params.get("agitation_power_mult", 1.0))
	if bool(session.get("fighting_loops", false)):
		power *= 2.0
	return power


## One completed Capture Line loop around the target.
static func session_loop(state: Dictionary, session: Dictionary) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var rid: String = _session_region(session)
	var model: String = str(session.get("model", ""))
	session["loops_total"] = int(session.get("loops_total", 0)) + 1
	# The Partner Gauge fills as loops are drawn (both partner
	# models read it).
	session["partner_gauge"] = minf(1.0, float(session.get("partner_gauge", 0.0)) + PUWStylerParams.PARTNER_GAUGE_FILL_PER_LOOP)
	if model == "loop_count":
		var step: int = 1
		if bool(session.get("fighting_loops", false)):
			# Fighting's assist: each loop counts as two.
			step = 2
		var consecutive: int = int(session.get("consecutive_loops", 0)) + step
		session["consecutive_loops"] = consecutive
		var required: int = int(session.get("loops_required", 0))
		if required > 0 and consecutive >= required:
			if bool(session.get("requirement_met", false)):
				session["extra_loops"] = int(session.get("extra_loops", 0)) + step
			session["requirement_met"] = true
		return {
			"ok": true,
			"consecutive_loops": int(session.get("consecutive_loops", 0)),
			"requirement_met": bool(session.get("requirement_met", false)),
			"captured": false,
		}
	# Gauge models: the loop adds friendship equal to Styler
	# Power; a charged loop spends its charge.
	var gain: float = loop_power(state, session)
	session["gauge"] = float(session.get("gauge", 0.0)) + gain
	session["consecutive_loops"] = int(session.get("consecutive_loops", 0)) + 1
	if int(session.get("charge_level", 0)) > 0:
		session["charge_level"] = 0
	var required_gauge: float = float(session.get("required", 0.0))
	if required_gauge > 0.0 and float(session.get("gauge", 0.0)) >= required_gauge:
		return _complete_befriend(state, session, 0)
	return {"ok": true, "gauge": float(session.get("gauge", 0.0)), "gain": gain, "captured": false}


## Lift the stylus. Fiore: the all-or-nothing rule -- lifting
## with the count met completes the befriending; lifting early
## resets the count to zero and every loop must be remade.
## Gauge models: lifting is free (the single biggest feel
## change from Fiore); only the uninterrupted chain breaks.
static func session_lift(state: Dictionary, session: Dictionary) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var model: String = str(session.get("model", ""))
	if model == "loop_count":
		if bool(session.get("requirement_met", false)):
			return _complete_befriend(state, session, int(session.get("extra_loops", 0)))
		session["consecutive_loops"] = 0
		return {"ok": true, "reset": true, "captured": false}
	session["consecutive_loops"] = 0
	return {"ok": true, "reset": false, "captured": false}


## The target or its attack cuts the Capture Line (no Energy
## damage -- see session_line_hit for a damaging hit). Fiore:
## the consecutive count resets to zero. Gauge models: only
## the uninterrupted chain breaks; the gauge itself is kept.
static func session_line_cut(state: Dictionary, session: Dictionary) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	session["consecutive_loops"] = 0
	if str(session.get("model", "")) == "loop_count":
		session["requirement_met"] = false
		session["extra_loops"] = 0
	return {"ok": true}


## A target's attack hits the Capture Line: the Styler takes
## damage (Energy is the tool's HP, persisted in the region
## record). At 0 Energy the Capture Disc explodes and the
## session ends -- the games return the Ranger to the last
## save point; that presentation is content's job. Fiore's
## count also resets (its attacks cut the line).
static func session_line_hit(state: Dictionary, session: Dictionary, damage: int) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var rid: String = _session_region(session)
	var ranger: Dictionary = ranger_state(state, rid)
	var energy: int = maxi(0, int(ranger.get("energy", 0)) - maxi(0, damage))
	ranger["energy"] = energy
	if str(session.get("model", "")) == "loop_count":
		session["consecutive_loops"] = 0
		session["requirement_met"] = false
		session["extra_loops"] = 0
	if energy <= 0:
		session["broken"] = true
		_end_session(state, session)
		return {"ok": true, "energy": 0, "styler_broken": true}
	return {"ok": true, "energy": energy, "styler_broken": false}


## Advance session time: gauge drain (gauge models, unless a
## Tired-state assist holds it), assist status durations, and
## a resting assistant's recovery (Guardian Signs).
static func session_tick(state: Dictionary, session: Dictionary, seconds: float) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var dt: float = maxf(0.0, seconds)
	if str(session.get("model", "")) == "gauge":
		var rid: String = _session_region(session)
		var params: Dictionary = PUWStylerParams.params_for(rid)
		if str(session.get("status_state", "")) != "tired":
			var drain: float = float(session.get("required", 0.0)) * float(params.get("gauge_drain_fraction_per_sec", 0.0)) * dt
			session["gauge"] = maxf(0.0, float(session.get("gauge", 0.0)) - drain)
	if float(session.get("status_seconds", 0.0)) > 0.0:
		session["status_seconds"] = maxf(0.0, float(session.get("status_seconds", 0.0)) - dt)
		if float(session.get("status_seconds", 0.0)) <= 0.0:
			session["status_state"] = ""
			session["fighting_loops"] = false
			session["double_line"] = false
	if float(session.get("assistant_rest_seconds", 0.0)) > 0.0:
		session["assistant_rest_seconds"] = maxf(0.0, float(session.get("assistant_rest_seconds", 0.0)) - dt)
		if float(session.get("assistant_rest_seconds", 0.0)) <= 0.0:
			session["assistant_rested"] = false
	return {"ok": true, "gauge": float(session.get("gauge", 0.0))}


## Power Charge (Almia): hold the Capture Disc still to charge
## the Styler, then loop for multiplied power. Rank 6 shortens
## the ready time; Rank 8 adds the second charge level. The
## charge is spent by the next loop (session_loop).
static func session_charge(state: Dictionary, session: Dictionary, held_seconds: float) -> Dictionary:
	var rid: String = _session_region(session)
	var params: Dictionary = PUWStylerParams.params_for(rid)
	if not params.has("charge_mult"):
		return {"ok": false, "reason": "no_power_charge_in_region"}
	var ranger: Dictionary = ranger_state(state, rid)
	var rank: int = int(ranger.get("rank", 1))
	var max_level: int = 1
	if rank >= int(params.get("charge_level2_rank", 8)):
		max_level = int(params.get("charge_max_level", 2))
	var ready: float = float(params.get("charge_ready_seconds", 2.0))
	if rank >= int(params.get("charge_faster_rank", 6)):
		ready = float(params.get("charge_ready_seconds_fast", ready))
	var level: int = 0
	if held_seconds >= ready:
		level = 1
	if max_level >= 2 and held_seconds >= ready * 2.0:
		level = 2
	session["charge_level"] = level
	return {"ok": true, "charge_level": level}


## Set or clear the target's agitation (Almia / Guardian
## Signs). Agitation cuts Styler Power; assist power is never
## cut -- assists are the documented answer to agitation.
static func session_set_agitated(session: Dictionary, agitated: bool) -> void:
	session["agitated"] = agitated


## Whether the target can move / attack right now: the
## documented states that stop it are Fiore's Immobilized and
## Frozen, and the gauge games' Stopped and Paused. Slowed and
## Tired targets can still act.
static func target_can_act(session: Dictionary) -> bool:
	var current: String = str(session.get("status_state", ""))
	if float(session.get("status_seconds", 0.0)) <= 0.0:
		return true
	return not ["immobilized", "frozen", "stopped", "paused"].has(current)


# ----------------------------------------------------------------
# Befriending and the Friend roster
# ----------------------------------------------------------------

## Build the Friend record for a captured target. A Friend is
## deliberately NOT a party Pokemon record: no identity
## serial, no health pool, no evolution family -- it cannot be
## mistaken for an owned Pokemon by any collection path, and
## it is never written into one (see the header).
static func _friend_from_session(session: Dictionary) -> Dictionary:
	var moves_value: Variant = session.get("field_moves", {})
	var moves: Dictionary = {}
	if moves_value is Dictionary:
		moves = moves_value
	return {
		"species": str(session.get("species", "")),
		"types": session.get("types", []),
		"assist_type": str(session.get("assist_type", "")),
		"evo_stage": int(session.get("evo_stage", 1)),
		"field_moves": moves.duplicate(true),
		"origin_location": str(session.get("location_id", "")),
		"via": "styler",
		"is_partner": false,
	}


static func _complete_befriend(state: Dictionary, session: Dictionary, extra_loops: int) -> Dictionary:
	var rid: String = _session_region(session)
	var ranger: Dictionary = ranger_state(state, rid)
	var friends: Array = _friends_of(ranger)
	if friends.size() >= friend_capacity(state, rid):
		session["over"] = true
		_end_session(state, session)
		return {"ok": true, "captured": false, "reason": "roster_full"}
	var friend: Dictionary = _friend_from_session(session)
	friends.append(friend)
	ranger["friends"] = friends
	session["captured"] = true
	# First-capture tracking (Guardian Signs' Ranger Points
	# key off it; the Browser is content built on the same
	# record).
	var seen_value: Variant = ranger.get("species_seen", [])
	var seen: Array = []
	if seen_value is Array:
		seen = seen_value
	var first_capture: bool = not seen.has(str(session.get("species", "")))
	if first_capture:
		seen.append(str(session.get("species", "")))
		ranger["species_seen"] = seen
	session["first_capture"] = first_capture
	var exp_gain: int = EXP_PER_CAPTURE + EXP_PER_EXTRA_LOOP * extra_loops
	award_styler_exp(state, exp_gain, rid)
	_end_session(state, session)
	return {
		"ok": true,
		"captured": true,
		"friend": friend,
		"first_capture": first_capture,
		"exp_gained": exp_gain,
	}


## End a session without a capture (the Ranger breaks off, or
## the target fled). Guardian Signs' presence rule resolves
## here: an assistant that helped during the session is
## released as the session closes.
static func session_flee(state: Dictionary, session: Dictionary) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	_end_session(state, session)
	return {"ok": true}


static func _end_session(state: Dictionary, session: Dictionary) -> void:
	session["over"] = true
	if bool(session.get("assistant_helped", false)):
		var assistant_value: Variant = session.get("assistant", {})
		if assistant_value is Dictionary:
			var assistant: Dictionary = assistant_value
			if not assistant.is_empty() and not bool(assistant.get("is_partner", false)):
				_release_friend_record(state, _session_region(session), assistant)
	session["assistant"] = {}


static func friends(state: Dictionary, region_id: String = "") -> Array:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return []
	return _friends_of(ranger).duplicate(true)


static func partner(state: Dictionary, region_id: String = "") -> Dictionary:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return {}
	var value: Variant = ranger.get("partner", {})
	if value is Dictionary:
		var active: Dictionary = value
		return active.duplicate(true)
	return {}


static func _release_friend_record(state: Dictionary, region_id: String, friend: Dictionary) -> bool:
	var ranger: Dictionary = ranger_state(state, region_id)
	var roster: Array = _friends_of(ranger)
	for i in roster.size():
		var entry_value: Variant = roster[i]
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if entry == friend:
				roster.remove_at(i)
				ranger["friends"] = roster
				return true
	return false


## Manually release one Friend back to the wild (a regulation
## release, not a faint and not a collection release: the
## Friend was never owned). Returns false for a bad index.
static func release_friend(state: Dictionary, friend_index: int, region_id: String = "") -> bool:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return false
	var roster: Array = _friends_of(ranger)
	if friend_index < 0 or friend_index >= roster.size():
		return false
	roster.remove_at(friend_index)
	ranger["friends"] = roster
	return true


## Leaving a habitat area. Fiore's regulation (pre-credits):
## every Friend is released; the right to carry Friends out
## of their habitats is earned at the finale. Almia and
## Oblivia document no such rule. Returns the count released.
static func leave_habitat(state: Dictionary, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"released": 0}
	var params: Dictionary = PUWStylerParams.params_for(rid)
	if not bool(params.get("habitat_release_pre_credits", false)):
		return {"released": 0}
	if bool(ranger.get("finale_done", false)):
		return {"released": 0}
	var roster: Array = _friends_of(ranger)
	var count: int = roster.size()
	ranger["friends"] = []
	return {"released": count}


# ----------------------------------------------------------------
# Partners (ruling P3)
# ----------------------------------------------------------------

## Fiore / Oblivia: assign the region's fixed story partner.
## Fiore's is set by the protagonist (Minun for the male
## Ranger, Plusle for the female -- Serebii, via RANGER_DEEP
## 1.1); Oblivia's is Ukulele Pichu, the scripted story
## partner (ruling P9 -- an accessory identity, kept strictly
## separate from Spiky-eared Pichu in data and in fact).
static func assign_fixed_partner(state: Dictionary, protagonist: String = "") -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"ok": false, "reason": "not_a_ranger_region"}
	var params: Dictionary = PUWStylerParams.params_for(rid)
	if str(params.get("partner_kind", "")) == "roster":
		return {"ok": false, "reason": "roster_region"}
	var fixed: Dictionary = {}
	if rid == "fiore":
		var species: String = "minun"
		if protagonist == "female":
			species = "plusle"
		fixed = {
			"species": species, "types": ["electric"],
			"assist_type": "discharge", "evo_stage": 1,
			"field_moves": {}, "origin_location": "",
			"via": "partner", "is_partner": true,
		}
	elif rid == "oblivia":
		fixed = {
			"species": "pichu", "types": ["electric"],
			"assist_type": "electric", "evo_stage": 1,
			"field_moves": {}, "origin_location": "dolce_island",
			"via": "partner", "is_partner": true,
			"accessory": "ukulele",
		}
	if fixed.is_empty():
		return {"ok": false, "reason": "no_fixed_partner"}
	ranger["partner"] = fixed
	return {"ok": true, "partner": fixed.duplicate(true)}


## Almia: unlock a partner through its documented acquisition
## channel (starter / storyline / quest). A partner cannot be
## unlocked through the wrong channel. The first partner
## unlocked becomes the traveling partner; the rest live at
## the Partner Farm (ruling P3).
static func unlock_partner(state: Dictionary, partner_id: String, acquisition: String) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "almia":
		return {"ok": false, "reason": "not_almia"}
	var entry: Dictionary = PUWStylerParams.almia_partner(partner_id)
	if entry.is_empty():
		return {"ok": false, "reason": "unknown_partner"}
	if str(entry.get("acquisition", "")) != acquisition:
		return {"ok": false, "reason": "wrong_acquisition_channel"}
	var unlocked_value: Variant = ranger.get("partners_unlocked", [])
	var unlocked: Array = []
	if unlocked_value is Array:
		unlocked = unlocked_value
	if unlocked.has(partner_id):
		return {"ok": false, "reason": "already_unlocked"}
	unlocked.append(partner_id)
	ranger["partners_unlocked"] = unlocked
	if partner(state, rid).is_empty():
		return set_active_partner(state, partner_id)
	return {"ok": true, "partner_id": partner_id}


## Almia: swap the traveling partner -- done by walking up and
## talking to the partner at the Partner Farm, which is the
## care layer's interaction shape (ruling P3). Only unlocked
## partners can travel.
static func set_active_partner(state: Dictionary, partner_id: String) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "almia":
		return {"ok": false, "reason": "not_almia"}
	var entry: Dictionary = PUWStylerParams.almia_partner(partner_id)
	if entry.is_empty():
		return {"ok": false, "reason": "unknown_partner"}
	var unlocked_value: Variant = ranger.get("partners_unlocked", [])
	var unlocked: Array = []
	if unlocked_value is Array:
		unlocked = unlocked_value
	if not unlocked.has(partner_id):
		return {"ok": false, "reason": "not_unlocked"}
	var active: Dictionary = {
		"species": partner_id,
		"types": [str(entry.get("assist_type", ""))],
		"assist_type": str(entry.get("assist_type", "")),
		"evo_stage": 1,
		"field_moves": {},
		"origin_location": "partner_farm",
		"via": "partner",
		"is_partner": true,
	}
	ranger["partner"] = active
	return {"ok": true, "partner": active.duplicate(true)}


# ----------------------------------------------------------------
# Poké Assists (ruling P2 -- the field-assist vocabulary)
# ----------------------------------------------------------------

## Fiore's assist duration for a type matchup, from the
## documented tiers (10/20/30/60 seconds). The tier-to-
## multiplier mapping is a DESIGN CONSTANT on the documented
## tiers: no effect at 0x, then the tiers climb with the
## mainline effectiveness chart.
static func fiore_assist_duration(matchup_mult: float) -> float:
	if matchup_mult <= 0.0:
		return 0.0
	var params: Dictionary = PUWStylerParams.params_for("fiore")
	var tiers_value: Variant = params.get("assist_duration_tiers", [10, 20, 30, 60])
	var tiers: Array = []
	if tiers_value is Array:
		tiers = tiers_value
	if matchup_mult <= 0.5:
		return float(tiers[0])
	if matchup_mult < 2.0:
		return float(tiers[1])
	if matchup_mult < 4.0:
		return float(tiers[2])
	return float(tiers[3])


static func _stage_value(table: Dictionary, stage: int) -> float:
	if table.has(stage):
		return float(table.get(stage, 1.0))
	return 1.0


## The gauge friendship an assist adds: the documented
## scaling shape (evolutionary stage and type matchup both
## scale it), NEVER reduced by agitation. Shared by the
## gauge regions for Friend and Partner assists alike.
static func assist_gauge_gain(session: Dictionary, assistant: Dictionary, matchup_mult: float) -> float:
	var required: float = float(session.get("required", 0.0))
	var stage: int = clampi(int(assistant.get("evo_stage", 1)), 1, 3)
	var gain: float = required * PUWStylerParams.ASSIST_GAUGE_FRACTION
	gain *= _stage_value(PUWStylerParams.ASSIST_STAGE_MULT, stage)
	gain *= matchup_mult
	return gain


static func _apply_assist_effect(state: Dictionary, session: Dictionary, assistant: Dictionary, matchup_mult: float) -> Dictionary:
	var rid: String = _session_region(session)
	var model: String = str(session.get("model", ""))
	var assist_type: String = str(assistant.get("assist_type", ""))
	var stage: int = clampi(int(assistant.get("evo_stage", 1)), 1, 3)
	var out: Dictionary = {"ok": true, "assist_type": assist_type, "state": "", "gauge_gain": 0.0}
	if model == "loop_count":
		var table: Dictionary = PUWStylerParams.ASSISTS_FIORE
		var entry_value: Variant = table.get(assist_type, {})
		var entry: Dictionary = {}
		if entry_value is Dictionary:
			entry = entry_value
		if entry.is_empty():
			return {"ok": false, "reason": "no_such_assist_in_fiore"}
		var special: String = str(entry.get("special", ""))
		if special == "recharge":
			# Recharge restores Styler Energy instead of
			# attacking (documented value: +5).
			restore_energy(state, int(entry.get("energy", 5)), rid)
			out["energy_restored"] = int(entry.get("energy", 5))
			return out
		if special == "double_loops":
			session["fighting_loops"] = true
			session["status_seconds"] = fiore_assist_duration(matchup_mult)
			out["state"] = "double_loops"
			return out
		if special == "line_for_energy":
			# Dark: sacrifice Styler Energy to double the
			# Capture Line's length. The Energy price is a
			# DESIGN CONSTANT (the trade is documented, its
			# price is not).
			var ranger: Dictionary = ranger_state(state, rid)
			var price: int = 5
			if int(ranger.get("energy", 0)) <= price:
				return {"ok": false, "reason": "not_enough_energy"}
			ranger["energy"] = int(ranger.get("energy", 0)) - price
			session["double_line"] = true
			session["status_seconds"] = fiore_assist_duration(matchup_mult)
			out["state"] = "double_line"
			out["energy_spent"] = price
			return out
		var state_name: String = str(entry.get("state", ""))
		session["status_state"] = state_name
		session["status_seconds"] = fiore_assist_duration(matchup_mult)
		out["state"] = state_name
		return out
	# Gauge models (Almia / Oblivia).
	var states: Dictionary = PUWStylerParams.ASSIST_STATES_GAUGE
	var state_name_gauge: String = str(states.get(assist_type, ""))
	var gain: float = assist_gauge_gain(session, assistant, matchup_mult)
	if state_name_gauge == "double_damage":
		session["fighting_loops"] = true
		session["status_seconds"] = _stage_value(PUWStylerParams.ASSIST_STAGE_DURATION, stage)
		out["state"] = "double_damage"
		return out
	if state_name_gauge == "flat_bonus":
		gain *= PUWStylerParams.ASSIST_NORMAL_MULT
		session["gauge"] = float(session.get("gauge", 0.0)) + gain
		out["gauge_gain"] = gain
		return out
	session["gauge"] = float(session.get("gauge", 0.0)) + gain
	out["gauge_gain"] = gain
	if state_name_gauge != "":
		session["status_state"] = state_name_gauge
		session["status_seconds"] = _stage_value(PUWStylerParams.ASSIST_STAGE_DURATION, stage)
		out["state"] = state_name_gauge
	return out


## Use one Friend's Poké Assist in a capture session, then
## release the Friend -- one help, then release (the
## regulation lifecycle). Exception, Guardian Signs: assists
## are physically present there, so the Friend steps onto the
## field as the session's assistant and its release resolves
## when the session ends (it can be hit and must rest first;
## see session_assistant_hit). The Partner never uses this
## path -- see session_apply_partner_assist.
static func session_apply_friend_assist(state: Dictionary, session: Dictionary, friend_index: int, matchup_mult: float) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var rid: String = _session_region(session)
	var ranger: Dictionary = ranger_state(state, rid)
	var roster: Array = _friends_of(ranger)
	if friend_index < 0 or friend_index >= roster.size():
		return {"ok": false, "reason": "no_such_friend"}
	if bool(session.get("assistant_rested", false)):
		# Guardian Signs: the present assistant was hit and
		# must rest before any assist can be used again.
		return {"ok": false, "reason": "assistant_resting"}
	var friend_value: Variant = roster[friend_index]
	var friend: Dictionary = {}
	if friend_value is Dictionary:
		friend = friend_value
	var params: Dictionary = PUWStylerParams.params_for(rid)
	var unlocks_value: Variant = params.get("assist_unlock_rank", {})
	if unlocks_value is Dictionary:
		var unlocks: Dictionary = unlocks_value
		var assist_type: String = str(friend.get("assist_type", ""))
		if unlocks.has(assist_type) and int(ranger.get("rank", 1)) < int(unlocks.get(assist_type, 1)):
			return {"ok": false, "reason": "assist_not_unlocked_at_rank"}
	var result: Dictionary = _apply_assist_effect(state, session, friend, matchup_mult)
	if not bool(result.get("ok", false)):
		return result
	if bool(params.get("assist_presence", false)):
		session["assistant"] = friend.duplicate(true)
		session["assistant_helped"] = true
		session["assistant_rested"] = false
		result["assistant_present"] = true
	else:
		_release_friend_record(state, rid, friend)
		result["released"] = true
	# The assist may itself fill the gauge.
	var required_gauge: float = float(session.get("required", 0.0))
	if str(session.get("model", "")) == "gauge" and required_gauge > 0.0 and float(session.get("gauge", 0.0)) >= required_gauge:
		var done: Dictionary = _complete_befriend(state, session, 0)
		result["captured"] = bool(done.get("captured", false))
	return result


## Guardian Signs: the target's attack hits the physically
## present assistant. It stops, flees, and must rest before it
## can assist again; while it rests, no assist can be used.
static func session_assistant_hit(state: Dictionary, session: Dictionary) -> Dictionary:
	var assistant_value: Variant = session.get("assistant", {})
	if not (assistant_value is Dictionary):
		return {"ok": false, "reason": "no_assistant_present"}
	var assistant: Dictionary = assistant_value
	if assistant.is_empty():
		return {"ok": false, "reason": "no_assistant_present"}
	session["assistant_rested"] = true
	session["assistant_rest_seconds"] = PUWStylerParams.ASSISTANT_REST_SECONDS
	return {"ok": true, "rest_seconds": PUWStylerParams.ASSISTANT_REST_SECONDS}


## Use the Partner's assist. The Partner is never consumed
## and never released -- its assist is permanently on call.
## Fiore: Discharge, gated by the Partner Gauge (filled by
## loops drawn; sized by Rank). Gauge regions: the partner's
## type assist, gated by its Partner Energy gauge refilling
## as loops are drawn.
static func session_apply_partner_assist(state: Dictionary, session: Dictionary, matchup_mult: float) -> Dictionary:
	if bool(session.get("over", false)):
		return {"ok": false, "reason": "session_over"}
	var rid: String = _session_region(session)
	var active_partner: Dictionary = partner(state, rid)
	if active_partner.is_empty():
		return {"ok": false, "reason": "no_partner"}
	var model: String = str(session.get("model", ""))
	if model == "loop_count":
		var ranger: Dictionary = ranger_state(state, rid)
		var params: Dictionary = PUWStylerParams.params_for(rid)
		var gauges_value: Variant = params.get("partner_gauge_by_rank", {})
		var segments: int = 1
		if gauges_value is Dictionary:
			var gauges: Dictionary = gauges_value
			segments = int(gauges.get(int(ranger.get("rank", 1)), 1))
		var loops_needed: int = segments * PUWStylerParams.FIORE_LOOPS_PER_PARTNER_SEGMENT
		var loops_done: int = int(session.get("loops_total", 0))
		if loops_done < loops_needed:
			return {"ok": false, "reason": "partner_gauge_not_full", "loops_needed": loops_needed, "loops_done": loops_done}
		session["status_state"] = "immobilized"
		session["status_seconds"] = PUWStylerParams.FIORE_DISCHARGE_STUN_PER_SEGMENT * float(segments)
		return {"ok": true, "assist_type": "discharge", "state": "immobilized", "segments": segments}
	# Gauge regions: the Partner Energy gauge must be full.
	if float(session.get("partner_gauge", 0.0)) < 1.0:
		return {"ok": false, "reason": "partner_gauge_not_full"}
	session["partner_gauge"] = 0.0
	var result: Dictionary = _apply_assist_effect(state, session, active_partner, matchup_mult)
	if not bool(result.get("ok", false)):
		return result
	var required_gauge: float = float(session.get("required", 0.0))
	if required_gauge > 0.0 and float(session.get("gauge", 0.0)) >= required_gauge:
		var done: Dictionary = _complete_befriend(state, session, 0)
		result["captured"] = bool(done.get("captured", false))
	return result


# ----------------------------------------------------------------
# Target Clear (ruling P4 -- tier grading on the field-action
# canon; the release rule belongs to the Styler fiction only)
# ----------------------------------------------------------------

## The pure qualification check, shared by every caller: a
## helper qualifies for a target when its Field Move level
## meets the target's tier. For the player's OWN followers
## (PUWFieldActions contexts) this is the whole story -- the
## helper is never released.
static func field_qualifies(field_level: int, tier: int) -> bool:
	return field_level >= tier


static func _friend_move_level(friend: Dictionary, move_id: String) -> int:
	var moves_value: Variant = friend.get("field_moves", {})
	if moves_value is Dictionary:
		var moves: Dictionary = moves_value
		return int(moves.get(move_id, 0))
	return 0


## A Friend performs a Target Clear: it must hold the target's
## Field Move at the target's tier, and it is released
## afterward -- one help, then release. Guardian Signs'
## combined clears: pass two Friend indices and their levels
## in the move combine against the tier. Map/Area Moves
## (River Flow and kin) resolve through the same path and
## report their traversal category for the ride canon.
## Target keys: "move" String, "tier" int, "category"
## "field" (default) / "map" / "area".
static func friend_target_clear(state: Dictionary, target: Dictionary, friend_indices: Array) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"ok": false, "reason": "not_a_ranger_region"}
	var params: Dictionary = PUWStylerParams.params_for(rid)
	if friend_indices.is_empty():
		return {"ok": false, "reason": "no_helper"}
	if friend_indices.size() > 1 and not bool(params.get("combined_clears", false)):
		return {"ok": false, "reason": "combined_clears_not_in_region"}
	var move_id: String = str(target.get("move", ""))
	var tier: int = int(target.get("tier", 1))
	var roster: Array = _friends_of(ranger)
	var helpers: Array = []
	var combined_level: int = 0
	for index_value: Variant in friend_indices:
		var index: int = int(index_value)
		if index < 0 or index >= roster.size():
			return {"ok": false, "reason": "no_such_friend"}
		var friend_value: Variant = roster[index]
		if friend_value is Dictionary:
			var friend: Dictionary = friend_value
			helpers.append(friend)
			combined_level += _friend_move_level(friend, move_id)
	if not field_qualifies(combined_level, tier):
		return {"ok": false, "reason": "tier_not_met", "combined_level": combined_level, "tier": tier}
	for helper_value: Variant in helpers:
		var helper: Dictionary = helper_value
		_release_friend_record(state, rid, helper)
	return {
		"ok": true,
		"cleared": true,
		"move": move_id,
		"tier": tier,
		"category": str(target.get("category", "field")),
		"released": helpers.size(),
	}


# ----------------------------------------------------------------
# Ranger Points (Oblivia's local tool-progression track)
# ----------------------------------------------------------------

static func points(state: Dictionary, region_id: String = "") -> int:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return 0
	return int(ranger.get("points", 0))


## SOURCED-R7 Ranger Points economy (replaces v1's
## design-constant grade table -- see PUWStylerParams). Three
## award routes, each once-only per its key:
## - first S-Rank capture of a species: 1 RP (301 species);
## - Mission Clear: 50 RP, once per mission id (the 14-vs-16
##   mission-count divergence is UNRESOLVED -- see params --
##   so no total cap is enforced here);
## - Quest Clear: 10-50 RP, once per quest id.
static func award_srank_points(state: Dictionary, species: String, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	var seen_value: Variant = ranger.get("points_srank_species", [])
	var seen: Array = []
	if seen_value is Array:
		seen = seen_value
	if seen.has(species):
		return {"ok": true, "awarded": 0, "reason": "species_already_awarded", "points": int(ranger.get("points", 0))}
	seen.append(species)
	ranger["points_srank_species"] = seen
	ranger["points"] = int(ranger.get("points", 0)) + PUWStylerParams.POINTS_PER_SRANK_SPECIES
	return {"ok": true, "awarded": PUWStylerParams.POINTS_PER_SRANK_SPECIES, "points": int(ranger.get("points", 0))}


static func award_mission_clear_points(state: Dictionary, mission_id: String, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	var done_value: Variant = ranger.get("points_missions", [])
	var done: Array = []
	if done_value is Array:
		done = done_value
	if done.has(mission_id):
		return {"ok": true, "awarded": 0, "reason": "mission_already_awarded", "points": int(ranger.get("points", 0))}
	done.append(mission_id)
	ranger["points_missions"] = done
	ranger["points"] = int(ranger.get("points", 0)) + PUWStylerParams.POINTS_PER_MISSION_CLEAR
	return {"ok": true, "awarded": PUWStylerParams.POINTS_PER_MISSION_CLEAR, "points": int(ranger.get("points", 0))}


static func award_quest_clear_points(state: Dictionary, quest_id: String, amount: int, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	if amount < PUWStylerParams.POINTS_QUEST_MIN or amount > PUWStylerParams.POINTS_QUEST_MAX:
		return {"ok": false, "reason": "quest_points_out_of_sourced_range"}
	var done_value: Variant = ranger.get("points_quests", [])
	var done: Array = []
	if done_value is Array:
		done = done_value
	if done.has(quest_id):
		return {"ok": true, "awarded": 0, "reason": "quest_already_awarded", "points": int(ranger.get("points", 0))}
	done.append(quest_id)
	ranger["points_quests"] = done
	ranger["points"] = int(ranger.get("points", 0)) + amount
	return {"ok": true, "awarded": amount, "points": int(ranger.get("points", 0))}


## Buy the next level of a Styler Modification track at its
## SOURCED-R7 catalog price (PUWStylerParams.
## MODIFICATION_TRACKS). Full catalog = 2,100 RP against
## 2,101 RP total available: a complete buyout leaves
## exactly 1 RP. Refuses on unknown track, maxed track, or
## insufficient points; never goes negative.
static func buy_modification(state: Dictionary, track_id: String, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	var prices_value: Variant = PUWStylerParams.MODIFICATION_TRACKS.get(track_id, [])
	var prices: Array = []
	if prices_value is Array:
		prices = prices_value
	if prices.is_empty():
		return {"ok": false, "reason": "unknown_modification_track"}
	var levels_value: Variant = ranger.get("modification_levels", {})
	var levels: Dictionary = {}
	if levels_value is Dictionary:
		levels = levels_value
	var level: int = int(levels.get(track_id, 0))
	if level >= prices.size():
		return {"ok": false, "reason": "track_maxed"}
	var cost: int = int(prices[level])
	if int(ranger.get("points", 0)) < cost:
		return {"ok": false, "reason": "insufficient_points"}
	ranger["points"] = int(ranger.get("points", 0)) - cost
	levels[track_id] = level + 1
	ranger["modification_levels"] = levels
	return {"ok": true, "track": track_id, "level": level + 1, "cost": cost, "points": int(ranger.get("points", 0))}


static func modification_level(state: Dictionary, track_id: String, region_id: String = "") -> int:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return 0
	var levels_value: Variant = ranger.get("modification_levels", {})
	if levels_value is Dictionary:
		var levels: Dictionary = levels_value
		return int(levels.get(track_id, 0))
	return 0


## Spend Ranger Points on a present-day Styler upgrade. The
## upgrade catalog is content (the games sell tool upgrades);
## this is the wallet the catalog draws on. Refuses cleanly
## on insufficient points and never goes negative.
static func spend_points(state: Dictionary, upgrade_id: String, cost: int, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	if cost <= 0:
		return {"ok": false, "reason": "bad_cost"}
	if int(ranger.get("points", 0)) < cost:
		return {"ok": false, "reason": "insufficient_points"}
	ranger["points"] = int(ranger.get("points", 0)) - cost
	var upgrades_value: Variant = ranger.get("points_upgrades", {})
	var upgrades: Dictionary = {}
	if upgrades_value is Dictionary:
		upgrades = upgrades_value
	upgrades[upgrade_id] = int(upgrades.get(upgrade_id, 0)) + 1
	ranger["points_upgrades"] = upgrades
	return {"ok": true, "points": int(ranger.get("points", 0))}


## The past-temple track (Oblivia's era layer): points earned
## in the past upgrade the past Partner along Assist /
## Healing / Power, each to a maximum of level 5 (sourced).
## Past points are their own wallet -- they are earned in the
## past and spent in the past.
static func award_past_points(state: Dictionary, amount: int, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	ranger["past_points"] = int(ranger.get("past_points", 0)) + maxi(0, amount)
	return {"ok": true, "past_points": int(ranger.get("past_points", 0))}


static func upgrade_past_partner(state: Dictionary, axis: String, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty() or rid != "oblivia":
		return {"ok": false, "reason": "no_points_track_in_region"}
	if not PUWStylerParams.PAST_TRACK_AXES.has(axis):
		return {"ok": false, "reason": "unknown_axis"}
	var upgrades_value: Variant = ranger.get("past_upgrades", {})
	var upgrades: Dictionary = {}
	if upgrades_value is Dictionary:
		upgrades = upgrades_value
	var level: int = int(upgrades.get(axis, 0))
	if level >= PUWStylerParams.PAST_TRACK_MAX:
		return {"ok": false, "reason": "axis_maxed"}
	var cost: int = PUWStylerParams.PAST_TRACK_COST_PER_LEVEL * (level + 1)
	if int(ranger.get("past_points", 0)) < cost:
		return {"ok": false, "reason": "insufficient_points"}
	ranger["past_points"] = int(ranger.get("past_points", 0)) - cost
	upgrades[axis] = level + 1
	ranger["past_upgrades"] = upgrades
	return {"ok": true, "axis": axis, "level": level + 1, "past_points": int(ranger.get("past_points", 0))}


# ----------------------------------------------------------------
# Oblivia PAST Styler track (SOURCED-R7) -- a separate Styler
# with its own level / Exp / Energy in the region record's
# "past_styler" sub-record. Present != past: nothing here
# reads or writes the present track's level, Exp, or Energy,
# and the present track never reads these. (Distinct again
# from the past PARTNER upgrade axes below in the points
# section: Assist / Healing / Power -- those are the partner,
# this is the tool.)
# ----------------------------------------------------------------

static func past_styler_state(state: Dictionary, region_id: String = "") -> Dictionary:
	var ranger: Dictionary = ranger_state(state, region_id)
	if ranger.is_empty():
		return {}
	var value: Variant = ranger.get("past_styler", {})
	if value is Dictionary:
		var existing: Dictionary = value
		if not existing.is_empty():
			return existing
	var fresh: Dictionary = {"styler_level": 1, "styler_exp": 0, "energy": int(PUWStylerParams.OBLIVIA_PAST.get("energy_base", 30))}
	ranger["past_styler"] = fresh
	return fresh


static func past_styler_level(state: Dictionary, region_id: String = "") -> int:
	var past: Dictionary = past_styler_state(state, region_id)
	if past.is_empty():
		return 0
	return int(past.get("styler_level", 1))


static func past_energy(state: Dictionary, region_id: String = "") -> int:
	var past: Dictionary = past_styler_state(state, region_id)
	if past.is_empty():
		return 0
	return int(past.get("energy", 0))


static func past_power(state: Dictionary, region_id: String = "") -> int:
	return power_at_level("oblivia", past_styler_level(state, region_id), "past")


## Award Exp to the PAST Styler only; level-ups raise the
## past Energy maximum and add the delta (the past track
## does not inherit the present track's full-restore rule --
## no source documents one for the past).
static func award_past_styler_exp(state: Dictionary, amount: int, region_id: String = "") -> Dictionary:
	var rid: String = region_id
	if rid == "":
		rid = PUWRegionState.active_region(state)
	if rid != "oblivia":
		return {"levels_gained": 0}
	var past: Dictionary = past_styler_state(state, rid)
	if past.is_empty():
		return {"levels_gained": 0}
	var levels_cap: int = int(PUWStylerParams.OBLIVIA_PAST.get("styler_levels", 99))
	var old_level: int = int(past.get("styler_level", 1))
	var total_exp: int = int(past.get("styler_exp", 0)) + maxi(0, amount)
	past["styler_exp"] = total_exp
	var new_level: int = old_level
	while new_level < levels_cap and total_exp >= exp_for_level("oblivia", new_level + 1, "past"):
		new_level += 1
	if new_level > old_level:
		past["styler_level"] = new_level
		var delta: int = energy_max("oblivia", new_level, "past") - energy_max("oblivia", old_level, "past")
		past["energy"] = mini(energy_max("oblivia", new_level, "past"), int(past.get("energy", 0)) + delta)
	return {"levels_gained": new_level - old_level}


## The session's sourced agitated-gauge requirement for its
## target (Oblivia's second per-species data dimension), or
## -1.0 when the species/encounter documents none. Carried
## as data from PUWStylerSpeciesData records; no ratio is
## applied here.
static func session_agitated_requirement(session: Dictionary) -> float:
	var value: Variant = session.get("agitated_gauge_points", [])
	if value is Array:
		var points: Array = value
		if not points.is_empty():
			return float(points[0])
	return -1.0


# ----------------------------------------------------------------
# Ranger Signs (ruling P7 -- Oblivia's mount-call idiom)
# ----------------------------------------------------------------

## A charged sign is a high-friendship call: it is gated
## behind the care layer's canon threshold (160), read
## through the real PUWFollowerCare. Uncharged signs are
## learned by befriending and are content's concern; this is
## the one gate the ruling assigns to the system.
static func charged_sign_allowed(follower_mon: Dictionary) -> bool:
	return PUWFollowerCare.friendship_of(follower_mon) >= PUWStylerParams.CHARGED_SIGN_CARE_THRESHOLD


# ----------------------------------------------------------------
# Transfer rewards -- the ONLY permanent gains (ruling P1)
# ----------------------------------------------------------------

## Mission content grants a transfer reward earned in a
## Ranger mission. The reward waits, pending, in the ORIGIN
## region's record; it becomes a Pokemon only when claimed
## in the wider game (claim_transfer_reward). Capture code
## never calls this -- a Styler befriending can produce a
## Friend and nothing else, ever.
static func grant_transfer_reward(state: Dictionary, reward_id: String) -> Dictionary:
	var rid: String = PUWRegionState.active_region(state)
	var ranger: Dictionary = ranger_state(state, rid)
	if ranger.is_empty():
		return {"ok": false, "reason": "not_a_ranger_region"}
	var table_value: Variant = PUWStylerParams.TRANSFER_REWARDS.get(reward_id, {})
	if not (table_value is Dictionary):
		return {"ok": false, "reason": "unknown_reward"}
	var entry: Dictionary = table_value
	var sources_value: Variant = entry.get("source_regions", [])
	var sources: Array = []
	if sources_value is Array:
		sources = sources_value
	if not sources.has(rid):
		return {"ok": false, "reason": "reward_not_from_this_region"}
	var pending_value: Variant = ranger.get("transfer_pending", [])
	var pending: Array = []
	if pending_value is Array:
		pending = pending_value
	var claimed_value: Variant = ranger.get("transfer_claimed", [])
	var claimed: Array = []
	if claimed_value is Array:
		claimed = claimed_value
	if pending.has(reward_id) or claimed.has(reward_id):
		return {"ok": false, "reason": "already_granted"}
	pending.append(reward_id)
	ranger["transfer_pending"] = pending
	return {"ok": true, "reward_id": reward_id, "origin_region": rid}


## Every pending transfer reward across the three Ranger
## regions, as {"reward_id", "origin_region"} records.
static func pending_transfer_rewards(state: Dictionary) -> Array:
	var out: Array = []
	for region_value: Variant in PUWRangerAvailability.RANGER_REGIONS:
		var rid: String = str(region_value)
		var root: Dictionary = PUWRegionState.ensure_regions(state)
		var records_value: Variant = root.get("regions", {})
		if not (records_value is Dictionary):
			continue
		var records: Dictionary = records_value
		var record_value: Variant = records.get(rid, {})
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var ranger_value: Variant = record.get("ranger", {})
		if not (ranger_value is Dictionary):
			continue
		var ranger: Dictionary = ranger_value
		var pending_value: Variant = ranger.get("transfer_pending", [])
		if pending_value is Array:
			var pending: Array = pending_value
			for reward_value: Variant in pending:
				out.append({"reward_id": str(reward_value), "origin_region": rid})
	return out


## Claim a pending transfer reward IN THE WIDER GAME: the
## active region must not be a Ranger region (in source the
## reward is received in a different game entirely). The
## reward template is appended to the active region's working
## boxes -- the one collection write this module ever makes,
## and the only path by which a Ranger region's content can
## become a permanent Pokemon. Transfers are once-only.
static func claim_transfer_reward(state: Dictionary, reward_id: String) -> Dictionary:
	var active: String = PUWRegionState.active_region(state)
	if PUWRangerAvailability.is_ranger_region(active):
		return {"ok": false, "reason": "received_in_the_wider_game"}
	var origin: String = ""
	for pending_value: Variant in pending_transfer_rewards(state):
		if pending_value is Dictionary:
			var pending_entry: Dictionary = pending_value
			if str(pending_entry.get("reward_id", "")) == reward_id:
				origin = str(pending_entry.get("origin_region", ""))
	if origin == "":
		return {"ok": false, "reason": "no_such_pending_reward"}
	var ranger: Dictionary = ranger_state(state, origin)
	var pending_list_value: Variant = ranger.get("transfer_pending", [])
	var pending_list: Array = []
	if pending_list_value is Array:
		pending_list = pending_list_value
	pending_list.erase(reward_id)
	ranger["transfer_pending"] = pending_list
	var claimed_value: Variant = ranger.get("transfer_claimed", [])
	var claimed: Array = []
	if claimed_value is Array:
		claimed = claimed_value
	claimed.append(reward_id)
	ranger["transfer_claimed"] = claimed
	var entry_value: Variant = PUWStylerParams.TRANSFER_REWARDS.get(reward_id, {})
	var entry: Dictionary = {}
	if entry_value is Dictionary:
		entry = entry_value
	var mon: Dictionary = {
		"name": str(entry.get("species", "")),
		"species": str(entry.get("species", "")),
		"egg": bool(entry.get("egg", false)),
		"origin": "ranger_transfer",
		"transfer_reward": reward_id,
		"origin_region": origin,
	}
	var moves_value: Variant = entry.get("signature_moves", [])
	if moves_value is Array:
		var moves: Array = moves_value
		if not moves.is_empty():
			mon["moves"] = moves.duplicate()
	if bool(entry.get("fateful_encounter", false)):
		mon["fateful_encounter"] = true
	var boxes_value: Variant = state.get("boxes", [])
	var boxes: Array = []
	if boxes_value is Array:
		boxes = boxes_value
	boxes.append(mon)
	state["boxes"] = boxes
	return {"ok": true, "mon": mon.duplicate(true), "origin_region": origin}
