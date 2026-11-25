class_name MoveDatabaseLoader
extends RefCounted
## Unifies the RC1 MoveDatabase with the official Showdown move list.
##
## This is the v5 loader. It starts from the v4 loader and changes only
## what the v5 fix needs. The v4 file this replaces is
## battle-engine-v4/move_database_loader.gd. Do not edit the v4 file.
##
## The RC1 move list (res://battle/moves/move_database.json) has 94 moves
## in its own shape: type, cat, power, acc, pp, priority, status,
## status_chance, base_pp, pp_max. The official list
## (battle-data-pack/moves.json, 954 moves from Showdown) uses different
## key names: type, category, basePower, accuracy, pp, priority, secondary.
## This loader maps one list onto the other, so the game can use all 954
## official moves without hand-writing each one.
##
## How the mapping works, in plain words:
## - type comes straight from "type".
## - cat comes from "category" (Physical, Special, or Status).
## - power comes from "basePower". Status moves always get power 0.
## - acc comes from "accuracy". If accuracy is true (the move always
##   hits), it becomes 100, and the mapped move also gets
##   "always_hits": true, so the engine knows the hit never needs a
##   roll. That is a clean mapping, not a hack.
## - pp is the base PP from "pp", and pp_max is the PP after PP Ups:
##   int(base_pp * 8 / 5). Checked against the RC1 file: base 15 -> 24,
##   base 20 -> 32, base 5 -> 8. That matches RC1 exactly.
## - priority comes from "priority", or 0 when it is missing.
## - status comes from secondary.status (for example "par"), and
##   status_chance comes from secondary.chance. Both are empty or 0
##   when the move has no secondary effect.
## - A move that switches the user out (U-turn, Volt Switch, Flip Turn
##   and the rest) keeps its selfSwitch flag, and also gets pivot true,
##   which is the key the RC1 file uses for the same idea.
## - "name" and "num" are kept as they are.
##
## What v5 changes over v4 (the whole fix, in one place):
## - accuracy true no longer flags the move. It maps to acc 100 and
##   adds "always_hits": true. (303 moves.)
## - A "multihit" field is kept on the mapped move and no longer
##   flags it. The basePower in Showdown is the power of ONE hit, and
##   MoveEffects already rolls the real hit count. (31 moves.)
## - An empty "secondary" dict {} means the move has no secondary
##   effect at all, so it is not stored and not flagged. In Showdown
##   the empty dict is a marker so Sheer Force can cancel the move's
##   real effect, which lives somewhere else. The 4 moves with an
##   empty secondary are Diamond Storm, Clangorous Soulblaze,
##   Ceaseless Edge and Stone Axe. Their real effects are now read
##   from the "self", "selfBoost" and "sets_hazard" keys below.
## - The "self" block (with its chance, when it has one) and the
##   "selfBoost" block are copied into the mapped move. V4 dropped
##   them, which lost every self boost (Close Combat's Defense drop
##   and the rest). MoveEffects reads them.
## - A damaging move with basePower 0 is no longer flagged. It gets
##   a "damage_rule" string that names the rule the engine must use
##   to work out the real power or damage, plus the numbers the rule
##   needs (rule_amount, rule_num / rule_den, rule_scale,
##   rule_mult_num / rule_mult_den, rule_category, rule_kind).
##   The mapped "power" stays 0 for these moves. The real formulas
##   live in VariablePower (variable_power.gd). (43 moves.)
## - Ceaseless Edge gets "sets_hazard": "spikes" and Stone Axe gets
##   "sets_hazard": "stealth_rock". In Showdown their onAfterHit sets
##   that hazard on the foe's side (unless the attacker has Sheer
##   Force). The move data file only has a function placeholder for
##   that effect, so the marker comes from the checked Showdown
##   source instead.
##
## Every mapped move also gets a "needs_attention" string. In v5 it is
## empty for all 954 moves: nothing in the source needs a person to
## check it any more. The reasons list is still kept in the code as a
## safety net: if a future source file is missing a field, the loader
## will say so instead of failing quietly.
##
## Note: in the RC1 file, the "pp" key holds the max PP (24 for
## Thunderbolt). This loader puts the base PP in "pp" (15) and the max
## PP in "pp_max" (24). Code that wants the full PP of a move should
## read "pp_max", not "pp". See MERGE_README.md. The v5 JSON file
## itself writes the max PP into "pp" too, to match the v4 file shape.

## The rule each basePower-0 damaging move uses, keyed by its slug.
## Every rule is checked against the live Showdown moves.ts
## (smogon/pokemon-showdown, data/moves.ts, crawled 2026-11-22).
## - "weight": power from the target's weight (Grass Knot, Low Kick).
## - "weight_ratio": power from user weight vs target weight
##   (Heavy Slam, Heat Crash).
## - "gyro_ball": 25 * target Speed / user Speed, +1, capped at 150.
## - "electro_ball": power from floor(user Speed / target Speed):
##   0 -> 40, 1 -> 60, 2 -> 80, 3 -> 120, 4 or more -> 150.
## - "low_hp": power from the user's own HP left (Flail, Reversal).
## - "target_hp": power from the target's HP left, times rule_scale
##   (Crush Grip / Wring Out scale 120, Hard Press scale 100).
## - "fixed": damage is always rule_amount (Dragon Rage 40,
##   Sonic Boom 20).
## - "level": damage equals the user's level (Seismic Toss,
##   Night Shade).
## - "fraction": damage is rule_num / rule_den of the target's HP
##   (Guardian of Alola 3/4, the rest 1/2).
## - "ohko": the move knocks out in one hit if it lands
##   (Fissure, Guillotine, Horn Drill, Sheer Cold).
## - "counter": damage is rule_mult_num / rule_mult_den times the
##   damage the user took, and only from the rule_category of move
##   (Counter 2x Physical, Mirror Coat 2x Special, Metal Burst and
##   Comeuppance 1.5x any).
## - "friendship": power from friendship. rule_kind "return" is
##   friendship / 2.5 (Return, Pika Papow, Veevee Volley);
##   rule_kind "frustration" is (255 - friendship) / 2.5.
## - "item": power from the held item. rule_kind "fling" reads the
##   item's fling power; rule_kind "natural_gift" reads the berry's
##   natural gift power and type.
## - "bide": stores damage taken, then hits back for twice as much.
## - "endeavor": damage is the target's HP minus the user's HP.
## - "final_gambit": damage is the user's HP, and the user faints.
## - "magnitude": random power 10 / 30 / 50 / 70 / 90 / 110 / 150.
## - "present": random power 40 / 80 / 120, or heals the target.
## - "psywave": damage is the user's level times 0.5 to 1.5.
## - "spit_up": power is 100 times the Stockpile count.
## - "trump_card": power from the PP left (1 -> 200, 2 -> 80,
##   3 -> 60, 4 -> 50, 5 or more -> 40).
## - "beat_up": one hit per able party member; each hit's power is
##   5 + that member's base Attack / 10.
## - "punishment": 60 + 20 per positive stat stage on the target,
##   capped at 200.
const DAMAGE_RULES: Dictionary = {
	"beatup": {"damage_rule": "beat_up"},
	"bide": {"damage_rule": "bide"},
	"comeuppance": {"damage_rule": "counter", "rule_mult_num": 3, "rule_mult_den": 2, "rule_category": "any"},
	"counter": {"damage_rule": "counter", "rule_mult_num": 2, "rule_mult_den": 1, "rule_category": "Physical"},
	"crushgrip": {"damage_rule": "target_hp", "rule_scale": 120},
	"dragonrage": {"damage_rule": "fixed", "rule_amount": 40},
	"electroball": {"damage_rule": "electro_ball"},
	"endeavor": {"damage_rule": "endeavor"},
	"finalgambit": {"damage_rule": "final_gambit"},
	"fissure": {"damage_rule": "ohko"},
	"flail": {"damage_rule": "low_hp"},
	"fling": {"damage_rule": "item", "rule_kind": "fling"},
	"frustration": {"damage_rule": "friendship", "rule_kind": "frustration"},
	"grassknot": {"damage_rule": "weight"},
	"guardianofalola": {"damage_rule": "fraction", "rule_num": 3, "rule_den": 4},
	"guillotine": {"damage_rule": "ohko"},
	"gyroball": {"damage_rule": "gyro_ball"},
	"hardpress": {"damage_rule": "target_hp", "rule_scale": 100},
	"heatcrash": {"damage_rule": "weight_ratio"},
	"heavyslam": {"damage_rule": "weight_ratio"},
	"horndrill": {"damage_rule": "ohko"},
	"lowkick": {"damage_rule": "weight"},
	"magnitude": {"damage_rule": "magnitude"},
	"metalburst": {"damage_rule": "counter", "rule_mult_num": 3, "rule_mult_den": 2, "rule_category": "any"},
	"mirrorcoat": {"damage_rule": "counter", "rule_mult_num": 2, "rule_mult_den": 1, "rule_category": "Special"},
	"naturalgift": {"damage_rule": "item", "rule_kind": "natural_gift"},
	"naturesmadness": {"damage_rule": "fraction", "rule_num": 1, "rule_den": 2},
	"nightshade": {"damage_rule": "level"},
	"pikapapow": {"damage_rule": "friendship", "rule_kind": "return"},
	"present": {"damage_rule": "present"},
	"psywave": {"damage_rule": "psywave"},
	"punishment": {"damage_rule": "punishment"},
	"return": {"damage_rule": "friendship", "rule_kind": "return"},
	"reversal": {"damage_rule": "low_hp"},
	"ruination": {"damage_rule": "fraction", "rule_num": 1, "rule_den": 2},
	"seismictoss": {"damage_rule": "level"},
	"sheercold": {"damage_rule": "ohko"},
	"sonicboom": {"damage_rule": "fixed", "rule_amount": 20},
	"spitup": {"damage_rule": "spit_up"},
	"superfang": {"damage_rule": "fraction", "rule_num": 1, "rule_den": 2},
	"trumpcard": {"damage_rule": "trump_card"},
	"veeveevolley": {"damage_rule": "friendship", "rule_kind": "return"},
	"wringout": {"damage_rule": "target_hp", "rule_scale": 120},
}

## The hazard a move sets on the foe's side after it hits, keyed by slug.
## Checked against live Showdown moves.ts: Ceaseless Edge sets Spikes,
## Stone Axe sets Stealth Rock (both unless the attacker has Sheer Force).
const SETS_HAZARD: Dictionary = {
	"ceaselessedge": "spikes",
	"stoneaxe": "stealth_rock",
}


## Map ONE Showdown move dict to the RC1 schema.
## Returns the mapped dict, with a "needs_attention" string inside it.
static func map_move(showdown_move: Dictionary) -> Dictionary:
	# A move that is already mapped (this pack's own
	# move_database_954.json) passes straight through. It carries
	# the mapped keys ("cat", "pp_max", "needs_attention") instead
	# of the Showdown keys ("category", "basePower", "accuracy"),
	# so running it through the mapping below would flag it for
	# missing fields it never had. The pass-through keeps the
	# loader able to load its own output: total 954, clean 954.
	if showdown_move.has("needs_attention") and showdown_move.has("pp_max") and showdown_move.has("cat"):
		return showdown_move.duplicate(true)
	var reasons: Array = []
	var move_name: String = str(showdown_move.get("name", ""))
	var move_num: int = int(showdown_move.get("num", 0))
	var move_type: String = str(showdown_move.get("type", "Normal"))
	var cat: String = str(showdown_move.get("category", "Status"))
	var slug: String = rc1_key(move_name)

	# Power. Status moves always have power 0. A damaging move with
	# basePower 0 gets its damage_rule from DAMAGE_RULES instead of
	# a flag: the rule field IS the fix, and VariablePower holds
	# the real formula. The mapped "power" stays 0 for these moves.
	var power: int = 0
	var rule_fields: Dictionary = {}
	if cat != "Status":
		if showdown_move.has("basePower"):
			power = int(showdown_move.get("basePower", 0))
		else:
			reasons.append("no basePower field - mapped to 0")
		if power == 0:
			if DAMAGE_RULES.has(slug):
				var rule_value: Variant = DAMAGE_RULES.get(slug, {})
				if rule_value is Dictionary:
					rule_fields = rule_value
			else:
				# This should never happen for the 954-move source:
				# all 43 basePower-0 damaging moves are in the table.
				# "unknown" keeps the move loadable and easy to find.
				rule_fields = {"damage_rule": "unknown"}

	# Accuracy. True means the move always hits, so it becomes 100,
	# and the mapped move gets "always_hits": true.
	var acc: int = 100
	var always_hits: bool = false
	if not showdown_move.has("accuracy"):
		reasons.append("no accuracy field - mapped to 100")
	else:
		var acc_value: Variant = showdown_move.get("accuracy", 100)
		if acc_value is bool:
			if acc_value:
				acc = 100
				always_hits = true
			else:
				acc = 0
		elif acc_value is int or acc_value is float:
			acc = int(acc_value)
		else:
			reasons.append("accuracy is not a number or true - mapped to 100")

	# PP. Base PP comes from "pp". Max PP (after PP Ups) is
	# int(base_pp * 8 / 5). Checked against RC1: 15 -> 24, 20 -> 32.
	var base_pp: int = 0
	if showdown_move.has("pp"):
		base_pp = int(showdown_move.get("pp", 0))
	else:
		reasons.append("no pp field")
	var pp_max: int = int(float(base_pp) * 8.0 / 5.0)

	var priority: int = int(showdown_move.get("priority", 0))

	# Secondary effect: a status it can give, and the chance.
	# Status codes are uppercased to match the RC1 file and the
	# battle engine, which check "PAR", "BRN", "PSN", "TOX", "SLP"
	# and "FRZ" (Showdown writes them lowercase, like "par").
	# Some moves carry the status at the top level instead of in
	# "secondary" (Thunder Wave, Will-O-Wisp, Toxic, Sleep Powder
	# and the like): when the move hits, that status always applies,
	# so the chance is 100. No move has both, so the secondary one
	# wins when it is there.
	# An empty secondary dict {} means no secondary effect at all
	# (it is a Sheer Force marker in Showdown), so it is skipped
	# here with no flag and nothing stored.
	var status: String = ""
	var status_chance: int = 0
	var secondary_chance: int = 0
	var secondary_block: Dictionary = {}
	if showdown_move.has("secondary"):
		var secondary_value: Variant = showdown_move.get("secondary", {})
		if secondary_value is Dictionary:
			secondary_block = secondary_value
			if secondary_block.is_empty():
				secondary_block = {}
			else:
				status = str(secondary_block.get("status", "")).to_upper()
				if secondary_block.has("chance"):
					secondary_chance = int(secondary_block.get("chance", 0))
				else:
					reasons.append("secondary has no chance")
	if status.is_empty() and showdown_move.has("status"):
		status = str(showdown_move.get("status", "")).to_upper()
		status_chance = 100
	elif not status.is_empty():
		# status_chance is the chance to apply the STATUS, so it only
		# comes from the secondary when a status is actually being
		# applied. A secondary that only drops stats, flinches or
		# confuses has no status, so its chance stays 0 here — but
		# the raw "secondary" block is kept on the mapped move, and
		# MoveEffects reads the real chance from it (flinch, stat
		# drops, confusion and the rest). Nothing is lost.
		status_chance = secondary_chance

	var mapped: Dictionary = {
		"name": move_name,
		"num": move_num,
		"type": move_type,
		"cat": cat,
		"power": power,
		"acc": acc,
		"pp": base_pp,
		"base_pp": base_pp,
		"pp_max": pp_max,
		"priority": priority,
		"needs_attention": "",
	}

	if always_hits:
		mapped["always_hits"] = true

	# The damage rule for basePower-0 damaging moves, with the
	# numbers the rule needs. This replaces the old v4 flag.
	if not rule_fields.is_empty():
		mapped.merge(rule_fields)

	# "status" and "status_chance" only exist on the move when it
	# actually applies a status, exactly like the RC1 file (only 14
	# of its 94 moves carry the keys). The battle controller tests
	# move.has("status"), so an empty "status" key on every move
	# would print a bogus "got status !" line; and AbilityEngine's
	# Sheer Force check tests move.has("status_chance"), so a
	# zero-valued key on every move would trip it on every move.
	if not status.is_empty():
		mapped["status"] = status
		mapped["status_chance"] = status_chance

	# Keep the raw "secondary" block on the mapped move. MoveEffects
	# reads the real chance from it for flinch, stat drops, confusion
	# and self boosts, which the RC1 "status"/"status_chance" pair
	# cannot express on its own. An empty block is not kept: it
	# means there is no secondary effect.
	if not secondary_block.is_empty():
		mapped["secondary"] = secondary_block

	# Copy the "self" block through (chance and boosts, when they
	# are there) and the "selfBoost" block. V4 dropped both, which
	# lost every self boost. They are plain data, so they are kept
	# exactly as they are in the source. MoveEffects reads them.
	# Note: a few "self" blocks hold a function placeholder instead
	# of plain boosts (the G-Max and Max moves, and a few others).
	# Those are kept as-is too; they are markers, not numbers.
	if showdown_move.has("self"):
		var self_value: Variant = showdown_move.get("self", {})
		if self_value is Dictionary:
			mapped["self"] = self_value
	if showdown_move.has("selfBoost"):
		var self_boost_value: Variant = showdown_move.get("selfBoost", {})
		if self_boost_value is Dictionary:
			mapped["selfBoost"] = self_boost_value

	# A move that switches the user out keeps that flag, and also gets
	# the RC1 "pivot" key for the same idea. Note that selfSwitch is
	# not always a plain true: Baton Pass stores "copyvolatile" and
	# Shed Tail stores "shedtail" there, so the raw value is kept and
	# never passed through bool(), which cannot read a String.
	var self_switch_value: Variant = showdown_move.get("selfSwitch", false)
	if self_switch_value:
		mapped["selfSwitch"] = self_switch_value
		mapped["pivot"] = true

	# A move that hits more than once keeps its multihit value.
	# basePower in Showdown is the power of ONE hit, and MoveEffects
	# already rolls the real hit count, so this needs no flag.
	if showdown_move.has("multihit"):
		mapped["multihit"] = showdown_move.get("multihit", null)

	# The hazard the move sets on the foe's side after it hits.
	if SETS_HAZARD.has(slug):
		mapped["sets_hazard"] = str(SETS_HAZARD.get(slug, ""))

	# Keep the move's own flags, volatile status, target boosts and
	# field markers exactly as Showdown writes them. They are plain
	# data (no functions): flags.contact is what Tough Claws,
	# Piercing Drill and Unseen Fist read; volatileStatus
	# "confusion" is what the controller's status-move path reads
	# (Swagger, Supersonic); boosts is what _apply_status_move
	# reads for the defender's stat change; sideCondition and
	# pseudoWeather are what _is_field_move reads (Tailwind, Trick
	# Room, Gravity, Safeguard, the Rooms).
	if showdown_move.get("flags", {}) is Dictionary and not Dictionary(showdown_move.get("flags", {})).is_empty():
		mapped["flags"] = showdown_move.get("flags", {})
	if str(showdown_move.get("volatileStatus", "")) != "":
		mapped["volatileStatus"] = str(showdown_move.get("volatileStatus", ""))
	if showdown_move.get("boosts", {}) is Dictionary and not Dictionary(showdown_move.get("boosts", {})).is_empty():
		mapped["boosts"] = showdown_move.get("boosts", {})
	if str(showdown_move.get("sideCondition", "")) != "":
		mapped["sideCondition"] = str(showdown_move.get("sideCondition", ""))
	if str(showdown_move.get("pseudoWeather", "")) != "":
		mapped["pseudoWeather"] = str(showdown_move.get("pseudoWeather", ""))

	mapped["needs_attention"] = "; ".join(reasons)
	return mapped


## Load the whole official moves JSON file and map every move.
## moves_json_path is the path to the file, for example
## "res://data/moves.json".
## Returns {"moves": Dictionary keyed by lowercase move id/slug,
## "total": int, "mapped_clean": int,
## "needs_attention": Array of {"id": String, "reason": String}}.
## In v5, mapped_clean is 954 and needs_attention is empty.
static func load_official(moves_json_path: String) -> Dictionary:
	var empty_moves: Dictionary = {}
	var empty_notes: Array = []
	var result: Dictionary = {
		"moves": empty_moves,
		"total": 0,
		"mapped_clean": 0,
		"needs_attention": empty_notes,
	}
	if not FileAccess.file_exists(moves_json_path):
		var notes: Array = result["needs_attention"]
		notes.append({"id": "", "reason": "moves file not found at " + moves_json_path})
		return result
	var raw: String = FileAccess.get_file_as_string(moves_json_path)
	var parsed: Variant = JSON.parse_string(raw)
	var moves_in: Dictionary = {}
	if parsed is Dictionary:
		var parsed_dict: Dictionary = parsed
		if parsed_dict.has("moves") and parsed_dict.get("moves") is Dictionary:
			moves_in = parsed_dict["moves"]
		else:
			# No "moves" wrapper: treat the whole file as the move table.
			moves_in = parsed_dict
	else:
		var bad_notes: Array = result["needs_attention"]
		bad_notes.append({"id": "", "reason": "moves file did not parse as a JSON object: " + moves_json_path})
		return result
	var moves_out: Dictionary = {}
	var flagged: Array = []
	var clean: int = 0
	for key in moves_in.keys():
		var entry: Variant = moves_in[key]
		if not (entry is Dictionary):
			continue
		var mapped: Dictionary = map_move(entry)
		var slug: String = rc1_key(str(mapped.get("name", "")))
		if slug.is_empty():
			slug = str(key).to_lower()
		moves_out[slug] = mapped
		var note: String = str(mapped.get("needs_attention", ""))
		if note.is_empty():
			clean += 1
		else:
			flagged.append({"id": slug, "reason": note})
	result["moves"] = moves_out
	result["total"] = moves_out.size()
	result["mapped_clean"] = clean
	result["needs_attention"] = flagged
	return result


## The lowercase slug key used in the moves dict.
## Lowercase, with spaces, hyphens, apostrophes, commas and any other
## character that is not a letter or a number removed.
## For example: "Thunderbolt" -> "thunderbolt", "U-turn" -> "uturn",
## "10,000,000 Volt Thunderbolt" -> "10000000voltthunderbolt".
## This matches the ids Showdown itself uses as keys in moves.json.
static func rc1_key(move_name: String) -> String:
	var out: String = ""
	var lowered: String = move_name.to_lower()
	for i in range(lowered.length()):
		var ch: String = lowered[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out
