extends SceneTree
## VS presentation prep tests (Godot 4.7.2 headless).
##
## Proves, against the REAL held art and the REAL intro index:
##   - the index resolves fronts/strips truthfully (Red 5 frames,
##     Brendan FRLG 4 frames, FALKNER honestly unresolved);
##   - make_throw_frames slices horizontal (Essentials) and
##     vertical (FRLG) strips at the exact atlas regions;
##   - the corrected BattleStageController answers frame counts
##     from the index and its Omni Ring VFX is unchanged;
##   - the patched BattleScene script parses and carries the new
##     intro hand-off statics at their "" defaults;
##   - the full intro sequence runs: trainer front slides in, the
##     player throw strip ADVANCES through its real frames, the
##     player battler release fires only once the strip reaches
##     its release frame, releases land enemy-then-player, the
##     handed-off battler itself animates, and intro_finished
##     fires exactly once -- for trainer, wild, gym/VS, no-strip
##     (gap G-VS2 ball-only), and unresolved-front configs.
## Run: godot --headless --script res://tests/vs_presentation_tests.gd

var _passed: int = 0
var _failed: int = 0

const FAST: Dictionary = {
	"slide_time": 0.05, "hold_time": 0.05, "vs_hold_time": 0.05,
	"ball_time": 0.08, "beat_time": 0.02,
}


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


func _run() -> void:
	_test_index_and_frames()
	_test_stage_controller()
	_test_scene_statics()
	await _test_sequence_trainer()
	await _test_sequence_wild()
	await _test_sequence_no_strip()
	await _test_sequence_gym_vs()
	await _test_sequence_unresolved_front()
	_finish()


# ------------------------------------------------------------ sync tests
func _test_index_and_frames() -> void:
	var index: Dictionary = PUWBattleIntro.load_index()
	_check("index loads", not index.is_empty())
	var strips: Dictionary = index.get("strips", {})
	_check("index holds 92 strips", strips.size() == 92, str(strips.size()))  # build 6 Stage 2B merges (base + Johto + Sevii + enemy set)
	var red: Dictionary = PUWBattleIntro.strip_entry_for("red")
	_check("red strip = 5 frames", int(red.get("frames", 0)) == 5)
	var brendan_frlg: Dictionary = PUWBattleIntro.strip_entry_for("brendan_frlg")
	_check("brendan_frlg strip = 4 frames", int(brendan_frlg.get("frames", 0)) == 4)
	_check("unknown strip resolves empty", PUWBattleIntro.strip_entry_for("nobody").is_empty())
	var youngster: Dictionary = PUWBattleIntro.front_entry_for("YOUNGSTER")
	_check("YOUNGSTER front resolves", not youngster.is_empty(),
		str(youngster.get("source_file", "")))
	_check("FALKNER front resolves (Johto extension, build 6)", not PUWBattleIntro.front_entry_for("FALKNER").is_empty())
	var backs: Dictionary = index.get("protagonist_backs", {})
	_check("riley back resolves (protagonist backs set, build 6)", backs.has("riley") and backs["riley"] != null)
	# Horizontal slicing: red strip is 800x160 -> five 160x160 frames.
	var red_tex: Texture2D = load("res://art/battle_intro/backs/red.png") as Texture2D
	_check("red strip texture loads at 800x160",
		red_tex != null and red_tex.get_size() == Vector2(800, 160))
	var frames: SpriteFrames = PUWBattleIntro.make_throw_frames(red_tex, 5, "horizontal", 10.0)
	_check("horizontal slice makes 5 frames", frames.get_frame_count("throw") == 5)
	var f3: Texture2D = frames.get_frame_texture("throw", 3)
	_check("horizontal frame 3 region is x=480",
		f3 is AtlasTexture and (f3 as AtlasTexture).region == Rect2(480, 0, 160, 160))
	_check("throw animation does not loop", not frames.get_animation_loop("throw"))
	# Vertical slicing: FRLG red is 64x320 -> five 64x64 frames.
	var frlg_tex: Texture2D = load("res://art/battle_intro/backs/red_frlg.png") as Texture2D
	_check("frlg strip texture loads at 64x320",
		frlg_tex != null and frlg_tex.get_size() == Vector2(64, 320))
	var vframes: SpriteFrames = PUWBattleIntro.make_throw_frames(frlg_tex, 5, "vertical", 10.0)
	_check("vertical slice makes 5 frames", vframes.get_frame_count("throw") == 5)
	var v2: Texture2D = vframes.get_frame_texture("throw", 2)
	_check("vertical frame 2 region is y=128",
		v2 is AtlasTexture and (v2 as AtlasTexture).region == Rect2(0, 128, 64, 64))


func _test_stage_controller() -> void:
	var stage := BattleStageController.new()
	_check("stage throw count red = 5 (real strip)", stage.play_trainer_throw("red") == 5)
	_check("stage throw count brendan_frlg = 4 (real strip)", stage.play_trainer_throw("brendan_frlg") == 4)
	_check("stage throw count unknown = 0", stage.play_trainer_throw("nobody") == 0)
	var vfx: Dictionary = stage.trigger_omni_ring_vfx("mega")
	_check("omni ring vfx unchanged", bool(vfx.get("active", false)) and str(vfx.get("aura_hex", "")) == "#ff4da6")
	stage.free()


func _test_scene_statics() -> void:
	_check("BattleScene pending_battle_kind default ''", BattleScene.pending_battle_kind == "")
	_check("BattleScene pending_enemy_trainer_id default ''", BattleScene.pending_enemy_trainer_id == "")
	_check("BattleScene pending_player_back_id default ''", BattleScene.pending_player_back_id == "")
	_check("BattleScene pending_player_front_id default ''", BattleScene.pending_player_front_id == "")


# --------------------------------------------------------- sequence rig
## A spy battler: stands in for the battle scene's battler node.
## When the intro releases its side, the spy starts playing a
## real 2-frame loop -- the same shape as the scene's handoff
## (assign frames, play) -- so the test can prove the handed-off
## battler actually animates.
func _make_spy_battler() -> AnimatedSprite2D:
	var image: Image = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.8, 0.2, 1.0))
	for x in range(16, 32):
		for y in range(16):
			image.set_pixel(x, y, Color(0.9, 0.3, 0.3, 1.0))
	var tex: Texture2D = ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 12.0)
	for i in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(i * 16, 0, 16, 16)
		frames.add_frame("idle", atlas)
	var battler := AnimatedSprite2D.new()
	battler.sprite_frames = frames
	return battler


func _run_sequence(config: Dictionary) -> Dictionary:
	var stage := Node2D.new()
	stage.name = "SeqStage"
	get_root().add_child(stage)
	var intro := PUWBattleIntro.new()
	stage.add_child(intro)
	var enemy_battler: AnimatedSprite2D = _make_spy_battler()
	var player_battler: AnimatedSprite2D = _make_spy_battler()
	stage.add_child(enemy_battler)
	stage.add_child(player_battler)
	var result: Dictionary = {
		"release_order": [], "throw_frame_at_player_release": -1,
		"max_throw_frame": -1, "saw_front": false, "saw_throw": false,
		"finished_count": 0, "phases": [],
		"enemy_battler_playing": false, "player_battler_advanced": false,
	}
	intro.battler_release.connect(func(side: String) -> void:
		(result["release_order"] as Array).append(side)
		if side == "enemy":
			enemy_battler.play("idle")
		else:
			var ts: AnimatedSprite2D = intro.throw_sprite()
			result["throw_frame_at_player_release"] = ts.frame if ts != null else -2
			player_battler.play("idle")
	)
	intro.intro_finished.connect(func() -> void:
		result["finished_count"] = int(result["finished_count"]) + 1
	)
	intro.phase_changed.connect(func(phase: String) -> void:
		(result["phases"] as Array).append(phase)
	)
	var cfg: Dictionary = FAST.duplicate()
	for key in config.keys():
		cfg[key] = config[key]
	intro.setup(cfg)
	intro.play()
	var start_msec: int = Time.get_ticks_msec()
	while not intro.is_finished() and Time.get_ticks_msec() - start_msec < 15000:
		await process_frame
		var ts2: AnimatedSprite2D = intro.throw_sprite()
		if ts2 != null:
			result["saw_throw"] = true
			result["max_throw_frame"] = maxi(int(result["max_throw_frame"]), ts2.frame)
		if intro.enemy_front_sprite() != null:
			result["saw_front"] = true
	result["enemy_battler_playing"] = enemy_battler.is_playing()
	# Prove the handed-off player battler keeps animating.
	if player_battler.is_playing():
		var first_frame: int = player_battler.frame
		var changed: bool = false
		var watch_start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - watch_start < 600:
			await process_frame
			if player_battler.frame != first_frame:
				changed = true
				break
		result["player_battler_advanced"] = changed
	stage.queue_free()
	await process_frame
	return result


# ------------------------------------------------------- sequence tests
func _test_sequence_trainer() -> void:
	var res: Dictionary = await _run_sequence({
		"kind": "trainer", "enemy_trainer_id": "YOUNGSTER", "player_back_id": "red"})
	_check("trainer: intro finished once", int(res["finished_count"]) == 1)
	_check("trainer: enemy front appeared", bool(res["saw_front"]))
	_check("trainer: throw sprite appeared", bool(res["saw_throw"]))
	_check("trainer: throw strip advanced to release frame",
		int(res["max_throw_frame"]) >= 2, "max frame " + str(res["max_throw_frame"]))
	_check("trainer: releases in order enemy -> player",
		res["release_order"] == ["enemy", "player"], str(res["release_order"]))
	_check("trainer: player release at/after the strip's release frame",
		int(res["throw_frame_at_player_release"]) >= 2,
		"frame " + str(res["throw_frame_at_player_release"]))
	_check("trainer: enemy battler playing after handoff", bool(res["enemy_battler_playing"]))
	_check("trainer: player battler animates after handoff", bool(res["player_battler_advanced"]))


func _test_sequence_wild() -> void:
	var res: Dictionary = await _run_sequence({
		"kind": "wild", "player_back_id": "leaf"})
	_check("wild: intro finished once", int(res["finished_count"]) == 1)
	_check("wild: no trainer front ever", not bool(res["saw_front"]))
	_check("wild: throw strip still plays", int(res["max_throw_frame"]) >= 2)
	_check("wild: releases in order enemy -> player",
		res["release_order"] == ["enemy", "player"], str(res["release_order"]))


func _test_sequence_no_strip() -> void:
	var res: Dictionary = await _run_sequence({
		"kind": "trainer", "enemy_trainer_id": "YOUNGSTER", "player_back_id": ""})
	_check("no-strip: intro finished once", int(res["finished_count"]) == 1)
	_check("no-strip: no throw sprite shown (gap G-VS2 ball-only)", not bool(res["saw_throw"]))
	_check("no-strip: releases still fire in order",
		res["release_order"] == ["enemy", "player"], str(res["release_order"]))
	_check("no-strip: battler still handed off and animates", bool(res["player_battler_advanced"]))


func _test_sequence_gym_vs() -> void:
	var res: Dictionary = await _run_sequence({
		"kind": "gym", "enemy_trainer_id": "BROCK",
		"player_front_id": "riley", "player_back_id": "red"})
	_check("gym: VS phase ran", (res["phases"] as Array).has("vs"), str(res["phases"]))
	_check("gym: intro finished once", int(res["finished_count"]) == 1)
	_check("gym: throw strip advanced", int(res["max_throw_frame"]) >= 2)
	_check("gym: releases in order enemy -> player",
		res["release_order"] == ["enemy", "player"], str(res["release_order"]))


func _test_sequence_unresolved_front() -> void:
	var res: Dictionary = await _run_sequence({
		"kind": "trainer", "enemy_trainer_id": "CHIEF", "player_back_id": "red"})
	_check("unresolved: no front faked for CHIEF", not bool(res["saw_front"]))
	_check("unresolved: intro finished once", int(res["finished_count"]) == 1)
	_check("unresolved: releases still fire in order",
		res["release_order"] == ["enemy", "player"], str(res["release_order"]))
