class_name ShinyOdds
extends RefCounted
## Shiny odds for Pokemon Ultimate World — the engine's one shiny
## determination, used by encounter generation
## (PUWHabitatEncounters.roll_habitat_encounter).
##
## Canon (Gen 6 and later, Bulbapedia "Shiny Pokemon"):
## - Base chance: 1 in 4096. The games roll once; a roll of 0
##   (out of 0..4095) makes the Pokemon shiny.
## - Shiny Charm (key item): +2 EXTRA rolls, so 3 rolls total,
##   chance 3/4096 (about 1 in 1365.67).
##
## Composition rule: sources compose by ADDING rolls. Each active
## source contributes its extra rolls on top of the 1 base roll,
## and the chance is total_rolls / 4096. That is exactly how the
## real games stack the Charm with other roll-granting effects.
##
## Sources that genuinely exist in this engine today:
## - Shiny Charm (+2 rolls) — implemented here, active when the
##   player holds the shiny-charm key item (the caller passes
##   has_shiny_charm from the bag).
## There is NO other shiny-odds source in this engine: there is
## no breeding (so no Masuda method), no catch combo / chain
## system, and no SOS chaining anywhere in the project (checked
## 2026-11-23 across battle/ and systems/). The VEXA shiny toggle
## and the rival-defeat shiny eggs are forced-shiny, not odds,
## and do not pass through here. If a second roll-granting source
## is ever built, it composes through additional_extra_rolls —
## the deterministic tests in tests/item_integrity_tests.gd prove
## that composition channel with a +2 second source (5/4096).

## Denominator of every shiny roll (Gen 6+ base rate 1/4096).
const DENOMINATOR: int = 4096
## Rolls with no source active: exactly 1.
const BASE_ROLLS: int = 1
## Extra rolls granted by the Shiny Charm (Gen 6+ canon).
const SHINY_CHARM_EXTRA_ROLLS: int = 2

## Extra rolls granted by the named sources that are active.
## Only "shiny_charm" exists in this engine (see header).
static func extra_rolls_for_sources(sources: Dictionary) -> int:
	var extra: int = 0
	if bool(sources.get("shiny_charm", false)):
		extra += SHINY_CHARM_EXTRA_ROLLS
	return extra

## Total rolls for a set of active sources plus any additional
## extra rolls from a future source. Never below the base roll.
static func total_rolls(has_shiny_charm: bool, additional_extra_rolls: int = 0) -> int:
	var sources: Dictionary = {"shiny_charm": has_shiny_charm}
	var rolls: int = BASE_ROLLS + extra_rolls_for_sources(sources) + maxi(0, additional_extra_rolls)
	return rolls

## The shiny chance as an exact fraction: numerator rolls out of
## DENOMINATOR. Deterministic — no RNG is touched here, so tests
## compare this directly.
static func shiny_chance_fraction(has_shiny_charm: bool, additional_extra_rolls: int = 0) -> Dictionary:
	return {"numerator": total_rolls(has_shiny_charm, additional_extra_rolls), "denominator": DENOMINATOR}

## The shiny chance as a float: total_rolls / 4096.0.
## No sources: 1/4096. Shiny Charm: 3/4096. Charm plus a +2
## second source: 5/4096.
static func shiny_chance(has_shiny_charm: bool, additional_extra_rolls: int = 0) -> float:
	return float(total_rolls(has_shiny_charm, additional_extra_rolls)) / float(DENOMINATOR)

## Roll whether one encounter is shiny, using the caller's RNG
## (encounter generation owns the RNG stream). One roll per
## total_rolls; any roll landing on 0 makes it shiny — the same
## reroll model the real games use for the Shiny Charm.
static func roll_shiny(rng: RandomNumberGenerator, has_shiny_charm: bool, additional_extra_rolls: int = 0) -> bool:
	var use_rng: RandomNumberGenerator = rng
	if use_rng == null:
		use_rng = RandomNumberGenerator.new()
		use_rng.randomize()
	var rolls: int = total_rolls(has_shiny_charm, additional_extra_rolls)
	for i in range(rolls):
		if use_rng.randi_range(0, DENOMINATOR - 1) == 0:
			return true
	return false
