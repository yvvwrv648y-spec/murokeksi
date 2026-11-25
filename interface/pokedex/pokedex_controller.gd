class_name DualPokedexController
extends Control
## Searchable 1,028-species PKDX & MDX Dual Pokédex with habitat and variant filters.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "pokedex")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "pokedex")
