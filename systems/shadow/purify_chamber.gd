class_name PUWPurifyChamber
extends RefCounted
## The Purify Chamber (Pokemon HQ Lab, XD layer) -- code prep,
## 2026-11-23. Per Orre prep SS4.3.3: the nine-chamber
## set-network system; tempo comes from type matchups; it
## purifies up to nine Shadow mons held in set networks. In PUW
## terms this is a facility model over the SAME heart-gauge
## state PUWShadowSystem owns -- there is no second gauge.
##
## A chamber holds one SET: an ordered circle of up to SET_MAX
## mons, exactly one of them the Shadow mon being purified (the
## others are the player's normal mons forming the network).
## Tempo measures how strongly the circle flows: for each
## adjacent pair (wrapping around), the pair flows when either
## mon has a type super-effective against the other's types,
## read from the REAL type chart (PUWBattleEngine.
## type_multiplier). Tempo scales 0..TEMPO_MAX by the fraction
## of flowing pairs.
##
## XD001's ONLY purification path lives here (register SS12):
## Shadow Lugia purifies only when ALL NINE chambers stand at
## maximum tempo and its own gauge has emptied in its chamber.
## chamber_tick never auto-purifies XD001; try_purify_xd001 is
## the sole route, and PUWShadowSystem refuses XD001 on the
## Relic Stone and Time Flute paths.
##
## NUMBERS: TEMPO_MAX and SET_MAX and the per-tick gauge rate
## are PUW DESIGN CONSTANTS (labeled; the source's structure --
## nine chambers, set networks, tempo from type matchups,
## XD001's all-nine-maximum rule -- is what is sourced; the
## source's exact tempo scale and per-time gauge rates are not
## staged anywhere, gap D7 territory). State lives on the save
## state as an additive key, "purify_chamber", whose chambers
## hold the actual mon dictionaries (the same dicts the party /
## boxes hold; the facility is a view over them, not a copy --
## callers place the live dicts).

const CHAMBER_COUNT: int = 9 # sourced: nine chambers
const SET_MAX: int = 4 # PUW DESIGN CONSTANT (set-network size)
const TEMPO_MAX: int = 4 # PUW DESIGN CONSTANT (tempo scale)
const TICK_POINTS_PER_TEMPO: int = 5 # PUW DESIGN CONSTANT (gauge points per tick per tempo level)
const STATE_KEY: String = "purify_chamber"


static func ensure_chamber_state(state: Dictionary) -> Dictionary:
	var existing_value: Variant = state.get(STATE_KEY, {})
	if existing_value is Dictionary:
		var existing: Dictionary = existing_value
		var chambers_value: Variant = existing.get("chambers", [])
		if chambers_value is Array:
			var chambers: Array = chambers_value
			while chambers.size() < CHAMBER_COUNT:
				chambers.append({"set": []})
			existing["chambers"] = chambers
			state[STATE_KEY] = existing
			return existing
	var chambers: Array = []
	for i in CHAMBER_COUNT:
		chambers.append({"set": []})
	var fresh: Dictionary = {"chambers": chambers}
	state[STATE_KEY] = fresh
	return fresh


static func _chamber(state: Dictionary, chamber_idx: int) -> Dictionary:
	var chamber_state: Dictionary = ensure_chamber_state(state)
	var chambers_value: Variant = chamber_state.get("chambers", [])
	if chambers_value is Array:
		var chambers: Array = chambers_value
		if chamber_idx >= 0 and chamber_idx < chambers.size():
			var chamber_value: Variant = chambers[chamber_idx]
			if chamber_value is Dictionary:
				var chamber: Dictionary = chamber_value
				return chamber
	return {}


static func set_of(state: Dictionary, chamber_idx: int) -> Array:
	var chamber: Dictionary = _chamber(state, chamber_idx)
	var set_value: Variant = chamber.get("set", [])
	if set_value is Array:
		var s: Array = set_value
		return s
	return []


## Place a set network into a chamber. Exactly one mon in the
## set must be Shadow (the mon being purified); the rest are
## normal network mons. Refusals are explicit.
static func place_set(state: Dictionary, chamber_idx: int, set_mons: Array) -> Dictionary:
	if chamber_idx < 0 or chamber_idx >= CHAMBER_COUNT:
		return {"ok": false, "reason": "bad_chamber"}
	if set_mons.is_empty():
		return {"ok": false, "reason": "empty_set"}
	if set_mons.size() > SET_MAX:
		return {"ok": false, "reason": "set_too_large", "set_max": SET_MAX}
	var shadow_count: int = 0
	for mon_value in set_mons:
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			if PUWShadowSystem.is_shadow(mon):
				shadow_count += 1
	if shadow_count == 0:
		return {"ok": false, "reason": "no_shadow_mon"}
	if shadow_count > 1:
		return {"ok": false, "reason": "multiple_shadow_mons"}
	var chamber_state: Dictionary = ensure_chamber_state(state)
	var chambers_value: Variant = chamber_state.get("chambers", [])
	if chambers_value is Array:
		var chambers: Array = chambers_value
		var chamber_value: Variant = chambers[chamber_idx]
		if chamber_value is Dictionary:
			var chamber: Dictionary = chamber_value
			chamber["set"] = set_mons.duplicate()
			chambers[chamber_idx] = chamber
			chamber_state["chambers"] = chambers
			state[STATE_KEY] = chamber_state
	return {"ok": true, "reason": "", "tempo": tempo_of(state, chamber_idx)}


static func clear_set(state: Dictionary, chamber_idx: int) -> void:
	place_set_clear(state, chamber_idx)


static func place_set_clear(state: Dictionary, chamber_idx: int) -> void:
	var chamber_state: Dictionary = ensure_chamber_state(state)
	var chambers_value: Variant = chamber_state.get("chambers", [])
	if chambers_value is Array:
		var chambers: Array = chambers_value
		if chamber_idx >= 0 and chamber_idx < chambers.size():
			var chamber_value: Variant = chambers[chamber_idx]
			if chamber_value is Dictionary:
				var chamber: Dictionary = chamber_value
				chamber["set"] = []
				chambers[chamber_idx] = chamber
				chamber_state["chambers"] = chambers
				state[STATE_KEY] = chamber_state


static func shadow_mon_of(state: Dictionary, chamber_idx: int) -> Dictionary:
	for mon_value in set_of(state, chamber_idx):
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			if PUWShadowSystem.is_shadow(mon):
				return mon
	return {}


static func _types_of(mon: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var types_value: Variant = mon.get("types", [])
	if types_value is Array:
		var types: Array = types_value
		for t in types:
			out.append(str(t))
	return out


static func _pair_flows(a: Dictionary, b: Dictionary) -> bool:
	var a_types: PackedStringArray = _types_of(a)
	var b_types: PackedStringArray = _types_of(b)
	for t in a_types:
		if PUWBattleEngine.type_multiplier(str(t), b_types) > 1.0:
			return true
	for t in b_types:
		if PUWBattleEngine.type_multiplier(str(t), a_types) > 1.0:
			return true
	return false


## Tempo of one chamber's set: TEMPO_MAX scaled by the fraction
## of adjacent pairs (wrapping) that flow. A set of fewer than
## two mons has no pairs and tempo 0.
static func tempo_of(state: Dictionary, chamber_idx: int) -> int:
	var set_mons: Array = set_of(state, chamber_idx)
	if set_mons.size() < 2:
		return 0
	var flowing: int = 0
	for i in set_mons.size():
		var a_value: Variant = set_mons[i]
		var b_value: Variant = set_mons[(i + 1) % set_mons.size()]
		if a_value is Dictionary and b_value is Dictionary:
			var a: Dictionary = a_value
			var b: Dictionary = b_value
			if _pair_flows(a, b):
				flowing += 1
	var fraction: float = float(flowing) / float(set_mons.size())
	return clampi(int(round(fraction * float(TEMPO_MAX))), 0, TEMPO_MAX)


static func all_chambers_max_tempo(state: Dictionary) -> bool:
	for i in CHAMBER_COUNT:
		if set_of(state, i).is_empty():
			return false
		if tempo_of(state, i) != TEMPO_MAX:
			return false
	return true


## Run the chamber network for ticks rounds. Each chamber's
## Shadow mon opens its heart by tempo x TICK_POINTS_PER_TEMPO
## per tick, through PUWShadowSystem's own gauge path. A mon
## whose gauge empties purifies in the chamber -- EXCEPT
## XD001, which is never auto-purified (try_purify_xd001 is
## its only path). Returns one event per purification.
static func chamber_tick(state: Dictionary, ticks: int = 1) -> Array:
	var events: Array = []
	if ticks <= 0:
		return events
	for round_idx in ticks:
		for i in CHAMBER_COUNT:
			var mon: Dictionary = shadow_mon_of(state, i)
			if mon.is_empty():
				continue
			var tempo: int = tempo_of(state, i)
			if tempo <= 0:
				continue
			PUWShadowSystem.apply_gauge_points(mon, tempo * TICK_POINTS_PER_TEMPO)
			if PUWShadowSystem.heart_gauge_of(mon) == 0 and not PUWShadowSystem.is_xd001(mon):
				var done: Dictionary = PUWShadowSystem.purify_in_chamber(mon)
				if bool(done.get("ok", false)):
					events.append({"chamber": i, "shadow_origin": PUWShadowSystem.shadow_origin_of(mon), "via": "chamber"})
	return events


## XD001's sole purification path: all nine chambers at maximum
## tempo, XD001's gauge empty (emptied in its own chamber by
## chamber_tick), and the mon actually XD001.
static func try_purify_xd001(state: Dictionary, mon: Dictionary) -> Dictionary:
	if not PUWShadowSystem.is_shadow(mon):
		return {"ok": false, "reason": "not_shadow"}
	if not PUWShadowSystem.is_xd001(mon):
		return {"ok": false, "reason": "not_xd001"}
	if not all_chambers_max_tempo(state):
		return {"ok": false, "reason": "chambers_not_max_tempo"}
	if PUWShadowSystem.heart_gauge_of(mon) > 0:
		return {"ok": false, "reason": "gauge_not_empty", "heart_gauge": PUWShadowSystem.heart_gauge_of(mon)}
	return PUWShadowSystem.purify_in_chamber(mon)
