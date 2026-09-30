extends SceneTree

## Headless regression suite. Run with:
##   godot --headless --path . --script res://tests/run_tests.gd

const LobbyPolicy = preload("res://scripts/network/lobby_match_policy.gd")
const RunStateModel = preload("res://scripts/game/run_state.gd")
const Catalog: ContentCatalog = preload("res://resources/content_catalog.tres")
const WaveOne: WaveDefinition = preload("res://resources/waves/wave_01.tres")
const Bolt: TowerDefinition = preload("res://resources/towers/bolt_tower.tres")
const Cannon: TowerDefinition = preload("res://resources/towers/cannon_tower.tres")
const Frost: TowerDefinition = preload("res://resources/towers/frost_tower.tres")
const Grunt: CreepDefinition = preload("res://resources/creeps/grunt.tres")
const WintermaulMapScene = preload("res://scenes/map/WintermaulMap.tscn")
const GAME_SCENE_PATH := "res://scenes/game/Game.tscn"
const BattlefieldCameraScript = preload("res://scripts/map/battlefield_camera.gd")
const PathGridModel = preload("res://scripts/pathfinding/path_grid.gd")
const GAME_TAG := BuildInfo.GAME_TAG
const PROTOCOL := BuildInfo.PROTOCOL_VERSION
const BUILD := "100"
const MAP := BuildInfo.MAP_ID
const MAP_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/WintermaulMap"
const CAMERA_PATH := "WorldClip/BattlefieldView/BattlefieldViewport/World/BattlefieldCamera"
const ALL_POSITIONS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
## Stylized layout reference cells.
## Reference cells on the 144x160 grid (design grid x2).
const P1_OPEN := Vector2i(34, 20)
const P1_OPEN_B := Vector2i(36, 20)
const P1_CREEP := Vector2i(34, 22)
const P2_OPEN := Vector2i(72, 24)
const P4_OPEN := Vector2i(116, 72)
const P9_OPEN := Vector2i(80, 140)
const VOID_CELL := Vector2i(6, 20)
const PORTAL_CELL := Vector2i(35, 7)
## Lane 1 exits through a ten-wide, four-deep gap (x 30-39, y 58-61). Four 2x2
## towers across rows 58-59 leave only x 36-37 open; a 2x2 at SEAL_CELL closes it.
const SEAL_CELL := Vector2i(36, 58)
const SEAL_NEIGHBOURS: Array[Vector2i] = [Vector2i(30, 58), Vector2i(32, 58), Vector2i(34, 58), Vector2i(38, 58)]

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# The host's race comes from this machine's saved preference; pin the
	# default race so results never depend on local settings.
	root.get_node("SteamSession").set("local_race", "")
	# Lobby and session
	_test_compatible_lobby()
	_test_full_lobby_rejected()
	_test_in_progress_lobby_rejected()
	_test_mismatched_build_rejected()
	_test_protocol_and_version_rules()
	_test_quick_match_selection()
	_test_solo_session()
	_test_host_disconnect_cleanup()
	# Layout, data, and content
	_test_classic_layout_coordinates()
	_test_content_catalog_validation()
	_test_wave_lane_counts()
	_test_wave_spawn_groups()
	_test_balance_player_scale()
	_test_upgrade_trees_and_races()
	# Run state
	_test_run_phase_transitions()
	_test_build_phase_policy()
	_test_leak_resolves_once()
	_test_team_economy()
	_test_snapshot_round_trip()
	_test_full_run_victory_and_defeat_model()
	# Ownership and authority
	_test_build_permission_policy()
	_test_unauthorized_client_build_rejected()
	_test_disconnect_takeover()
	_test_load_acknowledgement_gates_countdown()
	_test_wave_one_ready_check()
	# Map, pathing, and placement
	_test_grid_projection_and_placement()
	_test_path_grid_anti_block_rollback()
	_test_tower_collision_pathing()
	_test_sell_reopens_route()
	_test_relay_stage_continuity()
	_test_active_creep_collision()
	_test_stable_placement_preview()
	_test_placement_reasons()
	_test_two_by_two_footprints()
	# Camera
	_test_battlefield_camera_controls()
	_test_solo_camera_startup_focus()
	_test_edge_pan_only_at_window_edges()
	_test_multiplayer_camera_startup_focus()
	# Combat
	_test_basic_tower_combat()
	_test_targeting_priorities()
	_test_splash_slow_and_armor()
	_test_mid_wave_tower_placement()
	_test_blocked_placement_preserves_gold()
	_test_upgrade_and_sell_economy()
	# Special creeps
	_test_air_creeps()
	_test_air_creeps_follow_every_checkpoint()
	_test_magic_immunity()
	_test_invisible_creeps_and_detection()
	_test_splitters()
	_test_level_pacing()
	_test_starting_gold_scales_with_players()
	# Builder
	_test_builder_orders_and_construction()
	_test_builder_stop_and_trip()
	_test_races_gate_building_and_offers()
	_test_builder_reconciliation()
	# Roguelike layer
	_test_run_modifiers()
	_test_upgrade_offer_rules_and_determinism()
	_test_controller_wave_loop_with_offer()
	_test_controller_roguelike_toggle_suppresses_offer()
	# Reconciliation
	_test_tower_reconciliation()
	_test_creep_reconciliation()
	# Presentation
	_test_actor_models()
	_test_effects_layer()
	_test_audio_and_settings()
	if _failures == 0:
		print("PASS: %s lobby and run-state checks" % _checks)
	else:
		printerr("FAIL: %s of %s lobby and run-state checks failed" % [_failures, _checks])
	quit(_failures)


# --- Lobby and session ------------------------------------------------------

func _test_compatible_lobby() -> void:
	_check(_matches(_metadata(), 2, 8), "waiting compatible lobby is accepted")


func _test_full_lobby_rejected() -> void:
	_check(not _matches(_metadata(), 8, 8), "full lobby is rejected")


func _test_in_progress_lobby_rejected() -> void:
	var metadata := _metadata()
	metadata["state"] = "in_game"
	_check(not _matches(metadata, 2, 8), "in-progress lobby is rejected")


func _test_mismatched_build_rejected() -> void:
	var metadata := _metadata()
	metadata["build"] = "99"
	_check(not _matches(metadata, 2, 8), "mismatched build is rejected")


func _test_protocol_and_version_rules() -> void:
	var metadata := _metadata()
	metadata["protocol"] = str(int(PROTOCOL) + 1)
	_check(not _matches(metadata, 2, 8), "mismatched protocol version is rejected")
	_check(BuildInfo.build_id(0) == BuildInfo.VERSION, "development builds fall back to the semantic version")
	_check(BuildInfo.build_id(4242) == "4242", "Steam depot builds use the Steam build id")
	_check(BuildInfo.VERSION.split(".").size() == 3, "build version is semantic MAJOR.MINOR.PATCH")
	_check(ProjectSettings.get_setting("application/config/version") == BuildInfo.VERSION, "project version matches BuildInfo")


func _test_quick_match_selection() -> void:
	_check(LobbyPolicy.select_quick_match([]) == 0, "Quick Match creates when no lobby exists")
	_check(
		LobbyPolicy.select_quick_match([{"id": 76561198000000000}]) == 76561198000000000,
		"Quick Match chooses Steam's first ordered result"
	)


func _test_solo_session() -> void:
	var steam_session := root.get_node("SteamSession")
	var starts: Array[int] = [0]
	steam_session.connect("game_start_requested", func() -> void: starts[0] += 1, CONNECT_ONE_SHOT)
	steam_session.call("start_solo_game")
	var solo_roster: Array = steam_session.get("roster")
	_check(steam_session.get_multiplayer().is_server(), "solo session gives the local player host authority")
	_check(steam_session.get("is_solo_session") and steam_session.get("is_host"), "solo session records local host ownership")
	_check(solo_roster.size() == 1 and solo_roster[0]["lane"] == 1, "solo session creates a one-player roster")
	_check(steam_session.call("get_local_position_number") == 1, "session resolves the local roster position")
	_check(starts[0] == 1, "solo session requests the game scene transition")
	var ends: Array[int] = [0]
	steam_session.connect("game_end_requested", func() -> void: ends[0] += 1, CONNECT_ONE_SHOT)
	steam_session.call("return_to_lobby")
	_check(ends[0] == 1 and steam_session.get("lobby_id") == 0, "solo return-to-lobby ends the run and requests the lobby scene")


func _test_host_disconnect_cleanup() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("lobby_id", 12345)
	steam_session.set("is_host", false)
	var ends: Array[int] = [0]
	steam_session.connect("game_end_requested", func() -> void: ends[0] += 1, CONNECT_ONE_SHOT)
	steam_session.call("_on_server_disconnected")
	_check(ends[0] == 1, "host disconnect requests a graceful return to the lobby scene")
	_check(steam_session.get("lobby_id") == 0 and (steam_session.get("roster") as Array).is_empty(), "host disconnect clears lobby and roster state")
	_check(steam_session.get("last_status_is_error"), "host disconnect leaves an error status for the lobby screen")
	_check(steam_session.get_multiplayer().is_server(), "host disconnect resets the local peer to an offline host")


# --- Layout, data, and content ----------------------------------------------

func _test_classic_layout_coordinates() -> void:
	var positions := ClassicWintermaulLayout.setup_map_coordinates()
	_check(positions.size() == 9, "classic layout defines nine player positions")
	_check(ClassicWintermaulLayout.GRID_SIZE == Vector2i(144, 160), "layout scales the 72 by 80 design grid to 144 by 160 cells (72 by 80 towers)")
	_check(ClassicWintermaulLayout.SPATIAL_PLAYER_ORDER == [1, 2, 3, 6, 5, 4, 7, 9, 8], "classic layout preserves Warcraft color order")
	var spawn_cells: Dictionary = {}
	var all_bounds_valid := true
	var grid := Rect2i(Vector2i.ZERO, ClassicWintermaulLayout.GRID_SIZE)
	for position_data in positions:
		all_bounds_valid = all_bounds_valid and grid.encloses(position_data["macro_bounds"])
		for spawn in position_data["spawns"]:
			spawn_cells[spawn] = true
			all_bounds_valid = all_bounds_valid and ClassicWintermaulLayout.terrain_at(spawn, positions) == ClassicWintermaulLayout.Terrain.SPAWN_PAD
		all_bounds_valid = all_bounds_valid and ClassicWintermaulLayout.is_traversable(ClassicWintermaulLayout.terrain_at(position_data["checkpoint"], positions))
	_check(spawn_cells.size() == 10, "layout defines ten spawn portals across nine positions")
	_check(positions[4]["spawns"].size() == 2 and positions[8]["spawns"].size() == 1, "position five spawns from two pads and position nine from one")
	var p9_spawn: Vector2i = positions[8]["spawns"][0]
	_check(p9_spawn.x == ClassicWintermaulLayout.FINAL_GATE.x and p9_spawn.y > positions[6]["spawns"][0].y and p9_spawn.y < ClassicWintermaulLayout.FINAL_CHECKPOINT.y, "position nine spawns centred, below the brow spawns and above the relay")
	_check(all_bounds_valid, "macro bounds fit the grid and every spawn sits on a pad with a reachable checkpoint")
	var p9: Dictionary = positions[8]
	_check(p9["macro_bounds"] == Rect2i(54, 90, 40, 66), "position nine owns the bottom-center final defense")
	_check(p9["checkpoint"] == ClassicWintermaulLayout.FINAL_CHECKPOINT and ClassicWintermaulLayout.FINAL_GATE == Vector2i(71, 155), "position nine exits through the relay checkpoint and final gate")
	_check(ClassicWintermaulLayout.terrain_at(ClassicWintermaulLayout.FINAL_GATE) == ClassicWintermaulLayout.Terrain.EXIT_PAD, "the final gate sits on the exit pad")
	_check(ClassicWintermaulLayout.terrain_at(Vector2i(0, 0)) == ClassicWintermaulLayout.Terrain.VOID and ClassicWintermaulLayout.terrain_at(Vector2i(16, 0)) == ClassicWintermaulLayout.Terrain.WALL, "void surrounds the outer hedge")
	_check(ClassicWintermaulLayout.terrain_at(P1_OPEN) == ClassicWintermaulLayout.Terrain.OPEN and ClassicWintermaulLayout.position_index_at(P1_OPEN) == 0, "lane one ground below the spawn pad belongs to position one")
	_check(ClassicWintermaulLayout.terrain_at(Vector2i(16, 72)) == ClassicWintermaulLayout.Terrain.OPEN, "side entrances carve gaps through the outer hedge")


func _test_content_catalog_validation() -> void:
	_check(Catalog.validate().is_empty(), "shipped content catalog validates with unique ids")
	_check(Catalog.towers.size() >= 32, "catalog ships 8+ towers for each of four races")
	_check(Catalog.waves.size() >= 30, "catalog ships a classic run of 30+ levels")
	_check(Catalog.upgrades.size() >= 12 and Catalog.upgrades.size() <= 24, "catalog ships 12-24 run upgrades")
	_check(Catalog.creeps().size() >= 4, "catalog references at least four creep roles")
	var bosses_every_five := true
	for wave in Catalog.waves:
		bosses_every_five = bosses_every_five and (wave.number % 5 == 0) == wave.has_boss() and wave.has_boss() == wave.is_boss_wave
	_check(bosses_every_five, "every fifth level, and only those, is a boss level")
	_check(Catalog.waves[-1].has_boss(), "the run ends on a boss")
	var roles: Dictionary = {}
	for creep in Catalog.creeps():
		roles[creep.role] = true
	_check(roles.size() >= 4, "creep roles create distinct tactical pressures")
	_check(Catalog.get_tower("bolt") == Bolt and Catalog.get_creep("grunt") != null and Catalog.get_upgrade("extra_lives") != null, "catalog resolves towers, creeps, and upgrades by stable id")

	var broken := ContentCatalog.new()
	var duplicate := Bolt.duplicate() as TowerDefinition
	broken.towers = [Bolt, duplicate]
	_check(not broken.validate().is_empty(), "catalog validation reports duplicate tower ids")
	var invalid_wave := WaveDefinition.new()
	invalid_wave.id = "empty"
	var broken_waves := ContentCatalog.new()
	broken_waves.waves = [invalid_wave]
	_check(not broken_waves.validate().is_empty(), "catalog validation rejects waves without spawn groups")
	var orphan := ContentCatalog.new()
	var orphan_upgrade := RunUpgradeDefinition.new()
	orphan_upgrade.id = "ghost"
	orphan_upgrade.tower_id = "missing_tower"
	orphan.upgrades = [orphan_upgrade]
	_check(not orphan.validate().is_empty(), "catalog validation rejects upgrades targeting unknown towers")


func _test_wave_lane_counts() -> void:
	var counts := PackedInt32Array()
	for lane_id in range(ClassicWintermaulLayout.PLAYER_COUNT):
		counts.append(WaveOne.creep_count_for_lane(lane_id))
	_check(counts == PackedInt32Array([10, 10, 10, 5, 5, 5, 5, 5, 3]), "wave one applies nine-position multipliers")
	var total_count := 0
	for count in counts:
		total_count += count
	_check(total_count == 58, "wave one creates 58 native creeps at full team scale")


func _test_wave_spawn_groups() -> void:
	var wave_three := Catalog.waves[2]
	var queue := wave_three.build_spawn_queue(0)
	_check(queue.size() == wave_three.creep_count_for_lane(0), "spawn queue totals match the position creep count")
	var ordered := true
	var switched := false
	for entry in queue:
		if entry["creep_id"] == "grunt":
			switched = true
		elif switched:
			ordered = false
	_check(ordered and queue[0]["creep_id"] == "runner", "spawn groups are emitted in deterministic definition order")
	_check(queue == wave_three.build_spawn_queue(0), "spawn queue generation is repeatable")
	_check(float(queue[1]["delay"]) == 0.45, "spawn queue carries group intervals")
	var solo_total := 0
	var full_total := 0
	for lane_id in range(ClassicWintermaulLayout.PLAYER_COUNT):
		solo_total += wave_three.creep_count_for_lane(lane_id, BalanceConfig.player_scale(1))
		full_total += wave_three.creep_count_for_lane(lane_id, BalanceConfig.player_scale(9))
	_check(solo_total < full_total, "solo load scale spawns fewer creeps than a full lobby")
	var boss_wave := Catalog.waves[9]
	var boss_queue := boss_wave.build_spawn_queue(0, BalanceConfig.player_scale(1))
	var boss_count := 0
	for entry in boss_queue:
		if entry["creep_id"] == "warlord":
			boss_count += 1
	_check(boss_count == 1, "boss spawns are never multiplied by position or team scale")
	_check(boss_wave.preview_lines().size() == 2 and "BOSS" in boss_wave.preview_lines()[1], "wave preview lists groups with boss warning traits")


func _test_balance_player_scale() -> void:
	_check(is_equal_approx(BalanceConfig.player_scale(1), BalanceConfig.MIN_PLAYER_SCALE), "solo uses the minimum load scale")
	_check(is_equal_approx(BalanceConfig.player_scale(9), BalanceConfig.MAX_PLAYER_SCALE), "nine players use the full load scale")
	_check(BalanceConfig.player_scale(2) < BalanceConfig.player_scale(3), "load scale grows with team size")
	_check(BalanceConfig.build_duration_for_wave(0) > BalanceConfig.build_duration_for_wave(3), "first build phase is longer for initial mazing")


func _test_upgrade_trees_and_races() -> void:
	_check(Catalog.races.size() == 4, "the catalog ships four builder races")
	var race_ids: Array = []
	for race in Catalog.races:
		race_ids.append(race.id)
	_check(race_ids == ["humans", "orcs", "elves", "bugs"], "races are Humans, Orcs, Elves and Bugs, Humans first (the default)")
	_check(Catalog.race_of_tower("bolt") == "humans" and Catalog.race_of_tower("sentry") == "humans" and Catalog.race_of_tower("cannon") == "orcs" and Catalog.race_of_tower("frost") == "elves", "the original towers are folded into races")
	var every_tower_owned := true
	for tower in Catalog.towers:
		every_tower_owned = every_tower_owned and not Catalog.race_of_tower(tower.id).is_empty()
	_check(every_tower_owned, "every tower belongs to a race")
	for race in Catalog.races:
		var towers := Catalog.race_towers(race)
		var detects := false
		var branches := false
		for tower in towers:
			detects = detects or tower.detection_range > 0.0
			branches = branches or tower.upgrade_options.size() > 1
		_check(towers.size() >= 8 and detects, "%s have 8+ towers and a detector" % race.display_name)
		_check(race.towers.size() <= 10, "%s' builder roster fits the build card" % race.display_name)
	_check(Bolt.upgrade_options.size() == 2 and Catalog.get_tower("orc_mortar").upgrade_options.size() == 2, "upgrade trees branch, as in Wintermaul")
	var crossbow := Catalog.get_tower("human_crossbow")
	_check(crossbow.tier == Bolt.tier + 1 and Catalog.line_of("human_streamer") == "bolt", "upgrades sit one tier up and belong to their root's line")
	_check(Bolt.sell_value(25) == 17 and Bolt.sell_value(145, 30) == 145, "sell value applies the refund percentage and bonuses to the investment")
	var base := Bolt.stats()
	var top := Catalog.get_tower("human_musket").stats()
	_check(top["damage"] > base["damage"] and top["range"] > base["range"], "deeper towers hit harder and reach further")
	_check(Cannon.stats()["splash_radius"] > 0.0 and Frost.stats()["slow_factor"] > 0.0, "cannon splashes and frost slows by definition")
	var bug_splash: Array[String] = []
	var cheapest := 1 << 30
	for tower in Catalog.race_towers(Catalog.get_race("bugs")):
		if tower.splash_radius > 0.0:
			bug_splash.append(tower.id)
		if tower.tier == 1:
			cheapest = mini(cheapest, tower.cost)
	_check(bug_splash == ["bug_queen"], "Bugs have no splash except the Hive Queen ultimate")
	_check(cheapest <= 5 and cheapest < Bolt.cost, "Bugs build the cheapest maze towers")
	var looped := ContentCatalog.new()
	var a := TowerDefinition.new()
	a.id = "a"
	a.upgrade_options = ["missing"]
	var race := RaceDefinition.new()
	race.id = "r"
	race.towers = [a]
	looped.towers = [a]
	looped.races = [race]
	var problems := looped.validate()
	_check(problems.any(func(p: String) -> bool: return "unknown tower" in p) and problems.any(func(p: String) -> bool: return "detect" in p), "validation rejects unknown upgrade targets and races without detection")
	_check(Bolt.default_targeting == TowerTargeting.Mode.FIRST and Cannon.default_targeting == TowerTargeting.Mode.STRONGEST, "towers carry default targeting modes")


# --- Run state ----------------------------------------------------------------

func _test_run_phase_transitions() -> void:
	var state := RunStateModel.new(2, 20)
	_check(state.phase == RunStateModel.Phase.BUILD, "run starts in build phase")
	state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0]))
	_check(state.phase == RunStateModel.Phase.WAVE, "build transitions to active wave")
	state.register_spawn(0, 1)
	state.resolve_creep(1, false)
	state.advance_after_clear()
	_check(state.phase == RunStateModel.Phase.BUILD and state.current_wave_index == 1, "cleared wave advances to build")
	state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0]))
	state.register_spawn(0, 2)
	state.resolve_creep(2, false)
	state.advance_after_clear()
	_check(state.phase == RunStateModel.Phase.VICTORY, "final cleared wave ends in victory")


func _test_build_phase_policy() -> void:
	var state := RunStateModel.new(1, 1)
	_check(state.can_build(), "tower placement is available during build phase")
	state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0]))
	_check(state.can_build(), "tower placement remains available during active waves")
	state.register_spawn(0, 1)
	state.resolve_creep(1, false)
	state.advance_after_clear()
	_check(not state.can_build(), "tower placement locks after victory")
	var defeated_state := RunStateModel.new(1, 1)
	defeated_state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0]))
	defeated_state.register_spawn(0, 2)
	defeated_state.resolve_creep(2, true)
	_check(not defeated_state.can_build(), "tower placement locks after defeat")


func _test_leak_resolves_once() -> void:
	var state := RunStateModel.new(1, 2)
	state.begin_wave(PackedInt32Array([2, 0, 0, 0, 0, 0, 0, 0]))
	state.register_spawn(0, 7)
	state.register_spawn(0, 8)
	_check(state.resolve_creep(7, true), "first leak resolves active creep")
	_check(not state.resolve_creep(7, true), "duplicate leak is ignored")
	_check(state.shared_lives == 1, "duplicate leak cannot consume another life")
	_check(not state.resolve_creep(7, false), "a leaked creep cannot also be reported killed")
	state.resolve_creep(8, true)
	_check(
		state.phase == RunStateModel.Phase.DEFEAT and state.active_creeps.is_empty() and state.lane_queued[0] == 0,
		"life exhaustion ends the run and closes creep activity"
	)
	_check(state.stats["leaks"] == 2, "run stats count each leak once")


func _test_team_economy() -> void:
	var state := RunStateModel.new(1, 20, 25)
	_check(state.spend_gold(25) and state.team_gold == 0, "tower purchase spends authoritative team gold")
	_check(not state.spend_gold(1), "tower purchase rejects insufficient team gold")
	state.award_gold(5)
	_check(state.team_gold == 5, "creep bounty rewards authoritative team gold")
	state.refund_gold(10)
	_check(state.team_gold == 15 and state.stats["gold_earned"] == 5 and state.stats["gold_spent"] == 25, "refunds return gold without inflating earned bounty")


func _test_snapshot_round_trip() -> void:
	var state := RunStateModel.new(10, 20, 120)
	state.run_seed = 987654
	state.position_owners[2] = 7
	state.add_tower("bolt", P1_OPEN, 0, TowerTargeting.Mode.LAST)
	state.add_tower("frost", P2_OPEN, 1, TowerTargeting.Mode.FIRST)
	state.upgrade_tower(1, "human_crossbow", 45)
	state.apply_upgrade("bolt_damage")
	state.pending_offer = ["war_chest", "extra_lives"]
	state.elapsed_seconds = 42.5
	state.spend_gold(30)
	var snapshot := state.snapshot(12.0)
	var restored := RunStateModel.new()
	restored.restore(snapshot)
	_check(restored.run_seed == 987654 and restored.position_owners == state.position_owners, "snapshot restores seed and position owners")
	_check(restored.towers.size() == 2 and restored.get_tower(1)["definition_id"] == "human_crossbow" and int(restored.get_tower(1)["invested"]) == 45 and restored.get_tower(2)["definition_id"] == "frost", "snapshot restores tower records by stable id")
	_check(restored.applied_upgrades == ["bolt_damage"] and restored.pending_offer == ["war_chest", "extra_lives"], "snapshot restores applied upgrades and pending offer")
	_check(restored.team_gold == 90 and is_equal_approx(restored.elapsed_seconds, 42.5) and restored.stats["towers_built"] == 2, "snapshot restores economy, timer, and stats")
	_check(restored.snapshot(12.0) == snapshot, "snapshot serialization is stable across a round trip")
	_check(restored.allocate_tower_id() == 3, "snapshot restores id allocation so new ids never collide")


func _test_full_run_victory_and_defeat_model() -> void:
	var state := RunStateModel.new(Catalog.waves.size(), BalanceConfig.STARTING_LIVES, BalanceConfig.STARTING_GOLD)
	var creep_id := 1
	var boss_seen := false
	for wave in Catalog.waves:
		var counts := PackedInt32Array()
		for lane_id in range(ClassicWintermaulLayout.PLAYER_COUNT):
			counts.append(wave.creep_count_for_lane(lane_id, BalanceConfig.player_scale(3)))
		state.begin_wave(counts)
		for lane_id in range(counts.size()):
			for entry in wave.build_spawn_queue(lane_id, BalanceConfig.player_scale(3)):
				var definition := Catalog.get_creep(entry["creep_id"])
				boss_seen = boss_seen or definition.is_boss
				state.register_spawn(lane_id, creep_id, definition.id, entry["health_multiplier"])
				state.resolve_creep(creep_id, false)
				creep_id += 1
		_check(state.is_wave_clear(), "wave %s clears when every queued creep resolves" % wave.number)
		state.advance_after_clear()
	_check(state.phase == RunStateModel.Phase.VICTORY and boss_seen, "every cleared level including the bosses ends in victory")

	var doomed := RunStateModel.new(Catalog.waves.size(), 3, BalanceConfig.STARTING_GOLD)
	doomed.begin_wave(PackedInt32Array([3, 0, 0, 0, 0, 0, 0, 0, 0]))
	for leak_id in range(3):
		doomed.register_spawn(0, 100 + leak_id)
		doomed.resolve_creep(100 + leak_id, true)
	_check(doomed.phase == RunStateModel.Phase.DEFEAT and doomed.results()["victory"] == false and doomed.results()["wave_reached"] == 1, "three leaks against three lives resolve to defeat with results")


# --- Ownership and authority ------------------------------------------------

func _test_build_permission_policy() -> void:
	var owners := PackedInt32Array([2, 0, 0, 0, 0, 0, 0, 0, 3])
	_check(BuildPermissionPolicy.can_control(2, 0, owners), "a player controls their assigned position")
	_check(not BuildPermissionPolicy.can_control(3, 0, owners), "a player cannot control another player's position")
	_check(BuildPermissionPolicy.can_control(1, 1, owners), "the host controls unfilled positions")
	_check(not BuildPermissionPolicy.can_control(1, 0, owners), "the host cannot override an assigned position")
	_check(BuildPermissionPolicy.can_control(3, 8, owners) and not BuildPermissionPolicy.can_control(1, 8, owners), "position nine belongs to its assigned player")
	_check(not BuildPermissionPolicy.can_control(2, 9, owners) and not BuildPermissionPolicy.can_control(0, 1, owners), "invalid positions and peers are rejected")
	_check(BuildPermissionPolicy.controlled_positions(1, owners) == [1, 2, 3, 4, 5, 6, 7], "host control list covers every unfilled position")
	var roster := [
		{"steam_id": 111, "lane": 1, "is_host": true},
		{"steam_id": 222, "lane": 2, "is_host": false},
		{"steam_id": 333, "lane": 9, "is_host": false},
	]
	var lookup := func(steam_id: int) -> int: return {222: 5, 333: 6}.get(steam_id, 0)
	var resolved := BuildPermissionPolicy.resolve_owners(roster, 9, lookup, 111)
	_check(resolved == PackedInt32Array([1, 5, 0, 0, 0, 0, 0, 0, 6]), "roster resolves into peer ownership with host as peer one")
	var transferred := BuildPermissionPolicy.transfer_to_host(resolved, 5)
	_check(transferred[1] == 1 and transferred[8] == 6, "disconnect transfers only the departed peer's positions to the host")


func _test_unauthorized_client_build_rejected() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	state.position_owners[0] = 2
	var starting_gold := state.team_gold
	var p1_cell := P1_OPEN
	var p2_cell := P2_OPEN
	_check(game.call("_try_place_tower", "bolt", p1_cell, 3) == WintermaulMap.Placement.NOT_OWNED, "a client cannot build in another player's position")
	_check(game.call("_try_place_tower", "bolt", p1_cell, 1) == WintermaulMap.Placement.NOT_OWNED, "the host cannot build in an assigned client position")
	_check(state.team_gold == starting_gold and state.towers.is_empty(), "rejected ownership requests spend no gold")
	_check(game.call("_try_place_tower", "bolt", p1_cell, 2) == WintermaulMap.Placement.OK, "the assigned client builds in its own position")
	_check(game.call("_try_place_tower", "bolt", p2_cell, 1) == WintermaulMap.Placement.OK, "the host builds in unfilled positions")
	_check(game.call("_try_place_tower", "ghost_tower", P1_OPEN_B, 1) == WintermaulMap.Placement.NO_TOWER_SELECTED, "unknown tower ids are rejected")
	_check(game.call("_try_place_tower", "bolt", Vector2i(-5, 400), 1) == WintermaulMap.Placement.OUT_OF_BOUNDS, "malformed cells are rejected")
	var tower_id: int = state.tower_records()[0]["id"]
	_check(not game.call("_try_upgrade_tower", tower_id, "human_crossbow", 3) and not game.call("_try_sell_tower", tower_id, 3), "clients cannot upgrade or sell towers they do not control")
	_check(not game.call("_try_set_targeting", tower_id, TowerTargeting.Mode.LAST, 3), "clients cannot retarget towers they do not control")
	_check(game.call("_try_set_targeting", tower_id, TowerTargeting.Mode.LAST, 2) and state.get_tower(tower_id)["targeting"] == TowerTargeting.Mode.LAST, "owners can change target priority")
	_check(not game.call("_try_set_targeting", tower_id, 99, 2), "invalid targeting modes are rejected")
	game.queue_free()


func _test_disconnect_takeover() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	state.position_owners[0] = 2
	state.position_owners[1] = 3
	game.call("_on_peer_disconnected", 2)
	_check(state.position_owners[0] == 1 and state.position_owners[1] == 3, "non-host disconnect hands only that peer's positions to the host")
	_check(game.call("_try_place_tower", "bolt", P1_OPEN, 1) == WintermaulMap.Placement.OK, "host can build in a taken-over position")
	_check(state.phase == RunStateModel.Phase.BUILD, "non-host disconnect does not end the run")
	game.queue_free()


func _test_load_acknowledgement_gates_countdown() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	game.set("_awaiting_peers", [2] as Array[int])
	var countdown_before: float = game.get("build_countdown")
	game.call("_process", 1.0)
	_check(is_equal_approx(game.get("build_countdown"), countdown_before) and game.call("is_waiting_for_players"), "build countdown waits for load acknowledgements")
	game.call("_on_peer_disconnected", 2)
	game.call("_process", 1.0)
	_check(game.get("build_countdown") < countdown_before, "countdown resumes once every peer acknowledged or left")
	game.set("_awaiting_peers", [4] as Array[int])
	game.call("_process", BalanceConfig.LOAD_ACK_TIMEOUT + 1.0)
	_check(not game.call("is_waiting_for_players"), "load acknowledgement times out instead of stalling the run")
	game.queue_free()


func _test_wave_one_ready_check() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	game.set("_wave_one_pending_ready", [2, 3] as Array[int])
	game.set("_wave_one_total", 2)
	var countdown_before: float = game.get("build_countdown")
	game.call("_process", 1.0)
	_check(state.phase == RunStateModel.Phase.BUILD and game.get("build_countdown") < countdown_before, "wave 1 counts down toward the fallback timeout while players are not ready")
	game.call("_mark_wave_one_ready", 2)
	game.call("_process", 1.0)
	_check(state.phase == RunStateModel.Phase.BUILD, "wave 1 still waits while at least one player has not readied up")
	game.call("_mark_wave_one_ready", 3)
	game.call("_process", 1.0)
	_check(state.phase == RunStateModel.Phase.WAVE, "wave 1 starts immediately once every player has readied up, ahead of the fallback timer")
	game.queue_free()

	var timeout_game: Node = _instantiate_game()
	root.add_child(timeout_game)
	var timeout_state: RunState = timeout_game.get("run_state")
	timeout_game.set("_wave_one_pending_ready", [2] as Array[int])
	timeout_game.set("_wave_one_total", 1)
	timeout_game.call("_process", BalanceConfig.WAVE_ONE_READY_TIMEOUT + 1.0)
	_check(timeout_state.phase == RunStateModel.Phase.WAVE, "wave 1 falls back to starting after 1.5 minutes even if a player never readies up")
	timeout_game.queue_free()

	var disconnect_game: Node = _instantiate_game()
	root.add_child(disconnect_game)
	disconnect_game.set("_wave_one_pending_ready", [2, 3] as Array[int])
	disconnect_game.call("_on_peer_disconnected", 2)
	_check((disconnect_game.get("_wave_one_pending_ready") as Array[int]) == [3], "a disconnecting player is removed from the wave-1 ready check")
	disconnect_game.queue_free()


# --- Map, pathing, and placement ---------------------------------------------

func _test_grid_projection_and_placement() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var open_cell := P1_OPEN
	_check(map.world_to_grid(map.grid_to_world(open_cell)) == open_cell, "orthogonal grid projection round-trips")
	_check(map.get_route_count() == 9, "Wintermaul battlefield exposes nine creep entrances")
	var routes_share_goal := true
	for lane_id in range(map.get_route_count()):
		routes_share_goal = routes_share_goal and map.get_route_start(lane_id) != map.get_route_goal(lane_id)
		routes_share_goal = routes_share_goal and map.get_route_goal(lane_id) == WintermaulMap.GOAL_CELL
	_check(routes_share_goal, "all nine positions converge on the final gate")
	_check(map.get_route_targets(0) == [Vector2i(35, 61), ClassicWintermaulLayout.FINAL_CHECKPOINT, Vector2i(71, 155)], "P1 relays through its checkpoint and the shared relay checkpoint")
	_check(map.get_route_targets(8) == [ClassicWintermaulLayout.FINAL_CHECKPOINT, Vector2i(71, 155)], "P9 defends the relay checkpoint before the final gate")
	_check(map.get_spawner_cells(4).size() == 2 and map.get_spawner_cells(8).size() == 1 and map.get_spawner_cells(0).size() == 1, "position five exposes two spawners; position nine one central spawner")
	var first := map.spawn_creep(1, 4, _creep(1.0, 10))
	var second := map.spawn_creep(2, 4, _creep(1.0, 10))
	_check(first.plane_position != second.plane_position and map.world_to_grid(first.plane_position) in map.get_spawner_cells(4) and map.world_to_grid(second.plane_position) in map.get_spawner_cells(4), "twin spawners alternate creeps deterministically by id")
	var all_routes_open := true
	for lane_id in range(map.get_route_count()):
		for spawn in map.get_spawner_cells(lane_id):
			all_routes_open = all_routes_open and not map.get_grid_path(spawn, map.get_route_targets(lane_id)[0]).is_empty()
	_check(all_routes_open, "every spawner reaches its position checkpoint through the hedges")
	_check(not map.can_place_tower(PORTAL_CELL), "tower placement rejects spawn pad cells")
	_check(not map.can_place_tower(VOID_CELL), "tower placement rejects terrain outside the hedges")
	_check(not map.can_place_tower(Vector2i(16, 0)) and not map.can_place_tower(WintermaulMap.GOAL_CELL), "tower placement rejects hedge walls and the exit pad")
	_check(map.can_place_tower(open_cell), "tower placement accepts an open cell")
	_check(map.get_cell_position_index(open_cell) == 0 and map.get_cell_position_index(P9_OPEN) == 8, "build cells resolve to their owning position")
	var tower := map.spawn_tower(1, open_cell, Bolt)
	_check(tower != null and tower.position_index == 0 and tower.targeting == Bolt.default_targeting, "spawned towers record their position and default targeting")
	_check(not map.can_place_tower(open_cell), "tower placement rejects occupied cells")
	_check(map.get_tower_at(open_cell) == tower and map.get_tower(1) == tower, "towers resolve by cell and by stable id")
	map.queue_free()


func _test_path_grid_anti_block_rollback() -> void:
	var traversable_cells: Dictionary = {}
	for y in range(3):
		for x in range(5):
			traversable_cells[Vector2i(x, y)] = true
	var starts: Array[Vector2i] = [Vector2i(0, 1)]
	var path_grid := PathGridModel.new(Vector2i(5, 3), traversable_cells, starts, Vector2i(4, 1)) as PathGrid
	_check(path_grid.get_path(Vector2i(0, 1), Vector2i(2, 1))[-1] == Vector2i(2, 1), "path grid supports mandatory intermediate targets")
	_check(path_grid.commit_block(Vector2i(2, 0)), "path grid commits the first maze obstacle")
	_check(path_grid.commit_block(Vector2i(2, 1)), "path grid commits an obstacle while one route remains")
	_check(not path_grid.can_block(Vector2i(2, 2)), "path grid rejects the final cell of a sealing wall")
	_check(not path_grid.get_path(starts[0]).is_empty() and path_grid.revision == 2, "rejected path probe rolls back solidity and revision")
	var segment: Array[Dictionary] = [{"start": Vector2i(0, 1), "target": Vector2i(0, 0)}]
	_check(not path_grid.can_block(Vector2i(0, 0), [], segment), "path grid protects mandatory relay segments")
	_check(path_grid.unblock(Vector2i(2, 1)) and path_grid.revision == 3 and not path_grid.is_blocked(Vector2i(2, 1)), "path grid reopens sold cells and bumps the revision")
	_check(not path_grid.unblock(Vector2i(2, 1)), "unblocking an open cell is a no-op")


func _test_tower_collision_pathing() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var lane_start := map.get_route_start(0)
	var path_before := map.get_grid_path(lane_start, map.get_route_targets(0)[0])
	var obstacle_cell: Vector2i = path_before[12]
	_check(obstacle_cell in path_before and map.get_cell_position_index(obstacle_cell) == 0, "initial ground path crosses the future tower cell")
	_check(map.can_place_tower(obstacle_cell), "interior route cells accept maze towers when an alternate path exists")
	map.spawn_tower(1, obstacle_cell, Bolt)
	var path_after := map.get_grid_path(lane_start, map.get_route_targets(0)[0])
	_check(map.get_grid_revision() == 1, "accepted tower collision increments the path revision")
	_check(not obstacle_cell in path_after and path_after != path_before, "tower collision forces a new shortest path")
	_seal_lane_one_except(map, SEAL_CELL)
	_check(map.can_place_tower(Vector2i(42, 54), Bolt.footprint), "a tower beside the gap still leaves the route open")
	_check(not map.can_place_tower(SEAL_CELL, Bolt.footprint), "anti-block rejects sealing the lane exit gap")
	map.queue_free()


func _test_sell_reopens_route() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var lane_start := map.get_route_start(0)
	var target := map.get_route_targets(0)[0]
	var original := map.get_grid_path(lane_start, target)
	var cell: Vector2i = original[12]
	map.spawn_tower(1, cell, Bolt)
	map.spawn_creep(5, 0, _creep(1.0, 10))
	var runner := map.get_creep(5)
	runner._process(0.0)
	_check(map.remove_tower(1), "selling removes the tower by id")
	_check(map.get_grid_revision() == 2 and map.get_grid_path(lane_start, target) == original, "selling reopens the cell and restores the shortest route")
	_check(map.can_place_tower(cell) and map.get_tower_at(cell) == null, "sold cells become buildable again")
	runner._process(0.0)
	_check(runner.get("_path_revision") == map.get_grid_revision(), "active creeps repath after a sale")
	_check(not map.remove_tower(1), "selling an already sold tower is ignored")
	map.queue_free()


func _test_relay_stage_continuity() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var finished_ids: Array[int] = []
	map.creep_route_finished.connect(func(creep_id: int) -> void: finished_ids.append(creep_id))
	map.spawn_creep(77, 0, _creep(1.0, 10))
	var runner := map.get_node("RouteRunners").get_child(0) as RouteRunner
	runner.take_damage(3)
	var targets := map.get_route_targets(0)
	for stage_index in range(targets.size() - 1):
		runner.plane_position = map.grid_to_world(targets[stage_index])
		runner.set("_segment_index", (runner.get("_points") as PackedVector2Array).size() - 1)
		runner._process(0.0)
		_check(is_instance_valid(runner) and runner.health == 7 and runner.creep_id == 77, "relay stage preserves creep identity and health")
		_check(finished_ids.is_empty(), "intermediate relay checkpoint does not resolve a creep")
	_check(runner.get_stage_index() == targets.size() - 1 and runner.get_progress() > RouteRunner.STAGE_PROGRESS_WEIGHT, "route progress increases across relay stages")
	runner.plane_position = map.grid_to_world(targets[-1])
	runner.set("_segment_index", (runner.get("_points") as PackedVector2Array).size() - 1)
	runner._process(0.0)
	runner._process(0.0)
	_check(finished_ids == [77], "creep resolves exactly once after reaching the final gate")
	map.queue_free()


func _test_active_creep_collision() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	map.spawn_creep(43, 0, _creep(1.0, 10))
	var runner := map.get_node("RouteRunners").get_child(0) as RouteRunner
	var occupied_cell := P1_CREEP
	runner.plane_position = map.grid_to_world(occupied_cell)
	_check(not map.can_place_tower(occupied_cell), "tower placement cannot overlap an active ground creep")
	_check(map.evaluate_placement(occupied_cell) == WintermaulMap.Placement.CREEP_ON_CELL, "creep overlap reports its own placement reason")

	runner.plane_position = map.grid_to_world(map.get_route_start(0))
	var obstacle_cell: Vector2i = map.get_grid_path(map.get_route_start(0), map.get_route_targets(0)[0])[12]
	map.spawn_tower(1, obstacle_cell, Bolt)
	runner._process(0.0)
	var rerouted_points: PackedVector2Array = runner.get("_points")
	_check(runner.get("_path_revision") == map.get_grid_revision(), "active creep adopts the latest collision revision")
	_check(not map.grid_to_world(obstacle_cell) in rerouted_points, "active creep route avoids the placed tower")
	map.queue_free()


func _test_stable_placement_preview() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var open_cell := P1_OPEN
	var motion := InputEventMouseMotion.new()
	motion.position = map.grid_to_world(open_cell)
	map.set_build_context(true, Bolt, Bolt.cost, 100, ALL_POSITIONS)
	map._unhandled_input(motion)
	map.set_build_context(true, Bolt, Bolt.cost, 100, ALL_POSITIONS)
	_check(map.get("_preview_visible") and map.get("_preview_cell") == open_cell, "state snapshots preserve stationary tower hover")

	map.set_build_context(false, null, 0, 0, [])
	_check(not map.get("_preview_visible"), "disabling building hides the preview")
	map.set_build_context(true, Bolt, Bolt.cost, 100, ALL_POSITIONS)
	var requested_cells: Array[Vector2i] = []
	map.build_cell_requested.connect(func(cell: Vector2i) -> void: requested_cells.append(cell))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.grid_to_world(open_cell)
	map._unhandled_input(click)
	_check(requested_cells == [open_cell], "tower click resolves its cell without prior mouse motion")

	var rejected: Array[int] = []
	map.placement_rejected.connect(func(_cell: Vector2i, reason: int) -> void: rejected.append(reason))
	click.position = map.grid_to_world(VOID_CELL)
	map._unhandled_input(click)
	_check(rejected == [WintermaulMap.Placement.NOT_BUILDABLE], "clicking invalid terrain reports the rejection reason")

	map.spawn_tower(9, open_cell, Bolt)
	var clicked_towers: Array[int] = []
	map.tower_clicked.connect(func(tower_id: int) -> void: clicked_towers.append(tower_id))
	click.position = map.grid_to_world(open_cell)
	map._unhandled_input(click)
	_check(clicked_towers == [9], "clicking a placed tower selects it instead of building")
	map.queue_free()


func _test_placement_reasons() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var open_cell := P1_OPEN
	map.set_build_context(false, Bolt, Bolt.cost, 100, ALL_POSITIONS)
	_check(map.evaluate_build(open_cell) == WintermaulMap.Placement.LOCKED, "locked phases report a locked placement")
	map.set_build_context(true, null, 0, 100, ALL_POSITIONS)
	_check(map.evaluate_build(open_cell) == WintermaulMap.Placement.NO_TOWER_SELECTED, "building without a palette selection asks for a tower")
	map.set_build_context(true, Bolt, Bolt.cost, 100, [1] as Array[int])
	_check(map.evaluate_build(open_cell) == WintermaulMap.Placement.NOT_OWNED, "building outside controlled positions is flagged")
	map.set_build_context(true, Bolt, Bolt.cost, 10, ALL_POSITIONS)
	_check(map.evaluate_build(open_cell) == WintermaulMap.Placement.UNAFFORDABLE, "unaffordable towers are flagged before spending")
	map.set_build_context(true, Bolt, Bolt.cost, 100, ALL_POSITIONS)
	_seal_lane_one_except(map, SEAL_CELL)
	_check(map.evaluate_build(SEAL_CELL) == WintermaulMap.Placement.BLOCKS_ROUTE, "sealing placements are flagged as blocked routes")
	_check(map.evaluate_build(VOID_CELL) == WintermaulMap.Placement.NOT_BUILDABLE, "non-build terrain is flagged")
	_check(map.evaluate_build(Vector2i(-1, 0)) == WintermaulMap.Placement.OUT_OF_BOUNDS, "out-of-bounds cells are flagged")
	_check(map.evaluate_build(open_cell) == WintermaulMap.Placement.OK, "a valid affordable owned cell is accepted")
	var texts: Dictionary = {}
	for result in range(WintermaulMap.Placement.size()):
		texts[WintermaulMap.placement_text(result)] = true
	_check(texts.size() == WintermaulMap.Placement.size(), "every placement reason has a distinct player-facing message")
	map.queue_free()


# --- Camera -------------------------------------------------------------------

func _test_battlefield_camera_controls() -> void:
	var world := Node3D.new()
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	var camera := BattlefieldCameraScript.new() as BattlefieldCamera
	world.add_child(map)
	world.add_child(camera)
	root.add_child(world)
	var world_rect := map.get_world_rect()
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var center_screen := viewport_size * 0.5
	_check(is_equal_approx(camera.zoom_level, BattlefieldCamera.DEFAULT_ZOOM), "battlefield camera starts at the WC3 default distance")
	_check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "battlefield camera uses a WC3-style perspective projection")
	_check(camera.rotation.y == 0.0 and camera.rotation.z == 0.0 and camera.rotation.x < 0.0, "battlefield camera is a fixed downward tilt without yaw")
	_check(not camera.get_visible_plane_rect().encloses(world_rect), "the default view shows part of the map, not all of it")
	camera.set_zoom_level(-100.0)
	_check(is_equal_approx(camera.zoom_level, BattlefieldCamera.MIN_ZOOM) and not camera.get_visible_plane_rect().encloses(world_rect), "even fully zoomed out the camera never frames the whole map")
	var far_distance := camera.position.distance_to(MapProjection.to_3d(camera.get_focus()))
	camera.set_zoom_level(100.0)
	var close_distance := camera.position.distance_to(MapProjection.to_3d(camera.get_focus()))
	var default_distance := camera.get_default_distance()
	_check(absf(far_distance - default_distance * BattlefieldCamera.FAR_FACTOR) < 0.01 and absf(close_distance - default_distance * BattlefieldCamera.CLOSE_FACTOR) < 0.01, "zoom dollies between the far cap and the close view")
	camera.set_zoom_level(BattlefieldCamera.DEFAULT_ZOOM)
	var target := world_rect.get_center()
	camera.focus_on(target)
	_check(camera.screen_to_plane(center_screen).distance_to(target) < 0.5, "focus_on centres the view on a map point")
	var probe := map.grid_to_world(P4_OPEN)
	var round_trip := camera.screen_to_plane(camera.plane_to_screen(probe))
	_check(round_trip.distance_to(probe) < 0.5, "plane/screen projection round-trips")
	var edge_area := Rect2(100, 80, 800, 600)
	_check(camera.get_edge_direction(Vector2(101, 380), edge_area) == Vector2.LEFT, "battlefield left edge pans left")
	_check(camera.get_edge_direction(Vector2(899, 380), edge_area) == Vector2.RIGHT, "battlefield right edge pans right")
	_check(camera.get_edge_direction(Vector2(500, 81), edge_area) == Vector2.UP, "battlefield top edge pans up")
	_check(camera.get_edge_direction(Vector2(500, 679), edge_area) == Vector2.DOWN, "battlefield bottom edge pans down")
	_check(camera.get_edge_direction(Vector2(101, 81), edge_area).is_equal_approx(Vector2(-1, -1).normalized()), "battlefield corner pan is normalized")
	_check(camera.get_edge_direction(Vector2(500, 380), edge_area) == Vector2.ZERO, "battlefield center does not edge-pan")
	_check(camera.get_edge_direction(Vector2(950, 380), edge_area) == Vector2.ZERO, "cursor outside battlefield does not edge-pan")
	camera._move_camera(Vector2(-1, -1), 1000.0)
	var visible := camera.get_visible_plane_rect()
	var near_left := camera.screen_to_plane(Vector2(0, viewport_size.y))
	_check(absf(near_left.x - world_rect.position.x) < 0.5 and absf(visible.position.y - world_rect.position.y) < 0.5, "sustained camera movement clamps to the map corner")
	camera._move_camera(Vector2(1, 1), 1000.0)
	visible = camera.get_visible_plane_rect()
	var near_right := camera.screen_to_plane(viewport_size)
	_check(absf(near_right.x - world_rect.end.x) < 0.5 and absf(visible.end.y - world_rect.end.y) < 0.5, "camera movement reaches but does not cross the opposite map bounds")
	camera.focus_on(target)
	var anchor_screen := center_screen + Vector2(180, -120)
	var anchor_plane := camera.screen_to_plane(anchor_screen)
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	zoom_event.position = anchor_screen
	camera._unhandled_input(zoom_event)
	_check(camera.zoom_level > BattlefieldCamera.DEFAULT_ZOOM, "battlefield camera responds to wheel zoom")
	_check(camera.screen_to_plane(anchor_screen).distance_to(anchor_plane) < 1.0, "wheel zoom keeps the ground under the cursor fixed")
	var initial_center := camera.get_visible_plane_rect().get_center()
	var drag_start := InputEventMouseButton.new()
	drag_start.button_index = MOUSE_BUTTON_MIDDLE
	drag_start.pressed = true
	camera._unhandled_input(drag_start)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(100000, 100000)
	camera._unhandled_input(drag_motion)
	visible = camera.get_visible_plane_rect()
	var near_edge := Rect2(camera.screen_to_plane(Vector2(0, viewport_size.y)), Vector2.ZERO).expand(camera.screen_to_plane(viewport_size))
	_check(visible.get_center() != initial_center and world_rect.grow(0.5).encloses(near_edge) and visible.position.y >= world_rect.position.y - 0.5 and visible.end.y <= world_rect.end.y + 0.5, "battlefield drag pan remains inside map bounds")
	world.queue_free()


func _test_edge_pan_only_at_window_edges() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var camera := game.get_node(CAMERA_PATH) as BattlefieldCamera
	var window := (game as Control).get_global_rect()
	var console_top := (game.get_node("WorldClip") as Control).get_global_rect().end.y
	var area: Control = camera.get("_edge_pan_area")
	_check(area == game, "edge panning uses the whole window, not the battlefield view")
	_check(camera.get_edge_direction(Vector2(window.get_center().x, console_top + 2.0), window) == Vector2.ZERO, "moving onto the console does not pan the camera")
	_check(camera.get_edge_direction(Vector2(window.get_center().x, 20.0), window) == Vector2.ZERO, "hovering the top bar does not pan the camera")
	_check(camera.get_edge_direction(Vector2(window.get_center().x, window.end.y - 1.0), window) == Vector2.DOWN, "the bottom window edge still pans down, as in WC3")
	game.queue_free()


func _test_solo_camera_startup_focus() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var camera := game.get_node(CAMERA_PATH) as BattlefieldCamera
	var map := game.get_node(MAP_PATH) as WintermaulMap
	_check(is_equal_approx(camera.zoom_level, BattlefieldCamera.DEFAULT_ZOOM), "solo game starts at the WC3 default distance")
	var view_size := camera.get_viewport().get_visible_rect().size
	var focus := camera.screen_to_plane(view_size * 0.5)
	_check(map.get_position_world_rect(8).grow(WintermaulMap.TILE_SIZE * 2.0).has_point(focus), "solo game starts on Position 9, where every lane meets the gate")
	var across := camera.screen_to_plane(Vector2(0, view_size.y * 0.5)).distance_to(camera.screen_to_plane(Vector2(view_size.x, view_size.y * 0.5)))
	var towers_across := across / (WintermaulMap.TILE_SIZE * 2.0)
	_check(towers_across > 14.0 and towers_across < 26.0, "the default view spans about 19 towers, like WC3 (got %.1f)" % towers_across)
	var sun := game.get_node("WorldClip/BattlefieldView/BattlefieldViewport/World/Sun") as DirectionalLight3D
	var settings := root.get_node("GameSettings")
	_check(sun.shadow_enabled == bool(settings.get("shadows_enabled")), "the sun follows the real-time shadows setting")
	var previous: bool = settings.get("shadows_enabled")
	settings.set("shadows_enabled", not previous)
	settings.emit_signal("changed")
	_check(sun.shadow_enabled == not previous, "changing the shadows setting updates the running game")
	settings.set("shadows_enabled", previous)
	settings.emit_signal("changed")
	var creep := map.spawn_creep(9001, 0, Grunt)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.plane_to_screen(creep.plane_position, creep.get_visual_height() * 0.5)
	map._unhandled_input(click)
	_check(int(game.get("_selected_creep_id")) == 9001, "clicking a creep selects it for inspection")
	game.call("_refresh_creep_panel")
	var hud: Control = game.get("hud")
	_check((game.get_node("Hud").find_child("TowerName", true, false) as Label).text.begins_with("Grunt"), "the console shows the selected creep's details")
	creep.take_damage(creep.health)
	game.call("_refresh_creep_panel")
	_check(int(game.get("_selected_creep_id")) == 0, "a dead creep's selection clears")
	hud.call("toggle_multiboard")
	_check(not (game.get_node("Hud").find_child("PositionsList", true, false) as Control).visible, "the multiboard collapses to its title")
	hud.call("toggle_multiboard")
	var state: RunState = game.get("run_state")
	_check(state.position_owners == PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1, 1]), "solo host controls all nine positions")
	steam_session.set("is_solo_session", false)
	game.queue_free()


func _test_multiplayer_camera_startup_focus() -> void:
	var steam_session := root.get_node("SteamSession")
	var steamworks := root.get_node("Steamworks")
	var mock_roster: Array[Dictionary] = [{"steam_id": steamworks.get("steam_id"), "lane": 4, "is_host": true, "name": "Host"}]
	steam_session.set("roster", mock_roster)
	steam_session.set("is_host", true)
	_check(steam_session.call("get_local_position_number") == 4, "session resolves a multiplayer local roster position")
	var game: Node = _instantiate_game()
	root.add_child(game)
	var camera := game.get_node(CAMERA_PATH) as BattlefieldCamera
	var map := game.get_node(MAP_PATH) as WintermaulMap
	_check(is_equal_approx(camera.zoom_level, BattlefieldCamera.DEFAULT_ZOOM), "multiplayer game starts at the WC3 default distance")
	var focus := camera.screen_to_plane(camera.get_viewport().get_visible_rect().size * 0.5)
	_check(map.get_position_world_rect(3).grow(WintermaulMap.TILE_SIZE * 4.0).has_point(focus), "multiplayer camera starts on the local player's position")
	var state: RunState = game.get("run_state")
	_check(state.position_owners[3] == 1 and state.position_owners[0] == 0, "roster ownership marks the host position and leaves others host-controlled")
	steam_session.set("roster", [] as Array[Dictionary])
	steam_session.set("is_host", false)
	game.queue_free()


# --- Combat -------------------------------------------------------------------

func _test_basic_tower_combat() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var killed_ids: Array[int] = []
	var fired: Array[int] = []
	map.creep_killed.connect(func(creep_id: int) -> void: killed_ids.append(creep_id))
	map.tower_fired.connect(func(tower_id: int, _creep_id: int) -> void: fired.append(tower_id))
	map.spawn_creep(42, 0, _creep(1.0, Bolt.damage))
	map.get_creep(42).plane_position = map.grid_to_world(P1_OPEN + Vector2i(0, 1))
	var tower := map.spawn_tower(1, P1_OPEN_B, Bolt)
	tower._process(Bolt.attack_cooldown)
	_check(fired == [1] and map.get_node("Projectiles").get_child_count() == 1, "bolt tower fires a projectile at a creep in range")
	_check(killed_ids.is_empty(), "damage resolves on impact rather than at fire time")
	var projectile := map.get_node("Projectiles").get_child(0) as Projectile
	projectile._process(10.0)
	_check(killed_ids == [42], "bolt projectile damages and kills a nearby creep on impact")
	_check(map.get_active_creeps().is_empty() and map.effects.active_count() > 0, "kills remove the creep and spawn death feedback")
	map.queue_free()


func _test_targeting_priorities() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var origin := map.grid_to_world(Vector2i(32, 12))
	var near := map.spawn_creep(1, 0, _creep(1.0, 10))
	var far_strong := map.spawn_creep(2, 0, _creep(1.0, 50))
	var leader := map.spawn_creep(3, 0, _creep(1.0, 20))
	near.plane_position = origin + Vector2(10, 0)
	near.set("_distance_travelled", 50.0)
	far_strong.plane_position = origin + Vector2(60, 0)
	far_strong.set("_distance_travelled", 100.0)
	leader.plane_position = origin + Vector2(40, 0)
	leader.set("_distance_travelled", 900.0)
	var candidates := map.get_active_creeps()
	_check(TowerTargeting.select(candidates, origin, 100.0, TowerTargeting.Mode.FIRST) == leader, "FIRST targets the creep furthest along the route")
	_check(TowerTargeting.select(candidates, origin, 100.0, TowerTargeting.Mode.LAST) == near, "LAST targets the creep least far along the route")
	_check(TowerTargeting.select(candidates, origin, 100.0, TowerTargeting.Mode.STRONGEST) == far_strong, "STRONGEST targets the highest health creep")
	_check(TowerTargeting.select(candidates, origin, 100.0, TowerTargeting.Mode.NEAREST) == near, "NEAREST targets the closest creep")
	_check(TowerTargeting.select(candidates, origin, 30.0, TowerTargeting.Mode.FIRST) == near, "targeting ignores creeps outside attack range")
	_check(TowerTargeting.select([], origin, 100.0, TowerTargeting.Mode.FIRST) == null, "targeting returns null with no candidates")
	_check(TowerTargeting.mode_name(TowerTargeting.Mode.STRONGEST) == "Strongest" and not TowerTargeting.is_valid_mode(4), "targeting modes expose names and validate ids")
	map.queue_free()


func _test_splash_slow_and_armor() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var center := map.grid_to_world(Vector2i(32, 20))
	var primary := map.spawn_creep(1, 0, _creep(4.0, 30))
	var nearby := map.spawn_creep(2, 0, _creep(4.0, 30))
	var distant := map.spawn_creep(3, 0, _creep(4.0, 30))
	primary.plane_position = center
	nearby.plane_position = center + Vector2(20, 0)
	distant.plane_position = center + Vector2(200, 0)
	var cannon_stats := Cannon.stats()
	var payload := {"damage": cannon_stats["damage"], "splash_radius": cannon_stats["splash_radius"], "armor_pierce": 0}
	var hits := CombatResolver.resolve_impact(map.get_active_creeps(), payload, center, primary)
	_check(hits.size() == 2 and primary.health == 30 - int(cannon_stats["damage"]) and nearby.health == primary.health and distant.health == 30, "splash damages every creep inside the radius and none outside")

	var frost_stats := Frost.stats()
	var slow_payload := {"damage": frost_stats["damage"], "splash_radius": 0.0, "slow_factor": frost_stats["slow_factor"], "slow_duration": frost_stats["slow_duration"]}
	var base_speed := distant.current_speed()
	CombatResolver.resolve_impact(map.get_active_creeps(), slow_payload, distant.plane_position, distant)
	_check(distant.is_slowed() and is_equal_approx(distant.current_speed(), base_speed * (1.0 - float(frost_stats["slow_factor"]))), "frost impact slows the target by the slow factor")
	distant.call("_tick_status", float(frost_stats["slow_duration"]) + 0.1)
	_check(not distant.is_slowed() and is_equal_approx(distant.current_speed(), base_speed), "slow expires after its duration and speed recovers")
	var immune := map.spawn_creep(4, 0, _creep(4.0, 30, 0, true))
	_check(not immune.apply_slow(0.5, 2.0), "slow-immune creeps ignore slows")

	var armored := map.spawn_creep(5, 0, _creep(2.0, 40, 2))
	_check(armored.take_damage(5) == 3 and armored.health == 37, "armor reduces incoming damage")
	_check(armored.take_damage(5, 2) == 5 and armored.health == 32, "armor pierce ignores armor")
	_check(armored.take_damage(1) == 1, "damage never drops below one after armor")
	_check(armored.take_damage(0) == 0, "non-positive damage is ignored")

	var mender := map.spawn_creep(6, 0, _creep(3.5, 20, 0, false, 4.0))
	mender.take_damage(10)
	mender.call("_tick_status", 1.0)
	_check(mender.health == 14, "regenerating creeps recover health over time")
	mender.call("_tick_status", 10.0)
	_check(mender.health == 20, "regeneration never exceeds max health")

	var speedy := map.spawn_creep(7, 0, _creep(4.0, 10), -1, 1.15)
	_check(is_equal_approx(speedy.current_speed(), 4.0 * WintermaulMap.TILE_SIZE * 1.15), "run creep speed multipliers apply to movement")
	map.queue_free()


func _test_mid_wave_tower_placement() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0]))
	game.call("_try_place_tower", "bolt", P1_OPEN)
	var towers := game.get_node(MAP_PATH + "/Towers")
	_check(towers.get_child_count() == 1, "host placement handler spawns towers during active waves")
	_check(state.team_gold == BalanceConfig.STARTING_GOLD - Bolt.cost, "mid-wave tower placement charges authoritative gold")
	_check(state.towers.size() == 1 and state.tower_records()[0]["cell"] == P1_OPEN, "authoritative tower records mirror placed towers")
	game.queue_free()


func _test_two_by_two_footprints() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	_check(Bolt.footprint == Vector2i(2, 2) and Cannon.footprint == Vector2i(2, 2) and Frost.footprint == Vector2i(2, 2), "shipped towers use 2x2 footprints")
	var anchor := P1_OPEN
	var cells := WintermaulMap.footprint_cells(anchor, Bolt.footprint)
	_check(cells.size() == 4 and cells.has(anchor + Vector2i(1, 1)), "a 2x2 footprint covers four cells from its top-left anchor")
	var corner := (Vector2(anchor) + Vector2.ONE) * WintermaulMap.TILE_SIZE
	_check(map.anchor_for_world(corner + Vector2(3, 3), Bolt.footprint) == anchor and map.anchor_for_world(corner - Vector2(3, 3), Bolt.footprint) == anchor, "the cursor snaps a 2x2 preview to the nearest grid intersection")
	_check(map.anchor_for_world(corner + Vector2(3, 3), Vector2i.ONE) == anchor + Vector2i.ONE, "1x1 previews still use the hovered cell")
	var tower := map.spawn_tower(1, anchor, Bolt)
	_check(tower != null and tower.plane_position.is_equal_approx(corner), "a 2x2 tower is centered on its footprint")
	var covered := true
	for cell in cells:
		covered = covered and map.get_tower_at(cell) == tower
	_check(covered, "every footprint cell resolves to the tower for picking")
	_check(map.evaluate_placement(anchor + Vector2i(1, 0), Bolt.footprint) == WintermaulMap.Placement.OCCUPIED, "an overlapping 2x2 placement is rejected")
	_check(map.can_place_tower(anchor + Vector2i(2, 0), Bolt.footprint), "an adjacent 2x2 placement is accepted")
	_check(map.remove_tower(1), "a 2x2 tower can be sold")
	var freed := true
	for cell in cells:
		freed = freed and map.get_tower_at(cell) == null
	_check(freed and map.can_place_tower(anchor, Bolt.footprint), "selling a 2x2 tower frees all four cells")
	var straddles := false
	for y in range(WintermaulMap.GRID_SIZE.y - 1):
		for x in range(WintermaulMap.GRID_SIZE.x - 1):
			var cell := Vector2i(x, y)
			var a := map.get_cell_position_index(cell)
			var b := map.get_cell_position_index(cell + Vector2i(1, 0))
			if a >= 0 and b >= 0 and a != b and map.get_cell_position_index(cell + Vector2i(0, 1)) == a and map.get_cell_position_index(cell + Vector2i(1, 1)) == b:
				straddles = true
				_check(map.evaluate_placement(cell, Bolt.footprint) == WintermaulMap.Placement.NOT_BUILDABLE, "a 2x2 footprint cannot straddle two positions")
				break
		if straddles:
			break
	if not straddles:
		_check(true, "no two positions share a buildable border to straddle")
	var grid := PathGridModel.new(Vector2i(3, 3), {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true, Vector2i(0, 1): true, Vector2i(2, 1): true, Vector2i(0, 2): true, Vector2i(1, 2): true, Vector2i(2, 2): true}, [Vector2i(0, 0)] as Array[Vector2i], Vector2i(2, 2))
	_check(not grid.commit_block_cells([Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i]) and not grid.is_blocked(Vector2i(1, 0)), "footprint commits are all-or-nothing when any cell is not traversable")
	_check(not grid.can_block_cells([Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i]), "a footprint probe rejects sealing the start as a whole")
	_check(grid.can_block_cells([Vector2i(1, 0)] as Array[Vector2i]) and grid.can_block_cells([Vector2i(0, 1)] as Array[Vector2i]), "each cell alone still leaves the route open")
	map.queue_free()


func _test_blocked_placement_preserves_gold() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var starting_gold := state.team_gold
	_seal_lane_one_except(game.get_node(MAP_PATH) as WintermaulMap, SEAL_CELL)
	_check(game.call("_try_place_tower", "bolt", SEAL_CELL) == WintermaulMap.Placement.BLOCKS_ROUTE, "host reports why a sealing tower was rejected")
	var towers := game.get_node(MAP_PATH + "/Towers")
	_check(towers.get_child_count() == SEAL_NEIGHBOURS.size(), "host rejects a tower that seals a creep route")
	_check(state.team_gold == starting_gold, "rejected collision placement does not spend gold")
	game.queue_free()


func _test_upgrade_and_sell_economy() -> void:
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	state.team_gold = 500
	_check(game.call("_try_place_tower", "bolt", P1_OPEN) == WintermaulMap.Placement.OK, "bolt tower is placed for the economy test")
	var tower_id: int = state.tower_records()[0]["id"]
	var gold_after_build := state.team_gold
	var knight := Catalog.get_tower("human_knight")
	var crossbow := Catalog.get_tower("human_crossbow")
	var musket := Catalog.get_tower("human_musket")
	_check(not game.call("_try_upgrade_tower", tower_id, "human_musket"), "a tower cannot skip to a tower outside its options")
	_check(game.call("_try_upgrade_tower", tower_id, "human_crossbow"), "owner picks one branch of the upgrade tree")
	_check(state.team_gold == gold_after_build - crossbow.cost and state.get_tower(tower_id)["definition_id"] == "bolt" and map.get_tower(tower_id).is_upgrading(), "upgrades charge the target's cost up front and keep the old tower while in progress")
	_check(not game.call("_try_upgrade_tower", tower_id, "human_knight"), "a tower cannot start a second upgrade mid-upgrade")
	game.call("_tick_construction", 60.0)
	_check(state.get_tower(tower_id)["definition_id"] == "human_crossbow" and not map.get_tower(tower_id).is_upgrading(), "the upgrade completes into the chosen tower")
	_check(map.get_tower(tower_id).definition == crossbow and map.get_tower(tower_id).damage() == crossbow.damage, "the tower node becomes the new tower with its stats")
	_check(not game.call("_try_upgrade_tower", tower_id, "human_knight"), "the other branch closes once a branch is taken")
	_check(game.call("_try_upgrade_tower", tower_id, "human_musket"), "owner upgrades further down the branch")
	game.call("_tick_construction", 60.0)
	var invested := Bolt.cost + crossbow.cost + musket.cost
	_check(int(state.get_tower(tower_id)["invested"]) == invested and knight != null, "the record tracks every gold paid into the tower")
	var gold_before_sell := state.team_gold
	_check(game.call("_try_sell_tower", tower_id), "owner sells a tower")
	_check(state.team_gold == gold_before_sell + musket.sell_value(invested), "selling refunds the documented percentage of total investment")
	_check(not game.call("_try_sell_tower", tower_id) and state.team_gold == gold_before_sell + musket.sell_value(invested), "duplicate sell requests are ignored")
	_check(map.get_tower(tower_id) == null and map.can_place_tower(P1_OPEN), "sold towers leave the map and free their cell")
	_check(state.stats["towers_built"] == 1 and state.stats["towers_upgraded"] == 2 and state.stats["towers_sold"] == 1, "run stats track builds, upgrades, and sells")
	state.team_gold = 0
	_check(game.call("_try_place_tower", "bolt", P1_OPEN_B) == WintermaulMap.Placement.UNAFFORDABLE, "unaffordable builds report the reason and spend nothing")
	game.queue_free()


# --- Special creeps -------------------------------------------------------------

func _test_air_creeps() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var gargoyle := Catalog.get_creep("gargoyle")
	_check(gargoyle != null and gargoyle.is_air and "Air" in gargoyle.trait_summary(), "the catalog ships an air creep")
	var flyer := map.spawn_creep(8101, 0, gargoyle)
	var walker := map.spawn_creep(8102, 0, Grunt)
	_check(flyer.position.y > 1.0 and is_zero_approx(walker.position.y), "air creeps fly above the ground")
	var points: PackedVector2Array = flyer.get("_points")
	_check(points.size() >= 2 and points[-1] == map.grid_to_world(flyer.get_current_target()), "air creeps fly toward their current checkpoint")
	var start := flyer.plane_position
	walker.queue_free()
	var cell := map.world_to_grid(start)
	var anchor := cell - Vector2i(1, 1)
	var result := map.evaluate_placement(anchor, Bolt.footprint)
	_check(result != WintermaulMap.Placement.CREEP_ON_CELL, "air creeps never block building under them")
	var cannon_stats := Cannon.stats()
	_check(not cannon_stats["targets_air"] and Bolt.stats()["targets_air"], "Cannon is ground only; Bolt hits air")
	flyer.plane_position = Vector2(400, 400)
	_check(TowerTargeting.select([flyer], Vector2(400, 420), 100.0, TowerTargeting.Mode.FIRST, true, false) == null, "ground-only towers ignore flyers")
	_check(TowerTargeting.select([flyer], Vector2(400, 420), 100.0, TowerTargeting.Mode.FIRST, true, true) == flyer, "towers that hit air target flyers")
	var ground := map.spawn_creep(8103, 0, Grunt)
	ground.plane_position = Vector2(410, 400)
	var hits := CombatResolver.resolve_impact([flyer, ground], {"damage": 5, "splash_radius": 60.0, "targets_air": false}, Vector2(405, 400), ground)
	_check(hits.size() == 1 and hits[0]["creep"] == ground, "ground splash never reaches flyers")
	map.queue_free()


func _test_air_creeps_follow_every_checkpoint() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var gargoyle := Catalog.get_creep("gargoyle")
	# A tower on lane 1's route must not bend the flight path.
	map.spawn_tower(8150, P1_CREEP - Vector2i(1, 1), Bolt)
	var all_lanes_ok := true
	for lane in range(ClassicWintermaulLayout.PLAYER_COUNT):
		var flyer := map.spawn_creep(8160 + lane, lane, gargoyle)
		var targets := map.get_route_targets(lane)
		var closest: Array[float] = []
		for target in targets:
			closest.append(INF)
		var off_route := 0
		var steps := 0
		while not flyer.has_finished() and steps < 6000:
			flyer._process(0.05)
			for index in range(targets.size()):
				closest[index] = minf(closest[index], flyer.plane_position.distance_to(map.grid_to_world(targets[index])))
			if not ClassicWintermaulLayout.is_traversable(map.get_terrain(map.world_to_grid(flyer.plane_position))):
				off_route += 1
			steps += 1
		var visited := flyer.has_finished()
		for distance in closest:
			visited = visited and distance < WintermaulMap.TILE_SIZE * 0.5
		all_lanes_ok = all_lanes_ok and visited and off_route == 0
		if not (visited and off_route == 0):
			printerr("lane %d: closest %s, %d steps over walls or void" % [lane, closest, off_route])
	_check(all_lanes_ok, "flyers from every position pass through each checkpoint and stay over their lanes")
	var mid := map.spawn_creep(8190, 0, gargoyle, -1, 1.0, {"start_position": map.grid_to_world(map.get_route_targets(0)[0]) + Vector2(0, 40), "start_stage": 1})
	var mid_points: PackedVector2Array = mid.get("_points")
	_check(mid_points[-1] == map.grid_to_world(map.get_route_targets(0)[1]) and mid_points.size() >= 2, "mid-route flyers (split children) join their stage's flight path")
	map.queue_free()


func _test_magic_immunity() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var golem := map.spawn_creep(8201, 0, Catalog.get_creep("golem"))
	_check(golem.magic_immune and Frost.is_magic and Frost.stats()["magic"], "golems are magic immune and Frost is magic")
	var before := golem.health
	var frost_hit := CombatResolver.resolve_impact([golem], {"damage": 50, "magic": true, "slow_factor": 0.5, "slow_duration": 2.0}, golem.plane_position, golem)
	_check(golem.health == before and not golem.is_slowed() and frost_hit[0]["damage"] == 0, "magic attacks neither damage nor slow magic-immune creeps")
	_check(TowerTargeting.select([golem], golem.plane_position, 50.0, TowerTargeting.Mode.FIRST, true, true, true) == null, "magic towers do not waste shots on immune creeps")
	CombatResolver.resolve_impact([golem], {"damage": 50}, golem.plane_position, golem)
	_check(golem.health < before, "physical attacks still hurt magic-immune creeps")
	map.queue_free()


func _test_invisible_creeps_and_detection() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var shade := map.spawn_creep(8301, 8, Catalog.get_creep("shade"))
	shade.plane_position = map.grid_to_world(P9_OPEN + Vector2i(0, 6))
	map.refresh_detection()
	_check(shade.is_hidden() and not shade.visible, "invisible creeps are hidden without a detector")
	_check(TowerTargeting.select([shade], shade.plane_position, 100.0, TowerTargeting.Mode.FIRST) == null, "towers cannot target undetected invisible creeps")
	var bolt := map.spawn_tower(8310, P9_OPEN, Bolt)
	map.refresh_detection()
	_check(shade.is_hidden(), "ordinary towers do not detect")
	var sentry := Catalog.get_tower("sentry")
	_check(sentry != null and sentry.detection_range > 0.0, "the catalog ships a detection tower")
	map.spawn_tower(8311, P9_OPEN + Vector2i(-4, 0), sentry)
	map.refresh_detection()
	_check(not shade.is_hidden() and shade.visible, "a detection tower reveals invisible creeps in range")
	_check(TowerTargeting.select([shade], shade.plane_position, 100.0, TowerTargeting.Mode.FIRST) == shade, "revealed creeps can be targeted by any tower")
	shade.plane_position = map.grid_to_world(P9_OPEN + Vector2i(0, 40))
	map.refresh_detection()
	_check(shade.is_hidden(), "leaving detection range hides the creep again")
	var modifiers := RunModifiers.new(Catalog)
	modifiers.apply(Catalog.get_upgrade("snitch_network"))
	var bolt_stats := modifiers.modify_stats(Bolt.stats(), "bolt")
	_check(is_equal_approx(bolt_stats["detection_range"], bolt_stats["range"]), "the Snitch Network upgrade gives every tower detection over its range")
	bolt.apply_stats(Bolt, bolt.targeting, bolt_stats)
	shade.plane_position = bolt.plane_position + Vector2(40, 0)
	map.remove_tower(8311)
	map.refresh_detection()
	_check(not shade.is_hidden(), "towers with the detection upgrade reveal nearby invisible creeps")
	map.queue_free()


func _test_splitters() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	var slime := Catalog.get_creep("slime")
	_check(slime.splits() and Catalog.get_creep("slimelet") == slime.split_into, "the catalog indexes a splitter's children")
	state.begin_wave(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0, 0]))
	game.call("_spawn_entry", 0, {"creep_id": "slime", "health_multiplier": 2.0, "bounty_multiplier": 1.5, "delay": 0.0})
	var parent: RouteRunner = map.get_active_creeps()[0]
	for step in range(40):
		parent._process(0.1)
	var fell_at := parent.plane_position
	var stage := parent.get_stage_index()
	var gold := state.team_gold
	parent.take_damage(100000, 100)
	var children := map.get_active_creeps()
	_check(children.size() == slime.split_count and state.active_creeps.size() == slime.split_count, "a splitter's death spawns and registers its children")
	var placed := true
	for child: RouteRunner in children:
		placed = placed and child.definition_id == "slimelet" and child.plane_position.distance_to(fell_at) < WintermaulMap.TILE_SIZE and child.get_stage_index() == stage
		placed = placed and child.max_health == roundi(slime.split_into.health * 2.0)
	_check(placed, "children appear where the parent fell, on its stage, with its health multiplier")
	_check(state.team_gold == gold + roundi(slime.bounty * 1.5) and not state.is_wave_clear(), "the parent pays its bounty and the wave waits for the children")
	for child: RouteRunner in children:
		child.take_damage(100000, 100)
	_check(state.phase == RunStateModel.Phase.BUILD and state.current_wave_index == 1 and state.team_gold == gold + roundi(slime.bounty * 1.5) + slime.split_count * roundi(slime.split_into.bounty * 1.5), "killing every child clears the level and pays scaled bounties")
	var looped := CreepDefinition.new()
	looped.id = "loop"
	looped.split_into = looped
	looped.split_count = 2
	_check(not looped.is_valid(), "a creep cannot split into itself")
	steam_session.set("is_solo_session", false)
	game.queue_free()


func _test_starting_gold_scales_with_players() -> void:
	_check(BalanceConfig.starting_gold(1) == BalanceConfig.STARTING_GOLD, "solo starts with the base team gold")
	_check(BalanceConfig.starting_gold(4) == BalanceConfig.STARTING_GOLD + 3 * BalanceConfig.STARTING_GOLD_PER_EXTRA_PLAYER, "each extra player adds starting gold")
	_check(BalanceConfig.starting_gold(20) == BalanceConfig.starting_gold(ClassicWintermaulLayout.PLAYER_COUNT), "starting gold caps at a full lobby")


func _test_level_pacing() -> void:
	var boss_wave: WaveDefinition = Catalog.waves[4]
	_check(boss_wave.has_boss() and BalanceConfig.build_duration_for_wave(4, boss_wave) > BalanceConfig.BUILD_DURATION, "boss levels give extra build time")
	_check(is_equal_approx(BalanceConfig.build_duration_for_wave(1, Catalog.waves[1]), BalanceConfig.BUILD_DURATION), "ordinary levels use the default build time")
	_check(is_equal_approx(BalanceConfig.build_duration_for_wave(0, Catalog.waves[0]), BalanceConfig.WAVE_ONE_READY_TIMEOUT), "level one still waits for ready-up")
	var early: WaveDefinition = Catalog.waves[1]
	var late: WaveDefinition = Catalog.waves[25]
	_check(late.spawn_groups[0].health_multiplier > early.spawn_groups[0].health_multiplier * 10.0 and late.spawn_groups[0].bounty_multiplier > early.spawn_groups[0].bounty_multiplier, "creep health and bounty scale up across the run")
	var queue := late.build_spawn_queue(0)
	_check(is_equal_approx(float(queue[0]["bounty_multiplier"]), late.spawn_groups[0].bounty_multiplier), "spawn queues carry the bounty multiplier")


# --- Builder --------------------------------------------------------------------

func _run_builders(game: Node, seconds: float) -> void:
	var step := 0.05
	var elapsed := 0.0
	while elapsed < seconds:
		game.call("_tick_builders", step)
		elapsed += step


func _test_builder_orders_and_construction() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	var builders: BuilderSystem = game.get("builder_system")
	state.team_gold = 1000
	_check(builders != null and builders.has_builder(1) and map.get_builder(1) != null, "the host starts with a builder")
	_check(is_equal_approx(BalanceConfig.builder_speed_pixels(true), 2.0 * BalanceConfig.builder_speed_pixels(false)), "the solo builder runs twice as fast")
	var start := builders.get_position(1)
	_check(map.get_position_world_rect(8).has_point(start), "the solo builder starts in Position 9")
	var gold := state.team_gold
	_check(game.call("_try_order_build", 1, "bolt", P9_OPEN, false) == WintermaulMap.Placement.OK, "a valid build order is accepted")
	_check(state.team_gold == gold and state.towers.is_empty(), "ordering a build spends nothing until the builder arrives")
	_run_builders(game, 5.0)
	_check(state.towers.size() == 1 and state.team_gold == gold - Bolt.cost, "the builder walks to the site, starts construction and pays")
	var tower := map.get_tower(state.tower_records()[0]["id"])
	_check(tower != null and tower.is_under_construction() and tower.progress_ratio() >= 0.0, "a new tower starts under construction")
	var creep := map.spawn_creep(7001, 8, _creep(1.0, 10))
	creep.plane_position = tower.plane_position + Vector2(20, 0)
	tower._process(0.01)
	_check(map.get_node("Projectiles").get_child_count() == 0, "towers under construction do not attack")
	# The probe creep stands inside the footprint; left there, its segment would
	# start in a blocked cell and every later placement would read BLOCKS_ROUTE.
	map.remove_creep(7001)
	game.call("_tick_construction", 10.0)
	_check(not state.towers.values()[0].has("build_remaining") or float(state.towers.values()[0]["build_remaining"]) <= 0.0, "construction completes after its build time")
	# Queued orders show as sites; a plain order replaces the queue.
	_check(game.call("_try_order_build", 1, "sentry", P9_OPEN + Vector2i(4, 0), true) == WintermaulMap.Placement.OK and game.call("_try_order_build", 1, "bolt", P9_OPEN + Vector2i(8, 0), true) == WintermaulMap.Placement.OK, "shift-queued build orders are accepted")
	var records: Array = game.get("_builder_records")
	_check((records[0]["sites"] as Array).size() == 2, "queued build sites are replicated for markers")
	builders.stop(1)
	# Cancelling construction refunds in full.
	_check(game.call("_try_order_build", 1, "sentry", P9_OPEN + Vector2i(4, 0), false) == WintermaulMap.Placement.OK, "a second build order is accepted")
	gold = state.team_gold
	_run_builders(game, 5.0)
	var building_id: int = state.tower_records()[-1]["id"]
	_check(state.team_gold == gold - Catalog.get_tower("sentry").cost and game.call("_try_sell_tower", building_id) and state.team_gold == gold, "cancelling construction refunds the full cost")
	# A site taken while walking fails on arrival without charging.
	_check(game.call("_try_order_build", 1, "bolt", P9_OPEN + Vector2i(0, 4), false) == WintermaulMap.Placement.OK, "a third build order is accepted")
	game.call("_try_place_tower", "bolt", P9_OPEN + Vector2i(0, 4))
	gold = state.team_gold
	_run_builders(game, 5.0)
	_check(state.team_gold == gold and builders.get_orders(1).is_empty(), "an order whose site was taken fails on arrival and spends nothing")
	# Move orders walk the builder to the point.
	var target := map.grid_to_world(P9_OPEN + Vector2i(-6, -10))
	_check(game.call("_try_order_move", 1, target, false), "move orders are accepted")
	_run_builders(game, 4.0)
	_check(builders.get_position(1).distance_to(target) < 1.0 and map.get_builder(1).plane_position.distance_to(target) < 1.0, "the builder and its visual reach the move target")
	steam_session.set("is_solo_session", false)
	game.queue_free()


func _test_races_gate_building_and_offers() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var previous_race: String = steam_session.get("local_race")
	steam_session.set("local_race", "bugs")
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	state.team_gold = 1000
	_check(state.race_of(1) == "bugs", "the host builds with the race picked in the lobby")
	_check(game.call("_try_order_build", 1, "bolt", P9_OPEN, false) == WintermaulMap.Placement.WRONG_RACE, "a builder cannot order another race's tower")
	_check(game.call("_try_place_tower", "bug_soldier_ant", P9_OPEN, 1) == WintermaulMap.Placement.WRONG_RACE, "a builder cannot build an upgrade directly")
	_check(game.call("_try_place_tower", "bug_ant", P9_OPEN, 1) == WintermaulMap.Placement.OK, "a builder builds its own race's towers")
	var snapshot: Dictionary = game.call("_make_state_snapshot")
	_check(snapshot["races"] == {1: "bugs"}, "state snapshots carry each peer's race")
	var lines: PackedStringArray = game.call("_available_lines")
	_check(lines.has("bug_ant") and not lines.has("bolt"), "offer pools only include tower lines the team can build")
	var modifiers := RunModifiers.new(Catalog)
	var offered := {}
	for wave_index in range(40):
		for upgrade_id in UpgradeOffer.roll(Catalog.upgrades, modifiers, 7, wave_index, BalanceConfig.OFFER_CHOICE_COUNT, lines):
			offered[upgrade_id] = true
	_check(not offered.has("bolt_damage") and not offered.has("cannon_splash") and offered.has("pheromone_trails"), "race-aware offers skip other races' tower upgrades")
	state.peer_races[2] = "nonsense"
	_check((game.call("_race_for", 2) as RaceDefinition).id == "humans", "unknown race picks fall back to the default race")
	steam_session.set("local_race", previous_race)
	steam_session.set("is_solo_session", false)
	game.queue_free()


func _test_builder_stop_and_trip() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	var builders: BuilderSystem = game.get("builder_system")
	state.team_gold = 1000
	_check(is_equal_approx(builders.trip_chance, BalanceConfig.BUILDER_TRIP_CHANCE) and builders.trip_chance < 0.1, "builders trip only now and then")
	# Stop clears queued orders; a peer without a builder cannot issue one.
	game.call("_try_order_build", 1, "bolt", P9_OPEN, true)
	game.call("_try_order_build", 1, "sentry", P9_OPEN + Vector2i(4, 0), true)
	_check(game.call("_try_order_stop", 1) and builders.get_orders(1).is_empty(), "Stop clears the builder's queued orders")
	_check(not game.call("_try_order_stop", 7), "peers without a builder cannot issue Stop")
	_check(((game.get("_builder_records") as Array)[0]["sites"] as Array).is_empty(), "Stop clears the replicated build site markers")
	_run_builders(game, 3.0)
	_check(state.towers.is_empty() and state.team_gold == 1000, "stopped build orders never start construction or charge")
	# Trip: forced on, a move that ends beside a building knocks the builder over.
	game.call("_try_place_tower", "bolt", P9_OPEN)
	var tower := map.get_tower(state.tower_records()[0]["id"])
	builders.trip_chance = 1.0
	var beside := tower.plane_position + Vector2(WintermaulMap.TILE_SIZE * 1.5, 0.0)
	game.call("_try_order_move", 1, beside, false)
	var guard := 0
	while not builders.get_orders(1).is_empty() and guard < 200:
		game.call("_tick_builders", 0.05)
		guard += 1
	_check(builders.state_of(1) == BuilderSystem.State.STUNNED and map.get_builder(1).state == BuilderSystem.State.STUNNED, "a builder stopping beside a building can trip over it")
	var elsewhere := map.grid_to_world(P9_OPEN + Vector2i(-6, -10))
	var before := builders.get_position(1)
	game.call("_try_order_move", 1, elsewhere, false)
	_check(builders.state_of(1) == BuilderSystem.State.MOVING, "a new order gets a tripped builder straight back up")
	game.call("_tick_builders", 0.1)
	_check(builders.get_position(1).distance_to(before) > 1.0, "tripping never delays the next order")
	_run_builders(game, 4.0)
	_check(builders.state_of(1) == BuilderSystem.State.IDLE, "moves that end away from buildings never trip")
	builders.trip_chance = 0.0
	game.call("_try_order_move", 1, beside, false)
	_run_builders(game, 4.0)
	_check(builders.state_of(1) == BuilderSystem.State.IDLE, "with no trip chance the builder never trips")
	steam_session.set("is_solo_session", false)
	game.queue_free()


func _test_builder_reconciliation() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var speed := 100.0
	var start := Vector2(400, 400)
	var record := {"owner": 2, "x": start.x, "y": start.y, "tx": 600.0, "ty": 400.0, "state": BuilderSystem.State.MOVING, "sites": []}
	map.reconcile_builders([record], speed, false)
	var builder := map.get_builder(2)
	_check(builder != null and builder.plane_position.is_equal_approx(start), "clients spawn missing builders at the replicated position")
	builder._process(0.5)
	_check(builder.plane_position.is_equal_approx(start + Vector2(50, 0)), "clients walk moving builders toward the replicated target")
	var near := record.duplicate()
	near["x"] = start.x + 40.0
	map.reconcile_builders([near], speed, false)
	_check(builder.plane_position.is_equal_approx(start + Vector2(50, 0)), "small drift keeps the client's smooth position")
	var far := record.duplicate()
	far["x"] = start.x + 200.0
	map.reconcile_builders([far], speed, false)
	_check(builder.plane_position.is_equal_approx(start + Vector2(200, 0)), "large drift snaps the client builder to the host position")
	var idle := far.duplicate()
	idle["state"] = BuilderSystem.State.IDLE
	map.reconcile_builders([idle], speed, false)
	builder._process(0.5)
	_check(builder.plane_position.is_equal_approx(start + Vector2(200, 0)), "idle builders stay put on clients")
	builder._process(0.5)
	var stopped := idle.duplicate()
	stopped["x"] = start.x + 190.0
	stopped["tx"] = stopped["x"]
	map.reconcile_builders([stopped], speed, false)
	builder._process(0.5)
	_check(builder.plane_position.is_equal_approx(start + Vector2(190, 0)), "a stopped client builder settles onto the host position instead of keeping small drift")
	map.reconcile_builders([], speed, false)
	_check(map.get_builder(2) == null, "builders missing from the host record are removed")
	map.queue_free()


# --- Roguelike layer ----------------------------------------------------------

func _test_run_modifiers() -> void:
	var modifiers := RunModifiers.new(Catalog)
	_check(modifiers.apply(Catalog.get_upgrade("bolt_damage")), "run modifiers accept a new upgrade")
	_check(not modifiers.apply(Catalog.get_upgrade("bolt_damage")), "run modifiers reject duplicate upgrades")
	var bolt_stats := modifiers.modify_stats(Bolt.stats(), "bolt")
	var cannon_stats := modifiers.modify_stats(Cannon.stats(), "cannon")
	_check(bolt_stats["damage"] == roundi(Bolt.damage * 1.3) and cannon_stats["damage"] == Cannon.damage, "tower-specific upgrades only affect their tower")
	_check(Bolt.damage == 5, "applying modifiers never mutates the tower resource")
	modifiers.apply(Catalog.get_upgrade("glass_cannons"))
	_check(modifiers.build_cost(Bolt.cost) == roundi(Bolt.cost * 1.3), "tradeoff upgrades raise build costs")
	modifiers.apply(Catalog.get_upgrade("bounty_bonus"))
	_check(modifiers.bounty(10) == 12, "economy upgrades scale bounties")
	modifiers.apply(Catalog.get_upgrade("cheap_upgrades"))
	_check(modifiers.upgrade_cost(40) == 30 and modifiers.upgrade_cost(-1) == -1, "upgrade discounts apply and max tier stays unavailable")
	modifiers.apply(Catalog.get_upgrade("better_refunds"))
	_check(modifiers.sell_refund_bonus() == 20, "refund bonuses accumulate")
	modifiers.apply(Catalog.get_upgrade("p9_bastion"))
	var p9_stats := modifiers.modify_stats(Cannon.stats(), "cannon", true)
	var p1_stats := modifiers.modify_stats(Cannon.stats(), "cannon", false)
	_check(p9_stats["damage"] > p1_stats["damage"], "final position bonuses only apply inside position nine")
	var rebuilt := RunModifiers.new(Catalog)
	rebuilt.rebuild(modifiers.applied_ids)
	_check(rebuilt.applied_ids == modifiers.applied_ids and rebuilt.build_cost(Bolt.cost) == modifiers.build_cost(Bolt.cost), "modifiers rebuild identically from the applied id list")
	_check(modifiers.summary_lines().size() == 6, "modifier summary lists every applied upgrade")


func _test_upgrade_offer_rules_and_determinism() -> void:
	var modifiers := RunModifiers.new(Catalog)
	var first := UpgradeOffer.roll(Catalog.upgrades, modifiers, 1234, 1)
	var again := UpgradeOffer.roll(Catalog.upgrades, modifiers, 1234, 1)
	_check(first.size() == BalanceConfig.OFFER_CHOICE_COUNT and first == again, "the same seed and wave produce the same offer")
	var unique: Dictionary = {}
	for upgrade_id in first:
		unique[upgrade_id] = true
	_check(unique.size() == first.size(), "an offer never repeats an upgrade")
	var later_wave := UpgradeOffer.roll(Catalog.upgrades, modifiers, 1234, 3)
	var other_seed := UpgradeOffer.roll(Catalog.upgrades, modifiers, 99, 1)
	_check(later_wave != first or other_seed != first, "different waves or seeds vary the offer")
	_check(not UpgradeOffer.is_eligible(Catalog.get_upgrade("cannon_shock"), modifiers), "upgrades with unmet requirements are not offered")
	modifiers.apply(Catalog.get_upgrade("cannon_damage"))
	_check(UpgradeOffer.is_eligible(Catalog.get_upgrade("cannon_shock"), modifiers), "requirements unlock once a tagged upgrade is owned")
	_check(not UpgradeOffer.is_eligible(Catalog.get_upgrade("cannon_damage"), modifiers), "owned upgrades are never offered again")
	modifiers.apply(Catalog.get_upgrade("overclock"))
	_check(not UpgradeOffer.is_eligible(Catalog.get_upgrade("glass_cannons"), modifiers), "mutually exclusive tradeoffs are excluded once one is owned")
	for wave_index in range(10):
		for upgrade_id in UpgradeOffer.roll(Catalog.upgrades, modifiers, 555, wave_index):
			if not UpgradeOffer.is_eligible(Catalog.get_upgrade(upgrade_id), modifiers):
				_check(false, "offer pool never includes ineligible upgrades")
				return
	_check(true, "offer pool never includes ineligible upgrades")


func _test_controller_wave_loop_with_offer() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	var starting_lives := state.shared_lives
	for wave_number in range(1, 4):
		game.call("_begin_wave")
		_check(state.phase == RunStateModel.Phase.WAVE and state.current_wave_index == wave_number - 1, "controller begins wave %d" % wave_number)
		var guard := 0
		while state.is_wave_clear() == false and guard < 400:
			game.call("_process_spawns", 0.5)
			for runner in map.get_active_creeps():
				runner.take_damage(100000, 100)
			guard += 1
			if state.phase != RunStateModel.Phase.WAVE:
				break
		_check(state.active_creeps.is_empty() and state.shared_lives == starting_lives, "wave %d clears through kills without leaks" % wave_number)
		game.call("_finish_creep_resolution")
	_check(state.phase == RunStateModel.Phase.BUILD and state.current_wave_index == 3, "three cleared waves return to build for wave four")
	_check(state.stats["kills"] > 0 and state.team_gold > BalanceConfig.STARTING_GOLD, "kills award team gold and count toward results")
	_check(state.has_pending_offer() and state.pending_offer.size() == BalanceConfig.OFFER_CHOICE_COUNT, "clearing wave three offers a team upgrade")
	var countdown_before: float = game.get("build_countdown")
	game.call("_process", 1.0)
	_check(is_equal_approx(game.get("build_countdown"), countdown_before), "the build countdown pauses while an offer is open")
	_check(not game.call("_try_choose_upgrade", state.pending_offer[0], 2), "only the host resolves the team choice")
	_check(not game.call("_try_choose_upgrade", "not_offered", 1), "choices outside the offer are rejected")
	var chosen: String = state.pending_offer[0]
	_check(game.call("_try_choose_upgrade", chosen, 1), "the host applies an offered upgrade")
	var modifiers: RunModifiers = game.get("modifiers")
	_check(state.applied_upgrades == [chosen] and modifiers.has_upgrade(chosen) and not state.has_pending_offer(), "chosen upgrade is recorded, applied, and clears the offer")
	_check(not game.call("_try_choose_upgrade", chosen, 1), "duplicate choice resolution is ignored")
	game.call("_process", 1.0)
	_check(game.get("build_countdown") < countdown_before, "the countdown resumes after the choice")
	var snapshot: Dictionary = game.call("_make_state_snapshot")
	_check(snapshot["upgrades"] == [chosen] and snapshot["seed"] == state.run_seed and snapshot["towers"] is Array, "snapshots carry seed, upgrades, and tower records")
	steam_session.set("is_solo_session", false)
	game.queue_free()


# --- Reconciliation -----------------------------------------------------------

func _test_tower_reconciliation() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var stats_lookup := func(record: Dictionary) -> Dictionary:
		return Catalog.get_tower(record["definition_id"]).stats()
	var records := [
		{"id": 1, "definition_id": "bolt", "cell": P1_OPEN, "position": 0, "targeting": 0, "invested": 25},
		{"id": 2, "definition_id": "frost", "cell": P2_OPEN, "position": 1, "targeting": 0, "invested": 35},
	]
	var summary := map.reconcile_towers(records, Catalog.get_tower, stats_lookup)
	_check(summary["added"] == 2 and map.get_tower_count() == 2, "reconciliation spawns missing towers from authoritative records")
	records[0]["definition_id"] = "human_crossbow"
	records[0]["targeting"] = TowerTargeting.Mode.LAST
	records.remove_at(1)
	records.append({"id": 3, "definition_id": "cannon", "cell": P4_OPEN, "position": 3, "targeting": 2, "invested": 45})
	summary = map.reconcile_towers(records, Catalog.get_tower, stats_lookup)
	_check(summary["updated"] == 1 and summary["removed"] == 1 and summary["added"] == 1, "reconciliation updates changed, removes missing, and adds new towers")
	_check(map.get_tower(1).definition.id == "human_crossbow" and map.get_tower(1).targeting == TowerTargeting.Mode.LAST, "reconciled towers adopt upgrades and targeting changes")
	_check(map.get_tower(2) == null and map.can_place_tower(P2_OPEN), "removed towers free their cells")
	summary = map.reconcile_towers(records, Catalog.get_tower, stats_lookup)
	_check(summary["added"] == 0 and summary["updated"] == 0 and summary["removed"] == 0, "reconciling identical records is a no-op")
	map.queue_free()


func _test_creep_reconciliation() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var start := map.grid_to_world(map.get_route_start(0))
	var records := [
		{"id": 10, "position": 0, "definition_id": "grunt", "health": 10, "max_health": 10, "stage": 0, "x": start.x, "y": start.y, "slow": 0.0},
		{"id": 11, "position": 1, "definition_id": "brute", "health": 40, "max_health": 40, "stage": 0, "x": start.x, "y": start.y, "slow": 0.0},
	]
	var summary := map.reconcile_creeps(records, Catalog.get_creep)
	_check(summary["added"] == 2 and map.get_active_creeps().size() == 2, "reconciliation spawns creeps the client has not seen")
	var far := map.grid_to_world(Vector2i(32, 40))
	records[0]["health"] = 4
	records[0]["x"] = far.x
	records[0]["y"] = far.y
	records[0]["slow"] = 1.0
	records.remove_at(1)
	summary = map.reconcile_creeps(records, Catalog.get_creep)
	var grunt := map.get_creep(10)
	_check(summary["updated"] == 1 and summary["removed"] == 1, "reconciliation updates existing creeps and removes vanished ones")
	_check(grunt.health == 4 and grunt.plane_position.is_equal_approx(far) and grunt.is_slowed(), "large drift snaps position and adopts authoritative health and slow")
	var nudged := far + Vector2(6, 0)
	records[0]["x"] = nudged.x
	map.reconcile_creeps(records, Catalog.get_creep)
	_check(grunt.plane_position.x > far.x and grunt.plane_position.x < nudged.x, "small drift is corrected smoothly")
	var snapshot := map.creep_snapshot()
	_check(snapshot.size() == 1 and snapshot[0]["id"] == 10 and snapshot[0]["health"] == 4, "creep snapshots expose the authoritative presentation state")
	map.queue_free()


# --- Presentation -------------------------------------------------------------

func _test_actor_models() -> void:
	var map := WintermaulMapScene.instantiate() as WintermaulMap
	root.add_child(map)
	var all_modeled := true
	for tower_definition in Catalog.towers:
		all_modeled = all_modeled and tower_definition.visual_scene != null
	for wave in Catalog.waves:
		for group in wave.spawn_groups:
			all_modeled = all_modeled and group.creep != null and group.creep.visual_scene != null
	_check(all_modeled, "every shipped tower and creep has a placeholder model")
	var every_builder_modeled := true
	for race in Catalog.races:
		every_builder_modeled = every_builder_modeled and race.builder_scene != null
	_check(every_builder_modeled, "every race has a builder model")
	var modeled := map.spawn_tower(1, P1_OPEN, Bolt)
	var model: Node3D = modeled.get("_model")
	_check(model != null and model.get_parent() == modeled and modeled.get("_body") == null, "a tower with a model uses it instead of the procedural mesh")
	var turret: Node3D = modeled.get("_model_turret")
	modeled.face_target(modeled.plane_position + Vector2(10, 0))
	_check(turret != null and is_equal_approx(turret.rotation.y, PI * 0.5), "the model turret yaws toward its target (+Z front)")
	modeled.play_fire_animation()
	var player := ActorModel.animation_player(model)
	_check(player != null and player.current_animation == "attack", "firing plays the model's attack animation")
	var unmodeled := Cannon.duplicate() as TowerDefinition
	unmodeled.visual_scene = null
	var procedural := map.spawn_tower(2, P2_OPEN, unmodeled)
	_check(procedural.get("_model") == null and procedural.get("_body") != null, "towers without a model keep the procedural mesh")
	var runner := map.spawn_creep(7, 0, Grunt)
	var creep_model: Node3D = runner.get("_model")
	_check(creep_model != null and runner.get("_body") == null, "a creep with a model uses it instead of the procedural mesh")
	_check(ActorModel.animation_player(creep_model).current_animation == "walk", "creep models loop their walk animation")
	runner.call("_face_direction", Vector2(0, -3))
	_check(is_equal_approx(absf(creep_model.rotation.y), PI), "creep models face their movement direction")
	_check(runner.get_visual_height() > ActorModel.height(creep_model), "health bars sit above the creep model")
	runner.take_damage(1)
	var meshes := creep_model.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty() and (meshes[0] as MeshInstance3D).material_overlay != null, "hit flashes tint creep models")
	runner.take_damage(runner.health)
	_check(map.get_creep(runner.creep_id) == null or runner.is_queued_for_deletion(), "a killed creep leaves combat immediately")
	_check(map.get_corpse_count() == 1 and creep_model.get_parent() is Corpse, "its model is handed to a corpse that plays out the death")
	var corpse := creep_model.get_parent() as Corpse
	for step in range(40):
		corpse._process(0.1)
	_check(corpse.is_queued_for_deletion() and creep_model.position.y < 0.0, "the corpse sinks into the ground and frees itself")
	map.queue_free()


func _test_effects_layer() -> void:
	var effects := EffectsLayer.new()
	root.add_child(effects)
	effects.impact(Vector2.ZERO, Color.WHITE)
	effects.death(Vector2.ZERO, Color.RED)
	effects.leak(Vector2.ZERO)
	effects.floating_text(Vector2.ZERO, "+5", Color.YELLOW)
	_check(effects.active_count() == 4, "effects layer tracks transient feedback")
	effects._process(0.3)
	_check(effects.active_count() == 3, "short effects expire first")
	effects._process(5.0)
	_check(effects.active_count() == 0, "all effects expire")
	effects.queue_free()


func _test_audio_and_settings() -> void:
	var audio := root.get_node("AudioDirector")
	var required := ["ui_confirm", "ui_error", "build", "upgrade", "sell", "attack", "impact", "death", "wave_start", "boss_warning", "leak", "victory", "defeat"]
	var missing: Array[String] = []
	for event_name in required:
		if not audio.call("has_event", event_name):
			missing.append(event_name)
	_check(missing.is_empty(), "essential audio events are synthesized: %s" % ", ".join(PackedStringArray(missing)))
	_check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("Effects") != -1, "music and effects buses exist")
	_check(audio.call("play", "build") and not audio.call("play", "unknown_event"), "audio director plays known events and rejects unknown ones")
	var settings := root.get_node("GameSettings")
	var original: float = settings.get("effects_volume")
	settings.call("set_volume", "effects", 2.0)
	_check(is_equal_approx(settings.get("effects_volume"), 1.0), "volume settings clamp to the unit range")
	settings.call("set_volume", "effects", original)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")), linear_to_db(original)), "effects bus volume follows the setting")


# --- Helpers ------------------------------------------------------------------

## The game scene is loaded at runtime so autoload singletons exist before the
## controller script compiles.
func _instantiate_game() -> Node:
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	return game_scene.instantiate()


func _test_controller_roguelike_toggle_suppresses_offer() -> void:
	var steam_session := root.get_node("SteamSession")
	steam_session.set("is_solo_session", true)
	steam_session.set("roguelike_enabled", false)
	var game: Node = _instantiate_game()
	root.add_child(game)
	var state: RunState = game.get("run_state")
	var map := game.get_node(MAP_PATH) as WintermaulMap
	_check(not state.roguelike_enabled, "host run picks up the disabled roguelike flag from the session")
	for wave_number in range(1, 4):
		game.call("_begin_wave")
		var guard := 0
		while state.is_wave_clear() == false and guard < 400:
			game.call("_process_spawns", 0.5)
			for runner in map.get_active_creeps():
				runner.take_damage(100000, 100)
			guard += 1
			if state.phase != RunStateModel.Phase.WAVE:
				break
		game.call("_finish_creep_resolution")
	_check(state.phase == RunStateModel.Phase.BUILD and state.current_wave_index == 3, "three cleared waves return to build for wave four with roguelike disabled")
	_check(not state.has_pending_offer(), "clearing wave three does not offer an upgrade when roguelike is disabled")
	steam_session.set("is_solo_session", false)
	steam_session.set("roguelike_enabled", true)
	game.queue_free()


func _creep(speed: float, health: int, armor := 0, slow_immune := false, regen := 0.0) -> CreepDefinition:
	var definition := CreepDefinition.new()
	definition.id = "test_creep"
	definition.display_name = "Test Creep"
	definition.speed = speed
	definition.health = health
	definition.armor = armor
	definition.slow_immune = slow_immune
	definition.regen_per_second = regen
	return definition


## Walls off lane one's exit gap except the given cell, using ids 900+.
func _seal_lane_one_except(map: WintermaulMap, remaining: Vector2i) -> void:
	var next_id := 900
	for cell in SEAL_NEIGHBOURS:
		if cell != remaining:
			map.spawn_tower(next_id, cell, Bolt)
			next_id += 1


func _section_rect(position_index: int) -> Rect2:
	var bounds: Rect2i = ClassicWintermaulLayout.get_position(position_index)["macro_bounds"]
	return Rect2(Vector2(bounds.position) * WintermaulMap.TILE_SIZE, Vector2(bounds.size) * WintermaulMap.TILE_SIZE)


func _metadata() -> Dictionary:
	return {
		"game": GAME_TAG,
		"protocol": PROTOCOL,
		"build": BUILD,
		"map": MAP,
		"state": "waiting",
	}


func _matches(metadata: Dictionary, members: int, limit: int) -> bool:
	return LobbyPolicy.is_compatible(metadata, members, limit, GAME_TAG, PROTOCOL, BUILD, MAP)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("FAILED: %s" % description)
