class_name CameraQAHarness
extends Node3D
## Addendum Section 3 & 13B: Controlled Godot 4.7.2 Camera & Character Presentation QA Harness.
## Cycles Orthographic, Perspective, and Low-FOV Perspective across 32-45 deg pitch with real ground shadows.

enum CameraPreset { ORTHO_38, PERSP_STANDARD_40, PERSP_LOW_FOV_36 }

var active_preset: CameraPreset = CameraPreset.PERSP_LOW_FOV_36
var camera: Camera3D
var pitch_deg: float = -36.0
var focus_point: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_apply_preset(active_preset)

func _apply_preset(preset: CameraPreset) -> void:
	active_preset = preset
	match preset:
		CameraPreset.ORTHO_38:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 13.5
			pitch_deg = -38.0
		CameraPreset.PERSP_STANDARD_40:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 45.0
			pitch_deg = -40.0
		CameraPreset.PERSP_LOW_FOV_36:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 26.0
			pitch_deg = -36.0
	_update_camera_transform()

func _update_camera_transform() -> void:
	var dist: float = 24.0 if active_preset == CameraPreset.PERSP_LOW_FOV_36 else 16.0
	var rad: float = deg_to_rad(absf(pitch_deg))
	camera.position = focus_point + Vector3(0.0, sin(rad) * dist, cos(rad) * dist)
	camera.look_at(focus_point + Vector3(0.0, 0.85, 0.0), Vector3.UP)
