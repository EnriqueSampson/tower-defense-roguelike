class_name BalanceConfig
extends RefCounted

## Central tuning knobs recorded from playtests. Content lives in resources;
## these are run-wide constants that are not tower or creep specific.
const STARTING_GOLD := 120
## The lobby's starting gold, split evenly between the players' accounts: each
## extra player adds some so everyone can afford first towers (a Phase 6
## retune will scale income too).
const STARTING_GOLD_PER_EXTRA_PLAYER := 60
const STARTING_LIVES := 20
const BUILD_DURATION := 25.0
## Wave 1 waits for every player to ready up, falling back to this timeout.
const WAVE_ONE_READY_TIMEOUT := 90.0
const OFFER_CHOICE_COUNT := 3

## Ratings (the broadcast): viewers earned for playing with flair. Every
## RATINGS_MILESTONE viewers buys a sponsor offer (a run-upgrade choice). A
## flawless level earns a bit over a third of a milestone, so clean play gets
## an offer every third level, as the old fixed schedule did; flair is faster.
const RATINGS_MILESTONE := 100000
const RATINGS_FLAWLESS := 35000
## A kill within CLUTCH_TILES of the gate.
const RATINGS_CLUTCH := 8000
const CLUTCH_TILES := 5.0
## MULTI_KILL_COUNT kills within MULTI_KILL_SECONDS.
const RATINGS_MULTI_KILL := 5000
const MULTI_KILL_COUNT := 5
const MULTI_KILL_SECONDS := 0.6
## Clutch saves and multi-kills pay at most this many times each per level,
## or late levels (hundreds of creeps, splash everywhere) would flood ratings.
const KILL_FLAIR_PER_LEVEL := 2
## A boss killed within BOSS_SPEED_SECONDS of spawning.
const RATINGS_SPEED_BOSS := 30000
const BOSS_SPEED_SECONDS := 25.0
## A level cleared with this many lives or fewer left.
const RATINGS_NAIL_BITER := 15000
const NAIL_BITER_LIVES := 3
## Mazes: the creeps' current routes against the empty-map routes.
const RATINGS_MAZE := 15000
const RATINGS_MAZE_EPIC := 30000
const MAZE_RATIO := 1.6
const MAZE_RATIO_EPIC := 2.5
## Seconds the host waits for load acknowledgements before starting anyway.
const LOAD_ACK_TIMEOUT := 15.0
## Team-size load scale: solo defenders face fewer creeps per position than a
## full nine-player lobby because every position still spawns.
const MIN_PLAYER_SCALE := 0.4
const MAX_PLAYER_SCALE := 1.0
## Builders move in a straight line and clip through everything. Wintermaul
## builders run at WC3's 522 speed cap (~4 towers/s = 8 cells/s); a solo
## player covers all nine positions with one builder, so it runs faster.
const BUILDER_SPEED_CELLS := 8.0
const SOLO_BUILDER_SPEED_MULTIPLIER := 2.0
## A build order starts construction once the builder is this close (cells)
## to the site centre, like a WC3 worker reaching the building footprint.
const BUILDER_REACH_CELLS := 1.6
## Construction and upgrade time scale with cost: cost / 20 seconds, clamped.
const BUILD_SECONDS_PER_GOLD := 0.05
const MIN_BUILD_SECONDS := 1.5
const MAX_BUILD_SECONDS := 6.0
## Easter egg: chance that a builder stopping beside a building after a move
## order bumps it and falls over. Cosmetic: any new order gets it back up.
const BUILDER_TRIP_CHANCE := 0.04
const BUILDER_TRIP_SECONDS := 1.6


## Halfway choice: after this many levels (half the run) every builder picks
## a second race or a Relic for its race's ultimate. Unpicked choices become
## Relics when the timer runs out.
const MIDPOINT_CHOICE_TIMEOUT := 60.0


## Wave index whose clear triggers the halfway choice (level 15 of 30).
static func midpoint_wave_index(wave_count: int) -> int:
	return maxi(0, wave_count / 2 - 1)


static func player_scale(player_count: int, max_players := ClassicWintermaulLayout.PLAYER_COUNT) -> float:
	var clamped := clampi(player_count, 1, max_players)
	var t := float(clamped - 1) / float(maxi(1, max_players - 1))
	return lerpf(MIN_PLAYER_SCALE, MAX_PLAYER_SCALE, t)


static func starting_gold(player_count: int) -> int:
	return STARTING_GOLD + STARTING_GOLD_PER_EXTRA_PLAYER * (clampi(player_count, 1, ClassicWintermaulLayout.PLAYER_COUNT) - 1)


static func construction_seconds(gold_cost: int) -> float:
	return clampf(gold_cost * BUILD_SECONDS_PER_GOLD, MIN_BUILD_SECONDS, MAX_BUILD_SECONDS)


static func builder_speed_pixels(is_solo: bool) -> float:
	var cells := BUILDER_SPEED_CELLS * (SOLO_BUILDER_SPEED_MULTIPLIER if is_solo else 1.0)
	return cells * MapProjection.TILE_SIZE


static func build_duration_for_wave(wave_index: int, wave: WaveDefinition = null) -> float:
	if wave_index == 0:
		return WAVE_ONE_READY_TIMEOUT
	return wave.build_seconds if wave != null and wave.build_seconds > 0.0 else BUILD_DURATION
