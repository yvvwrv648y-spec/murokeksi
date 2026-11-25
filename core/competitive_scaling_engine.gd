class_name PUWCompetitiveScalingEngine
extends RefCounted
## Game-Wide Competitive Scaling, Dynamic Evolution, Format-Specific AI, & Challenge Run Rules.
## Applies universally from Route 1 to Champion / Leon — zero exceptions!

const MAX_LEVEL := 100
const COMPETITIVE_EV_BUDGET := 516
const HEALING_MOVES := ["Roost","Recover","Synthesis","Soft-Boiled","Moonlight","Morning Sun","Slack Off","Strength Sap","Giga Drain","Drain Punch","Wish","Protect"]

enum ChallengeMode {
	STANDARD_MAX_DIFFICULTY,
	NO_TRAINER_ITEMS,
	NO_ITEMS_UNIVERSAL,
	NO_HEALING_ITEMS,
	NO_HEALING_OR_MOVES
}

static func scale_wild_level(player_max_lv: int, offset_1_to_3: int = 2) -> int:
	if player_max_lv >= MAX_LEVEL:
		return MAX_LEVEL
	return clampi(player_max_lv + clampi(offset_1_to_3, 1, 3), 1, MAX_LEVEL)

static func scale_opponent_level(player_max_lv: int) -> int:
	if player_max_lv >= MAX_LEVEL:
		return MAX_LEVEL
	return clampi(player_max_lv, 1, MAX_LEVEL)

static func resolve_evolved_species(evo_stages: Array, current_level: int) -> String:
	var best_name: String = str(evo_stages[0]["name"])
	for st in evo_stages:
		if current_level >= int(st["min_lv"]):
			best_name = str(st["name"])
	return best_name

static func sanitize_moves_for_challenge(moves: Array[String], fallback_pool: Array[String], mode: int) -> Array[String]:
	if mode != ChallengeMode.NO_HEALING_OR_MOVES:
		return moves
	var out: Array[String] = []
	var fb_idx := 0
	for mv in moves:
		if mv in HEALING_MOVES:
			while fb_idx < fallback_pool.size() and (fallback_pool[fb_idx] in out or fallback_pool[fb_idx] in HEALING_MOVES):
				fb_idx += 1
			out.append(fallback_pool[fb_idx] if fb_idx < fallback_pool.size() else "Shadow Ball")
			fb_idx += 1
		else:
			out.append(mv)
	return out
