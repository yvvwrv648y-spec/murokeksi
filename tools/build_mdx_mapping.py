#!/usr/bin/env python3
"""Build data/mdx_mapping.json from the Moemon 1,519-slot mapping CSV.

Source CSV (read-only input, NOT shipped):
    ~/workspace/puw_ref/moemon_src/mapping/MOEMON_GEN1_9_1519_SLOT_MAPPING.csv
    columns: rom_slot, decoded_name, slug, generation_bucket,
             front_png, back_png, front_shiny_png, back_shiny_png,
             dimensions_px, format_class, candidate_status

Output per slot:
    {slot, species_slug, decoded_name, generation,
     dimensions_px, format_class, candidate_status}

Deliberate exclusions / notes:
- The CSV carries NO species_id column, so no species_id is emitted.
  rom_slot is a ROM slot number, not a national dex id (slots repeat
  species: e.g. "pikachu" appears in 17 slots, base + forms), so it is
  never copied into a species_id field.
- The four *_png columns are paths to locally extracted sprite files.
  Per the project provenance rule they are NEVER copied into the game
  data: MDX sprites resolve only through the public URL sprite index
  (battle/shiny_sprite_resolver.gd + data/shiny_sprites_index.json).
- Rows that fail to parse are counted and listed on stdout, never
  silently dropped.

Usage:
    python3 tools/build_mdx_mapping.py [--csv PATH] [--output PATH]
Defaults resolve the CSV relative to this repo's parent workspace
(../../moemon_src/...) and write res://data/mdx_mapping.json.
"""
import argparse
import csv
import json
import sys
from pathlib import Path

REQUIRED_COLUMNS = ["rom_slot", "decoded_name", "slug", "generation_bucket"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_csv = (
        Path(__file__).resolve().parents[2]
        / "moemon_src"
        / "mapping"
        / "MOEMON_GEN1_9_1519_SLOT_MAPPING.csv"
    )
    default_out = Path(__file__).resolve().parents[1] / "data" / "mdx_mapping.json"
    parser.add_argument("--csv", type=Path, default=default_csv)
    parser.add_argument("--output", type=Path, default=default_out)
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"ERROR: CSV not found: {args.csv}", file=sys.stderr)
        return 1

    entries = []
    failed = []  # list of (line_number, reason, raw_row)
    with args.csv.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        missing = [c for c in REQUIRED_COLUMNS if c not in (reader.fieldnames or [])]
        if missing:
            print(f"ERROR: CSV is missing required columns: {missing}", file=sys.stderr)
            return 1
        for line_no, row in enumerate(reader, start=2):  # line 1 is the header
            if None in row:  # extra fields -> malformed row
                failed.append((line_no, "row has extra fields", row.get(None)))
                continue
            slot_raw = (row.get("rom_slot") or "").strip()
            slug = (row.get("slug") or "").strip()
            name = (row.get("decoded_name") or "").strip()
            generation = (row.get("generation_bucket") or "").strip()
            if not slot_raw.isdigit():
                failed.append((line_no, f"rom_slot is not an integer: {slot_raw!r}", dict(row)))
                continue
            if not slug or not name or not generation:
                failed.append((line_no, "empty slug/decoded_name/generation_bucket", dict(row)))
                continue
            entries.append(
                {
                    "slot": int(slot_raw),
                    "species_slug": slug,
                    "decoded_name": name,
                    "generation": generation,
                    "dimensions_px": (row.get("dimensions_px") or "").strip(),
                    "format_class": (row.get("format_class") or "").strip(),
                    "candidate_status": (row.get("candidate_status") or "").strip(),
                }
            )

    payload = {
        "family": "MDX",
        "source_csv": "MOEMON_GEN1_9_1519_SLOT_MAPPING.csv",
        "slot_count": len(entries),
        "failed_rows": len(failed),
        "notes": [
            "The source CSV carries no species_id column; rom_slot is a ROM slot, not a national dex id, and is not emitted as species_id.",
            "The source CSV's *_png columns (paths to locally extracted sprite files) are deliberately excluded: MDX sprites resolve only through the public URL sprite index.",
            "Duplicate slugs are distinct slots (base species plus forms/megas/variants); the first slot for a slug is its base slot.",
        ],
        "entries": entries,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"rows ok: {len(entries)}")
    print(f"rows failed: {len(failed)}")
    for line_no, reason, _raw in failed:
        print(f"  FAILED line {line_no}: {reason}")
    print(f"wrote: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
