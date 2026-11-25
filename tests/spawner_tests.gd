extends SceneTree
## Spawner tests for Pokemon Ultimate World (Build A, part 2).
## Run: godot --headless --script res://tests/spawner_tests.gd
##
## S1: Pallet Town spawn counts equal the counts computed from
##     PalletTown.json inside this test.
## S2: a real sight-range trainer from trainers.json placements
##     (found programmatically on Route 3): sight triggers in the
##     facing line within range on clear tiles, fails one tile
##     off the line, beyond range, and when a tile between is
##     blocked.
## S3: a real no-sight-range trainer: check_sight false at every
##     distance; adjacent + facing interaction true.
## S4: dialogue resolution: a known map ref resolves to >= 1
##     line; the unresolved far-refs return [] and are recorded.
## S5: totals across all maps: spawned trainers equal the
##     placement count in trainers.json, with the with/without
##     sight split matching the data (all expectations computed
##     from the data files, not hardcoded).

const Spawner = preload("res://systems/overworld/spawner.gd")

var _passed: int = 0
var _failed: int = 0
var _spawner: Node = null


func _load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("PUW spawner tests — starting.")
	_spawner = Spawner.new()
	get_root().add_child(_spawner)

	var trainers_v: Variant = _load_json("res://data/trainers.json")
	_check("trainers_loaded", trainers_v is Dictionary)
	if not (trainers_v is Dictionary):
		_finish()
		return
	var trainers: Dictionary = trainers_v
	var placements: Array = trainers.get("placements", [])

	_test_s1_pallet_town()
	_test_s2_sight(placements)
	_test_s3_no_sight(placements)
	_test_s4_dialogue()
	_test_s5_totals(placements)
	_finish()


# Expected per-kind counts for one map, computed straight from
# the map JSON + placements using the documented rules.
func _expected_counts(map_name: String, map_data: Dictionary, placements: Array) -> Dictionary:
	var index: Dictionary = {}
	for raw_p in placements:
		var p: Dictionary = raw_p
		var key: String = String(p.get("map", "")) + "|" + str(int(p.get("x_tiles", 0))) + "|" + str(int(p.get("y_tiles", 0))) + "|" + String(p.get("class", ""))
		index[key] = p
	var exp: Dictionary = {"npc": 0, "trainer": 0, "sign": 0, "object": 0, "item": 0, "total": 0}
	var objects: Array = map_data.get("objects", [])
	for raw_o in objects:
		var o: Dictionary = raw_o
		var kind: String = "npc"
		var trainer_v: Variant = o.get("trainer", null)
		if trainer_v is Dictionary:
			var tb: Dictionary = trainer_v
			var key: String = map_name + "|" + str(int(o.get("x", 0))) + "|" + str(int(o.get("y", 0))) + "|" + String(tb.get("class", ""))
			kind = "trainer" if index.has(key) else "object"
		else:
			var item_v: Variant = o.get("item", null)
			if item_v is String:
				var item_id: String = item_v
				if item_id == "0":
					kind = "object"
				elif item_id != "":
					kind = "item"
		exp[kind] = int(exp[kind]) + 1
		exp["total"] = int(exp["total"]) + 1
	var bg: Array = map_data.get("bg_events", [])
	exp["sign"] = bg.size()
	exp["total"] = int(exp["total"]) + bg.size()
	return exp


func _test_s1_pallet_town() -> void:
	var map_v: Variant = _load_json("res://maps/data/maps/PalletTown.json")
	_check("S1_pallettown_json_loaded", map_v is Dictionary)
	if not (map_v is Dictionary):
		return
	var map_data: Dictionary = map_v
	var trainers_v: Variant = _load_json("res://data/trainers.json")
	var trainers: Dictionary = trainers_v
	var exp: Dictionary = _expected_counts("PalletTown", map_data, trainers.get("placements", []))
	var parent: Node2D = Node2D.new()
	get_root().add_child(parent)
	var report: Dictionary = _spawner.spawn_map(parent, "PalletTown")
	var counts: Dictionary = report.get("counts", {})
	_check("S1_total_matches_json", int(counts.get("total", -1)) == int(exp["total"]))
	_check("S1_npc_matches_json", int(counts.get("npc", -1)) == int(exp["npc"]))
	_check("S1_sign_matches_json", int(counts.get("sign", -1)) == int(exp["sign"]))
	_check("S1_trainer_matches_json", int(counts.get("trainer", -1)) == int(exp["trainer"]))
	_check("S1_children_spawned", parent.get_child_count() == int(exp["total"]))
	# Metadata spot check: every child carries kind + tile meta.
	var meta_ok: bool = true
	for child in parent.get_children():
		if not child.has_meta("kind") or not child.has_meta("tile"):
			meta_ok = false
	_check("S1_node_metadata_present", meta_ok)
	parent.queue_free()


func _find_placement(placements: Array, want_sight: bool) -> Dictionary:
	for raw_p in placements:
		var p: Dictionary = raw_p
		var dir: String = String(p.get("direction", ""))
		if not ["UP", "DOWN", "LEFT", "RIGHT"].has(dir):
			continue
		if want_sight:
			if String(p.get("map", "")) != "Route3":
				continue
			if p.has("sight_range") and int(p.get("sight_range", 0)) >= 2:
				return p
		else:
			if not p.has("sight_range"):
				return p
	return {}


func _test_s2_sight(placements: Array) -> void:
	var p: Dictionary = _find_placement(placements, true)
	_check("S2_sight_trainer_found_on_route3", not p.is_empty())
	if p.is_empty():
		return
	var t: Dictionary = Spawner.trainer_dict_from_placement(p)
	var tile: Vector2i = t["tile"]
	var facing: Vector2i = t["facing"]
	var sight: int = int(t["sight_range"])
	var clear: Callable = func(_t: Vector2i) -> bool: return false
	var in_line: Vector2i = tile + facing * 2
	_check("S2_sight_in_line_within_range", Spawner.check_sight(t, in_line, clear))
	var perp: Vector2i = Vector2i(facing.y, facing.x)
	_check("S2_sight_off_line_false", not Spawner.check_sight(t, in_line + perp, clear))
	_check("S2_sight_beyond_range_false", not Spawner.check_sight(t, tile + facing * (sight + 1), clear))
	_check("S2_sight_behind_false", not Spawner.check_sight(t, tile - facing, clear))
	var wall: Dictionary = {tile + facing: true}
	_check("S2_sight_blocked_false", not Spawner.check_sight_with_set(t, in_line, wall))
	_check("S2_sight_set_clear_true", Spawner.check_sight_with_set(t, in_line, {}))


func _test_s3_no_sight(placements: Array) -> void:
	var p: Dictionary = _find_placement(placements, false)
	_check("S3_no_sight_trainer_found", not p.is_empty())
	if p.is_empty():
		return
	var t: Dictionary = Spawner.trainer_dict_from_placement(p)
	var tile: Vector2i = t["tile"]
	var facing: Vector2i = t["facing"]
	var clear: Callable = func(_t: Vector2i) -> bool: return false
	var all_false: bool = true
	var d: int = 1
	while d <= 3:
		if Spawner.check_sight(t, tile + facing * d, clear):
			all_false = false
		d += 1
	_check("S3_sight_always_false_without_range", all_false)
	# Interaction: player adjacent on the trainer's facing side,
	# facing back at the trainer.
	var player_tile: Vector2i = tile + facing
	_check("S3_interaction_adjacent_facing_true", Spawner.check_interaction(t, player_tile, -facing))
	_check("S3_interaction_facing_away_false", not Spawner.check_interaction(t, player_tile, facing))
	_check("S3_interaction_not_adjacent_false", not Spawner.check_interaction(t, tile + facing * 2, -facing))


func _test_s4_dialogue() -> void:
	var lines: Array = _spawner.dialogue_for("PalletTown", "TEXT_PALLETTOWN_GIRL")
	_check("S4_known_ref_resolves", lines.size() >= 1)
	var far1: Array = _spawner.dialogue_for("Colosseum", "ColosseumOpponentText")
	_check("S4_colosseum_far_ref_empty", far1.is_empty())
	var far2: Array = _spawner.dialogue_for("TradeCenter", "TradeCenterOpponentText")
	_check("S4_tradecenter_far_ref_empty", far2.is_empty())
	var recorded: Array = _spawner.get_unresolved_dialogue()
	var seen: Dictionary = {}
	for raw_u in recorded:
		var u: Dictionary = raw_u
		seen[String(u.get("ref", ""))] = true
	_check("S4_far_refs_recorded_unresolved", seen.has("ColosseumOpponentText") and seen.has("TradeCenterOpponentText"))


func _test_s5_totals(placements: Array) -> void:
	var exp_with: int = 0
	var exp_without: int = 0
	var exp_zero: int = 0
	for raw_p in placements:
		var p: Dictionary = raw_p
		if p.has("sight_range"):
			exp_with += 1
			if int(p.get("sight_range", 0)) == 0:
				exp_zero += 1
		else:
			exp_without += 1
	var dir: DirAccess = DirAccess.open("res://maps/data/maps")
	_check("S5_maps_dir_open", dir != null)
	if dir == null:
		return
	var got_trainers: int = 0
	var got_with: int = 0
	var got_without: int = 0
	var got_zero: int = 0
	var got_object_only: int = 0
	var map_count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var map_name: String = file_name.trim_suffix(".json")
			var parent: Node2D = Node2D.new()
			get_root().add_child(parent)
			var report: Dictionary = _spawner.spawn_map(parent, map_name)
			var counts: Dictionary = report.get("counts", {})
			got_trainers += int(counts.get("trainer", 0))
			got_with += int(report.get("trainers_with_sight", 0))
			got_without += int(report.get("trainers_without_sight", 0))
			got_zero += int(report.get("trainers_sight_zero", 0))
			var oo: Array = report.get("object_only_trainers", [])
			got_object_only += oo.size()
			map_count += 1
			parent.queue_free()
		file_name = dir.get_next()
	dir.list_dir_end()
	print("S5 data: placements=", placements.size(), " with_sight=", exp_with, " without_sight=", exp_without, " sight_zero=", exp_zero, " maps=", map_count, " object_only_trainers=", got_object_only, " spawned=", got_trainers, " spawned_with=", got_with, " spawned_without=", got_without, " spawned_zero=", got_zero)
	_check("S5_spawned_trainers_equal_placements", got_trainers == placements.size())
	_check("S5_with_sight_split_matches", got_with == exp_with)
	_check("S5_without_sight_split_matches", got_without == exp_without)
	_check("S5_sight_zero_matches", got_zero == exp_zero)


func _finish() -> void:
	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(0 if _failed == 0 else 1)
