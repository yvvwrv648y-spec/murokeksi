class_name PUWRaidRun
extends RefCounted
## PUWRaidRun — the Dynamax Adventures run structure for VEXA
## raids (gap G4, run-structure half).
##
## Design reference: hidden_files/gen78_modes_transport/
## GEN78_MODES_TRANSPORT.md, "Dynamax Adventures" (official
## Expansion Pass page / Bulbapedia / guides via the register).
## Facts taken from it:
## - 4 Trainers enter with rental Pokemon only (pick 1 of 3
##   offered; the pool rotates as picks are made). Rentals are
##   permadeath-exempt under PUW canon, and this whole run lives
##   inside VEXA, which is permadeath-exempt as well.
## - The lair is a branching path: after each battle the team
##   votes a path, seeing the TYPE of the next Dynamax Pokemon
##   but not the species. A normal run is 3 Dynamax battles,
##   then a Legendary (or Ultra Beast) at the deepest point.
## - Attrition is the system: HP carries over between battles
##   with no free healing; the team shares 4 hearts, one lost
##   per faint; lose all 4 and the run ends. Path NPCs patch the
##   attrition: a Scientist offers a random-Pokemon swap, a
##   Backpacker gives a held item, Berries on the path heal.
## - After each win you may catch the Pokemon, and one Trainer
##   may swap their current Pokemon for the fresh, fully-healed
##   catch.
## - At the end you keep exactly one of everything you caught;
##   the rest are returned. Currency: Dynite Ore (more for
##   deeper / cleared runs).
## - Endless Dynamax Adventures unlock after 5 normal clears:
##   runs continue until a loss, pay more Ore, but you keep
##   nothing you catch.
##
## DESIGN CONSTANTS (the register gives no numbers for these):
## Dynite Ore per battle won (3) and for a full clear (+4) —
## the register says only "more for deeper/cleared runs"; the
## path Berries heal fraction (50% of max HP); the final
## battle's star rating (5; earlier battles use the run's star);
## the Legendary candidate pool below (the register says the
## deepest battle is "a Legendary (or Ultra Beast)" without a
## list — membership is verified against PUWTeamBuilder's held
## species data at runtime, and species the builder does not
## know are skipped); and one interpretation: a Pokemon that
## ended a battle fainted starts the next battle at full HP —
## the heart it cost is the penalty (the register does not say,
## and the alternative, a permanently 0-HP raider, would make
## the shared-hearts rule meaningless).
##
## Not modeled, stated plainly: PP carry-over (the project's mon
## dicts do not track PP anywhere), and the 20-second path vote
## clock (the register's own canon-fit note says to drop it for
## PUW co-op; path choice here is a plain method call).
##
## Safety: the run works on mons it built itself or on a deep
## copy of the caller's entry mon. It never touches a real
## party, a save, or PartyAndStorageManager.

const HEARTS: int = 4 ## SOURCED: shared 4 hearts, one per faint.
const BATTLES_BEFORE_FINAL: int = 3 ## SOURCED: 3 battles, then a Legendary.
const ENDLESS_UNLOCK_CLEARS: int = 5 ## SOURCED: Endless unlocks after 5 clears.
const RENTAL_OFFERS: int = 3 ## SOURCED: pick 1 of 3 offered rentals.
## DESIGN CONSTANT: Dynite Ore per battle won / full-clear bonus.
const ORE_PER_WIN: int = 3
const ORE_CLEAR_BONUS: int = 4
## DESIGN CONSTANT: path Berries heal this fraction of max HP.
const BERRY_HEAL_FRACTION: float = 0.5
## DESIGN CONSTANT: star rating of the deepest (Legendary) battle.
const FINAL_STAR: int = 5
## DESIGN CONSTANT: Legendary / Ultra Beast candidates for the
## deepest battle, verified against held species data at runtime.
const LEGENDARY_POOL: Array = [
	"mewtwo", "lugia", "ho-oh", "kyogre", "groudon", "rayquaza",
	"dialga", "palkia", "giratina", "reshiram", "zekrom",
	"xerneas", "yveltal", "solgaleo", "lunala", "zacian",
	"zamacenta", "koraidon", "miraidon", "necrozma", "eternatus",
	"nihilego", "buzzwole", "pheromosa", "xurkitree", "celesteela",
	"kartana", "guzzlord", "naganadel", "stakataka", "blacephalon",
]

var entries: Array = [] ## [{trainer, is_player, mon}] — the run's own mons.
var hearts: int = HEARTS
var catches: Array = [] ## species display names, in catch order.
var battles_won: int = 0
var status: String = "not_started" ## in_progress | cleared | run_failed
var fail_reason: String = ""

var _builder: PUWTeamBuilder = null
var _rng: RandomNumberGenerator = null
var _level: int = 50
var _star: int = 3
var _endless: bool = false
var _final_done: bool = false
var _battles_fought: int = 0
var _path_options: Array = [] ## [{species_slug, type}] — species hidden from players.
var _current_boss_slug: String = ""
var _last_catch_species: String = ""
var _swap_used: bool = true


## Offer RENTAL_OFFERS rental mons (sourced: pick 1 of 3; the
## pool rotates as picks are made — each call offers fresh
## species). The caller picks one and passes it to start() as
## player_mon, or passes its own mon to skip rentals.
func offer_rentals(builder: PUWTeamBuilder, level: int, rng: RandomNumberGenerator) -> Array:
	var offers: Array = []
	var used: Dictionary = {}
	var slugs: Array = _pool_slugs(builder)
	var guard: int = 0
	while offers.size() < RENTAL_OFFERS and guard < 200:
		guard += 1
		if slugs.is_empty():
			break
		var slug: String = str(slugs[rng.randi_range(0, slugs.size() - 1)])
		var mon: Dictionary = builder.build_mon(slug, level, "singles")
		var final_slug: String = str(mon.get("species_slug", slug))
		if used.has(final_slug):
			continue
		used[final_slug] = true
		offers.append(mon)
	return offers


func _pool_slugs(builder: PUWTeamBuilder) -> Array:
	builder._ensure_loaded()
	var slugs: Array = []
	for slug_v in builder._species.keys():
		slugs.append(str(slug_v))
	slugs.sort()
	return slugs


## Start a run. options: {
##   "builder": PUWTeamBuilder (required),
##   "rng": RandomNumberGenerator (required),
##   "level": int (default 50), "star": int 1-5 (default 3),
##   "player_mon": Dictionary (required — a rental from
##     offer_rentals(), or the caller's own mon; deep-copied),
##   "player_trainer": String (default "Player"),
##   "npc_species": Array of 3 species names/slugs for the NPC
##     Support Trainers (default: rolled from the pool),
##   "endless": bool (default false),
##   "prior_clears": int (default 0) — Endless refuses below 5.
## }
func start(options: Dictionary) -> Dictionary:
	_builder = options.get("builder", null)
	_rng = options.get("rng", null)
	if _builder == null or _rng == null:
		return {"status": "bad_options", "reason": "builder and rng are required"}
	_endless = bool(options.get("endless", false))
	if _endless and int(options.get("prior_clears", 0)) < ENDLESS_UNLOCK_CLEARS:
		# SOURCED: Endless unlocks after 5 normal clears.
		return {"status": "endless_locked", "prior_clears": int(options.get("prior_clears", 0))}
	_level = clampi(int(options.get("level", 50)), 5, 100)
	_star = clampi(int(options.get("star", 3)), 1, 5)
	hearts = HEARTS
	catches = []
	battles_won = 0
	_battles_fought = 0
	_final_done = false
	_last_catch_species = ""
	_swap_used = true
	fail_reason = ""
	var player_mon_in: Dictionary = options.get("player_mon", {})
	if player_mon_in.is_empty():
		return {"status": "bad_options", "reason": "player_mon is required"}
	entries = [{
		"trainer": str(options.get("player_trainer", "Player")),
		"is_player": true,
		"mon": player_mon_in.duplicate(true),
	}]
	var npc_species: Array = options.get("npc_species", [])
	var used: Dictionary = {}
	for i in range(PUWRaidBattle.RAIDER_COUNT - 1):
		var mon: Dictionary = {}
		if i < npc_species.size():
			mon = _builder.build_mon(str(npc_species[i]), _level, "singles")
		else:
			mon = _random_pool_mon(used)
		used[str(mon.get("species_slug", ""))] = true
		entries.append({"trainer": "Support Trainer %d" % (i + 1), "is_player": false, "mon": mon})
	status = "in_progress"
	_roll_path_options()
	return {"status": "started", "hearts": hearts, "endless": _endless, "path_options": path_options()}


func _random_pool_mon(used: Dictionary) -> Dictionary:
	var slugs: Array = _pool_slugs(_builder)
	var guard: int = 0
	while guard < 200:
		guard += 1
		var slug: String = str(slugs[_rng.randi_range(0, slugs.size() - 1)])
		var mon: Dictionary = _builder.build_mon(slug, _level, "singles")
		if not used.has(str(mon.get("species_slug", ""))):
			return mon
	return _builder.build_mon("eevee", _level, "singles")


## True when the next battle is the deepest (Legendary) one.
func is_final_next() -> bool:
	return not _final_done and _battles_fought >= BATTLES_BEFORE_FINAL


## The path choice as players see it (sourced: the TYPE of the
## next Dynamax Pokemon, not the species).
func path_options() -> Array:
	var out: Array = []
	for opt_v in _path_options:
		var opt: Dictionary = opt_v
		out.append({"type": str(opt.get("type", ""))})
	return out


## Test/debug view of the rolled path species. Players never see
## this in game (sourced: type only).
func peek_path_species() -> Array:
	var out: Array = []
	for opt_v in _path_options:
		var opt: Dictionary = opt_v
		out.append(str(opt.get("species_slug", "")))
	return out


func choose_path(option_idx: int) -> Dictionary:
	if _path_options.is_empty():
		return {"status": "no_path"}
	var idx: int = clampi(option_idx, 0, _path_options.size() - 1)
	var opt: Dictionary = _path_options[idx]
	_current_boss_slug = str(opt.get("species_slug", ""))
	return {"status": "chosen", "type": str(opt.get("type", ""))}


func _roll_path_options() -> void:
	_path_options = []
	_current_boss_slug = ""
	if is_final_next():
		var slug: String = _random_legendary_slug()
		if slug != "":
			var types: Array = _builder.species_types(slug)
			_path_options.append({"species_slug": slug, "type": str(types[0]) if not types.is_empty() else "Normal"})
		return
	var used_types: Dictionary = {}
	var guard: int = 0
	while _path_options.size() < 2 and guard < 200:
		guard += 1
		var mon: Dictionary = _random_pool_mon({})
		var slug2: String = str(mon.get("species_slug", ""))
		var types2: Array = _builder.species_types(slug2)
		var t: String = str(types2[0]) if not types2.is_empty() else "Normal"
		if used_types.has(t):
			continue
		used_types[t] = true
		_path_options.append({"species_slug": slug2, "type": t})


func _random_legendary_slug() -> String:
	var known: Array = []
	for slug_v in LEGENDARY_POOL:
		var slug: String = str(slug_v)
		var entry: Dictionary = _builder.species_entry(slug)
		if not entry.is_empty():
			known.append(slug)
	if known.is_empty():
		return ""
	return str(known[_rng.randi_range(0, known.size() - 1)])


## Fight the chosen path's battle with the engine's auto-driver
## (the holder Dynamaxes on its first opportunity). HP carries
## over between battles (sourced): the run's own mon dicts are
## handed to PUWRaidBattle without copying, and faints spend
## hearts. Returns the raid's battle_result() plus run fields.
func fight_current_battle() -> Dictionary:
	if status != "in_progress":
		return {"status": "not_in_progress"}
	if _current_boss_slug == "":
		choose_path(0)
	var final_battle: bool = is_final_next()
	var boss_mon: Dictionary = _builder.build_mon(_current_boss_slug, _level, "singles")
	var raid := PUWRaidBattle.new()
	var battle_star: int = FINAL_STAR if final_battle else _star
	raid.setup_raid(boss_mon, entries, battle_star, _rng, false)
	while not raid.is_over():
		var actions: Array = []
		for i in range(entries.size()):
			var action: Dictionary = raid.choose_action(i)
			if i == raid.dynamax_holder() and not raid.dynamax_spent():
				action["dynamax"] = true
			actions.append(action)
		raid.run_round(actions)
	var result: Dictionary = raid.battle_result()
	_battles_fought += 1
	# SOURCED: one heart lost per faint, across the whole run.
	hearts -= int(result.get("faints_used", 0))
	# A mon that ended the battle fainted starts the next battle
	# at full HP (DESIGN CONSTANT interpretation, see header).
	for e_v in entries:
		var e: Dictionary = e_v
		var m: Dictionary = e.get("mon", {})
		if int(m.get("hp", 0)) <= 0 and hearts > 0:
			m["hp"] = int(m.get("max_hp", 0))
			m["status"] = ""
	if str(result.get("status", "")) == "player_won":
		battles_won += 1
		# SOURCED: after each win you may catch the Pokemon.
		_last_catch_species = str(result.get("boss_species", ""))
		catches.append(_last_catch_species)
		_swap_used = false
		if final_battle:
			_final_done = true
			if not _endless:
				status = "cleared"
	else:
		status = "run_failed"
		fail_reason = str(result.get("lose_reason", ""))
	if hearts <= 0 and status == "in_progress":
		hearts = 0
		status = "run_failed"
		fail_reason = "hearts"
	if status == "in_progress":
		_roll_path_options()
	result["run_status"] = status
	result["hearts_left"] = hearts
	result["battles_won"] = battles_won
	result["final_battle"] = final_battle
	result["path_options"] = path_options()
	return result


## SOURCED path NPCs, rolled between battles: Berries heal,
## a Scientist offers a random-Pokemon swap (slot 0's rental),
## a Backpacker gives a held item. accept_scientist_swap only
## matters when the Scientist is rolled. Returns the event.
func roll_path_event(accept_scientist_swap: bool = false) -> Dictionary:
	if status != "in_progress":
		return {"event": "none", "reason": "run not in progress"}
	var kinds: Array = ["berries", "scientist", "backpacker"]
	var kind: String = str(kinds[_rng.randi_range(0, kinds.size() - 1)])
	var out: Dictionary = {"event": kind}
	if kind == "berries":
		# SOURCED: Berries on the path heal (amount = DESIGN
		# CONSTANT fraction).
		for e_v in entries:
			var e: Dictionary = e_v
			var m: Dictionary = e.get("mon", {})
			var heal: int = int(floor(float(int(m.get("max_hp", 0))) * BERRY_HEAL_FRACTION))
			m["hp"] = mini(int(m.get("max_hp", 0)), int(m.get("hp", 0)) + heal)
		out["healed_fraction"] = BERRY_HEAL_FRACTION
	elif kind == "scientist":
		var offer: Dictionary = _random_pool_mon({})
		out["offer_species"] = str(offer.get("species", ""))
		out["accepted"] = accept_scientist_swap
		if accept_scientist_swap:
			var slot0: Dictionary = entries[0]
			slot0["mon"] = offer
	elif kind == "backpacker":
		var slot0b: Dictionary = entries[0]
		var m0: Dictionary = slot0b.get("mon", {})
		if str(m0.get("item", "")) == "":
			m0["item"] = "Sitrus Berry"
		out["item"] = str(m0.get("item", ""))
	return out


## SOURCED: after a win, one Trainer may swap their current
## Pokemon for the fresh, fully-healed catch. Once per battle.
func swap_for_catch(entry_idx: int) -> bool:
	if _swap_used or _last_catch_species == "":
		return false
	if entry_idx < 0 or entry_idx >= entries.size():
		return false
	var slug: String = _builder.slugify(_last_catch_species)
	var fresh: Dictionary = _builder.build_mon(slug, _level, "singles")
	var entry: Dictionary = entries[entry_idx]
	entry["mon"] = fresh
	_swap_used = true
	return true


## End the run and settle it (sourced: keep exactly one of
## everything caught; Endless keeps nothing). keep_species must
## be one of catches (display name). Safe to call only once the
## run is cleared or failed; refuses while in progress.
func finish(keep_species: String) -> Dictionary:
	if status == "in_progress" or status == "not_started":
		return {"status": "still_running"}
	var kept: String = ""
	if not _endless and keep_species != "" and (keep_species in catches):
		kept = keep_species
	var released: Array = []
	for c_v in catches:
		var c: String = str(c_v)
		if c != kept:
			released.append(c)
	# DESIGN CONSTANT ore schedule (see header).
	var ore: int = battles_won * ORE_PER_WIN
	if status == "cleared":
		ore += ORE_CLEAR_BONUS
	return {
		"status": status,
		"kept_species": kept,
		"released": released,
		"catches": catches.duplicate(),
		"dynite_ore": ore,
		"battles_won": battles_won,
		"hearts_left": hearts,
		"endless": _endless,
		"fail_reason": fail_reason,
	}
