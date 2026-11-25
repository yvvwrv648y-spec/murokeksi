#!/usr/bin/env python3
"""Convert pokefirered Sevii Islands maps to PUW shared intermediate format.
Data only: parses map.json, layouts.json, map.bin, metatiles.bin, tiles.png, palettes.
No ROM, no repo build tools."""
import json, os, re, struct, sys
from PIL import Image

SRC = os.path.expanduser('~/workspace/puw_world/src/pokefirered')
OUT = os.path.expanduser('~/workspace/puw_world/work/sevii')
PREFIXES = ('OneIsland','TwoIsland','ThreeIsland','FourIsland','FiveIsland',
            'SixIsland','SevenIsland','MtEmber','TrainerTower','BirthIsland','NavelRock')
NUM_PRIMARY = 640  # include/fieldmap.h NUM_METATILES_IN_PRIMARY
TOTAL = 1024       # NUM_METATILES_TOTAL

# --- tileset symbol -> directory, parsed from src/data/tilesets/metatiles.h ---
ts_dir = {}
txt = open(f'{SRC}/src/data/tilesets/metatiles.h').read()
for m in re.finditer(r'gMetatiles_(\w+)\[\] = INCBIN_U16\("data/tilesets/(primary|secondary)/([\w]+)/metatiles\.bin"\)', txt):
    ts_dir['gTileset_' + m.group(1)] = f"{m.group(2)}/{m.group(3)}"
print(f'tileset symbols mapped: {len(ts_dir)}')

def load_palettes(dirpath):
    pals = []
    pdir = f'{SRC}/data/tilesets/{dirpath}/palettes'
    for i in range(16):
        p = f'{pdir}/{i:02d}.pal'
        cols = [(0,0,0)]*16
        if os.path.exists(p):
            lines = open(p).read().splitlines()
            # JASC-PAL: header 3 lines, then "R G B" lines
            nums = []
            for ln in lines[3:]:
                parts = ln.split()
                if len(parts) == 3:
                    nums.append(tuple(int(x) for x in parts))
            if len(nums) >= 16:
                cols = nums[:16]
        pals.append(cols)
    return pals

# Some tilesets share another tileset's tile graphics + palettes (per headers.h,
# e.g. gTileset_SilphCo uses gTilesetTiles_Condominiums). Resolve that from the repo.
_headers = open(f'{SRC}/src/data/tilesets/headers.h').read()
_graphics = open(f'{SRC}/src/data/tilesets/graphics.h').read()
_tile_dir = {}
for m in re.finditer(r'gTilesetTiles_(\w+)\[\] = INCBIN_U32\("data/tilesets/((?:primary|secondary)/[\w]+)/tiles', _graphics):
    _tile_dir[m.group(1)] = m.group(2)
def shared_gfx_dir(sym):
    m = re.search(re.escape(sym) + r' =\s*\{\s*\.isCompressed = \w+,\s*\.isSecondary = \w+,\s*\.tiles = gTilesetTiles_(\w+),', _headers)
    if m and m.group(1) in _tile_dir:
        return _tile_dir[m.group(1)]
    return None

def load_tileset(dirpath, sym=None):
    meta = open(f'{SRC}/data/tilesets/{dirpath}/metatiles.bin','rb').read()
    gfx_dir = dirpath
    if not os.path.exists(f'{SRC}/data/tilesets/{dirpath}/tiles.png') and sym:
        shared = shared_gfx_dir(sym)
        if shared:
            print(f'note: {sym} has no tiles.png of its own; using shared graphics from {shared} (per headers.h)')
            gfx_dir = shared
    d = f'{SRC}/data/tilesets/{gfx_dir}'
    count = len(meta)//16
    entries = [struct.unpack_from('<8H', meta, i*16) for i in range(count)]
    img = Image.open(f'{d}/tiles.png').convert('P')
    w, h = img.size
    idx = [[img.getpixel((x,y)) for x in range(w)] for y in range(h)]
    return {'dir': dirpath, 'gfx_dir': gfx_dir, 'count': count, 'entries': entries,
            'palettes': load_palettes(gfx_dir), 'idx': idx, 'w': w, 'h': h}

def render_metatile(prim, sec, owner, entry4):
    """Render bottom layer (first 4 entries) of one metatile as 16x16 RGB image.

    ROOT FIX (production/sevii_atlas_fix, 2026-11-24): each quadrant's
    graphic is taken from the tileset its tile number belongs to --
    tile < NUM_PRIMARY from the primary at that index, tile >=
    NUM_PRIMARY from the secondary at index - NUM_PRIMARY (shared
    graphics, e.g. SilphCo -> Condominiums, already resolved by
    load_tileset). The previous version indexed the OWNER tileset's
    tiles.png with the global tile number: secondary quadrants past
    the local tile count sampled out of range and stayed magenta
    (defect D1: 3,697 secondary slots entirely magenta across the
    24 Sevii atlases), and cross-range quadrants were rendered from
    the wrong tileset's graphics (defect D2). Palettes are
    unchanged: the metatile owner's palettes, indexed by the
    entry's palette field."""
    out = Image.new('RGB', (16,16), (255,0,255))
    positions = [(0,0),(8,0),(0,8),(8,8)]
    for (ox,oy), e in zip(positions, entry4):
        tile_num = e & 0x3FF; hflip = (e>>10)&1; vflip = (e>>11)&1; pal = (e>>12)&0xF
        if tile_num < NUM_PRIMARY:
            gfx = prim; local_tile = tile_num
        else:
            gfx = sec; local_tile = tile_num - NUM_PRIMARY
        tiles_per_row = gfx['w']//8
        tx = (local_tile % tiles_per_row)*8; ty = (local_tile // tiles_per_row)*8
        colors = owner['palettes'][pal]
        for py in range(8):
            sy = ty + (7-py if vflip else py)
            if sy >= gfx['h']: continue
            for px in range(8):
                sx = tx + (7-px if hflip else px)
                ci = gfx['idx'][sy][sx] & 0xF
                out.putpixel((ox+px, oy+py), colors[ci])
    return out

# --- layouts ---
layouts = {l['id']: l for l in json.load(open(f'{SRC}/data/layouts/layouts.json'))['layouts'] if l.get('id')}

# --- Sevii inventory ---
all_maps = sorted(os.listdir(f'{SRC}/data/maps'))
sevii = [n for n in all_maps if n.startswith(PREFIXES) and os.path.exists(f'{SRC}/data/maps/{n}/map.json')]
print(f'Sevii maps found: {len(sevii)}')

ts_cache = {}
def get_ts(sym):
    if sym not in ts_cache:
        ts_cache[sym] = load_tileset(ts_dir[sym], sym)
    return ts_cache[sym]

converted, failed, violations = [], [], []
pair_keys = {}   # pair key -> (primary sym, secondary sym)
for name in sevii:
    try:
        mj = json.load(open(f'{SRC}/data/maps/{name}/map.json'))
        lay = layouts[mj['layout']]
        W, H = lay['width'], lay['height']
        prim_sym, sec_sym = lay['primary_tileset'], lay['secondary_tileset']
        pair = f"{ts_dir[prim_sym].split('/')[1]}__{ts_dir[sec_sym].split('/')[1]}"
        pair_keys[pair] = (prim_sym, sec_sym)
        raw = open(f'{SRC}/{lay["blockdata_filepath"]}','rb').read()
        expect = W*H*2
        if len(raw) != expect:
            violations.append(f'{name}: blockdata {len(raw)} bytes != {expect} for {W}x{H}')
            failed.append((name, f'blockdata size {len(raw)} != {expect}'))
            continue
        cells = [struct.unpack_from('<H', raw, i*2)[0] for i in range(W*H)]
        tiles = [c & 0x3FF for c in cells]
        collision = [((c>>10)&0x3) != 0 for c in cells]
        prim, sec = get_ts(prim_sym), get_ts(sec_sym)
        bad = [t for t in tiles if not (t < prim['count'] or (NUM_PRIMARY <= t < NUM_PRIMARY + sec['count']))]
        if bad:
            violations.append(f'{name}: {len(bad)} metatile ids out of range, e.g. {bad[:5]} (primary count {prim["count"]}, secondary count {sec["count"]} at offset {NUM_PRIMARY})')
        def _dw(v):
            try: return int(v)
            except (TypeError, ValueError): return v  # e.g. "WARP_ID_DYNAMIC" in TrainerTower_Elevator
        warps = [{'x': w['x'], 'y': w['y'], 'dest_map': w['dest_map'], 'dest_warp': _dw(w['dest_warp_id'])} for w in mj.get('warp_events', [])]
        objects = [{'x': o['x'], 'y': o['y'], 'graphics_id': o.get('graphics_id'), 'elevation': o.get('elevation')} for o in mj.get('object_events', [])]
        out = {'name': mj['name'], 'id_const': mj['id'], 'region': 'sevii',
               'region_map_section': mj.get('region_map_section'), 'tileset': pair,
               'primary_tileset': prim_sym, 'secondary_tileset': sec_sym,
               'tile_size': 16, 'width_tiles': W, 'height_tiles': H,
               'tiles': tiles, 'collision_grid': collision,
               'warps': warps, 'objects': objects, 'connections': mj.get('connections', [])}
        # NOTE: pokefirered layouts have ONE blockdata file (map.bin) = one metatile layer.
        # The bottom/top split lives inside each metatile (metatiles.bin entries), not in map data.
        # So there is no tiles_top grid to emit for this repo.
        with open(f'{OUT}/maps/{name}.json','w') as f:
            json.dump(out, f)
        converted.append(name)
    except Exception as e:
        failed.append((name, f'{type(e).__name__}: {e}'))

# --- render atlases, one per tileset pair ---
index = {}
for pair, (prim_sym, sec_sym) in sorted(pair_keys.items()):
    prim, sec = get_ts(prim_sym), get_ts(sec_sym)
    total = prim['count'] + sec['count']
    cols = 32
    rows = (total + cols - 1)//cols
    atlas = Image.new('RGB', (cols*16, rows*16), (255,0,255))
    for i in range(prim['count']):
        mt = render_metatile(prim, sec, prim, prim['entries'][i][:4])
        atlas.paste(mt, ((i%cols)*16, (i//cols)*16))
    for j in range(sec['count']):
        i = NUM_PRIMARY + j  # atlas slot uses the game's global metatile id space (primary padded to 640)
        # but atlas is laid out compactly? No: keep slot = global id would need 1024 slots.
        pass
    # Rebuild atlas in global-id space: slots 0..1023, primary 0-639, secondary 640..
    total_slots = NUM_PRIMARY + sec['count']
    rows = (total_slots + cols - 1)//cols
    atlas = Image.new('RGB', (cols*16, rows*16), (255,0,255))
    for i in range(prim['count']):
        mt = render_metatile(prim, sec, prim, prim['entries'][i][:4])
        atlas.paste(mt, ((i%cols)*16, (i//cols)*16))
    for j in range(sec['count']):
        i = NUM_PRIMARY + j
        mt = render_metatile(prim, sec, sec, sec['entries'][j][:4])
        atlas.paste(mt, ((i%cols)*16, (i//cols)*16))
    atlas.save(f'{OUT}/tilesets/{pair}.png')
    index[pair] = {'atlas': f'tilesets/{pair}.png', 'tile_size': 16, 'columns': 32,
                   'collision_tiles': [],
                   'primary_tileset': prim_sym, 'secondary_tileset': sec_sym,
                   'primary_metatile_count': prim['count'], 'secondary_metatile_count': sec['count'],
                   'metatile_id_space': f'primary ids 0-{NUM_PRIMARY-1}, secondary ids {NUM_PRIMARY}-{NUM_PRIMARY+sec["count"]-1}',
                   'note': 'Atlas slot index = global metatile id. Bottom layer of each metatile only.'}
    print(f'atlas {pair}: {atlas.size} primary={prim["count"]} secondary={sec["count"]}')

json.dump(index, open(f'{OUT}/tilesets.json','w'), indent=1)
json.dump({'found': sevii, 'converted': converted, 'failed': failed, 'violations': violations},
          open(f'{OUT}/conversion_report.json','w'), indent=1)
print(f'converted {len(converted)}/{len(sevii)}  failed={failed}  violations={violations}')
