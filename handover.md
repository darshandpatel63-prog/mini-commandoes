# handover.md — continue in a new Claude chat

## Current state
| Field | Value |
|---|---|
| Phase | 1 (foundation) written as v0.0.2, **unverified**. Phase 0 verified on device (build #1). |
| Branch | `main` (owner pushes via unpack-bootstrap zip). Recommend `dev/*` branches from now on |
| Completed (static only) | docs, data files, repo validator, scaffold, workflow definitions |
| Incomplete | everything gameplay: Phases 1–10 |
| Known bugs | BUG-001 portrait orientation: fix written, awaiting device check |
| Known limitations | Phase 1 GDScript never executed (authoring sandbox has no Godot): expect possible parse/runtime errors on first CI run. Each CI debug APK has a new signing key: uninstall the old app before installing a new build |
| Latest successful build | CI run #1 (commit 0f04c1e), debug APK, installed on owner's phone |
| Latest failed build | none |
| GitHub Actions status | run #1 green; Phase 1 run pending |
| Latest test status | `validate_repo.py` pass (sandbox, incl. path + GDScript sanity checks). Godot unit tests ran green in CI run #1 (data tests only); the new Phase 1 tests have not run |
| Multiplayer test status | none |
| Android device test status | boot screen verified on one phone (portrait, build 1). Menus not yet seen |
| Current APK | none |
| Architecture | `blueprint.md` (host-authoritative ENet, data-driven, custom deterministic movement) |
| Important files | blueprint.md, CLAUDE.md, PROJECT.md, data/*.json, project.godot, export_presets.cfg, .github-staging/workflows/*.yml, tools/validate_repo.py, tests/run_tests.gd |
| Current priority | Phase 1 gate: build #2 installs, opens LANDSCAPE, menus navigate, settings/character selection persist across app restart |
| Next task | Read CI run result for v0.0.2; fix errors from the log; owner device-checks the list in README step 6; then start Phase 2 (core player: tile-grid movement, jetpack, touch controls) |
| Blocked | Android device testing needs the owner's phone |
| Temporary workarounds | Workflows live in `.github-staging/` until owner pastes them into `.github/workflows/` |
| Decisions | blueprint §0 D1–D8 |
| Asset status | no third-party assets; icon is placeholder; 3 generated UI sounds (tools/gen_audio.py) |
| Audio status | UI click/back/confirm only; need a human listen |
| Performance status | unmeasured |

# NEXT SESSION CHECKLIST
1. Read `CLAUDE.md`, this file, `PROJECT.md`; open `blueprint.md` only for the section you need.
2. Ask the owner for the latest Actions run result (or logs) of `CI`. Do not assume it passed.
3. If it failed: fix scripts/config from the log, give the complete changed file(s), re-run. If it passed: owner **uninstalls the old app**, installs the new APK and runs the device checklist (landscape, menu, Settings persist after force-close, Characters select persists, Back button, sounds).
4. Only after that checklist passes: mark BUG-001, G2, G3, G19 verified in `PROJECT.md` and start Phase 2.
5. Update `PROJECT.md` evidence and this file at the end of the session.
