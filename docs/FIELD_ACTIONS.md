# Field Actions — badge-locked, newest-generation style

System: `PUWFieldActions` (`systems/overworld/field_actions.gd`)
Tests: `tests/field_action_tests.gd` — 58 passed, 0 failed
Canon: Riley, 2026-11-22, Phase 3 item C

## This replaces classic HMs

Classic HMs are gone. There are no HM items, no HM slaves, and no move-slot tax: a follower/partner Pokemon performs a field action when it is *able*, the way the newest games handle field traversal. The moves themselves still exist as battle moves, completely unchanged — Cut, Flash, Fly, Surf, Strength, Teleport, Dig, Rock Smash and Waterfall are all ordinary moves in `data/move_database_954.json`, learnable and usable in battle exactly as before. This system governs only their use as field actions, and it adds Riley's hard rule on top: **every field action is badge-locked.** Capability without the badge is refused; the badge without capability is refused. Both axes must pass.

A party member qualifies on the **capability axis** in either of two ways:

- **Move path** — it knows the action's matching move (a real move id from our move data).
- **Natural path** — it has the action's natural capability, a rule computed only from species data this project actually holds (types, abilities, level-up learnsets). Where no principled data rule exists, the action is move-only and this document says so plainly.

Followers are party members for this system: the 1–6 follower system draws its followers from the party, so any party member can be the performer. (Assumption documented in the code header.)

The **badge axis** resolves through the campaign state: `state["badges"]` holds gym ids (awarded by `GymProgression.award_badge`, as the campaign stitch does), and each action's badge name is read from that gym's record in `data/gym_requirements.json`.

`can_perform(state, party, action_id)` returns `{"allowed", "reason", "via", "species"}` where reason is `ok`, `badge_missing` (checked first — the badge axis is independent of capability), `no_qualifying_pokemon`, or `unknown_action`. `perform(...)` runs the same check and, only when allowed, appends the action id to `state["story_flags"]["field_actions_used"]`.

## The table

| Action | Matching move (id) | Unlocking badge | Badge source | Natural rule |
|---|---|---|---|---|
| cut | Cut (`cut`) | Cascade Badge (Cerulean, `kanto_gym_2_misty`) | Source-defined | `slicing_learnset` — level-up learnset contains a slicing move (below) |
| illuminate | Flash (`flash`) | Boulder Badge (Pewter, `kanto_gym_1_brock`) | Source-defined | `illumination_type` — Electric-type or Fire-type |
| fly | Fly (`fly`) | Thunder Badge (Vermilion, `kanto_gym_3_surge`) | Source-defined | `flight` — Flying-type, or ability Levitate |
| surf | Surf (`surf`) | Soul Badge (Fuchsia, `kanto_gym_5_koga`) | Source-defined | `water_type` — Water-type |
| strength | Strength (`strength`) | Rainbow Badge (Celadon, `kanto_gym_4_erika`) | Source-defined | **Move-only** — no natural rule defined |
| teleport | Teleport (`teleport`) | Marsh Badge (Saffron, `kanto_gym_6_sabrina`) | PUW design | `psychic_type` — Psychic-type |
| dig | Dig (`dig`) | Volcano Badge (Cinnabar, `kanto_gym_7_blaine`) | PUW design | `ground_type` — Ground-type |
| rock_smash | Rock Smash (`rocksmash`) | Volcano Badge (Cinnabar, `kanto_gym_7_blaine`) | PUW design | **Move-only** — no natural rule defined |
| waterfall | Waterfall (`waterfall`) | Earth Badge (Viridian, `kanto_gym_8_giovanni`) | PUW design | **Move-only** — no natural rule defined |

All 9 matching move ids were verified present in `data/move_database_954.json` (Cut #15, Flash #148, Fly #19, Surf #57, Strength #70, Teleport #100, Dig #91, Rock Smash #249, Waterfall #127).

## The badge map and its reasoning

Five gates are **source-defined**: in the Gen 1 games the matching HM move's field use is gated behind exactly that badge — Flash behind the Boulder Badge, Cut behind the Cascade Badge, Fly behind the Thunder Badge, Strength behind the Rainbow Badge, Surf behind the Soul Badge. PUW keeps those gates and extends the same treatment to the other four actions.

The other four have no Gen 1 gate (Teleport and Dig were TMs, Rock Smash and Waterfall belong to later games' HM sets), so their badges are a **PUW design decision**, assigned to the three remaining Kanto badges by theme so the full traversal kit is spread across the whole badge run:

- **teleport → Marsh Badge.** Sabrina's Saffron Gym is the Psychic gym, and Teleport is the Psychic-type escape move; its natural rule is Psychic-type for the same reason.
- **dig → Volcano Badge** and **rock_smash → Volcano Badge.** Digging through earth and breaking rock are the same field family — earth-breaking — so one badge gates both. Blaine's Cinnabar Gym sits in volcanic ground, which is the thematic home of that family. This is the one badge that gates two actions, deliberately.
- **waterfall → Earth Badge.** The last badge gates the last traversal class: climbing waterfalls is endgame movement (in the source games Waterfall gates the approach to the Pokemon League), so it waits for Giovanni's Earth Badge.

## Natural rules, per action

- **illuminate — type-based (Riley's rule).** Any Electric-type or Fire-type follower gives off light of its own and can illuminate a dark cave without knowing Flash. Types come from `data/competitive_sets.json` (all 1,025 species), with the master species registry taking precedence where it has an entry.
- **cut — body-based.** A species qualifies if its **level-up** learnset in `data/learnsets_compact.json` contains at least one **slicing** move: the species grows a blade as part of its natural development. TM, tutor and egg moves do not count — being *taught* a slicing move is the move path's business, not the body's. Under this rule 326 learnset entries qualify (325 real species, plus the MissingNo glitch entry present in the source learnset data).
- **fly — Flying-type, or Levitate.** A species that flies or levitates by nature can carry the player. Ability data is the honest weak spot: a full-roster ability table is not among the project's data files, so Levitate is read from the party entry's own recorded ability when present, else from `pokemon/registry/master_species_registry.json`, which holds 25 curated species (Gastly among them — its Levitate path is test-proven). The Flying-type half of the rule has full coverage.
- **surf — Water-type.** A Water-type species can carry the player across water by nature.
- **teleport — Psychic-type.** Teleport is the signature escape of Psychic-types (the Abra line); a Psychic-type follower can warp the party out the same way.
- **dig — Ground-type.** A Ground-type species burrows by nature and can dig the party out of a cave.
- **strength, rock_smash, waterfall — move-only.** No natural rule is defined, plainly: raw pushing/breaking strength is not derivable from data we hold without inventing an arbitrary weight or size threshold, and waterfall climbing is a trained technique, not something a typing implies (a Water-type can swim — that is surf — but climbing a waterfall is the move). A Pokemon must know Strength, Rock Smash or Waterfall to perform those actions.

## The slicing move set — exact derivation

Gen 9 defines slicing moves through the Sharpness ability. Our own move data carries that definition: in `data/move_database_954.json`, a move record's `flags` dictionary contains `"slicing": 1` for exactly the Sharpness-boosted moves. The slicing set used by the cut rule is **exactly** those flagged records — no hand-built list, nothing added or removed. The flag set contains **26 moves**:

`aerialace` (Aerial Ace), `aircutter` (Air Cutter), `airslash` (Air Slash), `aquacutter` (Aqua Cutter), `behemothblade` (Behemoth Blade), `bitterblade` (Bitter Blade), `ceaselessedge` (Ceaseless Edge), `crosspoison` (Cross Poison), `cut` (Cut), `furycutter` (Fury Cutter), `kowtowcleave` (Kowtow Cleave), `leafblade` (Leaf Blade), `mightycleave` (Mighty Cleave), `nightslash` (Night Slash), `populationbomb` (Population Bomb), `psyblade` (Psyblade), `psychocut` (Psycho Cut), `razorleaf` (Razor Leaf), `razorshell` (Razor Shell), `sacredsword` (Sacred Sword), `secretsword` (Secret Sword), `slash` (Slash), `solarblade` (Solar Blade), `stoneaxe` (Stone Axe), `tachyoncutter` (Tachyon Cutter), `xscissor` (X-Scissor).

**Riley's examples, checked honestly:** Scyther and Scizor both qualify under the derived rule — and not by a technicality. Each has five slicing moves in its level-up learnset alone: Air Slash, Fury Cutter, Night Slash, Slash and X-Scissor. The blade-bodied species Riley named are exactly the species the data-driven rule selects. (Both also learn Cut itself in their full learnsets, as TM-class entries — but the natural rule does not need that; the level-up blades are enough.)

## Controller hook (documented, not wired in this item)

`systems/overworld/player_controller.gd` was not edited for this item, per the brief. When the player interacts with a field obstacle, the controller (or the obstacle's handler) should call `PUWFieldActions.perform(state, party, action_id)` and proceed with the traversal change only when the result's `allowed` is true; on refusal, `reason` says why — `badge_missing` (name the badge from `required_badge(action_id)`) or `no_qualifying_pokemon` (bring a capable partner).
