class_name RunUpgradeDefinition
extends Resource

enum Category {
	TOWER,
	ECONOMY,
	DEFENSE,
	TRADEOFF,
}

## Stable upgrade ID recorded in snapshots and run results.
@export var id := "bolt_damage"
@export var display_name := "Hardened Bolts"
@export_multiline var description := "Bolt Towers deal 25% more damage."
@export var category := Category.TOWER
@export var tags: PackedStringArray = []
## Empty applies to every tower; otherwise only the listed tower ID.
@export var tower_id := ""
@export_range(0.1, 5.0, 0.01) var damage_multiplier := 1.0
@export_range(-100.0, 200.0, 1.0) var range_bonus := 0.0
@export_range(0.1, 3.0, 0.01) var cooldown_multiplier := 1.0
@export_range(0.0, 200.0, 1.0) var splash_radius_bonus := 0.0
@export_range(0.0, 0.5, 0.01) var slow_factor_bonus := 0.0
@export_range(0.1, 5.0, 0.01) var bounty_multiplier := 1.0
@export_range(0.1, 3.0, 0.01) var build_cost_multiplier := 1.0
@export_range(0.1, 3.0, 0.01) var upgrade_cost_multiplier := 1.0
@export_range(-50, 30, 1) var sell_refund_bonus := 0
@export_range(-20, 50, 1) var extra_lives := 0
@export_range(0, 5000, 5) var immediate_gold := 0
## Applies to towers built inside Position 9 on top of other modifiers.
@export_range(0.1, 5.0, 0.01) var final_position_damage_multiplier := 1.0
## Every affected tower detects invisible creeps within its own attack range.
@export var grants_detection := false
## Tradeoff knob: creeps move faster when above 1.0.
@export_range(0.5, 2.0, 0.01) var creep_speed_multiplier := 1.0
## Offer rules: requires one of these tags to already be owned; excluded when
## any of the excluded tags is already owned.
@export var requires_tags: PackedStringArray = []
@export var excludes_tags: PackedStringArray = []


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty()


func category_name() -> String:
	match category:
		Category.TOWER:
			return "Tower"
		Category.ECONOMY:
			return "Economy"
		Category.DEFENSE:
			return "Defense"
		Category.TRADEOFF:
			return "Tradeoff"
	return "Unknown"
