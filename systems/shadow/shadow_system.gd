class_name PUWShadowSystem
extends RefCounted
## Shadow / snag / purification system (Orre) -- code prep,
## 2026-11-23. Built per ORRE_BUILD_PREP.md SS4 and the special
## Pokemon register SS12 (locked ruling): Shadow is a TREATMENT
## CLASS on an individual Pokemon (SHADOW_TREATMENT_CLASS), never
## a species form and never a generic shadow palette. The sole
## exception is SHADOW_LUGIA_XD001, a true form record, handled
## by is_xd001() below. Purification is a lifecycle: Shadow ->
## purified keeps a PERMANENT "formerly Shadow" provenance flag.
##
## All-static API over plain mon dictionaries and the save-state
## dictionary (house style of PUWRegionState / PUWQuestBoard).
## Mon dicts are the same JSON-safe dictionaries the save manager
## treats as opaque, so the four fields below ride through
## PUWSaveManager.build_state / save / load untouched, and
## through PUWRegionState's per-region party/box sync untouched:
## a Shadow mon is an ordinary member of Orre's sealed pool.
##
## THE FOUR FIELDS (Orre prep SS4.1), riding alongside the G1
## UUID ("mon_id"; every Shadow individual is a scripted unique,
## so the UUID system carries its identity):
##   "shadow_state":   absent = never Shadow (the field is
##                     written only by Orre scripted content);
##                     "shadow" / "purified" once stamped.
##   "heart_gauge":    int, current gauge. The gauge starts FULL
##                     (heart closed) and EMPTIES as the heart
##                     opens; 0 = ready to purify.
##   "heart_gauge_max": int, per individual.
##   "heart_stage":    int 0..5, derived from the source's
##                     five-stage gauge; maintained by every
##                     gauge write in this file.
##   "formerly_shadow": bool, set true at purification, never
##                     cleared by any function here.
##   "shadow_origin":  the register key of the staged
##                     individual, "orre:<game>:<location_id>:
##                     <species_slug>:<trainer>", matching
##                     data/shadow_register_index.json exactly
##                     (the same traceability Rocky/Gaspar have).
##
## NUMBERS: everything not sourced is a PUW DESIGN CONSTANT and
## is labeled as such, here and in the prep report's table.
## Sourced structure: five heart stages; gauge empties toward
## purification; care/battle/walk open the heart; Relic Stone
## purifies at an empty gauge; Time Flutes purify instantly;
## the Purify Chamber is XD001's only path (purify_chamber.gd).
## NOT staged anywhere (Orre prep SS3.4, gap D7) and therefore
## NOT invented here: per-individual Heart Gauge sizes (the
## index carries heart_gauge_max = null per record; the default
## below applies until a sourced pass fills them), Shadow move
## data (mon["shadow_moves"] is a data-shaped field this system
## reads but no held source populates yet), Hyper Mode rates
## (not implemented -- no sourced rates exist), and the
## purification EXP bonus amount (the bonus is sourced
## behavior; its amount is flagged, never faked -- see
## _finish_purification).

const STATE_SHADOW: String = "shadow"
const STATE_PURIFIED: String = "purified"

const HEART_STAGE_COUNT: int = 5 # sourced: the source gauge has five stages
const DEFAULT_HEART_GAUGE_MAX: int = 100 # PUW DESIGN CONSTANT (per-individual values unstaged, gap D7; only ratios drive the mechanics, so a sourced rescale is a data swap)
const BATTLE_PARTICIPATION_POINTS: int = 10 # PUW DESIGN CONSTANT (the source's "calling in battle" path, routed per battle the mon participates in)
const WALK_STEPS_PER_POINT: int = 100 # PUW DESIGN CONSTANT (the source's walking path)
const TIME_FLUTE_ITEM: String = "time-flute" # Colosseum's sourced instant-purification item (one-use, consumed from the bag)
const LEDGER_KEY: String = "shadow_ledger" # additive save-state key (habitat_rotation precedent)


# ----------------------------------------------------------------
# Identity / state reads
# ----------------------------------------------------------------

static func shadow_state_of(mon: Dictionary) -> String:
	return str(mon.get("shadow_state", ""))


static func is_shadow(mon: Dictionary) -> bool:
	return shadow_state_of(mon) == STATE_SHADOW


static func is_purified(mon: Dictionary) -> bool:
	return shadow_state_of(mon) == STATE_PURIFIED


static func was_shadow(mon: Dictionary) -> bool:
	return bool(mon.get("formerly_shadow", false))


static func shadow_origin_of(mon: Dictionary) -> String:
	return str(mon.get("shadow_origin", ""))


## XD001 is the register's sole Shadow FORM record
## (SHADOW_LUGIA_XD001): the XD Lugia individual. Derived from
## the origin key so no fifth mon field is needed.
static func is_xd001(mon: Dictionary) -> bool:
	var origin: String = shadow_origin_of(mon)
	return origin.begins_with("orre:xd:") and origin.contains(":lugia:")


static func heart_gauge_of(mon: Dictionary) -> int:
	return int(mon.get("heart_gauge", 0))


static func heart_gauge_max_of(mon: Dictionary) -> int:
	return int(mon.get("heart_gauge_max", 0))


## The five-stage derivation: stage counts how many fifths of
## the gauge have emptied. Full gauge -> 0, empty gauge -> 5.
static func heart_stage_for(gauge: int, gauge_max: int) -> int:
	if gauge_max <= 0:
		return 0
	var remaining: float = clampf(float(gauge) / float(gauge_max), 0.0, 1.0)
	var stage: int = HEART_STAGE_COUNT - int(ceil(remaining * float(HEART_STAGE_COUNT)))
	return clampi(stage, 0, HEART_STAGE_COUNT)


static func heart_stage_of(mon: Dictionary) -> int:
	return int(mon.get("heart_stage", heart_stage_for(heart_gauge_of(mon), heart_gauge_max_of(mon))))


static func _sync_stage(mon: Dictionary) -> void:
	mon["heart_stage"] = heart_stage_for(heart_gauge_of(mon), heart_gauge_max_of(mon))


# ----------------------------------------------------------------
# Stamping (Orre scripted content only)
# ----------------------------------------------------------------

## Stamp a mon as one of the 131 staged Shadow individuals.
## gauge_max <= 0 applies DEFAULT_HEART_GAUGE_MAX (the index's
## per-record heart_gauge_max is null until gap D7 closes).
## Refuses to re-stamp a Shadow mon, and refuses absolutely to
## stamp a purified / formerly-Shadow mon: provenance is
## permanent and scripted uniques are one-per-save.
static func stamp_shadow(mon: Dictionary, origin_key: String, gauge_max: int = -1) -> Dictionary:
	if is_shadow(mon):
		return {"ok": false, "reason": "already_shadow"}
	if is_purified(mon) or was_shadow(mon):
		return {"ok": false, "reason": "already_purified"}
	var applied_max: int = gauge_max if gauge_max > 0 else DEFAULT_HEART_GAUGE_MAX
	mon["shadow_state"] = STATE_SHADOW
	mon["heart_gauge_max"] = applied_max
	mon["heart_gauge"] = applied_max
	mon["formerly_shadow"] = false
	mon["shadow_origin"] = origin_key
	_sync_stage(mon)
	return {"ok": true, "reason": "", "heart_gauge": applied_max, "heart_gauge_max": applied_max, "heart_stage": 0}


# ----------------------------------------------------------------
# Heart gauge opening: battle, walking, care
# ----------------------------------------------------------------

## Reduce the gauge by points (never below 0). No-op with
## reason "not_shadow" for any mon not currently Shadow --
## purified mons keep formerly_shadow and take no gauge writes.
static func apply_gauge_points(mon: Dictionary, points: int) -> Dictionary:
	if not is_shadow(mon):
		return {"ok": false, "reason": "not_shadow", "applied": 0, "heart_gauge": heart_gauge_of(mon)}
	if points <= 0:
		return {"ok": false, "reason": "no_points", "applied": 0, "heart_gauge": heart_gauge_of(mon)}
	var before: int = heart_gauge_of(mon)
	var after: int = maxi(0, before - points)
	mon["heart_gauge"] = after
	_sync_stage(mon)
	return {"ok": true, "reason": "", "applied": before - after, "heart_gauge": after, "heart_stage": heart_stage_of(mon), "ready_to_purify": after == 0}


## The follower-care routing (Orre prep SS4.3.1, labeled design
## position): care points earned by a Shadow follower go into
## its heart gauge instead of the friendship track. Called by
## PUWFollowerCare._apply_gain (patched copy); the point values
## are the care layer's own constants (talk +2, groom +3,
## treat +5), routed 1:1.
static func apply_care_points(mon: Dictionary, points: int) -> Dictionary:
	return apply_gauge_points(mon, points)


## The battle path: a Shadow mon that participated in a battle
## opens its heart by BATTLE_PARTICIPATION_POINTS (the source's
## calling-in-battle equivalent, per participated battle).
static func apply_battle_participation(mon: Dictionary) -> Dictionary:
	return apply_gauge_points(mon, BATTLE_PARTICIPATION_POINTS)


## The walking path: WALK_STEPS_PER_POINT steps = 1 point.
## Sub-point steps accumulate on the mon dict
## ("heart_walk_remainder", a transient progress counter like
## the battle layer's "participated" flag; erased at
## purification).
static func apply_walk_steps(mon: Dictionary, steps: int) -> Dictionary:
	if not is_shadow(mon):
		return {"ok": false, "reason": "not_shadow", "applied": 0, "heart_gauge": heart_gauge_of(mon)}
	if steps <= 0:
		return {"ok": false, "reason": "no_steps", "applied": 0, "heart_gauge": heart_gauge_of(mon)}
	var total: int = int(mon.get("heart_walk_remainder", 0)) + steps
	var points: int = total / WALK_STEPS_PER_POINT
	mon["heart_walk_remainder"] = total % WALK_STEPS_PER_POINT
	if points <= 0:
		return {"ok": true, "reason": "", "applied": 0, "heart_gauge": heart_gauge_of(mon), "heart_stage": heart_stage_of(mon), "ready_to_purify": heart_gauge_of(mon) == 0}
	return apply_gauge_points(mon, points)


# ----------------------------------------------------------------
# Moves (data-shaped seam; Shadow move DATA is gap D7)
# ----------------------------------------------------------------

## The active move set: while Shadow, the mon's staged Shadow
## moves (mon["shadow_moves"], populated only when the D7 data
## pass stages them -- empty until then, never invented) plus
## the normal moves the heart stages have unlocked: one normal
## move per emptied stage, in learnset order, as in the source's
## progressive replacement. Purified / never-Shadow mons use
## their full normal set.
static func active_move_set(mon: Dictionary, normal_moves: Array) -> Dictionary:
	if not is_shadow(mon):
		return {"moves": normal_moves.duplicate(), "unlocked_normal": normal_moves.size(), "shadow_moves": 0}
	var shadow_moves_value: Variant = mon.get("shadow_moves", [])
	var shadow_moves: Array = []
	if shadow_moves_value is Array:
		var sm: Array = shadow_moves_value
		shadow_moves = sm.duplicate()
	var unlocked: int = mini(heart_stage_of(mon), normal_moves.size())
	var moves: Array = shadow_moves.duplicate()
	for i in unlocked:
		moves.append(normal_moves[i])
	return {"moves": moves, "unlocked_normal": unlocked, "shadow_moves": shadow_moves.size()}


# ----------------------------------------------------------------
# Purification
# ----------------------------------------------------------------

static func ready_to_purify(mon: Dictionary) -> bool:
	return is_shadow(mon) and heart_gauge_of(mon) == 0


## Gate shared by the Relic Stone path. XD001 is refused here
## on every non-chamber path: its only purification route is
## the Purify Chamber at maximum tempo in all nine chambers
## (register SS12; purify_chamber.gd).
static func can_purify(mon: Dictionary) -> Dictionary:
	if not is_shadow(mon):
		return {"ok": false, "reason": "not_shadow"}
	if is_xd001(mon):
		return {"ok": false, "reason": "xd001_chamber_only"}
	if heart_gauge_of(mon) > 0:
		return {"ok": false, "reason": "gauge_not_empty", "heart_gauge": heart_gauge_of(mon)}
	return {"ok": true, "reason": ""}


static func _finish_purification(mon: Dictionary) -> Dictionary:
	mon["shadow_state"] = STATE_PURIFIED
	mon["formerly_shadow"] = true
	mon["heart_gauge"] = 0
	_sync_stage(mon)
	mon.erase("heart_walk_remainder")
	# The source grants a purification EXP bonus. The bonus is
	# sourced behavior but its AMOUNT is not staged anywhere
	# (gap D7): this prep applies none and reports the fact, so
	# the binding build wires the real number at the marked
	# point instead of a fabricated one.
	return {"ok": true, "reason": "", "exp_bonus": -1, "exp_bonus_status": "not_staged_gap_d7"}


## Relic Stone (Agate Village): purify at an empty gauge.
static func purify_at_relic_stone(mon: Dictionary) -> Dictionary:
	var gate: Dictionary = can_purify(mon)
	if not bool(gate.get("ok", false)):
		return gate
	return _finish_purification(mon)


## The chamber-side finish, called only by PUWPurifyChamber:
## an ordinary Shadow mon purifies in the chamber when its
## gauge empties there. XD001 also finishes here, but only
## after PUWPurifyChamber.try_purify_xd001 has enforced the
## all-nine-chambers-at-maximum-tempo rule -- this function is
## not a public purification path and no other caller may use
## it (the merge steps wire no other call site).
static func purify_in_chamber(mon: Dictionary) -> Dictionary:
	if not is_shadow(mon):
		return {"ok": false, "reason": "not_shadow"}
	if heart_gauge_of(mon) > 0:
		return {"ok": false, "reason": "gauge_not_empty", "heart_gauge": heart_gauge_of(mon)}
	return _finish_purification(mon)


## Time Flute: summons Celebi for instant purification
## (Colosseum), bypassing the gauge. Consumes exactly one
## time-flute from the bag dictionary. XD001 is still refused:
## the flutes are Colosseum's and XD001's chamber-only rule is
## absolute (register SS12).
static func purify_with_time_flute(mon: Dictionary, bag: Dictionary) -> Dictionary:
	if not is_shadow(mon):
		return {"ok": false, "reason": "not_shadow"}
	if is_xd001(mon):
		return {"ok": false, "reason": "xd001_chamber_only"}
	if int(bag.get(TIME_FLUTE_ITEM, 0)) <= 0:
		return {"ok": false, "reason": "no_flute"}
	bag[TIME_FLUTE_ITEM] = int(bag.get(TIME_FLUTE_ITEM, 0)) - 1
	if int(bag[TIME_FLUTE_ITEM]) <= 0:
		bag.erase(TIME_FLUTE_ITEM)
	mon["heart_gauge"] = 0
	_sync_stage(mon)
	return _finish_purification(mon)


# ----------------------------------------------------------------
# Presentation gates (Orre prep SS4.2 / SS4.5)
# ----------------------------------------------------------------

## The dark-aura TREATMENT is always visible while a mon is
## Shadow (battle and follower presentation), and drops at
## purification. formerly_shadow is data, not a visual.
static func aura_visible(mon: Dictionary) -> bool:
	return is_shadow(mon)


## The aura MARKER / label is story-gated: Rui's aura sight in
## the Colosseum arc, the Snag Machine's aura detector in XD.
## identification_reached is the arc's story flag, passed in.
static func marker_visible(mon: Dictionary, identification_reached: bool) -> bool:
	return identification_reached and is_shadow(mon)


# ----------------------------------------------------------------
# Snag legality (the battle patch calls snag_refusal; the throw
# itself reuses attempt_capture's catch math -- Orre prep SS4.2:
# snag success uses the species' normal catch rate against the
# ball, as in the source)
# ----------------------------------------------------------------

## Returns "" when a snag throw at target is legal, else the
## refusal reason. Target state is checked first: a ball is not
## wasted on a non-Shadow mon (the source's own framing), so a
## non-Shadow target refuses even when the machine is missing.
static func snag_refusal(target: Dictionary, machine_held: bool) -> String:
	if not is_shadow(target):
		return "not_shadow"
	if not machine_held:
		return "no_machine"
	return ""


static func snag_legal(target: Dictionary, machine_held: bool) -> bool:
	return snag_refusal(target, machine_held) == ""


# ----------------------------------------------------------------
# The Shadow ledger: snagged / missed / permanently fainted
# records, keyed by shadow_origin. Lives on the save state as
# an additive top-level key (habitat_rotation precedent).
# Discipline (register-wide, Orre prep SS4.4): a snagged record
# never re-offers; a snagged mon that later faints permanently
# under PUW permadeath canon is gone and its record does not
# respawn.
# ----------------------------------------------------------------

static func ensure_ledger(state: Dictionary) -> Dictionary:
	var ledger_value: Variant = state.get(LEDGER_KEY, {})
	if ledger_value is Dictionary:
		var ledger: Dictionary = ledger_value
		for key in ["snagged", "missed", "permanently_fainted"]:
			if not ledger.has(key):
				ledger[key] = {}
		state[LEDGER_KEY] = ledger
		return ledger
	var fresh: Dictionary = {"snagged": {}, "missed": {}, "permanently_fainted": {}}
	state[LEDGER_KEY] = fresh
	return fresh


static func record_snag(state: Dictionary, origin_key: String) -> void:
	var ledger: Dictionary = ensure_ledger(state)
	var snagged_value: Variant = ledger.get("snagged", {})
	if snagged_value is Dictionary:
		var snagged: Dictionary = snagged_value
		snagged[origin_key] = true
	var missed_value: Variant = ledger.get("missed", {})
	if missed_value is Dictionary:
		var missed: Dictionary = missed_value
		missed.erase(origin_key)


static func record_missed(state: Dictionary, origin_key: String) -> void:
	var ledger: Dictionary = ensure_ledger(state)
	var snagged_value: Variant = ledger.get("snagged", {})
	if snagged_value is Dictionary:
		var snagged: Dictionary = snagged_value
		if bool(snagged.get(origin_key, false)):
			return
	var missed_value: Variant = ledger.get("missed", {})
	if missed_value is Dictionary:
		var missed: Dictionary = missed_value
		missed[origin_key] = true


## Record that a snagged Shadow mon fainted permanently (the
## caller routes the faint itself through the house permadeath
## machinery -- PUWCombatConsequences / PartyAndStorageManager
## -- this only closes the register record). Returns true when
## the mon carried a shadow_origin to close.
static func record_permanent_faint(state: Dictionary, mon: Dictionary) -> bool:
	var origin: String = shadow_origin_of(mon)
	if origin == "":
		return false
	var ledger: Dictionary = ensure_ledger(state)
	var fainted_value: Variant = ledger.get("permanently_fainted", {})
	if fainted_value is Dictionary:
		var fainted: Dictionary = fainted_value
		fainted[origin] = true
	return true


static func record_closed(state: Dictionary, origin_key: String) -> bool:
	var ledger: Dictionary = ensure_ledger(state)
	var snagged_value: Variant = ledger.get("snagged", {})
	if snagged_value is Dictionary:
		var snagged: Dictionary = snagged_value
		if bool(snagged.get(origin_key, false)):
			return true
	var fainted_value: Variant = ledger.get("permanently_fainted", {})
	if fainted_value is Dictionary:
		var fainted: Dictionary = fainted_value
		if bool(fainted.get(origin_key, false)):
			return true
	return false


## The missed-snag recovery pool (Orre prep SS4.4, sourced):
## every missed record that is not closed and whose register
## routing is not "none", with its venues. XD records route to
## Miror B. (Pyrite Colosseum, Realgam Colosseum, the Poke
## Spots); Colosseum records route to the Shadow Pokemon Lab /
## Snagem Hideout. The XD Voltorb record carries recovery
## "none" in the index -- it has no reappearance flag in the
## source (Bulbapedia) -- and never enters the pool even when
## marked missed. XD001 likewise carries "none" (its
## re-encounter is the scripted Greevil rematch).
static func recovery_pool(state: Dictionary, index_records: Array) -> Array:
	var ledger: Dictionary = ensure_ledger(state)
	var missed_value: Variant = ledger.get("missed", {})
	var missed: Dictionary = {}
	if missed_value is Dictionary:
		var m: Dictionary = missed_value
		missed = m
	var pool: Array = []
	for record_value in index_records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var key: String = str(record.get("origin_key", ""))
		if key == "" or not bool(missed.get(key, false)):
			continue
		if record_closed(state, key):
			continue
		if str(record.get("recovery", "none")) == "none":
			continue
		var entry: Dictionary = record.duplicate()
		entry["pool"] = str(record.get("recovery", ""))
		pool.append(entry)
	return pool
