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
## peer id -> gold. Every player has their own account (lives stay shared);
## the host's account also covers the positions it controls for absent players.
var peer_gold: Dictionary = {}
## peer id -> {kills, leaks, gold_spent, gold_sent, towers_built, trips}: who
## did what, for the end-of-run awards (RunAwards). Host only; in the results.
var peer_stats: Dictionary = {}
var roguelike_enabled := true
var lane_queued := PackedInt32Array()
var lane_spawned := PackedInt32Array()
## creep_id -> {"position": int, "definition_id": String, "health_multiplier": float}
var active_creeps: Dictionary = {}
## tower_id -> {"id", "definition_id", "cell": Vector2i, "position", "targeting", "invested"}
## An upgrade replaces definition_id with the chosen tree option; invested is
## the gold paid so far (it sets the sell value).
var towers: Dictionary = {}
## position_index -> owning peer id (0 = unfilled, host controls)
var position_owners := PackedInt32Array()
## peer id -> race id picked in the lobby (the host also builds its race's
## towers in the positions it controls for absent players).
var peer_races: Dictionary = {}
## Halfway choice (see BalanceConfig.midpoint_wave_index): peer id -> a second
## race whose towers that builder may also build...
var peer_bonus_races: Dictionary = {}
## ...or peer id -> Relics left, each allowing one race ultimate.
var peer_relics: Dictionary = {}
## Peers who still have to make the halfway choice (the build timer waits).
var midpoint_pending: Array[int] = []
var midpoint_done := false
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
	"gold_sent": 0,
	"boss_kills": 0,
}

var _next_tower_id := 1
var _next_creep_id := 1
## Host-only fractions of split bounties, carried until they make a whole coin.
var _gold_fractions: Dictionary = {}


func _init(total_waves := 5, starting_lives := 20, starting_gold := 100, position_count := 9) -> void:
	wave_count = total_waves
	shared_lives = starting_lives
	peer_gold = {BuildPermissionPolicy.HOST_PEER_ID: starting_gold}
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


# --- Gold (one account per player) -------------------------------------------

## Opens an account for every player and splits `starting_total` evenly;
## the host takes any remainder.
func open_accounts(peers: Array, starting_total: int) -> void:
	var host := BuildPermissionPolicy.HOST_PEER_ID
	var players: Array[int] = [host]
	for peer_id in peers:
		if not players.has(int(peer_id)):
			players.append(int(peer_id))
	peer_gold.clear()
	_gold_fractions.clear()
	var share := maxi(0, starting_total) / players.size()
	for peer_id in players:
		peer_gold[peer_id] = share
	peer_gold[host] += maxi(0, starting_total) - share * players.size()


func gold_of(peer_id: int) -> int:
	return int(peer_gold.get(peer_id, 0))


func set_gold(peer_id: int, amount: int) -> void:
	peer_gold[peer_id] = maxi(0, amount)


## Total gold across every account.
func total_gold() -> int:
	var total := 0
	for peer_id in peer_gold:
		total += int(peer_gold[peer_id])
	return total


## The player who controls (builds in, and earns for) a position.
func controller_of(position_index: int) -> int:
	var owner := position_owners[position_index] if position_index >= 0 and position_index < position_owners.size() else 0
	return owner if owner > 0 else BuildPermissionPolicy.HOST_PEER_ID


func spend_gold(peer_id: int, amount: int) -> bool:
	if amount < 0 or gold_of(peer_id) < amount:
		return false
	peer_gold[peer_id] = gold_of(peer_id) - amount
	stats["gold_spent"] += amount
	count_for(peer_id, "gold_spent", amount)
	return true


## Pays one player directly (counts as earned gold).
func award_gold(peer_id: int, amount: int) -> void:
	var clamped := maxi(0, amount)
	peer_gold[peer_id] = gold_of(peer_id) + clamped
	stats["gold_earned"] += clamped


## Splits team income (bounties, run-upgrade gold) into one share per
## position, paid to each position's controller, so income follows the
## positions a player defends. Fractions carry over between payouts.
func award_shared_gold(amount: int) -> void:
	var clamped := maxi(0, amount)
	if clamped == 0 or position_count <= 0:
		return
	stats["gold_earned"] += clamped
	var shares: Dictionary = {}
	for position_index in range(position_count):
		var peer_id := controller_of(position_index)
		shares[peer_id] = int(shares.get(peer_id, 0)) + 1
	for peer_id in shares:
		var exact := float(_gold_fractions.get(peer_id, 0.0)) + clamped * float(shares[peer_id]) / position_count
		var whole := floori(exact + 0.000001)
		_gold_fractions[peer_id] = exact - whole
		peer_gold[peer_id] = gold_of(peer_id) + whole


## Sell refunds return gold without counting as earned bounty.
func refund_gold(peer_id: int, amount: int) -> void:
	peer_gold[peer_id] = gold_of(peer_id) + maxi(0, amount)


## Sends gold between players. Returns false when the sender cannot cover it
## or the recipient has no account.
func transfer_gold(from_peer: int, to_peer: int, amount: int) -> bool:
	if amount <= 0 or from_peer == to_peer or not peer_gold.has(to_peer) or gold_of(from_peer) < amount:
		return false
	peer_gold[from_peer] = gold_of(from_peer) - amount
	peer_gold[to_peer] = gold_of(to_peer) + amount
	stats["gold_sent"] += amount
	count_for(from_peer, "gold_sent", amount)
	return true


## Adds to one player's award stats (see peer_stats).
func count_for(peer_id: int, key: String, amount := 1) -> void:
	var row: Dictionary = peer_stats.get(peer_id, {})
	row[key] = int(row.get(key, 0)) + amount
	peer_stats[peer_id] = row


## A leaving player's gold (and pending fractions) goes to `to_peer`.
func close_account(peer_id: int, to_peer: int) -> void:
	if peer_id == to_peer or not peer_gold.has(peer_id):
		return
	peer_gold[to_peer] = gold_of(to_peer) + gold_of(peer_id)
	_gold_fractions[to_peer] = float(_gold_fractions.get(to_peer, 0.0)) + float(_gold_fractions.get(peer_id, 0.0))
	peer_gold.erase(peer_id)
	_gold_fractions.erase(peer_id)


func add_lives(amount: int) -> void:
	shared_lives = maxi(0, shared_lives + amount)


func can_build() -> bool:
	return phase in [Phase.BUILD, Phase.WAVE]


func has_pending_offer() -> bool:
	return not pending_offer.is_empty()


func add_tower(definition_id: String, cell: Vector2i, position_index: int, targeting: int, invested := 0) -> Dictionary:
	var record := {
		"id": allocate_tower_id(),
		"definition_id": definition_id,
		"cell": cell,
		"position": position_index,
		"targeting": targeting,
		"invested": invested,
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


## Turns the tower into `definition_id` (a tree option) and adds `paid` to
## its investment. The caller validates the option.
func upgrade_tower(tower_id: int, definition_id: String, paid := 0) -> bool:
	if not towers.has(tower_id):
		return false
	towers[tower_id]["definition_id"] = definition_id
	towers[tower_id]["invested"] = int(towers[tower_id].get("invested", 0)) + paid
	stats["towers_upgraded"] += 1
	return true


func race_of(peer_id: int) -> String:
	return str(peer_races.get(peer_id, ""))


func bonus_race_of(peer_id: int) -> String:
	return str(peer_bonus_races.get(peer_id, ""))


func relics_of(peer_id: int) -> int:
	return int(peer_relics.get(peer_id, 0))


func has_midpoint_pending() -> bool:
	return not midpoint_pending.is_empty()


## Records a peer's halfway choice: "relic" or "race" (with `race_id`).
## The caller validates the race; returns false when the peer owes no choice.
func choose_midpoint(peer_id: int, choice: String, race_id := "") -> bool:
	if not midpoint_pending.has(peer_id):
		return false
	match choice:
		"relic":
			peer_relics[peer_id] = relics_of(peer_id) + 1
		"race":
			if race_id.is_empty():
				return false
			peer_bonus_races[peer_id] = race_id
		_:
			return false
	midpoint_pending.erase(peer_id)
	return true


func spend_relic(peer_id: int) -> bool:
	if relics_of(peer_id) <= 0:
		return false
	peer_relics[peer_id] = relics_of(peer_id) - 1
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
		"gold": peer_gold.duplicate(),
		"queued": lane_queued,
		"spawned": lane_spawned,
		"active_count": active_creeps.size(),
		"countdown": countdown,
		"towers": tower_records(),
		"owners": position_owners,
		"races": peer_races.duplicate(),
		"bonus_races": peer_bonus_races.duplicate(),
		"relics": peer_relics.duplicate(),
		"midpoint": midpoint_pending.duplicate(),
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
	var gold: Dictionary = data.get("gold", {})
	if not gold.is_empty():
		peer_gold.clear()
		for peer_id in gold:
			peer_gold[int(peer_id)] = int(gold[peer_id])
	lane_queued = PackedInt32Array(data.get("queued", lane_queued))
	lane_spawned = PackedInt32Array(data.get("spawned", lane_spawned))
	position_owners = PackedInt32Array(data.get("owners", position_owners))
	peer_races.clear()
	var races: Dictionary = data.get("races", {})
	for peer_id in races:
		peer_races[int(peer_id)] = str(races[peer_id])
	peer_bonus_races.clear()
	var bonus: Dictionary = data.get("bonus_races", {})
	for peer_id in bonus:
		peer_bonus_races[int(peer_id)] = str(bonus[peer_id])
	peer_relics.clear()
	var relics: Dictionary = data.get("relics", {})
	for peer_id in relics:
		peer_relics[int(peer_id)] = int(relics[peer_id])
	midpoint_pending.assign(data.get("midpoint", []))
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
		"gold": peer_gold.duplicate(),
		"peer_stats": peer_stats.duplicate(true),
	}
