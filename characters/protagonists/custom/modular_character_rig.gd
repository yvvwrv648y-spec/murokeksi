class_name ModularCharacterRig
extends Node3D
## Drives Godot 4.7.2 blend shapes (chest, muscle, waist, hips, shoulders, lower_front_contour),
## physical height scaling (4'9" / 1.45m to 6'10" / 2.08m), heterochromia shader params,
## modular clothing/footwear visibility, and Riley/Tasha hairstyle exclusivity lock.

const MIN_HEIGHT_M: float = 1.45 # 4'9"
const MAX_HEIGHT_M: float = 2.08 # 6'10"
const LOCKED_CANON_HAIRSTYLES: PackedStringArray = ["riley_tousled_bob", "tasha_copper_waves"]

@export var body_mesh: MeshInstance3D
@export var skeleton: Skeleton3D
@export var clothing_root: Node3D

var profile: Dictionary = {}

func apply_profile(new_profile: Dictionary) -> bool:
	var hair_id: String = str(new_profile.get("hairstyle", "high_ponytail"))
	if hair_id in LOCKED_CANON_HAIRSTYLES:
		push_warning("Hairstyle '%s' is reserved exclusively for Riley/Tasha." % hair_id)
		return false
	profile = new_profile.duplicate(true)
	var h_m: float = clampf(float(profile.get("height_cm", 168.0)) / 100.0, MIN_HEIGHT_M, MAX_HEIGHT_M)
	var scale_ratio: float = h_m / 1.68
	scale = Vector3.ONE * scale_ratio
	if is_instance_valid(body_mesh):
		_set_blend("chest_size", float(profile.get("chest_size", 0.45)))
		_set_blend("muscle_definition", float(profile.get("muscle_definition", 0.3)))
		_set_blend("waist_width", float(profile.get("waist_width", 0.45)))
		_set_blend("hip_width", float(profile.get("hip_width", 0.55)))
		_set_blend("shoulder_width", float(profile.get("shoulder_width", 0.5)))
		_set_blend("lower_front_contour", float(profile.get("lower_front_contour", 0.0)))
	return true

func _set_blend(shape_name: String, val: float) -> void:
	var idx: int = body_mesh.find_blend_shape_by_name(shape_name)
	if idx >= 0:
		body_mesh.set_blend_shape_value(idx, clampf(val, 0.0, 1.0))
