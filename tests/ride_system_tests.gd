extends SceneTree
## Rideable Pokemon tests for Pokemon Ultimate World (Phase 3, item B).
## Run: godot --headless --script res://tests/ride_system_tests.gd
##
## Covers PUWRideSystem eligibility (data-derived rules + the
## documented canon table), badge-locked crossings through
## PUWFieldActions, mount/dismount follower transitions, pose
## binding, per-mode speeds, and PUWPlayerController terrain
## enforcement on synthetic maps (water / gap tiles).

var _passed: int = 0
var _failed: int = 0

var _loader: PUWMapLoader = null
var _player: PUWPlayerController = null


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _finish() -> void:
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _init() -> void:
	_run.call_deferred()


func _party(slugs: Array) -> Array:
	var party: Array = []
	for slug_value: Variant in slugs:
		party.append({"species": str(slug_value)})
	return party


func _setup_world() -> void:
	_loader = PUWMapLoader.new()
	root.add_child(_loader)
	_player = PUWPlayerController.new()
	_player.input_enabled = false
	root.add_child(_player)
	_player.setup(_loader)


func _step_many(dir: Vector2, mode: String, count: int) -> void:
	for i in range(count):
		_player.step(0.05, dir, mode)


func _run() -> void:
	print("PUW ride system tests - starting.")
	_setup_world()

	# ---------- Eligibility: canon hover (Metagross) ----------
	var metagross_modes: Array = PUWRideSystem.eligible_modes("metagross")
	_check("metagross_hover_carrying", metagross_modes.has("hover_carrying"), "modes=" + str(metagross_modes))
	_check("metagross_hover_basis_is_canon", PUWRideSystem.basis_for("metagross", "hover_carrying") == "canon: Riley canon example, 2026-11-22", PUWRideSystem.basis_for("metagross", "hover_carrying"))
	_check("metagross_land_riding_by_weight", metagross_modes.has("land_riding"))

	# ---------- Eligibility: Lapras surf + ferry ----------
	var lapras_modes: Array = PUWRideSystem.eligible_modes("lapras")
	_check("lapras_surfing", lapras_modes.has("surfing"))
	_check("lapras_ferrying", lapras_modes.has("ferrying"))
	_check("lapras_diving", lapras_modes.has("diving"))
	_check("lapras_waterfall", lapras_modes.has("climbing_waterfall"))
	_check("lapras_not_land_aquatic_only", not lapras_modes.has("land_riding"))

	# ---------- Eligibility: flight split (Pidgey) ----------
	var pidgey_modes: Array = PUWRideSystem.eligible_modes("pidgey")
	_check("pidgey_carried_flight", pidgey_modes.has("carried_flight"), "modes=" + str(pidgey_modes))
	_check("pidgey_not_mounted_flight", not pidgey_modes.has("mounted_flight"))
	var charizard_modes: Array = PUWRideSystem.eligible_modes("charizard")
	_check("charizard_mounted_flight", charizard_modes.has("mounted_flight"))
	_check("charizard_not_carried_flight", not charizard_modes.has("carried_flight"))

	# ---------- Eligibility: Magikarp gets nothing ----------
	var magikarp_modes: Array = PUWRideSystem.eligible_modes("magikarp")
	_check("magikarp_no_ride_modes", magikarp_modes.is_empty(), "modes=" + str(magikarp_modes))

	# ---------- Eligibility: Machamp held + misc rules ----------
	var machamp_modes: Array = PUWRideSystem.eligible_modes("machamp")
	_check("machamp_held_carrying", machamp_modes.has("held_carrying"), "modes=" + str(machamp_modes))
	_check("onix_burrowing_and_cliff", PUWRideSystem.eligible_modes("onix").has("burrowing") and PUWRideSystem.eligible_modes("onix").has("climbing_cliff"))
	_check("gastly_hover_via_recorded_levitate", PUWRideSystem.eligible_modes("gastly").has("hover_carrying") and PUWRideSystem.basis_for("gastly", "hover_carrying") == "data_rule")
	_check("unknown_species_no_modes", PUWRideSystem.eligible_modes("notarealspecies").is_empty())
	_check("dex_int_resolves", PUWRideSystem.eligible_modes(131).has("surfing"))

	# ---------- can_mount ----------
	var lapras_party: Array = _party(["lapras"])
	var mount_state: Dictionary = {"badges": [], "followers": []}
	_check("can_mount_lapras_surf_ok", bool(PUWRideSystem.can_mount(mount_state, lapras_party, "lapras", "surfing").get("allowed", false)))
	_check("can_mount_lapras_land_refused", str(PUWRideSystem.can_mount(mount_state, lapras_party, "lapras", "land_riding").get("reason", "")) == "not_eligible")
	_check("can_mount_not_in_party", str(PUWRideSystem.can_mount(mount_state, lapras_party, "machamp", "held_carrying").get("reason", "")) == "not_in_party")
	_check("can_mount_unknown_mode", str(PUWRideSystem.can_mount(mount_state, lapras_party, "lapras", "teleporting").get("reason", "")) == "unknown_mode")

	# ---------- Badge-locked crossings: surf ----------
	var no_badge_state: Dictionary = {"badges": []}
	var surf_refused: Dictionary = PUWRideSystem.attempt_crossing(no_badge_state, lapras_party, "surfing", "water")
	_check("surf_crossing_refused_without_soul_badge", not bool(surf_refused.get("allowed", true)) and str(surf_refused.get("reason", "")) == "badge_missing" and str(surf_refused.get("action", "")) == "surf", str(surf_refused))
	var soul_state: Dictionary = {"badges": ["kanto_gym_5_koga"]}
	var surf_allowed: Dictionary = PUWRideSystem.attempt_crossing(soul_state, lapras_party, "surfing", "water")
	_check("surf_crossing_allowed_with_soul_badge", bool(surf_allowed.get("allowed", false)) and str(surf_allowed.get("action", "")) == "surf", str(surf_allowed))

	# ---------- Badge-locked crossings: hover / fly ----------
	var gastly_party: Array = _party(["gastly"])
	var hover_refused: Dictionary = PUWRideSystem.attempt_crossing(no_badge_state, gastly_party, "hover_carrying", "gap")
	_check("hover_crossing_refused_without_thunder_badge", not bool(hover_refused.get("allowed", true)) and str(hover_refused.get("reason", "")) == "badge_missing" and str(hover_refused.get("action", "")) == "fly", str(hover_refused))
	var thunder_state: Dictionary = {"badges": ["kanto_gym_3_surge"]}
	var hover_allowed: Dictionary = PUWRideSystem.attempt_crossing(thunder_state, gastly_party, "hover_carrying", "gap")
	_check("hover_crossing_allowed_with_thunder_badge", bool(hover_allowed.get("allowed", false)) and str(hover_allowed.get("action", "")) == "fly", str(hover_allowed))

	# ---------- Land riding needs no badge ----------
	var snorlax_party: Array = _party(["snorlax"])
	var land_crossing: Dictionary = PUWRideSystem.attempt_crossing(no_badge_state, snorlax_party, "land_riding", "open_ground")
	_check("land_riding_open_ground_no_badge", bool(land_crossing.get("allowed", false)) and str(land_crossing.get("action", "")) == "", str(land_crossing))
	_check("crossing_action_map", PUWRideSystem.crossing_action("climbing_waterfall") == "waterfall" and PUWRideSystem.crossing_action("climbing_cliff") == "rock_smash" and PUWRideSystem.crossing_action("burrowing") == "dig" and PUWRideSystem.crossing_action("held_carrying") == "strength" and PUWRideSystem.crossing_action("land_riding") == "")

	# ---------- Mount -> follower leaves -> dismount -> returns ----------
	var ride_state: Dictionary = {"badges": [], "cast_id": "tasha", "followers": ["metagross", "pikachu"]}
	var meta_party: Array = _party(["metagross", "pikachu"])
	var mounted: Dictionary = PUWRideSystem.mount(ride_state, meta_party, "metagross", "hover_carrying")
	_check("mount_metagross_hover_ok", bool(mounted.get("allowed", false)), str(mounted))
	_check("mount_records_state", str(PUWRideSystem.current_mount(ride_state).get("species", "")) == "metagross" and str(PUWRideSystem.current_mount(ride_state).get("mode", "")) == "hover_carrying")
	var followers_after_mount: Array = ride_state.get("followers", [])
	_check("mount_removes_follower", not followers_after_mount.has("metagross") and followers_after_mount.has("pikachu"), str(followers_after_mount))
	var dismounted: Dictionary = PUWRideSystem.dismount(ride_state)
	var followers_after_dismount: Array = ride_state.get("followers", [])
	_check("dismount_returns_follower", bool(dismounted.get("allowed", false)) and bool(dismounted.get("returned_to_followers", false)) and followers_after_dismount.has("metagross"), str(followers_after_dismount))
	_check("dismount_clears_mount", PUWRideSystem.current_mount(ride_state).is_empty())
	_check("dismount_when_not_mounted_refused", str(PUWRideSystem.dismount(ride_state).get("reason", "")) == "not_mounted")
	# Full follower line: no room to return.
	var full_state: Dictionary = {"badges": [], "followers": ["metagross"]}
	PUWRideSystem.mount(full_state, meta_party, "metagross", "hover_carrying")
	full_state["followers"] = ["pikachu", "rattata", "eevee", "aron", "ralts", "mareep"]
	var full_dismount: Dictionary = PUWRideSystem.dismount(full_state)
	_check("dismount_full_line_no_return", bool(full_dismount.get("allowed", false)) and not bool(full_dismount.get("returned_to_followers", true)))

	# ---------- Pose binding: Tasha + Metagross ----------
	_check("mount_pose_tasha_metagross", str(mounted.get("pose", "")) == "hover_stand" and str(mounted.get("pose_set", "")) == "tasha" and str(mounted.get("art_status", "")) == "bound", str(mounted))
	var binding: Dictionary = PUWRideSystem.pose_binding("tasha", "hover_carrying")
	_check("pose_binding_tasha_hover", str(binding.get("pose", "")) == "hover_stand" and str(binding.get("pose_set", "")) == "tasha" and str(binding.get("art_status", "")) == "bound" and int(binding.get("frame_count", -1)) == 2, str(binding))

	# ---------- Speeds are data, controller matches ----------
	_check("speed_data_surf_6", absf(PUWRideSystem.speed_for_mode("surfing") - 6.0) < 0.001)
	_check("speed_data_hover_8", absf(PUWRideSystem.speed_for_mode("hover_carrying") - 8.0) < 0.001)
	_check("speed_data_mounted_flight_12", absf(PUWRideSystem.speed_for_mode("mounted_flight") - 12.0) < 0.001)
	for mode_value: Variant in PUWCastRegistry.ride_mode_ids():
		var mode_id: String = str(mode_value)
		_check("speed_positive_" + mode_id, PUWRideSystem.speed_for_mode(mode_id) > 0.0)

	# ---------- Controller: water / gap on synthetic maps ----------
	var water_terrain: Dictionary = {Vector2i(5, 2): "water", Vector2i(6, 2): "water"}
	_loader.setup_synthetic_map(11, 5, water_terrain)
	_player.dismount_pokemon()
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_water_refused_on_foot", _player.player_tile().x <= 4 and _player.last_block_reason == "requires_water_mount", "tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_loader.setup_synthetic_map(11, 5, water_terrain)
	_check("controller_mount_lapras_surf", _player.mount_pokemon("lapras", "surfing"))
	_check("controller_mounted_speed_matches_mode", absf(_player.mounted_speed() - PUWRideSystem.speed_for_mode("surfing")) < 0.001)
	_player.place_at_tile(Vector2i(3, 2))
	var pos_before: Vector2 = _player.position
	_player.step(0.1, Vector2(1, 0), "walk")
	var moved_px: float = _player.position.x - pos_before.x
	_check("controller_step_uses_ride_speed", absf(moved_px - PUWRideSystem.speed_for_mode("surfing") * 8.0 * 0.1) < 0.01, "moved=" + str(moved_px))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_water_crossed_while_surf_mounted", _player.player_tile().x >= 7, "tile=" + str(_player.player_tile()))
	_player.dismount_pokemon()

	var gap_terrain: Dictionary = {Vector2i(5, 2): "gap"}
	_loader.setup_synthetic_map(11, 5, gap_terrain)
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_gap_refused_on_foot", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	_loader.setup_synthetic_map(11, 5, gap_terrain)
	_check("controller_mount_metagross_hover", _player.mount_pokemon("metagross", "hover_carrying"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_gap_crossed_while_hover_mounted", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))
	_player.dismount_pokemon()
	_check("controller_mount_ineligible_refused", _player.mount_pokemon("magikarp", "surfing") == false and not _player.is_mounted())

	_finish()
