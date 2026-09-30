class_name BalanceConfig
extends RefCounted

## Central tuning knobs recorded from playtests. Content lives in resources;
## these are run-wide constants that are not tower or creep specific.
const STARTING_GOLD := 120
## Team gold is shared, so each extra player adds starting gold for their
## first towers (a Phase 6 retune will scale income too).
const STARTING_GOLD_PER_EXTRA_PLAYER := 60
const STARTING_LIVES := 20
const BUILD_DURATION := 25.0
## Wave 1 waits for every player to ready up, falling back to this timeout.
const WAVE_ONE_READY_TIMEOUT := 90.0
const OFFER_CHOICE_COUNT := 3
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
