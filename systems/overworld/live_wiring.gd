class_name PUWLiveWiring
extends Node
## Live wiring for Pokemon Ultimate World: connects the world
## clock/weather, the follower controller, and the shader pack
## to real scenes at runtime. No scene files are edited; every
## mount is created in code, stored, and removable via detach().
##
## Clock choice: PUWWorldClock (res://systems/world/
## world_clock.gd) is the live clock. It is the implementation
## the passing tests/world_clock_tests.gd tests (phases "day" /
## "dusk" / "night", weather "clear" / "rain" / "sun" / "snow").
## The RC1 PUWWorldClockAndWeather (world/weather/) is a small
## stub with different phase names and no validated weather
## setter, so it is NOT used here. No new weather types or
## phases are invented: everything below reads this clock.
##
## Phase tints: PUWWorldClock defines phases but no colors, so
## the three tints below are PRESENTATION CHOICES made here
## (documented as such), not sourced game data:
##   day   -> Color(1.00, 1.00, 1.00)  (no tint)
##   dusk  -> Color(1.00, 0.82, 0.66)  (warm)
##   night -> Color(0.45, 0.52, 0.75)  (dark blue)
##
## Weather overlay: shaders/weather_overlay.gdshader supports
## exactly two modes (0 = rain, 1 = snow). Clock weather "rain"
## maps to mode 0 and "snow" to mode 1. For "clear" and "sun"
## the overlay layer exists but is hidden — the shader has no
## clear/sun mode and none is invented.
##
## Water surface: map JSONs carry a tileset name and numeric
## tile ids but no data marking which tiles are water, so water
## presence cannot be determined from data. Following the
## honest fallback, water_surface is mounted on the battle
## scene only (in the code-created ShaderMounts layer), never
## guessed onto a map.

const SHADER_PATHS: Dictionary = {
	"shiny_sparkle": "res://shaders/shiny_sparkle.gdshader",
	"water_surface": "res://shaders/water_surface.gdshader",
	"weather_overlay": "res://shaders/weather_overlay.gdshader",
	"tera_glow": "res://shaders/tera_glow.gdshader",
	"dynamax_aura": "res://shaders/dynamax_aura.gdshader",
}

const PHASE_TINTS: Dictionary = {
	"day": Color(1.0, 1.0, 1.0),
	"dusk": Color(1.0, 0.82, 0.66),
	"night": Color(0.45, 0.52, 0.75),
}

## The live clock (PUWWorldClock). Callers may drive it with
## tick()/from_dict()/set_weather() and then call refresh().
var clock: PUWWorldClock = null
## The follower controller this wiring delegates to.
var follower_controller: PUWFollowerController = null

var _map_root: Node = null
var _battle_root: Node = null
var _presentation: CanvasModulate = null
var _weather_layer: CanvasLayer = null
var _weather_rect: ColorRect = null
var _battle_mount_layer: CanvasLayer = null
var _shader_materials: Dictionary = {}
var _mount_records: Array = []


func _init() -> void:
	clock = PUWWorldClock.new()
	follower_controller = PUWFollowerController.new()
	add_child(follower_controller)


# ----------------------------------------------------------------
# Attach / detach / refresh
# ----------------------------------------------------------------

## Wire a map scene and/or a battle scene (either may be null).
## Applies the clock phase tint + weather overlay to the map
## and the shader mounts to the battle scene. Returns a record
## of what was mounted.
func attach(map_root: Node, battle_root: Node) -> Dictionary:
	var record: Dictionary = {"map": false, "battle": false}
	if map_root != null:
		_map_root = map_root
		mount_on_overworld(map_root)
		record["map"] = true
	if battle_root != null:
		_battle_root = battle_root
		mount_on_battle(battle_root)
		record["battle"] = true
	refresh()
	return record


## Remove every node/material this wiring mounted and restore
## the map's Presentation tint to white.
func detach() -> void:
	if _presentation != null and is_instance_valid(_presentation):
		_presentation.color = Color(1.0, 1.0, 1.0)
	_presentation = null
	if _weather_layer != null and is_instance_valid(_weather_layer):
		_weather_layer.queue_free()
	_weather_layer = null
	_weather_rect = null
	if _battle_mount_layer != null and is_instance_valid(_battle_mount_layer):
		_battle_mount_layer.queue_free()
	_battle_mount_layer = null
	for record_value in _mount_records:
		var record: Dictionary = record_value
		var node_value: Variant = record.get("node", null)
		if node_value is CanvasItem:
			var item: CanvasItem = node_value
			if is_instance_valid(item):
				item.material = null
	_mount_records.clear()
	_map_root = null
	_battle_root = null


## Re-apply the clock's current phase tint and weather overlay
## parameters to everything mounted.
func refresh() -> void:
	_apply_phase_tint()
	_apply_weather()


## The map's Presentation CanvasModulate color currently in
## effect (white when no map is attached).
func presentation_color() -> Color:
	if _presentation != null and is_instance_valid(_presentation):
		return _presentation.color
	return Color(1.0, 1.0, 1.0)


## The tint this wiring uses for a clock phase name.
static func tint_for_phase(phase: String) -> Color:
	var tint_value: Variant = PHASE_TINTS.get(phase, Color(1.0, 1.0, 1.0))
	if tint_value is Color:
		var tint: Color = tint_value
		return tint
	return Color(1.0, 1.0, 1.0)


func _apply_phase_tint() -> void:
	if _presentation == null or not is_instance_valid(_presentation):
		return
	_presentation.color = tint_for_phase(clock.get_time_of_day())


func _apply_weather() -> void:
	if _weather_rect == null or not is_instance_valid(_weather_rect):
		return
	var material: ShaderMaterial = weather_overlay_material()
	if material == null:
		return
	var weather: String = clock.get_weather()
	if weather == "rain":
		material.set_shader_parameter("mode", 0)
		material.set_shader_parameter("intensity", 0.6)
		_weather_layer.visible = true
	elif weather == "snow":
		material.set_shader_parameter("mode", 1)
		material.set_shader_parameter("intensity", 0.6)
		_weather_layer.visible = true
	else:
		# "clear" / "sun": the overlay shader has no such mode.
		_weather_layer.visible = false


# ----------------------------------------------------------------
# Followers (delegates to PUWFollowerController)
# ----------------------------------------------------------------

## Choose the party followers. Same contract as
## PUWFollowerController.select_followers().
func update_followers(party: Array, chosen: Array) -> Dictionary:
	return follower_controller.select_followers(party, chosen)


## The current follower records.
func get_followers() -> Array:
	return follower_controller.get_followers()


## Record one player position and return the followers'
## trailing positions for it.
func tick(player_pos: Vector2) -> Array:
	follower_controller.record_player_position(player_pos)
	return follower_controller.follower_positions()


# ----------------------------------------------------------------
# Rotom Menu — VEXA shortcut (canon audit gap G5)
# ----------------------------------------------------------------
## The custom register documents VEXA access through an
## "X/Rotom Menu shortcut" as well as the in-world holo pads.
## This wiring serves that entry: the Rotom Menu's VEXA entry is
## plain data (rotom_menu_entries()), pressing X toggles the
## VEXA menu state (_unhandled_input below), and
## open_vexa_via_shortcut() is the call the menu makes. The
## simulator behind the entry is the real PUWVexaSimulator,
## hosted on this node; run_vexa_via_shortcut() delegates to its
## run_simulation() with the party set through set_menu_party().
## Safety is the simulator's own: it snapshots and battles deep
## copies only, so the shortcut changes nothing about that.

## The Rotom Menu entry this wiring serves. "menu" names the
## Rotom Menu so a menu scene can place the entry without
## inventing its own copy of the label or the shortcut key.
const ROTOM_MENU_VEXA_ENTRY: Dictionary = {
	"id": "vexa_simulator",
	"label": "VEXA Simulator",
	"menu": "rotom_menu",
	"shortcut_key": "X",
}

## The simulator behind the shortcut entry (created on first
## use, hosted on this node).
var vexa_simulator: PUWVexaSimulator = null
## The live party the shortcut sims against. The game sets it
## (set_menu_party) the same way it sets followers; the wiring
## never reaches into game state on its own.
var menu_party: Array = []
var _vexa_menu_open: bool = false


## The Rotom Menu entries this wiring serves: exactly the VEXA
## shortcut entry. Other Rotom features are not part of this
## wiring and are not listed.
func rotom_menu_entries() -> Array:
	return [ROTOM_MENU_VEXA_ENTRY.duplicate(true)]


## Set the live party the VEXA shortcut will sim against.
func set_menu_party(party: Array) -> void:
	menu_party = party


func _ensure_vexa_simulator() -> PUWVexaSimulator:
	if vexa_simulator == null:
		vexa_simulator = PUWVexaSimulator.new()
		vexa_simulator.setup(self)
	return vexa_simulator


## Open the VEXA menu state through the shortcut entry. Returns
## vexa_menu_state() so the caller can render or check it.
func open_vexa_via_shortcut() -> Dictionary:
	_ensure_vexa_simulator()
	_vexa_menu_open = true
	return vexa_menu_state()


## Close the VEXA menu state (the simulator instance is kept).
func close_vexa_menu() -> void:
	_vexa_menu_open = false


## True while the VEXA menu state is open.
func is_vexa_menu_open() -> bool:
	return _vexa_menu_open


## The current VEXA menu state: whether it is open, the entry
## that opened it, and the LIVE simulator's formats with their
## honest build status (triple / rotation / tera_raid report
## "not_yet_built", exactly as the simulator itself reports).
func vexa_menu_state() -> Dictionary:
	var sim: PUWVexaSimulator = _ensure_vexa_simulator()
	var statuses: Dictionary = {}
	var all_formats: Array = ["singles", "doubles", "vgc", "sky", "inverse", "triple", "rotation", "tera_raid"]
	for format_value in all_formats:
		var format_id: String = format_value
		statuses[format_id] = sim.format_status(format_id)
	return {
		"open": _vexa_menu_open,
		"entry": ROTOM_MENU_VEXA_ENTRY.duplicate(true),
		"formats": sim.supported_formats(),
		"format_status": statuses,
	}


## Run one simulation through the shortcut: opens the menu
## state first if needed, then delegates to the simulator with
## the party set through set_menu_party(). The result is the
## simulator's own result dict, unchanged.
func run_vexa_via_shortcut(options: Dictionary) -> Dictionary:
	if not _vexa_menu_open:
		open_vexa_via_shortcut()
	return _ensure_vexa_simulator().run_simulation(menu_party, options)


## X toggles the VEXA menu state (the documented shortcut key).
## Key releases and key echoes do not toggle.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_X:
			if _vexa_menu_open:
				close_vexa_menu()
			else:
				open_vexa_via_shortcut()


# ----------------------------------------------------------------
# Shader materials
# ----------------------------------------------------------------

## One ShaderMaterial per shipped shader (all 5), created once
## and cached. Returns {shader_name: ShaderMaterial}.
func shader_mounts() -> Dictionary:
	if not _shader_materials.is_empty():
		return _shader_materials.duplicate()
	for name_value in SHADER_PATHS.keys():
		var shader_name: String = str(name_value)
		var path: String = str(SHADER_PATHS.get(shader_name, ""))
		var shader: Shader = load(path) as Shader
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		_shader_materials[shader_name] = material
	return _shader_materials.duplicate()


## The shared weather overlay ShaderMaterial (null before
## shader_mounts() has run).
func weather_overlay_material() -> ShaderMaterial:
	var mounts: Dictionary = shader_mounts()
	var material_value: Variant = mounts.get("weather_overlay", null)
	if material_value is ShaderMaterial:
		var material: ShaderMaterial = material_value
		return material
	return null


## The weather overlay CanvasLayer mounted on the current map
## (null when no map is attached).
func weather_overlay_layer() -> CanvasLayer:
	return _weather_layer


# ----------------------------------------------------------------
# Mounts
# ----------------------------------------------------------------

## Mount onto a map scene: the Presentation phase tint and the
## weather overlay CanvasLayer. water_surface is NOT mounted
## here — map data cannot identify water tiles (see header).
## Returns a mount record.
func mount_on_overworld(map_root: Node) -> Dictionary:
	var record: Dictionary = {
		"weather_overlay": false,
		"phase_tint": false,
		"water_surface": false,
		"water_note": "not mounted on maps: map JSON/tileset data does not identify water tiles",
	}
	var presentation_value: Variant = map_root.get_node_or_null("Presentation")
	if presentation_value is CanvasModulate:
		_presentation = presentation_value
		record["phase_tint"] = true
	# Weather overlay: a full-screen ColorRect in its own layer.
	if _weather_layer != null and is_instance_valid(_weather_layer):
		_weather_layer.queue_free()
	_weather_layer = CanvasLayer.new()
	_weather_layer.name = "PUWWeatherOverlay"
	_weather_layer.layer = 10
	_weather_rect = ColorRect.new()
	_weather_rect.name = "WeatherOverlayRect"
	_weather_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather_rect.material = weather_overlay_material()
	_weather_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_layer.add_child(_weather_rect)
	map_root.add_child(_weather_layer)
	record["weather_overlay"] = true
	_mount_records.append({"kind": "weather_overlay", "node": _weather_rect})
	_apply_phase_tint()
	_apply_weather()
	return record


## Mount onto the battle scene: tera_glow on the player sprite
## placeholder, dynamax_aura on the enemy sprite placeholder
## (both are ColorRects in scenes/battle.tscn), plus a
## code-created "ShaderMounts" CanvasLayer carrying
## shiny_sparkle and — per the honest water fallback —
## water_surface. Returns a mount record.
func mount_on_battle(battle_root: Node) -> Dictionary:
	var mounts: Dictionary = shader_mounts()
	var record: Dictionary = {
		"tera_glow": false,
		"dynamax_aura": false,
		"shiny_sparkle": false,
		"water_surface": false,
		"shader_mounts_layer": false,
	}
	var player_sprite_value: Variant = battle_root.get_node_or_null("PlayerMon/PlayerSprite")
	if player_sprite_value is CanvasItem:
		var player_sprite: CanvasItem = player_sprite_value
		player_sprite.material = mounts.get("tera_glow", null)
		_mount_records.append({"kind": "tera_glow", "node": player_sprite})
		record["tera_glow"] = true
	var enemy_sprite_value: Variant = battle_root.get_node_or_null("EnemyMon/EnemySprite")
	if enemy_sprite_value is CanvasItem:
		var enemy_sprite: CanvasItem = enemy_sprite_value
		enemy_sprite.material = mounts.get("dynamax_aura", null)
		_mount_records.append({"kind": "dynamax_aura", "node": enemy_sprite})
		record["dynamax_aura"] = true
	if _battle_mount_layer != null and is_instance_valid(_battle_mount_layer):
		_battle_mount_layer.queue_free()
	_battle_mount_layer = CanvasLayer.new()
	_battle_mount_layer.name = "ShaderMounts"
	_battle_mount_layer.layer = 5
	var shiny_rect: ColorRect = ColorRect.new()
	shiny_rect.name = "ShinySparkleMount"
	shiny_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shiny_rect.material = mounts.get("shiny_sparkle", null)
	shiny_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_mount_layer.add_child(shiny_rect)
	_mount_records.append({"kind": "shiny_sparkle", "node": shiny_rect})
	record["shiny_sparkle"] = true
	var water_rect: ColorRect = ColorRect.new()
	water_rect.name = "WaterSurfaceMount"
	water_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	water_rect.material = mounts.get("water_surface", null)
	water_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_mount_layer.add_child(water_rect)
	_mount_records.append({"kind": "water_surface", "node": water_rect})
	record["water_surface"] = true
	battle_root.add_child(_battle_mount_layer)
	record["shader_mounts_layer"] = true
	return record


## Every mount record made so far (removable data: detach()
## walks this list and clears the materials / frees layers).
func mount_records() -> Array:
	return _mount_records.duplicate(true)
