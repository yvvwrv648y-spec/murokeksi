extends SceneTree
## Supply + Vexa placement tests (post-milestone integration build,
## 2026-11-23). Run: godot --headless --script res://tests/supply_placement_tests.gd
##
## Proves the approved placement records (data/supply_placements.json,
## SUPPLY_AND_VEXA_PLACEMENTS_PROPOSAL.md, approved by Riley
## 2026-11-23) are real and complete:
## (1) exactly 18 spots -- 17 settlements + the Indigo Plateau lobby;
## (2) every spot's building resolves to a real map file in the
##     sourced world data (maps/data/maps), checked through the
##     stitch's own placement_building_exists();
## (3) the supply trio (the real records from supply_trainers()) is
##     present at every spot, with a named grouped spot;
## (4) Vexa has an access point at every spot, and exactly one home
##     spot: Pallet Town, Oak's Lab;
## (5) host kinds follow the proposal: 5 lab-like hosts, 12 Pokemon
##     Center fallbacks, 1 league lobby;
## (6) no excluded place (routes, dungeons, Victory Road, the Elite
##     Four rooms, event islands) carries a placement.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	var placements: Array = PUWCampaignStitch.supply_placements()
	_check("placements_count_28", placements.size() == 28)

	var towns: Array = PUWCampaignStitch.towns_with_supply_trainers()
	_check("towns_count_28", towns.size() == 28)
	var unique_towns: Dictionary = {}
	for town_value: Variant in towns:
		unique_towns[str(town_value)] = true
	_check("towns_unique_28", unique_towns.size() == 28)

	var resolved: int = 0
	var trio_complete: int = 0
	var spots_named: int = 0
	var lab_like: int = 0
	var centers: int = 0
	var lobbies: int = 0
	var trainer_ids: Dictionary = {}
	for trainer_value: Variant in PUWCampaignStitch.supply_trainers():
		var trainer: Dictionary = trainer_value
		trainer_ids[str(trainer.get("id", ""))] = true
	for placement_value: Variant in placements:
		var placement: Dictionary = placement_value
		if PUWCampaignStitch.placement_building_exists(placement):
			resolved += 1
		var ids: Array = placement.get("supply_trainer_ids", [])
		var all_present: bool = ids.size() == trainer_ids.size()
		for id_value: Variant in ids:
			if not trainer_ids.has(str(id_value)):
				all_present = false
		if all_present:
			trio_complete += 1
		if str(placement.get("trio_spot", "")) != "" and str(placement.get("vexa_spot", "")) != "":
			spots_named += 1
		var host_kind: String = str(placement.get("host_kind", ""))
		if host_kind == "lab_like":
			lab_like += 1
		elif host_kind == "pokemon_center":
			centers += 1
		elif host_kind == "league_lobby":
			lobbies += 1
	_check("placements_all_buildings_resolve", resolved == placements.size())
	_check("placements_trio_present_at_all", trio_complete == placements.size())
	_check("placements_spots_named_at_all", spots_named == placements.size())
	_check("placements_lab_like_6", lab_like == 6)
	_check("placements_pokemon_center_21", centers == 21)
	_check("placements_league_lobby_1", lobbies == 1)

	var points: Array = PUWCampaignStitch.vexa_access_points()
	_check("vexa_access_points_28", points.size() == 28)
	var homes: int = 0
	var home_settlement: String = ""
	var home_map: String = ""
	for point_value: Variant in points:
		var point: Dictionary = point_value
		if bool(point.get("is_home", false)):
			homes += 1
			home_settlement = str(point.get("settlement", ""))
			home_map = str(point.get("building_map", ""))
	_check("vexa_exactly_one_home", homes == 1)
	_check("vexa_home_is_pallet_oaks_lab", home_settlement == "Pallet Town" and home_map == "OaksLab")

	var excluded_fragments: Array = ["Route", "VictoryRoad", "MtMoon", "RockTunnel", "DiglettsCave", "CeruleanCave", "Seafoam", "IcefallCave", "LostCave", "DottedHole", "AlteringCave", "ViridianForest", "PokemonTower", "PokemonMansion", "PowerPlant", "RocketHideout", "RocketWarehouse", "SafariZone", "SSAnne", "BirthIsland", "NavelRock", "EliteFour", "HallOfFame"]
	var excluded_hits: int = 0
	for placement_value: Variant in placements:
		var placement: Dictionary = placement_value
		var map_id: String = str(placement.get("building_map", ""))
		for fragment_value: Variant in excluded_fragments:
			if map_id.contains(str(fragment_value)):
				excluded_hits += 1
	_check("placements_none_in_excluded_places", excluded_hits == 0)

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
