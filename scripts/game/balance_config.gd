class_name BalanceConfig
extends RefCounted

## Central tuning knobs recorded from playtests. Content lives in resources;
## these are run-wide constants that are not tower or creep specific.
const STARTING_GOLD := 120
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


static func player_scale(player_count: int, max_players := ClassicWintermaulLayout.PLAYER_COUNT) -> float:
	var clamped := clampi(player_count, 1, max_players)
	var t := float(clamped - 1) / float(maxi(1, max_players - 1))
	return lerpf(MIN_PLAYER_SCALE, MAX_PLAYER_SCALE, t)


static func build_duration_for_wave(wave_index: int) -> float:
	return WAVE_ONE_READY_TIMEOUT if wave_index == 0 else BUILD_DURATION
