class_name PartyScreenController
extends Control
## 6-slot party inspector with mid-battle switching, Exp. Share toggle, and Permanent Fainting ledger.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "party")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "party")
