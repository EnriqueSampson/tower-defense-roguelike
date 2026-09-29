# Wintermaul Roguelike MVP Roadmap

> **Archived September 29, 2026.** Superseded by [../ROADMAP.md](../ROADMAP.md). Kept for the MVP acceptance record and the manual multiplayer matrix.

**Status:** Vertical slice implemented; awaiting external Steam playtests and clean-machine export validation  
**Updated:** September 3, 2026  
**Target:** A complete, replayable cooperative run that becomes the foundation for content production

> Checkbox legend: `[x]` implemented and covered by the headless suite or the windowed smoke run; `[ ]` requires a human/hardware step (Steam group test, clean-machine export, target-hardware profiling) and is tracked in [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md).

## 1. Product Direction

Build a modern cooperative Wintermaul-style tower defense in Godot 4. The game remains an orthogonal 2D simulation, presented through a fixed three-quarter 3D camera (55° tilt, no rotation) that starts framing the whole map and zooms toward the cursor. Players build physical tower mazes, defend nine connected positions, and share responsibility for the final Position 9 gate.

The MVP should prove three things:

1. **Mazing is satisfying.** Tower placement changes creep paths reliably and creates meaningful spatial decisions.
2. **Co-op is understandable and stable.** Players know which position they own, see the same important game state, and can finish a run together.
3. **Runs create choices.** Players make tower and upgrade decisions that vary between runs rather than repeating the same build every wave.

This milestone is not the final content-complete game. It is the stable vertical slice from which more towers, enemies, events, maps, and progression can be produced safely.

## 2. MVP Definition

The MVP is complete when a solo player or a 2–3 player Steam group can:

1. Enter a lobby or start solo.
2. Load into assigned positions with the whole battlefield framed.
3. Select, place, inspect, upgrade, and sell towers while preserving valid creep routes.
4. Defend a tuned 10-wave run containing multiple ground enemy roles and at least one boss.
5. Choose upgrades during the run that alter tower strategy.
6. Follow surviving creeps through connected positions into Position 9.
7. Reach an unambiguous victory or defeat screen with run results.
8. Return to the lobby and start another run without restarting the application.

The first external playtest target is **2–3 players**, even though the architecture and lobby support nine positions. Nine simultaneous players remain an acceptance test before public release, not a requirement for the first balance pass.

## 3. Current Foundation

### Implemented and tested

- Godot 4.7 project using GL Compatibility for older Intel Mac hardware.
- Steam lobby creation, browsing, Quick Match, invites, and solo sessions.
- Nine-player lobby capacity and position roster.
- Host-authoritative run phase, lives, team gold, builds, kills, leaks, and rewards.
- 72x80 stylized Wintermaul battlefield: three hedge lanes on top (1/2/3), side entrances and twin pockets in the middle (6/5/4), brow boxes and the mouth at the bottom (7/9/8). Positions 5 and 9 spawn from two pads each that share one wave budget.
- Nine native spawn queues with Position 9 as the final defense.
- Connected relay routing from Positions 1–8 through Position 9.
- Creep identity and health preserved across relay checkpoints.
- Shared lives deducted only after the final gate.
- Four-direction dynamic `AStarGrid2D` pathfinding.
- Tower collision, anti-block placement, active-creep protection, and repathing.
- Building during build and wave phases.
- One functioning Bolt Tower and five stat-scaled ground waves (superseded: three towers and ten spawn-group waves).
- Shared team economy and bounty rewards.
- Whole-map startup framing, WASD/arrow pan, drag pan, cursor-anchored wheel zoom, edge pan, and map constraints.
- Headless regression runner with 292 passing checks at the time of this document.

### Added by the vertical slice

- `ContentCatalog` resource registry; towers, creeps, waves, and run upgrades are resources.
- Bolt, Cannon (splash), and Frost (slow) towers with two upgrade tiers, selling, and four target priorities.
- Five creep roles (grunt, runner, armored brute, regenerating mender, Frost Warlord boss) across ten waves.
- Seeded team upgrade offers after waves 2/4/6/8 from a 17-upgrade rule-filtered pool; modifiers rebuilt from IDs on every peer.
- Position ownership with host control of unfilled and disconnected positions; every RPC validated against the sender.
- Full state snapshots plus unreliable creep snapshots with ID-based reconciliation; load acknowledgement before the first countdown.
- Build palette, placement previews with reasons, tower panel, wave preview, modifier panel, end screen, settings, and first-run controls overlay.
- Procedural audio with Master/Music/Effects buses and persisted volumes.
- Export presets, semantic version + protocol rules, release checklist, playtest template, and asset license inventory.

### Prototype limitations

- Presentation uses coherent procedural placeholder art rather than authored sprites.
- Clients can show a creep alive for up to one creep-snapshot interval after the host killed it.
- Steam group runs, clean-machine exports, and target-hardware profiling still need to be executed by people.

## 4. Guiding Technical Decisions

These decisions should remain stable through the MVP unless testing disproves them.

- Keep gameplay and pathfinding in orthogonal 2D (`Vector2` sim pixels, `TILE_SIZE` per cell). The 3D scene is presentation only: `MapProjection` maps one tile to one unit on the XZ plane and actors expose `plane_position`.
- The camera is a fixed orthographic three-quarter view (yaw 0°, pitch 55°). It never rotates; zoom 1.0 frames the whole map, zoom 2.0 inspects models, and panning is clamped to the map so it is inert while fully zoomed out.
- Create depth through primitive meshes (raised bases, hedge blocks, blob shadows), lighting, particles, and sound rather than by changing the simulation.
- Keep the lobby owner as the authoritative host for the MVP.
- Lock lobbies after a run begins. Late join, reconnect, and host migration are post-MVP features.
- Allow building during waves; Wintermaul juggling is part of the intended skill ceiling.
- Use resources for tower, enemy, wave, and upgrade data. Controllers should orchestrate data instead of hardcoding content lists.
- Treat Position 9 as the shared final defense, with upstream survivors remaining the same creep instances.
- Keep the current shared-gold model for the first vertical slice, but label it clearly as team gold and protect it with build permissions.

## 5. Critical Path

### Milestone 0: Freeze invariants and document ownership

**Goal:** Protect the working architecture before broadening gameplay.

- [x] Add a root `README.md` with setup, Godot version, Steam test requirements, test command, and project structure.
- [x] Document authoritative state versus replicated presentation state (`docs/ARCHITECTURE.md`).
- [x] Define stable IDs for players, positions, towers, creeps, waves, and upgrades.
- [x] Define build permission policy (`BuildPermissionPolicy`):
  - A player builds in their assigned position.
  - The host controls unfilled positions.
  - Position 9 is controlled by its assigned player or host when empty.
- [x] Add assertions for malformed RPC requests, invalid position ownership, invalid tower IDs, unaffordable builds, and duplicate resolutions.
- [x] Rename remaining player-facing “lane” terminology to “position”; internal migration can happen later.

**Exit criteria**

- [x] Existing checks remain green (suite grew from 93 to 292).
- [x] A client cannot spend gold or place a tower in an unauthorized position.
- [x] Solo can still control all nine positions.
- [x] Authority boundaries are described in project documentation.

### Milestone 1: Data-driven combat foundation

**Goal:** Make new gameplay content cheap to add.

- [x] Expand `TowerDefinition` with a stable ID, icon/visual reference, footprint, projectile speed, targeting mode, effect data, upgrade paths, and sell value.
- [x] Add `CreepDefinition` with stable ID, display name, health, speed, armor/tags, bounty, visual reference, and immunities.
- [x] Replace scalar-only wave resources with spawn groups referencing creep definitions.
- [x] Introduce a small targeting component or strategy API instead of embedding all targeting in `BasicTower` (`TowerTargeting`).
- [x] Add projectile behavior as a reusable actor; separate combat resolution from visual effects (`Projectile`, `CombatResolver`, `EffectsLayer`).
- [x] Store authoritative tower records and creep records in the game state so they can be serialized into snapshots.
- [x] Keep all placement and routing checks independent of tower visuals.

**Exit criteria**

- [x] Adding a tower, creep, or wave group requires a resource and visual scene, not edits throughout `game_controller.gd`.
- [x] Host and clients can reconstruct the same tower roster from authoritative records.
- [x] Existing Bolt Tower behavior is reproduced through the new data model.

### Milestone 2: Core tower interaction

**Goal:** Turn clicking the map into a deliberate strategy interface.

Implement at least three distinct base towers:

| Tower | Role | MVP behavior |
| --- | --- | --- |
| Bolt Tower | Generalist | Reliable single-target damage |
| Cannon Tower | Area damage | Slow attack with splash damage |
| Frost Tower | Control | Low damage with temporary movement slow |

- [x] Add a compact build palette using icons and visible costs.
- [x] Show selected tower range and footprint before placement.
- [x] Make valid, invalid, blocked-route, occupied, and unaffordable previews visually distinct.
- [x] Add tower selection with stats and current targeting mode.
- [x] Add two upgrade tiers per tower, with mutually exclusive final choices only if the UI remains clear (linear tiers chosen; exclusive branches deferred).
- [x] Add tower selling with an explicit refund percentage.
- [x] Add target priorities: first, last, strongest, and nearest.
- [x] Replicate build, upgrade, sell, and target-priority commands through host validation.

**Exit criteria**

- [x] A player can build multiple viable maze strategies.
- [x] Every transaction is authoritative, synchronized, and exactly-once.
- [x] Selling cannot temporarily or permanently seal a route incorrectly.
- [x] Tower range and effects are readable at normal gameplay zoom.

### Milestone 3: Ten-wave vertical slice

**Goal:** Produce one complete run with changing tactical demands.

Implement a 10-wave sequence using at least:

- Standard ground creep.
- Fast, low-health creep.
- Slow armored creep.
- Regenerating or support creep.
- Boss on wave 10.

- [x] Define wave budgets and spawn groups instead of relying only on global stat growth.
- [x] Preserve the nine-position spawn multipliers but tune total load for solo, 2–3 players, and nine players (`BalanceConfig.player_scale`).
- [x] Add wave preview information during the build phase: enemy roles, count, major traits, and boss warning.
- [x] Add speed and slow handling without breaking checkpoint continuity or A* repathing.
- [x] Add armor/resistance rules only after damage types are readable in the tower UI (flat armor with pierce, shown in tower and wave panels).
- [x] Decide whether air waves belong in the MVP after ground-wave playtests. Decision: deferred; no air waves in the MVP.
- [ ] Tune starting gold, tower costs, bounty, lives, and build timer from recorded playtests (initial values in `BalanceConfig` and resources; awaiting playtest data).

**Exit criteria**

- [ ] A successful run lasts approximately 20–30 minutes (verify in playtests).
- [ ] Each tower has a useful matchup and no tower is always correct (verify in playtests).
- [x] Wave 10 victory and life-zero defeat both resolve cleanly.
- [x] No wave stalls because of lost creep state or unreachable path stages.

### Milestone 4: First roguelike layer

**Goal:** Make consecutive runs meaningfully different without building meta-progression too early.

Use **in-run choices first**. Permanent unlocks can follow after the combat loop is proven.

- [x] Add a deterministic run seed owned by the host and included in snapshots.
- [x] Present a choice of three upgrades after selected waves, with one team choice for the first implementation.
- [x] Implement 12–18 upgrades across categories (17 shipped):
  - Tower-specific damage, range, cooldown, splash, or slow changes.
  - Economy choices such as bounty bonuses or discounted upgrades.
  - Defensive choices such as extra shared lives or Position 9 bonuses.
  - Tradeoffs with a benefit and cost rather than flat stat inflation.
- [x] Tag upgrades and build a rule-based offer pool that avoids invalid or duplicate choices.
- [x] Replicate offered choices, votes/selection, and applied modifiers from the host.
- [x] Display active run modifiers in a compact panel.
- [x] Record the seed and selected upgrades in end-of-run results.

**Exit criteria**

- [x] Two runs can support visibly different builds.
- [x] The same seed produces the same offers under the same rules.
- [x] Upgrade effects survive snapshots and do not mutate resource files globally.
- [x] The run remains completable without permanent progression.

### Milestone 5: Multiplayer correctness pass

**Goal:** Make a full locked-lobby run trustworthy for all connected players.

- [x] Add authoritative snapshots containing towers, tower upgrades, active creeps, creep health/status/stage, run modifiers, phase timers, gold, and lives.
- [x] Reconcile client presentation against stable entity IDs instead of only spawning/removing through isolated RPCs.
- [x] Define snapshot cadence and interpolation so creep movement remains smooth without making clients authoritative (0.5 s reliable state, 0.15 s unreliable creeps, smooth nudge / snap threshold).
- [x] Ensure tower shots, damage feedback, deaths, sells, upgrades, leaks, and rewards are visible to every client.
- [x] Reject RPCs from peers acting outside their assigned or host-controlled positions.
- [x] Implement real host takeover of disconnected players’ positions, matching the current status message.
- [x] Handle non-host disconnects without stopping the run.
- [x] Handle host disconnect by ending the run gracefully and returning clients to the lobby with a clear explanation.
- [x] Add load acknowledgement before the host starts the build timer (with a timeout so a stuck peer cannot stall the run).
- [x] Keep in-progress lobbies non-joinable for MVP; do not build late-join reconstruction UI yet.

**Exit criteria**

- [ ] A 2–3 player run reaches victory with matching lives, gold, tower state, creep state, and upgrade state on every client (requires a Steam group test; reconciliation is unit-tested).
- [x] A non-host disconnect causes no crash or stuck wave.
- [x] Invalid client requests do not change authoritative state.
- [x] Simulated latency does not create duplicate towers, duplicate bounty, or duplicate leaks (exactly-once resolution and ID reconciliation are unit-tested).

### Milestone 6: Readability, feedback, and overhead presentation

**Goal:** Make the game understandable without reading source code or external notes.

- [x] Highlight the local player’s position and label host-controlled positions.
- [x] Add map labels for spawns, checkpoints, the shared relay checkpoint, and the final gate.
- [x] Replace debug circles/polygons with coherent three-quarter-view placeholder sprites (procedural shaded bodies, raised bases, shadows).
- [x] Add tower bases, creep shadows, directional impact effects, damage flashes, death effects, and leak feedback.
- [x] Improve terrain boundaries and corridors using the attached Wintermaul references as structural inspiration, not copied assets.
- [x] Keep player color as a secondary signal; use numbers/icons so position identity is not color-dependent.
- [x] Add essential audio: UI confirm/error, build, upgrade, sell, attack, impact, death, wave start, boss warning, leak, victory, and defeat.
- [x] Add master, music, and effects volume controls.
- [x] Add a first-run controls overlay for build, select, pan, edge-pan, drag, and zoom.
- [x] Add an end screen showing result, wave reached, duration, towers built/upgraded/sold, kills, leaks, gold spent, seed, and upgrades chosen.

**Exit criteria**

- [ ] A new tester can identify their area, place a tower, understand why placement failed, launch a wave, and read victory/defeat without coaching (verify in playtests).
- [x] Important events are visible and audible at the focused position zoom.
- [x] UI remains usable at 1280x800 and 1920x1080 without overlap (sidebar scrolls; verified at 1280x800 in the smoke run).

### Milestone 7: Performance, packaging, and release candidate

**Goal:** Produce reproducible builds suitable for external playtests.

- [x] Establish performance budgets for host CPU, client CPU, frame time, active creeps, towers, and network bandwidth (`docs/PERFORMANCE.md`).
- [ ] Profile the busiest wave on the Intel Iris Graphics 550 target and a typical Windows machine (smoke run shows 145 fps early-wave on the Iris 550; full-wave profiling pending).
- [x] Pool projectiles/effects and reduce per-frame searches only where profiling identifies a problem (effects batched in one layer; static terrain layer; pooling deferred pending profiling).
- [x] Add macOS and Windows export presets.
- [x] Replace development App ID 480 through environment/build configuration for real Steam builds (`WINTERMAUL_STEAM_APP_ID`).
- [x] Define semantic build version and network protocol version rules (`BuildInfo`, enforced against `project.godot`).
- [x] Add a release checklist for clean import, tests, export, clean-machine launch, Steam create/join/invite, full run, and return-to-lobby.
- [x] Add crash/log collection instructions and a playtest feedback template.
- [x] Verify legal ownership or licenses for every distributed font, texture, sound, and music asset (`docs/ASSET_LICENSES.md`; all art and audio are procedural).

**Exit criteria**

- [x] Headless tests and editor import are clean.
- [ ] Windows and macOS builds launch on clean machines.
- [ ] Steam clients on matching builds can discover and finish a run.
- [x] Mismatched protocol/build clients cannot join each other.
- [ ] Target hardware sustains the agreed frame-rate floor during the busiest wave.

## 6. Test Strategy

### Automated tests (implemented in `tests/run_tests.gd`)

- [x] Tower definition validation and unique IDs.
- [x] Creep definition validation and unique IDs.
- [x] Wave spawn-group totals and deterministic ordering.
- [x] Build ownership and host control of empty positions.
- [x] Upgrade and sell economy, including duplicate-request protection.
- [x] Splash targeting, slow application/expiry, armor, and target priorities.
- [x] Upgrade offer determinism by seed.
- [x] Snapshot serialize/deserialize round trips.
- [x] Snapshot reconciliation for missing, changed, and removed entities.
- [x] Disconnect takeover and host-disconnect cleanup.
- [x] Ten-wave victory and defeat simulations.
- [x] Camera, preview, A*, checkpoint, and final-gate regressions already covered today.

### Manual multiplayer matrix

Run each release candidate through:

| Scenario | Required result |
| --- | --- |
| Solo, Steam closed | Full run works through `OfflineMultiplayerPeer` |
| Solo, Steam open | Same behavior with Steam identity available |
| Host + one client | Full run, synchronized combat and choices |
| Host + two clients | Full run plus one non-host disconnect |
| Nine clients | Capacity, ownership, performance, and synchronized completion |
| Host disconnect | Clients receive clear termination and return safely |
| Build mismatch | Lobby is filtered or join is rejected |

## 7. MVP Acceptance Checklist

The project is ready for its first serious external playtest when every item below is true.

### Gameplay

- [x] Ten waves and one boss form a 20–30 minute run (duration to be confirmed in playtests).
- [x] Three tower roles, upgrades, selling, and target priorities work.
- [x] At least four ground creep roles create different tactical pressures.
- [x] Mazing, rerouting, juggling, relays, and final-gate leaks remain correct.
- [x] Victory, defeat, and replay flow require no restart.

### Roguelike

- [x] Seeded upgrade offers occur during the run.
- [x] At least 12 upgrades support multiple viable builds.
- [x] Active modifiers are visible and synchronized.
- [x] Run results record seed and choices.

### Multiplayer

- [x] Assigned position and build permissions are clear and enforced.
- [x] Host controls empty positions.
- [x] All connected clients reconcile authoritative entity state.
- [x] Non-host disconnects are recoverable through host position takeover.
- [x] Host disconnect exits gracefully.

### UX and presentation

- [x] Placement failure reasons are visible.
- [x] Tower and wave information is readable before committing gold.
- [x] Local position, shared gold, shared lives, and final gate are unmistakable.
- [x] Essential sound and event feedback are present.
- [x] Camera and UI work at target resolutions.

### Release engineering

- [x] Automated suite, editor import, and manual smoke test pass.
- [ ] Windows and macOS exports work on clean machines.
- [ ] Steam lobby create/join/invite and version filtering are verified with a real Steam group.
- [ ] Performance meets the target-hardware budget on the busiest wave.
- [x] Distributed assets have documented licenses.

## 8. Explicitly Deferred Beyond MVP

Do not place these on the critical path unless playtesting proves one is required.

- True 3D or diamond-isometric simulation (the 3D scene is presentation only).
- Air waves and separate flying pathfinding.
- Permanent account progression and unlock currencies.
- Multiple builder races or large elemental tech trees.
- Competitive sending, income, or PvP modes.
- Matchmaking rating, leaderboards, achievements, and Steam Cloud.
- Late join, reconnect, host migration, and spectator mode.
- In-game voice or text chat; use Steam communication during MVP tests.
- Procedural maps, a map editor, and additional battlefields.
- Mobile and console builds.
- Full key rebinding and broad accessibility suite beyond essential readable UI and non-color-only signals.

## 9. Recommended Work Order

Execute the roadmap in this order:

1. **Milestone 0:** authority and ownership invariants.
2. **Milestone 1:** data-driven tower/creep/wave foundation.
3. **Milestone 2:** tower selection, upgrades, selling, and three tower roles.
4. **Milestone 3:** ten-wave content slice and balance instrumentation.
5. **Milestone 4:** seeded in-run upgrade choices.
6. **Milestone 5:** multiplayer reconciliation and disconnect correctness.
7. **Milestone 6:** readability, audio, onboarding, and end screen.
8. **Milestone 7:** profiling, exports, Steam build validation, and release candidate.

Do not begin permanent meta-progression until the ten-wave in-run loop has survived external playtests. All eight milestones are implemented in code; the next tasks are the human steps in [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md): a 2–3 player Steam run, clean-machine exports, busiest-wave profiling on target hardware, and balance tuning from recorded playtests.

## 10. Working Cadence

For each milestone:

1. Write acceptance tests or a reproducible manual scenario first.
2. Make the smallest architecture change that supports the milestone.
3. Keep data in resources and authority on the host.
4. Run the headless suite after every substantive edit.
5. Test the real scene, not only pure models.
6. Complete one solo smoke test and one multiplayer smoke test before closing the milestone.
7. Record balance observations and defects separately from architectural work.

A feature is not complete because it exists in code. It is complete when its player-facing behavior is understandable, its network ownership is defined, and its acceptance test passes.
