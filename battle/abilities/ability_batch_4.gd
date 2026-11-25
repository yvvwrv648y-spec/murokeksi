class_name AbilityBatch4
extends RefCounted
## Ability batch 4 for Pokemon Ultimate World, battle engine v3.
## 70 abilities, Slush Rush through asone, alphabetical by name.
## Every mechanic comes from the real Showdown data in
## ~/workspace/puw_rc1/abilities.ts (asoneglastrier / asonespectrier
## for As One). Nothing is invented. Helpers _raise_stage,
## _is_contact, _lose_fraction_hp and _heal_fraction_hp are copied
## from the v2 AbilityEngine.
##
## How the hooks are used (merger contract, read this first):
## - is_immune is called ONCE per attempted hit, after the accuracy
##   check, exactly like the v2 battle_controller does. That is why
##   the absorb heals and stat boosts live in is_immune as a side
##   effect: Volt Absorb / Water Absorb heal 1/4 max HP, Storm Drain
##   raises Sp. Atk by 1, Well-Baked Body raises Defense by 2. The
##   v2 controller returns early on immunity and never calls
##   on_damage_taken for an immune hit, so putting the heal in
##   on_damage_taken would never run. Do not call is_immune twice
##   for one hit or the heal / boost would fire twice.
## - Mold Breaker, Teravolt and Turboblaze ignore defender
##   abilities: is_immune returns false when the attacker has one.
## - Stat-stage boosts (Steelworker, Swarm, Torrent, Transistor,
##   Solar Power, Toxic Boost, Stakeout, Supreme Overlord, Water
##   Bubble, Tough Claws, Strong Jaw) are applied as power_mult
##   because this batch has no stat-modifier hook. A 1.5x Attack or
##   Sp. Atk stage boost is the same size as a 1.5x power boost in
##   the damage formula, so the number is right; the name of the
##   step is an approximation, and it is noted in the report.
##   Thick Fat and the Fire half of Water Bubble halve the
##   attacker's offensive stat; damage_mult applies 0.5x instead,
##   same size, same note. The Ruin auras lower a stat by 0.75x;
##   damage_mult applies 0.75x (Tablets / Vessel) or 1/0.75x
##   (Sword of Ruin, because it lowers Defense).
## - Flags the caller must set or honour (same pattern as v2
##   mon["protean_used"] and mon["item_lost"]):
##   * defender["switched_in_this_turn"] = true on switch-in,
##     cleared each turn, for Stakeout.
##   * mon["flinched"] = true when the mon flinches, for Steadfast.
##   * mon["confused"] = true while confused, for Tangled Feet.
##   * mon["fallen_allies"] = fainted allies on the holder's side
##     (0-5), for Supreme Overlord.
##   * mon["ignore_def_stages"] / mon["ignore_atk_stages"], set by
##     before_move for Unaware; the damage calculator must ignore
##     the matching stat stages while they are set.
##   * mon["moves_last"] = true, set by before_move for Stall; the
##     turn resolver must order the mon last in its priority
##     bracket (priority_bonus returns int and cannot express
##     Stall's -0.1).
##   * defender["switch_flag"] = true, set by on_damage_taken for
##     Wimp Out; the caller performs the switch.
##   * mon["evasion_stage"] = -1, set by on_switch_in for
##     Supersweet Syrup; Batch4 accuracy_mult honours it (4/3x
##     accurate at -1), because the shared stage keys have no
##     evasion entry.

##   * field["ruin_sword"], field["ruin_tablets"],
##     field["ruin_vessel"], field["unnerve_active"]: set by
##     on_switch_in, cleared by on_faint when the holder faints.
##     on_switch_out has no field parameter, so the merger MUST
##     clear these four flags when the holder switches out.
##   * move["ignore_ability"] (Teravolt / Turboblaze),
##     move["ignores_protect"] (Unseen Fist),
##     move["ignores_redirection"] (Stalwart),
##     move["flinch_chance"] = 10 (Stench): set by before_move on
##     the move dict; roll_secondary rolls the flinch chance.

##   * mon["charged"] = true, set by on_damage_taken for Wind
##     Power; power_mult spends it on the next Electric move.
## - Slush Rush, Swift Swim and Surge Surfer are speed-only and are
##   owned by TurnResolver.effective_speed, as the brief orders.
##   They have no hook here and are still counted as covered.
## - Field words: field["weather"] is "sun" / "rain" / "sand" /
##   "snow" / "none"; field["terrain"] is "grassy" / "electric" /
##   "psychic" / "misty" / "none". Stage keys: atk / def / spa /
##   spd / spe. Status codes: BRN / PAR / PSN / TOX / SLP / FRZ / "".
##   mon["types"] is an Array of lowercase type names.
##   mon["species"] is the species name, mon["forme"] the forme
##   slug ("" means the base forme). mon["item"] is an item slug.
## - No hook exists in this batch for: losing an item to a foe
##   (Sticky Hold), being dragged out (Suction Cups), or getting a
##   status from a foe (Synchronize). Those three are named BLOCKED
##   in the report, with the exact missing piece. Symbiosis has
##   on_item_use with the ally parameter, and Telepathy has the
##   controller ally-damage check in _execute_move_doubles.
##   Nothing is faked for them.

## Abilities Trace may never copy (Showdown's notrace list, from
## the Trace entry in abilities.ts). "Embody Aspect" covers all
## four Ogerpon forms; "As One" covers both Calyrex forms.
const TRACE_BLOCKED: Array = [
	"As One", "Battle Bond", "Comatose", "Commander", "Disguise",
	"Embody Aspect", "Flower Gift", "Forecast", "Hunger Switch",
	"Ice Face", "Illusion", "Imposter", "Multitype",
	"Neutralizing Gas", "Poison Puppeteer", "Power Construct",
	"Power of Alchemy", "Protosynthesis", "Quark Drive", "Receiver",
	"RKS System", "Schooling", "Shields Down", "Stance Change",
	"Teraform Zero", "Tera Shell", "Tera Shift", "Trace",
	"Zen Mode", "Zero to Hero",
]

## Display name of a mon, for log lines.
static func _name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))


## Ability string of a mon ("" when it has none).
static func _ability(mon: Dictionary) -> String:
	return str(mon.get("ability", ""))


## Species name of a mon.
static func _species(mon: Dictionary) -> String:
	return str(mon.get("species", mon.get("name", "")))


## Forme slug of a mon ("" means the base forme).
static func _forme(mon: Dictionary) -> String:
	return str(mon.get("forme", ""))


## Move type, lowercased ("water", "fire", ...).
static func _mtype(move: Dictionary) -> String:
	return str(move.get("type", "")).to_lower()


## Move category, lowercased ("physical" / "special" / "status").
static func _mcat(move: Dictionary) -> String:
	var cat: String = str(move.get("cat", move.get("category", "")))
	return cat.to_lower()


## True when the move carries the named flag. moves.json marks
## these with flags.<name> (checked in the data: sound 33 moves,
## wind 17, bite 10, heal 36); RC1 move dicts may carry the flag
## as a top-level key instead.
static func _has_flag(move: Dictionary, flag: String) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get(flag, false)):
		return true
	return bool(move.get(flag, false))


## Item slug of a mon, normalised: lowercase, "-" and "_" removed,
## so "utility-umbrella", "utilityumbrella" and "Utility Umbrella"
## all compare equal to "utilityumbrella".
static func _item_id(mon: Dictionary) -> String:
	var raw: String = str(mon.get("item", ""))
	raw = raw.to_lower().replace("-", "").replace("_", "").replace(" ", "")
	return raw


## True when sun is up for Solar Power. Showdown checks sunnyday
## and desolateland; this engine also writes "sun" and "sunnyday".
static func _is_sun_weather(weather: String) -> bool:
	var w: String = weather.to_lower()
	return w == "sun" or w == "sunnyday" or w == "intensesun" or w == "desolateland"



## True when Trace may never copy this ability.
static func _is_trace_blocked(ab: String) -> bool:
	if ab == "":
		return true
	if ab in TRACE_BLOCKED:
		return true
	if ab.begins_with("Embody Aspect"):
		return true
	if ab.begins_with("As One"):
		return true
	return false


## Raise one stat stage by an amount, clamped between -6 and +6.
## (Copied from the v2 AbilityEngine.)
static func _raise_stage(mon: Dictionary, key: String, amount: int) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages[key] = clampi(int(stages.get(key, 0)) + amount, -6, 6)
	mon["stages"] = stages


## Current value of one stat stage (0 when the mon has no stages).
static func _stage(mon: Dictionary, key: String) -> int:
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	return int(stages.get(key, 0))


## Lose HP equal to a fraction of max HP, at least 1, never below 0.
## (Copied from the v2 AbilityEngine.)
static func _lose_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var loss: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = maxi(0, before - loss)
	return mini(loss, before)


## Heal HP by a fraction of max HP, never above max HP.
## (Copied from the v2 AbilityEngine.)
static func _heal_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var gain: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + gain)
	return int(mon.get("hp", 0)) - before


## True when this mon is a Terapagos in any forme.
static func _is_terapagos(mon: Dictionary) -> bool:
	return _species(mon).begins_with("Terapagos")


## The Zen Mode forme slug for a Darmanitan ("Darmanitan-Zen" or
## "Darmanitan-Galar-Zen"), or "" when the mon is not a Darmanitan.
static func _zen_forme(mon: Dictionary) -> String:
	var sp: String = _species(mon)
	if not sp.begins_with("Darmanitan"):
		return ""
	if sp.contains("Galar") or _forme(mon).contains("Galar"):
		return "Darmanitan-Galar-Zen"
	return "Darmanitan-Zen"


## The standard forme slug for a Darmanitan ("Darmanitan" or
## "Darmanitan-Galar"), or "" when the mon is not a Darmanitan.
static func _darmanitan_base_forme(mon: Dictionary) -> String:
	var sp: String = _species(mon)
	if not sp.begins_with("Darmanitan"):
		return ""
	if sp.contains("Galar") or _forme(mon).contains("Galar"):
		return "Darmanitan-Galar"
	return "Darmanitan"


## Switch-in effects. Supersweet Syrup lowers the foe's evasiveness
## 1 stage, once per battle. Supreme Overlord announces fallen
## allies. Tera Shift turns Terapagos into its Terastal Form.
## Trace copies the foe's Ability. The Ruin auras and Unnerve
## (including As One's Unnerve half) set field flags. Teravolt and
## Turboblaze announce themselves. Zero to Hero announces Hero
## Form. Truant starts fresh (first move works).
static func on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	var ab: String = _ability(mon)
	var mon_name: String = _name(mon)
	match ab:
		"Truant":
			mon["truant_skip"] = false
		"Teravolt", "Turboblaze":
			logs.append("%s's %s ignores the foe's Ability!" % [mon_name, ab])
		"Tera Shift":
			if _is_terapagos(mon) and _forme(mon) != "Terapagos-Terastal":
				mon["forme"] = "Terapagos-Terastal"
				logs.append("%s's Tera Shift changed it to Terastal Form!" % mon_name)
		"Zero to Hero":
			if _forme(mon) == "Palafin-Hero":
				logs.append("%s's Zero to Hero put it in Hero Form!" % mon_name)
		"Supersweet Syrup":
			if not bool(mon.get("syrup_triggered", false)):
				mon["syrup_triggered"] = true
				if not foe.is_empty():
					foe["evasion_stage"] = -1
					logs.append("%s's Supersweet Syrup lowered %s's evasiveness!" % [mon_name, _name(foe)])
		"Supreme Overlord":
			var fallen: int = mini(5, int(mon.get("fallen_allies", 0)))
			if fallen > 0:
				logs.append("%s's Supreme Overlord powers up for %d fallen allies!" % [mon_name, fallen])
		"Trace":
			if not foe.is_empty():
				var foe_ab: String = _ability(foe)
				if not _is_trace_blocked(foe_ab):
					mon["ability"] = foe_ab
					logs.append("%s's Trace copied %s's %s!" % [mon_name, _name(foe), foe_ab])
		"Sword of Ruin":
			field["ruin_sword"] = true
			logs.append("%s's Sword of Ruin weakens the foe's Defense!" % mon_name)
		"Tablets of Ruin":
			field["ruin_tablets"] = true
			logs.append("%s's Tablets of Ruin weakens the foe's Attack!" % mon_name)
		"Vessel of Ruin":
			field["ruin_vessel"] = true
			logs.append("%s's Vessel of Ruin weakens the foe's Sp. Atk!" % mon_name)
		"Unnerve", "asone", "As One", "As One (Glastrier)", "As One (Spectrier)":
			field["unnerve_active"] = true
			logs.append("%s's %s stops the foe eating Berries!" % [mon_name, ab])
	return logs


## Switch-out effects. Zero to Hero turns a Palafin in Zero Form
## into Hero Form when it leaves. This hook has no field
## parameter, so it cannot clear the Ruin / Unnerve field flags;
## the merger must clear field["ruin_sword"],
## field["ruin_tablets"], field["ruin_vessel"] and
## field["unnerve_active"] when the holder switches out (see the
## header). Fainting clears them in on_faint instead.
static func on_switch_out(mon: Dictionary) -> void:
	var ab: String = _ability(mon)
	if ab == "Zero to Hero" and _species(mon).begins_with("Palafin"):
		if _forme(mon) != "Palafin-Hero":
			mon["forme"] = "Palafin-Hero"

## Teraform Zero, at the true Showdown trigger (abilities.ts
## teraformzero onAfterTerastallization): when a Terapagos
## Terastallizes, the weather and terrain end, once per battle.
## Showdown only fires it for Terapagos (baseSpecies
## Terapagos-Stellar); this engine never sets the Terastal forme
## in terastallize(), so the check is the species name (the same
## _is_terapagos check Tera Shift uses) plus the ability. The
## controller only calls this right after a real
## Terastallization, so no tera check is needed here. The
## once-per-battle flag is set even when there is no weather or
## terrain to end: the trigger has passed, and weather or terrain
## set later in the battle must stay up.
static func on_terastallize(mon: Dictionary, field: Dictionary) -> Array:
	var out: Array = []
	if _ability(mon) != "Teraform Zero":
		return out
	if not _is_terapagos(mon):
		return out
	if bool(mon.get("teraform_zero_used", false)):
		return out
	mon["teraform_zero_used"] = true
	if str(field.get("weather", "none")) != "none" or str(field.get("terrain", "none")) != "none":
		field["weather"] = "none"
		field["weather_turns"] = 0
		field["terrain"] = "none"
		field["terrain_turns"] = 0
		out.append("%s's Teraform Zero ended the weather and terrain!" % _name(mon))
	return out

## Tailwind-start effects (Showdown abilities.ts
## onSideConditionStart, fired when Tailwind begins on the
## holder's side). Wind Power gains the Charge effect
## (mon["charged"], spent by power_mult on the next Electric
## move). Wind Rider raises Attack 1. Only one ability fires:
## a mon has exactly one ability. The Attack boost is skipped
## at +6 (a boost that cannot happen is not logged).
static func on_tailwind_start(mon: Dictionary, field: Dictionary) -> Array:
	var out: Array = []
	if int(mon.get("hp", 0)) <= 0:
		return out
	var ab: String = _ability(mon)
	var mon_name: String = _name(mon)
	if ab == "Wind Power":
		mon["charged"] = true
		out.append("%s's Wind Power gave it the Charge effect!" % mon_name)
	elif ab == "Wind Rider":
		if _stage(mon, "atk") < 6:
			_raise_stage(mon, "atk", 1)
			out.append("%s's Wind Rider raised its Attack!" % mon_name)
	return out

## Switch-in under an active Tailwind (Showdown abilities.ts
## windrider onStart: if Tailwind is already up on the holder's
## side when it starts, Attack rises 1). Wind Power has no
## onStart in Showdown, so it gets nothing here: switching in
## under an active Tailwind does NOT give it Charge. The
## controller only calls this when the side's Tailwind is up,
## so no field check is needed here.
static func on_tailwind_switch_in(mon: Dictionary, field: Dictionary) -> Array:
	var out: Array = []
	if int(mon.get("hp", 0)) <= 0:
		return out
	if _ability(mon) == "Wind Rider" and _stage(mon, "atk") < 6:
		_raise_stage(mon, "atk", 1)
		out.append("%s's Wind Rider raised its Attack!" % _name(mon))
	return out



## True when the defender's Ability blocks the move outright.
## Called ONCE per attempted hit, after the accuracy check, so the
## absorb heal and stat boosts below fire exactly once per hit;
## do not call it twice for one hit (see the header). Mold
## Breaker, Teravolt and Turboblaze ignore defender Abilities.
## Soundproof and Wind Rider are not here: they need the move's
## sound / wind flag, which this signature does not carry, so
## before_move blocks those moves instead.
static func is_immune(defender: Dictionary, move_type: String, attacker_ability: String, effectiveness: float = 1.0) -> bool:
	if attacker_ability == "Mold Breaker" or attacker_ability == "Teravolt" or attacker_ability == "Turboblaze":
		return false
	var ab: String = _ability(defender)
	var t: String = move_type.to_lower()
	match ab:
		"Volt Absorb":
			if t == "electric":
				_heal_fraction_hp(defender, 1, 4)
				return true
		"Water Absorb":
			if t == "water":
				_heal_fraction_hp(defender, 1, 4)
				return true
		"Storm Drain":
			if t == "water":
				_raise_stage(defender, "spa", 1)
				return true
		"Well-Baked Body":
			if t == "fire":
				_raise_stage(defender, "def", 2)
				return true
	return false


## Damage multiplier for defender-side and field-aura effects.
## Solid Rock: 0.75x on supereffective hits. Tera Shell: a full-HP
## Terapagos takes every non-immune hit at 0.5x effectiveness, so
## the multiplier is 0.5 / effectiveness. Thick Fat and the Fire
## half of Water Bubble halve the attacker's offensive stat, applied
## here as 0.5x damage (same size, see the header). The Ruin auras
## read the field flags set by on_switch_in: Tablets of Ruin and
## Vessel of Ruin lower the attacker's Attack / Sp. Atk by 0.75x,
## Sword of Ruin lowers the defender's Defense by 0.75x, which
## raises damage by 1/0.75x. The field flags live on
## mon["field"] when the caller stored the shared field there (the
## v2 controller does), else on the plain field dict passed here
## through the mon.
static func damage_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> float:
	var mult: float = 1.0
	var d_ab: String = _ability(defender)
	var a_ab: String = _ability(attacker)
	var t: String = _mtype(move)
	var cat: String = _mcat(move)
	match d_ab:
		"Solid Rock":
			if effectiveness > 1.0:
				mult *= 0.75
		"Tera Shell":
			if _is_terapagos(defender) and int(defender.get("hp", 0)) == int(defender.get("max_hp", 1)) and effectiveness > 0.0:
				mult *= 0.5 / effectiveness
		"Thick Fat":
			if t == "fire" or t == "ice":
				mult *= 0.5
		"Water Bubble":
			if t == "fire":
				mult *= 0.5
	var f: Dictionary = {}
	if attacker.has("field"):
		f = attacker["field"]
	elif defender.has("field"):
		f = defender["field"]
	if bool(f.get("ruin_sword", false)) and d_ab != "Sword of Ruin" and cat == "physical":
		mult *= 1.0 / 0.75
	if bool(f.get("ruin_tablets", false)) and a_ab != "Tablets of Ruin" and cat == "physical":
		mult *= 0.75
	if bool(f.get("ruin_vessel", false)) and a_ab != "Vessel of Ruin" and cat == "special":
		mult *= 0.75
	return mult


## End of turn effects. Solar Power loses 1/8 max HP in sun
## (Utility Umbrella blocks it). Thermal Exchange and Water Bubble
## cure a burn. Zen Mode changes a Darmanitan's forme at the
## 1/2 HP line.
static func end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var ab: String = _ability(mon)
	var weather: String = str(field.get("weather", "none"))
	var mon_name: String = _name(mon)
	match ab:
		"Solar Power":
			if _is_sun_weather(weather) and _item_id(mon) != "utilityumbrella":

				var lost: int = _lose_fraction_hp(mon, 1, 8)
				if lost > 0:
					logs.append("%s was hurt by Solar Power (-%d HP)!" % [mon_name, lost])
		"Thermal Exchange", "Water Bubble":
			if str(mon.get("status", "")) == "BRN":
				mon["status"] = ""
				logs.append("%s's %s cured its burn!" % [mon_name, ab])
		"Zen Mode":
			var zen: String = _zen_forme(mon)
			if zen != "":
				var max_hp: int = int(mon.get("max_hp", 1))
				var cur: String = _forme(mon)
				if cur == "":
					cur = _species(mon)
				if int(mon.get("hp", 0)) <= max_hp / 2 and cur != zen:
					mon["forme"] = zen
					logs.append("%s's Zen Mode changed it to Zen Mode!" % mon_name)
				elif int(mon.get("hp", 0)) > max_hp / 2 and cur == zen:
					mon["forme"] = _darmanitan_base_forme(mon)
					logs.append("%s's Zen Mode changed it back to Standard Mode!" % mon_name)

## Effects when the defender is hit by a damaging move. Stamina
## raises Defense 1. Steam Engine raises Speed 6 on a Fire or
## Water hit. Tangling Hair lowers the attacker's Speed 1 on
## contact. Thermal Exchange raises Attack 1 on a Fire hit. Water
## Compaction raises Defense 2 on a Water hit. Weak Armor lowers
## Defense 1 and raises Speed 2 on a physical hit. Spicy Spray
## burns the attacker. Toxic Debris sets Toxic Spikes on the
## attacker's side (one layer, max two; the layer count is kept on
## the shared field dict when the caller stored it on the
## attacker, else on the attacker dict as "toxic_spikes_layers").
## Wimp Out flags a switch when damage drops the mon from above
## 1/2 to 1/2 or less of max HP. Wind Power gains the Charge
## effect on a wind hit. Toxic Chain (on the attacker) badly
## poisons the target 30% of the time; Shield Dust and Covert
## Cloak block it. Absorb heals and boosts (Volt Absorb, Water
## Absorb, Storm Drain, Well-Baked Body) are NOT here: they fire
## in is_immune, because an immune hit never reaches this hook.
static func on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var d_ab: String = _ability(defender)
	var a_ab: String = _ability(attacker)
	var t: String = _mtype(move)
	var cat: String = _mcat(move)
	var contact: bool = _is_contact(move)
	var d_name: String = _name(defender)
	var a_name: String = _name(attacker)
	match d_ab:
		"Stamina":
			_raise_stage(defender, "def", 1)
			logs.append("%s's Stamina raised its Defense!" % d_name)
		"Steam Engine":
			if t == "fire" or t == "water":
				_raise_stage(defender, "spe", 6)
				logs.append("%s's Steam Engine raised its Speed sharply!" % d_name)
		"Tangling Hair":
			if contact:
				_raise_stage(attacker, "spe", -1)
				logs.append("%s's Tangling Hair lowered %s's Speed!" % [d_name, a_name])
		"Thermal Exchange":
			if t == "fire":
				_raise_stage(defender, "atk", 1)
				logs.append("%s's Thermal Exchange raised its Attack!" % d_name)
		"Water Compaction":
			if t == "water":
				_raise_stage(defender, "def", 2)
				logs.append("%s's Water Compaction raised its Defense sharply!" % d_name)
		"Weak Armor":
			if cat == "physical":
				_raise_stage(defender, "def", -1)
				_raise_stage(defender, "spe", 2)
				logs.append("%s's Weak Armor lowered its Defense and raised its Speed!" % d_name)
		"Spicy Spray":
			if str(attacker.get("status", "")) == "":
				attacker["status"] = "BRN"
				logs.append("%s was burned by %s's Spicy Spray!" % [a_name, d_name])
		"Toxic Debris":
			# Showdown onDamagingHit: any physical hit (contact is
			# not needed) sets one layer of Toxic Spikes, max 2, on
			# the attacker's side. When the attacker hit its own
			# ally, the spikes go on the other side instead.
			# The layers live in the side hazards of the shared
			# field dict, so the hazard system can read them later.
			if cat == "physical":
				var f: Dictionary = {}
				if attacker.has("field"):
					f = attacker["field"]
				if not f.is_empty():
					var atk_side: String = str(attacker.get("side", "player"))
					if bool(attacker.get("hit_ally", false)):
						atk_side = "enemy" if atk_side == "player" else "player"
					var hz_key: String = "player_hazards" if atk_side == "player" else "enemy_hazards"
					var hazards: Dictionary = {}
					if f.has(hz_key):
						hazards = f[hz_key]
					else:
						f[hz_key] = hazards
					var old_layers: int = int(hazards.get("toxic_spikes", 0))
					if old_layers < 2:
						hazards["toxic_spikes"] = old_layers + 1
						logs.append("%s's Toxic Debris set Toxic Spikes on the foe's side!" % d_name)
				else:
					var layers2: int = mini(2, int(attacker.get("toxic_spikes_layers", 0)) + 1)
					attacker["toxic_spikes_layers"] = layers2
					logs.append("%s's Toxic Debris set Toxic Spikes on the foe's side!" % d_name)
		"Wimp Out":
			var max_hp: int = int(defender.get("max_hp", 1))
			var before_hp: int = int(defender.get("hp", 0)) + damage
			if before_hp > max_hp / 2 and int(defender.get("hp", 0)) <= max_hp / 2 and int(defender.get("hp", 0)) > 0:
				defender["switch_flag"] = true
				logs.append("%s's Wimp Out makes it switch out!" % d_name)
		"Wind Power":
			if _has_flag(move, "wind"):
				defender["charged"] = true
				logs.append("%s's Wind Power gave it the Charge effect!" % d_name)
	if a_ab == "Toxic Chain":
		if str(defender.get("status", "")) == "" and _item_id(defender) != "covertcloak" and _ability(defender) != "Shield Dust":
			if randf() < 0.30:
				defender["status"] = "TOX"
				logs.append("%s was badly poisoned by %s's Toxic Chain!" % [d_name, a_name])


## True when the move makes contact. moves.json marks this with
## flags.contact; RC1 move dicts may carry "contact": true.
## (Copied from the v2 AbilityEngine.)
static func _is_contact(move: Dictionary) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get("contact", false)):
		return true
	return bool(move.get("contact", false))


## True when an ability blocks a status outright. Thermal Exchange
## and Water Bubble block burns; Sweet Veil blocks sleep for the
## holder itself (its allies need doubles support, which this
## signature cannot see, so that half is noted in the report).
static func blocks_status(mon: Dictionary, status: String, field: Dictionary = {}, source: Dictionary = {}) -> bool:
	var ab: String = _ability(mon)
	var st: String = status.to_upper()
	match ab:
		"Thermal Exchange", "Water Bubble":
			return st == "BRN"
		"Sweet Veil":
			return st == "SLP"
	# Sweet Veil ally half (Showdown onAllySetStatus): in
	# doubles, a mon cannot fall asleep when its ally has Sweet
	# Veil. The ally is mon["ally"], set by the controller in
	# doubles; in singles it is empty, so nothing changes there.
	# Only sleep is blocked, never any other status.
	if st == "SLP":
		var sv_ally: Dictionary = mon.get("ally", {})
		if str(sv_ally.get("ability", "")) == "Sweet Veil":
			return true
	return false



## What status Synchronize passes back, or "" when it does not
## fire. Showdown onAfterSetStatus: only when the source exists
## and is not the holder, the status is not SLP or FRZ, and the
## cause was not Toxic Spikes (there is no Toxic Spikes status path
## in this engine, so that arm cannot fire). The dispatcher does
## the pass-back through try_set_status, so this only answers.
## The target/source comparison is a Dictionary value comparison;
## byte-identical twin mons compare equal, which is vanishingly
## rare, and every real call site passes a genuinely different
## source.
static func synchronize_pass_back(target: Dictionary, source: Dictionary, status: String) -> String:
	if _ability(target) != "Synchronize":
		return ""
	if source.is_empty():
		return ""
	if target == source:
		return ""
	var st: String = status.to_upper()
	if st == "BRN" or st == "PAR" or st == "PSN" or st == "TOX":
		return st
	return ""


## Run before a move is used. Truant skips every other turn.
## Stance Change changes an Aegislash to Blade Forme before an
## attacking move and to Shield Forme before King's Shield.
## Teravolt and Turboblaze mark the move to ignore the defender's
## Ability. Unseen Fist marks a contact move to ignore protection.
## Stalwart marks the move so it cannot be redirected. Stench adds
## a 10% flinch chance to a damaging move that has none. Steadfast
## raises Speed 1 when the mon flinched (the caller sets
## mon["flinched"] = true when the flinch happens). Stall marks the
## mon to move last in its priority bracket. Unaware marks the
## stat stages the damage calculator must ignore. Soundproof
## blocks a sound move aimed at the holder, and Wind Rider blocks
## a wind move aimed at the holder while raising its Attack 1.
## Teraform Zero is not here: it fires at the moment of
## Terastallization, through on_terastallize, not before a move.
## Only a genuine block returns {"skip": true}.

static func before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	var a_ab: String = _ability(attacker)
	var d_ab: String = _ability(defender)
	var a_name: String = _name(attacker)
	var d_name: String = _name(defender)
	var cat: String = _mcat(move)
	attacker["ignore_atk_stages"] = false
	defender["ignore_def_stages"] = false
	if a_ab == "Truant":
		if bool(attacker.get("truant_skip", false)):
			attacker["truant_skip"] = false
			logs.append("%s can't move because of Truant!" % a_name)
			return {"skip": true}
		attacker["truant_skip"] = true
	match a_ab:
		"Stance Change":
			if _species(attacker).begins_with("Aegislash"):
				var move_id: String = str(move.get("id", "")).to_lower()
				var move_name: String = str(move.get("name", "")).to_lower()
				if move_id == "kingsshield" or move_name == "king's shield":
					if _forme(attacker) != "Aegislash":
						attacker["forme"] = "Aegislash"
						logs.append("%s's Stance Change changed it to Shield Forme!" % a_name)
				elif cat != "status":
					if _forme(attacker) != "Aegislash-Blade":
						attacker["forme"] = "Aegislash-Blade"
						logs.append("%s's Stance Change changed it to Blade Forme!" % a_name)
		"Teravolt", "Turboblaze":
			move["ignore_ability"] = true
		"Unseen Fist":
			if _is_contact(move):
				move["ignores_protect"] = true
		"Stalwart", "Propeller Tail":
			move["ignores_redirection"] = true
		"Stench":
			if cat != "status":
				var flinch: float = float(move.get("flinch_chance", 0))
				var sec: Dictionary = move.get("secondary", {})
				var secondary_flinches: bool = str(sec.get("volatileStatus", "")) == "flinch"
				if flinch <= 0.0 and not bool(move.get("has_flinch", false)) and not secondary_flinches:
					# flinch_chance is a percent in the RC1 data
					# (Air Slash 30), so Stench's 10% is 10, not 0.1.
					move["flinch_chance"] = 10

		# Steadfast moved to on_flinch (B10 below): before_move runs
		# before the mon tries to move, and the controller clears
		# the flinch flag before before_move ever runs, so the arm
		# here never fired.
		"Stall":
			attacker["moves_last"] = true
		"Unaware":
			defender["ignore_def_stages"] = true
		# Teraform Zero was here (before_move). Removed: it fires
		# at the moment of Terastallization through
		# on_terastallize, not on the next move. Keeping this arm
		# would clear weather set after the Terastallization,
		# which Showdown never does.

	if d_ab == "Unaware":
		attacker["ignore_atk_stages"] = true
	# A move that targets the user itself ("self") is never blocked
	# here: Showdown only blocks a sound / wind move when the
	# target is a different Pokemon than the user.
	if str(move.get("target", "")).to_lower() != "self":
		if d_ab == "Soundproof" and _has_flag(move, "sound"):
			logs.append("%s's Soundproof blocked the sound move!" % d_name)
			return {"skip": true}
		if d_ab == "Wind Rider" and _has_flag(move, "wind"):
			_raise_stage(defender, "atk", 1)
			logs.append("%s's Wind Rider blocked the wind move and raised its Attack!" % d_name)
			return {"skip": true}
	return {}

## Power multiplier for attacker-side offensive boosts. These are
## Showdown Attack / Sp. Atk stage boosts, applied here as power
## multipliers of the same size (see the header). Steelworker:
## 1.5x on Steel. Swarm and Torrent: 1.5x on Bug / Water at 1/3
## HP or less. Transistor: 1.3x on Electric. Toxic Boost: 1.5x on
## physical moves while poisoned. Water Bubble: 2x on Water.
## Solar Power: 1.5x on special moves in sun (Utility Umbrella
## blocks it). Strong Jaw: 1.5x on bite moves; Bug Bite has no
## bite flag in moves.json, so it is not boosted, as Showdown
## wants. Tough Claws: 1.3x on contact moves. Supreme Overlord:
## 1 + 0.1x per fainted ally, up to 5 (the caller keeps
## mon["fallen_allies"]). Stakeout: 2x against a foe that switched
## in this turn (the caller sets defender
## ["switched_in_this_turn"]). Wind Power's Charge: 2x on the
## next Electric move, and the Charge is spent here.
static func power_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var mult: float = 1.0
	var ab: String = _ability(attacker)
	var t: String = _mtype(move)
	var cat: String = _mcat(move)
	var hp: int = int(attacker.get("hp", 0))
	var max_hp: int = int(attacker.get("max_hp", 1))
	match ab:
		"Steelworker":
			if t == "steel":
				mult *= 1.5
		"Swarm":
			if t == "bug" and hp <= max_hp / 3:
				mult *= 1.5
		"Torrent":
			if t == "water" and hp <= max_hp / 3:
				mult *= 1.5
		"Transistor":
			if t == "electric":
				mult *= 1.3
		"Toxic Boost":
			var st: String = str(attacker.get("status", ""))
			if (st == "PSN" or st == "TOX") and cat == "physical":
				mult *= 1.5
		"Water Bubble":
			if t == "water":
				mult *= 2.0
		"Solar Power":
			if cat == "special" and _is_sun_weather(str(field.get("weather", "none"))) and _item_id(attacker) != "utilityumbrella":

				mult *= 1.5
		"Strong Jaw":
			if _has_flag(move, "bite"):
				mult *= 1.5
		"Tough Claws":
			if _is_contact(move):
				mult *= 1.3
		"Supreme Overlord":
			var fallen: int = mini(5, int(attacker.get("fallen_allies", 0)))
			if fallen > 0:
				mult *= 1.0 + 0.1 * float(fallen)
		"Stakeout":
			if bool(defender.get("switched_in_this_turn", false)):
				mult *= 2.0
	if ab == "Wind Power" and bool(attacker.get("charged", false)) and t == "electric":
		attacker["charged"] = false
		mult *= 2.0
	return mult


## Accuracy multiplier for moves aimed at the defender, and for
## moves used by the attacker. Snow Cloak: 0.8x against the holder
## in snow. Tangled Feet: 0.5x against a confused holder (the
## caller sets mon["confused"]). Wonder Skin: a status move aimed
## at the holder is set to 50 accuracy, so the multiplier is
## 50 / the move's own accuracy (moves with no accuracy check are
## left alone). Victory Star: 1.1x on the holder's own moves.
static func accuracy_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var mult: float = 1.0
	var d_ab: String = _ability(defender)
	var a_ab: String = _ability(attacker)
	var weather: String = str(field.get("weather", "none"))
	match d_ab:
		"Snow Cloak":
			if weather == "snow":
				mult *= 0.8
		"Tangled Feet":
			if bool(defender.get("confused", false)):
				mult *= 0.5
		"Wonder Skin":
			if _mcat(move) == "status":
				var acc_v: Variant = move.get("accuracy", move.get("acc", 100))
				if acc_v is int or acc_v is float:
					var acc: float = float(acc_v)
					if acc > 0.0:
						mult *= 50.0 / acc
	if a_ab == "Victory Star":
		mult *= 1.1
	# Victory Star ally half (Showdown onAnyModifyAccuracy): in
	# doubles, a mon's moves are 1.1x accurate when its ally has
	# Victory Star. The ally's ability is attacker["ally_ability"],
	# set by the controller in doubles; in singles it is empty,
	# so nothing changes there. Kept as a second if on purpose:
	# each Victory Star holder fires its own boost in Showdown,
	# so two holders on one side give 1.1 x 1.1 = 1.21x.
	if str(attacker.get("ally_ability", "")) == "Victory Star":
		mult *= 1.1
	# Evasiveness stages on the defender (Supersweet Syrup sets
	# evasion_stage -1 on switch-in). Standard stage table: an
	# evasion stage of -1 means moves against the mon are 4/3x
	# accurate, +1 means 3/4x. The shared stage keys have no
	# evasion entry, so the stage lives on its own key.
	var evasion_stage: int = clampi(int(defender.get("evasion_stage", 0)), -6, 6)
	if evasion_stage >= 0:
		mult *= 3.0 / (3.0 + float(evasion_stage))
	else:
		mult *= (3.0 - float(evasion_stage)) / 3.0
	return mult




## Extra critical-hit stages. Super Luck raises the ratio 1 stage.
static func crit_stage(attacker: Dictionary, move: Dictionary, defender: Dictionary = {}) -> int:
	if _ability(attacker) == "Super Luck":
		return 1
	return 0


## True when an ability stops this mon being dragged out by a
## forced switch. Showdown Suction Cups onDragOut returns null.
## The source is the mon using the drag-out move; it is only
## used for future per-source rules and is ignored today.
static func blocks_drag_out(mon: Dictionary, source: Dictionary = {}) -> bool:
	if _ability(mon) == "Suction Cups":
		return true
	return false


## Extra move priority. Triage gives healing moves +3 priority.
## Stall cannot be expressed here: its -0.1 fractional priority
## is not an int, so before_move sets mon["moves_last"] instead.
static func priority_bonus(attacker: Dictionary, move: Dictionary) -> int:
	if _ability(attacker) == "Triage" and _has_flag(move, "heal"):
		return 3
	return 0


## Fractional priority stub. Stall's +0.1 is NOT built here (its
## before_move already sets mon["moves_last"] instead); the
## dispatcher sums all three batches, so this must exist and
## return 0.0.
static func frac_priority(attacker: Dictionary, move: Dictionary) -> float:
	return 0.0


## True when the ability blocks a stat-stage change. White Smoke
## blocks any lowering of the holder's stages. Showdown lets the
## holder lower its own stages (its own moves), and both callers
## already pass no source for self drops (_apply_stages passes
## source = {} and _apply_boosts passes is_self = true), so the
## block only runs for foe-caused drops.

static func blocks_stat_change(mon: Dictionary, stat_key: String, amount: int, source: Dictionary = {}) -> bool:
	if _ability(mon) == "White Smoke" and amount < 0:
		return true
	return false


## True when this mon's Sticky Hold stops its item being taken.
## Showdown onTakeItem: blocked when the mon has HP, its item is
## not a Sticky Barb, and either the source is a different mon or
## the move is Knock Off (Knock Off calls takeItem with no source,
## so source defaults to the holder). The source comparison is a
## Dictionary value comparison, so byte-identical twin mons compare
## equal - vanishingly rare, and every real call site passes a
## genuinely different source.
static func blocks_take_item(mon: Dictionary, source: Dictionary, move: Dictionary) -> bool:
	if _ability(mon) != "Sticky Hold":
		return false
	if int(mon.get("hp", 0)) <= 0:
		return false
	if _item_id(mon) == "":
		return false
	if _item_id(mon) == "stickybarb":
		return false
	if not source.is_empty() and mon != source:
		return true
	var move_id: String = str(move.get("id", move.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if move_id == "knockoff":
		return true
	return false


## Effects when a Pokemon faints. Soul-Heart raises the holder's
## Sp. Atk 1 when another Pokemon faints. As One raises Attack 1
## (Glastrier half) or Sp. Atk 1 (Spectrier half) when the holder
## KOs a foe with a move; the variant is picked from the Ability
## string when it names Glastrier or Spectrier, else from the
## species (Calyrex-Shadow is Spectrier, anything else is
## Glastrier). The caller should pass the holder as "foe" and the
## Flinch response. Steadfast raises the holder's Speed 1 stage
## when it flinches. This runs from AbilityEngine.on_flinch, called
## by the controller from the flinch branch after the move is done,
## so the mon still cannot move that turn. It does not live in
## before_move: the controller clears the flinch flag before
## before_move runs.
static func on_flinch(mon: Dictionary, logs: Array) -> void:
	if not bool(mon.get("flinched", false)):
		return
	if _ability(mon) == "Steadfast":
		_raise_stage(mon, "spe", 1)
		logs.append("%s's Steadfast raised its Speed!" % _name(mon))
## fainted mon as "fainted". A fainted Ruin or Unnerve holder
## clears its field flag here.
static func on_faint(fainted: Dictionary, foe: Dictionary, field: Dictionary, logs: Array, by_move: bool = true) -> void:
	var f_ab: String = _ability(fainted)
	match f_ab:
		"Sword of Ruin":
			field["ruin_sword"] = false
		"Tablets of Ruin":
			field["ruin_tablets"] = false
		"Vessel of Ruin":
			field["ruin_vessel"] = false
		"Unnerve", "asone", "As One", "As One (Glastrier)", "As One (Spectrier)":
			field["unnerve_active"] = false
	if int(foe.get("hp", 0)) <= 0:
		return
	# No name check here on purpose: when the holder itself faints
	# its HP is 0 and the check above already returns. Two different
	# Pokemon can share a species name, so comparing names would
	# wrongly skip a real faint.
	var foe_ab: String = _ability(foe)
	var foe_name: String = _name(foe)
	# Soul-Heart fires on any faint (Showdown onAnyFaint), so it
	# runs before the move-KO gate below.
	if foe_ab == "Soul-Heart":
		_raise_stage(foe, "spa", 1)
		logs.append("%s's Soul-Heart raised its Sp. Atk!" % foe_name)
		return
	# The rest only fire on a move KO (Showdown onSourceAfterFaint
	# needs the KO effect to be a move).
	if not by_move:
		return
	match foe_ab:
		# The ability string can also be the plain slug
		# ("asoneglastrier" / "asonespectrier"), so those match too.
		"asone", "As One", "As One (Glastrier)", "As One (Spectrier)", "asoneglastrier", "asonespectrier":
			# Spectrier when the ability string names it, or when
			# the species is Calyrex-Shadow (the species can be
			# stored lowercase, so compare lowercase). Anything
			# else is Glastrier.
			if foe_ab.to_lower().contains("spectrier") or str(foe.get("species", "")).to_lower().contains("shadow"):
				_raise_stage(foe, "spa", 1)
				logs.append("%s's As One raised its Sp. Atk!" % foe_name)
			else:
				_raise_stage(foe, "atk", 1)
				logs.append("%s's As One raised its Attack!" % foe_name)


## Damage multiplier from an ally's Ability. Steely Spirit gives
## the holder's allies 1.5x power on Steel moves. The holder's own
## Steel moves are covered by power_mult; the caller must pass a
## DIFFERENT ally here, or the boost would count twice.
static func ally_damage_mult(ally: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> float:
	if _ability(ally) == "Steely Spirit" and _mtype(move) == "steel":
		return 1.5
	return 1.0


## Symbiosis (Showdown abilities.ts, onAllyAfterUseItem): when an
## ally uses its held item, this mon gives its own held item to
## that ally at once. Only the ally's use triggers it, never the
## holder's own use. The user must have an empty item slot (it
## just used its item) and the holder must have an item to give.
## Skipped when the user is about to switch out (Showdown's
## switchFlag check; this engine's flag is mon["force_switch"]).
## The giver is marked item_lost, so Unburden works for it (the
## v2 convention: the caller sets item_lost when the item goes).
## Not blocked by Sticky Hold: that ability has no take-item hook
## in this engine at all, so the transfer cannot check it. That
## is a known gap, said plainly.
static func on_item_use(mon: Dictionary, item_id: String, field: Dictionary, logs: Array, ally: Dictionary = {}) -> void:
	if ally.is_empty():
		return
	if str(ally.get("ability", "")) != "Symbiosis":
		return
	if bool(mon.get("force_switch", false)):
		return
	if str(mon.get("item", "")) != "":
		return
	var gift: String = str(ally.get("item", ""))
	if gift == "":
		return
	mon["item"] = gift
	ally["item"] = ""
	ally["item_lost"] = true
	logs.append("%s's Symbiosis gave its %s to %s!" % [str(ally.get("name", "Ally")), gift, str(mon.get("name", "Pokémon"))])


## Forme change on switch-in or at end of turn, as a slug for the
## caller to apply ("" means no change). Tera Shift turns a
## Terapagos into its Terastal Form. Zen Mode moves a Darmanitan
## across the 1/2 HP line. Stance Change is not here: it depends
## on the move being used, so before_move handles it.
static func form_change(mon: Dictionary, field: Dictionary) -> String:
	var ab: String = _ability(mon)
	match ab:
		"Tera Shift":
			if _is_terapagos(mon) and _forme(mon) != "Terapagos-Terastal":
				return "Terapagos-Terastal"
		"Zen Mode":
			var zen: String = _zen_forme(mon)
			if zen != "":
				var max_hp: int = int(mon.get("max_hp", 1))
				var cur: String = _forme(mon)
				if cur == "":
					cur = _species(mon)
				if int(mon.get("hp", 0)) <= max_hp / 2 and cur != zen:
					return zen
				if int(mon.get("hp", 0)) > max_hp / 2 and cur == zen:
					return _darmanitan_base_forme(mon)
	return ""
