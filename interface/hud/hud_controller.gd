class_name OverworldHudController
extends Control
## Displays Badges, Badge Level Cap, Active Bike/Sneak Noise Meter, and Quest Tracker.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "hud")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "hud")
