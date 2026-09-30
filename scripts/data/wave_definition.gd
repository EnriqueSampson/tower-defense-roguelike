class_name WaveDefinition
extends Resource

## Stable wave ID recorded in snapshots and results.
@export var id := "wave_01"
@export_range(1, 99, 1) var number := 1
@export var title := "Scouts"
@export var spawn_groups: Array[WaveSpawnGroup] = []
@export var is_boss_wave := false
## Waves whose clear triggers a run-upgrade offer.
@export var offers_upgrade_after := false
## Seconds of build time before this level (0 = BalanceConfig.BUILD_DURATION).
## Boss levels get longer to prepare. Wave 1 always waits for ready-up.
@export_range(0.0, 120.0, 1.0) var build_seconds := 0.0


func is_valid() -> bool:
	if id.is_empty() or spawn_groups.is_empty():
		return false
	for group in spawn_groups:
		if group == null or not group.is_valid():
			return false
	return true


func base_creep_count() -> int:
	var total := 0
	for group in spawn_groups:
		total += group.count
	return total


## Native creep count for one position after the classic nine-position
## multipliers and the team-size load scale.
func creep_count_for_lane(lane_id: int, player_scale := 1.0) -> int:
	var multiplier := ClassicWintermaulLayout.get_wave_multiplier(lane_id)
	if multiplier <= 0.0:
		return 0
	var total := 0
	for group in spawn_groups:
		total += _scaled_group_count(group, multiplier, player_scale)
	return total


## Ordered, deterministic spawn queue for one position. Each entry:
## {creep_id, health_multiplier, bounty_multiplier, delay} where delay is seconds after the
## previous entry.
func build_spawn_queue(lane_id: int, player_scale := 1.0) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var multiplier := ClassicWintermaulLayout.get_wave_multiplier(lane_id)
	if multiplier <= 0.0:
		return queue
	for group in spawn_groups:
		var count := _scaled_group_count(group, multiplier, player_scale)
		for index in range(count):
			var delay := group.spawn_interval
			if index == 0:
				delay = group.delay_before if queue.is_empty() else group.delay_before + group.spawn_interval
			queue.append({
				"creep_id": group.creep.id,
				"health_multiplier": group.health_multiplier,
				"bounty_multiplier": group.bounty_multiplier,
				"delay": delay,
			})
	return queue


func preview_lines() -> Array[String]:
	var lines: Array[String] = []
	for group in spawn_groups:
		var creep := group.creep
		var traits := creep.trait_summary()
		var line := "%dx %s" % [group.count, creep.display_name]
		if not traits.is_empty():
			line += "  (%s)" % traits
		lines.append(line)
	return lines


func has_boss() -> bool:
	if is_boss_wave:
		return true
	for group in spawn_groups:
		if group.creep != null and group.creep.is_boss:
			return true
	return false


func _scaled_group_count(group: WaveSpawnGroup, multiplier: float, player_scale: float) -> int:
	if group.creep != null and group.creep.is_boss:
		return group.count
	return maxi(1, roundi(group.count * multiplier * player_scale))
