class_name MoveForgetScreen
extends Control
## Move-Forget prompt for Pokemon Ultimate World.
## Plain words: when a Pokemon levels up and wants to learn a new
## move but already knows 4 moves, this screen asks the player
## which old move to forget, or whether to keep the old moves and
## not learn the new one. It needs no scene file: it builds its
## own buttons when it is shown.
##
## ------------------------------------------------------------------
## HOOK POINT FOR THE BATTLE CONTROLLER (BattleController)
## ------------------------------------------------------------------
## BattleController.grant_exp() calls _give_exp(), which calls
## _check_move_learning() when a Pokemon levels up. That function
## asks LearnsetResolver.get_level_up_moves(species, old_level,
## new_level) for the new moves. Right now, when the Pokemon
## already knows 4 moves, it only writes this log line and the new
## move is lost:
##   "<name> wants to learn <move>, but it already knows 4 moves."
## That is the exact place to hook this screen in. Do NOT change
## battle_controller.gd here; the change belongs in that file, in
## _check_move_learning(), and it should be:
##   1. When moves.size() >= 4 and a new move is learned, stop
##      the level-up flow and open this screen instead of logging
##      the line. For example, make a MoveForgetScreen, add it to
##      the battle scene, and call
##      screen.prompt_replace(moves, move_name), then wait for its
##      "choice_made" signal.
##   2. When the signal fires with choice_index -1, keep the old
##      moves and do not learn the new one.
##   3. When it fires with 0..3, set the Pokemon's moves to
##      MoveForgetScreen.apply_choice(moves, move_name,
##      choice_index) and log "<name> forgot <old move> and
##      learned <new move>!".
##   4. When the Pokemon knows fewer than 4 moves, keep the
##      current behaviour: add the new move straight away, with
##      no screen.
## The battle has to wait for the player's choice before the next
## turn starts, because the move list must be settled first.
## ------------------------------------------------------------------

## Fired when the player picks. -1 means "keep the old moves, do
## not learn the new one". 0..3 means "forget the move in that
## slot and learn the new one".
signal choice_made(choice_index: int)

## The Pokemon's current moves (move names, up to 4).
var current_moves: Array = []
## The new move the Pokemon wants to learn.
var new_move: String = ""
## True when prompt_replace() was called before this screen was
## ready, so _ready() still has to build the buttons.
var _ui_dirty: bool = false

func _ready() -> void:
	if _ui_dirty or not current_moves.is_empty() or new_move != "":
		_build_ui()

## Store the moves and the new move, then build the prompt UI:
## one button for each current move, plus one button to keep the
## old moves and not learn the new one. Works with no scene file.
func prompt_replace(moves: Array, new_move_name: String) -> void:
	current_moves = moves.duplicate()
	new_move = new_move_name
	_ui_dirty = true
	if is_inside_tree():
		_build_ui()

## Build (or rebuild) the buttons. Old buttons are removed first,
## so calling prompt_replace() twice never leaves stale buttons.
func _build_ui() -> void:
	_ui_dirty = false
	for child in get_children():
		child.queue_free()
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "MoveForgetBox"
	add_child(box)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	if new_move == "":
		title.text = "Which move should be forgotten?"
	else:
		title.text = "Forget a move to learn " + new_move + "?"
	box.add_child(title)
	var index: int = 0
	for raw_move in current_moves:
		var move_name: String = str(raw_move)
		var button: Button = Button.new()
		button.name = "ForgetButton" + str(index)
		if new_move == "":
			button.text = "Forget " + move_name
		else:
			button.text = "Forget " + move_name + " and learn " + new_move
		button.pressed.connect(_on_choice_pressed.bind(index))
		box.add_child(button)
		index += 1
	var keep_button: Button = Button.new()
	keep_button.name = "KeepButton"
	if new_move == "":
		keep_button.text = "Do not learn the new move"
	else:
		keep_button.text = "Do not learn " + new_move
	keep_button.pressed.connect(_on_choice_pressed.bind(-1))
	box.add_child(keep_button)

## One button was pressed: tell whoever is listening which choice
## was made. -1 keeps the old moves; 0..3 forgets that slot.
func _on_choice_pressed(choice_index: int) -> void:
	choice_made.emit(choice_index)

## Work out the new move list for a choice, without any UI.
## -1 (or any index outside 0..3, or a slot that does not exist)
## returns the current moves unchanged. 0..3 replaces that slot
## with the new move and returns the new move list.
static func apply_choice(current_moves: Array, new_move: String, choice_index: int) -> Array:
	var result: Array = current_moves.duplicate()
	if choice_index < 0 or choice_index > 3:
		return result
	if choice_index >= result.size():
		return result
	result[choice_index] = new_move
	return result
