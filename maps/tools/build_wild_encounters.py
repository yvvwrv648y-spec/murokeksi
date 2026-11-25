#!/usr/bin/env python3
"""Build data/wild_encounters.json for the PUW world-kanto pack.

Parses the wild encounter tables of two open-source disassemblies
as TEXT (their build toolchains are never run):

  Kanto - pret/pokered
    * constants/map_constants.asm      ordered map constants
    * data/wild/grass_water.asm        WildDataPointers (map -> label)
    * data/wild/maps/*.asm             def_grass_wildmons / def_water_wildmons
    * data/wild/probabilities.asm      the 10-slot chance table
    Rate semantics: engine/battle/wild_encounters.asm,
    TryDoWildEncounter - a random byte (0-255) is compared with the
    rate byte; an encounter starts when random < rate, so the
    per-step chance is rate / 256.

  Sevii - pret/pokefirered
    * src/data/wild_encounters.json    per-map encounter tables
    * include/constants/species.h      national dex numbers
    Rate semantics: src/wild_encounter.c, DoWildEncounterRateTest -
    the rate is multiplied by 16 and a random value % 1600
    (MAX_ENCOUNTER_RATE, src/wild_encounter.c line 20) must fall
    below it, so the base per-step chance is rate * 16 / 1600
    (= rate / 100). The ability / flute / Cleanse Tag modifiers in
    that function are not modelled here.

Map keys are the world pack's own map id_const values (pack maps
were inventoried from maps/data/maps/*.json), so the game can look
a map up by the same const its scene carries. Species are recorded
exactly as the sources name them (pokered constants for Kanto -
the same convention as data/trainers.json - and SPECIES_ constants
plus national dex numbers for Sevii).

Version differences are kept, never merged away: pokered tables
with IF DEF(_RED) / IF DEF(_BLUE) sections produce slots_red /
slots_blue; pokefirered tables whose FireRed and LeafGreen entries
differ produce firered / leafgreen variants.
"""

import json
import re
import sys
from pathlib import Path

POKERED = Path.home() / "workspace/puw_world/src/pokered"
POKEFIRERED = Path.home() / "workspace/puw_world/src/pokefirered"
PACK = Path(__file__).resolve().parents[2]
OUT = PACK / "data" / "wild_encounters.json"


def fail(msg: str) -> None:
    print("ERROR:", msg)
    sys.exit(1)


# ------------------------------------------------------------------
# Pack map inventory (id_const -> name, region)
# ------------------------------------------------------------------
def pack_maps() -> dict:
    out = {}
    for path in sorted((PACK / "maps" / "data" / "maps").glob("*.json")):
        d = json.loads(path.read_text())
        out[d["id_const"]] = {"name": d["name"], "region": d["region"]}
    return out


# ------------------------------------------------------------------
# Kanto (pokered)
# ------------------------------------------------------------------
def parse_pokered_labels() -> dict:
    """label -> {file, grass: block, water: block}.

    A block is {"rate": int, "slots": [...]} or, when the table has
    IF DEF(_RED)/IF DEF(_BLUE) sections, {"rate": int,
    "slots_red": [...], "slots_blue": [...]}. Slots keep source
    order, which is the engine's slot order.
    """
    labels = {}
    for path in sorted((POKERED / "data/wild/maps").glob("*.asm")):
        text = path.read_text()
        current_label = None
        current_kind = None  # "grass" | "water"
        variant = "shared"   # "shared" | "red" | "blue"
        for raw in text.splitlines():
            line = raw.strip()
            m = re.match(r"^(\w+):$", line)
            if m and not line.startswith(";"):
                current_label = m.group(1)
                labels.setdefault(current_label, {"file": "data/wild/maps/" + path.name})
                current_kind = None
                variant = "shared"
                continue
            if current_label is None:
                continue
            m = re.match(r"^def_(grass|water)_wildmons\s+(\d+)", line)
            if m:
                current_kind = m.group(1)
                labels[current_label][current_kind] = {"rate": int(m.group(2))}
                variant = "shared"
                continue
            if re.match(r"^end_(grass|water)_wildmons", line):
                current_kind = None
                variant = "shared"
                continue
            if current_kind is None:
                continue
            if line.startswith("IF DEF(_RED)"):
                variant = "red"
                continue
            if line.startswith("IF DEF(_BLUE)"):
                variant = "blue"
                continue
            if line.startswith("ENDC"):
                variant = "shared"
                continue
            m = re.match(r"^db\s+(\d+),\s*([A-Z_0-9]+)\s*$", line)
            if m:
                block = labels[current_label][current_kind]
                slot = {"level": int(m.group(1)), "species": m.group(2)}
                if variant == "shared":
                    if "slots_red" in block:
                        # Shared slot after a version section: it
                        # belongs to both versions.
                        block["slots_red"].append(slot)
                        block["slots_blue"].append(slot)
                    else:
                        block.setdefault("slots", []).append(slot)
                else:
                    if "slots" in block:
                        # Shared slots came first: they belong to
                        # both versions too.
                        shared = block.pop("slots")
                        block["slots_red"] = list(shared)
                        block["slots_blue"] = list(shared)
                    block.setdefault("slots_" + variant, []).append(slot)
    return labels


def build_kanto(pack: dict) -> tuple:
    consts_text = (POKERED / "constants/map_constants.asm").read_text()
    consts = re.findall(r"^\s*map_const\s+([A-Z0-9_]+)", consts_text, re.M)

    gw = (POKERED / "data/wild/grass_water.asm").read_text()
    table = gw.split("WildDataPointers:")[1]
    pointers = []
    for line in table.splitlines():
        m = re.match(r"\s*dw\s+(\w+)\s*(?:;\s*(.*))?", line)
        if m:
            pointers.append(m.group(1))
        elif pointers and line.strip() and not line.startswith("\t"):
            break
    if len(pointers) != len(consts):
        fail(f"pointer table has {len(pointers)} entries, map_constants has {len(consts)}")

    labels = parse_pokered_labels()
    maps = {}
    with_data = 0
    with_rate = 0
    for const, label in zip(consts, pointers):
        if const not in pack or pack[const]["region"] != "kanto":
            continue
        if label == "NothingWildMons":
            continue
        if label not in labels:
            fail(f"label {label} for {const} not defined in data/wild/maps/")
        src = labels[label]
        entry = {
            "name": pack[const]["name"],
            "region": "kanto",
            "source_game": "pokered",
            "semantics": "pokered_gen1",
            "source_file": src["file"],
            "source_label": label,
        }
        has_rate = False
        for kind in ("grass", "water"):
            if kind in src:
                entry[kind] = src[kind]
                if src[kind]["rate"] > 0:
                    has_rate = True
        maps[const] = entry
        with_data += 1
        if has_rate:
            with_rate += 1
    return maps, with_data, with_rate


# ------------------------------------------------------------------
# Sevii (pokefirered)
# ------------------------------------------------------------------
def build_sevii(pack: dict) -> tuple:
    species_h = (POKEFIRERED / "include/constants/species.h").read_text()
    species_ids = {}
    for m in re.finditer(r"^#define\s+(SPECIES_\w+)\s+(\d+)\s*$", species_h, re.M):
        species_ids[m.group(1)] = int(m.group(2))

    raw = json.loads((POKEFIRERED / "src/data/wild_encounters.json").read_text())
    group = raw["wild_encounter_groups"][0]
    fields = {f["type"]: f["encounter_rates"] for f in group["fields"]}

    by_map = {}
    for entry in group["encounters"]:
        version = None
        if entry["base_label"].endswith("_FireRed"):
            version = "firered"
        elif entry["base_label"].endswith("_LeafGreen"):
            version = "leafgreen"
        else:
            fail("encounter entry without version suffix: " + entry["base_label"])
        by_map.setdefault(entry["map"], {})[version] = entry

    def terrain_block(block: dict) -> dict:
        slots = []
        for mon in block["mons"]:
            const = "SPECIES_" + mon["species"].removeprefix("SPECIES_")
            slot = {
                "min_level": mon["min_level"],
                "max_level": mon["max_level"],
                "species": const,
            }
            if const in species_ids:
                slot["species_id"] = species_ids[const]
            slots.append(slot)
        return {"rate": block["encounter_rate"], "slots": slots}

    maps = {}
    with_rate = 0
    for const, info in sorted(pack.items()):
        if info["region"] != "sevii" or const not in by_map:
            continue
        versions = by_map[const]
        per_version = {}
        for version, entry in versions.items():
            built = {}
            for src_key, out_key in (
                ("land_mons", "land"),
                ("water_mons", "water"),
                ("rock_smash_mons", "rock_smash"),
                ("fishing_mons", "fishing"),
            ):
                if src_key in entry:
                    built[out_key] = terrain_block(entry[src_key])
            per_version[version] = built
        entry = {
            "name": info["name"],
            "region": "sevii",
            "source_game": "pokefirered",
            "semantics": "pokefirered_gen3",
            "source_file": "src/data/wild_encounters.json",
        }
        distinct = set(json.dumps(v, sort_keys=True) for v in per_version.values())
        if len(distinct) == 1:
            entry.update(next(iter(per_version.values())))
        else:
            for version, built in per_version.items():
                entry[version] = built
        maps[const] = entry
        flat = [entry] + [entry[v] for v in ("firered", "leafgreen") if v in entry]
        if any(
            isinstance(b, dict) and b.get("rate", 0) > 0
            for e in flat
            for b in e.values()
        ):
            with_rate += 1
    return maps, fields, len(maps), with_rate


def main() -> None:
    pack = pack_maps()
    kanto_maps, kanto_with_data, kanto_with_rate = build_kanto(pack)
    sevii_maps, fr_fields, sevii_with_data, sevii_with_rate = build_sevii(pack)

    kanto_total = sum(1 for v in pack.values() if v["region"] == "kanto")
    sevii_total = sum(1 for v in pack.values() if v["region"] == "sevii")

    out = {
        "pack": "world-kanto",
        "data": "wild_encounters",
        "generated": "2026-11-22",
        "generated_by": "maps/tools/build_wild_encounters.py (parses the "
                        "disassembly data files as text; no repo build "
                        "toolchain or script was run)",
        "sources": {
            "kanto": {
                "repo": "pret/pokered",
                "map_order": "constants/map_constants.asm",
                "pointer_table": "data/wild/grass_water.asm (WildDataPointers)",
                "per_map_files": "data/wild/maps/*.asm (cited per map as source_file)",
                "slot_chances": "data/wild/probabilities.asm "
                                "(WildMonEncounterSlotChances)",
                "rate_semantics": "engine/battle/wild_encounters.asm, "
                                  "TryDoWildEncounter: the rate byte is "
                                  "compared against a random byte 0-255; an "
                                  "encounter starts when random < rate, so "
                                  "the per-step chance is rate / 256.",
            },
            "sevii": {
                "repo": "pret/pokefirered",
                "data_file": "src/data/wild_encounters.json (cited per map "
                             "as source_file)",
                "species_ids": "include/constants/species.h",
                "slot_chances": "the fields encounter_rates arrays in "
                                "src/data/wild_encounters.json",
                "rate_semantics": "src/wild_encounter.c, "
                                  "DoWildEncounterRateTest: the rate is "
                                  "multiplied by 16 and a random value "
                                  "% 1600 (MAX_ENCOUNTER_RATE) must fall "
                                  "below it, so the base per-step chance "
                                  "is rate * 16 / 1600 = rate / 100. The "
                                  "ability, flute and Cleanse Tag "
                                  "modifiers in that function are not "
                                  "modelled.",
            },
        },
        "slot_chances": {
            "pokered_gen1": {
                "denominator": 256,
                "grass": [51, 51, 39, 25, 25, 25, 13, 13, 11, 3],
                "water": [51, 51, 39, 25, 25, 25, 13, 13, 11, 3],
                "note": "Per-slot weights of the single shared table in "
                        "data/wild/probabilities.asm; the engine compares "
                        "a random byte against the cumulative weights.",
            },
            "pokefirered_gen3": {
                "denominator": 100,
                "land": fr_fields["land_mons"],
                "water": fr_fields["water_mons"],
                "rock_smash": fr_fields["rock_smash_mons"],
                "fishing": fr_fields["fishing_mons"],
                "note": "Per-slot percentage weights from the fields "
                        "definitions in src/data/wild_encounters.json.",
            },
        },
        "counts": {
            "kanto_pack_maps": kanto_total,
            "kanto_maps_with_wild_table": kanto_with_data,
            "kanto_maps_with_nonzero_rate": kanto_with_rate,
            "sevii_pack_maps": sevii_total,
            "sevii_maps_with_wild_table": sevii_with_data,
            "sevii_maps_with_nonzero_rate": sevii_with_rate,
        },
        "notes": [
            "Maps with no entry have no wild encounter table in the "
            "source (pokered points them at NothingWildMons; the "
            "pokefirered data has no encounter entry for them). Their "
            "per-step chance in game code stays 0.0 - nothing was "
            "invented for them.",
            "Kanto entries carry grass and water blocks exactly as "
            "sourced, including rate 0 blocks with no slots.",
            "Sevii entries carry land, water, rock_smash and fishing "
            "blocks as sourced; only land and water are step "
            "encounters.",
            "Where the two game versions differ, both versions are "
            "kept: slots_red / slots_blue (pokered) and firered / "
            "leafgreen sub-tables (pokefirered).",
        ],
        "maps": {},
    }
    out["maps"].update(kanto_maps)
    out["maps"].update(sevii_maps)

    OUT.write_text(json.dumps(out, indent=1) + "\n")
    print("wrote", OUT)
    print(json.dumps(out["counts"], indent=1))
    print("total map entries:", len(out["maps"]))


if __name__ == "__main__":
    main()
