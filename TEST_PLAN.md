# TEST_PLAN.md

Result line format: `[area] [what ran] [target] -> pass/fail (n issues)`. Evidence goes in `PROJECT.md`.

| # | Area | What | How | Where | Status |
|---|---|---|---|---|---|
| T1 | Static | Data integrity (ids, 1+4+1 skills per character, 5 maps ×40, rarity/backpack tables, weapons distinct), docs present, secret scan, md fences | `python3 tools/validate_repo.py` | any / CI `validate` | **Run in sandbox: pass** (incl. 1 negative test) |
| T2 | Unit | Data registry loads; character slot rules | `godot --headless --script res://tests/run_tests.gd` | CI | Planned (not yet run — no Godot in authoring sandbox) |
| T3 | Unit | Damage/armor math, ModifierStack, inventory/backpack caps, rarity roll distribution | GDScript tests | CI | Planned (Phase 2–3) |
| T4 | Unit | Save atomic write, backup recovery, corruption, migration | GDScript tests | CI | Planned (Phase 1) |
| T5 | Unit | Net protocol encode/decode, snapshot delta, quantization error bounds | GDScript tests | CI | Planned (Phase 6) |
| T6 | Gameplay | Scripted-input scenarios: jump height, jetpack fuel, reload timing, melee combo window, knockback | headless sim | CI | Planned (Phase 2) |
| T7 | Gameplay | Bot-vs-bot soak 30 min: no stuck states, no soft locks, no NaN | headless | CI | Planned (Phase 7) |
| T8 | Map | Reachability (walk+jet) for all loot/spawns; spawns not in solids | `tools/validate_maps.py` | CI | Planned (Phase 5) |
| T9 | UI | Every menu button works or is marked unavailable; touch targets ≥104 px; safe-area | scripted UI walk + manual | CI + device | Planned (Phase 8) |
| T10 | Build | Debug APK exports; installs; launches; boot screen shows version + data counts | CI + phone | CI + device | **Not yet run** |
| T11 | LAN | Discovery on home Wi-Fi, hotspot host, client isolation case; manual IP fallback | 2+ phones | device | Planned (Phase 6) |
| T12 | Network | Prediction/reconciliation under 50–200 ms, 5% loss (netem-style sim), disconnect/rejoin | sim + devices | CI + device | Planned |
| T13 | **SIMULATED 40 PLAYER TEST** | 40 simulated clients/bots on loopback: tick time, bandwidth/client, drops | `tools/sim_stress.gd` | CI `stress` | Planned (Phase 9) |
| T14 | **REAL 40 DEVICE PLAYER TEST** | 40 physical devices | humans | field | Not planned yet; required before claiming "40 players supported" |
| T15 | Device perf | FPS/frame-time/RAM/battery/thermal on Low/Mid/High phone, per profile | Godot monitors + manual | 3 phones | Planned (Phase 9) |
| T16 | Save | Kill app mid-save; corrupt file; upgrade over old version | manual + unit | device | Planned |
| T17 | Lifecycle | Call/background/resume/rotate/low battery/low storage | manual | device | Planned |
| T18 | Soak | 60 min play: no crash, no memory growth | manual/bot | device | Planned |
| T19 | Audio | All required SFX/music present, no clipping, loop seams, bus volumes | script + listening | CI + human | Planned |
| T20 | Regression | Re-run T1–T9 on every merge to `main` | CI | CI | Planned |
| T21 | Security/QA | Cheat attempts vs host: speed, fire rate, cooldown, ammo, oversized packets | scripted client | CI | Planned (Phase 6) |

Human playtesting is separate from all automation and never replaced by it.
