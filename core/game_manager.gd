class_name PUWGameManager
extends Node
## Top-level game orchestration; enforces Kanto Omni Bracelet lock (Section 18).
var active_region: String = "kanto"
var active_map_id: String = "kanto_pallet_town"
var protagonist_id: String = "riley"
var omni_bracelet_unlocked: bool = false

func can_activate_omni_bracelet() -> bool:
	return active_region != "kanto" and omni_bracelet_unlocked
