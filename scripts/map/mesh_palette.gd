class_name MeshPalette
extends RefCounted

## Shared, cached materials and meshes so hundreds of actors reuse a handful
## of GPU resources on the Compatibility renderer.

const RING_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(1.0);
uniform float inner = 0.9;
uniform float fill_alpha = 0.0;
uniform bool square = false;

void fragment() {
	vec2 offset = UV - vec2(0.5);
	float d = square ? max(abs(offset.x), abs(offset.y)) * 2.0 : length(offset) * 2.0;
	if (d > 1.0) {
		discard;
	}
	float ring = smoothstep(inner - 0.02, inner, d);
	ALBEDO = color.rgb;
	ALPHA = color.a * mix(fill_alpha, 1.0, ring);
}
"""

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _ring_shader: Shader


static func vertex_color_material() -> StandardMaterial3D:
	return tinted_vertex_material(Color.WHITE, 0.0)


## Vertex-colored lit material with an optional albedo tint and white emission.
static func tinted_vertex_material(tint: Color, emission_energy: float) -> StandardMaterial3D:
	var key := "vertex:%s:%.2f" % [tint.to_html(), emission_energy]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = tint
		material.roughness = 0.85
		if emission_energy > 0.0:
			material.emission_enabled = true
			material.emission = Color.WHITE
			material.emission_energy_multiplier = emission_energy
		_materials[key] = material
	return _materials[key]


static func solid_material(color: Color, unshaded := false, emission_energy := 0.0) -> StandardMaterial3D:
	var key := "solid:%s:%s:%.2f" % [color.to_html(), unshaded, emission_energy]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		if unshaded:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emission_energy > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission_energy
		_materials[key] = material
	return _materials[key]


static func ring_shader() -> Shader:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER_CODE
	return _ring_shader


## Unique ring material; callers mutate uniforms per instance.
static func new_ring_material(color: Color, inner := 0.9, fill_alpha := 0.0, square := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ring_shader()
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("inner", inner)
	material.set_shader_parameter("fill_alpha", fill_alpha)
	material.set_shader_parameter("square", square)
	return material


## Shared filled-disc material (used for blob shadows and pads).
static func disc_material(color: Color) -> ShaderMaterial:
	var key := "disc:%s" % color.to_html()
	if not _materials.has(key):
		_materials[key] = new_ring_material(color, 2.0, 1.0)
	return _materials[key]


## Flat 2x2 quad on XZ with UV 0..1; scale by radius to size it.
static func unit_quad() -> Mesh:
	if not _meshes.has("quad"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 2.0)
		_meshes["quad"] = plane
	return _meshes["quad"]


static func sphere_mesh(radius: float) -> Mesh:
	var key := "sphere:%.3f" % radius
	if not _meshes.has(key):
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 5
		_meshes[key] = sphere
	return _meshes[key]
