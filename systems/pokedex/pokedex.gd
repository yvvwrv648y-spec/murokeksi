class_name PUWPokedex
extends RefCounted
## Pokedex data access for the two separate dex families:
## PKDX (the regular Pokemon dex) and MDX (the Moemon dex).
## The families are kept separate on purpose: PKDX entries come
## from the species list, MDX entries come only from the sourced
## MDX seed register, and the two entry functions never mix.
##
## PKDX species source: res://data/exp_yield.json — a PokeAPI
## species list whose "species" array carries an id and a name
## (slug) for the full 1,025 species (its own "count" is 1025).
##
## Seen/caught state shape mirrors PUWSaveManager exactly:
## build_state() stores two plain Arrays of species slug
## Strings under the keys "dex_seen" and "dex_caught" in the
## save state Dictionary. pokedex_entries() reads that shape and
## mark_seen()/mark_caught() mutate that shape in place.

const SPECIES_PATH: String = "res://data/exp_yield.json"
const MDX_PATH: String = "res://systems/pokedex/mdx_register.json"

var _species: Array = []
var _mdx_data: Dictionary = {}


func _init() -> void:
	_load_species()
	_load_mdx()


func _load_species() -> void:
	_species.clear()
	if not FileAccess.file_exists(SPECIES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPECIES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var list_value: Variant = data.get("species", [])
	if not (list_value is Array):
		return
	var list: Array = list_value
	for entry_value in list:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			_species.append({
				"id": int(entry.get("id", 0)),
				"slug": str(entry.get("name", ""))
			})
	_species.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))


func _load_mdx() -> void:
	_mdx_data.clear()
	if not FileAccess.file_exists(MDX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MDX_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	_mdx_data = data.duplicate(true)


## How many PKDX species the loaded list holds (1,025).
func species_count() -> int:
	return _species.size()


## Resolve a species argument (a slug String like "pikachu", a
## display name like "Pikachu", or an int id like 25) to the
## loaded species row. Returns an empty Dictionary when the
## species is not in the list.
func _resolve_species(species: Variant) -> Dictionary:
	if typeof(species) == TYPE_INT or typeof(species) == TYPE_FLOAT:
		var wanted_id: int = int(species)
		for row_value in _species:
			var row: Dictionary = row_value
			if int(row.get("id", 0)) == wanted_id:
				return row
		return {}
	var wanted_slug: String = str(species).to_lower()
	for row_value in _species:
		var row: Dictionary = row_value
		if str(row.get("slug", "")) == wanted_slug:
			return row
	return {}


## True when the save-manager-shaped list (an Array under
## "dex_seen"/"dex_caught") names this species, by slug String
## or by int id.
func _list_has(state: Dictionary, key: String, species_id: int, slug: String) -> bool:
	var list_value: Variant = state.get(key, [])
	if not (list_value is Array):
		return false
	var list: Array = list_value
	for item in list:
		if typeof(item) == TYPE_STRING and str(item) == slug:
			return true
		if (typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT) and int(item) == species_id:
			return true
	return false


## Append the slug to one of the state's dex lists, creating the
## list in the save manager's shape (a plain Array under the
## key) when it is missing. No duplicates.
func _list_add(state: Dictionary, key: String, species_id: int, slug: String) -> void:
	var list_value: Variant = state.get(key, [])
	var list: Array = []
	if list_value is Array:
		var existing: Array = list_value
		list = existing
	if _list_has(state, key, species_id, slug):
		state[key] = list
		return
	list.append(slug)
	state[key] = list


## Every PKDX species with its status in the given save state:
## "caught" when its slug is in dex_caught, else "seen" when in
## dex_seen, else "unseen". Each entry is
## {id, slug, name, status} in national dex order.
func pokedex_entries(state: Dictionary) -> Array:
	var entries: Array = []
	for row_value in _species:
		var row: Dictionary = row_value
		var species_id: int = int(row.get("id", 0))
		var slug: String = str(row.get("slug", ""))
		var status: String = "unseen"
		if _list_has(state, "dex_caught", species_id, slug):
			status = "caught"
		elif _list_has(state, "dex_seen", species_id, slug):
			status = "seen"
		entries.append({
			"id": species_id,
			"slug": slug,
			"name": slug,
			"status": status
		})
	return entries


## Mark a species seen in the state dict (save manager shape:
## its slug joins the "dex_seen" Array). Returns false when the
## species is not in the PKDX list.
func mark_seen(state: Dictionary, species: Variant) -> bool:
	var row: Dictionary = _resolve_species(species)
	if row.is_empty():
		return false
	_list_add(state, "dex_seen", int(row.get("id", 0)), str(row.get("slug", "")))
	return true


## Mark a species caught in the state dict: its slug joins the
## "dex_caught" Array, and the "dex_seen" Array too (a caught
## species has been seen). Returns false when the species is
## not in the PKDX list.
func mark_caught(state: Dictionary, species: Variant) -> bool:
	var row: Dictionary = _resolve_species(species)
	if row.is_empty():
		return false
	var species_id: int = int(row.get("id", 0))
	var slug: String = str(row.get("slug", ""))
	_list_add(state, "dex_seen", species_id, slug)
	_list_add(state, "dex_caught", species_id, slug)
	return true


## The MDX entries: only the sourced seed register
## (systems/pokedex/mdx_register.json). Kept fully separate
## from pokedex_entries(); MDX has no seen/caught state here.
func pokedex_entries_mdx() -> Array:
	var list_value: Variant = _mdx_data.get("entries", [])
	if list_value is Array:
		var list: Array = list_value
		return list.duplicate(true)
	return []


## The register's mapping note, stating that the fan-Moemon
## species mapping is otherwise empty.
func mdx_mapping_note() -> String:
	return str(_mdx_data.get("mapping_note", ""))
