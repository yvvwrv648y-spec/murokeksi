class_name PUWSpeciesAbilities
extends RefCounted
## Per-species ability slots for the Ability Capsule / Ability Patch
## (code prep code_prep_item_engine_gaps, closing gap G2 of
## code_prep_item_target/PREP_REPORT.md).
##
## ItemEngine's ability arms have always worked; what they lacked
## was honest context data: the species' non-Hidden abilities in
## order ("species_abilities") and which ability is Hidden
## ("hidden_ability"). The mirror's only per-species ability
## source, pokemon/registry/master_species_registry.json, covers
## 25 species and does not mark the Hidden slot, so the item-
## target prep refused every ability item needs_species_data
## rather than guess which ability was hidden.
##
## This resolver reads data/species_abilities.json, generated
## from the held registry conversion of Showdown's pokedex
## (hidden_files/data_registry/converted/showdown_pokedex.json;
## generator: the prep's work/generate_species_abilities.py).
## 1,481 species rows: "abilities" is the regular slots in the
## source's own order, "hidden" the source's "H" slot ("" when
## the species has none). Showdown's "S" slot (a special,
## non-capsule ability: Battle Bond, Power Construct, Own
## Tempo) is deliberately NOT carried — the games' Capsule
## cannot reach it either.
##
## A species with no row resolves to {} and the ability items
## refuse it needs_species_data, exactly as before. No fallback
## to a base species, no guessing: the row must be the species'
## own.

const DATA_PATH: String = "res://data/species_abilities.json"

static var _rows: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rows = {}
	if not FileAccess.file_exists(DATA_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		var species_value: Variant = (parsed as Dictionary).get("species", {})
		if species_value is Dictionary:
			_rows = species_value


## The lookup key for a species string: Showdown's species id,
## which is what the generated table is keyed by. Lowercase,
## accents folded, gender signs become f/m, then every character
## that is not a letter or digit is dropped — "Mr. Mime" ->
## "mrmime", "Farfetch'd" -> "farfetchd", "Nidoran♀" ->
## "nidoranf", "Type: Null" -> "typenull", "Flabébé" ->
## "flabebe".
static func key_for(species: String) -> String:
	var s: String = species.to_lower()
	s = s.replace("é", "e").replace("è", "e")
	s = s.replace("♀", "f").replace("♂", "m")
	var out: String = ""
	for i in s.length():
		var c: String = s[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


## The species' row: {"abilities": [...], "hidden": "...",
## "name": "..."}, or {} when the held data has no row for it.
static func for_species(species: String) -> Dictionary:
	_ensure_loaded()
	var row_value: Variant = _rows.get(key_for(species), {})
	if row_value is Dictionary:
		return row_value
	return {}


static func has_species(species: String) -> bool:
	return not for_species(species).is_empty()


## The ItemEngine context for one species:
## {"species_abilities": [...], "hidden_ability": "..."} —
## exactly the keys use_battle_item's ability arms read. {}
## when the species has no row.
static func context_for(species: String) -> Dictionary:
	var row: Dictionary = for_species(species)
	if row.is_empty():
		return {}
	var abilities_value: Variant = row.get("abilities", [])
	var abilities: Array = []
	if abilities_value is Array:
		abilities = abilities_value
	return {
		"species_abilities": abilities,
		"hidden_ability": str(row.get("hidden", "")),
	}


## How many species rows the held table carries (tests/report).
static func species_count() -> int:
	_ensure_loaded()
	return _rows.size()
