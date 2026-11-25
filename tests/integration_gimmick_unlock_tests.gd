extends SceneTree
## Gimmick progression-unlock tests (Riley canon, 2026-11-22):
## every gimmick family is locked until reached in the journey;
## in Kanto no gimmick is active. The battle tests drive a REAL
## BattleController battle through PUWGimmickUnlocks
## .attempt_gimmick, the integration layer's mandatory pre-check
## in front of BattleController._apply_gimmick.
## Run: godot --headless --script res://tests/integration_gimmick_unlock_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW integration gimmick unlock tests — starting.")
	_run("test_default_flags_all_locked", Callable(self, "test_default_flags_all_locked"))
	_run("test_missing_key_means_all_locked", Callable(self, "test_missing_key_means_all_locked"))
	_run("test_budget_to_family_mapping", Callable(self, "test_budget_to_family_mapping"))
	_run("test_simulation_always_allowed", Callable(self, "test_simulation_always_allowed"))
	_run("test_set_flag_returns_new_state", Callable(self, "test_set_flag_returns_new_state"))
	_run("test_mega_refused_in_fresh_kanto_battle", Callable(self, "test_mega_refused_in_fresh_kanto_battle"))
	_run("test_mega_allowed_after_unlock_consumes_budget", Callable(self, "test_mega_allowed_after_unlock_consumes_budget"))
	_run("test_save_round_trip_default_flags", Callable(self, "test_save_round_trip_default_flags"))
	_run("test_save_round_trip_mega_true", Callable(self, "test_save_round_trip_mega_true"))
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = bool(test.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _mon(mon_name: String, types: Array, moves: Array, extra: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": 50, "hp": 100, "max_hp": 100,
		"atk": 100, "def": 50, "spa": 200, "spd": 50, "spe": 100,
		"types": types, "ability": "", "item": "", "status": "",
		"moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for key_value: Variant in extra.keys():
		var key: String = str(key_value)
		mon[key] = extra[key]
	return mon


func _new_controller() -> BattleController:
	var controller: BattleController = BattleController.new()
	root.add_child(controller)
	return controller


## A fresh Kanto save state through PUWSaveManager.build_state,
## with the default (all-locked) gimmick flags installed.
func _kanto_state() -> Dictionary:
	var story_flags: Dictionary = {"region_id": "kanto", "gimmick_unlocks": PUWGimmickUnlocks.default_flags()}
	return PUWSaveManager.build_state([], [], {}, 0, [], [], [], story_flags, {"name": "Test"})


func _player_mega_budget(battle: BattleController) -> bool:
	var budgets: Dictionary = battle.battle_state.get("gimmick_budgets", {})
	var player_budgets: Dictionary = budgets.get("player", {})
	return bool(player_budgets.get("mega", false))


func test_default_flags_all_locked() -> bool:
	var flags: Dictionary = PUWGimmickUnlocks.default_flags()
	if flags.size() != 4:
		print("  default_flags size %d, want 4" % flags.size())
		return false
	for family_value: Variant in PUWGimmickUnlocks.FAMILIES:
		var family: String = str(family_value)
		if bool(flags.get(family, true)):
			print("  family " + family + " defaults to unlocked")
			return false
	return true


func test_missing_key_means_all_locked() -> bool:
	# A state with no story_flags at all, and one whose
	# story_flags lack the gimmick_unlocks key: both all locked.
	var bare: Dictionary = PUWSaveManager.build_state([], [], {}, 0, [], [], [], {}, {})
	var flags: Dictionary = PUWGimmickUnlocks.read_flags(bare)
	for family_value: Variant in PUWGimmickUnlocks.FAMILIES:
		if bool(flags.get(str(family_value), true)):
			print("  missing key defaulted a family to unlocked")
			return false
	for budget_value: Variant in ["mega", "zmove", "dynamax", "gigantamax", "tera"]:
		var budget_key: String = str(budget_value)
		if PUWGimmickUnlocks.is_budget_allowed(budget_key, bare, false):
			print("  budget " + budget_key + " allowed with no flags in state")
			return false
	if PUWGimmickUnlocks.is_budget_allowed("bogus", bare, false):
		print("  unknown budget key allowed")
		return false
	return true


func test_budget_to_family_mapping() -> bool:
	var expected: Dictionary = {"mega": "mega", "zmove": "z_move", "dynamax": "dynamax", "gigantamax": "dynamax", "tera": "terastallization"}
	for key_value: Variant in expected.keys():
		var budget_key: String = str(key_value)
		if PUWGimmickUnlocks.family_for_budget(budget_key) != str(expected[key_value]):
			print("  budget " + budget_key + " mapped to " + PUWGimmickUnlocks.family_for_budget(budget_key))
			return false
	# Unlocking dynamax allows BOTH dynamax and gigantamax
	# budgets; unlocking tera allows only tera.
	var state: Dictionary = PUWGimmickUnlocks.set_flag(_kanto_state(), "dynamax", true)
	if not PUWGimmickUnlocks.is_budget_allowed("dynamax", state, false):
		return false
	if not PUWGimmickUnlocks.is_budget_allowed("gigantamax", state, false):
		print("  gigantamax budget not covered by the dynamax family flag")
		return false
	if PUWGimmickUnlocks.is_budget_allowed("tera", state, false):
		print("  tera allowed by the dynamax flag")
		return false
	return true


func test_simulation_always_allowed() -> bool:
	var state: Dictionary = _kanto_state()
	for budget_value: Variant in ["mega", "zmove", "dynamax", "gigantamax", "tera"]:
		var budget_key: String = str(budget_value)
		if not PUWGimmickUnlocks.is_budget_allowed(budget_key, state, true):
			print("  simulation should allow budget " + budget_key + " (VEXA sim exemption)")
			return false
	return true


func test_set_flag_returns_new_state() -> bool:
	var state: Dictionary = _kanto_state()
	var updated: Dictionary = PUWGimmickUnlocks.set_flag(state, "mega", true)
	var new_flags: Dictionary = PUWGimmickUnlocks.read_flags(updated)
	if not bool(new_flags.get("mega", false)):
		print("  set_flag did not set mega on the returned state")
		return false
	if bool(new_flags.get("z_move", true)) or bool(new_flags.get("dynamax", true)) or bool(new_flags.get("terastallization", true)):
		print("  set_flag unlocked more than mega")
		return false
	var old_flags: Dictionary = PUWGimmickUnlocks.read_flags(state)
	if bool(old_flags.get("mega", true)):
		print("  set_flag mutated the caller's state")
		return false
	return true


## The core refusal: a REAL BattleController battle, a fresh
## Kanto save state, and a Mega attempt through the gate. The
## attempt is refused, the reason names the lock, the player's
## mega budget stays unused, and Charizard does not mega evolve.
func test_mega_refused_in_fresh_kanto_battle() -> bool:
	var battle: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	battle.start_battle([charizard], [foe], "singles")
	var action: Dictionary = {"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}
	var result: Dictionary = PUWGimmickUnlocks.attempt_gimmick(battle, "mega", _kanto_state(), false, action, true)
	if bool(result.get("allowed", true)):
		print("  Mega attempt was allowed in a fresh Kanto state")
		return false
	var reason: String = str(result.get("reason", ""))
	if not reason.to_lower().contains("locked"):
		print("  refusal reason does not name the lock: " + reason)
		return false
	if bool(battle.player_party[0].get("mega_evolved", false)):
		print("  Charizard mega evolved despite the lock")
		return false
	if _player_mega_budget(battle):
		print("  the player's mega budget was spent despite the lock")
		return false
	return true


## After set_flag(..., "mega", true) on a COPY of the state
## (test-only), the same attempt through the same gate is
## allowed, the engine really mega evolves Charizard, and the
## player's mega budget is consumed.
func test_mega_allowed_after_unlock_consumes_budget() -> bool:
	var battle: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	battle.start_battle([charizard], [foe], "singles")
	var unlocked: Dictionary = PUWGimmickUnlocks.set_flag(_kanto_state(), "mega", true)
	var action: Dictionary = {"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}
	var result: Dictionary = PUWGimmickUnlocks.attempt_gimmick(battle, "mega", unlocked, false, action, true)
	if not bool(result.get("allowed", false)):
		print("  Mega attempt refused after unlock: " + str(result.get("reason", "")))
		return false
	if not bool(battle.player_party[0].get("mega_evolved", false)):
		print("  Charizard did not mega evolve after unlock. logs=" + str(result.get("logs", [])))
		return false
	if not _player_mega_budget(battle):
		print("  the player's mega budget was not consumed after unlock")
		return false
	return true


func test_save_round_trip_default_flags() -> bool:
	PUWSaveManager.delete_save()
	var state: Dictionary = _kanto_state()
	if not PUWSaveManager.save_game(state):
		print("  save_game failed")
		return false
	var loaded: Dictionary = PUWSaveManager.load_game()
	PUWSaveManager.delete_save()
	var story_value: Variant = loaded.get("story_flags", {})
	if not (story_value is Dictionary):
		print("  story_flags lost in round-trip")
		return false
	var story_flags: Dictionary = story_value
	if not story_flags.has("gimmick_unlocks"):
		print("  gimmick_unlocks key did not survive the round-trip")
		return false
	var flags: Dictionary = PUWGimmickUnlocks.read_flags(loaded)
	for family_value: Variant in PUWGimmickUnlocks.FAMILIES:
		if bool(flags.get(str(family_value), true)):
			print("  a flag came back unlocked after the round-trip")
			return false
	return true


func test_save_round_trip_mega_true() -> bool:
	PUWSaveManager.delete_save()
	var state: Dictionary = PUWGimmickUnlocks.set_flag(_kanto_state(), "mega", true)
	if not PUWSaveManager.save_game(state):
		print("  save_game failed")
		return false
	var loaded: Dictionary = PUWSaveManager.load_game()
	PUWSaveManager.delete_save()
	var flags: Dictionary = PUWGimmickUnlocks.read_flags(loaded)
	if not bool(flags.get("mega", false)):
		print("  mega=true did not survive the round-trip")
		return false
	if bool(flags.get("z_move", true)) or bool(flags.get("dynamax", true)) or bool(flags.get("terastallization", true)):
		print("  another family came back unlocked after the round-trip")
		return false
	return true
