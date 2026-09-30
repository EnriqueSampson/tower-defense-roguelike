class_name CreepDefinition
extends Resource

## Stable content ID used by wave groups and snapshots.
@export var id := "grunt"
@export var display_name := "Grunt"
@export var role := "Standard"
@export_multiline var description := "Steady ground creep."
@export var color := Color("c96b4a")
## Optional model (.glb/.tscn) facing +Z, pivot at the feet, 1 unit per tile.
## A "walk" animation loops while moving. Empty keeps the procedural mesh.
@export var visual_scene: PackedScene
@export_range(3.0, 20.0, 0.5) var radius := 6.0
@export_range(1, 1000000, 1) var health := 10
@export_range(0.1, 20.0, 0.1) var speed := 4.0
@export_range(0, 1000, 1) var armor := 0
@export_range(0, 100000, 1) var bounty := 5
@export_range(0.0, 1000.0, 0.5) var regen_per_second := 0.0
@export var slow_immune := false
@export var is_boss := false
## Flies straight between route checkpoints, ignoring mazes; only towers with
## `can_target_air` can hit it.
@export var is_air := false
## Ignores damage and slows from magic towers (`TowerDefinition.is_magic`).
@export var magic_immune := false
## Towers can only target it inside a detector's range
## (`TowerDefinition.detection_range`, or a detection run upgrade).
@export var invisible := false
## On death, spawns `split_count` of this creep where it fell, continuing its
## route with the parent's health multiplier.
@export var split_into: CreepDefinition
@export_range(0, 20, 1) var split_count := 0
@export var tags: PackedStringArray = []


func is_valid() -> bool:
	if id.is_empty() or display_name.is_empty() or health < 1 or speed <= 0.0 or bounty < 0:
		return false
	return split_into == null or (split_into != self and split_count >= 1 and split_into.split_into == null)


func splits() -> bool:
	return split_into != null and split_count > 0


func trait_summary() -> String:
	var traits: PackedStringArray = []
	if is_boss:
		traits.append("BOSS")
	if armor > 0:
		traits.append("Armor %d" % armor)
	if regen_per_second > 0.0:
		traits.append("Regen %.1f/s" % regen_per_second)
	if is_air:
		traits.append("Air")
	if invisible:
		traits.append("Invisible")
	if magic_immune:
		traits.append("Magic immune")
	elif slow_immune:
		traits.append("Slow immune")
	if splits():
		traits.append("Splits into %d" % split_count)
	if speed >= 6.0:
		traits.append("Fast")
	elif speed <= 2.5:
		traits.append("Slow")
	return ", ".join(traits)
