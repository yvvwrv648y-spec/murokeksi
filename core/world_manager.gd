class_name PUWWorldManager
extends Node
var active_map_id: String = "kanto_pallet_town"
var resident_maps: PackedStringArray = []

func load_region_map(map_id: String) -> String:
	active_map_id = map_id
	return "res://world/regions/kanto/maps/%s.json" % map_id
