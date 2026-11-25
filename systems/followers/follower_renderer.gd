class_name PUWFollowerRenderer
extends Node2D
## Production follower renderer (binding build 5, 2026-11-24).
##
## Before this build the follower data layer was complete —
## PUWFollowerController computes positions, behavior, sprite
## info and animation names, and thousands of follower sheets
## are bound — but NO node anywhere drew a follower. This
## renderer is that node: it slices the bound LOCAL follower
## sheets into directional SpriteFrames and plays them.
##
## Sources it presents (all real, bound, local frame data):
##   - Charset sheets (EBDX / Willow follower index rows):
##     the row's own sheet_layout (4x4 grid, rows
##     down/left/right/up). walk_<dir> = the row's frames in
##     order; idle_<dir> = the row's first frame (the stance
##     frame of the same sheet — no frame is invented).
##   - HGSS per-frame files (hgss_overworld_index rows):
##     frames[dir].frames / .shiny_frames, a real 2-frame
##     walk cycle per direction.
##   - MDX walk atlases (PUWMDXData.follower_sheet_for_slot):
##     a 4x4 atlas measured from the sheet itself, rows
##     down/left/right/up — the layout the MDX follower
##     production recorded for these sheets.
##
## PMD SpriteCollab sheets are remote URLs whose frame
## geometry lives in a remote AnimData.xml that is not held
## locally, so they are not sliced here; that stays a named
## gap (BUILD5_REPORT.md), never faked.
##
## Locomotion states come from the caller (the follower
## controller's world logic): set_moving + set_facing pick
## the clip. The renderer's own job is only to have real
## frames and play them.

const WALK_FPS: float = 8.0
const DIRECTIONS: Array = ["down", "left", "right", "up"]

var _sprite: AnimatedSprite2D = null
var _facing: String = "down"
var _moving: bool = false
var _has_frames: bool = false


func _init() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "FollowerSprite"
	add_child(_sprite)


## The AnimatedSprite2D doing the drawing (the playback suite
## reads its frame index to prove motion).
func sprite_node() -> AnimatedSprite2D:
	return _sprite


func has_frames() -> bool:
	return _has_frames


func current_animation() -> String:
	if _sprite == null:
		return ""
	return _sprite.animation


## Present a charset sheet (EBDX / Willow index row shape):
## sheet_path is a res:// path; layout carries cols/rows/
## row_order/cell_w/cell_h as recorded in the index.
func present_charset(sheet_path: String, layout: Dictionary) -> bool:
	var texture: Texture2D = _load_texture(sheet_path)
	if texture == null:
		return false
	var cols: int = int(layout.get("cols", 4))
	var rows: int = int(layout.get("rows", 4))
	var cell_w: int = int(layout.get("cell_w", 0))
	var cell_h: int = int(layout.get("cell_h", 0))
	if cell_w <= 0 or cell_h <= 0:
		cell_w = int(texture.get_width()) / maxi(1, cols)
		cell_h = int(texture.get_height()) / maxi(1, rows)
	var row_order: Array = layout.get("row_order", DIRECTIONS)
	return _present_grid(texture, cols, rows, cell_w, cell_h, row_order)


## Present an MDX 4x4 walk atlas: geometry is measured from
## the sheet itself (cell = sheet size / 4 on both axes);
## a sheet whose size is not divisible by 4 is refused.
func present_mdx_atlas(sheet_path: String) -> bool:
	var texture: Texture2D = _load_texture(sheet_path)
	if texture == null:
		return false
	var w: int = int(texture.get_width())
	var h: int = int(texture.get_height())
	if w % 4 != 0 or h % 4 != 0 or w == 0 or h == 0:
		return false
	return _present_grid(texture, 4, 4, w / 4, h / 4, DIRECTIONS)


## Present HGSS-style per-frame files: frames_by_dir maps a
## direction to {"frames": [paths], "shiny_frames": [paths]}
## exactly as the hgss_overworld_index rows record them.
func present_frame_files(frames_by_dir: Dictionary, shiny: bool) -> bool:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var any: bool = false
	for dir_value in DIRECTIONS:
		var dir: String = str(dir_value)
		var entry_value: Variant = frames_by_dir.get(dir, {})
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var key: String = "shiny_frames" if shiny else "frames"
		var paths_value: Variant = entry.get(key, [])
		if not (paths_value is Array):
			continue
		var paths: Array = paths_value
		if paths.is_empty():
			continue
		var walk_name: String = "walk_" + dir
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, WALK_FPS)
		for path_value in paths:
			var tex: Texture2D = _load_texture(str(path_value))
			if tex != null:
				frames.add_frame(walk_name, tex)
		if frames.get_frame_count(walk_name) == 0:
			frames.remove_animation(walk_name)
			continue
		var idle_name: String = "idle_" + dir
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, frames.get_frame_texture(walk_name, 0))
		any = true
	if not any:
		return false
	_sprite.sprite_frames = frames
	_has_frames = true
	_refresh_clip()
	return true


func set_facing(dir: String) -> void:
	if DIRECTIONS.has(dir):
		_facing = dir
		_refresh_clip()


func facing() -> String:
	return _facing


func set_moving(moving: bool) -> void:
	_moving = moving
	_refresh_clip()


func is_moving() -> bool:
	return _moving


func _present_grid(texture: Texture2D, cols: int, rows: int, cell_w: int, cell_h: int, row_order: Array) -> bool:
	if cols < 1 or rows < 1 or cell_w < 1 or cell_h < 1:
		return false
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	for row_idx in range(mini(rows, row_order.size())):
		var dir: String = str(row_order[row_idx])
		var walk_name: String = "walk_" + dir
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, WALK_FPS)
		for col in range(cols):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * cell_w, row_idx * cell_h, cell_w, cell_h)
			frames.add_frame(walk_name, atlas)
		var idle_name: String = "idle_" + dir
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, frames.get_frame_texture(walk_name, 0))
	_sprite.sprite_frames = frames
	_has_frames = true
	_refresh_clip()
	return true


func _refresh_clip() -> void:
	if not _has_frames or _sprite == null or _sprite.sprite_frames == null:
		return
	var clip: String = ("walk_" if _moving else "idle_") + _facing
	if _sprite.sprite_frames.has_animation(clip):
		if _sprite.animation != clip or not _sprite.is_playing():
			_sprite.play(clip)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var full: String = path
	if not full.begins_with("res://"):
		full = "res://" + full
	if not FileAccess.file_exists(full):
		return null
	var image: Image = Image.new()
	if image.load(full) != OK:
		return null
	return ImageTexture.create_from_image(image)
