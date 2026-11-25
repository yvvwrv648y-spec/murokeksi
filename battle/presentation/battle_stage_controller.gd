class_name BattleStageController
extends Node2D
## Battle stage coordination: the player's Poké Ball throw and the
## 4 Omni Ring gimmick VFX (Mega, Z-Move, Dynamax/Gigantamax,
## Terastallization).
##
## THROW CONTRACT -- CORRECTED by the VS presentation prep
## (code_prep_vs_presentation). The old stub claimed "4-frame player
## throw, 3-frame Gym/E4 throw strips". No such strips exist in any
## held source. The real held data (data/battle_intro_index.json):
## player back throw strips of 5 frames (Red/Leaf) and 4 frames
## (Brendan/May, FRLG) / 5 frames (Essentials); enemy trainers have
## NO throw art held at all -- their fronts are single stills, so
## there is no Gym/E4 throw strip to count. play_trainer_throw now
## answers from the index: pass a throw-strip id ("red", "leaf",
## "brendan", "may", "red_frlg", ...) and get its real frame count,
## or 0 when no strip is held for the id. The full intro sequence
## itself lives in PUWBattleIntro; this function remains the quick
## frame-count query it always was (it has no other callers).

signal gimmick_vfx_finished(gimmick_id: String)

func play_trainer_throw(trainer_id: String, is_gym_or_e4: bool = false) -> int:
	var entry: Dictionary = PUWBattleIntro.strip_entry_for(trainer_id)
	if entry.is_empty():
		return 0
	return int(entry.get("frames", 0))

func trigger_omni_ring_vfx(gimmick_id: String) -> Dictionary:
	var palette := {
		"mega": "#ff4da6",
		"zmove": "#ffd447",
		"dynamax": "#ff2e63",
		"tera": "#38bdf8",
	}
	emit_signal("gimmick_vfx_finished", gimmick_id)
	return {"gimmick": gimmick_id, "aura_hex": palette.get(gimmick_id, "#ffffff"), "active": true}
