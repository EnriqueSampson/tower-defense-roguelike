extends SceneTree

## Headless balance harness (Phase 3): plays whole runs with scripted players
## who build only through builder orders, and reports leaks, lives and the
## gold curve per level.
##
##   godot --headless --fixed-fps 20 --path . --script res://tests/balance_harness.gd -- [options]
##
## --fixed-fps makes every frame advance the same game time however fast the
## machine runs it, so a 30-level run takes a few minutes and results do not
## depend on machine speed.
##
## Options:
##   --players=N       lobby size 1-9 (default 1). Each player gets a builder
##                     and a share of the nine positions, as a lobby would.
##   --strategy=NAME   maze (default): greedy mazing in each player's home
##                     position (Position 9 for the host); lazy: towers beside
##                     Position 9's route only, no mazing. Both build their
##                     race's towers in turn (detection included) and make
##                     every third purchase an upgrade, alternating branches.
##   --race=ID         every bot's race (humans, orcs, elves, bugs), or
##                     "mixed" to deal the races out in catalog order.
##                     Default: the catalog's default race.
##   --midpoint=WHAT   the halfway choice every bot makes: relic (default;
##                     then builds its race ultimate as soon as it can
##                     afford it) or race (recruits the next race in catalog
##                     order and mixes its towers in).
##   --waves=N         stop after N levels.
##   --seed=N          run seed (upgrade offers).
##   --out=PATH        also write the report as JSON.
##   --quiet           no per-level lines.
## Exit code 0 when the run finished (victory or defeat), 1 on timeout or when
## a tower was placed without a builder order.

const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"
const MAP_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap"
const REAL_TIMEOUT_MSEC := 1800000
## Spare gold above this goes into upgrades even while sites remain.
const UPGRADE_RESERVE := 150
const HOST := 1

var _options := {"players": 1, "strategy": "maze", "race": "", "midpoint": "relic", "waves": 0, "seed": 0, "out": "", "quiet": false}
var _game: Node
var _map: WintermaulMap
var _state: RunState
var _builders: BuilderSystem
var _catalog: ContentCatalog
## peer id -> Array[Vector2i] of candidate anchors, best first.
var _candidates: Dictionary = {}
var _ordered := 0
## peer id -> towers ordered plus upgrades bought
var _purchases: Dictionary = {}
## peer id -> towers ordered
var _built_by: Dictionary = {}
var _levels: Array[Dictionary] = []
var _level_start := {}
var _last_wave := -1
var _last_phase := -1
var _started_msec := 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts[0] == "quiet":
			_options["quiet"] = true
		elif parts.size() == 2 and _options.has(parts[0]):
			_options[parts[0]] = parts[1] if _options[parts[0]] is String else int(parts[1])
	var players := clampi(int(_options["players"]), 1, ClassicWintermaulLayout.PLAYER_COUNT)
	var session := root.get_node("SteamSession")
	session.set("is_solo_session", players == 1)
	root.get_node("GameSettings").set("controls_seen", true)
	# player_count() reads the roster size when each level begins.
	var roster: Array[Dictionary] = []
	for index in range(players):
		roster.append({"steam_id": 5000 + index, "lane": index + 1, "name": "Bot %d" % (index + 1)})
	session.set("roster", roster)
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_game)
	_map = _game.get_node(MAP_PATH) as WintermaulMap
	_state = _game.get("run_state")
	_builders = _game.get("builder_system")
	_catalog = _game.get("CATALOG")
	if int(_options["seed"]) != 0:
		_state.run_seed = int(_options["seed"])
	_assign_positions(players)
	_assign_races(players)
	for peer_id in _builders.builders:
		_candidates[peer_id] = _candidates_for(peer_id)
	_started_msec = Time.get_ticks_msec()
	print("BALANCE players=%d strategy=%s race=%s seed=%d levels=%d" % [players, _options["strategy"], _options["race"] if not str(_options["race"]).is_empty() else _state.race_of(HOST), _state.run_seed, _state.wave_count])


## Splits the nine positions between the bots like a lobby would (each bot
## its own position; the rest stay with the host), and gives each a builder.
func _assign_positions(players: int) -> void:
	var owners := PackedInt32Array()
	owners.resize(ClassicWintermaulLayout.PLAYER_COUNT)
	owners.fill(HOST)
	for index in range(1, players):
		owners[index] = HOST + index
	_state.position_owners = owners
	_state.open_accounts(Array(owners), BalanceConfig.starting_gold(players))
	_game.call("_ensure_builders")
	_game.call("_sync_builder_view")


func _assign_races(players: int) -> void:
	for index in range(players):
		var race_id := str(_options["race"])
		if race_id == "mixed":
			race_id = _catalog.races[index % _catalog.races.size()].id
		_state.peer_races[HOST + index] = _catalog.resolve_race_id(race_id)
	_game.call("_sync_builder_view")


## The tower a builder builds next: its race's roots in turn, with the
## generalist (first root) every other time.
func _next_definition(peer_id: int, built: int) -> String:
	var race := _catalog.get_race(_state.race_of(peer_id))
	var roots: Array[TowerDefinition] = race.towers.duplicate()
	var bonus := _catalog.get_race(_state.bonus_race_of(peer_id))
	if bonus != null:
		roots.append_array(bonus.towers)
	if built % 2 == 0:
		return roots[0].id
	return roots[(built / 2) % roots.size()].id


func _process(_delta: float) -> bool:
	if _game == null:
		return false
	if Time.get_ticks_msec() - _started_msec > REAL_TIMEOUT_MSEC:
		printerr("FAILED: the run timed out at level %d" % (_state.current_wave_index + 1))
		quit(1)
		return false
	_track_levels()
	if _state.phase in [RunState.Phase.VICTORY, RunState.Phase.DEFEAT] or (int(_options["waves"]) > 0 and _state.current_wave_index >= int(_options["waves"])):
		_finish()
		return false
	for peer_id in _state.midpoint_pending.duplicate():
		_choose_midpoint(peer_id)
	if _state.has_pending_offer():
		_game.call("_try_choose_upgrade", _state.pending_offer[0], HOST)
	for peer_id in _builders.builders:
		_play(peer_id)
	_ready_up_when_built()
	return false


## Level 1 waits for ready-up: press it once the starting gold is spent and
## every builder is idle, as a player would.
func _ready_up_when_built() -> void:
	if _state.current_wave_index != 0 or _state.phase != RunState.Phase.BUILD or bool(_game.get("_wave_one_ready_pressed")):
		return
	var cheapest := 1 << 30
	for tower: TowerDefinition in _catalog.towers:
		cheapest = mini(cheapest, tower.cost)
	var idle := true
	for peer_id in _builders.builders:
		idle = idle and _builders.get_orders(peer_id).is_empty()
	var richest := 0
	for peer_id in _builders.builders:
		richest = maxi(richest, _state.gold_of(peer_id))
	if idle and richest < cheapest:
		_game.call("_on_ready_pressed")


## One decision per builder per frame: once it is free, every UPGRADE_EVERY-th
## purchase is an upgrade, the rest are new towers; spare gold also goes
## into upgrades.
const UPGRADE_EVERY := 3


func _choose_midpoint(peer_id: int) -> void:
	if _options["midpoint"] == "race":
		var own := _state.race_of(peer_id)
		var index := 0
		for race_index in range(_catalog.races.size()):
			if _catalog.races[race_index].id == own:
				index = race_index
		var recruit := _catalog.races[(index + 1) % _catalog.races.size()].id
		_game.call("_try_choose_midpoint", peer_id, "race", recruit)
		_log_event("P%d recruits %s" % [peer_id, recruit])
	else:
		_game.call("_try_choose_midpoint", peer_id, "relic")
		_log_event("P%d takes a Relic" % peer_id)


## With a Relic and the gold, a bot builds its race ultimate, selling its
## cheapest tower in the home position when there is no room left.
func _try_build_ultimate(peer_id: int) -> bool:
	if _state.relics_of(peer_id) <= 0:
		return false
	var ultimate := _catalog.get_race(_state.race_of(peer_id)).ultimate
	var cost := (_game.get("modifiers") as RunModifiers).build_cost(ultimate.cost)
	if _state.gold_of(peer_id) < cost:
		return true
	var site := _next_site(peer_id, ultimate.id)
	if site.x < 0:
		site = _make_room(peer_id, ultimate.footprint)
	if site.x >= 0 and _game.call("_try_order_build", peer_id, ultimate.id, site, false) == WintermaulMap.Placement.OK:
		_ordered += 1
		_log_event("P%d builds %s" % [peer_id, ultimate.display_name])
	return true


func _make_room(peer_id: int, footprint: Vector2i) -> Vector2i:
	var cheapest := {}
	for record in _state.tower_records():
		if record.has("build_remaining") and float(record["build_remaining"]) > 0.0 or record.has("upgrade_to"):
			continue
		if not BuildPermissionPolicy.can_control(peer_id, int(record["position"]), _state.position_owners):
			continue
		if cheapest.is_empty() or int(record["invested"]) < int(cheapest["invested"]):
			cheapest = record
	if cheapest.is_empty() or not _game.call("_try_sell_tower", int(cheapest["id"]), peer_id):
		return Vector2i(-1, -1)
	var cell: Vector2i = cheapest["cell"]
	return cell if _map.evaluate_placement(cell, footprint) == WintermaulMap.Placement.OK else Vector2i(-1, -1)


var _events: Array[String] = []


func _log_event(text: String) -> void:
	_events.append("L%02d %s" % [_state.current_wave_index + 1, text])
	if not _options["quiet"]:
		print("  ", _events[-1])


func _play(peer_id: int) -> void:
	if not _builders.get_orders(peer_id).is_empty():
		return
	if _try_build_ultimate(peer_id):
		return
	var purchases: int = _purchases.get(peer_id, 0)
	if purchases % UPGRADE_EVERY == UPGRADE_EVERY - 1:
		if _upgrade_cheapest(peer_id):
			_purchases[peer_id] = purchases + 1
			return
	# Each builder walks the mix on its own, so every player builds detection.
	var built: int = _built_by.get(peer_id, 0)
	var definition_id := _next_definition(peer_id, built)
	var cost: int = (_game.get("modifiers") as RunModifiers).build_cost(_catalog.get_tower(definition_id).cost)
	if _state.gold_of(peer_id) >= cost:
		var site := _next_site(peer_id, definition_id)
		if site.x >= 0:
			if _game.call("_try_order_build", peer_id, definition_id, site, false) == WintermaulMap.Placement.OK:
				_ordered += 1
				_built_by[peer_id] = built + 1
				_purchases[peer_id] = purchases + 1
			return
	if _out_of_sites(peer_id) or _state.gold_of(peer_id) >= UPGRADE_RESERVE + cost:
		if _upgrade_cheapest(peer_id):
			_purchases[peer_id] = purchases + 1


func _upgrade_cheapest(peer_id: int) -> bool:
	var modifiers: RunModifiers = _game.get("modifiers")
	var best_id := 0
	var best_target := ""
	var best_cost := 1 << 30
	for record in _state.tower_records():
		if not BuildPermissionPolicy.can_control(peer_id, int(record["position"]), _state.position_owners):
			continue
		if record.has("build_remaining") and float(record["build_remaining"]) > 0.0 or record.has("upgrade_to"):
			continue
		var options := _catalog.get_tower(str(record["definition_id"])).upgrade_options
		if options.is_empty():
			continue
		# Alternate branches by tower id so both sides of a tree get used.
		var target := options[int(record["id"]) % options.size()]
		var cost := modifiers.upgrade_cost(_catalog.get_tower(target).cost)
		if cost < best_cost:
			best_cost = cost
			best_id = int(record["id"])
			best_target = target
	return best_id != 0 and _state.gold_of(peer_id) >= best_cost and _game.call("_try_upgrade_tower", best_id, best_target, peer_id)


# --- Strategies ---------------------------------------------------------------
#
# maze: greedy mazing. Each tower goes on (or right beside) the current creep
#   path of the builder's home position, so creeps detour around it; the
#   placement probe refuses anything that would seal the route. Home is
#   Position 9 for the host (every creep passes through it) and the roster
#   position for everyone else; other owned positions only once home is full.
# lazy: towers beside Position 9's original route only, no mazing. The floor a
#   run should punish.

## How far (cells) from the current path a maze tower may stand.
const MAZE_REACH := 2
const MAX_PROBES := 60

## peer id -> {positions: Array[int] (home first), exhausted: {}}
var _plans: Dictionary = {}
## position index -> Array[Vector2i] of tower anchors fully inside it
var _anchors: Dictionary = {}


func _candidates_for(peer_id: int) -> Array:
	var positions: Array[int] = []
	var home := ClassicWintermaulLayout.PLAYER_COUNT - 1 if peer_id == HOST else peer_id - HOST
	for position_index in [home, 8, 0, 1, 2, 3, 4, 5, 6, 7]:
		if positions.has(position_index):
			continue
		if not BuildPermissionPolicy.can_control(peer_id, position_index, _state.position_owners):
			continue
		if _options["strategy"] == "lazy" and position_index != ClassicWintermaulLayout.PLAYER_COUNT - 1:
			continue
		positions.append(position_index)
	_plans[peer_id] = {"positions": positions, "exhausted": {}}
	return _route_anchors(ClassicWintermaulLayout.PLAYER_COUNT - 1) if _options["strategy"] == "lazy" else []


func _out_of_sites(peer_id: int) -> bool:
	var plan: Dictionary = _plans[peer_id]
	if _options["strategy"] == "lazy":
		return (_candidates[peer_id] as Array).is_empty()
	return (plan["exhausted"] as Dictionary).size() >= (plan["positions"] as Array).size()


## Next anchor for `peer_id`, or (-1, -1) when it has nowhere left to build.
func _next_site(peer_id: int, definition_id: String) -> Vector2i:
	var footprint := _catalog.get_tower(definition_id).footprint
	if _options["strategy"] == "lazy":
		var sites: Array = _candidates[peer_id]
		while not sites.is_empty():
			var cell: Vector2i = sites.pop_front()
			if _map.evaluate_placement(cell, footprint) == WintermaulMap.Placement.OK:
				return cell
		return Vector2i(-1, -1)
	var plan: Dictionary = _plans[peer_id]
	for position_index: int in plan["positions"]:
		if (plan["exhausted"] as Dictionary).has(position_index):
			continue
		var site := _maze_site(position_index, footprint)
		if site.x >= 0:
			return site
		plan["exhausted"][position_index] = true
	return Vector2i(-1, -1)


## Best valid anchor on or beside the position's current path, nearest the
## position's exit first.
func _maze_site(position_index: int, footprint: Vector2i) -> Vector2i:
	var path := _current_path(position_index)
	var path_index: Dictionary = {}
	for step in range(path.size()):
		if _map.get_cell_position_index(path[step]) == position_index:
			path_index[path[step]] = step
	if path_index.is_empty():
		return Vector2i(-1, -1)
	var scored: Array = []
	for anchor: Vector2i in _position_anchors(position_index):
		var best_step := -1
		for cell in WintermaulMap.footprint_cells(anchor - Vector2i(MAZE_REACH, MAZE_REACH), footprint + Vector2i(MAZE_REACH * 2, MAZE_REACH * 2)):
			best_step = maxi(best_step, int(path_index.get(cell, -1)))
		if best_step >= 0:
			scored.append([best_step, anchor])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for index in range(mini(scored.size(), MAX_PROBES)):
		var anchor: Vector2i = scored[index][1]
		if _map.evaluate_placement(anchor, footprint) == WintermaulMap.Placement.OK:
			return anchor
	return Vector2i(-1, -1)


func _current_path(position_index: int) -> Array[Vector2i]:
	var start: Vector2i = _map.get_spawner_cells(position_index)[0]
	var end: Vector2i = ClassicWintermaulLayout.FINAL_GATE if position_index == ClassicWintermaulLayout.PLAYER_COUNT - 1 else _map.get_route_targets(position_index)[0]
	return _map.get_grid_path(start, end)


## Even-aligned 2x2 anchors whose four cells all belong to the position.
func _position_anchors(position_index: int) -> Array:
	if _anchors.has(position_index):
		return _anchors[position_index]
	var out: Array = []
	var bounds := _map.get_position_world_rect(position_index)
	var first := _map.world_to_grid(bounds.position)
	var last := _map.world_to_grid(bounds.end)
	for y in range(first.y - first.y % 2, last.y + 1, 2):
		for x in range(first.x - first.x % 2, last.x + 1, 2):
			var anchor := Vector2i(x, y)
			var inside := true
			for cell in WintermaulMap.footprint_cells(anchor, Vector2i(2, 2)):
				inside = inside and _map.get_cell_position_index(cell) == position_index
			if inside:
				out.append(anchor)
	_anchors[position_index] = out
	return out


func _route_anchors(position_index: int) -> Array:
	var path := _current_path(position_index)
	var seen: Dictionary = {}
	var out: Array = []
	for step in range(path.size() - 1, -1, -1):
		var cell: Vector2i = path[step]
		for offset in [Vector2i(2, -1), Vector2i(-4, -1), Vector2i(-1, 2), Vector2i(-1, -4)]:
			var anchor: Vector2i = cell + offset
			if seen.has(anchor) or _map.get_cell_position_index(anchor) != position_index:
				continue
			seen[anchor] = true
			out.append(anchor)
	return out


func _track_levels() -> void:
	var phase := _state.phase
	var wave := _state.current_wave_index
	if phase == RunState.Phase.WAVE and _last_phase != RunState.Phase.WAVE:
		_level_start = {
			"level": wave + 1,
			"title": (_catalog.waves[wave] as WaveDefinition).title,
			"gold_start": _state.total_gold(),
			"lives_start": _state.shared_lives,
			"leaks_start": int(_state.stats["leaks"]),
			"earned_start": int(_state.stats["gold_earned"]),
			"towers": _state.towers.size(),
			"invested": _invested(),
			"time_start": _state.elapsed_seconds,
		}
	elif _last_phase == RunState.Phase.WAVE and phase != RunState.Phase.WAVE and not _level_start.is_empty():
		# Creeps may have blocked every probe mid-level; look again each build.
		for plan: Dictionary in _plans.values():
			(plan["exhausted"] as Dictionary).clear()
		var level := _level_start.duplicate()
		level["leaks"] = int(_state.stats["leaks"]) - int(level["leaks_start"])
		level["lives_end"] = _state.shared_lives
		level["earned"] = int(_state.stats["gold_earned"]) - int(level["earned_start"])
		level["seconds"] = snappedf(_state.elapsed_seconds - float(level["time_start"]), 0.1)
		for key in ["leaks_start", "earned_start", "time_start"]:
			level.erase(key)
		_levels.append(level)
		if not _options["quiet"]:
			print("  L%02d %-26s leaks %3d  lives %3d  gold %5d  +%5d  towers %3d  invested %6d  %5.1fs" % [
				level["level"], level["title"], level["leaks"], level["lives_end"], level["gold_start"], level["earned"], level["towers"], level["invested"], level["seconds"]])
	_last_phase = phase
	_last_wave = wave


func _invested() -> int:
	var total := 0
	for record in _state.tower_records():
		total += int(record.get("invested", 0))
	return total


func _finish() -> void:
	var results := _state.results()
	var stats: Dictionary = results["stats"]
	# Orders can fail on arrival (another builder spent the gold, a creep
	# stepped on the site), so built <= ordered; more would mean a tower
	# appeared without a builder order.
	var only_builder: bool = int(stats["towers_built"]) <= _ordered
	var report := {
		"players": int(_options["players"]),
		"strategy": _options["strategy"],
		"races": _state.peer_races.duplicate(),
		"seed": _state.run_seed,
		"victory": results["victory"],
		"level_reached": results["wave_reached"],
		"level_count": results["wave_count"],
		"lives": results["lives"],
		"leaks": stats["leaks"],
		"kills": stats["kills"],
		"towers_built": stats["towers_built"],
		"all_by_builder": only_builder,
		"midpoint": _options["midpoint"],
		"events": _events,
		"upgrades": results["upgrades"],
		"game_seconds": snappedf(float(results["duration"]), 0.1),
		"levels": _levels,
	}
	print("BALANCE %s at level %d/%d  lives %d  leaks %d  kills %d  towers %d  all by builder: %s  %.0f s game time  %.0f s real" % [
		"VICTORY" if results["victory"] else ("DEFEAT" if _state.phase == RunState.Phase.DEFEAT else "STOPPED"),
		results["wave_reached"], results["wave_count"], results["lives"], stats["leaks"], stats["kills"],
		stats["towers_built"], only_builder, results["duration"], (Time.get_ticks_msec() - _started_msec) / 1000.0])
	print("BALANCE sponsor upgrades %d  viewers %d" % [(results["upgrades"] as Array).size(), _state.ratings])
	if not str(_options["out"]).is_empty():
		var file := FileAccess.open(str(_options["out"]), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	if not only_builder:
		printerr("FAILED: some towers were not placed through builder orders")
	quit(0 if only_builder else 1)
