extends SceneTree
## Badge-locked FIELD ACTION tests (Riley canon, 2026-11-22,
## Phase 3 item C): PUWFieldActions
## (systems/overworld/field_actions.gd) over the real data files.
## Run: godot --headless --script res://tests/field_action_tests.gd
##
## What is proven:
## - The BADGE axis is independent of capability: all 9 actions
##   are refused with reason "badge_missing" on a badgeless state
##   even when the party holds a Pokemon that knows the matching
##   move.
## - With the unlocking badge awarded through the real badge
##   store (GymProgression.award_badge writes the gym id into
##   state["badges"], exactly as the campaign stitch does) and a
##   move-knowing party member, all 9 actions are allowed via
##   "move".
## - NATURAL paths: illuminate via an Electric-type that does not
##   know Flash; cut via Scyther (and Scizor), whose LEVEL-UP
##   learnsets contain slicing moves under the derived rule
##   (flags.slicing in data/move_database_954.json); fly via
##   Gastly's Levitate; surf / teleport / dig via type.
## - Badge held but nobody qualifies -> "no_qualifying_pokemon",
##   including for the move-only actions (a Machamp that does
##   not know Strength is refused Strength).
## - perform() records into story_flags["field_actions_used"]
##   only when allowed.

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _fresh_state() -> Dictionary:
	return {"badges": [], "story_flags": {}, "bag": {}}


func _state_with_badge_for(action_id: String) -> Dictionary:
	var state: Dictionary = _fresh_state()
	var badge: Dictionary = PUWFieldActions.required_badge(action_id)
	GymProgression.award_badge(state, str(badge.get("gym_id", "")))
	return state


# A party entry in the campaign stitch's actual shape
# (CampaignFlow.build_starter): species slug in "name", known
# moves as {"name": move id} Dictionaries.
func _mon(slug: String, move_ids: Array) -> Dictionary:
	var moves: Array = []
	for move_value: Variant in move_ids:
		moves.append({"name": str(move_value), "pp": 10, "max_pp": 10})
	return {"species_id": 0, "name": slug, "level": 20, "moves": moves}


# One move-knowing party per action, real species + real move ids.
func _move_party(action_id: String) -> Array:
	match action_id:
		"cut":
			return [_mon("sandslash", ["cut"])]
		"illuminate":
			return [_mon("ampharos", ["flash"])]
		"fly":
			return [_mon("pidgeot", ["fly"])]
		"surf":
			return [_mon("lapras", ["surf"])]
		"strength":
			return [_mon("machamp", ["strength"])]
		"teleport":
			return [_mon("abra", ["teleport"])]
		"dig":
			return [_mon("diglett", ["dig"])]
		"rock_smash":
			return [_mon("geodude", ["rocksmash"])]
		"waterfall":
			return [_mon("gyarados", ["waterfall"])]
	return []


func _init() -> void:
	# --- The table itself -------------------------------------
	var action_ids: Array = PUWFieldActions.actions()
	_check("table: exactly 9 actions", action_ids.size() == 9)
	var expected_actions: Array = ["cut", "illuminate", "fly", "surf", "strength", "teleport", "dig", "rock_smash", "waterfall"]
	var same_table: bool = true
	for expected_value: Variant in expected_actions:
		if not action_ids.has(str(expected_value)):
			same_table = false
	_check("table: the 9 documented action ids", same_table)

	# Every action's matching move is a real move in our data.
	for action_value: Variant in expected_actions:
		var action_id: String = str(action_value)
		var move_id: String = PUWFieldActions.action_move(action_id)
		_check("move exists in 954-move data: %s -> %s" % [action_id, move_id],
			move_id != "" and PUWFieldActions.move_exists(move_id))

	# The shipped badge map (names resolved from gym records).
	var expected_badges: Dictionary = {
		"illuminate": "Boulder Badge",
		"cut": "Cascade Badge",
		"fly": "Thunder Badge",
		"strength": "Rainbow Badge",
		"surf": "Soul Badge",
		"teleport": "Marsh Badge",
		"dig": "Volcano Badge",
		"rock_smash": "Volcano Badge",
		"waterfall": "Earth Badge",
	}
	for action_value: Variant in expected_actions:
		var action_id: String = str(action_value)
		var badge: Dictionary = PUWFieldActions.required_badge(action_id)
		_check("badge map: %s -> %s" % [action_id, str(expected_badges[action_id])],
			str(badge.get("badge", "")) == str(expected_badges[action_id]))

	# Source-defined vs PUW-design split, as documented.
	_check("badge source: 5 source-defined gates",
		PUWFieldActions.badge_source("illuminate") == "source"
		and PUWFieldActions.badge_source("cut") == "source"
		and PUWFieldActions.badge_source("fly") == "source"
		and PUWFieldActions.badge_source("strength") == "source"
		and PUWFieldActions.badge_source("surf") == "source")
	_check("badge source: 4 PUW-design gates",
		PUWFieldActions.badge_source("teleport") == "puw_design"
		and PUWFieldActions.badge_source("dig") == "puw_design"
		and PUWFieldActions.badge_source("rock_smash") == "puw_design"
		and PUWFieldActions.badge_source("waterfall") == "puw_design")

	# --- Badge axis is independent of capability ---------------
	for action_value: Variant in expected_actions:
		var action_id: String = str(action_value)
		var result: Dictionary = PUWFieldActions.can_perform(
			_fresh_state(), _move_party(action_id), action_id)
		_check("badge axis: %s refused badge_missing with a move-knowing Pokemon present" % action_id,
			not bool(result.get("allowed", true))
			and str(result.get("reason", "")) == "badge_missing")

	# --- Move path: badge + move-knowing Pokemon ---------------
	for action_value: Variant in expected_actions:
		var action_id: String = str(action_value)
		var result: Dictionary = PUWFieldActions.can_perform(
			_state_with_badge_for(action_id), _move_party(action_id), action_id)
		_check("move path: %s allowed via move with badge + knower" % action_id,
			bool(result.get("allowed", false))
			and str(result.get("reason", "")) == "ok"
			and str(result.get("via", "")) == "move"
			and str(result.get("species", "")) != "")

	# --- The slicing derivation --------------------------------
	var slicing: Array = PUWFieldActions.slicing_moves()
	_check("slicing set: 26 moves carry flags.slicing in move_database_954.json",
		slicing.size() == 26)
	_check("slicing set: contains slash / xscissor / leafblade / cut, not tackle",
		slicing.has("slash") and slicing.has("xscissor")
		and slicing.has("leafblade") and slicing.has("cut")
		and not slicing.has("tackle"))
	var scyther_slicing: Array = PUWFieldActions.levelup_slicing_moves("scyther")
	var scizor_slicing: Array = PUWFieldActions.levelup_slicing_moves("scizor")
	_check("cut rule verdict: Scyther qualifies (level-up slicing: %s)" % ", ".join(scyther_slicing),
		scyther_slicing.has("slash"))
	_check("cut rule verdict: Scizor qualifies (level-up slicing: %s)" % ", ".join(scizor_slicing),
		scizor_slicing.has("slash"))

	# --- Natural paths ------------------------------------------
	# illuminate: Pikachu is Electric and does NOT know Flash.
	var illuminate_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("illuminate"),
		[_mon("pikachu", ["quickattack", "thunderbolt"])], "illuminate")
	_check("natural: illuminate allowed via Electric-type Pikachu without Flash",
		bool(illuminate_result.get("allowed", false))
		and str(illuminate_result.get("via", "")) == "natural"
		and str(illuminate_result.get("species", "")) == "pikachu")

	# cut: Scyther qualifies by body (level-up slicing learnset),
	# knowing no Cut itself in this entry.
	var cut_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("cut"),
		[_mon("scyther", ["quickattack", "leer"])], "cut")
	_check("natural: cut allowed via Scyther's slicing learnset",
		bool(cut_result.get("allowed", false))
		and str(cut_result.get("via", "")) == "natural"
		and str(cut_result.get("species", "")) == "scyther")
	var scyther_paths: Array = PUWFieldActions.qualifying_paths(
		_mon("scyther", ["quickattack"]), "cut")
	var scyther_path_ok: bool = false
	for path_value: Variant in scyther_paths:
		var path_entry: Dictionary = path_value
		if str(path_entry.get("path", "")) == "natural" and str(path_entry.get("rule", "")) == "slicing_learnset":
			scyther_path_ok = true
	_check("natural: qualifying_paths names the slicing_learnset rule for Scyther", scyther_path_ok)

	# fly: Gastly is not Flying-type; it qualifies by Levitate
	# (master registry ability record for species_id 92).
	var gastly: Dictionary = {"species_id": 92, "name": "gastly", "level": 20,
		"moves": [{"name": "lick", "pp": 30, "max_pp": 30}]}
	var fly_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("fly"), [gastly], "fly")
	_check("natural: fly allowed via Gastly's Levitate",
		bool(fly_result.get("allowed", false))
		and str(fly_result.get("via", "")) == "natural")

	# surf: Lapras is Water-type and does not know Surf here.
	var surf_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("surf"),
		[_mon("lapras", ["growl", "watergun"])], "surf")
	_check("natural: surf allowed via Water-type Lapras without Surf",
		bool(surf_result.get("allowed", false))
		and str(surf_result.get("via", "")) == "natural")

	# teleport: Abra is Psychic-type and does not know Teleport.
	var teleport_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("teleport"),
		[_mon("abra", ["confusion"])], "teleport")
	_check("natural: teleport allowed via Psychic-type Abra without Teleport",
		bool(teleport_result.get("allowed", false))
		and str(teleport_result.get("via", "")) == "natural")

	# dig: Diglett is Ground-type and does not know Dig here.
	var dig_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("dig"),
		[_mon("diglett", ["scratch"])], "dig")
	_check("natural: dig allowed via Ground-type Diglett without Dig",
		bool(dig_result.get("allowed", false))
		and str(dig_result.get("via", "")) == "natural")

	# --- Badge held, nobody qualifies ---------------------------
	var no_qual_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("surf"),
		[_mon("bulbasaur", ["tackle", "growl"])], "surf")
	_check("refusal: badge held but no qualifying Pokemon -> no_qualifying_pokemon",
		not bool(no_qual_result.get("allowed", true))
		and str(no_qual_result.get("reason", "")) == "no_qualifying_pokemon")

	# Move-only actions really are move-only: a Machamp that does
	# not know Strength is refused, however strong it looks.
	_check("move-only: strength / rock_smash / waterfall define no natural rule",
		PUWFieldActions.natural_rule("strength") == ""
		and PUWFieldActions.natural_rule("rock_smash") == ""
		and PUWFieldActions.natural_rule("waterfall") == "")
	var strength_result: Dictionary = PUWFieldActions.can_perform(
		_state_with_badge_for("strength"),
		[_mon("machamp", ["karatechop", "leer"])], "strength")
	_check("move-only: Machamp without Strength is refused Strength",
		not bool(strength_result.get("allowed", true))
		and str(strength_result.get("reason", "")) == "no_qualifying_pokemon")

	# --- Unknown action ------------------------------------------
	var unknown_result: Dictionary = PUWFieldActions.can_perform(
		_fresh_state(), [], "splash_around")
	_check("refusal: unknown action -> unknown_action",
		not bool(unknown_result.get("allowed", true))
		and str(unknown_result.get("reason", "")) == "unknown_action")

	# --- perform() records only when allowed --------------------
	var perform_state: Dictionary = _state_with_badge_for("cut")
	var performed: Dictionary = PUWFieldActions.perform(
		perform_state, [_mon("sandslash", ["cut"])], "cut")
	var flags_after: Dictionary = perform_state.get("story_flags", {})
	var used_after: Array = flags_after.get("field_actions_used", [])
	_check("perform: allowed use is recorded in story_flags.field_actions_used",
		bool(performed.get("allowed", false)) and used_after == ["cut"])

	var refused_state: Dictionary = _fresh_state()
	var refused: Dictionary = PUWFieldActions.perform(
		refused_state, [_mon("sandslash", ["cut"])], "cut")
	var refused_flags: Dictionary = refused_state.get("story_flags", {})
	_check("perform: badge-missing refusal records nothing",
		not bool(refused.get("allowed", true))
		and not refused_flags.has("field_actions_used"))

	var no_qual_state: Dictionary = _state_with_badge_for("surf")
	PUWFieldActions.perform(no_qual_state, [_mon("bulbasaur", ["tackle"])], "surf")
	var no_qual_flags: Dictionary = no_qual_state.get("story_flags", {})
	_check("perform: no-qualifying-Pokemon refusal records nothing",
		not no_qual_flags.has("field_actions_used"))

	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
