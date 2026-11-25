extends SceneTree
## Runtime checks for the Kanto encounter R-1 closure prep, run
## against the R-1 patched habitat_encounters.gd + R-1 patched
## wild_encounters.json. Asserts the 18 FRLG land placements named
## in the fixes prep's residual R-1 are now reachable on their maps
## through the frlg_land_membership layer (source_members), on land
## (grass) rolls at party_max 100, empty rotation.

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


func _member_of(hab: PUWHabitatEncounters, area: String, species_id: int) -> bool:
	var per_env: Dictionary = hab.source_membership(area)
	var list_v: Variant = per_env.get("grassland", [])
	if list_v is Array:
		return (list_v as Array).has(species_id)
	return false


func _init() -> void:
	var hab = PUWHabitatEncounters.new()
	_check(hab.load_data(), "load_data() succeeds")
	_check(hab.species_count() == 1028, "1028 species loaded")

	# The 18 R-1 placements: [area, species_id, slug].
	var r1: Array = [
		["VICTORY_ROAD_2F", 57, "primeape"],
		["VICTORY_ROAD_3F", 105, "marowak"],
		["CERULEAN_CAVE_1F", 67, "machoke"],
		["CERULEAN_CAVE_1F", 57, "primeape"],
		["CERULEAN_CAVE_1F", 202, "wobbuffet"],
		["CERULEAN_CAVE_2F", 67, "machoke"],
		["CERULEAN_CAVE_2F", 202, "wobbuffet"],
		["CERULEAN_CAVE_B1F", 64, "kadabra"],
		["CERULEAN_CAVE_B1F", 67, "machoke"],
		["CERULEAN_CAVE_B1F", 202, "wobbuffet"],
		["ROCK_TUNNEL_1F", 56, "mankey"],
		["ROCK_TUNNEL_B1F", 56, "mankey"],
		["SEAFOAM_ISLANDS_B4F", 87, "dewgong"],
		["ROUTE_3", 56, "mankey"],
		["ROUTE_4", 56, "mankey"],
		["ROUTE_22", 56, "mankey"],
		["ROUTE_23", 56, "mankey"],
		["ROUTE_23", 57, "primeape"],
	]
	for row in r1:
		var area: String = str(row[0])
		var sid: int = int(row[1])
		var slug: String = str(row[2])
		_check(_member_of(hab, area, sid),
			slug + " is a grassland source member of " + area)
		_check(_has(hab.get_eligible_pool(area, 100, "grass"), sid),
			slug + " eligible (grass) in " + area)

	# Membership, not fit, does the work on the terrain roll: none of
	# the R-1 species fits the grassland environment by habitat/type
	# alone (checked against the loaded data, not assumed).
	for row in r1:
		var sid2: int = int(row[1])
		_check(not hab.species_fits(sid2, ["grassland"]),
			str(row[2]) + " does not fit grassland by habitat/type")

	# The layer adds members only on its twelve maps: an unaffected
	# neighbour keeps exactly its record membership (Route 5's
	# grassland members are its pokered land species; primeape is
	# not among them and mankey already was a pokered member there).
	_check(not _member_of(hab, "ROUTE_5", 57),
		"primeape is not a source member of ROUTE_5 (no layer there)")
	_check(_member_of(hab, "ROUTE_5", 56),
		"mankey remains a source member of ROUTE_5 (pokered table)")

	# Rate-0 invariant still holds.
	_check(hab.build_pool("POKEMON_TOWER_1F").is_empty(),
		"POKEMON_TOWER_1F pool empty (rate-0 source)")
	_check(hab.build_pool("POKEMON_TOWER_2F").is_empty(),
		"POKEMON_TOWER_2F pool empty (rate-0 source)")

	print("checks: ", _checks, "  failures: ", _failures)
	quit(1 if _failures > 0 else 0)
