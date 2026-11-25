# Neon Handover — File Split Plan (for in-chat delivery at endgame close)

**DRAFT — prepared 2026-11-24 by Bossy.** Riley's deal: at endgame close the Neon handover files are delivered **in this chat**, split into proper files Gemini Neon can handle, with the massive archive in both clouds as the bulk channel. This plan defines the split so the close-out delivery is mechanical.

## Principles
- Every delivered file is **self-contained**: it opens with a 5-line header (what it is, package version/date, what it pairs with, where the full record lives in the archive) so any single file still makes sense if forwarded alone.
- **Size cap: ~32 KB per chat file** (comfortable for chat paste/attach and for Gemini ingestion). Anything larger is split at a section boundary, never mid-table.
- **Order is numbered** (`00_`, `01_`, …) so reassembly is unambiguous; a manifest with SHA-256 per file closes the set.
- Drafts live in `hidden_files/release_staging/neon_handover_draft/`; at close, refreshed finals are copied to `files/` for delivery and the draft folder is kept as the working copy.

## The split (from HANDOVER.md + GEMINI_ASSEMBLY_PROMPT.md)

| # | Chat file | Contents (source) | Est. size |
|---|---|---|---|
| 00 | `00_README_INDEX.md` | Package map, reading rules (QA gate, BW2 floor, English-only, honesty labels), cloud links + folder ids, manifest pointer | ~4 KB |
| 01 | `01_HANDOVER_state_of_the_game.md` | HANDOVER §1 (game in one page) + §2.1–2.2 (build 6 certified, build 7 stages 0–8) | ~14 KB |
| 02 | `02_HANDOVER_accomplishments.md` | HANDOVER §2.3–2.7 (remainders burn-down, systems audit, animation programs, exploitation closures, Everything Archive) | ~14 KB |
| 03 | `03_HANDOVER_partials_remaining.md` | HANDOVER §3 (partials table) + §4 (remaining programs) + §5 (not started) | ~16 KB |
| 04 | `04_HANDOVER_missing_and_sources.md` | HANDOVER §6 (genuinely missing) + §8 (exact source locations) | ~12 KB |
| 05 | `05_OPEN_ASKS_NEON.md` | HANDOVER §7 complete (R1 remainder, crosswalk, §7 six views, redraw Waves 2+, dive slots) + §9 directions | ~12 KB |
| 06 | `06_GEMINI_ASSEMBLY_PROMPT.md` | GEMINI_ASSEMBLY_PROMPT.md §§1–3 (inputs, rules, first verification jobs incl. boot-and-play) | ~14 KB |
| 07 | `07_GEMINI_CONTINUATION.md` | GEMINI_ASSEMBLY_PROMPT.md §§4–6 (Stage 9 + fold-ins, exports, region binds, art queue, reporting) | ~10 KB |
| 08 | `08_MANIFEST.sha256` | SHA-256 + byte size for files 00–07, generated at delivery time | ~1 KB |

Total delivered set: 9 files, ~97 KB of text — the complete handover, with all bulk material referenced by archive volume + path instead of embedded.

## What refreshes at endgame close (mechanical checklist)
1. **Build 7 Stage 9 outcome** — battery tallies + build 7 package identity (zip bytes/SHA/entries, split proof) into files 01 + 06; if Stage 9 has not run, file 01 keeps it as the top partial and file 06 keeps it as continuation job #1.
2. **Exports verdicts** — EXPORTS_REPORT.md per-target results (web/Windows/iOS-recipe/Godot project, sizes + hashes, fps profiling) into files 01 + 03.
3. **Upload completion** — per-cloud per-volume verified inventory (V01–V09) from the two state logs into files 00 + 03; any volume not verified stays listed as pending with its last log line quoted.
4. **Switch intake finals** — Scarlet base + v4.0.0 verdicts (sizes, SHAs, title IDs, the DLC-data question answered from bytes) and Sword update v1.3.2 verdict into file 03; Sword base link status into file 04.
5. **QA pass 38 remainder** — tranche-3 adoption grade when it lands, into file 03.
6. **Neon fold-in lane closure** — final follower parity figure if it moves past 626/785, into file 01.
7. **Usage/endgame state** — final pool figure + which thresholds fired, one line in file 00.
8. Regenerate `08_MANIFEST.sha256` last, after all edits; re-verify each split file against its source section (headings diff) before delivery.

## Delivery sequence at close
Files are attached to chat in numeric order, one message per file (00 first, 08 last), each message carrying only the file + its one-line description. If any file exceeds the cap after refresh, it splits at the nearest section boundary and the manifest gains a row — the numbering never reuses a retired slot (use `03a_`, `03b_`).
