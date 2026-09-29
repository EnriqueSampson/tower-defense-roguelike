extends SceneTree
var _frames := 0
var _game: Node
var _t0 := 0
var _worst := 0
var _last := 0
func _initialize() -> void:
	call_deferred("_start")
func _start() -> void:
	root.get_node("SteamSession").set("is_solo_session", true)
	root.get_node("GameSettings").set("controls_seen", true)
	_game = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_game.set("build_countdown", 0.5)
func _process(_delta: float) -> bool:
	_frames += 1
	var now := Time.get_ticks_usec()
	if _frames > 100 and _last > 0:
		_worst = maxi(_worst, now - _last)
	_last = now
	if _frames == 100:
		_t0 = now
	if _frames == 400:
		var state: RunState = _game.get("run_state")
		print("PERF avg_ms=%.1f worst_ms=%.1f active=%d draw_calls=%d" % [(now - _t0) / 300000.0, _worst / 1000.0, state.active_creeps.size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		print("PERF process_ms=%.2f physics_ms=%.2f" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		quit()
	return false
