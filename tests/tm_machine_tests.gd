extends SceneTree
## Headless tests for the TM Machine code prep (SV).
## Real-data tests load data/sv_tm_machine.json (copied into
## the harness at res://data/). Craft success/refusal tests
## use a clearly-labeled FIXTURE registry whose costs are test
## fixtures, not game data — shipped recipes are all stubbed
## (no held source carries SV recipe rows) and must refuse.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const DATA_PATH := "res://data/sv_tm_machine.json"

func _init() -> void:
	print("PUW TM Machine tests — starting.")
	_run("test_registry_integrity", Callable(self, "test_registry_integrity"))
	_run("test_all_shipped_recipes_stubbed", Callable(self, "test_all_shipped_recipes_stubbed"))
	_run("test_materials_census", Callable(self, "test_materials_census"))
	_run("test_stubbed_craft_refused_atomically", Callable(self, "test_stubbed_craft_refused_atomically"))
	_run("test_craft_success_exact", Callable(self, "test_craft_success_exact"))
	_run("test_craft_refusal_no_partial", Callable(self, "test_craft_refusal_no_partial"))
	_run("test_craft_insufficient_lp", Callable(self, "test_craft_insufficient_lp"))
	_run("test_unknown_recipe", Callable(self, "test_unknown_recipe"))
	_run("test_lp_wallet_seam", Callable(self, "test_lp_wallet_seam"))
	_run("test_teach_handoff", Callable(self, "test_teach_handoff"))
	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("FAILED: ", _failed_names)
	quit(1 if _failed > 0 else 0)

func _run(name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_failed_names.append(name)
		print("FAIL: ", name)

func _registry() -> Dictionary:
	return PUWTMMachine.load_registry(DATA_PATH)

func _fixture() -> Dictionary:
	return {"recipes": [{"tm_id": "tm001", "move": "take-down", "lp": 400,
		"materials": [{"material_id": "lechonk-hair", "qty": 3}, {"material_id": "pawmi-fur", "qty": 2}],
		"recipe_status": "sourced_fixture"}],
		"materials": [{"material_id": "lechonk-hair", "drop_source_species": "Lechonk"}]}

func _inv() -> PUWInventoryManager:
	var inv: PUWInventoryManager = PUWInventoryManager.new()
	inv.items = {}
	return inv

func test_registry_integrity() -> bool:
	var reg: Dictionary = _registry()
	var recipes: Array = reg.get("recipes", [])
	if recipes.size() != 230:
		return false
	var first: Dictionary = recipes[0]
	var last: Dictionary = recipes[229]
	if str(first.get("tm_id", "")) != "tm001" or str(last.get("tm_id", "")) != "tm230":
		return false
	# TM001 = Mega Punch (move 5), TM230 = Psychic Noise in the
	# PKHeX MachineMoves order — spot-check both ends + middle.
	if str(first.get("move", "")) != "megapunch":
		return false
	var mid: Dictionary = PUWTMMachine.recipe_for(reg, "tm171")
	return str(mid.get("move", "")) != ""

func test_all_shipped_recipes_stubbed() -> bool:
	var reg: Dictionary = _registry()
	var recipes: Array = reg.get("recipes", [])
	for raw in recipes:
		var r: Dictionary = raw
		if not PUWTMMachine.is_stubbed(r):
			return false
		if r.get("lp") != null:
			return false
	return true

func test_materials_census() -> bool:
	var reg: Dictionary = _registry()
	var mats: Array = reg.get("materials", [])
	if mats.size() != 222:
		return false
	if PUWTMMachine.drop_source_species(reg, "lechonk-hair") != "Lechonk":
		return false
	var rec: Dictionary = PUWTMMachine.material_record(reg, "lechonk-hair")
	if rec.get("drop_rate") != null:
		return false
	return PUWTMMachine.drop_source_species(reg, "no-such-material") == ""

func test_stubbed_craft_refused_atomically() -> bool:
	var reg: Dictionary = _registry()
	var inv: PUWInventoryManager = _inv()
	inv.add_item("lechonk-hair", 5)
	var wallet: Dictionary = {"lp": 9999}
	var logs: Array = []
	var res: Dictionary = PUWTMMachine.craft(reg, "tm001", inv, wallet, logs)
	if bool(res.get("ok", true)) or str(res.get("reason", "")) != "recipe_stubbed":
		return false
	return inv.count_item("lechonk-hair") == 5 and int(wallet["lp"]) == 9999 and inv.count_item("tm001") == 0

func test_craft_success_exact() -> bool:
	var inv: PUWInventoryManager = _inv()
	inv.add_item("lechonk-hair", 5)
	inv.add_item("pawmi-fur", 2)
	var wallet: Dictionary = {"lp": 1000}
	var logs: Array = []
	var res: Dictionary = PUWTMMachine.craft(_fixture(), "tm001", inv, wallet, logs)
	if not bool(res.get("ok", false)):
		return false
	return inv.count_item("lechonk-hair") == 2 and inv.count_item("pawmi-fur") == 0 \
		and int(wallet["lp"]) == 600 and inv.count_item("tm001") == 1

func test_craft_refusal_no_partial() -> bool:
	var inv: PUWInventoryManager = _inv()
	inv.add_item("lechonk-hair", 5) # second material missing entirely
	var wallet: Dictionary = {"lp": 1000}
	var logs: Array = []
	var res: Dictionary = PUWTMMachine.craft(_fixture(), "tm001", inv, wallet, logs)
	if bool(res.get("ok", true)) or str(res.get("reason", "")) != "insufficient_materials":
		return false
	return inv.count_item("lechonk-hair") == 5 and int(wallet["lp"]) == 1000 and inv.count_item("tm001") == 0

func test_craft_insufficient_lp() -> bool:
	var inv: PUWInventoryManager = _inv()
	inv.add_item("lechonk-hair", 3)
	inv.add_item("pawmi-fur", 2)
	var wallet: Dictionary = {"lp": 399}
	var logs: Array = []
	var res: Dictionary = PUWTMMachine.craft(_fixture(), "tm001", inv, wallet, logs)
	if bool(res.get("ok", true)) or str(res.get("reason", "")) != "insufficient_lp":
		return false
	return inv.count_item("lechonk-hair") == 3 and int(wallet["lp"]) == 399 and inv.count_item("tm001") == 0

func test_unknown_recipe() -> bool:
	var inv: PUWInventoryManager = _inv()
	var wallet: Dictionary = {"lp": 100}
	var logs: Array = []
	var res: Dictionary = PUWTMMachine.craft(_fixture(), "tm999", inv, wallet, logs)
	return not bool(res.get("ok", true)) and str(res.get("reason", "")) == "no_recipe"

func test_lp_wallet_seam() -> bool:
	var wallet: Dictionary = {"lp": 0}
	if PUWTMMachine.lp_add(wallet, 250) != 250:
		return false
	if not PUWTMMachine.lp_spend(wallet, 200):
		return false
	if PUWTMMachine.lp_spend(wallet, 100):
		return false
	return int(wallet["lp"]) == 50

func test_teach_handoff() -> bool:
	var reg: Dictionary = _registry()
	var table: Dictionary = PUWTMMachine.sv_machine_table(reg)
	if table.size() != 230 or str(table.get("tm001", "")) != "megapunch":
		return false
	var mon: Dictionary = {"species": "pikachu", "moves": ["tackle"]}
	var logs: Array = []
	var can: Callable = func(species: String, mv: String) -> bool: return true
	var res: Dictionary = PUWTMMachine.teach_crafted(mon, "tm001", reg, can, -1, logs)
	if not bool(res.get("ok", false)):
		return false
	var moves: Array = mon.get("moves", [])
	return moves.has("megapunch")
