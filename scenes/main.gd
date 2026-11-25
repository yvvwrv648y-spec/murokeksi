class_name MainScene
extends Node
## Main screen. Root node of main.tscn, the scene project.godot
## names as the game's main scene (run/main_scene).
## Plain words: this scene does almost nothing on purpose. It
## shows the game title for a moment, then hands over to the
## Overworld scene through PUWSceneTransition, and the game runs
## from there. When a battle is lost, PUWSceneTransition sends
## the player back here (its "battle_lost" trigger points at
## "main"), and this scene sends them on to the Overworld again,
## so the loop never dead-ends on a screen with nothing to do.
## Every real screen is its own scene: overworld, battle, party,
## bag and mart. This file only boots into the first one.

## Menu structure (PUW_UI_UX_SPEC.md), held as plain data so it
## can be read without a running scene. OPENING_MENU and
## GAME_MENU are the exact spec labels, in spec order.
## menu_target() resolves one entry id: entries backed by a real
## system return {"status": "system", "target": "<id>"}, and
## entries with no system yet honestly return
## {"status": "not_yet_built", "label": "<exact label>",
## "message": "<label> is not built yet."} — nothing spec-listed
## is omitted and nothing is faked as working.
const OPENING_MENU: Array = [
	"New Game",
	"Continue",
	"Load Game",
	"Character Setup",
	"Settings",
	"Accessibility",
	"Credits"
]

const GAME_MENU: Array = [
	"Pokedex",
	"Party",
	"Bag",
	"Trainer Profile",
	"Map",
	"Quest Log",
	"Character Wardrobe",
	"Pokemon Info",
	"Settings",
	"Save",
	"Help"
]

## Entry id -> exact label, for every entry in both menus.
const _MENU_LABELS: Dictionary = {
	"new_game": "New Game",
	"continue": "Continue",
	"load_game": "Load Game",
	"character_setup": "Character Setup",
	"settings": "Settings",
	"accessibility": "Accessibility",
	"credits": "Credits",
	"pokedex": "Pokedex",
	"party": "Party",
	"bag": "Bag",
	"trainer_profile": "Trainer Profile",
	"map": "Map",
	"quest_log": "Quest Log",
	"character_wardrobe": "Character Wardrobe",
	"pokemon_info": "Pokemon Info",
	"save": "Save",
	"help": "Help"
}

## Entry id -> backing system id, only for entries a real system
## already backs: the boot/save flow (PUWSaveManager and this
## scene's boot), the character setup flow (PUWCharacterSetup),
## the pokedex (PUWPokedex), party, bag and Pokemon info scenes,
## and Save (PUWSaveManager).
const _MENU_SYSTEM_TARGETS: Dictionary = {
	"new_game": "new_game",
	"continue": "continue",
	"load_game": "load_game",
	"character_setup": "character_setup",
	"pokedex": "pokedex",
	"party": "party",
	"bag": "bag",
	"pokemon_info": "pokemon_info",
	"save": "save"
}


## Resolve one menu entry id (for example "pokedex" or
## "quest_log") to what selecting it would do right now.
static func menu_target(menu_id: String) -> Dictionary:
	if _MENU_SYSTEM_TARGETS.has(menu_id):
		return {"status": "system", "target": str(_MENU_SYSTEM_TARGETS[menu_id])}
	if _MENU_LABELS.has(menu_id):
		var label: String = str(_MENU_LABELS[menu_id])
		return {"status": "not_yet_built", "label": label, "message": label + " is not built yet."}
	return {"status": "unknown", "label": "", "message": "Unknown menu entry: " + menu_id}


@onready var transition: PUWSceneTransition = $SceneTransition
@onready var title_label: Label = $Title


func _ready() -> void:
	# Title styling (v6 polish pass): big, clean, shadowed.
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", PUWUiTheme.TEXT)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	# Deferred: the scene tree is still setting this scene up
	# while _ready runs, so the scene change is asked for on the
	# next frame instead of right now.
	_start_game.call_deferred()


func _start_game() -> void:
	transition.transition_to("overworld")
