extends SceneTree
## Field-action CONTROLLER tests (Worker B, job (b)).
## Run: godot --headless --script res://tests/field_action_controller_tests.gd
##
## This is a NEW suite (documented choice): the standalone
## tests/field_action_tests.gd is left untouched at its
## 58 passed / 0 failed baseline. What is proven here is the
## wiring through the REAL PUWPlayerController path:
## - PUWPlayerController.set_field_context(state, party) binds
##   the gate context; movement over synthetic "water" / "gap"
##   terrain and attempt_field_action() both consult
##   PUWFieldActions (can_perform for crossings, perform for
##   interactions) -- the controller never reimplements it.
## (1) no badge + capable Pokemon -> refused with
##     last_block_reason "badge_missing", no crossing/action;
## (2) badge + capable Pokemon -> allowed (crossing happens,
##     interaction is recorded by perform);
## (3) badge + no capable Pokemon -> refused with
##     "no_qualifying_pokemon", nothing recorded.
## Synthetic maps follow the ride_system_tests pattern.

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


func _setup_world() -> void:
	_loader = PUWMapLoader.new()
	root.add_child(_loader)
	_player = PUWPlayerController.new()
	_player.input_enabled = false
	root.add_child(_player)
	_player.setup(_loader)


func _step_many(dir: Vector2, mode: String, count: int) -> void:
	for i: int in range(count):
		_player.step(0.05, dir, mode)


# Party entry in the campaign stitch's shape (as in
# field_action_tests): slug in "name", moves as {"name": id}.
func _mon(slug: String, move_ids: Array) -> Dictionary:
	var moves: Array = []
	for move_value: Variant in move_ids:
		moves.append({"name": str(move_value), "pp": 10, "max_pp": 10})
	return {"species_id": 0, "name": slug, "level": 20, "moves": moves}


func _state_with_badge(gym_id: String) -> Dictionary:
	var state: Dictionary = {"badges": [], "story_flags": {}, "bag": {}}
	if gym_id != "":
		GymProgression.award_badge(state, gym_id)
	return state


func _used_actions(state: Dictionary) -> Array:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		var used_value: Variant = flags.get("field_actions_used", [])
		if used_value is Array:
			var used: Array = used_value
			return used
	return []


func _run() -> void:
	print("PUW field-action controller tests - starting.")
	_setup_world()
	var lapras_party: Array = [_mon("lapras", ["surf"])]
	var bulbasaur_party: Array = [_mon("bulbasaur", ["tackle", "growl"])]
	var water_terrain: Dictionary = {Vector2i(5, 2): "water", Vector2i(6, 2): "water"}

	# --- (1) Water crossing: no badge + capable -> badge_missing
	var no_badge_state: Dictionary = _state_with_badge("")
	_loader.setup_synthetic_map(11, 5, water_terrain)
	_player.set_field_context(no_badge_state, lapras_party)
	_check("controller_ctx_mount_lapras_surf", _player.mount_pokemon("lapras", "surfing"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_water_no_badge_refused_badge_missing",
		_player.player_tile().x <= 4 and _player.last_block_reason == "badge_missing",
		"tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_check("controller_water_no_badge_gate_result_recorded",
		str(_player.last_field_action_result.get("reason", "")) == "badge_missing" and _player.last_field_action == "surf",
		str(_player.last_field_action_result))
	_player.dismount_pokemon()

	# --- (2) Water crossing: Soul Badge + capable -> allowed
	var soul_state: Dictionary = _state_with_badge("kanto_gym_5_koga")
	_loader.setup_synthetic_map(11, 5, water_terrain)
	_player.set_field_context(soul_state, lapras_party)
	_check("controller_ctx_remount_lapras_surf", _player.mount_pokemon("lapras", "surfing"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_water_with_badge_crossed", _player.player_tile().x >= 7,
		"tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_player.dismount_pokemon()

	# --- (1b) Gap crossing: no badge + capable -> badge_missing
	# Gastly qualifies for fly naturally (Levitate, registry) and
	# is eligible for hover_carrying (ride_system_tests).
	var gastly_party: Array = [{"species": "gastly"}]
	var gap_terrain: Dictionary = {Vector2i(5, 2): "gap"}
	var no_thunder_state: Dictionary = _state_with_badge("")
	_loader.setup_synthetic_map(11, 5, gap_terrain)
	_player.set_field_context(no_thunder_state, gastly_party)
	_check("controller_ctx_mount_gastly_hover", _player.mount_pokemon("gastly", "hover_carrying"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_gap_no_badge_refused_badge_missing",
		_player.player_tile().x <= 4 and _player.last_block_reason == "badge_missing",
		"tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_player.dismount_pokemon()

	# --- (2b) Gap crossing: Thunder Badge + capable -> allowed
	var thunder_state: Dictionary = _state_with_badge("kanto_gym_3_surge")
	_loader.setup_synthetic_map(11, 5, gap_terrain)
	_player.set_field_context(thunder_state, gastly_party)
	_check("controller_ctx_remount_gastly_hover", _player.mount_pokemon("gastly", "hover_carrying"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_gap_with_badge_crossed", _player.player_tile().x >= 6,
		"tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_player.dismount_pokemon()

	# --- (1c) Interaction: no badge + capable -> badge_missing
	var cut_party: Array = [_mon("sandslash", ["cut"])]
	var cut_no_badge_state: Dictionary = _state_with_badge("")
	_player.set_field_context(cut_no_badge_state, cut_party)
	var cut_refused: Dictionary = _player.attempt_field_action("cut")
	_check("controller_cut_no_badge_refused_badge_missing",
		not bool(cut_refused.get("allowed", true)) and str(cut_refused.get("reason", "")) == "badge_missing"
		and _player.last_block_reason == "badge_missing", str(cut_refused))
	_check("controller_cut_no_badge_records_nothing", _used_actions(cut_no_badge_state).is_empty())

	# --- (2c) Interaction: Cascade Badge + capable -> allowed
	var cut_badge_state: Dictionary = _state_with_badge("kanto_gym_2_misty")
	_player.set_field_context(cut_badge_state, cut_party)
	var cut_allowed: Dictionary = _player.attempt_field_action("cut")
	_check("controller_cut_with_badge_allowed",
		bool(cut_allowed.get("allowed", false)) and str(cut_allowed.get("reason", "")) == "ok", str(cut_allowed))
	_check("controller_cut_with_badge_recorded_by_perform", _used_actions(cut_badge_state) == ["cut"],
		str(_used_actions(cut_badge_state)))

	# --- (3) Badge + no capable Pokemon -> no_qualifying_pokemon
	var surf_badge_state: Dictionary = _state_with_badge("kanto_gym_5_koga")
	_player.set_field_context(surf_badge_state, bulbasaur_party)
	var surf_refused: Dictionary = _player.attempt_field_action("surf")
	_check("controller_surf_badge_no_capable_refused",
		not bool(surf_refused.get("allowed", true)) and str(surf_refused.get("reason", "")) == "no_qualifying_pokemon"
		and _player.last_block_reason == "no_qualifying_pokemon", str(surf_refused))
	_check("controller_surf_badge_no_capable_records_nothing", _used_actions(surf_badge_state).is_empty())

	# (3b) Same refusal through the movement path: badge held,
	# gate party has no surf-capable Pokemon, so the water step
	# is refused for capability even though a mount is present.
	_loader.setup_synthetic_map(11, 5, water_terrain)
	_player.set_field_context(surf_badge_state, bulbasaur_party)
	_check("controller_ctx_mount_for_capability_case", _player.mount_pokemon("lapras", "surfing"))
	_player.place_at_tile(Vector2i(3, 2))
	_step_many(Vector2(1, 0), "walk", 30)
	_check("controller_water_badge_no_capable_refused",
		_player.player_tile().x <= 4 and _player.last_block_reason == "no_qualifying_pokemon",
		"tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_player.dismount_pokemon()
	_player.clear_field_context()
	_check("controller_clear_context", not _player.field_context_set)

	_finish()
