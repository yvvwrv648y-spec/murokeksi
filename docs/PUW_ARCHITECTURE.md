# PUW_ARCHITECTURE.md
- **Status:** `IMPLEMENTED` (M0 Modular Scaffold) / `BLOCKED` (Godot headless/Web binary absent in sandbox VM)

## M0 Source-Preservation & Component Decisions
| Component | Source / Provenance | Decision | Rationale |
|---|---|---|---|
| `PUW_BW2_HYBRID_ENGINE_FOUNDATION_v0_1_0.zip` | Verified SHA `473b0ad9...` | **RETAIN** | Genuine Godot 4.7 hybrid seed |
| `PUW_NEON_RECOVERY_BRANCH_v0_3_1_BW2_3D` | Additive branch from v0.1.0 | **RETAIN & IMPROVE** | Preserved intact; split monolith into 19 subsystems in `v0.4.0-m0` |
| `scripts/main.gd` (633 lines) | v0.3.1 monolith | **REPLACE GRADUALLY** | Preserved for compatibility; modular replacements added in `core/`, `characters/`, `world/`, `battle/`, `save/`, `story/` |
| `pokemon_world_bw2_3d.html` (1.67 MB) | Archived Three.js BW2 build | **RETAIN (REFERENCE)** | Valuable playable visual/intro reference; not production engine authority |
| `PUW_NEON_GEN5_BW2_AUTHENTIC_ENV_ASSETS` (13,111 assets) | Owner Black 2 / White 2 ROMs | **QUARANTINE (CANDIDATE)** | Private source reference; `approved_for_live_swap = false`; never redistribute raw ROMs |
| `PUW_NEON_MOEMON_COMPLETE_ALL_ASSETS` (11,060 PNGs) | Owner Quetzal 8v4 ROM | **QUARANTINE (CANDIDATE)** | Separate MDX family; pending visual & voice QA |
| `PUW_NEON_GEN6_9_GODOT_HYBRID_CANDIDATE` | Checkpoint 4 Serebii/Bulbapedia | **RETAIN (CANDIDATE)** | 376 species stats + Kalos/Alola spatial nodes ready for post-Kanto expansion |
| Codex `v0.8.0` source / Web export | Absent from handoff & sandbox | **BLOCK (MISSING)** | Never presumed recovered; recorded honestly in `SOURCE_RECOVERY_REPORT.md` |
| `kanto_pallet_riley_house_1f.json` title conflict | v0.3.1 merged Riley & Tasha home | **REPLACE** | Split into distinct Top-Left (Riley), Top-Right (Tasha), Bottom-Right (Custom) homes per Section 8.1 |
| `protagonist_registry.gd` Tasha charm & belt | v0.3.1 lacked Klefki charm & 6-ball rig | **IMPROVE** | Updated in `characters/protagonist_canon.gd` per Section 6.2 & 6.3 |

## Authoritative Subsystem Tree (Section 19)
`core/ world/ maps/ characters/ pokemon/ npcs/ animation/ battle/ inventory/ items/ ui/ audio/ story/ quests/ save/ assets/ tools/ tests/ qa/ docs/`
