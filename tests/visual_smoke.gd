extends SceneTree

## Windowed smoke run: boots a solo game, builds, launches a wave, and exits.
## Usage: godot --path . --script res://tests/visual_smoke.gd

var _frames := 0
var _draws := 0
var _game: Node


func _initialize() -> void:
	# macOS skips drawing occluded windows; count real draws so fps is interpretable.
	RenderingServer.frame_post_draw.connect(func() -> void: _draws += 1)
	call_deferred("_start")


func _start() -> void:
	root.get_node("SteamSession").set("is_solo_session", true)
	root.get_node("GameSettings").set("controls_seen", true)
	_game = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_game.call("_try_place_tower", "bolt", Vector2i(17, 10))
	_game.call("_try_place_tower", "cannon", Vector2i(40, 68))
	_game.call("_try_place_tower", "frost", Vector2i(30, 66))
	_game.call("_on_palette_selected", "bolt")
	_game.set("build_countdown", 0.5)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 200:
		var state: RunState = _game.get("run_state")
		print("SMOKE phase=", state.phase, " active=", state.active_creeps.size(), " gold=", state.team_gold, " fps=", Engine.get_frames_per_second(),
			" process_ms=%.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
			" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" frames_drawn=", _draws, "/", _frames,
			" focused=", DisplayServer.window_is_focused())
	if _frames == 260:
		_game.call("_select_tower", 1)
	if _frames == 300:
		RenderingServer.force_draw(false)
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("/tmp/wintermaul_smoke.png")
		print("SMOKE screenshot saved to /tmp/wintermaul_smoke.png")
		var camera := _game.get_node("WorldClip/BattlefieldView/BattlefieldViewport/World/BattlefieldCamera") as BattlefieldCamera
		camera.set_zoom_level(BattlefieldCamera.MAX_ZOOM, camera.plane_to_screen((_game.get_node("WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap") as WintermaulMap).grid_to_world(Vector2i(40, 68))))
	if _frames == 315:
		RenderingServer.force_draw(false)
		var zoomed := root.get_viewport().get_texture().get_image()
		zoomed.save_png("/tmp/wintermaul_zoomed.png")
		print("SMOKE zoomed view saved to /tmp/wintermaul_zoomed.png")
	if _frames >= 320:
		var state: RunState = _game.get("run_state")
		print("SMOKE done phase=", state.phase, " kills=", state.stats["kills"], " leaks=", state.stats["leaks"])
		quit()
	return false
