class_name PUWItemTarget
extends RefCounted

## PUWItemTarget — field item-on-Pokémon resolution for the BW2 menu stack.
##
## Closes the gaps the live-bag prep named (code_prep_live_bag/PREP_REPORT.md):
## the bag's Give action and every targeted field item (healing, status
## cures, PP restore, evolution stones, rare candy, EV berries, Sacred Ash)
## resolve here, through the BOUND item engine — ItemEngine.use_battle_item
## (battle/item_engine.gd) for medicine, DynamicEvolutionEngine for stones.
## There is deliberately no parallel engine in this file: classification and
## validity mirror the engine's own refusal conditions, the engine performs
## every mutation, and the bag itself (counts, consumption) is handled
## through PUWLiveBag over the same state["bag"] dictionary.
##
## Contracts honoured:
## - Every refusal leaves the state byte-untouched (validity is read-only;
##   the resolver snapshots the target mon before the engine call and
##   restores it in place on any failure).
## - Every success consumes exactly one item via PUWLiveBag.
## - Held items live under BOTH mon["item"] and mon["held_item"] on write
##   (ItemEngine reads "item", Oak-dialect readers read "held_item", the
##   evolution manager reads both) and are read "item"-first, matching the
##   evolution manager's own precedent.
## - Result dictionaries carry a ready-to-show "message" built from the
##   engine's own log lines plus deltas measured from the mon's state —
##   never invented numbers.
##
## Engine gaps are refused honestly, never faked: species
## candies / Max Elixir / powders / regional snacks
## have NO handler with held effect data (reason "engine_gap");
## the NPC services (Bottle Cap, Heart Scale, TMs, Tera Shards)
## are bound to the save-state bag at the service layer by
## code_prep_item_engine_gaps but have no routing in this bag
## flow (reason "service_bound").
##
## Move-picker closure (code prep code_prep_pp_max): PP Up and
## PP Max need a move choice, which this flow now offers as a
## second step after the party picker (PUWMovePickerScreen).
## PP Max gained its ItemEngine arm in the same prep (PokeAPI
## item prose id 53: a selected move's max PP +60% of base —
## exactly the PP Up arm's three steps taken at once).
## target_validity answers at two levels for these two items:
## with no move in the context it judges the MON (can any move
## take the item — the party picker's question, result flagged
## "needs_move"); with context["move"] set it judges that MOVE
## (move_validity). Resolving without a chosen move still
## refuses "needs_move_choice", and a move already at its PP
## ceiling refuses "pp_maxed" — both before anything is spent.
##
## Gap closures (code prep code_prep_item_engine_gaps, on top of
## this prep): the vitamins, EV feathers and nature mints gained
## real ItemEngine arms (gap G1) and resolve through the picker
## below like every other targeted class; Ability Capsule /
## Patch resolve wherever PUWSpeciesAbilities carries the
## species' own ability row (gap G2) and keep refusing
## needs_species_data for species the held data does not cover;
## PUWItemServices and ItemEngine.use_tera_shard run against
## state["bag"] through PUWStateBagInventory (gap G3).
##
## EXP Candy closure (code prep code_prep_exp_candy, on top
## of the gaps prep): the five EXP Candies gained a real
## ItemEngine arm once the hunt desk sourced their EXP
## amounts (triple-sourced: Bulbapedia / PokémonDB / Serebii,
## in exact agreement), and resolve through the picker as
## class "exp_candy". The Dynamax Candy and the Let's Go
## candies keep refusing engine_gap by Bossy ruling: the
## Dynamax Candy needs a Dynamax Level field (a Galar-turn
## build item) and the Let's Go candies feed the Awakening
## Value system PUW does not adopt.

const POCKET_KEY_ITEMS := 5  # == PUWLiveBag pocket index for Key Items

# --- ItemEngine arm tables, keyed by the engine's normalized id ----------
# (ItemEngine._norm: lowercase, spaces/dashes/underscores/apostrophes gone.)

const HEAL_ITEMS := {
	"potion": true, "superpotion": true, "hyperpotion": true,
	"maxpotion": true, "freshwater": true, "sodapop": true,
	"lemonade": true, "moomoomilk": true, "energyroot": true,
}
const STATUS_CURES := {
	"antidote": ["PSN", "TOX"], "paralyzeheal": ["PAR"],
	"awakening": ["SLP"], "burnheal": ["BRN"], "iceheal": ["FRZ"],
	"cheriberry": ["PAR"], "pechaberry": ["PSN", "TOX"],
	"rawstberry": ["BRN"], "aspearberry": ["FRZ"],
	"chestoberry": ["SLP"],
}
const STATUS_CURE_ANY := {"fullheal": true, "lavacookie": true}
const CONFUSION_CURE := "persimberry"
const REVIVE_ITEMS := {"revive": true, "maxrevive": true, "revivalherb": true}
const PP_ONE_ITEMS := {"ether": true, "maxether": true}
const EV_BERRIES := {
	"pomegberry": "hp", "kelpsyberry": "atk", "qualotberry": "def",
	"hondewberry": "spa", "grepaberry": "spd", "tamatoberry": "spe",
}
const ABILITY_ITEMS := {"abilitycapsule": true, "abilitypatch": true}
# Gap G1 (code_prep_item_engine_gaps): the ItemEngine vitamin /
# feather tables, mirrored so validity can compute the gain the
# engine would apply. Values: ItemEngine._VITAMINS /
# _FEATHERS with VITAMIN_EV_GAIN / FEATHER_EV_GAIN.
const VITAMIN_STATS := {
	"hpup": "hp", "protein": "atk", "iron": "def",
	"calcium": "spa", "zinc": "spd", "carbos": "spe",
}
const FEATHER_STATS := {
	"healthwing": "hp", "musclewing": "atk", "resistwing": "def",
	"geniuswing": "spa", "cleverwing": "spd", "swiftwing": "spe",
}
const VITAMIN_GAIN := 10
const FEATHER_GAIN := 1
# The ItemEngine mint table, mirrored for validity.
const MINT_NATURES := {
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
# EXP Candy (code_prep_exp_candy): the ItemEngine
# _EXP_CANDIES table, mirrored so validity and the engine
# read the same amounts. Values triple-sourced by the hunt
# desk (Bulbapedia Exp. yield table / PokémonDB / Serebii
# ItemDex, exact agreement).
const EXP_CANDY_EXP := {
	"expcandyxs": 100, "expcandys": 800, "expcandym": 3000,
	"expcandyl": 10000, "expcandyxl": 30000,
}
# NPC-service items: the service layer is bound to the real
# bag (gap G3), but using one takes the service's own screen,
# which this bag flow does not host.
const SERVICE_ITEMS := {
	"bottlecap": true, "goldbottlecap": true, "heartscale": true,
}
const BATTLE_ONLY := {
	"xattack": true, "xdefense": true, "xspeed": true, "xspatk": true,
	"direhit": true, "pokedoll": true, "fluffytail": true,
}
const FIELD_SLUGS := {
	"repel": true, "super-repel": true, "max-repel": true,
	"escape-rope": true,
}
const PARTY_WIDE_SLUG := "sacred-ash"
# Compact-data categories whose members are medicine-shaped but (when they
# reach not_usable_result) have no engine arm: an engine gap, by rule.
const GAP_CATEGORIES := {
	"healing": true, "status-cures": true, "vitamins": true,
	"pp-recovery": true, "medicine": true, "picky-healing": true,
}

const REASON_TEXT := {
	"no_mon": "There is no Pokémon there.",
	"egg": "It's an Egg. Items can't be used on it.",
	"fainted": "The Pokémon has fainted.",
	"full_hp": "Its HP is already full.",
	"no_effect": "It would have no effect.",
	"no_status": "It isn't affected by a status problem.",
	"wrong_status": "It doesn't cure that status problem.",
	"not_fainted": "It hasn't fainted.",
	"permadeath": "It is gone. Nothing can bring it back.",
	"no_pp_data": "Its PP hasn't been recorded yet. It needs to battle first.",
	"pp_full": "Its PP is already full.",
	"pp_maxed": "Its max PP can't go any higher.",
	"no_ev": "That effort value can't go any lower.",
	"max_level": "It's already at the maximum level.",
	"level_cap": "It can't grow past the current badge cap yet.",
	"needs_move_choice": "It needs a move to be chosen first.",
	"needs_species_data": "Species ability data isn't available for it yet.",
	"engine_missing": "The evolution data couldn't be loaded.",
	"key_item": "That's too important to give away.",
	"holds_nothing": "It isn't holding anything.",
	"unknown_item": "Its held item isn't in the item registry.",
	"not_held": "There are none left in the Bag.",
	"battle_only": "That item can only be used in battle.",
	"engine_gap": "That item isn't wired into the field item engine yet.",
	"service_bound": "That service isn't wired into the Bag screen yet.",
	"ev_full": "Its effort values can't go any higher.",
	"not_field_usable": "It can't be used here.",
	"no_fainted": "No Pokémon in the party has fainted.",
}
const REASON_SHORT := {
	"no_mon": "—", "egg": "Egg", "fainted": "Fainted",
	"full_hp": "Full HP", "no_effect": "No effect",
	"no_status": "No status", "wrong_status": "Wrong status",
	"not_fainted": "Not fainted", "permadeath": "Gone",
	"no_pp_data": "No PP record", "pp_full": "PP full",
	"pp_maxed": "Max PP",
	"no_ev": "No EVs", "max_level": "Lv. 100",
	"level_cap": "Level cap", "needs_move_choice": "Needs a move",
	"needs_species_data": "No data", "engine_missing": "No data",
	"key_item": "Key item", "holds_nothing": "No item",
	"unknown_item": "Unknown item", "not_held": "None left",
	"battle_only": "Battle only", "engine_gap": "Not wired",
	"service_bound": "Not bound", "not_field_usable": "Can't use",
	"ev_full": "EVs full",
	"no_fainted": "None fainted", "no_evolution": "No evolution",
}

static var _evo_engine: DynamicEvolutionEngine = null
static var _evo_engine_tried: bool = false
static var _compact_rows: Dictionary = {}
static var _compact_loaded: bool = false


# ------------------------------------------------------------------ helpers

static func _norm(s: String) -> String:
	# ItemEngine._norm, mirrored exactly.
	return s.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")


static func _canon(item_id: String) -> String:
	var c: String = PUWItemRegistry.canonical_id_for(item_id)
	return c if c != "" else item_id


static func _party(state: Dictionary) -> Array:
	var p = state.get("party", [])
	return p if p is Array else []


static func _badge_count(state: Dictionary) -> int:
	var b = state.get("badges", [])
	if b is Array:
		return (b as Array).size()
	return int(b)


static func _mon_name(mon: Dictionary) -> String:
	var n: String = str(mon.get("name", ""))
	if n == "":
		n = str(mon.get("species", "Pokémon"))
	return n


static func _hp(mon: Dictionary) -> int:
	return int(mon.get("hp", 0))


static func _max_hp(mon: Dictionary) -> int:
	return int(mon.get("max_hp", 0))


static func _status_code(mon: Dictionary) -> String:
	return str(mon.get("status", "")).to_upper()


static func _is_permadead(mon: Dictionary) -> bool:
	return _status_code(mon) == "PERMADEATH"


static func held_of(mon: Dictionary) -> String:
	# "item" preferred, "held_item" fallback (evolution manager precedent).
	var a: String = str(mon.get("item", ""))
	if a != "":
		return a
	return str(mon.get("held_item", ""))


static func _set_held(mon: Dictionary, slug: String) -> void:
	mon["item"] = slug
	mon["held_item"] = slug


static func _compact_row(slug: String) -> Dictionary:
	if not _compact_loaded:
		_compact_loaded = true
		var path := "res://data/items_full_compact.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			var rows: Array = []
			if parsed is Array:
				rows = parsed
			elif parsed is Dictionary:
				var d: Dictionary = parsed
				if d.get("items") is Array:
					rows = d["items"]
				elif d.get("data") is Array:
					rows = d["data"]
			for r in rows:
				if r is Dictionary and str((r as Dictionary).get("slug", "")) != "":
					_compact_rows[str((r as Dictionary)["slug"])] = r
	var row = _compact_rows.get(slug, {})
	return row if row is Dictionary else {}


static func _evo() -> DynamicEvolutionEngine:
	if not _evo_engine_tried:
		_evo_engine_tried = true
		_evo_engine = DynamicEvolutionEngine.new()
	return _evo_engine


# ------------------------------------------------------------ classification

static func class_of(item_id: String) -> String:
	var n: String = _norm(_canon(item_id))
	if HEAL_ITEMS.has(n):
		return "heal"
	if n == "fullrestore":
		return "heal_status"
	if STATUS_CURES.has(n) or STATUS_CURE_ANY.has(n) or n == CONFUSION_CURE:
		return "status"
	if REVIVE_ITEMS.has(n):
		return "revive"
	if PP_ONE_ITEMS.has(n):
		return "pp_one"
	if n == "elixir":
		return "pp_all"
	if EV_BERRIES.has(n):
		return "ev_berry"
	if n == "rarecandy":
		return "candy"
	if EXP_CANDY_EXP.has(n):
		return "exp_candy"
	if n == "ppup":
		return "ppup"
	if n == "ppmax":
		return "ppmax"
	if ABILITY_ITEMS.has(n):
		return "ability"
	if VITAMIN_STATS.has(n) or FEATHER_STATS.has(n):
		return "vitamin"
	if MINT_NATURES.has(n):
		return "mint"
	return ""


## The EV gain one use of a vitamin/feather would apply to a
## mon: [stat key, gain] with the canon's ceilings applied
## (ItemEngine._raise_ev's rule: 252 per stat, 510 total,
## partial gains count). Gain 0 means the engine would refuse.
static func _ev_gain_for(mon: Dictionary, n: String) -> Array:
	var stat: String = ""
	var amount: int = 0
	if VITAMIN_STATS.has(n):
		stat = str(VITAMIN_STATS[n])
		amount = VITAMIN_GAIN
	elif FEATHER_STATS.has(n):
		stat = str(FEATHER_STATS[n])
		amount = FEATHER_GAIN
	else:
		return ["", 0]
	var evs_value: Variant = mon.get("evs", {})
	var evs: Dictionary = evs_value if evs_value is Dictionary else {}
	var total: int = 0
	for k in evs.keys():
		total += int(evs[k])
	var cur: int = int(evs.get(stat, 0))
	var gain: int = mini(amount, mini(ItemEngine.EV_STAT_CAP - cur, ItemEngine.EV_TOTAL_CAP - total))
	return [stat, maxi(0, gain)]


## A mon's species string: the species key first, the display
## name as fallback (ItemEngine._species_of's precedent).
static func _species_of(mon: Dictionary) -> String:
	var sp: String = str(mon.get("species", ""))
	if sp == "":
		sp = str(mon.get("name", ""))
	return sp


static func is_stone_candidate(item_id: String) -> bool:
	var slug: String = _canon(item_id)
	if _norm(slug) == "linkingcord":
		return true
	return str(_compact_row(slug).get("category", "")) == "evolution"


## "field" (PUWLiveBag resolves it), "target" (needs the party picker),
## "party" (party-wide, no single target), "none" (not field-usable here).
static func use_mode(state: Dictionary, item_id: String) -> String:
	var slug: String = _canon(item_id)
	if slug == PARTY_WIDE_SLUG:
		return "party"
	if FIELD_SLUGS.has(slug):
		return "field"
	if class_of(slug) != "":
		return "target"
	if is_stone_candidate(slug):
		return "target"
	return "none"


# ---------------------------------------------------------------- validity

static func _invalid(reason: String, text: String = "") -> Dictionary:
	return {
		"valid": false, "reason": reason,
		"reason_text": text if text != "" else str(REASON_TEXT.get(reason, "It can't be used.")),
		"short": str(REASON_SHORT.get(reason, "Can't use")),
	}


static func _valid() -> Dictionary:
	return {"valid": true, "reason": "", "reason_text": "", "short": ""}


static func _pp_state(mon: Dictionary) -> Dictionary:
	# PP is recorded two ways in the bound state dialects: per-move dicts
	# (Oak grants: moves = [{"name", "pp", "max_pp"}]) and the battle
	# controller's mon["pp"] / mon["pp_max"] dictionaries keyed by move name.
	var known := false
	var any_below := false
	var moves = mon.get("moves", [])
	var dict_moves := false
	if moves is Array:
		for mv in moves:
			if mv is Dictionary:
				dict_moves = true
				var md: Dictionary = mv
				if md.has("pp"):
					known = true
					var pp: int = int(md.get("pp", 0))
					var mx: int = int(md.get("max_pp", pp))
					if pp < mx:
						any_below = true
	if not dict_moves:
		var ppd = mon.get("pp", {})
		if ppd is Dictionary and not (ppd as Dictionary).is_empty():
			known = true
			var ppmax = mon.get("pp_max", {})
			for k in (ppd as Dictionary).keys():
				var cur: int = int((ppd as Dictionary)[k])
				var mx: int = cur
				if ppmax is Dictionary and (ppmax as Dictionary).has(k):
					mx = int((ppmax as Dictionary)[k])
				if cur < mx:
					any_below = true
	return {"known": known, "any_below": any_below}


## True for the two items whose use is a two-step pick: party
## first, then one of the chosen mon's moves (PP Up, PP Max).
static func requires_move_choice(item_id: String) -> bool:
	var cls: String = class_of(item_id)
	return cls == "ppup" or cls == "ppmax"


## A mon's move names in its own order, across both state
## dialects (per-move dicts, or name strings). Battle-dialect
## mons whose moves list is empty fall back to the recorded
## PP keys, the engine's own fallback order of last resort.
static func _move_names(mon: Dictionary) -> Array:
	var names: Array = []
	var moves = mon.get("moves", [])
	if moves is Array:
		for mv in moves:
			if mv is Dictionary:
				var nm: String = str((mv as Dictionary).get("name", ""))
				if nm != "" and not names.has(nm):
					names.append(nm)
			elif mv is String and str(mv) != "" and not names.has(str(mv)):
				names.append(str(mv))
	if names.is_empty():
		var ppmax = mon.get("pp_max", {})
		if ppmax is Dictionary:
			for k in (ppmax as Dictionary).keys():
				names.append(str(k))
	return names


## One move's PP record, normalized across both dialects and
## measured the way the ItemEngine PP Up / PP Max arms measure
## it: "known" mirrors the arms' pp_max record requirement;
## "pp_base" falls back to the current max PP when no base was
## recorded (the arms' own fallback); "step" is one PP Up step
## (max(1, floor(base × 0.2))); "full" is the ceiling the arms
## stop at (base + 3 steps); "pp_ups" is the recorded use count.
static func _move_pp_info(mon: Dictionary, move_name: String) -> Dictionary:
	var info: Dictionary = {
		"known": false, "pp": 0, "pp_max": 0,
		"pp_base": 0, "pp_ups": 0, "step": 0, "full": 0,
	}
	var moves = mon.get("moves", [])
	if moves is Array:
		for mv in moves:
			if mv is Dictionary:
				var md: Dictionary = mv
				if str(md.get("name", "")) == move_name:
					# The Oak dialect records every move's
					# PP in its dict; the resolver's adapter
					# turns exactly this into the engine's
					# pp / pp_max shape.
					info["known"] = true
					info["pp"] = int(md.get("pp", 0))
					info["pp_max"] = int(md.get("max_pp", int(md.get("pp", 0))))
					break
			elif mv is String and str(mv) == move_name:
				var ppmax = mon.get("pp_max", {})
				if ppmax is Dictionary and (ppmax as Dictionary).has(move_name):
					info["known"] = true
					info["pp_max"] = int((ppmax as Dictionary)[move_name])
					var ppd = mon.get("pp", {})
					if ppd is Dictionary:
						info["pp"] = int((ppd as Dictionary).get(move_name, 0))
				break
	if not bool(info["known"]):
		# A move named only in the PP records (the engine arms
		# key off mon["pp_max"], not the moves list).
		var ppmax2 = mon.get("pp_max", {})
		if ppmax2 is Dictionary and (ppmax2 as Dictionary).has(move_name):
			info["known"] = true
			info["pp_max"] = int((ppmax2 as Dictionary)[move_name])
			var ppd2 = mon.get("pp", {})
			if ppd2 is Dictionary:
				info["pp"] = int((ppd2 as Dictionary).get(move_name, 0))
	if bool(info["known"]):
		var base_map = mon.get("pp_base", {})
		if base_map is Dictionary and (base_map as Dictionary).has(move_name):
			info["pp_base"] = int((base_map as Dictionary)[move_name])
		else:
			info["pp_base"] = int(info["pp_max"])
		var uses_map = mon.get("pp_ups", {})
		if uses_map is Dictionary:
			info["pp_ups"] = int((uses_map as Dictionary).get(move_name, 0))
		if int(info["pp_base"]) > 0:
			info["step"] = maxi(1, int(floor(float(info["pp_base"]) * 0.2)))
			info["full"] = int(info["pp_base"]) + 3 * int(info["step"])
	return info


## Would one move's PP ceiling refuse this item? Mirrors the
## ItemEngine arms exactly: PP Up refuses at 3 recorded uses;
## PP Max refuses at 3 uses or when the max already stands at
## the ceiling the arm would set.
static func _move_at_ceiling(cls: String, info: Dictionary) -> bool:
	if int(info.get("pp_ups", 0)) >= 3:
		return true
	if cls == "ppmax" and int(info.get("full", 0)) > 0 \
			and int(info.get("pp_max", 0)) >= int(info.get("full", 0)):
		return true
	return false


## Move-level validity for the move picker step: mirrors the
## ItemEngine PP Up / PP Max arms' refusal conditions for one
## named move. Read-only, same result shape as target_validity,
## plus the move's PP figures for the picker's labels.
static func move_validity(state: Dictionary, item_id: String, slot: int, move_name: String) -> Dictionary:
	var party: Array = _party(state)
	if slot < 0 or slot >= party.size() or not (party[slot] is Dictionary):
		return _invalid("no_mon")
	var mon: Dictionary = party[slot]
	if bool(mon.get("is_egg", false)):
		return _invalid("egg")
	var cls: String = class_of(item_id)
	if cls != "ppup" and cls != "ppmax":
		return _invalid("not_field_usable")
	var info: Dictionary = _move_pp_info(mon, move_name)
	if not bool(info.get("known", false)) or int(info.get("pp_base", 0)) <= 0:
		var v0: Dictionary = _invalid("no_pp_data")
		v0["move"] = move_name
		return v0
	if _move_at_ceiling(cls, info):
		var v1: Dictionary = _invalid("pp_maxed")
		v1["move"] = move_name
		v1["pp"] = int(info["pp"])
		v1["pp_max"] = int(info["pp_max"])
		return v1
	var v: Dictionary = _valid()
	v["move"] = move_name
	v["pp"] = int(info["pp"])
	v["pp_max"] = int(info["pp_max"])
	# The max PP one use would leave: one more step for PP Up,
	# the ceiling itself for PP Max.
	v["new_pp_max"] = int(info["full"]) if cls == "ppmax" \
		else int(info["pp_max"]) + int(info["step"])
	return v


## The move picker's rows for one mon: every move in the mon's
## own order with its current / max PP and its move_validity
## verdict, so the screen can show PP and grey the maxed moves
## before anything is spent.
static func move_options(state: Dictionary, item_id: String, slot: int) -> Array:
	var rows: Array = []
	var party: Array = _party(state)
	if slot < 0 or slot >= party.size() or not (party[slot] is Dictionary):
		return rows
	var mon: Dictionary = party[slot]
	var names: Array = _move_names(mon)
	for i in names.size():
		var nm: String = str(names[i])
		var v: Dictionary = move_validity(state, item_id, slot, nm)
		var info: Dictionary = _move_pp_info(mon, nm)
		rows.append({
			"index": i, "move": nm,
			"pp": int(info.get("pp", 0)), "pp_max": int(info.get("pp_max", 0)),
			"valid": bool(v.get("valid", false)),
			"reason": str(v.get("reason", "")),
			"reason_text": str(v.get("reason_text", "")),
			"short": str(v.get("short", "")),
			"new_pp_max": int(v.get("new_pp_max", int(info.get("pp_max", 0)))),
			"label": "%s — PP %d/%d" % [nm, int(info.get("pp", 0)), int(info.get("pp_max", 0))],
		})
	return rows


static func _stone_check(mon: Dictionary, slug: String) -> Dictionary:
	var eng: DynamicEvolutionEngine = _evo()
	if eng == null:
		return {"can_evolve": false, "reason": "__engine_missing__"}
	var last: Dictionary = {}
	var candidates: Array = [PUWLiveBag.display_name_for(slug), slug]
	for cand in candidates:
		var res: Dictionary = eng.check_use_item(mon, str(cand), {})
		if bool(res.get("can_evolve", false)):
			return res
		last = res
	return last


## Mirrors the bound engine's refusal conditions per item class, so the
## picker can grey targets out BEFORE anything is consumed. Read-only.
static func target_validity(state: Dictionary, action: String, item_id: String, slot: int, context: Dictionary = {}) -> Dictionary:
	var party: Array = _party(state)
	if slot < 0 or slot >= party.size() or not (party[slot] is Dictionary):
		return _invalid("no_mon")
	var mon: Dictionary = party[slot]
	if bool(mon.get("is_egg", false)):
		return _invalid("egg")
	var slug: String = _canon(item_id)
	if action == "give":
		if PUWLiveBag.pocket_for_slug(slug) == POCKET_KEY_ITEMS:
			return _invalid("key_item")
		var held_raw: String = held_of(mon)
		if held_raw != "" and PUWItemRegistry.canonical_id_for(held_raw) == "":
			return _invalid("unknown_item")
		return _valid()
	if action == "take":
		var held: String = held_of(mon)
		if held == "":
			return _invalid("holds_nothing")
		if PUWItemRegistry.canonical_id_for(held) == "":
			return _invalid("unknown_item")
		return _valid()
	# action == "use"
	var cls: String = class_of(slug)
	if cls == "" and is_stone_candidate(slug):
		cls = "stone"
	match cls:
		"heal":
			if _hp(mon) <= 0:
				return _invalid("fainted")
			if _hp(mon) >= _max_hp(mon):
				return _invalid("full_hp")
		"heal_status":
			if _hp(mon) <= 0:
				return _invalid("fainted")
			if _hp(mon) >= _max_hp(mon) and _status_code(mon) == "":
				return _invalid("no_effect")
		"status":
			var code: String = _status_code(mon)
			var confused: bool = bool(mon.get("confused", false))
			var n: String = _norm(slug)
			if n == "lavacookie":
				# The one cure whose engine arm counts confusion.
				if code == "" and not confused:
					return _invalid("no_status")
			elif STATUS_CURE_ANY.has(n):
				# Full Heal: any status, but its arm ignores confusion.
				if code == "":
					return _invalid("no_status")
			elif n == CONFUSION_CURE:
				if not confused:
					return _invalid("no_status")
			else:
				var cures: Array = STATUS_CURES.get(n, [])
				if code == "":
					return _invalid("no_status")
				if not cures.has(code):
					return _invalid("wrong_status")
		"revive":
			if _is_permadead(mon):
				return _invalid("permadeath")
			if _hp(mon) > 0:
				return _invalid("not_fainted")
		"pp_one", "pp_all":
			var pps: Dictionary = _pp_state(mon)
			if not bool(pps.get("known", false)):
				return _invalid("no_pp_data")
			if not bool(pps.get("any_below", false)):
				return _invalid("pp_full")
		"ev_berry":
			if _hp(mon) <= 0:
				return _invalid("fainted")
			var evs = mon.get("evs", {})
			var stat: String = str(EV_BERRIES.get(_norm(slug), ""))
			if not (evs is Dictionary) or int((evs as Dictionary).get(stat, 0)) <= 0:
				return _invalid("no_ev")
		"candy":
			var level: int = int(mon.get("level", 1))
			if level >= 100:
				return _invalid("max_level")
			if level >= EXPSystem.level_cap_for_badges(_badge_count(state)):
				return _invalid("level_cap")
		"exp_candy":
			# Mirrors the engine's EXP Candy arm: fainted
			# refuses (the medicine-arm precedent), level
			# 100 refuses (no EXP can be gained). There is
			# deliberately NO level_cap refusal here, unlike
			# Rare Candy: the hard caps stop the level only
			# and EXP keeps accruing past them (EXPSystem's
			# own documented rule), so a mon at the badge
			# cap still gains the candy's EXP and the use
			# succeeds.
			if _hp(mon) <= 0:
				return _invalid("fainted")
			if int(mon.get("level", 1)) >= 100:
				return _invalid("max_level")
		"ppup", "ppmax":
			# Move-picker closure (code_prep_pp_max): with a
			# move chosen (context["move"]) the verdict is
			# the move's own; without one it is the mon-level
			# question the party picker asks — can any of its
			# moves take the item? A mon that can proceeds to
			# the move step (flagged "needs_move"); resolving
			# without a move still refuses needs_move_choice
			# in use_on_mon.
			var chosen_move: String = str(context.get("move", ""))
			if chosen_move != "":
				return move_validity(state, slug, slot, chosen_move)
			var saw_known := false
			var saw_ceiling := false
			for nm_v in _move_names(mon):
				var info: Dictionary = _move_pp_info(mon, str(nm_v))
				if not bool(info.get("known", false)) or int(info.get("pp_base", 0)) <= 0:
					continue
				saw_known = true
				if _move_at_ceiling(cls, info):
					saw_ceiling = true
				else:
					var v_ok: Dictionary = _valid()
					v_ok["needs_move"] = true
					return v_ok
			if not saw_known:
				return _invalid("no_pp_data")
			if saw_ceiling:
				return _invalid("pp_maxed")
			return _invalid("no_effect")
		"vitamin":
			# Mirrors the engine's vitamin/feather arms:
			# fainted refuses (the EV Berry precedent), and a
			# gain of 0 under the canon's ceilings refuses.
			if _hp(mon) <= 0:
				return _invalid("fainted")
			var gain_row: Array = _ev_gain_for(mon, _norm(slug))
			if int(gain_row[1]) <= 0:
				return _invalid("ev_full")
		"mint":
			# Mirrors the engine's mint arm: refused only
			# when the nature already matches.
			if str(mon.get("nature", "")) == str(MINT_NATURES.get(_norm(slug), "")):
				return _invalid("no_effect")
		"ability":
			# Gap G2: wherever PUWSpeciesAbilities carries
			# the species' own row, validity mirrors the
			# engine arms against it; species without a row
			# keep the honest needs_species_data refusal.
			var sp_row: Dictionary = PUWSpeciesAbilities.for_species(_species_of(mon))
			if sp_row.is_empty():
				return _invalid("needs_species_data")
			var cur_ability: String = _norm(str(mon.get("ability", "")))
			if _norm(slug) == "abilitycapsule":
				var regular_value: Variant = sp_row.get("abilities", [])
				var regular: Array = regular_value if regular_value is Array else []
				if regular.size() < 2:
					return _invalid("no_effect")
				var listed: bool = false
				for a in regular:
					if _norm(str(a)) == cur_ability:
						listed = true
				if not listed:
					return _invalid("no_effect")
			else:
				var hidden: String = str(sp_row.get("hidden", ""))
				if hidden == "":
					return _invalid("no_effect")
				if cur_ability == _norm(hidden):
					return _invalid("no_effect")
		"stone":
			var chk: Dictionary = _stone_check(mon, slug)
			if str(chk.get("reason", "")) == "__engine_missing__":
				return _invalid("engine_missing")
			if not bool(chk.get("can_evolve", false)):
				var why: String = str(chk.get("reason", ""))
				var v: Dictionary = _invalid("no_evolution", why if why != "" else str(REASON_TEXT["no_effect"]))
				return v
		_:
			return _invalid("not_field_usable")
	return _valid()


# --------------------------------------------------------------- resolvers

static func _refusal(action: String, slug: String, slot: int, validity: Dictionary) -> Dictionary:
	return {
		"ok": false, "action": action, "item": slug, "slot": slot,
		"reason": str(validity.get("reason", "not_field_usable")),
		"message": str(validity.get("reason_text", "")),
	}


static func _restore_mon(mon: Dictionary, snapshot: Dictionary) -> void:
	mon.clear()
	for k in snapshot.keys():
		mon[k] = snapshot[k]


static func _pp_adapter_apply(mon: Dictionary) -> bool:
	# Oak-dialect mons carry moves as dicts; ItemEngine reads mon["pp"] /
	# mon["pp_max"] keyed by move name with moves as name strings (the battle
	# controller's own shaping). Returns true when the mon was adapted.
	var moves = mon.get("moves", [])
	if not (moves is Array) or (moves as Array).is_empty():
		return false
	if not ((moves as Array)[0] is Dictionary):
		return false
	var names: Array = []
	var pp: Dictionary = {}
	var pp_max: Dictionary = {}
	for mv in moves:
		if not (mv is Dictionary):
			continue
		var md: Dictionary = mv
		var nm: String = str(md.get("name", ""))
		names.append(nm)
		pp[nm] = int(md.get("pp", 0))
		pp_max[nm] = int(md.get("max_pp", int(md.get("pp", 0))))
	mon["moves"] = names
	mon["pp"] = pp
	mon["pp_max"] = pp_max
	return true


static func _pp_adapter_writeback(mon: Dictionary, snapshot: Dictionary) -> void:
	var snap_moves = snapshot.get("moves", [])
	var ppd = mon.get("pp", {})
	var ppmaxd = mon.get("pp_max", {})
	var restored: Array = []
	if snap_moves is Array:
		for mv in snap_moves:
			if mv is Dictionary:
				var d: Dictionary = (mv as Dictionary).duplicate(true)
				var nm: String = str(d.get("name", ""))
				if ppd is Dictionary and (ppd as Dictionary).has(nm):
					d["pp"] = int((ppd as Dictionary)[nm])
				# PP Up / PP Max raise the max, not the
				# current PP: the raised max goes back into
				# the move dict that recorded one, so the
				# Oak dialect's own record keeps it (the
				# PP-restore arms never change pp_max, so
				# their writeback stays value-identical).
				if d.has("max_pp") and ppmaxd is Dictionary and (ppmaxd as Dictionary).has(nm):
					d["max_pp"] = int((ppmaxd as Dictionary)[nm])
				restored.append(d)
			else:
				restored.append(mv)
	mon["moves"] = restored


## Use a targeted item on party[slot] through the bound engine.
static func use_on_mon(state: Dictionary, item_id: String, slot: int, context: Dictionary = {}) -> Dictionary:
	var slug: String = _canon(item_id)
	var base: Dictionary = {"ok": false, "action": "use", "item": slug, "slot": slot, "reason": "", "message": ""}
	if PUWLiveBag.count_in_state(state, slug) <= 0:
		var v: Dictionary = _invalid("not_held")
		base["reason"] = "not_held"
		base["message"] = str(v["reason_text"])
		return base
	var validity: Dictionary = target_validity(state, "use", slug, slot, context)
	if not bool(validity.get("valid", false)):
		return _refusal("use", slug, slot, validity)
	var party: Array = _party(state)
	var mon: Dictionary = party[slot]
	var mon_name: String = _mon_name(mon)
	var before_hp: int = _hp(mon)
	var snapshot: Dictionary = mon.duplicate(true)
	var cls: String = class_of(slug)
	if cls == "" and is_stone_candidate(slug):
		cls = "stone"
	if (cls == "ppup" or cls == "ppmax") and str(context.get("move", "")) == "":
		# Mon-level validity passed (a move CAN take the
		# item), but the engine arms work on one chosen move:
		# without the picker's choice there is nothing to
		# resolve. Refuses before the snapshot is spent and
		# before anything is consumed.
		return _refusal("use", slug, slot, _invalid("needs_move_choice"))
	var logs: Array = []
	var ok := false
	if cls == "stone":
		var chk: Dictionary = _stone_check(mon, slug)
		var row = chk.get("row", {})
		if bool(chk.get("can_evolve", false)) and row is Dictionary:
			var evolved: Dictionary = _evo().apply_evolution(mon, row)
			_restore_mon(mon, evolved)
			ok = true
			base["evolved_to"] = str(mon.get("species", mon.get("name", "")))
			base["message"] = "%s evolved into %s!" % [mon_name, str(base["evolved_to"])]
	else:
		var adapted: bool = _pp_adapter_apply(mon)
		var ctx: Dictionary = {
			"badges": _badge_count(state),
			"party": party,
		}
		if mon.has("growth_rate"):
			ctx["growth_rate"] = mon["growth_rate"]
		for k in context.keys():
			ctx[k] = context[k]
		if cls == "ability":
			# Gap G2: the species' own ability row feeds the
			# engine arms, unless the caller supplied the
			# context itself.
			var sp_ctx: Dictionary = PUWSpeciesAbilities.context_for(_species_of(mon))
			for k in sp_ctx.keys():
				if not ctx.has(k):
					ctx[k] = sp_ctx[k]
		# The display name is passed so the engine's own log line reads
		# "Used Super Potion on Pikachu." (its _norm makes it match).
		ok = ItemEngine.use_battle_item(PUWLiveBag.display_name_for(slug), mon, logs, ctx)
		if ok and adapted:
			_pp_adapter_writeback(mon, snapshot)
	if not ok:
		_restore_mon(mon, snapshot)
		base["reason"] = "no_effect"
		base["message"] = str(REASON_TEXT["no_effect"])
		return base
	PUWLiveBag.consume_from_state(state, slug, 1)
	base["ok"] = true
	base["logs"] = logs
	if cls == "ppup" or cls == "ppmax":
		base["move"] = str(context.get("move", ""))
	if cls != "stone":
		var parts: Array = []
		for line in logs:
			parts.append(str(line))
		var healed: int = _hp(mon) - before_hp
		if healed > 0:
			parts.append("%s's HP was restored by %d." % [_mon_name(mon), healed])
		base["healed"] = healed
		base["message"] = " ".join(PackedStringArray(parts)) if parts.size() > 0 else "Used the %s on %s." % [PUWLiveBag.display_name_for(slug), mon_name]
	return base


## Party-wide use (Sacred Ash): the engine revives through context["party"].
static func use_party_wide(state: Dictionary, item_id: String) -> Dictionary:
	var slug: String = _canon(item_id)
	var base: Dictionary = {"ok": false, "action": "use", "item": slug, "slot": -1, "reason": "", "message": ""}
	if slug != PARTY_WIDE_SLUG:
		var nu: Dictionary = not_usable_result(state, slug)
		nu["action"] = "use"
		return nu
	if PUWLiveBag.count_in_state(state, slug) <= 0:
		base["reason"] = "not_held"
		base["message"] = str(REASON_TEXT["not_held"])
		return base
	var party: Array = _party(state)
	var fainted: Array = []
	var revivable: Array = []
	var any_permadead := false
	for i in party.size():
		if party[i] is Dictionary and _hp(party[i]) <= 0:
			fainted.append(i)
			if _is_permadead(party[i]):
				any_permadead = true
			else:
				revivable.append(i)
	if fainted.is_empty():
		base["reason"] = "no_fainted"
		base["message"] = str(REASON_TEXT["no_fainted"])
		return base
	if any_permadead or revivable.is_empty():
		# The engine's Sacred Ash arm revives EVERY hp<=0 member and
		# knows nothing of permadeath; canon forbids reviving the
		# permadead, so the whole use refuses while one is down.
		base["reason"] = "permadeath"
		base["message"] = str(REASON_TEXT["permadeath"])
		return base
	var snapshot: Array = party.duplicate(true)
	var target: Dictionary = party[int(revivable[0])]
	var logs: Array = []
	var ctx: Dictionary = {"badges": _badge_count(state), "party": party}
	var ok: bool = ItemEngine.use_battle_item(PUWLiveBag.display_name_for(slug), target, logs, ctx)
	if not ok:
		party.clear()
		party.append_array(snapshot)
		base["reason"] = "no_effect"
		base["message"] = str(REASON_TEXT["no_effect"])
		return base
	var revived := 0
	for i in fainted:
		if _hp(party[i]) > 0:
			revived += 1
	PUWLiveBag.consume_from_state(state, slug, 1)
	var parts: Array = []
	for line in logs:
		parts.append(str(line))
	parts.append("%d Pokémon were revived." % revived)
	base["ok"] = true
	base["logs"] = logs
	base["revived"] = revived
	base["message"] = " ".join(PackedStringArray(parts))
	return base


## Give: bag -> mon. Swap when the mon already holds something returnable.
static func give_to_mon(state: Dictionary, item_id: String, slot: int) -> Dictionary:
	var slug: String = _canon(item_id)
	var base: Dictionary = {"ok": false, "action": "give", "item": slug, "slot": slot, "reason": "", "message": ""}
	if PUWLiveBag.count_in_state(state, slug) <= 0:
		base["reason"] = "not_held"
		base["message"] = str(REASON_TEXT["not_held"])
		return base
	var validity: Dictionary = target_validity(state, "give", slug, slot)
	if not bool(validity.get("valid", false)):
		return _refusal("give", slug, slot, validity)
	var mon: Dictionary = _party(state)[slot]
	var held_raw: String = held_of(mon)
	var held_slug: String = PUWItemRegistry.canonical_id_for(held_raw) if held_raw != "" else ""
	PUWLiveBag.consume_from_state(state, slug, 1)
	if held_slug != "":
		PUWLiveBag.grant_to_state(state, held_slug, 1)
	_set_held(mon, slug)
	base["ok"] = true
	base["swapped"] = held_slug
	var item_name: String = PUWLiveBag.display_name_for(slug)
	if held_slug != "":
		base["message"] = "%s already held a %s. Swapped it for the %s." % [_mon_name(mon), PUWLiveBag.display_name_for(held_slug), item_name]
	else:
		base["message"] = "Gave the %s to %s." % [item_name, _mon_name(mon)]
	return base


## Take: mon -> bag.
static func take_from_mon(state: Dictionary, slot: int) -> Dictionary:
	var base: Dictionary = {"ok": false, "action": "take", "item": "", "slot": slot, "reason": "", "message": ""}
	var validity: Dictionary = target_validity(state, "take", "", slot)
	if not bool(validity.get("valid", false)):
		return _refusal("take", "", slot, validity)
	var mon: Dictionary = _party(state)[slot]
	var held_slug: String = PUWItemRegistry.canonical_id_for(held_of(mon))
	PUWLiveBag.grant_to_state(state, held_slug, 1)
	_set_held(mon, "")
	base["ok"] = true
	base["item"] = held_slug
	base["message"] = "Took the %s from %s." % [PUWLiveBag.display_name_for(held_slug), _mon_name(mon)]
	return base


## The refusal for items the bag can show but this flow cannot resolve.
static func not_usable_result(state: Dictionary, item_id: String) -> Dictionary:
	var slug: String = _canon(item_id)
	var n: String = _norm(slug)
	var reason := "not_field_usable"
	if BATTLE_ONLY.has(n):
		reason = "battle_only"
	elif class_of(slug) == "ppup" or class_of(slug) == "ppmax":
		# Both have engine arms; what they cannot do is
		# resolve without the move picker's chosen move
		# (the reclassification the gaps prep assigned to
		# this move-picker work — PP Max previously fell
		# through to engine_gap by its pp-recovery category).
		reason = "needs_move_choice"
	elif SERVICE_ITEMS.has(n) or n.find("terashard") >= 0 \
			or str(_compact_row(slug).get("category", "")) in ["tera-shard", "all-machines"]:
		# Gap G3: the services run against the real bag at
		# the service layer; this bag flow hosts no service
		# screen, so the refusal is routing, not binding.
		reason = "service_bound"
	elif GAP_CATEGORIES.has(str(_compact_row(slug).get("category", ""))) \
			or slug.ends_with("-candy"):
		reason = "engine_gap"
	return {
		"ok": false, "action": "use", "item": slug, "slot": -1,
		"reason": reason, "message": str(REASON_TEXT[reason]),
	}


# --------------------------------------------------------------- messaging

## Builds display text for any bag resolution result (live-bag field uses,
## tosses, and this class's own results, which arrive with "message" set).
static func message_for_result(action: String, item_id: String, result: Dictionary, mon_name: String = "") -> String:
	if str(result.get("message", "")) != "":
		return str(result["message"])
	var slug: String = _canon(item_id)
	var item_name: String = PUWLiveBag.display_name_for(slug)
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "not_field_usable"))
		return str(REASON_TEXT.get(reason, "It can't be used."))
	match action:
		"use":
			if result.has("steps"):
				return "Used the %s. Wild Pokémon will stay away for %d steps." % [item_name, int(result["steps"])]
			if mon_name != "":
				return "Used the %s on %s." % [item_name, mon_name]
			return "%s was used." % item_name
		"give":
			return "Gave the %s to %s." % [item_name, mon_name]
		"take":
			return "Took the %s from %s." % [item_name, mon_name]
		"toss":
			return "Threw away one %s." % item_name
	return item_name


# ------------------------------------------------------------ screen rows

static func _chip_for(mon: Dictionary) -> String:
	if _hp(mon) <= 0:
		return "permadeath" if _is_permadead(mon) else "fainted"
	match _status_code(mon):
		"PSN", "TOX":
			return "psn"
		"BRN":
			return "brn"
		"PAR":
			return "par"
		"SLP":
			return "slp"
		"FRZ":
			return "frz"
	return ""


## Party rows in PUWPartyScreen's own shape, built from the real state.
static func rows_for_screen(state: Dictionary) -> Array:
	var rows: Array = []
	var party: Array = _party(state)
	for i in party.size():
		if not (party[i] is Dictionary):
			continue
		var mon: Dictionary = party[i]
		var name: String = _mon_name(mon)
		if name == str(mon.get("species_slug", "")):
			name = name.capitalize()
		var held_raw: String = held_of(mon)
		var held_slug: String = PUWItemRegistry.canonical_id_for(held_raw) if held_raw != "" else ""
		rows.append({
			"slot": i,
			"name": name,
			"level": int(mon.get("level", 1)),
			"hp": _hp(mon),
			"max_hp": _max_hp(mon),
			"exp_frac": float(mon.get("exp_frac", 0.0)),
			"status": _chip_for(mon),
			"held_item": PUWLiveBag.display_name_for(held_slug) if held_slug != "" else "",
			"icon": "",
			"sprite": "",
		})
	return rows
