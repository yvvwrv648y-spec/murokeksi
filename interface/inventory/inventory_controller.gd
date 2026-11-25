class_name EmptyStartBagController
extends Control
## Starts strictly empty (0 items); receives infinite free supplies from Kira, Haruka, and Vance.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "inventory")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "inventory")
