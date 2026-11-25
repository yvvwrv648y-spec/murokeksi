#!/usr/bin/env python3
"""PUW Phase 3 (Animation Completion) — in-house engine rigging builder.

Generates, from real project data only:
  data/species_shapes.json   -- PokeAPI body-shape per dex id (see below)
  data/rig_definitions.json  -- per-species engine-rig definitions
  data/rig_escalations.json  -- pack copy of the escalation list
  <goal>/rigging_escalations.json -- canonical escalation list for the
                                final phase's Neon prompt

Shape data provenance: PokeAPI/pokeapi CSV dumps (the same source family
the project already uses for data/species_habitats.json):
  data/v2/csv/pokemon_shapes.csv  (id -> identifier)
  data/v2/csv/pokemon_species.csv (id -> shape_id, column 7)
fetched 2026-11-23. SHAPE_NAMES and SHAPE_BY_DEX are LOADED from those
CSVs at runtime (see _load_shape_data below) -- never hand-transcribe
them: a hand transcription is what put 38 wrong shapes into the tree
(Gen 4 block, dex 451-492, plus dex 66 and 289; fixed 2026-11-25, see
RIG_SHAPE_FIX.md). The SPOT asserts below validate the loaded column.

No species-specific data is invented anywhere in this builder: every
rig parameter derives from the class template plus the species' real
shape / domains / types / abilities / height / weight.
"""
import csv, json, math, os, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.dirname(HERE)
GOAL_FILES = os.path.dirname(PACK)  # files/pokemon-full
TEST_DATA = os.path.expanduser("~/workspace/puw_ref/POKEMON_ULTIMATE_WORLD/data")

def _pokeapi_csv_dir():
    """Locate the held PokeAPI CSV dumps (the data/v2/csv folder)."""
    candidates = []
    env = os.environ.get("POKEAPI_CSV_DIR")
    if env:
        candidates.append(env)
    candidates.append(os.path.join(PACK, "data", "v2", "csv"))
    candidates.append(os.path.expanduser(
        "~/workspace/goals/pok-mon-ultimate-world-sprint-006-emberfox-walk"
        "/hidden_files/data_registry/src/pokeapi/data/v2/csv"))
    for cand in candidates:
        if os.path.isfile(os.path.join(cand, "pokemon_species.csv")) and \
           os.path.isfile(os.path.join(cand, "pokemon_shapes.csv")):
            return cand
    raise FileNotFoundError(
        "PokeAPI CSV dumps not found; set POKEAPI_CSV_DIR to the folder "
        "holding pokemon_species.csv and pokemon_shapes.csv")

def _load_shape_data():
    """Load (SHAPE_NAMES, SHAPE_BY_DEX) from the PokeAPI CSVs.

    SHAPE_BY_DEX[dex-1] is pokemon_species.csv's shape_id column for
    that dex; SHAPE_NAMES is pokemon_shapes.csv's id -> identifier.
    Loaded, never hand-transcribed: the previous transcription held
    38 wrong values (see RIG_SHAPE_FIX.md, 2026-11-25)."""
    csv_dir = _pokeapi_csv_dir()
    names = {}
    with open(os.path.join(csv_dir, "pokemon_shapes.csv"),
              newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            names[int(row["id"])] = row["identifier"]
    by_id = {}
    with open(os.path.join(csv_dir, "pokemon_species.csv"),
              newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            by_id[int(row["id"])] = int(row["shape_id"])
    assert sorted(by_id) == list(range(1, 1026)), "species CSV dex coverage"
    return names, [by_id[dex] for dex in range(1, 1026)]

SHAPE_NAMES, SHAPE_BY_DEX = _load_shape_data()
assert len(SHAPE_BY_DEX) == 1025, len(SHAPE_BY_DEX)
# Spot checks against the fetched CSV rows.
SPOT = {1:8, 6:6, 23:2, 25:8, 95:2, 130:2, 144:9, 376:11, 384:2, 387:8,
        493:8, 497:2, 649:12, 718:2, 778:2, 990:8, 994:13, 1008:8,
        1017:12, 1024:8, 1025:1, 84:7, 85:7, 122:12, 150:6, 186:12, 190:6, 200:1, 330:9, 882:7, 883:3, 885:2, 890:9, 892:12, 535:3, 544:1}
for dex, want in SPOT.items():
    assert SHAPE_BY_DEX[dex-1] == want, (dex, SHAPE_BY_DEX[dex-1], want)

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def showdown(slug):
    return slug.replace("-", "")

def main():
    stats = load(os.path.join(GOAL_FILES, "data", "pokeapi_stats_1025.json"))["species"]
    by_dex = {int(s["id"]): s for s in stats}
    domains = load(os.path.join(PACK, "systems", "followers", "follower_domains.json"))["species"]
    dom_by_showdown = {}
    for key, val in domains.items():
        dom_by_showdown[showdown(key)] = val
    # follower_domains.json keys 8 base species by their DEFAULT FORM id
    # only (deoxysnormal, giratinaaltered, wormadamplant, frillishmale,
    # jellicentmale, pyroarmale, shayminland, squawkabillygreenplumage).
    # Mechanical rule: when the base id has no row and exactly one
    # domains key starts with it, that row is the species' own record;
    # the key used is recorded in derived_from.domains_key.
    dom_key_used = {}
    _all_dom_keys = sorted(dom_by_showdown.keys())
    for _sid in [r["showdown_id"] for r in load(os.path.join(GOAL_FILES, "data", "shiny_sprites_index.json"))["rows"]]:
        if _sid not in dom_by_showdown:
            _prefixed = [k for k in _all_dom_keys if k.startswith(_sid)]
            if len(_prefixed) == 1:
                dom_by_showdown[_sid] = dom_by_showdown[_prefixed[0]]
                dom_key_used[_sid] = _prefixed[0]
    shiny = load(os.path.join(GOAL_FILES, "data", "shiny_sprites_index.json"))
    rows = {r["showdown_id"]: r for r in shiny["rows"]}
    plan = load(os.path.join(GOAL_FILES, "sourcing_plan.json"))
    fol_candidates = sorted({e["showdown_id"] for e in plan["entries"]
                             if e["route"] == 3 and e["context"] == "follower_overworld"})
    # Pecharunt was sourced by route 2 (SpriteCollab) after the plan JSON
    # was written; FOLLOWER_SPRITES.md is the standing truth.
    fol_candidates = [s for s in fol_candidates if s != "pecharunt"]
    assert len(fol_candidates) == 552, len(fol_candidates)

    shapes_out = {"metadata": {
        "source": "PokeAPI/pokeapi CSV dumps: data/v2/csv/pokemon_shapes.csv + pokemon_species.csv (shape_id column)",
        "source_urls": ["https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_shapes.csv",
                        "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_species.csv"],
        "fetched": "2026-11-23",
        "note": "Same source family as data/species_habitats.json. Covers dex 1-1025 (base species only; PokeAPI assigns no shape to forms)."},
        "shapes": {str(k): v for k, v in SHAPE_NAMES.items()}, "species": {}}
    for dex in range(1, 1026):
        name = by_dex[dex]["name"]
        shapes_out["species"][showdown(name)] = {"dex": dex, "name": name,
                                                 "shape_id": SHAPE_BY_DEX[dex-1],
                                                 "shape": SHAPE_NAMES[SHAPE_BY_DEX[dex-1]]}

    def still_urls(row, patterns):
        out = {}
        for e in row.get("sprites", []):
            if e.get("source") == "pokeapi" and e.get("pattern") in patterns \
               and e.get("verified_http_200") is not False:
                out[e["pattern"]] = e["url"]
        return out

    def derive(sid):
        """Return (locomotion_class, derived_from dict, escalation_reason)."""
        row = rows[sid]
        dex = int(row.get("pokeapi_id") or 0)
        st = by_dex.get(dex, {})
        shape = SHAPE_NAMES.get(SHAPE_BY_DEX[dex-1]) if 1 <= dex <= 1025 else None
        dom = dom_by_showdown.get(sid, {})
        dlist = dom.get("domains", [])
        types = [t.capitalize() for t in st.get("types", [])] or dom.get("types", [])
        abilities = [a.lower() for a in st.get("abilities", [])]
        height_m = float(st.get("height", 0)) / 10.0
        weight_kg = float(st.get("weight", 0)) / 10.0
        learns_fly = bool(dom.get("learns_fly", False))
        derived = {"shape": shape, "domains": dlist, "types": types,
                   "domains_key": dom_key_used.get(sid, sid),
                   "learns_fly": learns_fly, "abilities": abilities,
                   "height_m": height_m, "weight_kg": weight_kg}
        if shape is None or not dlist:
            return None, derived, "insufficient_body_data: no PokeAPI shape or no follower-domain record, so no locomotion class can be derived honestly"
        water = ("water_surface" in dlist) or ("deep_dive" in dlist)
        if water and "land" not in dlist:
            return ("serpentine" if shape == "squiggle" else "aquatic_finned"), derived, ""
        if shape == "squiggle":
            # A serpent body undulates, on land and in the air alike
            # (Gyarados, Rayquaza): wing tracks never apply to it.
            return "serpentine", derived, ""
        # Wing evidence is the Flying type or a winged body shape.
        # learns_fly ALONE is not wing evidence: it is a teachable
        # field move (Pikachu's event Fly, Mew's all-HM learnset)
        # on bodies whose stills show no wings.
        winged_evidence = ("Flying" in types) or shape in ("wings", "bug-wings")
        airborne = ("air" in dlist) or ("Flying" in types) or ("levitate" in abilities) or (learns_fly and winged_evidence)
        if airborne and winged_evidence:
            if shape == "legs":
                return None, derived, "flightless_body_plan_no_usable_wings: Flying type with a legs body shape (flightless-bird plan); the front still shows no wings a flap track could honestly move"
            return "avian_winged", derived, ""
        if airborne:
            return "hover_levitator", derived, ""
        if shape == "squiggle":
            return "serpentine", derived, ""
        if shape == "ball":
            return "wheeled_rolling", derived, ""
        if weight_kg > 0.0 and weight_kg < 3.5:
            return "small_body", derived, ""
        if shape == "quadruped":
            return "quadruped", derived, ""
        if shape in ("upright", "humanoid", "arms", "legs", "heads", "wings", "bug-wings"):
            # Wing-shaped bodies that are not airborne (Scizor) walk
            # on their legs; the biped template carries them.
            return "upright_biped", derived, ""
        return "sessile", derived, ""

    TEMPLATES = build_templates()
    definitions = {}
    battle_definitions = {}
    escalations = []
    counts = collections.Counter()
    esc_counts = collections.Counter()

    for sid in fol_candidates:
        cls, derived, reason = derive(sid)
        row = rows[sid]
        stills = still_urls(row, ["front"])
        if not stills:
            cls, reason = None, "no_verified_still: candidate has no PokeAPI front still in the index to rig from"
        if cls is None:
            escalations.append({"showdown_id": sid, "context": "follower",
                                "scope": "species", "reason": reason,
                                "derived_from": derived})
            esc_counts[reason.split(":")[0]] += 1
            continue
        definitions[sid] = make_definition(sid, "follower", cls, derived,
                                           stills["front"], TEMPLATES[cls])
        counts[cls] += 1

    battle_species = ["irontreads", "ironbundle", "ironjugulis", "ironleaves",
                      "ogerpon", "ironboulder", "ironcrown", "pecharunt",
                      "ironhands", "ironmoth", "ironthorns", "ironvaliant",
                      "miraidon", "terapagos"]
    for sid in battle_species:
        cls, derived, reason = derive(sid)
        row = rows[sid]
        stills = still_urls(row, ["front", "back", "shiny-front", "shiny-back"])
        if cls is None or not stills:
            escalations.append({"showdown_id": sid, "context": "battle",
                                "scope": "species",
                                "reason": reason or "no_verified_still: no PokeAPI still in the index to rig from",
                                "derived_from": derived})
            esc_counts["battle_no_rig"] += 1
            continue
        battle_definitions[sid] = make_definition(sid, "battle", cls, derived,
                                                  stills.get("front", ""), TEMPLATES[cls],
                                                  views=stills)
        counts["battle_" + cls] += 1

    # 38 form partial-slot rows: forms carry no PokeAPI stills at all, so
    # there is nothing to rig; their existing front stays source-animated
    # and the missing slots escalate (task rule, do not invent views).
    form_partials = sorted({e["showdown_id"] for e in plan["entries"]
                            if e["route"] == 3 and e["context"] == "battle"
                            and e["family"] == "PKDX-form"})
    for sid in form_partials:
        entry = next(e for e in plan["entries"] if e["route"] == 3
                     and e["context"] == "battle" and e["showdown_id"] == sid)
        escalations.append({"showdown_id": sid, "context": "battle",
                            "scope": "slot",
                            "reason": "form_has_no_still_art_to_rig: form rows carry no PokeAPI stills; the verified front stays source-animated and the missing views cannot be derived from front art",
                            "missing_animated_slots": entry.get("missing_animated_slots", []),
                            "derived_from": {}})
        esc_counts["form_has_no_still_art_to_rig"] += 1

    rig_data = {"metadata": {
        "system": "PUW in-house engine rigging (route 3 of sourcing_plan.md)",
        "provenance": "engine-rigged",
        "generated_by": "tools/build_rigging.py",
        "generated": "2026-11-23",
        "note": "Every definition derives from its class template plus the species' real shape/domains/types/abilities/height/weight. Source art is the indexed PokeAPI still, copied verbatim; no URL is constructed."},
        "templates": TEMPLATES, "follower": definitions, "battle": battle_definitions}
    esc_data = {"metadata": {
        "system": "PUW engine-rigging escalations (route 3 failures -> Neon)",
        "generated": "2026-11-23",
        "rule": "Every rigging candidate is either in rig_definitions.json or in this list; no silent drops."},
        "escalations": escalations,
        "counts": {"follower_rigged": len(definitions),
                   "battle_rigged": len(battle_definitions),
                   "escalated_total": len(escalations)}}

    with open(os.path.join(PACK, "data", "species_shapes.json"), "w", encoding="utf-8") as f:
        json.dump(shapes_out, f, indent=1)
    with open(os.path.join(PACK, "data", "rig_definitions.json"), "w", encoding="utf-8") as f:
        json.dump(rig_data, f, indent=1)
    with open(os.path.join(PACK, "data", "rig_escalations.json"), "w", encoding="utf-8") as f:
        json.dump(esc_data, f, indent=1)
    with open(os.path.join(GOAL_FILES, "rigging_escalations.json"), "w", encoding="utf-8") as f:
        json.dump(esc_data, f, indent=1)
    print("follower rigged:", len(definitions), dict(counts))
    print("battle rigged:", len(battle_definitions))
    print("escalations:", len(escalations), dict(esc_counts))
    by_class = collections.Counter(d["locomotion_class"] for d in definitions.values())
    print("follower by class:", dict(by_class))

def part(region, anchor):
    return {"region": region, "anchor": anchor}

def tr(kind, freq, amp, phase=0.0, **kw):
    d = {"kind": kind, "freq_hz": freq, "amp": amp, "phase_deg": phase}
    d.update(kw)
    return d

def build_templates():
    """Class templates. Frequencies/amplitudes are PUW design parameters
    (labeled as such in RIGGING.md), scaled per species in
    make_definition by real height/weight."""
    T = {}
    T["quadruped"] = {
        "parts": {"body": part([0.15,0.15,0.70,0.62],[0.5,0.5]),
                  "head": part([0.28,0.0,0.44,0.36],[0.5,0.95]),
                  "tail": part([0.76,0.22,0.24,0.42],[0.05,0.4]),
                  "limb_front": part([0.18,0.66,0.26,0.34],[0.5,0.05]),
                  "limb_back": part([0.56,0.66,0.26,0.34],[0.5,0.05])},
        "idle": {"body": tr("breath",0.9,0.02), "head": tr("bob_y",0.9,0.008,40.0),
                 "tail": tr("rot_sway",1.3,10.0), "limb_front": tr("none",0,0), "limb_back": tr("none",0,0)},
        "movement": {"body": tr("bob_y",2.0,0.02), "head": tr("bob_y",2.0,0.012,30.0),
                     "tail": tr("rot_sway",2.6,14.0), "limb_front": tr("stride",2.0,0.05),
                     "limb_back": tr("stride",2.0,0.05,180.0)}}
    T["upright_biped"] = {
        "parts": {"body": part([0.2,0.2,0.6,0.55],[0.5,0.5]),
                  "head": part([0.3,0.0,0.4,0.34],[0.5,0.95]),
                  "tail": part([0.7,0.45,0.3,0.4],[0.05,0.3]),
                  "arm_left": part([0.02,0.28,0.22,0.46],[0.85,0.08]),
                  "arm_right": part([0.76,0.28,0.22,0.46],[0.15,0.08]),
                  "limb_front": part([0.26,0.7,0.2,0.3],[0.5,0.05]),
                  "limb_back": part([0.54,0.7,0.2,0.3],[0.5,0.05])},
        "idle": {"body": tr("breath",0.85,0.02), "head": tr("bob_y",0.85,0.008,40.0),
                 "tail": tr("rot_sway",1.2,8.0), "arm_left": tr("rot_sway",0.85,3.0,20.0),
                 "arm_right": tr("rot_sway",0.85,3.0,200.0), "limb_front": tr("none",0,0), "limb_back": tr("none",0,0)},
        "movement": {"body": tr("bob_y",2.1,0.018), "head": tr("bob_y",2.1,0.01,30.0),
                     "tail": tr("rot_sway",2.4,10.0), "arm_left": tr("rot_sway",2.1,12.0),
                     "arm_right": tr("rot_sway",2.1,12.0,180.0), "limb_front": tr("stride",2.1,0.045),
                     "limb_back": tr("stride",2.1,0.045,180.0)}}
    T["avian_winged"] = {
        "parts": {"body": part([0.25,0.25,0.5,0.55],[0.5,0.5]),
                  "head": part([0.32,0.0,0.36,0.32],[0.5,0.95]),
                  "wing_left": part([0.0,0.04,0.4,0.58],[0.95,0.25]),
                  "wing_right": part([0.6,0.04,0.4,0.58],[0.05,0.25]),
                  "tail": part([0.34,0.72,0.32,0.28],[0.5,0.1])},
        "idle": {"body": tr("breath",1.0,0.018), "head": tr("bob_y",1.0,0.008,40.0),
                 "wing_left": tr("flap",1.0,6.0), "wing_right": tr("flap",1.0,6.0),
                 "tail": tr("rot_sway",1.4,7.0)},
        "movement": {"body": tr("bob_y",2.6,0.03), "head": tr("bob_y",2.6,0.01,30.0),
                     "wing_left": tr("flap",2.6,38.0), "wing_right": tr("flap",2.6,38.0),
                     "tail": tr("rot_sway",2.6,9.0)}}
    T["hover_levitator"] = {
        "parts": {"body": part([0.12,0.12,0.76,0.76],[0.5,0.5]),
                  "head": part([0.3,0.0,0.4,0.36],[0.5,0.95])},
        "idle": {"body": tr("bob_y",0.8,0.025), "head": tr("bob_y",0.8,0.012,25.0)},
        "movement": {"body": tr("bob_y",1.5,0.04), "head": tr("bob_y",1.5,0.015,25.0)}}
    T["aquatic_finned"] = {
        "parts": {"seg_0": part([0.0,0.0,1.0,0.25],[0.5,0.5]),
                  "seg_1": part([0.0,0.25,1.0,0.25],[0.5,0.5]),
                  "seg_2": part([0.0,0.5,1.0,0.25],[0.5,0.5]),
                  "seg_3": part([0.0,0.75,1.0,0.25],[0.5,0.5]),
                  "fin_tail": part([0.3,0.7,0.4,0.3],[0.5,0.1])},
        "idle": {"seg_0": tr("undulate_x",0.9,0.008,0.0), "seg_1": tr("undulate_x",0.9,0.012,45.0),
                 "seg_2": tr("undulate_x",0.9,0.012,90.0), "seg_3": tr("undulate_x",0.9,0.008,135.0),
                 "fin_tail": tr("rot_sway",0.9,6.0)},
        "movement": {"seg_0": tr("undulate_x",1.9,0.02,0.0), "seg_1": tr("undulate_x",1.9,0.032,50.0),
                     "seg_2": tr("undulate_x",1.9,0.032,100.0), "seg_3": tr("undulate_x",1.9,0.02,150.0),
                     "fin_tail": tr("rot_sway",1.9,13.0)}}
    T["serpentine"] = {
        "parts": {"seg_0": part([0.0,0.0,1.0,0.2],[0.5,0.5]),
                  "seg_1": part([0.0,0.2,1.0,0.2],[0.5,0.5]),
                  "seg_2": part([0.0,0.4,1.0,0.2],[0.5,0.5]),
                  "seg_3": part([0.0,0.6,1.0,0.2],[0.5,0.5]),
                  "seg_4": part([0.0,0.8,1.0,0.2],[0.5,0.5])},
        "idle": {"seg_0": tr("undulate_x",0.7,0.006,0.0), "seg_1": tr("undulate_x",0.7,0.01,40.0),
                 "seg_2": tr("undulate_x",0.7,0.01,80.0), "seg_3": tr("undulate_x",0.7,0.008,120.0),
                 "seg_4": tr("undulate_x",0.7,0.006,160.0)},
        "movement": {"seg_0": tr("undulate_x",1.6,0.016,0.0), "seg_1": tr("undulate_x",1.6,0.028,45.0),
                     "seg_2": tr("undulate_x",1.6,0.028,90.0), "seg_3": tr("undulate_x",1.6,0.022,135.0),
                     "seg_4": tr("undulate_x",1.6,0.016,180.0)}}
    T["wheeled_rolling"] = {
        "parts": {"body": part([0.05,0.05,0.9,0.9],[0.5,0.5])},
        "idle": {"body": tr("rot_sway",0.9,4.0)},
        "movement": {"body": tr("roll",1.4,140.0)}}
    T["small_body"] = {
        "parts": {"body": part([0.15,0.2,0.7,0.65],[0.5,0.5]),
                  "head": part([0.3,0.0,0.4,0.36],[0.5,0.95])},
        "idle": {"body": tr("breath",1.4,0.025), "head": tr("bob_y",1.4,0.012,40.0)},
        "movement": {"body": tr("hop_y",2.8,0.05), "head": tr("bob_y",2.8,0.012,30.0)}}
    T["sessile"] = {
        "parts": {"body": part([0.15,0.25,0.7,0.65],[0.5,0.5]),
                  "head": part([0.28,0.0,0.44,0.4],[0.5,0.95])},
        "idle": {"body": tr("breath",0.8,0.022), "head": tr("rot_sway",0.8,4.0)},
        "movement": {"body": tr("hop_y",1.7,0.035), "head": tr("rot_sway",1.7,5.0,30.0)}}
    return T

def make_definition(sid, context, cls, derived, still_url, template, views=None):
    # Per-species parameter scaling from REAL size data (documented design
    # rule): stride/flap frequency falls as height grows; bob amplitude
    # grows slightly with weight class. No species-named values.
    h = max(float(derived.get("height_m", 1.0)), 0.1)
    freq_scale = min(1.35, max(0.7, 1.15 - 0.12 * math.log(max(h, 0.1))))
    tracks = {}
    for tname in ("idle", "movement"):
        tracks[tname] = {}
        for pname, t in template[tname].items():
            nt = dict(t)
            nt["freq_hz"] = round(float(t["freq_hz"]) * freq_scale, 3)
            tracks[tname][pname] = nt
    d = {"showdown_id": sid, "context": context, "provenance": "engine-rigged",
         "locomotion_class": cls, "body_shape": derived.get("shape"),
         "derived_from": derived, "source_art_url": still_url,
         "source_art_kind": "pokeapi_still_png_indexed",
         "parts": template["parts"], "tracks": tracks}
    if views is not None:
        d["views"] = views
        d["tracks"] = {"idle": tracks["idle"]}  # battle presentation: idle rig
    return d

if __name__ == "__main__":
    main()
