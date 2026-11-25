class_name PUWDialogueBox
extends CanvasLayer
## PUWDialogueBox — the in-game dialogue textbox (dialogue prep).
##
## The bound code had NO dialogue display at all: the spawner
## could resolve lines, but nothing could show them. This box is
## the missing piece: a bottom-anchored panel with a speaker name
## line, a typewriter body label, and a choice list, driven by
## PUWDialogueRunner.
##
## Usage:
##   var box: PUWDialogueBox = PUWDialogueBox.new()
##   add_child(box)
##   box.start_dialogue(spawner.dialogue_for(map_name, ref))
##   # feed player input to box.advance() / box.choose(i)
##
## Styling is deliberately plain (one dark panel, white text);
## adopting the BW2 UI theme is build-6 polish, not a prep
## blocker. The UI is built lazily so the box also works when
## created outside the tree (headless tests).

signal dialogue_finished

const RunnerScript: GDScript = preload("res://systems/dialogue/dialogue_runner.gd")
const CHARS_PER_SECOND: float = 60.0

var _runner: PUWDialogueRunner = null
var _built: bool = false
var _panel: PanelContainer = null
var _name_label: Label = null
var _body_label: Label = null
var _choice_box: VBoxContainer = null
var _hint_label: Label = null
var _revealed: float = 0.0
var _showing: bool = false
var finished_emitted: bool = false


func _ready() -> void:
	_ensure_built()
	visible = false


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.offset_top = -132.0
	_panel.offset_bottom = -16.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.border_color = Color(0.9, 0.9, 0.95, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vbox.add_child(_name_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(0.0, 44.0)
	_body_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(_body_label)

	_choice_box = VBoxContainer.new()
	vbox.add_child(_choice_box)

	_hint_label = Label.new()
	_hint_label.text = "▼"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_hint_label)


## Begin showing a resolved line list (see PUWDialogueRunner for
## the accepted shapes). An empty list finishes immediately.
func start_dialogue(lines: Array) -> void:
	_ensure_built()
	_runner = RunnerScript.new()
	_runner.setup(lines)
	_revealed = 0.0
	finished_emitted = false
	if _runner.is_finished():
		_showing = false
		visible = false
		_finish()
		return
	_showing = true
	visible = true
	_show_current()


func is_showing() -> bool:
	return _showing


## The full text of the line currently on screen ("" when no
## dialogue is active). Test-friendly accessor.
func current_line_text() -> String:
	if _runner == null:
		return ""
	return _runner.current_text()


## The text as currently revealed by the typewriter.
func visible_text() -> String:
	if _body_label == null:
		return ""
	return _body_label.text


func choice_count() -> int:
	if _runner == null:
		return 0
	return _runner.current_choices().size()


## Player confirm: completes the typewriter reveal first, then
## moves to the next line; hides the box at the end.
func advance() -> void:
	if not _showing or _runner == null:
		return
	var full: String = _runner.current_text()
	if int(_revealed) < full.length():
		_revealed = float(full.length())
		_apply_reveal()
		return
	if _runner.advance():
		_revealed = 0.0
		_show_current()
	else:
		_showing = false
		visible = false
		_finish()


## Player picks choice i of the current line.
func choose(i: int) -> void:
	if not _showing or _runner == null:
		return
	if _runner.choose(i):
		_revealed = 0.0
		_show_current()
	else:
		_showing = false
		visible = false
		_finish()


func _process(delta: float) -> void:
	if not _showing or _runner == null:
		return
	var full: String = _runner.current_text()
	if int(_revealed) < full.length():
		_revealed = minf(float(full.length()),
				_revealed + CHARS_PER_SECOND * delta)
		_apply_reveal()


func _show_current() -> void:
	var d: Dictionary = _runner.current()
	_name_label.text = String(d.get("speaker", ""))
	_name_label.visible = _name_label.text != ""
	_revealed = 0.0
	_apply_reveal()
	for child in _choice_box.get_children():
		child.queue_free()
	var choices_v: Variant = d.get("choices", [])
	if choices_v is Array:
		var choices: Array = choices_v
		for i in range(choices.size()):
			var c_v: Variant = choices[i]
			if c_v is Dictionary:
				var c: Dictionary = c_v
				var btn: Button = Button.new()
				btn.text = String(c.get("label", ""))
				btn.pressed.connect(_on_choice_pressed.bind(i))
				_choice_box.add_child(btn)
	_hint_label.visible = choices_v is Array and (choices_v as Array).is_empty()


func _apply_reveal() -> void:
	if _runner == null or _body_label == null:
		return
	var full: String = _runner.current_text()
	_body_label.text = full.substr(0, int(_revealed))


func _on_choice_pressed(i: int) -> void:
	choose(i)


func _finish() -> void:
	if finished_emitted:
		return
	finished_emitted = true
	dialogue_finished.emit()
