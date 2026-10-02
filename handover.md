# handover.md — continue in a new Claude chat

## Current state
| Field | Value |
|---|---|
| Phase | 0 complete as files; **not yet pushed to GitHub, not yet built** |
| Branch | none yet (create `main`, then `dev/phase1-foundation`) |
| Completed (static only) | docs, data files, repo validator, scaffold, workflow definitions |
| Incomplete | everything gameplay: Phases 1–10 |
| Known bugs | none logged (nothing has run in Godot) |
| Known limitations | Godot scripts/scene/export preset never opened in Godot; CI never executed; Godot version/URLs/SDK pins from web docs, not tested |
| Latest successful build | none |
| Latest failed build | none |
| GitHub Actions status | not run |
| Latest test status | `validate_repo.py` pass (sandbox). Godot tests not run |
| Multiplayer test status | none |
| Android device test status | none |
| Current APK | none |
| Architecture | `blueprint.md` (host-authoritative ENet, data-driven, custom deterministic movement) |
| Important files | blueprint.md, CLAUDE.md, PROJECT.md, data/*.json, project.godot, export_presets.cfg, .github-staging/workflows/*.yml, tools/validate_repo.py, tests/run_tests.gd |
| Current priority | Get the first CI debug APK building and booting on the phone (Phase 1 gate) |
| Next task | Fix whatever the first CI run reports (expected: export preset option names, editor settings path), then Phase 1 foundation |
| Blocked | Android device testing needs the owner's phone |
| Temporary workarounds | Workflows live in `.github-staging/` until owner pastes them into `.github/workflows/` |
| Decisions | blueprint §0 D1–D8 |
| Asset status | no third-party assets; icon is placeholder |
| Audio status | none yet (generator planned) |
| Performance status | unmeasured |

# NEXT SESSION CHECKLIST
1. Read `CLAUDE.md`, this file, `PROJECT.md`; open `blueprint.md` only for the section you need.
2. Ask the owner for the latest Actions run result (or logs) of `CI`. Do not assume it passed.
3. If it failed: fix `ci.yml` / `export_presets.cfg` / scripts using the log, give the complete changed file(s), re-run. If it passed: owner installs the debug APK and reports whether the boot screen shows version + counts (7 table lines).
4. Only after the boot screen is confirmed on a phone: mark G1/G21 `Device verified` and start Phase 1 (GameState, InputRouter, AudioManager, SaveManager, SceneRouter, UI theme, main menu skeleton).
5. Update `PROJECT.md` evidence and this file at the end of the session.
