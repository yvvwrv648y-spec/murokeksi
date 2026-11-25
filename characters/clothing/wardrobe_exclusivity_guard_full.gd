class_name PUWWardrobeExclusivityGuardFull
extends RefCounted
## Full exclusivity guard (staged 2026-11-24) -- the logic the
## bound characters/clothing/wardrobe_exclusivity_guard.gd
## declares in its docstring but does not implement (the bound
## file is three const outfit lists and no functions).
##
## Rules enforced here, all from canon:
## 1. Riley's and Tasha's signature hair and outfits are
##    EXCLUSIVE: no custom profile may equip them, ever. (The
##    hairstyle half is also enforced inside
##    PUWCharacterSetup.set_value_result and
##    ModularCharacterRig.apply_profile; this guard is the
##    outfit half plus one shared entry point.)
## 2. Outfits are scoped per cast (the rule PUWWardrobeShop
##    already applies at buy/wear time): a profile may equip
##    only outfits registered to its own cast id.
## 3. Mount/dismount PRESERVES the equipped outfit: the bound
##    guard's docstring promises this and nothing implemented
##    it. snapshot_outfit()/restore_outfit() are the pair a
##    mount system calls around a ride state change.
##
## This class is pure logic over profile Dictionaries and the
## wardrobe registry's shape; it loads no art and owns no
## state.

## Outfit ids exclusive to the named protagonists (the bound
## guard's lists, transcribed).
const RILEY_OUTFITS: Array = ["canon", "lounge", "bikini"]
const TASHA_OUTFITS: Array = ["canon", "gothic_glam", "obsidian_bikini"]
const NAMED_CASTS: Array = ["riley", "tasha"]


## True when outfit_id is one of the named protagonists'
## exclusive outfits for cast_id.
static func is_exclusive_outfit(cast_id: String, outfit_id: String) -> bool:
	if cast_id == "riley":
		return RILEY_OUTFITS.has(outfit_id)
	if cast_id == "tasha":
		return TASHA_OUTFITS.has(outfit_id)
	return false


## The equip decision, MartShop-style result shape:
## {ok, reason}. A profile (with "cast_id") may equip the
## catalog entry (cast_id + outfit_id, PUWWardrobeShop's id
## split) only when the entry's cast matches the profile's
## cast. That single rule yields exclusivity for free: a
## custom profile's cast never equals "riley"/"tasha", so the
## named protagonists' outfits are refused with the plain
## reason below; a named protagonist wearing their OWN
## exclusive outfit passes.
static func can_equip(profile: Dictionary, entry_cast_id: String, outfit_id: String) -> Dictionary:
	var profile_cast: String = str(profile.get("cast_id", ""))
	if entry_cast_id == profile_cast:
		return {"ok": true, "reason": ""}
	if NAMED_CASTS.has(entry_cast_id) and is_exclusive_outfit(entry_cast_id, outfit_id):
		return {"ok": false, "reason": "That outfit belongs to a named character and can't be worn by anyone else."}
	return {"ok": false, "reason": "That outfit is made for a different character."}


## Snapshot the profile's equipped outfit before a mount /
## ride state change. Returns {} when nothing is equipped.
static func snapshot_outfit(profile: Dictionary) -> Dictionary:
	var outfit: String = str(profile.get("current_outfit", ""))
	if outfit == "":
		return {}
	return {
		"current_outfit": outfit,
		"current_context": str(profile.get("current_context", "")),
	}


## Restore a snapshot taken by snapshot_outfit() after the
## mount state ends. An empty snapshot clears nothing and
## returns false (the ride state simply never recorded an
## outfit to preserve).
static func restore_outfit(profile: Dictionary, snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	profile["current_outfit"] = str(snapshot.get("current_outfit", ""))
	profile["current_context"] = str(snapshot.get("current_context", ""))
	return true
