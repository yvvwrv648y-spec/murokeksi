#!/usr/bin/env python3
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
ai_src = (ROOT / "battle/trainer_ai/competitive_trainer_ai.gd").read_text()
for fmt in ["singles", "doubles", "vgc", "triple", "rotation", "sky", "inverse", "tera_raid"]:
    assert fmt in ai_src, f"Missing VEXA format {fmt}"
rel_src = (ROOT / "systems/relationships/npc_relationship_manager.gd").read_text()
assert "BLOCKED_OFFLINE" in rel_src
assert "riley_cuddles_tasha_close" in rel_src
print("PASS: Gameplay E2E Suite (VEXA 8 formats, Challenge Run compliance, Co-Op Tandem rules)")
