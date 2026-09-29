extends Control

## Host-authoritative run orchestrator. The host owns RunState; every peer
## mirrors presentation through RPC events plus periodic snapshots that are
## reconciled by stable IDs.

const RunStateModel = preload("res://scripts/game/run_state.gd")
const CATALOG: ContentCatalog = preload("res://resources/content_catalog.tres")
const POSITION_COUNT := ClassicWintermaulLayout.PLAYER_COUNT
const FINAL_POSITION_INDEX := POSITION_COUNT - 1
const STATE_SNAPSHOT_INTERVAL := 0.5
const CREEP_SNAPSHOT_INTERVAL := 0.15
const HOST_PEER_ID := BuildPermissionPolicy.HOST_PEER_ID

var run_state: RunState
var modifiers: RunModifiers
var build_countdown := BalanceConfig.WAVE_ONE_READY_TIMEOUT

var _spawn_queues: Array[Array] = []
var _spawn_timers := PackedFloat32Array()
var _creep_bounties: Dictionary = {}
var _creep_is_boss: Dictionary = {}
var _latest_snapshot: Dictionary = {}
var _selected_definition_id := ""
var _selected_tower_id := 0
var _awaiting_peers: Array[int] = []
var _load_ack_timer := 0.0
## Peer ids (including the host) that have not yet readied up for wave 1.
var _wave_one_pending_ready: Array[int] = []
var _wave_one_total := 0
var _wave_one_ready_pressed := false
var _state_snapshot_timer := 0.0
var _creep_snapshot_timer := 0.0
var _state_dirty := true
var _authority_lost := false
var _run_ended_announced := false

@onready var wintermaul_map: WintermaulMap = %WintermaulMap
@onready var battlefield_camera: BattlefieldCamera = %BattlefieldCamera
@onready var battlefield_view: Control = %BattlefieldView
@onready var hud: GameHud = %Hud


func _ready() -> void:
	run_state = RunStateModel.new(CATALOG.waves.size(), BalanceConfig.STARTING_LIVES, BalanceConfig.STARTING_GOLD, POSITION_COUNT)
	modifiers = RunModifiers.new(CATALOG)
	_spawn_timers.resize(POSITION_COUNT)
	_spawn_queues.resize(POSITION_COUNT)
	for position_index in range(POSITION_COUNT):
		_spawn_queues[position_index] = []

	battlefield_camera.set_edge_pan_area(battlefield_view)
	battlefield_camera.edge_pan_enabled = GameSettings.edge_pan_enabled
	GameSettings.changed.connect(func() -> void: battlefield_camera.edge_pan_enabled = GameSettings.edge_pan_enabled)

	wintermaul_map.creep_route_finished.connect(_on_creep_route_finished)
	wintermaul_map.creep_killed.connect(_on_creep_killed)
	wintermaul_map.build_cell_requested.connect(_on_build_cell_requested)
	wintermaul_map.placement_rejected.connect(_on_placement_rejected)
	wintermaul_map.tower_clicked.connect(_select_tower)
	wintermaul_map.selection_cleared.connect(_clear_selection)
	wintermaul_map.tower_fired.connect(_on_tower_fired)
	wintermaul_map.impact_resolved.connect(func(_tower_id: int, _hits: int, _killed: int) -> void: AudioDirector.play("impact"))

	hud.setup(CATALOG)
	hud.tower_palette_selected.connect(_on_palette_selected)
	hud.launch_requested.connect(_on_launch_pressed)
	hud.upgrade_requested.connect(_on_upgrade_requested)
	hud.sell_requested.connect(_on_sell_requested)
	hud.targeting_requested.connect(_on_targeting_requested)
	hud.offer_chosen.connect(_on_offer_chosen)
	hud.return_requested.connect(_return_to_lobby)
	hud.selection_cleared.connect(_clear_selection)
	hud.ready_requested.connect(_on_ready_pressed)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	SteamSession.game_end_requested.connect(_on_game_end_requested)

	if multiplayer.is_server():
		_initialize_host_run()
	else:
		_request_state.rpc_id(HOST_PEER_ID)
		_acknowledge_loaded.rpc_id(HOST_PEER_ID)
	_refresh_local_context()
	if not GameSettings.controls_seen:
		hud.show_controls_overlay()
	AudioDirector.start_music()


# --- Host run lifecycle -------------------------------------------------------

func _initialize_host_run() -> void:
	run_state.run_seed = randi()
	run_state.roguelike_enabled = SteamSession.roguelike_enabled
	run_state.position_owners = _resolve_position_owners()
	if multiplayer.has_multiplayer_peer():
		_awaiting_peers.assign(multiplayer.get_peers())
	_load_ack_timer = BalanceConfig.LOAD_ACK_TIMEOUT
	if run_state.current_wave_index == 0:
		_wave_one_pending_ready.clear()
		if multiplayer.has_multiplayer_peer():
			_wave_one_pending_ready.assign(multiplayer.get_peers())
		_wave_one_pending_ready.append(HOST_PEER_ID)
		_wave_one_total = _wave_one_pending_ready.size()
	_start_build_phase()
	_broadcast_state()


func _resolve_position_owners() -> PackedInt32Array:
	var owners := PackedInt32Array()
	owners.resize(POSITION_COUNT)
	if SteamSession.is_solo_session or SteamSession.roster.is_empty():
		owners.fill(HOST_PEER_ID)
		return owners
	return BuildPermissionPolicy.resolve_owners(
		SteamSession.roster,
		POSITION_COUNT,
		SteamSession.get_peer_id_for_steam_id,
		Steamworks.steam_id,
		HOST_PEER_ID
	)


func _process(delta: float) -> void:
	if not multiplayer.is_server() or _authority_lost:
		return
	if run_state.phase in [RunStateModel.Phase.BUILD, RunStateModel.Phase.WAVE]:
		run_state.elapsed_seconds += delta

	match run_state.phase:
		RunStateModel.Phase.BUILD:
			if not _awaiting_peers.is_empty():
				_load_ack_timer -= delta
				if _load_ack_timer <= 0.0:
					_awaiting_peers.clear()
					_mark_dirty()
			elif not run_state.has_pending_offer():
				if run_state.current_wave_index == 0 and _wave_one_pending_ready.is_empty():
					_begin_wave()
				else:
					build_countdown = maxf(0.0, build_countdown - delta)
					if build_countdown <= 0.0:
						_begin_wave()
		RunStateModel.Phase.WAVE:
			_process_spawns(delta)

	_state_snapshot_timer -= delta
	if _state_dirty or _state_snapshot_timer <= 0.0:
		_state_snapshot_timer = STATE_SNAPSHOT_INTERVAL
		_state_dirty = false
		_broadcast_state()

	_creep_snapshot_timer -= delta
	if _creep_snapshot_timer <= 0.0:
		_creep_snapshot_timer = CREEP_SNAPSHOT_INTERVAL
		if run_state.phase == RunStateModel.Phase.WAVE and multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
			_apply_creep_snapshot.rpc(wintermaul_map.creep_snapshot())


func is_waiting_for_players() -> bool:
	return not _awaiting_peers.is_empty()


func _start_build_phase() -> void:
	build_countdown = BalanceConfig.build_duration_for_wave(run_state.current_wave_index)
	_spawn_timers.fill(0.0)
	_mark_dirty()


func _begin_wave() -> void:
	var wave: WaveDefinition = CATALOG.waves[run_state.current_wave_index]
	var scale := BalanceConfig.player_scale(SteamSession.player_count())
	var counts := PackedInt32Array()
	counts.resize(POSITION_COUNT)
	for position_index in range(POSITION_COUNT):
		var queue := wave.build_spawn_queue(position_index, scale)
		_spawn_queues[position_index] = queue
		counts[position_index] = queue.size()
		_spawn_timers[position_index] = float(queue[0]["delay"]) if not queue.is_empty() else 0.0
	run_state.begin_wave(counts)
	_play_event.rpc("wave_start")
	if wave.has_boss():
		_play_event.rpc("boss_warning")
		_show_notice.rpc("BOSS INCOMING  ·  %s" % wave.title, true)
	_mark_dirty()


func _process_spawns(delta: float) -> void:
	for position_index in range(POSITION_COUNT):
		var queue: Array = _spawn_queues[position_index]
		if queue.is_empty():
			continue
		_spawn_timers[position_index] -= delta
		while _spawn_timers[position_index] <= 0.0 and not queue.is_empty():
			var entry: Dictionary = queue.pop_front()
			_spawn_entry(position_index, entry)
			if not queue.is_empty():
				_spawn_timers[position_index] += float(queue[0]["delay"])


func _spawn_entry(position_index: int, entry: Dictionary) -> void:
	var definition := CATALOG.get_creep(str(entry["creep_id"]))
	if definition == null:
		return
	var creep_id := run_state.allocate_creep_id()
	var health_multiplier := float(entry.get("health_multiplier", 1.0))
	var health := maxi(1, roundi(definition.health * health_multiplier))
	if not run_state.register_spawn(position_index, creep_id, definition.id, health_multiplier):
		return
	_creep_bounties[creep_id] = modifiers.bounty(definition.bounty)
	_creep_is_boss[creep_id] = definition.is_boss
	_spawn_creep_visual.rpc(creep_id, position_index, definition.id, health, modifiers.creep_speed_multiplier())


@rpc("authority", "call_local", "reliable")
func _spawn_creep_visual(creep_id: int, position_index: int, definition_id: String, health: int, speed_multiplier: float) -> void:
	var definition := CATALOG.get_creep(definition_id)
	if definition == null:
		return
	wintermaul_map.spawn_creep(creep_id, position_index, definition, health, speed_multiplier)


func _on_creep_route_finished(creep_id: int) -> void:
	if multiplayer.is_server():
		if run_state.phase != RunStateModel.Phase.WAVE or not run_state.resolve_creep(creep_id, true):
			return
		_creep_bounties.erase(creep_id)
		_creep_is_boss.erase(creep_id)
		_remove_creep_visual.rpc(creep_id, false)
		_play_event.rpc("leak")
		_finish_creep_resolution()
	else:
		AudioDirector.play("leak")


func _on_creep_killed(creep_id: int) -> void:
	if multiplayer.is_server():
		if run_state.phase != RunStateModel.Phase.WAVE or not run_state.resolve_creep(creep_id, false):
			return
		var bounty := int(_creep_bounties.get(creep_id, 0))
		run_state.award_gold(bounty)
		if bool(_creep_is_boss.get(creep_id, false)):
			run_state.stats["boss_kills"] += 1
		_creep_bounties.erase(creep_id)
		_creep_is_boss.erase(creep_id)
		_remove_creep_visual.rpc(creep_id, true)
		_show_bounty.rpc(creep_id, bounty)
		_finish_creep_resolution()
	AudioDirector.play("death")


@rpc("authority", "call_remote", "reliable")
func _remove_creep_visual(creep_id: int, killed: bool) -> void:
	wintermaul_map.remove_creep(creep_id, killed)
	AudioDirector.play("death" if killed else "leak")


@rpc("authority", "call_local", "reliable")
func _show_bounty(creep_id: int, amount: int) -> void:
	wintermaul_map.show_bounty(creep_id, amount)


func _finish_creep_resolution() -> void:
	if run_state.phase == RunStateModel.Phase.DEFEAT:
		_clear_creeps_visual.rpc()
		_announce_run_end()
	elif run_state.is_wave_clear():
		var cleared_wave: WaveDefinition = CATALOG.waves[run_state.current_wave_index]
		run_state.advance_after_clear()
		if run_state.phase == RunStateModel.Phase.BUILD:
			if cleared_wave.offers_upgrade_after and run_state.roguelike_enabled:
				run_state.pending_offer = UpgradeOffer.roll(CATALOG.upgrades, modifiers, run_state.run_seed, run_state.current_wave_index)
			_start_build_phase()
		elif run_state.phase == RunStateModel.Phase.VICTORY:
			_announce_run_end()
	_mark_dirty()


func _announce_run_end() -> void:
	if _run_ended_announced:
		return
	_run_ended_announced = true
	_play_event.rpc("victory" if run_state.phase == RunStateModel.Phase.VICTORY else "defeat")


@rpc("authority", "call_local", "reliable")
func _clear_creeps_visual() -> void:
	wintermaul_map.clear_creeps()


# --- Snapshots ----------------------------------------------------------------

func _mark_dirty() -> void:
	_state_dirty = true


func _broadcast_state() -> void:
	_apply_state_snapshot.rpc(_make_state_snapshot())


@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if not multiplayer.is_server():
		return
	_apply_state_snapshot.rpc_id(multiplayer.get_remote_sender_id(), _make_state_snapshot())


@rpc("any_peer", "call_remote", "reliable")
func _acknowledge_loaded() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if _awaiting_peers.has(sender):
		_awaiting_peers.erase(sender)
		_mark_dirty()


@rpc("any_peer", "call_remote", "reliable")
func _signal_ready_for_wave_one() -> void:
	if not multiplayer.is_server():
		return
	_mark_wave_one_ready(multiplayer.get_remote_sender_id())


func _mark_wave_one_ready(peer_id: int) -> void:
	if _wave_one_pending_ready.has(peer_id):
		_wave_one_pending_ready.erase(peer_id)
		_mark_dirty()


func _make_state_snapshot() -> Dictionary:
	var snapshot := run_state.snapshot(build_countdown)
	snapshot["tower_count"] = run_state.towers.size()
	snapshot["waiting_for"] = _awaiting_peers.size()
	snapshot["player_count"] = SteamSession.player_count()
	snapshot["wave_one_ready"] = _wave_one_total - _wave_one_pending_ready.size()
	snapshot["wave_one_total"] = _wave_one_total
	if run_state.phase in [RunStateModel.Phase.VICTORY, RunStateModel.Phase.DEFEAT]:
		snapshot["results"] = run_state.results()
	return snapshot


@rpc("authority", "call_local", "reliable")
func _apply_state_snapshot(snapshot: Dictionary) -> void:
	_latest_snapshot = snapshot
	if not multiplayer.is_server():
		modifiers.rebuild(snapshot.get("upgrades", []))
		run_state.position_owners = PackedInt32Array(snapshot.get("owners", run_state.position_owners))
		run_state.phase = int(snapshot.get("phase", run_state.phase))
		run_state.team_gold = int(snapshot.get("gold", run_state.team_gold))
		wintermaul_map.reconcile_towers(snapshot.get("towers", []), CATALOG.get_tower, _stats_for_record)
	_refresh_local_context()


@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_creep_snapshot(records: Array) -> void:
	if multiplayer.is_server():
		return
	wintermaul_map.reconcile_creeps(records, CATALOG.get_creep, modifiers.creep_speed_multiplier())


func _refresh_local_context() -> void:
	if _latest_snapshot.is_empty():
		return
	var local_peer := multiplayer.get_unique_id()
	var owners: PackedInt32Array = _latest_snapshot.get("owners", PackedInt32Array())
	var controllable := BuildPermissionPolicy.controlled_positions(local_peer, owners, HOST_PEER_ID)
	var phase: int = _latest_snapshot["phase"]
	var gold: int = _latest_snapshot["gold"]
	var definition := CATALOG.get_tower(_selected_definition_id) if not _selected_definition_id.is_empty() else null
	var cost := modifiers.build_cost(definition.cost) if definition else 0
	var build_enabled := phase in [RunStateModel.Phase.BUILD, RunStateModel.Phase.WAVE]
	wintermaul_map.set_build_context(build_enabled, definition, cost, gold, controllable)
	wintermaul_map.set_ownership_view(owners, local_peer, SteamSession.get_peer_names())

	var context := {
		"local_peer": local_peer,
		"is_host": multiplayer.is_server(),
		"controllable": controllable,
		"owner_names": SteamSession.get_peer_names(),
		"modifiers": modifiers,
		"wave": CATALOG.waves[clampi(int(_latest_snapshot["wave_index"]), 0, CATALOG.waves.size() - 1)],
		"selected_definition": _selected_definition_id,
		"build_cost": cost,
		"wave_one_ready_pressed": _wave_one_ready_pressed,
	}
	hud.update_state(_latest_snapshot, context)
	_refresh_tower_panel()

	var offer_ids: Array = _latest_snapshot.get("offer", [])
	if offer_ids.is_empty():
		hud.hide_offer()
	else:
		var offered: Array[RunUpgradeDefinition] = []
		for upgrade_id in offer_ids:
			var upgrade := CATALOG.get_upgrade(str(upgrade_id))
			if upgrade:
				offered.append(upgrade)
		hud.show_offer(offered, multiplayer.is_server())

	if _latest_snapshot.has("results"):
		hud.show_end_screen(_latest_snapshot["results"], CATALOG)


func _stats_for_record(record: Dictionary) -> Dictionary:
	var definition := CATALOG.get_tower(str(record["definition_id"]))
	if definition == null:
		return {}
	return modifiers.modify_stats(definition.stats_for_tier(int(record["tier"])), definition.id, int(record.get("position", -1)) == FINAL_POSITION_INDEX)


# --- Tower transactions (host validation) -----------------------------------

func _on_build_cell_requested(cell: Vector2i) -> void:
	if _selected_definition_id.is_empty():
		hud.show_placement_message(WintermaulMap.placement_text(WintermaulMap.Placement.NO_TOWER_SELECTED), true)
		return
	if multiplayer.is_server():
		_placement_feedback(_try_place_tower(_selected_definition_id, cell, HOST_PEER_ID))
	else:
		_request_place_tower.rpc_id(HOST_PEER_ID, _selected_definition_id, cell)


@rpc("any_peer", "call_remote", "reliable")
func _request_place_tower(definition_id: String, cell: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_placement_feedback.rpc_id(sender, _try_place_tower(definition_id, cell, sender))


## Validates and applies a build. Returns a WintermaulMap.Placement code.
func _try_place_tower(definition_id: String, cell: Vector2i, peer_id := HOST_PEER_ID) -> int:
	if not run_state.can_build():
		return WintermaulMap.Placement.LOCKED
	var definition := CATALOG.get_tower(definition_id)
	if definition == null:
		return WintermaulMap.Placement.NO_TOWER_SELECTED
	var geometry := wintermaul_map.evaluate_placement(cell)
	if geometry != WintermaulMap.Placement.OK:
		return geometry
	var position_index := wintermaul_map.get_cell_position_index(cell)
	if not BuildPermissionPolicy.can_control(peer_id, position_index, run_state.position_owners, HOST_PEER_ID):
		return WintermaulMap.Placement.NOT_OWNED
	var cost := modifiers.build_cost(definition.cost)
	if not run_state.spend_gold(cost):
		return WintermaulMap.Placement.UNAFFORDABLE
	var record := run_state.add_tower(definition.id, cell, position_index, definition.default_targeting)
	_spawn_tower_visual.rpc(record, _stats_for_record(record))
	_play_event.rpc("build")
	_mark_dirty()
	return WintermaulMap.Placement.OK


@rpc("authority", "call_local", "reliable")
func _placement_feedback(result: int) -> void:
	if result == WintermaulMap.Placement.OK:
		hud.show_placement_message("Tower placed", false)
	else:
		hud.show_placement_message(WintermaulMap.placement_text(result), true)
		AudioDirector.play("ui_error")


func _on_placement_rejected(_cell: Vector2i, reason: int) -> void:
	hud.show_placement_message(WintermaulMap.placement_text(reason), true)
	AudioDirector.play("ui_error")


@rpc("authority", "call_local", "reliable")
func _spawn_tower_visual(record: Dictionary, stats: Dictionary) -> void:
	var definition := CATALOG.get_tower(str(record["definition_id"]))
	if definition == null:
		return
	wintermaul_map.spawn_tower(int(record["id"]), record["cell"], definition, int(record["tier"]), int(record["targeting"]), stats, int(record.get("position", -1)))


@rpc("authority", "call_local", "reliable")
func _update_tower_visual(record: Dictionary, stats: Dictionary) -> void:
	wintermaul_map.update_tower(int(record["id"]), int(record["tier"]), int(record["targeting"]), stats)
	if int(record["id"]) == _selected_tower_id:
		_refresh_tower_panel()


@rpc("authority", "call_local", "reliable")
func _remove_tower_visual(tower_id: int) -> void:
	wintermaul_map.remove_tower(tower_id)
	if tower_id == _selected_tower_id:
		_clear_selection()


func _on_upgrade_requested(tower_id: int) -> void:
	if multiplayer.is_server():
		_transaction_feedback(_try_upgrade_tower(tower_id, HOST_PEER_ID), "Tower upgraded", "Upgrade rejected")
	else:
		_request_upgrade_tower.rpc_id(HOST_PEER_ID, tower_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_upgrade_tower(tower_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_transaction_feedback.rpc_id(sender, _try_upgrade_tower(tower_id, sender), "Tower upgraded", "Upgrade rejected")


func _try_upgrade_tower(tower_id: int, peer_id := HOST_PEER_ID) -> bool:
	if not run_state.can_build():
		return false
	var record := run_state.get_tower(tower_id)
	if record.is_empty():
		return false
	if not BuildPermissionPolicy.can_control(peer_id, int(record["position"]), run_state.position_owners, HOST_PEER_ID):
		return false
	var definition := CATALOG.get_tower(str(record["definition_id"]))
	var base_cost := definition.upgrade_cost(int(record["tier"])) if definition else -1
	if base_cost < 0:
		return false
	if not run_state.spend_gold(modifiers.upgrade_cost(base_cost)):
		return false
	run_state.upgrade_tower(tower_id)
	_update_tower_visual.rpc(run_state.get_tower(tower_id), _stats_for_record(run_state.get_tower(tower_id)))
	_play_event.rpc("upgrade")
	_mark_dirty()
	return true


func _on_sell_requested(tower_id: int) -> void:
	if multiplayer.is_server():
		_transaction_feedback(_try_sell_tower(tower_id, HOST_PEER_ID), "Tower sold", "Sell rejected")
	else:
		_request_sell_tower.rpc_id(HOST_PEER_ID, tower_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_sell_tower(tower_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_transaction_feedback.rpc_id(sender, _try_sell_tower(tower_id, sender), "Tower sold", "Sell rejected")


func _try_sell_tower(tower_id: int, peer_id := HOST_PEER_ID) -> bool:
	if not run_state.can_build():
		return false
	var record := run_state.get_tower(tower_id)
	if record.is_empty():
		return false
	if not BuildPermissionPolicy.can_control(peer_id, int(record["position"]), run_state.position_owners, HOST_PEER_ID):
		return false
	var definition := CATALOG.get_tower(str(record["definition_id"]))
	if definition == null:
		return false
	var refund := definition.sell_value(int(record["tier"]), modifiers.sell_refund_bonus())
	run_state.remove_tower(tower_id)
	run_state.refund_gold(refund)
	_remove_tower_visual.rpc(tower_id)
	_play_event.rpc("sell")
	_mark_dirty()
	return true


func _on_targeting_requested(tower_id: int, mode: int) -> void:
	if multiplayer.is_server():
		_try_set_targeting(tower_id, mode, HOST_PEER_ID)
	else:
		_request_set_targeting.rpc_id(HOST_PEER_ID, tower_id, mode)


@rpc("any_peer", "call_remote", "reliable")
func _request_set_targeting(tower_id: int, mode: int) -> void:
	if not multiplayer.is_server():
		return
	_try_set_targeting(tower_id, mode, multiplayer.get_remote_sender_id())


func _try_set_targeting(tower_id: int, mode: int, peer_id := HOST_PEER_ID) -> bool:
	var record := run_state.get_tower(tower_id)
	if record.is_empty() or not TowerTargeting.is_valid_mode(mode):
		return false
	if not BuildPermissionPolicy.can_control(peer_id, int(record["position"]), run_state.position_owners, HOST_PEER_ID):
		return false
	if not run_state.set_tower_targeting(tower_id, mode):
		return false
	_update_tower_visual.rpc(run_state.get_tower(tower_id), _stats_for_record(run_state.get_tower(tower_id)))
	_mark_dirty()
	return true


@rpc("authority", "call_local", "reliable")
func _transaction_feedback(success: bool, success_text: String, failure_text: String) -> void:
	hud.show_placement_message(success_text if success else failure_text, not success)
	if not success:
		AudioDirector.play("ui_error")


# --- Run upgrades -------------------------------------------------------------

func _on_offer_chosen(upgrade_id: String) -> void:
	if multiplayer.is_server():
		_try_choose_upgrade(upgrade_id, HOST_PEER_ID)
	else:
		_request_choose_upgrade.rpc_id(HOST_PEER_ID, upgrade_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_choose_upgrade(upgrade_id: String) -> void:
	if not multiplayer.is_server():
		return
	_try_choose_upgrade(upgrade_id, multiplayer.get_remote_sender_id())


## The first implementation uses one team choice made by the host.
func _try_choose_upgrade(upgrade_id: String, peer_id := HOST_PEER_ID) -> bool:
	if peer_id != HOST_PEER_ID or not run_state.pending_offer.has(upgrade_id):
		return false
	var upgrade := CATALOG.get_upgrade(upgrade_id)
	if upgrade == null or not run_state.apply_upgrade(upgrade_id):
		return false
	modifiers.apply(upgrade)
	if upgrade.immediate_gold > 0:
		run_state.award_gold(upgrade.immediate_gold)
	if upgrade.extra_lives != 0:
		run_state.add_lives(upgrade.extra_lives)
	_refresh_tower_stats()
	_play_event.rpc("upgrade_chosen")
	_show_notice.rpc("Team upgrade: %s" % upgrade.display_name, false)
	_mark_dirty()
	return true


func _refresh_tower_stats() -> void:
	for record in run_state.tower_records():
		_update_tower_visual.rpc(record, _stats_for_record(record))


# --- Selection and HUD --------------------------------------------------------

func _on_palette_selected(definition_id: String) -> void:
	_selected_definition_id = definition_id
	if not definition_id.is_empty():
		_select_tower(0)
		AudioDirector.play("ui_confirm")
	_refresh_local_context()


func _select_tower(tower_id: int) -> void:
	_selected_tower_id = tower_id
	wintermaul_map.set_selected_tower(tower_id)
	if tower_id != 0:
		_selected_definition_id = ""
		AudioDirector.play("ui_confirm")
	_refresh_local_context()


func _clear_selection() -> void:
	_selected_tower_id = 0
	_selected_definition_id = ""
	wintermaul_map.set_selected_tower(0)
	_refresh_local_context()


func _refresh_tower_panel() -> void:
	if _selected_tower_id == 0:
		hud.hide_tower()
		return
	var record := _find_tower_record(_selected_tower_id)
	if record.is_empty():
		_selected_tower_id = 0
		wintermaul_map.set_selected_tower(0)
		hud.hide_tower()
		return
	var definition := CATALOG.get_tower(str(record["definition_id"]))
	var owners: PackedInt32Array = _latest_snapshot.get("owners", PackedInt32Array())
	var can_control := BuildPermissionPolicy.can_control(multiplayer.get_unique_id(), int(record["position"]), owners, HOST_PEER_ID)
	var upgrade_cost := modifiers.upgrade_cost(definition.upgrade_cost(int(record["tier"])))
	hud.show_tower(record, definition, _stats_for_record(record), upgrade_cost, definition.sell_value(int(record["tier"]), modifiers.sell_refund_bonus()), can_control, int(_latest_snapshot.get("gold", 0)))


func _find_tower_record(tower_id: int) -> Dictionary:
	for record in _latest_snapshot.get("towers", []):
		if int(record["id"]) == tower_id:
			return record
	return {}


func _on_launch_pressed() -> void:
	if multiplayer.is_server() and run_state.phase == RunStateModel.Phase.BUILD and not run_state.has_pending_offer() and _awaiting_peers.is_empty():
		build_countdown = 0.0


func _on_ready_pressed() -> void:
	if _wave_one_ready_pressed or run_state.current_wave_index != 0 or run_state.phase != RunStateModel.Phase.BUILD:
		return
	_wave_one_ready_pressed = true
	if multiplayer.is_server():
		_mark_wave_one_ready(HOST_PEER_ID)
	else:
		_signal_ready_for_wave_one.rpc_id(HOST_PEER_ID)
	_refresh_local_context()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if hud.close_top_overlay():
			return
		_clear_selection()


# --- Events and notices ------------------------------------------------------

func _on_tower_fired(tower_id: int, creep_id: int) -> void:
	AudioDirector.play("attack")
	if multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		_projectile_fired.rpc(tower_id, creep_id)


@rpc("authority", "call_remote", "unreliable")
func _projectile_fired(tower_id: int, creep_id: int) -> void:
	wintermaul_map.show_projectile(tower_id, creep_id)
	AudioDirector.play("attack")


@rpc("authority", "call_local", "reliable")
func _play_event(event_name: String) -> void:
	AudioDirector.play(event_name)


@rpc("authority", "call_local", "reliable")
func _show_notice(text: String, is_warning: bool) -> void:
	hud.show_toast(text, is_warning)


# --- Connection lifecycle -----------------------------------------------------

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_awaiting_peers.erase(peer_id)
	_wave_one_pending_ready.erase(peer_id)
	var before := run_state.position_owners.duplicate()
	run_state.position_owners = BuildPermissionPolicy.transfer_to_host(run_state.position_owners, peer_id, HOST_PEER_ID)
	var transferred := PackedStringArray()
	for position_index in range(before.size()):
		if before[position_index] != run_state.position_owners[position_index]:
			transferred.append(str(position_index + 1))
	if not transferred.is_empty():
		_show_notice.rpc("A player disconnected. Host now controls position(s) %s." % ", ".join(transferred), true)
	_mark_dirty()


func _on_server_disconnected() -> void:
	_authority_lost = true
	set_process(false)
	hud.show_toast("The host disconnected. Returning to the lobby...", true)
	_return_to_main_scene.call_deferred()


func _on_game_end_requested() -> void:
	_authority_lost = true
	set_process(false)
	_return_to_main_scene.call_deferred()


func _return_to_lobby() -> void:
	AudioDirector.play("ui_confirm")
	SteamSession.return_to_lobby()


func _return_to_main_scene() -> void:
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
