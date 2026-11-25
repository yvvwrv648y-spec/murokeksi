# PUW_TEST_PLAN.md
- **Status:** `IMPLEMENTED` (Static M0 Audit) / `BLOCKED` (Godot runtime & physical iPhone Safari tests)
- **Automated Suites:** `tests/run_m0_studio_audit.py` (JSON schemas, 16-doc completeness, Kanto register integrity, 6-ball hip rig contract, Omni Bracelet Kanto lock, master archive SHA-256).
- **Host-Required Suites (Godot 4.7.2 + Physical iPhone 17 Pro Max):** Headless GDScript parse/unit tests, Visual Acceptance Gate (15 items, video/frame-sequence), 60 FPS frame-time & thermal profiling on real iPhone Safari / native iOS.
