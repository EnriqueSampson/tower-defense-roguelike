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
| `shared_lives` | Shared defense |
| `peer_gold` | `peer_id -> gold`, one account per player; the host's also covers unfilled positions. `open_accounts` splits the lobby's starting gold evenly (remainder to the host); `award_shared_gold` splits each bounty and run-upgrade gold into one share per position, paid to that position's controller (fractions carry over); build, upgrade and sell use the requester's account; `close_account` hands a leaver's gold to the host |
| `lane_queued`, `lane_spawned` | Per-position spawn bookkeeping |
| `active_creeps` | `creep_id -> {position, definition_id, health_multiplier}` |
| `towers` | `tower_id -> {id, definition_id, cell, position, targeting, invested}`; an upgrade replaces `definition_id` with the chosen option from the tower's upgrade tree and adds its price to `invested` (which sets the sell value); `cell` is the footprint anchor (top-left cell of the tower's `TowerDefinition.footprint`, 2×2 for shipped towers). Work in progress adds `build_remaining`/`build_total`/`build_paid` (construction) or `upgrade_to`/`upgrade_remaining`/`upgrade_total`/`upgrade_paid` (timed upgrade); the host counts them down in `_tick_construction` |
| `position_owners` | `position_index -> peer_id` (0 = unfilled, host controls) |
| `peer_races` | `peer_id -> race_id` picked in the lobby (Steam member data `race`); unknown or missing picks fall back to the catalog's first race. Replicated as `races` in the state snapshot |
| `peer_bonus_races`, `peer_relics`, `midpoint_pending` | The halfway choice (§9): a second race per peer, Relics left per peer, and the peers who still have to choose. Replicated as `bonus_races`, `relics` and `midpoint` |
| `run_seed` | Host-generated seed for deterministic upgrade offers |
| `applied_upgrades`, `pending_offer` | Ordered upgrade IDs; offers pause the build timer |
| `elapsed_seconds`, `stats` | Run duration and results counters |
| `_next_tower_id`, `_next_creep_id` | Monotonic ID allocators (included in snapshots) |

Host-only runtime that is *not* in `RunState`: spawn queues and timers, bounty lookup per creep, load-acknowledgement set, and builders (`BuilderSystem`, `scripts/game/builder_system.gd`: one per controlling peer, keyed by peer ID, holding position, order queue and trip timer). Creep presentation state (health, stage, position, slow) is owned by `RouteRunner` nodes on the host and exported through `WintermaulMap.creep_snapshot()`.

## 3. Replicated presentation state (every peer)

- Tower nodes, creep nodes, projectiles, and effects are presentation. They are created by RPC events and corrected by snapshots.
- Clients simulate creep movement locally for smoothness; `RouteRunner.sync_authoritative()` corrects health, stage, slow, and position (smooth nudge under 1.5 tiles, snap and repath beyond that).
- Clients walk a moving builder toward its replicated target at builder speed, glide onto the host position once it stops, and snap when drift passes 1.5 tiles (`Builder.apply_record`). Clients count construction and upgrade timers down locally between snapshots, for the progress bars only.
- Invisible-creep detection is not replicated: every peer recomputes it each frame in `WintermaulMap.refresh_detection()` from the replicated tower stats (`detection_range`), so all peers reveal the same creeps. Undetected creeps are hidden and untargetable.
- Clients never resolve damage. Projectiles on clients are visual only. A creep that reaches the gate on a client waits there until the host confirms the leak.
- Clients run `RunModifiers.rebuild()` from the snapshot's upgrade list so previews and tower panels show host-equivalent numbers.

## 4. Snapshot cadence

| Message | Reliability | Cadence |
| --- | --- | --- |
| `_apply_state_snapshot` (RunState + tower records + results) | reliable | every 0.5 s and immediately after any transaction (`_mark_dirty`) |
| `_apply_creep_snapshot` (creep presentation records) | unreliable ordered | every 0.15 s during waves, only when peers are connected |
| `_apply_builder_snapshot` (`BuilderSystem.records()`: owner, position, current target, state, queued build sites) | unreliable ordered | every 0.15 s, only when peers are connected; the same records ride in the state snapshot as `builders` |
| `_builder_started_build` | reliable event | when a builder starts construction (plays `build`) |
| `_spawn_creep_visual` (carries a `start` dictionary: empty for pad spawns, the fall point, stage, progress and spawner for a splitter's children; a pad spawn's spawner is `creep_id % spawner count` on every peer, and the spawner picks the route, since twin spawners can take different sides of a fork), `_remove_creep_visual`, `_spawn_tower_visual`, `_update_tower_visual`, `_remove_tower_visual`, `_clear_creeps_visual` | reliable events | on change |
| `_projectile_fired` | unreliable | per shot |
| `_play_event`, `_show_notice`, `_show_bounty`, `_placement_feedback`, `_transaction_feedback` | reliable | on change |

Reconciliation (`WintermaulMap.reconcile_towers` / `reconcile_creeps`) adds missing entities, updates changed ones, and removes entities absent from the authoritative record, keyed by stable ID.

### Simulation vs presentation coordinates

Every gameplay value (paths, snapshots, targeting, splash) uses `Vector2` sim pixels on the orthogonal grid (`WintermaulMap.TILE_SIZE` per cell). Rendering is a 3D scene inside the battlefield `SubViewport`: `MapProjection` maps sim pixels to the XZ ground plane (one tile = one unit, height on Y), and `Tower`, `RouteRunner`, and `Projectile` expose `plane_position` as the only bridge to their `Node3D` transform. `BattlefieldCamera` (fixed WC3-style perspective: 56° pitch, 50° FOV, no yaw; the default distance shows about 19 towers across, zoom dollies toward the cursor between 0.4× and 1.5× of it, and the whole map is never framed) converts screen ↔ plane for picking and for the 2D canvas overlays (labels, health bars, effects) drawn on top of the 3D view. Nothing in networking, pathfinding, or combat depends on the 3D nodes.

## 5. Stable IDs

| Entity | ID | Source |
| --- | --- | --- |
| Player | Steam ID (lobby) and multiplayer peer ID (transport; host is 1) | `SteamSession` |
| Position | `0..8` internally, displayed as `Position 1..9`; classic order `1/2/3`, `6/5/4`, `7/9/8` | `ClassicWintermaulLayout` |
| Tower instance | `int` allocated by `RunState.allocate_tower_id()` | host |
| Creep instance | `int` allocated by `RunState.allocate_creep_id()` | host |
| Tower / creep / wave / upgrade / race definitions | `String id` on the resource; never rename after shipping (the original `bolt`, `cannon`, `frost` and `sentry` IDs survive inside their races) | `ContentCatalog` |
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
| Build order | phase allows building; definition ID exists; requester has a builder; the tower is one of the requester's race roots (`RaceDefinition.towers`, else `WRONG_RACE`); the placement checks below pass; requester controls the position; the requester's gold covers the modified cost. Nothing is spent yet. A plain order replaces the queue, a shift order appends |
| Construction start (builder arrives within `BUILDER_REACH_CELLS`) | the full place-tower check again, since the maze, creeps or gold may have changed; failure drops the order with a reason to its owner and spends nothing |
| Place tower | phase allows building; definition ID exists; race root as above; every footprint cell in bounds, buildable, inside one position, unoccupied, and free of creeps; the footprint as a whole does not seal any required route or active creep segment; requester controls the position; the requester's gold covers the modified cost (and pays it). Builder orders start the tower under construction (it holds its footprint but does not attack) |
| Move / Stop order | requester has a builder; move target inside the world rect. Builders walk anywhere and never touch the path grid |
| Halfway choice (`choice`, `race_id`) | requester is still pending; `race` names a known race other than its own; recorded once |
| Upgrade tower (`tower_id`, `target_id`) | phase; tower exists; requester controls its position; not under construction or already upgrading; `target_id` is one of the tower's `upgrade_options`; gold covers the target's modified cost. Paid up front; the tower keeps fighting as itself until the timer ends, then becomes the target |
| Sell tower | phase; tower exists; requester controls its position; exactly-once (second sell finds no record). Selling during construction cancels it for a full refund; selling mid-upgrade also returns the upgrade payment |
| Set targeting | tower exists; mode is valid; requester controls its position |
| Send gold (`to_peer`, `amount`) | run not over; `amount` > 0; the recipient has an account and is not the sender; the sender's gold covers it. The recipient gets a notice; `stats.gold_sent` counts it |
| Choose upgrade | requester is the host; upgrade is in the pending offer; not already applied |
| Creep resolution | `resolve_creep` erases the creep first so duplicate kill/leak reports are no-ops. A splitter's children are registered with `register_split` (outside the spawn queue) before the level can clear |

Typed RPC parameters reject malformed payloads at the transport layer before these checks run.

## 8. Run upgrades

- Offers are rolled after waves whose `offers_upgrade_after` flag is set (every third level) with `UpgradeOffer.roll(pool, modifiers, seed, wave_index, count, available_lines)`. The same seed, wave, owned upgrades and races always yield the same offer; upgrades for tower lines no race in the run can build are left out.
- Rules: an upgrade is never offered twice; `excludes_tags` removes mutually exclusive tradeoffs once one is owned; `requires_tags` gates upgrades behind an owned tag.
- The build countdown pauses while an offer is open. The host makes the single team choice; clients see the same cards read-only.
- `RunModifiers` never mutates resources. It layers multipliers on `TowerDefinition.stats()` output (tower-specific upgrades by line) and is rebuilt from the ID list on every peer.

## 9. Races and upgrade trees (Phase 4)

- `RaceDefinition` lists the tier-1 towers its builder builds and the builder model. Each `TowerDefinition` names the towers it can upgrade into (`upgrade_options`, one tier up); a tower with several options branches, as in classic Wintermaul.
- `ContentCatalog.validate()` checks that options name known towers one tier up, trees never merge, every tower belongs to exactly one race, every race can detect invisible creeps, and tower-specific run upgrades name a line root.
- A tower's *line* is the root of its tree (`ContentCatalog.line_of`). Run upgrades that name a tower apply to its whole line, and offers only include lines some race in the run can build.
- Each race also has a unique ultimate (`RaceDefinition.ultimate`) outside its trees. It is built directly, but only with a Relic.
- **Halfway choice.** Clearing level 15 of 30 (`BalanceConfig.midpoint_wave_index`) fills `midpoint_pending` with every peer that has a builder; the build timer and Launch wait until it empties (after `MIDPOINT_CHOICE_TIMEOUT` everyone left gets a Relic). Each peer sends `_request_midpoint_choice("relic" | "race", race_id)`: a Relic, or a second race (never its own) whose tier-1 towers and trees its builder may then build. Building the ultimate costs its gold plus one Relic (`Placement.NEEDS_RELIC` without one); cancelling construction refunds both, selling a finished ultimate refunds gold only.
- Content comes from `tools/race_content.py` (stats, trees, model recipes) through `tools/generate_races.py` (resources) and `tools/blender/race_towers.py` (placeholder models).

## 10. Special creeps (Phase 3)

| Trait | Rule |
| --- | --- |
| Air (`CreepDefinition.is_air`) | Follows its spawner's fixed flight path (`WintermaulMap.get_air_route`: the corners of the empty-map route, so every corridor and checkpoint) and ignores towers: never repaths, never blocks building. Only towers with `can_target_air` target or splash it |
| Magic immune | Magic towers (`TowerDefinition.is_magic`, Frost) skip it and their impacts deal no damage or slow |
| Invisible | Targetable only while inside some tower's `detection_range` (the Nosy Neighbor tower, or any tower with the Snitch Network upgrade). Splash still hits it, as in WC3 |
| Splitter (`split_into` × `split_count`) | On death, children spawn where it fell on the same stage, with the parent's health and bounty multipliers. Children never split again |

Levels scale creep health by `HEALTH_GROWTH` and regular bounties by `BOUNTY_GROWTH` per level (`tools/generate_waves.py`); `WaveDefinition.build_seconds` sets the build time before a level (boss levels get longer).

## 11. Known limitations (documented, not bugs)

- Clients may briefly show a creep alive after the host killed it (≤ one creep snapshot interval).
- Creep snapshots do not carry the spawner. If a client first learns of a split child from a snapshot rather than its spawn event, it derives the spawner from the creep ID, and may briefly steer toward the other side's neck until the next snapshot corrects its position.
- Position ownership maps Steam IDs to peer IDs at run start; peers that have not finished the transport handshake resolve to host control until the next roster refresh.
- Host migration, late join, and permanent progression are deferred (see the roadmap).
