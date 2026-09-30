class_name Builder
extends Node3D

## Presentation of a player's builder. The host drives it straight from
## BuilderSystem every frame; clients walk it toward the replicated target at
## builder speed, glide onto the host position once it stops, and snap when
## drift grows past SNAP_DISTANCE.

## Used until the owner's race is known (and for races without a model).
const DEFAULT_MODEL := preload("res://assets/models/builders/human_peasant.glb")
const SNAP_DISTANCE := WintermaulMap.TILE_SIZE * 1.5
const SELECTION_COLOR := Color("5ce36b")

var owner_peer := 0
var speed_pixels := 224.0
var state := BuilderSystem.State.IDLE
var target := Vector2.ZERO

## Simulation position in sim pixels; the 3D transform is derived from it.
var plane_position: Vector2:
	get:
		return MapProjection.to_plane(position)
	set(value):
		position = MapProjection.to_3d(value)

var _model: Node3D
var _model_scene: PackedScene
var _animation := &""
var _authoritative := false
var _selection_circle: MeshInstance3D


func _ready() -> void:
	if _model == null:
		var scene := _model_scene
		_model_scene = null
		set_model_scene(scene)


## Swaps to the owner's race builder model (null keeps the default).
func set_model_scene(scene: PackedScene) -> void:
	var wanted := scene if scene != null else DEFAULT_MODEL
	if wanted == _model_scene:
		return
	_model_scene = wanted
	if not is_inside_tree():
		return
	var yaw := _model.rotation.y if _model != null else 0.0
	if _model != null:
		_model.queue_free()
	_model = ActorModel.instantiate(wanted)
	if _model != null:
		add_child(_model)
		_model.rotation.y = yaw
	_animation = &""
	_refresh_animation()


## Applies a BuilderSystem record. `authoritative` (host) places it exactly.
func apply_record(record: Dictionary, authoritative: bool) -> void:
	_authoritative = authoritative
	var authoritative_position := Vector2(float(record["x"]), float(record["y"]))
	target = Vector2(float(record["tx"]), float(record["ty"]))
	var previous_state := state
	state = int(record["state"])
	if authoritative or plane_position.distance_to(authoritative_position) > SNAP_DISTANCE:
		_face(authoritative_position - plane_position)
		plane_position = authoritative_position
	elif state != BuilderSystem.State.MOVING:
		# Extrapolation overshoots a build site (the host stops within reach of
		# it), so a stopped builder settles onto the host's position.
		target = authoritative_position
	if state != previous_state or _animation == &"":
		_refresh_animation()


## Plays the hammer swing when construction starts.
func play_build() -> void:
	_play(&"build", &"idle")


func set_selected(value: bool) -> void:
	if not value:
		if _selection_circle:
			_selection_circle.visible = false
		return
	if _selection_circle == null:
		_selection_circle = MeshInstance3D.new()
		_selection_circle.mesh = MeshPalette.unit_quad()
		_selection_circle.material_override = MeshPalette.new_ring_material(SELECTION_COLOR, 0.82, 0.12)
		_selection_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_selection_circle.position.y = 0.03
		_selection_circle.scale = Vector3(0.45, 1.0, 0.45)
		add_child(_selection_circle)
	_selection_circle.visible = true


func _process(delta: float) -> void:
	if _authoritative or plane_position.is_equal_approx(target):
		return
	var before := plane_position
	plane_position = before.move_toward(target, speed_pixels * delta)
	if state == BuilderSystem.State.MOVING:
		_face(plane_position - before)


func _refresh_animation() -> void:
	match state:
		BuilderSystem.State.MOVING:
			_play(&"walk", &"", true)
		BuilderSystem.State.STUNNED:
			_play(&"trip", &"idle")
		_:
			if _animation != &"build":
				_play(&"idle", &"", true)


func _play(animation: StringName, then_loop: StringName = &"", loop := false) -> void:
	_animation = animation
	if _model != null:
		ActorModel.play(_model, animation, loop, then_loop)


## Models face +Z; yaw toward the movement direction.
func _face(step: Vector2) -> void:
	if _model != null and step.length_squared() > 0.0001:
		_model.rotation.y = atan2(step.x, step.y)
