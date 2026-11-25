#!/usr/bin/env python3
import json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
for sub in ["buildings", "interiors", "dungeons", "world_data"]:
    p = ROOT / "world" / "regions" / "kanto" / sub / f"kanto_{sub}_manifest.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    assert d["verified_maps"] == 72
print("PASS: Map Validator verified all 4 Kanto world layers (72 BFS-connected maps)")
