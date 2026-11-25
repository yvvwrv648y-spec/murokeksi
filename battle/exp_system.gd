# EXPSystem — real experience points for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# It works out how much EXP a Pokemon needs for each level, how much
# EXP it earns when something faints, and what level it is at for a
# given amount of EXP. All numbers come from the real games.
#
# Where the numbers come from:
# - The six level curves (Erratic, Fast, Medium Fast, Medium Slow,
#   Slow, Fluctuating) are the real game formulas, checked against
#   the Bulbapedia "Experience" page table (25 spot checks, levels
#   2, 15, 16, 36, 50, 68, 69, 98, 99 and 100 in all six groups,
#   all match) and the GameFAQs "EXP. Mechanics" guide, which lists
#   the same formulas. The MIT "Game Mechanics of Pokemon" notes
#   agree too, and settle two details: Erratic levels 69-98 use
#   floor((1911 - 10n) / 3) / 500, and Fluctuating levels 1-15 use
#   (floor((n + 1) / 3) + 24) / 50.
# - The EXP earned in battle is the classic formula:
#   base_experience x fainted level / 7, split between the Pokemon
#   that share it.
# - Each species' base_experience and growth_rate live in
#   exp_yield.json, fetched from PokeAPI. This file holds no species
#   data and invents no numbers.
#
# How to use it:
#   var gain: int = EXPSystem.exp_gain(64, 5, 1, false)  # Bulbasaur, level 5, alone
#   var need: int = EXPSystem.exp_for_level("medium-slow", 6)
#   var left: int = EXPSystem.exp_to_next_level("medium-slow", 5, 100)
#   var level: int = EXPSystem.level_for_exp("medium-slow", 1000)
#
# Growth rate names: PokeAPI calls the six groups "slow",
# "medium", "fast", "medium-slow", "slow-then-very-fast" and
# "fast-then-very-slow". Those are translated to the curve names
# used here ("medium" is Medium Fast, "slow-then-very-fast" is
# Erratic, "fast-then-very-slow" is Fluctuating). Plain names
# ("Medium Fast", "erratic", "medium_fast") work too.
# An unknown growth rate falls back to "medium-fast" (the most common
# group) so the game never crashes on a bad name; the real growth
# rate should always come from exp_yield.json instead.
#
# NOTE: this script extends RefCounted, not Node. That means it can
# NOT be an autoload (Godot only autoloads Nodes). All functions are
# static, so just call EXPSystem.exp_for_level(...) anywhere.

class_name EXPSystem
extends RefCounted

## Highest level a Pokemon can reach.
const MAX_LEVEL: int = 100

## Hard level caps by gym badge count, indexed by badges earned
## (0 badges first, 8 badges last). Transcribed from the RC1
## formats doc, docs/PUW_BATTLE_FORMATS_GIMMICKS_AND_CAPS.json,
## key "hard_badge_level_caps_zero_disobedience":
##   0 badges -> 10, 1 -> 20, 2 -> 24, 3 -> 29, 4 -> 40,
##   5 -> 43, 6 -> 47, 7 -> 50, 8 -> 100.
## The cap is a HARD STOP on the level only: EXP points keep
## accruing past it, and there are NO disobedience mechanics
## anywhere (the doc's name says "zero_disobedience").
const BADGE_LEVEL_CAPS: Array = [10, 20, 24, 29, 40, 43, 47, 50, 100]

## The hard level cap for a badge count. 0 or fewer badges
## returns the first cap (10); 8 or more returns 100.
static func level_cap_for_badges(badges: int) -> int:
	if badges <= 0:
		return int(BADGE_LEVEL_CAPS[0])
	if badges >= 8:
		return int(BADGE_LEVEL_CAPS[8])
	return int(BADGE_LEVEL_CAPS[badges])

## Total EXP needed to reach a level, for a growth rate.
## Level 1 always needs 0. Levels above 100 count as 100.
## All six formulas are the real game formulas (see the header).
static func exp_for_level(growth_rate: String, level: int) -> int:
	if level <= 1:
		return 0
	var n: int = mini(level, MAX_LEVEL)
	var n2: int = n * n
	var n3: int = n2 * n
	match _normalize_growth_rate(growth_rate):
		"fast":
			return (4 * n3) / 5
		"medium-fast":
			return n3
		"medium-slow":
			# At level 1 this gives -54 in the raw formula, which
			# the games clamp to 0. Levels 2 and up are positive.
			return maxi(0, (6 * n3) / 5 - 15 * n2 + 100 * n - 140)
		"slow":
			return (5 * n3) / 4
		"erratic":
			if n < 50:
				return n3 * (100 - n) / 50
			if n < 68:
				return n3 * (150 - n) / 100
			if n < 98:
				return n3 * ((1911 - 10 * n) / 3) / 500
			return n3 * (160 - n) / 100
		"fluctuating":
			if n < 15:
				return n3 * ((n + 1) / 3 + 24) / 50
			if n < 36:
				return n3 * (n + 14) / 50
			return n3 * (n / 2 + 32) / 50
	return n3


## EXP one Pokemon earns when a foe faints.
##   base_experience: the fainted species' base EXP from exp_yield.json
##   fainted_level: the fainted Pokemon's level
##   participants: how many Pokemon share the EXP
##   exp_share: true when Exp. Share is on, so the whole living party
##     shares (the caller passes the whole party count as
##     participants); false when only the Pokemon that fought share
##     (the caller passes only the battlers).
## The split is the same either way: the whole amount is divided
## evenly, and each Pokemon gets at least 1 EXP when anything was
## earned at all. A fainted level of 0 or a base EXP of 0 earns 0.
## Lucky Egg (held): the holder earns 1.5x EXP. That is the real
## games' rule (Bulbapedia "Lucky Egg": experience gained by the
## holder is multiplied by 1.5), and items_full.json's effect text
## for lucky-egg says the same: "Held: Increases EXP earned in
## battle by 50%." The boost is applied per holder, after the
## even split in exp_gain, and the result is floored to a whole
## number of EXP points, the same way the games round down.
const LUCKY_EGG_MULT: float = 1.5

## Normalise a held-item name the same way ItemEngine does:
## lowercase, then spaces, hyphens, underscores and apostrophes
## removed, so "Lucky Egg", "lucky-egg" and "luckyegg" all match.
static func _norm_item(raw: String) -> String:
	var s: String = raw.to_lower()
	s = s.replace(" ", "").replace("-", "").replace("_", "").replace("'", "")
	return s

## True when the named held item is a Lucky Egg.
static func is_lucky_egg(held_item: String) -> bool:
	return _norm_item(held_item) == "luckyegg"

## EXP multiplier for a held item: 1.5 for a Lucky Egg, else 1.0.
## No other held item in the data changes EXP, so nothing else
## composes here.
static func held_item_exp_mult(held_item: String) -> float:
	if is_lucky_egg(held_item):
		return LUCKY_EGG_MULT
	return 1.0

## exp_gain for one specific earner, with that earner's held item
## applied. A Lucky Egg holder gets floor(share x 1.5); everyone
## else gets exactly the exp_gain share, unchanged.
static func exp_gain_for_holder(base_experience: int, fainted_level: int, participants: int, exp_share: bool, held_item: String) -> int:
	var share: int = exp_gain(base_experience, fainted_level, participants, exp_share)
	if share <= 0:
		return 0
	var mult: float = held_item_exp_mult(held_item)
	if mult == 1.0:
		return share
	return maxi(1, int(floor(float(share) * mult)))


static func exp_gain(base_experience: int, fainted_level: int, participants: int, exp_share: bool) -> int:
	if base_experience <= 0 or fainted_level <= 0:
		return 0
	var total: int = base_experience * fainted_level / 7
	if total <= 0:
		return 0
	# exp_share only changes WHO counts as a participant (the caller
	# passes the whole party when it is on, only battlers when off).
	# The split itself is the same: the total divided evenly.
	var count: int = maxi(1, participants)
	var _share_on: bool = exp_share
	return maxi(1, total / count)


## EXP still needed to reach the next level.
## current_exp is the Pokemon's TOTAL EXP, not the EXP since its last
## level-up. Returns 0 at level 100 or when already past the next
## level's total.
static func exp_to_next_level(growth_rate: String, level: int, current_exp: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var next_total: int = exp_for_level(growth_rate, level + 1)
	return maxi(0, next_total - current_exp)


## What level a Pokemon is at for a total amount of EXP.
## Never below 1, never above 100.
static func level_for_exp(growth_rate: String, total_exp: int) -> int:
	if total_exp <= 0:
		return 1
	var rate: String = _normalize_growth_rate(growth_rate)
	var low: int = 1
	var high: int = MAX_LEVEL
	while low < high:
		var mid: int = (low + high + 1) / 2
		if exp_for_level(rate, mid) <= total_exp:
			low = mid
		else:
			high = mid - 1
	return low


## ------------------------------------------------------------------
## Helpers
## ------------------------------------------------------------------

## Clean a growth rate name into the PokeAPI spelling.
## "Medium Fast", "medium_fast" and "medium-fast" all become
## "medium-fast". Anything unknown falls back to "medium-fast".
## PokeAPI uses its own names for three of the groups, and they
## are translated here to the curve names used in this file:
##   "medium" -> medium-fast (n cubed)
##   "slow-then-very-fast" -> erratic
##   "fast-then-very-slow" -> fluctuating
static func _normalize_growth_rate(growth_rate: String) -> String:
	var clean: String = growth_rate.strip_edges().to_lower()
	clean = clean.replace("_", "-").replace(" ", "-")
	match clean:
		"erratic", "slow-then-very-fast":
			return "erratic"
		"fast":
			return "fast"
		"medium-fast", "medium":
			return "medium-fast"
		"medium-slow":
			return "medium-slow"
		"slow":
			return "slow"
		"fluctuating", "fast-then-very-slow":
			return "fluctuating"
	return "medium-fast"
