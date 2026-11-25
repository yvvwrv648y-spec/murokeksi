class_name PUWQuestManager
extends Node
## Section 23: Data-driven Kanto campaign & side-quest state machine.

signal quest_updated(quest_id: String, state: String)

var quests: Dictionary = {
	"q_kanto_01_pallet_departure": {"title": "New Horizon in Pallet Town", "state": "ACTIVE", "step": 1},
	"q_kanto_02_pewter_gym": {"title": "Challenge Pewter Gym (Brock)", "state": "LOCKED", "step": 0},
	"q_kanto_03_mt_moon_rocket": {"title": "Shadows Beneath Mt. Moon", "state": "LOCKED", "step": 0},
	"q_kanto_04_silph_liberation": {"title": "Liberate Silph Co. HQ", "state": "LOCKED", "step": 0},
	"q_kanto_05_indigo_league": {"title": "Ascend Indigo Plateau", "state": "LOCKED", "step": 0}
}

func set_quest_state(quest_id: String, new_state: String) -> void:
	if not quests.has(quest_id):
		return
	quests[quest_id]["state"] = new_state
	quest_updated.emit(quest_id, new_state)
