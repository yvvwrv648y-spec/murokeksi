# bike_qa_report.md -- PUW solo / tandem bike rig QA

Bossy, 2026-11-22. Numbers measured from the sliced frames produced by `tools/slice_bike_frames.py` (data: `systems/transportation/bike_slicer_stats.json` + `systems/transportation/bike_frame_data.json`, grids derived in `art_analysis/analysis_summary.md` -- Neon defined no sheet layout spec). Godot verification: `tests/bike_rig_tests.gd` -- SUMMARY: 30 passed, 0 failed (Godot 4.7.2 headless, log `pk_logs/followup_bike_rigs.log`).

## Totals and method

- 32 transportation sheets sliced, 159 frame PNGs total (5 per sheet, except `tandem_female_tasha_sheet.jpg` with 4 -- see defects below). Frames live in the project under `art_frames/systems/transportation/<sheet>/fNN.png` and in this pack under `art/frames/systems/transportation/<sheet>/fNN.png`.
- Every frame is chroma-keyed, bbox-cropped, and foot-anchor aligned on a uniform per-sheet canvas: the slicer places every frame's measured foot anchor (bottom-centre of the content bbox) at the same canvas pixel, so anchor drift is 0 px on every sheet, by construction, wherever the content fits the canvas. Per-sheet canvas sizes and drift are in the table below.
- Ride playback rate is 11.0 FPS (the RUN rate from `actor_state_machine.gd` CLIP_FPS; that file defines no RIDE rate, and a pedalling cycle at the 7.5 walk rate looks slow against mach/acro speeds). Verified by the `ride_fps_is_run_rate_11` check.
- Solo resolution: 6 cast members (riley, tasha, custom_female, custom_male, custom_femboy, custom_futanari), each riding frames [0, 1, 3, 4] of its solo sheet. Tandem resolution: 18 named driver>passenger pairings, each riding frames [0, 1, 3, 4] of its tandem sheet, except the one partial pairing noted below. The 4 single-token `tandem_custom_*` sheets are sliced but have no named pairing in `cast_sheets.json` (Custom x Custom has no named sheet), so no tandem resolution entry uses them and the loader refuses unnamed custom pairings (tested).

## Excluded panels (32, one per sheet)

Every sheet's frame 2 is its large right-hand hero panel, and frame 2 is excluded from every ride cycle (32 excluded panels listed in `bike_frame_data.json`; the `unoccupied_hero_excluded_from_solo_cycles` and `excluded_panels_listed` checks verify this):

- 4 sheets (`bike_riley_sheet.jpg`, `bike_tasha_sheet.jpg`, `bike_custom_fem_sheet.jpg`, `bike_custom_masc_sheet.jpg`): the hero panel shows an UNOCCUPIED tandem bicycle, not a rider on a solo bike (visual spot-check, `analysis_summary.md`). It must never be used as a solo-riding frame.
- The other 28 sheets: the hero panel is drawn at roughly double the small-pose scale; it is excluded from ride cycles so the cycle does not jump size. It is sliced and kept as a still.

## Named source defects (honest, not repaired by slicing)

- `tandem_female_tasha_sheet.jpg` -- MISSING SECOND SIDE VIEW: only 4 figure components exist (front, back, one side view, hero). The oversized hero starts at x=567 and takes the space where the second side view sits in the other tandem sheets; that pose is missing from the source art, not merged. Consequence: the `custom_female>tasha` tandem pairing resolves to only 3 ride frames [0, 1, 3] (the `tandem_frames_female_driver_tasha_passenger_partial` check) instead of 4. No frame was invented to fill the gap.
- `tandem_custom_femboy_sheet.jpg` -- TWO-TONE BACKGROUND SEAM: the right half is a visibly different magenta (corner medians (255,55,250)/(253,57,252) on the right vs (250,5,247)/(248,12,246) on the left), with a vertical seam at x=688. It was segmented/keyed against the nearest corner colour and sliced cleanly, but the seam should be removed from the source art before any future re-extraction.
- Futanari feet at the sheet edge (cast anim sheets, carried here because the same warning applies to the futanari bike sheets' source family): in `anim_custom_futanari_8frame_sheet.jpg`, bottom-row frames 6 and 7 have content reaching y=768, the sheet's bottom edge -- feet may be clipped in the source art itself. Within the transportation set itself, `solo_futanari_sheet.jpg` frame 3 and the futanari tandem sheets (below) carry cell-edge-crossing flags; slicing used the content bbox, not the cell, so no additional clipping was introduced, but source-edge content cannot be un-clipped.
- Clipped in source (content touches the sheet edge itself): `bike_custom_masc_sheet.jpg` frame 4 (bbox [292,0,263,768]) and `tandem_male_tasha_sheet.jpg` frame 4 (bbox [356,0,337,768]). Both frames are sliced as-is; the missing pixels do not exist in the source.
- Irregular layouts (low-confidence derived grids; components measured individually): `bike_custom_fem_sheet.jpg`, `bike_custom_masc_sheet.jpg`, `custom_fem_solo_sheet.jpg`, `tandem_female_tasha_sheet.jpg`, `tandem_femboy_riley_sheet.jpg`, `tandem_male_tasha_sheet.jpg`, `tandem_riley_femboy_sheet.jpg`, `tandem_tasha_futanari_sheet.jpg`. Two sheets also had 1 small accessory component merged into the nearest figure frame: `bike_custom_masc_sheet.jpg` and `tandem_male_tasha_sheet.jpg`.

## Per-sheet table

Frames sliced / canvas (the uniform per-sheet canvas every frame of that sheet was anchor-aligned onto) / anchor drift / edge-contact flags from `bike_slicer_stats.json`. "Crosses cell edge" means the content spilled past its derived grid cell in the source; those frames were sliced by content bbox, not by cell, so the full figure is kept.

| Sheet | Frames | Canvas | Anchor drift (px) | Edge-contact flags |
|---|---|---|---|---|
| `systems/transportation/bike_custom_fem_sheet.jpg` | 5 | 704x454 | 0 | irregular layout, low confidence grid |
| `systems/transportation/bike_custom_masc_sheet.jpg` | 5 | 786x768 | 0 | frame 2 hero-size component starts at x=569 (intrudes into pose region); frame 4 content touches sheet edge: bbox [292,0,263,768] - clipped in source; 1 small accessory component merged into nearest figure frame; irregular layout, low confidence grid |
| `systems/transportation/bike_riley_sheet.jpg` | 5 | 629x491 | 0 | none |
| `systems/transportation/bike_tasha_sheet.jpg` | 5 | 629x480 | 0 | none |
| `systems/transportation/custom_fem_solo_sheet.jpg` | 5 | 684x588 | 0 | irregular layout, low confidence grid |
| `systems/transportation/custom_masc_solo_sheet.jpg` | 5 | 632x603 | 0 | none |
| `systems/transportation/solo_female_sheet.jpg` | 5 | 617x737 | 0 | none |
| `systems/transportation/solo_femboy_sheet.jpg` | 5 | 572x723 | 0 | frames 3,4 content crosses cell bottom edge (y 394+345 > 768 boundary of cell) - sliced by content bbox, not cell |
| `systems/transportation/solo_futanari_sheet.jpg` | 5 | 572x715 | 0 | frame 3 content crosses cell edge |
| `systems/transportation/solo_male_sheet.jpg` | 5 | 606x737 | 0 | frames 3,4 content crosses cell edge |
| `systems/transportation/tandem_custom_female_sheet.jpg` | 5 | 638x700 | 0 | frames 3,4 content crosses cell edge |
| `systems/transportation/tandem_custom_femboy_sheet.jpg` | 5 | 640x726 | 0 | frame 3 content crosses cell edge; TWO-TONE background, seam at x=688 - keyed against nearest corner colour |
| `systems/transportation/tandem_custom_futanari_sheet.jpg` | 5 | 637x718 | 0 | none |
| `systems/transportation/tandem_custom_male_sheet.jpg` | 5 | 660x731 | 0 | none |
| `systems/transportation/tandem_female_riley_sheet.jpg` | 5 | 642x737 | 0 | none |
| `systems/transportation/tandem_female_tasha_sheet.jpg` | 4 | 751x717 | 0 | ONLY 4 components: second side view missing from source art (hero starts at x=567 and takes its space); irregular layout, low confidence grid |
| `systems/transportation/tandem_femboy_riley_sheet.jpg` | 5 | 680x732 | 0 | irregular layout, low confidence grid |
| `systems/transportation/tandem_femboy_tasha_sheet.jpg` | 5 | 664x729 | 0 | frame 2 (hero) content crosses cell edge at x=683 |
| `systems/transportation/tandem_futanari_riley_sheet.jpg` | 5 | 591x709 | 0 | frames 3,4 content crosses cell edge |
| `systems/transportation/tandem_futanari_tasha_sheet.jpg` | 5 | 635x729 | 0 | frames 0,1 content crosses cell edge |
| `systems/transportation/tandem_male_riley_sheet.jpg` | 5 | 666x735 | 0 | frame 2 (hero) content crosses cell edge at x=682 |
| `systems/transportation/tandem_male_tasha_sheet.jpg` | 5 | 599x768 | 0 | irregular layout, low confidence grid; frame 4 content touches sheet edge: bbox [356,0,337,768] - clipped in source; 1 small accessory component merged into nearest figure frame |
| `systems/transportation/tandem_riley_female_sheet.jpg` | 5 | 661x704 | 0 | none |
| `systems/transportation/tandem_riley_femboy_sheet.jpg` | 5 | 686x737 | 0 | irregular layout, low confidence grid |
| `systems/transportation/tandem_riley_futanari_sheet.jpg` | 5 | 622x701 | 0 | frames 3,4 content crosses cell edge |
| `systems/transportation/tandem_riley_male_sheet.jpg` | 5 | 643x726 | 0 | frame 2 (hero) content crosses cell edge at x=689; frame 4 crosses cell edge |
| `systems/transportation/tandem_riley_tasha_sheet.jpg` | 5 | 620x718 | 0 | frame 3 content crosses cell edge |
| `systems/transportation/tandem_tasha_female_sheet.jpg` | 5 | 626x717 | 0 | frame 4 content crosses cell edge |
| `systems/transportation/tandem_tasha_femboy_sheet.jpg` | 5 | 650x711 | 0 | none |
| `systems/transportation/tandem_tasha_futanari_sheet.jpg` | 5 | 713x729 | 0 | irregular layout, low confidence grid |
| `systems/transportation/tandem_tasha_male_sheet.jpg` | 5 | 652x692 | 0 | none |
| `systems/transportation/tandem_tasha_riley_sheet.jpg` | 5 | 626x710 | 0 | frames 3,4 content crosses cell edge |

## Tandem lock (unchanged logic, real art bound)

`PUWBikes` tandem-lock logic was not changed by this build. `PUWBikeRigFacade` binds the real sliced tandem frames through that lock: tandem is refused without co-op and allowed with co-op, verified by the bike rig suite (`lock_tandem_refused_without_coop`, `lock_tandem_allowed_with_coop`, `facade_tandem_rig_locked_without_coop`, `facade_tandem_rig_loaded_with_coop`). Solo rigs need no co-op (`facade_solo_rig_no_coop_needed`). Speeds verified: acro 10.67, mach 16.0 tiles/sec.

## Addendum — tandem side-2 fix received and REJECTED (QA round 2, 2026-11-22)

Neon sent `systems/transportation/tandem_female_tasha_side2_fix.jpg` (1376x768, two left-facing pedalling phases) to supply the second side view missing from `tandem_female_tasha_sheet.jpg`. It was visually graded against the original sheet and its sliced frames (verdict: `qa_round2/grade_custom_femboy_futanari_walk_and_tandem.md` in the goal workspace). The original's one side view (f03) faces RIGHT, so the missing view is LEFT — and the fix does face left. It was still REJECTED, on match, not anatomy: the driver wears a baseball cap, black/white jacket and denim shorts instead of Custom Female's red/white visor and blue tracksuit; the passenger's hair is in a high ponytail instead of Tasha's long loose copper-orange waves, and she wears a navy tracksuit and orange shoes instead of the black skull-brooch dress and black boots; the pink/white wing-decorated tandem with Poke Ball hubs is replaced by a plain blue tandem; and the pair is drawn much smaller than f03's scale. Nothing was sliced or bound. The `custom_female>tasha` pairing remains PARTIAL at 3 ride frames [0, 1, 3], exactly as before, and `bike_frame_data.json` is unchanged. Still owed: a left-facing side view of the same pair, same outfits, same bike, same scale as f03 (see `NEON_ART_QA_FEEDBACK_2.md`).

## Addendum — layered bikes graded, ZERO stacks pass (QA round 4, 2026-11-22)

Neon's round-4 delivery replaced the flat bike sheets with a layered system (chassis + base body + outfit layers for Riley, Tasha and the four Custom presets). It was visually graded sheet by sheet and stack by stack (verdicts: `hidden_files/qa_round4/verdicts/bikes_core.md` and `bikes_custom.md` in the goal workspace; composites in `/tmp/qa4/composites/bikes_core/` and `bikes_custom/`). RESULT: zero stacks pass (core 0/8, custom 0/7). NOTHING from this delivery was sliced or bound; the existing flat bike bindings in `bike_frame_data.json` stay exactly as they are, and every alternate outfit's bike context in `systems/cast/wardrobe_registry.json` stays `signature_fallback` with this structural reason recorded.

### Per-sheet accepted / total (from the two verdict files)

Core (Riley + Tasha + chassis):

| Sheet | Accepted / Total |
|---|---|
| bike_chassis_acro_solo_4x4.jpg | 16/16 |
| bike_chassis_mach_solo_4x4.jpg | 13/16 |
| bike_chassis_tandem_4x4.jpg | 8/16 |
| riley_bike_unique_base_body.jpg | 20/32 cells |
| riley_bike_unique_outfit_canon.jpg | 20/32 cells |
| riley_bike_unique_outfit_lounge.jpg | 0/32 |
| riley_bike_unique_outfit_bikini.jpg | 20/32 cells |
| tasha_bike_unique_base_body.jpg | 24/28 |
| tasha_bike_unique_outfit_canon.jpg | 0/28 |
| tasha_bike_unique_outfit_gothic_glam.jpg | 0/28 |
| tasha_bike_unique_outfit_obsidian_bikini.jpg | 0/28 |
| All stacks (6 solo + 2 tandem) | 0 pass |

Custom cast (body + outfit layering itself is good — the two rider layers share one grid per preset and align figure-for-figure; the failures are the chassis stacks and the specific figures below):

| Sheet | Accepted / Total |
|---|---|
| custom_female base_body | 23/28 |
| custom_female outfit_trainer_canon | 24/28 |
| custom_female outfit_streetwear | 24/28 |
| custom_female outfit_athletic | 24/28 |
| custom_female outfit_swimwear | 24/28 |
| custom_male base_body | 24/28 |
| custom_male outfit_trainer_canon | 23/28 |
| custom_male outfit_streetwear | 22/28 |
| custom_male outfit_athletic | 21/28 |
| custom_male outfit_swimwear | 24/28 |
| custom_femboy base_body | 24/24 |
| custom_femboy outfit_trainer_canon | 22/24 |
| custom_femboy outfit_streetwear | 21/24 |
| custom_femboy outfit_athletic | 23/24 |
| custom_femboy outfit_swimwear | 12/24 |
| custom_futanari base_body | 27/32 |
| custom_futanari outfit_trainer_canon | 23/32 |
| custom_futanari outfit_streetwear | 24/32 |
| custom_futanari outfit_athletic | 27/32 |
| custom_futanari outfit_swimwear | 27/32 |
| Custom total | 463/560 |
| All chassis stacks (7) | 0 pass |

### The grid-mismatch finding (why zero stacks can bind)

The three layer types do NOT share a grid, and the delivery manifest defines no anchors or offsets:

- Chassis sheets: 4 cols x 4 rows, cells 344x192.
- Riley rider sheets: 8 cols x 4 rows, cells 172x192.
- Tasha rider sheets: 7 cols x 4 rows, cells ~196x192 (uneven column spacing, roughly 190-233 px).
- Custom rider sheets: 7 cols (female, male), 6 cols (femboy), 8 cols (futanari), all x 4 rows of 192.

Composited as delivered at full-sheet alignment, TWO riders land on every side-view bike at the wrong places; nobody's seat is on a saddle, hands never reach the handlebars (side-view hands are held at the lap or chest, or on the hip), and feet hang below/behind the pedals. This is a layout failure, not a grading choice: nothing was re-aligned, scaled or mirrored to force a fit, because inventing placement data is not grading. A second, independent direction defect: for both Riley and Tasha, rider rows 3 AND 4 both face right — there is no left-facing rider row — while the chassis side rows are row 3 = left, row 4 = right, so half the side composites would face into the back of the bike even on a shared grid.

### Tandem finding

There are NO separate driver and passenger tandem poses anywhere in this delivery, and no tandem outfit layers at all. Riley's base sheet column F8 bakes BOTH riders into a single cell — and both figures are Riley; the pair is ~197 px wide against a ~318 px tandem frame, cannot be split into driver/passenger layers, cannot be re-ordered, and cannot put Tasha on the back. Custom Female's F7 cells are the same defect (a same-character pair as ONE connected component in all four rows); Custom Male's pair cells are irregular (R1F7, R2F7, R4F6, R4F7 — the left row has none); Custom Femboy and Custom Futanari have no pair cell at all. Tasha's bike sheets contain NO tandem poses and NO passenger figure of any kind. Conclusion: the layered system does NOT resolve the `custom_female>tasha` tandem pairing — it stays at 3 ride frames, exactly as before, and the pairing now cannot be built at all from layers until Neon delivers separate driver-only and passenger-only layers per character on the SAME grid as the tandem chassis, for all four rows. The tandem chassis side views (rows 3-4) are the only usable tandem art in this delivery, and they stay unbound like everything else here.

### Worst defects (redo list)

1. Layer grids do not match (chassis 344 px cells vs rider 172 / ~196 / ~229 px cells) and no anchors are defined — no stack can be assembled at all.
2. No tandem driver/passenger poses exist; the only tandem cells bake two clones of the same character into one unsplittable cell, and Tasha has no passenger figure.
3. Tasha's canon and gothic_glam bike outfits paint hands and thighs in bright magenta-pink inside the #FF00FF key family in every cell — those body parts key out to holes (the round-3 hot-pink failure repeated).
4. Tasha's obsidian_bikini bike layer paints skin (front and back rows) and whole body outlines (side rows) — 0/28.
5. Riley's lounge bike layer paints skin-tone leg bands in every cell and its sleeves are giant tubes that swallow the base arms — 0/32.
6. All-fours crawling poses delivered again: Riley base F6-F7 (8 cells) and Tasha base F4 (4 figures) — the same defect class rejected in round 2.
7. Both riders' row 4 faces right, same as row 3 — no left-facing rider row exists; side-view hands never reach the handlebars and feet never land on the pedals in any pose.
8. Mach chassis row 1 (F2-F4) and tandem chassis rows 1-2 are tilted three-quarter views instead of front/back views; the tandem has no front or back view at all.
9. Custom sheets: front-facing figures inside side/back rows (every preset's column 4, plus male/futanari back-row figures), outfit collars painted over the face in several front-row figures, the R4 lean figure copied facing left into the right row, Custom Femboy swimwear side rows painting full pink skin legs (and arms in R4) into the outfit layer, and Custom Male's tandem pair missing from the left row.

## Addendum — shared-grid bikes graded: chassis PASS, ZERO rider stacks pass (QA round 6, 2026-11-23)

Neon's round-6 delivery put every bike sheet on the shared grid at last (all sheets 1376x768, 4x4, cells 344x192) with the key EXACTLY #FF00FF everywhere — the round-4 wrong-magenta defect (255,100,253) and the grid mismatch are both gone, and the stacks could actually be tested this time. Graded in `hidden_files/qa_round6/verdicts_bikes_core.md` and `verdicts_bikes_custom.md`; integrated by `tools/slice_qa_art_round6.py`.

CERTIFIED AND BOUND — chassis only (48 frames, `bike_frame_data.json` section `layered_chassis_round6`, frames under `art/frames/systems/transportation/layered_chassis_round6/`):

| Chassis sheet | Verdict |
|---|---|
| bike_chassis_acro_solo_4x4.png | PASS 16/16 — true front/back/left/right, clean again |
| bike_chassis_mach_solo_4x4_v2.png | PASS 16/16 — round-4 front-row tilt FIXED (true straight-on front) |
| bike_chassis_tandem_4x4_v2.png | PASS 16/16 as a chassis — round-4 missing front/back views FIXED; two saddles, two crank sets |

NOT CERTIFIED — every rider stack (solo and tandem, base and outfit, all six cast members). NO rider bike frames were sliced or bound this round; the existing flat bike bindings are untouched, and no bike contact sheet was made (a sheet of bound bike art would be false — round-4 precedent). The failure is systemic and lives in the rider BASE sheets, so every outfit stack built on them fails with them:

1. Side-row heads sliced at the cell top: the side riders are drawn too tall / too high for the 192px cell (rows 3 and 4, every cell, all six riders). The face survives; the top of the skull/hair is cut off flat.
2. The missing head-top is painted as a detached hair-coloured blob at the bottom of other cells (rows 1-3 depending on the sheet). In game it would render as a floating blob rolling along under the wheels. No cell containing it can be bound.
3. Front/back rows: hands hang at the hips and never grip the handlebars (the bars sit untouched behind the shoulders); feet dangle beside the front wheel, off the pedals.
4. Row 4 (right): riders sit behind the saddle instead of on it (row 3 sits better — hands on bars, front foot on pedal).
5. Tandem: the layers are now genuinely separate and land in two saddle positions (round-4 structure fixed), but the passenger has no real passenger pose — her feet never reach the rear pedals, her hands reach toward the driver's back/bars — and the front/back views fuse the two riders into one two-headed figure (halo hair, four arms around one body; back view hides the passenger with limbs splayed).

Outfit layers themselves mostly align well this round (15 of 16 custom outfit layers align; Riley canon/bikini bike outfits pass as layers). Their own defects, for the redo list: Riley lounge bike outfit still paints bare arms and skin between leg straps (not clothing only — round-4 defect not fixed); Tasha bike outfits are drawn too high in the front row (canon pendant/collar on her face, gothic collar over her mouth, obsidian top over her chin; canon row 2 collar floats above her head); Tasha obsidian side rows contain big painted skin/mauve paddle shapes; Custom Futanari trainer_canon bike outfit covers the mouth/chin in row 1 and has a round key-hole in the torso in rows 3-4.

Nearest miss, for the record: Tasha + mach chassis, LEFT, base/canon/gothic passes every riding test (butt on saddle, hands on drop bars, front foot on pedal, no clipping) and fails ONLY on the base sheet's sliced head + loose dome. It is NOT certified — the dome would render in game — but it is one base-sheet fix away.

What Neon must redo (plain list, from the verdicts): (1) all six base sheets — draw side riders small/low enough that the whole head fits inside the 344x192 cell, and delete the detached hair blob; (2) front/back rows — hands on the grips, feet on the pedals; (3) row 4 — shift the rider forward onto the saddle; (4) Tasha outfits row 1 (and canon row 2) — move garments down onto the chest; (5) Riley lounge — clothing only, key out the skin; (6) Tasha obsidian rows 3-4 — remove the painted skin/paddle shapes; (7) tandem — a real passenger pose (hands on rear bars or resting, feet on rear pedals) and front/back views with the passenger visibly offset, not stacked inside the driver.

## Addendum — B1–B7 CLOSED: bench side rows + tandem drivers bound (bench-2 binding, 2026-11-23)

After four Neon rounds (v3–v5), the bike wall fell in-house. Bench round 2 (hidden_files/bench_round2/BENCH2_REPORT.md, under Riley's Neon-fails rule) redrew the side rows at the certified round-6 v2 chassis register and this build bound the result (bike_frame_data.json section `layered_stacks_bench2`, frames under `art/frames/systems/transportation/layered_stacks_bench2/`):

- **12 base stacks bound whole** — 6 solo + 6 tandem (driver + passenger), 16 full-cell frames each. Provenance split per sheet: rows 1–2 are Neon's v5 (round-11 contact PASS, pixel-identical in the bench sheets); rows 3–4 and the tandem DRIVER layers are in-house bench work. The driver layer is new: the v5 file set never had one, so a correct tandem stack was impossible from the delivered files — part of why B7 kept failing.
- **Contacts, bench-measured and re-checked on the binding copies:** fist-to-grip gap 0.0 in all 144 side cells; feet on the crank circle in every phase (BDC foot overlaps the chassis pedal block exactly); hip centre inside the saddle x-range in every cell, seat flush on the saddle body. B1–B7 are CLOSED.
- **Two findings recorded, nothing silently fixed:** (1) the round-11 verdict's tandem coordinates describe the layered tandem sheet in its own crop; against the certified v2 frames at the anchor rule the stations are driver grip x94–121, driver saddle x115–150 top y48, front crank (143,140), passenger saddle x212–260 top y44, stoker grip x169–191, rear crank (188,140) — the bench rows are bound at the v2 register. (2) The layered mach chassis SHEET's rows 3 AND 4 both face right (R4−R3 ≈ 1,381 px); the certified v2 frames have row 4 as the true mirror. The sheet is left as delivered; the stacks use the correct facing from the v2 frames.
- **Outfit stacks: 0 of 22 bind, all held with reasons** (bike_frame_data.json `held_outfit_stacks`). The QA-round-9 v3 outfit layers are full-figure layers drawn in the v3 poses; over the bench bases they render as a second, upright rider in rows 3–4 and seat nowhere (per-cell garment overhang 0.12–0.69; detached far components up to 2,516 px; verified visually at binding). The layer sheets are in the pack under `art/sheets/systems/transportation/layered/` for a future register redraw. This does not reopen B1–B7: the bases they blocked on are bound.
