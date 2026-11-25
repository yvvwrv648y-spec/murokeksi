extends SceneTree
## Builds Godot TileSet resources and TileMap scenes from the shared
## intermediate map JSON (maps/data/). Run headless:
##   godot --headless --path . --script res://builder.gd
## Exit code 0 = every map built, 1 = at least one failure.

var failures: Array = []
var built: Array = []

func _init() -> void:
	var data_dir: String = "res://maps/data/"
	var tilesets_data: Dictionary = _load_json(data_dir + "tilesets.json")
	var index_data: Array = _load_json(data_dir + "maps_index.json")
	if tilesets_data.is_empty() or index_data.is_empty():
		printerr("BUILDER: could not load tilesets.json or maps_index.json")
		quit(1)
		return

	# ---- build one TileSet per tileset ----
	var tileset_paths: Dictionary = {}
	for key_v in tilesets_data.keys():
		var key: String = key_v
		var info: Dictionary = tilesets_data[key]
		var ts_path: String = _build_tileset(key, info)
		if ts_path == "":
			failures.append("tileset:" + key)
		else:
			tileset_paths[key] = ts_path

	# ---- collision helper tileset (for explicit collision grids) ----
	var helper_path: String = _build_collision_helper()
	if helper_path == "":
		failures.append("tileset:__collision_helper")

	# ---- build one scene per map ----
	for entry_v in index_data:
		var entry: Dictionary = entry_v
		var name: String = entry["name"]
		var map_data: Dictionary = _load_json(data_dir + "maps/" + name + ".json")
		if map_data.is_empty():
			failures.append("map:" + name + ":json")
			continue
		var ts_key: String = map_data["tileset"]
		if not tileset_paths.has(ts_key):
			failures.append("map:" + name + ":tileset")
			continue
		if _build_map(map_data, tileset_paths[ts_key], helper_path):
			built.append(name)
		else:
			failures.append("map:" + name + ":save")

	var report: Dictionary = {"built": built, "failures": failures}
	var f: FileAccess = FileAccess.open("res://maps/build_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("BUILDER DONE: built=", built.size(), " failures=", failures.size())
	for fail_v in failures:
		var fail: String = fail_v
		printerr("BUILDER FAIL: ", fail)
	quit(0 if failures.is_empty() else 1)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		printerr("BUILDER: missing file ", path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		printerr("BUILDER: bad JSON in ", path)
		return {}
	return parsed

func _build_tileset(key: String, info: Dictionary) -> String:
	var tile_size: int = int(info["tile_size"])
	var columns: int = int(info["columns"])
	var atlas_rel: String = info["atlas"]  # e.g. "tilesets/overworld.png"
	var tex: Texture2D = ResourceLoader.load("res://maps/" + atlas_rel)
	if tex == null:
		printerr("BUILDER: could not load atlas ", atlas_rel)
		return ""
	var img_size: Vector2i = Vector2i(tex.get_width(), tex.get_height())
	var rows: int = img_size.y / tile_size
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(tile_size, tile_size)
	for y in rows:
		for x in columns:
			source.create_tile(Vector2i(x, y))
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_source(source, 0)
	var half: float = tile_size / 2.0
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
	var coll: Array = info.get("collision_tiles", [])
	for id_v in coll:
		var tid: int = int(id_v)
		var coords: Vector2i = Vector2i(tid % columns, tid / columns)
		if coords.y >= rows:
			continue
		var td: TileData = source.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	var out_path: String = "res://maps/tilesets/" + key + ".tres"
	var err: Error = ResourceSaver.save(tile_set, out_path)
	if err != OK:
		printerr("BUILDER: could not save ", out_path, " err=", err)
		return ""
	return out_path

func _build_collision_helper() -> String:
	# A 16x16 white tile with a full-square collision polygon. Used by the
	# hidden Collision layer for maps whose data carries an explicit
	# per-cell collision grid (Sevii). Tile size of the helper TileSet is
	# set per map at build time by scaling: instead we build it at 16px
	# and Sevii maps use 16px metatiles, so it lines up.
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_physics_layer(0)
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_source(source, 0)
	var td: TileData = source.get_tile_data(Vector2i(0, 0), 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	var out_path: String = "res://maps/tilesets/collision_helper.tres"
	var err: Error = ResourceSaver.save(tile_set, out_path)
	if err != OK:
		printerr("BUILDER: could not save collision helper err=", err)
		return ""
	return out_path

func _fill_layer(layer: TileMapLayer, tiles: Array, width: int, columns: int) -> void:
	for i in tiles.size():
		var tid: int = int(tiles[i])
		var cell: Vector2i = Vector2i(i % width, i / width)
		layer.set_cell(cell, 0, Vector2i(tid % columns, tid / columns))

func _build_map(map_data: Dictionary, tileset_path: String, helper_path: String) -> bool:
	var name: String = map_data["name"]
	var tile_size: int = int(map_data["tile_size"])
	var width: int = int(map_data["width_tiles"])
	var tileset_res: TileSet = ResourceLoader.load(tileset_path)
	if tileset_res == null:
		return false
	# atlas column count comes from the tileset source texture
	var source: TileSetAtlasSource = tileset_res.get_source(0) as TileSetAtlasSource
	var columns: int = source.texture.get_width() / tile_size

	var root: Node2D = Node2D.new()
	root.name = name
	# Presentation (Riley's art direction, 2026-11-22): BW2 as the base,
	# pushed toward a 2D/3D hybrid feel. Y-sort gives real depth: 2D
	# sprite characters added later sort against the world instead of
	# drawing flat on top. Map DATA is unchanged by any of this.
	root.y_sort_enabled = true
	root.set_meta("id_const", String(map_data.get("id_const", "")))
	root.set_meta("region", String(map_data.get("region", "")))
	root.set_meta("tileset", String(map_data.get("tileset", "")))
	root.set_meta("connections", JSON.stringify(map_data.get("connections", [])))
	if map_data.get("border_block") != null:
		root.set_meta("border_block", int(map_data["border_block"]))

	var ground: TileMapLayer = TileMapLayer.new()
	ground.name = "Ground"
	ground.y_sort_enabled = true
	ground.tile_set = tileset_res
	_fill_layer(ground, map_data["tiles"], width, columns)
	root.add_child(ground)
	ground.owner = root

	# Lighting hook for the presentation pass: a neutral CanvasModulate
	# named "Presentation" ships in every scene so the BW2-style
	# lighting grade can be tuned per map later without touching the
	# map data layers. Neutral (white) = no change by default.
	var presentation: CanvasModulate = CanvasModulate.new()
	presentation.name = "Presentation"
	presentation.color = Color(1, 1, 1, 1)
	root.add_child(presentation)
	presentation.owner = root

	if map_data.has("tiles_top"):
		var top: TileMapLayer = TileMapLayer.new()
		top.name = "Top"
		top.y_sort_enabled = true
		top.tile_set = tileset_res
		_fill_layer(top, map_data["tiles_top"], width, columns)
		root.add_child(top)
		top.owner = root

	if map_data.has("collision_grid"):
		var helper: TileSet = ResourceLoader.load(helper_path)
		var coll_layer: TileMapLayer = TileMapLayer.new()
		coll_layer.name = "Collision"
		coll_layer.tile_set = helper
		coll_layer.visible = false
		var grid: Array = map_data["collision_grid"]
		for i in grid.size():
			if bool(grid[i]):
				coll_layer.set_cell(Vector2i(i % width, i / width), 0, Vector2i(0, 0))
		root.add_child(coll_layer)
		coll_layer.owner = root

	var warps: Array = map_data.get("warps", [])
	var wnum: int = 0
	for warp_v in warps:
		var warp: Dictionary = warp_v
		wnum += 1
		var marker: Marker2D = Marker2D.new()
		marker.name = "Warp_%d" % wnum
		var wx: int = int(warp["x"])
		var wy: int = int(warp["y"])
		var ww: int = int(warp.get("w", 1))
		var wh: int = int(warp.get("h", 1))
		marker.position = Vector2((wx + ww / 2.0) * tile_size, (wy + wh / 2.0) * tile_size)
		marker.set_meta("dest_map", String(warp.get("dest_map", "")))
		marker.set_meta("dest_warp", int(warp.get("dest_warp", 0)))
		marker.set_meta("grid_x", wx)
		marker.set_meta("grid_y", wy)
		marker.set_meta("grid_w", ww)
		marker.set_meta("grid_h", wh)
		root.add_child(marker)
		marker.owner = root

	var packed: PackedScene = PackedScene.new()
	var perr: Error = packed.pack(root)
	if perr != OK:
		printerr("BUILDER: pack failed for ", name, " err=", perr)
		root.free()
		return false
	var out_path: String = "res://maps/scenes/" + name + ".tscn"
	var serr: Error = ResourceSaver.save(packed, out_path)
	root.free()
	if serr != OK:
		printerr("BUILDER: save failed for ", name, " err=", serr)
		return false
	return true
