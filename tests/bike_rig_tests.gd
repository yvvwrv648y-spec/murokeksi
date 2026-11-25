extends SceneTree
## Bike rig tests for Pokemon Ultimate World.
## Run: godot --headless --script tests/bike_rig_tests.gd
##
## Proves: sliced bike frames load for all 6 cast members (solo),
## tandem frames load for named pairings, the unoccupied-bike hero
## panels are excluded from ride cycles, and the EXISTING tandem
## co-op lock in PUWBikes still holds with real art bound through
## PUWBikeRigFacade.
##
## QA ROUND 5 (2026-11-23): the tandem_female_tasha side-2 LEFT
## redo was graded PASS (qa_round5/verdicts/rides_tandem.md) and
## bound as frame index 4 by tools/slice_qa_art_round5.py, so the
## custom_female>tasha pairing's ride cycle is now complete at 4
## frames. The partial-cycle assertion below was converted in
## place to the new truth (3 -> 4 frames, no count change) and
## ONE assertion was added for the new frame record (baseline
## 30 -> 31).
##
## QA ROUND 6 (2026-11-23): the shared-grid bike delivery was
## graded (qa_round6/verdicts_bikes_core.md + bikes_custom.md).
## The three CHASSIS sheets are certified (16/16 cells each) and
## their frames are recorded in the layered_chassis_round6
## section of bike_frame_data.json; ZERO rider stacks passed, so
## no rider assertion changes -- the flat bindings stand. New
## assertions (+4, baseline 31 -> 35): the chassis section holds
## exactly 3 sheets, and each sheet records 16 frames whose PNG
## files all exist.
##
## REGISTRY COMPLETION (2026-11-23): bicycle_registry.json now
## carries dedicated entries for the Femboy and Futanari presets
## (custom_femboy_solo/tandem, custom_futanari_solo/tandem) and
## PUWBikes resolves those cast members to their own bikes
## instead of custom_fem_*. New assertions (+3, baseline
## 35 -> 38): the solo resolver, the tandem resolver, and the
## registry themes for the two new presets.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _finish() -> void:
	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)


func _init() -> void:
	print("PUW bike rig tests - starting.")

	# --- frame data present ---
	var data: Dictionary = PUWBikeRigLoader._load_data()
	_check("bike_frame_data_loaded", not data.is_empty())
	var sheets: Dictionary = data.get("sheets", {})
	_check("all_transportation_sheets_sliced", sheets.size() >= 30)
	_check("ride_fps_is_run_rate_11", absf(PUWBikeRigLoader.ride_fps() - 11.0) < 0.001)

	# --- solo frames load for all 6 cast members ---
	var cast_ids: Array = ["riley", "tasha", "custom_female", "custom_male", "custom_femboy", "custom_futanari"]
	for cast_value: Variant in cast_ids:
		var cast_id: String = str(cast_value)
		var rig: Dictionary = PUWBikeRigLoader.build_solo_frames(cast_id)
		_check("solo_frames_" + cast_id, str(rig.get("status", "")) == "loaded" and int(rig.get("frame_count", 0)) > 0)
		var frames_obj: Variant = rig.get("frames", null)
		if frames_obj is SpriteFrames:
			var sf: SpriteFrames = frames_obj
			_check("solo_spriteframes_" + cast_id, sf.get_frame_count(PUWBikeRigLoader.ANIM_RIDE) == int(rig.get("frame_count", 0)))

	# --- hero panels excluded from every solo cycle ---
	var solo_res: Dictionary = data.get("solo_resolution", {})
	var hero_in_cycle: bool = false
	for cast_value2: Variant in cast_ids:
		var entry: Dictionary = solo_res.get(str(cast_value2), {})
		var indices: Array = entry.get("frame_indices", [])
		if indices.has(2):
			hero_in_cycle = true
	_check("unoccupied_hero_excluded_from_solo_cycles", not hero_in_cycle)
	var excluded: Array = data.get("excluded_panels", [])
	_check("excluded_panels_listed", excluded.size() >= 30)

	# --- tandem frames load for riley+tasha (both directions) ---
	var pairings: Array = PUWBikeRigLoader.tandem_pairings()
	_check("tandem_pairings_named_18", pairings.size() == 18)
	var rt: Dictionary = PUWBikeRigLoader.build_tandem_frames("riley", "tasha")
	_check("tandem_frames_riley_driver_tasha_passenger", str(rt.get("status", "")) == "loaded" and int(rt.get("frame_count", 0)) > 0)
	var tr: Dictionary = PUWBikeRigLoader.build_tandem_frames("tasha", "riley")
	_check("tandem_frames_tasha_driver_riley_passenger", str(tr.get("status", "")) == "loaded" and int(tr.get("frame_count", 0)) > 0)
	# tandem_female_tasha: QA round 5 bound the missing side-2
	# LEFT view as frame index 4 -- the cycle is complete at 4.
	var ft: Dictionary = PUWBikeRigLoader.build_tandem_frames("custom_female", "tasha")
	_check("tandem_frames_female_driver_tasha_passenger_complete_round5", str(ft.get("status", "")) == "loaded" and int(ft.get("frame_count", 0)) == 4)
	var ft_sheet: Dictionary = sheets.get("systems/transportation/tandem_female_tasha_sheet.png", {})
	var ft_frames: Array = ft_sheet.get("frames", [])
	var f04_in_cycle: bool = false
	for ft_value: Variant in ft_frames:
		var ft_rec: Dictionary = ft_value
		if int(ft_rec.get("index", -1)) == 4 and bool(ft_rec.get("in_ride_cycle", false)):
			f04_in_cycle = true
	_check("tandem_female_tasha_f04_in_ride_cycle_round5", f04_in_cycle)
	var unnamed: Dictionary = PUWBikeRigLoader.build_tandem_frames("custom_male", "custom_female")
	_check("tandem_unnamed_custom_pairing_refused", str(unnamed.get("status", "")) == "unnamed_pairing")

	# --- QA round 6 layered chassis frames (chassis ONLY). ---
	var chassis_section: Dictionary = data.get("layered_chassis_round6", {})
	var chassis_sheets: Dictionary = chassis_section.get("sheets", {})
	_check("round6_chassis_section_three_sheets", chassis_sheets.size() == 3)
	var chassis_stems: Array = ["bike_chassis_acro_solo_4x4", "bike_chassis_mach_solo_4x4_v2", "bike_chassis_tandem_4x4_v2"]
	for stem_value: Variant in chassis_stems:
		var stem: String = str(stem_value)
		var sheet_rec: Dictionary = chassis_sheets.get("systems/transportation/layered_chassis_round6/" + stem, {})
		var sheet_frames: Array = sheet_rec.get("frames", [])
		var files_ok: bool = sheet_frames.size() == 16
		for frame_value: Variant in sheet_frames:
			var frame_rec: Dictionary = frame_value
			if not FileAccess.file_exists("res://" + str(frame_rec.get("png", ""))):
				files_ok = false
		_check("round6_chassis_frames_" + stem, files_ok)

	# --- the EXISTING tandem lock still holds (real bikes.gd API) ---
	_check("lock_tandem_refused_without_coop", PUWBikes.tandem_available(false) == false)
	_check("lock_tandem_allowed_with_coop", PUWBikes.tandem_available(true) == true)
	var locked_rig: Dictionary = PUWBikeRigFacade.tandem_rig("riley", "tasha", false)
	_check("facade_tandem_rig_locked_without_coop", str(locked_rig.get("status", "")) == "locked_coop_inactive" and int(locked_rig.get("frame_count", 0)) == 0)
	var open_rig: Dictionary = PUWBikeRigFacade.tandem_rig("riley", "tasha", true)
	_check("facade_tandem_rig_loaded_with_coop", str(open_rig.get("status", "")) == "loaded" and int(open_rig.get("frame_count", 0)) > 0)

	# --- solo ride allowed regardless of co-op, speeds intact ---
	_check("solo_bicycle_ids_present", PUWBikes.solo_bicycle_id_for("riley") == "riley_solo" and PUWBikes.solo_bicycle_id_for("custom_male") == "custom_masc_solo")
	_check("solo_bicycle_ids_new_presets", PUWBikes.solo_bicycle_id_for("custom_femboy") == "custom_femboy_solo" and PUWBikes.solo_bicycle_id_for("custom_futanari") == "custom_futanari_solo")
	_check("tandem_bicycle_ids_new_presets", PUWBikes.tandem_bicycle_id_for("custom_femboy") == "custom_femboy_tandem" and PUWBikes.tandem_bicycle_id_for("custom_futanari") == "custom_futanari_tandem")
	_check("themes_new_presets_from_registry", PUWBikes.solo_theme_for("custom_femboy").contains("Femboy Scheme") and PUWBikes.solo_theme_for("custom_futanari").contains("Futanari Scheme") and PUWBikes.tandem_theme("custom_femboy").contains("Two-Seater") and PUWBikes.tandem_theme("custom_futanari").contains("Two-Seater"))
	_check("speed_acro_10_67", absf(PUWBikes.speed_for(PUWBikes.MODE_SOLO_ACRO) - 10.67) < 0.001)
	_check("speed_mach_16_0", absf(PUWBikes.speed_for(PUWBikes.MODE_SOLO_MACH) - 16.0) < 0.001)
	var solo_rig: Dictionary = PUWBikeRigFacade.solo_rig("riley")
	_check("facade_solo_rig_no_coop_needed", str(solo_rig.get("status", "")) == "loaded")

	_finish()
