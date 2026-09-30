class_name RouteRunner
extends Node3D

signal finished(creep_id: int)
signal killed(creep_id: int)
signal damaged(creep_id: int, amount: int)

const STAGE_PROGRESS_WEIGHT := 1000000.0
const SLOW_TINT := Color(0.62, 0.85, 1.0)

## Simulation position in sim pixels; the 3D transform is derived from it.
var plane_position: Vector2:
	get:
		return MapProjection.to_plane(position)
	set(value):
		position = MapProjection.to_3d(value)

var creep_id := 0
var lane_id := 0
var health := 1
var max_health := 1
var definition_id := ""
var armor := 0
var regen_per_second := 0.0
var slow_immune := false
var is_boss := false
var radius := 6.0
var body_color := Color.WHITE
var lane_color := Color.WHITE
## Run-wide creep speed modifier (tradeoff upgrades).
var speed_multiplier := 1.0

var _points := PackedVector2Array()
var _stage_targets: Array[Vector2i] = []
var _stage_index := 0
var _segment_index := 0
var _speed_pixels := 80.0
var _path_revision := 0
var _map: WintermaulMap
var _slow_factor := 0.0
var _slow_remaining := 0.0
var _flash_remaining := 0.0
var _regen_accumulator := 0.0
var _distance_travelled := 0.0
var _finished := false
var _body: MeshInstance3D
var _shadow: MeshInstance3D
var _visual_state := -1
## Authored model (CreepDefinition.visual_scene); replaces _body when set.
var _visual_scene: PackedScene
var _model: Node3D
var _model_height := 0.0


func _ready() -> void:
	if _map != null:
		_refresh_visual()


func setup(
	id: int,
	lane: int,
	start_cell: Vector2i,
	stage_targets: Array[Vector2i],
	speed_pixels: float,
	color: Color,
	starting_health: int,
	path_map: WintermaulMap,
	options := {}
) -> void:
	creep_id = id
	lane_id = lane
	health = starting_health
	max_health = starting_health
	_stage_targets = stage_targets.duplicate()
	_speed_pixels = speed_pixels
	lane_color = color
	body_color = options.get("color", color)
	definition_id = str(options.get("definition_id", ""))
	armor = int(options.get("armor", 0))
	regen_per_second = float(options.get("regen_per_second", 0.0))
	slow_immune = bool(options.get("slow_immune", false))
	is_boss = bool(options.get("is_boss", false))
	radius = float(options.get("radius", 6.0))
	speed_multiplier = float(options.get("speed_multiplier", 1.0))
	_visual_scene = options.get("visual_scene") as PackedScene
	_map = path_map
	_path_revision = _map.get_grid_revision()
	plane_position = _map.grid_to_world(start_cell)
	_load_current_stage(start_cell)
	_visual_state = -1
	_refresh_visual()


## Applies damage after armor. Returns the health actually removed.
func take_damage(amount: int, armor_pierce := 0) -> int:
	if amount <= 0 or health <= 0:
		return 0
	var effective_armor := maxi(0, armor - armor_pierce)
	var applied := maxi(1, amount - effective_armor)
	applied = mini(applied, health)
	health -= applied
	_flash_remaining = 0.12
	damaged.emit(creep_id, applied)
	_refresh_visual()
	if health == 0:
		killed.emit(creep_id)
	return applied


func apply_slow(factor: float, duration: float) -> bool:
	if slow_immune or factor <= 0.0 or duration <= 0.0 or health <= 0:
		return false
	# Stronger slows replace weaker ones; equal slows refresh the timer.
	if factor >= _slow_factor:
		_slow_factor = clampf(factor, 0.0, 0.9)
		_slow_remaining = duration
	else:
		_slow_remaining = maxf(_slow_remaining, duration * 0.5)
	_refresh_visual()
	return true


func current_speed() -> float:
	var slow := _slow_factor if _slow_remaining > 0.0 else 0.0
	return _speed_pixels * speed_multiplier * (1.0 - slow)


func is_slowed() -> bool:
	return _slow_remaining > 0.0 and _slow_factor > 0.0


func get_slow_remaining() -> float:
	return _slow_remaining


## Higher means further along the full relay route.
func get_progress() -> float:
	return float(_stage_index) * STAGE_PROGRESS_WEIGHT + _distance_travelled


func has_finished() -> bool:
	return _finished


func get_stage_index() -> int:
	return _stage_index


func get_current_target() -> Vector2i:
	return _stage_targets[_stage_index] if _stage_index < _stage_targets.size() else Vector2i(-1, -1)


## Client reconciliation entry point: adopt authoritative health, stage, and
## position. Small drift is corrected smoothly; large drift snaps and repaths.
func sync_authoritative(authoritative_health: int, stage_index: int, world_position: Vector2, slow_remaining: float) -> void:
	if authoritative_health != health:
		if authoritative_health < health:
			_flash_remaining = 0.12
		health = clampi(authoritative_health, 0, max_health)
	if slow_remaining > 0.0 and _slow_factor <= 0.0:
		_slow_factor = 0.3
	_slow_remaining = slow_remaining
	var drift := plane_position.distance_to(world_position)
	var snap_distance := WintermaulMap.TILE_SIZE * 1.5
	if stage_index != _stage_index or drift > snap_distance:
		_stage_index = clampi(stage_index, 0, maxi(0, _stage_targets.size() - 1))
		plane_position = world_position
		_load_current_stage(_map.world_to_grid(plane_position))
	elif drift > 1.0:
		plane_position = plane_position.lerp(world_position, 0.35)
	_refresh_visual()


func _process(delta: float) -> void:
	if health <= 0 or _finished:
		return
	_tick_status(delta)
	_repath_if_needed()
	if _points.size() < 2 or _segment_index >= _points.size() - 1:
		_advance_stage()
		return

	var target := _points[_segment_index + 1]
	var before := plane_position
	var after := before.move_toward(target, current_speed() * delta)
	plane_position = after
	_face_direction(after - before)
	_distance_travelled += before.distance_to(after)
	if after.is_equal_approx(target):
		_segment_index += 1
		if _segment_index >= _points.size() - 1:
			_advance_stage()


func _tick_status(delta: float) -> void:
	var needs_redraw := false
	if _slow_remaining > 0.0:
		_slow_remaining = maxf(0.0, _slow_remaining - delta)
		if _slow_remaining == 0.0:
			_slow_factor = 0.0
			needs_redraw = true
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		needs_redraw = true
	if regen_per_second > 0.0 and health < max_health and _is_authority():
		_regen_accumulator += regen_per_second * delta
		if _regen_accumulator >= 1.0:
			var restored := int(_regen_accumulator)
			_regen_accumulator -= restored
			health = mini(max_health, health + restored)
	if needs_redraw:
		_refresh_visual()


func _is_authority() -> bool:
	if not is_inside_tree():
		return true
	var api := get_multiplayer()
	return api == null or not api.has_multiplayer_peer() or api.is_server()


func _repath_if_needed() -> void:
	if not is_instance_valid(_map) or _path_revision == _map.get_grid_revision():
		return
	var path := _map.get_world_path(_map.world_to_grid(plane_position), get_current_target())
	if path.is_empty():
		return
	var rerouted_path := PackedVector2Array([plane_position])
	var first_path_index := 1 if path.size() > 1 else 0
	for point_index in range(first_path_index, path.size()):
		rerouted_path.append(path[point_index])
	_points = rerouted_path
	_segment_index = 0
	_path_revision = _map.get_grid_revision()


func _advance_stage() -> void:
	if _stage_index >= _stage_targets.size() - 1:
		if not _finished:
			_finished = true
			finished.emit(creep_id)
		return
	_stage_index += 1
	_load_current_stage(_map.world_to_grid(plane_position))


func _load_current_stage(from_cell: Vector2i) -> void:
	_points = _map.get_world_path(from_cell, get_current_target())
	_segment_index = 0
	_path_revision = _map.get_grid_revision()


# --- Visuals ------------------------------------------------------------------

## Height above the ground where the health bar should be anchored.
func get_visual_height() -> float:
	if _model != null:
		return _model_height + MapProjection.units(4.0)
	return MapProjection.units(radius * 2.0 + (6.0 if is_boss else 2.0))


## Models face +Z; yaw toward the sim-space movement direction.
func _face_direction(step: Vector2) -> void:
	if _model != null and step.length_squared() > 0.0001:
		_model.rotation.y = atan2(step.x, step.y)


func _refresh_visual() -> void:
	if not is_inside_tree():
		return
	if _shadow == null:
		_shadow = MeshInstance3D.new()
		_shadow.mesh = MeshPalette.unit_quad()
		_shadow.material_override = MeshPalette.disc_material(Color(0, 0, 0, 0.35))
		_shadow.position.y = 0.01
		add_child(_shadow)
		var shadow_radius := MapProjection.units(radius * 1.15)
		_shadow.scale = Vector3(shadow_radius, 1.0, shadow_radius)
	if _visual_scene != null and _model == null:
		_model = ActorModel.instantiate(_visual_scene)
		if _model != null:
			add_child(_model)
			# Creeps are many and small: the blob shadow disc stands in for a
			# real shadow, which would add a shadow-pass draw call per creep.
			ActorModel.set_cast_shadows(_model, false)
			_model_height = ActorModel.height(_model)
			ActorModel.play(_model, &"walk", true)
	if _model != null:
		_refresh_model_tint()
		return
	if _body == null:
		_body = MeshInstance3D.new()
		add_child(_body)
	var key := "creep:%s:%s:%s:%s:%s" % [definition_id, body_color.to_html(false), lane_color.to_html(false), armor > 0, is_boss]
	if _body.mesh == null or _body.mesh.resource_name != key:
		_body.mesh = _body_mesh(key)
	var state := (1 if is_slowed() else 0) + (2 if _flash_remaining > 0.0 else 0)
	if state == _visual_state:
		return
	_visual_state = state
	match state:
		0:
			_body.material_override = null
		1:
			_body.material_override = MeshPalette.tinted_vertex_material(SLOW_TINT, 0.0)
		2:
			_body.material_override = MeshPalette.tinted_vertex_material(Color.WHITE, 1.6)
		_:
			_body.material_override = MeshPalette.tinted_vertex_material(SLOW_TINT, 1.6)


func _refresh_model_tint() -> void:
	var state := (1 if is_slowed() else 0) + (2 if _flash_remaining > 0.0 else 0)
	if state == _visual_state:
		return
	_visual_state = state
	match state:
		0:
			ActorModel.set_tint(_model, Color(0, 0, 0, 0))
		1:
			ActorModel.set_tint(_model, Color(SLOW_TINT.r * 0.5, SLOW_TINT.g * 0.5, SLOW_TINT.b * 0.6, 0.5))
		_:
			ActorModel.set_tint(_model, Color(1.0, 1.0, 1.0, 0.6))


func _body_mesh(key: String) -> ArrayMesh:
	var mesh := MeshBuilder.cached(key)
	if mesh:
		return mesh
	var r := MapProjection.units(radius)
	var builder := MeshBuilder.new()
	builder.add_sphere(r, Vector3(0.0, r, 0.0), body_color, 10)
	builder.add_cylinder(r * 1.08, r * 0.3, Vector3(0.0, r * 0.85, 0.0), lane_color, 12)
	if is_boss:
		builder.add_cylinder(r * 1.35, r * 0.18, Vector3(0.0, r * 0.25, 0.0), Color("ffd36a"), 16)
	if armor > 0:
		builder.add_box(Vector3(r * 0.7, r * 0.5, r * 0.3), Vector3(0.0, r * 0.95, r * 0.95), Color(0.15, 0.17, 0.22))
	mesh = builder.commit()
	mesh.resource_name = key
	return MeshBuilder.store(key, mesh)
