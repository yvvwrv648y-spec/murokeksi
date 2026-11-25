class_name PUWTouchControls
extends CanvasLayer
## On-screen touch controls for Pokémon Ultimate World
## (interface/touch/touch_controls.tscn).
##
## WHY: the bound tree had no TouchScreenButton, touch overlay or
## virtual joystick anywhere. Mouse-from-touch emulation makes
## menu buttons tappable, but overworld d-pad movement and the
## A/B buttons had no on-screen form, so the game was not fully
## playable on a phone. This layer closes that gap by feeding the
## project's EXISTING input actions (see touch_button.gd) — it
## adds no input path of its own.
##
## SHOW / HIDE: the layer shows only where touch play is expected
## and stays hidden on desktop:
##   - a touchscreen is reported by the display server, or
##   - the build is Web (Riley's public website build: a desktop
##     browser without touch simply shows translucent controls;
##     touch browsers need them), or
##   - the build is iOS / Android (same feature flags
##     core/platform_manager.gd already keys off), or
##   - a real InputEventScreenTouch arrives at runtime (some
##     hardware only reveals touch after first use) — the layer
##     turns itself on at that moment, or
##   - force_show is set (desktop QA / the headless test).
## Layer 100 keeps the buttons visible and touchable above the
## overworld, battle and menu stacks so the same cluster drives
## all three; the buttons sit in the extreme corners (d-pad
## bottom-left, A/B bottom-right, START/SELECT bottom-center)
## with translucent fills, clear of the centered dialogue box
## and menu panels.

@export var force_show: bool = false

var _touch_seen: bool = false


static func touch_capable() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		return true
	if OS.has_feature("ios") or OS.has_feature("android"):
		return true
	return false


func _ready() -> void:
	_refresh_visibility()


func set_force_show(value: bool) -> void:
	force_show = value
	_refresh_visibility()


func controls_visible() -> bool:
	return visible


func _refresh_visibility() -> void:
	visible = force_show or _touch_seen or touch_capable()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not _touch_seen:
			_touch_seen = true
			_refresh_visibility()
