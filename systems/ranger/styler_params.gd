class_name PUWStylerParams
extends RefCounted
## RANGER VARIANT A — PER-REGION PARAMETER TABLES. **V2.**
##
## SUPERSESSION (the item-engine chain pattern): this file --
## code_prep_styler_v2/patched/systems/ranger/styler_params.gd,
## together with v2's styler_system.gd, styler_level_tables.gd
## and styler_species_data.gd -- SUPERSEDES v1's
## code_prep_styler/patched/systems/ranger/styler_params.gd
## (and v1's styler_system.gd) at bind. Bind v2, never v1.
##
## V2 applies hunt rotation 7's SOURCED data
## (hunt_desk/2026-11-23_rotation7/, Bulbapedia documentation-
## derived transcriptions; copies + SHA-256 in this prep's
## data/MANIFEST.tsv). Every value rotation 7 sourced is
## labeled SOURCED-R7 with its file + field; every value it
## contradicted has been replaced; the values it found NO
## source for stay PUW DESIGN CONSTANTS, labeled DC, with
## their v1 values unchanged. Per-region separation is
## strict throughout: fiore != almia != oblivia, and Oblivia
## present != Oblivia past, never blended.
##
## V1 provenance note (kept): every number not re-graded by
## rotation 7 traces to the mechanics register in
## ranger_deep/RANGER_DEEP.md section 1 (sources named per
## table in PREP_REPORT.md) or is a PUW DESIGN CONSTANT,
## labeled as such inline.
##
## The three games are ONE system with per-region parameters:
##   fiore   -- the loop-count model (Ranger, 2006)
##   almia   -- the Friendship Gauge + Power Charge model
##              (Shadows of Almia, 2008)
##   oblivia -- the gauge model + agitation state + Ranger
##              Points track (Guardian Signs, 2010)

# Sourced, all three games (RANGER_DEEP 1.0): the Friend roster
# caps at 7 at full progression; the Partner is separate and
# permanent, never counted against this cap.
const FRIEND_CAPACITY_MAX: int = 7

# Almia's documented Styler Power decomposition names "+ 6
# uninterrupted loops" as one component of the 1405 ceiling
# (RANGER_DEEP 1.2, Bulbapedia). The per-loop point value of
# that component is not published: DESIGN CONSTANT.
const UNINTERRUPTED_LOOP_POWER: int = 10
const UNINTERRUPTED_LOOP_CAP: int = 6

# Gauge-model Poké Assist strength: an assist adds this
# fraction of the target's friendship requirement, scaled by
# the assistant's evolutionary stage and the type matchup.
# The scaling SHAPE is sourced (stage and matchup both scale
# the effect, RANGER_DEEP 1.2); the numbers are DESIGN
# CONSTANTS.
const ASSIST_GAUGE_FRACTION: float = 0.15
const ASSIST_STAGE_MULT: Dictionary = {1: 1.0, 2: 1.75, 3: 2.5}
# Assist effect durations by evolutionary stage, seconds. The
# documented shape is "a base form's effect lasts seconds; a
# final form's can reach roughly a minute" (RANGER_DEEP 1.2):
# DESIGN CONSTANTS on that shape.
const ASSIST_STAGE_DURATION: Dictionary = {1: 10.0, 2: 25.0, 3: 50.0}
# Normal-type assist in the gauge games is "a small flat damage
# increase over no assist" (RANGER_DEEP 1.2): DESIGN CONSTANT.
const ASSIST_NORMAL_MULT: float = 1.1

# Fiore's Partner Gauge: the gauge fills as loops are drawn and
# Discharge spends it (RANGER_DEEP 1.1). Loops per gauge segment
# and stun seconds per segment are not published: DESIGN
# CONSTANTS.
const FIORE_LOOPS_PER_PARTNER_SEGMENT: int = 10
const FIORE_DISCHARGE_STUN_PER_SEGMENT: float = 5.0

# Almia / Oblivia partner assists ride a Partner Energy gauge
# that refills as loops are drawn (RANGER_DEEP 1.2: each
# partner has its own gauge length; lengths are not published).
# Fill per loop: DESIGN CONSTANT.
const PARTNER_GAUGE_FILL_PER_LOOP: float = 0.25

# Ranger Points (Oblivia) -- SOURCED-R7 economy shape, which
# REPLACES v1's design-constant grade table {S:100, A:60,
# B:30, C:10} and its 0.25 repeat fraction (both contradicted
# outright: no A/B/C-grade RP award is documented anywhere).
# Source: styler/oblivia_styler_modification.json,
# field ranger_points_economy (Bulbapedia "Styler Status"):
#   1 RP per species, first S-Rank capture only (301 species)
#   50 RP per Mission Clear, once per mission
#   10-50 RP per Quest Clear, once per quest (52 quests,
#   economy-table total 1,000 RP)
#   total available 2,101 RP vs 2,100 RP full-catalog cost.
const POINTS_PER_SRANK_SPECIES: int = 1
const POINTS_SRANK_SPECIES_TOTAL: int = 301
const POINTS_PER_MISSION_CLEAR: int = 50
const POINTS_QUEST_MIN: int = 10
const POINTS_QUEST_MAX: int = 50
const POINTS_QUEST_TOTAL: int = 1000
const POINTS_TOTAL_AVAILABLE: int = 2101
const MODIFICATION_CATALOG_TOTAL: int = 2100
# UNRESOLVED (recorded, neither figure picked): Oblivia main
# mission count -- RANGER_DEEP register says 14; rotation 7's
# economy table counts 16 Mission Clears. The economy
# arithmetic above uses the economy table's own 16 because
# 301 + 16*50 + 1000 = 2,101 is that table's internal sum;
# mission CONTENT must not treat 16 (or 14) as settled.
const OBLIVIA_MISSION_COUNT_UNRESOLVED: Dictionary = {
	"register_ranger_deep": 14, "economy_table_r7": 16, "resolved": false,
}
# Styler Modification catalog (SOURCED-R7, same file, field
# modifications): track id -> per-level RP prices in order.
# PUWStylerSpeciesData.modification_catalog_total recomputes
# the 2,100 total from the landed JSON; the v2 suite pins
# this table against it.
const MODIFICATION_TRACKS: Dictionary = {
	"energy_plus": [30, 30, 30, 30, 30, 30, 30, 40, 40, 50],
	"power_plus": [30, 30, 30, 30, 30, 30, 30, 40, 40, 50],
	"line_plus": [50, 100, 150, 200],
	"defense_plus": [80, 160, 250],
	"charge_plus": [80, 150],
	"recovery_plus": [50, 50],
	"latent_power_plus": [50, 50],
}
# Past-temple track (Oblivia): Ranger Points earned in the past
# upgrade the past Partner along Assist / Healing / Power, each
# to a maximum of level 5 (RANGER_DEEP 1.3, sourced). Cost per
# level: DESIGN CONSTANT.
const PAST_TRACK_AXES: Array = ["assist", "healing", "power"]
const PAST_TRACK_MAX: int = 5
const PAST_TRACK_COST_PER_LEVEL: int = 100

# Guardian Signs' physically-present assists: a hit assistant
# stops, flees, and must rest before assisting again
# (RANGER_DEEP 1.3). Rest length: DESIGN CONSTANT.
const ASSISTANT_REST_SECONDS: float = 10.0

# The care threshold a charged Ranger Sign is gated behind
# (ruling P7): PUW's canon friendship-evolution threshold, the
# same 160 PUWFollowerCare documents.
const CHARGED_SIGN_CARE_THRESHOLD: int = 160


const REGIONS: Dictionary = {
	"fiore": {
		"model": "loop_count",
		"progression": "rank",
		# SOURCED-R7 (styler/styler_levels.json, fiore):
		# 20 levels / 70,800 total Exp / Energy cap 60 /
		# Line cap 200 CONFIRMED (v1 GUIDE grade upgraded to
		# sourced). Bases CONTRADICTED and replaced: L1
		# Energy = 4 (v1 DC said 20); L1 Line = 100 (v1 DC
		# said 105 -- 105 is the sourced L2 value). The full
		# per-level table lives in PUWStylerLevelTables.FIORE
		# and is authoritative; these scalars are its
		# endpoints for callers that only need endpoints.
		"styler_levels": 20,
		"styler_exp_total": 70800,
		"energy_cap": 60,
		"line_cap": 200,
		"line_per_level": 5,
		"energy_base": 4,
		"line_base": 100,
		# Rank table (RANGER_DEEP 1.1, Bulbapedia/Psypokes):
		# capacity 4 at Rank 1, 5 at 4, 6 at 7, 7 at 10;
		# Partner Gauge 1 at Rank 1, then 2/3/4/5 at 3/5/7/9.
		"capacity_by_rank": {1: 4, 2: 4, 3: 4, 4: 5, 5: 5, 6: 5, 7: 6, 8: 6, 9: 6, 10: 7},
		"partner_gauge_by_rank": {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 5, 10: 5},
		"assist_unlock_rank": {
			"grass": 1, "fire": 1, "water": 1, "electric": 1,
			"fighting": 2, "poison": 3, "psychic": 3,
			"bug": 4, "ground": 4, "rock": 5, "flying": 6,
			"dark": 7, "ghost": 7, "ice": 8,
		},
		# Assist duration tiers in seconds, by type matchup
		# (RANGER_DEEP 1.1: documented tiers 10/20/30/60).
		"assist_duration_tiers": [10, 20, 30, 60],
		# Ranger regulations: Friends are released when the
		# Ranger leaves a habitat area until the finale
		# earns the right to carry them out (RANGER_DEEP 1.1).
		"habitat_release_pre_credits": true,
		"partner_kind": "fixed_by_protagonist",
		"target_tier_max": 3,
		"level_up_full_restore": false,
	},
	"almia": {
		"model": "gauge",
		"progression": "rank",
		# SOURCED-R7 (styler/styler_levels.json, almia) --
		# v1's Ranger-1 reuse (20 lv / 70,800 / cap 60 /
		# base 20) was CONTRADICTED and is replaced: 50
		# levels (the source header's "100" conflicts with
		# its own 1-50 table + level-50 max-stats section;
		# the table is landed, the conflict recorded in the
		# source file), 564,113 total Exp, Energy 10 -> 104,
		# Power 10 -> 205. Full table:
		# PUWStylerLevelTables.ALMIA (authoritative).
		"styler_levels": 50,
		"styler_exp_total": 564113,
		"energy_cap": 104,
		"energy_base": 10,
		# Power is PER-LEVEL from the sourced table (L1 =
		# 10); v1's "power_base 350" is contradicted as a
		# base and removed. The documented 1405 ceiling
		# stands as a gauge-damage ceiling including Charge,
		# uninterrupted loops and Power Plus (rotation 7
		# reading, flagged not resolved) -- it is NOT a
		# base stat and no runtime term targets it.
		"power_base": 10,
		"power_cap": 205,
		"power_maxed": 210,
		"energy_maxed": 109,
		"power_ceiling_documented": 1405,
		# Power Charge (RANGER_DEEP 1.2): hold the disc
		# still to charge, then loop for multiplied power;
		# Rank 6 shortens the ready time; Rank 8 adds a
		# further charge level. Multipliers and ready
		# times: DESIGN CONSTANTS.
		"charge_max_level": 2,
		"charge_level2_rank": 8,
		"charge_faster_rank": 6,
		"charge_mult": {1: 1.5, 2: 2.0},
		"charge_ready_seconds": 2.0,
		"charge_ready_seconds_fast": 1.0,
		# The Friendship Gauge drains while not being
		# looped (RANGER_DEEP 1.2). Rate: DESIGN CONSTANT,
		# as a fraction of the target's requirement.
		"gauge_drain_fraction_per_sec": 0.01,
		# Agitation (RANGER_DEEP 1.2): Styler power falls,
		# assist power does not. The fall's size is
		# documented only for Guardian Signs (one tenth);
		# Almia's value: DESIGN CONSTANT.
		"agitation_power_mult": 0.5,
		# Rank table (RANGER_DEEP 1.2): capacity grows 4
		# (Rank 3) -> 5 (Rank 5) -> 6 (Rank 7) -> 7
		# (Rank 9). The pre-Rank-3 base is not published;
		# 3 is a DESIGN CONSTANT chosen one below the
		# first documented milestone so every documented
		# milestone is a real increase.
		"capacity_by_rank": {1: 3, 2: 3, 3: 4, 4: 4, 5: 5, 6: 5, 7: 6, 8: 6, 9: 7, 10: 7},
		# Assist unlocks (RANGER_DEEP 1.2): Bug at Rank 1;
		# Fire/Fighting at 2; Ground/Steel at 3;
		# Poison/Ghost/Psychic/Dark at 4; Ice/Dragon at 5.
		# Types absent from the documented table are read
		# as available from Rank 1 (flagged reading, D11).
		"assist_unlock_rank": {
			"bug": 1, "normal": 1, "grass": 1, "water": 1,
			"electric": 1, "flying": 1, "rock": 1,
			"fire": 2, "fighting": 2, "ground": 3, "steel": 3,
			"poison": 4, "ghost": 4, "psychic": 4, "dark": 4,
			"ice": 5, "dragon": 5,
		},
		"habitat_release_pre_credits": false,
		"partner_kind": "roster",
		"target_tier_max": 5,
		"level_up_full_restore": false,
	},
	"oblivia": {
		"model": "gauge",
		"progression": "points",
		# SOURCED-R7 (styler/styler_levels.json,
		# oblivia_present) -- v1's series-model DC reuse
		# (20 / 70,800 / cap 60 / power 100) CONTRADICTED
		# and replaced: 99 levels (source header "100"
		# conflicts with its own 1-99 table; table landed),
		# Energy 10 -> 164, Power 10 -> 327, total Exp
		# 3,700,829. energy_base 10 CONFIRMED (matches v1's
		# walkthrough-sourced reading). Full table:
		# PUWStylerLevelTables.OBLIVIA_PRESENT.
		"styler_levels": 99,
		"styler_exp_total": 3700829,
		"energy_base": 10,
		"energy_cap": 164,
		"power_base": 10,
		"power_cap": 327,
		# Agitation (RANGER_DEEP 1.3, documented): Styler
		# Power drops to one tenth; assist power unchanged.
		"agitation_power_mult": 0.1,
		"gauge_drain_fraction_per_sec": 0.01,
		# Friend roster up to 7 (RANGER_DEEP 1.3). Growth
		# milestones are not published for this game; the
		# roster is read at the documented maximum
		# (DESIGN CONSTANT reading, flagged).
		"capacity_flat": 7,
		"assist_unlock_rank": {},
		"habitat_release_pre_credits": false,
		"partner_kind": "fixed_story",
		# Target tiers: Guardian Signs documents combined
		# clears but no tier ceiling in the register;
		# Almia's 5 is carried as a DESIGN CONSTANT.
		"target_tier_max": 5,
		"combined_clears": true,
		"assist_presence": true,
		# Leveling up restores and expands Energy
		# (RANGER_DEEP 1.3, documented for this game).
		"level_up_full_restore": true,
	},
}


# Oblivia's PAST Styler track (SOURCED-R7, styler_levels.json
# oblivia_past) -- a SEPARATE Styler that v1 did not model at
# all (v1 carried only past Partner upgrade axes). Present !=
# past: separate parameter set, separate level/exp/energy in
# the region record (PUWStylerSystem's "past_styler"
# sub-record), never blended with the present track above.
# 99 levels, Energy 30 -> 250, Power 5 -> 300, total Exp
# 547,546 -- landed AS PRINTED, including the source's
# shifted Total Exp column (L1 prints 10) and its L20 total
# (964, where 946 fits the pattern; probable source typo,
# flagged in the source file, not corrected here).
const OBLIVIA_PAST: Dictionary = {
	"styler_levels": 99,
	"styler_exp_total": 547546,
	"energy_base": 30,
	"energy_cap": 250,
	"power_base": 5,
	"power_cap": 300,
}


# --- Poké Assist vocabulary (ruling P2) -----------------------
# The documented effect language, adopted as the follower
# field-assist vocabulary. Assists NEVER enter PUW's turn-based
# battles; they name what a helper's aid does in field and
# Styler contexts.

# Fiore (RANGER_DEEP 1.1): fifteen assists; Normal, Dragon and
# Steel have none in this game. Every type assist Immobilizes
# except Ice (Frozen) and the three specials; Discharge is the
# partner's alone and recharges instead of being consumed.
const ASSISTS_FIORE: Dictionary = {
	"grass": {"state": "immobilized"},
	"fire": {"state": "immobilized"},
	"water": {"state": "immobilized"},
	"poison": {"state": "immobilized"},
	"ground": {"state": "immobilized"},
	"flying": {"state": "immobilized"},
	"rock": {"state": "immobilized"},
	"bug": {"state": "immobilized"},
	"ghost": {"state": "immobilized"},
	"psychic": {"state": "immobilized"},
	"ice": {"state": "frozen"},
	"electric": {"special": "recharge", "energy": 5},
	"fighting": {"special": "double_loops"},
	"dark": {"special": "line_for_energy"},
	"discharge": {"special": "partner_stun", "partner_only": true},
}

# Almia and Guardian Signs share the four-state table
# (RANGER_DEEP 1.2, Bulbapedia "Special Effect (Ranger)"):
# Paused = cannot use moves; Tired = the gauge stops draining;
# Slowed = movement sluggish; Stopped = cannot move or attack.
# Fighting doubles every loop's damage; Normal is a small flat
# increase. Flying, Rock and Dark carry no documented state:
# damage only.
const ASSIST_STATES_GAUGE: Dictionary = {
	"ground": "paused", "steel": "paused",
	"fire": "tired", "poison": "tired", "ghost": "tired", "dragon": "tired",
	"grass": "slowed", "water": "slowed", "bug": "slowed",
	"electric": "stopped", "psychic": "stopped", "ice": "stopped",
	"fighting": "double_damage", "normal": "flat_bonus",
	"flying": "", "rock": "", "dark": "",
}

# Field Moves and Target Clear tiers (ruling P4). Fiore's nine
# Field Moves (RANGER_DEEP 1.1): all except Flash and Cross
# come in levels 1-3; Flash and Cross carry a single level.
const FIELD_MOVES_FIORE: Dictionary = {
	"burn": 3, "cross": 1, "crush": 3, "cut": 3, "flash": 1,
	"gust": 3, "recharge": 3, "soak": 3, "tackle": 3,
}
# Almia Field Moves -- SOURCED-R7 (styler/
# field_move_assist_taxonomy.json, almia, computed from the
# 270 landed Browser rows). V1's flagged reading (every
# classic move at level 5) is CONTRADICTED and replaced:
# per-species levels vary 1-5 and caps differ per move --
# Burn/Crush/Cut/Recharge/Tackle reach 5; Electrify/Psy
# Power/Soak cap at 3; Tunnel caps at 1. GUST IS ABSENT in
# Almia (removed from the set) and Cross is not an Almia
# move; neither appears here. Per-species values are data
# (PUWStylerSpeciesData), this table is the taxonomy cap.
const FIELD_MOVES_ALMIA: Dictionary = {
	"burn": 5, "crush": 5, "cut": 5, "recharge": 5, "tackle": 5,
	"electrify": 3, "psy_power": 3, "soak": 3, "tunnel": 1,
}
# Almia's species-specific Field Moves (SOURCED-R7, same
# taxonomy): unlevelled moves carried by named species only
# (Teleport, Swim, Magma Flow, Dark Power, Fly, Rain Dance,
# Agility, Airlift, Elevate, Stink, Demist, Sand Fill, and
# Flash -- Electabuzz's species row, not a taxonomy entry).
const FIELD_MOVES_ALMIA_SPECIES_SPECIFIC: Array = [
	"agility", "airlift", "dark_power", "demist", "elevate",
	"flash", "fly", "magma_flow", "rain_dance", "sand_fill",
	"stink", "swim", "teleport",
]
# Oblivia (present) Field Moves -- SOURCED-R7 (taxonomy,
# oblivia_present, from the 279 landed rows): caps differ
# from Almia's (Burn/Crush/Cut/Tackle cap at 4 here, 5
# there -- per-region separation, never blended). Only
# species-unique move: Staraptor's Fly; Teleport is also
# species-carried.
const FIELD_MOVES_OBLIVIA: Dictionary = {
	"burn": 4, "crush": 4, "cut": 4, "tackle": 4, "recharge": 5,
	"electrify": 3, "psy_power": 3, "soak": 3,
}
const FIELD_MOVES_OBLIVIA_SPECIES_SPECIFIC: Array = ["fly", "teleport"]
# Map Moves / Area Moves (RANGER_DEEP 1.2): the traversal
# category. River Flow 1 rides a clear river; River Flow 2
# rides cold water and breaks icebergs. These slot into PUW's
# ride canon at bind.
const MAP_MOVES_ALMIA: Dictionary = {
	"river_flow": {"levels": [1, 2], "category": "map"},
}


# --- Almia's partner roster (ruling P3) -----------------------
# 17 selectable partners, one per Generation IV type
# (RANGER_DEEP 1.2): 3 starters met at Nabiki Beach, 3 gained
# in the storyline, 11 gained from Quests. Partners have no
# Field Move; their value is the assist type on call. The
# non-active partners live at the Partner Farm.
const ALMIA_PARTNERS: Array = [
	{"id": "pachirisu", "assist_type": "electric", "acquisition": "starter"},
	{"id": "starly", "assist_type": "flying", "acquisition": "starter"},
	{"id": "munchlax", "assist_type": "normal", "acquisition": "starter"},
	{"id": "kricketot", "assist_type": "bug", "acquisition": "storyline"},
	{"id": "croagunk", "assist_type": "poison", "acquisition": "storyline"},
	{"id": "mime_jr", "assist_type": "psychic", "acquisition": "storyline"},
	{"id": "turtwig", "assist_type": "grass", "acquisition": "quest"},
	{"id": "chimchar", "assist_type": "fire", "acquisition": "quest"},
	{"id": "piplup", "assist_type": "water", "acquisition": "quest"},
	{"id": "cranidos", "assist_type": "rock", "acquisition": "quest"},
	{"id": "shieldon", "assist_type": "steel", "acquisition": "quest"},
	{"id": "gible", "assist_type": "dragon", "acquisition": "quest"},
	{"id": "hippopotas", "assist_type": "ground", "acquisition": "quest"},
	{"id": "snover", "assist_type": "ice", "acquisition": "quest"},
	{"id": "machop", "assist_type": "fighting", "acquisition": "quest"},
	{"id": "sneasel", "assist_type": "dark", "acquisition": "quest"},
	{"id": "misdreavus", "assist_type": "ghost", "acquisition": "quest"},
]


# --- Transfer rewards (ruling P1) ------------------------------
# The ONLY permanent gains a Ranger region produces, and only
# through the games' own pattern: earned in a Ranger mission,
# received as a Pokemon in the wider game (RANGER_DEEP 1.1 /
# 1.2 / 1.3, the Ranger Net lists). Transfers are once-only.
# The mon templates carry identity and provenance only; the
# wider game's mon construction fills stats at bind.
const TRANSFER_REWARDS: Dictionary = {
	"manaphy_egg": {
		"species": "manaphy", "egg": true,
		"source_regions": ["fiore", "almia", "oblivia"],
		"signature_moves": [],
	},
	"aura_sphere_riolu": {
		"species": "riolu", "egg": false,
		"source_regions": ["almia"],
		"signature_moves": ["aurasphere"],
	},
	"dark_void_darkrai": {
		"species": "darkrai", "egg": false,
		"source_regions": ["almia"],
		"signature_moves": ["darkvoid"],
	},
	"deoxys": {
		"species": "deoxys", "egg": false,
		"source_regions": ["oblivia"],
		"signature_moves": [],
		"note": "Form is set by capture speed in source; the mission content decides the form at bind.",
	},
	"eruption_heatran": {
		"species": "heatran", "egg": false,
		"source_regions": ["oblivia"],
		"signature_moves": ["eruption"],
	},
	"fateful_shaymin": {
		"species": "shaymin", "egg": false,
		"source_regions": ["oblivia"],
		"signature_moves": [],
		"fateful_encounter": true,
	},
}


static func params_for(region_id: String) -> Dictionary:
	var value: Variant = REGIONS.get(region_id, {})
	if value is Dictionary:
		var params: Dictionary = value
		return params
	return {}


static func model_of(region_id: String) -> String:
	return str(params_for(region_id).get("model", ""))


static func assist_table_for(region_id: String) -> Dictionary:
	if region_id == "fiore":
		return ASSISTS_FIORE
	return ASSIST_STATES_GAUGE


static func field_moves_for(region_id: String) -> Dictionary:
	if region_id == "fiore":
		return FIELD_MOVES_FIORE
	if region_id == "almia":
		return FIELD_MOVES_ALMIA
	if region_id == "oblivia":
		return FIELD_MOVES_OBLIVIA
	return {}


static func species_specific_moves_for(region_id: String) -> Array:
	if region_id == "almia":
		return FIELD_MOVES_ALMIA_SPECIES_SPECIFIC
	if region_id == "oblivia":
		return FIELD_MOVES_OBLIVIA_SPECIES_SPECIFIC
	return []


static func almia_partner(partner_id: String) -> Dictionary:
	for entry_value: Variant in ALMIA_PARTNERS:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if str(entry.get("id", "")) == partner_id:
				return entry
	return {}
