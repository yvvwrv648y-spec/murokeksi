class_name PUWMoveButtonPolish
extends RefCounted
## Staged fix (battle_presentation lane, 2026-11-24) — NOT yet bound.
##
## The live battle scene's move buttons show the move NAME ONLY
## (battle_scene.gd _refresh_move_buttons). BW2's move menu shows
## name + PP and tints by type. Everything needed is already on the
## mon dict the scene holds: mon["pp"] is the controller's
## name -> current-PP map (battle_controller.gd builds it), and PP
## max + type come from data/move_database_954.json via the move
## database loader. This helper applies the BW2-form label.
##
## All Variant reads are typed explicitly (never := on a Variant).


## Apply BW2-form labels to the 4 move buttons.
## buttons: the scene's [move_button_1..4].
## mon: the active mon dict (reads "moves" and "pp").
## move_info: squashed-name -> {"pp_max": int, "type": String}
##   built once by the caller from the move database.
static func apply(buttons: Array, mon: Dictionary, move_info: Dictionary) -> void:
	var moves: Array = mon.get("moves", [])
	var pp_map: Dictionary = mon.get("pp", {})
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		if i >= moves.size():
			btn.text = "-"
			btn.disabled = true
			continue
		var move_name: String = str(moves[i])
		btn.disabled = false
		var key: String = move_name.to_upper().replace(" ", "").replace("-", "").replace("_", "")
		var info: Dictionary = move_info.get(key, {})
		var pp_max: int = int(info.get("pp_max", 0))
		var type_name: String = str(info.get("type", ""))
		var label: String = move_name
		if pp_map.has(move_name) and pp_max > 0:
			var pp_now: int = int(pp_map[move_name])
			label = move_name + "  " + str(pp_now) + "/" + str(pp_max)
			if pp_now == 0:
				btn.disabled = true
		btn.text = label
		if type_name != "":
			# TYPE_COLORS keys are Title-case ("Fire", "Water").
			var tint: Color = PUWUiTheme.type_color(type_name.capitalize())
			btn.add_theme_color_override("font_color", tint.lightened(0.35))
