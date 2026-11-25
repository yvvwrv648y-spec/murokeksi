# Kanto + Sevii maps — status: BUILT (phase 2 complete)

Riley approved processing the disassembly clones on 2026-11-22
("Yes, process pokered and add pokefirered for Sevii"), and the
conversion is done. Sources: pret/pokered (Kanto) and
pret/pokefirered (Sevii) — disassembly data files only. No ROMs,
no game binaries, and neither repo's build tools were run; our
own converters (maps/tools/) parsed the data as text/data.

## Kanto — 223 maps built

Every Kanto map that has data was converted: Pallet Town, all
cities, all 25 routes, every interior, Gym, Pokemon Center,
dungeon, and the Indigo Plateau rooms. Each scene has the real
tile layout (map .blk block data expanded through the tileset
blocksets), real collision (the game's own per-tileset collision
tile lists, as physics polygons in the tilesets), real warps
(from data/maps/objects/, as Warp markers with destination map +
warp index), and its connections in the scene metadata. Object,
sign, and NPC/trainer placement data for every map is in
maps/data/maps/<MapName>.json.

Load test: all 223 scenes load in Godot 4.7.2 headless with zero
errors and the exact cell counts from the source data
(tests/map_tests.log).

### Kanto maps NOT built — 6, all with no data to build from
- UnusedDiglettsCaveCopy, UnusedEmptyMap, UnusedPokecenterCopy —
  leftover .blk files with no map header; unused data the game
  never loads.
- CERULEAN_TRASHED_HOUSE_COPY, UNDERGROUND_PATH_ROUTE_6_COPY,
  CINNABAR_MART_COPY — constants in map_constants.asm with no
  header or block data of their own (the game reuses the
  original maps' data for these slots).

### One data quirk, handled from the data itself
UndergroundPathNorthSouth: map_constants.asm declares 4x24
blocks, but the .blk file holds 92 blocks (4x23) — the repo's own
comment on that line says the .blk is actually 4x23. The scene
uses the real .blk height (23).

## Sevii Islands — 160 maps built

All 160 Sevii maps found in pret/pokefirered were converted:
the seven islands' towns and ports, interiors, and the Sevii
dungeons and areas (Mt. Ember, Berry Forest, Icefall Cave,
Dotted Hole, Lost Cave, Tanoby Ruins, Navel Rock, Birth Island,
Trainer Tower, and the rest — every name is listed in
SEVII_STATUS.md and maps/data/sevii_conversion_report.json).
GBA format: one metatile grid per map plus the data's explicit
per-cell collision grid (kept as the hidden Collision layer in
each scene). Warps, objects, and connections are in the map
JSONs. Load test: all 160 pass, zero errors.

Not counted as Sevii (correctly): Cinnabar Island and the
Seafoam Islands are Kanto (built in the Kanto set). Excluded:
Prototype_SeviiIsle_6/7/8/9 — unused prototype test maps in the
repo, not real game maps.

## Presentation

Scenes follow Riley's art direction (BW2 base, pushed toward a
2D/3D hybrid; presentation only, data untouched): Y-sort depth
on roots and layers, a neutral Presentation CanvasModulate
lighting hook in every scene, and nearest-neighbour filtering as
the recorded project setting. Full note in ../MERGE_README.md.

## Totals

383 map scenes built, 383 load-tested, 0 failed. 48 tilesets
(24 Kanto + 24 Sevii) plus the shared collision helper.
