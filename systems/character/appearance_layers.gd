class_name PUWAppearanceLayers
extends RefCounted
## Resolves a built character Dictionary into the render spec
## the shipping 2D layered renderer consumes (staged
## 2026-11-24).
##
## THE GAP THIS CLOSES (audit 2026-11-24): in the bound tree,
## creator choices beyond the cast preset never reach the 2D
## renderer -- PUWCastRigLoader builds SpriteFrames per
## (cast, state) from fixed sliced frames, and nothing in the
## bound code applies skin tone, hair color, or height. The 3D
## ModularCharacterRig applies sliders to a Node3D model the
## shipping 2D game does not use. This resolver is the bridge
## the 2D path was missing: it turns the profile into concrete,
## honest render parameters using only mechanisms the 2D
## engine really has --
##
## - base body / outfit / hair are LAYERS (the layered walk
##   pilot's body + outfit sheets under characters/layered/);
## - skin tone and hair color apply as layer MODULATE colors
##   (CanvasItem modulate -- a tint, not new art);
## - height applies as a uniform sprite SCALE using the same
##   ratio rule as ModularCharacterRig (height_m / 1.68,
##   clamped to the schema's 1.45-2.08 m range);
## - the outfit is the wardrobe catalog id the profile wears
##   (PUWWardrobeShop owns buy/wear; this only reads).
##
## HONEST LIMITS (named, not papered over): per-hairstyle hair
## LAYER ART does not exist in the bound tree for custom
## profiles -- the only hair-bearing sheets are the cast
## signature sheets. resolve() therefore returns the hair
## layer as "signature" (the cast's own hair) plus the chosen
## color as its modulate, and flags "hair_art" in the result's
## "gaps" list until per-style hair layers are produced. Body
## sliders other than height have no 2D mechanism (they are
## blend shapes on the 3D rig); they are carried in the
## profile and reported in "gaps" as "body_sliders_2d" rather
## than silently dropped.

const MIN_HEIGHT_M: float = 1.45
const MAX_HEIGHT_M: float = 2.08
const REFERENCE_HEIGHT_M: float = 1.68
const DEFAULT_SKIN_TONE: String = "#f6cfa8"


## Resolve a character Dictionary (PUWCharacterSetup output,
## with the creator screen's extras) into a render spec:
## {cast_id, skin_modulate, hair_layer, hair_modulate,
##  height_scale, outfit_id, gaps}.
static func resolve(character: Dictionary) -> Dictionary:
	var gaps: Array = []
	var cast_id: String = str(character.get("cast_id", "custom_female"))

	# Skin tone: the schema hex rides on the profile as an
	# extra; fall back to the canon default profile's tone.
	var skin_hex: String = str(character.get("skin_tone", DEFAULT_SKIN_TONE))
	var skin_modulate: Color = Color.html(skin_hex) if skin_hex.begins_with("#") else Color.WHITE

	# Hair: chosen color tints the cast's signature hair layer;
	# per-style hair art is the named gap.
	var hair_hex: String = str(character.get("hair_color_hex", ""))
	var hair_modulate: Color = Color.html(hair_hex) if hair_hex.begins_with("#") else Color.WHITE
	gaps.append("hair_art")

	# Height: from the slider extras when present, else the
	# canon default profile height (1.65 m).
	var height_cm: float = 165.0
	var sliders_value: Variant = character.get("body_sliders", {})
	if sliders_value is Dictionary:
		var sliders: Dictionary = sliders_value
		height_cm = float(sliders.get("height_cm", 165.0))
		gaps.append("body_sliders_2d")
	var height_m: float = clampf(height_cm / 100.0, MIN_HEIGHT_M, MAX_HEIGHT_M)
	var height_scale: float = height_m / REFERENCE_HEIGHT_M

	# Outfit: the wardrobe profile field when set, else the
	# cast's signature outfit (owned by default per
	# PUWWardrobeShop).
	var outfit_id: String = str(character.get("current_outfit", ""))
	if outfit_id == "":
		outfit_id = cast_id + "_signature"

	return {
		"cast_id": cast_id,
		"skin_modulate": skin_modulate,
		"hair_layer": "signature",
		"hair_modulate": hair_modulate,
		"height_scale": height_scale,
		"outfit_id": outfit_id,
		"gaps": gaps,
	}


## Apply a resolved spec to a layered player node: any child
## CanvasItem named "BodyLayer" takes the skin modulate,
## "HairLayer" the hair modulate, and the node itself takes
## the height scale. Missing layers are skipped, never
## fabricated. Returns the list of layer names applied.
static func apply_to_node(spec: Dictionary, player_node: Node2D) -> Array:
	var applied: Array = []
	if player_node == null:
		return applied
	var scale_factor: float = float(spec.get("height_scale", 1.0))
	player_node.scale = Vector2.ONE * scale_factor
	applied.append("height_scale")
	var body_layer: Node = player_node.get_node_or_null("BodyLayer")
	if body_layer is CanvasItem:
		var body_item: CanvasItem = body_layer
		body_item.modulate = spec.get("skin_modulate", Color.WHITE)
		applied.append("BodyLayer")
	var hair_layer: Node = player_node.get_node_or_null("HairLayer")
	if hair_layer is CanvasItem:
		var hair_item: CanvasItem = hair_layer
		hair_item.modulate = spec.get("hair_modulate", Color.WHITE)
		applied.append("HairLayer")
	return applied
