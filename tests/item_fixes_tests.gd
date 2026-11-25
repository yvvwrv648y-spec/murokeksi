extends SceneTree
## Kanto item fixes — proof suite (code_prep_kanto_item_fixes).
## Runs on a copy of the code_prep_kanto_items harness (bound
## PUWItemRegistry + PUWLiveBag + MartShop + PUWSaveManager,
## unmodified) plus the dialogue prep's patched PUWSpawner, the
## input_menus PUWInputInteraction base, and this prep's patched
## files + extracted data.
##
##   godot --headless --script res://tests/item_fixes_tests.gd
##
## Checks (fixes F1-F6 + use gates):
## 1. Walk-up pickup: A-button seam grants the Route 2 Moon
##    Stone through PUWLiveBag, generates the source-format
##    message, sets the once-flag; the flag + bag survive a
##    real PUWSaveManager round trip; the spawned node despawns
##    on the loaded state; a second interact grants nothing.
##    The spawner-node path collects the HP Up ball.
## 2. Every one of the 60 distinct bound Kanto pickup item
##    constants
##    (audit fixture) resolves through PUWItemResolve — the
##    audit's 29 unresolved constants included.
## 3. Gen-1 TM alias: TM_WATER_GUN resolves BY MOVE to the
##    registry TM whose effect annotates Gen I: Water Gun (and
##    NOT to a number-joined entry); all 55 alias records carry
##    a live target + join evidence; Power Plant TM balls grant
##    their Gen-1 moves' TMs.
## 4. Spelling aliases: the ELIXER / MAX_ELIXER balls grant
##    elixir / max-elixir.
## 5. Hidden items: the Viridian Forest Potion is found only by
##    FACING its tile (the source trigger rule); the Four
##    Island Pearl (FRLG record) collects the same way.
## 6. Sevii balls: the Four Island Star Piece ball collects
##    through the F4 sidecar identity.
## 7. Pokemon balls route: Power Plant ambush = battle
##    (Voltorb 40), Dojo = gift choice (Hitmonlee 30), Oak's
##    Lab = oak_flow; the BluesHouse "0" object = script_give.
## 8. Mart stock loads per map (Pewter, Celadon 2F's two clerks
##    incl. the TM clerk, Three Island), prices agree with
##    MartShop's own table, empty-stock maps name their cause,
##    the Roof reports vending, and all 19 audit mart maps have
##    records.
## 9. Use gates refuse without and pass with their item:
##    Card Key doors, Lift Key elevator, Secret Key gym door,
##    Silph Scope ghost check, Poke Flute / Snorlax (flute not
##    consumed; beaten flag closes the gate).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW Kanto item fixes tests — starting.")
	if root == null:
		print("FAIL: no scene tree root.")
		quit(1)
		return
	_main()


func _main() -> void:
	await process_frame
	await _run("test_walkup_pickup_grant_message_persistence", Callable(self, "test_walkup_pickup_grant_message_persistence"))
	await _run("test_all_kanto_pickup_constants_resolve", Callable(self, "test_all_kanto_pickup_constants_resolve"))
	await _run("test_gen1_tm_alias_by_move", Callable(self, "test_gen1_tm_alias_by_move"))
	await _run("test_spelling_alias_pickups", Callable(self, "test_spelling_alias_pickups"))
	await _run("test_hidden_item_trigger_rule", Callable(self, "test_hidden_item_trigger_rule"))
	await _run("test_sevii_ball_pickup", Callable(self, "test_sevii_ball_pickup"))
	await _run("test_pokemon_ball_routes", Callable(self, "test_pokemon_ball_routes"))
	await _run("test_mart_stock_per_map", Callable(self, "test_mart_stock_per_map"))
	await _run("test_use_gates", Callable(self, "test_use_gates"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var result: Variant = await fn.call()
	if bool(result):
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _fresh_state() -> Dictionary:
	return PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {"name": "RED"})


func _fixture() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string("res://tests/item_fixes_data.json")
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _ball_tile(map_name: String, item_const: String) -> Vector2i:
	for obj_value in PUWItemPickups.map_objects(map_name):
		if obj_value is Dictionary:
			var obj: Dictionary = obj_value
			if str(obj.get("item", "")) == item_const:
				return Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
	return Vector2i(-1, -1)


# ----------------------------------------------------------------
# 1. Walk-up pickup: grant + message + persistence + despawn.
# ----------------------------------------------------------------
func test_walkup_pickup_grant_message_persistence() -> bool:
	var ok: bool = true
	var spawner: PUWSpawner = PUWSpawner.new()
	var state: Dictionary = _fresh_state()
	var ball: Vector2i = _ball_tile("Route2", "MOON_STONE")
	if ball == Vector2i(-1, -1):
		print("  Route2 MOON_STONE ball not found in map data")
		return false
	var hit: Dictionary = PUWInputInteraction.try_interact_field(
		spawner, state, "Route2", ball + Vector2i(0, 1), Vector2i(0, -1))
	if not bool(hit.get("found", false)) or str(hit.get("kind", "")) != "item" \
			or not bool(hit.get("ok", false)):
		print("  walk-up pickup failed: " + str(hit))
		ok = false
	if str(hit.get("item", "")) != "moon-stone":
		print("  wrong item granted: " + str(hit.get("item", "")))
		ok = false
	if str(hit.get("message", "")) != "RED found Moon Stone!":
		print("  wrong message: " + str(hit.get("message", "")))
		ok = false
	if PUWLiveBag.count_in_state(state, "moon-stone") != 1:
		print("  moon stone not in bag")
		ok = false
	var flag_key: String = PUWItemPickups.ball_flag_key("Route2", ball, "MOON_STONE")
	if not PUWItemPickups.is_collected(state, flag_key):
		print("  once-flag not set")
		ok = false
	# Persistence through the real save manager.
	if not PUWSaveManager.save_game(state):
		print("  save_game failed")
		return false
	var loaded: Dictionary = PUWSaveManager.load_game()
	if not PUWItemPickups.is_collected(loaded, flag_key):
		print("  once-flag lost across save/load")
		ok = false
	if PUWLiveBag.count_in_state(loaded, "moon-stone") != 1:
		print("  bag lost across save/load")
		ok = false
	# Second interact on the loaded state grants nothing.
	var again: Dictionary = PUWInputInteraction.try_interact_field(
		spawner, loaded, "Route2", ball + Vector2i(0, 1), Vector2i(0, -1))
	if str(again.get("reason", "")) != "already_collected" \
			or PUWLiveBag.count_in_state(loaded, "moon-stone") != 1:
		print("  second interact misbehaved: " + str(again))
		ok = false
	# Despawn: spawn Route 2 for real; the collected ball hides,
	# the uncollected HP Up ball stays visible.
	var parent: Node2D = Node2D.new()
	root.add_child(parent)
	var fresh_spawner: PUWSpawner = PUWSpawner.new()
	parent.add_child(fresh_spawner)
	fresh_spawner.spawn_map(parent, "Route2")
	var hidden_count: int = PUWItemPickups.despawn_collected_nodes(parent, loaded)
	if hidden_count < 1:
		print("  despawn hid nothing")
		ok = false
	var hp_ball: Vector2i = _ball_tile("Route2", "HP_UP")
	var saw_moon_hidden: bool = false
	var saw_hp_visible: bool = false
	for child in parent.get_children():
		var tile_value: Variant = child.get_meta("tile", Vector2i.ZERO)
		var tile: Vector2i = tile_value if tile_value is Vector2i else Vector2i.ZERO
		if str(child.get_meta("kind", "")) != "item":
			continue
		if tile == ball and not child.visible:
			saw_moon_hidden = true
		if tile == hp_ball and child.visible:
			saw_hp_visible = true
	if not saw_moon_hidden or not saw_hp_visible:
		print("  despawn state wrong (moon hidden=" + str(saw_moon_hidden)
			+ ", hp visible=" + str(saw_hp_visible) + ")")
		ok = false
	# Node path: collect the HP Up ball through its spawned node
	# on a fresh state.
	var state2: Dictionary = _fresh_state()
	var node_hit: Dictionary = {}
	for child in parent.get_children():
		var tile_value2: Variant = child.get_meta("tile", Vector2i.ZERO)
		var tile2: Vector2i = tile_value2 if tile_value2 is Vector2i else Vector2i.ZERO
		if str(child.get_meta("kind", "")) == "item" and tile2 == hp_ball:
			node_hit = PUWItemPickups.try_pickup_node(state2, child)
	if not bool(node_hit.get("ok", false)) or str(node_hit.get("item", "")) != "hp-up":
		print("  node-path pickup failed: " + str(node_hit))
		ok = false
	parent.queue_free()
	return ok


# ----------------------------------------------------------------
# 2. Every bound Kanto pickup constant resolves.
# ----------------------------------------------------------------
func test_all_kanto_pickup_constants_resolve() -> bool:
	var consts_value: Variant = _fixture().get("kanto_pickup_consts", [])
	if not (consts_value is Array):
		return false
	var consts: Array = consts_value
	if consts.size() != 60:
		print("  fixture drift: expected 60 distinct constants, got " + str(consts.size()))
		return false
	var ok: bool = true
	for const_value in consts:
		var const_name: String = str(const_value)
		if PUWItemResolve.resolve_const(const_name) == "":
			print("  unresolved: " + const_name)
			ok = false
	return ok


# ----------------------------------------------------------------
# 3. Gen-1 TM alias joins BY MOVE.
# ----------------------------------------------------------------
func test_gen1_tm_alias_by_move() -> bool:
	var ok: bool = true
	var record: Dictionary = PUWItemResolve.gen1_machine_record("TM_WATER_GUN")
	if int(record.get("gen1_number", 0)) != 12 \
			or str(record.get("move_slug", "")) != "water-gun":
		print("  TM_WATER_GUN record wrong: " + str(record))
		ok = false
	var target: String = PUWItemResolve.resolve_const("TM_WATER_GUN")
	if target != str(record.get("target_canonical", "")) or target == "":
		print("  TM_WATER_GUN did not resolve to its record target")
		ok = false
	# The joined entry must be Water Gun's TM in Gen 1 — proven
	# from the entry itself (its Gen I annotation), not from the
	# number 12: the modern TM12 teaches Taunt.
	var entry: Dictionary = PUWItemRegistry.get_entry(target)
	if not str(entry.get("effect", "")).contains("Gen I: Water Gun"):
		print("  target entry does not annotate Gen I: Water Gun: " + str(entry))
		ok = false
	# All 55 records carry a live target and join evidence.
	var checked: int = 0
	for machine in ["TM_MEGA_PUNCH", "TM_THUNDER", "TM_PSYCHIC_M", "TM_SWIFT",
			"TM_EARTHQUAKE", "TM_EXPLOSION", "TM_REST", "HM_CUT", "HM_FLASH"]:
		var rec: Dictionary = PUWItemResolve.gen1_machine_record(machine)
		if rec.is_empty() or str(rec.get("join_evidence", "")) == "" \
				or PUWItemResolve.resolve_const(machine) == "":
			print("  machine record/resolution failed: " + machine)
			ok = false
		checked += 1
	if checked != 9:
		ok = false
	# Power Plant TM balls grant their Gen-1 moves' TMs.
	var state: Dictionary = _fresh_state()
	var thunder_ball: Vector2i = _ball_tile("PowerPlant", "TM_THUNDER")
	var hit: Dictionary = PUWItemPickups.try_pickup_at(
		state, "PowerPlant", thunder_ball + Vector2i(0, 1), Vector2i(0, -1))
	if not bool(hit.get("ok", false)) or str(hit.get("item", "")) != "tm25":
		print("  TM_THUNDER ball granted wrong: " + str(hit))
		ok = false
	var reflect_ball: Vector2i = _ball_tile("PowerPlant", "TM_REFLECT")
	var hit2: Dictionary = PUWItemPickups.try_pickup_at(
		state, "PowerPlant", reflect_ball + Vector2i(0, 1), Vector2i(0, -1))
	if not bool(hit2.get("ok", false)) \
			or str(hit2.get("item", "")) != PUWItemResolve.resolve_const("TM_REFLECT"):
		print("  TM_REFLECT ball granted wrong: " + str(hit2))
		ok = false
	return ok


# ----------------------------------------------------------------
# 4. Spelling aliases.
# ----------------------------------------------------------------
func test_spelling_alias_pickups() -> bool:
	var ok: bool = true
	var state: Dictionary = _fresh_state()
	var elixer_ball: Vector2i = _ball_tile("PokemonTower4F", "ELIXER")
	if elixer_ball == Vector2i(-1, -1):
		print("  ELIXER ball not found")
		return false
	var hit: Dictionary = PUWItemPickups.try_pickup_at(
		state, "PokemonTower4F", elixer_ball + Vector2i(0, 1), Vector2i(0, -1))
	if not bool(hit.get("ok", false)) or str(hit.get("item", "")) != "elixir":
		print("  ELIXER ball granted wrong: " + str(hit))
		ok = false
	var max_ball: Vector2i = _ball_tile("CeruleanCave1F", "MAX_ELIXER")
	var hit2: Dictionary = PUWItemPickups.try_pickup_at(
		state, "CeruleanCave1F", max_ball + Vector2i(0, 1), Vector2i(0, -1))
	if not bool(hit2.get("ok", false)) or str(hit2.get("item", "")) != "max-elixir":
		print("  MAX_ELIXER ball granted wrong: " + str(hit2))
		ok = false
	return ok


# ----------------------------------------------------------------
# 5. Hidden items: the faced-tile trigger rule.
# ----------------------------------------------------------------
func test_hidden_item_trigger_rule() -> bool:
	var ok: bool = true
	# Viridian Forest Potion: source (1,18) step units -> bound
	# (2,36); ANTIDOTE at (32,84).
	var record: Dictionary = PUWItemPickups.hidden_item_at("ViridianForest", Vector2i(2, 36))
	if str(record.get("item_const", "")) != "POTION":
		print("  hidden record wrong: " + str(record))
		return false
	var state: Dictionary = _fresh_state()
	# Standing ON the tile does not trigger (must face it).
	var on_top: Dictionary = PUWItemPickups.try_pickup_at(
		state, "ViridianForest", Vector2i(2, 36), Vector2i(0, -1))
	if bool(on_top.get("found", false)):
		print("  hidden item triggered while standing on it")
		ok = false
	# Facing away from beside it does not trigger.
	var away: Dictionary = PUWItemPickups.try_pickup_at(
		state, "ViridianForest", Vector2i(2, 37), Vector2i(0, 1))
	if bool(away.get("found", false)):
		print("  hidden item triggered facing away")
		ok = false
	# Facing it triggers: grant + message + hidden flag.
	var hit: Dictionary = PUWItemPickups.try_pickup_at(
		state, "ViridianForest", Vector2i(2, 37), Vector2i(0, -1))
	if not bool(hit.get("ok", false)) or not bool(hit.get("hidden", false)) \
			or str(hit.get("item", "")) != "potion" \
			or str(hit.get("message", "")) != "RED found Potion!":
		print("  hidden pickup wrong: " + str(hit))
		ok = false
	var again: Dictionary = PUWItemPickups.try_pickup_at(
		state, "ViridianForest", Vector2i(2, 37), Vector2i(0, -1))
	if str(again.get("reason", "")) != "already_collected":
		print("  hidden re-pickup not refused: " + str(again))
		ok = false
	# FRLG Sevii record: Four Island Pearl at (22,34).
	var pearl: Dictionary = PUWItemPickups.hidden_item_at("FourIsland", Vector2i(22, 34))
	if str(pearl.get("item_const", "")) != "ITEM_PEARL":
		print("  FRLG hidden record wrong: " + str(pearl))
		ok = false
	var hit2: Dictionary = PUWItemPickups.try_pickup_at(
		state, "FourIsland", Vector2i(22, 35), Vector2i(0, -1))
	if not bool(hit2.get("ok", false)) or str(hit2.get("item", "")) != "pearl":
		print("  FRLG hidden pickup wrong: " + str(hit2))
		ok = false
	return ok


# ----------------------------------------------------------------
# 6. Sevii ball via the F4 sidecar.
# ----------------------------------------------------------------
func test_sevii_ball_pickup() -> bool:
	var identity: Dictionary = PUWItemPickups.sevii_item_at("FourIsland", Vector2i(5, 6))
	if str(identity.get("item_const", "")) != "ITEM_STAR_PIECE":
		print("  sevii identity wrong: " + str(identity))
		return false
	var state: Dictionary = _fresh_state()
	var hit: Dictionary = PUWItemPickups.try_pickup_at(
		state, "FourIsland", Vector2i(5, 7), Vector2i(0, -1))
	if not bool(hit.get("ok", false)) or str(hit.get("item", "")) != "star-piece":
		print("  sevii pickup wrong: " + str(hit))
		return false
	if PUWLiveBag.count_in_state(state, "star-piece") != 1:
		print("  star piece not in bag")
		return false
	return true


# ----------------------------------------------------------------
# 7. Pokemon-ball routing + the script-give marker.
# ----------------------------------------------------------------
func test_pokemon_ball_routes() -> bool:
	var ok: bool = true
	var state: Dictionary = _fresh_state()
	var voltorb: Dictionary = PUWItemPickups.try_pickup_at(
		state, "PowerPlant", Vector2i(18, 41), Vector2i(0, -1))
	if str(voltorb.get("kind", "")) != "pokemon_ball" \
			or str(voltorb.get("route", "")) != "battle" \
			or str(voltorb.get("species", "")) != "VOLTORB" \
			or int(voltorb.get("level", 0)) != 40:
		print("  voltorb route wrong: " + str(voltorb))
		ok = false
	var dojo: Dictionary = PUWItemPickups.try_pickup_at(
		state, "FightingDojo", Vector2i(8, 3), Vector2i(0, -1))
	if str(dojo.get("route", "")) != "gift_choice" \
			or str(dojo.get("species", "")) != "HITMONLEE" \
			or int(dojo.get("level", 0)) != 30:
		print("  dojo route wrong: " + str(dojo))
		ok = false
	var oak: Dictionary = PUWItemPickups.try_pickup_at(
		state, "OaksLab", Vector2i(12, 7), Vector2i(0, -1))
	if str(oak.get("route", "")) != "oak_flow" \
			or str(oak.get("species", "")) != "CHARMANDER":
		print("  oak route wrong: " + str(oak))
		ok = false
	# Routing never grants an item or a party member by itself.
	if PUWLiveBag.count_in_state(state, "potion") != 0:
		print("  routing leaked a grant")
		ok = false
	# The BluesHouse script-give ("0") object.
	var give_tile: Vector2i = Vector2i(-1, -1)
	for obj_value in PUWItemPickups.map_objects("BluesHouse"):
		if obj_value is Dictionary:
			var obj: Dictionary = obj_value
			if str(obj.get("item", "")) == "0":
				give_tile = Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
				break
	if give_tile == Vector2i(-1, -1):
		print("  BluesHouse script-give object not found")
		return false
	var give: Dictionary = PUWItemPickups.try_pickup_at(
		state, "BluesHouse", give_tile + Vector2i(0, 1), Vector2i(0, -1))
	if str(give.get("kind", "")) != "script_give":
		print("  script-give routing wrong: " + str(give))
		ok = false
	return ok


# ----------------------------------------------------------------
# 8. Per-mart stock.
# ----------------------------------------------------------------
func test_mart_stock_per_map() -> bool:
	var ok: bool = true
	var pewter: Dictionary = PUWMartStock.stock_for_map("PewterMart")
	if not bool(pewter.get("found", false)):
		print("  PewterMart record missing")
		return false
	var pewter_stock: Array = pewter.get("stock", [])
	for want in ["poke-ball", "potion", "escape-rope", "antidote",
			"burn-heal", "awakening", "paralyze-heal"]:
		if not pewter_stock.has(want):
			print("  PewterMart stock missing " + want + ": " + str(pewter_stock))
			ok = false
	# Prices agree with MartShop's own table for the same data.
	var shop: MartShop = MartShop.new()
	var compact_raw: String = FileAccess.get_file_as_string("res://data/items_full_compact.json")
	var compact: Variant = JSON.parse_string(compact_raw)
	var items: Array = []
	if compact is Dictionary:
		var compact_dict: Dictionary = compact
		var items_value: Variant = compact_dict.get("items", [])
		if items_value is Array:
			items = items_value
	shop.load_prices(items)
	if int(shop.prices.get("poke-ball", 0)) != PUWMartStock.price_for("poke-ball") \
			or PUWMartStock.price_for("poke-ball") <= 0:
		print("  price disagreement with MartShop")
		ok = false
	# Celadon 2F: two clerks; the TM clerk resolves by move.
	var celadon: Dictionary = PUWMartStock.stock_for_map("CeladonMart2F")
	var clerks: Array = celadon.get("clerks", [])
	if clerks.size() != 2:
		print("  CeladonMart2F should have 2 clerks: " + str(celadon))
		ok = false
	else:
		var tm_clerk: Dictionary = clerks[1]
		var tm_items: Array = tm_clerk.get("items", [])
		var tm_unresolved: Array = tm_clerk.get("unresolved", [])
		if tm_items.size() != 9 or not tm_unresolved.is_empty():
			print("  TM clerk wrong: " + str(tm_clerk))
			ok = false
		if not tm_items.has(PUWItemResolve.resolve_const("TM_DOUBLE_TEAM")):
			print("  TM clerk missing Gen-1 Double Team TM")
			ok = false
	# Three Island (FRLG list) resolves fully.
	var three: Dictionary = PUWMartStock.stock_for_map("ThreeIsland_Mart")
	var three_stock: Array = three.get("stock", [])
	if three_stock.is_empty() or not three_stock.has("ultra-ball"):
		print("  ThreeIsland_Mart stock wrong: " + str(three))
		ok = false
	# Empty-stock maps name their cause; the Roof reports vending.
	var lobby: Dictionary = PUWMartStock.stock_for_map("CeladonMart1F")
	var lobby_stock: Array = lobby.get("stock", [])
	if not lobby_stock.is_empty() or str(lobby.get("note", "")) == "":
		print("  CeladonMart1F should be empty with a named cause: " + str(lobby))
		ok = false
	var roof: Dictionary = PUWMartStock.stock_for_map("CeladonMartRoof")
	var vending: Array = roof.get("vending", [])
	if vending != ["fresh-water", "soda-pop", "lemonade"]:
		print("  CeladonMartRoof vending wrong: " + str(roof))
		ok = false
	var vend_prices_value: Variant = roof.get("vending_source_prices", {})
	var vend_prices: Dictionary = vend_prices_value if vend_prices_value is Dictionary else {}
	if int(vend_prices.get("FRESH_WATER", 0)) != 200:
		print("  vending source price lost: " + str(vend_prices))
		ok = false
	# All 19 audit mart maps have records.
	var audit_maps_value: Variant = _fixture().get("mart_maps", [])
	var audit_maps: Array = audit_maps_value if audit_maps_value is Array else []
	var recorded: Array = PUWMartStock.mart_maps()
	for map_value in audit_maps:
		var map_name: String = str(map_value)
		if not recorded.has(map_name):
			print("  mart record missing for " + map_name)
			ok = false
	# Every clerk list in every record resolves completely —
	# no source constant is left unidentified anywhere.
	for map_value in recorded:
		var map_name: String = str(map_value)
		var record: Dictionary = PUWMartStock.stock_for_map(map_name)
		var clerks_all: Array = record.get("clerks", [])
		for clerk_value in clerks_all:
			if clerk_value is Dictionary:
				var clerk_row: Dictionary = clerk_value
				var unresolved: Array = clerk_row.get("unresolved", [])
				if not unresolved.is_empty():
					print("  " + map_name + " clerk " + str(clerk_row.get("clerk", ""))
						+ " unresolved: " + str(unresolved))
					ok = false
	return ok


# ----------------------------------------------------------------
# 9. Use gates.
# ----------------------------------------------------------------
func test_use_gates() -> bool:
	var ok: bool = true
	var state: Dictionary = _fresh_state()
	# Card Key.
	var door: Dictionary = PUWItemGates.card_key_door(state, "SilphCo5F", 0x18)
	if not bool(door.get("applies", false)) or bool(door.get("opens", true)):
		print("  card key door should apply and stay shut: " + str(door))
		ok = false
	PUWLiveBag.grant_to_state(state, "card-key", 1)
	door = PUWItemGates.card_key_door(state, "SilphCo5F", 0x18)
	if not bool(door.get("opens", false)):
		print("  card key door should open with the key: " + str(door))
		ok = false
	var door11: Dictionary = PUWItemGates.card_key_door(state, "SilphCo11F", 0x5e)
	if not bool(door11.get("opens", false)):
		print("  11F card key door should open: " + str(door11))
		ok = false
	var off_map: Dictionary = PUWItemGates.card_key_door(state, "Route2", 0x18)
	if bool(off_map.get("applies", true)):
		print("  card key gate applied off Silph Co")
		ok = false
	# Lift Key.
	var lift: Dictionary = PUWItemGates.lift_key_elevator(state)
	if bool(lift.get("allowed", true)):
		print("  elevator allowed without lift key")
		ok = false
	PUWLiveBag.grant_to_state(state, "lift-key", 1)
	lift = PUWItemGates.lift_key_elevator(state)
	var floors: Array = lift.get("floors", [])
	if not bool(lift.get("allowed", false)) or floors.size() != 3:
		print("  elevator wrong with lift key: " + str(lift))
		ok = false
	# Secret Key.
	var gym: Dictionary = PUWItemGates.secret_key_door(
		state, "CinnabarIsland", Vector2i(36, 8), Vector2i(0, -1))
	if not bool(gym.get("applies", false)) or bool(gym.get("allowed", true)) \
			or str(gym.get("reason", "")) != "door_is_locked":
		print("  gym door should apply and lock: " + str(gym))
		ok = false
	PUWLiveBag.grant_to_state(state, "secret-key", 1)
	gym = PUWItemGates.secret_key_door(
		state, "CinnabarIsland", Vector2i(36, 8), Vector2i(0, -1))
	if not bool(gym.get("allowed", false)):
		print("  gym door should open with secret key: " + str(gym))
		ok = false
	var elsewhere: Dictionary = PUWItemGates.secret_key_door(
		state, "CinnabarIsland", Vector2i(0, 0), Vector2i(0, -1))
	if bool(elsewhere.get("applies", true)):
		print("  gym door gate applied away from the door")
		ok = false
	# Silph Scope.
	var ghost: Dictionary = PUWItemGates.ghost_check(state, "PokemonTower4F")
	if not bool(ghost.get("unidentified", false)):
		print("  ghost should be unidentified without scope: " + str(ghost))
		ok = false
	PUWLiveBag.grant_to_state(state, "silph-scope", 1)
	ghost = PUWItemGates.ghost_check(state, "PokemonTower4F")
	if bool(ghost.get("unidentified", true)):
		print("  ghost should be identified with scope: " + str(ghost))
		ok = false
	var no_ghost: Dictionary = PUWItemGates.ghost_check(state, "Route2")
	if bool(no_ghost.get("in_tower", true)):
		print("  ghost check applied outside the tower")
		ok = false
	# Poke Flute / Snorlax.
	var flute: Dictionary = PUWItemGates.snorlax_flute(state, "Route12", Vector2i(20, 122))
	if not bool(flute.get("applies", false)) or bool(flute.get("can_wake", true)) \
			or str(flute.get("reason", "")) != "needs_poke_flute":
		print("  flute gate should refuse without the flute: " + str(flute))
		ok = false
	PUWLiveBag.grant_to_state(state, "poke-flute", 1)
	flute = PUWItemGates.snorlax_flute(state, "Route12", Vector2i(20, 122))
	var battle: Dictionary = flute.get("battle", {})
	if not bool(flute.get("can_wake", false)) \
			or str(battle.get("species", "")) != "SNORLAX" \
			or int(battle.get("level", 0)) != 30:
		print("  flute gate should wake Snorlax 30: " + str(flute))
		ok = false
	if PUWLiveBag.count_in_state(state, "poke-flute") != 1:
		print("  the flute must not be consumed")
		ok = false
	var far: Dictionary = PUWItemGates.snorlax_flute(state, "Route12", Vector2i(0, 0))
	if bool(far.get("applies", true)):
		print("  flute gate applied away from Snorlax")
		ok = false
	var flags: Dictionary = state["story_flags"]
	flags["EVENT_BEAT_ROUTE12_SNORLAX"] = true
	state["story_flags"] = flags
	var beaten: Dictionary = PUWItemGates.snorlax_flute(state, "Route12", Vector2i(20, 122))
	if bool(beaten.get("can_wake", true)) or not bool(beaten.get("beaten", false)):
		print("  beaten Snorlax should close the gate: " + str(beaten))
		ok = false
	return ok
