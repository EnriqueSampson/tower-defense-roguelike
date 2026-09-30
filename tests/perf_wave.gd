extends SceneTree

## Busiest-wave performance harness (see docs/PERFORMANCE.md).
##   Logic only:  godot --headless --path . --script res://tests/perf_wave.gd
##   Full frame:  godot --path . --script res://tests/perf_wave.gd
## Places PERF_TOWERS towers (default 300) at seeded random valid spots, fakes
## a nine-player roster so the wave spawns at full scale, launches the busiest
## mixed level ("Full Assault", level 29) and samples frame times with vsync
## off and the camera fully zoomed out (PERF_ZOOM overrides the zoom level; PERF_SHADOWS=off or
## single isolates the shadow cost).

## The busiest mixed level; found by title so level renumbering cannot break it.
const WAVE_TITLE := "Full Assault"
const WARMUP_SECONDS := 3.0
const SAMPLE_SECONDS := 45.0
const MAP_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap"
const CAMERA_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/BattlefieldCamera"

var _game: Node
var _map: WintermaulMap
var _state: RunState
var _elapsed := 0.0
var _last_usec := 0
var _frame_usecs: PackedInt64Array = []
var _peak_creeps := 0
var _peak_projectiles := 0
var _peak_effects := 0
var _started := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var session := root.get_node("SteamSession")
	session.set("is_solo_session", true)
	root.get_node("GameSettings").set("controls_seen", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_game = (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	_map = _game.get_node(MAP_PATH) as WintermaulMap
	_state = _game.get("run_state")
	_state.team_gold = 100000000
	var placed := _place_towers(int(OS.get_environment("PERF_TOWERS")) if OS.has_environment("PERF_TOWERS") else 300)
	var camera := _game.get_node(CAMERA_PATH) as BattlefieldCamera
	camera.set_zoom_level(float(OS.get_environment("PERF_ZOOM")) if OS.has_environment("PERF_ZOOM") else BattlefieldCamera.MIN_ZOOM)
	# Diagnostics: PERF_SHADOWS=off | single compares shadow cost.
	var sun := _game.get_node("WorldClip/BattlefieldView/BattlefieldViewport/World/Sun") as DirectionalLight3D
	match OS.get_environment("PERF_SHADOWS"):
		"off":
			sun.shadow_enabled = false
		"single":
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# Full nine-player scale: the wave reads the roster size when it begins.
	var fake_roster: Array[Dictionary] = []
	for index in range(ClassicWintermaulLayout.PLAYER_COUNT):
		fake_roster.append({"steam_id": 1000 + index, "lane": index + 1, "name": "P%d" % (index + 1)})
	session.set("roster", fake_roster)
	var wave_index := 0
	for index in range(_state.wave_count):
		if (_game.get("CATALOG") as ContentCatalog).waves[index].title == WAVE_TITLE:
			wave_index = index
	_state.current_wave_index = wave_index
	_game.call("_begin_wave")
	session.set("roster", [] as Array[Dictionary])
	print("PERF setup towers=%d wave=%d renderer=%s" % [placed, wave_index + 1, DisplayServer.get_name()])
	_started = true


func _place_towers(target: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	# One tier-1 tower from each race; the host takes each tower's race in turn.
	var ids := ["bolt", "cannon", "frost", "bug_ant"]
	var catalog: ContentCatalog = _game.get("CATALOG")
	var placed := 0
	var attempts := 0
	while placed < target and attempts < target * 40:
		attempts += 1
		var cell := Vector2i(rng.randi_range(0, WintermaulMap.GRID_SIZE.x - 2), rng.randi_range(0, WintermaulMap.GRID_SIZE.y - 2))
		_state.peer_races[1] = catalog.race_of_tower(ids[placed % ids.size()])
		if _game.call("_try_place_tower", ids[placed % ids.size()], cell) == WintermaulMap.Placement.OK:
			placed += 1
	return placed


func _process(delta: float) -> bool:
	if not _started:
		return false
	var now := Time.get_ticks_usec()
	_elapsed += delta
	if _elapsed > WARMUP_SECONDS and _last_usec > 0:
		_frame_usecs.append(now - _last_usec)
		_peak_creeps = maxi(_peak_creeps, _map.get_active_creeps().size())
		_peak_projectiles = maxi(_peak_projectiles, _map.get_node("Projectiles").get_child_count())
		_peak_effects = maxi(_peak_effects, _map.effects.active_count())
	_last_usec = now
	if _elapsed >= WARMUP_SECONDS + SAMPLE_SECONDS:
		_report()
		quit()
	return false


func _report() -> void:
	var sorted := _frame_usecs.duplicate()
	sorted.sort()
	var total := 0
	for usec in sorted:
		total += usec
	var count := maxi(sorted.size(), 1)
	print("PERF frames=%d avg_ms=%.2f p50_ms=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.2f" % [
		sorted.size(), total / 1000.0 / count,
		sorted[count / 2] / 1000.0, sorted[int(count * 0.95)] / 1000.0,
		sorted[int(count * 0.99)] / 1000.0, sorted[count - 1] / 1000.0,
	])
	print("PERF peak_creeps=%d peak_projectiles=%d peak_effects=%d kills=%d leaks=%d draw_calls=%d" % [
		_peak_creeps, _peak_projectiles, _peak_effects, _state.stats["kills"], _state.stats["leaks"],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	])
