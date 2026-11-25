class_name VariablePower
extends RefCounted
## The real power and damage formulas for the 43 basePower-0 moves.
##
## Every formula here is checked against the live Showdown moves.ts
## (smogon/pokemon-showdown, data/moves.ts, crawled 2026-11-22).
## Nothing here is guessed. If a number looks odd, the Showdown
## source line is named in the comment above the function.
##
## How to use this file:
## - Every function is static. Call it like
##   VariablePower.weight_power(target_weight_hg).
## - Every function takes plain numbers (weights in hectograms,
##   Speed stats, HP numbers, friendship 0-255, PP left, and so on)
##   and returns one int. No function reads a file and no function
##   reads the game state. The controller passes the numbers in.
## - Weights come from weight_power.json in this same pack: species
##   name -> weight in hectograms (Bulbasaur 69 = 6.9 kg). The
##   controller loads that file once and passes the weight in.
## - "Power" means the base power that goes into the normal damage
##   formula. "Damage" means flat HP damage that skips the normal
##   formula (the controller deals it as-is, after accuracy).
## - Which function a move uses: read the move's "damage_rule" from
##   move_database_954.json, then use this list:
##     weight        -> weight_power(target_weight_hg)
##     weight_ratio  -> weight_ratio_power(user_weight_hg, target_weight_hg)
##     gyro_ball     -> gyro_ball_power(user_spe, target_spe)
##     electro_ball  -> electro_ball_power(user_spe, target_spe)
##     low_hp        -> flail_power(user_hp, user_max_hp)
##     target_hp     -> crush_grip_power(target_hp, target_max_hp, rule_scale)
##     fixed         -> dragon_rage_damage() or sonic_boom_damage()
##     level         -> level_damage(user_level)
##     fraction      -> fraction_damage(target_hp, rule_num, rule_den)
##     ohko          -> ohko_damage(target_max_hp)
##     counter       -> counter_damage(last_damage_taken, rule_mult_num,
##                      rule_mult_den, was_damaged)
##     friendship    -> friendship_power(happiness) or
##                      frustration_power(happiness)
##     item          -> fling_power(item_fling_power) or
##                      natural_gift_power(berry_power) plus
##                      natural_gift_type(berry_type)
##     bide          -> bide_damage(stored_damage)
##     endeavor      -> endeavor_damage(target_hp, user_hp)
##     final_gambit  -> final_gambit_damage(user_hp)
##     magnitude     -> magnitude_power(roll_0_99) and
##                      magnitude_number(roll_0_99)
##     present       -> present_heals(roll_0_9), present_power(roll_0_9),
##                      present_heal_amount(target_max_hp)
##     psywave       -> psywave_damage(user_level, roll_50_150)
##     spit_up       -> spit_up_power(stockpile_layers)
##     trump_card    -> trump_card_power(pp_left)
##     beat_up       -> beat_up_power(ally_base_atk) once per hit, and
##                      beat_up_hit_count(able_party_count)
##     punishment    -> punishment_power(positive_boost_total)
## - Random rolls are passed in as plain ints so the formulas stay
##   pure and testable: Magnitude takes a roll from 0 to 99,
##   Present takes a roll from 0 to 9, Psywave takes a roll from
##   50 to 150. The controller rolls with randi_range and passes
##   the result in.
##
## Notes on what the engine must still check around these formulas:
## - Counter and Mirror Coat only count damage from Physical or
##   Special moves (see the func comment). Metal Burst and
##   Comeuppance only work if the user was damaged this turn.
## - OHKO moves use accuracy 30 + user level - target level, and
##   fail outright if the user's level is lower than the target's.
## - Bide, Spit Up, Fling and Natural Gift fail when their setup is
##   missing (no damage stored, no Stockpile, no held item, no berry).
##   The funcs return 0 for those cases; the controller treats 0 as
##   "the move fails".
## - Showdown uses the target's HP without any Dynamax doubling
##   (getUndynamaxedHP). This game has no Dynamax, so plain current
##   HP is the same thing.


## Grass Knot, Low Kick. Power from the target's weight.
## Showdown moves.ts, grassknot / lowkick basePowerCallback:
## weight in hectograms. 2000 or more -> 120, 1000 or more -> 100,
## 500 or more -> 80, 250 or more -> 60, 100 or more -> 40, else 20.
static func weight_power(target_weight_hg: int) -> int:
	if target_weight_hg >= 2000:
		return 120
	if target_weight_hg >= 1000:
		return 100
	if target_weight_hg >= 500:
		return 80
	if target_weight_hg >= 250:
		return 60
	if target_weight_hg >= 100:
		return 40
	return 20


## Heavy Slam, Heat Crash. Power from the user's weight compared
## with the target's weight.
## Showdown moves.ts, heavyslam / heatcrash basePowerCallback:
## user weight 5x the target's or more -> 120, 4x or more -> 100,
## 3x or more -> 80, 2x or more -> 60, else 40.
static func weight_ratio_power(user_weight_hg: int, target_weight_hg: int) -> int:
	if target_weight_hg <= 0:
		return 40
	if user_weight_hg >= target_weight_hg * 5:
		return 120
	if user_weight_hg >= target_weight_hg * 4:
		return 100
	if user_weight_hg >= target_weight_hg * 3:
		return 80
	if user_weight_hg >= target_weight_hg * 2:
		return 60
	return 40


## Gyro Ball. Power grows the slower the user is than the target.
## Showdown moves.ts, gyroball basePowerCallback:
## power = floor(25 * target Speed / user Speed) + 1, capped at 150.
static func gyro_ball_power(user_spe: int, target_spe: int) -> int:
	if user_spe <= 0:
		return 150
	var power: int = int(25 * target_spe / user_spe) + 1
	if power > 150:
		power = 150
	if power < 1:
		power = 1
	return power


## Electro Ball. Power grows the faster the user is than the target.
## Showdown moves.ts, electroball basePowerCallback:
## ratio = floor(user Speed / target Speed), then the power is picked
## from [40, 60, 80, 120, 150] at index min(ratio, 4).
## So ratio 0 -> 40, 1 -> 60, 2 -> 80, 3 -> 120, 4 or more -> 150.
static func electro_ball_power(user_spe: int, target_spe: int) -> int:
	if target_spe <= 0:
		return 150
	var ratio: int = int(user_spe / target_spe)
	if ratio < 0:
		ratio = 0
	if ratio > 4:
		ratio = 4
	var table: Array = [40, 60, 80, 120, 150]
	var power: int = int(table[ratio])
	return power


## Flail, Reversal. Power grows the less HP the user has left.
## Showdown moves.ts, flail / reversal basePowerCallback:
## ratio = max(floor(user HP * 48 / user max HP), 1).
## ratio under 2 -> 200, under 5 -> 150, under 10 -> 100,
## under 17 -> 80, under 33 -> 40, else 20.
static func flail_power(user_hp: int, user_max_hp: int) -> int:
	if user_max_hp <= 0:
		return 20
	var ratio: int = maxi(int(user_hp * 48 / user_max_hp), 1)
	if ratio < 2:
		return 200
	if ratio < 5:
		return 150
	if ratio < 10:
		return 100
	if ratio < 17:
		return 80
	if ratio < 33:
		return 40
	return 20


## Crush Grip, Wring Out (scale 120) and Hard Press (scale 100).
## Power grows the more HP the target has left.
## Showdown moves.ts, crushgrip / wringout / hardpress
## basePowerCallback, written out in full:
## bp = floor(floor((scale * (100 * floor(hp * 4096 / maxHP))
##      + 2047) / 4096) / 100), and at least 1.
## In plain words that is scale * target HP / target max HP,
## rounded down, and never less than 1.
static func crush_grip_power(target_hp: int, target_max_hp: int, scale: int = 120) -> int:
	if target_max_hp <= 0:
		return 1
	var hp: int = maxi(target_hp, 0)
	var step1: int = int(hp * 4096 / target_max_hp)
	var step2: int = int((scale * (100 * step1) + 2047) / 4096)
	var bp: int = int(step2 / 100)
	if bp < 1:
		bp = 1
	return bp


## Dragon Rage. Always deals 40 damage.
## Showdown moves.ts, dragonrage: damage: 40.
static func dragon_rage_damage() -> int:
	return 40


## Sonic Boom. Always deals 20 damage.
## Showdown moves.ts, sonicboom: damage: 20.
static func sonic_boom_damage() -> int:
	return 20


## Seismic Toss, Night Shade. Damage equals the user's level.
## Showdown moves.ts, seismictoss / nightshade: damage: 'level'.
static func level_damage(user_level: int) -> int:
	return maxi(user_level, 0)


## Guardian of Alola (3/4), Nature's Madness, Ruination and
## Super Fang (1/2). Damage is a fraction of the target's HP.
## Showdown moves.ts damageCallback for each one:
## Guardian of Alola: floor(target HP * 3 / 4).
## Nature's Madness / Ruination:
##   clamp(floor(target HP / 2), at least 1).
## Super Fang: clamp(target HP / 2, at least 1).
## The func floors the result at 1 so the hit always deals damage.
static func fraction_damage(target_hp: int, num: int, den: int) -> int:
	if den <= 0:
		return 1
	var damage: int = int(maxi(target_hp, 0) * num / den)
	if damage < 1:
		damage = 1
	return damage


## Fissure, Guillotine, Horn Drill, Sheer Cold. One hit knocks out.
## Showdown moves.ts: ohko: true (Sheer Cold: ohko: "Ice").
## Damage equal to the target's full HP is a knockout. The engine
## must still apply the OHKO accuracy rule first: accuracy is
## 30 + user level - target level, and the move fails if the user's
## level is lower than the target's. Normal type immunity applies.
static func ohko_damage(target_max_hp: int) -> int:
	return maxi(target_max_hp, 1)


## Counter, Mirror Coat, Metal Burst, Comeuppance. Damage is a
## multiple of the damage the user took: Counter 2x, Mirror Coat 2x,
## Metal Burst 1.5x, Comeuppance 1.5x. Pass the multiple as
## mult_num / mult_den (2/1 or 3/2) from the move's damage_rule.
## Showdown moves.ts:
## - counter: the 'counter' volatile stores 2 * physical damage
##   taken, and damageCallback returns it (or 1 when nothing was
##   stored). Priority -5. Fails with no stored hit.
## - mirrorcoat: same, but only Special damage, stored in the
##   'mirrorcoat' volatile. Priority -5.
## - metalburst: damageCallback returns last damage taken * 1.5
##   (or 1), and 0 when never damaged. Fails unless the user was
##   damaged this turn. Any move category counts.
## - comeuppance: same 1.5x rule as Metal Burst, and it also fails
##   unless the user was damaged this turn.
## The engine must do the filtering Showdown does: only Physical
## damage counts for Counter, only Special damage for Mirror Coat,
## and Metal Burst / Comeuppance need damage taken this turn.
## was_damaged is false when no hit was stored, and then the move
## deals 0 (it fails). A stored hit of 0 damage still deals 1.
static func counter_damage(last_damage_taken: int, mult_num: int, mult_den: int, was_damaged: bool) -> int:
	if not was_damaged:
		return 0
	if mult_den <= 0:
		return 1
	var damage: int = int(maxi(last_damage_taken, 0) * mult_num / mult_den)
	if damage < 1:
		damage = 1
	return damage


## Return, Pika Papow, Veevee Volley. Power from friendship.
## Showdown moves.ts, return / pikapapow / veeveevolley
## basePowerCallback: floor(friendship * 10 / 25), and at least 1.
## Friendship runs 0 to 255, so the most this can be is 102.
static func friendship_power(happiness: int) -> int:
	var friend: int = clampi(happiness, 0, 255)
	var bp: int = int(friend * 10 / 25)
	if bp < 1:
		bp = 1
	return bp


## Frustration. Power from low friendship: the less the user likes
## its trainer, the harder it hits.
## Showdown moves.ts, frustration basePowerCallback:
## floor((255 - friendship) * 10 / 25), and at least 1.
## Friendship runs 0 to 255, so the most this can be is 102.
static func frustration_power(happiness: int) -> int:
	var friend: int = clampi(happiness, 0, 255)
	var bp: int = int((255 - friend) * 10 / 25)
	if bp < 1:
		bp = 1
	return bp


## Fling. Power comes from the held item.
## Showdown moves.ts, fling onPrepareHit:
## if the item has no fling entry the move fails, otherwise
## move.basePower = item.fling.basePower.
## The per-item numbers live in Showdown data/items.ts, one
## "fling: { basePower: N }" block per item (for example
## Air Balloon 10, Ability Shield 30, Adamant Orb 60,
## Assault Vest 80, Armor Fossil 100). The controller passes the
## held item's fling power in. Pass 0 when there is no held item
## or the item has no fling power, and the move fails.
static func fling_power(item_fling_power: int) -> int:
	return maxi(item_fling_power, 0)


## Natural Gift. Power comes from the held berry.
## Showdown moves.ts, naturalgift onPrepareHit:
## if the item has no naturalGift entry the move fails, otherwise
## move.basePower = item.naturalGift.basePower, and the berry is
## used up. The move's type comes from item.naturalGift.type.
## The per-berry numbers live in Showdown data/items.ts, one
## "naturalGift: { basePower, type }" block per berry (for example
## Aguav Berry 80 Dragon, Apicot Berry 100 Ground,
## Aspear Berry 80 Ice, Babiri Berry 80 Steel).
## The controller passes the berry's power in. Pass 0 when there
## is no berry or it has no natural gift, and the move fails.
static func natural_gift_power(berry_power: int) -> int:
	return maxi(berry_power, 0)


## Natural Gift type. Pass the berry's natural gift type straight
## through (for example "Dragon"). Returns "Normal" when empty,
## which is the move's own type when no berry is held.
static func natural_gift_type(berry_type: String) -> String:
	if berry_type.is_empty():
		return "Normal"
	return berry_type


## Bide. Stores the damage taken, then hits back for twice as much.
## Showdown moves.ts, bide condition: while the user waits (up to
## 2 turns after the first), every hit adds its damage to
## totalDamage. On the last turn the move deals
## damage = totalDamage * 2 at the Pokemon that hit it last, and
## fails when nothing was stored. Priority 1.
## The controller keeps totalDamage and passes it in here.
static func bide_damage(stored_damage: int) -> int:
	return maxi(stored_damage, 0) * 2


## Endeavor. Damage is the target's HP minus the user's HP.
## Showdown moves.ts, endeavor damageCallback:
## return target HP - user HP. It only works when the user's HP
## is lower than the target's (onTryImmunity: user HP < target HP),
## so the controller must fail the move when that is not true.
## This func floors the result at 0 for safety.
static func endeavor_damage(target_hp: int, user_hp: int) -> int:
	return maxi(target_hp - user_hp, 0)


## Final Gambit. Damage is the user's HP, and the user faints.
## Showdown moves.ts, finalgambit damageCallback:
## damage = user HP, then the user faints (selfdestruct "ifHit").
## The controller deals the damage and then faints the user.
static func final_gambit_damage(user_hp: int) -> int:
	return maxi(user_hp, 0)


## Magnitude. Random power, rolled once when the move is used.
## Showdown moves.ts, magnitude onModifyMove: roll a number from
## 0 to 99. Under 5 -> power 10 (Magnitude 4), under 15 -> 30
## (Magnitude 5), under 35 -> 50 (Magnitude 6), under 65 -> 70
## (Magnitude 7), under 85 -> 90 (Magnitude 8), under 95 -> 110
## (Magnitude 9), else 150 (Magnitude 10).
## Pass the roll in (0 to 99). Chances: 5% / 10% / 20% / 30% /
## 20% / 10% / 5%.
static func magnitude_power(roll_0_99: int) -> int:
	var roll: int = clampi(roll_0_99, 0, 99)
	if roll < 5:
		return 10
	if roll < 15:
		return 30
	if roll < 35:
		return 50
	if roll < 65:
		return 70
	if roll < 85:
		return 90
	if roll < 95:
		return 110
	return 150


## Magnitude number (4 to 10) for the same roll, for the message
## the game shows ("Magnitude 7!"). Same thresholds as
## magnitude_power.
static func magnitude_number(roll_0_99: int) -> int:
	var roll: int = clampi(roll_0_99, 0, 99)
	if roll < 5:
		return 4
	if roll < 15:
		return 5
	if roll < 35:
		return 6
	if roll < 65:
		return 7
	if roll < 85:
		return 8
	if roll < 95:
		return 9
	return 10


## Present. A random pick each use: heal the target, or hit it.
## Showdown moves.ts, present onModifyMove: roll a number from 0
## to 9. Under 2 (20%) -> heal the target for 1/4 of its max HP.
## Under 6 (40%) -> power 40. Under 9 (30%) -> power 80.
## Else (10%) -> power 120.
## Pass the roll in (0 to 9). present_heals says if the roll is a
## heal. present_power returns the power, or 0 when the roll heals.
static func present_heals(roll_0_9: int) -> bool:
	return clampi(roll_0_9, 0, 9) < 2


static func present_power(roll_0_9: int) -> int:
	var roll: int = clampi(roll_0_9, 0, 9)
	if roll < 2:
		return 0
	if roll < 6:
		return 40
	if roll < 9:
		return 80
	return 120


## Present heal amount: 1/4 of the target's max HP, at least 1.
static func present_heal_amount(target_max_hp: int) -> int:
	return maxi(int(maxi(target_max_hp, 0) / 4), 1)


## Psywave. Damage is the user's level times a random 0.5 to 1.5.
## Showdown moves.ts, psywave damageCallback:
## (random number from 50 to 150, times user level) / 100.
## Pass the roll in (50 to 150).
static func psywave_damage(user_level: int, roll_50_150: int) -> int:
	var roll: int = clampi(roll_50_150, 50, 150)
	return maxi(int(roll * maxi(user_level, 0) / 100), 0)


## Spit Up. Power is 100 times the Stockpile count.
## Showdown moves.ts, spitup basePowerCallback:
## fails with no Stockpile, otherwise returns
## stockpile layers * 100. Stockpile holds 1 to 3 layers.
## Pass 0 layers when there is no Stockpile, and the move fails.
static func spit_up_power(stockpile_layers: int) -> int:
	return maxi(stockpile_layers, 0) * 100


## Trump Card. Power from the PP left on the move.
## Showdown moves.ts, trumpcard basePowerCallback: the PP the
## callback sees is counted AFTER the 1 PP for this use is spent,
## so the cases read: 0 PP left here -> 200, 1 -> 80, 2 -> 60,
## 3 -> 50, anything else -> 40. Counted the way a player sees
## it (PP left when the move is picked, before spending 1 PP),
## that is: 1 PP left -> 200, 2 -> 80, 3 -> 60, 4 -> 50,
## 5 or more -> 40.
## Pass pp_left as the PP left when the move is picked.
static func trump_card_power(pp_left: int) -> int:
	if pp_left <= 1:
		return 200
	if pp_left == 2:
		return 80
	if pp_left == 3:
		return 60
	if pp_left == 4:
		return 50
	return 40


## Beat Up. One hit per able party member. Each hit's power is
## 5 + that member's base Attack / 10.
## Showdown moves.ts, beatup basePowerCallback:
## bp = 5 + floor(that member's base Attack / 10).
## The hits are set in onModifyMove: the move hits once for each
## party member that is the user, or is not fainted and has no
## status. Pass one member's base Attack in per hit.
static func beat_up_power(ally_base_atk: int) -> int:
	return 5 + int(maxi(ally_base_atk, 0) / 10)


## Beat Up hit count. Pass the count of able party members: the
## user plus every party member that is not fainted and has no
## status. That count is the number of hits.
static func beat_up_hit_count(able_party_count: int) -> int:
	return maxi(able_party_count, 0)


## Punishment. Power grows with the target's raised stats.
## Showdown moves.ts, punishment basePowerCallback:
## power = 60 + 20 * target.positiveBoosts(), capped at 200.
## positiveBoosts is the total of the target's stat stages above
## zero (for example +2 Attack and +1 Speed is 3). Pass that
## total in.
static func punishment_power(positive_boost_total: int) -> int:
	var power: int = 60 + 20 * maxi(positive_boost_total, 0)
	if power > 200:
		power = 200
	return power
