class_name RunModifiers
extends RefCounted

## Aggregated effect of chosen run upgrades. Rebuilt from the ordered list of
## upgrade IDs so snapshots stay small and resource files are never mutated.
var applied_ids: Array[String] = []
## Bumped whenever the applied set changes, so callers can cache derived stats.
var revision := 0

var _catalog: ContentCatalog
var _applied: Array[RunUpgradeDefinition] = []
var _tags: Dictionary = {}


func _init(catalog: ContentCatalog) -> void:
	_catalog = catalog


func apply(upgrade: RunUpgradeDefinition) -> bool:
	if upgrade == null or applied_ids.has(upgrade.id):
		return false
	applied_ids.append(upgrade.id)
	_applied.append(upgrade)
	revision += 1
	for tag in upgrade.tags:
		_tags[tag] = true
	return true


func rebuild(upgrade_ids: Array) -> void:
	if upgrade_ids.size() == applied_ids.size():
		var unchanged := true
		for index in range(upgrade_ids.size()):
			unchanged = unchanged and str(upgrade_ids[index]) == applied_ids[index]
		if unchanged:
			return
	revision += 1
	applied_ids.clear()
	_applied.clear()
	_tags.clear()
	for upgrade_id in upgrade_ids:
		apply(_catalog.get_upgrade(str(upgrade_id)))


func has_upgrade(upgrade_id: String) -> bool:
	return applied_ids.has(upgrade_id)


func has_tag(tag: String) -> bool:
	return _tags.has(tag)


func applied_definitions() -> Array[RunUpgradeDefinition]:
	return _applied.duplicate()


## Layers run modifiers on top of a tower's stats. `line_id` is the root of
## the tower's upgrade tree (ContentCatalog.line_of): tower-specific upgrades
## apply to the whole line.
func modify_stats(base: Dictionary, line_id: String, in_final_position := false) -> Dictionary:
	var stats := base.duplicate()
	var damage := float(stats.get("damage", 1))
	for upgrade in _applied:
		if not upgrade.tower_id.is_empty() and upgrade.tower_id != line_id:
			continue
		damage *= upgrade.damage_multiplier
		stats["range"] = float(stats.get("range", 0.0)) + upgrade.range_bonus
		stats["cooldown"] = float(stats.get("cooldown", 1.0)) * upgrade.cooldown_multiplier
		stats["splash_radius"] = float(stats.get("splash_radius", 0.0)) + upgrade.splash_radius_bonus
		stats["slow_factor"] = float(stats.get("slow_factor", 0.0)) + upgrade.slow_factor_bonus
		if upgrade.slow_factor_bonus > 0.0 and float(stats.get("slow_duration", 0.0)) <= 0.0:
			stats["slow_duration"] = 1.5
		if upgrade.grants_detection:
			stats["detection_range"] = maxf(float(stats.get("detection_range", 0.0)), float(stats.get("range", 0.0)))
	if in_final_position:
		for upgrade in _applied:
			damage *= upgrade.final_position_damage_multiplier
	stats["damage"] = maxi(1, roundi(damage))
	stats["cooldown"] = maxf(0.05, float(stats.get("cooldown", 1.0)))
	stats["slow_factor"] = clampf(float(stats.get("slow_factor", 0.0)), 0.0, 0.9)
	return stats


func build_cost(base_cost: int) -> int:
	var cost := float(base_cost)
	for upgrade in _applied:
		cost *= upgrade.build_cost_multiplier
	return maxi(0, roundi(cost))


func upgrade_cost(base_cost: int) -> int:
	if base_cost < 0:
		return -1
	var cost := float(base_cost)
	for upgrade in _applied:
		cost *= upgrade.upgrade_cost_multiplier
	return maxi(0, roundi(cost))


func bounty(base_bounty: int) -> int:
	var amount := float(base_bounty)
	for upgrade in _applied:
		amount *= upgrade.bounty_multiplier
	return maxi(0, roundi(amount))


func sell_refund_bonus() -> int:
	var bonus := 0
	for upgrade in _applied:
		bonus += upgrade.sell_refund_bonus
	return bonus


func creep_speed_multiplier() -> float:
	var multiplier := 1.0
	for upgrade in _applied:
		multiplier *= upgrade.creep_speed_multiplier
	return multiplier


func summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for upgrade in _applied:
		lines.append("%s  ·  %s" % [upgrade.display_name, upgrade.category_name()])
	return lines
