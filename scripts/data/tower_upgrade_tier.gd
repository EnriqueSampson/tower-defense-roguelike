class_name TowerUpgradeTier
extends Resource

@export var tier_name := "Mk II"
## Optional model override for this tier and above; see TowerDefinition.visual_scene.
@export var visual_scene: PackedScene
@export_range(0, 10000, 1) var cost := 40
@export_range(0.1, 10.0, 0.05) var damage_multiplier := 1.5
@export_range(-200.0, 400.0, 1.0) var range_bonus := 8.0
@export_range(0.1, 2.0, 0.01) var cooldown_multiplier := 0.92
@export_range(0.0, 200.0, 1.0) var splash_radius_bonus := 0.0
@export_range(0.0, 0.9, 0.01) var slow_factor_bonus := 0.0
@export_range(0.0, 10.0, 0.1) var slow_duration_bonus := 0.0
@export_range(0, 100, 1) var armor_pierce_bonus := 0
