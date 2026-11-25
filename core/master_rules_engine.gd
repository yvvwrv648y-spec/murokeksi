class_name PUWMasterRulesEngine
extends RefCounted
## Authoritative Versioned Rules Engine (v2.0.0) for Pokemon Ultimate World.
## Enforces: Immutable Pokemon UUIDs, Anti-Duplication, Permanent Fainting + Family Lockout,
## 6-Pokemon Standard Trainer Difficulty, Free Worldwide Supplies, & 5 Distinct Gimmick Slots.

const RULESET_VERSION := "2.0.0"
const MAX_PARTY_SIZE := 6
const STANDARD_SUPPLIES_FREE := true

# 5 Distinct Gimmick Allowances (NEVER merged into a single generic toggle)
const GIMMICK_ALLOWANCES := {
	"mega_evolution": {"slot": 1, "status": "VERIFIED", "kanto_active": false},
	"z_moves": {"slot": 2, "status": "VERIFIED", "kanto_active": false},
	"dynamax_gigantamax": {"slot": 3, "status": "VERIFIED", "kanto_active": false},
	"terastallization": {"slot": 4, "status": "VERIFIED", "kanto_active": false},
	"gimmick_slot_5_pending_canon": {"slot": 5, "status": "REQUIRES_CANON_DECISION", "kanto_active": false}
}

# Permanent Fainting Scope & Unresolved Exception Register
const PERMANENT_FAINTING_EXCEPTIONS := {
	"wild_battle": {"enforced": true, "status": "VERIFIED"},
	"trainer_battle": {"enforced": true, "status": "VERIFIED"},
	"gym_league_battle": {"enforced": true, "status": "VERIFIED"},
	"scripted_story_battle": {"enforced": true, "status": "REQUIRES_CANON_DECISION"},
	"multiplayer_coop_battle": {"enforced": true, "status": "REQUIRES_CANON_DECISION"}
}

var instances_by_id: Dictionary = {}
var party_ids: Array[String] = []
var storage_ids: Array[String] = []
var fainted_ids: Array[String] = []
var locked_evo_families: Dictionary = {}

func register_new_instance(instance_id: String, species_id: String, evo_family_id: String, dex_family: String) -> Dictionary:
	if instances_by_id.has(instance_id):
		return {"ok": false, "error": "DUPLICATE_INSTANCE_ID"}
	if locked_evo_families.has(evo_family_id):
		return {"ok": false, "error": "EVOLUTION_FAMILY_LOCKED_OUT"}
	var rec := {
		"instance_id": instance_id,
		"species_id": species_id,
		"evo_family_id": evo_family_id,
		"dex_family": dex_family,
		"location_state": "PARTY" if party_ids.size() < MAX_PARTY_SIZE else "STORAGE",
		"fainted_permanently": false
	}
	instances_by_id[instance_id] = rec
	if rec["location_state"] == "PARTY":
		party_ids.append(instance_id)
	else:
		storage_ids.append(instance_id)
	return {"ok": true, "destination": rec["location_state"], "instance": rec}

func apply_permanent_faint(instance_id: String, battle_format: String) -> Dictionary:
	if not instances_by_id.has(instance_id):
		return {"ok": false, "error": "UNKNOWN_INSTANCE"}
	var rec: Dictionary = instances_by_id[instance_id]
	rec["fainted_permanently"] = true
	rec["location_state"] = "PERMA_FAINTED"
	party_ids.erase(instance_id)
	storage_ids.erase(instance_id)
	if not fainted_ids.has(instance_id):
		fainted_ids.append(instance_id)
	locked_evo_families[rec["evo_family_id"]] = {"battle_format": battle_format, "instance_id": instance_id}
	return {"ok": true, "family_locked": rec["evo_family_id"]}
