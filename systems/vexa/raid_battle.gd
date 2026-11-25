class_name PUWRaidBattle
extends RefCounted
## PUWRaidBattle — one Max Raid-style battle for VEXA (gap G4).
##
## Design reference: hidden_files/gen78_modes_transport/
## GEN78_MODES_TRANSPORT.md, "Max Raid Battles" (Bulbapedia /
## Serebii / GameSpot via the register). The register is the ONLY
## source of mechanics here. Facts taken from it, verbatim in
## substance:
## - 4 Trainers vs 1 wild Dynamax/Gigantamax boss that stays
##   Dynamaxed for the whole battle.
## - Each Trainer brings exactly one Pokemon; no switching.
## - Loss conditions (both hard): the team's Pokemon faint 4 times
##   total, OR 10 turns pass.
## - A fainted Pokemon cheers for one turn, then revives at full
##   HP the following turn. Cheer outcomes per Serebii's table as
##   quoted in the register: with the boss's shield up, ~13.3%
##   each for full heal / status cure / +2-stage stat boost /
##   Reflect / Light Screen, 13.3% shield-break, ~20% nothing;
##   with the shield down, ~16% each for the five effects and
##   ~20% nothing (a shield-break roll with no shield up is
##   nothing — this engine's reading of the table, which sums to
##   ~100% both ways).
## - Only one Trainer may Dynamax. The opportunity starts with
##   the host (raider slot 0), passes each turn if unused, and
##   cycles every 4 turns. A used Dynamax lasts the normal 3
##   turns (PUWGimmicks also enforces 3).
## - The boss acts multiple times per turn, periodically
##   nullifies the players' stat changes and abilities, and at
##   HP thresholds raises a mysterious barrier (shield) of 2-8
##   bars by strength. The shield heavily reduces damage and
##   blocks status / secondary effects. Every damaging hit
##   removes 1 bar; a Max Move removes 2. Breaking the shield
##   costs the boss HP and drops its defenses.
## - On victory every Trainer gets one catch attempt plus a
##   reward bundle (the simulator reports these; a simulation
##   never grants real catches or items).
##
## Anything the register does NOT number is a DESIGN CONSTANT,
## labeled inline where it is defined: the star-to-bars mapping
## (inside the sourced 2-8 range), the shield HP thresholds, the
## shield damage multiplier, the shield-break HP cost and
## defense drop, the boss's actions per turn (2), the
## nullification period (every 3rd turn), cheer screen duration
## (5 turns), and the boss's extra action acting after all first
## actions. Damage itself is never invented: every hit is priced
## by PUWBattleEngine.calculate_damage, Dynamax HP doubling and
## Max Move conversion go through PUWGimmicks, and moves come
## from MoveDatabase.
##
## Simplifications, stated plainly: accuracy is not rolled (the
## VEXA singles driver makes the same simplification — the
## controller layer owns accuracy in the main engine); while the
## shield is down, a non-damaging move against the boss has no
## engine effect here (secondary effects live in MoveEffects /
## the controller layer); ability nullification resets stat
## stages mechanically and records an ability_nullified flag on
## each raider for the following turn — ability *effects* are
## AbilityEngine's layer, not this engine's.
##
## Safety: setup_raid() deep-copies the boss and every raider mon
## unless the caller passes copy_mons=false (PUWRaidRun does, with
## mons it built itself, so HP can carry over between battles).
## The engine never touches a save, never calls
## PartyAndStorageManager.handle_faint, and a raid faint is a
## sim faint: it spends the shared faint budget and nothing else.

const MAX_TURNS: int = 10 ## SOURCED: 10 turns pass = loss.
const MAX_FAINTS: int = 4 ## SOURCED: 4 total team faints = loss.
const RAIDER_COUNT: int = 4 ## SOURCED: 4 Trainers vs 1 boss.

## DESIGN CONSTANT (mapping only; the 2-8 range is sourced):
## shield bars by star rating 1-5.
const SHIELD_BARS_BY_STAR: Dictionary = {1: 2, 2: 3, 3: 4, 4: 6, 5: 8}
## DESIGN CONSTANT: boss HP fractions at which the shield raises
## (the register says "at HP thresholds" without values). Each
## threshold raises the shield once; crossing a second threshold
## while a shield stands refreshes it to full bars.
const SHIELD_HP_THRESHOLDS: Array = [0.5, 0.25]
## DESIGN CONSTANT: damage multiplier while the shield stands
## (the register says "heavily reduces damage", no number).
const SHIELD_DAMAGE_MULT: float = 0.5
## DESIGN CONSTANT: breaking the shield costs the boss this
## fraction of its max HP (the register says it "costs the boss
## HP", no number).
const SHIELD_BREAK_HP_FRACTION: float = 0.05
## DESIGN CONSTANT: on a break the boss's Def and Sp. Def stages
## drop by this much (the register says "drops its defenses",
## no number).
const SHIELD_BREAK_DEF_DROP: int = 1
## DESIGN CONSTANT: boss actions per turn (the register says the
## boss "acts multiple times per turn", no count).
const BOSS_ACTIONS_PER_TURN: int = 2
## DESIGN CONSTANT: the boss nullifies the players' stat changes
## and abilities at the end of every Nth turn (the register says
## "periodically", no period).
const NULLIFY_EVERY_TURNS: int = 3
## DESIGN CONSTANT: turns a cheer-set Reflect / Light Screen
## lasts (the main-series screen length; the register's cheer
## table does not give a duration).
const SCREEN_TURNS: int = 5
## SOURCED (approximate, Serebii via the register): cheer chance
## per effect when the boss's shield is up / down.
const CHEER_CHANCE_SHIELDED: float = 0.133
const CHEER_CHANCE_UNSHIELDED: float = 0.16
const CHEER_SHIELD_BREAK_CHANCE: float = 0.133
const CHEER_EFFECTS: Array = ["full_heal", "status_cure", "stat_boost", "reflect", "light_screen"]
## SOURCED: reward bundle categories on victory (register text:
## "TRs, Exp. Candies, treasures, Dynamax Candy"). Reported as
## labels only — a simulation grants nothing real.
const REWARD_BUNDLE: Array = ["TR", "Exp. Candy", "treasure", "Dynamax Candy"]

var boss: Dictionary = {}
var raiders: Array = [] ## [{trainer, is_player, mon, state, faint_round}]
var star: int = 3
var turn: int = 0
var faints_used: int = 0
var shield_bars: int = 0
var shield_breaks: int = 0
var status: String = "ongoing" ## "player_won" | "enemy_won" | "ongoing"
var lose_reason: String = "" ## "faint_limit" | "turn_limit"
var logs: Array = []

var _rng: RandomNumberGenerator = null
var _move_db: MoveDatabase = null
var _thresholds_raised: Array = []
var _dynamax_holder: int = 0
var _dynamax_spent: bool = false
var _gimmick_state: Dictionary = {}


func _move_data(move_name: String) -> Dictionary:
	if _move_db == null:
		_move_db = MoveDatabase.new()
		_move_db.load_database()
	return _move_db.get_move(move_name)


## Set up one raid battle. raider_entries: exactly RAIDER_COUNT
## dicts {"trainer": String, "is_player": bool, "mon": Dictionary}.
## The boss is Dynamaxed here (through PUWGimmicks, so its HP
## doubles exactly as the project's gimmick engine does it) and
## stays Dynamaxed: this engine never ticks the boss's
## dynamax_turns and never calls end_dynamax on it.
func setup_raid(boss_mon: Dictionary, raider_entries: Array, star_rating: int, rng: RandomNumberGenerator, copy_mons: bool = true) -> Dictionary:
	_rng = rng
	star = clampi(star_rating, 1, 5)
	turn = 0
	faints_used = 0
	shield_bars = 0
	shield_breaks = 0
	status = "ongoing"
	lose_reason = ""
	logs = []
	_thresholds_raised = []
	for _i in range(SHIELD_HP_THRESHOLDS.size()):
		_thresholds_raised.append(false)
	_dynamax_holder = 0
	_dynamax_spent = false
	_gimmick_state = {}
	if copy_mons:
		boss = boss_mon.duplicate(true)
	else:
		boss = boss_mon
	raiders = []
	for entry_v in raider_entries:
		var entry: Dictionary = entry_v
		var mon: Dictionary = entry.get("mon", {})
		if copy_mons:
			mon = mon.duplicate(true)
		raiders.append({
			"trainer": str(entry.get("trainer", "Trainer")),
			"is_player": bool(entry.get("is_player", false)),
			"mon": mon,
			"state": "active",
			"faint_round": -1,
			"ability_nullified": false,
		})
	var gimmick_logs: Array = []
	# The boss gets its OWN gimmick budget dict: PUWGimmicks
	# records dynamax_used on the dict it is handed, and the
	# boss's permanent Dynamax must not spend the raiders' one
	# Dynamax (theirs is gated by _dynamax_spent + _gimmick_state).
	var boss_gimmick_state: Dictionary = {}
	PUWGimmicks.dynamax(boss, gimmick_logs, boss_gimmick_state)
	boss["raid_boss"] = true
	logs.append("%s appeared, Dynamaxed! (star %d)" % [str(boss.get("species", "The boss")), star])
	return {"status": "started", "star": star, "boss_species": str(boss.get("species", "")), "boss_max_hp": int(boss.get("max_hp", 0))}


func is_over() -> bool:
	return status != "ongoing"


func dynamax_holder() -> int:
	return _dynamax_holder


func dynamax_spent() -> bool:
	return _dynamax_spent


## The move this engine's driver picks for a mon against a foe:
## the first damaging move that is not immune on the real type
## chart (the same rule the VEXA simulator's _pick_move uses, so
## a driver never stalls forever on an immunity).
func pick_move(mon: Dictionary, foe: Dictionary) -> String:
	var moves: Array = mon.get("moves", [])
	if moves.is_empty():
		return ""
	var foe_types := PackedStringArray()
	for t in foe.get("types", []):
		foe_types.append(str(t))
	for m in moves:
		var md: Dictionary = _move_data(str(m))
		if int(md.get("power", 0)) <= 0:
			continue
		if PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), foe_types) > 0.0:
			return str(m)
	return str(moves[0])


## The boss's move against one target: its strongest damaging
## move (after Max Move conversion, since the boss is Dynamaxed)
## that is not immune against the target; falls back to its first
## damaging move, then its first move.
func pick_boss_move(target: Dictionary) -> String:
	var moves: Array = boss.get("moves", [])
	var target_types := PackedStringArray()
	for t in target.get("types", []):
		target_types.append(str(t))
	var best_name: String = ""
	var best_power: int = -1
	var first_damaging: String = ""
	for m in moves:
		var md: Dictionary = _move_data(str(m))
		var power: int = int(md.get("power", 0))
		if power <= 0:
			continue
		if first_damaging == "":
			first_damaging = str(m)
		var maxed: Dictionary = PUWGimmicks.get_max_move(str(m), power, str(md.get("type", "Normal")), str(md.get("cat", md.get("category", "Physical"))))
		var max_power: int = int(maxed.get("power", power))
		if PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), target_types) <= 0.0:
			continue
		if max_power > best_power:
			best_power = max_power
			best_name = str(m)
	if best_name != "":
		return best_name
	if first_damaging != "":
		return first_damaging
	if moves.is_empty():
		return ""
	return str(moves[0])


## A default action for one raider (used by drivers and tests):
## move with the engine-picked move; the Dynamax policy is the
## caller's (the simulator's driver Dynamaxes on the holder's
## first opportunity).
func choose_action(raider_idx: int) -> Dictionary:
	if raider_idx < 0 or raider_idx >= raiders.size():
		return {"type": "none"}
	var entry: Dictionary = raiders[raider_idx]
	if str(entry.get("state", "")) != "active":
		return {"type": "none"}
	var mon: Dictionary = entry.get("mon", {})
	var picked: String = pick_move(mon, boss)
	if picked == "":
		return {"type": "none"}
	return {"type": "move", "move_name": picked, "dynamax": false}


## Resolve one damaging (or status) hit from a raider on the
## boss, with the full shield rules. Public so tests and the
## presentation layer can price a single hit. Returns
## {damage, is_max_move, blocked, status_move, bars_removed,
## shield_broke, shield_bars, boss_hp, boss_fainted}.
func apply_hit_to_boss(raider_idx: int, move_name: String) -> Dictionary:
	var out: Dictionary = {"damage": 0, "is_max_move": false, "blocked": false, "status_move": false, "bars_removed": 0, "shield_broke": false, "shield_bars": shield_bars, "boss_hp": int(boss.get("hp", 0)), "boss_fainted": false}
	if is_over() or raider_idx < 0 or raider_idx >= raiders.size():
		return out
	var entry: Dictionary = raiders[raider_idx]
	if str(entry.get("state", "")) != "active":
		return out
	var mon: Dictionary = entry.get("mon", {})
	var md: Dictionary = _move_data(move_name)
	var power: int = int(md.get("power", 0))
	var move_dict: Dictionary = md
	var is_max: bool = false
	if bool(mon.get("dynamax_active", false)) and power > 0:
		# A Dynamaxed Pokemon's damaging moves are Max Moves
		# (sourced format rule); conversion and power come from
		# PUWGimmicks, the project's own gimmick engine.
		move_dict = PUWGimmicks.get_max_move(move_name, power, str(md.get("type", "Normal")), str(md.get("cat", md.get("category", "Physical"))))
		is_max = true
	out["is_max_move"] = is_max
	if power <= 0:
		out["status_move"] = true
		if shield_bars > 0:
			# SOURCED: the shield blocks status / secondary effects.
			out["blocked"] = true
			logs.append("The mysterious barrier blocked %s's %s!" % [str(mon.get("species", "?")), move_name])
		else:
			logs.append("%s used %s. (Non-damaging moves have no engine effect in a raid battle.)" % [str(mon.get("species", "?")), move_name])
		return out
	var result: Dictionary = PUWBattleEngine.calculate_damage(mon, boss, move_dict, _rng)
	var dmg: int = int(result.get("damage", 0))
	if shield_bars > 0:
		dmg = int(floor(float(dmg) * SHIELD_DAMAGE_MULT))
		# SOURCED: every damaging hit removes 1 bar; a Max Move
		# removes 2. Bars count hits, not damage.
		var bars: int = 2 if is_max else 1
		bars = mini(bars, shield_bars)
		shield_bars -= bars
		out["bars_removed"] = bars
		if shield_bars <= 0:
			shield_bars = 0
			out["shield_broke"] = true
			_break_shield()
	out["damage"] = dmg
	boss["hp"] = maxi(0, int(boss.get("hp", 0)) - dmg)
	logs.append("%s's %s hit the boss for %d." % [str(mon.get("species", "?")), move_name, dmg])
	_check_shield_raise()
	if int(boss.get("hp", 0)) <= 0:
		out["boss_fainted"] = true
		_win()
	out["shield_bars"] = shield_bars
	out["boss_hp"] = int(boss.get("hp", 0))
	return out


## Resolve one hit from the boss on one raider. The boss is
## Dynamaxed, so its damaging moves resolve as Max Moves through
## PUWGimmicks.get_max_move. Screens a cheer set on the target
## are honored by PUWBattleEngine.calculate_damage itself (it
## reads the defender's "screens" key). Returns {damage, target,
## fainted}.
func apply_hit_to_raider(move_name: String, raider_idx: int) -> Dictionary:
	var out: Dictionary = {"damage": 0, "target": raider_idx, "fainted": false}
	if is_over() or raider_idx < 0 or raider_idx >= raiders.size():
		return out
	var entry: Dictionary = raiders[raider_idx]
	if str(entry.get("state", "")) != "active":
		return out
	var mon: Dictionary = entry.get("mon", {})
	var md: Dictionary = _move_data(move_name)
	var power: int = int(md.get("power", 0))
	if power <= 0:
		logs.append("The boss used %s. (Non-damaging moves have no engine effect in a raid battle.)" % move_name)
		return out
	var move_dict: Dictionary = PUWGimmicks.get_max_move(move_name, power, str(md.get("type", "Normal")), str(md.get("cat", md.get("category", "Physical"))))
	var result: Dictionary = PUWBattleEngine.calculate_damage(boss, mon, move_dict, _rng)
	var dmg: int = int(result.get("damage", 0))
	mon["hp"] = maxi(0, int(mon.get("hp", 0)) - dmg)
	out["damage"] = dmg
	logs.append("The boss's %s hit %s for %d." % [move_name, str(mon.get("species", "?")), dmg])
	if int(mon.get("hp", 0)) <= 0:
		out["fainted"] = true
		_handle_raider_faint(raider_idx)
	return out


## SOURCED shield break: breaking the shield costs the boss HP
## and drops its defenses (both amounts are DESIGN CONSTANTS,
## see the header constants).
func _break_shield() -> void:
	shield_breaks += 1
	var cost: int = int(floor(float(int(boss.get("max_hp", 0))) * SHIELD_BREAK_HP_FRACTION))
	boss["hp"] = maxi(0, int(boss.get("hp", 0)) - cost)
	var stages: Dictionary = boss.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages["def"] = clampi(int(stages.get("def", 0)) - SHIELD_BREAK_DEF_DROP, -6, 6)
	stages["spd"] = clampi(int(stages.get("spd", 0)) - SHIELD_BREAK_DEF_DROP, -6, 6)
	boss["stages"] = stages
	logs.append("The mysterious barrier broke! The boss lost %d HP and its defenses dropped." % cost)
	if int(boss.get("hp", 0)) <= 0:
		_win()


## SOURCED: at HP thresholds the boss raises its shield (bars by
## star, 2-8). Crossing a further threshold while a shield
## stands refreshes it to full bars (DESIGN CONSTANT reading).
func _check_shield_raise() -> void:
	if is_over():
		return
	var max_hp: int = maxi(1, int(boss.get("max_hp", 1)))
	var frac: float = float(int(boss.get("hp", 0))) / float(max_hp)
	for i in range(SHIELD_HP_THRESHOLDS.size()):
		if bool(_thresholds_raised[i]):
			continue
		if frac <= float(SHIELD_HP_THRESHOLDS[i]):
			_thresholds_raised[i] = true
			shield_bars = int(SHIELD_BARS_BY_STAR.get(star, 4))
			logs.append("A mysterious barrier went up around the boss! (%d bars)" % shield_bars)


func _handle_raider_faint(raider_idx: int) -> void:
	var entry: Dictionary = raiders[raider_idx]
	var mon: Dictionary = entry.get("mon", {})
	# A fainted Dynamaxed Pokemon returns to normal size (the
	# project's gimmick engine restores its HP bookkeeping).
	if bool(mon.get("dynamax_active", false)):
		var glogs: Array = []
		PUWGimmicks.end_dynamax(mon, glogs)
		mon["hp"] = 0
	entry["state"] = "fainted"
	entry["faint_round"] = turn
	faints_used += 1
	logs.append("%s fainted! (team faints: %d/%d)" % [str(mon.get("species", "?")), faints_used, MAX_FAINTS])
	if faints_used >= MAX_FAINTS:
		status = "enemy_won"
		lose_reason = "faint_limit"
		logs.append("The team was overwhelmed: %d faints." % MAX_FAINTS)


func _win() -> void:
	if status == "ongoing":
		status = "player_won"
		boss["hp"] = 0
		logs.append("The raid boss was defeated!")


## Roll and apply one cheer for a fainted raider (SOURCED table,
## see the header). Returns the effect id ("full_heal",
## "status_cure", "stat_boost", "reflect", "light_screen",
## "shield_break", "nothing").
func perform_cheer(raider_idx: int) -> String:
	var shielded: bool = shield_bars > 0
	var each: float = CHEER_CHANCE_SHIELDED if shielded else CHEER_CHANCE_UNSHIELDED
	var roll: float = _rng.randf()
	var effect: String = "nothing"
	for i in range(CHEER_EFFECTS.size()):
		if roll < each * float(i + 1):
			effect = str(CHEER_EFFECTS[i])
			break
	if effect == "nothing" and shielded and roll < each * float(CHEER_EFFECTS.size()) + CHEER_SHIELD_BREAK_CHANCE:
		effect = "shield_break"
	var entry: Dictionary = raiders[raider_idx]
	var mon: Dictionary = entry.get("mon", {})
	logs.append("%s cheered the team on: %s." % [str(mon.get("species", "?")), effect])
	match effect:
		"full_heal":
			for e_v in raiders:
				var e: Dictionary = e_v
				if str(e.get("state", "")) == "active":
					var m: Dictionary = e.get("mon", {})
					m["hp"] = int(m.get("max_hp", 0))
		"status_cure":
			for e_v in raiders:
				var e2: Dictionary = e_v
				if str(e2.get("state", "")) == "active":
					var m2: Dictionary = e2.get("mon", {})
					m2["status"] = ""
		"stat_boost":
			var stats: Array = ["atk", "def", "spa", "spd", "spe"]
			var which: String = str(stats[_rng.randi_range(0, stats.size() - 1)])
			for e_v in raiders:
				var e3: Dictionary = e_v
				if str(e3.get("state", "")) == "active":
					var m3: Dictionary = e3.get("mon", {})
					var st: Dictionary = m3.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
					st[which] = clampi(int(st.get(which, 0)) + 2, -6, 6)
					m3["stages"] = st
			logs.append("The cheer raised the team's %s by 2 stages." % which)
		"reflect":
			_set_screen("reflect")
		"light_screen":
			_set_screen("light_screen")
		"shield_break":
			if shield_bars > 0:
				shield_bars -= 1
				logs.append("The cheer chipped the barrier! (%d bars left)" % shield_bars)
				if shield_bars <= 0:
					shield_bars = 0
					_break_shield()
	return effect


func _set_screen(key: String) -> void:
	for e_v in raiders:
		var e: Dictionary = e_v
		if str(e.get("state", "")) == "active":
			var m: Dictionary = e.get("mon", {})
			var screens: Dictionary = m.get("screens", {})
			screens[key] = SCREEN_TURNS
			m["screens"] = screens
	logs.append("The cheer put up %s for the team." % key)


## Showdown stat-stage multiplier (the same table
## PUWBattleEngine._stage_mult uses for damage): +n stages give
## (2+n)/2, -n stages give 2/(2+n). Used here for Speed order.
func _stage_mult(stage: int) -> float:
	if stage >= 0:
		return (2.0 + float(stage)) / 2.0
	return 2.0 / (2.0 + float(-stage))


func _effective_spe(mon: Dictionary) -> float:
	var stages: Dictionary = mon.get("stages", {})
	return float(int(mon.get("spe", 50))) * _stage_mult(int(stages.get("spe", 0)))


## Run one full round. actions: one dict per raider, aligned to
## raiders: {"type": "move", "move_name": String,
## "dynamax": bool} or {"type": "none"}. A fainted raider's
## action is ignored — it cheers instead (sourced), then revives
## at full HP at the start of the round after its cheer.
## Returns a round report; the battle-level result is in
## battle_result() once is_over().
func run_round(actions: Array) -> Dictionary:
	var report: Dictionary = {"turn": turn, "status": status, "events": []}
	if is_over():
		return report
	turn += 1
	report["turn"] = turn
	var events: Array = report["events"]

	# Revive phase: a raider that cheered last round comes back
	# at full HP (sourced).
	for e_v in raiders:
		var e: Dictionary = e_v
		if str(e.get("state", "")) == "revive_pending":
			var m: Dictionary = e.get("mon", {})
			m["hp"] = int(m.get("max_hp", 0))
			m["status"] = ""
			e["state"] = "active"
			events.append("revived:" + str(m.get("species", "?")))
			logs.append("%s recovered and is ready to fight again!" % str(m.get("species", "?")))

	# Dynamax: only the current holder may Dynamax, and only one
	# Trainer per battle (sourced). The opportunity passes at
	# the end of the round if unused.
	var holder_used: bool = false
	if not _dynamax_spent and _dynamax_holder >= 0 and _dynamax_holder < actions.size():
		var h_entry: Dictionary = raiders[_dynamax_holder]
		var h_action: Dictionary = actions[_dynamax_holder]
		if str(h_entry.get("state", "")) == "active" and bool(h_action.get("dynamax", false)):
			var h_mon: Dictionary = h_entry.get("mon", {})
			var glogs: Array = []
			PUWGimmicks.dynamax(h_mon, glogs, _gimmick_state)
			if bool(h_mon.get("dynamax_active", false)):
				_dynamax_spent = true
				holder_used = true
				events.append("dynamax:" + str(h_mon.get("species", "?")))
				logs.append("%s Dynamaxed!" % str(h_mon.get("species", "?")))

	# Action queue: every active raider's move plus the boss's
	# first action, in Speed order; the boss's extra actions
	# follow after all first actions (DESIGN CONSTANT placement).
	var queue: Array = []
	for i in range(raiders.size()):
		var entry: Dictionary = raiders[i]
		if str(entry.get("state", "")) != "active":
			continue
		if i >= actions.size():
			continue
		var action: Dictionary = actions[i]
		if str(action.get("type", "")) != "move":
			continue
		var mon: Dictionary = entry.get("mon", {})
		queue.append({"kind": "raider", "idx": i, "move_name": str(action.get("move_name", "")), "spe": _effective_spe(mon), "tie": _rng.randf()})
	if _any_raider_active():
		queue.append({"kind": "boss", "n": 0, "spe": _effective_spe(boss), "tie": _rng.randf()})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["spe"]) != float(b["spe"]):
			return float(a["spe"]) > float(b["spe"])
		return float(a["tie"]) < float(b["tie"])
	)
	for extra in range(1, BOSS_ACTIONS_PER_TURN):
		queue.append({"kind": "boss", "n": extra, "spe": -1.0, "tie": 0.0})

	for q_v in queue:
		if is_over():
			break
		var q: Dictionary = q_v
		if str(q.get("kind", "")) == "raider":
			var idx: int = int(q.get("idx", -1))
			var entry2: Dictionary = raiders[idx]
			# A raider dropped earlier this round does not act.
			if str(entry2.get("state", "")) != "active":
				continue
			apply_hit_to_boss(idx, str(q.get("move_name", "")))
		else:
			var targets: Array = _active_raider_indices()
			if targets.is_empty():
				break
			var target_idx: int = int(targets[_rng.randi_range(0, targets.size() - 1)])
			var t_entry: Dictionary = raiders[target_idx]
			var t_mon: Dictionary = t_entry.get("mon", {})
			var boss_move: String = pick_boss_move(t_mon)
			if boss_move != "":
				apply_hit_to_raider(boss_move, target_idx)

	# Cheer phase: a raider that fainted in an earlier round
	# cheers now (sourced), then is set to revive next round.
	if not is_over():
		for i in range(raiders.size()):
			var entry3: Dictionary = raiders[i]
			if str(entry3.get("state", "")) == "fainted" and int(entry3.get("faint_round", -1)) < turn:
				perform_cheer(i)
				entry3["state"] = "revive_pending"

	# End of round bookkeeping.
	if not is_over():
		_tick_dynamax()
		_tick_screens()
		# The Dynamax opportunity passes each turn if unused and
		# cycles every 4 turns (sourced): with 4 raiders the
		# holder simply advances one slot per round.
		if not _dynamax_spent and not holder_used:
			_dynamax_holder = (_dynamax_holder + 1) % RAIDER_COUNT
		# SOURCED: the boss periodically nullifies the players'
		# stat changes and abilities (period = DESIGN CONSTANT).
		if turn % NULLIFY_EVERY_TURNS == 0:
			for e_v2 in raiders:
				var e4: Dictionary = e_v2
				var m4: Dictionary = e4.get("mon", {})
				m4["stages"] = {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
				e4["ability_nullified"] = true
			events.append("nullified")
			logs.append("The boss nullified the team's stat changes and abilities!")
		else:
			for e_v3 in raiders:
				var e5: Dictionary = e_v3
				e5["ability_nullified"] = false
		# SOURCED hard loss clock: 10 turns pass.
		if turn >= MAX_TURNS and int(boss.get("hp", 0)) > 0:
			status = "enemy_won"
			lose_reason = "turn_limit"
			logs.append("Time ran out: %d turns passed." % MAX_TURNS)
	report["status"] = status
	report["faints_used"] = faints_used
	report["shield_bars"] = shield_bars
	report["boss_hp"] = int(boss.get("hp", 0))
	return report


func _any_raider_active() -> bool:
	return not _active_raider_indices().is_empty()


func _active_raider_indices() -> Array:
	var out: Array = []
	for i in range(raiders.size()):
		var e: Dictionary = raiders[i]
		if str(e.get("state", "")) == "active":
			out.append(i)
	return out


func _tick_dynamax() -> void:
	for e_v in raiders:
		var e: Dictionary = e_v
		var m: Dictionary = e.get("mon", {})
		if bool(m.get("dynamax_active", false)):
			m["dynamax_turns"] = int(m.get("dynamax_turns", 1)) - 1
			if int(m.get("dynamax_turns", 0)) <= 0:
				var glogs: Array = []
				PUWGimmicks.end_dynamax(m, glogs)
				logs.append("%s returned to normal size." % str(m.get("species", "?")))


func _tick_screens() -> void:
	for e_v in raiders:
		var e: Dictionary = e_v
		var m: Dictionary = e.get("mon", {})
		var screens: Dictionary = m.get("screens", {})
		if screens.is_empty():
			continue
		var next: Dictionary = {}
		for key_v in screens.keys():
			var key: String = str(key_v)
			var left: int = int(screens.get(key, 0)) - 1
			if left > 0:
				next[key] = left
		m["screens"] = next


## The battle-level result once is_over() (also safe mid-battle).
## catch_attempts and rewards follow the sourced victory rule:
## every Trainer gets one catch attempt plus a reward bundle.
## In a simulation these are REPORTS only — nothing is caught
## and no item is granted.
func battle_result() -> Dictionary:
	var won: bool = status == "player_won"
	var species: Array = []
	for e_v in raiders:
		var e: Dictionary = e_v
		var m: Dictionary = e.get("mon", {})
		species.append(str(m.get("species", "")))
	return {
		"status": status,
		"turns": turn,
		"lose_reason": lose_reason,
		"star": star,
		"faints_used": faints_used,
		"shield_breaks": shield_breaks,
		"boss_species": str(boss.get("species", "")),
		"boss_hp": int(boss.get("hp", 0)),
		"boss_max_hp": int(boss.get("max_hp", 0)),
		"raider_species": species,
		"catch_attempts": RAIDER_COUNT if won else 0,
		"rewards": REWARD_BUNDLE.duplicate() if won else [],
		"logs": logs.duplicate(),
	}
