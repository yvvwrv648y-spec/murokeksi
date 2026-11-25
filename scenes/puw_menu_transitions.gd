class_name PUWMenuTransitions
extends RefCounted
## The one transition system every menu uses (MENU_AUDIT_AND_REBUILD_SPEC
## §3.0 "Transitions"). The menu stack calls these; panels never tween
## themselves. Timings are the spec's: dim fade 0.15 s, open slide-up
## 24 px + fade 0.18 s ease-out, submenu push/pop slide 32 px at
## 0.12 s, close 0.15 s. No instant visible toggles anywhere: a panel
## is only hidden at the end of its out-tween.

const DIM_ALPHA: float = 0.45
const DIM_TIME: float = 0.15
const OPEN_TIME: float = 0.18
const OPEN_RISE_PX: float = 24.0
const PUSH_TIME: float = 0.12
const PUSH_SLIDE_PX: float = 32.0
const CLOSE_TIME: float = 0.15


## Fade the stack's dim layer in. Dim must start transparent.
static func dim_in(owner: Node, dim: ColorRect) -> Tween:
	dim.visible = true
	dim.color = Color(0, 0, 0, 0)
	var tween: Tween = owner.create_tween()
	tween.tween_property(dim, "color", Color(0, 0, 0, DIM_ALPHA), DIM_TIME)
	return tween


static func dim_out(owner: Node, dim: ColorRect) -> Tween:
	var tween: Tween = owner.create_tween()
	tween.tween_property(dim, "color", Color(0, 0, 0, 0), DIM_TIME)
	tween.tween_callback(func() -> void: dim.visible = false)
	return tween


## First open: slide up 24 px + fade in, ease-out.
static func panel_open_in(owner: Node, panel: Control) -> Tween:
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.y += OPEN_RISE_PX
	var target_y: float = panel.position.y - OPEN_RISE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, OPEN_TIME)
	tween.tween_property(panel, "position:y", target_y, OPEN_TIME)
	return tween


## Submenu push: new panel slides in from the right + fades in.
static func panel_push_in(owner: Node, panel: Control) -> Tween:
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.x += PUSH_SLIDE_PX
	var target_x: float = panel.position.x - PUSH_SLIDE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, PUSH_TIME)
	tween.tween_property(panel, "position:x", target_x, PUSH_TIME)
	return tween


## Pop return: previous panel slides back in from the left.
static func panel_pop_in(owner: Node, panel: Control) -> Tween:
	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.x -= PUSH_SLIDE_PX
	var target_x: float = panel.position.x + PUSH_SLIDE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, PUSH_TIME)
	tween.tween_property(panel, "position:x", target_x, PUSH_TIME)
	return tween


## Outgoing panel on a push: slides left 32 px + fades out, then hides.
static func panel_push_out(owner: Node, panel: Control) -> Tween:
	var target_x: float = panel.position.x - PUSH_SLIDE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, PUSH_TIME)
	tween.tween_property(panel, "position:x", target_x, PUSH_TIME)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position.x = target_x + PUSH_SLIDE_PX
		panel.modulate.a = 1.0
	)
	return tween


## Outgoing panel on a pop: slides right 32 px + fades out, then hides.
static func panel_pop_out(owner: Node, panel: Control) -> Tween:
	var target_x: float = panel.position.x + PUSH_SLIDE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, PUSH_TIME)
	tween.tween_property(panel, "position:x", target_x, PUSH_TIME)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position.x = target_x - PUSH_SLIDE_PX
		panel.modulate.a = 1.0
	)
	return tween


## Final close: fade + sink 24 px over 0.15 s, then hide.
static func panel_close_out(owner: Node, panel: Control) -> Tween:
	var target_y: float = panel.position.y + OPEN_RISE_PX
	var tween: Tween = owner.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_property(panel, "position:y", target_y, CLOSE_TIME)
	tween.chain().tween_callback(func() -> void:
		panel.visible = false
		panel.position.y = target_y - OPEN_RISE_PX
		panel.modulate.a = 1.0
	)
	return tween


## The list cursor bob: ±2 px on a 0.5 s sine loop (§3.0). Call once
## when a cursor glyph is shown; kill the returned tween to stop.
static func cursor_bob(owner: Node, cursor: Control) -> Tween:
	var base_y: float = cursor.position.y
	var tween: Tween = owner.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cursor, "position:y", base_y - 2.0, 0.25)
	tween.tween_property(cursor, "position:y", base_y + 2.0, 0.5)
	tween.tween_property(cursor, "position:y", base_y, 0.25)
	return tween


## Grid selection pop: ease scale to 1.04 (or back to 1.0) in 0.08 s.
static func focus_pop(owner: Node, cell: Control, focused: bool) -> Tween:
	cell.pivot_offset = cell.size * 0.5
	var target: float = 1.04 if focused else 1.0
	var tween: Tween = owner.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2(target, target), 0.08)
	return tween
