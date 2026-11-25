class_name PUWPokedexScreen
extends Control
## Pokédex screen (ui_screens production).
##
## The bound tree's PUWPokedex is logic-only (plus a stub
## DualPokedexController shell); no screen existed. This screen
## renders it in the BW2 stack idiom.
##
## Data honesty:
## - PKDX rows come from PUWPokedex.pokedex_entries(state):
##   the real 1,025-species list with seen/caught read from the
##   save state's own dex_seen / dex_caught lists. An unseen
##   species shows its number and "?????" — its name is not
##   displayed before it is seen, the games' own convention.
## - The detail page shows only what the dex data holds:
##   number, name, status. PUWPokedex carries no height /
##   weight / flavour text, so the page does not invent any.
## - The Cry button appears for seen/caught species and routes
##   through the bound cry hook: a host-bound cry player
##   (bind_cry_player — build 6 binds the audio prep's
##   PokemonCryPlayer) is called with play_cry_for_mon({"species",
##   "dex_id"}), and cry_requested(slug) is emitted either way so
##   the host can route it. No player bound = the press is
##   reported in the message strip, not silently dropped.
## - MDX mode lists PUWPokedex.pokedex_entries_mdx() — the
##   sourced seed register only. The register currently holds
##   ZERO entries (its mapping note says the fan-Moemon species
##   mapping is otherwise empty), so MDX mode honestly shows
##   the register's own note and no rows rather than borrowing
##   PKDX rows.

signal close_requested
signal cry_requested(species_slug: String)

const FAMILY_PKDX: String = "pkdx"
const FAMILY_MDX: String = "mdx"

var _state: Dictionary = {}
var _dex: PUWPokedex = null
var _family: String = FAMILY_PKDX
var _entries: Array = []
var _selected: int = -1
var _cry_player: Node = null
var _built: bool = false

var _back_button: Button = null
var _counts_label: Label = null
var _rows_box: VBoxContainer = null
var _row_buttons: Array[Button] = []
var _detail_name: Label = null
var _detail_meta: Label = null
var _detail_note: Label = null
var _cry_button: Button = null
var _message_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_build()
	refresh()


func bind_state(state: Dictionary) -> void:
	_state = state
	_ensure_dex()
	_reload_entries()
	refresh()


## The cry hook: build 6 binds the audio prep's cry player
## (PokemonCryPlayer, whose play_cry_for_mon(mon) is the bound
## contract — it reads species / dex_id and never "family", so
## PKDX and MDX resolve identically).
func bind_cry_player(player: Node) -> void:
	_cry_player = player


func family() -> String:
	return _family


func entry_count() -> int:
	return _entries.size()


func set_family(family_id: String) -> void:
	if family_id != FAMILY_PKDX and family_id != FAMILY_MDX:
		return
	_family = family_id
	_ensure_dex()
	_reload_entries()
	refresh()


func _ensure_dex() -> void:
	if _dex == null:
		_dex = PUWPokedex.new()


func _reload_entries() -> void:
	_selected = -1
	if _dex == null:
		_entries = []
		return
	if _family == FAMILY_MDX:
		_entries = _dex.pokedex_entries_mdx()
	else:
		_entries = _dex.pokedex_entries(_state)


## Seen / caught totals over the current PKDX entries
## ({"seen": int, "caught": int}); MDX has no seen/caught state
## in PUWPokedex, so both stay 0 there.
func counts() -> Dictionary:
	var seen: int = 0
	var caught: int = 0
	if _family == FAMILY_PKDX:
		for entry_value in _entries:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var status: String = str(entry.get("status", "unseen"))
				if status == "caught":
					caught += 1
					seen += 1
				elif status == "seen":
					seen += 1
	return {"seen": seen, "caught": caught}


func select_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_selected = index
	_refresh_detail()


func selected_entry() -> Dictionary:
	if _selected < 0 or _selected >= _entries.size():
		return {}
	var entry_value: Variant = _entries[_selected]
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		return entry
	return {}


## Press the Cry button for the selected species.
func press_cry() -> void:
	var entry: Dictionary = selected_entry()
	if entry.is_empty():
		return
	if _family != FAMILY_PKDX:
		return
	var status: String = str(entry.get("status", "unseen"))
	if status == "unseen":
		return
	var slug: String = str(entry.get("slug", ""))
	cry_requested.emit(slug)
	if _cry_player != null and _cry_player.has_method("play_cry_for_mon"):
		_cry_player.call("play_cry_for_mon", {"species": slug, "dex_id": int(entry.get("id", 0))})
		PUWUiSound.play("ui_confirm")
	else:
		_set_message("No cry player is bound yet.")


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
	header.add_child(PUWUiTheme.make_label("POKÉDEX", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var pkdx_button: Button = PUWUiTheme.make_button("Pokémon", Vector2(150, 56))
	pkdx_button.pressed.connect(func() -> void: set_family(FAMILY_PKDX))
	header.add_child(pkdx_button)
	var mdx_button: Button = PUWUiTheme.make_button("Moemon", Vector2(150, 56))
	mdx_button.pressed.connect(func() -> void: set_family(FAMILY_MDX))
	header.add_child(mdx_button)
	_counts_label = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	header.add_child(_counts_label)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	# Detail pane.
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail.add_child(detail_box)
	_detail_name = PUWUiTheme.make_label("Choose a Pokémon.", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true)
	detail_box.add_child(_detail_name)
	_detail_meta = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM)
	detail_box.add_child(_detail_meta)
	_detail_note = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_note)
	_cry_button = PUWUiTheme.make_button("Play Cry", Vector2(180, 56))
	_cry_button.pressed.connect(func() -> void: press_cry())
	_cry_button.disabled = true
	detail_box.add_child(_cry_button)

	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 68)
	strip.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	root.add_child(strip)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	strip.add_child(_message_label)


func refresh() -> void:
	if not _built:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	_row_buttons.clear()
	if _family == FAMILY_PKDX:
		var totals: Dictionary = counts()
		_counts_label.text = "Seen: " + str(int(totals.get("seen", 0))) + "   Caught: " + str(int(totals.get("caught", 0)))
	else:
		_counts_label.text = "Registered: " + str(_entries.size())
	for i in _entries.size():
		var entry_index: int = i
		var entry_value: Variant = _entries[i]
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		var row: Button = PUWUiTheme.make_button(_row_text(entry), Vector2(0, 52))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(func() -> void: select_entry(entry_index))
		row.focus_entered.connect(func() -> void: PUWUiSound.play("ui_cursor"))
		_rows_box.add_child(row)
		_row_buttons.append(row)
	if _entries.is_empty():
		var empty_row: Button = PUWUiTheme.make_button("No entries.", Vector2(0, 52))
		empty_row.disabled = true
		_rows_box.add_child(empty_row)
		_row_buttons.append(empty_row)
	_refresh_detail()


func _row_text(entry: Dictionary) -> String:
	if _family == FAMILY_MDX:
		return str(entry.get("name", entry.get("slug", "Moemon")))
	var species_id: int = int(entry.get("id", 0))
	var status: String = str(entry.get("status", "unseen"))
	var number_text: String = "#%03d" % species_id
	if status == "unseen":
		return number_text + "  ?????"
	var name_text: String = str(entry.get("name", "")).capitalize()
	if status == "caught":
		return number_text + "  " + name_text + "  ·  Caught"
	return number_text + "  " + name_text + "  ·  Seen"


func _refresh_detail() -> void:
	if not _built:
		return
	var entry: Dictionary = selected_entry()
	if entry.is_empty():
		if _family == FAMILY_MDX and _dex != null:
			_detail_name.text = "Moemon Dex"
			_detail_meta.text = ""
			_detail_note.text = _dex.mdx_mapping_note()
		else:
			_detail_name.text = "Choose a Pokémon."
			_detail_meta.text = ""
			_detail_note.text = ""
		_cry_button.disabled = true
		return
	if _family == FAMILY_MDX:
		_detail_name.text = str(entry.get("name", entry.get("slug", "Moemon")))
		_detail_meta.text = ""
		_detail_note.text = ""
		_cry_button.disabled = true
		return
	var status: String = str(entry.get("status", "unseen"))
	_detail_meta.text = "#%03d" % int(entry.get("id", 0))
	if status == "unseen":
		_detail_name.text = "?????"
		_detail_note.text = "Not yet seen."
		_cry_button.disabled = true
	else:
		_detail_name.text = str(entry.get("name", "")).capitalize()
		_detail_note.text = "Caught." if status == "caught" else "Seen."
		_cry_button.disabled = false


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func message_text() -> String:
	if _message_label == null:
		return ""
	return _message_label.text


func get_initial_focus_control() -> Control:
	if not _row_buttons.is_empty():
		return _row_buttons[0]
	return _back_button
