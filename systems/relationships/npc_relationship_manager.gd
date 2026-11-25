class_name NpcRelationshipManager
extends Node
## Tracks Riley & Tasha bond, Co-Op Tandem pose eligibility, Rival 6-encounter cadence,
## and the 3 static side-by-side Town Supply Trainers (Kira, Haruka, Vance).

var riley_tasha_bond: int = 100
var riley_rival_wins: int = 0
var tasha_rival_wins: int = 0

func get_tandem_pose(driver: String, passenger: String, is_online_coop: bool) -> String:
	if not is_online_coop:
		return "BLOCKED_OFFLINE"
	if driver == "tasha" and passenger == "riley":
		return "riley_cuddles_tasha_close"
	if driver == "riley" and passenger == "tasha":
		return "tasha_holds_riley_close"
	if passenger == "riley":
		match driver:
			"custom_futanari": return "riley_wraps_arms_leans_in"
			"custom_male": return "riley_hands_on_shoulders"
			"custom_femboy": return "riley_hands_on_waist"
			_: return "riley_standard_hold"
	if passenger == "tasha":
		match driver:
			"custom_male": return "tasha_grip_bars_close"
			"custom_female": return "tasha_arms_around_waist"
			"custom_femboy": return "tasha_leans_in_waist_and_stomach"
			_: return "tasha_standard_hold"
	return "custom_basic_grip_bars"
