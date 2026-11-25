class_name BattleHUD
extends Control
## Battle HUD controller for Pokemon Ultimate World, battle engine v4.
##
## Nodes _ready() creates (no scene file is needed; attach this script
## to a Control node in the Battle scene and _ready() builds the rest):
## - enemy_sprite: TextureRect, the foe's sprite.
## - player_sprite: TextureRect, the player's sprite.
## - enemy_name_label: Label, foe name and level.
## - enemy_hp_bar: ProgressBar, foe HP from 0 to 100.
## - enemy_hp_label: Label, foe HP as "hp / max_hp".
## - player_name_label: Label, player name and level.
## - player_hp_bar: ProgressBar, player HP from 0 to 100.
## - player_exp_bar: ProgressBar, EXP from 0 to 100.
## - player_hp_label: Label, player HP as "hp / max_hp".
## - log_label: RichTextLabel, the battle log lines.
## - move_buttons: 4 Buttons in a row, one per move.
## - bag_button, party_button, run_button: Buttons in a row.
##
## What the Battle scene must provide: a Control root with this
## script attached. That is all. The scene does not need to make any
## of the child nodes above; _ready() makes them.
##
## The HUD only reads plain dictionaries (name, hp, max_hp, level,
## exp_fraction, move name, pp, max_pp). It never reaches into
## BattleController private state. bind_battle() only keeps the
## controller reference for the scene to use later.

signal move_selected(move_index: int)
signal bag_pressed
signal party_pressed
signal run_pressed
signal move_forget_choice(choice_index: int)

const MAX_LOG_LINES: int = 50

var player_hp: int = 0
var player_max_hp: int = 0
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var exp_fraction: float = 0.0
var log_lines: Array = []
var current_moves: Array = []

var player_name: String = ""
var player_level: int = 0
var enemy_name: String = ""
var enemy_level: int = 0
var battle_controller: Node = null

var enemy_sprite: TextureRect = null
var player_sprite: TextureRect = null
var enemy_name_label: Label = null
var enemy_hp_bar: ProgressBar = null
var enemy_hp_label: Label = null
var player_name_label: Label = null
var player_hp_bar: ProgressBar = null
var player_exp_bar: ProgressBar = null
var player_hp_label: Label = null
var log_label: RichTextLabel = null
var move_buttons: Array = []
var bag_button: Button = null
var party_button: Button = null
var run_button: Button = null


func _ready() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layout)

	enemy_sprite = TextureRect.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.custom_minimum_size = Vector2(96, 96)
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(enemy_sprite)

	enemy_name_label = Label.new()
	enemy_name_label.name = "EnemyNameLabel"
	layout.add_child(enemy_name_label)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.name = "EnemyHPBar"
	enemy_hp_bar.min_value = 0.0
	enemy_hp_bar.max_value = 100.0
	enemy_hp_bar.value = 0.0
	enemy_hp_bar.show_percentage = false
	layout.add_child(enemy_hp_bar)

	enemy_hp_label = Label.new()
	enemy_hp_label.name = "EnemyHPLabel"
	layout.add_child(enemy_hp_label)

	player_sprite = TextureRect.new()
	player_sprite.name = "PlayerSprite"
	player_sprite.custom_minimum_size = Vector2(96, 96)
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(player_sprite)

	player_name_label = Label.new()
	player_name_label.name = "PlayerNameLabel"
	layout.add_child(player_name_label)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.name = "PlayerHPBar"
	player_hp_bar.min_value = 0.0
	player_hp_bar.max_value = 100.0
	player_hp_bar.value = 0.0
	player_hp_bar.show_percentage = false
	layout.add_child(player_hp_bar)

	player_exp_bar = ProgressBar.new()
	player_exp_bar.name = "PlayerEXPBar"
	player_exp_bar.min_value = 0.0
	player_exp_bar.max_value = 100.0
	player_exp_bar.value = 0.0
	player_exp_bar.show_percentage = false
	layout.add_child(player_exp_bar)

	player_hp_label = Label.new()
	player_hp_label.name = "PlayerHPLabel"
	layout.add_child(player_hp_label)

	log_label = RichTextLabel.new()
	log_label.name = "LogLabel"
	log_label.custom_minimum_size = Vector2(0, 120)
	log_label.bbcode_enabled = false
	log_label.scroll_following = true
	layout.add_child(log_label)

	var move_row: HBoxContainer = HBoxContainer.new()
	move_row.name = "MoveRow"
	layout.add_child(move_row)
	move_buttons = []
	for i in range(4):
		var move_button: Button = Button.new()
		move_button.name = "MoveButton" + str(i)
		move_button.text = "Move " + str(i + 1)
		move_button.pressed.connect(_on_move_button_pressed.bind(i))
		move_row.add_child(move_button)
		move_buttons.append(move_button)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "ActionRow"
	layout.add_child(action_row)

	bag_button = Button.new()
	bag_button.name = "BagButton"
	bag_button.text = "Bag"
	bag_button.pressed.connect(_on_bag_button_pressed)
	action_row.add_child(bag_button)

	party_button = Button.new()
	party_button.name = "PartyButton"
	party_button.text = "Party"
	party_button.pressed.connect(_on_party_button_pressed)
	action_row.add_child(party_button)

	run_button = Button.new()
	run_button.name = "RunButton"
	run_button.text = "Run"
	run_button.pressed.connect(_on_run_button_pressed)
	action_row.add_child(run_button)

	_refresh_labels()
	update_bars()
	_refresh_move_buttons()
	_refresh_log_label()


## Keep the controller reference. Typed as Node so the HUD does not
## depend on BattleController internals.
func bind_battle(controller: Node) -> void:
	battle_controller = controller


## Set the player's Pokemon from a dict with "name", "hp",
## "max_hp", "level", and "exp_fraction" (default 0.0).
func set_player(mon: Dictionary) -> void:
	player_name = str(mon.get("name", ""))
	player_hp = int(mon.get("hp", 0))
	player_max_hp = int(mon.get("max_hp", 0))
	player_level = int(mon.get("level", 0))
	exp_fraction = clampf(float(mon.get("exp_fraction", 0.0)), 0.0, 1.0)
	_refresh_labels()
	update_bars()


## Set the foe's Pokemon from a dict with "name", "hp", "max_hp",
## and "level".
func set_enemy(mon: Dictionary) -> void:
	enemy_name = str(mon.get("name", ""))
	enemy_hp = int(mon.get("hp", 0))
	enemy_max_hp = int(mon.get("max_hp", 0))
	enemy_level = int(mon.get("level", 0))
	_refresh_labels()
	update_bars()


## Store the 4 move dicts (each with at least "name", "pp",
## "max_pp") and refresh the move buttons.
func set_moves(moves: Array) -> void:
	current_moves = moves.duplicate()
	_refresh_move_buttons()


## Add one line to the battle log. Keeps at most 50 lines and drops
## the oldest lines first.
func log_line(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)
	_refresh_log_label()


## HP fill color for a fraction of HP left: green above half,
## yellow above a fifth, red at a fifth or less — the same BW2
## thresholds the v6 scene polish uses (fold-in round P3).
static func _hp_fill_color(frac: float) -> Color:
	if frac > 0.5:
		return Color(0.24, 0.72, 0.30)
	if frac > 0.2:
		return Color(0.92, 0.72, 0.20)
	return Color(0.88, 0.24, 0.18)


static func _fill_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


## Recompute the HP and EXP bars from the current numbers. Safe to
## call when max HP is 0 (no division by zero).
func update_bars() -> void:
	if player_hp_bar != null:
		player_hp_bar.value = hp_fraction(true) * 100.0
		player_hp_bar.add_theme_stylebox_override("fill", _fill_box(_hp_fill_color(hp_fraction(true))))
	if enemy_hp_bar != null:
		enemy_hp_bar.value = hp_fraction(false) * 100.0
		enemy_hp_bar.add_theme_stylebox_override("fill", _fill_box(_hp_fill_color(hp_fraction(false))))
	if player_exp_bar != null:
		player_exp_bar.value = clampf(exp_fraction, 0.0, 1.0) * 100.0
		player_exp_bar.add_theme_stylebox_override("fill", _fill_box(Color(0.25, 0.60, 0.95)))


## Current HP divided by max HP, clamped from 0 to 1. Returns 0.0
## when max HP is 0.
func hp_fraction(is_player: bool) -> float:
	if is_player:
		if player_max_hp <= 0:
			return 0.0
		return clampf(float(player_hp) / float(player_max_hp), 0.0, 1.0)
	if enemy_max_hp <= 0:
		return 0.0
	return clampf(float(enemy_hp) / float(enemy_max_hp), 0.0, 1.0)


## The player picked a move to forget (used when a Pokemon with 4
## moves learns a new one). Emits move_forget_choice.
func select_forget_choice(choice_index: int) -> void:
	emit_signal("move_forget_choice", choice_index)


func _refresh_labels() -> void:
	if player_name_label != null:
		player_name_label.text = _mon_label(player_name, player_level)
	if enemy_name_label != null:
		enemy_name_label.text = _mon_label(enemy_name, enemy_level)
	if player_hp_label != null:
		player_hp_label.text = str(player_hp) + " / " + str(player_max_hp)
	if enemy_hp_label != null:
		enemy_hp_label.text = str(enemy_hp) + " / " + str(enemy_max_hp)


func _mon_label(mon_name: String, level: int) -> String:
	if mon_name == "":
		return ""
	if level > 0:
		return mon_name + "  Lv" + str(level)
	return mon_name


func _refresh_move_buttons() -> void:
	for i in range(move_buttons.size()):
		var button: Button = move_buttons[i]
		if i < current_moves.size() and current_moves[i] is Dictionary:
			var move: Dictionary = current_moves[i]
			var move_name: String = str(move.get("name", ""))
			var pp: int = int(move.get("pp", 0))
			var max_pp: int = int(move.get("max_pp", 0))
			if move_name == "":
				button.text = "Move " + str(i + 1)
			elif max_pp > 0:
				button.text = move_name + " " + str(pp) + "/" + str(max_pp)
			else:
				button.text = move_name
		else:
			button.text = "Move " + str(i + 1)


func _refresh_log_label() -> void:
	if log_label == null:
		return
	log_label.text = "\n".join(log_lines)


func _on_move_button_pressed(move_index: int) -> void:
	emit_signal("move_selected", move_index)


func _on_bag_button_pressed() -> void:
	emit_signal("bag_pressed")


func _on_party_button_pressed() -> void:
	emit_signal("party_pressed")


func _on_run_button_pressed() -> void:
	emit_signal("run_pressed")
