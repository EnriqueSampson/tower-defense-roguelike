extends Control

const COLOR_OK := Color("8ed8c6")
const COLOR_ERROR := Color("ff8d72")
const COLOR_MUTED := Color("92a09d")

var _listed_lobby_ids: Array[int] = []
var _pending_launch_action: Callable

@onready var steam_identity: Label = %SteamIdentity
@onready var status_label: Label = %StatusLabel
@onready var distance_filter: OptionButton = %DistanceFilter
@onready var lobby_list: ItemList = %LobbyList
@onready var roster_list: ItemList = %RosterList
@onready var join_button: Button = %JoinButton
@onready var invite_button: Button = %InviteButton
@onready var start_button: Button = %StartButton
@onready var map_options_overlay: Control = %MapOptionsOverlay
@onready var roguelike_check: CheckButton = %RoguelikeCheck
@onready var map_options_confirm_button: Button = %MapOptionsConfirmButton
@onready var map_options_cancel_button: Button = %MapOptionsCancelButton


func _ready() -> void:
	distance_filter.add_item("Close", Steam.LOBBY_DISTANCE_FILTER_CLOSE)
	distance_filter.add_item("Default", Steam.LOBBY_DISTANCE_FILTER_DEFAULT)
	distance_filter.add_item("Far", Steam.LOBBY_DISTANCE_FILTER_FAR)
	distance_filter.add_item("Worldwide", Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	distance_filter.select(1)

	%BackButton.pressed.connect(_on_back_pressed)
	%QuickMatchButton.pressed.connect(SteamSession.quick_match)
	%PlaySoloButton.pressed.connect(func() -> void: _request_launch(SteamSession.start_solo_game))
	%BrowseButton.pressed.connect(_browse_lobbies)
	%CreatePublicButton.pressed.connect(func() -> void: _request_launch(func() -> void: SteamSession.create_lobby(Steam.LOBBY_TYPE_PUBLIC)))
	%CreateFriendsButton.pressed.connect(func() -> void: _request_launch(func() -> void: SteamSession.create_lobby(Steam.LOBBY_TYPE_FRIENDS_ONLY)))
	%CreatePrivateButton.pressed.connect(func() -> void: _request_launch(func() -> void: SteamSession.create_lobby(Steam.LOBBY_TYPE_PRIVATE)))
	map_options_confirm_button.pressed.connect(_on_map_options_confirmed)
	map_options_cancel_button.pressed.connect(_on_map_options_cancelled)
	join_button.pressed.connect(_join_selected_lobby)
	invite_button.pressed.connect(SteamSession.invite_friends)
	start_button.pressed.connect(SteamSession.start_game)
	%LeaveButton.pressed.connect(SteamSession.leave_lobby)
	lobby_list.item_selected.connect(func(_index: int) -> void: join_button.disabled = false)

	Steamworks.initialization_changed.connect(_on_steam_initialization_changed)
	SteamSession.status_changed.connect(_on_status_changed)
	SteamSession.lobby_list_updated.connect(_on_lobby_list_updated)
	SteamSession.lobby_changed.connect(_on_lobby_changed)
	SteamSession.roster_changed.connect(_on_roster_changed)
	SteamSession.game_start_requested.connect(_on_game_start_requested)

	_on_steam_initialization_changed(Steamworks.is_initialized, Steamworks.status_message)
	_on_lobby_changed(SteamSession.lobby_id, SteamSession.is_host)
	_on_roster_changed(SteamSession.roster)
	if not SteamSession.last_status.is_empty():
		_on_status_changed(SteamSession.last_status, SteamSession.last_status_is_error)


func _request_launch(action: Callable) -> void:
	_pending_launch_action = action
	roguelike_check.button_pressed = true
	map_options_overlay.visible = true


func _on_map_options_confirmed() -> void:
	map_options_overlay.visible = false
	SteamSession.roguelike_enabled = roguelike_check.button_pressed
	var action := _pending_launch_action
	_pending_launch_action = Callable()
	if action.is_valid():
		action.call()


func _on_map_options_cancelled() -> void:
	map_options_overlay.visible = false
	_pending_launch_action = Callable()


func _browse_lobbies() -> void:
	var distance := distance_filter.get_item_id(distance_filter.selected)
	SteamSession.search_lobbies(distance)


func _join_selected_lobby() -> void:
	var selected := lobby_list.get_selected_items()
	if selected.is_empty():
		return
	SteamSession.join_lobby(_listed_lobby_ids[selected[0]])


func _on_steam_initialization_changed(available: bool, message: String) -> void:
	steam_identity.text = "%s  |  App %s  |  v%s  ·  protocol %s" % [Steamworks.persona_name, Steamworks.app_id, BuildInfo.VERSION, BuildInfo.PROTOCOL_VERSION]
	steam_identity.modulate = COLOR_OK if available else COLOR_ERROR
	_on_status_changed(message, not available)
	%SteamActions.visible = available


func _on_status_changed(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = COLOR_ERROR if is_error else COLOR_MUTED


func _on_lobby_list_updated(lobbies: Array) -> void:
	lobby_list.clear()
	_listed_lobby_ids.clear()
	join_button.disabled = true
	for lobby in lobbies:
		_listed_lobby_ids.append(lobby["id"])
		var host_name: String = lobby["host_name"]
		if host_name.is_empty():
			host_name = "Steam Host"
		var roguelike_text := "Roguelike On" if lobby["roguelike"] else "Roguelike Off"
		lobby_list.add_item("%s   %s/%s   %s   %s" % [host_name, lobby["members"], lobby["limit"], lobby["map"], roguelike_text])
	if lobbies.is_empty():
		lobby_list.add_item("No compatible public lobbies found")
		lobby_list.set_item_disabled(0, true)


func _on_lobby_changed(current_lobby_id: int, local_is_host: bool) -> void:
	var in_lobby := current_lobby_id != 0
	invite_button.disabled = not in_lobby
	%LeaveButton.disabled = not in_lobby
	start_button.disabled = not in_lobby or not local_is_host
	%LobbyHeading.text = "Current Lobby  #%s" % current_lobby_id if in_lobby else "Current Lobby"


func _on_roster_changed(members: Array) -> void:
	roster_list.clear()
	for member in members:
		var host_marker := "  HOST" if member["is_host"] else ""
		roster_list.add_item("Position %s   %s%s" % [member["lane"], member["name"], host_marker])
	if not members.is_empty():
		for lane_number in range(members.size() + 1, SteamSession.MAX_PLAYERS + 1):
			roster_list.add_item("Position %s   OPEN  •  HOST CONTROL" % lane_number)
		start_button.text = "Start Defense  %s/%s" % [members.size(), SteamSession.MAX_PLAYERS]
	else:
		roster_list.add_item("Create or join a lobby to assemble the team")
		roster_list.set_item_disabled(0, true)
		start_button.text = "Start Defense"


func _on_game_start_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_back_pressed() -> void:
	SteamSession.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")