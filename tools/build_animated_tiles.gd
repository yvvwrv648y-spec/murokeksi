extends SceneTree
## Build-time tool for ambient overworld tile animation (code prep
## code_prep_ambient_anim). Run headless from the project root, in
## two phases with a reimport between them:
##
##   godot --headless --script res://tools/build_animated_tiles.gd -- --phase graphics
##   godot --headless --import
##   godot --headless --script res://tools/build_animated_tiles.gd -- --phase tileset
##
## Phase "graphics": for every tileset in maps/data/
## animated_tiles.json (regions "kanto" and "johto"), resolve each
## cycle's frame descriptors against the PRISTINE atlas (kept
## under res://tools/pristine/, snapshotted from the live atlas on
## first run), append the new frame graphics as extra rows at the
## bottom of the atlas PNG, and write the resolved table (with
## per-cycle "frames_resolved" tile ids) back to maps/data/
## animated_tiles.json. Existing tile coordinates never move, so
## no map scene changes. Re-runs are deterministic: everything is
## rebuilt from the pristine atlas.
##
## Phase "tileset": load each extended tileset's .tres, create the
## appended tiles in its TileSetAtlasSource, and copy the base
## tile's TileData (physics-layer-0 collision polygons — the
## passable list — plus the scalar tile properties) onto every
## frame tile, so collision semantics are identical on every
## frame of a cycle. Saves the .tres in place; the atlas texture
## stays the external PNG reference.
##
## Tilesets whose .tres is absent from the project are skipped
## with a warning (lets the prep's reduced test project exercise
## the tool); in the full project every table tileset is present.
## Exit code 0 = no failures, 1 = at least one failure.

const TABLE_PATH: String = "res://maps/data/animated_tiles.json"
const TILESETS_JSON: String = "res://maps/data/tilesets.json"
const TILESETS_JOHTO_JSON: String = "res://maps/data/tilesets_johto.json"
const PRISTINE_ROOT: String = "res://tools/pristine/"
const ATLAS_ROOT: String = "res://maps/tilesets/"

var failures: Array = []
var _image_cache: Dictionary = {}


func _init() -> void:
	var phase: String = "graphics"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--phase" and i + 1 < args.size():
			phase = args[i + 1]
	var table: Dictionary = _load_json(TABLE_PATH)
	if table.is_empty():
		printerr("AMBIENT BUILD: could not load ", TABLE_PATH)
		quit(1)
		return
	var defs: Dictionary = {}
	for def_path in [TILESETS_JSON, TILESETS_JOHTO_JSON]:
		var parsed: Variant = _load_json(def_path)
		if parsed is Dictionary:
			var pd: Dictionary = parsed
			for key_v in pd.keys():
				var key: String = key_v
				if not defs.has(key):
					defs[key] = pd[key]
	var regions: Dictionary = table.get("regions", {})
	var region_keys: Array = regions.keys()
	region_keys.sort()
	for region_v in region_keys:
		var region: String = region_v
		var region_table: Dictionary = regions[region]
		var tileset_keys: Array = region_table.keys()
		tileset_keys.sort()
		for key_v in tileset_keys:
			var key: String = key_v
			var entry: Dictionary = region_table[key]
			if phase == "graphics":
				_graphics_for_tileset(table, defs, region, key, entry)
			else:
				_tileset_for_tileset(region, key, entry)
	if phase == "graphics":
		var f: FileAccess = FileAccess.open(TABLE_PATH, FileAccess.WRITE)
		if f == null:
			printerr("AMBIENT BUILD: cannot write ", TABLE_PATH)
			failures.append("table:write")
		else:
			f.store_string(JSON.stringify(table, "\t"))
			f.close()
	print("AMBIENT BUILD DONE phase=", phase, " failures=", failures.size())
	for fail_v in failures:
		var fail: String = fail_v
		printerr("AMBIENT BUILD FAIL: ", fail)
	quit(0 if failures.is_empty() else 1)


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	return parsed


func _tres_path(region: String, key: String) -> String:
	# Kanto and Sevii tilesets live directly under maps/tilesets/;
	# Johto's live in maps/tilesets/johto/.
	# RE-AUTHOR PATCH 2026-11-24 (production/ambient_kj_reauthor): try the
	# per-region subfolder FIRST when it exists. The original flat-first
	# order misfires on the "forest" key, which exists both as Kanto's
	# flat tilesets/forest.tres and as Johto's tilesets/johto/forest.tres:
	# Johto's forest cycles would have been appended to the Kanto atlas
	# and Johto's own atlas never extended. On the current tree the two
	# orders differ ONLY for johto/forest; every other table tileset
	# resolves identically either way (verified 2026-11-24).
	var regional: String = ATLAS_ROOT + region + "/" + key + ".tres"
	if ResourceLoader.exists(regional):
		return regional
	return ATLAS_ROOT + key + ".tres"


func _load_tileset(region: String, key: String) -> TileSet:
	var path: String = _tres_path(region, key)
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	return res as TileSet


# ----------------------------------------------------------------
# Phase: graphics
# ----------------------------------------------------------------

func _graphics_for_tileset(table: Dictionary, defs: Dictionary, region: String, key: String, entry: Dictionary) -> void:
	var tile_set: TileSet = _load_tileset(region, key)
	if tile_set == null:
		print("AMBIENT BUILD skip (no tileset in project): ", region, "/", key)
		return
	if not defs.has(key):
		failures.append(region + "/" + key + ":no-def")
		return
	var def: Dictionary = defs[key]
	var ts: int = int(def.get("tile_size", 8))
	var columns: int = int(def.get("columns", 16))
	var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	if source == null or source.texture == null:
		failures.append(region + "/" + key + ":no-source")
		return
	var atlas_path: String = source.texture.resource_path
	if atlas_path == "" or not atlas_path.begins_with(ATLAS_ROOT):
		failures.append(region + "/" + key + ":bad-atlas-path")
		return
	var rel: String = atlas_path.substr(ATLAS_ROOT.length())
	var pristine_path: String = PRISTINE_ROOT + rel
	_ensure_pristine(atlas_path, pristine_path)
	var pristine: Image = Image.load_from_file(ProjectSettings.globalize_path(pristine_path))
	if pristine == null:
		failures.append(region + "/" + key + ":pristine-load")
		return
	var fmt: Image.Format = pristine.get_format()
	var pristine_tiles: int = (pristine.get_width() / ts) * (pristine.get_height() / ts)
	# Resolve descriptors; collect new graphics in encounter order.
	var graphics: Dictionary = {}  # dedup key -> Image
	var order: Array = []  # dedup keys in assignment order
	var cycles: Array = entry.get("cycles", [])
	for raw_cycle in cycles:
		if not (raw_cycle is Dictionary):
			continue
		var cycle: Dictionary = raw_cycle
		var base: int = int(cycle.get("base", -1))
		var resolved: Array = []
		var frames: Array = cycle.get("frames", [])
		for raw_desc in frames:
			if not (raw_desc is Dictionary):
				continue
			var desc: Dictionary = raw_desc
			var rid: int = _resolve_descriptor(table, pristine, ts, columns, base, desc, graphics, order, pristine_tiles)
			if rid < 0:
				failures.append(region + "/" + key + ":descriptor")
				rid = base
			resolved.append(rid)
		cycle["frames_resolved"] = resolved
	var appended: int = order.size()
	if appended == 0:
		entry["_build"] = {"pristine_tiles": pristine_tiles, "appended_tiles": 0, "atlas": atlas_path}
		print("AMBIENT BUILD graphics ", region, "/", key, ": no new tiles")
		return
	# Assign ids and build the extended atlas image.
	var assigned: Dictionary = {}
	var next_id: int = pristine_tiles
	for key_v in order:
		var gkey: String = key_v
		assigned[gkey] = next_id
		next_id += 1
	# Re-resolve now that ids are assigned: descriptors that created
	# graphics recorded a placeholder via _graphic_key; rebuild the
	# resolved lists from the descriptors again (cheap, pure).
	for raw_cycle in cycles:
		if not (raw_cycle is Dictionary):
			continue
		var cycle: Dictionary = raw_cycle
		var base: int = int(cycle.get("base", -1))
		var resolved: Array = []
		var frames: Array = cycle.get("frames", [])
		for raw_desc in frames:
			var desc: Dictionary = raw_desc
			if desc.has("tile"):
				resolved.append(int(desc["tile"]))
			else:
				var gkey: String = _graphic_key(base, desc)
				resolved.append(int(assigned[gkey]))
		cycle["frames_resolved"] = resolved
	var total_tiles: int = pristine_tiles + appended
	var rows: int = (total_tiles + columns - 1) / columns
	var extended: Image = Image.create(pristine.get_width(), rows * ts, false, fmt)
	extended.fill(Color(0, 0, 0, 1))
	extended.blit_rect(pristine, Rect2i(0, 0, pristine.get_width(), pristine.get_height()), Vector2i.ZERO)
	for gkey_v in order:
		var gkey: String = gkey_v
		var gid: int = int(assigned[gkey])
		var img: Image = graphics[gkey]
		var dest: Vector2i = Vector2i((gid % columns) * ts, (gid / columns) * ts)
		extended.blit_rect(img, Rect2i(0, 0, ts, ts), dest)
	var err: Error = extended.save_png(ProjectSettings.globalize_path(atlas_path))
	if err != OK:
		failures.append(region + "/" + key + ":atlas-save")
		return
	entry["_build"] = {"pristine_tiles": pristine_tiles, "appended_tiles": appended, "atlas": atlas_path}
	print("AMBIENT BUILD graphics ", region, "/", key, ": pristine=", pristine_tiles, " appended=", appended, " atlas=", atlas_path)


## Returns the resolved tile id for a descriptor, or -1 on error.
## For graphic-producing descriptors the id cannot be known until
## all graphics are collected, so this pass only registers the
## graphic (dedup) and returns the base as a placeholder; the
## caller rebuilds resolved ids from _graphic_key afterwards.
func _resolve_descriptor(table: Dictionary, pristine: Image, ts: int, columns: int, base: int, desc: Dictionary, graphics: Dictionary, order: Array, pristine_tiles: int) -> int:
	if desc.has("tile"):
		return int(desc["tile"])
	var gkey: String = _graphic_key(base, desc)
	if graphics.has(gkey):
		return base
	var img: Image = null
	if desc.has("roll_x") or desc.has("roll_y"):
		var from_id: int = int(desc.get("from", base))
		if from_id < 0 or from_id >= pristine_tiles:
			return -1
		var tile_img: Image = _cut_tile(pristine, from_id, ts, columns)
		img = _rolled(tile_img, int(desc.get("roll_x", 0)), int(desc.get("roll_y", 0)))
	elif desc.has("image"):
		var name: String = str(desc["image"])
		var frame_images: Dictionary = table.get("frame_images", {})
		if not frame_images.has(name):
			return -1
		var src: Image = _frame_image(str(frame_images[name]))
		if src == null:
			return -1
		var index: int = int(desc.get("index", 0))
		var img_cols: int = src.get_width() / ts
		if img_cols <= 0:
			return -1
		img = _cut_tile(src, index, ts, img_cols)
		if img.get_format() != pristine.get_format():
			img.convert(pristine.get_format())
	else:
		return -1
	if img == null:
		return -1
	graphics[gkey] = img
	order.append(gkey)
	return base


func _graphic_key(base: int, desc: Dictionary) -> String:
	if desc.has("roll_x") or desc.has("roll_y"):
		return "roll|%d|%d|%d" % [int(desc.get("from", base)), int(desc.get("roll_x", 0)), int(desc.get("roll_y", 0))]
	return "img|%s|%d" % [str(desc.get("image", "")), int(desc.get("index", 0))]


func _cut_tile(img: Image, tile_id: int, ts: int, columns: int) -> Image:
	var x: int = (tile_id % columns) * ts
	var y: int = (tile_id / columns) * ts
	return img.get_region(Rect2i(x, y, ts, ts))


func _rolled(img: Image, rx: int, ry: int) -> Image:
	var ts: int = img.get_width()
	var out: Image = Image.create(ts, ts, false, img.get_format())
	for y in range(ts):
		for x in range(ts):
			out.set_pixel(x, y, img.get_pixel(posmod(x - rx, ts), posmod(y - ry, ts)))
	return out


func _frame_image(path: String) -> Image:
	if _image_cache.has(path):
		var cached: Image = _image_cache[path]
		return cached
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_image_cache[path] = img
	return img


func _ensure_pristine(atlas_path: String, pristine_path: String) -> void:
	if FileAccess.file_exists(pristine_path):
		return
	var global_pristine: String = ProjectSettings.globalize_path(pristine_path)
	var dir: String = global_pristine.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var src: FileAccess = FileAccess.open(atlas_path, FileAccess.READ)
	if src == null:
		return
	var bytes: PackedByteArray = src.get_buffer(src.get_length())
	src.close()
	var dst: FileAccess = FileAccess.open(pristine_path, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_buffer(bytes)
	dst.close()
	print("AMBIENT BUILD pristine snapshot: ", pristine_path)


# ----------------------------------------------------------------
# Phase: tileset
# ----------------------------------------------------------------

func _tileset_for_tileset(region: String, key: String, entry: Dictionary) -> void:
	var build: Dictionary = entry.get("_build", {})
	var pristine_tiles: int = int(build.get("pristine_tiles", -1))
	if pristine_tiles < 0:
		print("AMBIENT BUILD skip tileset phase (no _build info): ", region, "/", key)
		return
	var tile_set: TileSet = _load_tileset(region, key)
	if tile_set == null:
		print("AMBIENT BUILD skip (no tileset in project): ", region, "/", key)
		return
	var source: TileSetAtlasSource = tile_set.get_source(0) as TileSetAtlasSource
	if source == null or source.texture == null:
		failures.append(region + "/" + key + ":no-source")
		return
	var columns: int = int(source.texture.get_width()) / source.texture_region_size.x
	var created: int = 0
	var cycles: Array = entry.get("cycles", [])
	for raw_cycle in cycles:
		if not (raw_cycle is Dictionary):
			continue
		var cycle: Dictionary = raw_cycle
		var base: int = int(cycle.get("base", -1))
		var base_coords: Vector2i = Vector2i(base % columns, base / columns)
		var base_data: TileData = null
		if source.has_tile(base_coords):
			base_data = source.get_tile_data(base_coords, 0)
		var resolved: Array = cycle.get("frames_resolved", [])
		for raw_id in resolved:
			var fid: int = int(raw_id)
			if fid < pristine_tiles:
				continue
			var coords: Vector2i = Vector2i(fid % columns, fid / columns)
			if source.has_tile(coords):
				continue
			source.create_tile(coords)
			created += 1
			if base_data != null:
				var new_data: TileData = source.get_tile_data(coords, 0)
				_copy_tile_data(base_data, new_data)
	var err: Error = ResourceSaver.save(tile_set, _tres_path(region, key))
	if err != OK:
		failures.append(region + "/" + key + ":tres-save")
		return
	print("AMBIENT BUILD tileset ", region, "/", key, ": created=", created)


func _copy_tile_data(from_data: TileData, to_data: TileData) -> void:
	# Physics layer 0 polygons (the passable list) — the property
	# that decides collision on every PUW tileset family here.
	var count: int = from_data.get_collision_polygons_count(0)
	for i in range(count):
		to_data.add_collision_polygon(0)
		to_data.set_collision_polygon_points(0, i, from_data.get_collision_polygon_points(0, i))
		to_data.set_collision_polygon_one_way(0, i, from_data.is_collision_polygon_one_way(0, i))
	# Scalar tile properties, copied so a frame tile is
	# indistinguishable from its base tile except for its graphic.
	to_data.texture_origin = from_data.texture_origin
	to_data.flip_h = from_data.flip_h
	to_data.flip_v = from_data.flip_v
	to_data.transpose = from_data.transpose
	to_data.modulate = from_data.modulate
	to_data.material = from_data.material
	to_data.z_index = from_data.z_index
	to_data.y_sort_origin = from_data.y_sort_origin
