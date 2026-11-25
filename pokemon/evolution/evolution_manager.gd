class_name DynamicEvolutionEngine
extends Node
## Full evolution manager for Pokemon Ultimate World.
##
## This file replaces the old 9-line stub at
## res://pokemon/evolution/evolution_manager.gd. The class name and
## the get_status() shape stay the same, so old code keeps working.
##
## What it does, in plain words:
## - It reads the real evolution table from
##   res://data/evolution_triggers.json (1,025 species, 598 rows).
##   The table is loaded once, the first time it is needed, and kept
##   in memory. If the file is missing, every check just says the
##   Pokemon cannot evolve; nothing crashes.
## - check_level_up() tests the "level-up" rows for a Pokemon.
##   It also runs the ALSO level-up branches described below and,
##   for Nincada, the shed bonus (see the shed notes below).
## - check_use_item() tests the "use-item" rows (stones and such).
##   Using a Linking Cord also tests the species' trade rows.
## - check_special() tests the special rows that happen at a
##   known moment: "recoil-damage", "tower-of-darkness",
##   "tower-of-waters" and "spin".
## - check_trade() never evolves anything itself. It only reports
##   on the species' trade rows. needs_trade_rule is now false:
##   Riley's rule exists (see below), so trade evolutions can be
##   reached with a Linking Cord and by the level-up branches.
## - apply_evolution() builds the evolved Pokemon as a NEW dict.
##   The input dict is never changed.
## - on_level_up() is the hook the game's level-up code calls after
##   a Pokemon gains a level. It checks and, when the check passes,
##   applies the evolution in one call.
##
## Rules this manager follows:
## - No signals. Every function returns a plain Dictionary, so
##   headless tests can drive it directly.
## - When the caller does not supply a value a row needs (for
##   example the time of day, the place, or the party), that
##   condition FAILS. The manager never guesses a missing value.
## - No data is invented. Stats are never changed here: keeping the
##   current HP and growing the max HP is the caller's job.
##
## Condition fields handled (every field that carries a real value
## somewhere in the table):
## - min_level: the Pokemon's level must be at least this.
## - min_happiness: the Pokemon's friendship must be at least this.
##   Read from the mon's "friendship" value, falling back to
##   "happiness", default 0.
## - time_of_day: must match the context "time_of_day" ("day",
##   "night", "dusk", "full-moon" all appear in the data).
## - held_item: the mon's "item" must match (names are compared as
##   slugs, so "King's Rock" and "kings-rock" are the same item).
## - known_move: one of the mon's moves must match. The mon's
##   "moves" can be an Array of move names or of move dicts.
## - known_move_type: one of the mon's moves must be of this type.
##   Move types come from the real move table at
##   res://data/move_database_954.json when that file is present,
##   or from a "type" value on the move dict itself. If no type can
##   be found for any known move, the condition fails.
## - location: must match the context "location". Some rows list
##   extra places in their notes ("locations: a, b, c"); every place
##   in that list counts as a match too, because the data says so.
## - party_species: a Pokemon of that species must be in the
##   context "party" (an Array of mon dicts).
## - party_type: a Pokemon of that type must be in the context
##   "party". Party mons say their types with a "types" Array or a
##   "type" String; if a party mon carries no type at all, it
##   cannot meet this condition.
## - needs_overworld_rain: the context "weather" must be "rain"
##   (a true context "overworld_rain" also counts).
## - turn_upside_down: the context "turn_upside_down" (or
##   "upside_down") must be true.
## - min_beauty: the mon's "beauty" must be at least this,
##   default 0.
## - relative_physical_stats: compares the mon's Attack and
##   Defense. 1 needs Attack > Defense, -1 needs Attack < Defense,
##   0 needs them equal. Read from "atk"/"def", falling back to
##   "attack"/"defense", default 0.
## - gender: the table has no gender field of its own; the rows
##   that need one carry "gender_id: 1" (female) or "gender_id: 2"
##   (male) in their notes. The mon's "gender" can be a word
##   ("female", "male", "f", "m"), a sign, or the same 1/2 number.
##   A mon with no gender cannot meet a gender condition.
## - minimum_affection: also carried in the notes of two rows. The
##   mon's "affection" must be at least that, default 0.
##
## Special triggers: "recoil-damage", "tower-of-darkness",
## "tower-of-waters" and "spin" are run by check_special(), which
## the game calls at the moment the special thing happens.
## "shed" is run inside check_level_up(): when Nincada's level-up
## row passes, the shed row is tested too and a passing Shedinja
## is reported in the result's "bonus_evolutions" Array. The shed
## context convention is: context "party" is an Array of mon
## dicts and a free slot means party.size() < 6 (no "party" in
## the context means no shed); context "bag" is an Array of item
## slugs, or a Dictionary of slug -> count, and a Poke Ball means
## "poke-ball" is present (with count at least 1 when a count is
## given). Triggers other than the ones named here (use-move and
## the rest) are still not run by any check; their rows stay in
## the table and are returned by evolutions_for() for other code.
##
## Riley's design decision, 2026-11-22: every evolution gated by
## an outside mechanic ALSO evolves by leveling up, so no Pokemon
## stays locked behind trading, links or hardware. The original
## methods keep working, and the data rows keep their real trade
## flags; the branches below are a rule of this manager, not a
## change to the data. In check_level_up():
## - A trade row that names a held item also passes on a level-up
##   when the mon holds that item, at any level; the held item is
##   the gate.
## - A trade row that names no held item also passes on a
##   level-up when the mon's level is at least
##   TRADE_LEVEL_UP_LEVEL (30).
## - A level-up row that fails only because turn_upside_down is
##   unmet also passes at that same level with the upside-down
##   condition dropped (Inkay). No other condition type is ever
##   dropped this way.
## - Meltan's "meltan-candies" row also passes on a level-up at
##   level TRADE_LEVEL_UP_LEVEL or above.
## Separately, check_use_item() with a Linking Cord tests the
## trade rows directly: a row passes when its held item is held,
## or on the cord alone when the row names no held item.

## The level at which trade rows with no held item, and Meltan,
## also evolve on a level-up (Riley's design decision, above).
const TRADE_LEVEL_UP_LEVEL: int = 30

const DATA_PATH: String = "res://data/evolution_triggers.json"
const MOVE_DATA_PATH: String = "res://data/move_database_954.json"
const ASSET_INDEX_SOURCE: String = "PUW MASTER ASSET LIBRARY — INDEX AND SOURCE REGISTER — 2026-11-20.paper"

var _loaded: bool = false
var _rows_by_slug: Dictionary = {}
var _species_count: int = 0
var _row_count: int = 0
var _move_types_loaded: bool = false
var _move_type_by_slug: Dictionary = {}


func get_status() -> Dictionary:
	_ensure_loaded()
	return {
		"module": "evolution",
		"class": "DynamicEvolutionEngine",
		"operational": true,
		"data_path": DATA_PATH,
		"species_loaded": _species_count,
		"evolution_rows": _row_count,
	}


# ----------------------------------------------------------------
# Loading
# ----------------------------------------------------------------

## Load the evolution table once and keep it. Safe to call again;
## it does nothing after the first load. A missing or broken file
## leaves the table empty instead of raising an error.
func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rows_by_slug.clear()
	_species_count = 0
	_row_count = 0
	if not FileAccess.file_exists(DATA_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(DATA_PATH)
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var parsed_dict: Dictionary = parsed
	var data_value: Variant = parsed_dict.get("data", [])
	if not (data_value is Array):
		return
	var data_list: Array = data_value
	for entry_value in data_list:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var slug: String = str(entry.get("slug", "")).strip_edges().to_lower()
		if slug.is_empty():
			continue
		var rows_value: Variant = entry.get("evolves_to", [])
		var rows: Array = []
		if rows_value is Array:
			var rows_list: Array = rows_value
			for row_value in rows_list:
				if row_value is Dictionary:
					var row: Dictionary = row_value
					rows.append(row)
					_row_count += 1
		_rows_by_slug[slug] = rows
		_species_count += 1


## Load the real move types once, for the known_move_type check.
## The move table is keyed by display name ("Moonblast") and each
## entry carries its "type". If the file is missing, the type
## table stays empty and type conditions cannot be met that way.
func _ensure_move_types_loaded() -> void:
	if _move_types_loaded:
		return
	_move_types_loaded = true
	_move_type_by_slug.clear()
	if not FileAccess.file_exists(MOVE_DATA_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(MOVE_DATA_PATH)
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var parsed_dict: Dictionary = parsed
	var moves_value: Variant = parsed_dict.get("moves", {})
	if not (moves_value is Dictionary):
		return
	var moves: Dictionary = moves_value
	for key in moves.keys():
		var entry_value: Variant = moves[key]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var move_type: String = str(entry.get("type", "")).strip_edges().to_lower()
		if move_type.is_empty():
			continue
		_move_type_by_slug[_slugify(str(key))] = move_type
		var entry_name: String = str(entry.get("name", ""))
		if not entry_name.is_empty():
			_move_type_by_slug[_slugify(entry_name)] = move_type


# ----------------------------------------------------------------
# Name cleaning
# ----------------------------------------------------------------

## Turn a display name into the slug the data tables use:
## lower case, spaces become hyphens, apostrophes and dots are
## dropped, the female sign becomes -f and the male sign -m.
## This matches the battle controller's own species cleaning, so
## "Mr. Mime" becomes "mr-mime" and "Thunder Stone" becomes
## "thunder-stone". Text that is already a slug passes through
## unchanged.
static func _slugify(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "-f").replace("♂", "-m")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out


## The slug of the species a mon dict stands for. Battle mon dicts
## carry the species as a display name in "species" (or "name").
static func _mon_species_slug(mon: Dictionary) -> String:
	var raw: String = str(mon.get("species", mon.get("name", "")))
	return _slugify(raw)


## A display name built back from a slug: hyphens become spaces
## and each word starts with a capital letter. "mr-mime" becomes
## "Mr Mime". Good enough for this engine's dicts.
static func _display_name(slug: String) -> String:
	var parts: PackedStringArray = slug.split("-")
	var words: Array = []
	for part in parts:
		var word: String = str(part)
		if word.is_empty():
			continue
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(words)


# ----------------------------------------------------------------
# Reading values out of mon and context dicts
# ----------------------------------------------------------------

## An int read from a dict. Missing or null values give the
## fallback. JSON numbers arrive as floats, so they are cast.
static func _int_or(d: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = d.get(key, null)
	if value == null:
		return fallback
	if value is int:
		var as_int: int = value
		return as_int
	if value is float:
		var as_float: float = value
		return int(as_float)
	if value is String:
		var as_text: String = value
		if as_text.strip_edges().is_empty():
			return fallback
		return int(as_text)
	return fallback


## The mon's friendship: "friendship" first, then "happiness",
## then 0. Some packs store the same value under either name.
static func _friendship_of(mon: Dictionary) -> int:
	if mon.has("friendship") and mon.get("friendship") != null:
		return _int_or(mon, "friendship", 0)
	if mon.has("happiness") and mon.get("happiness") != null:
		return _int_or(mon, "happiness", 0)
	return 0


## The mon's Attack stat: "atk" first, then "attack", then 0.
static func _attack_of(mon: Dictionary) -> int:
	if mon.has("atk") and mon.get("atk") != null:
		return _int_or(mon, "atk", 0)
	return _int_or(mon, "attack", 0)


## The mon's Defense stat: "def" first, then "defense", then 0.
static func _defense_of(mon: Dictionary) -> int:
	if mon.has("def") and mon.get("def") != null:
		return _int_or(mon, "def", 0)
	return _int_or(mon, "defense", 0)


## The slugs of the moves a mon knows. "moves" can be an Array of
## move names ("Ancient Power") or of move dicts (with a "name",
## "id" or "slug" value). Anything else is skipped.
static func _known_move_slugs(mon: Dictionary) -> Array:
	var out: Array = []
	var moves_value: Variant = mon.get("moves", [])
	if not (moves_value is Array):
		return out
	var moves_list: Array = moves_value
	for move_value in moves_list:
		if move_value is String:
			var move_name: String = move_value
			out.append(_slugify(move_name))
		elif move_value is Dictionary:
			var move_dict: Dictionary = move_value
			var raw_name: String = str(move_dict.get("name", move_dict.get("id", move_dict.get("slug", ""))))
			if not raw_name.is_empty():
				out.append(_slugify(raw_name))
	return out


## The types of the moves a mon knows, lower case. A move dict can
## carry its own "type"; otherwise the type comes from the real
## move table. Moves whose type cannot be found add nothing.
func _known_move_types(mon: Dictionary) -> Array:
	_ensure_move_types_loaded()
	var out: Array = []
	var moves_value: Variant = mon.get("moves", [])
	if not (moves_value is Array):
		return out
	var moves_list: Array = moves_value
	for move_value in moves_list:
		var move_type: String = ""
		var move_slug: String = ""
		if move_value is String:
			var move_name: String = move_value
			move_slug = _slugify(move_name)
		elif move_value is Dictionary:
			var move_dict: Dictionary = move_value
			move_type = str(move_dict.get("type", "")).strip_edges().to_lower()
			var raw_name: String = str(move_dict.get("name", move_dict.get("id", move_dict.get("slug", ""))))
			move_slug = _slugify(raw_name)
		if move_type.is_empty() and not move_slug.is_empty():
			move_type = str(_move_type_by_slug.get(move_slug, ""))
		if not move_type.is_empty() and not out.has(move_type):
			out.append(move_type)
	return out


## The party list from the context, as an Array of mon dicts.
static func _party_of(context: Dictionary) -> Array:
	var out: Array = []
	var party_value: Variant = context.get("party", [])
	if not (party_value is Array):
		return out
	var party_list: Array = party_value
	for member_value in party_list:
		if member_value is Dictionary:
			var member: Dictionary = member_value
			out.append(member)
	return out


## The type names one party mon carries, lower case. Read from a
## "types" Array or a single "type" String; a mon with neither
## carries no types and cannot meet a party_type condition.
static func _types_of(mon: Dictionary) -> Array:
	var out: Array = []
	var types_value: Variant = mon.get("types", null)
	if types_value is Array:
		var types_list: Array = types_value
		for type_value in types_list:
			var type_name: String = str(type_value).strip_edges().to_lower()
			if not type_name.is_empty():
				out.append(type_name)
	elif types_value is String:
		var single: String = types_value
		single = single.strip_edges().to_lower()
		if not single.is_empty():
			out.append(single)
	var type_value2: Variant = mon.get("type", null)
	if type_value2 is String:
		var single2: String = type_value2
		single2 = single2.strip_edges().to_lower()
		if not single2.is_empty() and not out.has(single2):
			out.append(single2)
	return out


## The mon's gender as a plain word: "female", "male", or "" when
## the mon does not say. Accepts words, signs, and the table's own
## 1 (female) / 2 (male) numbers.
static func _gender_of(mon: Dictionary) -> String:
	var value: Variant = mon.get("gender", null)
	if value == null:
		return ""
	if value is int:
		var as_int: int = value
		if as_int == 1:
			return "female"
		if as_int == 2:
			return "male"
		return ""
	if value is float:
		var as_float: float = value
		if int(as_float) == 1:
			return "female"
		if int(as_float) == 2:
			return "male"
		return ""
	var text: String = str(value).strip_edges().to_lower()
	if text == "female" or text == "f" or text == "♀" or text == "1":
		return "female"
	if text == "male" or text == "m" or text == "♂" or text == "2":
		return "male"
	return ""


## One "key: value" number read out of a row's notes text, or -1
## when the notes do not carry it. The notes are part of the real
## data; this only reads what is written there.
static func _notes_number(notes: String, key: String) -> int:
	var marker: String = key + ":"
	var at: int = notes.find(marker)
	if at < 0:
		return -1
	var rest: String = notes.substr(at + marker.length())
	var digits: String = ""
	var i: int = 0
	while i < rest.length():
		var ch: String = rest.substr(i, 1)
		if ch == " " and digits.is_empty():
			i += 1
			continue
		if ch >= "0" and ch <= "9":
			digits += ch
			i += 1
			continue
		break
	if digits.is_empty():
		return -1
	return int(digits)


## Every place a row accepts: its "location" field plus any extra
## places listed after "locations:" in its notes.
static func _row_locations(row: Dictionary) -> Array:
	var out: Array = []
	var field_value: Variant = row.get("location", null)
	if field_value != null:
		var field_slug: String = _slugify(str(field_value))
		if not field_slug.is_empty():
			out.append(field_slug)
	var notes: String = str(row.get("notes", ""))
	var at: int = notes.find("locations:")
	if at >= 0:
		var rest: String = notes.substr(at + "locations:".length())
		var stop: int = rest.find(";")
		if stop >= 0:
			rest = rest.substr(0, stop)
		var parts: PackedStringArray = rest.split(",")
		for part in parts:
			var place: String = _slugify(str(part))
			if not place.is_empty() and not out.has(place):
				out.append(place)
	return out


# ----------------------------------------------------------------
# The condition test shared by every check
# ----------------------------------------------------------------

## Test every condition one row carries (not the trigger itself;
## the caller picks rows by trigger). Returns a Dictionary:
## {"ok": bool, "fail_count": int, "reason": String}. The reason
## names the first unmet condition in plain words.
func _check_row_conditions(mon: Dictionary, row: Dictionary, context: Dictionary) -> Dictionary:
	var fails: Array = []

	# Minimum level.
	var min_level_value: Variant = row.get("min_level", null)
	if min_level_value != null:
		var min_level: int = _int_or(row, "min_level", 0)
		var level: int = _int_or(mon, "level", 0)
		if level < min_level:
			fails.append("level %d is below the needed level %d" % [level, min_level])

	# Minimum happiness (friendship).
	var min_happiness_value: Variant = row.get("min_happiness", null)
	if min_happiness_value != null:
		var min_happiness: int = _int_or(row, "min_happiness", 0)
		var friendship: int = _friendship_of(mon)
		if friendship < min_happiness:
			fails.append("friendship %d is below the needed %d" % [friendship, min_happiness])

	# Time of day. The context must say it; no guess is made.
	var time_value: Variant = row.get("time_of_day", null)
	if time_value != null and not str(time_value).strip_edges().is_empty():
		var needed_time: String = str(time_value).strip_edges().to_lower()
		var given_time: String = str(context.get("time_of_day", "")).strip_edges().to_lower()
		if given_time != needed_time:
			if given_time.is_empty():
				fails.append("needs time of day %s, but the context does not say the time of day" % needed_time)
			else:
				fails.append("needs time of day %s, but it is %s" % [needed_time, given_time])

	# Held item.
	var held_value: Variant = row.get("held_item", null)
	if held_value != null and not str(held_value).strip_edges().is_empty():
		var needed_item: String = _slugify(str(held_value))
		var held_item: String = _slugify(str(mon.get("item", mon.get("held_item", ""))))
		if held_item != needed_item:
			fails.append("needs held item %s" % needed_item)

	# Known move.
	var move_value: Variant = row.get("known_move", null)
	if move_value != null and not str(move_value).strip_edges().is_empty():
		var needed_move: String = _slugify(str(move_value))
		if not _known_move_slugs(mon).has(needed_move):
			fails.append("needs to know the move %s" % needed_move)

	# Known move type.
	var move_type_value: Variant = row.get("known_move_type", null)
	if move_type_value != null and not str(move_type_value).strip_edges().is_empty():
		var needed_type: String = str(move_type_value).strip_edges().to_lower()
		if not _known_move_types(mon).has(needed_type):
			fails.append("needs to know a %s type move" % needed_type)

	# Location. The context must say it; no guess is made.
	var locations: Array = _row_locations(row)
	if not locations.is_empty():
		var given_location: String = _slugify(str(context.get("location", "")))
		if not locations.has(given_location):
			if given_location.is_empty():
				fails.append("needs location %s, but the context does not say the location" % str(locations[0]))
			else:
				fails.append("needs location %s, but the location is %s" % [str(locations[0]), given_location])

	# A species that must be in the party.
	var party_species_value: Variant = row.get("party_species", null)
	if party_species_value != null and not str(party_species_value).strip_edges().is_empty():
		var needed_species: String = _slugify(str(party_species_value))
		var found_species: bool = false
		for member in _party_of(context):
			var member_dict: Dictionary = member
			if _mon_species_slug(member_dict) == needed_species:
				found_species = true
				break
		if not found_species:
			fails.append("needs %s in the party" % needed_species)

	# A type that must be in the party.
	var party_type_value: Variant = row.get("party_type", null)
	if party_type_value != null and not str(party_type_value).strip_edges().is_empty():
		var needed_party_type: String = str(party_type_value).strip_edges().to_lower()
		var found_type: bool = false
		for member in _party_of(context):
			var member_dict: Dictionary = member
			if _types_of(member_dict).has(needed_party_type):
				found_type = true
				break
		if not found_type:
			fails.append("needs a %s type Pokemon in the party" % needed_party_type)

	# Overworld rain.
	var rain_value: Variant = row.get("needs_overworld_rain", false)
	if rain_value is bool and bool(rain_value):
		var weather: String = str(context.get("weather", "")).strip_edges().to_lower()
		var rain_flag: Variant = context.get("overworld_rain", false)
		var is_rain: bool = weather == "rain" or (rain_flag is bool and bool(rain_flag))
		if not is_rain:
			fails.append("needs rain in the overworld")

	# Device turned upside down.
	var upside_value: Variant = row.get("turn_upside_down", false)
	if upside_value is bool and bool(upside_value):
		var flag_value: Variant = context.get("turn_upside_down", context.get("upside_down", false))
		var is_upside: bool = flag_value is bool and bool(flag_value)
		if not is_upside:
			fails.append("needs the device turned upside down")

	# Minimum beauty.
	var beauty_value: Variant = row.get("min_beauty", null)
	if beauty_value != null:
		var min_beauty: int = _int_or(row, "min_beauty", 0)
		var beauty: int = _int_or(mon, "beauty", 0)
		if beauty < min_beauty:
			fails.append("beauty %d is below the needed %d" % [beauty, min_beauty])

	# Attack against Defense.
	var relative_value: Variant = row.get("relative_physical_stats", null)
	if relative_value != null:
		var relative: int = _int_or(row, "relative_physical_stats", 0)
		var atk: int = _attack_of(mon)
		var def: int = _defense_of(mon)
		var actual: int = 0
		if atk > def:
			actual = 1
		elif atk < def:
			actual = -1
		if actual != relative:
			if relative == 1:
				fails.append("needs Attack above Defense (Attack %d, Defense %d)" % [atk, def])
			elif relative == -1:
				fails.append("needs Attack below Defense (Attack %d, Defense %d)" % [atk, def])
			else:
				fails.append("needs Attack equal to Defense (Attack %d, Defense %d)" % [atk, def])

	# Gender, carried in the notes as gender_id (1 female, 2 male).
	var notes: String = str(row.get("notes", ""))
	var gender_id: int = _notes_number(notes, "gender_id")
	if gender_id == 1 or gender_id == 2:
		var needed_gender: String = "female"
		if gender_id == 2:
			needed_gender = "male"
		var mon_gender: String = _gender_of(mon)
		if mon_gender != needed_gender:
			if mon_gender.is_empty():
				fails.append("needs a %s Pokemon, but the Pokemon has no gender set" % needed_gender)
			else:
				fails.append("needs a %s Pokemon, but this one is %s" % [needed_gender, mon_gender])

	# Minimum affection, carried in the notes of two rows.
	var min_affection: int = _notes_number(notes, "minimum_affection")
	if min_affection >= 0:
		var affection: int = _int_or(mon, "affection", 0)
		if affection < min_affection:
			fails.append("affection %d is below the needed %d" % [affection, min_affection])

	var reason: String = ""
	if not fails.is_empty():
		reason = str(fails[0])
	return {"ok": fails.is_empty(), "fail_count": fails.size(), "reason": reason}


## Run one trigger's rows for a mon and build the shared answer
## shape. The first row whose conditions all pass wins. When none
## pass, the answer names the unmet condition of the closest row
## (the row with the fewest unmet conditions).
func _check_trigger(mon: Dictionary, trigger: String, context: Dictionary) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var rows: Array = evolutions_for(slug)
	var matching: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		if str(row.get("trigger", "")) == trigger:
			matching.append(row)
	if matching.is_empty():
		return {
			"can_evolve": false,
			"to_slug": "",
			"to_id": 0,
			"row": {},
			"reason": "%s has no %s evolution in the data" % [slug, trigger],
		}
	var best_row: Dictionary = {}
	var best_result: Dictionary = {}
	var best_fails: int = -1
	for row_value in matching:
		var row: Dictionary = row_value
		var result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(result.get("ok", false)):
			return {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}
		var fail_count: int = _int_or(result, "fail_count", 0)
		if best_fails < 0 or fail_count < best_fails:
			best_fails = fail_count
			best_row = row
			best_result = result
	return {
		"can_evolve": false,
		"to_slug": str(best_row.get("to_slug", "")),
		"to_id": _int_or(best_row, "to_id", 0),
		"row": best_row,
		"reason": str(best_result.get("reason", "conditions not met")),
	}


## The Linking Cord test against the species' trade rows: a row
## passes when its held item condition is met (the mon holds the
## named item), or on the cord alone when the row names no held
## item. The shared condition test does exactly that, because a
## trade row's only named gate is its held item. Returns the
## shared answer shape, or an empty Dictionary when the species
## has no trade row at all.
func _check_linking_cord_trade(mon: Dictionary, context: Dictionary) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var best_row: Dictionary = {}
	var best_result: Dictionary = {}
	var best_fails: int = -1
	var found_trade: bool = false
	for row_value in evolutions_for(slug):
		var row: Dictionary = row_value
		if not _is_trade_row(row):
			continue
		found_trade = true
		var result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(result.get("ok", false)):
			return {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}
		var fail_count: int = _int_or(result, "fail_count", 0)
		if best_fails < 0 or fail_count < best_fails:
			best_fails = fail_count
			best_row = row
			best_result = result
	if not found_trade:
		return {}
	return {
		"can_evolve": false,
		"to_slug": str(best_row.get("to_slug", "")),
		"to_id": _int_or(best_row, "to_id", 0),
		"row": best_row,
		"reason": str(best_result.get("reason", "conditions not met")),
	}


# ----------------------------------------------------------------
# Special triggers, trade branches and the shed bonus
# ----------------------------------------------------------------

## True when a row is a trade row: its trigger is "trade" or its
## trade flag is set on a "trade" row.
static func _is_trade_row(row: Dictionary) -> bool:
	if str(row.get("trigger", "")) == "trade":
		return true
	var trade_flag: Variant = row.get("trade", false)
	return trade_flag is bool and bool(trade_flag) and str(row.get("trigger", "")) == "trade"


## A number read from the context, as a float. Returns
## {"has": bool, "value": float}; "has" is false when the key is
## missing or is not a number, so callers can fail the condition
## instead of guessing.
static func _context_number(context: Dictionary, key: String) -> Dictionary:
	var value: Variant = context.get(key, null)
	if value is int:
		var as_int: int = value
		return {"has": true, "value": float(as_int)}
	if value is float:
		var as_float: float = value
		return {"has": true, "value": as_float}
	return {"has": false, "value": 0.0}


## The spin test for one Milcery row. The row's notes carry a
## condition expression such as
## "condition_expression: SPIN_DIR 0 == SPIN_SEC 5 < &&" or
## "condition_expression: SPIN_SEC 10 >=". The words mean: when
## SPIN_DIR is present, the context "spin_dir" must equal the
## number after it; SPIN_SEC compares the context "spin_seconds"
## against the number after it with the operator written after
## that number ("<", ">=" and the like). Missing spin context
## fails. Returns {"ok": bool, "reason": String}.
static func _check_spin_expression(row: Dictionary, context: Dictionary) -> Dictionary:
	var notes: String = str(row.get("notes", ""))
	var at: int = notes.find("condition_expression:")
	if at < 0:
		return {"ok": false, "reason": "the spin row carries no condition expression"}
	var expression: String = notes.substr(at + "condition_expression:".length()).strip_edges()
	var raw_parts: PackedStringArray = expression.split(" ")
	var tokens: Array = []
	for part in raw_parts:
		var token: String = str(part).strip_edges()
		if not token.is_empty():
			tokens.append(token)
	var i: int = 0
	while i < tokens.size():
		var token: String = str(tokens[i])
		if token == "SPIN_DIR":
			if i + 1 >= tokens.size():
				return {"ok": false, "reason": "the spin expression is incomplete"}
			var needed_dir: int = int(str(tokens[i + 1]))
			var dir_read: Dictionary = _context_number(context, "spin_dir")
			if not bool(dir_read.get("has", false)):
				return {"ok": false, "reason": "needs a spin, but the context does not say the spin direction"}
			if int(float(dir_read.get("value", 0.0))) != needed_dir:
				return {"ok": false, "reason": "needs spin direction %d" % needed_dir}
			i += 2
			continue
		if token == "SPIN_SEC":
			if i + 2 >= tokens.size():
				return {"ok": false, "reason": "the spin expression is incomplete"}
			var threshold: float = float(str(tokens[i + 1]))
			var operator_text: String = str(tokens[i + 2])
			var sec_read: Dictionary = _context_number(context, "spin_seconds")
			if not bool(sec_read.get("has", false)):
				return {"ok": false, "reason": "needs a spin, but the context does not say the spin length in seconds"}
			var seconds: float = float(sec_read.get("value", 0.0))
			var passes: bool = false
			if operator_text == "<":
				passes = seconds < threshold
			elif operator_text == ">=":
				passes = seconds >= threshold
			elif operator_text == ">":
				passes = seconds > threshold
			elif operator_text == "<=":
				passes = seconds <= threshold
			elif operator_text == "==":
				passes = seconds == threshold
			else:
				return {"ok": false, "reason": "the spin expression uses an unknown operator %s" % operator_text}
			if not passes:
				return {"ok": false, "reason": "needs a spin of %s %s seconds, but the spin was %s seconds" % [operator_text, str(threshold), str(seconds)]}
			i += 3
			continue
		i += 1
	return {"ok": true, "reason": ""}


## The Alcremie cream name for a passing spin, from the real
## game rules keyed on time of day, direction and how long the
## spin lasted (short is under 5 seconds, long is 5 or more;
## dusk with a spin of 10 seconds or more is its own case).
## Convention, written down because the data's SPIN_DIR 0/1 does
## not itself say which number is which way: SPIN_DIR 0 means
## clockwise and SPIN_DIR 1 means counterclockwise.
static func _alcremie_form(context: Dictionary) -> String:
	var time_of_day: String = str(context.get("time_of_day", "")).strip_edges().to_lower()
	var sec_read: Dictionary = _context_number(context, "spin_seconds")
	var seconds: float = float(sec_read.get("value", 0.0))
	if time_of_day == "dusk" and seconds >= 10.0:
		return "Rainbow Swirl"
	var dir_read: Dictionary = _context_number(context, "spin_dir")
	var clockwise: bool = int(float(dir_read.get("value", 0.0))) == 0
	var long_spin: bool = seconds >= 5.0
	if time_of_day == "day":
		if clockwise and not long_spin:
			return "Vanilla Cream"
		if not clockwise and not long_spin:
			return "Ruby Cream"
		if clockwise and long_spin:
			return "Matcha Cream"
		return "Mint Cream"
	if time_of_day == "night":
		if clockwise and not long_spin:
			return "Lemon Cream"
		if not clockwise and not long_spin:
			return "Salted Cream"
		if clockwise and long_spin:
			return "Ruby Swirl"
		return "Caramel Swirl"
	return ""


## The decoration name that comes from the Sweet a Milcery
## holds: strawberry-sweet gives Strawberry, and so on.
static func _alcremie_decoration(held_item_slug: String) -> String:
	var decorations: Dictionary = {
		"strawberry-sweet": "Strawberry",
		"berry-sweet": "Berry",
		"love-sweet": "Love",
		"star-sweet": "Star",
		"clover-sweet": "Clover",
		"flower-sweet": "Flower",
		"ribbon-sweet": "Ribbon",
	}
	return str(decorations.get(held_item_slug, ""))


## Test one special row: the shared conditions plus the extra
## test its trigger needs. Returns the same shape as
## _check_row_conditions: {"ok", "fail_count", "reason"}.
func _check_special_row(mon: Dictionary, row: Dictionary, context: Dictionary) -> Dictionary:
	var base: Dictionary = _check_row_conditions(mon, row, context)
	var fails: int = _int_or(base, "fail_count", 0)
	var reason: String = str(base.get("reason", ""))
	var trigger: String = str(row.get("trigger", ""))
	var extra_ok: bool = true
	var extra_reason: String = ""
	if trigger == "recoil-damage":
		var minimum: int = _notes_number(str(row.get("notes", "")), "minimum_damage_taken")
		var recoil_read: Dictionary = _context_number(context, "recoil_damage_taken")
		if not bool(recoil_read.get("has", false)):
			extra_ok = false
			extra_reason = "needs %d recoil damage taken, but the context does not say how much recoil damage was taken" % minimum
		elif float(recoil_read.get("value", 0.0)) < float(minimum):
			extra_ok = false
			extra_reason = "needs %d recoil damage taken, but only %s was taken" % [minimum, str(recoil_read.get("value", 0.0))]
	elif trigger == "tower-of-darkness" or trigger == "tower-of-waters":
		var needed_scroll: String = "scroll-of-darkness"
		if trigger == "tower-of-waters":
			needed_scroll = "scroll-of-waters"
		var used_scroll: String = _slugify(str(context.get("scroll_used", "")))
		if used_scroll != needed_scroll:
			extra_ok = false
			if used_scroll.is_empty():
				extra_reason = "needs the %s to be used, but the context does not say a scroll was used" % needed_scroll
			else:
				extra_reason = "needs the %s to be used, but %s was used" % [needed_scroll, used_scroll]
	elif trigger == "spin":
		var spin_result: Dictionary = _check_spin_expression(row, context)
		if not bool(spin_result.get("ok", false)):
			extra_ok = false
			extra_reason = str(spin_result.get("reason", "spin conditions not met"))
	if not extra_ok:
		fails += 1
		if reason.is_empty():
			reason = extra_reason
	return {"ok": fails == 0, "fail_count": fails, "reason": reason}


## True when the context "bag" holds a Poke Ball. The bag is an
## Array of item slugs, or a Dictionary of slug -> count where
## the count must be at least 1.
static func _bag_has_poke_ball(context: Dictionary) -> bool:
	var bag_value: Variant = context.get("bag", null)
	if bag_value is Array:
		var bag_list: Array = bag_value
		for item_value in bag_list:
			if _slugify(str(item_value)) == "poke-ball":
				return true
		return false
	if bag_value is Dictionary:
		var bag_dict: Dictionary = bag_value
		for key in bag_dict.keys():
			if _slugify(str(key)) != "poke-ball":
				continue
			var count_value: Variant = bag_dict[key]
			if count_value is int:
				var count_int: int = count_value
				return count_int >= 1
			if count_value is float:
				var count_float: float = count_value
				return count_float >= 1.0
			return true
		return false
	return false


## The shed bonus for a mon whose level-up evolution just
## passed: one result-style dict per passing "shed" row. The
## shed row passes when the context shows a free party slot and
## a Poke Ball in the bag (see the header for the convention).
## Missing party or bag context means no shed.
func _shed_bonus_evolutions(mon: Dictionary, context: Dictionary) -> Array:
	var out: Array = []
	if not context.has("party"):
		return out
	var party_value: Variant = context.get("party", null)
	if not (party_value is Array):
		return out
	var party_list: Array = party_value
	if party_list.size() >= 6:
		return out
	if not _bag_has_poke_ball(context):
		return out
	var slug: String = _mon_species_slug(mon)
	for row_value in evolutions_for(slug):
		var row: Dictionary = row_value
		if str(row.get("trigger", "")) != "shed":
			continue
		var result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(result.get("ok", false)):
			out.append({
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			})
	return out


# ----------------------------------------------------------------
# Public API
# ----------------------------------------------------------------

## Every evolution row for one species, as stored in the data.
## The species can be given as a slug ("mr-mime") or a display
## name ("Mr. Mime"); both are cleaned the same way. Returns an
## empty Array when the species has no evolutions or is unknown.
func evolutions_for(species_slug: String) -> Array:
	_ensure_loaded()
	var slug: String = _slugify(species_slug)
	var rows_value: Variant = _rows_by_slug.get(slug, [])
	if rows_value is Array:
		var rows: Array = rows_value
		return rows
	return []


## Can this Pokemon evolve by leveling up right now? Tests every
## "level-up" row for the mon's species, then Riley's ALSO
## level-up branches (see the header): trade rows, the Inkay
## upside-down branch, and Meltan. The context can carry
## "time_of_day", "location", "party", "weather" and
## "turn_upside_down". Returns the shared answer shape:
## {"can_evolve", "to_slug", "to_id", "row", "reason"}, plus a
## "bonus_evolutions" Array holding any extra evolution that
## comes along with the main one (Nincada's Shedinja).
func check_level_up(mon: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _check_trigger(mon, "level-up", context)
	if not bool(result.get("can_evolve", false)):
		var branch: Dictionary = _check_level_up_branches(mon, context)
		if bool(branch.get("can_evolve", false)):
			result = branch
	if bool(result.get("can_evolve", false)):
		result["bonus_evolutions"] = _shed_bonus_evolutions(mon, context)
	else:
		result["bonus_evolutions"] = []
	return result


## Riley's ALSO level-up branches (design decision 2026-11-22,
## see the header). Tests, in order: the trade rows, the
## upside-down branch for level-up rows, and Meltan's candies
## row. Returns the shared answer shape.
func _check_level_up_branches(mon: Dictionary, context: Dictionary) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var rows: Array = evolutions_for(slug)
	var level: int = _int_or(mon, "level", 0)

	# Trade rows: a held item is the gate when the row names one
	# (any level); with no held item the gate is level 30.
	for row_value in rows:
		var row: Dictionary = row_value
		if not _is_trade_row(row):
			continue
		var held_value: Variant = row.get("held_item", null)
		var has_held: bool = held_value != null and not str(held_value).strip_edges().is_empty()
		if not has_held and level < TRADE_LEVEL_UP_LEVEL:
			continue
		var trade_result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(trade_result.get("ok", false)):
			return {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}

	# Upside-down branch: a level-up row that fails only because
	# turn_upside_down is unmet passes with that one condition
	# dropped. Testing the row again with the flag supplied
	# proves nothing else was failing, because every other
	# condition is tested exactly the same way.
	for row_value in rows:
		var row: Dictionary = row_value
		if str(row.get("trigger", "")) != "level-up":
			continue
		var upside_value: Variant = row.get("turn_upside_down", false)
		if not (upside_value is bool and bool(upside_value)):
			continue
		var flipped_context: Dictionary = context.duplicate()
		flipped_context["turn_upside_down"] = true
		var flipped_result: Dictionary = _check_row_conditions(mon, row, flipped_context)
		if bool(flipped_result.get("ok", false)):
			return {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}

	# Meltan: its candies row also passes at level 30.
	if level >= TRADE_LEVEL_UP_LEVEL:
		for row_value in rows:
			var row: Dictionary = row_value
			if str(row.get("trigger", "")) != "meltan-candies":
				continue
			var meltan_result: Dictionary = _check_row_conditions(mon, row, context)
			if bool(meltan_result.get("ok", false)):
				return {
					"can_evolve": true,
					"to_slug": str(row.get("to_slug", "")),
					"to_id": _int_or(row, "to_id", 0),
					"row": row,
					"reason": "all conditions met",
				}

	return {
		"can_evolve": false,
		"to_slug": "",
		"to_id": 0,
		"row": {},
		"reason": "%s has no level-up branch evolution ready" % slug,
	}


## Can this Pokemon evolve through a special trigger right now?
## Tests the "recoil-damage", "tower-of-darkness",
## "tower-of-waters" and "spin" rows. The context carries what
## the moment knows: "recoil_damage_taken" for recoil rows,
## "scroll_used" for the tower rows, and "time_of_day",
## "spin_dir" and "spin_seconds" for spin rows. Returns the
## shared answer shape; a passing spin also carries "form" (the
## Alcremie cream name) and "form_detail" (the cream name with
## its decoration, from the Sweet the mon holds).
func check_special(mon: Dictionary, context: Dictionary = {}) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var rows: Array = evolutions_for(slug)
	var special_triggers: Array = ["recoil-damage", "tower-of-darkness", "tower-of-waters", "spin"]
	var matching: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		if special_triggers.has(str(row.get("trigger", ""))):
			matching.append(row)
	if matching.is_empty():
		return {
			"can_evolve": false,
			"to_slug": "",
			"to_id": 0,
			"row": {},
			"reason": "%s has no special evolution in the data" % slug,
		}
	var best_row: Dictionary = {}
	var best_result: Dictionary = {}
	var best_fails: int = -1
	for row_value in matching:
		var row: Dictionary = row_value
		var result: Dictionary = _check_special_row(mon, row, context)
		if bool(result.get("ok", false)):
			var answer: Dictionary = {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}
			if str(row.get("trigger", "")) == "spin":
				var form: String = _alcremie_form(context)
				var held_item: String = _slugify(str(mon.get("item", mon.get("held_item", ""))))
				var decoration: String = _alcremie_decoration(held_item)
				answer["form"] = form
				if decoration.is_empty():
					answer["form_detail"] = form
				else:
					answer["form_detail"] = "%s (%s decoration)" % [form, decoration]
			return answer
		var fail_count: int = _int_or(result, "fail_count", 0)
		if best_fails < 0 or fail_count < best_fails:
			best_fails = fail_count
			best_row = row
			best_result = result
	return {
		"can_evolve": false,
		"to_slug": str(best_row.get("to_slug", "")),
		"to_id": _int_or(best_row, "to_id", 0),
		"row": best_row,
		"reason": str(best_result.get("reason", "conditions not met")),
	}


## Can this Pokemon evolve by using the named item on it? Tests
## the "use-item" rows whose trigger_item matches the used item.
## Item names in the data are already slugs ("thunder-stone");
## the used item name is cleaned to a slug before comparing, so
## "Thunder Stone" and "thunder-stone" both match. Rows for other
## items are not tested at all.
func check_use_item(mon: Dictionary, item_name: String, context: Dictionary = {}) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var used_item: String = _slugify(item_name)
	var rows: Array = evolutions_for(slug)
	var matching: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		if str(row.get("trigger", "")) != "use-item":
			continue
		var trigger_item_value: Variant = row.get("trigger_item", null)
		if trigger_item_value == null:
			continue
		if _slugify(str(trigger_item_value)) == used_item:
			matching.append(row)
	if matching.is_empty():
		# A Linking Cord also works through the trade rows (see
		# below), even for species with no use-item cord row.
		if used_item == "linking-cord":
			var cord_result: Dictionary = _check_linking_cord_trade(mon, context)
			if not cord_result.is_empty():
				return cord_result
		return {
			"can_evolve": false,
			"to_slug": "",
			"to_id": 0,
			"row": {},
			"reason": "%s has no use-item evolution with %s in the data" % [slug, used_item],
		}
	var best_row: Dictionary = {}
	var best_result: Dictionary = {}
	var best_fails: int = -1
	for row_value in matching:
		var row: Dictionary = row_value
		var result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(result.get("ok", false)):
			return {
				"can_evolve": true,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"reason": "all conditions met",
			}
		var fail_count: int = _int_or(result, "fail_count", 0)
		if best_fails < 0 or fail_count < best_fails:
			best_fails = fail_count
			best_row = row
			best_result = result
	# The normal use-item rows did not pass. A Linking Cord still
	# gets its trade-row test before the answer is no.
	if used_item == "linking-cord":
		var cord_result: Dictionary = _check_linking_cord_trade(mon, context)
		if bool(cord_result.get("can_evolve", false)):
			return cord_result
	return {
		"can_evolve": false,
		"to_slug": str(best_row.get("to_slug", "")),
		"to_id": _int_or(best_row, "to_id", 0),
		"row": best_row,
		"reason": str(best_result.get("reason", "conditions not met")),
	}


## Trade evolutions are reported here, never performed by this
## check itself. needs_trade_rule is false: Riley's rule now
## exists (2026-11-22), so the note says the trade evolution can
## be reached with a Linking Cord and by the level-up branch
## (held item / level 30). When the row's other conditions are
## not met, the note names the unmet condition too. A species
## with no trade row also gets needs_trade_rule false.
func check_trade(mon: Dictionary, context: Dictionary = {}) -> Dictionary:
	var slug: String = _mon_species_slug(mon)
	var rows: Array = evolutions_for(slug)
	var trade_rows: Array = []
	for row_value in rows:
		var row: Dictionary = row_value
		var is_trade: bool = str(row.get("trigger", "")) == "trade"
		var trade_flag: Variant = row.get("trade", false)
		if trade_flag is bool and bool(trade_flag) and str(row.get("trigger", "")) == "trade":
			is_trade = true
		if is_trade:
			trade_rows.append(row)
	if trade_rows.is_empty():
		return {
			"can_evolve": false,
			"blocked": "",
			"needs_trade_rule": false,
			"to_slug": "",
			"to_id": 0,
			"row": {},
			"note": "%s has no trade evolution in the data" % slug,
		}
	for row_value in trade_rows:
		var row: Dictionary = row_value
		var result: Dictionary = _check_row_conditions(mon, row, context)
		if bool(result.get("ok", false)):
			return {
				"can_evolve": false,
				"blocked": "trade",
				"needs_trade_rule": false,
				"to_slug": str(row.get("to_slug", "")),
				"to_id": _int_or(row, "to_id", 0),
				"row": row,
				"note": "Trade evolution can now be reached with a Linking Cord and by Riley's level-up branch (held item / level 30).",
			}
	# A trade row exists but its other conditions are not met yet.
	var first_row: Dictionary = trade_rows[0]
	var first_result: Dictionary = _check_row_conditions(mon, first_row, context)
	return {
		"can_evolve": false,
		"blocked": "trade",
		"needs_trade_rule": false,
		"to_slug": str(first_row.get("to_slug", "")),
		"to_id": _int_or(first_row, "to_id", 0),
		"row": first_row,
		"note": "Trade evolution can now be reached with a Linking Cord and by Riley's level-up branch (held item / level 30). Other conditions not met yet: %s" % str(first_result.get("reason", "")),
	}


## Build the evolved Pokemon as a NEW dict. The input mon is
## never changed. The new dict keeps the level, exp, moves, held
## item, current HP and everything else as it was; only the
## species changes, and "evolved_from" records the old slug.
## Stats are not touched: if the max HP should grow, that is the
## caller's job, and no stat change is invented here.
func apply_evolution(mon: Dictionary, row: Dictionary) -> Dictionary:
	var new_mon: Dictionary = mon.duplicate(true)
	var old_slug: String = _mon_species_slug(mon)
	var to_slug: String = str(row.get("to_slug", ""))
	if to_slug.is_empty():
		return new_mon
	var display: String = _display_name(to_slug)
	new_mon["species"] = display
	new_mon["name"] = display
	new_mon["evolved_from"] = old_slug
	return new_mon


## The hook the game's level-up code calls after a Pokemon gains
## a level. It runs the level-up check and, when the Pokemon can
## evolve, applies the evolution. Returns {"evolved": true,
## "mon": the new mon dict, "to_slug": ..., "check": ...} or
## {"evolved": false, "mon": the mon as it was, "check": ...}.
## Trade species can evolve through this hook by Riley's
## level-up branches, which check_level_up() runs.
func on_level_up(mon: Dictionary, context: Dictionary = {}) -> Dictionary:
	var check: Dictionary = check_level_up(mon, context)
	if not bool(check.get("can_evolve", false)):
		return {
			"evolved": false,
			"mon": mon,
			"to_slug": str(check.get("to_slug", "")),
			"check": check,
			"reason": str(check.get("reason", "")),
		}
	var row_value: Variant = check.get("row", {})
	var row: Dictionary = {}
	if row_value is Dictionary:
		row = row_value
	var new_mon: Dictionary = apply_evolution(mon, row)
	return {
		"evolved": true,
		"mon": new_mon,
		"to_slug": str(check.get("to_slug", "")),
		"check": check,
		"reason": "evolved by level-up",
	}
