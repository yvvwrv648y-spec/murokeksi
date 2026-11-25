class_name PUWGen9BattleMechanics
extends RefCounted
## Authentic Gen IX Stat, IV/EV (252+ Rule), Scaled EXP, Optional Exp. Share, & 4-Gimmick Omni Ring Engine.

const MAX_IV := 31
const MAX_EV_PER_STAT := 252
const MAX_TOTAL_EV := 510

static func calc_hp(base_hp: int, iv: int, ev: int, level: int) -> int:
	return int(floor(((2 * base_hp + clampi(iv, 0, MAX_IV) + int(floor(clampi(ev, 0, MAX_EV_PER_STAT) / 4.0))) * level) / 100.0)) + level + 10

static func calc_stat(base_val: int, iv: int, ev: int, level: int, nature_mult: float = 1.0) -> int:
	var core := int(floor(((2 * base_val + clampi(iv, 0, MAX_IV) + int(floor(clampi(ev, 0, MAX_EV_PER_STAT) / 4.0))) * level) / 100.0)) + 5
	return int(floor(core * nature_mult))

static func calc_gen9_scaled_exp(base_yield: int, defeated_lv: int, winner_lv: int) -> int:
	var a := float(base_yield * defeated_lv) / 5.0
	var ratio := pow((2.0 * defeated_lv + 10.0) / (defeated_lv + winner_lv + 10.0), 2.5)
	return maxi(1, int(floor(a * ratio)) + 1)

static func add_ev_clamped(evs: Dictionary, stat_key: String, gain: int) -> Dictionary:
	var total := 0
	for k in evs.keys():
		total += int(evs[k])
	var room_total := maxi(0, MAX_TOTAL_EV - total)
	var room_stat := maxi(0, MAX_EV_PER_STAT - int(evs.get(stat_key, 0)))
	var applied := mini(gain, mini(room_total, room_stat))
	evs[stat_key] = int(evs.get(stat_key, 0)) + applied
	return evs

const BADGE_HARD_CAPS := [10, 20, 24, 29, 40, 43, 47, 50, 100]

static func get_hard_level_cap(badge_count: int) -> int:
	return BADGE_HARD_CAPS[clampi(badge_count, 0, BADGE_HARD_CAPS.size() - 1)]
