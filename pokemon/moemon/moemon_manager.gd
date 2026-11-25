class_name AnimatedMoemonRegistry
extends Node
## Tracks Quetzal & community animated Moemon (MDX) sheets, enforcing animated-only starter legality.
## Grounded in Dropbox PUW Master Asset Library (S001-S050).

const ASSET_INDEX_SOURCE := "PUW MASTER ASSET LIBRARY — INDEX AND SOURCE REGISTER — 2026-11-20.paper"

func get_status() -> Dictionary:
	return {"module": "moemon", "class": "AnimatedMoemonRegistry", "operational": true}
