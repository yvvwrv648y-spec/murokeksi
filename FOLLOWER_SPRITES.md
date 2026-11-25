# Follower sprites — what is bound (2026-11-23, route-2 integration)

The follower system is bound to the best legitimate sprite source per
species, resolved from the project's own index data by
`PUWFollowerSpriteResolver` (`systems/followers/follower_sprite_resolver.gd`)
and wired into `PUWFollowerController`: every follower record carries
`sprite_url`, `sprite_classification`, `sprite_source` and
`sprite_animated`, and the classification is queryable at runtime via
`follower_sprite_classification(index)` / `follower_sprite_info(index)`.
The binding travels with the behavior-layer output records. Follower
behavior (formation, locomotion, terrain domains) is unchanged — this is
the visual binding only.

## How resolution works

For a species (and form, where applicable), in order:

1. **Animated** — a real animated overworld/follower sprite indexed
   for follower use. Since the route-2 integration this is the
   **PMD SpriteCollab** index at `res://data/follower_sprites_index.json`,
   which the resolver loads **by default** in its normal path
   (`load_indexes()`; `load_follower_index_from(path)` remains the
   plug-in point for additional indexes). Entries are marked for
   follower use (`context`/`usage` = `follower`), carry the `animated`
   flag, the verbatim sheet URLs, source id `pmd-spritecollab`, and
   each row carries the species' `AnimData.xml` URL for frame
   geometry at runtime. Animated results expose `source_id`,
   `anim_data_url`, `verified_anims` and `partial` alongside the URL.
2. **Static-only** — otherwise, the verified PokeAPI front still PNG,
   copied verbatim from the species' row in
   `data/shiny_sprites_index.json` (the same stills the battle sprite
   loader streams). Battle Showdown GIFs are never credited here: they
   are single-view battle art, not follower animation.
3. **Missing** — otherwise nothing. A missing follower renders no fake
   flat stand-in presented as the Pokemon; the gap is recorded in the
   classification itself.

No URL is ever constructed: the resolver copies URLs verbatim from
index sprite entries only (it does not even use the index's pattern
templates), and returns only URLs that exist in the index data.
Resolution is exact-match only — a form name resolves to its own form
row, never silently to the base species.

## Route 2 — PMD SpriteCollab (accepted source)

- **Source:** PMD SpriteCollab (GitHub `PMDCollab/SpriteCollab`,
  https://sprites.pmdcollab.org/) — community-authored Pokemon
  Mystery Dungeon-style sprite sheets (8-direction Walk/Idle and
  more), streamed by URL, never bulk-downloaded.
- **Licence:** **CC BY-NC 4.0**
  (https://creativecommons.org/licenses/by-nc/4.0/). PUW is
  non-commercial, so the NC condition is met.
- **Credit:** per-species artist names ship in
  **`CREDITS_spritecollab.md`** (pack root), taken from the
  SpriteCollab tracker (`tracker.json` sprite_credit, resolved via
  the repo's `credit_names.txt`).
- **Barred:** every species whose tracker credit is **CHUNSOFT**
  (492 base species — sprites ripped from the commercial PMD games)
  is absent from the index by construction and still classifies
  static-only. A rip is a rip wherever it is hosted.
- **Verification (2026-11-23):** every indexed species was
  HEAD-checked per species — `Walk-Anim.png`, `Idle-Anim.png` and
  `AnimData.xml` all returned HTTP 200 for all 473 indexed species
  (Walk/Idle and AnimData each confirmed in two passes). Species are
  indexed only with the anims that verified.
- **Indexed: 473 base species** — the 472 community-authored species
  of `sourcing_plan.json`'s accepted set, plus Pecharunt (1025),
  whose plan-JSON entry claimed no sheet exists while
  `sourcing_plan.md` sample-verified its Walk sheet and its tracker
  credit is a community author; live re-check confirmed all three
  files at HTTP 200 (see its `inclusion_note` in the index and in
  `route2_demotions.json`).
- **Demotions: 0.** No accepted species failed verification, and no
  species is partial (Walk verified but Idle missing: 0). The empty
  demotion/partial lists are recorded in
  `files/pokemon-full/route2_demotions.json`. The remaining 552
  static-only base species (492 CHUNSOFT-barred + 60 with no
  SpriteCollab sheet) fall to Phase 3 rigging, as planned.
- **Forms: unindexed (397 stay candidates).** The tracker form
  subgroups do not map cleanly to PUW's form slugs — subgroup names
  are generic category labels (Female, Altcolor, Alternate, Mega,
  Gigantamax, Galar, Mega_X, …) in a nested tree interleaved with
  Shiny/Altcolor subgroups, and do not encode a specific Showdown
  form slug unambiguously. The mapping was **not** forced; all 397
  forms stay route-2 candidates with fallback route 4 (Neon) per
  the sourcing plan, and still classify missing as followers.

## Classification counts (resolver output)

| Group | Animated | Static-only | Missing |
|---|---|---|---|
| PKDX base species (1,025) | 473 | 552 | 0 |
| PKDX forms (397) | 0 | 0 | 397 |
| MDX Moemon slots (1,519) | 0 | 0 | 1,519 |

Proven by `tests/follower_sprite_tests.gd` (9 passed, 0 failed),
including a fabrication-guard sweep over all 1,422 main-index rows
plus the 473 follower-index rows (every returned URL verbatim in
index data), the SpriteCollab sample (Arceus, Victini, Snivy,
Genesect, Sprigatito, Gholdengo, Pecharunt → animated), and barred
Gen 1–4 samples (→ static-only, absent from the follower index).

## Honest gaps

- **552 base species are still static-only as followers** — the
  CHUNSOFT-barred Gen 1–4 species and the species with no
  SpriteCollab sheet. They fall to Phase 3 in-house rigging.
- **Forms have no follower art at all** — the SpriteCollab form
  mapping was not clean (above), and form rows carry no PokeAPI
  still PNG, so all 397 classify missing.
- **MDX follower art is missing, by rule.** 0 original Moemon sprite
  files exist. In the follower path an MDX follower never borrows its
  PKDX counterpart's sprite (the resolver returns missing for family
  MDX before any lookup). Battle behaviour for MDX is unchanged by
  this work.

## Extraction integration build addendum (2026-11-23, Solid Rule)

The follower picture changed substantially after this document's
route-2/route-3 state:

- **485 CHUNSOFT-credited SpriteCollab species** were verified
  (Walk/Idle HTTP 200 + AnimData frame counts) and appended to
  `data/follower_sprites_index.json` (now **958 rows**), under
  source_id `pmd-spritecollab-chunsoft`, credit CHUNSOFT, with
  game-sprite provenance recorded per row. The former "barred"
  section above is superseded: the bar was lifted by Riley's
  Solid Rule; provenance bookkeeping remains.
- **7 species** whose SpriteCollab sheets lack an Idle anim
  (beedrill, dragonair, silcoon, cascoon, lileep, mothim +
  hitmonchan) are bound from the **HGSS overworld set (Veekun
  pack)** as local files, indexed in
  `data/hgss_overworld_index.json` and loaded by the resolver
  alongside the follower index. Real 2-frame cycles,
  pixel-difference verified.
- New totals (PKDX base): **965 animated / 60 engine-rigged /
  0 static-only / 0 missing.** Doduo and Dodrio are animated
  (PMD ground cycles); their flight treatment stays escalated.
- MDX followers: **645 of 1,519 slots** now have real Moemon walk
  atlases bound locally (MoeMMO Followers v1.11 by 111Ventus),
  served by the MDX data layer (`PUWMDXData` +
  `data/mdx_sprites_index.json`) — this resolver's MDX guard is
  unchanged and still never borrows counterpart art.

## Consolidation build additions (2026-11-23)

- Willow OW pack index (data/willow_follower_index.json): 76 form
  followers (Gmax / Mega / Primal / Z-A Mega) as local charsets in
  art/followers_willow/ — forms now 293 animated / 104 missing.
  Flagged unbound in the index: pidgeotmega (ambiguous sheet),
  Ogerpon Terastal Cornerstone (unnumbered masks), the Urshifu
  Gmax pair (audit-miss candidates), Snorlax Gmax (Non-Follower
  sheet only).
- PMD SpriteCollab: 21 rows appended (979 total) — richness
  upgrades for 20 base species + the gimmighoulroaming form from
  the wave-2 intake's new folders; 8 no-Walk folders not bound
  (species keep EBDX). Per-species decisions:
  hidden_files/consolidation_build/work/pmd_decisions.md.
