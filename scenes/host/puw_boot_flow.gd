class_name PUWBootFlow
extends RefCounted
## Boot flow (host assembly prep, 2026-11-24).
##
## The gap this closes: PUWCampaignStitch.new_game_state --
## the only function that creates a real campaign save state
## (Omni Ring granted locked, region set, fixed protagonists'
## verified teams granted, quest boards registered) -- had NO
## scene caller. The live main scene auto-transitioned to the
## placeholder overworld, which invented a demo Pikachu. This
## class is the missing caller, as pure logic the boot scene
## (patched/scenes/boot/boot_scene.gd) drives:
##
##   new game:  character creation choices (cast id + name,
##              optionally a PUWCharacterSetup-built character
##              dict) -> new_game_state -> shared channels ->
##              host map (OaksLab for a custom character, whose
##              party is empty until the Oak event grants the
##              two picks; the saved map / Pallet Town for a
##              fixed protagonist, whose team is already granted)
##   continue:  PUWSaveManager.load_game -> shared channels ->
##              host map from the state (saved map if the state
##              carries one, else Pallet Town)
##
## The shared channels are the ones every bound system already
## reads: BagScene.save_state (the save state) and
## PartyScene.party (the party). Nothing here invents state:
## new_game_state and load_game own the state's shape.

## Story-flag key a host may stamp with the map the player is
## on, so continue can return there. Absent = Pallet Town.
const CURRENT_MAP_FLAG: String = "current_map"

## Boot channel: the boot scene stores its new_game /
## continue_game result here; PUWGameHost._ready consumes it
## (and clears it) to boot itself. This replaces the old main
## scene's blind auto-transition to the placeholder overworld.
static var pending_boot: Dictionary = {}

## Default first map for a fixed protagonist / a continue with
## no saved map. Pallet Town is where every Kanto journey the
## bound content describes begins.
const DEFAULT_MAP: String = "PalletTown"

## Map a custom character starts on: the Oak flow event
## (data/events/oak_lab_opening.json) plays in OaksLab and its
## terminal warp takes the player to Pallet Town.
const CUSTOM_START_MAP: String = "OaksLab"


## Start a new game. character is an optional Dictionary built
## by PUWCharacterSetup.build_character(); when given it is
## stored verbatim under the setup's own save-flag key inside
## the state's story_flags (PUWCharacterSetup.save_character
## does the same store; doing it here keeps the boot to one
## state build, and the character setup scene remains the
## author of the dict). Returns {ok, state, party, cast_id,
## needs_oak_flow, start_map}.
static func new_game(cast_id: String, player_name: String, character: Dictionary = {}) -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state(cast_id, player_name)
	if not character.is_empty():
		var flags_value: Variant = state.get("story_flags", {})
		var flags: Dictionary = flags_value if flags_value is Dictionary else {}
		flags[PUWCharacterSetup.SAVE_FLAG_KEY] = character.duplicate(true)
		state["story_flags"] = flags
	var party_value: Variant = state.get("party", [])
	var party: Array = party_value if party_value is Array else []
	_publish(state, party)
	var needs_oak: bool = party.is_empty()
	return {
		"ok": true,
		"state": state,
		"party": party,
		"cast_id": cast_id,
		"needs_oak_flow": needs_oak,
		"start_map": CUSTOM_START_MAP if needs_oak else DEFAULT_MAP,
	}


## Continue the saved game. Returns {ok:false, reason} when
## there is no readable save -- the boot scene shows its
## "no save" state then; nothing is fabricated.
static func continue_game() -> Dictionary:
	if not PUWSaveManager.has_save():
		return {"ok": false, "reason": "no_save"}
	var state: Dictionary = PUWSaveManager.load_game()
	if state.is_empty():
		return {"ok": false, "reason": "save_unreadable"}
	var party_value: Variant = state.get("party", [])
	var party: Array = party_value if party_value is Array else []
	_publish(state, party)
	return {
		"ok": true,
		"state": state,
		"party": party,
		"cast_id": cast_id_of(state),
		"needs_oak_flow": false,
		"start_map": start_map_for(state),
	}


## The map a state should boot its host on: the Oak lab while
## a custom character still has no Pokemon, else the state's
## recorded current map, else Pallet Town.
static func start_map_for(state: Dictionary) -> String:
	var party_value: Variant = state.get("party", [])
	var party: Array = party_value if party_value is Array else []
	if party.is_empty():
		return CUSTOM_START_MAP
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		var map_name: String = str(flags.get(CURRENT_MAP_FLAG, ""))
		if map_name != "":
			return map_name
	return DEFAULT_MAP


## The cast id a state was created with ("" when unknown).
static func cast_id_of(state: Dictionary) -> String:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		return str(flags.get("cast_id", ""))
	return ""


## Record the map the player is on, in the state's own flags,
## so a later continue returns there. Mutates the passed
## state's flags in place (the state dict is the save).
static func record_current_map(state: Dictionary, map_name: String) -> void:
	var flags_value: Variant = state.get("story_flags", {})
	var flags: Dictionary = flags_value if flags_value is Dictionary else {}
	flags[CURRENT_MAP_FLAG] = map_name
	state["story_flags"] = flags


## Publish a state + party to the shared channels every bound
## scene/system reads. One place, so boot and battle return
## can never drift apart.
static func _publish(state: Dictionary, party: Array) -> void:
	BagScene.save_state = state
	PartyScene.party = party
