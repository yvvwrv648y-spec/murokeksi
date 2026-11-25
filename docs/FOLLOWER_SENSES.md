# FOLLOWER SENSES, EMOTES, DELIVERY, AND TERRAIN DOMAINS (PUW, Refinement 5, 2026-11-23)

Implements Riley's 2026-11-23 07:21 CST follower refinements. His points were
examples with creative latitude; everything below is generalized into data-driven
systems and proven by `tests/follower_behavior_tests.gd` (tests 15-19).

## (a) Emote discipline

Head emotes are RARE: only a genuine interaction or event produces one, never
ambient behavior. Presentation model in `PUWFollowerController`:

- `EMOTE_TTL_SECONDS = 1.5` (PUW design parameter): an emote fades after 1.5 s.
- `EMOTE_MAX_CONCURRENT = 2` (PUW design parameter): at most 2 emotes visible at once;
  further events are dropped, not queued.
- `show_emote(index, glyph, source)` is the only entry point and only accepts event
  sources: `interaction`, `care`, `found_item`, `delivery`, `detection`, `encounter`.
  Idle, wander, scout, perch and formation states never call it. (The pre-existing
  "!" on Pickup/Honey Gather finds moved to delivery completion; Sweet Scent / Roar
  triggers use source `encounter`.)

Proof (test 15): a seeded 120 s idle+wander run with 6 followers produces zero
emotes; one interaction emote shows as exactly 1 active emote and expires after the
TTL; a burst of 6 forced events is capped at 2.

## (b) Detection and pointing — sense classes

Sense classes are derived per follower in `senses_for(slug, active_ability)`:

| Sense | Derivation (all from shipped project data) |
|---|---|
| sight | Individual's ACTIVE ability is Keen Eye, Compound Eyes, or Frisk; OR species is Flying type; OR species learnset (`data/learnsets_compact.json`) contains foresight or mindreader (species biology) |
| smell | Species learnset contains odorsleuth (e.g. Growlithe, Meowth) |
| hearing | Species learnset contains uproar or hypervoice; OR individual's ACTIVE ability is Soundproof |
| resonance_electric | Species is Electric type |
| resonance_psychic | Species is Psychic type |
| resonance_ground | Species is Ground type |

Ability-derived senses read the individual's ACTIVE ability only — the same rule as
overworld triggers (species possible-ability lists never qualify). Learnset-derived
senses use the learnset as species *biology* data (what the species' body can do),
not as a move trigger; the follower does not need the move slotted.

Point-of-interest kinds and the senses that can detect them (`POI_SENSES`):
hidden_item → sight/smell; buried → smell/resonance_ground; machinery →
resonance_electric/sight; presence → resonance_psychic/hearing; sound_source →
hearing/sight.

Behavior: points are registered with `set_points_of_interest()` as
`{"id", "kind", "pos"}`. Range is `SENSE_RANGE_TILES = 6.0` tiles (PUW design
parameter). EXACTLY ONE follower responds per point — the nearest eligible one —
and one follower answers at most one point, so two spaced points can draw two
responders, one each. The responder enters state `point`, moves to a cardinal
neighbour tile BESIDE the point (occupiable for its domains), never stands on the
point tile, and faces it (`facing_dir` on its record).

Data note: map JSONs (`maps/data/maps/*.json`) carry warps, bg_events and objects
but no hidden-item point list, so no map is claimed to supply points yet; tests seed
points on synthetic maps and label them seeded. Live code can register real points
through the same API when a map data source exists.

Proof (test 16, seeded point labeled in the test): Growlithe (smell) is the single
responder out of 6 followers, ends beside — not on — the point tile, facing it;
Caterpie (no plausible sense for a hidden item) never responds in 600 ticks.

## (c) Pickup delivery and notice timing

A find (Pickup, or Honey Gather as the equivalent carried-item effect) no longer
lands in the bag at find time. The follower takes state `deliver` carrying
`pending_item`, returns to the trainer, and only on arrival — and only in free
travel — does the item enter the bag via `MartShop.add_item` (canonical-id keyed)
and the notice fire (`follower_item_found`, plus the new `follower_item_delivered`).

Busy state: `set_world_busy(busy, reason)` on the controller. Live code sets it from
its battle/cutscene/story flags (e.g. `PartyScene.in_battle`); while busy, a
delivering follower waits at the trainer's side silently — no bag change, no
notice, no interruption — and completes when free travel resumes.

Proof (test 17): a seeded Pickup find under a scripted busy state stays pending
through 300 further busy ticks with an empty bag and zero notices; clearing the
state completes delivery with bag +1 (checked via `MartShop.count_item`) and
exactly one notice. Test 4 (Pickup end to end) still passes under the new flow
because the follower starts at the trainer's side.

## (d) Terrain domains

Generated table: `systems/followers/follower_domains.json`, built by
`tools/build_follower_domains.py` from local data only (competitive_sets types,
master registry, weight_power, species_habitats, learnsets_compact,
follower_locomotion). Coverage: 1,028 species (every species with type data).

Derivation:

- `land`: non-Water species; Water species only when amphibious — PokeAPI habitat
  is a land habitat or `waters-edge`, OR habitat is unrecorded AND the species has
  a non-Water/non-Flying secondary type or a `ground_*` locomotion entry. Habitat
  `sea` is never amphibious. An unrecorded-habitat pure-Water species defaults to
  the STRICTER domain (no land).
- `water_surface`: Water type, or the learnset contains surf.
- `deep_dive`: learnset contains dive AND water_surface — a strict subset of water
  species (surface swimmers like Magikarp, no Dive in its learnset, can never dive).
- `air`: Flying type, Levitate in the species ability data, or a flying/hover
  locomotion entry. Non-flyers never get air.

Enforcement: follower movement, slot verification and separation all check
`_can_occupy_domains()`: `water` tiles need water_surface or air; `deep_water`
tiles (the labeled synthetic dive-zone terrain) need deep_dive or air; `ground`
tiles need land or air — so a water-only species (e.g. Tentacool, sea habitat)
can never come onto land, a land-only follower stops at water's edge, and a
surface-only swimmer never enters a dive zone.

Proofs (tests 18-19): the table covers every species in
`data/competitive_sets.json` with zero deep_dive-without-water_surface violations;
on labeled synthetic maps Rattata never enters water in 300 frames, Magikarp never
enters the deep_water zone in 300 frames, Rattata never crosses a gap line that
Pidgey crosses over.
