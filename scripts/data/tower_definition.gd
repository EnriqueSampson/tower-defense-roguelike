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
## Depth in the race's upgrade tree: 1 for towers the builder builds, then
## one more per upgrade step.
@export_range(1, 6, 1) var tier := 1
## Tower IDs this tower can upgrade into (classic Wintermaul: an upgrade
## replaces the tower with another, sometimes with a choice of branches).
## The upgrade costs the target's `cost`.
@export var upgrade_options: PackedStringArray = []
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


func can_upgrade() -> bool:
	return not upgrade_options.is_empty()


## Refund for selling a tower that has `invested` gold in it so far.
func sell_value(invested: int, refund_percent_bonus := 0) -> int:
	var percent := clampi(sell_refund_percent + refund_percent_bonus, 0, 100)
	return int(floor(invested * percent / 100.0))


## Effective combat stats. Run modifiers are layered by the caller so resource
## files are never mutated.
func stats() -> Dictionary:
	return {
		"damage": damage,
		"range": attack_range,
		"cooldown": attack_cooldown,
		"splash_radius": splash_radius,
		"slow_factor": slow_factor,
		"slow_duration": slow_duration,
		"armor_pierce": armor_pierce,
		"projectile_speed": projectile_speed,
		"targets_ground": can_target_ground,
		"targets_air": can_target_air,
		"magic": is_magic,
		"detection_range": detection_range,
	}
