class_name ContentCatalog
extends Resource

## Single registry of shipped content. Adding a tower, creep, wave, or upgrade
## means creating a resource and listing it here; controllers never hardcode
## content lists.
## Every tower of every race, roots and upgrades alike.
@export var towers: Array[TowerDefinition] = []
## Builder races; the first is the default for players who have not picked.
@export var races: Array[RaceDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var upgrades: Array[RunUpgradeDefinition] = []

var _tower_index: Dictionary = {}
var _creep_index: Dictionary = {}
var _upgrade_index: Dictionary = {}
var _wave_index: Dictionary = {}
var _race_index: Dictionary = {}
## tower id -> root tower id of its upgrade tree (its "line")
var _line_index: Dictionary = {}
## tower id -> race id
var _tower_race: Dictionary = {}


func get_tower(tower_id: String) -> TowerDefinition:
	_ensure_indexes()
	return _tower_index.get(tower_id)


func get_creep(creep_id: String) -> CreepDefinition:
	_ensure_indexes()
	return _creep_index.get(creep_id)


func get_upgrade(upgrade_id: String) -> RunUpgradeDefinition:
	_ensure_indexes()
	return _upgrade_index.get(upgrade_id)


func get_race(race_id: String) -> RaceDefinition:
	_ensure_indexes()
	return _race_index.get(race_id)


func default_race() -> RaceDefinition:
	return races[0] if not races.is_empty() else null


## Race ID if known, else the default race's.
func resolve_race_id(race_id: String) -> String:
	if get_race(race_id) != null:
		return race_id
	var fallback := default_race()
	return fallback.id if fallback != null else ""


## Root of a tower's upgrade tree. Run upgrades that name a tower apply to
## its whole line.
func line_of(tower_id: String) -> String:
	_ensure_indexes()
	return _line_index.get(tower_id, tower_id)


func race_of_tower(tower_id: String) -> String:
	_ensure_indexes()
	return _tower_race.get(tower_id, "")


## Every tower reachable from a race's roots, roots first.
func race_towers(race: RaceDefinition) -> Array[TowerDefinition]:
	var result: Array[TowerDefinition] = []
	var queue: Array[TowerDefinition] = []
	for root in race.towers:
		if root != null:
			queue.append(root)
	var seen: Dictionary = {}
	while not queue.is_empty():
		var tower: TowerDefinition = queue.pop_front()
		if seen.has(tower.id):
			continue
		seen[tower.id] = true
		result.append(tower)
		for next_id in tower.upgrade_options:
			var next := get_tower(next_id)
			if next != null:
				queue.append(next)
	return result


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
	problems.append_array(_validate_trees(seen))
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
		elif not upgrade.tower_id.is_empty() and line_of(upgrade.tower_id) != upgrade.tower_id:
			problems.append("upgrade %s must name the root of a tower line, not %s" % [upgrade.id, upgrade.tower_id])
	return problems


## Upgrade trees and races: options name known towers one tier up, trees
## have no cycles or merges, every tower belongs to exactly one race, and
## every race can detect invisible creeps.
func _validate_trees(seen: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for tower in towers:
		if tower == null:
			continue
		for next_id in tower.upgrade_options:
			var next := get_tower(next_id)
			if next == null:
				problems.append("tower %s upgrades into unknown tower %s" % [tower.id, next_id])
			elif next.tier != tower.tier + 1:
				problems.append("tower %s (tier %d) upgrades into %s (tier %d)" % [tower.id, tower.tier, next_id, next.tier])
	var owner: Dictionary = {}
	var race_ids: Dictionary = {}
	for race in races:
		if race == null or not race.is_valid():
			problems.append("invalid race definition")
			continue
		if race_ids.has(race.id):
			problems.append("duplicate race id %s" % race.id)
		race_ids[race.id] = true
		var detects := false
		var parents: Dictionary = {}
		for root in race.towers:
			if root == null or not seen.has("tower:" + root.id):
				problems.append("race %s lists a tower missing from the catalog" % race.id)
			elif root.tier != 1:
				problems.append("race %s builds %s, which is not a tier 1 tower" % [race.id, root.id])
		for tower in race_towers(race):
			if owner.has(tower.id) and owner[tower.id] != race.id:
				problems.append("tower %s belongs to races %s and %s" % [tower.id, owner[tower.id], race.id])
			owner[tower.id] = race.id
			detects = detects or tower.detection_range > 0.0
			for next_id in tower.upgrade_options:
				if parents.has(next_id):
					problems.append("tower %s is reached from both %s and %s" % [next_id, parents[next_id], tower.id])
				parents[next_id] = tower.id
		if not detects:
			problems.append("race %s has no way to detect invisible creeps" % race.id)
	if not races.is_empty():
		for tower in towers:
			if tower != null and not owner.has(tower.id):
				problems.append("tower %s belongs to no race" % tower.id)
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
	for race in races:
		if race == null:
			continue
		_race_index[race.id] = race
		for root in race.towers:
			if root == null:
				continue
			var queue: Array[TowerDefinition] = [root]
			while not queue.is_empty():
				var tower: TowerDefinition = queue.pop_front()
				if _line_index.has(tower.id):
					continue
				_line_index[tower.id] = root.id
				_tower_race[tower.id] = race.id
				for next_id in tower.upgrade_options:
					var next: TowerDefinition = _tower_index.get(next_id)
					if next != null:
						queue.append(next)


## A creep and the creep it splits into (split children never split again).
static func _with_splits(creep: CreepDefinition) -> Array[CreepDefinition]:
	var result: Array[CreepDefinition] = [creep]
	if creep.split_into != null:
		result.append(creep.split_into)
	return result
