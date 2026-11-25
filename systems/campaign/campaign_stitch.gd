class_name PUWCampaignStitch
extends RefCounted
## The Kanto campaign stitch: one story state machine over the
## save state's story_flags, tying together the pieces that already
## exist in the project --
##   character setup / cast spawn (PUWCastRegistry),
##   Pallet home clues (PalletHomeClues, used verbatim),
##   starter choice (CampaignFlow + campaign/starters.json),
##   the branching rival track + dynamic Champion/Runner-Up
##   (PUWKantoLeagueRivalManager + systems/progression/
##   kanto_league_and_rival_story.json),
##   gym order and rosters (systems/progression/
##   trainer_6mon_rosters.json) with badge gating delegated to
##   GymProgression,
##   the Victory Road male gatekeeper beat (rival story data),
##   the Elite Four gauntlet + Hall of Fame (EliteFourFlow),
##   the Omni Ring Kanto lock (core/game_manager.gd rule),
##   Pokemon Center healing (PokemonCenter) and supply trainers
##   (data/supply_trainers.json) as thin flag/delegate calls.
##
## Stage order:
##   setup_done -> spawned_in_house -> clues_seen ->
##   starter_chosen -> (rival fights + badges 1..8 in any
##   interleaving) -> gatekeeper_beat -> runner_up_beat ->
##   elite_four -> champion -> hall_of_fame
##
## Everything story-shaped comes from the data files; this class
## holds the ordering and the gates only.

const STARTERS_PATH: String = "res://campaign/starters.json"
const ROSTERS_PATH: String = "res://systems/progression/trainer_6mon_rosters.json"
const RIVAL_STORY_PATH: String = "res://systems/progression/kanto_league_and_rival_story.json"
const SUPPLY_TRAINERS_PATH: String = "res://data/supply_trainers.json"
const SUPPLY_PLACEMENTS_PATH: String = "res://data/supply_placements.json"
const QUEST_POSTINGS_PATH: String = "res://data/quest_postings_all.json"
const OAK_POOL_PATH: String = "res://campaign/oak_pool.json"
const OAK_BUILDS_PATH: String = "res://campaign/oak_builds.json"
const MAPS_DIR: String = "res://maps/data/maps"

const STAGE_ORDER: Array = [
	"setup_done",
	"spawned_in_house",
	"clues_seen",
	"starter_chosen",
	"gatekeeper_beat",
	"runner_up_beat",
	"elite_four",
	"champion",
	"hall_of_fame",
]

const OMNI_ITEM_ID: String = "omni_ring"


static func _load_json(path: String) -> Dictionary:
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


static func _flags(state: Dictionary) -> Dictionary:
	var flags_value: Variant = state.get("story_flags", {})
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		return flags
	return {}


static func _set_flags(state: Dictionary, flags: Dictionary) -> void:
	state["story_flags"] = flags


static func stage(state: Dictionary) -> String:
	return str(_flags(state).get("campaign_stage", ""))


static func _set_stage(state: Dictionary, new_stage: String) -> void:
	var flags: Dictionary = _flags(state)
	flags["campaign_stage"] = new_stage
	_set_flags(state, flags)


static func _stage_index(state: Dictionary) -> int:
	return STAGE_ORDER.find(stage(state))


static func protagonist_id(state: Dictionary) -> String:
	return str(_flags(state).get("protagonist_id", ""))


## A fresh campaign save state for a cast member: built through
## PUWSaveManager.build_state, with the Omni Ring already in the
## bag (granted at game start, locked -- see can_use_omni).
static func new_game_state(cast_id: String, player_name: String) -> Dictionary:
	var flags: Dictionary = {
		"cast_id": cast_id,
		"protagonist_id": PUWCastRegistry.protagonist_for_cast(cast_id),
		"campaign_stage": "",
		"region_id": "kanto",
		"omni_bracelet_unlocked": false,
		"rival_defeats": {"riley": 0, "tasha": 0},
		"gatekeeper_beat": false,
		"runner_up_beat": false,
	}
	var bag: Dictionary = {OMNI_ITEM_ID: 1}
	var player: Dictionary = {"name": player_name}
	var state: Dictionary = PUWSaveManager.build_state([], [], bag, 0, [], [], [], flags, player)
	apply_protagonist_starter_team(state)
	register_quest_boards(state)
	return state


## Quest boards (binding build 4, code_prep_quests merge step
## 3): register one board per supply placement record, then
## post the authored launch postings for the boards of the
## state's ACTIVE region from data/quest_postings_all.json
## (PUWQuestBoard.post_authored refuses other regions by
## design, so their postings stay in the data file until the
## region activates). Idempotent: already-registered boards
## and already-posted postings refuse cleanly, so region-entry
## code can call this again when a new region becomes active
## and its boards fill. Special chains are NOT posted: they
## are player-accepted from the board screen via
## PUWQuestBoard.accept_special; their definitions ride in
## the same data file. Returns the counts.
static func register_quest_boards(state: Dictionary) -> Dictionary:
	PUWQuestBoard.ensure_quests(state)
	var boards: int = 0
	for placement_value: Variant in supply_placements():
		var placement: Dictionary = placement_value
		if PUWQuestBoard.register_board(state, str(placement.get("region", "")), str(placement.get("id", ""))):
			boards += 1
	var posted: int = 0
	var active_region: String = PUWRegionState.active_region(state)
	var content: Dictionary = _load_json(QUEST_POSTINGS_PATH)
	var postings_value: Variant = content.get("postings", [])
	if postings_value is Array:
		var postings: Array = postings_value
		for posting_value: Variant in postings:
			var posting: Dictionary = posting_value
			if str(posting.get("region_id", "")) != active_region:
				continue
			var result: Dictionary = PUWQuestBoard.post_authored(state, posting, 0)
			if bool(result.get("ok", false)):
				posted += 1
	return {"boards": boards, "postings_posted": posted}


## Fixed-protagonist starting teams (starter system ruling,
## 2026-11-23): Tasha and Riley start with their specified
## six-Pokemon teams, granted directly as the new-game party from
## the verified records at data/<protagonist>_starter_team.json
## (extended party-mon shape: nature, ability, IVs, EVs, held item
## and computed stats are consumed, never dropped — record D8).
## The Scizor exception flag in Tasha's record is data, and rides
## along untouched. Custom protagonists have no record here and
## start with NO Pokemon (their first Pokemon come from Professor
## Oak under the same ruling; that flow is separate). Granted
## mons receive their G1 mon_ids at once via
## PUWSaveManager.ensure_state_mon_ids.
static func apply_protagonist_starter_team(state: Dictionary) -> bool:
	var flags: Dictionary = _flags(state)
	var protagonist_id: String = str(flags.get("protagonist_id", ""))
	if protagonist_id == "":
		return false
	var path: String = "res://data/" + protagonist_id + "_starter_team.json"
	if not FileAccess.file_exists(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var record: Dictionary = parsed
	var team_value: Variant = record.get("team", [])
	if not (team_value is Array):
		return false
	var team: Array = team_value
	if team.is_empty():
		return false
	state["party"] = team.duplicate(true)
	PUWSaveManager.ensure_state_mon_ids(state)
	return true


## setup_done: validate the cast id, resolve the league branching
## (rival, rival encounter totals, Champion, Runner-Up) through
## PUWKantoLeagueRivalManager with a deterministic seed derived
## from the protagonist id, and store the resolution in the flags.
static func complete_setup(state: Dictionary) -> bool:
	var flags: Dictionary = _flags(state)
	var cast_id: String = str(flags.get("cast_id", ""))
	if not PUWCastRegistry.is_cast_id(cast_id):
		return false
	var protag: String = PUWCastRegistry.protagonist_for_cast(cast_id)
	flags["protagonist_id"] = protag
	# Wardrobe binding (code prep rotation 2, 2026-11-23): stamp
	# the resolved cast_id onto the built character dict, when
	# one is stored, so PUWWardrobeShop buy/wear can scope
	# outfits to the character the art exists for.
	var character_v: Variant = flags.get("character_setup", null)
	if character_v is Dictionary:
		var character: Dictionary = character_v
		character["cast_id"] = cast_id
		flags["character_setup"] = character
	var manager: PUWKantoLeagueRivalManager = PUWKantoLeagueRivalManager.new()
	var resolution: Dictionary = manager.configure_for_protagonist(protag, protag.hash())
	flags["league_resolution"] = resolution
	flags["champion_id"] = str(resolution.get("champion", ""))
	flags["runner_up_id"] = str(resolution.get("runner_up_before_e4", ""))
	_set_flags(state, flags)
	_set_stage(state, "setup_done")
	return true


## spawned_in_house: record the cast spawn from PUWCastRegistry
## (canon houses for Riley/Tasha, documented Pallet Town exterior
## spawn for Custom).
static func record_spawn(state: Dictionary) -> Dictionary:
	if _stage_index(state) < STAGE_ORDER.find("setup_done"):
		return {}
	var flags: Dictionary = _flags(state)
	var spawn: Dictionary = PUWCastRegistry.spawn_for_protagonist(str(flags.get("cast_id", "")))
	if spawn.is_empty():
		return {}
	flags["spawn"] = spawn
	_set_flags(state, flags)
	_set_stage(state, "spawned_in_house")
	return spawn


## Both home clues for the current protagonist, produced by
## PalletHomeClues itself -- the conditional texts are never
## retyped here.
static func home_clues(state: Dictionary) -> Dictionary:
	var protag: String = protagonist_id(state)
	return {
		"tasha_fridge_note": PalletHomeClues.get_tasha_fridge_note(protag),
		"riley_drawing_book": PalletHomeClues.get_riley_drawing_book(protag),
	}


## clues_seen: the player has read both home clues (both are
## fetched through PalletHomeClues here, which is the reading).
static func record_clues_seen(state: Dictionary) -> Dictionary:
	if _stage_index(state) < STAGE_ORDER.find("spawned_in_house"):
		return {}
	var clues: Dictionary = home_clues(state)
	var flags: Dictionary = _flags(state)
	flags["clues_seen"] = true
	_set_flags(state, flags)
	_set_stage(state, "clues_seen")
	return clues


## starter_chosen: SUPERSEDED for custom characters
## (STARTER_SYSTEM_SPEC.md C3, binding build 4). A custom
## character's first Pokemon come from Professor Oak via
## grant_oak_picks below -- never from the Kanto-trio picker.
## The fixed protagonists bypass this function too: their
## verified teams are granted directly at new_game_state
## (apply_protagonist_starter_team). This wrapper therefore
## refuses every state; it stays so legacy callers get a clean
## refusal instead of a trio grant, and CampaignFlow's own
## choose_starter remains only as the legacy unit-tested
## builder. Do not re-wire it into a new-game path.
static func choose_starter(state: Dictionary, species_name: String) -> Dictionary:
	return {}


## The Oak pick flow for custom characters (STARTER_SYSTEM_
## SPEC.md section 1; Riley ruling 2026-11-23 22:53 CST): the
## mandatory first story beat in Professor Oak's Lab. pick_1 /
## pick_2 are {species_id: int, variant: "pokemon"|"moemon"}.
## Refuses (empty Array, state untouched) for the fixed
## protagonists (C5: they receive their verified records
## directly), before the clues_seen stage, and for any invalid
## pick pair (CampaignFlow.grant_oak_picks validates pool
## membership, distinct species, variant legality, empty
## party, and one-time completion). On success the party holds
## exactly the two grants, the section 1.3 flags are set, and
## the campaign stage advances to starter_chosen.
static func grant_oak_picks(state: Dictionary, pick_1: Dictionary, pick_2: Dictionary) -> Array:
	if _stage_index(state) < STAGE_ORDER.find("clues_seen"):
		return []
	var protagonist_id: String = str(_flags(state).get("protagonist_id", ""))
	if protagonist_id == "riley" or protagonist_id == "tasha":
		return []
	var pool_file: Dictionary = _load_json(OAK_POOL_PATH)
	var builds_file: Dictionary = _load_json(OAK_BUILDS_PATH)
	var pool_data: Dictionary = {
		"pool": pool_file.get("pool", []),
		"builds": builds_file.get("builds", {}),
	}
	# CampaignFlow works on a {party, flags} shaped state; the
	# save state keeps its flags under story_flags, so shim and
	# copy back (the choose_starter shim pattern).
	var shim: Dictionary = {
		"party": state.get("party", []),
		"flags": _flags(state),
	}
	var granted: Array = CampaignFlow.grant_oak_picks(shim, pool_data, pick_1, pick_2)
	if granted.is_empty():
		return []
	state["party"] = shim["party"]
	_set_flags(state, shim["flags"])
	_set_stage(state, "starter_chosen")
	return granted


## C7 world gate accessor: true once a custom character's Oak
## flow has completed (Pallet exits / Route 1 access check).
## Fixed protagonists never gate on this (their intros grant
## their teams directly).
static func oak_picks_done(state: Dictionary) -> bool:
	return bool(_flags(state).get("oak_picks_done", false))


## Cutscene/story Pokemon display entry point (2026-11-23):
## the campaign stitch is pure logic and owns no scene, so
## this is the hook story code calls when a story beat needs
## to show a Pokemon. It resolves through
## PUWPokemonSpriteBinding with the "cutscene" context --
## the SAME ShinySpriteResolver path battle uses, with the
## same classification and URLs (proven identical by
## tests/battle_sprite_tests.gd). The result is the binding's
## Dictionary: {url, classification ("animated" /
## "static-only" / "missing"), animated, cache_key, ...};
## a scene displays result["url"] by streaming it through
## PUWSpriteLoader, and shows nothing when the classification
## is "missing". Scene-level display hooks (an actual
## cutscene scene calling this) are the remaining scene work;
## no separate cutscene sprite path exists or may grow.
static var _cutscene_binding: PUWPokemonSpriteBinding = null


static func _cutscene_sprite_binding() -> PUWPokemonSpriteBinding:
	if _cutscene_binding == null:
		_cutscene_binding = PUWPokemonSpriteBinding.new()
	return _cutscene_binding


## Display binding for a story mon Dictionary (battle-shaped:
## species / species_slug / forme / shiny).
static func pokemon_display_for(mon: Dictionary) -> Dictionary:
	return _cutscene_sprite_binding().resolve_for_mon(mon, PUWPokemonSpriteBinding.CONTEXT_CUTSCENE, false)


## Display binding for a story species named in plain data
## (e.g. a starter or a rival's ace), with an optional forme.
static func cutscene_sprite_for_species(species_name: String, forme: String = "", shiny: bool = false) -> Dictionary:
	return _cutscene_sprite_binding().resolve_species(species_name, forme, shiny, PUWPokemonSpriteBinding.CONTEXT_CUTSCENE, false)


## Rival encounter totals for this run, from the resolved league
## branching: {rival_id: total_encounters}.
static func rival_totals(state: Dictionary) -> Dictionary:
	var flags: Dictionary = _flags(state)
	var resolution: Dictionary = flags.get("league_resolution", {})
	if resolution.has("rival"):
		var totals: Dictionary = {}
		totals[str(resolution["rival"])] = int(resolution.get("rival_encounters_total", 0))
		return totals
	var totals_custom: Dictionary = {
		"riley": int(resolution.get("riley_encounters", 0)),
		"tasha": int(resolution.get("tasha_encounters", 0)),
	}
	return totals_custom


## Record one rival defeat. Refused for a rival who is not on this
## run's track, or beyond the track's encounter total.
static func record_rival_fight(state: Dictionary, rival_id: String) -> bool:
	if _stage_index(state) < STAGE_ORDER.find("starter_chosen"):
		return false
	var totals: Dictionary = rival_totals(state)
	if not totals.has(rival_id):
		return false
	var flags: Dictionary = _flags(state)
	var defeats: Dictionary = flags.get("rival_defeats", {"riley": 0, "tasha": 0})
	var current: int = int(defeats.get(rival_id, 0))
	if current >= int(totals[rival_id]):
		return false
	defeats[rival_id] = current + 1
	flags["rival_defeats"] = defeats
	_set_flags(state, flags)
	return true


static func rival_track_complete(state: Dictionary) -> bool:
	var totals: Dictionary = rival_totals(state)
	var flags: Dictionary = _flags(state)
	var defeats: Dictionary = flags.get("rival_defeats", {})
	for rival_value: Variant in totals.keys():
		var rival_id: String = str(rival_value)
		if int(defeats.get(rival_id, 0)) < int(totals[rival_id]):
			return false
	return not totals.is_empty()


## Gym order: the 8 Kanto gym ids in roster order from
## trainer_6mon_rosters.json (the 9th entry, the World Coronation
## finale, is not a badge gym).
static func gym_order() -> Array:
	var rosters: Dictionary = _load_json(ROSTERS_PATH)
	var gyms: Array = rosters.get("gyms_and_coronation", [])
	var order: Array = []
	for entry_value: Variant in gyms:
		var entry: Dictionary = entry_value
		var gym_id: String = str(entry.get("id", ""))
		if gym_id.begins_with("kanto_gym_"):
			order.append(gym_id)
	return order


static func gym_entry(gym_id: String) -> Dictionary:
	var rosters: Dictionary = _load_json(ROSTERS_PATH)
	var gyms: Array = rosters.get("gyms_and_coronation", [])
	for entry_value: Variant in gyms:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == gym_id:
			return entry
	return {}


## Gym AVAILABILITY gate (Riley canon, 2026-11-22 14:56 CST):
## the pre-battle check for the availability axis. Availability is
## regional and requirement-based (PUWGymRequirements over
## data/gym_requirements.json) and is never waived by progress in
## other regions -- a foreign badge raises the player's global
## level band / obedience cap (the power axis) but opens nothing
## here. Returns {"allowed": bool, "gym_id": gym_id, "unmet":
## [requirement descriptions...]}.
static func can_start_gym_battle(state: Dictionary, gym_id: String) -> Dictionary:
	var unmet: Array = PUWGymRequirements.unmet_requirements(state, gym_id)
	var descriptions: Array = []
	for req_value: Variant in unmet:
		var req: Dictionary = req_value
		descriptions.append(str(req.get("description", "")))
	return {
		"allowed": unmet.is_empty(),
		"gym_id": gym_id,
		"unmet": descriptions,
	}


## Record a gym win. CANON RECONCILIATION (Riley, 2026-11-22
## 14:56 CST): there is NO roster-order enforcement. Any gym whose
## AVAILABILITY gate passes (can_start_gym_battle ->
## PUWGymRequirements over data/gym_requirements.json) may be
## faced and beaten in any order; availability is regional and
## requirement-based and is never waived by foreign progress. The
## badge itself is awarded through GymProgression (the badge list
## lives in the save state's top-level "badges"), and when the
## region-lock structure (PUWRegionState) exists in the save, the
## win is also noted in the gym's home-region record.
static func record_gym_win(state: Dictionary, gym_id: String) -> bool:
	if _stage_index(state) < STAGE_ORDER.find("starter_chosen"):
		return false
	var gate: Dictionary = can_start_gym_battle(state, gym_id)
	if not bool(gate.get("allowed", false)):
		return false
	if not GymProgression.award_badge(state, gym_id):
		return false
	if state.has("regions"):
		PUWRegionState.note_badge(state, PUWGymRequirements.region_of_gym_id(gym_id), gym_id)
	var flags: Dictionary = _flags(state)
	var names: Dictionary = flags.get("badge_names", {})
	var entry: Dictionary = gym_entry(gym_id)
	names[gym_id] = str(entry.get("badge", ""))
	flags["badge_names"] = names
	_set_flags(state, flags)
	return true


## gatekeeper_beat: the Victory Road pre-cave male gatekeeper
## from the rival story data. Requires all 8 badges; the Elite
## Four gate refuses without this flag (see can_enter_elite_four).
static func record_gatekeeper_win(state: Dictionary) -> bool:
	if not GymProgression.can_challenge_elite_four(state):
		return false
	var flags: Dictionary = _flags(state)
	var resolution: Dictionary = flags.get("league_resolution", {})
	# The gatekeeper exists on the Riley/Tasha tracks in the
	# manager's resolution; the Custom track names him in the
	# story JSON's branching matrix instead. Either way the beat
	# is the same flag.
	var gatekeeper_id: String = str(resolution.get("victory_road_pre_cave_opponent", "male"))
	if gatekeeper_id == "":
		gatekeeper_id = "male"
	flags["gatekeeper_id"] = gatekeeper_id
	flags["gatekeeper_beat"] = true
	_set_flags(state, flags)
	_set_stage(state, "gatekeeper_beat")
	return true


## runner_up_beat: the Runner-Up challenges the player right
## before the Elite Four (rival story runner_up_rule). Requires
## the gatekeeper beat.
static func record_runner_up_win(state: Dictionary) -> bool:
	var flags: Dictionary = _flags(state)
	if not bool(flags.get("gatekeeper_beat", false)):
		return false
	flags["runner_up_beat"] = true
	_set_flags(state, flags)
	_set_stage(state, "runner_up_beat")
	return true


## The Elite Four gate: GymProgression's 8-badge rule AND the
## gatekeeper beat AND the Runner-Up beat.
static func can_enter_elite_four(state: Dictionary) -> bool:
	if not GymProgression.can_challenge_elite_four(state):
		return false
	var flags: Dictionary = _flags(state)
	if not bool(flags.get("gatekeeper_beat", false)):
		return false
	if not bool(flags.get("runner_up_beat", false)):
		return false
	return true


## The gauntlet sequence: the 4 Elite Four ids from the rival
## story JSON, then the dynamically resolved Champion.
static func elite_four_sequence(state: Dictionary) -> Array:
	var story: Dictionary = _load_json(RIVAL_STORY_PATH)
	var members: Array = story.get("kanto_elite_four", [])
	var sequence: Array = []
	for entry_value: Variant in members:
		var entry: Dictionary = entry_value
		sequence.append(str(entry.get("id", "")))
	var flags: Dictionary = _flags(state)
	var champion_id: String = str(flags.get("champion_id", ""))
	if champion_id != "":
		sequence.append(champion_id)
	return sequence


static func _e4_shim(state: Dictionary) -> Dictionary:
	var flags: Dictionary = _flags(state)
	return {
		"party": state.get("party", []),
		"badges": state.get("badges", []),
		"flags": flags,
		"e4_run": flags.get("e4_run", {}),
		"hall_of_fame": flags.get("hall_of_fame", []),
	}


static func _e4_unshim(state: Dictionary, shim: Dictionary) -> void:
	var flags: Dictionary = shim["flags"]
	flags["e4_run"] = shim.get("e4_run", {})
	flags["hall_of_fame"] = shim.get("hall_of_fame", [])
	_set_flags(state, flags)


## elite_four: start the gauntlet through EliteFourFlow. Refused
## unless can_enter_elite_four (8 badges + gatekeeper + runner-up).
static func start_elite_four(state: Dictionary) -> bool:
	if not can_enter_elite_four(state):
		return false
	var shim: Dictionary = _e4_shim(state)
	if not EliteFourFlow.start_gauntlet(shim, elite_four_sequence(state)):
		return false
	_e4_unshim(state, shim)
	_set_stage(state, "elite_four")
	return true


## Record one gauntlet win through EliteFourFlow. Winning the
## final opponent (the Champion) sets the champion flag and the
## Hall of Fame entry inside EliteFourFlow; the stitch then
## advances the stage to hall_of_fame.
static func record_elite_four_win(state: Dictionary) -> bool:
	if stage(state) != "elite_four":
		return false
	var shim: Dictionary = _e4_shim(state)
	if not EliteFourFlow.record_win(shim):
		return false
	_e4_unshim(state, shim)
	var flags: Dictionary = _flags(state)
	if bool(flags.get("champion", false)):
		# Champion-gate wiring (Worker B; parameterized in binding
		# build 3 for the Johto binding): the Champion victory is
		# the point where the campaign's region joins the
		# beaten/shared pool under the region-lock canon, so record
		# it through PUWRegionState.record_champion_win for the
		# campaign's own region — the story flag region_id, which
		# is "kanto" for the Kanto campaign and "johto" when this
		# stitch drives Johto's league (Lance). Never a region
		# literal: this sets
		# state["regions"]["regions"][<region>]
		# ["champion_beaten"] = true. record_champion_win is
		# idempotent-safe here: it returns false when the region
		# is already beaten, and this branch runs only on the
		# gauntlet win that first sets the champion flag.
		var campaign_region: String = str(flags.get("region_id", "kanto"))
		PUWRegionState.record_champion_win(state, campaign_region)
		_set_stage(state, "champion")
		flags = _flags(state)
		flags["hall_of_fame_entered"] = true
		_set_flags(state, flags)
		_set_stage(state, "hall_of_fame")
	return true


## Egg awards on rival track completion, verbatim records from
## kanto_league_and_rival_story.json: defeating Riley's track
## grants the 3 MDX Moemon eggs, defeating Tasha's track grants
## the 3 PKDX Pokemon eggs. A track only pays out when complete.
static func awards(state: Dictionary) -> Dictionary:
	var story: Dictionary = _load_json(RIVAL_STORY_PATH)
	var eggs: Dictionary = story.get("exclusive_rival_defeat_only_shiny_eggs", {})
	var totals: Dictionary = rival_totals(state)
	var flags: Dictionary = _flags(state)
	var defeats: Dictionary = flags.get("rival_defeats", {})
	var out: Dictionary = {"mdx_eggs": [], "pkdx_eggs": []}
	if totals.has("riley") and int(defeats.get("riley", 0)) >= int(totals["riley"]):
		var mdx: Array = eggs.get("riley_moemon_eggs_mdx", [])
		out["mdx_eggs"] = mdx.duplicate(true)
	if totals.has("tasha") and int(defeats.get("tasha", 0)) >= int(totals["tasha"]):
		var pkdx: Array = eggs.get("tasha_pokemon_eggs_pkdx", [])
		out["pkdx_eggs"] = pkdx.duplicate(true)
	return out


## --- Omni Ring -------------------------------------------------

static func omni_bracelet_in_bag(state: Dictionary) -> bool:
	var bag: Dictionary = state.get("bag", {})
	return int(bag.get(OMNI_ITEM_ID, 0)) > 0


static func set_region(state: Dictionary, region_id: String) -> void:
	var flags: Dictionary = _flags(state)
	flags["region_id"] = region_id
	_set_flags(state, flags)


static func set_omni_unlocked(state: Dictionary, unlocked: bool) -> void:
	var flags: Dictionary = _flags(state)
	flags["omni_bracelet_unlocked"] = unlocked
	_set_flags(state, flags)


## The game_manager rule exactly: usable only outside Kanto AND
## unlocked. (In core/game_manager.gd the method is named
## can_activate_omni_bracelet; the rule is identical.)
static func can_use_omni(state: Dictionary) -> bool:
	var flags: Dictionary = _flags(state)
	var region: String = str(flags.get("region_id", "kanto"))
	var unlocked: bool = bool(flags.get("omni_bracelet_unlocked", false))
	return region != "kanto" and unlocked


## --- Centers, Marts, supply trainers (thin delegates) ----------

static func _map_file_exists_with(fragment: String, map_id: String) -> bool:
	var dir: DirAccess = DirAccess.open(MAPS_DIR)
	if dir == null:
		return false
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var base: String = file_name.trim_suffix(".json")
		if base.to_lower().contains(fragment) and base.to_lower() == map_id.to_lower():
			return true
	return false


## A Pokemon Center exists where the sourced map data has a
## Pokecenter map (e.g. CeladonPokecenter, CeruleanPokecenter).
static func center_available(map_id: String) -> bool:
	return _map_file_exists_with("pokecenter", map_id)


## Healing delegates to PokemonCenter.heal_party and records the
## visit as a flag. Refused where no Center map exists.
static func healed_at_center(state: Dictionary, map_id: String) -> bool:
	if not center_available(map_id):
		return false
	var party: Array = state.get("party", [])
	PokemonCenter.heal_party(party)
	state["party"] = party
	var flags: Dictionary = _flags(state)
	flags["last_healed_at_center"] = map_id
	_set_flags(state, flags)
	return true


## A Mart exists where the sourced map data has a Mart map (e.g.
## CeruleanMart, CeladonMart1F). Stock/prices live in MartShop.
static func mart_available(map_id: String) -> bool:
	return _map_file_exists_with("mart", map_id)


## Supply trainer records from data/supply_trainers.json
## (Kira / Haruka / Vance, static, 0-cost claims via MartShop).
static func supply_trainers() -> Array:
	var data: Dictionary = _load_json(SUPPLY_TRAINERS_PATH)
	var trainers: Array = data.get("trainers", [])
	var out: Array = []
	for entry_value: Variant in trainers:
		var entry: Dictionary = entry_value
		out.append({
			"id": str(entry.get("id", "")),
			"name": str(entry.get("name", "")),
			"role": str(entry.get("role", "")),
			"static": bool(entry.get("static", false)),
		})
	return out


## Supply + Vexa placement records from data/supply_placements.json
## (SUPPLY_AND_VEXA_PLACEMENTS_PROPOSAL.md, approved by Riley
## 2026-11-23): 18 spots -- the supply trio grouped in one building
## per settlement, Vexa's holo pad in the same building (lab-like
## where the town has one, Pokemon Center fallback otherwise; her
## Pallet Oak's Lab pad is her home spot).
static func supply_placements() -> Array:
	var data: Dictionary = _load_json(SUPPLY_PLACEMENTS_PATH)
	var placements: Array = data.get("placements", [])
	var out: Array = []
	for entry_value: Variant in placements:
		var entry: Dictionary = entry_value
		var ids: Array = entry.get("supply_trainer_ids", [])
		out.append({
			"id": str(entry.get("id", "")),
			"settlement": str(entry.get("settlement", "")),
			"region": str(entry.get("region", "")),
			"building_name": str(entry.get("building_name", "")),
			"building_map": str(entry.get("building_map", "")),
			"host_kind": str(entry.get("host_kind", "")),
			"trio_spot": str(entry.get("trio_spot", "")),
			"vexa_spot": str(entry.get("vexa_spot", "")),
			"vexa_home": bool(entry.get("vexa_home", false)),
			"supply_trainer_ids": ids,
		})
	return out


## Towns with supply trainers: the 18 approved placement spots.
## (Before the placement source existed this honestly returned an
## empty Array; the proposal was approved 2026-11-23 and the
## records now live in data/supply_placements.json.)
static func towns_with_supply_trainers() -> Array:
	var out: Array = []
	for placement_value: Variant in supply_placements():
		var placement: Dictionary = placement_value
		out.append(str(placement.get("settlement", "")))
	return out


## Vexa holo-pad access points: one per placement spot, in the same
## building as the trio. Pallet's Oak's Lab pad is her home spot.
static func vexa_access_points() -> Array:
	var out: Array = []
	for placement_value: Variant in supply_placements():
		var placement: Dictionary = placement_value
		out.append({
			"settlement": str(placement.get("settlement", "")),
			"building_map": str(placement.get("building_map", "")),
			"spot": str(placement.get("vexa_spot", "")),
			"is_home": bool(placement.get("vexa_home", false)),
		})
	return out


## True when a placement's building resolves to a real map file in
## the sourced world data (exact map base name, e.g. OaksLab).
static func placement_building_exists(placement: Dictionary) -> bool:
	var map_id: String = str(placement.get("building_map", ""))
	if map_id.is_empty():
		return false
	var dir: DirAccess = DirAccess.open(MAPS_DIR)
	if dir == null:
		return false
	for file_name: String in dir.get_files():
		if file_name.trim_suffix(".json") == map_id:
			return true
	return false
