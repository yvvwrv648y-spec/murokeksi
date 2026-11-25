# PUWPBAnimPlayer — plays real Pokemon Essentials battle animation
# sequences (PBAnimation data) in Godot. NEW FILE, binding build 6.
#
# What this is, in plain words:
# The held Pokemon H build (Essentials v20.1) carries 1,456 authored
# battle animation sequences: per-frame lists of picture cells cut
# from sprite sheets, plus timed sound/background events. This player
# plays the converted form of that data (converted/anim_index.json +
# anims_by_id.json from code_prep_battle_anim) exactly the way the
# original BattleAnimationPlayer.rb plays it:
#   - 20 frames per second (Graphics.frame_rate / 20 in the source).
#   - Sheet cells are 192x192, 5 per row; a cell's PATTERN picks one.
#   - PATTERN -1 draws the USER's battler sprite itself, -2 the
#     TARGET's: those cells move the real battler nodes.
#   - Cell x/y are canvas positions on the 512x384 Essentials battle
#     canvas, anchored by FOCUS: 1 = target, 2 = user, 3 = both,
#     4 = screen. The user anchor on that canvas is (128, 224), the
#     target anchor is (384, 96). A cell lands at
#     cell_pos + (real battler position - canvas anchor), so the
#     sequence follows the battlers wherever the stage puts them.
#   - PRIORITY picks the draw layer: 0 = back (z 10), 1 = front
#     (z 80), 2 = just behind the focus battler, 3 = just in front.
#     Battlers are expected at z_index 50 (the battle scene patch
#     documents this; the anchors' own z is read live, so 2/3 stay
#     relative even if a stage changes it).
# Honest approximations (flagged in PREP_REPORT.md):
#   - Cell TONE (grey/colour shift) needs a shader and is skipped;
#     COLOR and FLASH tints are applied as modulate tints.
#   - Angle sign follows Godot's clockwise rotation_degrees; the
#     RGSS original measures the other way. One-line flip if visual
#     QA at bind time says so (ANIM_ANGLE_SIGN).
#   - Background/foreground timing graphics are full-canvas
#     TextureRects sized to the 512x384 canvas; the stage scales
#     this node if its stage area differs.

class_name PUWPBAnimPlayer
extends Node2D

signal finished
signal frame_advanced(frame_index: int)
signal se_requested(se_name: String, volume: int, pitch: int)

const FPS: float = 20.0
const CELL_SIZE: int = 192
const CELL_COLS: int = 5
const MAX_SPRITES: int = 60
const CANVAS_SIZE: Vector2 = Vector2(512, 384)
const FOCUS_USER: Vector2 = Vector2(128, 224)
const FOCUS_TARGET: Vector2 = Vector2(384, 96)
const ANIM_ANGLE_SIGN: float = 1.0

## Where the animation sheet PNGs live (the converted Graphics/
## Animations set). Set by the owner before playing.
var graphics_dir: String = "res://assets/battle_anims/"

var _pool: Array = []            # Array of Sprite2D, MAX_SPRITES
var _bg_rect: TextureRect = null
var _fg_rect: TextureRect = null
var _blend_add: CanvasItemMaterial = null
var _blend_sub: CanvasItemMaterial = null
var _textures: Dictionary = {}

var _anim: Dictionary = {}
var _frames: Array = []
var _timings: Array = []
var _playing: bool = false
var _frame: int = 0
var _accum: float = 0.0
var _user: Node2D = null
var _target: Node2D = null
var _user_base: Dictionary = {}
var _target_base: Dictionary = {}


func _ready() -> void:
	_blend_add = CanvasItemMaterial.new()
	_blend_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_blend_sub = CanvasItemMaterial.new()
	_blend_sub.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_bg_rect = TextureRect.new()
	_bg_rect.name = "AnimBackground"
	_bg_rect.size = CANVAS_SIZE
	_bg_rect.z_index = -100
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.visible = false
	add_child(_bg_rect)
	for i in range(MAX_SPRITES):
		var spr: Sprite2D = Sprite2D.new()
		spr.name = "CellSprite%d" % i
		spr.visible = false
		add_child(spr)
		_pool.append(spr)
	_fg_rect = TextureRect.new()
	_fg_rect.name = "AnimForeground"
	_fg_rect.size = CANVAS_SIZE
	_fg_rect.z_index = 200
	_fg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg_rect.visible = false
	add_child(_fg_rect)


func is_playing() -> bool:
	return _playing


func current_frame() -> int:
	return _frame


func frame_count() -> int:
	return _frames.size()


## Load a sheet/background texture by its data name (names in the
## converted data carry their ".png"; a bare name is tried too).
## Returns null when the file is not held — the cell is then hidden,
## never faked.
func get_texture(tex_name: String) -> Texture2D:
	if tex_name == "":
		return null
	if _textures.has(tex_name):
		return _textures[tex_name]
	var tex: Texture2D = null
	var path: String = graphics_dir + tex_name
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		path = graphics_dir + tex_name + ".png"
	if ResourceLoader.exists(path):
		var loaded: Variant = ResourceLoader.load(path)
		if loaded is Texture2D:
			tex = loaded
	elif FileAccess.file_exists(path):
		var img: Image = Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	_textures[tex_name] = tex
	return tex


## Play one converted sequence. user_sprite and target_sprite are the
## two battler nodes (holders are fine — anything Node2D). The
## battlers' current transforms are snapshotted and restored when
## the sequence ends, whatever the cells did to them.
func play(anim: Dictionary, user_sprite: Node2D, target_sprite: Node2D) -> void:
	if _playing:
		stop()
	_anim = anim
	_frames = anim.get("frames", [])
	_timings = anim.get("timings", [])
	_user = user_sprite
	_target = target_sprite
	_user_base = _snapshot(user_sprite)
	_target_base = _snapshot(target_sprite)
	_frame = 0
	_accum = 0.0
	if _frames.is_empty():
		finished.emit()
		return
	_playing = true
	_apply_frame(0)
	_apply_timings(0)
	frame_advanced.emit(0)


func stop() -> void:
	if not _playing:
		return
	_playing = false
	_cleanup()
	finished.emit()


func _process(delta: float) -> void:
	if not _playing:
		return
	_accum += delta
	var step: float = 1.0 / FPS
	while _playing and _accum >= step:
		_accum -= step
		_frame += 1
		if _frame >= _frames.size():
			_playing = false
			_cleanup()
			finished.emit()
			break
		_apply_frame(_frame)
		_apply_timings(_frame)
		frame_advanced.emit(_frame)


func _snapshot(node: Node2D) -> Dictionary:
	if node == null:
		return {}
	return {
		"position": node.global_position,
		"scale": node.scale,
		"rotation": node.rotation_degrees,
		"modulate": node.modulate,
	}


func _restore(node: Node2D, snap: Dictionary) -> void:
	if node == null or snap.is_empty():
		return
	node.global_position = snap["position"]
	node.scale = snap["scale"]
	node.rotation_degrees = snap["rotation"]
	node.modulate = snap["modulate"]


func _cleanup() -> void:
	for spr in _pool:
		spr.visible = false
	_restore(_user, _user_base)
	_restore(_target, _target_base)


## Canvas anchor for a focus value, and the matching live position.
func _focus_points(focus: int) -> Array:
	match focus:
		1:
			return [FOCUS_TARGET, _target.global_position if _target != null else FOCUS_TARGET]
		2:
			return [FOCUS_USER, _user.global_position if _user != null else FOCUS_USER]
		3:
			var anchor: Vector2 = (FOCUS_USER + FOCUS_TARGET) * 0.5
			var live: Vector2 = anchor
			if _user != null and _target != null:
				live = (_user.global_position + _target.global_position) * 0.5
			return [anchor, live]
		_:
			return [Vector2.ZERO, global_position]


func _cell_global_position(cell: Array) -> Vector2:
	var focus: int = int(cell[10]) if cell.size() > 10 else 4
	var pts: Array = _focus_points(focus)
	var anchor: Vector2 = pts[0]
	var live: Vector2 = pts[1]
	return Vector2(float(cell[1]), float(cell[2])) + live - anchor


func _priority_z(cell: Array) -> int:
	var prio: int = int(cell[11]) if cell.size() > 11 else 1
	match prio:
		0:
			return 10
		1:
			return 80
		2, 3:
			var focus: int = int(cell[10]) if cell.size() > 10 else 4
			var battler: Node2D = _user if focus == 2 else _target
			var base_z: int = battler.z_index if battler != null else 50
			return base_z - 1 if prio == 2 else base_z + 1
		_:
			return 80


## A converted cell is positional numerics (anim_index cell_fields)
## plus an optional extras dict of flat numeric arrays. A cell failing
## that shape is a source-dump link artifact — the converter logs the
## same family as anomalies and emits an empty slot; if one ever
## reaches the player anyway, treat it as an empty slot instead of
## letting a cast error abort the frame mid-playback.
func _cell_scalars_ok(c: Array) -> bool:
	for i in range(mini(12, c.size())):
		var t: int = typeof(c[i])
		if t != TYPE_INT and t != TYPE_FLOAT and t != TYPE_BOOL:
			return false
	if c.size() > 12:
		if not (c[12] is Dictionary):
			return false
		var ex: Dictionary = c[12]
		for k in ex:
			var v: Variant = ex[k]
			if v is Array:
				for x in v:
					var xt: int = typeof(x)
					if xt != TYPE_INT and xt != TYPE_FLOAT and xt != TYPE_BOOL:
						return false
			else:
				var vt: int = typeof(v)
				if vt != TYPE_INT and vt != TYPE_FLOAT and vt != TYPE_BOOL:
					return false
	return true


func _apply_frame(idx: int) -> void:
	# Battlers start each frame back at base; a battler cell in this
	# frame then moves them (same as the original player, which
	# re-derives battler sprite positions per frame).
	_restore(_user, _user_base)
	_restore(_target, _target_base)
	var frame_cells: Array = _frames[idx]
	var graphic: String = str(_anim.get("graphic", ""))
	var sheet: Texture2D = get_texture(graphic) if graphic != "" else null
	for slot in range(MAX_SPRITES):
		var spr: Sprite2D = _pool[slot]
		if slot >= frame_cells.size():
			spr.visible = false
			continue
		var cell: Variant = frame_cells[slot]
		if not (cell is Array) or (cell as Array).is_empty():
			spr.visible = false
			continue
		var c: Array = cell
		if not _cell_scalars_ok(c):
			spr.visible = false
			continue
		var pattern: int = int(c[0])
		if pattern == -1 or pattern == -2:
			spr.visible = false
			_apply_battler_cell(c, _user if pattern == -1 else _target)
			continue
		if sheet == null:
			spr.visible = false
			continue
		_apply_sheet_cell(spr, c, sheet)


func _apply_sheet_cell(spr: Sprite2D, c: Array, sheet: Texture2D) -> void:
	var pattern: int = int(c[0])
	spr.texture = sheet
	spr.region_enabled = true
	var col: int = pattern % CELL_COLS
	var row: int = pattern / CELL_COLS
	spr.region_rect = Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	spr.global_position = _cell_global_position(c)
	spr.scale = Vector2(maxf(0.0, float(c[3]) / 100.0), maxf(0.0, float(c[4]) / 100.0))
	spr.rotation_degrees = ANIM_ANGLE_SIGN * float(c[5])
	spr.flip_h = int(c[6]) != 0
	# Compact layout (anim_index cell_fields): opacity is field 7,
	# blend is field 8. (These two reads were swapped in the first
	# draft, which computed opacity from the blend field — 0 for most
	# cells — and left every sheet cell invisible.)
	var opacity: float = clampf(float(c[7]) / 255.0, 0.0, 1.0)
	spr.modulate = _cell_tint(c, opacity)
	match int(c[8]):
		1:
			spr.material = _blend_add
		2:
			spr.material = _blend_sub
		_:
			spr.material = null
	spr.z_index = _priority_z(c)
	spr.visible = int(c[9]) != 0 and opacity > 0.0


func _apply_battler_cell(c: Array, battler: Node2D) -> void:
	if battler == null:
		return
	battler.global_position = _cell_global_position(c)
	var snap: Dictionary = _user_base if battler == _user else _target_base
	var base_scale: Vector2 = snap.get("scale", Vector2.ONE)
	battler.scale = Vector2(base_scale.x * float(c[3]) / 100.0, base_scale.y * float(c[4]) / 100.0)
	battler.rotation_degrees = ANIM_ANGLE_SIGN * float(c[5])
	var opacity: float = clampf(float(c[7]) / 255.0, 0.0, 1.0)
	var tint: Color = _cell_tint(c, opacity)
	battler.modulate = tint


## COLOR tint and FLASH tint from the optional trailing extras dict.
## Layout: {"c": [r,g,b,a], "t": [tone...], "f": [r,g,b,a], "l": 1}.
## Tone is skipped on purpose (needs a shader; see header).
func _cell_tint(c: Array, opacity: float) -> Color:
	var tint: Color = Color(1, 1, 1, opacity)
	if c.size() > 12 and c[12] is Dictionary:
		var ex: Dictionary = c[12]
		if ex.has("f"):
			var f: Array = ex["f"]
			if f.size() >= 4 and int(f[3]) > 0:
				return Color(float(f[0]) / 255.0, float(f[1]) / 255.0, float(f[2]) / 255.0, opacity)
		if ex.has("c"):
			var col: Array = ex["c"]
			if col.size() >= 3:
				tint = Color(float(col[0]) / 255.0, float(col[1]) / 255.0, float(col[2]) / 255.0, opacity)
	return tint


func _apply_timings(idx: int) -> void:
	for t in _timings:
		if not (t is Dictionary):
			continue
		var td: Dictionary = t
		if int(td.get("frame", -1)) != idx:
			continue
		var ttype: int = int(td.get("type", 0))
		match ttype:
			0:
				se_requested.emit(str(td.get("name", "")), int(td.get("volume", 100)), int(td.get("pitch", 100)))
			1, 2:
				_apply_overlay_timing(_bg_rect, td, ttype == 2)
			3, 4:
				_apply_overlay_timing(_fg_rect, td, ttype == 4)


func _apply_overlay_timing(rect: TextureRect, td: Dictionary, fade: bool) -> void:
	if rect == null:
		return
	var tex_name: String = str(td.get("name", ""))
	if tex_name != "":
		var tex: Texture2D = get_texture(tex_name)
		if tex != null:
			rect.texture = tex
	var target_a: float = clampf(float(td.get("opacity", 255)) / 255.0, 0.0, 1.0)
	rect.visible = true
	if fade:
		var dur: float = maxf(1.0, float(td.get("duration", 1))) / FPS
		var tween: Tween = create_tween()
		tween.tween_property(rect, "modulate:a", target_a, dur)
	else:
		rect.modulate.a = target_a
