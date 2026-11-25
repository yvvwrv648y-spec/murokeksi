class_name PUWBattleTests
extends SceneTree
## Headless test runner for the Pokemon Ultimate World battle engine v3.
##
## Run it in Godot 4.7 (headless, no game window needed) with:
##   godot --headless --script res://battle/battle_tests.gd
## (from the project folder, with this file saved at res://battle/battle_tests.gd)
##
## It prints one PASS or FAIL line per test, then a summary line, then
## quits. Exit code 0 means every test passed, 1 means at least one failed.
##
## These tests were run for real in Godot 4.7.2 headless in the
## reference project: the 14 v2 tests passed 14/14, and the 13 v3
## tests passed 13/13. See TEST_REPORT.md for the exact run.
##
## What the tests need in the project to run:
## - All battle-engine-v3 scripts, plus the RC1 scripts they call:
##   MoveDatabase, BattleStageController, CompetitiveTrainerAI,
##   TurnResolver, DoublesTargeting, EXPSystem, StatusAndFieldEngine,
##   and PUWSmartAI (smart_ai.gd). Without any one of those the test
##   script will not even load, because BattleController names them all.
## - ability_engine.gd needs its four companion files
##   battle/abilities/ability_batch_1.gd to ability_batch_4.gd.
## - The data files at res://data/learnsets_compact.json,
##   res://data/shiny_sprites_index.json and res://data/exp_yield.json,
##   and the RC1 move list at res://battle/moves/move_database.json
##   (94 moves).
## - The tests only use moves that are in that RC1 move list
##   (Thunderbolt, Flamethrower, Surf, Earthquake, Shadow Ball,
##   Quick Attack, Psychic, Ice Beam, Close Combat, Energy Ball).
##   Tackle is NOT in that list, so no full-battle test uses it.
##   The damage test uses Tackle only as a plain move dict passed
##   straight to the damage maths, never through the move database.
## - The five v3 scenes at res://scenes/battle.tscn, bag.tscn,
##   mart.tscn, party.tscn and overworld.tscn, with their scripts.
##
var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW battle engine v3 tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://battle/battle_tests.gd")
		quit(1)
		return
	_run("test_type_chart_spot_checks", Callable(self, "test_type_chart_spot_checks"))
	_run("test_damage_sanity", Callable(self, "test_damage_sanity"))
	_run("test_turn_order", Callable(self, "test_turn_order"))
	_run("test_6v6_singles_simulation", Callable(self, "test_6v6_singles_simulation"))
	_run("test_wild_capture", Callable(self, "test_wild_capture"))
	_run("test_gym_style_battle", Callable(self, "test_gym_style_battle"))
	_run("test_item_effects", Callable(self, "test_item_effects"))
	_run("test_ability_effects", Callable(self, "test_ability_effects"))
	_run("test_hazards", Callable(self, "test_hazards"))
	_run("test_pivot_move", Callable(self, "test_pivot_move"))
	_run("test_gimmicks", Callable(self, "test_gimmicks"))
	_run("test_learnset_resolver", Callable(self, "test_learnset_resolver"))
	_run("test_shiny_resolver", Callable(self, "test_shiny_resolver"))
	_run("test_unknown_items_safe", Callable(self, "test_unknown_items_safe"))
	_run("test_exp_grant_and_level_up", Callable(self, "test_exp_grant_and_level_up"))
	_run("test_exp_curves", Callable(self, "test_exp_curves"))
	_run("test_doubles_turn", Callable(self, "test_doubles_turn"))
	_run("test_doubles_spread_damage", Callable(self, "test_doubles_spread_damage"))
	_run("test_flee_rules", Callable(self, "test_flee_rules"))
	_run("test_struggle_fallback", Callable(self, "test_struggle_fallback"))
	_run("test_dusk_ball", Callable(self, "test_dusk_ball"))
	_run("test_screens_reduce_damage", Callable(self, "test_screens_reduce_damage"))
	_run("test_multihit_distribution", Callable(self, "test_multihit_distribution"))
	_run("test_max_move_power", Callable(self, "test_max_move_power"))
	_run("test_rayquaza_dragon_ascent", Callable(self, "test_rayquaza_dragon_ascent"))
	_run("test_ability_counts", Callable(self, "test_ability_counts"))
	_run("test_scene_loading", Callable(self, "test_scene_loading"))
	_run("test_costar", Callable(self, "test_costar"))
	_run("test_curious_medicine", Callable(self, "test_curious_medicine"))
	_run("test_commander", Callable(self, "test_commander"))
	_run("test_dazzling_singles_and_doubles_partner", Callable(self, "test_dazzling_singles_and_doubles_partner"))
	_run("test_gravity_effects", Callable(self, "test_gravity_effects"))
	_run("test_safeguard_blocks_status", Callable(self, "test_safeguard_blocks_status"))
	_run("test_wonder_room_swaps_defenses", Callable(self, "test_wonder_room_swaps_defenses"))
	_run("test_magic_room_suppresses_items", Callable(self, "test_magic_room_suppresses_items"))
	_run("test_heal_block_blocks_healing", Callable(self, "test_heal_block_blocks_healing"))
	_run("test_fly_two_turn_airborne", Callable(self, "test_fly_two_turn_airborne"))
	_run("test_gravity_brings_down_fly", Callable(self, "test_gravity_brings_down_fly"))
	_run("test_sky_drop_and_gravity", Callable(self, "test_sky_drop_and_gravity"))
	_run("test_psychic_noise_heal_block", Callable(self, "test_psychic_noise_heal_block"))
	_run("test_leech_seed_drain_and_liquid_ooze", Callable(self, "test_leech_seed_drain_and_liquid_ooze"))
	_run("test_strength_sap_and_liquid_ooze", Callable(self, "test_strength_sap_and_liquid_ooze"))
	_run("test_commander_no_forced_switch", Callable(self, "test_commander_no_forced_switch"))
	_run("test_red_card_drags_out_attacker", Callable(self, "test_red_card_drags_out_attacker"))
	_run("test_evolution_on_level_up_hook", Callable(self, "test_evolution_on_level_up_hook"))
	_run("test_plus", Callable(self, "test_plus"))
	_run("test_symbiosis", Callable(self, "test_symbiosis"))
	_run("test_telepathy", Callable(self, "test_telepathy"))
	_run("test_dancer_singles", Callable(self, "test_dancer_singles"))
	_run("test_dancer_ignores_non_dance", Callable(self, "test_dancer_ignores_non_dance"))
	_run("test_dancer_doubles_no_chain", Callable(self, "test_dancer_doubles_no_chain"))
	_run("test_propeller_tail_mark", Callable(self, "test_propeller_tail_mark"))
	_run("test_move_forget_opens_screen", Callable(self, "test_move_forget_opens_screen"))
	_run("test_move_forget_resolve", Callable(self, "test_move_forget_resolve"))
	_run("test_quick_draw_frac_priority", Callable(self, "test_quick_draw_frac_priority"))
	_run("test_rock_head_no_recoil", Callable(self, "test_rock_head_no_recoil"))
	_run("test_leaf_guard_sun", Callable(self, "test_leaf_guard_sun"))
	_run("test_merciless_guaranteed_crit", Callable(self, "test_merciless_guaranteed_crit"))
	_run("test_magic_guard_no_indirect", Callable(self, "test_magic_guard_no_indirect"))
	_run("test_inner_focus_no_flinch", Callable(self, "test_inner_focus_no_flinch"))
	_run("test_liquid_ooze_drain_backfire", Callable(self, "test_liquid_ooze_drain_backfire"))
	_run("test_poison_puppeteer_confuses", Callable(self, "test_poison_puppeteer_confuses"))
	_run("test_synchronize_pass_back", Callable(self, "test_synchronize_pass_back"))
	_run("test_sticky_hold_knock_off", Callable(self, "test_sticky_hold_knock_off"))
	_run("test_suction_cups_blocks_roar", Callable(self, "test_suction_cups_blocks_roar"))
	_run("test_corrosion_poisons_steel", Callable(self, "test_corrosion_poisons_steel"))
	_run("test_persistent_tailwind_six", Callable(self, "test_persistent_tailwind_six"))
	_run("test_early_bird_wakes_fast", Callable(self, "test_early_bird_wakes_fast"))
	_run("test_mirror_armor_bounces", Callable(self, "test_mirror_armor_bounces"))
	_run("test_intimidate_routes_hooks", Callable(self, "test_intimidate_routes_hooks"))
	_run("test_try_set_status_choke_point", Callable(self, "test_try_set_status_choke_point"))
	_run("test_stench_flinch_chance", Callable(self, "test_stench_flinch_chance"))
	_run("test_priority_bonus", Callable(self, "test_priority_bonus"))
	_run("test_move_type_aerilate", Callable(self, "test_move_type_aerilate"))
	_run("test_crit_stage_super_luck", Callable(self, "test_crit_stage_super_luck"))
	_run("test_blocks_status", Callable(self, "test_blocks_status"))
	_run("test_blocks_stat_change", Callable(self, "test_blocks_stat_change"))
	_run("test_on_stat_boosted_contrary", Callable(self, "test_on_stat_boosted_contrary"))
	_run("test_on_stat_boosted_opportunist", Callable(self, "test_on_stat_boosted_opportunist"))
	_run("test_traps_foe_flee", Callable(self, "test_traps_foe_flee"))
	_run("test_traps_foe_switch", Callable(self, "test_traps_foe_switch"))
	_run("test_on_faint_moxie", Callable(self, "test_on_faint_moxie"))
	_run("test_terrain_surge", Callable(self, "test_terrain_surge"))
	_run("test_form_change_disguise", Callable(self, "test_form_change_disguise"))
	_run("test_ally_damage_mult", Callable(self, "test_ally_damage_mult"))
	_run("test_on_item_use_cheek_pouch", Callable(self, "test_on_item_use_cheek_pouch"))
	_run("test_speed_multiplier_unburden", Callable(self, "test_speed_multiplier_unburden"))
	_run("test_magic_bounce", Callable(self, "test_magic_bounce"))
	_run("test_skill_link_doubles", Callable(self, "test_skill_link_doubles"))
	_run("test_field_flags_sync", Callable(self, "test_field_flags_sync"))
	_run("test_rebound_switch_in_turn", Callable(self, "test_rebound_switch_in_turn"))
	_run("test_contrary_self_boost", Callable(self, "test_contrary_self_boost"))
	_run("test_simple_self_boost", Callable(self, "test_simple_self_boost"))
	_run("test_competitive_no_self_trigger", Callable(self, "test_competitive_no_self_trigger"))
	_run("test_overcoat_powder_block", Callable(self, "test_overcoat_powder_block"))
	_run("test_sandstorm_damage_immunity", Callable(self, "test_sandstorm_damage_immunity"))
	_run("test_sand_force_power", Callable(self, "test_sand_force_power"))
	_run("test_sand_rush_speed", Callable(self, "test_sand_rush_speed"))
	_run("test_sand_veil_accuracy", Callable(self, "test_sand_veil_accuracy"))
	_run("test_snow_cloak_accuracy", Callable(self, "test_snow_cloak_accuracy"))
	_run("test_poison_heal_skip_and_heal", Callable(self, "test_poison_heal_skip_and_heal"))
	_run("test_solar_power_damage_and_loss", Callable(self, "test_solar_power_damage_and_loss"))
	_run("test_water_bubble_damage", Callable(self, "test_water_bubble_damage"))
	_run("test_water_bubble_burn", Callable(self, "test_water_bubble_burn"))
	_run("test_weather_damage_helper", Callable(self, "test_weather_damage_helper"))
	_run("test_storm_drain_redirect_doubles", Callable(self, "test_storm_drain_redirect_doubles"))
	_run("test_lightning_rod_redirect_doubles", Callable(self, "test_lightning_rod_redirect_doubles"))
	_run("test_propeller_tail_ignores_redirect", Callable(self, "test_propeller_tail_ignores_redirect"))
	_run("test_stalwart_ignores_redirect", Callable(self, "test_stalwart_ignores_redirect"))
	_run("test_sweet_veil_ally_blocks_sleep_doubles", Callable(self, "test_sweet_veil_ally_blocks_sleep_doubles"))
	_run("test_sweet_veil_no_ally_sleep_singles", Callable(self, "test_sweet_veil_no_ally_sleep_singles"))
	_run("test_victory_star_ally_accuracy_doubles", Callable(self, "test_victory_star_ally_accuracy_doubles"))
	_run("test_redirect_skipped_by_mold_breaker", Callable(self, "test_redirect_skipped_by_mold_breaker"))
	_run("test_spread_move_not_redirected", Callable(self, "test_spread_move_not_redirected"))
	_run("test_redirected_thunder_wave_blocked", Callable(self, "test_redirected_thunder_wave_blocked"))
	_run("test_redirect_both_foes_draw_lower_slot_wins", Callable(self, "test_redirect_both_foes_draw_lower_slot_wins"))
	_run("test_redirect_skips_commanding_tatsugiri", Callable(self, "test_redirect_skips_commanding_tatsugiri"))
	_run("test_redirect_skipped_by_teravolt_turboblaze", Callable(self, "test_redirect_skipped_by_teravolt_turboblaze"))
	_run("test_lightning_rod_direct_hit_spa_boost", Callable(self, "test_lightning_rod_direct_hit_spa_boost"))
	_run("test_teravolt_levitate", Callable(self, "test_teravolt_levitate"))
	_run("test_turboblaze_levitate", Callable(self, "test_turboblaze_levitate"))
	_run("test_teravolt_ignores_filter_and_battle_armor", Callable(self, "test_teravolt_ignores_filter_and_battle_armor"))
	_run("test_unaware_attacker_ignores_def_stages", Callable(self, "test_unaware_attacker_ignores_def_stages"))
	_run("test_unaware_defender_ignores_atk_stages", Callable(self, "test_unaware_defender_ignores_atk_stages"))
	_run("test_shell_armor_never_crits", Callable(self, "test_shell_armor_never_crits"))
	_run("test_battle_armor_never_crits", Callable(self, "test_battle_armor_never_crits"))
	_run("test_stall_moves_last", Callable(self, "test_stall_moves_last"))
	_run("test_parental_bond_second_hit_quarter", Callable(self, "test_parental_bond_second_hit_quarter"))
	_run("test_parental_bond_doubles_second_hit_quarter", Callable(self, "test_parental_bond_doubles_second_hit_quarter"))
	_run("test_pressure_costs_2_pp", Callable(self, "test_pressure_costs_2_pp"))
	_run("test_stage_application", Callable(self, "test_stage_application"))
	_run("test_mold_breaker_still_works", Callable(self, "test_mold_breaker_still_works"))
	_run("test_teravolt_ignores_clear_body", Callable(self, "test_teravolt_ignores_clear_body"))
	_run("test_parental_bond_mark_reaches_doubles", Callable(self, "test_parental_bond_mark_reaches_doubles"))
	_run("test_neutralizing_gas_suppresses_and_restores", Callable(self, "test_neutralizing_gas_suppresses_and_restores"))
	_run("test_opportunist_copies_secondary_boost", Callable(self, "test_opportunist_copies_secondary_boost"))
	_run("test_stakeout_turn1_and_after", Callable(self, "test_stakeout_turn1_and_after"))
	_run("test_steadfast_flinch", Callable(self, "test_steadfast_flinch"))
	_run("test_supreme_overlord_power", Callable(self, "test_supreme_overlord_power"))
	_run("test_supreme_overlord_fallen_allies", Callable(self, "test_supreme_overlord_fallen_allies"))
	_run("test_tangled_feet_confused", Callable(self, "test_tangled_feet_confused"))
	_run("test_screen_cleaner_switch_in", Callable(self, "test_screen_cleaner_switch_in"))
	_run("test_unnerve_blocks_berry", Callable(self, "test_unnerve_blocks_berry"))
	_run("test_wimp_out_switches", Callable(self, "test_wimp_out_switches"))
	_run("test_emergency_exit_shared_path", Callable(self, "test_emergency_exit_shared_path"))
	_run("test_toxic_debris_layers", Callable(self, "test_toxic_debris_layers"))
	_run("test_rebound_singles_switch_in_turn", Callable(self, "test_rebound_singles_switch_in_turn"))
	_run("test_rebound_doubles_bounce", Callable(self, "test_rebound_doubles_bounce"))
	_run("test_as_one_variants_and_move_ko_gate", Callable(self, "test_as_one_variants_and_move_ko_gate"))
	_run("test_intimidate_blocked_oblivious_owntempo_scrappy", Callable(self, "test_intimidate_blocked_oblivious_owntempo_scrappy"))
	_run("test_white_smoke_blocks_foe_not_self", Callable(self, "test_white_smoke_blocks_foe_not_self"))
	_run("test_ripen_sitrus_double", Callable(self, "test_ripen_sitrus_double"))
	_run("test_ripen_pinch_and_stat_berry", Callable(self, "test_ripen_pinch_and_stat_berry"))
	_run("test_ripen_leppa_and_enigma", Callable(self, "test_ripen_leppa_and_enigma"))
	_run("test_ripen_weaken_berry_quarters", Callable(self, "test_ripen_weaken_berry_quarters"))
	_run("test_supersweet_syrup_accuracy", Callable(self, "test_supersweet_syrup_accuracy"))
	_run("test_stench_flinch_rolls", Callable(self, "test_stench_flinch_rolls"))
	_run("test_ripen_oran_juice_starf", Callable(self, "test_ripen_oran_juice_starf"))
	_run("test_steelworker_power_mult", Callable(self, "test_steelworker_power_mult"))
	_run("test_swarm_power_mult", Callable(self, "test_swarm_power_mult"))
	_run("test_thick_fat_power_mult", Callable(self, "test_thick_fat_power_mult"))
	_run("test_torrent_power_mult", Callable(self, "test_torrent_power_mult"))
	_run("test_tough_claws_power_mult", Callable(self, "test_tough_claws_power_mult"))
	_run("test_toxic_boost_power_mult", Callable(self, "test_toxic_boost_power_mult"))
	_run("test_transistor_power_mult", Callable(self, "test_transistor_power_mult"))
	_run("test_teraform_zero_ends_weather_terrain_on_tera", Callable(self, "test_teraform_zero_ends_weather_terrain_on_tera"))
	_run("test_teraform_zero_once_per_battle", Callable(self, "test_teraform_zero_once_per_battle"))
	_run("test_teraform_zero_not_on_next_move", Callable(self, "test_teraform_zero_not_on_next_move"))
	_run("test_wind_power_charge_on_tailwind_start", Callable(self, "test_wind_power_charge_on_tailwind_start"))
	_run("test_wind_rider_attack_on_tailwind_start", Callable(self, "test_wind_rider_attack_on_tailwind_start"))
	_run("test_wind_rider_attack_switch_in_under_tailwind", Callable(self, "test_wind_rider_attack_switch_in_under_tailwind"))
	_run("test_wind_power_no_charge_switch_in_under_tailwind", Callable(self, "test_wind_power_no_charge_switch_in_under_tailwind"))
	_run("test_tailwind_refresh_gives_no_second_boost", Callable(self, "test_tailwind_refresh_gives_no_second_boost"))
	_run("test_tailwind_start_doubles_both_allies", Callable(self, "test_tailwind_start_doubles_both_allies"))
	_run("test_protect_blocks_damaging_move", Callable(self, "test_protect_blocks_damaging_move"))
	_run("test_protect_blocks_status_move", Callable(self, "test_protect_blocks_status_move"))
	_run("test_protect_does_not_block_ally_move_doubles", Callable(self, "test_protect_does_not_block_ally_move_doubles"))
	_run("test_protect_flag_clears_after_turn", Callable(self, "test_protect_flag_clears_after_turn"))
	_run("test_piercing_drill_contact_hits_through_protect", Callable(self, "test_piercing_drill_contact_hits_through_protect"))
	_run("test_piercing_drill_non_contact_still_blocked", Callable(self, "test_piercing_drill_non_contact_still_blocked"))
	_run("test_unseen_fist_contact_hits_through_protect", Callable(self, "test_unseen_fist_contact_hits_through_protect"))
	_run("test_unseen_fist_non_contact_still_blocked", Callable(self, "test_unseen_fist_non_contact_still_blocked"))
	_run("test_ignores_protect_flag_path_doubles", Callable(self, "test_ignores_protect_flag_path_doubles"))
	_run("test_protect_does_not_block_own_self_move", Callable(self, "test_protect_does_not_block_own_self_move"))
	_run("test_sword_of_ruin_end_of_turn_faint", Callable(self, "test_sword_of_ruin_end_of_turn_faint"))
	_run("test_tablets_of_ruin_end_of_turn_faint", Callable(self, "test_tablets_of_ruin_end_of_turn_faint"))
	_run("test_vessel_of_ruin_end_of_turn_faint", Callable(self, "test_vessel_of_ruin_end_of_turn_faint"))
	_run("test_moxie_no_boost_on_end_of_turn_ko", Callable(self, "test_moxie_no_boost_on_end_of_turn_ko"))
	_run("test_end_of_turn_faint_grants_exp", Callable(self, "test_end_of_turn_faint_grants_exp"))
	_run("test_both_mons_faint_to_end_of_turn_damage", Callable(self, "test_both_mons_faint_to_end_of_turn_damage"))
	_run("test_end_of_turn_faint_no_double_exp", Callable(self, "test_end_of_turn_faint_no_double_exp"))
	_run("test_end_of_turn_faint_doubles", Callable(self, "test_end_of_turn_faint_doubles"))
	_run("test_dry_skin_single_fire", Callable(self, "test_dry_skin_single_fire"))
	_run("test_overcoat_blocks_effect_spore", Callable(self, "test_overcoat_blocks_effect_spore"))
	_run("test_confusion_from_move", Callable(self, "test_confusion_from_move"))
	_run("test_toxic_spikes_switch_in", Callable(self, "test_toxic_spikes_switch_in"))
	_run("test_cantsuppress_list", Callable(self, "test_cantsuppress_list"))
	_run("test_gimmick_budget_categories_independent", Callable(self, "test_gimmick_budget_categories_independent"))
	_run("test_gimmick_budget_one_mega_per_side", Callable(self, "test_gimmick_budget_one_mega_per_side"))
	_run("test_gimmick_budget_one_category_per_mon", Callable(self, "test_gimmick_budget_one_category_per_mon"))
	_run("test_gimmick_budget_per_side", Callable(self, "test_gimmick_budget_per_side"))
	_run("test_inverse_battle_type_chart", Callable(self, "test_inverse_battle_type_chart"))
	_run("test_inverse_battle_format_flag", Callable(self, "test_inverse_battle_format_flag"))
	_run("test_sky_battle_eligibility", Callable(self, "test_sky_battle_eligibility"))
	_run("test_vgc_select_team", Callable(self, "test_vgc_select_team"))
	print("PUW battle engine v3 tests — done: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		var failed_text: String = ""
		for failed_name in _failed_names:
			if not failed_text.is_empty():
				failed_text += ", "
			failed_text += str(failed_name)
		print("Failed tests: " + failed_text)
		quit(1)
		return
	quit(0)


func _run(test_name: String, test: Callable) -> void:
	var ok: bool = bool(test.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


## ------------------------------------------------------------------
## Helpers
## ------------------------------------------------------------------

## One test Pokemon, as a plain dict. Stats are plain top-level keys
## (atk, def, spa, spd, spe) because that is what the damage maths
## and the turn-order code read. "extra" overrides any of the defaults.
func _mon(mon_name: String, types: Array, moves: Array, extra: Dictionary = {}) -> Dictionary:
	var mon: Dictionary = {
		"name": mon_name, "species": mon_name,
		"level": 50, "hp": 100, "max_hp": 100,
		"atk": 100, "def": 50, "spa": 200, "spd": 50, "spe": 100,
		"types": types, "ability": "", "item": "", "status": "",
		"moves": moves,
		"stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for key in extra.keys():
		mon[key] = extra[key]
	return mon


## A BattleController that is in the tree, so its _ready() has run
## and its MoveDatabase is loaded. Freeing is not needed: quit()
## ends the run right after the tests.
func _new_controller() -> BattleController:
	var controller := BattleController.new()
	root.add_child(controller)
	return controller


## First party slot after slot 0 that is still standing, or -1.
func _next_living(party: Array) -> int:
	for i in range(1, party.size()):
		if int(party[i].get("hp", 0)) > 0:
			return i
	return -1


func _count_fainted(party: Array) -> int:
	var n: int = 0
	for mon in party:
		if int(mon.get("hp", 0)) <= 0:
			n += 1
	return n


## Play a trainer battle to the end. The player always uses the
## active Pokemon's first move, and switches to the next living
## Pokemon when the controller asks for one. Returns
## {"status": ..., "turns": ...}.
## Note: when a player's Pokemon faints, run_turn still returns
## "ongoing" — the switch is asked for through the controller's
## battle_state flag "player_must_switch", not through the status.
## That flag is what this loop reads.
func _run_battle(controller: BattleController, player_party: Array, enemy_party: Array, already_started: bool = false) -> Dictionary:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	if not already_started:
		var start: Dictionary = controller.start_battle(player_party, enemy_party, "singles", true)
		if str(start.get("status", "")) != "started":
			return {"status": "not_started", "turns": 0}
	var status: String = "ongoing"
	var turns: int = 0
	var need_switch: bool = false
	while turns < 200:
		turns += 1
		var action: Dictionary = {}
		if need_switch:
			var idx: int = _next_living(controller.player_party)
			if idx < 0:
				break
			action = {"type": "switch", "target_idx": idx}
		else:
			var active: Dictionary = controller.player_party[0]
			var moves: Array = active.get("moves", [])
			if moves.is_empty():
				break
			action = {"type": "move", "move_name": str(moves[0])}
		var result: Dictionary = controller.run_turn(action, field)
		status = str(result.get("status", "ongoing"))
		need_switch = bool(controller.battle_state.get("player_must_switch", false))
		if status in ["player_won", "enemy_won", "fled", "caught", "no_battle"]:
			break
	return {"status": status, "turns": turns}


## True when any Pokemon in either party has had PP taken off a move.
## The move database is the source of the full PP for each move.
func _any_pp_deducted(parties: Array) -> bool:
	var db := MoveDatabase.new()
	db.load_database()
	for party in parties:
		for mon in party:
			var pp: Dictionary = mon.get("pp", {})
			for move_name in pp.keys():
				var md: Dictionary = db.get_move(str(move_name))
				var full: int = int(md.get("pp_max", md.get("pp", 15)))
				if int(pp.get(move_name, full)) < full:
					return true
	return false


## ------------------------------------------------------------------
## Tests — each returns true when it passes, false when it fails.
## ------------------------------------------------------------------

## 10 type matchups, straight from the type chart in damage_calculator.gd.
func test_type_chart_spot_checks() -> bool:
	var checks: Array = [
		["Electric", "Ground", 0.0],
		["Fire", "Grass", 2.0],
		["Ghost", "Normal", 0.0],
		["Dragon", "Fairy", 0.0],
		["Fighting", "Ghost", 0.0],
		["Steel", "Fairy", 2.0],
		["Ground", "Electric", 2.0],
		["Water", "Fire", 2.0],
		["Ice", "Dragon", 2.0],
		["Bug", "Psychic", 2.0],
	]
	for check in checks:
		var got: float = PUWBattleEngine.type_multiplier(str(check[0]), PackedStringArray([str(check[1])]))
		if got != float(check[2]):
			print("  type check failed: %s vs %s gave %s, wanted %s." % [check[0], check[1], str(got), str(check[2])])
			return false
	return true


## Damage maths, called directly (no move database involved):
## Thunderbolt on a Water type hurts and is 2x; Tackle on a Ghost
## type does 0 damage (Normal cannot hit Ghost).
func test_damage_sanity() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var attacker: Dictionary = {"level": 50, "atk": 100, "def": 100, "spa": 100, "spd": 100, "types": ["Electric"]}
	var defender: Dictionary = {"types": ["Water"], "def": 80, "spd": 80, "hp": 100, "max_hp": 100}
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "power": 90}
	var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, bolt, rng)
	if int(res.get("damage", 0)) <= 0:
		print("  Thunderbolt did no damage to a Water type.")
		return false
	if float(res.get("effectiveness", 0.0)) != 2.0:
		print("  Thunderbolt effectiveness was %s, wanted 2.0." % str(res.get("effectiveness", 0.0)))
		return false
	var normal_attacker: Dictionary = {"level": 50, "atk": 100, "def": 100, "spa": 100, "spd": 100, "types": ["Normal"]}
	var ghost: Dictionary = {"types": ["Ghost"], "def": 80, "spd": 80, "hp": 100, "max_hp": 100}
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	var res2: Dictionary = PUWBattleEngine.calculate_damage(normal_attacker, ghost, tackle, rng)
	if int(res2.get("damage", -1)) != 0:
		print("  Tackle did %s damage to a Ghost type, wanted 0." % str(res2.get("damage", -1)))
		return false
	if float(res2.get("effectiveness", 1.0)) != 0.0:
		print("  Tackle effectiveness was %s, wanted 0.0." % str(res2.get("effectiveness", 1.0)))
		return false
	return true


## Turn order: priority beats speed, speed beats slowness, and
## Trick Room turns it around so the slower Pokemon goes first.
func test_turn_order() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var fast: Dictionary = {"spe": 100}
	var slow: Dictionary = {"spe": 50}
	var normal_move: Dictionary = {"priority": 0}
	var order: Array = TurnResolver.resolve_order(fast, normal_move, slow, normal_move, field)
	if str(order[0]) != "player":
		print("  fast Pokemon did not go first.")
		return false
	var quick_move: Dictionary = {"priority": 1}
	var very_fast_foe: Dictionary = {"spe": 200}
	order = TurnResolver.resolve_order(slow, quick_move, very_fast_foe, normal_move, field)
	if str(order[0]) != "player":
		print("  priority move did not go first.")
		return false
	var trick_field: Dictionary = StatusAndFieldEngine.create_field_state()
	trick_field["trick_room"] = 5
	order = TurnResolver.resolve_order(fast, normal_move, slow, normal_move, trick_field)
	if str(order[0]) != "enemy":
		print("  Trick Room did not put the slower Pokemon first.")
		return false
	return true


## A full 6-on-6 singles battle, played through the real
## BattleController until one side wins (or 200 turns pass).
## Attack and Special Attack are high on purpose so the battle
## ends fast; every move used is in the RC1 move list.
func test_6v6_singles_simulation() -> bool:
	var controller: BattleController = _new_controller()
	var player_party: Array = [
		_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"], {"spe": 120}),
		_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"], {"spe": 110}),
		_mon("Blastoise", ["Water"], ["Surf", "Quick Attack"], {"spe": 80}),
		_mon("Venusaur", ["Grass", "Poison"], ["Energy Ball", "Quick Attack"], {"spe": 90}),
		_mon("Gengar", ["Ghost", "Poison"], ["Shadow Ball", "Quick Attack"], {"spe": 115}),
		_mon("Dragonite", ["Dragon", "Flying"], ["Earthquake", "Quick Attack"], {"spe": 95}),
	]
	var enemy_party: Array = [
		_mon("Gyarados", ["Water", "Flying"], ["Surf", "Earthquake"], {"spe": 85}),
		_mon("Alakazam", ["Psychic"], ["Psychic", "Shadow Ball"], {"spe": 125}),
		_mon("Machamp", ["Fighting"], ["Close Combat", "Earthquake"], {"spe": 60}),
		_mon("Jolteon", ["Electric"], ["Thunderbolt", "Quick Attack"], {"spe": 130}),
		_mon("Snorlax", ["Normal"], ["Earthquake", "Shadow Ball"], {"spe": 40}),
		_mon("Lapras", ["Water", "Ice"], ["Surf", "Ice Beam"], {"spe": 70}),
	]
	var result: Dictionary = _run_battle(controller, player_party, enemy_party)
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  6v6 battle did not end: status %s after %s turns." % [status, str(result.get("turns", 0))])
		return false
	if _count_fainted(player_party) + _count_fainted(enemy_party) <= 0:
		print("  6v6 battle ended with no faint.")
		return false
	if not _any_pp_deducted([player_party, enemy_party]):
		print("  6v6 battle ended but no PP was taken off any move.")
		return false
	return true


## Catching: a Poke Ball at low HP has a better chance than at full
## HP, and a Master Ball always catches. The chance numbers are
## compared, not the random catch itself.
func test_wild_capture() -> bool:
	var controller: BattleController = _new_controller()
	controller.set_wild_battle(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	# catch_rate 100 here is only a test number, not any real
	# species' catch rate.
	var low_hp: Dictionary = {"name": "Pidgey", "species": "Pidgey", "types": ["Normal", "Flying"], "hp": 10, "max_hp": 100, "catch_rate": 100, "status": ""}
	var full_hp: Dictionary = {"name": "Pidgey", "species": "Pidgey", "types": ["Normal", "Flying"], "hp": 100, "max_hp": 100, "catch_rate": 100, "status": ""}
	var low: Dictionary = controller.attempt_capture("Poke Ball", low_hp, rng)
	var full: Dictionary = controller.attempt_capture("Poke Ball", full_hp, rng)
	if float(low.get("chance", 0.0)) <= float(full.get("chance", 0.0)):
		print("  low HP catch chance (%s) was not higher than full HP (%s)." % [str(low.get("chance", 0.0)), str(full.get("chance", 0.0))])
		return false
	var master: Dictionary = controller.attempt_capture("Master Ball", full_hp, rng)
	if float(master.get("chance", 0.0)) != 1.0:
		print("  Master Ball chance was %s, wanted 1.0." % str(master.get("chance", 0.0)))
		return false
	if not bool(master.get("caught", false)):
		print("  Master Ball did not catch.")
		return false
	return true


## A 3-on-3 gym-style battle. The leader's first Pokemon holds
## Leftovers and has Intimidate, so the test also checks that
## Intimidate lowered the player's first Pokemon's Attack at the
## start of the battle.
func test_gym_style_battle() -> bool:
	var controller: BattleController = _new_controller()
	var player_party: Array = [
		_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"], {"spe": 120}),
		_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"], {"spe": 110}),
		_mon("Blastoise", ["Water"], ["Surf", "Quick Attack"], {"spe": 80}),
	]
	var leader_party: Array = [
		_mon("Gyarados", ["Water", "Flying"], ["Surf", "Earthquake"], {"spe": 85, "ability": "Intimidate", "item": "Leftovers"}),
		_mon("Alakazam", ["Psychic"], ["Psychic", "Shadow Ball"], {"spe": 125}),
		_mon("Machamp", ["Fighting"], ["Close Combat", "Earthquake"], {"spe": 60}),
	]
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var start: Dictionary = controller.start_battle(player_party, leader_party, "singles", true)
	if str(start.get("status", "")) != "started":
		print("  gym battle did not start.")
		return false
	var player_stages: Dictionary = player_party[0].get("stages", {})
	if int(player_stages.get("atk", 0)) != -1:
		print("  leader Intimidate did not lower the player's Attack to -1 (got %s)." % str(player_stages.get("atk", 0)))
		return false
	# The battle is already started above, so _run_battle is told
	# not to start it a second time (a second start would apply
	# Intimidate again and drop Attack to -2).
	var result: Dictionary = _run_battle(controller, player_party, leader_party, true)
	var status: String = str(result.get("status", ""))
	if status != "player_won" and status != "enemy_won":
		print("  gym battle did not end: status %s after %s turns." % [status, str(result.get("turns", 0))])
		return false
	return true


## Held items, called directly on ItemEngine (all static):
## Life Orb recoil, Leftovers heal, Choice Band boost, Focus Sash.
func test_item_effects() -> bool:
	var logs: Array = []
	var orb_holder: Dictionary = {"name": "Attacker", "item": "Life Orb", "hp": 100, "max_hp": 100}
	ItemEngine.apply_recoil_after_attack(orb_holder, 50, logs)
	if int(orb_holder.get("hp", 0)) != 90:
		print("  Life Orb recoil left %s HP, wanted 90." % str(orb_holder.get("hp", 0)))
		return false
	var leftovers_holder: Dictionary = {"name": "Holder", "item": "Leftovers", "hp": 50, "max_hp": 100}
	ItemEngine.on_end_of_turn(leftovers_holder, {}, logs)
	if int(leftovers_holder.get("hp", 0)) != 56:
		print("  Leftovers healed to %s HP, wanted 56." % str(leftovers_holder.get("hp", 0)))
		return false
	var band_holder: Dictionary = {"item": "Choice Band"}
	var physical: Dictionary = {"cat": "Physical"}
	var boosted: int = ItemEngine.modify_attack_damage(band_holder, {}, physical, 100)
	if boosted != 150:
		print("  Choice Band damage was %s, wanted 150." % str(boosted))
		return false
	var bare_holder: Dictionary = {"item": ""}
	var plain: int = ItemEngine.modify_attack_damage(bare_holder, {}, physical, 100)
	if plain != 100:
		print("  no-item damage was %s, wanted 100." % str(plain))
		return false
	var sash_holder: Dictionary = {"name": "Holder", "item": "Focus Sash", "hp": 100, "max_hp": 100}
	var adjusted: int = ItemEngine.check_focus_sash(sash_holder, 999)
	if adjusted != 99:
		print("  Focus Sash adjusted damage was %s, wanted 99." % str(adjusted))
		return false
	if str(sash_holder.get("item", "Focus Sash")) != "":
		print("  Focus Sash was not used up.")
		return false
	if int(sash_holder.get("hp", 0)) - adjusted != 1:
		print("  Focus Sash did not leave the holder at 1 HP.")
		return false
	return true


## Abilities, called directly on AbilityEngine (all static):
## Intimidate, Levitate, Sturdy, Technician.
func test_ability_effects() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var intimidator: Dictionary = {"name": "Gyarados", "ability": "Intimidate"}
	var foe: Dictionary = {"name": "Foe", "stages": {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}}
	AbilityEngine.on_switch_in(intimidator, foe, field)
	var foe_stages: Dictionary = foe.get("stages", {})
	if int(foe_stages.get("atk", 0)) != -1:
		print("  Intimidate did not lower foe Attack to -1 (got %s)." % str(foe_stages.get("atk", 0)))
		return false
	if not AbilityEngine.is_immune_by_ability({"ability": "Levitate"}, "Ground"):
		print("  Levitate did not block a Ground move.")
		return false
	if AbilityEngine.is_immune_by_ability({"ability": ""}, "Ground"):
		print("  a Pokemon with no ability blocked a Ground move.")
		return false
	var sturdy_defender: Dictionary = {"ability": "Sturdy", "hp": 100, "max_hp": 100}
	var sturdy_result: int = AbilityEngine.modify_damage({}, sturdy_defender, {"power": 100, "cat": "Physical"}, 999, false)
	if sturdy_result != 99:
		print("  Sturdy left %s damage, wanted 99." % str(sturdy_result))
		return false
	var technician_attacker: Dictionary = {"ability": "Technician"}
	var plain_defender: Dictionary = {"ability": "", "hp": 100, "max_hp": 100}
	var tech_result: int = AbilityEngine.modify_damage(technician_attacker, plain_defender, {"power": 60, "cat": "Physical"}, 100, false)
	if tech_result != 150:
		print("  Technician damage was %s, wanted 150." % str(tech_result))
		return false
	return true


## Entry hazards, called directly on MoveEffects and
## StatusAndFieldEngine (all static): Stealth Rock hurts a
## switch-in, Rapid Spin clears only its own side, Spikes caps at 3.
func test_hazards() -> bool:
	var logs: Array = []
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var foe_hazards: Dictionary = field["enemy_hazards"]
	MoveEffects.apply_hazard_move("Stealth Rock", foe_hazards, field, logs)
	if not bool(foe_hazards.get("stealth_rock", false)):
		print("  Stealth Rock was not set.")
		return false
	var switch_in: Dictionary = {"name": "Charizard", "hp": 100, "max_hp": 100, "types": ["Fire", "Flying"], "ability": ""}
	StatusAndFieldEngine.apply_entry_hazards(switch_in, foe_hazards)
	if int(switch_in.get("hp", 0)) != 88:
		print("  Stealth Rock left the switch-in at %s HP, wanted 88." % str(switch_in.get("hp", 0)))
		return false
	var own_hazards: Dictionary = {"stealth_rock": true, "spikes": 2, "toxic_spikes": 0, "sticky_web": false}
	var other_hazards: Dictionary = {"stealth_rock": true, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	MoveEffects.apply_hazard_clear("Rapid Spin", own_hazards, other_hazards, field, logs)
	if bool(own_hazards.get("stealth_rock", true)) or int(own_hazards.get("spikes", 1)) != 0:
		print("  Rapid Spin did not clear its own side.")
		return false
	if not bool(other_hazards.get("stealth_rock", false)):
		print("  Rapid Spin cleared the foe's side too, but it should only clear its own.")
		return false
	var spike_hazards: Dictionary = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	for i in range(4):
		MoveEffects.apply_hazard_move("Spikes", spike_hazards, field, logs)
	if int(spike_hazards.get("spikes", 0)) != 3:
		print("  Spikes reached %s layers, wanted 3." % str(spike_hazards.get("spikes", 0)))
		return false
	return true


## Pivot moves, called directly on MoveEffects (all static).
## apply_after_hit is called BEFORE the HP is taken off, because
## it works out fainting from the HP before the hit. Do NOT call
## roll_secondary separately: apply_after_hit already rolls
## secondaries itself.
func test_pivot_move() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var logs: Array = []
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	if not MoveEffects.is_pivot({"selfSwitch": true}):
		print("  U-turn (selfSwitch) was not seen as a pivot move.")
		return false
	if not MoveEffects.is_pivot({"pivot": true}):
		print("  a pivot-flagged move was not seen as a pivot move.")
		return false
	var attacker: Dictionary = {"name": "Attacker", "hp": 100, "max_hp": 100}
	var defender: Dictionary = {"name": "Defender", "hp": 100, "max_hp": 100, "status": ""}
	var uturn: Dictionary = {"name": "U-turn", "selfSwitch": true, "type": "Bug", "cat": "Physical", "power": 70}
	var after: Dictionary = MoveEffects.apply_after_hit(attacker, defender, uturn, 40, field, rng, logs)
	if not bool(after.get("switch_requested", false)):
		print("  U-turn did not ask for a switch.")
		return false
	if bool(after.get("fainted", false)):
		print("  U-turn wrongly said the defender fainted on 40 damage to 100 HP.")
		return false
	if int(defender.get("hp", 0)) != 100:
		print("  apply_after_hit changed HP itself; the caller is the one that takes HP off.")
		return false
	var lethal: Dictionary = MoveEffects.apply_after_hit(attacker, defender, uturn, 100, field, rng, logs)
	if not bool(lethal.get("fainted", false)):
		print("  a 100-damage hit on 100 HP was not called a faint.")
		return false
	return true


## Gimmicks, called directly on PUWGimmicks (all static):
## Mega Evolution, Terastal, Dynamax.
func test_gimmicks() -> bool:
	var logs: Array = []
	var charizard: Dictionary = {"name": "Charizard", "species": "Charizard", "item": "Charizardite X", "types": ["Fire", "Flying"], "ability": "Blaze", "moves": ["Flamethrower"]}
	PUWGimmicks.mega_evolve(charizard, logs, {}, null)
	if str(charizard.get("forme", "")) != "Charizard-Mega-X":
		print("  Mega Charizard forme was '%s', wanted 'Charizard-Mega-X'." % str(charizard.get("forme", "")))
		return false
	var mega_types: Array = charizard.get("types", [])
	if not ("Dragon" in mega_types):
		print("  Mega Charizard X did not gain the Dragon type.")
		return false
	var tera_mon: Dictionary = {"name": "Pikachu", "species": "Pikachu", "types": ["Electric"], "moves": ["Thunderbolt"]}
	PUWGimmicks.terastallize(tera_mon, "Fire", logs, {}, null)
	var tera_types: Array = tera_mon.get("types", [])
	if tera_types != ["Fire"]:
		print("  Terastal did not change the type to Fire.")
		return false
	if str(tera_mon.get("tera_type", "")) != "Fire":
		print("  Terastal did not record the Tera type.")
		return false
	var dyna_mon: Dictionary = {"name": "Snorlax", "species": "Snorlax", "hp": 100, "max_hp": 100, "moves": ["Earthquake"]}
	PUWGimmicks.dynamax(dyna_mon, logs, {}, null)
	if int(dyna_mon.get("max_hp", 0)) != 200:
		print("  Dynamax max HP was %s, wanted 200." % str(dyna_mon.get("max_hp", 0)))
		return false
	if int(dyna_mon.get("hp", 0)) != 200:
		print("  Dynamax HP was %s, wanted 200." % str(dyna_mon.get("hp", 0)))
		return false
	if not bool(dyna_mon.get("dynamax_active", false)):
		print("  Dynamax did not set dynamax_active.")
		return false
	return true


## Learnsets. Needs res://data/learnsets_compact.json in the
## project; the resolver loads it by itself when it is made.
## Bulbasaur can learn Tackle, learns moves by level 16, and an
## unknown species returns empty instead of crashing.
func test_learnset_resolver() -> bool:
	var resolver := LearnsetResolver.new()
	if not resolver.is_loaded():
		print("  learnsets file not loaded. Copy learnsets_compact.json to res://data/ and run again.")
		return false
	if resolver.species_count() <= 0:
		print("  learnsets file loaded but has no species.")
		return false
	if not resolver.can_learn("Bulbasaur", "Tackle"):
		print("  Bulbasaur could not learn Tackle.")
		return false
	var by_16: Array = resolver.moves_learned_by_level("Bulbasaur", 16)
	if by_16.is_empty():
		print("  Bulbasaur learned no move by level 16.")
		return false
	var gained: Array = resolver.get_level_up_moves("Bulbasaur", 1, 16)
	if gained.is_empty():
		print("  Bulbasaur gained no level-up move between level 1 and 16.")
		return false
	if not resolver.get_learnset("Fake Species XYZ").is_empty():
		print("  an unknown species returned a learnset instead of empty.")
		return false
	if resolver.can_learn("Fake Species XYZ", "Tackle"):
		print("  an unknown species could supposedly learn Tackle.")
		return false
	return true


## Shiny sprites. Needs res://data/shiny_sprites_index.json in
## the project; the resolver loads it by itself when it is made.
## Pikachu has a shiny animated sprite. Iron Boulder has no live
## shiny animated sprite (all four of its Showdown shiny pictures
## are checked dead in the index), so get_sprite_url must fall
## back to a still picture instead of returning "". An unknown
## species returns "" and does not crash.
func test_shiny_resolver() -> bool:
	var sprites := ShinySpriteResolver.new()
	if not sprites.is_loaded():
		print("  sprite index not loaded. Copy shiny_sprites_index.json to res://data/ and run again.")
		return false
	if sprites.row_count() <= 0:
		print("  sprite index loaded but has no rows.")
		return false
	if str(sprites.get_shiny_sprite_url("Pikachu")).is_empty():
		print("  Pikachu had no shiny sprite address.")
		return false
	if not sprites.has_shiny_sprite("Pikachu"):
		print("  Pikachu was not flagged as having a shiny sprite.")
		return false
	# Binding build 3 (stage 9) bound Iron Boulder's local EBDX
	# animated strips, so it now HAS a shiny animated sprite —
	# served from the local strip, never from its checked-dead
	# Showdown ani-shiny link (verified_http_200 false above).
	if not sprites.has_shiny_sprite("Iron Boulder"):
		print("  Iron Boulder was not flagged as having a shiny animated sprite, but binding build 3 bound its local EBDX strip.")
		return false
	var iron_boulder_url: String = str(sprites.get_shiny_sprite_url("Iron Boulder"))
	if not iron_boulder_url.begins_with("res://"):
		print("  Iron Boulder shiny resolved to a remote link instead of the bound local strip.")
		return false
	if str(sprites.get_sprite_url("Iron Boulder", true)).is_empty():
		print("  Iron Boulder shiny request returned nothing.")
		return false
	if str(sprites.get_sprite_url("Fake Species XYZ", true)) != "":
		print("  an unknown species returned a sprite address instead of empty.")
		return false
	if str(sprites.get_shiny_sprite_url("Fake Species XYZ")) != "":
		print("  an unknown species returned a shiny sprite address instead of empty.")
		return false
	return true


## A nonsense held item must never crash anything: not the item
## code itself, and not a full turn fought while holding it.
func test_unknown_items_safe() -> bool:
	var logs: Array = []
	var holder: Dictionary = {"name": "Holder", "item": "Fake Item 123", "hp": 80, "max_hp": 100, "status": ""}
	if ItemEngine.modify_attack_damage(holder, {}, {"cat": "Physical"}, 100) != 100:
		print("  a fake item changed damage.")
		return false
	ItemEngine.on_end_of_turn(holder, {}, logs)
	if int(holder.get("hp", 0)) != 80:
		print("  a fake item changed HP at end of turn.")
		return false
	if ItemEngine.use_battle_item("Fake Item 123", holder, logs):
		print("  a fake item was somehow usable.")
		return false
	if typeof(ItemEngine.get_item_effect_text("Fake Item 123")) != TYPE_STRING:
		print("  a fake item did not return text (even empty text) for its effect.")
		return false
	var controller: BattleController = _new_controller()
	var player_party: Array = [
		_mon("Pikachu", ["Electric"], ["Thunderbolt", "Quick Attack"], {"spe": 120, "item": "Fake Item 123"}),
		_mon("Charizard", ["Fire", "Flying"], ["Flamethrower", "Quick Attack"], {"spe": 110}),
	]
	var enemy_party: Array = [
		_mon("Gyarados", ["Water", "Flying"], ["Surf", "Earthquake"], {"spe": 85}),
		_mon("Alakazam", ["Psychic"], ["Psychic", "Shadow Ball"], {"spe": 125}),
	]
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	controller.start_battle(player_party, enemy_party, "singles", true)
	var result: Dictionary = controller.run_turn({"type": "move", "move_name": "Thunderbolt"}, field)
	var status: String = str(result.get("status", ""))
	if status != "ongoing" and status != "player_won" and status != "enemy_won":
		print("  a turn fought holding a fake item ended with status '%s'." % status)
		return false
	return true

## ------------------------------------------------------------------
## v3 tests — EXP, doubles, leftovers, ability counts, scene loading.
## Each test here was run for real in Godot 4.7.2 headless in the
## reference project (see TEST_REPORT.md) and passed.
## ------------------------------------------------------------------

## EXP hand check from the spec: a level 5 Bulbasaur (base EXP 64,
## medium-slow curve) with 150 total EXP faints a level 5 Bulbasaur
## alone. It gains 64 * 5 / 7 = 45 EXP. New total 195 = level 6
## (179 needed, 236 for level 7), so exp_next is 41 (236 - 195).
func test_exp_grant_and_level_up() -> bool:
	var c: BattleController = _new_controller()
	var winner: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle"], {"level": 5, "exp": 150, "exp_is_total": true, "participated": true})
	var fainted: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle"], {"level": 5})
	var logs: Array = []
	c.grant_exp([winner], fainted, logs)
	return int(winner.get("exp", -1)) == 195 and int(winner.get("level", -1)) == 6 and int(winner.get("exp_next", -1)) == 41


## Growth curves and EXP gain from EXPSystem, straight from the data.
func test_exp_curves() -> bool:
	if EXPSystem.exp_for_level("medium-fast", 5) != 125:
		return false
	if EXPSystem.exp_for_level("medium-slow", 6) != 179:
		return false
	if EXPSystem.level_for_exp("medium-slow", 195) != 6:
		return false
	if EXPSystem.exp_gain(64, 5, 1, false) != 45:
		return false
	# The yield table itself is proven by test_exp_grant_and_level_up,
	# which reads Bulbasaur's base EXP 64 from res://data/exp_yield.json.
	return true


## A real doubles turn: both player slots act, both enemy slots act,
## and the turn ends "ongoing" with damage done.
func test_doubles_turn() -> bool:
	var c: BattleController = _new_controller()
	var p1: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"spe": 100})
	var p2: Dictionary = _mon("Blastoise", ["water"], ["Ice Beam"], {"spe": 90})
	var e1: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Energy Ball"], {"spe": 80})
	var e2: Dictionary = _mon("Pikachu", ["electric"], ["Electro Drift"], {"spe": 120})
	c.start_battle([p1, p2], [e1, e2], "doubles")
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var res: Dictionary = c.run_turn_doubles([{"type": "move", "move_name": "Flamethrower"}, {"type": "move", "move_name": "Ice Beam"}], field)
	if str(res.get("status", "")) != "ongoing":
		return false
	return int(e1.get("hp", 100)) < 100 or int(e2.get("hp", 100)) < 100


## Spread moves in doubles hit both foes at 0.75x damage per target,
## and a single living foe takes full damage (no cut).
func test_doubles_spread_damage() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Golem", ["rock", "ground"], ["Earthquake"], {"atk": 200, "spe": 100})
	var f1: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"hp": 2000, "max_hp": 2000})
	var f2: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Energy Ball"], {"hp": 2000, "max_hp": 2000})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [f1, f2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var spread_move: Dictionary = {"name": "Rock Slide", "power": 75, "type": "Rock", "cat": "Physical", "acc": 100, "target": "allAdjacentFoes"}
	var targets: Array = DoublesTargeting.resolve_targets(spread_move, 0, "player", view)
	if targets.size() != 2:
		return false
	if not DoublesTargeting.is_spread(spread_move):
		return false
	if not is_equal_approx(DoublesTargeting.spread_mult(2), 0.75):
		return false
	if not is_equal_approx(DoublesTargeting.spread_mult(1), 1.0):
		return false
	var override: Dictionary = {"target": "allAdjacentFoes", "power": 75, "type": "Rock", "cat": "Physical", "acc": 100}
	# Raw damage per target from the same rng sequence the move will
	# consume (one damage roll per target, in target order).
	var expect_rng := RandomNumberGenerator.new()
	expect_rng.seed = 4242
	var raw1: int = int(PUWBattleEngine.calculate_damage(attacker, f1, spread_move, expect_rng).get("damage", -1))
	var raw2: int = int(PUWBattleEngine.calculate_damage(attacker, f2, spread_move, expect_rng).get("damage", -1))
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Earthquake", true, 0, logs, override)
	var dmg2_f1: int = 2000 - int(f1.get("hp", 2000))
	var dmg2_f2: int = 2000 - int(f2.get("hp", 2000))
	if dmg2_f1 != int(float(raw1) * 0.75):
		return false
	if dmg2_f2 != int(float(raw2) * 0.75):
		return false
	if not str(logs).contains("0.75x"):
		return false
	# One living foe: no cut.
	f1["hp"] = 2000
	f2["hp"] = 0
	var view1: Dictionary = c._doubles_field_view()
	var targets1: Array = DoublesTargeting.resolve_targets(spread_move, 0, "player", view1)
	if targets1.size() != 1:
		return false
	c.rng.seed = 4242
	var logs1: Array = []
	c._execute_move_doubles(attacker, targets1, "Earthquake", true, 0, logs1, override)
	var dmg1: int = 2000 - int(f1.get("hp", 2000))
	return dmg1 == raw1


## Wild flee rules: a much faster Pokemon always escapes; Shadow Tag
## and Arena Trap block escape; Run Away always escapes.
func test_flee_rules() -> bool:
	var c: BattleController = _new_controller()
	var logs: Array = []
	var fast: Dictionary = _mon("Jolteon", ["electric"], ["Tackle"], {"spe": 130})
	var slow: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spe": 30})
	if not c._try_flee(fast, slow, logs):
		return false
	var tagged: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {"ability": "Shadow Tag", "spe": 30})
	if c._try_flee(fast, tagged, logs):
		return false
	var runner: Dictionary = _mon("Jolteon", ["electric"], ["Tackle"], {"ability": "Run Away", "spe": 30})
	if not c._try_flee(runner, slow, logs):
		return false
	var trapped: Dictionary = _mon("Dugtrio", ["ground"], ["Tackle"], {"ability": "Arena Trap", "spe": 30})
	var grounded: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spe": 130})
	if c._try_flee(grounded, trapped, logs):
		return false
	return true


## A Pokemon with no PP left on any move uses Struggle, which deals
## damage and costs a quarter of that damage in recoil.
func test_struggle_fallback() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunder Shock"], {"pp": {"Thunder Shock": 0}, "hp": 100, "max_hp": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.field_state = StatusAndFieldEngine.create_field_state()
	var res: Dictionary = c._execute_move(attacker, defender, "Thunder Shock", true, logs)
	var dealt: int = int(res.get("damage", 0))
	var recoil_taken: int = 100 - int(attacker.get("hp", 100))
	return dealt > 0 and recoil_taken == maxi(1, dealt / 4) and str(logs).contains("used Struggle!")


## Dusk Ball: 3.0x at night or in a cave, 1.0x otherwise.
func test_dusk_ball() -> bool:
	var night: float = ItemEngine.get_ball_bonus("Dusk Ball", [], 1, false, false, true)
	var day: float = ItemEngine.get_ball_bonus("Dusk Ball", [], 1, false, false, false)
	return is_equal_approx(night, 3.0) and is_equal_approx(day, 1.0)


## Reflect halves physical damage. Same seed, same rolls: the
## screened hit must be exactly half the plain hit.
func test_screens_reduce_damage() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"], {"atk": 200, "spa": 50})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"def": 100, "spd": 100, "hp": 500, "max_hp": 500})
	var move: Dictionary = {"name": "Close Combat", "power": 120, "type": "Fighting", "cat": "Physical", "acc": 100}
	var plain: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, move, rng)
	var screened_def: Dictionary = defender.duplicate(true)
	screened_def["screens"] = {"reflect": 5, "light_screen": 0, "aurora_veil": 0}
	rng.seed = 777
	var screened: Dictionary = PUWBattleEngine.calculate_damage(attacker, screened_def, move, rng)
	if not is_equal_approx(float(plain.get("screen_mult", -1)), 1.0):
		return false
	if not is_equal_approx(float(screened.get("screen_mult", -1)), 0.5):
		return false
	return int(screened.get("damage", -1)) == int(float(int(plain.get("damage", 0))) * 0.5)


## Multi-hit spread from the real games: 2 hits 35%, 3 hits 35%,
## 4 hits 15%, 5 hits 15%. Skill Link always gives 5 hits.
func test_multihit_distribution() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var move: Dictionary = {"multihit": [2, 5]}
	var counts: Dictionary = {2: 0, 3: 0, 4: 0, 5: 0}
	for i in range(2000):
		var n: int = MoveEffects.get_hit_count(move, rng, {})
		counts[n] = int(counts.get(n, 0)) + 1
	if absf(float(counts[2]) / 2000.0 - 0.35) > 0.04:
		return false
	if absf(float(counts[3]) / 2000.0 - 0.35) > 0.04:
		return false
	if absf(float(counts[4]) / 2000.0 - 0.15) > 0.03:
		return false
	if absf(float(counts[5]) / 2000.0 - 0.15) > 0.03:
		return false
	var linker: Dictionary = {"ability": "Skill Link"}
	for i in range(20):
		if MoveEffects.get_hit_count(move, rng, linker) != 5:
			return false
	return true


## Max Move power from the real tables: Pound 40 -> 90, Earthquake
## 100 -> 130, Close Combat 120 -> 95, Hyper Beam 150 -> 150,
## Pin Missile 25 -> 130. Status moves have no Max Move power.
func test_max_move_power() -> bool:
	if PUWGimmicks.max_power_for_move("Pound", 40, "Normal", "Physical") != 90:
		return false
	if PUWGimmicks.max_power_for_move("Earthquake", 100, "Ground", "Physical") != 130:
		return false
	if PUWGimmicks.max_power_for_move("Close Combat", 120, "Fighting", "Physical") != 95:
		return false
	if PUWGimmicks.max_power_for_move("Hyper Beam", 150, "Normal", "Special") != 150:
		return false
	if PUWGimmicks.max_power_for_move("Swords Dance", 0, "Normal", "Status") != 0:
		return false
	if PUWGimmicks.max_power_for_move("Pin Missile", 25, "Bug", "Physical") != 130:
		return false
	return true


## Rayquaza can Mega Evolve only when it knows Dragon Ascent.
func test_rayquaza_dragon_ascent() -> bool:
	var with_ascent: Dictionary = {"species": "Rayquaza", "moves": ["Dragon Ascent", "Outrage"], "item": ""}
	var without: Dictionary = {"species": "Rayquaza", "moves": ["Outrage"], "item": ""}
	if not PUWGimmicks.can_mega_evolve(with_ascent):
		return false
	if PUWGimmicks.can_mega_evolve(without):
		return false
	return true


## The ability engine covers all 322 abilities. The counts are the
## contract: they must add up to 322, and no ability may be missing.
func test_ability_counts() -> bool:
	var info: Dictionary = AbilityEngine.ABILITY_INFO
	var counts: Dictionary = {"implemented": 0, "partial": 0, "blocked": 0, "no_effect": 0, "turnresolver": 0}
	for key in info.keys():
		var entry: Dictionary = info[key]
		var hook: String = str(entry.get("hook", "?"))
		if not counts.has(hook):
			return false
		counts[hook] = int(counts[hook]) + 1
	return info.size() == 322


## All five v3 scenes load (all script references resolve) and their
## root nodes run the right scene script class. Instantiating without
## adding to the tree does not run _ready, so this is a pure load check.
func test_scene_loading() -> bool:
	var scenes: Dictionary = {
		"res://scenes/battle.tscn": "BattleScene",
		"res://scenes/bag.tscn": "BagScene",
		"res://scenes/mart.tscn": "MartScene",
		"res://scenes/party.tscn": "PartyScene",
		"res://scenes/overworld.tscn": "OverworldScene",
	}
	for path in scenes.keys():
		var packed: PackedScene = load(path)
		if packed == null:
			return false
		var inst: Node = packed.instantiate()
		if inst == null:
			return false
		var script: Script = inst.get_script()
		if script == null:
			inst.free()
			return false
		var cls: String = str(script.get_global_name())
		inst.free()
		if cls != str(scenes[path]):
			return false
	return true

## ------------------------------------------------------------------
## v3 unblock tests — the 8 doubles-ally abilities from the
## unblock spec (Costar, Curious Medicine, Commander, Plus,
## Symbiosis, Telepathy, Dancer, Propeller Tail), plus the
## self-boost fix the Dancer test needs (RC1 "self_boost" shape).
## ------------------------------------------------------------------

## Costar copies the ally's stat stages on switch-in.
func test_costar() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Flamigo", ["fighting", "flying"], ["Brave Bird"], {"ability": "Costar"})
	var ally: Dictionary = _mon("Staraptor", ["normal", "flying"], ["Brave Bird"], {"stages": {"atk": 2, "def": -1, "spa": 1, "spd": 0, "spe": 3}})
	c.start_battle([holder, ally], [_mon("Snorlax", ["normal"], ["Tackle"]), _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	var stages: Dictionary = holder.get("stages", {})
	return int(stages.get("atk", -9)) == 2 and int(stages.get("def", -9)) == -1 and int(stages.get("spa", -9)) == 1 and int(stages.get("spd", -9)) == 0 and int(stages.get("spe", -9)) == 3


## Curious Medicine resets the ally's stat stages to 0 on switch-in.
func test_curious_medicine() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Slowking", ["water", "psychic"], ["Scald"], {"ability": "Curious Medicine"})
	var ally: Dictionary = _mon("Staraptor", ["normal", "flying"], ["Brave Bird"], {"stages": {"atk": 2, "def": -1, "spa": 1, "spd": 0, "spe": 3}})
	c.start_battle([holder, ally], [_mon("Snorlax", ["normal"], ["Tackle"]), _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	var stages: Dictionary = ally.get("stages", {})
	for key in ["atk", "def", "spa", "spd", "spe"]:
		if int(stages.get(key, -9)) != 0:
			return false
	return true


## Commander: Tatsugiri + Dondozo. Tatsugiri cannot act or be hit,
## Dondozo gains +2 to all five stats, and when Dondozo faints
## Tatsugiri comes out of the mouth.
func test_commander() -> bool:
	var c: BattleController = _new_controller()
	var tatsugiri: Dictionary = _mon("Tatsugiri", ["dragon", "water"], ["Dragon Pulse"], {"species": "Tatsugiri", "ability": "Commander"})
	var dondozo: Dictionary = _mon("Dondozo", ["water"], ["Waterfall"], {"species": "Dondozo"})
	c.start_battle([tatsugiri, dondozo], [_mon("Snorlax", ["normal"], ["Tackle"]), _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	if not bool(tatsugiri.get("commanding", false)):
		return false
	if not bool(dondozo.get("commanded", false)):
		return false
	var stages: Dictionary = dondozo.get("stages", {})
	for key in ["atk", "def", "spa", "spd", "spe"]:
		if int(stages.get(key, -9)) != 2:
			return false
	# Tatsugiri cannot act. (Check the log lines one by one:
	# str(logs) escapes apostrophes, so it cannot match "can't".)
	var logs: Array = []
	var out: Dictionary = c._perform_action_doubles({"type": "move", "move_name": "Dragon Pulse"}, true, 0, logs)
	var found_block: bool = false
	for line in logs:
		if str(line).contains("can't move while commanding"):
			found_block = true
	if not found_block:
		return false
	# Tatsugiri cannot be hit: it is dropped from the targets.
	var kept: Array = c._drop_commanding_targets([{"side": "player", "slot": 0}, {"side": "player", "slot": 1}], logs)
	if kept.size() != 1 or int(kept[0].get("slot", -1)) != 1:
		return false
	# Dondozo faints: Tatsugiri comes out.
	dondozo["hp"] = 0
	var logs2: Array = []
	c._handle_faint_slot(true, 1, logs2)
	if bool(tatsugiri.get("commanding", true)):
		return false
	var found_out: bool = false
	for line in logs2:
		if str(line).contains("came out of Dondozo's mouth!"):
			found_out = true
	return found_out


## Plus: special damage 1.5x when the ally has Plus or Minus.
func test_plus() -> bool:
	var attacker: Dictionary = _mon("Plusle", ["electric"], ["Thunderbolt"], {"ability": "Plus", "ally_ability": "Minus"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var move: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "power": 90}
	var with_ally: int = AbilityEngine.modify_damage(attacker, defender, move, 100, false, false, 1.0)
	attacker["ally_ability"] = ""
	var without_ally: int = AbilityEngine.modify_damage(attacker, defender, move, 100, false, false, 1.0)
	if with_ally != 150:
		print("  Plus with ally = ", with_ally)
		return false
	if without_ally != 100:
		print("  Plus without ally = ", without_ally)
		return false
	# Physical moves get no Plus boost.
	var phys: Dictionary = {"name": "Quick Attack", "type": "Normal", "cat": "Physical", "power": 40}
	attacker["ally_ability"] = "Minus"
	if AbilityEngine.modify_damage(attacker, defender, phys, 100, false, false, 1.0) != 100:
		return false
	return true


## Symbiosis: when the ally eats its Sitrus Berry at end of turn,
## the holder hands its own item to the ally at once.
func test_symbiosis() -> bool:
	var c: BattleController = _new_controller()
	var eater: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 40, "max_hp": 100, "item": "Sitrus Berry"})
	var holder: Dictionary = _mon("Oranguru", ["normal", "psychic"], ["Psychic"], {"ability": "Symbiosis", "item": "Leftovers"})
	c.start_battle([eater, holder], [_mon("Pidgey", ["normal", "flying"], ["Tackle"]), _mon("Rattata", ["normal"], ["Tackle"])], "doubles")
	var logs: Array = []
	ItemEngine.on_end_of_turn(eater, c.field_state, logs)
	if str(eater.get("item", "?")) != "Leftovers":
		print("  eater item = ", str(eater.get("item", "?")))
		return false
	if str(holder.get("item", "?")) != "":
		return false
	return str(logs).contains("Symbiosis")


## Telepathy: no damage from an ally's attack in doubles, but a
## foe's attack still hits.
func test_telepathy() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var ally: Dictionary = _mon("Oricorio", ["normal"], ["Revelation Dance"], {"ability": "Telepathy"})
	var foe: Dictionary = _mon("Raichu", ["electric"], ["Thunderbolt"])
	c.start_battle([attacker, ally], [foe, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	var logs: Array = []
	c._execute_move_doubles(attacker, [{"side": "player", "slot": 1}], "Thunderbolt", true, 0, logs)
	if int(ally.get("hp", 0)) != 100:
		print("  ally hp after ally attack = ", int(ally.get("hp", 0)))
		return false
	if not str(logs).contains("Telepathy blocked"):
		return false
	var logs2: Array = []
	c._execute_move_doubles(foe, [{"side": "player", "slot": 1}], "Thunderbolt", false, 0, logs2)
	return int(ally.get("hp", 0)) < 100


## Dancer in singles: the foe's Oricorio copies Swords Dance once
## (its Attack rises +2, same as the user's own use), and a
## non-dance move is not copied.
func test_dancer_singles() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Scizor", ["bug", "steel"], ["Swords Dance"], {"spe": 100})
	var dancer: Dictionary = _mon("Oricorio", ["fire", "flying"], ["Quick Attack"], {"ability": "Dancer", "spe": 50})
	c.start_battle([user], [dancer], "singles")
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Swords Dance"}, field)
	var logs: Array = res.get("logs", [])
	if not str(logs).contains("Dancer copied Swords Dance!"):
		print("  no Dancer copy in logs")
		return false
	var user_stages: Dictionary = user.get("stages", {})
	var dancer_stages: Dictionary = dancer.get("stages", {})
	if int(user_stages.get("atk", -9)) != 2:
		print("  user atk stages = ", int(user_stages.get("atk", -9)))
		return false
	return int(dancer_stages.get("atk", -9)) == 2


## Dancer does not copy a non-dance move.
func test_dancer_ignores_non_dance() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spe": 100})
	var dancer: Dictionary = _mon("Oricorio", ["fire", "flying"], ["Quick Attack"], {"ability": "Dancer", "spe": 50})
	c.start_battle([user], [dancer], "singles")
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Thunderbolt"}, field)
	var logs: Array = res.get("logs", [])
	if str(logs).contains("Dancer copied"):
		return false
	var dancer_stages: Dictionary = dancer.get("stages", {})
	return int(dancer_stages.get("atk", -9)) == 0


## Dancer in doubles: both Dancers copy the user's Swords Dance
## exactly once each (no chains: +2, not +4).
func test_dancer_doubles_no_chain() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Scizor", ["bug", "steel"], ["Swords Dance"], {"spe": 100})
	var ally_dancer: Dictionary = _mon("Oricorio", ["fire", "flying"], ["Quick Attack"], {"ability": "Dancer", "spe": 50})
	var foe_dancer: Dictionary = _mon("Oricorio", ["electric", "flying"], ["Quick Attack"], {"ability": "Dancer", "spe": 60})
	c.start_battle([user, ally_dancer], [foe_dancer, _mon("Pidgey", ["normal", "flying"], ["Quick Attack"])], "doubles")
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var res: Dictionary = c.run_turn_doubles([{"type": "move", "move_name": "Swords Dance"}, {"type": "move", "move_name": "Quick Attack"}], field)
	var logs: Array = res.get("logs", [])
	var copies: int = 0
	for line in logs:
		if str(line).contains("Dancer copied Swords Dance!"):
			copies += 1
	if copies != 2:
		print("  dancer copies = ", copies)
		return false
	var a_stages: Dictionary = ally_dancer.get("stages", {})
	var f_stages: Dictionary = foe_dancer.get("stages", {})
	if int(a_stages.get("atk", -9)) != 2:
		print("  ally dancer atk = ", int(a_stages.get("atk", -9)))
		return false
	return int(f_stages.get("atk", -9)) == 2


## Propeller Tail (and Stalwart) mark the move so it cannot be
## redirected; a plain mon does not set the mark.
func test_propeller_tail_mark() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	var move1: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	var attacker1: Dictionary = _mon("Bombirdier", ["flying", "dark"], ["Tackle"], {"ability": "Propeller Tail"})
	AbilityEngine.on_before_move(attacker1, defender, move1, field, logs)
	if not bool(move1.get("ignores_redirection", false)):
		return false
	var move2: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	var attacker2: Dictionary = _mon("Duraludon", ["steel", "dragon"], ["Tackle"], {"ability": "Stalwart"})
	AbilityEngine.on_before_move(attacker2, defender, move2, field, logs)
	if not bool(move2.get("ignores_redirection", false)):
		return false
	var move3: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	var attacker3: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": ""})
	AbilityEngine.on_before_move(attacker3, defender, move3, field, logs)
	return not bool(move3.get("ignores_redirection", false))


## A Pokemon with 4 moves that levels up into a new move gets a
## pending learn AND the Move-Forget screen really opens.
func test_move_forget_opens_screen() -> bool:
	var c: BattleController = _new_controller()
	var mon: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle", "Growl", "Vine Whip", "Leech Seed"], {"level": 5})
	var logs: Array = []
	c._check_move_learning(mon, 5, 6, logs)
	if str(mon.get("pending_learn", "")) != "Growth":
		return false
	if c.move_forget_screen == null:
		return false
	if str(c.move_forget_screen.get("new_move")) != "Growth":
		return false
	var shown: Array = c.move_forget_screen.get("current_moves")
	if shown.size() != 4:
		return false
	return str(logs).contains("wants to learn Growth")

## Settling a pending learn: forget a slot and learn the new move,
## or keep the old moves with choice -1.
func test_move_forget_resolve() -> bool:
	var c: BattleController = _new_controller()
	var mon: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Tackle", "Growl", "Vine Whip", "Leech Seed"], {"level": 5})
	var logs: Array = []
	c._check_move_learning(mon, 5, 6, logs)
	var logs2: Array = []
	if not c.resolve_pending_learn(mon, 1, logs2):
		return false
	var moves: Array = mon.get("moves", [])
	if moves.size() != 4 or str(moves[1]) != "Growth" or str(moves[0]) != "Tackle":
		return false
	if mon.has("pending_learn"):
		return false
	if not str(logs2).contains("forgot Growl and learned Growth!"):
		return false
	mon["pending_learn"] = "Razor Leaf"
	var logs3: Array = []
	if not c.resolve_pending_learn(mon, -1, logs3):
		return false
	var moves2: Array = mon.get("moves", [])
	if moves2.size() != 4 or "Razor Leaf" in moves2:
		return false
	return str(logs3).contains("did not learn Razor Leaf")

## Quick Draw: +0.1 priority on a 30% roll, attacking moves only.
## The roll is random, so the test rolls 200 times and checks the
## only two values ever seen are 0.0 and 0.1, with both appearing,
## and that a status move never gets the bonus. The turn-order part
## sets frac_priority directly, so it is exact: a slower mon with
## +0.1 goes before a faster mon in the same bracket.
func test_quick_draw_frac_priority() -> bool:
	var attacker: Dictionary = _mon("Galarian Slowpoke", ["psychic"], ["Tackle"], {"ability": "Quick Draw"})
	var atk_move: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	var status_move: Dictionary = {"name": "Swords Dance", "type": "Normal", "cat": "Status", "power": 0}
	var saw_bonus: bool = false
	var saw_plain: bool = false
	for i in range(200):
		var bonus: float = AbilityEngine.frac_priority(attacker, atk_move)
		if bonus == 0.1:
			saw_bonus = true
		elif bonus == 0.0:
			saw_plain = true
		else:
			print("  Quick Draw returned ", bonus)
			return false
	if not saw_bonus or not saw_plain:
		print("  Quick Draw never rolled one side in 200 tries.")
		return false
	for i in range(20):
		if AbilityEngine.frac_priority(attacker, status_move) != 0.0:
			print("  Quick Draw gave a bonus to a status move.")
			return false
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var slow: Dictionary = {"spe": 50}
	var fast: Dictionary = {"spe": 100}
	var with_frac: Dictionary = {"priority": 0, "frac_priority": 0.1}
	var plain: Dictionary = {"priority": 0}
	var order: Array = TurnResolver.resolve_order(slow, with_frac, fast, plain, field)
	return str(order[0]) == "player"


## Rock Head: Brave Bird costs no HP; without it the attacker
## loses damage * 0.33 (the RC1 scalar recoil form).
func test_rock_head_no_recoil() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var move: Dictionary = {"name": "Brave Bird", "type": "Flying", "cat": "Physical", "power": 120, "recoil": 0.33}
	var rocky: Dictionary = _mon("Staraptor", ["normal", "flying"], ["Brave Bird"], {"ability": "Rock Head", "hp": 100, "max_hp": 100})
	var logs: Array = []
	MoveEffects.apply_after_hit(rocky, _mon("Snorlax", ["normal"], ["Tackle"]), move, 60, field, rng, logs)
	if int(rocky.get("hp", 0)) != 100:
		print("  Rock Head mon lost HP to recoil: ", int(rocky.get("hp", 0)))
		return false
	if not str(logs).contains("took no recoil damage with Rock Head!"):
		return false
	var plain: Dictionary = _mon("Staraptor", ["normal", "flying"], ["Brave Bird"], {"hp": 100, "max_hp": 100})
	var logs2: Array = []
	MoveEffects.apply_after_hit(plain, _mon("Snorlax", ["normal"], ["Tackle"]), move, 60, field, rng, logs2)
	if int(plain.get("hp", 0)) != 81:
		print("  plain Brave Bird HP = ", int(plain.get("hp", 0)), ", wanted 81 (60 * 0.33 = 19).")
		return false
	return str(logs2).contains("was hurt by recoil")


## Leaf Guard: no status in Sun, normal status when the weather
## is clear.
func test_leaf_guard_sun() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sun"
	var source: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Sludge Bomb"])
	var target: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	var logs: Array = []
	if AbilityEngine.try_set_status(target, "PSN", source, field, logs):
		print("  Leaf Guard mon was poisoned in Sun.")
		return false
	if str(target.get("status", "?")) != "":
		return false
	var field2: Dictionary = StatusAndFieldEngine.create_field_state()
	var target2: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	var logs2: Array = []
	if not AbilityEngine.try_set_status(target2, "PSN", source, field2, logs2):
		print("  Leaf Guard mon was not poisoned in clear weather.")
		return false
	return str(target2.get("status", "")) == "PSN"


## Merciless: crit stage 5 against a poisoned target (clamped to
## 4 in the damage maths, which is a guaranteed crit), 0 against
## a healthy target.
func test_merciless_guaranteed_crit() -> bool:
	var attacker: Dictionary = _mon("Toxapex", ["poison", "water"], ["Cross Poison"], {"ability": "Merciless", "atk": 100})
	var move: Dictionary = {"name": "Cross Poison", "type": "Poison", "cat": "Physical", "power": 70}
	var poisoned: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"status": "PSN", "hp": 1000, "max_hp": 1000, "def": 50})
	var healthy: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 1000, "max_hp": 1000, "def": 50})
	if AbilityEngine.crit_stage(attacker, move, poisoned) != 5:
		print("  Merciless crit stage vs PSN = ", AbilityEngine.crit_stage(attacker, move, poisoned))
		return false
	if AbilityEngine.crit_stage(attacker, move, healthy) != 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(10):
		var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, poisoned, move, rng)
		if not bool(res.get("critical", false)):
			print("  Merciless did not crit a poisoned target on roll ", i)
			return false
	return true


## Magic Guard: no burn, poison, sandstorm or hazard damage, but
## move recoil still hurts.
func test_magic_guard_no_indirect() -> bool:
	if not AbilityEngine.blocks_indirect_damage(_mon("Alakazam", ["psychic"], ["Psychic"], {"ability": "Magic Guard"})):
		return false
	if AbilityEngine.blocks_indirect_damage(_mon("Alakazam", ["psychic"], ["Psychic"])):
		return false
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var guarded: Dictionary = _mon("Alakazam", ["psychic"], ["Psychic"], {"ability": "Magic Guard", "status": "BRN", "hp": 100, "max_hp": 100})
	var logs: Array = StatusAndFieldEngine.apply_end_of_turn(guarded, field)
	if int(guarded.get("hp", 0)) != 100:
		print("  Magic Guard mon took burn damage: ", int(guarded.get("hp", 0)))
		return false
	var plain: Dictionary = _mon("Alakazam", ["psychic"], ["Psychic"], {"status": "BRN", "hp": 100, "max_hp": 100})
	var logs2: Array = StatusAndFieldEngine.apply_end_of_turn(plain, field)
	if int(plain.get("hp", 0)) != 94:
		print("  plain burn HP = ", int(plain.get("hp", 0)), ", wanted 94.")
		return false
	var hazards: Dictionary = {"stealth_rock": true, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	var g2: Dictionary = _mon("Alakazam", ["psychic"], ["Psychic"], {"ability": "Magic Guard", "hp": 100, "max_hp": 100})
	var hlogs: Array = StatusAndFieldEngine.apply_entry_hazards(g2, hazards, 1.0)
	if int(g2.get("hp", 0)) != 100 or not hlogs.is_empty():
		return false
	var p2: Dictionary = _mon("Alakazam", ["psychic"], ["Psychic"], {"hp": 100, "max_hp": 100})
	var hlogs2: Array = StatusAndFieldEngine.apply_entry_hazards(p2, hazards, 1.0)
	return int(p2.get("hp", 0)) < 100 and not hlogs2.is_empty()


## Inner Focus: Air Slash never flinches the holder (a plain mon
## flinches at least once in 60 tries), and Intimidate cannot drop
## its Attack.
func test_inner_focus_no_flinch() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var move: Dictionary = {"name": "Air Slash", "type": "Flying", "cat": "Special", "power": 75, "flinch_chance": 30}
	var attacker: Dictionary = _mon("Togekiss", ["fairy", "flying"], ["Air Slash"])
	var plain_flinches: int = 0
	for i in range(60):
		var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
		var logs: Array = []
		MoveEffects.apply_after_hit(attacker, defender, move, 10, field, rng, logs)
		if bool(defender.get("flinched", false)):
			plain_flinches += 1
	if plain_flinches < 1:
		print("  plain mon never flinched in 60 Air Slashes.")
		return false
	for i in range(60):
		var focused: Dictionary = _mon("Lucario", ["fighting", "steel"], ["Tackle"], {"ability": "Inner Focus", "hp": 100, "max_hp": 100})
		var logs2: Array = []
		MoveEffects.apply_after_hit(attacker, focused, move, 10, field, rng, logs2)
		if bool(focused.get("flinched", false)):
			print("  Inner Focus mon flinched.")
			return false
	var gary: Dictionary = _mon("Gyarados", ["water", "flying"], ["Tackle"], {"ability": "Intimidate"})
	var foe: Dictionary = _mon("Lucario", ["fighting", "steel"], ["Tackle"], {"ability": "Inner Focus"})
	AbilityEngine.on_switch_in(gary, foe, field)
	var stages: Dictionary = foe.get("stages", {})
	if int(stages.get("atk", -9)) != 0:
		print("  Intimidate dropped Inner Focus Attack to ", int(stages.get("atk", -9)))
		return false
	var plain_foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	AbilityEngine.on_switch_in(gary, plain_foe, field)
	var stages2: Dictionary = plain_foe.get("stages", {})
	return int(stages2.get("atk", -9)) == -1


## Liquid Ooze: Giga Drain on a Liquid Ooze mon hurts the attacker
## for the would-be heal instead of healing it.
func test_liquid_ooze_drain_backfire() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var move: Dictionary = {"name": "Giga Drain", "type": "Grass", "cat": "Special", "power": 75, "drain": 0.5}
	var attacker: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Giga Drain"], {"hp": 50, "max_hp": 100})
	var logs: Array = []
	MoveEffects.apply_after_hit(attacker, _mon("Snorlax", ["normal"], ["Tackle"]), move, 60, field, rng, logs)
	if int(attacker.get("hp", 0)) != 80:
		print("  plain Giga Drain HP = ", int(attacker.get("hp", 0)), ", wanted 80.")
		return false
	var attacker2: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Giga Drain"], {"hp": 50, "max_hp": 100})
	var ooze: Dictionary = _mon("Tentacruel", ["water", "poison"], ["Tackle"], {"ability": "Liquid Ooze"})
	var logs2: Array = []
	MoveEffects.apply_after_hit(attacker2, ooze, move, 60, field, rng, logs2)
	if int(attacker2.get("hp", 0)) != 20:
		print("  Liquid Ooze Giga Drain HP = ", int(attacker2.get("hp", 0)), ", wanted 20.")
		return false
	return str(logs2).contains("was hurt by Liquid Ooze")


## Poison Puppeteer: Pecharunt poisoning a target also confuses
## it for 2-5 turns. An Own Tempo target stays clear, and a
## non-Pecharunt with the ability does not confuse.
func test_poison_puppeteer_confuses() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var pecharunt: Dictionary = _mon("Pecharunt", ["poison", "ghost"], ["Toxic"], {"ability": "Poison Puppeteer"})
	var target: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	if not AbilityEngine.try_set_status(target, "TOX", pecharunt, field, logs):
		return false
	if str(target.get("status", "")) != "TOX":
		return false
	if not bool(target.get("confused", false)):
		print("  Pecharunt poison did not confuse.")
		return false
	var turns: int = int(target.get("confusion_turns", 0))
	if turns < 2 or turns > 5:
		print("  confusion_turns = ", turns, ", wanted 2-5.")
		return false
	var tempo: Dictionary = _mon("Lilligant", ["grass"], ["Tackle"], {"ability": "Own Tempo"})
	var logs2: Array = []
	AbilityEngine.try_set_status(tempo, "TOX", pecharunt, field, logs2)
	if bool(tempo.get("confused", false)):
		print("  Own Tempo target was confused.")
		return false
	var fake: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Toxic"], {"ability": "Poison Puppeteer"})
	var target3: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs3: Array = []
	AbilityEngine.try_set_status(target3, "TOX", fake, field, logs3)
	return not bool(target3.get("confused", false))


## Synchronize: a status the foe gives the holder is passed back
## to the foe. Sleep and freeze are never passed back.
func test_synchronize_pass_back() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var holder: Dictionary = _mon("Espeon", ["psychic"], ["Psychic"], {"ability": "Synchronize"})
	var foe: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Will-O-Wisp"])
	var logs: Array = []
	if not AbilityEngine.try_set_status(holder, "BRN", foe, field, logs):
		return false
	if str(foe.get("status", "")) != "BRN":
		print("  Synchronize did not pass the burn back.")
		return false
	if not str(logs).contains("Synchronize passed BRN back!"):
		return false
	var holder2: Dictionary = _mon("Espeon", ["psychic"], ["Psychic"], {"ability": "Synchronize"})
	var foe2: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Spore"])
	var logs2: Array = []
	if not AbilityEngine.try_set_status(holder2, "SLP", foe2, field, logs2):
		return false
	return str(foe2.get("status", "")) == ""


## Sticky Hold: Knock Off on the holder deals base power (65) and
## leaves the item; on a plain mon it deals 1.5x (97) and takes
## the item. The direct take check runs first, then a real move
## through the controller with a fixed seed.
func test_sticky_hold_knock_off() -> bool:
	var c: BattleController = _new_controller()
	var source: Dictionary = _mon("Weavile", ["dark", "ice"], ["Knock Off"])
	var move: Dictionary = {"name": "Knock Off"}
	var holder: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"ability": "Sticky Hold", "item": "Leftovers"})
	var logs: Array = []
	if c._try_take_item(holder, source, move, logs):
		print("  Sticky Hold item was taken.")
		return false
	if str(holder.get("item", "")) != "Leftovers":
		return false
	if not str(logs).contains("Sticky Hold kept"):
		return false
	var plain_holder: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"item": "Leftovers"})
	var logs2: Array = []
	if not c._try_take_item(plain_holder, source, move, logs2):
		print("  plain item was not taken.")
		return false
	if str(plain_holder.get("item", "?")) != "":
		return false
	var attacker: Dictionary = _mon("Weavile", ["dark", "ice"], ["Knock Off"], {"atk": 100})
	var sticky_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Sticky Hold", "item": "Leftovers", "hp": 500, "max_hp": 500, "def": 50})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500, "def": 50})
	c.start_battle([attacker], [sticky_def], "singles")
	c.rng.seed = 42
	var logs3: Array = []
	var out_a: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Knock Off", true, logs3)
	var dmg_a: int = int(out_a.get("damage", 0))
	if str(c.enemy_party[0].get("item", "")) != "Leftovers":
		print("  Sticky Hold lost its item to Knock Off in battle.")
		return false
	var c2: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Weavile", ["dark", "ice"], ["Knock Off"], {"atk": 100})
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"item": "Leftovers", "hp": 500, "max_hp": 500, "def": 50})
	c2.start_battle([attacker2], [plain_def], "singles")
	c2.rng.seed = 42
	var logs4: Array = []
	var out_b: Dictionary = c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Knock Off", true, logs4)
	var dmg_b: int = int(out_b.get("damage", 0))
	if str(c2.enemy_party[0].get("item", "?")) != "":
		print("  plain mon kept its item after Knock Off.")
		return false
	if dmg_a <= 0 or dmg_b <= 0:
		print("  Knock Off did no damage: ", dmg_a, " / ", dmg_b)
		return false
	if float(dmg_b) < float(dmg_a) * 1.4:
		print("  Knock Off damage ratio = ", float(dmg_b) / float(maxi(1, dmg_a)), ", wanted about 1.49 (97/65).")
		return false
	return str(logs4).contains("lost its Leftovers!")


## Suction Cups: Roar does nothing to the holder; on a plain mon
## it sends in a bench mon.
func test_suction_cups_blocks_roar() -> bool:
	var c: BattleController = _new_controller()
	var target: Dictionary = _mon("Octillery", ["water"], ["Tackle"], {"ability": "Suction Cups"})
	var bench: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var user: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([target, bench], [user], "singles")
	var logs: Array = []
	var res: String = c._handle_forced_switch(true, {"name": "Roar", "forceSwitch": true}, logs, 0)
	if res != "blocked":
		print("  Suction Cups drag-out returned ", res)
		return false
	if str(c.player_party[0].get("name", "?")) != "Octillery":
		return false
	if not str(logs).contains("Suction Cups kept it in battle!"):
		return false
	var c2: BattleController = _new_controller()
	var target2: Dictionary = _mon("Octillery", ["water"], ["Tackle"])
	var bench2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var user2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([target2, bench2], [user2], "singles")
	var logs2: Array = []
	var res2: String = c2._handle_forced_switch(true, {"name": "Roar", "forceSwitch": true}, logs2, 0)
	if res2 != "switched":
		print("  plain drag-out returned ", res2)
		return false
	return str(c2.player_party[0].get("name", "?")) == "Pidgey"


## Corrosion: the holder can poison Steel and Poison types; a
## plain mon cannot poison them at all.
func test_corrosion_poisons_steel() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var salazzle: Dictionary = _mon("Salazzle", ["poison", "fire"], ["Toxic"], {"ability": "Corrosion"})
	var steel: Dictionary = _mon("Steelix", ["steel", "ground"], ["Tackle"])
	var logs: Array = []
	if not AbilityEngine.try_set_status(steel, "PSN", salazzle, field, logs):
		print("  Corrosion could not poison a Steel type.")
		return false
	if str(steel.get("status", "")) != "PSN":
		return false
	var steel2: Dictionary = _mon("Steelix", ["steel", "ground"], ["Tackle"])
	var plain: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Toxic"])
	var logs2: Array = []
	if AbilityEngine.try_set_status(steel2, "PSN", plain, field, logs2):
		print("  plain mon poisoned a Steel type.")
		return false
	if str(steel2.get("status", "?")) != "":
		return false
	var poison_type: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"])
	var logs3: Array = []
	if AbilityEngine.try_set_status(poison_type, "PSN", plain, field, logs3):
		print("  plain mon poisoned a Poison type.")
		return false
	return str(poison_type.get("status", "?")) == ""


## Persistent: Tailwind lasts 6 turns from the holder (4 normally),
## Trick Room 7 (5 normally).
func test_persistent_tailwind_six() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Tornadus", ["flying"], ["Tailwind"], {"ability": "Persistent"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([holder], [foe], "singles")
	var logs: Array = []
	c._apply_field_move(c.player_party[0], c.enemy_party[0], {"name": "Tailwind"}, true, logs)
	var screens: Dictionary = c.field_state.get("player_screens", {})
	if int(screens.get("tailwind", 0)) != 6:
		print("  Persistent Tailwind = ", int(screens.get("tailwind", 0)), ", wanted 6.")
		return false
	var c2: BattleController = _new_controller()
	var plain: Dictionary = _mon("Tornadus", ["flying"], ["Tailwind"])
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([plain], [foe2], "singles")
	var logs2: Array = []
	c2._apply_field_move(c2.player_party[0], c2.enemy_party[0], {"name": "Tailwind"}, true, logs2)
	var screens2: Dictionary = c2.field_state.get("player_screens", {})
	if int(screens2.get("tailwind", 0)) != 4:
		return false
	var c3: BattleController = _new_controller()
	var holder3: Dictionary = _mon("Bronzong", ["steel", "psychic"], ["Trick Room"], {"ability": "Persistent"})
	var foe3: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c3.start_battle([holder3], [foe3], "singles")
	var logs3: Array = []
	c3._apply_field_move(c3.player_party[0], c3.enemy_party[0], {"name": "Trick Room"}, true, logs3)
	if int(c3.field_state.get("trick_room", 0)) != 7:
		print("  Persistent Trick Room = ", int(c3.field_state.get("trick_room", 0)), ", wanted 7.")
		return false
	return true


## Early Bird: sleep_turns 2 wakes on the first attempt; a normal
## mon fails once first.
func test_early_bird_wakes_fast() -> bool:
	var bird: Dictionary = _mon("Chatot", ["normal", "flying"], ["Tackle"], {"ability": "Early Bird", "status": "SLP", "sleep_turns": 2})
	var res: Dictionary = StatusAndFieldEngine.can_act_this_turn(bird)
	if not bool(res.get("can_act", false)):
		print("  Early Bird did not wake on the first attempt.")
		return false
	if str(bird.get("status", "?")) != "":
		return false
	var plain: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"status": "SLP", "sleep_turns": 2})
	var res2: Dictionary = StatusAndFieldEngine.can_act_this_turn(plain)
	if bool(res2.get("can_act", true)):
		print("  normal mon woke too fast.")
		return false
	if int(plain.get("sleep_turns", -1)) != 1:
		print("  normal sleep_turns = ", int(plain.get("sleep_turns", -1)), ", wanted 1.")
		return false
	return true


## Mirror Armor: a foe-caused Attack drop bounces onto the source.
## A Clear Body source makes the drop fizzle instead.
func test_mirror_armor_bounces() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var holder: Dictionary = _mon("Corviknight", ["flying", "steel"], ["Tackle"], {"ability": "Mirror Armor"})
	var source: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	c._apply_stages(holder, {"atk": -1}, logs, source, field)
	var h_stages: Dictionary = holder.get("stages", {})
	var s_stages: Dictionary = source.get("stages", {})
	if int(h_stages.get("atk", -9)) != 0:
		print("  Mirror Armor holder Attack fell to ", int(h_stages.get("atk", -9)))
		return false
	if int(s_stages.get("atk", -9)) != -1:
		print("  Mirror Armor source Attack = ", int(s_stages.get("atk", -9)), ", wanted -1.")
		return false
	if not str(logs).contains("Mirror Armor"):
		return false
	var holder2: Dictionary = _mon("Corviknight", ["flying", "steel"], ["Tackle"], {"ability": "Mirror Armor"})
	var clear_source: Dictionary = _mon("Tentacruel", ["water", "poison"], ["Tackle"], {"ability": "Clear Body"})
	var logs2: Array = []
	c._apply_stages(holder2, {"atk": -1}, logs2, clear_source, field)
	var h2: Dictionary = holder2.get("stages", {})
	var s2: Dictionary = clear_source.get("stages", {})
	if int(h2.get("atk", -9)) != 0 or int(s2.get("atk", -9)) != 0:
		print("  Clear Body fizzle changed a stage.")
		return false
	return str(logs2).contains("had no effect")


## Intimidate now routes through the stat hooks: a Rattled foe
## gains Speed, a Competitive foe gains Sp. Atk, and both still
## lose one Attack stage.
func test_intimidate_routes_hooks() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var gary: Dictionary = _mon("Gyarados", ["water", "flying"], ["Tackle"], {"ability": "Intimidate"})
	var rattled: Dictionary = _mon("Toxtricity", ["electric", "poison"], ["Tackle"], {"ability": "Rattled"})
	AbilityEngine.on_switch_in(gary, rattled, field)
	var r_stages: Dictionary = rattled.get("stages", {})
	if int(r_stages.get("atk", -9)) != -1 or int(r_stages.get("spe", -9)) != 1:
		print("  Rattled stages = ", r_stages)
		return false
	var comp: Dictionary = _mon("Milotic", ["water"], ["Tackle"], {"ability": "Competitive"})
	AbilityEngine.on_switch_in(gary, comp, field)
	var c_stages: Dictionary = comp.get("stages", {})
	# Competitive raises Sp. Atk by 2 stages in Showdown.
	if int(c_stages.get("atk", -9)) != -1 or int(c_stages.get("spa", -9)) != 2:
		print("  Competitive stages = ", c_stages)
		return false
	return true


## The status choke point: a status set through the controller's
## status-move path and one set through a move's secondary effect
## both respect Leaf Guard in Sun and both fire Synchronize.
func test_try_set_status_choke_point() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Toxic"])
	var defender: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	c.start_battle([attacker], [defender], "singles")
	c.field_state["weather"] = "sun"
	var logs: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Toxic", "status": "TOX"}, true, logs)
	if str(c.enemy_party[0].get("status", "?")) != "":
		print("  Leaf Guard mon was poisoned in Sun through the status path.")
		return false
	c.field_state["weather"] = "none"
	var defender2: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	c.start_battle([attacker], [defender2], "singles")
	var logs2: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Toxic", "status": "TOX"}, true, logs2)
	if str(c.enemy_party[0].get("status", "")) != "TOX":
		print("  Leaf Guard mon was not poisoned in clear weather.")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var sync_def: Dictionary = _mon("Espeon", ["psychic"], ["Psychic"], {"ability": "Synchronize", "hp": 100, "max_hp": 100})
	# The foe must not be a Steel or Poison type, or the pass-back
	# would rightly fail on type immunity (a Poison type cannot be
	# poisoned, even by Synchronize).
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var sludge: Dictionary = {"name": "Sludge Bomb", "type": "Poison", "cat": "Special", "power": 90, "status": "PSN", "status_chance": 100}
	var logs3: Array = []
	MoveEffects.apply_after_hit(foe2, sync_def, sludge, 10, field, rng, logs3)
	if str(sync_def.get("status", "")) != "PSN":
		print("  secondary did not poison the Synchronize mon.")
		return false
	return str(foe2.get("status", "")) == "PSN"


## Stench: a damaging move with no flinch chance gains a 10%
## flinch chance (flinch_chance is a percent in the RC1 data, so
## the value is 10, not 0.1). A move that already flinches keeps
## its own chance.
func test_stench_flinch_chance() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var stench_mon: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"ability": "Stench"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	var move: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	AbilityEngine.on_before_move(stench_mon, defender, move, field, logs)
	if int(move.get("flinch_chance", -1)) != 10:
		print("  Stench flinch_chance = ", move.get("flinch_chance", "?"), ", wanted 10.")
		return false
	var move2: Dictionary = {"name": "Air Slash", "type": "Flying", "cat": "Special", "power": 75, "acc": 95, "flinch_chance": 30}
	var logs2: Array = []
	AbilityEngine.on_before_move(stench_mon, defender, move2, field, logs2)
	return int(move2.get("flinch_chance", -1)) == 30


## ------------------------------------------------------------------
## Wiring tests — the controller hooks from PATCH_SPEC_wiring_adapted.
## Each test proves the hook is actually called by the battle code,
## not just present in the ability engine.
## ------------------------------------------------------------------

## Priority bonus: Gale Wings +1 on Flying moves at full HP only,
## Prankster +1 on Status moves only. Through _action_move and the
## turn resolver, the slower Gale Wings mon still moves first.
func test_priority_bonus() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var talon: Dictionary = _mon("Talonflame", ["fire", "flying"], ["Brave Bird"], {"ability": "Gale Wings", "spe": 100})
	var brave: Dictionary = {"name": "Brave Bird", "type": "Flying", "cat": "Physical", "power": 120}
	if AbilityEngine.priority_bonus(talon, brave) != 1:
		print("  Gale Wings priority = ", AbilityEngine.priority_bonus(talon, brave), ", wanted 1.")
		return false
	var hurt: Dictionary = _mon("Talonflame", ["fire", "flying"], ["Brave Bird"], {"ability": "Gale Wings", "spe": 100, "hp": 50})
	if AbilityEngine.priority_bonus(hurt, brave) != 0:
		return false
	var prank: Dictionary = _mon("Whimsicott", ["grass", "fairy"], ["Tailwind"], {"ability": "Prankster"})
	var status_move: Dictionary = {"name": "Tailwind", "type": "Flying", "cat": "Status", "power": 0}
	if AbilityEngine.priority_bonus(prank, status_move) != 1:
		return false
	if AbilityEngine.priority_bonus(prank, brave) != 0:
		return false
	var fast: Dictionary = _mon("Jolteon", ["electric"], ["Tackle"], {"spe": 130})
	var p_move: Dictionary = c._action_move({"type": "move", "move_name": "Brave Bird"}, talon)
	var e_move: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "priority": 0}
	var order: Array = TurnResolver.resolve_order(talon, p_move, fast, e_move, field)
	if order != ["player", "enemy"]:
		print("  Gale Wings order = ", order)
		return false
	var p_move2: Dictionary = c._action_move({"type": "move", "move_name": "Brave Bird"}, hurt)
	var order2: Array = TurnResolver.resolve_order(hurt, p_move2, fast, e_move, field)
	return order2 == ["enemy", "player"]


## Aerilate turns a Normal move Flying (1.2x power). End to end,
## the same Quick Attack hits a Fighting type far harder with
## Aerilate (Flying 2x, plus Flying STAB and the 1.2x boost) than
## without it.
func test_move_type_aerilate() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var attacker: Dictionary = _mon("Salamence", ["dragon", "flying"], ["Quick Attack"], {"ability": "Aerilate"})
	var move: Dictionary = {"name": "Quick Attack", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	if AbilityEngine.move_type(attacker, move, field) != "flying":
		print("  Aerilate move_type = ", AbilityEngine.move_type(attacker, move, field))
		return false
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, field), 1.2):
		return false
	var c: BattleController = _new_controller()
	var plain: Dictionary = _mon("Salamence", ["dragon", "flying"], ["Quick Attack"], {"spe": 100})
	var fighter: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "def": 100})
	c.start_battle([attacker], [fighter], "singles")
	var logs: Array = []
	c.rng.seed = 99
	c._execute_move(attacker, fighter, "Quick Attack", true, logs)
	var dmg_aero: int = 2000 - int(fighter.get("hp", 2000))
	fighter["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 99
	c._execute_move(plain, fighter, "Quick Attack", true, logs2)
	var dmg_plain: int = 2000 - int(fighter.get("hp", 2000))
	if dmg_plain <= 0 or dmg_aero <= dmg_plain * 3:
		print("  Aerilate dmg = ", dmg_aero, ", plain dmg = ", dmg_plain)
		return false
	return true


## Crit stages: Super Luck +1, Merciless a guaranteed crit (stage 5,
## clamped to always crit) against a poisoned foe and 0 otherwise,
## plain mons 0. The calculator really uses it: 500 seeded hits
## crit about 1 in 8 with Super Luck, about 1 in 24 without it.
func test_crit_stage_super_luck() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var lucky: Dictionary = _mon("Absol", ["dark"], ["Slash"], {"ability": "Super Luck"})
	var move: Dictionary = {"name": "Slash", "type": "Normal", "cat": "Physical", "power": 70}
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	if AbilityEngine.crit_stage(lucky, move, defender) != 1:
		return false
	var merciless: Dictionary = _mon("Toxapex", ["poison", "water"], ["Sludge Bomb"], {"ability": "Merciless"})
	var poisoned: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"status": "PSN"})
	if AbilityEngine.crit_stage(merciless, move, poisoned) != 5:
		print("  Merciless crit stage vs poisoned = ", AbilityEngine.crit_stage(merciless, move, poisoned))
		return false
	if AbilityEngine.crit_stage(merciless, move, defender) != 0:
		return false
	var plain: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	if AbilityEngine.crit_stage(plain, move, defender) != 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var crits_lucky: int = 0
	for i in range(500):
		var res: Dictionary = PUWBattleEngine.calculate_damage(lucky, defender, move, rng)
		if bool(res.get("critical", false)):
			crits_lucky += 1
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1234
	var crits_plain: int = 0
	for i in range(500):
		var res2: Dictionary = PUWBattleEngine.calculate_damage(plain, defender, move, rng2)
		if bool(res2.get("critical", false)):
			crits_plain += 1
	if crits_lucky < 25 or crits_lucky > 100:
		print("  Super Luck crits in 500 = ", crits_lucky)
		return false
	return crits_plain >= 0 and crits_plain <= 45


## Leaf Guard blocks a burn in Sun through the status-move path,
## and lets it through in clear weather.
func test_blocks_status() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sun"
	var leaf: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	if not AbilityEngine.blocks_status(leaf, "BRN", field):
		print("  Leaf Guard did not block a burn in Sun.")
		return false
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Chandelure", ["ghost", "fire"], ["Will-O-Wisp"])
	var defender: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	c.start_battle([attacker], [defender], "singles")
	c.field_state["weather"] = "sun"
	var logs: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Will-O-Wisp", "status": "BRN"}, true, logs)
	if str(c.enemy_party[0].get("status", "?")) != "":
		print("  Leaf Guard mon was burned in Sun.")
		return false
	c.field_state["weather"] = "none"
	var defender2: Dictionary = _mon("Leafeon", ["grass"], ["Tackle"], {"ability": "Leaf Guard"})
	c.start_battle([attacker], [defender2], "singles")
	var logs2: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Will-O-Wisp", "status": "BRN"}, true, logs2)
	return str(c.enemy_party[0].get("status", "")) == "BRN"


## Clear Body blocks a foe-caused stat drop; a plain mon still drops.
func test_blocks_stat_change() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var clear: Dictionary = _mon("Tentacruel", ["water", "poison"], ["Tackle"], {"ability": "Clear Body"})
	var source: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	c._apply_stages(clear, {"atk": -1}, logs, source, field)
	var stages: Dictionary = clear.get("stages", {})
	if int(stages.get("atk", -9)) != 0:
		print("  Clear Body Attack fell to ", int(stages.get("atk", -9)))
		return false
	# The log line has an apostrophe, so check it line by line:
	# str() on an Array escapes apostrophes.
	var found: bool = false
	for line in logs:
		if str(line).contains("didn't fall"):
			found = true
	if not found:
		return false
	var plain: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs2: Array = []
	c._apply_stages(plain, {"atk": -1}, logs2, source, field)
	var plain_stages: Dictionary = plain.get("stages", {})
	return int(plain_stages.get("atk", -9)) == -1


## Contrary flips a foe-caused drop into a rise; a plain mon drops.
func test_on_stat_boosted_contrary() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var contrary: Dictionary = _mon("Malamar", ["dark", "psychic"], ["Tackle"], {"ability": "Contrary"})
	var source: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	c._apply_stages(contrary, {"atk": -1}, logs, source, field)
	var stages: Dictionary = contrary.get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  Contrary Attack = ", int(stages.get("atk", -9)), ", wanted +1.")
		return false
	var plain: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs2: Array = []
	c._apply_stages(plain, {"atk": -1}, logs2, source, field)
	var plain_stages: Dictionary = plain.get("stages", {})
	return int(plain_stages.get("atk", -9)) == -1


## Opportunist copies a foe's self boost: the Swords Dance user gets
## +2 Attack, and so does the Opportunist holder facing it.
func test_on_stat_boosted_opportunist() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Scizor", ["bug", "steel"], ["Swords Dance"], {"spe": 100})
	var holder: Dictionary = _mon("Oricorio", ["fire", "flying"], ["Quick Attack"], {"ability": "Opportunist"})
	c.start_battle([user], [holder], "singles")
	var logs: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Swords Dance", "self_boost": {"atk": 2}}, true, logs)
	var user_stages: Dictionary = c.player_party[0].get("stages", {})
	var holder_stages: Dictionary = c.enemy_party[0].get("stages", {})
	if int(user_stages.get("atk", -9)) != 2:
		print("  Swords Dance user Attack = ", int(user_stages.get("atk", -9)))
		return false
	return int(holder_stages.get("atk", -9)) == 2


## Magnet Pull (the traps_foe catch-all, not a hardcoded check)
## stops a Steel type fleeing; Shed Shell escapes it; a non-Steel
## type is not trapped.
func test_traps_foe_flee() -> bool:
	var c: BattleController = _new_controller()
	var logs: Array = []
	var steel: Dictionary = _mon("Steelix", ["steel", "ground"], ["Tackle"], {"spe": 30})
	var magnet: Dictionary = _mon("Magnemite", ["electric", "steel"], ["Tackle"], {"ability": "Magnet Pull", "spe": 30})
	if c._try_flee(steel, magnet, logs):
		print("  Steel type fled from Magnet Pull.")
		return false
	var shelled: Dictionary = _mon("Steelix", ["steel", "ground"], ["Tackle"], {"spe": 30, "item": "Shed Shell"})
	if not c._try_flee(shelled, magnet, logs):
		print("  Shed Shell did not escape Magnet Pull.")
		return false
	var bird: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"], {"spe": 100})
	return c._try_flee(bird, magnet, logs)


## Shadow Tag blocks a voluntary switch; without it the switch works.
func test_traps_foe_switch() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var bench: Dictionary = _mon("Raichu", ["electric"], ["Thunderbolt"])
	var ghost: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"ability": "Shadow Tag"})
	c.start_battle([player, bench], [ghost], "singles")
	var logs: Array = []
	c._perform_action({"type": "switch", "target_idx": 1}, true, logs)
	if str(c.player_party[0].get("name", "")) != "Pikachu":
		print("  switched out despite Shadow Tag.")
		return false
	var bird: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([player, bench], [bird], "singles")
	var logs2: Array = []
	c._perform_action({"type": "switch", "target_idx": 1}, true, logs2)
	return str(c.player_party[0].get("name", "")) == "Raichu"


## Moxie raises the winner's Attack when its move KOs the foe.
func test_on_faint_moxie() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Krookodile", ["ground", "dark"], ["Thunderbolt"], {"ability": "Moxie", "spa": 200})
	var defender: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Thunderbolt", true, logs)
	if int(defender.get("hp", -1)) > 0:
		print("  defender did not faint.")
		return false
	var stages: Dictionary = attacker.get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  Moxie Attack = ", int(stages.get("atk", -9)))
		return false
	return str(logs).contains("Moxie")


## Electric Surge sets Electric Terrain for 5 turns on switch-in.
func test_terrain_surge() -> bool:
	var c: BattleController = _new_controller()
	var koko: Dictionary = _mon("Tapu Koko", ["electric", "fairy"], ["Thunderbolt"], {"ability": "Electric Surge"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([koko], [foe], "singles")
	if str(c.field_state.get("terrain", "")) != "electric":
		print("  terrain = ", str(c.field_state.get("terrain", "?")))
		return false
	return int(c.field_state.get("terrain_turns", -1)) == 5


## Disguise: the first hit breaks the disguise (1/8 max HP lost,
## no real damage) and the forme becomes Mimikyu-Busted.
func test_form_change_disguise() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spa": 200})
	var mimikyu: Dictionary = _mon("Mimikyu", ["ghost", "fairy"], ["Shadow Ball"], {"ability": "Disguise", "hp": 100, "max_hp": 100})
	c.start_battle([attacker], [mimikyu], "singles")
	var logs: Array = []
	c.rng.seed = 11
	c._execute_move(attacker, mimikyu, "Thunderbolt", true, logs)
	if str(mimikyu.get("forme", "")) != "mimikyu-busted":
		print("  Mimikyu forme = ", str(mimikyu.get("forme", "?")))
		return false
	var hp: int = int(mimikyu.get("hp", -1))
	return hp > 0 and hp < 100


## Friend Guard: a defender whose ally has Friend Guard takes
## exactly 3/4 of the damage it takes with a plain ally, same seed.
func test_ally_damage_mult() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spa": 200})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "spd": 50})
	var guard: Dictionary = _mon("Clefairy", ["fairy"], ["Metronome"], {"ability": "Friend Guard"})
	var plain_ally: Dictionary = _mon("Clefairy", ["fairy"], ["Metronome"])
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [defender, guard], "doubles")
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, [{"side": "enemy", "slot": 0}], "Thunderbolt", true, 0, logs)
	var dmg_guard: int = 2000 - int(defender.get("hp", 2000))
	defender["hp"] = 2000
	c.enemy_party[1] = plain_ally
	c._refresh_doubles_allies()
	var logs2: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, [{"side": "enemy", "slot": 0}], "Thunderbolt", true, 0, logs2)
	var dmg_plain: int = 2000 - int(defender.get("hp", 2000))
	if dmg_plain <= 0:
		return false
	if dmg_guard != int(float(dmg_plain) * 0.75):
		print("  Friend Guard dmg = ", dmg_guard, ", plain dmg = ", dmg_plain)
		return false
	return true


## Cheek Pouch: eating a Sitrus Berry at end of turn heals the
## berry's 1/4 max HP plus 1/3 max HP from Cheek Pouch.
## 40 + 25 + 33 = 98.
func test_on_item_use_cheek_pouch() -> bool:
	var c: BattleController = _new_controller()
	var eater: Dictionary = _mon("Dedenne", ["electric", "fairy"], ["Tackle"], {"ability": "Cheek Pouch", "hp": 40, "max_hp": 100, "item": "Sitrus Berry"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([eater], [foe], "singles")
	var logs: Array = []
	ItemEngine.on_end_of_turn(eater, c.field_state, logs)
	if int(eater.get("hp", -1)) != 98:
		print("  Cheek Pouch eater hp = ", int(eater.get("hp", -1)), ", wanted 98.")
		return false
	return str(logs).contains("Cheek Pouch")


## Unburden doubles Speed once the held item is gone, and only then.
func test_speed_multiplier_unburden() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var base: Dictionary = _mon("Hitmonlee", ["fighting"], ["Close Combat"], {"spe": 100})
	if not is_equal_approx(TurnResolver.effective_speed(base, field), 100.0):
		return false
	var unburden: Dictionary = _mon("Hitmonlee", ["fighting"], ["Close Combat"], {"ability": "Unburden", "spe": 100, "item": "", "item_lost": true})
	if not is_equal_approx(TurnResolver.effective_speed(unburden, field), 200.0):
		print("  Unburden speed = ", TurnResolver.effective_speed(unburden, field))
		return false
	var holding: Dictionary = _mon("Hitmonlee", ["fighting"], ["Close Combat"], {"ability": "Unburden", "spe": 100, "item": "Sitrus Berry"})
	return is_equal_approx(TurnResolver.effective_speed(holding, field), 100.0)


## Magic Bounce bounces Toxic back at the user. The attacker is a
## Dark type on purpose: a Poison type could not be poisoned by
## its own bounced Toxic.
func test_magic_bounce() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Umbreon", ["dark"], ["Toxic"])
	var defender: Dictionary = _mon("Espeon", ["psychic"], ["Psychic"], {"ability": "Magic Bounce"})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 3
	# Toxic has no reflectable flag in the RC1 move list, so the
	# override adds it (the flag is what Magic Bounce reads).
	c._execute_move(attacker, defender, "Toxic", true, logs, {"flags": {"reflectable": true}})
	if str(c.enemy_party[0].get("status", "?")) != "":
		print("  Magic Bounce defender was poisoned.")
		return false
	if str(c.player_party[0].get("status", "")) != "TOX":
		print("  Magic Bounce did not poison the user.")
		return false
	return str(logs).contains("Magic Bounce")


## Skill Link forces 5 hits on a [2, 5] move in doubles too. The
## expected damage is the same five rolls the move will consume.
func test_skill_link_doubles() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Cloyster", ["water", "ice"], ["Bullet Seed"], {"ability": "Skill Link", "atk": 200})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "def": 50})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [defender, _mon("Rattata", ["normal"], ["Tackle"])], "doubles")
	var move: Dictionary = {"name": "Bullet Seed", "type": "Grass", "cat": "Physical", "power": 25, "acc": 100, "multihit": [2, 5]}
	if MoveEffects.get_hit_count(move, c.rng, attacker) != 5:
		print("  Skill Link hit count is not 5.")
		return false
	var expect_rng := RandomNumberGenerator.new()
	expect_rng.seed = 5150
	var expected: int = 0
	for i in range(5):
		expected += int(PUWBattleEngine.calculate_damage(attacker, defender, move, expect_rng).get("damage", 0))
	var logs: Array = []
	c.rng.seed = 5150
	c._execute_move_doubles(attacker, [{"side": "enemy", "slot": 0}], "Bullet Seed", true, 0, logs, move)
	var dealt: int = 2000 - int(defender.get("hp", 2000))
	if dealt != expected:
		print("  Skill Link dealt = ", dealt, ", expected 5 hits = ", expected)
		return false
	return true


## Field flags sync: Neutralizing Gas suppresses abilities while
## its holder is out, and the flag clears when the holder switches.
func test_field_flags_sync() -> bool:
	var c: BattleController = _new_controller()
	var gas: Dictionary = _mon("Weezing", ["poison"], ["Sludge Bomb"], {"ability": "Neutralizing Gas"})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var foe: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([gas, bench], [foe], "singles")
	if not bool(c.field_state.get("abilities_suppressed", false)):
		print("  Neutralizing Gas did not suppress abilities.")
		return false
	var logs: Array = c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	if bool(c.field_state.get("abilities_suppressed", false)):
		print("  abilities_suppressed stayed on after the switch.")
		return false
	return str(c.player_party[0].get("name", "")) == "Snorlax"


## Rebound bounces a reflectable Status move only on the switch-in
## turn (active_turns == 0), and sets the bounced flag so the
## controller can use the move against its user.
func test_rebound_switch_in_turn() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var attacker: Dictionary = _mon("Umbreon", ["dark"], ["Toxic"])
	var defender: Dictionary = _mon("Hatterene", ["psychic", "fairy"], ["Psychic"], {"ability": "Rebound", "active_turns": 0})
	var move: Dictionary = {"name": "Toxic", "type": "Poison", "cat": "Status", "power": 0, "acc": 90, "status": "TOX", "flags": {"reflectable": true}}
	var logs: Array = []
	var res: Dictionary = AbilityEngine.on_before_move(attacker, defender, move, field, logs)
	if not bool(res.get("skip", false)) or not bool(move.get("bounced", false)):
		print("  Rebound did not bounce on the switch-in turn.")
		return false
	defender["active_turns"] = 1
	var move2: Dictionary = {"name": "Toxic", "type": "Poison", "cat": "Status", "power": 0, "acc": 90, "status": "TOX", "flags": {"reflectable": true}}
	var logs2: Array = []
	var res2: Dictionary = AbilityEngine.on_before_move(attacker, defender, move2, field, logs2)
	# The dispatcher returns the move dict itself when nothing
	# blocks (it starts from the v2 hook's result), so "not
	# bounced" means no skip flag and no bounced mark on the move.
	return not bool(res2.get("skip", false)) and not bool(move2.get("bounced", false))


## Contrary flips a self boost too: Swords Dance drops Attack by 2.
func test_contrary_self_boost() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Malamar", ["dark", "psychic"], ["Swords Dance"], {"ability": "Contrary"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([user], [foe], "singles")
	var logs: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Swords Dance", "self_boost": {"atk": 2}}, true, logs)
	var stages: Dictionary = c.player_party[0].get("stages", {})
	return int(stages.get("atk", -9)) == -2


## Simple doubles a self boost: Swords Dance raises Attack by 4.
func test_simple_self_boost() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Bibarel", ["normal", "water"], ["Swords Dance"], {"ability": "Simple"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([user], [foe], "singles")
	var logs: Array = []
	c._apply_status_move(c.player_party[0], c.enemy_party[0], {"name": "Swords Dance", "self_boost": {"atk": 2}}, true, logs)
	var stages: Dictionary = c.player_party[0].get("stages", {})
	return int(stages.get("atk", -9)) == 4


## Competitive only answers foe-caused drops. A self-caused Defense
## drop (Close Combat's own cost) does not raise Sp. Atk, but the
## same drop from a foe does (+2).
func test_competitive_no_self_trigger() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var comp: Dictionary = _mon("Milotic", ["water"], ["Tackle"], {"ability": "Competitive"})
	var logs: Array = []
	c._apply_stages(comp, {"def": -1}, logs, {}, field)
	var stages: Dictionary = comp.get("stages", {})
	if int(stages.get("def", -9)) != -1 or int(stages.get("spa", -9)) != 0:
		print("  Competitive stages after self drop = ", stages)
		return false
	var source: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs2: Array = []
	c._apply_stages(comp, {"atk": -1}, logs2, source, field)
	var stages2: Dictionary = comp.get("stages", {})
	return int(stages2.get("spa", -9)) == 2


## ------------------------------------------------------------------
## Group A — weather + end-of-turn abilities (Overcoat, Sand Force,
## Sand Rush, Sand Veil, Snow Cloak, Poison Heal, Solar Power,
## Water Bubble). Written against the Group A spec
## (PATCH_SPEC_groupA_weather.txt) and the patched v3 engine in
## /tmp/v3_apply, where Patches C, D and G are already in place.
## ------------------------------------------------------------------

## Overcoat blocks powder moves, but not normal moves, and a mon
## with no ability does not block them.
func test_overcoat_powder_block() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var attacker: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Sludge Bomb"])
	var defender: Dictionary = _mon("Ferrothorn", ["grass", "steel"], ["Tackle"], {"ability": "Overcoat"})
	var spore: Dictionary = {"name": "Spore", "type": "Grass", "cat": "Status", "power": 0, "flags": {"powder": true}}
	var logs: Array = []
	var result: Dictionary = AbilityEngine.on_before_move(attacker, defender, spore, field, logs)
	if not bool(result.get("skip", false)):
		print("  Overcoat did not block Spore (no skip in the result).")
		return false
	if not str(logs).contains("Overcoat blocked the powder move!"):
		print("  Overcoat block log line missing: %s" % str(logs))
		return false
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	var logs2: Array = []
	var result2: Dictionary = AbilityEngine.on_before_move(attacker, defender, tackle, field, logs2)
	if bool(result2.get("skip", false)):
		print("  Overcoat wrongly blocked Tackle, a non-powder move.")
		return false
	# A fresh Spore dict each time: on_before_move writes its
	# result onto the move dict it is given, so reusing the first
	# dict would carry the Overcoat skip into this check.
	var plain: Dictionary = _mon("Ferrothorn", ["grass", "steel"], ["Tackle"], {"ability": ""})
	var spore2: Dictionary = {"name": "Spore", "type": "Grass", "cat": "Status", "power": 0, "flags": {"powder": true}}
	var logs3: Array = []
	var result3: Dictionary = AbilityEngine.on_before_move(attacker, plain, spore2, field, logs3)
	if bool(result3.get("skip", false)):
		print("  a mon with no ability wrongly blocked Spore.")
		return false
	return true


## Sandstorm chips a plain mon for 1/16 max HP, but not the four
## sand-immune ability holders, not a Ground type, not a Magic
## Guard holder, and not anyone while the weather is suppressed.
## Snow Cloak only guards snow, not sand.
## NOTE: the type strings here are capitalised ("Normal",
## "Ground") on purpose. The sand block in
## StatusAndFieldEngine compares types case-sensitively
## ("Rock" / "Ground" / "Steel"), so lowercase types would make
## the Ground-type regression check fail for the wrong reason.
func test_sandstorm_damage_immunity() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sand"
	var plain: Dictionary = _mon("Pidgey", ["Normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var plain_logs: Array = StatusAndFieldEngine.apply_end_of_turn(plain, field)
	if int(plain.get("hp", -1)) != 94:
		print("  plain mon in sand had %s HP, wanted 94 (chip floor(100/16) = 6)." % str(plain.get("hp", -1)))
		return false
	if not str(plain_logs).contains("buffeted by the sandstorm"):
		print("  plain mon in sand had no sandstorm log line: %s" % str(plain_logs))
		return false
	var immune_abs: Array = ["Overcoat", "Sand Force", "Sand Rush", "Sand Veil"]
	for ab in immune_abs:
		var ab_name: String = str(ab)
		var holder: Dictionary = _mon("Pidgey", ["Normal"], ["Tackle"], {"ability": ab_name, "hp": 100, "max_hp": 100})
		var holder_logs: Array = StatusAndFieldEngine.apply_end_of_turn(holder, field)
		if int(holder.get("hp", -1)) != 100:
			print("  %s holder lost HP in sand (hp %s), wanted 100." % [ab_name, str(holder.get("hp", -1))])
			return false
		if str(holder_logs).contains("buffeted"):
			print("  %s holder still got a sandstorm log line." % ab_name)
			return false
	var ground: Dictionary = _mon("Diglett", ["Ground"], ["Tackle"], {"hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(ground, field)
	if int(ground.get("hp", -1)) != 100:
		print("  plain Ground-type mon lost HP in sand (hp %s), wanted 100." % str(ground.get("hp", -1)))
		return false
	var guard: Dictionary = _mon("Pidgey", ["Normal"], ["Tackle"], {"ability": "Magic Guard", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(guard, field)
	if int(guard.get("hp", -1)) != 100:
		print("  Magic Guard holder lost HP in sand (hp %s), wanted 100." % str(guard.get("hp", -1)))
		return false
	var suppressed_field: Dictionary = StatusAndFieldEngine.create_field_state()
	suppressed_field["weather"] = "sand"
	suppressed_field["weather_suppressed"] = true
	var suppressed: Dictionary = _mon("Pidgey", ["Normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(suppressed, suppressed_field)
	if int(suppressed.get("hp", -1)) != 100:
		print("  plain mon lost HP in sand while the weather was suppressed (hp %s), wanted 100." % str(suppressed.get("hp", -1)))
		return false
	var cloak: Dictionary = _mon("Pidgey", ["Normal"], ["Tackle"], {"ability": "Snow Cloak", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(cloak, field)
	if int(cloak.get("hp", -1)) != 94:
		print("  Snow Cloak holder in sand had %s HP, wanted 94: Snow Cloak guards snow, not sand." % str(cloak.get("hp", -1)))
		return false
	return true


## Sand Force: Ground / Rock / Steel moves deal 1.3x power in sand.
func test_sand_force_power() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sand"
	var attacker: Dictionary = _mon("Garchomp", ["dragon", "ground"], ["Earthquake"], {"ability": "Sand Force", "atk": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"def": 50})
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100}
	if AbilityEngine.power_mult(attacker, defender, quake, field) != 1.3:
		print("  Sand Force power_mult in sand was %s, wanted 1.3." % str(AbilityEngine.power_mult(attacker, defender, quake, field)))
		return false
	var clear_field: Dictionary = StatusAndFieldEngine.create_field_state()
	if AbilityEngine.power_mult(attacker, defender, quake, clear_field) != 1.0:
		print("  Sand Force power_mult in clear weather was not 1.0.")
		return false
	var claw: Dictionary = {"name": "Dragon Claw", "type": "Dragon", "cat": "Physical", "power": 80}
	if AbilityEngine.power_mult(attacker, defender, claw, field) != 1.0:
		print("  Sand Force boosted a Dragon move in sand; only Ground, Rock and Steel get 1.3x.")
		return false
	# Damage check. Base = ((22) * 100 * (100 / 50)) / 50 + 2 = 90.
	# STAB 1.5, effectiveness 1.0, so plain damage is
	# floor(90 * 1.5 * rand) = 114 to 135 with no crit. The same
	# seed is reset before each call so both rolls match, then the
	# controller step is total = int(float(plain) * 1.3).
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var plain_res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, quake, rng)
	var plain_dmg: int = int(plain_res.get("damage", -1))
	var total: int = int(float(plain_dmg) * 1.3)
	if not bool(plain_res.get("critical", false)):
		if plain_dmg < 114 or plain_dmg > 135:
			print("  plain Earthquake damage was %s, wanted 114 to 135 with no crit." % str(plain_dmg))
			return false
		if total < 148 or total > 175:
			print("  Sand Force Earthquake total was %s, wanted 148 to 175 with no crit." % str(total))
			return false
	return true


## Sand Rush: Speed is doubled in sand (TurnResolver-owned half).
func test_sand_rush_speed() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sand"
	var mon: Dictionary = _mon("Excadrill", ["ground", "steel"], ["Earthquake"], {"ability": "Sand Rush", "spe": 100})
	if TurnResolver.effective_speed(mon, field) != 200.0:
		print("  Sand Rush Speed in sand was %s, wanted 200.0." % str(TurnResolver.effective_speed(mon, field)))
		return false
	var clear_field: Dictionary = StatusAndFieldEngine.create_field_state()
	if TurnResolver.effective_speed(mon, clear_field) != 100.0:
		print("  Sand Rush Speed in clear weather was %s, wanted 100.0." % str(TurnResolver.effective_speed(mon, clear_field)))
		return false
	return true


## Sand Veil: moves used against the holder are 0.8x accurate in sand.
func test_sand_veil_accuracy() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sand"
	var attacker: Dictionary = _mon("Garchomp", ["dragon", "ground"], ["Earthquake"])
	var defender: Dictionary = _mon("Garchomp", ["dragon", "ground"], ["Earthquake"], {"ability": "Sand Veil"})
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	if AbilityEngine.accuracy_mult(attacker, defender, tackle, field) != 0.8:
		print("  Sand Veil accuracy_mult in sand was %s, wanted 0.8." % str(AbilityEngine.accuracy_mult(attacker, defender, tackle, field)))
		return false
	var clear_field: Dictionary = StatusAndFieldEngine.create_field_state()
	if AbilityEngine.accuracy_mult(attacker, defender, tackle, clear_field) != 1.0:
		print("  Sand Veil accuracy_mult in clear weather was not 1.0.")
		return false
	return true


## Snow Cloak: moves used against the holder are 0.8x accurate in
## snow. Snow deals no damage at all in Gen 9 (hail damage was
## removed), so a plain mon and a Snow Cloak mon both keep full HP.
func test_snow_cloak_accuracy() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "snow"
	var attacker: Dictionary = _mon("Garchomp", ["dragon", "ground"], ["Earthquake"])
	var defender: Dictionary = _mon("Garchomp", ["dragon", "ground"], ["Earthquake"], {"ability": "Snow Cloak"})
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	if AbilityEngine.accuracy_mult(attacker, defender, tackle, field) != 0.8:
		print("  Snow Cloak accuracy_mult in snow was %s, wanted 0.8." % str(AbilityEngine.accuracy_mult(attacker, defender, tackle, field)))
		return false
	var clear_field: Dictionary = StatusAndFieldEngine.create_field_state()
	if AbilityEngine.accuracy_mult(attacker, defender, tackle, clear_field) != 1.0:
		print("  Snow Cloak accuracy_mult in clear weather was not 1.0.")
		return false
	var plain: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var plain_logs: Array = StatusAndFieldEngine.apply_end_of_turn(plain, field)
	if int(plain.get("hp", -1)) != 100:
		print("  plain mon lost HP in snow (hp %s): snow deals no damage in Gen 9." % str(plain.get("hp", -1)))
		return false
	if str(plain_logs).contains("buffeted") or str(plain_logs).contains("snow"):
		print("  plain mon in snow got a weather-damage log line: %s" % str(plain_logs))
		return false
	var cloak: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"ability": "Snow Cloak", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(cloak, field)
	if int(cloak.get("hp", -1)) != 100:
		print("  Snow Cloak mon lost HP in snow (hp %s), wanted 100." % str(cloak.get("hp", -1)))
		return false
	return true


## Poison Heal: a poisoned holder heals exactly 1/8 max HP once
## per turn and takes no poison damage. Two heals would give 74
## from 50 HP, so 62 proves the old double-heal is gone.
func test_poison_heal_skip_and_heal() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var mon: Dictionary = _mon("Gliscor", ["ground", "flying"], ["Earthquake"], {"ability": "Poison Heal", "status": "PSN", "hp": 50, "max_hp": 100})
	AbilityEngine.on_end_of_turn(mon, field, logs)
	var end_logs: Array = StatusAndFieldEngine.apply_end_of_turn(mon, field)
	if int(mon.get("hp", -1)) != 62:
		print("  poisoned Poison Heal mon had %s HP, wanted 62 (one heal of 12 from 50)." % str(mon.get("hp", -1)))
		return false
	if not str(logs).contains("restored HP with Poison Heal"):
		print("  Poison Heal heal log line missing: %s" % str(logs))
		return false
	if str(end_logs).contains("hurt by poison") or str(logs).contains("hurt by poison"):
		print("  Poison Heal mon still took poison damage.")
		return false
	var tox: Dictionary = _mon("Gliscor", ["ground", "flying"], ["Earthquake"], {"ability": "Poison Heal", "status": "TOX", "toxic_counter": 1, "hp": 50, "max_hp": 100})
	var logs2: Array = []
	AbilityEngine.on_end_of_turn(tox, field, logs2)
	StatusAndFieldEngine.apply_end_of_turn(tox, field)
	if int(tox.get("hp", -1)) != 62:
		print("  badly poisoned Poison Heal mon had %s HP, wanted 62." % str(tox.get("hp", -1)))
		return false
	if int(tox.get("toxic_counter", -1)) != 1:
		print("  badly poisoned Poison Heal mon toxic_counter was %s, wanted 1 (damage skipped, counter not raised)." % str(tox.get("toxic_counter", -1)))
		return false
	var capped: Dictionary = _mon("Gliscor", ["ground", "flying"], ["Earthquake"], {"ability": "Poison Heal", "status": "PSN", "hp": 88, "max_hp": 100})
	var logs3: Array = []
	AbilityEngine.on_end_of_turn(capped, field, logs3)
	StatusAndFieldEngine.apply_end_of_turn(capped, field)
	if int(capped.get("hp", -1)) != 100:
		print("  Poison Heal heal was not capped at max HP (hp %s, wanted 100)." % str(capped.get("hp", -1)))
		return false
	var plain_psn: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"status": "PSN", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(plain_psn, field)
	if int(plain_psn.get("hp", -1)) != 88:
		print("  plain poisoned mon had %s HP, wanted 88 (lost floor(100/8) = 12)." % str(plain_psn.get("hp", -1)))
		return false
	var plain_tox: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"status": "TOX", "toxic_counter": 1, "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(plain_tox, field)
	if int(plain_tox.get("hp", -1)) != 94:
		print("  plain badly poisoned mon had %s HP, wanted 94 (lost floor(100*1/16) = 6)." % str(plain_tox.get("hp", -1)))
		return false
	if int(plain_tox.get("toxic_counter", -1)) != 2:
		print("  plain badly poisoned mon toxic_counter was %s, wanted 2." % str(plain_tox.get("toxic_counter", -1)))
		return false
	var burned: Dictionary = _mon("Gliscor", ["ground", "flying"], ["Earthquake"], {"ability": "Poison Heal", "status": "BRN", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(burned, field)
	if int(burned.get("hp", -1)) != 94:
		print("  burned Poison Heal mon had %s HP, wanted 94: burn damage is NOT skipped for Poison Heal." % str(burned.get("hp", -1)))
		return false
	return true


## Solar Power: special moves deal 1.5x in sun (and in harsh
## sunlight), and the holder loses exactly 1/8 max HP once per
## turn in sun. Two losses would give 76 from 100 HP, so 88
## proves the old double-loss is gone. A Utility Umbrella blocks
## both halves.
func test_solar_power_damage_and_loss() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["weather"] = "sun"
	var attacker: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "spa": 200})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spd": 50})
	var flame: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special", "power": 90}
	if AbilityEngine.power_mult(attacker, defender, flame, field) != 1.5:
		print("  Solar Power power_mult in sun was %s, wanted 1.5." % str(AbilityEngine.power_mult(attacker, defender, flame, field)))
		return false
	var physical: Dictionary = {"name": "Flare Blitz", "type": "Fire", "cat": "Physical", "power": 120}
	if AbilityEngine.power_mult(attacker, defender, physical, field) != 1.0:
		print("  Solar Power boosted a physical move in sun; only special moves get 1.5x.")
		return false
	var clear_field: Dictionary = StatusAndFieldEngine.create_field_state()
	if AbilityEngine.power_mult(attacker, defender, flame, clear_field) != 1.0:
		print("  Solar Power power_mult in clear weather was not 1.0.")
		return false
	var umbrella_attacker: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "spa": 200, "item": "Utility Umbrella"})
	if AbilityEngine.power_mult(umbrella_attacker, defender, flame, field) != 1.0:
		print("  Solar Power still boosted a special move in sun while holding a Utility Umbrella.")
		return false
	var harsh_field: Dictionary = StatusAndFieldEngine.create_field_state()
	harsh_field["weather"] = "intensesun"
	if AbilityEngine.power_mult(attacker, defender, flame, harsh_field) != 1.5:
		print("  Solar Power power_mult in harsh sunlight was %s, wanted 1.5." % str(AbilityEngine.power_mult(attacker, defender, flame, harsh_field)))
		return false
	# Damage check. Base = ((22) * 90 * (200 / 50)) / 50 + 2 = 160.4.
	# STAB 1.5, effectiveness 1.0, so plain damage is
	# floor(160.4 * 1.5 * rand) = 204 to 240 with no crit. The same
	# seed is reset before each call so both rolls match, then the
	# controller step is total = int(float(plain) * 1.5).
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var plain_res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, flame, rng)
	var plain_dmg: int = int(plain_res.get("damage", -1))
	var total: int = int(float(plain_dmg) * 1.5)
	if not bool(plain_res.get("critical", false)):
		if plain_dmg < 204 or plain_dmg > 240:
			print("  plain Flamethrower damage was %s, wanted 204 to 240 with no crit." % str(plain_dmg))
			return false
		if total < 306 or total > 360:
			print("  Solar Power Flamethrower total was %s, wanted 306 to 360 with no crit." % str(total))
			return false
	var logs: Array = []
	var mon: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "hp": 100, "max_hp": 100})
	AbilityEngine.on_end_of_turn(mon, field, logs)
	if int(mon.get("hp", -1)) != 88:
		print("  Solar Power mon in sun had %s HP, wanted 88 (one loss of 12 from 100)." % str(mon.get("hp", -1)))
		return false
	if not str(logs).contains("was hurt by Solar Power"):
		print("  Solar Power loss log line missing: %s" % str(logs))
		return false
	var umbrella_mon: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "hp": 100, "max_hp": 100, "item": "Utility Umbrella"})
	var logs2: Array = []
	AbilityEngine.on_end_of_turn(umbrella_mon, field, logs2)
	if int(umbrella_mon.get("hp", -1)) != 100:
		print("  Solar Power mon with a Utility Umbrella lost HP in sun (hp %s), wanted 100." % str(umbrella_mon.get("hp", -1)))
		return false
	var clear_mon: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "hp": 100, "max_hp": 100})
	var logs3: Array = []
	AbilityEngine.on_end_of_turn(clear_mon, clear_field, logs3)
	if int(clear_mon.get("hp", -1)) != 100:
		print("  Solar Power mon in clear weather lost HP (hp %s), wanted 100." % str(clear_mon.get("hp", -1)))
		return false
	var harsh_mon: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"ability": "Solar Power", "hp": 100, "max_hp": 100})
	var logs4: Array = []
	AbilityEngine.on_end_of_turn(harsh_mon, harsh_field, logs4)
	if int(harsh_mon.get("hp", -1)) != 88:
		print("  Solar Power mon in harsh sunlight had %s HP, wanted 88." % str(harsh_mon.get("hp", -1)))
		return false
	return true


## Water Bubble: Water moves deal 2x power, and Fire moves against
## the holder deal 0.5x damage.
## DEVIATION: the spec calls AbilityEngine.damage_mult for the
## direct 0.5x check, but AbilityEngine has no damage_mult
## function — damage_mult lives on the batch files, and
## AbilityEngine.modify_damage is the dispatcher that applies
## them. So the direct check uses AbilityBatch4.damage_mult
## (where the Water Bubble arm lives), and the full-path check
## uses AbilityEngine.modify_damage, as the spec already does
## for the damage numbers.
func test_water_bubble_damage() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var attacker: Dictionary = _mon("Araquanid", ["water", "bug"], ["Surf"], {"ability": "Water Bubble", "spa": 200})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spd": 50})
	var surf: Dictionary = {"name": "Surf", "type": "Water", "cat": "Special", "power": 90}
	if AbilityEngine.power_mult(attacker, defender, surf, field) != 2.0:
		print("  Water Bubble power_mult for Surf was %s, wanted 2.0." % str(AbilityEngine.power_mult(attacker, defender, surf, field)))
		return false
	var bug_move: Dictionary = {"name": "Bug Buzz", "type": "Bug", "cat": "Special", "power": 90}
	if AbilityEngine.power_mult(attacker, defender, bug_move, field) != 1.0:
		print("  Water Bubble boosted a Bug move; only Water moves get 2x.")
		return false
	# Damage check. Base 160.4 as in the Solar Power test, STAB
	# 1.5, effectiveness 1.0, so plain damage is 204 to 240 with
	# no crit, and the Water Bubble total is int(float(plain) * 2.0).
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var plain_res: Dictionary = PUWBattleEngine.calculate_damage(attacker, defender, surf, rng)
	var plain_dmg: int = int(plain_res.get("damage", -1))
	var total: int = int(float(plain_dmg) * 2.0)
	if not bool(plain_res.get("critical", false)):
		if plain_dmg < 204 or plain_dmg > 240:
			print("  plain Surf damage was %s, wanted 204 to 240 with no crit." % str(plain_dmg))
			return false
		if total < 408 or total > 480:
			print("  Water Bubble Surf total was %s, wanted 408 to 480 with no crit." % str(total))
			return false
	var fire_attacker: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"], {"spa": 200})
	# DEVIATION: the spec uses Araquanid here, but Araquanid is
	# Water/Bug, so Fire is 1.0x effective against it (0.5x vs
	# Water, 2x vs Bug) and the spec's hand numbers (eff 0.5,
	# plain 102 to 120) do not hold. A pure Water defender keeps
	# the spec's numbers exact.
	var bubble_defender: Dictionary = _mon("Blastoise", ["water"], ["Surf"], {"ability": "Water Bubble", "spd": 50})
	var flame: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special", "power": 90}
	if AbilityBatch4.damage_mult(fire_attacker, bubble_defender, flame, true, false, 0.5) != 0.5:
		print("  Water Bubble damage_mult for a Fire move was not 0.5.")
		return false
	rng.seed = 12345
	var fire_res: Dictionary = PUWBattleEngine.calculate_damage(fire_attacker, bubble_defender, flame, rng)
	var fire_plain: int = int(fire_res.get("damage", -1))
	var fire_total: int = AbilityEngine.modify_damage(fire_attacker, bubble_defender, flame, fire_plain, true, false, 0.5)
	var fire_expected: int = int(max(1, round(float(fire_plain) * 0.5)))
	if fire_total != fire_expected:
		print("  Water Bubble Flamethrower total was %s, wanted %s (half of plain %s)." % [str(fire_total), str(fire_expected), str(fire_plain)])
		return false
	if not bool(fire_res.get("critical", false)):
		# Plain: base 160.4, STAB 1.5, effectiveness 0.5
		# (Fire vs Water), so floor(160.4 * 1.5 * 0.5 * rand)
		# = 102 to 120, halved to 51 to 60.
		if fire_plain < 102 or fire_plain > 120:
			print("  plain Flamethrower vs Water Bubble holder was %s, wanted 102 to 120 with no crit." % str(fire_plain))
			return false
		if fire_total < 51 or fire_total > 60:
			print("  Water Bubble Flamethrower total was %s, wanted 51 to 60 with no crit." % str(fire_total))
			return false
	return true


## Water Bubble: the holder cannot be burned, and a burn it
## already has is cured at the end of the turn, before the burn
## chip runs (controller order: ability end of turn first).
func test_water_bubble_burn() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var holder: Dictionary = _mon("Araquanid", ["water", "bug"], ["Surf"], {"ability": "Water Bubble"})
	var source: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Sludge Bomb"])
	if not AbilityEngine.blocks_status(holder, "BRN"):
		print("  Water Bubble did not block a burn.")
		return false
	if AbilityEngine.blocks_status(holder, "PSN"):
		print("  Water Bubble wrongly blocked poison; it only blocks burns.")
		return false
	var logs: Array = []
	if AbilityEngine.try_set_status(holder, "BRN", source, field, logs):
		print("  Water Bubble holder was burned through try_set_status.")
		return false
	if str(holder.get("status", "?")) != "":
		print("  Water Bubble holder status was '%s', wanted empty." % str(holder.get("status", "?")))
		return false
	var burned: Dictionary = _mon("Araquanid", ["water", "bug"], ["Surf"], {"ability": "Water Bubble", "status": "BRN", "hp": 100, "max_hp": 100})
	var cure_logs: Array = []
	AbilityEngine.on_end_of_turn(burned, field, cure_logs)
	if str(burned.get("status", "?")) != "":
		print("  Water Bubble did not cure the burn at end of turn (status '%s')." % str(burned.get("status", "?")))
		return false
	if not str(cure_logs).contains("cured its burn"):
		print("  Water Bubble burn-cure log line missing: %s" % str(cure_logs))
		return false
	StatusAndFieldEngine.apply_end_of_turn(burned, field)
	if int(burned.get("hp", -1)) != 100:
		print("  Water Bubble holder lost HP to burn after the cure (hp %s), wanted 100." % str(burned.get("hp", -1)))
		return false
	var plain_burned: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"status": "BRN", "hp": 100, "max_hp": 100})
	StatusAndFieldEngine.apply_end_of_turn(plain_burned, field)
	if int(plain_burned.get("hp", -1)) != 94:
		print("  plain burned mon had %s HP, wanted 94 (lost floor(100/16) = 6)." % str(plain_burned.get("hp", -1)))
		return false
	return true


## The shared weather-damage immunity helper answers true only
## for the abilities and weather that deal end-of-turn damage.
func test_weather_damage_helper() -> bool:
	var abilities: Array = ["Overcoat", "Sand Force", "Sand Rush", "Sand Veil", "Snow Cloak", ""]
	var sand_immune: Array = ["Overcoat", "Sand Force", "Sand Rush", "Sand Veil"]
	var snow_immune: Array = ["Overcoat", "Snow Cloak"]
	for ab in abilities:
		var ab_name: String = str(ab)
		var mon: Dictionary = _mon("Pidgey", ["normal"], ["Tackle"], {"ability": ab_name})
		var sand_got: bool = AbilityEngine.is_immune_to_weather_damage(mon, "sand")
		var sand_want: bool = ab_name in sand_immune
		if sand_got != sand_want:
			print("  is_immune_to_weather_damage(%s, sand) was %s, wanted %s." % [ab_name, str(sand_got), str(sand_want)])
			return false
		var snow_got: bool = AbilityEngine.is_immune_to_weather_damage(mon, "snow")
		var snow_want: bool = ab_name in snow_immune
		if snow_got != snow_want:
			print("  is_immune_to_weather_damage(%s, snow) was %s, wanted %s." % [ab_name, str(snow_got), str(snow_want)])
			return false
		if AbilityEngine.is_immune_to_weather_damage(mon, "rain"):
			print("  is_immune_to_weather_damage(%s, rain) was true; the helper only answers for damage weather." % ab_name)
			return false
		if AbilityEngine.is_immune_to_weather_damage(mon, "sun"):
			print("  is_immune_to_weather_damage(%s, sun) was true; the helper only answers for damage weather." % ab_name)
			return false
	return true


## Storm Drain draws a single-target Water move in doubles: the
## Scald aimed at the plain foe in enemy slot 0 is redirected to
## the Storm Drain mon in enemy slot 1, which takes no damage and
## gains +1 Sp. Atk, while the plain foe is never hit.
func test_storm_drain_redirect_doubles() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Blastoise", ["water"], ["Scald"], {"spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Gastrodon", ["water", "ground"], ["Scald"], {"ability": "Storm Drain"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var scald: Dictionary = {"name": "Scald", "type": "Water", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(scald, 0, "player", view)
	if targets.size() != 1:
		print("  Storm Drain redirect gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 1:
		print("  Storm Drain redirect went to %s slot %s, wanted enemy slot 1." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Scald", true, 0, logs, {})
	if int(e2.get("hp", 0)) != 100:
		print("  Storm Drain mon took damage: hp %s, wanted 100." % str(e2.get("hp", 0)))
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 1:
		print("  Storm Drain mon Sp. Atk stages = %s, wanted +1." % str(e2_stages.get("spa", -9)))
		return false
	if int(e1.get("hp", 0)) != 100:
		print("  plain foe took damage: hp %s, wanted 100." % str(e1.get("hp", 0)))
		return false
	# Wrong type does not draw: an Electric move aimed at the
	# plain foe stays on it when the other foe has Storm Drain.
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var bolt_targets: Array = DoublesTargeting.resolve_targets(bolt, 0, "player", view)
	if bolt_targets.size() != 1:
		print("  Thunderbolt vs Storm Drain gave %s targets, wanted 1." % str(bolt_targets.size()))
		return false
	var b0: Dictionary = bolt_targets[0]
	if str(b0.get("side", "")) != "enemy" or int(b0.get("slot", -1)) != 0:
		print("  Thunderbolt was wrongly drawn to the Storm Drain mon.")
		return false
	return true


## Lightning Rod draws a single-target Electric move in doubles:
## the Thunderbolt aimed at the plain foe in enemy slot 0 is
## redirected to the Lightning Rod mon in enemy slot 1, which
## takes no damage and gains +1 Sp. Atk, while the plain foe is
## never hit.
func test_lightning_rod_redirect_doubles() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(bolt, 0, "player", view)
	if targets.size() != 1:
		print("  Lightning Rod redirect gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 1:
		print("  Lightning Rod redirect went to %s slot %s, wanted enemy slot 1." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Thunderbolt", true, 0, logs, {})
	if int(e2.get("hp", 0)) != 100:
		print("  Lightning Rod mon took damage: hp %s, wanted 100." % str(e2.get("hp", 0)))
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 1:
		print("  Lightning Rod mon Sp. Atk stages = %s, wanted +1." % str(e2_stages.get("spa", -9)))
		return false
	if int(e1.get("hp", 0)) != 100:
		print("  plain foe took damage: hp %s, wanted 100." % str(e1.get("hp", 0)))
		return false
	return true


## Propeller Tail marks the move so it cannot be redirected: the
## Scald stays on the plain foe in enemy slot 0, which takes the
## hit, and the Storm Drain mon gains no Sp. Atk.
func test_propeller_tail_ignores_redirect() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Bombirdier", ["flying", "dark"], ["Scald"], {"ability": "Propeller Tail", "spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Gastrodon", ["water", "ground"], ["Scald"], {"ability": "Storm Drain"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var move: Dictionary = {"name": "Scald", "type": "Water", "target": "normal"}
	var logs: Array = []
	AbilityEngine.on_before_move(attacker, {}, move, c.field_state, logs)
	if not bool(move.get("ignores_redirection", false)):
		print("  Propeller Tail did not mark the move ignores_redirection.")
		return false
	var targets: Array = DoublesTargeting.resolve_targets(move, 0, "player", view)
	if targets.size() != 1:
		print("  Propeller Tail Scald gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  Propeller Tail Scald went to %s slot %s, wanted enemy slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs2: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Scald", true, 0, logs2, {})
	if int(e1.get("hp", 100)) >= 100:
		print("  plain foe took no damage from the Propeller Tail Scald.")
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 0:
		print("  Storm Drain mon Sp. Atk stages = %s, wanted 0." % str(e2_stages.get("spa", -9)))
		return false
	return true


## Stalwart marks the move so it cannot be redirected: the
## Thunderbolt stays on the plain foe in enemy slot 0, which
## takes the hit, and the Lightning Rod mon gains no Sp. Atk.
func test_stalwart_ignores_redirect() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Duraludon", ["steel", "dragon"], ["Thunderbolt"], {"ability": "Stalwart", "spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var move: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var logs: Array = []
	AbilityEngine.on_before_move(attacker, {}, move, c.field_state, logs)
	if not bool(move.get("ignores_redirection", false)):
		print("  Stalwart did not mark the move ignores_redirection.")
		return false
	var targets: Array = DoublesTargeting.resolve_targets(move, 0, "player", view)
	if targets.size() != 1:
		print("  Stalwart Thunderbolt gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  Stalwart Thunderbolt went to %s slot %s, wanted enemy slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs2: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Thunderbolt", true, 0, logs2, {})
	if int(e1.get("hp", 100)) >= 100:
		print("  plain foe took no damage from the Stalwart Thunderbolt.")
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 0:
		print("  Lightning Rod mon Sp. Atk stages = %s, wanted 0." % str(e2_stages.get("spa", -9)))
		return false
	return true


## Sweet Veil ally half: in doubles a mon cannot fall asleep
## when its ally has Sweet Veil, and the holder itself still
## cannot fall asleep either. End to end, a foe's Spore aimed
## at the sleeper leaves it awake.
## Note: the spec suggested an override dict for the Spore use,
## but Spore is in the runtime move list with status SLP and
## acc 100, so the test uses the real move name instead.
func test_sweet_veil_ally_blocks_sleep_doubles() -> bool:
	var c: BattleController = _new_controller()
	var sleeper: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var veiler: Dictionary = _mon("Ribombee", ["bug", "fairy"], ["Tackle"], {"ability": "Sweet Veil"})
	var foe: Dictionary = _mon("Amoonguss", ["grass", "poison"], ["Spore"])
	c.start_battle([sleeper, veiler], [foe, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	var logs: Array = []
	if AbilityEngine.try_set_status(sleeper, "SLP", foe, c.field_state, logs):
		print("  Sweet Veil ally fell asleep through try_set_status.")
		return false
	if str(sleeper.get("status", "?")) != "":
		print("  Sweet Veil ally status = '%s', wanted empty." % str(sleeper.get("status", "?")))
		return false
	var logs2: Array = []
	if AbilityEngine.try_set_status(veiler, "SLP", foe, c.field_state, logs2):
		print("  Sweet Veil holder fell asleep through try_set_status.")
		return false
	if str(veiler.get("status", "?")) != "":
		print("  Sweet Veil holder status = '%s', wanted empty." % str(veiler.get("status", "?")))
		return false
	# End to end: the foe's Spore is aimed at the sleeper.
	var view: Dictionary = c._doubles_field_view()
	var spore: Dictionary = {"name": "Spore", "type": "Grass", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(spore, 0, "enemy", view)
	if targets.size() != 1:
		print("  Spore gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "player" or int(t0.get("slot", -1)) != 0:
		print("  Spore went to %s slot %s, wanted player slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs3: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(foe, targets, "Spore", false, 0, logs3)
	if str(sleeper.get("status", "?")) != "":
		print("  Sweet Veil ally fell asleep to Spore: status '%s'." % str(sleeper.get("status", "?")))
		return false
	return true


## Sweet Veil ally half must not leak into singles: with no ally
## key at all, sleep still works and lasts 2 to 4 turns.
func test_sweet_veil_no_ally_sleep_singles() -> bool:
	var c: BattleController = _new_controller()
	var sleeper: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var foe: Dictionary = _mon("Amoonguss", ["grass", "poison"], ["Spore"])
	c.start_battle([sleeper], [foe], "singles", true)
	if sleeper.has("ally"):
		print("  singles mon wrongly has an ally key.")
		return false
	var logs: Array = []
	if not AbilityEngine.try_set_status(sleeper, "SLP", foe, c.field_state, logs):
		print("  singles mon could not fall asleep.")
		return false
	if str(sleeper.get("status", "?")) != "SLP":
		print("  singles mon status = '%s', wanted SLP." % str(sleeper.get("status", "?")))
		return false
	var turns: int = int(sleeper.get("sleep_turns", -1))
	if turns < 2 or turns > 4:
		print("  sleep_turns = %s, wanted 2 to 4." % str(turns))
		return false
	return true


## Victory Star ally half: in doubles a mon's moves are 1.1x
## accurate when its ally has Victory Star, and 1.21x when both
## the mon itself and its ally have Victory Star. In singles,
## with no ally key, the multiplier is 1.0.
func test_victory_star_ally_accuracy_doubles() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var star_ally: Dictionary = _mon("Victini", ["psychic", "fire"], ["Tackle"], {"ability": "Victory Star"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([attacker, star_ally], [foe, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	var move: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "acc": 100}
	var ally_mult: float = AbilityEngine.accuracy_mult(attacker, foe, move, c.field_state)
	if not is_equal_approx(ally_mult, 1.1):
		print("  Victory Star ally accuracy = %s, wanted 1.1." % str(ally_mult))
		return false
	# Both holders on one side: the holder's own 1.1x and the
	# ally's 1.1x stack to 1.21x.
	attacker["ability"] = "Victory Star"
	var both_mult: float = AbilityEngine.accuracy_mult(attacker, foe, move, c.field_state)
	if not is_equal_approx(both_mult, 1.21):
		print("  double Victory Star accuracy = %s, wanted 1.21." % str(both_mult))
		return false
	# Singles: no ally key, no Victory Star, multiplier 1.0.
	var c2: BattleController = _new_controller()
	var solo: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([solo], [foe2], "singles", true)
	if solo.has("ally_ability"):
		print("  singles mon wrongly has an ally_ability key.")
		return false
	var solo_mult: float = AbilityEngine.accuracy_mult(solo, foe2, move, c2.field_state)
	if not is_equal_approx(solo_mult, 1.0):
		print("  singles accuracy = %s, wanted 1.0." % str(solo_mult))
		return false
	return true


## Mold Breaker skips the redirect: the Thunderbolt stays on the
## plain foe in enemy slot 0, which takes the hit.
func test_redirect_skipped_by_mold_breaker() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Haxorus", ["dragon"], ["Thunderbolt"], {"ability": "Mold Breaker", "spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(bolt, 0, "player", view)
	if targets.size() != 1:
		print("  Mold Breaker Thunderbolt gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  Mold Breaker Thunderbolt went to %s slot %s, wanted enemy slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Thunderbolt", true, 0, logs, {})
	if int(e1.get("hp", 100)) >= 100:
		print("  plain foe took no damage from the Mold Breaker Thunderbolt.")
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 0:
		print("  Lightning Rod mon Sp. Atk stages = %s, wanted 0." % str(e2_stages.get("spa", -9)))
		return false
	return true


## A spread Water move is never redirected: Surf aimed at both
## foes still returns both enemy slots, unchanged.
func test_spread_move_not_redirected() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Blastoise", ["water"], ["Surf"], {"spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Gastrodon", ["water", "ground"], ["Surf"], {"ability": "Storm Drain"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var surf: Dictionary = {"name": "Surf", "type": "Water", "target": "allAdjacentFoes"}
	var targets: Array = DoublesTargeting.resolve_targets(surf, 0, "player", view)
	if targets.size() != 2:
		print("  Surf gave %s targets, wanted 2." % str(targets.size()))
		return false
	if not DoublesTargeting.is_spread(surf):
		print("  Surf was not seen as a spread move.")
		return false
	var seen0: bool = false
	var seen1: bool = false
	for t in targets:
		var td: Dictionary = t
		if str(td.get("side", "")) == "enemy" and int(td.get("slot", -1)) == 0:
			seen0 = true
		if str(td.get("side", "")) == "enemy" and int(td.get("slot", -1)) == 1:
			seen1 = true
	if not seen0 or not seen1:
		print("  Surf targets did not cover both enemy slots.")
		return false
	return true


## A redirected Thunder Wave is blocked by Lightning Rod: the
## move is drawn to the Lightning Rod mon in enemy slot 1, the
## mon is not paralyzed, and it still gains +1 Sp. Atk.
func test_redirected_thunder_wave_blocked() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunder Wave"])
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Manectric", ["electric"], ["Thunder Wave"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var wave: Dictionary = {"name": "Thunder Wave", "type": "Electric", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(wave, 0, "player", view)
	if targets.size() != 1:
		print("  Thunder Wave redirect gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 1:
		print("  Thunder Wave went to %s slot %s, wanted enemy slot 1." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Thunder Wave", true, 0, logs)
	if str(e2.get("status", "?")) != "":
		print("  Lightning Rod mon was paralyzed: status '%s'." % str(e2.get("status", "?")))
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 1:
		print("  Lightning Rod mon Sp. Atk stages = %s, wanted +1." % str(e2_stages.get("spa", -9)))
		return false
	if int(e1.get("hp", 0)) != 100:
		print("  plain foe was wrongly hit: hp %s." % str(e1.get("hp", 0)))
		return false
	return true


## When both foes draw the same move, the lower slot wins: the
## player slot 1 attacker aims at enemy slot 1 by default, but
## with a Lightning Rod mon in both enemy slots the move goes to
## enemy slot 0. Same for Storm Drain and Water moves.
func test_redirect_both_foes_draw_lower_slot_wins() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var attacker2: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spa": 200})
	var e1: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	var e2: Dictionary = _mon("Raichu", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, attacker2], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(bolt, 1, "player", view)
	if targets.size() != 1:
		print("  double Lightning Rod redirect gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  double Lightning Rod redirect went to %s slot %s, wanted enemy slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var c2: BattleController = _new_controller()
	var p2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var p2b: Dictionary = _mon("Blastoise", ["water"], ["Scald"], {"spa": 200})
	var w1: Dictionary = _mon("Gastrodon", ["water", "ground"], ["Scald"], {"ability": "Storm Drain"})
	var w2: Dictionary = _mon("Swampert", ["water", "ground"], ["Scald"], {"ability": "Storm Drain"})
	c2.start_battle([p2, p2b], [w1, w2], "doubles")
	var view2: Dictionary = c2._doubles_field_view()
	var scald: Dictionary = {"name": "Scald", "type": "Water", "target": "normal"}
	var targets2: Array = DoublesTargeting.resolve_targets(scald, 1, "player", view2)
	if targets2.size() != 1:
		print("  double Storm Drain redirect gave %s targets, wanted 1." % str(targets2.size()))
		return false
	var u0: Dictionary = targets2[0]
	if str(u0.get("side", "")) != "enemy" or int(u0.get("slot", -1)) != 0:
		print("  double Storm Drain redirect went to %s slot %s, wanted enemy slot 0." % [str(u0.get("side", "")), str(u0.get("slot", -1))])
		return false
	return true


## A commanding Tatsugiri is never a redirect target: the Storm
## Drain mon in enemy slot 1 is skipped while it is commanding,
## so the Scald stays on the plain foe in enemy slot 0. Once the
## commanding flag is cleared, the same move is drawn to it.
## Note: the real Commander flow gives Tatsugiri the Commander
## ability, which draws nothing, so the commanding flag is set
## directly on a Storm Drain holder to exercise the guard.
func test_redirect_skips_commanding_tatsugiri() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Blastoise", ["water"], ["Scald"], {"spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Tatsugiri", ["dragon", "water"], ["Dragon Pulse"], {"ability": "Storm Drain", "commanding": true})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	if not bool(e2.get("commanding", false)):
		print("  commanding flag did not survive battle start.")
		return false
	var view: Dictionary = c._doubles_field_view()
	var scald: Dictionary = {"name": "Scald", "type": "Water", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(scald, 0, "player", view)
	if targets.size() != 1:
		print("  commanding redirect gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  Scald went to %s slot %s, wanted enemy slot 0 (commanding mon skipped)." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	# Control: with the flag cleared, the same move is drawn.
	e2["commanding"] = false
	var view2: Dictionary = c._doubles_field_view()
	var targets2: Array = DoublesTargeting.resolve_targets(scald, 0, "player", view2)
	if targets2.size() != 1:
		print("  control redirect gave %s targets, wanted 1." % str(targets2.size()))
		return false
	var u0: Dictionary = targets2[0]
	if str(u0.get("side", "")) != "enemy" or int(u0.get("slot", -1)) != 1:
		print("  control Scald went to %s slot %s, wanted enemy slot 1." % [str(u0.get("side", "")), str(u0.get("slot", -1))])
		return false
	return true


## Teravolt and Turboblaze skip the redirect just like Mold
## Breaker: the Thunderbolt stays on the plain foe in enemy
## slot 0, which takes the hit, and the Lightning Rod mon gains
## no Sp. Atk. The plain foe has 2000 HP on purpose: the
## Teravolt hit must not faint it, or the Turboblaze check below
## would fall through to the other foe for a different reason
## (no living mon in the aimed-at slot) instead of testing the
## redirect skip.
func test_redirect_skipped_by_teravolt_turboblaze() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Haxorus", ["dragon"], ["Thunderbolt"], {"ability": "Teravolt", "spa": 200})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	var e2: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	c.start_battle([attacker, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var view: Dictionary = c._doubles_field_view()
	var bolt: Dictionary = {"name": "Thunderbolt", "type": "Electric", "target": "normal"}
	var targets: Array = DoublesTargeting.resolve_targets(bolt, 0, "player", view)
	if targets.size() != 1:
		print("  Teravolt Thunderbolt gave %s targets, wanted 1." % str(targets.size()))
		return false
	var t0: Dictionary = targets[0]
	if str(t0.get("side", "")) != "enemy" or int(t0.get("slot", -1)) != 0:
		print("  Teravolt Thunderbolt went to %s slot %s, wanted enemy slot 0." % [str(t0.get("side", "")), str(t0.get("slot", -1))])
		return false
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(attacker, targets, "Thunderbolt", true, 0, logs, {})
	if int(e1.get("hp", 2000)) >= 2000:
		print("  plain foe took no damage from the Teravolt Thunderbolt.")
		return false
	var e2_stages: Dictionary = e2.get("stages", {})
	if int(e2_stages.get("spa", -9)) != 0:
		print("  Lightning Rod mon Sp. Atk stages = %s, wanted 0." % str(e2_stages.get("spa", -9)))
		return false
	# Turboblaze: same check at the targeting step.
	attacker["ability"] = "Turboblaze"
	var view2: Dictionary = c._doubles_field_view()
	var targets2: Array = DoublesTargeting.resolve_targets(bolt, 0, "player", view2)
	if targets2.size() != 1:
		print("  Turboblaze Thunderbolt gave %s targets, wanted 1." % str(targets2.size()))
		return false
	var u0: Dictionary = targets2[0]
	if str(u0.get("side", "")) != "enemy" or int(u0.get("slot", -1)) != 0:
		print("  Turboblaze Thunderbolt went to %s slot %s, wanted enemy slot 0." % [str(u0.get("side", "")), str(u0.get("slot", -1))])
		return false
	return true


## Regression guard for the found dispatcher bug: the old
## is_immune_by_ability called the v2 check first and returned
## at once, so the batch arms never fired and the Sp. Atk +1 of
## Lightning Rod and Storm Drain never happened, even on a direct
## hit with no redirect at all. A direct hit must give the +1
## through the normal path: directly through is_immune, through
## a Thunder Wave aimed straight at the Lightning Rod mon, and
## through a Thunderbolt aimed straight at it.
func test_lightning_rod_direct_hit_spa_boost() -> bool:
	# Direct dispatcher call: Lightning Rod and Storm Drain.
	var rod: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	if not AbilityEngine.is_immune_by_ability(rod, "Electric"):
		print("  is_immune did not block Electric for Lightning Rod.")
		return false
	var rod_stages: Dictionary = rod.get("stages", {})
	if int(rod_stages.get("spa", -9)) != 1:
		print("  direct Lightning Rod Sp. Atk stages = %s, wanted +1." % str(rod_stages.get("spa", -9)))
		return false
	var drain: Dictionary = _mon("Gastrodon", ["water", "ground"], ["Scald"], {"ability": "Storm Drain"})
	if not AbilityEngine.is_immune_by_ability(drain, "Water"):
		print("  is_immune did not block Water for Storm Drain.")
		return false
	var drain_stages: Dictionary = drain.get("stages", {})
	if int(drain_stages.get("spa", -9)) != 1:
		print("  direct Storm Drain Sp. Atk stages = %s, wanted +1." % str(drain_stages.get("spa", -9)))
		return false
	# Mold Breaker still bypasses it and gives no boost.
	var rod2: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	if AbilityEngine.is_immune_by_ability(rod2, "Electric", "Mold Breaker"):
		print("  Mold Breaker was wrongly blocked by Lightning Rod.")
		return false
	var rod2_stages: Dictionary = rod2.get("stages", {})
	if int(rod2_stages.get("spa", -9)) != 0:
		print("  Mold Breaker hit wrongly raised Sp. Atk to %s." % str(rod2_stages.get("spa", -9)))
		return false
	# End to end: Thunder Wave aimed straight at the Lightning
	# Rod mon in enemy slot 0 (no redirect involved).
	var c: BattleController = _new_controller()
	var waver: Dictionary = _mon("Pikachu", ["electric"], ["Thunder Wave"])
	var e1: Dictionary = _mon("Manectric", ["electric"], ["Thunder Wave"], {"ability": "Lightning Rod"})
	var e2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([waver, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [e1, e2], "doubles")
	var logs: Array = []
	c.rng.seed = 4242
	c._execute_move_doubles(waver, [{"side": "enemy", "slot": 0}], "Thunder Wave", true, 0, logs)
	if str(e1.get("status", "?")) != "":
		print("  direct Thunder Wave paralyzed the Lightning Rod mon: status '%s'." % str(e1.get("status", "?")))
		return false
	var e1_stages: Dictionary = e1.get("stages", {})
	if int(e1_stages.get("spa", -9)) != 1:
		print("  direct Thunder Wave Sp. Atk stages = %s, wanted +1." % str(e1_stages.get("spa", -9)))
		return false
	# End to end: Thunderbolt aimed straight at a Lightning Rod
	# mon in enemy slot 0 (no redirect involved).
	var c2: BattleController = _new_controller()
	var bolter: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"], {"spa": 200})
	var f1: Dictionary = _mon("Manectric", ["electric"], ["Thunderbolt"], {"ability": "Lightning Rod"})
	var f2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([bolter, _mon("Pidgey", ["normal", "flying"], ["Tackle"])], [f1, f2], "doubles")
	var logs2: Array = []
	c2.rng.seed = 4242
	c2._execute_move_doubles(bolter, [{"side": "enemy", "slot": 0}], "Thunderbolt", true, 0, logs2, {})
	if int(f1.get("hp", 0)) != 100:
		print("  direct Thunderbolt damaged the Lightning Rod mon: hp %s, wanted 100." % str(f1.get("hp", 0)))
		return false
	var f1_stages: Dictionary = f1.get("stages", {})
	if int(f1_stages.get("spa", -9)) != 1:
		print("  direct Thunderbolt Sp. Atk stages = %s, wanted +1." % str(f1_stages.get("spa", -9)))
		return false
	return true


## Teravolt Ground move hits a Levitate foe. Control: the same move
## from an attacker with no ability is blocked by Levitate.
func test_teravolt_levitate() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Zekrom", ["electric"], ["Earthquake"], {"ability": "Teravolt", "atk": 100})
	var defender: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {"ability": "Levitate", "hp": 500, "max_hp": 500})
	c.start_battle([attacker], [defender], "singles", true)
	var override: Dictionary = {"power": 100, "type": "Ground", "cat": "Physical", "acc": 100}
	var logs: Array = []
	var hp_before: int = int(defender.get("hp", 0))
	var out: Dictionary = c._execute_move(attacker, defender, "Earthquake", true, logs, override)
	if int(out.get("damage", 0)) <= 0:
		print("  Teravolt Earthquake did no damage to a Levitate foe.")
		return false
	if int(defender.get("hp", 0)) >= hp_before:
		print("  Teravolt Earthquake did not lower the Levitate foe's HP.")
		return false
	for line in logs:
		if str(line).contains("doesn't affect"):
			print("  Teravolt Earthquake wrongly logged that it doesn't affect the foe.")
			return false
	# Control: the same move from an attacker with no ability is blocked.
	var plain_attacker: Dictionary = _mon("Zekrom", ["electric"], ["Earthquake"], {"ability": "", "atk": 100})
	var plain_defender: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {"ability": "Levitate", "hp": 500, "max_hp": 500})
	var c2: BattleController = _new_controller()
	c2.start_battle([plain_attacker], [plain_defender], "singles", true)
	var logs2: Array = []
	var out2: Dictionary = c2._execute_move(plain_attacker, plain_defender, "Earthquake", true, logs2, override)
	if int(out2.get("damage", -1)) != 0:
		print("  plain Earthquake did %s damage to a Levitate foe, wanted 0." % str(out2.get("damage", -1)))
		return false
	var found_immune: bool = false
	for line in logs2:
		if str(line).contains("doesn't affect"):
			found_immune = true
	if not found_immune:
		print("  plain Earthquake against Levitate did not log that it doesn't affect the foe.")
		return false
	return true


## Turboblaze Ground move hits a Levitate foe. Control: the same move
## from an attacker with no ability is blocked by Levitate.
func test_turboblaze_levitate() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Reshiram", ["dragon", "fire"], ["Earthquake"], {"ability": "Turboblaze", "atk": 100})
	var defender: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {"ability": "Levitate", "hp": 500, "max_hp": 500})
	c.start_battle([attacker], [defender], "singles", true)
	var override: Dictionary = {"power": 100, "type": "Ground", "cat": "Physical", "acc": 100}
	var logs: Array = []
	var hp_before: int = int(defender.get("hp", 0))
	var out: Dictionary = c._execute_move(attacker, defender, "Earthquake", true, logs, override)
	if int(out.get("damage", 0)) <= 0:
		print("  Turboblaze Earthquake did no damage to a Levitate foe.")
		return false
	if int(defender.get("hp", 0)) >= hp_before:
		print("  Turboblaze Earthquake did not lower the Levitate foe's HP.")
		return false
	for line in logs:
		if str(line).contains("doesn't affect"):
			print("  Turboblaze Earthquake wrongly logged that it doesn't affect the foe.")
			return false
	# Control: the same move from an attacker with no ability is blocked.
	var plain_attacker: Dictionary = _mon("Reshiram", ["dragon", "fire"], ["Earthquake"], {"ability": "", "atk": 100})
	var plain_defender: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {"ability": "Levitate", "hp": 500, "max_hp": 500})
	var c2: BattleController = _new_controller()
	c2.start_battle([plain_attacker], [plain_defender], "singles", true)
	var logs2: Array = []
	var out2: Dictionary = c2._execute_move(plain_attacker, plain_defender, "Earthquake", true, logs2, override)
	if int(out2.get("damage", -1)) != 0:
		print("  plain Earthquake did %s damage to a Levitate foe, wanted 0." % str(out2.get("damage", -1)))
		return false
	var found_immune: bool = false
	for line in logs2:
		if str(line).contains("doesn't affect"):
			found_immune = true
	if not found_immune:
		print("  plain Earthquake against Levitate did not log that it doesn't affect the foe.")
		return false
	return true


## Teravolt ignores Filter, Battle Armor and Sturdy through the
## ignore_ability move flag. Direct modify_damage calls, no random roll.
func test_teravolt_ignores_filter_and_battle_armor() -> bool:
	var move_flag: Dictionary = {"power": 100, "cat": "Physical", "ignore_ability": true}
	var move_plain: Dictionary = {"power": 100, "cat": "Physical"}
	var attacker: Dictionary = {"ability": "Teravolt"}
	var plain_attacker: Dictionary = {"ability": ""}
	var filter_def: Dictionary = {"ability": "Filter", "hp": 100, "max_hp": 100}
	var armor_def: Dictionary = {"ability": "Battle Armor", "hp": 100, "max_hp": 100}
	var sturdy_def: Dictionary = {"ability": "Sturdy", "hp": 100, "max_hp": 100}
	# Filter cuts a super-effective hit to 0.75x; the flag ignores it.
	if AbilityEngine.modify_damage(attacker, filter_def, move_flag, 100, false, false, 2.0) != 100:
		print("  Teravolt with the ignore flag did not skip Filter.")
		return false
	if AbilityEngine.modify_damage(plain_attacker, filter_def, move_plain, 100, false, false, 2.0) != 75:
		print("  plain attacker against Filter did not take 75 damage.")
		return false
	# Battle Armor cancels a crit (2/3x); the flag ignores it.
	if AbilityEngine.modify_damage(attacker, armor_def, move_flag, 90, false, true, 1.0) != 90:
		print("  Teravolt with the ignore flag did not skip Battle Armor.")
		return false
	if AbilityEngine.modify_damage(plain_attacker, armor_def, move_plain, 90, false, true, 1.0) != 60:
		print("  plain attacker against Battle Armor did not take 60 damage.")
		return false
	# Sturdy caps a lethal hit at 1 HP left (999 -> 99); the flag ignores it.
	if AbilityEngine.modify_damage(attacker, sturdy_def, move_flag, 999, false, false, 1.0) != 999:
		print("  Teravolt with the ignore flag did not skip Sturdy.")
		return false
	if AbilityEngine.modify_damage(plain_attacker, sturdy_def, move_plain, 999, false, false, 1.0) != 99:
		print("  plain attacker against Sturdy did not take 99 damage.")
		return false
	return true


## Unaware attacker ignores the foe's Defense stages.
## Hand-worked numbers (level 50 Tackle, power 40, Normal vs Normal, STAB 1.5):
## base = ((2*50/5 + 2) * power * (atk/def)) / 50 + 2 = (22 * power * (atk/def)) / 50 + 2.
## Seed 777, first call: the crit roll draws 0.154417 (no crit, chance 1/24),
## then the random factor draws 0.863407 (Godot 4.7.2 RandomNumberGenerator).
## No stages (atk 100 / def 50): base = (22*40*2)/50 + 2 = 37.2;
##   damage = floor(37.2 * 1.5 * 0.863407) = floor(48.178) = 48.
## +2 Defense (def 50*2 = 100): base = (22*40*1)/50 + 2 = 19.6;
##   damage = floor(19.6 * 1.5 * 0.863407) = floor(25.384) = 25.
func test_unaware_attacker_ignores_def_stages() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var tackle: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100}
	var unaware: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"ability": "Unaware", "atk": 100})
	var plain_attacker: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"ability": "", "atk": 100})
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"def": 50})
	var boosted_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"def": 50, "stages": {"atk": 0, "def": 2, "spa": 0, "spd": 0, "spe": 0}})
	rng.seed = 777
	var d_unaware_boosted: int = int(PUWBattleEngine.calculate_damage(unaware, boosted_def, tackle, rng).get("damage", -1))
	rng.seed = 777
	var d_unaware_plain: int = int(PUWBattleEngine.calculate_damage(unaware, plain_def, tackle, rng).get("damage", -1))
	if d_unaware_boosted != d_unaware_plain:
		print("  Unaware damage changed with the foe's Defense stages: %s vs %s." % [str(d_unaware_boosted), str(d_unaware_plain)])
		return false
	if d_unaware_boosted != 48:
		print("  Unaware damage against a +2 Defense foe was %s, wanted 48." % str(d_unaware_boosted))
		return false
	rng.seed = 777
	var d_plain_boosted: int = int(PUWBattleEngine.calculate_damage(plain_attacker, boosted_def, tackle, rng).get("damage", -1))
	if d_plain_boosted != 25:
		print("  plain damage against a +2 Defense foe was %s, wanted 25." % str(d_plain_boosted))
		return false
	if not d_unaware_boosted > d_plain_boosted:
		print("  Unaware damage (%s) was not above plain damage (%s) against a +2 Defense foe." % [str(d_unaware_boosted), str(d_plain_boosted)])
		return false
	# Special sub-check: Psychic, power 90, spa 200 vs spd 50, no STAB.
	# No stages: base = (22*90*4)/50 + 2 = 160.4;
	#   damage = floor(160.4 * 0.863407) = floor(138.490) = 138.
	# +2 SpD (spd 50*2 = 100): base = (22*90*2)/50 + 2 = 81.2;
	#   damage = floor(81.2 * 0.863407) = floor(70.109) = 70.
	var psychic: Dictionary = {"name": "Psychic", "power": 90, "type": "Psychic", "cat": "Special", "acc": 100}
	var unaware_sp: Dictionary = _mon("Clefable", ["normal"], ["Psychic"], {"ability": "Unaware", "spa": 200})
	var plain_sp: Dictionary = _mon("Clefable", ["normal"], ["Psychic"], {"ability": "", "spa": 200})
	var plain_spd: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spd": 50})
	var boosted_spd: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spd": 50, "stages": {"atk": 0, "def": 0, "spa": 0, "spd": 2, "spe": 0}})
	rng.seed = 777
	var s_unaware_boosted: int = int(PUWBattleEngine.calculate_damage(unaware_sp, boosted_spd, psychic, rng).get("damage", -1))
	rng.seed = 777
	var s_unaware_plain: int = int(PUWBattleEngine.calculate_damage(unaware_sp, plain_spd, psychic, rng).get("damage", -1))
	if s_unaware_boosted != s_unaware_plain or s_unaware_boosted != 138:
		print("  Unaware special damage was %s vs plain %s, wanted 138 both." % [str(s_unaware_boosted), str(s_unaware_plain)])
		return false
	rng.seed = 777
	var s_plain_boosted: int = int(PUWBattleEngine.calculate_damage(plain_sp, boosted_spd, psychic, rng).get("damage", -1))
	if s_plain_boosted != 70:
		print("  plain special damage against a +2 SpD foe was %s, wanted 70." % str(s_plain_boosted))
		return false
	if not s_unaware_boosted > s_plain_boosted:
		print("  Unaware special damage (%s) was not above plain (%s)." % [str(s_unaware_boosted), str(s_plain_boosted)])
		return false
	return true


## Unaware defender ignores the foe's Attack stages.
## Same hand-worked numbers as test_unaware_attacker_ignores_def_stages:
## seed 777 gives no crit and a random factor of 0.863407.
## Plain (atk 100 / def 50): base 37.2, damage floor(37.2 * 1.5 * 0.863407) = 48.
## +2 Attack (atk 100*2 = 200 / def 50): base = (22*40*4)/50 + 2 = 72.4;
##   damage = floor(72.4 * 1.5 * 0.863407) = floor(93.766) = 93.
func test_unaware_defender_ignores_atk_stages() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var tackle: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100}
	var boosted_attacker: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"ability": "", "atk": 100, "stages": {"atk": 2, "def": 0, "spa": 0, "spd": 0, "spe": 0}})
	var plain_attacker: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"ability": "", "atk": 100})
	var unaware_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Unaware", "def": 50})
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "", "def": 50})
	rng.seed = 777
	var d_unaware: int = int(PUWBattleEngine.calculate_damage(boosted_attacker, unaware_def, tackle, rng).get("damage", -1))
	rng.seed = 777
	var d_plain: int = int(PUWBattleEngine.calculate_damage(plain_attacker, plain_def, tackle, rng).get("damage", -1))
	if d_unaware != d_plain:
		print("  Unaware defender damage changed with the foe's Attack stages: %s vs %s." % [str(d_unaware), str(d_plain)])
		return false
	if d_unaware != 48:
		print("  Unaware defender damage against a +2 Attack foe was %s, wanted 48." % str(d_unaware))
		return false
	rng.seed = 777
	var d_no_unaware: int = int(PUWBattleEngine.calculate_damage(boosted_attacker, plain_def, tackle, rng).get("damage", -1))
	if d_no_unaware != 93:
		print("  plain defender damage against a +2 Attack foe was %s, wanted 93." % str(d_no_unaware))
		return false
	if not d_unaware < d_no_unaware:
		print("  Unaware defender damage (%s) was not below plain (%s) against a +2 Attack foe." % [str(d_unaware), str(d_no_unaware)])
		return false
	return true


## Shell Armor can never be critically hit, even with a guaranteed crit.
## Crit stage is 1 (high_crit) + 1 (critRatio) + 1 (Super Luck) = 3,
## so the crit chance is 1.0 (the table is [24, 8, 2, 1, 1]).
## DEVIATION from the spec: the spec's Teravolt control says "100 rolls
## all critical", but a Teravolt attacker has no Super Luck, so its crit
## stage is only 2 and the chance is 1/2 — all 100 cannot be critical.
## This test instead checks Teravolt crits do happen (count above 0),
## and checks all 100 critical with a Teravolt attacker plus an
## always_crit move, which is the guaranteed-crit case the flag must
## also let through. It also checks a guaranteed crit is still blocked
## without the flag.
func test_shell_armor_never_crits() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var attacker: Dictionary = _mon("Absol", ["dark"], ["Slash"], {"ability": "Super Luck", "atk": 100})
	var move: Dictionary = {"name": "Slash", "power": 70, "type": "Normal", "cat": "Physical", "acc": 100, "high_crit": true, "critRatio": 1}
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var armored_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Shell Armor"})
	for i in range(100):
		var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, plain_def, move, rng)
		if not bool(res.get("critical", false)):
			print("  a roll against a plain defender was not a crit, so the rig does not prove the block.")
			return false
	for i in range(100):
		var res2: Dictionary = PUWBattleEngine.calculate_damage(attacker, armored_def, move, rng)
		if bool(res2.get("critical", false)):
			print("  a roll against Shell Armor was a crit.")
			return false
	# Controller check: the real move never logs a critical hit.
	var c: BattleController = _new_controller()
	c.start_battle([attacker], [armored_def], "singles", true)
	c.rng.seed = 12345
	var logs: Array = []
	c._execute_move(attacker, armored_def, "Slash", true, logs, move)
	for line in logs:
		if str(line).contains("A critical hit!"):
			print("  the controller logged a critical hit against Shell Armor.")
			return false
	# Teravolt control: the move ignores abilities, so crits happen again.
	var teravolt: Dictionary = _mon("Absol", ["dark"], ["Slash"], {"ability": "Teravolt", "atk": 100})
	var crits: int = 0
	for i in range(100):
		var res3: Dictionary = PUWBattleEngine.calculate_damage(teravolt, armored_def, move, rng)
		if bool(res3.get("critical", false)):
			crits += 1
	if crits <= 0:
		print("  a Teravolt attacker never crit Shell Armor, but the flag should let crits through.")
		return false
	# Guaranteed crits: always_crit is blocked without the flag, and
	# lets through with a Teravolt attacker.
	var sure_move: Dictionary = {"name": "Slash", "power": 70, "type": "Normal", "cat": "Physical", "acc": 100, "high_crit": true, "critRatio": 1, "always_crit": true}
	for i in range(100):
		var res4: Dictionary = PUWBattleEngine.calculate_damage(attacker, armored_def, sure_move, rng)
		if bool(res4.get("critical", false)):
			print("  a guaranteed crit got through Shell Armor without the flag.")
			return false
	for i in range(100):
		var res5: Dictionary = PUWBattleEngine.calculate_damage(teravolt, armored_def, sure_move, rng)
		if not bool(res5.get("critical", false)):
			print("  a Teravolt guaranteed crit did not crit Shell Armor.")
			return false
	return true


## Battle Armor can never be critically hit, even with a guaranteed crit.
## Same rig as test_shell_armor_never_crits (crit stage 3, chance 1.0).
func test_battle_armor_never_crits() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var attacker: Dictionary = _mon("Absol", ["dark"], ["Slash"], {"ability": "Super Luck", "atk": 100})
	var move: Dictionary = {"name": "Slash", "power": 70, "type": "Normal", "cat": "Physical", "acc": 100, "high_crit": true, "critRatio": 1}
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var armored_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Battle Armor"})
	for i in range(100):
		var res: Dictionary = PUWBattleEngine.calculate_damage(attacker, plain_def, move, rng)
		if not bool(res.get("critical", false)):
			print("  a roll against a plain defender was not a crit, so the rig does not prove the block.")
			return false
	for i in range(100):
		var res2: Dictionary = PUWBattleEngine.calculate_damage(attacker, armored_def, move, rng)
		if bool(res2.get("critical", false)):
			print("  a roll against Battle Armor was a crit.")
			return false
	# Controller check: the real move never logs a critical hit.
	var c: BattleController = _new_controller()
	c.start_battle([attacker], [armored_def], "singles", true)
	c.rng.seed = 12345
	var logs: Array = []
	c._execute_move(attacker, armored_def, "Slash", true, logs, move)
	for line in logs:
		if str(line).contains("A critical hit!"):
			print("  the controller logged a critical hit against Battle Armor.")
			return false
	return true


## Stall moves last in its own priority bracket, whatever the Speeds are.
func test_stall_moves_last() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var stall_mon: Dictionary = _mon("Sableye", ["dark", "ghost"], ["Tackle"], {"ability": "Stall", "spe": 200})
	var slow_mon: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"spe": 30})
	var normal_move: Dictionary = {"priority": 0}
	var order: Array = TurnResolver.resolve_order(stall_mon, normal_move, slow_mon, normal_move, field)
	if order != ["enemy", "player"]:
		print("  the faster Stall mon did not go last.")
		return false
	# Same result when the flag is set by hand instead of the ability.
	var flagged: Dictionary = _mon("Sableye", ["dark", "ghost"], ["Tackle"], {"ability": "", "spe": 200})
	flagged["moves_last"] = true
	order = TurnResolver.resolve_order(flagged, normal_move, slow_mon, normal_move, field)
	if order != ["enemy", "player"]:
		print("  the moves_last flag did not put the faster mon last.")
		return false
	# Priority still wins: a +1 priority move from the Stall mon goes first.
	var quick_move: Dictionary = {"priority": 1}
	order = TurnResolver.resolve_order(stall_mon, quick_move, slow_mon, normal_move, field)
	if order != ["player", "enemy"]:
		print("  a +1 priority move from the Stall mon did not go first.")
		return false
	# Trick Room still keeps Stall last.
	var trick_field: Dictionary = StatusAndFieldEngine.create_field_state()
	trick_field["trick_room"] = 5
	order = TurnResolver.resolve_order(stall_mon, normal_move, slow_mon, normal_move, trick_field)
	if order != ["enemy", "player"]:
		print("  Trick Room did not keep the Stall mon last.")
		return false
	# Doubles: the fastest mon has Stall, so it acts last of the four.
	var combatant1: Dictionary = {"mon": stall_mon, "move": {"priority": 0}, "side": "player", "slot": 0, "action": {}}
	var combatant2: Dictionary = {"mon": _mon("Jolteon", ["electric"], ["Tackle"], {"spe": 120}), "move": {"priority": 0}, "side": "enemy", "slot": 0, "action": {}}
	var combatant3: Dictionary = {"mon": _mon("Pidgey", ["normal", "flying"], ["Tackle"], {"spe": 90}), "move": {"priority": 0}, "side": "player", "slot": 1, "action": {}}
	var combatant4: Dictionary = {"mon": _mon("Snorlax", ["normal"], ["Tackle"], {"spe": 50}), "move": {"priority": 0}, "side": "enemy", "slot": 1, "action": {}}
	var ordered: Array = TurnResolver.resolve_order_4([combatant1, combatant2, combatant3, combatant4], field)
	var names: Array = []
	for combatant in ordered:
		var cm: Dictionary = combatant.get("mon", {})
		names.append(str(cm.get("name", "?")))
	if names != ["Jolteon", "Pidgey", "Snorlax", "Sableye"]:
		print("  doubles order was %s, wanted Jolteon, Pidgey, Snorlax, Sableye." % str(names))
		return false
	return true


## Parental Bond: the second hit deals 1/4 damage in singles.
## Expected total comes from a fresh rng with seed 777 calling
## calculate_damage twice with the same attacker, defender and move:
## total = d1 + maxi(1, d2 / 4).
func test_parental_bond_second_hit_quarter() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Kangaskhan", ["normal"], ["Tackle"], {"ability": "Parental Bond", "atk": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	c.start_battle([attacker], [defender], "singles", true)
	var move: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100}
	var expect_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expect_rng.seed = 777
	var d1: int = int(PUWBattleEngine.calculate_damage(attacker, defender, move, expect_rng).get("damage", -1))
	var d2: int = int(PUWBattleEngine.calculate_damage(attacker, defender, move, expect_rng).get("damage", -1))
	var expected: int = d1 + maxi(1, d2 / 4)
	c.rng.seed = 777
	var logs: Array = []
	var hp_before: int = int(defender.get("hp", 0))
	var out: Dictionary = c._execute_move(attacker, defender, "Tackle", true, logs, move)
	var total: int = int(out.get("damage", -1))
	if total != expected:
		print("  Parental Bond total was %s, wanted %s (d1 %s, d2 %s)." % [str(total), str(expected), str(d1), str(d2)])
		return false
	if hp_before - int(defender.get("hp", 0)) != total:
		print("  defender HP loss did not match the Parental Bond total.")
		return false
	var found_twice: bool = false
	for line in logs:
		if str(line).contains("hit 2 times"):
			found_twice = true
	if not found_twice:
		print("  Parental Bond did not log that it hit 2 times.")
		return false
	# Control: no Parental Bond means one hit, total == d1, no log line.
	var plain_attacker: Dictionary = _mon("Kangaskhan", ["normal"], ["Tackle"], {"ability": "", "atk": 100})
	var plain_defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	var c2: BattleController = _new_controller()
	c2.start_battle([plain_attacker], [plain_defender], "singles", true)
	var expect2: RandomNumberGenerator = RandomNumberGenerator.new()
	expect2.seed = 777
	var d1_plain: int = int(PUWBattleEngine.calculate_damage(plain_attacker, plain_defender, move, expect2).get("damage", -1))
	c2.rng.seed = 777
	var logs2: Array = []
	var out2: Dictionary = c2._execute_move(plain_attacker, plain_defender, "Tackle", true, logs2, move)
	if int(out2.get("damage", -1)) != d1_plain:
		print("  plain Tackle total was %s, wanted single-hit %s." % [str(out2.get("damage", -1)), str(d1_plain)])
		return false
	for line in logs2:
		if str(line).contains("hit 2 times"):
			print("  a plain attacker wrongly logged that it hit 2 times.")
			return false
	return true


## Parental Bond: the second hit deals 1/4 damage in doubles, per target.
## The override carries the mark by hand here because this test calls
## the execute function directly; the carry from before_move is tested
## separately in test_parental_bond_mark_reaches_doubles.
func test_parental_bond_doubles_second_hit_quarter() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Kangaskhan", ["normal"], ["Tackle"], {"ability": "Parental Bond", "atk": 100})
	var filler: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var foe1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	c.start_battle([attacker, filler], [foe1, foe2], "doubles")
	var move: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100}
	var override: Dictionary = {"power": 40, "type": "Normal", "cat": "Physical", "acc": 100, "multihit": 2, "multihit_type": "parentalbond"}
	var targets: Array = [{"side": "enemy", "slot": 0}, {"side": "enemy", "slot": 1}]
	var expect_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expect_rng.seed = 777
	var d1a: int = int(PUWBattleEngine.calculate_damage(attacker, foe1, move, expect_rng).get("damage", -1))
	var d2a: int = int(PUWBattleEngine.calculate_damage(attacker, foe1, move, expect_rng).get("damage", -1))
	var d1b: int = int(PUWBattleEngine.calculate_damage(attacker, foe2, move, expect_rng).get("damage", -1))
	var d2b: int = int(PUWBattleEngine.calculate_damage(attacker, foe2, move, expect_rng).get("damage", -1))
	var expected1: int = d1a + maxi(1, d2a / 4)
	var expected2: int = d1b + maxi(1, d2b / 4)
	c.rng.seed = 777
	var logs: Array = []
	var out: Dictionary = c._execute_move_doubles(attacker, targets, "Tackle", true, 0, logs, override)
	var loss1: int = 2000 - int(foe1.get("hp", 0))
	var loss2: int = 2000 - int(foe2.get("hp", 0))
	if loss1 != expected1:
		print("  foe 1 lost %s HP, wanted %s (d1 %s, d2 %s)." % [str(loss1), str(expected1), str(d1a), str(d2a)])
		return false
	if loss2 != expected2:
		print("  foe 2 lost %s HP, wanted %s (d1 %s, d2 %s)." % [str(loss2), str(expected2), str(d1b), str(d2b)])
		return false
	if int(out.get("damage", -1)) != expected1 + expected2:
		print("  doubles total damage was %s, wanted %s." % [str(out.get("damage", -1)), str(expected1 + expected2)])
		return false
	return true


## Pressure costs the move 1 extra PP: 2 PP in total, 1 extra even with
## two Pressure targets, allies with Pressure cost nothing, and PP
## never goes below 0.
func test_pressure_costs_2_pp() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"pp": {"Tackle": 5}, "moves": ["Tackle"]})
	var defender: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "Pressure", "hp": 500, "max_hp": 500})
	# Direct call: 5 PP falls to 3 against one Pressure foe.
	if not c._deduct_pp(attacker, {"name": "Tackle"}, [defender]):
		print("  _deduct_pp failed with 5 PP against Pressure.")
		return false
	var pp_map: Dictionary = attacker.get("pp", {})
	if int(pp_map.get("Tackle", -1)) != 3:
		print("  PP against Pressure was %s, wanted 3." % str(pp_map.get("Tackle", -1)))
		return false
	# Through the real move: a fresh 5 PP also falls to 3.
	c.start_battle([attacker], [defender], "singles", true)
	attacker["pp"] = {"Tackle": 5}
	var logs: Array = []
	c._execute_move(attacker, defender, "Tackle", true, logs, {"power": 40, "type": "Normal", "cat": "Physical", "acc": 100})
	pp_map = attacker.get("pp", {})
	if int(pp_map.get("Tackle", -1)) != 3:
		print("  PP after a real Tackle against Pressure was %s, wanted 3." % str(pp_map.get("Tackle", -1)))
		return false
	# Edge: 1 PP left still works against Pressure and is empty after.
	attacker["pp"] = {"Tackle": 1}
	if not c._deduct_pp(attacker, {"name": "Tackle"}, [defender]):
		print("  _deduct_pp failed with 1 PP left against Pressure.")
		return false
	pp_map = attacker.get("pp", {})
	if int(pp_map.get("Tackle", -1)) != 0:
		print("  PP after the last use against Pressure was %s, wanted 0." % str(pp_map.get("Tackle", -1)))
		return false
	if c._deduct_pp(attacker, {"name": "Tackle"}, [defender]):
		print("  _deduct_pp succeeded with 0 PP left.")
		return false
	# Control: no Pressure costs 1 PP (5 to 4).
	var plain_def: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "", "hp": 500, "max_hp": 500})
	attacker["pp"] = {"Tackle": 5}
	if not c._deduct_pp(attacker, {"name": "Tackle"}, [plain_def]):
		print("  _deduct_pp failed with 5 PP and no Pressure.")
		return false
	pp_map = attacker.get("pp", {})
	if int(pp_map.get("Tackle", -1)) != 4:
		print("  PP with no Pressure was %s, wanted 4." % str(pp_map.get("Tackle", -1)))
		return false
	# Doubles: two foe targets both with Pressure still cost 2 PP in
	# total (5 to 3, not 5 to 1).
	var c2: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"pp": {"Tackle": 5}, "moves": ["Tackle"]})
	var ally2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var foe_a: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "Pressure", "hp": 500, "max_hp": 500})
	var foe_b: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "Pressure", "hp": 500, "max_hp": 500})
	c2.start_battle([attacker2, ally2], [foe_a, foe_b], "doubles")
	c2.rng.seed = 777
	var logs2: Array = []
	var targets2: Array = [{"side": "enemy", "slot": 0}, {"side": "enemy", "slot": 1}]
	c2._execute_move_doubles(attacker2, targets2, "Tackle", true, 0, logs2, {"power": 40, "type": "Normal", "cat": "Physical", "acc": 100})
	var pp2: Dictionary = attacker2.get("pp", {})
	if int(pp2.get("Tackle", -1)) != 3:
		print("  PP against two Pressure foes in doubles was %s, wanted 3." % str(pp2.get("Tackle", -1)))
		return false
	# Doubles: an ally with Pressure plus a foe without costs 1 PP (5 to 4).
	var c3: BattleController = _new_controller()
	var attacker3: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"pp": {"Tackle": 5}, "moves": ["Tackle"]})
	var ally3: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "Pressure", "hp": 500, "max_hp": 500})
	var foe3: Dictionary = _mon("Zapdos", ["electric", "flying"], ["Tackle"], {"ability": "", "hp": 500, "max_hp": 500})
	var foe3b: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c3.start_battle([attacker3, ally3], [foe3, foe3b], "doubles")
	c3.rng.seed = 777
	var logs3: Array = []
	var targets3: Array = [{"side": "player", "slot": 1}, {"side": "enemy", "slot": 0}]
	c3._execute_move_doubles(attacker3, targets3, "Tackle", true, 0, logs3, {"power": 40, "type": "Normal", "cat": "Physical", "acc": 100})
	var pp3: Dictionary = attacker3.get("pp", {})
	if int(pp3.get("Tackle", -1)) != 4:
		print("  PP with an ally Pressure target was %s, wanted 4." % str(pp3.get("Tackle", -1)))
		return false
	return true


## Stat stages now change damage (Patch E): the +2 Attack stage a
## Swords Dance gives raises damage, and a -1 stage lowers it. This is
## the proof the stage maths runs at all — before the fix the
## calculator never read "stages", so stages changed nothing.
## Hand-worked numbers (level 50 Tackle, power 40, Normal vs Normal, STAB 1.5):
## base = ((2*50/5 + 2) * power * (atk/def)) / 50 + 2 = (22 * power * (atk/def)) / 50 + 2.
## Seed 777, first call: the crit roll draws 0.154417 (no crit, chance 1/24),
## then the random factor draws 0.863407 (Godot 4.7.2 RandomNumberGenerator,
## checked by running a probe script on the same version).
## Stage table (Showdown): +n stages multiply the stat by (2+n)/2,
## -n stages multiply it by 2/(2+n).
## Plain (atk 100 / def 50): base = (22*40*2)/50 + 2 = 37.2;
##   damage = floor(37.2 * 1.5 * 0.863407) = floor(48.178) = 48.
## +2 Attack (atk 100*2 = 200 / def 50): base = (22*40*4)/50 + 2 = 72.4;
##   damage = floor(72.4 * 1.5 * 0.863407) = floor(93.766) = 93.
## -1 Attack (atk 100*2/3 = 66.67 / def 50): base = (22*40*1.3333)/50 + 2 = 25.4667;
##   damage = floor(25.4667 * 1.5 * 0.863407) = floor(32.982) = 32.
func test_stage_application() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var tackle: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100}
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"def": 50})
	var plain: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"atk": 100})
	var boosted: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"atk": 100, "stages": {"atk": 2, "def": 0, "spa": 0, "spd": 0, "spe": 0}})
	var lowered: Dictionary = _mon("Clefable", ["normal"], ["Tackle"], {"atk": 100, "stages": {"atk": -1, "def": 0, "spa": 0, "spd": 0, "spe": 0}})
	rng.seed = 777
	var d_plain: int = int(PUWBattleEngine.calculate_damage(plain, defender, tackle, rng).get("damage", -1))
	rng.seed = 777
	var d_boosted: int = int(PUWBattleEngine.calculate_damage(boosted, defender, tackle, rng).get("damage", -1))
	rng.seed = 777
	var d_lowered: int = int(PUWBattleEngine.calculate_damage(lowered, defender, tackle, rng).get("damage", -1))
	if d_plain != 48:
		print("  plain Tackle damage was %s, wanted 48." % str(d_plain))
		return false
	if d_boosted != 93:
		print("  +2 Attack Tackle damage was %s, wanted 93." % str(d_boosted))
		return false
	if d_lowered != 32:
		print("  -1 Attack Tackle damage was %s, wanted 32." % str(d_lowered))
		return false
	if not (d_boosted > d_plain and d_plain > d_lowered):
		print("  stage order wrong: boosted %s, plain %s, lowered %s." % [str(d_boosted), str(d_plain), str(d_lowered)])
		return false
	return true


## Mold Breaker still works: the old name path is not broken by the
## new ignore_ability flag.
func test_mold_breaker_still_works() -> bool:
	if AbilityEngine.is_immune_by_ability({"ability": "Levitate"}, "Ground", "Mold Breaker"):
		print("  Mold Breaker did not bypass Levitate.")
		return false
	if not AbilityEngine.is_immune_by_ability({"ability": "Levitate"}, "Ground", ""):
		print("  Levitate did not block a Ground move from a plain attacker.")
		return false
	var sturdy_def: Dictionary = {"ability": "Sturdy", "hp": 100, "max_hp": 100}
	var result: int = AbilityEngine.modify_damage({"ability": "Mold Breaker"}, sturdy_def, {}, 999, false, false, 1.0)
	if result != 999:
		print("  Mold Breaker against Sturdy capped damage at %s, wanted 999." % str(result))
		return false
	return true


## Teravolt ignores Clear Body through _apply_stages: a Growl drop
## goes through. The move passed here carries the flag by hand because
## this test calls _apply_stages directly instead of going through
## _execute_move.
## DEVIATION from the spec: the spec's note says a Teravolt attacker
## with move {} would still drop it, but that is not true in the
## patched code — blocks_stat_change only applies the ignore rule
## when the move is non-empty (ability_engine.gd line 1059:
## "not move.is_empty() and move_ignores_ability(...)"), so with an
## empty move Clear Body still blocks. This test asserts that real
## behaviour instead: Teravolt with an empty move is blocked.
func test_teravolt_ignores_clear_body() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var growl_flag: Dictionary = {"name": "Growl", "ignore_ability": true}
	var teravolt: Dictionary = _mon("Zekrom", ["electric"], ["Growl"], {"ability": "Teravolt"})
	var plain: Dictionary = _mon("Zekrom", ["electric"], ["Growl"], {"ability": ""})
	var defender1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Clear Body"})
	var logs: Array = []
	c._apply_stages(defender1, {"atk": -1}, logs, teravolt, field, teravolt, growl_flag)
	var stages1: Dictionary = defender1.get("stages", {})
	if int(stages1.get("atk", 0)) != -1:
		print("  Teravolt Growl did not drop a Clear Body foe's Attack to -1 (got %s)." % str(stages1.get("atk", 0)))
		return false
	# Control: a plain attacker with no flag is blocked by Clear Body.
	var defender2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Clear Body"})
	var logs2: Array = []
	c._apply_stages(defender2, {"atk": -1}, logs2, plain, field, plain, {})
	var stages2: Dictionary = defender2.get("stages", {})
	if int(stages2.get("atk", -9)) != 0:
		print("  plain Growl dropped a Clear Body foe's Attack to %s, wanted 0." % str(stages2.get("atk", -9)))
		return false
	# Teravolt with an empty move is still blocked: blocks_stat_change
	# only honours the ignore rule for a non-empty move (see note above).
	var defender3: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Clear Body"})
	var logs3: Array = []
	c._apply_stages(defender3, {"atk": -1}, logs3, teravolt, field, teravolt, {})
	var stages3: Dictionary = defender3.get("stages", {})
	if int(stages3.get("atk", -9)) != 0:
		print("  Teravolt Growl with an empty move dropped a Clear Body foe's Attack to %s, wanted 0." % str(stages3.get("atk", -9)))
		return false
	return true


## The Parental Bond multihit mark set by before_move survives into
## _execute_move_doubles (Patch J1): the log says the move hit 2 times.
func test_parental_bond_mark_reaches_doubles() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Kangaskhan", ["normal"], ["Tackle"], {"ability": "Parental Bond", "atk": 100})
	var filler: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var foe1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([attacker, filler], [foe1, foe2], "doubles")
	c.rng.seed = 777
	var logs: Array = []
	c._perform_action_doubles({"type": "move", "move_name": "Tackle"}, true, 0, logs)
	var found_twice: bool = false
	for line in logs:
		if str(line).contains("hit 2 times"):
			found_twice = true
	if not found_twice:
		print("  Parental Bond in doubles did not log that it hit 2 times.")
		return false
	if int(foe1.get("hp", 500)) >= 500:
		print("  the Parental Bond doubles move did no damage to foe 1.")
		return false
	return true


## ------------------------------------------------------------------
## Group D tests — controller caller flags (Neutralizing Gas,
## Opportunist, Stakeout, Steadfast, Supreme Overlord, Tangled Feet,
## Screen Cleaner, Unnerve, Wimp Out, Toxic Debris, Rebound, As One).
## ------------------------------------------------------------------

## Neutralizing Gas: Intimidate is suppressed while the Gas holder
## is out, and works again once the Gas holder leaves (the field
## flag syncs on the switch).
func test_neutralizing_gas_suppresses_and_restores() -> bool:
	var c: BattleController = _new_controller()
	var koffing: Dictionary = _mon("Koffing", ["poison"], ["Sludge Bomb"], {"ability": "Neutralizing Gas"})
	var pidgey: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var rattata: Dictionary = _mon("Rattata", ["normal"], ["Tackle"])
	var gyarados: Dictionary = _mon("Gyarados", ["water", "flying"], ["Surf"], {"ability": "Intimidate"})
	c.start_battle([koffing, pidgey], [rattata, gyarados], "singles")
	if not bool(c.field_state.get("abilities_suppressed", false)):
		print("  Neutralizing Gas did not set abilities_suppressed at battle start.")
		return false
	# The Gas holder stays active while Gyarados switches in.
	c.execute_switch(c.enemy_party, 1, c.player_party[0], false)
	var koffing_stages: Dictionary = c.player_party[0].get("stages", {})
	if int(koffing_stages.get("atk", -9)) != 0:
		print("  Intimidate lowered Koffing's Attack to %s under Neutralizing Gas." % str(koffing_stages.get("atk", -9)))
		return false
	if not bool(c.field_state.get("abilities_suppressed", false)):
		print("  abilities_suppressed cleared while the Gas holder was still out.")
		return false
	# The Gas holder leaves: the flag clears.
	c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	if bool(c.field_state.get("abilities_suppressed", false)):
		print("  abilities_suppressed stayed on after the Gas holder switched out.")
		return false
	# Gyarados is the enemy lead now. Its Intimidate fires again
	# once the flag is gone.
	AbilityEngine.on_switch_in(c.enemy_party[0], c.player_party[0], c.field_state)
	var pidgey_stages: Dictionary = c.player_party[0].get("stages", {})
	if int(pidgey_stages.get("atk", -9)) != -1:
		print("  Intimidate did not lower Pidgey's Attack to -1 after the Gas left (got %s)." % str(pidgey_stages.get("atk", -9)))
		return false
	return true


## Opportunist copies a foe's self-boost through the secondary
## boost path (MoveEffects._apply_boosts), not just Swords Dance.
func test_opportunist_copies_secondary_boost() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Oricorio", ["fire", "flying"], ["Quick Attack"], {"ability": "Opportunist"})
	var foe: Dictionary = _mon("Scizor", ["bug", "steel"], ["Swords Dance"])
	c.start_battle([holder], [foe], "singles")
	var logs: Array = []
	# A self-boost, like a secondary from the foe's own move:
	# is_self true, empty source, the controller field, the holder
	# as the other mon.
	MoveEffects._apply_boosts(c.enemy_party[0], {"atk": 1}, logs, true, {}, c.field_state, c.player_party[0])
	var foe_stages: Dictionary = c.enemy_party[0].get("stages", {})
	if int(foe_stages.get("atk", -9)) != 1:
		print("  foe Attack = %s, wanted 1." % str(foe_stages.get("atk", -9)))
		return false
	var holder_stages: Dictionary = c.player_party[0].get("stages", {})
	if int(holder_stages.get("atk", -9)) != 1:
		print("  Opportunist holder Attack = %s, wanted 1." % str(holder_stages.get("atk", -9)))
		return false
	return str(logs).contains("Opportunist")


## Stakeout: 2x power against a foe that switched in this turn,
## and the flag clears at the END of the turn, not the start.
func test_stakeout_turn1_and_after() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Kingambit", ["dark", "steel"], ["Quick Attack"], {"ability": "Stakeout"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	var bench: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([attacker], [defender, bench], "singles")
	if not bool(c.enemy_party[0].get("switched_in_this_turn", false)):
		print("  defender did not count as switched in on turn 1.")
		return false
	var logs: Array = []
	c.rng.seed = 11
	var hit1: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Quick Attack", true, logs)
	var d1: int = int(hit1.get("damage", 0))
	if d1 <= 0:
		print("  turn-1 Stakeout hit dealt no damage.")
		return false
	c.enemy_party[0]["hp"] = 500
	var logs_eot: Array = []
	c._end_of_turn(logs_eot)
	if bool(c.enemy_party[0].get("switched_in_this_turn", false)):
		print("  switched_in_this_turn was still set after end of turn.")
		return false
	var logs2: Array = []
	c.rng.seed = 11
	var hit2: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Quick Attack", true, logs2)
	var d2: int = int(hit2.get("damage", 0))
	if d2 * 2 != d1:
		print("  turn-2 damage %s was not half the turn-1 damage %s." % [str(d2), str(d1)])
		return false
	# Mid-battle: the defender switches out and back in, so the
	# flag is set again and Stakeout fires once more.
	c.enemy_party[0]["hp"] = 500
	c.execute_switch(c.enemy_party, 1, c.player_party[0], false)
	c.execute_switch(c.enemy_party, 1, c.player_party[0], false)
	if not bool(c.enemy_party[0].get("switched_in_this_turn", false)):
		print("  defender did not count as switched in after switching back in.")
		return false
	var logs3: Array = []
	c.rng.seed = 11
	var hit3: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Quick Attack", true, logs3)
	var d3: int = int(hit3.get("damage", 0))
	if d3 != d1:
		print("  switched-back-in damage %s was not the turn-1 damage %s." % [str(d3), str(d1)])
		return false
	return true


## Steadfast: Speed +1 when the holder flinches, and the holder
## still cannot move that turn.
func test_steadfast_flinch() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Quick Attack"], {"spe": 120})
	var defender: Dictionary = _mon("Lucario", ["fighting", "steel"], ["Quick Attack"], {"ability": "Steadfast"})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 5
	# Quick Attack is in the RC1 move list; Air Slash is not, so
	# the flinch comes from the override, not the move data:
	# roll_secondary reads move flinch_chance as a percent.
	c._execute_move(c.player_party[0], c.enemy_party[0], "Quick Attack", true, logs, {"flinch_chance": 100})
	if not bool(c.enemy_party[0].get("flinched", false)):
		print("  defender did not flinch.")
		return false
	var logs2: Array = []
	var out: Dictionary = c._execute_move(c.enemy_party[0], c.player_party[0], "Quick Attack", false, logs2)
	if int(out.get("damage", -1)) != 0:
		print("  flinched defender still dealt %s damage." % str(out.get("damage", -1)))
		return false
	var stages: Dictionary = c.enemy_party[0].get("stages", {})
	if int(stages.get("spe", -9)) != 1:
		print("  Steadfast Speed = %s, wanted 1." % str(stages.get("spe", -9)))
		return false
	var all_logs: String = str(logs) + str(logs2)
	if not all_logs.contains("flinched") or not all_logs.contains("Steadfast"):
		print("  logs did not contain both 'flinched' and 'Steadfast'.")
		return false
	if bool(c.enemy_party[0].get("flinched", false)):
		print("  flinched flag was still set after the defender's turn.")
		return false
	return true


## Supreme Overlord: power is 1 + 0.1 per fallen ally, up to 5.
func test_supreme_overlord_power() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Kingambit", ["dark", "steel"], ["Iron Head"], {"ability": "Supreme Overlord"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([attacker], [defender], "singles")
	var move: Dictionary = {"power": 100, "type": "Normal", "cat": "physical"}
	attacker["fallen_allies"] = 0
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, c.field_state), 1.0):
		print("  Supreme Overlord power with 0 fallen allies was not 1.0.")
		return false
	attacker["fallen_allies"] = 1
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, c.field_state), 1.1):
		print("  Supreme Overlord power with 1 fallen ally was not 1.1.")
		return false
	attacker["fallen_allies"] = 5
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, c.field_state), 1.5):
		print("  Supreme Overlord power with 5 fallen allies was not 1.5.")
		return false
	attacker["fallen_allies"] = 9
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, c.field_state), 1.5):
		print("  Supreme Overlord power with 9 fallen allies was not capped at 1.5.")
		return false
	return true


## Supreme Overlord: the caller keeps fallen_allies fresh at
## battle start, after a faint and after a Revive.
func test_supreme_overlord_fallen_allies() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Kingambit", ["dark", "steel"], ["Iron Head"], {"ability": "Supreme Overlord"})
	var fainted_bench: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"], {"hp": 0})
	var healthy_bench: Dictionary = _mon("Rattata", ["normal"], ["Tackle"])
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([holder, fainted_bench, healthy_bench], [foe], "singles")
	if int(c.player_party[0].get("fallen_allies", -1)) != 1:
		print("  fallen_allies at battle start = %s, wanted 1." % str(c.player_party[0].get("fallen_allies", -1)))
		return false
	c.player_party[2]["hp"] = 0
	c._refresh_fallen_allies()
	if int(c.player_party[0].get("fallen_allies", -1)) != 2:
		print("  fallen_allies after a second faint = %s, wanted 2." % str(c.player_party[0].get("fallen_allies", -1)))
		return false
	# Revive it: HP back above 0, and the count drops again.
	c.player_party[2]["hp"] = 100
	c._refresh_fallen_allies()
	if int(c.player_party[0].get("fallen_allies", -1)) != 1:
		print("  fallen_allies after a Revive = %s, wanted 1." % str(c.player_party[0].get("fallen_allies", -1)))
		return false
	return true


## Tangled Feet: moves aimed at a confused holder are 0.5x accurate.
## (Only Poison Puppeteer sets mon["confused"] from a move, so the
## test sets it directly, as the spec says.)
func test_tangled_feet_confused() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var defender: Dictionary = _mon("Spinda", ["normal"], ["Tackle"], {"ability": "Tangled Feet"})
	c.start_battle([attacker], [defender], "singles")
	var move: Dictionary = {}
	c.enemy_party[0]["confused"] = true
	if not is_equal_approx(AbilityEngine.accuracy_mult(c.player_party[0], c.enemy_party[0], move, c.field_state), 0.5):
		print("  accuracy against a confused Tangled Feet holder was not 0.5.")
		return false
	c.enemy_party[0]["confused"] = false
	if not is_equal_approx(AbilityEngine.accuracy_mult(c.player_party[0], c.enemy_party[0], move, c.field_state), 1.0):
		print("  accuracy against a non-confused Tangled Feet holder was not 1.0.")
		return false
	return true


## Screen Cleaner: Reflect, Light Screen and Aurora Veil end on
## both sides when the holder switches in; Tailwind stays.
func test_screen_cleaner_switch_in() -> bool:
	var c: BattleController = _new_controller()
	var lead: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var cleaner: Dictionary = _mon("Indeedee", ["psychic", "normal"], ["Psychic"], {"ability": "Screen Cleaner"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([lead, cleaner], [foe], "singles")
	c.field_state["player_screens"] = {"reflect": 5, "light_screen": 5, "aurora_veil": 5, "tailwind": 4}
	c.field_state["enemy_screens"] = {"reflect": 5, "light_screen": 5, "aurora_veil": 5, "tailwind": 4}
	var logs: Array = c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	var player_screens: Dictionary = c.field_state.get("player_screens", {})
	var enemy_screens: Dictionary = c.field_state.get("enemy_screens", {})
	for screen in ["reflect", "light_screen", "aurora_veil"]:
		if int(player_screens.get(screen, -1)) != 0:
			print("  player %s was %s after Screen Cleaner, wanted 0." % [screen, str(player_screens.get(screen, -1))])
			return false
		if int(enemy_screens.get(screen, -1)) != 0:
			print("  enemy %s was %s after Screen Cleaner, wanted 0." % [screen, str(enemy_screens.get(screen, -1))])
			return false
	if int(player_screens.get("tailwind", -1)) != 4 or int(enemy_screens.get("tailwind", -1)) != 4:
		print("  Tailwind did not stay at 4 on both sides.")
		return false
	if bool(c.field_state.get("screens_cleared", false)):
		print("  screens_cleared flag was still set after the switch.")
		return false
	if not str(logs).contains("Screen Cleaner cleared all screens!"):
		print("  no Screen Cleaner log line after the switch.")
		return false
	# No-screens case: nothing to clear, so nothing is logged.
	var c2: BattleController = _new_controller()
	var lead2: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var cleaner2: Dictionary = _mon("Indeedee", ["psychic", "normal"], ["Psychic"], {"ability": "Screen Cleaner"})
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([lead2, cleaner2], [foe2], "singles")
	var logs2: Array = c2.execute_switch(c2.player_party, 1, c2.enemy_party[0], true)
	if str(logs2).contains("Screen Cleaner cleared"):
		print("  Screen Cleaner logged a clear with no screens up.")
		return false
	return true


## Unnerve: the other side cannot eat Berries while a holder is
## active; Leftovers still heals.
func test_unnerve_blocks_berry() -> bool:
	var c: BattleController = _new_controller()
	var eater: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 40, "max_hp": 100, "item": "Sitrus Berry"})
	var unnerve_foe: Dictionary = _mon("Tyranitar", ["rock", "dark"], ["Crunch"], {"ability": "Unnerve"})
	var bench_foe: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([eater], [unnerve_foe, bench_foe], "singles")
	var logs: Array = []
	c._end_of_turn(logs)
	if int(c.player_party[0].get("hp", -1)) != 40:
		print("  Sitrus Berry healed under Unnerve (hp %s)." % str(c.player_party[0].get("hp", -1)))
		return false
	if str(c.player_party[0].get("item", "")) != "Sitrus Berry":
		print("  Sitrus Berry was eaten under Unnerve.")
		return false
	# The Unnerve holder leaves: the Berry is eaten at once.
	c.execute_switch(c.enemy_party, 1, c.player_party[0], false)
	var logs2: Array = []
	c._end_of_turn(logs2)
	if int(c.player_party[0].get("hp", -1)) != 65:
		print("  Sitrus Berry healed to %s after Unnerve left, wanted 65." % str(c.player_party[0].get("hp", -1)))
		return false
	if str(c.player_party[0].get("item", "")) == "Sitrus Berry":
		print("  Sitrus Berry was still held after it was eaten.")
		return false
	# Leftovers case: Unnerve blocks Berries, not Leftovers.
	var c2: BattleController = _new_controller()
	var leftovers_holder: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 90, "max_hp": 100, "item": "Leftovers"})
	var unnerve_foe2: Dictionary = _mon("Tyranitar", ["rock", "dark"], ["Crunch"], {"ability": "Unnerve"})
	var foe2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c2.start_battle([leftovers_holder], [unnerve_foe2, foe2], "singles")
	var logs3: Array = []
	c2._end_of_turn(logs3)
	if int(c2.player_party[0].get("hp", -1)) != 96:
		print("  Leftovers healed to %s under Unnerve, wanted 96." % str(c2.player_party[0].get("hp", -1)))
		return false
	return true


## Wimp Out: the holder switches out when damage drops it to half
## HP or less, if a bench mon exists; a KO is a faint, not a switch.
func test_wimp_out_switches() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"], {"ability": "Wimp Out", "hp": 51, "max_hp": 100})
	var bench: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"])
	var rattata: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"], {"level": 5})
	c.start_battle([holder, bench], [rattata], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(c.enemy_party[0], c.player_party[0], "Quick Attack", false, logs)
	var holder_hp: int = int(c.player_party[0].get("hp", -1))
	if holder_hp <= 0 or holder_hp > 50:
		print("  Wimpod HP after the hit was %s, wanted above 0 and at most 50." % str(holder_hp))
		return false
	if not bool(c.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after Wimp Out.")
		return false
	var logs2: Array = []
	c._perform_action({"type": "switch", "target_idx": 1}, true, logs2)
	if str(c.player_party[0].get("name", "")) != "Golisopod":
		print("  player lead after the Wimp Out switch was %s, wanted Golisopod." % str(c.player_party[0].get("name", "")))
		return false
	# Foe case: the foe switches at once, with no choice to wait for.
	var c2: BattleController = _new_controller()
	var foe_holder: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"], {"ability": "Wimp Out", "hp": 51, "max_hp": 100})
	var foe_bench: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"])
	var weak_attacker: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"], {"level": 5})
	c2.start_battle([weak_attacker], [foe_holder, foe_bench], "singles")
	var logs3: Array = []
	c2.rng.seed = 7
	c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Quick Attack", true, logs3)
	if str(c2.enemy_party[0].get("name", "")) != "Golisopod":
		print("  foe lead after the Wimp Out switch was %s, wanted Golisopod." % str(c2.enemy_party[0].get("name", "")))
		return false
	if str(c2.enemy_party[1].get("name", "")) != "Wimpod":
		print("  foe bench after the Wimp Out switch was %s, wanted Wimpod." % str(c2.enemy_party[1].get("name", "")))
		return false
	# No-switch case: a hit that leaves the holder above half HP
	# does not trigger Wimp Out.
	var c3: BattleController = _new_controller()
	var holder3: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"], {"ability": "Wimp Out", "hp": 100, "max_hp": 100})
	var bench3: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"])
	var rattata3: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"], {"level": 5})
	c3.start_battle([holder3, bench3], [rattata3], "singles")
	var logs4: Array = []
	c3.rng.seed = 7
	c3._execute_move(c3.enemy_party[0], c3.player_party[0], "Quick Attack", false, logs4)
	if bool(c3.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was set even though the holder stayed above half HP.")
		return false
	# KO case: a faint is a faint, not a Wimp Out switch.
	var c4: BattleController = _new_controller()
	var holder4: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"], {"ability": "Wimp Out", "hp": 1, "max_hp": 100})
	var bench4: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"])
	var strong: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"])
	c4.start_battle([holder4, bench4], [strong], "singles")
	var logs5: Array = []
	c4.rng.seed = 7
	c4._execute_move(c4.enemy_party[0], c4.player_party[0], "Close Combat", false, logs5)
	if int(c4.player_party[0].get("hp", -1)) > 0:
		print("  holder did not faint to the strong hit.")
		return false
	if not bool(c4.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after the faint.")
		return false
	if not str(logs5).contains("fainted"):
		print("  no faint line in the logs after the KO.")
		return false
	if str(logs5).contains("Wimp Out"):
		print("  a Wimp Out line fired for the fainted holder.")
		return false
	return true


## Emergency Exit: the same shared switch path as Wimp Out, driven
## by mon["force_switch"] instead of mon["switch_flag"].
func test_emergency_exit_shared_path() -> bool:
	var logs: Array = []
	var holder: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"], {"ability": "Emergency Exit", "hp": 40, "max_hp": 100})
	var attacker: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"])
	var move: Dictionary = {"name": "Quick Attack", "type": "Normal", "cat": "Physical", "power": 40}
	# The arm reads HP after the hit: before_hp is rebuilt as
	# hp + damage, so 40 + 60 = 100, above half, and 40 is below.
	AbilityEngine.on_damage_taken(holder, attacker, move, 60, logs)
	if not bool(holder.get("force_switch", false)):
		print("  Emergency Exit did not set force_switch after the crossing.")
		return false
	# Full path: a hit that drops the holder to half HP or less
	# switches it out, just like Wimp Out.
	var c: BattleController = _new_controller()
	var holder2: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"], {"ability": "Emergency Exit", "hp": 51, "max_hp": 100})
	var bench2: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"])
	var rattata: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"], {"level": 5})
	c.start_battle([holder2, bench2], [rattata], "singles")
	var logs2: Array = []
	c.rng.seed = 7
	c._execute_move(c.enemy_party[0], c.player_party[0], "Quick Attack", false, logs2)
	var holder_hp: int = int(c.player_party[0].get("hp", -1))
	if holder_hp <= 0 or holder_hp > 50:
		print("  Golisopod HP after the hit was %s, wanted above 0 and at most 50." % str(holder_hp))
		return false
	if not bool(c.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after Emergency Exit.")
		return false
	var logs3: Array = []
	c._perform_action({"type": "switch", "target_idx": 1}, true, logs3)
	if str(c.player_party[0].get("name", "")) != "Wimpod":
		print("  player lead after the Emergency Exit switch was %s, wanted Wimpod." % str(c.player_party[0].get("name", "")))
		return false
	# Foe case: the foe switches at once, with no choice to wait for.
	var c2: BattleController = _new_controller()
	var foe_holder: Dictionary = _mon("Golisopod", ["bug", "water"], ["Tackle"], {"ability": "Emergency Exit", "hp": 51, "max_hp": 100})
	var foe_bench: Dictionary = _mon("Wimpod", ["bug", "water"], ["Tackle"])
	var weak_attacker: Dictionary = _mon("Rattata", ["normal"], ["Quick Attack"], {"level": 5})
	c2.start_battle([weak_attacker], [foe_holder, foe_bench], "singles")
	var logs4: Array = []
	c2.rng.seed = 7
	c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Quick Attack", true, logs4)
	if str(c2.enemy_party[0].get("name", "")) != "Wimpod":
		print("  foe lead after the Emergency Exit switch was %s, wanted Wimpod." % str(c2.enemy_party[0].get("name", "")))
		return false
	if str(c2.enemy_party[1].get("name", "")) != "Golisopod":
		print("  foe bench after the Emergency Exit switch was %s, wanted Golisopod." % str(c2.enemy_party[1].get("name", "")))
		return false
	return true


## Toxic Debris: a physical hit sets one layer of Toxic Spikes on
## the attacker's side, up to 2; a special hit sets none.
func test_toxic_debris_layers() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"])
	var holder: Dictionary = _mon("Glimmora", ["rock", "poison"], ["Sludge Bomb"], {"ability": "Toxic Debris", "hp": 2000, "max_hp": 2000})
	var foe_bench: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([attacker], [holder, foe_bench], "singles")
	var logs: Array = []
	c.rng.seed = 3
	c._execute_move(c.player_party[0], c.enemy_party[0], "Close Combat", true, logs)
	var hazards: Dictionary = c.field_state.get("player_hazards", {})
	if int(hazards.get("toxic_spikes", -1)) != 1:
		print("  Toxic Spikes layers after hit 1 = %s, wanted 1." % str(hazards.get("toxic_spikes", -1)))
		return false
	c.enemy_party[0]["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 3
	c._execute_move(c.player_party[0], c.enemy_party[0], "Close Combat", true, logs2)
	hazards = c.field_state.get("player_hazards", {})
	if int(hazards.get("toxic_spikes", -1)) != 2:
		print("  Toxic Spikes layers after hit 2 = %s, wanted 2." % str(hazards.get("toxic_spikes", -1)))
		return false
	c.enemy_party[0]["hp"] = 2000
	var logs3: Array = []
	c.rng.seed = 3
	c._execute_move(c.player_party[0], c.enemy_party[0], "Close Combat", true, logs3)
	hazards = c.field_state.get("player_hazards", {})
	if int(hazards.get("toxic_spikes", -1)) != 2:
		print("  Toxic Spikes layers after hit 3 = %s, wanted 2 (max)." % str(hazards.get("toxic_spikes", -1)))
		return false
	# Special-move case: a special hit sets no layers.
	var c2: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"spa": 200})
	var holder2: Dictionary = _mon("Glimmora", ["rock", "poison"], ["Sludge Bomb"], {"ability": "Toxic Debris", "hp": 2000, "max_hp": 2000})
	var foe2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c2.start_battle([attacker2], [holder2, foe2], "singles")
	var logs4: Array = []
	c2.rng.seed = 3
	c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Shadow Ball", true, logs4)
	var hazards2: Dictionary = c2.field_state.get("player_hazards", {})
	if int(hazards2.get("toxic_spikes", -1)) != 0:
		print("  Toxic Spikes layers after a special hit = %s, wanted 0." % str(hazards2.get("toxic_spikes", -1)))
		return false
	return true


## Rebound: a reflectable status move bounces back at the user on
## the switch-in turn, but works normally from the next turn on.
## (Deviation from the spec: the spec's second part asserts the
## attacker is not poisoned, but the first bounce already poisoned
## this attacker, so the test clears the attacker's status between
## the two uses. Without that, the second assertion could never
## pass with the same attacker.)
func test_rebound_singles_switch_in_turn() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Umbreon", ["dark"], ["Toxic"])
	var defender: Dictionary = _mon("Hatterene", ["psychic", "fairy"], ["Psychic"], {"ability": "Rebound"})
	c.start_battle([attacker], [defender], "singles")
	c.enemy_party[0]["active_turns"] = 0
	var logs: Array = []
	c.rng.seed = 3
	# Toxic has no reflectable flag in the RC1 move list, so the
	# override adds it (the flag is what Rebound reads).
	c._execute_move(c.player_party[0], c.enemy_party[0], "Toxic", true, logs, {"flags": {"reflectable": true}, "acc": 100})
	if str(c.enemy_party[0].get("status", "?")) != "":
		print("  Rebound defender was poisoned on the switch-in turn.")
		return false
	if str(c.player_party[0].get("status", "")) != "TOX":
		print("  Rebound did not poison the user on the switch-in turn.")
		return false
	if not str(logs).contains("Rebound"):
		print("  no Rebound line in the logs on the switch-in turn.")
		return false
	# After the turn ends the defender is on active_turns 1, so
	# the same Toxic lands normally now.
	var logs_eot: Array = []
	c._end_of_turn(logs_eot)
	# See the deviation note above: the first bounce already
	# poisoned this attacker, so its status is cleared here to
	# check the second use on its own.
	c.player_party[0]["status"] = ""
	var logs2: Array = []
	c.rng.seed = 3
	c._execute_move(c.player_party[0], c.enemy_party[0], "Toxic", true, logs2, {"flags": {"reflectable": true}, "acc": 100})
	if str(c.enemy_party[0].get("status", "")) != "TOX":
		print("  defender was not poisoned on the turn after the switch-in turn.")
		return false
	if str(c.player_party[0].get("status", "")) != "":
		print("  attacker was poisoned on the turn after the switch-in turn.")
		return false
	return true


## Rebound in doubles: a reflectable status move bounces back at
## the user on the switch-in turn, just like in singles.
func test_rebound_doubles_bounce() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Umbreon", ["dark"], ["Toxic"])
	var ally: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	var defender: Dictionary = _mon("Hatterene", ["psychic", "fairy"], ["Psychic"], {"ability": "Rebound"})
	var foe_ally: Dictionary = _mon("Rattata", ["normal"], ["Tackle"])
	c.start_battle([attacker, ally], [defender, foe_ally], "doubles")
	c.enemy_party[0]["active_turns"] = 0
	var logs: Array = []
	c.rng.seed = 3
	# Toxic has no reflectable flag in the RC1 move list, so the
	# override adds it (the flag is what Rebound reads).
	c._execute_move_doubles(c.player_party[0], [{"side": "enemy", "slot": 0}], "Toxic", true, 0, logs, {"flags": {"reflectable": true}, "acc": 100})
	if str(c.enemy_party[0].get("status", "?")) != "":
		print("  Rebound defender was poisoned in doubles.")
		return false
	if str(c.player_party[0].get("status", "")) != "TOX":
		print("  Rebound did not poison the user in doubles.")
		return false
	return str(logs).contains("Rebound")


## As One: the full-variant holder gets exactly +1 (not +2), the
## variant is picked from the species or the ability string, and
## the KO boost only fires on a move KO.
func test_as_one_variants_and_move_ko_gate() -> bool:
	# Glastrier: +1 Attack, and only +1 (the old Batch1 double-fire
	# would have given +2).
	var c: BattleController = _new_controller()
	var glastrier: Dictionary = _mon("Calyrex-Ice", ["psychic", "ice"], ["Thunderbolt"], {"ability": "As One (Glastrier)", "spa": 200})
	var karp: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c.start_battle([glastrier], [karp], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(c.player_party[0], c.enemy_party[0], "Thunderbolt", true, logs)
	if int(c.enemy_party[0].get("hp", -1)) > 0:
		print("  Magikarp did not faint to the Glastrier KO.")
		return false
	var stages: Dictionary = c.player_party[0].get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  As One (Glastrier) Attack = %s, wanted exactly 1." % str(stages.get("atk", -9)))
		return false
	if int(stages.get("spa", -9)) != 0:
		print("  As One (Glastrier) Sp. Atk = %s, wanted 0." % str(stages.get("spa", -9)))
		return false
	# Spectrier by species: ability "As One" on Calyrex-Shadow.
	var c2: BattleController = _new_controller()
	var spectrier: Dictionary = _mon("Calyrex-Shadow", ["psychic", "ghost"], ["Thunderbolt"], {"ability": "As One", "spa": 200})
	var karp2: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c2.start_battle([spectrier], [karp2], "singles")
	var logs2: Array = []
	c2.rng.seed = 7
	c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Thunderbolt", true, logs2)
	var stages2: Dictionary = c2.player_party[0].get("stages", {})
	if int(stages2.get("spa", -9)) != 1:
		print("  As One (Calyrex-Shadow) Sp. Atk = %s, wanted 1." % str(stages2.get("spa", -9)))
		return false
	if int(stages2.get("atk", -9)) != 0:
		print("  As One (Calyrex-Shadow) Attack = %s, wanted 0." % str(stages2.get("atk", -9)))
		return false
	# Spectrier by string: ability "As One (Spectrier)" on a
	# non-Shadow species.
	var c3: BattleController = _new_controller()
	var spectrier3: Dictionary = _mon("Calyrex", ["psychic"], ["Thunderbolt"], {"ability": "As One (Spectrier)", "spa": 200})
	var karp3: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c3.start_battle([spectrier3], [karp3], "singles")
	var logs3: Array = []
	c3.rng.seed = 7
	c3._execute_move(c3.player_party[0], c3.enemy_party[0], "Thunderbolt", true, logs3)
	var stages3: Dictionary = c3.player_party[0].get("stages", {})
	if int(stages3.get("spa", -9)) != 1:
		print("  As One (Spectrier) Sp. Atk = %s, wanted 1." % str(stages3.get("spa", -9)))
		return false
	if int(stages3.get("atk", -9)) != 0:
		print("  As One (Spectrier) Attack = %s, wanted 0." % str(stages3.get("atk", -9)))
		return false
	# Non-move KO gate: a direct _handle_faint with by_move false
	# boosts nothing, for As One or for Moxie.
	var c4: BattleController = _new_controller()
	var holder4: Dictionary = _mon("Calyrex-Ice", ["psychic", "ice"], ["Thunderbolt"], {"ability": "As One (Glastrier)", "spa": 200})
	var karp4: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c4.start_battle([holder4], [karp4], "singles")
	c4.enemy_party[0]["hp"] = 0
	var logs4: Array = []
	c4._handle_faint(false, logs4, false)
	var stages4: Dictionary = c4.player_party[0].get("stages", {})
	if int(stages4.get("atk", -9)) != 0:
		print("  As One (Glastrier) Attack rose on a non-move KO (got %s)." % str(stages4.get("atk", -9)))
		return false
	var c5: BattleController = _new_controller()
	var moxie: Dictionary = _mon("Krookodile", ["ground", "dark"], ["Thunderbolt"], {"ability": "Moxie", "spa": 200})
	var karp5: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c5.start_battle([moxie], [karp5], "singles")
	c5.enemy_party[0]["hp"] = 0
	var logs5: Array = []
	c5._handle_faint(false, logs5, false)
	var stages5: Dictionary = c5.player_party[0].get("stages", {})
	if int(stages5.get("atk", -9)) != 0:
		print("  Moxie Attack rose on a non-move KO (got %s)." % str(stages5.get("atk", -9)))
		return false
	# Move-KO gate: the same direct call with by_move true boosts.
	var c6: BattleController = _new_controller()
	var holder6: Dictionary = _mon("Calyrex-Ice", ["psychic", "ice"], ["Thunderbolt"], {"ability": "As One (Glastrier)", "spa": 200})
	var karp6: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c6.start_battle([holder6], [karp6], "singles")
	c6.enemy_party[0]["hp"] = 0
	var logs6: Array = []
	c6._handle_faint(false, logs6, true)
	var stages6: Dictionary = c6.player_party[0].get("stages", {})
	if int(stages6.get("atk", -9)) != 1:
		print("  As One (Glastrier) Attack = %s on a direct move KO, wanted 1." % str(stages6.get("atk", -9)))
		return false
	return true


## Intimidate drops Attack by 1 on a plain foe, but Oblivious,
## Own Tempo and Scrappy block only that Intimidate drop. A
## foe-caused Attack drop from a move still lands on an Oblivious
## mon, even when the foe happens to have Intimidate: the block
## reads the "intimidate_drop" mark the Intimidate arm sets
## around its own call, not the source mon's ability.
func test_intimidate_blocked_oblivious_owntempo_scrappy() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var gary: Dictionary = _mon("Gyarados", ["water", "flying"], ["Tackle"], {"ability": "Intimidate"})
	var logs: Array = []
	for ab in ["Oblivious", "Own Tempo", "Scrappy"]:
		var holder: Dictionary = _mon("Holder", ["normal"], ["Tackle"], {"ability": ab})
		AbilityEngine.on_switch_in(gary, holder, field)
		var holder_stages: Dictionary = holder.get("stages", {})
		if int(holder_stages.get("atk", -9)) != 0:
			print("  Intimidate dropped the ", ab, " holder's Attack to ", holder_stages.get("atk", "?"), ", wanted 0.")
			return false
	var plain: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	AbilityEngine.on_switch_in(gary, plain, field)
	var plain_stages: Dictionary = plain.get("stages", {})
	if int(plain_stages.get("atk", -9)) != -1:
		print("  Intimidate did not drop the plain foe's Attack: ", plain_stages)
		return false
	var c: BattleController = _new_controller()
	var plain_source: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var intimidate_source: Dictionary = _mon("Gyarados", ["water", "flying"], ["Tackle"], {"ability": "Intimidate"})
	var foe1: Dictionary = _mon("Holder", ["normal"], ["Tackle"], {"ability": "Oblivious"})
	c._apply_stages(foe1, {"atk": -1}, logs, plain_source, field)
	var stages1: Dictionary = foe1.get("stages", {})
	if int(stages1.get("atk", -9)) != -1:
		print("  A move drop from a plain foe did not land on the Oblivious mon: ", stages1)
		return false
	var foe2: Dictionary = _mon("Holder", ["normal"], ["Tackle"], {"ability": "Oblivious"})
	c._apply_stages(foe2, {"atk": -1}, logs, intimidate_source, field)
	var stages2: Dictionary = foe2.get("stages", {})
	if int(stages2.get("atk", -9)) != -1:
		print("  A move drop from an Intimidate mon (no mark set) did not land on the Oblivious mon: ", stages2)
		return false
	return true


## White Smoke blocks a foe-caused stat drop, but the holder's
## own moves still lower its own stages. The Close Combat part
## proves the real move path: the self boosts in apply_after_hit
## pass is_self = true, so the block never runs for them.
func test_white_smoke_blocks_foe_not_self() -> bool:
	var c: BattleController = _new_controller()
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var holder: Dictionary = _mon("Torkoal", ["fire"], ["Close Combat"], {"ability": "White Smoke"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c._apply_stages(holder, {"atk": -1}, logs, foe, field)
	var stages: Dictionary = holder.get("stages", {})
	if int(stages.get("atk", -9)) != 0:
		print("  White Smoke did not block the foe's Attack drop: ", stages)
		return false
	c._apply_stages(holder, {"def": -1, "spd": -1}, logs, {}, field)
	stages = holder.get("stages", {})
	if int(stages.get("def", -9)) != -1 or int(stages.get("spd", -9)) != -1:
		print("  White Smoke blocked the holder's own drop: ", stages)
		return false
	var holder2: Dictionary = _mon("Torkoal", ["fire"], ["Close Combat"], {"ability": "White Smoke"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var move: Dictionary = {"name": "Close Combat", "type": "Fighting", "cat": "Physical", "power": 120, "self": {"boosts": {"def": -1, "spd": -1}}}
	MoveEffects.apply_after_hit(holder2, foe, move, 10, field, rng, logs)
	var stages2: Dictionary = holder2.get("stages", {})
	if int(stages2.get("def", -9)) != -1 or int(stages2.get("spd", -9)) != -1:
		print("  Close Combat did not drop the White Smoke holder's own Defense / Sp. Def: ", stages2)
		return false
	return true


## Ripen doubles a Sitrus Berry: 1/4 max HP becomes 1/2, so a
## Ripen mon at 40/100 heals 50 HP instead of 25. The Berry is
## eaten, and the Ripen flag is cleared after the heal.
# Deviation from the spec list: the spec calls on_end_of_turn
# with field {}, but ItemEngine._consume only tells the ability
# engine about the eaten Berry when the field is not empty, so
# with {} the Ripen flag is never set and nothing doubles. A real
# battle always passes the live field, so these tests use one
# from create_field_state() instead.
func test_ripen_sitrus_double() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var ripen: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 40, "item": "Sitrus Berry"})
	ItemEngine.on_end_of_turn(ripen, field, logs)
	if int(ripen.get("hp", -1)) != 90:
		print("  Ripen Sitrus HP = ", ripen.get("hp", "?"), ", wanted 90.")
		return false
	if str(ripen.get("item", "?")) != "":
		print("  Ripen Sitrus Berry was not eaten, item = ", ripen.get("item", "?"))
		return false
	if bool(ripen.get("ripen_double", false)):
		print("  Ripen flag was not cleared after the Sitrus heal.")
		return false
	var plain: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 40, "item": "Sitrus Berry"})
	ItemEngine.on_end_of_turn(plain, field, logs)
	if int(plain.get("hp", -1)) != 65:
		print("  Plain Sitrus HP = ", plain.get("hp", "?"), ", wanted 65.")
		return false
	return str(plain.get("item", "?")) == ""


## Ripen doubles a pinch Berry (Figy heals 1/2 max HP, doubled
## to full, capped at max HP) and a stat Berry (Liechi raises
## Attack 1 stage, doubled to 2).
func test_ripen_pinch_and_stat_berry() -> bool:
	# Same field note as test_ripen_sitrus_double: a real field
	# is needed, or _consume never sets the Ripen flag.
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var ripen: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 10, "item": "Figy Berry"})
	ItemEngine.on_end_of_turn(ripen, field, logs)
	if int(ripen.get("hp", -1)) != 100 or str(ripen.get("item", "?")) != "":
		print("  Ripen Figy HP = ", ripen.get("hp", "?"), ", item = ", ripen.get("item", "?"), ", wanted 100 and eaten.")
		return false
	var plain: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 10, "item": "Figy Berry"})
	ItemEngine.on_end_of_turn(plain, field, logs)
	if int(plain.get("hp", -1)) != 60:
		print("  Plain Figy HP = ", plain.get("hp", "?"), ", wanted 60.")
		return false
	var liechi: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 20, "item": "Liechi Berry"})
	ItemEngine.on_end_of_turn(liechi, field, logs)
	var liechi_stages: Dictionary = liechi.get("stages", {})
	if int(liechi_stages.get("atk", -9)) != 2 or str(liechi.get("item", "?")) != "":
		print("  Ripen Liechi Attack stage = ", liechi_stages.get("atk", "?"), ", item = ", liechi.get("item", "?"), ", wanted 2 and eaten.")
		return false
	var plain_liechi: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 20, "item": "Liechi Berry"})
	ItemEngine.on_end_of_turn(plain_liechi, field, logs)
	var plain_stages: Dictionary = plain_liechi.get("stages", {})
	if int(plain_stages.get("atk", -9)) != 1:
		print("  Plain Liechi Attack stage = ", plain_stages.get("atk", "?"), ", wanted 1.")
		return false
	return true


## Ripen doubles Leppa Berry (10 PP becomes 20, capped at the
## move's max PP) and Enigma Berry (1/4 max HP becomes 1/2 on a
## super-effective hit).
func test_ripen_leppa_and_enigma() -> bool:
	# Same field note as test_ripen_sitrus_double: a real field
	# is needed, or _consume never sets the Ripen flag. The
	# Enigma half reads the Ripen ability straight from the mon,
	# so it needs no field.
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var ripen: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle", "Quick Attack"], {"ability": "Ripen", "item": "Leppa Berry", "pp": {"Tackle": 0, "Quick Attack": 5}, "pp_max": {"Tackle": 35, "Quick Attack": 10}})
	ItemEngine.on_end_of_turn(ripen, field, logs)
	var ripen_pp: Dictionary = ripen.get("pp", {})
	if int(ripen_pp.get("Tackle", -1)) != 20 or int(ripen_pp.get("Quick Attack", -1)) != 5 or str(ripen.get("item", "?")) != "":
		print("  Ripen Leppa PP = ", ripen_pp, ", item = ", ripen.get("item", "?"), ", wanted Tackle 20, Quick Attack 5, eaten.")
		return false
	var plain: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle", "Quick Attack"], {"item": "Leppa Berry", "pp": {"Tackle": 0, "Quick Attack": 5}, "pp_max": {"Tackle": 35, "Quick Attack": 10}})
	ItemEngine.on_end_of_turn(plain, field, logs)
	var plain_pp: Dictionary = plain.get("pp", {})
	if int(plain_pp.get("Tackle", -1)) != 10:
		print("  Plain Leppa Tackle PP = ", plain_pp.get("Tackle", "?"), ", wanted 10.")
		return false
	var enigma: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 50, "item": "Enigma Berry", "last_effectiveness": 2.0})
	ItemEngine.on_damage_taken(enigma, {"name": "Flamethrower"}, logs)
	if int(enigma.get("hp", -1)) != 100 or str(enigma.get("item", "?")) != "":
		print("  Ripen Enigma HP = ", enigma.get("hp", "?"), ", item = ", enigma.get("item", "?"), ", wanted 100 and eaten.")
		return false
	var plain_enigma: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 50, "item": "Enigma Berry", "last_effectiveness": 2.0})
	ItemEngine.on_damage_taken(plain_enigma, {"name": "Flamethrower"}, logs)
	if int(plain_enigma.get("hp", -1)) != 75:
		print("  Plain Enigma HP = ", plain_enigma.get("hp", "?"), ", wanted 75.")
		return false
	return true


## A weaken Berry halves a super-effective hit of its type and
## is eaten; with Ripen the hit is halved again, to a quarter.
## A hit that is not super-effective does not eat the Berry.
## Chilan Berry halves any Normal-type hit, super-effective
## or not.
func test_ripen_weaken_berry_quarters() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var attacker: Dictionary = _mon("Charizard", ["fire", "flying"], ["Flamethrower"])
	var move: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special", "power": 90}
	var defender: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "item": "Occa Berry"})
	var total: int = ItemEngine.check_weaken_berry(defender, move, 2.0, 100, logs, field)
	if total != 50 or str(defender.get("item", "?")) != "":
		print("  Ripen Occa Berry halved damage = ", total, ", item = ", defender.get("item", "?"), ", wanted 50 and eaten.")
		return false
	var total2: int = AbilityEngine.modify_damage(attacker, defender, move, 50, false, false, 2.0)
	if total2 != 25:
		print("  Ripen Occa Berry quartered damage = ", total2, ", wanted 25.")
		return false
	var plain_def: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"item": "Occa Berry"})
	var total3: int = ItemEngine.check_weaken_berry(plain_def, move, 2.0, 100, logs, field)
	if total3 != 50:
		print("  Plain Occa Berry halved damage = ", total3, ", wanted 50.")
		return false
	var total4: int = AbilityEngine.modify_damage(attacker, plain_def, move, 50, false, false, 2.0)
	if total4 != 50:
		print("  Plain Occa Berry damage after modify_damage = ", total4, ", wanted 50 (no second half).")
		return false
	if bool(plain_def.get("ripen_berry_weaken", false)):
		print("  Plain holder wrongly has the Ripen weaken flag set.")
		return false
	var resisted: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "item": "Occa Berry"})
	var total5: int = ItemEngine.check_weaken_berry(resisted, move, 1.0, 100, logs, field)
	if total5 != 100 or str(resisted.get("item", "?")) != "Occa Berry":
		print("  Non-super-effective Occa Berry damage = ", total5, ", item = ", resisted.get("item", "?"), ", wanted 100 and kept.")
		return false
	var chilan: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"item": "Chilan Berry"})
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40}
	var total6: int = ItemEngine.check_weaken_berry(chilan, tackle, 1.0, 100, logs, field)
	if total6 != 50 or str(chilan.get("item", "?")) != "":
		print("  Chilan Berry damage = ", total6, ", item = ", chilan.get("item", "?"), ", wanted 50 and eaten.")
		return false
	return true


## Supersweet Syrup lowers the foe's evasiveness 1 stage on
## switch-in, once per battle. An evasion stage of -1 makes
## moves against that foe 4/3x accurate, so a 75-accuracy move
## always hits and a 60-accuracy move is 80 accurate.
func test_supersweet_syrup_accuracy() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var syrup: Dictionary = _mon("Dipplin", ["grass", "dragon"], ["Tackle"], {"ability": "Supersweet Syrup"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	AbilityBatch4.on_switch_in(syrup, foe, field)
	if int(foe.get("evasion_stage", 0)) != -1:
		print("  Supersweet Syrup evasion_stage = ", foe.get("evasion_stage", "?"), ", wanted -1.")
		return false
	if not bool(syrup.get("syrup_triggered", false)):
		print("  Supersweet Syrup did not set its once-per-battle flag.")
		return false
	AbilityBatch4.on_switch_in(syrup, foe, field)
	if int(foe.get("evasion_stage", 0)) != -1:
		print("  Second Supersweet Syrup switch-in changed evasion_stage to ", foe.get("evasion_stage", "?"), ", wanted it to stay -1.")
		return false
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var move: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "power": 90, "acc": 100}
	var mult: float = AbilityEngine.accuracy_mult(attacker, foe, move, field)
	if not is_equal_approx(mult, 4.0 / 3.0):
		print("  Accuracy against a -1 evasion foe = ", mult, ", wanted 4/3.")
		return false
	if int(75.0 * 4.0 / 3.0) != 100:
		print("  A 75-accuracy move does not always hit a -1 evasion foe.")
		return false
	if int(60.0 * 4.0 / 3.0) != 80:
		print("  A 60-accuracy move is not 80 accurate against a -1 evasion foe.")
		return false
	return true


## Stench gives damaging moves a 10% flinch chance. The chance
## rolls on its own even when the move already has a secondary
## effect (Flamethrower's 10% burn still burns about 10% of the
## time, and Stench flinches about 10% on top of it). A move
## whose secondary already flinches (Air Slash, 30%) gets no
## extra flinch chance from Stench, so it still flinches about
## 30%, not 30% plus 10%. Status moves get nothing.
func test_stench_flinch_rolls() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var stench_mon: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"], {"ability": "Stench"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var logs: Array = []
	var tackle: Dictionary = {"name": "Tackle", "type": "Normal", "cat": "Physical", "power": 40, "acc": 100}
	AbilityEngine.on_before_move(stench_mon, defender, tackle, field, logs)
	if int(tackle.get("flinch_chance", -1)) != 10:
		print("  Stench Tackle flinch_chance = ", tackle.get("flinch_chance", "?"), ", wanted 10.")
		return false
	var status_move: Dictionary = {"name": "Growl", "type": "Normal", "cat": "Status", "power": 0}
	AbilityEngine.on_before_move(stench_mon, defender, status_move, field, logs)
	if status_move.has("flinch_chance"):
		print("  Stench added a flinch chance to a Status move.")
		return false
	var flamethrower: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special", "power": 90, "secondary": {"chance": 10, "status": "brn"}}
	AbilityEngine.on_before_move(stench_mon, defender, flamethrower, field, logs)
	if int(flamethrower.get("flinch_chance", -1)) != 10:
		print("  Stench Flamethrower flinch_chance = ", flamethrower.get("flinch_chance", "?"), ", wanted 10.")
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var flinch_count: int = 0
	var burn_count: int = 0
	for i in range(1000):
		var roll: Dictionary = MoveEffects.roll_secondary(flamethrower, rng)
		if bool(roll.get("flinch", false)):
			flinch_count += 1
		if str(roll.get("status", "")) == "brn":
			burn_count += 1
	if flinch_count < 50 or flinch_count > 150:
		print("  Stench Flamethrower flinch count = ", flinch_count, " in 1000 rolls, wanted 50-150.")
		return false
	if burn_count < 50 or burn_count > 150:
		print("  Flamethrower burn count = ", burn_count, " in 1000 rolls, wanted 50-150.")
		return false
	var air_slash: Dictionary = {"name": "Air Slash", "type": "Flying", "cat": "Special", "power": 75, "secondary": {"chance": 30, "volatileStatus": "flinch"}}
	AbilityEngine.on_before_move(stench_mon, defender, air_slash, field, logs)
	if air_slash.has("flinch_chance"):
		print("  Stench added a flinch chance to Air Slash, which already flinches.")
		return false
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var air_flinch: int = 0
	for i in range(1000):
		var roll2: Dictionary = MoveEffects.roll_secondary(air_slash, rng2)
		if bool(roll2.get("flinch", false)):
			air_flinch += 1
	if air_flinch < 240 or air_flinch > 360:
		print("  Air Slash flinch count = ", air_flinch, " in 1000 rolls, wanted 240-360.")
		return false
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 7
	var tackle_flinch: int = 0
	for i in range(1000):
		var roll3: Dictionary = MoveEffects.roll_secondary(tackle, rng3)
		if bool(roll3.get("flinch", false)):
			tackle_flinch += 1
	if tackle_flinch < 50 or tackle_flinch > 150:
		print("  Stench Tackle flinch count = ", tackle_flinch, " in 1000 rolls, wanted 50-150.")
		return false
	return true


## Ripen doubles Oran Berry (10 HP becomes 20) and Berry Juice
## (20 HP becomes 40), and doubles Starf Berry (a random stat
## rises 2 stages, doubled to 4; the total of all stages is
## checked because the picked stat is random).
func test_ripen_oran_juice_starf() -> bool:
	# Same field note as test_ripen_sitrus_double: a real field
	# is needed, or _consume never sets the Ripen flag.
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var logs: Array = []
	var ripen_oran: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 40, "item": "Oran Berry"})
	ItemEngine.on_end_of_turn(ripen_oran, field, logs)
	if int(ripen_oran.get("hp", -1)) != 60 or str(ripen_oran.get("item", "?")) != "":
		print("  Ripen Oran HP = ", ripen_oran.get("hp", "?"), ", item = ", ripen_oran.get("item", "?"), ", wanted 60 and eaten.")
		return false
	var plain_oran: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 40, "item": "Oran Berry"})
	ItemEngine.on_end_of_turn(plain_oran, field, logs)
	if int(plain_oran.get("hp", -1)) != 50:
		print("  Plain Oran HP = ", plain_oran.get("hp", "?"), ", wanted 50.")
		return false
	var ripen_juice: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 40, "item": "Berry Juice"})
	ItemEngine.on_end_of_turn(ripen_juice, field, logs)
	if int(ripen_juice.get("hp", -1)) != 80:
		print("  Ripen Berry Juice HP = ", ripen_juice.get("hp", "?"), ", wanted 80.")
		return false
	var plain_juice: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 40, "item": "Berry Juice"})
	ItemEngine.on_end_of_turn(plain_juice, field, logs)
	if int(plain_juice.get("hp", -1)) != 60:
		print("  Plain Berry Juice HP = ", plain_juice.get("hp", "?"), ", wanted 60.")
		return false
	var ripen_starf: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"ability": "Ripen", "hp": 20, "item": "Starf Berry"})
	ItemEngine.on_end_of_turn(ripen_starf, field, logs)
	var starf_stages: Dictionary = ripen_starf.get("stages", {})
	var starf_total: int = 0
	for key in starf_stages.keys():
		starf_total += int(starf_stages[key])
	if starf_total != 4 or str(ripen_starf.get("item", "?")) != "":
		print("  Ripen Starf total stages = ", starf_total, ", item = ", ripen_starf.get("item", "?"), ", wanted 4 and eaten.")
		return false
	var plain_starf: Dictionary = _mon("Appletun", ["grass", "dragon"], ["Tackle"], {"hp": 20, "item": "Starf Berry"})
	ItemEngine.on_end_of_turn(plain_starf, field, logs)
	var plain_starf_stages: Dictionary = plain_starf.get("stages", {})
	var plain_total: int = 0
	for key in plain_starf_stages.keys():
		plain_total += int(plain_starf_stages[key])
	if plain_total != 2:
		print("  Plain Starf total stages = ", plain_total, ", wanted 2.")
		return false
	return true


## Steelworker: Steel moves 1.5x (power_mult), the same as Showdown's
## 1.5x Attack/Sp. Atk boost. Iron Head, seed 99: 148 with vs 99 without.
func test_steelworker_power_mult() -> bool:
	var attacker: Dictionary = _mon("Dhelmise", ["steel", "ghost"], ["Iron Head"], {"ability": "Steelworker"})
	var plain: Dictionary = _mon("Dhelmise", ["steel", "ghost"], ["Iron Head"])
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000})
	var move: Dictionary = {"name": "Iron Head", "type": "Steel", "cat": "Physical", "power": 80}
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, {}), 1.5):
		print("  Steelworker power_mult = ", AbilityEngine.power_mult(attacker, defender, move, {}), ", wanted 1.5")
		return false
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100}
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, quake, {}), 1.0):
		print("  Steelworker power_mult for Earthquake = ", AbilityEngine.power_mult(attacker, defender, quake, {}), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 99
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Iron Head", true, logs)
	if int(out.get("damage", -1)) != 148:
		print("  Steelworker dmg = ", out.get("damage", -1), ", wanted 148")
		return false
	defender["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 99
	var out2: Dictionary = c._execute_move(plain, c.enemy_party[0], "Iron Head", true, logs2)
	if int(out2.get("damage", -1)) != 99:
		print("  Steelworker plain dmg = ", out2.get("damage", -1), ", wanted 99")
		return false
	return true

## Swarm: Bug moves 1.5x at 1/3 HP or less, the same as Showdown's
## 1.5x Sp. Atk boost. Bug Buzz, seed 777: 310 at 33/100 HP vs 207 at
## 34/100 HP (the boundary: 100 / 3 = 33, so hp 33 fires, hp 34 does not).
func test_swarm_power_mult() -> bool:
	var field: Dictionary = {}
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "spd": 50})
	var move: Dictionary = {"name": "Bug Buzz", "type": "Bug", "cat": "Special", "power": 90}
	var low: Dictionary = _mon("Heracross", ["bug", "fighting"], ["Bug Buzz"], {"ability": "Swarm", "hp": 33, "max_hp": 100})
	var high: Dictionary = _mon("Heracross", ["bug", "fighting"], ["Bug Buzz"], {"ability": "Swarm", "hp": 34, "max_hp": 100})
	if not is_equal_approx(AbilityEngine.power_mult(low, defender, move, field), 1.5):
		print("  Swarm power_mult at 33 HP = ", AbilityEngine.power_mult(low, defender, move, field), ", wanted 1.5")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(high, defender, move, field), 1.0):
		print("  Swarm power_mult at 34 HP = ", AbilityEngine.power_mult(high, defender, move, field), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([low], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 777
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Bug Buzz", true, logs)
	if int(out.get("damage", -1)) != 310:
		print("  Swarm dmg = ", out.get("damage", -1), ", wanted 310")
		return false
	defender["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 777
	var out2: Dictionary = c._execute_move(high, c.enemy_party[0], "Bug Buzz", true, logs2)
	if int(out2.get("damage", -1)) != 207:
		print("  Swarm high-HP dmg = ", out2.get("damage", -1), ", wanted 207")
		return false
	return true

## Thick Fat: Fire/Ice moves against the holder deal 0.5x damage
## (damage_mult), the same as Showdown's halved offensive stat on the
## tested matchup. Flamethrower and Ice Beam, seed 777, spa 100:
## 53 vs 105 without. The holder's own Fire move is not halved.
## Known rounding limit (do NOT test spa 200 + STAB): the 0.5x damage
## multiplier is not the same as halving the stat on every matchup,
## because the base formula's "+2" is not halved by a damage
## multiplier. With spa 200 and STAB the engine gives 111 where the
## halved-stat calc gives 112 (seed 99). This test pins spa 100,
## where the two agree exactly (53 = 53).
func test_thick_fat_power_mult() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Charizard", ["fire"], ["Flamethrower"], {"spa": 100})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Thick Fat", "hp": 2000, "max_hp": 2000, "spd": 50})
	var move: Dictionary = {"name": "Flamethrower", "type": "Fire", "cat": "Special", "power": 90}
	attacker["field"] = {}
	defender["field"] = {}
	if not is_equal_approx(AbilityBatch4.damage_mult(attacker, defender, move, true), 0.5):
		print("  Thick Fat damage_mult = ", AbilityBatch4.damage_mult(attacker, defender, move, true), ", wanted 0.5")
		return false
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 777
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Flamethrower", true, logs)
	if int(out.get("damage", -1)) != 53:
		print("  Thick Fat Fire dmg = ", out.get("damage", -1), ", wanted 53")
		return false
	# Ice half: same numbers with Ice Beam.
	var c2: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Glaceon", ["ice"], ["Ice Beam"], {"spa": 100})
	var defender2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"ability": "Thick Fat", "hp": 2000, "max_hp": 2000, "spd": 50})
	c2.start_battle([attacker2], [defender2], "singles")
	var logs2: Array = []
	c2.rng.seed = 777
	var out2: Dictionary = c2._execute_move(c2.player_party[0], c2.enemy_party[0], "Ice Beam", true, logs2)
	if int(out2.get("damage", -1)) != 53:
		print("  Thick Fat Ice dmg = ", out2.get("damage", -1), ", wanted 53")
		return false
	# Direction check: a Thick Fat holder's OWN Fire move is not halved.
	# The holder is Fire type here so the STAB matches the Fire-half raw
	# damage of 105 above; a Normal-type holder would deal 70, not 105.
	var c3: BattleController = _new_controller()
	var holder: Dictionary = _mon("Charizard", ["fire"], ["Flamethrower"], {"ability": "Thick Fat", "spa": 100})
	var plain_def: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "spd": 50})
	c3.start_battle([holder], [plain_def], "singles")
	var logs3: Array = []
	c3.rng.seed = 777
	var out3: Dictionary = c3._execute_move(c3.player_party[0], c3.enemy_party[0], "Flamethrower", true, logs3)
	if int(out3.get("damage", -1)) != 105:
		print("  Thick Fat holder own Fire dmg = ", out3.get("damage", -1), ", wanted 105")
		return false
	return true

## Torrent: Water moves 1.5x at 1/3 HP or less, the same as Showdown's
## 1.5x Sp. Atk boost. Surf, seed 777: 310 at 33/100 HP vs 207 at
## 34/100 HP.
func test_torrent_power_mult() -> bool:
	var field: Dictionary = {}
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "spd": 50})
	var move: Dictionary = {"name": "Surf", "type": "Water", "cat": "Special", "power": 90}
	var low: Dictionary = _mon("Blastoise", ["water"], ["Surf"], {"ability": "Torrent", "hp": 33, "max_hp": 100})
	var high: Dictionary = _mon("Blastoise", ["water"], ["Surf"], {"ability": "Torrent", "hp": 34, "max_hp": 100})
	if not is_equal_approx(AbilityEngine.power_mult(low, defender, move, field), 1.5):
		print("  Torrent power_mult at 33 HP = ", AbilityEngine.power_mult(low, defender, move, field), ", wanted 1.5")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(high, defender, move, field), 1.0):
		print("  Torrent power_mult at 34 HP = ", AbilityEngine.power_mult(high, defender, move, field), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([low], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 777
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Surf", true, logs)
	if int(out.get("damage", -1)) != 310:
		print("  Torrent dmg = ", out.get("damage", -1), ", wanted 310")
		return false
	defender["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 777
	var out2: Dictionary = c._execute_move(high, c.enemy_party[0], "Surf", true, logs2)
	if int(out2.get("damage", -1)) != 207:
		print("  Torrent high-HP dmg = ", out2.get("damage", -1), ", wanted 207")
		return false
	return true

## Tough Claws: contact moves 1.3x power, the same as Showdown's
## 1.3x base power boost. Iron Head, seed 42: 88 with vs 68 without.
## NOTE: the RC1 move database carries no flags at all, so a plain
## _execute_move("Iron Head") gives power_mult 1.0 and Tough Claws
## never fires through the controller. The end-to-end part below
## passes override={"flags": {"contact": true}} because Iron Head
## really is a contact move in Showdown; when the v5 loader brings
## real flags in, the override can be dropped. The plain control
## passes the same override, so the only difference is the ability.
func test_tough_claws_power_mult() -> bool:
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "def": 50})
	var contact_move: Dictionary = {"name": "Iron Head", "type": "Steel", "cat": "Physical", "power": 80, "flags": {"contact": true}}
	var plain_move: Dictionary = {"name": "Iron Head", "type": "Steel", "cat": "Physical", "power": 80, "flags": {}}
	var attacker: Dictionary = _mon("Lycanroc-Dusk", ["rock"], ["Iron Head"], {"ability": "Tough Claws"})
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, contact_move, {}), 1.3):
		print("  Tough Claws power_mult (contact) = ", AbilityEngine.power_mult(attacker, defender, contact_move, {}), ", wanted 1.3")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, plain_move, {}), 1.0):
		print("  Tough Claws power_mult (no flag) = ", AbilityEngine.power_mult(attacker, defender, plain_move, {}), ", wanted 1.0")
		return false
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100, "flags": {}}
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, quake, {}), 1.0):
		print("  Tough Claws power_mult (Earthquake) = ", AbilityEngine.power_mult(attacker, defender, quake, {}), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 42
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Iron Head", true, logs, {"flags": {"contact": true}})
	if int(out.get("damage", -1)) != 88:
		print("  Tough Claws dmg = ", out.get("damage", -1), ", wanted 88")
		return false
	defender["hp"] = 2000
	var plain_attacker: Dictionary = _mon("Lycanroc-Dusk", ["rock"], ["Iron Head"])
	var logs2: Array = []
	c.rng.seed = 42
	var out2: Dictionary = c._execute_move(plain_attacker, c.enemy_party[0], "Iron Head", true, logs2, {"flags": {"contact": true}})
	if int(out2.get("damage", -1)) != 68:
		print("  Tough Claws plain dmg = ", out2.get("damage", -1), ", wanted 68")
		return false
	return true

## Toxic Boost: physical moves 1.5x while poisoned (PSN or TOX),
## the same as Showdown's 1.5x base power boost. Earthquake while
## PSN, seed 99: 123 vs 82 healthy. Special moves get no boost.
func test_toxic_boost_power_mult() -> bool:
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "def": 50})
	var move: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100}
	var poisoned: Dictionary = _mon("Zangoose", ["normal"], ["Earthquake"], {"ability": "Toxic Boost", "status": "PSN"})
	var badly: Dictionary = _mon("Zangoose", ["normal"], ["Earthquake"], {"ability": "Toxic Boost", "status": "TOX"})
	var healthy: Dictionary = _mon("Zangoose", ["normal"], ["Earthquake"], {"ability": "Toxic Boost"})
	var special: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "power": 90}
	if not is_equal_approx(AbilityEngine.power_mult(poisoned, defender, move, {}), 1.5):
		print("  Toxic Boost power_mult (PSN) = ", AbilityEngine.power_mult(poisoned, defender, move, {}), ", wanted 1.5")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(badly, defender, move, {}), 1.5):
		print("  Toxic Boost power_mult (TOX) = ", AbilityEngine.power_mult(badly, defender, move, {}), ", wanted 1.5")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(healthy, defender, move, {}), 1.0):
		print("  Toxic Boost power_mult (healthy) = ", AbilityEngine.power_mult(healthy, defender, move, {}), ", wanted 1.0")
		return false
	if not is_equal_approx(AbilityEngine.power_mult(poisoned, defender, special, {}), 1.0):
		print("  Toxic Boost power_mult (special) = ", AbilityEngine.power_mult(poisoned, defender, special, {}), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([poisoned], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 99
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Earthquake", true, logs)
	if int(out.get("damage", -1)) != 123:
		print("  Toxic Boost dmg = ", out.get("damage", -1), ", wanted 123")
		return false
	defender["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 99
	var out2: Dictionary = c._execute_move(healthy, c.enemy_party[0], "Earthquake", true, logs2)
	if int(out2.get("damage", -1)) != 82:
		print("  Toxic Boost healthy dmg = ", out2.get("damage", -1), ", wanted 82")
		return false
	return true

## Transistor: Electric moves 1.3x (power_mult), the same as
## Showdown's 1.3x Attack/Sp. Atk boost. Thunderbolt, seed 5:
## 304 with vs 234 without.
func test_transistor_power_mult() -> bool:
	var attacker: Dictionary = _mon("Regieleki", ["electric"], ["Thunderbolt"], {"ability": "Transistor"})
	var plain: Dictionary = _mon("Regieleki", ["electric"], ["Thunderbolt"])
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 2000, "max_hp": 2000, "spd": 50})
	var move: Dictionary = {"name": "Thunderbolt", "type": "Electric", "cat": "Special", "power": 90}
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, move, {}), 1.3):
		print("  Transistor power_mult = ", AbilityEngine.power_mult(attacker, defender, move, {}), ", wanted 1.3")
		return false
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100}
	if not is_equal_approx(AbilityEngine.power_mult(attacker, defender, quake, {}), 1.0):
		print("  Transistor power_mult (Earthquake) = ", AbilityEngine.power_mult(attacker, defender, quake, {}), ", wanted 1.0")
		return false
	var c: BattleController = _new_controller()
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 5
	var out: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Thunderbolt", true, logs)
	if int(out.get("damage", -1)) != 304:
		print("  Transistor dmg = ", out.get("damage", -1), ", wanted 304")
		return false
	defender["hp"] = 2000
	var logs2: Array = []
	c.rng.seed = 5
	var out2: Dictionary = c._execute_move(plain, c.enemy_party[0], "Thunderbolt", true, logs2)
	if int(out2.get("damage", -1)) != 234:
		print("  Transistor plain dmg = ", out2.get("damage", -1), ", wanted 234")
		return false
	return true


## Group G — side-condition + Tera + protection (Teraform Zero,
## Wind Power, Wind Rider). No Piercing Drill test: it stays
## partial until Protect lands, and Protect is not in this engine.
## NOTE: Protect IS in the RC1 move DB (line 849: Normal/Status,
## power 0, priority 4) — the Group G spec wrongly said it was not.

## TEST 1 — Teraform Zero ends the weather and the terrain the
## moment a Terapagos Terastallizes.
## DEVIATION from the spec as written: the spec passes
## tera_type "Stellar", but gimmicks.gd ALL_TYPES holds only the
## 18 real types, so terastallize() fails safe on "Stellar" and
## tera_active is never set. This test uses "Normal" instead, so
## the Terastallization really goes through and the ability can
## fire. Everything else is exactly as the spec wrote it.
func test_teraform_zero_ends_weather_terrain_on_tera() -> bool:
	var c: BattleController = _new_controller()
	var terapagos: Dictionary = _mon("Terapagos", ["normal"], ["Tera Blast"], {"ability": "Teraform Zero"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([terapagos], [foe], "singles")
	c.field_state["weather"] = "rain"
	c.field_state["weather_turns"] = 5
	c.field_state["terrain"] = "grassy"
	c.field_state["terrain_turns"] = 5
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "tera", "tera_type": "Normal", "move_name": "Tera Blast"}, c.player_party[0], logs)
	if not bool(c.player_party[0].get("tera_active", false)):
		print("  Terapagos did not Terastallize.")
		return false
	if str(c.field_state.get("weather", "rain")) != "none":
		print("  weather was '%s' after Terastallizing, wanted 'none'." % str(c.field_state.get("weather", "")))
		return false
	if int(c.field_state.get("weather_turns", -1)) != 0:
		print("  weather_turns was %s after Terastallizing, wanted 0." % str(c.field_state.get("weather_turns", -1)))
		return false
	if str(c.field_state.get("terrain", "grassy")) != "none":
		print("  terrain was '%s' after Terastallizing, wanted 'none'." % str(c.field_state.get("terrain", "")))
		return false
	if int(c.field_state.get("terrain_turns", -1)) != 0:
		print("  terrain_turns was %s after Terastallizing, wanted 0." % str(c.field_state.get("terrain_turns", -1)))
		return false
	if not str(logs).contains("Teraform Zero"):
		print("  no Teraform Zero line in the log.")
		return false
	if not bool(c.player_party[0].get("teraform_zero_used", false)):
		print("  teraform_zero_used was not set.")
		return false
	return true


## TEST 2 — Teraform Zero fires once per battle: a second call
## after weather is set again changes nothing.
func test_teraform_zero_once_per_battle() -> bool:
	var c: BattleController = _new_controller()
	var terapagos: Dictionary = _mon("Terapagos", ["normal"], ["Tera Blast"], {"ability": "Teraform Zero"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([terapagos], [foe], "singles")
	c.field_state["weather"] = "rain"
	c.field_state["weather_turns"] = 5
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "tera", "tera_type": "Normal", "move_name": "Tera Blast"}, c.player_party[0], logs)
	if str(c.field_state.get("weather", "rain")) != "none":
		print("  first Terastallization did not clear the weather.")
		return false
	# Weather comes back later in the battle.
	c.field_state["weather"] = "rain"
	c.field_state["weather_turns"] = 5
	var second_logs: Array = AbilityEngine.on_terastallize(c.player_party[0], c.field_state)
	if str(c.field_state.get("weather", "none")) != "rain":
		print("  second Teraform Zero call cleared weather set after the Terastallization.")
		return false
	if int(c.field_state.get("weather_turns", -1)) != 5:
		print("  second Teraform Zero call changed weather_turns to %s, wanted 5." % str(c.field_state.get("weather_turns", -1)))
		return false
	if not second_logs.is_empty():
		print("  second Teraform Zero call logged something, but it should do nothing.")
		return false
	return true


## TEST 3 — the old before_move firing is gone: weather set after
## the Terastallization stays up when the Terapagos moves.
## (Same "Normal" Tera type deviation as Test 1: "Stellar" is not
## in gimmicks.gd ALL_TYPES, so the Terastallization would fail.)
func test_teraform_zero_not_on_next_move() -> bool:
	var c: BattleController = _new_controller()
	var terapagos: Dictionary = _mon("Terapagos", ["normal"], ["Tera Blast"], {"ability": "Teraform Zero"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([terapagos], [foe], "singles")
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "tera", "tera_type": "Normal", "move_name": "Tera Blast"}, c.player_party[0], logs)
	if not bool(c.player_party[0].get("teraform_zero_used", false)):
		print("  Terastallizing did not set teraform_zero_used.")
		return false
	# Weather is set AFTER the Terastallization.
	c.field_state["weather"] = "rain"
	c.field_state["weather_turns"] = 5
	var move_logs: Array = []
	AbilityEngine.on_before_move(c.player_party[0], c.enemy_party[0], {"name": "Tera Blast", "type": "Stellar", "cat": "Special", "power": 100}, c.field_state, move_logs)
	if str(c.field_state.get("weather", "none")) != "rain":
		print("  weather set after Terastallizing was cleared by the next move (old before_move firing is back).")
		return false
	if int(c.field_state.get("weather_turns", -1)) != 5:
		print("  weather_turns changed to %s on the next move, wanted 5." % str(c.field_state.get("weather_turns", -1)))
		return false
	return true


## TEST 4 — Wind Power gains the Charge effect when Tailwind
## starts on its side.
func test_wind_power_charge_on_tailwind_start() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Kilowattrel", ["electric", "flying"], ["Tailwind"], {"ability": "Wind Power"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([holder], [foe], "singles")
	var logs: Array = []
	c._apply_field_move(c.player_party[0], c.enemy_party[0], {"name": "Tailwind"}, true, logs)
	if not bool(c.player_party[0].get("charged", false)):
		print("  Wind Power did not gain Charge when Tailwind started.")
		return false
	var screens: Dictionary = c.field_state["player_screens"]
	if int(screens.get("tailwind", 0)) != 4:
		print("  Tailwind lasted %s turns, wanted 4." % str(screens.get("tailwind", 0)))
		return false
	if not str(logs).contains("Wind Power"):
		print("  no Wind Power line in the log.")
		return false
	return true


## TEST 5 — Wind Rider raises Attack 1 when Tailwind starts on
## its side.
func test_wind_rider_attack_on_tailwind_start() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Brambleghast", ["grass", "ghost"], ["Tailwind"], {"ability": "Wind Rider"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([holder], [foe], "singles")
	var logs: Array = []
	c._apply_field_move(c.player_party[0], c.enemy_party[0], {"name": "Tailwind"}, true, logs)
	var stages: Dictionary = c.player_party[0].get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  Wind Rider Attack stage was %s when Tailwind started, wanted 1." % str(stages.get("atk", -9)))
		return false
	if not str(logs).contains("Wind Rider"):
		print("  no Wind Rider line in the log.")
		return false
	return true


## TEST 6 — Wind Rider raises Attack 1 when it switches in under
## an already active Tailwind.
func test_wind_rider_attack_switch_in_under_tailwind() -> bool:
	var c: BattleController = _new_controller()
	var lead: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var holder: Dictionary = _mon("Brambleghast", ["grass", "ghost"], ["Tailwind"], {"ability": "Wind Rider"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([lead, holder], [foe], "singles")
	var screens: Dictionary = c.field_state["player_screens"]
	screens["tailwind"] = 4
	var logs: Array = c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	if str(c.player_party[0].get("name", "")) != "Brambleghast":
		print("  the switch did not bring Brambleghast in.")
		return false
	var stages: Dictionary = c.player_party[0].get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  Wind Rider Attack stage was %s after switching in under Tailwind, wanted 1." % str(stages.get("atk", -9)))
		return false
	if not str(logs).contains("Wind Rider"):
		print("  no Wind Rider line in the switch log.")
		return false
	return true


## TEST 7 — Wind Power gets NOTHING when it switches in under an
## already active Tailwind (Showdown gives it no onStart).
func test_wind_power_no_charge_switch_in_under_tailwind() -> bool:
	var c: BattleController = _new_controller()
	var lead: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var holder: Dictionary = _mon("Kilowattrel", ["electric", "flying"], ["Tailwind"], {"ability": "Wind Power"})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([lead, holder], [foe], "singles")
	var screens: Dictionary = c.field_state["player_screens"]
	screens["tailwind"] = 4
	c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	if str(c.player_party[0].get("name", "")) != "Kilowattrel":
		print("  the switch did not bring Kilowattrel in.")
		return false
	if bool(c.player_party[0].get("charged", false)):
		print("  Wind Power gained Charge by switching in under Tailwind, but Showdown gives it no onStart.")
		return false
	return true


## TEST 8 — refreshing an already active Tailwind fires NEITHER
## effect again: no second Attack boost for Wind Rider, and no
## second Charge log line for Wind Power.
func test_tailwind_refresh_gives_no_second_boost() -> bool:
	# Wind Rider half: already at Attack +1, Tailwind already up.
	var c: BattleController = _new_controller()
	var rider: Dictionary = _mon("Brambleghast", ["grass", "ghost"], ["Tailwind"], {"ability": "Wind Rider", "stages": {"atk": 1, "def": 0, "spa": 0, "spd": 0, "spe": 0}})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([rider], [foe], "singles")
	var screens: Dictionary = c.field_state["player_screens"]
	screens["tailwind"] = 2
	var logs: Array = []
	c._apply_field_move(c.player_party[0], c.enemy_party[0], {"name": "Tailwind"}, true, logs)
	var stages: Dictionary = c.player_party[0].get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  refreshing Tailwind raised Wind Rider Attack to %s, wanted it to stay at 1." % str(stages.get("atk", -9)))
		return false
	if str(logs).contains("Wind Rider"):
		print("  refreshing Tailwind logged a Wind Rider line again.")
		return false
	# Wind Power half: already charged, Tailwind already up.
	var c2: BattleController = _new_controller()
	var charger: Dictionary = _mon("Kilowattrel", ["electric", "flying"], ["Tailwind"], {"ability": "Wind Power", "charged": true})
	var foe2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c2.start_battle([charger], [foe2], "singles")
	var screens2: Dictionary = c2.field_state["player_screens"]
	screens2["tailwind"] = 2
	var logs2: Array = []
	c2._apply_field_move(c2.player_party[0], c2.enemy_party[0], {"name": "Tailwind"}, true, logs2)
	if not bool(c2.player_party[0].get("charged", false)):
		print("  refreshing Tailwind took the Charge effect away.")
		return false
	if str(logs2).contains("Wind Power"):
		print("  refreshing Tailwind logged a Wind Power line again.")
		return false
	return true


## TEST 9 — in doubles, a Tailwind start gives the effect to BOTH
## allies on the side: Charge for the Wind Power mon, Attack +1
## for the Wind Rider mon.
func test_tailwind_start_doubles_both_allies() -> bool:
	var c: BattleController = _new_controller()
	var charger: Dictionary = _mon("Kilowattrel", ["electric", "flying"], ["Tailwind"], {"ability": "Wind Power"})
	var rider: Dictionary = _mon("Brambleghast", ["grass", "ghost"], ["Tailwind"], {"ability": "Wind Rider"})
	var e1: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var e2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([charger, rider], [e1, e2], "doubles")
	var logs: Array = []
	c._apply_field_move(c.player_party[0], c.enemy_party[0], {"name": "Tailwind"}, true, logs)
	if not bool(c.player_party[0].get("charged", false)):
		print("  slot 0 Wind Power mon did not gain Charge on the doubles Tailwind start.")
		return false
	var stages: Dictionary = c.player_party[1].get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  slot 1 Wind Rider mon Attack stage was %s on the doubles Tailwind start, wanted 1." % str(stages.get("atk", -9)))
		return false
	if not str(logs).contains("Wind Power"):
		print("  no Wind Power line in the doubles log.")
		return false
	if not str(logs).contains("Wind Rider"):
		print("  no Wind Rider line in the doubles log.")
		return false
	return true


## Protect sets protect_active on the user, and a foe's damaging
## move aimed at the protected mon deals no damage.
func test_protect_blocks_damaging_move() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"])
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	if not bool(player.get("protect_active", false)):
		print("  Protect did not set protect_active.")
		return false
	if not str(logs).contains("protected itself!"):
		print("  Protect logged no 'protected itself!'.")
		return false
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Close Combat", false, logs2)
	if int(player.get("hp", 0)) != 100:
		print("  protected mon took damage: hp = ", int(player.get("hp", 0)))
		return false
	if int(out.get("damage", -1)) != 0:
		print("  blocked Close Combat dealt ", int(out.get("damage", -1)), " damage.")
		return false
	if not str(logs2).contains("protected itself!"):
		print("  blocked Close Combat logged no 'protected itself!'.")
		return false
	return true


## Protect blocks a foe's status move too: no burn, no damage.
## Will-O-Wisp is 85 accurate in the RC1 move list, so acc 100
## is passed in the override to keep the test exact.
func test_protect_blocks_status_move() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var foe: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Will-O-Wisp"])
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	if not bool(player.get("protect_active", false)):
		print("  Protect did not set protect_active.")
		return false
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Will-O-Wisp", false, logs2, {"acc": 100})
	if str(player.get("status", "")) != "":
		print("  protected mon was burned by Will-O-Wisp.")
		return false
	if int(out.get("damage", -1)) != 0:
		print("  blocked Will-O-Wisp dealt ", int(out.get("damage", -1)), " damage.")
		return false
	if not str(logs2).contains("protected itself!"):
		print("  blocked Will-O-Wisp logged no 'protected itself!'.")
		return false
	return true


## In doubles, an ally's attack aimed at the protected mon is
## never blocked by its ally's Protect: the ally's Thunderbolt
## still hurts the protected mon.
func test_protect_does_not_block_ally_move_doubles() -> bool:
	var c: BattleController = _new_controller()
	var guard: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var ally: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var foe1: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Shadow Ball"])
	var foe2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([guard, ally], [foe1, foe2], "doubles")
	var logs: Array = []
	c._execute_move_doubles(guard, [{"side": "player", "slot": 0}], "Protect", true, 0, logs)
	if not bool(guard.get("protect_active", false)):
		print("  Protect did not set protect_active in doubles.")
		return false
	c.rng.seed = 4242
	var logs2: Array = []
	c._execute_move_doubles(ally, [{"side": "player", "slot": 0}], "Thunderbolt", true, 1, logs2)
	if int(guard.get("hp", 0)) >= 100:
		print("  ally Thunderbolt did not hurt the protected ally: hp = ", int(guard.get("hp", 0)))
		return false
	return true


## The Protect flag ends with the turn: after _end_of_turn the
## same mon can be hit by the same move next turn.
func test_protect_flag_clears_after_turn() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"])
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	var logs_blocked: Array = []
	c._execute_move(foe, player, "Close Combat", false, logs_blocked)
	if int(player.get("hp", 0)) != 100:
		print("  protected mon took damage before end of turn: hp = ", int(player.get("hp", 0)))
		return false
	var logs_end: Array = []
	c._end_of_turn(logs_end)
	if bool(player.get("protect_active", false)):
		print("  protect_active was still set after _end_of_turn.")
		return false
	c.rng.seed = 4242
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Close Combat", false, logs2)
	if int(player.get("hp", 0)) >= 100:
		print("  unprotected mon took no damage next turn: hp = ", int(player.get("hp", 0)))
		return false
	return int(out.get("damage", 0)) > 0


## A contact move from a Piercing Drill holder hits through
## Protect. Contact is passed in the override as flags.contact:
## no move in either data set carries a contact marker, so the
## bypass arms only fire when the move dict carries it (see the
## spec's known gap 1). The protected mon gets 500 HP so the hit
## does not faint it and the damage can be compared exactly.
func test_piercing_drill_contact_hits_through_protect() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {"hp": 500, "max_hp": 500})
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"], {"ability": "Piercing Drill"})
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	c.rng.seed = 4242
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Close Combat", false, logs2, {"flags": {"contact": true}})
	if int(player.get("hp", 0)) >= 500:
		print("  Piercing Drill contact move did not hurt the protected mon: hp = ", int(player.get("hp", 0)))
		return false
	if int(out.get("damage", 0)) <= 0:
		print("  Piercing Drill contact move dealt no damage.")
		return false
	# No damage cut: the same hit on an unprotected mon from a
	# plain-ability foe, same seed, must deal the same damage
	# (the old 0.25x Piercing Drill arm is gone).
	var c2: BattleController = _new_controller()
	var player2: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {"hp": 500, "max_hp": 500})
	var foe2: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"])
	c2.start_battle([player2], [foe2], "singles")
	c2.rng.seed = 4242
	var logs3: Array = []
	var out2: Dictionary = c2._execute_move(foe2, player2, "Close Combat", false, logs3, {"flags": {"contact": true}})
	if int(out2.get("damage", -1)) != int(out.get("damage", -2)):
		print("  Piercing Drill damage ", int(out.get("damage", -2)), " != plain damage ", int(out2.get("damage", -1)))
		return false
	return true


## A Piercing Drill holder's non-contact move is still blocked:
## Earthquake carries no contact key, so it gets no bypass flag.
func test_piercing_drill_non_contact_still_blocked() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Earthquake"], {"ability": "Piercing Drill"})
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Earthquake", false, logs2)
	if int(player.get("hp", 0)) != 100:
		print("  protected mon took damage from non-contact Earthquake: hp = ", int(player.get("hp", 0)))
		return false
	if int(out.get("damage", -1)) != 0:
		print("  blocked Earthquake dealt ", int(out.get("damage", -1)), " damage.")
		return false
	return str(logs2).contains("protected itself!")


## A contact move from an Unseen Fist holder hits through
## Protect. Contact is passed as flags.contact in the override,
## as in the Piercing Drill test: no DB move carries a contact
## marker (spec known gap 1).
func test_unseen_fist_contact_hits_through_protect() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {"hp": 500, "max_hp": 500})
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"], {"ability": "Unseen Fist"})
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	c.rng.seed = 4242
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Close Combat", false, logs2, {"flags": {"contact": true}})
	if int(player.get("hp", 0)) >= 500:
		print("  Unseen Fist contact move did not hurt the protected mon: hp = ", int(player.get("hp", 0)))
		return false
	return int(out.get("damage", 0)) > 0


## An Unseen Fist holder's non-contact move is still blocked:
## Earthquake carries no contact key, so it gets no bypass flag.
func test_unseen_fist_non_contact_still_blocked() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	var foe: Dictionary = _mon("Machamp", ["fighting"], ["Earthquake"], {"ability": "Unseen Fist"})
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(player, foe, "Protect", true, logs)
	var logs2: Array = []
	var out: Dictionary = c._execute_move(foe, player, "Earthquake", false, logs2)
	if int(player.get("hp", 0)) != 100:
		print("  protected mon took damage from non-contact Earthquake: hp = ", int(player.get("hp", 0)))
		return false
	if int(out.get("damage", -1)) != 0:
		print("  blocked Earthquake dealt ", int(out.get("damage", -1)), " damage.")
		return false
	return str(logs2).contains("protected itself!")


## The ignores_protect mark survives into _execute_move_doubles.
## First half: on_before_move marks a contact Piercing Drill move
## on the move dict itself (the flag is read off the dict, not
## off the call's return value). Second half: the mark is carried
## in the override dict, because _execute_move_doubles loads a
## fresh move dict from the database and would lose it (Patch H).
func test_ignores_protect_flag_path_doubles() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"], {"ability": "Piercing Drill"})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var move: Dictionary = {"name": "Close Combat", "type": "Fighting", "cat": "Physical", "power": 120, "acc": 100, "flags": {"contact": true}}
	var logs: Array = []
	AbilityEngine.on_before_move(attacker, defender, move, field, logs)
	if not bool(move.get("ignores_protect", false)):
		print("  on_before_move did not mark the contact move ignores_protect.")
		return false
	var c: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Machamp", ["fighting"], ["Close Combat"], {"ability": "Piercing Drill"})
	var ally2: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt"])
	var foe1: Dictionary = _mon("Snorlax", ["normal"], ["Protect"], {"hp": 500, "max_hp": 500})
	var foe2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([attacker2, ally2], [foe1, foe2], "doubles")
	var logs2: Array = []
	c._execute_move_doubles(foe1, [{"side": "enemy", "slot": 0}], "Protect", false, 0, logs2)
	if not bool(foe1.get("protect_active", false)):
		print("  foe Protect did not set protect_active in doubles.")
		return false
	c.rng.seed = 4242
	var logs3: Array = []
	var out: Dictionary = c._execute_move_doubles(attacker2, [{"side": "enemy", "slot": 0}], "Close Combat", true, 0, logs3, {"ignores_protect": true})
	if int(foe1.get("hp", 0)) >= 500:
		print("  carried ignores_protect did not let the hit through in doubles: foe hp = ", int(foe1.get("hp", 0)))
		return false
	return int(out.get("damage", 0)) > 0


## A self move is not blocked by the FOE's Protect: the foe
## protected itself, then the player's Swords Dance still raises
## its own Attack +2. Swords Dance uses the RC1 "self_boost"
## shape, so the status-move block (which only looks at "boosts")
## does not treat it as targeting the defender.
func test_protect_does_not_block_own_self_move() -> bool:
	var c: BattleController = _new_controller()
	var player: Dictionary = _mon("Scizor", ["bug", "steel"], ["Swords Dance"])
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Protect"])
	c.start_battle([player], [foe], "singles")
	var logs: Array = []
	c._execute_move(foe, player, "Protect", false, logs)
	if not bool(foe.get("protect_active", false)):
		print("  foe Protect did not set protect_active.")
		return false
	var logs2: Array = []
	c._execute_move(player, foe, "Swords Dance", true, logs2)
	var stages: Dictionary = player.get("stages", {})
	if int(stages.get("atk", -9)) != 2:
		print("  Swords Dance did not raise Attack to +2 (got ", int(stages.get("atk", -9)), ").")
		return false
	return true


## A ruin holder that faints to poison at the end of the turn clears
## its flag, so later damage returns to normal. Group F numbers:
## Earthquake deals 109 with the flag, 82 without it, seed 99.
func test_sword_of_ruin_end_of_turn_faint() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Chien-Pao", ["dark", "ice"], ["Earthquake"], {"ability": "Sword of Ruin", "hp": 1, "max_hp": 100, "status": "PSN"})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 2000, "max_hp": 2000})
	c.start_battle([holder, bench], [foe], "singles")
	if not bool(c.field_state.get("ruin_sword", false)):
		print("  ruin_sword was not set after start_battle.")
		return false
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Earthquake"}, c.field_state)
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	if int(c.player_party[0].get("hp", -1)) != 0:
		print("  holder hp = ", int(c.player_party[0].get("hp", -1)), ", wanted 0 (fainted to poison at end of turn).")
		return false
	if bool(c.field_state.get("ruin_sword", false)):
		print("  ruin_sword stayed on after the holder fainted to poison.")
		return false
	if not bool(c.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after the poison faint.")
		return false
	# Send in the bench mon, then hit the foe again: the damage must
	# be plain (82), the Group F number without the flag (109 with it).
	c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	var foe_mon: Dictionary = c.enemy_party[0]
	foe_mon["hp"] = 2000
	var logs: Array = []
	c.rng.seed = 99
	var hit: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Earthquake", true, logs)
	var dealt: int = int(hit.get("damage", -1))
	if dealt != 82:
		print("  follow-up Earthquake dealt ", dealt, ", wanted 82 (no ruin boost).")
		return false
	return true


## Same shape as Test 1, holder on the enemy side, so the auto-send
## path is checked too. Group F numbers: Earthquake deals 62 with
## the flag, 82 without it, seed 99.
## Deviation from the spec: the spec has the player use Earthquake
## in the turn, but the holder has 1 HP, so that Earthquake would KO
## it by move before the poison tick, and the flag would clear
## through the old move-KO path instead of the end-of-turn path.
## The player uses Reflect (a move that cannot KO) in the turn
## instead; the damage check still uses Earthquake, through a
## direct _execute_move call with seed 99.
func test_tablets_of_ruin_end_of_turn_faint() -> bool:
	var c: BattleController = _new_controller()
	# Deterministic turn: the controller's rng is seeded before
	# the turn runs. Unseeded, this test was luck-based — the
	# two leads tie on Speed (both 100), so the turn order is a
	# coin flip, and when the holder moved first its Tackle
	# could crit and knock out the player's 100 HP Snorlax,
	# ending the battle before the poison tick this test is
	# about. The seed changes no check below; it only fixes
	# which rolls happen. The follow-up damage check reseeds
	# to 99 itself, as before.
	c.rng.seed = 99
	var attacker: Dictionary = _mon("Snorlax", ["normal"], ["Earthquake", "Reflect"])
	var holder: Dictionary = _mon("Wo-Chien", ["dark", "grass"], ["Tackle"], {"ability": "Tablets of Ruin", "hp": 1, "max_hp": 100, "status": "PSN"})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [holder, bench], "singles")
	if not bool(c.field_state.get("ruin_tablets", false)):
		print("  ruin_tablets was not set after start_battle.")
		return false
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Reflect"}, c.field_state)
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	var foe_lead: Dictionary = c.enemy_party[0]
	if str(foe_lead.get("name", "")) != "Snorlax":
		print("  enemy lead is still ", str(foe_lead.get("name", "?")), ", wanted the bench Snorlax sent in.")
		return false
	if int(foe_lead.get("hp", -1)) != 100:
		print("  replacement Snorlax hp = ", int(foe_lead.get("hp", -1)), ", wanted 100 (no end-of-turn damage in the turn it was sent in).")
		return false
	if bool(c.field_state.get("ruin_tablets", false)):
		print("  ruin_tablets stayed on after the holder fainted to poison.")
		return false
	var logs: Array = []
	c.rng.seed = 99
	var hit: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Earthquake", true, logs)
	var dealt: int = int(hit.get("damage", -1))
	if dealt != 82:
		print("  follow-up Earthquake dealt ", dealt, ", wanted 82 (no ruin cut).")
		return false
	return true


## Same shape as Test 2, special damage. Group F numbers:
## Thunderbolt deals 166 with the flag, 221 without it, seed 99.
## Deviation from the spec, same reason as Test 2: the spec has the
## player use Thunderbolt in the turn, but the holder has 1 HP, so
## that Thunderbolt would KO it by move before the poison tick.
## The player uses Reflect in the turn instead; the damage check
## still uses Thunderbolt, through a direct _execute_move call
## with seed 99. Second deviation: the spec gives the holder
## Tackle, but Tackle is not in the RC1 move list, and
## MoveDatabase.get_move falls back to an 80-power Normal attack
## for any unknown move. The holder is Normal type (so Thunderbolt
## stays neutral), so that fallback Tackle gets STAB and deals
## about 104 damage, which KOs the 100-HP Pikachu before the
## poison tick. The holder uses Reflect (a real no-op move) instead.
func test_vessel_of_ruin_end_of_turn_faint() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Pikachu", ["electric"], ["Thunderbolt", "Reflect"], {"spa": 200})
	var holder: Dictionary = _mon("Chi-Yu", ["normal"], ["Reflect"], {"ability": "Vessel of Ruin", "hp": 1, "max_hp": 100, "status": "PSN"})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([attacker], [holder, bench], "singles")
	if not bool(c.field_state.get("ruin_vessel", false)):
		print("  ruin_vessel was not set after start_battle.")
		return false
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Reflect"}, c.field_state)
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	var foe_lead: Dictionary = c.enemy_party[0]
	if str(foe_lead.get("name", "")) != "Snorlax":
		print("  enemy lead is still ", str(foe_lead.get("name", "?")), ", wanted the bench Snorlax sent in.")
		return false
	if int(foe_lead.get("hp", -1)) != 100:
		print("  replacement Snorlax hp = ", int(foe_lead.get("hp", -1)), ", wanted 100 (no end-of-turn damage in the turn it was sent in).")
		return false
	if bool(c.field_state.get("ruin_vessel", false)):
		print("  ruin_vessel stayed on after the holder fainted to poison.")
		return false
	var logs: Array = []
	c.rng.seed = 99
	var hit: Dictionary = c._execute_move(c.player_party[0], c.enemy_party[0], "Thunderbolt", true, logs)
	var dealt: int = int(hit.get("damage", -1))
	if dealt != 221:
		print("  follow-up Thunderbolt dealt ", dealt, ", wanted 221 (no ruin cut).")
		return false
	return true


## Moxie fires on a move KO but NOT on a poison KO. Both halves in
## one test, each with a fresh controller.
func test_moxie_no_boost_on_end_of_turn_ko() -> bool:
	# Half A (no regression, mirrors the existing test_on_faint_moxie):
	# a move KO still boosts Moxie.
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Krookodile", ["ground", "dark"], ["Thunderbolt"], {"ability": "Moxie", "spa": 200})
	var defender: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Thunderbolt", true, logs)
	if int(defender.get("hp", -1)) > 0:
		print("  move-KO half: defender did not faint.")
		return false
	var stages: Dictionary = attacker.get("stages", {})
	if int(stages.get("atk", -9)) != 1:
		print("  move-KO half: Moxie Attack = ", int(stages.get("atk", -9)), ", wanted 1.")
		return false
	if not str(logs).contains("Moxie"):
		print("  move-KO half: no Moxie line in the logs.")
		return false
	# Half B (the new path): a poison KO does not boost Moxie, but
	# the faint is still handled (the next mon is sent in).
	var c2: BattleController = _new_controller()
	var attacker2: Dictionary = _mon("Krookodile", ["ground", "dark"], ["Reflect"], {"ability": "Moxie", "spa": 200})
	var defender2: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 100, "status": "PSN"})
	var bench2: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c2.start_battle([attacker2], [defender2, bench2], "singles")
	var res2: Dictionary = c2.run_turn({"type": "move", "move_name": "Reflect"}, c2.field_state)
	if str(res2.get("status", "")) != "ongoing":
		print("  poison-KO half: status = ", str(res2.get("status", "?")), ", wanted ongoing.")
		return false
	if int(defender2.get("hp", -1)) != 0:
		print("  poison-KO half: defender hp = ", int(defender2.get("hp", -1)), ", wanted 0 (fainted to poison at end of turn).")
		return false
	var stages2: Dictionary = attacker2.get("stages", {})
	if int(stages2.get("atk", -9)) != 0:
		print("  poison-KO half: Moxie Attack = ", int(stages2.get("atk", -9)), ", wanted 0 (Moxie did not fire).")
		return false
	if str(res2.get("logs", [])).contains("Moxie"):
		print("  poison-KO half: a Moxie line showed up in the turn logs.")
		return false
	if str(c2.enemy_party[0].get("name", "")) != "Snorlax":
		print("  poison-KO half: enemy lead is still ", str(c2.enemy_party[0].get("name", "?")), ", wanted the bench Snorlax sent in.")
		return false
	return true


## An end-of-turn KO grants the same EXP as the move-KO path for
## the same matchup. Numbers are the existing test's numbers:
## Bulbasaur base EXP 64, level 5: 64 x 5 / 7 = 45 EXP.
## Needs res://data/exp_yield.json, same as
## test_exp_grant_and_level_up.
func test_end_of_turn_faint_grants_exp() -> bool:
	var c: BattleController = _new_controller()
	var winner: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Reflect"], {"level": 5, "exp": 150, "exp_is_total": true, "participated": true})
	var fainted: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Splash"], {"level": 5, "hp": 1, "max_hp": 100, "status": "PSN"})
	c.start_battle([winner], [fainted], "singles")
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Reflect"}, c.field_state)
	if int(fainted.get("hp", -1)) != 0:
		print("  fainted Bulbasaur hp = ", int(fainted.get("hp", -1)), ", wanted 0.")
		return false
	if int(winner.get("exp", -1)) != 195:
		print("  winner exp = ", int(winner.get("exp", -1)), ", wanted 195.")
		return false
	if int(winner.get("level", -1)) != 6:
		print("  winner level = ", int(winner.get("level", -1)), ", wanted 6.")
		return false
	if int(winner.get("exp_next", -1)) != 41:
		print("  winner exp_next = ", int(winner.get("exp_next", -1)), ", wanted 41.")
		return false
	if str(res.get("status", "")) != "player_won":
		print("  status = ", str(res.get("status", "?")), ", wanted player_won.")
		return false
	if not str(res.get("logs", [])).contains("gained 45 EXP"):
		print("  no 'gained 45 EXP' line in the turn logs.")
		return false
	return true


## Both mons faint in the same tick; both get replacements.
func test_both_mons_faint_to_end_of_turn_damage() -> bool:
	var c: BattleController = _new_controller()
	var player_mon: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 1, "max_hp": 100, "status": "PSN"})
	var player_bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var enemy_mon: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 1, "max_hp": 100, "status": "PSN"})
	var enemy_bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	c.start_battle([player_mon, player_bench], [enemy_mon, enemy_bench], "singles")
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Reflect"}, c.field_state)
	if int(player_mon.get("hp", -1)) != 0:
		print("  player Snorlax hp = ", int(player_mon.get("hp", -1)), ", wanted 0.")
		return false
	var foe_lead: Dictionary = c.enemy_party[0]
	if str(foe_lead.get("name", "")) != "Snorlax" or int(foe_lead.get("hp", -1)) != 100:
		print("  enemy lead after the turn: ", str(foe_lead.get("name", "?")), " hp ", int(foe_lead.get("hp", -1)), ", wanted Snorlax hp 100.")
		return false
	if not bool(c.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after both mons fainted.")
		return false
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	c.execute_switch(c.player_party, 1, c.enemy_party[0], true)
	if int(c.player_party[0].get("hp", -1)) != 100:
		print("  replacement player Snorlax hp = ", int(c.player_party[0].get("hp", -1)), ", wanted 100.")
		return false
	return true


## A mon that fainted to a move earlier in the same turn is NOT
## handled again at the end of the turn. This is the snapshot test.
## Magikarp base EXP is 40 (exp_yield.json) at level 50, so the one
## grant is 40 x 50 / 7 = 285 EXP. Needs res://data/exp_yield.json,
## like Test 5.
func test_end_of_turn_faint_no_double_exp() -> bool:
	var c: BattleController = _new_controller()
	var winner: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Thunderbolt"], {"level": 5, "exp": 150, "exp_is_total": true, "spa": 200, "participated": true})
	var foe: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"hp": 1, "max_hp": 20})
	var foe_bench: Dictionary = _mon("Bulbasaur", ["grass", "poison"], ["Splash"], {"level": 5, "hp": 100, "max_hp": 100})
	c.start_battle([winner], [foe, foe_bench], "singles")
	c.rng.seed = 7
	var res: Dictionary = c.run_turn({"type": "move", "move_name": "Thunderbolt"}, c.field_state)
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	if int(winner.get("exp", -1)) != 435:
		print("  winner exp = ", int(winner.get("exp", -1)), ", wanted 435 (150 + 285, one grant only).")
		return false
	return true


## The doubles path: a ruin holder faints to poison, the flag
## clears, the player side waits to pick.
func test_end_of_turn_faint_doubles() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Chien-Pao", ["dark", "ice"], ["Reflect"], {"ability": "Sword of Ruin", "hp": 1, "max_hp": 100, "status": "PSN"})
	var ally: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 100, "max_hp": 100})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 100, "max_hp": 100})
	var foe0: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 100, "max_hp": 100})
	var foe1: Dictionary = _mon("Snorlax", ["normal"], ["Reflect"], {"hp": 100, "max_hp": 100})
	c.start_battle([holder, ally, bench], [foe0, foe1], "doubles")
	if not bool(c.field_state.get("ruin_sword", false)):
		print("  ruin_sword was not set after start_battle.")
		return false
	var res: Dictionary = c.run_turn_doubles([{"type": "move", "move_name": "Reflect"}, {"type": "move", "move_name": "Reflect"}], c.field_state)
	if str(res.get("status", "")) != "ongoing":
		print("  status = ", str(res.get("status", "?")), ", wanted ongoing.")
		return false
	if int(c.player_party[0].get("hp", -1)) != 0:
		print("  holder hp = ", int(c.player_party[0].get("hp", -1)), ", wanted 0 (fainted to poison at end of turn).")
		return false
	if bool(c.field_state.get("ruin_sword", false)):
		print("  ruin_sword stayed on after the holder fainted to poison.")
		return false
	if not bool(c.battle_state.get("player_must_switch", false)):
		print("  player_must_switch was not set after the poison faint.")
		return false
	if int(c.player_party[1].get("hp", -1)) != 100:
		print("  ally hp = ", int(c.player_party[1].get("hp", -1)), ", wanted 100 (the living ally was not hurt by the faint handling).")
		return false
	return true


## Coordinator tests: the five fixes the coordinator made by hand
## (Dry Skin double-fire, Overcoat vs Effect Spore, confusion from
## a move, Toxic Spikes switch-in, the Neutralizing Gas cantsuppress
## list). Stage-to-damage is covered by Group C's
## test_stage_application, so it is not repeated here.
func test_dry_skin_single_fire() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Lapras", ["water"], ["Surf"], {"spa": 100})
	var defender: Dictionary = _mon("Parasect", ["bug", "grass"], ["Tackle"], {"ability": "Dry Skin", "hp": 50, "max_hp": 100})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Surf", true, logs, {"power": 90, "type": "Water", "cat": "Special", "acc": 100})
	if int(defender.get("hp", -1)) != 75:
		print("  Dry Skin HP after Surf was %s, wanted 75 (one 1/4 max HP heal)." % str(defender.get("hp", -1)))
		return false
	return true

func test_overcoat_blocks_effect_spore() -> bool:
	var defender: Dictionary = _mon("Amoonguss", ["grass", "poison"], ["Tackle"], {"ability": "Effect Spore"})
	var plain: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {"ability": ""})
	var coated: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {"ability": "Overcoat"})
	var move: Dictionary = {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100, "flags": {"contact": 1}}
	var seen_plain: bool = false
	for i in range(60):
		plain["status"] = ""
		var logs: Array = []
		AbilityEngine._v2_on_damage_taken(defender, plain, move, 10, logs)
		if str(plain.get("status", "")) != "":
			seen_plain = true
			break
	if not seen_plain:
		print("  Effect Spore never fired in 60 hits on a plain attacker.")
		return false
	for i in range(60):
		coated["status"] = ""
		var logs2: Array = []
		AbilityEngine._v2_on_damage_taken(defender, coated, move, 10, logs2)
		if str(coated.get("status", "")) != "":
			print("  Overcoat attacker got status %s from Effect Spore." % str(coated.get("status", "")))
			return false
	return true

func test_confusion_from_move() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Whimsicott", ["grass", "fairy"], ["Swagger"], {})
	var defender: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {})
	c.start_battle([attacker], [defender], "singles")
	var logs: Array = []
	c.rng.seed = 7
	c._execute_move(attacker, defender, "Swagger", true, logs, {"power": 0, "type": "Normal", "cat": "Status", "acc": 100, "volatileStatus": "confusion", "boosts": {"atk": 2}})
	if not bool(defender.get("confused", false)):
		print("  Swagger did not confuse the defender.")
		return false
	var stages: Dictionary = defender.get("stages", {})
	if int(stages.get("atk", -9)) != 2:
		print("  Swagger Attack stages were %s, wanted 2." % str(stages.get("atk", -9)))
		return false
	return true

func test_toxic_spikes_switch_in() -> bool:
	var mon1: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {})
	var h1: Dictionary = {"toxic_spikes": 1}
	StatusAndFieldEngine.apply_entry_hazards(mon1, h1)
	if str(mon1.get("status", "")) != "PSN":
		print("  1 Toxic Spikes layer gave status %s, wanted PSN." % str(mon1.get("status", "")))
		return false
	var mon2: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {})
	var h2: Dictionary = {"toxic_spikes": 2}
	StatusAndFieldEngine.apply_entry_hazards(mon2, h2)
	if str(mon2.get("status", "")) != "TOX":
		print("  2 Toxic Spikes layers gave status %s, wanted TOX." % str(mon2.get("status", "")))
		return false
	var mon3: Dictionary = _mon("Gengar", ["ghost", "poison"], ["Tackle"], {})
	var h3: Dictionary = {"toxic_spikes": 2}
	StatusAndFieldEngine.apply_entry_hazards(mon3, h3)
	if int(h3.get("toxic_spikes", -1)) != 0:
		print("  Poison type did not absorb Toxic Spikes (layers %s)." % str(h3.get("toxic_spikes", -1)))
		return false
	if str(mon3.get("status", "")) != "":
		print("  Poison type was poisoned by its own Toxic Spikes.")
		return false
	var mon4: Dictionary = _mon("Steelix", ["steel", "ground"], ["Tackle"], {})
	var h4: Dictionary = {"toxic_spikes": 2}
	StatusAndFieldEngine.apply_entry_hazards(mon4, h4)
	if str(mon4.get("status", "")) != "":
		print("  Steel type was poisoned by Toxic Spikes.")
		return false
	if int(h4.get("toxic_spikes", -1)) != 2:
		print("  Steel type cleared Toxic Spikes layers (now %s)." % str(h4.get("toxic_spikes", -1)))
		return false
	return true

func test_cantsuppress_list() -> bool:
	var field: Dictionary = {"abilities_suppressed": true}
	var keep: Array = ["As One", "Battle Bond", "Comatose", "Disguise", "Gulp Missile", "Ice Face", "Multitype", "Power Construct", "RKS System", "Schooling", "Shields Down", "Stance Change", "Tera Shift", "Zen Mode", "Zero to Hero"]
	for ab in keep:
		var mon: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {"ability": ab})
		if AbilityEngine._suppressed(field, [mon]):
			print("  %s was suppressed by Neutralizing Gas, but it is cantsuppress." % str(ab))
			return false
	var plain: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {"ability": "Intimidate"})
	if not AbilityEngine._suppressed(field, [plain]):
		print("  Intimidate was not suppressed by Neutralizing Gas.")
		return false
	var teraform: Dictionary = _mon("Pikachu", ["electric"], ["Tackle"], {"ability": "Teraform Zero"})
	if not AbilityEngine._suppressed(field, [teraform]):
		print("  Teraform Zero was not suppressed, but it is not cantsuppress.")
		return false
	var off_field: Dictionary = {}
	if AbilityEngine._suppressed(off_field, [plain]):
		print("  Abilities were suppressed with no Neutralizing Gas flag.")
		return false
	return true


## Dazzling in singles blocks a foe's priority move (the
## before_move arm), and in doubles the holder protects its
## whole side: a priority move aimed at the holder's PARTNER
## is blocked too (side_priority_block in the damage pass).
func test_dazzling_singles_and_doubles_partner() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Bruxish", ["water", "psychic"], ["Tackle"], {"ability": "Dazzling"})
	var foe: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Quick Attack"])
	c.start_battle([holder], [foe], "singles")
	c.rng.seed = 3
	var logs: Array = []
	c._execute_move(foe, holder, "Quick Attack", false, logs)
	if int(holder.get("hp", 0)) != 100:
		print("  Singles Dazzling: holder took damage, hp = ", int(holder.get("hp", 0)))
		return false
	if not str(logs).contains("blocked the priority move"):
		print("  Singles Dazzling: no block log. ", str(logs))
		return false
	# Doubles: the partner (slot 0) is the target, the holder
	# stands in slot 1. The partner must take no damage.
	var partner: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	var holder2: Dictionary = _mon("Bruxish", ["water", "psychic"], ["Tackle"], {"ability": "Dazzling"})
	var foe2: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Quick Attack"])
	var foe2b: Dictionary = _mon("Rattata", ["normal"], ["Tackle"])
	c.start_battle([partner, holder2], [foe2, foe2b], "doubles")
	c.rng.seed = 3
	var logs2: Array = []
	c._execute_move_doubles(foe2, [{"side": "player", "slot": 0}], "Quick Attack", false, 0, logs2)
	if int(partner.get("hp", 0)) != 100:
		print("  Doubles Dazzling: partner took damage, hp = ", int(partner.get("hp", 0)))
		return false
	if not str(logs2).contains("blocked the priority move"):
		print("  Doubles Dazzling: no block log. ", str(logs2))
		return false
	# A non-priority move against the same partner lands fine.
	var logs3: Array = []
	c._execute_move_doubles(foe2b, [{"side": "player", "slot": 0}], "Tackle", false, 1, logs3)
	if int(partner.get("hp", 0)) >= 100:
		print("  Doubles Dazzling: a plain Tackle was blocked too.")
		return false
	return true


## Gravity has real effects: Ground moves hit Flying and
## Levitate Pokemon, accuracy is boosted by 5/3 (a 70%
## accurate move cannot miss), and Fly cannot be used.
func test_gravity_effects() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Dugtrio", ["ground"], ["Earthquake"])
	var flyer: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([attacker], [flyer], "singles")
	c.rng.seed = 5
	var logs0: Array = []
	c._execute_move(attacker, flyer, "Earthquake", true, logs0)
	if int(flyer.get("hp", 0)) != 100:
		print("  Without Gravity, Earthquake hurt a Flying mon.")
		return false
	c.field_state["gravity"] = 5
	flyer["field"] = c.field_state
	attacker["field"] = c.field_state
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(attacker, flyer, "Earthquake", true, logs)
	if int(flyer.get("hp", 0)) >= 100:
		print("  Gravity: Earthquake still could not hit a Flying mon.")
		return false
	# Levitate is grounded too.
	var lev: Dictionary = _mon("Bronzong", ["steel", "psychic"], ["Tackle"], {"ability": "Levitate"})
	lev["field"] = c.field_state
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(attacker, lev, "Earthquake", true, logs2)
	if int(lev.get("hp", 0)) >= 100:
		print("  Gravity: Earthquake still could not hit a Levitate mon.")
		return false
	# Accuracy: a 70% move is boosted past 100 and always hits.
	var zapper: Dictionary = _mon("Pikachu", ["electric"], ["Zap Cannon"])
	var target: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	zapper["field"] = c.field_state
	target["field"] = c.field_state
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(zapper, target, "Zap Cannon", true, logs3, {"name": "Zap Cannon", "power": 50, "type": "Electric", "cat": "Special", "acc": 70})
	if int(target.get("hp", 0)) >= 500:
		print("  Gravity: the boosted-accuracy move did not land.")
		return false
	# Fly is disabled outright.
	var logs4: Array = []
	c._execute_move(flyer, attacker, "Fly", false, logs4, {"name": "Fly", "power": 90, "type": "Flying", "cat": "Physical", "acc": 95})
	if not str(logs4).contains("Gravity prevents"):
		print("  Gravity: Fly was not prevented. ", str(logs4))
		return false
	return true


## Safeguard blocks a foe's status move on the protected
## side (through the one choke point, try_set_status).
func test_safeguard_blocks_status() -> bool:
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	field["enemy_safeguard"] = 5
	var target: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	target["side"] = "enemy"
	var source: Dictionary = _mon("Pikachu", ["electric"], ["Thunder Wave"])
	source["side"] = "player"
	var logs: Array = []
	if AbilityEngine.try_set_status(target, "PAR", source, field, logs):
		print("  Safeguard did not block the status.")
		return false
	if str(target.get("status", "")) != "":
		print("  Safeguard: target still got a status.")
		return false
	if not str(logs).contains("protected by Safeguard"):
		print("  Safeguard: no protection log. ", str(logs))
		return false
	# With Safeguard down, the same call lands.
	field["enemy_safeguard"] = 0
	var logs2: Array = []
	if not AbilityEngine.try_set_status(target, "PAR", source, field, logs2):
		print("  Without Safeguard the status should have landed.")
		return false
	return str(target.get("status", "")) == "PAR"


## Wonder Room swaps Defense and Sp. Def in the damage maths:
## a physical hit meets Sp. Def, a special hit meets Defense.
func test_wonder_room_swaps_defenses() -> bool:
	var rng := RandomNumberGenerator.new()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Punch"], {"atk": 100, "spa": 100})
	var defender: Dictionary = _mon("Wall", ["normal"], ["Tackle"], {"def": 200, "spd": 40})
	var phys: Dictionary = {"name": "Punch", "type": "Normal", "cat": "Physical", "power": 80}
	var spec: Dictionary = {"name": "Beam", "type": "Normal", "cat": "Special", "power": 80}
	rng.seed = 5
	var plain_phys: int = int(PUWBattleEngine.calculate_damage(attacker, defender, phys, rng).get("damage", 0))
	rng.seed = 5
	var plain_spec: int = int(PUWBattleEngine.calculate_damage(attacker, defender, spec, rng).get("damage", 0))
	var wr_field: Dictionary = {"wonder_room": 5}
	attacker["field"] = wr_field
	defender["field"] = wr_field
	rng.seed = 5
	var wr_phys: int = int(PUWBattleEngine.calculate_damage(attacker, defender, phys, rng).get("damage", 0))
	rng.seed = 5
	var wr_spec: int = int(PUWBattleEngine.calculate_damage(attacker, defender, spec, rng).get("damage", 0))
	if not (wr_phys > plain_phys):
		print("  Wonder Room: physical damage ", wr_phys, " should beat plain ", plain_phys, " (Sp. Def 40 met instead of Def 200).")
		return false
	if not (wr_spec < plain_spec):
		print("  Wonder Room: special damage ", wr_spec, " should be under plain ", plain_spec, " (Def 200 met instead of Sp. Def 40).")
		return false
	return true


## Magic Room suppresses held items: Leftovers stops healing
## at the end of the turn, and a Focus Sash never triggers.
func test_magic_room_suppresses_items() -> bool:
	var mon: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"item": "Leftovers", "hp": 50})
	var logs: Array = []
	ItemEngine.on_end_of_turn(mon, {"magic_room": 3}, logs)
	if int(mon.get("hp", 0)) != 50:
		print("  Magic Room: Leftovers healed anyway, hp = ", int(mon.get("hp", 0)))
		return false
	var logs2: Array = []
	ItemEngine.on_end_of_turn(mon, {}, logs2)
	if int(mon.get("hp", 0)) != 56:
		print("  Without Magic Room, Leftovers should heal 6, hp = ", int(mon.get("hp", 0)))
		return false
	# Focus Sash through a real hit.
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"])
	var sashed: Dictionary = _mon("Frail", ["normal"], ["Tackle"], {"item": "Focus Sash", "def": 10})
	c.start_battle([attacker], [sashed], "singles")
	c.field_state["magic_room"] = 5
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(attacker, sashed, "Tackle", true, logs3, {"name": "Tackle", "power": 200, "type": "Normal", "cat": "Physical", "acc": 100})
	if int(sashed.get("hp", 0)) != 0:
		print("  Magic Room: Focus Sash saved the mon anyway, hp = ", int(sashed.get("hp", 0)))
		return false
	var sashed2: Dictionary = _mon("Frail", ["normal"], ["Tackle"], {"item": "Focus Sash", "def": 10})
	c.start_battle([attacker], [sashed2], "singles")
	c.rng.seed = 5
	var logs4: Array = []
	c._execute_move(attacker, sashed2, "Tackle", true, logs4, {"name": "Tackle", "power": 200, "type": "Normal", "cat": "Physical", "acc": 100})
	if int(sashed2.get("hp", 0)) != 1:
		print("  Without Magic Room, Focus Sash should leave 1 HP, hp = ", int(sashed2.get("hp", 0)))
		return false
	return true


## Heal Block blocks healing moves and draining while it is
## up; both work again without it.
func test_heal_block_blocks_healing() -> bool:
	var c: BattleController = _new_controller()
	var attacker: Dictionary = _mon("Blissey", ["normal"], ["Recover"], {"hp": 40, "heal_block_turns": 3})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([attacker], [foe], "singles")
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(attacker, foe, "Recover", true, logs, {"name": "Recover", "power": 0, "type": "Normal", "cat": "Status", "acc": 100, "heal_self": 0.5})
	if int(attacker.get("hp", 0)) != 40:
		print("  Heal Block: Recover healed anyway, hp = ", int(attacker.get("hp", 0)))
		return false
	if not str(logs).contains("prevented from healing by Heal Block"):
		print("  Heal Block: no block log on Recover. ", str(logs))
		return false
	attacker["heal_block_turns"] = 0
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(attacker, foe, "Recover", true, logs2, {"name": "Recover", "power": 0, "type": "Normal", "cat": "Status", "acc": 100, "heal_self": 0.5})
	if int(attacker.get("hp", 0)) != 90:
		print("  Without Heal Block, Recover should heal to 90, hp = ", int(attacker.get("hp", 0)))
		return false
	# Drain under Heal Block (MoveEffects level).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var drain_move: Dictionary = {"name": "Giga Drain", "type": "Grass", "cat": "Special", "power": 75, "drain": 0.5}
	var drainer: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Giga Drain"], {"hp": 50, "max_hp": 100, "heal_block_turns": 2})
	var logs3: Array = []
	MoveEffects.apply_after_hit(drainer, _mon("Snorlax", ["normal"], ["Tackle"]), drain_move, 60, field, rng, logs3)
	if int(drainer.get("hp", 0)) != 50:
		print("  Heal Block: Giga Drain healed anyway, hp = ", int(drainer.get("hp", 0)))
		return false
	return str(logs3).contains("prevented from healing by Heal Block")


## Fly is a two-turn move: the first use only takes the user
## into the air (no damage, PP spent once), a foe's plain move
## misses it while it is up there, and the strike turn — forced
## through _perform_action, even when another move was picked —
## deals damage, clears the state and spends no PP again.
func test_fly_two_turn_airborne() -> bool:
	var c: BattleController = _new_controller()
	var flyer: Dictionary = _mon("Pidgeot", ["normal", "flying"], ["Fly"], {"hp": 200, "max_hp": 200})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([flyer], [foe], "singles")
	c.rng.seed = 5
	var fly_move: Dictionary = {"name": "Fly", "power": 90, "type": "Flying", "cat": "Physical", "acc": 100}
	var logs: Array = []
	c._execute_move(flyer, foe, "Fly", true, logs, fly_move)
	if int(foe.get("hp", 0)) != 500:
		print("  Fly turn 1 dealt damage, foe hp = ", int(foe.get("hp", 0)))
		return false
	if str(flyer.get("airborne_move", "")) != "fly":
		print("  Fly turn 1 did not set the airborne state. ", str(logs))
		return false
	if not str(logs).contains("flew up high"):
		print("  Fly turn 1: no rise log. ", str(logs))
		return false
	var pp_map: Dictionary = flyer.get("pp", {})
	if int(pp_map.get("Fly", 0)) != 14:
		print("  Fly turn 1 should spend exactly 1 PP, pp = ", int(pp_map.get("Fly", 0)))
		return false
	# The foe's Tackle misses the airborne mon.
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(foe, flyer, "Tackle", false, logs2, {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100})
	if int(flyer.get("hp", 0)) != 200:
		print("  Tackle hit an airborne mon, hp = ", int(flyer.get("hp", 0)))
		return false
	if not str(logs2).contains("in the air"):
		print("  Tackle vs airborne: no in-the-air log. ", str(logs2))
		return false
	# Strike turn: _perform_action is told Tackle, but the
	# airborne mon is forced to strike with Fly instead.
	c.rng.seed = 5
	var logs3: Array = []
	c._perform_action({"type": "move", "move_name": "Tackle"}, true, logs3)
	if int(foe.get("hp", 0)) >= 500:
		print("  Fly strike turn dealt no damage, foe hp = ", int(foe.get("hp", 0)))
		return false
	if str(flyer.get("airborne_move", "")) != "":
		print("  Fly strike turn did not clear the airborne state.")
		return false
	var pp_map2: Dictionary = flyer.get("pp", {})
	if int(pp_map2.get("Fly", 0)) != 14:
		print("  Fly strike turn spent PP a second time, pp = ", int(pp_map2.get("Fly", 0)))
		return false
	return true


## Gravity brings a Pokemon that is mid-Fly straight back
## down: the airborne state is cleared, and a following
## Earthquake hits the (Flying) mon because Gravity is up.
func test_gravity_brings_down_fly() -> bool:
	var c: BattleController = _new_controller()
	var flyer: Dictionary = _mon("Pidgeot", ["normal", "flying"], ["Fly"], {"hp": 200, "max_hp": 200})
	var foe: Dictionary = _mon("Snorlax", ["normal"], ["Gravity", "Earthquake"], {"hp": 500, "max_hp": 500})
	c.start_battle([flyer], [foe], "singles")
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(flyer, foe, "Fly", true, logs, {"name": "Fly", "power": 90, "type": "Flying", "cat": "Physical", "acc": 100})
	if str(flyer.get("airborne_move", "")) != "fly":
		print("  Gravity test setup: Fly did not raise the mon.")
		return false
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(foe, flyer, "Gravity", false, logs2, {"name": "Gravity", "power": 0, "type": "Psychic", "cat": "Status", "acc": 100})
	if str(flyer.get("airborne_move", "")) != "":
		print("  Gravity did not clear the airborne state. ", str(logs2))
		return false
	if not str(logs2).contains("was brought down by Gravity"):
		print("  Gravity: no brought-down log. ", str(logs2))
		return false
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(foe, flyer, "Earthquake", false, logs3, {"name": "Earthquake", "power": 100, "type": "Ground", "cat": "Physical", "acc": 100})
	if int(flyer.get("hp", 0)) >= 200:
		print("  After Gravity, Earthquake still could not hit the Flying mon, hp = ", int(flyer.get("hp", 0)))
		return false
	return true


## Sky Drop takes the target up with the carrier: the target
## is held in the sky (it cannot act, and a plain move misses
## it), and Gravity brings both mons back down.
func test_sky_drop_and_gravity() -> bool:
	var c: BattleController = _new_controller()
	var carrier: Dictionary = _mon("Aerodactyl", ["rock", "flying"], ["Sky Drop"], {"hp": 200, "max_hp": 200})
	var target: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"hp": 500, "max_hp": 500})
	c.start_battle([carrier], [target], "singles")
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(carrier, target, "Sky Drop", true, logs, {"name": "Sky Drop", "power": 60, "type": "Flying", "cat": "Physical", "acc": 100})
	if int(target.get("hp", 0)) != 500:
		print("  Sky Drop turn 1 dealt damage, target hp = ", int(target.get("hp", 0)))
		return false
	if str(carrier.get("airborne_move", "")) != "skydrop":
		print("  Sky Drop turn 1 did not set the carrier airborne. ", str(logs))
		return false
	if not bool(target.get("held_in_sky", false)):
		print("  Sky Drop turn 1 did not hold the target in the sky. ", str(logs))
		return false
	# The held target cannot act.
	var logs2: Array = []
	c._perform_action({"type": "move", "move_name": "Tackle"}, false, logs2)
	if int(carrier.get("hp", 0)) != 200:
		print("  A held-in-sky mon acted and hit the carrier, hp = ", int(carrier.get("hp", 0)))
		return false
	if not str(logs2).contains("held in the sky"):
		print("  Held target: no held-in-the-sky log. ", str(logs2))
		return false
	# A plain move from a third mon misses the held target.
	var third: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"])
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(third, target, "Tackle", true, logs3, {"name": "Tackle", "power": 40, "type": "Normal", "cat": "Physical", "acc": 100})
	if int(target.get("hp", 0)) != 500:
		print("  Tackle hit a held-in-sky target, hp = ", int(target.get("hp", 0)))
		return false
	# Gravity brings both down.
	var caster: Dictionary = _mon("Alakazam", ["psychic"], ["Gravity"])
	c.rng.seed = 5
	var logs4: Array = []
	c._execute_move(caster, target, "Gravity", true, logs4, {"name": "Gravity", "power": 0, "type": "Psychic", "cat": "Status", "acc": 100})
	if str(carrier.get("airborne_move", "")) != "":
		print("  Gravity did not bring the Sky Drop carrier down. ", str(logs4))
		return false
	if bool(target.get("held_in_sky", false)):
		print("  Gravity did not free the held target. ", str(logs4))
		return false
	if not str(logs4).contains("was brought down by Gravity"):
		print("  Gravity vs Sky Drop: no brought-down log. ", str(logs4))
		return false
	return true


## Psychic Noise is a damaging move whose secondary is Heal
## Block for 2 turns, on its own counter: the Heal Block
## move's counter stays untouched, Recover and Giga Drain do
## not heal while it is up, Leftovers does not heal at the end
## of the turn, and Recover works again once the counter has
## ticked out at the end of two turns.
func test_psychic_noise_heal_block() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Alakazam", ["psychic"], ["Psychic Noise"], {"hp": 300, "max_hp": 300})
	var target: Dictionary = _mon("Blissey", ["normal"], ["Recover", "Giga Drain"], {"hp": 500, "max_hp": 500, "item": "Leftovers"})
	c.start_battle([user], [target], "singles")
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(user, target, "Psychic Noise", true, logs, {"name": "Psychic Noise", "power": 75, "type": "Psychic", "cat": "Special", "acc": 100, "secondary": {"chance": 100, "volatileStatus": "healblock"}})
	if int(target.get("noise_heal_block_turns", 0)) != 2:
		print("  Psychic Noise did not set its 2-turn block, turns = ", int(target.get("noise_heal_block_turns", 0)), ". ", str(logs))
		return false
	if int(target.get("heal_block_turns", 0)) != 0:
		print("  Psychic Noise touched the Heal Block move's counter.")
		return false
	if not str(logs).contains("was prevented from healing"):
		print("  Psychic Noise: no prevented-from-healing log. ", str(logs))
		return false
	var hp_after_noise: int = int(target.get("hp", 0))
	if hp_after_noise <= 0 or hp_after_noise >= 500:
		print("  Psychic Noise setup: target hp = ", hp_after_noise, ", wanted between 1 and 499.")
		return false
	# Recover does not heal while blocked.
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(target, user, "Recover", false, logs2, {"name": "Recover", "power": 0, "type": "Normal", "cat": "Status", "acc": 100, "heal_self": 0.5})
	if int(target.get("hp", 0)) != hp_after_noise:
		print("  Psychic Noise block: Recover healed anyway, hp = ", int(target.get("hp", 0)))
		return false
	# Giga Drain does not heal the blocked user either.
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(target, user, "Giga Drain", false, logs3, {"name": "Giga Drain", "power": 75, "type": "Grass", "cat": "Special", "acc": 100, "drain": 0.5})
	if int(target.get("hp", 0)) != hp_after_noise:
		print("  Psychic Noise block: Giga Drain healed anyway, hp = ", int(target.get("hp", 0)))
		return false
	if int(user.get("hp", 0)) >= 300:
		print("  Psychic Noise block setup: Giga Drain dealt no damage, so the drain check proves nothing.")
		return false
	# Leftovers does not heal at the end of the turn, and the
	# counter ticks 2 -> 1.
	var logs4: Array = []
	c._end_of_turn(logs4)
	if int(target.get("hp", 0)) != hp_after_noise:
		print("  Psychic Noise block: Leftovers healed anyway, hp = ", int(target.get("hp", 0)))
		return false
	if int(target.get("noise_heal_block_turns", 0)) != 1:
		print("  Psychic Noise block should tick to 1, turns = ", int(target.get("noise_heal_block_turns", 0)))
		return false
	# One more end of turn ticks it out; Recover heals again.
	var logs5: Array = []
	c._end_of_turn(logs5)
	if int(target.get("noise_heal_block_turns", 0)) != 0:
		print("  Psychic Noise block should have worn off, turns = ", int(target.get("noise_heal_block_turns", 0)))
		return false
	if not str(logs5).contains("Heal Block from Psychic Noise wore off"):
		print("  Psychic Noise block: no wore-off log. ", str(logs5))
		return false
	var hp_before_recover: int = int(target.get("hp", 0))
	c.rng.seed = 5
	var logs6: Array = []
	c._execute_move(target, user, "Recover", false, logs6, {"name": "Recover", "power": 0, "type": "Normal", "cat": "Status", "acc": 100, "heal_self": 0.5})
	if int(target.get("hp", 0)) <= hp_before_recover:
		print("  After the block wore off, Recover still did not heal, hp = ", int(target.get("hp", 0)))
		return false
	return true


## Leech Seed: the seeded mon loses 1/8 max HP at the end of
## the turn and the seeder heals by the same amount. A seeded
## Liquid Ooze mon turns the heal into damage. Grass types
## cannot be seeded.
func test_leech_seed_drain_and_liquid_ooze() -> bool:
	var c: BattleController = _new_controller()
	var seeder: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Leech Seed"], {"hp": 50})
	var target: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([seeder], [target], "singles")
	c.rng.seed = 5
	var seed_move: Dictionary = {"name": "Leech Seed", "power": 0, "type": "Grass", "cat": "Status", "acc": 100, "volatileStatus": "leechseed"}
	var logs: Array = []
	c._execute_move(seeder, target, "Leech Seed", true, logs, seed_move)
	if not bool(target.get("leech_seeded", false)):
		print("  Leech Seed did not seed the target. ", str(logs))
		return false
	var logs2: Array = []
	c._end_of_turn(logs2)
	if int(target.get("hp", 0)) != 88:
		print("  Leech Seed drain: target hp = ", int(target.get("hp", 0)), ", wanted 88.")
		return false
	if int(seeder.get("hp", 0)) != 62:
		print("  Leech Seed heal: seeder hp = ", int(seeder.get("hp", 0)), ", wanted 62.")
		return false
	# Liquid Ooze: the seeder is hurt instead of healed.
	var seeder2: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Leech Seed"], {"hp": 50})
	var ooze: Dictionary = _mon("Tentacruel", ["water", "poison"], ["Tackle"], {"ability": "Liquid Ooze"})
	c.start_battle([seeder2], [ooze], "singles")
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(seeder2, ooze, "Leech Seed", true, logs3, seed_move)
	var logs4: Array = []
	c._end_of_turn(logs4)
	if int(ooze.get("hp", 0)) != 88:
		print("  Liquid Ooze Leech Seed drain: target hp = ", int(ooze.get("hp", 0)), ", wanted 88.")
		return false
	if int(seeder2.get("hp", 0)) != 38:
		print("  Liquid Ooze Leech Seed: seeder hp = ", int(seeder2.get("hp", 0)), ", wanted 38 (hurt, not healed).")
		return false
	if not str(logs4).contains("hurt by Liquid Ooze"):
		print("  Liquid Ooze Leech Seed: no ooze log. ", str(logs4))
		return false
	# Grass types cannot be seeded.
	var seeder3: Dictionary = _mon("Venusaur", ["grass", "poison"], ["Leech Seed"])
	var grassy: Dictionary = _mon("Oddish", ["grass", "poison"], ["Tackle"])
	c.start_battle([seeder3], [grassy], "singles")
	c.rng.seed = 5
	var logs5: Array = []
	c._execute_move(seeder3, grassy, "Leech Seed", true, logs5, seed_move)
	if bool(grassy.get("leech_seeded", false)):
		print("  Leech Seed seeded a Grass type.")
		return false
	return true


## Strength Sap: the user heals by the target's Attack stat,
## then the target's Attack drops. Against Liquid Ooze the
## heal becomes damage. At Attack -6 the move fails.
func test_strength_sap_and_liquid_ooze() -> bool:
	var c: BattleController = _new_controller()
	var user: Dictionary = _mon("Shiinotic", ["grass", "fairy"], ["Strength Sap"], {"hp": 50, "max_hp": 200})
	var target: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"], {"atk": 100})
	c.start_battle([user], [target], "singles")
	c.rng.seed = 5
	var sap: Dictionary = {"name": "Strength Sap", "power": 0, "type": "Grass", "cat": "Status", "acc": 100}
	var logs: Array = []
	c._execute_move(user, target, "Strength Sap", true, logs, sap)
	if int(user.get("hp", 0)) != 150:
		print("  Strength Sap heal: user hp = ", int(user.get("hp", 0)), ", wanted 150.")
		return false
	var t_stages: Dictionary = target.get("stages", {})
	if int(t_stages.get("atk", 0)) != -1:
		print("  Strength Sap: target Attack stage = ", int(t_stages.get("atk", 0)), ", wanted -1.")
		return false
	# Liquid Ooze target: damage instead of healing.
	var user2: Dictionary = _mon("Shiinotic", ["grass", "fairy"], ["Strength Sap"], {"hp": 150, "max_hp": 200})
	var ooze: Dictionary = _mon("Tentacruel", ["water", "poison"], ["Tackle"], {"ability": "Liquid Ooze", "atk": 100})
	c.start_battle([user2], [ooze], "singles")
	c.rng.seed = 5
	var logs2: Array = []
	c._execute_move(user2, ooze, "Strength Sap", true, logs2, sap)
	if int(user2.get("hp", 0)) != 50:
		print("  Strength Sap vs Liquid Ooze: user hp = ", int(user2.get("hp", 0)), ", wanted 50.")
		return false
	var o_stages: Dictionary = ooze.get("stages", {})
	if int(o_stages.get("atk", 0)) != -1:
		print("  Strength Sap vs Liquid Ooze: the Attack drop should still happen.")
		return false
	# Attack already at -6: the move fails, nothing changes.
	var user3: Dictionary = _mon("Shiinotic", ["grass", "fairy"], ["Strength Sap"], {"hp": 50, "max_hp": 200})
	var floored: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"], {"atk": 100, "stages": {"atk": -6, "def": 0, "spa": 0, "spd": 0, "spe": 0}})
	c.start_battle([user3], [floored], "singles")
	c.rng.seed = 5
	var logs3: Array = []
	c._execute_move(user3, floored, "Strength Sap", true, logs3, sap)
	if int(user3.get("hp", 0)) != 50:
		print("  Strength Sap at Attack -6 should fail with no heal.")
		return false
	# (Log lines are checked one by one: str(logs) escapes
	# apostrophes, so it cannot match "won't".)
	var found_fail: bool = false
	for line in logs3:
		if str(line).contains("won't go lower"):
			found_fail = true
	return found_fail


## Commander: while Tatsugiri is inside Dondozo, neither of
## the pair can be forced out (Roar through the shared
## drag-out path) and Dondozo cannot switch out on its own.
func test_commander_no_forced_switch() -> bool:
	var c: BattleController = _new_controller()
	var tatsugiri: Dictionary = _mon("Tatsugiri", ["dragon", "water"], ["Dragon Pulse"], {"species": "Tatsugiri", "ability": "Commander"})
	var dondozo: Dictionary = _mon("Dondozo", ["water"], ["Waterfall"], {"species": "Dondozo"})
	var bench: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"])
	c.start_battle([tatsugiri, dondozo, bench], [_mon("Snorlax", ["normal"], ["Tackle"]), _mon("Pidgey", ["normal", "flying"], ["Tackle"])], "doubles")
	if not bool(dondozo.get("commanded", false)):
		print("  Commander did not trigger in the setup.")
		return false
	# Roar against Dondozo (player slot 1): refused.
	var logs: Array = []
	var res: String = c._handle_forced_switch(true, {"name": "Roar"}, logs, 1)
	if res != "blocked":
		print("  Roar on a commanded Dondozo returned ", res, ", wanted blocked.")
		return false
	if str(c.player_party[1].get("name", "")) != "Dondozo":
		print("  Dondozo was dragged out anyway.")
		return false
	if not str(logs).contains("cannot be forced out"):
		print("  Commander drag-out block: no log. ", str(logs))
		return false
	# Roar against Tatsugiri (player slot 0): refused too.
	var logs2: Array = []
	var res2: String = c._handle_forced_switch(true, {"name": "Roar"}, logs2, 0)
	if res2 != "blocked":
		print("  Roar on a commanding Tatsugiri returned ", res2, ", wanted blocked.")
		return false
	# Dondozo cannot switch out voluntarily either. (Log
	# lines checked one by one: str(logs) escapes the
	# apostrophe in "can't".)
	var logs3: Array = []
	c._perform_action_doubles({"type": "switch", "target_idx": 2}, true, 1, logs3)
	var found_refusal: bool = false
	for line in logs3:
		if str(line).contains("can't switch out"):
			found_refusal = true
	if not found_refusal:
		print("  Commanded Dondozo switch: no refusal log. ", str(logs3))
		return false
	if str(c.player_party[1].get("name", "")) != "Dondozo":
		print("  Dondozo switched out anyway.")
		return false
	return true


## Red Card: a standing holder's card drags the attacker
## out and swaps in the next bench mon. The card is used up.
func test_red_card_drags_out_attacker() -> bool:
	var c: BattleController = _new_controller()
	var holder: Dictionary = _mon("Snorlax", ["normal"], ["Tackle"], {"item": "Red Card"})
	var attacker: Dictionary = _mon("Machamp", ["fighting"], ["Tackle"])
	var bench: Dictionary = _mon("Pidgey", ["normal", "flying"], ["Tackle"])
	c.start_battle([holder], [attacker, bench], "singles")
	c.rng.seed = 5
	var logs: Array = []
	c._execute_move(attacker, holder, "Tackle", false, logs)
	if str(holder.get("item", "")) != "":
		print("  Red Card was not consumed; item = ", str(holder.get("item", "")))
		return false
	if str(c.enemy_party[0].get("name", "")) != "Pidgey":
		print("  Red Card did not drag the attacker out; lead is ", str(c.enemy_party[0].get("name", "")))
		return false
	if not str(logs).contains("Red Card"):
		print("  Red Card: no log. ", str(logs))
		return false
	return true


## Evolution hook: when a mon levels up through the EXP flow
## (_give_exp), the Evolution Manager (v6) is asked, and a
## Magikarp that reaches level 20 becomes a Gyarados in the
## same dict. Below level 20 nothing happens. Trade species
## are covered by the v6 pack's own tests.
func test_evolution_on_level_up_hook() -> bool:
	var c: BattleController = _new_controller()
	# Slow growth: level 19 starts at 8,573 total EXP and
	# level 20 at 10,000. 9,000 + 500 stays at 19;
	# 9,000 + 1,500 crosses into 20.
	var stay: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"level": 19, "exp": 9000, "exp_is_total": true, "growth_rate": "slow"})
	var logs: Array = []
	c._give_exp(stay, 500, logs)
	if int(stay.get("level", 0)) != 19:
		print("  Evolution hook setup: the control Magikarp did not stay at 19 (level ", int(stay.get("level", 0)), ").")
		return false
	if str(stay.get("species", "")) != "Magikarp":
		print("  A level 19 Magikarp evolved early into ", str(stay.get("species", "")), ".")
		return false
	var evo: Dictionary = _mon("Magikarp", ["water"], ["Splash"], {"level": 19, "exp": 9000, "exp_is_total": true, "growth_rate": "slow"})
	var logs2: Array = []
	c._give_exp(evo, 1500, logs2)
	if int(evo.get("level", 0)) != 20:
		print("  Evolution hook setup: Magikarp did not reach 20 (level ", int(evo.get("level", 0)), ").")
		return false
	if str(evo.get("species", "")) != "Gyarados":
		print("  Level 20 Magikarp species is ", str(evo.get("species", "")), ", wanted Gyarados.")
		return false
	if not str(logs2).contains("evolved into"):
		print("  Evolution hook: no evolution log. ", str(logs2))
		return false
	return true


## ------------------------------------------------------------------
## Gimmick budgets (hub register 9.2): five budgets per side —
## Mega, Z-Move, Dynamax, Gigantamax, Terastallization — each
## category once per side per battle, and one Pokemon may use
## only ONE category per battle. These tests drive
## BattleController._apply_gimmick / _apply_z_move directly,
## the way the Teraform Zero tests drive _apply_gimmick.
## ------------------------------------------------------------------

## Budget test 1 — the categories are independent: Mega on the
## player's Charizard spends only the Mega budget, and a
## DIFFERENT player Pokemon can still Terastallize.
func test_gimmick_budget_categories_independent() -> bool:
	var c: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var pikachu: Dictionary = _mon("Pikachu", ["Electric"], ["Thunderbolt"])
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	c.start_battle([charizard, pikachu], [foe], "singles")
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, c.player_party[0], logs, true)
	if not bool(c.player_party[0].get("mega_evolved", false)):
		print("  Budget setup: Charizard did not Mega Evolve. ", str(logs))
		return false
	if str(c.player_party[0].get("gimmick_category_used", "")) != "mega":
		print("  Charizard's gimmick marker was '%s', wanted 'mega'." % str(c.player_party[0].get("gimmick_category_used", "")))
		return false
	var budgets: Dictionary = c.battle_state.get("gimmick_budgets", {})
	var player_budgets: Dictionary = budgets.get("player", {})
	if not bool(player_budgets.get("mega", false)):
		print("  The player's Mega budget was not spent after Mega Evolving.")
		return false
	if bool(player_budgets.get("tera", false)):
		print("  The player's Tera budget was spent by a Mega Evolution; budgets must be per category.")
		return false
	c._apply_gimmick({"type": "move", "gimmick": "tera", "tera_type": "Fire", "move_name": "Thunderbolt"}, c.player_party[1], logs, true)
	if not bool(c.player_party[1].get("tera_active", false)):
		print("  Pikachu could not Terastallize after Charizard Mega Evolved; budgets must be per category. ", str(logs))
		return false
	if str(c.player_party[1].get("gimmick_category_used", "")) != "tera":
		print("  Pikachu's gimmick marker was '%s', wanted 'tera'." % str(c.player_party[1].get("gimmick_category_used", "")))
		return false
	return true


## Budget test 2 — one Mega per SIDE: after the player's
## Charizard Mega Evolves, a Mega attempt by the player's
## Venusaur is refused and spends nothing.
func test_gimmick_budget_one_mega_per_side() -> bool:
	var c: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var venusaur: Dictionary = _mon("Venusaur", ["Grass", "Poison"], ["Energy Ball"], {"item": "Venusaurite"})
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	c.start_battle([charizard, venusaur], [foe], "singles")
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, c.player_party[0], logs, true)
	if not bool(c.player_party[0].get("mega_evolved", false)):
		print("  Budget setup: Charizard did not Mega Evolve. ", str(logs))
		return false
	var refuse_logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Energy Ball"}, c.player_party[1], refuse_logs, true)
	if bool(c.player_party[1].get("mega_evolved", false)):
		print("  Venusaur Mega Evolved even though the player's Mega budget was already spent.")
		return false
	if str(c.player_party[1].get("gimmick_category_used", "")) != "":
		print("  A refused Mega still stamped Venusaur's gimmick marker.")
		return false
	if not str(refuse_logs).contains("already used its mega"):
		print("  The refused Mega logged no clear reason. ", str(refuse_logs))
		return false
	return true


## Budget test 3 — one category per POKEMON: a Charizard that
## Mega Evolved cannot also fire a Z-Move, even though the
## side's Z-Move budget is untouched. A different Pokemon on
## the same side CAN still use that Z-Move budget.
func test_gimmick_budget_one_category_per_mon() -> bool:
	var c: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var pikachu: Dictionary = _mon("Pikachu", ["Electric"], ["Thunderbolt"])
	var foe: Dictionary = _mon("Snorlax", ["Normal"], ["Quick Attack"])
	c.start_battle([charizard, pikachu], [foe], "singles")
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, c.player_party[0], logs, true)
	if not bool(c.player_party[0].get("mega_evolved", false)):
		print("  Budget setup: Charizard did not Mega Evolve. ", str(logs))
		return false
	var zlogs: Array = []
	var zres: Dictionary = c._apply_z_move({"type": "move", "z_crystal": "Firium Z", "move_name": "Flamethrower"}, "Flamethrower", zlogs, c.player_party[0], true)
	if str(zres.get("move_name", "")) != "Flamethrower":
		print("  The Mega Evolved Charizard fired a Z-Move ('%s'); one Pokemon gets only one gimmick category." % str(zres.get("move_name", "")))
		return false
	var zoverride: Dictionary = zres.get("override", {})
	if not zoverride.is_empty():
		print("  The refused Z-Move still produced an override.")
		return false
	if not str(zlogs).contains("already used its mega"):
		print("  The refused Z-Move logged no clear reason. ", str(zlogs))
		return false
	# The side's Z-Move budget itself is still free: Pikachu,
	# which has used no category, can fire its Z-Move.
	var zlogs2: Array = []
	var zres2: Dictionary = c._apply_z_move({"type": "move", "z_crystal": "Electrium Z", "move_name": "Thunderbolt"}, "Thunderbolt", zlogs2, c.player_party[1], true)
	if str(zres2.get("move_name", "")) != "Gigavolt Havoc":
		print("  Pikachu's Z-Move was '%s', wanted 'Gigavolt Havoc'. ", str(zres2.get("move_name", "")), str(zlogs2))
		return false
	if str(c.player_party[1].get("gimmick_category_used", "")) != "zmove":
		print("  Pikachu's gimmick marker was '%s', wanted 'zmove'." % str(c.player_party[1].get("gimmick_category_used", "")))
		return false
	return true


## Budget test 4 — the budgets are per SIDE: after the player's
## Mega, the enemy's Gengar can still Mega Evolve.
func test_gimmick_budget_per_side() -> bool:
	var c: BattleController = _new_controller()
	var charizard: Dictionary = _mon("Charizard", ["Fire", "Flying"], ["Flamethrower"], {"item": "Charizardite X"})
	var gengar: Dictionary = _mon("Gengar", ["Ghost", "Poison"], ["Shadow Ball"], {"item": "Gengarite"})
	c.start_battle([charizard], [gengar], "singles")
	var logs: Array = []
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Flamethrower"}, c.player_party[0], logs, true)
	if not bool(c.player_party[0].get("mega_evolved", false)):
		print("  Budget setup: Charizard did not Mega Evolve. ", str(logs))
		return false
	c._apply_gimmick({"type": "move", "gimmick": "mega", "move_name": "Shadow Ball"}, c.enemy_party[0], logs, false)
	if not bool(c.enemy_party[0].get("mega_evolved", false)):
		print("  The enemy Gengar could not Mega Evolve after the player's Mega; budgets must be per side. ", str(logs))
		return false
	if str(c.enemy_party[0].get("forme", "")) != "Gengar-Mega":
		print("  Enemy Gengar's forme was '%s', wanted 'Gengar-Mega'." % str(c.enemy_party[0].get("forme", "")))
		return false
	var budgets: Dictionary = c.battle_state.get("gimmick_budgets", {})
	var enemy_budgets: Dictionary = budgets.get("enemy", {})
	if not bool(enemy_budgets.get("mega", false)):
		print("  The enemy's Mega budget was not spent by the enemy's Mega Evolution.")
		return false
	return true


## ------------------------------------------------------------------
## Battle formats (same RC1 doc)
## ------------------------------------------------------------------

## Inverse Battle, calculator level: with the field flag on, a
## Ground move hits a Flying-type defender (normally immune),
## and a normally 2x matchup is halved. Same seed before every
## call, so the random factor and crit roll match.
func test_inverse_battle_type_chart() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var attacker: Dictionary = _mon("Dugtrio", ["Ground"], ["Earthquake"], {"atk": 100, "spa": 100})
	var flying: Dictionary = _mon("Pidgeot", ["Normal", "Flying"], ["Quick Attack"], {"def": 80, "spd": 80})
	var quake: Dictionary = {"name": "Earthquake", "type": "Ground", "cat": "Physical", "power": 100}
	rng.seed = 99
	var plain: Dictionary = PUWBattleEngine.calculate_damage(attacker, flying, quake, rng)
	if int(plain.get("damage", -1)) != 0:
		print("  Without Inverse, Earthquake did %s damage to a Flying type, wanted 0." % str(plain.get("damage", -1)))
		return false
	if float(plain.get("effectiveness", 1.0)) != 0.0:
		print("  Without Inverse, Earthquake effectiveness vs Flying was %s, wanted 0.0." % str(plain.get("effectiveness", 1.0)))
		return false
	var inverse_field: Dictionary = {"inverse_battle": true}
	attacker["field"] = inverse_field
	flying["field"] = inverse_field
	rng.seed = 99
	var flipped: Dictionary = PUWBattleEngine.calculate_damage(attacker, flying, quake, rng)
	if float(flipped.get("effectiveness", 0.0)) != 2.0:
		print("  Under Inverse, Earthquake effectiveness vs Flying was %s, wanted 2.0 (0x becomes 2x)." % str(flipped.get("effectiveness", 0.0)))
		return false
	if int(flipped.get("damage", 0)) <= 0:
		print("  Under Inverse, Earthquake did no damage to a Flying type.")
		return false
	# A normally 2x matchup is halved: Water vs a pure Fire type.
	var water_attacker: Dictionary = _mon("Blastoise", ["Water"], ["Surf"], {"atk": 100, "spa": 100})
	var fire_defender: Dictionary = _mon("Flareon", ["Fire"], ["Quick Attack"], {"def": 80, "spd": 80})
	var surf: Dictionary = {"name": "Surf", "type": "Water", "cat": "Special", "power": 90}
	rng.seed = 99
	var plain2: Dictionary = PUWBattleEngine.calculate_damage(water_attacker, fire_defender, surf, rng)
	if float(plain2.get("effectiveness", 0.0)) != 2.0:
		print("  Without Inverse, Surf effectiveness vs Fire was %s, wanted 2.0." % str(plain2.get("effectiveness", 0.0)))
		return false
	water_attacker["field"] = inverse_field
	fire_defender["field"] = inverse_field
	rng.seed = 99
	var flipped2: Dictionary = PUWBattleEngine.calculate_damage(water_attacker, fire_defender, surf, rng)
	if float(flipped2.get("effectiveness", 0.0)) != 0.5:
		print("  Under Inverse, Surf effectiveness vs Fire was %s, wanted 0.5 (2x becomes 0.5x)." % str(flipped2.get("effectiveness", 0.0)))
		return false
	if not (int(flipped2.get("damage", 0)) < int(plain2.get("damage", 0))):
		print("  Under Inverse, Surf damage %s was not lower than the plain %s." % [str(flipped2.get("damage", 0)), str(plain2.get("damage", 0))])
		return false
	return true


## Inverse Battle, wiring level: start_battle with the
## "inverse_battle" format sets the flag on the field state,
## run_turn carries it onto a caller-supplied field state, and
## a Ground move then really hits a Flying-type enemy through
## the full turn loop (in a plain singles battle it cannot).
func test_inverse_battle_format_flag() -> bool:
	var c: BattleController = _new_controller()
	var ground_mon: Dictionary = _mon("Dugtrio", ["Ground"], ["Earthquake"], {"atk": 100, "spa": 100})
	var bird: Dictionary = _mon("Pidgeot", ["Normal", "Flying"], ["Quick Attack"], {"def": 80, "spd": 80})
	c.start_battle([ground_mon], [bird], "inverse_battle", true)
	if not bool(c.field_state.get("inverse_battle", false)):
		print("  start_battle('inverse_battle') did not set field_state['inverse_battle'].")
		return false
	var field: Dictionary = StatusAndFieldEngine.create_field_state()
	var bird_hp_before: int = int(c.enemy_party[0].get("hp", 0))
	c.run_turn({"type": "move", "move_name": "Earthquake"}, field)
	if not bool(field.get("inverse_battle", false)):
		print("  run_turn did not carry the inverse_battle flag onto the caller's field state.")
		return false
	if not (int(c.enemy_party[0].get("hp", 0)) < bird_hp_before):
		print("  Under Inverse, a full-turn Earthquake did not hurt the Flying-type enemy (hp %s of %s)." % [str(c.enemy_party[0].get("hp", 0)), str(bird_hp_before)])
		return false
	# Control: the same hit in a plain singles battle is immune.
	var c2: BattleController = _new_controller()
	var ground_mon2: Dictionary = _mon("Dugtrio", ["Ground"], ["Earthquake"], {"atk": 100, "spa": 100})
	var bird2: Dictionary = _mon("Pidgeot", ["Normal", "Flying"], ["Quick Attack"], {"def": 80, "spd": 80})
	c2.start_battle([ground_mon2], [bird2], "singles", true)
	if bool(c2.field_state.get("inverse_battle", false)):
		print("  A plain singles battle had the inverse_battle flag set.")
		return false
	var field2: Dictionary = StatusAndFieldEngine.create_field_state()
	var bird2_hp_before: int = int(c2.enemy_party[0].get("hp", 0))
	c2.run_turn({"type": "move", "move_name": "Earthquake"}, field2)
	if int(c2.enemy_party[0].get("hp", 0)) != bird2_hp_before:
		print("  In plain singles, Earthquake hurt a Flying-type enemy (hp %s of %s); it should be immune." % [str(c2.enemy_party[0].get("hp", 0)), str(bird2_hp_before)])
		return false
	return true


## Sky Battle gate: Flying types and Levitate Pokemon may
## take part; everything else is locked out and named.
func test_sky_battle_eligibility() -> bool:
	var pidgey: Dictionary = _mon("Pidgey", ["Normal", "Flying"], ["Quick Attack"])
	if not PUWBattleFormats.sky_battle_eligible(pidgey):
		print("  Pidgey (Flying type) was refused by the Sky Battle gate.")
		return false
	var pikachu: Dictionary = _mon("Pikachu", ["Electric"], ["Thunderbolt"])
	if PUWBattleFormats.sky_battle_eligible(pikachu):
		print("  Pikachu (Electric, no Levitate) passed the Sky Battle gate.")
		return false
	var bronzong: Dictionary = _mon("Bronzong", ["Steel", "Psychic"], ["Psychic"], {"ability": "Levitate"})
	if not PUWBattleFormats.sky_battle_eligible(bronzong):
		print("  Bronzong with Levitate was refused by the Sky Battle gate.")
		return false
	var bronzong_slug: Dictionary = _mon("Bronzong", ["Steel", "Psychic"], ["Psychic"], {"ability": "levitate"})
	if not PUWBattleFormats.sky_battle_eligible(bronzong_slug):
		print("  Bronzong with the slug ability 'levitate' was refused by the Sky Battle gate.")
		return false
	var check: Dictionary = PUWBattleFormats.sky_battle_check([pidgey, pikachu, bronzong])
	if bool(check.get("ok", true)):
		print("  sky_battle_check passed a party holding a ground-bound Pikachu.")
		return false
	var refused: Array = check.get("refused", [])
	if refused != ["Pikachu"]:
		print("  sky_battle_check refused ", str(refused), ", wanted ['Pikachu'].")
		return false
	var ok_check: Dictionary = PUWBattleFormats.sky_battle_check([pidgey, bronzong])
	if not bool(ok_check.get("ok", false)):
		print("  sky_battle_check refused an all-flying/levitate party.")
		return false
	return true


## VGC team pick: Bring-6-Pick-4 at Lv.50 Flat. The picked
## copies come back at level 50, the originals stay untouched,
## and bad picks (wrong count, duplicates, out of range) are
## refused with a reason.
func test_vgc_select_team() -> bool:
	var party: Array = []
	for i in range(6):
		party.append(_mon("Mon" + str(i), ["Normal"], ["Quick Attack"], {"level": 100}))
	var res: Dictionary = PUWBattleFormats.vgc_select_team(party, [0, 2, 3, 5])
	if not bool(res.get("ok", false)):
		print("  VGC pick [0,2,3,5] was refused: ", str(res.get("reason", "")))
		return false
	var team: Array = res.get("team", [])
	if team.size() != 4:
		print("  VGC team had %s Pokemon, wanted 4." % str(team.size()))
		return false
	var want_names: Array = ["Mon0", "Mon2", "Mon3", "Mon5"]
	for i in range(4):
		var member: Dictionary = team[i]
		if str(member.get("name", "")) != str(want_names[i]):
			print("  VGC team slot %s was '%s', wanted '%s'." % [str(i), str(member.get("name", "")), str(want_names[i])])
			return false
		if int(member.get("level", 0)) != 50:
			print("  VGC team member %s was level %s, wanted 50 (Lv.50 Flat)." % [str(i), str(member.get("level", 0))])
			return false
	for i in range(6):
		var original: Dictionary = party[i]
		if int(original.get("level", 0)) != 100:
			print("  VGC pick changed the original party: slot %s is level %s, wanted 100." % [str(i), str(original.get("level", 0))])
			return false
	var dup: Dictionary = PUWBattleFormats.vgc_select_team(party, [0, 0, 1, 2])
	if bool(dup.get("ok", false)):
		print("  VGC accepted duplicate picks [0,0,1,2].")
		return false
	var short: Dictionary = PUWBattleFormats.vgc_select_team(party, [0, 1])
	if bool(short.get("ok", false)):
		print("  VGC accepted only 2 picks.")
		return false
	var out_of_range: Dictionary = PUWBattleFormats.vgc_select_team(party, [0, 1, 2, 6])
	if bool(out_of_range.get("ok", false)):
		print("  VGC accepted the out-of-range pick 6.")
		return false
	return true
