extends SceneTree
## Runtime checks for the Kanto encounter fixes prep, run against
## the PATCHED habitat_encounters.gd + patched data files.
## Asserts Bossy's ruling (source placement wins) end to end:
## Unown in Tanoby, Seel/Horsea at Seafoam, the new town tables,
## the Cerulean Gym Super Rod table, preserved-case reporting,
## and the Pokemon Tower rate-0 invariant.

var _failures: int = 0
var _checks: int = 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)


func _has(pool: Array, species_id: int) -> bool:
	for e in pool:
		if int(e.get("species", -1)) == species_id:
			return true
	return false


func _init() -> void:
	var hab = PUWHabitatEncounters.new()
	_check(hab.load_data(), "load_data() succeeds")
	_check(hab.species_count() == 1028, "1028 species loaded")

	# Unown (201) reachable on land in all seven Tanoby chambers.
	var chambers: Array = [
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_MONEAN_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_LIPTOO_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_WEEPTH_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_DILFORD_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_SCUFIB_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_RIXY_CHAMBER",
		"MAP_SEVEN_ISLAND_TANOBY_RUINS_VIAPOIS_CHAMBER",
	]
	for c in chambers:
		_check(_has(hab.get_eligible_pool(c, 100, "grass"), 201),
			"unown eligible (grass) in " + c)
		var preserved: Array = hab.source_preserved_species(c)
		_check(preserved.size() == 1 and int(preserved[0]) == 201,
			"unown is the logged preserved case in " + c)

	# Seafoam: Seel (86) on land rolls, Horsea (116) on fishing.
	for area in ["SEAFOAM_ISLANDS_1F", "SEAFOAM_ISLANDS_B1F",
			"SEAFOAM_ISLANDS_B2F", "SEAFOAM_ISLANDS_B3F",
			"SEAFOAM_ISLANDS_B4F"]:
		_check(_has(hab.get_eligible_pool(area, 100, "grass"), 86),
			"seel eligible (grass) in " + area)
	for area in ["SEAFOAM_ISLANDS_B3F", "SEAFOAM_ISLANDS_B4F"]:
		_check(_has(hab.get_eligible_pool(area, 100, "fishing"), 116),
			"horsea eligible (fishing) in " + area)
	for area in ["ROUTE_4", "ROUTE_10", "ROUTE_11", "ROUTE_12",
			"ROUTE_13", "ROUTE_24"]:
		_check(_has(hab.get_eligible_pool(area, 100, "fishing"), 116),
			"horsea eligible (fishing) in " + area)

	# The nine previously entry-less maps now serve pools.
	_check(not hab.build_pool("PALLET_TOWN").is_empty(),
		"PALLET_TOWN pool non-empty")
	_check(_has(hab.get_eligible_pool("PALLET_TOWN", 100, "water"), 129),
		"magikarp eligible (water) in PALLET_TOWN")
	_check(_has(hab.get_eligible_pool("VERMILION_DOCK", 100, "water"), 72),
		"tentacool eligible (water) in VERMILION_DOCK")
	_check(_has(hab.get_eligible_pool("FUCHSIA_CITY", 100, "water"), 129),
		"magikarp eligible (water) in FUCHSIA_CITY")

	# Cerulean Gym: Gen 1 Super Rod group 3 (Psyduck 54 at Lv 15).
	var gym_pool: Array = hab.get_eligible_pool("CERULEAN_GYM", 100, "fishing")
	_check(_has(gym_pool, 54), "psyduck eligible (fishing) in CERULEAN_GYM")
	_check(_has(gym_pool, 118), "goldeen eligible (fishing) in CERULEAN_GYM")
	_check(_has(gym_pool, 98), "krabby eligible (fishing) in CERULEAN_GYM")

	# Audit section 3 spot cases.
	_check(_has(hab.get_eligible_pool("CERULEAN_CAVE_1F", 100, "grass"), 64),
		"kadabra eligible (grass) in CERULEAN_CAVE_1F")
	_check(_has(hab.get_eligible_pool("POKEMON_TOWER_5F", 100, "grass"), 104),
		"cubone eligible (grass) in POKEMON_TOWER_5F")
	_check(_has(hab.get_eligible_pool("POKEMON_MANSION_3F", 100, "grass"), 126),
		"magmar eligible (grass) in POKEMON_MANSION_3F")
	_check(_has(hab.get_eligible_pool("MAP_SIX_ISLAND_RUIN_VALLEY", 100, "grass"), 202),
		"wobbuffet eligible (grass) in MAP_SIX_ISLAND_RUIN_VALLEY")
	_check(_has(hab.get_eligible_pool("ROUTE_17", 100, "fishing"), 54),
		"psyduck eligible (fishing) in ROUTE_17")
	_check(_has(hab.get_eligible_pool("ROUTE_18", 100, "fishing"), 54),
		"psyduck eligible (fishing) in ROUTE_18")

	# Membership reporting: Route 17's source members include its
	# FRLG fishing species.
	var m17: Dictionary = hab.source_membership("ROUTE_17")
	_check(m17.has("water"), "ROUTE_17 has water source membership")

	# Rate-0 invariant: Tower 1F/2F still serve empty pools.
	_check(hab.build_pool("POKEMON_TOWER_1F").is_empty(),
		"POKEMON_TOWER_1F pool empty (rate-0 source)")
	_check(hab.build_pool("POKEMON_TOWER_2F").is_empty(),
		"POKEMON_TOWER_2F pool empty (rate-0 source)")

	print("checks: ", _checks, "  failures: ", _failures)
	quit(1 if _failures > 0 else 0)
