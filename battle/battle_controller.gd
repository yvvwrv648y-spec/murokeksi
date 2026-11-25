class_name BattleController
extends Node
## Master Battle Controller for Pokemon Ultimate World (Godot 4).
## Keeps the RC1 start_battle() and execute_switch() and adds a full
## turn loop (run_turn), wild capture, EXP and level-ups, and a
## doubles stub. Plain words for what one turn does, in order:
## pick the foe's action, work out who goes first, check sleep/freeze/
## paralysis, take PP, check accuracy, work out damage, apply the
## move's after-effects, check for fainting, then end-of-turn effects
## (items, abilities, status, weather) and tick the field timers.
##
## This file calls the shared-contract APIs exactly as written by the
## other builders: ItemEngine, MoveEffects, AbilityEngine,
## StatusAndFieldEngine, TurnResolver, CompetitiveTrainerAI,
## MoveDatabase, BattleStageController, PUWBattleEngine, PUWGimmicks,
## and PUWSmartAI (as the fallback foe brain). It will not load in
## Godot until ItemEngine and MoveEffects exist in the project.
## LearnsetResolver is optional: it is found through the project's
## global class list, and move learning is skipped when it is missing.

@onready var move_db := MoveDatabase.new()
@onready var stage := BattleStageController.new()
var field_state: Dictionary = StatusAndFieldEngine.create_field_state()
var is_simulation: bool = false
var active_format: String = "singles"
var rng := RandomNumberGenerator.new()
var player_party: Array = []
var enemy_party: Array = []
var battle_state: Dictionary = {"mega_used": false, "z_used": false, "dynamax_used": false, "tera_used": false, "ultra_used": false, "turn": 0, "spread_damage": false, "player_must_switch": false, "flee_attempts": 0, "gimmick_budgets": {"player": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}, "enemy": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}}}
## Presentation events for the battle scene (binding build 6,
## code_prep_battle_anim): run_turn records what happened, in
## order, and the scene plays the matching animations back.
## Resolution itself stays synchronous and untouched. Event
## shapes: {"kind": "move", "side", "move_id"},
## {"kind": "faint", "side"} (side = the side that fainted),
## {"kind": "send_out", "side"},
## {"kind": "ball_throw", "side", "ball", "caught"}.
var anim_events: Array = []
var is_wild: bool = false
## The region this battle is fought in (set by the battle
## launcher from the campaign state). Ranger Variant A: Poke
## Balls are inert in the Ranger regions -- see
## PUWRangerAvailability. "" = unset = balls work as always.
var campaign_region_id: String = ""
var challenge_mode: String = "standard"

## Gym badge count for the hard badge level caps (see
## EXPSystem.BADGE_LEVEL_CAPS). -1 means "not supplied": the
## battle engine on its own has no badge concept, so NO cap
## applies until the game/campaign layer supplies a count.
## Supply it either with set_badge_count() or by putting a
## "badges" value in field_state. Whenever a count IS supplied
## (by either route) the cap is enforced totally in _give_exp:
## the LEVEL stops at the cap, EXP points keep accruing, and
## a mon's level is never lowered. There are no disobedience
## mechanics — the cap is a hard stop, per the RC1 formats doc.
var badge_count: int = -1

## Supply the player's gym badge count for the hard level caps.
## Pass -1 to clear it (back to "not supplied", no cap).
func set_badge_count(n: int) -> void:
	badge_count = n

## The hard level cap that applies right now, or -1 when no
## badge count has been supplied by either route (member first,
## then field_state["badges"]).
func _active_level_cap() -> int:
	if badge_count >= 0:
		return EXPSystem.level_cap_for_badges(badge_count)
	if field_state.has("badges"):
		return EXPSystem.level_cap_for_badges(int(field_state.get("badges", 0)))
	return -1


## Progression gimmick gate state (mechanics-completeness
## prep F1, 2026-11-24). PUWGimmickUnlocks.attempt_gimmick is
## documented as "the mandatory battle-facing pre-check" for
## every real-battle gimmick attempt, but nothing in the live
## flow called it: _apply_gimmick enforced only the per-battle
## budget, so a Mega Stone holder mega-evolved even in Kanto.
## The battle scene arms this gate from the save state before
## start_battle (arm_gimmick_gate); _perform_action then runs
## _gimmick_gate_check before the engine's gimmick paths.
## progression_state is the save-state Dictionary
## PUWGimmickUnlocks.read_flags consumes; progression_simulation
## is true only for VEXA simulations (the sim exemption).
var progression_state: Dictionary = {}
var progression_simulation: bool = false
var gimmick_gate_armed: bool = false


## Arm the progression gimmick gate for this battle.
func arm_gimmick_gate(state: Dictionary, simulation: bool = false) -> void:
	progression_state = state
	progression_simulation = simulation
	gimmick_gate_armed = true


## Disarm the gate (back to bare-engine behavior).
func disarm_gimmick_gate() -> void:
	gimmick_gate_armed = false
	progression_state = {}
	progression_simulation = false


## Supply the badge count from a save state (mechanics prep
## F3, 2026-11-24): reads the state's "badges" (an Array of
## badge ids in PUWSaveManager states; a bare int is also
## accepted) and routes it through set_badge_count, so the
## hard level caps enforced in _give_exp actually engage in
## live play. Before this, set_badge_count had no production
## caller and no live caller set field_state["badges"], so
## the caps never applied in a real battle.
func supply_badge_count_from_state(state: Dictionary) -> void:
	var badges_value: Variant = state.get("badges", null)
	if badges_value is Array:
		var badges: Array = badges_value
		set_badge_count(badges.size())
	elif badges_value is int:
		set_badge_count(int(badges_value))


## The budget key an action attempts, or "" when the action
## attempts no budgeted gimmick. Mirrors the engine's own
## reads: action["gimmick"] for mega / dynamax / gigantamax /
## tera (the exact keys _apply_gimmick matches) and a
## non-empty action["z_crystal"] for "zmove". "primal" and
## "ultra" are item-driven forme changes, not Omni budget
## families (PUWCombatConsequences.GIMMICK_FAMILY_KEYS), and
## are not progression-gated here.
func _gimmick_budget_key_for_action(action: Dictionary) -> String:
	if str(action.get("z_crystal", "")) != "":
		return "zmove"
	var gimmick: String = str(action.get("gimmick", "")).to_lower()
	match gimmick:
		"mega", "dynamax", "gigantamax", "tera":
			return gimmick
	return ""


## The progression pre-check. When the gate is armed, every
## gimmick attempt is decided by PUWGimmickUnlocks -- the
## same is_budget_allowed decision attempt_gimmick itself
## makes, from the same progression state, for both sides
## (the unlock is a property of the save's progression, not
## of a side). attempt_gimmick is not called directly
## because it applies the gimmick to party slot 0 only,
## while the live controller acts per-slot (doubles slot 1
## included); the predicate is applied here and the engine's
## own _apply_gimmick / _apply_z_move -- which enforce the
## per-battle budget -- remain the single application path.
## A refusal appends the lock message to logs and returns
## true: the engine is never called, no budget is spent, the
## mon does not transform, and the action's move still
## executes untransformed. When the gate is not armed
## (bare-engine tests and tooling), returns false and
## behavior is exactly the pre-gate engine behavior.
func _gimmick_gate_check(action: Dictionary, is_player: bool, logs: Array) -> bool:
	if not gimmick_gate_armed:
		return false
	var budget_key: String = _gimmick_budget_key_for_action(action)
	if budget_key == "":
		return false
	if PUWGimmickUnlocks.is_budget_allowed(budget_key, progression_state, progression_simulation):
		return false
	var family: String = PUWGimmickUnlocks.family_for_budget(budget_key)
	var family_name: String = str(PUWGimmickUnlocks.FAMILY_NAMES.get(family, family))
	logs.append("Gimmick locked: " + family_name + " is locked until its progression unlock is reached.")
	return true

## Move-Forget screen (v4 MoveForgetScreen, copied into this pack).
## Move-Forget screen (v4 MoveForgetScreen, copied into this pack).
## move_forget_screen is the screen currently open, or null.
## move_forget_logs holds the log lines from a choice the player
## made through the screen, since the screen's signal fires after
## the turn's own logs array is gone. The game or the battle scene
## can read it and show the lines.
var move_forget_screen: Node = null
var move_forget_logs: Array = []

## Dance moves (moves.json, flags.dance = 1; 12 moves, checked
## 2026-11-22): Aqua Step, Clangorous Soul, Dragon Dance, Feather
## Dance, Fiery Dance, Lunar Dance, Petal Dance, Quiver Dance,
## Revelation Dance, Swords Dance, Teeter Dance, Victory Dance.
## Rain Dance is NOT a dance move for Dancer (no dance flag).
const DANCE_MOVE_IDS: Array = ["aquastep", "clangoroussoul", "dragondance", "featherdance", "fierydance", "lunardance", "petaldance", "quiverdance", "revelationdance", "swordsdance", "teeterdance", "victorydance"]

func _ready() -> void:
	if move_db == null:
		move_db = MoveDatabase.new()
	if not move_db.is_inside_tree():
		add_child(move_db)
	move_db.load_database()
	if stage == null:
		stage = BattleStageController.new()
	if not stage.is_inside_tree():
		add_child(stage)
	rng.randomize()

func start_battle(player_party: Array, enemy_party: Array, format_id: String = "singles", simulation: bool = false) -> Dictionary:
	is_simulation = simulation
	active_format = format_id
	field_state = StatusAndFieldEngine.create_field_state()
	self.player_party = player_party
	self.enemy_party = enemy_party
	battle_state = {"mega_used": false, "z_used": false, "dynamax_used": false, "tera_used": false, "ultra_used": false, "turn": 0, "spread_damage": false, "player_must_switch": false, "flee_attempts": 0, "wild_fled": false, "gimmick_budgets": {"player": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}, "enemy": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}}}
	anim_events.clear()
	# Inverse Battle (Gen VI format): the type chart is flipped
	# for the whole battle. The flag rides on the field state,
	# which run_turn / run_turn_doubles stamp onto every mon as
	# mon["field"], and the damage calculator reads it there.
	if format_id == "inverse_battle" or format_id == "inverse":
		field_state["inverse_battle"] = true
	is_wild = false
	if enemy_party.size() > 0:
		is_wild = bool(enemy_party[0].get("wild", false))
	# A new battle starts with no volatiles: clear any stall
	# chain a mon dict carried over from an earlier battle.
	for party in [player_party, enemy_party]:
		for slot in range(party.size()):
			var mon: Dictionary = party[slot]
			mon["stall_counter"] = 0
			mon["stall_used_this_turn"] = false
			mon["airborne_move"] = ""
			mon["gimmick_category_used"] = ""
			mon["held_in_sky"] = false
			mon["skydrop_target"] = {}
	rng.randomize()
	var logs: Array = []
	# Doubles ally keys (mon["ally"] / mon["ally_ability"]) must be
	# set before any switch-in ability runs, so a lead pair's
	# Costar, Curious Medicine or Commander sees the ally. In
	# singles the helper is not called and the keys stay unset.
	if format_id == "doubles":
		_refresh_doubles_allies()
	if player_party.size() > 0 and enemy_party.size() > 0:
		player_party[0]["participated"] = true
		enemy_party[0]["participated"] = true
		player_party[0]["active_turns"] = 0
		enemy_party[0]["active_turns"] = 0

		_refresh_fallen_allies()
		player_party[0]["switched_in_this_turn"] = true
		enemy_party[0]["switched_in_this_turn"] = true
		logs.append_array(AbilityEngine.on_switch_in(player_party[0], enemy_party[0], field_state))
		_maybe_clear_screens(player_party[0], logs)
		_apply_form_change(player_party[0], logs)
		_apply_terrain_on_switch_in(player_party[0])
		ItemEngine.on_switch_in_items(player_party[0], field_state, logs)
		_apply_tailwind_switch_in(player_party[0], true, logs)

		logs.append_array(AbilityEngine.on_switch_in(enemy_party[0], player_party[0], field_state))
		_maybe_clear_screens(enemy_party[0], logs)
		_apply_form_change(enemy_party[0], logs)
		_apply_terrain_on_switch_in(enemy_party[0])
		ItemEngine.on_switch_in_items(enemy_party[0], field_state, logs)
		_apply_tailwind_switch_in(enemy_party[0], false, logs)


	if format_id == "doubles":
		if player_party.size() > 1 and enemy_party.size() > 0:
			player_party[1]["participated"] = true
			player_party[1]["active_turns"] = 0

			var foe1: Dictionary = enemy_party[1] if enemy_party.size() > 1 else enemy_party[0]
			player_party[1]["switched_in_this_turn"] = true
			logs.append_array(AbilityEngine.on_switch_in(player_party[1], foe1, field_state))
			_maybe_clear_screens(player_party[1], logs)
			_apply_form_change(player_party[1], logs)
			_apply_terrain_on_switch_in(player_party[1])
			ItemEngine.on_switch_in_items(player_party[1], field_state, logs)
			_apply_tailwind_switch_in(player_party[1], true, logs)


		if enemy_party.size() > 1 and player_party.size() > 0:
			enemy_party[1]["participated"] = true
			enemy_party[1]["active_turns"] = 0

			var foe2: Dictionary = player_party[1] if player_party.size() > 1 else player_party[0]
			enemy_party[1]["switched_in_this_turn"] = true
			logs.append_array(AbilityEngine.on_switch_in(enemy_party[1], foe2, field_state))
			_maybe_clear_screens(enemy_party[1], logs)
			_apply_form_change(enemy_party[1], logs)
			_apply_terrain_on_switch_in(enemy_party[1])
			ItemEngine.on_switch_in_items(enemy_party[1], field_state, logs)
			_apply_tailwind_switch_in(enemy_party[1], false, logs)


	return {"status": "started", "format": format_id, "simulation": simulation, "logs": logs}

func execute_switch(party: Array, target_idx: int, foe: Dictionary, is_player: bool) -> Array:
	var logs: Array = []
	if target_idx <= 0 or target_idx >= party.size():
		return logs
	AbilityEngine.on_switch_out(party[0], field_state)
	# V5: switching out ends Bide and clears the Counter store.
	_clear_bide(party[0], logs)
	_clear_counter_store(party[0])
	# Switching out also ends the airborne state, and frees a
	# Sky Drop target the outgoing mon was carrying.
	_clear_airborne(party[0])
	party[0]["switched_in_this_turn"] = false
	party[0]["switch_flag"] = false
	party[0]["force_switch"] = false
	var incoming = party[target_idx]

	party[target_idx] = party[0]
	party[0] = incoming
	incoming["active_turns"] = 0
	incoming["switched_in_this_turn"] = true

	var hazards: Dictionary = field_state["player_hazards"] if is_player else field_state["enemy_hazards"]
	logs.append_array(StatusAndFieldEngine.apply_entry_hazards(incoming, hazards))
	# Sync BEFORE the incoming mon's switch-in abilities run: the
	# outgoing mon may have been the Neutralizing Gas holder, and
	# its flag must be gone before the new mon's abilities are
	# checked (the engine guard reads this flag).
	_sync_field_flags()
	_refresh_fallen_allies()
	logs.append_array(AbilityEngine.on_switch_in(incoming, foe, field_state))
	_maybe_clear_screens(incoming, logs)
	_apply_form_change(incoming, logs)
	_apply_terrain_on_switch_in(incoming)
	ItemEngine.on_switch_in_items(incoming, field_state, logs)
	_apply_tailwind_switch_in(incoming, is_player, logs)
	_sync_field_flags()
	return logs




## Say this is a wild battle (catching is only allowed in wild battles).
func set_wild_battle(wild: bool) -> void:
	is_wild = wild

static func _mon_name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))

func _get_move(move_name: String) -> Dictionary:
	if move_db == null:
		move_db = MoveDatabase.new()
		move_db.load_database()
	var md: Dictionary = move_db.get_move(move_name)
	return md.duplicate(true)

static func _lower_types(types: Array) -> Array:
	var out: Array = []
	for t in types:
		out.append(str(t).to_lower())
	return out

func _all_fainted(party: Array) -> bool:
	for mon in party:
		if int(mon.get("hp", 0)) > 0:
			return false
	return true

func _battle_status() -> String:
	if not player_party.is_empty() and _all_fainted(player_party):
		return "enemy_won"
	if not enemy_party.is_empty() and _all_fainted(enemy_party):
		return "player_won"
	return "ongoing"

func _battle_over() -> bool:
	return _battle_status() != "ongoing"

## Find the LearnsetResolver through the project's global class list.
## Returns null when the class is not in the project, so this file
## still loads and runs without it (move learning is skipped then).
static func _learnset_resolver():
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == "LearnsetResolver":
			var path: String = str(entry.get("path", ""))
			if path == "":
				return null
			var script = load(path)
			if script == null:
				return null
			return script.new()
	return null

## Find the MoveForgetScreen class, or null when the file is not
## in the project. Same global-class-list lookup as _learnset_resolver.
## Falls back to the documented pack path when the class cache is
## stale (right after new files are dropped in, before re-import).
static func _move_forget_screen_class():
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == "MoveForgetScreen":
			var path: String = str(entry.get("path", ""))
			if path == "":
				return null
			return load(path)
	if FileAccess.file_exists("res://battle/move_forget_screen.gd"):
		return load("res://battle/move_forget_screen.gd")
	return null

## One full turn. player_action is one of:
## {"type": "move", "move_name": "..."} (plus optional "gimmick":
## "mega"/"dynamax"/"gigantamax"/"tera"/"primal"/"ultra", optional
## "tera_type", optional "z_crystal"),
## {"type": "switch", "target_idx": n},
## {"type": "item", "item_id": "..."} (a ball item in a wild battle
## tries a catch),
## {"type": "run"}.
## Returns {"status", "logs", "field", "player_party", "enemy_party"}.
## Status is "ongoing", "player_won", "enemy_won", "fled", "caught",
## "must_switch", or "no_battle".
func run_turn(player_action: Dictionary, field_state: Dictionary) -> Dictionary:
	self.field_state = field_state
	# Inverse Battle: the caller hands in the field state, so
	# carry the format flag set in start_battle onto it (the
	# mons are stamped with this dict below, and the damage
	# calculator reads the flag from the stamp).
	if (active_format == "inverse_battle" or active_format == "inverse") and not bool(field_state.get("inverse_battle", false)):
		field_state["inverse_battle"] = true
	# Safety net: a turn that ended early (battle won or lost)
	# never reaches _end_of_turn, so clear any leftover
	# Protect flag here too. A new turn never starts protected.
	_clear_protect_flags()
	# Pickup's record of items used this turn (batch 3 contract:
	# the caller resets it each turn). Doubles already does this.
	field_state["items_used_this_turn"] = []

	var logs: Array = []
	anim_events.clear()

	battle_state["turn"] = int(battle_state.get("turn", 0)) + 1
	# V5: a new turn starts, so no mon counts as damaged this
	# turn yet. Metal Burst and Comeuppance only answer damage
	# taken this turn. The stored hit itself (last_damage_taken)
	# is NOT reset here: Counter and Mirror Coat answer the last
	# hit of their kind until the mon switches out or uses the move.
	if not player_party.is_empty():
		player_party[0]["damaged_this_turn"] = false
	if not enemy_party.is_empty():
		enemy_party[0]["damaged_this_turn"] = false
	if player_party.is_empty() or enemy_party.is_empty():

		logs.append("No battle is running.")
		return {"status": "no_battle", "logs": logs, "field": field_state}
	if str(player_action.get("type", "")) == "run":
		if is_wild:
			if _try_flee(player_party[0], enemy_party[0], logs):
				logs.append("Got away safely!")
				return {"status": "fled", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
			logs.append("Can't escape!")
			player_action = {"type": "wait"}
		else:
			logs.append("You can't run from a trainer battle!")
	if bool(battle_state.get("player_must_switch", false)) and str(player_action.get("type", "")) != "switch":
		logs.append("Choose your next Pokemon first!")
		return {"status": "must_switch", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
	battle_state["player_must_switch"] = false
	var p_mon: Dictionary = player_party[0]
	var e_mon: Dictionary = enemy_party[0]
	# Stamp the shared field on both mons, so the engine guard can
	# read the Neutralizing Gas flag from any mon. The side stamp
	# rides along: Safeguard reads it in try_set_status to know
	# which side's Safeguard protects this mon.
	p_mon["field"] = field_state
	e_mon["field"] = field_state
	p_mon["side"] = "player"
	e_mon["side"] = "enemy"
	var e_name: String = _mon_name(e_mon)
	var enemy_action: Dictionary = _enemy_action(e_mon, p_mon, logs)
	var p_move: Dictionary = _action_move(player_action, p_mon)
	var e_move: Dictionary = _action_move(enemy_action, e_mon)

	_roll_frac_priority(p_mon, p_move, player_action)
	_roll_frac_priority(e_mon, e_move, enemy_action)
	var order: Array = TurnResolver.resolve_order(p_mon, p_move, e_mon, e_move, field_state)
	for side in order:
		if _battle_over():
			break
		if bool(battle_state.get("wild_fled", false)):
			break
		if str(side) == "player":
			var pres: Dictionary = _perform_action(player_action, true, logs)
			if pres.has("capture"):
				var cap: Dictionary = pres["capture"]
				if bool(cap.get("caught", false)):
					return {"status": "caught", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
			if bool(pres.get("fled", false)):
				# Poke Doll / Fluffy Tail (merge step 3e): the
				# item branch of _perform_action resolved a
				# guaranteed escape from a wild battle.
				return {"status": "fled", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
		else:
			# If the player's move fainted the foe and a new foe came
			# in, the new foe picks its own action.
			if _mon_name(enemy_party[0]) != e_name:
				enemy_action = _enemy_action(enemy_party[0], player_party[0], logs)
			_perform_action(enemy_action, false, logs)
	if bool(battle_state.get("wild_fled", false)):
		return {"status": "fled", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
	if not _battle_over():
		# Snapshot the living leads BEFORE the end-of-turn ticks:
		# a mon that already fainted to a move this turn must not
		# be handled again (that would grant its EXP twice). Only
		# a mon alive here and at 0 HP after the ticks fainted to
		# end-of-turn damage.
		var player_alive: bool = not player_party.is_empty() and int(player_party[0].get("hp", 0)) > 0
		var enemy_alive: bool = not enemy_party.is_empty() and int(enemy_party[0].get("hp", 0)) > 0
		_end_of_turn(logs)
		_handle_end_of_turn_faints(logs, player_alive, enemy_alive)
	var status: String = _battle_status()

	return {"status": status, "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}

## Try to run from a wild Pokemon. Real Gen 3 onward rule, see
## patch 1-B. Returns true when the player gets away.
func _try_flee(player_mon: Dictionary, wild_mon: Dictionary, logs: Array) -> bool:
	var player_ability: String = str(player_mon.get("ability", ""))
	var wild_ability: String = str(wild_mon.get("ability", ""))
	if player_ability == "Run Away":
		return true
	if str(player_mon.get("item", "")) == "Smoke Ball":
		return true
	if wild_ability == "Shadow Tag" and player_ability != "Shadow Tag":
		logs.append("The wild " + _mon_name(wild_mon) + "'s Shadow Tag stops you running away!")
		return false
	if wild_ability == "Arena Trap":
		var player_types: Array = player_mon.get("types", [])
		if not ("Flying" in player_types) and player_ability != "Levitate":
			logs.append("The wild " + _mon_name(wild_mon) + "'s Arena Trap stops you running away!")
			return false
	# Catch-all for the cases the checks above miss (Magnet Pull
	# on Steel types, and the Ghost / Levitate / Air Balloon /
	# Shed Shell escapes). The hardcoded checks stay: they are
	# tested, and they run first so their log lines win.
	if AbilityEngine.traps_foe(wild_mon, player_mon):
		logs.append("The wild " + _mon_name(wild_mon) + "'s " + wild_ability + " stops you running away!")
		return false

	var player_spe: int = int(player_mon.get("spe", 0))
	var wild_spe: int = maxi(1, int(wild_mon.get("spe", 0)))
	if player_spe >= wild_spe:
		return true
	battle_state["flee_attempts"] = int(battle_state.get("flee_attempts", 0)) + 1
	var tries: int = int(battle_state.get("flee_attempts", 1))
	var odds: int = (player_spe * 128 / wild_spe + 30 * tries) % 256
	return rng.randi_range(0, 255) < odds

## One full doubles turn (2v2). player_actions holds one action per
## player slot, in slot order: player_actions[0] is the slot 0 mon,
## player_actions[1] is the slot 1 mon. Each action is the same shape
## as in run_turn: {"type": "move", "move_name": "..."} (plus optional
## gimmick / z_crystal), {"type": "switch", "target_idx": n},
## {"type": "item", "item_id": "..."}. A missing or empty action
## means that slot does nothing this turn. Returns the same shape as
## run_turn: {"status", "logs", "field", "player_party",
## "enemy_party"}. Status is "ongoing", "player_won", "enemy_won",
## "must_switch", "fled", or "no_battle".
## Party layout in doubles: party[0] and party[1] are the two active
## mons (slot 0 and slot 1); party[2] and later are the bench.
func run_turn_doubles(player_actions: Array, field_state: Dictionary) -> Dictionary:
	self.field_state = field_state
	# Inverse Battle flag, carried onto the caller's field
	# state exactly as in run_turn.
	if (active_format == "inverse_battle" or active_format == "inverse") and not bool(field_state.get("inverse_battle", false)):
		field_state["inverse_battle"] = true
	# Safety net, as in run_turn: a turn that ended early never
	# reaches _end_of_turn_doubles, so clear any leftover
	# Protect flag here too.
	_clear_protect_flags()
	var logs: Array = []
	battle_state["turn"] = int(battle_state.get("turn", 0)) + 1

	# V5: a new turn starts, so no mon counts as damaged this
	# turn yet (see run_turn: only the flag resets, not the
	# stored hit). Both active slots on both sides reset.
	for v5_party in [player_party, enemy_party]:
		for v5_slot in range(2):
			if v5_slot < v5_party.size():
				v5_party[v5_slot]["damaged_this_turn"] = false
	# Pickup's record of items used this turn (batch 3 contract:

	# the caller resets it each turn). Singles run_turn does not
	# reset it yet; that is a gap for the coordinator, not this
	# patch.
	field_state["items_used_this_turn"] = []
	if player_party.is_empty() or enemy_party.is_empty():
		logs.append("No battle is running.")
		return {"status": "no_battle", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
	active_format = "doubles"
	# Running away: same rule as singles.
	for pa in player_actions:
		if pa is Dictionary:
			var pa_dict: Dictionary = pa
			if str(pa_dict.get("type", "")) == "run":
				if is_wild:
					logs.append("Got away safely!")
					return {"status": "fled", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
				logs.append("You can't run from a trainer battle!")
				break
	# A fainted player mon must be replaced before the turn runs.
	# A slot only waits for a replacement when a living bench mon
	# exists to send; with no bench mon left, the side fights on
	# with one mon and the empty slot just stays empty.
	if bool(battle_state.get("player_must_switch", false)):
		var need_send: Array = []
		for slot in range(mini(2, player_party.size())):
			if int(player_party[slot].get("hp", 0)) <= 0:
				need_send.append(slot)
		var bench_living: int = 0
		for i in range(2, player_party.size()):
			if int(player_party[i].get("hp", 0)) > 0:
				bench_living += 1
		var filled: int = 0
		for slot in need_send:
			if filled >= bench_living:
				break
			if slot < player_actions.size() and player_actions[slot] is Dictionary:
				var send_action: Dictionary = player_actions[slot]
				if str(send_action.get("type", "")) == "switch":
					_doubles_switch(player_party, int(send_action.get("target_idx", -1)), int(slot), enemy_party[0], true, logs)
					if int(player_party[int(slot)].get("hp", 0)) > 0:
						filled += 1
		if filled < mini(need_send.size(), bench_living):
			logs.append("Choose your next Pokemon first!")
			return {"status": "must_switch", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
		battle_state["player_must_switch"] = false
	_refresh_doubles_allies()
	# Build the 4 combatants: both living player slots, both living
	# enemy slots. The foe picks its own action per slot, against
	# the player mon in the same slot when it is alive.
	var combatants: Array = []
	for slot in range(2):
		if slot < player_party.size() and int(player_party[slot].get("hp", 0)) > 0:
			var p_action: Dictionary = {"type": "none"}
			if slot < player_actions.size() and player_actions[slot] is Dictionary:
				p_action = player_actions[slot]
			if str(p_action.get("type", "none")) == "none":
				logs.append("No action was given for your slot " + str(slot + 1) + ", so it does nothing.")
			combatants.append({"mon": player_party[slot], "move": _action_move(p_action, player_party[slot]), "side": "player", "slot": slot, "action": p_action})

	for slot in range(2):
		if slot < enemy_party.size() and int(enemy_party[slot].get("hp", 0)) > 0:
			var foe_mon: Dictionary = enemy_party[slot]
			var foe_target: Dictionary = {}
			if slot < player_party.size() and int(player_party[slot].get("hp", 0)) > 0:
				foe_target = player_party[slot]
			else:
				for pi in range(player_party.size()):
					if int(player_party[pi].get("hp", 0)) > 0:
						foe_target = player_party[pi]
						break
			var e_action: Dictionary = _enemy_action(foe_mon, foe_target, logs)
			combatants.append({"mon": foe_mon, "move": _action_move(e_action, foe_mon), "side": "enemy", "slot": slot, "action": e_action})

	for c in combatants:
		var c_mon: Dictionary = c.get("mon", {})
		var c_move: Dictionary = c.get("move", {})
		var c_action: Dictionary = c.get("action", {})
		_roll_frac_priority(c_mon, c_move, c_action)
		# Stamp the shared field on every combatant, so the engine
		# guard can read the Neutralizing Gas flag from any mon.
		# The side stamp rides along for Safeguard, the same as
		# in singles.
		c_mon["field"] = field_state
		c_mon["side"] = str(c.get("side", ""))
	var order: Array = TurnResolver.resolve_order_4(combatants, field_state)
	for c in order:
		if _battle_over():
			break
		if bool(battle_state.get("wild_fled", false)):
			break
		var c_mon: Dictionary = c.get("mon", {})
		if int(c_mon.get("hp", 0)) <= 0:
			continue
		var c_side: String = str(c.get("side", "player"))
		var c_slot: int = int(c.get("slot", 0))
		var c_action: Dictionary = c.get("action", {"type": "none"})
		_refresh_doubles_allies()
		_perform_action_doubles(c_action, c_side == "player", c_slot, logs)
	if bool(battle_state.get("wild_fled", false)):
		return {"status": "fled", "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}
	if not _battle_over():
		# Snapshot the living actives BEFORE the end-of-turn ticks,
		# one flag per slot (player 0, player 1, enemy 0, enemy 1):
		# a mon that already fainted to a move this turn must not
		# be handled again (that would grant its EXP twice).
		var p0_alive: bool = not player_party.is_empty() and int(player_party[0].get("hp", 0)) > 0
		var p1_alive: bool = player_party.size() > 1 and int(player_party[1].get("hp", 0)) > 0
		var e0_alive: bool = not enemy_party.is_empty() and int(enemy_party[0].get("hp", 0)) > 0
		var e1_alive: bool = enemy_party.size() > 1 and int(enemy_party[1].get("hp", 0)) > 0
		_end_of_turn_doubles(logs)
		_handle_end_of_turn_faints_doubles(logs, p0_alive, p1_alive, e0_alive, e1_alive)
	var status: String = _battle_status()

	return {"status": status, "logs": logs, "field": field_state, "player_party": player_party, "enemy_party": enemy_party}

## A view of the field for DoublesTargeting: the normal field state
## plus "player_active" and "enemy_active", the live mon dicts by
## slot ({} when a slot is empty). The mon dicts are the live party
## dicts, not copies, so HP read here is always current.
func _doubles_field_view() -> Dictionary:
	var view: Dictionary = field_state.duplicate(true)
	var pa: Array = []
	var ea: Array = []
	for slot in range(2):
		if slot < player_party.size():
			pa.append(player_party[slot])
		else:
			pa.append({})
		if slot < enemy_party.size():
			ea.append(enemy_party[slot])
		else:
			ea.append({})
	view["player_active"] = pa
	view["enemy_active"] = ea
	return view

## Set the doubles ally keys every active mon's ability hooks
## read: mon["ally"] is the live dict of the other active mon on
## the same side ({} when that slot is empty or fainted), and
## mon["ally_ability"] is that ally's ability string ("" when
## there is none). A fainted ally is {} on purpose: Costar copies
## a living ally's stages, Curious Medicine resets a living
## ally's stages, and Commander needs a living Dondozo. In
## singles this is never called, so the keys stay unset there.
func _refresh_doubles_allies() -> void:
	for side in ["player", "enemy"]:
		var party: Array = player_party if side == "player" else enemy_party
		for slot in range(2):
			if slot >= party.size():
				continue
			var mon: Dictionary = party[slot]
			var other_slot: int = 1 if slot == 0 else 0
			var ally: Dictionary = {}
			if other_slot < party.size() and int(party[other_slot].get("hp", 0)) > 0:
				ally = party[other_slot]
			mon["ally"] = ally
			mon["ally_ability"] = str(ally.get("ability", "")) if not ally.is_empty() else ""

## The live mon dict for a {"side", "slot"} target, or {} when the
## slot is out of range.
func _doubles_mon(t: Dictionary) -> Dictionary:
	var party: Array = player_party if str(t.get("side", "player")) == "player" else enemy_party
	var slot: int = int(t.get("slot", 0))
	if slot < 0 or slot >= party.size():
		return {}
	var mon: Dictionary = party[slot]
	return mon

## Drop a commanding Tatsugiri from a target list: it cannot be
## hit by any move while it is in Dondozo's mouth (Showdown
## conditions.ts, "commanding" onInvulnerability: false). Returns
## the targets that stay. Used by _perform_action_doubles and by
## the Dancer copy (Patch J).
func _drop_commanding_targets(targets: Array, logs: Array) -> Array:
	var kept: Array = []
	for t in targets:
		var t_mon: Dictionary = _doubles_mon(t)
		if bool(t_mon.get("commanding", false)):
			logs.append("It can't hit " + _mon_name(t_mon) + " while it's commanding Dondozo!")
		else:
			kept.append(t)
	return kept

## Switch the bench mon at target_idx into one doubles slot.
## target_idx must point at the bench (2 or later): the other
## active slot is not a switch target. Works even when the slot's
## mon has fainted, so it also sends in replacements. The "come
## back!" line is only said when the slot's mon is still alive.
func _doubles_switch(party: Array, target_idx: int, slot: int, foe: Dictionary, is_player: bool, logs: Array) -> void:
	if target_idx < 2 or target_idx >= party.size() or int(party[target_idx].get("hp", 0)) <= 0:
		logs.append("That switch is not possible.")
		return
	if int(party[slot].get("hp", 0)) > 0:
		AbilityEngine.on_switch_out(party[slot], field_state)
		# V5: switching out ends Bide and clears the Counter store.
		_clear_bide(party[slot], logs)
		_clear_counter_store(party[slot])
		# Switching out also ends the airborne state, and frees
		# a Sky Drop target the outgoing mon was carrying.
		_clear_airborne(party[slot])
		party[slot]["switched_in_this_turn"] = false
		party[slot]["switch_flag"] = false
		party[slot]["force_switch"] = false
		logs.append(_mon_name(party[slot]) + ", come back!")

	var incoming: Dictionary = party[target_idx]
	party[target_idx] = party[slot]
	party[slot] = incoming
	incoming["active_turns"] = 0
	incoming["switched_in_this_turn"] = true

	var hazards: Dictionary = field_state["player_hazards"] if is_player else field_state["enemy_hazards"]
	logs.append_array(StatusAndFieldEngine.apply_entry_hazards(incoming, hazards))
	# Ally keys must be set before switch-in abilities run: Costar
	# copies the ally's stages, Curious Medicine resets them, and
	# Commander checks for a Dondozo ally.
	_refresh_doubles_allies()
	# Sync BEFORE the incoming mon's switch-in abilities run: the
	# outgoing mon may have been the Neutralizing Gas holder, and
	# its flag must be gone before the new mon's abilities are
	# checked (the engine guard reads this flag).
	_sync_field_flags()
	_refresh_fallen_allies()
	logs.append_array(AbilityEngine.on_switch_in(incoming, foe, field_state))
	_maybe_clear_screens(incoming, logs)
	_apply_form_change(incoming, logs)
	_apply_terrain_on_switch_in(incoming)
	ItemEngine.on_switch_in_items(incoming, field_state, logs)
	_apply_tailwind_switch_in(incoming, is_player, logs)
	_sync_field_flags()
	party[slot]["participated"] = true


	logs.append("Go! " + _mon_name(party[slot]) + "!")

## Send the next living bench mon into one doubles slot. The bench
## starts at index 2 (slots 0 and 1 are active). Returns false when
## no living bench mon is left.
func _send_next_doubles(party: Array, slot: int, foe: Dictionary, is_player: bool, logs: Array) -> bool:
	for i in range(2, party.size()):
		if int(party[i].get("hp", 0)) > 0:
			_doubles_switch(party, i, slot, foe, is_player, logs)
			return true
	return false

## A Pokemon in one doubles slot fainted: log it, give EXP to the
## other side, then either the battle is over, the player must pick
## a new Pokemon, or the foe sends its next one into that slot at
## once. This is the slot-aware copy of _handle_faint; _handle_faint
## itself is unchanged and still serves singles (it always reads
## party[0]).
func _handle_faint_slot(fainted_is_player: bool, slot: int, logs: Array, by_move: bool = true, koer: Dictionary = {}) -> void:
	var fainted_party: Array = player_party if fainted_is_player else enemy_party
	var winner_party: Array = enemy_party if fainted_is_player else player_party
	if fainted_party.is_empty() or slot < 0 or slot >= fainted_party.size():
		return
	var fainted: Dictionary = fainted_party[slot]
	if int(fainted.get("hp", 0)) > 0:
		return
	# Fainting ends the airborne state, and a fainted Sky Drop
	# carrier drops the mon it was carrying.
	_clear_airborne(fainted)
	logs.append(_mon_name(fainted) + " fainted!")
	grant_exp(winner_party, fainted, logs)
	var foe_slot: Dictionary = winner_party[slot] if slot >= 0 and slot < winner_party.size() else {}
	# The KOer is the mon that landed the move, passed in by the
	# caller. The same-slot foe is only a guess: in doubles the
	# attacker often fights from the other slot.
	if not koer.is_empty():
		foe_slot = koer
	AbilityEngine.on_faint(fainted, foe_slot, field_state, logs, by_move)
	_sync_field_flags()
	_refresh_fallen_allies()
	# Commander: when Dondozo faints, its Tatsugiri comes out of


	# the mouth and can act again. When Tatsugiri itself faints
	# while commanding, nothing is cleared on Dondozo: it keeps
	# "commanded" and its +2 stages, so a replacement Tatsugiri
	# cannot re-trigger Commander.
	if str(fainted.get("species", "")).to_lower() == "dondozo":
		var ally_slot: int = 1 if slot == 0 else 0
		if ally_slot < fainted_party.size():
			var cmd_ally: Dictionary = fainted_party[ally_slot]
			if bool(cmd_ally.get("commanding", false)):
				cmd_ally["commanding"] = false
				logs.append(_mon_name(cmd_ally) + " came out of Dondozo's mouth!")
	if _all_fainted(fainted_party):
		return
	if fainted_is_player:
		battle_state["player_must_switch"] = true
		logs.append("Choose your next Pokemon!")
	else:
		var foe0: Dictionary = player_party[0] if not player_party.is_empty() else {}
		_send_next_doubles(enemy_party, slot, foe0, false, logs)

## Do one side's action for one doubles slot. Same action shapes as
## _perform_action, plus the slot the mon fights from. A "switch"
## action is allowed even when the slot's mon has fainted (sending
## in a replacement); every other action needs a living mon in the
## slot. Catching is not offered here: doubles battles are trainer
## battles, and _perform_action already handles balls only for wild
## singles. Returns {"fainted": bool}.
func _perform_action_doubles(action: Dictionary, is_player: bool, slot: int, logs: Array) -> Dictionary:
	var out: Dictionary = {"fainted": false}
	var party: Array = player_party if is_player else enemy_party
	var foe_party: Array = enemy_party if is_player else player_party
	if slot < 0 or slot >= party.size():
		return out
	var atype: String = str(action.get("type", "move"))
	if atype != "switch" and int(party[slot].get("hp", 0)) <= 0:
		return out
	# Commander: a Tatsugiri in Dondozo's mouth cannot act
	# (Showdown conditions.ts, "commanding" onBeforeTurn cancels
	# the action). "none" is not blocked: it already does nothing.
	if atype != "none" and bool(party[slot].get("commanding", false)):
		logs.append(_mon_name(party[slot]) + " can't move while commanding Dondozo!")
		return out
	# A mon carried up by Sky Drop cannot act at all while it
	# is held in the sky.
	if atype != "none" and bool(party[slot].get("held_in_sky", false)):
		logs.append(_mon_name(party[slot]) + " is held in the sky and can't move!")
		return out
	match atype:
		"switch":
			var foe0: Dictionary = foe_party[0] if not foe_party.is_empty() else {}
			# Commander: a commanded Dondozo cannot switch out
			# while Tatsugiri is in its mouth (the commanding
			# Tatsugiri itself never reaches here — the check
			# above stops all of its actions).
			if bool(party[slot].get("commanded", false)):
				logs.append(_mon_name(party[slot]) + " can't switch out while Commander is active!")
				return out
			var trapped: bool = false
			for fslot in range(mini(2, foe_party.size())):
				var fmon: Dictionary = foe_party[fslot]
				if int(fmon.get("hp", 0)) > 0 and AbilityEngine.traps_foe(fmon, party[slot]):
					logs.append(_mon_name(fmon) + "'s " + str(fmon.get("ability", "")) + " stops " + _mon_name(party[slot]) + " switching out!")
					trapped = true
					break
			if not trapped:
				_doubles_switch(party, int(action.get("target_idx", -1)), slot, foe0, is_player, logs)

		"item":
			var attacker: Dictionary = party[slot]
			var item_id: String = str(action.get("item_id", ""))
			var used: bool = ItemEngine.use_battle_item(item_id, attacker, logs)
			if used:
				AbilityEngine.on_item_use(attacker, item_id, field_state, logs)
				# A Revive brings a mon back: refresh the fainted
				# ally count so Supreme Overlord drops at once.
				_refresh_fallen_allies()
			else:
				logs.append("The " + item_id + " didn't work.")

		"move":
			var attacker2: Dictionary = party[slot]
			var gimmick_refused: bool = _gimmick_gate_check(action, is_player, logs)
			if not gimmick_refused:
				_apply_gimmick(action, attacker2, logs, is_player)
			var move_name: String = str(action.get("move_name", "Tera Blast"))
			# V5 Bide lock, doubles: same rule as singles.
			if bool(attacker2.get("bide_active", false)) and move_name != "Bide":
				move_name = "Bide"
			# An airborne mon must strike with the move it rose
			# with: whatever move was picked is replaced.
			if str(attacker2.get("airborne_move", "")) != "":
				move_name = _airborne_move_name(str(attacker2.get("airborne_move", "")))

			var override: Dictionary = {}
			if str(action.get("z_crystal", "")) != "" and not gimmick_refused:
				var zres: Dictionary = _apply_z_move(action, move_name, logs, attacker2, is_player)
				move_name = str(zres.get("move_name", move_name))
				override = zres.get("override", {})
			var move: Dictionary = _get_move(move_name)
			for k in override.keys():
				move[k] = override[k]
			# Ability before-move hooks. Called here, before targets
			# are resolved, so the attacker's marks land in time:
			# Propeller Tail and Stalwart set
			# move["ignores_redirection"] on this move dict, and the
			# targeting step below reads it. No defender is known
			# yet, so defender-side blocks (Soundproof and the like)
			# do not fire here; they need a per-target call. A
			# "skip" result (Truant) stops the move before it is
			# ever targeted.
			# Status moves skip this early call: no defender is
			# known yet, so defender-side arms (Rebound, Soundproof)
			# cannot fire here. They run once per target inside
			# _execute_move_doubles instead. Damaging moves keep the
			# early call: Propeller Tail and Stalwart must mark the
			# move before targeting, and Truant must stop the move
			# before it is ever targeted.
			var before: Dictionary = {}
			if str(move.get("cat", move.get("category", ""))).to_lower() != "status":
				before = AbilityEngine.on_before_move(attacker2, {}, move, field_state, logs)
			if bool(before.get("skip", false)):
				return out
			# The before-move hooks mark the move with
			# ignores_protect (Unseen Fist, Piercing Drill),
			# but _execute_move_doubles loads a fresh move dict
			# from the database, so the mark would be lost.
			# Carry it in the override, which is merged into
			# that fresh dict. No second before_move call:
			# Truant toggles on every call, so calling it
			# again would break it.
			if bool(move.get("ignores_protect", false)):
				override["ignores_protect"] = true

			# before_move ran on this local move dict, but
			# _execute_move_doubles fetches a fresh copy from the
			# database, so a hit count set here (Parental Bond
			# multihit 2) would be lost. Carry it in the override,
			# which the execute function copies onto its own dict.
			if move.has("multihit"):
				override["multihit"] = move["multihit"]
			if move.has("multihit_type"):
				override["multihit_type"] = move["multihit_type"]

			var side_name: String = "player" if is_player else "enemy"
			var targets: Array = DoublesTargeting.resolve_targets(move, slot, side_name, _doubles_field_view())
			targets = _drop_commanding_targets(targets, logs)
			var res: Dictionary = _execute_move_doubles(attacker2, targets, move_name, is_player, slot, logs, override)
			out["fainted"] = bool(res.get("fainted", false))
			# Held-item post-move hooks and Eject Pack
			# consumption, the doubles mirror of the singles
			# dispatcher.
			ItemEngine.on_after_move(attacker2, _get_move(move_name), logs)
			_consume_eject_pack(attacker2, is_player, _get_move(move_name), logs, slot)
			for t2 in targets:
				var t2_is_player: bool = str(t2.get("side", "player")) == "player"
				var t2_party: Array = player_party if t2_is_player else enemy_party
				var t2_slot: int = int(t2.get("slot", 0))
				if t2_slot >= 0 and t2_slot < t2_party.size():
					_consume_eject_pack(t2_party[t2_slot], t2_is_player, _get_move(move_name), logs, t2_slot)
			if bool(res.get("switch_requested", false)):
				_handle_pivot(is_player, logs, slot)
		"none":
			pass
		_:
			logs.append("Unknown action.")
	return out

## True when the move is a dance move for Dancer. Checked by move
## id (the 12 names in DANCE_MOVE_IDS, from moves.json
## flags.dance), not by flags, because the loaded move dicts do
## not always carry flags.
func _is_dance_move(move_name: String) -> bool:
	var move_id: String = move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "")
	return move_id in DANCE_MOVE_IDS

## Field view for Dancer targeting. In doubles it is the normal
## doubles view; in singles only slot 0 is live on each side
## (slot 1 is the bench and must never be a target).
func _dancer_field_view() -> Dictionary:
	if active_format == "doubles":
		return _doubles_field_view()
	var view: Dictionary = field_state.duplicate(true)
	var pa: Array = []
	var ea: Array = []
	pa.append(player_party[0] if not player_party.is_empty() else {})
	pa.append({})
	ea.append(enemy_party[0] if not enemy_party.is_empty() else {})
	ea.append({})
	view["player_active"] = pa
	view["enemy_active"] = ea
	return view

## The live mon dict for one {"side", "slot"} in a dancer field
## view, or {} when the slot is empty.
func _dancer_view_mon(view: Dictionary, side: String, slot: int) -> Dictionary:
	var key: String = "player_active" if side == "player" else "enemy_active"
	var actives: Array = view.get(key, [])
	if slot < 0 or slot >= actives.size():
		return {}
	var mon: Dictionary = actives[slot]
	return mon

## Dancer copies (Showdown sim/battle-actions.ts runMove): after a
## dance move does something, every other living active mon with
## Dancer uses the same move once, slowest first (raw Speed stat,
## Trick Room ignored), with no PP cost and no further Dancer
## triggers. The copy's target follows Showdown: for a
## single-target dance move, if the original target is not the
## dancer's ally and the original user is, the copy targets the
## original target; otherwise it targets the original user.
## Self-target and spread moves resolve normally from the dancer's
## slot. A commanding Tatsugiri is never a copy target.
## orig_targets are the resolved targets of the original move
## ({"side", "slot"} dicts); user_slot is the original user's slot.
func _dancer_copy(user: Dictionary, user_is_player: bool, user_slot: int, orig_targets: Array, move_name: String, logs: Array) -> void:
	if not _is_dance_move(move_name):
		return
	var move: Dictionary = _get_move(move_name)
	var user_side: String = "player" if user_is_player else "enemy"
	# Collect the other living active Dancers, slowest first.
	var dancers: Array = []
	for side in ["player", "enemy"]:
		var party: Array = player_party if side == "player" else enemy_party
		var max_slot: int = 2 if active_format == "doubles" else 1
		for slot in range(max_slot):
			if side == user_side and slot == user_slot:
				continue
			if slot >= party.size():
				continue
			var cand: Dictionary = party[slot]
			if int(cand.get("hp", 0)) <= 0:
				continue
			if str(cand.get("ability", "")) != "Dancer":
				continue
			dancers.append({"mon": cand, "side": side, "slot": slot})
	# Slowest first: raw Speed stat, ties by slot then side
	# (Showdown breaks ties by time with the ability, which this
	# engine does not track).
	var n: int = dancers.size()
	for i in range(n):
		var best: int = i
		for j in range(i + 1, n):
			var later: Dictionary = dancers[j]
			var current: Dictionary = dancers[best]
			var later_mon: Dictionary = later.get("mon", {})
			var current_mon: Dictionary = current.get("mon", {})
			var later_spe: float = float(later_mon.get("spe", 100))
			var current_spe: float = float(current_mon.get("spe", 100))
			var later_first: bool = false
			if later_spe < current_spe:
				later_first = true
			elif later_spe == current_spe:
				if int(later.get("slot", 0)) < int(current.get("slot", 0)):
					later_first = true
				elif int(later.get("slot", 0)) == int(current.get("slot", 0)) and str(later.get("side", "player")) < str(current.get("side", "player")):
					later_first = true
			if later_first:
				best = j
		if best != i:
			var tmp: Dictionary = dancers[i]
			dancers[i] = dancers[best]
			dancers[best] = tmp
	var view: Dictionary = _dancer_field_view()
	var mtarget: String = str(move.get("target", "normal")).to_lower()
	var single_target: bool = mtarget == "normal" or mtarget == "any" or mtarget == "adjacentfoe" or mtarget == "randomnormal"
	for d in dancers:
		if _battle_over():
			return
		var dancer: Dictionary = d.get("mon", {})
		if int(dancer.get("hp", 0)) <= 0:
			continue
		var d_side: String = str(d.get("side", "player"))
		var d_slot: int = int(d.get("slot", 0))
		var copy_targets: Array = []
		if single_target and not orig_targets.is_empty():
			var orig_last: Dictionary = orig_targets[orig_targets.size() - 1]
			var orig_target_side: String = str(orig_last.get("side", ""))
			var orig_target_slot: int = int(orig_last.get("slot", 0))
			var intended_side: String = user_side
			var intended_slot: int = user_slot
			if orig_target_side != d_side and user_side == d_side:
				intended_side = orig_target_side
				intended_slot = orig_target_slot
			var intended: Dictionary = _dancer_view_mon(view, intended_side, intended_slot)
			if not intended.is_empty() and int(intended.get("hp", 0)) > 0 and not bool(intended.get("commanding", false)):
				copy_targets = [{"side": intended_side, "slot": intended_slot}]
		if copy_targets.is_empty():
			copy_targets = DoublesTargeting.resolve_targets(move, d_slot, d_side, view)
			copy_targets = _drop_commanding_targets(copy_targets, logs)
		if copy_targets.is_empty():
			continue
		logs.append("%s's Dancer copied %s!" % [_mon_name(dancer), move_name])
		if active_format == "doubles":
			_execute_move_doubles(dancer, copy_targets, move_name, d_side == "player", d_slot, logs, {}, true)
		else:
			var first_target: Dictionary = copy_targets[0]
			var copy_def: Dictionary = _dancer_view_mon(view, str(first_target.get("side", "")), int(first_target.get("slot", 0)))
			_execute_move(dancer, copy_def, move_name, d_side == "player", logs, {}, true)

## One attack in doubles, against one or more targets. The checks
## that happen once per use (Choice lock, flinch, sleep / freeze /
## paralysis, PP) run once; accuracy is rolled per target; damage is
## worked out per target with the 0.75x spread cut when the move hits
## both foes. A single target goes through this same code, so
## _execute_move is not called here and its singles behaviour is
## untouched. Returns {"damage", "fainted", "switch_requested"}.
## damage is the total damage dealt to all targets.
func _execute_move_doubles(attacker: Dictionary, targets: Array, move_name: String, is_player: bool, attacker_slot: int, logs: Array, override: Dictionary = {}, is_dancer_copy: bool = false) -> Dictionary:
	var out: Dictionary = {"damage": 0, "fainted": false, "switch_requested": false}
	var move: Dictionary = _get_move(move_name)
	for k in override.keys():
		move[k] = override[k]
	move["name"] = move_name
	# The before-move hooks ran in _perform_action_doubles on a
	# different move dict, so the ignore_ability mark from Mold
	# Breaker, Teravolt and Turboblaze never reached this dict.
	# Re-mark it here from the attacker ability, so the damage
	# and immunity code below reads the flag.
	if str(attacker.get("ability", "")) == "Mold Breaker" or str(attacker.get("ability", "")) == "Teravolt" or str(attacker.get("ability", "")) == "Turboblaze":
		move["ignore_ability"] = true
	var aname: String = _mon_name(attacker)
	# Gravity disables the flying and jumping moves, same as
	# singles: the move fails before anything else runs.
	if int(field_state.get("gravity", 0)) > 0 and _gravity_disabled(move):
		logs.append(aname + " used " + move_name + "!")
		logs.append("Gravity prevents " + move_name + "!")
		return out

	var held: String = str(attacker.get("item", ""))
	if not is_dancer_copy and held != "" and ItemEngine.is_choice_item(held):
		var locked: String = ItemEngine.choice_locked_move(attacker)
		if locked != "" and locked != move_name:
			logs.append(aname + " is locked into " + locked + " by its Choice item!")
			return _execute_move_doubles(attacker, targets, locked, is_player, attacker_slot, logs, {})
	if bool(attacker.get("flinched", false)):
		# Steadfast fires here, before the flag is cleared. The
		# mon still cannot move this turn.
		AbilityEngine.on_flinch(attacker, logs)
		attacker["flinched"] = false
		logs.append(aname + " flinched and couldn't move!")
		# V5: being stopped from moving ends Bide (Showdown
		# onMoveAborted removes the volatile).
		_clear_bide(attacker, logs)
		return out
	var can_act: Dictionary = StatusAndFieldEngine.can_act_this_turn(attacker)
	if str(can_act.get("log", "")) != "":
		logs.append(str(can_act.get("log", "")))
	if not bool(can_act.get("can_act", true)):
		_clear_bide(attacker, logs)
		return out
	# Confusion is checked after sleep/freeze/paralysis and before
	# PP is taken, so a confused self-hit costs no PP.
	if _check_confusion(attacker, is_player, attacker_slot, logs):
		_clear_bide(attacker, logs)
		return out

	# Pressure targets: the foe mons in this move's target list
	# (allies are left out, so an ally with Pressure costs
	# nothing). _deduct_pp adds 1 extra PP at most.
	var pp_foes: Array = []
	var my_side: String = "player" if is_player else "enemy"
	for t in targets:
		if str(t.get("side", "")) != my_side:
			var tmon: Dictionary = _doubles_mon(t)
			if not tmon.is_empty():
				pp_foes.append(tmon)
	# V5 Trump Card: PP left is counted when the move is picked,
	# before this use spends 1 PP. Capture it now; _deduct_pp
	# below spends the PP. The resolver reads pp_left_at_pick.
	if str(move.get("damage_rule", "")) == "trump_card":
		move["pp_left_at_pick"] = _pp_left(attacker, move)
	# Airborne moves (Fly, Bounce, Sky Drop), same as singles:
	# when the attacker is already up in the air with this same
	# move, this use is the strike turn and costs no PP again.
	var airborne_id_d: String = _airborne_move_id(move_name)
	var is_airborne_strike_d: bool = airborne_id_d != "" and str(attacker.get("airborne_move", "")) == airborne_id_d
	if not is_dancer_copy and not is_airborne_strike_d and not _deduct_pp(attacker, move, pp_foes):
		logs.append(aname + " has no PP left for " + move_name + "!")
		return out
	# The strike turn clears the airborne state first, then the
	# move runs normally below. The first use deals no damage:
	# the user rises (Sky Drop takes its first target up too),
	# and PP was already spent above, as usual.
	if is_airborne_strike_d:
		_clear_airborne(attacker)
	elif airborne_id_d != "":
		attacker["airborne_move"] = airborne_id_d
		logs.append(aname + " used " + move_name + "!")
		if airborne_id_d == "fly":
			logs.append(aname + " flew up high!")
		elif airborne_id_d == "bounce":
			logs.append(aname + " sprang up!")
		elif not targets.is_empty():
			var sky_target: Dictionary = _doubles_mon(targets[0])
			if not sky_target.is_empty():
				sky_target["held_in_sky"] = true
				attacker["skydrop_target"] = sky_target
				logs.append(aname + " took " + _mon_name(sky_target) + " up into the sky!")
		return out


	# Dancer copies run the before-move hooks once, like a normal
	# use (Protean changes type, Truant can skip the copy, a
	# Soundproof target blocks a Clangorous Soul copy). Normal
	# moves already had before_move in _perform_action_doubles, so
	# this only runs for copies.
	if is_dancer_copy:
		var copy_first: Dictionary = {}
		if not targets.is_empty():
			copy_first = _doubles_mon(targets[0])
		var copy_before: Dictionary = AbilityEngine.on_before_move(attacker, copy_first, move, field_state, logs)
		# A Dancer copy of a status move can bounce too: the
		# bounced move is used against its own user instead.
		if bool(copy_before.get("bounced", false)):
			logs.append(aname + " used " + move_name + "!")
			_apply_status_move(copy_first, attacker, move, not is_player, logs)
			return out
		if bool(copy_before.get("skip", false)):
			return out
	# Ability type change (Aerilate, Pixilate and the rest). The
	# before-move hooks already ran in _perform_action_doubles;
	# no real mon has both a type-changing ability and Protean /
	# Libero, so that order is safe here. mtype below reads the
	# new type.
	var new_type: String = AbilityEngine.move_type(attacker, move, field_state)
	if new_type != "":
		move["type"] = new_type
	var power: int = int(move.get("power", 0))
	var cat: String = str(move.get("cat", move.get("category", "")))
	var mtype: String = str(move.get("type", "Normal"))
	# V5 Bide: Bide never runs the target loop. It sets up, waits,
	# or unleashes through _execute_bide.
	if str(move.get("damage_rule", "")) == "bide":
		return _execute_bide(attacker, move, is_player, logs, true)
	# V5 Beat Up: the hit count is the able party members, and
	# each hit has its own power. Set both BEFORE the hit count
	# is rolled below, so the loop hits the right number of times.
	# The per-target resolver (Patch E5) reads the same powers.
	if str(move.get("damage_rule", "")) == "beat_up":
		var v5_d_party: Array = player_party if is_player else enemy_party
		var v5_d_powers: Array = _beat_up_powers(attacker, v5_d_party, logs)
		move["multihit"] = v5_d_powers.size()
		move["beat_up_powers"] = v5_d_powers

	# No living target: entry hazard moves target a side, not a
	# Pokemon, so they still work. Counter-style moves resolve per
	# target in the loop below, so with no target they do nothing.
	if targets.is_empty():

		var mtarget: String = str(move.get("target", "normal")).to_lower()
		if mtarget == "foeside":
			logs.append(aname + " used " + move_name + "!")
			var foe_side_party: Array = enemy_party if is_player else player_party
			var foe_def: Dictionary = attacker
			if not foe_side_party.is_empty():
				foe_def = foe_side_party[0]
			_apply_status_move(attacker, foe_def, move, is_player, logs)
			return out
		logs.append(aname + " used " + move_name + ", but there was no target!")
		return out
	# V5: only a move with NO damage_rule takes the status path
	# when its power is 0. A damage_rule move with power 0 in the
	# data is a damaging move, and the per-target resolver below
	# works out its real power or flat damage.
	if str(move.get("damage_rule", "")) == "" and (power <= 0 or cat.to_lower() == "status"):
		logs.append(aname + " used " + move_name + "!")
		if _is_drag_out(move):
			# Drag-out moves run once per use, not once per target.

			var drag_side: String = str(targets[0].get("side", ""))
			var drag_slot: int = int(targets[0].get("slot", 0))
			_handle_forced_switch(drag_side == "player", move, logs, drag_slot)
			return out
		if _is_field_move(move):
			# Field moves run once per use, not once per target.
			var first_def: Dictionary = _doubles_mon(targets[0]) if not targets.is_empty() else attacker
			_apply_field_move(attacker, first_def, move, is_player, logs)
			return out
		if MoveEffects.is_pivot(move):
			# Status pivots (Chilly Reception and the like): apply
			# the move's own effects once, then switch out of the
			# attacker's own slot. _apply_status_move would call
			# _handle_pivot with slot 0, which is wrong here.
			var first_def: Dictionary = _doubles_mon(targets[0])
			var after0: Dictionary = MoveEffects.apply_after_hit(attacker, first_def, move, 0, field_state, rng, logs)
			if bool(after0.get("switch_requested", false)):
				out["switch_requested"] = true
			return out
		var status_affected: bool = false
		for t in targets:
			var sdef: Dictionary = _doubles_mon(t)
			if int(sdef.get("hp", 0)) <= 0:
				continue
			# Defender-side before-move arms run here, once per
			# target: Rebound bounces a reflectable status move
			# back at the user on the switch-in turn, and a
			# "skip" (Dazzling, Queenly Majesty) stops the move.
			# Copies skip this: their before-move call already ran
			# in the Dancer-copy block above. Damaging moves never
			# reach this branch, and power-0 damaging moves already
			# had their early call, so only true status moves run
			# it here (Truant then fires exactly once).
			if not is_dancer_copy and cat.to_lower() == "status":
				var s_before: Dictionary = AbilityEngine.on_before_move(attacker, sdef, move, field_state, logs)
				if bool(s_before.get("bounced", false)):
					status_affected = true
					_apply_status_move(sdef, attacker, move, not is_player, logs)
					continue
				if bool(s_before.get("skip", false)):
					return out
			# Ability immunity for status moves: a Thunder Wave
			# aimed at (or redirected onto) a Lightning Rod mon,
			# or a Water status move onto a Storm Drain mon, is
			# stopped by that ability, and the Sp. Atk +1 still
			# fires through is_immune_by_ability. Wonder Guard is
			# left out on purpose: it does not block status moves
			# in Showdown, but this check has no real
			# effectiveness to test, so it would block them.
			if str(sdef.get("ability", "")) != "Wonder Guard" and AbilityEngine.is_immune_by_ability(sdef, mtype, str(attacker.get("ability", ""))):
				logs.append("It doesn't affect " + _mon_name(sdef) + "!")
				continue
			status_affected = true
			var target_is_ally: bool = str(t.get("side", "")) == ("player" if is_player else "enemy")
			_apply_status_move(attacker, sdef, move, is_player, logs, target_is_ally)


		if not is_dancer_copy and status_affected:
			_dancer_copy(attacker, is_player, attacker_slot, targets, move_name, logs)
		return out
	# Damaging move: one pass per living target.
	var spread: bool = DoublesTargeting.is_spread(move)
	var smult: float = DoublesTargeting.spread_mult(targets.size())
	# The attacker is passed so Skill Link forces 5 hits here too
	# (singles already passes it; doubles forgot it).
	var hits: int = MoveEffects.get_hit_count(move, rng, attacker)
	var total_all: int = 0

	logs.append(aname + " used " + move_name + "!")
	for t in targets:
		if int(attacker.get("hp", 0)) <= 0:
			break
		var defender: Dictionary = _doubles_mon(t)
		if defender.is_empty() or int(defender.get("hp", 0)) <= 0:
			continue
		# Toxic Debris needs to know whether the attacker hit its
		# own ally: then the spikes go on the other side instead
		# of the attacker's side (Showdown onDamagingHit).
		attacker["hit_ally"] = str(t.get("side", "")) == ("player" if is_player else "enemy")
		var dname: String = _mon_name(defender)
		# Defender-side priority block: Dazzling, Queenly
		# Majesty and Armor Tail protect the holder's whole
		# side in doubles, and damaging moves never got a
		# per-target before-move call, so the block is checked
		# here, once per foe target. A blocked target is
		# skipped; unprotected targets are still hit.
		if str(t.get("side", "")) != ("player" if is_player else "enemy"):
			if AbilityEngine.side_priority_block(attacker, move, _active_side_mons(not is_player), field_state, logs):
				continue
		# V5: work out THIS target's real power or flat damage.
		# A move with a damage_rule has power 0 in the data but
		# still hits, and the numbers depend on this target (its
		# weight, its HP, its level), so this runs per target, not
		# once before the loop. The resolver fails moves with no
		# setup (Counter with no stored hit, and the rest).
		# Magnitude and Present roll once per use: the resolver
		# stores the roll on the move dict (v5_roll) the first
		# time, and later targets reuse it.
		var v5_t_party: Array = player_party if is_player else enemy_party
		var v5_t: Dictionary = _resolve_variable_power(move, attacker, defender, logs, v5_t_party)
		var v5_t_kind: String = str(v5_t.get("kind", "none"))
		if v5_t_kind == "fail":
			logs.append(str(v5_t.get("reason", "It failed!")))
			continue
		if v5_t_kind == "power":
			move["power"] = int(v5_t.get("power", 0))
		# Beat Up needs nothing here: its powers and hit count
		# were already set before the loop (Patch E3), and the
		# hit loop reads them per hit (Patch E6).
		var v5_t_flat: int = 0
		var v5_t_is_flat: bool = v5_t_kind == "flat"
		if v5_t_is_flat:
			v5_t_flat = int(v5_t.get("damage", 0))
		var acc = move.get("acc", move.get("accuracy", 100))
		# V5 always_hits: no accuracy roll at all for this target.
		# V5 one-hit KO: accuracy is 30 + user level - this
		# target's level. The level fail was already checked by
		# the resolver above, per target.
		var v5_t_always: bool = bool(move.get("always_hits", false))
		if v5_t_always:
			acc = 100
		elif str(move.get("damage_rule", "")) == "ohko":
			acc = 30 + int(attacker.get("level", 5)) - int(defender.get("level", 5))
		var acc_mult: float = AbilityEngine.accuracy_mult(attacker, defender, move, field_state)
		acc_mult *= ItemEngine.accuracy_multiplier(attacker)
		if acc != null and acc_mult != 1.0 and not v5_t_always:
			acc = int(float(acc) * acc_mult)
		# Gravity accuracy boost (x5/3), same as singles.
		if acc != null and not v5_t_always and int(field_state.get("gravity", 0)) > 0:
			acc = int(float(acc) * 5.0 / 3.0)
		if not v5_t_always and acc != null and int(acc) < 100:
			if rng.randf() * 100.0 >= float(acc):
				logs.append("It missed " + dname + "!")
				ItemEngine.on_move_missed(attacker, logs)
				continue
		# V5 Present heal: the roll already picked heal, and the
		# accuracy roll above already passed. Heal the TARGET for
		# 1/4 of its max HP, then move on to the next target.
		if v5_t_kind == "heal":
			var v5_t_heal_max: int = int(defender.get("max_hp", 100))
			var v5_t_healed: int = mini(int(v5_t.get("amount", 0)), v5_t_heal_max - int(defender.get("hp", 0)))
			defender["hp"] = int(defender.get("hp", 0)) + v5_t_healed
			logs.append(_mon_name(defender) + " restored " + str(v5_t_healed) + " HP from the Present!")
			continue


		# Protect blocks the move for this target only, after
		# its accuracy roll: no damage, no secondary, no
		# status, no stat change. A contact move from a
		# Piercing Drill or Unseen Fist holder carries
		# ignores_protect and hits normally. An ally target
		# is never blocked by its own side's Protect.
		var target_is_foe: bool = str(t.get("side", "")) != ("player" if is_player else "enemy")
		if target_is_foe and _is_blocked_by_protect(defender, move):
			logs.append(dname + " protected itself!")
			continue
		if AbilityEngine.is_immune_by_ability(defender, mtype, str(attacker.get("ability", "")), 1.0, move):

			logs.append("It doesn't affect " + dname + "!")
			continue

		# Telepathy (Showdown abilities.ts, onTryHit): a mon takes
		# no damage from its ally's non-Status attacks. The ally
		# check is the target's side against the attacker's side.
		# This is the damaging branch only; the status branch is
		# untouched, so an ally's Heal Pulse and the like still
		# work. Mold Breaker, Teravolt and Turboblaze ignore it.
		if str(t.get("side", "")) == ("player" if is_player else "enemy") and str(defender.get("ability", "")) == "Telepathy" and str(attacker.get("ability", "")) != "Mold Breaker" and str(attacker.get("ability", "")) != "Teravolt" and str(attacker.get("ability", "")) != "Turboblaze":
			logs.append(dname + "'s Telepathy blocked the ally's attack!")
			continue
		var total: int = 0
		var eff: float = 1.0
		var was_crit: bool = false
		var stab_mult: float = 1.0
		# Semi-invulnerability, same as singles: an airborne
		# target (Fly, Bounce, Sky Drop, or carried by Sky Drop)
		# cannot be hit, except by Gust, Twister, Thunder,
		# Hurricane, Sky Uppercut and Smack Down, or when either
		# mon has No Guard. Gust and Twister deal double power
		# to an airborne target (applied on the per-target copy
		# below), and a hit by Smack Down brings it down.
		var airborne_double: bool = false
		if _is_airborne(defender):
			var hit_move_id_d: String = move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "")
			var no_guard_d: bool = str(attacker.get("ability", "")) == "No Guard" or str(defender.get("ability", "")) == "No Guard"
			if not no_guard_d and not (hit_move_id_d in AIRBORNE_HIT_IDS):
				logs.append(dname + " is in the air and avoided the attack!")
				continue
			if hit_move_id_d == "smackdown":
				_clear_airborne(defender)
				logs.append(dname + " was brought down by Smack Down!")
			elif hit_move_id_d == "gust" or hit_move_id_d == "twister":
				airborne_double = true
		# Knock Off hits 1.5x harder when this target holds an item
		# (Showdown onBasePower). The move dict is shared across
		# targets in doubles, so the boost goes on a per-target copy.
		var target_move: Dictionary = move
		var target_move_is_copy: bool = false
		if _is_knock_off(move) and str(defender.get("item", "")) != "" and not AbilityEngine.blocks_take_item(defender, attacker, move):
			target_move = move.duplicate()
			target_move_is_copy = true
			target_move["power"] = int(float(int(move.get("power", 0))) * 1.5)
		if airborne_double:
			if not target_move_is_copy:
				target_move = move.duplicate()
			target_move["power"] = int(target_move.get("power", 0)) * 2
		if v5_t_is_flat:
			# V5 flat damage: no formula, no per-hit loop. The
			# number is dealt as-is after accuracy. Type immunity
			# still applies, checked by the eff test below.
			total = v5_t_flat
			var v5_t_types: PackedStringArray = PackedStringArray()
			for v5_tt in defender.get("types", []):
				v5_t_types.append(str(v5_tt))
			eff = PUWBattleEngine.type_multiplier(mtype, v5_t_types)
		else:
			for i in range(hits):
				# V5 Beat Up: each hit uses the power of the party
				# member that hit belongs to, not one shared power.
				if v5_t_kind == "beat_up":
					var v5_t_powers: Array = move.get("beat_up_powers", [])
					if i < v5_t_powers.size():
						target_move["power"] = int(v5_t_powers[i])
				attacker["field"] = field_state
				defender["field"] = field_state
				# Toxic Debris reads this to put the spikes on the right side.
				attacker["side"] = "player" if is_player else "enemy"
				var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, target_move, rng)
				eff = float(res.get("effectiveness", 1.0))
				was_crit = bool(res.get("critical", false))
				stab_mult = float(res.get("stab", 1.0))
				# Parental Bond: the second hit deals 1/4 damage
				# (Showdown BattleActions modifyDamage), per target.
				# The mark is on the shared move dict (see Patch J1).
				var hit_dmg: int = int(res.get("damage", 0))
				if str(move.get("multihit_type", "")) == "parentalbond" and i == 1:
					hit_dmg = maxi(1, hit_dmg / 4)
				total += hit_dmg

		if eff <= 0.0:
			logs.append("It doesn't affect " + dname + "!")
			continue

		var is_stab: bool = stab_mult > 1.0
		if not v5_t_is_flat:
			var pmult: float = AbilityEngine.power_mult(attacker, defender, move, field_state)
			if pmult != 1.0:
				total = maxi(1, int(float(total) * pmult))
			# Ally damage abilities (Friend Guard 0.75x, Power Spot
			# 1.3x, Steely Spirit 1.5x Steel). The ally is the live
			# ally dict set by _refresh_doubles_allies ({} when the
			# slot is empty); an empty ally gives 1.0x.
			var ally: Dictionary = attacker.get("ally", {})
			var amult: float = AbilityEngine.ally_damage_mult(ally, attacker, defender, move, total)
			if amult != 1.0:
				total = maxi(1, int(float(total) * amult))
			total = ItemEngine.check_weaken_berry(defender, move, eff, total, logs, field_state)
			total = AbilityEngine.modify_damage(attacker, defender, move, total, is_stab, was_crit, eff)


			total = ItemEngine.modify_attack_damage(attacker, defender, move, total)
			if spread:
				total = int(float(total) * smult)
				logs.append("Spread damage was reduced to 0.75x.")
		else:
			# V5 flat damage skips the formula modifiers above: a
			# fixed number ignores power, ally, ability and item
			# damage boosts. Sturdy still saves a full-HP mon,
			# through the one shared cap helper. Focus Sash still
			# runs, on the line below, like every other hit.
			total = _apply_sturdy_cap(attacker, defender, total)
		# Magic Room: held items have no effect, so the sash
		# never triggers while it is up.
		if int(field_state.get("magic_room", 0)) <= 0:
			total = ItemEngine.check_focus_sash(defender, total)
			total = ItemEngine.check_focus_band(defender, total, rng, logs)

		if str(defender.get("item_consumed", "")) == "Focus Sash":
			logs.append(dname + " held on with its Focus Sash!")
			defender["item_consumed"] = ""
		defender["last_effectiveness"] = eff
		var move_for_effects: Dictionary = move.duplicate()
		move_for_effects["multihit"] = hits
		var after: Dictionary = MoveEffects.apply_after_hit(attacker, defender, move_for_effects, total, field_state, rng, logs)
		defender["hp"] = maxi(0, int(defender.get("hp", 0)) - total)
		# V5: remember this hit for Counter and for Bide, set the
		# foe-side hazard, and use up Fling, Natural Gift and Spit Up.
		_record_damage_taken(attacker, defender, move, total, logs)
		_apply_v5_hazard(attacker, move, total, is_player, logs)
		_apply_fling_effect(attacker, defender, move, total, logs)
		_consume_v5_item(attacker, move, total, logs)
		# Red Card, same rule as singles: a standing defender's
		# card drags the attacker out of its own slot.
		if total > 0 and int(field_state.get("magic_room", 0)) <= 0 and ItemEngine.check_red_card(defender):
			if is_wild and not is_player:
				battle_state["wild_fled"] = true
				logs.append("The wild " + _mon_name(attacker) + " fled from the Red Card!")
			else:
				logs.append(_mon_name(attacker) + " was dragged out by the Red Card!")
				_handle_forced_switch(is_player, move, logs, attacker_slot)
		# Eject Button, the Red Card's mirror: the HOLDER is
		# switched out of its own slot after being hit.
		if total > 0 and int(field_state.get("magic_room", 0)) <= 0 and ItemEngine.check_eject_button(defender):
			var eb_side: String = str(t.get("side", "player"))
			var eb_slot: int = int(t.get("slot", 0))
			logs.append(_mon_name(defender) + " was switched out by its Eject Button!")
			_handle_forced_switch(eb_side == "player", move, logs, eb_slot)
		if str(move.get("damage_rule", "")) == "spit_up" and total > 0:
			attacker["stockpile_layers"] = 0
			logs.append(_mon_name(attacker) + " used up its Stockpile!")
		if str(move.get("damage_rule", "")) == "final_gambit" and total > 0 and int(attacker.get("hp", 0)) > 0:
			# Final Gambit faints the user after dealing its damage.
			# Only the HP is set here: the faint itself is handled
			# by the existing check at the end of this function, so
			# the "fainted!" line and EXP are said once, not twice.
			attacker["hp"] = 0
			logs.append(_mon_name(attacker) + " fainted from Final Gambit!")
		# V5: a Counter-family hit that lands uses up the stored hit.
		if str(move.get("damage_rule", "")) == "counter" and total > 0:
			attacker["last_damage_taken"] = 0
			attacker["last_damage_cat"] = ""
		ItemEngine.on_damage_taken(defender, move, logs, attacker, total, field_state)
		AbilityEngine.on_damage_taken(defender, attacker, move, total, logs)

		logs.append("It did " + str(total) + " damage to " + dname + ".")
		if eff > 1.0:
			logs.append("It's super effective!")
		elif eff < 1.0:
			logs.append("It's not very effective...")
		if was_crit:
			logs.append("A critical hit!")
		# Knock Off removes this target's item after the hit.
		if _is_knock_off(move) and total > 0:
			_try_take_item(defender, attacker, move, logs)
		_apply_form_change(defender, logs)
		total_all += total

		out["damage"] = total_all
		if bool(after.get("switch_requested", false)):
			out["switch_requested"] = true
		if int(defender.get("hp", 0)) <= 0 or bool(after.get("fainted", false)):
			out["fainted"] = true
			var t_side: String = str(t.get("side", "player"))
			var t_slot: int = int(t.get("slot", 0))
			_handle_faint_slot(t_side == "player", t_slot, logs, true, attacker)
		elif _is_drag_out(move):
			var d_side: String = str(t.get("side", "player"))
			var d_slot: int = int(t.get("slot", 0))
			_handle_forced_switch(d_side == "player", move, logs, d_slot)
	# Life Orb hurts once per use, not once per target, so it runs
	# here with the total damage, after the loop.
	if not AbilityEngine.blocks_indirect_damage(attacker):
		ItemEngine.apply_recoil_after_attack(attacker, total_all, logs)
	# Shell Bell heals once per use too, on the same total.
	ItemEngine.apply_shell_bell_after_attack(attacker, total_all, logs)
	_apply_form_change(attacker, logs)
	if int(attacker.get("hp", 0)) <= 0:

		_handle_faint_slot(is_player, attacker_slot, logs, false)
		out["fainted"] = true
	# Wimp Out / Emergency Exit: after the fainting is sorted, a
	# mon that dropped to half HP or less switches out.
	_maybe_ability_switch(not is_player, logs)
	_maybe_ability_switch(is_player, logs)
	if not is_dancer_copy and total_all > 0:
		_dancer_copy(attacker, is_player, attacker_slot, targets, move_name, logs)
	return out

## End of turn for doubles: held items, abilities, and status
## damage for all four living active mons, then Dynamax running out,
## then the field timers. This is the four-mon copy of _end_of_turn;
## _end_of_turn itself is unchanged and still serves singles.
func _end_of_turn_doubles(logs: Array) -> void:
	# Protect ends with the turn: clear every active mon's
	# flag now, before the end-of-turn effects run.
	_clear_protect_flags()
	# The stall chain ticks with the turn too (duration 2:
	# a chain fed this turn lives for one more turn).
	_tick_stall_chains()
	var actives: Array = []
	var active_sides: Array = []
	for slot in range(2):
		if slot < player_party.size():
			actives.append(player_party[slot])
			active_sides.append(true)
		if slot < enemy_party.size():
			actives.append(enemy_party[slot])
			active_sides.append(false)

	# Unnerve blocks the OTHER side's Berries. Work out once,
	# before the loop, whether each side has a living Unnerve (or
	# As One) holder among its active mons.
	var player_side_unnerve: bool = _side_has_unnerve(_active_side_mons(true))
	var enemy_side_unnerve: bool = _side_has_unnerve(_active_side_mons(false))
	for i in actives.size():
		var mon: Dictionary = actives[i]
		if int(mon.get("hp", 0)) <= 0:
			continue
		# active_sides runs next to actives: true is the player's
		# mon, false the foe's.
		var foe_has_unnerve: bool = enemy_side_unnerve if bool(active_sides[i]) else player_side_unnerve
		ItemEngine.on_end_of_turn(mon, field_state, logs, foe_has_unnerve)
		AbilityEngine.on_end_of_turn(mon, field_state, logs)
		logs.append_array(StatusAndFieldEngine.apply_end_of_turn(mon, field_state))
		_apply_form_change(mon, logs)
		mon["active_turns"] = int(mon.get("active_turns", 0)) + 1

		if int(mon.get("heal_block_turns", 0)) > 0:
			mon["heal_block_turns"] = int(mon.get("heal_block_turns", 0)) - 1
			if int(mon.get("heal_block_turns", 0)) <= 0:
				logs.append(_mon_name(mon) + "'s Heal Block wore off!")
		if int(mon.get("noise_heal_block_turns", 0)) > 0:
			mon["noise_heal_block_turns"] = int(mon.get("noise_heal_block_turns", 0)) - 1
			if int(mon.get("noise_heal_block_turns", 0)) <= 0:
				logs.append(_mon_name(mon) + "'s Heal Block from Psychic Noise wore off!")
	for mon in actives:
		if bool(mon.get("dynamax_active", false)):
			mon["dynamax_turns"] = int(mon.get("dynamax_turns", 1)) - 1
			if int(mon.get("dynamax_turns", 0)) <= 0:
				PUWGimmicks.end_dynamax(mon, logs)
	# Leech Seed drains after the other end-of-turn effects:
	# each seeded mon loses 1/8 of its max HP and the active
	# mon on the seeder's side in the same slot receives it.
	# actives is interleaved [p0, e0, p1, e1], so a mon's
	# slot is its index divided by 2, and the same-slot mon
	# on the seeder's side sits at that slot's base index
	# (+1 when the seeder's side is the enemy's).
	for i in actives.size():
		var seeded_mon: Dictionary = actives[i]
		if not bool(seeded_mon.get("leech_seeded", false)) or int(seeded_mon.get("hp", 0)) <= 0:
			continue
		var slot_base: int = (i / 2) * 2
		var healer_idx: int = slot_base + (0 if str(seeded_mon.get("leech_seed_side", "")) == "player" else 1)
		var healer: Dictionary = {}
		if healer_idx < actives.size() and healer_idx != i:
			healer = actives[healer_idx]
		_apply_leech_seed(seeded_mon, healer, logs)
	# Stakeout ends with the turn, and a mon that fainted to burn
	# or poison changes the fainted-ally count.
	_clear_switched_in_flags()
	_refresh_fallen_allies()
	_tick_field(logs)

## Roll fractional priority (Quick Draw) once per move action and
## store it on the move dict. Only move actions roll; switches and
## items carry priority 6 and no frac_priority. The roll happens
## here, once per turn, so the order is stable for the whole turn.
## The move dict is a fresh copy from _get_move, so writing
## frac_priority on it never pollutes the database.
func _roll_frac_priority(mon: Dictionary, move: Dictionary, action: Dictionary) -> void:
	if str(action.get("type", "move")) != "move":
		return
	move["frac_priority"] = AbilityEngine.frac_priority(mon, move) + ItemEngine.frac_priority(mon, move, rng)


## The move data used to work out turn order. Switches and items go
## before moves (priority 6); running away does not fight.
func _action_move(action: Dictionary, mon: Dictionary = {}) -> Dictionary:
	var atype: String = str(action.get("type", "move"))
	if atype == "move":
		var md: Dictionary = _get_move(str(action.get("move_name", "Tera Blast")))
		md["name"] = str(action.get("move_name", "Tera Blast"))
		if not mon.is_empty():
			var bonus: int = AbilityEngine.priority_bonus(mon, md)
			if bonus != 0:
				md["priority"] = int(md.get("priority", 0)) + bonus
		return md
	if atype == "switch" or atype == "item":
		return {"name": atype, "priority": 6}
	return {"name": atype, "priority": 0}


## The foe's action. The trainer AI picks first; when it gives
## nothing back, PUWSmartAI picks instead.
func _enemy_action(e_mon: Dictionary, p_mon: Dictionary, logs: Array) -> Dictionary:
	if move_db == null:
		move_db = MoveDatabase.new()
		move_db.load_database()
	var action: Dictionary = CompetitiveTrainerAI.choose_action(e_mon, p_mon, enemy_party, move_db, challenge_mode, active_format)
	if not action.is_empty() and action.has("type"):
		return action
	logs.append("The foe's trainer AI gave no action, so the simple AI picks.")
	var smart: PUWSmartAI = PUWSmartAI.new()
	var switch_plan: Dictionary = smart.should_switch(e_mon, enemy_party, 0, p_mon)
	if bool(switch_plan.get("switch", false)):
		var to_idx: int = int(switch_plan.get("to_index", -1))
		if to_idx > 0 and to_idx < enemy_party.size() and int(enemy_party[to_idx].get("hp", 0)) > 0:
			return {"type": "switch", "target_idx": to_idx}
	var move_dicts: Array = []
	for m in e_mon.get("moves", []):
		var md: Dictionary = _get_move(str(m))
		md["name"] = str(m)
		move_dicts.append(md)
	var foe_copy: Dictionary = e_mon.duplicate(true)
	var player_copy: Dictionary = p_mon.duplicate(true)
	foe_copy["types"] = _lower_types(e_mon.get("types", []))
	player_copy["types"] = _lower_types(p_mon.get("types", []))
	var picked: Dictionary = smart.choose_move(move_dicts, foe_copy, player_copy)
	if picked.is_empty():
		var fallback: String = "Tera Blast"
		var emoves: Array = e_mon.get("moves", [])
		if not emoves.is_empty():
			fallback = str(emoves[0])
		return {"type": "move", "move_name": fallback}
	return {"type": "move", "move_name": str(picked.get("name", "Tera Blast"))}

## Do one side's action. Returns {"fainted": bool} and, for a catch
## try, {"capture": {...}}.
func _perform_action(action: Dictionary, is_player: bool, logs: Array) -> Dictionary:
	var out := {"fainted": false}
	var attacker: Dictionary = player_party[0] if is_player else enemy_party[0]
	var defender: Dictionary = enemy_party[0] if is_player else player_party[0]
	# A mon carried up by Sky Drop cannot act at all while it
	# is held in the sky.
	if bool(attacker.get("held_in_sky", false)):
		logs.append(_mon_name(attacker) + " is held in the sky and can't move!")
		return out
	var atype: String = str(action.get("type", "move"))
	match atype:
		"wait":
			pass
		"switch":
			var idx: int = int(action.get("target_idx", -1))
			var party: Array = player_party if is_player else enemy_party
			if idx > 0 and idx < party.size() and int(party[idx].get("hp", 0)) > 0:
				if AbilityEngine.traps_foe(defender, attacker):
					logs.append(_mon_name(defender) + "'s " + str(defender.get("ability", "")) + " stops " + _mon_name(attacker) + " switching out!")
					return out
				logs.append(_mon_name(attacker) + ", come back!")

				var sw_logs: Array = execute_switch(party, idx, defender, is_player)
				party[0]["participated"] = true
				logs.append("Go! " + _mon_name(party[0]) + "!")
				logs.append_array(sw_logs)
				anim_events.append({"kind": "send_out", "side": "player" if is_player else "enemy"})
			else:
				logs.append("That switch is not possible.")
		"item":
			var item_id: String = str(action.get("item_id", ""))
			if is_player and is_wild and ItemEngine.guarantees_escape(item_id):
				# POKE DOLL / FLUFFY TAIL (binding build 4,
				# code_prep_items merge step 3e): using one in a
				# wild battle is a guaranteed escape -- the Smoke
				# Ball pattern in _try_flee, as an item. run_turn
				# reads out["fled"] and ends the battle with
				# status "fled"; bag consumption rides the
				# caller's normal item resolution, as for balls.
				logs.append("Used the " + item_id + "! Got away safely!")
				out["fled"] = true
				return out
			if not is_wild and is_player and item_id.to_lower().ends_with("ball") and str(battle_state.get("snag_arc", "")) != "":
				# SNAG (Orre code prep): in an Orre arc battle a
				# ball thrown at the foe is a snag attempt, not a
				# wild catch. Legality lives in PUWShadowSystem;
				# the throw reuses attempt_capture's math.
				var snag: Dictionary = attempt_snag(item_id, defender, rng)
				logs.append_array(snag.get("logs", []))
				out["capture"] = snag
				anim_events.append({"kind": "ball_throw", "side": "player" if is_player else "enemy", "ball": item_id, "caught": bool(snag.get("caught", false))})
			elif is_wild and item_id.to_lower().ends_with("ball"):
				var cap: Dictionary = attempt_capture(item_id, defender, rng)
				logs.append_array(cap.get("logs", []))
				out["capture"] = cap
				anim_events.append({"kind": "ball_throw", "side": "player" if is_player else "enemy", "ball": item_id, "caught": bool(cap.get("caught", false))})
			else:
				var used: bool = ItemEngine.use_battle_item(item_id, attacker, logs)
				if used:
					AbilityEngine.on_item_use(attacker, item_id, field_state, logs)
					# A Revive brings a mon back: refresh the fainted
					# ally count so Supreme Overlord drops at once.
					_refresh_fallen_allies()
				else:
					logs.append("The " + item_id + " didn't work.")

		"move":
			var gimmick_refused: bool = _gimmick_gate_check(action, is_player, logs)
			if not gimmick_refused:
				_apply_gimmick(action, attacker, logs, is_player)
			var move_name: String = str(action.get("move_name", "Tera Blast"))
			# V5 Bide lock: while Bide is running the user must
			# keep using Bide (Showdown onLockMove). Any other
			# move picked for this turn is replaced.
			if bool(attacker.get("bide_active", false)) and move_name != "Bide":
				move_name = "Bide"
			# An airborne mon must strike with the move it rose
			# with: whatever move was picked is replaced.
			if str(attacker.get("airborne_move", "")) != "":
				move_name = _airborne_move_name(str(attacker.get("airborne_move", "")))

			var override := {}
			if str(action.get("z_crystal", "")) != "" and not gimmick_refused:
				var zres: Dictionary = _apply_z_move(action, move_name, logs, attacker, is_player)
				move_name = str(zres.get("move_name", move_name))
				override = zres.get("override", {})
			anim_events.append({"kind": "move", "side": "player" if is_player else "enemy", "move_id": move_name})
			var res: Dictionary = _execute_move(attacker, defender, move_name, is_player, logs, override)
			out["fainted"] = bool(res.get("fainted", false))
			if bool(res.get("fainted", false)):
				anim_events.append({"kind": "faint", "side": "enemy" if is_player else "player"})
			# Held-item post-move hooks: Throat Spray, the
			# Metronome item's streak, Micle's spent flag.
			ItemEngine.on_after_move(attacker, _get_move(move_name), logs)
			# Eject Pack: a mon whose stats were dropped by the
			# foe during this action switches out now (the
			# flag was raised by ItemEngine.on_stat_dropped at
			# the stat-change choke points).
			_consume_eject_pack(attacker, is_player, _get_move(move_name), logs)
			_consume_eject_pack(defender, not is_player, _get_move(move_name), logs)
		_:
			logs.append("Unknown action.")
	return out

## ------------------------------------------------------------------
## Gimmick budgets (hub register 9.2, RC1 formats doc)
## ------------------------------------------------------------------
## Five independent battle budgets PER SIDE: Mega, Z-Move,
## ordinary Dynamax, Gigantamax, Terastallization. Each category
## may be used at most once per side per battle, and one
## individual Pokemon may use only ONE category per battle (its
## marker, mon["gimmick_category_used"], "" = none yet). Primal
## Reversion and Ultra Burst are NOT budget categories and stay
## unbudgeted. The budgets live in
## battle_state["gimmick_budgets"] = {"player": {...},
## "enemy": {...}} and are reset in start_battle, alongside each
## mon's marker. A refused gimmick only logs a line: the mon's
## move still executes, exactly as a failed gimmick did before.
## A budget is spent ONLY on success, read back from the mon's
## resulting state (mega_evolved / dynamax_active /
## gigantamax_active / tera_active, or a produced Z-Move
## override) — a gimmick the gimmick code itself refused (no
## Mega Stone, wrong species, ...) spends nothing.
## The old whole-battle flags inside gimmicks.gd (mega_used,
## dynamax_used, tera_used) would block the OTHER side's first
## use of a category, so _apply_gimmick clears the matching flag
## right before each budgeted call and lets the per-side budget
## be the only gate. battle_state["z_used"] is kept as a plain
## mirror (set when any Z-Move fires) but no longer gates.

## The budget table for one battle, created on first use so a
## battle_state built before budgets existed still works.
func _gimmick_budgets() -> Dictionary:
	var budgets: Dictionary = battle_state.get("gimmick_budgets", {})
	if not budgets.has("player") or not budgets.has("enemy"):
		budgets = {"player": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}, "enemy": {"mega": false, "zmove": false, "dynamax": false, "gigantamax": false, "tera": false}}
		battle_state["gimmick_budgets"] = budgets
	return budgets

## True when this mon may still spend the given budget category
## for its side. On a refusal a clear line is logged and false
## comes back; the caller then skips the gimmick and the mon's
## move still executes.
func _gimmick_budget_allows(category: String, attacker: Dictionary, is_player: bool, logs: Array) -> bool:
	var side: String = "player" if is_player else "enemy"
	var budgets: Dictionary = _gimmick_budgets()
	var side_budgets: Dictionary = budgets.get(side, {})
	if bool(side_budgets.get(category, false)):
		logs.append(_mon_name(attacker) + " can't use that gimmick: this side already used its " + category + " this battle.")
		return false
	var marker: String = str(attacker.get("gimmick_category_used", ""))
	if marker != "":
		logs.append(_mon_name(attacker) + " can't use that gimmick: it already used its " + marker + " this battle, and one Pokemon gets only one gimmick category per battle.")
		return false
	return true

## Spend one budget category for a side and stamp the mon's
## one-category marker. Called only after a gimmick succeeded.
func _gimmick_budget_spend(category: String, attacker: Dictionary, is_player: bool) -> void:
	var side: String = "player" if is_player else "enemy"
	var budgets: Dictionary = _gimmick_budgets()
	var side_budgets: Dictionary = budgets.get(side, {})
	side_budgets[category] = true
	budgets[side] = side_budgets
	battle_state["gimmick_budgets"] = budgets
	attacker["gimmick_category_used"] = category

## A gimmick on the action ("gimmick": "mega" and so on) happens
## before the move. The gimmick code fails safe when it is not allowed.
func _apply_gimmick(action: Dictionary, attacker: Dictionary, logs: Array, is_player: bool = true) -> void:
	var gimmick: String = str(action.get("gimmick", "")).to_lower()
	match gimmick:
		"mega":
			if not _gimmick_budget_allows("mega", attacker, is_player, logs):
				return
			# The budget is the gate now (see the budget note
			# above): clear the old whole-battle flag so the
			# other side's Mega does not block this one.
			battle_state["mega_used"] = false
			PUWGimmicks.mega_evolve(attacker, logs, battle_state, stage)
			if bool(attacker.get("mega_evolved", false)):
				_gimmick_budget_spend("mega", attacker, is_player)
		"dynamax":
			if not _gimmick_budget_allows("dynamax", attacker, is_player, logs):
				return
			battle_state["dynamax_used"] = false
			PUWGimmicks.dynamax(attacker, logs, battle_state, stage)
			if bool(attacker.get("dynamax_active", false)):
				_gimmick_budget_spend("dynamax", attacker, is_player)
		"gigantamax":
			if not _gimmick_budget_allows("gigantamax", attacker, is_player, logs):
				return
			battle_state["dynamax_used"] = false
			PUWGimmicks.gigantamax(attacker, logs, battle_state, stage)
			if bool(attacker.get("gigantamax_active", false)):
				_gimmick_budget_spend("gigantamax", attacker, is_player)
		"tera":
			if not _gimmick_budget_allows("tera", attacker, is_player, logs):
				return
			battle_state["tera_used"] = false
			var was_tera: bool = bool(attacker.get("tera_active", false))
			PUWGimmicks.terastallize(attacker, str(action.get("tera_type", "Normal")), logs, battle_state, stage)
			if not was_tera and bool(attacker.get("tera_active", false)):
				_gimmick_budget_spend("tera", attacker, is_player)
				logs.append_array(AbilityEngine.on_terastallize(attacker, field_state))

		"primal":
			PUWGimmicks.primal_revert(attacker, logs, battle_state, stage)
		"ultra":
			PUWGimmicks.ultra_burst(attacker, logs, battle_state, stage)
		"":
			pass
		_:
			logs.append("Unknown gimmick: " + gimmick + ".")

## Turn a base move into its Z-Move. Returns the Z-Move name and a
## move-data override (power, always hits). Fails safe to the base
## move when the crystal, the type, or the side's Z-Move budget
## (category "zmove") does not allow it. The budget is spent only
## when the Z-Move override is actually produced.
func _apply_z_move(action: Dictionary, move_name: String, logs: Array, attacker: Dictionary, is_player: bool) -> Dictionary:
	var crystal: String = str(action.get("z_crystal", ""))
	var base: Dictionary = _get_move(move_name)
	var z_name: String = PUWGimmicks.get_z_move(move_name, crystal)
	if z_name == "":
		logs.append("That Z-Move can't be used with " + crystal + ".")
		return {"move_name": move_name, "override": {}}
	var crystal_type: String = PUWGimmicks.z_crystal_type(crystal)
	if crystal_type != "" and str(base.get("type", "")) != crystal_type:
		logs.append("The Z-Crystal doesn't match the move's type.")
		return {"move_name": move_name, "override": {}}
	if not _gimmick_budget_allows("zmove", attacker, is_player, logs):
		return {"move_name": move_name, "override": {}}
	_gimmick_budget_spend("zmove", attacker, is_player)
	# Mirror only: something in the battle used a Z-Move. The
	# per-side budget above is the rule that gates.
	battle_state["z_used"] = true
	var zpower: int = PUWGimmicks.z_power_for_move(move_name, int(base.get("power", 0)))
	var override := {"name": z_name, "power": zpower, "type": base.get("type", "Normal"), "cat": base.get("cat", "Physical"), "acc": 100, "priority": 0}
	logs.append("Z-Power! " + z_name + "!")
	return {"move_name": z_name, "override": override}

## Confusion check, run after can_act_this_turn and before PP is
## taken. Showdown conditions.ts confusion onBeforeMove: the timer
## drops by 1 each attempted move; at 0 the confusion ends and the
## mon acts normally; otherwise a 33% chance to hurt itself with a
## 40-power typeless hit (battle-actions.ts getConfusionDamage:
## level formula with the mon's own Atk vs own Def, random 0.85-1.0,
## minimum 1, no crit, no STAB, no type effectiveness). This engine
## does not apply stat stages in damage, so raw atk/def are used.
## Returns true when the move is cancelled (self-hit or faint).
## A sleeping or flinching mon never reaches this check, so confusion
## does not tick on a turn the mon could not act - an approximation
## against Showdown, where confusion ticks before sleep is checked.
## No PP is lost on a cancelled move.
func _check_confusion(mon: Dictionary, is_player: bool, slot: int, logs: Array) -> bool:
	if not bool(mon.get("confused", false)):
		return false
	var turns: int = int(mon.get("confusion_turns", 2))
	turns -= 1
	if turns <= 0:
		mon["confused"] = false
		mon["confusion_turns"] = 0
		logs.append(_mon_name(mon) + " snapped out of its confusion!")
		return false
	mon["confusion_turns"] = turns
	if rng.randf() < 0.33:
		var level: int = int(mon.get("level", 50))
		var atk: float = float(mon.get("atk", 50))
		var defense: float = maxi(1.0, float(mon.get("def", 50)))
		var step1: int = int(2.0 * float(level) / 5.0 + 2.0)
		var step2: int = int(float(step1) * 40.0 * atk)
		var step3: int = int(float(step2) / defense)
		var damage: int = maxi(1, int(float(step3) / 50.0) + 2)
		damage = maxi(1, int(float(damage) * rng.randf_range(0.85, 1.0)))
		mon["hp"] = maxi(0, int(mon.get("hp", 0)) - damage)
		logs.append(_mon_name(mon) + " hurt itself in its confusion (-" + str(damage) + " HP)!")
		if int(mon.get("hp", 0)) <= 0:
			if active_format == "doubles":
				_handle_faint_slot(is_player, slot, logs, false)
			else:
				_handle_faint(is_player, logs, false)
		return true
	return false


## Take 1 PP for the move. First use fills the mon's PP from the move
## data. Returns false when the move has no PP left.
func _deduct_pp(mon: Dictionary, move: Dictionary, defenders: Array = []) -> bool:

	var mname: String = str(move.get("name", ""))
	var pp_map: Dictionary = mon.get("pp", {})
	if pp_map.is_empty():
		for m in mon.get("moves", []):
			var md: Dictionary = _get_move(str(m))
			pp_map[str(m)] = int(md.get("pp_max", md.get("pp", 15)))
		mon["pp"] = pp_map
	if not pp_map.has(mname):
		pp_map[mname] = int(move.get("pp_max", move.get("pp", 15)))
	var left: int = int(pp_map.get(mname, 0))
	if left <= 0:
		return false
	# Pressure: a foe target with Pressure costs 1 extra PP
	# (Showdown onDeductPP returns 1). The extra is 1 in total,
	# even when two targets have Pressure, and it never applies
	# for an ally target (the caller only passes foe mons). PP
	# never goes below 0, so a move with 1 PP left still works
	# against Pressure and is empty after.
	var extra_pp: int = 0
	for d in defenders:
		if d is Dictionary:
			var dmon: Dictionary = d
			if not dmon.is_empty() and str(dmon.get("ability", "")) == "Pressure":
				extra_pp = 1
				break
	pp_map[mname] = maxi(0, left - 1 - extra_pp)

	mon["pp"] = pp_map
	return true

## V5 Trump Card: the PP left when the move is picked, before
## this use spends 1 PP. Mirrors _deduct_pp's numbers without
## spending anything: the live pp map when it has the move, else
## the move's own pp_max.
func _pp_left(mon: Dictionary, move: Dictionary) -> int:
	var mname: String = str(move.get("name", ""))
	var pp_map: Dictionary = mon.get("pp", {})
	if pp_map.has(mname):
		return int(pp_map.get(mname, 0))
	return int(move.get("pp_max", move.get("pp", 15)))

## V5 Beat Up: one power per able party member, in party order.
## The user always counts, even with a status (Showdown
## moves.ts, beatup onModifyMove: the filter keeps the user, or
## a member that is not fainted and has no status). Each power is
## 5 + that member's base Attack / 10, from the base Attack
## table. A member with no base Attack data counts as 0, which
## gives power 5, and is logged so the gap is visible.
func _beat_up_powers(attacker: Dictionary, party: Array, logs: Array) -> Array:
	var powers: Array = []
	for m in party:
		if m != attacker and (int(m.get("hp", 0)) <= 0 or str(m.get("status", "")) != ""):
			continue
		var atk: int = _base_atk_of(m)
		if atk <= 0:
			logs.append("No base Attack data for " + _mon_name(m) + ".")
		powers.append(VariablePower.beat_up_power(atk))
	return powers

## V5: remember a hit so Counter, Mirror Coat, Metal Burst,
## Comeuppance and Bide can answer it. Call once per move hit,
## after the final damage is known. Only move damage counts:
## end-of-turn ticks (poison, burn, sand) never reach this
## function, so they never feed Counter or Bide.
func _record_damage_taken(attacker: Dictionary, defender: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	defender["last_damage_taken"] = damage
	defender["last_damage_cat"] = str(move.get("cat", move.get("category", "")))
	defender["damaged_this_turn"] = true
	# Bide stores move damage too, and remembers who hit last.
	# A mon never stores its own hits.
	if bool(defender.get("bide_active", false)) and attacker != defender:
		defender["bide_stored"] = int(defender.get("bide_stored", 0)) + damage
		defender["bide_last_attacker"] = attacker

## V5: Ceaseless Edge and Stone Axe set a hazard on the foe's
## side after a hit lands. Showdown sets it in onAfterHit unless
## the attacker has Sheer Force. The hazard shape is the same one
## StatusAndFieldEngine.create_field_state builds: foe hazards
## are field_state["enemy_hazards"] or ["player_hazards"], with
## "spikes" 0-3 and "stealth_rock" true/false. The cap and the
## already-set lines come from MoveEffects.apply_hazard_move.
func _apply_v5_hazard(attacker: Dictionary, move: Dictionary, damage: int, is_player: bool, logs: Array) -> void:
	if damage <= 0:
		return
	var hazard: String = str(move.get("sets_hazard", ""))
	if hazard == "":
		return
	if str(attacker.get("ability", "")) == "Sheer Force":
		return
	var foe_hazards: Dictionary = field_state["enemy_hazards"] if is_player else field_state["player_hazards"]
	if hazard == "spikes":
		MoveEffects.apply_hazard_move("Spikes", foe_hazards, field_state, logs)
	elif hazard == "stealth_rock":
		MoveEffects.apply_hazard_move("Stealth Rock", foe_hazards, field_state, logs)

## V5 Fling and Natural Gift: use up the held item after a hit
## lands. The item name is read before it is cleared, so the log
## can name it. Fling clears the fling power too; Natural Gift
## clears the berry power and type too.
func _consume_v5_item(attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	if str(move.get("damage_rule", "")) != "item":
		return
	var held_name: String = str(attacker.get("item", ""))
	if str(move.get("rule_kind", "")) == "fling":
		attacker["item"] = ""
		attacker["item_fling_power"] = 0
		logs.append(_mon_name(attacker) + " flung its " + held_name + "!")
	else:
		attacker["item"] = ""
		attacker["berry_power"] = 0
		attacker["berry_type"] = ""
		logs.append(_mon_name(attacker) + " used up its " + held_name + "!")

## V5 Fling effects: a few flung items carry an effect in
## fling_table.json (Showdown data/items.ts), and the hit
## applies it to the target. Flame Orb burns, Toxic Orb badly
## poisons, Poison Barb poisons and Light Ball paralyzes (the
## table's "status", applied through AbilityEngine.try_set_status
## so ability blocks and type immunities still count). King's
## Rock and Razor Fang make the target flinch
## ("volatile_status"). White Herb restores the target's
## lowered stat stages ("restores_negative_boosts"). Mental
## Herb clears the volatiles its Showdown effect function
## lists ("clears_volatiles"). Runs after the hit lands and
## before _consume_v5_item clears the held item, and only
## when the target is still standing.
func _apply_fling_effect(attacker: Dictionary, defender: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	if str(move.get("damage_rule", "")) != "item":
		return
	if str(move.get("rule_kind", "")) != "fling":
		return
	if int(defender.get("hp", 0)) <= 0:
		return
	var row: Dictionary = _fling_entry(str(attacker.get("item", "")))
	if row.is_empty():
		return
	var item_name: String = str(row.get("name", "item"))
	var status_id: String = str(row.get("status", ""))
	if status_id != "":
		if AbilityEngine.try_set_status(defender, status_id.to_upper(), attacker, field_state, logs):
			logs.append(_mon_name(defender) + " was hurt by the flung " + item_name + "!")
	if str(row.get("volatile_status", "")) == "flinch":
		defender["flinched"] = true
		logs.append(_mon_name(defender) + " flinched from the flung " + item_name + "!")
	if bool(row.get("restores_negative_boosts", false)):
		var stages: Dictionary = defender.get("stages", {})
		var restored: bool = false
		for stat in stages.keys():
			if int(stages.get(stat, 0)) < 0:
				stages[stat] = 0
				restored = true
		if restored:
			defender["stages"] = stages
			logs.append(_mon_name(defender) + "'s lowered stats were restored by the flung " + item_name + "!")
	var clears: Array = row.get("clears_volatiles", [])
	if not clears.is_empty():
		var volatiles: Dictionary = defender.get("volatiles", {})
		var cleared_any: bool = false
		for raw_name in clears:
			var vname: String = str(raw_name)
			if volatiles.has(vname):
				volatiles.erase(vname)
				cleared_any = true
			if bool(defender.get(vname, false)):
				defender[vname] = false
				cleared_any = true
		if cleared_any:
			defender["volatiles"] = volatiles
			logs.append(_mon_name(defender) + " was cured by the flung " + item_name + "!")

## V5: end Bide on a mon (flinch, sleep, paralysis, confusion
## self-hit, or switching out). Only logs when Bide was running.
func _clear_bide(mon: Dictionary, logs: Array) -> void:
	if not bool(mon.get("bide_active", false)):
		return
	mon["bide_active"] = false
	mon["bide_turns"] = 0
	mon["bide_stored"] = 0
	mon["bide_last_attacker"] = {}
	logs.append(_mon_name(mon) + "'s Bide ended!")

## V5: clear the stored hit a Counter-family move would answer.
## Switching out clears it, like any volatile.
func _clear_counter_store(mon: Dictionary) -> void:
	mon["last_damage_taken"] = 0
	mon["last_damage_cat"] = ""
	mon["damaged_this_turn"] = false

## V5: the Sturdy cap for flat damage. Same rule as
## AbilityEngine.modify_damage: a full-HP Sturdy mon survives a
## hit that would knock it out with 1 HP left. Flat damage skips
## modify_damage (its multipliers must not touch a fixed number),
## so this cap is copied here to keep Sturdy working, including
## against one-hit KO moves.
func _apply_sturdy_cap(attacker: Dictionary, defender: Dictionary, damage: int) -> int:
	if str(defender.get("ability", "")) == "Sturdy" and str(attacker.get("ability", "")) != "Mold Breaker" and int(defender.get("hp", 0)) == int(defender.get("max_hp", 1)) and damage >= int(defender.get("hp", 1)):
		return int(defender.get("hp", 1)) - 1
	return damage


## True when the mon has PP left on at least one of its moves.
func _has_any_pp(mon: Dictionary) -> bool:
	var pp_map: Dictionary = mon.get("pp", {})
	if pp_map.is_empty():
		return true
	for m in mon.get("moves", []):
		if int(pp_map.get(str(m), 0)) > 0:
			return true
	return false

## Struggle: 50 power, typeless, never misses, 1/4 recoil.
## Runs when the attacker has no PP left on any move.
func _execute_struggle(attacker: Dictionary, defender: Dictionary, is_player: bool, logs: Array) -> Dictionary:
	var out: Dictionary = {"damage": 0, "fainted": false, "switch_requested": false}
	var aname: String = _mon_name(attacker)
	var dname: String = _mon_name(defender)
	if bool(attacker.get("flinched", false)):
		# Steadfast fires here, before the flag is cleared. The
		# mon still cannot move this turn.
		AbilityEngine.on_flinch(attacker, logs)
		attacker["flinched"] = false
		logs.append(aname + " flinched and couldn't move!")
		return out
	var can_act: Dictionary = StatusAndFieldEngine.can_act_this_turn(attacker)
	if str(can_act.get("log", "")) != "":
		logs.append(str(can_act.get("log", "")))
	if not bool(can_act.get("can_act", true)):
		return out
	var struggle: Dictionary = {"name": "Struggle", "power": 50, "type": "???", "cat": "Physical", "acc": 100, "priority": 0}
	attacker["field"] = field_state
	defender["field"] = field_state
	# Toxic Debris reads this to put the spikes on the right side.
	attacker["side"] = "player" if is_player else "enemy"
	defender["screens"] = field_state["enemy_screens"] if is_player else field_state["player_screens"]
	var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, struggle, rng)
	var total: int = int(res.get("damage", 0))
	var eff: float = float(res.get("effectiveness", 1.0))
	var was_crit: bool = bool(res.get("critical", false))
	var stab_mult: float = float(res.get("stab", 1.0))
	total = AbilityEngine.modify_damage(attacker, defender, struggle, total, stab_mult > 1.0, was_crit, eff)
	total = ItemEngine.modify_attack_damage(attacker, defender, struggle, total)
	if int(field_state.get("magic_room", 0)) <= 0:
		total = ItemEngine.check_focus_sash(defender, total)
		total = ItemEngine.check_focus_band(defender, total, rng, logs)
	if str(defender.get("item_consumed", "")) == "Focus Sash":
		logs.append(dname + " held on with its Focus Sash!")
		defender["item_consumed"] = ""
	logs.append(aname + " used Struggle!")
	defender["hp"] = maxi(0, int(defender.get("hp", 0)) - total)
	if not AbilityEngine.blocks_indirect_damage(attacker):
		ItemEngine.apply_recoil_after_attack(attacker, total, logs)
	ItemEngine.on_damage_taken(defender, struggle, logs, attacker, total, field_state)
	AbilityEngine.on_damage_taken(defender, attacker, struggle, total, logs)
	ItemEngine.apply_shell_bell_after_attack(attacker, total, logs)
	logs.append("It did " + str(total) + " damage to " + dname + ".")
	if was_crit:
		logs.append("A critical hit!")
	out["damage"] = total
	if total > 0 and int(attacker.get("hp", 0)) > 0:
		var recoil: int = maxi(1, total / 4)
		attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - recoil)
		logs.append(aname + " was hurt by recoil (-" + str(recoil) + " HP)!")
	if int(defender.get("hp", 0)) <= 0:
		out["fainted"] = true
		_handle_faint(not is_player, logs, true)
	if int(attacker.get("hp", 0)) <= 0:
		_handle_faint(is_player, logs, false)
		out["fainted"] = true
	# Wimp Out / Emergency Exit: after the fainting is sorted, a
	# mon that dropped to half HP or less switches out.
	_maybe_ability_switch(not is_player, logs)
	_maybe_ability_switch(is_player, logs)
	return out

## V5: work out the real power or flat damage for a move whose
## power is 0 in the data but which still hits. Reads
## move["damage_rule"] and calls the matching VariablePower
## formula. Returns a small dict with a "kind" key:
## - {"kind": "none"}: no damage_rule, use the move as written.
## - {"kind": "power", "power": N}: use N as the move power in
##   the normal damage formula.
## - {"kind": "beat_up", "powers": [...], "hits": N}: one hit per
##   able party member; each hit uses powers[i] in party order.
## - {"kind": "flat", "damage": N}: deal N HP as-is, no formula.
## - {"kind": "heal", "amount": N}: Present heal branch.
## - {"kind": "fail", "reason": "..."}: the move fails. The
##   caller logs the reason and deals no damage. PP is already
##   spent, which matches the games.
## Bide never reaches this function: both execute functions send
## it to _execute_bide first. The "bide" arm below is only a
## safety net in case a future caller forgets.
## party is the attacker's whole party (bench included). It is
## only used by Beat Up.
func _resolve_variable_power(move: Dictionary, attacker: Dictionary, defender: Dictionary, logs: Array, party: Array = []) -> Dictionary:
	var rule: String = str(move.get("damage_rule", ""))
	if rule == "":
		return {"kind": "none"}
	if rule == "unknown":
		return {"kind": "fail", "reason": "It failed! The move has no damage rule in the data."}
	if rule == "bide":
		return {"kind": "fail", "reason": "It failed! Bide must go through _execute_bide."}
	var atk_level: int = int(attacker.get("level", 5))
	var def_level: int = int(defender.get("level", 5))
	var atk_hp: int = int(attacker.get("hp", 0))
	var atk_max_hp: int = int(attacker.get("max_hp", 100))
	var def_hp: int = int(defender.get("hp", 0))
	var def_max_hp: int = int(defender.get("max_hp", 100))
	match rule:
		"weight":
			var w: int = _weight_of(defender)
			if w <= 0:
				logs.append("No weight data for " + _mon_name(defender) + ".")
			return {"kind": "power", "power": VariablePower.weight_power(w)}
		"weight_ratio":
			var uw: int = _weight_of(attacker)
			var tw: int = _weight_of(defender)
			if uw <= 0:
				logs.append("No weight data for " + _mon_name(attacker) + ".")
			if tw <= 0:
				logs.append("No weight data for " + _mon_name(defender) + ".")
			return {"kind": "power", "power": VariablePower.weight_ratio_power(uw, tw)}
		"gyro_ball":
			return {"kind": "power", "power": VariablePower.gyro_ball_power(int(attacker.get("spe", 0)), int(defender.get("spe", 0)))}
		"electro_ball":
			return {"kind": "power", "power": VariablePower.electro_ball_power(int(attacker.get("spe", 0)), int(defender.get("spe", 0)))}
		"low_hp":
			return {"kind": "power", "power": VariablePower.flail_power(atk_hp, atk_max_hp)}
		"target_hp":
			return {"kind": "power", "power": VariablePower.crush_grip_power(def_hp, def_max_hp, int(move.get("rule_scale", 120)))}
		"fixed":
			var fixed: int = int(move.get("rule_amount", 0))
			if fixed <= 0:
				return {"kind": "fail", "reason": "It failed! The move has no damage amount in the data."}
			return {"kind": "flat", "damage": fixed}
		"level":
			return {"kind": "flat", "damage": VariablePower.level_damage(atk_level)}
		"fraction":
			return {"kind": "flat", "damage": VariablePower.fraction_damage(def_hp, int(move.get("rule_num", 1)), int(move.get("rule_den", 2)))}
		"ohko":
			if atk_level < def_level:
				return {"kind": "fail", "reason": "It failed! The foe is a higher level."}
			return {"kind": "flat", "damage": VariablePower.ohko_damage(def_max_hp)}
		"counter":
			var cat: String = str(move.get("rule_category", "any"))
			var was: bool = false
			if cat == "any":
				was = bool(attacker.get("damaged_this_turn", false))
			else:
				was = str(attacker.get("last_damage_cat", "")) == cat
			var c_damage: int = VariablePower.counter_damage(int(attacker.get("last_damage_taken", 0)), int(move.get("rule_mult_num", 2)), int(move.get("rule_mult_den", 1)), was)
			if c_damage <= 0:
				return {"kind": "fail", "reason": "It failed! No hit was stored to strike back with."}
			return {"kind": "flat", "damage": c_damage}
		"friendship":
			# 70 is the standard base friendship in the games.
			var happy: int = int(attacker.get("happiness", 70))
			if str(move.get("rule_kind", "return")) == "frustration":
				return {"kind": "power", "power": VariablePower.frustration_power(happy)}
			return {"kind": "power", "power": VariablePower.friendship_power(happy)}
		"item":
			if str(move.get("rule_kind", "fling")) == "fling":
				# The power comes from the held item's row in
				# fling_table.json (Showdown data/items.ts).
				# A caller that pre-set item_fling_power still
				# works when the table has no row for the item.
				var fling_row: Dictionary = _fling_entry(str(attacker.get("item", "")))
				var fling_p: int = int(fling_row.get("base_power", 0))
				if fling_p <= 0:
					fling_p = VariablePower.fling_power(int(attacker.get("item_fling_power", 0)))
				if fling_p <= 0:
					return {"kind": "fail", "reason": "It failed! There is no item to fling."}
				return {"kind": "power", "power": fling_p}
			# Natural Gift: power and type come from the held
			# berry's row in natural_gift_table.json, with the
			# caller-filled berry_power / berry_type as the
			# fallback when the table has no row.
			var gift_row: Dictionary = _natural_gift_entry(str(attacker.get("item", "")))
			var berry_p: int = int(gift_row.get("base_power", 0))
			var berry_t: String = str(gift_row.get("type", ""))
			if berry_p <= 0:
				berry_p = VariablePower.natural_gift_power(int(attacker.get("berry_power", 0)))
			if berry_t == "":
				berry_t = str(attacker.get("berry_type", ""))
			if berry_p <= 0 or berry_t == "":
				return {"kind": "fail", "reason": "It failed! There is no berry to use."}
			move["type"] = VariablePower.natural_gift_type(berry_t)
			return {"kind": "power", "power": berry_p}
		"endeavor":
			if atk_hp >= def_hp:
				return {"kind": "fail", "reason": "It failed! The user's HP is not lower than the target's."}
			return {"kind": "flat", "damage": VariablePower.endeavor_damage(def_hp, atk_hp)}
		"final_gambit":
			return {"kind": "flat", "damage": VariablePower.final_gambit_damage(atk_hp)}
		"magnitude":
			var mroll: int = int(move.get("v5_roll", -1))
			if mroll < 0:
				mroll = rng.randi_range(0, 99)
				move["v5_roll"] = mroll
				logs.append("Magnitude " + str(VariablePower.magnitude_number(mroll)) + "!")
			return {"kind": "power", "power": VariablePower.magnitude_power(mroll)}
		"present":
			var proll: int = int(move.get("v5_roll", -1))
			if proll < 0:
				proll = rng.randi_range(0, 9)
				move["v5_roll"] = proll
			if VariablePower.present_heals(proll):
				return {"kind": "heal", "amount": VariablePower.present_heal_amount(def_max_hp)}
			return {"kind": "power", "power": VariablePower.present_power(proll)}
		"psywave":
			return {"kind": "flat", "damage": VariablePower.psywave_damage(atk_level, rng.randi_range(50, 150))}
		"spit_up":
			var layers: int = int(attacker.get("stockpile_layers", 0))
			if layers <= 0:
				return {"kind": "fail", "reason": "It failed! There is no Stockpile to spit up."}
			return {"kind": "power", "power": VariablePower.spit_up_power(layers)}
		"trump_card":
			var pp_left: int = int(move.get("pp_left_at_pick", move.get("pp_max", move.get("pp", 5))))
			return {"kind": "power", "power": VariablePower.trump_card_power(pp_left)}
		"beat_up":
			var powers: Array = _beat_up_powers(attacker, party, logs)
			if powers.is_empty():
				return {"kind": "fail", "reason": "It failed! No party member can hit."}
			return {"kind": "beat_up", "powers": powers, "hits": powers.size()}
		"punishment":
			var stages: Dictionary = defender.get("stages", {})
			var pos: int = 0
			for k in stages.keys():
				var v: int = int(stages[k])
				if v > 0:
					pos += v
			return {"kind": "power", "power": VariablePower.punishment_power(pos)}
		_:
			return {"kind": "none"}

## V5 Bide: the whole Bide state machine in one place, used by
## both _execute_move and _execute_move_doubles. Showdown
## moves.ts, bide condition, checked live 2026-11-22:
## duration 3, locked into Bide, damage taken from moves is
## stored with the last attacker, and on the turn the count runs
## out the user hits that attacker for twice the stored damage.
## The unleash ignores type immunity (ignoreImmunity: true).
## Turn count here: the first use sets bide_turns = 2, two wait
## turns after the first use, the same as duration 3. Each wait
## turn takes 1 off; at 0 the stored damage unleashes. Nothing
## stored, or no last attacker, means the move fails. If the last
## attacker is no longer a living foe, the first living foe is
## hit instead (Showdown picks a random opposing mon; this
## engine picks the first living one, so the result is stable).
## is_doubles picks the faint handler: _handle_faint for singles
## (party[0]) and _handle_faint_slot for doubles.
func _execute_bide(attacker: Dictionary, move: Dictionary, is_player: bool, logs: Array, is_doubles: bool = false) -> Dictionary:
	var out: Dictionary = {"damage": 0, "fainted": false, "switch_requested": false}
	var aname: String = _mon_name(attacker)
	if not bool(attacker.get("bide_active", false)):
		attacker["bide_active"] = true
		attacker["bide_turns"] = 2
		attacker["bide_stored"] = 0
		attacker["bide_last_attacker"] = {}
		logs.append(aname + " used Bide!")
		logs.append(aname + " is biding its time!")
		return out
	var turns: int = int(attacker.get("bide_turns", 0)) - 1
	attacker["bide_turns"] = turns
	if turns > 0:
		logs.append(aname + " is biding its time!")
		return out
	var stored: int = int(attacker.get("bide_stored", 0))
	var last: Dictionary = attacker.get("bide_last_attacker", {})
	attacker["bide_active"] = false
	attacker["bide_turns"] = 0
	attacker["bide_stored"] = 0
	attacker["bide_last_attacker"] = {}
	if stored <= 0 or last.is_empty():
		logs.append(aname + " used Bide, but it failed!")
		return out
	var foe_party: Array = enemy_party if is_player else player_party
	var target: Dictionary = {}
	if int(last.get("hp", 0)) > 0 and foe_party.has(last):
		target = last
	if target.is_empty():
		for mon in foe_party:
			if int(mon.get("hp", 0)) > 0:
				target = mon
				break
	if target.is_empty():
		logs.append(aname + " used Bide, but there was no target!")
		return out
	var damage: int = VariablePower.bide_damage(stored)
	damage = _apply_sturdy_cap(attacker, target, damage)
	if int(field_state.get("magic_room", 0)) <= 0:
		damage = ItemEngine.check_focus_sash(target, damage)
		damage = ItemEngine.check_focus_band(target, damage, rng, logs)
	if str(target.get("item_consumed", "")) == "Focus Sash":
		logs.append(_mon_name(target) + " held on with its Focus Sash!")
		target["item_consumed"] = ""
	logs.append(aname + " unleashed Bide!")
	target["hp"] = maxi(0, int(target.get("hp", 0)) - damage)
	_record_damage_taken(attacker, target, move, damage, logs)
	ItemEngine.on_damage_taken(target, move, logs, attacker, damage, field_state)
	AbilityEngine.on_damage_taken(target, attacker, move, damage, logs)
	ItemEngine.apply_shell_bell_after_attack(attacker, damage, logs)
	logs.append("It did " + str(damage) + " damage to " + _mon_name(target) + ".")
	out["damage"] = damage
	if int(target.get("hp", 0)) <= 0:
		out["fainted"] = true
		var target_slot: int = foe_party.find(target)
		if is_doubles:
			_handle_faint_slot(not is_player, target_slot, logs)
		else:
			_handle_faint(not is_player, logs)
	return out


## One attack: flinch, sleep/freeze/paralysis, PP, accuracy, immunity,
## damage (abilities, items, Focus Sash), after-effects, fainting.
func _execute_move(attacker: Dictionary, defender: Dictionary, move_name: String, is_player: bool, logs: Array, override: Dictionary = {}, is_dancer_copy: bool = false) -> Dictionary:
	var out := {"damage": 0, "fainted": false, "switch_requested": false}
	var move: Dictionary = _get_move(move_name)
	for k in override.keys():
		move[k] = override[k]
	move["name"] = move_name
	var max_powers: Dictionary = attacker.get("max_move_powers", {})
	if max_powers.has(move_name):
		move["power"] = int(max_powers[move_name])
	var aname: String = _mon_name(attacker)
	var dname: String = _mon_name(defender)
	# Airborne moves (Fly, Bounce, Sky Drop): when the attacker
	# is already up in the air with this same move, this use is
	# the strike turn, and it costs no PP a second time.
	var airborne_id: String = _airborne_move_id(move_name)
	var is_airborne_strike: bool = airborne_id != "" and str(attacker.get("airborne_move", "")) == airborne_id
	var held: String = str(attacker.get("item", ""))
	if not is_dancer_copy and held != "" and ItemEngine.is_choice_item(held):
		var locked: String = ItemEngine.choice_locked_move(attacker)
		if locked != "" and locked != move_name:
			logs.append(aname + " is locked into " + locked + " by its Choice item!")
			return _execute_move(attacker, defender, locked, is_player, logs, {})
	if bool(attacker.get("flinched", false)):
		# Steadfast fires here, before the flag is cleared. The
		# mon still cannot move this turn.
		AbilityEngine.on_flinch(attacker, logs)
		attacker["flinched"] = false
		logs.append(aname + " flinched and couldn't move!")
		# V5: being stopped from moving ends Bide (Showdown
		# onMoveAborted removes the volatile).
		_clear_bide(attacker, logs)
		return out
	var can_act: Dictionary = StatusAndFieldEngine.can_act_this_turn(attacker)
	if str(can_act.get("log", "")) != "":
		logs.append(str(can_act.get("log", "")))
	if not bool(can_act.get("can_act", true)):
		_clear_bide(attacker, logs)
		return out
	# Confusion is checked after sleep/freeze/paralysis and before
	# PP is taken, so a confused self-hit costs no PP.
	if _check_confusion(attacker, is_player, 0, logs):
		_clear_bide(attacker, logs)
		return out

	# V5 Trump Card: PP left is counted when the move is picked,
	# before this use spends 1 PP. Capture it now; _deduct_pp
	# below spends the PP. The resolver reads pp_left_at_pick.
	if str(move.get("damage_rule", "")) == "trump_card":
		move["pp_left_at_pick"] = _pp_left(attacker, move)
	if not is_dancer_copy and not is_airborne_strike and not _deduct_pp(attacker, move, [defender]):
		if not _has_any_pp(attacker):
			return _execute_struggle(attacker, defender, is_player, logs)
		logs.append(aname + " has no PP left for " + move_name + "!")
		return out


	# Gravity disables the flying and jumping moves outright:
	# while it is up, the move fails before anything else runs.
	if int(field_state.get("gravity", 0)) > 0 and _gravity_disabled(move):
		logs.append(aname + " used " + move_name + "!")
		logs.append("Gravity prevents " + move_name + "!")
		return out
	# Airborne moves, first use and strike turn. The strike
	# turn clears the airborne state first, then the move runs
	# normally below. The first use deals no damage: the user
	# rises (Sky Drop takes the target up with it), and PP was
	# already spent above, as usual.
	if is_airborne_strike:
		_clear_airborne(attacker)
	elif airborne_id != "":
		attacker["airborne_move"] = airborne_id
		logs.append(aname + " used " + move_name + "!")
		if airborne_id == "fly":
			logs.append(aname + " flew up high!")
		elif airborne_id == "bounce":
			logs.append(aname + " sprang up!")
		else:
			defender["held_in_sky"] = true
			attacker["skydrop_target"] = defender
			logs.append(aname + " took " + dname + " up into the sky!")
		return out
	# Ability type change first (Aerilate, Pixilate and the rest):
	# the new type is what Protean reads below and what the damage
	# step uses for STAB and effectiveness. move_type also marks
	# the move with "type_changed_by" so power_mult can see it.
	var new_type: String = AbilityEngine.move_type(attacker, move, field_state)
	if new_type != "":
		move["type"] = new_type
	# Before-move hooks (Protean / Libero, Truant, Dazzling,
	# Queenly Majesty, Magic Bounce and the rest). A "bounced"
	# move is used against its own user instead; any other "skip"
	# stops the move. The batch arm already logged why, so no
	# extra line is added here. PP was already spent above, which
	# matches the games: a blocked move still costs PP.
	var hooked: Dictionary = AbilityEngine.on_before_move(attacker, defender, move, field_state, logs)
	if bool(hooked.get("bounced", false)):
		logs.append(aname + " used " + move_name + "!")
		_apply_status_move(defender, attacker, move, not is_player, logs)
		return out
	if bool(hooked.get("skip", false)):
		return out
	# V5 Bide: Bide never runs the normal damage path. It sets up,
	# waits, or unleashes through _execute_bide.
	if str(move.get("damage_rule", "")) == "bide":
		return _execute_bide(attacker, move, is_player, logs)
	# V5: work out the real power or flat damage first. A move
	# with a damage_rule has power 0 in the data but still hits,
	# so this must run BEFORE the power <= 0 status check below.
	# The resolver also fails moves with no setup (Counter with
	# no stored hit, Spit Up with no Stockpile, and the rest).
	# party is the attacker's whole party, bench included: Beat
	# Up counts the whole party, not just the active mon.
	var v5_party: Array = player_party if is_player else enemy_party
	var v5: Dictionary = _resolve_variable_power(move, attacker, defender, logs, v5_party)
	var v5_kind: String = str(v5.get("kind", "none"))
	if v5_kind == "fail":
		logs.append(aname + " used " + move_name + "!")
		logs.append(str(v5.get("reason", "It failed!")))
		return out
	if v5_kind == "power":
		move["power"] = int(v5.get("power", 0))
	if v5_kind == "beat_up":
		move["multihit"] = int(v5.get("hits", 0))
		move["beat_up_powers"] = v5.get("powers", [])
	var v5_flat: int = 0
	var v5_is_flat: bool = v5_kind == "flat"
	if v5_is_flat:
		v5_flat = int(v5.get("damage", 0))
	var v5_heal: int = 0
	if v5_kind == "heal":
		v5_heal = int(v5.get("amount", 0))
	var acc = move.get("acc", move.get("accuracy", 100))
	# V5 always_hits: no accuracy roll at all, so accuracy drops
	# and evasion rises cannot touch these moves. (acc 100 already
	# never misses on a plain roll, but the roll is skipped
	# entirely here.)
	# V5 one-hit KO: accuracy is 30 + user level - foe level.
	# The level fail (user level lower than foe level) was
	# already checked by the resolver above.
	var v5_always_hits: bool = bool(move.get("always_hits", false))
	if v5_always_hits:
		acc = 100
	elif str(move.get("damage_rule", "")) == "ohko":
		acc = 30 + int(attacker.get("level", 5)) - int(defender.get("level", 5))
	var acc_mult: float = AbilityEngine.accuracy_mult(attacker, defender, move, field_state)
	acc_mult *= ItemEngine.accuracy_multiplier(attacker)
	if acc != null and acc_mult != 1.0 and not v5_always_hits:
		acc = int(float(acc) * acc_mult)
	# Gravity: while it is up, every move's accuracy is
	# multiplied by 5/3 (Showdown's Gravity accuracy boost).
	if acc != null and not v5_always_hits and int(field_state.get("gravity", 0)) > 0:
		acc = int(float(acc) * 5.0 / 3.0)
	if not v5_always_hits and acc != null and int(acc) < 100:
		if rng.randf() * 100.0 >= float(acc):
			logs.append(aname + " used " + move_name + ", but it missed!")
			ItemEngine.on_move_missed(attacker, logs)
			return out


	var power: int = int(move.get("power", 0))
	var cat: String = str(move.get("cat", move.get("category", "")))
	var mtype: String = str(move.get("type", "Normal"))
	# V5 Present heal: the roll already picked heal, and the
	# accuracy roll above already passed. Heal the TARGET for
	# 1/4 of its max HP, then stop. No damage, no Dancer copy.
	if v5_kind == "heal":
		logs.append(aname + " used " + move_name + "!")
		var heal_max: int = int(defender.get("max_hp", 100))
		var healed: int = mini(v5_heal, heal_max - int(defender.get("hp", 0)))
		defender["hp"] = int(defender.get("hp", 0)) + healed
		logs.append(_mon_name(defender) + " restored " + str(healed) + " HP from the Present!")
		return out
	# V5: only a move with NO damage_rule takes the status path
	# when its power is 0. A damage_rule move with power 0 in the
	# data is a damaging move, and the resolver already worked
	# out its real power or flat damage.
	if v5_kind == "none" and (power <= 0 or cat.to_lower() == "status"):
		logs.append(aname + " used " + move_name + "!")
		if _is_drag_out(move):
			_handle_forced_switch(not is_player, move, logs)

		else:
			_apply_status_move(attacker, defender, move, is_player, logs)
		if not is_dancer_copy:
			var foe_side: String = "enemy" if is_player else "player"
			_dancer_copy(attacker, is_player, 0, [{"side": foe_side, "slot": 0}], move_name, logs)
		return out
	# Semi-invulnerability: a target up in the air (Fly, Bounce
	# or Sky Drop, or carried by Sky Drop) cannot be hit, except
	# by Gust, Twister, Thunder, Hurricane, Sky Uppercut and
	# Smack Down, or when either mon has No Guard. Gust and
	# Twister deal double power to an airborne target, and a
	# hit by Smack Down brings the target down.
	if _is_airborne(defender):
		var hit_move_id: String = move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "")
		var no_guard: bool = str(attacker.get("ability", "")) == "No Guard" or str(defender.get("ability", "")) == "No Guard"
		if not no_guard and not (hit_move_id in AIRBORNE_HIT_IDS):
			logs.append(aname + " used " + move_name + "!")
			logs.append(dname + " is in the air and avoided the attack!")
			return out
		if hit_move_id == "smackdown":
			_clear_airborne(defender)
			logs.append(dname + " was brought down by Smack Down!")
		elif hit_move_id == "gust" or hit_move_id == "twister":
			move["power"] = int(move.get("power", 0)) * 2
	# Protect blocks the move after the accuracy roll: no
	# damage, no secondary, no status, no stat change. A
	# contact move from a Piercing Drill or Unseen Fist holder
	# carries ignores_protect and hits normally.
	if _is_blocked_by_protect(defender, move):
		logs.append(aname + " used " + move_name + "!")
		logs.append(dname + " protected itself!")
		return out
	if AbilityEngine.is_immune_by_ability(defender, mtype, str(attacker.get("ability", "")), 1.0, move):
		logs.append(aname + " used " + move_name + "!")
		logs.append("It doesn't affect " + dname + "!")
		return out


	# Knock Off hits 1.5x harder when the target holds an item and
	# Sticky Hold does not block the take (Showdown onBasePower).
	# 65 becomes 97 (int(65 * 1.5) = 97). The move dict is a fresh
	# copy, so writing power here never pollutes the database.
	if _is_knock_off(move) and str(defender.get("item", "")) != "" and not AbilityEngine.blocks_take_item(defender, attacker, move):
		move["power"] = int(float(int(move.get("power", 0))) * 1.5)
	var hits: int = MoveEffects.get_hit_count(move, rng, attacker)
	var total: int = 0
	var eff: float = 1.0
	var was_crit: bool = false
	var stab_mult: float = 1.0
	if v5_is_flat:
		# V5 flat damage: no formula, no per-hit loop. The number
		# is dealt as-is after accuracy. Type immunity still
		# applies, checked by the eff test below, so Night Shade
		# still fails against a Normal type and Fissure still
		# fails against a Flying type.
		total = v5_flat
		var def_types: PackedStringArray = PackedStringArray()
		for t in defender.get("types", []):
			def_types.append(str(t))
		eff = PUWBattleEngine.type_multiplier(mtype, def_types)
	else:
		for i in range(hits):
			# V5 Beat Up: each hit uses the power of the party
			# member that hit belongs to, not one shared power.
			# The powers list is in party order, and the hit
			# count is the able party members (Patch A).
			if v5_kind == "beat_up":
				var beat_powers: Array = move.get("beat_up_powers", [])
				if i < beat_powers.size():
					move["power"] = int(beat_powers[i])
			attacker["field"] = field_state
			defender["field"] = field_state
			# Toxic Debris reads this to put the spikes on the right side.
			attacker["side"] = "player" if is_player else "enemy"
			defender["screens"] = field_state["enemy_screens"] if is_player else field_state["player_screens"]
			var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, move, rng)
			eff = float(res.get("effectiveness", 1.0))
			was_crit = bool(res.get("critical", false))
			stab_mult = float(res.get("stab", 1.0))
			# Parental Bond: the second hit deals 1/4 damage
			# (Showdown BattleActions modifyDamage). The mark is
			# move["multihit_type"] == "parentalbond", set by the
			# before_move arm, so real 2-hit moves are not quartered.
			var hit_dmg: int = int(res.get("damage", 0))
			if str(move.get("multihit_type", "")) == "parentalbond" and i == 1:
				hit_dmg = maxi(1, hit_dmg / 4)
			total += hit_dmg

	if eff <= 0.0:
		logs.append(aname + " used " + move_name + "!")
		logs.append("It doesn't affect " + dname + "!")
		return out

	var is_stab: bool = stab_mult > 1.0
	if not v5_is_flat:
		var pmult: float = AbilityEngine.power_mult(attacker, defender, move, field_state)
		if pmult != 1.0:
			total = maxi(1, int(float(total) * pmult))
		total = ItemEngine.check_weaken_berry(defender, move, eff, total, logs, field_state)
		total = AbilityEngine.modify_damage(attacker, defender, move, total, is_stab, was_crit, eff)
		total = ItemEngine.modify_attack_damage(attacker, defender, move, total)
		if bool(battle_state.get("spread_damage", false)) and DoublesTargeting.is_spread(move):

			total = int(float(total) * 0.75)
			logs.append("Spread damage was reduced to 0.75x.")
	else:
		# V5 flat damage skips the formula modifiers above: a
		# fixed number ignores power, ability and item damage
		# boosts. Sturdy still saves a full-HP mon, through the
		# one shared cap helper. Focus Sash still runs, on the
		# line below, like every other hit.
		total = _apply_sturdy_cap(attacker, defender, total)
	if int(field_state.get("magic_room", 0)) <= 0:
		total = ItemEngine.check_focus_sash(defender, total)
		total = ItemEngine.check_focus_band(defender, total, rng, logs)

	if str(defender.get("item_consumed", "")) == "Focus Sash":
		logs.append(dname + " held on with its Focus Sash!")
		defender["item_consumed"] = ""
	defender["last_effectiveness"] = eff
	logs.append(aname + " used " + move_name + "!")
	# After-effects run before the damage is taken off, because they
	# work out fainting from the HP before this hit. The move copy
	# carries the rolled hit count so the "hit N times" line matches.
	var move_for_effects: Dictionary = move.duplicate()
	move_for_effects["multihit"] = hits
	var after: Dictionary = MoveEffects.apply_after_hit(attacker, defender, move_for_effects, total, field_state, rng, logs)
	defender["hp"] = maxi(0, int(defender.get("hp", 0)) - total)
	# V5: remember this hit for Counter and for Bide, set the
	# foe-side hazard, and use up Fling, Natural Gift and Spit Up.
	_record_damage_taken(attacker, defender, move, total, logs)
	_apply_v5_hazard(attacker, move, total, is_player, logs)
	_apply_fling_effect(attacker, defender, move, total, logs)
	_consume_v5_item(attacker, move, total, logs)
	# Red Card: the defender stayed standing after a damaging
	# hit, so the card fires and the attacker is dragged out.
	# A wild attacker simply flees (the games' Red Card rule);
	# a trainer's mon goes through the shared drag-out path,
	# where Commander and Suction Cups can refuse it.
	if total > 0 and int(field_state.get("magic_room", 0)) <= 0 and ItemEngine.check_red_card(defender):
		if is_wild and not is_player:
			battle_state["wild_fled"] = true
			logs.append("The wild " + _mon_name(attacker) + " fled from the Red Card!")
		else:
			logs.append(_mon_name(attacker) + " was dragged out by the Red Card!")
			_handle_forced_switch(is_player, move, logs)
	# Eject Button, the Red Card's mirror: the HOLDER switches
	# out after being hit (the defender's side is the attacker's
	# opposite in singles).
	if total > 0 and int(field_state.get("magic_room", 0)) <= 0 and ItemEngine.check_eject_button(defender):
		logs.append(_mon_name(defender) + " was switched out by its Eject Button!")
		_handle_forced_switch(not is_player, move, logs)
	if str(move.get("damage_rule", "")) == "spit_up" and total > 0:
		attacker["stockpile_layers"] = 0
		logs.append(_mon_name(attacker) + " used up its Stockpile!")
	if str(move.get("damage_rule", "")) == "final_gambit" and total > 0 and int(attacker.get("hp", 0)) > 0:
		# Final Gambit faints the user after dealing its damage.
		# Only the HP is set here: the faint itself is handled by
		# the existing check at the end of this function, so the
		# "fainted!" line and EXP are said once, not twice.
		attacker["hp"] = 0
		logs.append(_mon_name(attacker) + " fainted from Final Gambit!")
	# V5: a Counter-family hit that lands uses up the stored hit.
	if str(move.get("damage_rule", "")) == "counter" and total > 0:
		attacker["last_damage_taken"] = 0
		attacker["last_damage_cat"] = ""
	if not AbilityEngine.blocks_indirect_damage(attacker):
		ItemEngine.apply_recoil_after_attack(attacker, total, logs)
	ItemEngine.on_damage_taken(defender, move, logs, attacker, total, field_state)
	AbilityEngine.on_damage_taken(defender, attacker, move, total, logs)
	ItemEngine.apply_shell_bell_after_attack(attacker, total, logs)

	logs.append("It did " + str(total) + " damage to " + dname + ".")
	if eff > 1.0:
		logs.append("It's super effective!")
	elif eff < 1.0:
		logs.append("It's not very effective...")
	if was_crit:
		logs.append("A critical hit!")
	_apply_form_change(defender, logs)
	_apply_form_change(attacker, logs)
	out["damage"] = total

	out["switch_requested"] = bool(after.get("switch_requested", false))
	var fainted: bool = int(defender.get("hp", 0)) <= 0 or bool(after.get("fainted", false))
	out["fainted"] = fainted
	# Knock Off removes the target's item after the hit (Showdown
	# onAfterHit takeItem). Sticky Hold blocks it; the log prints
	# in _try_take_item.
	if _is_knock_off(move) and total > 0:
		_try_take_item(defender, attacker, move, logs)
	if fainted:
		_handle_faint(not is_player, logs, true)
	elif _is_drag_out(move):
		_handle_forced_switch(not is_player, move, logs)
	elif bool(after.get("switch_requested", false)):
		_handle_pivot(is_player, logs)
	if int(attacker.get("hp", 0)) <= 0:
		_handle_faint(is_player, logs, false)
		out["fainted"] = true
	# Wimp Out / Emergency Exit: after the fainting is sorted, a
	# mon that dropped to half HP or less switches out.
	_maybe_ability_switch(not is_player, logs)
	_maybe_ability_switch(is_player, logs)
	if not is_dancer_copy and int(out.get("damage", 0)) > 0:
		var foe_side2: String = "enemy" if is_player else "player"
		_dancer_copy(attacker, is_player, 0, [{"side": foe_side2, "slot": 0}], move_name, logs)
	return out

## True when the move is Knock Off (removes_item flag in RC1 data,
## or the name in either data style). Knock Off gets 1.5x power
## when the target holds an item (Showdown onBasePower) and then
## removes the item (onAfterHit takeItem).
static func _is_knock_off(move: Dictionary) -> bool:
	if bool(move.get("removes_item", false)):
		return true
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	return move_id == "knockoff"


## True when the move is Protect. Checked by name, the way
## _is_knock_off does it: the v5 move data for Protect has no
## protect marker at all (no volatileStatus, no flags, no
## target key), and the RC1 data marks only Protect with a
## "protect": true key, which the v5 data does not keep. The
## name is the one check that works in both data sets. The
## volatileStatus check covers a future loader that keeps it.
## Detect counts too: in Showdown's data/moves.ts, Detect's
## volatileStatus is "protect", the very same condition as
## Protect, so the two moves protect in exactly the same way.
static func _is_protect(move: Dictionary) -> bool:
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if move_id == "protect" or move_id == "detect":
		return true
	return str(move.get("volatileStatus", "")).to_lower() == "protect"

## True when the defender is protected this turn and this move
## does not bypass protection. The bypass is the
## move["ignores_protect"] flag set in before_move by Unseen
## Fist (batch 4) and Piercing Drill (batch 3) on contact moves
## only. This check does not look at the attacker's ability
## itself: the flag is the one way through.
static func _is_blocked_by_protect(defender: Dictionary, move: Dictionary) -> bool:
	if not bool(defender.get("protect_active", false)):
		return false
	if bool(move.get("ignores_protect", false)):
		return false
	return true

## True when the move belongs to the Protect family: every
## move Showdown marks "stallingMove: true" in
## data/moves.ts. All of them share ONE stall counter (the
## "stall" volatile below): Baneful Bunker, Burning
## Bulwark, Detect, Endure, King's Shield, Mat Block, Max
## Guard, Obstruct, Protect, Silk Trap, Spiky Shield.
static func _is_stalling_move(move: Dictionary) -> bool:
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	return move_id in ["banefulbunker", "burningbulwark", "detect", "endure", "kingsshield", "matblock", "maxguard", "obstruct", "protect", "silktrap", "spikyshield"]

## The Protect family's consecutive-use roll, exactly as
## Showdown runs it. Source: pokemon-showdown
## data/conditions.ts, the "stall" volatile, together with
## data/moves.ts, where every stalling move's onPrepareHit
## runs the StallMove event and its onHit adds the volatile:
## - With no stall volatile up (first use, or the chain
##   broke), the StallMove event has no handler and the
##   move just works. The volatile then starts with
##   counter 3 (onStart).
## - While the volatile is up (the mon used a stalling
##   move last turn), onStallMove rolls randomChance(1,
##   counter): the second use in a row succeeds 1/3 of the
##   time, the third 1/9, then 1/27, 1/81, 1/243, 1/729.
##   Each success multiplies the counter by 3, capped at
##   counterMax 729 (onRestart).
## - A failed roll deletes the volatile at once, so the
##   chain is gone and the next use starts fresh.
## The counter lives on the mon: stall_counter is the
## current denominator (0 = no volatile up), and
## stall_used_this_turn tells the end-of-turn tick whether
## the chain was fed this turn. Returns true when the
## move goes ahead.
func _stall_move_succeeds(mon: Dictionary) -> bool:
	var counter: int = int(mon.get("stall_counter", 0))
	if counter <= 0:
		mon["stall_counter"] = 3
		mon["stall_used_this_turn"] = true
		return true
	if rng.randf() >= 1.0 / float(counter):
		mon["stall_counter"] = 0
		mon["stall_used_this_turn"] = false
		return false
	if counter < 729:
		mon["stall_counter"] = counter * 3
	mon["stall_used_this_turn"] = true
	return true

## End-of-turn tick for the stall counter. Showdown's
## stall volatile has duration 2: it is still up for the
## one turn after the stalling move, then it ends. So a
## mon that did not use a stalling move this turn loses
## its counter (the chain resets), and a mon that did
## keeps it for next turn. A benched mon never uses a
## move, so being switched out breaks the chain too,
## the same way volatiles end when a mon switches out.
func _tick_stall_chains() -> void:
	for party in [player_party, enemy_party]:
		for slot in range(party.size()):
			var mon: Dictionary = party[slot]
			if bool(mon.get("stall_used_this_turn", false)):
				mon["stall_used_this_turn"] = false
			else:
				mon["stall_counter"] = 0

## Clear every active mon's Protect flag. Protect lasts only
## until the end of the turn (Showdown Protect condition,
## duration 1), so a flag left over would wrongly block moves
## next turn. Called at the start of both end-of-turn
## functions and at the start of both run_turn functions (the
## second call is a safety net for a turn that never reaches
## end of turn because the battle ended). Clearing the bench
## too is safe: a benched mon never has the flag set.
func _clear_protect_flags() -> void:
	for party in [player_party, enemy_party]:
		for slot in range(mini(2, party.size())):
			var mon: Dictionary = party[slot]
			mon["protect_active"] = false

## Try to take the holder's item (Knock Off after the hit). Returns

## true when the item was taken, false when Sticky Hold blocked it
## or there was nothing to take. The log line prints once, here.
func _try_take_item(holder: Dictionary, source: Dictionary, move: Dictionary, logs: Array) -> bool:
	var item: String = str(holder.get("item", ""))
	if item == "":
		return false
	if AbilityEngine.blocks_take_item(holder, source, move):
		logs.append(_mon_name(holder) + "'s Sticky Hold kept its " + item + "!")
		return false
	holder["item"] = ""
	logs.append(_mon_name(holder) + " lost its " + item + "!")
	return true


## Swap the two mons' held items (Trick / Switcheroo). Either side's
## Sticky Hold blocks the whole swap (Showdown onTryImmunity
## returns false when the target has Sticky Hold, and onHit restores
## both items when either take fails). Does nothing when neither mon
## holds an item. Trick and Switcheroo are not in the RC1 move list,
## so this only runs once the v5 loader brings them in.
func _swap_items(user: Dictionary, target: Dictionary, move: Dictionary, logs: Array) -> void:
	var user_item: String = str(user.get("item", ""))
	var target_item: String = str(target.get("item", ""))
	if user_item == "" and target_item == "":
		return
	if AbilityEngine.blocks_take_item(target, user, move) or AbilityEngine.blocks_take_item(user, target, move):
		logs.append("The item swap failed - Sticky Hold kept the items in place!")
		return
	user["item"] = target_item
	target["item"] = user_item
	logs.append(_mon_name(user) + " swapped items with " + _mon_name(target) + "!")


## A status move: hazards, hazard clearing, healing, a status on the
## target, and stat changes. Pivot status moves switch out after.
## Protect sets the user's protect_active flag for this turn
## only. A foe-targeting status move aimed at a protected mon
## is blocked. defender_is_ally is true when the defender is
## the attacker's own ally in doubles: an ally's move is never
## blocked by its ally's Protect.
func _apply_status_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_player: bool, logs: Array, defender_is_ally: bool = false) -> void:
	var move_name: String = str(move.get("name", ""))
	var mname_lower: String = move_name.to_lower()
	var own_hazards: Dictionary = field_state["player_hazards"] if is_player else field_state["enemy_hazards"]
	var foe_hazards: Dictionary = field_state["enemy_hazards"] if is_player else field_state["player_hazards"]
	# Stall counter: a Protect-family move (see
	# _is_stalling_move) rolls here, before it does anything
	# at all. A failed roll means the move does nothing,
	# like Showdown, where the failed StallMove roll makes
	# onPrepareHit stop the move. PP was already spent by
	# the caller, which also matches Showdown.
	if _is_stalling_move(move):
		if not _stall_move_succeeds(attacker):
			logs.append("But it failed!")
			return
	# Protect sets the flag on the user (the attacker here),
	# for this turn only. It runs first, before the hazard and
	# field branches, so a future loader that keeps
	# volatileStatus "protect" cannot send Protect down the
	# field-move path.
	if _is_protect(move):
		attacker["protect_active"] = true
		logs.append(_mon_name(attacker) + " protected itself!")
		return

	if move.has("hazard") or mname_lower in ["stealth rock", "spikes", "toxic spikes", "sticky web"]:
		MoveEffects.apply_hazard_move(move_name, foe_hazards, field_state, logs)
		return
	if mname_lower in ["rapid spin", "defog", "court change"]:
		MoveEffects.apply_hazard_clear(move_name, own_hazards, foe_hazards, field_state, logs)
		return
	if _is_field_move(move):
		_apply_field_move(attacker, defender, move, is_player, logs)
		return
	# Protect blocks a foe-targeting status move: a status, a
	# stat change on the defender, or Trick / Switcheroo. Self
	# moves (heals, self boosts), hazards and field moves are
	# not blocked: they do not target the protected mon. An
	# ally's move is never blocked by its ally's Protect.
	var mid: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	var def_boosts: Dictionary = move.get("boosts", {})
	var targets_defender: bool = move.has("status") or not def_boosts.is_empty() or mid == "trick" or mid == "switcheroo" or mid == "leechseed" or mid == "strengthsap"
	if targets_defender and not defender_is_ally and _is_blocked_by_protect(defender, move):
		logs.append(_mon_name(defender) + " protected itself!")
		return
	# Safety Goggles: a powder move used against the holder
	# does nothing at all.
	if targets_defender and not defender_is_ally and ItemEngine.blocks_powder_move(defender, move):
		logs.append(_mon_name(defender) + " is protected by its Safety Goggles!")
		return

	var heal_frac: float = float(move.get("heal_self", 0.0))
	if heal_frac > 0.0:
		var max_hp: int = int(attacker.get("max_hp", 100))
		var healed: int = mini(int(float(max_hp) * heal_frac), max_hp - int(attacker.get("hp", 0)))
		if _heal_blocked(attacker):
			# Heal Block: a healing move cannot restore HP
			# while it is up. The move does nothing at all.
			logs.append(_mon_name(attacker) + " is prevented from healing by Heal Block!")
			healed = 0
		if healed > 0:
			attacker["hp"] = int(attacker.get("hp", 0)) + healed
			logs.append(_mon_name(attacker) + " healed " + str(healed) + " HP!")
	# Trick / Switcheroo swap the two mons' held items. The move
	# names are checked by id because neither move is in the RC1
	# list yet - this only runs once the v5 loader brings them in.
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if move_id == "trick" or move_id == "switcheroo":
		_swap_items(attacker, defender, move, logs)
		return
	if mid == "leechseed":
		# Leech Seed plants a seed on the target: at the end of
		# each turn the target loses 1/8 of its max HP and the
		# seeder's side heals by the same amount (see
		# _apply_leech_seed). Grass types are immune, and a mon
		# that is already seeded cannot be seeded again.
		var def_types: Array = defender.get("types", [])
		var is_grass: bool = false
		for t in def_types:
			if str(t).to_lower() == "grass":
				is_grass = true
		if is_grass:
			logs.append("It doesn't affect " + _mon_name(defender) + "!")
			return
		if bool(defender.get("leech_seeded", false)):
			logs.append("It failed - " + _mon_name(defender) + " is already seeded!")
			return
		defender["leech_seeded"] = true
		defender["leech_seed_side"] = "enemy" if is_player else "player"
		logs.append(_mon_name(defender) + " was seeded!")
		return
	if mid == "strengthsap":
		# Strength Sap: the user heals by the target's Attack
		# stat (with its stages, read before the drop), then
		# the target's Attack drops one stage. Against a
		# Liquid Ooze target the would-be heal becomes damage
		# to the user instead. Under Heal Block the heal is
		# prevented but the drop still happens. The move
		# fails outright when the target's Attack is already
		# at its lowest stage (Showdown rule).
		var d_stages: Dictionary = defender.get("stages", {})
		if int(d_stages.get("atk", 0)) <= -6:
			logs.append("It failed - " + _mon_name(defender) + "'s Attack won't go lower!")
			return
		var eff_atk: int = int(float(int(defender.get("atk", 0))) * PUWBattleEngine._stage_mult(int(d_stages.get("atk", 0))))
		if str(defender.get("ability", "")) == "Liquid Ooze":
			attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - eff_atk)
			logs.append(_mon_name(attacker) + " was hurt by Liquid Ooze!")
		elif _heal_blocked(attacker):
			logs.append(_mon_name(attacker) + " is prevented from healing by Heal Block!")
		else:
			var sap_healed: int = mini(eff_atk, int(attacker.get("max_hp", 100)) - int(attacker.get("hp", 0)))
			if sap_healed > 0:
				attacker["hp"] = int(attacker.get("hp", 0)) + sap_healed
				logs.append(_mon_name(attacker) + " restored " + str(sap_healed) + " HP with Strength Sap!")
		_apply_stages(defender, {"atk": -1}, logs, attacker, field_state, attacker, move)
		return
	if move.has("status"):
		# try_set_status is the one choke point: it checks
		# blocks_status (Leaf Guard Sun), the PSN/TOX type immunity
		# (Corrosion bypass), sets sleep_turns (2-4) and toxic_counter,
		# and fires on_after_set_status (Synchronize, Poison Puppeteer).
		AbilityEngine.try_set_status(defender, str(move.get("status", "")), attacker, field_state, logs)
	if str(move.get("volatileStatus", "")).to_lower() == "confusion":
		# A status move that confuses (Swagger, Supersonic, Teeter
		# Dance): 2-5 turns, Own Tempo blocks it, an already-confused
		# mon stays as it is. _is_field_move no longer treats
		# "confusion" as a field move, so this branch is reached.
		if not bool(defender.get("confused", false)) and str(defender.get("ability", "")) != "Own Tempo":
			defender["confused"] = true
			defender["confusion_turns"] = rng.randi_range(2, 5)
			logs.append(_mon_name(defender) + " became confused!")
	if MoveEffects.is_pivot(move):
		# The pivot handler also applies the move's own stat changes.
		var after: Dictionary = MoveEffects.apply_after_hit(attacker, defender, move, 0, field_state, rng, logs)
		if bool(after.get("switch_requested", false)):
			_handle_pivot(is_player, logs)
		return
	var self_block: Dictionary = move.get("self", {})
	var self_boosts: Dictionary = self_block.get("boosts", {})
	# The RC1 move list writes self boosts as "self_boost"
	# (Swords Dance, Dragon Dance, Calm Mind, Nasty Plot,
	# Rapid Spin); read that shape too, so those moves work.
	if self_boosts.is_empty():
		self_boosts = move.get("self_boost", {})
	_apply_stages(attacker, self_boosts, logs, {}, field_state, defender, move)
	_apply_stages(defender, move.get("boosts", {}), logs, attacker, field_state, attacker, move)



## True when the move sets a field effect with a duration.
## Tailwind and Trick Room are in the RC1 list (side_condition /
## field); Gravity, Safeguard, Wonder Room, Magic Room and Heal
## Block come from moves.json keys (sideCondition /
## pseudoWeather / volatileStatus) once the v5 loader brings them
## in. The move names are checked by id.
static func _is_field_move(move: Dictionary) -> bool:
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if move_id == "tailwind" or move_id == "trickroom" or move_id == "gravity" or move_id == "safeguard" or move_id == "wonderroom" or move_id == "magicroom" or move_id == "healblock":
		return true
	if str(move.get("side_condition", "")) != "" or str(move.get("field", "")) != "":
		return true
	if str(move.get("sideCondition", "")) != "" or str(move.get("pseudoWeather", "")) != "":
		return true
	# Only Heal Block is a field move by volatileStatus. A confusion
	# volatileStatus (Swagger, Supersonic) is a move effect, not a
	# field effect, and is handled in _apply_status_move.
	if str(move.get("volatileStatus", "")).to_lower() == "healblock":
		return true
	return false


## Set a field effect and its duration. Durations are the Showdown
## moves.ts base values (Tailwind 4, Trick Room 5, Gravity 5,
## Safeguard 5, Wonder Room 5, Magic Room 5, Heal Block 5), plus 2
## when the user has Persistent (field_duration). Trick Room toggles
## off when it is already up. Tailwind and Safeguard sit on the
## user's side (screens for Tailwind, player_safeguard /
## enemy_safeguard for Safeguard). Heal Block sits on the target
## mon as heal_block_turns; Psychic Noise's own 2-turn Heal Block
## is wired separately in MoveEffects, as noise_heal_block_turns
## on the target, because Psychic Noise is a damaging move and
## never reaches this status-move path. ONLY the durations are built here: the
## underlying effects of Gravity, Safeguard, the Rooms and Heal
## Block do not exist yet in this engine, so setting them does
## nothing but start the timer.
func _apply_field_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_player: bool, logs: Array) -> void:
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	var aname: String = _mon_name(attacker)
	match move_id:
		"tailwind":
			var dur: int = AbilityEngine.field_duration(attacker, "tailwind", 4)
			var screens: Dictionary = field_state["player_screens"] if is_player else field_state["enemy_screens"]
			var tailwind_was_up: bool = int(screens.get("tailwind", 0)) > 0
			screens["tailwind"] = dur
			if is_player:
				field_state["player_screens"] = screens
			else:
				field_state["enemy_screens"] = screens
			logs.append(aname + " set up a Tailwind for " + str(dur) + " turns!")
			if not tailwind_was_up:
				_apply_tailwind_start(is_player, logs)

		"trickroom":
			var dur2: int = AbilityEngine.field_duration(attacker, "trickroom", 5)
			if int(field_state.get("trick_room", 0)) > 0:
				field_state["trick_room"] = 0
				logs.append("Trick Room wore off!")
			else:
				field_state["trick_room"] = dur2
				logs.append(aname + " twisted the dimensions for " + str(dur2) + " turns!")
				# Room Service: every active holder's Speed
				# drops 1 stage as Trick Room goes up.
				_apply_room_service(logs)
		"gravity":
			field_state["gravity"] = AbilityEngine.field_duration(attacker, "gravity", 5)
			logs.append(aname + " set up Gravity for " + str(field_state.get("gravity", 0)) + " turns!")
			# Gravity brings down every airborne Pokemon at
			# once: a mon up with Fly, Bounce or Sky Drop lands,
			# and a mon carried by Sky Drop is dropped too. The
			# airborne mons are collected first, because clearing
			# a Sky Drop carrier already frees its target.
			var grav_actives: Array = []
			for grav_party in [player_party, enemy_party]:
				var grav_slots: int = 2 if active_format == "doubles" else 1
				for grav_slot in range(mini(grav_slots, grav_party.size())):
					grav_actives.append(grav_party[grav_slot])
			if not attacker.is_empty() and not (attacker in grav_actives):
				grav_actives.append(attacker)
			if not defender.is_empty() and not (defender in grav_actives):
				grav_actives.append(defender)
			var grav_downed: Array = []
			for grav_mon in grav_actives:
				var grav_mon_dict: Dictionary = grav_mon
				if _is_airborne(grav_mon_dict):
					grav_downed.append(grav_mon_dict)
			for grav_mon2 in grav_downed:
				var grav_mon2_dict: Dictionary = grav_mon2
				_clear_airborne(grav_mon2_dict)
				logs.append(_mon_name(grav_mon2_dict) + " was brought down by Gravity!")
		"safeguard":
			var dur3: int = AbilityEngine.field_duration(attacker, "safeguard", 5)
			if is_player:
				field_state["player_safeguard"] = dur3
			else:
				field_state["enemy_safeguard"] = dur3
			logs.append(aname + " set up Safeguard for " + str(dur3) + " turns!")
		"wonderroom":
			field_state["wonder_room"] = AbilityEngine.field_duration(attacker, "wonderroom", 5)
			logs.append(aname + " set up Wonder Room for " + str(field_state.get("wonder_room", 0)) + " turns!")
		"magicroom":
			field_state["magic_room"] = AbilityEngine.field_duration(attacker, "magicroom", 5)
			logs.append(aname + " set up Magic Room for " + str(field_state.get("magic_room", 0)) + " turns!")
		"healblock":
			defender["heal_block_turns"] = AbilityEngine.field_duration(attacker, "healblock", 5)
			logs.append(_mon_name(defender) + " was hit with Heal Block for " + str(defender.get("heal_block_turns", 0)) + " turns!")


## Change stat stages, clamped between -6 and +6.
func _apply_stages(mon: Dictionary, boosts: Dictionary, logs: Array, source: Dictionary = {}, field: Dictionary = {}, other: Dictionary = {}, move: Dictionary = {}) -> void:


	if boosts.is_empty() or int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var names := {"atk": "Attack", "def": "Defense", "spa": "Special Attack", "spd": "Special Defense", "spe": "Speed"}
	# A drop is foe-caused when a source mon is passed. Self boosts
	# pass source = {} and skip the Mirror Armor / block checks, so
	# a mon can still lower its own stages (White Smoke and Clear
	# Body only block foe-caused drops, per their Batch1 comment).
	var foe_caused: bool = not source.is_empty()
	# A move that ignores abilities (Mold Breaker, Teravolt,
	# Turboblaze) ignores the target's ability for this change:
	# no Mirror Armor bounce, no Clear Body block, and no
	# Competitive / Defiant / Contrary answer from the target.
	# The Opportunist copy below still fires: that is the other
	# mon's ability, not the target's.
	var ignore_target_ab: bool = foe_caused and AbilityEngine.move_ignores_ability(source, move)
	# The changes that really land, for the item hooks after
	# the loop (Eject Pack answers a drop, Mirror Herb copies
	# a rise) — the MoveEffects._apply_boosts mirror.
	var applied: Dictionary = {}

	for key in boosts.keys():
		var k := str(key)
		if not names.has(k):
			continue
		var amount: int = int(boosts[k])
		var before := int(stages.get(k, 0))
		if foe_caused and amount < 0:
			if not ignore_target_ab and AbilityEngine.try_mirror_armor(mon, k, amount, source, logs):
				continue
			if AbilityEngine.blocks_stat_change(mon, k, amount, source, move):

				logs.append("%s's %s didn't fall!" % [_mon_name(mon), str(names[k])])
				continue
			# Clear Amulet: an opposing Pokemon cannot lower
			# the holder's stats at all. (An item, so a
			# Mold-Breaker move does not ignore it.)
			if ItemEngine.blocks_foe_stat_drop(mon):
				logs.append("%s's %s didn't fall!" % [_mon_name(mon), str(names[k])])
				continue
		var after := clampi(before + amount, -6, 6)
		stages[k] = after
		if after != before:
			applied[k] = after - before
			var direction := "rose" if after > before else "fell"
			logs.append("%s's %s %s!" % [_mon_name(mon), str(names[k]), direction])
			field["boost_target_name"] = _mon_name(mon)
			if foe_caused and not ignore_target_ab:
				AbilityEngine.on_stat_boosted(mon, k, after - before, field, logs)

			elif str(mon.get("ability", "")) == "Contrary" or str(mon.get("ability", "")) == "Simple":
				# Self-caused changes only reach Contrary and
				# Simple. Competitive and Defiant only answer
				# foe-caused drops (see their Batch1 note), so
				# they are not called for a self change.
				AbilityEngine.on_stat_boosted(mon, k, after - before, field, logs)
			if not other.is_empty() and str(other.get("ability", "")) == "Opportunist":
				# Opportunist copies a foe's boost. Only the
				# Opportunist arm can fire on this call: the
				# other mon has exactly one ability, and it is
				# Opportunist.
				AbilityEngine.on_stat_boosted(other, k, after - before, field, logs)

	mon["stages"] = stages
	if foe_caused:
		var any_drop: bool = false
		for key2 in applied.keys():
			if int(applied[key2]) < 0:
				any_drop = true
		if any_drop:
			ItemEngine.on_stat_dropped(mon, logs)
		if not other.is_empty():
			ItemEngine.try_mirror_herb(other, applied, logs)
	elif not other.is_empty():
		# Mirror Herb also answers a mon raising its OWN stats:
		# self boosts pass source = {} and the holder is `other`.
		ItemEngine.try_mirror_herb(other, applied, logs)

## Apply a forme change from AbilityEngine.form_change (Disguise,
## Forecast, Zen Mode, Tera Shift and the rest). Sets mon["forme"]
## and logs it, but only when the forme really changes. Called
## after a switch-in, after damage, and at the end of a turn.
func _apply_form_change(mon: Dictionary, logs: Array) -> void:
	if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
		return
	var form: String = AbilityEngine.form_change(mon, field_state)
	if form == "":
		return
	if str(mon.get("forme", "")) == form:
		return
	mon["forme"] = form
	logs.append(_mon_name(mon) + " changed forme!")


## Apply a terrain from AbilityEngine.terrain_on_switch_in
## (Electric Surge, Grassy Surge, Misty Surge, Hadron Engine,
## Psychic Surge). Sets the field terrain for 5 turns, but only
## when the terrain really changes (Psychic Surge already sets it
## in its own switch-in arm). Called after a switch-in.
func _apply_terrain_on_switch_in(mon: Dictionary) -> void:
	if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
		return
	# Under Neutralizing Gas no ability sets terrain (the Surge
	# arms are suppressed by the engine guard, and this helper is
	# the only other terrain setter on switch-in).
	if bool(field_state.get("abilities_suppressed", false)):
		return
	var terrain: String = AbilityEngine.terrain_on_switch_in(mon)
	if terrain == "":
		return
	if str(field_state.get("terrain", "none")) == terrain:
		return
	field_state["terrain"] = terrain
	field_state["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)

## Run the Tailwind-start ability effects for every living mon
## on the side that just got Tailwind (Wind Power gains Charge,
## Wind Rider raises Attack 1). Called from _apply_field_move
## only when Tailwind was not already up. Slots 0-1 in doubles,
## slot 0 only in singles.
func _apply_tailwind_start(is_player: bool, logs: Array) -> void:
	var slots: int = 2 if active_format == "doubles" else 1
	var party: Array = player_party if is_player else enemy_party
	for slot in range(mini(slots, party.size())):
		var mon: Dictionary = party[slot]
		if int(mon.get("hp", 0)) <= 0:
			continue
		logs.append_array(AbilityEngine.on_tailwind_start(mon, field_state))

## Eject Pack consumption: ItemEngine.on_stat_dropped raises
## mon["eject_pack_pending"] when a foe-caused drop lands on a
## pack holder; the switch itself runs here, after the move,
## through _handle_forced_switch (so Suction Cups and friends
## can still refuse it). Called from the action dispatchers.
func _consume_eject_pack(mon: Dictionary, mon_is_player: bool, move: Dictionary, logs: Array, slot: int = 0) -> void:
	if mon.is_empty() or not bool(mon.get("eject_pack_pending", false)):
		return
	mon["eject_pack_pending"] = false
	if int(mon.get("hp", 0)) <= 0:
		return
	logs.append(_mon_name(mon) + " was switched out by its Eject Pack!")
	_handle_forced_switch(mon_is_player, move, logs, slot)

## Room Service: when Trick Room goes up, every active holder
## of the item drops 1 Speed stage and the item is consumed.
## Called from the Trick Room arm of _apply_field_move, in the
## set branch only (never when Trick Room is toggled off).
func _apply_room_service(logs: Array) -> void:
	var slots: int = 2 if active_format == "doubles" else 1
	for party in [player_party, enemy_party]:
		for slot in range(mini(slots, party.size())):
			var mon: Dictionary = party[slot]
			ItemEngine.on_trick_room_set(mon, logs)

## Run the switch-in-under-Tailwind ability effect for one mon
## (Wind Rider raises Attack 1 when it starts under an active
## Tailwind; Wind Power gets nothing on switch-in, because
## Showdown gives it no onStart). The caller knows the side, so
## this helper checks the right screens dict. Called after a
## switch-in at every switch-in site (Patch F).
func _apply_tailwind_switch_in(mon: Dictionary, is_player: bool, logs: Array) -> void:
	if mon.is_empty() or int(mon.get("hp", 0)) <= 0:
		return
	var screens: Dictionary = field_state["player_screens"] if is_player else field_state["enemy_screens"]
	if int(screens.get("tailwind", 0)) <= 0:
		return
	logs.append_array(AbilityEngine.on_tailwind_switch_in(mon, field_state))


## Recompute the field flags that only last while a holder is
## active, from the mons now on the field (HP above 0). Called
## after a switch-out and after a faint, so a flag only stays when
## another living active mon still has the ability that sets it.
## Weather Suppressed: Air Lock / Cloud Nine. Abilities Suppressed:
## Neutralizing Gas. Primordial Sea: Primordial Sea (its heavy
## rain ends too, unless another rain setter is active). Ruin
## flags: Sword / Tablets / Vessel of Ruin. Unnerve: Unnerve (and
## As One, which carries Unnerve).
func _sync_field_flags() -> void:
	var had_sea: bool = bool(field_state.get("primordialsea", false))
	var actives: Array = []
	# Only the mons actually on the field count: slot 0 in singles,
	# slots 0-1 in doubles. A benched mon's ability (a switched-out
	# Neutralizing Gas holder sitting in slot 1 of a singles party)
	# must not keep its flag on.
	var slots: int = 2 if active_format == "doubles" else 1
	for party in [player_party, enemy_party]:
		for slot in range(mini(slots, party.size())):
			var mon: Dictionary = party[slot]
			if int(mon.get("hp", 0)) > 0:
				actives.append(mon)
	var has_airlock: bool = false
	var has_gas: bool = false
	var has_sea: bool = false
	var has_sword: bool = false
	var has_tablets: bool = false
	var has_vessel: bool = false
	var has_unnerve: bool = false
	var has_drizzle: bool = false
	for mon in actives:
		var ab: String = str(mon.get("ability", ""))
		if ab == "Air Lock" or ab == "Cloud Nine":
			has_airlock = true
		if ab == "Neutralizing Gas":
			has_gas = true
		if ab == "Primordial Sea":
			has_sea = true
		if ab == "Sword of Ruin":
			has_sword = true
		if ab == "Tablets of Ruin":
			has_tablets = true
		if ab == "Vessel of Ruin":
			has_vessel = true
		if ab == "Unnerve" or ab == "As One" or ab == "As One (Glastrier)" or ab == "As One (Spectrier)" or ab == "asone":
			has_unnerve = true
		if ab == "Drizzle":
			has_drizzle = true
	field_state["weather_suppressed"] = has_airlock
	field_state["abilities_suppressed"] = has_gas
	field_state["primordialsea"] = has_sea
	field_state["ruin_sword"] = has_sword
	field_state["ruin_tablets"] = has_tablets
	field_state["ruin_vessel"] = has_vessel
	field_state["unnerve_active"] = has_unnerve
	if had_sea and not has_sea and str(field_state.get("weather", "none")) == "rain" and not has_drizzle:
		field_state["weather"] = "none"
		field_state["weather_turns"] = 0


## True when the move forces the target out. Showdown: Whirlwind

## and Roar (Status, priority -6, forceSwitch), Dragon Tail (60
## power, Dragon, priority -6, forceSwitch), Circle Throw (60
## power, Fighting, priority -6, forceSwitch). None of the four is
## in the RC1 move list, so this only runs once the v5 loader
## brings them in.
## Screen Cleaner: the Batch3 arm sets field_state["screens_cleared"]
## on switch-in. The caller removes Reflect, Light Screen and Aurora
## Veil from BOTH sides and clears the flag. Tailwind stays: Showdown
## removes exactly those three screens. The log only prints when a
## screen was really removed (that is why the arm itself no longer
## logs, see Patch B11).
func _maybe_clear_screens(mon: Dictionary, logs: Array) -> void:
	if not bool(field_state.get("screens_cleared", false)):
		return
	field_state["screens_cleared"] = false
	var cleared: bool = false
	for key in ["player_screens", "enemy_screens"]:
		var screens: Dictionary = field_state.get(key, {})
		for screen in ["reflect", "light_screen", "aurora_veil"]:
			if int(screens.get(screen, 0)) > 0:
				screens[screen] = 0
				cleared = true
	if cleared:
		logs.append("%s's Screen Cleaner cleared all screens!" % _mon_name(mon))


## Supreme Overlord reads mon["fallen_allies"]: how many of the
## holder's party members (not counting the holder) have 0 HP. The
## whole party counts, bench included (Showdown side.totalFainted).
## Run at battle start, after every faint and after a Revive, so
## the number is always fresh. Capped at 5, like the power table.
func _refresh_fallen_allies() -> void:
	for party in [player_party, enemy_party]:
		for i in party.size():
			var mon: Dictionary = party[i]
			var fallen: int = 0
			for j in party.size():
				if j != i and int(party[j].get("hp", 0)) <= 0:
					fallen += 1
			mon["fallen_allies"] = mini(5, fallen)


## Stakeout only hits a foe that switched in THIS turn. Clear the
## flag on every party mon at the end of the turn, after all moves
## are done. Clearing at the START of the turn would be wrong: a
## lead that started the battle would lose its flag before any
## move is made, and Stakeout would never fire on turn 1.
func _clear_switched_in_flags() -> void:
	for party in [player_party, enemy_party]:
		for mon in party:
			mon["switched_in_this_turn"] = false


## The active mons of one side: slot 0 only in singles, slots 0 and
## 1 in doubles. Bench mons never count (a benched Unnerve holder
## blocks nothing).
func _active_side_mons(is_player_side: bool) -> Array:
	var party: Array = player_party if is_player_side else enemy_party
	var mons: Array = []
	if party.is_empty():
		return mons
	mons.append(party[0])
	if active_format == "doubles" and party.size() > 1:
		mons.append(party[1])
	return mons


## True when one side has a living active Unnerve holder. As One
## carries Unnerve too, so it counts here as well. The single
## field_state["unnerve_active"] flag cannot answer this per side,
## so the live mons are checked directly.
func _side_has_unnerve(active_mons: Array) -> bool:
	for mon in active_mons:
		if int(mon.get("hp", 0)) <= 0:
			continue
		var ab: String = str(mon.get("ability", ""))
		if ab == "Unnerve" or ab == "As One" or ab == "As One (Glastrier)" or ab == "As One (Spectrier)" or ab == "asone" or ab == "asoneglastrier" or ab == "asonespectrier":
			return true
	return false


## Wimp Out (mon["switch_flag"]) and Emergency Exit
## (mon["force_switch"]) both mean: this mon leaves now, after the
## damage is done. One shared path for both, and it is the same path
## a pivot move uses (_handle_pivot): the player's side waits for the
## player to pick, the foe's side sends its next mon at once. A mon
## with no living bench mon stays in: forcing a switch with nowhere
## to go would soft-lock the battle. In doubles the player flag is
## shared for both slots, the same as a fainted player mon (see
## _handle_faint_slot).
func _maybe_ability_switch(side_is_player: bool, logs: Array) -> void:
	var party: Array = player_party if side_is_player else enemy_party
	var bench_start: int = 1 if active_format != "doubles" else 2
	var active_slots: int = 1 if active_format != "doubles" else 2
	for slot in range(mini(active_slots, party.size())):
		var mon: Dictionary = party[slot]
		if int(mon.get("hp", 0)) <= 0:
			continue
		if not bool(mon.get("switch_flag", false)) and not bool(mon.get("force_switch", false)):
			continue
		mon["switch_flag"] = false
		mon["force_switch"] = false
		var has_bench: bool = false
		for j in range(bench_start, party.size()):
			if int(party[j].get("hp", 0)) > 0:
				has_bench = true
				break
		if not has_bench:
			logs.append("%s has nowhere to go!" % _mon_name(mon))
			continue
		_handle_pivot(side_is_player, logs, slot)

static func _is_drag_out(move: Dictionary) -> bool:
	if bool(move.get("forceSwitch", false)):
		return true
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	return move_id == "whirlwind" or move_id == "roar" or move_id == "dragontail" or move_id == "circlethrow"

## Moves Gravity disables outright (Showdown's Gravity
## onDisableMove list): the two-turn flying moves, the
## jumping kicks, Sky Drop, Magnet Rise and Telekinesis.
## While Gravity is up, using one simply fails.
static func _gravity_disabled(move: Dictionary) -> bool:
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	return move_id in ["fly", "bounce", "skydrop", "highjumpkick", "jumpkick", "magnetrise", "telekinesis"]


## The two-turn airborne moves. The first use only takes the
## user into the air (mon["airborne_move"] holds the move id);
## the move strikes when it is used again next turn. Sky Drop
## also carries the target up: the target gets
## mon["held_in_sky"] and the carrier keeps the target dict in
## mon["skydrop_target"].
const AIRBORNE_MOVE_IDS: Array = ["fly", "bounce", "skydrop"]

## Moves that can hit an airborne target (Showdown: Gust,
## Twister, Thunder, Hurricane and Sky Uppercut hit a Pokemon
## in the air, and Smack Down hits it and brings it down).
## Gust and Twister also deal double power to an airborne
## target.
const AIRBORNE_HIT_IDS: Array = ["gust", "twister", "thunder", "hurricane", "skyuppercut", "smackdown"]

## The airborne move id for a move name ("Sky Drop" ->
## "skydrop"), or "" when the move is not an airborne move.
static func _airborne_move_id(move_name: String) -> String:
	var move_id: String = move_name.to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if move_id in AIRBORNE_MOVE_IDS:
		return move_id
	return ""

## The display name for an airborne move id, used when a turn
## forces an airborne mon to strike with the move it rose with.
static func _airborne_move_name(move_id: String) -> String:
	match move_id:
		"fly":
			return "Fly"
		"bounce":
			return "Bounce"
		"skydrop":
			return "Sky Drop"
	return ""

## True when the mon is up in the air: it rose with Fly, Bounce
## or Sky Drop, or it is being carried by a foe's Sky Drop.
static func _is_airborne(mon: Dictionary) -> bool:
	return str(mon.get("airborne_move", "")) != "" or bool(mon.get("held_in_sky", false))

## End a mon's airborne state. A Sky Drop carrier dropping (or
## leaving) frees the mon it was carrying.
func _clear_airborne(mon: Dictionary) -> void:
	var held_target: Dictionary = mon.get("skydrop_target", {})
	if not held_target.is_empty():
		held_target["held_in_sky"] = false
	mon["airborne_move"] = ""
	mon["skydrop_target"] = {}
	mon["held_in_sky"] = false

## True when healing is blocked for this mon, from either
## source: the Heal Block move (heal_block_turns, 5 turns) or
## Psychic Noise's own block (noise_heal_block_turns, 2 turns).
## The real games treat both as the same Heal Block condition.
func _heal_blocked(mon: Dictionary) -> bool:
	return int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0


## Force the target mon out. Returns "switched", "blocked",
## "failed" or "fled". Suction Cups and Guard Dog block the
## drag-out (blocks_drag_out). A wild mon hit by Roar or Whirlwind
## ends the battle (fled); Dragon Tail and Circle Throw fail
## against a wild mon because there is no party to send (Showdown:
## they fail when the target has no bench). Otherwise a random
## living bench mon is sent in through execute_switch /
## _doubles_switch, so switch-in abilities and hazards fire.
## A dragged-out mon whose action is still queued keeps it - all
## four drag-out moves are priority -6, so this only matters when
## the target had not acted yet (for example it was asleep).
func _handle_forced_switch(target_is_player: bool, move: Dictionary, logs: Array, slot: int = 0) -> String:
	var target_party: Array = player_party if target_is_player else enemy_party
	var target: Dictionary = target_party[slot] if slot < target_party.size() else {}
	if target.is_empty():
		return "failed"
	# Commander: while Tatsugiri is inside Dondozo, NEITHER of
	# the pair can be forced out — not by Roar, Whirlwind,
	# Dragon Tail or Circle Throw, and not by a Red Card (which
	# reaches this same function). The commanding Tatsugiri
	# and the commanded Dondozo both refuse the drag-out.
	if bool(target.get("commanding", false)) or bool(target.get("commanded", false)):
		logs.append(_mon_name(target) + " cannot be forced out while Commander is active!")
		return "blocked"
	var user_party: Array = enemy_party if target_is_player else player_party
	var user: Dictionary = user_party[0] if not user_party.is_empty() else {}
	if AbilityEngine.blocks_drag_out(target, user):
		var ab: String = str(target.get("ability", ""))
		if ab == "Guard Dog":
			logs.append(_mon_name(target) + "'s Guard Dog kept it in battle!")
		else:
			logs.append(_mon_name(target) + "'s Suction Cups kept it in battle!")
		return "blocked"
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if is_wild and not target_is_player:
		if move_id == "roar" or move_id == "whirlwind":
			battle_state["wild_fled"] = true
			logs.append("The wild " + _mon_name(target) + " was blown away!")
			return "fled"
		logs.append("It failed - the wild Pokemon has nowhere to go!")
		return "failed"
	# Random living bench mon: singles bench is party[1..],
	# doubles bench is party[2..].
	var bench_start: int = 1 if active_format != "doubles" else 2
	var living: Array = []
	for i in range(bench_start, target_party.size()):
		if int(target_party[i].get("hp", 0)) > 0:
			living.append(i)
	if living.is_empty():
		logs.append("It failed - there was nothing to send in!")
		return "failed"
	var pick: int = int(living[rng.randi_range(0, living.size() - 1)])
	if active_format == "doubles":
		var foe0: Dictionary = user_party[0] if not user_party.is_empty() else {}
		_doubles_switch(target_party, pick, slot, foe0, target_is_player, logs)
	else:
		var foe: Dictionary = user_party[0] if not user_party.is_empty() else {}
		var sw_logs: Array = execute_switch(target_party, pick, foe, target_is_player)
		logs.append_array(sw_logs)
	return "switched"


## A pivot move (U-turn, Volt Switch, and the like) switches the user
## out. The player's side waits for the player to pick; the foe's
## side sends its next Pokemon at once.
func _handle_pivot(is_player: bool, logs: Array, slot: int = 0) -> void:
	if is_player:
		battle_state["player_must_switch"] = true
		logs.append("Choose your next Pokemon!")
	elif active_format == "doubles":
		_send_next_doubles(enemy_party, slot, player_party[0], false, logs)
	else:
		_auto_send_next(enemy_party, player_party[0], false, logs)

## Send the next living Pokemon in. Returns false when none is left.
func _auto_send_next(party: Array, foe: Dictionary, is_player: bool, logs: Array) -> bool:
	for i in range(1, party.size()):
		if int(party[i].get("hp", 0)) > 0:
			var sw_logs: Array = execute_switch(party, i, foe, is_player)
			party[0]["participated"] = true
			logs.append("Go! " + _mon_name(party[0]) + "!")
			logs.append_array(sw_logs)
			return true
	return false

## A Pokemon fainted: log it, give EXP to the other side, then either
## the battle is over, the player must pick a new Pokemon, or the foe
## sends its next one at once.
func _handle_faint(fainted_is_player: bool, logs: Array, by_move: bool = true) -> void:
	var fainted_party: Array = player_party if fainted_is_player else enemy_party
	var winner_party: Array = enemy_party if fainted_is_player else player_party
	if fainted_party.is_empty():
		return
	var fainted: Dictionary = fainted_party[0]
	if int(fainted.get("hp", 0)) > 0:
		return
	# Fainting ends the airborne state, and a fainted Sky Drop
	# carrier drops the mon it was carrying.
	_clear_airborne(fainted)
	logs.append(_mon_name(fainted) + " fainted!")
	grant_exp(winner_party, fainted, logs)
	var foe: Dictionary = winner_party[0] if not winner_party.is_empty() else {}
	AbilityEngine.on_faint(fainted, foe, field_state, logs, by_move)
	_sync_field_flags()
	_refresh_fallen_allies()
	if _all_fainted(fainted_party):
		return


	if fainted_is_player:
		battle_state["player_must_switch"] = true
		logs.append("Choose your next Pokemon!")
	else:
		_auto_send_next(enemy_party, player_party[0], false, logs)


## Where the real EXP numbers live. exp_yield.json (PokeAPI data)
## must be copied to res://data/exp_yield.json in the project.
const EXP_YIELD_PATH: String = "res://data/exp_yield.json"

## V5 tables. weight_power.json is species slug -> weight in
## hectograms (1,025 entries). base_atk.json is species slug ->
## base Attack, built from pokeapi_stats_1025.json by the
## coordinator. Both files must be copied to res://data/.
const WEIGHT_TABLE_PATH: String = "res://data/weight_power.json"
const BASE_ATK_TABLE_PATH: String = "res://data/base_atk.json"

## Fling and Natural Gift tables (v5 pack, built from Showdown
## data/items.ts). fling_table.json is item slug -> a row with
## "name", "base_power" and, for the few items that carry one,
## an on-hit effect ("status", "volatile_status",
## "clears_volatiles" or "restores_negative_boosts").
## natural_gift_table.json is item slug -> {"name",
## "base_power", "type"} for the 77 berries. Both files must be
## copied to res://data/, like the weight table.
const FLING_TABLE_PATH: String = "res://data/fling_table.json"
const NATURAL_GIFT_TABLE_PATH: String = "res://data/natural_gift_table.json"

## V5 table caches, loaded once and kept in memory, same as
## _exp_yield_cache below.
static var _weight_cache: Dictionary = {}
static var _base_atk_cache: Dictionary = {}
static var _fling_cache: Dictionary = {}
static var _natural_gift_cache: Dictionary = {}


## The yield table, loaded once and kept in memory.
static var _exp_yield_cache: Dictionary = {}

## The whole yield table, keyed by a cleaned species name
## ("mr-mime" and "Mr. Mime" both become "mrmime"). Returns {}
## when the file is missing or broken — the caller then gives no
## EXP instead of guessing a number.
static func _exp_yield_table() -> Dictionary:
	if not _exp_yield_cache.is_empty():
		return _exp_yield_cache
	if not FileAccess.file_exists(EXP_YIELD_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(EXP_YIELD_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed as Dictionary
	var species_list: Variant = data.get("species", [])
	if not (species_list is Array):
		return {}
	var species: Array = species_list as Array
	for entry in species:
		if entry is Dictionary:
			var entry_dict: Dictionary = entry as Dictionary
			var key: String = _normalize_species_key(str(entry_dict.get("name", "")))
			if key != "":
				_exp_yield_cache[key] = entry_dict
	return _exp_yield_cache

## The whole weight table, keyed by species slug
## ("bulbasaur", "giratina-altered", "mr-mime"). Returns {} when
## the file is missing or broken, so the caller gets 0 instead
## of guessing a weight.
static func _weight_table() -> Dictionary:
	if not _weight_cache.is_empty():
		return _weight_cache
	if not FileAccess.file_exists(WEIGHT_TABLE_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(WEIGHT_TABLE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	_weight_cache = parsed as Dictionary
	return _weight_cache

## The whole base Attack table, keyed by species slug, same
## shape as the weight table. Returns {} when the file is
## missing or broken.
static func _base_atk_table() -> Dictionary:
	if not _base_atk_cache.is_empty():
		return _base_atk_cache
	if not FileAccess.file_exists(BASE_ATK_TABLE_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(BASE_ATK_TABLE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	_base_atk_cache = parsed as Dictionary
	return _base_atk_cache

## The whole Fling table, keyed by item slug ("lightball",
## "kingsrock"). Returns {} when the file is missing or broken,
## so Fling falls back to the caller-filled item_fling_power
## and fails when that is 0 too, instead of guessing a power.
static func _fling_table() -> Dictionary:
	if not _fling_cache.is_empty():
		return _fling_cache
	if not FileAccess.file_exists(FLING_TABLE_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(FLING_TABLE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	_fling_cache = parsed as Dictionary
	return _fling_cache

## The whole Natural Gift table, keyed by item slug
## ("liechiberry"). Returns {} when the file is missing or
## broken, like the Fling table.
static func _natural_gift_table() -> Dictionary:
	if not _natural_gift_cache.is_empty():
		return _natural_gift_cache
	if not FileAccess.file_exists(NATURAL_GIFT_TABLE_PATH):
		return {}
	var text: String = FileAccess.get_file_as_string(NATURAL_GIFT_TABLE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	_natural_gift_cache = parsed as Dictionary
	return _natural_gift_cache

## An item's table slug: lower case, and every character that
## is not a letter or a digit is dropped, so "Light Ball"
## becomes "lightball", "King's Rock" becomes "kingsrock" and
## "Liechi Berry" becomes "liechiberry". Same cleaning as
## _normalize_species_key.
static func _item_slug(item_name: String) -> String:
	var out: String = ""
	var lower: String = item_name.strip_edges().to_lower()
	for i in lower.length():
		var ch: String = lower.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

## One item's Fling row from fling_table.json, or {} when the
## item has no row (most items cannot be flung for power).
static func _fling_entry(item_name: String) -> Dictionary:
	var table: Dictionary = _fling_table()
	var key: String = _item_slug(item_name)
	if table.has(key):
		var row: Variant = table.get(key)
		if row is Dictionary:
			return row as Dictionary
	return {}

## One item's Natural Gift row from natural_gift_table.json,
## or {} when the item is not a berry with a natural gift.
static func _natural_gift_entry(item_name: String) -> Dictionary:
	var table: Dictionary = _natural_gift_table()
	var key: String = _item_slug(item_name)
	if table.has(key):
		var row: Variant = table.get(key)
		if row is Dictionary:
			return row as Dictionary
	return {}

## A mon's species as a table slug: lower case, spaces become
## hyphens, apostrophes and dots are dropped, so "Mr. Mime"
## becomes "mr-mime", "Farfetch'd" becomes "farfetchd", and
## "Nidoran♀" becomes "nidoran-f". Same idea as
## _normalize_species_key, but the hyphens are kept because the
## weight table keys have them.
static func _species_slug(mon: Dictionary) -> String:
	var raw: String = str(mon.get("species", mon.get("name", ""))).strip_edges().to_lower()
	raw = raw.replace(" ", "-").replace("'", "").replace(".", "").replace("♀", "-f").replace("♂", "-m")
	return raw

## A mon's weight in hectograms, from the weight table. The
## table holds both key styles: the hyphenated style
## ("aegislash-shield") and the Showdown style with no hyphens
## ("charizardmegax"), so after the exact key this also tries
## the key with the hyphens removed. When the exact form is
## still missing, fall back to the base form: strip everything
## from the first hyphen ("giratina-origin" tries "giratina").
## The base form itself may still be missing (the table lists
## "giratina-altered", not "giratina"), and then 0 is returned:
## unknown weight, not a real weight. The caller logs it, and
## the VariablePower ladders already define what 0 means
## (Grass Knot 20, Heavy Slam against an unknown weight 40).
static func _weight_of(mon: Dictionary) -> int:
	var table: Dictionary = _weight_table()
	if table.is_empty():
		return 0
	var key: String = _species_slug(mon)
	if table.has(key):
		return int(table.get(key, 0))
	var joined: String = key.replace("-", "")
	if joined != key and table.has(joined):
		return int(table.get(joined, 0))
	var dash: int = key.find("-")
	if dash > 0:
		var base_key: String = key.substr(0, dash)
		if table.has(base_key):
			return int(table.get(base_key, 0))
	return 0

## A mon's base Attack, from the base Attack table. Same
## base-form fallback as _weight_of. 0 means unknown, not a real
## base Attack, and Beat Up turns it into power 5 (its lowest
## value) with a log line.
static func _base_atk_of(mon: Dictionary) -> int:
	var table: Dictionary = _base_atk_table()
	if table.is_empty():
		return 0
	var key: String = _species_slug(mon)
	if table.has(key):
		return int(table.get(key, 0))
	var dash: int = key.find("-")
	if dash > 0:
		var base_key: String = key.substr(0, dash)
		if table.has(base_key):
			return int(table.get(base_key, 0))
	return 0


## One species' yield row from the table: {"id", "name",
## "base_experience", "growth_rate"}. Returns {} when the species
## is not in the table.
static func _exp_yield_entry(species: String) -> Dictionary:
	var table: Dictionary = _exp_yield_table()
	if table.is_empty():
		return {}
	var key: String = _normalize_species_key(species)
	if not table.has(key):
		return {}
	var found: Variant = table.get(key)
	if found is Dictionary:
		return found as Dictionary
	return {}

## A Pokemon's growth rate. First its own "growth_rate" field,
## then the yield table by species name. Falls back to
## "medium-fast" only when nothing is known at all — EXPSystem
## uses the same fallback, so the game never crashes on a bad name.
static func _growth_rate_for(mon: Dictionary) -> String:
	var own: String = str(mon.get("growth_rate", ""))
	if own != "":
		return own
	var entry: Dictionary = _exp_yield_entry(str(mon.get("species", "")))
	if not entry.is_empty():
		return str(entry.get("growth_rate", ""))
	return "medium-fast"

## Clean a species name into a plain lower-case key with no spaces,
## hyphens, or special marks, so "Mr. Mime", "mr-mime" and "mrmime"
## all match. Same cleaning as LearnsetResolver._normalize.
static func _normalize_species_key(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "f").replace("♂", "m")
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e")
	out = out.replace("á", "a").replace("à", "a").replace("â", "a")
	out = out.replace("í", "i").replace("ó", "o").replace("ú", "u")
	out = out.replace("ü", "u").replace("ñ", "n").replace("ç", "c")
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9"):
			clean += ch
	return clean

## Give EXP to the winning side, using the real numbers.
## The fainted Pokemon's base EXP comes from exp_yield.json
## (PokeAPI data). The gain is base EXP x fainted level / 7,
## split evenly between the earners. No EXP data for the fainted
## species means no EXP is given and a log line says so — no
## number is ever guessed.
func grant_exp(winner_party: Array, fainted: Dictionary, logs: Array) -> void:
	var fainted_name: String = _mon_name(fainted)
	var yield_entry: Dictionary = _exp_yield_entry(str(fainted.get("species", "")))
	if yield_entry.is_empty():
		logs.append("No EXP data for " + fainted_name + ", so no EXP was given.")
		return
	var base_exp: int = int(yield_entry.get("base_experience", 0))
	if base_exp <= 0:
		logs.append("No EXP data for " + fainted_name + ", so no EXP was given.")
		return
	var exp_share_on: bool = bool(battle_state.get("exp_share", false))
	var earners: Array = []
	if exp_share_on:
		for mon in winner_party:
			if int(mon.get("hp", 0)) > 0:
				earners.append(mon)
	else:
		for mon in winner_party:
			if int(mon.get("hp", 0)) > 0 and bool(mon.get("participated", false)):
				earners.append(mon)
	if earners.is_empty() and not winner_party.is_empty() and int(winner_party[0].get("hp", 0)) > 0:
		earners.append(winner_party[0])
	if earners.is_empty():
		return
	# Each earner's share goes through EXPSystem.exp_gain_for_holder,
	# so a Lucky Egg holder earns floor(share x 1.5) (the real games'
	# rule) while everyone else gets the plain even share, unchanged.
	# The obedience/badge level cap is NOT applied here: _give_exp
	# stores the full amount in mon["exp"] and clamps only the level.
	for mon in earners:
		var mon_share: int = EXPSystem.exp_gain_for_holder(base_exp, int(fainted.get("level", 5)), earners.size(), exp_share_on, str(mon.get("item", "")))
		_give_exp(mon, mon_share, logs)

## Give EXP to one Pokemon and level it up if it has earned enough.
## mon["exp"] now holds TOTAL EXP (all EXP the Pokemon has ever
## earned), not progress since its last level-up. A mon saved the
## v2 way (progress in "exp", no "exp_is_total" flag) is converted
## once: total = EXP for its current level + its saved progress.
## A mon with no "exp" key at all still only gets the log line,
## exactly like v2 did. Level 100 is the highest level. When a
## badge count has been supplied (see badge_count), the hard
## badge level cap also applies: EXP still accrues in full,
## but the level stops at the cap.
func _give_exp(mon: Dictionary, amount: int, logs: Array) -> void:
	var mon_name: String = _mon_name(mon)
	if not mon.has("exp"):
		logs.append(mon_name + " gained " + str(amount) + " EXP.")
		return
	var growth: String = _growth_rate_for(mon)
	var level: int = int(mon.get("level", 5))
	if not bool(mon.get("exp_is_total", false)):
		var old_progress: int = int(mon.get("exp", 0))
		mon["exp"] = EXPSystem.exp_for_level(growth, level) + old_progress
		mon["exp_is_total"] = true
	mon["exp"] = int(mon.get("exp", 0)) + amount
	logs.append(mon_name + " gained " + str(amount) + " EXP.")
	var new_level: int = EXPSystem.level_for_exp(growth, int(mon.get("exp", 0)))
	# Hard badge level cap (EXPSystem.BADGE_LEVEL_CAPS): when a
	# badge count has been supplied, the LEVEL stops at the cap.
	# The EXP points above already accrued in mon["exp"] either
	# way — only the level is clamped, and it is never lowered,
	# so a mon already at or above the cap simply does not level.
	var cap: int = _active_level_cap()
	var cap_clamped: bool = false
	if cap >= 0 and new_level > cap and new_level > level:
		new_level = maxi(cap, level)
		cap_clamped = true
	if new_level <= level:
		mon["exp_next"] = EXPSystem.exp_to_next_level(growth, level, int(mon.get("exp", 0)))
		if cap_clamped:
			logs.append(mon_name + " can't grow past level " + str(cap) + " without more badges.")
		return
	var old_level: int = level
	mon["level"] = new_level
	mon["exp_next"] = EXPSystem.exp_to_next_level(growth, new_level, int(mon.get("exp", 0)))
	logs.append(mon_name + " grew to level " + str(new_level) + "!")
	if cap_clamped:
		logs.append(mon_name + " can't grow past level " + str(cap) + " without more badges.")
	_check_move_learning(mon, old_level, new_level, logs)
	_check_evolution_on_level_up(mon, logs)

## Evolution on level-up, through the Evolution Manager from
## the v6 pack (class DynamicEvolutionEngine), when that file
## is in the project. The manager reads
## res://data/evolution_triggers.json itself and checks the
## level-up rows (level, friendship, held item, known move
## and the rest). Trade rows are never applied here — the
## manager flags them as needing Riley's trade rule. When the
## mon evolves, its dict is refilled in place with the evolved
## form's dict, so party arrays keep pointing at the same mon.
## When the v6 file is not in the project, this does nothing.
func _check_evolution_on_level_up(mon: Dictionary, logs: Array) -> void:
	var engine_script: GDScript = _evolution_engine_class()
	if engine_script == null:
		return
	var engine: Object = engine_script.new()
	if engine == null or not engine.has_method("on_level_up"):
		return
	var result: Dictionary = engine.on_level_up(mon, {})
	if not bool(result.get("evolved", false)):
		return
	var evolved: Dictionary = result.get("mon", {})
	if evolved.is_empty():
		return
	var old_name: String = _mon_name(mon)
	mon.clear()
	for key in evolved.keys():
		mon[key] = evolved[key]
	logs.append(old_name + " evolved into " + _mon_name(mon) + "!")

## Find the DynamicEvolutionEngine class (v6 pack), or null
## when the file is not in this project. Same global-class
## lookup as _move_forget_screen_class, with the documented
## merge path as the fallback.
static func _evolution_engine_class() -> GDScript:
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == "DynamicEvolutionEngine":
			var path: String = str(entry.get("path", ""))
			if path == "":
				return null
			return load(path)
	if FileAccess.file_exists("res://pokemon/evolution/evolution_manager.gd"):
		return load("res://pokemon/evolution/evolution_manager.gd")
	return null

## New moves on level-up, through the LearnsetResolver when it is in
## the project. A full move list (4 moves) never loses a move and
## never overwrites one: the new move is saved in
## mon["pending_learn"] so the game screen can ask the player which
## move to forget. If more than one move is waiting, the extra ones
## wait in mon["pending_learn_queue"].
func _check_move_learning(mon: Dictionary, old_level: int, new_level: int, logs: Array) -> void:
	var resolver = _learnset_resolver()
	if resolver == null:
		return
	if not resolver.has_method("get_level_up_moves"):
		return
	if not bool(resolver.is_loaded()):
		return
	var learned: Array = resolver.get_level_up_moves(str(mon.get("species", "")), old_level, new_level)
	var moves: Array = mon.get("moves", [])
	for entry in learned:
		var move_name: String = str(entry.get("move", ""))
		if move_name == "" or move_name in moves:
			continue
		if moves.size() < 4:
			moves.append(move_name)
			mon["moves"] = moves
			logs.append(_mon_name(mon) + " learned " + move_name + "!")
		elif str(mon.get("pending_learn", "")) == move_name:
			continue
		elif not mon.has("pending_learn"):
			mon["pending_learn"] = move_name
			logs.append(_mon_name(mon) + " wants to learn " + move_name + ", but it already knows 4 moves. Pick a move to forget.")
			_open_move_forget(mon)
		else:
			var queue: Array = mon.get("pending_learn_queue", [])
			if not move_name in queue:
				queue.append(move_name)
				mon["pending_learn_queue"] = queue
			logs.append(_mon_name(mon) + " wants to learn " + move_name + ", but it already knows 4 moves. Pick a move to forget.")

## Open the Move-Forget screen for a Pokemon that is waiting to
## learn a move (mon["pending_learn"]). The screen shows the 4
## current moves plus a "do not learn" button, and its choice_made
## signal settles the choice. Returns true when a screen was opened
## (or one is already open), false when there is no pending move or
## no screen file in the project.
func _open_move_forget(mon: Dictionary) -> bool:
	var pending: String = str(mon.get("pending_learn", ""))
	if pending == "":
		return false
	if move_forget_screen != null:
		return true
	var screen_class = _move_forget_screen_class()
	if screen_class == null:
		return false
	# No is_inside_tree() check here on purpose: add_child works
	# even before the tree starts (the screen enters the tree with
	# the controller), and in headless test runs is_inside_tree()
	# is false during the whole run. The screen builds its buttons
	# in _ready() when the tree starts, from the moves stored by
	# prompt_replace().
	var screen: Variant = screen_class.new()
	move_forget_screen = screen
	add_child(screen)
	screen.prompt_replace(mon.get("moves", []), pending)
	screen.choice_made.connect(_on_move_forget_chosen.bind(mon, screen))
	return true

## The player picked on the Move-Forget screen. Free the screen
## first (so a queued move can open a fresh one), then settle the
## pending move. The result lines go to move_forget_logs, which the
## game or the battle scene can read and show.
func _on_move_forget_chosen(choice_index: int, mon: Dictionary, screen: Node) -> void:
	if move_forget_screen == screen:
		move_forget_screen = null
	if screen != null:
		screen.queue_free()
	resolve_pending_learn(mon, choice_index, move_forget_logs)

## Settle the move a Pokemon is waiting to learn (mon["pending_learn"]).
## choice_index -1 means "do not learn the new move". 0..3 means
## "forget the move in that slot and learn the new one". When the
## Pokemon knows fewer than 4 moves, the new move is simply added.
## After settling, the next queued move (if any) becomes the new
## pending_learn and its screen is opened. Returns true when a
## pending move was settled, false when there was none.
func resolve_pending_learn(mon: Dictionary, choice_index: int, logs: Array) -> bool:
	var pending: String = str(mon.get("pending_learn", ""))
	if pending == "":
		return false
	var moves: Array = mon.get("moves", [])
	if choice_index < 0:
		logs.append(_mon_name(mon) + " did not learn " + pending + ".")
	elif moves.size() < 4:
		moves.append(pending)
		mon["moves"] = moves
		logs.append(_mon_name(mon) + " learned " + pending + "!")
	else:
		var old_move: String = ""
		if choice_index >= 0 and choice_index < moves.size():
			old_move = str(moves[choice_index])
		var new_moves: Array = moves.duplicate()
		var screen_class = _move_forget_screen_class()
		if screen_class != null:
			new_moves = screen_class.apply_choice(moves, pending, choice_index)
		elif choice_index >= 0 and choice_index < new_moves.size():
			new_moves[choice_index] = pending
		mon["moves"] = new_moves
		if old_move != "":
			logs.append(_mon_name(mon) + " forgot " + old_move + " and learned " + pending + "!")
		else:
			logs.append(_mon_name(mon) + " learned " + pending + "!")
	mon.erase("pending_learn")
	var queue: Array = mon.get("pending_learn_queue", [])
	if not queue.is_empty():
		mon["pending_learn"] = str(queue.pop_front())
		mon["pending_learn_queue"] = queue
		_open_move_forget(mon)
	return true

## Try to catch a wild Pokemon with a ball. Only in wild battles.
## The status bonus is the standard capture rule: sleep or freeze
## 2.0x, paralysis, burn, poison, or bad poison 1.5x, anything else
## 1.0x. The ball bonus comes from ItemEngine (Master Ball 255.0
## always catches). Returns {"caught", "chance", "logs"}.
func attempt_capture(ball_item: String, target: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var logs: Array = []
	if PUWRangerAvailability.balls_inert_in(campaign_region_id):
		# Ranger regulations: in Fiore, Almia, and Oblivia,
		# wild Pokemon are befriended with the Styler, not
		# caught. The ball does nothing and is not consumed.
		logs.append("The " + ball_item + " didn't work -- Ranger regulations. Pokemon here are befriended with the Styler, not caught.")
		return {"caught": false, "chance": 0.0, "logs": logs, "blocked_by_ranger_regulation": true}
	if not is_wild:
		logs.append("You can't catch another trainer's Pokemon!")
		return {"caught": false, "chance": 0.0, "logs": logs}
	var catch_rate := int(target.get("catch_rate", -1))
	if catch_rate < 0:
		logs.append("No catch rate is listed for this Pokemon, so the catch can't be worked out.")
		return {"caught": false, "chance": 0.0, "logs": logs}
	var status_bonus := 1.0
	match str(target.get("status", "")):
		"SLP", "FRZ":
			status_bonus = 2.0
		"PAR", "BRN", "PSN", "TOX":
			status_bonus = 1.5
	var def_types := PackedStringArray()
	for t in target.get("types", []):
		def_types.append(str(t))
	var ball_bonus: float = ItemEngine.get_ball_bonus(ball_item, def_types, int(battle_state.get("turn", 1)), false, false, bool(battle_state.get("night_or_cave", false)))
	var chance: float = PUWBattleEngine.compute_capture_chance(int(target.get("max_hp", 100)), int(target.get("hp", 1)), catch_rate, ball_bonus, status_bonus)
	var caught: bool = rng.randf() < chance
	if caught:
		logs.append("Gotcha! " + _mon_name(target) + " was caught!")
	else:
		logs.append("Oh no! " + _mon_name(target) + " broke free!")
	return {"caught": caught, "chance": chance, "logs": logs}

## Try to SNAG a Shadow Pokemon from an opposing trainer
## (Orre code prep). Legal only when the target carries the
## Shadow treatment and the player holds the Snag Machine --
## stamped into battle_state by the battle launcher from the
## story state ("snag_machine_held": bool, "snag_arc":
## "colosseum" for Wes's stolen machine, "xd" for Krane's;
## one system, the arc stamp is provenance). Refusals follow
## the source's framing as pinned by PUWShadowSystem: the ball
## is not wasted on a non-Shadow mon, and without the machine
## no snag is possible. A legal throw reuses the wild capture
## math unchanged -- the species' normal catch rate against
## the ball, as in the source -- by running attempt_capture
## with the wild gate temporarily satisfied, so the two paths
## can never drift apart. On a catch the result carries
## "snag": true and the target dict; the caller moves the mon
## into the player's party/storage (PartyAndStorageManager.
## add_pokemon) and records the snag in PUWShadowSystem's
## ledger (record_snag on the mon's shadow_origin).
func attempt_snag(ball_item: String, target: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var logs: Array = []
	var refusal: String = PUWShadowSystem.snag_refusal(target, bool(battle_state.get("snag_machine_held", false)))
	if refusal == "not_shadow":
		logs.append("That Pokemon isn't a Shadow Pokemon -- the ball would be wasted!")
		return {"caught": false, "snag": true, "refused": refusal, "chance": 0.0, "logs": logs}
	if refusal == "no_machine":
		logs.append("You can't snag a Shadow Pokemon without the Snag Machine!")
		return {"caught": false, "snag": true, "refused": refusal, "chance": 0.0, "logs": logs}
	var was_wild: bool = is_wild
	is_wild = true
	var result: Dictionary = attempt_capture(ball_item, target, rng)
	is_wild = was_wild
	result["snag"] = true
	result["target"] = target
	return result

## Handle the mons that fainted to end-of-turn damage (poison,
## burn, sandstorm, sun). Called from run_turn after _end_of_turn
## returns. player_was_alive / enemy_was_alive say which lead was
## alive BEFORE the ticks ran: a mon that already fainted to a
## move this turn is not handled again, so its EXP is never
## granted twice. Each fainted mon goes through _handle_faint
## with by_move false: EXP is granted, the next mon is sent in,
## and the field flags are synced, but no move-KO ability fires
## (Moxie, Grim Neigh, Chilling Neigh, Beast Boost, Battle Bond,
## As One). Power of Alchemy, Receiver and Soul-Heart still fire,
## because in Showdown they trigger on any faint. A mon
## sent in here takes no end-of-turn damage this turn: the ticks
## already ran.
func _handle_end_of_turn_faints(logs: Array, player_was_alive: bool, enemy_was_alive: bool) -> void:
	if player_was_alive and not player_party.is_empty() and int(player_party[0].get("hp", 0)) <= 0:
		_handle_faint(true, logs, false)
	if enemy_was_alive and not enemy_party.is_empty() and int(enemy_party[0].get("hp", 0)) <= 0:
		_handle_faint(false, logs, false)

## Doubles version of _handle_end_of_turn_faints: one alive flag
## per slot, in the order player slot 0, player slot 1, enemy slot
## 0, enemy slot 1. Each fainted slot goes through
## _handle_faint_slot with by_move false. The foe's replacement is
## sent into its slot at once; the player's side waits for the
## player to pick, the same as for a move KO.
func _handle_end_of_turn_faints_doubles(logs: Array, p0_alive: bool, p1_alive: bool, e0_alive: bool, e1_alive: bool) -> void:
	if p0_alive and not player_party.is_empty() and int(player_party[0].get("hp", 0)) <= 0:
		_handle_faint_slot(true, 0, logs, false)
	if p1_alive and player_party.size() > 1 and int(player_party[1].get("hp", 0)) <= 0:
		_handle_faint_slot(true, 1, logs, false)
	if e0_alive and not enemy_party.is_empty() and int(enemy_party[0].get("hp", 0)) <= 0:
		_handle_faint_slot(false, 0, logs, false)
	if e1_alive and enemy_party.size() > 1 and int(enemy_party[1].get("hp", 0)) <= 0:
		_handle_faint_slot(false, 1, logs, false)

## One Leech Seed drain: the seeded mon loses 1/8 of its max
## HP (at least 1). The healer (the active mon on the seeder's
## side, same slot) receives that much HP — unless the seeded
## mon has Liquid Ooze, in which case the healer TAKES that
## much damage instead, or the healer is under Heal Block, in
## which case nobody heals. The drain happens even when the
## healer is missing or fainted: the HP is simply lost.
func _apply_leech_seed(seeded: Dictionary, healer: Dictionary, logs: Array) -> void:
	var drain: int = maxi(1, int(seeded.get("max_hp", 8)) / 8)
	seeded["hp"] = maxi(0, int(seeded.get("hp", 0)) - drain)
	logs.append(_mon_name(seeded) + " lost " + str(drain) + " HP to Leech Seed!")
	if healer.is_empty() or int(healer.get("hp", 0)) <= 0:
		return
	if str(seeded.get("ability", "")) == "Liquid Ooze":
		healer["hp"] = maxi(0, int(healer.get("hp", 0)) - drain)
		logs.append(_mon_name(healer) + " was hurt by Liquid Ooze!")
		return
	if _heal_blocked(healer):
		logs.append(_mon_name(healer) + " is prevented from healing by Heal Block!")
		return
	# Big Root: the HP the healer receives is x1.3 (the seeded
	# mon still loses the base drain).
	var heal_amount: int = int(round(float(drain) * ItemEngine.drain_multiplier(healer)))
	var healed: int = mini(heal_amount, int(healer.get("max_hp", 100)) - int(healer.get("hp", 0)))
	if healed > 0:
		healer["hp"] = int(healer.get("hp", 0)) + healed
		logs.append(_mon_name(healer) + " restored " + str(healed) + " HP from Leech Seed!")

## End of turn: held items, abilities, and status damage for both
## living active Pokemon, then Dynamax running out, then the field
## timers (weather, terrain, Trick Room, screens).
func _end_of_turn(logs: Array) -> void:

	# Protect ends with the turn: clear every active mon's
	# flag now, before the end-of-turn effects run.
	_clear_protect_flags()
	# The stall chain ticks with the turn too (duration 2:
	# a chain fed this turn lives for one more turn).
	_tick_stall_chains()
	var actives: Array = []
	if not player_party.is_empty():
		actives.append(player_party[0])
	if not enemy_party.is_empty():
		actives.append(enemy_party[0])

	# Unnerve blocks the OTHER side's Berries. Work out once,
	# before the loop, whether each side has a living Unnerve (or
	# As One) holder among its active mons.
	var player_side_unnerve: bool = _side_has_unnerve(_active_side_mons(true))
	var enemy_side_unnerve: bool = _side_has_unnerve(_active_side_mons(false))
	for i in actives.size():
		var mon: Dictionary = actives[i]
		if int(mon.get("hp", 0)) <= 0:
			continue
		# actives[0] is the player's mon, actives[1] the foe's.
		var foe_has_unnerve: bool = enemy_side_unnerve if i == 0 else player_side_unnerve
		ItemEngine.on_end_of_turn(mon, field_state, logs, foe_has_unnerve)
		AbilityEngine.on_end_of_turn(mon, field_state, logs)
		logs.append_array(StatusAndFieldEngine.apply_end_of_turn(mon, field_state))
		_apply_form_change(mon, logs)
		mon["active_turns"] = int(mon.get("active_turns", 0)) + 1

		if int(mon.get("heal_block_turns", 0)) > 0:
			mon["heal_block_turns"] = int(mon.get("heal_block_turns", 0)) - 1
			if int(mon.get("heal_block_turns", 0)) <= 0:
				logs.append(_mon_name(mon) + "'s Heal Block wore off!")
		if int(mon.get("noise_heal_block_turns", 0)) > 0:
			mon["noise_heal_block_turns"] = int(mon.get("noise_heal_block_turns", 0)) - 1
			if int(mon.get("noise_heal_block_turns", 0)) <= 0:
				logs.append(_mon_name(mon) + "'s Heal Block from Psychic Noise wore off!")
	for mon in actives:
		if bool(mon.get("dynamax_active", false)):
			mon["dynamax_turns"] = int(mon.get("dynamax_turns", 1)) - 1
			if int(mon.get("dynamax_turns", 0)) <= 0:
				PUWGimmicks.end_dynamax(mon, logs)
	# Leech Seed drains after the other end-of-turn effects:
	# each seeded mon loses 1/8 of its max HP and the other
	# side's active mon receives it.
	if actives.size() == 2:
		for i in actives.size():
			var seeded_mon: Dictionary = actives[i]
			if bool(seeded_mon.get("leech_seeded", false)) and int(seeded_mon.get("hp", 0)) > 0:
				_apply_leech_seed(seeded_mon, actives[1 - i], logs)
	# Stakeout ends with the turn, and a mon that fainted to burn
	# or poison changes the fainted-ally count.
	_clear_switched_in_flags()
	_refresh_fallen_allies()
	_tick_field(logs)

func _tick_field(logs: Array) -> void:
	if int(field_state.get("weather_turns", 0)) > 0:
		field_state["weather_turns"] = int(field_state.get("weather_turns", 0)) - 1
		if int(field_state.get("weather_turns", 0)) <= 0:
			field_state["weather"] = "none"
			logs.append("The weather cleared.")
	if int(field_state.get("terrain_turns", 0)) > 0:
		field_state["terrain_turns"] = int(field_state.get("terrain_turns", 0)) - 1
		if int(field_state.get("terrain_turns", 0)) <= 0:
			field_state["terrain"] = "none"
			logs.append("The terrain faded.")
	if int(field_state.get("trick_room", 0)) > 0:
		field_state["trick_room"] = int(field_state.get("trick_room", 0)) - 1
		if int(field_state.get("trick_room", 0)) <= 0:
			logs.append("Trick Room wore off.")
	if int(field_state.get("gravity", 0)) > 0:
		field_state["gravity"] = int(field_state.get("gravity", 0)) - 1
		if int(field_state.get("gravity", 0)) <= 0:
			logs.append("Gravity returned to normal.")
	if int(field_state.get("wonder_room", 0)) > 0:
		field_state["wonder_room"] = int(field_state.get("wonder_room", 0)) - 1
		if int(field_state.get("wonder_room", 0)) <= 0:
			logs.append("Wonder Room wore off.")
	if int(field_state.get("magic_room", 0)) > 0:
		field_state["magic_room"] = int(field_state.get("magic_room", 0)) - 1
		if int(field_state.get("magic_room", 0)) <= 0:
			logs.append("Magic Room wore off.")
	for side_key in ["player_safeguard", "enemy_safeguard"]:
		if int(field_state.get(side_key, 0)) > 0:
			field_state[side_key] = int(field_state.get(side_key, 0)) - 1
			if int(field_state.get(side_key, 0)) <= 0:
				logs.append("Safeguard wore off.")
	for side_key in ["player_screens", "enemy_screens"]:
		var screens: Dictionary = field_state.get(side_key, {})
		var changed := false
		for screen_key in ["reflect", "light_screen", "aurora_veil", "tailwind"]:
			if int(screens.get(screen_key, 0)) > 0:
				screens[screen_key] = int(screens.get(screen_key, 0)) - 1
				changed = true
		if changed:
			field_state[side_key] = screens
