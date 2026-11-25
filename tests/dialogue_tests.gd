extends SceneTree
## Dialogue system tests — code prep (hidden_files/code_prep_dialogue).
##
## Drives the PATCHED PUWSpawner (Kanto bridge + bound bank + Johto
## bank/bridge), PUWDialogueRunner and PUWDialogueBox against the
## bound banks, bridges and map data in test_project/.
##
## Expected values come from the banks themselves (read in the
## test) and from the prep's verified coverage counts:
##   Kanto as-bound 820/1,119 (proven against the ORIGINAL spawner
##   by baseline_project), with-prep 894/1,119. (The one ref where
##   the Python count and GDScript disagreed was the Mt. Moon
##   Pokecenter clipboard: its bank entry and its pokered source
##   text are both empty — GDScript is right, it has no line.)
##   Johto as-bound 0/1,470 (the shipped spawner never loaded the
##   Johto bank), with-prep >= 942/1,470 (bridge count from the
##   generator; the GDScript core-match fallback may add more).
##
## Run: godot --headless --path test_project \
##        --script res://tests/dialogue_tests.gd

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

var _spawner: Node = null
var _kanto_bank: Dictionary = {}
var _johto_bank: Dictionary = {}


func _init() -> void:
	print("PUW dialogue tests — starting.")
	var spawner_script: GDScript = load("res://systems/overworld/spawner.gd")
	_spawner = spawner_script.new()
	_kanto_bank = _load_groups("res://data/dialogue_database.json")
	_johto_bank = _load_groups("res://data/johto/dialogue_database.json")

	_run("test_pallet_girl_lines", Callable(self, "test_pallet_girl_lines"))
	_run("test_celadon_gym_bridge_order", Callable(self, "test_celadon_gym_bridge_order"))
	_run("test_bills_house_choice_flow_lines", Callable(self, "test_bills_house_choice_flow_lines"))
	_run("test_johto_trainer_bridge_order", Callable(self, "test_johto_trainer_bridge_order"))
	_run("test_johto_sign_script", Callable(self, "test_johto_sign_script"))
	_run("test_spawned_nodes_carry_refs", Callable(self, "test_spawned_nodes_carry_refs"))
	_run("test_runner_plays_in_order", Callable(self, "test_runner_plays_in_order"))
	_run("test_box_displays_in_order", Callable(self, "test_box_displays_in_order"))
	_run("test_choice_entry_records_and_jumps", Callable(self, "test_choice_entry_records_and_jumps"))
	_run("test_no_dialogue_ref_recorded", Callable(self, "test_no_dialogue_ref_recorded"))
	_run("test_kanto_totals_with_prep", Callable(self, "test_kanto_totals_with_prep"))
	_run("test_johto_totals_with_prep", Callable(self, "test_johto_totals_with_prep"))

	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("FAILED: ", _failed_names)
	_spawner.free()
	quit(1 if _failed > 0 else 0)


# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

func _run(name: String, fn: Callable) -> void:
	var before: int = _failed
	fn.call()
	if _failed == before:
		_passed += 1
		print("PASS ", name)
	else:
		_failed_names.append(name)
		print("FAIL ", name)


func _check(cond: bool, detail: String) -> void:
	if not cond:
		_failed += 1
		print("  check failed: ", detail)


func _load_groups(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed
		var g_v: Variant = d.get("groups", {})
		if g_v is Dictionary:
			var g: Dictionary = g_v
			return g
	return {}


func _bank_line(bank: Dictionary, map_name: String, label: String) -> String:
	var g_v: Variant = bank.get(map_name, {})
	if g_v is Dictionary:
		var g: Dictionary = g_v
		var e_v: Variant = g.get("entries", {})
		if e_v is Dictionary:
			var e: Dictionary = e_v
			var v: Variant = e.get(label, "")
			if v is String:
				var s: String = v
				return s
	return ""


func _spawn_totals(region: String) -> Array:
	# [placements, resolved] over every bound map of the region,
	# through the patched spawner's real spawn_map path.
	var maps_dir: String = "res://maps/data/maps/"
	var dir: DirAccess = DirAccess.open(maps_dir)
	var names: Array = []
	if dir != null:
		dir.list_dir_begin()
		var fn: String = dir.get_next()
		while fn != "":
			if fn.ends_with(".json"):
				names.append(fn.trim_suffix(".json"))
			fn = dir.get_next()
		dir.list_dir_end()
	names.sort()
	var total: int = 0
	var resolved: int = 0
	for name_v in names:
		var map_name: String = name_v
		var f: FileAccess = FileAccess.open(maps_dir + map_name + ".json", FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if not (parsed is Dictionary):
			continue
		var map_data: Dictionary = parsed
		if String(map_data.get("region", "")) != region:
			continue
		var parent: Node2D = Node2D.new()
		var report: Dictionary = _spawner.spawn_map(parent, map_name)
		var counts: Dictionary = report.get("counts", {})
		var n: int = int(counts.get("total", 0))
		var unres: int = 0
		for entry_v in report.get("unresolved", []):
			var entry: String = entry_v
			if entry.begins_with("dialogue_unresolved:"):
				unres += 1
		total += n
		resolved += n - unres
		parent.free()
	return [total, resolved]


# ----------------------------------------------------------------
# Resolution: Kanto
# ----------------------------------------------------------------

func test_pallet_girl_lines() -> void:
	var lines: Array = _spawner.dialogue_for("PalletTown", "TEXT_PALLETTOWN_GIRL")
	_check(lines.size() >= 1, "girl resolves at least one line")
	if lines.size() >= 1:
		var expected: String = _bank_line(_kanto_bank, "PalletTown", "_PalletTownGirlText")
		_check(String(lines[0]) == expected,
			"first line is the bank's _PalletTownGirlText")


func test_celadon_gym_bridge_order() -> void:
	# As-bound this text_id resolves NOTHING (numbered bank labels
	# vs named text_id); the bridge restores Battle -> End -> After
	# in source order from the trainer header.
	var lines: Array = _spawner.dialogue_for("CeladonGym", "TEXT_CELADONGYM_COOLTRAINER_F1")
	var expected: Array = [
		_bank_line(_kanto_bank, "CeladonGym", "_CeladonGymBattleText2"),
		_bank_line(_kanto_bank, "CeladonGym", "_CeladonGymEndBattleText2"),
		_bank_line(_kanto_bank, "CeladonGym", "_CeladonGymAfterBattleText2"),
	]
	_check(lines == expected,
		"bridge order Battle/End/After, got %s" % [lines])


func test_bills_house_choice_flow_lines() -> void:
	# Bill's root carries the sourced YesNoChoice; the bridge plays
	# its three far texts in source order.
	var lines: Array = _spawner.dialogue_for("BillsHouse", "TEXT_BILLSHOUSE_BILL_POKEMON")
	# Build 6 (A-32; choices prep merge step 4): with the choice
	# split bound, this entry returns the ASSEMBLED shape — the
	# prompt line carrying the Yes/No choice block (Yes rejoins
	# at the shared tail, index 3; No plays its line then the
	# branch_end marker jumps to the same tail).
	var expected: Array = [
		{"text": _bank_line(_kanto_bank, "BillsHouse", "_BillsHouseBillImNotAPokemonText"),
			"speaker": "",
			"choices": [{"label": "Yes", "target_index": 3},
				{"label": "No", "target_index": 1}]},
		_bank_line(_kanto_bank, "BillsHouse", "_BillsHouseBillNoYouGottaHelpText"),
		{"text": "", "speaker": "", "choices": [],
			"branch_end": true, "goto_index": 3},
		_bank_line(_kanto_bank, "BillsHouse", "_BillsHouseBillUseSeparationSystemText"),
	]
	_check(lines == expected, "Bill flow lines in assembled choice order, got %s" % [lines])


# ----------------------------------------------------------------
# Resolution: Johto
# ----------------------------------------------------------------

func test_johto_trainer_bridge_order() -> void:
	var lines: Array = _spawner.dialogue_for_script("AzaleaGym", "TrainerBugCatcherBenny")
	var expected: Array = [
		_bank_line(_johto_bank, "AzaleaGym", "BugCatcherBennySeenText"),
		_bank_line(_johto_bank, "AzaleaGym", "BugCatcherBennyBeatenText"),
		_bank_line(_johto_bank, "AzaleaGym", "BugCatcherBennyAfterBattleText"),
	]
	_check(lines == expected,
		"Benny Seen/Beaten/After in source order, got %s" % [lines])


func test_johto_sign_script() -> void:
	var lines: Array = _spawner.dialogue_for_script("AzaleaTown", "AzaleaTownSign")
	var expected: String = _bank_line(_johto_bank, "AzaleaTown", "AzaleaTownSignText")
	_check(lines.size() == 1 and String(lines[0]) == expected,
		"AzaleaTown sign resolves its bank line, got %s" % [lines])


# ----------------------------------------------------------------
# Spawn integration
# ----------------------------------------------------------------

func test_spawned_nodes_carry_refs() -> void:
	var parent: Node2D = Node2D.new()
	_spawner.spawn_map(parent, "PalletTown")
	var girl_ok: bool = false
	for child in parent.get_children():
		if String(child.get_meta("dialogue_ref", "")) == "TEXT_PALLETTOWN_GIRL":
			var lines: Array = _spawner.dialogue_for(
				String(child.get_meta("map", "")), "TEXT_PALLETTOWN_GIRL")
			girl_ok = lines.size() >= 1
	parent.free()
	_check(girl_ok, "spawned PalletTown girl node resolves dialogue")

	var parent2: Node2D = Node2D.new()
	_spawner.spawn_map(parent2, "AzaleaGym")
	var benny_ok: bool = false
	for child in parent2.get_children():
		if String(child.get_meta("script", "")) == "TrainerBugCatcherBenny":
			_check(String(child.get_meta("dialogue_ref", "")) == "TrainerBugCatcherBenny",
				"Johto node dialogue_ref falls back to script")
			var lines2: Array = _spawner.dialogue_for_script("AzaleaGym", "TrainerBugCatcherBenny")
			benny_ok = lines2.size() == 3
	parent2.free()
	_check(benny_ok, "spawned Benny node resolves 3 lines via script ref")


# ----------------------------------------------------------------
# Runner + box
# ----------------------------------------------------------------

func test_runner_plays_in_order() -> void:
	var runner_script: GDScript = load("res://systems/dialogue/dialogue_runner.gd")
	var runner: RefCounted = runner_script.new()
	var lines: Array = _spawner.dialogue_for_script("AzaleaGym", "TrainerBugCatcherBenny")
	runner.setup(lines)
	_check(runner.line_count() == 3, "runner holds 3 lines")
	var played: Array = []
	while not runner.is_finished():
		played.append(runner.current_text())
		runner.advance()
	_check(played == lines, "runner plays lines in exact order")
	_check(runner.current() == {}, "runner current is empty when finished")


func test_box_displays_in_order() -> void:
	var box_script: GDScript = load("res://systems/dialogue/dialogue_box.gd")
	var box: CanvasLayer = box_script.new()
	get_root().add_child(box)
	var lines: Array = _spawner.dialogue_for("PalletTown", "TEXT_PALLETTOWN_GIRL")
	box.start_dialogue(lines)
	_check(box.is_showing(), "box shows after start_dialogue")
	_check(box.current_line_text() == String(lines[0]), "box on line 1")
	box.advance()  # completes the typewriter reveal
	_check(box.visible_text() == String(lines[0]), "reveal completes line 1")
	var seen: Array = [box.current_line_text()]
	var guard: int = 0
	while box.is_showing() and guard < 50:
		box.advance()
		guard += 1
		if box.is_showing():
			seen.append(box.current_line_text())
	_check(seen == lines, "box displays every line in order, got %s" % [seen])
	_check(box.finished_emitted, "box emitted finished")
	box.queue_free()


func test_choice_entry_records_and_jumps() -> void:
	# Synthetic SHAPE fixture for the choice mechanism (the sourced
	# case is Bill's YesNoChoice flow, whose lines are covered by
	# test_bills_house_choice_flow_lines; branch-splitting of real
	# flows is build-6 work).
	var fixture: Array = [
		{"text": "fixture prompt", "speaker": "",
			"choices": [{"label": "Yes", "target_index": 2},
					{"label": "No", "target_index": 1}]},
		{"text": "fixture no branch", "speaker": "", "choices": []},
		{"text": "fixture yes branch", "speaker": "", "choices": []},
	]
	var runner_script: GDScript = load("res://systems/dialogue/dialogue_runner.gd")
	var runner: RefCounted = runner_script.new()
	runner.setup(fixture)
	_check(runner.current_choices().size() == 2, "choice entry exposes 2 choices")
	_check(runner.choose(0), "choose(0) succeeds")
	_check(runner.current_text() == "fixture yes branch", "choose jumps to target")
	_check(runner.choices_made.size() == 1, "choice recorded")
	_check(not runner.choose(5), "out-of-range choice refused")


func test_no_dialogue_ref_recorded() -> void:
	var lines: Array = _spawner.dialogue_for("PalletTown", "TEXT_PALLETTOWN_NOPE")
	_check(lines.is_empty(), "unknown ref resolves no lines")
	var found: bool = false
	for entry_v in _spawner.get_unresolved_dialogue():
		var entry: Dictionary = entry_v
		if String(entry.get("map", "")) == "PalletTown" \
				and String(entry.get("ref", "")) == "TEXT_PALLETTOWN_NOPE":
			found = true
	_check(found, "unknown ref recorded as unresolved")
	# A real no-dialogue placement: an item ball's message is
	# generated by the pickup code in the source game; there is no
	# static line to resolve.
	var ball: Array = _spawner.dialogue_for("MtMoon1F", "TEXT_MTMOON1F_POTION1")
	_check(ball.is_empty(), "item ball has no static dialogue line")


# ----------------------------------------------------------------
# Whole-region totals through the real spawn path
# ----------------------------------------------------------------

func test_kanto_totals_with_prep() -> void:
	var t: Array = _spawn_totals("kanto")
	print("  kanto with-prep: %d/%d resolved" % [t[1], t[0]])
	_check(t[0] == 1121, "kanto placements 1121, got %d" % t[0])  # build 6: +2 A-52 placements (VermilionDock sailor, Bill)
	_check(t[1] == 965, "kanto resolved 965 with prep, got %d" % t[1])  # build 6: A-16 tier-D + A-31 service bank + A-52 bank growth


func test_johto_totals_with_prep() -> void:
	var t: Array = _spawn_totals("johto")
	print("  johto with-prep: %d/%d resolved" % [t[1], t[0]])
	_check(t[0] == 1615, "johto placements 1615, got %d" % t[0])  # build 7: 1470 + Stage 2/5 map+trainer additions
	_check(t[1] >= 1073, "johto resolved at least the 1073 post-merge count (942 + service 82 + tier-D gains), got %d" % t[1])  # build 7 Stage 6 (§7)
