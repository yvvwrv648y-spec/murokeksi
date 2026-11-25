extends SceneTree
## Bike capacity tests for Pokemon Ultimate World (Phase 3, item A).
## Run: godot --headless --script res://tests/bike_capacity_tests.gd
##
## REGISTRY COMPLETION (2026-11-23): the Femboy and Futanari
## presets previously had NO bicycle_registry.json entries (they
## silently shared custom_fem_solo). The registry addendum gives
## them their own bikes -- custom_futanari_solo (acro) and
## custom_femboy_solo (mach), balancing the six solos 3 acro /
## 3 mach. This suite grew 52 -> 66: +6 data checks (the two new
## solos in the class/capacity enumeration), +2 tandem checks
## (the two new tandems carry no class/capacities), +2 API checks
## (solo_capacities_for the two new cast members), +4 mechanic
## scenarios in the existing proof style (futanari acro hops the
## gap and rides the rail; femboy mach climbs the slope and
## cannot hop the obstacle).
##
## BENCH-2 BINDING (2026-11-23): the first rider bike stacks are
## bound (bike_frame_data.json section layered_stacks_bench2):
## 6 solo base stacks + 6 tandem base stacks over the certified
## round-6 v2 chassis, rows 1-2 Neon v5 / rows 3-4 + tandem drivers
## in-house bench, B1-B7 CLOSED; all 22 QA-round-9 v3 outfit stacks
## are HELD with measured reasons (full-figure v3 layers double the
## rider over the bench bases). New assertions (+18, baseline
## 66 -> 84): the section exists, B1-B7 read closed, 6+6 base
## stacks are registered, every frame PNG of all 12 base stacks
## exists, the 22 outfit stacks are held with reasons, and all 12
## bicycle_registry entries carry art_status bound.
##
## BENCH-3 BINDING (2026-11-23): all 22 outfit stacks are now
## BOUND in the same section (kind solo_outfit, 16 full-cell
## frames each). The layers are in-house bench round-3 register
## redraws of the QA-round-9 v3 designs over the bench-2 bases
## (the held v3 full-figure layers doubled the rider over the
## re-posed bases); re-measured on the bound copies with the
## bench-2 instruments: worst overhang 0.000, worst detached far
## component 0 px, contact 8/8 side cells on all 22. The bench-2
## held-with-reasons check is replaced by: held list empty, 22
## outfit stacks registered, every outfit frame PNG exists.
## Suite grew 84 -> 107 (+23 net).
##
## SYNTHETIC MAPS: Gen 1/3 Kanto-Sevii geometry has NO rails, muddy
## slopes, or hop gaps, so every mechanic below is proven on
## synthetic maps built programmatically through
## PUWMapLoader.setup_synthetic_map() -- a plain grid whose special
## tiles are named "gap" / "hop_obstacle" / "rail" / "muddy_slope".
## These maps are test fixtures only; they are not game geometry.
##
## Documented capacity model (PUWPlayerController):
## - bunny_hop (acro): hop over a 1-tile gap / hop obstacle, landing
##   on the tile directly beyond it.
## - wheelie (acro): sustained state while an acro rider keeps
##   moving; engaging a rail requires an active wheelie.
## - rail_ride (acro): on a rail tile, movement locks to the rail
##   line's axis. Everyone else treats rail tiles as solid.
## - muddy_slope_climb (mach): climbable ONLY in bike_mach mode at
##   the mach top speed (16.0 tiles/sec, the top_speed capacity);
##   every other mode is refused with "requires_mach_momentum"
##   (refusal model -- momentum is a gate checked before the step).
## - top_speed (mach): the existing bike_mach 16.0 tiles/sec.

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


func _sorted_join(values: Array) -> String:
	var strs: Array = []
	for v: Variant in values:
		strs.append(str(v))
	strs.sort()
	return ",".join(strs)


func _registry_entry(bike_id: String) -> Dictionary:
	var data: Dictionary = PUWBikes.registry_data()
	var bikes: Array = data.get("bicycles", [])
	for entry_value: Variant in bikes:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == bike_id:
			return entry
	return {}


func _setup_world() -> void:
	_loader = PUWMapLoader.new()
	root.add_child(_loader)
	_player = PUWPlayerController.new()
	_player.input_enabled = false
	root.add_child(_player)
	_player.setup(_loader)


## Start a fresh synthetic scenario: 11x5 grid, special tiles from
## the terrain dictionary, player placed, bike mounted ("" = none).
func _scenario(terrain: Dictionary, start: Vector2i, bike_id: String) -> void:
	_loader.setup_synthetic_map(11, 5, terrain)
	_player.dismount_bicycle()
	if bike_id != "":
		_player.mount_bicycle(bike_id)
	_player.place_at_tile(start)


func _step_many(dir: Vector2, mode: String, count: int) -> void:
	for i in range(count):
		_player.step(0.05, dir, mode)


func _run() -> void:
	print("PUW bike capacity tests - starting (synthetic maps; see header).")
	_setup_world()

	# ---------- Data: classes + capacities in the registry ----------
	var expected: Dictionary = {
		"riley_solo": "acro", "tasha_solo": "mach",
		"custom_fem_solo": "acro", "custom_masc_solo": "mach",
		"custom_futanari_solo": "acro", "custom_femboy_solo": "mach",
	}
	var classes_seen: Dictionary = {}
	for bike_value: Variant in expected.keys():
		var bike_id: String = str(bike_value)
		var entry: Dictionary = _registry_entry(bike_id)
		var cls: String = str(entry.get("class", ""))
		classes_seen[cls] = true
		_check("data_" + bike_id + "_has_class", cls != "")
		_check("data_" + bike_id + "_class_assignment", cls == str(expected[bike_id]), "class=" + cls)
		var caps: Array = entry.get("capacities", [])
		_check("data_" + bike_id + "_capacities_match_class", _sorted_join(caps) == _sorted_join(PUWBikes.capacities_for_class(cls)), "caps=" + _sorted_join(caps))
	_check("data_both_classes_exist", classes_seen.has("acro") and classes_seen.has("mach"))
	var reg: Dictionary = PUWBikes.registry_data()
	_check("data_design_decision_noted", str(reg.get("bike_class_design_decision", "")).contains("riley_solo"))
	for tandem_value: Variant in ["riley_tandem", "tasha_tandem", "custom_fem_tandem", "custom_masc_tandem", "custom_femboy_tandem", "custom_futanari_tandem"]:
		var tandem_id: String = str(tandem_value)
		var tentry: Dictionary = _registry_entry(tandem_id)
		_check("data_" + tandem_id + "_no_capacities", not tentry.has("capacities") and not tentry.has("class"))

	# ---------- API: PUWBikes capacity helpers ----------
	_check("api_capacities_for_class_acro", _sorted_join(PUWBikes.capacities_for_class("acro")) == "bunny_hop,rail_ride,wheelie")
	_check("api_capacities_for_class_mach", _sorted_join(PUWBikes.capacities_for_class("mach")) == "muddy_slope_climb,top_speed")
	_check("api_solo_capacities_riley_acro", _sorted_join(PUWBikes.solo_capacities_for("riley")) == "bunny_hop,rail_ride,wheelie")
	_check("api_solo_capacities_tasha_mach", _sorted_join(PUWBikes.solo_capacities_for("tasha")) == "muddy_slope_climb,top_speed")
	_check("api_solo_capacities_futanari_acro", _sorted_join(PUWBikes.solo_capacities_for("custom_futanari")) == "bunny_hop,rail_ride,wheelie")
	_check("api_solo_capacities_femboy_mach", _sorted_join(PUWBikes.solo_capacities_for("custom_femboy")) == "muddy_slope_climb,top_speed")
	_check("api_capacities_for_mode_acro", _sorted_join(PUWBikes.capacities_for_mode(PUWBikes.MODE_SOLO_ACRO)) == "bunny_hop,rail_ride,wheelie")
	_check("api_capacities_for_mode_mach", _sorted_join(PUWBikes.capacities_for_mode(PUWBikes.MODE_SOLO_MACH)) == "muddy_slope_climb,top_speed")
	_check("api_capacities_for_mode_on_foot_empty", PUWBikes.capacities_for_mode("walk").is_empty())
	_check("api_controller_refuses_tandem_mount", _player.mount_bicycle("riley_tandem") == false and _player.current_bicycle_id == "")

	# ---------- Speeds unchanged, top_speed bound ----------
	_check("speed_bikes_acro_10_67", absf(PUWBikes.speed_for(PUWBikes.MODE_SOLO_ACRO) - 10.67) < 0.001)
	_check("speed_bikes_mach_16_0", absf(PUWBikes.speed_for(PUWBikes.MODE_SOLO_MACH) - 16.0) < 0.001)
	_check("speed_controller_acro_10_67", absf(_player.speed_for_mode("bike_acro") - 10.67) < 0.001)
	_check("speed_controller_mach_16_0_top_speed", absf(_player.speed_for_mode("bike_mach") - 16.0) < 0.001)
	_scenario({}, Vector2i(2, 2), "tasha_solo")
	_player.step(0.05, Vector2.ZERO, "bike_mach")
	_check("speed_mach_rider_exposes_top_speed", _player.has_capacity("top_speed") and _player.has_capacity("muddy_slope_climb"))
	_scenario({}, Vector2i(2, 2), "riley_solo")
	_player.step(0.05, Vector2.ZERO, "bike_acro")
	_check("speed_acro_rider_exposes_acro_capacities", _player.has_capacity("bunny_hop") and _player.has_capacity("wheelie") and _player.has_capacity("rail_ride"))

	# ---------- bunny_hop: 1-tile gap (synthetic) ----------
	var gap_terrain: Dictionary = {Vector2i(5, 2): "gap"}
	_scenario(gap_terrain, Vector2i(3, 2), "riley_solo")
	_step_many(Vector2(1, 0), "bike_acro", 30)
	_check("hop_acro_hops_gap", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))
	_scenario(gap_terrain, Vector2i(3, 2), "tasha_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("hop_mach_cannot_hop_gap", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	_check("hop_mach_block_reason", _player.last_block_reason == "requires_bunny_hop", "reason=" + _player.last_block_reason)
	_scenario(gap_terrain, Vector2i(3, 2), "")
	_step_many(Vector2(1, 0), "walk", 30)
	_check("hop_foot_cannot_hop_gap", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	# Registry completion (2026-11-23): the Futanari preset's own
	# acro bike hops the same gap.
	_scenario(gap_terrain, Vector2i(3, 2), "custom_futanari_solo")
	_step_many(Vector2(1, 0), "bike_acro", 30)
	_check("hop_futanari_acro_hops_gap", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))

	# ---------- bunny_hop: hop obstacle tile (synthetic) ----------
	var obstacle_terrain: Dictionary = {Vector2i(5, 2): "hop_obstacle"}
	_scenario(obstacle_terrain, Vector2i(3, 2), "custom_fem_solo")
	_step_many(Vector2(1, 0), "bike_acro", 30)
	_check("hop_acro_hops_obstacle", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))
	_scenario(obstacle_terrain, Vector2i(3, 2), "custom_masc_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("hop_mach_cannot_hop_obstacle", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	# Registry completion (2026-11-23): the Femboy preset's own
	# mach bike cannot hop the obstacle either.
	_scenario(obstacle_terrain, Vector2i(3, 2), "custom_femboy_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("hop_femboy_mach_cannot_hop_obstacle", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))

	# ---------- muddy_slope_climb (synthetic) ----------
	var slope_terrain: Dictionary = {Vector2i(5, 2): "muddy_slope"}
	_scenario(slope_terrain, Vector2i(3, 2), "tasha_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("slope_mach_climbs_at_top_speed", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))
	_scenario(slope_terrain, Vector2i(3, 2), "riley_solo")
	_step_many(Vector2(1, 0), "bike_acro", 30)
	_check("slope_acro_cannot_climb", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	_check("slope_acro_block_reason", _player.last_block_reason == "requires_mach_momentum", "reason=" + _player.last_block_reason)
	_scenario(slope_terrain, Vector2i(3, 2), "")
	_step_many(Vector2(1, 0), "walk", 30)
	_check("slope_foot_cannot_climb", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	# Mach MODE on an ACRO bike: class mismatch means no capacities.
	_scenario(slope_terrain, Vector2i(3, 2), "riley_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("slope_mach_mode_on_acro_bike_cannot_climb", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	# Registry completion (2026-11-23): the Femboy preset's own
	# mach bike climbs the same slope at top speed.
	_scenario(slope_terrain, Vector2i(3, 2), "custom_femboy_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("slope_femboy_mach_climbs_at_top_speed", _player.player_tile().x >= 6, "tile=" + str(_player.player_tile()))

	# ---------- wheelie + rail_ride (synthetic) ----------
	var rail_terrain: Dictionary = {Vector2i(5, 2): "rail", Vector2i(6, 2): "rail", Vector2i(7, 2): "rail", Vector2i(8, 2): "rail"}
	_scenario(rail_terrain, Vector2i(2, 2), "riley_solo")
	_step_many(Vector2(1, 0), "bike_acro", 12)
	_check("rail_acro_rides_rail_line", _player.player_tile().x >= 8, "tile=" + str(_player.player_tile()))
	_check("rail_acro_rail_riding_state", _player.rail_riding == true, "tile=" + str(_player.player_tile()))
	_check("wheelie_active_while_acro_moving", _player.wheelie_active == true)
	var rail_tile_before: Vector2i = _player.player_tile()
	_player.step(0.05, Vector2(0, -1), "bike_acro")
	_check("rail_movement_locked_to_line", _player.player_tile() == rail_tile_before and _player.last_block_reason == "rail_locked_to_line", "tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_step_many(Vector2(1, 0), "bike_acro", 30)
	_check("rail_acro_exits_along_line", _player.player_tile().x >= 9 and _player.rail_riding == false, "tile=" + str(_player.player_tile()))
	_player.step(0.05, Vector2.ZERO, "bike_acro")
	_check("wheelie_drops_when_idle", _player.wheelie_active == false)
	# Registry completion (2026-11-23): the Futanari preset's own
	# acro bike rides the same rail line.
	_scenario(rail_terrain, Vector2i(2, 2), "custom_futanari_solo")
	_step_many(Vector2(1, 0), "bike_acro", 12)
	_check("rail_futanari_acro_rides_rail_line", _player.player_tile().x >= 8 and _player.rail_riding == true, "tile=" + str(_player.player_tile()))
	# Direct rail entry with no wheelie built up is refused.
	_scenario(rail_terrain, Vector2i(4, 2), "riley_solo")
	_player.step(0.05, Vector2(1, 0), "bike_acro")
	_check("rail_entry_requires_wheelie", _player.player_tile().x == 4 and _player.last_block_reason == "rail_requires_wheelie", "tile=" + str(_player.player_tile()) + " reason=" + _player.last_block_reason)
	_scenario(rail_terrain, Vector2i(2, 2), "tasha_solo")
	_step_many(Vector2(1, 0), "bike_mach", 30)
	_check("rail_mach_treats_rail_as_solid", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))
	_scenario(rail_terrain, Vector2i(2, 2), "")
	_step_many(Vector2(1, 0), "walk", 30)
	_check("rail_foot_treats_rail_as_solid", _player.player_tile().x <= 4, "tile=" + str(_player.player_tile()))

	# ---------- Bench-2 bound stacks (bike_frame_data.json) ----------
	var fd_file: FileAccess = FileAccess.open("res://systems/transportation/bike_frame_data.json", FileAccess.READ)
	var fd_text: String = fd_file.get_as_text() if fd_file != null else ""
	if fd_file != null:
		fd_file.close()
	var fd_parsed: Variant = JSON.parse_string(fd_text)
	var frame_data: Dictionary = fd_parsed if fd_parsed is Dictionary else {}
	var bench2: Dictionary = frame_data.get("layered_stacks_bench2", {})
	_check("bench2_section_present", not bench2.is_empty())
	var b2_status: Dictionary = bench2.get("status", {})
	var all_closed: bool = true
	for b_key: Variant in ["B1", "B2", "B3", "B4", "B5", "B6", "B7"]:
		if str(b2_status.get(str(b_key), "")) != "closed":
			all_closed = false
	_check("bench2_B1_B7_closed", all_closed)
	var b2_sheets: Dictionary = bench2.get("sheets", {})
	var solo_stacks: Array = []
	var tandem_stacks: Array = []
	for sheet_key: Variant in b2_sheets.keys():
		var sheet_rec: Dictionary = b2_sheets[sheet_key]
		var kind: String = str(sheet_rec.get("kind", ""))
		if kind == "solo_base":
			solo_stacks.append(str(sheet_key))
		elif kind == "tandem_base":
			tandem_stacks.append(str(sheet_key))
	_check("bench2_solo_stacks_six", solo_stacks.size() == 6)
	_check("bench2_tandem_stacks_six", tandem_stacks.size() == 6)
	var base_stacks: Array = []
	base_stacks.append_array(solo_stacks)
	base_stacks.append_array(tandem_stacks)
	base_stacks.sort()
	for stack_key: Variant in base_stacks:
		var stack_rec: Dictionary = b2_sheets[stack_key]
		var stack_frames: Array = stack_rec.get("frames", [])
		var frames_ok: bool = stack_frames.size() == 16
		for frame_value: Variant in stack_frames:
			var frame_rec: Dictionary = frame_value
			if not FileAccess.file_exists("res://" + str(frame_rec.get("png", ""))):
				frames_ok = false
		var stem: String = str(stack_key).get_file().trim_suffix(".png")
		_check("bench2_stack_frames_" + stem, frames_ok)
	var held: Array = bench2.get("held_outfit_stacks", [])
	_check("bench3_outfit_stacks_none_held", held.is_empty())
	var outfit_stacks: Array = []
	for sheet_key: Variant in b2_sheets.keys():
		var outfit_rec: Dictionary = b2_sheets[sheet_key]
		if str(outfit_rec.get("kind", "")) == "solo_outfit":
			outfit_stacks.append(str(sheet_key))
	outfit_stacks.sort()
	_check("bench3_outfit_stacks_22_bound", outfit_stacks.size() == 22)
	for stack_key: Variant in outfit_stacks:
		var outfit_stack_rec: Dictionary = b2_sheets[stack_key]
		var outfit_frames: Array = outfit_stack_rec.get("frames", [])
		var outfit_frames_ok: bool = outfit_frames.size() == 16
		for frame_value: Variant in outfit_frames:
			var outfit_frame_rec: Dictionary = frame_value
			if not FileAccess.file_exists("res://" + str(outfit_frame_rec.get("png", ""))):
				outfit_frames_ok = false
		var outfit_stem: String = str(stack_key).get_file().trim_suffix(".png")
		_check("bench3_stack_frames_" + outfit_stem, outfit_frames_ok)
	var reg_bikes: Array = reg.get("bicycles", [])
	var art_bound: int = 0
	for bike_value: Variant in reg_bikes:
		var bike_rec: Dictionary = bike_value
		if str(bike_rec.get("art_status", "")) == "bound":
			art_bound += 1
	_check("bench2_registry_art_bound_12", art_bound == 12)

	_finish()
