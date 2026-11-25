class_name PUWQuestBoardScreen
extends Control
## Quest board screen (ui_screens production).
##
## PUWQuestBoard is bound data/logic (the PMD job-board spine);
## live_wiring exposed its state as dictionaries and no screen
## existed. This screen renders ONE settlement's board in the
## BW2 stack idiom:
##
##   bind_board(state, board_id) — the board is the supply
##   placement id (data/supply_placements.json), the same id
##   PUWQuestBoard.register_board used. The header shows the
##   region's real rank (PUWQuestBoard.region_rank over the
##   bound grammar) and the board's stamp card.
##
##   Postings list — PUWQuestBoard.postings(state, region,
##   board): each row shows the posting's own title, task and
##   reward (its data, nothing paraphrased into existence) and
##   an Accept button routed to PUWQuestBoard.accept_job with
##   the caller's world context (bind_context — weather / day /
##   time of day in PUWWorldClock vocabulary; windowed postings
##   refuse honestly through the board's own reason).
##
##   Accepted list — PUWQuestBoard.accepted_jobs(state): real
##   progress (progress/count from the job's task) and status;
##   Turn In (enabled only when the board says the job is
##   "ready") routes to PUWQuestBoard.turn_in, Abandon to
##   abandon_job. Rewards land in the save's real money/bag
##   through the board module itself — the screen never grants
##   anything on its own.
##
## Every outcome (accept / turn-in / abandon / refusal) emits
## quests_changed and shows the board's reason in the message
## strip. Region locks are the board module's own: a board in
## a sealed region lists read-only and its writes refuse with
## "wrong_region", which the strip shows as-is.

signal close_requested
signal quests_changed

const GRAMMAR_PATH: String = "res://data/quest_grammar.json"

const REASON_TEXT: Dictionary = {
	"unknown_board": "This board is not registered.",
	"wrong_region": "This board is in a sealed region.",
	"already_accepted": "That job is already accepted.",
	"accepted_full": "You can't accept more jobs in this region.",
	"not_posted": "That posting is no longer on the board.",
	"window_closed": "That job's window is closed right now.",
	"rank_too_low": "Your rank is too low for that job.",
	"not_accepted": "That job is not accepted.",
	"not_ready": "That job isn't ready to turn in.",
	"duplicate": "That posting is already on the board.",
	"bad_posting": "That posting is missing its board or region.",
}

var _state: Dictionary = {}
var _grammar: Dictionary = {}
var _board_id: String = ""
var _region_id: String = ""
var _context: Dictionary = {}
var _built: bool = false

var _back_button: Button = null
var _rank_label: Label = null
var _postings_box: VBoxContainer = null
var _accepted_box: VBoxContainer = null
var _message_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_load_grammar()
	_build()
	refresh()


func _load_grammar() -> void:
	_grammar = {}
	if not FileAccess.file_exists(GRAMMAR_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GRAMMAR_PATH))
	if parsed is Dictionary:
		var grammar: Dictionary = parsed
		_grammar = grammar


## The world context accept_job checks windows against
## (PUWWorldClock vocabulary: weather, time_of_day, festival,
## world_day). Empty = no context; empty-window postings are
## open, windowed ones refuse through the board's own rule.
func bind_context(context: Dictionary) -> void:
	_context = context.duplicate(true)


func bind_board(state: Dictionary, board_id: String) -> void:
	_state = state
	_board_id = board_id
	_region_id = PUWQuestBoard.board_region(state, board_id)
	refresh()


func board_id() -> String:
	return _board_id


func region_id() -> String:
	return _region_id


func postings() -> Array:
	if _state.is_empty() or _region_id == "":
		return []
	return PUWQuestBoard.postings(_state, _region_id, _board_id)


func posting_count() -> int:
	return postings().size()


func accepted_jobs() -> Array:
	if _state.is_empty():
		return []
	return PUWQuestBoard.accepted_jobs(_state)


func accepted_count() -> int:
	return accepted_jobs().size()


func accept_posting(instance_id: String) -> Dictionary:
	if _state.is_empty():
		return {"ok": false, "reason": "unknown_board"}
	var result: Dictionary = PUWQuestBoard.accept_job(_state, _grammar, _board_id, instance_id, _context)
	_after_write(result, "Job accepted.")
	return result


func turn_in_job(instance_id: String) -> Dictionary:
	if _state.is_empty():
		return {"ok": false, "reason": "not_accepted"}
	var result: Dictionary = PUWQuestBoard.turn_in(_state, _grammar, instance_id)
	_after_write(result, "Job turned in.")
	return result


func abandon_job(instance_id: String) -> bool:
	if _state.is_empty():
		return false
	var done: bool = PUWQuestBoard.abandon_job(_state, instance_id)
	if done:
		_set_message("Job abandoned.")
		PUWUiSound.play("ui_cancel")
		quests_changed.emit()
		refresh()
	else:
		_set_message(_reason_text("not_accepted"))
		PUWUiSound.play("ui_error")
	return done


func _after_write(result: Dictionary, success_message: String) -> void:
	if bool(result.get("ok", false)):
		_set_message(success_message)
		PUWUiSound.play("ui_confirm")
		quests_changed.emit()
	else:
		_set_message(_reason_text(str(result.get("reason", ""))))
		PUWUiSound.play("ui_error")
	refresh()


func _reason_text(reason: String) -> String:
	if REASON_TEXT.has(reason):
		return str(REASON_TEXT[reason])
	return "That can't be done."


func _build() -> void:
	_built = true
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(56, 56)
	_back_button.icon = PUWUiTheme.tex("res://art/ui/back_chevron.png")
	_back_button.expand_icon = true
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(_back_button)
	header.add_child(PUWUiTheme.make_label("QUEST BOARD", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_rank_label = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	header.add_child(_rank_label)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var postings_panel := PanelContainer.new()
	postings_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	postings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(postings_panel)
	var postings_column := VBoxContainer.new()
	postings_column.add_theme_constant_override("separation", 8)
	postings_panel.add_child(postings_column)
	postings_column.add_child(PUWUiTheme.make_label("POSTINGS", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM, true))
	_postings_box = VBoxContainer.new()
	_postings_box.add_theme_constant_override("separation", 8)
	postings_column.add_child(_postings_box)

	var accepted_panel := PanelContainer.new()
	accepted_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	accepted_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(accepted_panel)
	var accepted_column := VBoxContainer.new()
	accepted_column.add_theme_constant_override("separation", 8)
	accepted_panel.add_child(accepted_column)
	accepted_column.add_child(PUWUiTheme.make_label("ACCEPTED", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM, true))
	_accepted_box = VBoxContainer.new()
	_accepted_box.add_theme_constant_override("separation", 8)
	accepted_column.add_child(_accepted_box)

	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	strip.add_child(_message_label)


func refresh() -> void:
	if not _built:
		return
	for child in _postings_box.get_children():
		child.queue_free()
	for child in _accepted_box.get_children():
		child.queue_free()
	if _state.is_empty() or _board_id == "":
		_rank_label.text = ""
		_postings_box.add_child(PUWUiTheme.make_label("No board selected.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM))
		return
	if _region_id == "":
		_rank_label.text = ""
		_postings_box.add_child(PUWUiTheme.make_label("This board is not registered.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM))
		return
	var rank: Dictionary = PUWQuestBoard.region_rank(_state, _grammar, _region_id)
	var board: Dictionary = PUWQuestBoard.board_state(_state, _region_id, _board_id)
	_rank_label.text = str(rank.get("name", "")) + "  ·  " + str(int(rank.get("points", 0))) + " pts  ·  Stamps: " + str(int(board.get("stamps", 0)))
	var posting_list: Array = postings()
	if posting_list.is_empty():
		_postings_box.add_child(PUWUiTheme.make_label("No postings right now.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM))
	for posting_value in posting_list:
		if posting_value is Dictionary:
			var posting: Dictionary = posting_value
			_postings_box.add_child(_make_posting_row(posting))
	var accepted_list: Array = accepted_jobs()
	if accepted_list.is_empty():
		_accepted_box.add_child(PUWUiTheme.make_label("No jobs accepted.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM))
	for job_value in accepted_list:
		if job_value is Dictionary:
			var job: Dictionary = job_value
			_accepted_box.add_child(_make_accepted_row(job))


func _make_posting_row(posting: Dictionary) -> VBoxContainer:
	var instance_id: String = str(posting.get("instance_id", posting.get("id", "")))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title_label: Label = PUWUiTheme.make_label(str(posting.get("title", "Job")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)
	box.add_child(PUWUiTheme.make_label(_task_text(posting) + "   ·   " + _reward_text(posting), PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM))
	var accept_button: Button = PUWUiTheme.make_button("Accept", Vector2(140, 52))
	accept_button.pressed.connect(func() -> void: accept_posting(instance_id))
	accept_button.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
	box.add_child(accept_button)
	return box


func _make_accepted_row(job: Dictionary) -> VBoxContainer:
	var instance_id: String = str(job.get("instance_id", job.get("id", "")))
	var status: String = str(job.get("status", "active"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title_label: Label = PUWUiTheme.make_label(str(job.get("title", "Job")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)
	var task_value: Variant = job.get("task", {})
	var task: Dictionary = task_value if task_value is Dictionary else {}
	var count: int = int(task.get("count", 1))
	box.add_child(PUWUiTheme.make_label("Progress: " + str(int(job.get("progress", 0))) + "/" + str(count) + "  ·  " + status.capitalize(), PUWUiTheme.MICRO_SIZE, PUWUiTheme.TEXT_DIM))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var turn_in_button: Button = PUWUiTheme.make_button("Turn In", Vector2(130, 52))
	turn_in_button.disabled = status != "ready"
	turn_in_button.pressed.connect(func() -> void: turn_in_job(instance_id))
	buttons.add_child(turn_in_button)
	var abandon_button: Button = PUWUiTheme.make_button("Abandon", Vector2(130, 52))
	abandon_button.pressed.connect(func() -> void: abandon_job(instance_id))
	buttons.add_child(abandon_button)
	return box


func _task_text(posting: Dictionary) -> String:
	var task_value: Variant = posting.get("task", {})
	if not (task_value is Dictionary):
		return ""
	var task: Dictionary = task_value
	var text: String = str(task.get("type", "")).capitalize()
	var target: String = str(task.get("target", ""))
	if target != "":
		text += ": " + target
	var count: int = int(task.get("count", 0))
	if count > 0:
		text += " x" + str(count)
	return text


func _reward_text(posting: Dictionary) -> String:
	var reward_value: Variant = posting.get("reward", {})
	if not (reward_value is Dictionary):
		return ""
	var reward: Dictionary = reward_value
	var parts: Array[String] = []
	var money: int = int(reward.get("money", 0))
	if money > 0:
		parts.append(PUWUiTheme.format_money(money))
	var rank_points: int = int(reward.get("rank_points", 0))
	if rank_points > 0:
		parts.append(str(rank_points) + " pts")
	var items_value: Variant = reward.get("items", {})
	if items_value is Dictionary:
		var items: Dictionary = items_value
		for slug_value in items.keys():
			parts.append(str(slug_value) + " x" + str(int(items.get(slug_value, 0))))
	return "Reward: " + ", ".join(parts) if not parts.is_empty() else ""


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func message_text() -> String:
	if _message_label == null:
		return ""
	return _message_label.text


func get_initial_focus_control() -> Control:
	return _back_button
