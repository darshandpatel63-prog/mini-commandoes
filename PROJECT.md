# PROJECT.md — single source of truth (ledger, assumptions, status)

Engine decision: **Godot 4.6.3**, GDScript, gl_compatibility. Targets: Android arm64 first; desktop after V1 gate. License: MIT, no fees. Rejected: Unity (CI license activation, size), Unreal (heavy), native Kotlin (tooling cost). See `blueprint.md §0`.

## Status vocabulary
Planned → In progress → Implemented → Build verified → Runtime verified → Device verified → Network verified → Production ready.

## Requirement ledger (Android V1 acceptance, from owner prompt §54)
| ID | Requirement | Design | Impl | Test | Status |
|---|---|---|---|---|---|
| G1 | App installs | bp §32 | export_presets.cfg, ci.yml | T10 | Implemented (config only; **not built**) |
| G2 | App launches, main menu works | bp §5,24 | boot scene only | T9,T10 | Planned (boot screen is a **UI PLACEHOLDER**) |
| G3 | Character selection | bp §7 | data only | T9 | Planned |
| G4 | ≥2 playable original characters | bp §7 | data only (4 defined) | T6 | Planned |
| G5 | Active skills work | bp §9 | data only | T3,T6 | Planned |
| G6 | Passive skills work | bp §9 | data only | T3 | Planned |
| G7 | Pet system works | bp §10 | data only | T6 | Planned |
| G8 | Weapons / shooting / reload | bp §8 | data only | T3,T6 | Planned |
| G9 | Melee | bp §15 | — | T6 | Planned |
| G10 | Grenades | bp §16 | data only | T6 | Planned |
| G11 | Health/armor | bp §13 | — | T3 | Planned |
| G12 | Loot + backpack (3 levels) | bp §11,12 | data only | T3 | Planned |
| G13 | Jetpack | bp §14 | — | T6 | Planned |
| G14 | ≥2 complete maps (target 5) | bp §17 | data stubs | T8 | Planned |
| G15 | LAN host/join/hotspot + manual IP | bp §19–22 | — | T11,T12 | Planned |
| G16 | Match start/end/respawn/score | bp §34 | — | T6,T12 | Planned |
| G17 | Audio | bp §25 | — | T19 | Planned |
| G18 | UI works | bp §24 | — | T9 | Planned |
| G19 | Save system | bp §26 | — | T4,T16 | Planned |
| G20 | Android perf tested | bp §28 | — | T15 | Planned |
| G21 | GitHub Actions builds | bp §30 | ci.yml | T10 | Implemented (**never run**) |
| G22 | Release artifact generated | bp §31 | — | T10 | Planned |
| G23 | 5 maps, 40-player capacity, full content, polish | bp §17,19 | data stubs | T13,T14 | Planned |
| G24 | Bots (4 difficulties), modes (TDM/FFA/Control/Survival/Training) | bp §23,34 | modes data | T7 | Planned |

Extras (not requested): X1 kill streaks, X2 assists, X3 daily missions, X4 match stats — evaluated in bp §36, not yet committed.

## What exists now (Phase 0)
| Item | Evidence | Status |
|---|---|---|
| blueprint, CLAUDE, handover, TEST_PLAN, ASSET_SOURCES docs | files exist; `validate_repo.py` pass | Implemented |
| 8 data files (4 chars, 24 skills, 4 pets, 12 weapons, 7 throwables, 5 maps, 5 modes, loot) | `validate_repo.py` pass (+negative test caught a broken character) | Build verified (static only) |
| Godot project skeleton (`project.godot`, autoloads, boot scene, test runner) | **never opened in Godot** — no engine in authoring sandbox | Implemented, UNVERIFIED |
| `export_presets.cfg` | option names from Godot docs; **not exported yet** | Implemented, UNVERIFIED |
| `ci.yml`, `unpack-bootstrap.yml` | YAML parses; **never run on GitHub** | Implemented, UNVERIFIED |

## Placeholder tracker
| ID | Placeholder | Location | Replace by | Replaced? |
|---|---|---|---|---|
| P1 | Boot screen stands in for main menu | scenes/boot | Phase 1/8 | no |
| P2 | icon.svg | icon.svg | Phase 8 | no |
| P3 | Weapon/skill numbers unbalanced | data/*.json | Phase 9 playtests | no |

## Assumptions log
| # | Assumption | Reason | Reversible? |
|---|---|---|---|
| A1 | Godot 4.6.3 rather than newer 4.7.x | web search showed 4.6.3 (May 2026) and 4.7.x exist; 4.6.3 chosen as mature line | yes (bump pin) |
| A2 | Landscape-only, arm64-only | phone shooter, smaller APK | yes |
| A3 | Custom deterministic movement over tile grid | netcode + perf | costly after Phase 2 |
| A4 | Pets are non-combatants in v1 | simpler netcode | yes |
| A5 | Host migration out of scope v1 | complexity | yes |
| A6 | Art = authored SVG part rigs; audio = procedural | only workflow possible from phone, license-clean | quality risk (R4) |

## Bug template
`ID | Title | Severity | Repro | Expected | Actual | Status | Fix commit | Verification` — none logged yet.

## Changelog
- 0.0.1 Phase 0: blueprint, rules, data, scaffold, CI definitions.
