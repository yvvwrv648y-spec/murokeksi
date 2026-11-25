extends SceneTree
## End-to-end smoke test for Pokemon Ultimate World: the full
## loop, run headless in the merged project (RC1 + v3 + v4 +
## v5 packs overlaid at their target paths, data in
## res://data/).
##
## The loop it walks:
##   1. Boot the main scene (res://scenes/main.tscn). It must
##      hand over to the Overworld scene on its own, through
##      PUWSceneTransition.
##   2. In the overworld, take steps in tall grass through
##      OverworldLoop until a wild encounter triggers. The RNG
##      is seeded, and the test area carries its own
##      "encounter_rate" of 1.0 (designer data — the engine
##      ships no built-in rate), so the first step triggers.
##      The species is rolled from the REAL encounter data
##      (res://data/encounters_1025.json) for one real area.
##   3. Move into the Battle scene the same way the Overworld
##      scene does (pending parties on BattleScene), seed the
##      battle, and press the first move until the battle ends
##      in a win or a faint.
##   4. Move back to the Overworld scene.
##
## Run it with:
##   godot --headless --script res://tests/smoke_test.gd
## It prints one STAGE PASS or STAGE FAIL line per stage, then
## a summary, then quits. Exit code 0 means the whole loop
## ran; 1 means a stage failed (the line says how far it got).

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_run.call_deferred()


func _ok(stage: String, ok: bool, detail: String = "") -> bool:
	if ok:
		_passed += 1
		print("STAGE PASS: " + stage)
	else:
		_failed += 1
		print("STAGE FAIL: " + stage + (" — " + detail if detail != "" else ""))
	return ok


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("PUW smoke test — starting.")
	if root == null:
		print("STAGE FAIL: boot — no scene tree root.")
		quit(1)
		return

	# ---- Stage 1: main scene boots into the overworld. ----
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	if not _ok("main scene loads", main_packed != null):
		_finish()
		return
	change_scene_to_packed(main_packed)
	await _frames(4)
	var booted_path: String = ""
	if current_scene != null:
		booted_path = current_scene.scene_file_path
	if not _ok("main scene boots into overworld", booted_path == "res://scenes/overworld.tscn", "current scene is " + booted_path):
		_finish()
		return

	# ---- Stage 2: tall-grass steps through OverworldLoop. ----
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var area_data: Dictionary = _first_walk_area()
	if not _ok("real encounter area found", not area_data.is_empty()):
		_finish()
		return
	var rows: Array = area_data.get("rows", [])
	var area_name: String = str(area_data.get("location_area_name", ""))
	# The area carries the designer's rate (1.0 = every step),
	# so the seeded walk triggers on the first step.
	var step_area: Dictionary = {"location_area_name": area_name, "encounter_rate": 1.0}
	var chance: float = OverworldLoop.step_encounter_chance("tall_grass", step_area)
	if not _ok("area encounter rate is read from the area data", chance == 1.0, "chance was " + str(chance)):
		_finish()
		return
	var encounter: Dictionary = {}
	var steps: int = 0
	while steps < 100 and encounter.is_empty():
		steps += 1
		if rng.randf() < chance:
			encounter = OverworldLoop.roll_encounter(rows, rng)
	if not _ok("encounter triggers in tall grass", not encounter.is_empty(), "no encounter in 100 steps"):
		_finish()
		return
	print("  encounter after %d step(s): %s at level %d (area %s)." % [steps, str(encounter.get("species", "")), int(encounter.get("level", 0)), area_name])

	# ---- Stage 3: into a battle, played to a win or a faint. ----
	var target_path: String = PUWSceneTransition.resolve_target("overworld", "wild_encounter")
	if not _ok("transition resolves overworld -> battle", target_path == "res://scenes/battle.tscn", "resolved to " + target_path):
		_finish()
		return
	var wild: Dictionary = _wild_mon(encounter)
	BattleScene.pending_player_party = PartyScene.party.duplicate(true)
	BattleScene.pending_enemy_party = [wild]
	change_scene_to_file(target_path)
	await _frames(4)
	if current_scene == null or current_scene.scene_file_path != "res://scenes/battle.tscn":
		_ok("battle scene loads", false, "current scene did not become the battle scene")
		_finish()
		return
	_ok("battle scene loads", true)
	var battle_scene: BattleScene = current_scene as BattleScene
	battle_scene.controller.rng.seed = 99
	var turns: int = 0
	while not battle_scene.battle_over and turns < 60:
		# Build 6: the presentation stack (VS intro, throw, move
		# animation) swallows move presses while it plays — the
		# driver waits for the scene to accept input before each
		# press, with a frame budget so a wedged animation fails
		# honestly instead of hanging.
		var waited: int = 0
		while not battle_scene.battle_over and waited < 900 \
				and (battle_scene._intro_active or battle_scene._animating):
			await _frames(1)
			waited += 1
		if battle_scene.battle_over:
			break
		battle_scene._on_move_pressed(0)
		turns += 1
		await _frames(1)
	if not _ok("battle runs to a win or a faint", battle_scene.battle_over, "still running after %d turns" % turns):
		_finish()
		return
	var lead: Dictionary = battle_scene.controller.player_party[0] if not battle_scene.controller.player_party.is_empty() else {}
	var foe: Dictionary = battle_scene.controller.enemy_party[0] if not battle_scene.controller.enemy_party.is_empty() else {}
	print("  battle ended after %d turn(s): player lead %s at %d HP, wild %s at %d HP." % [turns, str(lead.get("name", "")), int(lead.get("hp", 0)), str(foe.get("name", "")), int(foe.get("hp", 0))])

	# ---- Stage 4: back to the overworld. ----
	var back_path: String = PUWSceneTransition.resolve_target("battle", "battle_won")
	if not _ok("transition resolves battle -> overworld", back_path == "res://scenes/overworld.tscn", "resolved to " + back_path):
		_finish()
		return
	change_scene_to_file(back_path)
	await _frames(4)
	var back_ok: bool = current_scene != null and current_scene.scene_file_path == "res://scenes/overworld.tscn"
	_ok("back in the overworld", back_ok, "current scene is " + (current_scene.scene_file_path if current_scene != null else "<none>"))
	_finish()


func _finish() -> void:
	print("PUW smoke test — done: %d stages passed, %d failed." % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


## An early-game walk-encounter area from the real encounter
## data (at least 3 rows; the area whose lowest row level is
## smallest, so the demo party gets a fair fight), with every
## row carrying its species name from the parent entry — the
## rows themselves do not name the species.
func _first_walk_area() -> Dictionary:
	var path: String = "res://data/encounters_1025.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var entries: Array = (parsed as Dictionary).get("entries", [])
	var by_area: Dictionary = {}
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var species: String = str(entry.get("name", ""))
		var encs: Array = entry.get("encounters", [])
		for raw_row in encs:
			if not (raw_row is Dictionary):
				continue
			var row: Dictionary = (raw_row as Dictionary).duplicate()
			if str(row.get("method_name", "")) != "walk":
				continue
			row["species"] = species
			var area: String = str(row.get("location_area_name", ""))
			if not by_area.has(area):
				by_area[area] = []
			(by_area[area] as Array).append(row)
	var areas: Array = by_area.keys()
	areas.sort()
	# The earliest-game area wins: the one whose lowest row
	# level is smallest (ties broken by the alphabetical
	# order above), so the demo party fights a fair battle.
	var best: Dictionary = {}
	var best_min: int = 9999
	for area in areas:
		var rows: Array = by_area[area]
		if rows.size() < 3:
			continue
		var area_min: int = 9999
		for raw_row in rows:
			var row: Dictionary = raw_row
			area_min = mini(area_min, int(row.get("min_level", 9999)))
		if area_min < best_min:
			best_min = area_min
			best = {"location_area_name": str(area), "rows": rows}
	return best


## A battle-ready wild mon dict for the rolled species, in the
## same shape as the Overworld scene's own WILD_TABLE entries.
## HP is a plain test fixture (12 + 2 per level); the species
## and level are the real rolled values.
func _wild_mon(encounter: Dictionary) -> Dictionary:
	var slug: String = str(encounter.get("species", "pidgey"))
	var display: String = slug.capitalize().replace("-", " ")
	var level: int = int(encounter.get("level", 5))
	var hp: int = 12 + level * 2
	return {
		"name": display, "species": display, "level": level,
		"hp": hp, "max_hp": hp, "types": ["normal"],
		"moves": ["Tackle"], "status": "", "held_item": "",
		"wild": true,
	}
