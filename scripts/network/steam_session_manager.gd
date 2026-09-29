extends Node

const LobbyPolicy = preload("res://scripts/network/lobby_match_policy.gd")

signal status_changed(message: String, is_error: bool)
signal lobby_list_updated(lobbies: Array)
signal lobby_changed(lobby_id: int, is_host: bool)
signal roster_changed(members: Array)
signal game_start_requested
signal game_end_requested

const MAX_PLAYERS := 9
const VIRTUAL_PORT := 0
const PROTOCOL_VERSION := BuildInfo.PROTOCOL_VERSION
const GAME_TAG := BuildInfo.GAME_TAG
const MAP_ID := BuildInfo.MAP_ID
const LOBBY_STATE_WAITING := "waiting"
const LOBBY_STATE_IN_GAME := "in_game"

var lobby_id := 0
var lobby_results: Array[Dictionary] = []
var roster: Array[Dictionary] = []
var is_host := false
var is_solo_session := false
## Chosen in the pre-launch Map Options prompt; applied to the run when it starts.
var roguelike_enabled := true
var last_status := ""
var last_status_is_error := false
var _quick_match_pending := false
var _peer: SteamMultiplayerPeer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	status_changed.connect(func(message: String, is_error: bool) -> void:
		last_status = message
		last_status_is_error = is_error)
	Steamworks.initialization_changed.connect(_on_steam_initialization_changed)
	Steamworks.lobby_join_requested.connect(join_lobby)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if Steamworks.is_initialized:
		_connect_steam_signals()
	var pending_lobby_id: int = Steamworks.consume_pending_lobby_id()
	if pending_lobby_id > 0:
		join_lobby.call_deferred(pending_lobby_id)


func create_lobby(visibility: int) -> void:
	if not _require_steam():
		return
	if lobby_id != 0:
		leave_lobby()
	status_changed.emit("Creating Steam lobby...", false)
	Steam.createLobby(visibility, MAX_PLAYERS)


func search_lobbies(distance_filter: int, quick_match := false) -> void:
	if not _require_steam():
		return
	_quick_match_pending = quick_match
	lobby_results.clear()
	status_changed.emit("Searching public Steam lobbies...", false)
	Steam.addRequestLobbyListStringFilter("game", GAME_TAG, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter("protocol", PROTOCOL_VERSION, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter("build", _build_id(), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter("state", LOBBY_STATE_WAITING, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListFilterSlotsAvailable(1)
	Steam.addRequestLobbyListDistanceFilter(distance_filter)
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()


func quick_match() -> void:
	search_lobbies(Steam.LOBBY_DISTANCE_FILTER_DEFAULT, true)


func join_lobby(target_lobby_id: int) -> void:
	if not _require_steam() or target_lobby_id <= 0:
		return
	status_changed.emit("Joining Steam lobby %s..." % target_lobby_id, false)
	Steam.joinLobby(target_lobby_id)


func invite_friends() -> void:
	if lobby_id == 0:
		status_changed.emit("Create or join a lobby before inviting friends.", true)
		return
	Steam.activateGameOverlayInviteDialog(lobby_id)


func start_game() -> void:
	if not is_host or lobby_id == 0:
		status_changed.emit("Only the lobby host can start the session.", true)
		return
	Steam.setLobbyData(lobby_id, "state", LOBBY_STATE_IN_GAME)
	Steam.setLobbyJoinable(lobby_id, false)
	_begin_game.rpc()


func start_solo_game() -> void:
	if lobby_id != 0:
		leave_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = true
	is_solo_session = true
	roster = [{
		"steam_id": Steamworks.steam_id,
		"name": Steamworks.persona_name if Steamworks.is_initialized else "Solo Defender",
		"is_host": true,
		"lane": 1,
	}]
	roster_changed.emit(roster)
	status_changed.emit("Starting a solo defense with all nine positions active.", false)
	game_start_requested.emit()


func get_local_position_number() -> int:
	for member in roster:
		if int(member.get("steam_id", -1)) == Steamworks.steam_id:
			var position_number := int(member.get("lane", -1))
			return position_number if position_number in range(1, MAX_PLAYERS + 1) else -1
	return -1


## Multiplayer peer id for a roster member, or 0 when the transport does not
## know the Steam ID yet. The host is always peer 1.
func get_peer_id_for_steam_id(steam_id: int) -> int:
	if steam_id == Steamworks.steam_id and is_host:
		return 1
	if _peer == null:
		return 0
	return int(_peer.get_peer_id_for_steam_id(steam_id))


## peer_id -> display name for every roster member with a known peer.
func get_peer_names() -> Dictionary:
	var names: Dictionary = {}
	for member in roster:
		var peer_id := get_peer_id_for_steam_id(int(member.get("steam_id", 0)))
		if peer_id > 0:
			names[peer_id] = str(member.get("name", "Player"))
	return names


func player_count() -> int:
	return maxi(1, roster.size())


## Ends the current run for everyone and returns to the lobby scene. The host
## keeps the Steam lobby open so the same group can start another run.
func return_to_lobby() -> void:
	if is_solo_session or lobby_id == 0:
		leave_lobby()
		game_end_requested.emit()
		return
	if not is_host:
		status_changed.emit("Waiting in the lobby for the host to start another defense.", false)
		game_end_requested.emit()
		return
	if Steamworks.is_initialized:
		Steam.setLobbyData(lobby_id, "state", LOBBY_STATE_WAITING)
		Steam.setLobbyJoinable(lobby_id, true)
	_end_game.rpc()


@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	status_changed.emit("Lobby locked. Loading the defense map...", false)
	game_start_requested.emit()


@rpc("authority", "call_local", "reliable")
func _end_game() -> void:
	status_changed.emit("Run complete. The lobby is open for another defense.", false)
	game_end_requested.emit()


func leave_lobby() -> void:
	var was_solo := is_solo_session
	if lobby_id != 0 and Steamworks.is_initialized:
		Steam.leaveLobby(lobby_id)
	lobby_id = 0
	is_host = false
	is_solo_session = false
	roster.clear()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster_changed.emit(roster)
	lobby_changed.emit(0, false)
	status_changed.emit("Solo defense ended." if was_solo else "Left the Steam lobby.", false)


func _connect_steam_signals() -> void:
	if Steam.lobby_created.is_connected(_on_lobby_created):
		return
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_data_update.connect(_on_lobby_data_update)


func _on_steam_initialization_changed(available: bool, message: String) -> void:
	status_changed.emit(message, not available)
	if available:
		_connect_steam_signals()


func _on_lobby_created(connect_status: int, created_lobby_id: int) -> void:
	if connect_status != 1:
		status_changed.emit("Steam could not create the lobby (result %s)." % connect_status, true)
		return

	lobby_id = created_lobby_id
	is_host = true
	Steam.setLobbyData(lobby_id, "game", GAME_TAG)
	Steam.setLobbyData(lobby_id, "protocol", PROTOCOL_VERSION)
	Steam.setLobbyData(lobby_id, "build", _build_id())
	Steam.setLobbyData(lobby_id, "map", MAP_ID)
	Steam.setLobbyData(lobby_id, "state", LOBBY_STATE_WAITING)
	Steam.setLobbyData(lobby_id, "host_name", Steamworks.persona_name)
	Steam.setLobbyData(lobby_id, "roguelike", "true" if roguelike_enabled else "false")

	_peer = SteamMultiplayerPeer.new()
	_peer.server_relay = true
	var error := _peer.create_host(VIRTUAL_PORT)
	if error != OK:
		status_changed.emit("Steam host transport failed (error %s)." % error, true)
		leave_lobby()
		return
	multiplayer.multiplayer_peer = _peer
	_refresh_roster()
	lobby_changed.emit(lobby_id, true)
	status_changed.emit("Steam lobby ready for players.", false)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status_changed.emit("Steam lobby join failed (response %s)." % response, true)
		return

	lobby_id = joined_lobby_id
	var owner_steam_id := Steam.getLobbyOwner(lobby_id)
	is_host = owner_steam_id == Steamworks.steam_id
	if not is_host:
		_peer = SteamMultiplayerPeer.new()
		_peer.server_relay = true
		var error := _peer.create_client(owner_steam_id, VIRTUAL_PORT)
		if error != OK:
			status_changed.emit("Steam client transport failed (error %s)." % error, true)
			leave_lobby()
			return
		multiplayer.multiplayer_peer = _peer
	_refresh_roster()
	lobby_changed.emit(lobby_id, is_host)
	var host_name := Steam.getLobbyData(lobby_id, "host_name")
	status_changed.emit("Hosting lobby." if is_host else "Joined %s's lobby." % host_name, false)


func _on_lobby_match_list(lobbies: Array) -> void:
	lobby_results.clear()
	for result_lobby_id in lobbies:
		var metadata := {
			"game": Steam.getLobbyData(result_lobby_id, "game"),
			"protocol": Steam.getLobbyData(result_lobby_id, "protocol"),
			"build": Steam.getLobbyData(result_lobby_id, "build"),
			"map": Steam.getLobbyData(result_lobby_id, "map"),
			"state": Steam.getLobbyData(result_lobby_id, "state"),
			"roguelike": Steam.getLobbyData(result_lobby_id, "roguelike"),
		}
		var member_count := Steam.getNumLobbyMembers(result_lobby_id)
		var member_limit := Steam.getLobbyMemberLimit(result_lobby_id)
		if not LobbyPolicy.is_compatible(
			metadata,
			member_count,
			member_limit,
			GAME_TAG,
			PROTOCOL_VERSION,
			_build_id(),
			MAP_ID
		):
			continue
		lobby_results.append({
			"id": int(result_lobby_id),
			"host_name": Steam.getLobbyData(result_lobby_id, "host_name"),
			"map": metadata["map"],
			"members": member_count,
			"limit": member_limit,
			"roguelike": metadata["roguelike"] == "true",
		})
	lobby_list_updated.emit(lobby_results)
	if _quick_match_pending:
		_quick_match_pending = false
		var selected_lobby_id := LobbyPolicy.select_quick_match(lobby_results)
		if selected_lobby_id == 0:
			status_changed.emit("No compatible lobby found; creating a public lobby.", false)
			create_lobby(Steam.LOBBY_TYPE_PUBLIC)
		else:
			join_lobby(selected_lobby_id)
	elif lobby_results.is_empty():
		status_changed.emit("No compatible public lobbies found.", false)
	else:
		status_changed.emit("Found %s compatible lobby or lobbies." % lobby_results.size(), false)


func _refresh_roster() -> void:
	roster.clear()
	if lobby_id == 0:
		roster_changed.emit(roster)
		return
	var member_count := Steam.getNumLobbyMembers(lobby_id)
	for member_index in range(member_count):
		var member_steam_id := Steam.getLobbyMemberByIndex(lobby_id, member_index)
		roster.append({
			"steam_id": member_steam_id,
			"name": Steam.getFriendPersonaName(member_steam_id),
			"is_host": member_steam_id == Steam.getLobbyOwner(lobby_id),
			"lane": member_index + 1,
		})
	roster_changed.emit(roster)


func _on_lobby_chat_update(updated_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	if updated_lobby_id == lobby_id:
		_refresh_roster()


func _on_lobby_data_update(_success: int, updated_lobby_id: int, _member_id: int) -> void:
	if updated_lobby_id == lobby_id:
		_refresh_roster()


func _on_peer_connected(peer_id: int) -> void:
	if _peer == null:
		return
	var connected_steam_id := _peer.get_steam_id_for_peer_id(peer_id)
	status_changed.emit("Steam peer connected: %s" % connected_steam_id, false)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host:
		status_changed.emit("Peer %s disconnected; their positions transferred to the host." % peer_id, false)


func _on_server_disconnected() -> void:
	leave_lobby()
	status_changed.emit("The Steam host disconnected. This run has ended.", true)
	game_end_requested.emit()


func _build_id() -> String:
	var steam_build_id := Steam.getAppBuildId() if Steamworks.is_initialized else 0
	return BuildInfo.build_id(steam_build_id)


func _require_steam() -> bool:
	if Steamworks.is_initialized:
		return true
	status_changed.emit(Steamworks.status_message, true)
	return false