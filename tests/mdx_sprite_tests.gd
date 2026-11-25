extends SceneTree
## MDX sprite binding tests (extraction integration build,
## 2026-11-23). Run: godot --headless --script res://tests/mdx_sprite_tests.gd
##
## Proves the extraction build's MDX binding is real:
## (1) data/mdx_sprites_index.json carries all 1,519 slots;
## (2) every slot whose battle status is "bound_local_static"
##     names four view files that exist in the project, and the
##     bound count matches the index's own counts block;
## (3) every slot with a bound follower sheet names a file that
##     exists; every other slot is honestly "missing";
## (4) every bound party icon file exists;
## (5) data/mdx_sprite_audit.json carries per-slot ROM pointers
##     for all 1,519 slots, with the audited uniqueness totals
##     (1,393 front / 1,389 back unique) and the confirmed
##     fallback flag on slot 1378 (Pecharunt);
## (6) PUWMDXData serves the same truth through its accessors.
##
## Integration build 2 (2026-11-23): bench round 1's P3
## corrections are applied to the audit -- the canonical-slot
## shared flags are fixed (flag-filtered shared counts now read
## the true 148 front / 156 back, asserted below), and form
## names are resolved in part: 365 of 449 form slots carry a
## real form_name (263 grounded by bench round 1 in the
## project's own Showdown variant lists + 102 named in Neon's
## inventory v2), 84 keep an honest placeholder with a recorded
## reason (asserted below).
##
## Consolidation build (2026-11-23): 645 of the 717 locally
## bound slots gain animated Moemon battle fronts from the
## Moemon Black 2 v1.1 (Kurisu) kits (status
## "bound_local_animated"): front / front_shiny point at the
## kit keyframes in art/mdx/battle_animated/ and motion_data
## carries the preserved BW2 CTRL block. Backs are UNCHANGED
## MoeMMO Moemon backs (the ROM kits' backs are vanilla BW2
## Pokemon backs and were deliberately not bound) -- asserted
## below. The 72 uncovered Gen 6-8 slots keep
## "bound_local_static".

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _init() -> void:
	var index: Dictionary = _read_json("res://data/mdx_sprites_index.json")
	_check("index_loads", not index.is_empty())
	var slots_value: Variant = index.get("slots", [])
	var slots: Array = slots_value if slots_value is Array else []
	_check("index_slots_1519", slots.size() == 1519)
	var counts_value: Variant = index.get("counts", {})
	var counts: Dictionary = counts_value if counts_value is Dictionary else {}

	var battle_bound: int = 0
	var battle_files_ok: int = 0
	var battle_animated: int = 0
	var animated_files_ok: int = 0
	var animated_ctrl_ok: int = 0
	var animated_backs_ok: int = 0
	var follower_bound: int = 0
	var follower_files_ok: int = 0
	var follower_missing: int = 0
	var icons_bound: int = 0
	var icons_ok: int = 0
	for slot_value: Variant in slots:
		if not (slot_value is Dictionary):
			continue
		var entry: Dictionary = slot_value
		var battle_value: Variant = entry.get("battle", {})
		var battle: Dictionary = battle_value if battle_value is Dictionary else {}
		if str(battle.get("status", "")) == "bound_local_static":
			battle_bound += 1
			var views_value: Variant = battle.get("views", {})
			var views: Dictionary = views_value if views_value is Dictionary else {}
			var all_exist: bool = views.size() == 4
			for view_value: Variant in views.values():
				if not FileAccess.file_exists("res://" + str(view_value)):
					all_exist = false
			if all_exist:
				battle_files_ok += 1
		if str(battle.get("status", "")) == "bound_local_animated":
			battle_animated += 1
			var aviews_value: Variant = battle.get("views", {})
			var aviews: Dictionary = aviews_value if aviews_value is Dictionary else {}
			var front_ok: bool = str(aviews.get("front", "")).begins_with("art/mdx/battle_animated/") and FileAccess.file_exists("res://" + str(aviews.get("front", "")))
			var front_shiny_ok: bool = str(aviews.get("front_shiny", "")).begins_with("art/mdx/battle_animated/") and FileAccess.file_exists("res://" + str(aviews.get("front_shiny", "")))
			if front_ok and front_shiny_ok:
				animated_files_ok += 1
			var motion_value: Variant = battle.get("motion_data", {})
			var motion_data: Dictionary = motion_value if motion_value is Dictionary else {}
			if str(motion_data.get("ctrl_hex", "")) != "" and str(battle.get("front_source", "")) == "moemon-black2-v1.1-kit":
				animated_ctrl_ok += 1
			var back_ok: bool = str(aviews.get("back", "")).begins_with("art/mdx/battle/") and FileAccess.file_exists("res://" + str(aviews.get("back", "")))
			var back_shiny_ok: bool = str(aviews.get("back_shiny", "")).begins_with("art/mdx/battle/") and FileAccess.file_exists("res://" + str(aviews.get("back_shiny", "")))
			if back_ok and back_shiny_ok:
				animated_backs_ok += 1
		var follower_value: Variant = entry.get("follower", {})
		var follower: Dictionary = follower_value if follower_value is Dictionary else {}
		if str(follower.get("status", "")) == "bound_local_animated":
			follower_bound += 1
			if FileAccess.file_exists("res://" + str(follower.get("sheet", ""))):
				follower_files_ok += 1
		elif str(follower.get("status", "")) == "missing":
			follower_missing += 1
		var icon_value: Variant = entry.get("party_icon", "")
		if icon_value is String and str(icon_value) != "":
			icons_bound += 1
			if FileAccess.file_exists("res://" + str(icon_value)):
				icons_ok += 1

	_check("battle_bound_count_matches_index", battle_bound == int(counts.get("battle_bound_local_static", -1)))
	_check("battle_bound_files_all_exist", battle_files_ok == battle_bound and battle_bound > 0)
	_check("battle_animated_count_matches_index", battle_animated == int(counts.get("battle_bound_local_animated_front", -1)))
	_check("battle_animated_711", battle_animated == 711)  # build 6: 645 + 66 forme-kit slots (Stage 2C)
	_check("battle_animated_files_all_exist", animated_files_ok == battle_animated and battle_animated > 0)
	_check("battle_animated_motion_data_present", animated_ctrl_ok == battle_animated)
	_check("battle_animated_backs_unchanged_moemmo", animated_backs_ok == battle_animated)
	_check("follower_bound_count_matches_index", follower_bound == int(counts.get("follower_bound_local_animated", -1)))
	_check("follower_bound_files_all_exist", follower_files_ok == follower_bound and follower_bound > 0)
	_check("follower_missing_honest", follower_missing == int(counts.get("follower_missing", -2)))
	_check("party_icons_all_exist", icons_ok == icons_bound and icons_bound > 0)

	var audit: Dictionary = _read_json("res://data/mdx_sprite_audit.json")
	_check("audit_loads", not audit.is_empty())
	var totals_value: Variant = audit.get("totals", {})
	var totals: Dictionary = totals_value if totals_value is Dictionary else {}
	_check("audit_front_unique_1393", int(totals.get("front_ptr_unique", -1)) == 1393)
	_check("audit_back_unique_1389", int(totals.get("back_ptr_unique", -1)) == 1389)
	var audit_slots_value: Variant = audit.get("slots", [])
	var audit_slots: Array = audit_slots_value if audit_slots_value is Array else []
	_check("audit_slots_1519", audit_slots.size() == 1519)
	var pointers_ok: int = 0
	var fallback_1378: bool = false
	for audit_value: Variant in audit_slots:
		if not (audit_value is Dictionary):
			continue
		var rec: Dictionary = audit_value
		var quetzal_value: Variant = rec.get("quetzal", {})
		var quetzal: Dictionary = quetzal_value if quetzal_value is Dictionary else {}
		if str(quetzal.get("front_rom_ptr", "")).begins_with("0x") and str(quetzal.get("back_rom_ptr", "")).begins_with("0x"):
			pointers_ok += 1
		if int(rec.get("slot", 0)) == 1378 and str(rec.get("fallback_flag", "")) == "confirmed_standard_pokemon_sprite":
			fallback_1378 = true
	_check("audit_pointers_all_slots", pointers_ok == 1519)
	_check("audit_fallback_1378_flagged", fallback_1378)
	# Integration build 2: bench round 1 P3 corrections.
	_check("audit_front_shared_148", int(totals.get("front_ptr_shared", -1)) == 148)
	_check("audit_back_shared_156", int(totals.get("back_ptr_shared", -1)) == 156)
	var shared_f: int = 0
	var shared_b: int = 0
	var forms_named: int = 0
	var forms_placeholder: int = 0
	for audit_value2: Variant in audit_slots:
		if not (audit_value2 is Dictionary):
			continue
		var rec2: Dictionary = audit_value2
		var q2_value: Variant = rec2.get("quetzal", {})
		var q2: Dictionary = q2_value if q2_value is Dictionary else {}
		if bool(q2.get("front_ptr_shared", false)):
			shared_f += 1
		if bool(q2.get("back_ptr_shared", false)):
			shared_b += 1
		if bool(rec2.get("is_form_or_variant", false)):
			var fn2: Variant = rec2.get("form_name", "")
			if fn2 is String and str(fn2) != "":
				forms_named += 1
			elif str(rec2.get("form_name_status", "")) == "placeholder_kept_bench_round1" and str(rec2.get("form_name_reason", "")) != "":
				forms_placeholder += 1
	_check("audit_shared_flags_recount_148_156", shared_f == 148 and shared_b == 156)
	_check("audit_form_names_365_named_84_placeholder", forms_named == 365 and forms_placeholder == 84)

	var mdx: PUWMDXData = PUWMDXData.new()
	_check("mdxdata_index_slots_1519", mdx.load_sprite_index() == 1519)
	var bulbasaur_battle: Dictionary = mdx.battle_sprite_for_slot(1)
	_check("mdxdata_slot1_battle_bound", str(bulbasaur_battle.get("status", "")) == "bound_local_animated")
	var slot_1519: Dictionary = mdx.battle_sprite_for_slot(1519)
	_check("mdxdata_slot1519_status_known", str(slot_1519.get("status", "")) != "")
	_check("mdxdata_follower_slot1_bound", str(mdx.follower_sheet_for_slot(1).get("status", "")) == "bound_local_animated")
	_check("mdxdata_icon_slot1_exists", FileAccess.file_exists("res://" + mdx.party_icon_for_slot(1)))

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
