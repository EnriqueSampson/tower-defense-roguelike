class_name Tower
extends Node3D

signal fired(tower: Tower, target: RouteRunner)

const BASE_HEIGHT := 0.12
## Idle towers look for a new target this often instead of every frame;
## each tower is offset so a full map of idle towers does not scan at once.
const RETARGET_INTERVAL := 0.15
const RANGE_RING_HEIGHT := 0.02
const SELECTION_COLOR := Color("5ce36b")

## Simulation position in sim pixels; the 3D transform is derived from it.
var plane_position: Vector2:
	get:
		return MapProjection.to_plane(position)
	set(value):
		position = MapProjection.to_3d(value)

var tower_id := 0
## Footprint anchor (top-left cell); the tower is centered on its footprint.
var grid_cell := Vector2i.ZERO
var footprint := Vector2i.ONE
var definition: TowerDefinition
var tier := 0
var targeting := TowerTargeting.Mode.FIRST
var position_index := -1
## Effective stats after tiers and run modifiers: damage, range, cooldown,
## splash_radius, slow_factor, slow_duration, armor_pierce, projectile_speed.
var stats: Dictionary = {}
var selected := false

var _cooldown_remaining := 0.0
var _recoil := 0.0
var _map: WintermaulMap
var _body: MeshInstance3D
var _turret: MeshInstance3D
var _range_ring: MeshInstance3D
var _selection_circle: MeshInstance3D
var _turret_rest_height := 0.0
## Authored model (definition.visual_scene); replaces _body/_turret when set.
var _model: Node3D
var _model_scene: PackedScene
var _model_turret: Node3D
## Construction / timed-upgrade progress mirrored from the tower record and
## counted down locally between snapshots.
var _build_remaining := 0.0
var _build_total := 0.0
var _upgrade_remaining := 0.0
var _upgrade_total := 0.0


func _ready() -> void:
	if definition != null:
		_refresh_visual()


func setup(id: int, cell: Vector2i, tower_definition: TowerDefinition, tower_tier: int, targeting_mode: int, tower_stats: Dictionary, owner_position := -1) -> void:
	tower_id = id
	grid_cell = cell
	definition = tower_definition
	footprint = tower_definition.footprint if tower_definition != null else Vector2i.ONE
	position_index = owner_position
	_map = get_parent().get_parent() as WintermaulMap
	apply_stats(tower_tier, targeting_mode, tower_stats)


func apply_stats(tower_tier: int, targeting_mode: int, tower_stats: Dictionary) -> void:
	tier = tower_tier
	if TowerTargeting.is_valid_mode(targeting_mode):
		targeting = targeting_mode
	stats = tower_stats.duplicate()
	_refresh_visual()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_refresh_range_ring()
	_refresh_selection_circle()


## Adopts build_remaining/build_total and upgrade_remaining/upgrade_total.
func apply_progress(record: Dictionary) -> void:
	_build_remaining = float(record.get("build_remaining", 0.0))
	_build_total = float(record.get("build_total", 0.0))
	_upgrade_remaining = float(record.get("upgrade_remaining", 0.0))
	_upgrade_total = float(record.get("upgrade_total", 0.0))
	_apply_construction_offset()


func is_under_construction() -> bool:
	return _build_remaining > 0.0


func is_upgrading() -> bool:
	return _upgrade_remaining > 0.0


## 0..1 while building or upgrading, -1 otherwise.
func progress_ratio() -> float:
	if _build_remaining > 0.0 and _build_total > 0.0:
		return 1.0 - _build_remaining / _build_total
	if _upgrade_remaining > 0.0 and _upgrade_total > 0.0:
		return 1.0 - _upgrade_remaining / _upgrade_total
	return -1.0


func attack_range() -> float:
	return float(stats.get("range", definition.attack_range if definition else 100.0))


func detection_range() -> float:
	return float(stats.get("detection_range", 0.0))


func damage() -> int:
	return int(stats.get("damage", 1))


func play_fire_animation() -> void:
	if _model != null:
		ActorModel.play(_model, &"attack", false, &"idle")
		return
	_recoil = 0.12
	_update_turret_height()


func _process(delta: float) -> void:
	if _build_remaining > 0.0:
		_build_remaining = maxf(0.0, _build_remaining - delta)
		_apply_construction_offset()
		return
	if _upgrade_remaining > 0.0:
		_upgrade_remaining = maxf(0.0, _upgrade_remaining - delta)
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta)
		_update_turret_height()
	if not _is_authority():
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _cooldown_remaining > 0.0 or not is_instance_valid(_map):
		return
	var target := TowerTargeting.select(_map.get_active_creeps(), plane_position, attack_range(), targeting,
		bool(stats.get("targets_ground", true)), bool(stats.get("targets_air", true)), bool(stats.get("magic", false)))
	if target == null:
		_cooldown_remaining = RETARGET_INTERVAL * (0.75 + 0.5 * fposmod(tower_id * 0.618, 1.0))
		return
	_cooldown_remaining = float(stats.get("cooldown", 1.0))
	face_target(target.plane_position)
	play_fire_animation()
	fired.emit(self, target)


## Turns an authored model's "Turret" node toward a sim-space point.
func face_target(target_plane: Vector2) -> void:
	if _model_turret == null:
		return
	var direction := target_plane - plane_position
	if direction.length_squared() < 0.01:
		return
	# Models face +Z; yaw so +Z points along the sim direction (x -> X, y -> Z).
	_model_turret.rotation.y = atan2(direction.x, direction.y)


func _is_authority() -> bool:
	if not is_inside_tree():
		return true
	var api := get_multiplayer()
	return api == null or not api.has_multiplayer_peer() or api.is_server()


# --- Visuals ------------------------------------------------------------------

func _refresh_visual() -> void:
	if not is_inside_tree():
		return
	if _refresh_model():
		_refresh_range_ring()
		return
	var primary := definition.primary_color if definition else Color("315f58")
	var accent := definition.accent_color if definition else Color("e4b94f")
	var definition_id := definition.id if definition else "default"
	var body_height := MapProjection.units((12.0 + tier * 3.0) * _footprint_scale())
	if _body == null:
		_body = MeshInstance3D.new()
		add_child(_body)
	_body.mesh = _body_mesh(definition_id, primary, body_height)
	if _turret == null:
		_turret = MeshInstance3D.new()
		add_child(_turret)
	var splash := definition != null and definition.splash_radius > 0.0
	var slow := definition != null and definition.slow_factor > 0.0
	_turret.mesh = _turret_mesh(definition_id, accent, splash, slow)
	_turret_rest_height = BASE_HEIGHT + body_height + MapProjection.units(4.0 * _footprint_scale())
	_update_turret_height()
	_refresh_range_ring()


## Swaps in the authored model for the current tier. Returns false (and
## removes any model) when the procedural mesh should be used instead.
func _refresh_model() -> bool:
	var scene := definition.visual_scene_for_tier(tier) if definition else null
	if scene == null:
		if _model != null:
			_model.queue_free()
			_model = null
			_model_scene = null
			_model_turret = null
		return false
	if scene != _model_scene:
		var previous_yaw := _model_turret.rotation.y if _model_turret != null else 0.0
		if _model != null:
			_model.queue_free()
		_model = ActorModel.instantiate(scene)
		if _model == null:
			_model_scene = null
			return false
		_model_scene = scene
		add_child(_model)
		_model_turret = _model.find_child("Turret", true, false) as Node3D
		if _model_turret != null:
			_model_turret.rotation.y = previous_yaw
		ActorModel.play(_model, &"idle", true)
	for procedural in [_body, _turret]:
		if procedural != null:
			procedural.queue_free()
	_body = null
	_turret = null
	return true


## Under construction the tower rises out of the ground as progress grows.
func _apply_construction_offset() -> void:
	var sink := 0.0
	if _build_remaining > 0.0 and _build_total > 0.0:
		sink = -(_build_remaining / _build_total) * 1.2 * _footprint_scale() * 0.7
	for visual in [_model, _body, _turret]:
		if visual != null:
			visual.position.y = sink + (_turret_rest_height if visual == _turret else 0.0)


func _update_turret_height() -> void:
	if _turret:
		_turret.position.y = _turret_rest_height - _recoil * MapProjection.units(20.0)


## WC3-style green circle around the selected tower's footprint.
func _refresh_selection_circle() -> void:
	if not selected:
		if _selection_circle:
			_selection_circle.visible = false
		return
	if _selection_circle == null:
		_selection_circle = MeshInstance3D.new()
		_selection_circle.mesh = MeshPalette.unit_quad()
		_selection_circle.material_override = MeshPalette.new_ring_material(SELECTION_COLOR, 0.86, 0.12)
		_selection_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_selection_circle.position.y = RANGE_RING_HEIGHT * 1.5
		add_child(_selection_circle)
	var radius := maxf(footprint.x, footprint.y) * 0.5 * 1.18
	_selection_circle.scale = Vector3(radius, 1.0, radius)
	_selection_circle.visible = true


func _refresh_range_ring() -> void:
	if not selected:
		if _range_ring:
			_range_ring.visible = false
		return
	var accent := definition.accent_color if definition else Color("e4b94f")
	var radius := MapProjection.units(attack_range())
	if _range_ring == null:
		_range_ring = MeshInstance3D.new()
		_range_ring.mesh = MeshPalette.unit_quad()
		_range_ring.material_override = MeshPalette.new_ring_material(accent, 0.9, 0.1)
		_range_ring.position.y = RANGE_RING_HEIGHT
		add_child(_range_ring)
	var material := _range_ring.material_override as ShaderMaterial
	material.set_shader_parameter("color", Color(accent.r, accent.g, accent.b, 0.7))
	material.set_shader_parameter("inner", 1.0 - MapProjection.units(1.5) / maxf(radius, 0.01))
	_range_ring.scale = Vector3(radius, 1.0, radius)
	_range_ring.visible = true


## Raised stone base, colored body, and golden tier pips baked into one mesh.
func _body_mesh(definition_id: String, primary: Color, body_height: float) -> ArrayMesh:
	var size := _footprint_scale()
	var key := "tower:%s:%d:%d" % [definition_id, tier, size]
	var mesh := MeshBuilder.cached(key)
	if mesh:
		return mesh
	var builder := MeshBuilder.new()
	var base_size := MapProjection.units(WintermaulMap.TILE_SIZE * (size - 0.16))
	builder.add_box(Vector3(base_size, BASE_HEIGHT, base_size), Vector3(0.0, BASE_HEIGHT * 0.5, 0.0), Color(0.32, 0.36, 0.33), Color(0.12, 0.14, 0.13))
	var body_width := MapProjection.units(14.0 * size)
	builder.add_box(Vector3(body_width, body_height, body_width), Vector3(0.0, BASE_HEIGHT + body_height * 0.5, 0.0), primary.lightened(0.2), primary)
	var pip_radius := MapProjection.units(1.6)
	for pip in range(tier):
		var pip_x := MapProjection.units((-5.0 + pip * 5.0) * size)
		builder.add_sphere(pip_radius, Vector3(pip_x, BASE_HEIGHT + pip_radius, base_size * 0.5 - pip_radius), Color("fff0ae"), 6)
	return MeshBuilder.store(key, builder.commit())


func _turret_mesh(definition_id: String, accent: Color, splash: bool, slow: bool) -> ArrayMesh:
	var size := _footprint_scale()
	var key := "turret:%s:%d" % [definition_id, size]
	var mesh := MeshBuilder.cached(key)
	if mesh:
		return mesh
	var builder := MeshBuilder.new()
	var turret_radius := MapProjection.units(5.5 * size)
	builder.add_sphere(turret_radius, Vector3.ZERO, accent, 12)
	if splash:
		builder.add_box(Vector3(MapProjection.units(4.0 * size), MapProjection.units(6.0 * size), MapProjection.units(4.0 * size)), Vector3(0.0, turret_radius + MapProjection.units(2.0 * size), 0.0), accent.darkened(0.2))
	if slow:
		builder.add_cylinder(MapProjection.units(7.5 * size), MapProjection.units(1.0 * size), Vector3.ZERO, accent.lightened(0.2), 12)
	return MeshBuilder.store(key, builder.commit())


## Procedural meshes scale with the smaller footprint side (1 for 1x1, 2 for 2x2).
func _footprint_scale() -> int:
	return maxi(mini(footprint.x, footprint.y), 1)
