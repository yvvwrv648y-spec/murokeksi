extends SceneTree
## Cast animation tests for Pokemon Ultimate World.
## Run: godot --headless --script res://tests/cast_animation_tests.gd
##
## Verifies PUWCastRigLoader builds REAL SpriteFrames from the
## sliced frame PNGs (tools/slice_cast_frames.py ->
## systems/cast/frame_data.json -> res://art_frames/) for all six
## cast members: walk/run/idle/swim load with real non-null
## textures, FPS matches actor_state_machine.gd CLIP_FPS (walk
## 7.5, run 11.0, idle 4.0), battle loads its single real pose
## frame, and coverage() reports the character states present.
##
## Directional walk (QA integration 2026-11-22): the layered walk
## pilot adds per-facing clips for riley (all four directions) and
## tasha (down/up/right only -- her pilot left row was rejected,
## 5 of 8 frames facing right, so walk_left must stay unbound and
## is asserted absent below, never mirrored).
##
## Directional walk + run (QA round 2, 2026-11-22): Neon's layered
## run cycles for all six cast members and layered walk cycles for
## the four Custom presets were graded frame by frame (verdicts in
## the goal workspace, hidden_files/qa_round2/verdicts/). A
## direction is bound ONLY where its full row passed in both layers
## with layer alignment PASS. Bound below: riley run_* x4;
## custom_female walk_* x4 + run_up; custom_male walk_down/up +
## run_up; custom_femboy walk_* x4 + run_up; custom_futanari
## walk_up/left/right + run_up. Asserted NOT bound below: every
## tasha run direction (the set failed grading), the Custom run
## down/left/right directions (eye flicker, wrong-facing frames,
## feet on the cell edge), custom_male walk_left/walk_right
## (direction flips mid-row), and custom_futanari walk_down (the
## outfit vest collar covers the mouth/chin in every front frame).
##
## QA ROUND 5 (2026-11-23): Neon's redo delivery was graded
## (hidden_files/qa_round5/verdicts/) and only the passed material
## was bound by tools/slice_qa_art_round5.py. Changes to this
## suite, with the count arithmetic (baseline 267 -> 293):
##   * tasha walk_left is now BOUND (her redrawn left row passed):
##     the pilot section's tasha loop gains the left direction
##     (+4 checks) and the two walk_left not-bound assertions are
##     removed (-2).
##   * The round-2 run_up entries for custom_female / custom_male /
##     custom_futanari were converted IN PLACE to the v2 frame
##     counts that supersede them (12->10, 10->8, 8->10; no count
##     change). custom_femboy run_up stays 8 (v2 re-bind, same
##     count).
##   * A new round5_bound list asserts the newly bound run clips:
##     tasha run_down/up/left (8), custom_female run_down/left/
##     right (10), custom_male run_down/left (8), custom_femboy
##     run_left/right (8), custom_futanari run_left/right (10)
##     -- 12 clips x 4 checks = +48.
##   * The round-2 pending list loses the 12 clips round 5 bound
##     (-24 checks); still pending and asserted NOT bound: tasha
##     run_right (outfit F4-F6 offset), custom_male
##     walk_left/walk_right (F8 head faces right; 8/row vs the
##     bound 12/row cycle), custom_femboy run_down (hood over
##     mouth/chin), custom_futanari run_down (vest over
##     mouth/chin) + walk_down (row-1 v2 outfit FAILED
##     again -- chin still under the vest).
##
## QA ROUND 8 PHASE 3 (2026-11-23, Worker D stale-assertion fix):
## the L4 locomotion binding bound custom_male run_right
## (cast_states.custom_male.run_right = frames 24-31 on
## characters/layered/run/custom_male_run_composite_v2, 8 frames
## at 11.0 fps), so its two not-bound assertions in the pending
## list below were stale. Converted: the pending entry is removed
## (-2 checks) and a new phase3_bound list asserts the bound
## truth with the same 4 checks as every other bound direction
## (+4 checks). Count arithmetic: baseline 293 -> 295.
##
## QA ROUND 8 PHASE 3 (2026-11-23, gap-fix slice): the L6/L7
## locomotion bindings bound custom_futanari walk_down (L6:
## frames 0-11 on characters/layered/walk/
## custom_futanari_walk_composite, 12 frames at 7.5 fps) and
## custom_futanari run_down (L7: frames 0-9 on
## characters/layered/run/custom_futanari_run_composite_v2,
## 10 frames at 11.0 fps), so their two not-bound assertions
## in the pending list below were stale -- they directly
## contradicted the graded L6/L7 CLOSED verdicts
## (hidden_files/qa_round8/verdicts/wave1_loco_f1.md).
## Converted the same way as the L4 fix above: the two
## pending entries are removed (-4 checks) and a new
## phase3_l6l7_bound list asserts the bound truth with the
## same 4 checks as every other bound direction (+8 checks).
## Count arithmetic: baseline 295 -> 299.
##
## POST-MILESTONE INTEGRATION (2026-11-23): QA rounds 9 + 10
## closed the last four pending signature rows -- L1 v5 tasha
## run_right (round 10), L2/L3 custom_male walk_left/walk_right
## (round 9), L5 v4 custom_femboy run_down (round 9). All four
## are now bound, so their not-bound assertions were stale.
## Converted the same way as the L4/L6/L7 fixes: the four
## pending entries are removed (-8 checks) and a new
## post_milestone_bound list asserts the bound truth with the
## same 4 checks as every other bound direction (+16 checks).
## Count arithmetic: baseline 299 -> 307. The pending list is
## now EMPTY: every signature locomotion direction of every
## cast member is bound.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _all_textures_real(frames_value: Variant, state: String) -> bool:
	if not (frames_value is SpriteFrames):
		return false
	var sf: SpriteFrames = frames_value
	if not sf.has_animation(state):
		return false
	var count: int = sf.get_frame_count(state)
	if count < 1:
		return false
	for i: int in range(count):
		var tex: Texture2D = sf.get_frame_texture(state, i)
		if tex == null:
			return false
		if tex.get_width() < 1 or tex.get_height() < 1:
			return false
	return true


func _init() -> void:
	print("PUW cast animation tests -- starting.")
	var cast_ids: Array = PUWCastRegistry.cast_ids()
	_check("six_cast_members", cast_ids.size() == 6)
	var cov: Dictionary = PUWCastRigLoader.coverage()
	for cast_value: Variant in cast_ids:
		var cast_id: String = str(cast_value)

		var walk: Dictionary = PUWCastRigLoader.build_frames(cast_id, "walk")
		_check(cast_id + "_walk_loaded", str(walk.get("status", "")) == "loaded")
		_check(cast_id + "_walk_at_least_4_frames", int(walk.get("frame_count", 0)) >= 4)
		_check(cast_id + "_walk_textures_real", _all_textures_real(walk.get("frames", null), "walk"))
		var walk_sf: SpriteFrames = walk.get("frames", null) as SpriteFrames
		_check(cast_id + "_walk_fps_7_5", walk_sf != null and is_equal_approx(walk_sf.get_animation_speed("walk"), 7.5))
		_check(cast_id + "_walk_loops", walk_sf != null and walk_sf.get_animation_loop("walk"))

		var run: Dictionary = PUWCastRigLoader.build_frames(cast_id, "run")
		_check(cast_id + "_run_loaded", str(run.get("status", "")) == "loaded" and int(run.get("frame_count", 0)) >= 4)
		var run_sf: SpriteFrames = run.get("frames", null) as SpriteFrames
		_check(cast_id + "_run_fps_11_0", run_sf != null and is_equal_approx(run_sf.get_animation_speed("run"), 11.0))

		var idle: Dictionary = PUWCastRigLoader.build_frames(cast_id, "idle")
		_check(cast_id + "_idle_loaded", str(idle.get("status", "")) == "loaded" and int(idle.get("frame_count", 0)) >= 1)
		_check(cast_id + "_idle_textures_real", _all_textures_real(idle.get("frames", null), "idle"))
		var idle_sf: SpriteFrames = idle.get("frames", null) as SpriteFrames
		_check(cast_id + "_idle_fps_4_0", idle_sf != null and is_equal_approx(idle_sf.get_animation_speed("idle"), 4.0))

		var swim: Dictionary = PUWCastRigLoader.build_frames(cast_id, "swim")
		_check(cast_id + "_swim_loaded", str(swim.get("status", "")) == "loaded" and int(swim.get("frame_count", 0)) >= 4)
		_check(cast_id + "_swim_textures_real", _all_textures_real(swim.get("frames", null), "swim"))

		var battle: Dictionary = PUWCastRigLoader.build_frames(cast_id, "battle")
		_check(cast_id + "_battle_loaded", str(battle.get("status", "")) == "loaded")
		_check(cast_id + "_battle_single_pose_frame", int(battle.get("frame_count", 0)) == 1)
		_check(cast_id + "_battle_texture_real", _all_textures_real(battle.get("frames", null), "battle"))
		var battle_sf: SpriteFrames = battle.get("frames", null) as SpriteFrames
		_check(cast_id + "_battle_does_not_loop", battle_sf != null and not battle_sf.get_animation_loop("battle"))

		_check(cast_id + "_frames_available_walk", PUWCastRigLoader.frames_available(cast_id, "walk"))
		var cast_cov: Dictionary = cov.get(cast_id, {})
		_check(cast_id + "_coverage_walk", bool(cast_cov.get("walk", false)))
		_check(cast_id + "_coverage_battle", bool(cast_cov.get("battle", false)))

	# --- Directional walk clips from the layered pilot (2026-11-22). ---
	for dir_value: Variant in ["down", "up", "left", "right"]:
		var dir_name: String = str(dir_value)
		var clip: String = "walk_" + dir_name
		var built: Dictionary = PUWCastRigLoader.build_frames("riley", clip)
		_check("riley_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check("riley_" + clip + "_8_frames", int(built.get("frame_count", 0)) == 8)
		_check("riley_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check("riley_" + clip + "_fps_7_5", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), 7.5))
	# QA round 5: tasha's redrawn left row passed, so all four
	# directions are bound now (walk_left asserted in the loop).
	for dir_value: Variant in ["down", "up", "left", "right"]:
		var dir_name: String = str(dir_value)
		var clip: String = "walk_" + dir_name
		var built: Dictionary = PUWCastRigLoader.build_frames("tasha", clip)
		_check("tasha_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check("tasha_" + clip + "_8_frames", int(built.get("frame_count", 0)) == 8)
		_check("tasha_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check("tasha_" + clip + "_fps_7_5", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), 7.5))

	# --- Directional walk/run clips from QA round 2 (2026-11-22). ---
	# Bound clips: [cast_id, clip, expected frame count, expected fps].
	var round2_bound: Array = [
		["riley", "run_down", 8, 11.0],
		["riley", "run_up", 8, 11.0],
		["riley", "run_left", 8, 11.0],
		["riley", "run_right", 8, 11.0],
		["custom_female", "walk_down", 12, 7.5],
		["custom_female", "walk_up", 12, 7.5],
		["custom_female", "walk_left", 12, 7.5],
		["custom_female", "walk_right", 12, 7.5],
		["custom_female", "run_up", 10, 11.0],
		["custom_male", "walk_down", 12, 7.5],
		["custom_male", "walk_up", 12, 7.5],
		["custom_male", "run_up", 8, 11.0],
		["custom_femboy", "walk_down", 12, 7.5],
		["custom_femboy", "walk_up", 12, 7.5],
		["custom_femboy", "walk_left", 12, 7.5],
		["custom_femboy", "walk_right", 12, 7.5],
		["custom_femboy", "run_up", 8, 11.0],
		["custom_futanari", "walk_up", 12, 7.5],
		["custom_futanari", "walk_left", 12, 7.5],
		["custom_futanari", "walk_right", 12, 7.5],
		["custom_futanari", "run_up", 10, 11.0],
	]
	for rec_value: Variant in round2_bound:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var want_frames: int = int(rec[2])
		var want_fps: float = float(rec[3])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check(cid + "_" + clip + "_frame_count", int(built.get("frame_count", 0)) == want_frames)
		_check(cid + "_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check(cid + "_" + clip + "_fps", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), want_fps))

	# --- Directional run clips bound in QA round 5 (2026-11-23). ---
	# The v2 run sets (tools/slice_qa_art_round5.py); run_up clips
	# for the four Custom presets live in the round-2 list above at
	# their superseded v2 counts.
	var round5_bound: Array = [
		["tasha", "run_down", 8, 11.0],
		["tasha", "run_up", 8, 11.0],
		["tasha", "run_left", 8, 11.0],
		["custom_female", "run_down", 10, 11.0],
		["custom_female", "run_left", 10, 11.0],
		["custom_female", "run_right", 10, 11.0],
		["custom_male", "run_down", 8, 11.0],
		["custom_male", "run_left", 8, 11.0],
		["custom_femboy", "run_left", 8, 11.0],
		["custom_femboy", "run_right", 8, 11.0],
		["custom_futanari", "run_left", 10, 11.0],
		["custom_futanari", "run_right", 10, 11.0],
	]
	for rec_value: Variant in round5_bound:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var want_frames: int = int(rec[2])
		var want_fps: float = float(rec[3])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check(cid + "_" + clip + "_frame_count", int(built.get("frame_count", 0)) == want_frames)
		_check(cid + "_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check(cid + "_" + clip + "_fps", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), want_fps))

	# --- Directional run clip bound in QA round 8 phase 3 (L4). ---
	# custom_male run_right: frames 24-31 on
	# custom_male_run_composite_v2 (see the header note).
	var phase3_bound: Array = [
		["custom_male", "run_right", 8, 11.0],
	]

	# --- Directional clips bound in QA round 8 phase 3 (L6/L7). ---
	# custom_futanari walk_down (L6) and run_down (L7): see the
	# header note.
	var phase3_l6l7_bound: Array = [
		["custom_futanari", "walk_down", 12, 7.5],
		["custom_futanari", "run_down", 10, 11.0],
	]
	for rec_value: Variant in phase3_l6l7_bound:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var want_frames: int = int(rec[2])
		var want_fps: float = float(rec[3])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check(cid + "_" + clip + "_frame_count", int(built.get("frame_count", 0)) == want_frames)
		_check(cid + "_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check(cid + "_" + clip + "_fps", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), want_fps))
	for rec_value: Variant in phase3_bound:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var want_frames: int = int(rec[2])
		var want_fps: float = float(rec[3])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check(cid + "_" + clip + "_frame_count", int(built.get("frame_count", 0)) == want_frames)
		_check(cid + "_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check(cid + "_" + clip + "_fps", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), want_fps))

	# --- Directional clips bound in the post-milestone build. ---
	# L1 v5 tasha run_right (QA round 10), L2/L3 custom_male
	# walk_left/walk_right and L5 v4 custom_femboy run_down
	# (QA round 9): see the header note.
	var post_milestone_bound: Array = [
		["tasha", "run_right", 8, 11.0],
		["custom_male", "walk_left", 12, 7.5],
		["custom_male", "walk_right", 12, 7.5],
		["custom_femboy", "run_down", 8, 11.0],
	]
	for rec_value: Variant in post_milestone_bound:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var want_frames: int = int(rec[2])
		var want_fps: float = float(rec[3])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_loaded", str(built.get("status", "")) == "loaded")
		_check(cid + "_" + clip + "_frame_count", int(built.get("frame_count", 0)) == want_frames)
		_check(cid + "_" + clip + "_textures_real", _all_textures_real(built.get("frames", null), clip))
		var clip_sf: SpriteFrames = built.get("frames", null) as SpriteFrames
		_check(cid + "_" + clip + "_fps", clip_sf != null and is_equal_approx(clip_sf.get_animation_speed(clip), want_fps))

	# Directions the graders rejected (or that were never drawn
	# clean) must stay unbound -- no entry, no frames, no mirror.
	# Round 5 removed the 12 clips it bound from this list; round 8
	# phase 3 (L4) removed custom_male run_right and the L6/L7
	# gap-fix removed custom_futanari walk_down/run_down. The
	# post-milestone build (rounds 9 + 10) bound the last four;
	# the list is now empty and the loop below runs zero times.
	var round2_pending: Array = [
	]
	for rec_value: Variant in round2_pending:
		var rec: Array = rec_value
		var cid: String = str(rec[0])
		var clip: String = str(rec[1])
		var built: Dictionary = PUWCastRigLoader.build_frames(cid, clip)
		_check(cid + "_" + clip + "_not_bound", str(built.get("status", "")) != "loaded" and int(built.get("frame_count", -1)) == 0 and built.get("frames", null) == null)
		_check(cid + "_" + clip + "_frames_unavailable", not PUWCastRigLoader.frames_available(cid, clip))

	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(0 if _failed == 0 else 1)
