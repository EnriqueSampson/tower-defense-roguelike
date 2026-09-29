class_name Tower
extends Node3D

signal fired(tower: Tower, target: RouteRunner)

const BASE_HEIGHT := 0.12
const RANGE_RING_HEIGHT := 0.02

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
var _turret_rest_height := 0.0


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


func attack_range() -> float:
	return float(stats.get("range", definition.attack_range if definition else 100.0))


func damage() -> int:
	return int(stats.get("damage", 1))


func play_fire_animation() -> void:
	_recoil = 0.12
	_update_turret_height()


func _process(delta: float) -> void:
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta)
		_update_turret_height()
	if not _is_authority():
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _cooldown_remaining > 0.0 or not is_instance_valid(_map):
		return
	var target := TowerTargeting.select(_map.get_active_creeps(), plane_position, attack_range(), targeting)
	if target == null:
		return
	_cooldown_remaining = float(stats.get("cooldown", 1.0))
	play_fire_animation()
	fired.emit(self, target)


func _is_authority() -> bool:
	if not is_inside_tree():
		return true
	var api := get_multiplayer()
	return api == null or not api.has_multiplayer_peer() or api.is_server()


# --- Visuals ------------------------------------------------------------------

func _refresh_visual() -> void:
	if not is_inside_tree():
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


func _update_turret_height() -> void:
	if _turret:
		_turret.position.y = _turret_rest_height - _recoil * MapProjection.units(20.0)


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
