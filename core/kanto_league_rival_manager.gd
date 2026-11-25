class_name PUWKantoLeagueRivalManager
extends RefCounted
## Branching Kanto Elite Four, Dynamic Champion/Runner-Up, Victory Road Male Gatekeeper,
## and Exclusive Rival-Defeat-Only Shiny Multi-Gimmick Egg System.

var protagonist_id: String = "riley"
var champion_id: String = "futanari"
var runner_up_id: String = "femboy"
var male_gatekeeper_defeated: bool = false
var riley_defeats: int = 0
var tasha_defeats: int = 0
var earned_exclusive_eggs: Array[Dictionary] = []

func configure_for_protagonist(protag: String, rng_seed: int = 0) -> Dictionary:
	protagonist_id = protag
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	if protag == "riley" or protag == "tasha":
		var flip := rng.randi_range(0, 1) == 0
		champion_id = "futanari" if flip else "femboy"
		runner_up_id = "femboy" if flip else "futanari"
		return {
			"rival": "tasha" if protag == "riley" else "riley",
			"rival_encounters_total": 6,
			"victory_road_pre_cave_opponent": "male",
			"runner_up_before_e4": runner_up_id,
			"champion": champion_id
		}
	else:
		var pool := ["futanari", "male", "femboy"]
		champion_id = pool[rng.randi_range(0, 2)]
		runner_up_id = pool[(pool.find(champion_id) + 1) % 3]
		return {
			"rivals": ["riley", "tasha"],
			"riley_encounters": 3,
			"tasha_encounters": 3,
			"runner_up_before_e4": runner_up_id,
			"champion": champion_id
		}
