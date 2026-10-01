extends SceneTree

## Two-process local sync check (Phase 2 exit): a host and a client over ENet
## on localhost, no Steam. The host spawns the client, both drive the builder
## through the controller's input paths, and the host compares the client's
## view with its authoritative state. Exit code = failure count.
##   godot --headless --path . --script res://tests/net_sync.gd

const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"
const MAP_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap"
const P1_OPEN := Vector2i(20, 30)
const P2_OPEN := Vector2i(76, 40)
const P9_OPEN := Vector2i(80, 126)
const CONNECT_TIMEOUT := 10.0
## Host timeline (seconds after the client connects).
const BUILD_CHECK_AT := 12.0
const WAVE_CHECK_AT := 22.0
const CLIENT_READY_AT := 13.0

var _role := "host"
var _port := 0
var _digest_path := ""
var _game: Node
var _elapsed := 0.0
var _since_connect := -1.0
var _client_pid := 0
var _client_peer := 0
var _steps_done: Dictionary = {}
var _dump_timer := 0.0
var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "client":
		_role = "client"
		_port = int(args[1])
	else:
		_port = 20000 + randi() % 20000
	_digest_path = OS.get_user_data_dir().path_join("net_sync_client_%d.json" % _port)
	root.get_node("GameSettings").set("controls_seen", true)
	var peer := ENetMultiplayerPeer.new()
	if _role == "host":
		DirAccess.remove_absolute(_digest_path)
		if peer.create_server(_port, 2) != OK:
			_fail_and_quit("host could not open port %d" % _port)
			return
		root.multiplayer.multiplayer_peer = peer
		root.multiplayer.peer_connected.connect(_on_client_connected)
		_client_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/net_sync.gd", "--", "client", str(_port)])
		print("NET host listening on %d, client pid %d" % [_port, _client_pid])
	else:
		if peer.create_client("127.0.0.1", _port) != OK:
			_fail_and_quit("client could not connect")
			return
		root.multiplayer.multiplayer_peer = peer
		root.multiplayer.connected_to_server.connect(func() -> void: _since_connect = 0.0)


func _process(delta: float) -> bool:
	if _digest_path.is_empty():
		return false
	_elapsed += delta
	if _since_connect < 0.0:
		if _elapsed > CONNECT_TIMEOUT:
			_fail_and_quit("%s timed out waiting for the connection" % _role)
		return false
	_since_connect += delta
	if _role == "host":
		_host_step()
	else:
		_client_step(delta)
	return false


# --- Host ---------------------------------------------------------------------

func _on_client_connected(peer_id: int) -> void:
	_client_peer = peer_id
	_since_connect = 0.0
	_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_game)
	var state: RunState = _game.get("run_state")
	# Position 1 belongs to the client; the host keeps the other eight.
	state.position_owners[0] = peer_id
	state.open_accounts([peer_id], 2000)
	# The client plays Elves (as if picked in the lobby); the host plays Humans
	# whatever this machine's saved race preference is.
	state.peer_races[1] = "humans"
	state.peer_races[peer_id] = "elves"
	_game.call("_ensure_builders")
	_game.call("_sync_builder_view")
	_game.call("_mark_dirty")
	_game.call("_try_order_build", 1, "bolt", P9_OPEN, false)
	_game.call("_try_order_build", 1, "sentry", P9_OPEN + Vector2i(4, 0), true)


func _host_step() -> void:
	if _once("host_check_build", BUILD_CHECK_AT):
		_compare_build_state()
		# The halfway choice, opened early: the client answers over RPC.
		_game.call("_open_midpoint_choice")
		_game.call("_try_choose_midpoint", 1, "relic")
		_game.call("_on_ready_pressed")
	if _once("host_check_wave", WAVE_CHECK_AT):
		_compare_wave_state()
		if _client_pid > 0:
			OS.kill(_client_pid)
		DirAccess.remove_absolute(_digest_path)
		print("NET %s" % ("PASS: %d sync checks" % _checks if _failures == 0 else "FAIL: %d of %d sync checks failed" % [_failures, _checks]))
		quit(_failures)


func _compare_build_state() -> void:
	var client := _read_client_digest()
	# Round-trip through JSON so both sides compare with the same number types.
	var host: Dictionary = JSON.parse_string(JSON.stringify(_digest()))
	var state: RunState = _game.get("run_state")
	_check(not client.is_empty(), "the client reports its view")
	if client.is_empty():
		return
	_check(state.towers.size() == 4, "host built two towers and the client two (got %d)" % state.towers.size())
	_check(client["towers"] == host["towers"], "client tower records match the host\n  host   %s\n  client %s" % [host["towers"], client["towers"]])
	_check(client["map_towers"] == host["map_towers"], "client tower nodes match the host's (%s vs %s)" % [client["map_towers"], host["map_towers"]])
	_check(client["gold"] == host["gold"] and (host["gold"] as Dictionary).size() == 2, "client sees every player's gold as the host has it (%s vs %s)" % [client["gold"], host["gold"]])
	_check(int(state.stats["gold_sent"]) == 50, "the client sent 40 gold by button and 10 by /give, and an overdraft was refused (sent %d)" % int(state.stats["gold_sent"]))
	var host_chat: PackedStringArray = _game.get_node("%Hud").call("chat_history")
	_check(host_chat.has("Player %d: gg" % _client_peer), "the host sees the client's chat line (%s)" % host_chat)
	var client_chat: Array = client.get("chat", [])
	_check(client_chat.has("Player %d (you): gg" % _client_peer) and client_chat.any(func(line: String) -> bool: return line.begins_with("System: Sent 10 gold")), "the client sees its own line and a private System reply to /give (%s)" % [client_chat])
	_check(not host_chat.has("System: Sent 10 gold to Host."), "System replies go only to the player who ran the command")
	_check(state.get_tower(_tower_id_at(P2_OPEN)).is_empty(), "the client could not build in a host position")
	var client_tower := state.get_tower(_tower_id_at(P1_OPEN + Vector2i(4, 0)))
	_check(not client_tower.is_empty() and client_tower["definition_id"] == "elf_tide", "the client's builder built an Elf tower and upgraded it along its tree")
	_check(int(client["race"]) == 1, "the client sees its own race (Elves) from the snapshot")
	var host_builders: Dictionary = host["builders"]
	var client_builders: Dictionary = client["builders"]
	_check(host_builders.keys().size() == 2 and client_builders.keys() == host_builders.keys(), "both peers see both builders (%s vs %s)" % [host_builders.keys(), client_builders.keys()])
	for owner in host_builders:
		var a := Vector2(host_builders[owner][0], host_builders[owner][1])
		var b := Vector2(client_builders.get(owner, [INF, INF])[0], client_builders.get(owner, [INF, INF])[1])
		_check(a.distance_to(b) < 1.0, "idle builder %s sits at the same point on both peers (%s vs %s)" % [owner, a, b])
	var move_target := _client_move_target()
	var client_builder := Vector2(host_builders.get(str(_client_peer), [0, 0])[0], host_builders.get(str(_client_peer), [0, 0])[1])
	_check(client_builder.distance_to(move_target) < 1.0, "the client's move order walked its builder on the host")


func _compare_wave_state() -> void:
	var client := _read_client_digest()
	var state: RunState = _game.get("run_state")
	_check(state.bonus_race_of(_client_peer) == "bugs" and state.relics_of(1) == 1 and not state.has_midpoint_pending(), "the client's halfway choice reaches the host (recruited Bugs)")
	_check(state.phase == RunState.Phase.WAVE or state.current_wave_index > 0, "both players readying up starts wave one")
	if client.is_empty():
		return
	var host_creeps := _creep_positions()
	var client_creeps: Dictionary = client["creeps"]
	_check(not host_creeps.is_empty() and not client_creeps.is_empty(), "creeps are alive on both peers (%d host, %d client)" % [host_creeps.size(), client_creeps.size()])
	var shared := 0
	var worst := 0.0
	for creep_id in host_creeps:
		if client_creeps.has(creep_id):
			shared += 1
			var c: Array = client_creeps[creep_id]
			worst = maxf(worst, (host_creeps[creep_id] as Vector2).distance_to(Vector2(c[0], c[1])))
	_check(shared >= host_creeps.size() - 2, "the client tracks the host's creeps (%d of %d)" % [shared, host_creeps.size()])
	# The digest is up to 0.5 s older than the host's view; creeps move ~2 tiles/s.
	_check(worst < WintermaulMap.TILE_SIZE * 3.0, "client creep positions stay close to the host (worst %.1f px)" % worst)


func _read_client_digest() -> Dictionary:
	if not FileAccess.file_exists(_digest_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_digest_path))
	return parsed if parsed is Dictionary else {}


func _tower_id_at(cell: Vector2i) -> int:
	var state: RunState = _game.get("run_state")
	for record in state.tower_records():
		if record["cell"] == cell:
			return int(record["id"])
	return 0


# --- Client -------------------------------------------------------------------

func _client_step(delta: float) -> void:
	# Wait a moment so the host's game scene exists before our RPCs reach it.
	if _once("client_load", 1.0):
		_game = (load(GAME_SCENE_PATH) as PackedScene).instantiate()
		root.add_child(_game)
	if _game == null:
		return
	if _once("client_build", 2.0):
		_game.call("_on_palette_selected", "elf_archer")
		_game.call("_on_build_cell_requested", P1_OPEN)
	if _once("client_build_other", 2.5):
		# Not the client's position: the host must reject it.
		_game.call("_on_palette_selected", "elf_archer")
		_game.call("_on_build_cell_requested", P2_OPEN)
	if _once("client_build_second", 4.5):
		_game.call("_on_palette_selected", "frost")
		_game.call("_on_build_cell_requested", P1_OPEN + Vector2i(4, 0))
	# Upgrade once the tower has finished building (construction time depends
	# on frame pacing, so retry every half second instead of a fixed moment).
	if _since_connect >= 8.5 and not _steps_done.has("client_upgrade") and _once("client_upgrade_try_%d" % int(_since_connect * 2.0), 0.0):
		for record in (_game.get("_latest_snapshot") as Dictionary).get("towers", []):
			if record["cell"] == P1_OPEN + Vector2i(4, 0):
				if record["definition_id"] != "frost" or float(record.get("upgrade_remaining", 0.0)) > 0.0:
					_steps_done["client_upgrade"] = true
				elif float(record.get("build_remaining", 0.0)) <= 0.0:
					_game.call("_on_upgrade_requested", int(record["id"]), "elf_tide")
	if _once("client_send_gold", 8.8):
		_game.call("_on_send_gold_requested", 1, 40)
		# More than the client has: the host must refuse it.
		_game.call("_on_send_gold_requested", 1, 999999)
	if _once("client_chat", 8.9):
		_game.call("_on_chat_submitted", "gg")
		# Position 2 is the host's: the host gets 10 more gold.
		_game.call("_on_chat_submitted", "/give 10 p2")
	if _once("client_move", 9.0):
		_game.call("_clear_selection")
		_game.call("_on_move_requested", _client_move_target(), false)
	if _once("client_midpoint", CLIENT_READY_AT - 0.5):
		_game.call("_on_midpoint_chosen", "race", "bugs")
	if _once("client_ready", CLIENT_READY_AT):
		_game.call("_on_ready_pressed")
	_dump_timer -= delta
	if _dump_timer <= 0.0:
		_dump_timer = 0.25
		var file := FileAccess.open(_digest_path + ".tmp", FileAccess.WRITE)
		file.store_string(JSON.stringify(_digest()))
		file.close()
		DirAccess.rename_absolute(_digest_path + ".tmp", _digest_path)


func _client_move_target() -> Vector2:
	return (Vector2(P1_OPEN + Vector2i(-2, 6)) + Vector2(0.5, 0.5)) * WintermaulMap.TILE_SIZE


# --- Shared -------------------------------------------------------------------

## JSON-friendly view of what this peer shows: tower records and nodes, gold,
## builder positions and creep positions.
func _digest() -> Dictionary:
	var snapshot: Dictionary = _game.get("_latest_snapshot")
	var map := _game.get_node(MAP_PATH) as WintermaulMap
	var towers: Array = []
	for record in snapshot.get("towers", []):
		towers.append([int(record["id"]), record["definition_id"], record["cell"].x, record["cell"].y, int(record.get("invested", 0)), float(record.get("build_remaining", 0.0)) > 0.0])
	var map_towers: Array = []
	for child in map.get_node("Towers").get_children():
		if child is Tower and not child.is_queued_for_deletion():
			map_towers.append(child.tower_id)
	map_towers.sort()
	var builders: Dictionary = {}
	for record in _game.get("_builder_records"):
		var builder := map.get_builder(int(record["owner"]))
		if builder != null:
			builders[str(record["owner"])] = [builder.plane_position.x, builder.plane_position.y]
	var creeps: Dictionary = {}
	for creep_id in _creep_positions():
		var point: Vector2 = _creep_positions()[creep_id]
		creeps[creep_id] = [point.x, point.y]
	var races: Dictionary = snapshot.get("races", {})
	var elves := 1 if str(races.get(_game.multiplayer.get_unique_id(), "")) == "elves" else 0
	return {"race": elves, "gold": snapshot.get("gold", {}), "chat": Array(_game.get_node("%Hud").call("chat_history")), "towers": towers, "map_towers": map_towers, "builders": builders, "creeps": creeps}


func _creep_positions() -> Dictionary:
	var positions: Dictionary = {}
	for runner: RouteRunner in (_game.get_node(MAP_PATH) as WintermaulMap).get_active_creeps():
		positions[str(runner.creep_id)] = runner.plane_position
	return positions


func _once(key: String, at_seconds: float) -> bool:
	if _steps_done.has(key) or _since_connect < at_seconds:
		return false
	_steps_done[key] = true
	return true


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAILED: %s" % description)


func _fail_and_quit(message: String) -> void:
	printerr("FAILED: %s" % message)
	if _client_pid > 0:
		OS.kill(_client_pid)
	quit(1)
