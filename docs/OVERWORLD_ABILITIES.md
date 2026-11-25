# OVERWORLD ABILITIES AND MOVES — RESEARCHED LIST (PUW, 2026-11-23)

Compiled by Bossy (Worker C) from the project's real data plus canon
behavior. Every entry was VERIFIED to exist in the data; the overworld
effect itself is canon (Bulbapedia / veekun ability & move references).
Nothing in this list was assumed from the brief alone.

Data sources used for verification:
- Project: `battle/ability_engine.gd` (ability roster + descriptions),
  `data/moves.json` (Showdown moves data, 954 moves, sourced from
  smogon/pokemon-showdown, fetched 2026-11-22), `data/competitive_sets.json`
  and `pokemon/registry/master_species_registry.json` (species abilities),
  `data/learnsets_compact.json` (species learnsets — used ONLY to confirm
  a move exists in a learnset for research; triggers never read learnsets).
- Data pack: `data/abilities.json` (Showdown abilities, 321 entries).
- Canon overworld-effect behavior: Bulbapedia "Ability — Effects outside
  of battle" / veekun ability pages (Pickup's 10% post-battle check and
  level-banded item table also via polisheddex.app/guides/pickup-table;
  the table itself is transcribed in `systems/followers/pickup_table.json`).

TRIGGER RULE (Riley refinement, 2026-11-23): a follower triggers an
effect ONLY from its ACTIVE ability (the individual's stored `ability`
field — the exact field `battle/battle_controller.gd` reads) or a move in
its CURRENTLY KNOWN moveset (the individual's slotted `moves` list).
Species possible-ability lists and species learnsets never qualify.

SURPRISE RULE (Riley, binding): triggers fire on the follower's own
initiative at rare intervals. No popup, tutorial, or system text names or
explains any mechanic, anywhere. The event is the feedback.

## Abilities with overworld effects

| Ability | Canon overworld effect | Status in this build |
|---|---|---|
| Pickup | 10% check after battle; finds an item from the level-banded table | WIRED — overworld form: 10% per 1.0 s exploration tick (PUW design parameter, labeled in code) while in IDLE/WANDER/SCOUT; items only from `pickup_table.json`; item goes to the real MartShop bag; diegetic signal only |
| Honey Gather | May pick up Honey after battle (chance grows with level in canon) | WIRED — same registry hook; flat 5% per exploration tick is a PUW design parameter (canon level formula not reproduced); item `honey` to the real bag |
| Illuminate | Doubles wild encounter rate (Gen 3–7 form; PUW keeps it) | WIRED — x2 in `encounter_rate_multiplier()`, applied by OverworldLoop |
| Arena Trap | Doubles wild encounter rate | WIRED — x2, same path |
| Stench | Halves wild encounter rate | WIRED — x0.5, same path |
| White Smoke | Halves wild encounter rate | WIRED — x0.5, same path |
| Static | 50% chance a wild encounter is Electric-type when one is in the pool | WIRED — in `follower_roll_encounter()` type attraction |
| Magnet Pull | 50% chance a wild encounter is Steel-type when one is in the pool | WIRED — same path |
| Synchronize | Wild encounters have a 50% (Gen 8+) / guaranteed (older) chance to share the follower's nature | WIRED (pass-through) — encounter dict carries `nature_influenced`; the follower individual's own nature is the battle layer's to apply when it builds the wild mon |
| Compound Eyes | Raises the chance wild Pokemon hold items | WIRED (flag) — encounter dict carries `wild_held_item_bonus`; item assignment belongs to the battle/team-builder layer |
| Intimidate | Wild Pokemon at least 5 levels below the follower are repelled (50%) | DOCUMENTED-ONLY — habitat pool entries carry NO level (levels are assigned later by PUWTeamBuilder at battle entry), so a level filter cannot be applied honestly at pool stage |
| Keen Eye | Same repel-below-level effect as Intimidate | DOCUMENTED-ONLY — same reason |
| Cute Charm | 2/3 chance wild encounters are the opposite gender | DOCUMENTED-ONLY — pool entries carry no gender data; no gender is invented |
| Flame Body / Magma Armor / Steam Engine | Eggs hatch in half the steps | DOCUMENTED-ONLY — no egg-incubation system is reachable from the follower layer in this build |
| Hustle / Vital Spirit | Shifts wild level distribution upward / encounter rate up in some gens | DOCUMENTED-ONLY — same no-levels-in-pool reason as Intimidate |
| Run Away / Illuminate (Gen 9) | — | Noted: Gen 9 changed/removed some effects; PUW uses the classic forms above, stated here so the choice is visible |

## Moves with overworld / field effects (autonomous follower triggers)

HM-style field moves (Cut, Surf, Fly, Strength, Flash, Waterfall,
Rock Smash, Dig, Teleport-as-escape, etc.) are NOT part of this list:
they are already covered by the badge-locked field-action system
(`systems/overworld/field_actions.gd`, FIELD_ACTIONS.md).

| Move | Canon field effect | Status |
|---|---|---|
| Sweet Scent | Immediately starts a wild encounter from the local pool | WIRED — follower that KNOWS the move triggers it at 5% per exploration tick (PUW design parameter, rare by design); encounter rolled from the local PUWHabitatEncounters pool with follower composition influences |
| Roar | Ends / scares off a wild encounter | WIRED — follower that KNOWS the move cancels a pending encounter at 5% per exploration tick (PUW design parameter); diegetic cry/emote only |
| Soft-Boiled / Milk Drink | Heal party Pokemon from the menu | DOCUMENTED-ONLY — menu action, not an autonomous follower behavior; no party-HP interaction in the follower layer |
| Aromatherapy (field use in some gens) | — | DOCUMENTED-ONLY — no verified autonomous field effect in the moves data |

## Perching data note

Map JSONs (`maps/data/maps/*.json`) carry unnamed numeric tile ids and
NPC-only `objects`; tilesets carry no tile names. There is NO data source
that identifies a tile as a tree or branch. Environmental perch points
are therefore defined honestly as solid obstacle-top tiles adjacent to
walkable ground (`find_perch_point()`), and no tile is claimed to be a
tree. Trainer perching uses a weight threshold: PERCH_TRAINER_MAX_KG =
10.0 kg (PUW design parameter; Pidgey 1.8 kg perches on the trainer,
Charizard 90.5 kg uses environmental perch points or keeps flying).
