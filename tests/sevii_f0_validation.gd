extends SceneTree
## SEVII F0 VALIDATION — build 6, A-46 leg (ii). The Kanto F0
## pattern (code_prep_kanto_trainers/validation) applied to the
## 99 Sevii placements merged by A-46: spawn through the bound
## path (PUWBattleEntry.trainer_base_identity +
## start_route_trainer_battle) at player-max levels
## 5/35/50/75/100 and record, per placement/level: team size,
## base-mon build problems (zero moves, IV != 31, EV > 510),
## and the hand_off() guard verdict at expect_size 6. Also
## records dialogue resolution (spawner.dialogue_for) and VS
## front coverage per class — rates, not assertions (Sevii
## dialogue certifies per its restoration state, §9.5(c)).
## Writes res://tests/sevii_f0_out.json; quit code 0 when no
## build problems and every hand-off passes.

const LEVELS: Array = [5, 35, 50, 75, 100]
const OUT_PATH: String = "res://tests/sevii_f0_out.json"

var _entry: PUWBattleEntry = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _init() -> void:
	_rng.seed = 6006
	_entry = PUWBattleEntry.new()
	var trainers_v: Variant = _load_json("res://data/trainers.json")
	var trainers: Dictionary = trainers_v if trainers_v is Dictionary else {}
	var placements_v: Variant = trainers.get("placements", [])
	var placements: Array = placements_v if placements_v is Array else []
	var intro_v: Variant = _load_json("res://data/battle_intro_index.json")
	var intro: Dictionary = intro_v if intro_v is Dictionary else {}
	var fronts_v: Variant = intro.get("fronts", {})
	var fronts: Dictionary = fronts_v if fronts_v is Dictionary else {}
	var spawner: PUWSpawner = PUWSpawner.new()
	var records: Array = []
	var problems_total: int = 0
	var handoff_failures: int = 0
	var dialogue_ok: int = 0
	var fronts_ok: int = 0
	var sevii_count: int = 0
	for p_v in placements:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		if str(p.get("region", "")) != "sevii":
			continue
		sevii_count += 1
		var cls: String = str(p.get("class", ""))
		var pi: int = int(p.get("party_index", 0))
		var map_name: String = str(p.get("map", ""))
		var rec: Dictionary = {"map": map_name, "class": cls, "party_index": pi}
		var identity: Array = _entry.trainer_base_identity(cls, pi, "sevii")
		if identity.is_empty():
			identity = _entry.trainer_base_identity(cls, pi, "kanto")
		rec["identity_size"] = identity.size()
		if identity.is_empty():
			rec["identity_missing"] = true
			problems_total += 1
		var per_level: Dictionary = {}
		for lv_v in LEVELS:
			var lv: int = int(lv_v)
			var trigger: Dictionary = {"trainer_class": cls, "party_index": pi, "source": "sevii"}
			var res: Dictionary = _entry.start_route_trainer_battle(trigger, lv, "singles", _rng)
			var team_v: Variant = res.get("enemy_party", [])
			var team: Array = team_v if team_v is Array else []
			var lvl_rec: Dictionary = {"size": team.size(), "problems": []}
			var probs: Array = lvl_rec["problems"]
			for mon_v in team:
				if not (mon_v is Dictionary):
					continue
				var mon: Dictionary = mon_v
				var moves_v: Variant = mon.get("moves", [])
				var moves: Array = moves_v if moves_v is Array else []
				if moves.is_empty():
					probs.append("zero_moves:" + str(mon.get("species", "?")))
				var ivs_v: Variant = mon.get("ivs", {})
				if ivs_v is Dictionary:
					for stat_v in (ivs_v as Dictionary).values():
						if int(stat_v) != 31:
							probs.append("iv_not_31:" + str(mon.get("species", "?")))
							break
				var evs_v: Variant = mon.get("evs", {})
				if evs_v is Dictionary:
					var total: int = 0
					for stat_v2 in (evs_v as Dictionary).values():
						total += int(stat_v2)
					if total > 510:
						probs.append("ev_over_510:" + str(mon.get("species", "?")))
			if team.is_empty():
				lvl_rec["handoff_ok"] = false
				handoff_failures += 1
			else:
				var verdict: Dictionary = PUWBattleEntry.hand_off(team, 6, {"exact": lv})
				lvl_rec["handoff_ok"] = bool(verdict.get("ok", false))
				if not bool(verdict.get("ok", false)):
					handoff_failures += 1
			problems_total += probs.size()
			per_level[str(lv)] = lvl_rec
		rec["per_level"] = per_level
		var text_ref: String = str(p.get("text_id", p.get("script", "")))
		var lines: Array = spawner.dialogue_for(map_name, text_ref)
		rec["dialogue_ok"] = not lines.is_empty()
		if not lines.is_empty():
			dialogue_ok += 1
		rec["front_ok"] = fronts.has(cls)
		if fronts.has(cls):
			fronts_ok += 1
		records.append(rec)
	var out: Dictionary = {
		"sevii_placements": sevii_count,
		"build_problems": problems_total,
		"handoff_failures": handoff_failures,
		"dialogue_ok": dialogue_ok,
		"fronts_ok": fronts_ok,
		"records": records,
	}
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
	print("SEVII_F0 placements=", sevii_count, " build_problems=", problems_total,
		" handoff_failures=", handoff_failures, " dialogue_ok=", dialogue_ok,
		" fronts_ok=", fronts_ok)
	quit(0 if problems_total == 0 and handoff_failures == 0 and sevii_count == 99 else 1)
