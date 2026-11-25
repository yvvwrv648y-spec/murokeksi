class_name PUWOverworldMechanicsGlue
extends Node2D
## The overworld mechanics glue (mechanics-completeness prep
## F6, 2026-11-24).
##
## The gap this closes: the overworld mechanics hub --
## PUWMapLoader, PUWPlayerController (bikes, PokéMount rides,
## badge-locked field actions), PUWSpawner, PUWFollower-
## Controller, PUWLiveWiring -- is complete and suite-proven
## as a system, but NOTHING in the live game instantiates it.
## The live overworld scene (scenes/overworld_scene.gd) is a
## self-described placeholder: flat ground, a raw
## CharacterBody2D, and only the wild-battle hand-off wired.
## Every other mechanic therefore had no live caller.
##
## This node is the composition the real overworld scene
## adopts (see the patched scenes/overworld_scene.gd, which
## adds it as a child and delegates to it): it creates the
## hub, loads a real map, binds the save state + party into
## the field-action gate, spawns the map's placements, starts
## the follower selection, and exposes the mechanics verbs
## (mount bicycle / mount Pokémon / field action / step) plus
## the trainer-trigger scan that hands a spotted trainer to
## the difficulty layer (PUWBattleEntry) -- the composition
## campaign_stitch + battle_entry always assumed a scene
## would perform.
##
## It invents no mechanics: every verb delegates to the
## hub's own classes, and every battle team is built by
## PUWBattleEntry and checked by its hand-off guard.

var map_loader: PUWMapLoader = null
var player: PUWPlayerController = null
var spawner: PUWSpawner = null
var habitat: PUWHabitatEncounters = null
var entry: PUWBattleEntry = null
var followers: PUWFollowerController = null
var live_wiring: PUWLiveWiring = null
var coop: PUWCoopNetworkManager = null

var _rematch_tables: Dictionary = {}

var save_state: Dictionary = {}
var party: Array = []
var current_map_name: String = ""
var spawn_report: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Create the hub and load a real map. state is the save
## state (BagScene.save_state in the live scene); party is
## the player's party (PartyScene.party). cast_id is the
## player character's cast id for the rig loader. Returns
## {ok, map, spawn_report, followers} -- ok is false (and
## nothing is half-set-up) when the map does not load.
func setup(map_name: String, state: Dictionary, player_party: Array, cast_id: String = "") -> Dictionary:
	save_state = state
	party = player_party
	map_loader = PUWMapLoader.new()
	map_loader.name = "MapLoader"
	add_child(map_loader)
	if not map_loader.load_map(map_name):
		return {"ok": false, "reason": "map_load_failed", "map": map_name}
	current_map_name = map_loader.current_map_name
	player = PUWPlayerController.new()
	player.name = "PlayerController"
	add_child(player)
	player.setup(map_loader)
	if cast_id != "":
		player.set_cast(cast_id)
	player.set_field_context(save_state, party)
	var spawn_tile: Vector2i = _first_walkable_tile()
	if spawn_tile.x >= 0:
		player.place_at_tile(spawn_tile)
	spawner = PUWSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawn_report = spawner.spawn_map(self, current_map_name)
	habitat = PUWHabitatEncounters.new()
	habitat.load_data()
	entry = PUWBattleEntry.new()
	followers = PUWFollowerController.new()
	followers.name = "FollowerController"
	add_child(followers)
	var follower_result: Dictionary = {"ok": false, "reason": "empty_party"}
	if not party.is_empty():
		follower_result = followers.select_followers(party, [0])
	live_wiring = PUWLiveWiring.new()
	live_wiring.name = "LiveWiring"
	add_child(live_wiring)
	live_wiring.attach(self, null)
	coop = PUWCoopNetworkManager.new()
	coop.name = "CoopNetworkManager"
	add_child(coop)
	return {"ok": true, "map": current_map_name, "spawn_report": spawn_report, "followers": follower_result}


## First in-bounds non-solid tile, scanning row by row.
## Vector2i(-1, -1) when the map has none.
func _first_walkable_tile() -> Vector2i:
	for y in range(map_loader.map_height_tiles):
		for x in range(map_loader.map_width_tiles):
			var tile: Vector2i = Vector2i(x, y)
			if not map_loader.is_solid_tile(tile):
				return tile
	return Vector2i(-1, -1)


## One movement step through the player controller (bikes,
## rides, capacities and field gates all apply inside).
## Returns the tile the player is on after the step.
func step(delta: float, input_dir: Vector2, mode: String) -> Vector2i:
	if player == null:
		return Vector2i(-1, -1)
	var tile: Vector2i = player.step(delta, input_dir, mode)
	if followers != null:
		followers.record_player_position(player.position)
	if live_wiring != null:
		live_wiring.tick(player.position)
	return tile


## Mount a bicycle by registry id (PUWBikes rules apply:
## tandems and unknown ids are refused by the controller).
func mount_bicycle(bicycle_id: String) -> bool:
	if player == null:
		return false
	return player.mount_bicycle(bicycle_id)


## Mount the solo bicycle of a cast member.
func mount_bicycle_for_cast(cast_id: String) -> bool:
	if player == null:
		return false
	return player.mount_bicycle_for_cast(cast_id)


## Mount a rideable Pokémon (PUWRideSystem eligibility).
func mount_pokemon(species_slug: String, mode_id: String, gender: String = "") -> bool:
	if player == null:
		return false
	return player.mount_pokemon(species_slug, mode_id, gender)


## Run one badge-locked field action through the gate
## (PUWFieldActions' own verdict, via the controller hook).
func attempt_field_action(action_id: String) -> Dictionary:
	if player == null:
		return {"allowed": false, "reason": "no_player", "via": "", "species": ""}
	return player.attempt_field_action(action_id)


## Re-bind the field context after the party or save state
## changes (a capture, a badge award, a party swap).
func refresh_field_context(state: Dictionary, player_party: Array) -> void:
	save_state = state
	party = player_party
	if player != null:
		player.set_field_context(save_state, party)


## True while a co-op session is connected (the coop
## manager's own state). Tandem riding is strictly gated on
## this (bicycle_registry.json coop_tandem_rule).
func coop_active() -> bool:
	return coop != null and coop.is_coop_connected


## True when tandem riding is available right now:
## PUWBikes.tandem_available over the live co-op state.
## Single-player never sees tandem (the coop manager's own
## is_tandem_ui_visible states the same rule).
func tandem_available() -> bool:
	return PUWBikes.tandem_available(coop_active())


## Resolve the tandem bicycle for a driver cast member.
## Refused while co-op is offline. The consent handshake
## itself (request / respond / passenger camera lock) runs
## through PUWCoopNetworkManager at the session layer;
## this resolves availability + the bicycle only.
func mount_tandem(driver_cast_id: String) -> Dictionary:
	if not tandem_available():
		return {"ok": false, "reason": "coop_offline_tandem_hidden", "bicycle_id": ""}
	var bicycle_id: String = PUWBikes.tandem_bicycle_id_for(driver_cast_id)
	if bicycle_id == "":
		return {"ok": false, "reason": "unknown_driver", "bicycle_id": ""}
	return {"ok": true, "bicycle_id": bicycle_id, "theme": PUWBikes.tandem_theme(driver_cast_id)}


## Use the Vs. Seeker (mechanics prep F9, 2026-11-24): the
## charge rule is PUWItemServices.vs_seeker_charge (100
## steps since the last use, recorded on the state). On a
## successful use the step stamp is written, so the next
## use needs a fresh 100 steps. Pair with start_rematch.
func use_vs_seeker(state: Dictionary, steps_taken: int) -> Dictionary:
	if not PUWItemServices.vs_seeker_charge(state, steps_taken):
		return {"ok": false, "reason": "not_charged"}
	state["vs_seeker_last_use_step"] = steps_taken
	return {"ok": true}


## The region's rematch tables, sanitized ONCE through
## PUWBattleEntry.sanitize_rematch_tables (Bossy ruling
## D4: tier iv/level fields are dropped at load; parties
## are built by the difficulty layer at battle time).
## Loaded from the bound data/rematch_tables_<region>.json.
func load_rematch_tables(region_id: String) -> Dictionary:
	if _rematch_tables.has(region_id):
		var cached: Dictionary = _rematch_tables[region_id]
		return cached
	var trainers: Dictionary = {}
	var path: String = "res://data/rematch_tables_%s.json" % region_id
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var file_data: Dictionary = parsed
			var trainers_value: Variant = file_data.get("trainers", {})
			if trainers_value is Dictionary:
				trainers = trainers_value
	var report: Dictionary = PUWBattleEntry.sanitize_rematch_tables(trainers)
	var sanitized_value: Variant = report.get("tables", {})
	var sanitized: Dictionary = sanitized_value if sanitized_value is Dictionary else {}
	_rematch_tables[region_id] = sanitized
	return sanitized


## Start a Vs. Seeker rematch: the trainer's tier supplies
## species identity ONLY (D4); PUWBattleEntry builds the
## 6-mon party at the player's current max level, and the
## hand-off guard validates it. Returns {entry_result,
## enemy_party, verdict} like scan_trainer_trigger.
func start_rematch(region_id: String, trainer_key: String, tier_index: int) -> Dictionary:
	if entry == null:
		entry = PUWBattleEntry.new()
	var tables: Dictionary = load_rematch_tables(region_id)
	var player_max: int = PUWBattleEntry.player_max_level(party)
	var result: Dictionary = entry.start_rematch_battle(tables, trainer_key, tier_index, player_max, "singles", rng)
	var team_value: Variant = result.get("enemy_party", [])
	var team: Array = team_value if team_value is Array else []
	var verdict: Dictionary = PUWBattleEntry.hand_off(team, 6, {"exact": player_max})
	return {"entry_result": result, "enemy_party": team, "verdict": verdict}


## Scan the spawned trainers for one whose trigger fires
## against the player's current tile (sight first, then
## interaction, PUWSpawner's own rules). On a trigger, the
## trainer's team is built by the difficulty layer and
## checked by its hand-off guard. Returns {} when no
## trainer triggers; otherwise {trainer, enemy_party,
## verdict, entry_result} -- the caller hands enemy_party
## to BattleScene exactly like the wild hand-off does.
func scan_trainer_trigger() -> Dictionary:
	if spawner == null or player == null or entry == null:
		return {}
	var player_tile: Vector2i = player.player_tile()
	var blocked: Callable = func(t: Vector2i) -> bool:
		return map_loader.is_solid_tile(t)
	for node_value in get_children():
		var node: Node = node_value
		var trainer: Dictionary = PUWSpawner.trainer_dict_from_node(node)
		if trainer.is_empty():
			continue
		var triggers: bool = PUWSpawner.check_sight(trainer, player_tile, blocked) \
			or PUWSpawner.check_interaction(trainer, player_tile, PUWSpawner.facing_vector(player.facing))
		if not triggers:
			continue
		var player_max: int = PUWBattleEntry.player_max_level(party)
		var result: Dictionary = entry.start_route_trainer_battle(trainer, player_max, "singles", rng)
		var team_value: Variant = result.get("enemy_party", result.get("party", []))
		var team: Array = team_value if team_value is Array else []
		var verdict: Dictionary = PUWBattleEntry.hand_off(team, 6, {"exact": player_max})
		return {"trainer": trainer, "enemy_party": team, "verdict": verdict, "entry_result": result}
	return {}
