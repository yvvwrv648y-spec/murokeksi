#!/usr/bin/env python3
"""Build systems/followers/follower_domains.json from LOCAL project data.

Style follows tools/build_species_habitats.py (header documents sources,
honest coverage, nothing invented) but reads the already-shipped local
files instead of fetching, so it is reproducible offline.

Sources (all in this repo):
  - data/competitive_sets.json  species + types (1,025)
  - pokemon/registry/master_species_registry.json  types/abilities precedence
  - data/weight_power.json, data/species_habitats.json (PokeAPI habitat)
  - data/learnsets_compact.json  learnsets (Fly / Dive / Surf)
  - systems/followers/follower_locomotion.json  locomotion seed

Derivation (also in FOLLOWER_SENSES.md):
  land:          non-Water species; Water species only when amphibious:
                 habitat is a land habitat or "waters-edge", OR habitat is
                 unrecorded AND the species has a non-Water/non-Flying
                 secondary type or a ground_* locomotion entry.
                 Habitat "sea" is NEVER amphibious. Unrecorded-habitat
                 pure-Water species default STRICT (no land).
  water_surface: Water type, or the learnset contains "surf".
  deep_dive:     learnset contains "dive" AND water_surface (strict subset).
  air:           Flying type, or species ability Levitate, or locomotion
                 flying_avian / a hover locomotion entry.
"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
def load(p):
    try: return json.loads((ROOT/p).read_text())
    except Exception: return {}
sets = load("data/competitive_sets.json").get("species", {})
reg = load("pokemon/registry/master_species_registry.json").get("species", [])
weights = load("data/weight_power.json")
hab_raw = load("data/species_habitats.json").get("species", {})
hab = {v.get("slug"): v.get("habitat") for v in hab_raw.values() if isinstance(v, dict)}
learn = load("data/learnsets_compact.json").get("learnsets", {})
loco_raw = load("systems/followers/follower_locomotion.json").get("pallet_and_route1_seed", [])
loco = {e["slug"]: e.get("locomotion","") for e in loco_raw if isinstance(e, dict)}
types_by, abil_by = {}, {}
for slug, e in sets.items():
    if isinstance(e, dict) and e.get("types"): types_by[slug] = [str(t).capitalize() for t in e["types"]]
    ab=[]
    for fmt in ("singles","vgc"):
        r=e.get(fmt) if isinstance(e,dict) else None
        if isinstance(r,dict) and r.get("ability") and r["ability"]!="None": ab.append(r["ability"])
    if ab: abil_by[slug]=ab
for e in reg:
    if not isinstance(e,dict): continue
    slug=e.get("species_id","")
    if not slug: continue
    if e.get("types"): types_by[slug]=[str(t).capitalize() for t in e["types"]]
    if e.get("abilities"): abil_by[slug]=[str(a) for a in e["abilities"]]
LAND_HABITATS={"forest","grassland","mountain","cave","urban","rough-terrain","waters-edge"}
out={}
for slug in sorted(types_by):
    types=types_by[slug]; habitat=hab.get(slug); moves=set(learn.get(slug,{}).get("learnset",{}).keys())
    domains=[]
    is_water="Water" in types
    amphibious=False
    if is_water:
        if habitat in LAND_HABITATS: amphibious=True
        elif habitat is None:
            secondary=[t for t in types if t not in ("Water","Flying")]
            if secondary or str(loco.get(slug,"")).startswith("ground"): amphibious=True
    if not is_water or amphibious: domains.append("land")
    if is_water or "surf" in moves: domains.append("water_surface")
    if "dive" in moves and "water_surface" in domains: domains.append("deep_dive")
    if "Flying" in types or any(a.lower()=="levitate" for a in abil_by.get(slug,[])) or loco.get(slug) in ("flying_avian","hover","hover_follow"): domains.append("air")
    if not domains: domains=["land"]  # non-Water handled above; safety net, unreachable in practice
    out[slug]={"types":types,"habitat":habitat,"domains":domains,"learns_fly":"fly" in moves,"learns_dive":"dive" in moves,"learns_surf":"surf" in moves}
doc={"metadata":{"file":"follower_domains.json","builder":"tools/build_follower_domains.py","sources":["data/competitive_sets.json","pokemon/registry/master_species_registry.json","data/weight_power.json","data/species_habitats.json","data/learnsets_compact.json","systems/followers/follower_locomotion.json"],"species_count":len(out),"derivation":"land: non-Water, or amphibious Water (land/waters-edge habitat, or unrecorded habitat + land secondary type or ground locomotion); sea habitat never amphibious; unrecorded pure-Water defaults strict. water_surface: Water type or learns Surf. deep_dive: learns Dive and water_surface (strict subset). air: Flying type, Levitate, or flying/hover locomotion."},"species":out}
dest=ROOT/"systems/followers/follower_domains.json"
dest.write_text(json.dumps(doc,indent=1,sort_keys=True)+"\n")
print("wrote",dest,"species",len(out))
# sanity
bad=[s for s,v in out.items() if "deep_dive" in v["domains"] and "water_surface" not in v["domains"]]
print("deep_not_surface",bad)
for s in ["rattata","pidgey","tentacool","horsea","magikarp","goldeen","squirtle","gyarados","lapras"]:
    print(s,out.get(s))
