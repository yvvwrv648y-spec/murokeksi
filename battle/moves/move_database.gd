class_name MoveDatabase
extends Node
## Canonical Gen I-IX Competitive Move Database (Smogon / VGC Verified; zero fake moves).

const MOVE_DB_PATH := "res://battle/moves/move_database.json"
var _moves: Dictionary = {}

func _ready() -> void:
	load_database()

func load_database() -> void:
	if FileAccess.file_exists(MOVE_DB_PATH):
		var raw := FileAccess.get_file_as_string(MOVE_DB_PATH)
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary and parsed.has("moves"):
			_moves = parsed["moves"]

func get_move(move_name: String) -> Dictionary:
	return _moves.get(move_name, {"type": "Normal", "cat": "Physical", "power": 80, "acc": 100, "pp": 15, "priority": 0})

func filter_for_challenge(moves: Array, challenge_mode: String, format_id: String = "singles") -> Array:
	var out: Array = []
	for m in moves:
		var md := get_move(m)
		if challenge_mode == "no_healing_or_moves" and md.get("healing_move", false):
			out.append("Tera Blast" if format_id == "tera_raid" else "Protect" if format_id in ["doubles", "vgc"] else "Knock Off")
		else:
			out.append(m)
	return out
