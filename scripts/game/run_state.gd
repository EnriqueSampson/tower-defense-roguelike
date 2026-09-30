class_name RunState
extends RefCounted

## Host-authoritative run model. Everything here is the source of truth and is
## serialized into snapshots; presentation nodes only mirror it.

enum Phase {
	BUILD,
	WAVE,
	VICTORY,
	DEFEAT,
}

var phase := Phase.BUILD
var current_wave_index := 0
var wave_count := 0
var position_count := 9
var shared_lives := 20
var team_gold := 100
var roguelike_enabled := true
var lane_queued := PackedInt32Array()
var lane_spawned := PackedInt32Array()
## creep_id -> {"position": int, "definition_id": String, "health_multiplier": float}
var active_creeps: Dictionary = {}
## tower_id -> {"id", "definition_id", "cell": Vector2i, "tier", "position", "targeting"}
var towers: Dictionary = {}
## position_index -> owning peer id (0 = unfilled, host controls)
var position_owners := PackedInt32Array()
var run_seed := 0
var applied_upgrades: Array[String] = []
var pending_offer: Array[String] = []
var elapsed_seconds := 0.0
var stats := {
	"towers_built": 0,
	"towers_upgraded": 0,
	"towers_sold": 0,
	"kills": 0,
	"leaks": 0,
	"gold_spent": 0,
	"gold_earned": 0,
	"boss_kills": 0,
}

var _next_tower_id := 1
var _next_creep_id := 1


func _init(total_waves := 5, starting_lives := 20, starting_gold := 100, position_count := 9) -> void:
	wave_count = total_waves
	shared_lives = starting_lives
	team_gold = starting_gold
	self.position_count = position_count
	lane_queued.resize(self.position_count)
	lane_spawned.resize(self.position_count)
	position_owners.resize(self.position_count)
	position_owners.fill(0)


func allocate_tower_id() -> int:
	var tower_id := _next_tower_id
	_next_tower_id += 1
	return tower_id


func allocate_creep_id() -> int:
	var creep_id := _next_creep_id
	_next_creep_id += 1
	return creep_id


func begin_wave(counts: PackedInt32Array) -> void:
	phase = Phase.WAVE
	pending_offer.clear()
	lane_queued = PackedInt32Array()
	lane_queued.resize(position_count)
	for position_index in range(mini(position_count, counts.size())):
		lane_queued[position_index] = counts[position_index]
	lane_spawned.resize(position_count)
	lane_spawned.fill(0)
	active_creeps.clear()


func register_spawn(lane_id: int, creep_id: int, definition_id := "", health_multiplier := 1.0) -> bool:
	if phase != Phase.WAVE or lane_id < 0 or lane_id >= lane_queued.size():
		return false
	if lane_queued[lane_id] <= 0 or active_creeps.has(creep_id):
		return false
	lane_queued[lane_id] -= 1
	lane_spawned[lane_id] += 1
	active_creeps[creep_id] = {
		"position": lane_id,
		"definition_id": definition_id,
		"health_multiplier": health_multiplier,
	}
	return true


## Registers a creep born mid-wave (a splitter's child). It never counts
## against the position's spawn queue but must be resolved like any other.
func register_split(lane_id: int, creep_id: int, definition_id: String, health_multiplier := 1.0) -> bool:
	if phase != Phase.WAVE or lane_id < 0 or lane_id >= position_count or active_creeps.has(creep_id):
		return false
	active_creeps[creep_id] = {
		"position": lane_id,
		"definition_id": definition_id,
		"health_multiplier": health_multiplier,
	}
	return true


## Resolves a creep exactly once. Returns false for unknown or already
## resolved creeps so duplicate kill/leak reports cannot double count.
func resolve_creep(creep_id: int, leaked: bool) -> bool:
	if not active_creeps.has(creep_id):
		return false
	active_creeps.erase(creep_id)
	if leaked:
		stats["leaks"] += 1
		shared_lives = maxi(0, shared_lives - 1)
		if shared_lives == 0:
			phase = Phase.DEFEAT
			lane_queued.fill(0)
			active_creeps.clear()
	else:
		stats["kills"] += 1
	return true


func is_wave_clear() -> bool:
	if phase != Phase.WAVE or not active_creeps.is_empty():
		return false
	for queued in lane_queued:
		if queued > 0:
			return false
	return true


func advance_after_clear() -> void:
	if not is_wave_clear():
		return
	if current_wave_index >= wave_count - 1:
		phase = Phase.VICTORY
	else:
		current_wave_index += 1
		phase = Phase.BUILD


func spend_gold(amount: int) -> bool:
	if amount < 0 or team_gold < amount:
		return false
	team_gold -= amount
	stats["gold_spent"] += amount
	return true


func award_gold(amount: int) -> void:
	var clamped := maxi(0, amount)
	team_gold += clamped
	stats["gold_earned"] += clamped


## Sell refunds return gold without counting as earned bounty.
func refund_gold(amount: int) -> void:
	team_gold += maxi(0, amount)


func add_lives(amount: int) -> void:
	shared_lives = maxi(0, shared_lives + amount)


func can_build() -> bool:
	return phase in [Phase.BUILD, Phase.WAVE]


func has_pending_offer() -> bool:
	return not pending_offer.is_empty()


func add_tower(definition_id: String, cell: Vector2i, position_index: int, targeting: int, tier := 0) -> Dictionary:
	var record := {
		"id": allocate_tower_id(),
		"definition_id": definition_id,
		"cell": cell,
		"tier": tier,
		"position": position_index,
		"targeting": targeting,
	}
	towers[record["id"]] = record
	stats["towers_built"] += 1
	return record


func get_tower(tower_id: int) -> Dictionary:
	return towers.get(tower_id, {})


func remove_tower(tower_id: int) -> bool:
	if not towers.has(tower_id):
		return false
	towers.erase(tower_id)
	stats["towers_sold"] += 1
	return true


func upgrade_tower(tower_id: int) -> bool:
	if not towers.has(tower_id):
		return false
	towers[tower_id]["tier"] += 1
	stats["towers_upgraded"] += 1
	return true


func set_tower_targeting(tower_id: int, mode: int) -> bool:
	if not towers.has(tower_id) or not TowerTargeting.is_valid_mode(mode):
		return false
	towers[tower_id]["targeting"] = mode
	return true


func tower_at_cell(cell: Vector2i) -> Dictionary:
	for tower_id in towers:
		if towers[tower_id]["cell"] == cell:
			return towers[tower_id]
	return {}


func apply_upgrade(upgrade_id: String) -> bool:
	if applied_upgrades.has(upgrade_id):
		return false
	applied_upgrades.append(upgrade_id)
	pending_offer.clear()
	return true


func tower_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var ids := towers.keys()
	ids.sort()
	for tower_id in ids:
		records.append(towers[tower_id].duplicate())
	return records


func snapshot(countdown: float) -> Dictionary:
	return {
		"phase": phase,
		"wave_index": current_wave_index,
		"wave_count": wave_count,
		"lives": shared_lives,
		"gold": team_gold,
		"queued": lane_queued,
		"spawned": lane_spawned,
		"active_count": active_creeps.size(),
		"countdown": countdown,
		"towers": tower_records(),
		"owners": position_owners,
		"seed": run_seed,
		"upgrades": applied_upgrades.duplicate(),
		"offer": pending_offer.duplicate(),
		"elapsed": elapsed_seconds,
		"stats": stats.duplicate(),
		"next_tower_id": _next_tower_id,
		"next_creep_id": _next_creep_id,
	}


## Rebuilds authoritative fields from a snapshot. Used by tests and by any
## future host-migration path; clients only mirror presentation state today.
func restore(data: Dictionary) -> void:
	phase = int(data.get("phase", phase))
	current_wave_index = int(data.get("wave_index", current_wave_index))
	wave_count = int(data.get("wave_count", wave_count))
	shared_lives = int(data.get("lives", shared_lives))
	team_gold = int(data.get("gold", team_gold))
	lane_queued = PackedInt32Array(data.get("queued", lane_queued))
	lane_spawned = PackedInt32Array(data.get("spawned", lane_spawned))
	position_owners = PackedInt32Array(data.get("owners", position_owners))
	run_seed = int(data.get("seed", run_seed))
	applied_upgrades.assign(data.get("upgrades", []))
	pending_offer.assign(data.get("offer", []))
	elapsed_seconds = float(data.get("elapsed", elapsed_seconds))
	var restored_stats: Dictionary = data.get("stats", {})
	for key in restored_stats:
		stats[key] = restored_stats[key]
	towers.clear()
	for record in data.get("towers", []):
		towers[int(record["id"])] = record.duplicate()
	_next_tower_id = int(data.get("next_tower_id", _next_tower_id))
	_next_creep_id = int(data.get("next_creep_id", _next_creep_id))


func results() -> Dictionary:
	return {
		"phase": phase,
		"victory": phase == Phase.VICTORY,
		"wave_reached": current_wave_index + 1,
		"wave_count": wave_count,
		"duration": elapsed_seconds,
		"seed": run_seed,
		"upgrades": applied_upgrades.duplicate(),
		"stats": stats.duplicate(),
		"lives": shared_lives,
		"gold": team_gold,
	}
