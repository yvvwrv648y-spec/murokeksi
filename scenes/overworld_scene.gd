class_name OverworldScene
extends Node2D
## Overworld screen. Root node of overworld.tscn.
## A simple 2D map placeholder: a flat green ground, one tall-grass
## patch that starts a wild battle, and a player who walks with
## WASD or the arrow keys. The camera follows the player.
## This is NOT the real Kanto map. The real map data lives in
## world/regions/kanto/maps/*.json and has not been turned into a
## TileMap yet. The empty TileMapLayer node in the scene is the
## placeholder where the real map goes.
## Movement uses the built-in ui_left / ui_right / ui_up / ui_down
## actions (Godot has these by default) plus the W, A, S, D keys.
## project.godot has no custom input actions yet.

## Difficulty-wiring build (B7): the hardcoded WILD_TABLE
## placeholder hand-off is RETIRED. Wild battles now run the
## real path — PUWHabitatEncounters roll -> PUWBattleEntry
## (PUWTeamBuilder.build_wild_mon: level = player max +1..3,
## IV 31, MDX family preserved) -> the hand-off guard ->
## BattleScene. This placeholder scene rolls on ROUTE_1 (its
## grass patch is a stand-in for a real map); real map scenes
## pass their own map id constant to the same code.

const SPEED: float = 200.0
const ENCOUNTER_COOLDOWN: float = 5.0
const PLACEHOLDER_MAP_ID: String = "ROUTE_1"

@onready var player: CharacterBody2D = $Player
@onready var encounter_area: Area2D = $EncounterArea
@onready var hint_label: Label = $UI/HintLabel
@onready var bag_button: Button = $UI/MenuButtons/BagButton
@onready var party_button: Button = $UI/MenuButtons/PartyButton
@onready var mart_button: Button = $UI/MenuButtons/MartButton

var encounter_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _habitat: PUWHabitatEncounters = null
var _entry: PUWBattleEntry = null


func _ready() -> void:
	rng.randomize()
	# Shared screen look (v6 polish pass) for the menu layer.
	# The UI root is a CanvasLayer, so the theme goes on its
	# Control children: the hint label and the button row.
	var shared_theme: Theme = PUWUiTheme.make_theme()
	hint_label.theme = shared_theme
	var menu_row: Control = $UI/MenuButtons as Control
	if menu_row != null:
		menu_row.theme = shared_theme
	# Make sure there is a party to fight with. The Party screen
	# owns the shared party list; if it is empty, a demo Pikachu
	# BUILT by the difficulty layer (never a raw dict) fills it.
	if PartyScene.party.is_empty():
		PartyScene.party = [PUWTeamBuilder.new().build_mon("Pikachu", 12, "singles")]
	# B7: the habitat encounter system behind the wild hand-off.
	_habitat = PUWHabitatEncounters.new()
	_habitat.load_data()
	_entry = PUWBattleEntry.new()
	hint_label.text = "Move with WASD or arrow keys. Walk into the tall grass for a wild battle."
	encounter_area.body_entered.connect(_on_encounter_body_entered)
	bag_button.pressed.connect(_on_bag_pressed)
	party_button.pressed.connect(_on_party_pressed)
	mart_button.pressed.connect(_on_mart_pressed)


func _physics_process(delta: float) -> void:
	if encounter_timer > 0.0:
		encounter_timer -= delta
	var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	dir = dir.normalized()
	player.velocity = dir * SPEED
	player.move_and_slide()


func _on_encounter_body_entered(body: Node2D) -> void:
	if body != player:
		return
	if encounter_timer > 0.0:
		return
	encounter_timer = ENCOUNTER_COOLDOWN
	_start_wild_battle()


func _start_wild_battle() -> void:
	# B7 real hand-off: habitat roll -> built wild mon -> guard.
	# No eligible roll (or habitat data absent) means no battle,
	# never a placeholder one.
	if _habitat == null or _entry == null:
		return
	var player_max: int = PUWBattleEntry.player_max_level(PartyScene.party)
	var roll: Dictionary = _habitat.roll_habitat_encounter(PLACEHOLDER_MAP_ID, player_max, rng)
	if roll.is_empty():
		return
	var wild: Dictionary = _entry.build_habitat_wild_mon(roll, player_max, rng)
	if wild.is_empty():
		return
	var level_rule: Dictionary = {"min": player_max + 1, "max": mini(player_max + 3, 100)}
	var verdict: Dictionary = PUWBattleEntry.hand_off([wild], 1, level_rule)
	if not bool(verdict.get("ok", false)):
		push_warning("OverworldScene: wild hand-off refused: " + str(verdict.get("problems", [])))
		return
	BattleScene.pending_player_party = PartyScene.party
	BattleScene.pending_enemy_party = [wild]
	# Styler merge step 3 (binding build 4): the battle is
	# fought in the campaign's active region. The scene layer
	# holds no state of its own; the campaign state reaches
	# scenes through the shared channel BagScene.save_state
	# (the same channel the bag scene reads for its gimmick
	# gates). Until a state-bearing caller sets it, the
	# channel is empty and active_region reads the default
	# region -- which is this placeholder scene's region.
	BattleScene.pending_campaign_region_id = PUWRegionState.active_region(BagScene.save_state)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _on_bag_pressed() -> void:
	BagScene.return_scene_path = "res://scenes/overworld.tscn"
	BagScene.target_mon = PartyScene.party[0] if not PartyScene.party.is_empty() else {}
	get_tree().change_scene_to_file("res://scenes/bag.tscn")


func _on_party_pressed() -> void:
	PartyScene.return_scene_path = "res://scenes/overworld.tscn"
	PartyScene.in_battle = false
	PartyScene.party = PartyScene.party
	get_tree().change_scene_to_file("res://scenes/party.tscn")


func _on_mart_pressed() -> void:
	MartScene.return_scene_path = "res://scenes/overworld.tscn"
	get_tree().change_scene_to_file("res://scenes/mart.tscn")
