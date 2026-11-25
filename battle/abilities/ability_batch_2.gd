class_name AbilityBatch2
extends RefCounted
## Ability batch 2 for Pokemon Ultimate World, battle engine v3.
## 70 abilities, Flower Gift through Mycelium Might (alphabetical).
## Every mechanic below comes from Showdown abilities.ts. No invented
## mechanics. Static funcs only, fully self-contained, no references
## to any other file. All hook signatures match the v3 coordinator
## contract. Types are written out explicitly everywhere: never use
## inferred assignment on a Variant value (Dictionary.get, Array access, untyped
## returns), because Godot's headless check treats that as an error.
##
## Conventions used (same as v2 AbilityEngine):
## - field["weather"] is "sun"/"rain"/"sand"/"snow"/"none" with
##   field["weather_turns"]; field["terrain"] is "grassy"/"electric"/
##   "psychic"/"misty"/"none" with field["terrain_turns"].
## - mon["stages"] keys are atk/def/spa/spd/spe; mon["status"] is
##   BRN/PAR/PSN/TOX/SLP/FRZ/""; mon["types"] is an Array of type
##   names (any case); mon["hp"]/mon["max_hp"] are ints; mon["item"]
##   is an item slug (PokeAPI style like "sitrus-berry" or Showdown
##   style like "sitrusberry"; helpers normalise both) or "".
## - mon["species"] holds the species/forme name (e.g. "Eiscue",
##   "Eiscue-Noice", "Cramorant-Gulping"); mon["forme"] holds the
##   current forme slug when one applies.
##
## Ally data (doubles) is NOT in the v3 hook signatures, so ally
## effects read two optional keys the controller may set:
## - mon["ally"] is a Dictionary of the active ally, used by
##   Hospitality (heal 1/4 on switch-in) and Healer (30% cure).
## - mon["ally_ability"] is a String with the active ally's ability,
##   used by Flower Gift (ally Atk/SpD in sun) and Minus (ally
##   Minus/Plus). Without these keys the ally half of those abilities
##   does nothing; the holder's own half still works.
##
## Notes on tricky ones (see the report for the full list):
## - Lightning Rod / Motor Drive: the SpA / Spe +1 boost is applied
##   inside is_immune, because that is the only hook that sees the
##   Electric hit before damage is worked out. The controller must
##   call is_immune once per hit, or the boost could fire twice.
##   Redirecting Electric moves to the holder has no hook here.
## - Mold Breaker: is_immune returns false when attacker_ability is
##   "Mold Breaker"; damage_mult skips defender-ability cuts when
##   the attacker's ability is Mold Breaker; before_move sets
##   move["ignore_ability"] and attacker["ignore_ability"] to true.
## - Poison Heal: REMOVED at v3 integration (duplicate). The heal now
##   lives in batch 3 only (Poison Heal alphabetically belongs there).
##   StatusAndFieldEngine must still skip poison damage for Poison
##   Heal holders; that file is owned by another builder.
## - Fur Coat, Grass Pelt, Marvel Scale, Flower Gift (SpD) and
##   Heatproof change a stat, so damage_mult folds them into a
##   damage multiplier instead: doubled/halved Def or SpD becomes
##   half / 1.5x damage on the matching side, and a halved offensive
##   stat becomes half damage. Hustle and Gorilla Tactics (1.5x Atk)
##   and Hadron Engine (1.3333x SpA in Electric Terrain) work the
##   same way. This is the same stat-to-damage mapping v2 used.
## - Ice Face: damage_mult returns 0.0 for the first physical hit
##   on Ice Face Eiscue and sets defender["ice_face_broken"] = true
##   plus defender["forme"] = "eiscue-noice", so the controller can
##   log it and change the forme. There is no logs parameter here.
## - Magic Guard blocks indirect damage through
##   blocks_indirect_damage (Batch2), called by StatusAndFieldEngine
##   and by the controller at the Life Orb call sites. Liquid Ooze
##   is handled in MoveEffects.apply_after_hit (patch 7; the note
##   here is updated early so the header is final when the whole
##   spec is applied). Honey Gather has no hooks at all in Showdown
##   (no competitive use), so it is a deliberate no-op.
## - Merciless works through crit_stage now: the dispatcher passes
##   the defender, so target poison is visible. Mycelium Might's
##   -0.1 fractional priority cannot be an int priority_bonus.

## Berry slugs end in "berry" once dashes and underscores are
## stripped; this covers both "sitrus-berry" and "sitrusberry".
## Plates map to types the same way ("flame-plate" / "flameplate").

## Lowercase a string and strip dashes, underscores, spaces and
## apostrophes, so species, move and item names compare the same
## in either slug style.
static func _norm(raw: String) -> String:
	var out: String = raw.to_lower()
	out = out.replace("-", "")
	out = out.replace("_", "")
	out = out.replace(" ", "")
	out = out.replace("'", "")
	return out


## Species id of a mon, e.g. "eiscue", "cramorantgulping".
static func _species_id(mon: Dictionary) -> String:
	return _norm(str(mon.get("species", mon.get("name", ""))))


## Current forme slug of a mon, falling back to its species id.
static func _forme_id(mon: Dictionary) -> String:
	var forme: String = str(mon.get("forme", ""))
	if forme != "":
		return _norm(forme)
	return _species_id(mon)


## True when the mon has the given type (case-insensitive).
static func _has_type(mon: Dictionary, type_name: String) -> bool:
	var types: Array = mon.get("types", [])
	var want: String = type_name.to_lower()
	for t in types:
		if str(t).to_lower() == want:
			return true
	return false


## True when the move has the named flag. moves.json marks flags
## with flags.<name> = 1; RC1 move dicts may carry a top-level bool.
static func _flag(move: Dictionary, key: String) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if flags.has(key):
		return bool(flags.get(key, false))
	return bool(move.get(key, false))


## Move type, category, name/id and power, accepting both the
## moves.json keys (type/category/basePower) and the RC1 keys
## (type/cat/power).
static func _move_type(move: Dictionary) -> String:
	return str(move.get("type", ""))


static func _move_cat(move: Dictionary) -> String:
	return str(move.get("cat", move.get("category", "")))


static func _move_id(move: Dictionary) -> String:
	return _norm(str(move.get("id", move.get("name", ""))))


static func _move_power(move: Dictionary) -> int:
	return int(move.get("power", move.get("basePower", 0)))


## True when the move makes contact.
static func _is_contact(move: Dictionary) -> bool:
	return _flag(move, "contact")


## True when the move is a sound-based move.
static func _is_sound(move: Dictionary) -> bool:
	return _flag(move, "sound")


## True when the move is a pulse move.
static func _is_pulse(move: Dictionary) -> bool:
	return _flag(move, "pulse")


## True when the item slug is a Berry.
static func _is_berry(item: String) -> bool:
	return _norm(item).ends_with("berry")


## Plate slug to the type it gives Arceus, "" when not a Plate.
## Legend Plate (all types) and Blank Plate (no type) return "".
static func _plate_type(item: String) -> String:
	var slug: String = _norm(item)
	match slug:
		"flameplate":
			return "Fire"
		"splashplate":
			return "Water"
		"zapplate":
			return "Electric"
		"meadowplate":
			return "Grass"
		"icicleplate":
			return "Ice"
		"fistplate":
			return "Fighting"
		"toxicplate":
			return "Poison"
		"earthplate":
			return "Ground"
		"skyplate":
			return "Flying"
		"mindplate":
			return "Psychic"
		"insectplate":
			return "Bug"
		"stoneplate":
			return "Rock"
		"spookyplate":
			return "Ghost"
		"dracoplate":
			return "Dragon"
		"dreadplate":
			return "Dark"
		"ironplate":
			return "Steel"
		"pixieplate":
			return "Fairy"
	return ""


## Raise one stat stage by an amount, clamped between -6 and +6.
## Logs nothing on its own; callers add the log line.
static func _bump_stage(mon: Dictionary, key: String, amount: int) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages[key] = clampi(int(stages.get(key, 0)) + amount, -6, 6)
	mon["stages"] = stages


## Same as _bump_stage, kept for callers that already pass logs.
static func _raise_stage(mon: Dictionary, key: String, amount: int, logs: Array) -> void:
	_bump_stage(mon, key, amount)


## Lose HP equal to a fraction of max HP, at least 1, never below 0.
static func _lose_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var loss: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = maxi(0, before - loss)
	return mini(loss, before)


## Lose an exact amount of HP, never below 0. Returns HP lost.
static func _lose_hp(mon: Dictionary, amount: int) -> int:
	var before: int = int(mon.get("hp", 0))
	var loss: int = mini(maxi(0, amount), before)
	mon["hp"] = before - loss
	return loss


## Heal HP by a fraction of max HP, never above max HP.
static func _heal_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var gain: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + gain)
	return int(mon.get("hp", 0)) - before


## Run form_change and, when it names a new forme, store it on the
## mon and log it. Used by on_switch_in and end_of_turn so weather
## formes update even if the controller only calls those hooks.
static func _apply_form_change(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	var ab: String = str(mon.get("ability", ""))
	if ab != "Forecast" and ab != "Flower Gift" and ab != "Ice Face":
		return
	var forme: String = form_change(mon, field)
	if forme == "":
		return
	mon["forme"] = forme
	if ab == "Ice Face":
		mon["ice_face_broken"] = false
	logs.append("%s changed forme!" % mon.get("name", "Pokémon"))


## Switch-in effects. Grassy/Misty Surge and Hadron Engine set
## their terrain. Intrepid Sword raises Attack once per battle.
## Frisk and Forewarn report what they sense. Imposter copies the
## foe's types and ability. Illusion raises its disguise flag.
## Multitype sets Arceus's type from its Plate. Mimicry sets the
## type for the current terrain. Forecast, Flower Gift and Ice Face
## check their forme. Gluttony marks the 1/2 HP Berry threshold
## for the item engine. Klutz suppresses the held item. Hospitality
## heals the active ally. Mold Breaker announces itself. Gorilla
## Tactics clears its move lock.
static func on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	match ab:
		"Grassy Surge":
			field["terrain"] = "grassy"
			field["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)
			logs.append("%s's Grassy Surge set Grassy Terrain!" % mon_name)
		"Misty Surge":
			field["terrain"] = "misty"
			field["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)
			logs.append("%s's Misty Surge set Misty Terrain!" % mon_name)
		"Hadron Engine":
			field["terrain"] = "electric"
			field["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)
			logs.append("%s's Hadron Engine set Electric Terrain!" % mon_name)
		"Intrepid Sword":
			if not bool(mon.get("sword_boost", false)):
				mon["sword_boost"] = true
				_raise_stage(mon, "atk", 1, logs)
				logs.append("%s's Intrepid Sword raised its Attack!" % mon_name)
		"Frisk":
			var foe_item: String = str(foe.get("item", ""))
			if foe_item != "":
				logs.append("%s's Frisk found %s holding %s!" % [mon_name, str(foe.get("name", "Foe")), foe_item])
		"Forewarn":
			var foe_moves: Array = foe.get("moves", [])
			var best_name: String = ""
			var best_power: int = 0
			for entry in foe_moves:
				if entry is Dictionary:
					var entry_dict: Dictionary = entry
					var bp: int = _move_power(entry_dict)
					if bp == 1:
						bp = 80
					if bp > best_power:
						best_power = bp
						best_name = str(entry_dict.get("name", entry_dict.get("id", "")))
			if best_name != "":
				logs.append("%s's Forewarn sensed %s's %s!" % [mon_name, str(foe.get("name", "Foe")), best_name])
			elif not foe_moves.is_empty():
				logs.append("%s's Forewarn sensed a strong move!" % mon_name)
		"Imposter":
			if not foe.is_empty():
				var foe_types: Array = foe.get("types", [])
				mon["types"] = foe_types.duplicate()
				mon["ability"] = str(foe.get("ability", ""))
				mon["transformed"] = true
				logs.append("%s transformed into %s with Imposter!" % [mon_name, str(foe.get("name", "Foe"))])
		"Illusion":
			mon["illusion_active"] = true
			logs.append("%s's Illusion is hiding its true form!" % mon_name)
		"Multitype":
			var sid: String = _species_id(mon)
			if sid == "arceus" or sid.begins_with("arceus"):
				var plate: String = _plate_type(str(mon.get("item", "")))
				if plate != "":
					mon["types"] = [plate]
					logs.append("%s's Multitype changed its type to %s!" % [mon_name, plate])
		"Mimicry":
			var terrain: String = str(field.get("terrain", "none"))
			var mimic_types: Array = []
			match terrain:
				"electric":
					mimic_types = ["Electric"]
				"grassy":
					mimic_types = ["Grass"]
				"misty":
					mimic_types = ["Fairy"]
				"psychic":
					mimic_types = ["Psychic"]
			if not mimic_types.is_empty():
				mon["types"] = mimic_types
				logs.append("%s's Mimicry changed its type to match the terrain!" % mon_name)
		"Gluttony":
			mon["gluttony"] = true
		"Klutz":
			mon["ignore_item"] = true
			logs.append("%s's Klutz is ignoring its held item!" % mon_name)
		"Hospitality":
			var ally: Dictionary = mon.get("ally", {})
			if not ally.is_empty() and int(ally.get("hp", 0)) > 0:
				var healed: int = _heal_fraction_hp(ally, 1, 4)
				if healed > 0:
					logs.append("%s's Hospitality restored %s's HP (+%d HP)!" % [mon_name, str(ally.get("name", "Ally")), healed])
		"Mold Breaker":
			logs.append("%s's Mold Breaker ignores the foe's ability!" % mon_name)
		"Gorilla Tactics":
			mon["gorilla_lock"] = ""
	_apply_form_change(mon, field, logs)
	return logs


## Switch-out effects. No ability in this batch acts on switching
## out (Regenerator is a v2 ability, not in this batch).
static func on_switch_out(mon: Dictionary) -> void:
	return


## True when an ability makes the defender immune to the move type.
## Mold Breaker on the attacker turns every ability immunity off.
## Lightning Rod and Motor Drive also raise the holder's SpA or
## Spe by 1 here, because this is the only hook that sees the
## Electric hit before damage is worked out; the controller must
## call this once per hit. Mountaineer only blocks Rock moves on
## the switch-in turn, so it needs defender["just_switched_in"] to
## be true on that turn. Mind's Eye needs no code here: it lets
## Normal and Fighting moves hit Ghost types, and the default
## return of false already means "not immune".
static func is_immune(defender: Dictionary, move_type: String, attacker_ability: String, effectiveness: float = 1.0) -> bool:
	if attacker_ability == "Mold Breaker" or attacker_ability == "Teravolt" or attacker_ability == "Turboblaze":
		return false
	var ab: String = str(defender.get("ability", ""))
	var mtype: String = move_type.to_lower()

	if ab == "Lightning Rod" and mtype == "electric":
		if int(defender.get("hp", 0)) > 0:
			_bump_stage(defender, "spa", 1)
		return true
	if ab == "Motor Drive" and mtype == "electric":
		if int(defender.get("hp", 0)) > 0:
			_bump_stage(defender, "spe", 1)
		return true
	if ab == "Mountaineer" and mtype == "rock" and bool(defender.get("just_switched_in", false)):
		return true
	return false

## Damage multiplier from abilities. Attacker side: Hustle and
## Gorilla Tactics (1.5x Attack) raise physical damage 1.5x; Mega
## Sol uses the Sun damage table (Fire 1.5x, Water 0.5x); Hadron
## Engine raises special damage 1.3333x in Electric Terrain;
## Flower Gift raises physical damage 1.5x for Cherrim (or its
## ally, via attacker["ally_ability"]) in Sun, blocked by a Utility
## Umbrella; Minus raises special damage 1.5x when the ally has
## Minus or Plus. Defender side is skipped when the attacker has
## Mold Breaker: Fluffy (contact 0.5x, Fire 2x), Ice Scales
## (special 0.5x), Fur Coat (physical 0.5x), Grass Pelt (physical
## 1/1.5x in Grassy Terrain), Marvel Scale (physical 1/1.5x while
## statused), Heatproof (Fire 0.5x, halved offensive stat), Flower
## Gift (special 1/1.5x for Cherrim or its ally in Sun). Ice Face
## returns 0.0 for the first physical hit on Ice Face Eiscue and
## sets defender["ice_face_broken"] and defender["forme"] so the
## controller can change the forme.
static func damage_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> float:
	var mult: float = 1.0
	var a_ab: String = str(attacker.get("ability", ""))
	var d_ab: String = str(defender.get("ability", ""))
	var cat: String = _move_cat(move)
	var mtype: String = _move_type(move).to_lower()
	var weather: String = ""
	var terrain: String = ""
	# The field is not passed here, so weather and terrain are read
	# from the attacker's stored copies when the controller keeps
	# them there; otherwise these checks stay off.
	weather = str(attacker.get("weather", ""))
	terrain = str(attacker.get("terrain", ""))
	if cat == "Physical" and a_ab == "Hustle":
		mult *= 1.5
	if cat == "Physical" and a_ab == "Gorilla Tactics":
		mult *= 1.5
	if a_ab == "Mega Sol":
		if mtype == "fire":
			mult *= 1.5
		elif mtype == "water":
			mult *= 0.5
	if a_ab == "Hadron Engine" and cat == "Special" and terrain == "electric":
		mult *= 1.3333
	if a_ab == "Flower Gift" or str(attacker.get("ally_ability", "")) == "Flower Gift":
		var a_sid: String = _species_id(attacker)
		var a_self: bool = a_sid == "cherrim" or a_sid == "cherrimsunshine"
		var a_ally: bool = str(attacker.get("ally_ability", "")) == "Flower Gift"
		if (a_self or a_ally) and weather == "sun" and cat == "Physical" and str(attacker.get("item", "")) != "utility-umbrella":
			mult *= 1.5
	if (a_ab == "Minus" or a_ab == "Plus") and cat == "Special":
		var ally_ab: String = str(attacker.get("ally_ability", ""))
		if ally_ab == "Minus" or ally_ab == "Plus":
			mult *= 1.5
	if a_ab != "Mold Breaker":
		if d_ab == "Fluffy":
			if _is_contact(move):
				mult *= 0.5
			if mtype == "fire":
				mult *= 2.0
		if d_ab == "Ice Scales" and cat == "Special":
			mult *= 0.5
		if d_ab == "Fur Coat" and cat == "Physical":
			mult *= 0.5
		if d_ab == "Grass Pelt" and cat == "Physical" and terrain == "grassy":
			mult *= 1.0 / 1.5
		if d_ab == "Marvel Scale" and cat == "Physical" and str(defender.get("status", "")) != "":
			mult *= 1.0 / 1.5
		if d_ab == "Heatproof" and mtype == "fire":
			mult *= 0.5
		if d_ab == "Flower Gift" or str(defender.get("ally_ability", "")) == "Flower Gift":
			var d_sid: String = _species_id(defender)
			var d_self: bool = d_sid == "cherrim" or d_sid == "cherrimsunshine"
			var d_ally: bool = str(defender.get("ally_ability", "")) == "Flower Gift"
			if (d_self or d_ally) and weather == "sun" and cat == "Special" and str(defender.get("item", "")) != "utility-umbrella":
				mult *= 1.0 / 1.5
		if d_ab == "Ice Face" and cat == "Physical" and _species_id(defender) == "eiscue":
			defender["ice_face_broken"] = true
			defender["forme"] = "eiscue-noice"
			return 0.0
	return mult


## End of turn ability effects. Harvest restores the last Berry used when the
## hands are empty: always in Sun, else a 50% chance. Hydration
## cures status in Rain (not with a Utility Umbrella). Hunger
## Switch flips Morpeko between Full Belly and Hangry Mode. Moody
## raises a random stat +2 and lowers a different random stat -1.
## Healer has a 30% chance to cure the active ally (mon["ally"]).
## Ice Face forme is restored in Snow through form_change.
static func end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var ab: String = str(mon.get("ability", ""))
	var weather: String = str(field.get("weather", "none"))
	var status: String = str(mon.get("status", ""))
	match ab:
		"Harvest":
			if str(mon.get("item", "")) == "":
				var last_item: String = str(mon.get("last_item", ""))
				if last_item != "" and _is_berry(last_item):
					if weather == "sun" or randf() < 0.5:
						mon["item"] = last_item
						mon["last_item"] = ""
						logs.append("%s's Harvest restored its %s!" % [mon.get("name", "Pokémon"), last_item])
		"Hydration":
			if status != "" and weather == "rain" and str(mon.get("item", "")) != "utility-umbrella":
				mon["status"] = ""
				logs.append("%s's Hydration cured its status!" % mon.get("name", "Pokémon"))
		"Hunger Switch":
			var sid: String = _species_id(mon)
			if (sid == "morpeko" or sid == "morpekohangry") and not bool(mon.get("terastallized", false)):
				var current: String = _forme_id(mon)
				var target: String = "morpeko-hangry"
				if current == "morpekohangry":
					target = "morpeko"
				mon["forme"] = target
				logs.append("%s's Hunger Switch changed its forme!" % mon.get("name", "Pokémon"))
		"Moody":
			var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
			var stat_keys: Array = ["atk", "def", "spa", "spd", "spe"]
			var plus_choices: Array = []
			for key in stat_keys:
				if int(stages.get(key, 0)) < 6:
					plus_choices.append(key)
			var minus_choices: Array = []
			var plus_stat: String = ""
			if not plus_choices.is_empty():
				plus_stat = str(plus_choices[randi_range(0, plus_choices.size() - 1)])
				_raise_stage(mon, plus_stat, 2, logs)
			for key in stat_keys:
				if int(stages.get(key, 0)) > -6 and key != plus_stat:
					minus_choices.append(key)
			if not minus_choices.is_empty():
				var minus_stat: String = str(minus_choices[randi_range(0, minus_choices.size() - 1)])
				_raise_stage(mon, minus_stat, -1, logs)
			if plus_stat != "":
				logs.append("%s's Moody shifted its stats!" % mon.get("name", "Pokémon"))
		"Healer":
			var ally: Dictionary = mon.get("ally", {})
			if not ally.is_empty() and str(ally.get("status", "")) != "" and randf() < 0.3:
				ally["status"] = ""
				logs.append("%s's Healer cured its ally's status!" % [mon.get("name", "Pokémon")])
	_apply_form_change(mon, field, logs)


## Effects when the defender is hit. Gooey lowers the attacker's
## Speed 1 stage on contact. Justified raises Attack 1 stage when
## hit by a Dark move. Lingering Aroma changes a contact
## attacker's ability to Lingering Aroma (some abilities are
## protected from this). Gulp Missile makes Gulping Cramorant deal
## 1/4 of the attacker's max HP and lower its Defense 1 stage, or
## Gorging Cramorant deal 1/4 max HP and paralyze it, then
## Cramorant returns to normal. Innards Out costs the attacker HP
## equal to the damage that knocked this Pokemon out. Magician
## steals the defender's item when the attacker has none and hits
## with a damaging move. Illusion ends when the holder takes
## direct damage.
static func on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var d_ab: String = str(defender.get("ability", ""))
	var a_ab: String = str(attacker.get("ability", ""))
	var contact: bool = _is_contact(move)
	var mtype: String = _move_type(move).to_lower()
	if d_ab == "Gooey" and contact and int(attacker.get("hp", 0)) > 0:
		_raise_stage(attacker, "spe", -1, logs)
		logs.append("%s's Gooey lowered %s's Speed!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon")])
	if d_ab == "Justified" and mtype == "dark":
		_raise_stage(defender, "atk", 1, logs)
		logs.append("%s's Justified raised its Attack!" % defender.get("name", "Pokémon"))
	if d_ab == "Lingering Aroma" and contact:
		var a_norm: String = _norm(a_ab)
		var protected: Array = ["battlebond", "comatose", "disguise", "gulpmissile", "iceface", "lingeringaroma", "multitype", "powerconstruct", "rkssystem", "schooling", "shieldsdown", "stancechange", "terashift", "zenmode", "zerotohero"]
		if a_norm != "asone" and not a_norm.begins_with("asone") and not protected.has(a_norm):
			attacker["ability"] = "Lingering Aroma"
			logs.append("%s's Lingering Aroma changed %s's ability!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon")])
	if d_ab == "Gulp Missile":
		var d_sid: String = _species_id(defender)
		if d_sid == "cramorantgulping" or d_sid == "cramorantgorging":
			if int(attacker.get("hp", 0)) > 0:
				var lost: int = _lose_fraction_hp(attacker, 1, 4)
				if lost > 0:
					logs.append("%s's Gulp Missile hurt %s (-%d HP)!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon"), lost])
				if d_sid == "cramorantgulping":
					_raise_stage(attacker, "def", -1, logs)
					logs.append("%s's Gulp Missile lowered %s's Defense!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon")])
				elif str(attacker.get("status", "")) == "":
					attacker["status"] = "PAR"
					logs.append("%s was paralyzed by Gulp Missile!" % attacker.get("name", "Pokémon"))
			defender["forme"] = "cramorant"
			defender["species"] = "Cramorant"
	if d_ab == "Innards Out" and int(defender.get("hp", 0)) <= 0 and int(attacker.get("hp", 0)) > 0:
		var lost2: int = _lose_hp(attacker, damage)
		if lost2 > 0:
			logs.append("%s's Innards Out hurt %s (-%d HP)!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon"), lost2])
	if a_ab == "Magician" and str(attacker.get("item", "")) == "" and str(defender.get("item", "")) != "" and not _sticky_hold_blocks(defender):
		if _move_cat(move) != "Status" and _move_id(move) != "fling":
			var stolen: String = str(defender.get("item", ""))
			defender["item"] = ""
			attacker["item"] = stolen
			logs.append("%s's Magician stole %s's %s!" % [attacker.get("name", "Pokémon"), defender.get("name", "Pokémon"), stolen])
	if d_ab == "Illusion" and bool(defender.get("illusion_active", false)):
		defender["illusion_active"] = false
		logs.append("%s's Illusion wore off!" % defender.get("name", "Pokémon"))


## True when this mon's Sticky Hold stops its item being taken.
## Same rule as the dispatcher blocks_take_item: the holder has HP,
## holds an item, and the item is not a Sticky Barb.
static func _sticky_hold_blocks(mon: Dictionary) -> bool:
	if str(mon.get("ability", "")) != "Sticky Hold":
		return false
	if int(mon.get("hp", 0)) <= 0:
		return false
	var item: String = str(mon.get("item", ""))
	if item == "":
		return false
	return _norm(item) != "stickybarb"


## Speed multipliers for abilities in this batch. None of the 70
## changes Speed through this hook: Chlorophyll, Swift Swim, Sand
## Rush and Slush Rush are owned by TurnResolver and are not in
## this batch anyway. Always 1.0.
static func speed_mult(mon: Dictionary, field: Dictionary) -> float:
	return 1.0


## True when an ability blocks a status outright. Flower Veil
## protects a Grass-type holder from status inflicted by others
## (the ally half needs side info the hook does not get). Leaf Guard
## blocks every status while the Sun is up (Showdown onSetStatus:
## return false in sun; it also blocks Yawn and makes Rest fail in
## sun, but this engine has no Yawn volatile and no working Rest
## move, so those two are not built).
static func blocks_status(mon: Dictionary, status: String, field: Dictionary = {}, source: Dictionary = {}) -> bool:
	var ab: String = str(mon.get("ability", ""))
	if ab == "Flower Veil" and _has_type(mon, "grass"):
		return true
	if ab == "Leaf Guard":
		var w: String = str(field.get("weather", "none")).to_lower()
		if w == "sun" or w == "sunnyday" or w == "intensesun" or w == "desolateland":
			return true
	return false

## True when an ability blocks indirect (non-move) damage on this
## mon. Showdown Magic Guard onDamage: effect.effectType !== "Move"
## is blocked. The controller guards the Life Orb call sites, and
## StatusAndFieldEngine guards end-of-turn damage and entry hazards
## (see S-6). Move recoil and confusion self-hit are Move effects
## and are NOT blocked.
static func blocks_indirect_damage(mon: Dictionary) -> bool:
	return str(mon.get("ability", "")) == "Magic Guard"


## Run before a move is used. Mold Breaker marks the move and the
## attacker so later hooks ignore the defender's ability.
## Mycelium Might does the same for Status moves. Long Reach
## removes contact from the move. Infiltrator marks the move so it
## ignores substitutes and screens. Gorilla Tactics locks the
## attacker to its first move and blocks any other move (except
## Struggle). Gulp Missile changes Cramorant to Gulping Form when
## it has more than 1/2 HP, or Gorging Form at 1/2 or less, when it
## uses Surf. Good as Gold blocks Status moves aimed at the holder.
## Magic Bounce blocks reflectable Status moves aimed at the holder
## and marks the move as bounced, so the controller can use it
## against the original user instead. Returns {} normally.
static func before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	var a_ab: String = str(attacker.get("ability", ""))
	var d_ab: String = str(defender.get("ability", ""))
	var a_name: String = str(attacker.get("name", "Pokémon"))
	var d_name: String = str(defender.get("name", "Pokémon"))
	if a_ab == "Mold Breaker":
		move["ignore_ability"] = true
		attacker["ignore_ability"] = true
	if a_ab == "Mycelium Might" and _move_cat(move) == "Status":
		move["ignore_ability"] = true
	if a_ab == "Long Reach":
		var flags: Dictionary = move.get("flags", {})
		flags["contact"] = false
		move["flags"] = flags
		move["contact"] = false
	if a_ab == "Infiltrator":
		move["infiltrates"] = true
	if a_ab == "Gorilla Tactics":
		var move_key: String = _move_id(move)
		var lock: String = str(attacker.get("gorilla_lock", ""))
		if lock == "":
			attacker["gorilla_lock"] = move_key
		elif lock != move_key and move_key != "struggle":
			logs.append("%s can't use %s because of Gorilla Tactics!" % [a_name, str(move.get("name", "that move"))])
			return {"skip": true}
	if a_ab == "Gulp Missile" and _move_id(move) == "surf" and _species_id(attacker) == "cramorant":
		var forme: String = "cramorant-gulping"
		var species_name: String = "Cramorant-Gulping"
		if int(attacker.get("hp", 0)) * 2 <= int(attacker.get("max_hp", 1)):
			forme = "cramorant-gorging"
			species_name = "Cramorant-Gorging"
		attacker["forme"] = forme
		attacker["species"] = species_name
		logs.append("%s's Gulp Missile changed its forme!" % a_name)
	if a_name != d_name and d_ab == "Good as Gold" and _move_cat(move) == "Status":
		logs.append("%s is immune to Status moves with Good as Gold!" % d_name)
		return {"skip": true}
	if a_name != d_name and d_ab == "Magic Bounce" and _move_cat(move) == "Status" and _flag(move, "reflectable"):
		move["bounced"] = true
		logs.append("%s bounced the move back with Magic Bounce!" % d_name)
		return {"skip": true}
	return {}


## Move power multipliers. Galvanize gives 1.2x to the Normal
## moves it turns Electric (the move_type hook marks them with
## move["type_changed_by"]). Mega Launcher gives 1.5x to pulse
## moves. Anything else is 1.0.
static func power_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Galvanize":
		if str(move.get("type_changed_by", "")) == "Galvanize" or _move_type(move).to_lower() == "normal":
			return 1.2
	if a_ab == "Mega Launcher" and _is_pulse(move):
		return 1.5
	return 1.0


## Accuracy multipliers. Hustle makes physical moves 0.8x
## accurate. Illuminate, Keen Eye and Mind's Eye ignore the
## target's evasiveness stages, but this hook gets no stages to
## work with, so it stays neutral for them (their accuracy-drop
## block lives in blocks_stat_change).
static func accuracy_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Hustle" and _move_cat(move) == "Physical":
		return 0.8
	return 1.0


## Extra critical hit stages. Merciless adds 5 stages when the
## target is poisoned or badly poisoned (Showdown onModifyCritRatio
## returns 5 for psn/tox; the calculator clamps 0-4, so stage 4 is
## a guaranteed crit). No other ability in this batch changes crit
## stage.
static func crit_stage(attacker: Dictionary, move: Dictionary, defender: Dictionary = {}) -> int:
	if str(attacker.get("ability", "")) == "Merciless":
		var st: String = str(defender.get("status", ""))
		if st == "PSN" or st == "TOX":
			return 5
	return 0


## Priority bonus. Gale Wings gives +1 to Flying moves at full
## HP. Mycelium Might's -0.1 fractional priority (last inside its
## own bracket) cannot be an int, so it stays 0 here and is named
## in the report.
static func priority_bonus(attacker: Dictionary, move: Dictionary) -> int:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Gale Wings" and _move_type(move).to_lower() == "flying":
		if int(attacker.get("hp", 0)) == int(attacker.get("max_hp", 1)):
			return 1
	return 0


## Fractional priority stub. Mycelium Might's -0.1 is NOT built here
## (out of scope for this spec); the dispatcher sums all three
## batches, so this must exist and return 0.0.
static func frac_priority(attacker: Dictionary, move: Dictionary) -> float:
	return 0.0


## Move type changes. Galvanize turns Normal moves Electric
## (except Judgment, Multi Attack, Natural Gift, Revelation Dance,
## Techno Blast, Terrain Pulse and Weather Ball) and marks the
## move so power_mult can give it 1.2x. Liquid Voice turns
## sound-based moves Water. "" means unchanged.
static func move_type(attacker: Dictionary, move: Dictionary, field: Dictionary) -> String:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Galvanize" and _move_type(move).to_lower() == "normal":
		var blocked: Array = ["judgment", "multiattack", "naturalgift", "revelationdance", "technoblast", "terrainpulse", "weatherball"]
		if not blocked.has(_move_id(move)):
			move["type_changed_by"] = "Galvanize"
			return "Electric"
	if a_ab == "Liquid Voice" and _is_sound(move):
		return "Water"
	return ""


## True when an ability blocks a stat stage change. Full Metal
## Body blocks any drop. Hyper Cutter blocks Attack drops.
## Illuminate, Keen Eye and Mind's Eye block accuracy drops.
## Guard Dog blocks Attack drops (its +1 Attack when Intimidate
## tries to drop it needs the Intimidate caller to know the source
## was Intimidate, which this hook does not get). Flower Veil
## blocks drops on a Grass-type holder (the ally half needs side
## info). Inner Focus blocks an Attack drop when the source mon's
## ability is Intimidate (Showdown onTryBoost deletes boost.atk
## when effect.name is Intimidate). Mirror Armor does not block
## here: it bounces the drop in try_mirror_armor instead (patch 15).
static func blocks_stat_change(mon: Dictionary, stat_key: String, amount: int, source: Dictionary = {}) -> bool:
	if amount >= 0:
		return false
	var ab: String = str(mon.get("ability", ""))
	var key: String = stat_key.to_lower()
	if ab == "Full Metal Body":
		return true
	if ab == "Hyper Cutter" and key == "atk":
		return true
	if (ab == "Illuminate" or ab == "Keen Eye" or ab == "Mind's Eye") and (key == "accuracy" or key == "acc"):
		return true
	if ab == "Guard Dog" and key == "atk":
		return true
	if ab == "Flower Veil" and _has_type(mon, "grass"):
		return true
	if ab == "Inner Focus" and key == "atk" and str(source.get("ability", "")) == "Intimidate":
		return true
	return false


## True when an ability stops this mon flinching. Showdown Inner
## Focus onTryAddVolatile flinch returns null.
static func blocks_flinch(mon: Dictionary) -> bool:
	return str(mon.get("ability", "")) == "Inner Focus"


## Bounce a foe-caused stat drop back onto the source. Showdown
## Mirror Armor onTryBoost: only negative stages bounce, per stat,
## respecting the holder's -6 floor. The source's own
## blocks_stat_change is checked by the dispatcher (AbilityEngine)
## before this runs - a batch file can only see its own batch, and
## Clear Body lives in Batch1 and White Smoke in Batch4 - so when
## the source blocks it the drop fizzles entirely and this function
## is never reached. Returns true when the drop was bounced (the
## caller must not apply it to the holder). The source is never
## passed through try_mirror_armor again, so there is no re-bounce.
## Callers only call this for foe-caused drops.
static func try_mirror_armor(mon: Dictionary, stat_key: String, amount: int, source: Dictionary, logs: Array) -> bool:
	if amount >= 0:
		return false
	if str(mon.get("ability", "")) != "Mirror Armor":
		return false
	if source.is_empty():
		return false
	var key: String = stat_key.to_lower()
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	if int(stages.get(key, 0)) <= -6:
		return false
	var s_stages: Dictionary = source.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var before: int = int(s_stages.get(key, 0))
	var after: int = clampi(before + amount, -6, 6)
	s_stages[key] = after
	source["stages"] = s_stages
	logs.append("%s's Mirror Armor bounced the %s drop back!" % [str(mon.get("name", "Pokémon")), key])
	return true


## Called after a stat stage is raised or lowered. No ability in
## this batch reacts to its own stat boost here (the Intimidate
## answers live in blocks_stat_change and the Intimidate caller;
## Mirror Armor bounces in try_mirror_armor). Kept as a no-op so
## the hook exists.
static func on_stat_boosted(mon: Dictionary, stat_key: String, amount: int, field: Dictionary, logs: Array) -> void:
	return


## True when an ability stops this mon being dragged out by a
## forced switch. Showdown Guard Dog cannot be forced to switch
## out (its +1 Attack on Intimidate is a separate gap - see its
## ABILITY_INFO note).
static func blocks_drag_out(mon: Dictionary, source: Dictionary = {}) -> bool:
	if str(mon.get("ability", "")) == "Guard Dog":
		return true
	return false


## True when the trapper stops the foe switching out. Magnet Pull
## traps Steel types that are not Ghost types and are not holding
## a Shed Shell. Adjacency in doubles is not checked here.
static func traps_foe(trapper: Dictionary, foe: Dictionary) -> bool:
	var t_ab: String = str(trapper.get("ability", ""))
	if t_ab == "Magnet Pull":
		if _has_type(foe, "steel") and not _has_type(foe, "ghost"):
			# Shed Shell escapes. Compare normalized: the raw
			# "shed-shell" check never matched the display name
			# "Shed Shell", so the escape was dead.
			if _norm(str(foe.get("item", ""))) != "shedshell":
				return true
	return false


## Effects when a Pokemon faints. Moxie raises the foe's Attack 1
## stage and Grim Neigh raises its Sp. Atk 1 stage when it knocks
## the other Pokemon out with a move. The controller passes
## by_move = false for a faint that was not caused by a move
## (confusion self-hit, recoil, poison), and then nothing boosts.
static func on_faint(fainted: Dictionary, foe: Dictionary, field: Dictionary, logs: Array, by_move: bool = true) -> void:
	if int(foe.get("hp", 0)) <= 0:
		return
	# Only a move KO boosts (Showdown onSourceAfterFaint needs the
	# KO effect to be a move). See Batch1 B1 for the full note.
	if not by_move:
		return
	var f_ab: String = str(foe.get("ability", ""))
	if f_ab == "Moxie":
		_raise_stage(foe, "atk", 1, logs)
		logs.append("%s's Moxie raised its Attack!" % foe.get("name", "Pokémon"))
	elif f_ab == "Grim Neigh":
		_raise_stage(foe, "spa", 1, logs)
		logs.append("%s's Grim Neigh raised its Sp. Atk!" % foe.get("name", "Pokémon"))


## Damage multiplier for an ally's move, from the ally holder's
## ability. Friend Guard makes allies take 3/4 damage; the holder
## itself is not protected by its own Friend Guard. The holder is
## the DEFENDER's ally (the mon standing next to the mon being
## hit), not the attacker's ally — so this arm reads
## defender["ally"] itself. The passed ally is the attacker's ally,
## which is what Power Spot, Battery and Steely Spirit need. In
## singles the defender has no ally key, so Friend Guard cannot
## fire there, which matches Showdown.
static func ally_damage_mult(ally: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> float:
	var guard: Dictionary = defender.get("ally", {})
	if str(guard.get("ability", "")) == "Friend Guard":
		if str(defender.get("name", "")) != str(guard.get("name", "")):
			return 0.75
	return 1.0


## Terrain set on switch-in. "" means none.
static func terrain_on_switch_in(mon: Dictionary) -> String:
	var ab: String = str(mon.get("ability", ""))
	match ab:
		"Grassy Surge":
			return "grassy"
		"Misty Surge":
			return "misty"
		"Hadron Engine":
			return "electric"
	return ""


## Forme change for weather and forme abilities. Castform follows
## the weather (Sun, Rain, Snow, else base), unless it holds a
## Utility Umbrella in Sun or Rain. Cherrim becomes Sunshine Form
## in Sun (not with a Utility Umbrella) and base form otherwise.
## Eiscue-Noice regains its Ice Face in Snow. Morpeko is handled
## in end_of_turn, not here, so it does not flip twice. "" means
## no change (already in the right forme).
static func form_change(mon: Dictionary, field: Dictionary) -> String:
	var ab: String = str(mon.get("ability", ""))
	var sid: String = _species_id(mon)
	var current: String = _forme_id(mon)
	var weather: String = str(field.get("weather", "none"))
	var item: String = str(mon.get("item", ""))
	if ab == "Forecast" and (sid == "castform" or sid.begins_with("castform")):
		var target: String = "castform"
		if weather == "sun" and item != "utility-umbrella":
			target = "castform-sunny"
		elif weather == "rain" and item != "utility-umbrella":
			target = "castform-rainy"
		elif weather == "snow":
			target = "castform-snowy"
		if current != target:
			return target
		return ""
	if ab == "Flower Gift" and (sid == "cherrim" or sid == "cherrimsunshine"):
		var target2: String = "cherrim"
		if weather == "sun" and item != "utility-umbrella":
			target2 = "cherrim-sunshine"
		if current != target2:
			return target2
		return ""
	if ab == "Ice Face" and sid == "eiscuenoice" and weather == "snow":
		if current != "eiscue":
			return "eiscue"
		return ""
	return ""


## Weight multiplier. Heavy Metal doubles weight, Light Metal
## halves it.
static func weight_mult(mon: Dictionary) -> float:
	var ab: String = str(mon.get("ability", ""))
	if ab == "Heavy Metal":
		return 2.0
	if ab == "Light Metal":
		return 0.5
	return 1.0


## Called when the mon uses an item. No ability in this batch
## reacts to item use directly: Gluttony only changes the Berry
## HP threshold (the item engine reads mon["gluttony"], set on
## switch-in), Harvest restores Berries at end of turn, and
## Magician steals items on hitting. Kept as a no-op.
static func on_item_use(mon: Dictionary, item_id: String, field: Dictionary, logs: Array, ally: Dictionary = {}) -> void:
	return
