extends SceneTree

## Headless solo run played only through the builder (Phase 2 exit): every
## tower is a builder order that walks, constructs and pays on arrival. A
## simple scripted player lines the shared Position 9 route, then upgrades.
## Exit code 0 when the run reaches victory or defeat, 1 on timeout.
##   godot --headless --path . --script res://tests/solo_builder_run.gd
## Pass `-- --fast` for 8x game speed instead of 4x.

const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"
const MAP_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap"
const REAL_TIMEOUT_MSEC := 900000
## Build mix while lining the route: mostly Bolt, a Frost every fourth tower
## and a Cannon every fifth.
const MIX: Array[String] = ["bolt", "bolt", "bolt", "frost", "cannon"]

var _game: Node
var _map: WintermaulMap
var _state: RunState
var _builders: BuilderSystem
var _candidates: Array[Vector2i] = []
var _ordered := 0
var _built_ids: Dictionary = {}
var _last_wave := -1
var _started_msec := 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	Engine.time_scale = 8.0 if OS.get_cmdline_user_args().has("--fast") else 4.0
	root.get_node("SteamSession").set("is_solo_session", true)
	root.get_node("GameSettings").set("controls_seen", true)
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_game)
	_map = _game.get_node(MAP_PATH) as WintermaulMap
	_state = _game.get("run_state")
	_builders = _game.get("builder_system")
	_candidates = _route_candidates()
	_game.call("_on_ready_pressed")
	_started_msec = Time.get_ticks_msec()
	print("SOLO %d candidate sites along the Position 9 route, time scale %.0fx" % [_candidates.size(), Engine.time_scale])


func _process(_delta: float) -> bool:
	if _game == null:
		return false
	if Time.get_ticks_msec() - _started_msec > REAL_TIMEOUT_MSEC:
		printerr("FAILED: the solo builder run timed out at wave %d" % (_state.current_wave_index + 1))
		quit(1)
		return false
	if _state.phase in [RunState.Phase.VICTORY, RunState.Phase.DEFEAT]:
		_finish()
		return false
	if _state.has_pending_offer():
		_game.call("_try_choose_upgrade", _state.pending_offer[0])
	if _state.current_wave_index != _last_wave:
		_last_wave = _state.current_wave_index
		print("SOLO wave %d  lives %d  gold %d  towers %d" % [_last_wave + 1, _state.shared_lives, _state.team_gold, _state.towers.size()])
	_play()
	return false


## One decision per frame: order the next tower once the builder is free,
## otherwise spend spare gold on upgrades.
func _play() -> void:
	for record in _state.tower_records():
		_built_ids[int(record["id"])] = true
	if not _builders.get_orders(1).is_empty():
		return
	var definition_id := MIX[_ordered % MIX.size()]
	var cost: int = (_game.get("modifiers") as RunModifiers).build_cost((_game.get("CATALOG") as ContentCatalog).get_tower(definition_id).cost)
	if not _candidates.is_empty() and _state.team_gold >= cost:
		while not _candidates.is_empty():
			var cell: Vector2i = _candidates.pop_front()
			if _game.call("_try_order_build", 1, definition_id, cell, false) == WintermaulMap.Placement.OK:
				_ordered += 1
				return
		return
	if _candidates.is_empty() or _state.team_gold >= 150:
		for record in _state.tower_records():
			if _game.call("_try_upgrade_tower", int(record["id"]), 1):
				return


## Anchors two to three cells either side of Position 9's shortest route,
## nearest the gate first: every lane relays through it.
func _route_candidates() -> Array[Vector2i]:
	var path := _map.get_grid_path(_map.get_spawner_cells(8)[0], ClassicWintermaulLayout.FINAL_GATE)
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for index in range(path.size() - 1, -1, -1):
		var cell: Vector2i = path[index]
		for offset in [Vector2i(2, -1), Vector2i(-4, -1), Vector2i(-1, 2), Vector2i(-1, -4)]:
			var anchor: Vector2i = cell + offset
			if seen.has(anchor) or _map.get_cell_position_index(anchor) < 0:
				continue
			seen[anchor] = true
			out.append(anchor)
	return out


func _finish() -> void:
	var results := _state.results()
	var stats: Dictionary = results["stats"]
	print("SOLO %s at wave %d/%d  lives %d  kills %d  leaks %d  towers built %d (all by builder orders: %s)  %.0f s game time" % [
		"VICTORY" if results["victory"] else "DEFEAT",
		results["wave_reached"], results["wave_count"], results["lives"], stats["kills"], stats["leaks"],
		stats["towers_built"], _ordered == stats["towers_built"], results["duration"],
	])
	var only_builder: bool = _ordered == int(stats["towers_built"])
	if not only_builder:
		printerr("FAILED: some towers were not placed through builder orders")
	quit(0 if only_builder else 1)
