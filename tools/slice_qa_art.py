#!/usr/bin/env python3
"""Slice ONLY the QA-accepted frames from Neon's 2026-11-22 art delivery.

Sources of truth (verdict files, read in full before this script was
written):
  qa/qa_walk_pilot.md, qa/qa_ride_riley.md, qa/qa_ride_tasha.md,
  qa/qa_ride_generic_a.md, qa/qa_ride_generic_b.md

Rules enforced here (Riley's rule: use only what makes sense;
rejected material is documented, never used, never replaced):
  * Walk pilot: Riley all 32 body+outfit frames composited. Tasha
    down/up/right rows only (24+24); the LEFT row is NOT sliced at
    all (C3/C4/C6/C7/C8 face right in both sheets) -- no mirroring.
  * Ride poses: only the PER-POSE CHOICE primaries from the verdict
    files are sliced. Accepted backups are ignored. Rejected figures
    are never written.
  * JPEG magenta fringe: the chroma keyer from slice_cast_frames.py
    (colour-distance ramp + 1px erosion + boundary despill) is used.

Outputs (project + pack mirrors, same convention as frame_data.json):
  art_frames/characters/layered/walk/<char>_walk_composite/f<row><col>.png
  art_frames/characters/rides/<sheet_stem>_<version>/<figure>.png
  systems/cast/rider_frame_data.json (new)
  systems/cast/frame_data.json (walk composite sheets + directional
    cast_states added; existing entries untouched)
  systems/cast/rider_poses.json (art_status / frames_bound updated)
  art/contact_sheets/{riley,tasha}_walk_layered_contact.png,
    {riley,tasha}_ride_poses_contact.png (pack + project copies)

Usage:
  python3 slice_qa_art.py --incoming DIR --project DIR --pack DIR
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

# ---------------------------------------------------------------------------
# Chroma keying -- copied from tools/slice_cast_frames.py (same project
# convention: distance ramp, 1px erosion, boundary despill).
# ---------------------------------------------------------------------------

def key_color_for(img_rgb):
    w, h = img_rgb.size
    corners = []
    for x0, y0 in ((0, 0), (w - 24, 0), (0, h - 24), (w - 24, h - 24)):
        patch = np.asarray(img_rgb.crop((x0, y0, x0 + 24, y0 + 24)), dtype=np.float32)
        corners.append(np.median(patch.reshape(-1, 3), axis=0))
    return np.median(np.array(corners), axis=0)


def chroma_key(rgba_arr, key_rgb):
    rgb = rgba_arr[:, :, :3].astype(np.float32)
    dist = np.sqrt(((rgb - key_rgb) ** 2).sum(axis=2))
    alpha = np.clip((dist - 20.0) / 100.0, 0.0, 1.0)
    padded = np.pad(alpha, 1, mode="edge")
    eroded = np.minimum.reduce([
        padded[1:-1, 1:-1], padded[:-2, 1:-1], padded[2:, 1:-1],
        padded[1:-1, :-2], padded[1:-1, 2:],
    ])
    alpha = np.where(alpha >= 1.0, np.minimum(alpha, np.maximum(eroded, 0.92)), alpha)
    out = rgba_arr.copy()
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    near_edge = alpha < 0.999
    for _ in range(2):
        p = np.pad(near_edge, 1, mode="edge")
        near_edge = np.maximum.reduce([
            p[1:-1, 1:-1], p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:],
            p[:-2, :-2], p[:-2, 2:], p[2:, :-2], p[2:, 2:],
        ])
    rr = out[:, :, 0].astype(np.float32)
    gg = out[:, :, 1].astype(np.float32)
    bb = out[:, :, 2].astype(np.float32)
    ring = near_edge & (alpha > 0.0) & (rr > gg + 40) & (bb > gg + 40)
    rr[ring] = gg[ring] + (rr[ring] - gg[ring]) * 0.3
    bb[ring] = gg[ring] + (bb[ring] - gg[ring]) * 0.3
    out[:, :, 0] = rr.astype(np.uint8)
    out[:, :, 2] = bb.astype(np.uint8)
    semi = (alpha > 0.0) & (alpha < 1.0)
    if semi.any():
        r = out[:, :, 0].astype(np.float32)
        g = out[:, :, 1].astype(np.float32)
        b = out[:, :, 2].astype(np.float32)
        magentaish = semi & (r > g + 25) & (b > g + 25)
        r[magentaish] = np.minimum(r[magentaish], g[magentaish] + 25)
        b[magentaish] = np.minimum(b[magentaish], g[magentaish] + 25)
        out[:, :, 0] = r.astype(np.uint8)
        out[:, :, 2] = b.astype(np.uint8)
    return out, dist


def keyed_sheet(path):
    img = Image.open(path).convert("RGB")
    key_rgb = key_color_for(img)
    rgba = np.dstack([np.asarray(img), np.full(img.size[::-1], 255, np.uint8)])
    keyed, dist = chroma_key(rgba, key_rgb)
    return Image.fromarray(keyed, "RGBA"), dist, key_rgb


def place_on_canvas(crop_rgba, anchor_in_crop, canvas_w, canvas_h):
    """Bottom-centre anchor alignment: anchor lands at (canvas_w//2, canvas_h-1)."""
    tx, ty = canvas_w // 2, canvas_h - 1
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    dx, dy = tx - anchor_in_crop[0], ty - anchor_in_crop[1]
    bw, bh = crop_rgba.size
    sx0, sy0 = max(0, -dx), max(0, -dy)
    sx1, sy1 = min(bw, canvas_w - dx), min(bh, canvas_h - dy)
    if sx1 > sx0 and sy1 > sy0:
        canvas.paste(crop_rgba.crop((sx0, sy0, sx1, sy1)), (dx + sx0, dy + sy0))
    return canvas


def content_bbox(alpha_arr, thresh=8):
    ys, xs = np.where(alpha_arr > thresh)
    if len(xs) == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]


# ---------------------------------------------------------------------------
# Accepted-frame tables, transcribed from the verdict files.
# Ride: (cast_id, version, figure) -> (pose_id, role)
# ---------------------------------------------------------------------------

RIDE_CHOICES = {
    # --- Riley: qa_ride_riley.md PER-POSE CHOICE ---
    "riley": [
        ("v2", "R1F1", "ride_land_seated", "hold"),
        ("v2", "R1F2", "ride_land_gallop", "calm"),
        ("v2", "R1F3", "ride_land_gallop", "wind"),
        ("v1", "R1F4", "surf_stand", "hold"),
        ("v1", "R1F5", "surf_kneel", "hold"),
        ("v1", "R1F6", "ferry_seated", "hold"),
        ("v1", "R2F1", "fly_seated", "calm"),
        ("v1", "R2F2", "fly_seated", "wind"),
        ("v1", "R2F3", "fly_carried", "hold"),
        ("v2", "R2F4", "dive_hold", "hold"),
        ("v1", "R2F5", "climb_cling", "hold"),
        ("v1", "R2F6", "climb_stand", "hold"),
        ("v1", "R3F1", "hover_stand", "calm"),
        ("v1", "R3F2", "hover_stand", "wind"),
        ("v2", "R3F3", "carry_held", "hold"),
        ("v2", "R3F4", "burrow_crouch", "hold"),
        ("v2", "R3F5", "mount_wave", "wave"),
    ],
    # --- Tasha: qa_ride_tasha.md PER-POSE CHOICE ---
    "tasha": [
        ("v2", "R1F1", "ride_land_seated", "hold"),
        ("v2", "R1F2", "ride_land_gallop", "calm"),
        ("v2", "R1F3", "ride_land_gallop", "wind"),
        ("v1", "R1F4", "surf_stand", "hold"),
        ("v1", "R1F5", "surf_kneel", "hold"),
        ("v2", "R1F6", "ferry_seated", "hold"),
        ("v1", "R2F1", "fly_seated", "calm"),
        ("v2", "R2F2", "fly_seated", "wind"),
        ("v1", "R2F4", "dive_hold", "hold"),
        ("v1", "R2F5", "climb_cling", "hold"),
        ("v1", "R2F6", "climb_stand", "hold"),
        ("v1", "R3F1", "hover_stand", "calm"),
        ("v1", "R3F2", "hover_stand", "wind"),
        ("v2", "R3F3", "carry_held", "hold"),
        ("v1", "R3F4", "burrow_crouch", "hold"),
        ("v1", "R3F5", "hover_descend", "high"),
    ],
    # --- Custom Female: qa_ride_generic_a.md PER-POSE CHOICE ---
    "custom_female": [
        ("v1", "R1F1", "ride_land_seated", "hold"),
        ("v1", "R1F2", "ride_land_gallop", "calm"),
        ("v1", "R1F3", "ride_land_gallop", "wind"),
        ("v1", "R1F4", "surf_stand", "hold"),
        ("v1", "R1F5", "surf_kneel", "hold"),
        ("v1", "R1F6", "ferry_seated", "hold"),
        ("v1", "R2F1", "fly_seated", "calm"),
        ("v1", "R2F2", "fly_seated", "wind"),
        ("v1", "R2F3", "fly_carried", "hold"),
        ("v1", "R2F4", "dive_hold", "hold"),
        ("v2", "R2F6", "climb_stand", "hold"),
        ("v1", "R3F1", "hover_stand", "calm"),
        ("v1", "R3F2", "hover_stand", "wind"),
        ("v1", "R3F3", "carry_held", "hold"),
        ("v2", "R3F5", "burrow_crouch", "hold"),
    ],
    # --- Custom Male: qa_ride_generic_a.md PER-POSE CHOICE (all v2) ---
    "custom_male": [
        ("v2", "R1F1", "ride_land_seated", "hold"),
        ("v2", "R1F2", "ride_land_gallop", "calm"),
        ("v2", "R1F3", "ride_land_gallop", "wind"),
        ("v2", "R1F4", "surf_stand", "hold"),
        ("v2", "R1F5", "surf_kneel", "hold"),
        ("v2", "R1F6", "ferry_seated", "hold"),
        ("v2", "R2F1", "fly_seated", "calm"),
        ("v2", "R2F2", "fly_seated", "wind"),
        ("v2", "R2F3", "fly_carried", "hold"),
        ("v2", "R2F4", "dive_hold", "hold"),
        ("v2", "R2F6", "climb_stand", "hold"),
        ("v2", "R3F1", "hover_stand", "calm"),
        ("v2", "R3F2", "hover_stand", "wind"),
        ("v2", "R3F3", "carry_held", "hold"),
        ("v2", "R3F4", "burrow_crouch", "hold"),
    ],
    # --- Custom Femboy: qa_ride_generic_b.md per-pose choice ---
    "custom_femboy": [
        ("v1", "R1F1", "ride_land_seated", "hold"),
        ("v1", "R1F2", "ride_land_gallop", "calm"),
        ("v1", "R1F3", "ride_land_gallop", "wind"),
        ("v1", "R1F4", "surf_stand", "hold"),
        ("v1", "R1F5", "surf_kneel", "hold"),
        ("v1", "R1F6", "ferry_seated", "hold"),
        ("v1", "R2F1", "fly_seated", "calm"),
        ("v1", "R2F2", "fly_seated", "wind"),
        ("v1", "R2F3", "fly_carried", "hold"),
        ("v1", "R2F4", "dive_hold", "hold"),
        ("v1", "R2F5", "climb_cling", "hold"),
        ("v1", "R3F1", "hover_stand", "calm"),
        ("v1", "R3F2", "hover_stand", "wind"),
        ("v1", "R3F3", "carry_held", "hold"),
        ("v2", "R3F4", "burrow_crouch", "hold"),
    ],
    # --- Custom Futanari: qa_ride_generic_b.md (v1 == v2 byte-identical;
    #     sliced from the v1 copy only) ---
    "custom_futanari": [
        ("v1", "R1F1", "ride_land_seated", "hold"),
        ("v1", "R1F2", "ride_land_gallop", "calm"),
        ("v1", "R1F3", "ride_land_gallop", "wind"),
        ("v1", "R1F4", "surf_stand", "hold"),
        ("v1", "R1F5", "surf_kneel", "hold"),
        ("v1", "R1F6", "ferry_seated", "hold"),
        ("v1", "R2F1", "fly_seated", "calm"),
        ("v1", "R2F2", "fly_seated", "wind"),
        ("v1", "R2F3", "fly_carried", "hold"),
        ("v1", "R2F4", "dive_hold", "hold"),
        ("v1", "R3F1", "hover_stand", "calm"),
        ("v1", "R3F2", "hover_stand", "wind"),
        ("v1", "R3F3", "carry_held", "hold"),
        ("v1", "R3F4", "burrow_crouch", "hold"),
    ],
}

RIDE_SHEET_FILE = {
    "riley": "ride_riley_sheet.jpg",
    "tasha": "ride_tasha_sheet.jpg",
    "custom_female": "ride_custom_female_sheet.jpg",
    "custom_male": "ride_custom_male_sheet.jpg",
    "custom_femboy": "ride_custom_femboy_sheet.jpg",
    "custom_futanari": "ride_custom_futanari_sheet.jpg",
}

QA_REF = {
    "riley": "qa/qa_ride_riley.md",
    "tasha": "qa/qa_ride_tasha.md",
    "custom_female": "qa/qa_ride_generic_a.md",
    "custom_male": "qa/qa_ride_generic_a.md",
    "custom_femboy": "qa/qa_ride_generic_b.md",
    "custom_futanari": "qa/qa_ride_generic_b.md",
}

EXPECTED_COMPONENTS = {  # verdict figure counts per sheet (cross-check)
    ("riley", "v1"): 17, ("riley", "v2"): 17,
    ("tasha", "v1"): 17, ("tasha", "v2"): 17,
    ("custom_female", "v1"): 17, ("custom_female", "v2"): 17,
    ("custom_male", "v1"): 18, ("custom_male", "v2"): 16,
    ("custom_femboy", "v1"): 16, ("custom_femboy", "v2"): 16,
    ("custom_futanari", "v1"): 16,
}

POSE_ORDER = ["ride_land_seated", "ride_land_gallop", "surf_stand", "surf_kneel",
              "ferry_seated", "fly_seated", "fly_carried", "dive_hold",
              "climb_cling", "climb_stand", "hover_stand", "carry_held",
              "burrow_crouch", "mount_wave", "hover_descend"]


def segment_sheet(path):
    """Connected components on the magenta key, ordered row-major
    (y-bands, left-to-right) to match the graders' R<row>F<n> ids.
    Returns (keyed_image, {figure_id: (label_id, bbox)})."""
    keyed, dist, _k = keyed_sheet(path)
    mask = dist > 60.0
    lab, _n = ndimage.label(mask, structure=np.ones((3, 3), dtype=int))
    objs = ndimage.find_objects(lab)
    comps = []
    h_img = mask.shape[0]
    for i, sl in enumerate(objs):
        if sl is None:
            continue
        area = int((lab[sl] == i + 1).sum())
        x0, y0 = sl[1].start, sl[0].start
        w, hh = sl[1].stop - x0, sl[0].stop - y0
        if area < 800:
            continue
        # Tasha v1 burned-in text labels: thin components hugging the
        # bottom edge (figures sit clear above the text).
        if y0 + hh >= h_img - 4 and hh <= 30:
            continue
        comps.append({"label": i + 1, "bbox": [x0, y0, w, hh], "area": area,
                      "cx": x0 + w / 2.0, "cy": y0 + hh / 2.0})
    # Row bands: sort by centre-y, split on gaps > 100 px.
    comps.sort(key=lambda c: c["cy"])
    rows = []
    for c in comps:
        if rows and c["cy"] - max(x["cy"] for x in rows[-1]) <= 100:
            rows[-1].append(c)
        else:
            rows.append([c])
    figures = {}
    for ri, row in enumerate(rows, start=1):
        for fi, c in enumerate(sorted(row, key=lambda c: c["cx"]), start=1):
            figures["R%dF%d" % (ri, fi)] = c
    return keyed, lab, figures


def slice_rides(incoming, out_roots):
    """Returns rider_frame_data cast dict + per-sheet sliced counts."""
    cast_data = {}
    counts = {}
    # Group choices by (cast, version) so each sheet is segmented once.
    needed = {}
    for cast_id, choices in RIDE_CHOICES.items():
        for version, figure, pose, role in choices:
            needed.setdefault((cast_id, version), []).append((figure, pose, role))
    for (cast_id, version), wanted in sorted(needed.items()):
        sheet_file = RIDE_SHEET_FILE[cast_id]
        path = os.path.join(incoming, "ride_" + version, "characters", "rides", sheet_file)
        keyed, lab, figures = segment_sheet(path)
        expected = EXPECTED_COMPONENTS[(cast_id, version)]
        assert len(figures) == expected, "%s %s: segmented %d figures, verdict says %d" % (
            cast_id, version, len(figures), expected)
        stem = os.path.splitext(sheet_file)[0] + "_" + version
        # First pass: extract each wanted figure's tight crop.
        crops = {}
        for figure, pose, role in wanted:
            comp = figures[figure]
            x0, y0, w, hh = comp["bbox"]
            pad = 3
            rx0, ry0 = max(0, x0 - pad), max(0, y0 - pad)
            rx1, ry1 = min(keyed.width, x0 + w + pad), min(keyed.height, y0 + hh + pad)
            region = np.asarray(keyed.crop((rx0, ry0, rx1, ry1))).copy()
            label_region = lab[ry0:ry1, rx0:rx1]
            region[:, :, 3] = np.where(label_region == comp["label"], region[:, :, 3], 0)
            bb = content_bbox(region[:, :, 3])
            assert bb is not None, "%s %s %s empty" % (cast_id, version, figure)
            tight = Image.fromarray(region, "RGBA").crop((bb[0], bb[1], bb[0] + bb[2], bb[1] + bb[3]))
            abs_bbox = [rx0 + bb[0], ry0 + bb[1], bb[2], bb[3]]
            crops[figure] = (tight, abs_bbox, pose, role)
        canvas_w = max(t.size[0] for t, _b, _p, _r in crops.values())
        canvas_h = max(t.size[1] for t, _b, _p, _r in crops.values())
        for figure, (tight, abs_bbox, pose, role) in crops.items():
            anchor_in_crop = (abs_bbox[2] // 2, abs_bbox[3] - 1)
            frame_img = place_on_canvas(tight, anchor_in_crop, canvas_w, canvas_h)
            rel = "characters/rides/%s/%s.png" % (stem, figure)
            for root in out_roots:
                dest = os.path.join(root, rel)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                frame_img.save(dest)
            rec = {
                "figure": figure,
                "pose": pose,
                "role": role,
                "source_sheet": "ride_%s/characters/rides/%s" % (version, sheet_file),
                "source_version": version,
                "png": "res://art_frames/" + rel,
                "pack_png": "art/frames/" + rel,
                "anchor_offset": [0, 0],
                "content_bbox": abs_bbox,
                "opaque_px": int((np.asarray(frame_img)[:, :, 3] > 8).sum()),
                "qa_ref": QA_REF[cast_id],
            }
            cast_data.setdefault(cast_id, {}).setdefault(pose, []).append(rec)
            counts[(cast_id, version)] = counts.get((cast_id, version), 0) + 1
        print("ride %s %s: %d figures segmented, %d sliced" % (cast_id, version, len(figures), len(crops)))
    # Order each pose's frames by role order calm<wind / idle<wave / high<touching_down.
    role_rank = {"calm": 0, "wind": 1, "idle": 0, "wave": 1, "high": 0, "touching_down": 1, "hold": 0}
    for cast_id in cast_data:
        for pose in cast_data[cast_id]:
            cast_data[cast_id][pose].sort(key=lambda r: role_rank.get(r["role"], 0))
    return cast_data, counts


# ---------------------------------------------------------------------------
# Walk pilot
# ---------------------------------------------------------------------------

WALK_ROWS = {1: "down", 2: "up", 3: "left", 4: "right"}
WALK_ACCEPTED_ROWS = {"riley": [1, 2, 3, 4], "tasha": [1, 2, 4]}  # tasha row 3 REJECTED


def slice_walk(incoming, out_roots):
    """Returns (frame_data sheet records, cast_states additions, counts)."""
    walk_dir = os.path.join(incoming, "walk_pilot", "characters", "layered", "walk")
    sheets_out = {}
    states_out = {}
    counts = {}
    for char in ("riley", "tasha"):
        body_keyed, _d1, _k1 = keyed_sheet(os.path.join(walk_dir, "%s_base_body_walk.jpg" % char))
        outfit_keyed, _d2, _k2 = keyed_sheet(os.path.join(walk_dir, "%s_outfit_signature_walk.jpg" % char))
        cell_w, cell_h = 1376 // 8, 768 // 4  # 172 x 192 per the spec's 4x8 grid on 1376x768
        crops = {}
        for row in WALK_ACCEPTED_ROWS[char]:
            for col in range(1, 9):
                x0, y0 = (col - 1) * cell_w, (row - 1) * cell_h
                comp_img = body_keyed.crop((x0, y0, x0 + cell_w, y0 + cell_h))
                comp_img.alpha_composite(outfit_keyed.crop((x0, y0, x0 + cell_w, y0 + cell_h)))
                bb = content_bbox(np.asarray(comp_img)[:, :, 3])
                assert bb is not None
                tight = comp_img.crop((bb[0], bb[1], bb[0] + bb[2], bb[1] + bb[3]))
                crops[(row, col)] = (tight, [x0 + bb[0], y0 + bb[1], bb[2], bb[3]])
        canvas_w = max(t.size[0] for t, _b in crops.values())
        canvas_h = max(t.size[1] for t, _b in crops.values())
        stem = "characters/layered/walk/%s_walk_composite" % char
        frame_records = []
        for (row, col), (tight, abs_bbox) in sorted(crops.items()):
            frame_img = place_on_canvas(tight, (abs_bbox[2] // 2, abs_bbox[3] - 1), canvas_w, canvas_h)
            name = "f%d%d.png" % (row, col)
            for root in out_roots:
                dest = os.path.join(root, stem, name)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                frame_img.save(dest)
            frame_records.append({
                "index": (row - 1) * 8 + (col - 1),
                "row": row, "col": col, "direction": WALK_ROWS[row],
                "png": "res://art_frames/%s/%s" % (stem, name),
                "pack_png": "art/frames/%s/%s" % (stem, name),
                "anchor_offset": [0, 0],
                "content_bbox": abs_bbox,
                "opaque_px": int((np.asarray(frame_img)[:, :, 3] > 8).sum()),
            })
        sheets_out[stem] = {
            "source_sheet": "walk_pilot layered composite (body + outfit) for " + char,
            "method": "layered_composite_qa_accepted_only",
            "confidence": "high",
            "grid": {"cols": 8, "rows": 4, "cell_w": cell_w, "cell_h": cell_h},
            "canvas": [canvas_w, canvas_h],
            "anchor_target": [canvas_w // 2, canvas_h - 1],
            "qa_ref": "qa/qa_walk_pilot.md",
            "frames": frame_records,
        }
        states = {}
        for row in WALK_ACCEPTED_ROWS[char]:
            direction = WALK_ROWS[row]
            states["walk_" + direction] = {
                "sheet": stem,
                "frames": [(row - 1) * 8 + c for c in range(8)],
                "fps": 7.5, "loop": True,
            }
        states_out[char] = states
        counts[char] = len(frame_records)
        print("walk %s: %d composite frames (rows %s)" % (char, len(frame_records), WALK_ACCEPTED_ROWS[char]))
    return sheets_out, states_out, counts


# ---------------------------------------------------------------------------
# Contact sheets
# ---------------------------------------------------------------------------

def make_contact(cells, cols, out_paths, cell_w=190, cell_h=250):
    """cells: list of (label, PIL image or None). Dark bg, labeled."""
    rows = (len(cells) + cols - 1) // cols
    label_h = 22
    sheet = Image.new("RGBA", (cols * cell_w, rows * (cell_h + label_h)), (32, 32, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(cells):
        cx, cy = (i % cols) * cell_w, (i // cols) * (cell_h + label_h)
        draw.text((cx + 6, cy + 5), label, fill=(255, 255, 120, 255))
        if img is not None:
            im = img.copy()
            im.thumbnail((cell_w - 8, cell_h - 8))
            sheet.alpha_composite(im, (cx + (cell_w - im.width) // 2, cy + label_h + (cell_h - im.height)))
    for p in out_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        sheet.convert("RGB").save(p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--incoming", required=True)
    ap.add_argument("--project", required=True)
    ap.add_argument("--pack", required=True)
    args = ap.parse_args()

    proj_frames = os.path.join(args.project, "art_frames")
    pack_frames = os.path.join(args.pack, "art", "frames")
    roots = [proj_frames, pack_frames]

    ride_cast, ride_counts = slice_rides(args.incoming, roots)
    walk_sheets, walk_states, walk_counts = slice_walk(args.incoming, roots)

    # --- rider_frame_data.json ---
    rider_data = {
        "note": "QA-integrated 2026-11-22: ONLY the accepted primary figures from the ride-pose verdict files (qa/qa_ride_riley.md, qa/qa_ride_tasha.md, qa/qa_ride_generic_a.md, qa/qa_ride_generic_b.md) were sliced, by magenta-key connected components ordered row-major to match the graders' figure ids. Rejected figures and accepted backups were NOT sliced. Frames are chroma-keyed with despill, cropped to content bbox, and bottom-centre anchor aligned on a uniform canvas per source sheet (anchor_offset 0 after alignment). The custom futanari v1/v2 sheets are byte-identical; frames were sliced from the v1 copy only.",
        "schema": "puw_rider_frame_data_v1",
        "cast": {
            cast_id: {
                pose: {"frames": recs}
                for pose, recs in sorted(poses.items(), key=lambda kv: POSE_ORDER.index(kv[0]))
            }
            for cast_id, poses in ride_cast.items()
        },
    }
    for root in (args.project, args.pack):
        dest = os.path.join(root, "systems", "cast", "rider_frame_data.json")
        with open(dest, "w") as fh:
            json.dump(rider_data, fh, indent=1)
        print("wrote", dest)

    # --- frame_data.json: add walk composite sheets + directional states ---
    for root in (args.project, args.pack):
        dest = os.path.join(root, "systems", "cast", "frame_data.json")
        data = json.load(open(dest))
        for stem, rec in walk_sheets.items():
            # frame_png_for() looks sheets up by the cast_states sheet
            # key; keep the key identical to the cast_states sheet value.
            data["sheets"][stem] = rec
        for char, states in walk_states.items():
            for state_name, state_rec in states.items():
                data["cast_states"][char][state_name] = state_rec
            data.setdefault("resolution_notes", {}).setdefault(char, {})["walk_directional"] = (
                "Layered walk pilot (QA 2026-11-22, qa/qa_walk_pilot.md): per-facing clips "
                "walk_down/walk_up/walk_left/walk_right built from the composited body+outfit "
                "pilot frames at CLIP_FPS WALK 7.5."
                if char == "riley" else
                "Layered walk pilot (QA 2026-11-22, qa/qa_walk_pilot.md): walk_down/walk_up/"
                "walk_right bound from the composited pilot frames at 7.5 fps. walk_left is "
                "NOT bound: the pilot's left row faces right in C3/C4/C6/C7/C8 in both sheets "
                "and was rejected; the bare 'walk' fallback stays until Neon redoes the left row.")
        with open(dest, "w") as fh:
            json.dump(data, fh, indent=1)
        print("updated", dest)

    # --- rider_poses.json: truthful art statuses ---
    bound_counts = {}
    for cast_id, poses in ride_cast.items():
        bound_counts[cast_id] = {pose: len(recs) for pose, recs in poses.items()}
    for root in (args.project, args.pack):
        dest = os.path.join(root, "systems", "cast", "rider_poses.json")
        data = json.load(open(dest))
        data["notes"] = (
            "Rider pose taxonomy for rideable Pokemon (Phase 3, item B), decided 2026-11-22, "
            "refined 2026-11-22 14:59 CST into THREE pose sets: riley (custom, expressive) and "
            "tasha (custom, composed) with one signature extra state each, and generic (neutral) "
            "shared by the four Custom presets. QA INTEGRATION 2026-11-22: Neon's ride sheets "
            "(v1 + v2) were visually graded (qa/qa_ride_riley.md, qa/qa_ride_tasha.md, "
            "qa/qa_ride_generic_a.md, qa/qa_ride_generic_b.md) and ONLY the accepted primary "
            "figures were sliced into systems/cast/rider_frame_data.json. Bound today: riley 13 "
            "poses complete + mount_wave partial (wave frame only, idle missing); tasha 12 poses "
            "complete + hover_descend partial (1 of 2 frames), fly_carried still art_pending "
            "(rejected in both versions); each Custom preset 11-12 of 13 poses bound -- the "
            "generic set's per-cast truth lives in art_status_by_cast / frames_bound_by_cast "
            "because the four presets do not share one status (climb_cling is bound only for "
            "custom_femboy; climb_stand is missing for custom_femboy and custom_futanari). "
            "Rejected figures were never sliced and nothing was substituted.")
        for set_id, set_rec in data["sets"].items():
            cast_ids = set_rec["cast_ids"]
            for pose_rec in set_rec["poses"]:
                pose = pose_rec["id"]
                if set_id in ("riley", "tasha"):
                    cast_id = cast_ids[0]
                    n = bound_counts.get(cast_id, {}).get(pose, 0)
                    if n > 0:
                        pose_rec["art_status"] = "bound"
                        pose_rec["frames_bound"] = n
                    else:
                        pose_rec["art_status"] = "art_pending"
                        pose_rec.pop("frames_bound", None)
                    if cast_id == "riley" and pose == "mount_wave":
                        pose_rec["art_note"] = "PARTIAL 1/2: the wave frame (v2 R3F5) is bound; the mounted idle frame is MISSING in both v1 and v2 and is still owed by Neon."
                    if cast_id == "tasha" and pose == "hover_descend":
                        pose_rec["art_note"] = "PARTIAL 1/2: one frame (v1 R3F5) is bound; the second frame of the high/touching_down pair is MISSING in both versions and is still owed by Neon."
                    if cast_id == "tasha" and pose == "fly_carried":
                        pose_rec["art_note"] = "Rejected in both versions (v1 hangs from a drawn bar with arms up; v2 stands on the ground). Redraw owed: dangling, arms crossed, unimpressed."
                else:  # generic: per-cast truth
                    by_cast = {}
                    counts_by_cast = {}
                    for cast_id in cast_ids:
                        n = bound_counts.get(cast_id, {}).get(pose, 0)
                        counts_by_cast[cast_id] = n
                        by_cast[cast_id] = "bound" if n > 0 else "art_pending"
                    pose_rec["art_status_by_cast"] = by_cast
                    pose_rec["frames_bound_by_cast"] = counts_by_cast
                    vals = set(by_cast.values())
                    if vals == {"bound"}:
                        pose_rec["art_status"] = "bound"
                        pose_rec["frames_bound"] = counts_by_cast[cast_ids[0]]
                    elif vals == {"art_pending"}:
                        pose_rec["art_status"] = "art_pending"
                        pose_rec.pop("frames_bound", None)
                    else:
                        pose_rec["art_status"] = "partial_by_cast"
                        pose_rec.pop("frames_bound", None)
        with open(dest, "w") as fh:
            json.dump(data, fh, indent=1)
        print("updated", dest)

    # --- Contact sheets ---
    def load_pack(rel):
        return Image.open(os.path.join(pack_frames, rel)).convert("RGBA")

    for char, rows in (("riley", [1, 2, 3, 4]), ("tasha", [1, 2, 3, 4])):
        cells = []
        for row in rows:
            direction = WALK_ROWS[row]
            if row in WALK_ACCEPTED_ROWS[char]:
                for col in range(1, 9):
                    cells.append(("%s f%d%d" % (direction, row, col),
                                  load_pack("characters/layered/walk/%s_walk_composite/f%d%d.png" % (char, row, col))))
            else:
                cells.append(("LEFT PENDING", None))
                for _ in range(7):
                    cells.append(("", None))
        make_contact(cells, 8, [
            os.path.join(args.pack, "art", "contact_sheets", "%s_walk_layered_contact.png" % char),
            os.path.join(args.project, "art_contact_sheets", "%s_walk_layered_contact.png" % char),
        ], cell_w=150, cell_h=190)
        print("contact sheet", char, "walk layered")

    ride_cells_spec = {
        "riley": POSE_ORDER[:-1],   # riley set: 13 base + mount_wave
        "tasha": [p for p in POSE_ORDER if p != "mount_wave"],
    }
    for char, pose_list in ride_cells_spec.items():
        cells = []
        for pose in pose_list:
            recs = ride_cast.get(char, {}).get(pose, [])
            if not recs:
                cells.append((pose + " PENDING", None))
            else:
                for rec in recs:
                    label = pose if len(recs) == 1 else "%s %s" % (pose, rec["role"])
                    if pose in ("mount_wave", "hover_descend"):
                        label += " (1/2)"
                    cells.append((label, load_pack(rec["pack_png"].replace("art/frames/", ""))))
        make_contact(cells, 5, [
            os.path.join(args.pack, "art", "contact_sheets", "%s_ride_poses_contact.png" % char),
            os.path.join(args.project, "art_contact_sheets", "%s_ride_poses_contact.png" % char),
        ])
        print("contact sheet", char, "ride poses")

    print("SUMMARY ride_counts:", dict(ride_counts))
    print("SUMMARY walk_counts:", walk_counts)
    print("SUMMARY bound poses per cast:", {c: len(p) for c, p in ride_cast.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
