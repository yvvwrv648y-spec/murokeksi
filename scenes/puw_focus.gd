class_name PUWFocus
extends RefCounted
## One shared focus helper (code_prep_input_menus). The live
## battle scene never grabbed focus, so a keyboard/gamepad player
## faced a battle they could only click. Screens that drive real
## Buttons call this once their buttons exist.

## Grab focus on the first visible, enabled button in the list.
## Returns true when a button took focus.
static func grab_first_enabled(buttons: Array) -> bool:
	for raw in buttons:
		var b: Button = raw as Button
		if b != null and b.visible and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return true
	return false
