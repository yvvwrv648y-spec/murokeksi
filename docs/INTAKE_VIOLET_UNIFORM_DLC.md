# INTAKE — Violet "Teal Mask" New Uniform Set DLC (re-send, 2026-11-25)

**Source:** Dropbox share link sent by Riley 2026-11-25 02:30 CST
(`Pokemon-Violet-DLC-The-Teal-Mask-New-Uniform-Set-1.rar`, rlkey df44mq9k…).
Downloaded detached + logged (`work/download.log`), completed in seconds.

## Identity (from the bytes)

- Archive: RAR 5, **121,737 B**, SHA-256 `3e9c06e71a77e735d8cdeb60f395b538411888c62cb88db661009ad552917538`
  (archive comment: "Uploaded By NXBrew.com").
- Contents: exactly ONE file — an NSP:
  `Pokemon Violet [DLC The Teal Mask + New Uniform Set] [01008F6008C5F001][v0].nsp`,
  **121,040 B**, SHA-256 `b84cf69e2002f550dc65037e849e70efa3d526db8e766673dfec516350c6ca31`.
- NSP (PFS0) holds 4 entries: a PublicData NCA (114,688 B), a Meta (cnmt) NCA (3,584 B),
  a ticket (.tik, rights ID …8C5F001…000F), and a certificate (.cert).
- **Title ID 01008F6008C5F001 — Type: AddOnContent (DLC), version v0** (the Meta NCA's own
  file is named `AddOnContent_01008f6008c5f001.cnmt`).

## Decryption verdict (proven pipeline, keys by path only)

This exact file was already decrypted and extracted by the Switch decryption lane in
`intake_dropbox_switch_2026-11-24/extracted/violet_uniform/` — and this re-send is
**byte-for-byte identical at both layers** (RAR SHA-256 and inner NSP SHA-256 both match
the held copy exactly), so the proven result carries over without re-running it:

- PublicData NCA opens with the held ticket titlekey (gen 14); its RomFS contains
  exactly ONE file: `keyfile.dat`, 16 B, SHA-256 `38113c36…`.
- Meta NCA opens with the held key-area key (keygen 15, `prod.keys_v22.5.0` set).

## What it actually is — plain verdict

**HELD COMPLETE — duplicate, nothing new.** This is the small "New Uniform Set"
entitlement stub for Pokémon Violet. Despite the words "The Teal Mask" in its file name,
**it contains no Teal Mask story DLC at all** — no Kitakami, no Ogerpon, no areas, no
game data beyond a 16-byte key file. It is the same unlocker class as the tiny Sword
Expansion Pass DLC stubs: the real DLC data lives in the base game + update on a system
that owns the entitlement.

**Relation to the Violet/Scarlet DLC picture:** unchanged. The real Hidden Treasure of
Area Zero content (Teal Mask / Kitakami + Indigo Disk / Blueberry) is still NOT held for
either Scarlet or Violet — v4.0.0 of Scarlet was proven to carry no DLC data, and this
stub adds none. This item also cannot serve Scarlet (it is Violet-title-bound).

## Files

- `downloads/violet_teal_mask_uniform.rar` — as downloaded (121,737 B).
- `extracted/…[01008F6008C5F001][v0].nsp` — extracted NSP (121,040 B), identical to the
  held copy in the Switch intake, which also holds the decrypted tree.
- Fetch list item 3 updated to SUPPLIED + VERIFIED + COMPLETE.
