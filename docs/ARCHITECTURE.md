# Architecture: Authority, State, and Ownership

This document freezes the invariants that the MVP depends on. Change them deliberately and bump `BuildInfo.PROTOCOL_VERSION` whenever the wire contract changes.

## 1. Authority model

- The lobby owner is the **host** and is always multiplayer peer `1`. Solo play uses `OfflineMultiplayerPeer`, so the local player is the host.
- Lobbies lock when a run starts. Late join, reconnect, and host migration are out of scope for the MVP.
- Only the host mutates `RunState`. Clients never change gold, lives, towers, creeps, upgrades, or ownership locally.
- If the host disconnects, `SteamSession._on_server_disconnected` leaves the lobby, records an error status, and emits `game_end_requested`; the game scene stops processing and returns every client to the lobby screen.
- If a non-host disconnects, the host calls `BuildPermissionPolicy.transfer_to_host`, notifies everyone, and the run continues.

## 2. Authoritative state (host only)

`scripts/game/run_state.gd` — serialized by `RunState.snapshot()`:

| Field | Meaning |
| --- | --- |
| `phase`, `current_wave_index`, `wave_count` | Run progression |
| `shared_lives`, `team_gold` | Shared economy and defense |
| `lane_queued`, `lane_spawned` | Per-position spawn bookkeeping |
| `active_creeps` | `creep_id -> {position, definition_id, health_multiplier}` |
| `towers` | `tower_id -> {id, definition_id, cell, tier, position, targeting}`; `cell` is the footprint anchor (top-left cell of the tower's `TowerDefinition.footprint`, 2×2 for shipped towers) |
| `position_owners` | `position_index -> peer_id` (0 = unfilled, host controls) |
| `run_seed` | Host-generated seed for deterministic upgrade offers |
| `applied_upgrades`, `pending_offer` | Ordered upgrade IDs; offers pause the build timer |
| `elapsed_seconds`, `stats` | Run duration and results counters |
| `_next_tower_id`, `_next_creep_id` | Monotonic ID allocators (included in snapshots) |

Host-only runtime that is *not* in `RunState`: spawn queues and timers, bounty lookup per creep, load-acknowledgement set. Creep presentation state (health, stage, position, slow) is owned by `RouteRunner` nodes on the host and exported through `WintermaulMap.creep_snapshot()`.

## 3. Replicated presentation state (every peer)

- Tower nodes, creep nodes, projectiles, and effects are presentation. They are created by RPC events and corrected by snapshots.
- Clients simulate creep movement locally for smoothness; `RouteRunner.sync_authoritative()` corrects health, stage, slow, and position (smooth nudge under 1.5 tiles, snap and repath beyond that).
- Clients never resolve damage. Projectiles on clients are visual only. A creep that reaches the gate on a client waits there until the host confirms the leak.
- Clients run `RunModifiers.rebuild()` from the snapshot's upgrade list so previews and tower panels show host-equivalent numbers.

## 4. Snapshot cadence

| Message | Reliability | Cadence |
| --- | --- | --- |
| `_apply_state_snapshot` (RunState + tower records + results) | reliable | every 0.5 s and immediately after any transaction (`_mark_dirty`) |
| `_apply_creep_snapshot` (creep presentation records) | unreliable ordered | every 0.15 s during waves, only when peers are connected |
| `_spawn_creep_visual`, `_remove_creep_visual`, `_spawn_tower_visual`, `_update_tower_visual`, `_remove_tower_visual`, `_clear_creeps_visual` | reliable events | on change |
| `_projectile_fired` | unreliable | per shot |
| `_play_event`, `_show_notice`, `_show_bounty`, `_placement_feedback`, `_transaction_feedback` | reliable | on change |

Reconciliation (`WintermaulMap.reconcile_towers` / `reconcile_creeps`) adds missing entities, updates changed ones, and removes entities absent from the authoritative record, keyed by stable ID.

### Simulation vs presentation coordinates

Every gameplay value (paths, snapshots, targeting, splash) uses `Vector2` sim pixels on the orthogonal grid (`WintermaulMap.TILE_SIZE` per cell). Rendering is a 3D scene inside the battlefield `SubViewport`: `MapProjection` maps sim pixels to the XZ ground plane (one tile = one unit, height on Y), and `Tower`, `RouteRunner`, and `Projectile` expose `plane_position` as the only bridge to their `Node3D` transform. `BattlefieldCamera` (fixed WC3-style perspective: 56° pitch, 50° FOV, no yaw; zoom dollies toward the cursor, and zoom 1.0 frames the whole map) converts screen ↔ plane for picking and for the 2D canvas overlays (labels, health bars, effects) drawn on top of the 3D view. Nothing in networking, pathfinding, or combat depends on the 3D nodes.

## 5. Stable IDs

| Entity | ID | Source |
| --- | --- | --- |
| Player | Steam ID (lobby) and multiplayer peer ID (transport; host is 1) | `SteamSession` |
| Position | `0..8` internally, displayed as `Position 1..9`; classic order `1/2/3`, `6/5/4`, `7/9/8` | `ClassicWintermaulLayout` |
| Tower instance | `int` allocated by `RunState.allocate_tower_id()` | host |
| Creep instance | `int` allocated by `RunState.allocate_creep_id()` | host |
| Tower / creep / wave / upgrade definitions | `String id` on the resource; never rename after shipping | `ContentCatalog` |
| Run | `run_seed` (`int`) | host |

## 6. Build permission policy

`scripts/game/build_permission_policy.gd`:

1. A player controls the position assigned in the lobby roster.
2. The host controls every unfilled position (owner `0`).
3. Position 9 is controlled by its assigned player, or by the host when empty.
4. Disconnected players' positions transfer to the host.
5. Solo runs assign all nine positions to the host so everything reads as "YOU".

Every client intent carries the sender peer ID (`multiplayer.get_remote_sender_id()`) and is rejected when `can_control` fails. Rejections never change authoritative state and return a `WintermaulMap.Placement` reason to the requester.

## 7. Validation performed by the host

| Request | Checks |
| --- | --- |
| Place tower | phase allows building; definition ID exists; every footprint cell in bounds, buildable, inside one position, unoccupied, and free of creeps; the footprint as a whole does not seal any required route or active creep segment; requester controls the position; team gold covers the modified cost |
| Upgrade tower | phase; tower exists; requester controls its position; a next tier exists; gold covers the modified cost |
| Sell tower | phase; tower exists; requester controls its position; exactly-once (second sell finds no record) |
| Set targeting | tower exists; mode is valid; requester controls its position |
| Choose upgrade | requester is the host; upgrade is in the pending offer; not already applied |
| Creep resolution | `resolve_creep` erases the creep first so duplicate kill/leak reports are no-ops |

Typed RPC parameters reject malformed payloads at the transport layer before these checks run.

## 8. Run upgrades

- Offers are rolled after waves whose `offers_upgrade_after` flag is set (waves 2, 4, 6, 8) with `UpgradeOffer.roll(pool, modifiers, seed, wave_index)`. The same seed, wave, and owned upgrades always yield the same offer.
- Rules: an upgrade is never offered twice; `excludes_tags` removes mutually exclusive tradeoffs once one is owned; `requires_tags` gates upgrades behind an owned tag.
- The build countdown pauses while an offer is open. The host makes the single team choice; clients see the same cards read-only.
- `RunModifiers` never mutates resources. It layers multipliers on `TowerDefinition.stats_for_tier()` output and is rebuilt from the ID list on every peer.

## 9. Known limitations (documented, not bugs)

- Clients may briefly show a creep alive after the host killed it (≤ one creep snapshot interval).
- Position ownership maps Steam IDs to peer IDs at run start; peers that have not finished the transport handshake resolve to host control until the next roster refresh.
- Air waves, host migration, late join, and permanent progression are deferred (see the roadmap).
