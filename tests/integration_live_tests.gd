extends SceneTree
## Headless integration tests for the live wiring cluster:
## PUWMDXData (systems/pokedex/mdx_data.gd), PUWLiveWiring
## (systems/overworld/live_wiring.gd), the MDX slot mapping
## (data/mdx_mapping.json, 1,519 entries built from the sourced
## CSV by tools/build_mdx_mapping.py), the follower system with
## MDX mons, and the world clock driving scene presentation.
##
## How to run it (Godot 4.7, headless):
##   godot --headless --script res://tests/integration_live_tests.gd
## Prints one PASS or FAIL line per test, then a summary line.
## Exit code 0 means every test passed, 1 means a failure.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW integration live tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/integration_live_tests.gd")
		quit(1)
		return
	_run("test_mdx_mapping_loads_1519", Callable(self, "test_mdx_mapping_loads_1519"))
	_run("test_build_mdx_mon_mirrors_counterpart", Callable(self, "test_build_mdx_mon_mirrors_counterpart"))
	_run("test_mdx_cry_url_matches_bank", Callable(self, "test_mdx_cry_url_matches_bank"))
	_run("test_mdx_sprite_url_index_and_missing", Callable(self, "test_mdx_sprite_url_index_and_missing"))
	_run("test_mdx_voice_status", Callable(self, "test_mdx_voice_status"))
	_run("test_follower_mdx_locomotion", Callable(self, "test_follower_mdx_locomotion"))
	_run("test_live_wiring_followers_trail_and_move", Callable(self, "test_live_wiring_followers_trail_and_move"))
	_run("test_live_wiring_clock_weather_shaders", Callable(self, "test_live_wiring_clock_weather_shaders"))
	print("PUW integration live tests — done: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("Failed tests: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


# A sample PKDX Pikachu party mon in the project's mon shape
# (campaign/campaign_flow.gd build_starter shape, plus slug,
# abilities and family fields the follower/pokedex systems use).
func _sample_pikachu() -> Dictionary:
	return {
		"species_id": 25,
		"name": "Pikachu",
		"slug": "pikachu",
		"level": 5,
		"types": ["Electric"],
		"base_stats": {"hp": 35, "attack": 55, "defense": 40, "special_attack": 50, "special_defense": 50, "speed": 90},
		"abilities": ["Static"],
		"moves": [{"name": "Thunder Shock", "pp": 30, "max_pp": 30}, {"name": "Growl", "pp": 40, "max_pp": 40}],
		"family": "PKDX",
	}


# Test 1: the MDX mapping loads exactly 1,519 entries (the
# CSV's true data-row count, counted by
# tools/build_mdx_mapping.py: 1,519 ok, 0 failed), and
# counterpart_of("pikachu") returns its base MDX slot: slot 25,
# gen1_kanto.
func test_mdx_mapping_loads_1519() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var count: int = data.load_mapping()
	ok = _expect(count == 1519, "mapping must load exactly 1519 entries, got " + str(count)) and ok
	ok = _expect(data.mapping_entries().size() == 1519, "mapping_entries must hold 1519 entries") and ok
	var entry: Dictionary = data.counterpart_of("pikachu")
	ok = _expect(not entry.is_empty(), "counterpart_of(\"pikachu\") must return an entry") and ok
	ok = _expect(int(entry.get("slot", 0)) == 25, "pikachu base slot must be 25, got " + str(entry.get("slot", 0))) and ok
	ok = _expect(str(entry.get("species_slug", "")) == "pikachu", "entry slug must be pikachu") and ok
	ok = _expect(str(entry.get("generation", "")) == "gen1_kanto", "pikachu generation must be gen1_kanto, got " + str(entry.get("generation", ""))) and ok
	ok = _expect(data.counterpart_of("not-a-real-species-xyz").is_empty(), "an unknown slug must return {}") and ok
	# Pikachu carries 17 slots in the CSV (base + forms).
	ok = _expect(data.slots_for("pikachu").size() == 17, "pikachu must have 17 slots, got " + str(data.slots_for("pikachu").size())) and ok
	return ok


# Test 2: build_mdx_mon mirrors the counterpart's stats, types,
# abilities and moves exactly, sets family to "MDX", and does
# not modify the input mon.
func test_build_mdx_mon_mirrors_counterpart() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var pkdx_mon: Dictionary = _sample_pikachu()
	var mdx_mon: Dictionary = data.build_mdx_mon(pkdx_mon)
	ok = _expect(str(mdx_mon.get("family", "")) == "MDX", "MDX mon family must be MDX, got " + str(mdx_mon.get("family", ""))) and ok
	ok = _expect(str(pkdx_mon.get("family", "")) == "PKDX", "the input mon must stay PKDX") and ok
	var pkdx_stats: Dictionary = pkdx_mon.get("base_stats", {})
	var mdx_stats: Dictionary = mdx_mon.get("base_stats", {})
	ok = _expect(mdx_stats == pkdx_stats, "base_stats must mirror the counterpart exactly") and ok
	var pkdx_types: Array = pkdx_mon.get("types", [])
	var mdx_types: Array = mdx_mon.get("types", [])
	ok = _expect(mdx_types == pkdx_types, "types must mirror the counterpart exactly") and ok
	var pkdx_abilities: Array = pkdx_mon.get("abilities", [])
	var mdx_abilities: Array = mdx_mon.get("abilities", [])
	ok = _expect(mdx_abilities == pkdx_abilities, "abilities must mirror the counterpart exactly") and ok
	var pkdx_moves: Array = pkdx_mon.get("moves", [])
	var mdx_moves: Array = mdx_mon.get("moves", [])
	ok = _expect(mdx_moves == pkdx_moves, "moves must mirror the counterpart exactly") and ok
	ok = _expect(int(mdx_mon.get("species_id", 0)) == 25, "species_id must stay 25") and ok
	return ok


# Test 3: the MDX cry URL is the PKDX counterpart's cry URL
# from the cries bank (same value PokemonCryPlayer returns).
func test_mdx_cry_url_matches_bank() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var player: PokemonCryPlayer = PokemonCryPlayer.new()
	var bank_url: String = player.cry_url_for("pikachu")
	ok = _expect(not bank_url.is_empty(), "the cries bank must have a pikachu cry URL") and ok
	var mdx_url: String = data.cry_url_for("pikachu")
	ok = _expect(mdx_url == bank_url, "MDX cry URL must equal the PKDX bank URL, got " + mdx_url) and ok
	ok = _expect(data.cry_url_for("not-a-real-species-xyz").is_empty(), "an unknown species must give an empty cry URL") and ok
	player.free()
	return ok


# Test 4: sprites resolve through the URL index only: pikachu
# is in the shiny sprite index (url_index + a real URL), an
# out-of-dex slug is honestly missing.
func test_mdx_sprite_url_index_and_missing() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var found: Dictionary = data.sprite_for("pikachu", false)
	ok = _expect(str(found.get("status", "")) == "url_index", "pikachu sprite status must be url_index, got " + str(found.get("status", ""))) and ok
	ok = _expect(not str(found.get("url", "")).is_empty(), "pikachu sprite URL must be non-empty") and ok
	var shiny: Dictionary = data.sprite_for("pikachu", true)
	ok = _expect(str(shiny.get("status", "")) == "url_index", "shiny pikachu sprite status must be url_index") and ok
	var missing: Dictionary = data.sprite_for("not-a-real-species-xyz", false)
	ok = _expect(str(missing.get("status", "")) == "missing", "an out-of-dex slug must be missing, got " + str(missing.get("status", ""))) and ok
	ok = _expect(str(missing.get("url", "")) == "", "a missing sprite must have an empty URL") and ok
	return ok


# Test 5: voice status comes from the sourced voices data:
# pikachu is one of the SPECIFIED MDX voice species
# (specified_only, never recorded); bulbasaur has no MDX voice
# entry at all (not_recorded).
func test_mdx_voice_status() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	ok = _expect(data.voice_status("pikachu") == "specified_only", "pikachu voice must be specified_only, got " + data.voice_status("pikachu")) and ok
	ok = _expect(data.voice_status("pidgey") == "specified_only", "pidgey voice must be specified_only, got " + data.voice_status("pidgey")) and ok
	ok = _expect(data.voice_status("bulbasaur") == "not_recorded", "bulbasaur voice must be not_recorded, got " + data.voice_status("bulbasaur")) and ok
	return ok


# Test 6: the follower controller accepts an MDX Pikachu built
# by build_mdx_mon, and its locomotion resolves through the
# register to the MDX class "ground_biped_moemon" (the PKDX
# Pikachu resolves to "ground_agile" — family drives it).
func test_follower_mdx_locomotion() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var mdx_mon: Dictionary = data.build_mdx_mon(_sample_pikachu())
	var controller: PUWFollowerController = PUWFollowerController.new()
	var result: Dictionary = controller.select_followers([mdx_mon], [0])
	ok = _expect(bool(result.get("ok", false)), "selecting the MDX Pikachu follower must succeed") and ok
	var followers: Array = controller.get_followers()
	ok = _expect(followers.size() == 1, "exactly 1 follower must be tracked") and ok
	if followers.size() == 1:
		var record: Dictionary = followers[0]
		ok = _expect(str(record.get("family", "")) == "MDX", "follower family must be MDX") and ok
		ok = _expect(str(record.get("locomotion", "")) == "ground_biped_moemon", "MDX Pikachu locomotion must be ground_biped_moemon, got " + str(record.get("locomotion", ""))) and ok
	controller.free()
	var pkdx_controller: PUWFollowerController = PUWFollowerController.new()
	var pkdx_result: Dictionary = pkdx_controller.select_followers([_sample_pikachu()], [0])
	ok = _expect(bool(pkdx_result.get("ok", false)), "selecting the PKDX Pikachu follower must succeed") and ok
	var pkdx_followers: Array = pkdx_controller.get_followers()
	if pkdx_followers.size() == 1:
		var pkdx_record: Dictionary = pkdx_followers[0]
		ok = _expect(str(pkdx_record.get("locomotion", "")) == "ground_agile", "PKDX Pikachu locomotion must be ground_agile, got " + str(pkdx_record.get("locomotion", ""))) and ok
	else:
		ok = _expect(false, "exactly 1 PKDX follower must be tracked") and ok
	pkdx_controller.free()
	return ok


# Test 7 (live wiring, quality bar): through PUWLiveWiring,
# followers actually trail the player — as the player position
# advances, the follower positions returned by tick() change
# and lag behind the newest player position — and the MDX
# follower's locomotion class resolves in the wiring too.
func test_live_wiring_followers_trail_and_move() -> bool:
	var ok: bool = true
	var data: PUWMDXData = PUWMDXData.new()
	var mdx_mon: Dictionary = data.build_mdx_mon(_sample_pikachu())
	var wiring: PUWLiveWiring = PUWLiveWiring.new()
	root.add_child(wiring)
	var result: Dictionary = wiring.update_followers([mdx_mon], [0])
	ok = _expect(bool(result.get("ok", false)), "live wiring must accept the MDX follower") and ok
	var followers: Array = wiring.get_followers()
	ok = _expect(followers.size() == 1, "live wiring must track exactly 1 follower") and ok
	if followers.size() == 1:
		var record: Dictionary = followers[0]
		ok = _expect(str(record.get("locomotion", "")) == "ground_biped_moemon", "live wiring MDX locomotion must be ground_biped_moemon, got " + str(record.get("locomotion", ""))) and ok
	# Walk the player east in steps; the follower must move too,
	# trailing one step behind the newest player position.
	var first_positions: Array = wiring.tick(Vector2(0, 0))
	ok = _expect(first_positions.size() == 1, "tick must return 1 follower position") and ok
	var second_positions: Array = wiring.tick(Vector2(16, 0))
	var third_positions: Array = wiring.tick(Vector2(32, 0))
	if first_positions.size() == 1 and second_positions.size() == 1 and third_positions.size() == 1:
		var first_pos: Vector2 = first_positions[0]
		var second_pos: Vector2 = second_positions[0]
		var third_pos: Vector2 = third_positions[0]
		ok = _expect(first_pos == Vector2(0, 0), "follower must start at the first recorded player position, got " + str(first_pos)) and ok
		ok = _expect(second_pos == Vector2(0, 0), "follower must trail one step behind (still at 0,0), got " + str(second_pos)) and ok
		ok = _expect(third_pos == Vector2(16, 0), "follower must have moved to the previous player position (16,0), got " + str(third_pos)) and ok
		ok = _expect(third_pos != first_pos, "follower position must change as the player moves") and ok
	else:
		ok = _expect(false, "every tick must return exactly 1 follower position") and ok
	wiring.queue_free()
	return ok


# Test 8 (live wiring): PalletTown + battle scenes attach; the
# Presentation CanvasModulate color follows the clock phase
# (day vs night, forced through the clock's own API); the
# weather overlay material exists with its shader loaded and
# reacts to rain; all 5 shader materials instantiate with
# valid shaders; the battle mounts land.
func test_live_wiring_clock_weather_shaders() -> bool:
	var ok: bool = true
	var wiring: PUWLiveWiring = PUWLiveWiring.new()
	root.add_child(wiring)
	# All 5 shader materials instantiate with valid shaders.
	var mounts: Dictionary = wiring.shader_mounts()
	ok = _expect(mounts.size() == 5, "shader_mounts must hold exactly 5 materials, got " + str(mounts.size())) and ok
	for name_value in mounts.keys():
		var shader_name: String = str(name_value)
		var material_value: Variant = mounts.get(shader_name, null)
		if material_value is ShaderMaterial:
			var material: ShaderMaterial = material_value
			ok = _expect(material.shader != null, "material " + shader_name + " must have a valid shader loaded") and ok
		else:
			ok = _expect(false, "mount " + shader_name + " must be a ShaderMaterial") and ok
	# Scenes.
	var map_scene: PackedScene = load("res://maps/scenes/PalletTown.tscn") as PackedScene
	ok = _expect(map_scene != null, "PalletTown scene must load") and ok
	var battle_scene: PackedScene = load("res://scenes/battle.tscn") as PackedScene
	ok = _expect(battle_scene != null, "battle scene must load") and ok
	if map_scene == null or battle_scene == null:
		wiring.queue_free()
		return ok
	var map_root: Node = map_scene.instantiate()
	root.add_child(map_root)
	var battle_root: Node = battle_scene.instantiate()
	root.add_child(battle_root)
	var record: Dictionary = wiring.attach(map_root, battle_root)
	ok = _expect(bool(record.get("map", false)), "attach must mount the map") and ok
	ok = _expect(bool(record.get("battle", false)), "attach must mount the battle scene") and ok
	# Phase tint follows the clock: day (10:00 default) vs night
	# (21:40), forced through the clock's own from_dict API.
	ok = _expect(wiring.clock.get_time_of_day() == "day", "a fresh clock must be in day phase") and ok
	var day_color: Color = wiring.presentation_color()
	ok = _expect(day_color == PUWLiveWiring.tint_for_phase("day"), "day phase must apply the day tint, got " + str(day_color)) and ok
	wiring.clock.from_dict({"day": 1, "minute_of_day": 1300, "weather": "clear"})
	ok = _expect(wiring.clock.get_time_of_day() == "night", "minute 1300 must be night phase") and ok
	wiring.refresh()
	var night_color: Color = wiring.presentation_color()
	ok = _expect(night_color == PUWLiveWiring.tint_for_phase("night"), "night phase must apply the night tint, got " + str(night_color)) and ok
	ok = _expect(night_color != day_color, "the Presentation color must change between day and night") and ok
	# Weather overlay: material + shader exist; rain shows it.
	var overlay_material: ShaderMaterial = wiring.weather_overlay_material()
	ok = _expect(overlay_material != null, "the weather overlay material must exist") and ok
	if overlay_material != null:
		ok = _expect(overlay_material.shader != null, "the weather overlay shader must be loaded") and ok
	ok = _expect(wiring.weather_overlay_layer() != null, "the weather overlay layer must be mounted on the map") and ok
	wiring.clock.set_weather("rain")
	wiring.refresh()
	if overlay_material != null:
		ok = _expect(int(overlay_material.get_shader_parameter("mode")) == 0, "rain must set overlay mode 0") and ok
	if wiring.weather_overlay_layer() != null:
		ok = _expect(wiring.weather_overlay_layer().visible, "rain must make the weather overlay visible") and ok
	# Battle mounts: sprite placeholders carry the gimmick
	# materials and the ShaderMounts layer exists.
	var player_sprite_value: Variant = battle_root.get_node_or_null("PlayerMon/PlayerSprite")
	if player_sprite_value is CanvasItem:
		var player_sprite: CanvasItem = player_sprite_value
		ok = _expect(player_sprite.material == mounts.get("tera_glow", null), "the player sprite placeholder must carry the tera_glow material") and ok
	else:
		ok = _expect(false, "the battle scene must have PlayerMon/PlayerSprite") and ok
	var enemy_sprite_value: Variant = battle_root.get_node_or_null("EnemyMon/EnemySprite")
	if enemy_sprite_value is CanvasItem:
		var enemy_sprite: CanvasItem = enemy_sprite_value
		ok = _expect(enemy_sprite.material == mounts.get("dynamax_aura", null), "the enemy sprite placeholder must carry the dynamax_aura material") and ok
	else:
		ok = _expect(false, "the battle scene must have EnemyMon/EnemySprite") and ok
	ok = _expect(battle_root.get_node_or_null("ShaderMounts") != null, "the battle scene must gain the code-created ShaderMounts layer") and ok
	wiring.detach()
	ok = _expect(wiring.weather_overlay_layer() == null, "detach must remove the weather overlay") and ok
	wiring.queue_free()
	map_root.queue_free()
	battle_root.queue_free()
	return ok
