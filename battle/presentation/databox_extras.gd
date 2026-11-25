class_name PUWDataboxExtras
extends RefCounted
## Staged fix (battle_presentation lane, 2026-11-24) — NOT yet bound.
##
## The live battle scene (scenes/battle.tscn + battle_scene.gd) has
## databoxes with name / level / HP bar / HP number only: no EXP bar,
## no status-condition chip, and HP is set instantly with
## PUWUiTheme.update_hp_bar even though PUWUiTheme.tween_hp_bar (the
## 0.25 s drain tween) already exists and is never called. BW2's
## databox shows all three and drains HP over time. This helper adds
## the missing pieces programmatically (no .tscn edit needed) and
## routes HP/EXP changes through tweens.
##
## Bind steps are in PATCHES.md next to this file. All Variant reads
## are typed explicitly (project rule: never := on a Variant).


## Build the EXP bar (player only) and the status chip label inside
## a databox VBox. Returns {"exp_bar": ProgressBar or null,
## "status_chip": Label}. Call once per databox from _ready().
static func attach_extras(box: VBoxContainer, is_player: bool) -> Dictionary:
	var chip: Label = Label.new()
	chip.name = "StatusChip"
	chip.text = ""
	chip.visible = false
	box.add_child(chip)
	var exp_bar: ProgressBar = null
	if is_player:
		exp_bar = ProgressBar.new()
		exp_bar.name = "PlayerEXPBar"
		exp_bar.custom_minimum_size = Vector2(0, 8)
		exp_bar.show_percentage = false
		exp_bar.min_value = 0.0
		exp_bar.max_value = 100.0
		exp_bar.value = 0.0
		box.add_child(exp_bar)
	return {"exp_bar": exp_bar, "status_chip": chip}


## Show or hide the status chip for a status string ("psn", "brn",
## "par", "slp", "frz", "fainted", "" ...). Uses the theme's existing
## status_chip table so battle and party screens read identically.
static func refresh_status(chip: Label, status: String) -> void:
	if chip == null:
		return
	var data: Dictionary = PUWUiTheme.status_chip(status)
	if data.is_empty():
		chip.text = ""
		chip.visible = false
		return
	chip.text = " " + str(data.get("text", "")) + " "
	var color: Color = data.get("color", Color(0.4, 0.4, 0.4))
	chip.add_theme_stylebox_override("normal", PUWUiTheme.chip_style(color))
	chip.add_theme_color_override("font_color", Color.WHITE)
	chip.visible = true


## Animated HP change: tween the bar value over a duration scaled by
## the fraction of the bar that moves (BW2 drains big hits slower),
## clamped to [0.25, 1.5] s. Returns the Tween so the caller can
## await it before playing the next battle event.
static func animate_hp(bar: ProgressBar, hp: int, max_hp: int, owner: Node) -> Tween:
	var safe_max: int = maxi(1, max_hp)
	var current_frac: float = 0.0
	if bar.max_value > 0.0:
		current_frac = bar.value / bar.max_value
	var target_frac: float = float(clampi(hp, 0, safe_max)) / float(safe_max)
	var delta: float = absf(target_frac - current_frac)
	var duration: float = clampf(0.25 + delta * 1.25, 0.25, 1.5)
	return PUWUiTheme.tween_hp_bar(bar, hp, max_hp, owner, duration)


## Animated EXP change from one fraction to another (level-up
## rollovers are the caller's job: tween to 1.0, snap to 0, tween
## to the remainder). Applies the theme's EXP styling once, then
## tweens the value.
static func animate_exp(bar: ProgressBar, from_frac: float, to_frac: float, owner: Node, duration: float = 0.8) -> Tween:
	if bar == null:
		return null
	PUWUiTheme.update_exp_bar(bar, clampf(from_frac, 0.0, 1.0))
	bar.value = clampf(from_frac, 0.0, 1.0) * 100.0
	var tween: Tween = owner.create_tween()
	tween.tween_property(bar, "value", clampf(to_frac, 0.0, 1.0) * 100.0, duration)
	return tween
