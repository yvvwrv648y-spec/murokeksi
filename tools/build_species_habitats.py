#!/usr/bin/env python3
"""Build data/species_habitats.json from the PokeAPI CSV dumps.

Sources (public, PokeAPI/pokeapi repo, data/v2/csv/ -- the same
source family data/evolution_triggers.json was built from):
  - https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_species.csv
      (one row per species; column habitat_id, empty for some species)
  - https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_habitats.csv
      (habitat id -> identifier: cave, forest, grassland, mountain,
       rare, rough-terrain, sea, urban, waters-edge)
  - https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_habitat_names.csv
      (habitat id -> English display name, local_language_id 9)

NOTE on the file names: there is no "habitats.csv" in the PokeAPI
repo (that URL 404s). The real habitat tables are
pokemon_habitats.csv / pokemon_habitat_names.csv, used here.

Output: data/species_habitats.json
  {"metadata": {...source urls, fetch date, coverage...},
   "habitats": {habitat_id: identifier},
   "species": {"<national dex id>": {"slug": ..., "habitat": <name or null>}}}

Honest coverage: species whose pokemon_species.csv row has an empty
habitat_id get habitat=null. Nothing is filled in or guessed.
"""
import csv
import io
import json
import sys
import urllib.request
from datetime import date
from pathlib import Path

BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
URLS = {
    "pokemon_species": BASE + "pokemon_species.csv",
    "pokemon_habitats": BASE + "pokemon_habitats.csv",
    "pokemon_habitat_names": BASE + "pokemon_habitat_names.csv",
}
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "species_habitats.json"


def fetch(url: str) -> list:
    with urllib.request.urlopen(url) as resp:
        text = resp.read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def main() -> int:
    try:
        species_rows = fetch(URLS["pokemon_species"])
        habitat_rows = fetch(URLS["pokemon_habitats"])
    except Exception as exc:  # network blocked etc: fail loudly, invent nothing
        print(f"BLOCKER: could not fetch PokeAPI CSVs: {exc}", file=sys.stderr)
        return 1
    habitats = {int(r["id"]): r["identifier"] for r in habitat_rows}
    species = {}
    covered = 0
    for row in species_rows:
        sid = int(row["id"])
        hab_id = row.get("habitat_id") or ""
        habitat = habitats.get(int(hab_id)) if hab_id.strip() else None
        if habitat is not None:
            covered += 1
        species[str(sid)] = {"slug": row["identifier"], "habitat": habitat}
    payload = {
        "metadata": {
            "file": "species_habitats.json",
            "source": "PokeAPI CSV dumps (PokeAPI/pokeapi repo, data/v2/csv/)",
            "source_urls": list(URLS.values()),
            "fetch_date": date.today().isoformat(),
            "species_total": len(species),
            "species_with_habitat": covered,
            "species_without_habitat": len(species) - covered,
            "notes": (
                "habitat is the PokeAPI habitat identifier for the species, "
                "or null when pokemon_species.csv leaves habitat_id empty. "
                "No habitat is invented for uncovered species; in-game those "
                "species join encounter pools by type fit only (see "
                "systems/overworld/habitat_encounters.gd)."
            ),
        },
        "habitats": {str(k): v for k, v in sorted(habitats.items())},
        "species": species,
    }
    OUT.write_text(json.dumps(payload, indent=1) + "\n")
    print(f"wrote {OUT}: {len(species)} species, {covered} with a habitat, "
          f"{len(species) - covered} null")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
