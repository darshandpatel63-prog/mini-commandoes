# Mini Commandoes
Original 2D multiplayer commando action game (Godot 4.6.3, Android first). Start with `blueprint.md`; rules in `CLAUDE.md`; state in `PROJECT.md` / `handover.md`.

## Phone setup (taps only)
1. Create a GitHub repo (or use yours). Tap **Add file → Create new file**, name it `.github/workflows/unpack-bootstrap.yml`, paste the contents of `unpack-bootstrap.yml`, commit.
2. Tap **Add file → Upload files**, upload `mini-commandoes-repo.zip` to the repo root, commit.
3. **Actions → Unpack bootstrap zip → Run workflow.** It extracts the project and commits it.
4. Create `.github/workflows/ci.yml` (same way) and paste the contents of `ci.yml`. Commit.
5. **Actions → CI → Run workflow**, wait, open the run, download artifact `mini-commandoes-DEBUG-<n>` (APK). Allow "install unknown apps" for your browser/files app, install, open.
6. **Uninstall the previous Mini Commandoes first** (every CI build is signed with a new debug key; Android refuses to update in place), then install the new APK.
7. Device checklist for v0.0.2 (tell me pass/fail for each):
   - Opens in **landscape**; boot screen shows `v0.0.2 (build N, sha)` and `save: none`, then goes to the main menu by itself.
   - Main menu shows 11 buttons; PLAY, LOADOUT, MISSIONS, TRAINING are greyed out with a phase label (that is intended).
   - CHARACTERS: tap each commando, SELECT one other than Rook, force-close the app, reopen: the menu says your choice.
   - SETTINGS: change music/sfx +/-, FPS, vibration; force-close and reopen: values kept. Buttons click and vibrate.
   - PETS / SKILLS / ARSENAL / MAPS open and show details. ABOUT shows version, window size, engine license toggle.
   - Android Back button goes back to the menu; Back on the main menu closes the app.
8. If anything fails, send the Actions log or a screenshot.

This is a DEBUG build; there is no release build yet.
