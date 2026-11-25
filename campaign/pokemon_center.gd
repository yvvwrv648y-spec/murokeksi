class_name PokemonCenter
extends RefCounted
## The Pokemon Center healing loop for Pokemon Ultimate World.
##
## Healing restores every party member to full HP, full PP on every
## move, and clears the status condition — the same full restore the
## Centers perform in the games. Works on the plain party-member
## Dictionaries the battle engine uses.


## Heal one party member in place. Returns the same Dictionary.
static func heal_mon(mon: Dictionary) -> Dictionary:
	mon["hp"] = int(mon.get("max_hp", 0))
	mon["status"] = ""
	var moves: Array = mon.get("moves", [])
	for m: Variant in moves:
		var md: Dictionary = m
		md["pp"] = int(md.get("max_pp", 0))
	mon["moves"] = moves
	return mon


## Heal the whole party in place. Returns the party Array.
## Audio wiring build: a heal that actually changed something
## fires the ui_heal hook - the index maps it to the FRLG
## "Pkmn healing" jingle - through PUWUiSound, the one entry
## point for menu/event sounds. The hook is recorded in
## PUWUiSound.played_log even with no live instance, and plays
## wherever a host scene has ensured one.
static func heal_party(party: Array) -> Array:
	var needed: bool = party_needs_healing(party)
	for mon: Variant in party:
		var md: Dictionary = mon
		heal_mon(md)
	if needed:
		PUWUiSound.play("ui_heal")
	return party


## True when at least one party member is hurt, out of PP, or has a
## status condition — i.e. when a Center visit would change anything.
static func party_needs_healing(party: Array) -> bool:
	for mon: Variant in party:
		var md: Dictionary = mon
		if int(md.get("hp", 0)) < int(md.get("max_hp", 0)):
			return true
		if str(md.get("status", "")) != "":
			return true
		var moves: Array = md.get("moves", [])
		for m: Variant in moves:
			var mv: Dictionary = m
			if int(mv.get("pp", 0)) < int(mv.get("max_pp", 0)):
				return true
	return false
