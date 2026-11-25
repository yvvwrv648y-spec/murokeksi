extends SceneTree
## Load-tests every built map scene: loads the PackedScene, instantiates
## it, and checks the Ground layer's used-cell count against the source
## JSON grid size, plus root metadata. Prints one PASS/FAIL line per map
## and a summary. Exit code 0 = all pass.
##   godot --headless --path . --script res://test_maps.gd

func _init() -> void:
	var data_dir: String = "res://maps/data/"
	var index_data: Array = _load_json(data_dir + "maps_index.json")
	var passed: int = 0
	var failed: int = 0
	for entry_v in index_data:
		var entry: Dictionary = entry_v
		var name: String = entry["name"]
		var map_data: Dictionary = _load_json(data_dir + "maps/" + name + ".json")
		var expect_cells: int = int(map_data["width_tiles"]) * int(map_data["height_tiles"])
		var scene_path: String = "res://maps/scenes/" + name + ".tscn"
		var packed: PackedScene = ResourceLoader.load(scene_path)
		if packed == null:
			print("FAIL ", name, " scene did not load")
			failed += 1
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			print("FAIL ", name, " scene did not instantiate")
			failed += 1
			continue
		var ground: TileMapLayer = inst.get_node_or_null("Ground") as TileMapLayer
		if ground == null:
			print("FAIL ", name, " no Ground layer")
			failed += 1
			inst.free()
			continue
		var used: int = ground.get_used_cells().size()
		var id_const: String = String(inst.get_meta("id_const", ""))
		if used != expect_cells:
			print("FAIL ", name, " cells used=", used, " expected=", expect_cells)
			failed += 1
		elif id_const != String(map_data.get("id_const", "")):
			print("FAIL ", name, " id_const meta mismatch: ", id_const)
			failed += 1
		else:
			print("PASS ", name, " cells=", used)
			passed += 1
		inst.free()
	print("MAP TESTS: passed=", passed, " failed=", failed, " total=", passed + failed)
	quit(0 if failed == 0 else 1)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		printerr("TEST: missing file ", path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	return parsed
