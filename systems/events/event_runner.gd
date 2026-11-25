class_name PUWEventRunner
extends RefCounted
## Data-driven event / cutscene runner: interprets an event
## script (plain data, usually loaded from res://data/events/
## <id>.json) as a sequence of steps -- move an actor, face,
## say a line, give an item, start a battle, set a flag, warp --
## against the real game machinery:
##
##   story state + flags .. the save state's story_flags, read
##                          and written in PUWCampaignStitch's
##                          own style; campaign beats delegate
##                          to PUWCampaignStitch itself (the
##                          "campaign" op's whitelist), never
##                          re-implemented here.
##   dialogue ............. PUWSpawner.dialogue_for over
##                          data/dialogue_database.json (the
##                          sourced pokered/HGSS text); a "say"
##                          step names a map + a text_id or an
##                          exact entry label, never a retyped
##                          line (inline "text" exists for
##                          authored PUW lines only).
##   battles .............. PUWBattleEntry (the B5 scripted
##                          door and its siblings) + the
##                          hand_off guard. A battle step
##                          supplies IDENTITY only; an
##                          unbuildable battle halts the event
##                          with an error, never a raw party.
##   actors ............... PUWEventActor rigs registered by
##                          the host scene.
##
## Why this exists: before this file the project had the story
## state machine (PUWCampaignStitch), trigger predicates
## (CampaignFlow.should_trigger), dialogue data + lookup, and
## the scripted-battle door -- but NO interpreter that could
## sequence them into a played scene, no actor movement, no
## camera control, no screen fade, and no dialogue
## presentation. This runner is that interpreter.
##
## Execution model (deterministic, headless-provable -- the
## PUWPlayerController.step contract): instant steps run
## immediately; timed steps (move / wait / fade / camera)
## advance through tick(delta), which the host calls from
## _process in game and a test calls with fixed deltas. Two
## steps PAUSE the runner for the host: "say" (the host's
## textbox holds the line until advance_line()) and "battle"
## (the host runs the battle scene, then resolve_battle()).
##
## Host contract (configure):
##   state ......... the save state Dictionary (stitch shape).
##   actors ........ {actor_id: PUWEventActor}; "player" is
##                   the conventional player id (camera release
##                   target).
##   hooks ......... {"present_line": Callable(speaker, text),
##                    "on_warp": Callable(map, warp_id, tile)}
##                   -- both optional; without present_line,
##                   say lines are recorded in transcript()
##                   only. Warp is terminal: the hook fires and
##                   the event completes (the scene is gone).
##   substitutions . {"<RIVAL>": name, ...} applied to say
##                   text after dialogue resolution; "<PLAYER>"
##                   defaults to state.player.name.
##   seed .......... RNG seed for battle builds (tests pin it).
##
## Script shape:
##   {"id": "oak_lab_opening", "map": "OaksLab",
##    "once_flag": "oak_lab_opening_done",
##    "start_fade": 1.0,
##    "requires": {"flags": [...], "forbidden_flags": [...],
##                 "min_badges": 0, "min_stage": "clues_seen"},
##    "steps": [ {step}, ... ]}
## Any step may carry "if_flag" / "if_not_flag" /
## "if_stage_at_least" modifiers; a step whose modifier fails
## is skipped. Ops: say, move, face, wait, fade, camera,
## set_flag, give_item, campaign, battle, label, goto,
## actor_visible, warp. See PREP_REPORT.md for the full table.

const DEFAULT_FADE_SECONDS: float = 0.3

var fade_level: float = 0.0
var camera_state: Dictionary = {"target": "player", "point": Vector2.ZERO, "zoom": 1.0, "offset": Vector2.ZERO}

var _state: Dictionary = {}
var _actors: Dictionary = {}
var _hooks: Dictionary = {}
var _substitutions: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _script: Dictionary = {}
var _steps: Array = []
var _labels: Dictionary = {}
var _pc: int = 0
var _started: bool = false
var _finished: bool = false
var _error: String = ""

var _active_kind: String = ""
var _active_actor: PUWEventActor = null
var _active_remaining: float = 0.0
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _fade_elapsed: float = 0.0
var _fade_duration: float = 0.0
var _cam_from: Dictionary = {}
var _cam_to: Dictionary = {}
var _cam_elapsed: float = 0.0
var _cam_duration: float = 0.0

var _line_queue: Array = []
var _waiting_line: bool = false
var _current_line: Dictionary = {}
var _transcript: Array = []

var _waiting_battle: bool = false
var _pending_battle: Dictionary = {}
var _battle_win_goto: String = ""
var _battle_lose_goto: String = ""

var _spawner: PUWSpawner = null
var _entry: PUWBattleEntry = null


# ----------------------------------------------------------------
# Setup
# ----------------------------------------------------------------

func configure(state: Dictionary, actors: Dictionary, hooks: Dictionary = {}, substitutions: Dictionary = {}, seed_value: int = 0) -> void:
	_state = state
	_actors = actors
	_hooks = hooks
	_substitutions = substitutions
	_rng.seed = seed_value if seed_value != 0 else 1


static func load_script_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


## Validate and load a script Dictionary. Returns {ok, error}.
func load_script(script: Dictionary) -> Dictionary:
	_script = script
	_steps = []
	_labels = {}
	var steps_v: Variant = script.get("steps", [])
	if not (steps_v is Array):
		return {"ok": false, "error": "script has no steps array"}
	_steps = steps_v
	for i in range(_steps.size()):
		var step_v: Variant = _steps[i]
		if step_v is Dictionary:
			var step: Dictionary = step_v
			if str(step.get("op", "")) == "label":
				_labels[str(step.get("id", ""))] = i
	return {"ok": true, "error": ""}


# ----------------------------------------------------------------
# Run control
# ----------------------------------------------------------------

func run() -> Dictionary:
	if _script.is_empty():
		return {"ok": false, "error": "no script loaded"}
	var flags: Dictionary = _flags()
	var once_flag: String = str(_script.get("once_flag", ""))
	if once_flag != "" and bool(flags.get(once_flag, false)):
		return {"ok": false, "error": "event already played (once_flag '" + once_flag + "' set)"}
	var requires_v: Variant = _script.get("requires", {})
	if requires_v is Dictionary:
		var requires: Dictionary = requires_v
		var trigger: Dictionary = {
			"id": str(_script.get("id", "")),
			"required_flags": requires.get("flags", []),
			"forbidden_flags": requires.get("forbidden_flags", []),
			"min_badges": int(requires.get("min_badges", 0)),
		}
		var shim: Dictionary = {"flags": flags, "badges": _state.get("badges", [])}
		if not CampaignFlow.should_trigger(shim, trigger):
			return {"ok": false, "error": "event requirements not met"}
		var min_stage: String = str(requires.get("min_stage", ""))
		if min_stage != "":
			var order: Array = PUWCampaignStitch.STAGE_ORDER
			if order.find(PUWCampaignStitch.stage(_state)) < order.find(min_stage):
				return {"ok": false, "error": "campaign stage below '" + min_stage + "'"}
	if _script.has("start_fade"):
		fade_level = clampf(float(_script.get("start_fade", 0.0)), 0.0, 1.0)
	_started = true
	_pc = 0
	_advance()
	return {"ok": true, "error": ""}


func is_running() -> bool:
	return _started and not _finished and _error == ""


func is_finished() -> bool:
	return _finished


func has_error() -> bool:
	return _error != ""


func error_text() -> String:
	return _error


func current_step_index() -> int:
	return _pc


func is_waiting_line() -> bool:
	return _waiting_line


func is_waiting_battle() -> bool:
	return _waiting_battle


func pending_battle() -> Dictionary:
	return _pending_battle


func transcript() -> Array:
	return _transcript.duplicate(true)


## Host confirms the current say line (textbox advance).
func advance_line() -> void:
	if not _waiting_line:
		return
	_waiting_line = false
	_current_line = {}
	if not _line_queue.is_empty():
		_present_next_line()
		return
	_advance()


## Host reports the battle's outcome; the script continues at
## the win/lose label when the battle step named one.
func resolve_battle(won: bool) -> void:
	if not _waiting_battle:
		return
	_waiting_battle = false
	_pending_battle = {}
	var target: String = _battle_win_goto if won else _battle_lose_goto
	_battle_win_goto = ""
	_battle_lose_goto = ""
	if target != "" and _labels.has(target):
		_pc = int(_labels[target])
	_advance()


## Advance timed steps. Host calls from _process in game;
## tests call with fixed deltas.
func tick(delta: float) -> void:
	if not is_running():
		return
	match _active_kind:
		"move":
			if _active_actor == null or not _active_actor.is_moving():
				_clear_active()
				_advance()
			else:
				_active_actor.tick(delta)
				if not _active_actor.is_moving():
					_clear_active()
					_advance()
		"wait":
			_active_remaining -= delta
			if _active_remaining <= 0.0:
				_clear_active()
				_advance()
		"fade":
			_fade_elapsed += delta
			var t: float = 1.0 if _fade_duration <= 0.0 else clampf(_fade_elapsed / _fade_duration, 0.0, 1.0)
			fade_level = lerpf(_fade_from, _fade_to, t)
			if t >= 1.0:
				_clear_active()
				_advance()
		"camera":
			_cam_elapsed += delta
			var t2: float = 1.0 if _cam_duration <= 0.0 else clampf(_cam_elapsed / _cam_duration, 0.0, 1.0)
			camera_state["zoom"] = lerpf(float(_cam_from.get("zoom", 1.0)), float(_cam_to.get("zoom", 1.0)), t2)
			var from_off: Vector2 = _cam_from.get("offset", Vector2.ZERO)
			var to_off: Vector2 = _cam_to.get("offset", Vector2.ZERO)
			camera_state["offset"] = from_off.lerp(to_off, t2)
			if t2 >= 1.0:
				_clear_active()
				_advance()


# ----------------------------------------------------------------
# Step machine
# ----------------------------------------------------------------

func _advance() -> void:
	while _pc < _steps.size():
		if _error != "" or _waiting_line or _waiting_battle or _active_kind != "":
			return
		var step_v: Variant = _steps[_pc]
		if not (step_v is Dictionary):
			_pc += 1
			continue
		var step: Dictionary = step_v
		if not _step_allowed(step):
			_pc += 1
			continue
		var op: String = str(step.get("op", ""))
		match op:
			"label":
				_pc += 1
			"goto":
				var label: String = str(step.get("label", ""))
				if not _labels.has(label):
					_fail("goto names unknown label '" + label + "'")
					return
				_pc = int(_labels[label])
			"set_flag":
				_set_flag(str(step.get("flag", "")), step.get("value", true))
				_pc += 1
			"give_item":
				_give_item(str(step.get("item", "")), int(step.get("count", 1)))
				_pc += 1
			"face":
				_do_face(step)
				_pc += 1
			"actor_visible":
				var rig: PUWEventActor = _actor(str(step.get("actor", "")))
				if rig != null:
					rig.set_visible(bool(step.get("visible", true)))
				_pc += 1
			"campaign":
				_pc += 1
				if not _do_campaign(step):
					return
			"say":
				_pc += 1
				_do_say(step)
				return
			"move":
				_pc += 1
				if _do_move(step):
					return
			"wait":
				_pc += 1
				_active_kind = "wait"
				_active_remaining = float(step.get("seconds", 0.0))
				if _active_remaining <= 0.0:
					_clear_active()
					continue
				return
			"fade":
				_pc += 1
				if _do_fade(step):
					return
			"camera":
				_pc += 1
				if _do_camera(step):
					return
			"battle":
				_pc += 1
				_do_battle(step)
				return
			"warp":
				_pc += 1
				_do_warp(step)
				_complete()
				return
			_:
				_fail("unknown op '" + op + "' at step " + str(_pc))
				return
	_complete()


func _complete() -> void:
	if _error != "":
		return
	var once_flag: String = str(_script.get("once_flag", ""))
	if once_flag != "":
		_set_flag(once_flag, true)
	_finished = true


func _fail(message: String) -> void:
	_error = message
	_clear_active()
	_waiting_line = false
	_waiting_battle = false


func _clear_active() -> void:
	_active_kind = ""
	_active_actor = null
	_active_remaining = 0.0


func _step_allowed(step: Dictionary) -> bool:
	var flags: Dictionary = _flags()
	if step.has("if_flag") and not bool(flags.get(str(step.get("if_flag", "")), false)):
		return false
	if step.has("if_not_flag") and bool(flags.get(str(step.get("if_not_flag", "")), false)):
		return false
	if step.has("if_stage_at_least"):
		var order: Array = PUWCampaignStitch.STAGE_ORDER
		if order.find(PUWCampaignStitch.stage(_state)) < order.find(str(step.get("if_stage_at_least", ""))):
			return false
	return true


# ----------------------------------------------------------------
# Ops
# ----------------------------------------------------------------

func _do_say(step: Dictionary) -> void:
	var speaker: String = str(step.get("speaker", ""))
	var lines: Array = []
	if step.has("text"):
		lines = [str(step.get("text", ""))]
	elif step.has("dialogue"):
		var d_v: Variant = step.get("dialogue", {})
		if d_v is Dictionary:
			var d: Dictionary = d_v
			lines = _spawner_instance().dialogue_for(str(d.get("map", "")), str(d.get("ref", "")))
	if lines.is_empty():
		_fail("say step resolved no dialogue (speaker '" + speaker + "')")
		return
	for line_v in lines:
		_line_queue.append({"speaker": speaker, "text": _substitute(str(line_v))})
	_present_next_line()


func _present_next_line() -> void:
	if _line_queue.is_empty():
		return
	var line: Dictionary = _line_queue[0]
	_line_queue.remove_at(0)
	_current_line = line
	_transcript.append(line.duplicate(true))
	_waiting_line = true
	var hook_v: Variant = _hooks.get("present_line", Callable())
	if hook_v is Callable:
		var hook: Callable = hook_v
		if hook.is_valid():
			hook.call(str(line.get("speaker", "")), str(line.get("text", "")))


func _do_move(step: Dictionary) -> bool:
	var rig: PUWEventActor = _actor(str(step.get("actor", "")))
	if rig == null:
		_fail("move step names unknown actor '" + str(step.get("actor", "")) + "'")
		return false
	if step.has("to"):
		rig.queue_move_to(_vec2i(step.get("to", [])))
	elif step.has("path"):
		var path_v: Variant = step.get("path", [])
		if path_v is Array:
			rig.queue_path(path_v)
	elif step.has("dir"):
		rig.queue_step(str(step.get("dir", "")), int(step.get("tiles", 1)))
	if step.has("speed"):
		rig.speed_tiles_per_sec = float(step.get("speed", rig.speed_tiles_per_sec))
	if not rig.is_moving():
		return false
	_active_kind = "move"
	_active_actor = rig
	return true


func _do_face(step: Dictionary) -> void:
	var rig: PUWEventActor = _actor(str(step.get("actor", "")))
	if rig == null:
		return
	if step.has("toward"):
		var other: PUWEventActor = _actor(str(step.get("toward", "")))
		if other != null:
			rig.face_toward(other.tile)
	elif step.has("dir"):
		rig.face(str(step.get("dir", "")))


func _do_fade(step: Dictionary) -> bool:
	_fade_from = fade_level
	_fade_to = clampf(float(step.get("to", 0.0)), 0.0, 1.0)
	_fade_duration = float(step.get("seconds", DEFAULT_FADE_SECONDS))
	_fade_elapsed = 0.0
	if _fade_duration <= 0.0:
		fade_level = _fade_to
		return false
	_active_kind = "fade"
	return true


func _do_camera(step: Dictionary) -> bool:
	if bool(step.get("release", false)):
		camera_state["target"] = "player"
	elif step.has("target"):
		camera_state["target"] = str(step.get("target", "player"))
	elif step.has("point"):
		camera_state["target"] = ""
		camera_state["point"] = _vec2(step.get("point", []))
	_cam_from = {"zoom": float(camera_state.get("zoom", 1.0)), "offset": camera_state.get("offset", Vector2.ZERO)}
	_cam_to = {
		"zoom": float(step.get("zoom", float(camera_state.get("zoom", 1.0)))),
		"offset": _vec2(step.get("offset", [])) if step.has("offset") else camera_state.get("offset", Vector2.ZERO),
	}
	_cam_duration = float(step.get("seconds", 0.0))
	_cam_elapsed = 0.0
	if _cam_duration <= 0.0:
		camera_state["zoom"] = float(_cam_to["zoom"])
		camera_state["offset"] = _cam_to["offset"]
		return false
	_active_kind = "camera"
	return true


func _do_battle(step: Dictionary) -> void:
	var entry: PUWBattleEntry = _entry_instance()
	var player_max: int = PUWBattleEntry.player_max_level(_state.get("party", []))
	var kind: String = str(step.get("entry", "scripted"))
	var result: Dictionary = {}
	match kind:
		"scripted":
			var identity_v: Variant = step.get("identity", [])
			var identity: Array = identity_v if identity_v is Array else []
			result = entry.start_scripted_battle(identity, player_max, "singles", _rng, "")
		"rival":
			result = entry.start_rival_battle(str(step.get("stage_key", "")), int(step.get("party_index", 1)), player_max, "singles", _rng, "")
		"roster":
			result = entry.start_roster_battle(str(step.get("roster_id", "")), player_max, "singles")
		"gym":
			var gate: Dictionary = {}
			if bool(step.get("use_campaign_gate", false)):
				gate = PUWCampaignStitch.can_start_gym_battle(_state, str(step.get("gym_ref", "")))
			result = entry.start_gym_battle(str(step.get("gym_ref", "")), int(step.get("badge_count", 0)), "singles", gate)
		_:
			_fail("battle step names unknown entry '" + kind + "'")
			return
	if not bool(result.get("ok", false)):
		_fail("battle refused: " + str(result.get("error", "no buildable identity")))
		return
	var team_v: Variant = result.get("enemy_party", [])
	var team: Array = team_v if team_v is Array else []
	var verdict: Dictionary = PUWBattleEntry.hand_off(team, 0, {})
	if not bool(verdict.get("ok", false)):
		_fail("battle hand-off refused: " + str(verdict.get("problems", [])))
		return
	_pending_battle = result
	_battle_win_goto = str(step.get("win_goto", ""))
	_battle_lose_goto = str(step.get("lose_goto", ""))
	_waiting_battle = true


func _do_campaign(step: Dictionary) -> bool:
	var action: String = str(step.get("action", ""))
	var ok: bool = false
	match action:
		"complete_setup":
			ok = PUWCampaignStitch.complete_setup(_state)
		"record_spawn":
			ok = not PUWCampaignStitch.record_spawn(_state).is_empty()
		"record_clues_seen":
			ok = not PUWCampaignStitch.record_clues_seen(_state).is_empty()
		"grant_oak_picks":
			var p1_v: Variant = step.get("pick_1", {})
			var p2_v: Variant = step.get("pick_2", {})
			var p1: Dictionary = p1_v if p1_v is Dictionary else {}
			var p2: Dictionary = p2_v if p2_v is Dictionary else {}
			ok = not PUWCampaignStitch.grant_oak_picks(_state, p1, p2).is_empty()
		"record_rival_fight":
			ok = PUWCampaignStitch.record_rival_fight(_state, str(step.get("rival_id", "")))
		_:
			_fail("campaign step names unknown action '" + action + "'")
			return false
	if not ok:
		_fail("campaign action refused: " + action)
		return false
	return true


func _do_warp(step: Dictionary) -> void:
	var hook_v: Variant = _hooks.get("on_warp", Callable())
	if hook_v is Callable:
		var hook: Callable = hook_v
		if hook.is_valid():
			hook.call(str(step.get("map", "")), int(step.get("warp", 0)), _vec2i(step.get("to", [])))


# ----------------------------------------------------------------
# State helpers (PUWCampaignStitch's flag/bag style)
# ----------------------------------------------------------------

func _flags() -> Dictionary:
	var flags_v: Variant = _state.get("story_flags", {})
	if flags_v is Dictionary:
		var flags: Dictionary = flags_v
		return flags
	return {}


func _set_flag(flag: String, value: Variant) -> void:
	if flag == "":
		return
	var flags: Dictionary = _flags()
	flags[flag] = value
	_state["story_flags"] = flags


func _give_item(item_id: String, count: int) -> void:
	if item_id == "" or count == 0:
		return
	var bag_v: Variant = _state.get("bag", {})
	var bag: Dictionary = bag_v if bag_v is Dictionary else {}
	bag[item_id] = int(bag.get(item_id, 0)) + count
	_state["bag"] = bag


func _substitute(text: String) -> String:
	var out: String = text
	var player_name: String = ""
	var player_v: Variant = _state.get("player", {})
	if player_v is Dictionary:
		player_name = str((player_v as Dictionary).get("name", ""))
	if _substitutions.has("<PLAYER>"):
		player_name = str(_substitutions["<PLAYER>"])
	if player_name != "":
		out = out.replace("<PLAYER>", player_name)
	for key_v in _substitutions.keys():
		var key: String = str(key_v)
		if key != "<PLAYER>":
			out = out.replace(key, str(_substitutions[key_v]))
	return out


func _actor(actor_id: String) -> PUWEventActor:
	var rig_v: Variant = _actors.get(actor_id, null)
	if rig_v is PUWEventActor:
		return rig_v
	return null


func _spawner_instance() -> PUWSpawner:
	if _spawner == null:
		_spawner = PUWSpawner.new()
	return _spawner


func _entry_instance() -> PUWBattleEntry:
	if _entry == null:
		_entry = PUWBattleEntry.new()
	return _entry


func _vec2i(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Array:
		var a: Array = v
		if a.size() == 2:
			return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO


func _vec2(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array:
		var a: Array = v
		if a.size() == 2:
			return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO
