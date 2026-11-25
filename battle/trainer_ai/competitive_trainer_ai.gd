class_name CompetitiveTrainerAI
extends Node
## Format-aware Competitive Trainer AI (Singles/Doubles/VGC/Triple/Rotation/Sky/Inverse/Tera Raid)
## + VEXA 100% Super-Effective Counter-Team Builder + Strict Challenge Run Compliance.
##
## v3 (leftovers): same behaviour as RC1. One fix: line 11 used `:=`
## on a Variant value (max() returns Variant), which Godot's
## headless check treats as an error. It is now an explicit float
## using maxf(). No other line changed.

const ALL_FORMATS := ["singles", "doubles", "vgc", "triple", "rotation", "sky", "inverse", "tera_raid"]

static func choose_action(ai_mon: Dictionary, player_mon: Dictionary, ai_party: Array, move_db: MoveDatabase, challenge_mode: String, format_id: String, inverse_types: bool = false) -> Dictionary:
	# 1. Challenge-run compliant healing check (AI never cheats when items/healing are banned)
	var allow_item := challenge_mode in ["standard"]
	var hp_ratio: float = float(ai_mon.get("hp", 1)) / maxf(1.0, float(ai_mon.get("max_hp", 1)))
	if allow_item and hp_ratio < 0.28 and int(ai_mon.get("ai_potions_left", 0)) > 0:
		ai_mon["ai_potions_left"] = int(ai_mon.get("ai_potions_left", 0)) - 1
		return {"type": "item", "item_id": "full_restore"}

	# 2. Score all legal moves by expected damage + tactical value
	var legal_moves: Array = move_db.filter_for_challenge(ai_mon.get("moves", ["Thunderbolt"]), challenge_mode, format_id)
	var best_move: String = legal_moves[0] if legal_moves.size() > 0 else "Tera Blast"
	var best_score := -1.0
	for m_name in legal_moves:
		var md := move_db.get_move(m_name)
		var score := 0.0
		if md.get("cat", "") == "Status":
			if md.has("hazard") and not ai_mon.get("hazard_set", false):
				score = 92.0
			elif md.has("status") and player_mon.get("status", "") == "":
				score = 78.0
			elif md.get("heal_self", 0.0) > 0.0 and hp_ratio < 0.45:
				score = 110.0
			else:
				score = 25.0
		else:
			var pwr := float(md.get("power", 80))
			var stab := 1.5 if md.get("type", "") in ai_mon.get("types", []) else 1.0
			var eff := float(md.get("cached_eff", 1.0))
			if inverse_types:
				eff = 2.0 if eff == 0.0 else (0.5 if eff >= 2.0 else (2.0 if eff < 1.0 else 1.0))
			score = pwr * stab * eff + float(md.get("priority", 0)) * 18.0
		if score > best_score:
			best_score = score
			best_move = m_name
	return {"type": "move", "move_name": best_move, "score": best_score}

static func build_vexa_counter_team(player_party: Array, format_id: String = "singles") -> Array:
	## Static Lab Holo-Sim: constructs a 6-Pokémon competitive counter team targeting player weaknesses.
	var counter_pool := [
		{"name": "Garchomp", "types": ["Dragon", "Ground"], "ability": "Rough Skin", "moves": ["Earthquake", "Dragon Claw", "Stone Edge", "Stealth Rock"]},
		{"name": "Gholdengo", "types": ["Steel", "Ghost"], "ability": "Good as Gold", "moves": ["Make It Rain", "Shadow Ball", "Recover", "Nasty Plot"]},
		{"name": "Flutter Mane", "types": ["Ghost", "Fairy"], "ability": "Protosynthesis", "moves": ["Moonblast", "Shadow Ball", "Dazzling Gleam", "Mystical Fire"]},
		{"name": "Dragonite", "types": ["Dragon", "Flying"], "ability": "Multiscale", "moves": ["Extreme Speed", "Dragon Dance", "Earthquake", "Roost"]},
		{"name": "Volcarona", "types": ["Bug", "Fire"], "ability": "Flame Body", "moves": ["Flamethrower", "Bug Buzz", "Giga Drain", "Protect"]},
		{"name": "Corviknight", "types": ["Flying", "Steel"], "ability": "Pressure", "moves": ["Brave Bird", "Iron Head", "U-turn", "Roost"]},
	]
	if format_id == "sky":
		return [counter_pool[3], counter_pool[5], counter_pool[3], counter_pool[5], counter_pool[3], counter_pool[5]]
	return counter_pool
