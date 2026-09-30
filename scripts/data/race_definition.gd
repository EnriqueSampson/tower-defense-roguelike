class_name RaceDefinition
extends Resource

## A builder race: the towers its builder can build, each the root of an
## upgrade tree (`TowerDefinition.upgrade_options`). Players pick a race in
## the lobby; the race ID is a wire-level identifier, never rename it.
@export var id := "humans"
@export var display_name := "Humans"
@export_multiline var description := ""
@export var color := Color("5b8fd6")
## Builder model (.glb), facing +Z with idle / walk / build / trip actions.
@export var builder_scene: PackedScene
## Towers the builder builds directly (tier 1). Upgrades reach the rest.
@export var towers: Array[TowerDefinition] = []
## The race's unique ultimate: built directly, once per Relic, for gold plus
## the Relic. Relics come from the halfway choice (BalanceConfig.MIDPOINT_*).
@export var ultimate: TowerDefinition


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and not towers.is_empty()


func has_root(tower_id: String) -> bool:
	for tower in towers:
		if tower != null and tower.id == tower_id:
			return true
	return false
