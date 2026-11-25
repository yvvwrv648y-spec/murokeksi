class_name PUWPokeathlonPerf
extends RefCounted
## POKEATHLON PERFORMANCE ENGINE (code prep, 2026-11-23).
##
## Two layers, kept separate on purpose (DESIGN.md section 3):
## 1. The AUTHENTIC HGSS daily-variation engine [PUB, Ultimate
##    Pokemon Center archive]: given a species profile
##    (min/base/max per stat), PID, Nature, day of month and an
##    Aprijuice modifier, it produces today's stars. This math is
##    documented reference, implemented as published.
## 2. A PUW profile DERIVATION [DC] that stands in for the
##    per-species HGSS performance table, which is NOT held
##    material. It derives min/base/max from the species' battle
##    base stats ([HELD] Showdown conversion). HGSS performance
##    does NOT derive from base stats in the real games; this is
##    our stand-in, and the only layer that changes when the real
##    table is sourced. A mon dict may carry an explicit
##    "pokeathlon_profile" (bind-time table) or "base_stats";
##    the explicit profile always wins.

# ----------------------------------------------------------------
# Profile derivation [DC]
# ----------------------------------------------------------------

## Base stars for one battle base stat value, by [DC] bands.
static func stars_for_base_stat(value: int) -> int:
	var stars: int = 1
	for band_value: Variant in PUWPokeathlonParams.DERIVE_BANDS:
		var band: int = int(band_value)
		if value >= band:
			stars += 1
	return clampi(stars, 1, 5)


## Derive a full {stat: {"min","base","max"}} profile from a
## battle base-stats dict {"hp","atk","def","spa","spd","spe"}.
static func derive_profile(base_stats: Dictionary) -> Dictionary:
	var profile: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		var source_key: String = str(PUWPokeathlonParams.DERIVE_SOURCE_STAT.get(stat_id, "spe"))
		var raw_value: int = int(base_stats.get(source_key, 50))
		var base: int = stars_for_base_stat(raw_value)
		profile[stat_id] = {
			"min": maxi(1, base - 1),
			"base": base,
			"max": mini(5, base + 1),
		}
	return profile


## The profile a mon competes with: explicit profile first,
## then derivation from its base_stats, then a flat 2/3/4
## fallback [DC] for a mon carrying neither.
static func profile_of(mon: Dictionary) -> Dictionary:
	var explicit_value: Variant = mon.get("pokeathlon_profile", {})
	if explicit_value is Dictionary:
		var explicit: Dictionary = explicit_value
		if not explicit.is_empty():
			return _normalize_profile(explicit)
	var stats_value: Variant = mon.get("base_stats", {})
	if stats_value is Dictionary:
		var stats: Dictionary = stats_value
		if not stats.is_empty():
			return derive_profile(stats)
	var fallback: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		fallback[stat_id] = {"min": 2, "base": 3, "max": 4}
	return fallback


static func _normalize_profile(profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		var entry_value: Variant = profile.get(stat_id, {})
		var entry: Dictionary = {}
		if entry_value is Dictionary:
			entry = entry_value
		var base: int = clampi(int(entry.get("base", 3)), 1, 5)
		out[stat_id] = {
			"min": clampi(int(entry.get("min", maxi(1, base - 1))), 1, base),
			"base": base,
			"max": clampi(int(entry.get("max", mini(5, base + 1))), base, 5),
		}
	return out


## Total unjuiced base stars of a profile (Challenge Bonus input).
static func total_base_stars(profile: Dictionary) -> int:
	var total: int = 0
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		var entry_value: Variant = profile.get(stat_id, {})
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			total += int(entry.get("base", 0))
	return total


# ----------------------------------------------------------------
# Daily variation [PUB authentic formula]
# ----------------------------------------------------------------

## One PID digit: position 0 = ones ... 4 = ten-thousands.
static func pid_digit(pid: int, position: int) -> int:
	var divisor: int = 1
	for i: int in range(position):
		divisor *= 10
	return int(absi(pid) / divisor) % 10


## Raw value before the star-delta bands:
## ((((D + 3 + X) * (D + 7 - X) + Y) mod 10) * 2 - 9) + Z + A.
static func raw_value(stat_id: String, day_of_month: int, pid: int, nature: String, apri_a: int) -> int:
	var x: int = int(PUWPokeathlonParams.DAILY_X.get(stat_id, 0))
	var digit_pos: int = int(PUWPokeathlonParams.DAILY_PID_DIGIT.get(stat_id, 0))
	var y: int = pid_digit(pid, digit_pos)
	var daily_term: int = (((day_of_month + 3 + x) * (day_of_month + 7 - x) + y) % 10) * 2 - 9
	var z: int = nature_z(nature, stat_id)
	return daily_term + z + apri_a


## Nature term Z for one stat (0 when the nature does not touch it).
static func nature_z(nature: String, stat_id: String) -> int:
	var entry_value: Variant = PUWPokeathlonParams.NATURE_Z.get(nature.to_lower(), {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		return int(entry.get(stat_id, 0))
	return 0


## Published star-delta bands [PUB].
static func star_delta(raw: int) -> int:
	if raw <= -120:
		return -4
	if raw <= -80:
		return -3
	if raw <= -40:
		return -2
	if raw <= -15:
		return -1
	if raw <= 14:
		return 0
	if raw <= 39:
		return 1
	if raw <= 79:
		return 2
	if raw <= 119:
		return 3
	return 4


## Today's effective stars for every stat of a mon.
## mon keys read: "pokeathlon_profile" / "base_stats",
## "nature" (String), "pid" (int personality value),
## "aprijuice" (dict with "modifiers" {stat: A}).
static func effective_stars(mon: Dictionary, day_of_month: int) -> Dictionary:
	var profile: Dictionary = profile_of(mon)
	var nature: String = str(mon.get("nature", ""))
	var pid: int = int(mon.get("pid", 0))
	var modifiers: Dictionary = aprijuice_modifiers_of(mon)
	var out: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		var entry_value: Variant = profile.get(stat_id, {})
		var entry: Dictionary = {}
		if entry_value is Dictionary:
			entry = entry_value
		var a: int = int(modifiers.get(stat_id, 0))
		var raw: int = raw_value(stat_id, day_of_month, pid, nature, a)
		var stars: int = int(entry.get("base", 3)) + star_delta(raw)
		stars = clampi(stars, int(entry.get("min", 1)), int(entry.get("max", 5)))
		out[stat_id] = clampi(stars, 1, 5)
	return out


# ----------------------------------------------------------------
# Aprijuice [PUB mechanics; HELD byte shape]
# ----------------------------------------------------------------

static func empty_juice() -> Dictionary:
	return {
		"flavors": {"spicy": 0, "sour": 0, "dry": 0, "bitter": 0, "sweet": 0},
		"mildness": 0,
		"uses": 0,
	}


static func juice_level(juice: Dictionary) -> int:
	var flavors_value: Variant = juice.get("flavors", {})
	var total: int = 0
	if flavors_value is Dictionary:
		var flavors: Dictionary = flavors_value
		for flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
			total += int(flavors.get(flavor, 0))
	return mini(total, PUWPokeathlonParams.JUICE_LEVEL_CAP)


## Juice type = highest flavor, ties broken in flavor order [PUB].
static func juice_type(juice: Dictionary) -> String:
	var flavors_value: Variant = juice.get("flavors", {})
	if not (flavors_value is Dictionary):
		return ""
	var flavors: Dictionary = flavors_value
	var best_flavor: String = ""
	var best_value: int = 0
	for flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
		var value: int = int(flavors.get(flavor, 0))
		if value > best_value:
			best_value = value
			best_flavor = flavor
	if best_value <= 0:
		return ""
	return str(PUWPokeathlonParams.FLAVOR_STAT.get(best_flavor, ""))


## Ranked flavors: [highest, second, lowest] flavor ids [PUB
## tie-break: earlier in FLAVOR_ORDER ranks higher].
static func _ranked_flavors(flavors: Dictionary) -> Array:
	var ranked: Array = PUWPokeathlonParams.FLAVOR_ORDER.duplicate()
	ranked.sort_custom(func(a: String, b: String) -> bool:
		var av: int = int(flavors.get(a, 0))
		var bv: int = int(flavors.get(b, 0))
		if av != bv:
			return av > bv
		return PUWPokeathlonParams.FLAVOR_ORDER.find(a) < PUWPokeathlonParams.FLAVOR_ORDER.find(b))
	return ranked


## Blend a list of apricorn color ids into a juice [PUB, UPC].
## Deviation F3 (DESIGN.md): the original's sum>100 trim has a
## documented uint8 wrap bug; this implements the sane trim.
static func blend(apricorn_ids: Array, starting_juice: Dictionary = {}) -> Dictionary:
	var juice: Dictionary = starting_juice.duplicate(true) if not starting_juice.is_empty() else empty_juice()
	var flavors_value: Variant = juice.get("flavors", {})
	var flavors: Dictionary = {}
	if flavors_value is Dictionary:
		flavors = flavors_value
	for stat_flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
		if not flavors.has(stat_flavor):
			flavors[stat_flavor] = 0
	var mildness: int = int(juice.get("mildness", 0))
	var added: int = 0
	for apricorn_value: Variant in apricorn_ids:
		if added >= PUWPokeathlonParams.BLENDER_CAPACITY:
			break
		var apricorn_id: String = str(apricorn_value).to_lower()
		var spec_value: Variant = PUWPokeathlonParams.APRICORNS.get(apricorn_id, {})
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		added += 1
		# Rank BEFORE this apricorn changes anything [PUB step 2].
		var ranked: Array = _ranked_flavors(flavors)
		var top_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(str(ranked[0]), ""))
		var second_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(str(ranked[1]), ""))
		var top_flavor_value: int = int(flavors.get(str(ranked[0]), 0))
		var second_flavor_value: int = int(flavors.get(str(ranked[1]), 0))
		var changed_up: Dictionary = {}
		var all_delta: int = int(spec.get("all", 0))
		if all_delta != 0:
			for flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
				var stat_id: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(flavor, ""))
				flavors[flavor] = clampi(int(flavors.get(flavor, 0)) + all_delta, 0, PUWPokeathlonParams.FLAVOR_CAP)
				if all_delta > 0:
					changed_up[stat_id] = true
		else:
			var raise_stat: String = str(spec.get("raise", ""))
			var lower_stat: String = str(spec.get("lower", ""))
			for flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
				var stat_for_flavor: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(flavor, ""))
				if stat_for_flavor == raise_stat:
					flavors[flavor] = clampi(int(flavors.get(flavor, 0)) + int(spec.get("amount", 0)), 0, PUWPokeathlonParams.FLAVOR_CAP)
					changed_up[stat_for_flavor] = true
				elif stat_for_flavor == lower_stat:
					flavors[flavor] = clampi(int(flavors.get(flavor, 0)) - int(spec.get("penalty", 0)), 0, PUWPokeathlonParams.FLAVOR_CAP)
		# Mildness drop [PUB step 5]: a raised stat that is neither
		# highest nor second-highest (both non-zero) costs 10.
		if top_flavor_value != 0 and second_flavor_value != 0:
			for stat_id_value: Variant in changed_up.keys():
				var raised_stat: String = str(stat_id_value)
				if raised_stat != top_stat and raised_stat != second_stat:
					mildness = maxi(0, mildness - 10)
					break
		# Sum trim [PUB step 6, sane reading -- see F3]: if the
		# total exceeds 100 (and this was not a white apricorn),
		# reduce the highest flavor that did not just rise (black:
		# any flavor) by the excess.
		if apricorn_id != "white":
			var total: int = 0
			for flavor: String in PUWPokeathlonParams.FLAVOR_ORDER:
				total += int(flavors.get(flavor, 0))
			if total > 100:
				var excess: int = total - 100
				var candidates: Array = _ranked_flavors(flavors)
				for cand_value: Variant in candidates:
					var cand_flavor: String = str(cand_value)
					var cand_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(cand_flavor, ""))
					if apricorn_id == "black" or not bool(changed_up.get(cand_stat, false)):
						flavors[cand_flavor] = maxi(0, int(flavors.get(cand_flavor, 0)) - excess)
						break
	juice["flavors"] = flavors
	juice["mildness"] = clampi(mildness, 0, PUWPokeathlonParams.MILDNESS_CAP)
	if added > 0:
		juice["uses"] = PUWPokeathlonParams.JUICE_USES_PER_BLEND
	return juice


## Walking 100 steps: mildness +1 [PUB / HELD comment].
static func walk_steps(juice: Dictionary, steps: int) -> Dictionary:
	var out: Dictionary = juice.duplicate(true)
	out["mildness"] = clampi(int(out.get("mildness", 0)) + int(steps / 100), 0, PUWPokeathlonParams.MILDNESS_CAP)
	return out


## The A modifiers a juice applies when drunk [PUB, UPC]:
## highest flavor floor(f*1.5)+10 if non-zero; second-highest
## floor(f*1.5); lowest flavor takes the mildness-scaled penalty
## on (highest + second-highest).
static func drink_modifiers(juice: Dictionary) -> Dictionary:
	var flavors_value: Variant = juice.get("flavors", {})
	var flavors: Dictionary = {}
	if flavors_value is Dictionary:
		flavors = flavors_value
	var ranked: Array = _ranked_flavors(flavors)
	var high_flavor: String = str(ranked[0])
	var second_flavor: String = str(ranked[1])
	var low_flavor: String = str(ranked[ranked.size() - 1])
	var high: int = int(flavors.get(high_flavor, 0))
	var second: int = int(flavors.get(second_flavor, 0))
	var mildness: int = int(juice.get("mildness", 0))
	var modifiers: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		modifiers[stat_id] = 0
	if high > 0:
		var high_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(high_flavor, ""))
		modifiers[high_stat] = int(floor(float(high) * 1.5)) + 10
	if second > 0:
		var second_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(second_flavor, ""))
		modifiers[second_stat] = int(modifiers.get(second_stat, 0)) + int(floor(float(second) * 1.5))
	var pair_sum: int = (high + second) % 256
	var penalty: int = 0
	if mildness >= 255:
		penalty = int(floor(float(pair_sum) * 0.1))
	elif mildness >= 200:
		penalty = int(floor(float(pair_sum) * 0.2))
	else:
		var factor: float = 1.0 - float(int(mildness / 25)) * 0.1
		penalty = int(floor(float(pair_sum) * factor))
	if penalty > 0:
		var low_stat: String = str(PUWPokeathlonParams.FLAVOR_STAT.get(low_flavor, ""))
		modifiers[low_stat] = int(modifiers.get(low_stat, 0)) - penalty
	var clamped: Dictionary = {}
	for stat_id: String in PUWPokeathlonParams.STAT_IDS:
		clamped[stat_id] = clampi(int(modifiers.get(stat_id, 0)), -127, 127)
	return clamped


## Drink: replaces any previous juice effect [PUB]. Mutates the
## mon dict's "aprijuice" key -- the ONLY mon write this system
## makes besides clear_juice. Returns false when out of uses.
static func apply_juice(mon: Dictionary, juice: Dictionary) -> bool:
	if int(juice.get("uses", 0)) <= 0:
		return false
	mon["aprijuice"] = {
		"flavors": (juice.get("flavors", {}) as Dictionary).duplicate(true),
		"mildness": int(juice.get("mildness", 0)),
		"modifiers": drink_modifiers(juice),
	}
	return true


## Juice effects vanish when the mon is boxed [HELD comment /
## PUB]. Bind-time storage code calls this on deposit.
static func clear_juice(mon: Dictionary) -> void:
	mon.erase("aprijuice")


static func aprijuice_modifiers_of(mon: Dictionary) -> Dictionary:
	var juice_value: Variant = mon.get("aprijuice", {})
	if juice_value is Dictionary:
		var juice: Dictionary = juice_value
		var mods_value: Variant = juice.get("modifiers", {})
		if mods_value is Dictionary:
			var mods: Dictionary = mods_value
			return mods
	return {}


## Vendor price from fame [HELD: Aprijuice4.CalculatePrice].
static func vendor_price(fame: int, juice: Dictionary) -> int:
	var price: int = int(fame / 10) + int(juice_level(juice) / 2)
	return clampi(price, PUWPokeathlonParams.JUICE_PRICE_MIN, PUWPokeathlonParams.JUICE_PRICE_MAX)
