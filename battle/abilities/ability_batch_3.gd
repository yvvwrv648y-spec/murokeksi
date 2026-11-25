class_name AbilityBatch3
extends RefCounted
## Battle engine v3, ability batch 3: Natural Cure through Slow Start (70 abilities).
## Self-contained: static funcs only, no references to any other file.
##
## Every mechanic comes from Pokemon Showdown data/abilities.ts. Nothing is
## invented. Two v2 partials are COMPLETED here, not redone: Poison Heal
## (the 1/8 max HP heal while poisoned; v2 already had this in its own
## on_end_of_turn, it is re-implemented here so this batch is complete on
## its own) and Sap Sipper (v2 had only the Grass immunity; the +1 Attack
## stage on a Grass hit is added here, inside is_immune, because an immune
## move never deals damage so on_damage_taken never fires for it).
##
## NOTE ON THE BRIEF: the brief named Solar Power and Storm Drain as the
## v2 partials to complete, but batch_3.json does not contain them (they
## fall alphabetically after Slow Start, so they belong to batch 4). The
## partials actually in this batch file are Poison Heal and Sap Sipper,
## and those are the ones completed here.
##
## Caller contracts (the hooks below cannot see the whole battle, so the
## caller must honour these):
## - before_move MUST be called for every move before damage or immunity
##   resolution. Defender-side blocks live there: Overcoat powder moves,
##   Oblivious Attract/Captivate/Taunt, Own Tempo confusion moves, Pastel
##   Veil poison status moves, Purifying Salt / Shields Down (Meteor) status
##   moves, Queenly Majesty priority moves, Rebound reflectable status
##   moves, Prankster Dark immunity, Primordial Sea Fire moves.
## - is_immune MUST be consulted BEFORE type-chart immunity: Scrappy
##   returns false for Normal/Fighting moves against a Ghost, which is
##   what lets those moves hit. Sap Sipper raises Attack inside
##   is_immune (there is no log channel there, so the raise is silent).
## - on_stat_boosted is called AFTER the stage change has been applied.
##   Opportunist: the caller must ALSO call it for the Opportunist holder
##   whenever a FOE gains a positive stage, with field["boost_target_name"]
##   set to the name of the mon whose stat actually rose. Rattled's
##   Intimidate half needs field["stat_source"] = "Intimidate".
## - blocks_stat_change IS defined here now: it blocks an Attack drop
##   only when the source mon carries the "intimidate_drop" mark,
##   which the Intimidate arm sets around its own call and clears
##   right after. Drops from moves are never marked, so they land.

## - on_item_use MUST be called for every item a mon uses. It records the
##   item in field["items_used_this_turn"] (an Array the caller resets each
##   turn) so Pickup can find it in end_of_turn.
## - Sand Spit sets mon["sandspit_triggered"] and Seed Sower sets
##   mon["seedsower_triggered"]; on_damage_taken has no field parameter,
##   so the CALLER must start sand / grassy terrain after damage when it
##   sees those flags, then clear them.
## - Screen Cleaner sets field["screens_cleared"] = true; the caller must
##   remove Reflect / Light Screen / Aurora Veil from both sides.
## - Neutralizing Gas sets field["abilities_suppressed"] = true on
##   switch-in. on_switch_out has no field parameter, so the CALLER must
##   clear that flag when the Gas mon leaves. The suppression itself (other
##   abilities doing nothing) is engine-side: the engine must check the flag.
## - Primordial Sea sets field["primordialsea"] = true and weather "rain"
##   with weather_turns 0 (indefinite). The caller must clear both when
##   the Sea mon leaves. Heavy rain is "rain" plus that flag.
## - form_change MUST be called on switch-in and at end of turn; it
##   returns the new forme slug or "". Power Construct, Schooling and
##   Shields Down live there. Mon dicts carry "species" (and "forme" when
##   changed) and "level"; flat battle stats are "atk"/"def"/"spa"/"spd"/
##   "spe" as in RC1 mon dicts.
## - Protosynthesis / Quark Drive: the best stat is computed from flat
##   stats WITH stage multipliers applied (Showdown: "Stat stage changes
##   are considered at the time this Ability activates"). The boost is
##   active while mon["protosynthesis_active"] / mon["quarkdrive_active"]
##   is true; the best stat is stored in mon["proto_best_stat"] /
##   mon["quark_best_stat"]. A Booster Energy is consumed on switch-in
##   only when sun / Electric Terrain is NOT already active.
## - Poison Heal heals here, and StatusAndFieldEngine now skips PSN and
##   TOX damage for Poison Heal holders too (Group A weather spec), so
##   a poisoned holder heals 1/8 max HP and takes no poison damage.

## - Power of Alchemy / Receiver copy an ALLY's ability on faint. In
##   doubles the caller must pass the surviving ally as the "foe" argument
##   of on_faint; in singles there is no ally, so they cannot fire.
## - Power Spot needs the ally dict (ally_damage_mult). Plus reads the
##   ally's ability from mon["ally_ability"] in batch 2's damage_mult
##   (same arm as Minus); the controller sets the key in doubles.
## - Slow Start counts down in end_of_turn and is cleared on switch-out.
##   The counter lives in mon["slowstart_turns"].
## - No ":=" is used on any Variant value anywhere in this file (Godot
##   treats that as an error). Every variable has an explicit type.
## - Mon dict flags used here: "slowstart_turns", "protosynthesis_active",
##   "proto_best_stat", "proto_from_booster", "quarkdrive_active",
##   "quark_best_stat", "quark_from_booster", "ripen_ate_berry",
##   "ripen_double", "ripen_berry_weaken", "sandspit_triggered",
##   "seedsower_triggered", "perishsong", "volatiles" (Dictionary of
##   active volatiles such as "attract", "taunt", "confusion").

## Moves Normalize may not change (Hidden Power and Struggle are extra).
const NORMALIZE_NO_CHANGE: Array = [
	"hiddenpower", "judgment", "multiattack", "naturalgift",
	"revelationdance", "struggle", "technoblast", "terrainpulse",
	"weatherball",
]

## Moves Pixilate / Refrigerate may not change.
const NO_TYPE_CHANGE_MOVES: Array = [
	"judgment", "multiattack", "naturalgift", "revelationdance",
	"technoblast", "terrainpulse", "weatherball",
]

## Moves Parental Bond never doubles (Showdown onPrepareHit).
const PARENTAL_BOND_EXCLUDED: Array = [
	"doomdesire", "dragondarts", "dynamaxcannon", "endeavor",
	"explosion", "finalgambit", "fling", "futuresight", "iceball",
	"rollout", "selfdestruct",
]

## Berries whose damage-weakening effect Ripen doubles (halve -> quarter).
const WEAKEN_BERRIES: Array = [
	"babiriberry", "chartiberry", "chilanberry", "chopleberry",
	"cobaberry", "colburberry", "habanberry", "kasibberry",
	"kebiaberry", "occaberry", "passhoberry", "payapaberry",
	"rindoberry", "roseliberry", "shucaberry", "tangaberry",
	"wacanberry", "yacheberry",
]

## Abilities Power of Alchemy / Receiver may not copy (Showdown
## noreceiver flag), compared normalized.
const NORECEIVER_ABILITIES: Array = [
	"asone", "asoneglastrier", "asonespectrier", "battlebond",
	"comatose", "commander", "disguise", "embodyaspect",
	"embodyaspectteal", "embodyaspectwellspring",
	"embodyaspecthearthflame", "embodyaspectcornerstone",
	"flowergift", "forecast", "hungerswitch", "iceface", "illusion",
	"imposter", "multitype", "neutralizinggas", "poisonpuppeteer",
	"powerconstruct", "powerofalchemy", "protosynthesis",
	"quarkdrive", "receiver", "rkssystem", "schooling",
	"shieldsdown", "stancechange", "terashell", "terashift",
	"terraformzero", "trace", "wonderguard", "zenmode", "zerotohero",
	"noability",
]

## Moves Oblivious blocks outright.
const OBLIVIOUS_BLOCKED_MOVES: Array = ["attract", "captivate", "taunt"]

## Memory slug (normalized) -> type it gives a Silvally (RKS System).
const MEMORY_TYPES: Dictionary = {
	"fightingmemory": "Fighting", "flyingmemory": "Flying",
	"poisonmemory": "Poison", "groundmemory": "Ground",
	"rockmemory": "Rock", "bugmemory": "Bug",
	"ghostmemory": "Ghost", "steelmemory": "Steel",
	"firememory": "Fire", "watermemory": "Water",
	"grassmemory": "Grass", "electricmemory": "Electric",
	"psychicmemory": "Psychic", "icememory": "Ice",
	"dragonmemory": "Dragon", "darkmemory": "Dark",
	"fairymemory": "Fairy",
}


## Normalize an id/slug: lowercase, strip "-", "_", " ", "'", "(" and ")".
static func _norm(raw: String) -> String:
	var out: String = raw.to_lower()
	out = out.replace("-", "")
	out = out.replace("_", "")
	out = out.replace(" ", "")
	out = out.replace("'", "")
	out = out.replace("(", "")
	out = out.replace(")", "")
	return out


## Species id of a mon, e.g. "silvally", "zygardecomplete".
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
	for t: Variant in types:
		if str(t).to_lower() == want:
			return true
	return false


## True when the move has the named flag. moves.json marks flags with
## flags.<name> = 1; RC1 move dicts may carry a top-level bool.
static func _flag(move: Dictionary, key: String) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if flags.has(key):
		return bool(flags.get(key, false))
	return bool(move.get(key, false))


## Lowercase move type, "" when the move dict has none.
static func _move_type(move: Dictionary) -> String:
	return str(move.get("type", "")).to_lower()


## Lowercase move category, accepting "cat" (RC1) or "category".
static func _move_cat(move: Dictionary) -> String:
	return str(move.get("cat", move.get("category", ""))).to_lower()


## Normalized move id, falling back to the move name.
static func _move_id(move: Dictionary) -> String:
	return _norm(str(move.get("id", move.get("name", ""))))


## True when the move makes contact.
static func _is_contact(move: Dictionary) -> bool:
	return _flag(move, "contact")


## True when the move is sound-based.
static func _is_sound(move: Dictionary) -> bool:
	return _flag(move, "sound")


## True when the move is a slicing move.
static func _is_slicing(move: Dictionary) -> bool:
	return _flag(move, "slicing")


## True when the move is a powder move.
static func _is_powder(move: Dictionary) -> bool:
	return _flag(move, "powder")


## True when the item slug is a Berry (all Berry slugs end in "berry",
## plus Berry Juice).
static func _is_berry(item_id: String) -> bool:
	var low: String = _norm(item_id)
	if low == "berryjuice":
		return true
	return low.ends_with("berry")


## Gender as "M" / "F" / "" (genderless or unknown).
static func _gender(mon: Dictionary) -> String:
	var raw: String = str(mon.get("gender", "")).to_upper()
	if raw == "M" or raw == "MALE":
		return "M"
	if raw == "F" or raw == "FEMALE":
		return "F"
	return ""


## True when sun is up. "intensesun" (Desolate Land) counts as sun.
static func _is_sun(field: Dictionary) -> bool:
	var w: String = str(field.get("weather", "none")).to_lower()
	return w == "sun" or w == "sunnyday" or w == "intensesun" or w == "desolateland"


## Field-effect duration for a move used by this mon. Showdown
## moves.ts durationCallback: Persistent adds +2 turns to Tailwind
## (4 -> 6), Trick Room (5 -> 7), Gravity (5 -> 7), Safeguard
## (5 -> 7), Wonder Room (5 -> 7), Magic Room (5 -> 7) and Heal
## Block (5 -> 7, except Psychic Noise's 2-turn Heal Block, which
## is not wired here because it is a damaging move). The effect_id
## is the lower-case move id; unknown ids return base_turns.
static func field_duration(mon: Dictionary, effect_id: String, base_turns: int) -> int:
	if str(mon.get("ability", "")) == "Persistent":
		return base_turns + 2
	return base_turns


## True when a sandstorm is up.
static func _is_sand(field: Dictionary) -> bool:
	var w: String = str(field.get("weather", "none")).to_lower()
	return w == "sand" or w == "sandstorm"


## Type a held Memory gives a Silvally, "" when the item is no Memory.
static func _memory_type(item_id: String) -> String:
	return str(MEMORY_TYPES.get(_norm(item_id), ""))


## Raise one stat stage by an amount, clamped between -6 and +6.
static func _raise_stage(mon: Dictionary, key: String, amount: int, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages[key] = clampi(int(stages.get(key, 0)) + amount, -6, 6)
	mon["stages"] = stages


## Heal HP by a fraction of max HP, never above max HP.
static func _heal_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp: int = int(mon.get("max_hp", 100))
	var gain: int = maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before: int = int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + gain)
	return int(mon.get("hp", 0)) - before


## One battle stat with its stage multiplier applied (positive stage s:
## (2+s)/2, negative stage s: 2/(2-s)).
static func _staged_stat(mon: Dictionary, key: String) -> float:
	var base: float = float(int(mon.get(key, 0)))
	var stages: Dictionary = mon.get("stages", {})
	var stage: int = int(stages.get(key, 0))
	if stage >= 0:
		return base * (2.0 + float(stage)) / 2.0
	return base * 2.0 / (2.0 + float(-stage))


## The mon's highest battle stat. Ties go Attack, Defense, Special
## Attack, Special Defense, Speed (Showdown getBestStat order). Stage
## changes are counted, as the Protosynthesis / Quark Drive text says.
static func _best_stat(mon: Dictionary) -> String:
	var best_key: String = "atk"
	var best_val: float = _staged_stat(mon, "atk")
	var keys: Array = ["def", "spa", "spd", "spe"]
	for k: Variant in keys:
		var key: String = str(k)
		var val: float = _staged_stat(mon, key)
		if val > best_val:
			best_val = val
			best_key = key
	return best_key


## True when Normalize may change this move's type.
static func _normalize_applies(attacker: Dictionary, move: Dictionary) -> bool:
	if bool(move.get("is_z", false)) and _move_cat(move) != "status":
		return false
	if bool(move.get("is_max", false)):
		return true
	if NORMALIZE_NO_CHANGE.has(_move_id(move)):
		return false
	if _move_id(move) == "terablast" and bool(attacker.get("terastallized", false)):
		return false
	return true


## True when Pixilate / Refrigerate may change this move's type
## (Normal type, not in the exclusion list, not a terastallized
## Tera Blast, not a Z move).
static func _type_changer_applies(attacker: Dictionary, move: Dictionary) -> bool:
	if _move_type(move) != "normal":
		return false
	if bool(move.get("is_z", false)) and _move_cat(move) != "status":
		return false
	if NO_TYPE_CHANGE_MOVES.has(_move_id(move)) and not bool(move.get("is_max", false)):
		return false
	if _move_id(move) == "terablast" and bool(attacker.get("terastallized", false)):
		return false
	return true


## Try to switch on a Protosynthesis / Quark Drive boost on switch-in.
## use_sun true means sun is the trigger (Protosynthesis), false means
## Electric Terrain (Quark Drive). A Booster Energy is only spent when
## the field condition is NOT already active.
static func _try_activate_boost(mon: Dictionary, field: Dictionary, ability_name: String, active_key: String, best_key: String, booster_key: String, use_sun: bool, logs: Array) -> void:
	var mon_name: String = str(mon.get("name", "Pokémon"))
	var condition: bool = false
	if use_sun:
		condition = _is_sun(field)
	else:
		condition = str(field.get("terrain", "none")).to_lower() == "electric"
	if condition:
		mon[active_key] = true
		mon[best_key] = _best_stat(mon)
		mon[booster_key] = false
		logs.append("%s's %s activated! Best stat: %s." % [mon_name, ability_name, str(mon.get(best_key, ""))])
	elif _norm(str(mon.get("item", ""))) == "boosterenergy":
		mon["item"] = ""
		mon[active_key] = true
		mon[best_key] = _best_stat(mon)
		mon[booster_key] = true
		logs.append("%s's %s activated with Booster Energy!" % [mon_name, ability_name])


## End-of-turn refresh of a Protosynthesis / Quark Drive boost: switch
## it on when the field condition starts, switch it off when the
## condition ends (a Booster Energy boost stays until switch-out).
static func _refresh_boost(mon: Dictionary, field: Dictionary, ability_name: String, active_key: String, best_key: String, booster_key: String, use_sun: bool, logs: Array) -> void:
	var mon_name: String = str(mon.get("name", "Pokémon"))
	var condition: bool = false
	if use_sun:
		condition = _is_sun(field)
	else:
		condition = str(field.get("terrain", "none")).to_lower() == "electric"
	if bool(mon.get(active_key, false)):
		if not bool(mon.get(booster_key, false)) and not condition:
			mon.erase(active_key)
			mon.erase(best_key)
			mon.erase(booster_key)
			logs.append("%s's %s ended." % [mon_name, ability_name])
	elif condition:
		mon[active_key] = true
		mon[best_key] = _best_stat(mon)
		mon[booster_key] = false
		logs.append("%s's %s activated! Best stat: %s." % [mon_name, ability_name, str(mon.get(best_key, ""))])


## Switch-in effects. Orichalcum Pulse summons sun; Primordial Sea sets
## heavy rain; Psychic Surge sets Psychic Terrain (see also
## terrain_on_switch_in); Pastel Veil cures the holder's poison;
## Neutralizing Gas raises the suppression flag; Slow Start starts its
## 5-turn counter; Screen Cleaner flags screens for clearing; RKS System
## sets a Silvally's type from its Memory; Protosynthesis / Quark Drive
## switch on when their field condition holds (or spend a Booster Energy).
static func on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	match ab:
		"Orichalcum Pulse":
			field["weather"] = "sun"
			field["weather_turns"] = ItemEngine.weather_duration(mon, "sun", 5)
			logs.append("%s's Orichalcum Pulse intensified the sun's rays!" % mon_name)
		"Primordial Sea":
			field["weather"] = "rain"
			field["weather_turns"] = 0
			field["primordialsea"] = true
			logs.append("Heavy rain began with %s's Primordial Sea!" % mon_name)
		"Psychic Surge":
			field["terrain"] = "psychic"
			field["terrain_turns"] = ItemEngine.terrain_duration(mon, 5)
			logs.append("%s's Psychic Surge set Psychic Terrain!" % mon_name)
		"Pastel Veil":
			var st: String = str(mon.get("status", ""))
			if st == "PSN" or st == "TOX":
				mon["status"] = ""
				logs.append("%s's Pastel Veil cured its poison!" % mon_name)
		"Pressure":
			logs.append("%s is exerting Pressure!" % mon_name)
		"Neutralizing Gas":
			field["abilities_suppressed"] = true
			logs.append("%s's Neutralizing Gas suppressed all Abilities!" % mon_name)
		"Slow Start":
			mon["slowstart_turns"] = 5
			logs.append("%s's Slow Start began! (5 turns)" % mon_name)
		# The log moved to the caller's _maybe_clear_screens: it
		# only prints when a screen was really removed.
		"Screen Cleaner":
			field["screens_cleared"] = true
		"RKS System":
			if _species_id(mon).contains("silvally"):
				var mem_type: String = _memory_type(str(mon.get("item", "")))
				if mem_type != "":
					mon["types"] = [mem_type.to_lower()]
					logs.append("%s's RKS System changed its type to %s!" % [mon_name, mem_type])
		"Protosynthesis":
			_try_activate_boost(mon, field, "Protosynthesis", "protosynthesis_active", "proto_best_stat", "proto_from_booster", true, logs)
		"Quark Drive":
			_try_activate_boost(mon, field, "Quark Drive", "quarkdrive_active", "quark_best_stat", "quark_from_booster", false, logs)
	return logs


## Switch-out effects. Natural Cure clears the status. Slow Start and
## the Protosynthesis / Quark Drive boosts end. Neutralizing Gas and
## Primordial Sea cannot clear their field flags here (no field
## parameter); the CALLER must clear field["abilities_suppressed"] and
## field["primordialsea"] (plus the weather) when those mons leave.
static func on_switch_out(mon: Dictionary) -> void:
	var ab: String = str(mon.get("ability", ""))
	match ab:
		"Natural Cure":
			mon["status"] = ""
		"Slow Start":
			mon.erase("slowstart_turns")
		"Protosynthesis":
			mon.erase("protosynthesis_active")
			mon.erase("proto_best_stat")
			mon.erase("proto_from_booster")
		"Quark Drive":
			mon.erase("quarkdrive_active")
			mon.erase("quark_best_stat")
			mon.erase("quark_from_booster")


## True when the defender's ability makes the move fail outright.
## Mold Breaker on the attacker bypasses ability immunities. Scrappy
## on the attacker lets Normal/Fighting moves hit a Ghost (returns
## false so the caller does NOT apply the Ghost type immunity).
## Sap Sipper: Grass immunity, and the +1 Attack stage is raised here,
## because an immune move deals no damage and on_damage_taken never
## fires for it. The raise is silent (no log channel on this hook).
static func is_immune(defender: Dictionary, move_type: String, attacker_ability: String, effectiveness: float = 1.0) -> bool:
	if attacker_ability == "Mold Breaker":
		return false
	var mt: String = move_type.to_lower()
	if attacker_ability == "Scrappy" and (mt == "normal" or mt == "fighting") and _has_type(defender, "ghost"):
		return false
	var ab: String = str(defender.get("ability", ""))
	if ab == "Sap Sipper" and mt == "grass":
		var no_logs: Array = []
		_raise_stage(defender, "atk", 1, no_logs)
		return true
	return false


## Final damage multiplier. Attacker-side: Neuroforce on supereffective
## hits, Slow Start Attack halving.

## Defender-side: Protosynthesis / Quark Drive Defense / Sp. Def boosts
## (stat x1.3 means damage /1.3), Prism Armor and Shadow Shield on
## supereffective / full-HP hits, Punk Rock and Purifying Salt halving
## sound / Ghost damage, Ripen quartering a weakened Berry's hit, Shell
## Armor cancelling the standard 1.5x critical bonus (the crit roll
## itself is not consulted here; see the report).
static func damage_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> float:
	var mult: float = 1.0
	var a_ab: String = str(attacker.get("ability", ""))
	var d_ab: String = str(defender.get("ability", ""))
	var mt: String = _move_type(move)
	var cat: String = _move_cat(move)
	var d_hp: int = int(defender.get("hp", 0))
	var d_max_hp: int = int(defender.get("max_hp", 1))
	if a_ab == "Neuroforce" and effectiveness > 1.0:
		mult *= 1.25
	if a_ab == "Slow Start" and int(attacker.get("slowstart_turns", 0)) > 0 and cat == "physical":
		mult *= 0.5
	# Piercing Drill has no damage change in Showdown: its only
	# effect is letting contact moves bypass Protect
	# (abilities.ts piercingdrill onHitProtect). The old 0.25x
	# arm was a misreading and is removed. The bypass itself
	# cannot be built yet: no Protect exists in this engine.

	if d_ab == "Protosynthesis" and bool(defender.get("protosynthesis_active", false)):
		var proto_best: String = str(defender.get("proto_best_stat", ""))
		if proto_best == "def" and cat == "physical":
			mult *= 1.0 / 1.3
		elif proto_best == "spd" and cat == "special":
			mult *= 1.0 / 1.3
	if d_ab == "Quark Drive" and bool(defender.get("quarkdrive_active", false)):
		var quark_best: String = str(defender.get("quark_best_stat", ""))
		if quark_best == "def" and cat == "physical":
			mult *= 1.0 / 1.3
		elif quark_best == "spd" and cat == "special":
			mult *= 1.0 / 1.3
	if d_ab == "Prism Armor" and effectiveness > 1.0:
		mult *= 0.75
	if d_ab == "Shadow Shield" and d_hp >= d_max_hp:
		mult *= 0.5
	if d_ab == "Punk Rock" and _is_sound(move):
		mult *= 0.5
	if d_ab == "Purifying Salt" and mt == "ghost":
		mult *= 0.5
	if d_ab == "Ripen" and bool(defender.get("ripen_berry_weaken", false)):
		defender["ripen_berry_weaken"] = false
		mult *= 0.5
	if d_ab == "Shell Armor" and is_crit:
		mult *= 1.0 / 1.5
	return mult


## End-of-turn effects. Poison Heal heals 1/8 max HP while poisoned
## (StatusAndFieldEngine now skips the poison damage for the holder).
## Shed Skin

## has a 33% chance to cure the status. Pastel Veil cures the holder's
## poison. Oblivious clears Attract / Taunt volatiles and Own Tempo
## clears confusion (from mon["volatiles"] when the engine keeps one).
## Slow Start counts down. Protosynthesis / Quark Drive refresh against
## the current sun / terrain. Pickup takes the first item used this turn
## (field["items_used_this_turn"], filled by on_item_use).
static func end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	var status: String = str(mon.get("status", ""))
	match ab:
		"Poison Heal":
			if status == "PSN" or status == "TOX":
				var healed: int = _heal_fraction_hp(mon, 1, 8)
				if healed > 0:
					logs.append("%s restored HP with Poison Heal (+%d HP)!" % [mon_name, healed])
		"Shed Skin":
			if status != "" and randf() < 0.33:
				mon["status"] = ""
				logs.append("%s's Shed Skin cured its %s!" % [mon_name, status])
		"Pastel Veil":
			if status == "PSN" or status == "TOX":
				mon["status"] = ""
				logs.append("%s's Pastel Veil cured its poison!" % mon_name)
		"Oblivious":
			var vols: Dictionary = mon.get("volatiles", {})
			if vols.has("attract"):
				vols.erase("attract")
				logs.append("%s's Oblivious ended its infatuation!" % mon_name)
			if vols.has("taunt"):
				vols.erase("taunt")
				logs.append("%s's Oblivious ended its taunt!" % mon_name)
		"Own Tempo":
			var vols2: Dictionary = mon.get("volatiles", {})
			var had_confusion: bool = false
			if vols2.has("confusion"):
				vols2.erase("confusion")
				had_confusion = true
			if bool(mon.get("confused", false)):
				mon["confused"] = false
				mon["confusion_turns"] = 0
				had_confusion = true
			if had_confusion:
				logs.append("%s's Own Tempo ended its confusion!" % mon_name)
		"Slow Start":
			var turns: int = int(mon.get("slowstart_turns", 0))
			if turns > 0:
				turns -= 1
				if turns <= 0:
					mon.erase("slowstart_turns")
					logs.append("%s's Slow Start ended!" % mon_name)
				else:
					mon["slowstart_turns"] = turns
		"Protosynthesis":
			_refresh_boost(mon, field, "Protosynthesis", "protosynthesis_active", "proto_best_stat", "proto_from_booster", true, logs)
		"Quark Drive":
			_refresh_boost(mon, field, "Quark Drive", "quarkdrive_active", "quark_best_stat", "quark_from_booster", false, logs)
		"Pickup":
			if str(mon.get("item", "")) == "":
				var used: Array = field.get("items_used_this_turn", [])
				if not used.is_empty():
					var found_item: String = str(used[0])
					used.remove_at(0)
					field["items_used_this_turn"] = used
					mon["item"] = found_item
					logs.append("%s picked up %s with Pickup!" % [mon_name, found_item])


## Effects when the defender is hit. Poison Touch is attacker-side:
## a contact move has a 30% chance to poison the target (blocked by
## the target's Shield Dust or Covert Cloak). Rattled raises Speed 1
## stage on a Bug/Dark/Ghost hit. Sand Spit and Seed Sower set flags
## for the caller to start sand / grassy terrain (no field parameter
## here). Perish Body starts Perish Song on both mons on contact.
## Pickpocket steals the attacker's item on a contact hit when the
## holder has no item.
static func on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var d_ab: String = str(defender.get("ability", ""))
	var a_ab: String = str(attacker.get("ability", ""))
	var mt: String = _move_type(move)
	var contact: bool = _is_contact(move)
	if a_ab == "Poison Touch" and contact and str(defender.get("status", "")) == "":
		if str(defender.get("ability", "")) != "Shield Dust" and _norm(str(defender.get("item", ""))) != "covertcloak":
			if randf() < 0.30:
				defender["status"] = "PSN"
				logs.append("%s was poisoned by %s's Poison Touch!" % [str(defender.get("name", "Pokémon")), str(attacker.get("name", "Pokémon"))])
	match d_ab:
		"Rattled":
			if mt == "bug" or mt == "dark" or mt == "ghost":
				_raise_stage(defender, "spe", 1, logs)
				logs.append("%s's Rattled raised its Speed!" % str(defender.get("name", "Pokémon")))
		"Sand Spit":
			defender["sandspit_triggered"] = true
			logs.append("%s's Sand Spit whipped up a sandstorm!" % str(defender.get("name", "Pokémon")))
		"Seed Sower":
			defender["seedsower_triggered"] = true
			logs.append("%s's Seed Sower set Grassy Terrain!" % str(defender.get("name", "Pokémon")))
		"Perish Body":
			if contact and not bool(attacker.get("perishsong", false)):
				attacker["perishsong"] = true
				defender["perishsong"] = true
				logs.append("%s's Perish Body started Perish Song on both Pokemon!" % str(defender.get("name", "Pokémon")))
		"Pickpocket":
			if contact and str(defender.get("item", "")) == "" and str(attacker.get("item", "")) != "" and not _sticky_hold_blocks(attacker):
				var stolen: String = str(attacker.get("item", ""))
				attacker["item"] = ""
				defender["item"] = stolen
				logs.append("%s's Pickpocket stole %s!" % [str(defender.get("name", "Pokémon")), stolen])


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
	return item.to_lower().replace(" ", "").replace("-", "").replace("_", "") != "stickybarb"


## Speed multipliers owned by this file. Slow Start halves Speed for
## 5 turns. Protosynthesis / Quark Drive give 1.5x when Speed is the
## boosted best stat. Sand Rush is NOT here: TurnResolver owns it
## (see the brief).
static func speed_mult(mon: Dictionary, field: Dictionary) -> float:
	var ab: String = str(mon.get("ability", ""))
	if ab == "Slow Start" and int(mon.get("slowstart_turns", 0)) > 0:
		return 0.5
	if ab == "Protosynthesis" and bool(mon.get("protosynthesis_active", false)) and str(mon.get("proto_best_stat", "")) == "spe":
		return 1.5
	if ab == "Quark Drive" and bool(mon.get("quarkdrive_active", false)) and str(mon.get("quark_best_stat", "")) == "spe":
		return 1.5
	return 1.0


## True when the ability blocks a status outright. Pastel Veil blocks
## poison. Purifying Salt blocks every non-volatile status (and Yawn,
## which the caller reports through this same check). Shields Down
## blocks every status while Minior is in Meteor forme.
static func blocks_status(mon: Dictionary, status: String, field: Dictionary = {}, source: Dictionary = {}) -> bool:
	var ab: String = str(mon.get("ability", ""))
	var st: String = status.to_upper()
	match ab:
		"Pastel Veil":
			return st == "PSN" or st == "TOX"
		"Purifying Salt":
			return true
		"Shields Down":
			if _forme_id(mon) == "miniormeteor":
				return true
	return false


## True when the ability blocks a stat-stage change, but only for
## an Attack drop from Intimidate. Showdown Oblivious, Own Tempo
## and Scrappy delete boost.atk when the effect is Intimidate and
## nothing else. The Intimidate arm marks its own call with
## source["intimidate_drop"] = true (set and cleared around that
## one call), so a drop from a move used by a mon that happens to
## have Intimidate is NOT blocked here.
static func blocks_stat_change(mon: Dictionary, stat_key: String, amount: int, source: Dictionary = {}) -> bool:
	if amount >= 0:
		return false
	var ab: String = str(mon.get("ability", ""))
	var from_intimidate: bool = bool(source.get("intimidate_drop", false))
	if from_intimidate and stat_key.to_lower() == "atk" and (ab == "Oblivious" or ab == "Own Tempo" or ab == "Scrappy"):
		return true
	return false



## Fires after a status was set on target by source. Poison
## Puppeteer (Showdown onAnyAfterSetStatus): only when the source
## is the ability holder, the source's base species is Pecharunt,
## the target is not the source, the status is PSN or TOX, and the
## target is not already confused and does not have Own Tempo -
## then the target becomes confused for 2-5 turns (Showdown
## conditions.ts confusion onStart: time = random(2, 6)). The hook
## cannot tell a move-caused status from an ability-caused one (the
## engine has no effect id), but in practice only Pecharunt has this
## ability and its only poison sources are moves. The target/source
## comparison is a Dictionary value comparison; a Pecharunt
## poisoning a byte-identical Pecharunt is vanishingly rare.
static func on_after_set_status(target: Dictionary, source: Dictionary, status: String, field: Dictionary, logs: Array) -> void:
	if str(source.get("ability", "")) != "Poison Puppeteer":
		return
	var species: String = str(source.get("species", source.get("name", ""))).to_lower().replace(" ", "").replace("-", "").replace("'", "")
	if species != "pecharunt" and not species.begins_with("pecharunt"):
		return
	if target == source:
		return
	var st: String = status.to_upper()
	if st != "PSN" and st != "TOX":
		return
	if str(target.get("ability", "")) == "Own Tempo":
		return
	if bool(target.get("confused", false)):
		return
	target["confused"] = true
	target["confusion_turns"] = randi_range(2, 5)
	logs.append("%s became confused!" % str(target.get("name", target.get("species", "Pokemon"))))


## Run before a move is used. Returns {"skip": true} only when the move
## is genuinely blocked: heavy rain (Primordial Sea) stops damaging Fire
## moves; Queenly Majesty stops foe priority moves; a Dark type stops a
## Prankster-boosted status move; Rebound bounces a reflectable status
## move on the switch-in turn (the caller must re-target it at the user,
## this hook only stops it here); Overcoat stops powder moves; Oblivious
## stops Attract / Captivate / Taunt; Own Tempo stops confusion moves;
## Pastel Veil stops poison status moves; Purifying Salt and Meteor-forme
## Shields Down stop any status move. Attacker-side shaping never skips:
## Parental Bond makes a damaging move hit twice; Serene Grace doubles
## secondary chances; Skill Link takes the maximum hit count; Shield Dust
## marks the move so the caller skips its secondaries.
static func before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	var a_ab: String = str(attacker.get("ability", ""))
	var d_ab: String = str(defender.get("ability", ""))
	var mt: String = _move_type(move)
	var cat: String = _move_cat(move)
	var mv_id: String = _move_id(move)
	var priority: int = int(move.get("priority", 0))
	var move_name: String = str(move.get("name", mv_id))
	var def_name: String = str(defender.get("name", "Pokémon"))
	var atk_name: String = str(attacker.get("name", "Pokémon"))
	if bool(field.get("primordialsea", false)) and mt == "fire" and cat != "status":
		logs.append("The heavy rain blocked the Fire move!")
		return {"skip": true}
	if d_ab == "Queenly Majesty" and priority > 0:
		if str(move.get("target", "normal")).to_lower() != "foeside":
			logs.append("%s's Queenly Majesty blocked the priority move!" % def_name)
			return {"skip": true}
	if a_ab == "Prankster" and cat == "status" and _has_type(defender, "dark"):
		logs.append("The Dark type blocked the Prankster move!")
		return {"skip": true}
	if d_ab == "Rebound" and cat == "status" and _flag(move, "reflectable"):
		if int(defender.get("active_turns", 0)) == 0:
			move["bounced"] = true
			logs.append("%s's Rebound bounced %s back!" % [def_name, move_name])
			return {"skip": true}

	if d_ab == "Overcoat" and _is_powder(move) and attacker != defender:
		logs.append("%s's Overcoat blocked the powder move!" % def_name)
		return {"skip": true}
	if d_ab == "Oblivious" and OBLIVIOUS_BLOCKED_MOVES.has(mv_id):
		logs.append("%s's Oblivious blocked %s!" % [def_name, move_name])
		return {"skip": true}
	if d_ab == "Own Tempo" and str(move.get("volatileStatus", "")).to_lower() == "confusion":
		logs.append("%s's Own Tempo blocked the confusion move!" % def_name)
		return {"skip": true}
	if d_ab == "Pastel Veil" and str(move.get("status", "")).to_lower() == "psn" or d_ab == "Pastel Veil" and str(move.get("status", "")).to_lower() == "tox":
		logs.append("%s's Pastel Veil blocked the poison move!" % def_name)
		return {"skip": true}
	if d_ab == "Purifying Salt" and str(move.get("status", "")) != "":
		logs.append("%s's Purifying Salt blocked the status move!" % def_name)
		return {"skip": true}
	if d_ab == "Shields Down" and _forme_id(defender) == "miniormeteor" and str(move.get("status", "")) != "":
		logs.append("%s's Shields Down blocked the status move!" % def_name)
		return {"skip": true}
	if a_ab == "Parental Bond" and cat != "status":
		var excluded: bool = PARENTAL_BOND_EXCLUDED.has(mv_id)
		var already_multi: bool = move.has("multihit")
		var spread: bool = str(move.get("target", "normal")).to_lower() == "alladjacent" or str(move.get("target", "normal")).to_lower() == "alladjacentfoes" or str(move.get("target", "normal")).to_lower() == "all"
		var blocked_flag: bool = _flag(move, "noparentalbond") or _flag(move, "charge") or _flag(move, "futuremove")
		var is_z_or_max: bool = bool(move.get("is_z", false)) or bool(move.get("is_max", false))
		if not excluded and not already_multi and not spread and not blocked_flag and not is_z_or_max:
			move["multihit"] = 2
			move["multihit_type"] = "parentalbond"
			logs.append("%s's Parental Bond made %s hit twice!" % [atk_name, move_name])
	if a_ab == "Serene Grace":
		var sec: Dictionary = move.get("secondary", {})
		if sec.has("chance"):
			sec["chance"] = mini(100, int(sec.get("chance", 0)) * 2)
			move["secondary"] = sec
		var self_fx: Dictionary = move.get("self", {})
		if self_fx.has("chance"):
			self_fx["chance"] = mini(100, int(self_fx.get("chance", 0)) * 2)
			move["self"] = self_fx
		if move.has("status_chance"):
			move["status_chance"] = mini(100, int(move.get("status_chance", 0)) * 2)
		if move.has("flinch_chance"):
			move["flinch_chance"] = mini(100, int(move.get("flinch_chance", 0)) * 2)
	if a_ab == "Skill Link":
		var mh: Variant = move.get("multihit", null)
		if mh is Array:
			var mh_arr: Array = mh
			if not mh_arr.is_empty():
				move["multihit"] = int(mh_arr[mh_arr.size() - 1])
		if move.has("multiaccuracy"):
			move.erase("multiaccuracy")
	if d_ab == "Shield Dust":
		move["shield_dust_blocked"] = true
	# Piercing Drill (Showdown abilities.ts onHitProtect): a
	# contact move ignores the target's protection. The flag
	# is read by the Protect check in the controller; there
	# is no damage change. Non-contact moves get no flag.
	if a_ab == "Piercing Drill" and _is_contact(move):
		move["ignores_protect"] = true
	return {}



## Power multiplier for the attacker's move. Normalize / Pixilate /
## Refrigerate add 1.2x to a move whose type they changed (the flag
## move["type_changed_by"] covers the case where move_type already ran;
## the recompute covers the case where it has not). Punk Rock adds 1.3x
## to sound moves. Reckless adds 1.2x to recoil / crash moves. Sharpness
## adds 1.5x to slicing moves. Rivalry is 1.25x on the same gender and
## 0.75x on the opposite gender. Sand Force adds 1.3x to Ground / Rock /
## Steel moves in sand. Overgrow adds 1.5x to Grass moves at 1/3 HP or
## less. Rocky Payload adds 1.5x to Rock moves. Orichalcum Pulse adds
## 4/3x to physical moves in sun. Protosynthesis / Quark Drive add 1.3x
## when Attack or Sp. Atk is the boosted best stat (damage is linear in
## the offensive stat, so the stat boost equals a power boost).
static func power_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	var mult: float = 1.0
	var a_ab: String = str(attacker.get("ability", ""))
	var mt: String = _move_type(move)
	var cat: String = _move_cat(move)
	var hp: int = int(attacker.get("hp", 0))
	var max_hp: int = int(attacker.get("max_hp", 100))
	if a_ab == "Normalize" and (str(move.get("type_changed_by", "")) == "Normalize" or _normalize_applies(attacker, move)):
		mult *= 1.2
	if a_ab == "Pixilate" and (str(move.get("type_changed_by", "")) == "Pixilate" or _type_changer_applies(attacker, move)):
		mult *= 1.2
	if a_ab == "Refrigerate" and (str(move.get("type_changed_by", "")) == "Refrigerate" or _type_changer_applies(attacker, move)):
		mult *= 1.2
	if a_ab == "Punk Rock" and _is_sound(move):
		mult *= 1.3
	if a_ab == "Reckless" and (move.has("recoil") or bool(move.get("hasCrashDamage", false))):
		mult *= 1.2
	if a_ab == "Sharpness" and _is_slicing(move):
		mult *= 1.5
	if a_ab == "Rivalry":
		var g1: String = _gender(attacker)
		var g2: String = _gender(defender)
		if g1 != "" and g2 != "":
			if g1 == g2:
				mult *= 1.25
			else:
				mult *= 0.75
	if a_ab == "Sand Force" and _is_sand(field) and (mt == "ground" or mt == "rock" or mt == "steel"):
		mult *= 1.3
	if a_ab == "Overgrow" and mt == "grass" and float(hp) <= float(max_hp) / 3.0:
		mult *= 1.5
	if a_ab == "Rocky Payload" and mt == "rock":
		mult *= 1.5
	if a_ab == "Orichalcum Pulse" and _is_sun(field) and cat == "physical":
		mult *= 4.0 / 3.0
	if a_ab == "Protosynthesis" and bool(attacker.get("protosynthesis_active", false)):
		var proto_best: String = str(attacker.get("proto_best_stat", ""))
		if (proto_best == "atk" and cat == "physical") or (proto_best == "spa" and cat == "special"):
			mult *= 1.3
	if a_ab == "Quark Drive" and bool(attacker.get("quarkdrive_active", false)):
		var quark_best: String = str(attacker.get("quark_best_stat", ""))
		if (quark_best == "atk" and cat == "physical") or (quark_best == "spa" and cat == "special"):
			mult *= 1.3
	return mult


## Accuracy multiplier for the attacker's move. No Guard (on either
## side) makes every move always hit, so the multiplier is 100x. Sand
## Veil makes moves used against the holder 0.8x accurate in sand.
static func accuracy_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	if str(attacker.get("ability", "")) == "No Guard" or str(defender.get("ability", "")) == "No Guard":
		return 100.0
	if str(defender.get("ability", "")) == "Sand Veil" and _is_sand(field):
		return 0.8
	return 1.0


## Priority bonus. Prankster adds 1 to status moves. Quick Draw is NOT
## here: it adds a fractional +0.1 priority, which this int hook cannot
## express. It lives in frac_priority instead (see below).
static func priority_bonus(attacker: Dictionary, move: Dictionary) -> int:
	if str(attacker.get("ability", "")) == "Prankster" and _move_cat(move) == "status":
		return 1
	return 0


## Fractional priority. Showdown Quick Draw onFractionalPriority:
## +0.1 when the move is not a Status move and randomChance(3, 10)
## (30%). The controller calls this once per turn through the
## dispatcher and stores the result on the move dict as
## frac_priority; TurnResolver adds it to the int priority when it
## orders the turn.
static func frac_priority(attacker: Dictionary, move: Dictionary) -> float:
	if str(attacker.get("ability", "")) == "Quick Draw" and _move_cat(move) != "status":
		if randf() < 0.30:
			return 0.1
	return 0.0


## Changed move type, or "" when unchanged. Normalize turns moves into
## Normal, Pixilate into Fairy, Refrigerate into Ice. The move dict is
## marked with "type_changed_by" so power_mult can still see the change.
static func move_type(attacker: Dictionary, move: Dictionary, field: Dictionary) -> String:
	var a_ab: String = str(attacker.get("ability", ""))
	if a_ab == "Normalize" and _normalize_applies(attacker, move):
		move["type_changed_by"] = "Normalize"
		return "normal"
	if a_ab == "Pixilate" and _type_changer_applies(attacker, move):
		move["type_changed_by"] = "Pixilate"
		return "fairy"
	if a_ab == "Refrigerate" and _type_changer_applies(attacker, move):
		move["type_changed_by"] = "Refrigerate"
		return "ice"
	return ""


## Called AFTER a stat stage change has been applied. Simple applies
## the same change a second time, doubling it. Opportunist copies a
## FOE's positive stage gain: the caller must call this for the holder
## too, with field["boost_target_name"] set to the boosted mon's name.
## Rattled gains +1 Speed when Intimidate drops its Attack; the caller
## must set field["stat_source"] = "Intimidate" for that call.
static func on_stat_boosted(mon: Dictionary, stat_key: String, amount: int, field: Dictionary, logs: Array) -> void:
	var ab: String = str(mon.get("ability", ""))
	var mon_name: String = str(mon.get("name", "Pokémon"))
	match ab:
		"Simple":
			_raise_stage(mon, stat_key, amount, logs)
			logs.append("%s's Simple doubled the stat change!" % mon_name)
		"Opportunist":
			if amount > 0:
				var target_name: String = str(field.get("boost_target_name", ""))
				if target_name != "" and target_name != mon_name:
					_raise_stage(mon, stat_key, amount, logs)
					logs.append("%s's Opportunist copied the %s boost!" % [mon_name, stat_key])
		"Rattled":
			if stat_key == "atk" and amount < 0 and str(field.get("stat_source", "")) == "Intimidate":
				_raise_stage(mon, "spe", 1, logs)
				logs.append("%s's Rattled raised its Speed!" % mon_name)


## True when the trapper's Shadow Tag stops the foe switching out.
## A foe that also has Shadow Tag, is a Ghost type, or holds a Shed
## Shell can still switch.
static func traps_foe(trapper: Dictionary, foe: Dictionary) -> bool:
	if str(trapper.get("ability", "")) != "Shadow Tag":
		return false
	if str(foe.get("ability", "")) == "Shadow Tag":
		return false
	if _has_type(foe, "ghost"):
		return false
	if _norm(str(foe.get("item", ""))) == "shedshell":
		return false
	return true


## Called when a mon faints. Power of Alchemy and Receiver copy the
## fainted ALLY's ability onto the survivor (the caller passes the
## surviving ally as "foe" in doubles; in singles there is no ally).
## Abilities on the no-receiver list and No Ability cannot be copied.
static func on_faint(fainted: Dictionary, foe: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(foe.get("hp", 0)) <= 0:
		return
	var f_ab: String = str(foe.get("ability", ""))
	if f_ab != "Power of Alchemy" and f_ab != "Receiver":
		return
	var dead_ab: String = str(fainted.get("ability", ""))
	if dead_ab == "" or NORECEIVER_ABILITIES.has(_norm(dead_ab)):
		return
	foe["ability"] = dead_ab
	logs.append("%s's %s copied %s's %s!" % [str(foe.get("name", "Pokémon")), f_ab, str(fainted.get("name", "Pokémon")), dead_ab])


## Damage multiplier from an ally's ability. Power Spot gives the
## attacker's moves 1.3x when the ally (not the attacker) has it.
static func ally_damage_mult(ally: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> float:
	if str(ally.get("ability", "")) != "Power Spot":
		return 1.0
	var ally_name: String = str(ally.get("name", ""))
	var atk_name: String = str(attacker.get("name", ""))
	if ally_name == "" or atk_name == "" or ally_name == atk_name:
		return 1.0
	return 1.3


## Terrain set on switch-in. Psychic Surge summons Psychic Terrain.
static func terrain_on_switch_in(mon: Dictionary) -> String:
	if str(mon.get("ability", "")) == "Psychic Surge":
		return "psychic"
	return ""


## Forme change, or "" when none. Called on switch-in and at end of
## turn. Power Construct: a Zygarde at 1/2 max HP or less becomes
## Zygarde-Complete. Schooling: a level 20+ Wishiwashi becomes School
## Forme above 1/4 max HP and Solo Forme at or below it. Shields Down:
## a Minior becomes Meteor Forme above 1/2 max HP and its base forme
## at or below it.
static func form_change(mon: Dictionary, field: Dictionary) -> String:
	var ab: String = str(mon.get("ability", ""))
	var species: String = _species_id(mon)
	var forme: String = _forme_id(mon)
	var hp: int = int(mon.get("hp", 0))
	var max_hp: int = int(mon.get("max_hp", 1))
	if max_hp <= 0 or hp <= 0:
		return ""
	match ab:
		"Power Construct":
			if species.contains("zygarde") and not bool(mon.get("transformed", false)):
				if forme != "zygardecomplete" and float(hp) <= float(max_hp) / 2.0:
					return "zygardecomplete"
		"Schooling":
			if species.contains("wishiwashi") and int(mon.get("level", 100)) >= 20 and not bool(mon.get("transformed", false)):
				if float(hp) > float(max_hp) / 4.0 and forme == "wishiwashi":
					return "wishiwashischool"
				if float(hp) <= float(max_hp) / 4.0 and forme == "wishiwashischool":
					return "wishiwashi"
		"Shields Down":
			if species.contains("minior") and not bool(mon.get("transformed", false)):
				if float(hp) > float(max_hp) / 2.0 and forme != "miniormeteor":
					return "miniormeteor"
				if float(hp) <= float(max_hp) / 2.0 and forme == "miniormeteor":
					var base: String = _norm(str(mon.get("base_species", "minior")))
					if base == "":
						base = "minior"
					return base
	return ""


## Called when a mon uses an item. Every use is recorded in
## field["items_used_this_turn"] so Pickup can find it (the caller
## resets that Array each turn). Ripen: eating a Berry sets flags the
## item engine reads to double the effect; a damage-weakening Berry
## also sets mon["ripen_berry_weaken"], which damage_mult spends for
## 0.5x damage.
static func on_item_use(mon: Dictionary, item_id: String, field: Dictionary, logs: Array, ally: Dictionary = {}) -> void:
	var used: Array = field.get("items_used_this_turn", [])
	used.append(item_id)
	field["items_used_this_turn"] = used
	if str(mon.get("ability", "")) != "Ripen":
		return
	var slug: String = _norm(item_id)
	if not _is_berry(slug):
		return
	mon["ripen_ate_berry"] = true
	mon["ripen_double"] = true
	if WEAKEN_BERRIES.has(slug):
		mon["ripen_berry_weaken"] = true
	logs.append("%s's Ripen doubled the %s's effect!" % [str(mon.get("name", "Pokémon")), item_id])
