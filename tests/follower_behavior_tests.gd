extends SceneTree
## Headless tests for the PUW follower BEHAVIOR layer
## (PUWFollowerController behavior extension, Worker C
## 2026-11-23): runtime count 0-6, per-frame formation spacing
## on a real map, body-type locomotion (winged fence crossing,
## small-body passenger), Pickup end to end into the real
## MartShop bag, wander bounds + return, perching, autonomous
## Sweet Scent / Roar triggers, stuck recovery into the
## follower's own slot, and the tightened trigger condition
## (ACTIVE ability / KNOWN moves only -- negative controls).
##
## Run: godot --headless --script res://tests/follower_behavior_tests.gd
## Prints PASS/FAIL per test + a summary; exit 0 = all passed.
## Suite size: 19 tests (new suite, 2026-11-23; grew 10 -> 14
## with Part A teleport/co-op and Part B care/interaction
## tests the same day; grew 14 -> 19 with Refinement 5:
## emote discipline, detection/pointing, pickup delivery
## timing, and terrain domains).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []
var _found_events: Array = []
var _encounter_events: Array = []
var _repelled_count: int = 0


func _init() -> void:
	print("PUW follower behavior tests -- starting.")
	_run("test_counts_0_to_6", Callable(self, "test_counts_0_to_6"))
	_run("test_formation_walking_real_map", Callable(self, "test_formation_walking_real_map"))
	_run("test_winged_crosses_fence", Callable(self, "test_winged_crosses_fence"))
	_run("test_pickup_end_to_end", Callable(self, "test_pickup_end_to_end"))
	_run("test_wander_bounds_and_return", Callable(self, "test_wander_bounds_and_return"))
	_run("test_perching", Callable(self, "test_perching"))
	_run("test_sweet_scent_trigger", Callable(self, "test_sweet_scent_trigger"))
	_run("test_roar_cancels_pending", Callable(self, "test_roar_cancels_pending"))
	_run("test_negative_trigger_controls", Callable(self, "test_negative_trigger_controls"))
	_run("test_stuck_recovery", Callable(self, "test_stuck_recovery"))
	_run("test_teleport_carries_team", Callable(self, "test_teleport_carries_team"))
	_run("test_coop_teleport_offer", Callable(self, "test_coop_teleport_offer"))
	_run("test_care_actions", Callable(self, "test_care_actions"))
	_run("test_interactions_and_coop_sync", Callable(self, "test_interactions_and_coop_sync"))
	_run("test_emote_discipline", Callable(self, "test_emote_discipline"))
	_run("test_detection_pointing", Callable(self, "test_detection_pointing"))
	_run("test_delivery_waits_for_free_travel", Callable(self, "test_delivery_waits_for_free_travel"))
	_run("test_terrain_domains_table", Callable(self, "test_terrain_domains_table"))
	_run("test_terrain_domains_movement", Callable(self, "test_terrain_domains_movement"))
	print("PUW follower behavior tests -- done: %d passed, %d failed." % [_passed, _failed])
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


func _party6() -> Array:
	return [
		{"name": "Pikachu", "species": "Pikachu", "level": 10, "ability": "Static", "moves": ["Thunder Shock"]},
		{"name": "Pidgey", "species": "Pidgey", "level": 8, "ability": "Keen Eye", "moves": ["Gust"]},
		{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]},
		{"name": "Bulbasaur", "species": "Bulbasaur", "level": 9, "ability": "Overgrow", "moves": ["Vine Whip"]},
		{"name": "Squirtle", "species": "Squirtle", "level": 9, "ability": "Torrent", "moves": ["Water Gun"]},
		{"name": "Caterpie", "species": "Caterpie", "level": 5, "ability": "Shield Dust", "moves": ["String Shot"]},
	]


func _open_rect(loader: PUWMapLoader, w: int, h: int) -> Vector2i:
	for y in range(0, loader.map_height_tiles - h):
		for x in range(0, loader.map_width_tiles - w):
			var all_open: bool = true
			for dy in range(h):
				for dx in range(w):
					if loader.is_solid_tile(Vector2i(x + dx, y + dy)):
						all_open = false
						break
				if not all_open:
					break
			if all_open:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# 1: counts 0..6 selectable at runtime, reflected in actives.
func test_counts_0_to_6() -> bool:
	var ok: bool = true
	var c: PUWFollowerController = PUWFollowerController.new()
	var result: Dictionary = c.select_followers(_party6(), [0, 1, 2, 3, 4, 5])
	ok = _expect(bool(result.get("ok", false)), "select 6 must succeed") and ok
	for want in range(0, 7):
		var got: int = c.set_follower_count(want)
		ok = _expect(got == want, "set_follower_count(%d) must give %d, got %d" % [want, want, got]) and ok
		ok = _expect(c.get_followers().size() == want, "active followers must be %d" % want) and ok
		ok = _expect(c.behavior_followers().size() == want, "behavior records must be %d" % want) and ok
	c.free()
	return ok


# 2: formation while walking a real map (PalletTown), sampled
# EVERY frame: no overlaps beyond tolerance, no solid tiles.
# This is also the strengthened spacing proof of refinement 3.
func test_formation_walking_real_map() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	ok = _expect(loader.load_map("PalletTown"), "PalletTown must load") and ok
	var origin: Vector2i = _open_rect(loader, 16, 6)
	ok = _expect(origin.x >= 0, "a 16x6 open band must exist in PalletTown (found at (2,12) in survey)") and ok
	if origin.x < 0:
		return false
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(42)
	c.select_followers(_party6(), [0, 1, 2, 3, 4, 5])
	var ts: float = float(loader.tile_size_px)
	# Route: back-and-forth laps along the open band.
	var lane_y: float = (float(origin.y) + 2.5) * ts
	var left_x: float = (float(origin.x) + 2.5) * ts
	var right_x: float = (float(origin.x) + 13.5) * ts
	var trainer: Vector2 = Vector2(left_x, lane_y)
	var overlaps: int = 0
	var solids: int = 0
	var frames: int = 0
	var dt: float = 1.0 / 30.0
	for lap in range(6):
		var target_x: float = right_x if lap % 2 == 0 else left_x
		while absf(trainer.x - target_x) > 1.0:
			var dir_sign: float = signf(target_x - trainer.x)
			trainer.x += dir_sign * minf(4.0 * ts * dt, absf(target_x - trainer.x))
			var facing: String = "right" if dir_sign > 0.0 else "left"
			var records: Array = c.behavior_tick(dt, trainer, facing, true)
			frames += 1
			var ground: Array = []
			for r_value in records:
				var r: Dictionary = r_value
				if not bool(r.get("is_passenger", false)):
					ground.append(r)
			for a in range(ground.size()):
				var ra: Dictionary = ground[a]
				var pa: Vector2 = ra.get("pos", Vector2.ZERO)
				if loader.is_solid_tile(loader.tile_at_px(pa)):
					solids += 1
				if pa.distance_to(trainer) < 6.0:
					overlaps += 1
				for b in range(a + 1, ground.size()):
					var rb: Dictionary = ground[b]
					var pb: Vector2 = rb.get("pos", Vector2.ZERO)
					if pa.distance_to(pb) < 6.0:
						overlaps += 1
	ok = _expect(frames > 400, "route must sample many frames, got %d" % frames) and ok
	ok = _expect(overlaps == 0, "zero overlaps beyond tolerance across route, got %d" % overlaps) and ok
	ok = _expect(solids == 0, "zero solid-tile penetrations across route, got %d" % solids) and ok
	print("  formation proof: frames=%d overlaps=%d solids=%d" % [frames, overlaps, solids])
	c.free()
	loader.free()
	return ok


# 3: winged follower crosses a low fence (hop_obstacle line on
# a labeled synthetic map) the trainer walks around, rejoins.
func test_winged_crosses_fence() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {}
	for y in range(0, 8):
		terrain[Vector2i(10, y)] = "hop_obstacle"
	loader.setup_synthetic_map(20, 10, terrain, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(7)
	c.select_followers([{"name": "Pidgey", "species": "Pidgey", "level": 8, "ability": "Keen Eye", "moves": ["Gust"]}], [0])
	var ts: float = 8.0
	var trainer: Vector2 = Vector2(14.5, 4.5) * ts
	var dt: float = 1.0 / 30.0
	c.behavior_tick(dt, trainer, "right", true)
	# Lag setup (same technique as the stuck test): the follower
	# is west of the fence while its slot is east of it, so its
	# seek path crosses the fence line directly.
	c.debug_place_follower(0, Vector2(4.5, 4.5) * ts)
	var crossed_fence: bool = false
	for i in range(600):
		var records: Array = c.behavior_tick(dt, trainer, "right", true)
		if records.size() == 1:
			var r: Dictionary = records[0]
			var tile: Vector2i = loader.tile_at_px(r.get("pos", Vector2.ZERO))
			if str(loader.tile_terrain(tile)) == "hop_obstacle":
				crossed_fence = true
	var final_pos: Vector2 = Vector2.ZERO
	var settle: Array = c.behavior_followers()
	if settle.size() == 1:
		var se: Dictionary = settle[0]
		final_pos = se.get("pos", Vector2.ZERO)
	ok = _expect(final_pos.distance_to(trainer + Vector2(0.0, ts)) < ts * 1.5, "winged follower must rejoin its slot east of the fence") and ok
	ok = _expect(crossed_fence, "winged follower must cross the hop_obstacle fence line") and ok
	var final_records: Array = c.behavior_followers()
	ok = _expect(final_records.size() == 1, "one behavior record") and ok
	c.free()
	loader.free()
	return ok


# 4: Pickup end to end (seeded): Meowth, ACTIVE ability Pickup,
# level 5 (band 1-10). Found item must be in the band table and
# the real MartShop bag must gain exactly that item.
func test_pickup_end_to_end() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var shop: MartShop = MartShop.new()
	root.add_child(shop)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_bag_shop(shop)
	c.set_behavior_seed(20261123)
	_found_events.clear()
	c.follower_item_found.connect(func(idx: int, slug: String) -> void: _found_events.append(slug))
	c.select_followers([{"name": "Meowth", "species": "Meowth", "level": 5, "ability": "Pickup", "moves": ["Scratch"]}], [0])
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	var dt: float = 0.1
	var ticks: int = 0
	while _found_events.is_empty() and ticks < 3000:
		c.behavior_tick(dt, trainer, "down", false)
		ticks += 1
	ok = _expect(not _found_events.is_empty(), "Pickup follower must find an item within the seeded bound (ticks=%d)" % ticks) and ok
	if not _found_events.is_empty():
		var found: String = str(_found_events[0])
		var band_items: Array = c.pickup_items_for_level(5)
		var in_band: bool = false
		for item_value in band_items:
			if item_value is Dictionary and str((item_value as Dictionary).get("slug", "")) == found:
				in_band = true
		ok = _expect(in_band, "found item %s must be in the level 1-10 Pickup band" % found) and ok
		ok = _expect(int(shop.bag.get(found, 0)) == 1, "real bag must hold exactly 1 of %s, got %d" % [found, int(shop.bag.get(found, 0))]) and ok
		print("  pickup proof: seed=20261123 species=meowth level=5 ticks=%d item=%s bag_delta=1" % [ticks, found])
	c.free()
	shop.free()
	loader.free()
	return ok


# 5: wander bounds over a long seeded run + return on
# transition and on trainer moving away.
func test_wander_bounds_and_return() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {}
	for x in range(24):
		terrain[Vector2i(x, 0)] = "solid"
		terrain[Vector2i(x, 23)] = "solid"
	loader.setup_synthetic_map(24, 24, terrain, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(99)
	c.select_followers([{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]}], [0])
	var trainer: Vector2 = Vector2(12.5, 12.5) * 8.0
	var dt: float = 0.1
	var max_dist: float = 0.0
	var solid_hits: int = 0
	for i in range(3000):
		var records: Array = c.behavior_tick(dt, trainer, "down", false)
		if records.size() == 1:
			var r: Dictionary = records[0]
			var pos: Vector2 = r.get("pos", Vector2.ZERO)
			max_dist = maxf(max_dist, pos.distance_to(trainer) / 8.0)
			if loader.is_solid_tile(loader.tile_at_px(pos)):
				solid_hits += 1
	ok = _expect(max_dist <= 6.05, "follower must never exceed the leash/wander radius, max %f tiles" % max_dist) and ok
	ok = _expect(solid_hits == 0, "follower must never occupy a solid tile, got %d" % solid_hits) and ok
	c.notify_transition()
	var after: Array = c.behavior_followers()
	if after.size() == 1:
		var entry: Dictionary = after[0]
		ok = _expect(str(entry.get("state", "")) == "follow", "transition must return the follower to FOLLOW") and ok
	print("  wander proof: max_dist_tiles=%f solids=%d" % [max_dist, solid_hits])
	c.free()
	loader.free()
	return ok


# 6: perching -- Pidgey (1.8 kg winged) perches on the trainer;
# exits on trainer movement and on transition.
func test_perching() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(5)
	c.select_followers([{"name": "Pidgey", "species": "Pidgey", "level": 8, "ability": "Keen Eye", "moves": ["Gust"]}], [0])
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	var dt: float = 0.1
	var perched: bool = false
	for i in range(600):
		var records: Array = c.behavior_tick(dt, trainer, "down", false)
		if records.size() == 1:
			var r: Dictionary = records[0]
			if str(r.get("state", "")) == "perch_trainer" and str(r.get("animation", "")) == "perch_idle":
				perched = true
				break
	ok = _expect(perched, "small winged follower must enter perch_trainer with perch_idle") and ok
	# Exit on trainer movement.
	var moved: Vector2 = trainer + Vector2(16.0, 0.0)
	var records2: Array = c.behavior_tick(dt, moved, "right", true)
	if records2.size() == 1:
		var r2: Dictionary = records2[0]
		ok = _expect(str(r2.get("state", "")) == "follow", "trainer movement must exit perch to FOLLOW") and ok
	# Exit on transition.
	c.notify_transition()
	var after: Array = c.behavior_followers()
	if after.size() == 1:
		var entry: Dictionary = after[0]
		ok = _expect(str(entry.get("state", "")) == "follow", "transition must exit perch to FOLLOW") and ok
	c.free()
	loader.free()
	return ok


func _habitat_with_pool() -> PUWHabitatEncounters:
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	habitat.load_data()
	habitat.set_pool_override("ROUTE_1", [
		{"species": 16, "slug": "pidgey", "dex_family": "PKDX"},
		{"species": 19, "slug": "rattata", "dex_family": "PKDX"},
	])
	return habitat


# 7: seeded Sweet Scent (KNOWN move on the individual) forces
# an encounter from the local habitat pool.
func test_sweet_scent_trigger() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var habitat: PUWHabitatEncounters = _habitat_with_pool()
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_encounter_context(habitat, "ROUTE_1", 100)
	c.set_behavior_seed(777)
	_encounter_events.clear()
	c.follower_encounter_triggered.connect(func(enc: Dictionary, idx: int) -> void: _encounter_events.append(enc))
	c.select_followers([{"name": "Oddish", "species": "Oddish", "level": 10, "ability": "Chlorophyll", "moves": ["Sweet Scent", "Absorb"]}], [0])
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	var ticks: int = 0
	while _encounter_events.is_empty() and ticks < 3000:
		c.behavior_tick(0.1, trainer, "down", false)
		ticks += 1
	ok = _expect(not _encounter_events.is_empty(), "Sweet Scent must trigger within the seeded bound (ticks=%d)" % ticks) and ok
	if not _encounter_events.is_empty():
		var enc: Dictionary = _encounter_events[0]
		var slug: String = str(enc.get("species_slug", ""))
		ok = _expect(slug == "pidgey" or slug == "rattata", "encounter species must come from the local pool, got %s" % slug) and ok
		print("  sweet scent proof: seed=777 ticks=%d species=%s" % [ticks, slug])
	c.free()
	loader.free()
	return ok


# 8: seeded Roar (KNOWN move) cancels a pending encounter.
func test_roar_cancels_pending() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(31)
	_repelled_count = 0
	c.follower_encounter_repelled.connect(func(idx: int) -> void: _repelled_count += 1)
	c.select_followers([{"name": "Growlithe", "species": "Growlithe", "level": 12, "ability": "Intimidate", "moves": ["Roar", "Ember"]}], [0])
	c.set_pending_encounter({"species": 16, "slug": "pidgey"})
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	var ticks: int = 0
	while _repelled_count == 0 and ticks < 3000:
		c.behavior_tick(0.1, trainer, "down", false)
		ticks += 1
	ok = _expect(_repelled_count == 1, "Roar must repel exactly once within the seeded bound (ticks=%d)" % ticks) and ok
	ok = _expect(c.get_pending_encounter().is_empty(), "pending encounter must be cancelled") and ok
	print("  roar proof: seed=31 ticks=%d" % ticks)
	c.free()
	loader.free()
	return ok


# 9: tightened trigger condition -- negative controls:
# (a) Meowth whose ACTIVE ability is Technician (species CAN
#     have Pickup) never finds an item;
# (b) Oddish with Sweet Scent in its LEARNSET but NOT in its
#     known moves never triggers an encounter.
func test_negative_trigger_controls() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var shop: MartShop = MartShop.new()
	root.add_child(shop)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_bag_shop(shop)
	c.set_behavior_seed(4242)
	_found_events.clear()
	c.follower_item_found.connect(func(idx: int, slug: String) -> void: _found_events.append(slug))
	c.select_followers([{"name": "Meowth", "species": "Meowth", "level": 5, "ability": "Technician", "moves": ["Scratch"]}], [0])
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	for i in range(2000):
		c.behavior_tick(0.1, trainer, "down", false)
	ok = _expect(_found_events.is_empty(), "Technician Meowth must never trigger Pickup") and ok
	ok = _expect(shop.bag.is_empty(), "bag must stay empty for the negative ability control") and ok
	c.free()
	# (b) learnset-only move.
	var habitat: PUWHabitatEncounters = _habitat_with_pool()
	var c2: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c2)
	c2.set_behavior_loader(loader)
	c2.set_encounter_context(habitat, "ROUTE_1", 100)
	c2.set_behavior_seed(4243)
	_encounter_events.clear()
	c2.follower_encounter_triggered.connect(func(enc: Dictionary, idx: int) -> void: _encounter_events.append(enc))
	c2.select_followers([{"name": "Oddish", "species": "Oddish", "level": 10, "ability": "Chlorophyll", "moves": ["Absorb", "Tackle"]}], [0])
	for i in range(2000):
		c2.behavior_tick(0.1, trainer, "down", false)
	ok = _expect(_encounter_events.is_empty(), "learnset-only Sweet Scent must never trigger") and ok
	c2.free()
	shop.free()
	loader.free()
	return ok


# 10: stuck recovery -- follower walled into a solid-enclosed
# pocket on a labeled synthetic map teleports INTO ITS OWN
# SLOT after STUCK_SECONDS, landing clean.
func test_stuck_recovery() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {}
	# Enclosed pocket around tile (2,2).
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				terrain[Vector2i(2 + dx, 2 + dy)] = "solid"
	loader.setup_synthetic_map(20, 12, terrain, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(11)
	c.select_followers([
		{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]},
		{"name": "Pikachu", "species": "Pikachu", "level": 10, "ability": "Static", "moves": ["Thunder Shock"]},
	], [0, 1])
	var trainer: Vector2 = Vector2(12.5, 6.5) * 8.0
	var dt: float = 0.1
	c.behavior_tick(dt, trainer, "down", true)
	c.debug_place_follower(0, Vector2(2.5, 2.5) * 8.0)
	var recovered: bool = false
	for i in range(600):
		var records: Array = c.behavior_tick(dt, trainer, "down", true)
		if records.size() == 2:
			var r0: Dictionary = records[0]
			var p0: Vector2 = r0.get("pos", Vector2.ZERO)
			var slot0: Vector2 = trainer + Vector2(0.0, 8.0)
			if p0.distance_to(slot0) < 1.0 and not loader.is_solid_tile(loader.tile_at_px(p0)):
				recovered = true
				break
	ok = _expect(recovered, "stuck follower must recover into its own slot") and ok
	print("  stuck proof: recovered=%s stuck_seconds=%f" % [str(recovered), PUWFollowerController.STUCK_SECONDS])
	c.free()
	loader.free()
	return ok


# 11 (Part A): solo teleport via the field-action perform path
# carries all 6 followers; they land in slots, no overlap, no
# solid penetration -- including with one destination slot
# deliberately blocked (fallback placement, no clip).
func test_teleport_carries_team() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {}
	# Block the tile of slot 3 (trainer + (0,2)) at the first
	# destination: trainer tile (10,10) -> slot3 tile (10,12).
	terrain[Vector2i(10, 12)] = "solid"
	loader.setup_synthetic_map(24, 24, terrain, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(3)
	c.select_followers(_party6(), [0, 1, 2, 3, 4, 5])
	var state: Dictionary = {"badges": [], "story_flags": {}, "bag": {}}
	var badge: Dictionary = PUWFieldActions.required_badge("teleport")
	GymProgression.award_badge(state, str(badge.get("gym_id", "")))
	var party: Array = [{"species_id": 0, "name": "abra", "level": 20, "moves": [{"name": "teleport", "pp": 10, "max_pp": 10}]}]
	var dest: Vector2 = Vector2(10.5, 10.5) * 8.0
	var result: Dictionary = PUWFieldActions.perform_transport(state, party, "teleport", c, dest, "down")
	ok = _expect(bool(result.get("allowed", false)), "teleport must be allowed with badge + Abra") and ok
	ok = _expect(int(result.get("followers_arrived", 0)) == 6, "all 6 followers must arrive, got %d" % int(result.get("followers_arrived", 0))) and ok
	var records: Array = c.behavior_followers()
	var ground: Array = []
	for r_value in records:
		var r: Dictionary = r_value
		if not bool(r.get("is_passenger", false)):
			ground.append(r)
	for a in range(ground.size()):
		var ra: Dictionary = ground[a]
		var pa: Vector2 = ra.get("pos", Vector2.ZERO)
		ok = _expect(not loader.is_solid_tile(loader.tile_at_px(pa)), "arrived follower %d must not be in a solid tile" % a) and ok
		ok = _expect(pa.distance_to(dest) >= 6.0, "arrived follower %d must not overlap the trainer" % a) and ok
		for b in range(a + 1, ground.size()):
			var rb: Dictionary = ground[b]
			var pb: Vector2 = rb.get("pos", Vector2.ZERO)
			ok = _expect(pa.distance_to(pb) >= 6.0, "arrived followers %d/%d must not overlap" % [a, b]) and ok
	# Slot 3's own slot was blocked: its follower must be at a
	# fallback position (not its slot, not solid, not stacked).
	if ground.size() == 5:
		var r3: Dictionary = ground[3]
		var p3: Vector2 = r3.get("pos", Vector2.ZERO)
		ok = _expect(p3 != dest + Vector2(0.0, 16.0), "blocked-slot follower must use fallback placement, not its blocked slot") and ok
	c.free()
	loader.free()
	return ok


# 12 (Part A): co-op teleport offer flow -- offer sent, accept
# brings the second player + their followers, decline leaves
# them in place.
func test_coop_teleport_offer() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(24, 24, {}, 8)
	var coop: PUWCoopNetworkManager = PUWCoopNetworkManager.new()
	root.add_child(coop)
	var c2: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c2)
	c2.set_behavior_loader(loader)
	c2.select_followers([{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]}], [0])
	var home: Vector2 = Vector2(4.5, 4.5) * 8.0
	c2.behavior_tick(0.1, home, "down", true)
	# Decline path: offer -> decline -> nobody moves.
	var offer: Dictionary = coop.offer_teleport(1, 2, "PalletTown", Vector3(20.0, 0.0, 20.0))
	ok = _expect(str(offer.get("status", "")) == "awaiting_choice", "offer must await the other player's choice") and ok
	var declined: Dictionary = coop.respond_teleport_offer(2, false)
	ok = _expect(bool(declined.get("ok", false)) and not bool(declined.get("travel", true)), "decline must leave the peer in place") and ok
	var stayed: Array = c2.behavior_followers()
	if stayed.size() == 1:
		var se: Dictionary = stayed[0]
		var sp: Vector2 = se.get("pos", Vector2.ZERO)
		ok = _expect(sp.distance_to(home) < 24.0, "declining peer's follower must stay near home") and ok
	# Accept path: offer -> accept -> peer's team transports.
	coop.offer_teleport(1, 2, "PalletTown", Vector3(20.0, 0.0, 20.0))
	var accepted: Dictionary = coop.respond_teleport_offer(2, true)
	ok = _expect(bool(accepted.get("travel", false)), "accept must mark the peer to travel") and ok
	var dest: Vector2 = Vector2(18.5, 18.5) * 8.0
	c2.transport_followers_to(dest, "down")
	var arrived: Array = c2.behavior_followers()
	if arrived.size() == 1:
		var ae: Dictionary = arrived[0]
		var ap: Vector2 = ae.get("pos", Vector2.ZERO)
		ok = _expect(ap.distance_to(dest + Vector2(0.0, 8.0)) < 1.0, "accepting peer's follower must arrive in its slot") and ok
	ok = _expect(coop.teleport_message_log.size() == 4, "offer/decline/offer/accept messages must be logged, got %d" % coop.teleport_message_log.size()) and ok
	c2.free()
	coop.free()
	loader.free()
	return ok


# 13 (Part B): care actions -- exact friendship deltas on the
# individual, treat consumes the real bag item and refuses at
# 0, groom cooldown blocks then allows.
func test_care_actions() -> bool:
	var ok: bool = true
	var care: PUWFollowerCare = PUWFollowerCare.new()
	var mon: Dictionary = {"name": "Eevee", "species": "Eevee", "friendship": 100}
	var talk_result: Dictionary = care.talk(mon, 0.0)
	ok = _expect(bool(talk_result.get("ok", false)) and int(mon.get("friendship", 0)) == 100 + PUWFollowerCare.TALK_GAIN, "talk must add exactly TALK_GAIN") and ok
	var groom_result: Dictionary = care.groom(mon, 0.0)
	ok = _expect(bool(groom_result.get("ok", false)) and int(mon.get("friendship", 0)) == 100 + PUWFollowerCare.TALK_GAIN + PUWFollowerCare.GROOM_GAIN, "groom must add exactly GROOM_GAIN") and ok
	var groom_again: Dictionary = care.groom(mon, 10.0)
	ok = _expect(not bool(groom_again.get("ok", true)) and str(groom_again.get("reason", "")) == "cooldown", "second groom inside the window must be blocked") and ok
	var groom_later: Dictionary = care.groom(mon, PUWFollowerCare.GROOM_COOLDOWN_SECONDS + 1.0)
	ok = _expect(bool(groom_later.get("ok", false)), "groom after the cooldown must be allowed") and ok
	var shop: MartShop = MartShop.new()
	root.add_child(shop)
	shop.bag["oran-berry"] = 1
	var before: int = int(mon.get("friendship", 0))
	var treat_result: Dictionary = care.treat(mon, shop, "oran-berry")
	ok = _expect(bool(treat_result.get("ok", false)) and int(mon.get("friendship", 0)) == before + PUWFollowerCare.FEED_GAIN, "treat must add exactly FEED_GAIN") and ok
	ok = _expect(int(shop.bag.get("oran-berry", 0)) == 0, "treat must decrement the bag count by exactly 1") and ok
	var refused: Dictionary = care.treat(mon, shop, "oran-berry")
	ok = _expect(not bool(refused.get("ok", true)) and str(refused.get("reason", "")) == "no_item", "treat at 0 must refuse honestly") and ok
	ok = _expect(int(mon.get("friendship", 0)) == before + PUWFollowerCare.FEED_GAIN, "refused treat must grant nothing") and ok
	shop.free()
	return ok


# 14 (Part B): seeded autonomous interaction produces an event
# with an emote; co-op sync state carries BOTH teams' followers.
func test_interactions_and_coop_sync() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var care: PUWFollowerCare = PUWFollowerCare.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var event: Dictionary = {}
	for i in range(2000):
		event = care.tick_interaction(4, rng)
		if not event.is_empty():
			break
	ok = _expect(not event.is_empty(), "a seeded interaction event must occur") and ok
	if not event.is_empty():
		ok = _expect(str(event.get("emote", "")) == PUWFollowerCare.emote_for(str(event.get("kind", ""))), "interaction must carry the emote table's glyph for its kind") and ok
		print("  interaction proof: kind=%s emote=%s a=%d b=%d" % [str(event.get("kind", "")), str(event.get("emote", "")), int(event.get("a", -1)), int(event.get("b", -1))])
	var c1: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c1)
	c1.set_behavior_loader(loader)
	c1.select_followers(_party6(), [0, 1, 2])
	var c2: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c2)
	c2.set_behavior_loader(loader)
	c2.select_followers([{"name": "Meowth", "species": "Meowth", "level": 5, "ability": "Pickup", "moves": ["Scratch"]}], [0])
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	c1.behavior_tick(0.1, trainer, "down", true)
	c2.behavior_tick(0.1, trainer, "down", true)
	var coop: PUWCoopNetworkManager = PUWCoopNetworkManager.new()
	root.add_child(coop)
	coop.apply_remote_follower_state(2, c2.coop_sync_state())
	var mine: Array = c1.coop_sync_state()
	var theirs: Array = coop.get_remote_follower_state(2)
	ok = _expect(mine.size() == 3, "local sync state must carry 3 followers") and ok
	ok = _expect(theirs.size() == 1 and str((theirs[0] as Dictionary).get("slug", "")) == "meowth", "remote sync state must carry the other player's follower set") and ok
	c1.free()
	c2.free()
	coop.free()
	loader.free()
	return ok


# 15 (Refinement 5a): emote discipline -- a seeded idle+wander
# period produces ZERO emotes; one interaction emote shows,
# expires after EMOTE_TTL_SECONDS; the concurrent cap holds
# under a burst of forced events.
func test_emote_discipline() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(24, 24, {}, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(1234)
	c.select_followers(_party6(), [0, 1, 2, 3, 4, 5])
	var trainer: Vector2 = Vector2(12.5, 12.5) * 8.0
	var emotes_seen: int = 0
	for i in range(1200):
		var records: Array = c.behavior_tick(0.1, trainer, "down", false)
		for r_value in records:
			var r: Dictionary = r_value
			if str(r.get("emote", "")) != "":
				emotes_seen += 1
	ok = _expect(emotes_seen == 0, "idle/wander must produce zero emotes, got %d" % emotes_seen) and ok
	ok = _expect(c.active_emote_count() == 0, "no active emotes after idle period") and ok
	ok = _expect(c.show_emote(0, "?", "interaction"), "interaction emote must be accepted") and ok
	ok = _expect(c.active_emote_count() == 1, "exactly one active emote after one interaction") and ok
	for i in range(30):
		c.behavior_tick(0.1, trainer, "down", false)
	ok = _expect(c.active_emote_count() == 0, "emote must expire after its TTL (%f s)" % PUWFollowerController.EMOTE_TTL_SECONDS) and ok
	# Burst: 6 forced events, cap is EMOTE_MAX_CONCURRENT.
	for i in range(6):
		c.show_emote(i, "!", "interaction")
	ok = _expect(c.active_emote_count() == PUWFollowerController.EMOTE_MAX_CONCURRENT, "burst must be capped at %d, got %d" % [PUWFollowerController.EMOTE_MAX_CONCURRENT, c.active_emote_count()]) and ok
	ok = _expect(not c.show_emote(0, "x", "idle"), "a non-event source must never produce an emote") and ok
	print("  emote proof: idle_emotes=%d ttl=%f cap=%d" % [emotes_seen, PUWFollowerController.EMOTE_TTL_SECONDS, PUWFollowerController.EMOTE_MAX_CONCURRENT])
	c.free()
	loader.free()
	return ok


# 16 (Refinement 5b): detection + pointing with SEEDED points
# (labeled: map JSONs carry no hidden-item points, so the point
# is seeded on a synthetic map -- not claimed as map data).
# Growlithe smells (odorsleuth in its real learnset): exactly
# one responder of six, beside -- never on -- the point, facing it.
# Caterpie has no plausible sense for a hidden item: no response.
func test_detection_pointing() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(24, 24, {}, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(55)
	var party: Array = _party6()
	party.append({"name": "Growlithe", "species": "Growlithe", "level": 12, "ability": "Intimidate", "moves": ["Ember"]})
	# Use a 6-follower party that includes Growlithe at index 0.
	var party6b: Array = [party[6], party[0], party[1], party[2], party[3], party[4]]
	c.select_followers(party6b, [0, 1, 2, 3, 4, 5])
	var senses: Array = c.senses_for("growlithe", "Intimidate")
	ok = _expect(senses.has("smell"), "growlithe must have the smell sense (odorsleuth learnset), got %s" % str(senses)) and ok
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	c.behavior_tick(0.1, trainer, "down", true)
	var point_pos: Vector2 = Vector2(11.5, 8.5) * 8.0
	c.set_points_of_interest([{"id": "seeded-hidden-1", "kind": "hidden_item", "pos": point_pos}])
	var responders: int = 0
	var responder_pos: Vector2 = Vector2.ZERO
	var responder_facing: Vector2 = Vector2.ZERO
	for i in range(600):
		var records: Array = c.behavior_tick(0.1, trainer, "down", false)
		responders = 0
		for r_value in records:
			var r: Dictionary = r_value
			if str(r.get("point_id", "")) == "seeded-hidden-1":
				responders += 1
				responder_pos = r.get("pos", Vector2.ZERO)
				responder_facing = r.get("facing_dir", Vector2.ZERO)
		if responders == 1 and responder_pos.distance_to(point_pos) <= 9.0 and responder_pos.distance_to(point_pos) > 4.0:
			break
	ok = _expect(responders == 1, "exactly one responder of six for one point, got %d" % responders) and ok
	var responder_tile: Vector2i = loader.tile_at_px(responder_pos)
	var point_tile: Vector2i = loader.tile_at_px(point_pos)
	ok = _expect(responder_tile != point_tile, "responder must never stand on the point tile") and ok
	ok = _expect(responder_facing.x > 0.5, "responder must face the point (east), facing=%s" % str(responder_facing)) and ok
	print("  detection proof: responders=%d responder_tile=%s point_tile=%s facing=%s" % [responders, str(responder_tile), str(point_tile), str(responder_facing)])
	c.free()
	# No plausible sense: Caterpie alone, same seeded point.
	var c2: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c2)
	c2.set_behavior_loader(loader)
	c2.set_behavior_seed(56)
	c2.select_followers([{"name": "Caterpie", "species": "Caterpie", "level": 5, "ability": "Shield Dust", "moves": ["String Shot"]}], [0])
	c2.behavior_tick(0.1, trainer, "down", true)
	c2.set_points_of_interest([{"id": "seeded-hidden-1", "kind": "hidden_item", "pos": point_pos}])
	var any_response: int = 0
	for i in range(600):
		var records2: Array = c2.behavior_tick(0.1, trainer, "down", false)
		for r_value in records2:
			var r: Dictionary = r_value
			if str(r.get("point_id", "")) != "":
				any_response += 1
	ok = _expect(any_response == 0, "a follower with no plausible sense must never respond, got %d" % any_response) and ok
	c2.free()
	loader.free()
	return ok


# 17 (Refinement 5c): pickup delivery timing -- a find while a
# scripted battle state is active changes NO bag and fires NO
# notice; clearing the state completes delivery exactly once.
func test_delivery_waits_for_free_travel() -> bool:
	var ok: bool = true
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	loader.setup_synthetic_map(16, 16, {}, 8)
	var shop: MartShop = MartShop.new()
	root.add_child(shop)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_bag_shop(shop)
	c.set_behavior_seed(20261123)
	_found_events.clear()
	c.follower_item_found.connect(func(idx: int, slug: String) -> void: _found_events.append(slug))
	c.select_followers([{"name": "Meowth", "species": "Meowth", "level": 5, "ability": "Pickup", "moves": ["Scratch"]}], [0])
	c.set_world_busy(true, "scripted_battle_test")
	var trainer: Vector2 = Vector2(8.5, 8.5) * 8.0
	var ticks: int = 0
	# Run until the follower is carrying a pending delivery (or bound).
	while ticks < 3000:
		c.behavior_tick(0.1, trainer, "down", false)
		ticks += 1
		var beh: Array = c.behavior_followers()
		if beh.size() == 1 and str((beh[0] as Dictionary).get("pending_item", "")) != "":
			break
	var beh2: Array = c.behavior_followers()
	ok = _expect(beh2.size() == 1 and str((beh2[0] as Dictionary).get("pending_item", "")) != "", "a find must be pending delivery during the busy state (ticks=%d)" % ticks) and ok
	# Keep ticking while busy: no bag change, no notice, ever.
	for i in range(300):
		c.behavior_tick(0.1, trainer, "down", false)
	ok = _expect(shop.bag.is_empty(), "bag must not change while busy, got %s" % str(shop.bag)) and ok
	ok = _expect(_found_events.is_empty(), "no notice may fire while busy") and ok
	c.set_world_busy(false)
	for i in range(300):
		c.behavior_tick(0.1, trainer, "down", false)
		if not _found_events.is_empty():
			break
	ok = _expect(_found_events.size() == 1, "delivery notice must fire exactly once after free travel resumes, got %d" % _found_events.size()) and ok
	if _found_events.size() == 1:
		var item: String = str(_found_events[0])
		ok = _expect(shop.count_item(item) == 1, "bag must hold exactly 1 of the delivered item %s" % item) and ok
		print("  delivery proof: item=%s busy_ticks_blocked=300 bag_delta=1 notices=1" % item)
	c.free()
	shop.free()
	loader.free()
	return ok


# 18 (Refinement 5d): the generated domain table covers every
# followable species in the species data, deep_dive is a strict
# subset of water_surface, and spot domains match the derivation.
func test_terrain_domains_table() -> bool:
	var ok: bool = true
	var c: PUWFollowerController = PUWFollowerController.new()
	var table_size: int = c.domains_table_size()
	var sets_text: String = FileAccess.get_file_as_string("res://data/competitive_sets.json")
	var sets_value: Variant = JSON.parse_string(sets_text)
	var species_count: int = 0
	if sets_value is Dictionary:
		var sets: Dictionary = sets_value
		var species_value: Variant = sets.get("species", {})
		if species_value is Dictionary:
			species_count = (species_value as Dictionary).size()
	ok = _expect(table_size >= species_count and species_count > 1000, "domain table must cover every species in competitive_sets (%d), table=%d" % [species_count, table_size]) and ok
	ok = _expect(c.domains_for("rattata") == ["land"], "rattata must be land-only, got %s" % str(c.domains_for("rattata"))) and ok
	ok = _expect(not c.domains_for("tentacool").has("land"), "tentacool (sea habitat) must have no land domain") and ok
	ok = _expect(c.domains_for("tentacool").has("deep_dive") and c.domains_for("tentacool").has("water_surface"), "tentacool must dive (real Dive learnset)") and ok
	ok = _expect(c.domains_for("magikarp").has("water_surface") and not c.domains_for("magikarp").has("deep_dive"), "magikarp must be surface-only (no Dive in learnset)") and ok
	ok = _expect(c.domains_for("pidgey").has("air"), "pidgey must have the air domain") and ok
	# Strict subset across the whole generated table.
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://systems/followers/follower_domains.json"))
	var violations: int = 0
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var species_value: Variant = parsed.get("species", {})
		if species_value is Dictionary:
			var species: Dictionary = species_value
			for slug_value in species.keys():
				var entry_value: Variant = species[slug_value]
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					var domains_value: Variant = entry.get("domains", [])
					if domains_value is Array:
						var domains: Array = domains_value
						if domains.has("deep_dive") and not domains.has("water_surface"):
							violations += 1
	ok = _expect(violations == 0, "deep_dive must be a strict subset of water_surface, violations=%d" % violations) and ok
	print("  domains proof: species_data=%d table=%d subset_violations=%d" % [species_count, table_size, violations])
	c.free()
	return ok


# 19 (Refinement 5d): scripted routes on labeled synthetic maps --
# a land follower stops at water's edge; a surface-only water
# follower never enters the labeled deep_water dive zone; a
# non-flyer never takes the air path over a gap a flyer crosses.
func test_terrain_domains_movement() -> bool:
	var ok: bool = true
	# Land follower vs water.
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {}
	for y in range(0, 10):
		for x in range(10, 20):
			terrain[Vector2i(x, y)] = "water"
	loader.setup_synthetic_map(20, 10, terrain, 8)
	var c: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c)
	c.set_behavior_loader(loader)
	c.set_behavior_seed(21)
	c.select_followers([{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]}], [0])
	var trainer: Vector2 = Vector2(15.5, 4.5) * 8.0
	c.behavior_tick(0.1, trainer, "right", true)
	c.debug_place_follower(0, Vector2(4.5, 4.5) * 8.0)
	var entered_water: int = 0
	for i in range(300):
		var records: Array = c.behavior_tick(0.1, trainer, "right", true)
		if records.size() == 1:
			var r: Dictionary = records[0]
			if str(loader.tile_terrain(loader.tile_at_px(r.get("pos", Vector2.ZERO)))) == "water":
				entered_water += 1
	ok = _expect(entered_water == 0, "land-only follower must never enter water, got %d frames" % entered_water) and ok
	c.free()
	# Surface-only water follower vs the labeled dive zone.
	var terrain2: Dictionary = {}
	for y in range(0, 10):
		for x in range(0, 10):
			terrain2[Vector2i(x, y)] = "water"
		for x in range(10, 20):
			terrain2[Vector2i(x, y)] = "deep_water"
	loader.setup_synthetic_map(20, 10, terrain2, 8)
	var c2: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c2)
	c2.set_behavior_loader(loader)
	c2.set_behavior_seed(22)
	c2.select_followers([{"name": "Magikarp", "species": "Magikarp", "level": 7, "ability": "Swift Swim", "moves": ["Splash"]}], [0])
	var trainer2: Vector2 = Vector2(15.5, 4.5) * 8.0
	c2.behavior_tick(0.1, trainer2, "right", true)
	c2.debug_place_follower(0, Vector2(4.5, 4.5) * 8.0)
	var entered_deep: int = 0
	for i in range(300):
		var records2: Array = c2.behavior_tick(0.1, trainer2, "right", true)
		if records2.size() == 1:
			var r2: Dictionary = records2[0]
			if str(loader.tile_terrain(loader.tile_at_px(r2.get("pos", Vector2.ZERO)))) == "deep_water":
				entered_deep += 1
	ok = _expect(entered_deep == 0, "surface-only follower must never enter the dive zone, got %d frames" % entered_deep) and ok
	c2.free()
	# Non-flyer vs gap line; flyer crosses (air domain).
	var terrain3: Dictionary = {}
	for y in range(0, 8):
		terrain3[Vector2i(10, y)] = "gap"
	loader.setup_synthetic_map(20, 10, terrain3, 8)
	var c3: PUWFollowerController = PUWFollowerController.new()
	root.add_child(c3)
	c3.set_behavior_loader(loader)
	c3.set_behavior_seed(23)
	c3.select_followers([
		{"name": "Rattata", "species": "Rattata", "level": 7, "ability": "Run Away", "moves": ["Tackle"]},
		{"name": "Pidgey", "species": "Pidgey", "level": 8, "ability": "Keen Eye", "moves": ["Gust"]},
	], [0, 1])
	var trainer3: Vector2 = Vector2(14.5, 4.5) * 8.0
	c3.behavior_tick(0.1, trainer3, "right", true)
	c3.debug_place_follower(0, Vector2(4.5, 4.5) * 8.0)
	c3.debug_place_follower(1, Vector2(4.5, 4.5) * 8.0)
	var rattata_on_gap: bool = false
	var pidgey_on_gap: bool = false
	for i in range(600):
		var records3: Array = c3.behavior_tick(0.1, trainer3, "right", true)
		if records3.size() == 2:
			var r0: Dictionary = records3[0]
			var p0: Vector2 = r0.get("pos", Vector2.ZERO)
			if str(loader.tile_terrain(loader.tile_at_px(p0))) == "gap":
				rattata_on_gap = true
			var r1: Dictionary = records3[1]
			var p1: Vector2 = r1.get("pos", Vector2.ZERO)
			if str(loader.tile_terrain(loader.tile_at_px(p1))) == "gap":
				pidgey_on_gap = true
	# Note: the stuck-recovery teleport may legitimately place
	# Rattata in its slot east of the gap after STUCK_SECONDS
	# (Refinement 3 rule) -- the domain rule proven here is that
	# it never TAKES THE AIR PATH: it never occupies a gap tile.
	ok = _expect(not rattata_on_gap, "non-flyer must never take the air path over the gap (never occupy a gap tile)") and ok
	ok = _expect(pidgey_on_gap, "flyer must cross over the gap line (air domain)") and ok
	print("  terrain proof: water_frames=%d deep_frames=%d rattata_on_gap=%s pidgey_on_gap=%s" % [entered_water, entered_deep, str(rattata_on_gap), str(pidgey_on_gap)])
	c3.free()
	loader.free()
	return ok
