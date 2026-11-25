class_name PUWItemServices
extends RefCounted
## Batch 5 (item triage classes c/d): the NPC-service and
## framework mechanics that are complete in helper/service
## form, following the fossil-revival service precedent.
## Every function is pure logic over mon/inventory dicts; the
## PREP_REPORT names the UI/NPC wiring each one waits on.
## No downloaded code; numbers are the games' documented ones.
##
## State-bag bindings (code prep code_prep_item_engine_gaps,
## gap G3): the services below were written against
## PUWInventoryManager, whose own demo-seeded dictionary no
## save ever read. The *_in_state entry points at the bottom
## of this file run the SAME functions against the real bag —
## state["bag"], through PUWStateBagInventory / PUWLiveBag —
## so a Bottle Cap or Heart Scale a service spends now comes
## out of the player's actual inventory. The original
## functions are unchanged; existing callers are unaffected.

# --- Hyper Training (Bottle Cap / Gold Bottle Cap) ---
# Mr. Hyper service: requires level 100 (Gen 7+ rule; Gen 8+
# lowered to 50 — DESIGN CONSTANT, current-gen ruling uses 50
# in SwSh/SV; recorded in the report). Trained stats are
# recorded in mon["hyper_trained"] and read as 31 at stat
# computation (wiring named in the report); base IVs unchanged.
const HYPERTRAIN_MIN_LEVEL := 50
const _STAT_KEYS := ["hp", "atk", "def", "spa", "spd", "spe"]

static func hyper_train(mon: Dictionary, item: String, stat: String, inventory: PUWInventoryManager, logs: Array) -> bool:
	var id: String = item.to_lower().replace("-", "").replace(" ", "")
	if id != "bottlecap" and id != "goldbottlecap":
		return false
	if int(mon.get("level", 0)) < HYPERTRAIN_MIN_LEVEL:
		return false
	var ivs: Dictionary = mon.get("ivs", {})
	var trained: Dictionary = mon.get("hyper_trained", {})
	var targets: Array = _STAT_KEYS if id == "goldbottlecap" else [stat]
	var changed: bool = false
	for k in targets:
		if int(ivs.get(k, 0)) < 31 and not bool(trained.get(k, false)):
			trained[k] = true
			changed = true
	if not changed:
		return false
	mon["hyper_trained"] = trained
	if inventory != null:
		inventory.consume_item("bottle-cap" if id == "bottlecap" else "gold-bottle-cap", 1)
	logs.append("Hyper Training complete!")
	return true

static func effective_iv(mon: Dictionary, stat: String) -> int:
	var trained: Dictionary = mon.get("hyper_trained", {})
	if bool(trained.get(stat, false)):
		return 31
	var ivs: Dictionary = mon.get("ivs", {})
	return int(ivs.get(stat, 0))

# --- Move relearner (Heart Scale) ---
# Service form: given the species' level-up learnset rows
# [{move, level}] (from LearnsetResolver data at the call
# site), returns the moves the mon could re-learn now.
static func relearnable_moves(mon: Dictionary, levelup_rows: Array) -> Array:
	var known: Array = mon.get("moves", [])
	var out: Array = []
	for row in levelup_rows:
		var mv: String = str(row.get("move", ""))
		if int(row.get("level", 999)) <= int(mon.get("level", 0)) and not known.has(mv) and not out.has(mv):
			out.append(mv)
	return out

static func relearn_move(mon: Dictionary, move_name: String, forget_index: int, levelup_rows: Array, inventory: PUWInventoryManager, logs: Array) -> bool:
	if not relearnable_moves(mon, levelup_rows).has(move_name):
		return false
	var moves: Array = mon.get("moves", [])
	if moves.size() >= 4:
		if forget_index < 0 or forget_index >= moves.size():
			return false
		moves[forget_index] = move_name
	else:
		moves.append(move_name)
	mon["moves"] = moves
	if inventory != null:
		inventory.consume_item("heart-scale", 1)
	logs.append("Learned " + move_name + "!")
	return true

# --- Shard tutor exchange (red/blue/green/yellow shards) ---
# Hoenn/Platinum shard-trade pattern: 10 shards of one colour
# buys one weather TM-class reward slot. The exchange table is
# data for the tutor NPC; the wallet logic is complete here.
const SHARD_TRADE_COST := 10
const _SHARD_TRADES := {
	"red-shard": "sunny-day", "blue-shard": "rain-dance",
	"green-shard": "sandstorm", "yellow-shard": "hail",
}

static func shard_trade_reward(shard_id: String) -> String:
	return str(_SHARD_TRADES.get(shard_id, ""))

static func can_shard_trade(shard_id: String, inventory: PUWInventoryManager) -> bool:
	return _SHARD_TRADES.has(shard_id) and inventory != null and inventory.count_item(shard_id) >= SHARD_TRADE_COST

# --- TM/TR/HM teaching service ---
# The machine->move table is per-version data and MUST be
# supplied by the caller from that version's own table
# (per-version separation is mandatory; no table is invented
# here). Learnability is decided by a caller-supplied
# can_learn callable backed by LearnsetResolver. HM rows
# teach the move only (canon #8: field actions are
# badge-gated capabilities, never the HM item).
static func machine_move(machine_id: String, version_table: Dictionary) -> String:
	return str(version_table.get(machine_id, ""))

static func teach_machine(mon: Dictionary, machine_id: String, version_table: Dictionary, can_learn: Callable, forget_index: int, logs: Array) -> Dictionary:
	var mv: String = machine_move(machine_id, version_table)
	if mv == "":
		return {"ok": false, "reason": "no_machine_data"}
	if not bool(can_learn.call(str(mon.get("species", "")), mv)):
		return {"ok": false, "reason": "cannot_learn"}
	var moves: Array = mon.get("moves", [])
	if moves.has(mv):
		return {"ok": false, "reason": "already_known"}
	if moves.size() >= 4:
		if forget_index < 0 or forget_index >= moves.size():
			return {"ok": false, "reason": "needs_forget_choice"}
		moves[forget_index] = mv
	else:
		moves.append(mv)
	mon["moves"] = moves
	logs.append("Learned " + mv + "!")
	return {"ok": true, "move": mv}

static func is_reusable_machine(machine_id: String, version: String) -> bool:
	# TMs are reusable from Gen 5 on; TRs (Galar) are single-use.
	if machine_id.begins_with("tr"):
		return false
	return version != "gen1" and version != "gen2" and version != "gen3" and version != "gen4"

# --- Roto Powers (USUM) timed-effect framework ---
# State lives on a plain dict (the save/party state at bind).
# Levels 1-3 scale the effect; durations are the games'
# documented ~3 minutes at level scaling — recorded here as
# step counts is NOT sourced, so duration is a caller-supplied
# step budget and only the multipliers (documented) are coded.
const _ROTO_MULT := {
	"roto-exp-points": 2.0, "roto-catch": 2.0, "roto-prize-money": 2.0,
	"roto-encounter": 2.0, "roto-stealth": 0.5, "roto-bargain": 0.5,
}
static func roto_activate(state: Dictionary, roto_id: String, level: int, steps: int) -> bool:
	if roto_id == "roto-hp-restore" or roto_id == "roto-pp-restore" or roto_id == "roto-friendship":
		return false # instant-effect Roto Powers: handled by roto_instant
	var active: Dictionary = state.get("roto_active", {})
	active[roto_id] = {"level": clampi(level, 1, 3), "steps_left": steps}
	state["roto_active"] = active
	return true

static func roto_multiplier(state: Dictionary, roto_id: String) -> float:
	var active: Dictionary = state.get("roto_active", {})
	if not active.has(roto_id):
		return 1.0
	var base: float = float(_ROTO_MULT.get(roto_id, 1.0))
	var lvl: int = int(active[roto_id].get("level", 1))
	# Level scaling: L1 = base at half strength toward the cap,
	# documented direction only — exact per-level factors are
	# not in held sources, so L2/L3 use the documented cap and
	# L1 returns the midpoint. Flagged in the report.
	if base > 1.0:
		return base if lvl >= 2 else 1.0 + (base - 1.0) * 0.5
	return base if lvl >= 2 else 1.0 - (1.0 - base) * 0.5

static func roto_tick(state: Dictionary) -> void:
	var active: Dictionary = state.get("roto_active", {})
	for k in active.keys():
		var rec: Dictionary = active[k]
		rec["steps_left"] = int(rec.get("steps_left", 0)) - 1
		if int(rec["steps_left"]) <= 0:
			active.erase(k)
	state["roto_active"] = active

static func roto_instant(roto_id: String, mon: Dictionary, logs: Array) -> bool:
	if roto_id == "roto-hp-restore":
		var maxhp: int = int(mon.get("max_hp", 0))
		if maxhp <= 0 or int(mon.get("hp", 0)) >= maxhp:
			return false
		mon["hp"] = maxhp
		logs.append("HP was restored!")
		return true
	if roto_id == "roto-pp-restore":
		var pp: Dictionary = mon.get("pp", {})
		var maxpp: Dictionary = mon.get("pp_max", {})
		var changed: bool = false
		for mv in maxpp:
			if int(pp.get(mv, 0)) < int(maxpp[mv]):
				pp[mv] = int(maxpp[mv])
				changed = true
		if changed:
			mon["pp"] = pp
			logs.append("PP was restored!")
		return changed
	if roto_id == "roto-friendship":
		mon["friendship"] = mini(255, int(mon.get("friendship", 0)) + 30)
		logs.append("Friendship rose!")
		return true
	return false

# --- Poke Radar chain (helper state machine) ---
# Chain state on a plain dict; shiny odds composition rides
# the existing ShinyOdds channel at the encounter site
# (wiring named in the report). Chain caps at 40 (Gen 6+).
static func radar_record_encounter(state: Dictionary, species: String, caught_or_defeated: bool) -> int:
	if not caught_or_defeated:
		state["radar_chain"] = 0
		state["radar_species"] = ""
		return 0
	if str(state.get("radar_species", "")) == species:
		state["radar_chain"] = mini(40, int(state.get("radar_chain", 0)) + 1)
	else:
		state["radar_species"] = species
		state["radar_chain"] = 1
	return int(state["radar_chain"])

static func radar_break_chain(state: Dictionary) -> void:
	state["radar_chain"] = 0
	state["radar_species"] = ""

# --- Dowsing Machine reading (pure geometry) ---
# Returns {"direction": 8-way string, "distance": steps} to
# the nearest hidden item, or {} when none is in range.
static func dowsing_reading(player_pos: Vector2i, hidden_positions: Array, max_range: int = 12) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 30
	for raw in hidden_positions:
		var pos: Vector2i = raw
		var d: int = absi(pos.x - player_pos.x) + absi(pos.y - player_pos.y)
		if d < best_d and d <= max_range:
			best_d = d
			var dx: int = signi(pos.x - player_pos.x)
			var dy: int = signi(pos.y - player_pos.y)
			var dir: String = ""
			if dy < 0: dir += "north"
			elif dy > 0: dir += "south"
			if dx < 0: dir += "west"
			elif dx > 0: dir += "east"
			if dir == "": dir = "here"
			best = {"direction": dir, "distance": d}
	return best

static func signi(v: int) -> int:
	return 0 if v == 0 else (1 if v > 0 else -1)

# --- Coin Case wallet (Game Corner coin economy core) ---
const COIN_CASE_CAP := 50000 # Gen 4+ case capacity (Gen 3: 9999 — version note in report)
static func coin_add(wallet: Dictionary, amount: int) -> int:
	var cur: int = int(wallet.get("coins", 0))
	var added: int = mini(amount, COIN_CASE_CAP - cur)
	wallet["coins"] = cur + maxi(0, added)
	return maxi(0, added)
static func coin_spend(wallet: Dictionary, amount: int) -> bool:
	if int(wallet.get("coins", 0)) < amount:
		return false
	wallet["coins"] = int(wallet.get("coins", 0)) - amount
	return true

# --- Fishing rods (class d, seam-ready: encounter tables are
# staged and PUWHabitatEncounters maps the fishing env) ---
const _ROD_TIERS := {"old-rod": 1, "good-rod": 2, "super-rod": 3, "fishing-rod": 2}
static func rod_tier(item: String) -> int:
	return int(_ROD_TIERS.get(item, 0))

# --- Discount Coupon (Kalos boutique, planned wardrobe economy) ---
static func coupon_price(price: int, has_coupon: bool) -> int:
	return price / 2 if has_coupon else price

# --- Trackers with pure-logic cores (UI screens are the named
# program; the data cores are complete here) ---
static func unown_report(caught_forms: Array) -> Dictionary:
	var seen: Dictionary = {}
	for f in caught_forms:
		seen[str(f)] = true
	return {"caught": seen.size(), "total": 28, "forms": seen}

static func vs_seeker_charge(state: Dictionary, steps_taken: int) -> bool:
	# Vs. Seeker recharges after 100 steps (documented).
	return steps_taken - int(state.get("vs_seeker_last_use_step", -1000000)) >= 100

# --- Program-blocked registry (honest stubs) ---
# Every class-(c)/(d) item NOT implemented above maps to the
# named program it waits on. Querying an implemented item
# returns "". This table is the in-code stub: no item is
# silently skipped and none is faked.
const PROGRAM_BLOCKED := {
	"town-map": "world-map screen program", "town_map": "world-map screen program",
	"roller-skates": "player-controller locomotion program (skate mode)",
	"gb-sounds": "GB Sounds 8-bit audio program (HGSS)",
	"lock-capsule": "move-teaching program (TM95 distribution container)",
	"ride-pager": "Alola Poke Ride content program",
	"explorer-kit": "Grand Underground content program",
	"odd-keystone": "Grand Underground + Sinnoh content program",
	"devon-scope": "Hoenn content program",
	"eon-flute": "ORAS soaring content program",
	"nature-pass": "BW2 Nature Preserve content program",
	"pass": "Kalos TMV content program",
	"glimmering-charm": "Tera Raid program (VEXA gap G4)",
	"go-goggles": "Hoenn content program",
	"suite-key": "Sinnoh content program",
	"secret-key": "forme-change program wiring (Rotom room, Sinnoh) + DPPt content",
	"coin-case": "Game Corner economy program (wallet core implemented: coin_add/coin_spend)",
	"discount-coupon": "wardrobe/boutique economy program (price core implemented: coupon_price)",
	"max-mushrooms": "Isle of Armor Master Dojo program",
	"wishing-chip": "Max Raid den program (VEXA gap G4)",
	"wishing-piece": "Max Raid den program (VEXA gap G4)",
	"dynite-ore": "Crown Tundra content program",
	"armorite-ore": "Isle of Armor content program",
	"shoal-salt": "Hoenn Shoal Cave content program",
	"shoal-shell": "Hoenn Shoal Cave content program",
	"galarica-twig": "Isle of Armor content program",
}
static func blocked_program_for(item: String) -> String:
	return str(PROGRAM_BLOCKED.get(item, ""))

# --- State-bag bindings (code_prep_item_engine_gaps, gap G3) ---
# Each wrapper builds the state-bag adapter over the caller's
# save state and runs the bound function above through it, so
# the item a service consumes is consumed from state["bag"]
# (both id spellings are the one stack PUWLiveBag counts) and
# a service the state cannot pay for refuses untouched.
# ItemEngine.use_tera_shard needs no wrapper: it already takes
# a PUWInventoryManager, so PUWStateBagInventory.new(state)
# binds it to the real bag as-is.
#
# Payment guard: the bound functions consume AFTER acting and
# do not check the consume's result (against the demo manager
# a failed consume was invisible). Against the real bag that
# would teach/train for free, so each wrapper first proves
# the state holds the item the bound function will spend;
# the bound functions themselves are unchanged.

static func hyper_train_in_state(mon: Dictionary, item: String, stat: String, state: Dictionary, logs: Array) -> bool:
	var adapter: PUWStateBagInventory = PUWStateBagInventory.new(state)
	var id: String = item.to_lower().replace("-", "").replace(" ", "")
	var pay_id: String = "gold-bottle-cap" if id == "goldbottlecap" else "bottle-cap"
	if adapter.count_item(pay_id) < 1:
		adapter.free()
		return false
	var done: bool = hyper_train(mon, item, stat, adapter, logs)
	adapter.free()
	return done

static func relearn_move_in_state(mon: Dictionary, move_name: String, forget_index: int, levelup_rows: Array, state: Dictionary, logs: Array) -> bool:
	var adapter: PUWStateBagInventory = PUWStateBagInventory.new(state)
	if adapter.count_item("heart-scale") < 1:
		adapter.free()
		return false
	var done: bool = relearn_move(mon, move_name, forget_index, levelup_rows, adapter, logs)
	adapter.free()
	return done

static func can_shard_trade_in_state(shard_id: String, state: Dictionary) -> bool:
	var adapter: PUWStateBagInventory = PUWStateBagInventory.new(state)
	var ok: bool = can_shard_trade(shard_id, adapter)
	adapter.free()
	return ok
