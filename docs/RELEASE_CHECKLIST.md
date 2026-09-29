# Release Checklist

## Versioning rules

- `BuildInfo.VERSION` (`scripts/data/build_info.gd`) and `application/config/version` in `project.godot` must match; the test suite enforces it. Export presets carry the same version string.
- **MAJOR**: incompatible gameplay/data resets. **MINOR**: content drops or features. **PATCH**: fixes that keep network compatibility.
- `BuildInfo.PROTOCOL_VERSION` increments whenever RPC signatures, snapshot fields, or content IDs change in a way older clients cannot interpret. Lobbies only match equal protocol strings.
- Lobby `build` metadata uses the Steam depot build ID when available and falls back to `VERSION` in development, so mismatched builds never see each other.
- The Steam App ID is `480` unless `WINTERMAUL_STEAM_APP_ID` is set in the build environment. Real Steam builds must set it and must not ship `steam_appid.txt`.

## Release candidate checklist

### Source and import
- [ ] Working tree is clean; `.godot/` is not committed.
- [ ] `godot --headless --path . --import` completes with no errors or class-cache warnings.
- [ ] `godot --headless --path . --script res://tests/run_tests.gd` prints `PASS`.
- [ ] `godot --path . --script res://tests/visual_smoke.gd` runs windowed with no script errors and fps above the floor.
- [ ] `docs/ASSET_LICENSES.md` lists every distributed font, texture, sound, and music asset.

### Export
- [ ] Export **macOS** preset; open the `.app`/zip on a clean Mac (no Godot installed) and reach the lobby.
- [ ] Export **Windows Desktop** preset; launch on a clean Windows machine and reach the lobby.
- [ ] Both builds report the same `v<VERSION> · protocol <PROTOCOL>` in the lobby identity line.
- [ ] Both builds initialize Steam with the intended App ID (identity line shows the App ID).

### Steam and multiplayer (see the manual matrix in `docs/archive/MVP_ROADMAP.md`)
- [ ] Solo, Steam closed: full run to victory or defeat, return to lobby, start again.
- [ ] Solo, Steam open: same, with the Steam persona shown.
- [ ] Host + one client: create, join, invite, full run; lives, gold, towers, creeps, and upgrades match on both screens.
- [ ] Host + two clients: full run with one client disconnecting mid-wave; host takes over their positions and the run finishes.
- [ ] Host disconnect: clients return to the lobby with the error status visible.
- [ ] Build mismatch: a client on a different version cannot see or join the lobby.
- [ ] Nine clients (pre-public acceptance): capacity, ownership labels, synchronized completion.

### Performance
- [ ] Busiest wave meets the budgets in `docs/PERFORMANCE.md` on the Intel Iris 550 reference machine and a typical Windows laptop.

### Sign-off
- [ ] Playtest feedback collected with `docs/PLAYTEST_FEEDBACK_TEMPLATE.md`.
- [ ] Balance observations and defects recorded separately from architecture work.
- [ ] Tag the commit `v<VERSION>`.
