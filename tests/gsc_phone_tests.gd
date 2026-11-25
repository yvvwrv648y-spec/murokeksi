extends SceneTree
## GSC PHONE profile tests — code prep (code_prep_gsc_phone).
## Run with Godot 4.7.2 headless against test_project/, which
## holds the patched PUWRematchSystem (frlg + dppt + the new
## gsc_phone profile) and the REAL Johto data files in
## res://data/: rematch_tables_johto.json +
## phone_contact_tier_mapping.json (copies of the
## code_prep_johto_fixes deliverables). The contacts dict is
## built from the mapping file by the adapter below — the
## same join the bind will perform. All rolls are injected;
## no RNG is drawn except the seeded builder RNG in the D4
## build test (the lanes' established pattern).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const JACK: String = "schoolboy_jack_national_park"
const BEVERLY: String = "pokefanf_beverly_national_park"
const PARRY: String = "hiker_parry_route45"

func _init() -> void:
	print("PUW gsc_phone profile tests — starting.")
	_run("test_data_joins_and_profile_registered", Callable(self, "test_data_joins_and_profile_registered"))
	_run("test_registration_rules", Callable(self, "test_registration_rules"))
	_run("test_call_timer_delay_cycle", Callable(self, "test_call_timer_delay_cycle"))
	_run("test_incoming_call_availability_and_content", Callable(self, "test_incoming_call_availability_and_content"))
	_run("test_gate_opens_at_recorded_story_point", Callable(self, "test_gate_opens_at_recorded_story_point"))
	_run("test_ladder_serves_in_proven_order", Callable(self, "test_ladder_serves_in_proven_order"))
	_run("test_unwired_contact_derived_ladder", Callable(self, "test_unwired_contact_derived_ladder"))
	_run("test_loss_and_simulation_guards", Callable(self, "test_loss_and_simulation_guards"))
	_run("test_rematch_party_builds_through_difficulty_layer", Callable(self, "test_rematch_party_builds_through_difficulty_layer"))
	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("FAILED: ", _failed_names)
	quit(1 if _failed > 0 else 0)

func _run(name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_failed_names.append(name)
		print("FAIL: ", name)

func _rng(seed_val: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var root: Dictionary = parsed
	return root

# The bind's join, performed on the real files: tier tables
# keyed as the Johto fixes prep shipped them; contacts built
# from the mapping (gates re-based to 0-based tier indices;
# wants_battle_chance carried ONLY for the three contacts
# whose caller scripts this prep reduced to a number —
# Jack 25, Joey 67, Parry 100 — the rest exercise the
# profile default).
func _tables() -> Dictionary:
	var root: Dictionary = _load_json("res://data/rematch_tables_johto.json")
	var trainers: Dictionary = root.get("trainers", {})
	return trainers

func _contacts() -> Dictionary:
	var tables: Dictionary = _tables()
	var mapping: Dictionary = _load_json("res://data/phone_contact_tier_mapping.json")
	var out: Dictionary = {}
	var mcontacts: Array = mapping.get("contacts", [])
	for raw in mcontacts:
		var c: Dictionary = raw
		var name_slug: String = str(c.get("name", "")).to_lower()
		var map_slug: String = str(c.get("map_slug", ""))
		var key: String = ""
		for k in tables.keys():
			var ks: String = str(k)
			var e: Dictionary = tables[k]
			if str(e.get("map", "")) == map_slug and (ks.contains("_" + name_slug + "_") or ks.ends_with("_" + name_slug)):
				key = ks
				break
		if key.is_empty():
			continue
		var gates: Dictionary = {}
		var mtiers: Array = c.get("tiers", [])
		for traw in mtiers:
			var t: Dictionary = traw
			var g: Variant = t.get("gate_event")
			if g != null and str(g) != "":
				gates[int(t.get("tier", 0)) - 1] = str(g)
		var contact: Dictionary = {"caller_id": str(c.get("caller_id", "")),
			"map": map_slug, "caller_time": "ANYTIME",
			"ladder_wired": bool(c.get("ladder_wired_in_crystal", true)),
			"gates": gates}
		var nm: String = str(c.get("name", ""))
		if nm == "JACK":
			contact["wants_battle_chance"] = 25
		elif nm == "JOEY":
			contact["wants_battle_chance"] = 67
		elif nm == "PARRY":
			contact["wants_battle_chance"] = 100
		out[key] = contact
	return out

func _ctx(current_map: String = "route_29") -> Dictionary:
	return {"on_entrance": false, "map_has_service": true,
		"current_map": current_map, "time_of_day": "ANYTIME"}

# Defeat + register one contact on a fresh-ish state.
func _enlist(state: Dictionary, key: String) -> bool:
	var fb: Dictionary = PUWRematchSystem.phone_record_first_battle(state, key, true, 0)
	if not bool(fb.get("ok", false)):
		return false
	var reg: Dictionary = PUWRematchSystem.phone_register_contact(state, key)
	return bool(reg.get("ok", false))

# Drive one incoming call that readies the named contact:
# only that contact is registered in these tests, so the
# uniform pick (draw 0) always lands on them; content 0 is
# under every wired chance and irrelevant for unwired ones.
func _ready_via_call(state: Dictionary, contacts: Dictionary, key: String) -> bool:
	var res: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx(), 0, 0, 0)
	if not bool(res.get("ok", false)):
		return false
	if str(res.get("contact", "")) != key:
		return false
	if str(res.get("kind", "")) != "rematch_ready":
		return false
	var info: Dictionary = PUWRematchSystem.phone_contact_info(state, key, contacts)
	return bool(info.get("ready", false))

# The real data joins: all 28 mapping contacts find their
# table entry; gates land where the mapping put them; the
# gsc_phone profile is registered alongside frlg/dppt and
# the seeker entry points refuse it cleanly.
func test_data_joins_and_profile_registered() -> bool:
	var tables: Dictionary = _tables()
	var contacts: Dictionary = _contacts()
	if tables.size() != 28 or contacts.size() != 28:
		print("  tables/contacts sizes %d/%d, wanted 28/28" % [tables.size(), contacts.size()])
		return false
	var jack: Dictionary = contacts[JACK]
	var jgates: Dictionary = jack.get("gates", {})
	if jgates.size() != 4:
		return false
	if str(jgates.get(1, "")) != "ENGINE_FLYPOINT_OLIVINE":
		return false
	if str(jgates.get(2, "")) != "EVENT_CLEARED_RADIO_TOWER":
		return false
	if str(jgates.get(3, "")) != "EVENT_BEAT_ELITE_FOUR":
		return false
	if str(jgates.get(4, "")) != "EVENT_RESTORED_POWER_TO_KANTO":
		return false
	var bev: Dictionary = contacts[BEVERLY]
	if bool(bev.get("ladder_wired", true)):
		return false
	var bgates: Dictionary = bev.get("gates", {})
	if not bgates.is_empty():
		return false
	var parry: Dictionary = contacts[PARRY]
	var pgates: Dictionary = parry.get("gates", {})
	if pgates.size() != 2 or str(pgates.get(1, "")) != "EVENT_BEAT_ELITE_FOUR":
		return false
	var p: Dictionary = PUWRematchSystem.profile("gsc_phone")
	if str(p.get("scan_mode", "")) != "incoming_call":
		return false
	if PUWRematchSystem.tier_cap("gsc_phone", {}) != 4:
		return false
	if PUWRematchSystem.tier_cap("frlg", {}) != 0:
		return false
	var state: Dictionary = {}
	var use: Dictionary = PUWRematchSystem.use_vs_seeker(state, [], tables, {}, "gsc_phone", {})
	if str(use.get("reason", "")) != "phone_profile_uses_calls":
		return false
	return true

# Registration: Crystal's order enforced — defeat first,
# then the exchange; the 10-number list cap refuses the
# 11th (CONTACT_LIST_SIZE); deleting a number frees the
# slot and (as in Crystal) leaves progress untouched.
func test_registration_rules() -> bool:
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	var early: Dictionary = PUWRematchSystem.phone_register_contact(state, JACK)
	if str(early.get("reason", "")) != "not_defeated":
		return false
	if not _enlist(state, JACK):
		return false
	var dup: Dictionary = PUWRematchSystem.phone_register_contact(state, JACK)
	if str(dup.get("reason", "")) != "already_registered":
		return false
	# Fixture progress on Jack, to prove delete preserves it
	# (Crystal: DelCellNum touches the list only).
	var root: Dictionary = state["rematch"]
	var t: Dictionary = root["trainers"]
	var jrec: Dictionary = t[JACK]
	jrec["phone_fight_count"] = 2
	jrec["phone_ready"] = true
	t[JACK] = jrec
	root["trainers"] = t
	state["rematch"] = root
	# Fill the remaining 9 slots, then the 11th must refuse.
	var keys: Array = contacts.keys()
	var filled: int = 1
	for k in keys:
		if filled >= 10:
			break
		var ks: String = str(k)
		if ks == JACK:
			continue
		if not _enlist(state, ks):
			return false
		filled += 1
	if PUWRematchSystem.phone_registered_count(state) != 10:
		return false
	var eleventh: String = ""
	for k2 in keys:
		var k2s: String = str(k2)
		var info: Dictionary = PUWRematchSystem.phone_contact_info(state, k2s, contacts)
		if not bool(info.get("registered", false)):
			eleventh = k2s
			break
	if eleventh.is_empty():
		return false
	PUWRematchSystem.phone_record_first_battle(state, eleventh, true, 0)
	var full: Dictionary = PUWRematchSystem.phone_register_contact(state, eleventh)
	if str(full.get("reason", "")) != "phone_list_full":
		return false
	var del: Dictionary = PUWRematchSystem.phone_delete_contact(state, JACK)
	if not bool(del.get("ok", false)):
		return false
	var now: Dictionary = PUWRematchSystem.phone_register_contact(state, eleventh)
	if not bool(now.get("ok", false)):
		return false
	var re: Dictionary = PUWRematchSystem.phone_register_contact(state, JACK)
	if str(re.get("reason", "")) != "phone_list_full":
		return false
	PUWRematchSystem.phone_delete_contact(state, eleventh)
	var re2: Dictionary = PUWRematchSystem.phone_register_contact(state, JACK)
	if not bool(re2.get("ok", false)):
		return false
	var jinfo: Dictionary = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if int(jinfo.get("fight_count", -1)) != 2 or not bool(jinfo.get("ready", false)):
		return false
	return true

# The receive-call delay (time.asm): 20 minutes to the first
# opportunity; each expiry without a received call shortens
# the next delay (10, 5, 3, then 3 forever).
func test_call_timer_delay_cycle() -> bool:
	var state: Dictionary = {}
	if PUWRematchSystem.phone_call_timer_tick(state, 19) != 0:
		return false
	var root: Dictionary = state["rematch"]
	var ph: Dictionary = root["phone"]
	if int(ph.get("call_delay_left", -1)) != 1:
		return false
	if PUWRematchSystem.phone_call_timer_tick(state, 1) != 1:
		return false
	root = state["rematch"]
	ph = root["phone"]
	if int(ph.get("cycles_since_last_call", -1)) != 1 or int(ph.get("call_delay_left", -1)) != 10:
		return false
	if PUWRematchSystem.phone_call_timer_tick(state, 10) != 1:
		return false
	if PUWRematchSystem.phone_call_timer_tick(state, 5) != 1:
		return false
	root = state["rematch"]
	ph = root["phone"]
	if int(ph.get("cycles_since_last_call", -1)) != 3 or int(ph.get("call_delay_left", -1)) != 3:
		return false
	if PUWRematchSystem.phone_call_timer_tick(state, 3) != 1:
		return false
	root = state["rematch"]
	ph = root["phone"]
	if int(ph.get("cycles_since_last_call", -1)) != 3 or int(ph.get("call_delay_left", -1)) != 3:
		return false
	return true

# CheckPhoneCall's chain: entrance / service / coin-flip
# refusals connect nothing and reset nothing; availability
# excludes the contact's own map; a connected call resets
# the delay; content decides ready vs generic (Jack's
# script-derived chance is 25); an already-ready contact's
# call is generic and readiness persists.
func test_incoming_call_availability_and_content() -> bool:
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	if not _enlist(state, JACK):
		return false
	PUWRematchSystem.phone_call_timer_tick(state, 20)
	var entrance: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, {"on_entrance": true, "map_has_service": true,
			"current_map": "route_29", "time_of_day": "ANYTIME"}, 0, 0, 0)
	if str(entrance.get("reason", "")) != "on_entrance":
		return false
	var nosvc: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, {"on_entrance": false, "map_has_service": false,
			"current_map": "route_29", "time_of_day": "ANYTIME"}, 0, 0, 0)
	if str(nosvc.get("reason", "")) != "no_phone_service":
		return false
	var ownmap: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx("national_park"), 0, 0, 0)
	if str(ownmap.get("reason", "")) != "no_available_callers":
		return false
	var flip: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx(), 1, 0, 0)
	if str(flip.get("reason", "")) != "call_coin_flip":
		return false
	var root: Dictionary = state["rematch"]
	var ph: Dictionary = root["phone"]
	if int(ph.get("cycles_since_last_call", -1)) != 1:
		return false
	var generic: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx(), 0, 0, 99)
	if str(generic.get("kind", "")) != "generic_call":
		return false
	root = state["rematch"]
	ph = root["phone"]
	if int(ph.get("cycles_since_last_call", -1)) != 0 or int(ph.get("call_delay_left", -1)) != 20:
		return false
	var info: Dictionary = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if bool(info.get("ready", false)):
		return false
	var ready: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx(), 0, 0, 24)
	if str(ready.get("kind", "")) != "rematch_ready" or str(ready.get("via", "")) != "caller_script":
		return false
	info = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if not bool(info.get("ready", false)):
		return false
	var again: Dictionary = PUWRematchSystem.phone_try_incoming_call(
		state, contacts, _ctx(), 0, 0, 0)
	if str(again.get("kind", "")) != "generic_call":
		return false
	info = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if not bool(info.get("ready", false)):
		return false
	return true

# The recorded story point opens the recorded tier: with
# Jack's FightCount at 1 and no progression flags, the
# cascade falls back to the Fight0 party and reports the
# frontier gate (ENGINE_FLYPOINT_OLIVINE, verbatim from the
# mapping); setting that flag serves JACK2.
func test_gate_opens_at_recorded_story_point() -> bool:
	var tables: Dictionary = _tables()
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	if not _enlist(state, JACK):
		return false
	if not _ready_via_call(state, contacts, JACK):
		return false
	var first: Dictionary = PUWRematchSystem.phone_begin_rematch(state, JACK, tables, contacts, {})
	if not bool(first.get("ok", false)) or int(first.get("tier_index", -1)) != 0:
		return false
	if str(first.get("trainer_id", "")) != "schoolboy_jack1":
		return false
	var rec1: Dictionary = PUWRematchSystem.phone_record_result(
		state, JACK, tables, true, 10, first["context"])
	if not bool(rec1.get("ok", false)):
		return false
	if not _ready_via_call(state, contacts, JACK):
		return false
	var gated: Dictionary = PUWRematchSystem.phone_next_tier(state, JACK, tables, contacts, {})
	if int(gated.get("tier_index", -1)) != 0:
		return false
	if not bool(gated.get("frontier_gated", false)):
		return false
	if str(gated.get("frontier_gate", "")) != "ENGINE_FLYPOINT_OLIVINE":
		return false
	if not bool(gated.get("is_repeat", false)):
		return false
	var opened: Dictionary = PUWRematchSystem.phone_begin_rematch(
		state, JACK, tables, contacts, {"ENGINE_FLYPOINT_OLIVINE": true})
	if not bool(opened.get("ok", false)) or int(opened.get("tier_index", -1)) != 1:
		return false
	if str(opened.get("trainer_id", "")) != "schoolboy_jack2":
		return false
	if bool(opened.get("frontier_gated", true)):
		return false
	return true

# Jack's full ladder, in the mapping's proven order, one
# recorded gate at a time; the top tier then re-serves
# (Crystal's LoadFight4 sets no new count).
func test_ladder_serves_in_proven_order() -> bool:
	var tables: Dictionary = _tables()
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	if not _enlist(state, JACK):
		return false
	var progression: Dictionary = {}
	var gate_flags: Array = ["ENGINE_FLYPOINT_OLIVINE",
		"EVENT_CLEARED_RADIO_TOWER", "EVENT_BEAT_ELITE_FOUR",
		"EVENT_RESTORED_POWER_TO_KANTO"]
	var expected: Array = ["schoolboy_jack1", "schoolboy_jack2",
		"schoolboy_jack3", "schoolboy_jack4", "schoolboy_jack5"]
	for i in expected.size():
		if i > 0:
			progression[gate_flags[i - 1]] = true
		if not _ready_via_call(state, contacts, JACK):
			print("  walk: ready failed at step %d" % i)
			return false
		var begin: Dictionary = PUWRematchSystem.phone_begin_rematch(
			state, JACK, tables, contacts, progression)
		if not bool(begin.get("ok", false)):
			print("  walk: begin failed at step %d" % i)
			return false
		if int(begin.get("tier_index", -1)) != i:
			print("  walk: tier %d at step %d" % [int(begin.get("tier_index", -1)), i])
			return false
		if str(begin.get("trainer_id", "")) != str(expected[i]):
			print("  walk: id %s at step %d" % [str(begin.get("trainer_id", "")), i])
			return false
		var rec: Dictionary = PUWRematchSystem.phone_record_result(
			state, JACK, tables, true, 100 + i, begin["context"])
		if not bool(rec.get("ok", false)):
			return false
	var info: Dictionary = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if int(info.get("fight_count", -1)) != 4:
		return false
	if not _ready_via_call(state, contacts, JACK):
		return false
	var top: Dictionary = PUWRematchSystem.phone_begin_rematch(
		state, JACK, tables, contacts, progression)
	if int(top.get("tier_index", -1)) != 4 or not bool(top.get("is_repeat", false)):
		return false
	var rec2: Dictionary = PUWRematchSystem.phone_record_result(
		state, JACK, tables, true, 200, top["context"])
	if not bool(rec2.get("ok", false)):
		return false
	info = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if int(info.get("fight_count", -1)) != 4:
		return false
	return true

# Beverly is one of the four contacts the mapping flags
# ladder_wired_in_crystal: false. The profile invents no
# wiring for her: her info reports the flag, her gate set
# is empty, readiness arrives by the labeled PUW-side call
# rule (any content roll), and her tiers serve in the
# mapping's derived order.
func test_unwired_contact_derived_ladder() -> bool:
	var tables: Dictionary = _tables()
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	if not _enlist(state, BEVERLY):
		return false
	var info: Dictionary = PUWRematchSystem.phone_contact_info(state, BEVERLY, contacts)
	if bool(info.get("ladder_wired_in_crystal", true)):
		return false
	if str(info.get("caller_id", "")) != "PHONE_POKEFAN_BEVERLY":
		return false
	var expected: Array = ["pokefanf_beverly1", "pokefanf_beverly2", "pokefanf_beverly3"]
	for i in expected.size():
		var call: Dictionary = PUWRematchSystem.phone_try_incoming_call(
			state, contacts, _ctx(), 0, 0, 99)
		if str(call.get("kind", "")) != "rematch_ready" or str(call.get("via", "")) != "puw_unwired_rule":
			print("  beverly: call at step %d: %s" % [i, str(call.get("kind", ""))])
			return false
		var begin: Dictionary = PUWRematchSystem.phone_begin_rematch(
			state, BEVERLY, tables, contacts, {})
		if not bool(begin.get("ok", false)) or int(begin.get("tier_index", -1)) != i:
			return false
		if str(begin.get("trainer_id", "")) != str(expected[i]):
			return false
		var rec: Dictionary = PUWRematchSystem.phone_record_result(
			state, BEVERLY, tables, true, 300 + i, begin["context"])
		if not bool(rec.get("ok", false)):
			return false
	info = PUWRematchSystem.phone_contact_info(state, BEVERLY, contacts)
	if int(info.get("fight_count", -1)) != 2:
		return false
	return true

# Canon guards on the phone path: begin requires READY; a
# simulation context is refused and changes nothing; a
# loss clears readiness but does not advance the count.
func test_loss_and_simulation_guards() -> bool:
	var tables: Dictionary = _tables()
	var contacts: Dictionary = _contacts()
	var state: Dictionary = {}
	if not _enlist(state, JACK):
		return false
	var notready: Dictionary = PUWRematchSystem.phone_begin_rematch(state, JACK, tables, contacts, {})
	if str(notready.get("reason", "")) != "not_ready":
		return false
	if not _ready_via_call(state, contacts, JACK):
		return false
	var begin: Dictionary = PUWRematchSystem.phone_begin_rematch(state, JACK, tables, contacts, {})
	if not bool(begin.get("ok", false)):
		return false
	var sim: Dictionary = PUWRematchSystem.phone_record_result(
		state, JACK, tables, true, 5,
		{"simulation": true, "battle_kind": "rematch"})
	if str(sim.get("reason", "")) != "simulation_context_refused":
		return false
	var info: Dictionary = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if not bool(info.get("ready", false)):
		return false
	var loss: Dictionary = PUWRematchSystem.phone_record_result(
		state, JACK, tables, false, 6, begin["context"])
	if not bool(loss.get("ok", false)):
		return false
	info = PUWRematchSystem.phone_contact_info(state, JACK, contacts)
	if bool(info.get("ready", false)) or int(info.get("fight_count", -1)) != 0:
		return false
	var rec: Dictionary = PUWRematchSystem.trainer_record(state, JACK)
	if int(rec.get("rematches_lost", -1)) != 1:
		return false
	return true

# D4 on the phone path: Jack's tier-3 row (schoolboy_jack4;
# recorded history level 30/33/33, iv null in Crystal data)
# builds through build_rematch_party() into exactly 6 mons
# at the player's level 50 — IV 31 everywhere, EV totals
# within the 510 budget, the tier's species present, and
# none of the tier's recorded levels anywhere.
func test_rematch_party_builds_through_difficulty_layer() -> bool:
	var tables: Dictionary = _tables()
	var entry: Dictionary = tables[JACK]
	var tiers: Array = entry["tiers"]
	var tier3: Dictionary = tiers[3]
	if str(tier3.get("trainer_id", "")) != "schoolboy_jack4":
		return false
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	if not builder.is_loaded():
		print("  builder data not loaded (data folder missing?)")
		return false
	var team: Array = PUWRematchSystem.build_rematch_party(tier3, 50, "singles", _rng(7))
	if team.size() != 6:
		print("  team size %d, wanted 6" % team.size())
		return false
	var slugs: Dictionary = {}
	for mon_v in team:
		var mon: Dictionary = mon_v
		if int(mon["level"]) != 50:
			print("  mon level %d, wanted 50 (player scaling)" % int(mon["level"]))
			return false
		var ivs: Dictionary = mon["ivs"]
		for stat in ["hp", "atk", "def", "spa", "spd", "spe"]:
			if int(ivs.get(stat, -1)) != 31:
				print("  mon iv %s = %d, wanted 31" % [stat, int(ivs.get(stat, -1))])
				return false
		var evs: Dictionary = mon["evs"]
		if PUWTeamBuilder.ev_total(evs) > 510:
			print("  mon ev total over 510")
			return false
		slugs[str(mon.get("species_slug", ""))] = true
	for want in ["gloom", "growlithe", "electrode"]:
		if not slugs.has(want):
			print("  tier species %s missing from built team" % want)
			return false
	return true
