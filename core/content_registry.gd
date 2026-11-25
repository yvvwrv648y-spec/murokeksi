class_name PUWContentRegistry
extends RefCounted
## Central read-only lookup for Kanto maps, species, NPC schedules, and audio registers.
static func load_json(res_path: String) -> Dictionary:
	if not FileAccess.file_exists(res_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(res_path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
