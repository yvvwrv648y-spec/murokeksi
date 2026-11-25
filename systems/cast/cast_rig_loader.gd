class_name PUWCastRigLoader
extends RefCounted
## Builds SpriteFrames for one cast member / state from the SLICED
## frame PNGs produced by tools/slice_cast_frames.py, driven by
## systems/cast/frame_data.json (Bossy-derived 2026-11-22 from
## art_analysis/sheet_grids.json -- Neon defined no sheet layout spec).
##
## The raw sheets sit on a magenta chroma key, so AtlasTexture strips
## of the JPGs are unusable; the slicer chroma-keys each measured
## content bbox, foot-anchor aligns it on a uniform per-sheet canvas,
## and writes transparent PNGs under res://art_frames/. This loader
## only ever loads those real frame PNGs: status is "loaded" only
## when every frame PNG for the resolved (cast, state) exists, and
## PUWCastRegistry.ART_STATUS otherwise. It never invents,
## substitutes, or placeholder-renders art.
##
## Frame-to-state mapping (full reasoning in SHEET_GRID_SPEC.md):
## the 6 anim_*_8frame_sheet.jpg sheets are one 8-frame trainer
## action sequence (stance, ball throw, crouch, neutral stand,
## victory) -- NOT a directional set and NOT a true locomotion
## cycle. walk and run use the full sequence at their CLIP_FPS
## rates, idle uses frame 6 (the neutral standing frame in every
## sheet), swim uses the swim sheets' small poses at the walk rate
## (CLIP_FPS defines no SWIM rate), and battle is the single
## *_battle.png pose (static).
## bike_solo / tandem_* states have no frame_data resolution yet:
## their sheets live under systems/transportation and are owned by
## the bikes build, so those states report ART_STATUS here.
##
## Directional walk (QA integration 2026-11-22): the layered walk
## pilot (body + outfit sheets, visually graded in
## qa/qa_walk_pilot.md) adds per-facing clips walk_down / walk_up /
## walk_left / walk_right in frame_data.json cast_states, built
## from the composited pilot frames at the walk rate. Riley carries
## all four directions; Tasha carries walk_down / walk_up /
## walk_right ONLY -- her pilot left row was rejected (5 of 8
## frames face right in both sheets), so tasha walk_left is NOT
## bound and is never mirrored or fabricated; her bare "walk"
## fallback stays as it was until Neon redoes the left row.
##
## Directional walk + run (QA round 2, 2026-11-22): Neon's layered
## run cycles (all six cast) and Custom-preset walk cycles were
## graded frame by frame (verdicts in qa_round2/). Bound today:
## riley run_* all four directions (clean sweep); the four Custom
## presets' walk_* as graded (custom_female and custom_femboy all
## four; custom_male down/up only -- side rows flip direction
## mid-row; custom_futanari up/left/right -- her outfit front row
## covers the mouth/chin, so walk_down stays unbound); run_up ONLY
## for the four Custom presets (their other run rows fail on eye
## flicker, wrong-facing frames, or feet on the cell edge); and NO
## tasha run direction (the set failed grading outright). Unbound
## directions simply have no cast_states entry: build_frames
## reports ART_STATUS with 0 frames, never a substitute.

const FRAME_DATA_PATH: String = "res://systems/cast/frame_data.json"
const RIDER_FRAME_DATA_PATH: String = "res://systems/cast/rider_frame_data.json"
const WARDROBE_REGISTRY_PATH: String = "res://systems/cast/wardrobe_registry.json"
const RIG_ROOT: String = "res://"

## Playback rates from characters/animations/actor_state_machine.gd
## CLIP_FPS: idle 4.0, walk 7.5, run 11.0. CLIP_FPS defines no SWIM
## rate, so swim uses the walk rate; battle is a static pose state
## (loop off; the 1.0 speed is never visibly played).
const CLIP_FPS: Dictionary = {
	"idle": 4.0,
	"walk": 7.5,
	"walk_down": 7.5,
	"walk_up": 7.5,
	"walk_left": 7.5,
	"walk_right": 7.5,
	"run": 11.0,
	"run_down": 11.0,
	"run_up": 11.0,
	"run_left": 11.0,
	"run_right": 11.0,
	"swim": 7.5,
	"battle": 1.0,
}

const LOOP_STATES: Array = ["idle", "walk", "walk_down", "walk_up", "walk_left", "walk_right", "run", "run_down", "run_up", "run_left", "run_right", "swim"]

## Rider pose playback: hold poses are static (loop off); the
## two-frame calm/wind pairs loop slowly so the wind frame reads.
const RIDER_FPS: float = 4.0


static func _frame_data() -> Dictionary:
	return PUWCastRegistry.load_json(FRAME_DATA_PATH)


## The frame PNG path (res://) for one sheet + frame index, or ""
## when frame_data.json has no such frame.
static func frame_png_for(sheet_path: String, frame_index: int) -> String:
	var data: Dictionary = _frame_data()
	var sheets: Dictionary = data.get("sheets", {})
	var sheet_rec: Dictionary = sheets.get(sheet_path, {})
	var frames: Array = sheet_rec.get("frames", [])
	for frame_value: Variant in frames:
		var frame_rec: Dictionary = frame_value
		if int(frame_rec.get("index", -1)) == frame_index:
			return str(frame_rec.get("png", ""))
	return ""


## True when the registry sheet file for this cast/state is present
## in the project. (build_frames is stricter: it needs the sliced
## frame PNGs, see below.)
static func sheet_available(cast_id: String, state: String) -> bool:
	var resolved: Dictionary = PUWCastRegistry.sheet_for(cast_id, state)
	var path: String = str(resolved.get("path", ""))
	if path == "":
		return false
	return ResourceLoader.exists(RIG_ROOT + path)


## True when sliced frame PNGs exist for this cast/state, i.e.
## build_frames will return status "loaded".
static func frames_available(cast_id: String, state: String) -> bool:
	var data: Dictionary = _frame_data()
	var cast_states: Dictionary = data.get("cast_states", {})
	var entry: Dictionary = cast_states.get(cast_id, {})
	var state_rec: Dictionary = entry.get(state, {})
	if state_rec.is_empty():
		return false
	var sheet_path: String = str(state_rec.get("sheet", ""))
	var indices: Array = state_rec.get("frames", [])
	if indices.is_empty():
		return false
	for index_value: Variant in indices:
		var png: String = frame_png_for(sheet_path, int(index_value))
		if png == "" or not ResourceLoader.exists(png):
			return false
	return true


## Build SpriteFrames for one cast member in one state from the
## sliced frame PNGs listed in frame_data.json.
## Returns {frames: SpriteFrames or null, status, frame_count}.
static func build_frames(cast_id: String, state: String) -> Dictionary:
	var data: Dictionary = _frame_data()
	var cast_states: Dictionary = data.get("cast_states", {})
	var entry: Dictionary = cast_states.get(cast_id, {})
	var state_rec: Dictionary = entry.get(state, {})
	if state_rec.is_empty():
		return {"frames": null, "status": PUWCastRegistry.ART_STATUS, "frame_count": 0}
	var sheet_path: String = str(state_rec.get("sheet", ""))
	var indices: Array = state_rec.get("frames", [])
	if sheet_path == "" or indices.is_empty():
		return {"frames": null, "status": PUWCastRegistry.ART_STATUS, "frame_count": 0}
	var textures: Array = []
	for index_value: Variant in indices:
		var png: String = frame_png_for(sheet_path, int(index_value))
		if png == "" or not ResourceLoader.exists(png):
			return {"frames": null, "status": PUWCastRegistry.ART_STATUS, "frame_count": 0}
		var texture: Texture2D = load(png) as Texture2D
		if texture == null:
			return {"frames": null, "status": PUWCastRegistry.ART_STATUS, "frame_count": 0}
		textures.append(texture)
	var fps: float = float(state_rec.get("fps", float(CLIP_FPS.get(state, 7.5))))
	var loops: bool = bool(state_rec.get("loop", LOOP_STATES.has(state)))
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(state)
	frames.set_animation_loop(state, loops)
	frames.set_animation_speed(state, fps)
	for texture_value: Variant in textures:
		var texture: Texture2D = texture_value
		frames.add_frame(state, texture)
	return {"frames": frames, "status": "loaded", "frame_count": textures.size()}


## Coverage report: for every cast member x state, whether the
## registry sheet is merged in the project. Used by tests and the
## merge checklist; a state with zero frames is an open item, never
## silently filled. (frames_available() is the stricter sliced-PNG
## check.)
static func coverage() -> Dictionary:
	var report: Dictionary = {}
	for cast_value: Variant in PUWCastRegistry.cast_ids():
		var cast_id: String = str(cast_value)
		var states_report: Dictionary = {}
		for state_value: Variant in PUWCastRegistry.states():
			var state: String = str(state_value)
			states_report[state] = sheet_available(cast_id, state)
		report[cast_id] = states_report
	return report


## ------------------------------------------------------------------
## Rider poses (Phase 3, item B; QA integration 2026-11-22). Rider
## poses are registered by name in PUWCastRegistry.RIDER_POSES /
## rider_poses.json. Neon's ride sheets (v1 + v2) were visually
## graded and ONLY the accepted primary figures were sliced (see
## systems/cast/rider_frame_data.json and tools/slice_qa_art.py):
## a pose whose rider_poses.json record for this cast member is
## "bound" AND which has sliced frames in rider_frame_data.json
## builds a real SpriteFrames and reports "bound". Poses with no
## accepted frame still report "art_pending" with ZERO frames.
## This section never fabricates a frame and never substitutes
## another state's art for a rider pose.
## ------------------------------------------------------------------

static func _rider_frame_data() -> Dictionary:
	return PUWCastRegistry.load_json(RIDER_FRAME_DATA_PATH)


## The sliced rider frame records for one cast member + pose from
## rider_frame_data.json ([] when none were sliced).
static func rider_frame_records(cast_id: String, pose_id: String) -> Array:
	var data: Dictionary = _rider_frame_data()
	var cast_map: Dictionary = data.get("cast", {})
	var poses: Dictionary = cast_map.get(cast_id, {})
	var pose_rec: Dictionary = poses.get(pose_id, {})
	var frames: Array = pose_rec.get("frames", [])
	return frames.duplicate()

## True when pose_id is registered in ANY rider pose set (one of
## the 13 base poses, or a set-scoped signature extra).
static func rider_pose_registered(pose_id: String) -> bool:
	return PUWCastRegistry.is_rider_pose(pose_id)


## True when pose_id belongs to the pose set this cast member
## resolves to (riley -> riley set, tasha -> tasha set, custom_*
## -> generic set). This is the set-aware registration check:
## mount_wave is registered for riley but NOT for tasha.
static func rider_pose_registered_for(cast_id: String, pose_id: String) -> bool:
	var set_id: String = PUWCastRegistry.pose_set_for_cast(cast_id)
	if set_id == "":
		return false
	return PUWCastRegistry.rider_pose_in_set(set_id, pose_id)


## Build frames for one cast member in one rider pose. The cast
## member's pose set is resolved first: a pose that is registered
## but not in that cast member's set returns status "not_in_set"
## with 0 frames; an unknown cast id or pose reports its own
## status, still with zero frames. A pose in the set returns
## status "bound" with a real SpriteFrames when rider_poses.json
## records it bound for this cast member AND rider_frame_data.json
## holds sliced frames whose PNGs all exist; otherwise it returns
## status "art_pending" with 0 frames. Partial poses (riley
## mount_wave, tasha hover_descend) are bound with the frames that
## exist (1 of 2); the missing frame is recorded in rider_poses.json.
static func build_rider_frames(cast_id: String, pose_id: String) -> Dictionary:
	if not PUWCastRegistry.is_cast_id(cast_id):
		return {"frames": null, "status": "unknown_cast", "frame_count": 0, "pose_set": ""}
	if not rider_pose_registered(pose_id):
		return {"frames": null, "status": "unknown_rider_pose", "frame_count": 0, "pose_set": PUWCastRegistry.pose_set_for_cast(cast_id)}
	if not rider_pose_registered_for(cast_id, pose_id):
		return {"frames": null, "status": "not_in_set", "frame_count": 0, "pose_set": PUWCastRegistry.pose_set_for_cast(cast_id)}
	var pending: Dictionary = {
		"frames": null,
		"status": PUWCastRegistry.RIDER_POSE_ART_STATUS,
		"frame_count": 0,
		"frames_expected": PUWCastRegistry.frames_expected(pose_id),
		"pose_set": PUWCastRegistry.pose_set_for_cast(cast_id),
	}
	if PUWCastRegistry.rider_pose_art_status_for_cast(cast_id, pose_id) != "bound":
		return pending
	var records: Array = rider_frame_records(cast_id, pose_id)
	if records.is_empty():
		return pending
	var textures: Array = []
	for record_value: Variant in records:
		var record: Dictionary = record_value
		var png: String = str(record.get("png", ""))
		if png == "" or not ResourceLoader.exists(png):
			return pending
		var texture: Texture2D = load(png) as Texture2D
		if texture == null:
			return pending
		textures.append(texture)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(pose_id)
	frames.set_animation_loop(pose_id, textures.size() > 1)
	frames.set_animation_speed(pose_id, RIDER_FPS)
	for texture_value: Variant in textures:
		var texture: Texture2D = texture_value
		frames.add_frame(pose_id, texture)
	return {
		"frames": frames,
		"status": "bound",
		"frame_count": textures.size(),
		"frames_expected": PUWCastRegistry.frames_expected(pose_id),
		"pose_set": PUWCastRegistry.pose_set_for_cast(cast_id),
	}


## ------------------------------------------------------------------
## Wardrobe (QA round 3, 2026-11-22). Alternate outfit layers were
## visually graded row by row (verdicts in qa_round3/); ONLY the
## directions whose full composite row passed are "bound" in
## systems/cast/wardrobe_registry.json (14 directions, 142 frames).
## Every other direction is recorded "unbound" with its plain
## reason (graded defect or structural block) and NEVER builds
## frames here. Alternate outfits have no idle / swim / battle /
## ride / bike layers in this delivery, so those states report
## "signature_fallback": the caller keeps the signature outfit for
## them (documented architecture rule, not a bug). The signature
## outfit itself keeps its frame_data.json bindings and is served
## by build_frames above; wardrobe_status references it without
## duplicating that data.
## ------------------------------------------------------------------

static func _wardrobe_registry() -> Dictionary:
	return PUWCastRegistry.load_json(WARDROBE_REGISTRY_PATH)


## The registry record for one character + outfit, or a status-only
## record: "unknown_cast" / "unknown_outfit" with 0 bound frames.
## Bound records are returned as stored (per-gait per-direction
## statuses plus wearable_contexts).
static func wardrobe_status(character: String, outfit_id: String) -> Dictionary:
	var registry: Dictionary = _wardrobe_registry()
	var characters: Dictionary = registry.get("characters", {})
	if not characters.has(character):
		return {"status": "unknown_cast", "character": character, "outfit_id": outfit_id}
	var char_rec: Dictionary = characters.get(character, {})
	var outfits: Dictionary = char_rec.get("outfits", {})
	if not outfits.has(outfit_id):
		return {"status": "unknown_outfit", "character": character, "outfit_id": outfit_id}
	var outfit_rec: Dictionary = outfits.get(outfit_id, {})
	return outfit_rec.duplicate(true)


## Build SpriteFrames for one alternate-outfit direction. `state`
## is a directional locomotion state ("walk_down", "walk_up",
## "run_up", ...). Returns {frames, status, frame_count}:
##   "bound"             -- real SpriteFrames from the copied
##                          composite PNGs, registry fps.
##   "unbound"           -- 0 frames + the recorded reason.
##   "signature_fallback"-- 0 frames; the state has no alternate
##                          layer (idle/swim/battle/ride/bike, or a
##                          bare non-directional gait request).
##   "unknown_cast" / "unknown_outfit" -- 0 frames.
## The signature outfit delegates to build_frames unchanged.
static func build_outfit_frames(character: String, outfit_id: String, state: String) -> Dictionary:
	if outfit_id == "signature":
		var built: Dictionary = build_frames(character, state)
		return built
	var status_rec: Dictionary = wardrobe_status(character, outfit_id)
	var status: String = str(status_rec.get("status", ""))
	if status == "unknown_cast" or status == "unknown_outfit":
		return {"frames": null, "status": status, "frame_count": 0}
	var parts: PackedStringArray = state.split("_")
	if parts.size() != 2:
		return {"frames": null, "status": "signature_fallback", "frame_count": 0,
			"reason": "Alternate outfits bind per direction only; states without a direction use the signature outfit."}
	var gait: String = parts[0]
	var direction: String = parts[1]
	if gait != "walk" and gait != "run":
		return {"frames": null, "status": "signature_fallback", "frame_count": 0,
			"reason": "No alternate-outfit layer exists for this state; the signature outfit is used."}
	var gaits: Dictionary = status_rec.get("gaits", {})
	var gait_rec: Dictionary = gaits.get(gait, {})
	var directions: Dictionary = gait_rec.get("directions", {})
	var dir_rec: Dictionary = directions.get(direction, {})
	if dir_rec.is_empty():
		return {"frames": null, "status": "signature_fallback", "frame_count": 0,
			"reason": "No wardrobe record for this direction; the signature outfit is used."}
	if str(dir_rec.get("status", "")) != "bound":
		return {"frames": null, "status": "unbound", "frame_count": 0,
			"reason": str(dir_rec.get("reason", ""))}
	var frame_recs: Array = dir_rec.get("frames", [])
	var textures: Array = []
	for frame_value: Variant in frame_recs:
		var frame_rec: Dictionary = frame_value
		var png: String = str(frame_rec.get("png", ""))
		if png == "" or not ResourceLoader.exists(png):
			return {"frames": null, "status": "unbound", "frame_count": 0,
				"reason": "Bound in the registry but a frame PNG is missing from the project."}
		var texture: Texture2D = load(png) as Texture2D
		if texture == null:
			return {"frames": null, "status": "unbound", "frame_count": 0,
				"reason": "Bound in the registry but a frame PNG failed to load."}
		textures.append(texture)
	var fps: float = float(dir_rec.get("fps", float(CLIP_FPS.get(state, 7.5))))
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(state)
	frames.set_animation_loop(state, true)
	frames.set_animation_speed(state, fps)
	for texture_value: Variant in textures:
		var texture: Texture2D = texture_value
		frames.add_frame(state, texture)
	return {"frames": frames, "status": "bound", "frame_count": textures.size()}


## Rider coverage report, PER SET: for every cast member, the
## poses of THEIR OWN set only, each with its art status and built
## frame count (riley sees the 14 riley-set states incl.
## mount_wave; tasha the 14 tasha-set states incl. hover_descend;
## custom presets the 13 generic states). Since the 2026-11-22 QA
## integration most entries are "bound" with their sliced frame
## counts; the poses Neon still owes report art_pending with 0.
static func rider_coverage() -> Dictionary:
	var report: Dictionary = {}
	for cast_value: Variant in PUWCastRegistry.cast_ids():
		var cast_id: String = str(cast_value)
		var poses_report: Dictionary = {}
		for pose_value: Variant in PUWCastRegistry.rider_pose_ids_for_cast(cast_id):
			var pose_id: String = str(pose_value)
			var built: Dictionary = build_rider_frames(cast_id, pose_id)
			poses_report[pose_id] = {
				"status": str(built.get("status", "")),
				"frame_count": int(built.get("frame_count", 0)),
				"frames_expected": PUWCastRegistry.frames_expected(pose_id),
				"pose_set": PUWCastRegistry.pose_set_for_cast(cast_id),
			}
		report[cast_id] = poses_report
	return report
