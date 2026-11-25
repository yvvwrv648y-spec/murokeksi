extends SceneTree
## Traversal core tests for Pokemon Ultimate World (Build A part 1).
## Run: godot --headless --script res://tests/traversal_core_tests.gd
##
## Drives PUWPlayerController.step() directly (no real input) over
## the REAL map scenes and collision data. Open tiles and paths are
## found programmatically from PUWMapLoader.is_solid_tile via BFS —
## no guessed coordinates. Warp tiles are treated as blocked during
## pathfinding except as an explicit goal.
##
## T1 Pallet Town -> Route 1 across the north connection.
## T2 Route 1 -> Viridian City across the north connection.
## T3 BluesHouse warp round-trip (Pallet -> interior -> Pallet).
## T4 Collision: walking into a solid tile is refused.
## T5 Speed sanity: walk covers ~4 tiles in 1.0 s; run is faster.

var _passed: int = 0
var _failed: int = 0

var _loader: PUWMapLoader = null
var _player: PUWPlayerController = null


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" — " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" — " + detail) if detail != "" else "")


func _init() -> void:
	_run.call_deferred()


func _setup_world() -> bool:
	_loader = PUWMapLoader.new()
	root.add_child(_loader)
	_player = PUWPlayerController.new()
	_player.input_enabled = false
	root.add_child(_player)
	_player.setup(_loader)
	return _loader.load_map("PalletTown")


## BFS over walkable tiles. Warp tiles are blocked unless the goal
## itself is one (allow_warp_goal). Returns the path excluding the
## start tile, or an empty Array when unreachable / already there
## (distinguish via _bfs_found).
var _bfs_found: bool = false


func _bfs_path(start: Vector2i, is_goal: Callable, allow_warp_goal: bool) -> Array:
	_bfs_found = false
	if is_goal.call(start):
		_bfs_found = true
		return []
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array = [start]
	visited[start] = true
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for raw_dir in dirs:
			var d: Vector2i = raw_dir
			var nxt: Vector2i = cur + d
			if visited.has(nxt):
				continue
			if _loader.is_solid_tile(nxt):
				continue
			var on_warp: bool = not _loader.find_warp_at_tile(nxt).is_empty()
			var goal_here: bool = bool(is_goal.call(nxt))
			if on_warp and not (allow_warp_goal and goal_here):
				continue
			visited[nxt] = true
			parent[nxt] = cur
			if goal_here:
				_bfs_found = true
				var path: Array = []
				var node: Vector2i = nxt
				while node != start:
					path.push_front(node)
					node = parent[node]
				return path
			queue.append(nxt)
	return []


## Walk the player along a BFS path, one tile at a time.
func _walk_path(path: Array, mode: String = "walk") -> void:
	for raw_tile in path:
		var target: Vector2i = raw_tile
		_walk_to_tile(target, mode)


## Step until the player's centre reaches the target tile (or the
## map changes, or a generous step budget runs out).
func _walk_to_tile(target: Vector2i, mode: String = "walk") -> void:
	var map_before: String = _loader.current_map_name
	var budget: int = 200
	while budget > 0:
		budget -= 1
		if _loader.current_map_name != map_before:
			return
		var here: Vector2i = _player.player_tile()
		if here == target:
			return
		var centre: Vector2 = _loader.tile_center_px(target)
		var dir: Vector2 = centre - _player.position
		_player.step(0.05, dir, mode)


## Step in a fixed direction until the map changes or budget ends.
func _walk_off_edge(dir: Vector2, mode: String = "walk") -> void:
	var map_before: String = _loader.current_map_name
	var budget: int = 60
	while budget > 0 and _loader.current_map_name == map_before:
		budget -= 1
		_player.step(0.05, dir, mode)


func _first_open_tile(predicate: Callable) -> Vector2i:
	for y in range(_loader.map_height_tiles):
		for x in range(_loader.map_width_tiles):
			var tile: Vector2i = Vector2i(x, y)
			if _loader.is_solid_tile(tile):
				continue
			if not _loader.find_warp_at_tile(tile).is_empty():
				continue
			if bool(predicate.call(tile)):
				return tile
	return Vector2i(-1, -1)


func _run() -> void:
	print("PUW traversal core tests — starting.")
	if not _setup_world():
		_check("setup_load_pallet", false, "PalletTown failed to load")
		_finish()
		return
	_check("setup_load_pallet", _loader.current_id_const == "PALLET_TOWN", "id_const=" + _loader.current_id_const)

	# ---------- T1: Pallet Town -> Route 1 (north connection) ----------
	var start1: Vector2i = _first_open_tile(func(t: Vector2i) -> bool: return t.y > 20)
	_player.place_at_tile(start1)
	var path1: Array = _bfs_path(start1, func(t: Vector2i) -> bool: return t.y == 0, false)
	_check("T1_path_found", _bfs_found, "start=" + str(start1) + " path_len=" + str(path1.size()))
	_walk_path(path1)
	_walk_off_edge(Vector2(0, -1))
	var t1_tile: Vector2i = _player.player_tile()
	_check("T1_pallet_to_route1", _loader.current_map_name == "Route1" and _loader.current_id_const == "ROUTE_1" and t1_tile.y >= _loader.map_height_tiles - 3, "map=" + _loader.current_map_name + " id=" + _loader.current_id_const + " tile=" + str(t1_tile))

	# ---------- T2: Route 1 -> Viridian City (north connection) ----------
	var here2: Vector2i = _player.player_tile()
	var path2: Array = _bfs_path(here2, func(t: Vector2i) -> bool: return t.y == 0, false)
	_check("T2_path_found", _bfs_found, "start=" + str(here2) + " path_len=" + str(path2.size()))
	_walk_path(path2)
	_walk_off_edge(Vector2(0, -1))
	_check("T2_route1_to_viridian", _loader.current_map_name == "ViridianCity" and _loader.current_id_const == "VIRIDIAN_CITY", "map=" + _loader.current_map_name + " id=" + _loader.current_id_const + " tile=" + str(_player.player_tile()))

	# ---------- T3: BluesHouse warp round-trip ----------
	_loader.load_map("PalletTown")
	var door_warp: Dictionary = {}
	for i in range(_loader.warps.size()):
		var w: Dictionary = _loader.warps[i]
		if str(w.get("dest_map", "")) == "BLUES_HOUSE":
			door_warp = _loader.find_warp_by_id(i + 1)
			break
	var door_tile: Vector2i = Vector2i(int(door_warp.get("x", -1)), int(door_warp.get("y", -1)))
	var door_goal_rect: Rect2i = Rect2i(door_tile, Vector2i(int(door_warp.get("w", 1)), int(door_warp.get("h", 1))))
	var start3: Vector2i = _first_open_tile(func(t: Vector2i) -> bool: return t.y > 20)
	_player.place_at_tile(start3)
	# Goal is any cell of the door warp's rect: the warp fires on the
	# first warp cell stepped on, not on the rect's origin cell.
	var path3: Array = _bfs_path(start3, func(t: Vector2i) -> bool: return door_goal_rect.has_point(t), true)
	_check("T3_path_to_door", _bfs_found and not door_warp.is_empty(), "door=" + str(door_tile) + " path_len=" + str(path3.size()))
	_walk_path(path3)
	var in_house: bool = _loader.current_map_name == "BluesHouse"
	var entry_warp: Dictionary = _loader.find_warp_by_id(1)
	var entry_rect: Rect2i = Rect2i(int(entry_warp.get("x", 0)), int(entry_warp.get("y", 0)), int(entry_warp.get("w", 1)), int(entry_warp.get("h", 1)))
	var t3_in_tile: Vector2i = _player.player_tile()
	_check("T3_enter_blues_house", in_house and entry_rect.has_point(t3_in_tile), "map=" + _loader.current_map_name + " tile=" + str(t3_in_tile) + " entry_rect=" + str(entry_rect))
	# Exit: walk to the second exit warp tile (the one we did not spawn on).
	var exit_warp: Dictionary = _loader.find_warp_by_id(2)
	var exit_tile: Vector2i = Vector2i(int(exit_warp.get("x", -1)), int(exit_warp.get("y", -1)))
	var exit_rect: Rect2i = Rect2i(exit_tile, Vector2i(int(exit_warp.get("w", 1)), int(exit_warp.get("h", 1))))
	var path3b: Array = _bfs_path(t3_in_tile, func(t: Vector2i) -> bool: return exit_rect.has_point(t), true)
	_check("T3_path_to_exit", _bfs_found, "exit=" + str(exit_tile) + " path_len=" + str(path3b.size()))
	_walk_path(path3b)
	var door_rect: Rect2i = Rect2i(door_tile, Vector2i(int(door_warp.get("w", 1)), int(door_warp.get("h", 1))))
	var t3_out_tile: Vector2i = _player.player_tile()
	_check("T3_exit_to_pallet_door", _loader.current_map_name == "PalletTown" and door_rect.has_point(t3_out_tile), "map=" + _loader.current_map_name + " tile=" + str(t3_out_tile) + " door_rect=" + str(door_rect))

	# ---------- T4: collision refusal ----------
	var open4: Vector2i = Vector2i(-1, -1)
	var solid4: Vector2i = Vector2i(-1, -1)
	for y in range(1, _loader.map_height_tiles - 1):
		if open4.x >= 0:
			break
		for x in range(1, _loader.map_width_tiles - 1):
			var tile: Vector2i = Vector2i(x, y)
			if _loader.is_solid_tile(tile):
				continue
			if not _loader.find_warp_at_tile(tile).is_empty():
				continue
			var east: Vector2i = tile + Vector2i(1, 0)
			if _loader.is_solid_tile(east) and _loader.find_warp_at_tile(east).is_empty():
				open4 = tile
				solid4 = east
				break
	_player.place_at_tile(open4)
	for i in range(20):
		_player.step(0.05, Vector2(1, 0), "walk")
	_check("T4_solid_tile_refused", _player.player_tile() == open4 and _player.player_tile() != solid4, "open=" + str(open4) + " solid=" + str(solid4) + " now=" + str(_player.player_tile()))

	# ---------- T5: speed sanity on open ground ----------
	# Find a horizontal run of >= 10 open, warp-free tiles.
	var run_start: Vector2i = Vector2i(-1, -1)
	for y in range(_loader.map_height_tiles):
		if run_start.x >= 0:
			break
		var run_len: int = 0
		for x in range(_loader.map_width_tiles):
			var tile: Vector2i = Vector2i(x, y)
			if not _loader.is_solid_tile(tile) and _loader.find_warp_at_tile(tile).is_empty():
				run_len += 1
				if run_len >= 10:
					run_start = Vector2i(x - 9, y)
					break
			else:
				run_len = 0
	_player.place_at_tile(run_start)
	var walk_from: Vector2 = _player.position
	for i in range(20):
		_player.step(0.05, Vector2(1, 0), "walk")
	var walk_tiles: float = (_player.position.x - walk_from.x) / float(_loader.tile_size_px)
	_player.place_at_tile(run_start)
	var run_from: Vector2 = _player.position
	for i in range(20):
		_player.step(0.05, Vector2(1, 0), "run")
	var run_tiles: float = (_player.position.x - run_from.x) / float(_loader.tile_size_px)
	_check("T5_walk_speed_4_tiles_per_sec", walk_tiles >= 3.4 and walk_tiles <= 4.6, "walk_tiles=" + str(walk_tiles) + " from=" + str(run_start))
	_check("T5_run_faster_than_walk", run_tiles > walk_tiles + 1.0, "run_tiles=" + str(run_tiles) + " walk_tiles=" + str(walk_tiles))
	_check("T5_controller_state", _player.facing == "right" and _player.locomotion_state == "run" and _player.current_animation == "run_right", "facing=" + _player.facing + " state=" + _player.locomotion_state + " anim=" + _player.current_animation)

	_finish()


func _finish() -> void:
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
