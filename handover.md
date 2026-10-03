# handover.md — continue in a new Claude chat

## Current state
| Field | Value |
|---|---|
| Phase | 1 verified on device (build 28, v0.0.2). v0.0.3 design update written, **GDScript unrun**. |
| Branch | `main` (owner pushes via unpack-bootstrap zip). Recommend `dev/*` branches from now on |
| Completed (static only) | docs, data files, repo validator, scaffold, workflow definitions |
| Incomplete | everything gameplay: Phases 1–10 |
| Known bugs | BUG-001 fixed+verified. BUG-002/003 fixed in 0.0.3, unverified |
| Known limitations | Phase 1 GDScript never executed (authoring sandbox has no Godot): expect possible parse/runtime errors on first CI run. Each CI debug APK has a new signing key: uninstall the old app before installing a new build |
| Latest successful build | build 28 (commit 5ab9b16, v0.0.2), installed and screenshotted on owner's phone |
| Latest failed build | none |
| GitHub Actions status | build 28 green; v0.0.3 run pending |
| Latest test status | `validate_repo.py` pass (sandbox, incl. path + GDScript sanity checks). Godot unit tests ran green in CI run #1 (data tests only); the new Phase 1 tests have not run |
| Multiplayer test status | none |
| Android device test status | boot screen verified on one phone (portrait, build 1). Menus not yet seen |
| Current APK | none |
| Architecture | `blueprint.md` (host-authoritative ENet, data-driven, custom deterministic movement) |
| Important files | blueprint.md, CLAUDE.md, PROJECT.md, data/*.json, project.godot, export_presets.cfg, .github-staging/workflows/*.yml, tools/validate_repo.py, tests/run_tests.gd |
| Current priority | Get v0.0.3 green in CI (the vector-replay tests are the first real execution of the GDScript combat code), then device-check Loadout, Combat Lab, HUD editor, Haptics |
| Next task | Read CI log for v0.0.3; fix mismatches between GDScript and `tests/vectors/cases.json` (the reference model is the spec: if GDScript differs, fix GDScript; if a rule must change, change ref_model + vectors + docs together); owner runs README checklist; then Phase 2 (tile-grid movement, jetpack, real touch HUD using `HudLayout` + `ControlsManager.hud`) |
| Blocked | Android device testing needs the owner's phone |
| Temporary workarounds | Workflows live in `.github-staging/` until owner pastes them into `.github/workflows/` |
| Decisions | blueprint §0 D1–D8 |
| Asset status | no third-party assets; icon is placeholder; 3 generated UI sounds (tools/gen_audio.py) |
| Audio status | UI click/back/confirm only; need a human listen |
| Performance status | unmeasured |

## Design update summary (0.0.3)
Equal HP/EP, identity-only characters, player loadout with validation + presets, helmet/vest, DamagePipeline, EP, HUD editor, haptics, controls.json, host admission. Read `docs/combat.md`, `docs/loadout.md`, `docs/controls_haptics.md`, `docs/multiplayer_validation.md`, `docs/balance.md`. Rules are verified by `tools/ref_model.py` + `tools/gen_vectors.py` (hand-checked) and replayed by `tests/run_tests.gd`.
Known honesty points: behavior skills have no world effect yet; HUD editor is unverified on a phone; Android amplitude support is hardware-dependent; no network transport exists.

# NEXT SESSION CHECKLIST
1. Read `CLAUDE.md`, this file, `PROJECT.md`; open `blueprint.md` only for the section you need.
2. Ask the owner for the latest Actions run result (or logs) of `CI`. Do not assume it passed.
3. If it failed: fix scripts/config from the log, give the complete changed file(s), re-run. If it passed: owner **uninstalls the old app**, installs the new APK and runs the device checklist (landscape, menu, Settings persist after force-close, Characters select persists, Back button, sounds).
4. Only after that checklist passes: mark BUG-001, G2, G3, G19 verified in `PROJECT.md` and start Phase 2.
5. Update `PROJECT.md` evidence and this file at the end of the session.
