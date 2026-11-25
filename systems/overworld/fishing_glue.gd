class_name PUWFishingGlue
extends RefCounted
## Fishing (mechanics-completeness prep F8, 2026-11-24).
##
## The gap this closes: the bound game has the pieces of
## fishing but no fishing. PUWItemServices.rod_tier knows the
## three rods (its own comment calls the seam "seam-ready:
## encounter tables are staged and PUWHabitatEncounters maps
## the fishing env"), and PUWHabitatEncounters maps the
## "fishing" environment onto water pools -- but no cast,
## roll, or battle hand-off existed anywhere, so a rod in
## the bag did nothing.
##
## cast_line is that seam, composed only of held parts:
##   rod check      -> PUWItemServices.rod_tier
##   encounter roll -> PUWHabitatEncounters.roll_habitat_
##                     encounter(area_id, ..., "fishing")
##   mon build      -> PUWBattleEntry.build_habitat_wild_mon
##                     (the difficulty layer: level = player
##                     max +1..3, IV 31, MDX family preserved
##                     from the roll -- the same builder the
##                     overworld's wild hand-off uses)
## The caller hands a successful result's "mon" to
## BattleScene exactly like the wild hand-off does. Gen 7's
## spot-based fishing is a data property of the areas
## themselves (the habitat environment records), not a
## different code path, so no per-generation branch exists
## here.

var _habitat: PUWHabitatEncounters = null
var _entry: PUWBattleEntry = null


func _get_habitat() -> PUWHabitatEncounters:
	if _habitat == null:
		_habitat = PUWHabitatEncounters.new()
		_habitat.load_data()
	return _habitat


func _get_entry() -> PUWBattleEntry:
	if _entry == null:
		_entry = PUWBattleEntry.new()
	return _entry


## Cast a line in an area. state is the save state (its bag
## must hold the rod when a bag is present in the state);
## party is the player's party (its max level seeds the
## roll); rod_item_id is the rod used ("old-rod" / "good-rod"
## / "super-rod" per PUWItemServices._ROD_TIERS).
## Returns {ok: false, reason} with reason one of
## "not_a_rod" / "rod_not_in_bag" / "no_bite", or
## {ok: true, rod_tier, roll, mon} on a bite.
func cast_line(state: Dictionary, party: Array, area_id: String, rod_item_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var tier: int = PUWItemServices.rod_tier(rod_item_id)
	if tier <= 0:
		return {"ok": false, "reason": "not_a_rod"}
	var bag_value: Variant = state.get("bag", null)
	if bag_value is Dictionary:
		var bag: Dictionary = bag_value
		if int(bag.get(rod_item_id, 0)) <= 0:
			return {"ok": false, "reason": "rod_not_in_bag"}
	var player_max: int = PUWBattleEntry.player_max_level(party)
	var roll: Dictionary = _get_habitat().roll_habitat_encounter(area_id, player_max, rng, "fishing")
	if roll.is_empty():
		return {"ok": false, "reason": "no_bite"}
	var mon: Dictionary = _get_entry().build_habitat_wild_mon(roll, player_max, rng)
	if mon.is_empty():
		return {"ok": false, "reason": "no_bite"}
	return {"ok": true, "rod_tier": tier, "roll": roll, "mon": mon}
