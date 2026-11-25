class_name ActorAnimationStateMachine
extends Node
## Section 12: Typed locomotion & action animation state machine with per-clip timing.

signal state_changed(old_state: int, new_state: int)

enum AnimState {
	IDLE, IDLE_VAR, WALK, RUN, TURN, TALK, INTERACT, INSPECT,
	THROW_BALL, CAPTURE_REACT, VICTORY, DEFEAT, DAMAGE, CLIMB, SWIM, SURF, RIDE, SIT
}

const CLIP_FPS: Dictionary = {
	AnimState.IDLE: 4.0, AnimState.IDLE_VAR: 5.0, AnimState.WALK: 7.5, AnimState.RUN: 11.0,
	AnimState.TURN: 10.0, AnimState.TALK: 6.0, AnimState.THROW_BALL: 12.0, AnimState.VICTORY: 8.0
}

var current_state: AnimState = AnimState.IDLE
var facing: String = "down"
var idle_clock: float = 0.0

func set_state(next_state: AnimState) -> void:
	if next_state == current_state:
		return
	var prev: AnimState = current_state
	current_state = next_state
	idle_clock = 0.0
	state_changed.emit(prev, next_state)

func step_locomotion(velocity: Vector2, is_running: bool, delta: float) -> String:
	if velocity.length() > 0.05:
		if absf(velocity.x) >= absf(velocity.y):
			facing = "right" if velocity.x > 0.0 else "left"
		else:
			facing = "down" if velocity.y > 0.0 else "up"
		set_state(AnimState.RUN if is_running else AnimState.WALK)
	else:
		idle_clock += delta
		set_state(AnimState.IDLE_VAR if idle_clock > 6.5 else AnimState.IDLE)
	return "%s_%s" % [AnimState.keys()[current_state].to_lower(), facing]
