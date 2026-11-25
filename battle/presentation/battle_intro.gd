class_name PUWBattleIntro
extends Node2D
## Battle intro sequencer for Pokemon Ultimate World (Godot 4).
##
## What this does, in plain words:
## When a battle opens, this plays the canon intro beats before the
## player gets control:
##   1. VS phase (gym / Elite Four / rival / Champion battles only,
##      and only when both sides' front portraits resolve): the two
##      trainers slide in facing off, hold, and slide out.
##   2. Trainer phase (any non-wild battle): the enemy trainer's
##      front sprite slides in on the enemy side and holds.
##   3. Enemy release: the trainer slides out, a ball arcs to the
##      enemy anchor, and "battler_release" fires for "enemy" --
##      that is the moment the battle scene starts the enemy
##      battler's own animation and cry (the scene's existing
##      sprite-binding path; this sequencer never touches battlers).
##   4. Player throw: the player's back sprite slides in and plays
##      its REAL throw strip (held strips only: Red/Leaf 5 frames,
##      Brendan/May 4-5 frames, sliced from the actual sheet by
##      make_throw_frames). When the strip reaches its release
##      frame, a ball arcs to the player anchor and
##      "battler_release" fires for "player". The back sprite then
##      finishes the strip and exits.
##   5. "intro_finished" fires exactly once; control is the scene's.
##
## Honest limits, by design:
##   - Enemy trainers have NO throw animation held anywhere (every
##     held enemy front is a single still), so the enemy side is a
##     slide-in / slide-out, never a faked throw.
##   - PUW's own protagonists (Riley, Tasha, custom presets) have NO
##     back throw strip held (index gap G-VS2). When the config's
##     player_back_id does not resolve, the player release runs
##     ball-only: no wrong character's back is ever shown as the
##     player's.
##   - A trainer class with no held front (index "unresolved")
##     skips the trainer sprite; the release beats still fire.
##   - Wild battles skip the VS and trainer phases entirely.
##
## Data: res://data/battle_intro_index.json (fronts per trainer
## class, throw strips with real frame counts, protagonist fronts).
## Playback contract with the battle scene: the scene owns the
## battlers; this sequencer only emits battler_release(side) at the
## exact release moments and intro_finished at the end.

signal intro_finished
signal battler_release(side: String)
signal phase_changed(phase: String)

const INDEX_PATH: String = "res://data/battle_intro_index.json"

## Stage anchors, matching scenes/battle.tscn (1280x720).
const ENEMY_ANCHOR: Vector2 = Vector2(960, 220)
const PLAYER_ANCHOR: Vector2 = Vector2(320, 420)
## Where the enemy trainer stands relative to the battler anchor.
const TRAINER_STAND: Vector2 = Vector2(150, -10)
## Where the player's back sprite stands relative to its anchor.
const BACK_STAND: Vector2 = Vector2(-170, -6)
## Display heights in px (fronts are 128/160 native, strips 160).
const FRONT_HEIGHT: float = 210.0
const BACK_HEIGHT: float = 200.0
const VS_HEIGHT: float = 250.0
const SLIDE_OFF: float = 480.0

static var _index_cache: Dictionary = {}
static var _index_loaded: bool = false

var _config: Dictionary = {}
var _enemy_front: Sprite2D = null
var _player_back: AnimatedSprite2D = null
var _ball: Sprite2D = null
var _released: Dictionary = {"enemy": false, "player": false}
var _playing: bool = false
var _finished: bool = false

# Timing (seconds); config may override each for tests / pacing.
var _slide_time: float = 0.35
var _hold_time: float = 0.55
var _vs_hold_time: float = 0.9
var _ball_time: float = 0.28
var _beat_time: float = 0.2


# ---------------------------------------------------------------- index
static func load_index(path: String = INDEX_PATH) -> Dictionary:
	if _index_loaded:
		return _index_cache
	_index_loaded = true
	if not FileAccess.file_exists(path):
		return _index_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_index_cache = parsed
	return _index_cache


static func strip_entry_for(back_id: String) -> Dictionary:
	if back_id.is_empty():
		return {}
	var strips: Dictionary = load_index().get("strips", {})
	var entry: Variant = strips.get(back_id, {})
	return entry if entry is Dictionary else {}


static func front_entry_for(trainer_id: String) -> Dictionary:
	if trainer_id.is_empty():
		return {}
	var fronts: Dictionary = load_index().get("fronts", {})
	var entry: Variant = fronts.get(trainer_id, {})
	return entry if entry is Dictionary else {}


static func protagonist_front_path(front_id: String) -> String:
	var fronts: Dictionary = load_index().get("protagonist_fronts", {})
	return str(fronts.get(front_id, ""))


static func vs_eligible(kind: String) -> bool:
	var kinds: Array = load_index().get("vs_eligible_kinds", [])
	return kind in kinds


## Slice a throw strip sheet into a non-looping "throw" animation.
## orientation "horizontal": frames run left to right (Essentials
## strips, 800x160). "vertical": frames run top to bottom (FRLG
## back pics, 64x320 / 64x256). Frame size is derived from the
## texture size and the frame count, so the slice can never invent
## a frame the sheet does not contain.
static func make_throw_frames(texture: Texture2D, frame_count: int,
		orientation: String, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if texture == null or frame_count <= 0:
		return frames
	var tex_size: Vector2i = texture.get_size()
	var frame_w: int = tex_size.x / frame_count if orientation == "horizontal" else tex_size.x
	var frame_h: int = tex_size.y if orientation == "horizontal" else tex_size.y / frame_count
	frames.add_animation("throw")
	frames.set_animation_loop("throw", false)
	frames.set_animation_speed("throw", fps)
	for i in range(frame_count):
		var region := Rect2i()
		if orientation == "horizontal":
			region = Rect2i(i * frame_w, 0, frame_w, frame_h)
		else:
			region = Rect2i(0, i * frame_h, frame_w, frame_h)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		frames.add_frame("throw", atlas)
	return frames


# ---------------------------------------------------------------- setup
## config keys:
##   kind: entry-result kind ("wild", "trainer", "gym",
##     "elite_four", "rival", "champion", "scripted", "rematch"...).
##     "" or "wild" = wild intro.
##   enemy_trainer_id: PUW trainer class / named id for the front
##     lookup ("" = no front).
##   player_back_id: throw strip id from the index ("" = none held,
##     ball-only release).
##   player_front_id: protagonist front id for the VS phase.
##   slide_time / hold_time / vs_hold_time / ball_time / beat_time:
##     optional timing overrides (seconds).
func setup(config: Dictionary) -> void:
	_config = config
	_slide_time = float(config.get("slide_time", _slide_time))
	_hold_time = float(config.get("hold_time", _hold_time))
	_vs_hold_time = float(config.get("vs_hold_time", _vs_hold_time))
	_ball_time = float(config.get("ball_time", _ball_time))
	_beat_time = float(config.get("beat_time", _beat_time))


func is_finished() -> bool:
	return _finished


func released(side: String) -> bool:
	return bool(_released.get(side, false))


func throw_sprite() -> AnimatedSprite2D:
	return _player_back


func enemy_front_sprite() -> Sprite2D:
	return _enemy_front


func _kind() -> String:
	return str(_config.get("kind", ""))


func _is_wild() -> bool:
	return _kind() == "" or _kind() == "wild"


# ------------------------------------------------------------------ play
func play() -> void:
	if _playing:
		return
	_playing = true
	if not _is_wild():
		await _vs_phase()
		await _trainer_phase()
	else:
		phase_changed.emit("wild")
		await get_tree().create_timer(_beat_time).timeout
		_release("enemy")
	await _player_throw_phase()
	_finish()


func _vs_phase() -> void:
	if not vs_eligible(_kind()):
		return
	var enemy_entry: Dictionary = front_entry_for(str(_config.get("enemy_trainer_id", "")))
	var player_path: String = protagonist_front_path(str(_config.get("player_front_id", "")))
	if enemy_entry.is_empty() or player_path.is_empty():
		return
	var enemy_tex: Texture2D = load("res://" + str(enemy_entry.get("file", ""))) as Texture2D
	var player_tex: Texture2D = load("res://" + player_path) as Texture2D
	if enemy_tex == null or player_tex == null:
		return
	phase_changed.emit("vs")
	var enemy_vs := Sprite2D.new()
	enemy_vs.name = "VSEnemyFront"
	enemy_vs.texture = enemy_tex
	enemy_vs.scale = Vector2.ONE * (VS_HEIGHT / float(enemy_tex.get_height()))
	enemy_vs.position = Vector2(ENEMY_ANCHOR.x + SLIDE_OFF, 300)
	enemy_vs.z_index = 20
	add_child(enemy_vs)
	var player_vs := Sprite2D.new()
	player_vs.name = "VSPlayerFront"
	player_vs.texture = player_tex
	player_vs.scale = Vector2.ONE * (VS_HEIGHT / float(player_tex.get_height()))
	player_vs.position = Vector2(PLAYER_ANCHOR.x - SLIDE_OFF, 300)
	player_vs.z_index = 20
	add_child(player_vs)
	var label := Label.new()
	label.name = "VSLabel"
	label.text = "VS"
	label.add_theme_font_size_override("font_size", 64)
	label.position = Vector2(600, 260)
	label.z_index = 21
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(enemy_vs, "position:x", 900.0, _slide_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_vs, "position:x", 380.0, _slide_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(_vs_hold_time).timeout
	var out_tween: Tween = create_tween().set_parallel(true)
	out_tween.tween_property(enemy_vs, "position:x", ENEMY_ANCHOR.x + SLIDE_OFF, _slide_time)
	out_tween.tween_property(player_vs, "position:x", PLAYER_ANCHOR.x - SLIDE_OFF, _slide_time)
	out_tween.tween_property(label, "modulate:a", 0.0, _slide_time)
	await out_tween.finished
	enemy_vs.queue_free()
	player_vs.queue_free()
	label.queue_free()


func _trainer_phase() -> void:
	phase_changed.emit("trainer")
	# The player's back sprite walks in alongside the trainer phase
	# so the throw can start the moment the enemy release lands.
	_prepare_player_back()
	var entry: Dictionary = front_entry_for(str(_config.get("enemy_trainer_id", "")))
	if entry.is_empty():
		# No held front for this class: no sprite is faked; the
		# release beats still run on a short hold.
		await get_tree().create_timer(_hold_time * 0.5).timeout
		_release("enemy")
		return
	var tex: Texture2D = load("res://" + str(entry.get("file", ""))) as Texture2D
	if tex == null:
		await get_tree().create_timer(_hold_time * 0.5).timeout
		_release("enemy")
		return
	_enemy_front = Sprite2D.new()
	_enemy_front.name = "EnemyTrainerFront"
	_enemy_front.texture = tex
	_enemy_front.scale = Vector2.ONE * (FRONT_HEIGHT / float(tex.get_height()))
	_enemy_front.z_index = 10
	var stand: Vector2 = ENEMY_ANCHOR + TRAINER_STAND
	_enemy_front.position = stand + Vector2(SLIDE_OFF, 0)
	add_child(_enemy_front)
	var tween: Tween = create_tween()
	tween.tween_property(_enemy_front, "position", stand, _slide_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(_hold_time).timeout
	# Trainer exits; the ball leaves as they go and the battler
	# release fires when the ball lands on the enemy anchor.
	var out_tween: Tween = create_tween()
	out_tween.tween_property(_enemy_front, "position", stand + Vector2(SLIDE_OFF, 0), _slide_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fly_ball(stand, ENEMY_ANCHOR, "enemy")
	await out_tween.finished
	if _enemy_front != null:
		_enemy_front.queue_free()
		_enemy_front = null


func _prepare_player_back() -> void:
	if _player_back != null:
		return
	var entry: Dictionary = strip_entry_for(str(_config.get("player_back_id", "")))
	if entry.is_empty():
		return
	var tex: Texture2D = load("res://" + str(entry.get("file", ""))) as Texture2D
	if tex == null:
		return
	_player_back = AnimatedSprite2D.new()
	_player_back.name = "PlayerBackSprite"
	_player_back.sprite_frames = make_throw_frames(tex,
		int(entry.get("frames", 1)), str(entry.get("orientation", "horizontal")),
		float(entry.get("fps", 10.0)))
	_player_back.scale = Vector2.ONE * (BACK_HEIGHT / float(entry.get("frame_h", tex.get_height())))
	_player_back.z_index = 10
	var stand: Vector2 = PLAYER_ANCHOR + BACK_STAND
	_player_back.position = stand + Vector2(-SLIDE_OFF, 0)
	add_child(_player_back)
	_player_back.frame = 0
	var tween: Tween = create_tween()
	tween.tween_property(_player_back, "position", stand, _slide_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _player_throw_phase() -> void:
	phase_changed.emit("throw")
	if _player_back == null:
		# Wild battles skip the trainer phase that normally
		# prepares the back sprite; prepare it here instead.
		_prepare_player_back()
	if _player_back == null:
		# No strip held for this protagonist (gap G-VS2): the ball
		# alone makes the release. No substitute character is shown.
		_fly_ball(PLAYER_ANCHOR + Vector2(-SLIDE_OFF, -30), PLAYER_ANCHOR, "player")
		await get_tree().create_timer(_ball_time + _beat_time).timeout
		return
	var entry: Dictionary = strip_entry_for(str(_config.get("player_back_id", "")))
	var release_frame: int = int(entry.get("release_frame", 0))
	_player_back.play("throw")
	var max_frame: int = 0
	var start_msec: int = Time.get_ticks_msec()
	while _player_back.is_playing() and Time.get_ticks_msec() - start_msec < 5000:
		await get_tree().process_frame
		max_frame = maxi(max_frame, _player_back.frame)
		if max_frame >= release_frame and not _released["player"]:
			var hand: Vector2 = _player_back.position + Vector2(36, -52)
			_fly_ball(hand, PLAYER_ANCHOR, "player")
	if not _released["player"]:
		_release("player")
	# Let the strip settle, then the back sprite exits left.
	await get_tree().create_timer(_beat_time).timeout
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_player_back, "position:x", _player_back.position.x - SLIDE_OFF, _slide_time)
	tween.tween_property(_player_back, "modulate:a", 0.0, _slide_time)
	await tween.finished
	if _player_back != null:
		_player_back.queue_free()
		_player_back = null


## A plain drawn ball (same approach as PUWBattleAnim's projectile
## sprites: generated pixels, no art file) arcs from one point to
## another; the side's battler release fires when it lands.
func _fly_ball(from_pos: Vector2, to_pos: Vector2, side: String) -> void:
	_ball = Sprite2D.new()
	_ball.name = "IntroBall"
	_ball.texture = _make_ball_texture()
	_ball.z_index = 15
	_ball.position = from_pos
	add_child(_ball)
	var tween: Tween = create_tween()
	tween.tween_property(_ball, "position", to_pos, _ball_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _ball != null:
			_ball.queue_free()
			_ball = null
		_release(side)
	)


func _release(side: String) -> void:
	if bool(_released.get(side, false)):
		return
	_released[side] = true
	battler_release.emit(side)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	phase_changed.emit("done")
	intro_finished.emit()


func _make_ball_texture() -> Texture2D:
	var size: int = 24
	var radius: float = size / 2.0
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) - radius + 0.5) / radius
			var dy: float = (float(y) - radius + 0.5) / radius
			if dx * dx + dy * dy <= 1.0:
				var color: Color = Color(0.9, 0.15, 0.15) if y < size / 2 else Color(0.95, 0.95, 0.95)
				if abs(dy) < 0.12:
					color = Color(0.1, 0.1, 0.1)
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
