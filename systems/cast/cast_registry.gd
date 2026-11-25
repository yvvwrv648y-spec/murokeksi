class_name PUWCastRegistry
extends RefCounted
## Cast registry for Pokemon Ultimate World: who the playable cast
## is, which Neon sprite sheet serves each cast member in each
## animation state, where each protagonist spawns, and which
## identities / body presets the character creator accepts.
##
## Data only. The sheet paths in systems/cast/cast_sheets.json are
## Neon repo-relative paths from the custom work register manifest.
## The art itself lives in Neon's repo (forwarded as the
## PUW_NEON_CHARACTERS / PUW_NEON_TANDEM_BIKES art zips); this
## registry ships NO art, so every sheet answer carries the status
## "waits_on_neon_art_merge" until those sheets are merged.
## PUWCastRigLoader turns a merged sheet into SpriteFrames without
## any change to this registry.
##
## Identity / preset validation reuses the data already encoded in
## the project: PUWCharacterSetup (canon display-name identities)
## and ProtagonistCanon (schema snake-case identities, transcribed
## from characters/protagonists/custom/character_creator_schema.json).

const SHEETS_PATH: String = "res://systems/cast/cast_sheets.json"
const RIDER_POSES_PATH: String = "res://systems/cast/rider_poses.json"
const CANON_PATH: String = "res://characters/protagonist_canon.json"
const PALLET_TOWN_PATH: String = "res://maps/data/maps/PalletTown.json"

const ART_STATUS: String = "waits_on_neon_art_merge"

const CAST_IDS: Array = [
	"riley",
	"tasha",
	"custom_female",
	"custom_male",
	"custom_femboy",
	"custom_futanari",
]

const STATES: Array = [
	"idle",
	"walk",
	"run",
	"bike_solo",
	"swim",
	"battle",
	"tandem_driver",
	"tandem_passenger",
]

## Rider poses for rideable Pokemon (Phase 3, item B): a SEPARATE
## registry namespace from STATES above -- rider poses are NOT cast
## animation states and must never be added to STATES (the cast
## animation baseline depends on STATES staying exactly as it is).
## The full taxonomy (descriptions, frame counts/roles, ride-mode
## mapping, per-mode anchor rules) lives in
## systems/cast/rider_poses.json. QA integration 2026-11-22:
## Neon's ride sheets arrived and were visually graded; the
## accepted primary figures were sliced (rider_frame_data.json),
## so most poses are now "bound" per cast member -- the generic
## set records its truth per cast in art_status_by_cast because
## the four Custom presets differ on the climb poses. Poses with
## no accepted frame stay ART_PENDING and PUWCastRigLoader reports
## art_pending with zero frames for them rather than substituting
## art.
const RIDER_POSE_ART_STATUS: String = "art_pending"

const RIDER_POSES: Array = [
	"ride_land_seated",
	"ride_land_gallop",
	"surf_stand",
	"surf_kneel",
	"ferry_seated",
	"fly_seated",
	"fly_carried",
	"dive_hold",
	"climb_cling",
	"climb_stand",
	"hover_stand",
	"carry_held",
	"burrow_crouch",
]

## Rider pose SETS (refinement 2026-11-22 14:59 CST): poses are
## recorded PER SET in rider_poses.json. "riley" and "tasha" are
## custom personality sets (the 13 base poses with their own
## descriptions, plus one signature extra each); "generic" is the
## neutral set shared by the four Custom presets, with NO extras.
## Rig resolution: riley -> "riley", tasha -> "tasha", every
## custom_* -> "generic" (see pose_set_for_cast).
const RIDER_POSE_SET_IDS: Array = ["riley", "tasha", "generic"]

## Signature extra states, set-scoped ONLY (never mode primaries):
## mount_wave belongs to the riley set (tied to land riding,
## mounted idle); hover_descend belongs to the tasha set (tied to
## hover-carrying, arrival). They are NOT part of the 13-pose base
## taxonomy above.
const RIDER_EXTRA_POSES: Array = ["mount_wave", "hover_descend"]

## The four Custom body presets from the character creator schema:
## the four identities that carry their own master/casual/swim/
## battle sheets and cast entries. Written in the schema's own
## snake-case spelling (character_creator_schema.json "identities").
const BODY_PRESETS: Array = ["female", "male", "femboy", "futanari"]

## Custom protagonist spawn basis, documented honestly: canon
## (characters/protagonist_canon.json) puts the Custom house at
## Pallet Town's bottom-right, but the sourced Gen 1 Pallet Town
## map data has only two houses (Red's and Blue's) plus Oak's Lab
## and exactly three warps -- there is NO Custom house interior
## map and NO Custom house door warp cell in the sourced data.
## The spawn therefore uses Pallet Town's own documented default
## exterior spawn cell (11, 15): the cell the legacy project
## (legacy_v031/scripts/main.gd, last_spawn) and the v1 save
## migration default in core/save_manager.gd both use for
## kanto_pallet_town.
const CUSTOM_SPAWN_CELL: Vector2i = Vector2i(11, 15)
const CUSTOM_SPAWN_BASIS: String = "canon_custom_house_bottom_right_has_no_interior_map_or_door_warp_in_sourced_gen1_pallet_town_data; using pallet_town_default_exterior_spawn_cell_from_legacy_main_and_save_v1_migration"


static func load_json(path: String) -> Dictionary:
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


static func sheets_data() -> Dictionary:
	return load_json(SHEETS_PATH)


static func cast_ids() -> Array:
	return CAST_IDS.duplicate()


static func states() -> Array:
	return STATES.duplicate()


static func is_cast_id(cast_id: String) -> bool:
	return CAST_IDS.has(cast_id)


## The protagonist id a cast member plays as in story data:
## riley -> "riley", tasha -> "tasha", every custom_* -> "custom".
static func protagonist_for_cast(cast_id: String) -> String:
	if cast_id == "riley":
		return "riley"
	if cast_id == "tasha":
		return "tasha"
	if cast_id.begins_with("custom_"):
		return "custom"
	return ""


## Resolve the sheet(s) for one cast member in one state.
## Returns {path, paths, status}. path is the first sheet ("" when
## the pairing has no named sheet, e.g. custom x custom tandem).
## status is always ART_STATUS: the sheets live in Neon's repo and
## no art ships with this registry.
static func sheet_for(cast_id: String, state: String) -> Dictionary:
	var data: Dictionary = sheets_data()
	var cast: Dictionary = data.get("cast", {})
	var entry: Dictionary = cast.get(cast_id, {})
	var sheets: Dictionary = entry.get("sheets", {})
	var paths: Array = sheets.get(state, [])
	var first: String = ""
	if not paths.is_empty():
		first = str(paths[0])
	return {"path": first, "paths": paths.duplicate(), "status": ART_STATUS}


## Frame layout data for a sheet path (frame_count / layout), used
## by PUWCastRigLoader when the real sheet file is merged.
static func frame_data_for(cast_id: String, sheet_path: String) -> Dictionary:
	var data: Dictionary = sheets_data()
	var cast: Dictionary = data.get("cast", {})
	var entry: Dictionary = cast.get(cast_id, {})
	var frame_data: Dictionary = entry.get("frame_data", {})
	var fd: Dictionary = frame_data.get(sheet_path, {})
	return fd


## Spawn for a protagonist, from canon + the sourced Pallet Town
## map data. Riley -> REDS_HOUSE_1F and Tasha -> BLUES_HOUSE via
## the actual warp entries in maps/data/maps/PalletTown.json
## (looked up by dest_map, not hardcoded coordinates). Custom ->
## the documented Pallet Town exterior spawn (see
## CUSTOM_SPAWN_BASIS).
static func spawn_for_protagonist(cast_id: String) -> Dictionary:
	if cast_id == "riley" or cast_id == "tasha":
		var dest: String = "REDS_HOUSE_1F" if cast_id == "riley" else "BLUES_HOUSE"
		var pallet: Dictionary = load_json(PALLET_TOWN_PATH)
		var warps: Array = pallet.get("warps", [])
		for i: int in range(warps.size()):
			var w: Dictionary = warps[i]
			if str(w.get("dest_map", "")) == dest:
				return {
					"map_id_const": dest,
					"kind": "house_interior",
					"via_map_id_const": str(pallet.get("id_const", "PALLET_TOWN")),
					"warp_index": i + 1,
					"warp_cell": [int(w.get("x", 0)), int(w.get("y", 0))],
					"basis": "protagonist_canon_house + PalletTown.json warp dest_map",
				}
		return {"map_id_const": dest, "kind": "house_interior", "basis": "protagonist_canon_house; warp not found in PalletTown.json"}
	if cast_id.begins_with("custom_"):
		return {
			"map_id_const": "PALLET_TOWN",
			"kind": "exterior_cell",
			"cell": [CUSTOM_SPAWN_CELL.x, CUSTOM_SPAWN_CELL.y],
			"basis": CUSTOM_SPAWN_BASIS,
		}
	return {}


## Canon record for a protagonist id ("riley" / "tasha" /
## "custom") from characters/protagonist_canon.json.
static func canon_for(protagonist_id: String) -> Dictionary:
	var canon: Dictionary = load_json(CANON_PATH)
	var protagonists: Array = canon.get("protagonists", [])
	for entry_value: Variant in protagonists:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == protagonist_id:
			return entry
	return {}


## Identity validation against BOTH encodings already in the
## project: PUWCharacterSetup's canon display names ("Femboy")
## and ProtagonistCanon's schema snake-case ids ("femboy").
static func valid_identity(identity: String) -> bool:
	if PUWCharacterSetup.identity_options().has(identity):
		return true
	return ProtagonistCanon.IDENTITY_OPTIONS.has(identity)


## Body preset validation: the four Custom body presets from the
## character creator schema.
static func valid_preset(preset: String) -> bool:
	return BODY_PRESETS.has(preset)


static func body_presets() -> Array:
	return BODY_PRESETS.duplicate()


## ------------------------------------------------------------------
## Rider poses (separate namespace; see RIDER_POSES note above).
## All data comes from systems/cast/rider_poses.json, loaded through
## the same load_json path as the sheets data.
## ------------------------------------------------------------------

static func rider_poses_data() -> Dictionary:
	return load_json(RIDER_POSES_PATH)


## The 13 base rider pose ids, in taxonomy order (shared by all
## three pose sets; the set-scoped extras are separate, see
## RIDER_EXTRA_POSES).
static func rider_pose_ids() -> Array:
	return RIDER_POSES.duplicate()


## True when pose_id is registered in ANY pose set: one of the 13
## base poses, or one of the two set-scoped signature extras.
static func is_rider_pose(pose_id: String) -> bool:
	return RIDER_POSES.has(pose_id) or RIDER_EXTRA_POSES.has(pose_id)


## The pose set a cast member resolves to: riley -> "riley",
## tasha -> "tasha", every custom_* cast id -> "generic",
## "" for an unknown cast id.
static func pose_set_for_cast(cast_id: String) -> String:
	if cast_id == "riley":
		return "riley"
	if cast_id == "tasha":
		return "tasha"
	if cast_id.begins_with("custom_") and is_cast_id(cast_id):
		return "generic"
	return ""


static func rider_pose_set_ids() -> Array:
	return RIDER_POSE_SET_IDS.duplicate()


## The rider_poses.json "sets" record for one set id, or {}.
static func rider_pose_set_record(set_id: String) -> Dictionary:
	var data: Dictionary = rider_poses_data()
	var sets: Dictionary = data.get("sets", {})
	var set_rec: Dictionary = sets.get(set_id, {})
	return set_rec


## Pose ids of one set, in set order: 14 for riley (13 base +
## mount_wave), 14 for tasha (13 base + hover_descend), 13 for
## generic (base only). [] for an unknown set.
static func rider_pose_ids_for_set(set_id: String) -> Array:
	var set_rec: Dictionary = rider_pose_set_record(set_id)
	var poses: Array = set_rec.get("poses", [])
	var ids: Array = []
	for pose_value: Variant in poses:
		var pose_rec: Dictionary = pose_value
		ids.append(str(pose_rec.get("id", "")))
	return ids


## Pose ids of the set one cast member resolves to.
static func rider_pose_ids_for_cast(cast_id: String) -> Array:
	return rider_pose_ids_for_set(pose_set_for_cast(cast_id))


## True when pose_id is a member of one specific set.
static func rider_pose_in_set(set_id: String, pose_id: String) -> bool:
	return rider_pose_ids_for_set(set_id).has(pose_id)


## The pose record for one pose IN one set (descriptions are
## per-set: the same pose id carries different personality text in
## each set), or {} when the pose is not in that set.
static func rider_pose_record_for_set(set_id: String, pose_id: String) -> Dictionary:
	var set_rec: Dictionary = rider_pose_set_record(set_id)
	var poses: Array = set_rec.get("poses", [])
	for pose_value: Variant in poses:
		var pose_rec: Dictionary = pose_value
		if str(pose_rec.get("id", "")) == pose_id:
			return pose_rec
	return {}


## The pose record for one pose in the set a cast member resolves
## to, or {} when that cast member's set does not carry the pose.
static func rider_pose_record_for_cast(cast_id: String, pose_id: String) -> Dictionary:
	return rider_pose_record_for_set(pose_set_for_cast(cast_id), pose_id)


## The per-set description text for one pose in one set, or "".
static func rider_pose_description_for_set(set_id: String, pose_id: String) -> String:
	var pose_rec: Dictionary = rider_pose_record_for_set(set_id, pose_id)
	return str(pose_rec.get("description", ""))


## A record for one pose from the first set that carries it (the
## generic set for base poses). Frame counts and roles agree
## across sets for base poses; descriptions do NOT -- use
## rider_pose_record_for_set / _for_cast for description text.
static func rider_pose_record(pose_id: String) -> Dictionary:
	for set_value: Variant in ["generic", "riley", "tasha"]:
		var set_id: String = str(set_value)
		var pose_rec: Dictionary = rider_pose_record_for_set(set_id, pose_id)
		if not pose_rec.is_empty():
			return pose_rec
	return {}


## Ride mode ids from rider_poses.json, in table order (11 rows:
## climbing appears twice, as climbing_cliff and
## climbing_waterfall).
static func ride_mode_ids() -> Array:
	var data: Dictionary = rider_poses_data()
	var modes: Array = data.get("ride_modes", [])
	var ids: Array = []
	for mode_value: Variant in modes:
		var mode_rec: Dictionary = mode_value
		ids.append(str(mode_rec.get("id", "")))
	return ids


## The rider_poses.json record for one ride mode, or {}.
static func ride_mode_record(mode_id: String) -> Dictionary:
	var data: Dictionary = rider_poses_data()
	var modes: Array = data.get("ride_modes", [])
	for mode_value: Variant in modes:
		var mode_rec: Dictionary = mode_value
		if str(mode_rec.get("id", "")) == mode_id:
			return mode_rec
	return {}


## All poses serving one ride mode, as the stored entries:
## [{pose_id, role, condition}, ...] with the primary first.
static func poses_for_mode(mode_id: String) -> Array:
	var mode_rec: Dictionary = ride_mode_record(mode_id)
	var poses: Array = mode_rec.get("poses", [])
	return poses.duplicate()


## The primary pose id for one ride mode, or "" for an unknown mode.
static func pose_for_mode(mode_id: String) -> String:
	var entries: Array = poses_for_mode(mode_id)
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		if str(entry.get("role", "")) == "primary":
			return str(entry.get("pose_id", ""))
	if not entries.is_empty():
		var first: Dictionary = entries[0]
		return str(first.get("pose_id", ""))
	return ""


## The per-mode anchor rule: {rider_anchor, pokemon_anchor, offset
## ([x, y] normalized fractions of the Pokemon sprite frame),
## facing, z_order}. {} for an unknown mode.
static func anchor_rule_for_mode(mode_id: String) -> Dictionary:
	var mode_rec: Dictionary = ride_mode_record(mode_id)
	var rule: Dictionary = mode_rec.get("anchor_rule", {})
	return rule


## Frames the finished art for a pose must supply (2 for
## ride_land_gallop / fly_seated / hover_stand in EVERY set, and
## for the set-scoped extras mount_wave / hover_descend; 1 for
## the other base poses), or 0 for an unregistered pose.
static func frames_expected(pose_id: String) -> int:
	var pose_rec: Dictionary = rider_pose_record(pose_id)
	return int(pose_rec.get("frames_expected", 0))


## Frame roles for a pose: ["calm", "wind"] for the two-frame
## base poses, ["idle", "wave"] for mount_wave, ["high",
## "touching_down"] for hover_descend, ["hold"] for the one-frame
## poses, [] when unregistered.
static func frame_roles_for_pose(pose_id: String) -> Array:
	var pose_rec: Dictionary = rider_pose_record(pose_id)
	var roles: Array = pose_rec.get("frame_roles", [])
	return roles.duplicate()


## Art status for a pose from the first set record that carries
## it (the generic set for base poses): "bound", "art_pending", or
## "partial_by_cast" for a generic pose whose four Custom presets
## differ, "" for an unregistered pose. For a per-cast answer use
## rider_pose_art_status_for_cast -- the generic summary cannot
## speak for an individual Custom preset.
static func rider_pose_art_status(pose_id: String) -> String:
	if not is_rider_pose(pose_id):
		return ""
	var pose_rec: Dictionary = rider_pose_record(pose_id)
	return str(pose_rec.get("art_status", RIDER_POSE_ART_STATUS))


## Art status for one pose for ONE cast member: the cast member's
## own set record, honoring the generic set's art_status_by_cast
## map (climb_cling is bound for custom_femboy but art_pending for
## the other presets). "" when the pose is not in the cast
## member's set.
static func rider_pose_art_status_for_cast(cast_id: String, pose_id: String) -> String:
	var pose_rec: Dictionary = rider_pose_record_for_cast(cast_id, pose_id)
	if pose_rec.is_empty():
		return ""
	var by_cast: Dictionary = pose_rec.get("art_status_by_cast", {})
	if by_cast.has(cast_id):
		return str(by_cast[cast_id])
	return str(pose_rec.get("art_status", RIDER_POSE_ART_STATUS))
