class_name PUWCreatorOptions
extends RefCounted
## Typed option catalogs for the character creator UI.
##
## WHY THIS EXISTS (audit 2026-11-24): the bound creator flow
## (systems/character/character_setup.gd) stores every step as a
## free-form String, and the bound schema
## (characters/protagonists/custom/character_creator_schema.json
## v2.0.0) declares typed options -- body sliders with ranges,
## a 7-tone skin palette, hairstyle ids -- that no bound code
## exposes as data a UI can bind to. This class is that data:
## transcribed from the schema where the schema speaks, and
## marked DESIGN CONSTANT where it does not (the same honesty
## rule PUWWardrobeShop uses for its prices).
##
## Sources:
## - SKIN_TONES, SLIDER_DEFS, HAIRSTYLES, EYEBROW_STYLES,
##   BEAUTY_MARKS, SCARS, MAKEUP: transcribed verbatim from
##   character_creator_schema.json v2.0.0 (bound).
## - BODY_PRESETS: PUWCastRegistry.BODY_PRESETS (bound).
## - HAIR_COLORS / EYE_COLORS: the schema names no color
##   palette (only "dual_tone_hair_tips": true), so these are
##   DESIGN CONSTANTS set for this catalog, labeled as such in
##   every entry's "basis" field. They are not sourced data.
## - SIGNATURE_BALLS: the creator's "signature_ball" step takes
##   a free-form String in the bound flow; these are the ball
##   ids the bound data already uses (standard ball items).

## Skin tones, verbatim from schema face_and_details.skin_tones.
const SKIN_TONES: Array = [
	"#fde7d6", "#f6cfa8", "#e5b283", "#c98e5b",
	"#9e6238", "#6d3f22", "#472716"
]

## Hairstyles, verbatim from schema face_and_details.hairstyles.
## The two locked signature styles (riley_tousled_bob,
## tasha_copper_waves) are NOT in the schema list and are never
## added here; PUWCharacterSetup.locked_hairstyles() is the
## authority the UI also filters against.
const HAIRSTYLES: Array = [
	"high_ponytail", "spiky_layered", "wolf_cut", "long_sleek",
	"undercut", "twin_braids", "curly_volume", "short_crop"
]

const EYEBROW_STYLES: Array = [
	"soft_arch", "sharp_angled", "thick_natural", "thin_curved"
]

const BEAUTY_MARKS: Array = [
	"none", "left_cheek", "right_cheek", "below_lip", "collarbone"
]

const SCARS: Array = [
	"none", "eyebrow_slash", "cheek_scar", "nose_bridge", "shoulder_scar"
]

const MAKEUP: Array = ["lipstick", "eyeshadow", "blush", "eyeliner"]

## Body presets, verbatim from PUWCastRegistry.BODY_PRESETS.
const BODY_PRESETS: Array = ["female", "male", "femboy", "futanari"]

## Slider definitions, transcribed from schema body_sliders
## plus height_cm from schema height_range_cm. Each entry:
## {id, min, max, default, step}. height is in whole cm; the
## 0.0-1.0 sliders are proportions the rigs consume.
const SLIDER_DEFS: Array = [
	{"id": "height_cm", "min": 145.0, "max": 208.0, "default": 168.0, "step": 1.0},
	{"id": "chest_size", "min": 0.0, "max": 1.0, "default": 0.45, "step": 0.01},
	{"id": "muscle_definition", "min": 0.0, "max": 1.0, "default": 0.3, "step": 0.01},
	{"id": "shoulder_width", "min": 0.0, "max": 1.0, "default": 0.5, "step": 0.01},
	{"id": "waist_width", "min": 0.0, "max": 1.0, "default": 0.45, "step": 0.01},
	{"id": "hip_width", "min": 0.0, "max": 1.0, "default": 0.55, "step": 0.01},
	{"id": "lower_front_contour", "min": 0.0, "max": 1.0, "default": 0.0, "step": 0.01},
]

## The identities for which the schema enables the
## lower_front_contour slider (schema body_sliders.
## lower_front_contour.enabled_identities, using the schema's
## lowercase ids; PUWCharacterSetup stores display-case
## identities, so callers compare case-insensitively).
const LOWER_FRONT_CONTOUR_IDENTITIES: Array = [
	"male", "femboy", "futanari", "custom",
	"nonbinary", "trans_man", "trans_woman"
]

## DESIGN CONSTANT hair colors (no palette exists in bound
## data). Natural set first, then dyed set; "basis" says so.
const HAIR_COLORS: Array = [
	{"id": "black", "hex": "#1c1410", "basis": "design_constant"},
	{"id": "dark_brown", "hex": "#3b2314", "basis": "design_constant"},
	{"id": "brown", "hex": "#6d4527", "basis": "design_constant"},
	{"id": "auburn", "hex": "#8a3b1e", "basis": "design_constant"},
	{"id": "copper", "hex": "#b5651d", "basis": "design_constant"},
	{"id": "blonde", "hex": "#d9a441", "basis": "design_constant"},
	{"id": "platinum", "hex": "#e8e0cc", "basis": "design_constant"},
	{"id": "silver", "hex": "#b9bec4", "basis": "design_constant"},
	{"id": "red", "hex": "#a8232a", "basis": "design_constant"},
	{"id": "pink", "hex": "#e58bb1", "basis": "design_constant"},
	{"id": "blue", "hex": "#2f5fb3", "basis": "design_constant"},
	{"id": "teal", "hex": "#1f8a80", "basis": "design_constant"},
	{"id": "purple", "hex": "#6d3fa0", "basis": "design_constant"},
	{"id": "green", "hex": "#3f7d3a", "basis": "design_constant"},
]

## DESIGN CONSTANT eye colors (same basis note as hair).
const EYE_COLORS: Array = [
	{"id": "brown", "hex": "#4a2c14", "basis": "design_constant"},
	{"id": "amber", "hex": "#b57a1e", "basis": "design_constant"},
	{"id": "hazel", "hex": "#7d6a35", "basis": "design_constant"},
	{"id": "green", "hex": "#2e7d46", "basis": "design_constant"},
	{"id": "blue", "hex": "#2563eb", "basis": "design_constant"},
	{"id": "gray", "hex": "#7a8288", "basis": "design_constant"},
	{"id": "violet", "hex": "#6d3fa0", "basis": "design_constant"},
	{"id": "red", "hex": "#a8232a", "basis": "design_constant"},
]

## Pronoun sets offered on the pronouns step. The bound flow
## stores the step as a free-form String; the UI writes the
## "id" and the profile extras carry the full set (the shape
## ProtagonistCanon.create_default_custom_profile uses).
const PRONOUN_SETS: Array = [
	{"id": "she/her", "subject": "she", "object": "her", "possessive": "her"},
	{"id": "he/him", "subject": "he", "object": "him", "possessive": "his"},
	{"id": "they/them", "subject": "they", "object": "them", "possessive": "their"},
]

## Signature ball choices for the final step (standard balls;
## the step value stored is the ball id String).
const SIGNATURE_BALLS: Array = [
	"poke_ball", "great_ball", "ultra_ball", "premier_ball",
	"luxury_ball", "cherish_ball"
]


## The slider definitions as dictionaries a UI can bind to.
static func slider_defs() -> Array:
	return SLIDER_DEFS.duplicate(true)


## The default slider values, keyed by slider id.
static func default_slider_values() -> Dictionary:
	var values: Dictionary = {}
	for def_value in SLIDER_DEFS:
		var def: Dictionary = def_value
		values[str(def.get("id", ""))] = float(def.get("default", 0.0))
	return values


## True when the lower_front_contour slider applies to an
## identity stored by the bound flow (display case) -- compared
## case-insensitively against the schema's lowercase list.
static func lower_front_contour_enabled(identity_display: String) -> bool:
	return LOWER_FRONT_CONTOUR_IDENTITIES.has(identity_display.to_lower())


## The hex for a hair/eye color id, or "" when unknown.
static func color_hex(catalog: Array, color_id: String) -> String:
	for entry_value in catalog:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == color_id:
			return str(entry.get("hex", ""))
	return ""


## The pronoun set Dictionary for an id, or the they/them set.
static func pronoun_set(pronoun_id: String) -> Dictionary:
	for entry_value in PRONOUN_SETS:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == pronoun_id:
			return entry.duplicate(true)
	return {"id": "they/them", "subject": "they", "object": "them", "possessive": "their"}
