# TEST_PLAN.md

Result line format: `[area] [what ran] [target] -> pass/fail (n issues)`. Evidence goes in `PROJECT.md`.

| # | Area | What | How | Where | Status |
|---|---|---|---|---|---|
| T1 | Static | Data integrity (ids, 1+4+1 skills, 5 maps ×40, rarity/backpack, distinct weapons), docs, secret scan, md fences, **res:// path integrity, required assets, GDScript indent/bracket sanity** | `python3 tools/validate_repo.py` | any / CI `validate` | **Run in sandbox: pass** (incl. 1 negative test) |
| T2 | Unit | Data registry loads; character slot rules | `godot --headless --script res://tests/run_tests.gd` | CI | Data tests passed in CI run #1; Phase 1 tests (save, settings, profile) written, **not yet run** |
| T3 | Unit | Damage/armor math, ModifierStack, inventory/backpack caps, rarity roll distribution | GDScript tests | CI | Planned (Phase 2–3) |
| T4 | Unit | Save atomic write, backup recovery, corruption, tamper, migration | GDScript tests | CI | Written, **not yet run** |
| T5 | Unit | Net protocol encode/decode, snapshot delta, quantization error bounds | GDScript tests | CI | Planned (Phase 6) |
| T6 | Gameplay | Scripted-input scenarios: jump height, jetpack fuel, reload timing, melee combo window, knockback | headless sim | CI | Planned (Phase 2) |
| T7 | Gameplay | Bot-vs-bot soak 30 min: no stuck states, no soft locks, no NaN | headless | CI | Planned (Phase 7) |
| T8 | Map | Reachability (walk+jet) for all loot/spawns; spawns not in solids | `tools/validate_maps.py` | CI | Planned (Phase 5) |
| T9 | UI | Every menu button works or is marked unavailable; touch targets ≥104 px; safe-area; landscape lock | manual on device (checklist in README) | device | Pending build #2 |
| T10 | Build | Debug APK exports; installs; launches; boot screen shows version + data counts | CI + phone | CI + device | **Pass** (build #1, one phone). Re-run for each build |
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

CI evidence (owner screenshot, v0.0.3 run): 1789 checks passed, 1 failed (BUG-004, since fixed). Device (D) column is still pending everywhere.

## Design-update tests (equal HP / EP / armor / loadout / HUD / haptics)
Evidence levels: **P** = executed in the authoring sandbox with the Python reference model (hand-checked numbers); **G** = GDScript test in `tests/run_tests.gd` replaying the same vectors (runs in CI; not yet run); **D** = needs a device.
| # | Requirement area | Test | P | G | D |
|---|---|---|---|---|---|
| T22 | Every character has the same base HP (and EP); characters identity-only | validator rejects gameplay keys; combatant per character has max HP 200 | pass | **pass in CI** | - |
| T23 | Character selection works | `SaveManager.select_character`, Characters screen | - | indirect | pending |
| T24 | Active skill selection; 4 passive slots; invalid combos rejected | 25 loadout vectors (5 passives, dup, budget, groups, excludes, wrong slot, hostile types) + every active/passive equippable | pass | **pass in CI** | pending (UI) |
| T25 | Skill changes actually affect results | Hardened Helm, Combat Conditioning, Reinforced Plating, Capacitor Bank, Quick Hands, caps; `pipeline` skills only (behavior skills are NOT simulated) | pass | **pass in CI** | Combat Lab |
| T26 | Pets pair with any character; pet abilities work | 4 chars x 4 pets valid; Bulwark shield and Biscuit heal scenarios; Pip/Talon are behavior-only (cost+cooldown) | pass | **pass in CI** | Combat Lab |
| T27 | EP display/changes/recovery/EP-HP rules | spend, delay, regen, Quick Charge, Capacitor, EP Cell, FULL refusal, Energy Mender conversion, barrier incl. EP-limited | pass | **pass in CI** | Combat Lab (bars) |
| T28 | Helmets, vests, levels, durability, armor never raises HP | sniper vs helmet L0/L1/L3, broken helmet, vest L3, armor_break, repair, max_hp stays 200 | pass | **pass in CI** | Combat Lab |
| T29 | Damage pipeline: head/body, armor, skills, shield, EP, HP, death/knockdown | 40 scenarios incl. knockdown->death, no-knockdown death, interrupt, cooldown | pass | **pass in CI** | Combat Lab |
| T30 | HUD move/resize/opacity/visibility/save/restore/reset | 9 HUD vectors (clamp, scale/opacity limits, required, insets, defaults, garbage), presets, persistence round-trip | pass (logic) | **pass in CI** | **editor UX pending** |
| T31 | Haptics master/per-control/intensity/persist | 10 vectors + persistence round-trip + sanitize | pass (logic) | **pass in CI** | **vibration feel pending; amplitude is hardware-dependent** |
| T32 | Multiplayer: injected stats rejected, loadouts validated | tampered claim ignored, hostile types, illegal armor/stacking | pass | **pass in CI** | - |
| T33 | Existing multiplayer not broken | no multiplayer exists yet | n/a | n/a | n/a |
| T34 | Static data invariants | `validate_repo.py` (equal stats, armor monotonic, skills, symmetric excludes, presets legal, HUD no overlap) + 3 negative tests | pass | - | - |

Human playtesting is separate from all automation and never replaced by it.
