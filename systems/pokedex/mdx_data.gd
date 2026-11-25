class_name PUWMDXData
extends RefCounted
## MDX (Moemon dex) data layer for Pokemon Ultimate World.
##
## Data sources (all real, all shipped in the project):
## - Mapping: res://data/mdx_mapping.json, built by
##   tools/build_mdx_mapping.py from the sourced 1,519-slot CSV
##   (MOEMON_GEN1_9_1519_SLOT_MAPPING.csv). One entry per slot:
##   {slot, species_slug, decoded_name, generation, ...}.
##   The CSV carries no species_id column, and its local sprite
##   file paths were deliberately excluded at build time.
## - Voices: res://data/mdx_voices.json, installed verbatim from
##   the sourced species_cries_and_moemon_voices.json. Its MDX
##   entries are SPECIFIED only (0 recorded). This class reports
##   voice status; it never produces or fakes audio.
##
## Rules (from the sourced register):
## - An MDX mon mirrors its PKDX counterpart exactly for battle
##   data: stats, types, abilities and moves are UNCHANGED. Only
##   the family changes, to "MDX" — the same "family" field name
##   the follower controller (PUWFollowerController) and the
##   Pokedex register use.
## - MDX cries use the Pokemon counterpart's cry URL from the
##   cries bank, via PokemonCryPlayer (res://audio/cries/
##   cries_bank.json, the "latest" link).
## - MDX sprites resolve ONLY through the public URL sprite
##   index, via ShinySpriteResolver
##   (res://data/shiny_sprites_index.json). A species with no
##   sprite in the index is honestly reported as "missing".
##
## Extraction integration build (2026-11-23, Solid Rule): MDX now
## also has its own bound-art index, res://data/mdx_sprites_index.json
## (audit: res://data/mdx_sprite_audit.json). It records, per slot,
## the Moemon art bound locally in this project (MoeMMO distribution
## copies of the Moemon Project pool: battle sets, follower walk
## sheets, party icons) and the slots whose verified Quetzal
## extraction still lives only in Neon's archive. The accessors
## below serve that index; sprite_for() above keeps its original
## counterpart-index behaviour for battle display compatibility.

const MAPPING_PATH: String = "res://data/mdx_mapping.json"
const VOICES_PATH: String = "res://data/mdx_voices.json"
const SPRITES_INDEX_PATH: String = "res://data/mdx_sprites_index.json"
const MDX_FAMILY: String = "MDX"

var _entries: Array = []
var _loaded: bool = false
var _sprite_slots: Dictionary = {}
var _sprites_loaded: bool = false
var _specified_voice_slugs: Dictionary = {}
var _voices_loaded: bool = false
var _cry_player: PokemonCryPlayer = null
var _sprite_resolver: ShinySpriteResolver = null


## Load (once) the MDX slot mapping. Returns the entry count
## (1,519 for the shipped file, 0 when the file is missing or
## unreadable).
func load_mapping() -> int:
	if _loaded:
		return _entries.size()
	_loaded = true
	_entries = []
	if not FileAccess.file_exists(MAPPING_PATH):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPPING_PATH))
	if not (parsed is Dictionary):
		return 0
	var data: Dictionary = parsed
	var list_value: Variant = data.get("entries", [])
	if list_value is Array:
		var list: Array = list_value
		for entry_value in list:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				_entries.append(entry)
	return _entries.size()


## All mapping entries (a deep copy), in slot order.
func mapping_entries() -> Array:
	load_mapping()
	return _entries.duplicate(true)


## The MDX mapping entry for a species slug: the FIRST slot
## carrying that slug (the base slot; later slots with the same
## slug are forms/megas/variants). Returns {} when the slug is
## not in the mapping.
func counterpart_of(species_slug: String) -> Dictionary:
	load_mapping()
	var wanted: String = species_slug.strip_edges().to_lower()
	for entry_value in _entries:
		var entry: Dictionary = entry_value
		if str(entry.get("species_slug", "")) == wanted:
			return entry.duplicate(true)
	return {}


## Every slot carrying this slug (base + forms), in slot order.
func slots_for(species_slug: String) -> Array:
	load_mapping()
	var wanted: String = species_slug.strip_edges().to_lower()
	var out: Array = []
	for entry_value in _entries:
		var entry: Dictionary = entry_value
		if str(entry.get("species_slug", "")) == wanted:
			out.append(entry.duplicate(true))
	return out


## Build the MDX version of a PKDX party mon: a deep copy with
## "family" set to "MDX" and nothing else changed — stats,
## types, abilities and moves mirror the counterpart exactly.
## The input Dictionary is not modified.
func build_mdx_mon(pkdx_mon: Dictionary) -> Dictionary:
	var mon: Dictionary = pkdx_mon.duplicate(true)
	mon["family"] = MDX_FAMILY
	return mon


## The counterpart Pokemon's cry URL from the cries bank (the
## "latest" link, via PokemonCryPlayer). "" when the species
## has no bank entry.
func cry_url_for(species_slug: String) -> String:
	if _cry_player == null:
		_cry_player = PokemonCryPlayer.new()
	return _cry_player.cry_url_for(species_slug.strip_edges().to_lower())


## The counterpart's sprite through the public URL sprite
## index only: {url, status: "url_index"} when the index has a
## sprite, {url: "", status: "missing"} when it does not.
func sprite_for(species_slug: String, shiny: bool) -> Dictionary:
	if _sprite_resolver == null:
		_sprite_resolver = ShinySpriteResolver.new()
	var url: String = _sprite_resolver.get_sprite_url(species_slug.strip_edges().to_lower(), shiny)
	if url.is_empty():
		return {"url": "", "status": "missing"}
	return {"url": url, "status": "url_index"}


## Load (once) the bound-art sprite index. Returns the slot
## count (1,519 for the shipped file, 0 when missing).
func load_sprite_index() -> int:
	if _sprites_loaded:
		return _sprite_slots.size()
	_sprites_loaded = true
	_sprite_slots = {}
	if not FileAccess.file_exists(SPRITES_INDEX_PATH):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPRITES_INDEX_PATH))
	if not (parsed is Dictionary):
		return 0
	var data: Dictionary = parsed
	var list_value: Variant = data.get("slots", [])
	if list_value is Array:
		var list: Array = list_value
		for entry_value in list:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				_sprite_slots[int(entry.get("slot", 0))] = entry
	return _sprite_slots.size()


## The full sprite-index entry for a slot ({} when unknown).
func sprite_entry_for_slot(slot: int) -> Dictionary:
	load_sprite_index()
	var entry_value: Variant = _sprite_slots.get(slot, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		return entry.duplicate(true)
	return {}


## The slot's battle-art record: {status: "bound_local_static",
## views: {front/back/front_shiny/back_shiny -> res path}, ...}
## for locally bound sets, or {status: "quetzal_archive_only"}
## when the verified extracted set is not on this machine.
## Consolidation build (2026-11-23): 645 slots carry status
## "bound_local_animated" instead -- front/front_shiny are the
## Moemon Black 2 v1.1 kit keyframes in art/mdx/battle_animated/
## and the record's motion_data carries the preserved BW2 CTRL
## block + NANR/NMAR tables; backs stay the MoeMMO Moemon backs
## (the ROM kits' backs are vanilla and were not bound).
func battle_sprite_for_slot(slot: int) -> Dictionary:
	var entry: Dictionary = sprite_entry_for_slot(slot)
	var battle_value: Variant = entry.get("battle", {})
	if battle_value is Dictionary:
		var battle: Dictionary = battle_value
		return battle.duplicate(true)
	return {"status": "unknown"}


## The slot's follower record: {status: "bound_local_animated",
## sheet: res path, ...} or {status: "missing"} — never a
## borrowed counterpart sheet.
func follower_sheet_for_slot(slot: int) -> Dictionary:
	var entry: Dictionary = sprite_entry_for_slot(slot)
	var follower_value: Variant = entry.get("follower", {})
	if follower_value is Dictionary:
		var follower: Dictionary = follower_value
		return follower.duplicate(true)
	return {"status": "unknown"}


## The slot's bound party icon res path, or "" when none bound.
func party_icon_for_slot(slot: int) -> String:
	var entry: Dictionary = sprite_entry_for_slot(slot)
	return str(entry.get("party_icon", ""))


## "specified_only" when the voices data carries a SPECIFIED
## MDX voice entry for this species (specified on paper, never
## recorded — no audio exists), else "not_recorded".
func voice_status(species_slug: String) -> String:
	_load_voices()
	var wanted: String = species_slug.strip_edges().to_lower()
	if bool(_specified_voice_slugs.get(wanted, false)):
		return "specified_only"
	return "not_recorded"


func _load_voices() -> void:
	if _voices_loaded:
		return
	_voices_loaded = true
	_specified_voice_slugs = {}
	if not FileAccess.file_exists(VOICES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOICES_PATH))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var list_value: Variant = data.get("entries", [])
	if not (list_value is Array):
		return
	var list: Array = list_value
	for entry_value in list:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("family", "")) != MDX_FAMILY:
			continue
		if str(entry.get("status", "")) != "SPECIFIED":
			continue
		var slug: String = _slug_from_voice_audio_id(str(entry.get("audio_id", "")))
		if not slug.is_empty():
			_specified_voice_slugs[slug] = true


## Voice audio ids look like "voice_mdx_0025_pikachu_f": the
## slug is the middle part, between the numeric species id and
## the trailing sex marker.
static func _slug_from_voice_audio_id(audio_id: String) -> String:
	var parts: PackedStringArray = audio_id.split("_")
	if parts.size() < 5:
		return ""
	var slug_parts: Array = []
	for i in range(3, parts.size() - 1):
		slug_parts.append(parts[i])
	return "-".join(slug_parts)
