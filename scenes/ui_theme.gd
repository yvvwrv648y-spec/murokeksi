class_name PUWUiTheme
extends RefCounted
## Shared look for the game's screens, in a Black/White-2
## spirit: near-black panels with a thin light border, clean
## off-white text, one blue accent, and chunky rounded
## buttons. Built in code with Godot Controls only — no art
## assets. Every scene applies it the same way: in _ready,
## set the root Control's theme to make_theme(), and refresh
## HP bars through update_hp_bar so the fill color follows
## the HP fraction (green, then yellow, then red).
##
## v2 (MENU_AUDIT_AND_REBUILD_SPEC §3.0 / §4 step 4): every v1
## constant and helper above is kept verbatim. v2 adds the four
## things the baseline lacked — texture, typography, motion,
## sound: nine-patch frame styleboxes (dark + bright families),
## a bundled font with the spec's size ladder, full control
## coverage (ItemList, TabBar, LineEdit, scrollbars, tooltips),
## selection-row / chip / header styles, an HP-bar tween, and
## the BW2 chip + type color tables. Motion lives in
## PUWMenuTransitions, sound hooks in PUWUiSound.

const INK: Color = Color(0.08, 0.08, 0.10)
const PANEL: Color = Color(0.13, 0.13, 0.17)
const PANEL_LIGHT: Color = Color(0.20, 0.20, 0.26)
const TEXT: Color = Color(0.96, 0.96, 0.94)
const TEXT_DIM: Color = Color(0.72, 0.72, 0.75)
const ACCENT: Color = Color(0.30, 0.55, 0.95)
const BORDER: Color = Color(0.85, 0.85, 0.88)
const HP_GREEN: Color = Color(0.24, 0.72, 0.30)
const HP_YELLOW: Color = Color(0.92, 0.72, 0.20)
const HP_RED: Color = Color(0.88, 0.24, 0.18)
const EXP_BLUE: Color = Color(0.25, 0.60, 0.95)
const BAR_BACK: Color = Color(0.05, 0.05, 0.07)

## v2 additions ------------------------------------------------------------
## Bright window family (dialogue / mart / confirm): the one good
## stylebox in Neon's discarded theme, promoted per spec §3.0.
const WINDOW_BG: Color = Color(0.97, 0.98, 0.98)
const WINDOW_TEXT: Color = Color(0.12, 0.16, 0.22)
const WINDOW_TEXT_DIM: Color = Color(0.38, 0.42, 0.48)
const WINDOW_FRAME: Color = Color(0.08, 0.09, 0.12)

## Type ladder at 1280x720 (§3.0). Nothing below MICRO_SIZE ships.
const TITLE_SIZE: int = 28
const TEXT_SIZE: int = 20
const SECONDARY_SIZE: int = 18
const MICRO_SIZE: int = 16

const DARK_FRAME_PATH: String = "res://art/ui/dark_frame.png"
const BRIGHT_FRAME_PATH: String = "res://art/ui/bright_frame.png"
const CURSOR_PATH: String = "res://art/ui/cursor_triangle.png"

## BW2 X-menu chip colors, one saturated hue per entry (§3.0).
const CHIP_COLORS: Dictionary = {
	"party": Color(0.85, 0.27, 0.24),
	"bag": Color(0.93, 0.55, 0.16),
	"dex": Color(0.27, 0.68, 0.36),
	"map": Color(0.22, 0.50, 0.90),
	"settings": Color(0.52, 0.54, 0.60),
	"save": Color(0.16, 0.64, 0.60),
	"challenge": Color(0.56, 0.36, 0.86),
}

## Move type chip colors (the games' standard type palette).
const TYPE_COLORS: Dictionary = {
	"Normal": Color(0.66, 0.65, 0.48), "Fire": Color(0.93, 0.51, 0.19),
	"Water": Color(0.25, 0.55, 0.94), "Electric": Color(0.97, 0.82, 0.17),
	"Grass": Color(0.48, 0.78, 0.30), "Ice": Color(0.59, 0.85, 0.85),
	"Fighting": Color(0.76, 0.18, 0.16), "Poison": Color(0.64, 0.24, 0.63),
	"Ground": Color(0.89, 0.75, 0.40), "Flying": Color(0.66, 0.57, 0.95),
	"Psychic": Color(0.98, 0.33, 0.55), "Bug": Color(0.66, 0.72, 0.12),
	"Rock": Color(0.72, 0.63, 0.22), "Ghost": Color(0.45, 0.34, 0.63),
	"Dragon": Color(0.44, 0.21, 0.99), "Dark": Color(0.44, 0.35, 0.29),
	"Steel": Color(0.72, 0.72, 0.81), "Fairy": Color(0.93, 0.61, 0.79),
}

static var _tex_cache: Dictionary = {}
static var _font_regular: Font = null
static var _font_bold: Font = null
static var _fonts_tried: bool = false


static func _flat(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_width > 0:
		sb.border_color = border
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_width_top = border_width
		sb.border_width_bottom = border_width
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


## The one Theme every screen shares.
static func make_theme() -> Theme:
	_ensure_fonts()
	var t := Theme.new()
	if _font_regular != null:
		t.default_font = _font_regular
	t.default_font_size = TEXT_SIZE
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "Panel", dark_panel_style())
	t.set_stylebox("panel", "PanelContainer", dark_panel_style())
	t.set_stylebox("normal", "Button", _flat(PANEL_LIGHT, BORDER, 8, 1))
	t.set_stylebox("hover", "Button", _flat(ACCENT.darkened(0.15), BORDER, 8, 1))
	t.set_stylebox("pressed", "Button", _flat(ACCENT.darkened(0.35), BORDER, 8, 1))
	t.set_stylebox("disabled", "Button", _flat(PANEL, TEXT_DIM.darkened(0.3), 8, 1))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), ACCENT, 8, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font_size("font_size", "Button", TEXT_SIZE)
	t.set_color("font_color", "RichTextLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", _flat(BAR_BACK, BORDER, 4, 1))
	t.set_stylebox("fill", "ProgressBar", _flat(HP_GREEN, Color(0, 0, 0, 0), 4, 0))
	# v2 full coverage: lists, tabs, line edits, scrollbars, tooltips.
	t.set_stylebox("panel", "ItemList", _flat(PANEL, BORDER, 8, 1))
	t.set_stylebox("focus", "ItemList", _flat(Color(0, 0, 0, 0), ACCENT, 8, 2))
	t.set_stylebox("selected", "ItemList", row_style(true))
	t.set_stylebox("selected_focus", "ItemList", row_style(true))
	t.set_stylebox("hovered", "ItemList", row_style(false))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("guide_color", "ItemList", Color(1, 1, 1, 0.08))
	t.set_font_size("font_size", "ItemList", TEXT_SIZE)
	t.set_stylebox("tab_selected", "TabBar", _flat(PANEL_LIGHT, ACCENT, 8, 2))
	t.set_stylebox("tab_unselected", "TabBar", _flat(PANEL, BORDER, 8, 1))
	t.set_stylebox("tab_hovered", "TabBar", _flat(PANEL_LIGHT, BORDER, 8, 1))
	t.set_stylebox("tab_disabled", "TabBar", _flat(PANEL, TEXT_DIM.darkened(0.3), 8, 1))
	t.set_color("font_selected_color", "TabBar", TEXT)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_font_size("font_size", "TabBar", SECONDARY_SIZE)
	t.set_stylebox("normal", "LineEdit", _flat(PANEL, BORDER, 6, 1))
	t.set_stylebox("focus", "LineEdit", _flat(PANEL, ACCENT, 6, 2))
	t.set_stylebox("read_only", "LineEdit", _flat(PANEL.darkened(0.2), TEXT_DIM, 6, 1))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", TEXT_SIZE)
	for bar_name in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar_name, _flat(BAR_BACK, Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber", bar_name, _flat(PANEL_LIGHT, Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber_highlight", bar_name, _flat(ACCENT.darkened(0.15), Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber_pressed", bar_name, _flat(ACCENT.darkened(0.35), Color(0, 0, 0, 0), 4, 0))
	t.set_stylebox("panel", "TooltipPanel", _flat(PANEL, BORDER, 6, 1))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", MICRO_SIZE)
	return t


## HP fill color for a fraction of HP left: green above half,
## yellow above a fifth, red at a fifth or less — the BW2
## thresholds (fold-in round P3: the red cut is 20%, not 25%).
static func hp_fill_color(frac: float) -> Color:
	if frac > 0.5:
		return HP_GREEN
	if frac > 0.2:
		return HP_YELLOW
	return HP_RED


## Set a ProgressBar to hp/max_hp with the fill colored by
## the fraction left. Call it wherever a scene refreshes HP.
static func update_hp_bar(bar: ProgressBar, hp: int, max_hp: int) -> void:
	var safe_max: int = maxi(1, max_hp)
	bar.max_value = safe_max
	bar.value = clampi(hp, 0, safe_max)
	var frac: float = float(clampi(hp, 0, safe_max)) / float(safe_max)
	var fill := _flat(hp_fill_color(frac), Color(0, 0, 0, 0), 4, 0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", _flat(BAR_BACK, BORDER, 4, 1))


## Same idea for an EXP bar: fraction in, blue fill.
static func update_exp_bar(bar: ProgressBar, frac: float) -> void:
	bar.max_value = 100
	bar.value = clampf(frac, 0.0, 1.0) * 100.0
	bar.add_theme_stylebox_override("fill", _flat(EXP_BLUE, Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("background", _flat(BAR_BACK, BORDER, 4, 1))


## v2: HP bar with the spec's 0.25 s value tween. The fill color
## snaps to the target fraction's threshold color at tween start
## (the games recolor as the bar drains past a threshold).
static func tween_hp_bar(bar: ProgressBar, hp: int, max_hp: int, owner: Node, duration: float = 0.25) -> Tween:
	var safe_max: int = maxi(1, max_hp)
	bar.max_value = safe_max
	var target: float = float(clampi(hp, 0, safe_max))
	var frac: float = target / float(safe_max)
	bar.add_theme_stylebox_override("fill", _flat(hp_fill_color(frac), Color(0, 0, 0, 0), 4, 0))
	bar.add_theme_stylebox_override("background", _flat(BAR_BACK, BORDER, 4, 1))
	var tween: Tween = owner.create_tween()
	tween.tween_property(bar, "value", target, duration)
	return tween


## --- v2 texture styleboxes -------------------------------------------------

static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	_tex_cache[path] = loaded
	return loaded


static func _frame_style(path: String, fallback_bg: Color) -> StyleBox:
	var texture: Texture2D = tex(path)
	if texture == null:
		return _flat(fallback_bg, BORDER, 8, 2)
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.texture_margin_left = 28.0
	sb.texture_margin_right = 28.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_bottom = 28.0
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	sb.draw_center = true
	return sb


## Dark family frame: pause / party / bag / battle commands.
static func dark_panel_style() -> StyleBox:
	return _frame_style(DARK_FRAME_PATH, PANEL)


## Bright family frame: dialogue window / mart / confirm prompts.
static func bright_panel_style() -> StyleBox:
	return _frame_style(BRIGHT_FRAME_PATH, WINDOW_BG)


## Header strip inside a dark panel: panel-light fill, title sits on it.
static func header_style() -> StyleBoxFlat:
	var sb := _flat(PANEL_LIGHT, Color(0, 0, 0, 0), 6, 0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## Selected row = accent at 30% over panel-light; unselected = a
## whisper of white so rows read as rows (§3.0 selection cursor).
static func row_style(selected: bool) -> StyleBoxFlat:
	if selected:
		return _flat(Color(0.23, 0.31, 0.47), Color(0, 0, 0, 0), 6, 0)
	return _flat(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 6, 0)


## A saturated chip (X-menu entries, type chips, status chips).
static func chip_style(color: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := _flat(color, color.darkened(0.25), radius, 1)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb


## Status chip text + color. "permadeath" is PUW's ledger state and
## reads distinctly from an ordinary in-battle faint (§3.2).
static func status_chip(status: String) -> Dictionary:
	match status:
		"permadeath":
			return {"text": "FAINTED", "color": Color(0.55, 0.10, 0.10)}
		"fainted":
			return {"text": "FAINTED", "color": HP_RED}
		"psn":
			return {"text": "PSN", "color": Color(0.64, 0.24, 0.63)}
		"brn":
			return {"text": "BRN", "color": Color(0.85, 0.35, 0.15)}
		"par":
			return {"text": "PAR", "color": Color(0.80, 0.62, 0.10)}
		"slp":
			return {"text": "SLP", "color": Color(0.45, 0.47, 0.55)}
		"frz":
			return {"text": "FRZ", "color": Color(0.45, 0.70, 0.85)}
	return {}


static func type_color(type_name: String) -> Color:
	if TYPE_COLORS.has(type_name):
		return TYPE_COLORS[type_name] as Color
	return PANEL_LIGHT


static func format_money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	grouped = digits + grouped
	if amount < 0:
		grouped = "-" + grouped
	return "¥" + grouped


## --- v2 fonts ---------------------------------------------------------------

static func _ensure_fonts() -> void:
	if _fonts_tried:
		return
	_fonts_tried = true
	_font_regular = _load_font_file([
		"res://fonts/MPLUSRounded1c-Medium.ttf",
		"res://fonts/NotoSans-Regular.ttf",
	])
	_font_bold = _load_font_file([
		"res://fonts/MPLUSRounded1c-Bold.ttf",
		"res://fonts/NotoSans-Bold.ttf",
	])


static func _load_font_file(paths: Array) -> Font:
	for path_value in paths:
		var path: String = str(path_value)
		if ResourceLoader.exists(path):
			var font_file := FontFile.new()
			if font_file.load_dynamic_font(path) == OK:
				return font_file
	return null


static func font_regular() -> Font:
	_ensure_fonts()
	return _font_regular


static func font_bold() -> Font:
	_ensure_fonts()
	if _font_bold != null:
		return _font_bold
	return _font_regular


## --- v2 control factories (one selection state, spec sizes) -----------------

static func make_label(text: String, size: int = TEXT_SIZE, color: Color = TEXT, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold and font_bold() != null:
		label.add_theme_font_override("font", font_bold())
	return label


static func make_button(text: String, min_size: Vector2 = Vector2(0, 56)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", TEXT_SIZE)
	button.focus_mode = Control.FOCUS_ALL
	return button
