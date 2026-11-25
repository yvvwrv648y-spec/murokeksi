class_name FollowerController
extends Node3D
## Production-fixed FollowerController (fixes Y-axis float/sink, wall-clipping via optional NavigationAgent3D,
## low-FPS overshoot jitter, and map-change snap distance).

@export var follow_distance: float = 1.5
@export var catchup_distance: float = 5.0
@export var snap_distance: float = 18.0
@export var movement_speed: float = 3.5
@export var rotation_speed: float = 8.0
@export var hover_altitude: float = 0.0 # >0.0 for flying avian followers
@export var nav_agent: NavigationAgent3D

var target: Node3D
var navigation_target: Vector3
var is_following: bool = true

func set_follow_target(new_target: Node3D) -> void:
	target = new_target

func set_following(enabled: bool) -> void:
	is_following = enabled

func _physics_process(delta: float) -> void:
	if not is_following or not is_instance_valid(target):
		return

	var desired_position: Vector3 = target.global_position
	var delta_xz: Vector3 = Vector3(desired_position.x - global_position.x, 0.0, desired_position.z - global_position.z)
	var horiz_dist: float = delta_xz.length()

	# Fix 4: Snap cleanly on map transitions instead of walking across the void
	if horiz_dist > snap_distance:
		global_position = Vector3(desired_position.x, desired_position.y + hover_altitude, desired_position.z + follow_distance)
		return

	if horiz_dist <= follow_distance:
		return

	# Fix 2: Use NavigationAgent3D pathing when attached so followers avoid walls & furniture
	var move_goal: Vector3 = desired_position
	if is_instance_valid(nav_agent):
		nav_agent.target_position = desired_position
		move_goal = nav_agent.get_next_path_position()

	# Fix 1: Lock horizontal locomotion to XZ plane (prevents ground followers floating/sinking)
	var step_vec: Vector3 = Vector3(move_goal.x - global_position.x, 0.0, move_goal.z - global_position.z)
	if step_vec.length_squared() < 0.0001:
		return
	var direction: Vector3 = step_vec.normalized()

	var speed: float = movement_speed * (1.35 if horiz_dist > catchup_distance else 1.0)
	# Fix 3: Clamp step length so follower never overshoots follow_distance and jitters
	var step_len: float = minf(speed * delta, maxf(0.0, horiz_dist - follow_distance))
	global_position.x += direction.x * step_len
	global_position.z += direction.z * step_len
	global_position.y = lerpf(global_position.y, desired_position.y + hover_altitude, clampf(delta * 10.0, 0.0, 1.0))

	var desired_rotation: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired_rotation, clampf(rotation_speed * delta, 0.0, 1.0))
