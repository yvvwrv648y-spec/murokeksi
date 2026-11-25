class_name PUWAmbientTileAnimator
extends Node
## Ambient overworld tile animation (code prep code_prep_ambient_anim).
##
## Cycles source-faithful animated tiles (water, flowers, fountains,
## whirlpools, lava, waterfalls, tower pillars) on a loaded map's
## TileMapLayers, driven by maps/data/animated_tiles.json — the
## table authored from pret/pokered (home/vcopy.asm
## UpdateMovingBgTiles + per-tileset TILEANIM_* header flags) and
## pret/pokecrystal (engine/tilesets/tileset_anims.asm +
## data/tileset_anims.asm). See PREP_REPORT.md in the prep folder
## for the census and the timing derivation.
##
## How it works, against the renderer's real tile contract:
## - Maps are scenes whose root carries "region" and "tileset"
##   metadata; the table is keyed regions -> tileset key -> cycles.
## - A cycle names a base atlas tile id (linear, row-major:
##   id = y * columns + x, exactly how maps/tools/builder.gd fills
##   cells) plus "frames_resolved": the concrete atlas tile ids to
##   cycle through, produced by tools/build_animated_tiles.gd,
##   which appends the frame graphics as extra rows at the bottom
##   of the atlas and creates matching tiles in the TileSet with
##   the base tile's TileData copied verbatim (so passable-list
##   collision semantics never flicker mid-cycle). Cycles whose
##   table entry has no frames_resolved yet are skipped.
## - setup_map() scans every TileMapLayer of the map except the
##   hidden "Collision" helper layer, groups used cells by base
##   tile id, and from then on all cells of a cycle advance in
##   lockstep — the source games swap the tile's VRAM pattern, so
##   every on-screen instance changes together.
## - Cycles with a non-empty "gate" in the table are event-gated
##   in the source (the Ilex Forest trees animate only during the
##   Celebi event) and stay static here too; build 6 can pass open
##   gates through setup_map's open_gates argument.
## - A cell is only ever rewritten while it still shows a tile of
##   its own cycle (base or any frame), so edits by other systems
##   (or by gameplay) are never stomped.
## - _process forwards to advance_time(); tests drive
##   advance_time() directly for deterministic headless runs.

const TABLE_PATH: String = "res://maps/data/animated_tiles.json"

var _table: Dictionary = {}
var _table_loaded: bool = false
## Active cycle states. Each is a Dictionary:
## {layer, cells, frames (Array of Vector2i atlas coords),
##  frame_set (Dictionary id -> true), columns, interval, t, index}
var _active: Array = []


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_time(delta)


## Number of cycles currently animating (diagnostics / tests).
func active_cycle_count() -> int:
	return _active.size()


## Total map cells covered by active cycles (diagnostics / tests).
func animated_cell_count() -> int:
	var n: int = 0
	for raw_state in _active:
		var state: Dictionary = raw_state
		var cells: Array = state["cells"]
		n += cells.size()
	return n


## Stop animating. The current map keeps whatever frame is on
## screen; the loader calls this (via setup_map / synthetic maps)
## before the old map is freed.
func detach() -> void:
	_active.clear()
	if is_inside_tree():
		set_process(false)


## Aim the animator at a freshly loaded map. map_root is the map
## scene root (Node2D with "region"/"tileset" metadata already
## resolved by the caller); region and tileset_key select the
## table entry. open_gates lists table "gate" names currently open
## (empty = source default: gated cycles stay static).
func setup_map(map_root: Node, region: String, tileset_key: String, open_gates: Array = []) -> void:
	detach()
	if map_root == null:
		return
	_ensure_table()
	var regions: Dictionary = _table.get("regions", {})
	if not regions.has(region):
		return
	var region_table: Dictionary = regions[region]
	if not region_table.has(tileset_key):
		return
	var tileset_entry: Dictionary = region_table[tileset_key]
	var cycle_defs: Array = tileset_entry.get("cycles", [])
	if cycle_defs.is_empty():
		return
	# Frame tile id -> owning cycle's base id, so a cell that is
	# currently showing a mid-cycle frame (e.g. setup_map called
	# again on an already-animated map) is still claimed by its
	# cycle instead of being orphaned.
	var frame_to_base: Dictionary = {}
	for raw_def0 in cycle_defs:
		if not (raw_def0 is Dictionary):
			continue
		var def0: Dictionary = raw_def0
		var base0: int = int(def0.get("base", -1))
		if base0 < 0:
			continue
		var ids0: Array = def0.get("frames_resolved", [])
		for raw_id0 in ids0:
			frame_to_base[int(raw_id0)] = base0
	for child in map_root.get_children():
		if not (child is TileMapLayer):
			continue
		var layer: TileMapLayer = child as TileMapLayer
		if layer.name == "Collision":
			continue
		if layer.tile_set == null:
			continue
		var source: TileSetAtlasSource = layer.tile_set.get_source(0) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var columns: int = int(source.texture.get_width()) / source.texture_region_size.x
		if columns <= 0:
			continue
		# Index this layer's used cells by linear tile id, once.
		var by_id: Dictionary = {}
		for cell in layer.get_used_cells():
			if layer.get_cell_source_id(cell) != 0:
				continue
			var coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var tid: int = coords.y * columns + coords.x
			var owner: int = int(frame_to_base.get(tid, tid))
			if not by_id.has(owner):
				by_id[owner] = []
			var bucket: Array = by_id[owner]
			bucket.append(cell)
		for raw_def in cycle_defs:
			if not (raw_def is Dictionary):
				continue
			var def: Dictionary = raw_def
			var gate: String = str(def.get("gate", ""))
			if gate != "" and not open_gates.has(gate):
				continue
			var base: int = int(def.get("base", -1))
			var frame_ids: Array = def.get("frames_resolved", [])
			if base < 0 or frame_ids.size() < 2 or not by_id.has(base):
				continue
			var frames: Array = []
			var frame_set: Dictionary = {base: true}
			for raw_id in frame_ids:
				var fid: int = int(raw_id)
				frames.append(Vector2i(fid % columns, fid / columns))
				frame_set[fid] = true
			var state: Dictionary = {
				"layer": layer,
				"cells": by_id[base],
				"frames": frames,
				"frame_set": frame_set,
				"columns": columns,
				"interval": maxf(float(def.get("interval", 0.35)), 0.01),
				"t": 0.0,
				"index": 0,
			}
			_active.append(state)
			# Show frame 0 now: in the source the first animation
			# tick lands within one interval of entering the map,
			# and for most cycles frame 0 IS the base tile anyway.
			_apply(state)
	if is_inside_tree():
		set_process(not _active.is_empty())


## Advance every active cycle by delta seconds, applying frame
## changes whose step boundaries were crossed. Deterministic:
## same total delta in any chunking lands on the same frame.
func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	for raw_state in _active:
		var state: Dictionary = raw_state
		var interval: float = float(state["interval"])
		var t: float = float(state["t"]) + delta
		var frames: Array = state["frames"]
		var index: int = int(state["index"])
		var stepped: bool = false
		while t >= interval:
			t -= interval
			index = (index + 1) % frames.size()
			stepped = true
		state["t"] = t
		state["index"] = index
		if stepped:
			_apply(state)


func _apply(state: Dictionary) -> void:
	var layer: TileMapLayer = state["layer"]
	if layer == null or not is_instance_valid(layer):
		return
	var frames: Array = state["frames"]
	var coords: Vector2i = frames[int(state["index"])]
	var columns: int = int(state["columns"])
	var frame_set: Dictionary = state["frame_set"]
	var cells: Array = state["cells"]
	for raw_cell in cells:
		var cell: Vector2i = raw_cell
		if layer.get_cell_source_id(cell) != 0:
			continue
		var cur: Vector2i = layer.get_cell_atlas_coords(cell)
		var cur_id: int = cur.y * columns + cur.x
		if frame_set.has(cur_id):
			layer.set_cell(cell, 0, coords)


func _ensure_table() -> void:
	if _table_loaded:
		return
	_table_loaded = true
	if not FileAccess.file_exists(TABLE_PATH):
		return
	var text: String = FileAccess.get_file_as_string(TABLE_PATH)
	if text == "":
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var pd: Dictionary = parsed
		_table = pd
