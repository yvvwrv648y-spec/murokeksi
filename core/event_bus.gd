class_name PUWEventBus
extends Node
signal map_transition_requested(target_map_id: String, entry_pos: Vector3)
signal battle_started(encounter_context: Dictionary)
signal battle_finished(result: Dictionary)
signal badge_awarded(badge_id: String)
signal save_requested()
