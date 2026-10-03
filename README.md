# Mini Commandoes
Original 2D multiplayer commando action game (Godot 4.6.3, Android first). Start with `blueprint.md`; rules in `CLAUDE.md`; state in `PROJECT.md` / `handover.md`.

## Phone setup (taps only)
1. Create a GitHub repo (or use yours). Tap **Add file → Create new file**, name it `.github/workflows/unpack-bootstrap.yml`, paste the contents of `unpack-bootstrap.yml`, commit.
2. Tap **Add file → Upload files**, upload `mini-commandoes-repo.zip` to the repo root, commit.
3. **Actions → Unpack bootstrap zip → Run workflow.** It extracts the project and commits it.
4. Create `.github/workflows/ci.yml` (same way) and paste the contents of `ci.yml`. Commit.
5. **Actions → CI → Run workflow**, wait, open the run, download artifact `mini-commandoes-DEBUG-<n>` (APK). Allow "install unknown apps" for your browser/files app, install, open.
6. **Uninstall the previous Mini Commandoes first** (every CI build is signed with a new debug key; Android refuses to update in place), then install the new APK.
7. Device checklist for v0.0.3 (tell me pass/fail for each):
   - Landscape; boot goes to the main menu; About shows `v0.0.3`, "Base stats for every commando: HP 200, EP 100".
   - ARSENAL shows `Damage 14` (not 14.0); the first entry of every list looks selected.
   - CHARACTERS: no HP/skills listed, just identity; SELECT works.
   - LOADOUT: tap ACTIVE SKILL, PASSIVE 1-4, PET, PRIMARY, SECONDARY, MELEE, GRENADE; EQUIP works; try Triage + Energy Barrier (must be refused with a reason); try the same passive twice (refused); BUILD SUMMARY updates; force-close and reopen: build kept.
   - PRESETS: apply Assault/Defensive/Mobility/Support; type a name, SAVE CURRENT BUILD AS PRESET, change the build, LOAD it back, DELETE it.
   - COMBAT LAB: BODY SHOT / HEAD SHOT reduce HP; change HELMET/VEST LV and compare; HEALTH KIT, EP CELL, REPAIR KIT, ACTIVE SKILL, PET ABILITY; EP bar refills after about 2.5 s; shots interrupt an item in use; KNOCKDOWN ON shows DOWNED then death.
   - SETTINGS -> CUSTOMIZE HUD: drag buttons, tap one and change SIZE/FADE/SHOWN, TEST mode (buttons flash and vibrate), RESET, LAYOUT presets, SAVE; reopen: layout kept; CANCEL discards.
   - SETTINGS -> HAPTICS: master toggle/intensity, per-control presets, TEST each; tell me if Low/Medium/High feel different.
   - Android Back goes back; Back on the main menu closes the app.
8. If anything fails, send the Actions log or a screenshot.

This is a DEBUG build; there is no release build yet.
