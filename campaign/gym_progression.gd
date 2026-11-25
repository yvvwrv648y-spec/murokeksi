class_name GymProgression
extends RefCounted
## Badge storage and progression gates for Pokemon Ultimate World.
##
## Badge ids and field-move gating come from data files supplied by
## the caller (the gym data file ships with the trainer data). This
## script holds the rules only: no badge names are hardcoded here.

const BADGES_FOR_ELITE_FOUR: int = 8


static func badge_count(state: Dictionary) -> int:
	var badges: Array = state.get("badges", [])
	return badges.size()


static func has_badge(state: Dictionary, badge_id: String) -> bool:
	var badges: Array = state.get("badges", [])
	return badges.has(badge_id)


## Award a badge. Returns false if the player already has it.
static func award_badge(state: Dictionary, badge_id: String) -> bool:
	if badge_id == "":
		return false
	var badges: Array = state.get("badges", [])
	if badges.has(badge_id):
		return false
	badges.append(badge_id)
	state["badges"] = badges
	return true


## The Elite Four gate: the player needs all 8 badges.
static func can_challenge_elite_four(state: Dictionary) -> bool:
	return badge_count(state) >= BADGES_FOR_ELITE_FOUR


## Field-move (HM) gating as data: gating maps a move id to the badge
## id it requires, e.g. {"surf": "cascade_badge"}. A move with no
## entry in the table is not badge-gated.
static func can_use_field_move(state: Dictionary, move_id: String, gating: Dictionary) -> bool:
	if not gating.has(move_id):
		return true
	return has_badge(state, str(gating[move_id]))
