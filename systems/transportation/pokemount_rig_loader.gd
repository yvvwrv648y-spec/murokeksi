class_name PUWPokeMountRigLoader
extends RefCounted
## Builds SpriteFrames for PokéMount ride art from the frame
## PNGs bound by the consolidation build (art/pokemount/<set>/,
## 352 frames, 7 mounts in 11 sets), driven entirely by the
## shipped registry data/pokemount_art_index.json. This is the
## art layer only, in the same shape as PUWBikeRigLoader /
## PUWCastRigLoader: status is "loaded" only when every frame
## PNG for the resolved set exists and loads; it never invents,
## substitutes, or placeholder-renders a frame.
##
## SET / ROW LAYOUT (read from the index; direction order
## verified visually against the bound frames on 2026-11-23):
## every set is a 4x8 grid of 33x33 frames sliced to individual
## PNGs named "<set>_r<1-8>c<1-4>.png". Within each 4-row block
## the rows are the four facings in RPG Maker / Essentials
## charset order: down, left, right, up; the columns are the
## 4-frame walk cycle (column 2 is the neutral standing frame,
## the classic charset layout: step / stand / step / stand).
## The two blocks differ per set, exactly as the index's
## row_layout records:
## - combined sheets (kabutops / avalugg / gogoat / hippowdon /
##   swampert "<species>_male_female"): rows 1-4 are the MALE
##   mount, rows 5-8 the FEMALE mount (block axis "gender").
## - single-gender sheets (luxray_male / luxray_female and the
##   four lanturn sets): rows 1-4 are plain, rows 5-8 are the
##   Flash-sparkle variant (block axis "flash").
##
## SET SELECTION: a species' sets split by variant — "land"
## (the default), "surf" and "dive" (lanturn carries genuine
## surf and dive sets per gender). The ride mode picks the
## context: diving -> "dive"; surfing / ferrying /
## climbing_waterfall -> "surf"; every other mode -> "land".
## Fallbacks, in order: a dive context with no dive set uses
## the surf set (same water art family); a species with exactly
## ONE variant family uses that set for every context (the
## single-set rule — it is how swampert's own index kind,
## "land/surf mount", already reads). A bound species with no
## set for the context and no fallback (lanturn asked for land
## art: it has surf + dive sets only) reports
## "no_set_for_mode" and builds nothing. A species with no
## PokéMount art at all (the 7 fetch-list mounts — lapras,
## torkoal, flygon, gyarados, araquanid, sharpedo, rhyhorn —
## and every other species) reports "not_bound".
##
## GENDER: the mount individual's gender ("male" / "female",
## from the party record where live play records it; "" when
## unknown). Combined sheets select the gender's block;
## single-gender sets select the matching set. Unknown gender
## takes the male block / male set — the index's first-listed
## variant — and the result records the gender actually used,
## so the choice is never silent.
##
## FLASH: flash=true selects the Flash-sparkle block on
## flash-axis sets (luxray / lanturn). It is the display hook
## for the illuminate field action's lit state; the loader only
## reports whether the resolved set could apply it
## ("flash_applied"). Gender-axis sets have no Flash rows and
## ignore the flag.
##
## ANIMATIONS: built under the player controller's own naming
## ("%s_%s" % [state, facing] — see PUWPlayerController), one
## "idle_<facing>" (the neutral column-2 frame), one
## "walk_<facing>" and one "run_<facing>" (the full 4-column
## cycle) per facing, at the controller's CLIP_FPS rates (idle
## 4.0 / walk 7.5 / run 11.0 — PUWPlayerController._refresh_
## animation re-applies those rates at play time anyway). The
## frames draw the mount WITH its rider (the PokéMount sheets
## carry a generic rider, cap and all), exactly like the tandem
## bike frames: the composite is one sprite, never split.

const INDEX_PATH: String = "res://data/pokemount_art_index.json"

const FACINGS: Array = ["down", "left", "right", "up"]
const FACING_ROW_OFFSET: Dictionary = {"down": 0, "left": 1, "right": 2, "up": 3}
const IDLE_COLUMN: int = 2
const CYCLE_COLUMNS: Array = [1, 2, 3, 4]
const IDLE_FPS: float = 4.0
const WALK_FPS: float = 7.5
const RUN_FPS: float = 11.0

static var _index_loaded: bool = false
static var _rows_by_species: Dictionary = {}
static var _bound_species: Array = []
static var _missing_species: Array = []


static func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


## Same slug normalization as PUWRideSystem._normalize_slug.
static func _normalize_slug(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	out = out.replace("♀", "-f").replace("♂", "-m")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out


static func _variant_for_set(set_name: String) -> String:
	if set_name.ends_with("_dive"):
		return "dive"
	if set_name.contains("_surf"):
		return "surf"
	return "land"


static func _block_axis_for_layout(row_layout: String) -> String:
	if row_layout.contains("rows 1-4 male, rows 5-8 female"):
		return "gender"
	if row_layout.contains("Flash sparkle"):
		return "flash"
	return "none"


static func _set_gender_for(set_name: String, block_axis: String) -> String:
	if block_axis == "gender":
		return ""
	if set_name.contains("_female"):
		return "female"
	if set_name.contains("_male"):
		return "male"
	return ""


static func _ensure_loaded() -> void:
	if _index_loaded:
		return
	_index_loaded = true
	var index: Dictionary = _load_json(INDEX_PATH)
	var present_value: Variant = index.get("mounts_present", [])
	if present_value is Array:
		var present: Array = present_value
		for slug_value: Variant in present:
			_bound_species.append(str(slug_value))
	var missing_value: Variant = index.get("mounts_missing", {})
	if missing_value is Dictionary:
		var missing: Dictionary = missing_value
		var list_value: Variant = missing.get("list", [])
		if list_value is Array:
			var list: Array = list_value
			for slug_value: Variant in list:
				_missing_species.append(str(slug_value))
	var rows_value: Variant = index.get("rows", [])
	if rows_value is Array:
		var rows: Array = rows_value
		for row_value: Variant in rows:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			var set_name: String = str(row.get("set", ""))
			var species: String = str(row.get("mount_species", ""))
			if set_name == "" or species == "":
				continue
			var block_axis: String = _block_axis_for_layout(str(row.get("row_layout", "")))
			var record: Dictionary = {
				"set": set_name,
				"species": species,
				"kind": str(row.get("kind", "")),
				"variant": _variant_for_set(set_name),
				"block_axis": block_axis,
				"set_gender": _set_gender_for(set_name, block_axis),
				"frame_dir": "res://" + str(row.get("frame_dir", "")),
				"frame_count": int(row.get("frame_count", 0)),
			}
			var species_rows: Array = []
			var existing_value: Variant = _rows_by_species.get(species, [])
			if existing_value is Array:
				var existing: Array = existing_value
				species_rows = existing
			species_rows.append(record)
			_rows_by_species[species] = species_rows


# ------------------------------------------------------------------
# Index queries
# ------------------------------------------------------------------

## Species with bound PokéMount art (index order).
static func bound_species() -> Array:
	_ensure_loaded()
	return _bound_species.duplicate()


## Species whose PokéMount sheets are still on the fetch list.
static func missing_species() -> Array:
	_ensure_loaded()
	return _missing_species.duplicate()


## True when the species has bound PokéMount art.
static func is_bound(species_ref: String) -> bool:
	_ensure_loaded()
	return _rows_by_species.has(_normalize_slug(species_ref))


## The normalized set records for one species ([] when unbound).
static func sets_for_species(species_ref: String) -> Array:
	_ensure_loaded()
	var value: Variant = _rows_by_species.get(_normalize_slug(species_ref), [])
	if value is Array:
		var rows: Array = value
		return rows.duplicate(true)
	return []


## The art context a ride mode displays in: "dive", "surf", or
## "land" (see header).
static func context_for_mode(mode_id: String) -> String:
	match mode_id:
		"diving":
			return "dive"
		"surfing", "ferrying", "climbing_waterfall":
			return "surf"
	return "land"


# ------------------------------------------------------------------
# Set resolution
# ------------------------------------------------------------------

## Resolve the set + block for one mount display, without
## loading any texture. Returns a Dictionary:
## {"status": "resolved" | "not_bound" | "no_set_for_mode",
##  "species", "mode", "context", "set", "variant",
##  "gender_used", "block_axis", "block_base_row" (0-based
##  first row of the selected block), "frame_dir"}.
static func resolve_set(species_ref: String, mode_id: String, gender: String = "") -> Dictionary:
	_ensure_loaded()
	var species: String = _normalize_slug(species_ref)
	var context: String = context_for_mode(mode_id)
	var base: Dictionary = {
		"species": species, "mode": mode_id, "context": context,
		"set": "", "variant": "", "gender_used": "",
		"block_axis": "", "block_base_row": 0, "frame_dir": "",
	}
	var rows: Array = sets_for_species(species)
	if rows.is_empty():
		base["status"] = "not_bound"
		return base
	# Variant choice with the documented fallbacks.
	var variants_present: Dictionary = {}
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		variants_present[str(row.get("variant", ""))] = true
	var variant: String = context
	if not variants_present.has(variant):
		if context == "dive" and variants_present.has("surf"):
			variant = "surf"
		elif variants_present.size() == 1:
			variant = str(variants_present.keys()[0])
		else:
			base["status"] = "no_set_for_mode"
			return base
	# Gender choice among the variant's sets, index order.
	var wanted_gender: String = gender.strip_edges().to_lower()
	if wanted_gender != "male" and wanted_gender != "female":
		wanted_gender = ""
	var chosen: Dictionary = {}
	var first_of_variant: Dictionary = {}
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		if str(row.get("variant", "")) != variant:
			continue
		if first_of_variant.is_empty():
			first_of_variant = row
		var set_gender: String = str(row.get("set_gender", ""))
		if set_gender == "":
			# Combined sheet: serves either gender.
			if chosen.is_empty():
				chosen = row
		elif wanted_gender != "" and set_gender == wanted_gender:
			chosen = row
			break
		elif wanted_gender == "" and set_gender == "male":
			if chosen.is_empty():
				chosen = row
	if chosen.is_empty():
		chosen = first_of_variant
	if chosen.is_empty():
		base["status"] = "no_set_for_mode"
		return base
	var block_axis: String = str(chosen.get("block_axis", ""))
	var gender_used: String = str(chosen.get("set_gender", ""))
	if block_axis == "gender":
		gender_used = wanted_gender if wanted_gender != "" else "male"
	base["status"] = "resolved"
	base["set"] = str(chosen.get("set", ""))
	base["variant"] = variant
	base["gender_used"] = gender_used
	base["block_axis"] = block_axis
	base["frame_dir"] = str(chosen.get("frame_dir", ""))
	if block_axis == "gender":
		base["block_base_row"] = 4 if gender_used == "female" else 0
	return base


## The 1-based sheet row a resolved display uses for one
## facing (block base + the facing's offset + 1). flash selects
## the Flash block on flash-axis sets; it is ignored on
## gender-axis sets. -1 when the resolution did not resolve or
## the facing is unknown.
static func row_for_facing(resolution: Dictionary, facing: String, flash: bool = false) -> int:
	if str(resolution.get("status", "")) != "resolved":
		return -1
	if not FACING_ROW_OFFSET.has(facing):
		return -1
	var base_row: int = int(resolution.get("block_base_row", 0))
	if str(resolution.get("block_axis", "")) == "flash" and flash:
		base_row = 4
	return base_row + int(FACING_ROW_OFFSET[facing]) + 1


## The res:// path of one frame PNG in a resolved set.
static func frame_path(resolution: Dictionary, row: int, column: int) -> String:
	return "%s/%s_r%dc%d.png" % [str(resolution.get("frame_dir", "")), str(resolution.get("set", "")), row, column]


# ------------------------------------------------------------------
# Frame building
# ------------------------------------------------------------------

## Build the mount SpriteFrames for one ride. Returns the
## bike/cast loader shape plus the resolution record:
## {"frames": SpriteFrames or null, "status": "loaded" |
## "not_bound" | "no_set_for_mode" | "no_frames",
## "frame_count" (unique frame textures loaded), "set",
## "species", "mode", "context", "variant", "gender_used",
## "block_axis", "flash_applied", "missing_path" (first
## missing PNG when status is "no_frames")}.
## All-or-nothing per set, like PUWCastRigLoader: if any of
## the 16 cycle frames is missing, nothing is built.
static func build_mount_frames(species_ref: String, mode_id: String, gender: String = "", flash: bool = false) -> Dictionary:
	var resolution: Dictionary = resolve_set(species_ref, mode_id, gender)
	var result: Dictionary = {
		"frames": null,
		"status": str(resolution.get("status", "")),
		"frame_count": 0,
		"set": str(resolution.get("set", "")),
		"species": str(resolution.get("species", "")),
		"mode": mode_id,
		"context": str(resolution.get("context", "")),
		"variant": str(resolution.get("variant", "")),
		"gender_used": str(resolution.get("gender_used", "")),
		"block_axis": str(resolution.get("block_axis", "")),
		"flash_applied": false,
		"missing_path": "",
	}
	if str(resolution.get("status", "")) != "resolved":
		return result
	var flash_applied: bool = flash and str(resolution.get("block_axis", "")) == "flash"
	result["flash_applied"] = flash_applied
	# Load the 16 cycle textures (4 facings x 4 columns).
	var textures_by_facing: Dictionary = {}
	var unique_count: int = 0
	for facing_value: Variant in FACINGS:
		var facing: String = str(facing_value)
		var row: int = row_for_facing(resolution, facing, flash)
		var cycle: Array = []
		for column_value: Variant in CYCLE_COLUMNS:
			var column: int = int(column_value)
			var path: String = frame_path(resolution, row, column)
			if not ResourceLoader.exists(path):
				result["status"] = "no_frames"
				result["missing_path"] = path
				return result
			var texture: Texture2D = load(path) as Texture2D
			if texture == null:
				result["status"] = "no_frames"
				result["missing_path"] = path
				return result
			cycle.append(texture)
			unique_count += 1
		textures_by_facing[facing] = cycle
	var frames: SpriteFrames = SpriteFrames.new()
	for facing_value: Variant in FACINGS:
		var facing: String = str(facing_value)
		var cycle: Array = textures_by_facing[facing]
		var idle_anim: String = "idle_" + facing
		frames.add_animation(idle_anim)
		frames.set_animation_loop(idle_anim, true)
		frames.set_animation_speed(idle_anim, IDLE_FPS)
		frames.add_frame(idle_anim, cycle[IDLE_COLUMN - 1])
		var walk_anim: String = "walk_" + facing
		frames.add_animation(walk_anim)
		frames.set_animation_loop(walk_anim, true)
		frames.set_animation_speed(walk_anim, WALK_FPS)
		for texture_value: Variant in cycle:
			var texture: Texture2D = texture_value
			frames.add_frame(walk_anim, texture)
		var run_anim: String = "run_" + facing
		frames.add_animation(run_anim)
		frames.set_animation_loop(run_anim, true)
		frames.set_animation_speed(run_anim, RUN_FPS)
		for texture_value: Variant in cycle:
			var texture: Texture2D = texture_value
			frames.add_frame(run_anim, texture)
	result["frames"] = frames
	result["status"] = "loaded"
	result["frame_count"] = unique_count
	return result
