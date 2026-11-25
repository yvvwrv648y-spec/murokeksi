#!/usr/bin/env python3
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[4]
html = ROOT / "output" / "puw_kanto_studio_showcase.html"
mb = html.stat().st_size / (1024 * 1024)
assert mb <= 3.0, f"Showcase HTML too large for fast Canvas render: {mb:.2f} MB > 3.0 MB"
print(f"PASS: Performance Budget Suite (puw_kanto_studio_showcase.html = {mb:.2f} MB <= 3.0 MB)")
