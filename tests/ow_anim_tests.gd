extends SceneTree
## Overworld movement-animation prep tests.
## Run: godot --headless --script res://tests/ow_anim_tests.gd
##
## Proves, on REAL held sheets copied into this project:
## - PUWOWAnimator slices each held sheet format into the
##   "<state>_<facing>" clips the overworld state machine
##   plays, with the right frame counts and the right atlas
##   row per direction (EBDX charset 256x256, MDX walk atlas
##   504x504, NPC bank sheet 96x128, HGSS per-frame files).
## - PUWNPCSpriteView / PUWFollowerSpriteView pick the right
##   clip per state, facing, and behavior record.
## - Playback actually ADVANCES: a playing view's frame index
##   changes over process frames, per state and per direction.

var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _region_of(frames: SpriteFrames, clip: String, frame_idx: int) -> Rect2:
	var tex_value: Variant = frames.get_frame_texture(clip, frame_idx)
	if tex_value is AtlasTexture:
		var atlas: AtlasTexture = tex_value
		return atlas.region
	return Rect2()


func _init() -> void:
	_run()


func _run() -> void:
	var ebdx_tex: Texture2D = load("res://art_samples/ebdx_charset.png")
	var mdx_tex: Texture2D = load("res://art_samples/mdx_walk.png")
	var npc_tex: Texture2D = load("res://art_samples/npc_bank.png")
	_check(ebdx_tex != null and mdx_tex != null and npc_tex != null, "sample sheets load")

	# --- EBDX charset: 4x4, 64 px cells, rows down/left/right/up.
	var ebdx: SpriteFrames = PUWOWAnimator.charset_frames(ebdx_tex, 4, 4)
	var ebdx_clips: int = 0
	for state_name in ["idle", "walk", "run"]:
		for dir_name in ["down", "up", "left", "right"]:
			if ebdx.has_animation(state_name + "_" + dir_name):
				ebdx_clips += 1
	_check(ebdx_clips == 12, "ebdx: 12 clips (idle/walk/run x 4 dirs), got %d" % ebdx_clips)
	for dir_name in ["down", "up", "left", "right"]:
		_check(ebdx.get_frame_count("walk_" + dir_name) == 4, "ebdx walk_%s has 4 frames" % dir_name)
		_check(ebdx.get_frame_count("idle_" + dir_name) == 1, "ebdx idle_%s has 1 frame" % dir_name)
	_check(_region_of(ebdx, "walk_down", 0).position == Vector2(0, 0), "ebdx down row at y=0")
	_check(_region_of(ebdx, "walk_left", 0).position == Vector2(0, 64), "ebdx left row at y=64")
	_check(_region_of(ebdx, "walk_right", 0).position == Vector2(0, 128), "ebdx right row at y=128")
	_check(_region_of(ebdx, "walk_up", 0).position == Vector2(0, 192), "ebdx up row at y=192")
	_check(_region_of(ebdx, "idle_down", 0).position == Vector2(64, 0), "ebdx idle is the standing frame (col 1)")
	_check(is_equal_approx(ebdx.get_animation_speed("walk_down"), 7.5), "ebdx walk fps 7.5")
	_check(is_equal_approx(ebdx.get_animation_speed("run_down"), 11.0), "ebdx run fps 11.0")

	# --- MDX walk atlas: 504x504, 4x4, 126 px cells.
	var mdx: SpriteFrames = PUWOWAnimator.charset_frames(mdx_tex, 4, 4)
	_check(mdx.get_frame_count("walk_up") == 4, "mdx walk_up has 4 frames")
	_check(_region_of(mdx, "walk_up", 0).position == Vector2(0, 378), "mdx up row at y=378 (126 px cells)")

	# --- NPC bank sheet: 96x128, 3 cols x 4 rows, 32 px cells.
	var npc: SpriteFrames = PUWOWAnimator.charset_frames(npc_tex, 3, 4)
	_check(npc.get_frame_count("walk_down") == 4, "npc walk cycle is [0,1,2,1] = 4 frames")
	_check(_region_of(npc, "walk_down", 2).position == Vector2(64, 0), "npc walk frame 2 at x=64")
	_check(_region_of(npc, "walk_down", 3).position == Vector2(32, 0), "npc walk frame 3 returns to centre frame")
	_check(_region_of(npc, "idle_left", 0).position == Vector2(32, 32), "npc idle_left is centre frame of left row")

	# --- HGSS per-frame files: 2 steps per direction.
	var by_dir: Dictionary = {}
	for dir_name in ["down", "up", "left", "right"]:
		var list: Array = []
		for i in [1, 2]:
			var t: Texture2D = load("res://art_samples/hgss_%s_%d.png" % [dir_name, i])
			list.append(t)
		by_dir[dir_name] = list
	var hgss: SpriteFrames = PUWOWAnimator.frame_list_frames(by_dir)
	_check(hgss.get_frame_count("walk_down") == 2, "hgss walk_down has 2 step frames")
	_check(hgss.get_frame_count("idle_up") == 1, "hgss idle_up has 1 frame")
	_check(hgss.get_frame_texture("walk_left", 0) == by_dir["left"][0], "hgss walk_left uses the left files, not another row")

	# --- NPC view: facing + movement pick the clip.
	var npc_view: PUWNPCSpriteView = PUWNPCSpriteView.new()
	root.add_child(npc_view)
	_check(npc_view.setup_sheet(npc_tex, "adaman"), "npc view setup_sheet")
	npc_view.face("left")
	npc_view.set_moving(true)
	_check(npc_view.current_clip() == "walk_left", "npc view plays walk_left, got %s" % npc_view.current_clip())
	npc_view.set_moving(false)
	_check(npc_view.current_clip() == "idle_left", "npc view idles facing left, got %s" % npc_view.current_clip())
	var npc_missing: PUWNPCSpriteView = PUWNPCSpriteView.new()
	root.add_child(npc_missing)
	_check(not npc_missing.setup_bank("no_such_npc_id"), "npc view refuses an id with no bank sheet")
	_check(npc_missing.sheet_status == "no_sheet", "npc missing sheet is honestly reported")

	# --- Follower view: behavior records pick clips + facing.
	var fol_view: PUWFollowerSpriteView = PUWFollowerSpriteView.new()
	root.add_child(fol_view)
	_check(fol_view.setup_charset(ebdx_tex), "follower view setup_charset")
	fol_view.apply_behavior({"pos": Vector2(40, 24), "animation": "walk", "facing_dir": Vector2(1, 0), "visual_offset_y": 0.0}, "down")
	_check(fol_view.current_clip() == "walk_right", "follower walk + facing_dir right -> walk_right, got %s" % fol_view.current_clip())
	_check(fol_view.position == Vector2(40, 24), "follower view takes the record position")
	fol_view.apply_behavior({"pos": Vector2(40, 24), "animation": "swim", "facing_dir": Vector2(0, -1), "visual_offset_y": 0.0}, "down")
	_check(fol_view.current_clip() == "walk_up", "follower swim plays the walk row facing up, got %s" % fol_view.current_clip())
	fol_view.apply_behavior({"pos": Vector2(40, 24), "animation": "hover_idle", "facing_dir": Vector2.ZERO, "visual_offset_y": -3.0}, "left")
	_check(fol_view.current_clip() == "idle_left", "follower hover_idle -> idle_left (trainer facing), got %s" % fol_view.current_clip())
	_check(fol_view.position == Vector2(40, 21), "follower view applies visual_offset_y")

	# --- Playback: frame indices advance per state + direction.
	var play_view: PUWOWSpriteView = PUWOWSpriteView.new()
	root.add_child(play_view)
	play_view.set_ow_frames(ebdx)
	ebdx.set_animation_speed("walk_down", 60.0)
	ebdx.set_animation_speed("walk_up", 60.0)
	play_view.play_ow("walk", "down")
	var seen_down: Dictionary = {}
	for i in range(40):
		await process_frame
		seen_down[play_view.current_frame_index()] = true
	_check(seen_down.size() >= 3, "walk_down frame index advances (>=3 distinct frames), saw %s" % str(seen_down.keys()))
	_check(play_view.current_clip() == "walk_down", "still playing walk_down")
	play_view.play_ow("walk", "up")
	_check(play_view.current_clip() == "walk_up", "direction switch plays walk_up")
	var seen_up: Dictionary = {}
	for i in range(40):
		await process_frame
		seen_up[play_view.current_frame_index()] = true
	_check(seen_up.size() >= 3, "walk_up frame index advances, saw %s" % str(seen_up.keys()))
	var up_tex: Texture2D = play_view.sprite_frames.get_frame_texture(play_view.current_clip(), play_view.current_frame_index())
	_check(up_tex is AtlasTexture and (up_tex as AtlasTexture).region.position.y == 192.0, "playing frame comes from the up row while walking up")

	print("OW_ANIM_TESTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
