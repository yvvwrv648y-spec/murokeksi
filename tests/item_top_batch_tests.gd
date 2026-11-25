extends SceneTree
## Headless tests for the item top-batch use-path prep
## (staging hidden_files/code_prep_items) — the class-(b) bag
## use paths of the item triage TOP_BATCH (97 small-hook items
## + 3 Kanto fossils), plus the Tera Shards the brief names as
## the pattern's model.
##
## Run with Godot 4.7.2:
##   godot --headless --path <harness project> --script res://tests/item_top_batch_tests.gd
##
## Prints one PASS or FAIL line per test, then a summary, then
## quits. Exit code 0 = all passed, 1 = at least one failed.
## Every implemented item has at least one test; items that
## turned out not to be use paths (the fossils, class (c)) are
## tested to still refuse, which is their honest status.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW item top-batch use-path tests — starting.")
	if root == null:
		print("FAIL: no scene tree root.")
		quit(1)
		return
	_run("test_fresh_water", Callable(self, "test_fresh_water"))
	_run("test_soda_pop", Callable(self, "test_soda_pop"))
	_run("test_lemonade", Callable(self, "test_lemonade"))
	_run("test_moomoo_milk", Callable(self, "test_moomoo_milk"))
	_run("test_energy_root", Callable(self, "test_energy_root"))
	_run("test_lava_cookie", Callable(self, "test_lava_cookie"))
	_run("test_cheri_berry_bag", Callable(self, "test_cheri_berry_bag"))
	_run("test_pecha_berry_bag", Callable(self, "test_pecha_berry_bag"))
	_run("test_rawst_berry_bag", Callable(self, "test_rawst_berry_bag"))
	_run("test_aspear_berry_bag", Callable(self, "test_aspear_berry_bag"))
	_run("test_chesto_berry_bag", Callable(self, "test_chesto_berry_bag"))
	_run("test_persim_berry_bag", Callable(self, "test_persim_berry_bag"))
	_run("test_pomeg_berry", Callable(self, "test_pomeg_berry"))
	_run("test_kelpsy_berry", Callable(self, "test_kelpsy_berry"))
	_run("test_qualot_berry", Callable(self, "test_qualot_berry"))
	_run("test_hondew_berry", Callable(self, "test_hondew_berry"))
	_run("test_grepa_berry", Callable(self, "test_grepa_berry"))
	_run("test_tamato_berry", Callable(self, "test_tamato_berry"))
	_run("test_revival_herb", Callable(self, "test_revival_herb"))
	_run("test_x_attack", Callable(self, "test_x_attack"))
	_run("test_x_defense", Callable(self, "test_x_defense"))
	_run("test_x_speed", Callable(self, "test_x_speed"))
	_run("test_x_sp_atk", Callable(self, "test_x_sp_atk"))
	_run("test_dire_hit", Callable(self, "test_dire_hit"))
	_run("test_ether", Callable(self, "test_ether"))
	_run("test_max_ether", Callable(self, "test_max_ether"))
	_run("test_elixir", Callable(self, "test_elixir"))
	_run("test_pp_up", Callable(self, "test_pp_up"))
	_run("test_ability_capsule", Callable(self, "test_ability_capsule"))
	_run("test_ability_patch", Callable(self, "test_ability_patch"))
	_run("test_rare_candy", Callable(self, "test_rare_candy"))
	_run("test_sacred_ash", Callable(self, "test_sacred_ash"))
	_run("test_tera_shard_all_types", Callable(self, "test_tera_shard_all_types"))
	_run("test_tera_shard_negatives", Callable(self, "test_tera_shard_negatives"))
	_run("test_repel_steps_table", Callable(self, "test_repel_steps_table"))
	_run("test_habitat_repel", Callable(self, "test_habitat_repel"))
	_run("test_guarantees_escape", Callable(self, "test_guarantees_escape"))
	_run("test_escape_rope", Callable(self, "test_escape_rope"))
	_run("test_fossils_are_not_a_use_path", Callable(self, "test_fossils_are_not_a_use_path"))
	_run("test_regression_existing_items", Callable(self, "test_regression_existing_items"))
	_run("test_effect_text", Callable(self, "test_effect_text"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
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


## A plain test mon. Overrides are merged over the defaults.
func _mon(overrides: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": "Testmon", "hp": 50, "max_hp": 100, "status": "",
		"confused": false, "confusion_turns": 0,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
		"moves": [], "pp": {}, "pp_max": {},
		"level": 5, "exp": 0, "friendship": 100, "evs": {},
		"ability": "Run Away", "item": "",
	}
	for key in overrides.keys():
		mon[key] = overrides[key]
	return mon


# ------------------------------------------------------------------
# Healing drinks
# ------------------------------------------------------------------

func test_fresh_water() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 10})
	if not ItemEngine.use_battle_item("Fresh Water", mon, logs):
		return false
	if int(mon.get("hp", 0)) != 60:
		return false
	var full: Dictionary = _mon({"hp": 100})
	if ItemEngine.use_battle_item("fresh-water", full, logs):
		return false
	var fainted: Dictionary = _mon({"hp": 0})
	return not ItemEngine.use_battle_item("Fresh Water", fainted, logs)


func test_soda_pop() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 10})
	if not ItemEngine.use_battle_item("Soda Pop", mon, logs):
		return false
	return int(mon.get("hp", 0)) == 70


func test_lemonade() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 10})
	if not ItemEngine.use_battle_item("Lemonade", mon, logs):
		return false
	return int(mon.get("hp", 0)) == 90


func test_moomoo_milk() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 30})
	if not ItemEngine.use_battle_item("Moomoo Milk", mon, logs):
		return false
	return int(mon.get("hp", 0)) == 100


func test_energy_root() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 5, "max_hp": 300, "friendship": 100})
	if not ItemEngine.use_battle_item("Energy Root", mon, logs):
		return false
	if int(mon.get("hp", 0)) != 205:
		return false
	return int(mon.get("friendship", 0)) == 99


# ------------------------------------------------------------------
# Status cures: Lava Cookie and the bag-used cure Berries
# ------------------------------------------------------------------

func test_lava_cookie() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "BRN", "confused": true, "confusion_turns": 3})
	if not ItemEngine.use_battle_item("Lava Cookie", mon, logs):
		return false
	if str(mon.get("status", "")) != "" or bool(mon.get("confused", false)):
		return false
	var healthy: Dictionary = _mon()
	return not ItemEngine.use_battle_item("Lava Cookie", healthy, logs)


func test_cheri_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "PAR"})
	if not ItemEngine.use_battle_item("Cheri Berry", mon, logs):
		return false
	if str(mon.get("status", "")) != "":
		return false
	var wrong: Dictionary = _mon({"status": "BRN"})
	return not ItemEngine.use_battle_item("Cheri Berry", wrong, logs)


func test_pecha_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "PSN"})
	if not ItemEngine.use_battle_item("Pecha Berry", mon, logs):
		return false
	if str(mon.get("status", "")) != "":
		return false
	var tox: Dictionary = _mon({"status": "TOX"})
	if not ItemEngine.use_battle_item("Pecha Berry", tox, logs):
		return false
	return str(tox.get("status", "")) == ""


func test_rawst_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "BRN"})
	if not ItemEngine.use_battle_item("Rawst Berry", mon, logs):
		return false
	return str(mon.get("status", "")) == ""


func test_aspear_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "FRZ"})
	if not ItemEngine.use_battle_item("Aspear Berry", mon, logs):
		return false
	return str(mon.get("status", "")) == ""


func test_chesto_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"status": "SLP"})
	if not ItemEngine.use_battle_item("Chesto Berry", mon, logs):
		return false
	return str(mon.get("status", "")) == ""


func test_persim_berry_bag() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"confused": true, "confusion_turns": 2})
	if not ItemEngine.use_battle_item("Persim Berry", mon, logs):
		return false
	if bool(mon.get("confused", false)) or int(mon.get("confusion_turns", 0)) != 0:
		return false
	var clear: Dictionary = _mon()
	return not ItemEngine.use_battle_item("Persim Berry", clear, logs)


# ------------------------------------------------------------------
# EV Berries
# ------------------------------------------------------------------

func _ev_berry_check(item: String, ev_key: String) -> bool:
	var logs: Array = []
	var evs: Dictionary = {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	evs[ev_key] = 100
	var mon: Dictionary = _mon({"evs": evs, "friendship": 50})
	if not ItemEngine.use_battle_item(item, mon, logs):
		return false
	var after: Dictionary = mon.get("evs", {})
	if int(after.get(ev_key, 0)) != 90:
		return false
	if int(mon.get("friendship", 0)) != 51:
		return false
	var empty_evs: Dictionary = {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var zero: Dictionary = _mon({"evs": empty_evs})
	return not ItemEngine.use_battle_item(item, zero, logs)


func test_pomeg_berry() -> bool:
	return _ev_berry_check("Pomeg Berry", "hp")


func test_kelpsy_berry() -> bool:
	return _ev_berry_check("Kelpsy Berry", "atk")


func test_qualot_berry() -> bool:
	return _ev_berry_check("Qualot Berry", "def")


func test_hondew_berry() -> bool:
	return _ev_berry_check("Hondew Berry", "spa")


func test_grepa_berry() -> bool:
	return _ev_berry_check("Grepa Berry", "spd")


func test_tamato_berry() -> bool:
	if not _ev_berry_check("Tamato Berry", "spe"):
		return false
	# Floor: 5 EVs drop to 0, never negative.
	var logs: Array = []
	var mon: Dictionary = _mon({"evs": {"spe": 5}})
	if not ItemEngine.use_battle_item("Tamato Berry", mon, logs):
		return false
	var after: Dictionary = mon.get("evs", {})
	return int(after.get("spe", -1)) == 0


# ------------------------------------------------------------------
# Revival Herb, X items, Dire Hit
# ------------------------------------------------------------------

func test_revival_herb() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 0, "friendship": 100})
	if not ItemEngine.use_battle_item("Revival Herb", mon, logs):
		return false
	if int(mon.get("hp", 0)) != 100:
		return false
	if int(mon.get("friendship", 0)) != 99:
		return false
	var living: Dictionary = _mon({"hp": 10})
	return not ItemEngine.use_battle_item("Revival Herb", living, logs)


func _x_item_check(item: String, stage_key: String) -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon()
	if not ItemEngine.use_battle_item(item, mon, logs):
		return false
	var stages: Dictionary = mon.get("stages", {})
	if int(stages.get(stage_key, 0)) != 2:
		return false
	var maxed_stages: Dictionary = {"atk": 6, "def": 6, "spa": 6, "spd": 6, "spe": 6}
	var maxed: Dictionary = _mon({"stages": maxed_stages})
	return not ItemEngine.use_battle_item(item, maxed, logs)


func test_x_attack() -> bool:
	return _x_item_check("X Attack", "atk")


func test_x_defense() -> bool:
	return _x_item_check("X Defense", "def")


func test_x_speed() -> bool:
	return _x_item_check("X Speed", "spe")


func test_x_sp_atk() -> bool:
	# Canonical registry id form: the engine's documented _norm
	# has never stripped periods, so the punctuated display
	# spelling "X Sp. Atk" matches nothing in this engine (a
	# pre-existing convention, recorded in PREP_REPORT.md); the
	# bag passes canonical ids.
	return _x_item_check("x-sp-atk", "spa")


func test_dire_hit() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon()
	if ItemEngine.crit_stage_bonus(mon) != 0:
		return false
	if not ItemEngine.use_battle_item("Dire Hit", mon, logs):
		return false
	if ItemEngine.crit_stage_bonus(mon) != 2:
		return false
	return not ItemEngine.use_battle_item("Dire Hit", mon, logs)


# ------------------------------------------------------------------
# PP items
# ------------------------------------------------------------------

func test_ether() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({
		"moves": ["Tackle", "Growl"],
		"pp": {"Tackle": 3, "Growl": 40}, "pp_max": {"Tackle": 35, "Growl": 40},
	})
	if not ItemEngine.use_battle_item("Ether", mon, logs, {"move": "Tackle"}):
		return false
	var pp: Dictionary = mon.get("pp", {})
	if int(pp.get("Tackle", 0)) != 13:
		return false
	# Without a chosen move, the first move below its max is picked.
	var auto: Dictionary = _mon({
		"moves": ["Tackle", "Growl"],
		"pp": {"Tackle": 35, "Growl": 12}, "pp_max": {"Tackle": 35, "Growl": 40},
	})
	if not ItemEngine.use_battle_item("Ether", auto, logs):
		return false
	var auto_pp: Dictionary = auto.get("pp", {})
	return int(auto_pp.get("Growl", 0)) == 22


func test_max_ether() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({
		"moves": ["Tackle"], "pp": {"Tackle": 2}, "pp_max": {"Tackle": 35},
	})
	if not ItemEngine.use_battle_item("Max Ether", mon, logs, {"move": "Tackle"}):
		return false
	var pp: Dictionary = mon.get("pp", {})
	if int(pp.get("Tackle", 0)) != 35:
		return false
	if ItemEngine.use_battle_item("Max Ether", mon, logs, {"move": "Tackle"}):
		return false
	# No recorded max PP: "full" is unknowable, so it refuses.
	var no_cap: Dictionary = _mon({"moves": ["Tackle"], "pp": {"Tackle": 2}, "pp_max": {}})
	return not ItemEngine.use_battle_item("Max Ether", no_cap, logs, {"move": "Tackle"})


func test_elixir() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({
		"moves": ["Tackle", "Growl"],
		"pp": {"Tackle": 0, "Growl": 5}, "pp_max": {"Tackle": 35, "Growl": 40},
	})
	if not ItemEngine.use_battle_item("Elixir", mon, logs):
		return false
	var pp: Dictionary = mon.get("pp", {})
	if int(pp.get("Tackle", 0)) != 10 or int(pp.get("Growl", 0)) != 15:
		return false
	var full: Dictionary = _mon({
		"moves": ["Tackle"], "pp": {"Tackle": 35}, "pp_max": {"Tackle": 35},
	})
	return not ItemEngine.use_battle_item("Elixir", full, logs)


func test_pp_up() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({
		"moves": ["Tackle"], "pp": {"Tackle": 35}, "pp_max": {"Tackle": 35},
	})
	# Base 35: each PP Up adds floor(35 * 0.2) = 7, at most 3 times.
	var want: Array = [42, 49, 56]
	for step in range(3):
		if not ItemEngine.use_battle_item("PP Up", mon, logs, {"move": "Tackle"}):
			return false
		var pp_max: Dictionary = mon.get("pp_max", {})
		if int(pp_max.get("Tackle", 0)) != int(want[step]):
			return false
	if ItemEngine.use_battle_item("PP Up", mon, logs, {"move": "Tackle"}):
		return false
	var base_map: Dictionary = mon.get("pp_base", {})
	if int(base_map.get("Tackle", 0)) != 35:
		return false
	# No chosen move: refuses.
	var no_move: Dictionary = _mon({"moves": ["Tackle"], "pp_max": {"Tackle": 35}})
	return not ItemEngine.use_battle_item("PP Up", no_move, logs)


# ------------------------------------------------------------------
# Ability Capsule / Patch, Rare Candy, Sacred Ash
# ------------------------------------------------------------------

func test_ability_capsule() -> bool:
	var logs: Array = []
	var ctx: Dictionary = {"species_abilities": ["Run Away", "Adaptability"]}
	var mon: Dictionary = _mon({"ability": "Run Away"})
	if not ItemEngine.use_battle_item("Ability Capsule", mon, logs, ctx):
		return false
	if str(mon.get("ability", "")) != "Adaptability":
		return false
	if not ItemEngine.use_battle_item("Ability Capsule", mon, logs, ctx):
		return false
	if str(mon.get("ability", "")) != "Run Away":
		return false
	# A mon whose current ability is the Hidden one is refused.
	var hidden_holder: Dictionary = _mon({"ability": "Anticipation"})
	if ItemEngine.use_battle_item("Ability Capsule", hidden_holder, logs, ctx):
		return false
	# One non-Hidden ability: nothing to switch to.
	var single: Dictionary = _mon({"ability": "Static"})
	return not ItemEngine.use_battle_item("Ability Capsule", single, logs, {"species_abilities": ["Static"]})


func test_ability_patch() -> bool:
	var logs: Array = []
	var ctx: Dictionary = {"hidden_ability": "Anticipation"}
	var mon: Dictionary = _mon({"ability": "Run Away"})
	if not ItemEngine.use_battle_item("Ability Patch", mon, logs, ctx):
		return false
	if str(mon.get("ability", "")) != "Anticipation":
		return false
	if ItemEngine.use_battle_item("Ability Patch", mon, logs, ctx):
		return false
	var no_ctx: Dictionary = _mon({"ability": "Run Away"})
	return not ItemEngine.use_battle_item("Ability Patch", no_ctx, logs)


func test_rare_candy() -> bool:
	var logs: Array = []
	var ctx: Dictionary = {"growth_rate": "medium-fast", "badges": 8}
	var mon: Dictionary = _mon({"level": 5, "exp": 125})
	if not ItemEngine.use_battle_item("Rare Candy", mon, logs, ctx):
		return false
	if int(mon.get("level", 0)) != 6:
		return false
	# Medium Fast: level 6 needs 6^3 = 216 total EXP.
	if int(mon.get("exp", 0)) != 216:
		return false
	# Badge hard cap: 0 badges cap at 10, so a Lv. 10 mon refuses.
	var capped: Dictionary = _mon({"level": 10, "exp": 1000})
	if ItemEngine.use_battle_item("Rare Candy", capped, logs, {"growth_rate": "medium-fast", "badges": 0}):
		return false
	# Banked EXP is never taken away.
	var banked: Dictionary = _mon({"level": 5, "exp": 999999})
	if not ItemEngine.use_battle_item("Rare Candy", banked, logs, ctx):
		return false
	if int(banked.get("exp", 0)) != 999999 or int(banked.get("level", 0)) != 6:
		return false
	var maxed: Dictionary = _mon({"level": 100, "exp": 1000000})
	return not ItemEngine.use_battle_item("Rare Candy", maxed, logs, ctx)


func test_sacred_ash() -> bool:
	var logs: Array = []
	var a: Dictionary = _mon({"name": "A", "hp": 0, "max_hp": 80})
	var b: Dictionary = _mon({"name": "B", "hp": 30, "max_hp": 90})
	var c: Dictionary = _mon({"name": "C", "hp": 0, "max_hp": 120})
	var party: Array = [a, b, c]
	if not ItemEngine.use_battle_item("Sacred Ash", b, logs, {"party": party}):
		return false
	if int(a.get("hp", 0)) != 80 or int(c.get("hp", 0)) != 120:
		return false
	if int(b.get("hp", 0)) != 30:
		return false
	if ItemEngine.use_battle_item("Sacred Ash", b, logs, {"party": party}):
		return false
	return not ItemEngine.use_battle_item("Sacred Ash", b, logs)


# ------------------------------------------------------------------
# Tera Shards
# ------------------------------------------------------------------

func test_tera_shard_all_types() -> bool:
	var logs: Array = []
	var table: Dictionary = {
		"normal-tera-shard": "Normal", "fire-tera-shard": "Fire",
		"water-tera-shard": "Water", "electric-tera-shard": "Electric",
		"grass-tera-shard": "Grass", "ice-tera-shard": "Ice",
		"fighting-tera-shard": "Fighting", "poison-tera-shard": "Poison",
		"ground-tera-shard": "Ground", "flying-tera-shard": "Flying",
		"psychic-tera-shard": "Psychic", "bug-tera-shard": "Bug",
		"rock-tera-shard": "Rock", "ghost-tera-shard": "Ghost",
		"dragon-tera-shard": "Dragon", "dark-tera-shard": "Dark",
		"steel-tera-shard": "Steel", "fairy-tera-shard": "Fairy",
	}
	if table.size() != 18:
		return false
	for shard_id in table.keys():
		var inventory: PUWInventoryManager = PUWInventoryManager.new()
		inventory.add_item(shard_id, 50)
		var mon: Dictionary = _mon()
		if not ItemEngine.use_tera_shard(shard_id, mon, inventory, logs):
			return false
		if str(mon.get("tera_type", "")) != str(table[shard_id]):
			return false
		if inventory.count_item(shard_id) != 0:
			return false
		inventory.free()
	return true


func test_tera_shard_negatives() -> bool:
	var logs: Array = []
	# 49 shards: refuses, consumes nothing, writes nothing.
	var short_inv: PUWInventoryManager = PUWInventoryManager.new()
	short_inv.add_item("fire-tera-shard", 49)
	var mon: Dictionary = _mon()
	if ItemEngine.use_tera_shard("fire-tera-shard", mon, short_inv, logs):
		return false
	if short_inv.count_item("fire-tera-shard") != 49:
		return false
	if str(mon.get("tera_type", "")) != "":
		return false
	short_inv.free()
	# Already that Tera type: refuses, consumes nothing.
	var full_inv: PUWInventoryManager = PUWInventoryManager.new()
	full_inv.add_item("fire-tera-shard", 50)
	var typed: Dictionary = _mon({"tera_type": "Fire"})
	if ItemEngine.use_tera_shard("Fire Tera Shard", typed, full_inv, logs):
		return false
	if full_inv.count_item("fire-tera-shard") != 50:
		return false
	# Changing to a different type works and costs another 50.
	full_inv.add_item("water-tera-shard", 50)
	if not ItemEngine.use_tera_shard("water-tera-shard", typed, full_inv, logs):
		return false
	if str(typed.get("tera_type", "")) != "Water":
		return false
	# Not a shard at all.
	if ItemEngine.use_tera_shard("Potion", typed, full_inv, logs):
		return false
	full_inv.free()
	return ItemEngine.tera_type_for_shard("Potion") == ""


# ------------------------------------------------------------------
# Repels, escape items, Escape Rope
# ------------------------------------------------------------------

func test_repel_steps_table() -> bool:
	if ItemEngine.repel_steps_for("Repel") != 100:
		return false
	if ItemEngine.repel_steps_for("Super Repel") != 200:
		return false
	if ItemEngine.repel_steps_for("max-repel") != 250:
		return false
	return ItemEngine.repel_steps_for("Potion") == 0


func test_habitat_repel() -> bool:
	var habitat: PUWHabitatEncounters = PUWHabitatEncounters.new()
	if habitat.repel_active():
		return false
	habitat.apply_repel(ItemEngine.repel_steps_for("Repel"))
	if not habitat.repel_active() or habitat.repel_steps_remaining() != 100:
		return false
	# Strictly lower levels are blocked; equal or higher are not.
	if not habitat.repel_would_block(5, 10):
		return false
	if habitat.repel_would_block(10, 10):
		return false
	if habitat.repel_would_block(12, 10):
		return false
	# A shorter Repel never shortens the active one.
	habitat.apply_repel(50)
	if habitat.repel_steps_remaining() != 100:
		return false
	# Save / restore round trip.
	var saved: Dictionary = habitat.attach_repel_to_save({})
	var restored: PUWHabitatEncounters = PUWHabitatEncounters.new()
	restored.restore_repel_from_save(saved)
	if restored.repel_steps_remaining() != 100:
		return false
	# Steps tick down to a clean stop.
	for i in range(100):
		habitat.tick_repel_step()
	if habitat.repel_active():
		return false
	return not habitat.repel_would_block(1, 100)


func test_guarantees_escape() -> bool:
	# Canonical id form (see test_x_sp_atk's note on _norm).
	if not ItemEngine.guarantees_escape("poke-doll"):
		return false
	if not ItemEngine.guarantees_escape("fluffy-tail"):
		return false
	return not ItemEngine.guarantees_escape("Potion")


func test_escape_rope() -> bool:
	if not ItemEngine.is_escape_rope("Escape Rope"):
		return false
	if ItemEngine.is_escape_rope("Repel"):
		return false
	var loader: PUWMapLoader = PUWMapLoader.new()
	if not loader.escape_rope_target().is_empty():
		return false
	loader.record_entrance("PalletTown", 2)
	var target: Dictionary = loader.escape_rope_target()
	if str(target.get("map", "")) != "PalletTown" or int(target.get("warp_id", 0)) != 2:
		return false
	loader.clear_entrance()
	var cleared: bool = loader.escape_rope_target().is_empty()
	loader.free()
	return cleared


# ------------------------------------------------------------------
# Honest non-implementations and regressions
# ------------------------------------------------------------------

func test_fossils_are_not_a_use_path() -> bool:
	# The three Kanto fossils are the top batch's only class-(c)
	# rows: they belong to a fossil revival SERVICE (an NPC/lab
	# interaction), not to any bag use path. use_battle_item
	# must keep refusing them until that service exists.
	var logs: Array = []
	var mon: Dictionary = _mon()
	if ItemEngine.use_battle_item("Dome Fossil", mon, logs):
		return false
	if ItemEngine.use_battle_item("Helix Fossil", mon, logs):
		return false
	return not ItemEngine.use_battle_item("Old Amber", mon, logs)


func test_regression_existing_items() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"hp": 50})
	if not ItemEngine.use_battle_item("Potion", mon, logs):
		return false
	if int(mon.get("hp", 0)) != 70:
		return false
	var fainted: Dictionary = _mon({"hp": 0})
	if not ItemEngine.use_battle_item("Revive", fainted, logs):
		return false
	if int(fainted.get("hp", 0)) != 50:
		return false
	var hurt: Dictionary = _mon({"hp": 10, "status": "PAR"})
	if not ItemEngine.use_battle_item("Full Heal", hurt, logs):
		return false
	if str(hurt.get("status", "")) != "":
		return false
	return not ItemEngine.use_battle_item("No Such Item", mon, logs)


func test_effect_text() -> bool:
	if ItemEngine.get_item_effect_text("Potion") != "Restores 20 HP.":
		return false
	if ItemEngine.get_item_effect_text("Fresh Water") != "Restores 50 HP.":
		return false
	if ItemEngine.get_item_effect_text("PP Up") != "Raises a move’s max PP by 20%.":
		return false
	# Honest gaps: no effect_short exists for these in the
	# source data, so no text is invented for them.
	if ItemEngine.get_item_effect_text("Ability Patch") != "":
		return false
	return ItemEngine.get_item_effect_text("Fire Tera Shard") == ""
