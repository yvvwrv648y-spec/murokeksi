# Sevii Islands - Status

## Clone

- git clone --depth 1 https://github.com/pret/pokefirered worked.
- The code is saved at ~/workspace/puw_world/src/pokefirered
- No ROM or game binary was downloaded. No build tools from the repo were run.
  The repo files were only read as data by my own Python script
  (convert_sevii.py, saved in this same folder).

## How the Sevii maps were picked

- I used the repo's own data: each map's map.json "region_map_section" field,
  the map groups in data/maps/map_groups.json, and the map folder names.
- A map counted as Sevii if its folder name starts with OneIsland, TwoIsland,
  ThreeIsland, FourIsland, FiveIsland, SixIsland, SevenIsland, MtEmber,
  TrainerTower, BirthIsland, or NavelRock. Mt. Ember sits on One Island,
  Trainer Tower sits on Seven Island, and Birth Island and Navel Rock are the
  extra Sevii islands (Isle 8 and Isle 9).
- Not counted: the 4 unused test maps named Prototype_SeviiIsle_6,
  Prototype_SeviiIsle_7, Prototype_SeviiIsle_8, Prototype_SeviiIsle_9. They are
  prototypes, not real game maps.
- Kanto places with "Island" in the name, like Cinnabar Island and the Seafoam
  Islands, were NOT counted. They are not Sevii.

## Maps found: 160

BirthIsland_Exterior, BirthIsland_Harbor, FiveIsland, FiveIsland_Harbor, FiveIsland_House1, FiveIsland_House2, FiveIsland_LostCave_Entrance, FiveIsland_LostCave_Room1, FiveIsland_LostCave_Room10, FiveIsland_LostCave_Room11, FiveIsland_LostCave_Room12, FiveIsland_LostCave_Room13, FiveIsland_LostCave_Room14, FiveIsland_LostCave_Room2, FiveIsland_LostCave_Room3, FiveIsland_LostCave_Room4, FiveIsland_LostCave_Room5, FiveIsland_LostCave_Room6, FiveIsland_LostCave_Room7, FiveIsland_LostCave_Room8, FiveIsland_LostCave_Room9, FiveIsland_Meadow, FiveIsland_MemorialPillar, FiveIsland_PokemonCenter_1F, FiveIsland_PokemonCenter_2F, FiveIsland_ResortGorgeous, FiveIsland_ResortGorgeous_House, FiveIsland_RocketWarehouse, FiveIsland_WaterLabyrinth, FourIsland, FourIsland_Harbor, FourIsland_House1, FourIsland_House2, FourIsland_IcefallCave_1F, FourIsland_IcefallCave_B1F, FourIsland_IcefallCave_Back, FourIsland_IcefallCave_Entrance, FourIsland_LoreleisHouse, FourIsland_Mart, FourIsland_PokemonCenter_1F, FourIsland_PokemonCenter_2F, FourIsland_PokemonDayCare, MtEmber_Exterior, MtEmber_RubyPath_1F, MtEmber_RubyPath_B1F, MtEmber_RubyPath_B1F_Stairs, MtEmber_RubyPath_B2F, MtEmber_RubyPath_B2F_Stairs, MtEmber_RubyPath_B3F, MtEmber_RubyPath_B4F, MtEmber_RubyPath_B5F, MtEmber_Summit, MtEmber_SummitPath_1F, MtEmber_SummitPath_2F, MtEmber_SummitPath_3F, NavelRock_1F, NavelRock_B1F, NavelRock_Base, NavelRock_BasePath_B10F, NavelRock_BasePath_B11F, NavelRock_BasePath_B1F, NavelRock_BasePath_B2F, NavelRock_BasePath_B3F, NavelRock_BasePath_B4F, NavelRock_BasePath_B5F, NavelRock_BasePath_B6F, NavelRock_BasePath_B7F, NavelRock_BasePath_B8F, NavelRock_BasePath_B9F, NavelRock_Exterior, NavelRock_Fork, NavelRock_Harbor, NavelRock_Summit, NavelRock_SummitPath_2F, NavelRock_SummitPath_3F, NavelRock_SummitPath_4F, NavelRock_SummitPath_5F, OneIsland, OneIsland_Harbor, OneIsland_House1, OneIsland_House2, OneIsland_KindleRoad, OneIsland_KindleRoad_EmberSpa, OneIsland_PokemonCenter_1F, OneIsland_PokemonCenter_2F, OneIsland_TreasureBeach, SevenIsland, SevenIsland_Harbor, SevenIsland_House_Room1, SevenIsland_House_Room2, SevenIsland_Mart, SevenIsland_PokemonCenter_1F, SevenIsland_PokemonCenter_2F, SevenIsland_SevaultCanyon, SevenIsland_SevaultCanyon_Entrance, SevenIsland_SevaultCanyon_House, SevenIsland_SevaultCanyon_TanobyKey, SevenIsland_TanobyRuins, SevenIsland_TanobyRuins_DilfordChamber, SevenIsland_TanobyRuins_LiptooChamber, SevenIsland_TanobyRuins_MoneanChamber, SevenIsland_TanobyRuins_RixyChamber, SevenIsland_TanobyRuins_ScufibChamber, SevenIsland_TanobyRuins_ViapoisChamber, SevenIsland_TanobyRuins_WeepthChamber, SevenIsland_TrainerTower, SevenIsland_UnusedHouse, SixIsland, SixIsland_AlteringCave, SixIsland_DottedHole_1F, SixIsland_DottedHole_B1F, SixIsland_DottedHole_B2F, SixIsland_DottedHole_B3F, SixIsland_DottedHole_B4F, SixIsland_DottedHole_SapphireRoom, SixIsland_GreenPath, SixIsland_Harbor, SixIsland_House, SixIsland_Mart, SixIsland_OutcastIsland, SixIsland_PatternBush, SixIsland_PokemonCenter_1F, SixIsland_PokemonCenter_2F, SixIsland_RuinValley, SixIsland_WaterPath, SixIsland_WaterPath_House1, SixIsland_WaterPath_House2, ThreeIsland, ThreeIsland_BerryForest, ThreeIsland_BondBridge, ThreeIsland_DunsparceTunnel, ThreeIsland_Harbor, ThreeIsland_House1, ThreeIsland_House2, ThreeIsland_House3, ThreeIsland_House4, ThreeIsland_House5, ThreeIsland_Mart, ThreeIsland_PokemonCenter_1F, ThreeIsland_PokemonCenter_2F, ThreeIsland_Port, TrainerTower_1F, TrainerTower_2F, TrainerTower_3F, TrainerTower_4F, TrainerTower_5F, TrainerTower_6F, TrainerTower_7F, TrainerTower_8F, TrainerTower_Elevator, TrainerTower_Lobby, TrainerTower_Roof, TwoIsland, TwoIsland_CapeBrink, TwoIsland_CapeBrink_House, TwoIsland_Harbor, TwoIsland_House, TwoIsland_JoyfulGameCorner, TwoIsland_PokemonCenter_1F, TwoIsland_PokemonCenter_2F

## Maps converted: 160 of 160

Every map above was converted. The converted list is the same as the found
list, name for name. Each one is saved as its own file in the maps folder:
~/workspace/puw_world/work/sevii/maps/<MapName>.json

## Maps that did not convert

None. All 160 maps converted.

One fix was needed on the way: TrainerTower_Elevator has a warp whose
dest_warp_id is the word "WARP_ID_DYNAMIC" instead of a number. That word is
kept as-is in its JSON file instead of a number.

## How the map data works in this repo (checked, not guessed)

- This repo (pokefirered) stores ONE blockdata file per layout, called
  map.bin. It does not store separate bottom and top blockdata files.
- map.bin is 2 bytes per cell, little-endian: bits 0-9 = metatile id,
  bits 10-11 = collision (nonzero = blocked), bits 12-15 = elevation.
- So each map JSON has one "tiles" grid. There is no "tiles_top" grid,
  because the layout truly has only one layer of cells.
- The bottom/top split lives inside each metatile instead: metatiles.bin
  holds 8 tile entries per metatile, the first 4 are the bottom layer and
  the last 4 are the top layer. The atlas pictures below use the bottom
  4 entries of each metatile.
- Collision: "collision_grid" is true where the cell's collision bits
  (bits 10-11) are nonzero, false everywhere else.
- Metatile ids: ids 0 to 639 belong to the primary tileset and ids 640 and
  up belong to the secondary tileset. This comes from the repo itself:
  include/fieldmap.h says NUM_METATILES_IN_PRIMARY is 640 and
  NUM_METATILES_TOTAL is 1024.
- Warps, objects, and connections were copied straight from each map's
  map.json file.

## Checks run on every map

- The tiles grid length equals width times height. Passed for all 160 maps.
- The collision grid length equals width times height. Passed for all 160 maps.
- Every metatile id is inside its tileset's metatile count (primary count
  for ids under 640, secondary count for ids 640 and up). Passed for all
  160 maps. Zero problems found.
- A second, separate check script re-read all 160 finished JSON files and
  checked the grid lengths again. All passed.

## Tileset pictures (atlases)

- 24 tileset pairs are used by the Sevii maps. One atlas picture was made
  for each pair, saved in ~/workspace/puw_world/work/sevii/tilesets/
- The list of pairs is in ~/workspace/puw_world/work/sevii/tilesets.json
- Pairs: building__fan_club_daycare, building__game_corner, building__generic_building_2, building__lab, building__mart, building__museum, building__pokemon_center, building__safari_zone_building, building__seafoam_islands, building__silph_co, building__tanoby_ruins, building__trainer_tower, general__berry_forest, general__cave, general__digletts_cave, general__island_harbor, general__mt_ember, general__navel_rock, general__rock_tunnel, general__seafoam_islands, general__sevii_islands_123, general__sevii_islands_45, general__sevii_islands_67, general__viridian_forest
- Each atlas is laid out 32 metatiles per row, each metatile 16 by 16
  pixels. The slot number in the atlas is the game's global metatile id:
  primary metatiles first (0-639), then secondary (640 and up).
- The pictures were drawn with PIL from the repo's tiles.png files and
  metatiles.bin files, using each tile's own palette file and honoring
  horizontal and vertical flips.
- Spot check: I rebuilt the One Island map picture from its atlas. The
  land, water, paths, cliffs, and trees all look right.
- Two honest notes about the pictures:
  1. Some metatiles show bright pink (magenta). That pink is a real color
     in the repo's own palette files (255, 0, 255). It is used for blank
     tiles. It is not missing data.
  2. Only the bottom layer of each metatile is drawn in the atlas. The top
     layer tile entries are still in the repo data and in metatiles.bin,
     but they are not drawn in these atlas pictures.
- One tileset needed special handling: gTileset_SilphCo (used by
  FiveIsland_RocketWarehouse and TrainerTower_Elevator) has no tiles.png
  of its own in the repo. The repo's headers.h says it shares the
  Condominiums tileset's tiles and palettes, so those were used to draw
  its atlas. Its own metatiles.bin was used as normal.

## Files

- Maps: ~/workspace/puw_world/work/sevii/maps/ (160 JSON files)
- Atlases: ~/workspace/puw_world/work/sevii/tilesets/ (24 PNG files)
- Tileset index: ~/workspace/puw_world/work/sevii/tilesets.json
- Converter script: ~/workspace/puw_world/work/sevii/convert_sevii.py
- Machine check report: ~/workspace/puw_world/work/sevii/conversion_report.json
- This status file: ~/workspace/puw_world/work/sevii/SEVII_STATUS.md
