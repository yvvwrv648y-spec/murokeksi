extends SceneTree
## Fossil-revival service tests (code prep, 2026-11-23).
## Run: godot --headless --script res://tests/fossil_revival_tests.gd
##
## Covers, against COPIES of the real systems (G1-UUID patched
## PartyAndStorageManager + PUWSaveManager, PUWInventoryManager
## + PUWItemRegistry, PUWTeamBuilder + its real data files):
## - the staged index: all 11 single fossils + 4 Galar pairings;
## - every single fossil -> its registry species, at its level,
##   item consumed exactly once, mon in party with a G1 mon_id;
## - every Galar pairing -> its species, both components
##   consumed exactly once, wrong-point + single-component
##   refusals consuming nothing;
## - invalid-item rejection (non-fossil item, unheld fossil,
##   unknown service point) consuming nothing;
## - party-full routing: the 7th revival lands in pc_storage;
## - permadeath parity: a revived mon faints through the real
##   handle_faint exactly like any owned mon (story context);
## - save round-trip through the real PUWSaveManager: species,
##   level, provenance fields and mon_id survive, in party AND
##   in pc_storage, and the id is never reissued after reload;
## - service-point registration from the placement data file.

var _passed: int = 0
var _failed: int = 0

const SINGLES: Array = [
	["dome-fossil", "kabuto", "Kabuto", 5],
	["helix-fossil", "omanyte", "Omanyte", 5],
	["old-amber", "aerodactyl", "Aerodactyl", 5],
	["root-fossil", "lileep", "Lileep", 20],
	["claw-fossil", "anorith", "Anorith", 20],
	["skull-fossil", "cranidos", "Cranidos", 20],
	["armor-fossil", "shieldon", "Shieldon", 20],
	["cover-fossil", "tirtouga", "Tirtouga", 25],
	["plume-fossil", "archen", "Archen", 25],
	["jaw-fossil", "tyrunt", "Tyrunt", 20],
	["sail-fossil", "amaura", "Amaura", 20],
]

const COMBOS: Array = [
	["fossilized-bird", "fossilized-drake", "dracozolt", "Dracozolt"],
	["fossilized-bird", "fossilized-dino", "arctozolt", "Arctozolt"],
	["fossilized-fish", "fossilized-drake", "dracovish", "Dracovish"],
	["fossilized-fish", "fossilized-dino", "arctovish", "Arctovish"],
]


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _make_service() -> Dictionary:
	var mgr: PartyAndStorageManager = PartyAndStorageManager.new()
	var inv: PUWInventoryManager = PUWInventoryManager.new()
	inv.items = {}
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var svc: PUWFossilRevivalService = PUWFossilRevivalService.new(mgr, inv, builder)
	return {"mgr": mgr, "inv": inv, "builder": builder, "svc": svc}


func _init() -> void:
	_test_index_completeness()
	_test_service_points()
	_test_each_single_fossil()
	_test_each_galar_combination()
	_test_invalid_item_rejection()
	_test_unheld_fossil_refusal()
	_test_unknown_point_refusal()
	_test_single_component_refusal()
	_test_combination_wrong_point()
	_test_party_full_routing()
	_test_permadeath_parity()
	_test_save_round_trip()
	print("RESULT: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)


func _test_index_completeness() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var known: Array = svc.known_fossil_items()
	_check("index holds exactly the 11 single fossils", known.size() == 11, str(known.size()))
	for row_v in SINGLES:
		var row: Array = row_v
		var rec: Dictionary = svc.fossil_record(str(row[0]))
		_check("index maps " + str(row[0]), str(rec.get("species_slug", "")) == str(row[1]) and int(rec.get("level", 0)) == int(row[3]), str(rec.get("species_slug", "")) + " lv" + str(rec.get("level", 0)))
	for combo_v in COMBOS:
		var combo: Array = combo_v
		var rec2: Dictionary = svc.combination_record(str(combo[0]), str(combo[1]))
		_check("index pairs " + str(combo[0]) + "+" + str(combo[1]), str(rec2.get("species_slug", "")) == str(combo[2]), str(rec2.get("species_slug", "")))
		var rec3: Dictionary = svc.combination_record(str(combo[1]), str(combo[0]))
		_check("pairing is order-insensitive for " + str(combo[2]), str(rec3.get("species_slug", "")) == str(combo[2]))


func _test_service_points() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var points: Array = svc.service_points()
	_check("7 service points registered from placement data", points.size() == 7, str(points.size()))
	_check("Cinnabar Lab is a registered Kanto point", svc.is_registered_point("kanto_cinnabar_lab"))
	var cinnabar: Dictionary = svc.service_point("kanto_cinnabar_lab")
	_check("Cinnabar point is the lab on Cinnabar Island", str(cinnabar.get("building_name", "")) == "Cinnabar Lab" and str(cinnabar.get("region", "")) == "kanto")
	_check("Pewter Museum registered (registry-named point)", svc.is_registered_point("kanto_pewter_museum"))
	_check("Oreburgh Museum registered (registry-named point)", svc.is_registered_point("sinnoh_oreburgh_museum"))
	_check("Galar restoration point registered", svc.is_registered_point("galar_route6_restoration"))


func _test_each_single_fossil() -> void:
	for row_v in SINGLES:
		var row: Array = row_v
		var item_id: String = str(row[0])
		var ctx: Dictionary = _make_service()
		var svc: PUWFossilRevivalService = ctx["svc"]
		var inv: PUWInventoryManager = ctx["inv"]
		var mgr: PartyAndStorageManager = ctx["mgr"]
		inv.add_item(item_id, 2)
		var result: Dictionary = svc.revive(item_id, "kanto_cinnabar_lab")
		_check(item_id + " revives", bool(result.get("ok", false)), str(result.get("reason", "")))
		var mon: Dictionary = result.get("mon", {})
		_check(item_id + " -> " + str(row[2]), str(mon.get("species_slug", "")) == str(row[1]) and str(result.get("species", "")) == str(row[2]), str(mon.get("species_slug", "")))
		_check(item_id + " level " + str(row[3]), int(mon.get("level", 0)) == int(row[3]), str(mon.get("level", 0)))
		_check(item_id + " consumed exactly once (2 held -> 1 left)", inv.count_item(item_id) == 1, str(inv.count_item(item_id)))
		_check(item_id + " landed in party", str(result.get("destination", "")) == "party" and mgr.party.size() == 1)
		_check(item_id + " mon carries a G1 mon_id", not str(mon.get("mon_id", "")).is_empty(), str(mon.get("mon_id", "")))
		_check(item_id + " provenance stamped", str(mon.get("origin", "")) == "fossil_revival" and str(mon.get("revived_from", "")) == item_id and str(mon.get("revival_point", "")) == "kanto_cinnabar_lab")
		var found: Dictionary = mgr.find_mon_by_id(str(mon.get("mon_id", "")))
		_check(item_id + " findable by mon_id", not found.is_empty())


func _test_each_galar_combination() -> void:
	for combo_v in COMBOS:
		var combo: Array = combo_v
		var ctx: Dictionary = _make_service()
		var svc: PUWFossilRevivalService = ctx["svc"]
		var inv: PUWInventoryManager = ctx["inv"]
		var mgr: PartyAndStorageManager = ctx["mgr"]
		inv.add_item(str(combo[0]), 1)
		inv.add_item(str(combo[1]), 1)
		var result: Dictionary = svc.revive_combination(str(combo[0]), str(combo[1]), "galar_route6_restoration")
		_check(str(combo[3]) + " combination revives", bool(result.get("ok", false)), str(result.get("reason", "")))
		var mon: Dictionary = result.get("mon", {})
		_check(str(combo[3]) + " species + level 10", str(mon.get("species_slug", "")) == str(combo[2]) and int(mon.get("level", 0)) == 10, str(mon.get("species_slug", "")) + " lv" + str(mon.get("level", 0)))
		_check(str(combo[3]) + " both components consumed exactly once", inv.count_item(str(combo[0])) == 0 and inv.count_item(str(combo[1])) == 0)
		_check(str(combo[3]) + " in party with mon_id", mgr.party.size() == 1 and not str(mon.get("mon_id", "")).is_empty())


func _test_invalid_item_rejection() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	var mgr: PartyAndStorageManager = ctx["mgr"]
	inv.add_item("potion", 3)
	var result: Dictionary = svc.revive("potion", "kanto_cinnabar_lab")
	_check("non-fossil item refused as not_a_fossil", not bool(result.get("ok", true)) and str(result.get("reason", "")) == "not_a_fossil", str(result.get("reason", "")))
	_check("refusal consumed nothing and created nothing", inv.count_item("potion") == 3 and mgr.party.is_empty() and mgr.pc_storage.is_empty())
	var result2: Dictionary = svc.revive("master-ball", "kanto_cinnabar_lab")
	_check("unheld non-fossil also refused as not_a_fossil", not bool(result2.get("ok", true)) and str(result2.get("reason", "")) == "not_a_fossil")


func _test_unheld_fossil_refusal() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var mgr: PartyAndStorageManager = ctx["mgr"]
	var result: Dictionary = svc.revive("dome-fossil", "kanto_cinnabar_lab")
	_check("unheld fossil refused as fossil_not_held", not bool(result.get("ok", true)) and str(result.get("reason", "")) == "fossil_not_held", str(result.get("reason", "")))
	_check("no mon created on unheld refusal", mgr.party.is_empty() and mgr.pc_storage.is_empty())


func _test_unknown_point_refusal() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	inv.add_item("helix-fossil", 1)
	var result: Dictionary = svc.revive("helix-fossil", "nowhere_lab")
	_check("unknown service point refused", not bool(result.get("ok", true)) and str(result.get("reason", "")) == "unknown_service_point", str(result.get("reason", "")))
	_check("fossil not consumed at unknown point", inv.count_item("helix-fossil") == 1)


func _test_single_component_refusal() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	inv.add_item("fossilized-bird", 1)
	var result: Dictionary = svc.revive("fossilized-bird", "galar_route6_restoration")
	_check("single Galar component refused as incomplete pair", not bool(result.get("ok", true)) and str(result.get("reason", "")) == "incomplete_fossil_pair", str(result.get("reason", "")))
	_check("component not consumed", inv.count_item("fossilized-bird") == 1)
	var result2: Dictionary = svc.revive_combination("fossilized-bird", "fossilized-bird", "galar_route6_restoration")
	_check("same component twice is an invalid combination", not bool(result2.get("ok", true)) and str(result2.get("reason", "")) == "invalid_combination", str(result2.get("reason", "")))
	_check("component still not consumed", inv.count_item("fossilized-bird") == 1)


func _test_combination_wrong_point() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	inv.add_item("fossilized-fish", 1)
	inv.add_item("fossilized-dino", 1)
	var result: Dictionary = svc.revive_combination("fossilized-fish", "fossilized-dino", "kanto_cinnabar_lab")
	_check("combination at a non-Galar point refused", not bool(result.get("ok", true)) and str(result.get("reason", "")) == "combination_wrong_point", str(result.get("reason", "")))
	_check("neither component consumed at wrong point", inv.count_item("fossilized-fish") == 1 and inv.count_item("fossilized-dino") == 1)


func _test_party_full_routing() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	var mgr: PartyAndStorageManager = ctx["mgr"]
	for i in 6:
		mgr.add_pokemon({"name": "Filler" + str(i), "species": "Filler", "species_slug": "filler", "level": 5, "evo_family": "filler"})
	_check("party filled to 6 through the real path", mgr.party.size() == 6)
	inv.add_item("old-amber", 1)
	var result: Dictionary = svc.revive("old-amber", "kanto_cinnabar_lab")
	_check("revival with full party still succeeds", bool(result.get("ok", false)), str(result.get("reason", "")))
	_check("full-party revival routed to pc_storage", str(result.get("destination", "")) == "pc_storage" and mgr.pc_storage.size() == 1 and mgr.party.size() == 6, str(result.get("destination", "")))
	_check("stored revived mon is the Aerodactyl with a mon_id", str(mgr.pc_storage[0].get("species_slug", "")) == "aerodactyl" and not str(mgr.pc_storage[0].get("mon_id", "")).is_empty())
	_check("fossil consumed on storage routing", inv.count_item("old-amber") == 0)


func _test_permadeath_parity() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	var mgr: PartyAndStorageManager = ctx["mgr"]
	mgr.add_pokemon({"name": "Anchor", "species": "Anchor", "species_slug": "anchor", "level": 5, "evo_family": "anchor"})
	inv.add_item("dome-fossil", 1)
	var result: Dictionary = svc.revive("dome-fossil", "kanto_cinnabar_lab")
	_check("setup: Kabuto revived into party slot 1", bool(result.get("ok", false)) and mgr.party.size() == 2)
	var kabuto_id: String = str(mgr.party[1].get("mon_id", ""))
	var faint: Dictionary = mgr.handle_faint(1, false, "singles")
	_check("revived mon permadeath applies in story context (no exemption)", bool(faint.get("permanent", false)), str(faint))
	_check("fallen revived mon removed from party", mgr.party.size() == 1)
	_check("revived mon's id retired, never findable again", mgr.find_mon_by_id(kabuto_id).is_empty() and mgr.is_mon_id_retired(kabuto_id))
	var sim: Dictionary = mgr.handle_faint(0, true, "singles")
	_check("simulation faint stays non-permanent (house rule intact)", not bool(sim.get("permanent", true)))


func _test_save_round_trip() -> void:
	var ctx: Dictionary = _make_service()
	var svc: PUWFossilRevivalService = ctx["svc"]
	var inv: PUWInventoryManager = ctx["inv"]
	var mgr: PartyAndStorageManager = ctx["mgr"]
	inv.add_item("helix-fossil", 1)
	inv.add_item("old-amber", 1)
	var r1: Dictionary = svc.revive("helix-fossil", "kanto_pewter_museum")
	for i in 5:
		mgr.add_pokemon({"name": "Filler" + str(i), "species": "Filler", "species_slug": "filler", "level": 5, "evo_family": "filler"})
	var r2: Dictionary = svc.revive("old-amber", "sinnoh_oreburgh_museum")
	_check("setup: one revived in party, one in storage", bool(r1.get("ok", false)) and bool(r2.get("ok", false)) and str(r2.get("destination", "")) == "pc_storage", str(r2.get("destination", "")))
	var party_id: String = str(r1.get("mon", {}).get("mon_id", ""))
	var stored_id: String = str(r2.get("mon", {}).get("mon_id", ""))
	var state: Dictionary = PUWSaveManager.build_state(mgr.party, mgr.pc_boxes, {}, 0, [], [], [], {}, {}, mgr.mon_id_state())
	state["pc_storage"] = mgr.pc_storage.duplicate(true)
	_check("real save_game succeeds", PUWSaveManager.save_game(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check("real load_game returns the state", not loaded.is_empty())
	var mgr2: PartyAndStorageManager = PartyAndStorageManager.new()
	var book_v: Variant = loaded.get("mon_id_state", {})
	var book: Dictionary = book_v if book_v is Dictionary else {}
	mgr2.adopt_collections(loaded.get("party", []), loaded.get("boxes", []), loaded.get("pc_storage", []), book)
	var back_party: Dictionary = mgr2.find_mon_by_id(party_id).get("mon", {})
	_check("party Omanyte survives round-trip with id + provenance", str(back_party.get("species_slug", "")) == "omanyte" and int(back_party.get("level", 0)) == 5 and str(back_party.get("revived_from", "")) == "helix-fossil" and str(back_party.get("revival_point", "")) == "kanto_pewter_museum", str(back_party.get("species_slug", "")))
	var back_stored: Dictionary = mgr2.find_mon_by_id(stored_id).get("mon", {})
	_check("stored Aerodactyl survives round-trip with id + provenance", str(back_stored.get("species_slug", "")) == "aerodactyl" and str(back_stored.get("revived_from", "")) == "old-amber", str(back_stored.get("species_slug", "")))
	var fresh: Dictionary = {"name": "Fresh", "species": "Fresh", "species_slug": "fresh", "level": 1, "evo_family": "fresh"}
	mgr2.add_pokemon(fresh)
	_check("post-load mon never reuses a revived mon's id", str(fresh.get("mon_id", "")) != party_id and str(fresh.get("mon_id", "")) != stored_id and not str(fresh.get("mon_id", "")).is_empty())
	PUWSaveManager.delete_save()
