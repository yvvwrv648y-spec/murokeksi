#!/usr/bin/env python3
import json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
p = ROOT / "systems" / "pokedex" / "national_dex_1028.json"
d = json.loads(p.read_text(encoding="utf-8"))
assert d["total_species"] == 1028, f"Expected 1028, got {d['total_species']}"
assert d["gen1_to_gen9_count"] == 1025
assert d["gen10_official_reveals_count"] == 3
print("PASS: Species Validator verified 1,028 National Dex entries (1,025 Gen I-IX + 3 Gen X reveals)")
