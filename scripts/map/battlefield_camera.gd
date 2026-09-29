class_name BattlefieldCamera
extends Camera3D

## Fixed three-quarter orthographic view of the battlefield. It never rotates;
## players zoom toward the cursor and pan while zoomed in. Zoom 1.0 frames the
## whole map, so panning is inert until the player zooms in.

signal view_changed

const PITCH_DEGREES := 55.0
const CAMERA_DISTANCE := 120.0
const PAN_SPEED := 720.0
const ZOOM_STEP := 0.1
const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.0
const FRAME_INSET := 0.96

@export var edge_pan_enabled := true
@export_range(1.0, 64.0, 1.0) var edge_border_thickness := 15.0

## 1.0 shows the whole map; larger values zoom in.
var zoom_level := MIN_ZOOM

var _dragging := false
var _map: WintermaulMap
var _edge_pan_area: Control
var _world_rect := Rect2()
## Sim-pixel point on the ground plane at the screen centre.
var _focus := Vector2.ZERO
## Orthographic size that frames the whole map.
var _fit_size := 80.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 1.0
	far = CAMERA_DISTANCE * 3.0
	rotation = Vector3(deg_to_rad(-PITCH_DEGREES), 0.0, 0.0)
	_map = get_parent().get_node_or_null("WintermaulMap") as WintermaulMap
	if _map != null:
		_world_rect = _map.get_world_rect()
		_map.attach_camera(self)
	else:
		_world_rect = Rect2(Vector2.ZERO, Vector2(ClassicWintermaulLayout.GRID_SIZE) * WintermaulMap.TILE_SIZE)
	_focus = _world_rect.get_center()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_fit_size = _compute_fit_size()
	_apply_view()


func set_edge_pan_area(area: Control) -> void:
	_edge_pan_area = area


# --- Projection helpers -------------------------------------------------------

## Ground-plane point (sim pixels) under a viewport pixel.
func screen_to_plane(screen_position: Vector2) -> Vector2:
	var origin := project_ray_origin(screen_position)
	var direction := project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return _focus
	var distance := -origin.y / direction.y
	return MapProjection.to_plane(origin + direction * distance)


func plane_to_screen(plane: Vector2, height := 0.0) -> Vector2:
	return unproject_position(MapProjection.to_3d(plane, height))


## Screen pixels per sim pixel along the map's x axis.
func get_screen_scale() -> float:
	var visible := get_visible_plane_size()
	return _viewport_size().x / visible.x if visible.x > 0.0 else 1.0


## Ground-plane extent (sim pixels) currently on screen.
func get_visible_plane_size() -> Vector2:
	var viewport_size := _viewport_size()
	var aspect := viewport_size.x / viewport_size.y if viewport_size.y > 0.0 else 1.0
	return Vector2(size * aspect, size / sin(deg_to_rad(PITCH_DEGREES))) * WintermaulMap.TILE_SIZE


func get_visible_plane_rect() -> Rect2:
	var visible := get_visible_plane_size()
	return Rect2(_focus - visible * 0.5, visible)


# --- Zoom and pan -------------------------------------------------------------

## Zooms while keeping the ground point under anchor_screen fixed.
func set_zoom_level(value: float, anchor_screen := Vector2(-1.0, -1.0)) -> void:
	var anchored := anchor_screen.x >= 0.0 and anchor_screen.y >= 0.0
	var anchor_plane := screen_to_plane(anchor_screen) if anchored else Vector2.ZERO
	zoom_level = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_apply_view()
	if anchored:
		_focus += anchor_plane - screen_to_plane(anchor_screen)
		_apply_view()


func get_edge_direction(mouse_position: Vector2, area_rect: Rect2) -> Vector2:
	if not area_rect.has_point(mouse_position):
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if mouse_position.x <= area_rect.position.x + edge_border_thickness:
		direction.x = -1.0
	elif mouse_position.x >= area_rect.end.x - edge_border_thickness:
		direction.x = 1.0
	if mouse_position.y <= area_rect.position.y + edge_border_thickness:
		direction.y = -1.0
	elif mouse_position.y >= area_rect.end.y - edge_border_thickness:
		direction.y = 1.0
	return direction.normalized()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if _can_edge_pan():
		direction += get_edge_direction(get_window().get_mouse_position(), _edge_pan_area.get_global_rect())
	if direction != Vector2.ZERO:
		_move_camera(direction, delta)


func _can_edge_pan() -> bool:
	return (
		edge_pan_enabled
		and is_instance_valid(_edge_pan_area)
		and _edge_pan_area.is_visible_in_tree()
		and get_window().has_focus()
	)


func _move_camera(direction: Vector2, delta: float) -> void:
	_focus += direction.normalized() * PAN_SPEED * delta / zoom_level
	_apply_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_level(zoom_level + ZOOM_STEP, event.position)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_level(zoom_level - ZOOM_STEP, event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var plane_per_pixel := get_visible_plane_size() / _viewport_size()
		_focus -= event.relative * plane_per_pixel
		_apply_view()
		get_viewport().set_input_as_handled()


# --- Internals ----------------------------------------------------------------

func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(1100, 824)
	return viewport_size


func _compute_fit_size() -> float:
	var viewport_size := _viewport_size()
	var aspect := viewport_size.x / viewport_size.y
	var map_units := _world_rect.size * MapProjection.UNITS_PER_PIXEL
	var fit_height := map_units.y * sin(deg_to_rad(PITCH_DEGREES))
	var fit_width := map_units.x / aspect
	return maxf(fit_height, fit_width) / FRAME_INSET


func _apply_view() -> void:
	size = _fit_size / zoom_level
	_clamp_focus_to_world()
	var pitch := deg_to_rad(PITCH_DEGREES)
	position = MapProjection.to_3d(_focus) + Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	view_changed.emit()


func _clamp_focus_to_world() -> void:
	if _world_rect.size == Vector2.ZERO:
		return
	var visible_half := get_visible_plane_size() * 0.5
	var world_half := _world_rect.size * 0.5
	var center := _world_rect.get_center()
	if visible_half.x >= world_half.x:
		_focus.x = center.x
	else:
		_focus.x = clampf(_focus.x, _world_rect.position.x + visible_half.x, _world_rect.end.x - visible_half.x)
	if visible_half.y >= world_half.y:
		_focus.y = center.y
	else:
		_focus.y = clampf(_focus.y, _world_rect.position.y + visible_half.y, _world_rect.end.y - visible_half.y)


func _on_viewport_resized() -> void:
	_fit_size = _compute_fit_size()
	_apply_view()
