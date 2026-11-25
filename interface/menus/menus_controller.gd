class_name MainPauseMenuController
extends Control
## Root pause menu routing to Party, Bag, Dual Pokédex, Kanto/Sevii Map, Challenge Rules, and Settings.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "menus")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "menus")
