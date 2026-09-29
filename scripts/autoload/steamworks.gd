extends Node

signal initialization_changed(available: bool, message: String)
signal lobby_join_requested(lobby_id: int)

const DEVELOPMENT_APP_ID := 480
const APP_ID_ENVIRONMENT_VARIABLE := "WINTERMAUL_STEAM_APP_ID"

var is_initialized := false
var app_id := DEVELOPMENT_APP_ID
var steam_id := 0
var persona_name := "Offline"
var status_message := "Steam has not initialized."
var pending_lobby_id := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_initialize_steam()
	_check_launch_arguments()


func _process(_delta: float) -> void:
	if is_initialized:
		Steam.run_callbacks()


func _initialize_steam() -> void:
	var configured_app_id := OS.get_environment(APP_ID_ENVIRONMENT_VARIABLE)
	if not configured_app_id.is_empty():
		app_id = configured_app_id.to_int()

	var result: Dictionary = Steam.steamInitEx(app_id, false)
	var status := int(result.get("status", 1))
	if status != 0:
		status_message = "Steam initialization failed: %s" % result.get("verbal", "unknown error")
		initialization_changed.emit(false, status_message)
		return

	is_initialized = true
	steam_id = Steam.getSteamID()
	persona_name = Steam.getPersonaName()
	status_message = "Connected to Steam as %s" % persona_name
	Steam.join_requested.connect(_on_join_requested)
	initialization_changed.emit(true, status_message)


func _check_launch_arguments() -> void:
	var arguments := OS.get_cmdline_args()
	for index in range(arguments.size() - 1):
		if arguments[index] == "+connect_lobby":
			pending_lobby_id = int(arguments[index + 1])
			lobby_join_requested.emit(pending_lobby_id)
			return


func _on_join_requested(lobby_id: int, _friend_steam_id: int) -> void:
	pending_lobby_id = lobby_id
	lobby_join_requested.emit(lobby_id)


func consume_pending_lobby_id() -> int:
	var requested_lobby_id := pending_lobby_id
	pending_lobby_id = 0
	return requested_lobby_id