class_name MeshBuilder
extends RefCounted

## Bakes several colored primitives into one ArrayMesh so each actor is a
## single draw call. Results are cached by key because towers and creeps of the
## same kind share geometry.

static var _cache: Dictionary = {}

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


static func cached(key: String) -> ArrayMesh:
	return _cache.get(key)


static func store(key: String, mesh: ArrayMesh) -> ArrayMesh:
	_cache[key] = mesh
	return mesh


## side_color, when opaque, is used for faces that do not point up.
func add(primitive: PrimitiveMesh, transform: Transform3D, color: Color, side_color := Color(0, 0, 0, 0)) -> MeshBuilder:
	var arrays := primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	var base := _vertices.size()
	var shade_sides := side_color.a > 0.0
	for index in range(vertices.size()):
		var normal := (normal_basis * normals[index]).normalized()
		_vertices.append(transform * vertices[index])
		_normals.append(normal)
		_colors.append(side_color if shade_sides and normal.y < 0.5 else color)
	for index in indices:
		_indices.append(base + index)
	return self


func add_box(size: Vector3, center: Vector3, color: Color, side_color := Color(0, 0, 0, 0)) -> MeshBuilder:
	var box := BoxMesh.new()
	box.size = size
	return add(box, Transform3D(Basis.IDENTITY, center), color, side_color)


func add_sphere(radius: float, center: Vector3, color: Color, segments := 10) -> MeshBuilder:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = maxi(3, segments / 2)
	return add(sphere, Transform3D(Basis.IDENTITY, center), color)


func add_cylinder(radius: float, height: float, center: Vector3, color: Color, segments := 12) -> MeshBuilder:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 0
	return add(cylinder, Transform3D(Basis.IDENTITY, center), color)


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material if material else MeshPalette.vertex_color_material())
	return mesh
