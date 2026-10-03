# ASSET_SOURCES.md

Record **before** committing any asset. Release is blocked while a required placeholder remains.

| Asset | Type | Source | License | Commercial use | Attribution | Redistribution | Modification | Ships? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `icon.svg` | icon | Original, authored by Claude in this project | Project-owned (owner's choice of license) | yes | none | n/a | yes | yes | Simple placeholder mark; **replace** with final identity (P2) |
| Godot Engine 4.6.3 + export templates | engine | godotengine.org | MIT | yes | MIT notice must be included in credits/About | yes | yes | yes (runtime in APK) | Add MIT notice screen in Phase 8 |
| `assets/audio/sfx/ui_click.wav`, `ui_back.wav`, `ui_confirm.wav` | audio | Original, synthesized by `tools/gen_audio.py` (sine/noise recipes, seed 1234) | Project-owned | yes | none | n/a | yes | yes | UI placeholders; need human listening review |
| `data/*.json` content (names, stats) | data | Original | Project-owned | yes | none | n/a | yes | yes | Names/weapons are invented; do a trademark quick-check before release (A5) |

No third-party art, audio, fonts, or code are included. No Mini Militia material is used or consulted as a source of assets.

Planned original asset pipelines (not yet created): SVG body-part rigs (`assets/art`), procedural audio (`tools/gen_audio.py`), OFL font (to be recorded here with license text when chosen).
