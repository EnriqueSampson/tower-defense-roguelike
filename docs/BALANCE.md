# Balance

How the 30-level run is tuned and what the harness says about it. Update the table whenever `tools/generate_waves.py`, creep or tower stats, or `BalanceConfig` change.

## Knobs

| Knob | Where | Now |
| --- | --- | --- |
| Creep health per level | `HEALTH_GROWTH` in `tools/generate_waves.py` | ×1.16 per level (level 30 ≈ 74× level 1) |
| Boss health per level | `BOSS_HEALTH_GROWTH` (on top of each boss's own health) | ×1.03 per level |
| Bounty per level | `BOUNTY_GROWTH` (regular creeps only; bosses keep their own bounty) | ×1.06 per level |
| Build time | `BalanceConfig.BUILD_DURATION`; boss levels `BOSS_BUILD_SECONDS` | 25 s; 35 s |
| Starting gold | `BalanceConfig.starting_gold(players)` | 120 + 60 per extra player |
| Creeps per position | `ClassicWintermaulLayout.WAVE_MULTIPLIERS` × `BalanceConfig.player_scale` | 0.4× solo to 1.0× at nine players |

Rerun `python3 tools/generate_waves.py` after changing a curve; never hand-edit `resources/waves/`.

## The harness

`tests/balance_harness.gd` plays a whole run with bots that only build through builder orders, and prints one line per level (leaks, lives, gold at the start, gold earned, towers, gold invested, level length). `--out=report.json` also writes it as JSON.

```sh
godot --headless --fixed-fps 20 --path . --script res://tests/balance_harness.gd -- --players=1 --strategy=maze --seed=42
```

`--fixed-fps 20` advances every frame by 0.05 s of game time as fast as the machine can go: a full run takes about 5 minutes of real time for about 50 minutes of game time, and results do not depend on the machine.

Strategies:

- **maze** (the competent player): greedy mazing. Each tower goes on or beside the current creep path in the bot's home position (Position 9 for the host, which every creep crosses; its roster position for anyone else), nearest the exit first, so creeps keep detouring. It builds Bolt, Bolt, Frost, Bolt, Cannon, Nosy Neighbor in turn and makes every third purchase an upgrade.
- **lazy** (the floor): towers beside Position 9's original route only, no mazing, then upgrades.

The bots always take the first offered run upgrade.

## Targets

- A competent solo player and a competent 2–4 player team win, losing some lives on boss levels.
- A lazy player does not win. It should fall somewhere in the second half of the run.
- Early levels (1–9) should not leak for a competent player.

## Results (seed 42, September 30, 2026)

| Players | Strategy | Result | Lives left | Levels that leaked |
| --- | --- | --- | --- | --- |
| 1 | maze | Victory | 9 / 20 | 10 (1), 15 (5), 30 (5) |
| 2 | maze | Victory | 9 / 20 | 10 (3), 15 (4), 29 (1), 30 (3) |
| 4 | maze | Victory | 6 / 20 | 14 (4), 15 (3), 20 (1), 21 (1), 29 (5) |
| 1 | lazy | Defeat at level 22 | 0 | 20–22 |

Tuning history: growth 1.14 let the lazy wall reach level 28 and the maze bot coast; 1.17 beat the maze bot at level 28.

## Known gaps

- **Late gold piles up.** Once the home position is full (about 340 towers, around level 18), the bots max every upgrade and still bank 10–30k gold. The game needs gold sinks: Phase 4's larger race rosters and branching upgrade trees.
- **Bosses are the difficulty spikes,** especially the air boss on level 15 (only Bolt, Frost and the Nosy Neighbor can hit it) and the final boss. That is intended, but check it in playtests.
- The bots never sell, never move their maze, and pick run upgrades blindly, so they are a floor, not a ceiling, for what players can do.
- Nine-player lobbies are not covered yet (Phase 6).
