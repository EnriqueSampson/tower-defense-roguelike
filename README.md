# Wintermaul Roguelike

A cooperative Wintermaul-style tower defense roguelike built in Godot 4 with Steam lobbies. Nine positions, one shared final gate, host-authoritative simulation, and seeded in-run upgrades.

## Requirements

| Item | Value |
| --- | --- |
| Engine | Godot **4.7.2 stable** (GL Compatibility renderer — required for older Intel Macs) |
| Steam | GodotSteam GDExtension 4.22 (vendored in `addons/godotsteam/`), Steamworks SDK 1.65 |
| Steam App ID | Development ID `480` by default; override with the `WINTERMAUL_STEAM_APP_ID` environment variable. `steam_appid.txt` is git-ignored and must never ship. |
| Platforms | macOS (universal) and Windows x86_64 export presets in `export_presets.cfg` |

Steam features (lobbies, invites, Quick Match) require the Steam client to be running and logged in. Without Steam the game still runs solo through `OfflineMultiplayerPeer`.

## Running

```sh
# Open in the editor
godot --path . --editor

# Run the game directly
godot --path .

# Headless regression suite (324 checks)
godot --headless --path . --script res://tests/run_tests.gd

# Windowed smoke run: boots a solo game, builds, launches a wave, saves /tmp/wintermaul_smoke.png
godot --path . --script res://tests/visual_smoke.gd

# Refresh the script class cache after adding class_name scripts
godot --headless --path . --import
```

Replace `godot` with the path to your Godot 4.7.2 binary (for example `/Applications/Godot.app/Contents/MacOS/Godot`).

## Testing with Steam

1. Launch Steam and sign in on every test machine.
2. Run the project (App ID 480 works for local development; every tester must use the same build so lobby metadata matches).
3. Host: **Create Public/Friends/Private** lobby, or **Quick Match**. Clients: **Browse**, **Join**, or accept a Steam invite (`+connect_lobby <id>` is also supported).
4. The lobby locks when the host presses **Start Defense**; in-progress lobbies are hidden from matchmaking.
5. After a run, **Return to Lobby** keeps the Steam lobby open so the same group can start again without restarting the application.

Lobby compatibility requires matching `game`, `protocol` (`BuildInfo.PROTOCOL_VERSION`), `build` (Steam build id, or `BuildInfo.VERSION` for development), and `map`.

## Project structure

```
project.godot              Autoloads: Steamworks, SteamSession, GameSettings, AudioDirector
export_presets.cfg         macOS + Windows export presets
resources/
  content_catalog.tres     Registry of every shipped tower, wave, and upgrade
  towers/                  TowerDefinition resources (bolt, cannon, frost) with upgrade tiers
  creeps/                  CreepDefinition resources (grunt, runner, brute, mender, warlord boss)
  waves/                   Ten WaveDefinition resources built from spawn groups
  upgrades/                17 RunUpgradeDefinition resources (tower / economy / defense / tradeoff)
scenes/
  MainMenu.tscn            Main menu (entry scene)
  Main.tscn                Steam lobby screen
  game/Game.tscn           Battlefield, camera, and HUD
  map/WintermaulMap.tscn   Map layers: terrain, towers, creeps, projectiles, effects, overlay
scripts/
  main.gd                  Lobby screen controller
  menu/                    main_menu.gd
  autoload/                steamworks.gd, game_settings.gd, audio_director.gd
  network/                 steam_session_manager.gd, lobby_match_policy.gd
  data/                    Definitions, catalog, layout, BuildInfo
  game/                    game_controller.gd (host authority), run_state.gd, run_modifiers.gd,
                           upgrade_offer.gd, build_permission_policy.gd, balance_config.gd
  combat/                  tower_targeting.gd, combat_resolver.gd
  actors/                  tower.gd, route_runner.gd, projectile.gd, effects_layer.gd
  map/                     wintermaul_map.gd, battlefield_camera.gd, map_paint_layer.gd,
                           map_projection.gd (sim pixels -> 3D plane), mesh_builder.gd, mesh_palette.gd
  pathfinding/             path_grid.gd (four-direction AStarGrid2D with anti-block probes)
  ui/                      game_hud.gd
tests/                     run_tests.gd (headless suite), visual_smoke.gd (windowed smoke)
tools/                     Generators used to author wave and upgrade resources
docs/                      Roadmap, architecture, release checklist, playtest template, licenses
```

## Adding content

- **Tower**: create a `TowerDefinition` `.tres` in `resources/towers/`, give it a unique `id`, add tiers, and list it in `resources/content_catalog.tres`. Towers draw themselves from `primary_color`/`accent_color`; no controller edits are required.
- **Creep**: create a `CreepDefinition` and reference it from a `WaveSpawnGroup`.
- **Wave**: create a `WaveDefinition` with ordered spawn groups and append it to the catalog (`number` must increase).
- **Run upgrade**: create a `RunUpgradeDefinition`, set typed effects and offer rules (`requires_tags`, `excludes_tags`), and append it to the catalog.

`ContentCatalog.validate()` runs in the test suite and rejects duplicate IDs, unordered waves, empty waves, and upgrades that target unknown towers.

## Authority in one paragraph

The lobby host owns the run. `RunState` (phase, gold, lives, tower records, creep records, seed, upgrades, position owners) lives only on the host and is broadcast as snapshots. Clients send intents (`_request_place_tower`, `_request_upgrade_tower`, `_request_sell_tower`, `_request_set_targeting`, `_request_choose_upgrade`) that the host validates against `BuildPermissionPolicy`; clients mirror results through RPC events and reconcile towers and creeps by stable ID. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full state and ownership contract.

## Documentation

- [docs/MVP_ROADMAP.md](docs/MVP_ROADMAP.md) — milestones and acceptance checklist
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — authoritative vs. replicated state, IDs, permissions, RPCs
- [docs/PERFORMANCE.md](docs/PERFORMANCE.md) — budgets and profiling procedure
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) — versioning rules and the release candidate checklist
- [docs/PLAYTEST_FEEDBACK_TEMPLATE.md](docs/PLAYTEST_FEEDBACK_TEMPLATE.md) — log collection and feedback form
- [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md) — provenance of every distributed asset
