# ShinySpriteResolver — sprite URLs for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# It reads the shiny sprite index (shiny_sprites_index.json) and hands
# back the web address of a Pokemon's picture — normal or shiny, front
# or back. The game can then load that picture from the web. It never
# downloads pictures itself and never guesses a web address.
#
# How the index file is built (read this before changing the code):
#   The file has a top-level "rows" list (1,422 rows = 1,025 base
#   species + 397 forms) and a top-level "patterns" Dictionary.
#   There are NO flat URL fields on a row. A row has these keys:
#     showdown_id, name, num, base_species, forme, is_form,
#     is_cosmetic_forme, canon_base, canon_note,
#     num_inherited_from_base_species, pokeapi_id, pokeapi_name,
#     pokeapi_note, sprite_slug, sprite_slug_source, sprites.
#   The URLs live in row["sprites"]: a list of Dictionaries, each with
#   these exact keys: source, pattern, url, file_name, shiny, view,
#   animated, verified_http_200, verification.
#   To find a picture, match source + pattern + shiny + view:
#     source "showdown", pattern "ani"            = normal front, animated
#     source "showdown", pattern "ani-back"       = normal back, animated
#     source "showdown", pattern "ani-shiny"      = shiny front, animated
#     source "showdown", pattern "ani-back-shiny" = shiny back, animated
#     source "pokeapi",  pattern "front"          = normal front, still PNG
#     source "pokeapi",  pattern "back"           = normal back, still PNG
#     source "pokeapi",  pattern "shiny-front"    = shiny front, still PNG
#     source "pokeapi",  pattern "shiny-back"     = shiny back, still PNG
#     source "pokeapi",  pattern "official-artwork" = big still picture
#   "verified_http_200" tells you if the address was checked live:
#   true = it worked, false = it is a known dead link (never use it),
#   null = not checked one by one. This script prefers checked-good
#   links, then unchecked ones, and never returns a known dead link.
#
# The "patterns" Dictionary holds URL templates, one Dictionary per
# pattern with keys "template", "status" and "note". Showdown templates
# use a {sprite_slug} placeholder, PokeAPI templates use an {id}
# placeholder. This script only ever builds a URL from a pattern when
# the row has no entry for that picture at all, the template is a plain
# string with one of those placeholders, and the pattern is not the
# known-dead one. It NEVER uses this pattern:
#   showdown_ani_shiny_back ("ani-shiny-back") — status NOT_FOUND_404.
#   The working shiny-back path is "ani-back-shiny".
#
# The 14 species with no animated Showdown sprite at any tested
# pattern (from the index file's "known_missing" note):
#   ironboulder, ironbundle, ironcrown, ironhands, ironjugulis,
#   ironleaves, ironmoth, ironthorns, irontreads, ironvaliant,
#   miraidon, ogerpon, pecharunt, terapagos.
#   Their Showdown animated links are all known dead, so the animated
#   INTEGRATION BUILD 2 (2026-11-23): 35 of those 40 form rows now
#   carry a LOCAL animated strip from the Open-Source EBDX
#   Renovation Project (Eevee Expo resource 1831), bound as
#   "ebdx1831" sprite entries whose url is a res:// path
#   (art/battle_fronts_ebdx/). The animated getters return that
#   path when no verified Showdown animated sprite exists (see
#   _local_animated_url); PUWSpriteLoader loads res:// paths
#   directly and slices strips into height-sized frames, looped.
#   Front view only — no EBDX backs were staged, so back requests
#   for those rows stay honestly empty. The 5 rows with no strip
#   (rockruffdusk, ribombeetotem, pokestarufopropu2,
#   ramnarokradiant, venomiconepilogue) remain missing.
#   getters return "" for them. Their PokeAPI still pictures DO exist
#   (front, back, shiny front and back were checked for all 1,025 base
#   species), so get_sprite_url() falls back to the PokeAPI picture
#   for them and never returns "". One exception: miraidon DOES have a
#   checked-good Gen 5 style shiny front link (gen5ani-shiny), so the
#   shiny front getter returns that one for miraidon.
#   40 form rows also have no working front sprite file at any tested
#   slug (including all 7 Ogerpon forms and both Terapagos forms).
#   Their rows still list the built-up candidate addresses with
#   verified_http_200 = false — this script never returns those.
#   2026-11-23 fix: the front-normal getter used to fall through
#   to the UNCHECKED xyani entry (verified_http_200 = null) for
#   exactly those rows and returned a URL that live-checks 404.
#   The xyani/gen5ani fallbacks now accept verified entries
#   only, so the animated getters honestly return "" there, as
#   this header always claimed and the back/shiny getters
#   already did.
#
# How to use it:
#   var sprites = ShinySpriteResolver.new()
#   sprites.load_from("res://data/shiny_sprites_index.json")
#   var url = sprites.get_sprite_url("Pikachu", true)  # shiny front
#   var back = sprites.get_sprite_url("Pikachu", false, true)  # normal back
#   if sprites.has_shiny_sprite("Charizard"):
#       print(sprites.get_shiny_sprite_url("Charizard"))
#
# NOTE: this script extends RefCounted, not Node. That means it can NOT
# be an autoload (Godot only autoloads Nodes). Make one with .new()
# where you need it, usually once in the Battle scene, and pass it to
# whatever needs it. See project_godot_autoloads.txt for details.

class_name ShinySpriteResolver
extends RefCounted

## Default place for the sprite index inside the Godot project.
## The project has no data folder yet — create res://data/ and copy
## shiny_sprites_index.json there, or call load_from() with your own path.
const DEFAULT_PATH := "res://data/shiny_sprites_index.json"

## The 14 base species with no animated Showdown sprite at any tested
## pattern. Listed here so the fallback in get_sprite_url() is easy to
## follow. Copied from the index file's "known_missing" note.
const NO_ANIMATED_SHOWDOWN_SPRITE: Array[String] = [
	"ironboulder", "ironbundle", "ironcrown", "ironhands",
	"ironjugulis", "ironleaves", "ironmoth", "ironthorns",
	"irontreads", "ironvaliant", "miraidon", "ogerpon",
	"pecharunt", "terapagos",
]

## Forme words stuck on the end of a species name, tried when the
## plain name is not in the index. Example: "Giratina-Altered"
## falls back to "giratina", "Deoxys-Normal" falls back to "deoxys".
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

## All index rows, in file order.
var _rows: Array = []
## URL templates from the file's "patterns" Dictionary.
var _patterns: Dictionary = {}
## showdown_id slug -> row Dictionary.
var _by_showdown_id: Dictionary = {}
## sprite_slug (hyphenated, e.g. "charizard-megax") -> row Dictionary.
var _by_sprite_slug: Dictionary = {}
## True after a file has loaded successfully.
var data_loaded: bool = false


func _init() -> void:
	# Try the default path. If the file is not there yet, this just
	# leaves the resolver empty — call load_from() with the real path.
	load_from(DEFAULT_PATH)


## Load a sprite index file. Returns true if it loaded.
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
	if not data.has("rows"):
		return false
	var rows: Variant = data["rows"]
	if not (rows is Array):
		return false
	_rows = rows
	_patterns = data.get("patterns", {})
	_by_showdown_id.clear()
	_by_sprite_slug.clear()
	for row in _rows:
		if not (row is Dictionary):
			continue
		var row_dict: Dictionary = row
		var showdown_id: String = str(row_dict.get("showdown_id", "")).to_lower()
		if not showdown_id.is_empty():
			_by_showdown_id[showdown_id] = row_dict
		var sprite_slug: String = str(row_dict.get("sprite_slug", "")).to_lower()
		if not sprite_slug.is_empty():
			_by_sprite_slug[sprite_slug] = row_dict
	data_loaded = true
	return true


## True when a sprite index file is loaded.
func is_loaded() -> bool:
	return data_loaded


## How many rows are in the loaded file (1,422 in the shipped file).
func row_count() -> int:
	return _rows.size()


## The shiny animated sprite address for a species (front, or back
## when is_back is true). Returns "" when there is no shiny animated
## sprite — that includes the 14 species with no animated Showdown
## sprite at all. Never returns a known dead link.
func get_shiny_sprite_url(species: String, is_back: bool = false) -> String:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return ""
	var view: String = "back" if is_back else "front"
	var main_pattern: String = "ani-back-shiny" if is_back else "ani-shiny"
	# Binding build 5 (2026-11-24): a verified LOCAL animated
	# file shipped in the project wins over every streamed
	# address — the game must animate from its own files, not
	# from the network. The streamed chain below is unchanged
	# as the fallback for rows with no local file.
	var local_url: String = _local_animated_url(row, true, is_back)
	if not local_url.is_empty():
		return local_url
	var url: String = _sprite_url(row, "showdown", main_pattern, true, view)
	if not url.is_empty():
		return url
	# Older style animated shiny pictures, front only. These were
	# checked live in the index file too.
	if not is_back:
		url = _sprite_url(row, "showdown", "xyani-shiny", true, "front")
		if not url.is_empty():
			return url
		url = _sprite_url(row, "showdown", "gen5ani-shiny", true, "front")
		if not url.is_empty():
			return url
	# Local animated strips (integration build 2, 2026-11-23):
	# the EBDX 1831 strips bound as "ebdx1831" entries — a
	# res:// path to a horizontal strip file in the project,
	# sliced into height-sized frames and looped by the loader.
	url = _local_animated_url(row, true, is_back)
	if not url.is_empty():
		return url
	# Last resort: build from a verified pattern, but only when the
	# row has no entry for that picture at all (so the 14 species,
	# whose entries are known dead, are never built up).
	url = _showdown_pattern_url(main_pattern, row)
	if not url.is_empty():
		return url
	return ""


## The normal animated sprite address for a species (front, or back
## when is_back is true). Returns "" when there is no normal animated
## sprite — that includes the 14 species with no animated Showdown
## sprite at all. Never returns a known dead link.
func get_normal_sprite_url(species: String, is_back: bool = false) -> String:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return ""
	var view: String = "back" if is_back else "front"
	var main_pattern: String = "ani-back" if is_back else "ani"
	# Binding build 5 (2026-11-24): verified local first, as
	# in get_shiny_sprite_url.
	var local_url: String = _local_animated_url(row, false, is_back)
	if not local_url.is_empty():
		return local_url
	var url: String = _sprite_url(row, "showdown", main_pattern, false, view)
	if not url.is_empty():
		return url
	# Older style animated pictures, front only. FIXED
	# 2026-11-23: these two patterns (xyani, gen5ani) were never
	# individually HEAD-checked in the index -- every entry for
	# them carries verified_http_200 = null -- and a live sample
	# showed the xyani URLs for exactly the rows that reach this
	# fallback (the 54 with no verified "ani" front) return 404.
	# Only a VERIFIED entry may be returned here; where none
	# exists this getter now honestly returns "" (the behaviour
	# the back/shiny getters already had), so callers fall back
	# to the indexed still picture instead of a dead GIF URL.
	if not is_back:
		url = _sprite_url_verified_only(row, "showdown", "xyani", false, "front")
		if not url.is_empty():
			return url
		url = _sprite_url_verified_only(row, "showdown", "gen5ani", false, "front")
		if not url.is_empty():
			return url
	# Local animated strips (integration build 2, 2026-11-23):
	# see get_shiny_sprite_url.
	url = _local_animated_url(row, false, is_back)
	if not url.is_empty():
		return url
	url = _showdown_pattern_url(main_pattern, row)
	if not url.is_empty():
		return url
	return ""


## The best picture address for a species: the shiny one when shiny
## is true and one exists, otherwise the normal one. This is the
## fallback function — it never returns "" for a species the index
## knows about. Order for a shiny request:
##   shiny animated -> PokeAPI shiny still -> normal PokeAPI still
##   -> normal animated -> official artwork.
## For the 14 species with no animated Showdown sprite, the answer is
## a PokeAPI still picture. Returns "" only when the species is not
## in the index at all.
func get_sprite_url(species: String, shiny: bool, is_back: bool = false) -> String:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return ""
	if shiny:
		var shiny_url: String = get_shiny_sprite_url(species, is_back)
		if not shiny_url.is_empty():
			return shiny_url
		var pokeapi_shiny: String = _pokeapi_url(row, true, is_back)
		if not pokeapi_shiny.is_empty():
			return pokeapi_shiny
		# The named fallback for the 14 species: the normal PokeAPI
		# still picture, when the row has one.
		var pokeapi_normal: String = _pokeapi_url(row, false, is_back)
		if not pokeapi_normal.is_empty():
			return pokeapi_normal
		var normal_url: String = get_normal_sprite_url(species, is_back)
		if not normal_url.is_empty():
			return normal_url
		return _official_artwork_url(row)
	var normal_url2: String = get_normal_sprite_url(species, is_back)
	if not normal_url2.is_empty():
		return normal_url2
	var pokeapi_normal2: String = _pokeapi_url(row, false, is_back)
	if not pokeapi_normal2.is_empty():
		return pokeapi_normal2
	return _official_artwork_url(row)


## True when the species has a shiny animated sprite (front or back).
## When this was written, 13 of the 14 species with no animated
## Showdown sprite answered false here (their PokeAPI shiny stills
## are stills, not animated sprites; miraidon was the exception,
## with a checked-good Gen 5 style shiny front link). Binding
## build 3 (stage 9) bound local EBDX animated strips for all 14,
## so they now answer true — served from the local strips, never
## from the checked-dead Showdown links. Use get_sprite_url() to
## get a still picture when there is no animated one.
func has_shiny_sprite(species: String) -> bool:
	if not get_shiny_sprite_url(species, false).is_empty():
		return true
	return not get_shiny_sprite_url(species, true).is_empty()


## The index row identity for a species name, resolved through
## the same row-finding as every getter: {} when nothing
## matches, otherwise {showdown_id, sprite_slug, name, is_form}.
## Added 2026-11-23 for the shared battle/cutscene sprite
## binding, which reports WHICH row a name resolved to.
func row_info(species: String) -> Dictionary:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return {}
	return {
		"showdown_id": str(row.get("showdown_id", "")),
		"sprite_slug": str(row.get("sprite_slug", "")),
		"name": str(row.get("name", "")),
		"is_form": bool(row.get("is_form", false)),
	}


## The indexed PokeAPI still picture for a species (front or
## back, normal or shiny), or "" when the row carries none --
## form rows have no PokeAPI entries at all. This is the
## verified-static fallback the battle/cutscene binding uses
## where no verified animated sprite exists. (PokeAPI "front"
## and "shiny-front" entries are pattern-indexed in the index;
## "back" and "shiny-back" entries are HEAD-verified -- see
## the index's patterns note. No URL is returned for a known
## dead entry.)
func get_still_sprite_url(species: String, shiny: bool, is_back: bool = false) -> String:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return ""
	return _pokeapi_url(row, shiny, is_back)


## The big official artwork still picture for a species, or "".
func get_official_artwork_url(species: String) -> String:
	var row: Dictionary = _find_row(species)
	if row.is_empty():
		return ""
	return _official_artwork_url(row)


## All four animated sprite addresses for a species. Missing ones are
## "". These are the animated addresses only — use get_sprite_url()
## when you want the still-picture fallback included.
func get_sprite_urls(species: String) -> Dictionary:
	return {
		"front": get_normal_sprite_url(species, false),
		"front_shiny": get_shiny_sprite_url(species, false),
		"back": get_normal_sprite_url(species, true),
		"back_shiny": get_shiny_sprite_url(species, true),
	}


## ------------------------------------------------------------------
## Helpers
## ------------------------------------------------------------------

## Find the index row for a species. The name may be a display name
## ("Bulbasaur", "Giratina-Altered", "Mr. Mime"), a Showdown id
## ("bulbasaur", "giratinaorigin") or a sprite slug
## ("charizard-megax"). Returns {} when nothing matches.
func _find_row(species: String) -> Dictionary:
	var plain: String = _normalize(species)
	if not plain.is_empty():
		if _by_showdown_id.has(plain):
			return _by_showdown_id[plain]
		if _by_sprite_slug.has(plain):
			return _by_sprite_slug[plain]
	var hyphen: String = _hyphen_slug(species)
	if not hyphen.is_empty():
		if _by_sprite_slug.has(hyphen):
			return _by_sprite_slug[hyphen]
		if _by_showdown_id.has(hyphen):
			return _by_showdown_id[hyphen]
		# Try the base form: drop the last hyphen part at a time.
		# "giratina-origin" -> "giratina", "pikachu-alola" -> "pikachu".
		var parts: PackedStringArray = hyphen.split("-")
		while parts.size() > 1:
			parts.remove_at(parts.size() - 1)
			var base_hyphen: String = "-".join(parts)
			if _by_sprite_slug.has(base_hyphen):
				return _by_sprite_slug[base_hyphen]
			if _by_showdown_id.has(base_hyphen):
				return _by_showdown_id[base_hyphen]
	# Try stripping a forme word stuck on the end of the plain slug.
	# "giratinaaltered" -> "giratina", "deoxysnormal" -> "deoxys".
	for suffix in FORME_SUFFIXES:
		if plain.ends_with(suffix) and plain.length() > suffix.length():
			var base: String = plain.substr(0, plain.length() - suffix.length())
			if _by_showdown_id.has(base):
				return _by_showdown_id[base]
			if _by_sprite_slug.has(base):
				return _by_sprite_slug[base]
	return {}


## One picture address from a row's "sprites" list, matched by source,
## pattern, shiny flag and view. Prefers links that were checked live
## and worked (verified_http_200 = true), then unchecked ones
## (verified_http_200 = null). Never returns a known dead link
## (verified_http_200 = false). Returns "" when there is no match.
func _sprite_url(row: Dictionary, source: String, pattern: String, shiny: bool, view: String) -> String:
	var entries: Variant = row.get("sprites", [])
	if not (entries is Array):
		return ""
	var unchecked: String = ""
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		if str(item.get("source", "")) != source:
			continue
		if str(item.get("pattern", "")) != pattern:
			continue
		if bool(item.get("shiny", false)) != shiny:
			continue
		if str(item.get("view", "")) != view:
			continue
		var url: String = str(item.get("url", ""))
		if url.is_empty():
			continue
		var verified: Variant = item.get("verified_http_200", null)
		if verified == true:
			return url
		if verified == null and unchecked.is_empty():
			unchecked = url
		# verified == false means a known dead link: skip it.
	return unchecked


## A LOCAL animated sprite path from the row's verified-local
## entries, or "" when the row carries none. Entries are
## matched on pattern + shiny + view like _sprite_url, but the
## address is a res:// path shipped in the project, not a web
## URL: the entry must carry verified_local_file = true and
## the file must exist. Two local sources exist: the EBDX 1831
## strips (source "ebdx1831", art/battle_fronts_ebdx/ +
## art/battle_backs_ebdx/, sliced into height-sized frames by
## the loader) and the held Showdown GIF pool (source
## "showdown_local", art/battle_gifs/, decoded by the loader's
## GIF path). Integration build 2 (2026-11-23) bound front
## strips only; binding build 5 (2026-11-24) completed all
## four views, so back requests resolve here too wherever a
## local file was bound.
func _local_animated_url(row: Dictionary, shiny: bool, is_back: bool) -> String:
	var entries: Variant = row.get("sprites", [])
	if not (entries is Array):
		return ""
	var view: String = "back" if is_back else "front"
	var pattern: String = ""
	if shiny and is_back:
		pattern = "ani-back-shiny"
	elif shiny:
		pattern = "ani-shiny"
	elif is_back:
		pattern = "ani-back"
	else:
		pattern = "ani"
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		if str(item.get("pattern", "")) != pattern:
			continue
		if bool(item.get("shiny", false)) != shiny:
			continue
		if str(item.get("view", "")) != view:
			continue
		if not bool(item.get("animated", false)):
			continue
		if not bool(item.get("verified_local_file", false)):
			continue
		var url: String = str(item.get("url", ""))
		if url.is_empty():
			continue
		if not url.begins_with("res://"):
			continue
		if not FileAccess.file_exists(url):
			continue
		return url
	return ""


## A PokeAPI still picture address from the row, or "" when the row
## has none. Forms have no pokeapi_id, so they have no PokeAPI
## picture. Builds from the file's PokeAPI patterns only when the row
## has no entry for that picture at all.
func _pokeapi_url(row: Dictionary, shiny: bool, is_back: bool) -> String:
	var view: String = "back" if is_back else "front"
	var pattern: String = ""
	var pattern_key: String = ""
	if shiny and is_back:
		pattern = "shiny-back"
		pattern_key = "pokeapi_shiny_back_png"
	elif shiny:
		pattern = "shiny-front"
		pattern_key = "pokeapi_shiny_front_png"
	elif is_back:
		pattern = "back"
		pattern_key = "pokeapi_back_png"
	else:
		pattern = "front"
		pattern_key = "pokeapi_front_png"
	var url: String = _sprite_url(row, "pokeapi", pattern, shiny, view)
	if not url.is_empty():
		return url
	return _pokeapi_pattern_url(pattern_key, row)


## The big official artwork still picture, or "" when the row has none.
func _official_artwork_url(row: Dictionary) -> String:
	var url: String = _sprite_url(row, "pokeapi", "official-artwork", false, "front")
	if not url.is_empty():
		return url
	return _pokeapi_pattern_url("pokeapi_official_artwork", row)


## Like _sprite_url, but ONLY a live-verified entry
## (verified_http_200 = true) counts: unchecked entries
## (verified_http_200 = null) are never returned. Used for the
## xyani / gen5ani fallbacks, whose index entries were never
## individually checked (see get_normal_sprite_url).
func _sprite_url_verified_only(row: Dictionary, source: String, pattern: String, shiny: bool, view: String) -> String:
	var entries: Variant = row.get("sprites", [])
	if not (entries is Array):
		return ""
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		if str(item.get("source", "")) != source:
			continue
		if str(item.get("pattern", "")) != pattern:
			continue
		if bool(item.get("shiny", false)) != shiny:
			continue
		if str(item.get("view", "")) != view:
			continue
		var verified: Variant = item.get("verified_http_200", null)
		if verified == true:
			var url: String = str(item.get("url", ""))
			if not url.is_empty():
				return url
	return ""


## Build a Showdown animated URL from the file's "patterns" — only
## when the row has no entry for that pattern at all, the pattern is
## a plain string template with a {sprite_slug} placeholder, and the
## pattern is not the known-dead "ani-shiny-back" one. Otherwise "".
## No URL pattern is guessed here: every template comes from the file.
func _showdown_pattern_url(pattern_key: String, row: Dictionary) -> String:
	if pattern_key == "showdown_ani_shiny_back":
		return ""
	var entries: Variant = row.get("sprites", [])
	if entries is Array:
		for entry in entries:
			if entry is Dictionary and str(entry.get("pattern", "")) == pattern_key:
				return ""
	var template: String = _pattern_template(pattern_key)
	if template.is_empty():
		return ""
	if "{sprite_slug}" not in template:
		return ""
	var slug: String = str(row.get("sprite_slug", ""))
	if slug.is_empty():
		return ""
	return template.replace("{sprite_slug}", slug)


## Build a PokeAPI still URL from the file's "patterns" — only when
## the row has a pokeapi_id and the template is a plain string with
## an {id} placeholder. Otherwise "".
func _pokeapi_pattern_url(pattern_key: String, row: Dictionary) -> String:
	var template: String = _pattern_template(pattern_key)
	if template.is_empty():
		return ""
	if "{id}" not in template:
		return ""
	var pokeapi_id: Variant = row.get("pokeapi_id", null)
	if pokeapi_id == null:
		return ""
	var id_num: int = int(pokeapi_id)
	if id_num <= 0:
		return ""
	return template.replace("{id}", str(id_num))


## The "template" string for one pattern key, or "" when the pattern
## is missing, not a Dictionary, has no string template, or is marked
## NOT_FOUND_404 in the file.
func _pattern_template(pattern_key: String) -> String:
	if not _patterns.has(pattern_key):
		return ""
	var entry: Variant = _patterns[pattern_key]
	if not (entry is Dictionary):
		return ""
	var entry_dict: Dictionary = entry
	if str(entry_dict.get("status", "")) == "NOT_FOUND_404":
		return ""
	var template: Variant = entry_dict.get("template", "")
	if not (template is String):
		return ""
	return template


## Turn a species name into a plain slug: lowercase, gender signs
## become letters, accents dropped, only a-z and 0-9 kept.
## "Farfetch'd" -> "farfetchd", "Mr. Mime" -> "mrmime",
## "Nidoran♀" -> "nidoranf", "Flabébé" -> "flabebe".
static func _normalize(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "f").replace("♂", "m")
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e")
	out = out.replace("á", "a").replace("à", "a").replace("â", "a")
	out = out.replace("í", "i").replace("ó", "o").replace("ú", "u")
	out = out.replace("ü", "u").replace("ñ", "n").replace("ç", "c")
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9"):
			clean += ch
	return clean


## Turn a species name into a hyphenated slug: lowercase, spaces
## become hyphens, apostrophes and periods removed.
## "Giratina-Altered" -> "giratina-altered",
## "Charizard-Mega-X" -> "charizard-mega-x".
static func _hyphen_slug(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "f").replace("♂", "m")
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e")
	out = out.replace("á", "a").replace("à", "a").replace("â", "a")
	out = out.replace("í", "i").replace("ó", "o").replace("ú", "u")
	out = out.replace("ü", "u").replace("ñ", "n").replace("ç", "c")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	out = out.replace("_", "-")
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9") or ch == "-":
			clean += ch
	while "--" in clean:
		clean = clean.replace("--", "-")
	return clean.strip_edges().trim_prefix("-").trim_suffix("-")
