class_name BattlefieldCamera
extends Camera3D

## Fixed WC3-style perspective view of the battlefield. It never rotates;
## zooming dollies the camera along its tilt toward the cursor. Like WC3 it
## plays close: zoom 1.0 shows about 19 towers across (one position's maze),
## and the minimap, not the camera, gives the whole-map overview.

signal view_changed

## Close to Warcraft III's default camera (angle of attack 304°, i.e. 56° down).
const PITCH_DEGREES := 56.0
const FOV_DEGREES := 50.0
## WC3's default camera shows about 19 two-by-two towers across; the default
## dolly distance is solved from the viewport aspect so every window shape
## gets that width at the focus. FAR and CLOSE are multiples of it.
const DEFAULT_TOWERS_ACROSS := 19.0
const FAR_FACTOR := 1.8
const CLOSE_FACTOR := 0.18
## Screens per second of pan at any zoom.
const PAN_SCREENS_PER_SECOND := 0.9
const ZOOM_FACTOR := 1.2
const MIN_ZOOM := 1.0 / FAR_FACTOR
const DEFAULT_ZOOM := 1.0
const MAX_ZOOM := 1.0 / CLOSE_FACTOR

@export var edge_pan_enabled := true
## Edge panning only triggers this close to the window edge, as in WC3, so
## moving the mouse onto the console, top bar or multiboard never pans.
@export_range(1.0, 64.0, 1.0) var edge_border_thickness := 6.0

## 1.0 is the WC3 default distance; larger values zoom in.
var zoom_level := DEFAULT_ZOOM

var _dragging := false
var _map: WintermaulMap
var _edge_pan_area: Control
var _world_rect := Rect2()
## Sim-pixel point on the ground plane at the screen centre.
var _focus := Vector2.ZERO


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
	_focus = _world_rect.get_center()
	_apply_view()


## Centres the view on a sim-space point (clamped to the map).
func focus_on(plane: Vector2) -> void:
	_focus = plane
	_apply_view()


func get_focus() -> Vector2:
	return _focus


## `area` should cover the whole window (the game root), not just the
## battlefield: its edges are where the camera pans.
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
	# Arrow keys only, as in WC3: letter keys belong to the command card. They
	# move the caret instead while a text field (chat) has focus.
	if not get_tree().root.gui_get_focus_owner() is LineEdit:
		if Input.is_key_pressed(KEY_LEFT):
			direction.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			direction.x += 1.0
		if Input.is_key_pressed(KEY_UP):
			direction.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
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
		# Middle-drag pans; right-click belongs to builder orders, as in WC3.
		if event.button_index == MOUSE_BUTTON_MIDDLE:
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
	return get_default_distance() / zoom_level


## Dolly distance (units) at which the focus row spans DEFAULT_TOWERS_ACROSS.
func get_default_distance() -> float:
	var viewport_size := _viewport_size()
	var half_width := tan(deg_to_rad(FOV_DEGREES) * 0.5) * viewport_size.x / viewport_size.y
	return DEFAULT_TOWERS_ACROSS * 2.0 / (2.0 * half_width)


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


func _apply_view() -> void:
	var distance := _distance()
	_clamp_focus_to_world(distance)
	far = maxf(distance * 4.0, 50.0)
	position = MapProjection.to_3d(_focus) + _back_vector() * distance
	view_changed.emit()


## Keeps the clamp area (see _clamp_offset_rect) on the map; an axis that
## cannot fit (only on maps smaller than the view) centres horizontally or
## top-aligns vertically.
func _clamp_focus_to_world(distance: float) -> void:
	if _world_rect.size == Vector2.ZERO:
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
	_apply_view()
