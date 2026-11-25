# PUWCheatEngine — cheat code support for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# This is PUW's OWN cheat engine. It reads cheat codes written in the old
# formats (Action Replay, GameShark, CodeBreaker, Game Genie) and applies
# them to PUW's own game data — your money, your items, your party, and
# world flags like walk-through-walls. It never touches a Nintendo ROM.
# There is no ROM here. Codes are parsed into an address and a value, and
# then mapped onto PUW game state through a safe table, so a bad code can
# never crash the game or write somewhere it should not.
#
# How to use it:
#   var cheats = PUWCheatEngine.new()
#   add_child(cheats)
#   cheats.apply_code("82005274 0001")   # a CodeBreaker style code
#   cheats.enable_cheat("rare_candy")    # one of PUW's own named cheats
#   print(cheats.game_state["money"])
#
# Code formats this parser understands (verified against public sources):
#
#   Action Replay, Nintendo DS style:
#       XXXXXXXX YYYYYYYY   (two groups of 8 hex digits)
#       The first digit of the first group is the code type:
#       0 = 32-bit write, 1 = 16-bit write, 2 = 8-bit write,
#       9 = button check, B = load offset, C = repeat a block,
#       D0/D2 = end of a code block.
#       Example (Pokemon Diamond, Max Cash, press L+R):
#       94000130 fcff0000 / b21c4d28 00000000 / b0000004 00000000 /
#       000002e4 000f423f / d2000000 00000000
#       NOTE: Game Boy Advance Action Replay codes are ENCRYPTED pairs of
#       8 hex digits. You cannot read the address and value off an
#       encrypted GBA code, so this engine does not decode them. It
#       handles the DS style shown above and CodeBreaker style below.
#
#   GameShark, Game Boy / Game Boy Color style:
#       TTVVAAAA   (one group of 8 hex digits, no space)
#       TT = code type and memory bank (usually 01), VV = the value
#       written, AAAA = the memory address, low byte first.
#       Example (Pokemon Red, walk through walls): 010138CD
#       (type 01, value 01, address $CD38, written low byte first).
#
#   CodeBreaker, Game Boy Advance style:
#       AAAAAAAA YYYY   (8 hex digits, a space, a short value)
#       The first digit is the code type. A real address starts
#       02XXXXXX or 03XXXXXX; you drop the leading 0 and put the type
#       digit in front. Main types: 3 = 8-bit write, 8 = 16-bit write,
#       4 = slide code, 6 = 16-bit AND, 7 = run next line if equal,
#       A = run next line if not equal, D = button check.
#       Example (Pokemon Emerald, Master Ball from Poke Mart):
#       82005274 0001
#
#   Game Genie, Game Boy / Game Boy Color style:
#       XXX-XXX-XXX   (9 hex digits, written in three groups of three)
#       The first two digits are the new value. The next four digits
#       hold the memory address, XORed by $F000, with the nibbles in the
#       order F, C, D, E. The next two digits hold the old value the
#       Genie checks for, XORed by $BA and rotated left by two. The
#       last digit is a checksum and is ignored here.
#       Example (Pokemon Blue, Master Ball in Pewter City):
#       014-4DD-91E  (value 01 = Master Ball)
#       NOTE: the letter-based Game Genie codes (A, P, Z, L, G, I, T,
#       Y, E, O, X, U, K, S, V, N) are for the NES version. Pokemon
#       never came out on the NES, so this engine only detects those
#       codes and reports them; it does not apply them.
#
# PUW named cheats (these are PUW's own, not Nintendo codes):
#   rare_candy, max_money, walk_through_walls, shiny_party, max_level,
#   master_balls, all_badges, infinite_pp, unlock_all_moves
# Each one is a small safe change to PUW's game state, listed in
# PUW_CHEATS below. Mods can add their own named cheats with
# register_named_cheat().

class_name PUWCheatEngine
extends Node

signal cheat_applied(code_text: String, effect: String)
signal cheat_failed(code_text: String, reason: String)

## PUW's own game state. The engine only ever writes to this dictionary.
## "party" is an Array of Dictionaries with keys: species, level, hp, max_hp,
## shiny, moves. "items" is a Dictionary of item name -> count.
## "flags" is a Dictionary of flag name -> bool.
var game_state: Dictionary = {
	"money": 3000,
	"badges": 0,
	"items": {"poke_ball": 5, "potion": 3},
	"flags": {"walk_through_walls": false, "infinite_pp": false},
	"party": [],
}

## PUW's own named cheats. Each entry is a Dictionary describing one safe
## change to game_state. "do" is one of: give_item, set_money, set_flag,
## set_level, set_shiny, set_badges.
const PUW_CHEATS: Dictionary = {
	"rare_candy": {"do": "give_item", "item": "rare_candy", "count": 99,
		"text": "Gave 99 Rare Candy."},
	"max_money": {"do": "set_money", "value": 999999,
		"text": "Money set to 999999."},
	"walk_through_walls": {"do": "set_flag", "flag": "walk_through_walls",
		"value": true, "text": "Walk through walls is on."},
	"shiny_party": {"do": "set_shiny", "value": true,
		"text": "Every Pokemon in your party is now shiny."},
	"max_level": {"do": "set_level", "value": 100,
		"text": "Every Pokemon in your party is now level 100."},
	"master_balls": {"do": "give_item", "item": "master_ball", "count": 99,
		"text": "Gave 99 Master Balls."},
	"all_badges": {"do": "set_badges", "value": 8,
		"text": "All 8 badges given."},
	"infinite_pp": {"do": "set_flag", "flag": "infinite_pp", "value": true,
		"text": "Moves never run out of PP."},
	"unlock_all_moves": {"do": "set_flag", "flag": "unlock_all_moves",
		"value": true, "text": "All moves are unlocked for your party."},
}

## NES Game Genie letter -> hex nibble table. This is the published NES
## alphabet. Pokemon never came out on the NES, so these codes are only
## detected, never applied.
const NES_GAME_GENIE_ALPHABET: Dictionary = {
	"A": 0, "P": 1, "Z": 2, "L": 3, "G": 4, "I": 5, "T": 6, "Y": 7,
	"E": 8, "O": 9, "X": 10, "U": 11, "K": 12, "S": 13, "V": 14, "N": 15,
}

## A small table that maps a few well-known cheat-code addresses to PUW
## game state. Real cheat codes for old games used real memory addresses;
## here those addresses are only used as keys, and each key points at a
## safe PUW effect. Unknown addresses are ignored on purpose.
## GBA-style 32-bit addresses (CodeBreaker / Action Replay DS):
const ADDRESS_EFFECTS: Dictionary = {
	0x02005274: {"do": "give_item", "item": "master_ball", "count": 1,
		"text": "Master Ball given by code."},
	0x02025E00: {"do": "give_item", "item": "rare_candy", "count": 1,
		"text": "Rare Candy given by code."},
	0x000002E4: {"do": "set_money", "value": 999999,
		"text": "Money changed by code."},
}
## Game Boy 16-bit addresses (GameShark GB / Game Genie GB):
## 0xCD38 = walk through walls in Pokemon Red, 0xD347-0xD349 = money
## in Pokemon Red (three bytes, BCD: 99 99 99 = 999999), 0xD31E = the
## first item slot in Pokemon Red (99 Master Balls code).
const GB_ADDRESS_EFFECTS: Dictionary = {
	0xCD38: {"do": "set_flag", "flag": "walk_through_walls", "value": true,
		"text": "Walk through walls is on."},
	0xD347: {"do": "set_money", "value": 999999,
		"text": "Money changed by code."},
	0xD348: {"do": "set_money", "value": 999999,
		"text": "Money changed by code."},
	0xD349: {"do": "set_money", "value": 999999,
		"text": "Money changed by code."},
	0xD31E: {"do": "give_item", "item": "master_ball", "count": 99,
		"text": "99 Master Balls given by code."},
}

var _named_cheats: Dictionary = {}
var _active_named_cheats: Array[String] = []


func _ready() -> void:
	_named_cheats = PUW_CHEATS.duplicate(true)


## Add a named cheat of your own (for mods). "effect" uses the same
## "do" dictionary shape as PUW_CHEATS above.
func register_named_cheat(cheat_name: String, effect: Dictionary) -> void:
	_named_cheats[cheat_name] = effect


## Turn on one of PUW's named cheats. Returns true if it worked.
func enable_cheat(cheat_name: String) -> bool:
	if not _named_cheats.has(cheat_name):
		cheat_failed.emit(cheat_name, "Unknown named cheat.")
		return false
	_apply_effect(_named_cheats[cheat_name])
	if not _active_named_cheats.has(cheat_name):
		_active_named_cheats.append(cheat_name)
	cheat_applied.emit(cheat_name, str(_named_cheats[cheat_name].get("text", cheat_name)))
	return true


## Turn off a named cheat that has a flag effect. Item and money cheats
## cannot be undone (you keep what you got).
func disable_cheat(cheat_name: String) -> bool:
	if not _active_named_cheats.has(cheat_name):
		return false
	_active_named_cheats.erase(cheat_name)
	var effect: Dictionary = _named_cheats.get(cheat_name, {})
	if effect.get("do") == "set_flag":
		game_state["flags"][effect["flag"]] = false
		cheat_applied.emit(cheat_name, "Flag turned off: " + str(effect["flag"]))
		return true
	return true


func list_named_cheats() -> Array[String]:
	return _named_cheats.keys()


func active_named_cheats() -> Array[String]:
	return _active_named_cheats.duplicate()


## Work out which format a code string is in, and pull it apart.
## Returns a Dictionary like:
##   {"format": "action_replay", "code_type": 0, "address": 740, "value": 999999}
##   {"format": "codebreaker", "code_type": 8, "address": 33619956, "value": 1}
##   {"format": "gameshark_gb", "code_type": 1, "address": 52536, "value": 1}
##   {"format": "game_genie", "address": 9280, "value": 1, "compare": 29}
##   {"format": "game_genie_nes", "nibbles": [...]}
##   {"format": "unknown"} when the text is not a code we know.
func parse_code(code_text: String) -> Dictionary:
	var text: String = code_text.strip_edges().to_upper()
	if text.is_empty():
		return {"format": "unknown", "reason": "Empty code."}
	var no_dash: String = text.replace("-", "").replace(" ", "")
	# Game Boy Game Genie: 9 hex digits, e.g. 014-4DD-91E.
	if no_dash.length() == 9 and _is_hex(no_dash):
		return _parse_game_genie_gb(no_dash)
	# NES Game Genie: 6 or 8 letters from the NES alphabet.
	if (no_dash.length() == 6 or no_dash.length() == 8) and _is_nes_genie(no_dash):
		var nibbles: Array[int] = []
		for ch in no_dash:
			nibbles.append(NES_GAME_GENIE_ALPHABET[ch])
		return {"format": "game_genie_nes", "nibbles": nibbles, "raw": text}
	# GameShark, Game Boy style: one group of 8 hex digits, TTVVAAAA.
	if text.length() == 8 and _is_hex(text):
		var whole: int = int("0x" + text)
		var address: int = ((whole & 0xFF) << 8) | ((whole >> 8) & 0xFF)
		return {
			"format": "gameshark_gb",
			"code_type": (whole >> 24) & 0xFF,
			"value": (whole >> 16) & 0xFF,
			"address": address,
			"raw": text,
		}
	# Two-group codes: Action Replay DS (8 + 8) or CodeBreaker (8 + 4).
	var parts: PackedStringArray = text.split(" ")
	if parts.size() == 2 and _is_hex(parts[0]) and _is_hex(parts[1]) \
			and parts[0].length() == 8:
		var first: int = int("0x" + parts[0])
		var second: int = int("0x" + parts[1])
		var code_type: int = (first >> 28) & 0xF
		if parts[1].length() == 4:
			return {
				"format": "codebreaker",
				"code_type": code_type,
				"address": first & 0x0FFFFFFF,
				"value": second,
				"raw": text,
			}
		if parts[1].length() == 8:
			return {
				"format": "action_replay",
				"code_type": code_type,
				"address": first & 0x0FFFFFFF,
				"value": second,
				"raw": text,
			}
	return {"format": "unknown", "reason": "Code shape not recognised."}


## Apply one code string to PUW's game state. Returns true if it did something.
func apply_code(code_text: String) -> bool:
	var parsed: Dictionary = parse_code(code_text)
	if parsed.get("format") == "unknown":
		cheat_failed.emit(code_text, str(parsed.get("reason", "Unknown code.")))
		return false
	match parsed["format"]:
		"game_genie_nes":
			cheat_failed.emit(code_text, "NES Game Genie code. Pokemon never came out on the NES, so this engine does not apply it.")
			return false
		"game_genie", "gameshark_gb":
			return _apply_gb_code(parsed, code_text)
		_:
			return _apply_hex_code(parsed, code_text)


## Apply many codes at once, one per line. Lines starting with # are comments.
## Returns a Dictionary with "applied" and "failed" counts and the failed lines.
func import_code_list(list_text: String) -> Dictionary:
	var applied: int = 0
	var failed_lines: Array[String] = []
	for raw_line in list_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if apply_code(line):
			applied += 1
		else:
			failed_lines.append(line)
	return {"applied": applied, "failed": failed_lines}


## Decode a Game Boy Game Genie code (9 hex digits, dashes ignored).
## Layout, per the published format: the first two digits are the new
## value; the address nibbles come in the order F, C, D, E and are XORed
## by $F000; the compare byte comes from digits G and I, XORed by $BA
## and rotated left by two (so decoding rotates right by two, then
## XORs $BA); the last digit is a checksum and is ignored here.
func _parse_game_genie_gb(code: String) -> Dictionary:
	var d: Array[int] = []
	for ch in code:
		d.append(int("0x" + ch))
	var value: int = (d[0] << 4) | d[1]
	var address: int = ((d[5] << 12) | (d[2] << 8) | (d[3] << 4) | d[4]) ^ 0xF000
	var compare_stored: int = (d[6] << 4) | d[8]
	var compare: int = _rotr8(compare_stored, 2) ^ 0xBA
	return {"format": "game_genie", "address": address, "value": value,
		"compare": compare, "raw": code}


func _apply_gb_code(parsed: Dictionary, code_text: String) -> bool:
	var address: int = parsed["address"]
	if GB_ADDRESS_EFFECTS.has(address):
		var effect: Dictionary = GB_ADDRESS_EFFECTS[address]
		_apply_effect(effect)
		cheat_applied.emit(code_text, str(effect.get("text", "Code applied.")))
		return true
	cheat_failed.emit(code_text, "Address not mapped to PUW. Nothing changed.")
	return false


func _apply_hex_code(parsed: Dictionary, code_text: String) -> bool:
	var code_type: int = parsed["code_type"]
	var address: int = parsed["address"]
	# Action Replay control lines do nothing in PUW: button checks (9),
	# load offset (B), repeat blocks (C), and terminators (D).
	if parsed["format"] == "action_replay" and code_type in [0x9, 0xB, 0xC, 0xD]:
		cheat_failed.emit(code_text, "Control line, not a write. Nothing changed.")
		return false
	# CodeBreaker conditional and slide lines are not writes on their own.
	if parsed["format"] == "codebreaker" and code_type in [0x4, 0x6, 0x7, 0xA, 0xD]:
		cheat_failed.emit(code_text, "Conditional or slide line. Nothing changed.")
		return false
	if ADDRESS_EFFECTS.has(address):
		var effect: Dictionary = ADDRESS_EFFECTS[address]
		_apply_effect(effect)
		cheat_applied.emit(code_text, str(effect.get("text", "Code applied.")))
		return true
	# A write code for an address we do not know is ignored, never written.
	cheat_failed.emit(code_text, "Address not mapped to PUW. Nothing changed.")
	return false


## Carry out one effect Dictionary on game_state.
func _apply_effect(effect: Dictionary) -> void:
	match effect.get("do"):
		"give_item":
			var items: Dictionary = game_state["items"]
			var item: String = str(effect["item"])
			items[item] = int(items.get(item, 0)) + int(effect.get("count", 1))
		"set_money":
			game_state["money"] = int(effect["value"])
		"set_flag":
			game_state["flags"][str(effect["flag"])] = bool(effect["value"])
		"set_level":
			for member in game_state["party"]:
				member["level"] = int(effect["value"])
		"set_shiny":
			for member in game_state["party"]:
				member["shiny"] = bool(effect["value"])
		"set_badges":
			game_state["badges"] = int(effect["value"])


func _is_hex(text: String) -> bool:
	if text.is_empty():
		return false
	for ch in text:
		if not ("0" <= ch and ch <= "9" or "A" <= ch and ch <= "F" or "a" <= ch and ch <= "f"):
			return false
	return true


func _is_nes_genie(text: String) -> bool:
	for ch in text:
		if not NES_GAME_GENIE_ALPHABET.has(ch):
			return false
	return true


## Rotate an 8-bit value right by 2 bits.
func _rotr8(value: int, bits: int) -> int:
	return ((value >> bits) | ((value & ((1 << bits) - 1)) << (8 - bits))) & 0xFF
