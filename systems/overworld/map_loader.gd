class_name PUWMapLoader
extends Node
## Loads PUW map scenes (res://maps/scenes/<Name>.tscn) and their
## per-map data (res://maps/data/maps/<Name>.json), and resolves
## warps and map connections for the traversal core.
##
## Data facts this loader is built on (verified against the real
## project data on 2026-11-22):
## - Grid unit = one 8 px cell. TileSet texture_region_size and
##   tile_size are both Vector2i(8, 8); per-map JSON tile_size = 8;
##   warp x/y/w/h and width_tiles/height_tiles are in these cells.
##   Warp Marker2D positions in the scenes sit at the centre of the
##   warp's cell rect (e.g. PalletTown warp 1 at (10,10,2,2) has its
##   marker at pixel (88, 88)).
## - Each map scene root is a Node2D with metadata id_const, region,
##   tileset, connections (JSON string) and border_block, plus a
##   TileMapLayer child named "Ground".
## - COLLISION SEMANTICS (read this before "fixing" it): the physics
##   polygons in the shipped TileSets do NOT mean "solid". The map
##   builder (maps/tools/builder.gd) added a physics-layer-0 polygon
##   to exactly the tiles in each tileset's "collision_tiles" list
##   from maps/data/tilesets.json, and those lists are copied from
##   pret/pokered's data/tilesets/collision_tile_ids.asm — which
##   pokered itself documents as the list of PASSABLE tiles
##   (engine/items/item_effects.asm: "wTilesetCollisionPtr ; pointer
##   to list of passable tiles"; CanWalkOntoTile in
##   engine/overworld/movement.asm allows a step only when the
##   destination tile is IN the list). Verified empirically on
##   Pallet Town: passable-list semantics yields one connected
##   818-cell walkable region covering the town, both house doors'
##   approach tiles and the lab approach; inverted semantics
##   fragments it into unreachable pockets (house yards marooned
##   behind "solid" path tiles). So here: a Ground cell is walkable
##   iff its TileData HAS a physics-layer-0 polygon. Warp tiles are
##   always steppable (doors / warp carpets are stepped onto so the
##   warp can fire, even when their tile id is not in the passable
##   list). Cells with no tile are solid, which is what makes
##   border_block edges impassable where no connection exists.
##   EXCEPTION: Sevii maps carry an explicit per-cell collision grid
##   as a hidden "Collision" TileMapLayer (builder.gd); when that
##   layer exists, ITS polygons mean solid in the normal way.
##   Known simplification vs real Gen 1: tile-PAIR elevation
##   collisions (land <-> water) are not modelled, so water tiles in
##   the passable list read as walkable; in the Kanto data those are
##   enclosed pockets (e.g. Pallet's pond, ringed by non-passable
##   bank tiles), unreachable on foot regardless.
## - Warps are 1-based by list order: warp id 1 is warps[0].
## - Interior exit warps use dest_map "LAST_MAP": the destination is
##   the map the player came from, and dest_warp is the warp id in
##   THAT map to spawn on (e.g. BluesHouse exits carry dest_warp 2,
##   the Pallet Town warp whose dest is BluesHouse).
## - Connection offsets are in pret "blocks" of 4 cells. Verified
##   empirically: Route 1's open north-edge columns (6,7,18,19,24,25,
##   36,37) land exactly on Viridian City's open south-edge columns
##   (26,27,38,39,44,45,56,57) under dest = src - offset * 4, using
##   Route 1 north offset -5 and Viridian south offset +5 (a +20 cell
##   shift). The same rule inverts cleanly for Viridian <-> Route 2
##   (offsets +5 / -5).

const SCENES_DIR: String = "res://maps/scenes/"
const DATA_DIR: String = "res://maps/data/maps/"
const INDEX_PATH: String = "res://maps/data/maps_index.json"
const OFFSET_CELLS_PER_UNIT: int = 4
const LAST_MAP: String = "LAST_MAP"

var current_map_name: String = ""
var current_id_const: String = ""
var current_node: Node2D = null
var current_layer: TileMapLayer = null
var tile_size_px: int = 8
var map_width_tiles: int = 0
var map_height_tiles: int = 0
var border_block: int = 0
var warps: Array = []
var connections: Array = []
## Map the player warped in from; LAST_MAP exits resolve against it.
var last_map_name: String = ""

## Escape Rope record (item triage top batch, staged by code
## prep code_prep_items): the map and warp the player entered
## the current cave/interior through. The warp-fire path calls
## record_entrance when a warp leads into an interior map; the
## bag's Escape Rope use reads escape_rope_target. Empty until
## an entrance has been recorded.
var entrance_map_name: String = ""
var entrance_warp_id: int = 0

var _index_by_name: Dictionary = {}
var _index_by_id: Dictionary = {}
var _index_loaded: bool = false
var _data_cache: Dictionary = {}
var _explicit_collision_layer: TileMapLayer = null

## Ambient tile animation (code prep code_prep_ambient_anim):
## cycles source-faithful animated tiles (water, flowers,
## fountains, ...) on the loaded map's visual layers. Created
## lazily on the first real map load; detached for synthetic
## maps and whenever a new map replaces the current one.
var ambient_animator: PUWAmbientTileAnimator = null

## SYNTHETIC test-map support (Phase 3 bike capacities). Gen 1/3
## Kanto-Sevii geometry has no rails, muddy slopes, or hop gaps, so
## capacity mechanics are proven on clearly-labelled synthetic maps
## built programmatically by tests via setup_synthetic_map(). A
## synthetic map is a plain grid: tiles not named in the terrain
## dictionary are "ground"; named values are one of "ground",
## "solid", "gap", "hop_obstacle", "rail", "muddy_slope", "water"
## ("water" added for Phase 3 item B ride crossings: crossable
## only while mounted in a water ride mode).
var _synthetic_active: bool = false
var _synthetic_terrain: Dictionary = {}
var _synthetic_layer: TileMapLayer = null


## Build a synthetic map of the given size. terrain maps Vector2i
## tiles to terrain-type strings (see above). Any previously loaded
## real map is replaced for collision purposes.
func setup_synthetic_map(width_tiles: int, height_tiles: int, terrain: Dictionary, synthetic_tile_size: int = 8) -> void:
	clear_synthetic_map()
	_synthetic_active = true
	_synthetic_terrain = terrain.duplicate()
	current_map_name = "SyntheticBikeCapacityMap"
	current_id_const = "SYNTHETIC_BIKE_CAPACITY_MAP"
	map_width_tiles = width_tiles
	map_height_tiles = height_tiles
	tile_size_px = synthetic_tile_size
	warps.clear()
	connections.clear()
	_explicit_collision_layer = null
	_synthetic_layer = TileMapLayer.new()
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(synthetic_tile_size, synthetic_tile_size)
	_synthetic_layer.tile_set = ts
	add_child(_synthetic_layer)
	current_layer = _synthetic_layer


func clear_synthetic_map() -> void:
	_synthetic_active = false
	_synthetic_terrain.clear()
	if ambient_animator != null:
		ambient_animator.detach()
	if _synthetic_layer != null:
		remove_child(_synthetic_layer)
		_synthetic_layer.queue_free()
		_synthetic_layer = null
		if current_layer == null or current_layer.get_parent() == null:
			current_layer = null


func is_synthetic_map() -> bool:
	return _synthetic_active


## Terrain type at a tile. On synthetic maps: the named terrain, or
## "ground" for unnamed in-bounds tiles, "solid" out of bounds. On
## real maps: "solid" when is_solid_tile, otherwise "ground" (real
## geometry has no rail / slope / gap terrain types).
func tile_terrain(tile: Vector2i) -> String:
	if _synthetic_active:
		if tile.x < 0 or tile.y < 0 or tile.x >= map_width_tiles or tile.y >= map_height_tiles:
			return "solid"
		if _synthetic_terrain.has(tile):
			return str(_synthetic_terrain[tile])
		return "ground"
	return "solid" if is_solid_tile(tile) else "ground"


func _ensure_index() -> void:
	if _index_loaded:
		return
	_index_loaded = true
	var parsed: Variant = _read_json(INDEX_PATH)
	if parsed is Array:
		var entries: Array = parsed
		for raw_entry in entries:
			if raw_entry is Dictionary:
				var entry: Dictionary = raw_entry
				var entry_name: String = str(entry.get("name", ""))
				var entry_id: String = str(entry.get("id_const", ""))
				if entry_name != "":
					_index_by_name[entry_name] = entry
					if entry_id != "":
						_index_by_id[entry_id] = entry_name


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	return JSON.parse_string(text)


## Parsed per-map JSON for a scene name (cached). Empty Dictionary
## when the file is missing or unparsable.
func map_data_for(map_name: String) -> Dictionary:
	if _data_cache.has(map_name):
		var cached: Dictionary = _data_cache[map_name]
		return cached
	var parsed: Variant = _read_json(DATA_DIR + map_name + ".json")
	var data: Dictionary = {}
	if parsed is Dictionary:
		var pd: Dictionary = parsed
		data = pd
	_data_cache[map_name] = data
	return data


## Resolve a scene name OR an id_const (e.g. "ROUTE_1") to a scene
## name (e.g. "Route1"). Returns "" when unknown.
func resolve_map_name(identifier: String) -> String:
	_ensure_index()
	if _index_by_name.has(identifier):
		return identifier
	if _index_by_id.has(identifier):
		var by_id: String = str(_index_by_id[identifier])
		return by_id
	if FileAccess.file_exists(SCENES_DIR + identifier + ".tscn"):
		return identifier
	return ""


## Load a map by scene name or id_const. Instances the scene as a
## child of this loader, swaps out any previous map, and parses the
## per-map JSON once. Returns true on success.
func load_map(identifier: String) -> bool:
	clear_synthetic_map()
	var map_name: String = resolve_map_name(identifier)
	if map_name == "":
		return false
	var packed: PackedScene = load(SCENES_DIR + map_name + ".tscn") as PackedScene
	if packed == null:
		return false
	var data: Dictionary = map_data_for(map_name)
	if current_node != null:
		remove_child(current_node)
		current_node.queue_free()
		current_node = null
		current_layer = null
	var node: Node = packed.instantiate()
	if node == null:
		return false
	add_child(node)
	current_node = node as Node2D
	current_map_name = map_name
	current_id_const = str(node.get_meta("id_const", str(data.get("id_const", ""))))
	border_block = int(node.get_meta("border_block", int(data.get("border_block", 0))))
	tile_size_px = int(data.get("tile_size", 8))
	map_width_tiles = int(data.get("width_tiles", 0))
	map_height_tiles = int(data.get("height_tiles", 0))
	warps.clear()
	var raw_warps: Array = data.get("warps", [])
	for raw_warp in raw_warps:
		if raw_warp is Dictionary:
			var warp: Dictionary = raw_warp
			warps.append(warp.duplicate())
	connections.clear()
	var raw_conns: Array = data.get("connections", [])
	for raw_conn in raw_conns:
		if raw_conn is Dictionary:
			var conn: Dictionary = raw_conn
			connections.append(conn.duplicate())
	_explicit_collision_layer = null
	for child in node.get_children():
		if child is TileMapLayer:
			var layer: TileMapLayer = child as TileMapLayer
			if layer.name == "Collision":
				_explicit_collision_layer = layer
			elif current_layer == null:
				current_layer = layer
	if current_layer != null and current_layer.tile_set != null:
		tile_size_px = current_layer.tile_set.tile_size.x
		var used: Rect2i = current_layer.get_used_rect()
		if map_width_tiles <= 0:
			map_width_tiles = used.size.x
		if map_height_tiles <= 0:
			map_height_tiles = used.size.y
	# Ambient tile animation: attach (or re-aim) the animator at
	# this map's tileset cycles. Maps whose tileset has no cycles
	# in maps/data/animated_tiles.json simply stay static.
	if ambient_animator == null:
		ambient_animator = PUWAmbientTileAnimator.new()
		ambient_animator.name = "AmbientTileAnimator"
		add_child(ambient_animator)
	var anim_region: String = str(current_node.get_meta("region", str(data.get("region", ""))))
	var anim_tileset: String = str(current_node.get_meta("tileset", str(data.get("tileset", ""))))
	ambient_animator.setup_map(current_node, anim_region, anim_tileset)
	return true


## Warp by 1-based id (list order in the per-map JSON). The returned
## Dictionary is a copy carrying an extra "id" key. Empty when the
## id is out of range.
func find_warp_by_id(warp_id: int) -> Dictionary:
	if warp_id < 1 or warp_id > warps.size():
		return {}
	var warp: Dictionary = warps[warp_id - 1]
	var result: Dictionary = warp.duplicate()
	result["id"] = warp_id
	return result


## Record the entrance the player just came through: the map
## they left (map_name) and the warp IN THAT MAP they spawned
## back onto when leaving the way they came (warp_id, the
## entrance warp's own LAST_MAP return point). Called by the
## warp-fire path when a warp leads into a cave/interior map.
func record_entrance(map_name: String, warp_id: int) -> void:
	entrance_map_name = map_name
	entrance_warp_id = warp_id


## Where an Escape Rope takes the player: back to the recorded
## entrance — its map and the warp to spawn on there. Empty
## when no entrance has been recorded (the rope then has no
## target and its use fails, the honest result outdoors).
func escape_rope_target() -> Dictionary:
	if entrance_map_name == "" or entrance_warp_id < 1:
		return {}
	return {"map": entrance_map_name, "warp_id": entrance_warp_id}


## Forget the recorded entrance (new game, or after the rope
## has been used and the player is back outside).
func clear_entrance() -> void:
	entrance_map_name = ""
	entrance_warp_id = 0


## Warp whose cell rect contains the given tile. Empty when none.
func find_warp_at_tile(tile: Vector2i) -> Dictionary:
	for i in range(warps.size()):
		var warp: Dictionary = warps[i]
		var wx: int = int(warp.get("x", 0))
		var wy: int = int(warp.get("y", 0))
		var ww: int = int(warp.get("w", 1))
		var wh: int = int(warp.get("h", 1))
		if tile.x >= wx and tile.x < wx + ww and tile.y >= wy and tile.y < wy + wh:
			var result: Dictionary = warp.duplicate()
			result["id"] = i + 1
			return result
	return {}


## Connection entry for a direction ("north"/"south"/"east"/"west").
## Empty when the map has no connection that way.
func find_connection(direction: String) -> Dictionary:
	for raw_conn in connections:
		var conn: Dictionary = raw_conn
		if str(conn.get("direction", "")) == direction:
			return conn.duplicate()
	return {}


## The spawn tile (origin cell of the destination warp's rect) for a
## warp id on an arbitrary map, read from that map's JSON without
## loading it. Returns Vector2i(-1, -1) when unknown.
func spawn_tile_for(map_name: String, warp_id: int) -> Vector2i:
	var data: Dictionary = map_data_for(map_name)
	var dest_warps: Array = data.get("warps", [])
	if warp_id < 1 or warp_id > dest_warps.size():
		return Vector2i(-1, -1)
	var dest_warp: Dictionary = dest_warps[warp_id - 1]
	return Vector2i(int(dest_warp.get("x", 0)), int(dest_warp.get("y", 0)))


## Execute a warp entry from the current map: resolves LAST_MAP,
## loads the destination map, and returns the spawn tile in the new
## map. Returns Vector2i(-1, -1) (and leaves the current map loaded)
## when the warp cannot be resolved.
func execute_warp(warp: Dictionary) -> Vector2i:
	var dest_map_id: String = str(warp.get("dest_map", ""))
	var dest_warp_id: int = int(warp.get("dest_warp", 0))
	var dest_name: String = ""
	if dest_map_id == LAST_MAP:
		dest_name = last_map_name
	else:
		dest_name = resolve_map_name(dest_map_id)
	if dest_name == "" or dest_warp_id < 1:
		return Vector2i(-1, -1)
	var spawn: Vector2i = spawn_tile_for(dest_name, dest_warp_id)
	if spawn.x < 0:
		return Vector2i(-1, -1)
	if dest_map_id != LAST_MAP:
		last_map_name = current_map_name
	if not load_map(dest_name):
		return Vector2i(-1, -1)
	return spawn


## Destination tile for walking off an edge through a connection.
## Pure helper (does not load anything): given the connection, the
## exit tile coordinate along the crossing axis, and the destination
## map's size, returns the entry tile in the destination map.
static func connection_entry_tile(conn: Dictionary, direction: String, exit_coord: int, dest_size: Vector2i) -> Vector2i:
	var offset_cells: int = int(round(float(conn.get("offset", 0.0)))) * OFFSET_CELLS_PER_UNIT
	var along: int = exit_coord - offset_cells
	match direction:
		"north":
			return Vector2i(clampi(along, 0, dest_size.x - 1), dest_size.y - 1)
		"south":
			return Vector2i(clampi(along, 0, dest_size.x - 1), 0)
		"west":
			return Vector2i(dest_size.x - 1, clampi(along, 0, dest_size.y - 1))
		"east":
			return Vector2i(0, clampi(along, 0, dest_size.y - 1))
	return Vector2i(-1, -1)


## True when the tile cannot be walked on. See the collision
## semantics note at the top of this file: on the Ground layer a
## physics-layer-0 polygon means the tile is in pokered's PASSABLE
## list (walkable), no polygon means solid; warp tiles are always
## steppable; on maps with an explicit "Collision" layer, that
## layer's polygons mean solid in the normal way.
func is_solid_tile(tile: Vector2i) -> bool:
	if _synthetic_active:
		# Generic collision on synthetic maps: only "ground" is
		# walkable. Special terrain (gap / hop_obstacle / rail /
		# muddy_slope) reads solid here; PUWPlayerController
		# intercepts it through tile_terrain() and its capacity
		# rules before falling back to this check.
		return tile_terrain(tile) != "ground"
	if current_layer == null:
		return true
	if tile.x < 0 or tile.y < 0 or tile.x >= map_width_tiles or tile.y >= map_height_tiles:
		return true
	if _explicit_collision_layer != null:
		var ctd: TileData = _explicit_collision_layer.get_cell_tile_data(tile)
		return ctd != null and ctd.get_collision_polygons_count(0) > 0
	if not find_warp_at_tile(tile).is_empty():
		return false
	var td: TileData = current_layer.get_cell_tile_data(tile)
	if td == null:
		return true
	return td.get_collision_polygons_count(0) == 0


## Pixel position of a tile's centre, in map-local coordinates.
func tile_center_px(tile: Vector2i) -> Vector2:
	return Vector2((float(tile.x) + 0.5) * float(tile_size_px), (float(tile.y) + 0.5) * float(tile_size_px))


## Tile containing a map-local pixel position.
func tile_at_px(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(tile_size_px)), floori(pos.y / float(tile_size_px)))
