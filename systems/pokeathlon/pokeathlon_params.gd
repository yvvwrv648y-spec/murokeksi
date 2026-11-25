class_name PUWPokeathlonParams
extends RefCounted
## POKEATHLON PARAMETER TABLES (code prep, 2026-11-23).
## Provenance tags: [HELD] = staged PKHeX save-structure tree
## (data_registry/src/pkhex/.../Gen4/Pokeathlon/, READ as format
## documentation); [PUB] = public reference (Bulbapedia / Ultimate
## Pokemon Center archive, fetched 2026-11-23) -- documented
## reference, NOT extracted data; [DC] = PUW design constant.
## See DESIGN.md in this prep for the full survey.

# Performance stat ids [HELD: PokeathlonStat4 enum order].
const STAT_SPEED: int = 0
const STAT_POWER: int = 1
const STAT_SKILL: int = 2
const STAT_STAMINA: int = 3
const STAT_JUMP: int = 4
const STAT_COUNT: int = 5
const STAT_IDS: Array = ["speed", "power", "skill", "stamina", "jump"]

# Event ids [HELD: PokeathlonEvent4 enum order].
const EVENT_HURDLE_DASH: int = 0
const EVENT_PENNANT_CAPTURE: int = 1
const EVENT_CIRCLE_PUSH: int = 2
const EVENT_BLOCK_SMASH: int = 3
const EVENT_DISC_CATCH: int = 4
const EVENT_LAMP_JUMP: int = 5
const EVENT_RELAY_RUN: int = 6
const EVENT_RING_DROP: int = 7
const EVENT_SNOW_THROW: int = 8
const EVENT_GOAL_ROLL: int = 9
const EVENT_COUNT: int = 10
const EVENT_IDS: Array = [
	"hurdle_dash", "pennant_capture", "circle_push", "block_smash",
	"disc_catch", "lamp_jump", "relay_run", "ring_drop",
	"snow_throw", "goal_roll",
]

# Courses [PUB]: five courses, three events each, in course order
# (flagged reading F1 in DESIGN.md). Course id == its medal stat.
const COURSE_IDS: Array = ["speed", "power", "skill", "stamina", "jump"]
const COURSES: Dictionary = {
	"speed": ["hurdle_dash", "pennant_capture", "relay_run"],
	"power": ["block_smash", "circle_push", "goal_roll"],
	"skill": ["snow_throw", "goal_roll", "pennant_capture"],
	"stamina": ["ring_drop", "relay_run", "block_smash"],
	"jump": ["lamp_jump", "disc_catch", "hurdle_dash"],
}

# Per-event data [PUB]: performance stats used (in documented
# effect order), duration seconds (0 = fixed course, -6 rounds
# encoded as 0 for circle_push with a note), record thresholds
# (raw metric for 1st-place record / Potential trophy).
const EVENTS: Dictionary = {
	"hurdle_dash": {
		"stats": ["speed", "jump", "skill"], "duration_s": 0,
		"record": 100.0, "potential": 80.0, "lower_is_better": true,
		"no_miss": "no hurdles broken",
	},
	"pennant_capture": {
		"stats": ["speed", "skill", "power", "stamina"], "duration_s": 60,
		"record": 35.0, "potential": 50.0, "lower_is_better": false,
		"no_miss": "no flags taken via tackling",
	},
	"circle_push": {
		"stats": ["speed", "power", "stamina"], "duration_s": 0,
		"record": 40.0, "potential": 60.0, "lower_is_better": false,
		"no_miss": "never fell off the stage",
	},
	"block_smash": {
		"stats": ["power", "stamina", "skill"], "duration_s": 30,
		"record": 80.0, "potential": 130.0, "lower_is_better": false,
		"no_miss": "never fainted (minigame stun)",
	},
	"disc_catch": {
		"stats": ["speed", "jump", "power"], "duration_s": 60,
		"record": 40.0, "potential": 70.0, "lower_is_better": false,
		"no_miss": "did not fall off the stage",
	},
	"lamp_jump": {
		"stats": ["jump", "skill", "stamina"], "duration_s": 60,
		"record": 350.0, "potential": 500.0, "lower_is_better": false,
		"no_miss": "did not faint from a collision (minigame stun)",
	},
	"relay_run": {
		"stats": ["speed", "stamina", "skill", "power"], "duration_s": 90,
		"record": 12.0, "potential": 16.0, "lower_is_better": false,
		"no_miss": "never fainted (minigame stun)",
	},
	"ring_drop": {
		"stats": ["power", "stamina", "speed", "jump"], "duration_s": 60,
		"record": 70.0, "potential": 100.0, "lower_is_better": false,
		"no_miss": "never knocked off the stage and never fainted",
	},
	"snow_throw": {
		"stats": ["skill", "power", "stamina"], "duration_s": 60,
		"record": 30.0, "potential": 55.0, "lower_is_better": false,
		"no_miss": "never fainted from a snowball (minigame stun)",
	},
	"goal_roll": {
		"stats": ["speed", "skill", "power", "stamina"], "duration_s": 90,
		"record": 3.0, "potential": 9.0, "lower_is_better": false,
		"no_miss": "never fainted and never scored an own goal",
	},
}

# Points wallet cap [HELD: Pokeathlon4.MaxPoints].
const MAX_POINTS: int = 99999
# Per-event Athlete Points cap [PUB].
const EVENT_POINTS_CAP: int = 200
# Win bonus by mode [PUB].
const WIN_BONUS: Dictionary = {"single": 100, "supreme": 300, "link": 500}
# End-of-course bonuses [PUB].
const CHALLENGE_BONUS_BASE: int = 75
const NO_MISS_BONUS: int = 10
const LEADING_BONUS: int = 20
const EFFORT_BONUS: int = 10
# Collective Trophy threshold [PUB].
const COLLECTIVE_TROPHY_SCORE: int = 420
# Friendship Trophy global-score thresholds [HELD:
# Pokeathlon4.FriendshipTrophyThresholds].
const FRIENDSHIP_TROPHY_THRESHOLDS: Array = [3000, 3100, 3200, 3300, 3400, 3600, 3800, 4000, 4200, 4500]
# Trust Trophy Medalist-species thresholds [PUB].
const TRUST_TROPHY_THRESHOLDS: Array = [1, 2, 5, 10, 25, 50, 75, 100, 150, 200]
# Data Cards [HELD: DataCard4.Count = 27]. Price [DC]: no price
# exists in held material; cards are bought with points [HELD].
const DATA_CARD_COUNT: int = 27
const DATA_CARD_PRICE: int = 200
# Athlete Shop daily purchases [HELD: 12 bits].
const DAILY_SHOP_SLOTS: int = 12
# Counter caps [HELD: PokeathlonGlobalCounters4 / EventData4].
const MAX_COUNTER: int = 9999999
const MAX_ATTEMPTS: int = 9999999
const MAX_TIME_MINUTES: int = 59999
# Aprijuice [HELD byte shape: flavor cap 63, level cap 100;
# price clamp 100..5000 from fame].
const FLAVOR_CAP: int = 63
const JUICE_LEVEL_CAP: int = 100
const JUICE_PRICE_MIN: int = 100
const JUICE_PRICE_MAX: int = 5000
const MILDNESS_CAP: int = 255
const BLENDER_CAPACITY: int = 5
const JUICE_USES_PER_BLEND: int = 3

# Nature Z table [PUB, UPC]: per nature, {raised stat: +Z,
# lowered stat: -Z}; neutral natures use 10, the rest 35. The
# raised performance stat follows the raised battle stat
# (Spe->speed, Atk->power, SpD->skill, Def->stamina, SpA->jump).
const NATURE_Z: Dictionary = {
	"hardy": {"power": 10, "speed": -10},
	"docile": {"stamina": 10, "jump": -10},
	"serious": {"speed": 10, "skill": -10},
	"bashful": {"jump": 10, "power": -10},
	"quirky": {"skill": 10, "stamina": -10},
	"lonely": {"power": 35, "stamina": -35},
	"brave": {"power": 35, "speed": -35},
	"adamant": {"power": 35, "jump": -35},
	"naughty": {"power": 35, "skill": -35},
	"bold": {"stamina": 35, "power": -35},
	"relaxed": {"stamina": 35, "speed": -35},
	"impish": {"stamina": 35, "jump": -35},
	"lax": {"stamina": 35, "skill": -35},
	"timid": {"speed": 35, "power": -35},
	"hasty": {"speed": 35, "stamina": -35},
	"jolly": {"speed": 35, "jump": -35},
	"naive": {"speed": 35, "skill": -35},
	"modest": {"jump": 35, "power": -35},
	"mild": {"jump": 35, "stamina": -35},
	"quiet": {"jump": 35, "speed": -35},
	"rash": {"jump": 35, "skill": -35},
	"calm": {"skill": 35, "power": -35},
	"gentle": {"skill": 35, "stamina": -35},
	"sassy": {"skill": 35, "speed": -35},
	"careful": {"skill": 35, "jump": -35},
}

# Daily-variation per-stat constants [PUB, UPC]: X offset and
# which PID digit supplies Y.
const DAILY_X: Dictionary = {"power": 0, "stamina": 1, "skill": 2, "jump": 3, "speed": 4}
const DAILY_PID_DIGIT: Dictionary = {"power": 0, "stamina": 1, "skill": 2, "jump": 3, "speed": 4}

# Apricorn blending effects [PUB, UPC]: {raised stat: +4 (or +2
# all for black), lowered stat: -2 (or -2 all for white)}.
const APRICORNS: Dictionary = {
	"red": {"raise": "power", "amount": 4, "lower": "stamina", "penalty": 2},
	"yellow": {"raise": "stamina", "amount": 4, "lower": "skill", "penalty": 2},
	"blue": {"raise": "skill", "amount": 4, "lower": "jump", "penalty": 2},
	"green": {"raise": "jump", "amount": 4, "lower": "speed", "penalty": 2},
	"pink": {"raise": "speed", "amount": 4, "lower": "power", "penalty": 2},
	"white": {"raise": "", "amount": 0, "lower": "", "penalty": 0, "all": -2},
	"black": {"raise": "", "amount": 0, "lower": "", "penalty": 0, "all": 2},
}
# Flavor -> performance stat [PUB]; flavor order for tie-breaks
# is power, stamina, skill, jump, speed [PUB, UPC].
const FLAVOR_STAT: Dictionary = {
	"spicy": "power", "sour": "stamina", "dry": "skill",
	"bitter": "jump", "sweet": "speed",
}
const FLAVOR_ORDER: Array = ["spicy", "sour", "dry", "bitter", "sweet"]

# Aprijuice Stand vendor juices [PUB, UPC]: flavors + mildness +
# listed cost; weekday rotation included as content data.
const STAND_JUICES: Dictionary = {
	"holden": {"flavors": {"spicy": 22, "sour": 10}, "mildness": 116, "cost": 100},
	"elaine": {"flavors": {"sour": 20, "dry": 14}, "mildness": 120, "cost": 100},
	"gilmore": {"flavors": {"dry": 28, "bitter": 20}, "mildness": 125, "cost": 150},
	"krise": {"flavors": {"bitter": 24, "sweet": 14}, "mildness": 136, "cost": 100},
	"victor": {"flavors": {"sweet": 20, "spicy": 12}, "mildness": 104, "cost": 100},
}
const STAND_ROTATION: Dictionary = {
	"sunday": ["holden", "gilmore", "victor"],
	"monday": ["elaine", "krise", "holden"],
	"tuesday": ["gilmore", "victor", "elaine"],
	"wednesday": ["krise", "holden", "gilmore"],
	"thursday": ["victor", "elaine", "krise"],
	"friday": ["holden", "gilmore", "victor"],
	"saturday": ["elaine", "krise", "holden"],
}

# [DC] PUW derivation bands (DESIGN.md section 3): battle base
# stat value -> base performance stars. NOT HGSS data.
const DERIVE_BANDS: Array = [40, 65, 90, 115]
# Battle base stat feeding each performance stat [DC mapping on
# the [PUB] nature-link correspondence].
const DERIVE_SOURCE_STAT: Dictionary = {
	"speed": "spe", "power": "atk", "skill": "spd",
	"stamina": "def", "jump": "spa",
}

# Species that cannot jump [PUB presentation note].
const NON_JUMPERS: Array = ["diglett", "dugtrio"]


static func course_events(course_id: String) -> Array:
	var value: Variant = COURSES.get(course_id, [])
	if value is Array:
		var events: Array = value
		return events.duplicate()
	return []


static func event_index(event_id: String) -> int:
	return EVENT_IDS.find(event_id)


static func course_index(course_id: String) -> int:
	return COURSE_IDS.find(course_id)


static func is_valid_course(course_id: String) -> bool:
	return COURSES.has(course_id)


static func is_valid_event(event_id: String) -> bool:
	return EVENTS.has(event_id)
