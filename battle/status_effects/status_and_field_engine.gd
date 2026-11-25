class_name StatusAndFieldEngine
extends Node
## Handles Primary Statuses (BRN/PAR/PSN/TOX/SLP/FRZ), Entry Hazards, Screens, Weather, and Terrains.
##
## v3 (leftovers): same behaviour as RC1, plus three fixes.
## 1. Poison Heal: PSN and TOX do no damage here when the mon's
## ability is "Poison Heal". AbilityEngine.on_end_of_turn heals
## those holders instead, so this file must not hurt them first.
## Burn and sandstorm damage are NOT skipped for Poison Heal
## holders: only poison damage is skipped.
## 2. Every `:=` that read a Variant value is now an explicit type.
## Godot's headless check treats `:=` from a Variant as an error.
## No other line changed behaviour.
## 3. Sandstorm damage is skipped for Overcoat, Sand Force, Sand Rush
## and Sand Veil holders, and while the weather is suppressed
## (Air Lock / Cloud Nine). Ground, Rock and Steel types were already
## safe. Magic Guard holders already skip all end-of-turn damage.

##
## Terrains: Grassy Terrain heals 1/16 max HP here (see
## apply_end_of_turn). Electric, Psychic and Misty Terrain have no
## HP tick in the real games, so they have none here either. All
## terrains run out through terrain_turns, which the battle
## controller ticks down each turn.

static func create_field_state() -> Dictionary:
	return {
		"weather": "none", "weather_turns": 0,
		"terrain": "none", "terrain_turns": 0,
		"trick_room": 0,
		"gravity": 0,
		"wonder_room": 0,
		"magic_room": 0,
		"player_safeguard": 0,
		"enemy_safeguard": 0,
		"player_hazards": {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false},
		"enemy_hazards": {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false},
		"player_screens": {"reflect": 0, "light_screen": 0, "aurora_veil": 0, "tailwind": 0},
		"enemy_screens": {"reflect": 0, "light_screen": 0, "aurora_veil": 0, "tailwind": 0},
	}

static func can_act_this_turn(mon: Dictionary) -> Dictionary:
	var st: String = mon.get("status", "")
	if st == "SLP":
		# Showdown conditions.ts slp: time is set to 2-4 on start
		# (1-3 failed attempts). On each attempted move time drops by
		# 1, and by 2 when the mon has Early Bird, then the mon wakes
		# when time <= 0. try_set_status sets sleep_turns = 2-4, so
		# this decrement-then-check is exact: normal sleep fails
		# 1/2/3 attempts for time 2/3/4; Early Bird fails 0/1/1.
		# A mon with no sleep_turns set (pre-patch save) defaults to
		# 2, so it fails 1 attempt, then wakes - today's behaviour.
		var turns: int = int(mon.get("sleep_turns", 2))
		var drop: int = AbilityEngine.sleep_tick(mon)
		var left: int = turns - drop
		if left <= 0:
			mon["status"] = ""
			mon["sleep_turns"] = 0
			return {"can_act": true, "log": "%s woke up!" % mon.get("name", "Pokémon")}
		mon["sleep_turns"] = left
		return {"can_act": false, "log": "%s is fast asleep!" % mon.get("name", "Pokémon")}
	if st == "FRZ":
		if randf() < 0.20:
			mon["status"] = ""
			return {"can_act": true, "log": "%s thawed out!" % mon.get("name", "Pokémon")}
		return {"can_act": false, "log": "%s is frozen solid!" % mon.get("name", "Pokémon")}
	if st == "PAR" and randf() < 0.25:
		return {"can_act": false, "log": "%s is paralyzed! It can't move!" % mon.get("name", "Pokémon")}
	return {"can_act": true, "log": ""}

static func apply_end_of_turn(mon: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	if int(mon.get("hp", 0)) <= 0:
		return logs
	var max_hp: int = int(mon.get("max_hp", 100))
	var ab: String = mon.get("ability", "")
	var st: String = mon.get("status", "")
	if not AbilityEngine.blocks_indirect_damage(mon):
		if st == "BRN":
			var chip: int = maxi(1, int(floor(float(max_hp) / 16.0)))
			mon["hp"] = max(0, int(mon.get("hp", 0)) - chip)
			logs.append("%s was hurt by its burn (-%d HP)!" % [mon.get("name", "Pokémon"), chip])
		elif st == "PSN" and ab != "Poison Heal":
			var chip: int = maxi(1, int(floor(float(max_hp) / 8.0)))
			mon["hp"] = max(0, int(mon.get("hp", 0)) - chip)
			logs.append("%s was hurt by poison (-%d HP)!" % [mon.get("name", "Pokémon"), chip])
		elif st == "TOX" and ab != "Poison Heal":
			var tc: int = int(mon.get("toxic_counter", 1))
			var chip: int = maxi(1, int(floor(float(max_hp) * float(tc) / 16.0)))
			mon["toxic_counter"] = tc + 1
			mon["hp"] = max(0, int(mon.get("hp", 0)) - chip)
			logs.append("%s was badly poisoned (-%d HP)!" % [mon.get("name", "Pokémon"), chip])
		if field.get("weather", "none") == "sand" and not bool(field.get("weather_suppressed", false)):
			var types: Array = mon.get("types", [])
			if not ("Rock" in types or "Ground" in types or "Steel" in types) and not AbilityEngine.is_immune_to_weather_damage(mon, "sand") and not ItemEngine.blocks_weather_damage(mon):
				var chip: int = maxi(1, int(floor(float(max_hp) / 16.0)))
				mon["hp"] = max(0, int(mon.get("hp", 0)) - chip)
				logs.append("%s is buffeted by the sandstorm (-%d HP)!" % [mon.get("name", "Pokémon"), chip])

	if field.get("terrain", "none") == "grassy" and int(mon.get("hp", 0)) > 0:
		# Heal Block blocks the Grassy Terrain heal, from
		# either source: the Heal Block move's counter or
		# Psychic Noise's own 2-turn counter (both keys
		# checked inline here, the same rule as the other
		# heal gates).
		if int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0:
			logs.append("%s is prevented from healing by Heal Block!" % mon.get("name", "Pokémon"))
		else:
			var heal: int = maxi(1, int(floor(float(max_hp) / 16.0)))
			mon["hp"] = min(max_hp, int(mon.get("hp", 0)) + heal)
			logs.append("%s restored HP from Grassy Terrain!" % mon.get("name", "Pokémon"))
	return logs

static func apply_entry_hazards(mon: Dictionary, hazards: Dictionary, rock_eff: float = 1.0) -> Array:
	var logs: Array = []
	var max_hp: int = int(mon.get("max_hp", 100))
	# Magic Guard blocks indirect DAMAGE only (Stealth Rock, Spikes).
	# It does not block Sticky Web's Speed drop or Toxic Spikes'
	# poison: those are not damage. So the guard sits on the two
	# damage branches below, not on the whole function.
	var no_indirect: bool = AbilityEngine.blocks_indirect_damage(mon)
	if hazards.get("stealth_rock", false) and not no_indirect:
		var dmg: int = maxi(1, int(floor(float(max_hp) * 0.125 * rock_eff)))
		mon["hp"] = max(0, int(mon.get("hp", 0)) - dmg)
		logs.append("Pointed stones dug into %s (-%d HP)!" % [mon.get("name", "Pokémon"), dmg])
	var sp: int = int(hazards.get("spikes", 0))
	if sp > 0 and not no_indirect and not ("Flying" in mon.get("types", [])) and mon.get("ability", "") != "Levitate":
		var frac: float = 0.125 if sp == 1 else (0.1667 if sp == 2 else 0.25)
		var dmg: int = maxi(1, int(floor(float(max_hp) * frac)))
		mon["hp"] = max(0, int(mon.get("hp", 0)) - dmg)
		logs.append("%s was hurt by Spikes (-%d HP)!" % [mon.get("name", "Pokémon"), dmg])
	# Toxic Spikes: a grounded mon is poisoned (1 layer PSN, 2 layers
	# TOX) through the same choke point as move poison, so Leaf Guard,
	# Synchronize and Poison Puppeteer still fire. A Poison type
	# absorbs the spikes instead: the layers clear and nobody is
	# poisoned. Steel types cannot be poisoned, so they are skipped
	# here (try_set_status skips the type check when the source is
	# empty, so the check lives here, not in there). Toxic Debris
	# sets these layers.
	var mtypes: Array = []
	for ty in mon.get("types", []):
		mtypes.append(str(ty).to_lower())
	var grounded: bool = not ("flying" in mtypes) and str(mon.get("ability", "")) != "Levitate"
	var tsp: int = int(hazards.get("toxic_spikes", 0))
	if tsp > 0 and grounded:
		if "poison" in mtypes:
			hazards["toxic_spikes"] = 0
			logs.append("The Toxic Spikes were absorbed!")
		elif "steel" not in mtypes:
			AbilityEngine.try_set_status(mon, "TOX" if tsp >= 2 else "PSN", {}, {}, logs)
	if hazards.get("sticky_web", false) and not ("Flying" in mon.get("types", [])) and mon.get("ability", "") != "Levitate":
		var stages: Dictionary = mon.get("stages", {"spe": 0})
		stages["spe"] = max(-6, int(stages.get("spe", 0)) - 1)
		mon["stages"] = stages
		logs.append("%s was caught in a Sticky Web! Speed fell!" % mon.get("name", "Pokémon"))
	return logs
