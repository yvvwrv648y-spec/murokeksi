class_name PUWRigStage
extends Node2D
## PUW engine-rigging stage: builds the part sprites for one
## rigged still and plays a rig definition's tracks on them.
##
## Given a Texture2D (the streamed/cached indexed still — the
## caller streams it through PUWSpriteLoader exactly like every
## other sprite) and a rig definition, the stage cuts one
## AtlasTexture region per part, mounts each region on a pivot
## Node2D sitting at the part's anchor, and on every frame
## applies PUWRigPlayer.sample() for the active track. Wing
## parts rotate around their inner anchor (flap), body segments
## slide laterally (undulation), limbs stride, bodies breathe —
## real per-part motion of the real still, labeled
## "engine-rigged" by the resolvers that hand out the
## definition. No art is drawn or invented here.

var _definition: Dictionary = {}
var _pivots: Dictionary = {}  # part_name -> Node2D pivot
var _track: String = PUWRigPlayer.TRACK_IDLE
var _time: float = 0.0
var _playing: bool = false


## Build (or rebuild) the stage from a still texture + rig
## definition. Returns false when either is unusable.
func build(texture: Texture2D, definition: Dictionary) -> bool:
	clear()
	if texture == null or definition.is_empty():
		return false
	var parts_value: Variant = definition.get("parts", {})
	if not (parts_value is Dictionary):
		return false
	var parts: Dictionary = parts_value
	var tex_size: Vector2 = Vector2(texture.get_width(), texture.get_height())
	for part_name_value in parts:
		var part_name: String = str(part_name_value)
		var part_value: Variant = parts[part_name]
		if not (part_value is Dictionary):
			continue
		var part_def: Dictionary = part_value
		var region_value: Variant = part_def.get("region", [])
		var anchor_value: Variant = part_def.get("anchor", [0.5, 0.5])
		if not (region_value is Array) or not (anchor_value is Array):
			continue
		var region_arr: Array = region_value
		var anchor_arr: Array = anchor_value
		if region_arr.size() != 4 or anchor_arr.size() != 2:
			continue
		var rect: Rect2 = Rect2(
			float(region_arr[0]) * tex_size.x, float(region_arr[1]) * tex_size.y,
			float(region_arr[2]) * tex_size.x, float(region_arr[3]) * tex_size.y)
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		var pivot: Node2D = Node2D.new()
		# Pivot sits at the anchor point, in stage space where the
		# still's top-left is (-w/2, -h/2) (centered presentation).
		var anchor_px: Vector2 = Vector2(
			rect.position.x + float(anchor_arr[0]) * rect.size.x,
			rect.position.y + float(anchor_arr[1]) * rect.size.y)
		pivot.position = anchor_px - tex_size * 0.5
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = atlas
		sprite.centered = true
		# Sprite center must sit on the region's center relative
		# to the pivot (anchor).
		sprite.position = (rect.position + rect.size * 0.5) - anchor_px
		pivot.add_child(sprite)
		add_child(pivot)
		_pivots[part_name] = pivot
		_pivot_bases[part_name] = pivot.position
	_definition = definition
	_time = 0.0
	_playing = true
	apply_sample(PUWRigPlayer.sample(_definition, _track, 0.0), tex_size)
	return not _pivots.is_empty()


func clear() -> void:
	for child in get_children():
		child.queue_free()
	_pivots.clear()
	_pivot_bases.clear()
	_definition = {}
	_playing = false


## Switch the active track ("idle" / "movement").
func set_track(track_name: String) -> void:
	_track = track_name


func active_track() -> String:
	return _track


## Apply one sampled pose. Offsets are fractions of the still
## size; rotations are degrees around each part's anchor.
func apply_sample(sampled: Dictionary, tex_size: Vector2) -> void:
	for part_name_value in _pivots:
		var part_name: String = str(part_name_value)
		var pivot: Node2D = _pivots[part_name]
		var entry_value: Variant = sampled.get(part_name, {})
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var base_pos: Vector2 = _pivot_bases.get(part_name, Vector2.ZERO)
		var offset: Vector2 = entry.get("offset", Vector2.ZERO)
		pivot.position = base_pos + Vector2(offset.x * tex_size.x, offset.y * tex_size.y)
		pivot.rotation_degrees = float(entry.get("rotation_deg", 0.0))
		var part_scale: Vector2 = entry.get("scale", Vector2.ONE)
		pivot.scale = part_scale


var _pivot_bases: Dictionary = {}

func _process(delta: float) -> void:
	if not _playing or _definition.is_empty():
		return
	_time += delta
	# Texture size from the first part sprite's atlas.
	var tex_size: Vector2 = Vector2(96.0, 96.0)
	for part_name_value in _pivots:
		var part_name: String = str(part_name_value)
		var pivot: Node2D = _pivots[part_name]
		if pivot.get_child_count() > 0:
			var sprite: Sprite2D = pivot.get_child(0)
			if sprite.texture is AtlasTexture:
				var atlas: AtlasTexture = sprite.texture
				if atlas.atlas != null:
					tex_size = Vector2(atlas.atlas.get_width(), atlas.atlas.get_height())
		break
	apply_sample(PUWRigPlayer.sample(_definition, _track, _time), tex_size)
