#!/usr/bin/env python3
"""Convert pret/pokered map data to the shared intermediate map format.

Reads ONLY data files from the disassembly repo (assembly text + .blk
binary block data + .bst blocksets + tileset PNGs). Writes per-map JSON,
a tileset index, tileset PNG copies, and a conversion report.
Approved by Riley in chat 2026-11-22 (process pokered).
"""
import json, re, shutil, sys
from pathlib import Path

SRC = Path.home() / "workspace/puw_world/src/pokered"
OUT = Path.home() / "workspace/puw_world/work/kanto"
MAPS_OUT = OUT / "maps"
TS_OUT = OUT / "tilesets"
MAPS_OUT.mkdir(parents=True, exist_ok=True)
TS_OUT.mkdir(parents=True, exist_ok=True)

def strip_comment(line):
    return line.split(";")[0].strip()

# ---------- map constants: CONST -> (width_blocks, height_blocks) ----------
map_consts = {}   # CONST -> (w, h)
const_order = []
for line in (SRC / "constants/map_constants.asm").read_text().splitlines():
    m = re.match(r"\s*map_const\s+([A-Z0-9_]+),\s*(\d+),\s*(\d+)", line)
    if m:
        map_consts[m.group(1)] = (int(m.group(2)), int(m.group(3)))
        const_order.append(m.group(1))

# ---------- tileset constants: CONST -> index ----------
tileset_consts = {}
for line in (SRC / "constants/tileset_constants.asm").read_text().splitlines():
    m = re.match(r"\s*const\s+([A-Z0-9_]+)", strip_comment(line))
    if m:
        tileset_consts[m.group(1)] = len(tileset_consts)

# ---------- tileset headers: index -> macro name ----------
tileset_names = []
for line in (SRC / "data/tilesets/tileset_headers.asm").read_text().splitlines():
    m = re.match(r"\s*tileset\s+([A-Za-z0-9_]+),", strip_comment(line))
    if m:
        tileset_names.append(m.group(1))
assert len(tileset_names) == len(tileset_consts), (len(tileset_names), len(tileset_consts))

# ---------- gfx/tilesets.asm: symbol prefix -> (png stem, blockset stem) ----------
gfx_map = {}   # "Overworld" -> ("overworld", "overworld")
pending_labels = []
for line in (SRC / "gfx/tilesets.asm").read_text().splitlines():
    lm = re.match(r"([A-Za-z0-9_]+)_(GFX|Block)::", line)
    if lm:
        pending_labels.append((lm.group(1), lm.group(2)))
    im = re.search(r'INCBIN\s+"gfx/(tilesets|blocksets)/([a-z0-9_]+)\.(2bpp|bst)"', line)
    if im:
        kind = "GFX" if im.group(1) == "tilesets" else "Block"
        for name, k in pending_labels:
            if k == kind:
                gfx_map.setdefault(name, {})["gfx" if kind == "GFX" else "block"] = im.group(2)
        pending_labels = []

# ---------- collision tile ids: tileset macro name -> [tile ids] ----------
collision = {}
current_labels = []
for line in (SRC / "data/tilesets/collision_tile_ids.asm").read_text().splitlines():
    lm = re.match(r"([A-Za-z0-9_]+)_Coll::", line)
    if lm:
        current_labels.append(lm.group(1))
        continue
    cm = re.match(r"\s*coll_tiles\s+(.*)", strip_comment(line))
    if cm and current_labels:
        ids = []
        for tok in cm.group(1).split(","):
            tok = tok.strip()
            if tok:
                ids.append(int(tok[1:], 16) if tok.startswith("$") else int(tok))
        for name in current_labels:
            collision[name] = ids
        current_labels = []

# ---------- build tileset index ----------
tilesets = {}
for name in tileset_names:
    info = gfx_map.get(name)
    if not info or "gfx" not in info or "block" not in info:
        print(f"WARN: tileset {name} missing gfx/block mapping: {info}")
        continue
    key = name.lower()
    png_src = SRC / "gfx/tilesets" / f"{info['gfx']}.png"
    shutil.copyfile(png_src, TS_OUT / f"{key}.png")
    tilesets[key] = {
        "atlas": f"tilesets/{key}.png",
        "tile_size": 8,
        "columns": 16,
        "collision_tiles": collision.get(name, []),
        "blockset_file": info["block"],
        "source_tileset_name": name,
    }
(TS_OUT.parent / "tilesets.json").write_text(json.dumps(tilesets, indent=1))

# blocksets loaded lazily
blocksets = {}
def load_blockset(stem):
    if stem not in blocksets:
        data = (SRC / "gfx/blocksets" / f"{stem}.bst").read_bytes()
        assert len(data) % 16 == 0, stem
        blocksets[stem] = [list(data[i:i+16]) for i in range(0, len(data), 16)]
    return blocksets[stem]

# ---------- maps.asm: <Name>_Blocks labels -> .blk file (stacked labels share) ----------
blk_for_stem = {}
pending = []
for line in (SRC / "maps.asm").read_text().splitlines():
    lm = re.match(r"([A-Za-z0-9_]+)_Blocks:", line)
    if lm:
        pending.append(lm.group(1))
    im = re.search(r'INCBIN\s+"maps/([A-Za-z0-9_]+)\.blk"', line)
    if im:
        for stem in pending:
            blk_for_stem[stem] = im.group(1)
        pending = []

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

const_by_norm = {norm(c): c for c in map_consts}

# ---------- headers ----------
def parse_header(path):
    tileset_const = None
    connections = []
    for line in path.read_text().splitlines():
        s = strip_comment(line)
        m = re.match(r"map_header\s+\w+,\s*([A-Z0-9_]+),\s*([A-Z0-9_]+)", s)
        if m:
            tileset_const = m.group(2)
            continue
        m = re.match(r"connection\s+(north|south|east|west),\s*\w+,\s*([A-Z0-9_]+),\s*(-?\d+)", s)
        if m:
            connections.append({"direction": m.group(1), "map": m.group(2), "offset": int(m.group(3))})
    return tileset_const, connections

# ---------- objects ----------
def parse_objects(path):
    border = None
    warps, bgs, objs = [], [], []
    for line in path.read_text().splitlines():
        s = strip_comment(line)
        m = re.match(r"db\s+\$([0-9a-fA-F]+)\s*$", s)
        if m and border is None and not warps and not objs:
            border = int(m.group(1), 16)
            continue
        m = re.match(r"warp_event\s+(-?\d+),\s*(-?\d+),\s*([A-Z0-9_]+),\s*(\d+)", s)
        if m:
            x, y = int(m.group(1)) * 2, int(m.group(2)) * 2
            warps.append({"x": x, "y": y, "w": 2, "h": 2,
                          "dest_map": m.group(3), "dest_warp": int(m.group(4))})
            continue
        m = re.match(r"bg_event\s+(-?\d+),\s*(-?\d+),\s*([A-Za-z0-9_]+)", s)
        if m:
            bgs.append({"x": int(m.group(1)) * 2, "y": int(m.group(2)) * 2,
                        "text_id": m.group(3)})
            continue
        m = re.match(r"object_event\s+(.+)$", s)
        if m:
            parts = [p.strip() for p in m.group(1).split(",")]
            entry = {"x": int(parts[0]) * 2, "y": int(parts[1]) * 2,
                     "sprite": parts[2], "movement": parts[3],
                     "direction": parts[4], "text_id": parts[5],
                     "trainer": None, "item": None}
            if len(parts) == 8:
                entry["trainer"] = {"class": parts[6].replace("OPP_", ""), "party": int(parts[7])}
            elif len(parts) == 7:
                entry["item"] = parts[6]
            objs.append(entry)
    return border, warps, bgs, objs

# ---------- convert every map that has header + blk ----------
headers = {p.stem: p for p in (SRC / "data/maps/headers").glob("*.asm")}
blks = {p.stem: p for p in (SRC / "maps").glob("*.blk")}
objects_dir = SRC / "data/maps/objects"

report = {"converted": [], "skipped": [], "warnings": []}
index = []
for stem in sorted(headers):
    hp = headers[stem]
    blk_stem = blk_for_stem.get(stem, stem)
    if blk_stem not in blks:
        report["skipped"].append({"map": stem, "reason": "header exists but no .blk file"})
        continue
    const = const_by_norm.get(norm(stem))
    if const is None:
        report["skipped"].append({"map": stem, "reason": "no matching map_const in map_constants.asm"})
        continue
    wb, hb = map_consts[const]
    if wb == 0 or hb == 0:
        report["skipped"].append({"map": stem, "reason": f"map_const size is {wb}x{hb}"})
        continue
    tileset_const, connections = parse_header(hp)
    if tileset_const is None or tileset_const not in tileset_consts:
        report["skipped"].append({"map": stem, "reason": f"bad tileset const {tileset_const}"})
        continue
    ts_name = tileset_names[tileset_consts[tileset_const]]
    ts_key = ts_name.lower()
    if ts_key not in tilesets:
        report["skipped"].append({"map": stem, "reason": f"tileset {ts_name} not in index"})
        continue
    blocks = load_blockset(tilesets[ts_key]["blockset_file"])
    blk = blks[blk_stem].read_bytes()
    if len(blk) != wb * hb:
        report["warnings"].append(f"{stem}: .blk has {len(blk)} blocks, map_const says {wb}x{hb}={wb*hb}")
    if len(blk) < wb * hb:
        # UndergroundPathNorthSouth: the repo's own comment in
        # map_constants.asm says the .blk is actually 4x23 while the
        # const declares 4x24. Trust the data file's real height.
        if len(blk) % wb == 0:
            hb = len(blk) // wb
            report["warnings"].append(f"{stem}: using real .blk height {hb} (map_const declares more; repo comment confirms .blk is authoritative)")
        else:
            report["skipped"].append({"map": stem, "reason": f".blk has {len(blk)} blocks but map_const size is {wb}x{hb}={wb*hb}"})
            continue
    w_tiles, h_tiles = wb * 4, hb * 4
    tiles = [0] * (w_tiles * h_tiles)
    for by in range(hb):
        for bx in range(wb):
            block_id = blk[by * wb + bx]
            if block_id >= len(blocks):
                report["warnings"].append(f"{stem}: block id {block_id} out of range (max {len(blocks)-1})")
                continue
            bt = blocks[block_id]
            for ty in range(4):
                for tx in range(4):
                    tiles[(by * 4 + ty) * w_tiles + (bx * 4 + tx)] = bt[ty * 4 + tx]
    border, warps, bgs, objs = (None, [], [], [])
    op = objects_dir / f"{stem}.asm"
    if op.exists():
        border, warps, bgs, objs = parse_objects(op)
    else:
        report["warnings"].append(f"{stem}: no objects file")
    m = {"name": stem, "id_const": const, "region": "kanto",
         "tileset": ts_key, "tile_size": 8,
         "width_tiles": w_tiles, "height_tiles": h_tiles,
         "tiles": tiles, "border_block": border,
         "warps": warps, "bg_events": bgs, "objects": objs,
         "connections": connections}
    (MAPS_OUT / f"{stem}.json").write_text(json.dumps(m))
    index.append({"name": stem, "id_const": const, "tileset": ts_key,
                  "width_tiles": w_tiles, "height_tiles": h_tiles,
                  "warps": len(warps), "objects": len(objs)})
    report["converted"].append(stem)

for stem in sorted(blks):
    if stem not in headers:
        report["skipped"].append({"map": stem, "reason": ".blk exists but no header file"})
for c in const_order:
    if map_consts[c] != (0, 0) and norm(c) not in {norm(s) for s in headers}:
        report["skipped"].append({"map": c, "reason": "in map_constants but no header/.blk pair"})

(OUT / "maps_index.json").write_text(json.dumps(index, indent=1))
(OUT / "conversion_report.json").write_text(json.dumps(report, indent=1))
print(f"converted: {len(report['converted'])}")
print(f"skipped: {len(report['skipped'])}")
for s in report["skipped"]:
    print("  SKIP", s["map"], "-", s["reason"])
print(f"warnings: {len(report['warnings'])}")
for w in report["warnings"][:20]:
    print("  WARN", w)
