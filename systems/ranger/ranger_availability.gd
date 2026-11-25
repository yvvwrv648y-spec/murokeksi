class_name PUWRangerAvailability
extends RefCounted
## RANGER VARIANT A — THE AVAILABILITY LAYER (Bossy's ruling P1,
## adopted 2026-11-23; ranger_deep/RANGER_DEEP.md section 2,
## region_build_prep/ranger/RANGER_BUILD_PREP.md section 5.4).
##
## The Capture Styler exists ONLY inside the three Ranger
## regions (Fiore, Almia, Oblivia). Outside them the system does
## not exist at all: no Styler capture, no Friend roster, no
## Ranger Rank. Inside them, Poke Balls are INERT -- Ranger
## regulations, in-fiction: wild Pokemon are befriended with the
## Styler, never caught in Balls. Both rules are enforced here,
## in the item/system availability layer, region-keyed off the
## active region (PUWRegionState.active_region -- the same
## region source the campaign stitch's Omni lock reads).
##
## This module is the single gate every caller asks:
## - BattleController.attempt_capture asks balls_inert_in()
##   before any ball is thrown (see the merge patch).
## - The Styler system itself asks styler_exists_in() before
##   any capture session opens.
## - Menus / the bag ask capture_method() to present the right
##   verb ("Befriend" in Ranger regions, "Throw Ball" elsewhere).
##
## Nothing here touches party, storage, or faint records; this
## file only answers questions about a region id.

const RANGER_REGIONS: Array = ["fiore", "almia", "oblivia"]


## True when region_id is one of the three Ranger regions.
static func is_ranger_region(region_id: String) -> bool:
	return RANGER_REGIONS.has(region_id)


## The Styler exists in exactly the Ranger regions, nowhere else.
static func styler_exists_in(region_id: String) -> bool:
	return is_ranger_region(region_id)


## Poke Balls are inert in exactly the Ranger regions.
static func balls_inert_in(region_id: String) -> bool:
	return is_ranger_region(region_id)


## The capture verb for a region: "styler" inside the Ranger
## regions, "ball" everywhere else in the world.
static func capture_method_in(region_id: String) -> String:
	if is_ranger_region(region_id):
		return "styler"
	return "ball"


## State-reading conveniences (active region from the save).
static func styler_active(state: Dictionary) -> bool:
	return styler_exists_in(PUWRegionState.active_region(state))


static func balls_inert(state: Dictionary) -> bool:
	return balls_inert_in(PUWRegionState.active_region(state))


static func capture_method(state: Dictionary) -> String:
	return capture_method_in(PUWRegionState.active_region(state))
