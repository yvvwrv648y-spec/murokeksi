class_name ProtagonistRegistry
extends RefCounted
## Authoritative selectable protagonist specifications for Riley (default) and Tasha.
## Preserves character locks in saves and battle trainer identity.

const DEFAULT_PROTAGONIST := "riley"

const PROFILES := {
	"riley": {
		"id": "riley",
		"display_name": "Riley",
		"canon_lock": "Adult petite/slim feminine; blonde tousled bob; green eyes; charcoal cropped tee with filled dusty-pink thorned heart; white frayed shorts; orange boots; black/pink Wifestress collar with gold detailing and cat bell; dusty-pink belt with 6 asymmetric anchored custom Poke Balls; no hat/earrings/animal ears/tail.",
		"custom_six_ball_belt": true,
		"art_approval_state": "PENDING_VISUAL_QA"
	},
	"tasha": {
		"id": "tasha",
		"display_name": "Tasha",
		"canon_lock": "Adult taller; long copper-orange wavy hair; blue eyes; black skull sweater dress; left-thigh strap; black boots; purple/black Riley collar with gold square padlock and key; no earrings; 6-ball belt unassigned unless supplied by owner.",
		"custom_six_ball_belt": false,
		"art_approval_state": "PENDING_VISUAL_QA"
	}
}

static func get_profile(protagonist_id: String) -> Dictionary:
	return PROFILES.get(protagonist_id, PROFILES[DEFAULT_PROTAGONIST]).duplicate(true)
