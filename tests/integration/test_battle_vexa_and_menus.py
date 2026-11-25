#!/usr/bin/env python3
import json, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
moves = json.loads((ROOT / "battle/moves/move_database.json").read_text())["moves"]
assert len(moves) >= 75, "Move DB too small"
assert "Special Burst" not in moves, "Fake move detected"
assert moves["Stealth Rock"]["hazard"] == "stealth_rock"
assert moves["Volt Switch"]["pivot"] is True
dex = json.loads((ROOT / "systems/pokedex/national_dex_1028.json").read_text())
assert dex["total_species"] == 1028
empty_dirs = [d for d in ROOT.rglob("*") if d.is_dir() and not any(d.iterdir())]
assert len(empty_dirs) == 0, f"Empty dirs remain: {empty_dirs}"
print(f"PASS: Integration Suite ({len(moves)} competitive moves, 1,028 species, 0 empty dirs)")
