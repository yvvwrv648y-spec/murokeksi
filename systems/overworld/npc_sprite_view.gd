class_name PUWNPCSpriteView
extends PUWOWSpriteView
## NPC overworld sprite (code prep, 2026-11-24).
##
## The spawner (systems/overworld/spawner.gd) places every NPC
## as a bare Node2D carrying only metadata (sprite id, facing,
## movement pattern) -- nothing in the project draws an NPC
## today. This view is the missing renderer: it loads the NPC's
## sheet from the people bank bound by binding build 3
## (characters/npcs/bank/<id>_walk.png, 96x128 = 3 cols x 4 rows
## of 32 px cells, rows down / left / right / up), builds its
## clips through PUWOWAnimator, and plays idle / walk per the
## NPC's facing and movement.
##
## An NPC whose id has no bank sheet gets NO view frames and
## reports status "no_sheet" -- never a substitute person.
##
## HOST ASSEMBLY SEAM PATCH (2026-11-24, on top of the ow_anim
## prep's file): the spawner's sprite metadata carries pret
## sprite constants (SPRITE_OAK, SPRITE_FISHER, SPRITE_GIRL),
## while the people bank's sheets are filed under plain
## lowercase ids (oak, fisher). Neither side was wrong -- the
## two id spaces were simply never joined, so every spawned
## NPC reported no_sheet. setup_bank now tries the id as
## given first, then the constant's bank form (SPRITE_ prefix
## stripped, lowercased). An id with no sheet in either form
## still reports "no_sheet" (SPRITE_GIRL: the bank holds no
## generic girl sheet -- a production gap, recorded in the
## host prep report, never papered over with another sheet).

const BANK_DIR: String = "res://characters/npcs/bank/"
const BANK_COLS: int = 3
const BANK_ROWS: int = 4

var npc_id: String = ""
var sheet_status: String = ""


## Set up from a bank sheet texture (the form tests use).
func setup_sheet(tex: Texture2D, id: String = "") -> bool:
	npc_id = id
	if tex == null:
		sheet_status = "no_sheet"
		return false
	set_ow_frames(PUWOWAnimator.charset_frames(tex, BANK_COLS, BANK_ROWS))
	sheet_status = "loaded"
	return true


## Set up from the people bank by NPC id. Returns false (and
## leaves the view frameless) when the bank holds no sheet for
## the id. The spawner's pret sprite constants (SPRITE_OAK)
## resolve to their bank form (oak) when the literal id has
## no sheet; npc_id always keeps the caller's original id.
func setup_bank(npc_id_in: String) -> bool:
	var candidates: Array = [npc_id_in]
	var bank_form: String = npc_id_in
	if bank_form.begins_with("SPRITE_"):
		bank_form = bank_form.trim_prefix("SPRITE_")
	bank_form = bank_form.to_lower()
	if bank_form != npc_id_in:
		candidates.append(bank_form)
	for candidate_value in candidates:
		var candidate: String = str(candidate_value)
		var path: String = BANK_DIR + candidate + "_walk.png"
		if not ResourceLoader.exists(path):
			continue
		var tex_value: Variant = ResourceLoader.load(path)
		if tex_value is Texture2D:
			var tex: Texture2D = tex_value
			return setup_sheet(tex, npc_id_in)
	npc_id = npc_id_in
	sheet_status = "no_sheet"
	return false


## Face a direction (spawner direction strings are Godot-style
## "up" / "down" / "left" / "right" or "NONE"); "NONE" keeps
## the current facing.
func face(direction: String) -> void:
	var dir_name: String = direction.strip_edges().to_lower()
	if dir_name == "up" or dir_name == "down" or dir_name == "left" or dir_name == "right":
		play_ow(ow_state, dir_name)


## Movement patterns from the map data: a wandering / pacing
## NPC plays walk; a stationary one idles. The caller drives
## position; this only picks the clip.
func set_moving(moving: bool) -> void:
	play_ow("walk" if moving else "idle", ow_facing)
