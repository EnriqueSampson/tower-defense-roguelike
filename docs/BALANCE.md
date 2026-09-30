# Balance

How the 30-level run is tuned and what the harness says about it. Update the table whenever `tools/generate_waves.py`, creep or tower stats, or `BalanceConfig` change.

## Knobs

| Knob | Where | Now |
| --- | --- | --- |
| Creep health per level | `HEALTH_GROWTH` in `tools/generate_waves.py` | ×1.18 per level (level 30 ≈ 122× level 1) |
| Tower stats and trees | `tools/race_content.py`, then `python3 tools/generate_races.py` | see the file |
| Boss health per level | `BOSS_HEALTH_GROWTH` (on top of each boss's own health) | ×1.03 per level |
| Bounty per level | `BOUNTY_GROWTH` (regular creeps only; bosses keep their own bounty) | ×1.06 per level |
| Build time | `BalanceConfig.BUILD_DURATION`; boss levels `BOSS_BUILD_SECONDS` | 25 s; 35 s |
| Starting gold | `BalanceConfig.starting_gold(players)` | 120 + 60 per extra player |
| Creeps per position | `ClassicWintermaulLayout.WAVE_MULTIPLIERS` × `BalanceConfig.player_scale` | 0.4× solo to 1.0× at nine players |

Rerun `python3 tools/generate_waves.py` after changing a curve; never hand-edit `resources/waves/`.

## The harness

`tests/balance_harness.gd` plays a whole run with bots that only build through builder orders, and prints one line per level (leaks, lives, gold at the start, gold earned, towers, gold invested, level length). `--out=report.json` also writes it as JSON.

```sh
godot --headless --fixed-fps 20 --path . --script res://tests/balance_harness.gd -- --players=1 --strategy=maze --race=orcs --seed=42
```

`--race` sets every bot's race, or `mixed` deals the four races out in catalog order. `--midpoint=relic|race` sets the halfway choice every bot makes; with a Relic the bot saves for its race ultimate and builds it at once (selling its cheapest tower if the maze is full). The JSON report lists these events.

`--fixed-fps 20` advances every frame by 0.05 s of game time as fast as the machine can go: a full run takes about 5 minutes of real time for about 50 minutes of game time, and results do not depend on the machine.

Strategies:

- **maze** (the competent player): greedy mazing. Each tower goes on or beside the current creep path in the bot's home position (Position 9 for the host, which every creep crosses; its roster position for anyone else), nearest the exit first, so creeps keep detouring. It builds its race's generalist every other time and the other tier-1 towers (detection included) in turn, and makes every third purchase an upgrade, alternating between branches of the tree.
- **lazy** (the floor): towers beside Position 9's original route only, no mazing, then upgrades.

The bots always take the first offered run upgrade.

## Targets

- A competent solo player and a competent 2–4 player team win, losing some lives on boss levels.
- A lazy player does not win. It should fall somewhere in the second half of the run.
- Early levels (1–9) should not leak for a competent player.

## Results (seed 42, September 30, 2026)

58 towers (Phase 4 plus the new branches and race ultimates), growth 1.18, solo, maze bot:

| Race | Halfway: Relic (ultimate) | Halfway: recruit a race | Levels that leaked |
| --- | --- | --- | --- |
| Humans | Victory, 14 lives | Victory, 14 lives (recruited Orcs) | 15 (5), 30 (1) |
| Orcs | Victory, 20 lives | Victory, 14 lives (recruited Elves) | 15 (4), 20 (1); with Elves also 23 (6) |
| Elves | Victory, 25 lives | Victory, 25 lives (recruited Bugs) | none |
| Bugs | Victory, 18 lives | Victory, 18 lives (recruited Humans) | 10 (1), 15 (6) |
| Humans, lazy bot | Defeat at level 23 | | 20 (19), 23 (1) |
| Mixed four-player lobby, Relics | Defeat at level 30 | | 3 (7), 30 (13) |

Every bot makes the halfway choice at the start of level 16 and, with a Relic, builds its ultimate straight away from banked gold. Lives can end above 20 through the Reinforced Gate run upgrade.

Tuning history:
- Before races (three towers with linear tiers): growth 1.14 let the lazy wall reach level 28 and the maze bot coast; 1.17 beat the maze bot at level 28; 1.16 was chosen.
- With races and upgrade trees the bots got stronger. First pass at 1.16: Humans 20 lives, Bugs 18, Elves 6, Orcs lost at level 29 (no air coverage once the axe line became the ground-only Lizard Rider). The Lizard line now hits air, the Minivan and Musketeer lost some damage, Elves' Ranger, Hippogryph and Owl hit harder, and the Ancient Ent now hits air. Growth rose to 1.18 (Humans 20, Orcs 22, Elves 17, Bugs 19; lazy bot lost at 28).
- New branches and ultimates: Elves went to 25 lives with no leaks; the Thornbush (now 30 gold, weaker slow) and Moon Well (less damage and splash) were trimmed, with no change in the result.
- Map retrace (82×84 towers, twin centre spawns split left and right), Humans, seed 42: solo Victory with 19 lives (1 leak; was 14 lives on the old map). Four players, Relics: Defeat at level 28, against level 24 on the old map in the same run. The new map leaks 7 on level 1 in four-player lobbies, because bots start at their home positions and little gold reaches the shared funnel in time. Watch the opening in playtests.

## Known gaps

- **Team lobbies lose to the final boss where solo wins.** In the mixed four-player run each bot defends its own position, so only about a quarter of the gold reaches Position 9, which every boss crosses (The Board of Directors spawns in all nine lanes). Solo puts everything into Position 9. This is the Phase 6 question of how positions and shared gold should work in 2–4 player lobbies.
- **Elves are the strongest race for bots:** they stack slows in the maze and have the most anti-air, and the level-15 air boss causes most other races' leaks. Watch it in playtests before nerfing.
- **The bots find it comfortable.** Every race wins solo and only the level-15 air boss reliably costs lives. Humans may find it harder (bots maze perfectly and never misclick), so hold further difficulty changes until Playtest gate A.
- **Late gold still piles up.** Once the home position is full (about 330 towers, level 11–18 depending on the race; Bugs fill it first because their towers are cheap), the bots max every upgrade and bank gold. Ultimates absorb more than the old tiers did, but more sinks (Phase 5 run events, or pricier ultimates) are worth considering.
- **Bosses are the difficulty spikes,** especially the air boss on level 15 (only towers that hit air can touch it) and the final boss. That is intended, but check it in playtests.
- The bots never sell, never move their maze, and pick run upgrades blindly, so they are a floor, not a ceiling, for what players can do.
- Nine-player lobbies are not covered yet (Phase 6).
