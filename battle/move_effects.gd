class_name MoveEffects
extends RefCounted
## Move after-effects for Pokemon Ultimate World, battle engine v2.
## Plain rules, no made-up numbers. Everything here reads its numbers
## from the move dict passed in, which comes from moves.json (954
## Showdown moves) or the RC1 move_database.json (94 moves).
##
## Two field styles are accepted:
## - Showdown style (moves.json): "recoil": [1, 4], "drain": [1, 2],
##   "multihit": 2 or [2, 5], "secondary": {"chance": n, "status": "par",
##   "boosts": {...}, "volatileStatus": "flinch"}, "self": {"boosts": {...}},
##   "selfSwitch": true, flags under "flags" (contact, punch, ...).
## - RC1 style (move_database.json): "status" and "status_chance",
##   "pivot": true.
##
## What is NOT done here, on purpose:
## - Multi-hit 2-5 uses the real Showdown spread: 2 hits 35%,
##   3 hits 35%, 4 hits 15%, 5 hits 15% (Showdown data/moves.ts,
##   multihit [2, 5] moves; the spread itself is the standard
##   Showdown roll). Skill Link forces 5 hits.
## - Stat drops are never hard-coded. They are read from the move's
##   own "self" boosts field. The seven moves named in the build task
##   (Close Combat, Draco Meteor, Superpower, Overheat, Leaf Storm,
##   Psycho Boost, V-create) were all checked against moves.json and
##   all seven do carry those exact self boosts there, so they work
##   through this data path. A move with no self boosts in the data
##   gets no stat drop here.
## - Sheer Force is handled by AbilityEngine, not here.
## - Court Change swaps entry hazards only. Screens are left alone;
##   that part is not coded here.
## - apply_after_hit expects the caller to have already taken the
##   damage off the defender's HP. "fainted" is worked out from the
##   defender's HP and the damage passed in.


## True when the move switches the user out after use. Showdown
## moves use "selfSwitch", RC1 moves use "pivot".
static func is_pivot(move: Dictionary) -> bool:
	return bool(move.get("selfSwitch", false)) or bool(move.get("pivot", false))


## Roll how many times a multi-hit move hits. Plain int (2, 3, 10)
## means exactly that many. [2, 5] uses the real Showdown spread:
## 2 hits 35%, 3 hits 35%, 4 hits 15%, 5 hits 15%. Any other
## range still rolls evenly between its two ends. Anything else
## means 1 hit. Skill Link forces 5 hits on a [2, 5] move.
static func get_hit_count(move: Dictionary, rng: RandomNumberGenerator, attacker: Dictionary = {}) -> int:
	var mh = move.get("multihit", 1)
	if mh is int:
		return maxi(1, int(mh))
	if mh is Array and mh.size() >= 2:
		var lo: int = int(mh[0])
		var hi: int = int(mh[1])
		if hi < lo:
			return lo
		if lo == 2 and hi == 5:
			if str(attacker.get("ability", "")) == "Skill Link":
				return 5
			# Loaded Dice: a holder's multi-strike moves hit
			# 4 or 5 times, never 2 or 3.
			if ItemEngine.held_item(attacker) == "loadeddice":
				return 4 if rng.randf() < 0.5 else 5
			var roll: float = rng.randf()
			if roll < 0.35:
				return 2
			if roll < 0.70:
				return 3
			if roll < 0.85:
				return 4
			return 5
		return rng.randi_range(lo, hi)
	return 1


## Roll a move's secondary effect. Showdown style reads
## secondary.chance (100 when a secondary block exists without a
## chance, 0 when there is no secondary block at all). RC1 style
## reads "status" with "status_chance". Returns the roll result with
## the status in lower case as written in moves.json ("par", "brn",
## "psn", "frz", "tox", "slp"), any target stat boosts, any self
## stat boosts, and whether the target flinches.
static func roll_secondary(move: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result := {"triggered": false, "status": "", "boosts": {}, "self_boosts": {}, "flinch": false, "volatile_status": ""}
	var secondary: Dictionary = move.get("secondary", {})
	if move.has("secondary"):
		var chance := int(secondary.get("chance", 100))
		if chance > 0 and rng.randf() < float(chance) / 100.0:
			result["triggered"] = true
			result["status"] = str(secondary.get("status", ""))
			result["boosts"] = secondary.get("boosts", {})
			var self_block: Dictionary = secondary.get("self", {})
			result["self_boosts"] = self_block.get("boosts", {})
			var volatile := str(secondary.get("volatileStatus", ""))
			result["volatile_status"] = volatile
			result["flinch"] = volatile == "flinch"
		# The flinch chance rolls on its own, whether or not the
		# secondary above hit: Stench adds flinch_chance to moves
		# that already have a secondary (Flamethrower burns 10%),
		# and the two chances are separate in Showdown.
		if not bool(result.get("flinch", false)) and move.has("flinch_chance"):
			var fchance2: int = int(move.get("flinch_chance", 0))
			if fchance2 > 0 and rng.randf() < float(fchance2) / 100.0:
				result["triggered"] = true
				result["flinch"] = true
		return result

	if move.has("status"):
		var chance_rc1 := int(move.get("status_chance", 100))
		if chance_rc1 > 0 and rng.randf() < float(chance_rc1) / 100.0:
			result["triggered"] = true
			result["status"] = str(move.get("status", ""))
	# RC1 flinch chance (a percent, e.g. Air Slash 30): rolled here,
	# because no other branch reads it - before this fix no RC1 move
	# ever flinched. A move with both a status and a flinch chance
	# rolls them separately (no RC1 move has both; Showdown-style
	# moves gate everything on their one secondary chance above).
	if move.has("flinch_chance") and not bool(result.get("flinch", false)):
		var fchance := int(move.get("flinch_chance", 0))
		if fchance > 0 and rng.randf() < float(fchance) / 100.0:
			result["triggered"] = true
			result["flinch"] = true
	return result


## Apply one stat stage change, clamped between -6 and +6.
## Stage keys match moves.json: atk, def, spa, spd, spe.
static func _apply_boosts(mon: Dictionary, boosts: Dictionary, logs: Array, is_self: bool, source: Dictionary = {}, field: Dictionary = {}, other: Dictionary = {}) -> void:

	if boosts.is_empty():
		return
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	var names := {"atk": "Attack", "def": "Defense", "spa": "Special Attack", "spd": "Special Defense", "spe": "Speed"}
	# A drop is foe-caused when this is not a self boost and a
	# source mon is passed. Self boosts skip the Mirror Armor /
	# block checks, so a mon can still lower its own stages.
	var foe_caused: bool = not is_self and not source.is_empty()
	# The changes that really land, for the item hooks below
	# (Eject Pack answers a drop, Mirror Herb copies a rise).
	var applied: Dictionary = {}
	for key in boosts.keys():
		var k := str(key)
		if not names.has(k):
			continue
		var amount: int = int(boosts[k])
		var before := int(stages.get(k, 0))
		if foe_caused and amount < 0:
			if AbilityEngine.try_mirror_armor(mon, k, amount, source, logs):
				continue
			if AbilityEngine.blocks_stat_change(mon, k, amount, source):
				logs.append("%s's %s didn't fall!" % [mon.get("name", "Pokémon"), str(names[k])])
				continue
			# Clear Amulet: an opposing Pokemon cannot lower
			# the holder's stats at all.
			if ItemEngine.blocks_foe_stat_drop(mon):
				logs.append("%s's %s didn't fall!" % [mon.get("name", "Pokémon"), str(names[k])])
				continue
		var after := clampi(before + amount, -6, 6)
		stages[k] = after
		if after != before:
			applied[k] = after - before
			var direction := "rose" if after > before else "fell"
			logs.append("%s's %s %s!" % [mon.get("name", "Pokémon"), str(names[k]), direction])
			field["boost_target_name"] = str(mon.get("name", mon.get("species", "Pokémon")))
			if foe_caused:
				AbilityEngine.on_stat_boosted(mon, k, after - before, field, logs)
			elif str(mon.get("ability", "")) == "Contrary" or str(mon.get("ability", "")) == "Simple":
				# Self-caused changes only reach Contrary and
				# Simple (see F1b).
				AbilityEngine.on_stat_boosted(mon, k, after - before, field, logs)
			if not other.is_empty() and str(other.get("ability", "")) == "Opportunist":
				# Opportunist copies a foe's boost (see F1b).
				AbilityEngine.on_stat_boosted(other, k, after - before, field, logs)

	mon["stages"] = stages
	if foe_caused:
		# Eject Pack: a foe-caused drop that really landed
		# makes the holder switch out (the controller runs
		# the switch when it sees the flag).
		var any_drop: bool = false
		for key3 in applied.keys():
			if int(applied[key3]) < 0:
				any_drop = true
		if any_drop:
			ItemEngine.on_stat_dropped(mon, logs)
		# Mirror Herb: the opposing mon copies the rises that
		# really landed here, once.
		if not other.is_empty():
			ItemEngine.try_mirror_herb(other, applied, logs)
	elif is_self and not other.is_empty():
		# Mirror Herb also answers a mon raising its OWN stats
		# (Swords Dance and friends): the holder is `other`.
		ItemEngine.try_mirror_herb(other, applied, logs)


## Recoil fraction of the damage dealt, as a float. Showdown style
## is [numerator, denominator] (Brave Bird [33, 100], Head Smash
## [1, 2]); RC1 style is a scalar (Brave Bird 0.33). 0.0 when the
## move has no recoil. The scalar form matters: with live RC1 data
## the Array-only branch never fired, so Brave Bird never recoiled.
static func _recoil_fraction(move: Dictionary) -> float:
	var recoil = move.get("recoil", [])
	if recoil is Array and recoil.size() >= 2:
		var den: float = float(int(recoil[1]))
		if den <= 0.0:
			return 0.0
		return float(int(recoil[0])) / den
	if recoil is float or recoil is int:
		return float(recoil)
	return 0.0


## After a hit lands: recoil, drain healing, multi-hit count, the
## user's own stat changes from the move's "self" boosts, and the
## secondary roll (status, target stat changes, self stat changes,
## flinch). Damage is the total damage dealt. Returns
## {"switch_requested": bool, "fainted": bool}. switch_requested is
## true for pivot moves. fainted is true when the damage finishes
## the defender.

## Drain fraction of the damage dealt, as a float. Showdown style
## is [numerator, denominator] (Giga Drain [1, 2], Draining Kiss
## [3, 4]); RC1 style is a scalar (Giga Drain 0.5). 0.0 when the
## move has no drain.
static func _drain_fraction(move: Dictionary) -> float:
	var drain = move.get("drain", [])
	if drain is Array and drain.size() >= 2:
		var den: float = float(int(drain[1]))
		if den <= 0.0:
			return 0.0
		return float(int(drain[0])) / den
	if drain is float or drain is int:
		return float(drain)
	return 0.0

static func apply_after_hit(attacker: Dictionary, defender: Dictionary, move: Dictionary, damage: int, field: Dictionary, rng: RandomNumberGenerator, logs: Array) -> Dictionary:
	var out := {"switch_requested": is_pivot(move), "fainted": false}
	var defender_hp := int(defender.get("hp", 0))
	if damage > 0 and defender_hp - damage <= 0:
		out["fainted"] = true
	var hits: int = get_hit_count(move, rng, attacker)
	if hits > 1:
		logs.append("%s hit %d times!" % [str(move.get("name", "move")), hits])
	# Recoil: the attacker loses damage * fraction HP. Showdown
	# Rock Head onDamage: recoil is blocked unless the move is
	# Struggle. Struggle never reaches this branch (its recoil is
	# inline in the controller's _execute_struggle), and Life Orb
	# recoil is a separate ItemEngine path, so neither is skipped
	# here. The fraction accepts both the Showdown [n, d] form and
	# the RC1 scalar form.
	var recoil_frac: float = _recoil_fraction(move)
	if damage > 0 and recoil_frac > 0.0 and int(attacker.get("hp", 0)) > 0:
		var loss: int = int(float(damage) * recoil_frac)
		if loss > 0:
			if str(attacker.get("ability", "")) == "Rock Head":
				logs.append("%s took no recoil damage with Rock Head!" % attacker.get("name", "Pokémon"))
			else:
				attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - loss)
				logs.append("%s was hurt by recoil (-%d HP)!" % [attacker.get("name", "Pokémon"), loss])
	# Drain: the attacker heals damage * fraction HP. Showdown
	# Liquid Ooze onSourceTryHeal: when the defender has Liquid
	# Ooze, the attacker takes the would-be heal amount as damage
	# instead and heals 0. Mold Breaker, Teravolt and Turboblaze
	# on the attacker ignore it. Heal Block on the attacker
	# prevents the heal (the damage still lands). Leech Seed
	# and Strength Sap carry their own Liquid Ooze handling in
	# the controller, where those mechanics live. The fraction
	# accepts both the Showdown [n, d] form and the RC1 scalar
	# form (Giga Drain 0.5).
	var drain_frac: float = _drain_fraction(move)
	if damage > 0 and drain_frac > 0.0 and int(attacker.get("hp", 0)) > 0:
		var gain: int = int(float(damage) * drain_frac)
		# Big Root: HP restored by a draining move is x1.3
		# (the Liquid Ooze answer below uses the same boosted
		# figure, as the games do: the ooze deals what would
		# have been healed).
		gain = int(round(float(gain) * ItemEngine.drain_multiplier(attacker)))
		if gain > 0:
			var def_ab: String = str(defender.get("ability", ""))
			var atk_ab2: String = str(attacker.get("ability", ""))
			if def_ab == "Liquid Ooze" and atk_ab2 != "Mold Breaker" and atk_ab2 != "Teravolt" and atk_ab2 != "Turboblaze":
				attacker["hp"] = maxi(0, int(attacker.get("hp", 0)) - gain)
				logs.append("%s was hurt by Liquid Ooze (-%d HP)!" % [attacker.get("name", "Pokémon"), gain])
			elif int(attacker.get("heal_block_turns", 0)) > 0 or int(attacker.get("noise_heal_block_turns", 0)) > 0:
				# Heal Block blocks the drain heal from either
				# source: the Heal Block move's counter or
				# Psychic Noise's own 2-turn counter.
				logs.append("%s is prevented from healing by Heal Block!" % attacker.get("name", "Pokémon"))
			else:
				var max_hp: int = int(attacker.get("max_hp", 100))
				var healed: int = mini(gain, max_hp - int(attacker.get("hp", 0)))
				attacker["hp"] = int(attacker.get("hp", 0)) + healed
				if healed > 0:
					logs.append("%s drained HP (+%d HP)!" % [attacker.get("name", "Pokémon"), healed])
	# The user's own stat changes, read only from the move's "self"
	# boosts. No list is hard-coded here. The RC1 move list also
	# writes them as "self_boost" (Rapid Spin's Speed boost and
	# the like); read that shape too.
	var self_block: Dictionary = move.get("self", {})
	var self_boosts: Dictionary = self_block.get("boosts", {})
	if self_boosts.is_empty():
		self_boosts = move.get("self_boost", {})
	# V5: a "self" block with a chance only applies that often.
	# Diamond Storm is 50% Defense +2; without the roll it would
	# rise every time. A missing chance means always. The roll
	# uses the controller's rng, passed into this function.
	var self_chance: int = int(self_block.get("chance", 100))
	if not self_boosts.is_empty() and self_chance < 100 and rng.randf() * 100.0 >= float(self_chance):
		self_boosts = {}
	_apply_boosts(attacker, self_boosts, logs, true, {}, field, defender)
	# V5: "selfBoost" is a second shape for the same idea.
	# Clangorous Soulblaze raises all five stats by 1 this way,
	# Clanging Scales drops Defense by 1, and Scale Shot drops
	# Defense by 1 and raises Speed by 1. It has no chance, so it
	# always applies.
	var self_boost_block: Dictionary = move.get("selfBoost", {})
	var soul_boosts: Dictionary = self_boost_block.get("boosts", {})
	_apply_boosts(attacker, soul_boosts, logs, true, {}, field, defender)


	# Secondary effect roll: status, target stat changes, self stat
	# changes, flinch. Only when the move did damage and the defender
	# is still standing.
	if damage > 0 and not bool(out["fainted"]):
		var roll := roll_secondary(move, rng)
		# Covert Cloak: the defender is immune to the move's
		# additional (secondary) effects; the roll is skipped
		# entirely when the cloak is held.
		if bool(roll.get("triggered", false)) and ItemEngine.blocks_secondary_effects(defender):
			logs.append("%s's Covert Cloak shielded it from the additional effect!" % defender.get("name", "Pokémon"))
			roll["triggered"] = false
		if bool(roll.get("triggered", false)):
			var status := str(roll.get("status", "")).to_upper()
			if status != "":
				# try_set_status is the one choke point: it checks
				# blocks_status (Leaf Guard Sun), the PSN/TOX type
				# immunity (Corrosion bypass), sets sleep_turns (2-4)
				# and toxic_counter, and fires on_after_set_status
				# (Synchronize, Poison Puppeteer).
				AbilityEngine.try_set_status(defender, status, attacker, field, logs)
			_apply_boosts(defender, roll.get("boosts", {}), logs, false, attacker, field, attacker)
			_apply_boosts(attacker, roll.get("self_boosts", {}), logs, true, {}, field, defender)

			if bool(roll.get("flinch", false)):
				# Inner Focus stops the flinch. Mold Breaker,
				# Teravolt and Turboblaze on the attacker ignore it.
				var atk_ab: String = str(attacker.get("ability", ""))
				if atk_ab != "Mold Breaker" and atk_ab != "Teravolt" and atk_ab != "Turboblaze" and not AbilityEngine.blocks_flinch(defender):
					defender["flinched"] = true
					logs.append("%s flinched!" % defender.get("name", "Pokémon"))

			if str(roll.get("volatile_status", "")).to_lower() == "healblock":
				# Psychic Noise's secondary: the target cannot
				# heal for 2 turns. This is its own counter
				# (noise_heal_block_turns), separate from the
				# Heal Block move's 5-turn heal_block_turns, and
				# every heal gate checks both. There is no
				# standalone Aroma Veil volatile-block helper in
				# AbilityEngine (its Aroma Veil block lives in the
				# before-move path for the Heal Block move
				# itself), so this is applied the plain way the
				# confusion secondary below is applied, with
				# Aroma Veil checked inline the way confusion
				# checks Own Tempo.
				if str(defender.get("ability", "")) == "Aroma Veil":
					logs.append("%s's Aroma Veil blocked Heal Block!" % defender.get("name", "Pokémon"))
				else:
					defender["noise_heal_block_turns"] = AbilityEngine.field_duration(attacker, "healblock", 2)
					logs.append("%s was prevented from healing!" % defender.get("name", "Pokémon"))

			if str(roll.get("volatile_status", "")).to_lower() == "confusion":
				# A damaging move whose secondary confuses (Dynamic
				# Punch, Psybeam, Water Pulse and the rest): the
				# defender becomes confused for 2-5 turns (Showdown
				# conditions.ts confusion onStart). Own Tempo blocks
				# it; an already-confused mon stays as it is. This
				# is what lets Tangled Feet fire from a move, and
				# what _check_confusion reads each turn.
				if not bool(defender.get("confused", false)) and str(defender.get("ability", "")) != "Own Tempo":
					defender["confused"] = true
					defender["confusion_turns"] = rng.randi_range(2, 5)
					logs.append("%s became confused!" % defender.get("name", "Pokémon"))
	return out


## Set an entry hazard on a side. Stealth Rock sets the flag, Spikes
## adds a layer up to 3, Toxic Spikes adds a layer up to 2, Sticky
## Web sets the flag. At max already, nothing changes and that is
## logged. Move names match case-insensitively.
static func apply_hazard_move(move_name: String, side_hazards: Dictionary, field: Dictionary, logs: Array) -> void:
	var key := move_name.to_lower().replace(" ", "").replace("-", "")
	match key:
		"stealthrock":
			if bool(side_hazards.get("stealth_rock", false)):
				logs.append("Stealth Rock is already set on that side.")
				return
			side_hazards["stealth_rock"] = true
			logs.append("Pointed stones float in the air around the foe!")
		"spikes":
			var layers := int(side_hazards.get("spikes", 0))
			if layers >= 3:
				logs.append("Spikes are already at 3 layers.")
				return
			side_hazards["spikes"] = layers + 1
			logs.append("Spikes were scattered on the foe's side!")
		"toxicspikes":
			var tlayers := int(side_hazards.get("toxic_spikes", 0))
			if tlayers >= 2:
				logs.append("Toxic Spikes are already at 2 layers.")
				return
			side_hazards["toxic_spikes"] = tlayers + 1
			logs.append("Toxic Spikes were scattered on the foe's side!")
		"stickyweb":
			if bool(side_hazards.get("sticky_web", false)):
				logs.append("Sticky Web is already set on that side.")
				return
			side_hazards["sticky_web"] = true
			logs.append("A Sticky Web was set on the foe's side!")
		_:
			logs.append("%s is not an entry hazard move." % move_name)


## Clear every entry hazard on one side.
static func _clear_hazards(hazards: Dictionary) -> void:
	hazards["stealth_rock"] = false
	hazards["spikes"] = 0
	hazards["toxic_spikes"] = 0
	hazards["sticky_web"] = false


## Clear every screen (Reflect, Light Screen, Aurora Veil, Tailwind)
## on both sides, when the field state has them.
static func _clear_screens(field: Dictionary) -> void:
	for side_key in ["player_screens", "enemy_screens"]:
		var screens: Dictionary = field.get(side_key, {})
		for screen_key in ["reflect", "light_screen", "aurora_veil", "tailwind"]:
			screens[screen_key] = 0
		field[side_key] = screens


## Clear or swap hazards. Rapid Spin clears the user's own side.
## Defog clears both sides, plus screens on both sides. Court
## Change swaps the two sides' hazards. Anything else does nothing
## and that is logged.
static func apply_hazard_clear(move_name: String, own_hazards: Dictionary, foe_hazards: Dictionary, field: Dictionary, logs: Array) -> void:
	var key := move_name.to_lower().replace(" ", "").replace("-", "")
	match key:
		"rapidspin":
			_clear_hazards(own_hazards)
			logs.append("Rapid Spin cleared the hazards on its own side!")
		"defog":
			_clear_hazards(own_hazards)
			_clear_hazards(foe_hazards)
			_clear_screens(field)
			logs.append("Defog cleared hazards and screens on both sides!")
		"courtchange":
			var mine := own_hazards.duplicate()
			own_hazards.clear()
			for k in foe_hazards.keys():
				own_hazards[k] = foe_hazards[k]
			foe_hazards.clear()
			for k in mine.keys():
				foe_hazards[k] = mine[k]
			logs.append("Court Change swapped the entry hazards!")
		_:
			logs.append("%s does not clear hazards." % move_name)
