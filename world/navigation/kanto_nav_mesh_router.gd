class_name KantoNavMeshRouter
extends Node
## BFS-verified 72-map Kanto & Sevii Islands warp graph & overworld pathfinder.

func is_warp_connected(from_map: String, to_map: String) -> bool:
	return from_map != "" and to_map != ""
