class_name PUWTrainerAlert
extends Node2D
## Trainer "!" alert + approach walk (overworld-life prep,
## 2026-11-24).
##
## The gap: PUWSpawner.check_sight + the glue's
## scan_trainer_trigger detect a spotted player and the
## host starts the battle the same tick -- no "!" alert
## renders and the trainer never walks over. The BW2 beat
## (alert, pause, approach, THEN battle) is missing.
##
## This driver supplies the beat WITHOUT a parallel
## engagement path:
## - Detection is the existing predicate, verbatim:
##   find_spotter() runs PUWSpawner.trainer_dict_from_node
##   + PUWSpawner.check_sight over the glue's spawned
##   children with the same blocked-tile callable
##   scan_trainer_trigger builds (map_loader.is_solid_tile).
##   The alert can therefore never fire for a trainer the
##   existing scan would not engage, and stealth / sight
##   semantics stay whatever the spawner says they are.
## - The approach moves the trainer's OWN spawned node,
##   tile by tile along the sight line (check_sight
##   guarantees the row/column between is unblocked), at
##   the player's walk speed, playing the node's own
##   PUWNPCSpriteView walk clip; the node's tile /
##   direction / facing metadata are updated per tile so
##   the trainer dict the scan rebuilds afterwards is the
##   walked-to one.
## - On completion it emits alert_finished and the HOST
##   runs the untouched existing flow
##   (glue.scan_trainer_trigger -> start_trainer_battle).
##   Adjacent + facing the player, the trainer re-triggers
##   through check_sight itself. This class never builds a
##   team and never starts a battle.
##
## Host wiring (4 small edits) is in
## host_patch/PUW_GAME_HOST_PATCH.md: while is_running()
## the host returns early from host_tick, the same input
## lock the event runner gets. A-press interaction bumps
## are NOT alerted -- they reach battle through the
## existing interaction trigger, as before.

signal alert_finished(trainer_node: Node2D)
signal alert_cancelled(trainer_node: Node2D)

## PUW DESIGN PARAMETERS (labeled, not sourced): the
## alert hold matches the series' beat (~half a second
## on the "!"); the approach speed is the player's own
## walk speed, PUWPlayerController.SPEEDS["walk"] = 4.0
## tiles/sec, restated here so this driver carries no
## compile dependency on the player controller.
const ALERT_HOLD_SECONDS: float = 0.5
const APPROACH_TILES_PER_SECOND: float = 4.0
const ALERT_GLYPH: String = "!"

enum Phase { IDLE, ALERT, APPROACH }

var _phase: int = Phase.IDLE
var _trainer_node: Node2D = null
var _view: PUWNPCSpriteView = null
var _bubble: PUWEmoteBubbleView = null
var _tile_size: float = 16.0
var _player_tile: Vector2i = Vector2i.ZERO
var _path: Array = [] # Array of Vector2i: tiles to enter, in order
var _seg_from: Vector2 = Vector2.ZERO
var _seg_to: Vector2 = Vector2.ZERO
var _seg_elapsed: float = 0.0
var _phase_elapsed: float = 0.0


## The first spawned trainer (in glue child order, the
## same order scan_trainer_trigger scans) whose sight
## trigger fires against player_tile. Sight ONLY --
## interaction triggers are the host's bump path, not an
## alert. Returns {"node": Node2D, "trainer": Dictionary}
## or {} when no trainer spots the player.
static func find_spotter(glue: Node, player_tile: Vector2i) -> Dictionary:
	if glue == null:
		return {}
	var blocked: Callable = Callable()
	var loader_value: Variant = glue.get("map_loader")
	if loader_value is Object:
		var loader: Object = loader_value
		blocked = Callable(loader, "is_solid_tile")
	for child_value in glue.get_children():
		var node: Node = child_value
		if not node.has_meta("kind"):
			continue
		if str(node.get_meta("kind", "")) != "trainer":
			continue
		var trainer: Dictionary = PUWSpawner.trainer_dict_from_node(node)
		if trainer.is_empty():
			continue
		if PUWSpawner.check_sight(trainer, player_tile, blocked):
			return {"node": node, "trainer": trainer}
	return {}


func is_running() -> bool:
	return _phase != Phase.IDLE


## The trainer node the running (or last) sequence is
## about; null before the first alert.
func current_trainer_node() -> Node2D:
	return _trainer_node


## Find a spotter and start its alert. npc_views is the
## host's instance-id -> PUWNPCSpriteView map; a trainer
## with no view still alerts (bubble on the node itself)
## and still walks. Returns false when already running
## or when no trainer spots the player.
func try_begin(glue: Node, player_tile: Vector2i, npc_views: Dictionary) -> bool:
	if is_running() or glue == null:
		return false
	var spot: Dictionary = find_spotter(glue, player_tile)
	if spot.is_empty():
		return false
	var node_value: Variant = spot.get("node")
	if not (node_value is Node2D):
		return false
	var node: Node2D = node_value
	var view: PUWNPCSpriteView = null
	var view_value: Variant = npc_views.get(node.get_instance_id())
	if view_value is PUWNPCSpriteView:
		var found_view: PUWNPCSpriteView = view_value
		view = found_view
	return begin(node, view, _tile_size_for(glue), player_tile)


## Start the alert for one trainer node. Computes the
## approach path: straight along the sight line to the
## tile adjacent to the player (empty when already
## adjacent -- the "!" still plays). False when already
## running or the node carries no tile metadata.
func begin(trainer_node: Node2D, view: PUWNPCSpriteView, tile_size: float, player_tile: Vector2i) -> bool:
	if is_running() or trainer_node == null:
		return false
	if not trainer_node.has_meta("tile"):
		return false
	_trainer_node = trainer_node
	_view = view
	_tile_size = tile_size
	_player_tile = player_tile
	var start_tile_value: Variant = trainer_node.get_meta("tile")
	var start_tile: Vector2i = start_tile_value if start_tile_value is Vector2i else Vector2i.ZERO
	_path = _approach_path(start_tile, player_tile)
	_phase = Phase.ALERT
	_phase_elapsed = 0.0
	_seg_elapsed = 0.0
	_attach_bubble()
	if _bubble != null:
		_bubble.show_glyph(ALERT_GLYPH)
	if _view != null:
		_view.set_moving(false)
	set_process(true)
	return true


## Abort a running sequence (map change, battle from
## another path): bubble down, trainer idles, no signal
## hand-off to battle.
func cancel() -> void:
	if not is_running():
		return
	var node: Node2D = _trainer_node
	if _bubble != null:
		_bubble.clear()
	if _view != null:
		_view.set_moving(false)
	_reset()
	if node != null:
		alert_cancelled.emit(node)


## Advance the sequence. _process drives this in game;
## headless tests call it directly.
func tick(delta: float) -> void:
	if not is_running():
		return
	match _phase:
		Phase.ALERT:
			_phase_elapsed += delta
			if _phase_elapsed >= ALERT_HOLD_SECONDS:
				if _path.is_empty():
					_finish()
				else:
					_phase = Phase.APPROACH
					_start_segment()
		Phase.APPROACH:
			_seg_elapsed += delta
			var seg_seconds: float = 1.0 / APPROACH_TILES_PER_SECOND
			var t: float = clampf(_seg_elapsed / seg_seconds, 0.0, 1.0)
			if _trainer_node != null:
				_trainer_node.position = _seg_from.lerp(_seg_to, t)
			if t >= 1.0:
				_complete_segment()


func _process(delta: float) -> void:
	tick(delta)


## Tiles the trainer enters, from its tile toward the
## player along the dominant axis, stopping one tile
## short of the player. check_sight guarantees the
## trainer and player share the facing row/column, so
## the dominant axis IS the sight line and every tile
## strictly between is unblocked by the sight predicate
## itself; the final adjacent tile is either a between
## tile (dist >= 2, proven unblocked) or the trainer
## never moves (dist == 1).
static func _approach_path(from_tile: Vector2i, player_tile: Vector2i) -> Array:
	var path: Array = []
	var delta: Vector2i = player_tile - from_tile
	var step: Vector2i = Vector2i.ZERO
	if absi(delta.x) >= absi(delta.y):
		step = Vector2i(signi(delta.x), 0)
	else:
		step = Vector2i(0, signi(delta.y))
	if step == Vector2i.ZERO:
		return path
	var dist: int = absi(delta.x) + absi(delta.y)
	var cur: Vector2i = from_tile
	for i in range(dist - 1):
		cur += step
		path.append(cur)
	return path


static func _dir_name(step: Vector2i) -> String:
	if step.x > 0:
		return "right"
	if step.x < 0:
		return "left"
	if step.y > 0:
		return "down"
	return "up"


func _tile_size_for(glue: Node) -> float:
	var report_value: Variant = glue.get("spawn_report")
	if report_value is Dictionary:
		var report: Dictionary = report_value
		var ts: float = float(report.get("tile_size", 0))
		if ts > 0.0:
			return ts
	var loader_value: Variant = glue.get("map_loader")
	if loader_value is Object:
		var loader: Object = loader_value
		var px_value: Variant = loader.get("tile_size_px")
		if px_value is int or px_value is float:
			var px: float = float(px_value)
			if px > 0.0:
				return px
	return 16.0


## The bubble lives on the trainer's sprite view when it
## has one (anchored above the sprite's head), else on
## the spawned node itself at the default anchor.
func _attach_bubble() -> void:
	var parent: Node2D = _trainer_node
	if _view != null:
		parent = _view
	if parent == null:
		_bubble = null
		return
	var existing: Node = parent.get_node_or_null("EmoteBubble")
	if existing is PUWEmoteBubbleView:
		_bubble = existing
	else:
		_bubble = PUWEmoteBubbleView.new()
		_bubble.name = "EmoteBubble"
		parent.add_child(_bubble)
	if _view != null:
		_bubble.position = Vector2(0.0, PUWEmoteBubbleView.anchor_y_for(_view))
	else:
		_bubble.position = Vector2(0.0, PUWEmoteBubbleView.DEFAULT_ANCHOR_Y)


func _start_segment() -> void:
	if _trainer_node == null or _path.is_empty():
		return
	var target_value: Variant = _path[0]
	var target: Vector2i = target_value if target_value is Vector2i else Vector2i.ZERO
	_seg_from = _trainer_node.position
	_seg_to = Vector2(target) * _tile_size
	_seg_elapsed = 0.0
	var cur_tile_value: Variant = _trainer_node.get_meta("tile")
	var cur_tile: Vector2i = cur_tile_value if cur_tile_value is Vector2i else Vector2i.ZERO
	var step: Vector2i = target - cur_tile
	if _view != null:
		_view.face(_dir_name(step))
		_view.set_moving(true)


func _complete_segment() -> void:
	if _trainer_node == null or _path.is_empty():
		return
	var target_value: Variant = _path[0]
	var target: Vector2i = target_value if target_value is Vector2i else Vector2i.ZERO
	_path.remove_at(0)
	_trainer_node.position = Vector2(target) * _tile_size
	# Keep the node's metadata truthful per tile: the
	# trainer dict scan_trainer_trigger rebuilds comes
	# from this meta, so the walked-to trainer is the
	# one that engages.
	var step: Vector2i = target - _trainer_tile()
	_trainer_node.set_meta("tile", target)
	if step != Vector2i.ZERO:
		var meta_dir: String = _dir_name(step).to_upper()
		_trainer_node.set_meta("direction", meta_dir)
		_trainer_node.set_meta("facing", PUWSpawner.facing_vector(meta_dir))
	if _path.is_empty():
		_finish()
	else:
		_start_segment()


func _trainer_tile() -> Vector2i:
	if _trainer_node == null:
		return Vector2i.ZERO
	var v: Variant = _trainer_node.get_meta("tile", Vector2i.ZERO)
	if v is Vector2i:
		var t: Vector2i = v
		return t
	return Vector2i.ZERO


func _finish() -> void:
	var node: Node2D = _trainer_node
	if _bubble != null:
		_bubble.clear()
	if _view != null and node != null:
		_view.set_moving(false)
		# Face the player from the final tile (the sight
		# line's own direction, so the post-approach
		# scan's check_sight fires on this trainer).
		var final_tile: Vector2i = _trainer_tile()
		var to_player: Vector2i = _player_tile - final_tile
		var step: Vector2i = Vector2i.ZERO
		if absi(to_player.x) >= absi(to_player.y):
			step = Vector2i(signi(to_player.x), 0)
		else:
			step = Vector2i(0, signi(to_player.y))
		if step != Vector2i.ZERO:
			_view.face(_dir_name(step))
			var meta_dir: String = _dir_name(step).to_upper()
			node.set_meta("direction", meta_dir)
			node.set_meta("facing", PUWSpawner.facing_vector(meta_dir))
	_reset()
	if node != null:
		alert_finished.emit(node)


func _reset() -> void:
	_phase = Phase.IDLE
	_trainer_node = null
	_view = null
	_bubble = null
	_path = []
	_phase_elapsed = 0.0
	_seg_elapsed = 0.0
	set_process(false)
