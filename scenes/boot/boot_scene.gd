class_name PUWBootScene
extends Control
## Title / boot scene (host assembly prep, 2026-11-24).
##
## Replaces the old main scene's behavior (show the title for
## a moment, then blindly transition to the placeholder
## overworld). This scene is the title screen Riley plays:
##
##   New Game -> character creation (cast pick + name; the
##     full 11-step PUWCharacterSetup flow is the creator UI
##     that feeds the same confirm path -- its built dict is
##     passed to PUWBootFlow.new_game as `character`) ->
##     PUWBootFlow.new_game -> game host. A custom character
##     boots into OaksLab, where the host runs the Oak event;
##     Riley / Tasha boot into Pallet Town with their verified
##     teams already granted by the stitch.
##   Continue -> PUWBootFlow.continue_game -> game host on
##     the saved map. No save = the button is disabled, never
##     a fabricated game.
##
## All state creation lives in PUWBootFlow; this scene only
## collects choices and hands over through its pending_boot
## channel. Music: the audio prep's director plays the title
## track from _ready.

const HOST_SCENE: String = "res://scenes/host/game_host.tscn"
const CAST_CHOICES: Array = [
	{"cast_id": "riley", "label": "Riley (fixed protagonist)"},
	{"cast_id": "tasha", "label": "Tasha (fixed protagonist)"},
	{"cast_id": "custom_female", "label": "Custom - Female"},
	{"cast_id": "custom_male", "label": "Custom - Male"},
	{"cast_id": "custom_femboy", "label": "Custom - Femboy"},
	{"cast_id": "custom_futanari", "label": "Custom - Futanari"},
]

var _cast_id: String = "custom_female"
var _name_edit: LineEdit = null
var _create_panel: VBoxContainer = null
var _menu_panel: VBoxContainer = null
var _status_label: Label = null


func _ready() -> void:
	var director: PUWMusicDirector = PUWMusicDirector.new()
	director.name = "MusicDirector"
	add_child(director)
	director.play_track("ost_main_title")
	theme = PUWUiTheme.make_theme()
	var title: Label = Label.new()
	title.text = "Pokémon Ultimate World"
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)
	_menu_panel = VBoxContainer.new()
	add_child(_menu_panel)
	var new_button: Button = Button.new()
	new_button.text = "New Game"
	new_button.pressed.connect(_on_new_game_pressed)
	_menu_panel.add_child(new_button)
	var continue_button: Button = Button.new()
	continue_button.text = "Continue"
	continue_button.disabled = not PUWSaveManager.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	_menu_panel.add_child(continue_button)
	_create_panel = VBoxContainer.new()
	_create_panel.visible = false
	add_child(_create_panel)
	for choice_value in CAST_CHOICES:
		var choice: Dictionary = choice_value
		var cast_button: Button = Button.new()
		cast_button.text = str(choice.get("label", ""))
		var chosen_id: String = str(choice.get("cast_id", ""))
		cast_button.pressed.connect(func() -> void: _cast_id = chosen_id)
		_create_panel.add_child(cast_button)
	_name_edit = LineEdit.new()
	_name_edit.text = "RED"
	_name_edit.placeholder_text = "Your name"
	_create_panel.add_child(_name_edit)
	var start_button: Button = Button.new()
	start_button.text = "Start"
	start_button.pressed.connect(_on_start_pressed)
	_create_panel.add_child(start_button)
	_status_label = Label.new()
	add_child(_status_label)
	PUWFocus.grab_first_enabled([new_button, continue_button])


func _on_new_game_pressed() -> void:
	_menu_panel.visible = false
	_create_panel.visible = true


func _on_start_pressed() -> void:
	var player_name: String = _name_edit.text.strip_edges()
	if player_name == "":
		player_name = "RED"
	# Fixed protagonists keep the direct path (fold-in round,
	# creator bind step 4).
	if _cast_id == "riley" or _cast_id == "tasha":
		var result: Dictionary = PUWBootFlow.new_game(_cast_id, player_name)
		_launch(result)
		return
	# Custom path: the 11-step creator screen collects the
	# character dict and runs the same pending_boot hand-off
	# on confirm (its finish() calls PUWBootFlow.new_game
	# with the built character). Configure BEFORE the screen
	# enters the tree — its _ready reads the cast id.
	_create_panel.visible = false
	var screen: PUWCharacterCreatorScreen = PUWCharacterCreatorScreen.new()
	screen.configure(_cast_id, player_name)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


func _on_continue_pressed() -> void:
	var result: Dictionary = PUWBootFlow.continue_game()
	if not bool(result.get("ok", false)):
		_status_label.text = "No save game found."
		return
	_launch(result)


func _launch(result: Dictionary) -> void:
	PUWBootFlow.pending_boot = result
	get_tree().change_scene_to_file(HOST_SCENE)
