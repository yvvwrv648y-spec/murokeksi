class_name PUWRematchSystem
extends RefCounted
## Trainer rematch system (Vs. Seeker) — code prep, staging only.
## The program that batch 5's Vs. Seeker CORE in
## PUWItemServices.vs_seeker_charge() waits on (batch-5 report:
## "HELPER COMPLETE (100-step recharge rule); the trainer-rematch
## reset flow is the named program").
##
## ADOPTED MODEL: FRLG (the Vs. Seeker's origin version and the
## model batch 5's core encodes), implemented in full. DPPt /
## Platinum is implemented as a SEPARATE profile with its own
## sourced constants — per-version separation is mandatory and
## the two models are never blended (see PREP_REPORT.md for the
## full provenance table). Later rematch devices (Emerald Match
## Call, ORAS Trainers' Eyes, HGSS phone, BW2, XY Battle Chateau,
## LGPE, SwSh, SV) are different systems, not Vs. Seeker
## variants, and are NOT implemented here.
##
## All mechanics below were read from held game source under
## Riley's standing mechanics authorization (reading only; no
## downloaded code was built or run):
##   FRLG:     pret/pokefirered src/vs_seeker.c
##   Platinum: pokeplatinum src/overlay005/vs_seeker.c +
##             include/constants/vs_seeker.h
##
## State lives on a plain Dictionary (the save state at bind):
##   state["rematch"] = {
##     "trainers": { trainer_key: {
##        "defeated": bool,            # original battle won
##        "highest_tier_fought": int,  # tier index; 0 = original
##        "wants_rematch": bool,       # set by a successful scan
##        "active_tier": int,          # tier offered; -1 = none
##        "rematches_won": int, "rematches_lost": int,
##        "last_rematch": {"tier": int, "result": String,
##                         "step": int} } },
##     "vs_seeker": {"charge": int, "total_steps": int,
##                   "active_steps_left": int,
##                   "vs_seeker_last_use_step": int} }
## Tier tables are CALLER-SUPPLIED per region (never invented):
##   tables = { trainer_key: {"region": String,
##     "tiers": [ tier0, tier1, ... ] } }
##   tier = {"trainer_id": String,
##           "party": [{"species": String, "level": int,
##                      "iv": int}],
##           "prize_base": int}
##   A tier slot may be null: FRLG's SKIP / Platinum's NONE hole.
##   Tier 0 is the original party; rematch tiers start at 1.
##   A tier whose trainer_id equals tier 0's is the games'
##   "no unique rematch" row (e.g. FRLG Calvin) and never counts
##   as a new tier.
##
## DIFFICULTY — PM RULING D4 (2026-11-23, applying Riley's
## restatement of 23:13 CST; RULES_REFRESHER.md §11 D4): tier
## tables supply SPECIES / IDENTITY ONLY. A tier party's
## "species" is the build input; its "level" and "iv" fields
## are IDENTITY-HISTORY — the source game's recorded values for
## that tier, kept as provenance — and are NEVER build values.
## No battle party is ever fielded from a tier row directly.
## BIND INSTRUCTION: at battle time the caller takes the
## selected tier's identity (tier_party_identity() below —
## species plus any Moemon variant marker, nothing else) and
## builds the battle party through the difficulty layer's ONE
## entry point, PUWDifficultyLayer.build_party_from_identity()
## (landed in code_prep_difficulty; consumed verbatim by this
## prep under patched/systems/difficulty/), or equivalently via
## build_rematch_party() below. The layer delegates to
## PUWTeamBuilder, which fields exactly 6 Pokémon at
## IV 31 in every stat, EV spread = each species' best sourced
## set under the 510 cap, best nature/ability/moveset (egg
## moves included where the sourced set carries them), level
## scaled to the player, species auto-evolved at the built
## level with the set re-sourced on evolution (EV
## redistribution happens only where the evolved species' own
## sourced set differs — it is the builder's behaviour, never a
## tier-table edit). This applies identically to Pokémon and
## Moemon parties: Moemon mirror PKDX stats/moves/evolutions,
## so the same builder and the same sourced sets produce
## Moemon rematch parties at the identical standard (the layer
## wraps an MDX identity's mon on the family axis only) — there
## is no separate, weaker Moemon path.
##
## CANON: a rematch is an ordinary world battle, NOT a VEXA
## simulation. battle_context() always returns simulation=false
## and permadeath_applies=true, and record_rematch_result()
## refuses a simulation context outright. This system never
## reads or writes Champion/region-lock state: rematches grant
## no badges, no progression flags, and no region unlocks.
##
## GSC PHONE PROFILE (gsc_phone) — Crystal's Pokégear phone
## rematches, implemented in this same file as a third profile
## (code_prep_gsc_phone). NOT a Vs. Seeker variant: Crystal
## has no seeker, no charge counter and no area scan. The
## mechanics were read from held pokecrystal source (reading
## only, same authorization as above):
##   engine/phone/phone.asm          (CheckPhoneCall,
##     GetAvailableCallers, ChooseRandomCaller,
##     Script_ReceivePhoneCall, AddPhoneNumber, DelCellNum)
##   engine/overworld/time.asm       (CheckReceiveCallTimer;
##     .ReceiveCallDelays db 20, 10, 5, 3 — MINUTES)
##   data/phone/phone_contacts.asm   (the 28 trainer
##     contacts; every caller time is ANYTIME)
##   constants/phone_constants.asm   (CONTACT_LIST_SIZE 10)
##   engine/phone/scripts/*.asm      (per-contact caller
##     scripts; a WantsToBattle branch sets the contact's
##     ENGINE_<NAME>_READY_FOR_REMATCH flag)
##   maps/<Map>.asm                  (per-contact trainer
##     scripts: the post-battle number exchange, the
##     w<Name>FightCount ladder, and each fight's
##     checkevent/checkflag story gate)
## Tier data is caller-supplied from the Johto prep's tables
## (code_prep_johto_fixes: rematch_tables_johto.json +
## phone_contact_tier_mapping.json): per-contact gates are
## the mapping's VERBATIM Crystal event names and the ladder
## order is the mapping's proven Fight0..FightN order. D4
## applies unchanged: the phone path builds every battle
## party through build_rematch_party() / the difficulty
## layer from tier identity only.
##
## Phone state lives in the same state["rematch"] root:
##   state["rematch"]["phone"] = {
##     "cycles_since_last_call": int,  # 0..3, delay index
##     "call_delay_left": int }        # minutes remaining
## and per-trainer phone fields on the shared record:
##   "phone_registered": bool,  # number exchanged
##   "phone_ready": bool,       # the READY_FOR_REMATCH flag
##   "phone_fight_count": int,  # w<Name>FightCount
##   "phone_active_tier": int,  # tier served at begin; -1
##   "phone_top_served": bool } # top tier already served
## Caller-supplied contacts (built from the mapping file):
##   contacts = { trainer_key: {
##     "caller_id": "PHONE_SCHOOLBOY_JACK",
##     "map": "national_park",
##     "caller_time": "ANYTIME",
##     "ladder_wired": bool,
##     "wants_battle_chance": int,  # percent, script-derived
##     "gates": {tier_index: "EVENT_..." } } }

# --- Per-version profiles (sourced; NOT blended) ---
# FRLG (pokefirered/src/vs_seeker.c):
#   * charge counter caps at 100 steps (UpdateVsSeekerStepCounter,
#     trainerRematchStepCounter low byte < 100).
#   * willingness: Random()%100, refuse when < 30 => 70% yes
#     (GetVsSeekerResponseInArea). A duplicate of the same trainer
#     visible twice resolves YES for the first instance already
#     accepted and NO for the duplicate (GetCurVsSeekerResponse).
#   * a successful use starts a charging window; when its second
#     100-step counter completes, ClearAllTrainerRematchStates()
#     wipes every wants-rematch state (UpdateVsSeekerStepCounter).
#   * use is refused where the map type is not route/town/city,
#     and in Viridian Forest / Mt. Ember exterior / Berry Forest /
#     Pattern Bush (item_use.c FieldUseFunc_VsSeeker) — the
#     caller passes map_allowed; this system enforces the flag.
# Platinum (pokeplatinum/src/overlay005/vs_seeker.c):
#   * VS_SEEKER_MAX_BATTERY 100, +1 per step while the item is
#     held (VsSeeker_UpdateStepCount); use zeroes the battery.
#   * VS_SEEKER_REMATCH_CHANCE 50 (50% willingness).
#   * VS_SEEKER_MAX_NUM_ACTIVE_STEPS 100 (active window).
#   * search radius: left 7, right 7, up 7, down 6 tiles.
#   * result codes in include/constants/vs_seeker.h: OK /
#     NO_BATTERY / NO_TRAINERS / NO_TRAINERS_PICKED.
const PROFILES: Dictionary = {
	"frlg": {
		"charge_max": 100, "willing_chance": 70, "active_steps": 100,
		"max_tier_index": 5, "scan_mode": "visible_flag",
		"radius_left": 0, "radius_right": 0, "radius_up": 0, "radius_down": 0,
	},
	"dppt": {
		"charge_max": 100, "willing_chance": 50, "active_steps": 100,
		"max_tier_index": 5, "scan_mode": "radius",
		"radius_left": 7, "radius_right": 7, "radius_up": 7, "radius_down": 6,
	},
	# GSC phone (pokecrystal): no charge exists (charge_max 0
	# is inert — the phone path never reads it) and there is
	# no scan (scan_mode "incoming_call"); readiness never
	# expires (active_steps 0 is inert — phone_begin_rematch
	# consults no window). max_tier_index 4 = the longest
	# held ladder (Fight0..Fight4, five tiers incl. original).
	"gsc_phone": {
		"charge_max": 0, "willing_chance": 100, "active_steps": 0,
		"max_tier_index": 4, "scan_mode": "incoming_call",
		"radius_left": 0, "radius_right": 0, "radius_up": 0, "radius_down": 0,
	},
}

# FRLG tier progression gates (TryGetRematchTrainerIdGivenGameState
# in pokefirered/src/vs_seeker.c): tier index -> progression flag
# that must be set for that tier to be selectable. Tier 1 needs
# FLAG_GOT_VS_SEEKER, 2 FLAG_WORLD_MAP_CELADON_CITY,
# 3 FLAG_WORLD_MAP_FUCHSIA_CITY, 4 FLAG_SYS_GAME_CLEAR,
# 5 FLAG_SYS_CAN_LINK_WITH_RS. Flag names here are PUW-side
# spellings of those source flags (caller supplies its own set).
const FRLG_TIER_GATES: Dictionary = {
	1: "got_vs_seeker", 2: "world_map_celadon", 3: "world_map_fuchsia",
	4: "game_clear", 5: "can_link_rs",
}
# Platinum tier ("level") gates: FLAG_UNLOCKED_VS_SEEKER_LVL_1..5,
# set by story scripts at Route 207 (L1), Celestic Town (L2),
# Spear Pillar (L3), Hall of Fame (L4), Stark Mountain (L5) —
# res/field/maps/*/scripts.s in the held pokeplatinum tree.
# The highest unlocked level caps the selectable tier index.
const DPPT_LEVEL_FLAGS: Array = [
	"unlocked_vs_seeker_lvl_1", "unlocked_vs_seeker_lvl_2",
	"unlocked_vs_seeker_lvl_3", "unlocked_vs_seeker_lvl_4",
	"unlocked_vs_seeker_lvl_5",
]

# GSC phone constants (pokecrystal, cited in the header):
#   * .ReceiveCallDelays (engine/overworld/time.asm): the
#     receive-call delay in MINUTES, indexed by
#     wTimeCyclesSinceLastCall (capped at 3): the longer the
#     player goes without a received call, the shorter the
#     delay until the next call opportunity.
#   * CONTACT_LIST_SIZE 10 (constants/phone_constants.asm):
#     the phone list holds at most 10 registered numbers;
#     the ask flow refuses a new one when full.
#   * The default wants-battle chance covers wired contacts
#     whose caller script this prep did not reduce to a
#     number; it is the modal wired pattern (two sequential
#     PhoneScript_Random2 gates: 1/2 x 1/2 = 25%). Proven
#     per-contact values are caller data (Jack 25 —
#     scripts/jack.asm; Joey 67 — scripts/joey.asm Random3
#     with two of three outcomes; Parry 100 —
#     scripts/parry.asm Random2 with both outcomes).
const PHONE_CALL_DELAYS: Array = [20, 10, 5, 3]
const PHONE_LIST_CAPACITY: int = 10
const PHONE_DEFAULT_WANTS_BATTLE_CHANCE: int = 25

static func profile(profile_name: String) -> Dictionary:
	var p: Dictionary = PROFILES.get(profile_name, {})
	return p

static func ensure_state(state: Dictionary) -> Dictionary:
	var root: Dictionary = state.get("rematch", {})
	if not root.has("trainers"):
		root["trainers"] = {}
	if not root.has("vs_seeker"):
		root["vs_seeker"] = {"charge": 0, "total_steps": 0,
			"active_steps_left": 0, "vs_seeker_last_use_step": -1000000}
	if not root.has("phone"):
		root["phone"] = {"cycles_since_last_call": 0,
			"call_delay_left": int(PHONE_CALL_DELAYS[0])}
	state["rematch"] = root
	return root

static func _trainers(state: Dictionary) -> Dictionary:
	var root: Dictionary = ensure_state(state)
	var t: Dictionary = root["trainers"]
	return t

static func _seeker(state: Dictionary) -> Dictionary:
	var root: Dictionary = ensure_state(state)
	var s: Dictionary = root["vs_seeker"]
	return s

static func trainer_record(state: Dictionary, trainer_key: String) -> Dictionary:
	var t: Dictionary = _trainers(state)
	var rec: Dictionary = t.get(trainer_key, {})
	return rec

# --- Registry: first-battle bookkeeping ---
# Records the ORIGINAL battle (tier 0). Only a win makes a
# trainer rematch-eligible (both source games gate on
# HasTrainerBeenFought / Script_IsTrainerDefeated).
static func record_battle_result(state: Dictionary, trainer_key: String, won: bool, step: int) -> Dictionary:
	if won:
		var t: Dictionary = _trainers(state)
		var rec: Dictionary = t.get(trainer_key, {})
		rec["defeated"] = true
		rec["highest_tier_fought"] = maxi(0, int(rec.get("highest_tier_fought", 0)))
		if not rec.has("rematches_won"):
			rec["rematches_won"] = 0
		if not rec.has("rematches_lost"):
			rec["rematches_lost"] = 0
		if not rec.has("wants_rematch"):
			rec["wants_rematch"] = false
		if not rec.has("active_tier"):
			rec["active_tier"] = -1
		t[trainer_key] = rec
		var root: Dictionary = ensure_state(state)
		root["trainers"] = t
		state["rematch"] = root
	return {"ok": won, "reason": "" if won else "battle_lost"}

static func is_defeated(state: Dictionary, trainer_key: String) -> bool:
	var rec: Dictionary = trainer_record(state, trainer_key)
	return bool(rec.get("defeated", false))

# --- Tier selection ---
# The gate cap for a profile: FRLG = highest tier index whose
# gate flag is set (tier 1 also requires its flag; with no flags
# the cap is 0, i.e. no rematch tier is selectable yet — exactly
# the source walk-down to 0). Platinum = highest unlocked level.
static func tier_cap(profile_name: String, progression: Dictionary) -> int:
	if profile_name == "gsc_phone":
		# Gates are PER-CONTACT story events, enforced by
		# phone_next_tier(); the global cap is the profile's
		# ladder maximum.
		var gsc_p: Dictionary = profile(profile_name)
		return int(gsc_p.get("max_tier_index", 4))
	if profile_name == "dppt":
		var cap: int = 0
		for i in DPPT_LEVEL_FLAGS.size():
			if bool(progression.get(str(DPPT_LEVEL_FLAGS[i]), false)):
				cap = i + 1
		return cap
	var frlg_cap: int = 0
	for idx in FRLG_TIER_GATES.keys():
		var tier_idx: int = int(idx)
		if bool(progression.get(str(FRLG_TIER_GATES[idx]), false)):
			frlg_cap = maxi(frlg_cap, tier_idx)
	return frlg_cap

# First defined, unique, not-yet-fought tier at or below the
# gate cap. Holes (null) and same-id rows are skipped, as in
# both sources. FLAGGED READING (see report): when the first
# unfought tier sits ABOVE the cap, the source walk-down can
# land on an already-fought lower tier; PUW instead reports
# "progression_locked" and offers nothing — a rematch must be a
# new party, never a silent replay of a fought one.
static func next_tier(state: Dictionary, trainer_key: String, tables: Dictionary, progression: Dictionary, profile_name: String) -> Dictionary:
	if not is_defeated(state, trainer_key):
		return {"ok": false, "reason": "not_defeated", "tier_index": -1}
	if not tables.has(trainer_key):
		return {"ok": false, "reason": "not_in_table", "tier_index": -1}
	var entry: Dictionary = tables[trainer_key]
	var tiers: Array = entry.get("tiers", [])
	if tiers.size() < 2:
		return {"ok": false, "reason": "no_rematch_tiers", "tier_index": -1}
	var base_id: String = ""
	var tier0: Dictionary = tiers[0]
	base_id = str(tier0.get("trainer_id", ""))
	var rec: Dictionary = trainer_record(state, trainer_key)
	var fought: int = int(rec.get("highest_tier_fought", 0))
	var p: Dictionary = profile(profile_name)
	var hard_max: int = mini(int(p.get("max_tier_index", 5)), tiers.size() - 1)
	var cap: int = tier_cap(profile_name, progression)
	var first_unfought: int = -1
	var i: int = 1
	while i <= hard_max:
		var raw: Variant = tiers[i]
		if raw != null:
			var tier: Dictionary = raw
			if str(tier.get("trainer_id", "")) != base_id and i > fought:
				first_unfought = i
				break
		i += 1
	if first_unfought == -1:
		return {"ok": false, "reason": "no_next_tier", "tier_index": -1}
	if first_unfought > cap:
		return {"ok": false, "reason": "progression_locked", "tier_index": first_unfought}
	return {"ok": true, "reason": "", "tier_index": first_unfought}

static func eligibility(state: Dictionary, trainer_key: String, tables: Dictionary, progression: Dictionary, profile_name: String) -> Dictionary:
	var n: Dictionary = next_tier(state, trainer_key, tables, progression, profile_name)
	return {"eligible": bool(n.get("ok", false)), "reason": str(n.get("reason", "")),
		"tier_index": int(n.get("tier_index", -1))}

# The ONLY battle-facing extractions from a tier (PM ruling
# D4, 2026-11-23): the tier's identity, in party order. The
# tier's level/iv fields are identity-history (provenance)
# and are deliberately NOT returned — a battle party is built
# from this identity by the difficulty layer at battle time,
# never fielded from the tier row itself.
static func tier_species_identity(tier: Dictionary) -> Array:
	var out: Array = []
	var src_party: Array = tier.get("party", [])
	for mon in src_party:
		var m: Dictionary = mon
		var sp: String = str(m.get("species", ""))
		if not sp.is_empty():
			out.append(sp)
	return out

# Identity in the difficulty layer's input shape
# (PUWDifficultyLayer): one Dictionary per party slot carrying
# ONLY "species" plus, when the tier row marks the slot as a
# Moemon variant, its "variant" / "family" / "dex_family"
# marker. Every other stored field — level, iv, moves,
# held_item, form, ball_seal — is provenance and is dropped
# here, so no stored build value can reach the builder even
# by accident.
static func tier_party_identity(tier: Dictionary) -> Array:
	var out: Array = []
	var src_party: Array = tier.get("party", [])
	for mon in src_party:
		var m: Dictionary = mon
		var sp: String = str(m.get("species", ""))
		if sp.is_empty():
			continue
		var identity: Dictionary = {"species": sp}
		for key in ["variant", "family", "dex_family"]:
			var marker: String = str(m.get(key, ""))
			if not marker.is_empty():
				identity[key] = marker
		out.append(identity)
	return out

# THE rematch party-construction path (PM ruling D4): build
# the battle party for a selected tier through the difficulty
# layer's one entry point. The tier supplies identity only
# (tier_party_identity); PUWDifficultyLayer /
# PUWTeamBuilder supply every build value — exactly 6 mons,
# IV 31 in every stat, the final species' best sourced set
# under the 510 EV cap, level = the player's max, auto-evolve
# with the set re-sourced. Pokémon and Moemon tiers route
# through this same call; an MDX identity's mon differs from
# its PKDX build on the family axis only.
static func build_rematch_party(tier: Dictionary, player_max_level: int, mode: String, rng: RandomNumberGenerator) -> Array:
	var layer: PUWDifficultyLayer = PUWDifficultyLayer.new()
	return layer.build_party_from_identity(tier_party_identity(tier), player_max_level, mode, rng)

# Returns a deep copy of the selected tier's party so battle
# code can never mutate the caller's table. NOTE (D4): the
# returned party is IDENTITY data (species + the source's
# recorded level/iv history). It is NOT a battle party — route
# it through build_rematch_party() (tier_party_identity() +
# PUWDifficultyLayer) before any battle (see the header's D4
# bind instruction).
static func select_rematch_party(state: Dictionary, trainer_key: String, tables: Dictionary, progression: Dictionary, profile_name: String) -> Dictionary:
	var n: Dictionary = next_tier(state, trainer_key, tables, progression, profile_name)
	if not bool(n.get("ok", false)):
		return {"ok": false, "reason": str(n.get("reason", "")), "tier_index": -1, "party": []}
	var tier_idx: int = int(n["tier_index"])
	var entry: Dictionary = tables[trainer_key]
	var tiers: Array = entry["tiers"]
	var tier: Dictionary = tiers[tier_idx]
	var party_copy: Array = []
	var src_party: Array = tier.get("party", [])
	for mon in src_party:
		var m: Dictionary = mon
		party_copy.append(m.duplicate(true))
	return {"ok": true, "reason": "", "tier_index": tier_idx,
		"trainer_id": str(tier.get("trainer_id", "")),
		"party": party_copy, "prize_base": int(tier.get("prize_base", 0))}

# --- Charge / step flow (wired to batch 5's core) ---
# One overworld step. Mirrors UpdateVsSeekerStepCounter (FRLG)
# and VsSeeker_UpdateStepCount (Platinum): charge +1 per step
# while the item is held, capped at charge_max; the active
# window counts down and, on expiry, ALL wants-rematch states
# are cleared. Returns true only on the expiring step.
# Also keeps the batch-5 core in agreement: the flat
# vs_seeker_last_use_step is maintained so
# PUWItemServices.vs_seeker_charge(flat, total_steps) gives the
# same charged answer as is_charged() for the FRLG profile.
static func on_step(state: Dictionary, has_vs_seeker: bool, profile_name: String = "frlg") -> bool:
	var p: Dictionary = profile(profile_name)
	var s: Dictionary = _seeker(state)
	s["total_steps"] = int(s.get("total_steps", 0)) + 1
	if has_vs_seeker and int(s.get("charge", 0)) < int(p.get("charge_max", 100)):
		s["charge"] = int(s.get("charge", 0)) + 1
	s["vs_seeker_last_use_step"] = int(s["total_steps"]) - int(s.get("charge", 0))
	var expired: bool = false
	if int(s.get("active_steps_left", 0)) > 0:
		s["active_steps_left"] = int(s.get("active_steps_left", 0)) - 1
		if int(s.get("active_steps_left", 0)) <= 0:
			clear_all_wants(state)
			expired = true
	var root: Dictionary = ensure_state(state)
	root["vs_seeker"] = s
	state["rematch"] = root
	return expired

static func charge_amount(state: Dictionary) -> int:
	var s: Dictionary = _seeker(state)
	return int(s.get("charge", 0))

static func is_charged(state: Dictionary, profile_name: String = "frlg") -> bool:
	var p: Dictionary = profile(profile_name)
	return charge_amount(state) >= int(p.get("charge_max", 100))

static func steps_until_charged(state: Dictionary, profile_name: String = "frlg") -> int:
	var p: Dictionary = profile(profile_name)
	return maxi(0, int(p.get("charge_max", 100)) - charge_amount(state))

static func clear_all_wants(state: Dictionary) -> void:
	var t: Dictionary = _trainers(state)
	for key in t.keys():
		var rec: Dictionary = t[key]
		rec["wants_rematch"] = false
		rec["active_tier"] = -1
		t[key] = rec
	var root: Dictionary = ensure_state(state)
	root["trainers"] = t
	state["rematch"] = root

# Map-change reset: MapResetTrainerRematches (FRLG) clears the
# charging state and every rematch state. PUW reading: leaving
# the area ends the active window early.
static func on_map_reset(state: Dictionary) -> void:
	var s: Dictionary = _seeker(state)
	s["active_steps_left"] = 0
	var root: Dictionary = ensure_state(state)
	root["vs_seeker"] = s
	state["rematch"] = root
	clear_all_wants(state)

# --- Vs. Seeker use flow ---
# nearby: [{trainer_key, visible: bool, dx: int, dy: int}]
#   FRLG scan_mode "visible_flag": the caller (overworld) marks
#   on-screen trainers visible, as IsTrainerVisibleOnScreen does.
#   DPPt scan_mode "radius": dx/dy are trainer-minus-player tile
#   offsets, checked against the sourced radius.
# rolls: {trainer_key: int 0..99} — the game's RNG draw for that
#   trainer, injected so this system stays deterministic and
#   testable (the sources draw Random()%100 per candidate).
#   A candidate with no supplied roll is refused with reason
#   "no_roll_supplied" rather than silently defaulted.
# map_allowed: FRLG's map-type / excluded-area gate.
# Charge consumption follows the sources: a use that reaches
# the area scan (at least one trainer in range, fought or not)
# consumes the charge — FRLG resets the in-bag counter in
# Task_VsSeeker_2 once CanUseVsSeeker passes, Platinum zeroes
# the battery when the use starts. A use refused as
# not_charged or no_one_in_range keeps the charge.
static func use_vs_seeker(state: Dictionary, nearby: Array, tables: Dictionary, progression: Dictionary, profile_name: String, rolls: Dictionary, map_allowed: bool = true) -> Dictionary:
	var p: Dictionary = profile(profile_name)
	if p.is_empty():
		return {"ok": false, "reason": "unknown_profile", "willing": [], "refused": {}}
	if str(p.get("scan_mode", "")) == "incoming_call":
		# The phone profile has no seeker use; readiness
		# arrives by incoming call (phone_try_incoming_call).
		return {"ok": false, "reason": "phone_profile_uses_calls", "willing": [], "refused": {}}
	if not map_allowed:
		return {"ok": false, "reason": "map_not_allowed", "willing": [], "refused": {}}
	if not is_charged(state, profile_name):
		return {"ok": false, "reason": "not_charged", "willing": [], "refused": {},
			"steps_remaining": steps_until_charged(state, profile_name)}
	var in_range: Array = []
	for raw in nearby:
		var n: Dictionary = raw
		if _in_scan_range(n, p):
			in_range.append(n)
	if in_range.is_empty():
		return {"ok": false, "reason": "no_one_in_range", "willing": [], "refused": {}}
	# Charge is consumed from here on (source behaviour above).
	var s: Dictionary = _seeker(state)
	s["charge"] = 0
	s["vs_seeker_last_use_step"] = int(s.get("total_steps", 0))
	var root0: Dictionary = ensure_state(state)
	root0["vs_seeker"] = s
	state["rematch"] = root0
	var willing: Array = []
	var refused: Dictionary = {}
	var saw_unfought: bool = false
	var seen: Dictionary = {}
	for raw2 in in_range:
		var n2: Dictionary = raw2
		var key: String = str(n2.get("trainer_key", ""))
		if key == "":
			continue
		if seen.has(key):
			refused[key] = "duplicate_instance"
			continue
		seen[key] = true
		if not is_defeated(state, key):
			refused[key] = "not_defeated"
			saw_unfought = true
			continue
		var sel: Dictionary = next_tier(state, key, tables, progression, profile_name)
		if not bool(sel.get("ok", false)):
			refused[key] = str(sel.get("reason", ""))
			continue
		if not rolls.has(key):
			refused[key] = "no_roll_supplied"
			continue
		var roll: int = int(rolls[key])
		if roll < int(p.get("willing_chance", 70)):
			var t: Dictionary = _trainers(state)
			var rec: Dictionary = t[key]
			rec["wants_rematch"] = true
			rec["active_tier"] = int(sel["tier_index"])
			t[key] = rec
			var root: Dictionary = ensure_state(state)
			root["trainers"] = t
			state["rematch"] = root
			willing.append(key)
		else:
			refused[key] = "declined_roll"
	if not willing.is_empty():
		var s2: Dictionary = _seeker(state)
		s2["active_steps_left"] = int(p.get("active_steps", 100))
		var root2: Dictionary = ensure_state(state)
		root2["vs_seeker"] = s2
		state["rematch"] = root2
		return {"ok": true, "reason": "found_rematches", "willing": willing, "refused": refused}
	if saw_unfought and refused.size() == in_range.size():
		return {"ok": false, "reason": "unfought_in_range", "willing": [], "refused": refused}
	return {"ok": false, "reason": "no_trainers_picked", "willing": [], "refused": refused}

static func _in_scan_range(nearby_entry: Dictionary, p: Dictionary) -> bool:
	if str(p.get("scan_mode", "")) == "radius":
		var dx: int = int(nearby_entry.get("dx", 9999))
		var dy: int = int(nearby_entry.get("dy", 9999))
		if dx < 0 and absi(dx) > int(p.get("radius_left", 7)):
			return false
		if dx > 0 and dx > int(p.get("radius_right", 7)):
			return false
		if dy < 0 and absi(dy) > int(p.get("radius_up", 7)):
			return false
		if dy > 0 and dy > int(p.get("radius_down", 6)):
			return false
		return true
	return bool(nearby_entry.get("visible", false))

# --- Battle launch + result (canon path) ---
# The ONLY battle context this system will ever produce:
# an ordinary story/world battle. simulation is hard-false;
# permadeath applies exactly as in any story battle.
static func battle_context(trainer_key: String, tier_index: int) -> Dictionary:
	return {"simulation": false, "permadeath_applies": true,
		"battle_kind": "rematch", "trainer_key": trainer_key,
		"tier_index": tier_index, "grants_progression": false,
		"region_lock_bypass": false}

static func begin_rematch(state: Dictionary, trainer_key: String, tables: Dictionary, progression: Dictionary, profile_name: String) -> Dictionary:
	var rec: Dictionary = trainer_record(state, trainer_key)
	if not bool(rec.get("wants_rematch", false)):
		return {"ok": false, "reason": "not_willing"}
	var s: Dictionary = _seeker(state)
	if int(s.get("active_steps_left", 0)) <= 0:
		return {"ok": false, "reason": "window_expired"}
	var sel: Dictionary = select_rematch_party(state, trainer_key, tables, progression, profile_name)
	if not bool(sel.get("ok", false)):
		return sel
	if int(sel["tier_index"]) != int(rec.get("active_tier", -1)):
		return {"ok": false, "reason": "tier_changed_since_scan"}
	sel["context"] = battle_context(trainer_key, int(sel["tier_index"]))
	return sel

# Prize money for a won rematch, through batch 5's seam:
# ItemEngine.prize_money_multiplier (Amulet Coin / Luck Incense
# holder participated => x2) and, when a Roto state is supplied,
# PUWItemServices.roto_multiplier for "roto-prize-money".
# base is the tier's caller-supplied prize_base (per-version
# trainer-class money data is a later data drop; no base is
# invented here — a tier without one pays 0).
static func prize_money(party_mons: Array, tier: Dictionary, roto_state: Dictionary = {}) -> int:
	var base: int = int(tier.get("prize_base", 0))
	if base <= 0:
		return 0
	var mult: float = ItemEngine.prize_money_multiplier(party_mons)
	if not roto_state.is_empty():
		mult *= PUWItemServices.roto_multiplier(roto_state, "roto-prize-money")
	return int(round(float(base) * mult))

# Records a finished rematch. A simulation context is REFUSED:
# rematches never run as simulations, so a result claiming one
# is a wiring error, not data. On a win the fought tier
# advances; on a loss it does not. Either way the trainer's
# wants-rematch state is cleared (FRLG's
# ClearRematchStateByTrainerId after a rematch battle).
static func record_rematch_result(state: Dictionary, trainer_key: String, won: bool, step: int, context: Dictionary) -> Dictionary:
	if bool(context.get("simulation", false)):
		return {"ok": false, "reason": "simulation_context_refused"}
	if str(context.get("battle_kind", "")) != "rematch":
		return {"ok": false, "reason": "not_a_rematch_context"}
	var t: Dictionary = _trainers(state)
	if not t.has(trainer_key):
		return {"ok": false, "reason": "unknown_trainer"}
	var rec: Dictionary = t[trainer_key]
	if not bool(rec.get("wants_rematch", false)):
		return {"ok": false, "reason": "not_willing"}
	var tier_idx: int = int(rec.get("active_tier", -1))
	rec["last_rematch"] = {"tier": tier_idx, "result": "won" if won else "lost", "step": step}
	if won:
		rec["highest_tier_fought"] = maxi(int(rec.get("highest_tier_fought", 0)), tier_idx)
		rec["rematches_won"] = int(rec.get("rematches_won", 0)) + 1
	else:
		rec["rematches_lost"] = int(rec.get("rematches_lost", 0)) + 1
	rec["wants_rematch"] = false
	rec["active_tier"] = -1
	t[trainer_key] = rec
	var root: Dictionary = ensure_state(state)
	root["trainers"] = t
	state["rematch"] = root
	return {"ok": true, "reason": "", "tier_index": tier_idx}

# ============================================================
# GSC PHONE PROFILE — Crystal's Pokégear phone rematches.
# The flow mirrors pokecrystal end to end (citations inline):
#   first battle won -> talk -> number exchange (register)
#   -> time passes (the receive-call delay) -> an incoming
#   call may set the contact READY (their caller script's
#   WantsToBattle branch) -> the player visits the contact
#   and talks -> the ladder cascade serves the highest tier
#   at or below the FightCount whose story gate is open ->
#   battle (D4 build path) -> the FightCount advances.
# Where Crystal and the Vs. Seeker profiles conflict,
# Crystal wins HERE and the difference is documented at the
# function. The seeker path above is untouched.
# ============================================================

static func _phone_root(state: Dictionary) -> Dictionary:
	var root: Dictionary = ensure_state(state)
	var ph: Dictionary = root["phone"]
	return ph

static func _store_phone_root(state: Dictionary, ph: Dictionary) -> void:
	var root: Dictionary = ensure_state(state)
	root["phone"] = ph
	state["rematch"] = root

static func _store_rec(state: Dictionary, trainer_key: String, rec: Dictionary) -> void:
	var t: Dictionary = _trainers(state)
	t[trainer_key] = rec
	var root: Dictionary = ensure_state(state)
	root["trainers"] = t
	state["rematch"] = root

# The shared trainer record plus this profile's phone
# fields, default-filled. Mirrors Crystal keeping the READY
# flag and the FightCount in per-contact storage that is
# independent of the phone list itself.
static func _phone_rec(state: Dictionary, trainer_key: String) -> Dictionary:
	var rec: Dictionary = trainer_record(state, trainer_key)
	if not rec.has("phone_registered"):
		rec["phone_registered"] = false
	if not rec.has("phone_ready"):
		rec["phone_ready"] = false
	if not rec.has("phone_fight_count"):
		rec["phone_fight_count"] = 0
	if not rec.has("phone_active_tier"):
		rec["phone_active_tier"] = -1
	if not rec.has("phone_top_served"):
		rec["phone_top_served"] = false
	return rec

static func _phone_reset_call_delay(state: Dictionary) -> void:
	var ph: Dictionary = _phone_root(state)
	ph["cycles_since_last_call"] = 0
	ph["call_delay_left"] = int(PHONE_CALL_DELAYS[0])
	_store_phone_root(state, ph)

# --- First battle + registration ---
# Crystal: the number exchange happens in the contact's own
# map script AFTER the first battle (the trainer macro's
# post-battle script: checkcellnum, then
# askforphonenumber). Registration is never automatic and
# never happens for an undefeated trainer. The player may
# decline and be asked again on a later talk
# (EVENT_<NAME>_ASKED_FOR_PHONE_NUMBER) — that prompt flow
# is the caller's; this function is the acceptance seam
# (AddPhoneNumber in engine/phone/phone.asm).
static func phone_record_first_battle(state: Dictionary, trainer_key: String, won: bool, step: int) -> Dictionary:
	var res: Dictionary = record_battle_result(state, trainer_key, won, step)
	if won:
		var rec: Dictionary = _phone_rec(state, trainer_key)
		_store_rec(state, trainer_key, rec)
	return res

static func phone_registered_count(state: Dictionary) -> int:
	var t: Dictionary = _trainers(state)
	var n: int = 0
	for key in t.keys():
		var rec: Dictionary = t[key]
		if bool(rec.get("phone_registered", false)):
			n += 1
	return n

static func phone_register_contact(state: Dictionary, trainer_key: String) -> Dictionary:
	if not is_defeated(state, trainer_key):
		return {"ok": false, "reason": "not_defeated"}
	var rec: Dictionary = _phone_rec(state, trainer_key)
	if bool(rec["phone_registered"]):
		return {"ok": false, "reason": "already_registered"}
	# CONTACT_LIST_SIZE (constants/phone_constants.asm): the
	# source refuses a new number when the list is full
	# (PHONE_CONTACTS_FULL in the ask flow).
	if phone_registered_count(state) >= PHONE_LIST_CAPACITY:
		return {"ok": false, "reason": "phone_list_full"}
	rec["phone_registered"] = true
	_store_rec(state, trainer_key, rec)
	return {"ok": true, "reason": ""}

# DelCellNum (engine/phone/phone.asm): removes the number
# from the list ONLY. Crystal's READY flag and FightCount
# live outside the list and survive a delete/re-register
# cycle; so do PUW's.
static func phone_delete_contact(state: Dictionary, trainer_key: String) -> Dictionary:
	var rec: Dictionary = _phone_rec(state, trainer_key)
	if not bool(rec["phone_registered"]):
		return {"ok": false, "reason": "not_registered"}
	rec["phone_registered"] = false
	_store_rec(state, trainer_key, rec)
	return {"ok": true, "reason": ""}

static func phone_contact_info(state: Dictionary, trainer_key: String, contacts: Dictionary) -> Dictionary:
	var rec: Dictionary = trainer_record(state, trainer_key)
	var c: Dictionary = contacts.get(trainer_key, {})
	return {"trainer_key": trainer_key,
		"caller_id": str(c.get("caller_id", "")),
		"map": str(c.get("map", "")),
		"ladder_wired_in_crystal": bool(c.get("ladder_wired", true)),
		"defeated": bool(rec.get("defeated", false)),
		"registered": bool(rec.get("phone_registered", false)),
		"ready": bool(rec.get("phone_ready", false)),
		"fight_count": int(rec.get("phone_fight_count", 0))}

# --- Receive-call delay (the phone's "recharge") ---
# CheckReceiveCallTimer (engine/overworld/time.asm): when
# the delay (wReceiveCallDelay_MinsRemaining, in MINUTES)
# expires, wTimeCyclesSinceLastCall increments (cap 3) and
# the delay restarts from .ReceiveCallDelays[cycles]
# (20, 10, 5, 3). Each expiry opens ONE call opportunity
# (CheckPhoneCall proceeds in the same tick). A RECEIVED
# call resets the cycle count to 0 (Script_ReceivePhoneCall
# ends in InitCallReceiveDelay), so the next delay is 20
# again. There is no step counter and no battery: time is
# the recharge, and readiness itself never expires — the
# READY flag stays set until the rematch is fought (nothing
# in Crystal clears it otherwise). Both points deliberately
# diverge from the Vs. Seeker profiles; Crystal wins here.
# Returns the number of call opportunities opened by this
# tick; the caller attempts at most one incoming call per
# opportunity via phone_try_incoming_call().
static func phone_call_timer_tick(state: Dictionary, minutes: int) -> int:
	var ph: Dictionary = _phone_root(state)
	var cycles: int = int(ph.get("cycles_since_last_call", 0))
	var delay: int = int(ph.get("call_delay_left", int(PHONE_CALL_DELAYS[0])))
	if delay <= 0:
		delay = int(PHONE_CALL_DELAYS[mini(cycles, 3)])
	var opportunities: int = 0
	var mins: int = maxi(0, minutes)
	while mins > 0:
		if mins < delay:
			delay -= mins
			mins = 0
		else:
			mins -= delay
			opportunities += 1
			cycles = mini(3, cycles + 1)
			delay = int(PHONE_CALL_DELAYS[cycles])
	ph["cycles_since_last_call"] = cycles
	ph["call_delay_left"] = delay
	_store_phone_root(state, ph)
	return opportunities

# --- Incoming calls (CheckPhoneCall) ---
# GetAvailableCallers (engine/phone/phone.asm): a
# registered contact can call when their caller time window
# matches the current time of day (the contact's
# PHONE_CONTACT_SCRIPT2_TIME ANDed with the current time;
# every held trainer contact is ANYTIME in
# data/phone/phone_contacts.asm) and the player is NOT on
# the contact's own map (map group+number equality excludes
# them). Non-trainer callers (Mom, Elm, Bill) are story
# systems outside this profile.
static func phone_available_callers(state: Dictionary, contacts: Dictionary, current_map: String, time_of_day: String) -> Array:
	var out: Array = []
	for key in contacts.keys():
		var k: String = str(key)
		var c: Dictionary = contacts[key]
		var rec: Dictionary = trainer_record(state, k)
		if not bool(rec.get("phone_registered", false)):
			continue
		var window: String = str(c.get("caller_time", "ANYTIME"))
		if window != "ANYTIME" and window != time_of_day:
			continue
		if str(c.get("map", "")) == current_map:
			continue
		out.append(k)
	return out

# One incoming-call attempt, mirroring CheckPhoneCall from
# its .timecheck onward (the caller owns the timer and
# calls this once per opened opportunity):
#   * standing on an entrance -> no call;
#   * a 50% coin flip (Random: the drawn byte's top bit
#     must be clear) — flip_roll 0 proceeds, 1 declines;
#   * the map must have phone service (GetMapPhoneService
#     must report service);
#   * the caller is chosen uniformly from the available
#     callers (ChooseRandomCaller: a 0..31 draw modulo the
#     available count) — pick_roll is that draw;
#   * the call CONNECTS: the receive-call delay resets and
#     the chosen contact's caller script resolves its
#     content. A contact already READY produces a generic
#     call (their WaitingForBattle branch). A WIRED contact
#     that is not ready sets READY when the script's
#     WantsToBattle branch is drawn — content_roll (0..99)
#     under the contact's script-derived
#     wants_battle_chance.
#   * The four UNWIRED contacts (mapping:
#     ladder_wired_in_crystal false — BEVERLY, IRWIN,
#     DEREK, KENJI) have NO caller-script battle branch in
#     Crystal at all: their calls are item/rumor content
#     and no *_READY_FOR_REMATCH flag exists for them.
#     PUW-side rule, labeled as such and NOT Crystal
#     wiring: a connected call from an unwired contact
#     readies them, so the profile's identity-table
#     consumption (the Johto fixes disposition: all 28
#     contacts are consumed) reaches them. Their ladder
#     order is the mapping's derived order and their gate
#     set is empty — nothing beyond this readiness rule is
#     invented for them.
static func phone_try_incoming_call(state: Dictionary, contacts: Dictionary, ctx: Dictionary, flip_roll: int, pick_roll: int, content_roll: int) -> Dictionary:
	if bool(ctx.get("on_entrance", false)):
		return {"ok": false, "reason": "on_entrance", "contact": ""}
	if not bool(ctx.get("map_has_service", true)):
		return {"ok": false, "reason": "no_phone_service", "contact": ""}
	if flip_roll != 0:
		return {"ok": false, "reason": "call_coin_flip", "contact": ""}
	var avail: Array = phone_available_callers(state, contacts,
		str(ctx.get("current_map", "")), str(ctx.get("time_of_day", "ANYTIME")))
	if avail.is_empty():
		return {"ok": false, "reason": "no_available_callers", "contact": ""}
	var idx: int = absi(pick_roll) % avail.size()
	var key: String = str(avail[idx])
	_phone_reset_call_delay(state)
	var rec: Dictionary = _phone_rec(state, key)
	if bool(rec["phone_ready"]):
		return {"ok": true, "reason": "", "kind": "generic_call", "contact": key}
	var c: Dictionary = contacts[key]
	if not bool(c.get("ladder_wired", true)):
		rec["phone_ready"] = true
		_store_rec(state, key, rec)
		return {"ok": true, "reason": "", "kind": "rematch_ready",
			"contact": key, "via": "puw_unwired_rule"}
	var chance: int = int(c.get("wants_battle_chance", PHONE_DEFAULT_WANTS_BATTLE_CHANCE))
	if content_roll < chance:
		rec["phone_ready"] = true
		_store_rec(state, key, rec)
		return {"ok": true, "reason": "", "kind": "rematch_ready",
			"contact": key, "via": "caller_script"}
	return {"ok": true, "reason": "", "kind": "generic_call", "contact": key}

# --- Ladder cascade (the contact's own map script) ---
# When the player talks to a READY contact, Crystal reads
# w<Name>FightCount and cascades DOWN from it: the highest
# fight at or below the count whose per-fight story gate
# (checkevent/checkflag, verbatim in the mapping) is open
# is served; fight 0 has no gate, so a ready contact always
# serves SOMETHING — including, by design, the first-battle
# party again as the first rematch, and a repeat of a lower
# tier while the frontier tier's gate is still closed.
# DIVERGENCE FROM THE VS. SEEKER PATH, deliberate: the
# shared next_tier() refuses "progression_locked" and never
# repeats a fought tier (the recorded PM reading for the
# seeker profiles). Crystal's phone cascade does the
# opposite, and for this profile Crystal wins — the cascade
# is implemented here, separately, and the seeker path is
# untouched. Per-contact gates replace the seeker profiles'
# global tier gates entirely.
static func phone_next_tier(state: Dictionary, trainer_key: String, tables: Dictionary, contacts: Dictionary, progression: Dictionary) -> Dictionary:
	if not is_defeated(state, trainer_key):
		return {"ok": false, "reason": "not_defeated", "tier_index": -1}
	var rec: Dictionary = trainer_record(state, trainer_key)
	if not bool(rec.get("phone_registered", false)):
		return {"ok": false, "reason": "not_registered", "tier_index": -1}
	if not tables.has(trainer_key):
		return {"ok": false, "reason": "not_in_table", "tier_index": -1}
	var entry: Dictionary = tables[trainer_key]
	var tiers: Array = entry.get("tiers", [])
	if tiers.is_empty():
		return {"ok": false, "reason": "no_tiers", "tier_index": -1}
	var contact: Dictionary = contacts.get(trainer_key, {})
	var gates: Dictionary = contact.get("gates", {})
	var top: int = tiers.size() - 1
	var f: int = int(rec.get("phone_fight_count", 0))
	var frontier: int = mini(f, top)
	var served: int = 0
	var j: int = frontier
	while j >= 1:
		var gate: String = str(gates.get(j, gates.get(str(j), "")))
		if gate.is_empty() or bool(progression.get(gate, false)):
			served = j
			break
		j -= 1
	var frontier_gate: String = ""
	if served < frontier:
		frontier_gate = str(gates.get(frontier, gates.get(str(frontier), "")))
	var is_repeat: bool = served < f or served == 0
	if served == top and bool(rec.get("phone_top_served", false)):
		is_repeat = true
	return {"ok": true, "reason": "", "tier_index": served,
		"frontier_tier": frontier, "frontier_gated": served < frontier,
		"frontier_gate": frontier_gate, "is_repeat": is_repeat}

# Talk to a READY contact: the cascade picks the tier NOW
# (Crystal computes it at talk time from the FightCount and
# the gate cascade — there is no offered-tier window and no
# expiry). Returns the tier's IDENTITY data (deep-copied;
# D4: build the battle party via build_rematch_party(),
# never from this dict) plus the canon battle context.
static func phone_begin_rematch(state: Dictionary, trainer_key: String, tables: Dictionary, contacts: Dictionary, progression: Dictionary) -> Dictionary:
	var rec: Dictionary = _phone_rec(state, trainer_key)
	if not bool(rec["phone_ready"]):
		return {"ok": false, "reason": "not_ready", "tier_index": -1}
	var n: Dictionary = phone_next_tier(state, trainer_key, tables, contacts, progression)
	if not bool(n.get("ok", false)):
		return {"ok": false, "reason": str(n.get("reason", "")), "tier_index": -1}
	var tier_idx: int = int(n["tier_index"])
	var entry: Dictionary = tables[trainer_key]
	var tiers: Array = entry["tiers"]
	var tier: Dictionary = tiers[tier_idx]
	var party_copy: Array = []
	var src_party: Array = tier.get("party", [])
	for mon in src_party:
		var m: Dictionary = mon
		party_copy.append(m.duplicate(true))
	rec["phone_active_tier"] = tier_idx
	_store_rec(state, trainer_key, rec)
	return {"ok": true, "reason": "", "tier_index": tier_idx,
		"trainer_id": str(tier.get("trainer_id", "")),
		"party": party_copy, "prize_base": int(tier.get("prize_base", 0)),
		"is_repeat": bool(n.get("is_repeat", false)),
		"frontier_gated": bool(n.get("frontier_gated", false)),
		"context": battle_context(trainer_key, tier_idx)}

# Records a finished phone rematch. Same canon guards as
# record_rematch_result() (a simulation context is refused
# outright; a rematch is an ordinary world battle). On a
# WIN the FightCount advances exactly as the source
# script's loadmem lines do: FightCount := served tier + 1,
# except at the top tier, whose LoadFight script sets no
# new count (the top party is re-served on every later
# ready call). On a LOSS the count does not advance.
# Either way READY clears — the source script clears it
# after the battle lines.
# DOCUMENTED READING: the source's loadmem/clearflag lines
# sit after startbattle unconditionally, but a loss blacks
# the player out and warps them away, so whether they run
# after a loss is not observable from the script text; the
# profile follows the shared system's rule (win advances,
# loss does not; readiness clears either way).
static func phone_record_result(state: Dictionary, trainer_key: String, tables: Dictionary, won: bool, step: int, context: Dictionary) -> Dictionary:
	if bool(context.get("simulation", false)):
		return {"ok": false, "reason": "simulation_context_refused"}
	if str(context.get("battle_kind", "")) != "rematch":
		return {"ok": false, "reason": "not_a_rematch_context"}
	var t: Dictionary = _trainers(state)
	if not t.has(trainer_key):
		return {"ok": false, "reason": "unknown_trainer"}
	var rec: Dictionary = _phone_rec(state, trainer_key)
	if not bool(rec["phone_ready"]):
		return {"ok": false, "reason": "not_ready"}
	var tier_idx: int = int(rec["phone_active_tier"])
	if tier_idx < 0:
		return {"ok": false, "reason": "no_active_tier"}
	rec["last_rematch"] = {"tier": tier_idx,
		"result": "won" if won else "lost", "step": step}
	if won:
		rec["rematches_won"] = int(rec.get("rematches_won", 0)) + 1
		var entry: Dictionary = tables.get(trainer_key, {})
		var tiers: Array = entry.get("tiers", [])
		var top: int = tiers.size() - 1
		if tier_idx < top:
			rec["phone_fight_count"] = tier_idx + 1
		elif top >= 0:
			rec["phone_fight_count"] = top
			rec["phone_top_served"] = true
	else:
		rec["rematches_lost"] = int(rec.get("rematches_lost", 0)) + 1
	rec["phone_ready"] = false
	rec["phone_active_tier"] = -1
	_store_rec(state, trainer_key, rec)
	return {"ok": true, "reason": "", "tier_index": tier_idx}
