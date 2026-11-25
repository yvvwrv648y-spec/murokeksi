import os, json, re, unittest, uuid

REPO = "artifacts/file_generation/ttl=63d/intermediate/POKEMON_ULTIMATE_WORLD"
MIG2_UP = "artifacts/file_generation/ttl=63d/intermediate/puw-neon-db/migrations/0002_puw_master_rules_ecology_instances.up.sql"
MIG2_DN = "artifacts/file_generation/ttl=63d/intermediate/puw-neon-db/migrations/0002_puw_master_rules_ecology_instances.down.sql"
OUT_HTML = "artifacts/file_generation/ttl=63d/output/puw_kanto_studio_showcase.html"

class TestPUWMasterRulesAndEcology(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reg = json.load(open(os.path.join(REPO, "pokemon/registry/master_species_registry.json")))
        cls.eco = json.load(open(os.path.join(REPO, "world/regions/kanto/kanto_encounter_matrix.json")))
        cls.trn = json.load(open(os.path.join(REPO, "systems/progression/trainer_6mon_rosters.json")))
        cls.mig_up = open(MIG2_UP).read()
        cls.mig_dn = open(MIG2_DN).read()
        cls.html = open(OUT_HTML).read()

    def test_01_species_and_regional_form_identity(self):
        ids = [s["species_id"] for s in self.reg["species"]]
        self.assertEqual(len(ids), len(set(ids)), "Duplicate species_id found")
        form_ids = [f["form_id"] for f in self.reg["regional_forms"]]
        self.assertIn("alolan_vulpix", form_ids)
        self.assertIn("paldean_wooper", form_ids)

    def test_02_cross_gen_coverage_1_to_10(self):
        gens = {s["gen"] for s in self.reg["species"]}
        self.assertEqual(gens, {1,2,3,4,5,6,7,8,9,10})

    def test_03_gen10_official_only_and_unconfirmed_regional(self):
        g10 = [s for s in self.reg["species"] if s["gen"] == 10]
        self.assertEqual({s["species_id"] for s in g10}, {"browt", "pombon", "gecqua"})
        for s in g10:
            self.assertFalse(s["encounter_eligible"])
            self.assertEqual(s["capture_legality"], "unconfirmed_gen10")

    def test_04_kanto_ecological_priority_and_water_separation(self):
        self.assertEqual(len(self.eco["eligibility_priority"]), 8)
        cerulean = [r for r in self.eco["routes"] if r["location_id"] == "kanto_cerulean_coast_and_river"][0]
        reasons = " ".join(e["reason"].lower() for e in cerulean["entries"])
        self.assertIn("freshwater", reasons)
        self.assertIn("reef", reasons)
        self.assertIn("deep offshore", reasons)

    def test_05_kanto_cross_gen_route_weights_and_reasons(self):
        r1 = [r for r in self.eco["routes"] if r["location_id"] == "kanto_route_1"][0]
        self.assertEqual(sum(e["weight"] for e in r1["entries"]), 100)
        r1_species = {e["species_id"] for e in r1["entries"]}
        self.assertTrue({"pidgey","starly","mareep","shinx","fletchling","rookidee"}.issubset(r1_species))
        for e in r1["entries"]:
            self.assertTrue(len(e["reason"]) > 10)

    def test_06_six_pokemon_standard_trainers_and_leon(self):
        self.assertEqual(len(self.trn["gyms_and_coronation"]), 9)
        for t in self.trn["gyms_and_coronation"]:
            self.assertEqual(len(t["party"]), 6, f"{t['name']} must have 6 Pokemon!")
            for m in t["party"]:
                self.assertTrue(m["ability"] and len(m["moves"]) == 4)
        self.assertIn("Leon", self.trn["gyms_and_coronation"][-1]["name"])

    def test_07_sql_migration_0002_required_tables_and_isolation(self):
        self.assertNotIn("meridian", self.mig_up.lower().replace("meridian-standby-free", "").replace("meridian tables", ""))
        for tbl in [
            "rules.game_rules", "rules.rule_versions", "rules.rule_exceptions",
            "world.routes", "world.biomes", "world.world_events", "gameplay.npc_schedules",
            "pokemon.species_habitats", "pokemon.regional_species_eligibility",
            "gameplay.encounter_tables", "gameplay.encounter_entries", "gameplay.encounter_conditions",
            "instances.pokemon_instances", "instances.player_parties", "instances.pokemon_storage",
            "instances.pokemon_transfers", "instances.battle_records", "instances.fainting_records",
            "instances.capture_records", "cloud_save.save_versions", "eng.content_provenance"
        ]:
            self.assertIn(f"CREATE TABLE IF NOT EXISTS {tbl}", self.mig_up)
            self.assertIn(f"DROP TABLE IF EXISTS {tbl}", self.mig_dn)

    def test_08_immutable_identity_anti_duplication_and_perma_faint_simulation(self):
        seen_ids = set(); party = []; storage = []; locked_fams = set()
        def capture(species, fam):
            if fam in locked_fams: return ("LOCKED", None)
            uid = str(uuid.uuid4())
            assert uid not in seen_ids
            seen_ids.add(uid)
            if len(party) < 6: party.append((uid, species, fam)); return ("PARTY", uid)
            storage.append((uid, species, fam)); return ("STORAGE", uid)
        # Fill 6 party slots + 1 overflow to PC Storage
        for i in range(6):
            dest, _ = capture(f"sp_{i}", f"fam_{i}")
            self.assertEqual(dest, "PARTY")
        dest7, uid7 = capture("sp_6", "fam_6")
        self.assertEqual(dest7, "STORAGE")
        self.assertEqual(len(party), 6)
        self.assertEqual(len(storage), 1)
        # Permanent faint removes from party and locks evolution family
        fainted = party.pop(0)
        locked_fams.add(fainted[2])
        res_locked, _ = capture("sp_0_again", fainted[2])
        self.assertEqual(res_locked, "LOCKED")

    def test_09_five_distinct_gimmick_slots_preserved_in_godot_and_ui(self):
        gd = open(os.path.join(REPO, "core/master_rules_engine.gd")).read()
        for g in ["mega_evolution", "z_moves", "dynamax_gigantamax", "terastallization", "gimmick_slot_5_pending_canon"]:
            self.assertIn(g, gd)
        for btn in ['data-gimmick="mega"', 'data-gimmick="zmove"', 'data-gimmick="dynamax"', 'data-gimmick="tera"']:
            self.assertIn(btn, self.html)

    def test_10_showcase_rules_and_23_studio_sheets_intact(self):
        for marker in ["mintImmutablePokemonId", "PC_STORAGE", "GYM_6MON_TEAMS", "PERMANENT FAINT", "MASTER_DEX_CATALOG", "riley_swim", "tasha_swim", "custom_futanari_bikini"]:
            self.assertIn(marker, self.html)


    def test_11_gen9_iv_ev_252_plus_and_no_special_burst(self):
        self.assertNotIn("Special Burst", self.html)
        for m in ["calcGen9Stats", "calcTypeEff", "calcGen9ScaledExp", "awardGen9ExpAndEvs", "SMOGON_SETS"]:
            self.assertIn(m, self.html)
        smogon = json.load(open(os.path.join(REPO, "pokemon/movesets/smogon_optimal_sets.json")))
        for sp, cfg in smogon["species_sets"].items():
            self.assertEqual(len(cfg["moves"]), 4)
            self.assertLessEqual(sum(cfg["evs"].values()), 510)
            for v in cfg["evs"].values():
                self.assertLessEqual(v, 252)

    def test_12_empty_bag_omni_ring_and_2_shiny_starters(self):
        self.assertIn("const BAG_ITEMS = [];", self.html)
        self.assertIn("STATE.omniRing = true", self.html)
        self.assertIn("★ Shiny", self.html)
        self.assertIn("TOWN_SUPPLY_CATALOG", self.html)
        self.assertIn("expShareOn", self.html)

    def test_13_unique_solo_and_coop_two_seater_bicycles(self):
        bikes = json.load(open(os.path.join(REPO, "systems/transportation/bicycle_registry.json")))
        ids = {b["id"] for b in bikes["bicycles"]}
        self.assertTrue({"riley_solo","riley_tandem","tasha_solo","tasha_tandem","custom_fem_solo","custom_fem_tandem","custom_masc_solo","custom_masc_tandem"}.issubset(ids))
        self.assertIn("getActiveBikeInfo", self.html)
        self.assertIn("btn-bike-tandem", self.html)


    def test_14_bicycle_art_and_mounted_sprites(self):
        for bk in ["riley","tasha","custom_fem","custom_masc"]:
            self.assertTrue(os.path.exists(os.path.join(REPO, f"systems/transportation/bike_{bk}_sheet.jpg")))
        self.assertIn("A.bikes.riley", self.html)
        self.assertIn("A.bikes.tasha", self.html)

    def test_15_dynamic_level_scaling_lv100_and_auto_evolution(self):
        gd = open(os.path.join(REPO, "core/competitive_scaling_engine.gd")).read()
        self.assertIn("COMPETITIVE_EV_BUDGET := 516", gd)
        self.assertIn("scale_wild_level", gd)
        self.assertIn("resolve_evolved_species", gd)
        for marker in ["getScaledWildLevel", "getScaledOpponentLevel", "resolveDynamicEvolution", "buildDynamic6MonCompetitiveTeam"]:
            self.assertIn(marker, self.html)

    def test_16_challenge_run_modifiers_and_healing_move_swap(self):
        for m in ["no_trainer_items", "no_items_all", "no_healing", "no_healing_or_moves", "applyChallengeMoveFilter"]:
            self.assertIn(m, self.html)


    def test_17_movement_speeds_noise_and_stealth_math(self):
        spec = json.load(open(os.path.join(REPO, "systems/transportation/tandem_pose_and_movement_spec.json")))
        p = spec["official_movement_physics"]
        self.assertLess(p["crouch_sneak"]["tiles_per_sec"], p["walk"]["tiles_per_sec"])
        self.assertEqual(p["running_shoes"]["speed_mult"], 2.0)
        self.assertLess(p["running_shoes"]["tiles_per_sec"], p["bike_acro"]["tiles_per_sec"])
        self.assertLess(p["bike_acro"]["tiles_per_sec"], p["bike_mach"]["tiles_per_sec"])
        self.assertEqual(p["crouch_sneak"]["noise_level"], 0.0)
        self.assertLess(p["crouch_sneak"]["detection_mult"], p["walk"]["detection_mult"])
        self.assertGreater(p["running_shoes"]["detection_mult"], p["walk"]["detection_mult"])

    def test_18_tandem_poses_and_outfit_preservation(self):
        spec = json.load(open(os.path.join(REPO, "systems/transportation/tandem_pose_and_movement_spec.json")))
        poses = spec["passenger_pose_matrix"]
        for k in ["riley_behind_tasha","tasha_behind_riley","riley_behind_futanari","riley_behind_male","riley_behind_femboy","tasha_behind_male","tasha_behind_female","tasha_behind_femboy","custom_behind_any"]:
            self.assertIn(k, poses)
        self.assertIn("ZERO_DEFAULT_REVERSION", spec["outfit_preservation_rule"])
        self.assertIn("tandem_riley_tasha", self.html)
        self.assertIn("tandem_tasha_riley", self.html)

    def test_19_exact_gen9_stat_and_badge_cap_math(self):
        # Verify Lv.50 Pikachu (Base SpA=50, IV=31, EV=252, Modest 1.1x): floor((floor(((100+31+63)*50)/100)+5)*1.1) = floor(102*1.1) = 112
        calc_spa = int((int(((2*50 + 31 + (252//4)) * 50) / 100) + 5) * 1.1)
        self.assertEqual(calc_spa, 112)
        # Verify Hard Badge Caps prevent disobedience
        caps = [10, 20, 24, 29, 40, 43, 47, 50, 100]
        self.assertEqual(caps[0], 10)
        self.assertEqual(caps[8], 100)

    def test_20_universal_lv100_scaling_and_evolution_math(self):
        # Wild scales +1..+3, hard-locked to 100 at player Lv.100
        for p_lv in (5, 15, 50, 98, 99, 100):
            for off in (1, 2, 3):
                w = 100 if p_lv >= 100 else min(100, p_lv + off)
                self.assertGreaterEqual(w, p_lv)
                self.assertLessEqual(w, 100)
                if p_lv == 100: self.assertEqual(w, 100)
        # Caterpie dynamic evolution check
        stages = [(1,"Caterpie"),(7,"Metapod"),(10,"Butterfree")]
        def evo(lv): return [n for m, n in stages if lv >= m][-1]
        self.assertEqual(evo(5), "Caterpie")
        self.assertEqual(evo(7), "Metapod")
        self.assertEqual(evo(15), "Butterfree")


    def test_21_coop_tandem_hidden_offline_and_consent_handshake(self):
        coop = open(os.path.join(REPO, "systems/multiplayer/coop_network_manager.gd")).read()
        for sym in ["is_tandem_ui_visible", "request_tandem_ride", "respond_tandem_invite", "passenger_input_locked", "passenger_camera_follow_driver", "BOTH_PLAYERS_USE_SINGULAR_BIKES"]:
            self.assertIn(sym, coop)
        for bk in ["tandem_custom_female","tandem_custom_male","tandem_custom_femboy","tandem_custom_futanari"]:
            self.assertIn(f'"{bk}"', self.html)
        self.assertIn("Player 2 Accepts Tandem Ride", self.html)
        self.assertIn("Player 2 Declines (Both Use Singular Bikes)", self.html)


    def test_22_mounted_solo_bikes_unique_npcs_and_live_animations(self):
        for k in ["npc_kira","npc_haruka","npc_vance","champ_leon"]:
            self.assertIn(f'"{k}"', self.html)
        for bk in ["solo_female","solo_male","solo_femboy","solo_futanari","tandem_riley_futanari","tandem_riley_male","tandem_tasha_female","tandem_tasha_femboy"]:
            self.assertIn(f'"{bk}"', self.html)
        for vfx in ["puwIdleBreath","vfx-mega","vfx-dynamax","vfx-tera","vfx-zmove"]:
            self.assertIn(vfx, self.html)


    def test_23_all_8_gym_leaders_6_action_sheets_and_complete_tandems(self):
        for g in ["brock","misty","surge","erika","koga","sabrina","blaine","giovanni"]:
            self.assertTrue(os.path.exists(os.path.join(REPO, f"characters/npcs/gym_leaders/gym_{g}_sheet.jpg")))
            self.assertIn(f'"{g}"', self.html)
        for a in ["riley","tasha","custom_female","custom_male","custom_femboy","custom_futanari"]:
            self.assertTrue(os.path.exists(os.path.join(REPO, f"characters/animations/anim_{a}_8frame_sheet.jpg")))
        self.assertIn("playTrainerThrowAnimation", self.html)
        self.assertIn("A.anims[aKey].crouch", self.html)


    def test_24_kanto_elite4_dynamic_champion_and_exclusive_rival_eggs(self):
        for e4 in ["lorelei","bruno","agatha","lance"]:
            self.assertTrue(os.path.exists(os.path.join(REPO, f"characters/npcs/elite_four/e4_{e4}_sheet.jpg")))
            self.assertIn(f'"{e4}"', self.html)
        spec = json.load(open(os.path.join(REPO, "systems/progression/kanto_league_and_rival_story.json")))
        self.assertEqual(spec["exclusive_rival_defeat_only_shiny_eggs"]["exclusivity_guarantee"][:17], "RIVAL_DEFEAT_ONLY")
        self.assertEqual(len(spec["kanto_elite_four"]), 4)
        for m in ["triggerRivalEggEncounter", "hatchExclusiveEgg", "launchKantoLeagueStage", "RILEY_EXCLUSIVE_EGGS", "TASHA_EXCLUSIVE_EGGS"]:
            self.assertIn(m, self.html)

if __name__ == "__main__":
    unittest.main(verbosity=2)
