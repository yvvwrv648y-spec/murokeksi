class_name PUWTouchButton
extends Control
## One on-screen button of the PUW touch layer (interface/touch).
##
## A press does NOT call any game system directly and does NOT
## invent a parallel input path. It reproduces, through
## Input.parse_input_event(), the exact single InputEventKey a
## keyboard produces for the button's primary binding (arrows for
## the d-pad, Enter for A, X for B, Tab for START — the bindings
## project.godot's input map and the tree's own input tests use).
## Event consumers therefore see ONE event per tap, exactly like
## hardware: PUWInputInteraction's predicates, menu_host's menu
## toggle, bw2_menu_stack's raw-key back path (KEY_X) and the GUI
## focus navigation all react as they do to a physical press, and
## the key event also sets the held state of every action bound
## to that key in both the puw_* map and the engine ui_* map
## (Enter is bound to puw_confirm AND ui_accept; the arrows are
## bound to both direction maps).
##
## Two actions have no keyboard binding to mirror, so they are
## held as STATE ONLY via Input.action_press() (which dispatches
## no event, so nothing can double-fire): while B is held,
## ui_cancel is held for state pollers (the X key event already
## covers every event consumer) and puw_run is held — joypad B is
## bound to puw_run in the real map, and its only consumer,
## PUWInputInteraction.run_held(), polls state. SELECT has no
## binding or consumer anywhere in the tree today, so it emits an
## InputEventAction for puw_select (added to the map by the bind
## snippet shipped with this layer) and nothing else.
##
## Multi-touch: each button owns one touch index; simultaneous
## presses on other buttons are independent Controls and work in
## parallel (hold B to run while steering with the d-pad). Mouse
## input is also accepted so the layer can be QA'd on desktop
## when force-shown; mouse events emulated from a real touch are
## de-duplicated by the _is_pressed state machine, so one
## physical tap always produces exactly one press and one
## release.
##
## Drawing is pure vector primitives (circles / rounded rect /
## triangle glyphs / default-font labels) — no texture art, so
## nothing here is a placeholder image.

const REPEAT_DELAY: float = 0.38
const REPEAT_INTERVAL: float = 0.09

## Primary keyboard binding mirrored by this button, as a Key
## value (KEY_UP, KEY_ENTER, ...). 0 = no key (SELECT): then
## action_event is used instead.
@export var key_code: int = 0
## Extra actions held as state only (Input.action_press, no
## event dispatched) while the button is held.
@export var state_actions: PackedStringArray = PackedStringArray()
## Action emitted as an InputEventAction when key_code is 0.
@export var action_event: String = ""
## Optional text label ("A", "B", "START", "SELECT").
@export var label_text: String = ""
@export var label_font_size: int = 20
## Optional direction triangle: 0 none, 1 up, 2 down, 3 left, 4 right.
@export_enum("None", "Up", "Down", "Left", "Right") var glyph: int = 0
## Round (A/B) vs rounded-rect (d-pad / START / SELECT) body.
@export var circular: bool = false
## D-pad only: while held, re-emit the key event as an echo after
## REPEAT_DELAY at REPEAT_INTERVAL, mirroring keyboard
## auto-repeat so menu focus navigation keeps stepping.
@export var enable_repeat: bool = false

var _is_pressed: bool = false
var _touch_index: int = -1
var _mouse_held: bool = false
var _hold_time: float = 0.0
var _repeat_time: float = 0.0
var _style_normal: StyleBoxFlat = null
var _style_pressed: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Never steal keyboard focus: Space/Enter must stay confirm.
	focus_mode = Control.FOCUS_NONE
	_style_normal = _make_style(Color(1.0, 1.0, 1.0, 0.13))
	_style_pressed = _make_style(Color(1.0, 1.0, 1.0, 0.30))


func _make_style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(1.0, 1.0, 1.0, 0.50)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
				_press()
		else:
			if touch.index == _touch_index:
				_touch_index = -1
				_release()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			# Sliding off the button cancels the press (steering
			# off a d-pad direction releases that direction).
			if not Rect2(Vector2.ZERO, size).has_point(drag.position):
				_touch_index = -1
				_release()
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_mouse_held = true
				_press()
			elif _mouse_held:
				_mouse_held = false
				_release()
			accept_event()


func _process(delta: float) -> void:
	if not _is_pressed or not enable_repeat:
		return
	_hold_time += delta
	if _hold_time < REPEAT_DELAY:
		return
	_repeat_time += delta
	if _repeat_time >= REPEAT_INTERVAL:
		_repeat_time = 0.0
		_emit_primary(true, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		release_now()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			release_now()


## Programmatic press (used by the headless test; identical code
## path to a real touch).
func press_now() -> void:
	_press()


## Programmatic release; also the stuck-key safety net when the
## button leaves the tree or is hidden mid-press.
func release_now() -> void:
	_touch_index = -1
	_mouse_held = false
	_release()


func is_touch_pressed() -> bool:
	return _is_pressed


func _press() -> void:
	if _is_pressed:
		return
	_is_pressed = true
	_hold_time = 0.0
	_repeat_time = 0.0
	_emit_primary(true, false)
	for action_name in state_actions:
		Input.action_press(action_name)
	queue_redraw()


func _release() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	for action_name in state_actions:
		Input.action_release(action_name)
	_emit_primary(false, false)
	queue_redraw()


func _emit_primary(pressed_state: bool, echo: bool) -> void:
	if key_code != 0:
		# Real hardware events carry BOTH keycode and
		# physical_keycode (the tree's input tests note the
		# bound stack reads one, the action map the other).
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = key_code as Key
		key_event.physical_keycode = key_code as Key
		key_event.pressed = pressed_state
		key_event.echo = echo
		Input.parse_input_event(key_event)
	elif action_event != "":
		var action_ev: InputEventAction = InputEventAction.new()
		action_ev.action = action_event
		action_ev.pressed = pressed_state
		action_ev.strength = 1.0 if pressed_state else 0.0
		Input.parse_input_event(action_ev)


func _draw() -> void:
	var fill: Color = Color(1.0, 1.0, 1.0, 0.30) if _is_pressed else Color(1.0, 1.0, 1.0, 0.13)
	var edge: Color = Color(1.0, 1.0, 1.0, 0.50)
	var ink: Color = Color(1.0, 1.0, 1.0, 0.90)
	if circular:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(center + Vector2(0.0, 2.0), radius, Color(0.0, 0.0, 0.0, 0.28))
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 48, edge, 2.0, true)
	else:
		var style: StyleBoxFlat = _style_pressed if _is_pressed else _style_normal
		if style == null:
			style = _make_style(fill)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
	if glyph != 0:
		_draw_glyph(glyph, ink)
	if label_text != "":
		var font: Font = get_theme_default_font()
		var font_size: int = label_font_size
		var baseline_y: float = size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var pos: Vector2 = Vector2((size.x - text_width) * 0.5, baseline_y)
		draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ink)


func _draw_glyph(kind: int, ink: Color) -> void:
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.26
	var points: PackedVector2Array = PackedVector2Array()
	match kind:
		1:
			points = PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, r * 0.8), center + Vector2(-r, r * 0.8)])
		2:
			points = PackedVector2Array([center + Vector2(0.0, r), center + Vector2(r, -r * 0.8), center + Vector2(-r, -r * 0.8)])
		3:
			points = PackedVector2Array([center + Vector2(-r, 0.0), center + Vector2(r * 0.8, r), center + Vector2(r * 0.8, -r)])
		4:
			points = PackedVector2Array([center + Vector2(r, 0.0), center + Vector2(-r * 0.8, r), center + Vector2(-r * 0.8, -r)])
	if points.size() == 3:
		draw_colored_polygon(points, ink)
