class_name PUWEmoteBubbleView
extends Node2D
## Emote bubble renderer (overworld-life prep, 2026-11-24).
##
## The missing VIEW half of two systems that already produce
## emote data:
## - PUWFollowerController: every behavior_tick() record
##   carries an "emote" glyph + the entry carries emote_ttl,
##   produced only by genuine events through show_emote()
##   (interaction / care / find-delivery / detection /
##   encounter). PUWFollowerSpriteView now feeds that glyph
##   here (see the patched follower_sprite_view.gd).
## - PUWTrainerAlert: the trainer "!" on a sight trigger.
##
## The glyph set is the one the producers emit
## (PUWFollowerCare.EMOTES + the controller's own calls):
## "!" "?" "♥" "♪" "Z". Rendering is DRAWN, never a
## placeholder box: a white rounded bubble with a dark
## outline, drop shadow and a tail, drawn with canvas
## primitives in _draw(), and the glyph either as text (when
## the active font carries the codepoint) or as a vector
## drawing for "♥" / "♪" (the two glyphs the project's text
## fonts are not guaranteed to carry). No art asset is
## loaded, so the bubble can never go missing with a sheet.
##
## This node's origin is the bubble's TIP (bottom centre):
## the parent places it just above the actor's head with
## anchor_y_for(). Lifetime is NOT owned here -- the
## follower controller's emote_ttl clears the record's
## glyph and the view hides; the trainer alert holds its
## own timer. This view only pops in, draws, and hides.

## PUW DESIGN PARAMETERS (labeled, not sourced): bubble
## geometry in px, sized against the 32 px NPC bank cells
## and the follower charsets; pop-in duration; per-glyph
## ink colours in the BW2 emote idiom (dark marks on a
## white bubble, heart in warm pink, alert in red).
const BUBBLE_HALF_W: float = 10.0
const BUBBLE_TOP: float = -19.0
const BUBBLE_BOTTOM: float = -3.0
const BUBBLE_RADIUS: float = 4.0
const TAIL_HALF_W: float = 3.5
const GLYPH_FONT_SIZE: int = 13
const POP_SECONDS: float = 0.12
const DEFAULT_ANCHOR_Y: float = -20.0
const HEAD_GAP_PX: float = 2.0

const FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const INK_COLOR: Color = Color(0.157, 0.157, 0.235, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.25)
const GLYPH_COLORS: Dictionary = {
	"!": Color(0.847, 0.204, 0.173, 1.0),
	"?": Color(0.157, 0.314, 0.784, 1.0),
	"♥": Color(0.910, 0.365, 0.541, 1.0),
	"♪": Color(0.157, 0.157, 0.235, 1.0),
	"Z": Color(0.314, 0.314, 0.627, 1.0),
}
## Glyphs with a vector fallback drawing, used when the
## active font has no codepoint for them.
const VECTOR_GLYPHS: Array = ["♥", "♪"]

## Optional font override. The bind sets this to the
## project's rounded bold font (res://fonts/
## MPLUSRounded1c-Bold.ttf); unset, the engine fallback
## font is used. "♥" / "♪" fall back to vector drawing
## whenever the active font lacks them either way.
var bubble_font: Font = null

var _glyph: String = ""
var _showing: bool = false
var _pop_elapsed: float = 0.0
var _style: StyleBoxFlat = null


func _init() -> void:
	visible = false
	z_index = 10
	_style = StyleBoxFlat.new()
	_style.bg_color = FILL_COLOR
	_style.border_color = INK_COLOR
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(int(BUBBLE_RADIUS))
	_style.shadow_color = SHADOW_COLOR
	_style.shadow_size = 2
	_style.shadow_offset = Vector2(1.0, 1.0)
	set_process(false)


## The Y offset that puts this bubble's tip just above the
## head of an AnimatedSprite2D actor view: half the current
## frame's height (the sprite is centred on the actor
## origin) plus a small gap. DEFAULT_ANCHOR_Y when the view
## has no frames to measure.
static func anchor_y_for(view: AnimatedSprite2D) -> float:
	if view != null and view.sprite_frames != null:
		var clip: String = view.animation
		if clip != "" and view.sprite_frames.has_animation(clip) and view.sprite_frames.get_frame_count(clip) > 0:
			var tex: Texture2D = view.sprite_frames.get_frame_texture(clip, 0)
			if tex != null:
				return -0.5 * float(tex.get_height()) - HEAD_GAP_PX
	return DEFAULT_ANCHOR_Y


## How a glyph would be drawn with the given font: "vector"
## for a VECTOR_GLYPHS glyph the font cannot render (or no
## font at all), else "text". Pure; the tests pin both
## branches through it.
static func render_mode(glyph: String, font: Font) -> String:
	if VECTOR_GLYPHS.has(glyph):
		if font == null:
			return "vector"
		if glyph.length() > 0 and not font.has_char(glyph.unicode_at(0)):
			return "vector"
	return "text"


## The ink colour a glyph is drawn in.
static func glyph_color(glyph: String) -> Color:
	var c_value: Variant = GLYPH_COLORS.get(glyph, INK_COLOR)
	if c_value is Color:
		var c: Color = c_value
		return c
	return INK_COLOR


## Show a glyph. Returns true when the bubble state
## changed; re-showing the glyph already up is a no-op so
## a per-tick caller (apply_behavior) never restarts the
## pop-in.
func show_glyph(glyph: String) -> bool:
	if glyph == "":
		return clear()
	if _showing and _glyph == glyph:
		return false
	_glyph = glyph
	_showing = true
	_pop_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()
	return true


## Hide the bubble. Returns true when the state changed.
func clear() -> bool:
	if not _showing:
		return false
	_glyph = ""
	_showing = false
	visible = false
	set_process(false)
	return true


func is_showing() -> bool:
	return _showing


func current_glyph() -> String:
	return _glyph


func _process(delta: float) -> void:
	if not _showing:
		set_process(false)
		return
	if _pop_elapsed < POP_SECONDS:
		_pop_elapsed = minf(_pop_elapsed + delta, POP_SECONDS)
		var t: float = clampf(_pop_elapsed / POP_SECONDS, 0.0, 1.0)
		var s: float = lerpf(0.5, 1.0, t) + 0.15 * sin(PI * t) * (1.0 - t)
		scale = Vector2(s, s)
	else:
		scale = Vector2.ONE
		set_process(false)


func _active_font() -> Font:
	if bubble_font != null:
		return bubble_font
	return ThemeDB.fallback_font


func _draw() -> void:
	if not _showing or _glyph == "":
		return
	var body: Rect2 = Rect2(-BUBBLE_HALF_W, BUBBLE_TOP, BUBBLE_HALF_W * 2.0, BUBBLE_BOTTOM - BUBBLE_TOP)
	# Tail first (the body's bottom border overlaps its
	# root): white wedge + ink edges, tip at the origin.
	var tail: PackedVector2Array = PackedVector2Array([
		Vector2(-TAIL_HALF_W, BUBBLE_BOTTOM - 1.0),
		Vector2(TAIL_HALF_W, BUBBLE_BOTTOM - 1.0),
		Vector2(0.0, 0.0),
	])
	draw_colored_polygon(tail, FILL_COLOR)
	draw_line(Vector2(-TAIL_HALF_W, BUBBLE_BOTTOM - 1.0), Vector2(0.0, 0.0), INK_COLOR, 1.0)
	draw_line(Vector2(TAIL_HALF_W, BUBBLE_BOTTOM - 1.0), Vector2(0.0, 0.0), INK_COLOR, 1.0)
	draw_style_box(_style, body)
	var font: Font = _active_font()
	var color: Color = glyph_color(_glyph)
	var centre: Vector2 = body.get_center()
	if render_mode(_glyph, font) == "vector":
		if _glyph == "♥":
			_draw_heart(centre, color)
		elif _glyph == "♪":
			_draw_note(centre, color)
	else:
		var ascent: float = font.get_ascent(GLYPH_FONT_SIZE)
		var descent: float = font.get_descent(GLYPH_FONT_SIZE)
		var baseline: float = centre.y + (ascent - descent) * 0.5
		draw_string(font, Vector2(-BUBBLE_HALF_W, baseline), _glyph, HORIZONTAL_ALIGNMENT_CENTER, BUBBLE_HALF_W * 2.0, GLYPH_FONT_SIZE, color)


## A heart in two circles + a downward wedge, centred on c.
func _draw_heart(c: Vector2, color: Color) -> void:
	draw_circle(c + Vector2(-3.1, -1.6), 3.2, color)
	draw_circle(c + Vector2(3.1, -1.6), 3.2, color)
	var wedge: PackedVector2Array = PackedVector2Array([
		c + Vector2(-6.1, -1.2),
		c + Vector2(6.1, -1.2),
		c + Vector2(0.0, 5.6),
	])
	draw_colored_polygon(wedge, color)


## An eighth note: head, stem and flag, centred on c.
func _draw_note(c: Vector2, color: Color) -> void:
	draw_circle(c + Vector2(-2.4, 3.4), 2.7, color)
	var stem_top: Vector2 = c + Vector2(0.3, -5.6)
	var stem_bottom: Vector2 = c + Vector2(0.3, 3.4)
	draw_line(stem_bottom, stem_top, color, 1.6)
	var flag: PackedVector2Array = PackedVector2Array([
		stem_top,
		stem_top + Vector2(0.0, 3.0),
		stem_top + Vector2(4.0, 1.6),
	])
	draw_colored_polygon(flag, color)
