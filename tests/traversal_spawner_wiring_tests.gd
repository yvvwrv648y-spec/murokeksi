extends SceneTree
## Traversal <-> spawner wiring tests for Pokemon Ultimate World.
## Run: godot --headless --script res://tests/traversal_spawner_wiring_tests.gd
##
## W1: the spawner's sight check, wired to REAL map collision.
##     PUWSpawner.check_sight takes a blocked-tile predicate; here
##     that predicate is PUWMapLoader.is_solid_tile on the loaded
##     map (pokered passable-list semantics). No single trainer in
##     the sourced data has both a clear line and a solid-blocked
##     line inside its own sight range (a blocked line stays
##     blocked at every longer distance, and trainers with a clear
##     first step are clear all the way), so this test searches
##     programmatically -- map by map, trainer by trainer, using
##     only real geometry -- for the first map that contains BOTH
##     a clear-line trainer and a solid-blocked trainer, spawns
##     that whole map through PUWSpawner, and asserts both cases
##     against the spawned nodes. The map and trainers used are
##     printed in the PASS detail lines.
## W2: PUWPlayerController.set_cast("riley") on a loaded map binds
##     the rebuilt PUWCastRigLoader's real sliced frames: the
##     AnimatedSprite2D ends up with non-null SpriteFrames holding
##     >0 frames for the walk state, and the rig itself reports
##     status "loaded" for riley/walk.

const Spawner = preload("res://systems/overworld/spawner.gd")

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" -- " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" -- " + detail) if detail != "" else "")


func _finish() -> void:
	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)


func _init() -> void:
	_run.call_deferred()


func _load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


# One sight case found from real geometry: {trainer (placement
# Dictionary), player_tile, blocked_tile (Vector2i(-999,-999) for
# the clear case)}.
func _find_case(loader: PUWMapLoader, p: Dictionary, want_blocked: bool) -> Dictionary:
	var t: Dictionary = Spawner.trainer_dict_from_placement(p)
	var tile: Vector2i = t["tile"]
	var facing: Vector2i = t["facing"]
	var sight: int = int(t["sight_range"])
	var d: int = 2
	while d <= sight:
		var player_tile: Vector2i = tile + facing * d
		if not loader.is_solid_tile(player_tile):
			var first_solid: Vector2i = Vector2i(-999, -999)
			var s: int = 1
			while s < d:
				var between: Vector2i = tile + facing * s
				if loader.is_solid_tile(between) and first_solid.x == -999:
					first_solid = between
				s += 1
			if want_blocked and first_solid.x != -999:
				return {"trainer": t, "player_tile": player_tile, "blocked_tile": first_solid}
			if not want_blocked and first_solid.x == -999:
				return {"trainer": t, "player_tile": player_tile, "blocked_tile": first_solid}
		d += 1
	return {}


func _run() -> void:
	print("PUW traversal/spawner wiring tests -- starting.")
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var spawner: Node = Spawner.new()
	root.add_child(spawner)

	var trainers_v: Variant = _load_json("res://data/trainers.json")
	_check("W1_trainers_loaded", trainers_v is Dictionary)
	if not (trainers_v is Dictionary):
		_finish()
		return
	var trainers: Dictionary = trainers_v
	var placements: Array = trainers.get("placements", [])

	# Group sighted placements by map, preserving data order.
	var map_order: Array = []
	var by_map: Dictionary = {}
	for raw_p in placements:
		var p: Dictionary = raw_p
		if not p.has("sight_range") or int(p.get("sight_range", 0)) < 2:
			continue
		var dir: String = String(p.get("direction", ""))
		if not ["UP", "DOWN", "LEFT", "RIGHT"].has(dir):
			continue
		var m: String = String(p.get("map", ""))
		if not by_map.has(m):
			by_map[m] = []
			map_order.append(m)
		var arr: Array = by_map[m]
		arr.append(p)

	# Search for the first map holding BOTH cases in real geometry.
	var chosen_map: String = ""
	var clear_case: Dictionary = {}
	var blocked_case: Dictionary = {}
	for raw_m in map_order:
		var m2: String = str(raw_m)
		if not loader.load_map(m2):
			continue
		var arr2: Array = by_map[m2]
		var cc: Dictionary = {}
		var bc: Dictionary = {}
		for raw_p2 in arr2:
			var p2: Dictionary = raw_p2
			if cc.is_empty():
				cc = _find_case(loader, p2, false)
			if bc.is_empty():
				bc = _find_case(loader, p2, true)
		if not cc.is_empty() and not bc.is_empty():
			chosen_map = m2
			clear_case = cc
			blocked_case = bc
			break
	_check("W1_map_with_clear_and_blocked_cases_found", chosen_map != "", "map=" + chosen_map)
	if chosen_map == "":
		_finish()
		return
	_check("W1_chosen_map_loaded", loader.load_map(chosen_map), "map=" + chosen_map)

	# Spawn the chosen map through PUWSpawner and recover the two
	# trainers from the spawned nodes (not from the raw placements).
	var parent: Node2D = Node2D.new()
	root.add_child(parent)
	var report: Dictionary = spawner.spawn_map(parent, chosen_map)
	var counts: Dictionary = report.get("counts", {})
	_check("W1_spawn_produced_trainers", int(counts.get("trainer", 0)) > 0, "map=" + chosen_map + " trainers=" + str(int(counts.get("trainer", 0))))
	var clear_trainer: Dictionary = {}
	var blocked_trainer: Dictionary = {}
	var clear_src: Dictionary = clear_case.get("trainer", {})
	var blocked_src: Dictionary = blocked_case.get("trainer", {})
	for child in parent.get_children():
		if not child.has_meta("kind") or String(child.get_meta("kind", "")) != "trainer":
			continue
		var td: Dictionary = Spawner.trainer_dict_from_node(child)
		if td.get("tile", Vector2i(-1, -1)) == clear_src.get("tile", Vector2i(-2, -2)) and String(td.get("text_id", "")) == String(clear_src.get("text_id", "")):
			clear_trainer = td
		if td.get("tile", Vector2i(-1, -1)) == blocked_src.get("tile", Vector2i(-2, -2)) and String(td.get("text_id", "")) == String(blocked_src.get("text_id", "")):
			blocked_trainer = td
	_check("W1_clear_trainer_recovered_from_spawn", not clear_trainer.is_empty(), "trainer=" + String(clear_src.get("text_id", "")))
	_check("W1_blocked_trainer_recovered_from_spawn", not blocked_trainer.is_empty(), "trainer=" + String(blocked_src.get("text_id", "")))
	if clear_trainer.is_empty() or blocked_trainer.is_empty():
		_finish()
		return

	# The wiring under test: spawner sight predicate backed by the
	# map loader's real collision.
	var predicate: Callable = func(t: Vector2i) -> bool:
		return loader.is_solid_tile(t)
	var clear_player: Vector2i = clear_case.get("player_tile", Vector2i.ZERO)
	var blocked_player: Vector2i = blocked_case.get("player_tile", Vector2i.ZERO)
	var blocked_tile: Vector2i = blocked_case.get("blocked_tile", Vector2i(-999, -999))
	_check("W1_clear_line_sight_true_via_loader", Spawner.check_sight(clear_trainer, clear_player, predicate), "map=" + chosen_map + " trainer=" + String(clear_trainer.get("text_id", "")) + " tile=" + str(clear_trainer.get("tile", Vector2i.ZERO)) + " player=" + str(clear_player))
	_check("W1_blocked_tile_is_solid_in_loader", loader.is_solid_tile(blocked_tile), "blocked_tile=" + str(blocked_tile))
	var bt: Vector2i = blocked_trainer.get("tile", Vector2i.ZERO)
	var bf: Vector2i = blocked_trainer.get("facing", Vector2i.ZERO)
	var strictly_between: bool = blocked_tile != bt and blocked_tile != blocked_player and (blocked_tile - bt).x * bf.x + (blocked_tile - bt).y * bf.y > 0 and (blocked_player - blocked_tile).x * bf.x + (blocked_player - blocked_tile).y * bf.y > 0
	_check("W1_blocked_tile_strictly_between", strictly_between, "trainer=" + str(bt) + " blocked=" + str(blocked_tile) + " player=" + str(blocked_player))
	_check("W1_solid_between_sight_false_via_loader", not Spawner.check_sight(blocked_trainer, blocked_player, predicate), "map=" + chosen_map + " trainer=" + String(blocked_trainer.get("text_id", "")) + " tile=" + str(bt) + " player=" + str(blocked_player))
	# Control: the same blocked geometry with a never-blocked
	# predicate returns true, proving the false above comes from
	# the loader wiring and not from range/facing arithmetic.
	var never_blocked: Callable = func(_t: Vector2i) -> bool:
		return false
	_check("W1_blocked_geometry_true_without_predicate", Spawner.check_sight(blocked_trainer, blocked_player, never_blocked))

	# --- W2: player controller cast art on the loaded map ---
	var rig: Dictionary = PUWCastRigLoader.build_frames("riley", "walk")
	_check("W2_cast_rig_riley_walk_status_loaded", String(rig.get("status", "")) == "loaded" and int(rig.get("frame_count", 0)) > 0, "frames=" + str(int(rig.get("frame_count", 0))))
	var player: PUWPlayerController = PUWPlayerController.new()
	root.add_child(player)
	player.setup(loader)
	player.input_enabled = false
	player.set_cast("riley")
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check("W2_sprite_present", sprite != null)
	if sprite != null:
		_check("W2_sprite_frames_non_null", sprite.sprite_frames != null)
		if sprite.sprite_frames != null:
			var sf: SpriteFrames = sprite.sprite_frames
			_check("W2_walk_state_has_frames", sf.has_animation("walk") and sf.get_frame_count("walk") > 0, "walk_frames=" + str(sf.get_frame_count("walk")) if sf.has_animation("walk") else "no walk animation")
	_finish()
