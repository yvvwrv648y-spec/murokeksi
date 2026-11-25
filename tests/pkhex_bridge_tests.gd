extends SceneTree
## PKHeX Bridge tests (code prep, 2026-11-24). Run:
##   godot --headless --script res://tests/pkhex_bridge_tests.gd
##
## Builds a real PUW save fixture with the project's own code
## (two CampaignFlow Oak grants -- one Pokemon, one Moemon; one
## PUWTeamBuilder difficulty-layer mon; one protagonist-shape
## record copied from data/riley_starter_team.json with Shadow
## stamps), round-trips it through PUWSaveManager, then:
## - exports the save to .pk9 files and checks structure,
##   checksums and decoded fields against the source mons;
## - edits one boxed mon's .pk9 bytes (an IV and a move), as a
##   PKHeX/PKHaX user would, and encrypts another mon's file
##   the way official tooling can store it;
## - imports and asserts exactly the edited changes landed,
##   every PUW-only field survived, mon_ids are unchanged, the
##   untouched mons' records are byte-identical, the caller's
##   state was never mutated, a second import is a no-op, and a
##   mon_id mismatch is refused whole.
## The exported files are also verified by an INDEPENDENT Python
## reader (work/pk9_verify.py) driven by run_tests.sh.

const BRIDGE_DIR: String = "res://bridge_out"
const BRIDGE_DIR2: String = "res://bridge_out2"

var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	if PUWPKHexBridge._deep_equal(actual, expected):
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label, "  expected=", expected, "  actual=", actual)


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


func _pool_entry(pool: Array, species_id: int) -> Dictionary:
	for entry_v in pool:
		var entry: Dictionary = entry_v
		if int(entry.get("species_id", 0)) == species_id:
			return entry
	return {}


func _encrypt_pk9(plain: PackedByteArray) -> PackedByteArray:
	# The forward direction of the PK9 crypto (PokeCrypto): shuffle
	# blocks into stored order, then crypt both regions. The
	# bridge's decrypted() must undo exactly this.
	var data: PackedByteArray = plain.duplicate()
	var ec: int = PUWPKHexBridge._u32(data, 0x00)
	var sv: int = (ec >> 13) & 31
	var order: Array = []
	for k in range(4):
		order.append(int(PUWPKHexBridge.BLOCK_POSITION[sv * 4 + k]))
	var shuffled: PackedByteArray = data.duplicate()
	for i in range(4):
		var src_off: int = 8 + i * PUWPKHexBridge.BLOCK_SIZE
		var dst_off: int = 8 + int(order[i]) * PUWPKHexBridge.BLOCK_SIZE
		for j in range(PUWPKHexBridge.BLOCK_SIZE):
			shuffled[dst_off + j] = data[src_off + j]
	data = shuffled
	PUWPKHexBridge._crypt_range(data, 8, 0x148, ec)
	PUWPKHexBridge._crypt_range(data, 0x148, PUWPKHexBridge.PK9_SIZE, ec)
	return data


func _init() -> void:
	print("== PKHeX Bridge test suite ==")
	var t: Dictionary = PUWPKHexBridge.load_tables()
	_check(not t.is_empty(), "bridge tables load")
	_check_eq((t.get("species_by_slug", {}) as Dictionary).size(), 1555, "tables carry 1555 species slugs (1518 canonical + 37 default-form aliases)")
	_check_eq(PUWPKHexBridge.exp_for_level(t, 0, 100), 1000000, "Medium Fast L100 = 1,000,000 exp")
	_check_eq(PUWPKHexBridge.exp_for_level(t, 3, 5), 135, "Medium Slow L5 = 135 exp")
	for dex in [1, 500, 917, 1000, 1025]:
		_check_eq(PUWPKHexBridge.internal_to_national(t, PUWPKHexBridge.national_to_internal(t, dex)), dex, "Gen 9 id round trip for dex %d" % dex)

	# ---------- fixture save, built with the project's own code
	var pool: Array = _read_json("res://campaign/oak_pool.json").get("pool", [])
	var builds: Dictionary = _read_json("res://campaign/oak_builds.json").get("builds", {})
	var grant_a: Dictionary = CampaignFlow.build_oak_grant(_pool_entry(pool, 72), "pokemon", builds.get("tentacool", {}))
	var grant_b: Dictionary = CampaignFlow.build_oak_grant(_pool_entry(pool, 172), "moemon", builds.get("pichu", {}))
	_check_eq(grant_a.get("family", ""), "PKDX", "Oak grant A is the Pokemon variant")
	_check_eq(grant_b.get("family", ""), "MDX", "Oak grant B is the Moemon variant")
	var tb: PUWTeamBuilder = PUWTeamBuilder.new()
	var diff_mon: Dictionary = {}
	for species_name in ["Tentacruel", "Gengar", "Dragonite", "Snorlax"]:
		diff_mon = tb.build_mon(species_name, 50, "singles")
		if not diff_mon.is_empty():
			break
	_check(not diff_mon.is_empty(), "difficulty-layer mon built by PUWTeamBuilder")
	var ext_mon: Dictionary = _read_json("res://tests/fixture_riley_tentacool.json")
	ext_mon["shadow_state"] = "shadow"
	ext_mon["heart_gauge"] = 40
	ext_mon["heart_gauge_max"] = 100
	ext_mon["heart_stage"] = 2
	ext_mon["formerly_shadow"] = false
	ext_mon["shadow_origin"] = "orre"
	_check_eq(int(ext_mon.get("species_id", 0)), 72, "extended fixture is the protagonist Tentacool record")

	var state: Dictionary = PUWSaveManager.build_state(
		[grant_a, diff_mon], [[grant_b, ext_mon]], {}, 5000, [], [], [], {}, {"name": "Riley"})
	state = PUWSaveManager.ensure_state_mon_ids(state)
	_check(PUWSaveManager.save_game(state), "fixture save writes via PUWSaveManager")
	var loaded: Dictionary = PUWSaveManager.load_game()
	_check_eq((loaded.get("party", []) as Array).size(), 2, "loaded save has 2 party mons")
	_check_eq(((loaded.get("boxes", []) as Array)[0] as Array).size(), 2, "loaded save has 2 boxed mons")
	var orig: Dictionary = loaded.duplicate(true)
	var orig_party: Array = orig.get("party", [])
	var orig_box: Array = (orig.get("boxes", []) as Array)[0]
	for mon_v in [orig_party[0], orig_party[1], orig_box[0], orig_box[1]]:
		var mon: Dictionary = mon_v
		_check(not str(mon.get("mon_id", "")).is_empty(), "fixture mon carries a mon_id (%s)" % str(mon.get("species_slug", "?")))

	# ---------- export
	var bridge_abs: String = ProjectSettings.globalize_path(BRIDGE_DIR)
	var exported: Dictionary = PUWPKHexBridge.export_state(loaded, bridge_abs, t)
	_check(bool(exported.get("ok", false)), "export_state runs")
	_check_eq(int(exported.get("exported", 0)), 4, "4 mons exported")
	_check_eq((exported.get("refused", []) as Array).size(), 0, "no export refusals")
	var manifest: Dictionary = PUWPKHexBridge._read_json(bridge_abs.path_join("manifest.json"))
	var entries: Array = manifest.get("entries", [])
	_check_eq(entries.size(), 4, "manifest lists 4 entries")
	var expected: Dictionary = {}
	var source_mons: Array = [orig_party[0], orig_party[1], orig_box[0], orig_box[1]]
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var mon: Dictionary = source_mons[i]
		_check_eq(str(entry.get("mon_id", "")), str(mon.get("mon_id", "")), "manifest entry %d mon_id matches the save" % i)
		var bytes: PackedByteArray = PUWPKHexBridge._read_bytes(bridge_abs.path_join(str(entry.get("file", ""))))
		_check_eq(bytes.size(), PUWPKHexBridge.PK9_SIZE, "pk9 %d is 344 bytes" % i)
		_check(PUWPKHexBridge.checksum_valid(bytes), "pk9 %d checksum valid" % i)
		var decoded: Dictionary = PUWPKHexBridge.decode_pk9(bytes, t)
		_check(bool(decoded.get("ok", false)), "pk9 %d decodes" % i)
		var fields: Dictionary = decoded.get("fields", {})
		_check_eq(int(fields.get("party_level", 0)), int(mon.get("level", 0)), "pk9 %d level matches" % i)
		var move_ids: Array = []
		for pm_v in fields.get("moves", []):
			var pm: Dictionary = pm_v
			move_ids.append(int(pm.get("id", 0)))
		expected[str(entry.get("file", ""))] = {
			"species_internal": PUWPKHexBridge.national_to_internal(t, int(PUWPKHexBridge.resolve_species(t, mon).get("dex", 0))),
			"move_ids": move_ids,
		}
	# The extended record's Tera designation lives only in
	# gimmick_assignment: export must surface it as TeraTypeOriginal.
	var ext_entry: Dictionary = entries[3]
	var ext_bytes: PackedByteArray = PUWPKHexBridge._read_bytes(bridge_abs.path_join(str(ext_entry.get("file", ""))))
	var ext_fields: Dictionary = PUWPKHexBridge.decode_pk9(ext_bytes, t).get("fields", {})
	_check_eq(int(ext_fields.get("tera_original", -1)), 2, "extended mon exports Tera Flying from gimmick_assignment")
	_check_eq(int(ext_fields.get("dex", 0)), 72, "extended mon exports as Tentacool (dex 72)")
	PUWPKHexBridge._write_json(bridge_abs.path_join("expected.json"), expected)

	# ---------- export refusals (never write a corrupt/lossy file)
	var bad_species: Dictionary = PUWPKHexBridge.encode_mon({"species_slug": "missingno", "level": 5, "moves": []}, {"ot_name": "Riley", "tid16": 1, "sid16": 2}, t)
	_check(not bool(bad_species.get("ok", true)), "unknown species refused at encode")
	var bad_move: Dictionary = PUWPKHexBridge.encode_mon({"species_slug": "tentacool", "level": 5, "moves": ["Definitely Not A Move"]}, {"ot_name": "Riley", "tid16": 1, "sid16": 2}, t)
	_check(not bool(bad_move.get("ok", true)), "unmapped move refused at encode")
	var bad_item: Dictionary = PUWPKHexBridge.encode_mon({"species_slug": "tentacool", "level": 5, "moves": [], "held_item": "Riley Plush"}, {"ot_name": "Riley", "tid16": 1, "sid16": 2}, t)
	_check(not bool(bad_item.get("ok", true)), "unmapped held item refused at encode")
	var truncated: Dictionary = PUWPKHexBridge.decode_pk9(PackedByteArray().slice(0, 0), t)
	_check(not bool(truncated.get("ok", true)), "empty file refused at decode")
	var corrupt: PackedByteArray = ext_bytes.duplicate()
	corrupt[0x30] = (int(corrupt[0x30]) + 1) % 256
	_check(not bool(PUWPKHexBridge.decode_pk9(corrupt, t).get("ok", true)), "checksum-corrupt file refused at decode")

	# ---------- edit one .pk9 the way PKHeX would (IV + move),
	# ---------- encrypt another the way official tooling can
	var edited: PackedByteArray = ext_bytes.duplicate()
	var old_iv32: int = PUWPKHexBridge._u32(edited, 0x8C)
	PUWPKHexBridge._put_u32(edited, 0x8C, (old_iv32 & ~0x1F) | 7) # HP IV 31 -> 7
	var ice_beam_id: int = int((t.get("moves_by_slug", {}) as Dictionary).get("icebeam", {}).get("id", 0))
	_check(ice_beam_id > 0, "Ice Beam has a Gen 9 move id")
	PUWPKHexBridge._put_u16(edited, 0x72 + 2, ice_beam_id) # move slot 2
	edited[0x7A + 1] = 10 # PP = Ice Beam base PP
	edited = PUWPKHexBridge.refresh_checksum(edited)
	_check(PUWPKHexBridge._write_bytes(bridge_abs.path_join(str(ext_entry.get("file", ""))), edited), "edited pk9 written back")

	var grant_entry: Dictionary = entries[0]
	var grant_path: String = bridge_abs.path_join(str(grant_entry.get("file", "")))
	var grant_plain: PackedByteArray = PUWPKHexBridge._read_bytes(grant_path)
	var grant_encrypted: PackedByteArray = _encrypt_pk9(grant_plain)
	_check_eq(PUWPKHexBridge.decrypted(grant_encrypted), grant_plain, "bridge decrypts an encrypted pk9 back to the plain bytes")
	_check(PUWPKHexBridge._write_bytes(grant_path, grant_encrypted), "encrypted pk9 written back")

	# ---------- import
	var imported: Dictionary = PUWPKHexBridge.import_state(loaded, bridge_abs, t)
	_check(bool(imported.get("ok", false)), "import_state runs")
	_check_eq(int(imported.get("applied", 0)), 2, "2 entries applied (edited + encrypted)")
	_check_eq(int(imported.get("unchanged", 0)), 2, "2 entries unchanged")
	_check_eq((imported.get("refused", []) as Array).size(), 0, "no import refusals")
	var merged: Dictionary = imported.get("state", {})
	var m_party: Array = merged.get("party", [])
	var m_box: Array = (merged.get("boxes", []) as Array)[0]

	# Edited mon: exactly the edited changes, PUW-only fields intact.
	var m_ext: Dictionary = m_box[1]
	var o_ext: Dictionary = orig_box[1]
	_check_eq(int((m_ext.get("ivs", {}) as Dictionary).get("hp", -1)), 7, "edited HP IV landed (31 -> 7)")
	_check_eq(str(((m_ext.get("moves", []) as Array)[1] as Dictionary).get("name", "")), "icebeam", "edited move landed in the record's own slug style")
	_check_eq(int(((m_ext.get("moves", []) as Array)[1] as Dictionary).get("max_pp", 0)), 10, "edited move PP Ups recomputed (max PP 10)")
	_check_eq(int(m_ext.get("max_hp", 0)), 22, "max HP recomputed for the new IV (23 -> 22)")
	_check_eq(int(m_ext.get("hp", 0)), 22, "current HP clamped to the new max")
	_check_eq(str(m_ext.get("mon_id", "")), str(o_ext.get("mon_id", "")), "edited mon keeps its mon_id")
	_check_eq(str(m_ext.get("shadow_state", "")), "shadow", "shadow_state preserved")
	_check_eq(int(m_ext.get("heart_gauge", -1)), 40, "heart_gauge preserved")
	_check_eq(int(m_ext.get("heart_stage", -1)), 2, "heart_stage preserved")
	_check_eq(m_ext.get("formerly_shadow", true), false, "formerly_shadow preserved")
	_check(PUWPKHexBridge._deep_equal(m_ext.get("gimmick_assignment", {}), o_ext.get("gimmick_assignment", {})), "gimmick_assignment (Tera designation) preserved")
	_check_eq(str(m_ext.get("held_item", "")), "eviolite", "held item preserved")
	_check_eq(str(m_ext.get("ability", "")), "clear-body", "ability preserved in pokeapi style")
	for key_v in o_ext.keys():
		var key: String = str(key_v)
		if ["ivs", "moves", "exp", "max_hp", "hp"].has(key):
			continue
		_check(PUWPKHexBridge._deep_equal(m_ext.get(key), o_ext.get(key)), "edited mon field unchanged: " + key)

	# Encrypted mon: every original field intact (exp may be added).
	var m_grant: Dictionary = m_party[0]
	var o_grant: Dictionary = orig_party[0]
	for key_v in o_grant.keys():
		var key: String = str(key_v)
		_check(PUWPKHexBridge._deep_equal(m_grant.get(key), o_grant.get(key)), "encrypted mon field unchanged: " + key)
	_check_eq(str(m_grant.get("mon_id", "")), str(o_grant.get("mon_id", "")), "encrypted mon keeps its mon_id")

	# Untouched mons: byte-identical records.
	_check_eq(JSON.stringify(m_party[1]), JSON.stringify(orig_party[1]), "untouched difficulty mon record byte-identical")
	_check_eq(JSON.stringify(m_box[0]), JSON.stringify(orig_box[0]), "untouched Moemon grant record byte-identical")

	# The caller's state was never mutated.
	_check_eq(int(((loaded.get("boxes", []) as Array)[0][1].get("ivs", {}) as Dictionary).get("hp", -1)), 31, "input state untouched by import")

	# The diff report names the changes.
	var diff: Dictionary = PUWPKHexBridge._read_json(bridge_abs.path_join("diff_report.json"))
	_check_eq(str(diff.get("format", "")), "puw-pkhex-bridge-diff/1", "diff report written")
	var saw_ivs_change: bool = false
	for entry_v in diff.get("entries", []):
		var entry: Dictionary = entry_v
		for change_v in entry.get("changes", []):
			var change: Dictionary = change_v
			if str(change.get("field", "")) == "ivs":
				saw_ivs_change = true
	_check(saw_ivs_change, "diff report logs the IV change")

	# ---------- second import is a no-op
	var again: Dictionary = PUWPKHexBridge.import_state(merged, bridge_abs, t)
	_check_eq(int(again.get("applied", -1)), 0, "second import applies nothing")
	_check_eq(int(again.get("unchanged", -1)), 4, "second import sees all 4 unchanged")

	# ---------- mon_id mismatch is refused whole
	var bridge2_abs: String = ProjectSettings.globalize_path(BRIDGE_DIR2)
	var exported2: Dictionary = PUWPKHexBridge.export_state(merged, bridge2_abs, t)
	_check_eq(int(exported2.get("exported", 0)), 4, "second export writes 4 mons")
	var manifest2: Dictionary = PUWPKHexBridge._read_json(bridge2_abs.path_join("manifest.json"))
	var entries2: Array = manifest2.get("entries", [])
	# Expectations for the independent verifier: bridge_out2 is a
	# pristine export (nothing edits it afterwards), so all four
	# files must verify structurally there. bridge_out itself is
	# left in its post-test state on purpose (one file encrypted,
	# one edited) and is only reported, not gated.
	var expected2: Dictionary = {}
	var merged_mons: Array = [m_party[0], m_party[1], m_box[0], m_box[1]]
	for i in range(entries2.size()):
		var entry2: Dictionary = entries2[i]
		var mon2: Dictionary = merged_mons[i]
		var bytes2: PackedByteArray = PUWPKHexBridge._read_bytes(bridge2_abs.path_join(str(entry2.get("file", ""))))
		var fields2: Dictionary = PUWPKHexBridge.decode_pk9(bytes2, t).get("fields", {})
		var move_ids2: Array = []
		for pm2_v in fields2.get("moves", []):
			var pm2: Dictionary = pm2_v
			move_ids2.append(int(pm2.get("id", 0)))
		expected2[str(entry2.get("file", ""))] = {
			"species_internal": PUWPKHexBridge.national_to_internal(t, int(PUWPKHexBridge.resolve_species(t, mon2).get("dex", 0))),
			"move_ids": move_ids2,
		}
	PUWPKHexBridge._write_json(bridge2_abs.path_join("expected.json"), expected2)
	(entries2[0] as Dictionary)["mon_id"] = "puw-000000-deadbeef"
	PUWPKHexBridge._write_json(bridge2_abs.path_join("manifest.json"), manifest2)
	var refused_import: Dictionary = PUWPKHexBridge.import_state(merged, bridge2_abs, t)
	_check_eq((refused_import.get("refused", []) as Array).size(), 1, "mon_id mismatch refused")
	_check_eq(int(refused_import.get("applied", -1)), 0, "nothing applied in the mismatch import")
	_check_eq(JSON.stringify((refused_import.get("state", {}) as Dictionary).get("party", [])), JSON.stringify(merged.get("party", [])), "mismatch import leaves the party untouched")

	print("== PKHeX Bridge: %d passed, %d failed ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
