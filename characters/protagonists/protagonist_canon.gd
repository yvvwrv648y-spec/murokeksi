class_name ProtagonistCanon
extends RefCounted
## Authoritative Section 6 & 7 Protagonist Canon + Character Creator Contracts.
## Updates v0.3.1 registry to enforce Tasha's Klefki-inspired charm and 6-ball hip rigs for BOTH Riley & Tasha.

const IDENTITY_OPTIONS: PackedStringArray = [
	"male", "female", "nonbinary", "trans_man", "trans_woman",
	"femboy", "futanari", "custom", "prefer_not_to_specify"
]

const CLOTHING_SLOTS: PackedStringArray = [
	"top", "outerwear", "dress", "bottom", "swimwear", "underwear",
	"socks", "footwear", "belt", "collar", "jewellery", "hat", "hair_accessory"
]

const RILEY_SIX_BALL_RIG: Array[Dictionary] = [
	{"anchor": "hip_left_1", "side": "left", "slot": 1, "ball_id": "riley_signature_ball", "is_signature": true},
	{"anchor": "hip_left_2", "side": "left", "slot": 2, "ball_id": "riley_custom_ball_2", "is_signature": false},
	{"anchor": "hip_left_3", "side": "left", "slot": 3, "ball_id": "riley_custom_ball_3", "is_signature": false},
	{"anchor": "hip_right_1", "side": "right", "slot": 4, "ball_id": "riley_custom_ball_4", "is_signature": false},
	{"anchor": "hip_right_2", "side": "right", "slot": 5, "ball_id": "riley_custom_ball_5", "is_signature": false},
	{"anchor": "hip_right_3", "side": "right", "slot": 6, "ball_id": "riley_custom_ball_6", "is_signature": false}
]

const TASHA_SIX_BALL_RIG: Array[Dictionary] = [
	{"anchor": "hip_left_1", "side": "left", "slot": 1, "ball_id": "tasha_signature_ball", "is_signature": true},
	{"anchor": "hip_left_2", "side": "left", "slot": 2, "ball_id": "tasha_custom_ball_2", "is_signature": false},
	{"anchor": "hip_left_3", "side": "left", "slot": 3, "ball_id": "tasha_custom_ball_3", "is_signature": false},
	{"anchor": "hip_right_1", "side": "right", "slot": 4, "ball_id": "tasha_custom_ball_4", "is_signature": false},
	{"anchor": "hip_right_2", "side": "right", "slot": 5, "ball_id": "tasha_custom_ball_5", "is_signature": false},
	{"anchor": "hip_right_3", "side": "right", "slot": 6, "ball_id": "tasha_custom_ball_6", "is_signature": false}
]

static func get_preset(preset_id: String) -> Dictionary:
	if preset_id == "tasha":
		return {
			"id": "tasha",
			"display_name": "Tasha",
			"adult_presenting": true,
			"relative_height_m": 1.72,
			"hair": "long copper-orange wavy",
			"eyes": "blue",
			"default_outfit": "black skull sweater-dress, left-thigh strap, black boots",
			"collar": "purple/black collar with gold detailing",
			"collar_charm": "custom Klefki-inspired keyring Pokemon charm",
			"home_location_id": "kanto_pallet_tasha_house",
			"six_ball_rig": TASHA_SIX_BALL_RIG.duplicate(true),
			"art_status": "ASSET_CANDIDATE"
		}
	return {
		"id": "riley",
		"display_name": "Riley",
		"adult_presenting": true,
		"relative_height_m": 1.56,
		"hair": "blonde tousled bob",
		"eyes": "green",
		"default_outfit": "charcoal cropped shirt with dusty-pink thorned-heart, white frayed shorts, orange boots",
		"collar": "black-and-pink Wifestress collar with gold detailing",
		"collar_charm": "custom Meowth-inspired cat-bell trinket",
		"home_location_id": "kanto_pallet_riley_house",
		"six_ball_rig": RILEY_SIX_BALL_RIG.duplicate(true),
		"art_status": "ASSET_CANDIDATE"
	}

static func create_default_custom_profile(display_name: String) -> Dictionary:
	return {
		"id": "custom",
		"display_name": display_name,
		"adult_presenting": true,
		"identity": "prefer_not_to_specify",
		"pronouns": {"subject": "they", "object": "them", "possessive": "their"},
		"body": {"silhouette": "balanced", "height_m": 1.65, "build": 0.5, "shoulders": 0.5, "waist": 0.5, "hips": 0.5, "chest": 0.5},
		"appearance": {"skin_hex": "#f6c9a0", "hair_style": "medium", "hair_hex": "#3b2314", "eye_left_hex": "#2563eb", "eye_right_hex": "#2563eb", "heterochromia": false},
		"clothing": {"top": "jacket_01", "bottom": "trousers_01", "footwear": "boots_01", "belt": "belt_six_ball"},
		"home_location_id": "kanto_pallet_custom_house",
		"six_ball_rig": RILEY_SIX_BALL_RIG.duplicate(true)
	}
