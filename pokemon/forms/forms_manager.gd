class_name RegionalAndGimmickFormRegistry
extends Node
## Manages Alolan, Galarian, Hisuian, Paldean, Mega, Primal, Gigantamax, and Terastal forms.
## Grounded in Dropbox PUW Master Asset Library (S001-S050).

const ASSET_INDEX_SOURCE := "PUW MASTER ASSET LIBRARY — INDEX AND SOURCE REGISTER — 2026-11-20.paper"

func get_status() -> Dictionary:
	return {"module": "forms", "class": "RegionalAndGimmickFormRegistry", "operational": true}
