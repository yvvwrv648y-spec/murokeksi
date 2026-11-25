class_name DexAndUniquenessLedger
extends RefCounted
## Maintains separate Pokemon (PKDX) and Moemon (MDX) species identities and
## enforces persistent, atomic singleton uniqueness for Legendary/Mythical species.

const FAMILY_POKEMON := "pokemon"
const FAMILY_MOEMON := "moemon"

var pkdx_seen: Dictionary = {}
var pkdx_caught: Dictionary = {}
var mdx_seen: Dictionary = {}
var mdx_caught: Dictionary = {}
var singleton_ledger: Dictionary = {}
var live_moemon_encounters_enabled: bool = false

func make_species_key(family: String, base_species_id: int) -> String:
	assert(family == FAMILY_POKEMON or family == FAMILY_MOEMON)
	return "%s:%04d" % [family, base_species_id]

func claim_legendary_singleton(family: String, base_species_id: int, context: String) -> bool:
	var key := make_species_key(family, base_species_id)
	if singleton_ledger.has(key):
		return false
	singleton_ledger[key] = {
		"claimed": true,
		"context": context,
		"family": family,
		"base_species_id": base_species_id
	}
	return true

func is_singleton_claimed(family: String, base_species_id: int) -> bool:
	return singleton_ledger.has(make_species_key(family, base_species_id))

func record_seen(family: String, base_species_id: int) -> void:
	if family == FAMILY_MOEMON:
		mdx_seen[base_species_id] = true
	else:
		pkdx_seen[base_species_id] = true

func record_caught(family: String, base_species_id: int) -> void:
	record_seen(family, base_species_id)
	if family == FAMILY_MOEMON:
		mdx_caught[base_species_id] = true
	else:
		pkdx_caught[base_species_id] = true

func to_save_dict() -> Dictionary:
	return {
		"pkdx_seen": pkdx_seen.keys(),
		"pkdx_caught": pkdx_caught.keys(),
		"mdx_seen": mdx_seen.keys(),
		"mdx_caught": mdx_caught.keys(),
		"singleton_ledger": singleton_ledger.duplicate(true),
		"live_moemon_encounters_enabled": live_moemon_encounters_enabled
	}
