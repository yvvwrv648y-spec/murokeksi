class_name PUWBattleFormats
extends RefCounted
## Battle format gates for Pokemon Ultimate World (Godot 4).
## Plain words: the team checks for the special formats in the
## RC1 formats doc (PUW_BATTLE_FORMATS_GIMMICKS_AND_CAPS.json).
##
## - Sky Battle (Gen VI): ONLY Flying-type or Levitate Pokemon
##   may take part; ground-bound Pokemon are strictly locked out.
## - VGC (Pokemon World Championships): Lv.50 Flat, Bring-6-
##   Pick-4. The team pick lives here; the battle itself is a
##   doubles battle run by the controller as usual.
##
## Inverse Battle needs no gate here: it only flips the type
## chart, and that lives in PUWBattleEngine.calculate_damage()
## behind the field flag "inverse_battle", which the controller
## sets in start_battle() for the "inverse_battle" format.
##
## Every function here fails safe: bad input gives a clear
## {ok: false, ...} answer instead of a crash, and no input
## dictionary is ever changed.

## Ability names are matched the same way the ability engine
## matches them: lower case, with spaces, hyphens and
## apostrophes removed, so a display name ("Levitate") and a
## slug ("levitate") read the same.
static func _ability_key(ability: String) -> String:
	return ability.to_lower().replace(" ", "").replace("-", "").replace("'", "")

static func _mon_name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))

## Sky Battle gate for one Pokemon: it may take part when one
## of its types is Flying (any capitals) or its ability is
## Levitate (display name or slug).
static func sky_battle_eligible(mon: Dictionary) -> bool:
	var types: Array = mon.get("types", [])
	for t in types:
		if str(t).to_lower() == "flying":
			return true
	return _ability_key(str(mon.get("ability", ""))) == "levitate"

## Sky Battle gate for a whole party. Returns {ok: true} when
## every Pokemon may take part, or {ok: false, refused: [...]}
## with the name of every locked-out Pokemon, in party order.
static func sky_battle_check(party: Array) -> Dictionary:
	var refused: Array = []
	for entry in party:
		if entry is Dictionary:
			var mon: Dictionary = entry
			if not sky_battle_eligible(mon):
				refused.append(_mon_name(mon))
	return {"ok": refused.is_empty(), "refused": refused}

## VGC team pick: from a party of 6, choose the 4 that fight.
## picks holds 4 distinct party indices. On success returns
## {ok: true, team: [...]} with COPIES of the picked Pokemon,
## each copy's level set to 50 (Lv.50 Flat) — the party passed
## in is never changed. Bad picks (wrong count, a repeated
## index, an index outside the party, a non-number entry)
## return {ok: false, reason: ...}.
static func vgc_select_team(party: Array, picks: Array) -> Dictionary:
	if picks.size() != 4:
		return {"ok": false, "reason": "VGC is Bring-6-Pick-4: exactly 4 picks are needed, got " + str(picks.size()) + "."}
	var seen: Dictionary = {}
	var team: Array = []
	for pick in picks:
		if not (pick is int or pick is float):
			return {"ok": false, "reason": "A pick was not a party index: " + str(pick) + "."}
		var idx: int = int(pick)
		if idx < 0 or idx >= party.size():
			return {"ok": false, "reason": "Pick " + str(idx) + " is outside the party (0-" + str(party.size() - 1) + ")."}
		if seen.has(idx):
			return {"ok": false, "reason": "Pick " + str(idx) + " was chosen twice; the 4 picks must be distinct."}
		seen[idx] = true
		var entry: Variant = party[idx]
		if not (entry is Dictionary):
			return {"ok": false, "reason": "Party slot " + str(idx) + " is not a Pokemon."}
		var mon: Dictionary = entry
		var copy: Dictionary = mon.duplicate(true)
		copy["level"] = 50
		team.append(copy)
	return {"ok": true, "team": team}
