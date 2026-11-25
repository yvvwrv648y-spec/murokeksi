extends SceneTree
## Headless tests for the held-item battle hooks prep
## (staging hidden_files/code_prep_items_hooks) — the 59
## TOP_BATCH items the top-batch prep reclassified as held-item
## battle hooks, plus the held triggers of the 6 cure Berries.
##
## Run with Godot 4.7.2:
##   godot --headless --path <harness project> --script res://tests/item_hooks_tests.gd
##
## Prints one PASS or FAIL line per test, then a summary, then
## quits. Exit code 0 = all passed, 1 = at least one failed.
## Every hook has a fires case and, where the condition has a
## meaningful outside, a does-not-fire case.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW held-item battle hooks tests — starting.")
	if root == null:
		print("FAIL: no scene tree root.")
		quit(1)
		return
	_run("test_booster_energy", Callable(self, "test_booster_energy"))
	_run("test_rocky_helmet", Callable(self, "test_rocky_helmet"))
	_run("test_covert_cloak", Callable(self, "test_covert_cloak"))
	_run("test_black_sludge", Callable(self, "test_black_sludge"))
	_run("test_safety_goggles", Callable(self, "test_safety_goggles"))
	_run("test_power_herb", Callable(self, "test_power_herb"))
	_run("test_clear_amulet", Callable(self, "test_clear_amulet"))
	_run("test_flame_orb", Callable(self, "test_flame_orb"))
	_run("test_light_clay", Callable(self, "test_light_clay"))
	_run("test_throat_spray", Callable(self, "test_throat_spray"))
	_run("test_custap_berry", Callable(self, "test_custap_berry"))
	_run("test_weather_rocks", Callable(self, "test_weather_rocks"))
	_run("test_terrain_seeds", Callable(self, "test_terrain_seeds"))
	_run("test_loaded_dice", Callable(self, "test_loaded_dice"))
	_run("test_soul_dew", Callable(self, "test_soul_dew"))
	_run("test_toxic_orb", Callable(self, "test_toxic_orb"))
	_run("test_type_boost_items", Callable(self, "test_type_boost_items"))
	_run("test_eject_pack", Callable(self, "test_eject_pack"))
	_run("test_expert_belt", Callable(self, "test_expert_belt"))
	_run("test_light_ball", Callable(self, "test_light_ball"))
	_run("test_mental_herb", Callable(self, "test_mental_herb"))
	_run("test_miracle_berry", Callable(self, "test_miracle_berry"))
	_run("test_protective_pads", Callable(self, "test_protective_pads"))
	_run("test_thick_club", Callable(self, "test_thick_club"))
	_run("test_eject_button", Callable(self, "test_eject_button"))
	_run("test_shell_bell", Callable(self, "test_shell_bell"))
	_run("test_crit_items", Callable(self, "test_crit_items"))
	_run("test_wide_lens", Callable(self, "test_wide_lens"))
	_run("test_focus_band", Callable(self, "test_focus_band"))
	_run("test_quick_claw", Callable(self, "test_quick_claw"))
	_run("test_white_herb", Callable(self, "test_white_herb"))
	_run("test_metronome_item", Callable(self, "test_metronome_item"))
	_run("test_terrain_extender", Callable(self, "test_terrain_extender"))
	_run("test_adrenaline_orb", Callable(self, "test_adrenaline_orb"))
	_run("test_mirror_herb", Callable(self, "test_mirror_herb"))
	_run("test_blunder_policy", Callable(self, "test_blunder_policy"))
	_run("test_room_service", Callable(self, "test_room_service"))
	_run("test_big_root", Callable(self, "test_big_root"))
	_run("test_ability_shield", Callable(self, "test_ability_shield"))
	_run("test_jaboca_rowap", Callable(self, "test_jaboca_rowap"))
	_run("test_kee_maranga", Callable(self, "test_kee_maranga"))
	_run("test_lansat_berry", Callable(self, "test_lansat_berry"))
	_run("test_micle_berry", Callable(self, "test_micle_berry"))
	_run("test_metal_powder", Callable(self, "test_metal_powder"))
	_run("test_orbs_species", Callable(self, "test_orbs_species"))
	_run("test_held_cure_berries", Callable(self, "test_held_cure_berries"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


## A plain test mon. Overrides are merged over the defaults.
func _mon(overrides: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": "Testmon", "species": "Testmon", "hp": 100, "max_hp": 100,
		"status": "", "confused": false, "confusion_turns": 0,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
		"types": ["Normal"], "volatiles": {},
		"level": 50, "ability": "Run Away", "item": "",
		"atk": 100, "def": 100, "spa": 100, "spd": 100, "spe": 100,
	}
	for key in overrides.keys():
		mon[key] = overrides[key]
	return mon


func _field() -> Dictionary:
	return StatusAndFieldEngine.create_field_state()


# ------------------------------------------------------------------
# Switch-in and field hooks
# ------------------------------------------------------------------

func test_booster_energy() -> bool:
	# Already implemented in AbilityBatch3 before this prep:
	# a Protosynthesis mon entering with no sun spends its
	# Booster Energy and activates.
	var field: Dictionary = _field()
	var logs: Array = []
	var mon: Dictionary = _mon({"ability": "Protosynthesis", "item": "Booster Energy", "name": "Flutter Mane", "species": "Flutter Mane"})
	AbilityEngine.on_switch_in(mon, _mon({}), field)
	if str(mon.get("item", "")) != "":
		return false
	if not bool(mon.get("protosynthesis_active", false)):
		return false
	if not bool(mon.get("proto_from_booster", false)):
		return false
	# With sun already up it activates from the sun and the
	# item is NOT spent.
	var field2: Dictionary = _field()
	field2["weather"] = "sun"
	var mon2: Dictionary = _mon({"ability": "Protosynthesis", "item": "Booster Energy", "name": "Flutter Mane", "species": "Flutter Mane"})
	AbilityEngine.on_switch_in(mon2, _mon({}), field2)
	if str(mon2.get("item", "")) != "Booster Energy":
		return false
	if not bool(mon2.get("protosynthesis_active", false)):
		return false
	# A non-Paradox ability never spends it.
	var mon3: Dictionary = _mon({"ability": "Run Away", "item": "Booster Energy"})
	AbilityEngine.on_switch_in(mon3, _mon({}), _field())
	return str(mon3.get("item", "")) == "Booster Energy" and logs.size() >= 0


func test_weather_rocks() -> bool:
	# The duration helper itself.
	var rock: Dictionary = _mon({"item": "Heat Rock"})
	if ItemEngine.weather_duration(rock, "sun", 5) != 8:
		return false
	if ItemEngine.weather_duration(rock, "rain", 5) != 5:
		return false
	if ItemEngine.weather_duration(_mon({}), "sun", 5) != 5:
		return false
	# Wired at the ability switch-in arms: Drought + Heat Rock
	# sets 8 turns of sun; Drizzle + Damp Rock 8 of rain; Sand
	# Stream + Smooth Rock 8; Snow Warning + Icy Rock 8.
	var f1: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Drought", "item": "Heat Rock"}), _mon({}), f1)
	if int(f1.get("weather_turns", 0)) != 8:
		return false
	var f2: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Drizzle", "item": "Damp Rock"}), _mon({}), f2)
	if int(f2.get("weather_turns", 0)) != 8:
		return false
	var f3: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Sand Stream", "item": "Smooth Rock"}), _mon({}), f3)
	if int(f3.get("weather_turns", 0)) != 8:
		return false
	var f4: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Snow Warning", "item": "Icy Rock"}), _mon({}), f4)
	if int(f4.get("weather_turns", 0)) != 8:
		return false
	# Without the rock the same arm still sets 5.
	var f5: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Drought"}), _mon({}), f5)
	return int(f5.get("weather_turns", 0)) == 5


func test_terrain_extender() -> bool:
	if ItemEngine.terrain_duration(_mon({"item": "Terrain Extender"}), 5) != 8:
		return false
	if ItemEngine.terrain_duration(_mon({}), 5) != 5:
		return false
	# Wired at a Surge arm: Electric Surge + Extender = 8.
	var f1: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Electric Surge", "item": "Terrain Extender"}), _mon({}), f1)
	if int(f1.get("terrain_turns", 0)) != 8:
		return false
	var f2: Dictionary = _field()
	AbilityEngine.on_switch_in(_mon({"ability": "Electric Surge"}), _mon({}), f2)
	return int(f2.get("terrain_turns", 0)) == 5


func test_terrain_seeds() -> bool:
	# Electric Seed on Electric Terrain: Defense +1, consumed.
	var f1: Dictionary = _field()
	f1["terrain"] = "electric"
	var logs1: Array = []
	var m1: Dictionary = _mon({"item": "Electric Seed"})
	ItemEngine.on_switch_in_items(m1, f1, logs1)
	if int(m1["stages"].get("def", 0)) != 1 or str(m1.get("item", "")) != "":
		return false
	# No terrain up: nothing happens, seed kept.
	var logs2: Array = []
	var m2: Dictionary = _mon({"item": "Electric Seed"})
	ItemEngine.on_switch_in_items(m2, _field(), logs2)
	if str(m2.get("item", "")) != "Electric Seed" or int(m2["stages"].get("def", 0)) != 0:
		return false
	# Wrong terrain for the seed: nothing.
	var f3: Dictionary = _field()
	f3["terrain"] = "grassy"
	var logs3: Array = []
	var m3: Dictionary = _mon({"item": "Electric Seed"})
	ItemEngine.on_switch_in_items(m3, f3, logs3)
	if str(m3.get("item", "")) != "Electric Seed":
		return false
	# Grassy Seed raises Defense; Misty and Psychic Seeds
	# raise Special Defense.
	var f4: Dictionary = _field()
	f4["terrain"] = "grassy"
	var logs4: Array = []
	var m4: Dictionary = _mon({"item": "Grassy Seed"})
	ItemEngine.on_switch_in_items(m4, f4, logs4)
	if int(m4["stages"].get("def", 0)) != 1:
		return false
	var f5: Dictionary = _field()
	f5["terrain"] = "misty"
	var logs5: Array = []
	var m5: Dictionary = _mon({"item": "Misty Seed"})
	ItemEngine.on_switch_in_items(m5, f5, logs5)
	if int(m5["stages"].get("spd", 0)) != 1:
		return false
	var f6: Dictionary = _field()
	f6["terrain"] = "psychic"
	var logs6: Array = []
	var m6: Dictionary = _mon({"item": "Psychic Seed"})
	ItemEngine.on_switch_in_items(m6, f6, logs6)
	return int(m6["stages"].get("spd", 0)) == 1 and str(m6.get("item", "")) == ""


func test_room_service() -> bool:
	# Trick Room already up at switch-in: Speed -1, consumed.
	var f1: Dictionary = _field()
	f1["trick_room"] = 3
	var logs1: Array = []
	var m1: Dictionary = _mon({"item": "Room Service"})
	ItemEngine.on_switch_in_items(m1, f1, logs1)
	if int(m1["stages"].get("spe", 0)) != -1 or str(m1.get("item", "")) != "":
		return false
	# No Trick Room: nothing.
	var logs2: Array = []
	var m2: Dictionary = _mon({"item": "Room Service"})
	ItemEngine.on_switch_in_items(m2, _field(), logs2)
	if int(m2["stages"].get("spe", 0)) != 0 or str(m2.get("item", "")) != "Room Service":
		return false
	# Trick Room set while already out.
	var logs3: Array = []
	var m3: Dictionary = _mon({"item": "Room Service"})
	ItemEngine.on_trick_room_set(m3, logs3)
	return int(m3["stages"].get("spe", 0)) == -1 and str(m3.get("item", "")) == ""


func test_light_clay() -> bool:
	if ItemEngine.screen_duration(_mon({"item": "Light Clay"}), 5) != 8:
		return false
	return ItemEngine.screen_duration(_mon({}), 5) == 5


func test_power_herb() -> bool:
	var beam: Dictionary = {"name": "Solar Beam", "id": "solarbeam"}
	var tackle: Dictionary = {"name": "Tackle", "id": "tackle"}
	if not ItemEngine.is_charge_move(beam):
		return false
	if ItemEngine.is_charge_move(tackle):
		return false
	var logs: Array = []
	var mon: Dictionary = _mon({"item": "Power Herb"})
	if not ItemEngine.try_use_power_herb(mon, beam, logs):
		return false
	if str(mon.get("item", "")) != "":
		return false
	var mon2: Dictionary = _mon({"item": "Power Herb"})
	if ItemEngine.try_use_power_herb(mon2, tackle, logs):
		return false
	return str(mon2.get("item", "")) == "Power Herb"


func test_ability_shield() -> bool:
	if not ItemEngine.blocks_ability_change(_mon({"item": "Ability Shield"})):
		return false
	return not ItemEngine.blocks_ability_change(_mon({}))


# ------------------------------------------------------------------
# Damage-flow hooks
# ------------------------------------------------------------------

func test_rocky_helmet() -> bool:
	var field: Dictionary = _field()
	var contact: Dictionary = {"name": "Tackle", "cat": "Physical", "flags": {"contact": true}}
	var ranged: Dictionary = {"name": "Rock Throw", "cat": "Physical", "flags": {}}
	# Contact hit: attacker loses 1/6 of its max HP (120 -> 20).
	var logs1: Array = []
	var def1: Dictionary = _mon({"item": "Rocky Helmet", "hp": 90})
	var atk1: Dictionary = _mon({"max_hp": 120, "hp": 120})
	ItemEngine.on_damage_taken(def1, contact, logs1, atk1, 10, field)
	if int(atk1.get("hp", 0)) != 100:
		return false
	# Non-contact hit: nothing.
	var logs2: Array = []
	var def2: Dictionary = _mon({"item": "Rocky Helmet", "hp": 90})
	var atk2: Dictionary = _mon({"max_hp": 120, "hp": 120})
	ItemEngine.on_damage_taken(def2, ranged, logs2, atk2, 10, field)
	if int(atk2.get("hp", 0)) != 120:
		return false
	# Old three-argument call shape (Struggle-style sites
	# before this prep): the arm stays silent.
	var logs3: Array = []
	var def3: Dictionary = _mon({"item": "Rocky Helmet", "hp": 90})
	ItemEngine.on_damage_taken(def3, contact, logs3)
	return int(def3.get("hp", 0)) == 90


func test_protective_pads() -> bool:
	var field: Dictionary = _field()
	var contact: Dictionary = {"name": "Tackle", "cat": "Physical", "flags": {"contact": true}}
	# Padded attacker vs Rocky Helmet: no chip.
	var logs1: Array = []
	var def1: Dictionary = _mon({"item": "Rocky Helmet", "hp": 90})
	var atk1: Dictionary = _mon({"item": "Protective Pads", "max_hp": 120, "hp": 120})
	ItemEngine.on_damage_taken(def1, contact, logs1, atk1, 10, field)
	if int(atk1.get("hp", 0)) != 120:
		return false
	# Padded attacker vs Jaboca Berry: no chip AND the Berry
	# is not eaten.
	var logs2: Array = []
	var def2: Dictionary = _mon({"item": "Jaboca Berry", "hp": 90})
	var atk2: Dictionary = _mon({"item": "Protective Pads", "max_hp": 120, "hp": 120})
	ItemEngine.on_damage_taken(def2, contact, logs2, atk2, 10, field)
	if int(atk2.get("hp", 0)) != 120:
		return false
	return str(def2.get("item", "")) == "Jaboca Berry"


func test_jaboca_rowap() -> bool:
	var field: Dictionary = _field()
	var phys: Dictionary = {"name": "Tackle", "cat": "Physical", "flags": {}}
	var spec: Dictionary = {"name": "Ember", "cat": "Special", "flags": {}}
	# Jaboca on a physical hit: attacker loses 1/8 (160 -> 20),
	# Berry consumed.
	var logs1: Array = []
	var def1: Dictionary = _mon({"item": "Jaboca Berry", "hp": 90})
	var atk1: Dictionary = _mon({"max_hp": 160, "hp": 160})
	ItemEngine.on_damage_taken(def1, phys, logs1, atk1, 10, field)
	if int(atk1.get("hp", 0)) != 140 or str(def1.get("item", "")) != "":
		return false
	# Jaboca on a special hit: nothing.
	var logs2: Array = []
	var def2: Dictionary = _mon({"item": "Jaboca Berry", "hp": 90})
	var atk2: Dictionary = _mon({"max_hp": 160, "hp": 160})
	ItemEngine.on_damage_taken(def2, spec, logs2, atk2, 10, field)
	if int(atk2.get("hp", 0)) != 160 or str(def2.get("item", "")) != "Jaboca Berry":
		return false
	# Rowap mirrors it on special hits.
	var logs3: Array = []
	var def3: Dictionary = _mon({"item": "Rowap Berry", "hp": 90})
	var atk3: Dictionary = _mon({"max_hp": 160, "hp": 160})
	ItemEngine.on_damage_taken(def3, spec, logs3, atk3, 10, field)
	if int(atk3.get("hp", 0)) != 140 or str(def3.get("item", "")) != "":
		return false
	var logs4: Array = []
	var def4: Dictionary = _mon({"item": "Rowap Berry", "hp": 90})
	var atk4: Dictionary = _mon({"max_hp": 160, "hp": 160})
	ItemEngine.on_damage_taken(def4, phys, logs4, atk4, 10, field)
	return int(atk4.get("hp", 0)) == 160 and str(def4.get("item", "")) == "Rowap Berry"


func test_kee_maranga() -> bool:
	var field: Dictionary = _field()
	var phys: Dictionary = {"name": "Tackle", "cat": "Physical", "flags": {}}
	var spec: Dictionary = {"name": "Ember", "cat": "Special", "flags": {}}
	var logs1: Array = []
	var def1: Dictionary = _mon({"item": "Kee Berry", "hp": 90})
	ItemEngine.on_damage_taken(def1, phys, logs1, _mon({}), 10, field)
	if int(def1["stages"].get("def", 0)) != 1 or str(def1.get("item", "")) != "":
		return false
	var logs2: Array = []
	var def2: Dictionary = _mon({"item": "Kee Berry", "hp": 90})
	ItemEngine.on_damage_taken(def2, spec, logs2, _mon({}), 10, field)
	if int(def2["stages"].get("def", 0)) != 0 or str(def2.get("item", "")) != "Kee Berry":
		return false
	var logs3: Array = []
	var def3: Dictionary = _mon({"item": "Maranga Berry", "hp": 90})
	ItemEngine.on_damage_taken(def3, spec, logs3, _mon({}), 10, field)
	if int(def3["stages"].get("spd", 0)) != 1 or str(def3.get("item", "")) != "":
		return false
	var logs4: Array = []
	var def4: Dictionary = _mon({"item": "Maranga Berry", "hp": 90})
	ItemEngine.on_damage_taken(def4, phys, logs4, _mon({}), 10, field)
	return int(def4["stages"].get("spd", 0)) == 0 and str(def4.get("item", "")) == "Maranga Berry"


func test_shell_bell() -> bool:
	var logs: Array = []
	var mon: Dictionary = _mon({"item": "Shell Bell", "hp": 50})
	ItemEngine.apply_shell_bell_after_attack(mon, 80, logs)
	if int(mon.get("hp", 0)) != 60:
		return false
	# No damage dealt: no heal.
	var mon2: Dictionary = _mon({"item": "Shell Bell", "hp": 50})
	ItemEngine.apply_shell_bell_after_attack(mon2, 0, logs)
	if int(mon2.get("hp", 0)) != 50:
		return false
	# Heal Block: no heal.
	var mon3: Dictionary = _mon({"item": "Shell Bell", "hp": 50, "heal_block_turns": 2})
	ItemEngine.apply_shell_bell_after_attack(mon3, 80, logs)
	return int(mon3.get("hp", 0)) == 50


func test_focus_band() -> bool:
	# Statistical: over many seeded rolls the band must save
	# sometimes and fail sometimes, at any HP (unlike Sash),
	# and never be consumed.
	var saves: int = 0
	var fails: int = 0
	for i in range(300):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var logs: Array = []
		var mon: Dictionary = _mon({"item": "Focus Band", "hp": 50})
		var out_dmg: int = ItemEngine.check_focus_band(mon, 60, rng, logs)
		if str(mon.get("item", "")) != "Focus Band":
			return false
		if out_dmg == 49:
			saves += 1
		elif out_dmg == 60:
			fails += 1
		else:
			return false
	if saves == 0 or fails == 0:
		return false
	# Damage that would not KO passes through untouched.
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 7
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "Focus Band", "hp": 50})
	return ItemEngine.check_focus_band(mon2, 30, rng2, logs2) == 30


func test_eject_button() -> bool:
	var standing: Dictionary = _mon({"item": "Eject Button", "hp": 40})
	if not ItemEngine.check_eject_button(standing):
		return false
	if str(standing.get("item", "")) != "" or str(standing.get("item_consumed", "")) != "Eject Button":
		return false
	var fainted: Dictionary = _mon({"item": "Eject Button", "hp": 0})
	if ItemEngine.check_eject_button(fainted):
		return false
	var other: Dictionary = _mon({"item": "Leftovers", "hp": 40})
	return not ItemEngine.check_eject_button(other)


func test_type_boost_items() -> bool:
	var defender: Dictionary = _mon({"types": ["Normal"]})
	var cases: Array = [
		["Black Glasses", "Dark"], ["Magnet", "Electric"],
		["Mystic Water", "Water"], ["Twisted Spoon", "Psychic"],
	]
	for c in cases:
		var attacker: Dictionary = _mon({"item": str(c[0])})
		var move: Dictionary = {"name": "Hit", "type": str(c[1]), "cat": "Special"}
		if ItemEngine.modify_attack_damage(attacker, defender, move, 100) != 120:
			return false
		var off_move: Dictionary = {"name": "Hit", "type": "Fire", "cat": "Special"}
		if ItemEngine.modify_attack_damage(attacker, defender, off_move, 100) != 100:
			return false
	return true


func test_soul_dew() -> bool:
	var defender: Dictionary = _mon({"types": ["Normal"]})
	var latias: Dictionary = _mon({"item": "Soul Dew", "species": "Latias", "name": "Latias"})
	var dragon: Dictionary = {"name": "Dragon Pulse", "type": "Dragon", "cat": "Special"}
	var psychic: Dictionary = {"name": "Psychic", "type": "Psychic", "cat": "Special"}
	var fire: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special"}
	if ItemEngine.modify_attack_damage(latias, defender, dragon, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(latias, defender, psychic, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(latias, defender, fire, 100) != 100:
		return false
	# Wrong species: no boost even on a Dragon move.
	var other: Dictionary = _mon({"item": "Soul Dew", "species": "Testmon"})
	return ItemEngine.modify_attack_damage(other, defender, dragon, 100) == 100


func test_orbs_species() -> bool:
	var defender: Dictionary = _mon({"types": ["Normal"]})
	var dialga: Dictionary = _mon({"item": "Adamant Orb", "species": "Dialga", "name": "Dialga"})
	var steel: Dictionary = {"name": "Flash Cannon", "type": "Steel", "cat": "Special"}
	var dragon: Dictionary = {"name": "Dragon Pulse", "type": "Dragon", "cat": "Special"}
	var water: Dictionary = {"name": "Surf", "type": "Water", "cat": "Special"}
	if ItemEngine.modify_attack_damage(dialga, defender, steel, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(dialga, defender, dragon, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(dialga, defender, water, 100) != 100:
		return false
	var palkia: Dictionary = _mon({"item": "Lustrous Orb", "species": "Palkia", "name": "Palkia"})
	if ItemEngine.modify_attack_damage(palkia, defender, water, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(palkia, defender, dragon, 100) != 120:
		return false
	if ItemEngine.modify_attack_damage(palkia, defender, steel, 100) != 100:
		return false
	# Right item, wrong species.
	var fake: Dictionary = _mon({"item": "Adamant Orb", "species": "Testmon"})
	return ItemEngine.modify_attack_damage(fake, defender, steel, 100) == 100


func test_expert_belt() -> bool:
	var belt: Dictionary = _mon({"item": "Expert Belt"})
	var grass: Dictionary = _mon({"types": ["Grass"]})
	var fire_move: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special"}
	if ItemEngine.modify_attack_damage(belt, grass, fire_move, 100) != 120:
		return false
	# Neutral hit: no boost.
	var normal_def: Dictionary = _mon({"types": ["Normal"]})
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical"}
	if ItemEngine.modify_attack_damage(belt, normal_def, tackle, 100) != 100:
		return false
	# Resisted hit: no boost.
	var water_def: Dictionary = _mon({"types": ["Water"]})
	return ItemEngine.modify_attack_damage(belt, water_def, fire_move, 100) == 100


func test_light_ball() -> bool:
	var pika: Dictionary = _mon({"item": "Light Ball", "species": "Pikachu", "name": "Pikachu"})
	if ItemEngine.stat_multiplier(pika, "atk") != 2.0:
		return false
	if ItemEngine.stat_multiplier(pika, "spa") != 2.0:
		return false
	if ItemEngine.stat_multiplier(pika, "spe") != 1.0:
		return false
	var other: Dictionary = _mon({"item": "Light Ball", "species": "Testmon"})
	return ItemEngine.stat_multiplier(other, "atk") == 1.0


func test_thick_club() -> bool:
	var cubone: Dictionary = _mon({"item": "Thick Club", "species": "Cubone", "name": "Cubone"})
	if ItemEngine.stat_multiplier(cubone, "atk") != 2.0:
		return false
	if ItemEngine.stat_multiplier(cubone, "spa") != 1.0:
		return false
	var marowak: Dictionary = _mon({"item": "Thick Club", "species": "Marowak", "name": "Marowak"})
	if ItemEngine.stat_multiplier(marowak, "atk") != 2.0:
		return false
	var other: Dictionary = _mon({"item": "Thick Club", "species": "Testmon"})
	return ItemEngine.stat_multiplier(other, "atk") == 1.0


func test_metal_powder() -> bool:
	var ditto: Dictionary = _mon({"item": "Metal Powder", "species": "Ditto", "name": "Ditto"})
	if ItemEngine.stat_multiplier(ditto, "def") != 1.5:
		return false
	if ItemEngine.stat_multiplier(ditto, "spd") != 1.5:
		return false
	if ItemEngine.stat_multiplier(ditto, "atk") != 1.0:
		return false
	# Lost once Transformed.
	var transformed: Dictionary = _mon({"item": "Metal Powder", "species": "Ditto", "name": "Ditto", "transformed": true})
	return ItemEngine.stat_multiplier(transformed, "def") == 1.0


func test_crit_items() -> bool:
	if ItemEngine.crit_stage(_mon({"item": "Scope Lens"})) != 1:
		return false
	if ItemEngine.crit_stage(_mon({"item": "Lucky Punch", "species": "Chansey", "name": "Chansey"})) != 2:
		return false
	if ItemEngine.crit_stage(_mon({"item": "Lucky Punch", "species": "Testmon"})) != 0:
		return false
	if ItemEngine.crit_stage(_mon({"item": "Stick", "species": "Farfetch'd", "name": "Farfetch'd"})) != 2:
		return false
	if ItemEngine.crit_stage(_mon({"item": "Stick", "species": "Sirfetch'd", "name": "Sirfetch'd"})) != 2:
		return false
	if ItemEngine.crit_stage(_mon({"item": "Stick", "species": "Testmon"})) != 0:
		return false
	# The Dire Hit volatile rides the same total (the
	# top-batch prep's wiring step, landed here).
	if ItemEngine.crit_stage(_mon({"crit_stage_bonus": 2})) != 2:
		return false
	return ItemEngine.crit_stage(_mon({})) == 0


func test_wide_lens() -> bool:
	if absf(ItemEngine.accuracy_multiplier(_mon({"item": "Wide Lens"})) - 1.1) > 0.0001:
		return false
	if absf(ItemEngine.accuracy_multiplier(_mon({})) - 1.0) > 0.0001:
		return false
	return true


func test_loaded_dice() -> bool:
	var move: Dictionary = {"name": "Bullet Seed", "multihit": [2, 5]}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var holder: Dictionary = _mon({"item": "Loaded Dice"})
	for i in range(40):
		var hits: int = MoveEffects.get_hit_count(move, rng, holder)
		if hits != 4 and hits != 5:
			return false
	# Without the dice the same move can roll 2 or 3.
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var saw_low: bool = false
	for i in range(40):
		var hits2: int = MoveEffects.get_hit_count(move, rng2, _mon({}))
		if hits2 < 4:
			saw_low = true
	return saw_low


func test_covert_cloak() -> bool:
	if not ItemEngine.blocks_secondary_effects(_mon({"item": "Covert Cloak"})):
		return false
	return not ItemEngine.blocks_secondary_effects(_mon({}))


# ------------------------------------------------------------------
# Stat-change, post-move and end-of-turn hooks
# ------------------------------------------------------------------

func test_clear_amulet() -> bool:
	var field: Dictionary = _field()
	# Through the MoveEffects choke point: a foe-caused drop
	# is blocked entirely.
	var logs1: Array = []
	var holder: Dictionary = _mon({"item": "Clear Amulet"})
	var foe: Dictionary = _mon({})
	MoveEffects._apply_boosts(holder, {"atk": -1}, logs1, false, foe, field, foe)
	if int(holder["stages"].get("atk", 0)) != 0:
		return false
	# A self-inflicted drop is NOT blocked.
	var logs2: Array = []
	var holder2: Dictionary = _mon({"item": "Clear Amulet"})
	MoveEffects._apply_boosts(holder2, {"atk": -1}, logs2, true, {}, field, foe)
	if int(holder2["stages"].get("atk", 0)) != -1:
		return false
	# Through Intimidate: no drop at all.
	var foe3: Dictionary = _mon({"item": "Clear Amulet"})
	AbilityEngine.on_switch_in(_mon({"ability": "Intimidate"}), foe3, _field())
	return int(foe3["stages"].get("atk", 0)) == 0


func test_eject_pack() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var holder: Dictionary = _mon({"item": "Eject Pack"})
	var foe: Dictionary = _mon({})
	MoveEffects._apply_boosts(holder, {"spe": -1}, logs1, false, foe, field, foe)
	if not bool(holder.get("eject_pack_pending", false)):
		return false
	if str(holder.get("item", "")) != "":
		return false
	# A foe-caused RISE does not trigger it.
	var logs2: Array = []
	var holder2: Dictionary = _mon({"item": "Eject Pack"})
	MoveEffects._apply_boosts(holder2, {"spe": 1}, logs2, false, foe, field, foe)
	if bool(holder2.get("eject_pack_pending", false)):
		return false
	# A self drop does not trigger it either.
	var logs3: Array = []
	var holder3: Dictionary = _mon({"item": "Eject Pack"})
	MoveEffects._apply_boosts(holder3, {"spe": -1}, logs3, true, {}, field, foe)
	return not bool(holder3.get("eject_pack_pending", false)) and str(holder3.get("item", "")) == "Eject Pack"


func test_mirror_herb() -> bool:
	var field: Dictionary = _field()
	# A mon raises its own Attack; the opposing herb holder
	# copies the rise and the herb is spent.
	var logs1: Array = []
	var booster: Dictionary = _mon({})
	var holder: Dictionary = _mon({"item": "Mirror Herb"})
	MoveEffects._apply_boosts(booster, {"atk": 2}, logs1, true, {}, field, holder)
	if int(holder["stages"].get("atk", 0)) != 2:
		return false
	if str(holder.get("item", "")) != "":
		return false
	# No herb: nothing copied.
	var logs2: Array = []
	var booster2: Dictionary = _mon({})
	var plain: Dictionary = _mon({})
	MoveEffects._apply_boosts(booster2, {"atk": 2}, logs2, true, {}, field, plain)
	return int(plain["stages"].get("atk", 0)) == 0


func test_adrenaline_orb() -> bool:
	# Intimidate drops the holder's Attack; the orb answers
	# with +1 Speed and is consumed.
	var foe: Dictionary = _mon({"item": "Adrenaline Orb"})
	AbilityEngine.on_switch_in(_mon({"ability": "Intimidate"}), foe, _field())
	if int(foe["stages"].get("atk", 0)) != -1:
		return false
	if int(foe["stages"].get("spe", 0)) != 1:
		return false
	if str(foe.get("item", "")) != "":
		return false
	# No Intimidate: the orb stays.
	var foe2: Dictionary = _mon({"item": "Adrenaline Orb"})
	AbilityEngine.on_switch_in(_mon({"ability": "Run Away"}), foe2, _field())
	return int(foe2["stages"].get("spe", 0)) == 0 and str(foe2.get("item", "")) == "Adrenaline Orb"


func test_throat_spray() -> bool:
	var sound: Dictionary = {"name": "Boomburst", "flags": {"sound": true}}
	var plain: Dictionary = {"name": "Tackle", "flags": {}}
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Throat Spray"})
	ItemEngine.on_after_move(mon, sound, logs1)
	if int(mon["stages"].get("spa", 0)) != 1 or str(mon.get("item", "")) != "":
		return false
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "Throat Spray"})
	ItemEngine.on_after_move(mon2, plain, logs2)
	return int(mon2["stages"].get("spa", 0)) == 0 and str(mon2.get("item", "")) == "Throat Spray"


func test_metronome_item() -> bool:
	var defender: Dictionary = _mon({"types": ["Normal"]})
	var move: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical"}
	# First use of a move: no boost.
	var mon: Dictionary = _mon({"item": "Metronome"})
	if ItemEngine.modify_attack_damage(mon, defender, move, 100) != 100:
		return false
	var logs: Array = []
	ItemEngine.on_after_move(mon, move, logs)
	# Second consecutive use: x1.2.
	if ItemEngine.modify_attack_damage(mon, defender, move, 100) != 120:
		return false
	ItemEngine.on_after_move(mon, move, logs)
	# Third: x1.4.
	if ItemEngine.modify_attack_damage(mon, defender, move, 100) != 140:
		return false
	# A different move resets the streak.
	var other_move: Dictionary = {"name": "Ember", "type": "Fire", "cat": "Special"}
	ItemEngine.on_after_move(mon, other_move, logs)
	return ItemEngine.modify_attack_damage(mon, defender, move, 100) == 100


func test_blunder_policy() -> bool:
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Blunder Policy"})
	ItemEngine.on_move_missed(mon, logs1)
	if int(mon["stages"].get("spe", 0)) != 2 or str(mon.get("item", "")) != "":
		return false
	var logs2: Array = []
	var mon2: Dictionary = _mon({})
	ItemEngine.on_move_missed(mon2, logs2)
	return int(mon2["stages"].get("spe", 0)) == 0


func test_quick_claw() -> bool:
	# Statistical: over many seeded rolls the claw must fire
	# sometimes and not others, and is never consumed.
	var move: Dictionary = {"name": "Tackle"}
	var fired: int = 0
	var quiet: int = 0
	for i in range(300):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5000 + i
		var mon: Dictionary = _mon({"item": "Quick Claw"})
		var fp: float = ItemEngine.frac_priority(mon, move, rng)
		if str(mon.get("item", "")) != "Quick Claw":
			return false
		if fp > 0.0:
			fired += 1
		else:
			quiet += 1
	return fired > 0 and quiet > 0


func test_custap_berry() -> bool:
	var move: Dictionary = {"name": "Tackle"}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	# At exactly 1/4 HP: fires, Berry eaten.
	var low: Dictionary = _mon({"item": "Custap Berry", "hp": 25})
	var fp: float = ItemEngine.frac_priority(low, move, rng)
	if fp != 0.1 or str(low.get("item", "")) != "" or str(low.get("item_consumed", "")) != "Custap Berry":
		return false
	# Above 1/4 HP: nothing.
	var high: Dictionary = _mon({"item": "Custap Berry", "hp": 26})
	var fp2: float = ItemEngine.frac_priority(high, move, rng)
	return fp2 == 0.0 and str(high.get("item", "")) == "Custap Berry"


func test_white_herb() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "White Herb", "stages": {"atk": -2, "def": 0, "spa": 1, "spd": 0, "spe": -1}})
	ItemEngine.update_item_checks(mon, field, logs1)
	if int(mon["stages"].get("atk", 0)) != 0 or int(mon["stages"].get("spe", 0)) != 0:
		return false
	if int(mon["stages"].get("spa", 0)) != 1:
		return false
	if str(mon.get("item", "")) != "":
		return false
	# No lowered stats: the herb stays.
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "White Herb"})
	ItemEngine.update_item_checks(mon2, field, logs2)
	return str(mon2.get("item", "")) == "White Herb"


func test_mental_herb() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Mental Herb", "volatiles": {"taunt": 2, "attract": 1}, "infatuated": true, "disabled_move": "Tackle", "heal_block_turns": 3})
	ItemEngine.update_item_checks(mon, field, logs1)
	var vols: Dictionary = mon.get("volatiles", {})
	if vols.has("taunt") or vols.has("attract"):
		return false
	if bool(mon.get("infatuated", false)):
		return false
	if str(mon.get("disabled_move", "")) != "":
		return false
	if int(mon.get("heal_block_turns", 0)) != 0:
		return false
	if str(mon.get("item", "")) != "":
		return false
	# Nothing to cure: the herb stays.
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "Mental Herb"})
	ItemEngine.update_item_checks(mon2, field, logs2)
	return str(mon2.get("item", "")) == "Mental Herb"


func test_black_sludge() -> bool:
	var field: Dictionary = _field()
	# Poison holder heals 1/16 (100 max -> 6, from 50 to 56).
	var logs1: Array = []
	var poison: Dictionary = _mon({"item": "Black Sludge", "types": ["Poison"], "hp": 50})
	ItemEngine.on_end_of_turn(poison, field, logs1)
	if int(poison.get("hp", 0)) != 56:
		return false
	# Non-Poison holder loses 1/8 (100 -> 12, from 50 to 38).
	var logs2: Array = []
	var other: Dictionary = _mon({"item": "Black Sludge", "types": ["Normal"], "hp": 50})
	ItemEngine.on_end_of_turn(other, field, logs2)
	return int(other.get("hp", 0)) == 38


func test_flame_orb() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Flame Orb", "types": ["Normal"]})
	ItemEngine.on_end_of_turn(mon, field, logs1)
	if str(mon.get("status", "")) != "BRN":
		return false
	# The orb is not consumed.
	if str(mon.get("item", "")) != "Flame Orb":
		return false
	# A Fire-type cannot be burned: no status.
	var logs2: Array = []
	var fire: Dictionary = _mon({"item": "Flame Orb", "types": ["Fire"]})
	ItemEngine.on_end_of_turn(fire, field, logs2)
	return str(fire.get("status", "")) == ""


func test_toxic_orb() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Toxic Orb", "types": ["Normal"]})
	ItemEngine.on_end_of_turn(mon, field, logs1)
	if str(mon.get("status", "")) != "TOX":
		return false
	if int(mon.get("toxic_counter", 0)) != 1:
		return false
	# A Poison-type is immune.
	var logs2: Array = []
	var poison: Dictionary = _mon({"item": "Toxic Orb", "types": ["Poison"]})
	ItemEngine.on_end_of_turn(poison, field, logs2)
	return str(poison.get("status", "")) == ""


func test_safety_goggles() -> bool:
	if not ItemEngine.blocks_weather_damage(_mon({"item": "Safety Goggles"})):
		return false
	if ItemEngine.blocks_weather_damage(_mon({})):
		return false
	# Powder gate.
	var spore: Dictionary = {"name": "Spore", "flags": {"powder": true}}
	var tackle: Dictionary = {"name": "Tackle", "flags": {}}
	if not ItemEngine.blocks_powder_move(_mon({"item": "Safety Goggles"}), spore):
		return false
	if ItemEngine.blocks_powder_move(_mon({"item": "Safety Goggles"}), tackle):
		return false
	# Sand damage through the field engine: a goggled
	# non-immune mon takes nothing; a plain one takes 1/16.
	var field: Dictionary = _field()
	field["weather"] = "sand"
	var goggled: Dictionary = _mon({"item": "Safety Goggles", "types": ["Normal"], "hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(goggled, field)
	if int(goggled.get("hp", 0)) != 100:
		return false
	var plain: Dictionary = _mon({"types": ["Normal"], "hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(plain, field)
	return int(plain.get("hp", 0)) == 94


func test_big_root() -> bool:
	if absf(ItemEngine.drain_multiplier(_mon({"item": "Big Root"})) - 1.3) > 0.0001:
		return false
	if absf(ItemEngine.drain_multiplier(_mon({})) - 1.0) > 0.0001:
		return false
	# Through a real drain: Giga Drain (1/2 of 40 = 20)
	# heals 26 with the root, 20 without.
	var field: Dictionary = _field()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var move: Dictionary = {"name": "Giga Drain", "type": "Grass", "cat": "Special", "drain": [1, 2]}
	var logs1: Array = []
	var rooted: Dictionary = _mon({"item": "Big Root", "hp": 10})
	var target1: Dictionary = _mon({"hp": 100})
	MoveEffects.apply_after_hit(rooted, target1, move, 40, field, rng, logs1)
	if int(rooted.get("hp", 0)) != 36:
		return false
	var logs2: Array = []
	var plain: Dictionary = _mon({"hp": 10})
	var target2: Dictionary = _mon({"hp": 100})
	MoveEffects.apply_after_hit(plain, target2, move, 40, field, rng, logs2)
	return int(plain.get("hp", 0)) == 30


func test_lansat_berry() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var low: Dictionary = _mon({"item": "Lansat Berry", "hp": 25})
	ItemEngine.update_item_checks(low, field, logs1)
	if int(low.get("crit_stage_bonus", 0)) != 2 or str(low.get("item", "")) != "":
		return false
	if ItemEngine.crit_stage(low) != 2:
		return false
	var logs2: Array = []
	var high: Dictionary = _mon({"item": "Lansat Berry", "hp": 26})
	ItemEngine.update_item_checks(high, field, logs2)
	return int(high.get("crit_stage_bonus", 0)) == 0 and str(high.get("item", "")) == "Lansat Berry"


func test_micle_berry() -> bool:
	var field: Dictionary = _field()
	var logs1: Array = []
	var low: Dictionary = _mon({"item": "Micle Berry", "hp": 20})
	ItemEngine.update_item_checks(low, field, logs1)
	if not bool(low.get("micle_accuracy", false)) or str(low.get("item", "")) != "":
		return false
	if absf(ItemEngine.accuracy_multiplier(low) - 1.2) > 0.0001:
		return false
	# The flag is spent after the holder's next move.
	var logs2: Array = []
	ItemEngine.on_after_move(low, {"name": "Tackle", "flags": {}}, logs2)
	if bool(low.get("micle_accuracy", false)):
		return false
	var logs3: Array = []
	var high: Dictionary = _mon({"item": "Micle Berry", "hp": 60})
	ItemEngine.update_item_checks(high, field, logs3)
	return not bool(high.get("micle_accuracy", false)) and str(high.get("item", "")) == "Micle Berry"


func test_miracle_berry() -> bool:
	# Immediate timing through the status choke point: the
	# status lands and the Berry cures it at once.
	var field: Dictionary = _field()
	var logs1: Array = []
	var mon: Dictionary = _mon({"item": "Miracle Berry", "types": ["Normal"]})
	if not AbilityEngine.try_set_status(mon, "PAR", _mon({}), field, logs1):
		return false
	if str(mon.get("status", "")) != "" or str(mon.get("item", "")) != "":
		return false
	# End-of-turn path cures a pre-existing status too.
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "Miracle Berry", "status": "BRN"})
	ItemEngine.update_item_checks(mon2, field, logs2)
	return str(mon2.get("status", "")) == "" and str(mon2.get("item", "")) == ""


func test_held_cure_berries() -> bool:
	# Each cure Berry answers its own status the moment the
	# status lands (through try_set_status), and only its own.
	var cases: Array = [
		["Cheri Berry", "PAR"], ["Pecha Berry", "PSN"], ["Pecha Berry", "TOX"],
		["Rawst Berry", "BRN"], ["Aspear Berry", "FRZ"], ["Chesto Berry", "SLP"],
	]
	for c in cases:
		var field: Dictionary = _field()
		var logs: Array = []
		var mon: Dictionary = _mon({"item": str(c[0]), "types": ["Normal"]})
		if not AbilityEngine.try_set_status(mon, str(c[1]), _mon({}), field, logs):
			return false
		if str(mon.get("status", "")) != "" or str(mon.get("item", "")) != "":
			return false
	# Wrong status: Cheri does not cure a burn.
	var field2: Dictionary = _field()
	var logs2: Array = []
	var mon2: Dictionary = _mon({"item": "Cheri Berry", "types": ["Normal"]})
	if not AbilityEngine.try_set_status(mon2, "BRN", _mon({}), field2, logs2):
		return false
	if str(mon2.get("status", "")) != "BRN" or str(mon2.get("item", "")) != "Cheri Berry":
		return false
	# Persim Berry answers confusion through the update check
	# (confusion has no single choke point in this engine).
	var logs3: Array = []
	var mon3: Dictionary = _mon({"item": "Persim Berry", "confused": true, "confusion_turns": 3})
	ItemEngine.update_item_checks(mon3, _field(), logs3)
	if bool(mon3.get("confused", false)) or str(mon3.get("item", "")) != "":
		return false
	# Persim does not cure a major status.
	var logs4: Array = []
	var mon4: Dictionary = _mon({"item": "Persim Berry", "status": "PAR"})
	ItemEngine.update_item_checks(mon4, _field(), logs4)
	return str(mon4.get("status", "")) == "PAR" and str(mon4.get("item", "")) == "Persim Berry"
