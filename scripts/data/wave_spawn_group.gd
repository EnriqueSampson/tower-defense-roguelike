class_name WaveSpawnGroup
extends Resource

@export var creep: CreepDefinition
@export_range(1, 200, 1) var count := 5
@export_range(0.1, 10.0, 0.05) var spawn_interval := 0.8
@export_range(0.1, 1000.0, 0.01) var health_multiplier := 1.0
## Later levels pay more per kill so the economy keeps up with creep health.
@export_range(0.1, 100.0, 0.01) var bounty_multiplier := 1.0
@export_range(0.0, 60.0, 0.5) var delay_before := 0.0


func is_valid() -> bool:
	return creep != null and creep.is_valid() and count >= 1 and spawn_interval > 0.0 and health_multiplier > 0.0 and bounty_multiplier > 0.0
