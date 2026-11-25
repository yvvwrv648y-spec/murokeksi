class_name PUWEventActor
extends RefCounted
## One actor in an event/cutscene: a named participant with a
## tile position, a facing, and a movement queue, optionally
## bound to a Node2D (a PUWSpawner-spawned map object node, or
## the player node) whose position it drives.
##
## Why this exists: before this file, map actors were plain
## Node2D nodes created by PUWSpawner with metadata (tile,
## sprite, direction, movement pattern) and NOTHING could move
## or re-face them at runtime -- the movement pattern string in
## the map data was inert. Cutscenes need exactly that: walk an
## actor along a scripted path, turn them, hide them. This rig
## is the missing half; PUWEventRunner drives it.
##
## Movement model: tile-by-tile along a queued path at
## speed_tiles_per_sec (default 4.0 = PUWPlayerController's
## walk speed, SPEEDS["walk"]). tick(delta) advances the rig;
## the host calls it from _process in game, and a headless test
## calls it with fixed deltas -- the same deterministic-step
## contract PUWPlayerController.step() documents. Movement is
## scripted-path only: no tile collision is consulted, because
## a cutscene path is authored against the map (the source
## games' scripted movements work the same way). Facing follows
## the direction of travel; face()/face_toward() set it
## directly.
##
## Node sync: node.position is tile * tile_size plus the
## interpolated offset toward the next tile -- the same
## placement PUWSpawner._make_node uses (tile * tile_size), so
## a spawner node picked up by this rig does not jump. A rig
## with node == null is logic-only (positions/facings still
## tracked; used for camera targets and headless tests).

const DIRS: Dictionary = {
	"down": Vector2i(0, 1),
	"up": Vector2i(0, -1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}

var actor_id: String = ""
var node: Node2D = null
var tile: Vector2i = Vector2i.ZERO
var facing: String = "down"
var tile_size: int = 16
var speed_tiles_per_sec: float = 4.0
var is_visible: bool = true

var _path: Array = []
var _segment_progress: float = 0.0


static func normalize_dir(dir_text: String) -> String:
	var d: String = dir_text.strip_edges().to_lower()
	if DIRS.has(d):
		return d
	return ""


## Build a rig. start_tile is the actor's tile on its map;
## node may be null (logic-only rig).
static func create(p_actor_id: String, p_node: Node2D, start_tile: Vector2i, p_tile_size: int, start_facing: String = "down") -> PUWEventActor:
	var rig: PUWEventActor = PUWEventActor.new()
	rig.actor_id = p_actor_id
	rig.node = p_node
	rig.tile = start_tile
	rig.tile_size = maxi(p_tile_size, 1)
	var f: String = normalize_dir(start_facing)
	rig.facing = f if f != "" else "down"
	rig._sync_node(0.0, Vector2i.ZERO)
	return rig


## Teleport to a tile (warp-style placement inside an event).
func place(p_tile: Vector2i) -> void:
	tile = p_tile
	_path.clear()
	_segment_progress = 0.0
	_sync_node(0.0, Vector2i.ZERO)


## Queue a Manhattan path to target (horizontal steps first,
## then vertical -- deterministic; authors who need a specific
## route use queue_path with explicit waypoints).
func queue_move_to(target: Vector2i) -> void:
	var cursor: Vector2i = _path_end()
	while cursor.x != target.x:
		cursor.x += 1 if target.x > cursor.x else -1
		_path.append(cursor)
	while cursor.y != target.y:
		cursor.y += 1 if target.y > cursor.y else -1
		_path.append(cursor)


## Queue explicit waypoints; each consecutive pair must be a
## straight line (the rig walks tile by tile between them).
func queue_path(waypoints: Array) -> void:
	for wp_v in waypoints:
		if wp_v is Vector2i:
			var wp: Vector2i = wp_v
			queue_move_to(wp)
		elif wp_v is Array:
			var pair: Array = wp_v
			if pair.size() == 2:
				queue_move_to(Vector2i(int(pair[0]), int(pair[1])))


## Queue relative steps: dir ("down"/"up"/"left"/"right") x tiles.
func queue_step(dir_text: String, tiles: int) -> void:
	var d: String = normalize_dir(dir_text)
	if d == "" or tiles <= 0:
		return
	var delta: Vector2i = DIRS[d]
	var cursor: Vector2i = _path_end()
	for i in range(tiles):
		cursor += delta
		_path.append(cursor)


func is_moving() -> bool:
	return not _path.is_empty()


func queued_tiles() -> int:
	return _path.size()


func face(dir_text: String) -> void:
	var d: String = normalize_dir(dir_text)
	if d != "":
		facing = d


## Face toward another tile (dominant axis wins; ties go
## vertical, matching the source games' actor turns).
func face_toward(target: Vector2i) -> void:
	var diff: Vector2i = target - tile
	if diff == Vector2i.ZERO:
		return
	if abs(diff.x) > abs(diff.y):
		facing = "right" if diff.x > 0 else "left"
	else:
		facing = "down" if diff.y > 0 else "up"


func set_visible(p_visible: bool) -> void:
	is_visible = p_visible
	if node != null:
		node.visible = p_visible


## Advance movement by delta seconds. Returns true when the
## queue drained during this call.
func tick(delta: float) -> bool:
	if _path.is_empty():
		return false
	_segment_progress += delta * speed_tiles_per_sec
	var drained: bool = false
	while _segment_progress >= 1.0 and not _path.is_empty():
		_segment_progress -= 1.0
		var next_tile: Vector2i = _path[0]
		var step_delta: Vector2i = next_tile - tile
		if step_delta.x > 0:
			facing = "right"
		elif step_delta.x < 0:
			facing = "left"
		elif step_delta.y > 0:
			facing = "down"
		elif step_delta.y < 0:
			facing = "up"
		tile = next_tile
		_path.remove_at(0)
		drained = _path.is_empty()
	if _path.is_empty():
		_segment_progress = 0.0
		_sync_node(0.0, Vector2i.ZERO)
	else:
		var ahead: Vector2i = _path[0]
		_sync_node(_segment_progress, ahead - tile)
	return drained


func _path_end() -> Vector2i:
	if _path.is_empty():
		return tile
	var last_v: Variant = _path[_path.size() - 1]
	if last_v is Vector2i:
		return last_v
	return tile


func _sync_node(fraction: float, step_delta: Vector2i) -> void:
	if node == null:
		return
	var base: Vector2 = Vector2(tile) * float(tile_size)
	var offset: Vector2 = Vector2(step_delta) * float(tile_size) * fraction
	node.position = base + offset
