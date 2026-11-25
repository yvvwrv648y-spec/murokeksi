class_name PUWPKHexBridge
extends RefCounted
## PKHeX / PKHaX bridge: exchanges individual Pokemon between a PUW
## save and PKHeX through the file format PKHeX genuinely supports
## for loose Pokemon -- the decrypted Gen 9 entity file (.pk9,
## 344 bytes). PKHeX cannot open a PUW native save (it reads official
## game saves only); this bridge is the supported route, specified in
## PKHEX_BRIDGE_SPEC.md (read it before changing merge rules).
##
## Shape of the exchange:
## - export_state(state, dir): every party + boxed mon in the state
##   becomes one .pk9 plus one ".puw.json" sidecar in dir, plus a
##   manifest.json mapping each file to its save slot and mon_id.
##   The sidecar carries every PUW-only or bridge-derived value the
##   .pk9 cannot hold (mon_id, shadow fields, family, PID/EC, gender,
##   ball, ...), so a round trip is lossless.
## - import_state(state, dir): reads the manifest's .pk9 files back
##   (as edited by PKHeX / PKHaX -- same format), merges the standard
##   fields into a DEEP COPY of the state at the manifest slots
##   (verified by mon_id), preserves PUW-only fields, updates the
##   sidecars, writes diff_report.json into dir, and returns the
##   merged state + the diff. Saving is the caller's job
##   (PUWSaveManager.save_game), so a refused import can never touch
##   the real save.
##
## Format facts are implemented from the staged PKHeX sources, read
## as documentation only (never built or run): PK9.cs (field layout),
## PokeCrypto.cs (sizes, checksum scope, block crypto), Species-
## Converter.cs (Gen 9 internal species ids), Experience.cs (EXP
## tables), StringConverter8.cs (UTF-16LE strings). The numeric id
## tables ride in data/pkhex_bridge_tables.json (see its "sources").
##
## All-static API over plain dicts and byte arrays, house style of
## PUWShadowSystem / PUWSaveManager. Mon dicts are treated as data;
## the only project code this module needs at bind time is
## PUWSaveManager.ensure_state_mon_ids (the G1 id pass).

const TABLES_PATH: String = "res://data/pkhex_bridge_tables.json"
const MANIFEST_NAME: String = "manifest.json"
const DIFF_NAME: String = "diff_report.json"
const MANIFEST_FORMAT: String = "puw-pkhex-bridge/1"

# .pk9 geometry (PokeCrypto.cs: SIZE_8STORED = 0x148, SIZE_8PARTY =
# 0x158, four 80-byte blocks after an 8-byte header).
const PK9_SIZE: int = 344
const PK9_STORED_SIZE: int = 328
const BLOCK_SIZE: int = 80
const HEADER_SIZE: int = 8

# Bridge conventions for fields PUW has no counterpart for. These are
# bridge-owned constants, NOT sourced game data; see the spec.
const BRIDGE_VERSION_ID: int = 49 # GameVersion.Scarlet, stamped as origin
const BRIDGE_LANGUAGE_ID: int = 2 # English
const BRIDGE_DEFAULT_BALL: int = 4 # Poke Ball
const TERA_OVERRIDE_NONE: int = 19 # TeraTypeUtil.OverrideNone
const TERA_STELLAR: int = 99 # TeraTypeUtil.Stellar

# Official nature ids 0..24 (the order PUWTeamBuilder.NATURES lists).
const NATURE_ORDER: Array = [
	"Hardy", "Lonely", "Brave", "Adamant", "Naughty",
	"Bold", "Docile", "Relaxed", "Impish", "Lax",
	"Timid", "Hasty", "Serious", "Jolly", "Naive",
	"Modest", "Mild", "Quiet", "Bashful", "Rash",
	"Calm", "Gentle", "Sassy", "Careful", "Quirky",
]
# Nature stat mods, verbatim from PUWTeamBuilder.NATURES / campaign
# NATURE_MODS: nature -> [plus_stat, minus_stat] ("" = neutral).
const NATURE_MODS: Dictionary = {
	"Hardy": ["", ""], "Lonely": ["atk", "def"], "Brave": ["atk", "spe"],
	"Adamant": ["atk", "spa"], "Naughty": ["atk", "spd"],
	"Bold": ["def", "atk"], "Docile": ["", ""], "Relaxed": ["def", "spe"],
	"Impish": ["def", "spa"], "Lax": ["def", "spd"],
	"Timid": ["spe", "atk"], "Hasty": ["spe", "def"], "Serious": ["", ""],
	"Jolly": ["spe", "spa"], "Naive": ["spe", "spd"],
	"Modest": ["spa", "atk"], "Mild": ["spa", "def"], "Quiet": ["spa", "spe"],
	"Rash": ["spa", "spd"], "Bashful": ["", ""],
	"Calm": ["spd", "atk"], "Gentle": ["spd", "def"], "Sassy": ["spd", "spe"],
	"Careful": ["spd", "spa"], "Quirky": ["", ""],
}
const STAT_KEYS: Array = ["hp", "atk", "def", "spa", "spd", "spe"]
# Type names by official type id (MoveType 0..17), PUW's lowercase
# spelling; TERA_STELLAR (99) is handled separately.
const TYPE_NAMES: Array = [
	"normal", "fighting", "flying", "poison", "ground", "rock", "bug",
	"ghost", "steel", "fire", "water", "grass", "electric", "psychic",
	"ice", "dragon", "dark", "fairy",
]
# PUW status string <-> .pk9 Status_Condition bit (0x90). Sleep is
# the low 3 bits (turns remaining); the rest are single bits.
const STATUS_BITS: Dictionary = {
	"psn": 3, "brn": 4, "frz": 5, "par": 6, "tox": 7,
}
# Block shuffle permutations (PokeCrypto.BlockPosition, 32 rows of 4;
# rows 24..31 duplicate 0..7 by design in the source).
const BLOCK_POSITION: Array = [
	0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2,
	0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
	2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1,
	1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2,
	2, 3, 0, 1, 3, 2, 0, 1, 1, 2, 3, 0, 1, 3, 2, 0,
	2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0,
	0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2,
	0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
]

static var _tables_cache: Dictionary = {}
static var _tables_cache_path: String = ""


# ------------------------------------------------------------------
# Tables
# ------------------------------------------------------------------

static func load_tables(path: String = TABLES_PATH) -> Dictionary:
	if not _tables_cache.is_empty() and _tables_cache_path == path:
		return _tables_cache
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
	_tables_cache = out
	_tables_cache_path = path
	return out


static func tables_ready(t: Dictionary) -> bool:
	return not t.is_empty() and t.has("species_by_slug") and t.has("moves_by_slug")


# ------------------------------------------------------------------
# Byte primitives (little-endian, matching the format throughout)
# ------------------------------------------------------------------

static func _u16(b: PackedByteArray, off: int) -> int:
	return int(b[off]) | (int(b[off + 1]) << 8)


static func _put_u16(b: PackedByteArray, off: int, v: int) -> void:
	b[off] = v & 0xFF
	b[off + 1] = (v >> 8) & 0xFF


static func _u32(b: PackedByteArray, off: int) -> int:
	return int(b[off]) | (int(b[off + 1]) << 8) | (int(b[off + 2]) << 16) | (int(b[off + 3]) << 24)


static func _put_u32(b: PackedByteArray, off: int, v: int) -> void:
	b[off] = v & 0xFF
	b[off + 1] = (v >> 8) & 0xFF
	b[off + 2] = (v >> 16) & 0xFF
	b[off + 3] = (v >> 24) & 0xFF


## The .pk9 checksum: sum of every u16 in Data[8..0x148], mod 2^16
## (PK9.CalculateChecksum over Checksums.Add16).
static func checksum(data: PackedByteArray) -> int:
	var total: int = 0
	var off: int = HEADER_SIZE
	while off + 1 < PK9_STORED_SIZE:
		total = (total + _u16(data, off)) & 0xFFFF
		off += 2
	return total


static func checksum_valid(data: PackedByteArray) -> bool:
	if data.size() < PK9_STORED_SIZE:
		return false
	return _u16(data, 0x06) == checksum(data)


static func refresh_checksum(data: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = data.duplicate()
	_put_u16(out, 0x06, checksum(out))
	return out


# ------------------------------------------------------------------
# Block crypto (PokeCrypto.cs, Gen 8/9 variant). Only needed to READ
# files that arrive encrypted; .pk9 files PKHeX writes are decrypted,
# and this bridge only ever writes decrypted files.
# ------------------------------------------------------------------

static func _crypt_range(b: PackedByteArray, start: int, end: int, seed: int) -> void:
	var s: int = seed & 0xFFFFFFFF
	var off: int = start
	while off + 1 < end:
		s = int((0x41C64E6D * s + 0x6073) & 0xFFFFFFFF)
		var x: int = (s >> 16) & 0xFFFF
		_put_u16(b, off, _u16(b, off) ^ x)
		off += 2


static func _shuffle_blocks(b: PackedByteArray, sv: int) -> void:
	# Selection-swap exactly as PokeCrypto.Shuffle: for each slot i,
	# bring the block the permutation names for i into slot i.
	var order: Array = []
	for k in range(4):
		order.append(int(BLOCK_POSITION[(sv & 31) * 4 + k]))
	var perm: Array = [0, 1, 2, 3] # perm[pos] = block id at pos
	var slot_of: Array = [0, 1, 2, 3] # slot_of[block] = pos
	for i in range(3):
		var desired: int = int(order[i])
		var j: int = int(slot_of[desired])
		if j == i:
			continue
		var a_start: int = HEADER_SIZE + i * BLOCK_SIZE
		var b_start: int = HEADER_SIZE + j * BLOCK_SIZE
		for k in range(BLOCK_SIZE):
			var tmp: int = int(b[a_start + k])
			b[a_start + k] = b[b_start + k]
			b[b_start + k] = tmp
		var block_at_i: int = int(perm[i])
		perm[i] = desired
		perm[j] = block_at_i
		slot_of[desired] = i
		slot_of[block_at_i] = j


static func _decrypt8(data: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = data.duplicate()
	var ec: int = _u32(out, 0x00)
	_crypt_range(out, HEADER_SIZE, PK9_STORED_SIZE, ec)
	if out.size() >= PK9_SIZE:
		_crypt_range(out, PK9_STORED_SIZE, PK9_SIZE, ec)
	_shuffle_blocks(out, (ec >> 13) & 31)
	return out


## Returns the data decrypted when it arrives encrypted, or the data
## itself when it is already a plain valid .pk9. Detection mirrors
## PKHeX's loader contract: a plain file has Sanity 0 and a valid
## checksum; anything else is tried through Decrypt8 and accepted
## only if the checksum then validates.
static func decrypted(data: PackedByteArray) -> PackedByteArray:
	if data.size() >= PK9_STORED_SIZE and _u16(data, 0x04) == 0 and checksum_valid(data):
		return data
	if data.size() >= PK9_STORED_SIZE:
		var attempt: PackedByteArray = _decrypt8(data)
		if checksum_valid(attempt):
			return attempt
	return data


# ------------------------------------------------------------------
# Strings (StringConverter8: UTF-16LE, 0x0000 terminator)
# ------------------------------------------------------------------

static func _write_string16(b: PackedByteArray, off: int, capacity_bytes: int, value: String) -> void:
	var limit: int = capacity_bytes / 2 - 1 # chars, leaving room for the terminator
	var text: String = value
	if text.length() > limit:
		text = text.substr(0, limit)
	for i in range(capacity_bytes):
		b[off + i] = 0
	for i in range(text.length()):
		_put_u16(b, off + i * 2, text.unicode_at(i))
	# terminator is the zero u16 right after the text (buffer cleared).


static func _read_string16(b: PackedByteArray, off: int, capacity_bytes: int) -> String:
	var out: String = ""
	var i: int = 0
	while i + 1 < capacity_bytes:
		var code: int = _u16(b, off + i)
		if code == 0:
			break
		out += String.chr(code)
		i += 2
	return out


# ------------------------------------------------------------------
# Deterministic derivations (bridge-owned; see the spec). FNV-1a
# over the mon_id text keeps every derived value stable per mon
# across exports with no stored state beyond the sidecar.
# ------------------------------------------------------------------

static func fnv1a32(text: String) -> int:
	var h: int = 2166136261
	var bytes: PackedByteArray = text.to_utf8_buffer()
	for i in range(bytes.size()):
		h = int(((h ^ int(bytes[i])) * 16777619) & 0xFFFFFFFF)
	return h


static func is_shiny_pid(pid: int, tid16: int, sid16: int) -> bool:
	var x: int = (tid16 ^ sid16 ^ ((pid >> 16) & 0xFFFF) ^ (pid & 0xFFFF)) & 0xFFFF
	return x < 16


static func derive_pid(mon_id: String, shiny: bool, tid16: int, sid16: int) -> int:
	var base: int = fnv1a32(mon_id + ":pid")
	var hi: int = (base >> 16) & 0xFFFF
	var v: int = 0
	if shiny:
		v = (base >> 3) & 0x7 # 0..7, always < 16
	else:
		v = 16 + int((base >> 3) % 60000) # comfortably >= 16
	var lo: int = (tid16 ^ sid16 ^ hi ^ v) & 0xFFFF
	return int(((hi << 16) | lo) & 0xFFFFFFFF)


## Same slug rule as PUWTeamBuilder.slugify (kept local so the
## bridge has no cross-system dependency beyond the save manager).
static func slugify(text: String) -> String:
	var lowered: String = text.strip_edges().to_lower().replace("♀", "f").replace("♂", "m")
	var clean: String = ""
	for i in range(lowered.length()):
		var ch: String = lowered.substr(i, 1)
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9"):
			clean += ch
	return clean


# ------------------------------------------------------------------
# Species id conversion (SpeciesConverter.cs Gen 9 deltas)
# ------------------------------------------------------------------

static func national_to_internal(t: Dictionary, national: int) -> int:
	var first: int = int(t.get("gen9_first_unaligned", 917))
	if national < first:
		return national
	var table: Array = t.get("gen9_national_to_internal", [])
	var shift: int = national - first
	if shift >= table.size():
		return national
	return national + int(table[shift])


static func internal_to_national(t: Dictionary, internal: int) -> int:
	var first: int = int(t.get("gen9_first_unaligned", 917))
	if internal < first:
		return internal
	var table: Array = t.get("gen9_internal_to_national", [])
	var shift: int = internal - first
	if shift >= table.size():
		return internal
	return internal + int(table[shift])


# ------------------------------------------------------------------
# EXP (Experience.cs tables, carried in the bridge tables file)
# ------------------------------------------------------------------

static func exp_for_level(t: Dictionary, growth: int, level: int) -> int:
	var tables: Dictionary = t.get("exp_tables", {})
	var table: Array = tables.get(str(growth), [])
	var lv: int = clampi(level, 1, 100)
	if table.size() < lv:
		return 0
	return int(table[lv - 1])


static func level_for_exp(t: Dictionary, growth: int, exp_value: int) -> int:
	var tables: Dictionary = t.get("exp_tables", {})
	var table: Array = tables.get(str(growth), [])
	var level: int = 1
	for lv in range(1, 101):
		if table.size() >= lv and int(table[lv - 1]) <= exp_value:
			level = lv
		else:
			break
	return level


# ------------------------------------------------------------------
# Mon record accessors. PUW has two live mon shapes (difficulty-layer
# records: display-name strings, moves as strings, "item"; campaign
# records: slug strings, moves as {name, pp, max_pp} dicts,
# "held_item", "species_id"). The bridge reads both and writes back
# in the shape it found. Anything it cannot represent in Gen 9 ids
# REFUSES the mon at export rather than dropping data silently.
# ------------------------------------------------------------------

static func _mon_species_slug(t: Dictionary, mon: Dictionary) -> String:
	var slug: String = str(mon.get("species_slug", ""))
	if not slug.is_empty():
		return slug
	var sid: int = int(mon.get("species_id", 0))
	if sid > 0:
		var by_dex: Dictionary = t.get("puw_base_slug_by_dex", {})
		var mapped: String = str(by_dex.get(str(sid), ""))
		if not mapped.is_empty():
			return mapped
		var fd: Dictionary = t.get("species_by_dex_form", {})
		return str(fd.get(str(sid) + ":0", ""))
	var species_name: String = str(mon.get("species", ""))
	if not species_name.is_empty():
		return slugify(species_name)
	return slugify(str(mon.get("name", "")))


## Resolves a mon to {ok, dex, form, slug, error}. The slug is the
## bridge table slug of the (species, form); a mon carrying a bridge
## "pkhex_form" from an earlier import re-exports as that form.
static func resolve_species(t: Dictionary, mon: Dictionary) -> Dictionary:
	var slug: String = _mon_species_slug(t, mon)
	var by_slug: Dictionary = t.get("species_by_slug", {})
	var rec: Dictionary = by_slug.get(slug, {})
	if rec.is_empty():
		return {"ok": false, "error": "species slug not in bridge tables: " + slug}
	var dex: int = int(rec.get("dex", 0))
	var form: int = int(rec.get("form", -1))
	if mon.has("pkhex_form"):
		var carried: int = int(mon.get("pkhex_form", 0))
		var base_rec: Dictionary = by_slug.get(slug, {})
		if int(base_rec.get("form", -1)) == 0 and carried > 0:
			form = carried
	if form < 0:
		return {"ok": false, "error": "species has no Gen 9 (SV) form entry: " + slug}
	return {"ok": true, "dex": dex, "form": form, "slug": slug}


static func _base_species(t: Dictionary, dex: int) -> Dictionary:
	var all_base: Dictionary = t.get("base_species", {})
	var rec: Variant = all_base.get(str(dex), {})
	if rec is Dictionary:
		return rec
	return {}


static func _form_data(t: Dictionary, dex: int, form: int) -> Dictionary:
	var all_forms: Dictionary = t.get("form_data", {})
	var rec: Variant = all_forms.get(str(dex) + ":" + str(form), {})
	if rec is Dictionary:
		return rec
	return {}


static func _display_name(t: Dictionary, slug: String) -> String:
	var by_slug: Dictionary = t.get("species_by_slug", {})
	var rec: Dictionary = by_slug.get(slug, {})
	var name: String = str(rec.get("name", ""))
	if name.is_empty() or name == slug:
		if slug.is_empty():
			return ""
		return slug.substr(0, 1).to_upper() + slug.substr(1)
	return name


static func _slug_for_dex_form(t: Dictionary, dex: int, form: int) -> String:
	if form == 0:
		var puw: Dictionary = t.get("puw_base_slug_by_dex", {})
		var p: String = str(puw.get(str(dex), ""))
		if not p.is_empty():
			return p
	var fd: Dictionary = t.get("species_by_dex_form", {})
	return str(fd.get(str(dex) + ":" + str(form), ""))


## Looks a move/ability/item display name or slug up in an id table.
## Returns the table slug ("" when unknown). Handles PUW's
## "Hidden Power <Type>" set notation (the type is set data, not a
## distinct Gen 9 move id).
static func _lookup_slug(table: Dictionary, raw: String) -> String:
	if raw.strip_edges().is_empty():
		return ""
	var slug: String = slugify(raw)
	if table.has(slug):
		return slug
	if slug.begins_with("hiddenpower") and table.has("hiddenpower"):
		return "hiddenpower"
	return ""


static func _mon_item_raw(mon: Dictionary) -> String:
	if mon.has("held_item"):
		return str(mon.get("held_item", ""))
	return str(mon.get("item", ""))


static func _mon_move_entries(mon: Dictionary) -> Array:
	var out: Array = []
	var moves: Variant = mon.get("moves", [])
	if moves is Array:
		for entry in moves:
			out.append(entry)
	return out


static func _move_entry_name(entry: Variant) -> String:
	if entry is Dictionary:
		var d: Dictionary = entry
		return str(d.get("name", ""))
	return str(entry)


static func _mon_tera_type(mon: Dictionary) -> String:
	var direct: String = str(mon.get("tera_type", ""))
	if not direct.is_empty():
		return direct.to_lower()
	var gimmick: Variant = mon.get("gimmick_assignment", {})
	if gimmick is Dictionary:
		var g: Dictionary = gimmick
		return str(g.get("tera_type", "")).to_lower()
	return ""


static func _type_id(type_name: String) -> int:
	var idx: int = TYPE_NAMES.find(type_name.to_lower())
	if idx >= 0:
		return idx
	if type_name.to_lower() == "stellar":
		return TERA_STELLAR
	return -1


static func _type_name(type_id: int) -> String:
	if type_id == TERA_STELLAR:
		return "stellar"
	if type_id >= 0 and type_id < TYPE_NAMES.size():
		return str(TYPE_NAMES[type_id])
	return ""


static func _nature_id(nature_name: String) -> int:
	var idx: int = NATURE_ORDER.find(nature_name)
	if idx >= 0:
		return idx
	for i in range(NATURE_ORDER.size()):
		if str(NATURE_ORDER[i]).to_lower() == nature_name.to_lower():
			return i
	return -1


## The official stat formula, identical to PUWTeamBuilder.
## _compute_stats, over sourced base stats.
static func compute_stats(base_stats: Dictionary, ivs: Dictionary, evs: Dictionary, level: int, nature: String) -> Dictionary:
	var out: Dictionary = {}
	var mods: Array = NATURE_MODS.get(nature, ["", ""])
	for key_v in STAT_KEYS:
		var key: String = str(key_v)
		var bs: int = int(base_stats.get(key, 50))
		var iv: int = int(ivs.get(key, 31))
		var ev: int = int(evs.get(key, 0))
		var core: int = int(floor((2.0 * float(bs) + float(iv) + floor(float(ev) / 4.0)) * float(level) / 100.0))
		if key == "hp":
			out[key] = core + level + 10
		else:
			var val: float = float(core + 5)
			if str(mods[0]) == key:
				val = floor(val * 1.1)
			elif str(mods[1]) == key:
				val = floor(val * 0.9)
			out[key] = int(val)
	return out


static func _gender_for(t: Dictionary, dex: int, mon_id: String, prior: Dictionary) -> int:
	if prior.has("gender"):
		return int(prior.get("gender", 2))
	var base: Dictionary = _base_species(t, dex)
	var ratio: int = int(base.get("gender_ratio", 255))
	if ratio == 255:
		return 2
	if ratio == 0:
		return 0
	if ratio == 254:
		return 1
	var roll: int = int(fnv1a32(mon_id + ":gender") % 254)
	return 1 if roll < ratio else 0


# Mon keys the .pk9 mapping owns. Every OTHER key on a mon record
# is PUW-only data: it rides in the sidecar snapshot so import can
# prove it survived untouched.
const STANDARD_KEYS: Array = [
	"name", "species", "species_slug", "species_id", "level", "exp",
	"hp", "max_hp", "atk", "def", "spa", "spd", "spe", "types",
	"base_stats", "ability", "ability_slot", "item", "held_item",
	"status", "moves", "ivs", "evs", "nature", "shiny", "friendship",
	"tera_type", "pkhex_form", "pkhex_form_slug",
]


static func _snapshot_puw_fields(mon: Dictionary) -> Dictionary:
	var snap: Dictionary = {}
	for key_v in mon.keys():
		var key: String = str(key_v)
		if STANDARD_KEYS.has(key):
			continue
		snap[key] = mon.get(key)
	return snap.duplicate(true)


# ------------------------------------------------------------------
# Encode: PUW mon dict -> .pk9 bytes + sidecar
# ------------------------------------------------------------------

## ctx: {ot_name, tid16, sid16}. prior: the sidecar from a previous
## export of this mon ({} when none) -- values already derived for
## this mon stay stable across re-exports.
static func encode_mon(mon: Dictionary, ctx: Dictionary, t: Dictionary, prior: Dictionary = {}) -> Dictionary:
	var notes: Array = []
	var resolved: Dictionary = resolve_species(t, mon)
	if not bool(resolved.get("ok", false)):
		return {"ok": false, "error": str(resolved.get("error", "species unresolved"))}
	var dex: int = int(resolved.get("dex", 0))
	var form: int = int(resolved.get("form", 0))
	var slug: String = _mon_species_slug(t, mon)
	var mon_id: String = str(mon.get("mon_id", ""))
	var base: Dictionary = _base_species(t, dex)
	var fdata: Dictionary = _form_data(t, dex, form)
	var tid16: int = int(ctx.get("tid16", 0)) & 0xFFFF
	var sid16: int = int(ctx.get("sid16", 0)) & 0xFFFF
	var level: int = clampi(int(mon.get("level", 1)), 1, 100)
	var ivs: Dictionary = mon.get("ivs", {})
	var evs: Dictionary = mon.get("evs", {})

	var b: PackedByteArray = PackedByteArray()
	b.resize(PK9_SIZE)

	# Identity block: EC / PID (sidecar-stable, shiny-consistent).
	var ec: int = int(prior.get("ec", -1))
	if ec < 0:
		ec = fnv1a32(mon_id + ":ec")
	var shiny: bool = bool(mon.get("shiny", false))
	var pid: int = int(prior.get("pid", -1))
	if pid < 0 or is_shiny_pid(pid, tid16, sid16) != shiny:
		pid = derive_pid(mon_id, shiny, tid16, sid16)
	_put_u32(b, 0x00, ec)
	_put_u16(b, 0x08, national_to_internal(t, dex))
	_put_u32(b, 0x0C, tid16 | (sid16 << 16))
	_put_u32(b, 0x1C, pid)

	# Held item: an unmapped non-empty item refuses the mon (the
	# alternative would be silently dropping the item in PKHeX).
	var item_raw: String = _mon_item_raw(mon)
	var item_id: int = 0
	if not item_raw.strip_edges().is_empty():
		var items: Dictionary = t.get("items_by_slug", {})
		var item_slug: String = _lookup_slug(items, item_raw)
		if item_slug.is_empty():
			return {"ok": false, "error": "held item has no Gen 9 item id: " + item_raw}
		item_id = int((items.get(item_slug, {}) as Dictionary).get("id", 0))
	_put_u16(b, 0x0A, item_id)

	# EXP: the mon's own tracked exp when it carries one, else the
	# level-boundary value for its growth rate (PUW tracks level,
	# not exp, on most records -- see the spec).
	var growth: int = int(base.get("exp_growth", 0))
	var exp_value: int = 0
	if mon.has("exp"):
		exp_value = int(mon.get("exp", 0))
	else:
		exp_value = exp_for_level(t, growth, level)
	_put_u32(b, 0x10, exp_value)

	# Ability + ability number from the species' own ability ids
	# (SV personal table order: slot 0, slot 1, hidden).
	var ability_ids: Array = fdata.get("abilities", [0, 0, 0])
	var ability_raw: String = str(mon.get("ability", ""))
	var ability_id: int = 0
	var ability_filled: bool = false
	if ability_raw.strip_edges().is_empty():
		ability_id = int(ability_ids[0]) if ability_ids.size() > 0 else 0
		ability_filled = true
		notes.append("ability empty on record; filled with the species' slot-0 ability")
	else:
		var abilities: Dictionary = t.get("abilities_by_slug", {})
		var ability_slug: String = _lookup_slug(abilities, ability_raw)
		if ability_slug.is_empty():
			return {"ok": false, "error": "ability has no Gen 9 ability id: " + ability_raw}
		ability_id = int((abilities.get(ability_slug, {}) as Dictionary).get("id", 0))
	_put_u16(b, 0x14, ability_id)
	var a0: int = int(ability_ids[0]) if ability_ids.size() > 0 else 0
	var a1: int = int(ability_ids[1]) if ability_ids.size() > 1 else 0
	var a2: int = int(ability_ids[2]) if ability_ids.size() > 2 else 0
	var ability_number: int = 1
	if str(mon.get("ability_slot", "")) == "hidden" and ability_id == a2:
		ability_number = 4
	elif ability_id == a2 and a2 != a0 and a2 != a1:
		ability_number = 4
	elif ability_id == a1 and a1 != a0:
		ability_number = 2
	b[0x16] = ability_number & 7

	# Nature (display + stat nature identical: PUW has one nature).
	var nature_name: String = str(mon.get("nature", ""))
	var nature_id: int = _nature_id(nature_name)
	if nature_id < 0:
		nature_id = 0
		nature_name = "Hardy"
		notes.append("nature empty/unknown on record; exported as Hardy")
	b[0x20] = nature_id
	b[0x21] = nature_id

	# Gender (bridge-derived, sidecar-carried; PUW records none).
	var gender: int = _gender_for(t, dex, mon_id, prior)
	b[0x22] = (gender & 3) << 1

	# Form (u16 write per PK9.cs; high byte stays 0).
	_put_u16(b, 0x24, form)

	# EVs in format order hp, atk, def, SPE, spa, spd.
	b[0x26] = clampi(int(evs.get("hp", 0)), 0, 255)
	b[0x27] = clampi(int(evs.get("atk", 0)), 0, 255)
	b[0x28] = clampi(int(evs.get("def", 0)), 0, 255)
	b[0x29] = clampi(int(evs.get("spe", 0)), 0, 255)
	b[0x2A] = clampi(int(evs.get("spa", 0)), 0, 255)
	b[0x2B] = clampi(int(evs.get("spd", 0)), 0, 255)

	# Nickname: the mon's own name when it is a real nickname,
	# else the species' official display name.
	var display: String = _display_name(t, _slug_for_dex_form(t, dex, form))
	var mon_name: String = str(mon.get("name", ""))
	var nicknamed: bool = false
	var nickname_text: String = display
	if not mon_name.is_empty() and slugify(mon_name) != slugify(display) and slugify(mon_name) != slug:
		nicknamed = true
		nickname_text = mon_name
	_write_string16(b, 0x58, 26, nickname_text)

	# Moves + PP.
	var moves_table: Dictionary = t.get("moves_by_slug", {})
	var entries: Array = _mon_move_entries(mon)
	for i in range(4):
		if i >= entries.size():
			break
		var entry: Variant = entries[i]
		var move_name: String = _move_entry_name(entry)
		var move_slug: String = _lookup_slug(moves_table, move_name)
		if move_slug.is_empty():
			return {"ok": false, "error": "move has no Gen 9 move id: " + move_name}
		var move_rec: Dictionary = moves_table.get(move_slug, {})
		var move_id: int = int(move_rec.get("id", 0))
		var base_pp: int = int(move_rec.get("pp", 0))
		_put_u16(b, 0x72 + i * 2, move_id)
		var pp: int = base_pp
		var pp_ups: int = 0
		if entry is Dictionary:
			var ed: Dictionary = entry
			if ed.has("pp"):
				pp = int(ed.get("pp", base_pp))
			if ed.has("max_pp") and base_pp > 0:
				var max_pp: int = int(ed.get("max_pp", base_pp))
				pp_ups = clampi(int(round(float(max_pp - base_pp) / (float(base_pp) * 0.2))), 0, 3)
		b[0x7A + i] = clampi(pp, 0, 255)
		b[0x7E + i] = pp_ups

	# Current HP + IVs + status.
	_put_u16(b, 0x8A, clampi(int(mon.get("hp", 0)), 0, 65535))
	var iv32: int = 0
	iv32 |= clampi(int(ivs.get("hp", 31)), 0, 31)
	iv32 |= clampi(int(ivs.get("atk", 31)), 0, 31) << 5
	iv32 |= clampi(int(ivs.get("def", 31)), 0, 31) << 10
	iv32 |= clampi(int(ivs.get("spe", 31)), 0, 31) << 15
	iv32 |= clampi(int(ivs.get("spa", 31)), 0, 31) << 20
	iv32 |= clampi(int(ivs.get("spd", 31)), 0, 31) << 25
	if nicknamed:
		iv32 |= 1 << 31
	_put_u32(b, 0x8C, iv32)
	var status: String = str(mon.get("status", "")).to_lower()
	var status_value: int = 0
	if status == "slp":
		status_value = 3 # 3 sleep turns in the low bits
	elif STATUS_BITS.has(status):
		status_value = 1 << int(STATUS_BITS[status])
	_put_u32(b, 0x90, status_value)

	# Tera type: the record's designation when it carries one, else
	# the species' first type (the official default origin type).
	var tera_source: String = "record"
	var tera_name: String = _mon_tera_type(mon)
	if tera_name.is_empty():
		tera_source = "default_first_type"
		var types: Array = fdata.get("types", [])
		if types.size() > 0:
			tera_name = str(types[0]).to_lower()
	var tera_id: int = _type_id(tera_name)
	if tera_id < 0:
		return {"ok": false, "error": "tera type has no Gen 9 type id: " + tera_name}
	b[0x94] = tera_id
	b[0x95] = TERA_OVERRIDE_NONE

	# Handler block stays empty (untraded, CurrentHandler 0).
	b[0xCE] = BRIDGE_VERSION_ID
	b[0xCF] = BRIDGE_VERSION_ID
	b[0xD5] = BRIDGE_LANGUAGE_ID

	# Original trainer block.
	_write_string16(b, 0xF8, 26, str(ctx.get("ot_name", "")))
	var friendship: int = 0
	if mon.has("friendship"):
		friendship = int(mon.get("friendship", 0))
	elif prior.has("friendship"):
		friendship = int(prior.get("friendship", 0))
	else:
		friendship = int(base.get("base_friendship", 70))
	b[0x112] = clampi(friendship, 0, 255)
	var ball: int = int(prior.get("ball", BRIDGE_DEFAULT_BALL))
	b[0x124] = ball
	b[0x125] = level & 0x7F # MetLevel; OT gender bit stays 0
	b[0x11F] = level # ObedienceLevel

	# Party stats section: the record's own computed stats (PUW's
	# truth); any missing value is recomputed by formula.
	var base_stats: Dictionary = fdata.get("base_stats", {})
	var computed: Dictionary = compute_stats(base_stats, ivs, evs, level, nature_name)
	b[0x148] = level
	_put_u16(b, 0x14A, clampi(int(mon.get("max_hp", int(computed.get("hp", 0)))), 0, 65535))
	_put_u16(b, 0x14C, clampi(int(mon.get("atk", int(computed.get("atk", 0)))), 0, 65535))
	_put_u16(b, 0x14E, clampi(int(mon.get("def", int(computed.get("def", 0)))), 0, 65535))
	_put_u16(b, 0x150, clampi(int(mon.get("spe", int(computed.get("spe", 0)))), 0, 65535))
	_put_u16(b, 0x152, clampi(int(mon.get("spa", int(computed.get("spa", 0)))), 0, 65535))
	_put_u16(b, 0x154, clampi(int(mon.get("spd", int(computed.get("spd", 0)))), 0, 65535))

	b = refresh_checksum(b)

	var sidecar: Dictionary = {
		"format": "puw-pkhex-sidecar/1",
		"mon_id": mon_id,
		"species_slug": slug,
		"dex": dex,
		"form": form,
		"ec": ec,
		"pid": pid,
		"tid16": tid16,
		"sid16": sid16,
		"gender": gender,
		"ball": ball,
		"friendship": friendship,
		"tera_source": tera_source,
		"ability_filled": ability_filled,
		"puw_snapshot": _snapshot_puw_fields(mon),
	}
	return {"ok": true, "bytes": b, "sidecar": sidecar, "notes": notes}


# ------------------------------------------------------------------
# Decode: .pk9 bytes -> field dictionary
# ------------------------------------------------------------------

static func decode_pk9(raw: PackedByteArray, t: Dictionary) -> Dictionary:
	if raw.size() < PK9_STORED_SIZE:
		return {"ok": false, "error": "file too small for a .pk9 (%d bytes)" % raw.size()}
	var data: PackedByteArray = decrypted(raw)
	if data.size() < PK9_STORED_SIZE or not checksum_valid(data):
		return {"ok": false, "error": "checksum invalid: not a valid decrypted .pk9"}
	if _u16(data, 0x04) != 0:
		return {"ok": false, "error": "sanity field nonzero: not a valid .pk9"}
	if data.size() < PK9_SIZE:
		var padded: PackedByteArray = data.duplicate()
		padded.resize(PK9_SIZE)
		data = padded

	var species_internal: int = _u16(data, 0x08)
	var dex: int = internal_to_national(t, species_internal)
	var form: int = int(data[0x24])
	var tid16: int = _u16(data, 0x0C)
	var sid16: int = _u16(data, 0x0E)
	var pid: int = _u32(data, 0x1C)
	var iv32: int = _u32(data, 0x8C)
	var ivs: Dictionary = {
		"hp": iv32 & 0x1F, "atk": (iv32 >> 5) & 0x1F, "def": (iv32 >> 10) & 0x1F,
		"spe": (iv32 >> 15) & 0x1F, "spa": (iv32 >> 20) & 0x1F, "spd": (iv32 >> 25) & 0x1F,
	}
	var evs: Dictionary = {
		"hp": int(data[0x26]), "atk": int(data[0x27]), "def": int(data[0x28]),
		"spe": int(data[0x29]), "spa": int(data[0x2A]), "spd": int(data[0x2B]),
	}
	var moves: Array = []
	var moves_table: Dictionary = t.get("moves_by_id", {})
	for i in range(4):
		var move_id: int = _u16(data, 0x72 + i * 2)
		if move_id == 0:
			continue
		moves.append({
			"id": move_id,
			"slug": str(moves_table.get(str(move_id), "")),
			"pp": int(data[0x7A + i]),
			"pp_ups": int(data[0x7E + i]),
		})
	var status_value: int = _u32(data, 0x90)
	var status: String = ""
	if status_value & 0x7 != 0:
		status = "slp"
	else:
		for key_v in STATUS_BITS.keys():
			var key: String = str(key_v)
			if status_value & (1 << int(STATUS_BITS[key])) != 0:
				status = key
				break
	var tera_original: int = int(data[0x94])
	var tera_override: int = int(data[0x95])
	var tera_effective: int = tera_original if tera_override == TERA_OVERRIDE_NONE else tera_override
	var handler: int = int(data[0xC4])
	var friendship: int = int(data[0x112]) if handler == 0 else int(data[0xC8])
	var nature_id: int = int(data[0x20])
	var stat_nature_id: int = int(data[0x21])
	var fields: Dictionary = {
		"ec": _u32(data, 0x00),
		"dex": dex,
		"form": form,
		"held_item_id": _u16(data, 0x0A),
		"held_item_slug": str(t.get("items_by_id", {}).get(str(_u16(data, 0x0A)), "")),
		"tid16": tid16,
		"sid16": sid16,
		"pid": pid,
		"shiny": is_shiny_pid(pid, tid16, sid16),
		"exp": _u32(data, 0x10),
		"ability_id": _u16(data, 0x14),
		"ability_slug": str(t.get("abilities_by_id", {}).get(str(_u16(data, 0x14)), "")),
		"ability_number": int(data[0x16]) & 7,
		"nature": str(NATURE_ORDER[nature_id]) if nature_id >= 0 and nature_id < NATURE_ORDER.size() else "",
		"stat_nature": str(NATURE_ORDER[stat_nature_id]) if stat_nature_id >= 0 and stat_nature_id < NATURE_ORDER.size() else "",
		"gender": (int(data[0x22]) >> 1) & 3,
		"ivs": ivs,
		"evs": evs,
		"nickname": _read_string16(data, 0x58, 26),
		"is_nicknamed": ((iv32 >> 31) & 1) == 1,
		"is_egg": ((iv32 >> 30) & 1) == 1,
		"moves": moves,
		"current_hp": _u16(data, 0x8A),
		"status": status,
		"status_value": status_value,
		"tera_original": tera_original,
		"tera_override": tera_override,
		"tera_effective": tera_effective,
		"ot_name": _read_string16(data, 0xF8, 26),
		"friendship": friendship,
		"current_handler": handler,
		"ball": int(data[0x124]),
		"version": int(data[0xCE]),
		"met_level": int(data[0x125]) & 0x7F,
		"party_level": int(data[0x148]),
	}
	return {"ok": true, "fields": fields}


# ------------------------------------------------------------------
# Merge: decoded fields -> PUW mon (the import half of the bridge)
# ------------------------------------------------------------------

static func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		# JSON round trips turn ints into floats and back; compare
		# numbers by value across int/float.
		if (a is int or a is float) and (b is int or b is float):
			return float(a) == float(b)
		return false
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for key_v in da.keys():
			if not db.has(key_v):
				return false
			if not _deep_equal(da.get(key_v), db.get(key_v)):
				return false
		return true
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in range(aa.size()):
			if not _deep_equal(aa[i], ab[i]):
				return false
		return true
	return a == b


static func _record_change(changes: Array, mon: Dictionary, key: String, value: Variant) -> void:
	var had: bool = mon.has(key)
	var old: Variant = mon.get(key, null)
	if had and _deep_equal(old, value):
		return
	changes.append({"field": key, "from": old if had else "<absent>", "to": value})
	mon[key] = value


## Formats an id-table name in the style the record already uses:
## "showdown" (clearbody), "pokeapi" (clear-body) or "display"
## (Clear Body). The style is detected from the FORM of the
## record's current value, then applied to the new name.
static func _restyle(existing: String, slug: String, display: String) -> String:
	if not existing.is_empty() and existing == slugify(existing):
		return slug # compact slug style ("clearbody", "poisonsting")
	if not existing.is_empty() and existing == existing.to_lower() and existing.contains("-"):
		return display.to_lower().replace(" ", "-").replace(".", "").replace("'", "")
	return display


static func apply_pk9_to_mon(mon_in: Dictionary, fields: Dictionary, sidecar_in: Dictionary, t: Dictionary) -> Dictionary:
	var changes: Array = []
	var notes: Array = []
	var errors: Array = []
	var mon: Dictionary = mon_in.duplicate(true)
	var sidecar: Dictionary = sidecar_in.duplicate(true)
	if bool(fields.get("is_egg", false)):
		return {"ok": false, "mon": mon_in, "changes": changes, "notes": notes,
			"errors": ["entity is an egg; PUW party/box records have no egg shape -- import refused"]}
	var dex: int = int(fields.get("dex", 0))
	var form: int = int(fields.get("form", 0))
	if dex <= 0 or _base_species(t, dex).is_empty():
		return {"ok": false, "mon": mon_in, "changes": changes, "notes": notes,
			"errors": ["species id %d is not in the bridge tables -- import refused" % dex]}
	var cur: Dictionary = resolve_species(t, mon)
	if not bool(cur.get("ok", false)):
		return {"ok": false, "mon": mon_in, "changes": changes, "notes": notes,
			"errors": ["current record species unresolved: " + str(cur.get("error", ""))]}
	var identity_changed: bool = int(cur.get("dex", 0)) != dex or int(cur.get("form", 0)) != form
	var fdata: Dictionary = _form_data(t, dex, form)
	var base: Dictionary = _base_species(t, dex)
	var growth: int = int(base.get("exp_growth", 0))

	# -- Species / form identity
	var old_display_slug: String = _slug_for_dex_form(t, int(cur.get("dex", 0)), int(cur.get("form", 0)))
	if identity_changed:
		var base_slug: String = _slug_for_dex_form(t, dex, 0)
		_record_change(changes, mon, "species_slug", base_slug)
		if mon.has("species_id"):
			_record_change(changes, mon, "species_id", dex)
		if mon.has("species"):
			_record_change(changes, mon, "species", _display_name(t, _slug_for_dex_form(t, dex, form)))
		if mon.has("types"):
			_record_change(changes, mon, "types", fdata.get("types", []))
		if mon.has("base_stats"):
			_record_change(changes, mon, "base_stats", fdata.get("base_stats", {}))
	if form > 0:
		_record_change(changes, mon, "pkhex_form", form)
		_record_change(changes, mon, "pkhex_form_slug", _slug_for_dex_form(t, dex, form))
		notes.append("form %d carried as pkhex_form: PUW species identity stays the base species" % form)
	else:
		if mon.has("pkhex_form"):
			changes.append({"field": "pkhex_form", "from": mon.get("pkhex_form"), "to": "<removed>"})
			mon.erase("pkhex_form")
		if mon.has("pkhex_form_slug"):
			changes.append({"field": "pkhex_form_slug", "from": mon.get("pkhex_form_slug"), "to": "<removed>"})
			mon.erase("pkhex_form_slug")

	# -- Level / EXP (level derives from EXP + growth, as in PKHeX)
	var new_level: int = level_for_exp(t, growth, int(fields.get("exp", 0)))
	var party_level: int = int(fields.get("party_level", 0))
	if party_level != 0 and party_level != new_level:
		notes.append("party-stats level %d disagrees with EXP-derived level %d; EXP wins" % [party_level, new_level])
	var level_changed: bool = int(mon.get("level", 0)) != new_level
	if level_changed:
		_record_change(changes, mon, "level", new_level)
	_record_change(changes, mon, "exp", int(fields.get("exp", 0)))

	# -- IVs / EVs / nature
	var ivs_changed: bool = not _deep_equal(mon.get("ivs", {}), fields.get("ivs", {}))
	if ivs_changed:
		_record_change(changes, mon, "ivs", (fields.get("ivs", {}) as Dictionary).duplicate(true))
	# EVs compare by value (a stored 0 and an absent key are the
	# same EV); when they do change, the record's own key style
	# (full six-key dict vs sparse) is preserved.
	var raw_evs: Dictionary = fields.get("evs", {})
	var old_evs: Dictionary = mon.get("evs", {})
	var evs_changed: bool = false
	for key_v in STAT_KEYS:
		var key: String = str(key_v)
		if int(old_evs.get(key, 0)) != int(raw_evs.get(key, 0)):
			evs_changed = true
	var new_evs: Dictionary = {}
	for key_v in STAT_KEYS:
		var key: String = str(key_v)
		var v: int = int(raw_evs.get(key, 0))
		if old_evs.size() >= 6 or v > 0:
			new_evs[key] = v
	if evs_changed:
		_record_change(changes, mon, "evs", new_evs)
	var new_nature: String = str(fields.get("stat_nature", ""))
	if str(fields.get("nature", "")) != new_nature and not new_nature.is_empty():
		notes.append("minted nature: display nature %s, effective nature %s; the effective one is imported" % [str(fields.get("nature", "")), new_nature])
	var nature_changed: bool = not new_nature.is_empty() and str(mon.get("nature", "")) != new_nature
	if nature_changed:
		_record_change(changes, mon, "nature", new_nature)

	# -- Ability (number 4 = hidden slot)
	var ability_slug: String = str(fields.get("ability_slug", ""))
	if ability_slug.is_empty():
		if int(fields.get("ability_id", 0)) != 0:
			errors.append("ability id %d unknown to the bridge tables; PUW ability kept" % int(fields.get("ability_id", 0)))
	else:
		var abilities: Dictionary = t.get("abilities_by_slug", {})
		var display: String = str((abilities.get(ability_slug, {}) as Dictionary).get("name", ability_slug))
		_record_change(changes, mon, "ability", _restyle(str(mon.get("ability", "")), ability_slug, display))
		if mon.has("ability_slot"):
			var slot: String = "hidden" if int(fields.get("ability_number", 1)) == 4 else "regular"
			_record_change(changes, mon, "ability_slot", slot)

	# -- Held item
	var item_id: int = int(fields.get("held_item_id", 0))
	var item_key: String = "held_item" if mon.has("held_item") else "item"
	if item_id == 0:
		_record_change(changes, mon, item_key, "")
	else:
		var item_slug: String = str(fields.get("held_item_slug", ""))
		if item_slug.is_empty():
			errors.append("held item id %d unknown to the bridge tables; PUW item kept" % item_id)
		else:
			var items: Dictionary = t.get("items_by_slug", {})
			var display: String = str((items.get(item_slug, {}) as Dictionary).get("name", item_slug))
			_record_change(changes, mon, item_key, _restyle(str(mon.get(item_key, "")), item_slug, display))

	# -- Moves (written back in the record's own shape)
	var moves_table: Dictionary = t.get("moves_by_slug", {})
	var old_entries: Array = _mon_move_entries(mon)
	var dict_shape: bool = old_entries.size() > 0 and old_entries[0] is Dictionary
	var new_moves: Array = []
	var pk_moves: Array = fields.get("moves", [])
	for i in range(pk_moves.size()):
		var pm: Dictionary = pk_moves[i]
		var mslug: String = str(pm.get("slug", ""))
		if mslug.is_empty():
			errors.append("move id %d unknown to the bridge tables; slot %d keeps its PUW move" % [int(pm.get("id", 0)), i])
			if i < old_entries.size():
				new_moves.append(old_entries[i])
			continue
		var mrec: Dictionary = moves_table.get(mslug, {})
		var mdisplay: String = str(mrec.get("name", mslug))
		var base_pp: int = int(mrec.get("pp", 0))
		var max_pp: int = int(float(base_pp) * float(5 + int(pm.get("pp_ups", 0))) / 5.0)
		var cur_pp: int = mini(int(pm.get("pp", base_pp)), max_pp)
		if dict_shape:
			var old_name: String = _move_entry_name(old_entries[0]) if old_entries.size() > 0 else ""
			new_moves.append({"name": _restyle(old_name, mslug, mdisplay), "pp": cur_pp, "max_pp": max_pp})
		else:
			var old_name2: String = _move_entry_name(old_entries[0]) if old_entries.size() > 0 else ""
			new_moves.append(_restyle(old_name2, mslug, mdisplay))
	if not _deep_equal(old_entries, new_moves):
		_record_change(changes, mon, "moves", new_moves)

	# -- Shiny / friendship / status / tera / nickname
	if bool(mon.get("shiny", false)) != bool(fields.get("shiny", false)):
		_record_change(changes, mon, "shiny", bool(fields.get("shiny", false)))
	var friendship_baseline: int = int(sidecar.get("friendship", mon.get("friendship", int(base.get("base_friendship", 70)))))
	if int(fields.get("friendship", 0)) != friendship_baseline:
		_record_change(changes, mon, "friendship", int(fields.get("friendship", 0)))
	if str(mon.get("status", "")) != str(fields.get("status", "")):
		_record_change(changes, mon, "status", str(fields.get("status", "")))
	var default_tera: String = ""
	var types_now: Array = fdata.get("types", [])
	if types_now.size() > 0:
		default_tera = str(types_now[0]).to_lower()
	var effective_tera: String = _type_name(int(fields.get("tera_effective", 0)))
	var current_tera: String = _mon_tera_type(mon)
	if not effective_tera.is_empty() and effective_tera != current_tera:
		if effective_tera == default_tera and current_tera.is_empty():
			pass # still the default: no designation to record
		elif effective_tera == default_tera and str(sidecar.get("tera_source", "")) == "record" and mon.has("tera_type"):
			changes.append({"field": "tera_type", "from": mon.get("tera_type"), "to": "<removed>"})
			mon.erase("tera_type")
			notes.append("tera designation cleared back to the species default")
		else:
			_record_change(changes, mon, "tera_type", effective_tera)
	if bool(fields.get("is_nicknamed", false)):
		_record_change(changes, mon, "name", str(fields.get("nickname", "")))
	elif identity_changed:
		var old_name: String = str(mon.get("name", ""))
		if slugify(old_name) == slugify(old_display_slug) or slugify(old_name) == _mon_species_slug(t, mon_in):
			_record_change(changes, mon, "name", _display_name(t, _slug_for_dex_form(t, dex, form)))
		else:
			notes.append("record name %s is custom but the .pk9 is not nicknamed; name kept" % old_name)

	# -- Derived stats: recomputed (and logged above via the field
	# changes) whenever identity, level, IVs, EVs or nature moved.
	if identity_changed or level_changed or ivs_changed or evs_changed or nature_changed:
		var stats: Dictionary = compute_stats(fdata.get("base_stats", {}), fields.get("ivs", {}), new_evs, new_level, new_nature)
		for key_v in ["max_hp", "atk", "def", "spa", "spd", "spe"]:
			var key: String = str(key_v)
			var stat_key: String = "hp" if key == "max_hp" else key
			if mon.has(key):
				_record_change(changes, mon, key, int(stats.get(stat_key, 0)))
	# Current HP comes from the .pk9, clamped to the (possibly new) max.
	var new_max_hp: int = int(mon.get("max_hp", int(fields.get("current_hp", 0))))
	_record_change(changes, mon, "hp", clampi(int(fields.get("current_hp", 0)), 0, maxi(new_max_hp, 0)))

	# -- PUW-only field verification against the sidecar snapshot.
	var snapshot: Dictionary = sidecar.get("puw_snapshot", {})
	for key_v in snapshot.keys():
		var key: String = str(key_v)
		if not mon.has(key):
			errors.append("PUW-only field missing after merge: " + key)
		elif not _deep_equal(mon.get(key), snapshot.get(key)):
			errors.append("PUW-only field drifted during merge: " + key)
	if str(mon.get("mon_id", "")) != str(mon_in.get("mon_id", "")):
		errors.append("mon_id changed during merge (must never happen)")

	# -- Sidecar refresh: bridge-owned values now follow the .pk9.
	sidecar["dex"] = dex
	sidecar["form"] = form
	sidecar["species_slug"] = _mon_species_slug(t, mon)
	sidecar["ec"] = int(fields.get("ec", 0))
	sidecar["pid"] = int(fields.get("pid", 0))
	if int(fields.get("tid16", 0)) != int(sidecar.get("tid16", 0)) or int(fields.get("sid16", 0)) != int(sidecar.get("sid16", 0)):
		notes.append("trainer id changed in PKHeX (tid %d->%d, sid %d->%d); adopted for future exports" % [
			int(sidecar.get("tid16", 0)), int(fields.get("tid16", 0)),
			int(sidecar.get("sid16", 0)), int(fields.get("sid16", 0))])
	sidecar["tid16"] = int(fields.get("tid16", 0))
	sidecar["sid16"] = int(fields.get("sid16", 0))
	sidecar["gender"] = int(fields.get("gender", 2))
	sidecar["ball"] = int(fields.get("ball", BRIDGE_DEFAULT_BALL))
	sidecar["friendship"] = int(fields.get("friendship", 0))
	sidecar["tera_source"] = "record" if mon.has("tera_type") else "default_first_type"
	sidecar["puw_snapshot"] = _snapshot_puw_fields(mon)
	return {"ok": errors.is_empty(), "mon": mon, "changes": changes, "notes": notes, "errors": errors, "sidecar": sidecar}


# ------------------------------------------------------------------
# Save-level orchestration: export_state / import_state
# ------------------------------------------------------------------

static func _sha256_hex(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


static func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(int(f.get_length()))
	f.close()
	return data


static func _write_json(path: String, data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func _mon_at(state: Dictionary, slot: Dictionary) -> Dictionary:
	if str(slot.get("kind", "")) == "party":
		var party: Array = state.get("party", [])
		var idx: int = int(slot.get("index", -1))
		if idx >= 0 and idx < party.size() and party[idx] is Dictionary:
			var m: Dictionary = party[idx]
			return m
		return {}
	var boxes: Array = state.get("boxes", [])
	var b: int = int(slot.get("box", -1))
	var p: int = int(slot.get("index", -1))
	if b >= 0 and b < boxes.size() and boxes[b] is Array:
		var box: Array = boxes[b]
		if p >= 0 and p < box.size() and box[p] is Dictionary:
			var m2: Dictionary = box[p]
			return m2
	return {}


static func _set_mon_at(state: Dictionary, slot: Dictionary, mon: Dictionary) -> void:
	if str(slot.get("kind", "")) == "party":
		var party: Array = state.get("party", [])
		var idx: int = int(slot.get("index", -1))
		if idx >= 0 and idx < party.size():
			party[idx] = mon
		return
	var boxes: Array = state.get("boxes", [])
	var b: int = int(slot.get("box", -1))
	var p: int = int(slot.get("index", -1))
	if b >= 0 and b < boxes.size() and boxes[b] is Array:
		var box: Array = boxes[b]
		if p >= 0 and p < box.size():
			box[p] = mon


static func _slot_label(slot: Dictionary) -> String:
	if str(slot.get("kind", "")) == "party":
		return "party %d" % (int(slot.get("index", 0)) + 1)
	return "box %d slot %d" % [int(slot.get("box", 0)) + 1, int(slot.get("index", 0)) + 1]


## Exports every party + boxed mon of a PUW save state to .pk9
## files (+ sidecars + manifest.json) in out_dir. The input state
## is never modified (mon ids are backfilled on an internal copy
## only). Mons that cannot be represented are refused with a
## reason, never written corrupt.
static func export_state(state: Dictionary, out_dir: String, t: Dictionary) -> Dictionary:
	var work: Dictionary = state.duplicate(true)
	PUWSaveManager.ensure_state_mon_ids(work)
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Trainer identity: stable across exports of the same folder.
	var player: Dictionary = work.get("player", {})
	var ot_name: String = str(player.get("name", "PUW"))
	if ot_name.strip_edges().is_empty():
		ot_name = "PUW"
	var old_manifest: Dictionary = _read_json(out_dir.path_join("manifest.json"))
	var trainer: Dictionary = old_manifest.get("trainer", {})
	var tid16: int = 0
	var sid16: int = 0
	if not trainer.is_empty() and str(trainer.get("ot_name", "")) == ot_name:
		tid16 = int(trainer.get("tid16", 0))
		sid16 = int(trainer.get("sid16", 0))
	else:
		tid16 = int(fnv1a32(ot_name + ":tid") % 65536)
		sid16 = int(fnv1a32(ot_name + ":sid") % 65536)
	var ctx: Dictionary = {"ot_name": ot_name, "tid16": tid16, "sid16": sid16}

	var entries: Array = []
	var refused: Array = []
	var jobs: Array = []
	var party: Array = work.get("party", [])
	for i in range(party.size()):
		if party[i] is Dictionary:
			var pm: Dictionary = party[i]
			jobs.append({"mon": pm, "slot": {"kind": "party", "index": i},
				"base": "party_%02d" % (i + 1)})
	var boxes: Array = work.get("boxes", [])
	for b in range(boxes.size()):
		if boxes[b] is Array:
			var box: Array = boxes[b]
			for p in range(box.size()):
				if box[p] is Dictionary:
					var bm: Dictionary = box[p]
					jobs.append({"mon": bm, "slot": {"kind": "box", "box": b, "index": p},
						"base": "box_%02d_%02d" % [b + 1, p + 1]})
	for job_v in jobs:
		var job: Dictionary = job_v
		var mon: Dictionary = job.get("mon", {})
		var slot: Dictionary = job.get("slot", {})
		var slug: String = _mon_species_slug(t, mon)
		var base_name: String = str(job.get("base", "mon")) + "_" + (slug if not slug.is_empty() else "unknown")
		var prior: Dictionary = _read_json(out_dir.path_join(base_name + ".puw.json"))
		if not prior.is_empty() and str(prior.get("mon_id", "")) != str(mon.get("mon_id", "")):
			prior = {} # a different mon now sits at this filename; derive fresh
		var encoded: Dictionary = encode_mon(mon, ctx, t, prior)
		if not bool(encoded.get("ok", false)):
			refused.append({"slot": slot, "mon_id": str(mon.get("mon_id", "")),
				"error": str(encoded.get("error", "encode failed"))})
			continue
		var bytes: PackedByteArray = encoded.get("bytes", PackedByteArray())
		var file_name: String = base_name + ".pk9"
		var sidecar_name: String = base_name + ".puw.json"
		if not _write_bytes(out_dir.path_join(file_name), bytes):
			refused.append({"slot": slot, "mon_id": str(mon.get("mon_id", "")), "error": "could not write " + file_name})
			continue
		_write_json(out_dir.path_join(sidecar_name), encoded.get("sidecar", {}))
		entries.append({
			"file": file_name,
			"sidecar": sidecar_name,
			"slot": slot,
			"mon_id": str(mon.get("mon_id", "")),
			"species_slug": str((encoded.get("sidecar", {}) as Dictionary).get("species_slug", slug)),
			"pk9_sha256": _sha256_hex(bytes),
			"notes": encoded.get("notes", []),
		})
	var manifest: Dictionary = {
		"format": "puw-pkhex-bridge/1",
		"trainer": {"ot_name": ot_name, "tid16": tid16, "sid16": sid16},
		"entries": entries,
		"refused": refused,
	}
	_write_json(out_dir.path_join("manifest.json"), manifest)
	return {"ok": true, "exported": entries.size(), "refused": refused,
		"manifest": manifest, "dir": out_dir}


## Imports a bridge folder back into a COPY of the save state.
## Safety rails: a mon is only merged when its slot still holds
## the same mon_id the manifest recorded; a .pk9 whose bytes are
## unchanged since export is skipped entirely (byte-identical
## round trip); any entry with an error is refused whole, never
## half-merged. The caller's state is never modified; persisting
## the returned state is the caller's decision.
static func import_state(state: Dictionary, bridge_dir: String, t: Dictionary) -> Dictionary:
	var manifest: Dictionary = _read_json(bridge_dir.path_join("manifest.json"))
	if manifest.is_empty() or str(manifest.get("format", "")) != "puw-pkhex-bridge/1":
		return {"ok": false, "error": "no puw-pkhex-bridge/1 manifest.json in " + bridge_dir}
	var work: Dictionary = state.duplicate(true)
	var diff: Dictionary = {"format": "puw-pkhex-bridge-diff/1", "entries": [], "ignored_files": []}
	var applied: int = 0
	var refused: Array = []
	var unchanged: int = 0
	var known_files: Dictionary = {}
	var entries: Array = manifest.get("entries", [])
	for entry_v in entries:
		var entry: Dictionary = entry_v
		var slot: Dictionary = entry.get("slot", {})
		var label: String = _slot_label(slot)
		var file_name: String = str(entry.get("file", ""))
		known_files[file_name] = true
		var mon: Dictionary = _mon_at(work, slot)
		if mon.is_empty():
			refused.append({"slot": slot, "reason": "no mon at " + label})
			(diff["entries"] as Array).append({"slot": slot, "status": "refused", "reason": "no mon at slot"})
			continue
		if str(mon.get("mon_id", "")) != str(entry.get("mon_id", "")):
			refused.append({"slot": slot, "reason": "mon_id mismatch at " + label + " (save changed since export)"})
			(diff["entries"] as Array).append({"slot": slot, "status": "refused", "reason": "mon_id mismatch"})
			continue
		var path: String = bridge_dir.path_join(file_name)
		var bytes: PackedByteArray = _read_bytes(path)
		if bytes.is_empty():
			(diff["entries"] as Array).append({"slot": slot, "status": "missing_file", "file": file_name})
			continue
		if _sha256_hex(bytes) == str(entry.get("pk9_sha256", "")):
			unchanged += 1
			(diff["entries"] as Array).append({"slot": slot, "status": "unchanged", "file": file_name})
			continue
		var decoded: Dictionary = decode_pk9(bytes, t)
		if not bool(decoded.get("ok", false)):
			refused.append({"slot": slot, "reason": str(decoded.get("error", "decode failed"))})
			(diff["entries"] as Array).append({"slot": slot, "status": "refused", "reason": str(decoded.get("error", ""))})
			continue
		var sidecar: Dictionary = _read_json(bridge_dir.path_join(str(entry.get("sidecar", ""))))
		var merged: Dictionary = apply_pk9_to_mon(mon, decoded.get("fields", {}), sidecar, t)
		if not bool(merged.get("ok", false)):
			refused.append({"slot": slot, "reason": "; ".join(merged.get("errors", []))})
			(diff["entries"] as Array).append({"slot": slot, "status": "refused",
				"reason": "; ".join(merged.get("errors", [])), "notes": merged.get("notes", [])})
			continue
		_set_mon_at(work, slot, merged.get("mon", {}))
		_write_json(bridge_dir.path_join(str(entry.get("sidecar", ""))), merged.get("sidecar", {}))
		entry["pk9_sha256"] = _sha256_hex(bytes)
		applied += 1
		(diff["entries"] as Array).append({"slot": slot, "status": "applied", "file": file_name,
			"changes": merged.get("changes", []), "notes": merged.get("notes", [])})
	# .pk9 files the manifest does not know are ignored (v1 never
	# adopts new mons into a save).
	var dir: DirAccess = DirAccess.open(bridge_dir)
	if dir != null:
		dir.list_dir_begin()
		var name: String = dir.get_next()
		while not name.is_empty():
			if name.ends_with(".pk9") and not known_files.has(name):
				(diff["ignored_files"] as Array).append(name)
			name = dir.get_next()
		dir.list_dir_end()
	manifest["entries"] = entries
	_write_json(bridge_dir.path_join("manifest.json"), manifest)
	_write_json(bridge_dir.path_join("diff_report.json"), diff)
	return {"ok": true, "state": work, "diff": diff, "applied": applied,
		"refused": refused, "unchanged": unchanged}
