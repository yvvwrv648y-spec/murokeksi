extends SceneTree
## Sevii access + story remainders: the ferry network (pass
## branches, destination matrix, scripted transfers), the pass
## grants (Bill's invitation -> MeetCelio's Tri-Pass; the events
## lane's Ruby-delivery exchange -> Rainbow Pass), the decoded
## Sevii labels (GideonPostBattle in the patched reclaim script,
## FoundARuby in the patched pickup, the whole MeetCelio scene),
## and the Marowak ghost beat with the real PUWItemGates Silph
## Scope check. Played on the real machinery: PUWEventRunner +
## PUWCampaignStitch state + the stage-4 PUWSpawner over the
## merged banks (restored Sevii bank + this prep's additions) +
## PUWBattleEntry + PUWFixedEncounters + PUWItemGates.
## Run: godot --headless --script res://tests/sevii_access_tests.gd
##
## The host's side of the ferry/ghost contracts is played by the
## helpers _host_ferry_flags / _host_ghost_flag below, which do
## exactly what sevii_ferry_wiring.json's host_contract says the
## host does: read the real bag and set the transient flags.

const EVENTS_DIR: String = "res://data/events/"
const SUBS: Dictionary = {"{PLAYER}": "RED"}

var _passed: int = 0
var _failed: int = 0
var _lines: Array = []
var _warps: Array = []


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _record_line(speaker: String, text: String) -> void:
	_lines.append({"speaker": speaker, "text": text})


func _record_warp(map_name: String, warp_id: int, _tile: Vector2i) -> void:
	_warps.append([map_name, warp_id])


func _drive(runner: PUWEventRunner, battle_won: bool) -> Dictionary:
	var seen: Dictionary = {}
	var guard: int = 0
	while not runner.is_finished() and not runner.has_error() and guard < 20000:
		guard += 1
		if runner.is_waiting_line():
			runner.advance_line()
		elif runner.is_waiting_battle():
			seen = runner.pending_battle()
			runner.resolve_battle(battle_won)
		else:
			runner.tick(0.05)
	return seen


func _story_state() -> Dictionary:
	var state: Dictionary = PUWCampaignStitch.new_game_state("custom_female", "RED")
	PUWCampaignStitch.complete_setup(state)
	PUWCampaignStitch.record_spawn(state)
	PUWCampaignStitch.record_clues_seen(state)
	PUWCampaignStitch.grant_oak_picks(state,
		{"species_id": 1, "variant": "pokemon"},
		{"species_id": 7, "variant": "pokemon"})
	return state


func _champion_state() -> Dictionary:
	var state: Dictionary = _story_state()
	var flags: Dictionary = state.get("story_flags", {})
	flags["champion"] = true
	flags["campaign_stage"] = "champion"
	state["story_flags"] = flags
	return state


func _flags(state: Dictionary) -> Dictionary:
	var flags_v: Variant = state.get("story_flags", {})
	if flags_v is Dictionary:
		var flags: Dictionary = flags_v
		return flags
	return {}


func _set_flag(state: Dictionary, flag: String) -> void:
	var flags: Dictionary = _flags(state)
	flags[flag] = true
	state["story_flags"] = flags


func _bag(state: Dictionary) -> Dictionary:
	var bag_v: Variant = state.get("bag", {})
	if bag_v is Dictionary:
		var bag: Dictionary = bag_v
		return bag
	return {}


func _give(state: Dictionary, item: String, count: int) -> void:
	var bag: Dictionary = _bag(state)
	bag[item] = int(bag.get(item, 0)) + count
	state["bag"] = bag


func _rig(actor_id: String, tile: Vector2i) -> PUWEventActor:
	return PUWEventActor.create(actor_id, null, tile, 8, "down")


func _actors(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	for id_v in ids:
		out[str(id_v)] = _rig(str(id_v), Vector2i(4 + i, 4))
		i += 1
	return out


## Whether the host would fire this script in this state: the
## runner's own run() gate (once_flag + requires) on a deep copy,
## so the probe's instant steps never touch the caller's state.
func _triggerable(state: Dictionary, path: String) -> bool:
	var copy: Dictionary = state.duplicate(true)
	var runner: PUWEventRunner = PUWEventRunner.new()
	runner.configure(copy, {}, {}, SUBS, 1)
	var script: Dictionary = PUWEventRunner.load_script_file(path)
	if script.is_empty() or not bool(runner.load_script(script).get("ok", false)):
		return false
	return bool(runner.run().get("ok", false))


func _run_script(state: Dictionary, actors: Dictionary, path: String, battle_won: bool, subs: Dictionary = SUBS) -> Dictionary:
	_lines = []
	_warps = []
	var runner: PUWEventRunner = PUWEventRunner.new()
	runner.configure(state, actors,
		{"present_line": Callable(self, "_record_line"), "on_warp": Callable(self, "_record_warp")},
		subs, 4242)
	var script: Dictionary = PUWEventRunner.load_script_file(path)
	var load_ok: bool = not script.is_empty() and bool(runner.load_script(script).get("ok", false))
	var run_result: Dictionary = runner.run()
	var battle_seen: Dictionary = _drive(runner, battle_won)
	return {"runner": runner, "load_ok": load_ok, "run_ok": bool(run_result.get("ok", false)),
		"battle": battle_seen, "lines": _lines.duplicate(), "warps": _warps.duplicate()}


func _bank_text(bank_path: String, group: String, label: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(bank_path))
	if not (parsed is Dictionary):
		return ""
	var groups_v: Variant = (parsed as Dictionary).get("groups", {})
	if not (groups_v is Dictionary):
		return ""
	var group_v: Variant = (groups_v as Dictionary).get(group, {})
	if not (group_v is Dictionary):
		return ""
	var entries_v: Variant = (group_v as Dictionary).get("entries", {})
	if not (entries_v is Dictionary):
		return ""
	return str((entries_v as Dictionary).get(label, ""))


func _sevii(group: String, label: String) -> String:
	return _bank_text("res://data/sevii_dialogue_database.json", group, label).replace("{PLAYER}", "RED")


func _kanto(label_group: String, label: String) -> String:
	return _bank_text("res://data/dialogue_database.json", label_group, label).replace("<PLAYER>", "RED")


func _line_texts(lines: Array) -> Array:
	var out: Array = []
	for line_v in lines:
		out.append(str((line_v as Dictionary).get("text", "")))
	return out


func _party_slugs(battle: Dictionary) -> Array:
	var out: Array = []
	var party_v: Variant = battle.get("enemy_party", [])
	if party_v is Array:
		var party: Array = party_v
		for mon_v in party:
			if mon_v is Dictionary:
				out.append(str((mon_v as Dictionary).get("species_slug", "")))
	return out


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


# ----------------------------------------------------------------
# The host's side of the contracts (sevii_ferry_wiring.json).
# ----------------------------------------------------------------

const DEST_KEYS: Array = ["vermilion", "one_island", "two_island",
	"three_island", "four_island", "five_island", "six_island",
	"seven_island", "navel_rock", "birth_island"]


## Derive the ferry transient flags from the real bag, exactly as
## the wiring record's host_contract prescribes, and (when dest is
## not "") set the one destination flag the menu produced.
func _host_ferry_flags(state: Dictionary, dest: String) -> void:
	var bag: Dictionary = _bag(state)
	var flags: Dictionary = _flags(state)
	flags["ferry_tri_pass"] = int(bag.get("tri-pass", 0)) > 0
	flags["ferry_rainbow_pass"] = int(bag.get("rainbow-pass", 0)) > 0
	flags["ferry_any_ticket"] = int(bag.get("mysticticket", 0)) > 0 \
		or int(bag.get("auroraticket", 0)) > 0
	flags["ferry_mystic_ticket"] = int(bag.get("mysticticket", 0)) > 0 \
		and not bool(flags.get("shown_mystic_ticket", false))
	flags["ferry_aurora_ticket"] = int(bag.get("auroraticket", 0)) > 0 \
		and not bool(flags.get("shown_aurora_ticket", false))
	for key_v in DEST_KEYS:
		flags["ferry_dest_" + str(key_v)] = false
	if dest != "":
		flags["ferry_dest_" + dest] = true
	state["story_flags"] = flags


## The Marowak host step: run the item-fixes prep's real ghost
## check and hand the script its transient flag.
func _host_ghost_flag(state: Dictionary) -> Dictionary:
	var result: Dictionary = PUWItemGates.ghost_check(state, "PokemonTower6F")
	var flags: Dictionary = _flags(state)
	flags["ghost_unidentified"] = bool(result.get("unidentified", false))
	state["story_flags"] = flags
	return result


func _init() -> void:
	_test_bank_additions()
	_test_bill_invitation()
	_test_meet_celio()
	_test_bill_return_note()
	_test_ferry_vermilion()
	_test_ferry_islands()
	_test_ferry_matrix()
	_test_gideon_patched()
	_test_ruby_patched()
	_test_sevii_chain_end_to_end()
	_test_marowak()
	print("SUMMARY: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)


# ----------------------------------------------------------------
# Bank additions: shape + the merge into the test bank.
# ----------------------------------------------------------------

func _test_bank_additions() -> void:
	var additions: Dictionary = _load_json("res://data/sevii_bank_additions.json")
	_check("additions_total_33", int(additions.get("total_entries", 0)) == 33)
	var groups_v: Variant = additions.get("groups", {})
	var groups: Dictionary = groups_v if groups_v is Dictionary else {}
	_check("additions_five_groups", groups.size() == 5)
	var all_present: bool = true
	for group_v in groups.keys():
		var group: String = str(group_v)
		var entries_v: Variant = (groups[group] as Dictionary).get("entries", {})
		var entries: Dictionary = entries_v if entries_v is Dictionary else {}
		for label_v in entries.keys():
			var label: String = str(label_v)
			if _bank_text("res://data/sevii_dialogue_database.json", group, label) != str(entries[label]):
				all_present = false
	_check("additions_merged_into_bank_verbatim", all_present)
	_check("gideon_postbattle_text_exact",
		_sevii("FiveIsland_RocketWarehouse", "FiveIsland_RocketWarehouse_Text_GideonPostBattle")
		== "If I can't sell it, it's worthless!\nGo ahead, take it!")
	_check("found_a_ruby_text_exact",
		_bank_text("res://data/sevii_dialogue_database.json", "MtEmber_RubyPath_B3F",
			"MtEmber_RubyPath_B3F_Text_FoundARuby") == "{PLAYER} found a RUBY!")
	_check("ship_set_sail_text_exact",
		_sevii("VermilionCity", "VermilionCity_Text_TheShipSetSail") == "The ship set sail.")


# ----------------------------------------------------------------
# Bill's invitation: the way onto the islands.
# ----------------------------------------------------------------

func _badged_state(badges: int) -> Dictionary:
	var state: Dictionary = _story_state()
	var ids: Array = ["kanto_gym_1_brock", "kanto_gym_2_misty", "kanto_gym_3_surge",
		"kanto_gym_4_erika", "kanto_gym_5_koga", "kanto_gym_6_sabrina",
		"kanto_gym_7_blaine", "kanto_gym_8_giovanni"]
	state["badges"] = ids.slice(0, badges)
	return state


func _test_bill_invitation() -> void:
	var path: String = EVENTS_DIR + "sevii_bill_invitation.json"
	var script: Dictionary = PUWEventRunner.load_script_file(path)

	var st_low: Dictionary = _badged_state(6)
	_check("invitation_refused_before_blaine",
		not _triggerable(st_low, path))

	var st_yes: Dictionary = _badged_state(7)
	_set_flag(st_yes, "bill_trip_agreed")
	_check("invitation_offered_at_seven_badges", _triggerable(st_yes, path))
	var r_yes: Dictionary = _run_script(st_yes, _actors(["player", "bill"]), path, true)
	_check("invitation_agree_lines_exact", _line_texts(r_yes["lines"]) == [
		_sevii("CinnabarIsland", "CinnabarIsland_Text_HeyIfItIsntPlayer"),
		_sevii("CinnabarIsland", "CinnabarIsland_Text_ComeWithMeToOneIsland"),
		_sevii("CinnabarIsland", "CinnabarIsland_Text_AllRightLetsGo")])
	_check("invitation_agree_sails_to_one_island_harbor",
		(r_yes["warps"] as Array).has(["OneIsland_Harbor", 1]))
	_check("invitation_agree_sets_sailed_flag",
		bool(_flags(st_yes).get("sevii_bill_sailed", false)))
	_check("invitation_never_replays_after_sailing",
		not _triggerable(st_yes, path))

	var st_no: Dictionary = _badged_state(7)
	var r_no: Dictionary = _run_script(st_no, _actors(["player", "bill"]), path, true)
	_check("invitation_decline_waits_in_center", _line_texts(r_no["lines"]) == [
		_sevii("CinnabarIsland", "CinnabarIsland_Text_HeyIfItIsntPlayer"),
		_sevii("CinnabarIsland", "CinnabarIsland_Text_ComeWithMeToOneIsland"),
		_sevii("CinnabarIsland", "CinnabarIsland_Text_IllBeWaitingInPokeCenter")])
	_check("invitation_decline_no_warp_no_flag",
		(r_no["warps"] as Array).is_empty()
		and not bool(_flags(st_no).get("sevii_bill_sailed", false)))
	_check("invitation_decline_stays_offered", _triggerable(st_no, path))


# ----------------------------------------------------------------
# MeetCelio: the Tri-Pass grant scene.
# ----------------------------------------------------------------

func _meet_celio_lines(champion: bool) -> Array:
	var g: String = "OneIsland_PokemonCenter_1F"
	var p: String = "OneIsland_PokemonCenter_1F_Text_"
	var lines: Array = [
		_sevii(g, p + "BillHeyThereCelio"),
		_sevii(g, p + "CelioCantBelieveYouCameOut"),
		_sevii(g, p + "BillHowsYourResearchComing"),
		_sevii(g, p + "ThisIsMyBuddyCelio"),
		_sevii(g, p + ("PlayerIsReigningPokemonChamp" if champion else "PlayerIsRisingPokemonChamp")),
		_sevii(g, p + "CelioThatsReallyImpressive"),
		_sevii(g, p + "BillBringMeUpToSpeed"),
		_sevii(g, p + "CelioPCsCantLinkWithYours"),
		_sevii(g, p + "BillLetMeHelpYou"),
		_sevii(g, p + "CanYouDeliverThisMeteoritePlayer"),
		_sevii(g, p + "AcceptedMeteoriteFromBill"),
		_sevii(g, p + "CelioPleaseTakeThis"),
		_sevii(g, p + "ObtainedTriPass"),
		_sevii(g, p + "PassLetsYouTravelBetweenIslands"),
		_sevii(g, p + "ReceivedTownMap"),
		_sevii(g, p + "BillCatchYouLater"),
	]
	return lines


func _test_meet_celio() -> void:
	var path: String = EVENTS_DIR + "sevii_meet_celio.json"
	var script: Dictionary = PUWEventRunner.load_script_file(path)

	var st_blocked: Dictionary = _champion_state()
	_check("meet_celio_waits_for_bills_boat",
		not _triggerable(st_blocked, path))

	var st: Dictionary = _champion_state()
	_set_flag(st, "sevii_bill_sailed")
	var r: Dictionary = _run_script(st, _actors(["player", "bill", "celio"]), path, true)
	_check("meet_celio_champion_lines_exact",
		_line_texts(r["lines"]) == _meet_celio_lines(true))
	_check("meet_celio_grants_meteorite_tri_pass_town_map",
		int(_bag(st).get("meteorite", 0)) == 1
		and int(_bag(st).get("tri-pass", 0)) == 1
		and int(_bag(st).get("town-map", 0)) == 1)
	_check("meet_celio_sets_scene_and_map_flags",
		bool(_flags(st).get("sevii_met_celio", false))
		and bool(_flags(st).get("sevii_map_123", false)))
	_check("meet_celio_plays_once", not _triggerable(st, path))

	var st_rising: Dictionary = _story_state()
	_set_flag(st_rising, "sevii_bill_sailed")
	var r_rising: Dictionary = _run_script(st_rising, _actors(["player", "bill", "celio"]), path, true)
	_check("meet_celio_rising_line_before_league",
		_line_texts(r_rising["lines"]) == _meet_celio_lines(false))


func _test_bill_return_note() -> void:
	var path: String = EVENTS_DIR + "sevii_bill_return_note.json"
	var st: Dictionary = _story_state()
	_set_flag(st, "sevii_met_celio")
	var r: Dictionary = _run_script(st, _actors(["player", "bill"]), path, true)
	_check("return_note_line_exact", _line_texts(r["lines"]) == [
		_sevii("CinnabarIsland", "CinnabarIsland_Text_IfYouHaveTriPassYouCanGoAgain")])
	_check("return_note_plays_once",
		bool(_flags(st).get("sevii_bill_return_noted", false)))

# ----------------------------------------------------------------
# The ferry: Vermilion branches.
# ----------------------------------------------------------------

func _ferry_run(origin: String, state: Dictionary, dest: String, subs: Dictionary = SUBS) -> Dictionary:
	_host_ferry_flags(state, dest)
	return _run_script(state, _actors(["player", "sailor"]),
		EVENTS_DIR + "sevii_ferry_" + origin + ".json", true, subs)


func _test_ferry_vermilion() -> void:
	var g: String = "VermilionCity"
	var p: String = "VermilionCity_Text_"

	# No pass: the ship has set sail -- one line, no warp, even if
	# a destination flag were (wrongly) set.
	var st0: Dictionary = _story_state()
	var r0: Dictionary = _ferry_run("vermilion", st0, "one_island")
	_check("ferry_vermilion_refuses_without_pass",
		_line_texts(r0["lines"]) == [_sevii(g, p + "TheShipSetSail")]
		and (r0["warps"] as Array).is_empty())

	# Tri-Pass: boarding line + the HI-SPEED 7 departing line.
	var st1: Dictionary = _story_state()
	_give(st1, "tri-pass", 1)
	var r1: Dictionary = _ferry_run("vermilion", st1, "two_island")
	_check("ferry_vermilion_tri_sails_to_two_island",
		_line_texts(r1["lines"]) == [
			_sevii(g, p + "BoardSeagallopTriPass"),
			_sevii("_common", "VermilionCity_Text_Seagallop7Departing")]
		and (r1["warps"] as Array).has(["TwoIsland_Harbor", 1]))

	# Tri-Pass cannot reach a Rainbow island: the destination flag
	# is inert in the Tri section.
	var st2: Dictionary = _story_state()
	_give(st2, "tri-pass", 1)
	var r2: Dictionary = _ferry_run("vermilion", st2, "four_island")
	_check("ferry_vermilion_tri_cannot_reach_four_island",
		_line_texts(r2["lines"]) == [_sevii(g, p + "BoardSeagallopTriPass")]
		and (r2["warps"] as Array).is_empty())

	# Cancelled menu (no destination flag): boarding line only.
	var st3: Dictionary = _story_state()
	_give(st3, "tri-pass", 1)
	var r3: Dictionary = _ferry_run("vermilion", st3, "")
	_check("ferry_vermilion_cancel_ends_after_boarding",
		_line_texts(r3["lines"]) == [_sevii(g, p + "BoardSeagallopTriPass")]
		and (r3["warps"] as Array).is_empty())

	# Rainbow Pass: all seven islands open.
	var st4: Dictionary = _story_state()
	_give(st4, "rainbow-pass", 1)
	var r4: Dictionary = _ferry_run("vermilion", st4, "six_island")
	_check("ferry_vermilion_rainbow_sails_to_six_island",
		_line_texts(r4["lines"]) == [
			_sevii(g, p + "BoardSeagallopRainbowPass"),
			_sevii("_common", "VermilionCity_Text_Seagallop7Departing")]
		and (r4["warps"] as Array).has(["SixIsland_Harbor", 1]))

	# Rainbow + MysticTicket, first showing: recognition line,
	# the generic ferry boarding line, then the HI-SPEED 10
	# departing line to Navel Rock; the shown flag lands.
	var st5: Dictionary = _story_state()
	_give(st5, "rainbow-pass", 1)
	_give(st5, "mysticticket", 1)
	var r5: Dictionary = _ferry_run("vermilion", st5, "navel_rock")
	_check("ferry_vermilion_mystic_ticket_sails_to_navel_rock",
		_line_texts(r5["lines"]) == [
			_sevii(g, p + "OhMysticTicketTakeYouToNavelRock"),
			_sevii(g, p + "BoardSeagallopFerry"),
			_sevii(g, p + "Seagallop10Departing")]
		and (r5["warps"] as Array).has(["NavelRock_Harbor", 1])
		and bool(_flags(st5).get("shown_mystic_ticket", false)))

	# Second visit with the same ticket: the recognition line is
	# spent (the source's FLAG_SHOWN_MYSTIC_TICKET), the generic
	# boarding line still plays.
	var r5b: Dictionary = _ferry_run("vermilion", st5, "one_island")
	_check("ferry_vermilion_ticket_recognition_plays_once",
		_line_texts(r5b["lines"]) == [
			_sevii(g, p + "BoardSeagallopFerry"),
			_sevii("_common", "VermilionCity_Text_Seagallop7Departing")]
		and (r5b["warps"] as Array).has(["OneIsland_Harbor", 1]))

	# Rainbow + AuroraTicket: HI-SPEED 12 to Birth Island.
	var st6: Dictionary = _story_state()
	_give(st6, "rainbow-pass", 1)
	_give(st6, "auroraticket", 1)
	var r6: Dictionary = _ferry_run("vermilion", st6, "birth_island")
	_check("ferry_vermilion_aurora_ticket_sails_to_birth_island",
		_line_texts(r6["lines"]) == [
			_sevii(g, p + "OhAuroraTicketTakeYouToBirthIsland"),
			_sevii(g, p + "BoardSeagallopFerry"),
			_sevii(g, p + "Seagallop12Departing")]
		and (r6["warps"] as Array).has(["BirthIsland_Harbor", 1]))

	# A ticket destination without the ticket is never offered by
	# the host; in-script its warp step still sits behind the
	# destination flag alone, so assert the recognition line does
	# NOT play without the ticket in the bag.
	var st7: Dictionary = _story_state()
	_give(st7, "rainbow-pass", 1)
	var r7: Dictionary = _ferry_run("vermilion", st7, "one_island")
	_check("ferry_vermilion_no_ticket_lines_without_tickets",
		_line_texts(r7["lines"]) == [
			_sevii(g, p + "BoardSeagallopRainbowPass"),
			_sevii("_common", "VermilionCity_Text_Seagallop7Departing")])


# ----------------------------------------------------------------
# The ferry: island harbors.
# ----------------------------------------------------------------

func _aboard(number: String) -> String:
	return _sevii("_common", "Text_AllAboardSeagallopNum").replace("{STR_VAR_1}", number)


func _test_ferry_islands() -> void:
	var greet: String = _sevii("OneIsland", "Text_WhereDoYouWantToSail")

	# One Island, Tri-Pass, back to Vermilion: the ship on a
	# Vermilion route is HI-SPEED 7.
	var st1: Dictionary = _story_state()
	_give(st1, "tri-pass", 1)
	var subs1: Dictionary = {"{PLAYER}": "RED", "{STR_VAR_1}": "7"}
	var r1: Dictionary = _ferry_run("one_island", st1, "vermilion", subs1)
	_check("ferry_one_island_tri_sails_home",
		_line_texts(r1["lines"]) == [greet, _aboard("7")]
		and (r1["warps"] as Array).has(["VermilionDock", 1]))

	# One Island, Tri-Pass, cannot reach Five Island.
	var st2: Dictionary = _story_state()
	_give(st2, "tri-pass", 1)
	var r2: Dictionary = _ferry_run("one_island", st2, "five_island", subs1)
	_check("ferry_one_island_tri_cannot_reach_five_island",
		_line_texts(r2["lines"]) == [greet]
		and (r2["warps"] as Array).is_empty())

	# Three Island, Rainbow Pass, to Seven Island: an
	# inter-island route outside the numbered pairs is HI-SPEED 6.
	var st3: Dictionary = _story_state()
	_give(st3, "rainbow-pass", 1)
	var subs3: Dictionary = {"{PLAYER}": "RED", "{STR_VAR_1}": "6"}
	var r3: Dictionary = _ferry_run("three_island", st3, "seven_island", subs3)
	_check("ferry_three_island_rainbow_sails_to_seven",
		_line_texts(r3["lines"]) == [greet, _aboard("6")]
		and (r3["warps"] as Array).has(["SevenIsland_Harbor", 1]))

	# Four Island (Rainbow-only harbor) back to One Island.
	var st4: Dictionary = _story_state()
	_give(st4, "rainbow-pass", 1)
	var r4: Dictionary = _ferry_run("four_island", st4, "one_island", subs1)
	_check("ferry_four_island_rainbow_sails_to_one",
		_line_texts(r4["lines"]) == [greet, _aboard("7")]
		and (r4["warps"] as Array).has(["OneIsland_Harbor", 1]))

	# Navel Rock: the charter return is Vermilion only, HI-SPEED 10.
	var st5: Dictionary = _story_state()
	_give(st5, "rainbow-pass", 1)
	_give(st5, "mysticticket", 1)
	var subs5: Dictionary = {"{PLAYER}": "RED", "{STR_VAR_1}": "10"}
	var r5: Dictionary = _ferry_run("navel_rock", st5, "vermilion", subs5)
	_check("ferry_navel_rock_returns_to_vermilion",
		_line_texts(r5["lines"]) == [greet, _aboard("10")]
		and (r5["warps"] as Array).has(["VermilionDock", 1]))


# ----------------------------------------------------------------
# The destination matrix: scripts vs the wiring record.
# ----------------------------------------------------------------

func _script_sections(script: Dictionary) -> Dictionary:
	var sections: Dictionary = {"head": [], "tri": [], "rainbow": []}
	var current: String = "head"
	var saw_tier_label: bool = false
	var steps_v: Variant = script.get("steps", [])
	var steps: Array = steps_v if steps_v is Array else []
	for step_v in steps:
		if not (step_v is Dictionary):
			continue
		var step: Dictionary = step_v
		if str(step.get("op", "")) == "label":
			var id: String = str(step.get("id", ""))
			if id == "tri" or id == "rainbow":
				current = id
				saw_tier_label = true
			elif id == "end":
				current = "head"
			continue
		if str(step.get("op", "")) == "warp":
			(sections[current] as Array).append(str(step.get("map", "")))
	if not saw_tier_label:
		# A single-section script (a Rainbow-only harbor, or the
		# Navel/Birth charter return): its warps are its rainbow
		# section -- it has no Tri section at all.
		sections["rainbow"] = sections["head"]
		sections["head"] = []
	return sections


func _test_ferry_matrix() -> void:
	var wiring: Dictionary = _load_json("res://data/sevii_ferry_wiring.json")
	var harbors_v: Variant = wiring.get("harbors", [])
	var harbors: Array = harbors_v if harbors_v is Array else []
	_check("wiring_records_ten_harbors", harbors.size() == 10)
	var map_of: Dictionary = {}
	var sailor_ok: bool = true
	for entry_v in harbors:
		var entry: Dictionary = entry_v
		map_of[str(entry.get("origin", ""))] = str(entry.get("map", ""))
		if str(entry.get("origin", "")) != "vermilion":
			var facts_v: Variant = entry.get("bound_map_facts", {})
			var facts: Dictionary = facts_v if facts_v is Dictionary else {}
			var sailor_v: Variant = facts.get("sailor_object", {})
			var sailor: Dictionary = sailor_v if sailor_v is Dictionary else {}
			if int(sailor.get("x", -1)) != 8 or int(sailor.get("y", -1)) != 6:
				sailor_ok = false
			var warps_v: Variant = facts.get("warps", [])
			if not (warps_v is Array) or (warps_v as Array).size() != 1:
				sailor_ok = false
	_check("wiring_island_sailors_bound_at_8_6_sole_warp", sailor_ok)

	var matrix_v: Variant = wiring.get("destination_matrix", {})
	var matrix: Dictionary = matrix_v if matrix_v is Dictionary else {}
	var matrix_ok: bool = true
	for origin_v in matrix.keys():
		var origin: String = str(origin_v)
		var script: Dictionary = PUWEventRunner.load_script_file(
			EVENTS_DIR + "sevii_ferry_" + origin + ".json")
		if script.is_empty():
			matrix_ok = false
			continue
		var sections: Dictionary = _script_sections(script)
		var want_v: Variant = matrix[origin]
		var want: Dictionary = want_v if want_v is Dictionary else {}
		for tier in ["tri_pass", "rainbow_pass"]:
			var want_maps: Array = []
			var dests_v: Variant = want.get(tier, [])
			var dests: Array = dests_v if dests_v is Array else []
			for dest_v in dests:
				want_maps.append(str(map_of.get(str(dest_v), "")))
			var section: String = "tri" if tier == "tri_pass" else "rainbow"
			var got: Array = (sections.get(section, []) as Array).duplicate()
			var want_sorted: Array = want_maps.duplicate()
			got.sort()
			want_sorted.sort()
			if got != want_sorted:
				matrix_ok = false
	_check("ferry_scripts_match_wiring_destination_matrix", matrix_ok)


# ----------------------------------------------------------------
# The patched events-lane scripts.
# ----------------------------------------------------------------

func _test_gideon_patched() -> void:
	var st: Dictionary = _champion_state()
	_set_flag(st, "sevii_sapphire_stolen")
	var r: Dictionary = _run_script(st, _actors(["player", "gideon"]),
		EVENTS_DIR + "sevii_gideon_reclaim.json", true)
	var g: String = "FiveIsland_RocketWarehouse"
	var p: String = "FiveIsland_RocketWarehouse_Text_"
	_check("gideon_plays_postbattle_line_before_handover",
		_line_texts(r["lines"]) == [
			_sevii(g, p + "GideonIntro"),
			_sevii(g, p + "GideonDefeat"),
			_sevii(g, p + "GideonPostBattle")])
	_check("gideon_still_hands_over_sapphire",
		int(_bag(st).get("sapphire", 0)) == 1
		and bool(_flags(st).get("sevii_sapphire_recovered", false)))


func _test_ruby_patched() -> void:
	var st: Dictionary = _champion_state()
	_set_flag(st, "sevii_celio_quest_started")
	var r: Dictionary = _run_script(st, _actors(["player"]),
		EVENTS_DIR + "sevii_ruby_pickup.json", true)
	_check("ruby_pickup_plays_found_line",
		_line_texts(r["lines"]) == ["RED found a RUBY!"])
	_check("ruby_pickup_still_grants_ruby_and_flag",
		int(_bag(st).get("ruby", 0)) == 1
		and bool(_flags(st).get("sevii_ruby_held", false)))


# ----------------------------------------------------------------
# The whole Sevii chain, end to end, with this prep's access
# beats at both ends and the decoded labels inside it.
# ----------------------------------------------------------------

func _test_sevii_chain_end_to_end() -> void:
	var st: Dictionary = _champion_state()
	st["badges"] = ["kanto_gym_1_brock", "kanto_gym_2_misty", "kanto_gym_3_surge",
		"kanto_gym_4_erika", "kanto_gym_5_koga", "kanto_gym_6_sabrina",
		"kanto_gym_7_blaine", "kanto_gym_8_giovanni"]

	# 1. Bill's invitation (agreed) sails the player to One Island.
	_set_flag(st, "bill_trip_agreed")
	var r1: Dictionary = _run_script(st, _actors(["player", "bill"]),
		EVENTS_DIR + "sevii_bill_invitation.json", true)
	_check("chain_1_invitation_lands_on_one_island",
		(r1["warps"] as Array).has(["OneIsland_Harbor", 1])
		and bool(_flags(st).get("sevii_bill_sailed", false)))

	# 2. MeetCelio grants the Tri-Pass.
	var r2: Dictionary = _run_script(st, _actors(["player", "bill", "celio"]),
		EVENTS_DIR + "sevii_meet_celio.json", true)
	_check("chain_2_meet_celio_grants_tri_pass",
		int(_bag(st).get("tri-pass", 0)) == 1 and r2["load_ok"])

	# 3. The Tri-Pass ferry hops One -> Three Island.
	var subs3: Dictionary = {"{PLAYER}": "RED", "{STR_VAR_1}": "2"}
	var r3: Dictionary = _ferry_run("one_island", st, "three_island", subs3)
	_check("chain_3_tri_pass_ferry_hops_islands",
		(r3["warps"] as Array).has(["ThreeIsland_Harbor", 1]))

	# 4-5. Celio's request, then the Ruby pickup (patched line).
	var r4: Dictionary = _run_script(st, _actors(["player", "celio"]),
		EVENTS_DIR + "sevii_celio_request.json", true)
	_check("chain_4_celio_request_starts_quest",
		bool(_flags(st).get("sevii_celio_quest_started", false)) and r4["load_ok"])
	var r5: Dictionary = _run_script(st, _actors(["player"]),
		EVENTS_DIR + "sevii_ruby_pickup.json", true)
	_check("chain_5_ruby_pickup_with_line",
		int(_bag(st).get("ruby", 0)) == 1
		and _line_texts(r5["lines"]) == ["RED found a RUBY!"])

	# 6. The Ruby delivery exchanges Ruby + Tri-Pass for the
	# Rainbow Pass (the events lane's sourced exchange).
	var r6: Dictionary = _run_script(st, _actors(["player", "celio"]),
		EVENTS_DIR + "sevii_celio_ruby_delivery.json", true)
	_check("chain_6_ruby_delivery_exchanges_for_rainbow_pass",
		int(_bag(st).get("ruby", 0)) == 0
		and int(_bag(st).get("tri-pass", 0)) == 0
		and int(_bag(st).get("rainbow-pass", 0)) == 1
		and bool(_flags(st).get("sevii_ruby_delivered", false)) and r6["load_ok"])

	# 7-8. The Sapphire theft, then Gideon (patched line) gives
	# the Sapphire back.
	var r7: Dictionary = _run_script(st, _actors(["player", "gideon"]),
		EVENTS_DIR + "sevii_sapphire_theft.json", true)
	_check("chain_7_sapphire_stolen",
		bool(_flags(st).get("sevii_sapphire_stolen", false)) and r7["load_ok"])
	var r8: Dictionary = _run_script(st, _actors(["player", "gideon"]),
		EVENTS_DIR + "sevii_gideon_reclaim.json", true)
	_check("chain_8_gideon_reclaim_with_postbattle_line",
		int(_bag(st).get("sapphire", 0)) == 1
		and _line_texts(r8["lines"]).has(
			_sevii("FiveIsland_RocketWarehouse",
				"FiveIsland_RocketWarehouse_Text_GideonPostBattle")))

	# 9. The Sapphire delivery completes the Network Machine.
	var r9: Dictionary = _run_script(st, _actors(["player", "celio"]),
		EVENTS_DIR + "sevii_celio_sapphire_delivery.json", true)
	_check("chain_9_network_machine_complete",
		bool(_flags(st).get("sevii_network_machine_complete", false)) and r9["load_ok"])

	# 10. The Rainbow Pass ferry sails Vermilion -> Seven Island.
	var r10: Dictionary = _ferry_run("vermilion", st, "seven_island")
	_check("chain_10_rainbow_ferry_sails_to_seven_island",
		(r10["warps"] as Array).has(["SevenIsland_Harbor", 1]))


# ----------------------------------------------------------------
# The Marowak ghost beat.
# ----------------------------------------------------------------

func _test_marowak() -> void:
	var path: String = EVENTS_DIR + "pokemon_tower_marowak_ghost.json"

	# The record and its once semantics (PUWFixedEncounters).
	var record: Dictionary = PUWFixedEncounters.record_for("pokemon_tower_marowak_ghost")
	_check("marowak_record_present", not record.is_empty()
		and str(record.get("species", "")) == "MAROWAK"
		and int(record.get("level", 0)) == 30)
	var st_rec: Dictionary = _story_state()
	_check("marowak_available_until_resolved",
		PUWFixedEncounters.is_available(st_rec, record))
	_check("marowak_ran_does_not_consume",
		not PUWFixedEncounters.record_outcome(st_rec, record, "ran")
		and PUWFixedEncounters.is_available(st_rec, record))
	_check("marowak_caught_cannot_consume",
		not PUWFixedEncounters.record_outcome(st_rec, record, "caught")
		and PUWFixedEncounters.is_available(st_rec, record))
	_check("marowak_defeat_consumes",
		PUWFixedEncounters.record_outcome(st_rec, record, "defeated")
		and not PUWFixedEncounters.is_available(st_rec, record)
		and bool(_flags(st_rec).get("marowak_calmed", false)))

	# The real Silph Scope gate (item-fixes prep's PUWItemGates).
	var st_plain: Dictionary = _story_state()
	var check_plain: Dictionary = PUWItemGates.ghost_check(st_plain, "PokemonTower6F")
	_check("ghost_check_unidentified_without_scope",
		bool(check_plain.get("in_tower", false))
		and not bool(check_plain.get("has_scope", true))
		and bool(check_plain.get("unidentified", false)))
	var st_scoped: Dictionary = _story_state()
	_give(st_scoped, "silph-scope", 1)
	var check_scoped: Dictionary = PUWItemGates.ghost_check(st_scoped, "PokemonTower6F")
	_check("ghost_check_identified_with_scope",
		bool(check_scoped.get("has_scope", false))
		and not bool(check_scoped.get("unidentified", true)))
	var check_offmap: Dictionary = PUWItemGates.ghost_check(st_plain, "PalletTown")
	_check("ghost_check_off_tower_does_not_apply",
		not bool(check_offmap.get("in_tower", true)))

	var begone: String = _kanto("PokemonTower6F", "_PokemonTower6FBeGoneText")
	var mother: String = _kanto("PokemonTower6F", "_PokemonTower6FGhostWasCubonesMotherText")
	var calmed: String = _kanto("PokemonTower6F", "_PokemonTower6FSoulWasCalmedText")

	# Without the Scope: BeGone, NO battle built, pushed back
	# east, nothing set, the beat stays live.
	var st_u: Dictionary = _story_state()
	_host_ghost_flag(st_u)
	var actors_u: Dictionary = {"player": _rig("player", Vector2i(20, 32))}
	var r_u: Dictionary = _run_script(st_u, actors_u, path, true)
	_check("marowak_unidentified_plays_begone_only",
		_line_texts(r_u["lines"]) == [begone])
	_check("marowak_unidentified_builds_no_battle",
		(r_u["battle"] as Dictionary).is_empty())
	_check("marowak_unidentified_pushes_player_back",
		(actors_u["player"] as PUWEventActor).tile == Vector2i(21, 32))
	_check("marowak_unidentified_sets_no_flag",
		not bool(_flags(st_u).get("marowak_calmed", false)))
	_check("marowak_unidentified_beat_stays_live",
		_triggerable(st_u, path))

	# With the Scope, won: the Marowak battle builds, the
	# departed lines play, the flag lands, the beat closes.
	var st_w: Dictionary = _story_state()
	_give(st_w, "silph-scope", 1)
	_host_ghost_flag(st_w)
	var actors_w: Dictionary = {"player": _rig("player", Vector2i(20, 32))}
	var r_w: Dictionary = _run_script(st_w, actors_w, path, true)
	_check("marowak_unveiled_battle_is_marowak",
		bool((r_w["battle"] as Dictionary).get("ok", false))
		and _party_slugs(r_w["battle"]).has("marowak"))
	_check("marowak_unveiled_win_plays_departed_lines",
		_line_texts(r_w["lines"]) == [begone, mother, calmed])
	_check("marowak_unveiled_win_sets_calmed_flag",
		bool(_flags(st_w).get("marowak_calmed", false)))
	_check("marowak_calmed_beat_closes",
		not _triggerable(st_w, path))

	# With the Scope, lost: pushed back, no flag, still live --
	# and so still barring the 7F stairs (the record stays
	# available, which is the host's stair-gate condition).
	var st_l: Dictionary = _story_state()
	_give(st_l, "silph-scope", 1)
	_host_ghost_flag(st_l)
	var actors_l: Dictionary = {"player": _rig("player", Vector2i(20, 32))}
	var r_l: Dictionary = _run_script(st_l, actors_l, path, false)
	_check("marowak_unveiled_loss_pushes_back_no_flag",
		_line_texts(r_l["lines"]) == [begone]
		and (actors_l["player"] as PUWEventActor).tile == Vector2i(21, 32)
		and not bool(_flags(st_l).get("marowak_calmed", false)))
	_check("marowak_unresolved_record_bars_fuji_stairs",
		PUWFixedEncounters.is_available(st_l, record)
		and str((record.get("blocks", {}) as Dictionary).get("until", "")) != "")
