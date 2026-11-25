# Fonts in this staged project

Spec (MENU_AUDIT_AND_REBUILD_SPEC §3.0): bundle one rounded/grotesque
sans with true bold, SIL OFL or equivalent $0 license; first choice
"M PLUS Rounded 1c", fallback "Nunito". Nothing below 16 px ships.

Staged here:

- `MPLUSRounded1c-Medium.ttf` (3,423,112 B) and
  `MPLUSRounded1c-Bold.ttf` (3,532,960 B) — M PLUS Rounded 1c, the
  spec's first choice, © the M+ Fonts project, SIL Open Font
  License 1.1. Downloaded from Google Fonts during this lane
  (resume-assembled through the flaky proxy, verified by TTF magic
  + size, and confirmed rendering in the QA screenshots). These
  are the full CJK builds; a latin-subset build would slim the
  pack and is a binding-build option, not a requirement.
- `NotoSans-Regular.ttf` (512,672 B) and `NotoSans-Bold.ttf`
  (515,752 B) — Noto Sans, © Google, SIL Open Font License 1.1,
  kept as the fallback.

PUWUiTheme's font loader prefers, in order:

1. `MPLUSRounded1c-Medium.ttf` / `MPLUSRounded1c-Bold.ttf`
2. `NotoSans-Regular.ttf` / `NotoSans-Bold.ttf`

Adoption: copy this folder as-is; keep an OFL license text beside
the fonts in the pack credits.
