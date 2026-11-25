class_name PUWFollowerSpriteResolver
extends RefCounted
## Follower (overworld) sprite resolution for Pokemon Ultimate World.
##
## What this does, in plain words:
## Given a species (and a form where applicable), it returns the
## best LEGITIMATE follower sprite the project actually indexes,
## plus an honest classification that travels with the URL:
##
##   "animated"    -- a real animated OVERWORLD / follower sprite
##                    is indexed for this species. Since the
##                    2026-11-23 route-2 integration this is the
##                    PMD SpriteCollab community sheets indexed in
##                    res://data/follower_sprites_index.json
##                    (473 community-authored base species, every
##                    Walk/Idle sheet HEAD-verified HTTP 200;
##                    CC BY-NC 4.0, per-species credit in
##                    CREDITS_spritecollab.md). Extraction build
##                    (2026-11-23, Solid Rule): the same index now
##                    also carries 485 CHUNSOFT-credited (game
##                    sprite) species, verified the same way
##                    (Walk/Idle HTTP 200 + AnimData frame counts),
##                    with provenance recorded per row; and the
##                    HGSS overworld index (data/hgss_overworld_
##                    index.json, Veekun pack, local files) adds 7
##                    more species whose SpriteCollab sheets lack
##                    an Idle anim. Integration build 2
##                    (2026-11-23): the EBDX overworld index
##                    (data/ebdx_follower_index.json, Open-Source
##                    EBDX Renovation Project, Eevee Expo resource
##                    1831, local RPG Maker XP charset sheets)
##                    upgrades the last 60 engine-rigged base
##                    species to genuinely animated — base
##                    followers are now 1,025 / 1,025
##                    source-animated, 0 rigged — and binds the
##                    first form followers: 217 of the 397 form
##                    rows (the other 180 stay an honest gap).
##                    Consolidation build (2026-11-23): the
##                    Willow OW pack follower index
##                    (data/willow_follower_index.json, Willow's
##                    "Gmax, Mega and Primal OW Sprites Pack +
##                    Extras", Eevee Expo resource 1475, local
##                    charset sheets) binds 76 more form
##                    followers (27 Gigantamax, 48 Mega / Primal,
##                    Mega Lucario Z) — forms now stand at 293 of
##                    397, the other 104 stay an honest gap (the
##                    index's not_bound_flagged list names the
##                    ambiguous sheets left unbound on purpose).
##                    The same build appended 21 PMD SpriteCollab
##                    rows to the PMD index (richness upgrades for
##                    20 base species plus the gimmighoulroaming
##                    form); the PMD index still loads first, so
##                    those species resolve through PMD.
##   "static-only" -- no animated follower art, but a verified
##                    still picture exists: the PokeAPI front PNG
##                    recorded verbatim in the sprite index.
##                    Every one of the 1,025 PKDX base species
##                    classifies here.
##   "missing"     -- no follower sprite of any kind. The
##                    follower renders NO fake flat stand-in
##                    presented as the Pokemon. All 397 PKDX form
##                    rows classify here (forms have no PokeAPI
##                    PNG entries), and so does every MDX slot.
##
## HARD RULES (standing project rules, enforced by construction):
## - Sprites are INDEXED BY URL and streamed, never
##   bulk-downloaded. This resolver only reads index data and
##   hands back URLs; it downloads nothing.
## - NEVER fabricate a sprite URL: every URL returned is copied
##   verbatim from a sprite entry inside the index data. No URL
##   is ever built from a pattern template here.
## - Battle animated GIFs (Showdown "ani" etc.) are NOT follower
##   animation: they are single-view battle art with no walk
##   cycle and no directions. They are never credited as
##   follower art, which is why fully-animated battle species
##   still classify "static-only" as followers.
## - MDX (Moemon) follower art is MISSING, recorded as such.
##   An MDX follower is never silently dressed in its PKDX
##   counterpart's sprite: any resolve with family "MDX"
##   returns "missing" before any index lookup happens.
##   (Battle behaviour for MDX is unchanged -- that is a
##   different code path, not this resolver.)
##
## Index data read (and ONLY this data):
## - res://data/shiny_sprites_index.json -- the file
##   ShinySpriteResolver reads: 1,422 rows (1,025 base species +
##   397 forms), each row carrying a "sprites" list of
##   {source, pattern, url, shiny, view, animated,
##   verified_http_200} entries. The static follower picture is
##   the entry with source "pokeapi" and pattern "front",
##   copied verbatim. (sprites_index_1025.json carries the same
##   PokeAPI front PNG pattern for the same species; the audit
##   credits the same stills from either file.)
## - res://data/follower_sprites_index.json -- the route-2
##   overworld source (PMD SpriteCollab), same row/sprites
##   shape, loaded by default in load_indexes(). A sprite entry
##   counts as animated follower art only when it is marked for
##   follower use -- entry "context" or "usage" equal to
##   "follower" or "overworld", or a "pattern" beginning with
##   "follower" or "overworld" -- AND its "animated" flag is
##   true AND it is not a known dead link
##   (verified_http_200 == false). The same follower-marking
##   check also runs over the main index, so follower entries
##   added there plug in the same way. Animated results also
##   carry the entry's source id, the row's AnimData.xml URL
##   (frame geometry at runtime), the verified anim names and
##   the partial flag from the follower index row.
##
## Resolution is EXACT-MATCH ONLY: a name resolves to the index
## row it names (by showdown_id or sprite_slug), never to a
## base-species fallback. That matters for forms: "venusaurgmax"
## names the Venusaur-Gmax form row, which has no still PNG, so
## it is "missing" -- it is NOT quietly resolved to base
## Venusaur's still.
##
## Result Dictionary from resolve():
##   {
##     "classification": "animated" | "static-only" | "missing",
##     "url": <verbatim index URL, or "" when missing>,
##     "source": <plain source name, or "" when missing>,
##     "animated": bool,
##     "species": <the species string as passed in>,
##     "showdown_id": <matched index row id, or "">,
##     "is_form": bool,
##     "family": <family as passed in>,
##     "reason": <why, when missing; "" otherwise>,
##   }

const INDEX_PATH: String = "res://data/shiny_sprites_index.json"
const FOLLOWER_INDEX_PATH: String = "res://data/follower_sprites_index.json"
const HGSS_INDEX_PATH: String = "res://data/hgss_overworld_index.json"
const EBDX_INDEX_PATH: String = "res://data/ebdx_follower_index.json"
const WILLOW_INDEX_PATH: String = "res://data/willow_follower_index.json"
const MDX_PATH: String = "res://data/mdx_mapping.json"

const CLASS_ANIMATED: String = "animated"
const CLASS_STATIC: String = "static-only"
const CLASS_MISSING: String = "missing"
## Engine-rigged (route 3, 2026-11-23): no source-animated
## follower art, but the species' indexed still carries a rig
## definition (PUWRigRegistry over data/rig_definitions.json)
## and PUWRigPlayer animates it in the engine. Provenance is
## "engine-rigged" — never passed off as source-animated.
const CLASS_RIGGED: String = "engine-rigged"

const STATIC_SOURCE_NAME: String = "PokeAPI sprites repo front PNG (indexed in shiny_sprites_index.json)"
const ANIMATED_SOURCE_NAME: String = "Indexed animated overworld/follower sprite"

## Parsed index data shared across every resolver instance
## (the main index is ~6.6 MB; parsing it once per follower
## selection would be wasteful). Key: path -> parsed Dictionary.
static var _shared_indexes: Dictionary = {}

var _rows: Array = []
var _by_showdown_id: Dictionary = {}
var _by_sprite_slug: Dictionary = {}
var _follower_rows: Array = []
var _loaded: bool = false
var _rig_registry: PUWRigRegistry = null


## The shared rig registry (parsed once via its own cache).
func rig_registry() -> PUWRigRegistry:
	if _rig_registry == null:
		_rig_registry = PUWRigRegistry.new()
	return _rig_registry


func _init() -> void:
	load_indexes()


## Load (or reload) the index data. Returns true when the main
## sprite index loaded. The optional follower index is loaded
## when present; its absence is normal today, not an error.
func load_indexes() -> bool:
	_loaded = true
	_rows = []
	_by_showdown_id.clear()
	_by_sprite_slug.clear()
	_follower_rows = []
	var main_data: Dictionary = _shared_index(INDEX_PATH)
	if main_data.is_empty():
		return false
	_rows = _index_rows(main_data)
	_index_rows_by_id(_rows, _by_showdown_id, _by_sprite_slug)
	var follower_data: Dictionary = _shared_index(FOLLOWER_INDEX_PATH)
	if not follower_data.is_empty():
		_follower_rows = _index_rows(follower_data)
	# Extraction build (2026-11-23): the HGSS overworld index
	# (Veekun pack, local files) plugs into the same follower
	# row list; its rows carry local res:// frame paths instead
	# of streamed URLs.
	var hgss_data: Dictionary = _shared_index(HGSS_INDEX_PATH)
	if not hgss_data.is_empty():
		for hgss_row_value in _index_rows(hgss_data):
			_follower_rows.append(hgss_row_value)
	# Integration build 2 (2026-11-23): the EBDX overworld
	# index (Open-Source EBDX Renovation Project, Eevee Expo
	# resource 1831, local files) plugs into the same follower
	# row list the same way; its rows carry local res:// sheet
	# paths (RPG Maker XP charsets) instead of streamed URLs.
	var ebdx_data: Dictionary = _shared_index(EBDX_INDEX_PATH)
	if not ebdx_data.is_empty():
		for ebdx_row_value in _index_rows(ebdx_data):
			_follower_rows.append(ebdx_row_value)
	# Consolidation build (2026-11-23): the Willow OW pack
	# follower index (Gmax / Mega / Primal / Z-A Mega form
	# charsets, local files) plugs into the same follower row
	# list the same way.
	var willow_data: Dictionary = _shared_index(WILLOW_INDEX_PATH)
	if not willow_data.is_empty():
		for willow_row_value in _index_rows(willow_data):
			_follower_rows.append(willow_row_value)
	return true


## Load an ADDITIONAL follower/overworld index from an explicit
## path, in the same row/sprites shape. This is the plug-in
## point for a future real overworld sprite source (and how the
## test suite proves the animated path without touching the
## shipped index data).
func load_follower_index_from(path: String) -> bool:
	var data: Dictionary = _shared_index(path)
	if data.is_empty():
		return false
	var rows: Array = _index_rows(data)
	if rows.is_empty():
		return false
	for row_value in rows:
		_follower_rows.append(row_value)
	return true


## True when the main sprite index is loaded.
func is_loaded() -> bool:
	return not _rows.is_empty()


## How many rows the main index carries (1,422 shipped).
func row_count() -> int:
	return _rows.size()


# ----------------------------------------------------------------
# Resolution
# ----------------------------------------------------------------

## Resolve the follower sprite for a species. "species" may be
## a display name ("Mr. Mime"), a hyphen slug ("mr-mime") or a
## Showdown id ("mrmime"); a form may be named either inside
## the species string ("Charizard-Mega-X", "venusaurgmax") or
## via the "form" argument ("gmax", "mega-x"). Family "MDX"
## always resolves missing (see header).
func resolve(species: String, family: String = "PKDX", form: String = "") -> Dictionary:
	if family.strip_edges().to_upper() == "MDX":
		return _missing(species, family, "", false, "mdx_art_resolves_via_mdx_data_layer: MDX-native art is bound in data/mdx_sprites_index.json and served by PUWMDXData; this resolver never borrows counterpart PKDX art for an MDX follower")
	if not is_loaded():
		load_indexes()
	var row: Dictionary = _find_row(species, form)
	if row.is_empty():
		var reason: String = "form_not_in_index" if not form.strip_edges().is_empty() else "species_not_in_index"
		return _missing(species, family, "", false, reason)
	return resolve_row(row, species, family)


## Resolve one index row directly (the row's own identity is
## authoritative -- used by the count sweep so every one of the
## 1,422 rows is classified as itself, never via a name that
## could land on a different row).
func resolve_row(row: Dictionary, species_label: String = "", family: String = "PKDX") -> Dictionary:
	var showdown_id: String = str(row.get("showdown_id", ""))
	var is_form: bool = bool(row.get("is_form", false))
	var label: String = species_label if not species_label.is_empty() else showdown_id
	# (a) Best legitimate ANIMATED follower source, if one is
	# ever indexed for follower use (either index).
	var animated_url: String = _follower_animated_url(row)
	if not animated_url.is_empty():
		var follower_row: Dictionary = _matching_follower_row(row)
		var entry_source: String = _follower_animated_source(row)
		return {
			"classification": CLASS_ANIMATED,
			"url": animated_url,
			"source": entry_source if not entry_source.is_empty() else ANIMATED_SOURCE_NAME,
			"source_id": str(follower_row.get("source_id", "")),
			"animated": true,
			"species": label,
			"showdown_id": showdown_id,
			"is_form": is_form,
			"family": family,
			"reason": "",
			"provenance": "source-animated",
			"animation_status": "source-animated",
			"anim_data_url": str(follower_row.get("anim_data_url", "")),
			"verified_anims": follower_row.get("verified_anims", []),
			"partial": bool(follower_row.get("partial", false)),
		}
	# (b) Verified static PokeAPI front PNG, base species only
	# in practice: form rows carry no PokeAPI entries at all.
	var static_url: String = _pokeapi_front_url(row)
	if not static_url.is_empty():
		# (b1) Engine rigging (route 3): a rig definition for
		# this species animates the still in the engine. The
		# classification is honestly "engine-rigged": the ART
		# is the still (URL above, verbatim), the MOTION is
		# PUW's own rig, attached here as "rig".
		var rig: Dictionary = rig_registry().follower_rig(showdown_id)
		if not rig.is_empty():
			return {
				"classification": CLASS_RIGGED,
				"url": static_url,
				"source": STATIC_SOURCE_NAME,
				"animated": true,
				"species": label,
				"showdown_id": showdown_id,
				"is_form": is_form,
				"family": family,
				"reason": "",
				"provenance": "engine-rigged",
				"animation_status": "engine-rigged",
				"source_art_url": static_url,
				"rig_class": str(rig.get("locomotion_class", "")),
				"rig": rig,
			}
		return {
			"classification": CLASS_STATIC,
			"url": static_url,
			"source": STATIC_SOURCE_NAME,
			"animated": false,
			"species": label,
			"showdown_id": showdown_id,
			"is_form": is_form,
			"family": family,
			"reason": "",
			"provenance": "static-still",
			"animation_status": "neon-gap",
			"on_neon_gap_list": true,
		}
	# (c) Nothing. Missing is recorded, never papered over.
	var reason: String = "form_no_sprite_at_all" if is_form else "no_static_png_in_index"
	return _missing(label, family, showdown_id, is_form, reason)


## Classification counts over the whole main index, split by
## base species vs form rows, plus the MDX total (every MDX
## slot resolves missing by rule; the slot count is read from
## the MDX mapping data, never assumed).
## Returns {"base": {...}, "forms": {...}, "mdx": {...},
## "total_rows": int} where each inner Dictionary maps
## classification -> count.
func classification_counts() -> Dictionary:
	if not is_loaded():
		load_indexes()
	var base_counts: Dictionary = {CLASS_ANIMATED: 0, CLASS_RIGGED: 0, CLASS_STATIC: 0, CLASS_MISSING: 0}
	var form_counts: Dictionary = {CLASS_ANIMATED: 0, CLASS_RIGGED: 0, CLASS_STATIC: 0, CLASS_MISSING: 0}
	for row_value in _rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var result: Dictionary = resolve_row(row)
		var classification: String = str(result.get("classification", CLASS_MISSING))
		if bool(row.get("is_form", false)):
			form_counts[classification] = int(form_counts.get(classification, 0)) + 1
		else:
			base_counts[classification] = int(base_counts.get(classification, 0)) + 1
	var mdx_total: int = mdx_slot_count()
	var mdx_counts: Dictionary = {CLASS_ANIMATED: 0, CLASS_RIGGED: 0, CLASS_STATIC: 0, CLASS_MISSING: mdx_total}
	return {"base": base_counts, "forms": form_counts, "mdx": mdx_counts, "total_rows": _rows.size()}


## Number of MDX slots in the mapping data (1,519 shipped),
## or -1 when the mapping cannot be read.
func mdx_slot_count() -> int:
	var data: Dictionary = _shared_index(MDX_PATH)
	if data.is_empty():
		return -1
	var entries_value: Variant = data.get("entries", [])
	if entries_value is Array:
		var entries: Array = entries_value
		return entries.size()
	return int(data.get("slot_count", -1))


## Every URL recorded anywhere in the loaded index data
## (main index + follower index), as a url -> true Dictionary.
## The fabrication guard: resolve() only ever returns URLs
## from this set, copied verbatim from sprite entries.
func indexed_urls() -> Dictionary:
	var urls: Dictionary = {}
	_collect_urls(_rows, urls)
	_collect_urls(_follower_rows, urls)
	return urls


## True when "url" appears verbatim in the loaded index data.
func is_indexed_url(url: String) -> bool:
	if url.is_empty():
		return false
	return indexed_urls().has(url)


# ----------------------------------------------------------------
# Lookup helpers
# ----------------------------------------------------------------

func _missing(species: String, family: String, showdown_id: String, is_form: bool, reason: String) -> Dictionary:
	return {
		"classification": CLASS_MISSING,
		"url": "",
		"source": "",
		"animated": false,
		"species": species,
		"showdown_id": showdown_id,
		"is_form": is_form,
		"family": family,
		"reason": reason,
		"provenance": "none",
		"animation_status": "neon-gap",
		"on_neon_gap_list": true,
	}


## Exact-match row lookup. Tries, in order: the form-combined
## names (when a form is given), then the species name itself,
## against sprite_slug (hyphenated) and showdown_id
## (concatenated) in the main index, then the follower index.
## NO base-species fallback: a form name that matches no form
## row returns {} rather than its base species' row.
func _find_row(species: String, form: String) -> Dictionary:
	var candidates: Array = []
	var form_clean: String = form.strip_edges()
	if not form_clean.is_empty():
		candidates.append(species + "-" + form_clean)
		candidates.append(species + form_clean)
	candidates.append(species)
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		var hyphen: String = _hyphen_slug(candidate)
		if _by_sprite_slug.has(hyphen):
			var by_slug: Dictionary = _by_sprite_slug[hyphen]
			return by_slug
		var plain: String = hyphen.replace("-", "")
		if _by_showdown_id.has(plain):
			var by_id: Dictionary = _by_showdown_id[plain]
			return by_id
		if _by_showdown_id.has(hyphen):
			var by_id_hyphen: Dictionary = _by_showdown_id[hyphen]
			return by_id_hyphen
	# Follower index rows (future overworld source): same exact
	# matching, so an overworld-only species can still resolve.
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		var hyphen: String = _hyphen_slug(candidate)
		var plain: String = hyphen.replace("-", "")
		for row_value in _follower_rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			if str(row.get("sprite_slug", "")).to_lower() == hyphen:
				return row
			if str(row.get("showdown_id", "")).to_lower() == plain:
				return row
			if str(row.get("slug", "")).to_lower() == hyphen:
				return row
	return {}


## The animated follower URL for a row, or "" when none is
## indexed. Searches the row itself plus any follower-index row
## with the same showdown_id / sprite_slug. An entry qualifies
## only when it is marked for follower use, is animated, and is
## not a known dead link (verified_http_200 == false).
func _follower_animated_url(row: Dictionary) -> String:
	var url: String = _follower_animated_url_in_row(row)
	if not url.is_empty():
		return url
	var showdown_id: String = str(row.get("showdown_id", "")).to_lower()
	var sprite_slug: String = str(row.get("sprite_slug", "")).to_lower()
	for row_value in _follower_rows:
		if not (row_value is Dictionary):
			continue
		var follower_row: Dictionary = row_value
		var same: bool = false
		if not showdown_id.is_empty() and str(follower_row.get("showdown_id", "")).to_lower() == showdown_id:
			same = true
		if not sprite_slug.is_empty() and str(follower_row.get("sprite_slug", "")).to_lower() == sprite_slug:
			same = true
		if same:
			var follower_url: String = _follower_animated_url_in_row(follower_row)
			if not follower_url.is_empty():
				return follower_url
	return ""


## The follower-index row matching this row (same showdown_id
## or sprite_slug), or {} when the animated hit came from the
## row itself / no follower row matches.
func _matching_follower_row(row: Dictionary) -> Dictionary:
	var showdown_id: String = str(row.get("showdown_id", "")).to_lower()
	var sprite_slug: String = str(row.get("sprite_slug", "")).to_lower()
	for row_value in _follower_rows:
		if not (row_value is Dictionary):
			continue
		var follower_row: Dictionary = row_value
		if not showdown_id.is_empty() and str(follower_row.get("showdown_id", "")).to_lower() == showdown_id:
			return follower_row
		if not sprite_slug.is_empty() and str(follower_row.get("sprite_slug", "")).to_lower() == sprite_slug:
			return follower_row
	return {}


## The "source" value of the qualifying animated follower
## entry (e.g. "pmd-spritecollab"), or "" when none qualifies.
func _follower_animated_source(row: Dictionary) -> String:
	var source: String = _follower_animated_source_in_row(row)
	if not source.is_empty():
		return source
	var follower_row: Dictionary = _matching_follower_row(row)
	if not follower_row.is_empty():
		return _follower_animated_source_in_row(follower_row)
	return ""


func _follower_animated_source_in_row(row: Dictionary) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if not (sprites_value is Array):
		return ""
	var sprites: Array = sprites_value
	for entry_value in sprites:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("animated", false)):
			continue
		var verified_value: Variant = entry.get("verified_http_200", null)
		if verified_value == false:
			continue
		if not _is_follower_marked(entry):
			continue
		if not str(entry.get("url", "")).is_empty():
			return str(entry.get("source", ""))
	return ""


func _follower_animated_url_in_row(row: Dictionary) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if not (sprites_value is Array):
		return ""
	var sprites: Array = sprites_value
	for entry_value in sprites:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("animated", false)):
			continue
		var verified_value: Variant = entry.get("verified_http_200", null)
		if verified_value == false:
			continue
		if not _is_follower_marked(entry):
			continue
		var url: String = str(entry.get("url", ""))
		if not url.is_empty():
			return url
	return ""


## A sprite entry is marked for follower use when its context
## or usage names the follower/overworld context, or its
## pattern names it. Battle patterns ("ani", "gen5ani", ...)
## never qualify -- battle art is not follower animation.
func _is_follower_marked(entry: Dictionary) -> bool:
	var context: String = str(entry.get("context", entry.get("usage", ""))).strip_edges().to_lower()
	if context == "follower" or context == "overworld" or context == "follower_overworld":
		return true
	var pattern: String = str(entry.get("pattern", "")).strip_edges().to_lower()
	return pattern.begins_with("follower") or pattern.begins_with("overworld")


## The PokeAPI front still PNG URL recorded verbatim on the
## row, or "" when the row has none (all form rows). A known
## dead link (verified_http_200 == false) is never returned.
## No URL is built here: unlike ShinySpriteResolver, this
## resolver never falls back to pattern templates.
func _pokeapi_front_url(row: Dictionary) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if not (sprites_value is Array):
		return ""
	var sprites: Array = sprites_value
	for entry_value in sprites:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("source", "")) != "pokeapi":
			continue
		if str(entry.get("pattern", "")) != "front":
			continue
		if str(entry.get("view", "front")) != "front":
			continue
		if bool(entry.get("shiny", false)):
			continue
		var verified_value: Variant = entry.get("verified_http_200", null)
		if verified_value == false:
			continue
		var url: String = str(entry.get("url", ""))
		if not url.is_empty():
			return url
	return ""


func _collect_urls(rows: Array, urls: Dictionary) -> void:
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var sprites_value: Variant = row.get("sprites", [])
		if not (sprites_value is Array):
			continue
		var sprites: Array = sprites_value
		for entry_value in sprites:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var url: String = str(entry.get("url", ""))
				if not url.is_empty():
					urls[url] = true


# ----------------------------------------------------------------
# Index loading (shared, parse-once)
# ----------------------------------------------------------------

static func _shared_index(path: String) -> Dictionary:
	if _shared_indexes.has(path):
		var cached: Dictionary = _shared_indexes[path]
		return cached
	var parsed_data: Dictionary = {}
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		if not text.is_empty():
			var parsed_value: Variant = JSON.parse_string(text)
			if parsed_value is Dictionary:
				parsed_data = parsed_value
	_shared_indexes[path] = parsed_data
	return parsed_data


static func _index_rows(data: Dictionary) -> Array:
	var rows_value: Variant = data.get("rows", [])
	if rows_value is Array:
		var rows: Array = rows_value
		return rows
	return []


static func _index_rows_by_id(rows: Array, by_showdown_id: Dictionary, by_sprite_slug: Dictionary) -> void:
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var showdown_id: String = str(row.get("showdown_id", "")).to_lower()
		if not showdown_id.is_empty():
			by_showdown_id[showdown_id] = row
		var sprite_slug: String = str(row.get("sprite_slug", "")).to_lower()
		if not sprite_slug.is_empty():
			by_sprite_slug[sprite_slug] = row


## Same normalization family as PUWFollowerController._slugify:
## lowercase, spaces become hyphens, apostrophes and periods
## dropped, female sign becomes -f and male sign becomes -m.
static func _hyphen_slug(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "-f").replace("♂", "-m")
	out = out.replace("é", "e").replace("è", "e").replace("ê", "e")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	out = out.replace("_", "-")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out
