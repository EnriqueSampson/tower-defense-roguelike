extends Control

## The lobby finder, styled as contestant registration for a live show.

const COLOR_OK := BroadcastTheme.CYAN
const COLOR_ERROR := BroadcastTheme.LIVE_RED
const COLOR_MUTED := BroadcastTheme.MUTED
const CATALOG: ContentCatalog = preload("res://resources/content_catalog.tres")
## What the System says while players wait in the lobby.
const SYSTEM_LINES: Array[String] = [
	"Pick a builder. Any builder. They all trip over things eventually.",
	"Crew tip: whoever holds Position 9 deserves your gold. And your prayers.",
	"Solo runs get great ratings. Mostly when they go badly.",
	"Remember: lives are shared, gold is not. Send gold with /give in chat.",
	"The Bugs builder is very cheap. So are our production values.",
	"Please do not feed the creeps. They grow up so fast. Into bosses.",
]

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
@onready var race_picker: OptionButton = %RacePicker
@onready var race_blurb: Label = %RaceBlurb
@onready var system_line: SystemLowerThird = %SystemLine


func _ready() -> void:
	_apply_broadcast_style()
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
	_setup_race_picker()

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


func _apply_broadcast_style() -> void:
	theme = BroadcastTheme.build()
	BroadcastTheme.headline(%Title, 44, BroadcastTheme.GOLD)
	BroadcastTheme.headline(%BrowserHeading, 28, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	BroadcastTheme.headline(%LobbyHeading, 28, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	BroadcastTheme.headline(%RaceLabel, 20, BroadcastTheme.TEXT, Color(0, 0, 0, 0.6))
	BroadcastTheme.headline(%MapOptionsTitle, 30, BroadcastTheme.GOLD)
	%Subtitle.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	%MapOptionsHint.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	race_blurb.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	system_line.set_lines(SYSTEM_LINES)


## Every player picks a builder race here; the pick carries into solo runs
## and is shared with the lobby as Steam member data.
func _setup_race_picker() -> void:
	race_picker.clear()
	var current := CATALOG.resolve_race_id(SteamSession.local_race if not SteamSession.local_race.is_empty() else GameSettings.preferred_race)
	for index in range(CATALOG.races.size()):
		var race := CATALOG.races[index]
		race_picker.add_item(race.display_name, index)
		if race.id == current:
			race_picker.select(index)
	race_picker.item_selected.connect(_on_race_selected)
	_on_race_selected(race_picker.selected, false)


func _on_race_selected(index: int, announce := true) -> void:
	if index < 0 or index >= CATALOG.races.size():
		return
	var race := CATALOG.races[index]
	race_blurb.text = race.description
	if announce or SteamSession.local_race != race.id:
		SteamSession.set_local_race(race.id)


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
	%BrowserTools.visible = available
	if lobby_list.item_count == 0 or lobby_list.is_item_disabled(0):
		lobby_list.clear()
		lobby_list.add_item("Press REFRESH to see what's airing." if available else "Steam is off the air. GO SOLO, or start Steam to find a crew.")
		lobby_list.set_item_disabled(0, true)


func _on_status_changed(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = COLOR_ERROR if is_error else COLOR_MUTED
	if is_error and not message.is_empty():
		system_line.say("We are experiencing technical difficulties: %s" % message)


func _on_lobby_list_updated(lobbies: Array) -> void:
	lobby_list.clear()
	_listed_lobby_ids.clear()
	join_button.disabled = true
	for lobby in lobbies:
		_listed_lobby_ids.append(lobby["id"])
		var host_name: String = lobby["host_name"]
		if host_name.is_empty():
			host_name = "Steam Host"
		var roguelike_text := "Sponsor upgrades on" if lobby["roguelike"] else "Sponsor upgrades off"
		lobby_list.add_item("%s's show   ·   %s/%s crawlers   ·   %s" % [host_name, lobby["members"], lobby["limit"], roguelike_text])
	if lobbies.is_empty():
		lobby_list.add_item("Nothing airing right now. Host your own show.")
		lobby_list.set_item_disabled(0, true)


func _on_lobby_changed(current_lobby_id: int, local_is_host: bool) -> void:
	var in_lobby := current_lobby_id != 0
	invite_button.disabled = not in_lobby
	%LeaveButton.disabled = not in_lobby
	start_button.disabled = not in_lobby or not local_is_host
	%LobbyHeading.text = "YOUR CREW  ·  SHOW #%s" % str(current_lobby_id).right(6) if in_lobby else "YOUR CREW"


func _on_roster_changed(members: Array) -> void:
	roster_list.clear()
	for member in members:
		var host_marker := "  HOST" if member["is_host"] else ""
		var race := CATALOG.get_race(CATALOG.resolve_race_id(str(member.get("race", ""))))
		var index := roster_list.add_item("Position %s   %s   %s%s" % [member["lane"], member["name"], race.display_name if race else "", host_marker])
		roster_list.set_item_custom_fg_color(index, _position_color(int(member["lane"])))
	if not members.is_empty():
		for lane_number in range(members.size() + 1, SteamSession.MAX_PLAYERS + 1):
			var index := roster_list.add_item("Position %s   OPEN  ·  HOST CONTROL" % lane_number)
			roster_list.set_item_custom_fg_color(index, _position_color(lane_number).darkened(0.5))
		start_button.text = "GO LIVE  %s/%s" % [members.size(), SteamSession.MAX_PLAYERS]
	else:
		roster_list.add_item("Host or join a show to assemble your crew")
		roster_list.set_item_disabled(0, true)
		start_button.text = "GO LIVE"


func _position_color(lane_number: int) -> Color:
	var index := clampi(lane_number - 1, 0, ClassicWintermaulLayout.PLAYER_COLORS.size() - 1)
	return ClassicWintermaulLayout.PLAYER_COLORS[index].lightened(0.2)


func _on_game_start_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_back_pressed() -> void:
	SteamSession.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")