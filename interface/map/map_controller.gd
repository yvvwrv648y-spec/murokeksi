class_name KantoWorldMapController
extends Control
## Interactive Kanto + Sevii Islands 72-map fast-travel & Indigo Plateau League tracker.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "map")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "map")
