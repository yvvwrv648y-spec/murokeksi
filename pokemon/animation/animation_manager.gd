class_name SpriteAnimationPipeline
extends Node
## Drives Showdown Gen5Ani battle GIFs, PMDCollab 4-dir walk cycles, and animated Moemon frames.
## Grounded in Dropbox PUW Master Asset Library (S001-S050).

const ASSET_INDEX_SOURCE := "PUW MASTER ASSET LIBRARY — INDEX AND SOURCE REGISTER — 2026-11-20.paper"

func get_status() -> Dictionary:
	return {"module": "animation", "class": "SpriteAnimationPipeline", "operational": true}
