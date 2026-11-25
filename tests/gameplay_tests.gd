class_name PUWGameplayTests
extends SceneTree
## Headless test runner for the Pokemon Ultimate World battle engine v4.
##
## Run it in Godot 4 (headless, no game window needed) with:
##   godot --headless --script res://tests/gameplay_tests.gd
## (from the project folder, with this file saved at
## res://tests/gameplay_tests.gd)
##
## It prints one PASS, FAIL or SKIPPED line per test, then a summary
## line, then quits. Exit code 0 means nothing failed (skipped tests
## do not fail the run), 1 means at least one test failed.
##
## The v4 pieces are built by different workers in parallel, so this
## file never names another worker's class directly. Every test loads
## its class by name first: if the class script cannot be found, that
## test prints FAIL with the reason "class not found" and the run
## carries on with the next test. A missing class is a real failure
## here, not something to work around.
##
## What the tests need in the project to run:
## - move_database_loader.gd at res://battle/moves/, and the official
##   move list at res://data/moves.json (954 moves).
## - MartShop, BattleHUD, OverworldLoop, MoveForgetScreen and
##   PUWSceneTransition, wherever the coordinator puts them. The tests
##   find them through the project's global class list, so their folder
##   does not matter, as long as they carry the right class_name.
##   Note: the RC1 project already has a PUWSceneTransition stub at
##   res://core/scene_transition.gd with no resolve_target method.
##   The v4 scene_transition.gd REPLACES that stub; do not keep both
##   files in the project, or the tests may load the stub instead.
## - exp_yield.json, growth_curves.json and evolution_triggers.json
##   at res://data/ for the two data tests. If those files are not
##   there yet, the data tests print SKIPPED and do not fail the run.
##   exp_yield.json holds 1,025 species entries under "species";
##   growth_curves.json holds 6 curves under "data" (PokeAPI names:
##   slow, medium, fast, medium-slow, slow-then-very-fast,
##   fast-then-very-slow); evolution_triggers.json holds 1,025
##   species entries under "data".
##
## The exact API each test expects is written in MERGE_README.md, so
## the worker building each class can match it.

const CLASS_PATHS: Dictionary = {
	"MoveDatabaseLoader": ["res://battle/moves/move_database_loader.gd"],
	"MartShop": ["res://battle/mart_shop.gd", "res://shop/mart_shop.gd", "res://battle/mart/mart_shop.gd", "res://systems/mart_shop.gd"],
	"BattleHUD": ["res://battle/battle_hud.gd", "res://ui/battle_hud.gd", "res://battle/hud/battle_hud.gd", "res://interface/battle_hud.gd"],
	"OverworldLoop": ["res://overworld/overworld_loop.gd", "res://world/overworld_loop.gd", "res://battle/overworld_loop.gd"],
	"MoveForgetScreen": ["res://ui/move_forget_screen.gd", "res://battle/move_forget_screen.gd", "res://interface/move_forget_screen.gd"],
	"PUWSceneTransition": ["res://scene_transition.gd", "res://core/scene_transition.gd", "res://ui/scene_transition.gd", "res://battle/scene_transition.gd"],
}

var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _failed_names: Array = []
var _skip_reason: String = ""


func _init() -> void:
	print("PUW battle engine v4 gameplay tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/gameplay_tests.gd")
		quit(1)
		return
	_run("test_move_loader_mapping", Callable(self, "test_move_loader_mapping"))
	_run("test_mart_buy_sell", Callable(self, "test_mart_buy_sell"))
	_run("test_hud_state", Callable(self, "test_hud_state"))
	_run("test_encounter_roll", Callable(self, "test_encounter_roll"))
	_run("test_move_forget", Callable(self, "test_move_forget"))
	_run("test_exp_growth_data", Callable(self, "test_exp_growth_data"))
	_run("test_evolution_data", Callable(self, "test_evolution_data"))
	_run("test_scene_resolve", Callable(self, "test_scene_resolve"))
	_run("test_encounter_cycle", Callable(self, "test_encounter_cycle"))
	_run("test_wild_encounter_rates", Callable(self, "test_wild_encounter_rates"))
	_run("test_free_supply_claims", Callable(self, "test_free_supply_claims"))
	print("PUW battle engine v4 gameplay tests — done: %d passed, %d failed, %d skipped." % [_passed, _failed, _skipped])
	if _failed > 0:
		var failed_text: String = ""
		for failed_name in _failed_names:
			if not failed_text.is_empty():
				failed_text += ", "
			failed_text += str(failed_name)
		print("Failed tests: " + failed_text)
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	_skip_reason = ""
	var ok: bool = test.call()
	if _skip_reason != "":
		_skipped += 1
		print("SKIPPED: " + test_name + " — " + _skip_reason)
	elif ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


## ------------------------------------------------------------------
## Helpers
## ------------------------------------------------------------------

## Print a failure detail line and return false, so a test can end
## with one line: return _fail("what went wrong").
func _fail(message: String) -> bool:
	print("  " + message)
	return false


## Mark this test as skipped (used by the data tests when their file
## is not in the project yet) and return true.
func _skip(reason: String) -> bool:
	_skip_reason = reason
	print("  SKIPPED: " + reason)
	return true


## A Variant as a Dictionary, or an empty Dictionary when it is not one.
func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## A Variant as an Array, or an empty Array when it is not one.
func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	if value is PackedStringArray:
		return Array(value)
	return []


## First path in the list that exists in the project, or "".
func _first_existing_path(paths: Array) -> String:
	for path in paths:
		if FileAccess.file_exists(str(path)):
			return str(path)
	return ""


## Read a JSON file. Returns the parsed value, or null when the file
## is missing or does not parse.
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var raw: String = FileAccess.get_file_as_string(path)
	return JSON.parse_string(raw)


## Load a class by its class_name. First through the project's global
## class list (works wherever the file was put), then through a short
## list of likely paths. Returns the script resource, or null when the
## class cannot be found or its script does not load.
func _load_class(class_name_str: String) -> Variant:
	var classes: Array = ProjectSettings.get_global_class_list()
	for entry in classes:
		var item: Dictionary = _as_dict(entry)
		if str(item.get("class", "")) == class_name_str:
			var path: String = str(item.get("path", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				var loaded: Resource = load(path)
				if loaded != null:
					return loaded
	var candidates: Array = _as_array(CLASS_PATHS.get(class_name_str, []))
	for candidate in candidates:
		var candidate_path: String = str(candidate)
		if ResourceLoader.exists(candidate_path):
			var loaded2: Resource = load(candidate_path)
			if loaded2 != null:
				return loaded2
	return null


## Make one object from a loaded script, or null.
func _new_instance(script_res: Variant) -> Variant:
	if script_res == null:
		return null
	return script_res.new()


## How many arguments a method takes on an object, or -1 when the
## method is not there at all. Used so a test never calls a method
## with the wrong number of arguments.
func _method_arg_count(obj: Object, method_name: String) -> int:
	var methods: Array = obj.get_method_list()
	for method in methods:
		var info: Dictionary = _as_dict(method)
		if str(info.get("name", "")) == method_name:
			return _as_array(info.get("args", [])).size()
	return -1


## ------------------------------------------------------------------
## Mart shop helpers. The shop keeps its money in a "money" value
## (or set_money / get_money methods) and the trainer's items in a
## "bag" dict keyed by item slug (or an "inventory" dict, or a
## get_inventory / get_bag method). Buy and sell return either a
## bool or a result dict with an "ok" key. These helpers read
## through whichever shape the shop uses, and fail cleanly when
## neither is there.
## ------------------------------------------------------------------

func _shop_set_money(shop: Variant, amount: int) -> bool:
	if _method_arg_count(shop, "set_money") >= 1:
		shop.set_money(amount)
		return true
	if "money" in shop:
		shop.money = amount
		return true
	return false


func _shop_get_money(shop: Variant) -> int:
	if _method_arg_count(shop, "get_money") == 0:
		return int(shop.get_money())
	if "money" in shop:
		return int(shop.money)
	return -1


func _shop_get_inventory(shop: Variant) -> Dictionary:
	if "bag" in shop:
		return _as_dict(shop.bag)
	if "inventory" in shop:
		return _as_dict(shop.inventory)
	if _method_arg_count(shop, "get_inventory") == 0:
		return _as_dict(shop.get_inventory())
	if _method_arg_count(shop, "get_bag") == 0:
		return _as_dict(shop.get_bag())
	return {}


## True when a buy/sell result means success. The result is either
## a plain bool or a dict with an "ok" key.
func _trade_ok(result: Variant) -> bool:
	if result is Dictionary:
		var ok_value: Variant = result.get("ok", false)
		return ok_value == true
	if result is bool:
		return result
	return false


func _shop_count(shop: Variant, item_name: String) -> int:
	var inv: Dictionary = _shop_get_inventory(shop)
	return int(inv.get(item_name, 0))


## Buy some of an item. The shop's buy takes either (item) or
## (item, qty); this calls whichever shape the shop has.
func _shop_buy(shop: Variant, item_name: String, qty: int) -> bool:
	var args: int = _method_arg_count(shop, "buy")
	if args >= 2:
		return _trade_ok(shop.buy(item_name, qty))
	if args == 1:
		var ok: bool = true
		for i in range(qty):
			if not _trade_ok(shop.buy(item_name)):
				ok = false
		return ok
	return false


## Sell some of an item. The shop's sell takes either (item) or
## (item, qty); this calls whichever shape the shop has.
func _shop_sell(shop: Variant, item_name: String, qty: int) -> bool:
	var args: int = _method_arg_count(shop, "sell")
	if args >= 2:
		return _trade_ok(shop.sell(item_name, qty))
	if args == 1:
		var ok: bool = true
		for i in range(qty):
			if not _trade_ok(shop.sell(item_name)):
				ok = false
		return ok
	return false


## ------------------------------------------------------------------
## Battle HUD helpers. The HUD keeps its log lines in "log_lines"
## (or a get_log_lines method) and its moves in "current_moves"
## (or a "moves" value, or a get_moves / get_current_moves method).
## ------------------------------------------------------------------

func _hud_log_lines(hud: Variant) -> Array:
	if "log_lines" in hud:
		return _as_array(hud.log_lines)
	if _method_arg_count(hud, "get_log_lines") == 0:
		return _as_array(hud.get_log_lines())
	return []


func _hud_moves(hud: Variant) -> Array:
	if "current_moves" in hud:
		return _as_array(hud.current_moves)
	if "moves" in hud:
		return _as_array(hud.moves)
	if _method_arg_count(hud, "get_current_moves") == 0:
		return _as_array(hud.get_current_moves())
	if _method_arg_count(hud, "get_moves") == 0:
		return _as_array(hud.get_moves())
	return []


## ------------------------------------------------------------------
## Evolution helpers. An evolution entry can spell its target, level,
## item and method under a few key names; these read whichever is there.
## ------------------------------------------------------------------

func _evo_list(entry: Variant) -> Array:
	if entry is Array:
		return entry
	var entry_dict: Dictionary = _as_dict(entry)
	if entry_dict.has("evolves_to") and entry_dict.get("evolves_to") is Array:
		return entry_dict["evolves_to"]
	if entry_dict.has("evolutions") and entry_dict.get("evolutions") is Array:
		return entry_dict["evolutions"]
	if entry_dict.has("to") or entry_dict.has("to_slug") or entry_dict.has("evolves_to") or entry_dict.has("target"):
		return [entry_dict]
	return []


func _evo_target(evo: Dictionary) -> String:
	if evo.has("to_slug"):
		return str(evo.get("to_slug", ""))
	if evo.has("to"):
		return str(evo.get("to", ""))
	if evo.has("evolves_to"):
		return str(evo.get("evolves_to", ""))
	if evo.has("target"):
		return str(evo.get("target", ""))
	if evo.has("species"):
		return str(evo.get("species", ""))
	return ""


func _evo_level(evo: Dictionary) -> int:
	if evo.has("level"):
		return int(evo.get("level", -1))
	if evo.has("min_level"):
		return int(evo.get("min_level", -1))
	if evo.has("at_level"):
		return int(evo.get("at_level", -1))
	return -1


func _evo_item(evo: Dictionary) -> String:
	if evo.has("trigger_item"):
		return str(evo.get("trigger_item", ""))
	if evo.has("item"):
		return str(evo.get("item", ""))
	if evo.has("stone"):
		return str(evo.get("stone", ""))
	return ""


func _evo_method(evo: Dictionary) -> String:
	if evo.has("method"):
		return str(evo.get("method", ""))
	if evo.has("trigger"):
		return str(evo.get("trigger", ""))
	if evo.has("type"):
		return str(evo.get("type", ""))
	return ""


## ------------------------------------------------------------------
## Data-file helpers. The v4 data files hold their species in a list
## under "species" (exp_yield.json) or "data" (evolution_triggers.json
## and growth_curves.json). Each entry carries its slug under "slug"
## or "name". These helpers find one entry by slug, or pull the
## whole list out, whichever shape the file uses.
## ------------------------------------------------------------------

## The species/curve list out of a data file: the list under
## "species" or "data", a bare list, or the values of a flat dict.
func _entry_list(data: Variant) -> Array:
	if data is Array:
		return data
	var data_dict: Dictionary = _as_dict(data)
	if data_dict.has("species") and data_dict.get("species") is Array:
		return data_dict["species"]
	if data_dict.has("data") and data_dict.get("data") is Array:
		return data_dict["data"]
	if data_dict.has("species") and data_dict.get("species") is Dictionary:
		return _as_dict(data_dict["species"]).values()
	if data_dict.has("data") and data_dict.get("data") is Dictionary:
		return _as_dict(data_dict["data"]).values()
	return []


## One entry out of a list, by its "slug", "name" or "id" value.
## Returns an empty dict when no entry matches.
func _find_entry(entries: Array, slug: String) -> Dictionary:
	var wanted: String = slug.to_lower()
	for raw in entries:
		var entry: Dictionary = _as_dict(raw)
		if entry.is_empty():
			continue
		var entry_slug: String = str(entry.get("slug", entry.get("name", entry.get("id", "")))).to_lower()
		if entry_slug == wanted:
			return entry
	return {}


## ------------------------------------------------------------------
## Tests — each returns true when it passes, false when it fails.
## ------------------------------------------------------------------

## The move loader, run against the real official move list.
## Total must be 954. Thunderbolt must map to power 90, acc 100,
## cat Special, pp 15, pp_max 24, status "PAR", status_chance 10.
## (Status codes are uppercase, like the RC1 file and the engine.)
## U-turn must keep its self-switch flag. Stealth Rock must be a
## Status move with power 0.
func test_move_loader_mapping() -> bool:
	var loader_script: Variant = _load_class("MoveDatabaseLoader")
	if loader_script == null:
		return _fail("MoveDatabaseLoader class not found.")
	var loader: Variant = _new_instance(loader_script)
	if loader == null:
		return _fail("MoveDatabaseLoader could not be made.")
	var moves_path: String = _first_existing_path([
		"res://data/moves.json",
		"res://battle/data/moves.json",
		"res://battle/moves/moves.json",
		"res://battle-engine-v4/moves.json",
	])
	if moves_path.is_empty():
		return _fail("moves.json not found in the project (looked in res://data/).")
	if _method_arg_count(loader, "load_official") != 1:
		return _fail("MoveDatabaseLoader has no load_official(path) method.")
	var result: Dictionary = _as_dict(loader.load_official(moves_path))
	var total: int = int(result.get("total", 0))
	var mapped_clean: int = int(result.get("mapped_clean", 0))
	var needs_attention: Array = _as_array(result.get("needs_attention", []))
	print("  loader: total %d, mapped_clean %d, needs_attention %d." % [total, mapped_clean, needs_attention.size()])
	if total != 954:
		return _fail("total moves was %d, wanted 954." % total)
	var moves: Dictionary = _as_dict(result.get("moves", {}))
	var bolt: Dictionary = _as_dict(moves.get("thunderbolt", {}))
	if bolt.is_empty():
		return _fail("Thunderbolt was not in the mapped moves.")
	if int(bolt.get("power", -1)) != 90:
		return _fail("Thunderbolt power was %s, wanted 90." % str(bolt.get("power", -1)))
	if int(bolt.get("acc", -1)) != 100:
		return _fail("Thunderbolt acc was %s, wanted 100." % str(bolt.get("acc", -1)))
	if str(bolt.get("cat", "")) != "Special":
		return _fail("Thunderbolt cat was '%s', wanted 'Special'." % str(bolt.get("cat", "")))
	if int(bolt.get("pp", -1)) != 15:
		return _fail("Thunderbolt pp was %s, wanted 15." % str(bolt.get("pp", -1)))
	if int(bolt.get("pp_max", -1)) != 24:
		return _fail("Thunderbolt pp_max was %s, wanted 24." % str(bolt.get("pp_max", -1)))
	if str(bolt.get("status", "")) != "PAR":
		return _fail("Thunderbolt status was '%s', wanted 'PAR'." % str(bolt.get("status", "")))
	if int(bolt.get("status_chance", -1)) != 10:
		return _fail("Thunderbolt status_chance was %s, wanted 10." % str(bolt.get("status_chance", -1)))
	var uturn: Dictionary = _as_dict(moves.get("uturn", {}))
	if uturn.is_empty():
		return _fail("U-turn was not in the mapped moves.")
	if not uturn.get("selfSwitch", false):
		return _fail("U-turn lost its self-switch flag.")
	if not uturn.get("pivot", false):
		return _fail("U-turn lost its pivot flag.")
	var rocks: Dictionary = _as_dict(moves.get("stealthrock", {}))
	if rocks.is_empty():
		return _fail("Stealth Rock was not in the mapped moves.")
	if str(rocks.get("cat", "")) != "Status":
		return _fail("Stealth Rock cat was '%s', wanted 'Status'." % str(rocks.get("cat", "")))
	if int(rocks.get("power", -1)) != 0:
		return _fail("Stealth Rock power was %s, wanted 0." % str(rocks.get("power", -1)))
	# Thunder Wave carries its status at the top level of the
	# Showdown move (not in "secondary"), so the loader must still
	# pick it up: status "PAR", chance 100.
	var wave: Dictionary = _as_dict(moves.get("thunderwave", {}))
	if wave.is_empty():
		return _fail("Thunder Wave was not in the mapped moves.")
	if str(wave.get("status", "")) != "PAR":
		return _fail("Thunder Wave status was '%s', wanted 'PAR'." % str(wave.get("status", "")))
	if int(wave.get("status_chance", -1)) != 100:
		return _fail("Thunder Wave status_chance was %s, wanted 100." % str(wave.get("status_chance", -1)))
	return true


## The Mart shop: buy, buy with too little money, sell for half,
## sell what you do not own.
## Prices in this test come from the project's own items file
## (items_full_compact.json, PokeAPI values), not the classic games'
## old 300/100 pricing: Potion costs 200 and Antidote costs 200.
## Items are named by slug ("potion", "antidote"). load_prices
## takes a list of item dicts with "slug" and "cost". buy and sell
## take (slug, qty) and return a dict with "ok", "money" and "bag".
func test_mart_buy_sell() -> bool:
	var shop_script: Variant = _load_class("MartShop")
	if shop_script == null:
		return _fail("MartShop class not found.")
	var shop: Variant = _new_instance(shop_script)
	if shop == null:
		return _fail("MartShop could not be made.")
	if _method_arg_count(shop, "load_prices") != 1:
		return _fail("MartShop has no load_prices(items) method.")
	if _method_arg_count(shop, "buy") < 1:
		return _fail("MartShop has no buy method.")
	if _method_arg_count(shop, "sell") < 1:
		return _fail("MartShop has no sell method.")
	# Prices from the archive's items file (PokeAPI values):
	# Potion 200, Antidote 200.
	var loaded: Variant = shop.load_prices([
		{"slug": "potion", "cost": 200, "display_name": "Potion"},
		{"slug": "antidote", "cost": 200, "display_name": "Antidote"},
	])
	if int(loaded) != 2:
		return _fail("load_prices loaded %s items, wanted 2." % str(loaded))
	if not _shop_set_money(shop, 1000):
		return _fail("MartShop has no money value to set.")
	# Buying 3 Potions at 200 each costs 600, leaving 400.
	if not _shop_buy(shop, "potion", 3):
		return _fail("buying 3 Potions with 1000 money failed.")
	if _shop_get_money(shop) != 400:
		return _fail("after buying 3 Potions at 200, money was %d, wanted 400." % _shop_get_money(shop))
	if _shop_count(shop, "potion") != 3:
		return _fail("after buying 3 Potions, the bag had %d Potions, wanted 3." % _shop_count(shop, "potion"))
	# Buying with too little money must fail and change nothing.
	if not _shop_set_money(shop, 150):
		return _fail("MartShop money could not be set to 150.")
	if _shop_buy(shop, "potion", 1):
		return _fail("buying a 200 Potion with only 150 money worked, but it should fail.")
	if _shop_get_money(shop) != 150:
		return _fail("a failed buy changed the money to %d, wanted 150." % _shop_get_money(shop))
	if _shop_count(shop, "potion") != 3:
		return _fail("a failed buy changed the Potion count to %d, wanted 3." % _shop_count(shop, "potion"))
	# Selling pays half, rounded down: a 200 Potion sells for 100.
	if not _shop_set_money(shop, 400):
		return _fail("MartShop money could not be set back to 400.")
	if not _shop_sell(shop, "potion", 1):
		return _fail("selling an owned Potion failed.")
	if _shop_get_money(shop) != 500:
		return _fail("selling a 200 Potion paid the wrong amount: money was %d, wanted 500." % _shop_get_money(shop))
	if _shop_count(shop, "potion") != 2:
		return _fail("after selling one Potion, the bag had %d Potions, wanted 2." % _shop_count(shop, "potion"))
	# Selling what you do not own must fail and change nothing.
	if _shop_sell(shop, "antidote", 1):
		return _fail("selling an Antidote that was never bought worked, but it should fail.")
	if _shop_get_money(shop) != 500:
		return _fail("a failed sell changed the money to %d, wanted 500." % _shop_get_money(shop))
	return true


## The battle HUD: player HP as a fraction, log lines, stored moves,
## and updating the bars when max HP is 0 must not crash.
func test_hud_state() -> bool:
	var hud_script: Variant = _load_class("BattleHUD")
	if hud_script == null:
		return _fail("BattleHUD class not found.")
	var hud: Variant = _new_instance(hud_script)
	if hud == null:
		return _fail("BattleHUD could not be made.")
	if _method_arg_count(hud, "set_player") < 1:
		return _fail("BattleHUD has no set_player method.")
	var set_args: int = _method_arg_count(hud, "set_player")
	if set_args == 1:
		hud.set_player({"hp": 45, "max_hp": 100})
	elif set_args == 2:
		hud.set_player(45, 100)
	else:
		return _fail("BattleHUD set_player takes %d arguments, wanted 1 (a dict) or 2 (hp, max_hp)." % set_args)
	var fraction: float = -1.0
	if _method_arg_count(hud, "hp_fraction") == 1:
		fraction = float(hud.hp_fraction(true))
	elif "hp_fraction" in hud:
		fraction = float(hud.hp_fraction)
	elif _method_arg_count(hud, "get_hp_fraction") == 0:
		fraction = float(hud.get_hp_fraction())
	else:
		return _fail("BattleHUD has no hp_fraction value to read.")
	if absf(fraction - 0.45) > 0.001:
		return _fail("hp 45 out of 100 gave hp_fraction %s, wanted 0.45." % str(fraction))
	if _method_arg_count(hud, "log_line") != 1:
		return _fail("BattleHUD has no log_line(text) method.")
	hud.log_line("Pikachu used Thunderbolt!")
	var lines: Array = _hud_log_lines(hud)
	if lines.is_empty():
		return _fail("log_line did not store the line anywhere.")
	if str(lines[lines.size() - 1]) != "Pikachu used Thunderbolt!":
		return _fail("the last log line was '%s', wanted 'Pikachu used Thunderbolt!'." % str(lines[lines.size() - 1]))
	if _method_arg_count(hud, "set_moves") != 1:
		return _fail("BattleHUD has no set_moves(moves) method.")
	hud.set_moves(["Thunderbolt", "Quick Attack", "Iron Tail", "Electro Ball"])
	var stored: Array = _hud_moves(hud)
	if stored.size() != 4:
		return _fail("set_moves stored %d moves, wanted 4." % stored.size())
	# Updating the bars with max HP 0 must not crash. The HUD's
	# update_bars takes either nothing, one dict, or two dicts
	# (player, enemy); this calls whichever shape it has.
	if _method_arg_count(hud, "update_bars") < 0:
		return _fail("BattleHUD has no update_bars method.")
	var bar_args: int = _method_arg_count(hud, "update_bars")
	if bar_args == 0:
		if set_args == 1:
			hud.set_player({"hp": 0, "max_hp": 0})
		else:
			hud.set_player(0, 0)
		hud.update_bars()
	elif bar_args == 1:
		hud.update_bars({"hp": 0, "max_hp": 0})
	elif bar_args == 2:
		hud.update_bars({"hp": 0, "max_hp": 0}, {"hp": 50, "max_hp": 100})
	else:
		return _fail("BattleHUD update_bars takes %d arguments, wanted 0, 1 or 2." % bar_args)
	return true


## Wild encounters and trainer sight in the overworld loop.
## Two species with weights 70 and 30, a seeded random roll, and a
## trainer at (0,0) facing right who should see (3,0) but not (0,3)
## or (-1,0) behind them.
func test_encounter_roll() -> bool:
	var loop_script: Variant = _load_class("OverworldLoop")
	if loop_script == null:
		return _fail("OverworldLoop class not found.")
	var loop: Variant = _new_instance(loop_script)
	if loop == null:
		return _fail("OverworldLoop could not be made.")
	if _method_arg_count(loop, "roll_encounter") != 2:
		return _fail("OverworldLoop has no roll_encounter(rows, rng) method.")
	var rows: Array = [
		{"species": "Pidgey", "rate": 70, "min_level": 2, "max_level": 5},
		{"species": "Rattata", "rate": 30, "min_level": 2, "max_level": 5},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var got: Dictionary = _as_dict(loop.roll_encounter(rows, rng))
	if got.is_empty():
		return _fail("roll_encounter returned nothing for two rows.")
	var species: String = str(got.get("species", ""))
	if species != "Pidgey" and species != "Rattata":
		return _fail("roll_encounter returned species '%s', wanted Pidgey or Rattata." % species)
	var level: int = int(got.get("level", 0))
	if level < 2 or level > 5:
		return _fail("roll_encounter gave level %d, wanted between 2 and 5." % level)
	var empty: Dictionary = _as_dict(loop.roll_encounter([], rng))
	if not empty.is_empty():
		return _fail("roll_encounter with no rows returned %s, wanted an empty dict." % str(empty))
	if _method_arg_count(loop, "trainer_sees_player") != 4:
		return _fail("OverworldLoop has no trainer_sees_player(trainer_pos, player_pos, facing, range) method.")
	if not loop.trainer_sees_player(Vector2(0, 0), Vector2(3, 0), Vector2(1, 0), 4):
		return _fail("a trainer at (0,0) facing right did not see the player at (3,0).")
	if loop.trainer_sees_player(Vector2(0, 0), Vector2(0, 3), Vector2(1, 0), 4):
		return _fail("a trainer facing right saw the player at (0,3), off to the side.")
	if loop.trainer_sees_player(Vector2(0, 0), Vector2(-1, 0), Vector2(1, 0), 4):
		return _fail("a trainer facing right saw the player at (-1,0), behind them.")
	return true


## The Move-Forget screen: pick a slot to replace, or keep the list.
func test_move_forget() -> bool:
	var screen_script: Variant = _load_class("MoveForgetScreen")
	if screen_script == null:
		return _fail("MoveForgetScreen class not found.")
	var screen: Variant = _new_instance(screen_script)
	if screen == null:
		return _fail("MoveForgetScreen could not be made.")
	if _method_arg_count(screen, "apply_choice") != 3:
		return _fail("MoveForgetScreen has no apply_choice(moves, new_move, choice) method.")
	var start: Array = ["Tackle", "Growl", "Ember", "Scratch"]
	var replaced: Array = _as_array(screen.apply_choice(start.duplicate(), "Flamethrower", 1))
	if replaced != ["Tackle", "Flamethrower", "Ember", "Scratch"]:
		return _fail("replacing slot 1 gave %s, wanted [Tackle, Flamethrower, Ember, Scratch]." % str(replaced))
	var kept: Array = _as_array(screen.apply_choice(start.duplicate(), "Flamethrower", -1))
	if kept != start:
		return _fail("choice -1 changed the list to %s, wanted it unchanged." % str(kept))
	var out_of_range: Array = _as_array(screen.apply_choice(start.duplicate(), "Flamethrower", 9))
	if out_of_range != start:
		return _fail("choice 9 (past the end) changed the list to %s, wanted it unchanged." % str(out_of_range))
	return true


## EXP yield and growth-curve data. These files are built by another
## worker in parallel: when they are not in the project yet, this
## test SKIPS instead of failing.
## exp_yield.json holds 1,025 species entries under "species", each
## with "name" (lowercase slug), "base_experience" and "growth_rate".
## Bulbasaur's base experience is 64. growth_curves.json holds 6
## curves under "data", each with "id" (PokeAPI name) and
## "exp_at_level" with levels "1" to "100". The "medium" curve at
## level 100 is 1,000,000, and every curve's level-100 value is
## checked: slow 1250000, medium 1000000, fast 800000,
## medium-slow 1059860, slow-then-very-fast 600000,
## fast-then-very-slow 1640000.
func test_exp_growth_data() -> bool:
	var exp_path: String = _first_existing_path([
		"res://data/exp_yield.json",
		"res://battle/data/exp_yield.json",
		"res://battle-engine-v4/exp_yield.json",
	])
	var growth_path: String = _first_existing_path([
		"res://data/growth_curves.json",
		"res://battle/data/growth_curves.json",
		"res://battle-engine-v4/growth_curves.json",
	])
	if exp_path.is_empty() or growth_path.is_empty():
		return _skip("data file not present yet (exp_yield.json or growth_curves.json missing from res://data/)")
	var exp_data: Variant = _load_json(exp_path)
	if exp_data == null:
		return _fail("exp_yield.json did not load as JSON.")
	var exp_entries: Array = _entry_list(exp_data)
	if exp_entries.is_empty():
		return _fail("exp_yield.json has no species entries.")
	if exp_entries.size() != 1025:
		return _fail("exp_yield.json has %d species, wanted all 1,025." % exp_entries.size())
	var bulb: Dictionary = _find_entry(exp_entries, "bulbasaur")
	if bulb.is_empty():
		return _fail("Bulbasaur was not in exp_yield.json.")
	if int(bulb.get("base_experience", -1)) != 64:
		return _fail("Bulbasaur base_experience was %s, wanted 64." % str(bulb.get("base_experience", -1)))
	var growth_data: Variant = _load_json(growth_path)
	if growth_data == null:
		return _fail("growth_curves.json did not load as JSON.")
	var curves: Array = _entry_list(growth_data)
	if curves.is_empty():
		return _fail("growth_curves.json has no curves.")
	var anchors: Dictionary = {
		"slow": 1250000,
		"medium": 1000000,
		"fast": 800000,
		"medium-slow": 1059860,
		"slow-then-very-fast": 600000,
		"fast-then-very-slow": 1640000,
	}
	for curve_id in anchors.keys():
		var curve: Dictionary = _find_entry(curves, str(curve_id))
		if curve.is_empty():
			return _fail("growth_curves.json has no '%s' curve." % str(curve_id))
		var exp_at_level: Dictionary = _as_dict(curve.get("exp_at_level", {}))
		var level_100: int = int(exp_at_level.get("100", -1))
		if level_100 != int(anchors[curve_id]):
			return _fail("the '%s' curve at level 100 was %d, wanted %d." % [str(curve_id), level_100, int(anchors[curve_id])])
	return true


## Evolution data. Built by another worker in parallel: when the
## file is not in the project yet, this test SKIPS instead of failing.
## evolution_triggers.json holds 1,025 species entries under "data",
## each with "slug" and "evolves_to": a list of rows with "to_slug",
## "trigger", "trigger_item" (an item slug such as "thunder-stone")
## and "min_level". Pikachu evolves to Raichu with a Thunder Stone,
## Magikarp evolves to Gyarados at level 20, and Eevee has 8
## different evolutions (its file rows repeat some of them for
## different triggers, so the test counts different target species,
## not rows).
func test_evolution_data() -> bool:
	var evo_path: String = _first_existing_path([
		"res://data/evolution_triggers.json",
		"res://battle/data/evolution_triggers.json",
		"res://battle-engine-v4/evolution_triggers.json",
	])
	if evo_path.is_empty():
		return _skip("data file not present yet (evolution_triggers.json missing from res://data/)")
	var evo_data: Variant = _load_json(evo_path)
	if evo_data == null:
		return _fail("evolution_triggers.json did not load as JSON.")
	var evo_entries: Array = _entry_list(evo_data)
	if evo_entries.is_empty():
		return _fail("evolution_triggers.json has no species entries.")
	var pikachu: Dictionary = _find_entry(evo_entries, "pikachu")
	if pikachu.is_empty():
		return _fail("Pikachu was not in evolution_triggers.json.")
	var pikachu_evos: Array = _evo_list(pikachu)
	var found_raichu: bool = false
	for evo in pikachu_evos:
		var evo_dict: Dictionary = _as_dict(evo)
		if _evo_target(evo_dict) == "raichu":
			var item: String = _evo_item(evo_dict)
			var method: String = _evo_method(evo_dict)
			if item == "thunder-stone" or item == "Thunder Stone" or "thunder" in item.to_lower() or "Thunder Stone" in method:
				found_raichu = true
	if not found_raichu:
		return _fail("Pikachu had no Thunder Stone evolution to Raichu.")
	var magikarp: Dictionary = _find_entry(evo_entries, "magikarp")
	if magikarp.is_empty():
		return _fail("Magikarp was not in evolution_triggers.json.")
	var magikarp_evos: Array = _evo_list(magikarp)
	var found_gyarados: bool = false
	for evo in magikarp_evos:
		var evo_dict: Dictionary = _as_dict(evo)
		if _evo_target(evo_dict) == "gyarados" and _evo_level(evo_dict) == 20:
			found_gyarados = true
	if not found_gyarados:
		return _fail("Magikarp had no level 20 evolution to Gyarados.")
	var eevee: Dictionary = _find_entry(evo_entries, "eevee")
	if eevee.is_empty():
		return _fail("Eevee was not in evolution_triggers.json.")
	var eevee_evos: Array = _evo_list(eevee)
	var eevee_targets: Dictionary = {}
	for evo in eevee_evos:
		var target: String = _evo_target(_as_dict(evo))
		if target != "":
			eevee_targets[target] = true
	if eevee_targets.size() != 8:
		return _fail("Eevee had %d different evolutions, wanted 8." % eevee_targets.size())
	return true


## The encounter cycle (vision mode): a seeded, equal-probability,
## no-repeat cycle over a real area's eligible species pool.
## The area is dewford-town-area from the project's own
## encounters_1025.json, whose pool is exactly Magikarp, Pelipper,
## Tentacool, Wailmer and Wingull. Rows are built from that file
## the same way the loop reads them: the species lives on the
## parent species entry, one row per species for this area.
func test_encounter_cycle() -> bool:
	var loop_script: Variant = _load_class("OverworldLoop")
	if loop_script == null:
		return _fail("OverworldLoop class not found.")
	var loop: Variant = _new_instance(loop_script)
	if loop == null:
		return _fail("OverworldLoop could not be made.")
	if _method_arg_count(loop, "start_encounter_cycle") != 3:
		return _fail("OverworldLoop has no start_encounter_cycle(area_id, rows, rng) method.")
	if _method_arg_count(loop, "next_in_encounter_cycle") != 2:
		return _fail("OverworldLoop has no next_in_encounter_cycle(area_id, rng) method.")
	if _method_arg_count(loop, "get_encounter_cycle_state") != 1:
		return _fail("OverworldLoop has no get_encounter_cycle_state(area_id) method.")
	if _method_arg_count(loop, "load_encounter_cycle_state") < 1:
		return _fail("OverworldLoop has no load_encounter_cycle_state method.")
	var enc_path: String = _first_existing_path(["res://data/encounters_1025.json"])
	if enc_path.is_empty():
		return _fail("encounters_1025.json not found in res://data/.")
	var enc_data: Variant = _load_json(enc_path)
	if enc_data == null:
		return _fail("encounters_1025.json did not load as JSON.")
	var area_id: String = "dewford-town-area"
	var rows: Array = []
	var entries_value: Variant = _as_dict(enc_data).get("entries", [])
	if entries_value is Array:
		var entries: Array = entries_value
		for raw_entry in entries:
			var entry: Dictionary = _as_dict(raw_entry)
			var species_name: String = str(entry.get("name", ""))
			var enc_value: Variant = entry.get("encounters", [])
			if not (enc_value is Array):
				continue
			var enc_rows: Array = enc_value
			for raw_row in enc_rows:
				var row: Dictionary = _as_dict(raw_row)
				if str(row.get("location_area_name", "")) == area_id:
					rows.append({"species": species_name, "chance": int(row.get("chance", 0)), "min_level": int(row.get("min_level", 1)), "max_level": int(row.get("max_level", 1))})
					break
	var expected_pool: Array = ["magikarp", "pelipper", "tentacool", "wailmer", "wingull"]
	if rows.size() != expected_pool.size():
		return _fail("built %d encounter rows for %s, wanted %d." % [rows.size(), area_id, expected_pool.size()])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var started: Dictionary = _as_dict(loop.start_encounter_cycle(area_id, rows, rng))
	if started.is_empty():
		return _fail("start_encounter_cycle returned an empty state.")
	var pool_in_state: Array = _as_array(started.get("pool", []))
	if pool_in_state.size() != expected_pool.size():
		return _fail("cycle pool had %d species, wanted %d." % [pool_in_state.size(), expected_pool.size()])
	# (1) Drawing pool-size times yields every pool species once.
	var drawn: Dictionary = {}
	for i in range(expected_pool.size()):
		var species: String = str(loop.next_in_encounter_cycle(area_id, rng))
		if species == "":
			return _fail("cycle draw %d returned an empty species." % i)
		if drawn.has(species):
			return _fail("cycle repeated species '%s' before the pool was exhausted." % species)
		drawn[species] = true
	for wanted in expected_pool:
		if not drawn.has(str(wanted)):
			return _fail("a full cycle never drew '%s'." % str(wanted))
	# (2) The next draw starts a fresh cycle: drawn size back to 1.
	var extra: String = str(loop.next_in_encounter_cycle(area_id, rng))
	if extra == "":
		return _fail("the first draw of the fresh cycle was empty.")
	var state_after: Dictionary = _as_dict(loop.get_encounter_cycle_state(area_id))
	var drawn_after: Array = _as_array(state_after.get("drawn", []))
	if drawn_after.size() != 1:
		return _fail("after exhaustion the drawn list had %d entries, wanted 1 (fresh cycle)." % drawn_after.size())
	if str(drawn_after[0]) != extra:
		return _fail("the fresh cycle's drawn list did not hold its first draw.")
	# (3) Save/load mid-cycle resumes exactly, with no repeats.
	var loop2: Variant = _new_instance(loop_script)
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 99
	loop2.start_encounter_cycle(area_id, rows, rng2)
	var pre: Dictionary = {}
	for i in range(2):
		var pre_species: String = str(loop2.next_in_encounter_cycle(area_id, rng2))
		if pre_species == "" or pre.has(pre_species):
			return _fail("pre-save draws were empty or repeated.")
		pre[pre_species] = true
	var snapshot: Dictionary = _as_dict(loop2.get_encounter_cycle_state(area_id))
	var loop3: Variant = _new_instance(loop_script)
	loop3.load_encounter_cycle_state(snapshot, area_id)
	var rng3: RandomNumberGenerator = RandomNumberGenerator.new()
	rng3.seed = 7
	var all_drawn: Dictionary = {}
	for key in pre.keys():
		all_drawn[str(key)] = true
	for i in range(expected_pool.size() - 2):
		var post_species: String = str(loop3.next_in_encounter_cycle(area_id, rng3))
		if post_species == "":
			return _fail("a post-load draw was empty.")
		if all_drawn.has(post_species):
			return _fail("after load the cycle repeated '%s' before the pool was exhausted." % post_species)
		all_drawn[post_species] = true
	if all_drawn.size() != expected_pool.size():
		return _fail("pre- plus post-load draws covered %d species, wanted the full pool of %d." % [all_drawn.size(), expected_pool.size()])
	for wanted2 in expected_pool:
		if not all_drawn.has(str(wanted2)):
			return _fail("the save/load cycle never drew '%s'." % str(wanted2))
	return true


## Real wild encounter rates: the world pack's
## data/wild_encounters.json (pret/pokered tables for Kanto,
## pret/pokefirered tables for Sevii) wired into OverworldLoop.
## Route 1's grass rate byte is 25 in data/wild/maps/Route1.asm,
## and the Gen 1 engine (TryDoWildEncounter) rolls a random byte
## against it, so the per-step chance must be 25/256. Route 1's
## water rate is 0, an unknown map stays 0.0, and the Gen 3
## conversion (rate * 16 / 1600 in pokefirered's
## DoWildEncounterRateTest) turns a rate of 25 into 0.25.
func test_wild_encounter_rates() -> bool:
	var loop_script: Variant = _load_class("OverworldLoop")
	if loop_script == null:
		return _fail("OverworldLoop class not found.")
	var loop: Variant = _new_instance(loop_script)
	if loop == null:
		return _fail("OverworldLoop could not be made.")
	if _method_arg_count(loop, "set_wild_encounters_data") != 1:
		return _fail("OverworldLoop has no set_wild_encounters_data(data) method.")
	if _method_arg_count(loop, "wild_step_encounter_chance") < 2:
		return _fail("OverworldLoop has no wild_step_encounter_chance(map, terrain) method.")
	if _method_arg_count(loop, "rate_byte_to_step_chance") != 2:
		return _fail("OverworldLoop has no rate_byte_to_step_chance(rate, semantics) method.")
	var wild_path: String = _first_existing_path([
		"res://data/wild_encounters.json",
		"res://world-kanto/data/wild_encounters.json",
	])
	if wild_path.is_empty():
		return _skip("wild_encounters.json not present in the project yet")
	var wild_data: Variant = _load_json(wild_path)
	if not (wild_data is Dictionary):
		return _fail("wild_encounters.json did not load as a Dictionary.")
	loop.set_wild_encounters_data(wild_data)
	var route1: float = float(loop.wild_step_encounter_chance("ROUTE_1", "grass"))
	var expected_route1: float = 25.0 / 256.0
	if absf(route1 - expected_route1) > 0.000001:
		return _fail("Route 1 grass chance was %f, wanted %f (rate byte 25, Gen 1 semantics)." % [route1, expected_route1])
	var route1_water: float = float(loop.wild_step_encounter_chance("ROUTE_1", "water"))
	if route1_water != 0.0:
		return _fail("Route 1 water chance was %f, wanted 0.0 (sourced rate is 0)." % route1_water)
	var unknown: float = float(loop.wild_step_encounter_chance("NO_SUCH_MAP", "grass"))
	if unknown != 0.0:
		return _fail("an unknown map gave chance %f, wanted 0.0." % unknown)
	var gen3: float = float(loop.rate_byte_to_step_chance(25, "pokefirered_gen3"))
	if absf(gen3 - 0.25) > 0.000001:
		return _fail("Gen 3 conversion of rate 25 gave %f, wanted 0.25 (25 * 16 / 1600)." % gen3)
	var bogus: float = float(loop.rate_byte_to_step_chance(25, "no_such_semantics"))
	if bogus != 0.0:
		return _fail("unknown semantics gave %f, wanted 0.0 (never guess a conversion)." % bogus)
	if _method_arg_count(loop, "wild_encounter_rows") < 2:
		return _fail("OverworldLoop has no wild_encounter_rows(map, terrain) method.")
	var rows: Array = _as_array(loop.wild_encounter_rows("ROUTE_1", "grass"))
	if rows.size() != 10:
		return _fail("Route 1 grass pool has %d rows, wanted the 10 sourced slots." % rows.size())
	var first: Dictionary = _as_dict(rows[0])
	if str(first.get("species", "")) != "PIDGEY":
		return _fail("Route 1 slot 0 species was '%s', wanted PIDGEY (source order)." % str(first.get("species", "")))
	if absf(float(first.get("chance", 0.0)) - 51.0) > 0.000001:
		return _fail("Route 1 slot 0 weight was %s, wanted 51 (probabilities.asm)." % str(first.get("chance", 0.0)))
	return true


## Free supplies: the three static supply trainers from
## data/supply_trainers.json give ordinary supplies and lawful
## healing away at cost 0, in every starting settlement. Claims
## are infinite, money never changes, a Tera Shard claim from
## Vance gives 50, and claiming an item outside a trainer's
## stock is refused.
func test_free_supply_claims() -> bool:
	var shop_script: Variant = _load_class("MartShop")
	if shop_script == null:
		return _fail("MartShop class not found.")
	var shop: Variant = _new_instance(shop_script)
	if shop == null:
		return _fail("MartShop could not be made.")
	if _method_arg_count(shop, "load_supply_trainers_file") != 1:
		return _fail("MartShop has no load_supply_trainers_file(path) method.")
	if _method_arg_count(shop, "claim") != 2:
		return _fail("MartShop has no claim(trainer_id, item_id) method.")
	var trainer_count: int = int(shop.load_supply_trainers_file("res://data/supply_trainers.json"))
	if trainer_count != 3:
		return _fail("load_supply_trainers_file loaded %d trainers, wanted 3." % trainer_count)
	if not _shop_set_money(shop, 500):
		return _fail("MartShop has no money value to set.")
	# A Poke Ball from Kira: bag gains it, money unchanged, cost 0.
	var ball_result: Dictionary = _as_dict(shop.claim("kira", "poke-ball"))
	if not _trade_ok(ball_result):
		return _fail("claiming a Poke Ball from Kira failed: %s" % str(ball_result.get("reason", "")))
	if int(ball_result.get("cost", -1)) != 0:
		return _fail("Kira's Poke Ball claim cost %s, wanted 0." % str(ball_result.get("cost", -1)))
	if _shop_count(shop, "poke-ball") != 1:
		return _fail("after Kira's claim the bag had %d Poke Balls, wanted 1." % _shop_count(shop, "poke-ball"))
	if _shop_get_money(shop) != 500:
		return _fail("Kira's free claim changed the money to %d, wanted 500." % _shop_get_money(shop))
	# A healing item from Haruka, also free.
	var heal_result: Dictionary = _as_dict(shop.claim("haruka", "potion"))
	if not _trade_ok(heal_result):
		return _fail("claiming a Potion from Haruka failed: %s" % str(heal_result.get("reason", "")))
	if int(heal_result.get("cost", -1)) != 0:
		return _fail("Haruka's Potion claim cost %s, wanted 0." % str(heal_result.get("cost", -1)))
	if _shop_count(shop, "potion") != 1:
		return _fail("after Haruka's claim the bag had %d Potions, wanted 1." % _shop_count(shop, "potion"))
	if _shop_get_money(shop) != 500:
		return _fail("Haruka's free claim changed the money to %d, wanted 500." % _shop_get_money(shop))
	# A Tera Shard from Vance gives 50 in one claim.
	var shard_result: Dictionary = _as_dict(shop.claim("vance", "fire-tera-shard"))
	if not _trade_ok(shard_result):
		return _fail("claiming a Fire Tera Shard from Vance failed: %s" % str(shard_result.get("reason", "")))
	if int(shard_result.get("cost", -1)) != 0:
		return _fail("Vance's Tera Shard claim cost %s, wanted 0." % str(shard_result.get("cost", -1)))
	if _shop_count(shop, "fire-tera-shard") != 50:
		return _fail("after Vance's shard claim the bag had %d Fire Tera Shards, wanted 50." % _shop_count(shop, "fire-tera-shard"))
	if _shop_get_money(shop) != 500:
		return _fail("Vance's free claim changed the money to %d, wanted 500." % _shop_get_money(shop))
	# A Mega Stone is Vance stock, not Kira stock: refused, no change.
	var refused: Dictionary = _as_dict(shop.claim("kira", "abomasite"))
	if _trade_ok(refused):
		return _fail("claiming a Mega Stone from Kira worked, but it should be refused.")
	if _shop_count(shop, "abomasite") != 0:
		return _fail("a refused claim still added a Mega Stone to the bag.")
	if _shop_get_money(shop) != 500:
		return _fail("a refused claim changed the money to %d, wanted 500." % _shop_get_money(shop))
	return true


## Scene transitions: a wild encounter goes to the battle scene, a
## closed menu goes back to the scene named in "return_to", and a
## nonsense trigger goes nowhere (empty string).
## resolve_target takes (current_scene, trigger, context). The
## context dict is only used by "close_menu": it may hold
## "return_to" with the short name of the scene to go back to.
func test_scene_resolve() -> bool:
	var trans_script: Variant = _load_class("PUWSceneTransition")
	if trans_script == null:
		return _fail("PUWSceneTransition class not found.")
	var trans: Variant = _new_instance(trans_script)
	if trans == null:
		return _fail("PUWSceneTransition could not be made.")
	var resolve_args: int = _method_arg_count(trans, "resolve_target")
	if resolve_args != 2 and resolve_args != 3:
		return _fail("PUWSceneTransition has no resolve_target(current_scene, trigger, context) method.")
	var battle_scene: Variant = null
	var back: Variant = null
	var nonsense: Variant = null
	if resolve_args == 3:
		battle_scene = trans.resolve_target("overworld", "wild_encounter", {})
		back = trans.resolve_target("party", "close_menu", {"return_to": "overworld"})
		nonsense = trans.resolve_target("overworld", "nonsense_trigger_xyz", {})
	else:
		battle_scene = trans.resolve_target("overworld", "wild_encounter")
		back = trans.resolve_target("party", "close_menu")
		nonsense = trans.resolve_target("overworld", "nonsense_trigger_xyz")
	if str(battle_scene) != "res://scenes/battle.tscn":
		return _fail("wild_encounter from overworld returned '%s', wanted 'res://scenes/battle.tscn'." % str(battle_scene))
	if str(back) != "res://scenes/overworld.tscn":
		return _fail("close_menu from party returned '%s', wanted 'res://scenes/overworld.tscn'." % str(back))
	if str(nonsense) != "":
		return _fail("a nonsense trigger returned '%s', wanted an empty string." % str(nonsense))
	return true
