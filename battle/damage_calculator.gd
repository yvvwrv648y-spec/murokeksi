class_name PUWBattleEngine
extends RefCounted
## Battle damage math for Pokemon Ultimate World (Godot 4).
## The type chart below was made by a script from the Showdown type data
## in battle-data-pack/typechart.json. It was not typed by hand.
## How the chart was made: for each defender type, Showdown lists
## "damageTaken" (0 = normal, 1 = weak, 2 = resist, 3 = immune).
## That turns into attacker -> defender numbers like this:
## 0 -> 1.0, 1 -> 2.0, 2 -> 0.5, 3 -> 0.0.
## "Stellar" is a Tera-only type, so it is not in this chart.
## A Stellar-type move is treated as neutral (1.0) here.
## Types and type names are matched without caring about capitals,
## because the move data writes them Capitalized ("Electric") and
## other code writes them lowercase ("electric").

const TYPE_CHART: Dictionary = {
	"normal": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 1.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 0.5, "ghost": 0.0, "dragon": 1.0, "dark": 1.0, "steel": 0.5, "fairy": 1.0},
	"fire": {"normal": 1.0, "fire": 0.5, "water": 0.5, "electric": 1.0, "grass": 2.0, "ice": 2.0, "fighting": 1.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 2.0, "rock": 0.5, "ghost": 1.0, "dragon": 0.5, "dark": 1.0, "steel": 2.0, "fairy": 1.0},
	"water": {"normal": 1.0, "fire": 2.0, "water": 0.5, "electric": 1.0, "grass": 0.5, "ice": 1.0, "fighting": 1.0, "poison": 1.0, "ground": 2.0, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 2.0, "ghost": 1.0, "dragon": 0.5, "dark": 1.0, "steel": 1.0, "fairy": 1.0},
	"electric": {"normal": 1.0, "fire": 1.0, "water": 2.0, "electric": 0.5, "grass": 0.5, "ice": 1.0, "fighting": 1.0, "poison": 1.0, "ground": 0.0, "flying": 2.0, "psychic": 1.0, "bug": 1.0, "rock": 1.0, "ghost": 1.0, "dragon": 0.5, "dark": 1.0, "steel": 1.0, "fairy": 1.0},
	"grass": {"normal": 1.0, "fire": 0.5, "water": 2.0, "electric": 1.0, "grass": 0.5, "ice": 1.0, "fighting": 1.0, "poison": 0.5, "ground": 2.0, "flying": 0.5, "psychic": 1.0, "bug": 0.5, "rock": 2.0, "ghost": 1.0, "dragon": 0.5, "dark": 1.0, "steel": 0.5, "fairy": 1.0},
	"ice": {"normal": 1.0, "fire": 0.5, "water": 0.5, "electric": 1.0, "grass": 2.0, "ice": 0.5, "fighting": 1.0, "poison": 1.0, "ground": 2.0, "flying": 2.0, "psychic": 1.0, "bug": 1.0, "rock": 1.0, "ghost": 1.0, "dragon": 2.0, "dark": 1.0, "steel": 0.5, "fairy": 1.0},
	"fighting": {"normal": 2.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 2.0, "fighting": 1.0, "poison": 0.5, "ground": 1.0, "flying": 0.5, "psychic": 0.5, "bug": 0.5, "rock": 2.0, "ghost": 0.0, "dragon": 1.0, "dark": 2.0, "steel": 2.0, "fairy": 0.5},
	"poison": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 2.0, "ice": 1.0, "fighting": 1.0, "poison": 0.5, "ground": 0.5, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 0.5, "ghost": 0.5, "dragon": 1.0, "dark": 1.0, "steel": 0.0, "fairy": 2.0},
	"ground": {"normal": 1.0, "fire": 2.0, "water": 1.0, "electric": 2.0, "grass": 0.5, "ice": 1.0, "fighting": 1.0, "poison": 2.0, "ground": 1.0, "flying": 0.0, "psychic": 1.0, "bug": 0.5, "rock": 2.0, "ghost": 1.0, "dragon": 1.0, "dark": 1.0, "steel": 2.0, "fairy": 1.0},
	"flying": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 0.5, "grass": 2.0, "ice": 1.0, "fighting": 2.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 2.0, "rock": 0.5, "ghost": 1.0, "dragon": 1.0, "dark": 1.0, "steel": 0.5, "fairy": 1.0},
	"psychic": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 2.0, "poison": 2.0, "ground": 1.0, "flying": 1.0, "psychic": 0.5, "bug": 1.0, "rock": 1.0, "ghost": 1.0, "dragon": 1.0, "dark": 0.0, "steel": 0.5, "fairy": 1.0},
	"bug": {"normal": 1.0, "fire": 0.5, "water": 1.0, "electric": 1.0, "grass": 2.0, "ice": 1.0, "fighting": 0.5, "poison": 0.5, "ground": 1.0, "flying": 0.5, "psychic": 2.0, "bug": 1.0, "rock": 1.0, "ghost": 0.5, "dragon": 1.0, "dark": 2.0, "steel": 0.5, "fairy": 0.5},
	"rock": {"normal": 1.0, "fire": 2.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 2.0, "fighting": 0.5, "poison": 1.0, "ground": 0.5, "flying": 2.0, "psychic": 1.0, "bug": 2.0, "rock": 1.0, "ghost": 1.0, "dragon": 1.0, "dark": 1.0, "steel": 0.5, "fairy": 1.0},
	"ghost": {"normal": 0.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 1.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 2.0, "bug": 1.0, "rock": 1.0, "ghost": 2.0, "dragon": 1.0, "dark": 0.5, "steel": 1.0, "fairy": 1.0},
	"dragon": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 1.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 1.0, "ghost": 1.0, "dragon": 2.0, "dark": 1.0, "steel": 0.5, "fairy": 0.0},
	"dark": {"normal": 1.0, "fire": 1.0, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 0.5, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 2.0, "bug": 1.0, "rock": 1.0, "ghost": 2.0, "dragon": 1.0, "dark": 0.5, "steel": 1.0, "fairy": 0.5},
	"steel": {"normal": 1.0, "fire": 0.5, "water": 0.5, "electric": 0.5, "grass": 1.0, "ice": 2.0, "fighting": 1.0, "poison": 1.0, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 2.0, "ghost": 1.0, "dragon": 1.0, "dark": 1.0, "steel": 0.5, "fairy": 2.0},
	"fairy": {"normal": 1.0, "fire": 0.5, "water": 1.0, "electric": 1.0, "grass": 1.0, "ice": 1.0, "fighting": 2.0, "poison": 0.5, "ground": 1.0, "flying": 1.0, "psychic": 1.0, "bug": 1.0, "rock": 1.0, "ghost": 1.0, "dragon": 2.0, "dark": 2.0, "steel": 0.5, "fairy": 1.0}
}

static func type_multiplier(move_type: String, defender_types: PackedStringArray) -> float:
	var atk_type: String = move_type.to_lower()
	if atk_type == "stellar":
		# Stellar is Tera-only and is not on the normal chart.
		return 1.0
	var mult: float = 1.0
	var row: Dictionary = TYPE_CHART.get(atk_type, {})
	for t in defender_types:
		mult *= float(row.get(str(t).to_lower(), 1.0))
	return mult

## Weather and terrain change how strong a move is. This is only used
## when the attacker or defender has a "field" key holding the battle
## field state (weather, terrain). Sun: Fire 1.5x, Water 0.5x.
## Rain: Water 1.5x, Fire 0.5x. Electric Terrain: Electric 1.3x.
## Grassy Terrain: Grass 1.3x. Psychic Terrain: Psychic 1.3x.
## Misty Terrain: Dragon moves are halved (0.5x).
static func field_multiplier(move_type: String, field: Dictionary) -> float:
	var mult: float = 1.0
	var mtype: String = move_type.to_lower()
	var weather: String = str(field.get("weather", "none")).to_lower()
	if weather == "sun":
		if mtype == "fire":
			mult *= 1.5
		elif mtype == "water":
			mult *= 0.5
	elif weather == "rain":
		if mtype == "water":
			mult *= 1.5
		elif mtype == "fire":
			mult *= 0.5
	var terrain: String = str(field.get("terrain", "none")).to_lower()
	if terrain == "electric" and mtype == "electric":
		mult *= 1.3
	elif terrain == "grassy" and mtype == "grass":
		mult *= 1.3
	elif terrain == "psychic" and mtype == "psychic":
		mult *= 1.3
	elif terrain == "misty" and mtype == "dragon":
		mult *= 0.5
	return mult

static func _has_type(types: Array, wanted: String) -> bool:
	for t in types:
		if str(t).to_lower() == wanted.to_lower():
			return true
	return false

## One stat stage as a multiplier (Showdown stage table): +n
## stages give (2+n)/2, -n stages give 2/(2+n). Stage 0 is 1.0.
static func _stage_mult(stage: int) -> float:
	if stage >= 0:
		return (2.0 + float(stage)) / 2.0
	return 2.0 / (2.0 + float(-stage))

static func calculate_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, rng: RandomNumberGenerator) -> Dictionary:

	var level: int = int(attacker.get("level", 5))
	var power: int = int(move.get("power", 40))
	if power <= 0:
		return {"damage": 0, "effectiveness": 1.0, "critical": false, "stab": 1.0, "field_mult": 1.0}
	# The field state, when the controller passed one on the
	# attacker or defender under the "field" key. Read early:
	# Gravity and Wonder Room change the stats and types below.
	# No field key means no change.
	var field: Dictionary = attacker.get("field", defender.get("field", {}))
	var gravity_up: bool = int(field.get("gravity", 0)) > 0
	var wonder_room_up: bool = int(field.get("wonder_room", 0)) > 0
	# The move data writes the category as "cat" ("Physical"/"Special").
	# Older code wrote "category". Both are read here.
	var cat: String = str(move.get("category", move.get("cat", "physical"))).to_lower()
	var is_special: bool = cat == "special"
	# Wonder Room swaps every Pokemon's Defense and Sp. Def for
	# as long as it is up, so a Physical move meets the target's
	# Sp. Def and a Special move meets its Defense. The stage of
	# the swapped-in stat comes with it (the stats swap whole).
	var def_key: String = "spd" if is_special else "def"
	if wonder_room_up:
		def_key = "def" if is_special else "spd"
	var atk: float = float(attacker.get("spa" if is_special else "atk", 15))
	var defn: float = maxf(1.0, float(defender.get(def_key, 12)))
	# Stat stages, applied here for the first time: until now the
	# engine tracked stages but never used them in damage. Stage
	# table from Showdown: +n stages multiply the stat by (2+n)/2,
	# -n stages multiply it by 2/(2+n). Unaware ignores the foe's
	# stages: the attacker's Unaware ignores the defender's
	# Defense stages, and the defender's Unaware ignores the
	# attacker's Attack stages. The before_move flags carry the
	# same facts, and the ability name is checked too, because in
	# doubles before_move runs with defender {} and never sets
	# the flags.
	var atk_stages: Dictionary = attacker.get("stages", {})
	var def_stages: Dictionary = defender.get("stages", {})
	var atk_stage: int = int(atk_stages.get("spa" if is_special else "atk", 0))
	var def_stage: int = int(def_stages.get(def_key, 0))
	if bool(attacker.get("ignore_atk_stages", false)) or str(defender.get("ability", "")) == "Unaware":
		atk_stage = 0
	if bool(defender.get("ignore_def_stages", false)) or str(attacker.get("ability", "")) == "Unaware":
		def_stage = 0
	# Held-item species stat multipliers (Light Ball, Thick
	# Club, Metal Powder — ItemEngine.stat_multiplier), applied
	# to the raw stat before its stage multiplier.
	atk *= ItemEngine.stat_multiplier(attacker, "spa" if is_special else "atk")
	defn *= ItemEngine.stat_multiplier(defender, def_key)
	atk *= _stage_mult(atk_stage)
	defn = maxf(1.0, defn * _stage_mult(def_stage))

	var move_type: String = str(move.get("type", "normal"))
	# STAB (same-type bonus). Terastal rule (Gen 9): a Terastallized
	# Pokemon gets 2.0x on moves of its Tera type, and keeps 1.5x on
	# moves that match its original types. The gimmick code stores the
	# Tera type in "tera_type" and the old types in "original_types".
	var stab: float = 1.0
	var tera_type: String = str(attacker.get("tera_type", ""))
	if tera_type != "" and move_type.to_lower() == tera_type.to_lower():
		stab = 2.0
	elif _has_type(attacker.get("original_types", attacker.get("types", [])), move_type):
		stab = 1.5
	elif _has_type(attacker.get("types", []), move_type):
		stab = 1.5
	var def_types := PackedStringArray()
	for t in defender.get("types", []):
		# Gravity grounds Flying Pokemon: while it is up, a
		# Ground move meets the target as if it had no Flying
		# type, so it can be hit (Showdown: Gravity makes
		# Ground-type moves hit Flying-type Pokemon).
		if gravity_up and move_type.to_lower() == "ground" and str(t).to_lower() == "flying":
			continue
		def_types.append(str(t))
	var eff: float = type_multiplier(move_type, def_types)
	# Inverse Battle (Gen VI format, field flag "inverse_battle"
	# set by the controller for that format): every single-type
	# pairing is flipped on its own — 2x becomes 0.5x, 0.5x
	# becomes 2x, and an immunity (0x) becomes 2x. Flipping per
	# pairing means a dual-type defender's 4x becomes 0.25x and
	# its 0.25x becomes 4x, exactly as the format doc says.
	if bool(field.get("inverse_battle", false)):
		eff = 1.0
		for t in def_types:
			var single: float = type_multiplier(move_type, PackedStringArray([str(t)]))
			eff *= 2.0 if single == 0.0 else 1.0 / single
	var crit_stage: int = 0
	if bool(move.get("high_crit", false)):
		crit_stage += 1
	if int(move.get("critRatio", 0)) >= 1:
		crit_stage += 1
	crit_stage += AbilityEngine.crit_stage(attacker, move, defender)
	crit_stage += ItemEngine.crit_stage(attacker)
	crit_stage = clampi(crit_stage, 0, 4)
	var crit_table: Array = [24.0, 8.0, 2.0, 1.0, 1.0]
	var crit_chance: float = 1.0 / float(crit_table[crit_stage])
	var always_crit: bool = bool(move.get("always_crit", false)) or bool(move.get("willCrit", false))
	var crit_blocked: bool = false
	var def_ab: String = str(defender.get("ability", ""))
	if def_ab == "Battle Armor" or def_ab == "Shell Armor":
		# The hit can never be a crit (Showdown onCriticalHit
		# false for both), unless the move ignores abilities:
		# the move flag is the real mark (Mold Breaker, Teravolt
		# and Turboblaze set it in before_move), and the attacker
		# ability name covers direct calls that never ran
		# before_move, such as Struggle.
		var atk_ab: String = str(attacker.get("ability", ""))
		var ignores_ab: bool = bool(move.get("ignore_ability", false)) or bool(attacker.get("ignore_ability", false)) or atk_ab == "Mold Breaker" or atk_ab == "Teravolt" or atk_ab == "Turboblaze"
		if not ignores_ab:
			crit_blocked = true

	var crit: bool = false
	if not crit_blocked:
		crit = always_crit or rng.randf() < crit_chance
	var crit_mult: float = 1.5 if crit else 1.0
	var rand_factor: float = rng.randf_range(0.85, 1.0)
	# Weather and terrain multipliers from the field state read
	# at the top of this function.
	var fmult: float = field_multiplier(move_type, field) if not field.is_empty() else 1.0
	# Screens on the defender's side, handed over by the controller
	# in defender["screens"] (patch 1-F). Reflect halves physical,
	# Light Screen halves special, Aurora Veil halves both. They do
	# not stack, and a critical hit ignores them. 0.5x is the singles
	# value; doubles would use about 0.667x.
	var screens: Dictionary = defender.get("screens", {})
	var screen_mult: float = 1.0
	if not crit:
		if int(screens.get("aurora_veil", 0)) > 0:
			screen_mult = 0.5
		elif not is_special and int(screens.get("reflect", 0)) > 0:
			screen_mult = 0.5
		elif is_special and int(screens.get("light_screen", 0)) > 0:
			screen_mult = 0.5
	var base: float = (((2.0 * float(level) / 5.0 + 2.0) * float(power) * (atk / defn)) / 50.0) + 2.0
	var dmg: int = maxi(1, int(floor(base * stab * eff * crit_mult * rand_factor * fmult * screen_mult))) if eff > 0.0 else 0
	return {"damage": dmg, "effectiveness": eff, "critical": crit, "stab": stab, "field_mult": fmult, "screen_mult": screen_mult}

static func compute_capture_chance(max_hp: int, cur_hp: int, catch_rate: int, ball_bonus: float, status_bonus: float) -> float:
	var a: float = (((3.0 * float(max_hp) - 2.0 * float(cur_hp)) * float(catch_rate) * ball_bonus) / (3.0 * float(max_hp))) * status_bonus
	return clampf(a / 255.0, 0.02, 1.0)
