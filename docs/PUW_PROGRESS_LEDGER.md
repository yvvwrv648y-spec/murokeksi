# PUW_PROGRESS_LEDGER.md
| Milestone | Scope | Status | Evidence |
|---|---|---|---|
| **M0** | Source & architecture audit, modular 19-subsystem scaffold, 16 studio docs, automated M0 audit | `TEST_PASSED` (Static) | `tests/run_m0_studio_audit.py` PASS; `PUW_KANTO_STUDIO_v0_4_0_M0_20261121.zip` |
| **M1** | Visual & animation foundation, Camera QA scene, Riley/Tasha 6-ball rigs, Visual Acceptance Gate | `IMPLEMENTED` (Harness) / `BLOCKED` (Godot render) | `world/camera_qa_harness.gd`, `characters/protagonist_canon.gd`; requires Godot 4.7.2 host for frame captures |
| **M2** | Pallet Town full production (3 distinct homes, Oak's Lab, 2-min intro, NPC/Pokémon ecology) | `SPECIFIED` | Pallet home clues (`story/pallet_home_clues.gd`) implemented; 3D browser prototype archived as reference |
| **M3** | Kanto world foundation (11 cities, Routes 1–25, dungeons, Sevii Islands) | `SPECIFIED` | Complete continuity-tagged register in `docs/PUW_KANTO_LOCATION_REGISTER.json` |
| **M4** | Gameplay systems (typed Battle Engine, Save v2 atomic migration, PKDX/MDX uniqueness) | `IMPLEMENTED` (Core) | `battle/battle_engine.gd`, `save/save_manager.gd`, `core/game_state.gd` |
| **M5** | Living world (NPC schedules, Pokémon ecology, weather/time) | `SPECIFIED` | Registers seeded in `docs/PUW_NPC_POPULATION_REGISTER.json` & `PUW_POKEMON_OVERWORLD_REGISTER.json` |
| **M6** | Original music, species cries, Moemon voices | `SPECIFIED` | `docs/PUW_AUDIO_ASSET_REGISTER.json` |
| **M7** | Complete Kanto & Sevii content | `SPECIFIED` | Pending M1 Visual Acceptance Gate |
| **M8** | Final QA, physical iPhone 17 Pro Max profiling, release candidate | `BLOCKED` | Requires Godot 4.7.2 export + real iPhone device |
