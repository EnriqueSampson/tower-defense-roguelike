class_name BattlefieldCamera
extends Camera3D

## Fixed WC3-style perspective view of the battlefield. It never rotates;
## zooming dollies the camera along its tilt toward the cursor. Zoom 1.0 frames
## the whole map, so panning is inert until the player zooms in.

signal view_changed

## Close to Warcraft III's default camera (angle of attack 304°, i.e. 56° down).
const PITCH_DEGREES := 56.0
const FOV_DEGREES := 50.0
## Closest dolly distance in units (tiles); about WC3's default view.
const CLOSE_DISTANCE := 12.0
## Screens per second of pan at any zoom.
const PAN_SCREENS_PER_SECOND := 0.9
const ZOOM_FACTOR := 1.15
const MIN_ZOOM := 1.0
const MAX_ZOOM := 8.0
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
## Dolly distance (units) and focus that frame the whole map at zoom 1.0.
var _fit_distance := 100.0
var _fit_focus := Vector2.ZERO


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	keep_aspect = KEEP_HEIGHT
	fov = FOV_DEGREES
	near = 0.1
	rotation = Vector3(deg_to_rad(-PITCH_DEGREES), 0.0, 0.0)
	_map = get_parent().get_node_or_null("WintermaulMap") as WintermaulMap
	if _map != null:
		_world_rect = _map.get_world_rect()
		_map.attach_camera(self)
	else:
		_world_rect = Rect2(Vector2.ZERO, Vector2(ClassicWintermaulLayout.GRID_SIZE) * WintermaulMap.TILE_SIZE)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_compute_fit()
	_focus = _fit_focus
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


## Screen pixels per sim pixel along the map's x axis, measured at the focus
## (perspective makes nearer ground larger and farther ground smaller).
func get_screen_scale() -> float:
	var step := WintermaulMap.TILE_SIZE
	var measured := plane_to_screen(_focus + Vector2(step, 0.0)).distance_to(plane_to_screen(_focus))
	return measured / step if measured > 0.0 else 1.0


## Ground-plane extent (sim pixels) of the visible area's bounding box.
func get_visible_plane_size() -> Vector2:
	return get_visible_plane_rect().size


## Bounding box of the ground visible on screen (a trapezoid in perspective).
func get_visible_plane_rect() -> Rect2:
	var offset := _visible_offset_rect(_distance())
	return Rect2(_focus + offset.position, offset.size)


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
	_focus += direction.normalized() * get_visible_plane_size().x * PAN_SCREENS_PER_SECOND * delta
	_apply_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_level(zoom_level * ZOOM_FACTOR, event.position)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_level(zoom_level / ZOOM_FACTOR, event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		# Screen-to-ground scale at the focus; exact enough for a drag and safe
		# for any pointer delta (rays never leave the ground plane).
		_focus -= event.relative / get_screen_scale()
		_apply_view()
		get_viewport().set_input_as_handled()


# --- Internals ----------------------------------------------------------------

func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(1100, 824)
	return viewport_size


func _distance() -> float:
	return _fit_distance / zoom_level


## Unit vector from the focus point toward the camera.
func _back_vector() -> Vector3:
	var pitch := deg_to_rad(PITCH_DEGREES)
	return Vector3(0.0, sin(pitch), cos(pitch))


## Visible ground bounding box, relative to the focus, for a dolly distance.
## Depends only on distance, pitch, fov and aspect, never on the focus.
func _visible_offset_rect(distance: float) -> Rect2:
	var corners := _ground_corners(distance)
	var rect := Rect2(corners[0], Vector2.ZERO)
	for point in corners:
		rect = rect.expand(point)
	return rect


## Area that must stay on the map, relative to the focus: the near (bottom)
## screen edge horizontally and the full depth vertically. The wider far
## corners may show a little void past the map edge, as in WC3.
func _clamp_offset_rect(distance: float) -> Rect2:
	var corners := _ground_corners(distance)
	var bounds := _visible_offset_rect(distance)
	return Rect2(Vector2(corners[2].x, bounds.position.y), Vector2(corners[3].x - corners[2].x, bounds.size.y))


## Ground hits (sim pixels, relative to the focus) of the screen corners:
## top-left, top-right, bottom-left, bottom-right.
func _ground_corners(distance: float) -> Array[Vector2]:
	var viewport_size := _viewport_size()
	var half_v := tan(deg_to_rad(FOV_DEGREES) * 0.5)
	var half_h := half_v * viewport_size.x / viewport_size.y
	var pitch := deg_to_rad(PITCH_DEGREES)
	var forward := Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var origin := _back_vector() * distance
	var points: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var ray := forward + Vector3.RIGHT * corner.x * half_h + up * -corner.y * half_v
		# Rays above the horizon would never land; clamp them just below it.
		ray.y = minf(ray.y, -0.02)
		var hit := origin + ray * (-origin.y / ray.y)
		points.append(Vector2(hit.x, hit.z) * WintermaulMap.TILE_SIZE)
	return points


## Finds the smallest distance at which the whole map fits inside the visible
## ground trapezoid (with an inset), top-aligned and centred horizontally.
func _compute_fit() -> void:
	var margin := _world_rect.size * (1.0 / FRAME_INSET - 1.0) * 0.5
	var target := _world_rect.grow_individual(margin.x, margin.y, margin.x, margin.y)
	var low := 1.0
	var high := 4000.0
	for _step in range(40):
		var mid := (low + high) * 0.5
		if _fits(mid, target):
			high = mid
		else:
			low = mid
	_fit_distance = maxf(high, CLOSE_DISTANCE)
	var offset := _visible_offset_rect(_fit_distance)
	_fit_focus = Vector2(_world_rect.get_center().x, target.position.y - offset.position.y)


## True when `target`, top-aligned to the view, fits inside the trapezoid.
## The trapezoid narrows toward the camera, so the target's bottom row is
## the binding width.
func _fits(distance: float, target: Rect2) -> bool:
	var corners := _ground_corners(distance)
	var depth := corners[2].y - corners[0].y
	if depth < target.size.y:
		return false
	var t := target.size.y / depth
	var width_at_bottom := lerpf(corners[1].x - corners[0].x, corners[3].x - corners[2].x, t)
	return width_at_bottom >= target.size.x


func _apply_view() -> void:
	var distance := _distance()
	_clamp_focus_to_world(distance)
	far = maxf(distance * 4.0, 50.0)
	position = MapProjection.to_3d(_focus) + _back_vector() * distance
	view_changed.emit()


## Zoom 1.0 is locked to the whole-map framing. Zoomed in, the clamp area
## (see _clamp_offset_rect) stays on the map; an axis that cannot fit centres
## horizontally or top-aligns vertically, matching the zoom 1.0 framing.
func _clamp_focus_to_world(distance: float) -> void:
	if _world_rect.size == Vector2.ZERO:
		return
	if zoom_level <= MIN_ZOOM:
		_focus = _fit_focus
		return
	var offset := _clamp_offset_rect(distance)
	if offset.size.x >= _world_rect.size.x:
		_focus.x = _world_rect.get_center().x
	else:
		_focus.x = clampf(_focus.x, _world_rect.position.x - offset.position.x, _world_rect.end.x - offset.end.x)
	if offset.size.y >= _world_rect.size.y:
		_focus.y = _world_rect.position.y - offset.position.y
	else:
		_focus.y = clampf(_focus.y, _world_rect.position.y - offset.position.y, _world_rect.end.y - offset.end.y)


func _on_viewport_resized() -> void:
	_compute_fit()
	_apply_view()
