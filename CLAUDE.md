# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Wintermaul-style cooperative tower defense roguelike in **Godot 4.7.2** (GDScript, GL Compatibility renderer — keep it; it is required for older Intel Macs). Multiplayer uses Steam lobbies through the vendored GodotSteam GDExtension in `addons/godotsteam/` (do not edit it). Without Steam the game runs solo on `OfflineMultiplayerPeer`.

## Commands

`godot` below means the Godot 4.7.2 binary (e.g. `/Applications/Godot.app/Contents/MacOS/Godot`).

```sh
godot --path .                                               # run the game
godot --headless --path . --script res://tests/run_tests.gd  # full regression suite; exit code = failure count
godot --path . --script res://tests/visual_smoke.gd          # windowed smoke run, writes /tmp/wintermaul_smoke.png
godot --headless --path . --import                           # refresh class cache after adding a class_name script
```

- The test suite is a single `SceneTree` script. `_run_tests()` calls each `_test_*` function in turn, and each one records assertions through `_check(condition, description)`. There is no per-test filter: to run one test, temporarily comment out the other calls in `_run_tests()`. New tests must be added to that call list.
- A new `class_name` script is not visible to other scripts or the tests until `--import` runs.
- The Steam App ID defaults to `480`. Override it with `WINTERMAUL_STEAM_APP_ID`. `steam_appid.txt` is git-ignored and must never ship.

## Architecture

The full contract is in `docs/ARCHITECTURE.md`. Read it before changing networking, `RunState`, or RPCs. The key points:

- **Host-authoritative.** The lobby host is always peer `1`. Only the host mutates `RunState` (`scripts/game/run_state.gd`), which holds phase, gold, lives, tower and creep records, seed, upgrades and position owners. Clients send `_request_*` RPC intents to `game_controller.gd`, which checks them with `BuildPermissionPolicy.can_control` (using `multiplayer.get_remote_sender_id()`) plus phase, gold and pathing checks. Clients never change economy or entities locally.
- **Replication.** The host broadcasts a reliable `_apply_state_snapshot` every 0.5 s and right after any transaction (`_mark_dirty`), an unreliable creep snapshot every 0.15 s during waves, and reliable visual events. `WintermaulMap.reconcile_towers` / `reconcile_creeps` sync presentation by stable integer ID (allocated by `RunState`). Clients simulate creep movement for smoothness but never resolve damage. `RouteRunner.sync_authoritative()` corrects them.
- **Simulation vs. rendering.** All gameplay (paths, targeting, splash, snapshots) uses 2D `Vector2` sim pixels on an orthogonal grid (`WintermaulMap.TILE_SIZE`). Rendering is a 3D scene in a `SubViewport`. `MapProjection` maps sim pixels to the XZ plane, and each actor's `plane_position` is the only bridge to its `Node3D`. Networking, pathfinding and combat must not depend on 3D nodes.
- **Pathing.** `scripts/pathfinding/path_grid.gd` is a four-direction `AStarGrid2D`. Tower placement is rejected (and rolled back) if it would seal a required route or an active creep's segment.
- **Data-driven content.** Towers, creeps, waves and run upgrades are `.tres` resources (script classes in `scripts/data/`) registered in `resources/content_catalog.tres`. `ContentCatalog.validate()` runs in the tests and rejects duplicate IDs, unordered or empty waves, and upgrades that target unknown towers. Definition `id` strings are wire-level identifiers: never rename a shipped one.
- **Roguelike layer.** `UpgradeOffer.roll(pool, modifiers, seed, wave_index)` is deterministic for a given run seed, and offers appear after waves flagged `offers_upgrade_after`. `RunModifiers` never mutates resources. It layers multipliers on `TowerDefinition.stats_for_tier()` and is rebuilt from the applied-upgrade ID list on every peer, so clients show host-equivalent numbers.
- **Scene flow.** `MainMenu.tscn` (entry) → `Main.tscn` (Steam lobby, `scripts/main.gd`) → `game/Game.tscn` (`game_controller.gd`, which hosts `map/WintermaulMap.tscn` and the HUD). Autoloads: `Steamworks`, `SteamSession` (`scripts/network/steam_session_manager.gd`), `GameSettings`, `AudioDirector`.
- `tools/generate_waves.py` and `tools/generate_upgrades.py` are one-off generators that write `.tres` files. Rerunning them overwrites hand edits in `resources/waves/` or `resources/upgrades/`.

## Versioning rules (enforced by tests and lobby matching)

- `BuildInfo.VERSION` (`scripts/data/build_info.gd`), `application/config/version` in `project.godot`, and the export presets must all carry the same version string. The test suite checks this.
- Bump `BuildInfo.PROTOCOL_VERSION` whenever RPC signatures, snapshot fields, or content IDs change in a way older clients can't read. Lobbies only match equal `game`, `protocol`, `build` and `map` metadata.
