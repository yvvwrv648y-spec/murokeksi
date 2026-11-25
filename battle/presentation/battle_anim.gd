# PUWBattleAnim — battle animations for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# This helper plays battle animations in PUW using the open Pokemon
# Showdown animation data that is already in the PUW archive
# (files/pokemon-full/data/battle_animations.json and
# animation_states.json). Each move in that data has a list of effect
# names, like "fireball", "iceball", "leftslash", or "wisp". This helper
# turns those effect names into real movement on screen: projectiles that
# fly from the attacker to the target, lunges, shakes, flashes, and sparkles.
# Everything is made with Godot Tweens and simple drawn shapes, so it
# needs no art files and works with any Node2D sprites you already have.
#
# What the open data covers, and what it does not:
#   Covered in the data: attack (608 moves), idle (the looping sprite
#   itself), shiny sparkle, mega evolution, Z-Power, Ultra Burst, Primal
#   Reversion, status conditions, heal.
#   NOT covered in the open data: walk, hurt, faint, Dynamax/Gmax,
#   Terastal, switch, send-out. This helper still plays those states,
#   but with plain PUW-made motion (shake, sink, fade) — it says so in
#   the code, and does not pretend they came from Showdown data.
#
# How to use it:
#   var anims = PUWBattleAnim.new()
#   add_child(anims)
#   anims.load_animation_data("res://data/battle_animations.json")
#   anims.play_move_animation("tackle", attacker_node, target_node, func(): pass)
#   anims.play_state_animation(target_node, "hurt")
#
# Binding build 6 addition (code_prep_battle_anim): real authored
# move animation sequences now come FIRST. The held Pokemon H build
# (Essentials v20.1) carries 1,456 PBAnimation sequences plus the
# move2anim table Essentials itself uses to pick one per move; that
# data was converted (data-only) into res://data/battle_anim_index.json
# + battle_anims_by_id.json + battle_anims_custom.json, with the
# sheets in res://assets/battle_anims/. play_move_animation tries, in
# order: an H-custom .anm sequence, the PBAnimation sequence for the
# move (user/opp variant by the attacker's side), and only then the
# Showdown effect shapes below, then the plain contact fallback.
# PUWPBAnimPlayer (pb_animation_player.gd) plays the sequences.
# Status states ("sleep", "poison", ...) likewise try their real
# Common: sequences first. Ball throws and send-outs get real ball
# art from res://assets/battle_anims/battle/ (play_ball_throw,
# play_send_out). _ready now loads BOTH data sets: before this
# patch, load_animation_data had no callers anywhere, so no move
# animation ever played in production.
#
# Effect names this helper knows how to show:
#   Projectile effects (a ball flies from attacker to target):
#       fireball, flareball, iceball, electroball, shadowball,
#       energyball, waterwisp, mistball, purplewisp, blackwisp, wisp,
#       moon, lightning, icicle, rock1, rock2, leaf1, leaf2, petal,
#       bone, gear, heart, rainbow, mudwisp, bluefireball, greenmetal1,
#       greenmetal2, pinkicicle, poisoncaltrop, caltrop, feather
#   Contact effects (the attacker lunges in and the target shakes):
#       leftslash, rightslash, leftchop, rightchop, bite, bottombite,
#       fist, fist1, foot, impact, angry, pointer, sword, pokeball
# Anything else falls back to a simple flash on the target.

class_name PUWBattleAnim
extends Node

signal animation_finished(move_id: String)

## Path to the archive's battle_animations.json, relative to the project.
## Pass your own path to load_animation_data() if your copy lives elsewhere.
const DEFAULT_DATA_PATH: String = "res://data/battle_animations.json"

## Effect names that fly as projectiles, with the color to draw them in.
const PROJECTILE_EFFECTS: Dictionary = {
	"fireball": Color(1.0, 0.45, 0.1), "flareball": Color(1.0, 0.35, 0.05),
	"iceball": Color(0.6, 0.85, 1.0), "electroball": Color(1.0, 0.9, 0.2),
	"shadowball": Color(0.45, 0.2, 0.7), "energyball": Color(0.4, 0.9, 0.3),
	"waterwisp": Color(0.3, 0.6, 1.0), "mistball": Color(0.8, 0.85, 0.9),
	"purplewisp": Color(0.65, 0.4, 0.9), "blackwisp": Color(0.15, 0.1, 0.25),
	"wisp": Color(0.9, 0.9, 0.9), "moon": Color(0.95, 0.95, 0.75),
	"lightning": Color(1.0, 0.95, 0.3), "icicle": Color(0.7, 0.9, 1.0),
	"rock1": Color(0.55, 0.5, 0.45), "rock2": Color(0.45, 0.4, 0.35),
	"leaf1": Color(0.3, 0.8, 0.3), "leaf2": Color(0.4, 0.85, 0.4),
	"petal": Color(1.0, 0.6, 0.8), "bone": Color(0.95, 0.95, 0.9),
	"gear": Color(0.7, 0.7, 0.75), "heart": Color(1.0, 0.4, 0.6),
	"rainbow": Color(0.9, 0.5, 0.9), "mudwisp": Color(0.6, 0.45, 0.3),
	"bluefireball": Color(0.3, 0.5, 1.0), "greenmetal1": Color(0.3, 0.8, 0.5),
	"greenmetal2": Color(0.4, 0.85, 0.6), "pinkicicle": Color(1.0, 0.7, 0.85),
	"poisoncaltrop": Color(0.6, 0.3, 0.8), "caltrop": Color(0.5, 0.5, 0.5),
	"feather": Color(0.95, 0.95, 0.95),
}

## Effect names that are contact hits (lunge + shake).
const CONTACT_EFFECTS: Array[String] = [
	"leftslash", "rightslash", "leftchop", "rightchop", "bite",
	"bottombite", "fist", "fist1", "foot", "impact", "angry", "pointer",
	"sword", "pokeball",
]

## The raw animation data, loaded from battle_animations.json.
## Shape: {"move_anims": {move_id: {"effects": [...], ...}}, ...}
var animation_data: Dictionary = {}
var data_loaded: bool = false

## Converted PBAnimation data (binding build 6): the index maps a
## squashed move id to {"user": anim_id, "opp": anim_id} plus the
## Common: state sequences; anims_by_id holds the sequences
## themselves; anims_custom holds the H-custom .anm sequences.
const PB_INDEX_PATH: String = "res://data/battle_anim_index.json"
const PB_ANIMS_PATH: String = "res://data/battle_anims_by_id.json"
const PB_CUSTOM_PATH: String = "res://data/battle_anims_custom.json"
const PB_GRAPHICS_DIR: String = "res://assets/battle_anims/"
const BALL_GRAPHICS_DIR: String = "res://assets/battle_anims/battle/"

var pb_index: Dictionary = {}
var pb_anims: Dictionary = {}
var pb_custom: Dictionary = {}
var pb_loaded: bool = false

## Where ball art is read from. A var (defaulting to the bound
## location) so tests and tools can point it at a staging folder.
var ball_graphics_dir: String = BALL_GRAPHICS_DIR

## The sequence player. A battle scene may register its own
## stage-parented player (set_stage_player) so sheet cells inherit
## the stage transform; otherwise an internal player is used.
var _pb_player: PUWPBAnimPlayer = null
var _stage_player: PUWPBAnimPlayer = null
var _pb_pending_move: String = ""
var _pb_pending_callback: Callable = Callable()

## Battle states that have a real Common: sequence in the held data.
## Names on the right are the Common: suffixes in the index.
const STATE_COMMON: Dictionary = {
	"sleep": "Sleep", "poison": "Poison", "toxic": "Toxic",
	"burn": "Burn", "paralysis": "Paralysis", "frozen": "Frozen",
	"confusion": "Confusion", "attract": "Attract",
	"stat_up": "StatUp", "stat_down": "StatDown",
	"health_up": "HealthUp", "health_down": "HealthDown",
	"shiny": "Shiny", "mega_evolution": "MegaEvolution",
}


func _ready() -> void:
	# The fix for the dead wiring: before this patch nothing ever
	# called load_animation_data, so has_move_anim was always false
	# and no move animation ever played.
	if not data_loaded:
		load_animation_data()
	load_pb_data()
	_ensure_pb_player()


## Load the converted PBAnimation set. Returns true if it loaded.
func load_pb_data() -> bool:
	if pb_loaded:
		return true
	if not FileAccess.file_exists(PB_INDEX_PATH):
		return false
	if not FileAccess.file_exists(PB_ANIMS_PATH):
		return false
	var idx: Variant = JSON.parse_string(FileAccess.get_file_as_string(PB_INDEX_PATH))
	var by_id: Variant = JSON.parse_string(FileAccess.get_file_as_string(PB_ANIMS_PATH))
	if not (idx is Dictionary) or not (by_id is Dictionary):
		return false
	pb_index = idx
	pb_anims = by_id
	if FileAccess.file_exists(PB_CUSTOM_PATH):
		var cust: Variant = JSON.parse_string(FileAccess.get_file_as_string(PB_CUSTOM_PATH))
		if cust is Dictionary:
			pb_custom = cust
	pb_loaded = true
	_ensure_pb_player()
	return true


func _ensure_pb_player() -> void:
	if _pb_player == null and is_inside_tree():
		_pb_player = PUWPBAnimPlayer.new()
		_pb_player.name = "PBAnimPlayer"
		_pb_player.graphics_dir = PB_GRAPHICS_DIR
		add_child(_pb_player)
		_pb_player.finished.connect(_on_pb_player_finished)


## A battle scene registers its stage-parented player here so the
## sequence cells inherit the stage's transform. Optional: the
## internal player works anywhere (it positions by global coords).
func set_stage_player(player: PUWPBAnimPlayer) -> void:
	_stage_player = player
	if player != null:
		player.graphics_dir = PB_GRAPHICS_DIR
		if not player.finished.is_connected(_on_pb_player_finished):
			player.finished.connect(_on_pb_player_finished)


func _active_player() -> PUWPBAnimPlayer:
	if _stage_player != null:
		return _stage_player
	_ensure_pb_player()
	return _pb_player


func _on_pb_player_finished() -> void:
	var move_id: String = _pb_pending_move
	var callback: Callable = _pb_pending_callback
	_pb_pending_move = ""
	_pb_pending_callback = Callable()
	if move_id != "":
		animation_finished.emit(move_id)
	if callback.is_valid():
		callback.call()


## Squash a move id the way the converted index keys it:
## uppercase, no spaces, dashes or underscores.
func pb_squash(move_id: String) -> String:
	return move_id.to_upper().replace(" ", "").replace("-", "").replace("_", "")


## Resolve a move's real animation sequence, or {} when none is
## held. Order: H-custom .anm, then the move2anim PBAnimation
## (requested side first), then named Move:/OppMove: sequences the
## move2anim table does not reference (extra_named, e.g. the
## Hidden Power per-type variants). "side" is "user" when the
## attacker is the player's battler, "opp" for the enemy's.
func resolve_move_sequence(move_id: String, side: String = "") -> Dictionary:
	if not pb_loaded:
		return {}
	var key: String = pb_squash(move_id)
	if pb_custom.has(key):
		return pb_custom[key]
	var order: Array = []
	if side == "user" or side == "opp":
		order = [side, "opp" if side == "user" else "user"]
	else:
		order = ["user", "opp"]
	for table_name in ["moves", "extra_named"]:
		var table: Dictionary = pb_index.get(table_name, {})
		if not table.has(key):
			continue
		var entry: Dictionary = table[key]
		for side_name in order:
			if entry.has(side_name):
				var anim_id: String = str(int(entry[side_name]))
				if pb_anims.has(anim_id):
					return pb_anims[anim_id]
	return {}


func has_pb_move_anim(move_id: String) -> bool:
	return not resolve_move_sequence(move_id).is_empty()


## A Common: state sequence by its suffix ("Sleep", "StatUp", ...).
func resolve_common_sequence(common_name: String) -> Dictionary:
	if not pb_loaded:
		return {}
	var common: Dictionary = pb_index.get("common", {})
	if not common.has(common_name):
		return {}
	var anim_id: String = str(int(common[common_name]))
	if pb_anims.has(anim_id):
		return pb_anims[anim_id]
	return {}

## Live idle tweens by node instance id (binding build 5,
## 2026-11-24): the idle loop is now started/stopped by the
## battle scene as battlers are sent out, hurt and faint, so
## a node's previous idle tween is always killed before a
## new one starts and whenever a non-idle state plays on it —
## idle loops never stack.
var _idle_tweens: Dictionary = {}


## Load the archive's battle_animations.json. Returns true if it loaded.
func load_animation_data(path: String = DEFAULT_DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	animation_data = parsed
	data_loaded = true
	return true


## Effect names for a move, from the Showdown data. Empty if unknown.
func get_move_effects(move_id: String) -> Array:
	if not data_loaded:
		return []
	var key: String = move_id.to_lower().replace(" ", "").replace("-", "")
	var moves: Dictionary = animation_data.get("move_anims", {})
	if not moves.has(key):
		return []
	return moves[key].get("effects", [])


func has_move_anim(move_id: String) -> bool:
	return has_pb_move_anim(move_id) or not get_move_effects(move_id).is_empty()


## Play a move's animation between two Node2D battlers.
## "on_finished" is called when the animation ends (may be an empty Callable).
## "side" says which PBAnimation variant fits the attacker: "user"
## for the player's battler, "opp" for the enemy's ("" = either).
func play_move_animation(move_id: String, attacker: Node2D, target: Node2D,
		on_finished: Callable = Callable(), side: String = "") -> void:
	# Real authored sequences first (binding build 6).
	if pb_loaded:
		var sequence: Dictionary = resolve_move_sequence(move_id, side)
		if not sequence.is_empty():
			var player: PUWPBAnimPlayer = _active_player()
			if player != null:
				_pb_pending_move = move_id
				_pb_pending_callback = on_finished
				player.play(sequence, attacker, target)
				return
	var effects: Array = get_move_effects(move_id)
	var effect: String = str(effects[0]) if not effects.is_empty() else ""
	if PROJECTILE_EFFECTS.has(effect):
		_play_projectile(effect, attacker, target, move_id, on_finished)
	elif effect in CONTACT_EFFECTS:
		_play_contact(attacker, target, move_id, on_finished)
	elif effect != "":
		_play_flash(target, move_id, on_finished)
	else:
		# No data for this move: a plain lunge so something still happens.
		_play_contact(attacker, target, move_id, on_finished)


## Play one of the named battle states on a Node2D.
## States from the open data: "idle", "attack", "shiny", "mega_evolution",
## "z_power", "ultra_burst", "primal_reversion", "status_conditions", "heal".
## States PUW plays with its own plain motion: "hurt", "faint", "walk",
## "switch", "send_out", "dynamax", "terastal".
func play_state_animation(node: Node2D, state: String) -> void:
	if state != "idle":
		_kill_idle(node)
	# Real Common: sequences first for the states that have them
	# (binding build 6); the plain-motion match below stays as the
	# fallback for everything else.
	if pb_loaded and STATE_COMMON.has(state):
		var sequence: Dictionary = resolve_common_sequence(str(STATE_COMMON[state]))
		if not sequence.is_empty():
			var player: PUWPBAnimPlayer = _active_player()
			if player != null:
				player.play(sequence, node, node)
				return
	match state:
		"idle":
			_play_idle(node)
		"hurt":
			_play_hurt(node)
		"faint":
			_play_faint(node)
		"shiny", "mega_evolution", "z_power", "ultra_burst", "primal_reversion":
			_play_sparkle(node, Color(1.0, 0.9, 0.3))
		"heal":
			_play_sparkle(node, Color(0.4, 1.0, 0.5))
		"status_conditions":
			_play_flash(node, state)
		"walk":
			_play_walk(node)
		"switch", "send_out":
			_play_send_out(node)
		"dynamax", "terastal":
			_play_grow(node)
		_:
			_play_flash(node, state)


func _play_projectile(effect: String, attacker: Node2D, target: Node2D,
		move_id: String, on_finished: Callable) -> void:
	var ball: Sprite2D = _make_ball_sprite(PROJECTILE_EFFECTS[effect])
	attacker.get_parent().add_child(ball)
	ball.global_position = attacker.global_position
	var tween: Tween = create_tween()
	tween.tween_property(ball, "global_position", target.global_position, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		ball.queue_free()
		_play_hurt(target)
		animation_finished.emit(move_id)
		if on_finished.is_valid():
			on_finished.call()
	)


func _play_contact(attacker: Node2D, target: Node2D, move_id: String,
		on_finished: Callable) -> void:
	var start: Vector2 = attacker.position
	var mid: Vector2 = attacker.position.lerp(target.position, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(attacker, "position", mid, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position", start, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_play_hurt(target)
		animation_finished.emit(move_id)
		if on_finished.is_valid():
			on_finished.call()
	)


func _play_flash(node: Node2D, move_id: String, on_finished: Callable = Callable()) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.3, 0.1)
	tween.tween_property(node, "modulate:a", 1.0, 0.2)
	if on_finished.is_valid():
		tween.tween_callback(func() -> void:
			animation_finished.emit(move_id)
			on_finished.call()
		)


## A quick shake, used for hurt and for impact after a hit lands.
func _play_hurt(node: Node2D) -> void:
	var start: Vector2 = node.position
	var tween: Tween = create_tween()
	for i in range(4):
		var offset: Vector2 = Vector2(6 if i % 2 == 0 else -6, 0)
		tween.tween_property(node, "position", start + offset, 0.05)
	tween.tween_property(node, "position", start, 0.05)


## Stop a node's idle loop, if one is running (binding build 5).
func _kill_idle(node: Node2D) -> void:
	if node == null:
		return
	var key: int = node.get_instance_id()
	var existing: Variant = _idle_tweens.get(key, null)
	if existing is Tween:
		var old: Tween = existing
		if old.is_valid():
			old.kill()
	_idle_tweens.erase(key)


## True when a node currently has a live idle loop (binding
## build 5: the playback suite proves idle motion through this).
func is_idle_playing(node: Node2D) -> bool:
	if node == null:
		return false
	var existing: Variant = _idle_tweens.get(node.get_instance_id(), null)
	if existing is Tween:
		var tween: Tween = existing
		return tween.is_valid() and tween.is_running()
	return false


## Looping gentle bob for idle. The looping animated sprite itself is the
## real idle animation; this bob is only a small extra for still sprites.
func _play_idle(node: Node2D) -> void:
	_kill_idle(node)
	var base_y: float = node.position.y
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(node, "position:y", base_y - 4.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", base_y, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tweens[node.get_instance_id()] = tween


## Sink and fade. PUW-made motion: the open data has no faint animation.
func _play_faint(node: Node2D) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(node, "position:y", node.position.y + 24.0, 0.6)
	tween.tween_property(node, "modulate:a", 0.0, 0.6)


## A few sparkles that rise and fade. Used for shiny, mega, Z-Power, heal.
func _play_sparkle(node: Node2D, color: Color) -> void:
	for i in range(6):
		var spark: Sprite2D = _make_ball_sprite(color, 3)
		node.get_parent().add_child(spark)
		var start: Vector2 = node.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 20))
		spark.global_position = start
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(spark, "global_position:y", start.y - 40.0, 0.6)
		tween.tween_property(spark, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(spark.queue_free)


## Small step forward and back. PUW-made motion: no walk data in the archive.
func _play_walk(node: Node2D) -> void:
	var start: Vector2 = node.position
	var tween: Tween = create_tween()
	tween.tween_property(node, "position:x", start.x + 8.0, 0.15)
	tween.tween_property(node, "position:x", start.x, 0.15)


## Rise from below and fade in. PUW-made motion: no send-out data.
func _play_send_out(node: Node2D) -> void:
	var start: Vector2 = node.position
	node.position = start + Vector2(0, 30)
	node.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(node, "position", start, 0.4)
	tween.tween_property(node, "modulate:a", 1.0, 0.4)


## Grow big, then settle. PUW-made motion: no Dynamax/Terastal data.
func _play_grow(node: Node2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", node.scale * 1.6, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", node.scale, 0.3)


## Make a plain colored circle sprite. No art files needed.
func _make_ball_sprite(color: Color, radius: int = 6) -> Sprite2D:
	var size: int = radius * 2
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dx: float = float(x - radius) / radius
			var dy: float = float(y - radius) / radius
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(x, y, color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	return sprite


# ======================================================================
# Binding build 6: awaitable playback, ball throws, send-outs.
# ======================================================================

## Play a move animation and wait until it ends. The battle scene
## awaits this so the turn resolves AFTER the picture, not during
## it. A generous frame guard keeps a broken animation from ever
## soft-locking the battle: after ~60 seconds it gives up waiting.
func play_move_animation_async(move_id: String, attacker: Node2D, target: Node2D,
		side: String = "") -> void:
	if not is_inside_tree():
		return
	var flag: Array = [false]
	play_move_animation(move_id, attacker, target, func() -> void: flag[0] = true, side)
	var guard: int = 0
	while not flag[0] and guard < 3600:
		await get_tree().process_frame
		guard += 1


## Load a texture from a res:// path, imported or loose file.
func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Variant = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded
		return null
	if FileAccess.file_exists(path):
		var img: Image = Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


## The held ball art for a ball item id ("pokeball" -> POKEBALL).
## open_variant picks the "_open" sheet. Null when not held.
func ball_texture(ball_id: String, open_variant: bool = false) -> Texture2D:
	var key: String = "ball_" + pb_squash(ball_id) + ("_open" if open_variant else "") + ".png"
	return _load_texture(ball_graphics_dir + key)


## Throw a ball from the thrower at the target battler. Caught:
## the battler is drawn in, the ball drops and wobbles three
## times. Not caught: the battler breaks back out at full size.
## The burst flash uses the held generic ballBurst_star sheet —
## the held set has no per-ball burst mapping, so no per-ball
## burst is invented.
func play_ball_throw(ball_id: String, thrower: Node2D, target: Node2D,
		caught: bool, on_finished: Callable = Callable()) -> void:
	_ball_sequence(ball_id, thrower, target, caught, false, on_finished)


## Send a battler out with a ball: the ball arcs to the battler's
## spot, opens, and the battler rises in (the _play_send_out
## motion). Used for battle entry and mid-battle switches.
func play_send_out(ball_id: String, thrower: Node2D, battler: Node2D,
		on_finished: Callable = Callable()) -> void:
	_ball_sequence(ball_id, thrower, battler, false, true, on_finished)


func _ball_sequence(ball_id: String, thrower: Node2D, target: Node2D,
		caught: bool, send_out: bool, on_finished: Callable) -> void:
	var closed_tex: Texture2D = ball_texture(ball_id, false)
	if closed_tex == null or thrower == null or target == null or not is_inside_tree():
		# No held art for this ball: honest fallback, never a fake.
		if send_out and target != null:
			_play_send_out(target)
		if on_finished.is_valid():
			on_finished.call()
		return
	var stage: Node = target.get_parent()
	if stage == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	var base_pos: Vector2 = target.global_position
	var base_scale: Vector2 = target.scale
	var base_alpha: float = target.modulate.a
	var ball: Sprite2D = Sprite2D.new()
	ball.texture = closed_tex
	ball.z_index = 90
	stage.add_child(ball)
	var start_pos: Vector2 = thrower.global_position
	var end_pos: Vector2 = base_pos
	ball.global_position = start_pos
	if send_out:
		target.modulate.a = 0.0
	var flight: Tween = create_tween()
	flight.tween_method(_ball_arc.bind(start_pos, end_pos, ball), 0.0, 1.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flight.finished
	var open_tex: Texture2D = ball_texture(ball_id, true)
	if open_tex != null:
		ball.texture = open_tex
	_ball_burst(ball.global_position, stage)
	if send_out:
		_play_send_out(target)
	else:
		var shrink: Tween = create_tween().set_parallel(true)
		shrink.tween_property(target, "scale", base_scale * 0.05, 0.3)
		shrink.tween_property(target, "global_position", ball.global_position, 0.3)
		shrink.tween_property(target, "modulate:a", 0.4, 0.3)
		await shrink.finished
	if open_tex != null:
		ball.texture = closed_tex
	var drop: Tween = create_tween()
	drop.tween_property(ball, "global_position:y", end_pos.y + 46.0, 0.35) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await drop.finished
	if caught:
		for i in range(3):
			var wobble: Tween = create_tween()
			wobble.tween_property(ball, "rotation_degrees", 18.0, 0.12)
			wobble.tween_property(ball, "rotation_degrees", -18.0, 0.24)
			wobble.tween_property(ball, "rotation_degrees", 0.0, 0.12)
			await wobble.finished
	elif not send_out:
		# Breakout: the battler bursts back to its spot and size.
		if open_tex != null:
			ball.texture = open_tex
		_ball_burst(ball.global_position, stage)
		var back: Tween = create_tween().set_parallel(true)
		back.tween_property(target, "scale", base_scale, 0.3)
		back.tween_property(target, "global_position", base_pos, 0.3)
		back.tween_property(target, "modulate:a", base_alpha, 0.3)
		await back.finished
	ball.queue_free()
	animation_finished.emit(ball_id)
	if on_finished.is_valid():
		on_finished.call()


## Quadratic arc for a thrown ball: up 110px at the midpoint.
func _ball_arc(t: float, from_pos: Vector2, to_pos: Vector2, ball: Sprite2D) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var mid: Vector2 = (from_pos + to_pos) * 0.5 + Vector2(0, -110)
	var a: Vector2 = from_pos.lerp(mid, t)
	var b: Vector2 = mid.lerp(to_pos, t)
	ball.global_position = a.lerp(b, t)


## A quick star burst where a ball opens. Generic held art
## (ballBurst_star.png); skipped quietly when missing.
func _ball_burst(at_pos: Vector2, stage: Node) -> void:
	var tex: Texture2D = _load_texture(ball_graphics_dir + "ballBurst_star.png")
	if tex == null or stage == null:
		return
	var burst: Sprite2D = Sprite2D.new()
	burst.texture = tex
	burst.z_index = 95
	burst.global_position = at_pos
	burst.scale = Vector2(0.4, 0.4)
	stage.add_child(burst)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(burst, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(burst.queue_free)
