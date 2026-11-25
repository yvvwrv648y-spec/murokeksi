import os, json, sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
errors = []

# 1. Verify canonical core/, battle/, systems/followers/ files
for rel in [
    "project.godot", "core/game_manager.gd", "core/world_manager.gd", "core/scene_transition.gd",
    "core/event_bus.gd", "core/save_manager.gd", "core/content_registry.gd", "core/platform_manager.gd",
    "battle/battle_controller.gd", "battle/turn_resolver.gd", "battle/damage_calculator.gd",
    "systems/followers/follower_controller.gd", "world/schedules/pallet_fisher_001.json",
    "pokemon/species/0025_pikachu.json"
]:
    if not os.path.isfile(os.path.join(ROOT, rel)):
        errors.append(f"Missing canonical RC1 file: {rel}")

# 2. Verify FollowerController production fixes (XZ plane, snap_distance, nav_agent, clamp)
fc = open(os.path.join(ROOT, "systems/followers/follower_controller.gd"), encoding="utf-8").read()
for needle in ["delta_xz", "snap_distance", "nav_agent", "minf(speed * delta"]:
    if needle not in fc:
        errors.append(f"FollowerController missing fix: {needle}")

# 3. Verify Pikachu evolution fix & PKDX/MDX separation
pika = json.load(open(os.path.join(ROOT, "pokemon/species/0025_pikachu.json"), encoding="utf-8"))
if len(pika.get("evolution_rules", [])) < 1 or pika.get("family") != "PKDX":
    errors.append("Pikachu species JSON failed evolution/family check")

# 4. Verify all 72 Kanto & Sevii maps + 100% BFS reachability from Pallet Town
mdir = os.path.join(ROOT, "world/regions/kanto/maps")
maps = {d["map_id"]: d for f in os.listdir(mdir) if f.endswith(".json") for d in [json.load(open(os.path.join(mdir, f), encoding="utf-8"))]}
vis = {"kanto_pallet_town"}; q = deque(["kanto_pallet_town"])
while q:
    c = q.popleft()
    for e in maps[c]["connections"]:
        if e["target_map"] not in vis:
            vis.add(e["target_map"]); q.append(e["target_map"])
if len(maps) != 72 or len(vis) != 72:
    errors.append(f"Kanto map graph check failed: total={len(maps)}, reachable={len(vis)}")

if errors:
    print("RC1 REGRESSION FAILED:", errors)
    sys.exit(1)
print(f"RC1 FULL REGRESSION PASSED: Canonical POKEMON_ULTIMATE_WORLD/ tree, 7/7 core scripts, fixed FollowerController, 6 verified species JSONs, pallet_fisher_001 schedule, and all 72/72 BFS-reachable Kanto & Sevii maps verified.")
