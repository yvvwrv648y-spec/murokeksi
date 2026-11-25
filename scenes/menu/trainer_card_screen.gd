class_name PUWTrainerCardScreen
extends Control
## Trainer card (ui_screens production).
##
## No trainer card existed anywhere in the bound tree — no
## class, no screen, no data view. This screen renders the
## save state's own trainer facts in the BW2 stack idiom:
##
##   Name     state["player"]["name"]
##   Money    state["money"]
##   Badges   state["badges"] (count + each badge's own name/id)
##   Pokédex  sizes of state["dex_seen"] / state["dex_caught"]
##   Region   state["region_id"], when the state carries one
##   Play time state["play_time_seconds"], ONLY when present
##
## NO INVENTED DATA: the current save schema records no play
## time anywhere (verified against PUWSaveManager.build_state),
## so the Play Time row is OMITTED unless the state actually
## carries play_time_seconds — it is never filled with a
## plausible-looking value. The same rule applies to every row:
## a field with no state source is omitted, not faked. The
## X-menu header's old demo clock ("12:47") is exactly the
## failure this rule exists to prevent; the live-bag prep's
## bind_state already erases it there.

signal close_requested

var _state: Dictionary = {}
var _built: bool = false

var _back_button: Button = null
var _rows_box: VBoxContainer = null
var _row_labels: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()
	refresh()


func bind_state(state: Dictionary) -> void:
	_state = state
	refresh()


## The rows the card will show for the bound state, as an
## ordered list of {"key", "label", "value"} — the single
## source both the render and the tests read. A key appears
## only when its state source exists.
func card_rows() -> Array:
	var rows: Array = []
	var player_value: Variant = _state.get("player", {})
	if player_value is Dictionary:
		var player: Dictionary = player_value
		var player_name: String = str(player.get("name", ""))
		if player_name != "":
			rows.append({"key": "name", "label": "Name", "value": player_name})
	if _state.has("money"):
		rows.append({"key": "money", "label": "Money", "value": PUWUiTheme.format_money(int(_state.get("money", 0)))})
	var badges_value: Variant = _state.get("badges", [])
	if badges_value is Array:
		var badges: Array = badges_value
		rows.append({"key": "badges", "label": "Badges", "value": str(badges.size())})
		for badge_value in badges:
			rows.append({"key": "badge", "label": "  ·", "value": _badge_text(badge_value)})
	var seen_value: Variant = _state.get("dex_seen", [])
	var caught_value: Variant = _state.get("dex_caught", [])
	if seen_value is Array or caught_value is Array:
		var seen_count: int = (seen_value as Array).size() if seen_value is Array else 0
		var caught_count: int = (caught_value as Array).size() if caught_value is Array else 0
		rows.append({"key": "dex", "label": "Pokédex", "value": "Seen " + str(seen_count) + "  ·  Caught " + str(caught_count)})
	var region_id: String = str(_state.get("region_id", ""))
	if region_id != "":
		rows.append({"key": "region", "label": "Region", "value": region_id})
	var play_seconds: int = play_time_seconds()
	if play_seconds >= 0:
		rows.append({"key": "play_time", "label": "Play Time", "value": format_play_time(play_seconds)})
	return rows


## Play time in seconds from the state, or -1 when the state
## records none. Sources, in order: state["play_time_seconds"],
## state["player"]["play_time_seconds"].
func play_time_seconds() -> int:
	if _state.has("play_time_seconds"):
		return int(_state.get("play_time_seconds", 0))
	var player_value: Variant = _state.get("player", {})
	if player_value is Dictionary:
		var player: Dictionary = player_value
		if player.has("play_time_seconds"):
			return int(player.get("play_time_seconds", 0))
	return -1


func has_play_time_row() -> bool:
	return play_time_seconds() >= 0


## "H:MM" — hours unpadded, minutes zero-padded (3661 -> "1:01").
static func format_play_time(total_seconds: int) -> String:
	var safe: int = maxi(0, total_seconds)
	var hours: int = safe / 3600
	var minutes: int = (safe % 3600) / 60
	return str(hours) + ":" + ("%02d" % minutes)


func _badge_text(badge_value: Variant) -> String:
	if badge_value is Dictionary:
		var badge: Dictionary = badge_value
		var badge_name: String = str(badge.get("name", ""))
		if badge_name != "":
			return badge_name
		return str(badge.get("id", "Badge"))
	return str(badge_value)


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
	header.add_child(PUWUiTheme.make_label("TRAINER CARD", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	panel.add_child(_rows_box)

	var close_button: Button = PUWUiTheme.make_button("Close", Vector2(180, 56))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	root.add_child(close_button)


func refresh() -> void:
	if not _built:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	_row_labels.clear()
	var rows: Array = card_rows()
	if rows.is_empty():
		var empty_label: Label = PUWUiTheme.make_label("No trainer data yet.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM)
		_rows_box.add_child(empty_label)
		return
	for row_value in rows:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 16)
			var label: Label = PUWUiTheme.make_label(str(row.get("label", "")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM, true)
			label.custom_minimum_size = Vector2(180, 0)
			line.add_child(label)
			var value_label: Label = PUWUiTheme.make_label(str(row.get("value", "")), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT)
			line.add_child(value_label)
			_rows_box.add_child(line)
			_row_labels[str(row.get("key", ""))] = value_label


func get_initial_focus_control() -> Control:
	return _back_button
