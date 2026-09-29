# Roadmap

**Updated:** September 29, 2026
**Goal:** A commercial Steam Early Access release of a co-op tower defense that plays like Warcraft III Wintermaul, with a light roguelike layer.
**Pace:** Part-time (10–20 h/week). No launch date yet; phases are ordered, not scheduled. Size estimates are rough, at that pace.

The previous plan, which covered the 10-wave vertical slice, is archived at [archive/MVP_ROADMAP.md](archive/MVP_ROADMAP.md).

## 1. Vision

A faithful co-op Wintermaul for modern players:

- **Wintermaul first.** Build mazes with a builder unit, hold nine connected positions, and defend the shared Position 9 gate across a long run of levels. The roguelike layer adds run-to-run variety on top of that. It does not replace it.
- **Tone: funny and a bit out there.** Think *Dungeon Crawler Carl*: absurd escalation, sarcastic flavor text, and towers that start mundane and end ridiculous. The comedy targets absurdity, corporations and the system, not real groups of people.
- **The WC3 look.** A fixed, tilted perspective camera, chunky and readable fantasy models, animation, and spell effects.
- **Builder races.** Several builders, each with its own tower set and upgrade trees. Early Access ships with 3–4 races.
- **Classic length.** 30+ levels per run. Other run-length presets are a post-MVP nice-to-have.
- **Co-op at any size.** Design for full 9-player lobbies first. Before Early Access, 1–4 players and solo must also be good.

## 2. Where we are

### Built and tested (310 headless checks)

- Host-authoritative co-op over Steam lobbies, plus solo on `OfflineMultiplayerPeer`. Nine positions, with the host controlling unfilled and disconnected positions.
- Mazing on a 72×80 grid: A* rerouting, anti-block placement, relay checkpoints into Position 9, and shared lives and gold.
- Three towers (Bolt, Cannon, Frost), each with two upgrade tiers, selling, and four target priorities.
- Five creep roles, including one boss, across 10 waves.
- 17 seeded run upgrades, offered after waves 2, 4, 6 and 8.
- A data-driven content catalog: towers, creeps, waves and upgrades are `.tres` resources.
- A 3D presentation layer: an orthographic 55° camera over a 2D simulation, with procedural primitive meshes.
- HUD, main menu, lobby, settings, end screen, procedural audio, and export presets.

### Not yet validated

- **Nobody but the developer has played it.** No Steam group run has happened yet.
- Exports have not been launched on clean machines, and the busiest wave has not been profiled on the Intel Iris 550 target.
- Balance is untuned.

### Gaps against the vision

| Vision | Today |
|---|---|
| Builder unit you control, with build time | Click a tile and the tower appears instantly |
| WC3 perspective camera and real models | Orthographic camera; procedural primitive meshes built per ID in `tower.gd` and `route_runner.gd` |
| 30+ levels, air and special waves | 10 ground waves; air waves deferred |
| 3–4 races with large tower rosters | 3 towers, no races |
| Balanced for 1–4 players and solo | Solo exists, but controlling nine positions alone is untested |

## 3. Decisions from the planning interview

- Visuals come first: builder, camera and placeholder models, then content.
- Models: placeholders for now, made with the Blender MCP. A friend will model the final art. Model files have to be swappable without code changes.
- Builder: classic WC3. Right-click to move; a build order walks the builder to the site, and the tower then constructs over a few seconds. Builders cannot be killed.
- Camera: a fixed WC3-style angle with perspective projection. No rotation.
- The roguelike layer stays, but it is secondary to classic Wintermaul.
- **Towers are 2×2** (done September 29, 2026). A footprint is anchored at its top-left cell and can start on any cell, so 1-tile gaps between towers stay possible for mazing.
- **Builders** can cross into other players' positions and move without colliding: they clip through towers and each other. The one exception is an easter egg: now and then a builder bumps into a building and falls over.
- **Run length:** classic 30+ levels only, for the MVP. Presets such as Short, Long and Endless are post-MVP.
- **Invisible creeps are in.** Each race gets detection through a detection tower, a detection upgrade, or either one, depending on the race.

## 4. Phases

Each phase ends with exit criteria and a short solo play session. The headless suite stays green throughout. Any change to RPCs or snapshots bumps `BuildInfo.PROTOCOL_VERSION`.

### Phase 0: Baseline and pipeline (about 1–2 weeks)

**Goal:** Know what the current game actually feels like, and make it possible to drop in real models.

- [ ] Play 3+ full solo runs of the current build and record what feels wrong (use [PLAYTEST_FEEDBACK_TEMPLATE.md](PLAYTEST_FEEDBACK_TEMPLATE.md)). This is the baseline for every later change.
- [ ] Set up the Blender MCP for placeholder models.
- [ ] Add a model hook: `visual_scene: PackedScene` on `TowerDefinition` and `CreepDefinition`, falling back to today's procedural meshes when it is empty.
- [ ] Write an asset spec for the modeler (§7): format, scale, pivot, orientation, polygon and texture budgets, animation names, and file naming.
- [ ] Put one placeholder tower and one creep through the whole pipeline (Blender → `.glb` → resource → in game).

**Exit:** One tower and one creep render from `.glb` files, the other content still renders procedurally, and nothing else changes.

### Phase 1: WC3 look and feel (about 4–6 weeks)

**Goal:** A screenshot reads as a Wintermaul-like game.

- [ ] Camera: switch to perspective at a fixed WC3-like angle and field of view, with zoom and pan. Rework screen-to-ground picking, overlays, and the startup framing for the whole map.
- [ ] Placeholder models for the three towers, five creeps and the terrain props, with idle, walk, attack and death animations where they apply.
- [ ] Terrain: replace flat tiles with height, cliffs and lane borders in WC3 style, and add lighting and shadows within Iris 550 budgets.
- [ ] Unit readability: selection circles, health bars, damage numbers, and projectile and impact effects sized for a perspective camera.
- [ ] Performance check: the busiest current wave on the Iris 550, with the camera fully zoomed out.

**Exit:** Every tower and creep uses a model file. The camera and picking work at 1280×800 and 1920×1080. The busiest wave meets the target frame rate on the Iris 550.

### Phase 2: The builder (about 4–6 weeks)

**Goal:** Building feels like WC3 Wintermaul.

- [ ] Builder units: the host owns their position and order queue, and snapshots and reconciliation replicate them the same way as towers and creeps. Builders cannot be killed and do not block creeps.
- [ ] Orders: right-click to move, a WC3-style build grid of hotkeys, shift-queued builds, and cancel.
- [ ] Construction: the build site is validated when ordered and again when construction starts, because a path may have changed in between. Towers build over time (placement stays reserved), and cancelling refunds the cost.
- [ ] Movement: builders walk anywhere, including other players' positions, and clip through towers and other builders. They don't use the creep path grid.
- [ ] Permissions: a builder may only build inside positions its owner controls (`BuildPermissionPolicy`), even though it can walk anywhere.
- [ ] Easter egg: occasionally a builder "bumps" a building and plays a fall-over animation. It's purely cosmetic and never changes gameplay.
- [ ] Solo control: one builder per player. Decide how a solo player covers nine positions (§6).
- [ ] Protocol bump, plus tests for order validation, construction timing, cancel and refund, and builder reconciliation.

**Exit:** A solo run can be finished using only the builder, and a 2-player local or Steam test stays in sync.

### Playtest gate A: First friends playtest

- [ ] Run the manual multiplayer matrix (in the archived MVP roadmap) with 2–4 friends over Steam.
- [ ] Collect feedback with the template. Triage it into fun problems, bugs, and content.
- [ ] Update this roadmap from the results before starting Phase 3.

### Phase 3: Classic run structure (about 5–8 weeks)

**Goal:** A full-length Wintermaul run.

- [ ] Extend to 30+ levels, with a boss every few levels, level timers, and between-level pacing.
- [ ] Air waves: flying creeps take a direct route between checkpoints, and towers need `can_target_air` / `can_target_ground` flags.
- [ ] Special creeps: magic immunity, fast swarms, splitters, and invisible creeps. Towers can only target invisible creeps inside detection range, which each race gets from a detection tower, a detection upgrade, or either one (Phase 4).
- [ ] Balance tooling: a headless auto-play harness that simulates waves against scripted mazes and reports leaks and gold curves. Hand-tuning 30+ levels is not realistic without it.

**Exit:** A full classic 30+ level run can be completed solo and with 2–4 players, and the balance harness covers every level.

### Phase 4: Builder races (about 3–4 weeks for the framework, then 3–5 weeks per race)

**Goal:** 3–4 distinct races, each with a full tower roster.

- [ ] Race framework: a `RaceDefinition` resource (builder model, tower tree, race-specific upgrades), race selection in the lobby, and catalog validation for races.
- [ ] Branching upgrade trees, replacing the current two linear tiers.
- [ ] About 8–10 towers per race, escalating from mundane to absurd, and covering ground, air, splash, slow and support roles plus detection. Each race ships with placeholder art first and final art from the modeler. The existing Bolt, Cannon and Frost towers get folded into a race or retired.

| Race | Early towers | Mid towers | Late towers |
|---|---|---|---|
| **Humans** | A guy with a sword | A car full of people with machine guns | A streamer at a computer hurling insults |
| **Orcs** | An orc with an axe | Makeshift cars with guns bolted on | An orc riding a giant lizard |
| **Elves** | Archers | Hippogryph riders | Ents and water summons |
| **Race 4** (name TBD) | Ninjas | Samurai | An AI chip maker |

Race 4 keeps its ninja, samurai and AI chip maker towers, but its name and framing must not be based on a real ethnicity. Point the joke at the absurdity instead, for example a mega-corporation ninja clan. Real brand and platform names (such as Twitch) are avoided in tower names; use generic stand-ins like "streamer".
- [ ] Balance each race against the Phase 3 harness.

**Exit:** 3–4 races can each finish a classic run, and no race dominates in playtests.

### Phase 5: Roguelike layer, retuned (about 2–3 weeks)

**Goal:** Variety between runs that works with 30+ levels and multiple races.

- [ ] Retune when offers appear and how large the upgrade pool is for long runs. Make offers race-aware.
- [ ] Optional run events or modifiers, only if Playtest gate A or B shows runs feel samey.
- [ ] Decide about meta-progression. It stays deferred unless playtests ask for it.

### Phase 6: Every lobby size (about 3–4 weeks)

**Goal:** Solo and 1–4 player lobbies are as good as 9-player lobbies.

- [ ] Scale waves and economy by player count (extends `BalanceConfig.player_scale`).
- [ ] Unfilled positions: pick an approach from §6 and implement it.
- [ ] Balance-harness coverage for 1, 2, 4 and 9 players.
- [ ] Test with a 9-player lobby (capacity, performance, sync).

### Playtest gate B: Wider external playtest

- [ ] 10+ outside players across lobby sizes, including solo. Record crash logs and feedback.

### Phase 7: Early Access readiness (about 4–6 weeks)

- [ ] Final art from the modeler across all races, creeps and terrain.
- [ ] A real Steam App ID, a store page, and capsule art.
- [ ] Clean-machine exports for Windows and macOS, and the release checklist passing ([RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)).
- [ ] Performance budgets met on the Iris 550 with final art and 9 players.
- [ ] Settings polish: graphics options, key rebinding for the build grid, and accessibility basics.
- [ ] Legal and naming review (see §5).

## 5. Risks

- **Name and IP.** "Wintermaul" is a Warcraft III community map name. Before a commercial release, choose a final game name and make sure nothing uses Blizzard names, assets or recognizable designs. Do this before the store page.
- **Performance on the Iris 550.** Real models, animation and 9 positions of creeps on GL Compatibility is the biggest technical risk. Profile at the end of Phase 1, not at the end of the project.
- **Art throughput.** 3–4 races with 8–10 towers each means about 30–40 tower models plus creeps and builders, all from one volunteer modeler. The model hook and placeholders keep this from blocking gameplay work, but the modeler's time decides the Early Access date.
- **Balance at scale.** 30+ levels × 3–4 races × 4 lobby sizes cannot be hand-tuned. The Phase 3 harness is essential.
- **Builder networking.** Move orders and construction time add latency-sensitive state. It uses the host-authority pattern that already works, but it changes the protocol.

## 6. Open questions

- **Solo and small lobbies:** should solo control all nine positions with one builder, get several builders, have positions merged or disabled, or get AI help?
- **Race 4's name and framing** (see Phase 4), and whether races share any towers.
- **Map scale after 2×2 towers:** towers now cover 4× the area on the same 72×80 map, so mazes are coarser and lanes feel narrower. Review this in the Phase 0 baseline runs. If it feels wrong, base the fix on how the actual WC3 Wintermaul map is built, not on guesswork: its lane widths and position sizes measured in tower widths, and how its build grid relates to creep pathing. Then rescale the layout to match.
- **Final game name.**

## 7. Asset spec for the modeler (to finalize in Phase 0)

Draft conventions so placeholder and final models are interchangeable:

- Format: `.glb` (glTF binary), one file per tower tier, creep or builder.
- Scale: 1 unit = 1 map tile. Towers are 2×2 tiles, so a tower model fits a 2×2-unit square. Pivot at the center of the base, on the ground.
- Orientation: facing −Z. Turrets that rotate are a separate named node (`Turret`).
- Animations, named: `idle`, `walk`, `attack`, `death`, `build` (for builders and construction).
- Budget: to be set by the Phase 1 performance check. Start around 1–3k triangles per tower and 0.5–1.5k per creep, with one texture atlas per race.

## 8. Explicitly deferred

Not on the critical path unless playtests change our minds: run-length presets (Short, Long, Endless), PvP or sending modes, a map editor or multiple maps, procedural maps, late join, reconnect, host migration, spectating, leaderboards, Steam Cloud, mobile or console, and in-game voice.
