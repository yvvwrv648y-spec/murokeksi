# SHEET_GRID_SPEC.md -- PUW cast sheet grids

Bossy-derived 2026-11-22 -- Neon defined no spec. Every grid below was derived from the pixels of the real Neon sheets (segmentation against the near-solid magenta chroma key, corner medians approx RGB 252,5,250; connected components; alpha channel for the single-sprite PNGs) in `art_analysis/sheet_grids.json` / `analysis_summary.md`, then used by `tools/slice_cast_frames.py` to slice `art/frames/**`.

## Slicing contract

- Frame PNGs: `art_frames/<sheet path relative to art_src, minus extension>/f<NN>.png` in the project, mirrored to the pack at `art/frames/<same relative path>`.
- Each JPG frame: magenta chroma-keyed by colour distance (ramp 20-120, 1px alpha erosion, boundary despill of the JPEG magenta ring), cropped to the measured content bbox, placed on a uniform canvas per sheet (canvas = max content width/height across that sheet's frames).
- Foot anchor = bottom-centre of the content bbox (`anchor_px` in the grids). Canvas anchor target = (canvas_w/2, canvas_h-1). Residual per-frame anchor offset after alignment is recorded in `frame_data.json` (0 px for every frame of every sheet in this build).
- The 30 single-sprite PNGs (ow_00..03, battle) are already transparent and are copied through as f00; all 30 are tightly cropped to their canvas edges in the source.
- Frame labels in the source analysis are HEURISTIC (filename + reading order only; facings were never verified from pixels).

## Frame-to-state mapping (decided by visual inspection of the sliced frames, 2026-11-22)

All six `anim_*_8frame_sheet.jpg` sheets share one template. Reading the frames in order: f00 ready stance, f01 reach for a Poke Ball, f02 ball raised, f03 throw (the thrown ball is a separate component merged into this frame in anim_riley and anim_custom_male), f04-f05 crouch / capture-react, f06 neutral standing, f07 victory pose.

HONEST READ: this is a trainer ACTION sequence, not a locomotion cycle, and it contains NO directional (up/down/left/right) frame sets. No true walk cycle exists anywhere in the cast art. Mapping used by PUWCastRigLoader (in `frame_data.json`):

| State | Frames | FPS | Loop | Basis |
|---|---|---|---|---|
| idle | f06 only (the neutral standing frame in every sheet) | 4.0 | yes | CLIP_FPS IDLE |
| walk | f00-f07, the full 8-frame sequence | 7.5 | yes | CLIP_FPS WALK; only multi-frame sequence that exists -- flagged, not a true walk cycle |
| run | f00-f07, same sequence | 11.0 | yes | CLIP_FPS RUN; the art has no separate run cycle |
| swim | swim sheet frames 0,1,3,4 (small poses; frame 2 is the large hero pose, excluded) | 7.5 | yes | CLIP_FPS defines no SWIM rate, so the walk rate is used |
| battle | the single *_battle.png pose (f00) | 1.0 (static) | no | battle is a static pose state |
| bike_solo, tandem_driver, tandem_passenger | not resolved in this build | - | - | systems/transportation sheets are owned by the bikes build |

Swim sheets used: riley = characters/protagonists/riley/riley_swim_exclusive_sheet.jpg (the registry points riley swim at the anim sheet, but this real swim sheet exists and is used), tasha = characters/protagonists/tasha/tasha_swim_exclusive_sheet.jpg, customs = characters/protagonists/custom/custom_<variant>_swim_sheet.jpg.
Battle overrides: the registry points riley/tasha battle at the anim sheet; the real battle pose PNGs characters/protagonists/riley/riley_v2_battle.png and characters/protagonists/riley/tasha_v2_battle.png exist on disk and are used. Customs use their registry battle PNGs directly.

## Known defects per sheet (from the pixel analysis)

- anim_custom_futanari_8frame_sheet.jpg: bottom-row frames f06 and f07 have content reaching y=768, the sheet bottom edge -- feet may be clipped in the SOURCE art itself. The sliced frames keep the anchor at the sheet edge; this cannot be fixed by alignment.
- All 30 single-sprite PNGs touch all four canvas edges (tight crops in the source).
- Irregular (low-confidence) sheets among characters/: all 8 gym-leader sheets, all 4 elite-four sheets, npc_haruka, riley_6ball_meowth_master_sheet, tasha_6ball_klefki_master_sheet -- no uniform grid fits; frames were measured per-component and their grids are equal-division approximations. They slice as individual poses, not cycles.
- champ_leon frame 2 and several pose-sheet hero frames touch/cross cell edges (hero poses occupy the merged right-half cell); custom_futanari master/swim hero frames likewise.
- Pose sheets (5 frames) are 4 small poses + 1 hero pose, not animation cycles.

## Every characters/ sheet: derived grid

| Sheet | Size | Method | Confidence | Grid | Cell | Frames | Sliced canvas | Anchor target |
|---|---|---|---|---|---|---|---|---|
| characters/animations/anim_custom_female_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 257x362 | (128,361) |
| characters/animations/anim_custom_femboy_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 286x364 | (143,363) |
| characters/animations/anim_custom_futanari_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 303x376 | (151,375) |
| characters/animations/anim_custom_male_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 316x336 | (158,335) |
| characters/animations/anim_riley_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 300x371 | (150,370) |
| characters/animations/anim_tasha_8frame_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 8 | 309x365 | (154,364) |
| characters/npcs/champ_leon_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 671x756 | (335,755) |
| characters/npcs/elite_four/e4_agatha_sheet.jpg | 1376x768 | segmented | low | 5x2 | 275.2x384.0 | 7 | 400x332 | (200,331) |
| characters/npcs/elite_four/e4_bruno_sheet.jpg | 1376x768 | segmented | low | 5x2 | 275.2x384.0 | 7 | 297x385 | (148,384) |
| characters/npcs/elite_four/e4_lance_sheet.jpg | 1376x768 | segmented | low | 4x2 | 344.0x384.0 | 6 | 352x502 | (176,501) |
| characters/npcs/elite_four/e4_lorelei_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 282x474 | (141,473) |
| characters/npcs/gym_leaders/gym_blaine_sheet.jpg | 1376x768 | segmented | low | 4x2 | 344.0x384.0 | 7 | 387x431 | (193,430) |
| characters/npcs/gym_leaders/gym_brock_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 236x350 | (118,349) |
| characters/npcs/gym_leaders/gym_erika_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 242x365 | (121,364) |
| characters/npcs/gym_leaders/gym_giovanni_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 224x359 | (112,358) |
| characters/npcs/gym_leaders/gym_koga_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 325x346 | (162,345) |
| characters/npcs/gym_leaders/gym_misty_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 331x359 | (165,358) |
| characters/npcs/gym_leaders/gym_sabrina_sheet.jpg | 1376x768 | segmented | low | 5x3 | 275.2x256.0 | 7 | 292x338 | (146,337) |
| characters/npcs/gym_leaders/gym_surge_sheet.jpg | 1376x768 | segmented | low | 4x3 | 344.0x256.0 | 6 | 373x650 | (186,649) |
| characters/npcs/npc_haruka_sheet.jpg | 1376x768 | segmented | low | 5x1 | 275.2x768.0 | 5 | 296x727 | (148,726) |
| characters/npcs/npc_kira_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 303x731 | (151,730) |
| characters/npcs/npc_vance_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 312x752 | (156,751) |
| characters/npcs/vexa_welcome_sim_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 465x739 | (232,738) |
| characters/protagonists/custom/custom_female_battle.png | 132x240 | alpha | high | 1x1 | 132x240 | 1 | 132x240 | (66,239) |
| characters/protagonists/custom/custom_female_bikini_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 414x745 | (207,744) |
| characters/protagonists/custom/custom_female_casual_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 414x744 | (207,743) |
| characters/protagonists/custom/custom_female_master_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 401x726 | (200,725) |
| characters/protagonists/custom/custom_female_ow_00.png | 48x104 | alpha | high | 1x1 | 48x104 | 1 | 48x104 | (24,103) |
| characters/protagonists/custom/custom_female_ow_01.png | 49x104 | alpha | high | 1x1 | 49x104 | 1 | 49x104 | (24,103) |
| characters/protagonists/custom/custom_female_ow_02.png | 58x104 | alpha | high | 1x1 | 58x104 | 1 | 58x104 | (29,103) |
| characters/protagonists/custom/custom_female_ow_03.png | 58x104 | alpha | high | 1x1 | 58x104 | 1 | 58x104 | (29,103) |
| characters/protagonists/custom/custom_female_swim_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 402x725 | (201,724) |
| characters/protagonists/custom/custom_femboy_battle.png | 105x240 | alpha | high | 1x1 | 105x240 | 1 | 105x240 | (52,239) |
| characters/protagonists/custom/custom_femboy_bikini_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 467x744 | (233,743) |
| characters/protagonists/custom/custom_femboy_casual_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 467x743 | (233,742) |
| characters/protagonists/custom/custom_femboy_master_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 331x748 | (165,747) |
| characters/protagonists/custom/custom_femboy_ow_00.png | 57x104 | alpha | high | 1x1 | 57x104 | 1 | 57x104 | (28,103) |
| characters/protagonists/custom/custom_femboy_ow_01.png | 59x104 | alpha | high | 1x1 | 59x104 | 1 | 59x104 | (29,103) |
| characters/protagonists/custom/custom_femboy_ow_02.png | 47x104 | alpha | high | 1x1 | 47x104 | 1 | 47x104 | (23,103) |
| characters/protagonists/custom/custom_femboy_ow_03.png | 47x104 | alpha | high | 1x1 | 47x104 | 1 | 47x104 | (23,103) |
| characters/protagonists/custom/custom_femboy_swim_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 320x751 | (160,750) |
| characters/protagonists/custom/custom_futanari_battle.png | 184x240 | alpha | high | 1x1 | 184x240 | 1 | 184x240 | (92,239) |
| characters/protagonists/custom/custom_futanari_bikini_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 406x713 | (203,712) |
| characters/protagonists/custom/custom_futanari_casual_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 406x712 | (203,711) |
| characters/protagonists/custom/custom_futanari_master_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 581x755 | (290,754) |
| characters/protagonists/custom/custom_futanari_ow_00.png | 54x104 | alpha | high | 1x1 | 54x104 | 1 | 54x104 | (27,103) |
| characters/protagonists/custom/custom_futanari_ow_01.png | 54x104 | alpha | high | 1x1 | 54x104 | 1 | 54x104 | (27,103) |
| characters/protagonists/custom/custom_futanari_ow_02.png | 45x104 | alpha | high | 1x1 | 45x104 | 1 | 45x104 | (22,103) |
| characters/protagonists/custom/custom_futanari_ow_03.png | 44x104 | alpha | high | 1x1 | 44x104 | 1 | 44x104 | (22,103) |
| characters/protagonists/custom/custom_futanari_swim_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 582x756 | (291,755) |
| characters/protagonists/custom/custom_male_battle.png | 155x240 | alpha | high | 1x1 | 155x240 | 1 | 155x240 | (77,239) |
| characters/protagonists/custom/custom_male_bikini_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 489x752 | (244,751) |
| characters/protagonists/custom/custom_male_casual_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 488x751 | (244,750) |
| characters/protagonists/custom/custom_male_master_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 462x715 | (231,714) |
| characters/protagonists/custom/custom_male_ow_00.png | 62x104 | alpha | high | 1x1 | 62x104 | 1 | 62x104 | (31,103) |
| characters/protagonists/custom/custom_male_ow_01.png | 64x104 | alpha | high | 1x1 | 64x104 | 1 | 64x104 | (32,103) |
| characters/protagonists/custom/custom_male_ow_02.png | 50x104 | alpha | high | 1x1 | 50x104 | 1 | 50x104 | (25,103) |
| characters/protagonists/custom/custom_male_ow_03.png | 50x104 | alpha | high | 1x1 | 50x104 | 1 | 50x104 | (25,103) |
| characters/protagonists/custom/custom_male_swim_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 463x717 | (231,716) |
| characters/protagonists/riley/riley_6ball_meowth_master_sheet.jpg | 1376x768 | segmented | low | 3x3 | 458.7x256.0 | 5 | 364x726 | (182,725) |
| characters/protagonists/riley/riley_casual_exclusive_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 435x739 | (217,738) |
| characters/protagonists/riley/riley_swim_exclusive_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 582x756 | (291,755) |
| characters/protagonists/riley/riley_v2_battle.png | 120x240 | alpha | high | 1x1 | 120x240 | 1 | 120x240 | (60,239) |
| characters/protagonists/riley/riley_v2_ow_00.png | 53x104 | alpha | high | 1x1 | 53x104 | 1 | 53x104 | (26,103) |
| characters/protagonists/riley/riley_v2_ow_01.png | 53x104 | alpha | high | 1x1 | 53x104 | 1 | 53x104 | (26,103) |
| characters/protagonists/riley/riley_v2_ow_02.png | 43x104 | alpha | high | 1x1 | 43x104 | 1 | 43x104 | (21,103) |
| characters/protagonists/riley/riley_v2_ow_03.png | 43x104 | alpha | high | 1x1 | 43x104 | 1 | 43x104 | (21,103) |
| characters/protagonists/riley/tasha_6ball_klefki_master_sheet.jpg | 1376x768 | segmented | low | 5x1 | 275.2x768.0 | 5 | 364x742 | (182,741) |
| characters/protagonists/riley/tasha_v2_battle.png | 117x240 | alpha | high | 1x1 | 117x240 | 1 | 117x240 | (58,239) |
| characters/protagonists/riley/tasha_v2_ow_00.png | 34x104 | alpha | high | 1x1 | 34x104 | 1 | 34x104 | (17,103) |
| characters/protagonists/riley/tasha_v2_ow_01.png | 31x104 | alpha | high | 1x1 | 31x104 | 1 | 31x104 | (15,103) |
| characters/protagonists/riley/tasha_v2_ow_02.png | 32x104 | alpha | high | 1x1 | 32x104 | 1 | 32x104 | (16,103) |
| characters/protagonists/riley/tasha_v2_ow_03.png | 27x104 | alpha | high | 1x1 | 27x104 | 1 | 27x104 | (13,103) |
| characters/protagonists/tasha/tasha_casual_exclusive_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 336x743 | (168,742) |
| characters/protagonists/tasha/tasha_swim_exclusive_sheet.jpg | 1376x768 | segmented | high | 4x2 | 344x384 | 5 | 428x726 | (214,725) |

Total: 75 character sheets, 295 frames sliced.

## Layered walk pilot + ride poses (QA integration, 2026-11-22)

The layered walk pilot sheets are true grids: 1376x768, 4 rows x 8 cols,
cells 172x192 (row 1 down, row 2 up, row 3 left, row 4 right), per
`layered_walk_pilot_spec.json`. Composited (outfit over body, magenta
keyed with despill) frames live under
`art/frames/characters/layered/walk/<char>_walk_composite/f<row><col>.png`
and are registered in `frame_data.json` as `walk_down/walk_up/walk_left/
walk_right` cast states at 7.5 fps. Riley: all 4 rows. Tasha: rows 1/2/4
only — row 3 (left) was REJECTED in grading (C3/C4/C6/C7/C8 face right in
both sheets); it was not sliced or mirrored, and `tasha walk_left` stays
unbound/pending Neon's redo of the left row.

Ride pose sheets are FREE LAYOUT (no grid): sliced by magenta-key
connected components ordered row-major, registered in
`systems/cast/rider_frame_data.json`. Only the verdict files' accepted
primary figures were sliced (92 frames); rejected figures and accepted
backups were not.
