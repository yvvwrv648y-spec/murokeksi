# LearnsetResolver — learnset lookups for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# It reads the learnsets file (learnsets_compact.json, copied from the
# Pokemon Showdown open data) and answers simple questions: can this
# Pokemon learn this move, how can it learn it, and what does it learn
# when it levels up. It never changes game data. It never crashes on a
# name it does not know — it just returns an empty answer.
#
# Data file this reads:
#   learnsets_compact.json — a Dictionary with a "learnsets" key.
#   "learnsets" maps a Showdown species slug (like "bulbasaur") to a
#   Dictionary with a "learnset" key, which maps a move slug (like
#   "thunderbolt") to an Array of method codes (like ["9M", "8L33"]).
#   1,289 species are in the file. 56 of them have NO "learnset" key at
#   all — only {"eventOnly": true, ...}. Those are alternate forms such
#   as deoxysattack, giratinaorigin, shayminsky and the Arceus type
#   forms. For those, this script falls back to the base species
#   (deoxys, giratina, shaymin, arceus).
#
#   A further 24 forme species (aegislashshield, keldeoordinary,
#   miniorredmeteor, ...) are not keys in the file at all: the held
#   Showdown data records their learnset only under the base species.
#   A second-chance pass (FORME_SUFFIXES_EXTENDED +
#   _resolve_key_extended) reaches that base record for them. It runs
#   only when the exact key and the original suffix pass both fail,
#   and exact keys always win first, so formes with genuinely
#   different learnsets (indeedeef, urshifurapidstrike) are never
#   reduced to the base.
#
# Method codes in the data (first character is the generation number,
# second character is the method):
#   L = level-up, followed by the level. Example: "9L33" = Gen 9,
#       learned at level 33. "3L1" = Gen 3, learned at level 1.
#   M = TM or HM. Example: "9M" = Gen 9 TM.
#   E = egg move (bred). Example: "7E" = Gen 7 egg move.
#   T = move tutor. Example: "7T" = Gen 7 tutor.
#   S = event-only move. Example: "5S3" = Gen 5, event number 3.
#   V = Virtual Console transfer (Gen 7/8 only, codes "7V" and "8V").
#   D and R are rare codes in the file (D 702, R 64). They carry no
#   level or TM info, so they are returned as
#   {"method": "other", ...} with the raw code kept, so nothing is
#   lost and nothing is guessed. Counts in the file: L 70,343,
#   M 175,554, E 16,148, T 38,477, S 5,404, V 15,149, D 702, R 64.
#
# How to use it:
#   var learnsets = LearnsetResolver.new()
#   learnsets.load_from("res://data/learnsets_compact.json")
#   print(learnsets.can_learn("Bulbasaur", "Solar Beam"))  # true
#   print(learnsets.get_learn_methods("Bulbasaur", "Tackle"))
#   print(learnsets.moves_learned_by_level("Bulbasaur", 16))
#   print(learnsets.get_level_up_moves("Bulbasaur", 15, 16))
#
# NOTE: this script extends RefCounted, not Node. That means it can NOT
# be an autoload (Godot only autoloads Nodes). Make one with .new()
# where you need it, usually once in the Battle scene, and pass it to
# whatever needs it. See project_godot_autoloads.txt for details.
#
# Display names: the learnsets file only stores move slugs, such as
# "doubleedge". This script returns display-style names by capitalising
# the first letter ("Doubleedge"). Exact display names with spaces and
# hyphens (like "Double-Edge") live in the move database
# (battle/moves/move_database.json), so map through that if you need
# the exact spelling on screen.

class_name LearnsetResolver
extends RefCounted

## Default place for the learnsets file inside the Godot project.
## The project has no data folder yet — create res://data/ and copy
## learnsets_compact.json there, or call load_from() with your own path.
const DEFAULT_PATH := "res://data/learnsets_compact.json"

## Forme words stuck on the end of a species slug. When a slug is not
## in the file, these are stripped one at a time and the base species
## is tried instead. Example: "giratinaorigin" -> "giratina".
## Exact keys in the file always win first, so "mrmimegalar" and
## "farfetchdgalar" (which DO have their own learnsets) are never
## wrongly reduced to "mrmime" or "farfetchd".
const FORME_SUFFIXES: Array[String] = [
	"altered", "origin", "sky", "attack", "defense", "speed",
	"land", "therian", "incarnate", "normal", "plant",
	"hangry", "amped", "lowkey", "solo", "busted", "disguised",
	"school", "complete", "hero", "roaming", "dusk", "midday",
	"midnight", "galar", "alola", "hisui", "paldea",
	"mega", "megax", "megay", "gmax", "eternamax",
	"dawnwings", "duskmane", "ultra", "totem", "stella", "terastal",
	"original", "hoenn", "sinnoh", "unova", "kalos", "partner",
	"cosplay", "rockstar", "belle", "popstar", "phd", "libre",
	"10", "50",
]

## More forme words, consulted ONLY by the second-chance pass
## (_resolve_key_extended), which runs when the exact key and the
## original suffix pass above both fail — so adding a word here can
## never change a lookup that already worked. Each word is here
## because a named species needs it (defect S1, Kanto trainer
## completeness prep, 2026-11-24): these 24 forme species have no
## learnset entry of their own in the held Showdown data — their
## learnset is recorded only under the base species, which IS the
## sourced record for the forme (formes whose learnsets genuinely
## differ, like indeedeef or urshifurapidstrike, carry their own
## entries in the file and still win by the exact-key rule):
##   shield        aegislashshield -> aegislash
##   male          basculegionmale, frillishmale, indeedeemale,
##                 jellicentmale, meowsticmale, oinkolognemale,
##                 pyroarmale -> base species
##   redstriped    basculinredstriped -> basculin
##   standard      darmanitanstandard -> darmanitan
##   twosegment    dudunsparcetwosegment -> dudunsparce
##   ice           eiscueice -> eiscue
##   average       gourgeistaverage, pumpkabooaverage -> base
##   ordinary      keldeoordinary -> keldeo
##   familyoffour  mausholdfamilyoffour -> maushold
##   aria          meloettaaria -> meloetta
##   fullbelly     morpekofullbelly -> morpeko
##   baile         oricoriobaile -> oricorio
##   zero          palafinzero -> palafin
##   greenplumage  squawkabillygreenplumage -> squawkabilly
##   curly         tatsugiricurly -> tatsugiri
##   singlestrike  urshifusinglestrike -> urshifu
##   redmeteor     miniorredmeteor -> minior
const FORME_SUFFIXES_EXTENDED: Array[String] = [
	"shield", "male", "redstriped", "standard", "twosegment",
	"ice", "average", "ordinary", "familyoffour", "aria",
	"fullbelly", "baile", "zero", "greenplumage", "curly",
	"singlestrike", "redmeteor",
]

## Species slug -> {"learnset": {move_slug: [codes]}}.
var _learnsets: Dictionary = {}
## True after a file has loaded successfully.
var data_loaded: bool = false


func _init() -> void:
	# Try the default path. If the file is not there yet, this just
	# leaves the resolver empty — call load_from() with the real path.
	load_from(DEFAULT_PATH)


## Load a learnsets file. Returns true if it loaded.
## A failed load leaves whatever was already loaded untouched.
func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	if not data.has("learnsets"):
		return false
	var learnsets: Variant = data["learnsets"]
	if not (learnsets is Dictionary):
		return false
	_learnsets = learnsets
	data_loaded = true
	return true


## True when a learnsets file is loaded.
func is_loaded() -> bool:
	return data_loaded


## How many species entries are in the loaded file (1,289 in the
## shipped file, including the 56 event-only forms with no learnset).
func species_count() -> int:
	return _learnsets.size()


## The raw learnset for a species: {move_slug: ["3L1", "3M", ...]}.
## Returns {} when the species is unknown.
func get_learnset(species: String) -> Dictionary:
	var key: String = _resolve_key(_normalize_species(species))
	if key.is_empty():
		return {}
	var entry: Variant = _learnsets.get(key, {})
	if not (entry is Dictionary):
		return {}
	var learnset: Variant = (entry as Dictionary).get("learnset", {})
	if not (learnset is Dictionary):
		return {}
	return (learnset as Dictionary).duplicate(true)


## Can this species learn this move by any method? Move may be a
## display name ("Thunderbolt") or a slug ("thunderbolt").
func can_learn(species: String, move: String) -> bool:
	var learnset: Dictionary = get_learnset(species)
	if learnset.is_empty():
		return false
	return learnset.has(_normalize_move(move))


## How a species can learn a move, as readable Dictionaries, one per
## raw code, in file order. Examples:
##   "9L33" -> {"method": "level", "level": 33, "gen": 9}
##   "9M"   -> {"method": "tm", "gen": 9}
##   "7E"   -> {"method": "egg", "gen": 7}
##   "7T"   -> {"method": "tutor", "gen": 7}
##   "5S3"  -> {"method": "event", "gen": 5}
##   "7V"   -> {"method": "virtual_console", "gen": 7}
## Returns [] when the species or the move is unknown.
func get_learn_methods(species: String, move: String) -> Array:
	var learnset: Dictionary = get_learnset(species)
	if learnset.is_empty():
		return []
	var codes: Variant = learnset.get(_normalize_move(move), [])
	if not (codes is Array):
		return []
	var out: Array = []
	for code in codes:
		out.append(_parse_method_code(str(code)))
	return out


## Every move the species learns by level-up at or below the given
## level, as display-style names, newest first (highest level first,
## then name order for ties). The level used for each move is its
## newest generation's level-up level (Gen 9 first when present).
func moves_learned_by_level(species: String, level: int) -> Array:
	var learnset: Dictionary = get_learnset(species)
	if learnset.is_empty():
		return []
	var found: Array = []
	for move_slug in learnset.keys():
		var at_level: int = _newest_level_up_level(learnset, str(move_slug))
		if at_level >= 0 and at_level <= level:
			found.append({"move": _display_name(str(move_slug)), "level": at_level})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["level"]) != int(b["level"]):
			return int(a["level"]) > int(b["level"])
		return str(a["move"]) < str(b["move"])
	)
	var names: Array = []
	for entry in found:
		names.append(entry["move"])
	return names


## Moves learned while levelling from from_level up to to_level.
## Each entry is {"move": "Thunderbolt", "level": 16}, in the order
## they are learned (lowest level first). If more than 4 moves would
## be learned, this function still returns all of them — the caller
## picks which ones to keep. Nothing is deleted here.
func get_level_up_moves(species: String, from_level: int, to_level: int) -> Array:
	var learnset: Dictionary = get_learnset(species)
	if learnset.is_empty():
		return []
	var found: Array = []
	for move_slug in learnset.keys():
		var at_level: int = _newest_level_up_level(learnset, str(move_slug))
		if at_level > from_level and at_level <= to_level:
			found.append({"move": _display_name(str(move_slug)), "level": at_level})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["level"]) != int(b["level"]):
			return int(a["level"]) < int(b["level"])
		return str(a["move"]) < str(b["move"])
	)
	return found


## Every move the species can learn by any method, as display-style
## names, in alphabetical order.
func get_all_moves(species: String) -> Array:
	var learnset: Dictionary = get_learnset(species)
	if learnset.is_empty():
		return []
	var names: Array = []
	for move_slug in learnset.keys():
		names.append(_display_name(str(move_slug)))
	names.sort()
	return names


## ------------------------------------------------------------------
## Helpers
## ------------------------------------------------------------------

## Turn a species name into the file's slug style.
## "Bulbasaur" -> "bulbasaur", "Farfetch'd" -> "farfetchd",
## "Mr. Mime" -> "mrmime", "Nidoran♀" -> "nidoranf",
## "Nidoran♂" -> "nidoranm", "Giratina-Altered" -> "giratinaaltered",
## "Mime Jr." -> "mimejr", "Ho-Oh" -> "hooh", "Flabébé" -> "flabebe".
static func _normalize_species(text: String) -> String:
	return _normalize(text)


## Turn a move name into the file's slug style.
## "Thunderbolt" -> "thunderbolt", "Solar Beam" -> "solarbeam",
## "Double-Edge" -> "doubleedge", "Will-O-Wisp" -> "willowisp".
static func _normalize_move(text: String) -> String:
	return _normalize(text)


static func _normalize(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	# Gender signs first: they carry meaning, so turn them into
	# letters before the cleanup below removes them.
	out = out.replace("♀", "f").replace("♂", "m")
	# Common accented letters, so "Flabébé" still matches.
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e")
	out = out.replace("á", "a").replace("à", "a").replace("â", "a")
	out = out.replace("í", "i").replace("ó", "o").replace("ú", "u")
	out = out.replace("ü", "u").replace("ñ", "n").replace("ç", "c")
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9"):
			clean += ch
	return clean


## Find the file key for a normalised slug. Exact keys win. If the
## exact slug has no learnset (the 56 event-only forms) or is missing
## entirely, forme suffixes are stripped and the base species is
## tried. Returns "" when nothing matches.
func _resolve_key(slug: String) -> String:
	if slug.is_empty():
		return ""
	if _has_learnset(slug):
		return slug
	for suffix in FORME_SUFFIXES:
		if slug.ends_with(suffix) and slug.length() > suffix.length():
			var base: String = slug.substr(0, slug.length() - suffix.length())
			if _has_learnset(base):
				return base
	return _resolve_key_extended(slug)


## Second-chance resolution. Reached only when the exact key and
## the original suffix pass both failed, so it cannot change any
## lookup that already worked. It strips forme suffixes (the
## original list plus FORME_SUFFIXES_EXTENDED) repeatedly, in every
## combination, and returns the LONGEST reachable slug that has a
## learnset — the most specific sourced record for the forme.
## Returns "" when no reachable slug has a learnset.
func _resolve_key_extended(slug: String) -> String:
	var all_suffixes: Array = []
	all_suffixes.append_array(FORME_SUFFIXES)
	all_suffixes.append_array(FORME_SUFFIXES_EXTENDED)
	var seen: Dictionary = {slug: true}
	var frontier: Array[String] = [slug]
	var candidates: Array[String] = []
	while not frontier.is_empty():
		var next_frontier: Array[String] = []
		for cand in frontier:
			for suffix_v in all_suffixes:
				var suffix: String = str(suffix_v)
				if cand.ends_with(suffix) and cand.length() > suffix.length():
					var base: String = cand.substr(0, cand.length() - suffix.length())
					if not seen.has(base):
						seen[base] = true
						candidates.append(base)
						next_frontier.append(base)
		frontier = next_frontier
	candidates.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for cand2 in candidates:
		if _has_learnset(cand2):
			return cand2
	return ""


func _has_learnset(slug: String) -> bool:
	if not _learnsets.has(slug):
		return false
	var entry: Variant = _learnsets[slug]
	if not (entry is Dictionary):
		return false
	return (entry as Dictionary).has("learnset")


## Turn one raw method code into a readable Dictionary.
## See the header for the full list of codes.
func _parse_method_code(code: String) -> Dictionary:
	if code.length() < 2:
		return {"method": "other", "code": code, "gen": 0}
	var gen_text: String = code.substr(0, 1)
	var gen: int = int(gen_text) if gen_text.is_valid_int() else 0
	var letter: String = code.substr(1, 1)
	var rest: String = code.substr(2)
	match letter:
		"L":
			var level: int = int(rest) if rest.is_valid_int() else 0
			return {"method": "level", "level": level, "gen": gen}
		"M":
			return {"method": "tm", "gen": gen}
		"E":
			return {"method": "egg", "gen": gen}
		"T":
			return {"method": "tutor", "gen": gen}
		"S":
			return {"method": "event", "gen": gen}
		"V":
			return {"method": "virtual_console", "gen": gen}
		_:
			return {"method": "other", "code": code, "gen": gen}


## The level at which a move is learned by level-up, using the newest
## generation's level-up code (Gen 9 first when present). Returns -1
## when the move is never learned by level-up.
func _newest_level_up_level(learnset: Dictionary, move_slug: String) -> int:
	var codes: Variant = learnset.get(move_slug, [])
	if not (codes is Array):
		return -1
	var best_gen: int = -1
	var best_level: int = -1
	for raw_code in codes:
		var code: String = str(raw_code)
		if code.length() < 3:
			continue
		if code.substr(1, 1) != "L":
			continue
		var gen_text: String = code.substr(0, 1)
		if not gen_text.is_valid_int():
			continue
		var gen: int = int(gen_text)
		var level_text: String = code.substr(2)
		if not level_text.is_valid_int():
			continue
		var level: int = int(level_text)
		if gen > best_gen or (gen == best_gen and level > best_level):
			best_gen = gen
			best_level = level
	return best_level


## "thunderbolt" -> "Thunderbolt". The file only stores slugs, so
## this capitalises the first letter. Exact display names with
## spaces and hyphens live in the move database.
func _display_name(slug: String) -> String:
	if slug.is_empty():
		return ""
	return slug.substr(0, 1).to_upper() + slug.substr(1)
