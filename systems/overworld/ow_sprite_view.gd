class_name PUWOWSpriteView
extends AnimatedSprite2D
## One overworld actor's on-screen sprite (code prep,
## 2026-11-24): an AnimatedSprite2D that plays the overworld
## state machine's clips -- "<state>_<facing>" built by
## PUWOWAnimator -- and keeps playing them as the actor's state
## and facing change.
##
## Fallback order in play_ow() is deliberate and honest:
## "<state>_<facing>", then the bare "<state>", then
## "idle_<facing>", then "idle". A clip that was never built
## (a direction row the sheet does not carry) is never replaced
## by a mirrored or borrowed clip; the actor simply keeps the
## closest real clip, and current_clip() reports what is
## actually on screen.

var ow_state: String = "idle"
var ow_facing: String = "down"


## Install the SpriteFrames built for this actor.
func set_ow_frames(frames: SpriteFrames) -> void:
	sprite_frames = frames
	play_ow(ow_state, ow_facing)


## Play the clip for a locomotion state + facing. States are
## the overworld set: idle / walk / run (charset actors), plus
## whatever extra clips the installed frames carry (the player
## controller's own swim / bike clips use the same convention).
func play_ow(state: String, facing: String) -> void:
	ow_state = state
	ow_facing = facing
	if sprite_frames == null:
		return
	var candidates: Array = []
	# Idle bob (fold-in round, PATCHES P4): where a caller
	# plays idle, the two-frame bob clip built by
	# PUWOWAnimator wins when it exists; sheets without one
	# fall through to the plain idle candidates unchanged.
	if state == "idle":
		candidates.append("idle_bob_%s" % facing)
		candidates.append("idle_bob")
	candidates.append("%s_%s" % [state, facing])
	candidates.append(state)
	candidates.append("idle_%s" % facing)
	candidates.append("idle")
	for cand_value in candidates:
		var cand: String = str(cand_value)
		if sprite_frames.has_animation(cand) and sprite_frames.get_frame_count(cand) > 0:
			if animation != cand or not is_playing():
				play(cand)
			return


## The clip actually playing ("" when nothing is).
func current_clip() -> String:
	return animation


## The frame index currently shown within the playing clip.
func current_frame_index() -> int:
	return frame
