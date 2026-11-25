class_name PUWGymAndTrainerManager
extends Node
## Section 13 & 23: Complete 8-Gym Kanto League progression + Team Rocket story milestones.

signal badge_earned(badge_id: String, leader_name: String)

const KANTO_GYMS: Array[Dictionary] = [
	{"badge_id": "boulder_badge", "city": "kanto_pewter_city", "leader": "Brock", "type": "rock", "ace": "onix", "level_cap": 14},
	{"badge_id": "cascade_badge", "city": "kanto_cerulean_city", "leader": "Misty", "type": "water", "ace": "starmie", "level_cap": 21},
	{"badge_id": "thunder_badge", "city": "kanto_vermilion_city", "leader": "Lt. Surge", "type": "electric", "ace": "raichu", "level_cap": 24},
	{"badge_id": "rainbow_badge", "city": "kanto_celadon_city", "leader": "Erika", "type": "grass", "ace": "vileplume", "level_cap": 29},
	{"badge_id": "soul_badge", "city": "kanto_fuchsia_city", "leader": "Koga", "type": "poison", "ace": "weezing", "level_cap": 43},
	{"badge_id": "marsh_badge", "city": "kanto_saffron_city", "leader": "Sabrina", "type": "psychic", "ace": "alakazam", "level_cap": 43},
	{"badge_id": "volcano_badge", "city": "kanto_cinnabar_island", "leader": "Blaine", "type": "fire", "ace": "arcanine", "level_cap": 47},
	{"badge_id": "earth_badge", "city": "kanto_viridian_city", "leader": "Giovanni", "type": "ground", "ace": "rhydon", "level_cap": 50}
]

var earned_badges: PackedStringArray = []

func award_badge(badge_id: String) -> bool:
	if badge_id in earned_badges:
		return false
	earned_badges.append(badge_id)
	for g in KANTO_GYMS:
		if str(g["badge_id"]) == badge_id:
			badge_earned.emit(badge_id, str(g["leader"]))
			break
	return true
