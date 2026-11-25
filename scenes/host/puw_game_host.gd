class_name PUWGameHost
extends Node2D
## The real overworld host (host assembly prep, 2026-11-24).
##
## The root finding this closes (mechanics audit, family 1-5):
## the live boot path bypassed the whole game -- title ->
## placeholder overworld, and PUWPlayerController /
## PUWMapLoader / PUWRideSystem / PUWFieldActions /
## PUWSpawner were never instantiated outside tests. This
## scene is the plug. It composes, on one real map:
##
##   PUWOverworldMechanicsGlue (mechanics prep F6/F9) --
##     PUWMapLoader (+ PUWAmbientTileAnimator via the ambient
##     prep's loader hunks), PUWPlayerController (rides, bikes
##     incl. the F5 Rotom re-fit, badge-locked field actions),
##     PUWSpawner, PUWHabitatEncounters, PUWBattleEntry,
##     PUWFollowerController (incl. the F4 MDX routing fix),
##     PUWLiveWiring, PUWCoopNetworkManager
##   PUWNPCSpriteView per spawned NPC + PUWFollowerSpriteView
##     per active follower (ow_anim prep -- the two renderers
##     the bound game never had)
##   PUWInputInteraction (input prep) -- movement vector,
##     A = talk, Start = menu, B-hold = run
##   PUWDialogueBox + PUWDialogueRunner seam (dialogue prep)
##   PUWEventRunner + PUWEventActor rigs (events prep) --
##     fade + camera applied to a real ColorRect / Camera2D
##   PUWMenuHost (input prep) fed by PUWLiveBag (live-bag
##     prep): bag + X-menu bind the real state on every open
##   PUWMusicDirector (audio prep): map BGM on boot / warp
##
## Battle hand-off: wild (habitat roll), trainer (spawner
## trigger scan) and scripted (event runner) battles all build
## through PUWBattleEntry, pass its hand-off guard, and land
## in launch_battle(), which sets the BattleScene statics the
## bound scene reads (pending parties, campaign region, and
## pending_battle_context -- the channel the mechanics prep's
## F1 gimmick gate + F3 badge feeder + F2 permadeath bridge
## consume) and records the full handoff (kind + trainer
## identity for the VS intro) in pending_handoff, which the
## build-6 merged battle scene reads. The scene wrapper
## (game_host.tscn's parent flow) performs the actual
## change_scene_to_file; apply_battle_return() re-reads the
## shared channels the permadeath bridge wrote back.

signal battle_requested(handoff: Dictionary)
## A-49/A-50 story-lane hand-off: script_give text ids and the
## gift / gift_choice / oak_flow Pokemon-ball routes are the
## story lane's to play; the host emits them here (mirroring
## battle_requested) instead of inventing flows for them.
signal story_handoff(kind: String, payload: Dictionary)
signal dialogue_started(lines: Array)
signal event_finished(result: Dictionary)
signal warp_performed(map_name: String, warp_id: int)

## The most recent battle handoff, in full: {kind, enemy_party,
## player_party, trainer, entry_result, verdict, context}.
## The build-6 battle scene (with the VS prep's statics merged)
## reads kind + trainer identity from here; the mechanics-era
## statics are set directly in launch_battle().
static var pending_handoff: Dictionary = {}

var state: Dictionary = {}
var party: Array = []
var cast_id: String = ""
var current_map: String = ""

var glue: PUWOverworldMechanicsGlue = null
var menu_host: PUWMenuHost = null
var dialogue_box: PUWDialogueBox = null
var music_director: PUWMusicDirector = null
var event_runner: PUWEventRunner = null
var trainer_alert: PUWTrainerAlert = null
var camera: Camera2D = null

var npc_views: Dictionary = {}
var npc_no_sheet: Array = []
var follower_views: Array = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_bag_result: Dictionary = {}
var last_message: String = ""

var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _event_actors: Dictionary = {}
var _gym_triggers: Array = []
var _gym_triggers_loaded: bool = false
var _pending_gym_gate: String = ""
var _menu_bound: bool = false


func _ready() -> void:
	dialogue_box = PUWDialogueBox.new()
	dialogue_box.name = "DialogueBox"
	add_child(dialogue_box)
	menu_host = PUWMenuHost.new()
	menu_host.name = "MenuHost"
	add_child(menu_host)
	music_director = PUWMusicDirector.new()
	music_director.name = "MusicDirector"
	add_child(music_director)
	event_runner = PUWEventRunner.new()
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "EventFadeLayer"
	_fade_layer.layer = 10
	_fade_rect = ColorRect.new()
	_fade_rect.name = "EventFade"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)
	# Boot channel: if the boot scene handed over a new-game /
	# continue result, boot from it on the next frame (the glue
	# setup loads a map scene; deferring keeps _ready light).
	if not PUWBootFlow.pending_boot.is_empty():
		var pending: Dictionary = PUWBootFlow.pending_boot
		PUWBootFlow.pending_boot = {}
		_boot_from_pending.call_deferred(pending)


func _boot_from_pending(pending: Dictionary) -> void:
	var p_state_value: Variant = pending.get("state", {})
	var p_state: Dictionary = p_state_value if p_state_value is Dictionary else {}
	var p_party_value: Variant = pending.get("party", [])
	var p_party: Array = p_party_value if p_party_value is Array else []
	boot(p_state, p_party, str(pending.get("start_map", PUWBootFlow.DEFAULT_MAP)), str(pending.get("cast_id", "")))


## Boot the host on a real map with a real state + party (from
## PUWBootFlow.new_game / continue_game). Returns the glue's
## setup report extended with renderer counts:
## {ok, map, spawn_report, followers, npc_views, npc_no_sheet,
## follower_views}. ok=false leaves nothing half-set-up.
func boot(p_state: Dictionary, p_party: Array, map_name: String, p_cast_id: String = "") -> Dictionary:
	state = p_state
	party = p_party
	cast_id = p_cast_id
	BagScene.save_state = state
	PartyScene.party = party
	glue = PUWOverworldMechanicsGlue.new()
	glue.name = "MechanicsGlue"
	add_child(glue)
	var setup: Dictionary = glue.setup(map_name, state, party, cast_id)
	if not bool(setup.get("ok", false)):
		return setup
	current_map = str(setup.get("map", map_name))
	PUWBootFlow.record_current_map(state, current_map)
	if glue.followers != null and glue.map_loader != null:
		glue.followers.set_behavior_loader(glue.map_loader)
	_attach_npc_views()
	# Overworld-life (fold-in round): the trainer alert is a
	# per-boot glue child — change_map() frees and rebuilds
	# the glue, so it is created here, never in _ready().
	trainer_alert = PUWTrainerAlert.new()
	trainer_alert.name = "TrainerAlert"
	glue.add_child(trainer_alert)
	trainer_alert.alert_finished.connect(_on_trainer_alert_finished)
	# Character appearance (fold-in round, creator bind
	# step 5): the saved character dict resolves to a render
	# spec and applies to the player node — height scale
	# plus BodyLayer/HairLayer tints; missing layers are
	# skipped, never fabricated. (Applied here, after the
	# pick-UI host replacement and the trainer-alert edits,
	# so no host write overwrites another.)
	var flags_v: Variant = state.get("story_flags", {})
	if flags_v is Dictionary:
		var flags: Dictionary = flags_v
		var char_v: Variant = flags.get(PUWCharacterSetup.SAVE_FLAG_KEY, {})
		if char_v is Dictionary and glue.player != null:
			var character: Dictionary = char_v
			var spec: Dictionary = PUWAppearanceLayers.resolve(character)
			PUWAppearanceLayers.apply_to_node(spec, glue.player)
	if glue.player != null:
		glue.player.warp_veto = Callable(self, "_warp_veto")
	# A-49: collected item balls / hidden items do not respawn —
	# hide their nodes on the freshly spawned map.
	PUWItemPickups.despawn_collected_nodes(glue, state)
	_apply_fixed_encounter_visibility()
	_build_follower_views()
	camera = Camera2D.new()
	camera.name = "HostCamera"
	glue.player.add_child(camera)
	camera.enabled = true
	bind_menu_state()
	if music_director != null:
		music_director.play_map_bgm(current_map)
	_check_entry_triggers()
	var report: Dictionary = setup.duplicate()
	report["npc_views"] = npc_views.size()
	report["npc_no_sheet"] = npc_no_sheet.duplicate()
	report["follower_views"] = follower_views.size()
	return report


## Feed the menu stack the real state (live-bag prep's
## hand-over, exactly): the bag panel binds state + field
## context, the X-menu binds state, save goes to the real
## PUWSaveManager, bag results surface as host messages, and
## an escape-rope result warps through the map loader.
func bind_menu_state() -> void:
	if menu_host == null or menu_host.stack == null or glue == null:
		return
	menu_host.bag_screen.bind_state(state, {"habitat": glue.habitat, "map_loader": glue.map_loader})
	menu_host.xmenu.bind_state(state)
	menu_host.bind_state(state)
	menu_host.bind_map(current_map)
	if not _menu_bound:
		_menu_bound = true
		menu_host.save_requested.connect(_on_save_requested)
		menu_host.bag_screen.bag_action_resolved.connect(_on_bag_action_resolved)
		# build6_remainders (remainder 5): close the pick-UI
		# loop. The fossil / ferry story hand-offs this host
		# emits had NO consumer anywhere in the tree — the
		# host now consumes its own hand-offs and opens the
		# menu host's pick panels, and the panels' answers
		# route back to the seams that were already wired
		# (run_fossil_choice / run_ferry / change_map).
		story_handoff.connect(_on_story_handoff)
		menu_host.fossil_chosen.connect(run_fossil_choice)
		menu_host.ferry_chosen.connect(run_ferry)
		menu_host.floor_chosen.connect(_on_floor_chosen)


func _on_save_requested() -> void:
	PUWSaveManager.save_game(state)


func _on_bag_action_resolved(action_id: String, item_slug: String, result: Dictionary) -> void:
	last_bag_result = result
	if bool(result.get("ok", false)) and str(result.get("effect", "")) == "escape_rope":
		var target_value: Variant = result.get("target", {})
		if target_value is Dictionary:
			var target: Dictionary = target_value
			change_map(str(target.get("map", "")), int(target.get("warp_id", -1)))


## Attach the missing NPC renderer to every spawned node that
## carries spawner metadata (ow_anim prep merge step 3).
func _attach_npc_views() -> void:
	npc_views.clear()
	npc_no_sheet.clear()
	for child_value in glue.get_children():
		var node: Node = child_value
		if not node.has_meta("kind"):
			continue
		# People only, in the spawner's own kind taxonomy:
		# npc / trainer / object are people (object = stationary
		# encounter people and script-give objects, sprite
		# included); item and sign are things -- a sign with an
		# NPC view child is a frameless wart and pollutes the
		# no_sheet report.
		var kind: String = str(node.get_meta("kind"))
		if kind != "npc" and kind != "trainer" and kind != "object":
			continue
		var view: PUWNPCSpriteView = PUWNPCSpriteView.new()
		view.name = "NPCSpriteView"
		node.add_child(view)
		var sprite_id: String = str(node.get_meta("sprite", ""))
		if view.setup_bank(sprite_id):
			view.face(str(node.get_meta("direction", "down")))
			view.set_moving(false)
			npc_views[node.get_instance_id()] = view
		else:
			npc_no_sheet.append(sprite_id)


## Create one follower renderer per active follower (ow_anim
## prep merge step 4). Sheet preference is the follower
## controller's own resolution (F4: MDX routes through
## PUWMDXData, never borrowed PKDX art). Followers whose
## resolved sheet is a local charset install it; frame-file
## (HGSS) and URL-only (PMD) resolutions stay undrawn and are
## counted in the boot report by their absence -- never
## silently dressed in another source's sheet.
func _build_follower_views() -> void:
	for view_value in follower_views:
		var old_view: Node = view_value
		old_view.queue_free()
	follower_views.clear()
	if glue == null or glue.followers == null:
		return
	var records: Array = glue.followers.get_followers()
	for i in range(records.size()):
		var info: Dictionary = glue.followers.follower_sprite_info(i)
		var view: PUWFollowerSpriteView = PUWFollowerSpriteView.new()
		view.name = "FollowerSpriteView%d" % i
		add_child(view)
		var url: String = str(info.get("url", ""))
		if url.begins_with("res://") and ResourceLoader.exists(url):
			var tex: Texture2D = load(url) as Texture2D
			if tex != null:
				view.setup_charset(tex)
		follower_views.append(view)


## One frame of host life, callable from _process in game and
## directly by headless tests: event playback first (input is
## locked while an event runs), then dialogue, then movement
## + follower behavior + trainer trigger scan.
func host_tick(delta: float) -> void:
	_check_tile_triggers()
	if event_runner != null and event_runner.is_running():
		event_runner.tick(delta)
		_apply_event_presentation()
		return
	if dialogue_box != null and dialogue_box.is_showing():
		return
	if menu_host != null and menu_host.is_open():
		return
	if glue == null or glue.player == null:
		return
	# Overworld-life: while a trainer alert/approach runs,
	# input is locked (the same early return the event
	# runner gets above). A fresh sighting starts the
	# alert INSTEAD of the instant battle below; the
	# battle itself still starts through
	# scan_trainer_trigger when the approach completes
	# (see _on_trainer_alert_finished).
	if trainer_alert != null and trainer_alert.is_running():
		return
	if trainer_alert != null and trainer_alert.try_begin(glue, glue.player.player_tile(), npc_views):
		return
	var vector: Vector2 = PUWInputInteraction.movement_vector()
	if vector == Vector2.ZERO:
		_tick_followers(delta, false)
		return
	var mode: String = "run" if PUWInputInteraction.run_held() else "walk"
	glue.step(delta, vector, mode)
	_tick_followers(delta, true)
	var trigger: Dictionary = glue.scan_trainer_trigger()
	if not trigger.is_empty():
		start_trainer_battle(trigger)


func _tick_followers(delta: float, trainer_moving: bool) -> void:
	if glue == null or glue.followers == null or glue.player == null:
		return
	var records: Array = glue.followers.behavior_tick(delta, glue.player.position, glue.player.facing, trainer_moving)
	for i in range(mini(records.size(), follower_views.size())):
		var record_value: Variant = records[i]
		if record_value is Dictionary:
			var record: Dictionary = record_value
			var view: PUWFollowerSpriteView = follower_views[i]
			view.apply_behavior(record, glue.player.facing)


## A press (Start / touch button): open or close the menu.
## Opening rebinds + refreshes the bag so grants and purchases
## made elsewhere show without a rebind (live-bag hand-over).
func toggle_menu() -> void:
	if menu_host == null:
		return
	var was_open: bool = menu_host.is_open()
	menu_host.toggle_menu()
	if not was_open and menu_host.is_open():
		bind_menu_state()
		if menu_host.bag_screen != null:
			menu_host.bag_screen.refresh_holdings()


## A press next to a placed actor: the input prep's missing
## A-button path -- faced tile -> spawner placement -> the
## spawner's own interaction predicate -> real lines, played
## through the dialogue prep's box. A trainer that triggers
## hands off to battle instead of talking.
func try_interact() -> Dictionary:
	if glue == null or glue.spawner == null or glue.player == null:
		return {"found": false, "trainer": {}, "lines": []}
	var facing_vec: Vector2i = PUWInputInteraction.facing_vector_for(glue.player.facing)
	# A-49: the field seam FIRST — it classifies the faced tile
	# (item ball / hidden item, Pokemon ball, script_give marker)
	# ahead of the plain dialogue path.
	var field_hit: Dictionary = PUWInputInteraction.try_interact_field(
		glue.spawner, state, current_map, glue.player.player_tile(), facing_vec)
	if bool(field_hit.get("found", false)):
		var field_kind: String = str(field_hit.get("kind", ""))
		if field_kind == "item":
			_present_message(str(field_hit.get("message", "")))
			PUWItemPickups.despawn_collected_nodes(glue, state)
			return field_hit
		if field_kind == "pokemon_ball":
			return _dispatch_pokemon_ball(field_hit)
		if field_kind == "script_give":
			story_handoff.emit("script_give", field_hit)
			return field_hit
		if field_kind == "trainer":
			# A-50: a gated gym leader runs the gate protocol,
			# not a plain conversation.
			var trainer_value: Variant = field_hit.get("trainer", {})
			var trainer: Dictionary = trainer_value if trainer_value is Dictionary else {}
			var gate: Dictionary = _gym_gate_for(trainer)
			if not gate.is_empty():
				return run_gym_gate(gate)
			# A-50: the Mt. Moon Super Nerd is the fossil beat;
			# the pick itself is the pick UI's (run_fossil_choice).
			if current_map == "MtMoonB2F" and str(trainer.get("class", "")) == "SUPER_NERD":
				story_handoff.emit("fossil_pick", field_hit)
				return field_hit
	# A-52: an object carrying an event-script ref runs its
	# beat: ferry sailors open the ferry hand-off (flags derived
	# at interact time, destination menu is the story lane's),
	# Bill opens his invitation / return note.
	var faced_object: Dictionary = _object_at(
		current_map, glue.player.player_tile() + facing_vec)
	var script_ref: String = str(faced_object.get("script", ""))
	if script_ref.begins_with("sevii_ferry_"):
		var origin: String = script_ref.trim_prefix("sevii_ferry_")
		var options: Dictionary = ferry_options(origin)
		story_handoff.emit("ferry_menu", options)
		return {"found": true, "kind": "ferry", "options": options}
	if script_ref == "sevii_bill_invitation":
		var invite: Dictionary = PUWEventRunner.load_script_file(
			"res://data/events/sevii_bill_invitation.json")
		if not invite.is_empty():
			return start_event(invite, _cast_for_script(invite))
	if current_map == "OneIsland_PokemonCenter_1F" \
			and str(faced_object.get("sprite", "")) == "bill" \
			and bool(_flags().get("sevii_met_celio", false)):
		var note: Dictionary = PUWEventRunner.load_script_file(
			"res://data/events/sevii_bill_return_note.json")
		if not note.is_empty():
			return start_event(note, _cast_for_script(note))
	# build6_remainders (remainder 5): the two elevator maps'
	# floor-select bg_events open the elevator floor-select.
	# Each elevator map carries exactly ONE bg_event (the
	# panel), so a faced bg_event on these maps is the panel.
	if current_map == "SilphCoElevator" or current_map == "TrainerTower_Elevator":
		var faced_bg: Dictionary = _bg_event_at(
			current_map, glue.player.player_tile() + facing_vec)
		if not faced_bg.is_empty():
			var building: Dictionary = _elevator_building_for(current_map)
			if not building.is_empty() and menu_host != null:
				menu_host.open_elevator(building, current_map)
				return {"found": true, "kind": "elevator", "building": str(building.get("id", ""))}
	# A-50: a placed fixed encounter (Mewtwo) starts its battle
	# on interaction while it is available.
	var fixed_hit: Dictionary = _fixed_encounter_at(
		current_map, glue.player.player_tile() + facing_vec)
	if not fixed_hit.is_empty():
		return start_fixed_encounter(fixed_hit)
	var trigger: Dictionary = glue.scan_trainer_trigger()
	if not trigger.is_empty():
		return start_trainer_battle(trigger)
	var result: Dictionary = PUWInputInteraction.try_interact(glue.spawner, glue.player.player_tile(), facing_vec)
	var lines_value: Variant = result.get("lines", [])
	var lines: Array = lines_value if lines_value is Array else []
	if bool(result.get("found", false)) and not lines.is_empty() and dialogue_box != null:
		dialogue_box.start_dialogue(lines)
		dialogue_started.emit(lines)
	return result


## Show a one-line field message (item found, gate refusal)
## through the dialogue box, in the runner's line shape.
func _present_message(message: String) -> void:
	if message == "" or dialogue_box == null:
		return
	var lines: Array = [{"speaker": "", "text": message}]
	dialogue_box.start_dialogue(lines)
	dialogue_started.emit(lines)


## A-49 Pokemon-ball dispatch: the "battle" route is a real
## scripted battle against the ball's species; "dialogue"
## shows the ball's text through the story lane; the gift /
## gift_choice / oak_flow routes ARE story-lane flows (Dojo +
## Eevee gifts, the Oak starter flow) and hand off untouched.
func _dispatch_pokemon_ball(hit: Dictionary) -> Dictionary:
	var route: String = str(hit.get("route", ""))
	if route == "battle":
		var species: String = str(hit.get("species", ""))
		if species == "" or glue == null or glue.entry == null:
			return {"ok": false, "reason": "ball_battle_unbuilt", "hit": hit}
		var player_max: int = PUWBattleEntry.player_max_level(party)
		var built: Dictionary = glue.entry.start_scripted_battle(
			[species], player_max, "singles", rng, "")
		var team_value: Variant = built.get("enemy_party", [])
		var team: Array = team_value if team_value is Array else []
		if team.is_empty():
			return {"ok": false, "reason": "ball_battle_unbuilt", "hit": hit}
		return launch_battle("scripted", team, {}, {"pokemon_ball": true})
	story_handoff.emit("pokemon_ball_" + route, hit)
	return hit


## Build an event cast from the spawned nodes on this map:
## actor ids match a node's trainer class, its (de-prefixed)
## sprite id, or its source ref; "player" is the player rig.
func _cast_for_script(script: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var cast_value: Variant = script.get("cast", [])
	if cast_value is Array:
		for id_value in cast_value:
			ids[str(id_value)] = true
	var steps_value: Variant = script.get("steps", [])
	if steps_value is Array:
		for step_value in steps_value:
			if step_value is Dictionary:
				var step: Dictionary = step_value
				for key in ["speaker", "actor"]:
					if step.has(key):
						ids[str(step[key])] = true
	var cast: Dictionary = {}
	for id_value in ids.keys():
		var actor_id: String = str(id_value)
		if actor_id == "player":
			if glue != null and glue.player != null:
				cast["player"] = glue.player
			continue
		if glue == null:
			continue
		for child in glue.get_children():
			if not (child is Node2D):
				continue
			var tclass: String = str(child.get_meta("trainer_class", "")).to_lower()
			var sprite: String = str(child.get_meta("sprite", ""))
			if sprite.begins_with("SPRITE_"):
				sprite = sprite.substr(7)
			sprite = sprite.to_lower()
			var source_id: String = str(child.get_meta("source_id", ""))
			if tclass == actor_id or sprite == actor_id or source_id == actor_id:
				cast[actor_id] = child
				break
	return cast


## A-50 gym gates (data/gym_gate_triggers.json): the trigger
## records for the two flag-gated Kanto gyms.
func _load_gym_triggers() -> Array:
	if _gym_triggers_loaded:
		return _gym_triggers
	_gym_triggers_loaded = true
	var path: String = "res://data/gym_gate_triggers.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var triggers_value: Variant = (parsed as Dictionary).get("triggers", [])
			if triggers_value is Array:
				_gym_triggers = triggers_value
	return _gym_triggers


## The gate trigger a faced trainer belongs to, if any: same
## map, and the leader actor matches the trainer's class or
## its placed sprite id.
func _gym_gate_for(trainer: Dictionary) -> Dictionary:
	var tclass: String = str(trainer.get("class", "")).to_lower()
	for trigger_value in _load_gym_triggers():
		if not (trigger_value is Dictionary):
			continue
		var trigger: Dictionary = trigger_value
		if str(trigger.get("map", "")) != current_map:
			continue
		if str(trigger.get("leader_actor", "")) == tclass:
			return trigger
	return {}


## A-50: run one gym gate exactly as its trigger record
## prescribes — evaluate the campaign checker against the
## live state and present the unmet descriptions on refusal;
## when allowed, load the event script, overwrite the battle
## step's badge_count with the live GLOBAL badge count, and
## run it. The badge itself lands through record_gym_win on
## the win branch (see resolve_event_battle).
func run_gym_gate(trigger: Dictionary) -> Dictionary:
	var gym_id: String = str(trigger.get("gym_id", ""))
	var verdict: Dictionary = PUWCampaignStitch.can_start_gym_battle(state, gym_id)
	if not bool(verdict.get("allowed", false)):
		var unmet_value: Variant = verdict.get("unmet", [])
		var unmet: Array = unmet_value if unmet_value is Array else []
		for desc_value in unmet:
			_present_message(str(desc_value))
		return {"ok": false, "reason": "gym_gate_refused", "gym_id": gym_id, "unmet": unmet}
	var script: Dictionary = PUWEventRunner.load_script_file(
		"res://" + str(trigger.get("event_script", "")))
	if script.is_empty():
		return {"ok": false, "reason": "gym_script_missing", "gym_id": gym_id}
	var live_badges: int = GymProgression.badge_count(state)
	var steps_value: Variant = script.get("steps", [])
	if steps_value is Array:
		for step_value in steps_value:
			if step_value is Dictionary:
				var step: Dictionary = step_value
				if str(step.get("badge_count", "")) == "HOST_SUPPLIES_LIVE_GLOBAL_BADGE_COUNT":
					step["badge_count"] = live_badges
	_pending_gym_gate = gym_id
	var started: Dictionary = start_event(script, _cast_for_script(script))
	if not bool(started.get("ok", false)):
		_pending_gym_gate = ""
	return started


## A-50 fossil seam: the pick UI calls this with "dome" or
## "helix"; the host sets the ONE transient pick flag the
## script's step modifiers read and runs the beat with the
## bound placements as actors.
func run_fossil_choice(pick: String) -> Dictionary:
	var flags_value: Variant = state.get("story_flags", {})
	var flags: Dictionary = flags_value if flags_value is Dictionary else {}
	flags["mt_moon_pick_dome"] = pick == "dome"
	flags["mt_moon_pick_helix"] = pick == "helix"
	state["story_flags"] = flags
	var script: Dictionary = PUWEventRunner.load_script_file(
		"res://data/events/mt_moon_fossil_choice.json")
	if script.is_empty():
		return {"ok": false, "reason": "fossil_script_missing"}
	return start_event(script, _cast_for_script(script))


## A-50 fixed encounters: the record placed at a tile on a
## map, while the encounter is still available.
func _fixed_encounter_at(map_name: String, tile: Vector2i) -> Dictionary:
	for record_value in PUWFixedEncounters.records():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if str(record.get("map", "")) != map_name:
			continue
		var object_value: Variant = record.get("object", {})
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if int(object.get("x", -1)) == tile.x and int(object.get("y", -1)) == tile.y:
			if PUWFixedEncounters.is_available(state, record):
				return record
	return {}


## Start a fixed encounter's battle from its record identity
## (species only — the difficulty layer builds the mon).
func start_fixed_encounter(record: Dictionary) -> Dictionary:
	if glue == null or glue.entry == null:
		return {"ok": false, "reason": "host_not_booted"}
	var species_id: int = int(record.get("species_id", 0))
	if species_id <= 0:
		return {"ok": false, "reason": "fixed_identity_missing"}
	var player_max: int = PUWBattleEntry.player_max_level(party)
	var built: Dictionary = glue.entry.start_scripted_battle(
		[{"species_id": species_id}], player_max, "singles", rng, "")
	var team_value: Variant = built.get("enemy_party", [])
	var team: Array = team_value if team_value is Array else []
	if team.is_empty():
		return {"ok": false, "reason": "fixed_battle_unbuilt"}
	return launch_battle("scripted", team, {},
		{"fixed_encounter": str(record.get("id", ""))})


## A-50: the battle driver reports a fixed encounter's
## outcome ("caught" / "defeated" consume it; "ran" /
## "player_teleported" do not, per the record) through the
## prep's own recorder, and the placed object despawn follows
## the recorded availability.
func resolve_fixed_encounter(record_id: String, outcome: String) -> Dictionary:
	var record: Dictionary = PUWFixedEncounters.record_for(record_id)
	if record.is_empty():
		return {"ok": false, "reason": "fixed_record_missing"}
	var recorded: bool = PUWFixedEncounters.record_outcome(state, record, outcome)
	_apply_fixed_encounter_visibility()
	return {"ok": recorded, "record": record_id, "outcome": outcome}


## Hide placed fixed-encounter objects whose encounter is no
## longer available on the current map (Mewtwo after resolve;
## Cerulean Cave re-shows it while the flag is unset, which
## is_available already encodes).
func _apply_fixed_encounter_visibility() -> void:
	if glue == null:
		return
	for record_value in PUWFixedEncounters.records():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if str(record.get("map", "")) != current_map:
			continue
		if PUWFixedEncounters.is_available(state, record):
			continue
		var object_value: Variant = record.get("object", {})
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		var tile: Vector2i = Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		for child in glue.get_children():
			if child is Node2D and child.has_meta("tile"):
				var child_tile: Variant = child.get_meta("tile")
				if child_tile is Vector2i and (child_tile as Vector2i) == tile:
					(child as Node2D).visible = false


## Advance the open dialogue one step (A press while a box is
## showing); when an event is waiting on its line, the same
## press releases the runner.
func advance_dialogue() -> void:
	if dialogue_box != null and dialogue_box.is_showing():
		dialogue_box.advance()
		if not dialogue_box.is_showing() and event_runner != null and event_runner.is_waiting_line():
			event_runner.advance_line()


## Run an event script (events prep) on this host: actors are
## built from the spawned nodes the script's cast names (plus
## the player rig on the real player controller's node), the
## present_line hook plays through the dialogue box, and the
## warp hook performs the warp through the map loader. The
## runner's battle step pauses the event; the host's battle
## return calls resolve_event_battle().
func start_event(script: Dictionary, cast_by_actor: Dictionary, substitutions: Dictionary = {}, seed_value: int = 1) -> Dictionary:
	_event_actors = _build_event_actors(cast_by_actor)
	var hooks: Dictionary = {
		"present_line": Callable(self, "_event_present_line"),
		"on_warp": Callable(self, "_event_on_warp"),
	}
	event_runner.configure(state, _event_actors, hooks, substitutions, seed_value)
	var loaded: Dictionary = event_runner.load_script(script)
	if not bool(loaded.get("ok", false)):
		return loaded
	if glue != null and glue.player != null:
		glue.player.input_enabled = false
	return event_runner.run()


func _build_event_actors(cast_by_actor: Dictionary) -> Dictionary:
	var actors: Dictionary = {}
	var tile_size: int = glue.map_loader.tile_size_px if glue != null and glue.map_loader != null else 16
	for actor_id_value in cast_by_actor.keys():
		var actor_id: String = str(actor_id_value)
		var node_value: Variant = cast_by_actor[actor_id_value]
		var node: Node2D = node_value if node_value is Node2D else null
		var start_tile: Vector2i = Vector2i.ZERO
		var facing: String = "down"
		if node != null and node.has_meta("tile"):
			var tile_value: Variant = node.get_meta("tile")
			if tile_value is Vector2i:
				start_tile = tile_value
			facing = str(node.get_meta("direction", "down"))
		actors[actor_id] = PUWEventActor.create(actor_id, node, start_tile, tile_size, facing)
	if glue != null and glue.player != null and not actors.has("player"):
		actors["player"] = PUWEventActor.create("player", glue.player, glue.player.player_tile(), tile_size, glue.player.facing)
	return actors


func _event_present_line(speaker: String, text: String) -> void:
	if dialogue_box != null:
		dialogue_box.start_dialogue([{"speaker": speaker, "text": text}])


func _event_on_warp(map_name: String, warp_id: int, _tile: Vector2i) -> void:
	change_map(map_name, warp_id)


## The event's battle step is waiting: take its built party
## through the same launch path as every other battle.
func start_event_battle() -> Dictionary:
	if event_runner == null or not event_runner.is_waiting_battle():
		return {"ok": false, "reason": "no_pending_event_battle"}
	var pending: Dictionary = event_runner.pending_battle()
	var team_value: Variant = pending.get("enemy_party", pending.get("party", []))
	var team: Array = team_value if team_value is Array else []
	return launch_battle("scripted", team, {}, {"story": true})


## After an event battle returns: feed the result back into
## the runner (win/lose branch) and restore player input when
## the event completes.
func resolve_event_battle(won: bool) -> void:
	if event_runner == null:
		return
	# A-50: a won gym-gate battle awards the badge through the
	# stitch's own gate-checked path (the trigger's on_win).
	if won and _pending_gym_gate != "":
		PUWCampaignStitch.record_gym_win(state, _pending_gym_gate)
		_pending_gym_gate = ""
	event_runner.resolve_battle(won)
	_drive_event_to_pause()


## Headless/in-game completion driver: tick + advance until
## the event finishes, errors, or pauses on a battle. In game
## the same steps happen across frames via host_tick +
## advance_dialogue; this loop is the deterministic form the
## tests (and a cutscene-skip path) use.
func _drive_event_to_pause() -> Dictionary:
	var guard: int = 0
	while event_runner.is_running() and not event_runner.has_error() and guard < 20000:
		guard += 1
		if event_runner.is_waiting_battle():
			return {"ok": true, "paused": "battle"}
		if event_runner.is_waiting_line():
			event_runner.advance_line()
		else:
			event_runner.tick(0.05)
			_apply_event_presentation()
	if glue != null and glue.player != null:
		glue.player.input_enabled = true
	var result: Dictionary = {"ok": not event_runner.has_error(), "finished": event_runner.is_finished(), "error": event_runner.error_text()}
	event_finished.emit(result)
	return result


## Apply the runner's presentation data to the real nodes:
## fade level -> the fade ColorRect, camera state -> the
## host Camera2D (target actor's node position + offset,
## zoom). The events prep owns the data; this is the host
## binding it deliberately left to build 6.
func _apply_event_presentation() -> void:
	if event_runner == null:
		return
	if _fade_rect != null:
		_fade_rect.color = Color(0, 0, 0, clampf(event_runner.fade_level, 0.0, 1.0))
	if camera != null:
		var cam: Dictionary = event_runner.camera_state
		camera.zoom = Vector2.ONE * float(cam.get("zoom", 1.0))
		var offset_value: Variant = cam.get("offset", Vector2.ZERO)
		if offset_value is Vector2:
			var offset: Vector2 = offset_value
			camera.offset = offset
		var target: String = str(cam.get("target", "player"))
		if target != "player" and _event_actors.has(target):
			var rig: PUWEventActor = _event_actors[target]
			if rig.node != null:
				camera.global_position = rig.node.global_position + camera.offset


## A wild battle on an explicit habitat area (the real map
## scenes pass their own area id, the B7 pattern): roll ->
## difficulty-layer build -> hand-off guard -> launch. No
## eligible roll means no battle, never a placeholder one.
func start_wild_battle(area_id: String, max_rolls: int = 60) -> Dictionary:
	if glue == null or glue.habitat == null or glue.entry == null:
		return {"ok": false, "reason": "host_not_booted"}
	var player_max: int = PUWBattleEntry.player_max_level(party)
	for attempt in range(max_rolls):
		var roll: Dictionary = glue.habitat.roll_habitat_encounter(area_id, player_max, rng)
		if roll.is_empty():
			continue
		var wild: Dictionary = glue.entry.build_habitat_wild_mon(roll, player_max, rng)
		if wild.is_empty():
			continue
		var level_rule: Dictionary = {"min": player_max + 1, "max": mini(player_max + 3, 100)}
		var verdict: Dictionary = PUWBattleEntry.hand_off([wild], 1, level_rule)
		if not bool(verdict.get("ok", false)):
			return {"ok": false, "reason": "hand_off_refused", "verdict": verdict}
		return launch_battle("wild", [wild], {}, {})
	return {"ok": false, "reason": "no_encounter"}


## The trainer alert/approach finished: the trainer now
## stands adjacent, facing the player, with its node
## metadata updated — so the EXISTING trigger scan
## re-detects it through check_sight and starts the
## battle through the normal hand-off. Nothing is built
## or launched here that scan_trainer_trigger would not
## have produced on its own.
func _on_trainer_alert_finished(_trainer_node: Node2D) -> void:
	if glue == null:
		return
	var trigger: Dictionary = glue.scan_trainer_trigger()
	if not trigger.is_empty():
		start_trainer_battle(trigger)


## A trainer battle from the glue's trigger scan result.
func start_trainer_battle(trigger: Dictionary) -> Dictionary:
	var team_value: Variant = trigger.get("enemy_party", [])
	var team: Array = team_value if team_value is Array else []
	var verdict_value: Variant = trigger.get("verdict", {})
	var verdict: Dictionary = verdict_value if verdict_value is Dictionary else {}
	if team.is_empty() or not bool(verdict.get("ok", false)):
		return {"ok": false, "reason": "trigger_refused", "verdict": verdict}
	var trainer_value: Variant = trigger.get("trainer", {})
	var trainer: Dictionary = trainer_value if trainer_value is Dictionary else {}
	return launch_battle("trainer", team, trainer, {})


## The one launch path every battle takes. Sets the statics
## the bound battle scene reads -- pending parties, campaign
## region, pending_battle_context ({} = ordinary battle:
## permadeath counts, the gimmick gate reads the save's
## progression flags, the badge feeder supplies the level
## cap) -- and records the full handoff for the VS intro.
func launch_battle(kind: String, enemy_party: Array, trainer: Dictionary, context: Dictionary) -> Dictionary:
	pending_handoff = {
		"kind": kind,
		"enemy_party": enemy_party,
		"player_party": party,
		"trainer": trainer,
		"context": context,
	}
	BattleScene.pending_player_party = party
	BattleScene.pending_enemy_party = enemy_party
	BattleScene.pending_campaign_region_id = PUWRegionState.active_region(state)
	BattleScene.pending_battle_context = context
	battle_requested.emit(pending_handoff)
	return {"ok": true, "handoff": pending_handoff}


## After BattleScene returns: the permadeath bridge (F2) has
## already written survivors / locked families / the fainting
## ledger back to the shared channels; re-read them, rebind
## the field context, and re-select followers from the
## surviving party.
func apply_battle_return() -> Dictionary:
	var channel_state: Dictionary = BagScene.save_state
	if not channel_state.is_empty():
		state = channel_state
	party = PartyScene.party
	if glue != null:
		glue.refresh_field_context(state, party)
		if glue.followers != null and not party.is_empty():
			glue.followers.select_followers(party, [0])
			_build_follower_views()
	var ledger_value: Variant = state.get("fainting_ledger", [])
	var ledger: Array = ledger_value if ledger_value is Array else []
	return {"ok": true, "party_size": party.size(), "fainting_ledger_size": ledger.size()}


# -----------------------------------------------------------------
# A-52 Sevii access host contract (sevii_ferry_wiring.json is
# the spec): transient ferry flags derive from the real bag at
# interact time; the destination menu is presented by the
# story lane from the ferry_menu hand-off and answers through
# run_ferry. MeetCelio fires on map entry; the Marowak beat
# fires on its trigger tile and gates the 6F->7F stair warp.
# -----------------------------------------------------------------

func _flags() -> Dictionary:
	var value: Variant = state.get("story_flags", {})
	return value if value is Dictionary else {}


## build6_remainders (remainder 5): consume this host's own
## story hand-offs for the two pick beats. Other kinds keep
## flowing to any external listener untouched — this handler
## only ADDS the pick-UI routing build 6 left unbuilt.
func _on_story_handoff(kind: String, payload: Dictionary) -> void:
	if menu_host == null:
		return
	match kind:
		"fossil_pick":
			menu_host.open_fossil_pick()
		"ferry_menu":
			menu_host.open_ferry_menu(payload)


## build6_remainders (remainder 5): the elevator panel's
## answer — warp to the chosen floor, spawning at that
## floor's elevator-door warp (change_map's 1-based warp_id).
func _on_floor_chosen(map_name: String, warp_id: int) -> void:
	change_map(map_name, warp_id)


## The bg_event record at a tile on a map ({} if none) — the
## _object_at twin for signs / panels.
func _bg_event_at(map_name: String, tile: Vector2i) -> Dictionary:
	if glue == null or glue.map_loader == null:
		return {}
	var data: Dictionary = glue.map_loader.map_data_for(map_name)
	var bg_value: Variant = data.get("bg_events", [])
	if not (bg_value is Array):
		return {}
	for bg_item in bg_value:
		if bg_item is Dictionary:
			var bg: Dictionary = bg_item
			if int(bg.get("x", -1)) == tile.x and int(bg.get("y", -1)) == tile.y:
				return bg
	return {}


## The elevator_floors.json building whose elevator_map is
## this map ({} if none / file missing). Read per call: the
## file is tiny and this runs on a panel interact only.
func _elevator_building_for(map_name: String) -> Dictionary:
	var path: String = "res://data/elevator_floors.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var buildings_value: Variant = (parsed as Dictionary).get("buildings", [])
	if not (buildings_value is Array):
		return {}
	for building_value in buildings_value:
		if building_value is Dictionary:
			var building: Dictionary = building_value
			if str(building.get("elevator_map", "")) == map_name:
				return building
	return {}


## The placed object record at a tile on a map ({} if none).
func _object_at(map_name: String, tile: Vector2i) -> Dictionary:
	if glue == null or glue.map_loader == null:
		return {}
	var data: Dictionary = glue.map_loader.map_data_for(map_name)
	var objects_value: Variant = data.get("objects", [])
	if not (objects_value is Array):
		return {}
	for object_value in objects_value:
		if object_value is Dictionary:
			var object: Dictionary = object_value
			if int(object.get("x", -1)) == tile.x and int(object.get("y", -1)) == tile.y:
				return object
	return {}


## Derive the ferry transient flags from the real bag (the
## wiring record's host contract) and return the menu options:
## the tier the flags select + its destination set for this
## origin, read from the wiring record's destination matrix.
func ferry_options(origin: String) -> Dictionary:
	var flags: Dictionary = _flags()
	var holds = func(slug: String) -> bool:
		return PUWLiveBag.count_in_state(state, slug) > 0
	flags["ferry_tri_pass"] = holds.call("tri-pass")
	flags["ferry_rainbow_pass"] = holds.call("rainbow-pass")
	flags["ferry_mystic_ticket"] = holds.call("mysticticket") \
		and not bool(flags.get("shown_mystic_ticket", false))
	flags["ferry_aurora_ticket"] = holds.call("auroraticket") \
		and not bool(flags.get("shown_aurora_ticket", false))
	flags["ferry_any_ticket"] = holds.call("mysticticket") or holds.call("auroraticket")
	state["story_flags"] = flags
	var tier: String = "rainbow_pass" if flags["ferry_rainbow_pass"] else "tri_pass"
	var destinations: Array = []
	var wiring_path: String = "res://data/sevii_ferry_wiring.json"
	if FileAccess.file_exists(wiring_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(wiring_path))
		if parsed is Dictionary:
			var matrix_value: Variant = (parsed as Dictionary).get("destination_matrix", {})
			if matrix_value is Dictionary:
				var origin_value: Variant = (matrix_value as Dictionary).get(origin, {})
				if origin_value is Dictionary:
					var dest_value: Variant = (origin_value as Dictionary).get(tier, [])
					if dest_value is Array:
						destinations = dest_value
	return {"origin": origin, "tier": tier, "destinations": destinations}


## The Seagallop number for a route (pokefirered
## src/seagallop.c GetSeagallopNumber, per the wiring record).
func _seagallop_number(origin: String, dest: String) -> int:
	var pair: Array = [origin, dest]
	if pair.has("cinnabar"):
		return 1
	if pair.has("vermilion"):
		return 7
	if pair.has("navel_rock"):
		return 10
	if pair.has("birth_island"):
		return 12
	var tri: Array = ["one_island", "two_island", "three_island"]
	if tri.has(origin) and tri.has(dest):
		return 2
	if (origin == "four_island" and dest == "five_island") \
			or (origin == "five_island" and dest == "four_island"):
		return 3
	if (origin == "six_island" and dest == "seven_island") \
			or (origin == "seven_island" and dest == "six_island"):
		return 5
	return 6


## The menu's answer: set the ONE ferry_dest_* flag and run
## the origin's ferry script with {STR_VAR_1} = the route's
## Seagallop number as a runner substitution.
func run_ferry(origin: String, dest: String) -> Dictionary:
	var flags: Dictionary = _flags()
	var stale: Array = []
	for key_value in flags.keys():
		if str(key_value).begins_with("ferry_dest_"):
			stale.append(key_value)
	for key in stale:
		flags.erase(key)
	flags["ferry_dest_" + dest] = true
	state["story_flags"] = flags
	var script: Dictionary = PUWEventRunner.load_script_file(
		"res://data/events/sevii_ferry_" + origin + ".json")
	if script.is_empty():
		return {"ok": false, "reason": "ferry_script_missing", "origin": origin}
	return start_event(script, _cast_for_script(script),
		{"STR_VAR_1": str(_seagallop_number(origin, dest))})


## Map-entry beats: MeetCelio on first entry to One Island's
## Pokemon Center after Bill sailed (the script's own
## requires + once_flag carry the exact gating).
func _check_entry_triggers() -> void:
	if current_map != "OneIsland_PokemonCenter_1F":
		return
	if event_runner != null and event_runner.is_running():
		return
	var script: Dictionary = PUWEventRunner.load_script_file(
		"res://data/events/sevii_meet_celio.json")
	if not script.is_empty():
		start_event(script, _cast_for_script(script))


## Tile beats: the Marowak ghost on PokemonTower6F (20, 32) —
## set ghost_unidentified from the item gate, then run the
## beat (its requires forbid re-runs once calmed).
func _check_tile_triggers() -> void:
	if current_map != "PokemonTower6F" or glue == null or glue.player == null:
		return
	if event_runner != null and event_runner.is_running():
		return
	if glue.player.player_tile() != Vector2i(20, 32):
		return
	if bool(_flags().get("marowak_calmed", false)):
		return
	var gate: Dictionary = PUWItemGates.ghost_check(state, current_map)
	var flags: Dictionary = _flags()
	flags["ghost_unidentified"] = bool(gate.get("unidentified", false))
	state["story_flags"] = flags
	var script: Dictionary = PUWEventRunner.load_script_file(
		"res://data/events/pokemon_tower_marowak_ghost.json")
	if not script.is_empty():
		start_event(script, _cast_for_script(script))


## Warp veto (player controller seam): while the Marowak is
## unresolved it blocks the PokemonTower 6F -> 7F stair warp,
## exactly as in the source.
func _warp_veto(warp: Dictionary, dest_map_name: String) -> bool:
	if current_map != "PokemonTower6F" or dest_map_name != "PokemonTower7F":
		return true
	for record_value in PUWFixedEncounters.records():
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if str(record.get("map", "")) == "PokemonTower6F":
			return not PUWFixedEncounters.is_available(state, record)
	return true


## Move the host to another map (warp hook, escape rope):
## tear the glue down and boot again on the same state +
## party, placing the player at the destination warp's spawn
## tile when the loader knows it.
func change_map(map_name: String, warp_id: int = -1) -> Dictionary:
	if map_name == "":
		return {"ok": false, "reason": "no_map"}
	# A-50: fixed-encounter access gates guard their map's
	# entrance (Cerulean Cave: the champion flag, per the
	# record's access_gate) — refuse the warp, do not move.
	if not state.is_empty():
		for record_value in PUWFixedEncounters.records():
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			if str(record.get("map", "")) != map_name:
				continue
			if record.has("access_gate") and not PUWFixedEncounters.access_allowed(state, record):
				return {"ok": false, "reason": "fixed_encounter_access",
					"encounter": str(record.get("id", "")), "map": map_name}
	if glue != null:
		glue.queue_free()
		glue = null
	npc_views.clear()
	follower_views.clear()
	var report: Dictionary = boot(state, party, map_name, cast_id)
	if bool(report.get("ok", false)) and warp_id >= 0 and glue != null and glue.map_loader != null:
		var spawn_tile: Vector2i = glue.map_loader.spawn_tile_for(current_map, warp_id)
		if spawn_tile.x >= 0:
			glue.player.place_at_tile(spawn_tile)
	warp_performed.emit(current_map, warp_id)
	return report
