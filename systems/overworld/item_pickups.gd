class_name PUWItemPickups
extends RefCounted
## Item pickup system (code_prep_kanto_item_fixes, fix F1 + F4/F5
## runtime). The bound spawner classifies item balls and stamps
## them with an `item` meta, but nothing in the bound tree
## consumed that meta — no pickup could be collected. This class
## is the consumer:
##
## - try_pickup_node(): the spawner-node path — reads the node's
##   own metas (kind / map / tile / item), exactly as stamped by
##   PUWSpawner._make_node.
## - try_pickup_at(): the data path — classifies the object on
##   the faced tile straight from the map JSON (both schemas:
##   Kanto objects carry `item`; Sevii objects carry only
##   graphics_id, so their identities come from
##   res://data/sevii_item_balls.json, the F4 restoration).
## - Hidden items (res://data/hidden_items.json, fix F5) are
##   checked on the faced tile after visible objects, under the
##   source trigger rule: pokered's CheckForHiddenEvent fires
##   when the event coords equal the tile IN FRONT of the
##   player.
##
## A successful grant goes through PUWLiveBag.grant_to_state and
## records a once-flag in the state's story_flags keyed
## (map, x, y, item) — "pickup|<Map>|<x>|<y>|<CONST>" for balls,
## "hidden_pickup|..." for hidden items — so a collected ball
## stays collected across save/load (despawn_collected_nodes
## hides the nodes again on spawn). The "found item" message is
## generated in the source games' own format (pokered
## _FoundItemText / _FoundHiddenItemText: "<PLAYER> found
## <ITEM>!") with the registry's display name — the dialogue
## prep proved no static text exists for pickups; in the source
## the pickup code generates it, and now ours does too.
##
## Pokemon balls (item == null) are ROUTED, never granted here:
## res://data/pokemon_ball_routes.json classifies all 15 Kanto
## balls — ambush battles (species/level from the bound trainer
## block), the Dojo gift choice and the Eevee gift (parameters
## from the source scripts), the Oak's Lab balls (owned by the
## story/Oak lane), and the Fuchsia zoo Voltorb (dialogue only).
## The host performs the battle/grant through its own entry
## points; this class returns the route and its parameters.
##
## An item constant that PUWItemResolve cannot resolve is
## reported {ok: false, reason: "unresolved_item"} and the ball
## is NOT consumed — the honest state the audit found stays
## visible instead of being papered over.

const MAPS_DIR: String = "res://maps/data/maps/"
const SEVII_BALLS_PATH: String = "res://data/sevii_item_balls.json"
const HIDDEN_PATH: String = "res://data/hidden_items.json"
const ROUTES_PATH: String = "res://data/pokemon_ball_routes.json"

const BALL_SPRITE: String = "SPRITE_POKE_BALL"
const BALL_GFX: String = "OBJ_EVENT_GFX_ITEM_BALL"

static var _sevii_maps: Dictionary = {}
static var _sevii_loaded: bool = false
static var _hidden_records: Array = []
static var _hidden_loaded: bool = false
static var _routes: Dictionary = {}
static var _routes_loaded: bool = false


static func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ----------------------------------------------------------------
# Flag store (the save state's story_flags — the same store the
# event runner and the campaign stitch read and write).
# ----------------------------------------------------------------

static func _flags(state: Dictionary) -> Dictionary:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		return flags
	var fresh: Dictionary = {}
	state["story_flags"] = fresh
	return fresh


static func ball_flag_key(map_name: String, tile: Vector2i, item_const: String) -> String:
	return "pickup|" + map_name + "|" + str(tile.x) + "|" + str(tile.y) + "|" + item_const


static func hidden_flag_key(map_name: String, tile: Vector2i, item_const: String) -> String:
	return "hidden_pickup|" + map_name + "|" + str(tile.x) + "|" + str(tile.y) + "|" + item_const


static func is_collected(state: Dictionary, flag_key: String) -> bool:
	return bool(_flags(state).get(flag_key, false))


# ----------------------------------------------------------------
# Message generation (source format, registry display name).
# ----------------------------------------------------------------

static func _player_name(state: Dictionary) -> String:
	var player_value: Variant = state.get("player", {})
	if player_value is Dictionary:
		var player: Dictionary = player_value
		var display: String = str(player.get("name", ""))
		if display != "":
			return display
	return "PLAYER"


## "<PLAYER> found <ITEM>!" — pokered _FoundItemText (visible
## balls) and _FoundHiddenItemText (hidden items) share the
## shape; the item name is the registry's display name.
static func found_message(state: Dictionary, canonical: String) -> String:
	return _player_name(state) + " found " + PUWItemResolve.display_name_for(canonical) + "!"


# ----------------------------------------------------------------
# Data accessors
# ----------------------------------------------------------------

## The raw objects array of one bound map (either schema), or
## [] when the map file is missing.
static func map_objects(map_name: String) -> Array:
	var parsed: Variant = _load_json(MAPS_DIR + map_name + ".json")
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var objects_value: Variant = data.get("objects", [])
		if objects_value is Array:
			var objects: Array = objects_value
			return objects
	return []


static func _ensure_sevii() -> void:
	if _sevii_loaded:
		return
	_sevii_loaded = true
	_sevii_maps = {}
	var parsed: Variant = _load_json(SEVII_BALLS_PATH)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var maps_value: Variant = data.get("maps", {})
		if maps_value is Dictionary:
			_sevii_maps = maps_value


## The F4-restored identity of a Sevii item ball:
## {item_const, quantity, source_script, source_flag} or {}.
static func sevii_item_at(map_name: String, tile: Vector2i) -> Dictionary:
	_ensure_sevii()
	var rows_value: Variant = _sevii_maps.get(map_name, [])
	if rows_value is Array:
		var rows: Array = rows_value
		for row_value in rows:
			if row_value is Dictionary:
				var row: Dictionary = row_value
				if int(row.get("x", -1)) == tile.x and int(row.get("y", -1)) == tile.y:
					return row
	return {}


static func _ensure_hidden() -> void:
	if _hidden_loaded:
		return
	_hidden_loaded = true
	_hidden_records = []
	var parsed: Variant = _load_json(HIDDEN_PATH)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var records_value: Variant = data.get("records", [])
		if records_value is Array:
			_hidden_records = records_value


## The hidden-item record at (map, tile), or {} — includes
## records whose map has no bound counterpart under "map": ""
## keyed by source_map_const; those never match a live map.
static func hidden_item_at(map_name: String, tile: Vector2i) -> Dictionary:
	_ensure_hidden()
	for record_value in _hidden_records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if str(record.get("map", "")) == map_name \
					and int(record.get("x", -1)) == tile.x \
					and int(record.get("y", -1)) == tile.y:
				return record
	return {}


static func _ensure_routes() -> void:
	if _routes_loaded:
		return
	_routes_loaded = true
	_routes = {}
	var parsed: Variant = _load_json(ROUTES_PATH)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var balls_value: Variant = data.get("balls", [])
		if balls_value is Array:
			var balls: Array = balls_value
			for ball_value in balls:
				if ball_value is Dictionary:
					var ball: Dictionary = ball_value
					var key: String = str(ball.get("map", "")) + "|" \
						+ str(int(ball.get("x", 0))) + "|" + str(int(ball.get("y", 0)))
					_routes[key] = ball


## The Pokemon-ball route record for (map, tile), or {}.
static func pokemon_ball_route(map_name: String, tile: Vector2i) -> Dictionary:
	_ensure_routes()
	var key: String = map_name + "|" + str(tile.x) + "|" + str(tile.y)
	var route_value: Variant = _routes.get(key, {})
	if route_value is Dictionary:
		var route: Dictionary = route_value
		return route
	return {}


# ----------------------------------------------------------------
# Classification (pure data — shared by both trigger paths).
# ----------------------------------------------------------------

## Classify one bound map object for the interaction seam:
##   {kind: "item", item_const}        a collectable item ball
##   {kind: "pokemon_ball", route...}  a Pokemon ball (routed)
##   {kind: "script_give"}             item == "0" marker object
##   {kind: "other"}                   anything else
static func classify_object(map_name: String, obj: Dictionary) -> Dictionary:
	var tile: Vector2i = Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
	# Sevii schema: identity rides the F4 sidecar.
	if str(obj.get("graphics_id", "")) == BALL_GFX:
		var identity: Dictionary = sevii_item_at(map_name, tile)
		if identity.is_empty():
			return {"kind": "other"}
		return {"kind": "item", "item_const": str(identity.get("item_const", "")),
			"quantity": int(identity.get("quantity", 1)), "sevii": true}
	var item_value: Variant = obj.get("item", null)
	if item_value is String:
		var item_const: String = item_value
		if item_const == "0":
			return {"kind": "script_give", "text_id": str(obj.get("text_id", ""))}
		if item_const != "":
			return {"kind": "item", "item_const": item_const, "quantity": 1}
	# item == null: a Pokemon ball when it wears the ball sprite
	# or carries a static-encounter trainer block.
	var trainer_value: Variant = obj.get("trainer", null)
	if str(obj.get("sprite", "")) == BALL_SPRITE or trainer_value is Dictionary:
		var route: Dictionary = pokemon_ball_route(map_name, tile)
		if route.is_empty() and trainer_value is Dictionary:
			var trainer: Dictionary = trainer_value
			route = {"route": "battle", "species": str(trainer.get("class", "")),
				"level": int(trainer.get("party", 0))}
		var out: Dictionary = {"kind": "pokemon_ball"}
		out.merge(route)
		return out
	return {"kind": "other"}


# ----------------------------------------------------------------
# The grant core.
# ----------------------------------------------------------------

## Collect one item (ball or hidden) into the state. Returns
## {found: true, kind: "item", ok, ...}: on success the item is
## granted through PUWLiveBag, the once-flag is set, and the
## generated message is included. On an unresolved constant or
## an already-collected flag, nothing changes.
static func collect_item(state: Dictionary, map_name: String, tile: Vector2i,
		item_const: String, quantity: int = 1, hidden: bool = false) -> Dictionary:
	var flag_key: String = hidden_flag_key(map_name, tile, item_const) if hidden \
		else ball_flag_key(map_name, tile, item_const)
	if is_collected(state, flag_key):
		return {"found": true, "kind": "item", "ok": false,
			"reason": "already_collected", "item_const": item_const,
			"flag_key": flag_key, "hidden": hidden}
	var canonical: String = PUWItemResolve.resolve_const(item_const)
	if canonical == "":
		return {"found": true, "kind": "item", "ok": false,
			"reason": "unresolved_item", "item_const": item_const,
			"flag_key": flag_key, "hidden": hidden}
	PUWLiveBag.grant_to_state(state, canonical, quantity)
	_flags(state)[flag_key] = true
	return {"found": true, "kind": "item", "ok": true,
		"item": canonical, "item_const": item_const, "quantity": quantity,
		"message": found_message(state, canonical),
		"flag_key": flag_key, "hidden": hidden}


# ----------------------------------------------------------------
# Triggers.
# ----------------------------------------------------------------

## The A-button seam, data path: classify the object on the
## faced tile; collect item balls; route Pokemon balls; then
## fall through to hidden items on the faced tile (the source
## trigger rule). Returns {found: false} when nothing is there.
static func try_pickup_at(state: Dictionary, map_name: String,
		player_tile: Vector2i, player_facing: Vector2i) -> Dictionary:
	if player_facing == Vector2i.ZERO:
		return {"found": false}
	var faced: Vector2i = player_tile + player_facing
	for obj_value in map_objects(map_name):
		if not (obj_value is Dictionary):
			continue
		var obj: Dictionary = obj_value
		if int(obj.get("x", -1)) != faced.x or int(obj.get("y", -1)) != faced.y:
			continue
		var classified: Dictionary = classify_object(map_name, obj)
		var kind: String = str(classified.get("kind", "other"))
		if kind == "item":
			return collect_item(state, map_name, faced,
				str(classified.get("item_const", "")),
				int(classified.get("quantity", 1)))
		if kind == "pokemon_ball":
			var out: Dictionary = {"found": true, "kind": "pokemon_ball"}
			out.merge(classified)
			out.erase("kind")
			out["kind"] = "pokemon_ball"
			return out
		if kind == "script_give":
			return {"found": true, "kind": "script_give",
				"text_id": str(classified.get("text_id", ""))}
		# kind == "other": the faced object has no interaction of
		# ours — fall through to the hidden-item check, as the
		# source's A-press order does.
	var hidden: Dictionary = hidden_item_at(map_name, faced)
	if not hidden.is_empty():
		return collect_item(state, map_name, faced,
			str(hidden.get("item_const", "")),
			int(hidden.get("quantity", 1)), true)
	return {"found": false}


## The A-button seam, spawner-node path: the node's own metas
## (stamped by PUWSpawner) drive the same outcomes. Item nodes
## collect; object nodes carrying a trainer block or a routed
## ball position route as Pokemon balls.
static func try_pickup_node(state: Dictionary, node: Node) -> Dictionary:
	if node == null:
		return {"found": false}
	var kind: String = str(node.get_meta("kind", ""))
	var map_name: String = str(node.get_meta("map", ""))
	var tile_value: Variant = node.get_meta("tile", Vector2i.ZERO)
	var tile: Vector2i = tile_value if tile_value is Vector2i else Vector2i.ZERO
	if kind == "item":
		return collect_item(state, map_name, tile, str(node.get_meta("item", "")))
	if kind == "object":
		var route: Dictionary = pokemon_ball_route(map_name, tile)
		if not route.is_empty():
			var out: Dictionary = {"found": true, "kind": "pokemon_ball"}
			out.merge(route)
			return out
	return {"found": false}


# ----------------------------------------------------------------
# Despawn (spawn-time filtering against the flag store).
# ----------------------------------------------------------------

## Hide every collected item node under a spawned map parent.
## Returns how many nodes were hidden. Sevii balls join this
## path once build 6 merges the F4 identities into the Sevii
## map objects (the spawner then stamps the same metas).
static func despawn_collected_nodes(parent: Node, state: Dictionary) -> int:
	var hidden_count: int = 0
	for child in parent.get_children():
		if str(child.get_meta("kind", "")) != "item":
			continue
		var map_name: String = str(child.get_meta("map", ""))
		var tile_value: Variant = child.get_meta("tile", Vector2i.ZERO)
		var tile: Vector2i = tile_value if tile_value is Vector2i else Vector2i.ZERO
		var item_const: String = str(child.get_meta("item", ""))
		if is_collected(state, ball_flag_key(map_name, tile, item_const)):
			child.visible = false
			child.set_meta("collected", true)
			hidden_count += 1
	return hidden_count


## Data-level spawn filter: the map's objects with collected
## item balls removed (hidden items are never objects — use
## hidden_item_at + is_collected for those).
static func uncollected_objects(map_name: String, state: Dictionary) -> Array:
	var kept: Array = []
	for obj_value in map_objects(map_name):
		if obj_value is Dictionary:
			var obj: Dictionary = obj_value
			var classified: Dictionary = classify_object(map_name, obj)
			if str(classified.get("kind", "")) == "item":
				var tile: Vector2i = Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
				if is_collected(state, ball_flag_key(map_name, tile,
						str(classified.get("item_const", "")))):
					continue
			kept.append(obj)
	return kept
