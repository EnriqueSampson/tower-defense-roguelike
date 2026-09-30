class_name Corpse
extends Node3D

## Presentation-only remains of a killed creep. The creep node is removed at
## once (so combat, snapshots and reconciliation never see it); its visual is
## handed here to play a `death` animation, or fall over when the model has
## none, then sink into the ground like a WC3 corpse and free itself.

const FALL_SECONDS := 0.35
const MAX_DEATH_ANIMATION_SECONDS := 1.2
const LINGER_SECONDS := 0.6
const SINK_SECONDS := 0.7

var _visual: Node3D
var _height := 0.5
var _age := 0.0
var _animated_seconds := 0.0
var _fall_axis := Vector3.RIGHT
var _start_basis := Basis.IDENTITY
var _start_y := 0.0


## Takes ownership of `visual` (already removed from the creep), keeping its
## world placement. `height` is how far it sinks.
func setup(visual: Node3D, world_transform: Transform3D, height: float) -> void:
	_visual = visual
	_height = maxf(height, 0.2)
	add_child(_visual)
	_visual.global_transform = world_transform
	_start_basis = _visual.basis
	_start_y = _visual.position.y
	ActorModel.set_tint(_visual, Color(0, 0, 0, 0))
	if ActorModel.play(_visual, &"death"):
		var player := ActorModel.animation_player(_visual)
		_animated_seconds = minf(player.current_animation_length, MAX_DEATH_ANIMATION_SECONDS)
	else:
		var player := ActorModel.animation_player(_visual)
		if player != null:
			player.stop()
		# Topple sideways relative to the creep's facing.
		_fall_axis = _visual.basis * Vector3.RIGHT


func _process(delta: float) -> void:
	if _visual == null:
		queue_free()
		return
	_age += delta
	var fall_end := _animated_seconds if _animated_seconds > 0.0 else FALL_SECONDS
	if _animated_seconds <= 0.0:
		var t := clampf(_age / FALL_SECONDS, 0.0, 1.0)
		_visual.basis = _start_basis.rotated(_fall_axis.normalized(), -deg_to_rad(80.0) * ease(t, 0.5))
	var sink_start := fall_end + LINGER_SECONDS
	if _age > sink_start:
		var s := clampf((_age - sink_start) / SINK_SECONDS, 0.0, 1.0)
		_visual.position.y = _start_y - _height * s
	if _age > sink_start + SINK_SECONDS:
		queue_free()

