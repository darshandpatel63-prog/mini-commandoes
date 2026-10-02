# Mini Commandoes
Original 2D multiplayer commando action game (Godot 4.6.3, Android first). Start with `blueprint.md`; rules in `CLAUDE.md`; state in `PROJECT.md` / `handover.md`.

## Phone setup (taps only)
1. Create a GitHub repo (or use yours). Tap **Add file → Create new file**, name it `.github/workflows/unpack-bootstrap.yml`, paste the contents of `unpack-bootstrap.yml`, commit.
2. Tap **Add file → Upload files**, upload `mini-commandoes-repo.zip` to the repo root, commit.
3. **Actions → Unpack bootstrap zip → Run workflow.** It extracts the project and commits it.
4. Create `.github/workflows/ci.yml` (same way) and paste the contents of `ci.yml`. Commit.
5. **Actions → CI → Run workflow**, wait, open the run, download artifact `mini-commandoes-DEBUG-<n>` (APK). Allow "install unknown apps" for your browser/files app, install, open.
6. Expected on screen: the MINI COMMANDOES title, version line, and counts (characters 4, skills 24, pets 4, weapons 12, throwables 7, maps 5, modes 5). That is only an infrastructure boot screen, not the game.
7. Send me the Actions log (or screenshot) if anything fails.

This is a DEBUG build; there is no release build yet.
