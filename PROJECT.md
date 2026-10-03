# PROJECT.md — single source of truth (ledger, assumptions, status)

Engine decision: **Godot 4.6.3**, GDScript, gl_compatibility. Targets: Android arm64 first; desktop after V1 gate. License: MIT, no fees. Rejected: Unity (CI license activation, size), Unreal (heavy), native Kotlin (tooling cost). See `blueprint.md §0`.

## Status vocabulary
Planned → In progress → Implemented → Build verified → Runtime verified → Device verified → Network verified → Production ready.

## Requirement ledger (Android V1 acceptance, from owner prompt §54)
| ID | Requirement | Design | Impl | Test | Status |
|---|---|---|---|---|---|
| G1 | App installs + launches | bp §32 | export_presets.cfg, ci.yml | T10 | **Device verified** (debug build #1, commit 0f04c1e, screenshot from owner's phone: boot screen, Godot 4.6.3, all data counts correct) |
| G2 | App launches, main menu works | bp §5,24 | main_menu + 4 screens (0.0.2) | T9,T10 | Implemented (**not run yet**) |
| G3 | Character selection | bp §7 | characters_screen + SaveManager (0.0.2) | T4,T9 | Implemented (unit tests written, **not run**; screen not seen on device) |
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
| G17 | Audio | bp §25 | AudioManager + 3 generated UI sounds | T19 | In progress (UI sounds only; needs human listening) |
| G18 | UI works | bp §24 | theme + kit + base + 5 screens | T9 | In progress (menus only; HUD/controls Phase 2+) |
| G19 | Save system | bp §26 | save_io, profile_data, SaveManager | T4,T16 | Implemented (tests written, **not run**) |
| G20 | Android perf tested | bp §28 | — | T15 | Planned |
| G21 | GitHub Actions builds | bp §30 | ci.yml | T10 | **Build verified** (run #1 produced a debug APK that installed) |
| G22 | Release artifact generated | bp §31 | — | T10 | Planned |
| G23 | 5 maps, 40-player capacity, full content, polish | bp §17,19 | data stubs | T13,T14 | Planned |
| G24 | Bots (4 difficulties), modes (TDM/FFA/Control/Survival/Training) | bp §23,34 | modes data | T7 | Planned |

Extras (not requested): X1 kill streaks, X2 assists, X3 daily missions, X4 match stats — evaluated in bp §36, not yet committed.

## What exists now
| Item | Evidence | Status |
|---|---|---|
| Docs (blueprint, CLAUDE, handover, TEST_PLAN, ASSET_SOURCES, PROJECT) | `validate_repo.py` pass | Implemented |
| 8 data files (4 chars, 24 skills, 4 pets, 12 weapons, 7 throwables, 5 maps, 5 modes, loot) | validator pass; runtime counts seen on phone (build #1) | **Runtime verified (device)** |
| Boot scene, DataRegistry, Version stamping (build number + git sha) | phone screenshot: "v0.0.1 (build 1, 0f04c1e) Godot 4.6.3-stable (official)" | **Device verified** |
| CI: validate → import → headless tests → debug APK export | run #1 succeeded (artifact installed) | **Build verified** |
| Phase 1 (v0.0.2): Settings, SaveManager (atomic + backup + SHA-256), AudioManager + 3 generated UI sounds, SceneRouter (fade), InputRouter, GameState, UI theme/kit/base, Main menu, Settings, Characters, Browser (pets/skills/arsenal/maps), About | written; validator static checks pass (paths, brackets, indentation); **never run in Godot or on device** | Implemented, UNVERIFIED |
| Unit tests (data, save roundtrip/backup/tamper, settings validation/persistence, profile migrate) | written, **not run** (CI will run them) | Implemented |

## Placeholder tracker
| ID | Placeholder | Location | Replace by | Replaced? |
|---|---|---|---|---|
| P1 | Disabled menu buttons PLAY (Ph 6), LOADOUT (Ph 3), TRAINING (Ph 2), MISSIONS (later) | main_menu | matching phases | no |
| P2 | icon.svg | icon.svg | Phase 8 | no |
| P3 | Weapon/skill numbers unbalanced | data/*.json | Phase 9 playtests | no |
| P4 | Character art preview (text-only now) | characters_screen | rig, Phase 4 | no |
| P5 | Pets / Skills / Arsenal / Maps screens are INFO ONLY browsers | browser_screen | real screens as systems land | no |
| P6 | "Graphics quality" setting stored but not applied | settings | Phase 8/9 | no |
| P7 | Language fixed to English | settings | string tables, Phase 8 | no |

## Assumptions log
| # | Assumption | Reason | Reversible? |
|---|---|---|---|
| A1 | Godot 4.6.3 rather than newer 4.7.x | web search showed 4.6.3 (May 2026) and 4.7.x exist; 4.6.3 chosen as mature line | yes (bump pin) |
| A2 | Landscape-only, arm64-only | phone shooter, smaller APK | yes |
| A3 | Custom deterministic movement over tile grid | netcode + perf | costly after Phase 2 |
| A4 | Pets are non-combatants in v1 | simpler netcode | yes |
| A5 | Host migration out of scope v1 | complexity | yes |
| A6 | Art = authored SVG part rigs; audio = procedural | only workflow possible from phone, license-clean | quality risk (R4) |

| A7 | Debug APKs are signed with a fresh keystore per CI run, so each new build must be installed after **uninstalling** the previous one | CI generates the keystore | yes (store a debug keystore as a GitHub secret) |

## Bug template
`ID | Title | Severity | Repro | Expected | Actual | Status | Fix commit | Verification`

| ID | Title | Sev | Repro | Expected | Actual | Status | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| BUG-001 | App opens in portrait | Medium | Install build #1, hold phone upright | Landscape only (blueprint §32) | Portrait boot screen | Fix implemented in 0.0.2 (`window/handheld/orientation` 6 -> 4, sensor landscape; 6 meant "any") | pending commit | **Not verified** — needs build #2 on phone |


## Changelog
- 0.0.1 Phase 0: blueprint, rules, data, scaffold, CI definitions. Build #1 verified on device.
- 0.0.2 Phase 1: orientation fix (BUG-001), save/settings/audio/scene/input/game-state autoloads, UI theme + main menu + 4 functional screens, generated UI sounds, unit tests, validator path/GDScript checks, version-code stamping.
