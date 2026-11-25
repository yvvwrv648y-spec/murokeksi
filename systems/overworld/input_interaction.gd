class_name PUWInputInteraction
extends RefCounted
## Field input glue (code_prep_input_menus; the field variant at
## the end is code_prep_kanto_item_fixes — everything above it is
## the input_menus file verbatim). The bound tree had NO
## input path from a button press to talking to someone:
## PUWSpawner.check_interaction() is a pure predicate whose only
## callers were its own unit tests, and PUWPlayerController reads
## only the movement vector. This class is the missing seam the
## host scene calls once per physics/input step:
##
##   var hit: Dictionary = PUWInputInteraction.try_interact(
##       spawner, controller.player_tile(), facing_vec)
##
## It is written against the spawner's REAL API
## (get_trainers_data / trainer_dict_from_placement /
## check_interaction / dialogue_for) and the canonical puw_*
## actions from patched/project.godot, falling back to the
## engine-default ui_* actions so it also works before build 6
## adopts the input map. Presentation stays with the caller: this
## class returns the lines; showing them is the dialogue/event
## host's job (their preps own the textbox seam).

## Movement from the canonical map, ui_* fallback. Returns the
## same shape PUWPlayerController.step() already consumes.
static func movement_vector() -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if InputMap.has_action("puw_left"):
		v = Input.get_vector("puw_left", "puw_right", "puw_up", "puw_down")
	else:
		v = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return v


## True when this event is the A button (confirm / talk / advance)
## in any binding: puw_confirm, ui_accept, or the raw keys the
## bound code already used (Z / Enter / Space).
static func confirm_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("puw_confirm"):
		return true
	if event.is_action_pressed("ui_accept"):
		return true
	return false


## True when this event is the B button (cancel / back).
static func cancel_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("puw_cancel"):
		return true
	if event.is_action_pressed("ui_cancel"):
		return true
	return false


## True when this event is Start (open the menu).
static func menu_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("puw_menu")


## Held-state run read for the field: Shift or pad B held. Only
## meaningful in the field — menus read the same pad button as a
## cancel PRESS, never as a hold, so the two never fight.
static func run_held() -> bool:
	if InputMap.has_action("puw_run"):
		return Input.is_action_pressed("puw_run")
	return Input.is_key_pressed(KEY_SHIFT)


## Convert the player controller's facing word to a tile vector.
static func facing_vector_for(facing: String) -> Vector2i:
	match facing:
		"up":
			return Vector2i(0, -1)
		"down":
			return Vector2i(0, 1)
		"left":
			return Vector2i(-1, 0)
		"right":
			return Vector2i(1, 0)
	return Vector2i.ZERO


## The A-button interaction itself. Looks at the tile the player
## faces, finds a placed trainer/NPC there (spawner placements),
## verifies with the spawner's own interaction predicate, and
## returns {found, trainer, lines}. lines come from
## spawner.dialogue_for(map, text_id) — real bound dialogue data,
## never authored here. An empty lines array with found=true is
## reported as-is (a placed actor whose text did not resolve is
## the dialogue prep's coverage item, not something to paper over).
static func try_interact(spawner: PUWSpawner, player_tile: Vector2i, player_facing: Vector2i) -> Dictionary:
	var miss: Dictionary = {"found": false, "trainer": {}, "lines": []}
	if spawner == null or player_facing == Vector2i.ZERO:
		return miss
	var data: Dictionary = spawner.get_trainers_data()
	var placements: Array = data.get("placements", [])
	for raw_p in placements:
		if not (raw_p is Dictionary):
			continue
		var trainer: Dictionary = PUWSpawner.trainer_dict_from_placement(raw_p as Dictionary)
		if PUWSpawner.check_interaction(trainer, player_tile, player_facing):
			var lines: Array = spawner.dialogue_for(
				str(trainer.get("map", "")), str(trainer.get("text_id", "")))
			return {"found": true, "trainer": trainer, "lines": lines}
	return miss


## The full field A-button (code_prep_kanto_item_fixes): the
## trainer/NPC interaction above first (its result gains
## kind="trainer"), then the item seam — PUWItemPickups
## classifies the faced tile's object (item ball, Pokemon ball,
## script-give marker) and falls through to hidden items under
## the source trigger rule. state is the live save state (the
## pickup grants into it and records its once-flag there);
## map_name is the host's current map. Returns the pickup
## result verbatim ({found, kind, ...}) or the trainer result,
## or the shared miss shape when nothing is faced.
static func try_interact_field(spawner: PUWSpawner, state: Dictionary, map_name: String, player_tile: Vector2i, player_facing: Vector2i) -> Dictionary:
	var hit: Dictionary = try_interact(spawner, player_tile, player_facing)
	if bool(hit.get("found", false)):
		var trainer_hit: Dictionary = hit.duplicate()
		trainer_hit["kind"] = "trainer"
		return trainer_hit
	var pickup: Dictionary = PUWItemPickups.try_pickup_at(state, map_name, player_tile, player_facing)
	if bool(pickup.get("found", false)):
		return pickup
	return {"found": false, "trainer": {}, "lines": []}
