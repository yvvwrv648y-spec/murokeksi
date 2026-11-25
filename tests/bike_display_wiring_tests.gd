extends SceneTree
## Bicycle display wiring tests (systems activation fix, 2026-11-24).
## Verifies the player-controller bicycle display hook: mounting a
## solo bicycle swaps the ride-cycle art onto the player sprite,
## and dismounting restores the cast frames.
## Run: godot --headless --script res://tests/bike_display_wiring_tests.gd
## Prints one PASS/FAIL line per check, then a summary. Exit 0 only
## if every check passes. Drop into res://tests/ alongside the
## player_controller.gd patch in this fix packet.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		print("FAIL: " + name + ((" — " + detail) if detail != "" else ""))


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var player: PUWPlayerController = PUWPlayerController.new()
	root.add_child(player)
	await process_frame

	player.set_cast("riley")
	_check("cast_frames_bound", player._cast_frames != null)
	_check("no_bike_art_before_mount", not player.bike_art_active())

	var mounted: bool = player.mount_bicycle_for_cast("riley")
	_check("mount_bicycle_for_cast_ok", mounted)
	_check("bike_display_loaded", str(player.bike_display().get("status", "")) == "loaded", str(player.bike_display()))
	_check("bike_art_active_after_mount", player.bike_art_active())
	var frames: SpriteFrames = player._sprite.sprite_frames
	_check("sprite_has_bike_anim", frames != null and frames.has_animation("bike"))
	_check("sprite_has_bike_down_anim", frames != null and frames.has_animation("bike_down"))
	_check("bike_anim_has_frames", frames != null and frames.has_animation("bike") and frames.get_frame_count("bike") > 0)

	player.dismount_bicycle()
	_check("bike_art_inactive_after_dismount", not player.bike_art_active())
	_check("cast_frames_restored_after_dismount", player._sprite.sprite_frames == player._cast_frames)

	# Cast change while mounted re-resolves the NEW cast's rig.
	player.mount_bicycle_for_cast("riley")
	player.set_cast("tasha")
	_check("bike_art_active_after_cast_change", player.bike_art_active(), str(player.bike_display()))
	player.dismount_bicycle()

	# Unknown bicycle id is refused and changes no display state.
	var refused: bool = player.mount_bicycle("not_a_bicycle")
	_check("unknown_bicycle_refused", not refused and not player.bike_art_active())

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
