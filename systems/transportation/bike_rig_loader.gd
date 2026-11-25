class_name PUWBikeRigLoader
extends RefCounted
## Builds SpriteFrames for solo and tandem bicycle riding from the
## sliced frame PNGs (art_frames/systems/transportation/<sheet>/fNN.png)
## described by systems/transportation/bike_frame_data.json, which was
## produced by tools/slice_bike_frames.py from the derived sheet grids.
##
## Status is "loaded" only when real frame PNGs exist and load. Hero
## panels are never part of a ride cycle (the bike_* heroes are an
## UNOCCUPIED tandem bicycle; other heroes are double-scale stills).
## This loader does NOT enforce the tandem co-op lock -- that rule
## lives in PUWBikes.tandem_available() and is applied by
## PUWBikeRigFacade; this class is the pure art layer.

const DATA_PATH: String = "res://systems/transportation/bike_frame_data.json"
const ANIM_RIDE: String = "ride"


static func _load_data() -> Dictionary:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func ride_fps() -> float:
	var data: Dictionary = _load_data()
	return float(data.get("ride_fps", 11.0))


static func _frames_for(sheet: String, indices: Array) -> Dictionary:
	var data: Dictionary = _load_data()
	var sheets: Dictionary = data.get("sheets", {})
	var sheet_entry: Dictionary = sheets.get(sheet, {})
	var all_frames: Array = sheet_entry.get("frames", [])
	var by_index: Dictionary = {}
	for frame_value: Variant in all_frames:
		var frame_entry: Dictionary = frame_value
		by_index[int(frame_entry.get("index", -1))] = frame_entry
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(ANIM_RIDE)
	frames.set_animation_loop(ANIM_RIDE, true)
	frames.set_animation_speed(ANIM_RIDE, ride_fps())
	var count: int = 0
	for index_value: Variant in indices:
		var idx: int = int(index_value)
		var frame_entry: Dictionary = by_index.get(idx, {})
		var png: String = str(frame_entry.get("png", ""))
		if png == "":
			continue
		var path: String = "res://" + png
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		frames.add_frame(ANIM_RIDE, texture)
		count += 1
	if count == 0:
		return {"frames": null, "status": "no_frames", "frame_count": 0, "sheet": sheet}
	return {"frames": frames, "status": "loaded", "frame_count": count, "sheet": sheet}


## Solo ride frames for one cast member, from the per-cast solo
## resolution table in bike_frame_data.json.
static func build_solo_frames(cast_id: String) -> Dictionary:
	var data: Dictionary = _load_data()
	var solo: Dictionary = data.get("solo_resolution", {})
	var entry: Dictionary = solo.get(cast_id, {})
	if entry.is_empty():
		return {"frames": null, "status": "unknown_cast", "frame_count": 0, "sheet": ""}
	var indices: Array = entry.get("frame_indices", [])
	return _frames_for(str(entry.get("sheet", "")), indices)


## Tandem ride frames for a (driver, passenger) pairing named in
## cast_sheets.json. The frame is the full two-rider pose component;
## riders are never split into separate sprites.
static func build_tandem_frames(driver_id: String, passenger_id: String) -> Dictionary:
	var data: Dictionary = _load_data()
	var tandem: Dictionary = data.get("tandem_resolution", {})
	var key: String = driver_id + ">" + passenger_id
	var entry: Dictionary = tandem.get(key, {})
	if entry.is_empty():
		return {"frames": null, "status": "unnamed_pairing", "frame_count": 0, "sheet": ""}
	var indices: Array = entry.get("frame_indices", [])
	return _frames_for(str(entry.get("sheet", "")), indices)


## All tandem pairing keys ("driver>passenger") with named sheets.
static func tandem_pairings() -> Array:
	var data: Dictionary = _load_data()
	var tandem: Dictionary = data.get("tandem_resolution", {})
	var keys: Array = tandem.keys()
	keys.sort()
	return keys
