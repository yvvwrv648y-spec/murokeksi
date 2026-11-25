# PUW_CHANGELOG.md
## v0.4.0-m0 (2026-11-21) — Master Studio Production Directive M0 Baseline
- Preserved all 180 files from `godot_v0_3_1` non-destructively.
- Established authoritative 19-subsystem modular architecture (`core/`, `world/`, `maps/`, `characters/`, `pokemon/`, `npcs/`, `animation/`, `battle/`, `inventory/`, `items/`, `ui/`, `audio/`, `story/`, `quests/`, `save/`, `assets/`, `tools/`, `tests/`, `qa/`, `docs/`).
- Authored typed GDScript modules: `core/game_state.gd`, `characters/protagonist_canon.gd`, `story/pallet_home_clues.gd`, `world/camera_qa_harness.gd`, `world/kanto_world_graph.gd`, `battle/battle_engine.gd`, `save/save_manager.gd`.
- Resolved v0.3.1 canon conflicts: updated Tasha's collar charm to custom Klefki-inspired keyring Pokémon charm, locked 6 individual custom Poké Ball hip anchors (3 left, 3 right, 1 signature) for both Riley and Tasha, and separated Riley/Tasha/Custom Pallet homes.
- Authored all 16 required living studio documents (`docs/PUW_*.md` & `.json`) and automated audit script (`tests/run_m0_studio_audit.py`).

## v0.5.0-m1-m2 (2026-11-21) — M1/M2 Vertical Showcase Systems & Connected Kanto Slice
- Added `animation/actor_state_machine.gd`, `npcs/npc_simulation_manager.gd`, `pokemon/overworld_ecology_manager.gd`, `pokemon/follower_controller.gd`, `inventory/inventory_manager.gd`, `audio/audio_director.gd`.
- Authored 7 connected Kanto vertical-slice maps (`Pallet Town`, 4 unique interiors, `Route 1`, `Viridian Forest`) with bidirectional connection validation.

## v0.6.0-m3-m4 (2026-11-21) — Complete Connected Kanto World Graph (72 Maps) & M4 Gameplay Systems
- Authored 72 bidirectionally connected Kanto & Sevii JSON map definitions (100% BFS reachable from Pallet Town).
- Added `battle/gym_and_trainer_manager.gd` (all 8 Kanto Gyms), `quests/quest_manager.gd`, `story/dialogue_database.json`, `story/dialogue_manager.gd`, `world/chunk_streamer.gd`, and `tests/run_m3_m4_kanto_audit.py`.

## v0.7.0-m5-m6 (2026-11-21) — M5 Living World Simulation & M6 Original Audio/Voice Architecture
- Added `world/world_clock_and_weather.gd`, `npcs/kanto_npc_schedules.json`, `pokemon/kanto_ecology_spawns.json`.
- Added 30-track `audio/original_soundtrack_manifest.json`, `audio/species_cries_and_moemon_voices.json`, and `tests/run_m5_m6_living_world_audio_audit.py`.

## v1.0.0-rc1 (2026-11-21) — Canonical POKEMON_ULTIMATE_WORLD/ Studio Release Candidate
- Reorganized into canonical `POKEMON_ULTIMATE_WORLD/` directory tree (`core/`, `world/regions/kanto/`, `characters/protagonists/`, `pokemon/`, `battle/`, `systems/`, `interface/`, `audio/`, `tools/`, `tests/`).
- Fixed 4 production bugs in `FollowerController` (XZ ground lock, NavigationAgent3D support, low-FPS overshoot clamp, map-change snap).
- Adopted & enhanced `pallet_fisher_001.json` schedule and fixed `0025_pikachu.json` Thunder Stone evolution rules + PKDX/MDX linkage.
