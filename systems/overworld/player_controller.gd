class_name PUWPlayerController
extends Node2D
## MERGED for the host harness (host assembly prep): ow_anim prep's
## player_controller (swim state + run/swim clip loading) with the
## mechanics prep's F5 Rotom Bike water re-fit re-applied verbatim
## (the two preps patched the same file independently; their hunks
## are disjoint). Build 6 applies this same union to the real file.
## Tile-grid player controller for the PUW traversal core.
##
## Base class choice: Node2D, NOT CharacterBody2D. Collision here is
## tile data (TileData physics-layer-0 polygons read through
## PUWMapLoader.is_solid_tile), not physics shapes, so movement is
## resolved manually per axis against the tile grid. That keeps
## step() fully deterministic in a headless test run — no physics
## server frames, no move_and_slide timing — while the in-game path
## (_physics_process) just feeds real input into the same step().
##
## Movement model: position is a pixel point (the player's centre).
## A step moves along one axis at a time; the move is refused on
## that axis when the tile under the new centre would be solid.
## Speeds are in grid cells ("tiles") per second from the custom
## work bundle's movement spec, converted to px/s with the current
## map's tile size (8 px): sneak 2.2, walk 4.0, run 8.0,
## bike_acro 10.67, bike_mach 16.0.
##
## Traversal: stepping onto a warp tile executes the warp through
## PUWMapLoader (signal warp_triggered fires first, with the warp
## entry and resolved destination). Warps only trigger after the
## player has left all warp tiles since the last warp/spawn, so
## spawning on an interior exit warp does not bounce the player
## straight back out. Walking off an edge with a connection loads
## the connected map at the offset entry tile; walking off an edge
## without one is blocked (out-of-bounds tiles are solid).

signal warp_triggered(warp: Dictionary, dest_map_name: String, spawn_tile: Vector2i)
## Build 6 (A-52): optional host warp veto — when set, the
## callable (warp, dest_map_name) -> bool may refuse a warp
## before it executes (the Marowak stair gate). Unset = every
## warp proceeds, the pre-build-6 behavior everywhere.
var warp_veto: Callable = Callable()
signal map_changed(map_name: String, id_const: String)

const SPEEDS: Dictionary = {
	"sneak": 2.2, "walk": 4.0, "run": 8.0, "bike_acro": 10.67, "bike_mach": 16.0,
}
## --- Stealth (canon audit gap G2 wiring, 2026-11-23) ---
## NOISE and DETECTION_MULT are ported VERBATIM from Neon's
## core/movement_and_stealth_controller.gd
## (PUWMovementAndStealthController), the same source SPEEDS
## came from. NOISE is a unitless level per mode (sneak is
## exactly 0.00: a crouch-sneaking player makes no noise at
## all); DETECTION_MULT scales a trainer's sight_range in
## PUWSpawner.check_detection (sneak 0.35x: a sneaking player
## must get much closer to be seen; run 1.45x and the bikes
## higher: fast movement is spotted farther away). Before this
## wiring the pack carried the speeds only, so sneaking was
## slower walking with no gameplay effect. The spawner owns
## the detection checks; this controller only publishes the
## current mode's values (current_noise /
## current_detection_mult).
const NOISE: Dictionary = {
	"sneak": 0.00, "walk": 0.45, "run": 0.85, "bike_acro": 1.00, "bike_mach": 1.00,
}
const DETECTION_MULT: Dictionary = {
	"sneak": 0.35, "walk": 1.00, "run": 1.45, "bike_acro": 1.75, "bike_mach": 1.90,
}
const CLIP_FPS: Dictionary = {"idle": 4.0, "walk": 7.5, "run": 11.0, "bike": 11.0, "swim": 7.5}
const FACINGS: Array = ["down", "up", "left", "right"]
const STATES: Array = ["idle", "walk", "run", "bike", "swim"]

var loader: PUWMapLoader = null
var facing: String = "down"
var locomotion_state: String = "idle"
var current_mode: String = "walk"
var current_animation: String = "idle_down"
var cast_id: String = ""
## When false, _physics_process does not read real input (tests
## drive step() directly). In-game it stays true.
var input_enabled: bool = true

var _sprite: AnimatedSprite2D = null
var _frames_by_state: Dictionary = {}
var _warp_armed: bool = false

## --- Bike capacities (Phase 3) ---
## Riding state: the mounted solo bicycle ("" = none mounted; the
## ride MODE then decides the effective class on its own).
## Effective capacities require the ride mode's class to match the
## mounted bike's class when a bike is mounted, and require an
## actual bike mode -- capacities never apply on foot.
## Capacity model (documented; proven on synthetic maps, because
## Gen 1/3 geometry has no rails / muddy slopes / hop gaps):
## - bunny_hop (acro): stepping onto a "gap" or "hop_obstacle"
##   tile hops over it, landing on the tile directly beyond it.
## - wheelie (acro): wheelie_active is true while an acro rider
##   keeps moving; it drops on idle / dismount / mode change away
##   from acro. Engaging a rail requires an active wheelie.
## - rail_ride (acro): entering a "rail" tile requires rail_ride
##   + an active wheelie. While standing on a rail tile, movement
##   locks to the rail line's axis (the axis is read from the rail
##   neighbours); leaving along that axis is allowed. For anyone
##   else, rail tiles are solid.
## - muddy_slope_climb (mach): a "muddy_slope" tile is climbable
##   ONLY in bike_mach mode at the mach top speed (16.0 tiles/sec,
##   the top_speed capacity). On foot, walking, running, acro, or
##   any slower mode the step is refused (reason
##   "requires_mach_momentum") -- refusal, not a slide-back, is the
##   model: momentum is a gate checked before the step.
## - top_speed (mach): the existing bike_mach 16.0 tiles/sec in
##   SPEEDS; the capacity id is bound to that entry.
var current_bicycle_id: String = ""
var wheelie_active: bool = false
var rail_riding: bool = false
var last_block_reason: String = ""

## --- Rideable Pokemon mounts (Phase 3, item B) ---
## Mounted state, in the same pattern as the bicycle state above:
## current_mount_species / current_ride_mode ("" = on foot).
## While mounted, step() moves at PUWRideSystem.speed_for_mode
## for the ride mode instead of the on-foot SPEEDS table, and
## synthetic "water" / "gap" terrain is decided by the mount:
## water tiles are crossable only in a water ride mode
## (surfing / ferrying / diving), gap tiles only in an airborne
## mode (mounted_flight / carried_flight / hover_carrying).
## Badge gating for crossings lives in PUWRideSystem.
## attempt_crossing (through PUWFieldActions); the controller
## only enforces the physical terrain rule.
var current_mount_species: String = ""
var current_ride_mode: String = ""

## --- PokéMount display hook (code prep, 2026-11-23) ---
## When the mounted species has bound PokéMount art (the 7
## mounts / 11 sets in data/pokemount_art_index.json), the
## player's sprite swaps to the mount frames built by
## PUWPokeMountRigLoader for as long as the mount lasts: the
## sheets draw mount + rider as one composite sprite, exactly
## like the tandem bike frames, so the swap replaces the cast
## frames wholesale and dismount restores them. The loader
## builds its animations under this controller's own
## "<state>_<facing>" naming, so _refresh_animation() drives
## mount playback with no changes. When the mount has NO bound
## art (the 7 fetch-list mounts, or a set missing for the
## ride mode's context), the display is exactly what it was
## before this hook: the cast frames stay up and the refusal
## is recorded in mount_display() — never a substitute sprite.
## mount_gender is the mount individual's gender ("male" /
## "female" / "" unknown) as recorded on its party record;
## mount_flash is the illuminate hook point for the
## Flash-sparkle rows (luxray / lanturn sets).
var mount_gender: String = ""
var mount_flash: bool = false
var _cast_frames: SpriteFrames = null
var _mount_display: Dictionary = {}
var _mount_frames_active: bool = false

## --- Bicycle display hook (systems activation fix, 2026-11-24) ---
## Mirrors the PokéMount display hook above for bicycles. The
## bike art (PUWBikeRigFacade.solo_rig -> PUWBikeRigLoader) builds
## one "ride" cycle per cast member; until this hook existed,
## mount_bicycle() only recorded the registry id and the sprite
## kept the cast frames, so the "bike" locomotion state had no
## animation to play (frame_data.json carries no bike state for
## any cast). _apply_bike_display() adapts the ride cycle under
## this controller's own "bike" / "bike_<facing>" names so
## _refresh_animation() drives it unchanged, swaps it onto the
## sprite while a solo bicycle is mounted, and dismount restores
## the cast display. Tandem rigs keep their own co-op-locked
## path through PUWBikes / PUWBikeRigFacade and are NOT swapped
## here (mount_bicycle refuses tandems, unchanged). When the
## rig has no frames for the cast, the cast display stays up
## and the refusal is recorded in bike_display().
var _bike_display: Dictionary = {}
var _bike_frames_active: bool = false

## --- Field-action gate wiring (Worker B) ---
## Live-play context for the badge-locked field-action gate:
## the save state and party the controller should consult.
## Set through set_field_context() by live play (and by tests);
## when no context is set, movement keeps its previous
## physical-only behaviour (existing traversal / ride / bike
## suites drive the controller without a save state).
## When a context IS set:
## - a ride crossing over "water" / "gap" terrain is checked
##   through PUWFieldActions.can_perform for the crossing's
##   action (PUWRideSystem.crossing_action for the ride mode:
##   surf-class modes -> "surf", airborne modes -> "fly")
##   BEFORE the step is allowed, and a refusal sets
##   last_block_reason to the gate's reason ("badge_missing"
##   when the unlocking badge is not held -- even when a party
##   Pokemon knows the move or has the natural capability --
##   or "no_qualifying_pokemon" when nobody qualifies);
## - attempt_field_action() runs any of the 9 field actions
##   (cut / illuminate / fly / surf / strength / teleport /
##   dig / rock_smash / waterfall) through
##   PUWFieldActions.perform, the documented controller hook
##   in systems/overworld/field_actions.gd.
## The controller never reimplements the gate: every decision
## above is PUWFieldActions' own verdict.
var field_state: Dictionary = {}
var field_party: Array = []
var field_context_set: bool = false
var last_field_action: String = ""
var last_field_action_result: Dictionary = {}


## Bind the save state + party the field-action gate consults.
func set_field_context(state: Dictionary, party: Array) -> void:
	field_state = state
	field_party = party
	field_context_set = true


func clear_field_context() -> void:
	field_state = {}
	field_party = []
	field_context_set = false
	last_field_action = ""
	last_field_action_result = {}


## Run the field-action gate for one action and remember the
## verdict. Returns true when the action is allowed (or when
## no field context is set -- physical-only legacy behaviour).
## On refusal last_block_reason is the gate's reason.
func _field_gate_allows(action_id: String) -> bool:
	if not field_context_set or action_id == "":
		return true
	var result: Dictionary = PUWFieldActions.can_perform(field_state, field_party, action_id)
	last_field_action = action_id
	last_field_action_result = result
	if bool(result.get("allowed", false)):
		return true
	last_block_reason = str(result.get("reason", ""))
	return false


## The documented controller hook for field-obstacle
## interaction: attempt one of the 9 field actions through
## PUWFieldActions.perform (which records the use in the
## state's story_flags only when allowed). Returns the gate's
## own Dictionary {"allowed", "reason", "via", "species"}.
## With no field context set, returns a refusal with reason
## "no_field_context" and records nothing.
func attempt_field_action(action_id: String) -> Dictionary:
	if not field_context_set:
		var no_context: Dictionary = {"allowed": false, "reason": "no_field_context", "via": "", "species": ""}
		last_field_action = action_id
		last_field_action_result = no_context
		last_block_reason = "no_field_context"
		return no_context
	var result: Dictionary = PUWFieldActions.perform(field_state, field_party, action_id)
	last_field_action = action_id
	last_field_action_result = result
	if not bool(result.get("allowed", false)):
		last_block_reason = str(result.get("reason", ""))
	return result


## Mount a rideable Pokemon (species slug + ride mode id from
## rider_poses.json). Refused (false, nothing mounted) when the
## species is not eligible for the mode under PUWRideSystem.
## On a successful mount the PokéMount display hook runs (see
## the mount display vars above): bound art swaps onto the
## sprite, unbound mounts keep the cast display exactly as
## before. gender is the mount individual's gender from its
## party record ("male" / "female"; "" when unrecorded).
func mount_pokemon(species_slug: String, mode_id: String, gender: String = "") -> bool:
	if not PUWRideSystem.eligible_modes(species_slug).has(mode_id):
		current_mount_species = ""
		current_ride_mode = ""
		mount_gender = ""
		_mount_display = {}
		_restore_cast_display()
		return false
	current_mount_species = species_slug
	current_ride_mode = mode_id
	mount_gender = gender
	_apply_mount_display()
	_refresh_animation()
	return true


func dismount_pokemon() -> void:
	current_mount_species = ""
	current_ride_mode = ""
	mount_gender = ""
	_mount_display = {}
	_restore_cast_display()
	_refresh_animation()


## True while mounted on a rideable Pokemon.
func is_mounted() -> bool:
	return current_ride_mode != ""


## The last PokéMount display resolution for the current
## mount ({} when not mounted). Keys mirror
## PUWPokeMountRigLoader.build_mount_frames' result: status
## "loaded" means mount art is on the sprite; "not_bound" /
## "no_set_for_mode" / "no_frames" mean the cast display
## stayed up, with the reason recorded here.
func mount_display() -> Dictionary:
	return _mount_display.duplicate()


## True while PokéMount art (not cast art) is on the sprite.
func mount_art_active() -> bool:
	return _mount_frames_active


## Re-resolve the mount display in place — after live play
## changes mount_gender / mount_flash, or re-mounts in a new
## mode through mount_pokemon. No-op on foot.
func refresh_mount_display() -> void:
	if not is_mounted():
		return
	_apply_mount_display()
	_refresh_animation()


## Resolve and apply the mount display for the current mount.
## Loaded art swaps onto the sprite; anything else restores
## the cast display (the fail-safe: pre-hook behaviour).
func _apply_mount_display() -> void:
	_mount_display = PUWPokeMountRigLoader.build_mount_frames(current_mount_species, current_ride_mode, mount_gender, mount_flash)
	if str(_mount_display.get("status", "")) == "loaded":
		var mount_frames_value: Variant = _mount_display.get("frames", null)
		if mount_frames_value is SpriteFrames:
			var mount_frames: SpriteFrames = mount_frames_value
			_mount_frames_active = true
			if _sprite != null:
				_sprite.sprite_frames = mount_frames
			return
	_restore_cast_display()


## Put the cast frames back on the sprite (dismount, refused
## mount, or a mount whose art did not resolve).
func _restore_cast_display() -> void:
	_mount_frames_active = false
	if _sprite != null:
		_sprite.sprite_frames = _cast_frames


## Speed in tiles/sec while mounted (0.0 when on foot).
func mounted_speed() -> float:
	if current_ride_mode == "":
		return 0.0
	return PUWRideSystem.speed_for_mode(current_ride_mode)


## Mount a solo bicycle by registry id. Returns false (and mounts
## nothing) for tandems and unknown ids -- tandems keep their own
## co-op-locked path in PUWBikes / PUWBikeRigFacade, unchanged.
func mount_bicycle(bicycle_id: String) -> bool:
	if PUWBikes.bike_class_for(bicycle_id) == "":
		current_bicycle_id = ""
		return false
	current_bicycle_id = bicycle_id
	if not is_mounted():
		_apply_bike_display()
		_refresh_animation()
	return true


func mount_bicycle_for_cast(cast_id: String) -> bool:
	return mount_bicycle(PUWBikes.solo_bicycle_id_for(cast_id))


func dismount_bicycle() -> void:
	current_bicycle_id = ""
	wheelie_active = false
	rail_riding = false
	_bike_display = {}
	_bike_frames_active = false
	if is_mounted():
		_apply_mount_display()
	else:
		_restore_cast_display()
	_refresh_animation()


## The last bicycle display resolution for the mounted solo
## bicycle ({} when no bicycle is mounted). Keys mirror
## PUWBikeRigFacade.solo_rig's result: status "loaded" means
## bike art is on the sprite; any other status means the cast
## display stayed up, with the reason recorded here.
func bike_display() -> Dictionary:
	return _bike_display.duplicate()


## True while bicycle art (not cast art) is on the sprite.
func bike_art_active() -> bool:
	return _bike_frames_active


## Re-resolve the bicycle display in place (after a cast change
## while a bicycle is mounted). No-op with no bicycle mounted.
func refresh_bike_display() -> void:
	if current_bicycle_id == "" or is_mounted():
		return
	_apply_bike_display()
	_refresh_animation()


## Resolve and apply the bicycle display for the mounted solo
## bicycle. Loaded art swaps onto the sprite; anything else
## restores the cast display (the fail-safe: pre-hook behaviour).
func _apply_bike_display() -> void:
	_bike_display = PUWBikeRigFacade.solo_rig(cast_id)
	_bike_frames_active = false
	if str(_bike_display.get("status", "")) == "loaded":
		var bike_frames_value: Variant = _bike_display.get("frames", null)
		if bike_frames_value is SpriteFrames:
			var rig_frames: SpriteFrames = bike_frames_value
			if rig_frames.has_animation(PUWBikeRigLoader.ANIM_RIDE):
				var ride: String = PUWBikeRigLoader.ANIM_RIDE
				var adapted: SpriteFrames = SpriteFrames.new()
				for raw_name in ["bike", "bike_down", "bike_up", "bike_left", "bike_right"]:
					var anim_name: String = str(raw_name)
					adapted.add_animation(anim_name)
					adapted.set_animation_loop(anim_name, rig_frames.get_animation_loop(ride))
					adapted.set_animation_speed(anim_name, rig_frames.get_animation_speed(ride))
					for f in range(rig_frames.get_frame_count(ride)):
						adapted.add_frame(anim_name, rig_frames.get_frame_texture(ride, f), rig_frames.get_frame_duration(ride, f))
				_bike_frames_active = true
				if _sprite != null:
					_sprite.sprite_frames = adapted
				return
	_restore_cast_display()


## Class of the mounted bike ("" when none mounted).
func current_bike_class() -> String:
	if current_bicycle_id == "":
		return ""
	return PUWBikes.bike_class_for(current_bicycle_id)


## Capacities in effect RIGHT NOW for the current ride mode: empty
## unless riding a bike mode whose class matches the mounted bike
## (when one is mounted).
func current_capacities() -> Array:
	var mode_class: String = PUWBikes.class_for_mode(current_mode)
	if mode_class == "":
		return []
	var mounted_class: String = current_bike_class()
	if mounted_class != "" and mounted_class != mode_class:
		return []
	return PUWBikes.capacities_for_class(mode_class)


func has_capacity(capacity: String) -> bool:
	return current_capacities().has(capacity)


func _init() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D"
	add_child(_sprite)


## Bind the map loader this controller walks on. The loader owns the
## current map node; the controller and loader should share a parent
## (or the loader should be added to the tree before the player is
## placed) so map-local pixel coordinates line up.
func setup(map_loader: PUWMapLoader) -> void:
	loader = map_loader


## Attach cast art: builds SpriteFrames per locomotion state via
## PUWCastRigLoader.build_frames(cast_id, state). Works fine when
## the art is not merged yet — build_frames returns null frames and
## the controller simply plays nothing.
func set_cast(new_cast_id: String) -> void:
	cast_id = new_cast_id
	_frames_by_state.clear()
	if _sprite == null:
		return
	var combined: SpriteFrames = SpriteFrames.new()
	var any_frames: bool = false
	for raw_state in STATES:
		var state: String = str(raw_state)
		var built: Dictionary = PUWCastRigLoader.build_frames(cast_id, state)
		var state_frames: Variant = built.get("frames", null)
		_frames_by_state[state] = state_frames
		if state_frames is SpriteFrames:
			var sf: SpriteFrames = state_frames
			for raw_anim in sf.get_animation_names():
				var anim: String = str(raw_anim)
				if not combined.has_animation(state):
					combined.add_animation(state)
					combined.set_animation_loop(state, sf.get_animation_loop(anim))
					combined.set_animation_speed(state, CLIP_FPS.get(state, 7.5))
				for f in range(sf.get_frame_count(anim)):
					combined.add_frame(state, sf.get_frame_texture(anim, f), sf.get_frame_duration(anim, f))
					any_frames = true
	# Per-facing walk clips (QA integration 2026-11-22): when the
	# cast rig carries a directional clip (walk_down / walk_up /
	# walk_left / walk_right from the layered walk pilot), copy it
	# under its own name so _refresh_animation can play
	# "<state>_<facing>". A direction the rig does not carry (tasha
	# walk_left -- pilot left row rejected) is simply absent, and
	# playback falls back to the bare state name as before.
	for raw_dir in ["walk_down", "walk_up", "walk_left", "walk_right", "run_down", "run_up", "run_left", "run_right"]:
		var clip_name: String = str(raw_dir)
		var built_dir: Dictionary = PUWCastRigLoader.build_frames(cast_id, clip_name)
		var dir_frames: Variant = built_dir.get("frames", null)
		_frames_by_state[clip_name] = dir_frames
		if dir_frames is SpriteFrames:
			var dsf: SpriteFrames = dir_frames
			for raw_anim in dsf.get_animation_names():
				var danim: String = str(raw_anim)
				if not combined.has_animation(danim):
					combined.add_animation(danim)
					combined.set_animation_loop(danim, dsf.get_animation_loop(danim))
					combined.set_animation_speed(danim, dsf.get_animation_speed(danim))
					for f in range(dsf.get_frame_count(danim)):
						combined.add_frame(danim, dsf.get_frame_texture(danim, f), dsf.get_frame_duration(danim, f))
					any_frames = true
	_cast_frames = combined if any_frames else null
	_sprite.sprite_frames = _cast_frames
	# A cast change while mounted keeps the mount display up:
	# the mount frames re-apply over the new cast frames, and a
	# mount with no bound art falls back to the NEW cast frames.
	if is_mounted():
		_apply_mount_display()
	# A cast change while a bicycle is mounted likewise keeps
	# the (new cast's) bicycle display up.
	if current_bicycle_id != "" and not is_mounted():
		_apply_bike_display()
	_refresh_animation()


## Teleport to a tile (centre of the cell) on the current map.
## Landing on a warp tile does not trigger it (see _warp_armed).
func place_at_tile(tile: Vector2i) -> void:
	if loader == null:
		return
	wheelie_active = false
	rail_riding = loader.tile_terrain(tile) == "rail"
	last_block_reason = ""
	position = loader.tile_center_px(tile)
	_warp_armed = loader.find_warp_at_tile(tile).is_empty()
	_refresh_animation()


## Tile the player's centre is currently on.
func player_tile() -> Vector2i:
	if loader == null:
		return Vector2i(-1, -1)
	return loader.tile_at_px(position)


## Speed of a movement mode in tiles/sec. 0.0 for unknown modes.
func speed_for_mode(mode: String) -> float:
	var speed: Variant = SPEEDS.get(mode, 0.0)
	return float(speed)


## Noise level of a movement mode (unitless, from NOISE).
## -1.0 for unknown modes, so an unknown mode is never
## silently treated as silent.
func noise_for_mode(mode: String) -> float:
	var noise: Variant = NOISE.get(mode, -1.0)
	return float(noise)


## Sight-range multiplier of a movement mode (from
## DETECTION_MULT). 1.0 (neutral) for unknown modes.
func detection_mult_for_mode(mode: String) -> float:
	var mult: Variant = DETECTION_MULT.get(mode, 1.0)
	return float(mult)


## Noise level of the mode the player is currently in.
func current_noise() -> float:
	return noise_for_mode(current_mode)


## Sight-range multiplier of the mode the player is
## currently in.
func current_detection_mult() -> float:
	return detection_mult_for_mode(current_mode)


## Mode resolution with the source controller's priority
## (PUWMovementAndStealthController.resolve_state): biking
## beats sneaking, sneaking beats running / auto-run.
static func resolve_mode(is_biking: bool, bike_gear: String, is_sneaking: bool, is_running: bool, auto_run: bool) -> String:
	if is_biking:
		return "bike_mach" if bike_gear == "mach" else "bike_acro"
	if is_sneaking:
		return "sneak"
	if is_running or auto_run:
		return "run"
	return "walk"


## One movement step. input_dir is a raw input direction (any
## length; normalised internally, dominant axis wins for facing and
## for the move itself, matching grid movement). mode must be one
## of SPEEDS' keys; an unknown mode falls back to the current mode.
## Returns the tile the player is on after the step.
func step(delta: float, input_dir: Vector2, mode: String) -> Vector2i:
	if loader == null or loader.current_layer == null:
		return player_tile()
	if SPEEDS.has(mode):
		current_mode = mode
	if input_dir.length() < 0.001:
		locomotion_state = "idle"
		wheelie_active = false
		_refresh_animation()
		return player_tile()
	# Dominant-axis grid movement.
	var dir: Vector2 = Vector2.ZERO
	if absf(input_dir.x) >= absf(input_dir.y):
		dir = Vector2(signf(input_dir.x), 0.0)
	else:
		dir = Vector2(0.0, signf(input_dir.y))
	if dir.x > 0.0:
		facing = "right"
	elif dir.x < 0.0:
		facing = "left"
	elif dir.y > 0.0:
		facing = "down"
	else:
		facing = "up"
	if current_mode == "bike_acro" or current_mode == "bike_mach":
		locomotion_state = "bike"
	elif current_mode == "run":
		locomotion_state = "run"
	else:
		locomotion_state = "walk"
	# OW-anim prep (2026-11-24): in a water ride mode with no
	# bound mount art on the sprite, the player is swimming on
	# their own -- play the cast's own swim clip (frame_data
	# carries swim for every cast member) instead of walking on
	# water. When mount art IS active the mount frames (built
	# under the same "<state>_<facing>" names) keep playing.
	if is_mounted() and not _mount_frames_active and PUWRideSystem.is_water_mode(current_ride_mode):
		locomotion_state = "swim"
	if current_mode != "bike_acro":
		wheelie_active = false
	var active_speed: float = speed_for_mode(current_mode)
	if is_mounted():
		active_speed = mounted_speed()
	var distance_px: float = active_speed * float(loader.tile_size_px) * delta
	var candidate: Vector2 = position + dir * distance_px
	var candidate_tile: Vector2i = loader.tile_at_px(candidate)
	if _try_edge_crossing(candidate_tile):
		_refresh_animation()
		return player_tile()
	last_block_reason = ""
	if _try_ride_move(candidate_tile, candidate):
		_check_warp()
		_refresh_animation()
		return player_tile()
	if last_block_reason != "":
		_refresh_animation()
		return player_tile()
	if _try_capacity_move(candidate_tile, candidate, Vector2i(int(dir.x), int(dir.y))):
		_check_warp()
		_refresh_animation()
		return player_tile()
	if last_block_reason != "":
		# A capacity rule decided this step: refused, do not move.
		_refresh_animation()
		return player_tile()
	if not loader.is_solid_tile(candidate_tile):
		position = candidate
		_update_ride_state_after_move()
	else:
		last_block_reason = "solid"
	_check_warp()
	_refresh_animation()
	return player_tile()


## Ride terrain handling (Phase 3, item B). Returns true when this
## step is fully decided here (moved OR refused with
## last_block_reason set); returns false with no reason set when
## the candidate is ordinary ground (or a gap on foot / on a bike,
## where the capacity rules decide) and the normal path should run.
func _try_ride_move(candidate_tile: Vector2i, candidate_pos: Vector2) -> bool:
	var cand_terrain: String = loader.tile_terrain(candidate_tile)
	if cand_terrain == "water":
		# Field-action gate first (when a context is set): the
		# crossing action is the ride mode's crossing action
		# (surf-class), or "surf" on foot. A badge_missing /
		# no_qualifying_pokemon refusal blocks the step before
		# the physical mount rule is even considered.
		if field_context_set:
			var water_action: String = PUWRideSystem.crossing_action(current_ride_mode) if is_mounted() else "surf"
			if water_action == "":
				water_action = "surf"
			if not _field_gate_allows(water_action):
				return true
		if is_mounted() and PUWRideSystem.is_water_mode(current_ride_mode):
			position = candidate_pos
			_update_ride_state_after_move()
			return true
		# Rotom Bike water re-fit (mechanics prep F5,
		# 2026-11-24): a mounted bicycle whose rider's save
		# state holds the Rotom Bike key item re-fits for
		# water and crosses like a water mount. The surf
		# field-action gate above has already run, so the
		# badge/move rule is fully enforced before the
		# re-fit is consulted. Not a 13th bike: no registry
		# entry, the mounted bike keeps its own identity
		# and class capacities.
		if current_bicycle_id != "" and PUWBikes.water_capable(current_bicycle_id, field_state):
			position = candidate_pos
			_update_ride_state_after_move()
			return true
		last_block_reason = "requires_water_mount"
		return true
	if cand_terrain == "gap" and is_mounted():
		# Same gate for airborne crossings: the ride mode's
		# crossing action is fly-class ("fly").
		if field_context_set:
			var gap_action: String = PUWRideSystem.crossing_action(current_ride_mode)
			if gap_action == "":
				gap_action = "fly"
			if not _field_gate_allows(gap_action):
				return true
		if PUWRideSystem.is_airborne_mode(current_ride_mode):
			position = candidate_pos
			_update_ride_state_after_move()
			return true
		last_block_reason = "requires_airborne_mount"
		return true
	return false


## Capacity terrain handling. Returns true when this step is fully
## decided here (moved OR refused with last_block_reason set);
## returns false with no reason set when the candidate is ordinary
## ground and the normal collision path should run.
func _try_capacity_move(candidate_tile: Vector2i, candidate_pos: Vector2, dir_tile: Vector2i) -> bool:
	var here_tile: Vector2i = player_tile()
	var here_terrain: String = loader.tile_terrain(here_tile)
	var cand_terrain: String = loader.tile_terrain(candidate_tile)
	# Rail lock: while standing on a rail, only movement along the
	# rail line's axis is allowed, whatever the destination is.
	if here_terrain == "rail":
		rail_riding = true
		var axis_horizontal: bool = _rail_axis_horizontal(here_tile)
		var along_axis: bool = (axis_horizontal and dir_tile.y == 0) or (not axis_horizontal and dir_tile.x == 0)
		if not along_axis:
			last_block_reason = "rail_locked_to_line"
			return true
		if cand_terrain == "ground":
			position = candidate_pos
			rail_riding = false
			_update_ride_state_after_move()
			return true
		if cand_terrain == "rail":
			position = candidate_pos
			rail_riding = true
			_update_ride_state_after_move()
			return true
		last_block_reason = "rail_locked_to_line"
		return true
	if cand_terrain == "ground" or cand_terrain == "solid":
		return false
	if cand_terrain == "gap" or cand_terrain == "hop_obstacle":
		if not has_capacity(PUWBikes.CAP_BUNNY_HOP):
			last_block_reason = "requires_bunny_hop"
			return true
		var landing: Vector2i = candidate_tile + dir_tile
		if loader.tile_terrain(landing) != "ground" or loader.is_solid_tile(landing):
			last_block_reason = "hop_no_landing"
			return true
		position = loader.tile_center_px(landing)
		_update_ride_state_after_move()
		return true
	if cand_terrain == "rail":
		if not has_capacity(PUWBikes.CAP_RAIL_RIDE):
			last_block_reason = "rail_requires_acro"
			return true
		if not wheelie_active:
			last_block_reason = "rail_requires_wheelie"
			return true
		position = candidate_pos
		rail_riding = true
		_update_ride_state_after_move()
		return true
	if cand_terrain == "muddy_slope":
		var at_mach_top_speed: bool = current_mode == "bike_mach" and absf(speed_for_mode(current_mode) - 16.0) < 0.001
		if not has_capacity(PUWBikes.CAP_MUDDY_SLOPE_CLIMB) or not at_mach_top_speed:
			last_block_reason = "requires_mach_momentum"
			return true
		position = candidate_pos
		_update_ride_state_after_move()
		return true
	return false


## Rail axis at a rail tile: horizontal when a horizontal neighbour
## is also rail (or no vertical rail neighbour exists), else
## vertical.
func _rail_axis_horizontal(rail_tile: Vector2i) -> bool:
	var horiz: bool = loader.tile_terrain(rail_tile + Vector2i(1, 0)) == "rail" or loader.tile_terrain(rail_tile + Vector2i(-1, 0)) == "rail"
	var vert: bool = loader.tile_terrain(rail_tile + Vector2i(0, 1)) == "rail" or loader.tile_terrain(rail_tile + Vector2i(0, -1)) == "rail"
	if horiz and not vert:
		return true
	if vert and not horiz:
		return false
	return true


## Sustained-state upkeep after a successful move: an acro rider
## who keeps moving is in a wheelie; rail_riding tracks standing
## on a rail tile.
func _update_ride_state_after_move() -> void:
	if current_mode == "bike_acro" and has_capacity(PUWBikes.CAP_WHEELIE):
		wheelie_active = true
	else:
		wheelie_active = false
	rail_riding = loader.tile_terrain(player_tile()) == "rail"


## If the candidate tile is out of bounds and that edge has a
## connection, load the connected map and place the player at the
## entry tile. Returns true when a crossing happened.
func _try_edge_crossing(candidate_tile: Vector2i) -> bool:
	var direction: String = ""
	var exit_coord: int = 0
	var here: Vector2i = player_tile()
	if candidate_tile.x < 0:
		direction = "west"
		exit_coord = here.y
	elif candidate_tile.x >= loader.map_width_tiles:
		direction = "east"
		exit_coord = here.y
	elif candidate_tile.y < 0:
		direction = "north"
		exit_coord = here.x
	elif candidate_tile.y >= loader.map_height_tiles:
		direction = "south"
		exit_coord = here.x
	if direction == "":
		return false
	var conn: Dictionary = loader.find_connection(direction)
	if conn.is_empty():
		return false
	var dest_name: String = loader.resolve_map_name(str(conn.get("map", "")))
	if dest_name == "":
		return false
	var dest_data: Dictionary = loader.map_data_for(dest_name)
	var dest_size: Vector2i = Vector2i(int(dest_data.get("width_tiles", 0)), int(dest_data.get("height_tiles", 0)))
	if dest_size.x <= 0 or dest_size.y <= 0:
		return false
	var entry: Vector2i = PUWMapLoader.connection_entry_tile(conn, direction, exit_coord, dest_size)
	if entry.x < 0:
		return false
	if not loader.load_map(dest_name):
		return false
	place_at_tile(entry)
	map_changed.emit(loader.current_map_name, loader.current_id_const)
	return true


## Warp check after a successful move: trigger when standing on a
## warp tile and warps are armed (player has been off warp tiles
## since the last warp/spawn).
func _check_warp() -> void:
	var tile: Vector2i = player_tile()
	var warp: Dictionary = loader.find_warp_at_tile(tile)
	if warp.is_empty():
		_warp_armed = true
		return
	if not _warp_armed:
		return
	var dest_map_id: String = str(warp.get("dest_map", ""))
	var dest_name: String = loader.last_map_name if dest_map_id == PUWMapLoader.LAST_MAP else loader.resolve_map_name(dest_map_id)
	if warp_veto.is_valid() and not bool(warp_veto.call(warp, dest_name)):
		_warp_armed = false
		return
	var spawn: Vector2i = loader.execute_warp(warp)
	if spawn.x < 0:
		return
	warp_triggered.emit(warp, dest_name, spawn)
	place_at_tile(spawn)
	map_changed.emit(loader.current_map_name, loader.current_id_const)


## Animation name is "%s_%s" % [state, facing] when the bound
## SpriteFrames carry per-facing clips; falls back to the bare state
## name (the cast rig's sheets are one strip per state), and does
## nothing when no frames are bound (headless / art not merged).
func _refresh_animation() -> void:
	current_animation = "%s_%s" % [locomotion_state, facing]
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	var to_play: String = ""
	if frames.has_animation(current_animation):
		to_play = current_animation
	elif frames.has_animation(locomotion_state):
		to_play = locomotion_state
	if to_play == "":
		return
	frames.set_animation_speed(to_play, float(CLIP_FPS.get(locomotion_state, 7.5)))
	if _sprite.animation != to_play or not _sprite.is_playing():
		_sprite.play(to_play)


func _physics_process(delta: float) -> void:
	if not input_enabled or loader == null:
		return
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var mode: String = current_mode
	if current_mode != "bike_acro" and current_mode != "bike_mach":
		# Crouch-sneak is Ctrl (DESIGN CHOICE, G2 wiring: the
		# pack had no sneak input at all; this is one line to
		# rebind). Shift still runs; neither key walks.
		var sneaking: bool = Input.is_key_pressed(KEY_CTRL)
		var running: bool = Input.is_key_pressed(KEY_SHIFT)
		mode = resolve_mode(false, "", sneaking, running, false)
	step(delta, input_dir, mode)
