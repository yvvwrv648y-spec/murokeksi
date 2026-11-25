# INTAKE — Pokémon Scarlet "New Uniform Set" DLC (Riley-supplied, 2026-11-25)

Source: Dropbox share link sent by Riley 2026-11-25 02:30 CST (nswvault-sourced file).
Downloaded detached + resumable (log: `work/download.log`, CURL_EXIT=0).

## What arrived

- ZIP: `downloads/Pokemon-Scarlet-New-Uniform-Set-0100A3D008C5D001-v0-DLC-nswvault.com-.nsp.zip`
  — 122,184 B, SHA-256 `1226e98af17fe7de222232163e792bb97d656648079646068e86cb5adf544761`, ZIP CRC test PASS.
- Contents (3 files): the NSP below, a 237 B readme.txt, and a 46 B "Visit nswvault.com.url"
  shortcut file (junk; not opened, nothing in the archive was run).
- NSP: `Pokemon Scarlet [New Uniform Set] [0100A3D008C5D001][v0][DLC](nswvault.com).nsp`
  — 121,040 B, SHA-256 `1e2cacd1f1d70c594ce38cd90c36749265133c0ab88fde8bdd5819caccb01a9c`.

## Identity — proven from the file's own bytes, not its name

Decrypted with the proven in-house pipeline (`decrypt_work/extract_with_keys.py`, keys by path
only — `hidden_files/version_roms/keys/prod.keys_v22.5.0`; no key values recorded anywhere):

- PublicData NCA `de5e1900a5cea6e1552643b334a5d4ef.nca` — header title ID **0100A3D008C5D001**,
  content 114,688 B, rights-ID (ticket) present, titlekey generation 14 — DECRYPTED + extracted.
- Meta NCA `eb61e171a8a1265ca49147721f2340eb.cnmt.nca` — title ID 0100A3D008C5D001, DECRYPTED + extracted.
- CNMT (`AddOnContent_0100a3d008c5d001.cnmt`, 144 B): title ID 0100A3D008C5D001, **version 0**,
  type 0x82 = AddOnContent, and its content entry points at the Scarlet base title 0100A3D008C5C000.
- Verdict: the name's claim is TRUE — this is Scarlet DLC title ID 0100A3D008C5D001, version 0,
  and the held keys open it (the v22.5.0 key set is required: titlekey gen 14 / key-area gen 15
  are beyond the original prod.keys' generations 00–0A).
- Extracted tree: `extracted/decrypted/` (catalogue.json + the one data file below).

## What it actually is — plain statement

An entitlement-stub DLC, exactly like its Violet twin. Its entire data payload is one 16-byte
file, `keyfile.dat` (SHA-256 `38113c36d1f8eb3558d5868d285a7ddcba11128374fd2f13537255c351ea8c2f`).
It carries NO game content of its own.

**This is NOT the Teal Mask / Indigo Disk story DLC.** It does not contain Kitakami, Blueberry
Academy, their Pokémon, or any story data, and it does not close the Scarlet DLC gap — that gap
stands exactly as before. This file is only the small "New Uniform Set" unlock for Scarlet.

## Comparison vs the uniform DLC already held (01008F6008C5F001)

DIFFERENT item — the Scarlet-bound twin of the held Violet one:

| | This file | Held Violet uniform |
|---|---|---|
| Title ID (from bytes) | 0100A3D008C5D001 (Scarlet) | 01008F6008C5F001 (Violet) |
| NSP size / SHA-256 | 121,040 B / `1e2cacd1…` | 121,040 B / `b84cf69e…` |
| Structure | PublicData 114,688 B + Meta 3,584 B | identical sizes |
| keyfile.dat | `38113c36…` | `38113c36…` (byte-identical) |
| Decrypts with | prod.keys_v22.5.0 (gen 14/15) | prod.keys_v22.5.0 (gen 14/15) |

Same class, same shape, same stub payload — bound to the other game. The held Violet copy could
never serve Scarlet; this one is the Scarlet-side entitlement the fetch list had noted as owed.
That fetch-list note is now SUPPLIED + VERIFIED + EXTRACTED (fetch list updated 2026-11-25).
