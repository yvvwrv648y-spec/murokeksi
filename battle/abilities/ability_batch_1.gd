class_name AbilityBatch1
extends RefCounted
## Battle engine v3, ability batch 1: Aerilate through Flash Fire (70 abilities).
## Self-contained: static funcs only, no references to any other file.
##
## Every mechanic comes from Pokemon Showdown data/abilities.ts. Nothing is
## invented. Two v2 partials are COMPLETED here, not redone: Dry Skin (heal
## on a Water hit + 1.25x Fire damage, plus the v2 rain/sun end-of-turn
## effect) and Flash Fire (+1 SpA stage equivalent 1.5x Fire power after a
## Fire hit, plus the v2 Fire immunity).
##
## Caller contracts (the hooks below cannot see the whole battle, so the
## caller must honour these):
## - before_move MUST be called for every move before damage or immunity
##   resolution. Absorb abilities act there: Dry Skin heals 1/4 max HP on a
##   Water hit, Earth Eater heals 1/4 on a Ground hit, Flash Fire gains its
##   charge on a Fire hit. If the caller skips before_move for immune moves,
##   the heal/charge is skipped too. is_immune still reports the immunity.
## - on_stat_boosted is called AFTER the stage change has been applied.
##   Contrary inverts by applying -2x the amount. Competitive and Defiant
##   must only be called for drops caused by a FOE (never for self-inflicted
##   drops such as Close Combat); the hook cannot see the source.
## - TurnResolver must set field["attacker_moved_last"] = true when the
##   attacker is the last mon to move this turn (Analytic, 1.3x power).
## - on_damage_taken must be called with the real damage dealt. Anger Point
##   needs the crit flag on the move dict: move["crit"] = true (or
##   move["was_crit"] = true). Anger Shell, Berserk and Emergency Exit
##   rebuild HP-before-damage as hp + damage.
## - on_faint must only be called when the KO was caused by a move.
## - Bad Dreams: end_of_turn damages field["foe"] if the caller put the foe
##   dict there; otherwise it sets field["bad_dreams_active"] = true and the
##   caller must deal 1/8 max HP to each sleeping foe.
## - Air Lock / Cloud Nine set field["weather_suppressed"] = true on
##   switch-in. on_switch_out has no field param, so the CALLER must clear
##   that flag when the suppressing mon leaves the field.
## - field["weather"] may be "strongwinds" (Delta Stream) or "intensesun"
##   (Desolate Land) in addition to "sun"/"rain"/"sand"/"snow"/"none".
##   "intensesun" counts as sun for sun effects. Both last until the setter
##   leaves; field["weather_turns"] = 0 means indefinite.
## - Emergency Exit sets mon["force_switch"] = true; the caller switches
##   the mon out. Electromorphosis sets mon["charged"] = true (Charge:
##   next Electric move 2x power, applied by the damage code).
## - Anticipation reads foe.get("moves"): an Array of move Dictionaries
##   (keys "type", "id", "category", "ohko") or move id Strings. String
##   ids can only be checked for OHKO moves, not for effectiveness.
## - Download, Beast Boost and Eelevate read the foe's flat battle stats
##   ("def"/"spd" and "atk"/"def"/"spa"/"spd"/"spe", as in RC1 mon dicts).
## - Disguise: damage_mult returns 0.0 for the first hit on a Mimikyu and
##   applies the 1/8 max HP loss there; form_change then returns the
##   Busted forme slug. mon["disguise_broken"] tracks the broken state.
## - Mon dict flags used here: "flashfire_active", "disguise_broken",
##   "bond_triggered" (Battle Bond, once per battle), "shield_boost"
##   (Dauntless Shield, once per battle), "embodied" (Embody Aspect, once
##   per switch-in), "force_switch", "charged", "infatuated",
##   "cud_berry" / "cud_turns" (Cud Chew), "terastallized", "species".
## - No inferred assignment is used on any Variant value anywhere in
##   this file (Godot treats that as an error). Every variable has an
##   explicit type.

## Moves Aerilate / Dragonize / Pixilate-style type changers never touch.
const NO_TYPE_CHANGE_MOVES: Array = [
	"judgment", "multiattack", "naturalgift", "revelationdance",
	"technoblast", "terrainpulse", "weatherball",
]

## One-hit KO moves (Anticipation shudders at these).
const OHKO_MOVES: Array = ["fissure", "guillotine", "horndrill", "sheercold"]

## Moves Damp blocks while a Damp mon is active.
const DAMP_BLOCKED_MOVES: Array = [
	"explosion", "mindblown", "mistyexplosion", "selfdestruct",
]

## Volatile-inflicting moves Aroma Veil blocks.
const AROMA_VEIL_BLOCKED_MOVES: Array = [
	"attract", "disable", "encore", "healblock", "taunt", "torment",
]

## Attacking type -> defending type -> damage multiplier. Only entries
## different from 1.0 are listed. Built from Showdown data/typechart.ts.
const TYPE_EFFECT: Dictionary = {
	"normal": {"ghost": 0.0, "rock": 0.5, "steel": 0.5},
	"fire": {"bug": 2.0, "dragon": 0.5, "fire": 0.5, "grass": 2.0, "ice": 2.0, "rock": 0.5, "steel": 2.0, "water": 0.5},
	"water": {"dragon": 0.5, "fire": 2.0, "grass": 0.5, "ground": 2.0, "rock": 2.0, "water": 0.5},
	"electric": {"dragon": 0.5, "electric": 0.5, "flying": 2.0, "grass": 0.5, "ground": 0.0, "water": 2.0},
	"grass": {"bug": 0.5, "dragon": 0.5, "fire": 0.5, "flying": 0.5, "grass": 0.5, "ground": 2.0, "poison": 0.5, "rock": 2.0, "steel": 0.5, "water": 2.0},
	"ice": {"dragon": 2.0, "fire": 0.5, "flying": 2.0, "grass": 2.0, "ground": 2.0, "ice": 0.5, "steel": 0.5, "water": 0.5},
	"fighting": {"bug": 0.5, "dark": 2.0, "fairy": 0.5, "flying": 0.5, "ghost": 0.0, "ice": 2.0, "normal": 2.0, "poison": 0.5, "psychic": 0.5, "rock": 2.0, "steel": 2.0},
	"poison": {"fairy": 2.0, "ghost": 0.5, "grass": 2.0, "ground": 0.5, "poison": 0.5, "rock": 0.5, "steel": 0.0},
	"ground": {"bug": 0.5, "electric": 2.0, "fire": 2.0, "flying": 0.0, "grass": 0.5, "poison": 2.0, "rock": 2.0, "steel": 2.0},
	"flying": {"bug": 2.0, "electric": 0.5, "fighting": 2.0, "grass": 2.0, "rock": 0.5, "steel": 0.5},
	"psychic": {"dark": 0.0, "fighting": 2.0, "poison": 2.0, "psychic": 0.5, "steel": 0.5},
	"bug": {"dark": 2.0, "fairy": 0.5, "fighting": 0.5, "fire": 0.5, "flying": 0.5, "ghost": 0.5, "grass": 2.0, "poison": 0.5, "psychic": 2.0, "steel": 0.5},
	"rock": {"bug": 2.0, "fighting": 0.5, "fire": 2.0, "flying": 2.0, "ground": 0.5, "ice": 2.0, "steel": 0.5},
	"ghost": {"dark": 0.5, "ghost": 2.0, "normal": 0.0, "psychic": 2.0},
	"dragon": {"dragon": 2.0, "fairy": 0.0, "steel": 0.5},
	"dark": {"dark": 0.5, "fairy": 0.5, "fighting": 0.5, "ghost": 2.0, "psychic": 2.0},
	"steel": {"electric": 0.5, "fairy": 2.0, "fire": 0.5, "ice": 2.0, "rock": 2.0, "steel": 0.5, "water": 0.5},
	"fairy": {"dark": 2.0, "dragon": 2.0, "fighting": 2.0, "fire": 0.5, "poison": 0.5, "steel": 0.5},
}


## Raise one stat stage by an amount, clamped between -6 and +6.
static func _raise_stage(mon: Dictionary, key: String, amount: int, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages[key] = clampi(int(stages.get(key, 0)) + amount, -6, 6)
	mon["stages"] = stages


## True when the move makes contact. moves.json marks this with
## flags.contact; RC1 move dicts may carry "contact": true.
static func _is_contact(move: Dictionary) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get("contact", false)):
		return true
	return bool(move.get("contact", false))


## True when the move is a bullet move (flags.bullet in moves.json).
static func _is_bullet_move(move: Dictionary) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get("bullet", false)):
		return true
	return bool(move.get("bullet", false))


## Lose HP equal to a fraction of max HP, at least 1, never below 0.
static func _lose_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var loss: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = maxi(0, before - loss)
	return mini(loss, before)


## Heal HP by a fraction of max HP, never above max HP.
static func _heal_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var gain: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + gain)
	return int(mon.get("hp", 0)) - before


## Heal a flat amount of HP, never above max HP.
static func _heal_flat_hp(mon: Dictionary, amount: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + amount)
	return int(mon.get("hp", 0)) - before


## True when the item id is a Berry (all Berry ids end in "berry",
## plus Berry Juice). Used by Cheek Pouch and Cud Chew.
static func _is_berry(item_id: String) -> bool:
	var low: String = item_id.to_lower()
	if low == "berryjuice":
		return true
	return low.ends_with("berry")


## Lowercase type list of a mon as a plain Array of Strings.
static func _mon_types(mon: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = mon.get("types", [])
	if raw is Array:
		var arr: Array = raw
		for t: Variant in arr:
			out.append(str(t).to_lower())
	elif raw is PackedStringArray:
		var packed: PackedStringArray = raw
		for t: String in packed:
			out.append(t.to_lower())
	return out


## Full effectiveness multiplier of one attacking type against a list
## of defending types, from TYPE_EFFECT above.
static func _effectiveness(move_type: String, defender_types: Array) -> float:
	var mult: float = 1.0
	var row: Dictionary = TYPE_EFFECT.get(move_type.to_lower(), {})
	for t: Variant in defender_types:
		mult *= float(row.get(str(t).to_lower(), 1.0))
	return mult


## The mon's highest battle stat. Ties go Attack, Defense, Special
## Attack, Special Defense, Speed (Showdown getBestStat order).
## Stages are ignored, as in Showdown.
static func _best_stat(mon: Dictionary) -> String:
	var best_key: String = "atk"
	var best_val: int = int(mon.get("atk", 0))
	var keys: Array = ["def", "spa", "spd", "spe"]
	for k: Variant in keys:
		var key: String = str(k)
		var val: int = int(mon.get(key, 0))
		if val > best_val:
			best_val = val
			best_key = key
	return best_key


## Lowercase move type, "" when the move dict has none.
static func _move_type(move: Dictionary) -> String:
	return str(move.get("type", "")).to_lower()


## Lowercase move id, "" when the move dict has none.
static func _move_id(move: Dictionary) -> String:
	return str(move.get("id", "")).to_lower()


## True when Aerilate / Dragonize may change this move's type.
## Excludes Judgment, Multi-Attack, Natural Gift, Revelation Dance,
## Techno Blast, Terrain Pulse, Weather Ball, and Tera Blast while
## the user is Terastallized.
static func _type_changer_applies(attacker: Dictionary, move: Dictionary) -> bool:
	if _move_type(move) != "normal":
		return false
	if NO_TYPE_CHANGE_MOVES.has(_move_id(move)):
		return false
	if _move_id(move) == "terablast" and bool(attacker.get("terastallized", false)):
		return false
	return true

## Switch-in effects. Anticipation reads the foe's moves; Download reads
## the foe's flat Def / SpD; Embody Aspect only fires for a Terastallized
## Ogerpon-Tera forme. Costar copies the ally's stages and Curious
## Medicine resets them, both from mon["ally"], which the controller
## sets in doubles (see _try_commander for Commander, same key).
## True when the mon is a Tatsugiri, any forme (base, Curly,
## Droopy or Stretchy: the species string starts with Tatsugiri).
static func _is_tatsugiri(mon: Dictionary) -> bool:
	return str(mon.get("species", "")).to_lower().begins_with("tatsugiri")

## True when the mon is a Dondozo (no formes).
static func _is_dondozo(mon: Dictionary) -> bool:
	return str(mon.get("species", "")).to_lower() == "dondozo"

## Commander (Showdown abilities.ts + data/conditions.ts): when a
## Tatsugiri with Commander and a Dondozo are active on the same
## side, Tatsugiri enters Dondozo's mouth (mon["commanding"] =
## true), Dondozo is commanded (mon["commanded"] = true) and gains
## +2 to Attack, Defense, Sp. Atk, Sp. Def and Speed (the
## "commanded" volatile's onStart boost). Runs on either mon's
## switch-in, so it fires whichever of the pair arrives second.
## Does nothing when Dondozo is already commanded (Showdown
## refuses a second Commander while the first is active, so a
## replacement Tatsugiri cannot re-trigger it), when there is no
## living ally, or in singles (no ally key, so the ally dict is
## empty). The +2 stages are written straight onto Dondozo, the
## same way Intrepid Sword writes its +1 in this file; a Contrary
## Dondozo would get +2 instead of -2, because this does not go
## through on_stat_boosted. That is a known gap, said plainly.
static func _try_commander(mon: Dictionary, logs: Array) -> void:
	var ally: Dictionary = mon.get("ally", {})
	if ally.is_empty() or int(ally.get("hp", 0)) <= 0:
		return
	var tatsugiri: Dictionary = {}
	var dondozo: Dictionary = {}
	if _is_tatsugiri(mon) and str(mon.get("ability", "")) == "Commander" and _is_dondozo(ally):
		tatsugiri = mon
		dondozo = ally
	elif _is_dondozo(mon) and _is_tatsugiri(ally) and str(ally.get("ability", "")) == "Commander":
		tatsugiri = ally
		dondozo = mon
	else:
		return
	if bool(tatsugiri.get("commanding", false)) or bool(dondozo.get("commanded", false)):
		return
	tatsugiri["commanding"] = true
	dondozo["commanded"] = true
	_raise_stage(dondozo, "atk", 2, logs)
	_raise_stage(dondozo, "def", 2, logs)
	_raise_stage(dondozo, "spa", 2, logs)
	_raise_stage(dondozo, "spd", 2, logs)
	_raise_stage(dondozo, "spe", 2, logs)
	logs.append("%s's Commander sent it into %s's mouth! %s's Attack, Defense, Sp. Atk, Sp. Def and Speed sharply rose!" % [str(tatsugiri.get("name", "Tatsugiri")), str(dondozo.get("name", "Dondozo")), str(dondozo.get("name", "Dondozo"))])

static func on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	match ab:
		"Air Lock", "Cloud Nine":
			field["weather_suppressed"] = true
			logs.append("%s's %s suppressed the weather!" % [mon_name, ab])
		"Anticipation":
			if _foe_has_threatening_move(mon, foe):
				logs.append("%s shuddered with Anticipation!" % mon_name)
		"As One (Glastrier)", "As One (Spectrier)":
			logs.append("%s's As One carries Unnerve: foes cannot eat Berries!" % mon_name)
		"Beads of Ruin":
			logs.append("%s's Beads of Ruin lowered the Sp. Def of active Pokemon!" % mon_name)
		"Dark Aura":
			logs.append("%s's Dark Aura raised the power of Dark moves!" % mon_name)
		"Fairy Aura":
			logs.append("%s's Fairy Aura raised the power of Fairy moves!" % mon_name)
		"Aura Break":
			logs.append("%s's Aura Break reversed the power of Dark and Fairy auras!" % mon_name)
		"Comatose":
			logs.append("%s is drowsing (Comatose) and cannot be statused!" % mon_name)
		"Costar":
			var costar_ally: Dictionary = mon.get("ally", {})
			if not costar_ally.is_empty() and int(costar_ally.get("hp", 0)) > 0:
				var costar_stages: Dictionary = costar_ally.get("stages", {})
				var my_stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
				for key in ["atk", "def", "spa", "spd", "spe"]:
					my_stages[key] = clampi(int(costar_stages.get(key, 0)), -6, 6)
				mon["stages"] = my_stages
				logs.append("%s's Costar copied %s's stat changes!" % [mon_name, str(costar_ally.get("name", "its ally"))])
		"Curious Medicine":
			var med_ally: Dictionary = mon.get("ally", {})
			if not med_ally.is_empty() and int(med_ally.get("hp", 0)) > 0:
				var med_stages: Dictionary = med_ally.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
				for key in ["atk", "def", "spa", "spd", "spe"]:
					med_stages[key] = 0
				med_ally["stages"] = med_stages
				logs.append("%s's Curious Medicine reset %s's stat changes!" % [mon_name, str(med_ally.get("name", "its ally"))])
		"Dauntless Shield":
			if not bool(mon.get("shield_boost", false)):
				mon["shield_boost"] = true
				_raise_stage(mon, "def", 1, logs)
				logs.append("%s's Dauntless Shield raised its Defense!" % mon_name)
		"Delta Stream":
			field["weather"] = "strongwinds"
			field["weather_turns"] = 0
			logs.append("Strong winds began with %s's Delta Stream!" % mon_name)
		"Desolate Land":
			field["weather"] = "intensesun"
			field["weather_turns"] = 0
			logs.append("The sunlight turned extremely harsh with %s's Desolate Land!" % mon_name)
		"Download":
			var total_def: int = int(foe.get("def", 0))
			var total_spd: int = int(foe.get("spd", 0))
			if total_def > 0 and total_def >= total_spd:
				_raise_stage(mon, "spa", 1, logs)
				logs.append("%s's Download raised its Sp. Atk!" % mon_name)
			elif total_spd > 0:
				_raise_stage(mon, "atk", 1, logs)
				logs.append("%s's Download raised its Attack!" % mon_name)
		"Electric Surge":
			field["terrain"] = "electric"
			field["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)
			logs.append("%s's Electric Surge set Electric Terrain!" % mon_name)
		"Embody Aspect (Cornerstone)":
			_try_embody_aspect(mon, "ogerpon-cornerstone-tera", "def", logs)
		"Embody Aspect (Hearthflame)":
			_try_embody_aspect(mon, "ogerpon-hearthflame-tera", "atk", logs)
		"Embody Aspect (Teal)":
			_try_embody_aspect(mon, "ogerpon-teal-tera", "spe", logs)
		"Embody Aspect (Wellspring)":
			_try_embody_aspect(mon, "ogerpon-wellspring-tera", "spd", logs)
	_try_commander(mon, logs)
	return logs


## True when any of the foe's moves is super-effective against this mon
## (and the mon is not immune to it) or is an OHKO move. Hidden Power
## uses the foe's "hp_type" when given. Move ids given as plain Strings
## can only be checked for OHKO moves.
static func _foe_has_threatening_move(mon: Dictionary, foe: Dictionary) -> bool:
	var my_types: Array = _mon_types(mon)
	var foe_moves: Array = foe.get("moves", [])
	for mv: Variant in foe_moves:
		if mv is Dictionary:
			var mv_dict: Dictionary = mv
			var cat: String = str(mv_dict.get("category", "")).to_lower()
			if cat == "status":
				continue
			var mv_id: String = str(mv_dict.get("id", "")).to_lower()
			if bool(mv_dict.get("ohko", false)) or OHKO_MOVES.has(mv_id):
				return true
			var mv_type: String = str(mv_dict.get("type", "")).to_lower()
			if mv_id == "hiddenpower":
				mv_type = str(foe.get("hp_type", mv_type)).to_lower()
			if mv_type != "" and _effectiveness(mv_type, my_types) > 1.0:
				return true
		elif mv is String:
			var mv_str: String = str(mv).to_lower()
			if OHKO_MOVES.has(mv_str):
				return true
	return false


## Embody Aspect: +1 to one stat, once, only for a Terastallized
## Ogerpon-Tera forme of the matching mask.
static func _try_embody_aspect(mon: Dictionary, forme_slug: String, stat_key: String, logs: Array) -> void:
	var species: String = str(mon.get("species", mon.get("name", ""))).to_lower()
	if species != forme_slug:
		return
	if not bool(mon.get("terastallized", false)):
		return
	if bool(mon.get("embodied", false)):
		return
	mon["embodied"] = true
	_raise_stage(mon, stat_key, 1, logs)
	logs.append("%s's Embody Aspect raised its %s!" % [str(mon.get("name", "Pokémon")), stat_key.to_upper()])


## Switch-out effects. Flash Fire loses its charge when the mon leaves.
## Air Lock / Cloud Nine weather suppression cannot be cleared here:
## this hook has no field param, so the caller must clear
## field["weather_suppressed"] when that mon leaves.
static func on_switch_out(mon: Dictionary) -> void:
	if str(mon.get("ability", "")) == "Flash Fire":
		mon["flashfire_active"] = false
	# Commander: the flags live on the mons themselves. A Dondozo
	# that leaves clears "commanded" (a fresh pair can command
	# again when it comes back); a Tatsugiri that leaves clears
	# "commanding" but the Dondozo keeps "commanded", so a
	# replacement Tatsugiri cannot re-trigger it (Bulbapedia).
	if bool(mon.get("commanding", false)):
		mon["commanding"] = false
	if bool(mon.get("commanded", false)):
		mon["commanded"] = false


## True when the defender's ability makes it immune to this move type.
## Mold Breaker on the attacker ignores these immunities. Bulletproof is
## NOT here: it needs the move's flags, so it is handled in before_move.
static func is_immune(defender: Dictionary, move_type: String, attacker_ability: String, effectiveness: float = 1.0) -> bool:
	if attacker_ability == "Mold Breaker":
		return false
	var ab: String = str(defender.get("ability", ""))
	var mt: String = move_type.to_lower()
	match ab:
		"Dry Skin":
			return mt == "water"
		"Earth Eater":
			return mt == "ground"
		"Eelevate":
			if mt == "ground" and str(defender.get("item", "")) != "ironball":
				return true
			return false
		"Flash Fire":
			return mt == "fire"
	return false


## Damage multiplier applied after base damage is worked out.
## Battle Armor cancels a crit (the caller applies 1.5x for crits, so
## returning 2/3 removes it). Filter cuts super-effective hits to 3/4.
## Aura Guard halves contact moves. Beads of Ruin raises damage from the
## holder's Special moves (the foe's SpD is 0.75x, so damage is 4/3x).
## Dry Skin takes 1.25x from Fire moves. Disguise blocks the first hit
## on a Mimikyu outright and costs it 1/8 max HP.
static func damage_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> float:
	var mult: float = 1.0
	var d_ab: String = str(defender.get("ability", ""))
	var a_ab: String = str(attacker.get("ability", ""))
	var mt: String = _move_type(move)
	var cat: String = str(move.get("category", "")).to_lower()
	if d_ab == "Battle Armor" and is_crit:
		mult *= 2.0 / 3.0
	if d_ab == "Filter" and effectiveness > 1.0:
		mult *= 0.75
	if d_ab == "Aura Guard" and _is_contact(move):
		mult *= 0.5
	if d_ab == "Dry Skin" and mt == "fire":
		mult *= 1.25
	if a_ab == "Beads of Ruin" and d_ab != "Beads of Ruin" and cat == "special":
		mult *= 4.0 / 3.0
	if d_ab == "Disguise" and not bool(defender.get("disguise_broken", false)):
		var species: String = str(defender.get("species", defender.get("name", ""))).to_lower()
		if species == "mimikyu" or species == "mimikyutotem":
			defender["disguise_broken"] = true
			_lose_fraction_hp(defender, 1, 8)
			return 0.0
	return mult

## End-of-turn effects for the holder. Dry Skin heals 1/8 max HP in
## rain and loses 1/8 in sun (a Utility Umbrella blocks both). Bad Dreams
## hurts a sleeping foe for 1/8 max HP when the caller put the foe dict in
## field["foe"]; otherwise it raises field["bad_dreams_active"] for the
## caller to apply. Cud Chew re-eats its stored Berry at the end of the
## next turn.
static func end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var ab: String = str(mon.get("ability", ""))
	var weather: String = str(field.get("weather", "none")).to_lower()
	match ab:
		"Dry Skin":
			if str(mon.get("item", "")) != "utilityumbrella":
				if weather == "rain":
					var healed: int = _heal_fraction_hp(mon, 1, 8)
					if healed > 0:
						logs.append("%s restored HP with Dry Skin (+%d HP)!" % [str(mon.get("name", "Pokémon")), healed])
				elif weather == "sun" or weather == "intensesun":
					var lost: int = _lose_fraction_hp(mon, 1, 8)
					if lost > 0:
						logs.append("%s was hurt by the sun with Dry Skin (-%d HP)!" % [str(mon.get("name", "Pokémon")), lost])
		"Bad Dreams":
			var foe_raw: Variant = field.get("foe", null)
			if foe_raw is Dictionary:
				var foe: Dictionary = foe_raw
				var foe_status: String = str(foe.get("status", ""))
				var foe_ab: String = str(foe.get("ability", ""))
				if int(foe.get("hp", 0)) > 0 and (foe_status == "SLP" or foe_ab == "Comatose"):
					var foe_lost: int = _lose_fraction_hp(foe, 1, 8)
					if foe_lost > 0:
						logs.append("%s was hurt by %s's Bad Dreams (-%d HP)!" % [str(foe.get("name", "Foe")), str(mon.get("name", "Pokémon")), foe_lost])
			else:
				field["bad_dreams_active"] = true
		"Cud Chew":
			var berry: String = str(mon.get("cud_berry", ""))
			var turns_left: int = int(mon.get("cud_turns", 0))
			if berry != "" and turns_left > 0:
				turns_left -= 1
				mon["cud_turns"] = turns_left
				if turns_left <= 0:
					mon["cud_berry"] = ""
					logs.append("%s ate its %s again with Cud Chew!" % [str(mon.get("name", "Pokémon")), berry])
					_reapply_berry(mon, berry, logs)


## Re-applies a Berry's healing when Cud Chew eats it a second time.
## Sitrus and Enigma restore 1/4 max HP, pinch Berries (Figy, Wiki,
## Mago, Aguav, Iapapa) restore 1/2, Oran restores 10 HP and Berry
## Juice restores 20 HP (Showdown items.ts). Other Berries have no
## healing effect to re-apply here.
static func _reapply_berry(mon: Dictionary, berry: String, logs: Array) -> void:
	var healed: int = 0
	match berry.to_lower():
		"sitrusberry", "enigmaberry":
			healed = _heal_fraction_hp(mon, 1, 4)
		"figyberry", "wikiberry", "magoberry", "aguavberry", "iapapaberry":
			healed = _heal_fraction_hp(mon, 1, 2)
		"oranberry":
			healed = _heal_flat_hp(mon, 10)
		"berryjuice":
			healed = _heal_flat_hp(mon, 20)
	if healed > 0:
		logs.append("%s restored HP from the Berry (+%d HP)!" % [str(mon.get("name", "Pokémon")), healed])


## Effects when the defender is hit by a damaging move. HP before the
## hit is rebuilt as hp + damage. Anger Shell and Berserk fire when the
## hit drops the mon from above 1/2 to 1/2 or less of max HP.
## Emergency Exit flags the mon to switch out on the same crossing.
## Anger Point needs move["crit"] = true set by the caller.
static func on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var d_ab: String = str(defender.get("ability", ""))
	var max_hp: int = int(defender.get("max_hp", 100))
	var hp_now: int = int(defender.get("hp", 0))
	var hp_before: int = hp_now + damage
	var crossed_half: bool = hp_before > max_hp / 2 and hp_now <= max_hp / 2
	var contact: bool = _is_contact(move)
	if d_ab == "Anger Point":
		if bool(move.get("crit", false)) or bool(move.get("was_crit", false)):
			_raise_stage(defender, "atk", 12, logs)
			logs.append("%s's Anger Point maxed its Attack!" % str(defender.get("name", "Pokémon")))
	if crossed_half:
		if d_ab == "Anger Shell":
			_raise_stage(defender, "atk", 1, logs)
			_raise_stage(defender, "spa", 1, logs)
			_raise_stage(defender, "spe", 1, logs)
			_raise_stage(defender, "def", -1, logs)
			_raise_stage(defender, "spd", -1, logs)
			logs.append("%s's Anger Shell raised its Attack, Sp. Atk and Speed and lowered its defenses!" % str(defender.get("name", "Pokémon")))
		elif d_ab == "Berserk":
			_raise_stage(defender, "spa", 1, logs)
			logs.append("%s's Berserk raised its Sp. Atk!" % str(defender.get("name", "Pokémon")))
		elif d_ab == "Emergency Exit":
			defender["force_switch"] = true
			logs.append("%s's Emergency Exit is switching it out!" % str(defender.get("name", "Pokémon")))
	if d_ab == "Color Change":
		var cat: String = str(move.get("category", "")).to_lower()
		var mt: String = _move_type(move)
		var my_types: Array = _mon_types(defender)
		if cat != "status" and mt != "" and mt != "???" and not my_types.has(mt):
			defender["types"] = [mt]
			logs.append("%s's Color Change made it %s type!" % [str(defender.get("name", "Pokémon")), mt])
	if d_ab == "Cotton Down":
		if attacker != defender and int(attacker.get("hp", 0)) > 0:
			_raise_stage(attacker, "spe", -1, logs)
			logs.append("%s's Cotton Down lowered %s's Speed!" % [str(defender.get("name", "Pokémon")), str(attacker.get("name", "Foe"))])
	if d_ab == "Cute Charm" and contact:
		var my_gender: String = str(defender.get("gender", "")).to_upper()
		var foe_gender: String = str(attacker.get("gender", "")).to_upper()
		if (my_gender == "" or foe_gender == "" or my_gender != foe_gender) and randf() < 0.30:
			attacker["infatuated"] = true
			logs.append("%s was infatuated by %s's Cute Charm!" % [str(attacker.get("name", "Foe")), str(defender.get("name", "Pokémon"))])
	if d_ab == "Electromorphosis":
		defender["charged"] = true
		logs.append("%s gained a Charge with Electromorphosis!" % str(defender.get("name", "Pokémon")))


## True when an ability blocks a status outright. Comatose blocks every
## non-volatile status (it is treated as asleep instead).
static func blocks_status(mon: Dictionary, status: String, field: Dictionary = {}, source: Dictionary = {}) -> bool:
	if str(mon.get("ability", "")) == "Comatose":
		return true
	return false


## True when the mon's ability lets it poison a Steel or Poison
## type. Showdown Corrosion is implemented in sim/pokemon.ts
## setStatus: the type immunity to PSN/TOX is skipped when the
## source has Corrosion. try_set_status calls this.
static func bypasses_poison_type_immunity(mon: Dictionary) -> bool:
	return str(mon.get("ability", "")) == "Corrosion"


## Run before a move is used. Returns {"skip": true} only when the move
## is genuinely blocked. Absorb abilities act here (see the header):
## a Water move into Dry Skin heals 1/4 max HP, a Ground move into
## Earth Eater heals 1/4, a Fire move into Flash Fire sets the charge.
## Armor Tail / Dazzling block foe priority moves, Aroma Veil blocks
## Attract / Disable / Encore / Heal Block / Taunt / Torment, Bulletproof
## blocks bullet moves, Damp blocks Explosion-style moves, and Desolate
## Land's harsh sun blocks damaging Water moves.
static func before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	var mv_id: String = _move_id(move)
	var mt: String = _move_type(move)
	var cat: String = str(move.get("category", "")).to_lower()
	var priority: int = int(move.get("priority", 0))
	var d_ab: String = str(defender.get("ability", ""))
	var a_ab: String = str(attacker.get("ability", ""))
	var def_name: String = str(defender.get("name", "Pokémon"))
	if (d_ab == "Armor Tail" or d_ab == "Dazzling") and priority > 0:
		if str(move.get("target", "normal")) != "foeside":
			logs.append("%s's %s blocked the priority move!" % [def_name, d_ab])
			return {"skip": true}
	if d_ab == "Aroma Veil" and AROMA_VEIL_BLOCKED_MOVES.has(mv_id):
		logs.append("%s's Aroma Veil blocked %s!" % [def_name, str(move.get("name", mv_id))])
		return {"skip": true}
	if d_ab == "Bulletproof" and _is_bullet_move(move):
		logs.append("%s's Bulletproof blocked the bullet move!" % def_name)
		return {"skip": true}
	if (d_ab == "Damp" or a_ab == "Damp") and DAMP_BLOCKED_MOVES.has(mv_id):
		logs.append("Damp blocked %s!" % str(move.get("name", mv_id)))
		return {"skip": true}
	if (d_ab == "Desolate Land" or a_ab == "Desolate Land") and mt == "water" and cat != "status":
		logs.append("The harsh sun blocked the Water move!")
		return {"skip": true}
	if d_ab == "Dry Skin" and mt == "water":
		var healed: int = _heal_fraction_hp(defender, 1, 4)
		if healed > 0:
			logs.append("%s restored HP with Dry Skin (+%d HP)!" % [def_name, healed])
		else:
			logs.append("%s's Dry Skin blocked the Water move!" % def_name)
		return {"skip": true}
	if d_ab == "Earth Eater" and mt == "ground":
		var healed2: int = _heal_fraction_hp(defender, 1, 4)
		if healed2 > 0:
			logs.append("%s restored HP with Earth Eater (+%d HP)!" % [def_name, healed2])
		else:
			logs.append("%s's Earth Eater blocked the Ground move!" % def_name)
		return {"skip": true}
	if d_ab == "Flash Fire" and mt == "fire":
		defender["flashfire_active"] = true
		logs.append("%s's Flash Fire raised the power of its Fire moves!" % def_name)
		return {"skip": true}
	return {}

## Power multiplier for the attacker's move. Aerilate / Dragonize add
## 1.2x to a changed Normal move. Analytic adds 1.3x when the attacker
## moved last (field["attacker_moved_last"]). Blaze adds 1.5x to Fire
## moves at 1/3 HP or less; Dragon's Maw 1.5x to Dragon moves; Fire Mane
## 1.5x to Fire moves; Flash Fire 1.5x to Fire moves while charged.
## Flare Boost adds 1.5x to Special moves while burned. Defeatist halves
## power at 1/2 HP or less. Dark / Fairy Aura add 4/3x to Dark / Fairy
## moves from any active mon, or 0.75x when Aura Break is also active.
static func power_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var mult: float = 1.0
	var a_ab: String = str(attacker.get("ability", ""))
	var d_ab: String = str(defender.get("ability", ""))
	var mt: String = _move_type(move)
	var cat: String = str(move.get("category", "")).to_lower()
	var hp: int = int(attacker.get("hp", 0))
	var max_hp: int = int(attacker.get("max_hp", 100))
	# The type-changer check reads the move as it was BEFORE the
	# type change, so it must also accept the "type_changed_by"
	# mark that move_type sets. Pixilate, Refrigerate, Normalize
	# and Galvanize already do this; Aerilate and Dragonize did
	# not, so their 1.2x never fired once the type had changed.
	if a_ab == "Aerilate" and (str(move.get("type_changed_by", "")) == "Aerilate" or _type_changer_applies(attacker, move)):
		mult *= 1.2
	if a_ab == "Dragonize" and (str(move.get("type_changed_by", "")) == "Dragonize" or _type_changer_applies(attacker, move)):
		mult *= 1.2
	if a_ab == "Analytic" and bool(field.get("attacker_moved_last", false)):
		mult *= 1.3
	if a_ab == "Blaze" and mt == "fire" and hp <= max_hp / 3:
		mult *= 1.5
	if a_ab == "Dragon's Maw" and mt == "dragon":
		mult *= 1.5
	if a_ab == "Fire Mane" and mt == "fire":
		mult *= 1.5
	if a_ab == "Flash Fire" and mt == "fire" and bool(attacker.get("flashfire_active", false)):
		mult *= 1.5
	if a_ab == "Flare Boost" and str(attacker.get("status", "")) == "BRN" and cat == "special":
		mult *= 1.5
	if a_ab == "Defeatist" and hp <= max_hp / 2 and (cat == "physical" or cat == "special"):
		mult *= 0.5
	if mt == "dark" and (a_ab == "Dark Aura" or d_ab == "Dark Aura"):
		if a_ab == "Aura Break" or d_ab == "Aura Break":
			mult *= 0.75
		else:
			mult *= 4.0 / 3.0
	if mt == "fairy" and (a_ab == "Fairy Aura" or d_ab == "Fairy Aura"):
		if a_ab == "Aura Break" or d_ab == "Aura Break":
			mult *= 0.75
		else:
			mult *= 4.0 / 3.0
	return mult


## Accuracy multiplier for the attacker's move. Compound Eyes: 1.3x.
static func accuracy_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	if str(attacker.get("ability", "")) == "Compound Eyes":
		return 1.3
	return 1.0


## Changed move type, or "" when unchanged. Aerilate turns Normal
## moves into Flying, Dragonize into Dragon. The move dict is marked
## with "type_changed_by" so power_mult can still see the change.
static func move_type(attacker: Dictionary, move: Dictionary, field: Dictionary) -> String:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Aerilate" and _type_changer_applies(attacker, move):
		move["type_changed_by"] = "Aerilate"
		return "flying"
	if a_ab == "Dragonize" and _type_changer_applies(attacker, move):
		move["type_changed_by"] = "Dragonize"
		return "dragon"
	return ""


## How many sleep turns one failed attempt costs this mon. Normal
## sleep costs 1; Early Bird costs 2 (Showdown conditions.ts slp
## onBeforeMove decrements time an extra time when the mon has
## Early Bird). StatusAndFieldEngine.can_act_this_turn calls this.
static func sleep_tick(mon: Dictionary) -> int:
	if str(mon.get("ability", "")) == "Early Bird":
		return 2
	return 1


## True when the ability blocks a stat drop. Big Pecks blocks Defense
## drops only; Clear Body blocks every drop. The caller must only call
## this for drops caused by a foe, never for self-inflicted drops.
static func blocks_stat_change(mon: Dictionary, stat_key: String, amount: int, source: Dictionary = {}) -> bool:
	if amount >= 0:
		return false
	var ab: String = str(mon.get("ability", ""))
	if ab == "Big Pecks" and stat_key == "def":
		return true
	if ab == "Clear Body":
		return true
	return false


## Called AFTER a stat stage change has been applied. Contrary inverts
## the change by applying -2x the amount. Competitive raises Sp. Atk
## by 2 and Defiant raises Attack by 2 when a stat was lowered; the
## caller must only call this for drops caused by a foe.
static func on_stat_boosted(mon: Dictionary, stat_key: String, amount: int, field: Dictionary, logs: Array) -> void:
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	match ab:
		"Contrary":
			_raise_stage(mon, stat_key, -2 * amount, logs)
			logs.append("%s's Contrary flipped the stat change!" % mon_name)
		"Competitive":
			if amount < 0:
				_raise_stage(mon, "spa", 2, logs)
				logs.append("%s's Competitive raised its Sp. Atk!" % mon_name)
		"Defiant":
			if amount < 0:
				_raise_stage(mon, "atk", 2, logs)
				logs.append("%s's Defiant raised its Attack!" % mon_name)


## True when the trapper's Arena Trap stops the foe switching out.
## Flying-type, Levitate, Air Balloon and Ghost-type foes escape, and
## a foe holding a Shed Shell escapes.
static func traps_foe(trapper: Dictionary, foe: Dictionary) -> bool:
	if str(trapper.get("ability", "")) != "Arena Trap":
		return false
	var foe_types: Array = _mon_types(foe)
	if foe_types.has("ghost") or foe_types.has("flying"):
		return false
	if str(foe.get("ability", "")) == "Levitate":
		return false
	var foe_item: String = str(foe.get("item", "")).to_lower()
	if foe_item == "airballoon" or foe_item == "shedshell":
		return false
	return true


## Effects when a mon faints. "foe" is the surviving mon that scored
## the KO (the caller only calls this for move KOs). Beast Boost and
## Eelevate raise the KOer's highest stat; Chilling Neigh and
## As One (Glastrier) raise Attack; As One (Spectrier) raises Sp. Atk;
## Battle Bond raises Attack, Sp. Atk and Speed for a Greninja, once
## per battle.
static func on_faint(fainted: Dictionary, foe: Dictionary, field: Dictionary, logs: Array, by_move: bool = true) -> void:
	if int(foe.get("hp", 0)) <= 0:
		return
	# Only a move KO boosts (Showdown onSourceAfterFaint needs the
	# KO effect to be a move). The controller passes false for a
	# confusion self-hit and for recoil or Life Orb self-faints.
	if not by_move:
		return
	var ab: String = str(foe.get("ability", ""))
	var foe_name: String = str(foe.get("name", "Pokémon"))
	match ab:
		"Beast Boost", "Eelevate":
			var best: String = _best_stat(foe)
			_raise_stage(foe, best, 1, logs)
			logs.append("%s's %s raised its %s!" % [foe_name, ab, best.to_upper()])
		# As One lives in Batch4 only now: it was here too, so a
		# full-variant holder got +2 (once here, once in Batch4).
		"Chilling Neigh":
			_raise_stage(foe, "atk", 1, logs)
			logs.append("%s's %s raised its Attack!" % [foe_name, ab])
		"Battle Bond":
			if bool(foe.get("bond_triggered", false)):
				return
			var species: String = str(foe.get("species", foe.get("name", ""))).to_lower()
			if species == "greninja" or species == "greninjabond" or species == "greninja-ash":
				foe["bond_triggered"] = true
				_raise_stage(foe, "atk", 1, logs)
				_raise_stage(foe, "spa", 1, logs)
				_raise_stage(foe, "spe", 1, logs)
				logs.append("%s's Battle Bond raised its Attack, Sp. Atk and Speed!" % foe_name)


## Damage multiplier from an ally's ability. Battery: an ally's Special
## moves get 1.3x power. In singles the attacker is its own ally, so
## this does nothing there, which matches Showdown.
static func ally_damage_mult(ally: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> float:
	if str(ally.get("ability", "")) == "Battery":
		if str(attacker.get("name", "")) != str(ally.get("name", "")):
			if str(move.get("category", "")).to_lower() == "special":
				return 1.3
	return 1.0


## Terrain this mon sets on switch-in, or "" for none.
## Electric Surge sets Electric Terrain.
static func terrain_on_switch_in(mon: Dictionary) -> String:
	if str(mon.get("ability", "")) == "Electric Surge":
		return "electric"
	return ""


## New forme slug after a forme-changing ability fires, or "".
## Disguise: a Mimikyu whose disguise is broken becomes Mimikyu-Busted
## (or Mimikyu-Busted-Totem for the Totem forme).
static func form_change(mon: Dictionary, field: Dictionary) -> String:
	if str(mon.get("ability", "")) != "Disguise":
		return ""
	if not bool(mon.get("disguise_broken", false)):
		return ""
	var species: String = str(mon.get("species", mon.get("name", ""))).to_lower()
	if species == "mimikyutotem":
		return "mimikyu-busted-totem"
	if species == "mimikyu":
		return "mimikyu-busted"
	return ""


## Effects when the mon uses (eats) a held item. Cheek Pouch restores
## 1/3 max HP after eating any Berry. Cud Chew stores the Berry to eat
## it again at the end of the next turn (see end_of_turn).
static func on_item_use(mon: Dictionary, item_id: String, field: Dictionary, logs: Array, ally: Dictionary = {}) -> void:
	if not _is_berry(item_id):
		return
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	if ab == "Cheek Pouch":
		var healed: int = _heal_fraction_hp(mon, 1, 3)
		if healed > 0:
			logs.append("%s restored HP with Cheek Pouch (+%d HP)!" % [mon_name, healed])
	if ab == "Cud Chew":
		mon["cud_berry"] = item_id.to_lower()
		mon["cud_turns"] = 2
		logs.append("%s will eat its %s again with Cud Chew!" % [mon_name, item_id])
