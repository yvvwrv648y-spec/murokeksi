# animation_qa_report.md -- PUW cast animation QA

Bossy, 2026-11-22. Numbers measured from the sliced frames produced by `tools/slice_cast_frames.py` (data: frame_data.json + the slicer QA dump). Godot verification: tests/cast_animation_tests.gd -- SUMMARY: 115 passed, 0 failed (Godot 4.7.2 headless).

## Method

- Foot-anchor drift: max absolute residual anchor offset (px) across the cycle AFTER alignment. The slicer places every frame's measured foot anchor (bottom-centre of content bbox) at the same canvas pixel (canvas_w/2, canvas_h-1), so drift is 0 by construction wherever the content fits the canvas; the real number is reported per cycle below.
- Frame-edge contact flags are carried from the pixel analysis: frames whose content touched a cell border or the sheet edge in the SOURCE art (clipping risk that alignment cannot repair).
- Bbox variance: content width/height min-max (and population stdev) within the cycle, from sheet_grids.json measurements. Large variance is expected for the action sequence (crouch and throw poses differ from standing) and for swim (poses differ).

## Per cast member

### riley

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 152-300 (44.6) | 270-371 (35.1) | none |
| swim (small poses) | 0,1,3,4 | 0 | 181-198 (8.3) | 342-348 (2.8) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

### tasha

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 161-309 (43.3) | 278-365 (28.8) | none |
| swim (small poses) | 0,1,3,4 | 0 | 143-170 (13.3) | 336-344 (3.8) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

### custom_female

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 178-257 (25.7) | 274-362 (31.4) | none |
| swim (small poses) | 0,1,3,4 | 0 | 165-199 (16.8) | 343-350 (2.7) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

### custom_male

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 134-316 (47.5) | 259-336 (29.5) | none |
| swim (small poses) | 0,1,3,4 | 0 | 158-188 (13.2) | 314-325 (5.5) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

### custom_femboy

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 144-286 (44.0) | 256-364 (35.8) | none |
| swim (small poses) | 0,1,3,4 | 0 | 153-181 (12.8) | 337-338 (0.4) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

### custom_futanari

| Cycle | Frames | Anchor drift (max px) | Content width min-max (stdev) | Content height min-max (stdev) | Edge-contact flags |
|---|---|---|---|---|---|
| walk/run sequence (anim sheet) | 0,1,2,3,4,5,6,7 | 0 | 182-303 (34.2) | 297-376 (26.3) | f06: touches_cell_edge,touches_sheet_edge; f07: touches_cell_edge,touches_sheet_edge |
| swim (small poses) | 0,1,3,4 | 0 | 150-180 (14.3) | 344-348 (2.0) | none |

Idle: single neutral standing frame f06 of the anim sheet (drift n/a). Battle: single *_battle.png pose (drift n/a).

## Verdicts -- what cannot yield a clean cycle, and why

- ALL SIX anim sheets: they are trainer ACTION sequences (stance, ball throw, crouch/capture-react, neutral stand, victory), NOT locomotion cycles, and contain no directional sets. Walk/run are wired to the full sequence per the build brief because it is the only multi-frame sequence in the art, but it will read as an action loop, not as walking. A true walk cycle does not exist in the Neon cast art and was NOT faked: no frame was frozen into a fake cycle and no frames were invented.
- anim_custom_futanari_8frame_sheet.jpg: frames f06 and f07 reach y=768, the sheet's bottom edge -- feet may be clipped in the source art itself. Alignment keeps their anchors exact (drift 0), but missing foot pixels cannot be restored.
- Swim cycles: built from the swim sheets' 4 small poses only. The 5th frame of each swim sheet is a large hero pose at a different scale and is excluded; including it would pop scale mid-cycle. Swim canvas is sized by the hero pose (uniform-canvas contract), so swim frames sit on a large canvas with the anchor aligned -- consistent, but wasteful of texture space.
- Pose sheets (master/casual/bikini, NPC, gym, elite-four): 4 small poses + 1 hero, or irregular per-component layouts (15 low-confidence sheets). Sliced as individual anchored poses; they are not cycles and are not wired as ones.
- Chroma cleanup: magenta-ish visible pixels in riley f00 dropped from 1,376 (first pass) to 116 after the wide key ramp + 1px erosion + boundary despill; the remaining 116 are interior pink/red clothing pixels (e.g. the shirt heart), not fringe.

## What alignment fixed

- Every sliced frame of every character sheet (295 frames, 75 sheets) has residual anchor offset [0,0]: foot anchors are pixel-identical across every cycle after alignment (before alignment, anchor_norm varied within the anim sheets by up to 0.121 of a cell width (custom_female) and 0.068 of a cell height (custom_female, riley)).
