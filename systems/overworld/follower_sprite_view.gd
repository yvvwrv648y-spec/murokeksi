class_name PUWFollowerSpriteView
extends PUWOWSpriteView
## Follower overworld sprite (code prep, 2026-11-24).
##
## PUWFollowerController.behavior_tick() already computes, per
## follower and per tick, a position and an animation NAME
## (idle / walk / fly / fly_idle / hover / hover_idle / swim /
## shore_idle / perch_idle) -- but no node in the project draws
## a follower. This view is that node: it is fed one behavior
## record per tick through apply_behavior() and plays the
## matching clip from the follower's own bound sheet.
##
## Sheets, by the source the follower resolved through
## PUWFollowerSpriteResolver (local files only -- the PMD
## SpriteCollab rows are streamed URLs with no local sheet, so
## they cannot be installed here; see PREP_REPORT.md gaps):
## - EBDX / Willow / swim / levitate charsets and MDX walk
##   atlases: 4 cols x 4 rows, rows down / left / right / up
##   (setup_charset).
## - HGSS per-frame files: 2 step frames per direction
##   (setup_frame_files).
##
## Behavior-name mapping (playback of the sheet's OWN frames;
## no frame is invented): walk / fly / hover / swim all play
## the walk row for the current facing (a charset carries one
## locomotion cycle; the behavior layer already supplies the
## airborne visual_offset_y that sells flight), and every
## *_idle name plus shore_idle / perch_idle plays the idle row.
##
## OVERWORLD-LIFE PATCH (2026-11-24, on top of the file
## above; base SHA-256 d2eb8c5b... recorded in
## OVERWORLD_LIFE_REPORT.md): the behavior record ALSO
## carries an "emote" glyph -- produced only by genuine
## events through PUWFollowerController.show_emote() and
## aged out by the controller's own emote_ttl -- but no
## view rendered it. apply_behavior() now feeds the glyph
## to a PUWEmoteBubbleView child (emote_bubble), anchored
## above this sprite's head. The record's glyph going ""
## (TTL expiry) hides the bubble; nothing here invents an
## emote or extends its life.

const CHARSET_COLS: int = 4
const CHARSET_ROWS: int = 4

var sheet_status: String = ""

## The emote bubble over this follower (created in _init;
## hidden until a behavior record carries a glyph).
var emote_bubble: PUWEmoteBubbleView = null


func _init() -> void:
	emote_bubble = PUWEmoteBubbleView.new()
	emote_bubble.name = "EmoteBubble"
	add_child(emote_bubble)


## Install a 4x4 charset / walk-atlas texture.
func setup_charset(tex: Texture2D) -> bool:
	if tex == null:
		sheet_status = "no_sheet"
		return false
	set_ow_frames(PUWOWAnimator.charset_frames(tex, CHARSET_COLS, CHARSET_ROWS))
	sheet_status = "loaded"
	return true


## Install per-direction frame texture lists (HGSS files).
func setup_frame_files(frames_by_dir: Dictionary) -> bool:
	var frames: SpriteFrames = PUWOWAnimator.frame_list_frames(frames_by_dir)
	if frames.get_animation_names().is_empty():
		sheet_status = "no_sheet"
		return false
	set_ow_frames(frames)
	sheet_status = "loaded"
	return true


## Apply one behavior_tick record: position (plus the record's
## visual_offset_y) and the clip for its animation name.
## trainer_facing is the fallback facing when the record
## carries no facing_dir of its own.
func apply_behavior(record: Dictionary, trainer_facing: String = "down") -> void:
	var pos_value: Variant = record.get("pos", Vector2.ZERO)
	if pos_value is Vector2:
		var pos: Vector2 = pos_value
		position = pos + Vector2(0.0, float(record.get("visual_offset_y", 0.0)))
	var facing: String = _facing_for(record, trainer_facing)
	var anim_name: String = str(record.get("animation", "idle"))
	play_ow(_state_for(anim_name), facing)
	_apply_emote(str(record.get("emote", "")))


## Show the record's emote glyph in the bubble (anchored
## above the current frame's head), or hide the bubble
## when the record carries none. Re-applying the glyph
## already up is a no-op inside the bubble, so the
## per-tick feed never restarts its pop-in.
func _apply_emote(glyph: String) -> void:
	if emote_bubble == null:
		return
	if glyph == "":
		emote_bubble.clear()
		return
	emote_bubble.position = Vector2(0.0, PUWEmoteBubbleView.anchor_y_for(self))
	emote_bubble.show_glyph(glyph)


## The overworld clip state for a behavior animation name.
static func _state_for(anim_name: String) -> String:
	match anim_name:
		"walk", "fly", "hover", "swim":
			return "walk"
		_:
			return "idle"


## Facing from the record's facing_dir when it points
## somewhere, else the trainer's facing, else the view's own.
func _facing_for(record: Dictionary, trainer_facing: String) -> String:
	var dir_value: Variant = record.get("facing_dir", Vector2.ZERO)
	if dir_value is Vector2:
		var dir_vec: Vector2 = dir_value
		if dir_vec.length() > 0.01:
			if absf(dir_vec.x) >= absf(dir_vec.y):
				return "right" if dir_vec.x > 0.0 else "left"
			return "down" if dir_vec.y > 0.0 else "up"
	if trainer_facing == "up" or trainer_facing == "down" or trainer_facing == "left" or trainer_facing == "right":
		return trainer_facing
	return ow_facing
