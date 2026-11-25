class_name ItemEngine
extends RefCounted
## Item engine for Pokemon Ultimate World, battle engine v2.
## Plain rules, no made-up numbers. Every number here comes from the task
## spec or from items_full_compact.json (2,241 items; only 954 have a short
## English effect and 944 a full effect in that source file, the rest have
## no English effect text, so unknown items return no text and do nothing).
##
## Held items are read from mon["item"]. The name may be a display name
## ("Leftovers") or a slug ("leftovers"). Both work: names are matched
## after lowercasing and removing spaces, hyphens, underscores and
## apostrophes.
##
## Notes on numbers that differ between sources:
## - Pinch berries (Figy, Wiki, Mago, Aguav, Iapapa) heal 1/2 max HP at
##   1/4 max HP or less here, as the task spec says. The older effect text
##   in items_full_compact.json says 1/8 at 1/2 HP; the spec value is used.
## - Quick Ball is 5.0 on turn 1 here, as the task spec says. The source
##   effect text says 4x (Gen V: 5x).
## - Dusk Ball is 3.0 at night or in caves (task spec value; the
##   source effect text says 3.5x). The night_or_cave flag on
##   get_ball_bonus carries it. The battle controller passes the
##   flag from battle_state["night_or_cave"].
## - Heavy-Duty Boots has no effect_short text in items_full_compact.json,
##   so get_item_effect_text returns "" for it even though ignores_hazards
##   handles it. That is honest, not a bug.
## - Choice Scarf raises Speed, not damage, so it does not appear in
##   modify_attack_damage. Speed is owned by TurnResolver.

## Small table of effect text, copied word for word from the
## effect_short field of items_full_compact.json, for the items this
## engine handles. Items with no effect_short in that file are not here.

const ITEM_EFFECT_TEXT := {
	"choiceband": "Held: Increases Attack by 50%, but restricts the holder to only one move.",
	"choicespecs": "Held: Increases Special Attack by 50%, but restricts the holder to only one move.",
	"choicescarf": "Held: Increases Speed by 50%, but restricts the holder to only one move.",
	"lifeorb": "Held: Holder’s moves inflict 30% extra damage, but cost 10% max HP.",
	"eviolite": "Held: Holder has 1.5× Defense and Special Defense, as long as it’s not fully evolved.",
	"assaultvest": "Raises the holder’s Special Defense to 1.5×.  Prevents the holder from selecting a status move.",
	"focussash": "Held: Holder survives any single-hit attack at 1 HP if at max HP, then the item is consumed.",
	"leftovers": "Held: Restores 1/16 (6.25%) holder’s max HP at the end of each turn.",
	"sitrusberry": "Consumed at 1/2 max HP to recover 1/4 max HP.",
	"figyberry": "Consumed at 1/2 max HP to restore 1/8 max HP. Confuses Pokémon that dislike spicy flavor.",
	"wikiberry": "Consumed at 1/2 max HP to restore 1/8 max HP. Confuses Pokémon that dislike dry flavor.",
	"magoberry": "Consumed at 1/2 max HP to restore 1/8 max HP. Confuses Pokémon that dislike sweet flavor.",
	"aguavberry": "Consumed at 1/2 max HP to restore 1/8 max HP. Confuses Pokémon that dislike bitter flavor.",
	"iapapaberry": "Consumed at 1/2 max HP to restore 1/8 max HP. Confuses Pokémon that dislike sour flavor.",
	"lumberry": "Consumed to cure any status condition or confusion.",
	"weaknesspolicy": "When the holder is hit by a super effective move, its Attack and Special Attack raise by two stages.",
	"potion": "Restores 20 HP.",
	"superpotion": "Restores 50 HP.",
	"hyperpotion": "Restores 200 HP.",
	"maxpotion": "Restores HP to full.",
	"fullrestore": "Restores HP to full and cures any status ailment and confusion.",
	"antidote": "Cures poison.",
	"paralyzeheal": "Cures paralysis.",
	"awakening": "Cures sleep.",
	"burnheal": "Cures a burn.",
	"iceheal": "Cures freezing.",
	"fullheal": "Cures any status ailment and confusion.",
	"revive": "Revives with half HP.",
	"maxrevive": "Revives with full HP.",
	"pokeball": "Tries to catch a wild Pokémon.",
	"greatball": "Tries to catch a wild Pokémon.  Success rate is 1.5×.",
	"ultraball": "Tries to catch a wild Pokémon.  Success rate is 2×.",
	"masterball": "Catches a wild Pokémon every time.",
	"safariball": "Tries to catch a wild Pokémon in the Great Marsh or Safari Zone.  Success rate is 1.5×.",
	"netball": "Tries to catch a wild Pokémon.  Success rate is 3× for water and bug Pokémon.",
	"diveball": "Tries to catch a wild Pokémon. Success rate is 3.5× when underwater, fishing, or surfing.",
	"duskball": "Tries to catch a wild Pokémon.  Success rate is 3.5× at night and in caves.",
	"quickball": "Tries to catch a wild Pokémon. Success rate is 4× (Gen V: 5×), but only on the first turn.",
	"timerball": "Tries to catch a wild Pokémon. Success rate increases by 0.1× (Gen V: 0.3×) every turn, to a max of 4×.",
	"repeatball": "Tries to catch a wild Pokémon.  Success rate is 3× for previously-caught Pokémon.",
	"luxuryball": "Tries to catch a wild Pokémon.  Caught Pokémon start with 200 happiness.",
	"healball": "Tries to catch a wild Pokémon.  Caught Pokémon are immediately healed.",
	"friendball": "Caught Pokémon start with 200 happiness. Made from Grn Apricorn.",
	"premierball": "Tries to catch a wild Pokémon.",
	"luckyegg": "Held: Increases EXP earned in battle by 50%.",
	"shinycharm": "Raises the chance of finding a shiny Pokémon.",
}

const _CHOICE_ITEMS := ["choiceband", "choicespecs", "choicescarf"]
const _PINCH_BERRIES := ["figyberry", "wikiberry", "magoberry", "aguavberry", "iapapaberry"]


## Stat Berry slug -> stage key it raises by 1 (Showdown items.ts:
## Liechi Atk, Ganlon Def, Salac Spe, Petaya SpA, Apicot SpD).
const _STAT_BERRIES := {
	"liechiberry": "atk", "ganlonberry": "def", "salacberry": "spe",
	"petayaberry": "spa", "apicotberry": "spd",
}


## Weaken Berry slug -> move type it halves (Showdown items.ts and
## the effect_short text in items_full_compact.json). Chilan Berry
## halves any Normal-type hit; the other 17 need a super-effective
## hit (checked in check_weaken_berry, not here).
const _WEAKEN_BERRY_TYPES := {
	"babiriberry": "steel", "chartiberry": "rock",
	"chilanberry": "normal", "chopleberry": "fighting",
	"cobaberry": "flying", "colburberry": "dark",
	"habanberry": "dragon", "kasibberry": "ghost",
	"kebiaberry": "poison", "occaberry": "fire",
	"passhoberry": "water", "payapaberry": "psychic",
	"rindoberry": "grass", "roseliberry": "fairy",
	"shucaberry": "ground", "tangaberry": "bug",
	"wacanberry": "electric", "yacheberry": "ice",
}


## ------------------------------------------------------------------
## Held-item battle-hook tables (item triage TOP_BATCH.md, staged
## by code prep code_prep_items_hooks — see PREP_REPORT.md there).
## The 59 held items of the top batch whose missing piece is a
## battle hook, plus the held triggers of the six cure Berries.
## Every number is the games' own (Showdown items.ts values, the
## same source the triage's hook column names).
## ------------------------------------------------------------------

## Type-boost held items: matching-type moves x1.2, never
## consumed. Only the four set-used members of the family are in
## the top batch (the rest of the family is next in line).
const _TYPE_BOOST_ITEMS := {
	"blackglasses": "dark", "magnet": "electric",
	"mysticwater": "water", "twistedspoon": "psychic",
}


## Weather rock slug per weather word: while the holder sets
## that weather (by move or ability), it lasts 8 turns not 5.
const _WEATHER_ROCKS := {
	"sun": "heatrock", "rain": "damprock", "sand": "smoothrock",
	"snow": "icyrock", "hail": "icyrock",
}


## Terrain seed slug per terrain word -> stage key it raises by
## 1 when the holder enters (or the terrain starts under it).
## Electric and Grassy Seeds raise Defense; Misty and Psychic
## Seeds raise Special Defense.
const _TERRAIN_SEEDS := {
	"electric": ["electricseed", "def"], "grassy": ["grassyseed", "def"],
	"misty": ["mistyseed", "spd"], "psychic": ["psychicseed", "spd"],
}


## Held cure Berry slug -> the status code it cures the moment
## that status lands (the status-application choke point is
## AbilityEngine.try_set_status; see on_status_set). Persim
## Berry is not here: confusion is a volatile, not a status
## code, and is handled in update_item_checks.
const _HELD_CURE_BERRIES := {
	"cheriberry": "PAR", "pechaberry": "PSN", "rawstberry": "BRN",
	"aspearberry": "FRZ", "chestoberry": "SLP",
}


## The two-turn charge moves (Showdown's twoturnmove volatile
## users, minus the airborne moves Fly / Bounce / Dig / Dive /
## Phantom Force / Shadow Force / Sky Drop, which this engine
## already runs through its own airborne system). There is no
## charge-turn state machine in the engine yet, so Power Herb
## has only this recognition half here; the minimal controller
## addition is staged with this prep (see PREP_REPORT.md).
const _CHARGE_MOVE_IDS := [
	"solarbeam", "solarblade", "skullbash", "razorwind",
	"skyattack", "freezeshock", "iceburn", "geomancy",
	"meteorbeam", "electroshot",
]


## ------------------------------------------------------------------
## Top-batch use-path tables (item triage TOP_BATCH.md, staged by
## code prep code_prep_items — see PREP_REPORT.md there). Values
## are the games' own: healing drinks from their effect text,
## X items at the Gen 7+ two-stage raise (the triage version
## register), EV Berries at -10 EV in one stat, Repels at
## 100/200/250 steps, Tera Shards at a cost of 50.
## ------------------------------------------------------------------

## Healing drink slug -> HP restored (effect_short values in
## items_full_compact.json).
const _HEAL_DRINKS := {
	"freshwater": 50, "sodapop": 60, "lemonade": 80,
	"moomoomilk": 100, "energyroot": 200,
}


## X item slug -> stage key it raises by 2 (Gen 7+).
const _X_STAGE_ITEMS := {
	"xattack": "atk", "xdefense": "def", "xspeed": "spe",
	"xspatk": "spa",
}


## EV Berry slug -> EV key it lowers by 10.
const _EV_BERRIES := {
	"pomegberry": "hp", "kelpsyberry": "atk", "qualotberry": "def",
	"hondewberry": "spa", "grepaberry": "spd", "tamatoberry": "spe",
}


## ------------------------------------------------------------------
## Gap-closure additions (code prep code_prep_item_engine_gaps —
## gap G1 of code_prep_item_target/PREP_REPORT.md: these classes
## had NO handler anywhere in the bound code). Every value is
## from held data, cited per table.
## ------------------------------------------------------------------

## The EV caps of the difficulty canon (qa_desk/RULES_REFRESHER:
## 252 per stat, 510 total — the same ceilings PUWTeamBuilder's
## spreads obey). The vitamin prose's "won't increase it beyond
## 100" is the pre-Gen-8 sub-cap; the canon's current-gen
## ceilings govern here, the same ruling style as
## PUWItemServices' hyper-training level note.
const EV_STAT_CAP := 252
const EV_TOTAL_CAP := 510


## Vitamin slug -> EV key it raises by VITAMIN_EV_GAIN. Source:
## PokeAPI item prose (held at data_registry/src/pokeapi item_
## prose.csv, item ids 45-49 and 52): "Increases <stat> effort
## by 10" — HP Up/HP, Protein/Attack, Iron/Defense, Carbos/
## Speed, Calcium/Special Attack, Zinc/Special Defense.
const VITAMIN_EV_GAIN := 10
const _VITAMINS := {
	"hpup": "hp", "protein": "atk", "iron": "def",
	"calcium": "spa", "zinc": "spd", "carbos": "spe",
}


## Feather (Wing) slug -> EV key it raises by FEATHER_EV_GAIN.
## Source: items_full_compact.json effect_short ("Increases HP
## effort by 1." and siblings) and PokeAPI item prose ids
## 606-611, same values. Both spellings are keyed: the compact
## slug is "health-wing" (normalised "healthwing") while its
## display name is "Health Feather" ("healthfeather"). Pretty
## Wing is NOT here: it has no use effect in the games.
const FEATHER_EV_GAIN := 1
const _FEATHERS := {
	"healthwing": "hp", "healthfeather": "hp",
	"musclewing": "atk", "musclefeather": "atk",
	"resistwing": "def", "resistfeather": "def",
	"geniuswing": "spa", "geniusfeather": "spa",
	"cleverwing": "spd", "cleverfeather": "spd",
	"swiftwing": "spe", "swiftfeather": "spe",
}


## EXP Candy slug -> EXP granted to the chosen mon. Values
## triple-sourced by the hunt desk (hidden_files/hunt_desk/
## rotation_current/2026-11-24/ROTATION_REPORT.md, target 1):
## Bulbapedia's "Exp. Candy" Exp. yield table, PokémonDB's
## item pages ("Exp. Candy XS increases a Pokémon's Exp.
## Points by 100") and Serebii's ItemDex agree exactly.
## (code prep code_prep_exp_candy — this table replaces the
## gaps prep's refusal, which stood only because no held
## source defined the amounts; the hunt desk sourced them.)
const _EXP_CANDIES := {
	"expcandyxs": 100, "expcandys": 800, "expcandym": 3000,
	"expcandyl": 10000, "expcandyxl": 30000,
}


## Nature mint slug -> the nature it sets. Source: the mints'
## own names — items_full_compact.json files all 21 under
## category "nature-mints" with display names "<Nature> Mint",
## and every named nature exists in the bound nature table
## (PUWTeamBuilder.NATURES, systems/difficulty/team_builder.gd).
## A mint writes the mon's "nature" — the one field the bound
## stat computation reads — which is the current games'
## behaviour (Gen 9 mints change the nature itself).
const _MINT_NATURES := {
	"lonelymint": "Lonely", "adamantmint": "Adamant",
	"naughtymint": "Naughty", "bravemint": "Brave",
	"boldmint": "Bold", "impishmint": "Impish",
	"laxmint": "Lax", "relaxedmint": "Relaxed",
	"modestmint": "Modest", "mildmint": "Mild",
	"rashmint": "Rash", "quietmint": "Quiet",
	"calmmint": "Calm", "gentlemint": "Gentle",
	"carefulmint": "Careful", "sassymint": "Sassy",
	"timidmint": "Timid", "hastymint": "Hasty",
	"jollymint": "Jolly", "naivemint": "Naive",
	"seriousmint": "Serious",
}


## Tera Shard slug (normalised) -> [Tera type display name,
## canonical registry id]. 18 shards, one per type.
const _TERA_SHARDS := {
	"normalterashard": ["Normal", "normal-tera-shard"],
	"fireterashard": ["Fire", "fire-tera-shard"],
	"waterterashard": ["Water", "water-tera-shard"],
	"electricterashard": ["Electric", "electric-tera-shard"],
	"grassterashard": ["Grass", "grass-tera-shard"],
	"iceterashard": ["Ice", "ice-tera-shard"],
	"fightingterashard": ["Fighting", "fighting-tera-shard"],
	"poisonterashard": ["Poison", "poison-tera-shard"],
	"groundterashard": ["Ground", "ground-tera-shard"],
	"flyingterashard": ["Flying", "flying-tera-shard"],
	"psychicterashard": ["Psychic", "psychic-tera-shard"],
	"bugterashard": ["Bug", "bug-tera-shard"],
	"rockterashard": ["Rock", "rock-tera-shard"],
	"ghostterashard": ["Ghost", "ghost-tera-shard"],
	"dragonterashard": ["Dragon", "dragon-tera-shard"],
	"darkterashard": ["Dark", "dark-tera-shard"],
	"steelterashard": ["Steel", "steel-tera-shard"],
	"fairyterashard": ["Fairy", "fairy-tera-shard"],
}


## Shards one Tera Type change costs in the games.
const TERA_SHARD_COST := 50


## Effect text for the top-batch items, copied word for word
## from the effect_short field of items_full_compact.json, the
## same source as ITEM_EFFECT_TEXT. Items with no effect_short
## in that file (Ability Patch, the Tera Shards) are not here,
## the same honest gap as Heavy-Duty Boots in the main table.
const ITEM_EFFECT_TEXT_TOP_BATCH := {
	"freshwater": "Restores 50 HP.",
	"sodapop": "Restores 60 HP.",
	"lemonade": "Restores 80 HP.",
	"moomoomilk": "Restores 100 HP.",
	"energyroot": "Restores 200 HP, but lowers happiness.",
	"lavacookie": "Cures any status ailment and confusion.",
	"cheriberry": "Held: Consumed when paralyzed to cure paralysis.",
	"pechaberry": "Held: Consumed when poisoned to cure poison.",
	"rawstberry": "Held: Consumed when burned to cure a burn.",
	"aspearberry": "Held: Consumed when frozen to cure frozen.",
	"chestoberry": "Held: Consumed when asleep to cure sleep.",
	"persimberry": "Held: Consumed when confused to cure confusion.",
	"pomegberry": "Drops HP Effort Values by 10 and raises happiness.",
	"kelpsyberry": "Drops Attack Effort Values by 10 and raises happiness.",
	"qualotberry": "Drops Defense Effort Values by 10 and raises happiness.",
	"hondewberry": "Drops Special Attack Effort Values by 10 and raises happiness.",
	"grepaberry": "Drops Special Defense Effort Values by 10 and raises happiness.",
	"tamatoberry": "Drops Speed Effort Values by 10 and raises happiness.",
	"hpup": "Raises HP effort and happiness.",
	"protein": "Raises Attack effort and happiness.",
	"iron": "Raises Defense effort and happiness.",
	"carbos": "Raises Speed effort and happiness.",
	"calcium": "Raises Special Attack effort and happiness.",
	"zinc": "Raises Special Defense and happiness.",
	"healthwing": "Increases HP effort by 1.",
	"healthfeather": "Increases HP effort by 1.",
	"musclewing": "Increases Attack effort by 1.",
	"musclefeather": "Increases Attack effort by 1.",
	"resistwing": "Increases Defense effort by 1.",
	"resistfeather": "Increases Defense effort by 1.",
	"geniuswing": "Increases Special Attack effort by 1.",
	"geniusfeather": "Increases Special Attack effort by 1.",
	"cleverwing": "Increases Special Defense effort by 1.",
	"cleverfeather": "Increases Special Defense effort by 1.",
	"swiftwing": "Increases Speed effort by 1.",
	"swiftfeather": "Increases Speed effort by 1.",
	"revivalherb": "Revives with full HP, but lowers happiness.",
	"xattack": "Raises Attack by one stage in battle.  Raises happiness.",
	"xdefense": "Raises Defense by one stage in battle.  Raises happiness.",
	"xspeed": "Raises Speed by one stage in battle.  Raises happiness.",
	"xspatk": "Raises Special Attack by one stage in battle.  Raises happiness.",
	"direhit": "Increases the chance of a critical hit in battle.  Raises happiness.",
	"ether": "Restores 10 PP for one move.",
	"maxether": "Restores PP to full for one move.",
	"elixir": "Restores 10 PP for each move.",
	"ppup": "Raises a move’s max PP by 20%.",
	"ppmax": "Raises a move’s max PP by 60%.",
	"abilitycapsule": "Switches a Pokémon between its two possible (non-Hidden) Abilities.",
	"rarecandy": "Causes a level-up and raises happiness.",
	"sacredash": "Revives all fainted Pokémon with full HP.",
	"repel": "For 100 steps, prevents wild encounters of level lower than your party’s lead Pokémon.",
	"superrepel": "For 200 steps, prevents wild encounters of level lower than your party’s lead Pokémon.",
	"maxrepel": "For 250 steps, prevents wild encounters of level lower than your party’s lead Pokémon.",
	"escaperope": "Transports user to the outside entrance of a cave.",
	"pokedoll": "Ends a wild battle.",
	"fluffytail": "Ends a wild battle.",
}



## Turn any display name or slug into one plain key, e.g. "Heavy-Duty
## Boots" and "heavy-duty-boots" both become "heavydutyboots".
static func _norm(raw: String) -> String:
	var s := raw.to_lower()
	s = s.replace(" ", "").replace("-", "").replace("_", "").replace("'", "")
	return s


## Held item of a mon, normalised. "" when the mon holds nothing.
static func _held(mon: Dictionary) -> String:
	return _norm(str(mon.get("item", "")))


## Public read of _held, for the other battle files (MoveEffects'
## Loaded Dice roll, the calculator's crit and stat paths).
static func held_item(mon: Dictionary) -> String:
	return _held(mon)


## True when a move carries the named flag. moves.json marks
## flags with flags.<name> = 1; RC1 move dicts may carry a
## top-level bool. The same convention as AbilityEngine's _flag.
static func _flag(move: Dictionary, key: String) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get(key, false)):
		return true
	return bool(move.get(key, false))


## True when the move makes contact (flags.contact, or a
## top-level "contact" bool on RC1 move dicts).
static func _is_contact(move: Dictionary) -> bool:
	return _flag(move, "contact")


## A mon's species as one lower-case key ("Farfetch'd" ->
## "farfetch'd"). The species key first, the display name as
## fallback: test mons and team-built mons both carry "species",
## but a hand-made mon may only carry "name".
static func _species_of(mon: Dictionary) -> String:
	var sp: String = str(mon.get("species", ""))
	if sp == "":
		sp = str(mon.get("name", ""))
	return sp.to_lower()


## True when the mon has the named type (case-insensitive).
static func _has_type(mon: Dictionary, wanted: String) -> bool:
	for t in mon.get("types", []):
		if str(t).to_lower() == wanted.to_lower():
			return true
	return false


## Heal a mon by an amount, never above max HP. Returns the HP healed.
static func _heal(mon: Dictionary, amount: int) -> int:
	var max_hp := int(mon.get("max_hp", 100))
	var hp := int(mon.get("hp", 0))
	if hp <= 0 or amount <= 0:
		return 0
	var healed := mini(amount, max_hp - hp)
	mon["hp"] = hp + healed
	return healed


## Use up a held item: clear it and record what was used.
static func _consume(mon: Dictionary, display_name: String, logs: Array, field: Dictionary = {}) -> void:
	var used_id: String = str(mon.get("item", ""))
	mon["item"] = ""
	mon["item_consumed"] = display_name
	# Held-item use: tell the ability engine (Symbiosis hands the
	# holder's item to this mon when its ally used one; Pickup
	# records the item). The ally comes from mon["ally"], set by
	# the controller in doubles; in singles it is empty and
	# Symbiosis cannot fire, which matches Showdown (doubles-only).
	if not field.is_empty():
		AbilityEngine.on_item_use(mon, used_id, field, logs, mon.get("ally", {}))
	logs.append("%s used up its %s!" % [mon.get("name", "Pokémon"), display_name])


## Clear the Ripen eat flags after a Berry's effect has been
## applied. ripen_berry_weaken is NOT cleared here: the weaken
## Berry is eaten during damage, and Batch3 damage_mult spends
## that flag in the same hit.
static func _clear_ripen_flags(mon: Dictionary) -> void:
	mon.erase("ripen_double")
	mon.erase("ripen_ate_berry")


## Raise one stat stage by an amount, clamped between -6 and +6.
## Used for stat Berries (the holder's own item, so no ability
## block is checked, same as Weakness Policy in on_damage_taken).
static func _raise_stage(mon: Dictionary, key: String, amount: int, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if key == "":
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var names := {"atk": "Attack", "def": "Defense", "spa": "Special Attack", "spd": "Special Defense", "spe": "Speed"}
	if not names.has(key):
		return
	var before: int = int(stages.get(key, 0))
	var after: int = clampi(before + amount, -6, 6)
	stages[key] = after
	mon["stages"] = stages
	if after != before:
		logs.append("%s's %s rose!" % [mon.get("name", "Pokémon"), str(names[key])])


## Raise a random stat that is not already at +6, for Starf Berry.
## Nothing rises when every stat is already at +6.
static func _raise_random_stage(mon: Dictionary, amount: int, logs: Array) -> void:
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var open_keys: Array = []
	for key in ["atk", "def", "spa", "spd", "spe"]:
		if int(stages.get(key, 0)) < 6:
			open_keys.append(key)
	if open_keys.is_empty():
		return
	var pick: String = str(open_keys[randi_range(0, open_keys.size() - 1)])
	_raise_stage(mon, pick, amount, logs)


## First move (in mon["moves"] order) with 0 PP left, or "" when
## every move still has PP. Falls back to the pp dict order when
## the mon has no moves list.
static func _first_empty_pp_move(mon: Dictionary, pp_map: Dictionary) -> String:
	for m in mon.get("moves", []):
		if int(pp_map.get(str(m), -1)) == 0:
			return str(m)
	for key in pp_map.keys():
		if int(pp_map.get(key, -1)) == 0:
			return str(key)
	return ""


## Give a move back some PP, never above its max PP when the mon
## records one in mon["pp_max"]. Without a pp_max record there is
## nothing to cap against, so the PP is added as-is.
static func _restore_pp(mon: Dictionary, move_name: String, gain: int, logs: Array) -> void:
	var pp_map: Dictionary = mon.get("pp", {})
	var pp_max_map: Dictionary = mon.get("pp_max", {})
	var cur: int = int(pp_map.get(move_name, 0))
	var cap: int = int(pp_max_map.get(move_name, 0))
	var new_pp: int = cur + gain
	if cap > 0:
		new_pp = mini(new_pp, cap)
	pp_map[move_name] = new_pp
	mon["pp"] = pp_map
	logs.append("%s restored PP to %s (+%d PP)!" % [mon.get("name", "Pokémon"), move_name, gain])


static func is_choice_item(item: String) -> bool:

	return _norm(item) in _CHOICE_ITEMS


## The move a Choice item locks the mon into, or "" when not locked.
static func choice_locked_move(mon: Dictionary) -> String:
	return str(mon.get("choice_lock", ""))


## Attacker damage multipliers and defender defence multipliers.
## Choice Band 1.5x on Physical, Choice Specs 1.5x on Special,
## Life Orb 1.3x. Eviolite means 1.5x both defences, so damage is
## divided by 1.5 when the holder can still evolve (mon["can_evolve"]).
## Assault Vest means 1.5x Special Defence, so Special damage is
## divided by 1.5. Returns at least 1 when base_dmg is 1 or more.
static func modify_attack_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> int:
	if base_dmg < 1:
		return 0
	var mult := 1.0
	var held := _held(attacker)
	var cat := str(move.get("cat", move.get("category", "")))
	if held == "choiceband" and cat == "Physical":
		mult *= 1.5
	if held == "choicespecs" and cat == "Special":
		mult *= 1.5
	if held == "lifeorb":
		mult *= 1.3
	# Held-item battle hooks (code_prep_items_hooks). Type-boost
	# family: a move of the matching type is x1.2.
	var move_type: String = str(move.get("type", "")).to_lower()
	if _TYPE_BOOST_ITEMS.has(held) and move_type == str(_TYPE_BOOST_ITEMS[held]):
		mult *= 1.2
	# Soul Dew (Gen 7+ form): Latias / Latios only, their Dragon
	# and Psychic moves x1.2.
	if held == "souldew" and (_species_of(attacker) == "latias" or _species_of(attacker) == "latios"):
		if move_type == "dragon" or move_type == "psychic":
			mult *= 1.2
	# Adamant Orb: Dialga's Steel and Dragon moves x1.2.
	# Lustrous Orb: Palkia's Water and Dragon moves x1.2.
	if held == "adamantorb" and _species_of(attacker) == "dialga":
		if move_type == "steel" or move_type == "dragon":
			mult *= 1.2
	if held == "lustrousorb" and _species_of(attacker) == "palkia":
		if move_type == "water" or move_type == "dragon":
			mult *= 1.2
	# Expert Belt: x1.2 when the move is super effective against
	# the defender (effectiveness >= 2). The effectiveness is
	# worked out from the type chart here, because this function
	# runs before the controller stamps last_effectiveness.
	if held == "expertbelt":
		var def_types := PackedStringArray()
		for t in defender.get("types", []):
			def_types.append(str(t))
		if PUWBattleEngine.type_multiplier(str(move.get("type", "Normal")), def_types) >= 2.0:
			mult *= 1.2
	# Metronome (the item, not the move): the same move used
	# over and over gains +20% per repeat, capped at x2.0. The
	# streak lives on the mon (metronome_streak /
	# metronome_last_move) and is advanced by on_after_move.
	if held == "metronome":
		var move_key: String = _norm(str(move.get("name", move.get("id", ""))))
		if move_key != "" and move_key == str(attacker.get("metronome_last_move", "")):
			var streak: int = int(attacker.get("metronome_streak", 0))
			if streak > 0:
				mult *= minf(1.0 + 0.2 * float(streak), 2.0)
	var divisor := 1.0
	var def_held := _held(defender)
	if def_held == "eviolite" and bool(defender.get("can_evolve", false)):
		divisor *= 1.5
	if def_held == "assaultvest" and cat == "Special":
		divisor *= 1.5
	var dmg := int(round(float(base_dmg) * mult / divisor))
	return maxi(1, dmg)


## Life Orb recoil: the attacker loses 10% of its max HP, rounded
## down, at least 1. Only when it held a Life Orb, dealt damage,
## and still has HP left.
static func apply_recoil_after_attack(attacker: Dictionary, dealt_dmg: int, logs: Array) -> void:
	if _held(attacker) != "lifeorb":
		return
	if dealt_dmg <= 0:
		return
	if int(attacker.get("hp", 0)) <= 0:
		return
	var loss := maxi(1, int(floor(float(int(attacker.get("max_hp", 100))) / 10.0)))
	attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - loss)
	logs.append("%s was hurt by its Life Orb (-%d HP)!" % [attacker.get("name", "Pokémon"), loss])


## Shell Bell: the holder heals 1/8 of the damage it dealt,
## rounded down. Beside apply_recoil_after_attack (the
## controller calls both after a move's damage is totalled).
## Heal Block blocks the heal, the same gate as the drain
## heals in MoveEffects.
static func apply_shell_bell_after_attack(attacker: Dictionary, dealt_dmg: int, logs: Array) -> void:
	if _held(attacker) != "shellbell":
		return
	if dealt_dmg <= 0:
		return
	if int(attacker.get("hp", 0)) <= 0:
		return
	if int(attacker.get("heal_block_turns", 0)) > 0 or int(attacker.get("noise_heal_block_turns", 0)) > 0:
		return
	var gain: int = int(floor(float(dealt_dmg) / 8.0))
	if gain <= 0:
		return
	var healed: int = _heal(attacker, gain)
	if healed > 0:
		logs.append("%s restored HP with its Shell Bell (+%d HP)!" % [attacker.get("name", "Pokémon"), healed])


## Focus Sash: at full HP, a hit that would faint the holder leaves
## it at 1 HP instead and the sash is used up. Anything else leaves
## the damage unchanged.
static func check_focus_sash(defender: Dictionary, would_be_dmg: int) -> int:
	if _held(defender) != "focussash":
		return would_be_dmg
	var hp := int(defender.get("hp", 0))
	var max_hp := int(defender.get("max_hp", 100))
	if hp != max_hp:
		return would_be_dmg
	if would_be_dmg < hp:
		return would_be_dmg
	defender["item"] = ""
	defender["item_consumed"] = "Focus Sash"
	return hp - 1


## Red Card: when the holder is hit by a damaging move and
## stays standing, the card is consumed and the ATTACKER is
## dragged out (through the controller's _handle_forced_switch,
## so Suction Cups, Guard Dog and Commander can still refuse
## it). Returns true when the card fired; the caller clears
## nothing — the item is already consumed here.
static func check_red_card(defender: Dictionary) -> bool:
	if _held(defender) != "redcard":
		return false
	if int(defender.get("hp", 0)) <= 0:
		return false
	defender["item"] = ""
	defender["item_consumed"] = "Red Card"
	return true


## Focus Band: a 10% chance to survive a hit that would knock
## the holder out, leaving it at 1 HP. Unlike Focus Sash it
## works at any HP and is NOT consumed. The controller calls
## this beside check_focus_sash at every damage site; the rng
## is the battle's own, passed in.
static func check_focus_band(defender: Dictionary, would_be_dmg: int, rng: RandomNumberGenerator, logs: Array) -> int:
	if _held(defender) != "focusband":
		return would_be_dmg
	var hp: int = int(defender.get("hp", 0))
	if hp <= 0 or would_be_dmg < hp:
		return would_be_dmg
	if rng.randf() >= 0.10:
		return would_be_dmg
	logs.append("%s hung on with its Focus Band!" % defender.get("name", "Pokémon"))
	return hp - 1


## Eject Button: when the holder is hit by a damaging move and
## stays standing, the button is consumed and the HOLDER is
## switched out. Beside check_red_card, but the switch target
## is the holder, not the attacker: the caller runs
## _handle_forced_switch on the holder's side when this
## returns true. The item is already consumed here.
static func check_eject_button(defender: Dictionary) -> bool:
	if _held(defender) != "ejectbutton":
		return false
	if int(defender.get("hp", 0)) <= 0:
		return false
	defender["item"] = ""
	defender["item_consumed"] = "Eject Button"
	return true


## Weaken Berry: when the holder is hit by a move of the matching
## type, the berry is eaten and the damage is halved. Every weaken
## Berry needs a super-effective hit, except Chilan Berry, which
## halves any Normal-type hit (Showdown items.ts). The berry is
## eaten here, BEFORE AbilityEngine.modify_damage runs, so Ripen's
## onEatItem flag (ripen_berry_weaken) is already set when the
## Ripen damage arm reads it, and the two halves make a quarter.
## Returns the damage after the Berry, or the same damage when no
## weaken Berry applies. Unnerve is not checked here: the field
## flag cannot say whose Unnerve it is, so it cannot tell a foe's
## Unnerve from the holder's own (see the spec gaps).
static func check_weaken_berry(defender: Dictionary, move: Dictionary, effectiveness: float, damage: int, logs: Array, field: Dictionary) -> int:
	if damage <= 0:
		return damage
	var held: String = _held(defender)
	var want: String = str(_WEAKEN_BERRY_TYPES.get(held, ""))
	if want == "":
		return damage
	var mtype: String = str(move.get("type", "")).to_lower()
	if mtype != want:
		return damage
	if held != "chilanberry" and effectiveness < 2.0:
		return damage
	if int(defender.get("hp", 0)) <= 0:
		return damage
	var halved: int = maxi(1, damage / 2)
	_consume(defender, str(defender.get("item", "berry")), logs, field)
	return halved



## End of turn held-item effects. Leftovers heals 1/16 max HP.
## Sitrus Berry heals 1/4 max HP at 1/2 max HP or less, Oran Berry
## heals 10 HP at 1/2 or less, Berry Juice heals 20 HP at 1/2 or
## less, pinch berries (Figy, Wiki, Mago, Aguav, Iapapa) heal 1/2
## max HP at 1/4 or less, stat berries (Liechi, Ganlon, Salac,
## Petaya, Apicot) raise one stat 1 stage at 1/4 or less, Starf
## Berry raises a random stat 2 stages at 1/4 or less, Leppa Berry
## restores 10 PP to a move at 0 PP, Lum Berry cures any status.
## Ripen doubles every one of those Berry effects. The berry is
## eaten first (_consume runs on_item_use, which sets
## mon["ripen_double"]), then the effect is doubled when that flag
## is set, then the flag is cleared. Fainted mons get nothing.
static func on_end_of_turn(mon: Dictionary, field: Dictionary, logs: Array, foe_has_unnerve: bool = false) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	# Magic Room: while it is up, held items have no effect at
	# all, so nothing in this function runs — no Leftovers, no
	# end-of-turn Berry.
	if int(field.get("magic_room", 0)) > 0:
		return
	var max_hp := int(mon.get("max_hp", 100))
	var held := _held(mon)
	if held == "leftovers":
		# Heal Block blocks the Leftovers heal, from either
		# source: the Heal Block move's counter or Psychic
		# Noise's own 2-turn counter (both keys checked inline
		# here, the same rule as the other heal gates).
		if int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0:
			logs.append("%s is prevented from healing by Heal Block!" % mon.get("name", "Pokémon"))
		else:
			var healed := _heal(mon, maxi(1, int(floor(float(max_hp) / 16.0))))
			if healed > 0:
				logs.append("%s restored HP with its Leftovers (+%d HP)!" % [mon.get("name", "Pokémon"), healed])
	if held == "blacksludge":
		# Black Sludge: a Poison-type holder heals 1/16 max HP
		# (Heal Block gates it, like Leftovers); any other
		# holder loses 1/8 max HP (Magic Guard blocks the
		# damage, as for every other indirect source).
		if _has_type(mon, "poison"):
			if int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0:
				logs.append("%s is prevented from healing by Heal Block!" % mon.get("name", "Pokémon"))
			else:
				var sludge_healed: int = _heal(mon, maxi(1, int(floor(float(max_hp) / 16.0))))
				if sludge_healed > 0:
					logs.append("%s restored HP with its Black Sludge (+%d HP)!" % [mon.get("name", "Pokémon"), sludge_healed])
		elif not AbilityEngine.blocks_indirect_damage(mon):
			var sludge_loss: int = maxi(1, int(floor(float(max_hp) / 8.0)))
			mon["hp"] = maxi(0, int(mon.get("hp", 0)) - sludge_loss)
			logs.append("%s was hurt by its Black Sludge (-%d HP)!" % [mon.get("name", "Pokémon"), sludge_loss])
	held = _held(mon)
	var hp := int(mon.get("hp", 0))
	# Unnerve (and As One, which carries Unnerve): while a holder
	# is active on the other side, a foe cannot eat a Berry at all.
	# The Berry is not eaten: no heal, and it stays held.
	var would_eat: bool = (held == "sitrusberry" and hp <= max_hp / 2) or (held in _PINCH_BERRIES and hp <= max_hp / 4) or (held == "lumberry" and str(mon.get("status", "")) != "")
	if foe_has_unnerve and would_eat:
		logs.append("%s can't eat its %s because of Unnerve!" % [mon.get("name", "Pokémon"), mon.get("item", "berry")])
		return
	if held == "sitrusberry" and hp <= max_hp / 2:
		_consume(mon, "Sitrus Berry", logs, field)
		var sitrus_heal: int = maxi(1, int(floor(float(max_hp) / 4.0)))
		if bool(mon.get("ripen_double", false)):
			sitrus_heal *= 2
		_heal(mon, sitrus_heal)
		_clear_ripen_flags(mon)
		return
	if held in _PINCH_BERRIES and hp <= max_hp / 4:
		_consume(mon, str(mon.get("item", "berry")), logs, field)
		var pinch_heal: int = maxi(1, int(floor(float(max_hp) / 2.0)))
		if bool(mon.get("ripen_double", false)):
			pinch_heal *= 2
		_heal(mon, pinch_heal)
		_clear_ripen_flags(mon)
		return
	if held == "oranberry" and hp <= max_hp / 2:
		_consume(mon, "Oran Berry", logs, field)
		var oran_heal: int = 10
		if bool(mon.get("ripen_double", false)):
			oran_heal *= 2
		_heal(mon, oran_heal)
		_clear_ripen_flags(mon)
		return
	if held == "berryjuice" and hp <= max_hp / 2:
		_consume(mon, "Berry Juice", logs, field)
		var juice_heal: int = 20
		if bool(mon.get("ripen_double", false)):
			juice_heal *= 2
		_heal(mon, juice_heal)
		_clear_ripen_flags(mon)
		return
	if _STAT_BERRIES.has(held) and hp <= max_hp / 4:
		var stat_key: String = str(_STAT_BERRIES.get(held, ""))
		_consume(mon, str(mon.get("item", "berry")), logs, field)
		var boost: int = 1
		if bool(mon.get("ripen_double", false)):
			boost = 2
		_raise_stage(mon, stat_key, boost, logs)
		_clear_ripen_flags(mon)
		return
	if held == "starfberry" and hp <= max_hp / 4:
		_consume(mon, "Starf Berry", logs, field)
		var starf_boost: int = 2
		if bool(mon.get("ripen_double", false)):
			starf_boost = 4
		_raise_random_stage(mon, starf_boost, logs)
		_clear_ripen_flags(mon)
		return
	if held == "leppaberry":
		var pp_map: Dictionary = mon.get("pp", {})
		var leppa_move: String = _first_empty_pp_move(mon, pp_map)
		if leppa_move != "":
			_consume(mon, "Leppa Berry", logs, field)
			var pp_gain: int = 10
			if bool(mon.get("ripen_double", false)):
				pp_gain = 20
			_restore_pp(mon, leppa_move, pp_gain, logs)
			_clear_ripen_flags(mon)
			return
	if held == "lumberry" and str(mon.get("status", "")) != "":
		mon["status"] = ""
		_consume(mon, "Lum Berry", logs, field)
	# Flame Orb burns the holder and Toxic Orb badly poisons
	# it at the end of the turn. The status goes through
	# try_set_status, the one choke point, so Leaf Guard, type
	# immunities and Safeguard answer exactly as they do for a
	# move's status. The orbs are not consumed. (The Guts /
	# Quick Feet / Flare Boost payoffs are ability-side and
	# already live in AbilityEngine.)
	held = _held(mon)
	if held == "flameorb" and str(mon.get("status", "")) == "":
		if AbilityEngine.try_set_status(mon, "BRN", mon, field, logs, true):
			logs.append("%s was burned by its Flame Orb!" % mon.get("name", "Pokémon"))
	elif held == "toxicorb" and str(mon.get("status", "")) == "":
		if AbilityEngine.try_set_status(mon, "TOX", mon, field, logs, true):
			logs.append("%s was badly poisoned by its Toxic Orb!" % mon.get("name", "Pokémon"))
	# The standing update checks (cure Berries that did not
	# fire at the choke point, Mental Herb, White Herb, Lansat
	# and Micle Berries) run last, on the final state of the
	# turn.
	update_item_checks(mon, field, logs, foe_has_unnerve)


## The held-item update check: the items whose trigger is "the
## moment their condition becomes true". The controller gets
## this at end of turn through on_end_of_turn, immediately for
## statuses through on_status_set (called from
## AbilityEngine.try_set_status), and after a move through
## on_after_move's caller. Berries respect Unnerve when the
## caller can attribute it (foe_has_unnerve), exactly as
## on_end_of_turn's own Berry arms do.
static func update_item_checks(mon: Dictionary, field: Dictionary, logs: Array, foe_has_unnerve: bool = false) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if int(field.get("magic_room", 0)) > 0:
		return
	_check_held_cure_berry(mon, field, logs, foe_has_unnerve)
	var held: String = _held(mon)
	if held == "mentalherb":
		# Mental Herb: cure infatuation, Taunt, Encore,
		# Torment, Disable and Heal Block volatiles, once.
		var vols: Dictionary = mon.get("volatiles", {})
		var cured: bool = false
		for vkey in ["attract", "taunt", "encore", "torment", "disable", "healblock"]:
			if vols.has(vkey):
				vols.erase(vkey)
				cured = true
		if not vols.is_empty() or mon.has("volatiles"):
			mon["volatiles"] = vols
		if bool(mon.get("infatuated", false)):
			mon["infatuated"] = false
			cured = true
		if str(mon.get("disabled_move", "")) != "":
			mon["disabled_move"] = ""
			cured = true
		if int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0:
			mon["heal_block_turns"] = 0
			mon["noise_heal_block_turns"] = 0
			cured = true
		if cured:
			_consume(mon, "Mental Herb", logs, field)
			logs.append("%s's Mental Herb cured its volatile conditions!" % mon.get("name", "Pokémon"))
		return
	held = _held(mon)
	if held == "whiteherb":
		# White Herb: restore every lowered stat stage to 0,
		# once. Raised stages are untouched.
		var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
		var restored: bool = false
		for key in ["atk", "def", "spa", "spd", "spe", "acc", "eva"]:
			if int(stages.get(key, 0)) < 0:
				stages[key] = 0
				restored = true
		if restored:
			mon["stages"] = stages
			_consume(mon, "White Herb", logs, field)
			logs.append("%s's White Herb restored its lowered stats!" % mon.get("name", "Pokémon"))
		return
	held = _held(mon)
	var max_hp: int = int(mon.get("max_hp", 100))
	var hp_now: int = int(mon.get("hp", 0))
	if foe_has_unnerve:
		return
	if held == "lansatberry" and hp_now <= max_hp / 4:
		# Lansat Berry: at 1/4 HP or less, the holder's
		# critical-hit ratio rises by 2 stages (the same
		# volatile key Dire Hit writes, read by crit_stage).
		mon["crit_stage_bonus"] = maxi(int(mon.get("crit_stage_bonus", 0)), 2)
		_consume(mon, "Lansat Berry", logs, field)
		logs.append("%s's Lansat Berry raised its critical-hit ratio!" % mon.get("name", "Pokémon"))
		return
	if held == "micleberry" and hp_now <= max_hp / 4:
		# Micle Berry: at 1/4 HP or less, the holder's next
		# move gains +20% accuracy (accuracy_multiplier reads
		# the flag; on_after_move clears it after the move).
		mon["micle_accuracy"] = true
		_consume(mon, "Micle Berry", logs, field)
		logs.append("%s's Micle Berry boosted its accuracy!" % mon.get("name", "Pokémon"))
		return


## The held cure Berries: Cheri (PAR), Pecha (PSN/TOX), Rawst
## (BRN), Aspear (FRZ), Chesto (SLP), Persim (confusion) and
## Miracle Berry (any status — the Gen 2 predecessor of Lum
## Berry, same hook). The Berry is eaten and the condition
## cured the moment it lands. Persim's confusion is a volatile
## set by direct writes in several places (there is no single
## confusion choke point), so Persim is checked here and from
## the post-move / end-of-turn update checks rather than from
## on_status_set.
static func _check_held_cure_berry(mon: Dictionary, field: Dictionary, logs: Array, foe_has_unnerve: bool = false) -> void:
	if foe_has_unnerve:
		return
	var held: String = _held(mon)
	var status: String = str(mon.get("status", ""))
	if _HELD_CURE_BERRIES.has(held):
		var want: String = str(_HELD_CURE_BERRIES[held])
		if status == want or (want == "PSN" and status == "TOX"):
			mon["status"] = ""
			if want == "PSN":
				mon.erase("toxic_counter")
			_consume(mon, str(mon.get("item", "berry")), logs, field)
		return
	if held == "persimberry" and bool(mon.get("confused", false)):
		mon["confused"] = false
		mon["confusion_turns"] = 0
		_consume(mon, "Persim Berry", logs, field)
		return
	if held == "miracleberry" and status != "":
		mon["status"] = ""
		mon.erase("toxic_counter")
		_consume(mon, "Miracle Berry", logs, field)
		return


## Called from AbilityEngine.try_set_status right after a
## status is set on this mon (the status-application choke
## point the triage names): a held cure Berry answers at once.
## Unnerve cannot be attributed at this choke point — the
## field flag cannot say whose Unnerve it is — so it is not
## checked here, the same documented limit as
## check_weaken_berry.
static func on_status_set(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if int(field.get("magic_room", 0)) > 0:
		return
	_check_held_cure_berry(mon, field, logs)



## Weakness Policy: when a super-effective move hits (the caller
## records the last effectiveness in mon["last_effectiveness"]),
## Attack and Special Attack rise by 2 stages and the item is used
## up. Enigma Berry: when a super-effective move hits, the holder
## eats it and heals 1/4 of its max HP (1/2 with Ripen). The
## Enigma heal reads the Ripen ability straight from the mon:
## this function has no field channel, so on_item_use does not run
## on this path and the ripen_double flag is never set here. The
## berry is still eaten through _consume with the field the
## controller stored on mon["field"], so Cheek Pouch and Cud Chew
## fire when that field is there. Fainted mons get nothing.
static func on_damage_taken(mon: Dictionary, move: Dictionary, logs: Array, attacker: Dictionary = {}, damage: int = 0, field: Dictionary = {}) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if _held(mon) == "weaknesspolicy":
		if float(mon.get("last_effectiveness", 0.0)) < 2.0:
			return
		var stages: Dictionary = mon.get("stages", {"atk": 0, "spa": 0})
		stages["atk"] = mini(6, int(stages.get("atk", 0)) + 2)
		stages["spa"] = mini(6, int(stages.get("spa", 0)) + 2)
		mon["stages"] = stages
		mon["item"] = ""
		mon["item_consumed"] = "Weakness Policy"
		logs.append("%s's Weakness Policy sharply raised its Attack and Special Attack!" % mon.get("name", "Pokémon"))
		return
	if _held(mon) == "enigmaberry" and float(mon.get("last_effectiveness", 0.0)) >= 2.0:
		var max_hp: int = int(mon.get("max_hp", 100))
		var enigma_heal: int = maxi(1, int(floor(float(max_hp) / 4.0)))
		if str(mon.get("ability", "")) == "Ripen":
			enigma_heal *= 2
		var eat_field: Dictionary = mon.get("field", {})
		_consume(mon, "Enigma Berry", logs, eat_field)
		_heal(mon, enigma_heal)
	# Held-item hooks that need the attacker and the damage
	# (code_prep_items_hooks). The old three-argument calls pass
	# damage 0 and no attacker, so every arm below stays silent
	# for them; the controller's damage sites pass all three.
	# Magic Room suppresses held items here too (the field is
	# only known on the new calls).
	if damage <= 0 or attacker.is_empty():
		return
	if int(field.get("magic_room", 0)) > 0:
		return
	if int(attacker.get("hp", 0)) <= 0:
		return
	var cat: String = str(move.get("cat", move.get("category", "")))
	var is_physical: bool = cat == "Physical"
	var is_special: bool = cat == "Special"
	# Protective Pads: an attacker wearing them is protected
	# from the effects of moves that make contact with its
	# target — no Rocky Helmet chip, no Jaboca / Rowap bite
	# back. Kee and Maranga Berries still fire: they are the
	# defender's own items, not contact effects on the attacker.
	var attacker_padded: bool = _held(attacker) == "protectivepads"
	var held_now: String = _held(mon)
	if held_now == "rockyhelmet" and _is_contact(move) and not attacker_padded:
		if not AbilityEngine.blocks_indirect_damage(attacker):
			var chip: int = maxi(1, int(floor(float(int(attacker.get("max_hp", 100))) / 6.0)))
			attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - chip)
			logs.append("%s was hurt by %s's Rocky Helmet (-%d HP)!" % [attacker.get("name", "Pokémon"), mon.get("name", "Pokémon"), chip])
		return
	if held_now == "jabocaberry" and is_physical:
		# Protective Pads stop the whole effect: no damage, and
		# the Berry is not eaten.
		if attacker_padded:
			return
		if not AbilityEngine.blocks_indirect_damage(attacker):
			var jab_chip: int = maxi(1, int(floor(float(int(attacker.get("max_hp", 100))) / 8.0)))
			attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - jab_chip)
			logs.append("%s was hurt by %s's Jaboca Berry (-%d HP)!" % [attacker.get("name", "Pokémon"), mon.get("name", "Pokémon"), jab_chip])
		_consume(mon, "Jaboca Berry", logs, field)
		return
	if held_now == "rowapberry" and is_special:
		if attacker_padded:
			return
		if not AbilityEngine.blocks_indirect_damage(attacker):
			var row_chip: int = maxi(1, int(floor(float(int(attacker.get("max_hp", 100))) / 8.0)))
			attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - row_chip)
			logs.append("%s was hurt by %s's Rowap Berry (-%d HP)!" % [attacker.get("name", "Pokémon"), mon.get("name", "Pokémon"), row_chip])
		_consume(mon, "Rowap Berry", logs, field)
		return
	if held_now == "keeberry" and is_physical:
		_consume(mon, "Kee Berry", logs, field)
		_raise_stage(mon, "def", 1, logs)
		return
	if held_now == "marangaberry" and is_special:
		_consume(mon, "Maranga Berry", logs, field)
		_raise_stage(mon, "spd", 1, logs)
		return



## Catch-rate multiplier for a ball. Master Ball returns 255.0,
## which means always catch. Unknown balls return 1.0 and never crash.
## Net Ball needs the target's types. Quick Ball needs the turn count
## (turn 1 is the first turn). Timer Ball scales with turns:
## 1 + turns * 122 / 4096, capped at 4.0. Repeat Ball needs
## already_caught to be true. Dive Ball needs terrain_water to be true
## (in or on water). Dusk Ball needs night_or_cave to be true
## (at night or in a cave): 3.0x then, 1.0x otherwise.
static func get_ball_bonus(ball_item: String, defender_types: PackedStringArray = [], turn: int = 0, terrain_water: bool = false, already_caught: bool = false, night_or_cave: bool = false) -> float:
	match _norm(ball_item):
		"pokeball":
			return 1.0
		"greatball":
			return 1.5
		"ultraball":
			return 2.0
		"masterball":
			return 255.0
		"safariball":
			return 1.5
		"netball":
			if "Bug" in defender_types or "Water" in defender_types:
				return 3.0
			return 1.0
		"diveball":
			if terrain_water:
				return 3.5
			return 1.0
		"duskball":
			if night_or_cave:
				return 3.0
			return 1.0
		"quickball":
			if turn <= 1:
				return 5.0
			return 1.0
		"timerball":
			return minf(4.0, 1.0 + float(maxi(0, turn)) * 122.0 / 4096.0)
		"repeatball":
			if already_caught:
				return 3.0
			return 1.0
		"luxuryball", "healball", "friendball", "premierball":
			return 1.0
	return 1.0


## A mon's friendship: the "friendship" key first, then
## "happiness" (the follower-care convention); 70 when neither
## is recorded (the standard base friendship in the games, the
## same default battle_controller documents).
static func _friendship_of(mon: Dictionary) -> int:
	if mon.has("friendship"):
		return int(mon.get("friendship", 0))
	if mon.has("happiness"):
		return int(mon.get("happiness", 0))
	return 70


## Write friendship back to the key it was read from (or to
## "friendship" when neither key exists), clamped 0..255.
static func _set_friendship(mon: Dictionary, value: int) -> void:
	var clamped: int = clampi(value, 0, 255)
	if mon.has("happiness") and not mon.has("friendship"):
		mon["happiness"] = clamped
	else:
		mon["friendship"] = clamped


static func _raise_friendship(mon: Dictionary, amount: int) -> void:
	_set_friendship(mon, _friendship_of(mon) + amount)


## Raise one EV by amount, never past the canon's ceilings
## (EV_STAT_CAP per stat, EV_TOTAL_CAP across all six). The
## games apply what fits and refuse only when nothing fits;
## the partial gain is applied here the same way. Returns true
## when at least 1 EV was gained. (code_prep_item_engine_gaps)
static func _raise_ev(mon: Dictionary, stat_key: String, amount: int) -> bool:
	var ev_map: Dictionary = mon.get("evs", {})
	var total: int = 0
	for k in ev_map.keys():
		total += int(ev_map[k])
	var cur: int = int(ev_map.get(stat_key, 0))
	var gain: int = mini(amount, mini(EV_STAT_CAP - cur, EV_TOTAL_CAP - total))
	if gain <= 0:
		return false
	ev_map[stat_key] = cur + gain
	mon["evs"] = ev_map
	return true


## Bitter medicine (Energy Root, Revival Herb): the games lower
## friendship. The amount here is 1, the flat Gen 7+ value.
static func _lower_friendship(mon: Dictionary, amount: int) -> void:
	_set_friendship(mon, _friendship_of(mon) - amount)


## The move a PP item works on: the context's "move" when it is
## one of the mon's PP-tracked moves; otherwise the first move
## (in mon["moves"] order) below its recorded max PP; otherwise
## the first PP-tracked move. "" when the mon tracks no PP.
static func _pick_pp_move(mon: Dictionary, context: Dictionary) -> String:
	var pp_map: Dictionary = mon.get("pp", {})
	if pp_map.is_empty():
		return ""
	var chosen: String = str(context.get("move", ""))
	if chosen != "" and pp_map.has(chosen):
		return chosen
	var pp_max_map: Dictionary = mon.get("pp_max", {})
	for m_v in mon.get("moves", []):
		var m_name: String = str(m_v)
		if pp_map.has(m_name) and int(pp_map.get(m_name, 0)) < int(pp_max_map.get(m_name, 0)):
			return m_name
	for m_v2 in mon.get("moves", []):
		if pp_map.has(str(m_v2)):
			return str(m_v2)
	var keys: Array = pp_map.keys()
	if not keys.is_empty():
		return str(keys[0])
	return ""


## Use a bag item on a mon. Returns true only when the item did
## something. Potion heals 20, Super Potion 50, Hyper Potion 200,
## Max Potion to full, Full Restore to full plus cures status.
## Antidote cures PSN and TOX, Paralyze Heal cures PAR, Awakening
## cures SLP, Burn Heal cures BRN, Ice Heal cures FRZ, Full Heal
## cures any status. Revive restores a fainted mon to 1/2 max HP,
## Max Revive to full HP. Never heals above max HP. Unknown items
## return false.
##
## Top-batch additions (item triage TOP_BATCH.md, staged by code
## prep code_prep_items): the healing drinks (Fresh Water 50,
## Soda Pop 60, Lemonade 80, Moomoo Milk 100, Energy Root 200
## and bitter), Lava Cookie (any status plus confusion), the six
## cure Berries used from the bag (Cheri, Pecha, Rawst, Aspear,
## Chesto, Persim — their held trigger is a separate battle
## hook), Revival Herb (revive at full HP, bitter), the X items
## (+2 stages, Gen 7+ per the triage version register), Dire Hit
## (+2 crit stages, read back through crit_stage_bonus), Ether /
## Max Ether / Elixir (PP restore through _restore_pp), PP Up
## (+20% of a move's base max PP, at most 3 per move), Ability
## Capsule and Ability Patch, Rare Candy (one level through the
## EXP path: EXP is set to the next level's total and the level
## is clamped by the badge hard caps), the six EV Berries (-10
## EV in one stat, friendship +1, refused when that EV is
## already 0) and Sacred Ash (revives every fainted party
## member at full HP).
##
## Gap-closure additions (code prep code_prep_item_engine_gaps):
## the six vitamins (+10 EV in one stat) and the six EV
## feathers (+1 EV), both capped at the difficulty canon's
## 252-per-stat / 510-total ceilings with partial gains
## applied, and the 21 nature mints (set the mon's nature to
## the mint's own nature; refused when it already matches).
## Sources are cited at the _VITAMINS / _FEATHERS /
## _MINT_NATURES tables.
##
## EXP Candy additions (code prep code_prep_exp_candy): the
## five EXP Candies (XS/S/M/L/XL) grant a fixed amount of EXP
## through the same total-EXP path as the Rare Candy arm —
## the amount is added to mon["exp"], the level is re-derived
## with EXPSystem.level_for_exp and clamped by the badge hard
## caps (the cap stops the LEVEL only; EXP keeps accruing
## past it, so a mon at the cap still gains the EXP). The
## amounts were refused by code_prep_item_engine_gaps for
## lack of a held source; the hunt desk has since sourced
## them, triple-checked (see the _EXP_CANDIES table). The
## Dynamax Candy and the Let's Go candies stay refused: the
## Dynamax Candy needs a Dynamax Level field no mon record
## carries (a Galar-turn build item), and the Let's Go
## candies feed the Awakening Value system PUW does not
## adopt (Bossy rulings, recorded in that prep's report).
##
## Move-picker addition (code prep code_prep_pp_max): PP Max
## (a selected move's max PP to its maximum — PokeAPI item
## prose id 53: "Raises a move's max PP by 60%."). Under this
## engine's own PP Up accounting (each PP Up adds one step of
## max(1, floor(base × 0.2)), at most 3 per move) +60% of base
## is exactly three PP Up steps, so the arm sets the move's
## max PP straight to base + 3 steps and records all 3 PP Up
## uses: a move already raised by PP Ups is topped up to the
## same ceiling, never overshot, and a maxed move refuses.
##
## Items that need a choice or data this engine does not own
## take it from the optional context Dictionary:
##   "move" (String): the chosen move (Ether, Max Ether,
##     PP Up, PP Max)
##   "species_abilities" (Array): the species' non-Hidden
##     abilities in order (Ability Capsule). The new ability is
##     written back in the list's own spelling.
##   "hidden_ability" (String): the species' Hidden ability
##     (Ability Patch)
##   "growth_rate" (String): the species' growth rate (Rare
##     Candy and the EXP Candies; falls back to
##     target["growth_rate"], then to the EXP system's own
##     medium-fast fallback)
##   "badges" (int): badge count for the level cap (Rare
##     Candy and the EXP Candies)
##   "party" (Array of mon Dictionaries): Sacred Ash
## An item whose context is missing returns false and does
## nothing, the same as an unknown item. The bag itself (counts,
## consumption of the used item) stays the caller's job, as it
## is for every item this function already handled — Tera
## Shards are the one exception, because they consume 50, and
## they have their own entry point (use_tera_shard) below.
static func use_battle_item(item: String, target: Dictionary, logs: Array, context: Dictionary = {}) -> bool:
	var max_hp := int(target.get("max_hp", 100))
	var hp := int(target.get("hp", 0))
	var status := str(target.get("status", ""))
	match _norm(item):
		"potion":
			if hp <= 0 or hp >= max_hp:
				return false
			_heal(target, 20)
		"superpotion":
			if hp <= 0 or hp >= max_hp:
				return false
			_heal(target, 50)
		"hyperpotion":
			if hp <= 0 or hp >= max_hp:
				return false
			_heal(target, 200)
		"maxpotion":
			if hp <= 0 or hp >= max_hp:
				return false
			_heal(target, max_hp)
		"fullrestore":
			if hp <= 0:
				return false
			if hp >= max_hp and status == "":
				return false
			_heal(target, max_hp)
			target["status"] = ""
		"antidote":
			if status != "PSN" and status != "TOX":
				return false
			target["status"] = ""
		"paralyzeheal":
			if status != "PAR":
				return false
			target["status"] = ""
		"awakening":
			if status != "SLP":
				return false
			target["status"] = ""
		"burnheal":
			if status != "BRN":
				return false
			target["status"] = ""
		"iceheal":
			if status != "FRZ":
				return false
			target["status"] = ""
		"fullheal":
			if status == "":
				return false
			target["status"] = ""
		"revive":
			if hp > 0:
				return false
			target["hp"] = maxi(1, int(floor(float(max_hp) / 2.0)))
		"maxrevive":
			if hp > 0:
				return false
			target["hp"] = max_hp
		"freshwater", "sodapop", "lemonade", "moomoomilk", "energyroot":
			if hp <= 0 or hp >= max_hp:
				return false
			_heal(target, int(_HEAL_DRINKS.get(_norm(item), 0)))
			if _norm(item) == "energyroot":
				_lower_friendship(target, 1)
		"lavacookie":
			if status == "" and not bool(target.get("confused", false)):
				return false
			target["status"] = ""
			target["confused"] = false
			target["confusion_turns"] = 0
		"cheriberry":
			if status != "PAR":
				return false
			target["status"] = ""
		"pechaberry":
			if status != "PSN" and status != "TOX":
				return false
			target["status"] = ""
		"rawstberry":
			if status != "BRN":
				return false
			target["status"] = ""
		"aspearberry":
			if status != "FRZ":
				return false
			target["status"] = ""
		"chestoberry":
			if status != "SLP":
				return false
			target["status"] = ""
		"persimberry":
			if not bool(target.get("confused", false)):
				return false
			target["confused"] = false
			target["confusion_turns"] = 0
		"revivalherb":
			if hp > 0:
				return false
			target["hp"] = max_hp
			_lower_friendship(target, 1)
		"xattack", "xdefense", "xspeed", "xspatk":
			if hp <= 0:
				return false
			var x_key: String = str(_X_STAGE_ITEMS.get(_norm(item), ""))
			var x_stages: Dictionary = target.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
			if int(x_stages.get(x_key, 0)) >= 6:
				return false
			_raise_stage(target, x_key, 2, logs)
		"direhit":
			if hp <= 0:
				return false
			if int(target.get("crit_stage_bonus", 0)) > 0:
				return false
			target["crit_stage_bonus"] = 2
			logs.append("%s's critical-hit ratio rose!" % target.get("name", "Pokémon"))
		"ether":
			var ether_move: String = _pick_pp_move(target, context)
			if ether_move == "":
				return false
			var ether_pp: Dictionary = target.get("pp", {})
			var ether_max: Dictionary = target.get("pp_max", {})
			var ether_cap: int = int(ether_max.get(ether_move, 0))
			if ether_cap > 0 and int(ether_pp.get(ether_move, 0)) >= ether_cap:
				return false
			_restore_pp(target, ether_move, 10, logs)
		"maxether":
			var maxether_move: String = _pick_pp_move(target, context)
			if maxether_move == "":
				return false
			var maxether_pp: Dictionary = target.get("pp", {})
			var maxether_max: Dictionary = target.get("pp_max", {})
			var maxether_cap: int = int(maxether_max.get(maxether_move, 0))
			if maxether_cap <= 0:
				return false
			var maxether_cur: int = int(maxether_pp.get(maxether_move, 0))
			if maxether_cur >= maxether_cap:
				return false
			_restore_pp(target, maxether_move, maxether_cap - maxether_cur, logs)
		"elixir":
			var elixir_pp: Dictionary = target.get("pp", {})
			var elixir_max: Dictionary = target.get("pp_max", {})
			var elixir_moves: Array = target.get("moves", [])
			if elixir_moves.is_empty():
				elixir_moves = elixir_pp.keys()
			var elixir_any: bool = false
			for elixir_v in elixir_moves:
				var elixir_move: String = str(elixir_v)
				var elixir_cap: int = int(elixir_max.get(elixir_move, 0))
				if elixir_cap > 0 and int(elixir_pp.get(elixir_move, 0)) >= elixir_cap:
					continue
				_restore_pp(target, elixir_move, 10, logs)
				elixir_any = true
			if not elixir_any:
				return false
		"ppup":
			var ppup_move: String = str(context.get("move", ""))
			if ppup_move == "":
				return false
			var ppup_max: Dictionary = target.get("pp_max", {})
			if not ppup_max.has(ppup_move):
				return false
			var ppup_base_map: Dictionary = target.get("pp_base", {})
			var ppup_base: int = int(ppup_base_map.get(ppup_move, int(ppup_max.get(ppup_move, 0))))
			if ppup_base <= 0:
				return false
			var ppup_uses: Dictionary = target.get("pp_ups", {})
			if int(ppup_uses.get(ppup_move, 0)) >= 3:
				return false
			if not ppup_base_map.has(ppup_move):
				ppup_base_map[ppup_move] = ppup_base
				target["pp_base"] = ppup_base_map
			ppup_max[ppup_move] = int(ppup_max.get(ppup_move, 0)) + maxi(1, int(floor(float(ppup_base) * 0.2)))
			target["pp_max"] = ppup_max
			ppup_uses[ppup_move] = int(ppup_uses.get(ppup_move, 0)) + 1
			target["pp_ups"] = ppup_uses
			logs.append("%s's %s max PP rose!" % [target.get("name", "Pokémon"), ppup_move])
		"ppmax":
			# PP Max (code prep code_prep_pp_max): the PP Up
			# arm's accounting taken to its ceiling in one
			# use — PokeAPI item prose id 53, +60% of the
			# move's base max PP, is exactly the 3 PP Up
			# steps the arm above allows. Same records, same
			# refusals: no chosen move, no PP record for the
			# move, no base to measure from, already at 3
			# PP Up uses, or the max already at the ceiling.
			var ppmax_move: String = str(context.get("move", ""))
			if ppmax_move == "":
				return false
			var ppmax_max: Dictionary = target.get("pp_max", {})
			if not ppmax_max.has(ppmax_move):
				return false
			var ppmax_base_map: Dictionary = target.get("pp_base", {})
			var ppmax_base: int = int(ppmax_base_map.get(ppmax_move, int(ppmax_max.get(ppmax_move, 0))))
			if ppmax_base <= 0:
				return false
			var ppmax_uses: Dictionary = target.get("pp_ups", {})
			if int(ppmax_uses.get(ppmax_move, 0)) >= 3:
				return false
			var ppmax_full: int = ppmax_base + 3 * maxi(1, int(floor(float(ppmax_base) * 0.2)))
			if int(ppmax_max.get(ppmax_move, 0)) >= ppmax_full:
				return false
			if not ppmax_base_map.has(ppmax_move):
				ppmax_base_map[ppmax_move] = ppmax_base
				target["pp_base"] = ppmax_base_map
			ppmax_max[ppmax_move] = ppmax_full
			target["pp_max"] = ppmax_max
			ppmax_uses[ppmax_move] = 3
			target["pp_ups"] = ppmax_uses
			logs.append("%s's %s max PP rose!" % [target.get("name", "Pokémon"), ppmax_move])
		"abilitycapsule":
			var capsule_v: Variant = context.get("species_abilities", [])
			if not (capsule_v is Array):
				return false
			var capsule_list: Array = capsule_v
			if capsule_list.size() < 2:
				return false
			var capsule_cur: String = _norm(str(target.get("ability", "")))
			var capsule_idx: int = -1
			for capsule_i in range(capsule_list.size()):
				if _norm(str(capsule_list[capsule_i])) == capsule_cur:
					capsule_idx = capsule_i
					break
			if capsule_idx < 0:
				return false
			var capsule_next: String = str(capsule_list[(capsule_idx + 1) % capsule_list.size()])
			target["ability"] = capsule_next
			logs.append("%s's Ability changed to %s!" % [target.get("name", "Pokémon"), capsule_next])
		"abilitypatch":
			var patch_hidden: String = str(context.get("hidden_ability", ""))
			if patch_hidden == "":
				return false
			if _norm(str(target.get("ability", ""))) == _norm(patch_hidden):
				return false
			target["ability"] = patch_hidden
			logs.append("%s's Ability changed to %s!" % [target.get("name", "Pokémon"), patch_hidden])
		"rarecandy":
			var candy_level: int = int(target.get("level", 0))
			if candy_level <= 0 or candy_level >= EXPSystem.MAX_LEVEL:
				return false
			var candy_badges: int = int(context.get("badges", 0))
			var candy_cap: int = EXPSystem.level_cap_for_badges(candy_badges)
			if candy_level >= candy_cap:
				return false
			var candy_growth: String = str(context.get("growth_rate", target.get("growth_rate", "")))
			var candy_exp: int = EXPSystem.exp_for_level(candy_growth, candy_level + 1)
			target["exp"] = maxi(int(target.get("exp", 0)), candy_exp)
			target["level"] = mini(candy_level + 1, candy_cap)
			logs.append("%s grew to Lv. %d!" % [target.get("name", "Pokémon"), int(target.get("level", 0))])
		"expcandyxs", "expcandys", "expcandym", "expcandyl", "expcandyxl", "exp.candyxs", "exp.candys", "exp.candym", "exp.candyl", "exp.candyxl":
			# EXP Candies (code prep code_prep_exp_candy).
			# Both key spellings are matched: _norm strips
			# spaces, dashes, underscores and apostrophes but
			# NOT periods, so the display name "Exp. Candy XL"
			# normalises to "exp.candyxl" while the registry
			# slug "exp-candy-xl" normalises to "expcandyxl".
			# This family is the only one whose display name
			# carries a period; the amount lookup below strips
			# the dot so both spellings read the one table.
			# a fixed amount of EXP to the chosen mon, through
			# the same total-EXP path as the Rare Candy arm
			# above — the amount is added to mon["exp"], the
			# level is re-derived with EXPSystem.level_for_exp
			# and clamped by the badge hard caps exactly as
			# EXPSystem documents them: the cap is a hard stop
			# on the LEVEL only, EXP keeps accruing past it,
			# so a mon at the cap still gains the full amount
			# and the candy is spent. The level is never
			# lowered (the battle EXP path's own rule). What a
			# level-up triggers beyond the level itself —
			# stat recomputation, move learning, evolution —
			# stays with the battle / campaign layer, exactly
			# as it does for Rare Candy: this arm writes "exp"
			# and "level" and nothing else. Refused on a
			# fainted mon (this engine's medicine-arm
			# precedent — the vitamins and EV Berries above;
			# the Rare Candy arm predates that check and is
			# unchanged) and at level 100, where no EXP can
			# be gained.
			if hp <= 0:
				return false
			var xpc_level: int = int(target.get("level", 0))
			if xpc_level <= 0 or xpc_level >= EXPSystem.MAX_LEVEL:
				return false
			var xpc_gain: int = int(_EXP_CANDIES.get(_norm(item).replace(".", ""), 0))
			if xpc_gain <= 0:
				return false
			var xpc_growth: String = str(context.get("growth_rate", target.get("growth_rate", "")))
			target["exp"] = int(target.get("exp", 0)) + xpc_gain
			var xpc_badges: int = int(context.get("badges", 0))
			var xpc_cap: int = EXPSystem.level_cap_for_badges(xpc_badges)
			var xpc_new_level: int = mini(EXPSystem.level_for_exp(xpc_growth, int(target.get("exp", 0))), xpc_cap)
			if xpc_new_level > xpc_level:
				target["level"] = xpc_new_level
				logs.append("%s grew to Lv. %d!" % [target.get("name", "Pokémon"), xpc_new_level])
		"pomegberry", "kelpsyberry", "qualotberry", "hondewberry", "grepaberry", "tamatoberry":
			if hp <= 0:
				return false
			var ev_key: String = str(_EV_BERRIES.get(_norm(item), ""))
			var ev_map: Dictionary = target.get("evs", {})
			if int(ev_map.get(ev_key, 0)) <= 0:
				return false
			ev_map[ev_key] = maxi(0, int(ev_map.get(ev_key, 0)) - 10)
			target["evs"] = ev_map
			_raise_friendship(target, 1)
		"hpup", "protein", "iron", "calcium", "zinc", "carbos":
			# Vitamins (code_prep_item_engine_gaps, gap G1):
			# +10 EV in the named stat, capped by the canon's
			# ceilings through _raise_ev. The fainted refusal
			# follows this engine's EV Berry arm above. The
			# prose's happiness rise rides the engine's flat
			# friendship convention (the EV Berry arm's +1; the
			# prose's tiered 5/3/2 breakpoints are defined in
			# no held source).
			if hp <= 0:
				return false
			if not _raise_ev(target, str(_VITAMINS.get(_norm(item), "")), VITAMIN_EV_GAIN):
				return false
			_raise_friendship(target, 1)
		"healthwing", "healthfeather", "musclewing", "musclefeather", "resistwing", "resistfeather", "geniuswing", "geniusfeather", "cleverwing", "cleverfeather", "swiftwing", "swiftfeather":
			# Feathers / Wings (gap G1): +1 EV in the named
			# stat, same ceilings, same conventions as the
			# vitamins above.
			if hp <= 0:
				return false
			if not _raise_ev(target, str(_FEATHERS.get(_norm(item), "")), FEATHER_EV_GAIN):
				return false
			_raise_friendship(target, 1)
		"lonelymint", "adamantmint", "naughtymint", "bravemint", "boldmint", "impishmint", "laxmint", "relaxedmint", "modestmint", "mildmint", "rashmint", "quietmint", "calmmint", "gentlemint", "carefulmint", "sassymint", "timidmint", "hastymint", "jollymint", "naivemint", "seriousmint":
			# Nature mints (gap G1): set the mon's nature to
			# the mint's own nature. Refused when the nature
			# already matches (the games' no-effect case). No
			# HP check, following this engine's Ability
			# Capsule / Patch arms — a nature change is not
			# medicine.
			var mint_nature: String = str(_MINT_NATURES.get(_norm(item), ""))
			if mint_nature == "":
				return false
			if str(target.get("nature", "")) == mint_nature:
				return false
			target["nature"] = mint_nature
			logs.append("%s's nature changed to %s!" % [target.get("name", "Pokémon"), mint_nature])
		"sacredash":
			var ash_v: Variant = context.get("party", [])
			if not (ash_v is Array):
				return false
			var ash_party: Array = ash_v
			var ash_any: bool = false
			for ash_member_v in ash_party:
				if ash_member_v is Dictionary:
					var ash_member: Dictionary = ash_member_v
					if int(ash_member.get("hp", 0)) <= 0:
						ash_member["hp"] = int(ash_member.get("max_hp", 100))
						ash_any = true
			if not ash_any:
				return false
		_:
			return false
	logs.append("Used %s on %s." % [item, target.get("name", "Pokémon")])
	return true


## Extra critical-hit stages a mon carries from a Dire Hit used
## this battle (Gen 7+: +2 stages). The damage path adds this to
## the crit stage it computes (the same total AbilityEngine's
## crit_stage feeds); ItemEngine only records the volatile, in
## use_battle_item's "direhit" arm. 0 when no Dire Hit was used.
static func crit_stage_bonus(mon: Dictionary) -> int:
	return int(mon.get("crit_stage_bonus", 0))


## Held-item critical-hit stages, summed by the damage
## calculator beside AbilityEngine.crit_stage (and beside the
## Dire Hit volatile, which rides in through crit_stage_bonus —
## Lansat Berry writes the same key in update_item_checks).
## Scope Lens: +1 stage for any holder. Lucky Punch: +2 for
## Chansey. Stick (canonical id "stick"; the registry merged
## "leek" into it): +2 for Farfetch'd and Sirfetch'd.
static func crit_stage(mon: Dictionary) -> int:
	var total: int = crit_stage_bonus(mon)
	match _held(mon):
		"scopelens":
			total += 1
		"luckypunch":
			if _species_of(mon) == "chansey":
				total += 2
		"stick":
			var sp: String = _species_of(mon)
			if sp == "farfetch'd" or sp == "farfetchd" or sp == "sirfetch'd" or sp == "sirfetchd":
				total += 2
	return total


## Species stat multiplier from a held item, read by the damage
## calculator where it reads the raw stats (the Deep Sea Tooth
## precedent's family). Light Ball: Pikachu's Attack and
## Special Attack x2. Thick Club: Cubone / Marowak's Attack x2.
## Metal Powder: Ditto's Defense and Special Defense x1.5,
## lost once it has Transformed (mon["transformed"]).
## stat_key is "atk" / "def" / "spa" / "spd" / "spe".
static func stat_multiplier(mon: Dictionary, stat_key: String) -> float:
	match _held(mon):
		"lightball":
			if _species_of(mon) == "pikachu" and (stat_key == "atk" or stat_key == "spa"):
				return 2.0
		"thickclub":
			var sp: String = _species_of(mon)
			if (sp == "cubone" or sp == "marowak" or sp == "marowak-alola") and stat_key == "atk":
				return 2.0
		"metalpowder":
			if _species_of(mon) == "ditto" and not bool(mon.get("transformed", false)):
				if stat_key == "def" or stat_key == "spd":
					return 1.5
	return 1.0


## Accuracy multiplier for the holder's own moves, multiplied
## into the controller's accuracy roll beside
## AbilityEngine.accuracy_mult. Wide Lens: x1.1. Micle Berry's
## one-move +20% rides in as the micle_accuracy flag (set by
## update_item_checks at 1/4 HP or less, cleared by
## on_after_move once the move has been used).
static func accuracy_multiplier(mon: Dictionary) -> float:
	var mult: float = 1.0
	if _held(mon) == "widelens":
		mult *= 1.1
	if bool(mon.get("micle_accuracy", false)):
		mult *= 1.2
	return mult


## Drain multiplier for the holder: Big Root makes HP restored
## by draining moves and Leech Seed x1.3. Read at the drain
## application sites (MoveEffects.apply_after_hit and the
## controller's Leech Seed tick).
static func drain_multiplier(mon: Dictionary) -> float:
	if _held(mon) == "bigroot":
		return 1.3
	return 1.0


## The Tera type a Tera Shard writes, or "" when the item is
## not a Tera Shard.
static func tera_type_for_shard(item: String) -> String:
	var row_v: Variant = _TERA_SHARDS.get(_norm(item), [])
	if row_v is Array:
		var row: Array = row_v
		if not row.is_empty():
			return str(row[0])
	return ""


## Use Tera Shards from the bag: the missing half of the Tera
## contract. battle_controller already passes a mon's
## "tera_type" to PUWGimmicks.terastallize; nothing wrote a
## persistent one. This writes it, at the games' cost of 50
## shards of the matching type, taken from the real bag
## (PUWInventoryManager, so the registry's canonical ids and
## counts are the ones that move). Returns false and changes
## nothing when the item is not a shard, the mon already has
## that Tera type, or the bag holds fewer than 50. Whether
## Terastallization is unlocked yet is progression's call
## (PUWGimmickUnlocks), not this function's.
static func use_tera_shard(item: String, target: Dictionary, inventory: PUWInventoryManager, logs: Array) -> bool:
	var type_name: String = tera_type_for_shard(item)
	if type_name == "":
		return false
	if inventory == null:
		return false
	if str(target.get("tera_type", "")) == type_name:
		return false
	var row: Array = _TERA_SHARDS.get(_norm(item), [])
	var shard_id: String = str(row[1])
	if inventory.count_item(shard_id) < TERA_SHARD_COST:
		return false
	if not inventory.consume_item(shard_id, TERA_SHARD_COST):
		return false
	target["tera_type"] = type_name
	logs.append("%s's Tera Type is now %s!" % [target.get("name", "Pokémon"), type_name])
	return true


## Poké Doll and Fluffy Tail: using one in a wild battle ends
## the battle (guaranteed escape); the bag consumes it after.
## The battle controller's flee resolution reads this — Smoke
## Ball is the held-item pattern that path already follows.
static func guarantees_escape(item: String) -> bool:
	return _norm(item) in ["pokedoll", "fluffytail"]


## Trainer prize-money multiplier: Amulet Coin / Luck Incense
## double the award when the holder participated. Wiring: the
## (not yet built) trainer prize-money award path multiplies
## by this — the path itself is the named program in the
## report; the check is complete here.
## (Bound in build 4.1 from code_prep_items_batch5, verbatim:
## the batch-5 dependency PUWRematchSystem's prize path and
## the rematch suites were built against.)
static func prize_money_multiplier(party: Array) -> float:
	for mon in party:
		if bool(mon.get("participated", false)):
			var held: String = _held(mon)
			if held == "amuletcoin" or held == "luckincense":
				return 2.0
	return 1.0


## Steps a Repel-family item lasts (its effect text): Repel
## 100, Super Repel 200, Max Repel 250. 0 for anything else.
## The overworld use path feeds this into
## PUWHabitatEncounters.apply_repel.
static func repel_steps_for(item: String) -> int:
	match _norm(item):
		"repel":
			return 100
		"superrepel":
			return 200
		"maxrepel":
			return 250
	return 0


## True for the Escape Rope. Its use path lives in the map
## loader (PUWMapLoader.escape_rope_target); this is the bag
## side's recognition check.
static func is_escape_rope(item: String) -> bool:
	return _norm(item) == "escaperope"


## Heavy-Duty Boots means entry hazards do not hurt the holder.
static func ignores_hazards(mon: Dictionary) -> bool:
	return _held(mon) == "heavydutyboots"


## Assault Vest blocks status moves. Everything else can use them.
static func can_use_status_move(mon: Dictionary) -> bool:
	return _held(mon) != "assaultvest"


## Effect text for an item, copied from items_full_compact.json.
## "" for unknown items and for items with no effect text in that
## file (Heavy-Duty Boots is one of those).
static func get_item_effect_text(item: String) -> String:
	var key: String = _norm(item)
	var text: String = str(ITEM_EFFECT_TEXT.get(key, ""))
	if text != "":
		return text
	return str(ITEM_EFFECT_TEXT_TOP_BATCH.get(key, ""))


## ------------------------------------------------------------------
## Switch-in, field and stat-change hooks (code_prep_items_hooks).
## ------------------------------------------------------------------

## Run when a mon enters battle (the controller calls this
## beside AbilityEngine.on_switch_in and
## _apply_terrain_on_switch_in, at battle start and on every
## switch): the terrain seeds fire on the terrain already up,
## and Room Service fires when Trick Room is already up.
## Booster Energy is NOT here: it already lives in
## AbilityBatch3's Protosynthesis / Quark Drive switch-in arm,
## which spends the item when the field condition is absent
## (verified by this prep's tests — see PREP_REPORT.md).
static func on_switch_in_items(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if int(field.get("magic_room", 0)) > 0:
		return
	check_terrain_seed(mon, field, logs)
	if _held(mon) == "roomservice" and int(field.get("trick_room", 0)) > 0:
		_consume(mon, "Room Service", logs, field)
		_raise_stage(mon, "spe", -1, logs)


## A terrain seed fires when its terrain is up under the
## holder: on switch-in (above) and when a Surge ability sets
## the terrain with the holder already out (the controller
## calls this from _apply_terrain_on_switch_in's callers via
## on_switch_in_items; mid-battle terrain moves do not exist
## in this engine yet, so there is no other terrain-change
## site). Raises Defense (Electric / Grassy) or Special
## Defense (Misty / Psychic) by 1 stage, then consumed.
static func check_terrain_seed(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var terrain: String = str(field.get("terrain", "none")).to_lower()
	if not _TERRAIN_SEEDS.has(terrain):
		return
	var row: Array = _TERRAIN_SEEDS[terrain]
	if _held(mon) != str(row[0]):
		return
	_consume(mon, str(mon.get("item", "seed")), logs, field)
	_raise_stage(mon, str(row[1]), 1, logs)


## Room Service when Trick Room is set while the holder is
## already out: Speed -1, consumed. The controller calls this
## for every active mon from the Trick Room arm of
## _apply_field_move.
static func on_trick_room_set(mon: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if _held(mon) != "roomservice":
		return
	_consume(mon, "Room Service", logs)
	_raise_stage(mon, "spe", -1, logs)


## Adrenaline Orb: when Intimidate lowers the holder's Attack,
## its Speed rises 1 stage and the orb is consumed (Gen 9
## trigger). Called from the Intimidate arm of
## AbilityEngine._v2_on_switch_in, only on the branch where
## the drop really applied.
static func on_intimidate_drop(mon: Dictionary, logs: Array) -> void:
	if _held(mon) != "adrenalineorb":
		return
	_consume(mon, "Adrenaline Orb", logs)
	_raise_stage(mon, "spe", 1, logs)


## Clear Amulet: the holder's stats cannot be lowered by an
## opposing Pokemon (moves or abilities). Read at the
## stat-drop choke points (MoveEffects._apply_boosts, the
## controller's _apply_stages, the Intimidate arm) beside
## AbilityEngine.blocks_stat_change. Self-inflicted drops are
## not blocked: those call sites only consult this on their
## foe-caused path.
static func blocks_foe_stat_drop(mon: Dictionary) -> bool:
	return _held(mon) == "clearamulet"


## Eject Pack: when a foe-caused stat drop really lands on
## the holder, the pack is consumed and the holder must switch
## out. The switch itself is the controller's machinery, so
## this only raises the eject_pack_pending flag; the
## controller consumes it after the move (through
## _handle_forced_switch, so Suction Cups and friends can
## still refuse). Called from the same choke points as
## blocks_foe_stat_drop, after a stage actually changed.
static func on_stat_dropped(mon: Dictionary, logs: Array) -> void:
	if _held(mon) != "ejectpack":
		return
	mon["item"] = ""
	mon["item_consumed"] = "Eject Pack"
	mon["eject_pack_pending"] = true
	logs.append("%s's Eject Pack activated!" % mon.get("name", "Pokémon"))


## Mirror Herb: when an opposing Pokemon's stat stages rise,
## the holder copies the same rises, once, and the herb is
## consumed. Called from the stat-change choke points with
## the deltas that really applied to the foe (positive
## entries only are copied). Returns true when it fired.
static func try_mirror_herb(holder: Dictionary, foe_deltas: Dictionary, logs: Array) -> bool:
	if _held(holder) != "mirrorherb":
		return false
	if int(holder.get("hp", 0)) <= 0:
		return false
	var any: bool = false
	for key in foe_deltas.keys():
		if int(foe_deltas[key]) > 0:
			any = true
	if not any:
		return false
	_consume(holder, "Mirror Herb", logs)
	for key in foe_deltas.keys():
		var amount: int = int(foe_deltas[key])
		if amount > 0:
			_raise_stage(holder, str(key), amount, logs)
	return true


## Fractional priority from held items, rolled by the
## controller in _roll_frac_priority beside
## AbilityEngine.frac_priority (the resolver never rolls; the
## controller sets frac_priority on the move dict). Quick
## Claw: 20% chance of +0.1 — first within the priority
## bracket, the Quick Draw precedent. Custap Berry: at 1/4 HP
## or less the holder's move gains the same +0.1, once; the
## Berry is eaten here, at roll time (Showdown eats it in
## onFractionalPriority), and item_consumed is stamped for
## the caller's log pattern.
static func frac_priority(mon: Dictionary, move: Dictionary, rng: RandomNumberGenerator) -> float:
	if int(mon.get("hp", 0)) <= 0:
		return 0.0
	var held: String = _held(mon)
	if held == "quickclaw":
		if rng.randf() < 0.20:
			return 0.1
		return 0.0
	if held == "custapberry":
		var max_hp: int = int(mon.get("max_hp", 100))
		if int(mon.get("hp", 0)) <= max_hp / 4:
			mon["item"] = ""
			mon["item_consumed"] = "Custap Berry"
			return 0.1
		return 0.0
	return 0.0


## Blunder Policy: when the holder's own move misses because
## of accuracy, its Speed rises 2 stages and the policy is
## consumed. Called from the controller's two accuracy-miss
## branches (singles and doubles).
static func on_move_missed(mon: Dictionary, logs: Array) -> void:
	if _held(mon) != "blunderpolicy":
		return
	if int(mon.get("hp", 0)) <= 0:
		return
	_consume(mon, "Blunder Policy", logs)
	_raise_stage(mon, "spe", 2, logs)


## After the holder's move has been used (the controller calls
## this once per move action, after execution): Throat Spray
## raises Special Attack 1 stage after a sound move and is
## consumed; the Metronome item's streak advances or resets;
## Micle Berry's one-move accuracy flag is spent.
static func on_after_move(mon: Dictionary, move: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	if _held(mon) == "throatspray" and _flag(move, "sound"):
		_consume(mon, "Throat Spray", logs)
		_raise_stage(mon, "spa", 1, logs)
	var move_key: String = _norm(str(move.get("name", move.get("id", ""))))
	if move_key != "":
		# metronome_streak counts consecutive completed uses of
		# the move, including this one; modify_attack_damage
		# reads it as the number of PREVIOUS consecutive uses
		# (first use x1.0, second x1.2, capped at x2.0).
		if move_key == str(mon.get("metronome_last_move", "")):
			mon["metronome_streak"] = int(mon.get("metronome_streak", 0)) + 1
		else:
			mon["metronome_last_move"] = move_key
			mon["metronome_streak"] = 1
	if bool(mon.get("micle_accuracy", false)):
		mon["micle_accuracy"] = false


## Weather duration when this mon sets the weather: 8 turns
## with the matching weather rock, the base duration without.
## Read at every weather-set site that writes a duration
## (the ability switch-in arms today; weather moves do not
## exist in this engine yet, and when they are built they
## must read this too).
static func weather_duration(mon: Dictionary, weather: String, base_turns: int) -> int:
	var rock: String = str(_WEATHER_ROCKS.get(weather.to_lower(), ""))
	if rock != "" and _held(mon) == rock:
		return 8
	return base_turns


## Terrain duration when this mon sets the terrain: 8 turns
## with a Terrain Extender, the base duration without.
static func terrain_duration(mon: Dictionary, base_turns: int) -> int:
	if _held(mon) == "terrainextender":
		return 8
	return base_turns


## Screen duration when this mon sets a screen (Reflect,
## Light Screen, Aurora Veil): 8 turns with Light Clay, the
## base duration without. NOTE: no move path in this engine
## sets a screen yet (the state, the damage read and the
## tick all exist; the set path does not), so this helper has
## no caller today — it is the hook the screen-set path must
## read when it is built (see PREP_REPORT.md).
static func screen_duration(mon: Dictionary, base_turns: int) -> int:
	if _held(mon) == "lightclay":
		return 8
	return base_turns


## Safety Goggles, weather half: the holder takes no weather
## damage. Read in StatusAndFieldEngine.apply_end_of_turn
## beside AbilityEngine.is_immune_to_weather_damage.
static func blocks_weather_damage(mon: Dictionary) -> bool:
	return _held(mon) == "safetygoggles"


## Safety Goggles, powder half: a powder move used against
## the holder does nothing. Read in the controller's
## _apply_status_move before the status is applied (the
## Overcoat before_move arm is the ability-side precedent).
static func blocks_powder_move(mon: Dictionary, move: Dictionary) -> bool:
	if _held(mon) != "safetygoggles":
		return false
	return _flag(move, "powder")


## Covert Cloak: the holder is immune to the additional
## (secondary) effects of opposing moves. Read in
## MoveEffects.apply_after_hit where the secondary roll is
## applied. The move's primary effects are untouched.
static func blocks_secondary_effects(mon: Dictionary) -> bool:
	return _held(mon) == "covertcloak"


## Ability Shield: the holder's ability cannot be changed or
## suppressed by an opposing effect. NOTE: this engine has no
## ability-assignment choke point — the ability batches write
## mon["ability"] directly at seven sites — so this predicate
## has no caller today. The minimal choke-point addition is
## staged with this prep (see PREP_REPORT.md); every future
## ability write must consult this first.
static func blocks_ability_change(mon: Dictionary) -> bool:
	return _held(mon) == "abilityshield"


## True when the move is a two-turn charge move (see
## _CHARGE_MOVE_IDS). Solar Beam in harsh sunlight does not
## charge in the games; that exemption belongs to the charge
## state machine, not to this recognition helper.
static func is_charge_move(move: Dictionary) -> bool:
	var move_id: String = _norm(str(move.get("id", move.get("name", ""))))
	return move_id in _CHARGE_MOVE_IDS


## Power Herb: when the holder uses a charge move, the herb
## is consumed and the charge turn is skipped. Returns true
## when it fired. There is no charge-turn state machine in
## the engine yet, so nothing calls this today; it is the
## hook the staged charge addition reads (see
## PREP_REPORT.md).
static func try_use_power_herb(mon: Dictionary, move: Dictionary, logs: Array) -> bool:
	if _held(mon) != "powerherb":
		return false
	if not is_charge_move(move):
		return false
	_consume(mon, "Power Herb", logs)
	logs.append("%s used its Power Herb to skip the charge turn!" % mon.get("name", "Pokémon"))
	return true
