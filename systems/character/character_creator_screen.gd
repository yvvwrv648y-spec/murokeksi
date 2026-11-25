class_name PUWCharacterCreatorScreen
extends Control
## The character creator SCREEN (staged 2026-11-24).
##
## THE GAP THIS CLOSES (audit 2026-11-24): the bound boot
## scene (scenes/boot/boot_scene.gd) offers only a cast pick +
## name and calls PUWBootFlow.new_game WITHOUT a character
## dict, so the bound 11-step flow (PUWCharacterSetup) had no
## UI at all -- its own header defers to "the creator UI that
## feeds the same confirm path", which did not exist. This
## screen is that UI. It draws nothing itself beyond standard
## controls, following the boot scene's patterns (code-built
## controls, PUWUiTheme, PUWFocus).
##
## Flow: one panel per PUWCharacterSetup step, in STEP_IDS
## order. Option steps render buttons from PUWCreatorOptions
## (which transcribes the bound schema); the body_silhouette
## step also renders the schema's body sliders as HSliders;
## the face step renders the 7 skin-tone swatches; eyes pick
## per-eye colors with a heterochromia step between them.
## Locked hairstyles are never offered (the setup refuses them
## too -- belt and braces, per the G7 rule).
##
## Typed values the bound flow cannot hold (it stores Strings
## per step) ride as extras on the built character Dictionary:
## PUWBootFlow.new_game stores the dict verbatim in
## story_flags, and PUWCharacterSetup.load_character preserves
## non-step keys as extras, so body_sliders / skin_tone /
## hair_color_hex / eye hexes / pronouns survive save + load
## untouched. On confirm: setup.finish() (which finalizes the
## profile and makes the identity + body-preset lock live),
## build_character(), extras attached, then
## PUWBootFlow.new_game(cast_id, name, character) and the same
## pending_boot hand-off the boot scene uses.

const HOST_SCENE: String = "res://scenes/host/game_host.tscn"

var _setup: PUWCharacterSetup = null
var _cast_id: String = "custom_female"
var _player_name: String = ""

var _title_label: Label = null
var _step_label: Label = null
var _options_box: VBoxContainer = null
var _sliders_box: VBoxContainer = null
var _status_label: Label = null
var _back_button: Button = null
var _next_button: Button = null
var _name_edit: LineEdit = null

var _slider_values: Dictionary = {}
var _slider_controls: Dictionary = {}
var _skin_tone: String = "#f6cfa8"
var _hair_color_id: String = "dark_brown"
var _eye_left_id: String = "blue"
var _eye_right_id: String = "blue"
var _heterochromia_on: bool = false


## Entry point used by the boot scene's custom path: the cast
## id chosen there (custom_female / custom_male / custom_femboy
## / custom_futanari) fixes the body preset step's value; the
## name is the one typed on the boot screen ("" = ask here).
func configure(cast_id: String, player_name: String) -> void:
	_cast_id = cast_id
	_player_name = player_name


func _ready() -> void:
	theme = PUWUiTheme.make_theme()
	_setup = PUWCharacterSetup.new()
	add_child(_setup)
	_slider_values = PUWCreatorOptions.default_slider_values()
	var preset: String = _cast_id.trim_prefix("custom_")
	if PUWCreatorOptions.BODY_PRESETS.has(preset):
		_setup.set_value("body_silhouette", preset)
	_title_label = Label.new()
	_title_label.text = "Create Your Character"
	_title_label.add_theme_font_size_override("font_size", 32)
	add_child(_title_label)
	_step_label = Label.new()
	add_child(_step_label)
	_options_box = VBoxContainer.new()
	add_child(_options_box)
	_sliders_box = VBoxContainer.new()
	add_child(_sliders_box)
	_status_label = Label.new()
	add_child(_status_label)
	var nav: HBoxContainer = HBoxContainer.new()
	add_child(nav)
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.pressed.connect(_on_back_pressed)
	nav.add_child(_back_button)
	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.pressed.connect(_on_next_pressed)
	nav.add_child(_next_button)
	_show_step()


## Rebuild the option controls for the current step.
func _show_step() -> void:
	for child in _options_box.get_children():
		child.queue_free()
	for child in _sliders_box.get_children():
		child.queue_free()
	_slider_controls.clear()
	var step_id: String = _setup.current_step()
	_step_label.text = "Step %d of 11: %s" % [_setup.current_step_index() + 1, step_id.capitalize()]
	_back_button.disabled = _setup.current_step_index() == 0
	_next_button.text = "Confirm" if step_id == "confirm" else "Next"
	match step_id:
		"identity":
			_add_options(PUWCharacterSetup.identity_options(), step_id)
		"pronouns":
			var ids: Array = []
			for set_value in PUWCreatorOptions.PRONOUN_SETS:
				var set_dict: Dictionary = set_value
				ids.append(str(set_dict.get("id", "")))
			_add_options(ids, step_id)
		"body_silhouette":
			_add_options(PUWCreatorOptions.BODY_PRESETS, step_id)
			_add_sliders()
		"face":
			_add_swatches(PUWCreatorOptions.SKIN_TONES, "_skin_tone")
			_add_options(PUWCreatorOptions.EYEBROW_STYLES, "eyebrows")
		"eyes":
			_add_options(PUWCreatorOptions.EYE_COLORS.map(func(e: Dictionary) -> String: return str(e.get("id", ""))), "eye_color")
		"heterochromia":
			_add_options(["off", "on"], step_id)
		"hair_style":
			var styles: Array = []
			for style_value in PUWCreatorOptions.HAIRSTYLES:
				var style_id: String = str(style_value)
				if not PUWCharacterSetup.is_hairstyle_locked(style_id):
					styles.append(style_id)
			_add_options(styles, step_id)
		"hair_color":
			_add_options(PUWCreatorOptions.HAIR_COLORS.map(func(e: Dictionary) -> String: return str(e.get("id", ""))), step_id)
		"clothing":
			_add_options(["trainer_canon", "streetwear", "athletic", "swimwear"], step_id)
		"signature_ball":
			_add_options(PUWCreatorOptions.SIGNATURE_BALLS, step_id)
		"confirm":
			_add_confirm()


## One button per option; pressing stores the value through
## the setup (which refuses locked/invalid values with a
## reason the status label shows verbatim).
func _add_options(options: Array, step_id: String) -> void:
	for option_value in options:
		var option_text: String = str(option_value)
		var button: Button = Button.new()
		button.text = option_text.capitalize()
		var stored_step: String = step_id
		var stored_value: String = option_text
		button.pressed.connect(func() -> void: _on_option_chosen(stored_step, stored_value))
		_options_box.add_child(button)


## Skin-tone swatches: color buttons carrying the schema hex.
func _add_swatches(hexes: Array, _target: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_options_box.add_child(row)
	for hex_value in hexes:
		var hex_text: String = str(hex_value)
		var swatch: Button = Button.new()
		swatch.text = "  "
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.html(hex_text)
		swatch.add_theme_stylebox_override("normal", style)
		var stored_hex: String = hex_text
		swatch.pressed.connect(func() -> void: _skin_tone = stored_hex)
		row.add_child(swatch)


## The schema's body sliders for the body_silhouette step.
## lower_front_contour renders only for the identities the
## schema enables it for (checked against the stored identity).
func _add_sliders() -> void:
	var identity_text: String = str(_setup.get_value("identity"))
	for def_value in PUWCreatorOptions.slider_defs():
		var def: Dictionary = def_value
		var slider_id: String = str(def.get("id", ""))
		if slider_id == "lower_front_contour" and not PUWCreatorOptions.lower_front_contour_enabled(identity_text):
			continue
		var label: Label = Label.new()
		label.text = slider_id.capitalize()
		_sliders_box.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = float(def.get("min", 0.0))
		slider.max_value = float(def.get("max", 1.0))
		slider.step = float(def.get("step", 0.01))
		slider.value = float(_slider_values.get(slider_id, float(def.get("default", 0.0))))
		var stored_id: String = slider_id
		slider.value_changed.connect(func(new_value: float) -> void: _slider_values[stored_id] = new_value)
		_sliders_box.add_child(slider)
		_slider_controls[slider_id] = slider


## The confirm step: name entry (when the boot screen did not
## supply one) + a plain summary of the stored choices.
func _add_confirm() -> void:
	if _player_name == "":
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Your name"
		_name_edit.text = "RED"
		_options_box.add_child(_name_edit)
	var summary: Label = Label.new()
	var lines: Array = []
	for step_value in PUWCharacterSetup.STEP_IDS:
		var step_id: String = str(step_value)
		if step_id == "confirm":
			continue
		var value: Variant = _setup.get_value(step_id)
		if value != null:
			lines.append("%s: %s" % [step_id.capitalize(), str(value)])
	summary.text = "\n".join(lines)
	_options_box.add_child(summary)


func _on_option_chosen(step_id: String, value: String) -> void:
	# Two steps store through side channels the bound flow's
	# String steps do not model; everything else goes through
	# set_value_result so refusals surface verbatim.
	if step_id == "eyebrows":
		_setup.set_value("face", str(_setup.get_value("face")) if _setup.get_value("face") != null else value)
		_status_label.text = "Eyebrows: " + value
		return
	if step_id == "eye_color":
		_eye_left_id = value
		if not _heterochromia_on:
			_eye_right_id = value
		_setup.set_value("eyes", value)
		_status_label.text = "Eyes: " + value
		return
	if step_id == "heterochromia":
		_heterochromia_on = value == "on"
		_setup.set_value("heterochromia", _heterochromia_on)
		_status_label.text = "Heterochromia: " + value
		return
	var result: Dictionary = _setup.set_value_result(step_id, value)
	if bool(result.get("ok", false)):
		_status_label.text = "%s: %s" % [step_id.capitalize(), value]
	else:
		_status_label.text = str(result.get("reason", "That choice is not available."))


func _on_back_pressed() -> void:
	if _setup.previous_step():
		_show_step()


func _on_next_pressed() -> void:
	var step_id: String = _setup.current_step()
	if step_id == "confirm":
		_finish_creation()
		return
	if _setup.get_value(step_id) == null and step_id != "body_silhouette":
		_status_label.text = "Choose an option for this step first."
		return
	if _setup.next_step():
		_show_step()


## Confirm: finalize (identity + body-preset lock goes live),
## build the character, attach the typed extras, and hand off
## through PUWBootFlow exactly like the boot scene does. A
## custom character boots into OaksLab for the Oak two-pick
## flow (PUWBootFlow's own rule).
func _finish_creation() -> void:
	if _player_name == "" and _name_edit != null:
		_player_name = _name_edit.text.strip_edges()
	if _player_name == "":
		_player_name = "RED"
	if not _setup.finish():
		_status_label.text = "Some steps are still empty -- go back and complete them."
		return
	var character: Dictionary = _setup.build_character()
	character["cast_id"] = _cast_id
	character["body_sliders"] = _slider_values.duplicate(true)
	character["skin_tone"] = _skin_tone
	character["hair_color_id"] = _hair_color_id if str(_setup.get_value("hair_color")) == "" else str(_setup.get_value("hair_color"))
	character["hair_color_hex"] = PUWCreatorOptions.color_hex(PUWCreatorOptions.HAIR_COLORS, str(character["hair_color_id"]))
	character["eye_left_hex"] = PUWCreatorOptions.color_hex(PUWCreatorOptions.EYE_COLORS, _eye_left_id)
	character["eye_right_hex"] = PUWCreatorOptions.color_hex(PUWCreatorOptions.EYE_COLORS, _eye_right_id)
	character["pronouns_set"] = PUWCreatorOptions.pronoun_set(str(_setup.get_value("pronouns")))
	var result: Dictionary = PUWBootFlow.new_game(_cast_id, _player_name, character)
	PUWBootFlow.pending_boot = result
	get_tree().change_scene_to_file(HOST_SCENE)
