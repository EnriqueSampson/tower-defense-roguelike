# Roadmap

**Updated:** September 30, 2026
**Goal:** A commercial Steam Early Access release of a co-op tower defense that plays like Warcraft III Wintermaul, with a light roguelike layer.
**Pace:** Part-time (10–20 h/week). No launch date yet; phases are ordered, not scheduled. Size estimates are rough, at that pace.

The previous plan, which covered the 10-wave vertical slice, is archived at [archive/MVP_ROADMAP.md](archive/MVP_ROADMAP.md).

## 1. Vision

A faithful co-op Wintermaul for modern players:

- **Wintermaul first.** Build mazes with a builder unit, hold nine connected positions, and defend the shared Position 9 gate across a long run of levels. The roguelike layer adds run-to-run variety on top of that. It does not replace it.
- **Tone: funny and a bit out there.** Think *Dungeon Crawler Carl*: absurd escalation, sarcastic flavor text, and towers that start mundane and end ridiculous. The comedy targets absurdity, corporations and the system, not real groups of people.
- **The run is a broadcast.** As in *Dungeon Crawler Carl*, the defense is a show: an audience watches, ratings reward playing with flair, sponsors pay in loot boxes, and the System meddles for ratings. This premise is the roguelike layer, not decoration on it.
- **The WC3 look.** A fixed, tilted perspective camera, chunky and readable fantasy models, animation, and spell effects.
- **Builder races.** Several builders, each with its own tower set and upgrade trees. Early Access ships with 3–4 races.
- **Classic length.** 30+ levels per run. Other run-length presets are a post-MVP nice-to-have.
- **Co-op at any size.** Design for full 9-player lobbies first. Before Early Access, 1–4 players and solo must also be good.

## 2. Where we are

### Built and tested (502 headless checks, a two-process sync check, and a balance harness)

- Host-authoritative co-op over Steam lobbies, plus solo on `OfflineMultiplayerPeer`. Nine positions, with the host controlling unfilled and disconnected positions.
- A WC3-style builder per player: right-click to move, shift-queued build orders, Stop, construction over time, and cancel for a full refund. Solo uses one builder at double speed.
- Mazing on a 164×168 grid (82×84 two-by-two towers, retraced from the classic Wintermaul map): A* rerouting, anti-block placement, relay checkpoints into Position 9, shared lives, and gold per player with Send Gold.
- Four builder races picked in the lobby (Humans, Orcs, Elves, Bugs) with 58 towers: classic Wintermaul upgrade trees (branching, up to four tiers) plus one Relic-gated ultimate per race, selling, and four target priorities.
- A halfway choice after level 15: each player takes a Relic (their race's ultimate tower, for gold plus the Relic) or recruits a second race.
- A classic 30-level run: 17 creeps including air, invisible, magic-immune, swarm and splitting creeps, with a boss every fifth level.
- 18 seeded run upgrades, offered after every third level.
- A data-driven content catalog: towers, creeps, waves and upgrades are `.tres` resources.
- A 3D presentation layer over a 2D simulation, with procedural primitive meshes. At the Phase 0 baseline (tag `baseline-phase0`) the camera was orthographic at 55°.
- HUD, main menu, lobby, settings, end screen, procedural audio, and export presets.

### Not yet validated

- **Nobody but the developer has played it.** No Steam group run has happened yet.
- Exports have not been launched on clean machines, and the busiest wave has not been profiled on the Intel Iris 550 target.
- Balance is untuned.

### Gaps against the vision

| Vision | Today |
|---|---|
| Final art | Placeholder `.glb` models from `tools/blender/` for every tower, creep and the builder |
| 3–4 races with large tower rosters | 4 races, 14–15 towers each including an ultimate, placeholder art |
| Balanced for 1–4 players and solo | Balance-harness bots win with 1, 2 and 4 players and a lazy bot loses ([BALANCE.md](BALANCE.md)); no humans have tested it yet |

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

### Stock-take, September 30, 2026

The developer has played a full run and the direction is to keep refining, not rework. No one else has played yet. The balance harness hints at a flat middle: bots fill their home position by levels 11–18 and then bank gold, and only boss levels cost lives. Decisions:

- **Gold per player, not a team pool,** as in WC3: each player earns and spends their own gold and can send gold to teammates, including from chat. Lives stay shared. Unfilled positions' gold goes to the host, who controls them.
- **The Dungeon Crawler Carl framing, not only funny names:** a snarky "System" announcer reacting to play (first leak, bosses, builder trips, selling sprees, near-death saves), run-upgrade offers presented as sponsor loot boxes with rarities, and achievements with sarcastic titles.
- **Per-player end-of-run awards** from the multiboard stats ("Employee of the Month", "Most Leaks Allowed").
- **A late-game gold sink with real choices,** since gold piles up once a position is full.
- **Variety between runs** (wave mutators, boss variants), but only once playtests show runs feel samey.
- **The run is a broadcast** (the next-level hook). A ratings meter rises for playing with flair: clutch saves on the last tile, long mazes, kill combos, fast boss kills, comebacks. The System calls each one out on screen so it is never a mystery. Ratings milestones pay out sponsor loot boxes (Bronze, Silver, Gold, Legendary), which replace the fixed every-third-level upgrade offers. Before some levels the System offers a twist for bonus ratings ("every creep flies this level"), voted by the team or opted into per position. Team ratings plus a personal fan-favourite count feed the end-of-run awards. Ratings must reward good mazing, never replace it.
- **One active ability per builder,** on a cooldown (for example Humans' "Performance Review" stun), so waves are something to play, not only watch. Builders still cannot die.
- **Market check:** no standalone co-op Wintermaul-style game is on Steam. The nearest are Legion TD 2 (lane building and sending, from a WC3 map; the reference for the Wars mode) and Element TD 2 (mazing, from a WC3 map, no builders or shared positions).
- **A 3v3 "Wintermaul Wars" mode before Early Access** (creep sending between teams, in the spirit of Legion TD). Not started; keep maps and modes data-driven so a Wars map is another `DESIGN_MAP`.

## 4. Phases

Each phase ends with exit criteria and a short solo play session. The headless suite stays green throughout. Any change to RPCs or snapshots bumps `BuildInfo.PROTOCOL_VERSION`.

### Phase 0: Baseline and pipeline (about 1–2 weeks)

**Goal:** Know what the current game actually feels like, and make it possible to drop in real models.

- [ ] Play 3+ full solo runs of the current build and record what feels wrong (use [PLAYTEST_FEEDBACK_TEMPLATE.md](PLAYTEST_FEEDBACK_TEMPLATE.md)). This is the baseline for every later change. One full run played (September 30): the core works; keep refining rather than reworking.
- [x] Set up the Blender MCP for placeholder models (Blender 4.5 LTS, the last release for Intel Macs).
- [x] Add a model hook: `visual_scene` on `TowerDefinition`, `TowerUpgradeTier` and `CreepDefinition`, falling back to today's procedural meshes when it is empty (`ActorModel` helpers).
- [x] Write an asset spec for the modeler (§7): format, scale, pivot, facing, the `Turret` node, animation names, materials, and the draw-call and triangle budget from the Phase 1 performance check.
- [x] Put one placeholder tower and one creep through the whole pipeline: `tools/blender/human_swordsman.py` and `grunt.py` → `assets/models/*.glb` → Bolt and Grunt resources → in game.

**Exit:** One tower and one creep render from `.glb` files, the other content still renders procedurally, and nothing else changes.

### Phase 1: WC3 look and feel (about 4–6 weeks)

**Goal:** A screenshot reads as a Wintermaul-like game.

- [x] Camera: switched to perspective at a fixed WC3-like angle (56° pitch, 50° FOV). It plays close, as in WC3: the default view spans about 19 towers across at any window shape, zoom ranges from 0.18× (a close look at a single tower) to 1.8× of that, and the camera starts on the local player's position (Position 9 in solo). The whole map is never framed; the minimap (see the WC3 UI item) gives the overview. Picking uses ray casts, and overlays project correctly.
- [x] Placeholder models for the three towers and five creeps, generated by `tools/blender/` scripts: Human swordsman (Bolt), orc junk cannon (Cannon), elf water spirit (Frost); grunt, runner, brute, mender and the Frost Warlord boss. Towers have `idle` and `attack` animations; creeps have `walk`.
- [x] Terrain props and death animations. Cliffs carry about 1,000 pines, 300 snow-capped boulders and 66 ice-crystal clusters, each type one MultiMesh draw call and never on buildable ground. Killed creeps hand their model to a presentation-only `Corpse` that plays `death` (placeholders topple sideways, which reads clearly from the WC3 camera), or falls over when there is no `death` animation, then sinks into the ground. The battlefield now renders only above the console, as WC3 does, so camera focus lands in the centre of the visible area.
- [x] Tower ranges matched to Wintermaul's starter towers, taken from the map's unit data (1 tower = 128 WC3 units = 56 px): Bolt 5 towers (Wintermaul generalists are 4.7–5.9), Cannon 3.5 (splash towers 3.1–3.5), Frost 5 (slows 5.5–6.2). Tier and run-upgrade range bonuses were scaled to match. Splash radius is unchanged pending Phase 3 balance.
- [x] Position 9 spawns once, centred just below the chin and close to the relay and gate, as the single "Grey spawn" does in Wintermaul v.72.2 (v.73, X10.1 and Hb use two spawns). The old mouth channel is buildable ground.
- [x] Map scale: measured the real Wintermaul map (84×84 playable tiles = 82×84 towers, lanes about 10 towers wide and 25 long, Northrend tileset) and scaled our own layout 2× to 144×160 cells (72×80 towers).
- [x] Map retrace: `ClassicWintermaulLayout` is now an 82×84 ASCII design map (one character per tower) hand-retraced from the classic layout: ten-wide top lanes with no-build chokes, one 6 | 5 | 4 middle band, Position 5 spawning from nooks beside its chamber, 7 and 8 spawning under the brow and walking diagonals to the side lanes, and Position 9 spawning directly under the chin (the old empty strip is gone) and holding the funnel. Positions 2 and 5 spawn from left and right twins, and each twin routes through its own side's neck (a per-spawner `via` waypoint; split children inherit their parent's side), so the centre's creeps split evenly instead of all going left. No map files are copied (see ASSET_LICENSES).
- [x] WC3-style UI: the battlefield fills the screen behind a top resource bar (Menu/F10, phase, wave, timer, lives, gold, Launch and Ready), a top-right multiboard (positions, owners, spawns, modifiers, seed), and a bottom console. The console holds a minimap (terrain, position tints, towers, creeps and the camera trapezoid; click or drag to move the camera), a portrait with the selected tower's stats or the wave preview, and a 4×3 command card with QWER/ASDF/ZXCV hotkeys. The camera pans with the arrow keys, as in WC3. The theme is procedural (`WC3Theme`) until authored UI art exists.
- [x] Edge panning only at the real window edges, so moving the mouse onto the console, top bar or multiboard no longer nudges the camera (playtest feedback).
- [x] UI polish: 3D model portraits in the console (the selected tower's or creep's model in its own small viewport, playing idle or walk); click a creep to inspect it (red WC3 selection circle, live health, armor, speed, bounty, traits and home position, cleared on death); a multiboard that folds to its title; and fixed two-line command-card slots so the console keeps one height in every mode.
- [x] Terrain: a frozen Northrend look. Wall cells are raised, flat-shaded rock cliffs with uneven snowy tops (`TerrainBuilder`). The ground is lit snow with a tiling noise detail layer and a faint build grid, the outside is a dark abyss, and the sun casts shadows (2 splits). It holds 60 fps on the Iris 550 in the smoke run.
- [x] Unit readability: a WC3-style green selection circle on the selected tower (inside its range ring), bordered health bars that scale with zoom within limits, lane-coloured blob discs under creeps (model creeps lost the procedural lane band), and a small tinted impact spark instead of a large white flash (the splash ring stays). Damage numbers are left out on purpose: with hundreds of towers they are noise, and WC3 tower defenses show only the gold bounty on kills, which we already do. Position 9's lane colour is grey, so its creep discs are the least distinct.
- [x] Performance check: busiest wave (wave 9 at nine-player scale, 300 towers) via `tests/perf_wave.gd`. Game logic is now within budget. Rendering fixes: one draw call per moving part and real-time shadows off by default. See [PERFORMANCE.md](PERFORMANCE.md). Still to do: confirm 60 fps on a quiet machine.

**Exit:** Every tower and creep uses a model file. The camera and picking work at 1280×800 and 1920×1080. The busiest wave meets the target frame rate on the Iris 550.

### Phase 2: The builder (about 4–6 weeks)

**Goal:** Building feels like WC3 Wintermaul.

- [x] Builder units: `BuilderSystem` on the host owns each builder's position and order queue; the state snapshot and a 0.15 s unreliable builder snapshot replicate them, and `WintermaulMap.reconcile_builders` mirrors them by owner peer. Builders cannot be killed and do not block creeps. Placeholder model: `tools/blender/human_peasant.py` (`idle`, `walk`, `build`, `trip`).
- [x] Orders: right-click to move (Shift queues), build from the command card's hotkey grid (Shift-click queues more sites, shown as blue footprint markers), Stop on `S`, right-click or `V` to cancel placement, F1 to select and centre the builder. Camera drag moved to the middle button.
- [x] Construction: a build order is validated when issued and again when the builder arrives, because the maze may have changed. Gold is paid when construction starts. The tower holds its footprint, rises out of the ground over cost / 20 s (1.5–6 s) and does not attack until done. Cancelling refunds the full cost. Upgrades are timed the same way; the tower keeps fighting at its old tier meanwhile.
- [x] Movement: builders walk in straight lines anywhere, including other players' positions, clip through towers and each other, and never use the creep path grid.
- [x] Permissions: a builder may only build inside positions its owner controls (`BuildPermissionPolicy`), even though it can walk anywhere.
- [x] Easter egg: a builder that stops beside a building after a move order sometimes (4%, rolled from the run seed) bumps it and falls over (`trip`). Purely cosmetic: any new order gets it straight back up.
- [x] Solo control: one builder at double speed (16 cells/s) covers all nine positions (§6). Revisit after Playtest gate A.
- [x] Protocol bump (now 5), plus tests for order validation, construction timing, cancel and refund, Stop, the trip, and client-side builder reconciliation.

**Exit:** met in automated form. `tests/solo_builder_run.gd` finishes a solo run using only builder orders (victory at wave 10, 38 towers), and `tests/net_sync.gd` runs a host and a client over local ENet: the client builds, gets a foreign-position build rejected, upgrades, moves and readies up, and towers, gold, builders and creeps match on both peers. A human 2-player Steam session is still part of Playtest gate A.

Found while testing, for later phases:
- The creep snapshot is a list of dictionaries with string keys and exceeds the ENet MTU with only 18 creeps (Godot warns about packet loss). Pack it into typed arrays before the 9-player test (Phase 6).
- The host broadcasts snapshots to peers whose game scene hasn't loaded yet, which logs "node not found" RPC errors on them. It's harmless, because a client requests state on load, but it's noisy.

### Before Playtest gate A (added September 30)

- [x] Main menu and lobby finder redesign as a live game-show broadcast (the chosen direction): an animated studio backdrop with sweeping spotlights and scanlines, a LIVE badge with a climbing viewer count, Anton headlines (OFL), a sponsor ticker of invented sponsors, the System's lower third cycling sarcastic lines, and a "Tonight's Arena" card drawn from the layout. The lobby is "Contestant Registration": Now Airing (public shows), Your Crew (builder pick, roster coloured by position) and GO LIVE. Shared pieces live in `scripts/ui/broadcast/` (`BroadcastTheme`). No real brands and no names from the books.
- [x] Gold per player: `RunState.peer_gold` holds one account per player. Starting gold is split evenly; each bounty is split into nine position shares paid to each position's controller, so the host earns the shares of the positions it covers; build, upgrade and sell use the requester's account; a leaver's gold goes to the host. The top bar shows your gold, and the multiboard shows everyone's with +25 / +100 Send Gold buttons (host-validated `_request_send_gold`). Protocol 10.
- [x] In-game chat: Enter to talk, Esc to cancel; the log fades above the console, names in each player's position colour. The host relays lines (trimmed, capped at 200 characters, flood-limited) and runs slash commands: `/give 50 Name` (or `p3` for Position 3's player, amount and name in either order), `/gold`, `/help`, with private System replies. The System line is the hook for the announcer. Protocol 11.
- [x] The System announcer (`SystemAnnouncer`, host only): sarcastic lines for the run opening, the first leak, low lives, boss arrivals and kills, builder trips (by name), selling sprees, big gold gifts, close calls, the halfway choice, and victory or defeat. Ordinary lines respect an 8 s cooldown; once-per-run lines fire once; lines pick from pools seeded by the run seed. Each line shows as a broadcast banner over the battlefield and in the chat log. Protocol 12.
- [ ] End-of-run awards on the end screen.
- [ ] Broadcast prototype: a ratings meter with System call-outs for a few flair events, whose milestones trigger the existing upgrade offers.
- [ ] One builder ability, Humans only, to test whether active waves land.

### Playtest gate A: First friends playtest

- [ ] Run the manual multiplayer matrix (in the archived MVP roadmap) with 2–4 friends over Steam.
- [ ] Collect feedback with the template. Triage it into fun problems, bugs, and content.
- [ ] Update this roadmap from the results before starting Phase 3.

### Phase 3: Classic run structure (about 5–8 weeks)

**Goal:** A full-length Wintermaul run.

- [x] 30 levels with a boss on every fifth (The Regional Manager, the Frost Warlord, the Wyrm of Unpaid Overtime, the Compliance Lich, the Phantom Auditor and the Board of Directors), generated by `tools/generate_waves.py` from a level table and health and bounty curves. Boss levels get 35 s of build time (`WaveDefinition.build_seconds`), and run-upgrade offers come after every third level. Overlapping levels (the next level spawning before this one is cleared) are not in; a level still ends when its creeps are gone.
- [x] Air: flying creeps follow their lane's fixed flight path through every corridor and checkpoint (they used to cut straight across cliffs; fixed from playtest feedback), ignore mazes, and never block building. Towers have `can_target_air` / `can_target_ground` (Cannon is ground only).
- [x] Special creeps: magic immunity (Frost is magic), fast swarms (Intern Imps), splitters (Middle Management Slime → three Delegated Slimelets; the final boss adjourns into five Directors), and invisible creeps. Towers can only target invisible creeps inside detection range, which currently comes from the Nosy Neighbor tower or the Snitch Network run upgrade; Phase 4 moves detection into each race. Placeholder models for every new creep and the tower come from `tools/blender/creeps_phase3.py` and `human_nosy_neighbor.py`.
- [x] Balance tooling: `tests/balance_harness.gd` plays whole runs headless with bots that build only through builder orders (a greedy mazer and a lazy wall, 1–9 players) and reports leaks, lives and the gold curve per level; a full run takes about 5 minutes. See [BALANCE.md](BALANCE.md) for the knobs, targets and current results.

**Exit:** met by the harness. The maze bot wins solo and with 2 and 4 players, and the lazy bot loses at level 22. Every level is covered. Human playtests still decide whether it is fun.

Found while tuning, for later phases:
- Late-game gold piles up once a position is full: Phase 4's bigger rosters and branching upgrades must add gold sinks.
- Bigger lobbies start with more gold (+60 per extra player, now split evenly between the players' accounts) as a stopgap; Phase 6 retunes the economy per lobby size.
- The busiest level is now level 29 at nine-player scale: 286 creeps at once (wave 9 peaked at 100). Headless game logic still averages 7.2 ms per frame (p99 14 ms), but rendering it on the Iris 550 needs re-profiling in Phase 6.

### Phase 4: Builder races (about 3–4 weeks for the framework, then 3–5 weeks per race)

**Goal:** 3–4 distinct races, each with a full tower roster.

- [x] Race framework: a `RaceDefinition` resource (builder model, the towers its builder builds), a race picker in the lobby (Steam member data `race`, remembered in settings, shown on the roster), per-peer races in `RunState` and the snapshot, host validation that a builder only builds its own race's towers, and catalog validation for races (every tower in exactly one race, every race can detect). Race-specific run upgrades exist for Bugs (Pheromone Trails, Swarm Tactics), and offers are race-aware.
- [x] Classic Wintermaul upgrade trees replace the two linear tiers: an upgrade turns a tower into another tower (paying that tower's cost), and some towers branch (the Guy With a Sword becomes a Crossbow Enthusiast or a Knight on a Budget). Sell value follows the gold invested.
- [x] 14–15 towers per race (September 30: +13 upgrade branches and a Relic-gated race ultimate each), escalating from mundane to absurd and covering ground, air, splash, slow, armor piercing and detection. All content lives in `tools/race_content.py`; `tools/generate_races.py` writes the resources and `tools/blender/race_towers.py` the placeholder models (37 new towers and three new builders). Final art from the modeler is still to come. Bolt, Cannon, Frost and the Nosy Neighbor were folded in: Humans, Orcs, Elves and Humans respectively, keeping their IDs.

| Race | Tier 1 (builder) | Upgrades | Ultimate | Detection |
|---|---|---|---|---|
| **Humans** | Guy With a Sword, Nosy Neighbor | Crossbow Enthusiast → Musketeer; Knight on a Budget → Minivan of Uncles; Neighborhood Watch → HOA President | Rage Streamer (magic splash) | Nosy Neighbor line |
| **Orcs** | Orc With an Axe, Junk Cannon, Sniffer Boar | Axe Juggler → Lizard Rider; Scrap Mortar → Battle Wagon or Flak Goblin (anti-air); Truffle Hog of War | Big Lizard Energy, War Rig | Sniffer Boar line |
| **Elves** | Elf Archer, Water Spirit, Sapling | Ranger → Hippogryph Rider, or Owl Post; Tide Caller → Water Elemental; Treant → Ancient Ent | Water Elemental (area slow), Ancient Ent | Owl Post |
| **Bugs** | Worker Ant (5 gold), Dung Beetle, Firefly, Mosquito | Soldier Ant → Army Ant Platoon; Stag Beetle → Rhino Beetle; Lantern Bug; Horsefly | The Hive Queen (the only Bug splash) | Firefly line |

Added after the first playtest feedback: Humans gained the Ballista Guy, Paladin of Paperwork, Monster Truck Rally and Doorbell Camera Drone; Orcs the Shaman With Opinions → Witch Doctor (their first slows) and Boar Cavalry; Elves the Moon Well, Pond Kraken and Thornbush; Bugs the Stink Bug and Dragonfly → Murder Hornet. Race ultimates, one per Relic: Orbital Selfie Stick (Humans), Da Big Stompa (Orcs), The World Tree (Elves) and Locust Apocalypse (Bugs). Six more race-line run upgrades joined the pool.

Bugs are the mazing race: towers cost 5–12 gold, hit weakly, and never splash except their ultimates (the Hive Queen and Locust Apocalypse). Real brand names are avoided (the Rage Streamer is a "streamer").
- [ ] Balance each race against the Phase 3 harness: first pass done (see [BALANCE.md](BALANCE.md)); needs playtests.

**Exit:** 3–4 races can each finish a classic run, and no race dominates in playtests. The harness has each race finishing solo; playtests are still to come.

### Phase 5: Roguelike layer, retuned (about 2–3 weeks)

**Goal:** Variety between runs that works with 30+ levels and multiple races.

- [x] Halfway choice (added from playtest feedback): after level 15 every builder takes a Relic, a one-time resource that lets them build their race's unique ultimate for gold plus the Relic, or recruits a second race whose towers their builder can also build. The wave timer waits for everyone (60 s, then a Relic). See ARCHITECTURE.md §9.
- [ ] Retune when offers appear and how large the upgrade pool is for long runs. Offers are already race-aware (Phase 4).
- [ ] The full broadcast: sponsor loot boxes with rarities paid by ratings milestones (replacing fixed offers), System twists before some levels with team voting or per-position opt-in, and a personal fan-favourite count. Tune from the Playtest gate A reaction to the prototype.
- [ ] Builder abilities for every race, if the Humans prototype lands.
- [ ] Achievements with sarcastic titles.
- [ ] A late-game gold sink with real choices (for example pricier ultimates, paid run events, or rewards for banked gold).
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

### Phase 8: Wintermaul Wars, 3v3 (before Early Access)

- [ ] A team-versus-team mode with creep sending, on its own map. Scope it after Playtest gate B.

## 5. Risks

- **Name and IP.** "Wintermaul" is a Warcraft III community map name. Before a commercial release, choose a final game name and make sure nothing uses Blizzard names, assets or recognizable designs. Do this before the store page.
- **Performance on the Iris 550.** Real models, animation and 9 positions of creeps on GL Compatibility is the biggest technical risk. Profile at the end of Phase 1, not at the end of the project.
- **Art throughput.** 3–4 races with 8–10 towers each means about 30–40 tower models plus creeps and builders, all from one volunteer modeler. The model hook and placeholders keep this from blocking gameplay work, but the modeler's time decides the Early Access date.
- **Balance at scale.** 30+ levels × 3–4 races × 4 lobby sizes cannot be hand-tuned. The Phase 3 harness is essential.
- **Builder networking.** Move orders and construction time add latency-sensitive state. It uses the host-authority pattern that already works, but it changes the protocol.

## 6. Open questions

- **Solo and small lobbies:** for now solo controls all nine positions with one builder at double speed (Phase 2). Revisit after Playtest gate A: several builders, merged or disabled positions, or AI help are still options, and Phase 6 has to settle 2–4 player lobbies too.
- ~~Race 4's name and framing~~: Bugs, a cheap mazing race. Races share no towers.
- **Final game name.**
- **Public repository.** The GitHub repo is public and search-indexed. Decide whether it goes private before the store page.
- **Duke Wintermaul.** A 2011 forum post mentions a tower defense made with the original map's author. Look into it during the naming review.

## 7. Asset spec for the modeler

These conventions keep placeholder and final models interchangeable. The placeholder scripts in `tools/blender/` follow them and are working examples.

- **Format:** `.glb` (glTF binary) exported from Blender with +Y up (the exporter default). One file per tower, creep or builder; every tower in an upgrade tree is its own tower with its own file.
- **Where:** `assets/models/towers/`, `assets/models/creeps/` and `assets/models/builders/`. File names use the content ID in snake_case (for example `human_swordsman.glb`).
- **Scale:** 1 Blender unit = 1 map tile. Towers are 2×2 tiles, so a tower fits a 2×2-unit square, base included. Creeps are about half a tile across. The game does not rescale models, so author them at size.
- **Pivot:** the object origin is at the center of the footprint, on the ground (z = 0).
- **Facing:** the model's front faces −Y in Blender (the side Blender's Front view shows). After export that becomes +Z, which the game treats as forward.
- **Turning:** on towers, everything that should turn toward the target sits under an empty named `Turret`. Creeps turn as a whole to face where they're walking.
- **Animations:** action names become the in-game animation names. Towers use `idle` (looping) and `attack` (plays once per shot, then returns to `idle`). Creeps use `walk` (looping) and `death` (plays once, up to about 1.2 s, then the corpse sinks; a sideways fall reads best from the WC3 camera). Builders use `idle`, `walk` (looping), `build` (plays when construction starts) and `trip` (the fall-over easter egg). Keep each animation on as few objects as possible; the placeholders animate one pivot empty per animation.
- **Materials:** use a Principled BSDF with base color, roughness and optionally one texture. Avoid Blender-only shader nodes, which glTF can't export. Colors pass through as linear light: Blender's color picker already handles this, but values typed into a script must be converted from sRGB (the placeholder helper does this). Keep emission strength below about 1, or glowing parts wash out to white in game.
- **Budget (from the Phase 1 performance check):** draw calls matter far more than triangles on the Iris 550 (each separate mesh-and-material pair is one draw call). A tower should be at most 3–4 meshes (base, the `Turret`, and one extra moving part if animated) and a creep 1–2, each with a single material using one texture atlas per race. Keep roughly 1–3k triangles per tower and 0.5–1.5k per creep. Don't rely on real-time shadows: they are off by default, so bake contact shading into the texture.

## 8. Explicitly deferred

Not on the critical path unless playtests change our minds: run-length presets (Short, Long, Endless), PvP modes other than the 3v3 Wars mode (Phase 8), a map editor or multiple maps, procedural maps, late join, reconnect, host migration, spectating, leaderboards, Steam Cloud, mobile or console, and in-game voice.
