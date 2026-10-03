# PROJECT.md — single source of truth (ledger, assumptions, status)

Engine decision: **Godot 4.6.3**, GDScript, gl_compatibility. Targets: Android arm64 first; desktop after V1 gate. License: MIT, no fees. Rejected: Unity (CI license activation, size), Unreal (heavy), native Kotlin (tooling cost). See `blueprint.md §0`.

## Status vocabulary
Planned → In progress → Implemented → Build verified → Runtime verified → Device verified → Network verified → Production ready.

## Requirement ledger (Android V1 acceptance, from owner prompt §54)
| ID | Requirement | Design | Impl | Test | Status |
|---|---|---|---|---|---|
| G1 | App installs + launches | bp §32 | export_presets.cfg, ci.yml | T10 | **Device verified** (debug build #1, commit 0f04c1e, screenshot from owner's phone: boot screen, Godot 4.6.3, all data counts correct) |
| G2 | App launches, main menu works | bp §5,24 | main_menu + screens | T9,T10 | **Device verified (partly)**: build 28 screenshots show landscape main menu with 11 buttons, Settings, Pets, Skills, Arsenal, Maps, Characters, About rendering on the owner's phone. Button taps beyond navigation and Android Back were not evidenced |
| G3 | Character selection | bp §7 | characters_screen + SaveManager | T23 | Device verified (screen renders, Rook shown SELECTED); **selecting another character + persistence after restart not evidenced**. Design changed in 0.0.3 (identity-only) so this must be re-checked on build 0.0.3 |
| G4 | ≥2 playable original characters | bp §7 | 4 identity-only characters, equal stats | T22 | Implemented (rules verified in Python reference; GDScript test pending CI). **Not playable yet** (no match simulation) |
| G5 | Active skills work | bp §9 | loadout + skill_exec + 8 actives (3 simulated) | T24,T25 | Implemented. Slot/validation: Python-verified. `pipeline` actives (Field Pulse, Energy Mender, Aegis Pulse) simulated in Combat Lab; the other 5 actives are `behavior` (EP/cooldown only) |
| G6 | Passive skills work | bp §9 | 4 passive slots + 22 passives | T24,T25 | Implemented. 9 passives `pipeline`, 3 `pending_stat`, 10 `behavior` — only `pipeline` ones change results today |
| G7 | Pet system works | bp §10 | pets not locked to characters, 4 pets | T26 | Implemented. Bulwark/Biscuit abilities simulated in Combat Lab; Pip/Talon are `behavior`; no pet entity yet |
| G8 | Weapons / shooting / reload | bp §8 | data only | T3,T6 | Planned |
| G9 | Melee | bp §15 | — | T6 | Planned |
| G10 | Grenades | bp §16 | data only | T6 | Planned |
| G11 | Health / EP / armor / damage pipeline | bp §13,39 | src/combat/* | T27,T28,T29 | Implemented. 40 scenarios hand-checked in the Python reference model; GDScript replay pending CI; **not device-verified** |
| G12 | Loot + backpack (3 levels) | bp §11,12 | data only | T3 | Planned |
| G13 | Jetpack | bp §14 | — | T6 | Planned |
| G14 | ≥2 complete maps (target 5) | bp §17 | data stubs | T8 | Planned |
| G15 | LAN host/join/hotspot + manual IP | bp §19–22 | — | T11,T12 | Planned |
| G16 | Match start/end/respawn/score | bp §34 | — | T6,T12 | Planned |
| G17 | Audio | bp §25 | AudioManager + 3 generated UI sounds | T19 | In progress (UI sounds only; needs human listening) |
| G18 | UI works | bp §24 | theme + kit + base + 11 screens | T9 | In progress (menus verified on device up to build 28; Loadout/HUD editor/Haptics/Combat Lab are new in 0.0.3, unverified) |
| G19 | Save system | bp §26 | save_io, profile v2, controls.json | T4,T16 | Implemented. CI run for build 28 passed its unit tests (inferred: export runs after tests); **restart persistence not evidenced on device** |
| G20 | Android perf tested | bp §28 | — | T15 | Planned |
| G21 | GitHub Actions builds | bp §30 | ci.yml | T10 | **Build verified** (run #1 produced a debug APK that installed) |
| G22 | Release artifact generated | bp §31 | — | T10 | Planned |
| G23 | 5 maps, 40-player capacity, full content, polish | bp §17,19 | data stubs | T13,T14 | Planned |
| G24 | Bots (4 difficulties), modes (TDM/FFA/Control/Survival/Training) | bp §23,34 | modes data | T7 | Planned |
| G25 | Equal base HP for all characters | bp §7,13 | balance.json base_hp 200; identity-only characters | T22 | Implemented (validator + vectors) — Python-verified |
| G26 | EP system (separate from HP, recovery, interactions) | bp §39 | vitals.gd, skills | T27 | Implemented — Python-verified; not device-verified |
| G27 | Player-controlled skill loadout (1 active + 4 passive) with browser, categories, previews, equip/unequip, validation, presets | bp §9,40 | loadout_* , picker, loadout screen | T24 | Implemented — validation Python-verified; UI unverified on device |
| G28 | Pets selectable independent of character | bp §10 | picker + validator | T26 | Implemented — unverified on device |
| G29 | Helmet + vest system (levels, durability, break) | bp §13 | armor.json, damage_pipeline | T28 | Implemented — Python-verified; visual damage feedback on the rig **Planned** (Phase 4) |
| G30 | Centralized damage pipeline | bp §13 | damage_pipeline.gd | T29 | Implemented — Python-verified |
| G31 | Healing/recovery limited and validated | bp §13 | vitals.gd | T27 | Implemented — Python-verified |
| G32 | Complete loadout screen + presets (4 built-in, 6 custom) | bp §40 | loadout_screen | T24 | Implemented — unverified on device |
| G33 | HUD customization (move/size/opacity/visibility/reset/layouts) + editor | bp §41 | hud_layout, hud_editor | T30 | Implemented — logic Python-verified; **editor drag UX unverified on a phone**; the real in-match HUD does not exist yet (layout is saved for it) |
| G34 | Per-control haptics (master, per control, presets, strength, length) | bp §41 | haptic_config, haptics_screen | T31 | Implemented — logic Python-verified; **vibration feel unverified; amplitude is hardware-dependent (documented)** |
| G35 | All customization persists, versioned, migratable | bp §26 | profile v2 + controls v1 | T4,T30,T31 | Implemented (v1->v2 migration tested in Python-model-independent GDScript tests, pending CI) |
| G36 | Multiplayer fairness: client cannot inject stats; loadouts validated | bp §42 | authority.gd | T32 | Implemented as pure logic (Python-verified); **no network transport yet** |
| G37 | Docs updated | — | blueprint, CLAUDE, handover, TEST_PLAN, docs/*.md | — | Done |

Extras (not requested): X1 kill streaks, X2 assists, X3 daily missions, X4 match stats — evaluated in bp §36, not yet committed.

## What exists now
| Item | Evidence | Status |
|---|---|---|
| Docs | validator pass | Implemented |
| Data model (equal HP/EP, armor, melee, 34 skills, 4 pets, presets, HUD defaults) | `validate_repo.py` pass + 3 negative tests; `gen_vectors.py` hand-checked | Build verified (static) |
| Build #1 (v0.0.1) boot screen | screenshot, commit 0f04c1e | **Device verified** |
| Build #28 (v0.0.2, commit 5ab9b16): landscape main menu, Settings, Characters, Pets, Skills, Arsenal, Maps, About | 10 owner screenshots, 2400x1080 landscape | **Device verified (rendering)**; BUG-001 fixed |
| CI: validate -> import -> headless tests -> debug APK | run for build 28 produced an APK, so its tests passed | **Build verified** |
| v0.0.3 design update: combat core, loadout, picker, presets, HUD editor, haptics, Combat Lab, authority | written; reference model executed in sandbox (40 scenarios, 8 stat, 25 loadout, 4 authority, 10 haptics, 9 HUD, all hand-asserted); static GDScript checks pass; **GDScript never executed (no Godot in sandbox)** | Implemented, UNVERIFIED in Godot/device |

## Placeholder tracker
| ID | Placeholder | Location | Replace by | Replaced? |
|---|---|---|---|---|
| P1 | Disabled menu buttons PLAY (Ph 6), TRAINING (Ph 2), MISSIONS (later) | main_menu | matching phases | no (LOADOUT now functional) |
| P2 | icon.svg | icon.svg | Phase 8 | no |
| P3 | Weapon/skill numbers unbalanced | data/*.json | Phase 9 playtests | no |
| P4 | Character art preview (text-only now) | characters_screen | rig, Phase 4 | no |
| P5 | Skills / Arsenal / Maps screens are INFO ONLY browsers (Pets + slot pickers are functional) | browser_screen | real screens as systems land | no |
| P8 | In-match HUD does not exist: HUD editor edits a preview, layout stored for Phase 2 | hud_editor | Phase 2 touch controls | no |
| P9 | `behavior` / `pending_stat` skills have no world effect yet; helmet/vest visuals absent | skills | Phase 2-4 | no |
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
| BUG-001 | App opens in portrait | Medium | Install build #1, hold phone upright | Landscape only (blueprint §32) | Portrait boot screen | Fixed in 0.0.2 (`orientation` 6 -> 4) | build 28 | **Verified**: build 28 screenshots are 2400x1080 landscape |
| BUG-002 | Numbers shown as `14.0` | Low | Arsenal -> Vanguard AR-7 | `14` | `Damage 14.0` | Fixed in 0.0.3 (`UIKit.num`) | 0.0.3 | **Not verified** |
| BUG-003 | First list entry not highlighted when screen opens | Low | Pets / Skills screens | selected entry highlighted | detail shown but first button not pressed-looking | Fixed in 0.0.3 (first button pressed) | 0.0.3 | **Not verified** |


## Changelog
- 0.0.1 Phase 0: blueprint, rules, data, scaffold, CI definitions. Build #1 verified on device.
- 0.0.3 Design update (owner document): equal base HP 200 + EP 100, identity-only characters, shared skill pool with player loadout (1 active + 4 passives), free pet choice, helmet/vest armor, centralized damage pipeline, separate HP/EP recovery, loadout screen + presets, HUD editor, per-control haptics, versioned persistence (profile v2, controls v1), host-side admission, Combat Lab, reference model + vectors, docs. **Supersedes** the per-character skills/pets/HP of 0.0.1-0.0.2 (their screenshots showing HP 130 etc. are obsolete).
- 0.0.2 Phase 1: orientation fix (BUG-001), save/settings/audio/scene/input/game-state autoloads, UI theme + main menu + 4 functional screens, generated UI sounds, unit tests, validator path/GDScript checks, version-code stamping.
