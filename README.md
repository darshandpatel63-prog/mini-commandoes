# Mini Commandoes
Original 2D multiplayer commando action game (Godot 4.6.3, Android first). Start with `blueprint.md`; rules in `CLAUDE.md`; state in `PROJECT.md` / `handover.md`.

## Phone setup (taps only)
1. Create a GitHub repo (or use yours). Tap **Add file → Create new file**, name it `.github/workflows/unpack-bootstrap.yml`, paste the contents of `unpack-bootstrap.yml`, commit.
2. Tap **Add file → Upload files**, upload `mini-commandoes-repo.zip` to the repo root, commit.
3. **Actions → Unpack bootstrap zip → Run workflow.** It extracts the project and commits it.
4. Create `.github/workflows/ci.yml` (same way) and paste the contents of `ci.yml`. Commit.
5. **Actions → CI → Run workflow**, wait, open the run, download artifact `mini-commandoes-DEBUG-<n>` (APK). Allow "install unknown apps" for your browser/files app, install, open.
6. **Uninstall the previous Mini Commandoes first** (every CI build is signed with a new debug key; Android refuses to update in place), then install the new APK.
7. Device checklist for v0.0.4 (tell me pass/fail):
   - Main menu: TRAINING is enabled. CHARACTERS shows a baked portrait for each commando (4 colorways) and no "placeholder" note.
   - TRAINING: your commando appears in landscape with the left stick (move), right stick (aim + fire), buttons from your saved HUD layout.
   - Walk, jump, crouch (tap Crouch or pull the stick down), hold Jetpack: fuel bar (orange) drains and refills, "JET COOLING" shows when empty.
   - Aim with the right stick: arm + rifle rotate, shots hit the dummies (numbers float up; head shots show more; armor "BREAK" appears), reload button works.
   - Skill / Pet / Heal / EP buttons show a message; Melee hits a dummy next to you.
   - EXIT or Android Back returns to the menu.
   - Report anything that feels wrong: stick dead zone, sprite too small/large, stuck on platforms, jitter.
8. If anything fails, send the Actions log or a screenshot.

This is a DEBUG build; there is no release build yet.
