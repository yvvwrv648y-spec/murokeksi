class_name PUWStylerSpeciesData
extends RefCounted
## SOURCED PER-SPECIES STYLER DATA LOADER (prep merge step 6).
##
## Parses hunt rotation 7's landed Browser JSONs (copied into
## this prep's data/ with hashes in data/MANIFEST.tsv;
## documentation-derived transcriptions from Bulbapedia
## "Friend Pokemon (Ranger)" -- NOT game data, NOT ROM
## extraction) into the session target fields the Styler
## system consumes:
##   fiore   -> "loops_required" (int)
##   almia   -> "gauge_points" (Array, per encounter context,
##              preserved in source order, never averaged)
##   oblivia -> "gauge_points" + "agitated_gauge_points"
##              (Array or empty when the source prints "-":
##              a second, per-species data dimension, carried
##              as data -- no ratio is baked in or applied)
## plus "field_moves" (move id -> level) parsed from the
## source's "Burn 3" / "Teleport" strings. Unlevelled
## species-specific moves land at level 1 with the move also
## listed in the record's "species_specific_moves".
##
## Per-region separation is strict: a Fiore record never
## carries gauge fields and an Oblivia record's agitated
## values never leak into Almia. Species ids are the source's
## display names lowercased with spaces/punctuation folded to
## underscores (content normalizes at bind if its register
## disagrees; the browser_no is the stable key).

static func parse_field_move(raw: String) -> Dictionary:
	var text: String = raw.strip_edges()
	if text == "" or text == "None":
		return {}
	var parts: PackedStringArray = text.split(" ")
	var level: int = 1
	var levelled: bool = false
	var last: String = str(parts[parts.size() - 1])
	if last.is_valid_int():
		level = int(last)
		levelled = true
		parts.remove_at(parts.size() - 1)
	var move_id: String = " ".join(parts).to_lower().replace(" ", "_")
	return {"move_id": move_id, "level": level, "levelled": levelled}


static func species_id(display_name: String) -> String:
	var out: String = display_name.to_lower()
	out = out.replace(" ", "_").replace(".", "").replace("'", "")
	out = out.replace("♀", "_f").replace("♂", "_m")
	return out


## Parse one landed Browser JSON text into normalized records.
## Returns [] on malformed input (never fabricates rows).
static func parse_browser_json(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return []
	var root: Dictionary = parsed
	var region: String = str(root.get("region", ""))
	var rows_value: Variant = root.get("rows", [])
	if not (rows_value is Array):
		return []
	var rows: Array = rows_value
	var out: Array = []
	for row_value: Variant in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var record: Dictionary = {
			"region": region,
			"browser_no": str(row.get("browser_no", "")),
			"species": species_id(str(row.get("species", ""))),
			"species_display": str(row.get("species", "")),
			"group": str(row.get("group", "")).to_lower(),
			"poke_assist": str(row.get("poke_assist", "")).to_lower().replace(" ", "_"),
			"field_moves": {},
			"species_specific_moves": [],
		}
		var fm: Dictionary = parse_field_move(str(row.get("field_move", "")))
		if not fm.is_empty():
			var moves: Dictionary = {}
			moves[str(fm.get("move_id", ""))] = int(fm.get("level", 1))
			record["field_moves"] = moves
			if not bool(fm.get("levelled", false)):
				record["species_specific_moves"] = [str(fm.get("move_id", ""))]
		if region == "fiore":
			record["loops_required"] = int(row.get("loops_required", 0))
		else:
			var gauge_value: Variant = row.get("gauge_points", [])
			var gauge: Array = []
			if gauge_value is Array:
				var raw_gauge: Array = gauge_value
				for point_value: Variant in raw_gauge:
					gauge.append(int(point_value))
			record["gauge_points"] = gauge
			record["friendship_required"] = float(gauge[0]) if not gauge.is_empty() else 0.0
		if region == "oblivia":
			var agitated_value: Variant = row.get("agitated_gauge_points", null)
			var agitated: Array = []
			if agitated_value is Array:
				var raw_agitated: Array = agitated_value
				for point_value: Variant in raw_agitated:
					agitated.append(int(point_value))
			record["agitated_gauge_points"] = agitated
			record["has_agitated_gauge"] = not agitated.is_empty()
		out.append(record)
	return out


static func find_species(records: Array, species: String) -> Dictionary:
	for record_value: Variant in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("species", "")) == species:
				return record
	return {}


static func find_browser_no(records: Array, browser_no: String) -> Dictionary:
	for record_value: Variant in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("browser_no", "")) == browser_no:
				return record
	return {}


## The Oblivia Styler Modification catalog total, computed
## from the landed price table (never a hand-typed sum).
static func modification_catalog_total(json_text: String) -> int:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return -1
	var root: Dictionary = parsed
	var mods_value: Variant = root.get("modifications", [])
	if not (mods_value is Array):
		return -1
	var mods: Array = mods_value
	var total: int = 0
	for mod_value: Variant in mods:
		if mod_value is Dictionary:
			var mod: Dictionary = mod_value
			var levels_value: Variant = mod.get("levels", [])
			if levels_value is Array:
				var levels: Array = levels_value
				for level_value: Variant in levels:
					if level_value is Dictionary:
						var level_row: Dictionary = level_value
						total += int(level_row.get("ranger_points", 0))
	return total


## One modification track's price list, in level order.
static func modification_track_prices(json_text: String, track_name: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return []
	var root: Dictionary = parsed
	var mods_value: Variant = root.get("modifications", [])
	if not (mods_value is Array):
		return []
	var mods: Array = mods_value
	for mod_value: Variant in mods:
		if mod_value is Dictionary:
			var mod: Dictionary = mod_value
			if str(mod.get("modification", "")) == track_name:
				var prices: Array = []
				var levels_value: Variant = mod.get("levels", [])
				if levels_value is Array:
					var levels: Array = levels_value
					for level_value: Variant in levels:
						if level_value is Dictionary:
							var level_row: Dictionary = level_value
							prices.append(int(level_row.get("ranger_points", 0)))
				return prices
	return []
