extends SceneTree
## Ambient overworld tile animation tests (code prep
## code_prep_ambient_anim, 2026-11-24). Run:
##   godot --headless --script res://tests/ambient_anim_tests.gd
## (run_tests.sh first runs --import and both phases of
## tools/build_animated_tiles.gd, so the tilesets under test are
## the tool-extended ones and maps/data/animated_tiles.json is
## the resolved table.)
##
## Covers:
## - the resolved table's shape for the Kanto overworld water
##   cycle (ping-pong scroll: base, +1, +2, +3, +4, +3, +2, +1)
##   and flower cycle ([f1, f1, f2, f3]);
## - frame tiles exist in the extended TileSets and carry the
##   base tile's TileData (collision polygon count);
## - a water tile's frame ADVANCES over time and wraps back to
##   the base tile after a full cycle (Kanto scroll + Johto
##   frame-swap), a flower advances, a non-animated control tile
##   never changes, chunked advance_time is deterministic, and
##   _process forwards to advance_time;
## - event-gated cycles (Ilex Forest trees) stay static without
##   the gate and animate with it;
## - the patched PUWMapLoader integration: loading the real
##   Pallet Town scene animates its pond water through the
##   loader's own animator, loading New Bark Town re-aims the
##   animator at the Johto cycles, and a synthetic map detaches
##   it;
## - an unknown region (sevii — census done, cycles bind in
##   build 6) leaves the animator idle.

var _pass: int = 0
var _fail: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("PASS: ", label)
	else:
		_fail += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	var table: Dictionary = _load_table()
	_check(not table.is_empty(), "resolved animated_tiles.json loads")
	_test_kanto_unit(table)
	_test_johto_unit(table)
	_test_gated_cycles(table)
	_test_loader_integration(table)
	_test_unknown_region()
	_test_sevii_cycles_bound(table)
	print("AMBIENT ANIM TESTS: passed=", _pass, " failed=", _fail)
	quit(0 if _fail == 0 else 1)


func _load_table() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://maps/data/animated_tiles.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var pd: Dictionary = parsed
		return pd
	return {}


func _cycle(table: Dictionary, region: String, key: String, base: int) -> Dictionary:
	var regions: Dictionary = table.get("regions", {})
	var region_table: Dictionary = regions.get(region, {})
	var entry: Dictionary = region_table.get(key, {})
	var cycles: Array = entry.get("cycles", [])
	for raw in cycles:
		var cycle: Dictionary = raw
		if int(cycle.get("base", -1)) == base:
			return cycle
	return {}


func _coords(tile_id: int, columns: int = 16) -> Vector2i:
	return Vector2i(tile_id % columns, tile_id / columns)


func _make_layer(tileset_path: String) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Ground"
	var ts: TileSet = ResourceLoader.load(tileset_path) as TileSet
	layer.tile_set = ts
	return layer


func _make_map(layer: TileMapLayer) -> Node2D:
	var map_root: Node2D = Node2D.new()
	map_root.add_child(layer)
	root.add_child(map_root)
	return map_root


func _cell_id(layer: TileMapLayer, cell: Vector2i, columns: int = 16) -> int:
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	return coords.y * columns + coords.x


# ----------------------------------------------------------------

func _test_kanto_unit(table: Dictionary) -> void:
	var water: Dictionary = _cycle(table, "kanto", "overworld", 20)
	var resolved: Array = water.get("frames_resolved", [])
	_check(resolved.size() == 8, "kanto water cycle resolves to 8 steps")
	if resolved.size() == 8:
		_check(int(resolved[0]) == 20, "kanto water step 0 is the base tile")
		_check(int(resolved[1]) == 96, "kanto water roll+1 is the first appended tile (96)")
		_check(int(resolved[4]) == 99, "kanto water roll+4 is appended tile 99")
		_check(int(resolved[5]) == int(resolved[3]) and int(resolved[7]) == int(resolved[1]),
			"kanto water ping-pong reuses rolled tiles on the way back")
	var flower: Dictionary = _cycle(table, "kanto", "overworld", 3)
	var fresolved: Array = flower.get("frames_resolved", [])
	_check(fresolved.size() == 4, "kanto flower cycle resolves to 4 steps")
	if fresolved.size() == 4:
		_check(int(fresolved[0]) == int(fresolved[1]), "kanto flower steps 0-1 are the same graphic (source: flower1 twice)")
		_check(int(fresolved[2]) != int(fresolved[0]) and int(fresolved[3]) != int(fresolved[2]),
			"kanto flower steps 2 and 3 are distinct graphics")

	var layer: TileMapLayer = _make_layer("res://maps/tilesets/overworld.tres")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0) as TileSetAtlasSource
	_check(source.has_tile(_coords(96)), "extended overworld tileset has the roll+1 tile")
	var base_data: TileData = source.get_tile_data(_coords(20), 0)
	var frame_data: TileData = source.get_tile_data(_coords(96), 0)
	_check(frame_data != null, "frame tile carries TileData")
	if base_data != null and frame_data != null:
		_check(frame_data.get_collision_polygons_count(0) == base_data.get_collision_polygons_count(0),
			"frame tile collision polygon count matches base tile")

	var water_cell: Vector2i = Vector2i(5, 5)
	var flower_cell: Vector2i = Vector2i(6, 5)
	var control_cell: Vector2i = Vector2i(7, 5)
	layer.set_cell(water_cell, 0, _coords(20))
	layer.set_cell(flower_cell, 0, _coords(3))
	layer.set_cell(control_cell, 0, _coords(6))
	var map_root: Node2D = _make_map(layer)
	var animator: PUWAmbientTileAnimator = PUWAmbientTileAnimator.new()
	root.add_child(animator)
	animator.setup_map(map_root, "kanto", "overworld")
	_check(animator.active_cycle_count() == 2, "kanto unit: water + flower cycles active")
	_check(animator.animated_cell_count() == 2, "kanto unit: 2 animated cells")
	_check(_cell_id(layer, water_cell) == 20, "kanto water starts on the base tile")

	animator.advance_time(0.36)
	_check(_cell_id(layer, water_cell) == int(resolved[1]), "kanto water frame advances to roll+1")
	_check(_cell_id(layer, flower_cell) == int(fresolved[0]), "kanto flower advances to flower1 tile")
	animator.advance_time(0.35)
	_check(_cell_id(layer, water_cell) == int(resolved[2]), "kanto water advances to roll+2")
	_check(_cell_id(layer, flower_cell) == int(fresolved[2]), "kanto flower advances to flower2 on step 3 (source cycle [f1, f1, f2, f3])")
	animator.advance_time(0.35)
	_check(_cell_id(layer, flower_cell) == int(fresolved[3]), "kanto flower reaches flower3")
	animator.advance_time(0.35)
	_check(_cell_id(layer, water_cell) == int(resolved[4]), "kanto water reaches roll+4")
	animator.advance_time(0.35)
	animator.advance_time(0.35)
	animator.advance_time(0.35)
	animator.advance_time(0.35)
	_check(_cell_id(layer, water_cell) == 20, "kanto water wraps back to the base tile after a full cycle")
	_check(_cell_id(layer, control_cell) == 6, "control tile never changes")

	# Deterministic chunking: two half-steps equal one step.
	animator.advance_time(0.175)
	_check(_cell_id(layer, water_cell) == 20, "half-step does not advance the water tile")
	animator.advance_time(0.175)
	_check(_cell_id(layer, water_cell) == int(resolved[1]), "two half-steps advance exactly one frame")
	# _process forwards to advance_time.
	animator._process(0.35)
	_check(_cell_id(layer, water_cell) == int(resolved[2]), "_process forwards to advance_time")

	animator.detach()
	_check(animator.active_cycle_count() == 0, "detach clears all cycles")
	animator.advance_time(1.0)
	_check(_cell_id(layer, water_cell) == int(resolved[2]), "no animation after detach")


func _test_johto_unit(table: Dictionary) -> void:
	var water: Dictionary = _cycle(table, "johto", "johto", 20)
	var resolved: Array = water.get("frames_resolved", [])
	_check(resolved.size() == 4, "johto water cycle resolves to 4 frames")
	if resolved.size() == 4:
		_check(int(resolved[0]) == 20 and int(resolved[1]) == 192,
			"johto water frame 1 is the first appended tile (192)")
	var layer: TileMapLayer = _make_layer("res://maps/tilesets/johto/johto.tres")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0) as TileSetAtlasSource
	_check(source.has_tile(_coords(192)), "extended johto tileset has the water frame tile")
	var water_cell: Vector2i = Vector2i(5, 5)
	var flower_cell: Vector2i = Vector2i(6, 5)
	layer.set_cell(water_cell, 0, _coords(20))
	layer.set_cell(flower_cell, 0, _coords(3))
	var map_root: Node2D = _make_map(layer)
	var animator: PUWAmbientTileAnimator = PUWAmbientTileAnimator.new()
	root.add_child(animator)
	animator.setup_map(map_root, "johto", "johto")
	_check(animator.active_cycle_count() == 2,
		"johto unit: water + flower active (whirlpool cycles idle without whirlpool cells)")
	animator.advance_time(0.44)
	_check(_cell_id(layer, water_cell) == int(resolved[1]), "johto water advances to GSC frame 1")
	_check(_cell_id(layer, flower_cell) != 3, "johto flower advances to cgb_2")
	animator.advance_time(0.44)
	_check(_cell_id(layer, flower_cell) == 3, "johto flower wraps back to the base tile")
	animator.advance_time(0.44)
	animator.advance_time(0.44)
	_check(_cell_id(layer, water_cell) == 20, "johto water wraps back to the base tile after 4 frames")


func _test_gated_cycles(table: Dictionary) -> void:
	var layer: TileMapLayer = _make_layer("res://maps/tilesets/johto/forest.tres")
	var tree_l: Vector2i = Vector2i(5, 5)
	var tree_r: Vector2i = Vector2i(6, 5)
	var flower_cell: Vector2i = Vector2i(7, 5)
	var water_cell: Vector2i = Vector2i(8, 5)
	layer.set_cell(tree_l, 0, _coords(12))
	layer.set_cell(tree_r, 0, _coords(15))
	layer.set_cell(flower_cell, 0, _coords(3))
	layer.set_cell(water_cell, 0, _coords(20))
	var map_root: Node2D = _make_map(layer)
	var animator: PUWAmbientTileAnimator = PUWAmbientTileAnimator.new()
	root.add_child(animator)
	animator.setup_map(map_root, "johto", "forest")
	_check(animator.active_cycle_count() == 2, "forest: gated tree cycles stay inactive without the gate")
	animator.advance_time(10.3)
	_check(_cell_id(layer, tree_l) == 12 and _cell_id(layer, tree_r) == 15,
		"forest trees stay static without the Celebi gate (source default)")
	_check(_cell_id(layer, water_cell) != 20, "forest water animates")
	animator.setup_map(map_root, "johto", "forest", ["celebi_event"])
	_check(animator.active_cycle_count() == 4, "forest: tree cycles activate with the gate open")
	animator.advance_time(0.21)
	_check(_cell_id(layer, tree_l) != 12, "forest left tree animates with the gate open")


func _test_loader_integration(table: Dictionary) -> void:
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	_check(loader.load_map("PalletTown"), "loader loads the real Pallet Town scene")
	_check(loader.ambient_animator != null, "loader created its ambient animator")
	if loader.ambient_animator == null:
		return
	_check(loader.ambient_animator.active_cycle_count() == 2, "Pallet Town: water + flower cycles active")
	var layer: TileMapLayer = loader.current_layer
	var water_cell: Vector2i = Vector2i(-1, -1)
	for cell in layer.get_used_cells():
		if _cell_id(layer, cell) == 20:
			water_cell = cell
			break
	_check(water_cell.x >= 0, "Pallet Town has a water cell to animate")
	if water_cell.x < 0:
		return
	var water: Dictionary = _cycle(table, "kanto", "overworld", 20)
	var resolved: Array = water.get("frames_resolved", [])
	loader.ambient_animator.advance_time(0.36)
	_check(_cell_id(layer, water_cell) == int(resolved[1]),
		"Pallet Town pond water frame advances through the loader's animator")
	loader.ambient_animator.advance_time(0.35 * 7.0 + 0.01)
	_check(_cell_id(layer, water_cell) == 20, "Pallet Town water wraps back to the base tile")

	_check(loader.load_map("NewBarkTown"), "loader loads the real New Bark Town scene")
	_check(loader.ambient_animator.active_cycle_count() >= 2, "New Bark Town: johto cycles active after re-aim")
	var jlayer: TileMapLayer = loader.current_layer
	var jwater: Vector2i = Vector2i(-1, -1)
	for cell in jlayer.get_used_cells():
		if _cell_id(jlayer, cell) == 20:
			jwater = cell
			break
	_check(jwater.x >= 0, "New Bark Town has a water cell to animate")
	if jwater.x >= 0:
		var jcycle: Dictionary = _cycle(table, "johto", "johto", 20)
		var jresolved: Array = jcycle.get("frames_resolved", [])
		loader.ambient_animator.advance_time(0.44)
		_check(_cell_id(jlayer, jwater) == int(jresolved[1]),
			"New Bark Town water advances to the GSC frame (animator re-aimed by region)")
	loader.setup_synthetic_map(4, 4, {})
	_check(loader.ambient_animator.active_cycle_count() == 0, "synthetic map detaches the animator")


func _test_unknown_region() -> void:
	var layer: TileMapLayer = _make_layer("res://maps/tilesets/overworld.tres")
	layer.set_cell(Vector2i(5, 5), 0, _coords(20))
	var map_root: Node2D = _make_map(layer)
	var animator: PUWAmbientTileAnimator = PUWAmbientTileAnimator.new()
	root.add_child(animator)
	animator.setup_map(map_root, "bogus_region", "general__sevii_islands_123")
	_check(animator.active_cycle_count() == 0, "unknown region leaves the animator idle")
	animator.advance_time(1.0)
	_check(_cell_id(layer, Vector2i(5, 5)) == 20, "unknown-region cell untouched")


## Build 6 (A-40): the Sevii cycle table is bound — the sevii
## region exists in the shipped table with live cycles, and
## the animator activates + advances a real cycle (base tile
## 256, the regenerated table's first islands-123 cycle) on
## the real Sevii tileset (32-column atlas).
func _test_sevii_cycles_bound(table: Dictionary) -> void:
	var regions_value: Variant = table.get("regions", {})
	var regions: Dictionary = regions_value if regions_value is Dictionary else {}
	_check(regions.has("sevii"), "bound table carries the sevii region")
	var sevii_value: Variant = regions.get("sevii", {})
	var sevii: Dictionary = sevii_value if sevii_value is Dictionary else {}
	var ts_value: Variant = sevii.get("general__sevii_islands_123", {})
	var ts: Dictionary = ts_value if ts_value is Dictionary else {}
	var cycles_value: Variant = ts.get("cycles", [])
	var cycles: Array = cycles_value if cycles_value is Array else []
	_check(cycles.size() > 0, "sevii islands-123 cycles bound (got %d)" % cycles.size())
	var layer: TileMapLayer = _make_layer("res://maps/tilesets/general__sevii_islands_123.tres")
	layer.set_cell(Vector2i(5, 5), 0, _coords(256, 32))
	var map_root: Node2D = _make_map(layer)
	var animator: PUWAmbientTileAnimator = PUWAmbientTileAnimator.new()
	root.add_child(animator)
	animator.setup_map(map_root, "sevii", "general__sevii_islands_123")
	_check(animator.active_cycle_count() == 1, "sevii cycle activates on the real tileset")
	animator.advance_time(1.0)
	_check(_cell_id(layer, Vector2i(5, 5), 32) != 256, "sevii cell advances under the animator")
