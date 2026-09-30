class_name ActorModel
extends RefCounted

## Helpers for authored models (.glb/.tscn) on towers and creeps. Models face
## +Z with their pivot on the ground; see the asset spec in docs/ROADMAP.md.

static var _tint_materials: Dictionary = {}


static func instantiate(scene: PackedScene) -> Node3D:
	if scene == null:
		return null
	var node := scene.instantiate()
	if node is Node3D:
		_enable_vertex_colors(node)
		return node
	node.free()
	push_warning("ActorModel: %s does not have a Node3D root" % scene.resource_path)
	return null


## Exported placeholders carry their colour in vertex colours (one draw call
## per part); Godot's glTF import does not switch that on, so enable it for
## any surface that has a colour array. Materials are shared, so this runs
## once per material.
static func _enable_vertex_colors(model: Node) -> void:
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and not material.vertex_color_use_as_albedo and mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				material.vertex_color_use_as_albedo = true


static func animation_player(model: Node) -> AnimationPlayer:
	if model == null:
		return null
	var players := model.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null


static func has_animation(model: Node, animation_name: StringName) -> bool:
	var player := animation_player(model)
	return player != null and player.has_animation(animation_name)


## Plays `animation_name` from the start if the model has it, then
## `then_loop` (looping) if given. Loop modes are set here so authored files
## need no import tweaks.
static func play(model: Node, animation_name: StringName, loop := false, then_loop: StringName = &"") -> bool:
	var player := animation_player(model)
	if player == null or not player.has_animation(animation_name):
		return false
	player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.stop()
	player.play(animation_name)
	if not then_loop.is_empty() and player.has_animation(then_loop):
		player.get_animation(then_loop).loop_mode = Animation.LOOP_LINEAR
		player.queue(then_loop)
	return true


## Top of the model's combined mesh bounds, in the model's local space.
static func height(model: Node3D) -> float:
	var top := 0.0
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (_relative_transform(model, mesh_instance) * mesh_instance.get_aabb()).end.y)
	return top


## Combined mesh bounds in the model's local space.
static func bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := _relative_transform(model, mesh_instance) * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Turns sun shadow casting on or off for every mesh in the model.
static func set_cast_shadows(model: Node, enabled: bool) -> void:
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.cast_shadow = setting


## Adds (or clears, with alpha 0) a flat tint over every mesh in the model.
static func set_tint(model: Node, color: Color) -> void:
	var material: StandardMaterial3D = null
	if color.a > 0.0:
		material = _tint_materials.get(color)
		if material == null:
			material = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = color
			_tint_materials[color] = material
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_overlay = material


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
