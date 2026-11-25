extends SceneTree
## Headless verification of the Sevii warp normalization through the REAL
## PUWMapLoader code (copied verbatim into this harness by
## work/apply_patches.py). For every numeric warp in the corrected table:
## resolve_map_name(dest_map) must succeed and spawn_tile_for(dest, id)
## must return the exact tile the corrected table names. LAST_MAP exits
## are checked against every possible origin map that warps into the
## room. Run: godot --headless --path test_project --script tests/sevii_warp_tests.gd

var _failures: Array = []
var _checks: int = 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)


func _read_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	return JSON.parse_string(text)


func _init() -> void:
	var loader_script: GDScript = load("res://systems/overworld/map_loader.gd") as GDScript
	var loader: Node = loader_script.new()
	var table_parsed: Variant = _read_json("res://test_data/sevii_warp_table_corrected.json")
	var table: Dictionary = table_parsed as Dictionary
	var maps: Dictionary = table.get("maps", {}) as Dictionary

	# Inbound origins per map id_const (for LAST_MAP exit checks).
	var origins: Dictionary = {}
	for map_name_v in maps.keys():
		var m: Dictionary = maps[map_name_v] as Dictionary
		var warps_in: Array = m.get("warps", []) as Array
		for wv in warps_in:
			var w: Dictionary = wv as Dictionary
			var dm: String = str(w.get("dest_map", ""))
			if dm != "" and dm != "LAST_MAP" and dm != "MAP_DYNAMIC":
				if not origins.has(dm):
					origins[dm] = []
				var arr: Array = origins[dm] as Array
				arr.append(str(m.get("id_const", "")))

	var numeric_warps: int = 0
	var dynamic_skipped: int = 0
	for map_name_v in maps.keys():
		var map_name: String = str(map_name_v)
		var m: Dictionary = maps[map_name] as Dictionary
		var warps: Array = m.get("warps", []) as Array
		for wv in warps:
			var w: Dictionary = wv as Dictionary
			if str(w.get("class", "")) == "DYNAMIC_BY_DESIGN":
				dynamic_skipped += 1
				continue
			numeric_warps += 1
			var wid: int = int(w.get("id", 0))
			var dm: String = str(w.get("dest_map", ""))
			var dw: int = int(w.get("dest_warp", 0))
			if dm == "LAST_MAP":
				# The exit must land on a real warp in EVERY origin map.
				var my_id: String = str(m.get("id_const", ""))
				var my_origins: Array = origins.get(my_id, []) as Array
				_check(my_origins.size() > 0, map_name + "#" + str(wid) + " LAST_MAP exit has origins")
				for ov in my_origins:
					var o_id: String = str(ov)
					var o_name: String = loader.call("resolve_map_name", o_id) as String
					_check(o_name != "", map_name + " exit origin resolves: " + o_id)
					var ospawn: Vector2i = loader.call("spawn_tile_for", o_name, dw) as Vector2i
					_check(ospawn != Vector2i(-1, -1),
						map_name + "#" + str(wid) + " LAST_MAP spawn in " + o_name + "/" + str(dw))
				continue
			var dest_name: String = loader.call("resolve_map_name", dm) as String
			_check(dest_name != "", map_name + "#" + str(wid) + " dest resolves: " + dm)
			if dest_name == "":
				continue
			var spawn: Vector2i = loader.call("spawn_tile_for", dest_name, dw) as Vector2i
			_check(spawn != Vector2i(-1, -1),
				map_name + "#" + str(wid) + " spawn valid: " + dm + "/" + str(dw))
			# The spawn tile must be the destination warp's own tile.
			var dest_data: Dictionary = loader.call("map_data_for", dest_name) as Dictionary
			var dest_warps: Array = dest_data.get("warps", []) as Array
			if dw >= 1 and dw <= dest_warps.size():
				var dw_rec: Dictionary = dest_warps[dw - 1] as Dictionary
				var expect: Vector2i = Vector2i(int(dw_rec.get("x", -1)), int(dw_rec.get("y", -1)))
				_check(spawn == expect,
					map_name + "#" + str(wid) + " spawn tile == " + dm + " warp " + str(dw) + " tile")

	_check(numeric_warps == 343, "numeric warps tested == 343 (342 Sevii + 1 UnionRoom exit) got " + str(numeric_warps))
	_check(dynamic_skipped == 1, "exactly 1 dynamic warp skipped, got " + str(dynamic_skipped))

	# The retargeted destinations and authored room lists, by name.
	var tc_spawn: Vector2i = loader.call("spawn_tile_for", "TradeCenter", 1) as Vector2i
	_check(tc_spawn == Vector2i(8, 14), "TradeCenter warp 1 is the (8,14) door pad, got " + str(tc_spawn))
	var col_spawn: Vector2i = loader.call("spawn_tile_for", "Colosseum", 1) as Vector2i
	_check(col_spawn == Vector2i(8, 14), "Colosseum warp 1 is the (8,14) door pad, got " + str(col_spawn))
	var ur_name: String = loader.call("resolve_map_name", "MAP_UNION_ROOM") as String
	_check(ur_name == "UnionRoom", "MAP_UNION_ROOM resolves to UnionRoom, got " + ur_name)
	var tc_name: String = loader.call("resolve_map_name", "TRADE_CENTER") as String
	_check(tc_name == "TradeCenter", "TRADE_CENTER resolves to TradeCenter, got " + tc_name)

	print("SEVII WARP TESTS: checks=", _checks, " failures=", _failures.size(),
		" numeric_warps=", numeric_warps, " dynamic_skipped=", dynamic_skipped)
	for f in _failures:
		print("FAIL: ", str(f))
	quit(1 if _failures.size() > 0 else 0)
