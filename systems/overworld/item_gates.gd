class_name PUWItemGates
extends RefCounted
## Key-item use gates (code_prep_kanto_item_fixes). The bound
## tree had NO code checking for any progression key item — no
## Card Key door, no Lift Key elevator, no Secret Key gym door,
## no Silph Scope ghost check, no Poke Flute / Snorlax path.
## These are the data hooks the host calls; every parameter
## comes from the source games (res://data/item_gates.json,
## extracted with its evidence):
##
## - card_key_door: pokered engine/events/card_key.asm — on
##   Silph Co 2F-11F, facing a card-key door tile (ids $18/$24,
##   $5e on 11F) opens it iff CARD_KEY is in the bag.
## - lift_key_elevator: scripts/RocketHideoutElevator.asm — the
##   elevator's floor menu (B1F/B2F/B4F) runs iff LIFT_KEY is
##   in the bag.
## - secret_key_door: scripts/CinnabarIsland.asm — without
##   SECRET_KEY, stepping to the tile south of the Cinnabar Gym
##   door facing it turns the player back with the locked-door
##   text; with the key the warp proceeds.
## - ghost_check: engine/battle/core.asm IsGhostBattle — in
##   battle on Pokemon Tower 1F-7F the enemy stays an
##   unidentified GHOST unless SILPH_SCOPE is in the bag.
## - snorlax_flute: engine/items/item_effects.asm
##   ItemUsePokeFlute + the Route 12/16 scripts — bag-using the
##   POKE_FLUTE (never consumed) on one of the source flute
##   tiles beside an unbeaten Snorlax wakes it into its
##   level-30 battle. The beaten state is read from the state's
##   story_flags under the source event name (the host sets it
##   when the battle resolves, as the source sets EVENT_BEAT_*).
##
## Possession is always read from the real save state through
## PUWLiveBag.count_in_state under the item's canonical id.
## These hooks decide; the host performs (door animation, floor
## menu, battle entry stay host/battle-entry work).

const GATES_PATH: String = "res://data/item_gates.json"

static var _gates: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_gates = {}
	if not FileAccess.file_exists(GATES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GATES_PATH))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var gates_value: Variant = data.get("gates", {})
		if gates_value is Dictionary:
			_gates = gates_value


static func _gate(name: String) -> Dictionary:
	_ensure()
	var gate_value: Variant = _gates.get(name, {})
	if gate_value is Dictionary:
		var gate: Dictionary = gate_value
		return gate
	return {}


## True when the state bag holds the gate's required item.
static func _holds(state: Dictionary, gate: Dictionary) -> bool:
	var canonical: String = PUWItemResolve.resolve_const(str(gate.get("requires", "")))
	if canonical == "":
		return false
	return PUWLiveBag.count_in_state(state, canonical) > 0


## Card Key door check for the tile in front of the player.
## {applies, opens, has_key, reason} — applies is false off the
## Silph maps or off a door tile (the host then does nothing).
static func card_key_door(state: Dictionary, map_name: String, tile_in_front_id: int) -> Dictionary:
	var gate: Dictionary = _gate("card_key_doors")
	if gate.is_empty():
		return {"applies": false, "opens": false, "has_key": false, "reason": "no_gate_data"}
	var maps_value: Variant = gate.get("maps", [])
	var maps: Array = maps_value if maps_value is Array else []
	if not maps.has(map_name):
		return {"applies": false, "opens": false, "has_key": false, "reason": "not_silph_co"}
	# JSON numbers arrive as floats; coerce to int or the id
	# comparison against the host's int tile id never matches.
	var door_ids: Array = []
	var base_value: Variant = gate.get("door_tile_ids", [])
	if base_value is Array:
		var base_ids: Array = base_value
		for id_value in base_ids:
			door_ids.append(int(id_value))
	var by_map_value: Variant = gate.get("door_tile_ids_by_map", {})
	if by_map_value is Dictionary:
		var by_map: Dictionary = by_map_value
		var extra_value: Variant = by_map.get(map_name, [])
		if extra_value is Array:
			var extra_ids: Array = extra_value
			for id_value in extra_ids:
				door_ids.append(int(id_value))
	if not door_ids.has(tile_in_front_id):
		return {"applies": false, "opens": false, "has_key": false, "reason": "not_a_card_key_door"}
	var has_key: bool = _holds(state, gate)
	return {"applies": true, "opens": has_key, "has_key": has_key,
		"reason": "ok" if has_key else "needs_card_key"}


## Lift Key elevator check (the host calls this when the
## elevator panel is used on RocketHideoutElevator).
## {applies, allowed, has_key, floors, reason}
static func lift_key_elevator(state: Dictionary) -> Dictionary:
	var gate: Dictionary = _gate("lift_key_elevator")
	if gate.is_empty():
		return {"applies": false, "allowed": false, "has_key": false, "floors": [], "reason": "no_gate_data"}
	var has_key: bool = _holds(state, gate)
	var floors_value: Variant = gate.get("floors", [])
	var floors: Array = floors_value if floors_value is Array else []
	return {"applies": true, "allowed": has_key, "has_key": has_key,
		"floors": floors, "reason": "ok" if has_key else "needs_lift_key"}


## Secret Key gym-door check. applies only on CinnabarIsland
## with the player on the source trigger tile facing the door;
## allowed is true when the key is held (the warp proceeds) and
## false when the source would bounce the player back.
static func secret_key_door(state: Dictionary, map_name: String,
		player_tile: Vector2i, player_facing: Vector2i) -> Dictionary:
	var gate: Dictionary = _gate("secret_key_gym_door")
	if gate.is_empty():
		return {"applies": false, "allowed": false, "has_key": false, "reason": "no_gate_data"}
	if map_name != str(gate.get("map", "")):
		return {"applies": false, "allowed": false, "has_key": false, "reason": "wrong_map"}
	var trigger_value: Variant = gate.get("trigger_tile", {})
	var trigger: Dictionary = trigger_value if trigger_value is Dictionary else {}
	var trigger_tile: Vector2i = Vector2i(int(trigger.get("x", -1)), int(trigger.get("y", -1)))
	var facing_name: String = str(gate.get("trigger_facing", "up"))
	var want_facing: Vector2i = Vector2i(0, -1) if facing_name == "up" else Vector2i.ZERO
	if player_tile != trigger_tile or player_facing != want_facing:
		return {"applies": false, "allowed": false, "has_key": false, "reason": "not_at_door"}
	var has_key: bool = _holds(state, gate)
	return {"applies": true, "allowed": has_key, "has_key": has_key,
		"reason": "ok" if has_key else "door_is_locked"}


## Silph Scope ghost check for a battle starting on map_name.
## {in_tower, has_scope, unidentified}
static func ghost_check(state: Dictionary, map_name: String) -> Dictionary:
	var gate: Dictionary = _gate("silph_scope_ghost")
	if gate.is_empty():
		return {"in_tower": false, "has_scope": false, "unidentified": false}
	var maps_value: Variant = gate.get("maps", [])
	var maps: Array = maps_value if maps_value is Array else []
	var in_tower: bool = maps.has(map_name)
	var has_scope: bool = _holds(state, gate)
	return {"in_tower": in_tower, "has_scope": has_scope,
		"unidentified": in_tower and not has_scope}


## Poke Flute / Snorlax check for a bag use of the flute on
## map_name at player_tile. {applies, can_wake, has_flute,
## beaten, battle, reason} — battle carries the source
## {species, level} when can_wake is true. The flute is never
## consumed by the source use, and this hook consumes nothing.
static func snorlax_flute(state: Dictionary, map_name: String, player_tile: Vector2i) -> Dictionary:
	var gate: Dictionary = _gate("poke_flute_snorlax")
	if gate.is_empty():
		return {"applies": false, "can_wake": false, "has_flute": false,
			"beaten": false, "battle": {}, "reason": "no_gate_data"}
	var sites_value: Variant = gate.get("sites", [])
	var sites: Array = sites_value if sites_value is Array else []
	var site: Dictionary = {}
	for site_value in sites:
		if site_value is Dictionary:
			var candidate: Dictionary = site_value
			if str(candidate.get("map", "")) == map_name:
				site = candidate
				break
	if site.is_empty():
		return {"applies": false, "can_wake": false, "has_flute": false,
			"beaten": false, "battle": {}, "reason": "no_snorlax_site"}
	var on_tile: bool = false
	var tiles_value: Variant = site.get("flute_tiles", [])
	if tiles_value is Array:
		var tiles: Array = tiles_value
		for tile_value in tiles:
			if tile_value is Dictionary:
				var tile: Dictionary = tile_value
				if int(tile.get("x", -1)) == player_tile.x and int(tile.get("y", -1)) == player_tile.y:
					on_tile = true
					break
	var has_flute: bool = _holds(state, gate)
	var flags_value: Variant = state.get("story_flags", {})
	var beaten: bool = false
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		beaten = bool(flags.get(str(site.get("beat_event", "")), false))
	var battle_value: Variant = site.get("battle", {})
	var battle: Dictionary = battle_value if battle_value is Dictionary else {}
	if not on_tile:
		return {"applies": false, "can_wake": false, "has_flute": has_flute,
			"beaten": beaten, "battle": {}, "reason": "not_beside_snorlax"}
	if beaten:
		return {"applies": true, "can_wake": false, "has_flute": has_flute,
			"beaten": true, "battle": {}, "reason": "already_beaten"}
	if not has_flute:
		return {"applies": true, "can_wake": false, "has_flute": false,
			"beaten": false, "battle": {}, "reason": "needs_poke_flute"}
	return {"applies": true, "can_wake": true, "has_flute": true,
		"beaten": false, "battle": battle, "reason": "ok"}
