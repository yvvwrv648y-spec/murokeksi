class_name ChallengeAndAudioSettingsController
extends Control
## Configures Challenge Run modifiers, Auto-Run Shoes, Audio BGM/SFX, and Co-Op Online toggle.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

var is_open: bool = false

func open_panel() -> void:
	is_open = true
	visible = true
	emit_signal("panel_opened", "settings")

func close_panel() -> void:
	is_open = false
	visible = false
	emit_signal("panel_closed", "settings")
