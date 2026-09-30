class_name TowerDefinition
extends Resource

## Stable content ID used by RPCs, snapshots, and run upgrades. Never rename
## after a build ships; add a new definition instead.
@export var id := "bolt"
@export var display_name := "Bolt Tower"
@export var role := "Generalist"
@export_multiline var description := "Reliable single-target damage."
@export var primary_color := Color("315f58")
@export var accent_color := Color("e4b94f")
@export var footprint := Vector2i.ONE
## Optional model (.glb/.tscn) facing +Z, pivot at the footprint centre on the
## ground, 1 unit per tile. Empty keeps the procedural placeholder mesh.
@export var visual_scene: PackedScene
@export_range(0, 10000, 1) var cost := 25
@export_range(1, 10000, 1) var damage := 5
@export_range(1.0, 1000.0, 1.0) var attack_range := 105.0
@export_range(0.05, 10.0, 0.05) var attack_cooldown := 0.65
@export_range(60.0, 4000.0, 10.0) var projectile_speed := 620.0
@export_range(0.0, 300.0, 1.0) var splash_radius := 0.0
@export_range(0.0, 0.9, 0.01) var slow_factor := 0.0
@export_range(0.0, 20.0, 0.1) var slow_duration := 0.0
@export_range(0, 100, 1) var armor_pierce := 0
## Air creeps can only be hit by towers with `can_target_air`.
@export var can_target_ground := true
@export var can_target_air := true
## Magic attacks do nothing to magic-immune creeps.
@export var is_magic := false
## Reveals invisible creeps within this radius (sim pixels) for every tower.
@export_range(0.0, 1000.0, 1.0) var detection_range := 0.0
@export var default_targeting := TowerTargeting.Mode.FIRST
@export var upgrade_tiers: Array[TowerUpgradeTier] = []
@export_range(0, 100, 1) var sell_refund_percent := 70


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and cost >= 0
		and damage >= 1
		and attack_range > 0.0
		and attack_cooldown > 0.0
		and footprint.x >= 1
		and footprint.y >= 1
		and (can_target_ground or can_target_air)
		and sell_refund_percent >= 0
		and sell_refund_percent <= 100
	)


## Model for `tier` (0 = base): the latest tier override at or below it, else
## the base model. Null means use the procedural mesh.
func visual_scene_for_tier(tier: int) -> PackedScene:
	for index in range(mini(tier, upgrade_tiers.size()) - 1, -1, -1):
		if upgrade_tiers[index].visual_scene != null:
			return upgrade_tiers[index].visual_scene
	return visual_scene


func max_tier() -> int:
	return upgrade_tiers.size()


func tier_name(tier: int) -> String:
	if tier <= 0 or tier > upgrade_tiers.size():
		return "Mk I"
	return upgrade_tiers[tier - 1].tier_name


## Cost to move from `tier` to `tier + 1`, or -1 when no further tier exists.
func upgrade_cost(tier: int) -> int:
	if tier < 0 or tier >= upgrade_tiers.size():
		return -1
	return upgrade_tiers[tier].cost


func total_invested(tier: int) -> int:
	var total := cost
	for index in range(mini(tier, upgrade_tiers.size())):
		total += upgrade_tiers[index].cost
	return total


func sell_value(tier: int, refund_percent_bonus := 0) -> int:
	var percent := clampi(sell_refund_percent + refund_percent_bonus, 0, 100)
	return int(floor(total_invested(tier) * percent / 100.0))


## Effective combat stats for a tower at `tier`. Run modifiers are layered by
## the caller so resource files are never mutated.
func stats_for_tier(tier: int) -> Dictionary:
	var effective_damage := float(damage)
	var effective_range := attack_range
	var effective_cooldown := attack_cooldown
	var effective_splash := splash_radius
	var effective_slow := slow_factor
	var effective_slow_duration := slow_duration
	var effective_pierce := armor_pierce
	for index in range(mini(tier, upgrade_tiers.size())):
		var upgrade := upgrade_tiers[index]
		effective_damage *= upgrade.damage_multiplier
		effective_range += upgrade.range_bonus
		effective_cooldown *= upgrade.cooldown_multiplier
		effective_splash += upgrade.splash_radius_bonus
		effective_slow += upgrade.slow_factor_bonus
		effective_slow_duration += upgrade.slow_duration_bonus
		effective_pierce += upgrade.armor_pierce_bonus
	return {
		"damage": maxi(1, roundi(effective_damage)),
		"range": effective_range,
		"cooldown": maxf(0.05, effective_cooldown),
		"splash_radius": effective_splash,
		"slow_factor": clampf(effective_slow, 0.0, 0.9),
		"slow_duration": effective_slow_duration,
		"armor_pierce": effective_pierce,
		"projectile_speed": projectile_speed,
		"targets_ground": can_target_ground,
		"targets_air": can_target_air,
		"magic": is_magic,
		"detection_range": detection_range,
	}
