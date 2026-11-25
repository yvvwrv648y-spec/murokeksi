class_name PUWOWAnimator
extends RefCounted
## Overworld animation frame builder (code prep, 2026-11-24).
##
## Builds SpriteFrames for overworld actors (NPCs, followers)
## from the charset sheets the project ALREADY holds, in the
## animation naming the overworld state machine uses:
## "<state>_<facing>" with states idle / walk / run and facings
## down / up / left / right -- the same names PUWPlayerController
## plays for the player ("walk_down", "idle_up", ...).
##
## Sheet formats covered, all verified against the real files
## (see PREP_REPORT.md census):
## - RMXP charsets, 4 cols x 4 rows (EBDX / Willow / swim /
##   levitate follower charsets at 256x256 or 512x512; MDX
##   follower walk atlases at e.g. 504x504, 384x384): rows are
##   directions in RMXP order down, left, right, up; the four
##   frames in a row are the walk cycle, and frame index 1 is
##   the standing frame (RMXP convention).
## - NPC bank sheets, 3 cols x 4 rows of 32 px cells (96x128,
##   characters/npcs/bank/<id>_walk.png): same row order; the
##   walk cycle is [0, 1, 2, 1] and frame 1 (centre) is the
##   standing frame.
## - Per-frame file sets (HGSS overworld followers): one PNG
##   per (direction, step), 2 steps per direction; idle is the
##   first step frame, walk loops the steps.
##
## This builder only ever slices the texture it is handed. It
## never invents, mirrors, or substitutes frames: a direction
## row that is absent from the sheet is absent from the result.

## Direction rows in RMXP charset order (row 0 first).
const ROW_DIRECTIONS: Array = ["down", "left", "right", "up"]
const DIRECTIONS: Array = ["down", "up", "left", "right"]
## Playback rates: the cast CLIP_FPS values the player
## controller uses (idle 4.0, walk 7.5, run 11.0).
const FPS_IDLE: float = 4.0
const FPS_WALK: float = 7.5
const FPS_RUN: float = 11.0


## Build SpriteFrames from a charset texture of cols x rows
## square-ish cells. Returns an empty SpriteFrames when the
## texture is null or the grid does not divide it.
static func charset_frames(tex: Texture2D, cols: int, rows: int) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if tex == null or cols <= 0 or rows <= 0:
		return frames
	var sheet_w: int = tex.get_width()
	var sheet_h: int = tex.get_height()
	if sheet_w % cols != 0 or sheet_h % rows != 0:
		return frames
	var cell_w: int = sheet_w / cols
	var cell_h: int = sheet_h / rows
	# Standing-frame index and walk cycle per column count,
	# per the RMXP convention documented in the header.
	var stand_index: int = 1 if cols >= 2 else 0
	var cycle: Array = []
	if cols == 3:
		cycle = [0, 1, 2, 1]
	else:
		for c in range(cols):
			cycle.append(c)
	for row in range(rows):
		if row >= ROW_DIRECTIONS.size():
			break
		var dir_name: String = str(ROW_DIRECTIONS[row])
		var row_textures: Array = []
		for col in range(cols):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(float(col * cell_w), float(row * cell_h), float(cell_w), float(cell_h))
			row_textures.append(atlas)
		_add_clip(frames, "idle_" + dir_name, [row_textures[stand_index]], FPS_IDLE, true)
		# Idle bob (fold-in round, battle_presentation PATCHES
		# P4): the standing frame plus the same cell region
		# shifted +1 px vertically — a 1 px breathing bob at
		# idle rate, looping. The shifted region crops the
		# cell's bottom row; a per-format QA eyeball is owed
		# (recorded as a Stage 9 note, per the patch).
		var stand_tex: AtlasTexture = row_textures[stand_index]
		var bob_tex: AtlasTexture = AtlasTexture.new()
		bob_tex.atlas = tex
		bob_tex.region = Rect2(stand_tex.region.position.x, stand_tex.region.position.y + 1.0, stand_tex.region.size.x, stand_tex.region.size.y)
		_add_clip(frames, "idle_bob_" + dir_name, [stand_tex, bob_tex], FPS_IDLE, true)
		var walk_textures: Array = []
		for idx_value in cycle:
			walk_textures.append(row_textures[int(idx_value)])
		_add_clip(frames, "walk_" + dir_name, walk_textures, FPS_WALK, true)
		_add_clip(frames, "run_" + dir_name, walk_textures, FPS_RUN, true)
	return frames


## Build SpriteFrames from per-direction frame texture lists
## (HGSS-style per-frame files). frames_by_dir maps a direction
## name to an Array of Texture2D in step order. Directions with
## an empty list are skipped, never filled from another row.
static func frame_list_frames(frames_by_dir: Dictionary) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	for dir_value in DIRECTIONS:
		var dir_name: String = str(dir_value)
		var list_value: Variant = frames_by_dir.get(dir_name, [])
		if not (list_value is Array):
			continue
		var list: Array = list_value
		if list.is_empty():
			continue
		_add_clip(frames, "idle_" + dir_name, [list[0]], FPS_IDLE, true)
		# Idle bob (fold-in round, PATCHES P4): same +1 px
		# shifted-region second frame as the charset builder.
		var first_tex: Texture2D = list[0] as Texture2D
		if first_tex != null:
			var bob_atlas: AtlasTexture = AtlasTexture.new()
			bob_atlas.atlas = first_tex
			bob_atlas.region = Rect2(0.0, 1.0, float(first_tex.get_width()), float(first_tex.get_height()))
			_add_clip(frames, "idle_bob_" + dir_name, [first_tex, bob_atlas], FPS_IDLE, true)
		_add_clip(frames, "walk_" + dir_name, list, FPS_WALK, true)
		_add_clip(frames, "run_" + dir_name, list, FPS_RUN, true)
	return frames


static func _add_clip(frames: SpriteFrames, clip_name: String, textures: Array, fps: float, loop: bool) -> void:
	if frames.has_animation(clip_name):
		frames.remove_animation(clip_name)
	frames.add_animation(clip_name)
	frames.set_animation_loop(clip_name, loop)
	frames.set_animation_speed(clip_name, fps)
	for tex_value in textures:
		if tex_value is Texture2D:
			var tex: Texture2D = tex_value
			frames.add_frame(clip_name, tex)
