#!/usr/bin/env python3
import json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
bundle = ROOT.parent / "bw2_game_assets" / "asset_bundle.json"
if not bundle.exists():
    print("FAIL: asset_bundle.json missing"); sys.exit(1)
b = json.loads(bundle.read_text(encoding="utf-8"))
assert len(b.get("chars", {})) >= 28, "Missing char sheets"
assert len(b.get("bikes", {})) >= 32, "Missing bike sheets"
assert len(b.get("anims", {})) >= 6, "Missing anim sheets"
assert len(b.get("gyms", {})) >= 8, "Missing gym sheets"
assert len(b.get("elite4", {})) >= 4, "Missing elite4 sheets"
print(f"PASS: Asset Validator verified 78+ studio sheets ({bundle.stat().st_size/1024/1024:.2f} MB)")
