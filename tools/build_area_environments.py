#!/usr/bin/env python3
"""Build data/area_environments.json from data/wild_encounters.json.

Canon (Riley, 2026-11-22): wild_encounters.json stops being a species
list. It becomes the ENVIRONMENT RECORD for each area: which kinds of
place the area is. The species pool is then generated globally from
habitat + type fit (systems/overworld/habitat_encounters.gd).

Derivation rules (applied in order; every map entry gets a record,
and a map only gets tags its own data supports):

1. METHOD tags, from the map's own encounter blocks (the map's FULL
   merged record is used: top-level blocks plus both version
   sub-tables -- see repair R1 below):
   - a grass/land block with rate > 0          -> "grassland"
   - a water block with rate > 0               -> "water"
   - a fishing block with rate > 0             -> "water"
   - a rock_smash block with rate > 0          -> "rough-terrain"
   A block with rate 0 or no slots gives NO tag (honest: Route 1's
   rate-0 water block does not make Route 1 a water environment).

2. NAME tags, added only when the map already has at least one
   method tag (a map with no live encounter block at all gets no
   tags, whatever its name says -- e.g. Pokemon Tower 1F, rate 0):
   - name contains FOREST, BUSH or WOOD         -> "forest"
   - name contains CAVE, TUNNEL                 -> "cave"
   - name contains MT_, MOUNT, EMBER, SUMMIT,
     CANYON, VALLEY                             -> "mountain" + "rough-terrain"
   - name contains ICEFALL, SEAFOAM             -> "cold"
   - name contains POWER_PLANT, MANSION, TOWER  -> "urban"
   - name/id contains BEACH, CAPE, PORT, ISLAND
     or DOCK and the map has a water method tag -> "coastal"

Environment tag vocabulary: grassland, forest, water, coastal, cave,
mountain, rough-terrain, urban, cold.

REPAIRS (Kanto encounter fixes prep, 2026-11-24 -- the derivation had
gone stale against the record it derives from):

R1. Method tags are derived from the map's FULL merged record: the
    top-level blocks AND both version sub-tables (firered/leafgreen).
    The original builder read only the FireRed sub-table for
    pokefirered entries, and the shipped area_environments.json was
    generated before the pokefirered water/fishing/rock_smash layer
    fills were merged into the Kanto entries -- so maps whose water
    exists only in the merged record (Routes 4/6/10-13/22-25, Seafoam
    B3F/B4F, Safari Zone, Cerulean Cave) never got their water tag,
    and Cerulean Cave never got rough-terrain from its rock_smash
    blocks. Unioning every root fixes the whole class; tags only
    ever grow.
R2. VICTORY_ROAD maps gain cave + mountain + rough-terrain: Victory
    Road is a cave through the mountain range, and none of the
    original name triggers fired on it (audit fix list item 3).
R3. Coastal triggers are checked against the map id_const as well as
    the display name (the display name drops separators and words:
    VermilionDock carries no DOCK in name form), and DOCK is a
    trigger. Settlement maps (id ends _CITY or _TOWN, plus
    CINNABAR_ISLAND) with a water tag gain coastal, and _CITY maps
    gain urban (audit fix list item 1: the towns' tags are water +
    coastal, + urban for the cities).
R4. Shoreline rule: a ROUTE_ map with a live water block AND a live
    fishing block gains coastal (pond/river/sea routes are
    shorelines; audit fix list item 3: pond/river routes + water,
    coastal). Interior maps are untouched by this rule.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "wild_encounters.json"
OUT = ROOT / "data" / "area_environments.json"

BLOCK_METHODS = ("grass", "land", "water", "fishing", "rock_smash")
METHOD_TAGS = {
    "grass": "grassland",
    "land": "grassland",
    "water": "water",
    "fishing": "water",
    "rock_smash": "rough-terrain",
}


def blocks_of(entry: dict) -> dict:
    """Encounter blocks for one entry, unioned over the entry itself
    and both version sub-tables (repair R1: the merged record is the
    source of truth, not any single layer of it). A block key present
    in several roots keeps the first live (rate > 0) form found."""
    roots = [entry]
    for version in ("firered", "leafgreen"):
        sub = entry.get(version)
        if isinstance(sub, dict):
            roots.append(sub)
    blocks = {}
    for root in roots:
        for k in BLOCK_METHODS:
            block = root.get(k)
            if not isinstance(block, dict):
                continue
            if k not in blocks or (
                int(block.get("rate", 0)) > 0
                and int(blocks[k].get("rate", 0)) <= 0
            ):
                blocks[k] = block
    return blocks


def derive(entry: dict, map_id: str = "") -> list:
    tags = []
    blocks = blocks_of(entry)
    live = set()
    for method, block in blocks.items():
        if int(block.get("rate", 0)) > 0:
            live.add(method)
            if METHOD_TAGS[method] not in tags:
                tags.append(METHOD_TAGS[method])
    if not tags:
        return tags
    name = str(entry.get("name", "")).upper()
    # The map id_const is checked too: it carries separators the
    # display name drops (MT_MOON_1F vs MtMoon1F, POWER_PLANT in
    # neither -- the display name is PowerPlant, hence both forms).
    def add(tag):
        if tag not in tags:
            tags.append(tag)
    if any(w in name for w in ("FOREST", "BUSH", "WOOD")):
        add("forest")
    if any(w in name for w in ("CAVE", "TUNNEL")):
        add("cave")
    if any(w in name for w in ("MT_", "MOUNT", "EMBER", "SUMMIT",
                    "CANYON", "VALLEY")):
        add("mountain"); add("rough-terrain")
    if any(w in name for w in ("ICEFALL", "SEAFOAM")):
        add("cold")
    if any(w in name or w in map_id for w in ("POWER_PLANT", "POWERPLANT", "MANSION", "TOWER")):
        add("urban")
    if "MT_" in map_id or name.startswith("MT"):
        add("mountain"); add("rough-terrain")
    # Repair R2: Victory Road is a cave through the mountains.
    if "VICTORY_ROAD" in map_id:
        add("cave"); add("mountain"); add("rough-terrain")
    # Repair R3: cities are urban; settlements on water are coastal.
    if map_id.endswith("_CITY"):
        add("urban")
    if "water" in tags and (
        any(w in name or w in map_id
            for w in ("BEACH", "CAPE", "PORT", "ISLAND", "DOCK"))
        or map_id.endswith(("_CITY", "_TOWN"))
        or map_id == "CINNABAR_ISLAND"
    ):
        add("coastal")
    # Repair R4: routes with live water and live fishing are
    # shorelines (ponds, rivers, sea routes).
    if map_id.startswith("ROUTE_") and "water" in live and "fishing" in live:
        add("coastal")
    return tags


def main() -> int:
    data = json.loads(SRC.read_text())
    maps = data["maps"]
    areas = {}
    untagged = []
    for map_id, entry in maps.items():
        tags = derive(entry, map_id)
        areas[map_id] = {"name": entry.get("name", ""), "environments": tags}
        if not tags:
            untagged.append(map_id)
    payload = {
        "metadata": {
            "file": "area_environments.json",
            "source": "Derived from data/wild_encounters.json (the environment record) by tools/build_area_environments.py",
            "generated": "2026-11-24",
            "area_count": len(areas),
            "areas_with_tags": len(areas) - len(untagged),
            "areas_without_tags": untagged,
            "rules": (
                "Method tags come from the map's own rate>0 encounter blocks "
                "across its full merged record (top-level blocks plus both "
                "version sub-tables; grass/land->grassland, water/fishing->water, "
                "rock_smash->rough-terrain). Name tags (forest, cave, "
                "mountain, cold, urban, coastal) are added only to maps that "
                "already have a method tag; Victory Road gains cave/mountain/"
                "rough-terrain, cities gain urban, and settlements and "
                "water+fishing routes on water gain coastal. A map with no "
                "live block gets no tags and therefore no habitat pool. "
                "Derivation repaired 2026-11-24 (Kanto encounter fixes): "
                "the previous derivation predated the pokefirered layer "
                "fills in wild_encounters.json and read only one sub-table, "
                "so merged water/rock_smash blocks never fed it."
            ),
        },
        "areas": areas,
    }
    OUT.write_text(json.dumps(payload, indent=1) + "\n")
    print(f"wrote {OUT}: {len(areas)} areas, {len(areas) - len(untagged)} tagged, "
          f"untagged={untagged}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
