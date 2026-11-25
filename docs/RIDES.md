# Rideable Pokemon — PUW Phase 3, Item B

System: `systems/overworld/ride_system.gd` (`PUWRideSystem`). Ride modes are the
11 modes registered in `systems/cast/rider_poses.json`:
`land_riding`, `surfing`, `ferrying`, `mounted_flight`, `carried_flight`,
`diving`, `climbing_cliff`, `climbing_waterfall`, `hover_carrying`,
`held_carrying`, `burrowing`.

## Eligibility — derived from real data only

Eligibility is computed from species data this project actually holds:
types (`data/competitive_sets.json`, 1,025 species; the 25-species master
registry in `pokemon/registry/master_species_registry.json` takes precedence),
weight (`data/weight_power.json`, stored in hectograms, converted to kg),
abilities (master registry, plus the ability recorded on competitive sets),
learnsets (`data/learnsets_compact.json`), PokeAPI habitat
(`data/species_habitats.json`), and follower locomotion
(`systems/followers/follower_locomotion.json`). MDX (Moemon) counterparts share
their PKDX counterpart's slug in `data/mdx_mapping.json`, so Moemon are
rideable on exactly the same rules as their counterparts.

### Rules and thresholds

All thresholds below are **PUW design parameters** — round numbers chosen for
this project. They are design decisions, not sourced facts.

| Mode | Rule |
| --- | --- |
| land_riding | Weight at or above **50 kg**, and not an aquatic-only species (PokeAPI habitat `sea` or `waters-edge` excludes; no recorded habitat = not excluded). |
| surfing | Water-type and weight at or above **20 kg** (a surf mount must float a rider; this keeps Magikarp, 10 kg, out of every mode). |
| ferrying | Water-type and weight at or above **100 kg** — the large, placid subset. Lapras (220 kg) qualifies for both surfing and ferrying. |
| diving | Water-type that also qualifies for surfing. |
| mounted_flight | Flying-type or Levitate, weight at or above **25 kg** (big enough to sit on). |
| carried_flight | Flying-type or Levitate, weight **below 25 kg**. The 25 kg line is a hard split: no species is claimed by both flight modes. Pidgey (1.8 kg) is carried_flight only. |
| hover_carrying | Levitate ability, OR a hover/float locomotion entry in `follower_locomotion.json`, OR the explicit canon table below. |
| held_carrying | Weight at or above **50 kg** and not aquatic-only. Machamp (130 kg) qualifies. |
| climbing_cliff | Learnset contains `rockclimb` or `rocksmash`, OR Ground/Rock-type with weight at or above **20 kg**. |
| climbing_waterfall | Water-type that also qualifies for surfing (climbs the fall while swimming). |
| burrowing | Ground-type, or learnset contains `dig`. |

### Canon table (hover_carrying)

One species is eligible by name rather than by a data rule, with its basis
recorded in `PUWRideSystem.CANON_HOVER`:

- **Metagross — hover_carrying.** Basis: "Riley canon example, 2026-11-22"
  (Riley's named example of a hover-carrier: Tasha standing arms-folded on a
  hovering Metagross). `PUWRideSystem.basis_for("metagross", "hover_carrying")`
  returns this citation.

### Honest coverage note

Ability data is thin: the master registry holds abilities for only 25 curated
species and most competitive-set records carry no ability. Levitate-based
eligibility (hover_carrying, and the Levitate branch of the flight modes)
therefore only resolves for species whose ability is actually recorded (for
example Gastly, Levitate, in the registry). No ability is invented to widen
coverage. The follower locomotion registry likewise holds only 4 seed entries,
none of them hover/float, so that branch currently contributes no species.

## Speeds (PUW design)

Tiles per second, tied to the existing movement spec (walk 4.0, run 8.0,
acro bike 10.67, mach bike 16.0):

land_riding 8.0 · surfing 6.0 · ferrying 5.0 · mounted_flight 12.0 ·
carried_flight 10.0 · diving 6.0 · climbing_cliff 3.0 ·
climbing_waterfall 4.0 · hover_carrying 8.0 · held_carrying 4.0 ·
burrowing 5.0.

## Mount, dismount, followers

`mount(state, party, species, mode)` validates eligibility and party
membership, records `state["current_mount"] = {"species", "mode"}`, and
removes the species from the save-state follower line `state["followers"]`
(an Array of species slugs, the species identity the follower controller
records) when it was following. `dismount(state)` clears the mount and
returns the species to the follower line when there is room (max 6, the
follower controller's `MAX_FOLLOWERS`).

Mounting also returns the rider pose binding: the mode's primary pose from
`PUWCastRegistry`, resolved through the player's cast pose set, plus the art
status from `PUWCastRigLoader.build_rider_frames`. Rider art is still pending
from Neon, so bindings honestly report `art_pending` with 0 frames — no frame
is ever faked. Example: Tasha mounting Metagross returns pose `hover_stand`,
set `tasha`, status `art_pending`.

## Badge-locked crossings

Riding itself is **not** a field action — plain land riding on open ground
needs no badge. Only crossings are gated, and every gated crossing goes
through the field-action gate, `PUWFieldActions.can_perform`, with the field
action's refusal reason passed through unchanged (for example
`badge_missing`).

Crossing → field-action map (PUW design):

| Crossing (ride mode) | Field action | Unlocking badge |
| --- | --- | --- |
| Water crossing (surfing / ferrying / diving) | `surf` | Soul Badge |
| Airborne crossing over a gap or obstacle (mounted_flight / carried_flight / hover_carrying) | `fly` | Thunder Badge |
| Waterfall climb (climbing_waterfall) | `waterfall` | Earth Badge |
| Cliff climb (climbing_cliff) | `rock_smash` | Volcano Badge |
| Burrow escape (burrowing) | `dig` | Volcano Badge |
| Carried past an obstacle (held_carrying) | `strength` | Rainbow Badge |
| Plain land riding on open ground (land_riding) | — none — | — |

## Controller behaviour

While mounted, `PUWPlayerController.step()` moves at the ride mode's speed.
On synthetic test maps (real Kanto geometry has no named water/gap terrain
of this kind), water tiles are crossable only while mounted in a water mode
and gap tiles only while mounted in an airborne mode; on foot both are
refused. The badge gate for a crossing is `PUWRideSystem.attempt_crossing`;
the controller enforces only the physical terrain rule.
