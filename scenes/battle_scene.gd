class_name BattleScene
extends Control
## Battle screen. Root node of battle.tscn.
## Owns a BattleController child and shows the two active Pokemon,
## their HP bars, 4 move buttons, and a battle log.
## How to open it: set BattleScene.pending_player_party and
## BattleScene.pending_enemy_party first, then change scene to
## res://scenes/battle.tscn. The Overworld scene does this for you.
## If you open the scene with no parties set, a small demo battle
## is built so you can see the screen work (placeholder only).

## Parties handed over by the scene that opened the battle.
## Cleared after _ready reads them.
static var pending_player_party: Array = []
static var pending_enemy_party: Array = []
## When the Party scene picks a switch mid-battle, it writes the
## chosen party slot index here, then returns to this scene.
static var pending_switch_index: int = -1
## The campaign region the pending battle is fought in, set by
## the launching scene from the campaign state (binding build
## 4, Styler merge step 3). Applied to the controller in
## _ready; "" = unset = balls work as always (Ranger Variant A
## reads this through BattleController.campaign_region_id).
static var pending_campaign_region_id: String = ""
## Battle intro hand-off (VS presentation prep): the launching
## scene sets these from the PUWBattleEntry result (its "kind"
## plus the trainer identity it was built from) and from the
## active protagonist record (back throw-strip id + front
## portrait id, resolved through data/battle_intro_index.json).
## "" kind = no intro: the scene behaves exactly as before.
## Cleared after _ready reads them. The same kind also
## selects the battle BGM through the music director
## (audio wiring build): "wild", "trainer", "gym_leader",
## "story_boss" or "champion"; _ready infers wild vs
## trainer from the controller when it is "".
static var pending_battle_kind: String = ""
static var pending_enemy_trainer_id: String = ""
static var pending_enemy_display_name: String = ""
static var pending_player_back_id: String = ""
static var pending_player_front_id: String = ""

## The battle's context for the permadeath bridge and the
## gimmick gate (mechanics prep F1/F2, 2026-11-24):
## {simulation: bool, rental: bool, story: bool, coop: bool}.
## Launchers set it next to the pending parties; empty means
## an ordinary battle (permadeath counts, gimmicks gated by
## the save's progression flags). VEXA launchers set
## simulation = true; rental facilities set rental = true.
static var pending_battle_context: Dictionary = {}

@onready var controller: BattleController = $BattleController
@onready var stage: BattleStageController = $BattleStage
@onready var player_name_label: Label = $TopBar/PlayerBox/PlayerNameLabel
@onready var player_level_label: Label = $TopBar/PlayerBox/PlayerLevelLabel
@onready var player_hp_bar: ProgressBar = $TopBar/PlayerBox/PlayerHPBar
@onready var player_hp_label: Label = $TopBar/PlayerBox/PlayerHPLabel
@onready var enemy_name_label: Label = $TopBar/EnemyBox/EnemyNameLabel
@onready var enemy_level_label: Label = $TopBar/EnemyBox/EnemyLevelLabel
@onready var enemy_hp_bar: ProgressBar = $TopBar/EnemyBox/EnemyHPBar
@onready var enemy_hp_label: Label = $TopBar/EnemyBox/EnemyHPLabel
@onready var player_box: VBoxContainer = $TopBar/PlayerBox
@onready var enemy_box: VBoxContainer = $TopBar/EnemyBox
@onready var log_label: RichTextLabel = $BattleLog
@onready var move_button_1: Button = $MenuBar/MoveButtons/MoveButton1
@onready var move_button_2: Button = $MenuBar/MoveButtons/MoveButton2
@onready var move_button_3: Button = $MenuBar/MoveButtons/MoveButton3
@onready var move_button_4: Button = $MenuBar/MoveButtons/MoveButton4
@onready var run_button: Button = $MenuBar/ActionButtons/RunButton
@onready var bag_button: Button = $MenuBar/ActionButtons/BagButton
@onready var party_button: Button = $MenuBar/ActionButtons/PartyButton
@onready var back_button: Button = $MenuBar/ActionButtons/BackButton
@onready var player_mon: Node2D = $PlayerMon
@onready var enemy_mon: Node2D = $EnemyMon

var battle_over: bool = false
## True while a turn's animations are playing back (binding
## build 6): move presses are ignored so turns cannot stack.
var _animating: bool = false
var item_engine: ItemEngine = ItemEngine.new()
var move_effects: MoveEffects = MoveEffects.new()
## Runtime sprite loading: pictures are resolved through
## PUWPokemonSpriteBinding over ShinySpriteResolver (animated
## Showdown GIF first, indexed still PNG as fallback) and
## streamed/cached by PUWSpriteLoader under user://. The
## shown-key for each side is the binding's cache key (index
## row + view + shiny), so a forme change -- Mega, Gmax,
## Primal, Ultra, ability formes -- changes the key and the
## picture refreshes to the forme's own art.
var sprite_loader: PUWSpriteLoader = null
var player_sprite2d: AnimatedSprite2D = null
var enemy_sprite2d: AnimatedSprite2D = null
var _shown_player_key: String = ""
var _shown_enemy_key: String = ""
## Binding build 5 (2026-11-24) — animations on:
## - MDX-family mons are presented with MDX-native battle art
##   via PUWMDXData (below), not with counterpart PKDX art;
##   the slot record's "motion" field drives playback
##   (BW2 engine-procedural idle for the kit keyframes, the
##   engine rig for the still slots).
## - BattleAnims.play_state_animation finally has production
##   callers here: send_out + idle when a battler's picture
##   lands, hurt when its HP drops, faint when it reaches 0.
## - When the binding hands back an engine rig (a still with
##   a rig definition), a PUWRigStage presents the still with
##   the rig's idle motion instead of the plain sprite.
var mdx_data: PUWMDXData = null
var player_rig_stage: PUWRigStage = null
var enemy_rig_stage: PUWRigStage = null
var _player_result: Dictionary = {}
var _enemy_result: Dictionary = {}
var _player_mdx: Dictionary = {}
var _enemy_mdx: Dictionary = {}
var _last_player_hp: int = -1
var _last_enemy_hp: int = -1
# Battle presentation (fold-in round, battle_presentation
# PATCHES P1/P2): databox extras per side, the move-button
# polish table, the animated-refresh gate, and the last EXP
# fraction shown for the player's battler.
var player_extras: Dictionary = {}
var enemy_extras: Dictionary = {}
var move_info: Dictionary = {}
var _databox_live: bool = false
var _player_exp_frac: float = 0.0
## Plays species cries on send-out. Made in _ready. A missing
## or unknown cry never breaks the scene: play_cry just
## returns false and the battle carries on as before.
var cry_player: PokemonCryPlayer = null
## Battle intro sequencer (VS presentation prep). Created in
## _ready when the launching scene supplied a battle kind. While
## it runs, the HUD is hidden and input is gated; each side's
## battler animation starts at the intro's release moment for
## that side, and the full display refresh lands when it ends.
var intro: PUWBattleIntro = null
var _intro_active: bool = false
## Battle BGM through the music director. Made in _ready.
var music_director: PUWMusicDirector = null
## Identity (species + forme) of the enemy mon currently
## shown, so a replacement send-out mid-battle plays its cry
## too - the lead send-outs and the player's switch-in were
## already covered; the enemy's replacement was not.
var _shown_enemy_identity: String = ""


func _ready() -> void:
	var player_party: Array = pending_player_party
	var enemy_party: Array = pending_enemy_party
	pending_player_party = []
	pending_enemy_party = []
	if player_party.is_empty() or enemy_party.is_empty():
		player_party = _demo_player_party()
		enemy_party = _demo_enemy_party()
		_add_log("Demo battle: no party was handed over, so difficulty-layer-built demo Pokemon are used.")
	cry_player = PokemonCryPlayer.new()
	cry_player.name = "CryPlayer"
	add_child(cry_player)
	music_director = PUWMusicDirector.new()
	music_director.name = "MusicDirector"
	add_child(music_director)
	# Battle presentation (fold-in round, PATCHES P1/P2):
	# databox extras (status chips on both sides, EXP bar on
	# the player's) attach programmatically — no .tscn edit.
	# The enemy databox shows the HP bar only (PM ruling
	# 2026-11-24: match BW2, no numeric enemy HP), so its HP
	# number label is hidden here and never written again.
	player_extras = PUWDataboxExtras.attach_extras(player_box, true)
	enemy_extras = PUWDataboxExtras.attach_extras(enemy_box, false)
	enemy_hp_label.visible = false
	move_info = _build_move_info()
	# Shared screen look (v6 polish pass): one theme for the
	# whole screen, HP bars colored by fraction, and sprites
	# loaded from the index at runtime over the placeholders.
	theme = PUWUiTheme.make_theme()
	sprite_loader = PUWSpriteLoader.new()
	sprite_loader.name = "SpriteLoader"
	add_child(sprite_loader)
	player_sprite2d = AnimatedSprite2D.new()
	player_sprite2d.name = "PlayerSprite2D"
	player_mon.add_child(player_sprite2d)
	enemy_sprite2d = AnimatedSprite2D.new()
	enemy_sprite2d.name = "EnemySprite2D"
	enemy_mon.add_child(enemy_sprite2d)
	mdx_data = PUWMDXData.new()
	player_rig_stage = PUWRigStage.new()
	player_rig_stage.name = "PlayerRigStage"
	player_rig_stage.visible = false
	player_mon.add_child(player_rig_stage)
	enemy_rig_stage = PUWRigStage.new()
	enemy_rig_stage.name = "EnemyRigStage"
	enemy_rig_stage.visible = false
	enemy_mon.add_child(enemy_rig_stage)
	controller.campaign_region_id = pending_campaign_region_id
	pending_campaign_region_id = ""
	var battle_kind: String = pending_battle_kind
	var intro_trainer_id: String = pending_enemy_trainer_id
	var intro_display_name: String = pending_enemy_display_name
	var intro_back_id: String = pending_player_back_id
	var intro_front_id: String = pending_player_front_id
	pending_battle_kind = ""
	pending_enemy_trainer_id = ""
	pending_enemy_display_name = ""
	pending_player_back_id = ""
	pending_player_front_id = ""

	# Mechanics prep F1/F3 (2026-11-24): arm the progression
	# gimmick gate and supply the badge count for the hard
	# level caps, both from the shared save-state channel
	# (BagScene.save_state, the same channel the Styler merge
	# used for the campaign region). A VEXA battle's context
	# marks it a simulation, which the gate treats as exempt.
	controller.arm_gimmick_gate(BagScene.save_state, bool(pending_battle_context.get("simulation", false)))
	controller.supply_badge_count_from_state(BagScene.save_state)
	var result: Dictionary = controller.start_battle(player_party, enemy_party)
	for line in result.get("logs", []):
		_add_log(str(line))
	# Battle intro (VS presentation prep): when the launching
	# scene supplied a battle kind and this is not a mid-battle
	# switch return, the intro sequencer plays first -- trainer
	# slide-in, player throw, ball releases -- and each side's
	# battler animation + cry starts at its release moment (see
	# _on_intro_battler_release). With no kind set, the opening is
	# exactly what it was: cries now, full display now.
	if pending_switch_index < 0 and battle_kind != "":
		_start_intro(battle_kind, intro_trainer_id, intro_display_name, intro_back_id, intro_front_id)
	if not _intro_active:
		_play_opening_cries()
		# Entry animations (battle-anim prep): with no intro
		# sequencer running, a wild Pokemon appears, a trainer's
		# Pokemon is thrown out, and the player's lead is sent
		# out with its ball, as before.
		_play_entry_animations()
	# Battle BGM (audio wiring build): the launcher's
	# pending kind (already read into battle_kind above)
	# wins; with none set, infer wild vs trainer from
	# the controller now that start_battle has read the
	# parties.
	var bgm_kind: String = battle_kind
	if bgm_kind == "":
		bgm_kind = "wild" if controller.is_wild else "trainer"
	if music_director != null:
		music_director.play_battle_bgm(bgm_kind)
	# If the Party scene sent us back with a switch choice, do it now.
	if pending_switch_index >= 0:
		var idx: int = pending_switch_index
		pending_switch_index = -1
		if idx > 0 and idx < controller.player_party.size():
			var logs: Array = controller.execute_switch(controller.player_party, idx, controller.enemy_party[0], true)
			for line in logs:
				_add_log(str(line))
			# Play the cry of the Pokemon that just switched in.
			if not controller.player_party.is_empty():
				_play_cry_for_mon(controller.player_party[0])
			if has_node("/root/BattleAnims"):
				get_node("/root/BattleAnims").play_state_animation(player_mon, "send_out")
	if not _intro_active:
		_refresh_display()
	move_button_1.pressed.connect(_on_move_pressed.bind(0))
	move_button_2.pressed.connect(_on_move_pressed.bind(1))
	move_button_3.pressed.connect(_on_move_pressed.bind(2))
	move_button_4.pressed.connect(_on_move_pressed.bind(3))
	run_button.pressed.connect(_on_run_pressed)
	bag_button.pressed.connect(_on_bag_pressed)
	party_button.pressed.connect(_on_party_pressed)
	back_button.pressed.connect(_on_back_pressed)
	# Input prep (code_prep_input_menus): the scene never grabbed
	# focus, so keyboard/gamepad input had nowhere to land and the
	# battle was mouse/touch-only. Focus the first live move button.
	PUWFocus.grab_first_enabled([move_button_1, move_button_2, move_button_3, move_button_4])


## Play one Pokemon's cry, if a cry player is set up.
## Delegates the field extraction to the cry player itself
## (audio wiring build): it reads a dex id field when the
## party entry has one, otherwise the species (or name) text,
## plus the forme when present - and never the family, so an
## MDX battler cries exactly like its PKDX counterpart.
## Unknown cries are skipped quietly.
func _play_cry_for_mon(mon: Dictionary) -> void:
	if cry_player == null:
		return
	cry_player.play_cry_for_mon(mon)


## Species + forme identity of a party entry, for detecting
## an enemy replacement send-out between display refreshes.
func _mon_identity(mon: Dictionary) -> String:
	return str(mon.get("species_slug", mon.get("species", mon.get("name", "")))) + "|" + str(mon.get("forme", mon.get("form", "")))


## Play the lead cry for each side as the battle starts (the
## no-intro opening; with an intro, cries fire per side at the
## release moments instead).
func _play_opening_cries() -> void:
	if not controller.player_party.is_empty():
		_play_cry_for_mon(controller.player_party[0])
	if not controller.enemy_party.is_empty():
		_play_cry_for_mon(controller.enemy_party[0])


## Start the battle intro sequencer: HUD hidden, placeholders
## hidden, sequencer added over the stage. The battlers
## themselves are untouched until their release moments.
func _start_intro(kind: String, trainer_id: String, display_name: String, back_id: String, front_id: String) -> void:
	_intro_active = true
	$TopBar.visible = false
	$MenuBar.visible = false
	_hide_placeholder(true)
	_hide_placeholder(false)
	intro = PUWBattleIntro.new()
	intro.name = "BattleIntro"
	add_child(intro)
	intro.battler_release.connect(_on_intro_battler_release)
	intro.intro_finished.connect(_on_intro_finished)
	intro.setup({
		"kind": kind,
		"enemy_trainer_id": trainer_id,
		"enemy_display_name": display_name,
		"player_back_id": back_id,
		"player_front_id": front_id,
	})
	intro.play()


## The intro's release moment for one side: start that side's
## battler animation through the existing sprite-binding path
## and play its cry. This is the whole handoff -- the sequencer
## never touches the battler nodes itself.
func _on_intro_battler_release(side: String) -> void:
	if side == "enemy":
		if not controller.enemy_party.is_empty():
			_refresh_sprite(controller.enemy_party[0], false)
			_play_cry_for_mon(controller.enemy_party[0])
	else:
		if not controller.player_party.is_empty():
			_refresh_sprite(controller.player_party[0], true)
			_play_cry_for_mon(controller.player_party[0])


## The intro is over: HUD back, full display refresh (sprite
## refresh is key-cached, so sides already shown are not
## re-fetched), sequencer freed.
func _on_intro_finished() -> void:
	_intro_active = false
	$TopBar.visible = true
	$MenuBar.visible = true
	_refresh_display()
	if intro != null:
		intro.queue_free()
		intro = null


## Difficulty-wiring build (B7): the demo parties are BUILT by
## the difficulty layer (PUWTeamBuilder), never raw dicts — so
## opening battle.tscn directly can no longer produce an
## unbuilt placeholder fight.
func _demo_player_party() -> Array:
	return [PUWTeamBuilder.new().build_mon("Pikachu", 12, "singles")]


func _demo_enemy_party() -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	return [PUWTeamBuilder.new().build_wild_mon("Pidgey", 9, rng)]


func _on_move_pressed(slot: int) -> void:
	if battle_over or _intro_active or _animating:
		return
	if controller.player_party.is_empty():
		return
	var mon: Dictionary = controller.player_party[0]
	var moves: Array = mon.get("moves", [])
	if slot >= moves.size():
		_add_log("That move slot is empty.")
		return
	var move_name: String = str(moves[slot])
	var action: Dictionary = {"type": "move", "move_name": move_name}
	_animating = true
	# Play the player's move animation FIRST and wait for it
	# (binding build 6): real PBAnimation sequence when one is
	# held, Showdown effect shapes next, plain lunge last — the
	# autoload resolves that order itself.
	if has_node("/root/BattleAnims"):
		var anims: Variant = get_node("/root/BattleAnims")
		await anims.play_move_animation_async(move_name, player_mon, enemy_mon, "user")
	var result: Dictionary = controller.run_turn(action, controller.field_state)
	for line in result.get("logs", []):
		_add_log(str(line))
	# PATCHES P1 step 5: the HP drain is awaited here so the
	# bars drain as the hit lands, between the move animation
	# above and the turn's event playback below.
	await _refresh_display()
	# Then play back everything the turn recorded: the enemy's
	# move, faints, switches and ball throws, in order.
	if has_node("/root/BattleAnims"):
		await _play_anim_events(get_node("/root/BattleAnims"))
	_animating = false
	_check_battle_end(str(result.get("status", "ongoing")))


func _on_run_pressed() -> void:
	if battle_over or _intro_active or _animating:
		return
	_animating = true
	var result: Dictionary = controller.run_turn({"type": "run"}, controller.field_state)
	for line in result.get("logs", []):
		_add_log(str(line))
	_refresh_display()
	if has_node("/root/BattleAnims"):
		await _play_anim_events(get_node("/root/BattleAnims"))
	_animating = false
	_check_battle_end(str(result.get("status", "ongoing")))


## Battle entry animations (binding build 6). Fire-and-forget:
## the cries above already fired, input connects after _ready,
## and nothing about the battle state waits on these pictures.
func _play_entry_animations() -> void:
	if not has_node("/root/BattleAnims"):
		return
	var anims: Variant = get_node("/root/BattleAnims")
	if controller.is_wild:
		anims.play_state_animation(enemy_mon, "send_out")
	else:
		anims.play_send_out("pokeball", enemy_mon, enemy_mon)
	anims.play_send_out("pokeball", player_mon, player_mon)


## Play back the controller's recorded anim_events in order
## (binding build 6). The player's own "move" events are skipped:
## _on_move_pressed already played that animation before the
## turn resolved. Everything else plays here, awaited, so a
## faint lands before the next event starts.
func _play_anim_events(anims: Variant) -> void:
	if anims == null:
		return
	for ev in controller.anim_events:
		if not (ev is Dictionary):
			continue
		var event: Dictionary = ev
		var kind: String = str(event.get("kind", ""))
		var side: String = str(event.get("side", ""))
		var actor: Node2D = player_mon if side == "player" else enemy_mon
		var other: Node2D = enemy_mon if side == "player" else player_mon
		match kind:
			"move":
				if side == "player":
					continue
				await anims.play_move_animation_async(str(event.get("move_id", "")), actor, other, "opp")
			"faint":
				anims.play_state_animation(actor, "faint")
				await get_tree().create_timer(0.65).timeout
			"send_out":
				await _await_send_out(anims, actor)
			"ball_throw":
				await _await_ball_throw(anims, str(event.get("ball", "pokeball")), actor, other, bool(event.get("caught", false)))


func _await_send_out(anims: Variant, battler: Node2D) -> void:
	var flag: Array = [false]
	anims.play_send_out("pokeball", battler, battler, func() -> void: flag[0] = true)
	var guard: int = 0
	while not flag[0] and guard < 600:
		await get_tree().process_frame
		guard += 1


func _await_ball_throw(anims: Variant, ball_id: String, thrower: Node2D, target: Node2D, caught: bool) -> void:
	var flag: Array = [false]
	anims.play_ball_throw(ball_id, thrower, target, caught, func() -> void: flag[0] = true)
	var guard: int = 0
	while not flag[0] and guard < 600:
		await get_tree().process_frame
		guard += 1


func _on_bag_pressed() -> void:
	if _intro_active:
		return
	BagScene.return_scene_path = "res://scenes/battle.tscn"
	BagScene.target_mon = controller.player_party[0] if not controller.player_party.is_empty() else {}
	# Bag use context (binding build 4, code_prep_items merge
	# step 3a): the battle supplies the live party; the engine's
	# context items (e.g. Sacred Ash) read it from there.
	BagScene.use_context = {"party": controller.player_party}
	get_tree().change_scene_to_file("res://scenes/bag.tscn")


func _on_party_pressed() -> void:
	if _intro_active:
		return
	PartyScene.return_scene_path = "res://scenes/battle.tscn"
	PartyScene.in_battle = true
	PartyScene.party = controller.player_party
	get_tree().change_scene_to_file("res://scenes/party.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


## Mechanics prep F2 (2026-11-24): when a battle ends, route
## the finished player party through the permadeath bridge
## exactly once. The bridge delegates every decision to
## PUWCombatConsequences (story + co-op count; simulations
## and rentals are exempt). The updated collections are
## written back to the shared channels the other scenes read:
## BagScene.save_state (party / locked_evo_families /
## fainting_ledger) and PartyScene.party (the survivors).
## Runs before the win/loss log lines so a permanent faint is
## already recorded whatever the outcome was.
func _apply_permadeath_bridge() -> void:
	var context: Dictionary = pending_battle_context
	pending_battle_context = {}
	var party_state: Dictionary = {
		"party": controller.player_party,
		"locked_evo_families": BagScene.save_state.get("locked_evo_families", {}),
		"fainting_ledger": BagScene.save_state.get("fainting_ledger", []),
	}
	var outcome: Dictionary = PUWPermadeathBridge.apply_battle_end(party_state, controller.player_party, context)
	var new_state: Dictionary = outcome.get("state", {})
	BagScene.save_state["party"] = new_state.get("party", controller.player_party)
	BagScene.save_state["locked_evo_families"] = new_state.get("locked_evo_families", {})
	BagScene.save_state["fainting_ledger"] = new_state.get("fainting_ledger", [])
	PartyScene.party = new_state.get("party", controller.player_party)
	for removed_value in outcome.get("removed", []):
		var removed_mon: Dictionary = removed_value
		_add_log(str(removed_mon.get("name", "A Pokemon")) + " fainted and was lost for good.")


func _check_battle_end(status: String) -> void:
	if status == "ongoing" or status == "must_switch":
		if status == "must_switch":
			_add_log("Your Pokemon fainted! Pick the next one in the Party screen.")
			_on_party_pressed()
		return
	battle_over = true
	_apply_permadeath_bridge()
	match status:
		"player_won":
			_add_log("You won the battle!")
			# Victory jingle (audio wiring build) on the
			# director's jingle channel.
			if music_director != null:
				music_director.play_jingle(PUWMusicDirector.track_for_battle("victory"))
		"enemy_won":
			_add_log("You lost the battle...")
		"fled":
			_add_log("Got away safely!")
		"caught":
			_add_log("Gotcha! The wild Pokemon was caught!")
		_:
			_add_log("Battle ended: " + status)


func _refresh_display() -> void:
	# Battle presentation (fold-in round, PATCHES P1 step 4):
	# the first display of each battler is instant (_show_mon);
	# once the databoxes are live, refreshes animate the HP
	# drain (_show_mon_animated). Callers that must order the
	# drain against other playback await this function.
	if not controller.player_party.is_empty():
		if _databox_live:
			await _show_mon_animated(controller.player_party[0], player_name_label, player_level_label, player_hp_bar, player_hp_label, player_extras, true)
		else:
			_show_mon(controller.player_party[0], player_name_label, player_level_label, player_hp_bar, player_hp_label, player_extras, true)
		_refresh_move_buttons(controller.player_party[0])
		_refresh_sprite(controller.player_party[0], true)
	if not controller.enemy_party.is_empty():
		if _databox_live:
			await _show_mon_animated(controller.enemy_party[0], enemy_name_label, enemy_level_label, enemy_hp_bar, enemy_hp_label, enemy_extras, false)
		else:
			_show_mon(controller.enemy_party[0], enemy_name_label, enemy_level_label, enemy_hp_bar, enemy_hp_label, enemy_extras, false)
		_refresh_sprite(controller.enemy_party[0], false)
	_databox_live = true
	_react_to_hp_changes()
	# Input prep: if a turn cycle left nothing focused (a button
	# was disabled under the cursor), restore a live focus target
	# so the D-pad / A button keep working without a mouse click.
	if get_viewport() != null and get_viewport().gui_get_focus_owner() == null:
		PUWFocus.grab_first_enabled([move_button_1, move_button_2, move_button_3, move_button_4])

		# Enemy replacement send-out (audio wiring build):
		# when the shown enemy's identity changes after the
		# first display, the new mon was just sent out - play
		# its cry. The first display only records the identity;
		# the lead cry already played in _ready.
		var enemy_identity: String = _mon_identity(controller.enemy_party[0])
		if _shown_enemy_identity != "" and enemy_identity != _shown_enemy_identity:
			_play_cry_for_mon(controller.enemy_party[0])
		_shown_enemy_identity = enemy_identity


## Resolve and show the active mon's picture through the
## shared sprite binding: animated GIF first, indexed still
## as fallback, back view for the player's own Pokemon, front
## view for the foe, shiny pictures for shiny mons. The
## shown-key is species + forme + view + shiny (the binding's
## cache key), so any forme change refreshes the picture.
## When the binding honestly reports "missing" (no sprite of
## any kind for that forme/view), the side shows NOTHING: the
## flat placeholder block is hidden and any previous sprite is
## cleared, so a placeholder is never presented as the
## Pokemon. When a picture lands, the placeholder is hidden.
func _refresh_sprite(mon: Dictionary, is_player: bool) -> void:
	if sprite_loader == null:
		return
	if str(mon.get("family", "")) == "MDX":
		_refresh_sprite_mdx(mon, is_player)
		return
	var binding: PUWPokemonSpriteBinding = sprite_loader.binding()
	var result: Dictionary = binding.resolve_for_mon(mon, PUWPokemonSpriteBinding.CONTEXT_BATTLE, is_player)
	if is_player:
		_player_result = result
		_player_mdx = {}
	else:
		_enemy_result = result
		_enemy_mdx = {}
	var key: String = str(result.get("cache_key", ""))
	if key.is_empty():
		# Unresolvable name: key on the raw input so we do not
		# retry every refresh, and show nothing for it.
		key = "unresolved:" + str(mon.get("species_slug", mon.get("species", mon.get("name", "")))) + ":" + str(mon.get("forme", ""))
	if is_player and key == _shown_player_key:
		return
	if not is_player and key == _shown_enemy_key:
		return
	var target: AnimatedSprite2D = player_sprite2d if is_player else enemy_sprite2d
	var on_ready: Callable = _on_player_sprite_ready if is_player else _on_enemy_sprite_ready
	if is_player:
		_shown_player_key = key
	else:
		_shown_enemy_key = key
	var stage: PUWRigStage = player_rig_stage if is_player else enemy_rig_stage
	if stage != null:
		stage.clear()
		stage.visible = false
	var url: String = str(result.get("url", ""))
	if url.is_empty():
		# Honest empty result: clear any previous sprite and
		# hide the placeholder block on this side.
		if target != null:
			target.stop()
			target.sprite_frames = null
		_hide_placeholder(is_player)
		return
	sprite_loader.get_url_sprite(url, key, target, on_ready)


## Binding build 5: present an MDX-family mon with its own
## bound Moemon battle art. The slot is the mon's own MDX
## mapping slot (form slots matched by form name when the mon
## carries one, else the species' base slot); the view is the
## slot record's own file (player = back, enemy = front, shiny
## variants honored). Playback starts from the sprite-ready
## callback, driven by the record's "motion" field: the BW2
## engine-procedural idle for the kit keyframes, the engine
## rig for the still slots.
func _refresh_sprite_mdx(mon: Dictionary, is_player: bool) -> void:
	if mdx_data == null:
		return
	var slug: String = str(mon.get("species_slug", ""))
	if slug.is_empty():
		slug = PUWTeamBuilder.slugify(str(mon.get("species", mon.get("name", ""))))
	var entry: Dictionary = _mdx_entry_for_mon(mon, slug)
	if entry.is_empty():
		return
	var slot: int = int(entry.get("slot", 0))
	if slot <= 0:
		return
	var record: Dictionary = mdx_data.battle_sprite_for_slot(slot)
	if record.is_empty():
		return
	# The battle record alone does not name its species; the
	# motion starter needs the slug for rig lookups.
	record["species_slug"] = slug
	record["slot"] = slot
	var shiny: bool = bool(mon.get("shiny", false))
	var view_key: String = ""
	if is_player:
		view_key = "back_shiny" if shiny else "back"
	else:
		view_key = "front_shiny" if shiny else "front"
	var views: Dictionary = record.get("views", {})
	var rel_path: String = str(views.get(view_key, ""))
	if rel_path.is_empty():
		return
	var key: String = "mdx|" + str(slot) + "|" + view_key + "|" + rel_path
	if is_player and key == _shown_player_key:
		return
	if not is_player and key == _shown_enemy_key:
		return
	if is_player:
		_shown_player_key = key
		_player_mdx = record
		_player_result = {}
	else:
		_shown_enemy_key = key
		_enemy_mdx = record
		_enemy_result = {}
	var stage: PUWRigStage = player_rig_stage if is_player else enemy_rig_stage
	if stage != null:
		stage.clear()
		stage.visible = false
	var target: AnimatedSprite2D = player_sprite2d if is_player else enemy_sprite2d
	var on_ready: Callable = _on_player_sprite_ready if is_player else _on_enemy_sprite_ready
	sprite_loader.get_url_sprite("res://" + rel_path, key, target, on_ready)


## The MDX mapping entry for a battle mon: an exact form-name
## match among the species' slots when the mon names a form,
## else the species' base (first) slot.
func _mdx_entry_for_mon(mon: Dictionary, slug: String) -> Dictionary:
	var slots: Array = mdx_data.slots_for(slug)
	if slots.is_empty():
		return {}
	var forme: String = str(mon.get("forme", ""))
	if not forme.is_empty():
		var wanted: String = _norm_token(forme)
		for entry_value in slots:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			if _norm_token(str(entry.get("form_name", ""))) == wanted:
				return entry
	var first_value: Variant = slots[0]
	if first_value is Dictionary:
		var first: Dictionary = first_value
		return first
	return {}


static func _norm_token(text: String) -> String:
	var out: String = ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


func _hide_placeholder(is_player: bool) -> void:
	var holder: Node2D = player_mon if is_player else enemy_mon
	var node_name: String = "PlayerSprite" if is_player else "EnemySprite"
	var placeholder: ColorRect = holder.get_node_or_null(node_name) as ColorRect
	if placeholder != null:
		placeholder.visible = false


func _on_player_sprite_ready(target: AnimatedSprite2D) -> void:
	_hide_placeholder(true)
	_on_battler_presented(true, target)


func _on_enemy_sprite_ready(target: AnimatedSprite2D) -> void:
	_hide_placeholder(false)
	_on_battler_presented(false, target)


## Binding build 5: a battler's picture has landed — start its
## motion. MDX records play by their own "motion" field; a
## PKDX result carrying an engine rig is presented on the rig
## stage; any other (animated) sprite gets the BattleAnims
## send-out followed by the looping idle. These are the first
## production callers of play_state_animation.
func _on_battler_presented(is_player: bool, target: AnimatedSprite2D) -> void:
	var holder: Node2D = player_mon if is_player else enemy_mon
	var mdx_record: Dictionary = _player_mdx if is_player else _enemy_mdx
	if not mdx_record.is_empty():
		_start_mdx_motion(is_player, mdx_record, target)
		return
	var result: Dictionary = _player_result if is_player else _enemy_result
	var rig_value: Variant = result.get("rig", {})
	if rig_value is Dictionary:
		var rig: Dictionary = rig_value
		if not rig.is_empty():
			_start_rig_presentation(is_player, rig, target)
			return
	_start_state_motion(holder, "send_out")
	_start_idle_deferred(holder)


func _battle_anims():
	if has_node("/root/BattleAnims"):
		return get_node("/root/BattleAnims")
	return null


func _start_state_motion(holder: Node2D, state: String) -> void:
	var anims = _battle_anims()
	if anims != null and anims.has_method("play_state_animation"):
		anims.play_state_animation(holder, state)


func _start_idle_deferred(holder: Node2D) -> void:
	# The send-out rise runs 0.4 s; the idle loop starts just
	# after it lands so the two tweens never fight over the
	# holder's height. A faint/hurt in between cancels the
	# restart through the captured HP check in _react.
	var timer: SceneTreeTimer = get_tree().create_timer(0.45)
	timer.timeout.connect(_start_state_motion.bind(holder, "idle"))


## MDX motion, read from the slot record's own "motion" field:
## "bw2-engine-procedural-ctrl" = the source engine's
## procedural idle, played by BattleAnims on the keyframe;
## "engine-rigged*" = the still is presented on the rig stage
## with the species' rig definition when one exists, else the
## same procedural idle (the motion is engine-driven either
## way — never a faked frame sequence).
func _start_mdx_motion(is_player: bool, record: Dictionary, target: AnimatedSprite2D) -> void:
	var holder: Node2D = player_mon if is_player else enemy_mon
	var motion: String = str(record.get("motion", ""))
	if motion == "rig_template":
		# A-30 (binding build 6): rig-template slots carry a still
		# plus a rig template, not a cut rig. They present with the
		# engine-procedural idle, exactly like the engine-procedural
		# slots -- never the PUWRigStage part-cut path below (that
		# is only for engine-rigged stills with a real rig
		# definition) and never an "unwired motion" fall-through.
		_start_state_motion(holder, "idle")
		return
	if motion.begins_with("engine-rigged"):
		var slug: String = str(record.get("species_slug", ""))
		var definition: Dictionary = _rig_definition_for(slug)
		if not definition.is_empty():
			_present_on_rig_stage(is_player, definition, target)
			return
	_start_state_motion(holder, "idle")


func _rig_definition_for(slug: String) -> Dictionary:
	if sprite_loader == null:
		return {}
	var registry: PUWRigRegistry = sprite_loader.binding().rig_registry()
	var record: Dictionary = registry.battle_rig(slug)
	if record.is_empty():
		record = registry.follower_rig(slug)
	return registry.definition_for_rig(record)


func _start_rig_presentation(is_player: bool, rig: Dictionary, target: AnimatedSprite2D) -> void:
	if sprite_loader != null:
		var registry: PUWRigRegistry = sprite_loader.binding().rig_registry()
		var definition: Dictionary = registry.definition_for_rig(rig)
		if not definition.is_empty():
			_present_on_rig_stage(is_player, definition, target)
			return
	var holder: Node2D = player_mon if is_player else enemy_mon
	_start_state_motion(holder, "idle")


## Cut the still currently on the target into rig parts and
## play the rig's idle track. The plain sprite is hidden —
## the stage IS the presentation of that still now.
func _present_on_rig_stage(is_player: bool, definition: Dictionary, target: AnimatedSprite2D) -> void:
	var stage: PUWRigStage = player_rig_stage if is_player else enemy_rig_stage
	if stage == null or target == null or target.sprite_frames == null:
		return
	if target.sprite_frames.get_frame_count("default") < 1:
		return
	var texture: Texture2D = target.sprite_frames.get_frame_texture("default", 0)
	if texture == null:
		return
	if stage.build(texture, definition):
		stage.set_track("idle")
		stage.visible = true
		target.visible = false


## Binding build 5: HP reactions. Called at the end of every
## display refresh; the first call per side only sets the
## baseline. A drop plays "hurt" (and restarts the idle for
## sprite presentations); reaching 0 plays "faint" and stops
## any rig presentation.
func _react_to_hp_changes() -> void:
	if not controller.player_party.is_empty():
		_react_side(controller.player_party[0], true)
	if not controller.enemy_party.is_empty():
		_react_side(controller.enemy_party[0], false)


func _react_side(mon: Dictionary, is_player: bool) -> void:
	var hp: int = int(mon.get("hp", 0))
	var last: int = _last_player_hp if is_player else _last_enemy_hp
	if is_player:
		_last_player_hp = hp
	else:
		_last_enemy_hp = hp
	if last < 0 or hp >= last:
		return
	var holder: Node2D = player_mon if is_player else enemy_mon
	if hp <= 0:
		_start_state_motion(holder, "faint")
		var stage: PUWRigStage = player_rig_stage if is_player else enemy_rig_stage
		if stage != null:
			stage.clear()
			stage.visible = false
		return
	_start_state_motion(holder, "hurt")
	# A rig-stage presentation keeps its own continuous motion
	# (the hurt shake rides on the holder). Sprite and
	# procedural presentations restart their idle loop, which
	# the hurt state stopped.
	var stage2: PUWRigStage = player_rig_stage if is_player else enemy_rig_stage
	if stage2 == null or not stage2.visible:
		_start_idle_deferred(holder)


## Squashed move name -> {"pp_max", "type"} from the move
## database, built once for the move-button polish (PATCHES P2).
func _build_move_info() -> Dictionary:
	var info: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_database_954.json"))
	if parsed is Dictionary:
		var moves_v: Variant = (parsed as Dictionary).get("moves", {})
		if moves_v is Dictionary:
			var moves: Dictionary = moves_v
			for name_v in moves.keys():
				var entry_v: Variant = moves[name_v]
				if entry_v is Dictionary:
					var entry: Dictionary = entry_v
					var key: String = str(name_v).to_upper().replace(" ", "").replace("-", "").replace("_", "")
					info[key] = {"pp_max": int(entry.get("pp_max", entry.get("pp", 0))), "type": str(entry.get("type", ""))}
	return info


## The player's battler EXP fraction in [0, 1] for the databox
## EXP bar (PATCHES P1): the mon dict's own exp_fraction when
## it carries one, else computed from exp_system at this call
## site with the controller's own total-exp normalization.
func _exp_fraction(mon: Dictionary) -> float:
	if mon.has("exp_fraction"):
		return clampf(float(mon.get("exp_fraction", 0.0)), 0.0, 1.0)
	var growth: String = str(mon.get("growth_rate", ""))
	if growth == "" or not mon.has("exp"):
		return 0.0
	var level: int = int(mon.get("level", 1))
	if level >= 100:
		return 1.0
	var total: int = int(mon.get("exp", 0))
	if not bool(mon.get("exp_is_total", false)):
		total = EXPSystem.exp_for_level(growth, level) + total
	var lo: int = EXPSystem.exp_for_level(growth, level)
	var hi: int = EXPSystem.exp_for_level(growth, level + 1)
	if hi <= lo:
		return 0.0
	return clampf(float(total - lo) / float(hi - lo), 0.0, 1.0)


## Shared databox label work for _show_mon / _show_mon_animated:
## name, level, status chip, and the HP number — the player's
## side only. The enemy side's HP label is never written and
## stays hidden (PM ruling 2026-11-24: BW2 shows the foe the
## bar only).
func _show_mon_labels(mon: Dictionary, name_label: Label, level_label: Label, hp_label: Label, extras: Dictionary, is_player: bool) -> void:
	name_label.text = str(mon.get("name", mon.get("species", "Pokemon")))
	level_label.text = "Lv " + str(mon.get("level", 1))
	var hp: int = int(mon.get("hp", 0))
	var max_hp: int = maxi(1, int(mon.get("max_hp", 1)))
	if is_player:
		hp_label.text = str(hp) + " / " + str(max_hp)
		hp_label.visible = true
	else:
		hp_label.visible = false
	var chip_v: Variant = extras.get("status_chip", null)
	if chip_v is Label:
		var chip: Label = chip_v
		PUWDataboxExtras.refresh_status(chip, str(mon.get("status", "")))


func _show_mon(mon: Dictionary, name_label: Label, level_label: Label, hp_bar: ProgressBar, hp_label: Label, extras: Dictionary, is_player: bool) -> void:
	_show_mon_labels(mon, name_label, level_label, hp_label, extras, is_player)
	var hp: int = int(mon.get("hp", 0))
	var max_hp: int = maxi(1, int(mon.get("max_hp", 1)))
	PUWUiTheme.update_hp_bar(hp_bar, hp, max_hp)
	if is_player:
		var exp_bar_v: Variant = extras.get("exp_bar", null)
		if exp_bar_v is ProgressBar:
			var exp_bar: ProgressBar = exp_bar_v
			_player_exp_frac = _exp_fraction(mon)
			PUWUiTheme.update_exp_bar(exp_bar, _player_exp_frac)


## Post-turn databox refresh (PATCHES P1): same labels as
## _show_mon, but the HP bar drains through the theme tween
## and the player EXP bar animates from the last shown
## fraction. Awaited from _refresh_display once the databoxes
## are live, so the drain lands between the move animation
## and the turn's event playback (PATCHES P1 step 5).
func _show_mon_animated(mon: Dictionary, name_label: Label, level_label: Label, hp_bar: ProgressBar, hp_label: Label, extras: Dictionary, is_player: bool) -> void:
	_show_mon_labels(mon, name_label, level_label, hp_label, extras, is_player)
	var hp: int = int(mon.get("hp", 0))
	var max_hp: int = maxi(1, int(mon.get("max_hp", 1)))
	await PUWDataboxExtras.animate_hp(hp_bar, hp, max_hp, self)
	if is_player:
		var exp_bar_v: Variant = extras.get("exp_bar", null)
		if exp_bar_v is ProgressBar:
			var exp_bar: ProgressBar = exp_bar_v
			var new_frac: float = _exp_fraction(mon)
			var tween: Tween = PUWDataboxExtras.animate_exp(exp_bar, _player_exp_frac, new_frac, self)
			if tween != null:
				await tween
			_player_exp_frac = new_frac


func _refresh_move_buttons(mon: Dictionary) -> void:
	PUWMoveButtonPolish.apply([move_button_1, move_button_2, move_button_3, move_button_4], mon, move_info)


func _add_log(line: String) -> void:
	log_label.append_text(line + "\n")
