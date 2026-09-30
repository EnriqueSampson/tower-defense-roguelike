class_name Minimap
extends Control

## WC3-style minimap: terrain, position tints, towers, creeps and the camera's
## view trapezoid. Click or drag to move the camera there.

const REDRAW_INTERVAL := 0.1
const TOWER_COLOR := Color("f2f2f2")
const CREEP_COLOR := Color("ff4a3d")
const VIEW_COLOR := Color("fff6d0")

var _map: WintermaulMap
var _camera: BattlefieldCamera
var _terrain: ImageTexture
var _redraw_timer := 0.0
var _dragging := false


func attach(map: WintermaulMap, camera: BattlefieldCamera) -> void:
	_map = map
	_camera = camera
	_terrain = ImageTexture.create_from_image(map.build_minimap_image())
	queue_redraw()


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _map == null or _terrain == null:
		return
	var area := _map_area()
	draw_texture_rect(_terrain, area, false)
	var to_minimap := area.size / _map.get_world_rect().size
	for tower: Tower in _map.get_node("Towers").get_children():
		var point := area.position + tower.plane_position * to_minimap
		var half := Vector2(tower.footprint) * WintermaulMap.TILE_SIZE * to_minimap * 0.5
		draw_rect(Rect2(point - half, half * 2.0).grow(0.5), TOWER_COLOR)
	for runner: RouteRunner in _map.get_active_creeps():
		if runner.is_hidden():
			continue
		draw_rect(Rect2(area.position + runner.plane_position * to_minimap - Vector2(1.5, 1.5), Vector2(3, 3)), CREEP_COLOR)
	if is_instance_valid(_camera):
		var view_size := _camera.get_viewport().get_visible_rect().size
		var corners := PackedVector2Array()
		for screen in [Vector2.ZERO, Vector2(view_size.x, 0), view_size, Vector2(0, view_size.y)]:
			corners.append(area.position + _camera.screen_to_plane(screen) * to_minimap)
		corners.append(corners[0])
		draw_polyline(corners, VIEW_COLOR, 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_jump_to(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_jump_to(event.position)
		accept_event()


func _jump_to(local_position: Vector2) -> void:
	if _map == null or not is_instance_valid(_camera):
		return
	var area := _map_area()
	var plane := (local_position - area.position) / area.size * _map.get_world_rect().size
	_camera.focus_on(plane)
	queue_redraw()


## Map drawn at the largest size that keeps its aspect, centred.
func _map_area() -> Rect2:
	var world := _map.get_world_rect().size
	var fit := minf(size.x / world.x, size.y / world.y)
	var drawn := world * fit
	return Rect2((size - drawn) * 0.5, drawn)
