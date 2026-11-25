class_name BW2ArtIntakeLoader
extends RefCounted
## Quarantined loader for res://assets_candidate/bw2_recovered/.
## Refuses promotion unless approval_receipt.json explicitly sets approved_for_live_swap = true.

const CANDIDATE_ROOT := "res://assets_candidate/bw2_recovered/"
const RECEIPT_PATH := CANDIDATE_ROOT + "approval_receipt.json"
const MANIFEST_PATH := CANDIDATE_ROOT + "art_intake_manifest.json"

static func is_candidate_pack_approved() -> bool:
	if not FileAccess.file_exists(RECEIPT_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECEIPT_PATH))
	return typeof(parsed) == TYPE_DICTIONARY and parsed.get("approved_for_live_swap", false) == true

static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
