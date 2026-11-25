extends SceneTree
## Mechanics-completeness prep tests (2026-11-24): the fixes
## F1-F8 from hidden_files/code_prep_mechanics_check/patched/,
## exercised on copies in this harness project.
## Run: godot --headless --script res://tests/mechanics_check_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW mechanics-completeness prep tests — starting.")
	_run("f1_gate_locked_refuses_mega_in_live_turn", Callable(self, "f1_gate_locked_refuses_mega_in_live_turn"))
	_run("f1_gate_unlocked_allows_mega", Callable(self, "f1_gate_unlocked_allows_mega"))
	_run("f1_gate_simulation_allows_mega", Callable(self, "f1_gate_simulation_allows_mega"))
	_run("f1_unarmed_legacy_behavior", Callable(self, "f1_unarmed_legacy_behavior"))
	_run("f1_gate_matches_unlock_predicate", Callable(self, "f1_gate_matches_unlock_predicate"))
	_run("f3_badge_supply_sets_cap", Callable(self, "f3_badge_supply_sets_cap"))
	_run("f2_story_faint_removes_and_ledgers", Callable(self, "f2_story_faint_removes_and_ledgers"))
	_run("f2_simulation_and_rental_exempt", Callable(self, "f2_simulation_and_rental_exempt"))
	_run("f2_coop_counts", Callable(self, "f2_coop_counts"))
	_run("f2_no_faints_no_removal", Callable(self, "f2_no_faints_no_removal"))
	_run("f4_mdx_follower_bound_sheet", Callable(self, "f4_mdx_follower_bound_sheet"))
	_run("f4_mdx_follower_missing_slot", Callable(self, "f4_mdx_follower_missing_slot"))
	_run("f4_pkdx_follower_unchanged", Callable(self, "f4_pkdx_follower_unchanged"))
	_run("f5_registry_still_twelve_and_refit_api", Callable(self, "f5_registry_still_twelve_and_refit_api"))
	_run("f5_rotom_refit_water_crossing", Callable(self, "f5_rotom_refit_water_crossing"))
	_run("f6_glue_setup_real_map_and_field_gate", Callable(self, "f6_glue_setup_real_map_and_field_gate"))
	_run("f6_glue_trainer_chain", Callable(self, "f6_glue_trainer_chain"))
	_run("f7_quest_board_lifecycle", Callable(self, "f7_quest_board_lifecycle"))
	_run("f8_fishing_paths", Callable(self, "f8_fishing_paths"))
	_run("f9_vs_seeker_and_rematch_chain", Callable(self, "f9_vs_seeker_and_rematch_chain"))
	_run("f9_tandem_coop_gate", Callable(self, "f9_tandem_coop_gate"))
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


# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

func _mon(mon_name: String, types: Array, moves: Array, extra: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": 50, "hp": 200, "max_hp": 200,
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


func _locked_state() -> Dictionary:
	return {"story_flags": {"region_id": "kanto", "gimmick_unlocks": PUWGimmickUnlocks.default_flags()}}


func _field() -> Dictionary:
	return StatusAndFieldEngine.create_field_state()


func _mega_battle() -> BattleController:
	var battle: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	battle.start_battle([charizard], [foe], "singles")
	return battle


func _turn_logs_text(result: Dictionary) -> String:
	var text: String = ""
	var logs_value: Variant = result.get("logs", [])
	if logs_value is Array:
		var logs: Array = logs_value
		for line_value in logs:
			text += str(line_value) + "\n"
	return text


# ----------------------------------------------------------------
# F1 — the progression gimmick gate in the live turn path
# ----------------------------------------------------------------

func f1_gate_locked_refuses_mega_in_live_turn() -> bool:
	var battle: BattleController = _mega_battle()
	battle.arm_gimmick_gate(_locked_state(), false)
	var foe_hp_before: int = int(battle.enemy_party[0].get("hp", 0))
	var result: Dictionary = battle.run_turn({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, _field())
	if bool(battle.player_party[0].get("mega_evolved", false)):
		print("  Charizard mega evolved despite the armed lock")
		return false
	var budgets: Dictionary = battle.battle_state.get("gimmick_budgets", {})
	var player_budgets: Dictionary = budgets.get("player", {})
	if bool(player_budgets.get("mega", false)):
		print("  mega budget spent despite the lock")
		return false
	if not _turn_logs_text(result).contains("Gimmick locked"):
		print("  no lock message in the turn logs")
		return false
	if int(battle.enemy_party[0].get("hp", 0)) >= foe_hp_before:
		print("  the move itself did not execute (foe took no damage)")
		return false
	return true


func f1_gate_unlocked_allows_mega() -> bool:
	var battle: BattleController = _mega_battle()
	var unlocked: Dictionary = PUWGimmickUnlocks.set_flag(_locked_state(), "mega", true)
	battle.arm_gimmick_gate(unlocked, false)
	battle.run_turn({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, _field())
	if not bool(battle.player_party[0].get("mega_evolved", false)):
		print("  Charizard did not mega evolve after the unlock")
		return false
	return true


func f1_gate_simulation_allows_mega() -> bool:
	var battle: BattleController = _mega_battle()
	battle.arm_gimmick_gate(_locked_state(), true)
	battle.run_turn({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, _field())
	if not bool(battle.player_party[0].get("mega_evolved", false)):
		print("  simulation (VEXA) did not exempt the gate")
		return false
	return true


func f1_unarmed_legacy_behavior() -> bool:
	var battle: BattleController = _mega_battle()
	battle.run_turn({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, _field())
	if not bool(battle.player_party[0].get("mega_evolved", false)):
		print("  unarmed controller changed behavior (existing suites rely on it)")
		return false
	return true


func f1_gate_matches_unlock_predicate() -> bool:
	var battle: BattleController = _new_controller()
	var states: Array = [
		[_locked_state(), false],
		[PUWGimmickUnlocks.set_flag(_locked_state(), "mega", true), false],
		[PUWGimmickUnlocks.set_flag(_locked_state(), "terastallization", true), false],
		[_locked_state(), true],
	]
	var actions: Array = [
		{"type": "move", "gimmick": "mega", "move_name": "Flamethrower"},
		{"type": "move", "gimmick": "tera", "tera_type": "Fire", "move_name": "Flamethrower"},
		{"type": "move", "gimmick": "dynamax", "move_name": "Flamethrower"},
		{"type": "move", "z_crystal": "Firium Z", "move_name": "Flamethrower"},
		{"type": "move", "move_name": "Flamethrower"},
	]
	for state_pair in states:
		var state: Dictionary = state_pair[0]
		var simulation: bool = bool(state_pair[1])
		battle.arm_gimmick_gate(state, simulation)
		for action_value in actions:
			var action: Dictionary = action_value
			var budget_key: String = battle._gimmick_budget_key_for_action(action)
			var logs: Array = []
			var refused: bool = battle._gimmick_gate_check(action, true, logs)
			var expected_refused: bool = budget_key != "" and not PUWGimmickUnlocks.is_budget_allowed(budget_key, state, simulation)
			if refused != expected_refused:
				print("  gate disagrees with is_budget_allowed for key " + budget_key)
				return false
			if refused and logs.is_empty():
				print("  refusal without a log line for key " + budget_key)
				return false
	return true


# ----------------------------------------------------------------
# F3 — badge supply for the level caps
# ----------------------------------------------------------------

func f3_badge_supply_sets_cap() -> bool:
	var battle: BattleController = _new_controller()
	if battle._active_level_cap() != -1:
		print("  fresh controller should have no cap")
		return false
	battle.supply_badge_count_from_state({"badges": ["kanto_gym_1_brock", "kanto_gym_2_misty", "kanto_gym_3_surge"]})
	if battle._active_level_cap() != 29:
		print("  3 badges should cap at 29, got " + str(battle._active_level_cap()))
		return false
	battle.supply_badge_count_from_state({"badges": 8})
	if battle._active_level_cap() != 100:
		print("  8 badges (int form) should cap at 100, got " + str(battle._active_level_cap()))
		return false
	battle.supply_badge_count_from_state({})
	if battle._active_level_cap() != 100:
		print("  a state without badges must not clear a supplied count")
		return false
	return true


# ----------------------------------------------------------------
# F2 — the permadeath bridge
# ----------------------------------------------------------------

func _bridge_state() -> Dictionary:
	var a: Dictionary = {"name": "Alpha", "species": "Pidgey", "evo_family": "pidgey", "hp": 0, "max_hp": 20}
	var b: Dictionary = {"name": "Beta", "species": "Rattata", "evo_family": "rattata", "hp": 15, "max_hp": 20}
	return {"party": [a, b], "locked_evo_families": {}, "fainting_ledger": []}


func f2_story_faint_removes_and_ledgers() -> bool:
	var party_state: Dictionary = _bridge_state()
	var battle_party: Array = party_state["party"]
	var outcome: Dictionary = PUWPermadeathBridge.apply_battle_end(party_state, battle_party, {"story": true})
	if not bool(outcome.get("applied", false)):
		print("  story battle did not apply permadeath")
		return false
	if (outcome.get("removed", []) as Array).size() != 1:
		print("  exactly one mon should be removed")
		return false
	var new_state: Dictionary = outcome["state"]
	if (new_state["party"] as Array).size() != 1 or str((new_state["party"] as Array)[0].get("name", "")) != "Beta":
		print("  survivor party is wrong")
		return false
	if (new_state["fainting_ledger"] as Array).size() != 1:
		print("  ledger should hold one entry")
		return false
	var entry: Dictionary = (new_state["fainting_ledger"] as Array)[0]
	if str(entry.get("format", "")) != "scripted_story_battle":
		print("  ledger format should be scripted_story_battle, got " + str(entry.get("format", "")))
		return false
	if not bool((new_state["locked_evo_families"] as Dictionary).get("pidgey", false)):
		print("  pidgey family should be locked")
		return false
	if (party_state["party"] as Array).size() != 2:
		print("  the caller's state was mutated")
		return false
	return true


func f2_simulation_and_rental_exempt() -> bool:
	for context in [{"simulation": true}, {"rental": true}, {"simulation": true, "story": true}]:
		var party_state: Dictionary = _bridge_state()
		var outcome: Dictionary = PUWPermadeathBridge.apply_battle_end(party_state, party_state["party"], context)
		if bool(outcome.get("applied", true)):
			print("  exempt context applied permadeath: " + str(context))
			return false
		var new_state: Dictionary = outcome["state"]
		if (new_state["party"] as Array).size() != 2 or (new_state["fainting_ledger"] as Array).size() != 0:
			print("  exempt context changed the collections: " + str(context))
			return false
	return true


func f2_coop_counts() -> bool:
	var party_state: Dictionary = _bridge_state()
	var outcome: Dictionary = PUWPermadeathBridge.apply_battle_end(party_state, party_state["party"], {"coop": true})
	if not bool(outcome.get("applied", false)):
		print("  co-op battle did not apply permadeath")
		return false
	var new_state: Dictionary = outcome["state"]
	var entry: Dictionary = (new_state["fainting_ledger"] as Array)[0]
	if str(entry.get("format", "")) != "multiplayer_coop_battle":
		print("  co-op ledger format wrong: " + str(entry.get("format", "")))
		return false
	return true


func f2_no_faints_no_removal() -> bool:
	var party_state: Dictionary = _bridge_state()
	(party_state["party"] as Array)[0]["hp"] = 5
	var outcome: Dictionary = PUWPermadeathBridge.apply_battle_end(party_state, party_state["party"], {})
	if not bool(outcome.get("applied", false)):
		print("  ordinary battle context should apply")
		return false
	if (outcome.get("removed", []) as Array).size() != 0:
		print("  nothing fainted but a mon was removed")
		return false
	var new_state: Dictionary = outcome["state"]
	if (new_state["party"] as Array).size() != 2 or (new_state["fainting_ledger"] as Array).size() != 0:
		print("  collections changed without a faint")
		return false
	return true


# ----------------------------------------------------------------
# F4 — MDX followers through the MDX data layer
# ----------------------------------------------------------------

func f4_mdx_follower_bound_sheet() -> bool:
	var controller: PUWFollowerController = PUWFollowerController.new()
	root.add_child(controller)
	var mon: Dictionary = {"name": "Bulbasaur", "species": "Bulbasaur", "family": "MDX"}
	var result: Dictionary = controller.select_followers([mon], [0])
	if not bool(result.get("ok", false)):
		print("  MDX follower selection refused: " + str(result.get("reason", "")))
		return false
	var info: Dictionary = controller.follower_sprite_info(0)
	if str(info.get("classification", "")) != "animated":
		print("  MDX Bulbasaur should classify animated, got " + str(info.get("classification", "")))
		return false
	if str(info.get("url", "")) != "res://art/mdx/followers/0001_bulbasaur_walk.png":
		print("  MDX Bulbasaur URL wrong: " + str(info.get("url", "")))
		return false
	if not bool(info.get("animated", false)):
		print("  MDX Bulbasaur should be animated")
		return false
	return true


func f4_mdx_follower_missing_slot() -> bool:
	var controller: PUWFollowerController = PUWFollowerController.new()
	root.add_child(controller)
	var mon: Dictionary = {"name": "Sylveon", "species": "Sylveon", "family": "MDX"}
	var result: Dictionary = controller.select_followers([mon], [0])
	if not bool(result.get("ok", false)):
		print("  MDX Sylveon selection refused")
		return false
	var info: Dictionary = controller.follower_sprite_info(0)
	if str(info.get("classification", "")) != "missing" or str(info.get("url", "")) != "":
		print("  unbound MDX slot should stay honestly missing, got " + str(info))
		return false
	return true


func f4_pkdx_follower_unchanged() -> bool:
	var controller: PUWFollowerController = PUWFollowerController.new()
	root.add_child(controller)
	var mon: Dictionary = {"name": "Bulbasaur", "species": "Bulbasaur", "family": "PKDX"}
	var result: Dictionary = controller.select_followers([mon], [0])
	if not bool(result.get("ok", false)):
		print("  PKDX follower selection refused")
		return false
	var info: Dictionary = controller.follower_sprite_info(0)
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var direct: Dictionary = resolver.resolve("bulbasaur", "PKDX", "")
	if str(info.get("classification", "")) != str(direct.get("classification", "")) or str(info.get("url", "")) != str(direct.get("url", "")):
		print("  PKDX routing changed: controller " + str(info) + " vs resolver " + str(direct))
		return false
	return true


# ----------------------------------------------------------------
# F5 — Rotom Bike water re-fit
# ----------------------------------------------------------------

func f5_registry_still_twelve_and_refit_api() -> bool:
	var data: Dictionary = PUWBikes.registry_data()
	if (data.get("bicycles", []) as Array).size() != 12:
		print("  registry must stay at exactly 12 bicycles")
		return false
	if not PUWBikes.water_capable("riley_solo", {"bag": {"rotom-bike": 1}}):
		print("  solo bike with the Rotom Bike item should be water-capable")
		return false
	if PUWBikes.water_capable("riley_solo", {"bag": {}}):
		print("  no item, no re-fit")
		return false
	if PUWBikes.water_capable("riley_tandem", {"bag": {"rotom-bike": 1}}):
		print("  tandems are never water-capable through the re-fit")
		return false
	if PUWBikes.water_capable("", {"bag": {"rotom-bike": 1}}):
		print("  no bike, no re-fit")
		return false
	return true


func f5_rotom_refit_water_crossing() -> bool:
	var loader: PUWMapLoader = PUWMapLoader.new()
	root.add_child(loader)
	var terrain: Dictionary = {Vector2i(3, 0): "water", Vector2i(3, 1): "water", Vector2i(3, 2): "water"}
	loader.setup_synthetic_map(6, 3, terrain, 8)
	var controller: PUWPlayerController = PUWPlayerController.new()
	root.add_child(controller)
	controller.setup(loader)
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var squirtle: Dictionary = builder.build_mon("Squirtle", 20, "singles")
	if squirtle.is_empty():
		print("  could not build a Squirtle for the field party")
		return false
	var state: Dictionary = {"badges": ["kanto_gym_5_koga"], "bag": {}}
	controller.set_field_context(state, [squirtle])
	controller.place_at_tile(Vector2i(2, 1))
	if not controller.mount_bicycle("riley_solo"):
		print("  could not mount riley_solo")
		return false
	controller.step(0.1, Vector2.RIGHT, "bike_acro")
	if controller.player_tile() != Vector2i(2, 1) or controller.last_block_reason != "requires_water_mount":
		print("  without the re-fit, water must block the bike (tile " + str(controller.player_tile()) + ", reason " + controller.last_block_reason + ")")
		return false
	state["bag"] = {"rotom-bike": 1}
	controller.set_field_context(state, [squirtle])
	controller.step(0.1, Vector2.RIGHT, "bike_acro")
	if controller.player_tile() != Vector2i(3, 1):
		print("  with the re-fit, the bike should be on the water tile, got " + str(controller.player_tile()) + " reason " + controller.last_block_reason)
		return false
	return true


# ----------------------------------------------------------------
# F6 — overworld mechanics glue
# ----------------------------------------------------------------

func _glue_party() -> Array:
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	return [builder.build_mon("Squirtle", 20, "singles"), builder.build_mon("Pikachu", 20, "singles")]


func f6_glue_setup_real_map_and_field_gate() -> bool:
	var glue: PUWOverworldMechanicsGlue = PUWOverworldMechanicsGlue.new()
	root.add_child(glue)
	var party: Array = _glue_party()
	var setup: Dictionary = glue.setup("Route3", {"badges": []}, party)
	if not bool(setup.get("ok", false)):
		print("  glue setup failed on Route3: " + str(setup))
		return false
	var counts: Dictionary = (setup.get("spawn_report", {}) as Dictionary).get("counts", {})
	if int(counts.get("total", 0)) <= 0:
		print("  spawner placed nothing on Route3")
		return false
	var refused: Dictionary = glue.attempt_field_action("surf")
	if bool(refused.get("allowed", true)) or str(refused.get("reason", "")) != "badge_missing":
		print("  surf without the badge should refuse badge_missing, got " + str(refused))
		return false
	glue.refresh_field_context({"badges": ["kanto_gym_5_koga"]}, party)
	var allowed: Dictionary = glue.attempt_field_action("surf")
	if not bool(allowed.get("allowed", false)):
		print("  surf with badge + Water party member should be allowed, got " + str(allowed))
		return false
	if not glue.mount_bicycle_for_cast("riley"):
		print("  glue could not mount Riley's solo bike")
		return false
	# Capacities follow the active movement mode: one step in
	# the acro bike mode (no input direction, so no movement)
	# puts the controller in bike_acro, as live input would.
	glue.step(0.1, Vector2.ZERO, "bike_acro")
	if not glue.player.has_capacity(PUWBikes.CAP_BUNNY_HOP):
		print("  Riley's acro bike should carry bunny_hop through the glue")
		return false
	return true


func f6_glue_trainer_chain() -> bool:
	var glue: PUWOverworldMechanicsGlue = PUWOverworldMechanicsGlue.new()
	root.add_child(glue)
	var party: Array = _glue_party()
	var setup: Dictionary = glue.setup("Route3", {"badges": []}, party)
	if not bool(setup.get("ok", false)):
		print("  glue setup failed on Route3")
		return false
	# Find a spawned trainer and stand where its trigger fires.
	var trainers: Array = []
	for child_value in glue.get_children():
		var child: Node = child_value
		var trainer: Dictionary = PUWSpawner.trainer_dict_from_node(child)
		if not trainer.is_empty() and str(trainer.get("trainer_class", "")) != "":
			trainers.append(trainer)
	if trainers.is_empty():
		print("  no trainer nodes spawned on Route3")
		return false
	var offsets: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]
	for trainer_value in trainers:
		var trainer: Dictionary = trainer_value
		var base_tile: Vector2i = trainer.get("tile", Vector2i(-1, -1))
		var facing_step: Vector2i = trainer.get("facing", Vector2i.ZERO)
		var candidates: Array = [base_tile + facing_step, base_tile + facing_step * 2, base_tile + facing_step * 3]
		for offset_value in offsets:
			candidates.append(base_tile + offset_value)
		for candidate_value in candidates:
			var candidate: Vector2i = candidate_value
			if candidate.x < 0 or candidate.y < 0:
				continue
			if glue.map_loader.is_solid_tile(candidate):
				continue
			glue.player.place_at_tile(candidate)
			var hit: Dictionary = glue.scan_trainer_trigger()
			if hit.is_empty():
				continue
			var team: Array = hit.get("enemy_party", [])
			if team.size() != 6:
				print("  trainer team should be 6, got " + str(team.size()))
				return false
			var verdict: Dictionary = hit.get("verdict", {})
			if not bool(verdict.get("ok", false)):
				print("  hand-off guard refused the built team: " + str(verdict.get("problems", [])))
				return false
			return true
	print("  no placement triggered a trainer scan on Route3")
	return false


# ----------------------------------------------------------------
# F7 — quest board glue lifecycle
# ----------------------------------------------------------------

func f7_quest_board_lifecycle() -> bool:
	var state: Dictionary = {}
	PUWCampaignStitch.set_region(state, "kanto")
	var glue: PUWQuestBoardGlue = PUWQuestBoardGlue.new()
	var setup: Dictionary = glue.setup_board(state, "kanto", "pallet_town", 1, {"world_day": 1})
	if not bool(setup.get("ok", false)):
		print("  board setup failed: " + str(setup))
		return false
	var postings: Array = setup.get("postings", [])
	if postings.is_empty():
		print("  Pallet Town board has no postings after setup")
		return false
	var target_id: String = ""
	for posting_value in postings:
		var posting: Dictionary = posting_value
		if str(posting.get("instance_id", "")) == "pallet_town_catch_pidgey":
			target_id = "pallet_town_catch_pidgey"
			break
	if target_id == "":
		print("  the authored Pallet Town catch-Pidgey posting is not on the board")
		return false
	var accepted: Dictionary = glue.accept(state, "pallet_town", target_id, {"world_day": 1})
	if not bool(accepted.get("ok", false)):
		print("  accept failed: " + str(accepted))
		return false
	glue.record_event(state, {"type": "catch", "species": "pidgey"})
	glue.record_event(state, {"type": "catch", "species": "pidgey"})
	var turned: Dictionary = glue.turn_in(state, target_id)
	if not bool(turned.get("ok", false)):
		print("  turn-in failed after 2 catches: " + str(turned))
		return false
	return true


# ----------------------------------------------------------------
# F9 — Vs. Seeker + rematch caller, tandem co-op gate
# ----------------------------------------------------------------

func f9_vs_seeker_and_rematch_chain() -> bool:
	var glue: PUWOverworldMechanicsGlue = PUWOverworldMechanicsGlue.new()
	root.add_child(glue)
	glue.party = _glue_party()
	var state: Dictionary = {"vs_seeker_last_use_step": 1000}
	var early: Dictionary = glue.use_vs_seeker(state, 1050)
	if bool(early.get("ok", true)):
		print("  Vs. Seeker fired at 50 steps (needs 100)")
		return false
	var fired: Dictionary = glue.use_vs_seeker(state, 1100)
	if not bool(fired.get("ok", false)):
		print("  Vs. Seeker refused at 100 steps")
		return false
	var again: Dictionary = glue.use_vs_seeker(state, 1150)
	if bool(again.get("ok", true)):
		print("  Vs. Seeker fired again without a fresh 100 steps")
		return false
	var tables: Dictionary = glue.load_rematch_tables("kanto")
	var trainer_key: String = ""
	for key_value in tables.keys():
		var key: String = str(key_value)
		var record_value: Variant = tables[key]
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if (record.get("tiers", []) as Array).size() > 0:
				trainer_key = key
				break
	if trainer_key == "":
		print("  no rematch trainer with tiers in the bound Kanto tables")
		return false
	var result: Dictionary = glue.start_rematch("kanto", trainer_key, 0)
	var team: Array = result.get("enemy_party", [])
	if team.size() != 6:
		print("  rematch team should be 6 (D4/D5 standard), got " + str(team.size()))
		return false
	var verdict: Dictionary = result.get("verdict", {})
	if not bool(verdict.get("ok", false)):
		print("  rematch hand-off refused: " + str(verdict.get("problems", [])))
		return false
	return true


func f9_tandem_coop_gate() -> bool:
	var glue: PUWOverworldMechanicsGlue = PUWOverworldMechanicsGlue.new()
	root.add_child(glue)
	var setup: Dictionary = glue.setup("Route1", {"badges": []}, _glue_party())
	if not bool(setup.get("ok", false)):
		print("  glue setup failed on Route1")
		return false
	if glue.tandem_available():
		print("  tandem available while co-op is offline")
		return false
	var refused: Dictionary = glue.mount_tandem("riley")
	if bool(refused.get("ok", true)):
		print("  tandem mount allowed while co-op is offline")
		return false
	glue.coop.is_coop_connected = true
	if not glue.tandem_available():
		print("  tandem still hidden with a connected co-op session")
		return false
	var mounted: Dictionary = glue.mount_tandem("riley")
	if not bool(mounted.get("ok", false)) or str(mounted.get("bicycle_id", "")) != "riley_tandem":
		print("  tandem resolution wrong: " + str(mounted))
		return false
	return true


# ----------------------------------------------------------------
# F8 — fishing glue
# ----------------------------------------------------------------

func f8_fishing_paths() -> bool:
	var glue: PUWFishingGlue = PUWFishingGlue.new()
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var party: Array = [builder.build_mon("Pikachu", 20, "singles")]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var not_rod: Dictionary = glue.cast_line({"bag": {"potion": 1}}, party, "ROUTE_19", "potion", rng)
	if bool(not_rod.get("ok", true)) or str(not_rod.get("reason", "")) != "not_a_rod":
		print("  a potion is not a rod: " + str(not_rod))
		return false
	var no_bag_rod: Dictionary = glue.cast_line({"bag": {}}, party, "ROUTE_19", "old-rod", rng)
	if bool(no_bag_rod.get("ok", true)) or str(no_bag_rod.get("reason", "")) != "rod_not_in_bag":
		print("  rod must be in the bag: " + str(no_bag_rod))
		return false
	var state: Dictionary = {"bag": {"old-rod": 1, "good-rod": 1, "super-rod": 1}}
	var bite: Dictionary = {}
	for seed_value in range(1, 61):
		rng.seed = seed_value * 7919
		var result: Dictionary = glue.cast_line(state, party, "ROUTE_19", "super-rod", rng)
		if bool(result.get("ok", false)):
			bite = result
			break
	if bite.is_empty():
		print("  no bite on ROUTE_19 in 60 seeded casts")
		return false
	var mon: Dictionary = bite.get("mon", {})
	if mon.is_empty():
		print("  bite without a built mon")
		return false
	var level: int = int(mon.get("level", 0))
	if level < 21 or level > 23:
		print("  wild level should be player max +1..3 (21..23), got " + str(level))
		return false
	var ivs: Dictionary = mon.get("ivs", {})
	for stat_key in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if int(ivs.get(stat_key, 0)) != 31:
			print("  wild mon IV " + stat_key + " should be 31, got " + str(ivs.get(stat_key, 0)))
			return false
	return true
