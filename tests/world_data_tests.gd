extends SceneTree
## World data tests for Pokemon Ultimate World.
## Run: godot --headless --script world_data_tests.gd
## (with the pack's data/ folder available at res://data/)
##
## These tests run the campaign flow rules against the REAL data
## extracted from pret/pokered: trainer parties, gym leaders, the
## Elite Four sequence, the rival, and the dialogue database.
## No fixture ids are used for the badge or gauntlet runs.

var _passed: int = 0
var _failed: int = 0


func _load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _party_ok(party: Array) -> bool:
	if party.size() < 1 or party.size() > 6:
		return false
	for mon_v in party:
		var mon: Dictionary = mon_v
		var level: int = int(mon.get("level", 0))
		if level < 1 or level > 100:
			return false
		if String(mon.get("species", "")).is_empty():
			return false
	return true


func _init() -> void:
	print("PUW world data tests — starting.")

	# --- trainers.json structure ---
	var trainers_v: Variant = _load_json("res://data/trainers.json")
	_check("trainers_loaded", trainers_v is Dictionary)
	if not (trainers_v is Dictionary):
		_finish()
		return
	var trainers: Dictionary = trainers_v
	var classes: Dictionary = trainers.get("classes", {})
	_check("trainer_classes_present", classes.size() >= 40)
	var total_parties: int = 0
	var all_parties_ok: bool = true
	# These two classes are "; none" in parties.asm — zero parties is
	# the real data for them, verified against the source.
	# Build 6: POKEMON_PROF joins the list — its Johto source
	# group (PokemonProfGroup) carries no parties and zero
	# placements reference it; the class record is source data.
	var empty_allowed: Array = ["UNUSED_JUGGLER", "CHIEF", "POKEMON_PROF"]
	for class_id_v in classes.keys():
		var class_id: String = class_id_v
		var entry: Dictionary = classes[class_id]
		var parties: Array = entry.get("parties", [])
		if parties.is_empty() and not empty_allowed.has(class_id):
			all_parties_ok = false
		for party_v in parties:
			var party: Array = party_v
			total_parties += 1
			if not _party_ok(party):
				all_parties_ok = false
	print("INFO: trainer classes=", classes.size(), " total parties=", total_parties)
	_check("all_trainer_parties_valid", all_parties_ok and total_parties > 0)

	# --- placements join cleanly against classes/parties ---
	var placements: Array = trainers.get("placements", [])
	_check("placements_present", placements.size() > 0)
	var placements_ok: bool = true
	for p_v in placements:
		var p: Dictionary = p_v
		var cls: String = String(p.get("class", ""))
		if not classes.has(cls):
			placements_ok = false
			continue
		var parties_for_class: Array = classes[cls].get("parties", [])
		var pidx: int = int(p.get("party_index", 0))
		if pidx < 1 or pidx > parties_for_class.size():
			placements_ok = false
	print("INFO: placements=", placements.size())
	_check("placements_reference_valid_parties", placements_ok)

	# --- gym leaders: real badges through the real gate ---
	var gyms_v: Variant = _load_json("res://data/gym_leaders.json")
	_check("gym_leaders_loaded", gyms_v is Array)
	if not (gyms_v is Array):
		_finish()
		return
	var gyms: Array = gyms_v
	_check("eight_gym_leaders", gyms.size() == 8)
	var badge_ids: Array = []
	var badges_from_data: bool = true
	var gym_parties_ok: bool = true
	for g_v in gyms:
		var g: Dictionary = g_v
		var badge: String = String(g.get("badge", ""))
		if badge.is_empty():
			badges_from_data = false
			badge = String(g.get("class", ""))
		badge_ids.append(badge)
		if not _party_ok(g.get("party", [])):
			gym_parties_ok = false
	_check("gym_badges_come_from_data", badges_from_data)
	_check("gym_parties_valid", gym_parties_ok)
	var unique_badges: Dictionary = {}
	for b_v in badge_ids:
		unique_badges[b_v] = true
	_check("gym_badges_unique", unique_badges.size() == 8)

	var prog: Dictionary = {}
	for i in 7:
		GymProgression.award_badge(prog, String(badge_ids[i]))
	_check("e4_locked_at_seven_real_badges", not GymProgression.can_challenge_elite_four(prog))
	GymProgression.award_badge(prog, String(badge_ids[7]))
	_check("e4_open_at_eight_real_badges", GymProgression.can_challenge_elite_four(prog))
	_check("duplicate_real_badge_refused", not GymProgression.award_badge(prog, String(badge_ids[0])))

	# --- elite four: real sequence through the real gauntlet ---
	var e4_v: Variant = _load_json("res://data/elite_four.json")
	_check("elite_four_loaded", e4_v is Dictionary)
	if not (e4_v is Dictionary):
		_finish()
		return
	var e4: Dictionary = e4_v
	var sequence: Array = e4.get("sequence", [])
	_check("e4_sequence_has_four_members", sequence.size() == 4)
	var members: Dictionary = e4.get("members", {})
	var member_parties_ok: bool = true
	for m_v in sequence:
		var mid: String = m_v
		if not members.has(mid):
			member_parties_ok = false
			continue
		var mparties: Array = members[mid].get("parties", [])
		if mparties.is_empty():
			member_parties_ok = false
			continue
		# elite_four.json wraps each party: {"party_index": n, "party": [...]}
		var first_party: Array = []
		var first_v: Variant = mparties[0]
		if first_v is Dictionary and (first_v as Dictionary).has("party"):
			first_party = (first_v as Dictionary)["party"]
		elif first_v is Array:
			first_party = first_v
		if not _party_ok(first_party):
			member_parties_ok = false
	_check("e4_member_parties_valid", member_parties_ok)
	var champion: Dictionary = e4.get("champion", {})
	var champion_class: String = String(champion.get("class", ""))
	_check("champion_present", not champion_class.is_empty() and champion.get("parties", []).size() > 0)

	var run_sequence: Array = sequence.duplicate()
	run_sequence.append(champion_class)
	var champ: Dictionary = {}
	for b_v in badge_ids:
		GymProgression.award_badge(champ, String(b_v))
	champ["party"] = [{"species": "BULBASAUR", "level": 5}]
	_check("real_gauntlet_starts", EliteFourFlow.start_gauntlet(champ, run_sequence))
	_check("real_gauntlet_first_opponent", EliteFourFlow.current_opponent(champ) == String(sequence[0]))
	var wins_ok: bool = true
	for step in run_sequence.size():
		if not EliteFourFlow.record_win(champ):
			wins_ok = false
	_check("real_gauntlet_all_wins_recorded", wins_ok)
	var flags: Dictionary = champ.get("flags", {})
	_check("real_gauntlet_sets_champion_flag", bool(flags.get("champion", false)))
	_check("real_gauntlet_hall_of_fame_entry", champ.get("hall_of_fame", []).size() == 1)

	# --- rival data ---
	var rival_v: Variant = _load_json("res://data/rival.json")
	_check("rival_loaded", rival_v is Dictionary and not (rival_v as Dictionary).is_empty())
	if rival_v is Dictionary:
		var rival: Dictionary = rival_v
		var stages: Dictionary = rival.get("stages", {})
		var rival_parties: int = 0
		for stage_v in stages.values():
			if stage_v is Dictionary:
				var sp: Array = (stage_v as Dictionary).get("parties", [])
				rival_parties += sp.size()
		print("INFO: rival stages=", stages.size(), " rival parties=", rival_parties)
		_check("rival_parties_present", rival_parties > 0)

	# --- dialogue database integrity ---
	var dlg_v: Variant = _load_json("res://data/dialogue_database.json")
	_check("dialogue_loaded", dlg_v is Dictionary)
	if dlg_v is Dictionary:
		var dlg: Dictionary = dlg_v
		var groups: Dictionary = dlg.get("groups", {})
		var sum_entries: int = 0
		var groups_cited: bool = true
		for gname_v in groups.keys():
			var grp: Dictionary = groups[gname_v]
			sum_entries += (grp.get("entries", {}) as Dictionary).size()
			# The two _shared_text_* pools are the bank builder's
			# shared-text groups (signs/system lines drawn from
			# several map files); the bank's top-level source
			# citation covers them — no per-group file exists.
			if String(grp.get("source_file", "")).is_empty() \
					and not String(gname_v).begins_with("_shared_text_"):
				groups_cited = false
		print("INFO: dialogue groups=", groups.size(), " entries=", sum_entries)
		_check("dialogue_groups_present", groups.size() >= 200)
		_check("dialogue_total_matches_groups", int(dlg.get("total_entries", -1)) == sum_entries)
		_check("dialogue_groups_cite_sources", groups_cited)
		var pallet: Dictionary = groups.get("PalletTown", {})
		var pallet_entries: Dictionary = pallet.get("entries", {})
		_check("dialogue_pallet_town_girl_text", String(pallet_entries.get("_PalletTownGirlText", "")).contains("raising"))

	# --- wild encounter data integrity (closing build) ---
	# Real tables from pret/pokered (Kanto) and pret/pokefirered
	# (Sevii): every entry cites its source, rates are bytes, slot
	# lists match the engines' fixed slot counts, and Route 1
	# matches data/wild/maps/Route1.asm exactly (grass rate 25,
	# first slot level 3 PIDGEY, water rate 0).
	var wild_v: Variant = _load_json("res://data/wild_encounters.json")
	_check("wild_loaded", wild_v is Dictionary)
	if wild_v is Dictionary:
		var wild: Dictionary = wild_v
		var wmaps: Dictionary = wild.get("maps", {})
		var counts: Dictionary = wild.get("counts", {})
		_check("wild_counts_match_maps", int(counts.get("kanto_maps_with_wild_table", -1)) + int(counts.get("sevii_maps_with_wild_table", -1)) == wmaps.size())
		var all_cited: bool = true
		var rates_ok: bool = true
		var slots_ok: bool = true
		var kanto_entries: int = 0
		var sevii_entries: int = 0
		for const_v in wmaps.keys():
			var entry: Dictionary = wmaps[const_v]
			if String(entry.get("source_file", "")).is_empty():
				all_cited = false
			if String(entry.get("region", "")) == "kanto":
				kanto_entries += 1
			elif String(entry.get("region", "")) == "sevii":
				sevii_entries += 1
			var blocks: Array = []
			_collect_wild_blocks(entry, blocks)
			for block_v in blocks:
				var block: Dictionary = block_v
				var rate: int = int(block.get("rate", -1))
				var is_fishing: bool = String(block.get("_puw_block_key", "")) == "fishing"
				# Gen-1 fishing rolls on a 256 denominator (source
				# behavior, R-1 data) — a byte everywhere else.
				if rate < 0 or rate > 255 and not (is_fishing and rate == 256):
					rates_ok = false
				for key_v in block.keys():
					var key: String = String(key_v)
					if key.begins_with("slots"):
						var slots: Array = block.get(key, [])
						# Gen-1 fishing tables hold 3-5 slots; the
						# land/water engines hold 5/10/12.
						if not [0, 5, 10, 12].has(slots.size()) \
								and not (is_fishing and [3, 4, 5].has(slots.size())):
							slots_ok = false
		_check("wild_every_entry_cites_source", all_cited)
		_check("wild_rates_are_bytes", rates_ok)
		_check("wild_slot_counts_match_engines", slots_ok)
		_check("wild_kanto_entries_present", kanto_entries >= 50)
		_check("wild_sevii_entries_present", sevii_entries >= 50)
		var route1: Dictionary = wmaps.get("ROUTE_1", {})
		var r1_grass: Dictionary = route1.get("grass", {})
		var r1_slots: Array = r1_grass.get("slots", [])
		_check("wild_route1_grass_rate_25", int(r1_grass.get("rate", -1)) == 25)
		_check("wild_route1_ten_slots", r1_slots.size() == 10)
		if r1_slots.size() > 0:
			var slot0: Dictionary = r1_slots[0]
			_check("wild_route1_slot0_pidgey", String(slot0.get("species", "")) == "PIDGEY" and int(slot0.get("level", -1)) == 3)
		var r1_water: Dictionary = route1.get("water", {})
		_check("wild_route1_water_rate_0", int(r1_water.get("rate", -1)) == 0)

	_finish()


func _collect_wild_blocks(entry: Dictionary, out: Array) -> void:
	for key_v in entry.keys():
		var value: Variant = entry[key_v]
		if not (value is Dictionary):
			continue
		var sub: Dictionary = value
		if sub.has("rate"):
			var marked: Dictionary = sub.duplicate()
			marked["_puw_block_key"] = String(key_v)
			out.append(marked)
		elif String(key_v) == "firered" or String(key_v) == "leafgreen":
			_collect_wild_blocks(sub, out)


func _finish() -> void:
	print("WORLD DATA TESTS: passed=", _passed, " failed=", _failed)
	quit(0 if _failed == 0 else 1)
