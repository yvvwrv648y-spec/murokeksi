extends SceneTree
## Rider pose tests for Pokemon Ultimate World (Phase 3, item B).
## Run: godot --headless --script res://tests/rider_pose_tests.gd
##
## Verifies the rider pose taxonomy registered in
## PUWCastRegistry (RIDER_POSES + systems/cast/rider_poses.json)
## and the rider section of PUWCastRigLoader: exactly 13 poses
## with the exact names and order, frame counts and roles, the
## ride-mode -> pose mapping (11 mode rows), a complete anchor
## rule per mode, and rider poses staying OUT of the existing
## cast STATES array.
##
## Art truth updated 2026-11-22 (QA integration): Neon's ride
## sheets were graded and the accepted primaries sliced, so
## build_rider_frames now reports "bound" with real frames for
## every pose that has accepted art, and still reports
## art_pending with zero frames for the poses Neon still owes
## (tasha fly_carried; generic climb_cling except custom_femboy;
## generic climb_stand for custom_femboy / custom_futanari).
## The assertions below state that per-set / per-cast truth.
##
## Art truth updated 2026-11-22 (QA ROUND 4): the layered ride
## delivery was graded and its accepted trainer_canon stacks
## supersede the round-1 flat canon bindings in
## rider_frame_data.json. Generic climb_cling is now bound for
## custom_female and custom_futanari as well (layered canon,
## 1 frame each); custom_male climb_cling stays art_pending
## (drawn rock). Exactly ONE assertion below was converted in
## place to the new truth (custom_female climb_cling:
## art_pending -> bound); the suite total is unchanged.
##
## Art truth updated 2026-11-23 (QA ROUND 5): the graded ride
## singles were bound by tools/slice_qa_art_round5.py. Converted
## in place (no count change): the per-pose art_status loop now
## expects tasha fly_carried bound and BOTH generic climb poses
## bound (climb_cling closed for custom_male; climb_stand closed
## for custom_femboy + custom_futanari, joining custom_female +
## custom_male who were bound in round 1); the tasha fly_carried
## art_pending build assertion is now a bound assertion; the
## riley mount_wave and tasha hover_descend partial build
## assertions (1 of 2 frames) are now complete (2 of 2). New
## assertions (+6, baseline 172 -> 178): custom_male climb_cling
## builds bound, custom_femboy climb_stand builds bound,
## custom_futanari climb_stand builds bound, the round-5 spares
## are stored marked not-the-active-binding, custom_female's
## active climb_cling binding is still the round-4 layered stack,
## and hover_descend frame 2 sits on frame 1's shared canvas.
##
## Art truth updated 2026-11-23 (QA ROUND 6): Riley and Tasha
## canon ride bindings are now the layered canon stacks
## (qa_round6/verdicts_rides.md), superseding the round-1 flat
## frames; the round-6 singles complete riley's gallop pair and
## bind riley + tasha climb_stand (climb_stand is now bound for
## all six cast members) and tasha's hover_stand wind (pair
## complete); custom_male climb_cling was REPLACED by the v2
## single and the round-5 frame moved to spares. Converted in
## place (no count change): the spares check then expected 3
## spares (2 round-5 + the replaced round-5 male climb_cling).
##
## Art truth updated 2026-11-23 (QA ROUND 8 PHASE 3, Worker D
## stale-assertion fix): the R7 ride binding superseded the
## round-5 tasha fly_carried single with the round-8 layered
## canon base binding and moved that single to spares, making
## 4 spares (all marked spare_not_active_binding; see the
## spares note in rider_frame_data.json). Converted in place
## (no count change): the spares check now expects 4.
## New assertions (+6, baseline 178 -> 184): riley and tasha
## canon seated entries carry source_round qa_round6_layered,
## riley gallop builds bound at 2 frames, riley and tasha
## climb_stand build bound, and custom_male's active
## climb_cling frame is the round-6 single.

var _passed: int = 0
var _failed: int = 0

const EXPECTED_POSES: Array = [
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

const TWO_FRAME_POSES: Array = ["ride_land_gallop", "fly_seated", "hover_stand"]

const EXPECTED_PRIMARY: Dictionary = {
	"land_riding": "ride_land_seated",
	"surfing": "surf_stand",
	"ferrying": "ferry_seated",
	"mounted_flight": "fly_seated",
	"carried_flight": "fly_carried",
	"diving": "dive_hold",
	"climbing_cliff": "climb_cling",
	"climbing_waterfall": "climb_stand",
	"hover_carrying": "hover_stand",
	"held_carrying": "carry_held",
	"burrowing": "burrow_crouch",
}


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	print("PUW rider pose tests -- starting.")

	# --- Registration: exactly 13 poses, exact names and order. ---
	var pose_ids: Array = PUWCastRegistry.rider_pose_ids()
	_check("exactly_13_rider_poses", pose_ids.size() == 13)
	_check("rider_pose_names_and_order_exact", pose_ids == EXPECTED_POSES)
	for pose_value: Variant in EXPECTED_POSES:
		var pose_id: String = str(pose_value)
		_check("registered_" + pose_id, PUWCastRigLoader.rider_pose_registered(pose_id))
		# Per-set art truth (QA round 5, 2026-11-23): every base
		# pose is now bound in every set -- tasha fly_carried was
		# bound in round 5, and the generic climb pair closed
		# (climb_cling for custom_male; climb_stand for
		# custom_femboy + custom_futanari).
		var riley_rec: Dictionary = PUWCastRegistry.rider_pose_record_for_set("riley", pose_id)
		var tasha_rec: Dictionary = PUWCastRegistry.rider_pose_record_for_set("tasha", pose_id)
		var generic_status: String = PUWCastRegistry.rider_pose_art_status(pose_id)
		var expected_generic: String = "bound"
		var expected_tasha: String = "bound"
		_check(
			"art_status_truth_" + pose_id,
			str(riley_rec.get("art_status", "")) == "bound"
			and str(tasha_rec.get("art_status", "")) == expected_tasha
			and generic_status == expected_generic
		)

	# --- Frame counts and roles. ---
	for pose_value: Variant in EXPECTED_POSES:
		var pose_id: String = str(pose_value)
		var expected_frames: int = 2 if TWO_FRAME_POSES.has(pose_id) else 1
		_check("frames_expected_" + pose_id, PUWCastRegistry.frames_expected(pose_id) == expected_frames)
		var roles: Array = PUWCastRegistry.frame_roles_for_pose(pose_id)
		if expected_frames == 2:
			_check("frame_roles_calm_wind_" + pose_id, roles == ["calm", "wind"])
		else:
			_check("frame_roles_hold_" + pose_id, roles == ["hold"])

	# --- Ride modes: 11 rows (climbing counted twice). ---
	var mode_ids: Array = PUWCastRegistry.ride_mode_ids()
	_check("exactly_11_ride_mode_rows", mode_ids.size() == 11)
	var served_poses: Array = []
	for mode_value: Variant in EXPECTED_PRIMARY.keys():
		var mode_id: String = str(mode_value)
		_check("mode_exists_" + mode_id, mode_ids.has(mode_id))
		var entries: Array = PUWCastRegistry.poses_for_mode(mode_id)
		_check("mode_has_pose_" + mode_id, not entries.is_empty())
		for entry_value: Variant in entries:
			var entry: Dictionary = entry_value
			var served: String = str(entry.get("pose_id", ""))
			if not served_poses.has(served):
				served_poses.append(served)
		_check("primary_pose_" + mode_id, PUWCastRegistry.pose_for_mode(mode_id) == str(EXPECTED_PRIMARY[mode_id]))
	for pose_value: Variant in EXPECTED_POSES:
		var pose_id: String = str(pose_value)
		_check("pose_serves_a_mode_" + pose_id, served_poses.has(pose_id))
	_check("all_13_poses_served_by_modes", served_poses.size() == 13)

	# Variant mapping spot checks (exact conditions from the taxonomy).
	var land_entries: Array = PUWCastRegistry.poses_for_mode("land_riding")
	_check("land_riding_has_gallop_variant", land_entries.size() == 2 and str((land_entries[1] as Dictionary).get("pose_id", "")) == "ride_land_gallop")
	var surf_entries: Array = PUWCastRegistry.poses_for_mode("surfing")
	_check("surfing_has_kneel_variant", surf_entries.size() == 2 and str((surf_entries[1] as Dictionary).get("pose_id", "")) == "surf_kneel")

	# --- Anchor rules: one complete rule per mode. ---
	for mode_value: Variant in EXPECTED_PRIMARY.keys():
		var mode_id: String = str(mode_value)
		var rule: Dictionary = PUWCastRegistry.anchor_rule_for_mode(mode_id)
		var offset: Array = rule.get("offset", [])
		_check(
			"anchor_rule_" + mode_id,
			str(rule.get("rider_anchor", "")) != ""
			and str(rule.get("pokemon_anchor", "")) != ""
			and offset.size() == 2
			and str(rule.get("facing", "")) == "sync"
			and ["rider_above", "rider_below"].has(str(rule.get("z_order", "")))
		)
	var hover_rule: Dictionary = PUWCastRegistry.anchor_rule_for_mode("hover_carrying")
	_check("hover_anchor_feet_on_top_center", str(hover_rule.get("rider_anchor", "")) == "feet" and str(hover_rule.get("pokemon_anchor", "")) == "top_center")
	var carried_rule: Dictionary = PUWCastRegistry.anchor_rule_for_mode("carried_flight")
	_check("carried_flight_rider_below", str(carried_rule.get("z_order", "")) == "rider_below" and str(carried_rule.get("pokemon_anchor", "")) == "underside_grip")
	var held_rule: Dictionary = PUWCastRegistry.anchor_rule_for_mode("held_carrying")
	_check("held_anchor_seat_in_front_arms", str(held_rule.get("rider_anchor", "")) == "seat" and str(held_rule.get("pokemon_anchor", "")) == "front_arms")

	# --- Rig loader: bound poses build real frames (QA 2026-11-22). ---
	var build_cases: Array = [
		["riley", "ride_land_seated", 1],
		["riley", "hover_stand", 2],
		["riley", "fly_seated", 2],
		["tasha", "hover_stand", 2],
		["tasha", "surf_stand", 1],
		["tasha", "dive_hold", 1],
	]
	for case_value: Variant in build_cases:
		var case_pair: Array = case_value
		var cast_id: String = str(case_pair[0])
		var pose_id: String = str(case_pair[1])
		var expected_count: int = int(case_pair[2])
		var built: Dictionary = PUWCastRigLoader.build_rider_frames(cast_id, pose_id)
		_check(
			"build_rider_frames_bound_" + cast_id + "_" + pose_id,
			str(built.get("status", "")) == "bound"
			and int(built.get("frame_count", -1)) == expected_count
			and built.get("frames", null) != null
		)
	# QA round 5: tasha fly_carried was redrawn to spec and bound.
	var tasha_carried: Dictionary = PUWCastRigLoader.build_rider_frames("tasha", "fly_carried")
	_check("tasha_fly_carried_bound_round5", str(tasha_carried.get("status", "")) == "bound" and int(tasha_carried.get("frame_count", -1)) == 1 and tasha_carried.get("frames", null) != null)
	var female_cling: Dictionary = PUWCastRigLoader.build_rider_frames("custom_female", "climb_cling")
	_check("custom_female_climb_cling_bound_round4", str(female_cling.get("status", "")) == "bound" and int(female_cling.get("frame_count", -1)) == 1 and female_cling.get("frames", null) != null)
	var femboy_cling: Dictionary = PUWCastRigLoader.build_rider_frames("custom_femboy", "climb_cling")
	_check("custom_femboy_climb_cling_bound", str(femboy_cling.get("status", "")) == "bound" and int(femboy_cling.get("frame_count", -1)) == 1 and femboy_cling.get("frames", null) != null)
	var rider_cov: Dictionary = PUWCastRigLoader.rider_coverage()
	var tasha_cov: Dictionary = rider_cov.get("tasha", {})
	var hover_cov: Dictionary = tasha_cov.get("hover_stand", {})
	_check("rider_coverage_hover_stand_bound", str(hover_cov.get("status", "")) == "bound" and int(hover_cov.get("frame_count", -1)) == 2)

	# --- Three pose sets (refinement 2026-11-22 14:59 CST). ---
	_check("pose_set_riley", PUWCastRegistry.pose_set_for_cast("riley") == "riley")
	_check("pose_set_tasha", PUWCastRegistry.pose_set_for_cast("tasha") == "tasha")
	_check("pose_set_custom_female", PUWCastRegistry.pose_set_for_cast("custom_female") == "generic")
	_check("pose_set_custom_male", PUWCastRegistry.pose_set_for_cast("custom_male") == "generic")
	_check("pose_set_custom_femboy", PUWCastRegistry.pose_set_for_cast("custom_femboy") == "generic")
	_check("pose_set_custom_futanari", PUWCastRegistry.pose_set_for_cast("custom_futanari") == "generic")

	var riley_set: Array = PUWCastRegistry.rider_pose_ids_for_set("riley")
	_check("riley_set_14_states", riley_set.size() == 14 and riley_set.has("mount_wave"))
	_check("riley_set_has_all_13_base", EXPECTED_POSES.all(func(p: Variant) -> bool: return riley_set.has(str(p))))
	var tasha_set: Array = PUWCastRegistry.rider_pose_ids_for_set("tasha")
	_check("tasha_set_14_states", tasha_set.size() == 14 and tasha_set.has("hover_descend"))
	_check("tasha_set_has_all_13_base", EXPECTED_POSES.all(func(p: Variant) -> bool: return tasha_set.has(str(p))))
	var generic_set: Array = PUWCastRegistry.rider_pose_ids_for_set("generic")
	_check("generic_set_13_states", generic_set.size() == 13 and generic_set == EXPECTED_POSES)
	_check("generic_set_no_mount_wave", not generic_set.has("mount_wave"))
	_check("generic_set_no_hover_descend", not generic_set.has("hover_descend"))
	_check("mount_wave_absent_from_tasha", not PUWCastRegistry.rider_pose_in_set("tasha", "mount_wave"))
	_check("hover_descend_absent_from_riley", not PUWCastRegistry.rider_pose_in_set("riley", "hover_descend"))
	_check("mount_wave_registered_for_riley", PUWCastRigLoader.rider_pose_registered_for("riley", "mount_wave"))
	_check("mount_wave_not_for_tasha", not PUWCastRigLoader.rider_pose_registered_for("tasha", "mount_wave"))

	# Signature extras: frame counts and roles.
	_check("mount_wave_2_frames", PUWCastRegistry.frames_expected("mount_wave") == 2)
	_check("mount_wave_roles_idle_wave", PUWCastRegistry.frame_roles_for_pose("mount_wave") == ["idle", "wave"])
	_check("hover_descend_2_frames", PUWCastRegistry.frames_expected("hover_descend") == 2)
	_check("hover_descend_roles_high_touching_down", PUWCastRegistry.frame_roles_for_pose("hover_descend") == ["high", "touching_down"])

	# The two-frame rule holds in EVERY set.
	for set_value: Variant in ["riley", "tasha", "generic"]:
		var set_id: String = str(set_value)
		for pose_value: Variant in TWO_FRAME_POSES:
			var pose_id: String = str(pose_value)
			var rec: Dictionary = PUWCastRegistry.rider_pose_record_for_set(set_id, pose_id)
			_check("two_frame_in_" + set_id + "_" + pose_id, int(rec.get("frames_expected", 0)) == 2 and (rec.get("frame_roles", []) as Array) == ["calm", "wind"])

	# Set-aware build: not_in_set vs bound / art_pending.
	var tasha_wave: Dictionary = PUWCastRigLoader.build_rider_frames("tasha", "mount_wave")
	_check("tasha_mount_wave_not_in_set", str(tasha_wave.get("status", "")) == "not_in_set" and int(tasha_wave.get("frame_count", -1)) == 0 and tasha_wave.get("frames", null) == null)
	var riley_wave: Dictionary = PUWCastRigLoader.build_rider_frames("riley", "mount_wave")
	_check("riley_mount_wave_bound_complete_round5", str(riley_wave.get("status", "")) == "bound" and int(riley_wave.get("frame_count", -1)) == 2 and riley_wave.get("frames", null) != null and int(riley_wave.get("frames_expected", -1)) == 2)
	var tasha_descend: Dictionary = PUWCastRigLoader.build_rider_frames("tasha", "hover_descend")
	_check("tasha_hover_descend_bound_complete_round5", str(tasha_descend.get("status", "")) == "bound" and int(tasha_descend.get("frame_count", -1)) == 2 and tasha_descend.get("frames", null) != null and int(tasha_descend.get("frames_expected", -1)) == 2)

	# --- QA round 5 new bindings and spares (2026-11-23). ---
	var male_cling: Dictionary = PUWCastRigLoader.build_rider_frames("custom_male", "climb_cling")
	_check("custom_male_climb_cling_bound_round5", str(male_cling.get("status", "")) == "bound" and int(male_cling.get("frame_count", -1)) == 1 and male_cling.get("frames", null) != null)
	var femboy_stand: Dictionary = PUWCastRigLoader.build_rider_frames("custom_femboy", "climb_stand")
	_check("custom_femboy_climb_stand_bound_round5", str(femboy_stand.get("status", "")) == "bound" and int(femboy_stand.get("frame_count", -1)) == 1 and femboy_stand.get("frames", null) != null)
	var futanari_stand: Dictionary = PUWCastRigLoader.build_rider_frames("custom_futanari", "climb_stand")
	_check("custom_futanari_climb_stand_bound_round5", str(futanari_stand.get("status", "")) == "bound" and int(futanari_stand.get("frame_count", -1)) == 1 and futanari_stand.get("frames", null) != null)
	var rider_data: Dictionary = PUWCastRegistry.load_json("res://systems/cast/rider_frame_data.json")
	var spares: Dictionary = rider_data.get("spares", {})
	var spare_frames: Array = spares.get("frames", [])
	var spares_marked: bool = spare_frames.size() == 4
	for spare_value: Variant in spare_frames:
		var spare_rec: Dictionary = spare_value
		if str(spare_rec.get("binding_status", "")) != "spare_not_active_binding":
			spares_marked = false
	_check("round5_spares_stored_marked_not_active", spares_marked)
	var female_cling_entry: Dictionary = (rider_data.get("cast", {}) as Dictionary).get("custom_female", {})
	var female_cling_pose: Dictionary = (female_cling_entry as Dictionary).get("climb_cling", {})
	_check("custom_female_climb_cling_active_still_layered_round4", str(female_cling_pose.get("source_round", "")) == "qa_round4_layered")
	var tasha_cast: Dictionary = (rider_data.get("cast", {}) as Dictionary).get("tasha", {})
	var hover_entry: Dictionary = (tasha_cast as Dictionary).get("hover_descend", {})
	var hover_frames: Array = hover_entry.get("frames", [])
	var hover_f2_canvas_ok: bool = false
	if hover_frames.size() == 2:
		var f2_rec: Dictionary = hover_frames[1]
		var f2_canvas: Array = f2_rec.get("canvas", [])
		hover_f2_canvas_ok = str(f2_rec.get("role", "")) == "touching_down" and f2_canvas.size() == 2 and int(f2_canvas[0]) == 285 and int(f2_canvas[1]) == 266
	_check("tasha_hover_descend_f2_on_shared_canvas", hover_f2_canvas_ok)
	# --- QA round 6 canon supersedes and singles (2026-11-23). ---
	var riley_cast: Dictionary = (rider_data.get("cast", {}) as Dictionary).get("riley", {})
	var riley_seated: Dictionary = (riley_cast as Dictionary).get("ride_land_seated", {})
	_check("riley_canon_seated_superseded_round6", str(riley_seated.get("source_round", "")) == "qa_round6_layered")
	var tasha_seated: Dictionary = (tasha_cast as Dictionary).get("ride_land_seated", {})
	_check("tasha_canon_seated_superseded_round6", str(tasha_seated.get("source_round", "")) == "qa_round6_layered")
	var riley_gallop: Dictionary = PUWCastRigLoader.build_rider_frames("riley", "ride_land_gallop")
	_check("riley_gallop_pair_complete_round6", str(riley_gallop.get("status", "")) == "bound" and int(riley_gallop.get("frame_count", -1)) == 2 and riley_gallop.get("frames", null) != null)
	var riley_stand: Dictionary = PUWCastRigLoader.build_rider_frames("riley", "climb_stand")
	_check("riley_climb_stand_bound_round6", str(riley_stand.get("status", "")) == "bound" and int(riley_stand.get("frame_count", -1)) == 1 and riley_stand.get("frames", null) != null)
	var tasha_stand: Dictionary = PUWCastRigLoader.build_rider_frames("tasha", "climb_stand")
	_check("tasha_climb_stand_bound_round6", str(tasha_stand.get("status", "")) == "bound" and int(tasha_stand.get("frame_count", -1)) == 1 and tasha_stand.get("frames", null) != null)
	var male_cast: Dictionary = (rider_data.get("cast", {}) as Dictionary).get("custom_male", {})
	var male_cling_pose: Dictionary = (male_cast as Dictionary).get("climb_cling", {})
	var male_cling_frames: Array = male_cling_pose.get("frames", [])
	var male_cling_active_v2: bool = false
	if male_cling_frames.size() == 1:
		var mc_rec: Dictionary = male_cling_frames[0]
		male_cling_active_v2 = str(mc_rec.get("source", "")) == "round6_single"
	_check("custom_male_climb_cling_active_is_v2_round6", male_cling_active_v2 and str(male_cling_pose.get("source_round", "")) == "qa_round6_single")
	var custom_hover: Dictionary = PUWCastRigLoader.build_rider_frames("custom_female", "hover_stand")
	_check("custom_female_hover_stand_bound_generic", str(custom_hover.get("status", "")) == "bound" and str(custom_hover.get("pose_set", "")) == "generic" and int(custom_hover.get("frame_count", -1)) == 2)
	var custom_wave: Dictionary = PUWCastRigLoader.build_rider_frames("custom_male", "mount_wave")
	_check("custom_male_mount_wave_not_in_set", str(custom_wave.get("status", "")) == "not_in_set" and int(custom_wave.get("frame_count", -1)) == 0)

	# Per-set personality text actually landed: hover_stand differs in all three sets.
	var hover_riley: String = PUWCastRegistry.rider_pose_description_for_set("riley", "hover_stand")
	var hover_tasha: String = PUWCastRegistry.rider_pose_description_for_set("tasha", "hover_stand")
	var hover_generic: String = PUWCastRegistry.rider_pose_description_for_set("generic", "hover_stand")
	_check("hover_stand_descriptions_nonempty", hover_riley != "" and hover_tasha != "" and hover_generic != "")
	_check("hover_stand_riley_not_tasha", hover_riley != hover_tasha)
	_check("hover_stand_riley_not_generic", hover_riley != hover_generic)
	_check("hover_stand_tasha_not_generic", hover_tasha != hover_generic)

	# Per-set coverage: riley sees mount_wave, tasha does not; custom sees 13.
	var riley_cov: Dictionary = rider_cov.get("riley", {})
	_check("rider_coverage_riley_14", riley_cov.size() == 14 and riley_cov.has("mount_wave"))
	_check("rider_coverage_tasha_14_no_mount_wave", tasha_cov.size() == 14 and not tasha_cov.has("mount_wave") and tasha_cov.has("hover_descend"))
	var custom_cov: Dictionary = rider_cov.get("custom_female", {})
	_check("rider_coverage_generic_13", custom_cov.size() == 13 and not custom_cov.has("mount_wave") and not custom_cov.has("hover_descend"))

	# --- Rider poses stay OUT of the existing STATES array. ---
	var states: Array = PUWCastRegistry.states()
	_check("states_still_exactly_8", states.size() == 8)
	var leaked: bool = false
	for pose_value: Variant in EXPECTED_POSES:
		if states.has(str(pose_value)):
			leaked = true
	_check("no_rider_pose_in_states", not leaked)

	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(0 if _failed == 0 else 1)
