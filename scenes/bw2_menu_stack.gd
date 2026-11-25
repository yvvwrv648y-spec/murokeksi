class_name BW2MenuStack
extends CanvasLayer
## Unified Pokemon Black 2 / White 2 Menu Stack tied to B / X / Escape.
## Replaces floating disconnected panels with a single docked X-Menu -> Submenu navigation stack.
##
## Kept from Neon's original (MENU_AUDIT_AND_REBUILD_SPEC §1.1: KEEP AS
## PLUMBING) with the audit's four gaps closed (§3.1 / §4 step 1):
##   1. Focus management — a pushed panel's initial control is grabbed
##      (panel.get_initial_focus_control() when the panel provides it,
##      otherwise the first visible focusable control in the panel).
##   2. Transitions — panels animate through PUWMenuTransitions over a
##      dim layer; nothing toggles visible instantly.
##   3. Sound hooks — ui_open / ui_close / ui_confirm / ui_cancel fire
##      through PUWUiSound at open / close / push / pop.
##   4. Touch entry point — open_from_touch() is the same code path as
##      the B button, for the on-screen Menu button (§3.0 touch rules).
## Panels are children of this layer, registered with register_panel;
## the dim layer is child 0 so every panel renders above it.

signal menu_opened
signal menu_closed
signal submenu_changed(submenu_id: String)

var _stack: Array[String] = []
var _panels: Dictionary = {}
var _dim: ColorRect = null


func _ready() -> void:
	# Audio wiring build: the stack is the menu sound host.
	# Guarantee the PUWUiSound instance (and with it the FRLG
	# stream registration its _ready performs) exists before
	# any panel fires a hook.
	PUWUiSound.ensure_instance(self)
	_dim = ColorRect.new()
	_dim.name = "MenuDim"
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)


## Registered panels are full-screen layers: the stack sizes the
## dim and every panel to the viewport (and re-fits on resize), so
## a panel's own full-rect children lay out against the real screen.
func _fit_to_viewport() -> void:
	if get_viewport() == null:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if _dim != null:
		_dim.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_dim.position = Vector2.ZERO
		_dim.size = view_size
	for panel_value in _panels.values():
		var panel: Control = panel_value as Control
		if panel != null:
			panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			panel.position = Vector2.ZERO
			panel.size = view_size


func register_panel(panel_id: String, node: Control) -> void:
	_panels[panel_id] = node
	node.visible = false
	_fit_to_viewport()


func current_panel_id() -> String:
	if _stack.is_empty():
		return ""
	return _stack[_stack.size() - 1]


func depth() -> int:
	return _stack.size()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_B, KEY_X, KEY_ESCAPE]):
		handle_b_button()
		get_viewport().set_input_as_handled()


## The on-screen Menu button (touch) feeds this exact same path.
func open_from_touch() -> void:
	handle_b_button()


func handle_b_button() -> void:
	if _stack.is_empty():
		push_panel("xmenu")
		menu_opened.emit()
	else:
		pop_panel()


func push_panel(panel_id: String) -> void:
	if not _panels.has(panel_id):
		push_error("BW2MenuStack: no panel registered as '" + panel_id + "'")
		return
	if current_panel_id() == panel_id:
		return
	var panel: Control = _panels[panel_id] as Control
	var was_empty: bool = _stack.is_empty()
	var outgoing: Control = null
	if not was_empty:
		outgoing = _panels[current_panel_id()] as Control
	_stack.append(panel_id)
	if was_empty:
		PUWUiSound.play("ui_open")
		PUWMenuTransitions.dim_in(self, _dim)
		PUWMenuTransitions.panel_open_in(self, panel)
	else:
		PUWUiSound.play("ui_confirm")
		if outgoing != null and outgoing != panel:
			PUWMenuTransitions.panel_push_out(self, outgoing)
		PUWMenuTransitions.panel_push_in(self, panel)
	submenu_changed.emit(panel_id)
	_focus_panel_deferred(panel)


func pop_panel() -> void:
	if _stack.is_empty():
		return
	var outgoing_id: String = current_panel_id()
	var outgoing: Control = _panels[outgoing_id] as Control
	_stack.pop_back()
	if _stack.is_empty():
		PUWUiSound.play("ui_close")
		PUWMenuTransitions.panel_close_out(self, outgoing)
		PUWMenuTransitions.dim_out(self, _dim)
		menu_closed.emit()
	else:
		PUWUiSound.play("ui_cancel")
		PUWMenuTransitions.panel_pop_out(self, outgoing)
		var top: String = current_panel_id()
		var panel: Control = _panels[top] as Control
		PUWMenuTransitions.panel_pop_in(self, panel)
		submenu_changed.emit(top)
		_focus_panel_deferred(panel)


## Grab focus on the panel's initial control once its in-animation
## has had a frame to start, so keyboard/gamepad/touch-focus all land
## in the freshly opened panel (§3.1 fix 1).
func _focus_panel_deferred(panel: Control) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or panel == null or not panel.visible:
		return
	var target: Control = null
	if panel.has_method("get_initial_focus_control"):
		target = panel.call("get_initial_focus_control") as Control
	if target == null:
		target = _first_focusable(panel)
	if target != null:
		target.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		var control: Control = child as Control
		if control != null and control.visible and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
			return control
		var nested: Control = _first_focusable(child)
		if nested != null:
			return nested
	return null
