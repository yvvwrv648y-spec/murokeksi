class_name PUWVexaSimulator
extends RefCounted
## VEXA — holographic welcome-trainer battle simulator (Godot port of
## the vexa_spec in PUW_CUSTOM_WORK_BUNDLE_20261122.json).
##
## What VEXA does: on the pad in Oak's Lab, the player picks a level
## (5-100, or 50 flat in VGC), a format, a shiny toggle, and either a
## dynamic super-effective COUNTER team or one chosen opponent
## species, then fights a SAFE simulation: isSimulation=true suspends
## permanent fainting and real-party evolution (spec safety_rule).
##
## Every option actually changes the battle that runs, and the tests
## in tests/integration_vexa_tests.gd prove each one:
## - level pick: built enemy mons are at that level (VGC forces 50).
## - format pick: singles/doubles run the matching controller path;
##   vgc runs PUWBattleFormats.vgc_select_team (bring 6 pick 4, Lv.50
##   flat) into a doubles battle; sky gates both teams through
##   PUWBattleFormats.sky_battle_check; inverse runs the engine's
##   "inverse_battle" format id (flipped type chart).
## - counter vs chosen: counter builds a team whose types are
##   super-effective against the player's actual party (real type
##   chart in PUWBattleEngine.TYPE_CHART); chosen builds a team led
##   by the one species the player named. The two teams differ.
## - shiny toggle: when on, every sim mon carries shiny=true; when
##   off, none does. The real party is never touched either way.
##
## COMPOSED G4 STATE (binding-build target, staged by
## code_prep_vexa_raid/composed/): ALL NINE formats are built and
## NOT_YET_BUILT_FORMATS is empty. This file is the union of the
## raid prep's simulator patch (tera_raid) and the formats prep's
## simulator patch (triple/rotation) -- see that prep's step 3
## composition rules, which this file follows exactly.
##
## Triple and Rotation Battles are BUILT (code prep
## code_prep_vexa_formats): run_triple() runs PUWTripleBattle
## (three active per side, placement-based targeting in
## PUWTripleTargeting, shifting) and run_rotation() runs
## PUWRotationBattle (three fielded, one active, free rotation).
##
## tera_raid IS built (gap G4): a Max Raid-style 4-Trainer raid
## run by PUWRaidBattle (see run_raid), with the Dynamax
## Adventures run structure in PUWRaidRun (see run_raid_run).
## Max Raid Battles are the primary design reference and
## Dynamax Adventures the run-structure half, per
## hidden_files/gen78_modes_transport/GEN78_MODES_TRANSPORT.md.
## The format id is "tera_raid" but NO Terastallization mechanic
## runs in it: canon compliance is documented in
## code_prep_vexa_raid/PREP_REPORT.md (canon section).
##
## Formats the engine cannot run are NEVER faked: an id that is
## not built returns format_status() "unknown_format" and
## run_simulation() refuses it with status "unknown_format".
##
## SAFETY (the critical rule): run_simulation() snapshots the live
## party through PUWSaveManager.build_state BEFORE the sim, then
## battles with deep copies only (duplicate(true)). It never calls
## PartyAndStorageManager.handle_faint, never saves, and never
## writes back. A mon fainting or levelling past an evolution
## trigger inside the sim therefore cannot change the real party,
## the save state, or any permadeath / family-lockout record. The
## returned dict carries "snapshot_unchanged" so callers can check.

const BUILT_FORMATS: Dictionary = {
	"singles": "singles",
	"doubles": "doubles",
	"vgc": "doubles",
	"sky": "singles",
	"inverse": "inverse_battle",
	"tera_raid": "raid",
	"triple": "triple",
	"rotation": "rotation",
}
const NOT_YET_BUILT_FORMATS: Array = []

## DESIGN CONSTANT: default raid star rating when the caller
## does not pass one (star 1-5 is the sourced Max Raid scale;
## the default itself is a VEXA presentation choice).
const DEFAULT_RAID_STAR: int = 3

var _builder: PUWTeamBuilder = null
var _host: Node = null


## The simulator creates a BattleController (a Node), so it needs a
## host inside the scene tree. Tests pass root; the game passes the
## battle scene.
func setup(host: Node) -> void:
	_host = host


func _team_builder() -> PUWTeamBuilder:
	if _builder == null:
		_builder = PUWTeamBuilder.new()
	return _builder


func supported_formats() -> Array:
	return ["singles", "doubles", "vgc", "sky", "inverse", "tera_raid", "triple", "rotation"]


func format_status(format_id: String) -> String:
	if BUILT_FORMATS.has(format_id):
		return "built"
	if format_id in NOT_YET_BUILT_FORMATS:
		return "not_yet_built"
	return "unknown_format"


## Engine format id a VEXA format maps to ("" when not built).
func engine_format(format_id: String) -> String:
	return str(BUILT_FORMATS.get(format_id, ""))


## A team of species whose typing is super-effective against the
## player's team, computed from PUWBattleEngine.TYPE_CHART (the real
## chart the damage calculator uses). A species scores by summing,
## over every player mon, the best effectiveness any of the
## species' types has against that mon's types; only species with a
## positive score (super-effective against at least one player mon)
## are eligible. Ranking is deterministic: score desc, then slug.
## The pool is the 1,025 species with sourced types in
## competitive_sets.json. Mons are built by PUWTeamBuilder at the
## chosen level (auto-evolved, 31 IVs, capped EVs, real sets).
func build_counter_team(player_party: Array, level: int, rng: RandomNumberGenerator) -> Array:
	var builder: PUWTeamBuilder = _team_builder()
	builder._ensure_loaded()
	var scored: Array = []
	for slug_v in builder._species.keys():
		var slug: String = str(slug_v)
		var types: Array = builder.species_types(slug)
		if types.is_empty():
			continue
		var score: float = 0.0
		for mon_v in player_party:
			if mon_v is Dictionary:
				var mon: Dictionary = mon_v
				var def_types: Array = mon.get("types", [])
				if def_types.is_empty():
					continue
				var packed := PackedStringArray()
				for t in def_types:
					packed.append(str(t))
				var best: float = 0.0
				for t2 in types:
					var eff: float = PUWBattleEngine.type_multiplier(str(t2), packed)
					if eff > best:
						best = eff
				if best > 1.0:
					score += best
		if score > 0.0:
			scored.append({"slug": slug, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["score"]) != float(b["score"]):
			return float(a["score"]) > float(b["score"])
		return str(a["slug"]) < str(b["slug"])
	)
	var team: Array = []
	var used_evolved: Dictionary = {}
	for entry_v in scored:
		if team.size() >= 6:
			break
		var slug2: String = str((entry_v as Dictionary).get("slug", ""))
		var evolved: String = builder.resolve_evolved_species(slug2, level)
		if used_evolved.has(evolved):
			continue
		used_evolved[evolved] = true
		team.append(builder.build_mon(slug2, level, "singles"))
	return team


## Team for the "chosen opponent" option: a 6-mon team led by the
## named species, filled by PUWTeamBuilder's shared-type rule.
func build_chosen_team(species_name: String, level: int, mode: String, rng: RandomNumberGenerator) -> Array:
	var builder: PUWTeamBuilder = _team_builder()
	var clamped: int = clampi(level, 5, 100)
	# build_trainer_team scales to player_max; passing the chosen
	# level as player_max gives mons exactly at that level.
	return builder.build_trainer_team([species_name], clamped, mode, rng)


## Run one safe simulation.
## options: {
##   "format": "singles" (default) | "doubles" | "vgc" | "sky" | "inverse" | "tera_raid" | "triple" | "rotation",
##   "level": int 5..100 (default 50; VGC always forces 50 flat),
##   "shiny": bool (default false),
##   "opponent": "counter" (default) | a species name/slug,
##   "seed": int (default 12345),
##   "player_party": the live party is the first argument instead.
## }
## player_party is the LIVE party: it is snapshotted and deep-copied,
## never battled directly. Returns {status, turns, format,
## engine_format, enemy_species, snapshot_unchanged, snapshot_before,
## snapshot_after} where status mirrors the controller ("player_won",
## "enemy_won", ...) or a refusal ("not_yet_built", "no_host",
## "sky_ineligible").
func run_simulation(player_party: Array, options: Dictionary) -> Dictionary:
	if _host == null:
		return {"status": "no_host", "reason": "Call setup(host) with a Node in the tree first."}
	var format_id: String = str(options.get("format", "singles"))
	if format_status(format_id) == "not_yet_built":
		return {"status": "not_yet_built", "format": format_id}
	if format_status(format_id) != "built":
		return {"status": "unknown_format", "format": format_id}
	if format_id == "tera_raid":
		return run_raid(player_party, options)
	if format_id == "triple":
		return run_triple(player_party, options)
	if format_id == "rotation":
		return run_rotation(player_party, options)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 12345))
	var level: int = clampi(int(options.get("level", 50)), 5, 100)
	if format_id == "vgc":
		level = 50
	var shiny: bool = bool(options.get("shiny", false))
	var mode: String = "vgc" if format_id == "vgc" else "singles"

	# SAFETY SNAPSHOT: the live party packed through the real save
	# manager before anything is copied or battled.
	var snapshot_before: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var before_text: String = JSON.stringify(snapshot_before)

	# Deep copies only from here on. The live dicts are never handed
	# to the controller.
	var sim_player: Array = player_party.duplicate(true)
	var opponent: String = str(options.get("opponent", "counter"))
	var sim_enemy: Array = []
	if opponent == "counter":
		sim_enemy = build_counter_team(sim_player, level, rng)
	else:
		sim_enemy = build_chosen_team(opponent, level, mode, rng)
	if format_id == "vgc":
		var picked: Dictionary = PUWBattleFormats.vgc_select_team(sim_enemy, [0, 1, 2, 3])
		if bool(picked.get("ok", false)):
			sim_enemy = picked.get("team", sim_enemy)
	if shiny:
		for party in [sim_player, sim_enemy]:
			for mon_v in party:
				(mon_v as Dictionary)["shiny"] = true
	if format_id == "sky":
		var check_p: Dictionary = PUWBattleFormats.sky_battle_check(sim_player)
		var check_e: Dictionary = PUWBattleFormats.sky_battle_check(sim_enemy)
		if not bool(check_p.get("ok", false)) or not bool(check_e.get("ok", false)):
			return {"status": "sky_ineligible", "format": format_id,
				"refused_player": check_p.get("refused", []), "refused_enemy": check_e.get("refused", []),
				"snapshot_unchanged": JSON.stringify(PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})) == before_text}

	var controller := BattleController.new()
	_host.add_child(controller)
	var eng_format: String = engine_format(format_id)
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var start: Dictionary = controller.start_battle(sim_player, sim_enemy, eng_format, true)
	if str(start.get("status", "")) != "started":
		controller.queue_free()
		return {"status": "not_started", "format": format_id}
	var status: String = "ongoing"
	var turns: int = 0
	if eng_format == "doubles":
		status = _drive_doubles(controller, field)
		turns = int(controller.battle_state.get("turn", 0))
	else:
		var result: Dictionary = _drive_singles(controller, field)
		status = str(result.get("status", "ongoing"))
		turns = int(result.get("turns", 0))
	var enemy_species: Array = []
	for mon_v in sim_enemy:
		enemy_species.append(str((mon_v as Dictionary).get("species", "")))
	controller.queue_free()
	var snapshot_after: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	return {
		"status": status, "turns": turns, "format": format_id,
		"engine_format": eng_format, "enemy_species": enemy_species,
		"enemy_team": sim_enemy, "player_team": sim_player,
		"snapshot_unchanged": JSON.stringify(snapshot_after) == before_text,
		"snapshot_before": before_text, "snapshot_after": JSON.stringify(snapshot_after),
	}


var _move_db: MoveDatabase = null


func _pick_move(mon: Dictionary, foe: Dictionary) -> String:
	# First move that is not immune against the foe's types (checked
	# on the real chart); falls back to the first move. A sim driver
	# that only ever uses move 1 can stall forever on an immunity
	# (Thunderbolt vs a Ground counter team), which is a driver
	# artifact, not a battle result.
	if _move_db == null:
		_move_db = MoveDatabase.new()
		_move_db.load_database()
	var moves: Array = mon.get("moves", [])
	if moves.is_empty():
		return ""
	var foe_types := PackedStringArray()
	for t in foe.get("types", []):
		foe_types.append(str(t))
	for m in moves:
		var md: Dictionary = _move_db.get_move(str(m))
		if int(md.get("power", 0)) <= 0:
			continue
		if PUWBattleEngine.type_multiplier(str(md.get("type", "Normal")), foe_types) > 0.0:
			return str(m)
	return str(moves[0])


## Singles driver: mirrors how battle_tests.gd drives battles —
## a legal damaging move every turn (see _pick_move), switch to the
## next living mon when the controller flags player_must_switch.
func _drive_singles(controller: BattleController, field: Dictionary) -> Dictionary:
	var status: String = "ongoing"
	var turns: int = 0
	var need_switch: bool = false
	while turns < 200:
		turns += 1
		var action: Dictionary = {}
		if need_switch:
			var idx: int = -1
			for i in range(1, controller.player_party.size()):
				if int((controller.player_party[i] as Dictionary).get("hp", 0)) > 0:
					idx = i
					break
			if idx < 0:
				break
			action = {"type": "switch", "target_idx": idx}
		else:
			var active: Dictionary = controller.player_party[0]
			var foe: Dictionary = controller.enemy_party[0]
			var picked: String = _pick_move(active, foe)
			if picked.is_empty():
				break
			action = {"type": "move", "move_name": picked}
		var result: Dictionary = controller.run_turn(action, field)
		status = str(result.get("status", "ongoing"))
		need_switch = bool(controller.battle_state.get("player_must_switch", false))
		if status in ["player_won", "enemy_won", "fled", "caught", "no_battle"]:
			break
	return {"status": status, "turns": turns}


func _drive_doubles(controller: BattleController, field: Dictionary) -> String:
	var status: String = "ongoing"
	var turns: int = 0
	while turns < 200:
		turns += 1
		var actions: Array = []
		for slot in range(2):
			if slot < controller.player_party.size():
				var mon: Dictionary = controller.player_party[slot]
				var moves: Array = mon.get("moves", [])
				if int(mon.get("hp", 0)) > 0 and not moves.is_empty():
					actions.append({"type": "move", "move_name": str(moves[0])})
				else:
					actions.append({"type": "none"})
		var result: Dictionary = controller.run_turn_doubles(actions, field)
		status = str(result.get("status", "ongoing"))
		if status in ["player_won", "enemy_won", "fled", "caught", "no_battle", "must_switch"]:
			break
	return status


## Run one raid simulation (format "tera_raid", gap G4): a
## Max Raid-style battle — 4 Trainers vs 1 Dynamaxed boss —
## run by PUWRaidBattle. Raids live inside VEXA, so the
## permadeath exemption covers them exactly as it covers every
## other sim: the same snapshot discipline as run_simulation()
## (snapshot the live party through PUWSaveManager BEFORE the
## battle, battle with deep copies only, never write back, a
## raid faint retires nothing and records nothing).
##
## Extra options beyond run_simulation()'s:
##   "boss": species name/slug for the den boss (default: the
##     "opponent" option; "counter" builds a boss that counters
##     the player's party, via build_counter_team's top pick),
##   "star": int 1-5 (default DEFAULT_RAID_STAR),
##   "co_op_parties": Array of up to 3 extra live parties whose
##     lead mons fill raider slots 1-3 as co-op partners; they
##     are deep-copied too and never mutated. Remaining slots
##     are NPC Support Trainers (sourced Max Raid rule: empty
##     slots are filled by NPC Support Trainers), built to
##     counter the boss.
## The player brings exactly one Pokemon (sourced): their
## party's lead. The result mirrors run_simulation()'s shape,
## plus a "raid" key with PUWRaidBattle.battle_result().
func run_raid(player_party: Array, options: Dictionary) -> Dictionary:
	if _host == null:
		return {"status": "no_host", "reason": "Call setup(host) with a Node in the tree first."}
	if player_party.is_empty():
		return {"status": "no_party", "format": "tera_raid"}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 12345))
	var level: int = clampi(int(options.get("level", 50)), 5, 100)
	var shiny: bool = bool(options.get("shiny", false))
	var star: int = clampi(int(options.get("star", DEFAULT_RAID_STAR)), 1, 5)
	var builder: PUWTeamBuilder = _team_builder()

	# SAFETY SNAPSHOT: identical discipline to run_simulation().
	var snapshot_before: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var before_text: String = JSON.stringify(snapshot_before)

	var sim_player: Array = player_party.duplicate(true)
	var boss_choice: String = str(options.get("boss", options.get("opponent", "counter")))
	var boss_mon: Dictionary = {}
	if boss_choice == "counter":
		var counters: Array = build_counter_team(sim_player, level, rng)
		if counters.is_empty():
			return {"status": "not_started", "format": "tera_raid", "snapshot_unchanged": true}
		boss_mon = (counters[0] as Dictionary).duplicate(true)
	else:
		boss_mon = builder.build_mon(boss_choice, level, "singles")
	if boss_mon.is_empty():
		return {"status": "not_started", "format": "tera_raid", "snapshot_unchanged": true}

	# Raider slot 0: the player's one entry — their lead mon.
	var entries: Array = []
	var player_entry: Dictionary = (sim_player[0] as Dictionary).duplicate(true)
	entries.append({"trainer": "Player", "is_player": true, "mon": player_entry})
	# Slots 1-3: co-op partners' leads when provided...
	var co_op: Array = options.get("co_op_parties", [])
	for party_v in co_op:
		if entries.size() >= PUWRaidBattle.RAIDER_COUNT:
			break
		var party: Array = party_v
		if party.is_empty():
			continue
		var lead: Dictionary = (party[0] as Dictionary).duplicate(true)
		entries.append({"trainer": "Co-op Trainer", "is_player": true, "mon": lead})
	# ...then NPC Support Trainers built to counter the boss.
	if entries.size() < PUWRaidBattle.RAIDER_COUNT:
		var support: Array = build_counter_team([boss_mon], level, rng)
		for mon_v in support:
			if entries.size() >= PUWRaidBattle.RAIDER_COUNT:
				break
			var mon: Dictionary = (mon_v as Dictionary).duplicate(true)
			entries.append({"trainer": "Support Trainer", "is_player": false, "mon": mon})
	while entries.size() < PUWRaidBattle.RAIDER_COUNT:
		var filler: Dictionary = builder.build_mon("eevee", level, "singles")
		entries.append({"trainer": "Support Trainer", "is_player": false, "mon": filler})
	if shiny:
		boss_mon["shiny"] = true
		for e_v in entries:
			var e: Dictionary = e_v
			var m: Dictionary = e.get("mon", {})
			m["shiny"] = true

	var raid := PUWRaidBattle.new()
	raid.setup_raid(boss_mon, entries, star, rng)
	while not raid.is_over():
		var actions: Array = []
		for i in range(entries.size()):
			var action: Dictionary = raid.choose_action(i)
			# Driver policy: the Dynamax holder Dynamaxes on its
			# first opportunity (the rotation itself is sourced;
			# taking it immediately is the driver's choice).
			if i == raid.dynamax_holder() and not raid.dynamax_spent():
				action["dynamax"] = true
			actions.append(action)
		raid.run_round(actions)
	var result: Dictionary = raid.battle_result()
	var snapshot_after: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var player_team: Array = []
	var enemy_team: Array = [raid.boss]
	for e_v2 in raid.raiders:
		var e2: Dictionary = e_v2
		player_team.append(e2.get("mon", {}))
	return {
		"status": str(result.get("status", "ongoing")),
		"turns": int(result.get("turns", 0)),
		"format": "tera_raid",
		"engine_format": engine_format("tera_raid"),
		"enemy_species": [str(result.get("boss_species", ""))],
		"enemy_team": enemy_team,
		"player_team": player_team,
		"snapshot_unchanged": JSON.stringify(snapshot_after) == before_text,
		"snapshot_before": before_text,
		"snapshot_after": JSON.stringify(snapshot_after),
		"raid": result,
	}


## Run a full Dynamax Adventures raid run (PUWRaidRun): rental
## entry, branching path, HP carry-over, shared hearts, keep
## exactly one catch at the end. Same snapshot safety as every
## VEXA sim — the run is built from rentals and deep copies, so
## the real party is never even read for mons, only snapshotted.
##
## Extra options: "rental_pick" (int, which of the 3 offered
## rentals the player takes; default 0), "player_mon" (a mon
## dict to enter with instead of a rental — deep-copied),
## "path_picks" (Array of path indices, one per battle; missing
## picks default to 0), "scientist_swap" (bool), "swap_catch"
## (bool: swap slot 0 for the fresh catch after each win),
## "keep_species" (display name of the catch to keep; default:
## the first catch), "endless" / "prior_clears" (PUWRaidRun).
## Returns the run_simulation()-shaped dict (status mapped:
## cleared -> "player_won", failed -> "enemy_won") plus "run"
## with PUWRaidRun.finish()'s settlement.
func run_raid_run(player_party: Array, options: Dictionary) -> Dictionary:
	if _host == null:
		return {"status": "no_host", "reason": "Call setup(host) with a Node in the tree first."}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 12345))
	var level: int = clampi(int(options.get("level", 50)), 5, 100)
	var builder: PUWTeamBuilder = _team_builder()

	var snapshot_before: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var before_text: String = JSON.stringify(snapshot_before)

	var run := PUWRaidRun.new()
	var entry_mon: Dictionary = {}
	if options.has("player_mon"):
		entry_mon = (options.get("player_mon", {}) as Dictionary).duplicate(true)
	else:
		# SOURCED: rentals only — pick 1 of 3 offered.
		var offers: Array = run.offer_rentals(builder, level, rng)
		if offers.is_empty():
			return {"status": "not_started", "format": "tera_raid", "snapshot_unchanged": true}
		var pick: int = clampi(int(options.get("rental_pick", 0)), 0, offers.size() - 1)
		entry_mon = offers[pick]
	var started: Dictionary = run.start({
		"builder": builder, "rng": rng, "level": level,
		"star": clampi(int(options.get("star", DEFAULT_RAID_STAR)), 1, 5),
		"player_mon": entry_mon,
		"endless": bool(options.get("endless", false)),
		"prior_clears": int(options.get("prior_clears", 0)),
	})
	if str(started.get("status", "")) != "started":
		return {"status": str(started.get("status", "not_started")), "format": "tera_raid", "snapshot_unchanged": true}
	var path_picks: Array = options.get("path_picks", [])
	var battles: Array = []
	var battle_no: int = 0
	while run.status == "in_progress":
		var pick_idx: int = 0
		if battle_no < path_picks.size():
			pick_idx = int(path_picks[battle_no])
		run.choose_path(pick_idx)
		var battle_result: Dictionary = run.fight_current_battle()
		battles.append(battle_result)
		battle_no += 1
		if run.status == "in_progress":
			run.roll_path_event(bool(options.get("scientist_swap", false)))
			if bool(options.get("swap_catch", false)):
				run.swap_for_catch(0)
		if battle_no > 50:
			break
	var keep: String = str(options.get("keep_species", ""))
	if keep == "" and not run.catches.is_empty():
		keep = str(run.catches[0])
	var settlement: Dictionary = run.finish(keep)
	var snapshot_after: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var mapped: String = "player_won" if run.status == "cleared" else "enemy_won"
	return {
		"status": mapped,
		"turns": battle_no,
		"format": "tera_raid",
		"engine_format": engine_format("tera_raid"),
		"enemy_species": run.catches.duplicate(),
		"snapshot_unchanged": JSON.stringify(snapshot_after) == before_text,
		"snapshot_before": before_text,
		"snapshot_after": JSON.stringify(snapshot_after),
		"run": settlement,
		"battles": battles,
	}


## One safe Triple Battle simulation (format "triple"). Same
## safety contract as run_simulation(): the live party is
## snapshotted through PUWSaveManager.build_state first, the
## battle runs on deep copies in PUWTripleBattle (copy_mons
## false — the sim copies made here are the battle's mons, so
## the returned teams show the final state), and nothing is
## written back. The player's slots are driven by
## PUWTripleBattle.choose_ai_action, the same brain the enemy
## uses; shifting is a runner mechanic, exercised directly in
## the runner's own tests. Options are the same as
## run_simulation()'s (level clamped 5..100; the format has no
## flat-level rule). Returns run_simulation()'s shape plus a
## "triple" key holding PUWTripleBattle.battle_result().
func run_triple(player_party: Array, options: Dictionary) -> Dictionary:
	if _host == null:
		return {"status": "no_host", "reason": "Call setup(host) with a Node in the tree first."}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 12345))
	var level: int = clampi(int(options.get("level", 50)), 5, 100)
	var shiny: bool = bool(options.get("shiny", false))
	var snapshot_before: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var before_text: String = JSON.stringify(snapshot_before)
	var sim_player: Array = player_party.duplicate(true)
	var opponent: String = str(options.get("opponent", "counter"))
	var sim_enemy: Array = []
	if opponent == "counter":
		sim_enemy = build_counter_team(sim_player, level, rng)
	else:
		sim_enemy = build_chosen_team(opponent, level, "singles", rng)
	if shiny:
		for party in [sim_player, sim_enemy]:
			for mon_v in party:
				(mon_v as Dictionary)["shiny"] = true
	var battle := PUWTripleBattle.new()
	var setup: Dictionary = battle.setup_battle(sim_player, sim_enemy, rng, false)
	if str(setup.get("status", "")) != "started":
		return {"status": "not_started", "format": "triple",
			"snapshot_unchanged": JSON.stringify(PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})) == before_text}
	var guard: int = 0
	while not battle.is_over() and guard < 200:
		guard += 1
		battle.run_turn(_triple_player_actions(battle))
	var enemy_species: Array = []
	for mon_v in sim_enemy:
		enemy_species.append(str((mon_v as Dictionary).get("species", "")))
	var snapshot_after: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	return {
		"status": battle.status, "turns": battle.turn, "format": "triple",
		"engine_format": "triple", "enemy_species": enemy_species,
		"enemy_team": sim_enemy, "player_team": sim_player,
		"snapshot_unchanged": JSON.stringify(snapshot_after) == before_text,
		"snapshot_before": before_text, "snapshot_after": JSON.stringify(snapshot_after),
		"triple": battle.battle_result(),
	}


## One safe Rotation Battle simulation (format "rotation").
## Same safety contract as run_triple(); the player's turns are
## driven by _rotation_player_action (rotate when the runner's
## own suggestion strictly improves the matchup, then attack
## with _pick_move). Returns run_simulation()'s shape plus a
## "rotation" key holding PUWRotationBattle.battle_result().
func run_rotation(player_party: Array, options: Dictionary) -> Dictionary:
	if _host == null:
		return {"status": "no_host", "reason": "Call setup(host) with a Node in the tree first."}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 12345))
	var level: int = clampi(int(options.get("level", 50)), 5, 100)
	var shiny: bool = bool(options.get("shiny", false))
	var snapshot_before: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	var before_text: String = JSON.stringify(snapshot_before)
	var sim_player: Array = player_party.duplicate(true)
	var opponent: String = str(options.get("opponent", "counter"))
	var sim_enemy: Array = []
	if opponent == "counter":
		sim_enemy = build_counter_team(sim_player, level, rng)
	else:
		sim_enemy = build_chosen_team(opponent, level, "singles", rng)
	if shiny:
		for party in [sim_player, sim_enemy]:
			for mon_v in party:
				(mon_v as Dictionary)["shiny"] = true
	var battle := PUWRotationBattle.new()
	var setup: Dictionary = battle.setup_battle(sim_player, sim_enemy, rng, false)
	if str(setup.get("status", "")) != "started":
		return {"status": "not_started", "format": "rotation",
			"snapshot_unchanged": JSON.stringify(PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})) == before_text}
	var guard: int = 0
	while not battle.is_over() and guard < 200:
		guard += 1
		battle.run_turn(_rotation_player_action(battle))
	var enemy_species: Array = []
	for mon_v in sim_enemy:
		enemy_species.append(str((mon_v as Dictionary).get("species", "")))
	var snapshot_after: Dictionary = PUWSaveManager.build_state(player_party, [], {}, 0, [], [], [], {})
	return {
		"status": battle.status, "turns": battle.turn, "format": "rotation",
		"engine_format": "rotation", "enemy_species": enemy_species,
		"enemy_team": sim_enemy, "player_team": sim_player,
		"snapshot_unchanged": JSON.stringify(snapshot_after) == before_text,
		"snapshot_before": before_text, "snapshot_after": JSON.stringify(snapshot_after),
		"rotation": battle.battle_result(),
	}


## Triple driver: one action per player slot from the runner's
## own AI (the same brain the enemy side uses).
func _triple_player_actions(battle: PUWTripleBattle) -> Array:
	var actions: Array = []
	for slot in range(3):
		actions.append(battle.choose_ai_action(true, slot))
	return actions


## Rotation driver: rotate when the runner's suggestion strictly
## improves the matchup (or when forced — the suggestion always
## names a living mon), then attack with _pick_move from the
## (possibly new) active.
func _rotation_player_action(battle: PUWRotationBattle) -> Dictionary:
	var action: Dictionary = {}
	var active: Dictionary = battle.active_mon(true)
	if int(active.get("hp", 0)) <= 0:
		var idx: int = battle.suggest_rotation(true)
		action["rotate_to"] = idx
		var incoming: Dictionary = {}
		if idx >= 0 and idx < battle.player_fielded.size():
			incoming = battle.player_fielded[idx]
		var picked: String = _pick_move(incoming, battle.active_mon(false))
		if not picked.is_empty():
			action["move_name"] = picked
		return action
	var suggest: int = battle.suggest_rotation(true)
	if suggest != battle.player_active_idx and suggest >= 0 and suggest < battle.player_fielded.size():
		action["rotate_to"] = suggest
		active = battle.player_fielded[suggest]
	var picked2: String = _pick_move(active, battle.active_mon(false))
	if not picked2.is_empty():
		action["move_name"] = picked2
	return action
