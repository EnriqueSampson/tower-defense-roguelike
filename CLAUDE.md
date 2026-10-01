# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Frozen Gate TD LIVE!**: a Wintermaul-style cooperative tower defense roguelike, presented as a live game show, in **Godot 4.7.2** (GDScript, GL Compatibility renderer — keep it; it is required for older Intel Macs). Multiplayer uses Steam lobbies through the vendored GodotSteam GDExtension in `addons/godotsteam/` (do not edit it). Without Steam the game runs solo on `OfflineMultiplayerPeer`.

Current direction and phase order are in `docs/ROADMAP.md`: a commercial Early Access release that plays like classic WC3 Wintermaul, built look-and-feel first. Check it before starting feature work.

## Commands

`godot` below means the Godot 4.7.2 binary (e.g. `/Applications/Godot.app/Contents/MacOS/Godot`).

```sh
godot --path .                                               # run the game
godot --headless --path . --script res://tests/run_tests.gd  # full regression suite; exit code = failure count
godot --headless --path . --script res://tests/net_sync.gd   # host + spawned client over local ENet; exit code = failure count
godot --headless --fixed-fps 20 --path . --script res://tests/balance_harness.gd -- --players=1 --strategy=maze  # scripted full run, per-level report
godot --path . --script res://tests/visual_smoke.gd          # windowed smoke run, writes /tmp/wintermaul_smoke.png
godot --headless --path . --import                           # refresh class cache after adding a class_name script
blender -b --python tools/blender/<model>.py                  # regenerate a placeholder .glb into assets/models/, then --import
```

- The test suite is a single `SceneTree` script. `_run_tests()` calls each `_test_*` function in turn, and each one records assertions through `_check(condition, description)`. There is no per-test filter: to run one test, temporarily comment out the other calls in `_run_tests()`. New tests must be added to that call list.
- A new `class_name` script is not visible to other scripts or the tests until `--import` runs.
- The Steam App ID defaults to `480`. Override it with `WINTERMAUL_STEAM_APP_ID`. `steam_appid.txt` is git-ignored and must never ship.

## Architecture

The full contract is in `docs/ARCHITECTURE.md`. Read it before changing networking, `RunState`, or RPCs. The key points:

- **Host-authoritative.** The lobby host is always peer `1`. Only the host mutates `RunState` (`scripts/game/run_state.gd`), which holds phase, gold, lives, tower and creep records, seed, upgrades and position owners. Clients send `_request_*` RPC intents to `game_controller.gd`, which checks them with `BuildPermissionPolicy.can_control` (using `multiplayer.get_remote_sender_id()`) plus phase, gold and pathing checks. Clients never change economy or entities locally.
- **Replication.** The host broadcasts a reliable `_apply_state_snapshot` every 0.5 s and right after any transaction (`_mark_dirty`), an unreliable creep snapshot every 0.15 s during waves, and reliable visual events. `WintermaulMap.reconcile_towers` / `reconcile_creeps` sync presentation by stable integer ID (allocated by `RunState`). Clients simulate creep movement for smoothness but never resolve damage. `RouteRunner.sync_authoritative()` corrects them.
- **Simulation vs. rendering.** All gameplay (paths, targeting, splash, snapshots) uses 2D `Vector2` sim pixels on an orthogonal grid (`WintermaulMap.TILE_SIZE`). Rendering is a 3D scene in a `SubViewport`. `MapProjection` maps sim pixels to the XZ plane, and each actor's `plane_position` is the only bridge to its `Node3D`. Networking, pathfinding and combat must not depend on 3D nodes.
- **Builders.** `BuilderSystem` (host only, not in `RunState`) keeps one builder per controlling peer with a WC3 order queue (plain order replaces, shift appends). Builders walk in straight lines and never touch the path grid. A build order is validated when issued and again by `_try_place_tower` when the builder arrives; gold is paid then, and the tower starts under construction (`build_remaining` on its record), holding its footprint but not attacking. Upgrades are timed the same way. Right-click moves, F1 selects the builder, and the camera pans with middle-drag.
- **Pathing and footprints.** `scripts/pathfinding/path_grid.gd` is a four-direction `AStarGrid2D` on 1-tile cells. Towers are 2×2 (`TowerDefinition.footprint`), anchored at their top-left cell (the record's `cell`), and may start on any cell. `WintermaulMap.footprint_cells` / `footprint_center` / `anchor_for_world` handle the conversion, and a placement is probed and committed as one all-or-nothing block (`PathGrid.can_block_cells`). It is rejected if it would seal a required route or an active creep's segment.
- **Data-driven content.** Towers, creeps, waves and run upgrades are `.tres` resources (script classes in `scripts/data/`) registered in `resources/content_catalog.tres`. `ContentCatalog.validate()` runs in the tests and rejects duplicate IDs, unordered or empty waves, and upgrades that target unknown towers. Definition `id` strings are wire-level identifiers: never rename a shipped one.
- **Races and upgrade trees.** Four builder races (Humans, Orcs, Elves, Bugs; `resources/races/`), picked in the lobby and stored per peer in `RunState.peer_races`. A builder builds only its race's tier-1 towers (`RaceDefinition.towers`); every other tower is reached by upgrading along `TowerDefinition.upgrade_options`, which can branch. An upgrade replaces the record's `definition_id` and adds to `invested`. Each race also has a unique ultimate (`RaceDefinition.ultimate`) that needs a Relic from the halfway choice (after level 15 every builder picks a Relic or a second race; `RunState.midpoint_pending`, `peer_relics`, `peer_bonus_races`). All race content (stats, trees, model recipes) lives in `tools/race_content.py`: edit it, then run `python3 tools/generate_races.py` (resources and catalog lists) and `python tools/blender/race_towers.py` (placeholder models for new towers). Don't hand-edit the generated tower or race files.
- **Roguelike layer.** `UpgradeOffer.roll(pool, modifiers, seed, wave_index, count, available_lines)` is deterministic for a given run seed and race-aware, and offers appear after waves flagged `offers_upgrade_after`. `RunModifiers` never mutates resources. It layers multipliers on `TowerDefinition.stats()` (tower-specific upgrades apply to the tower's whole line, `ContentCatalog.line_of`) and is rebuilt from the applied-upgrade ID list on every peer, so clients show host-equivalent numbers.
- **Scene flow.** `MainMenu.tscn` (entry) → `Main.tscn` (Steam lobby, `scripts/main.gd`) → `game/Game.tscn` (`game_controller.gd`, which hosts `map/WintermaulMap.tscn` and the HUD). Autoloads: `Steamworks`, `SteamSession` (`scripts/network/steam_session_manager.gd`), `GameSettings`, `AudioDirector`.
- **HUD.** `game_hud.gd` finds its widgets by unique name (`%Name`), so the WC3 layout in `Game.tscn` (top bar, multiboard, bottom console) can be rearranged freely. The command card is 12 slots built in code; `_fill_build_card` and `_fill_tower_card` decide what each slot shows, and its grid position sets the hotkey (QWER/ASDF/ZXCV), so the camera pans with the arrow keys only. `Minimap` draws from `WintermaulMap.build_minimap_image()`. `WC3Theme` styles the in-game HUD. The menus (`MainMenu.tscn`, the `Main.tscn` lobby) are a game-show broadcast built from `scripts/ui/broadcast/` (`BroadcastTheme`, `StudioBackdrop`, `LiveBadge`, `SponsorTicker`, `SystemLowerThird`); keep sponsors and show copy invented (no real brands, no names from *Dungeon Crawler Carl*), and call players builders, never crawlers. Player-facing text says "Frozen Gate TD LIVE!", not "Wintermaul" (internal class names keep it).
- **Terrain and lighting.** `TerrainBuilder` turns wall cells into cliff meshes and pines. The ground is one lit quad with a baked texture plus a noise detail layer. Keep default back-face culling on lit meshes: with culling disabled, the Compatibility renderer flips the ground's normal and the sun stops lighting it. Vertex colors on terrain are authored in sRGB (`vertex_color_is_srgb`).
- **Models.** `visual_scene` on `TowerDefinition` / `TowerUpgradeTier` / `CreepDefinition` points at a `.glb` under `assets/models/`; when empty, `Tower` / `RouteRunner` fall back to procedural meshes. `ActorModel` handles instancing, animations (`idle`/`attack`/`walk`), tint overlays and height. Models face +Z (−Y in Blender) with a `Turret` node for aiming; see the asset spec in `docs/ROADMAP.md` §7. `blender` means `/Applications/Blender.app/Contents/MacOS/Blender` (4.5 LTS).
- `tools/generate_waves.py` owns the 30 levels: the level table plus the `HEALTH_GROWTH` / `BOUNTY_GROWTH` curves. It writes `resources/waves/` and the catalog's wave list, so tune there and rerun, never hand-edit wave files. Check changes with `tests/balance_harness.gd` (bots that build only through builder orders; `--fixed-fps` makes a 30-level run take minutes). `tools/generate_upgrades.py` is a one-off; rerunning it overwrites hand edits in `resources/upgrades/`.
- **Special creeps** (air, magic immune, invisible with detection, splitters) are flags on `CreepDefinition`, matched by `can_target_air` / `can_target_ground` / `is_magic` / `detection_range` on `TowerDefinition`; see `docs/ARCHITECTURE.md` §9.
- `bpy` (Blender 4.5 as a Python module, `pip install bpy==4.5.0` on Python 3.11) runs the `tools/blender/` scripts without the Blender app: `python tools/blender/<model>.py`.

## Versioning rules (enforced by tests and lobby matching)

- `BuildInfo.VERSION` (`scripts/data/build_info.gd`), `application/config/version` in `project.godot`, and the export presets must all carry the same version string. The test suite checks this.
- Bump `BuildInfo.PROTOCOL_VERSION` whenever RPC signatures, snapshot fields, or content IDs change in a way older clients can't read. Lobbies only match equal `game`, `protocol`, `build` and `map` metadata.
