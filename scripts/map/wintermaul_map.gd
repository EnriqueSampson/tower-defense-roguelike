class_name WintermaulMap
extends Node3D

## Orthogonal 2D simulation (sim pixels, TILE_SIZE per cell) presented in 3D:
## one tile is one unit on the XZ plane, see MapProjection.
signal creep_route_finished(creep_id: int)
signal creep_killed(creep_id: int)
signal creep_damaged(creep_id: int, amount: int)
signal build_cell_requested(cell: Vector2i)
signal placement_rejected(cell: Vector2i, reason: int)
signal tower_clicked(tower_id: int)
signal creep_clicked(creep_id: int)
signal builder_clicked(owner_peer: int)
## Right-click on the ground (WC3 move order); `queue` when shift is held.
signal move_requested(plane: Vector2, queue: bool)
## Right-click while placing a tower cancels placement, as in WC3.
signal placement_cancelled
signal selection_cleared
signal tower_fired(tower_id: int, creep_id: int)
signal impact_resolved(tower_id: int, hit_count: int, killed_count: int)

enum Placement {
	OK,
	OUT_OF_BOUNDS,
	NOT_BUILDABLE,
	OCCUPIED,
	CREEP_ON_CELL,
	BLOCKS_ROUTE,
	NOT_OWNED,
	UNAFFORDABLE,
	LOCKED,
	NO_TOWER_SELECTED,
	WRONG_RACE,
}

const RouteRunnerScene = preload("res://scripts/actors/route_runner.gd")
const TowerScene = preload("res://scripts/actors/tower.gd")
const ProjectileScene = preload("res://scripts/actors/projectile.gd")
const CorpseScene = preload("res://scripts/actors/corpse.gd")
const BuilderScene = preload("res://scripts/actors/builder.gd")
const PathGridModel = preload("res://scripts/pathfinding/path_grid.gd")
const Layout = preload("res://scripts/data/classic_wintermaul_layout.gd")
const GRID_SIZE := Layout.GRID_SIZE
const TILE_SIZE := MapProjection.TILE_SIZE
const GOAL_CELL := Layout.FINAL_GATE
const LANE_COLORS: Array[Color] = Layout.PLAYER_COLORS
const GROUND_DETAIL_TILES := 12.0
## Terrain texture resolution; 8 px per cell keeps the 144x160 map at 1152x1280.
const BAKE_PIXELS_PER_CELL := 8
const DECAL_HEIGHT := 0.015
const LANDMARK_HEIGHT := 0.03

var _routes: Array[PackedVector2Array] = []
var _spawner_routes: Array[Array] = []
var _spawner_cells: Array[Array] = []
var _route_targets: Array[Array] = []
var _required_segments: Array[Dictionary] = []
var _terrain_cells: Dictionary = {}
var _build_cells: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _positions: Array[Dictionary] = []
var _path_grid: PathGrid
var _last_creep_positions: Dictionary = {}
## creep_id -> {start_position, start_stage, start_distance} of killed creeps,
## so the host can spawn a splitter's children where it fell.
var _last_creep_routes: Dictionary = {}
## Active creeps shared by every caller within a frame (towers, impacts,
## minimap); rebuilt on the next frame or when creeps spawn, die or leave.
var _active_creeps_cache: Array = []
var _active_creeps_frame := -1
var _terrain_texture: ImageTexture

var _build_enabled := false
var _build_definition: TowerDefinition
var _build_cost := 0
var _team_gold := 0
var _controllable_positions: Array[int] = []
var _owners := PackedInt32Array()
var _local_peer_id := 1
var _owner_names: Dictionary = {}
## Cell under the cursor (tower picking) and the build anchor derived from it
## (top-left cell of the selected tower's footprint, centered on the cursor).
var _hover_plane := Vector2.ZERO
var _hover_cell := Vector2i.ZERO
var _preview_cell := Vector2i.ZERO
var _preview_visible := false
var _selected_tower_id := 0
var _selected_creep_id := 0
var _selected_builder_owner := 0
var _site_markers: Array[MeshInstance3D] = []
var _camera: BattlefieldCamera
var _ground_material: StandardMaterial3D
var _hover_material: ShaderMaterial
var _preview_ring_material: ShaderMaterial

@onready var _ground: MeshInstance3D = %Ground
@onready var _walls: MeshInstance3D = %Walls
@onready var _landmarks: Node3D = %Landmarks
@onready var _route_hints: MeshInstance3D = %RouteHints
@onready var _hover_decal: MeshInstance3D = %HoverDecal
@onready var _preview_ring: MeshInstance3D = %PreviewRing
@onready var _static_canvas: MapPaintLayer = %StaticCanvas
@onready var _dynamic_canvas: MapPaintLayer = %DynamicCanvas
@onready var effects: EffectsLayer = %Effects


func _ready() -> void:
	_ensure_map_data()
	_build_ground()
	_build_walls()
	_build_landmarks()
	_build_route_hints()
	_hover_material = MeshPalette.new_ring_material(Color.WHITE, 0.86, 0.6, true)
	_hover_decal.mesh = MeshPalette.unit_quad()
	_hover_decal.material_override = _hover_material
	_hover_decal.scale = Vector3(0.5, 1.0, 0.5)
	_hover_decal.visible = false
	_preview_ring_material = MeshPalette.new_ring_material(Color.WHITE, 0.9, 0.12)
	_preview_ring.mesh = MeshPalette.unit_quad()
	_preview_ring.material_override = _preview_ring_material
	_preview_ring.visible = false
	_static_canvas.painter = _paint_static_canvas
	_dynamic_canvas.painter = _paint_dynamic_canvas
	effects.projector = project_to_screen
	effects.screen_scale = get_screen_scale
	_static_canvas.queue_redraw()


func _process(_delta: float) -> void:
	# Runs before the Towers and RouteRunners children, so targeting this
	# frame sees fresh detection.
	refresh_detection()
	_dynamic_canvas.queue_redraw()


## Reveals invisible creeps inside any tower's detection range. Deterministic
## from the replicated tower stats, so every peer shows the same creeps.
func refresh_detection() -> void:
	var detectors: Array = []
	for creep: RouteRunner in get_active_creeps():
		if not creep.invisible:
			continue
		if detectors.is_empty():
			for child in %Towers.get_children():
				if child is Tower and not child.is_queued_for_deletion() and child.detection_range() > 0.0:
					detectors.append(child)
			if detectors.is_empty():
				detectors.append(null)
		var seen := false
		for tower in detectors:
			if tower != null and tower.plane_position.distance_squared_to(creep.plane_position) <= tower.detection_range() * tower.detection_range():
				seen = true
				break
		if seen != creep.detected:
			creep.set_detected(seen)


## Called by the battlefield camera so screen picking and label projection
## follow the 3D view. Without a camera the map treats screen space as sim space.
func attach_camera(camera: BattlefieldCamera) -> void:
	_camera = camera
	camera.view_changed.connect(_on_view_changed)
	_on_view_changed()


func project_to_screen(plane: Vector2, height := 0.0) -> Vector2:
	if is_instance_valid(_camera):
		return _camera.plane_to_screen(plane, height)
	return plane


## Screen pixels per sim pixel at the current zoom.
func get_screen_scale() -> float:
	if is_instance_valid(_camera):
		return _camera.get_screen_scale()
	return 1.0


func _on_view_changed() -> void:
	if is_node_ready():
		_static_canvas.queue_redraw()


# --- Creeps -------------------------------------------------------------------

## Positions with several spawners alternate between them by creep id so every
## peer picks the same pad without extra replication. `start` (split children)
## may hold start_position, start_stage and start_distance.
func spawn_creep(creep_id: int, lane_id: int, definition: CreepDefinition, health := -1, speed_multiplier := 1.0, start := {}) -> RouteRunner:
	_ensure_map_data()
	if lane_id < 0 or lane_id >= _routes.size() or definition == null:
		return null
	var spawners: Array = _spawner_cells[lane_id]
	var spawn_cell: Vector2i = spawners[creep_id % spawners.size()]
	var runner := RouteRunnerScene.new() as RouteRunner
	%RouteRunners.add_child(runner)
	_invalidate_active_creeps()
	var options := {
		"color": definition.color,
		"definition_id": definition.id,
		"armor": definition.armor,
		"regen_per_second": definition.regen_per_second,
		"slow_immune": definition.slow_immune or definition.magic_immune,
		"is_boss": definition.is_boss,
		"is_air": definition.is_air,
		"magic_immune": definition.magic_immune,
		"invisible": definition.invisible,
		"radius": definition.radius,
		"speed_multiplier": speed_multiplier,
		"visual_scene": definition.visual_scene,
	}
	options.merge(start, true)
	runner.setup(
		creep_id,
		lane_id,
		spawn_cell,
		get_route_targets(lane_id),
		definition.speed * TILE_SIZE,
		LANE_COLORS[lane_id],
		definition.health if health < 0 else health,
		self,
		options
	)
	runner.finished.connect(_on_runner_finished)
	runner.killed.connect(_on_runner_killed)
	runner.damaged.connect(func(id: int, amount: int) -> void: creep_damaged.emit(id, amount))
	return runner


func remove_creep(creep_id: int, killed := false) -> void:
	_invalidate_active_creeps()
	var runner := get_creep(creep_id)
	if runner == null:
		return
	if killed:
		effects.death(runner.plane_position, runner.body_color, runner.radius)
		_spawn_corpse(runner)
	else:
		effects.leak(runner.plane_position)
	_last_creep_positions[creep_id] = runner.plane_position
	runner.queue_free()


func clear_creeps() -> void:
	_invalidate_active_creeps()
	for child in %RouteRunners.get_children():
		child.queue_free()


func get_creep(creep_id: int) -> RouteRunner:
	for child in %RouteRunners.get_children():
		if child is RouteRunner and child.creep_id == creep_id and not child.is_queued_for_deletion():
			return child
	return null


## Callers must not modify the returned array. Entries can die later in the
## same frame, so consumers still check health (TowerTargeting, CombatResolver).
func get_active_creeps() -> Array:
	var frame := Engine.get_process_frames()
	if frame == _active_creeps_frame:
		return _active_creeps_cache
	var creeps: Array = []
	for child in %RouteRunners.get_children():
		if child is RouteRunner and child.health > 0 and not child.is_queued_for_deletion():
			creeps.append(child)
	_active_creeps_cache = creeps
	_active_creeps_frame = frame
	return creeps


func _invalidate_active_creeps() -> void:
	_active_creeps_frame = -1


## Where a creep killed this frame fell (empty once creep_killed returns).
func last_creep_route(creep_id: int) -> Dictionary:
	return _last_creep_routes.get(creep_id, {})


func show_bounty(creep_id: int, amount: int) -> void:
	if amount <= 0 or not _last_creep_positions.has(creep_id):
		return
	effects.floating_text(_last_creep_positions[creep_id], "+%d" % amount, Color("f0d868"))
	_last_creep_positions.erase(creep_id)


func find_nearest_creep(origin: Vector2, attack_range: float) -> RouteRunner:
	return TowerTargeting.select(get_active_creeps(), origin, attack_range, TowerTargeting.Mode.NEAREST)


## Authoritative creep presentation state for client reconciliation.
func creep_snapshot() -> Array:
	var records: Array = []
	for runner: RouteRunner in get_active_creeps():
		records.append({
			"id": runner.creep_id,
			"position": runner.lane_id,
			"definition_id": runner.definition_id,
			"health": runner.health,
			"max_health": runner.max_health,
			"stage": runner.get_stage_index(),
			"x": runner.plane_position.x,
			"y": runner.plane_position.y,
			"slow": runner.get_slow_remaining(),
		})
	return records


## Mirrors authoritative creep records: spawns missing creeps, corrects
## existing ones, and removes creeps the host no longer tracks.
func reconcile_creeps(records: Array, creep_lookup: Callable, speed_multiplier := 1.0) -> Dictionary:
	var summary := {"added": 0, "updated": 0, "removed": 0}
	var seen: Dictionary = {}
	for record in records:
		var creep_id := int(record["id"])
		seen[creep_id] = true
		var runner := get_creep(creep_id)
		if runner == null:
			var definition: CreepDefinition = creep_lookup.call(str(record.get("definition_id", "")))
			if definition == null:
				continue
			runner = spawn_creep(creep_id, int(record["position"]), definition, int(record.get("max_health", -1)), speed_multiplier)
			if runner == null:
				continue
			summary["added"] += 1
		else:
			summary["updated"] += 1
		runner.sync_authoritative(
			int(record["health"]),
			int(record.get("stage", 0)),
			Vector2(float(record["x"]), float(record["y"])),
			float(record.get("slow", 0.0))
		)
	for child in %RouteRunners.get_children():
		if child is RouteRunner and not seen.has(child.creep_id) and not child.is_queued_for_deletion():
			child.queue_free()
			summary["removed"] += 1
	if summary["removed"] > 0 or summary["added"] > 0:
		_invalidate_active_creeps()
	return summary


# --- Towers -------------------------------------------------------------------

func spawn_tower(tower_id: int, cell: Vector2i, definition: TowerDefinition, targeting := -1, stats := {}, position_index := -1) -> Tower:
	_ensure_map_data()
	if definition == null:
		return null
	var cells := footprint_cells(cell, definition.footprint)
	for footprint_cell in cells:
		if _occupied_cells.has(footprint_cell):
			return null
	if not _path_grid.commit_block_cells(cells):
		return null
	for footprint_cell in cells:
		_occupied_cells[footprint_cell] = tower_id
	var tower := TowerScene.new() as Tower
	%Towers.add_child(tower)
	tower.plane_position = footprint_center(cell, definition.footprint)
	var resolved_targeting := targeting if TowerTargeting.is_valid_mode(targeting) else definition.default_targeting
	var resolved_stats := stats if not stats.is_empty() else definition.stats()
	var resolved_position := position_index if position_index >= 0 else get_cell_position_index(cell)
	tower.setup(tower_id, cell, definition, resolved_targeting, resolved_stats, resolved_position)
	tower.fired.connect(_on_tower_fired)
	effects.ring(tower.plane_position, definition.accent_color, TILE_SIZE * 0.7 * definition.footprint.x)
	_refresh_preview()
	return tower


func remove_tower(tower_id: int) -> bool:
	var tower := get_tower(tower_id)
	if tower == null:
		return false
	var cells := footprint_cells(tower.grid_cell, tower.footprint)
	for footprint_cell in cells:
		_occupied_cells.erase(footprint_cell)
	_path_grid.unblock_cells(cells)
	effects.ring(tower.plane_position, Color("f0d868"), TILE_SIZE * 0.7 * tower.footprint.x)
	if _selected_tower_id == tower_id:
		_selected_tower_id = 0
	tower.queue_free()
	_refresh_preview()
	return true


func update_tower(tower_id: int, definition: TowerDefinition, targeting: int, stats: Dictionary) -> bool:
	var tower := get_tower(tower_id)
	if tower == null or definition == null:
		return false
	var upgraded := definition != tower.definition
	tower.apply_stats(definition, targeting, stats)
	if upgraded:
		effects.ring(tower.plane_position, Color("9ff2d1"), TILE_SIZE * 0.9)
	return true


func get_tower(tower_id: int) -> Tower:
	for child in %Towers.get_children():
		if child is Tower and child.tower_id == tower_id and not child.is_queued_for_deletion():
			return child
	return null


func get_tower_at(cell: Vector2i) -> Tower:
	if not _occupied_cells.has(cell):
		return null
	return get_tower(int(_occupied_cells[cell]))


func get_tower_count() -> int:
	var count := 0
	for child in %Towers.get_children():
		if child is Tower and not child.is_queued_for_deletion():
			count += 1
	return count


func set_selected_tower(tower_id: int) -> void:
	if _selected_tower_id == tower_id:
		return
	var previous := get_tower(_selected_tower_id)
	if previous:
		previous.set_selected(false)
	_selected_tower_id = tower_id
	var current := get_tower(tower_id)
	if current:
		current.set_selected(true)
	_refresh_preview()


## Nearest living creep whose on-screen body is under `screen_position`.
func creep_at_screen(screen_position: Vector2) -> RouteRunner:
	var unit_scale := get_screen_scale()
	var best: RouteRunner = null
	var best_distance := INF
	for runner: RouteRunner in get_active_creeps():
		if runner.is_hidden():
			continue
		var center := project_to_screen(runner.plane_position, runner.get_visual_height() * 0.5)
		var pick_radius := maxf(14.0, runner.radius * unit_scale * 1.8)
		var distance := center.distance_to(screen_position)
		if distance <= pick_radius and distance < best_distance:
			best = runner
			best_distance = distance
	return best


# --- Builders -------------------------------------------------------------------

func _builders() -> Node3D:
	var container := get_node_or_null("Builders") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Builders"
		add_child(container)
	return container


func get_builder(owner_peer: int) -> Builder:
	for child in _builders().get_children():
		if child is Builder and child.owner_peer == owner_peer and not child.is_queued_for_deletion():
			return child
	return null


## Mirrors BuilderSystem records by owner. `authoritative` places them
## exactly (host); clients extrapolate toward each record's target.
## `scene_for_owner(owner_peer) -> PackedScene` picks each builder's race model.
func reconcile_builders(records: Array, speed_pixels: float, authoritative: bool, scene_for_owner := Callable()) -> void:
	var seen: Dictionary = {}
	for record in records:
		var owner_peer := int(record["owner"])
		seen[owner_peer] = true
		var builder := get_builder(owner_peer)
		if builder == null:
			builder = BuilderScene.new() as Builder
			builder.owner_peer = owner_peer
			_builders().add_child(builder)
			builder.plane_position = Vector2(float(record["x"]), float(record["y"]))
			builder.set_selected(owner_peer == _selected_builder_owner and owner_peer != 0)
		builder.speed_pixels = speed_pixels
		if scene_for_owner.is_valid():
			builder.set_model_scene(scene_for_owner.call(owner_peer))
		builder.apply_record(record, authoritative)
	for child in _builders().get_children():
		if child is Builder and not seen.has(child.owner_peer):
			child.queue_free()


func builder_at_screen(screen_position: Vector2) -> Builder:
	var best: Builder = null
	var best_distance := INF
	for child in _builders().get_children():
		if not child is Builder:
			continue
		var center := project_to_screen(child.plane_position, MapProjection.units(10.0))
		var distance := center.distance_to(screen_position)
		if distance <= maxf(16.0, get_screen_scale() * 12.0) and distance < best_distance:
			best = child
			best_distance = distance
	return best


func set_selected_builder(owner_peer: int) -> void:
	var previous := get_builder(_selected_builder_owner)
	if previous:
		previous.set_selected(false)
	_selected_builder_owner = owner_peer
	var current := get_builder(owner_peer)
	if current:
		current.set_selected(true)


## Footprint markers for the local builder's queued build orders.
func show_build_sites(sites: Array) -> void:
	while _site_markers.size() < sites.size():
		var marker := MeshInstance3D.new()
		marker.mesh = MeshPalette.unit_quad()
		marker.material_override = MeshPalette.new_ring_material(Color("7fd0ff"), 0.8, 0.18, true)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		_site_markers.append(marker)
	for index in range(_site_markers.size()):
		var marker := _site_markers[index]
		marker.visible = index < sites.size()
		if not marker.visible:
			continue
		var site: Dictionary = sites[index]
		var definition_footprint: Vector2i = site.get("footprint", Vector2i(2, 2))
		var center := footprint_center(site["cell"], definition_footprint)
		marker.position = MapProjection.to_3d(center, DECAL_HEIGHT * 3.0)
		marker.scale = Vector3(definition_footprint.x * 0.5, 1.0, definition_footprint.y * 0.5)


func set_selected_creep(creep_id: int) -> void:
	var previous := get_creep(_selected_creep_id)
	if previous:
		previous.set_selected(false)
	_selected_creep_id = creep_id
	var current := get_creep(creep_id)
	if current:
		current.set_selected(true)


func get_selected_tower_id() -> int:
	return _selected_tower_id


## Mirrors authoritative tower records by stable ID.
func reconcile_towers(records: Array, definition_lookup: Callable, stats_lookup: Callable) -> Dictionary:
	var summary := {"added": 0, "updated": 0, "removed": 0}
	var seen: Dictionary = {}
	var by_id: Dictionary = {}
	for child in %Towers.get_children():
		if child is Tower and not child.is_queued_for_deletion():
			by_id[child.tower_id] = child
	for record in records:
		var tower_id := int(record["id"])
		seen[tower_id] = true
		var tower: Tower = by_id.get(tower_id)
		var stats: Dictionary = stats_lookup.call(record)
		if tower == null:
			var definition: TowerDefinition = definition_lookup.call(str(record["definition_id"]))
			if definition == null:
				continue
			var spawned := spawn_tower(tower_id, record["cell"], definition, int(record["targeting"]), stats, int(record.get("position", -1)))
			if spawned != null:
				spawned.apply_progress(record)
				summary["added"] += 1
			continue
		elif tower.definition == null or tower.definition.id != str(record["definition_id"]) or tower.targeting != int(record["targeting"]) or tower.stats != stats:
			update_tower(tower_id, definition_lookup.call(str(record["definition_id"])), int(record["targeting"]), stats)
			summary["updated"] += 1
		tower.apply_progress(record)
	for child in %Towers.get_children():
		if child is Tower and not seen.has(child.tower_id) and not child.is_queued_for_deletion():
			remove_tower(child.tower_id)
			summary["removed"] += 1
	return summary


# --- Combat -------------------------------------------------------------------

func fire_projectile(tower: Tower, target: RouteRunner) -> Projectile:
	if tower == null or target == null:
		return null
	var payload := {
		"tower_id": tower.tower_id,
		"damage": tower.damage(),
		"splash_radius": float(tower.stats.get("splash_radius", 0.0)),
		"slow_factor": float(tower.stats.get("slow_factor", 0.0)),
		"slow_duration": float(tower.stats.get("slow_duration", 0.0)),
		"armor_pierce": int(tower.stats.get("armor_pierce", 0)),
		"magic": bool(tower.stats.get("magic", false)),
		"targets_ground": bool(tower.stats.get("targets_ground", true)),
		"targets_air": bool(tower.stats.get("targets_air", true)),
	}
	var projectile := ProjectileScene.new() as Projectile
	%Projectiles.add_child(projectile)
	projectile.setup(
		tower.plane_position,
		target,
		float(tower.stats.get("projectile_speed", 600.0)),
		tower.definition.accent_color if tower.definition else Color.WHITE,
		payload,
		_on_projectile_impact
	)
	return projectile


## Client-side mirror of a host shot: plays the animation and visual projectile.
func show_projectile(tower_id: int, creep_id: int) -> void:
	var tower := get_tower(tower_id)
	var target := get_creep(creep_id)
	if tower == null or target == null:
		return
	tower.play_fire_animation()
	fire_projectile(tower, target)


func _on_tower_fired(tower: Tower, target: RouteRunner) -> void:
	fire_projectile(tower, target)
	tower_fired.emit(tower.tower_id, target.creep_id)


func _on_projectile_impact(payload: Dictionary, impact_position: Vector2, target: RouteRunner) -> void:
	var splash := float(payload.get("splash_radius", 0.0))
	var tower := get_tower(int(payload.get("tower_id", 0)))
	var color := tower.definition.accent_color if tower and tower.definition else Color.WHITE
	effects.impact(impact_position, color, splash if splash > 0.0 else 9.0)
	if not _is_authority():
		impact_resolved.emit(int(payload.get("tower_id", 0)), 0, 0)
		return
	var hits := CombatResolver.resolve_impact(get_active_creeps(), payload, impact_position, target)
	var killed := 0
	for hit in hits:
		if hit["killed"]:
			killed += 1
	impact_resolved.emit(int(payload.get("tower_id", 0)), hits.size(), killed)


func _is_authority() -> bool:
	if not is_inside_tree():
		return true
	var api := get_multiplayer()
	return api == null or not api.has_multiplayer_peer() or api.is_server()


# --- Build context and placement --------------------------------------------

func set_build_context(enabled: bool, definition: TowerDefinition, cost: int, gold: int, controllable_positions: Array[int]) -> void:
	var changed := (
		enabled != _build_enabled
		or definition != _build_definition
		or cost != _build_cost
		or gold != _team_gold
		or controllable_positions != _controllable_positions
	)
	_build_enabled = enabled
	_build_definition = definition
	_build_cost = cost
	_team_gold = gold
	_controllable_positions = controllable_positions.duplicate()
	if not enabled:
		_preview_visible = false
	if changed:
		if enabled and is_node_ready():
			_set_hover_plane(_hover_plane)
		_refresh_preview()


func set_ownership_view(owners: PackedInt32Array, local_peer_id: int, owner_names: Dictionary) -> void:
	if owners == _owners and local_peer_id == _local_peer_id and owner_names == _owner_names:
		return
	if owners != _owners or local_peer_id != _local_peer_id:
		_terrain_texture = null
	_owners = owners.duplicate()
	_local_peer_id = local_peer_id
	_owner_names = owner_names.duplicate()
	if is_node_ready():
		_refresh_ground_texture()
		_static_canvas.queue_redraw()


func get_cell_position_index(cell: Vector2i) -> int:
	_ensure_map_data()
	return int(_build_cells.get(cell, -1))


## Geometry-only placement check shared by host validation and previews.
## `cell` is the footprint anchor (top-left cell); every covered cell must be
## buildable, free, and inside one position.
func evaluate_placement(cell: Vector2i, footprint := Vector2i.ONE) -> int:
	_ensure_map_data()
	var cells := footprint_cells(cell, footprint)
	for footprint_cell in cells:
		if not _is_cell_in_bounds(footprint_cell):
			return Placement.OUT_OF_BOUNDS
	var position_index := get_cell_position_index(cell)
	for footprint_cell in cells:
		if not _build_cells.has(footprint_cell) or int(_build_cells[footprint_cell]) != position_index:
			return Placement.NOT_BUILDABLE
	for footprint_cell in cells:
		if _occupied_cells.has(footprint_cell):
			return Placement.OCCUPIED
	var creep_cells := _get_active_creep_cells()
	for footprint_cell in cells:
		if footprint_cell in creep_cells:
			return Placement.CREEP_ON_CELL
	if not _path_grid.can_block_cells(cells, [], _required_segments + _get_active_creep_segments()):
		return Placement.BLOCKS_ROUTE
	return Placement.OK


## Full local check including phase, ownership, and affordability.
func evaluate_build(cell: Vector2i) -> int:
	if not _build_enabled:
		return Placement.LOCKED
	if _build_definition == null:
		return Placement.NO_TOWER_SELECTED
	var geometry := evaluate_placement(cell, _build_definition.footprint)
	if geometry != Placement.OK:
		return geometry
	if not get_cell_position_index(cell) in _controllable_positions:
		return Placement.NOT_OWNED
	if _team_gold < _build_cost:
		return Placement.UNAFFORDABLE
	return Placement.OK


func can_place_tower(cell: Vector2i, footprint := Vector2i.ONE) -> bool:
	return evaluate_placement(cell, footprint) == Placement.OK


static func placement_text(result: int) -> String:
	match result:
		Placement.OK:
			return "Valid placement"
		Placement.OUT_OF_BOUNDS:
			return "Outside the battlefield"
		Placement.NOT_BUILDABLE:
			return "Not a build tile"
		Placement.OCCUPIED:
			return "Tile already has a tower"
		Placement.CREEP_ON_CELL:
			return "A creep is standing there"
		Placement.BLOCKS_ROUTE:
			return "Would seal a creep route"
		Placement.NOT_OWNED:
			return "Not your position"
		Placement.UNAFFORDABLE:
			return "Not enough team gold"
		Placement.LOCKED:
			return "Building is locked"
		Placement.NO_TOWER_SELECTED:
			return "Select a tower from the palette"
		Placement.WRONG_RACE:
			return "Your builder cannot build that"
	return "Unknown"


# --- Geometry -----------------------------------------------------------------

func _ensure_map_data() -> void:
	if not _routes.is_empty():
		return
	_positions = Layout.setup_map_coordinates()
	var traversable_cells: Dictionary = {}
	var route_starts: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			var terrain := Layout.terrain_at(cell, _positions)
			_terrain_cells[cell] = terrain
			if Layout.is_traversable(terrain):
				traversable_cells[cell] = true
			if terrain == Layout.Terrain.OPEN:
				var owner := Layout.position_index_at(cell, _positions)
				if owner >= 0:
					_build_cells[cell] = owner

	for lane_id in range(_positions.size()):
		var position_data: Dictionary = _positions[lane_id]
		var spawners: Array = position_data["spawns"]
		_spawner_cells.append(spawners.duplicate())
		for spawn_cell in spawners:
			route_starts.append(spawn_cell)
		var route_nodes := _build_route_nodes(position_data)
		var targets: Array[Vector2i] = []
		for node_index in range(1, route_nodes.size()):
			targets.append(route_nodes[node_index])
			_required_segments.append({"start": route_nodes[node_index - 1], "target": route_nodes[node_index]})
		for spawner_index in range(1, spawners.size()):
			_required_segments.append({"start": spawners[spawner_index], "target": route_nodes[1]})
		_route_targets.append(targets)
	_path_grid = PathGridModel.new(GRID_SIZE, traversable_cells, route_starts, GOAL_CELL)

	# Initial shortest routes are presentation hints; creeps repath as mazes grow.
	for lane_id in range(_positions.size()):
		var lane_routes: Array = []
		for spawn_cell in _spawner_cells[lane_id]:
			var route := PackedVector2Array([spawn_cell])
			var cursor: Vector2i = spawn_cell
			for target in _route_targets[lane_id]:
				var segment := _path_grid.get_path(cursor, target)
				for point_index in range(1, segment.size()):
					route.append(segment[point_index])
				cursor = target
			lane_routes.append(route)
		_spawner_routes.append(lane_routes)
		_routes.append(lane_routes[0])


func grid_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE


func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


## Cells covered by a footprint anchored at its top-left cell.
static func footprint_cells(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(maxi(footprint.y, 1)):
		for x in range(maxi(footprint.x, 1)):
			cells.append(anchor + Vector2i(x, y))
	return cells


func footprint_center(anchor: Vector2i, footprint: Vector2i) -> Vector2:
	return (Vector2(anchor) + Vector2(footprint) * 0.5) * TILE_SIZE


## Footprint anchor whose center is nearest to `world_position`: the hovered
## cell for 1x1, the nearest grid intersection for 2x2.
func anchor_for_world(world_position: Vector2, footprint: Vector2i) -> Vector2i:
	var offset := (Vector2(footprint) - Vector2.ONE) * 0.5
	return Vector2i(
		floori(world_position.x / TILE_SIZE - offset.x),
		floori(world_position.y / TILE_SIZE - offset.y)
	)


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(GRID_SIZE) * TILE_SIZE)


func get_route_count() -> int:
	_ensure_map_data()
	return _routes.size()


func get_route_start(lane_id: int) -> Vector2i:
	_ensure_map_data()
	return Vector2i(_routes[lane_id][0]) if lane_id >= 0 and lane_id < _routes.size() else Vector2i(-1, -1)


func get_spawner_cells(lane_id: int) -> Array[Vector2i]:
	_ensure_map_data()
	var cells: Array[Vector2i] = []
	if lane_id >= 0 and lane_id < _spawner_cells.size():
		cells.assign(_spawner_cells[lane_id])
	return cells


func get_terrain(cell: Vector2i) -> int:
	_ensure_map_data()
	return int(_terrain_cells.get(cell, Layout.Terrain.VOID))


func get_route_goal(lane_id: int) -> Vector2i:
	_ensure_map_data()
	return Vector2i(_routes[lane_id][-1]) if lane_id >= 0 and lane_id < _routes.size() else Vector2i(-1, -1)


func get_route_targets(lane_id: int) -> Array[Vector2i]:
	_ensure_map_data()
	var targets: Array[Vector2i] = []
	if lane_id >= 0 and lane_id < _route_targets.size():
		targets.assign(_route_targets[lane_id])
	return targets


func get_grid_revision() -> int:
	_ensure_map_data()
	return _path_grid.revision


func get_world_path(from_cell: Vector2i, target_cell := Vector2i(-1, -1)) -> PackedVector2Array:
	_ensure_map_data()
	var world_path := PackedVector2Array()
	for path_cell in _path_grid.get_path(from_cell, target_cell):
		world_path.append(grid_to_world(path_cell))
	return world_path


func get_grid_path(from_cell: Vector2i, target_cell := Vector2i(-1, -1)) -> Array[Vector2i]:
	_ensure_map_data()
	return _path_grid.get_path(from_cell, target_cell)


func get_position_world_rect(position_index: int) -> Rect2:
	_ensure_map_data()
	if position_index < 0 or position_index >= _positions.size():
		return Rect2()
	var bounds: Rect2i = _positions[position_index]["macro_bounds"]
	return Rect2(Vector2(bounds.position) * TILE_SIZE, Vector2(bounds.size) * TILE_SIZE)


## Ground creeps only: flyers never block building or care about the maze.
func _get_active_creep_cells() -> Array[Vector2i]:
	var active_cells: Array[Vector2i] = []
	var seen_cells: Dictionary = {}
	for child in get_active_creeps():
		if child.is_air:
			continue
		var cell := world_to_grid(child.plane_position)
		if not seen_cells.has(cell):
			seen_cells[cell] = true
			active_cells.append(cell)
	return active_cells


func _get_active_creep_segments() -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for child in get_active_creeps():
		if child.is_air:
			continue
		segments.append({
			"start": world_to_grid(child.plane_position),
			"target": child.get_current_target(),
		})
	return segments


func _build_route_nodes(position_data: Dictionary) -> Array[Vector2i]:
	var nodes: Array[Vector2i] = [position_data["spawn"], position_data["checkpoint"]]
	if position_data["checkpoint"] != Layout.FINAL_CHECKPOINT:
		nodes.append(Layout.FINAL_CHECKPOINT)
	nodes.append(GOAL_CELL)
	return nodes


func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_preview_from_viewport(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_update_preview_from_viewport(event.position)
		if _build_definition != null:
			placement_cancelled.emit()
		elif _preview_visible:
			move_requested.emit(_hover_plane, event.shift_pressed)
			effects.ring(_hover_plane, Color("5ce36b"), TILE_SIZE * 0.6)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_preview_from_viewport(event.position)
		if not _preview_visible:
			return
		if _build_definition == null or not _build_enabled:
			var builder := builder_at_screen(event.position)
			if builder != null:
				builder_clicked.emit(builder.owner_peer)
				get_viewport().set_input_as_handled()
				return
			var creep := creep_at_screen(event.position)
			if creep != null:
				creep_clicked.emit(creep.creep_id)
				get_viewport().set_input_as_handled()
				return
		var tower := get_tower_at(_hover_cell)
		if tower != null:
			tower_clicked.emit(tower.tower_id)
			get_viewport().set_input_as_handled()
			return
		if not _build_enabled:
			return
		if _build_definition == null:
			selection_cleared.emit()
			get_viewport().set_input_as_handled()
			return
		var result := evaluate_build(_preview_cell)
		if result == Placement.OK:
			build_cell_requested.emit(_preview_cell)
		else:
			placement_rejected.emit(_preview_cell, result)
		get_viewport().set_input_as_handled()


func _update_preview_from_viewport(viewport_position: Vector2) -> void:
	var plane := _camera.screen_to_plane(viewport_position) if is_instance_valid(_camera) else viewport_position
	_set_hover_plane(plane)


func _set_hover_plane(plane: Vector2) -> void:
	_hover_plane = plane
	var hovered_cell := world_to_grid(plane)
	var anchor := anchor_for_world(plane, _preview_footprint())
	var visible := _is_cell_in_bounds(hovered_cell)
	if hovered_cell == _hover_cell and anchor == _preview_cell and visible == _preview_visible:
		return
	_hover_cell = hovered_cell
	_preview_cell = anchor
	_preview_visible = visible
	_refresh_preview()


func _preview_footprint() -> Vector2i:
	return _build_definition.footprint if _build_definition != null else Vector2i.ONE


# --- 3D battlefield -----------------------------------------------------------

func _build_ground() -> void:
	var size := Vector2(GRID_SIZE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(size.x, 0, 0), Vector3(size.x, 0, size.y), Vector3(0, 0, size.y),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	# UV2 tiles a noise detail layer every GROUND_DETAIL_TILES cells.
	var detail_scale := size / GROUND_DETAIL_TILES
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2.ZERO, Vector2(detail_scale.x, 0), detail_scale, Vector2(0, detail_scale.y)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Default back-face culling: with culling disabled the Compatibility renderer
	# flips this quad's normal and the sun stops lighting the ground.
	_ground_material = StandardMaterial3D.new()
	_ground_material.roughness = 1.0
	_ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ground_material.detail_enabled = true
	_ground_material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	_ground_material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_ground_material.detail_albedo = _ground_detail_texture()
	mesh.surface_set_material(0, _ground_material)
	_ground.mesh = mesh
	_refresh_ground_texture()


## Soft tiling noise multiplied over the ground so it reads as snow and
## frozen earth rather than flat colour.
func _ground_detail_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	# Map noise into a narrow bright band: a multiply between ~0.86 and 1.0.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.88, 0.92))
	ramp.set_color(1, Color(1, 1, 1))
	texture.color_ramp = ramp
	return texture


func _refresh_ground_texture() -> void:
	if _terrain_texture == null:
		_terrain_texture = _bake_terrain_texture()
	_ground_material.albedo_texture = _terrain_texture


## Wall cells become snowy rock cliffs (one mesh) with instanced pines.
func _build_walls() -> void:
	_walls.mesh = TerrainBuilder.build_cliffs(_terrain_cells, GRID_SIZE, Layout.Terrain.WALL)
	var pines := _walls.get_node_or_null("Pines") as MultiMeshInstance3D
	if pines == null:
		pines = MultiMeshInstance3D.new()
		pines.name = "Pines"
		_walls.add_child(pines)
	pines.multimesh = TerrainBuilder.build_pines(_terrain_cells, GRID_SIZE, Layout.Terrain.WALL)
	for prop in [["Boulders", TerrainBuilder.build_boulders], ["Crystals", TerrainBuilder.build_crystals]]:
		var instance := _walls.get_node_or_null(str(prop[0])) as MultiMeshInstance3D
		if instance == null:
			instance = MultiMeshInstance3D.new()
			instance.name = str(prop[0])
			_walls.add_child(instance)
		instance.multimesh = (prop[1] as Callable).call(_terrain_cells, GRID_SIZE, Layout.Terrain.WALL)


func _build_landmarks() -> void:
	for child in _landmarks.get_children():
		child.queue_free()
	var pad_color := Color(0.02, 0.035, 0.032, 0.94)
	for position_index in range(_positions.size()):
		var data := _positions[position_index]
		var color := LANE_COLORS[position_index]
		for spawn_cell in data["spawns"]:
			_add_disc(grid_to_world(spawn_cell), 16.0, pad_color)
			_add_ring(grid_to_world(spawn_cell), 15.0, 3.0, color)
		if data["checkpoint"] != Layout.FINAL_CHECKPOINT:
			_add_ring(grid_to_world(data["checkpoint"]), 9.0, 1.5, color.lightened(0.25))
	_add_ring(grid_to_world(Layout.FINAL_CHECKPOINT), 11.0, 1.5, Color("e4f4ef"))
	var goal := grid_to_world(GOAL_CELL)
	_add_disc(goal, 18.0, Color("e4f4ef"))
	_add_disc(goal, 11.0, Color("b5544c"), LANDMARK_HEIGHT * 1.5)
	_add_ring(goal, 23.0, 2.0, Color("e4f4ef"))


func _add_disc(plane: Vector2, radius_px: float, color: Color, height := LANDMARK_HEIGHT) -> void:
	var disc := MeshInstance3D.new()
	disc.mesh = MeshPalette.unit_quad()
	disc.material_override = MeshPalette.disc_material(color)
	var radius := MapProjection.units(radius_px)
	disc.position = MapProjection.to_3d(plane, height)
	disc.scale = Vector3(radius, 1.0, radius)
	_landmarks.add_child(disc)


func _add_ring(plane: Vector2, radius_px: float, thickness_px: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = MeshPalette.unit_quad()
	ring.material_override = MeshPalette.new_ring_material(color, 1.0 - thickness_px / radius_px)
	var radius := MapProjection.units(radius_px)
	ring.position = MapProjection.to_3d(plane, LANDMARK_HEIGHT * 2.0)
	ring.scale = Vector3(radius, 1.0, radius)
	_landmarks.add_child(ring)


## Faint shortest-route hints from every spawner as ground-level line segments.
func _build_route_hints() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for lane_id in range(_spawner_routes.size()):
		var hint := LANE_COLORS[lane_id]
		var color := Color(hint.r, hint.g, hint.b, 0.35)
		for route in _spawner_routes[lane_id]:
			for point_index in range(1, route.size()):
				vertices.append(MapProjection.to_3d(grid_to_world(Vector2i(route[point_index - 1])), DECAL_HEIGHT))
				vertices.append(MapProjection.to_3d(grid_to_world(Vector2i(route[point_index])), DECAL_HEIGHT))
				colors.append(color)
				colors.append(color)
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, material)
	_route_hints.mesh = mesh


## Moves the hover decal and range preview to the hovered cell.
func _refresh_preview() -> void:
	if not is_node_ready():
		return
	if not _build_enabled or not _preview_visible:
		_hover_decal.visible = false
		_preview_ring.visible = false
		return
	var hovered_tower := get_tower_at(_hover_cell)
	if hovered_tower != null or _build_definition == null:
		var hover_footprint := hovered_tower.footprint if hovered_tower != null else Vector2i.ONE
		var hover_center := hovered_tower.plane_position if hovered_tower != null else grid_to_world(_hover_cell)
		_place_hover_decal(hover_center, hover_footprint)
		_hover_material.set_shader_parameter("color", Color(0.9, 0.95, 1.0, 0.8))
		_hover_material.set_shader_parameter("fill_alpha", 0.22)
		_preview_ring.visible = false
		return
	var center := footprint_center(_preview_cell, _build_definition.footprint)
	_place_hover_decal(center, _build_definition.footprint)
	var preview_color := _preview_color(evaluate_build(_preview_cell))
	_hover_material.set_shader_parameter("color", Color(preview_color.r, preview_color.g, preview_color.b, 0.9))
	_hover_material.set_shader_parameter("fill_alpha", preview_color.a)
	var radius := MapProjection.units(_build_definition.attack_range)
	_preview_ring.position = MapProjection.to_3d(center, DECAL_HEIGHT * 2.0)
	_preview_ring.scale = Vector3(radius, 1.0, radius)
	_preview_ring_material.set_shader_parameter("color", Color(preview_color.r, preview_color.g, preview_color.b, 0.6))
	_preview_ring_material.set_shader_parameter("inner", 1.0 - MapProjection.units(1.5) / maxf(radius, 0.01))
	_preview_ring.visible = true


func _place_hover_decal(center: Vector2, footprint: Vector2i) -> void:
	_hover_decal.position = MapProjection.to_3d(center, DECAL_HEIGHT)
	_hover_decal.scale = Vector3(0.5 * footprint.x, 1.0, 0.5 * footprint.y)
	_hover_decal.visible = true


# --- Canvas overlays ----------------------------------------------------------

## Labels that only move when the camera moves.
func _paint_static_canvas(canvas: CanvasItem) -> void:
	_ensure_map_data()
	var font := ThemeDB.fallback_font
	for position_index in range(_positions.size()):
		var data := _positions[position_index]
		var label_color := LANE_COLORS[position_index].lightened(0.25)
		var spawners: Array = data["spawns"]
		for spawner_index in range(spawners.size()):
			var spawn_screen := project_to_screen(grid_to_world(spawners[spawner_index]), LANDMARK_HEIGHT)
			canvas.draw_string(font, spawn_screen + Vector2(-4, 5), str(position_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LANE_COLORS[position_index])
			var spawn_label := "SPAWN %d" % (position_index + 1)
			if spawners.size() > 1:
				spawn_label += "%s  (SHARED WAVE)" % char(65 + spawner_index)
			canvas.draw_string(font, spawn_screen + Vector2(-24, 32), spawn_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
		if data["checkpoint"] != Layout.FINAL_CHECKPOINT:
			var checkpoint_screen := project_to_screen(grid_to_world(data["checkpoint"]))
			canvas.draw_string(font, checkpoint_screen + Vector2(12, 4), "CHECKPOINT %d" % (position_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color)

	var relay_screen := project_to_screen(grid_to_world(Layout.FINAL_CHECKPOINT))
	canvas.draw_string(font, relay_screen + Vector2(-58, -16), "RELAY CHECKPOINT  (ALL POSITIONS)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e4f4ef"))
	var goal_screen := project_to_screen(grid_to_world(GOAL_CELL))
	canvas.draw_string(font, goal_screen + Vector2(-38, -28), "FINAL GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffe9e4"))
	_paint_ownership(canvas, font)


## Per-frame overlays: creep health bars and the placement reason.
func _paint_dynamic_canvas(canvas: CanvasItem) -> void:
	var unit_scale := get_screen_scale()
	for runner: RouteRunner in get_active_creeps():
		if runner.is_hidden():
			continue
		var anchor := project_to_screen(runner.plane_position, runner.get_visual_height())
		# Scales with zoom but stays readable when zoomed out and tidy up close.
		var bar_width := clampf(runner.radius * 3.0 * unit_scale, 18.0, 64.0)
		var bar_height := clampf(bar_width * 0.12, 3.0, 6.0)
		var health_ratio := float(runner.health) / float(runner.max_health)
		var bar_rect := Rect2(anchor.x - bar_width * 0.5, anchor.y - bar_height - 4.0, bar_width, bar_height)
		canvas.draw_rect(bar_rect.grow(1.0), Color(0.02, 0.02, 0.02, 0.9))
		var bar_color := Color("4fe06d") if health_ratio > 0.5 else (Color("f0d23c") if health_ratio > 0.25 else Color("f04a3e"))
		bar_rect.size.x *= health_ratio
		canvas.draw_rect(bar_rect, bar_color)
	_paint_tower_progress(canvas, unit_scale)
	if not _build_enabled or not _preview_visible or _build_definition == null or get_tower_at(_hover_cell) != null:
		return
	var result := evaluate_build(_preview_cell)
	if result == Placement.OK:
		return
	var preview_color := _preview_color(result)
	var center := project_to_screen(footprint_center(_preview_cell, _build_definition.footprint))
	canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-40, -TILE_SIZE * unit_scale), placement_text(result), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, preview_color.lightened(0.4))


## Construction (blue) and upgrade (gold) bars above towers in progress.
func _paint_tower_progress(canvas: CanvasItem, unit_scale: float) -> void:
	for child in %Towers.get_children():
		var tower := child as Tower
		if tower == null:
			continue
		var ratio := tower.progress_ratio()
		if ratio < 0.0:
			continue
		var anchor := project_to_screen(tower.plane_position, MapProjection.units(TILE_SIZE * 1.4))
		var width := clampf(TILE_SIZE * 1.6 * unit_scale, 28.0, 90.0)
		var rect := Rect2(anchor.x - width * 0.5, anchor.y - 8.0, width, 5.0)
		canvas.draw_rect(rect.grow(1.0), Color(0.02, 0.02, 0.02, 0.9))
		rect.size.x *= ratio
		canvas.draw_rect(rect, Color("5aa8f0") if tower.is_under_construction() else Color("e2bf62"))


## One texture for the whole battlefield: hedges, ground, spawn pads, exit,
## and the local player's ownership tint.
func _bake_terrain_texture() -> ImageTexture:
	var tile := BAKE_PIXELS_PER_CELL
	var image := Image.create(GRID_SIZE.x * tile, GRID_SIZE.y * tile, false, Image.FORMAT_RGBA8)
	var controlled: Dictionary = {}
	for position_index in range(_owners.size()):
		if _owners[position_index] == _local_peer_id and _local_peer_id != 0:
			controlled[position_index] = true
	var void_color := Color("0e131a")
	var rock := Color("3a3e46")
	var ground_a := Color("a9b8c1")
	var ground_b := Color("9eaeb8")
	var pad := Color("3a4552")
	var exit := Color("2c3542")
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			var rect := Rect2i(x * tile, y * tile, tile, tile)
			var terrain: int = _terrain_cells[cell]
			match terrain:
				Layout.Terrain.VOID:
					image.fill_rect(rect, void_color)
				Layout.Terrain.WALL:
					# Hidden under the cliffs; only the cliff foot shows.
					image.fill_rect(rect, rock)
				Layout.Terrain.SPAWN_PAD:
					image.fill_rect(rect, pad if (x + y) % 2 == 0 else pad.lightened(0.05))
				Layout.Terrain.EXIT_PAD:
					image.fill_rect(rect, exit if (x + y) % 2 == 0 else exit.lightened(0.05))
				_:
					var fill := ground_a.lerp(ground_b, TerrainBuilder.hash_2d(x, y))
					if _build_cells.has(cell):
						var owner: int = _build_cells[cell]
						fill = fill.lerp(LANE_COLORS[owner], 0.14 if controlled.has(owner) else 0.05)
					image.fill_rect(rect, fill)
					# Faint build grid, like WC3's placement grid.
					image.fill_rect(Rect2i(rect.position, Vector2i(tile, 1)), fill.darkened(0.08))
					image.fill_rect(Rect2i(rect.position, Vector2i(1, tile)), fill.darkened(0.08))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## One pixel per cell for the HUD minimap: cliffs, ground tinted by position
## owner colour, pads, and the abyss.
func build_minimap_image() -> Image:
	_ensure_map_data()
	var image := Image.create(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			var color := Color("06080b")
			match int(_terrain_cells[cell]):
				Layout.Terrain.WALL:
					color = Color("9aa3ad")
				Layout.Terrain.SPAWN_PAD:
					color = Color("2b3440")
				Layout.Terrain.EXIT_PAD:
					color = Color("7a2a2a")
				Layout.Terrain.OPEN:
					color = Color("4a5a66")
					if _build_cells.has(cell):
						color = color.lerp(LANE_COLORS[int(_build_cells[cell])], 0.35)
			image.set_pixel(x, y, color)
	return image


func _paint_ownership(canvas: CanvasItem, font: Font) -> void:
	if _owners.is_empty():
		return
	for position_index in range(mini(_owners.size(), _positions.size())):
		var owner := _owners[position_index]
		var is_local := owner == _local_peer_id and owner != 0
		var is_host_controlled := owner == 0 or owner == BuildPermissionPolicy.HOST_PEER_ID
		var color := LANE_COLORS[position_index]
		var label := "POSITION %d" % (position_index + 1)
		if is_local:
			label += "  ·  YOU"
		elif is_host_controlled:
			label += "  ·  HOST"
		else:
			label += "  ·  %s" % str(_owner_names.get(owner, "ALLY"))
		var label_position := project_to_screen(grid_to_world(_positions[position_index]["label_anchor"])) + Vector2(-TILE_SIZE * 0.5 + 4, 4)
		canvas.draw_rect(Rect2(label_position + Vector2(-6, -14), Vector2(label.length() * 8.2 + 12, 20)), Color(0.02, 0.04, 0.035, 0.75))
		canvas.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.3) if is_local else Color("d5e2dd"))


static func _preview_color(result: int) -> Color:
	match result:
		Placement.OK:
			return Color(0.35, 0.9, 0.68, 0.55)
		Placement.BLOCKS_ROUTE:
			return Color(0.98, 0.6, 0.2, 0.6)
		Placement.OCCUPIED, Placement.CREEP_ON_CELL:
			return Color(0.6, 0.62, 0.66, 0.55)
		Placement.UNAFFORDABLE:
			return Color(0.95, 0.85, 0.3, 0.55)
		Placement.NOT_OWNED:
			return Color(0.8, 0.45, 0.95, 0.55)
	return Color(0.95, 0.3, 0.27, 0.55)


# --- Runner callbacks ---------------------------------------------------------

func _on_runner_finished(creep_id: int) -> void:
	_invalidate_active_creeps()
	# Clients hold leaked creeps at the gate until the host confirms the leak.
	if not _is_authority():
		return
	var runner := get_creep(creep_id)
	if runner != null:
		effects.leak(runner.plane_position)
		_last_creep_positions[creep_id] = runner.plane_position
		runner.queue_free()
	creep_route_finished.emit(creep_id)


func _on_runner_killed(creep_id: int) -> void:
	_invalidate_active_creeps()
	var runner := get_creep(creep_id)
	if runner != null:
		effects.death(runner.plane_position, runner.body_color, runner.radius)
		_spawn_corpse(runner)
		_last_creep_positions[creep_id] = runner.plane_position
		_last_creep_routes[creep_id] = {
			"start_position": runner.plane_position,
			"start_stage": runner.get_stage_index(),
			"start_distance": runner.get_progress() - runner.get_stage_index() * RouteRunner.STAGE_PROGRESS_WEIGHT,
		}
		runner.queue_free()
	creep_killed.emit(creep_id)
	_last_creep_routes.erase(creep_id)


## Presentation only: the killed creep's visual falls or plays `death`, then
## sinks. Corpses never take part in combat, snapshots or reconciliation.
func _spawn_corpse(runner: RouteRunner) -> void:
	if not is_inside_tree():
		return
	var height := runner.get_visual_height()
	# detach_visual() leaves the visual's world transform in `transform`.
	var visual := runner.detach_visual()
	if visual == null:
		return
	var corpse := CorpseScene.new() as Corpse
	_corpses().add_child(corpse)
	corpse.setup(visual, visual.transform, height)


func _corpses() -> Node3D:
	var container := get_node_or_null("Corpses") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Corpses"
		add_child(container)
	return container


func get_corpse_count() -> int:
	return _corpses().get_child_count()
