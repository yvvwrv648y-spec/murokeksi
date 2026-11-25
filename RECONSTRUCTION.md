# RECONSTRUCTION — how this repo rebuilds the project

This repo holds the project's papers (docs/), the Neon page (FOR_NEON.md), and — landing
2026-11-25 in the named "Project files" commits — every TEXT file of the Godot project:
all code, scenes in text form, data files, and project papers. The project root in this
repo IS the project root: project.godot sits at the top, next to this file.

## What is here

- docs/ + FOR_NEON.md — the handover set (already here before the project files).
- 31143 project text files, 120,873,587 bytes, pushed in
  46 batches. Each batch is one commit named "Project files NN: <folder>".
  Limits of the upload route (2,000 files and 16 MiB of text per push) set the batch sizes.

| Batch | Commit name | Files | Bytes |
|---|---|---|---|
| 1 | Project files 01: (root) | 7 | 191,271 |
| 2 | Project files 02: art (part 1) | 1900 | 1,808,446 |
| 3 | Project files 03: art (part 2) | 1900 | 1,809,582 |
| 4 | Project files 04: art (part 3) | 1900 | 1,813,164 |
| 5 | Project files 05: art (part 4) | 1900 | 1,814,231 |
| 6 | Project files 06: art (part 5) | 1900 | 1,840,482 |
| 7 | Project files 07: art (part 6) | 1900 | 1,865,350 |
| 8 | Project files 08: art (part 7) | 1900 | 1,865,184 |
| 9 | Project files 09: art (part 8) | 1900 | 1,875,266 |
| 10 | Project files 10: art (part 9) | 1900 | 1,874,160 |
| 11 | Project files 11: art (part 10) | 1900 | 1,870,671 |
| 12 | Project files 12: art (part 11) | 1900 | 1,854,112 |
| 13 | Project files 13: art (part 12) | 427 | 418,752 |
| 14 | Project files 14: art_contact_sheets | 28 | 27,948 |
| 15 | Project files 15: art_frames (part 1) | 1900 | 1,873,856 |
| 16 | Project files 16: art_frames (part 2) | 1900 | 1,881,373 |
| 17 | Project files 17: art_frames (part 3) | 883 | 872,837 |
| 18 | Project files 18: art_samples | 11 | 10,416 |
| 19 | Project files 19: assets | 770 | 748,990 |
| 20 | Project files 20: audio | 1004 | 663,065 |
| 21 | Project files 21: battle | 65 | 1,390,481 |
| 22 | Project files 22: bridge_out | 7 | 5,944 |
| 23 | Project files 23: bridge_out2 | 7 | 5,927 |
| 24 | Project files 24: campaign | 14 | 1,520,780 |
| 25 | Project files 25: characters | 297 | 320,894 |
| 26 | Project files 26: core | 24 | 27,590 |
| 27 | Project files 27: data (part 1) | 81 | 14,729,222 |
| 28 | Project files 28: data (part 2) | 38 | 12,815,565 |
| 29 | Project files 29: data (part 3) | 14 | 11,448,235 |
| 30 | Project files 30: docs | 22 | 70,393 |
| 31 | Project files 31: fonts | 5 | 4,277 |
| 32 | Project files 32: interface | 20 | 17,556 |
| 33 | Project files 33: legacy_v031 | 9 | 28,404 |
| 34 | Project files 34: maps (part 1) | 558 | 14,947,212 |
| 35 | Project files 35: maps (part 2) | 708 | 14,991,648 |
| 36 | Project files 36: maps (part 3) | 632 | 13,539,608 |
| 37 | Project files 37: pokemon | 22 | 105,939 |
| 38 | Project files 38: regions | 11 | 25,025 |
| 39 | Project files 39: ride_v1 | 2 | 1,995 |
| 40 | Project files 40: scenes | 77 | 502,333 |
| 41 | Project files 41: shaders | 10 | 6,332 |
| 42 | Project files 42: systems | 330 | 5,372,720 |
| 43 | Project files 43: test_data | 1 | 97,954 |
| 44 | Project files 44: tests | 210 | 1,695,723 |
| 45 | Project files 45: tools | 60 | 150,195 |
| 46 | Project files 46: world | 89 | 72,479 |

## What is NOT here, and why

- **Every binary file** — 29192 files, 857,203,883 bytes in the
  project tree: sprite and picture files (.png and friends), sound and music (.ogg, .wav),
  fonts, and Godot's compiled resource files (.ctex, .stex, .res, the .pck packs).
  The upload route for this repo carries text only, so no binary can ride it.
- **Two data files that are text but too big for one push** (16 MiB cap):
  data/battle_anims_by_id.json (43,074,875 bytes) and data/encounters_1025.json
  (37,871,836 bytes). They belong at those exact paths in the tree.
- **The .godot/ editor cache** — not source; Godot rebuilds it on first import.
- **build/ outputs inside the tree** — stale export leftovers, replaced by the finale builds.
- **No ROMs, no game dumps, no key files** — never placed in this repo, by rule.

## Where the missing pieces live

- The complete project, binaries included, is in the full-project archive in Dropbox
  "/PUW Release" (the "Everything" volumes, each server-checked). That archive is the
  master copy of every binary at its exact project path.
- The finished builds (web, Windows, Linux — checked file by file; the Mac build failed
  on Bossy's machine and is not in this set) are being placed on public hosts by Bossy;
  the live link list is kept in FOR_NEON.md as each link lands.
- The two oversize data files above are in the same Dropbox archive, inside the project
  tree copy, at data/battle_anims_by_id.json and data/encounters_1025.json.

## Rebuild steps

1. Pull this repo. You now have the full text tree.
2. From the Dropbox "/PUW Release" archive, lay the binary files over the tree at their
   exact paths (pictures, sounds, fonts, compiled resources), and put the two oversize
   data files back in data/.
3. Open the folder in Godot 4.7.2 and let it import once. The project is whole again.
