class_name CreepDefinition
extends Resource

## Stable content ID used by wave groups and snapshots.
@export var id := "grunt"
@export var display_name := "Grunt"
@export var role := "Standard"
@export_multiline var description := "Steady ground creep."
@export var color := Color("c96b4a")
@export_range(3.0, 20.0, 0.5) var radius := 6.0
@export_range(1, 1000000, 1) var health := 10
@export_range(0.1, 20.0, 0.1) var speed := 4.0
@export_range(0, 1000, 1) var armor := 0
@export_range(0, 100000, 1) var bounty := 5
@export_range(0.0, 1000.0, 0.5) var regen_per_second := 0.0
@export var slow_immune := false
@export var is_boss := false
@export var tags: PackedStringArray = []


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and health >= 1 and speed > 0.0 and bounty >= 0


func trait_summary() -> String:
	var traits: PackedStringArray = []
	if is_boss:
		traits.append("BOSS")
	if armor > 0:
		traits.append("Armor %d" % armor)
	if regen_per_second > 0.0:
		traits.append("Regen %.1f/s" % regen_per_second)
	if slow_immune:
		traits.append("Slow immune")
	if speed >= 6.0:
		traits.append("Fast")
	elif speed <= 2.5:
		traits.append("Slow")
	return ", ".join(traits)
