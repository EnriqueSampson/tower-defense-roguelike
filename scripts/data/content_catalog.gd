class_name ContentCatalog
extends Resource

## Single registry of shipped content. Adding a tower, creep, wave, or upgrade
## means creating a resource and listing it here; controllers never hardcode
## content lists.
@export var towers: Array[TowerDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var upgrades: Array[RunUpgradeDefinition] = []

var _tower_index: Dictionary = {}
var _creep_index: Dictionary = {}
var _upgrade_index: Dictionary = {}
var _wave_index: Dictionary = {}


func get_tower(tower_id: String) -> TowerDefinition:
	_ensure_indexes()
	return _tower_index.get(tower_id)


func get_creep(creep_id: String) -> CreepDefinition:
	_ensure_indexes()
	return _creep_index.get(creep_id)


func get_upgrade(upgrade_id: String) -> RunUpgradeDefinition:
	_ensure_indexes()
	return _upgrade_index.get(upgrade_id)


func get_wave(wave_id: String) -> WaveDefinition:
	_ensure_indexes()
	return _wave_index.get(wave_id)


func creeps() -> Array[CreepDefinition]:
	_ensure_indexes()
	var result: Array[CreepDefinition] = []
	for creep_id in _creep_index:
		result.append(_creep_index[creep_id])
	return result


## Returns human-readable problems; empty means every definition is valid and
## every ID is unique.
func validate() -> Array[String]:
	var problems: Array[String] = []
	var seen: Dictionary = {}
	for tower in towers:
		if tower == null or not tower.is_valid():
			problems.append("invalid tower definition")
			continue
		if seen.has("tower:" + tower.id):
			problems.append("duplicate tower id %s" % tower.id)
		seen["tower:" + tower.id] = true
	var creep_ids: Dictionary = {}
	var previous_number := 0
	for wave in waves:
		if wave == null or not wave.is_valid():
			problems.append("invalid wave definition")
			continue
		if seen.has("wave:" + wave.id):
			problems.append("duplicate wave id %s" % wave.id)
		seen["wave:" + wave.id] = true
		if wave.number <= previous_number:
			problems.append("wave %s is out of order" % wave.id)
		previous_number = wave.number
		for group in wave.spawn_groups:
			for creep in _with_splits(group.creep):
				if creep_ids.has(creep.id) and creep_ids[creep.id] != creep:
					problems.append("creep id %s maps to two definitions" % creep.id)
				creep_ids[creep.id] = creep
	for upgrade in upgrades:
		if upgrade == null or not upgrade.is_valid():
			problems.append("invalid upgrade definition")
			continue
		if seen.has("upgrade:" + upgrade.id):
			problems.append("duplicate upgrade id %s" % upgrade.id)
		seen["upgrade:" + upgrade.id] = true
		if not upgrade.tower_id.is_empty() and not seen.has("tower:" + upgrade.tower_id):
			problems.append("upgrade %s targets unknown tower %s" % [upgrade.id, upgrade.tower_id])
	return problems


func _ensure_indexes() -> void:
	if not _tower_index.is_empty() or towers.is_empty():
		return
	for tower in towers:
		if tower != null:
			_tower_index[tower.id] = tower
	for wave in waves:
		if wave == null:
			continue
		_wave_index[wave.id] = wave
		for group in wave.spawn_groups:
			if group != null and group.creep != null:
				for creep in _with_splits(group.creep):
					_creep_index[creep.id] = creep
	for upgrade in upgrades:
		if upgrade != null:
			_upgrade_index[upgrade.id] = upgrade


## A creep and the creep it splits into (split children never split again).
static func _with_splits(creep: CreepDefinition) -> Array[CreepDefinition]:
	var result: Array[CreepDefinition] = [creep]
	if creep.split_into != null:
		result.append(creep.split_into)
	return result
