class_name Projectile
extends Node3D

## Visual-only actor on every peer. The host attaches an impact callable that
## performs authoritative combat resolution when the projectile arrives.
var payload: Dictionary = {}

const FLIGHT_HEIGHT := 0.75

## Simulation position in sim pixels; the 3D transform is derived from it.
var plane_position: Vector2:
	get:
		return MapProjection.to_plane(position)
	set(value):
		position = MapProjection.to_3d(value, FLIGHT_HEIGHT)

var _target: RouteRunner
var _target_position := Vector2.ZERO
var _speed := 600.0
var _color := Color.WHITE
var _radius := 3.0
var _on_impact := Callable()
var _mesh: MeshInstance3D


func setup(start: Vector2, target: RouteRunner, speed: float, color: Color, projectile_payload: Dictionary, on_impact := Callable()) -> void:
	plane_position = start
	_target = target
	_target_position = target.plane_position if is_instance_valid(target) else start
	_speed = maxf(60.0, speed)
	_color = color
	payload = projectile_payload.duplicate()
	_radius = 4.5 if float(payload.get("splash_radius", 0.0)) > 0.0 else 3.0
	_on_impact = on_impact
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	_mesh.mesh = MeshPalette.sphere_mesh(MapProjection.units(_radius))
	_mesh.material_override = MeshPalette.solid_material(_color, true, 1.2)


func _process(delta: float) -> void:
	if is_instance_valid(_target) and not _target.is_queued_for_deletion() and _target.health > 0:
		_target_position = _target.plane_position
	var next := plane_position.move_toward(_target_position, _speed * delta)
	plane_position = next
	if next.distance_to(_target_position) <= 1.0:
		_impact()


func _impact() -> void:
	var live_target := _target if is_instance_valid(_target) and not _target.is_queued_for_deletion() and _target.health > 0 else null
	if _on_impact.is_valid():
		_on_impact.call(payload, plane_position, live_target)
	queue_free()
