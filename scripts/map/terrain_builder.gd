class_name TerrainBuilder
extends RefCounted

## Builds the frozen WC3-style battlefield presentation: rocky cliffs with
## snowy tops where the layout has walls, and snowy pines on cliff interiors.
## Presentation only; the simulation grid is unchanged.

const CLIFF_HEIGHT := 1.05
## Random extra height on cliff-top vertices, for an uneven rocky silhouette.
const CLIFF_TOP_JITTER := 0.5
## How far cliff faces bulge outward at mid-height, in tiles.
const CLIFF_BULGE := 0.18
const SNOW := Color("c3cfd7")
const SNOW_SHADE := Color("9eaebb")
const ROCK := Color("4b4f58")
const ROCK_DARK := Color("33363e")
const PINE := Color("27442f")
const PINE_SNOW := Color("dfe8ee")
const TRUNK := Color("4a3424")
const BOULDER := Color("6a6f78")
const ICE := Color("a8dcf0")

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## One flat-shaded mesh for every WALL cell: an uneven snowy top plus rock
## faces toward any non-wall neighbour.
static func build_cliffs(terrain_cells: Dictionary, grid_size: Vector2i, wall: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if int(terrain_cells.get(cell, -1)) != wall:
				continue
			var corners: Array[Vector3] = [
				_top_vertex(x, y), _top_vertex(x + 1, y), _top_vertex(x + 1, y + 1), _top_vertex(x, y + 1),
			]
			var snow := SNOW.lerp(SNOW_SHADE, _hash(x, y) * 0.6)
			_add_quad(vertices, colors, corners[0], corners[1], corners[2], corners[3], snow, Vector3.UP)
			for side in range(4):
				var neighbour := cell + DIRECTIONS[side]
				if int(terrain_cells.get(neighbour, wall)) == wall:
					continue
				_add_face(vertices, colors, corners[side], corners[(side + 1) % 4], DIRECTIONS[side], x + y * 7 + side)
	return _commit(vertices, colors)


## Instanced snowy pines on cliff cells whose four neighbours are also cliff,
## so trees never overhang a lane.
static func build_pines(terrain_cells: Dictionary, grid_size: Vector2i, wall: int) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if int(terrain_cells.get(cell, -1)) != wall or _hash(x * 3 + 11, y * 5 + 7) > 0.55:
				continue
			var interior := true
			for direction in DIRECTIONS:
				interior = interior and int(terrain_cells.get(cell + direction, wall)) == wall
			if not interior:
				continue
			var scale := 0.8 + _hash(x + 91, y + 17) * 0.5
			var offset := Vector2(_hash(x + 5, y + 3) - 0.5, _hash(x + 13, y + 29) - 0.5) * 0.4
			var height := minf(minf(_top_height(x, y), _top_height(x + 1, y)), minf(_top_height(x, y + 1), _top_height(x + 1, y + 1)))
			var basis := Basis(Vector3.UP, _hash(x + 41, y + 43) * TAU).scaled(Vector3.ONE * scale)
			transforms.append(Transform3D(basis, Vector3(x + 0.5 + offset.x, height, y + 0.5 + offset.y)))
	return _multimesh(_pine_mesh(), transforms)


## Snow-capped boulders on cliff edge cells (pines take the interiors).
static func build_boulders(terrain_cells: Dictionary, grid_size: Vector2i, wall: int) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if int(terrain_cells.get(cell, -1)) != wall or _hash(x * 7 + 3, y * 11 + 5) > 0.16:
				continue
			var edge := false
			for direction in DIRECTIONS:
				edge = edge or int(terrain_cells.get(cell + direction, wall)) != wall
			if not edge:
				continue
			var size := 0.22 + _hash(x + 23, y + 61) * 0.28
			var offset := Vector2(_hash(x + 2, y + 9) - 0.5, _hash(x + 17, y + 4) - 0.5) * 0.5
			var basis := Basis.from_euler(Vector3(_hash(x + 5, y) * 0.5, _hash(x, y + 5) * TAU, _hash(x + 9, y + 9) * 0.5))
			basis = basis.scaled(Vector3(size * 1.3, size * 0.8, size))
			transforms.append(Transform3D(basis, Vector3(x + 0.5 + offset.x, _top_height(x, y) + size * 0.25, y + 0.5 + offset.y)))
	return _multimesh(_boulder_mesh(), transforms)


## Rare clusters of ice shards on cliff interiors.
static func build_crystals(terrain_cells: Dictionary, grid_size: Vector2i, wall: int) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if int(terrain_cells.get(cell, -1)) != wall or _hash(x * 13 + 1, y * 3 + 17) > 0.035:
				continue
			var interior := true
			for direction in DIRECTIONS:
				interior = interior and int(terrain_cells.get(cell + direction, wall)) == wall
			if not interior:
				continue
			var scale := 0.7 + _hash(x + 31, y + 7) * 0.6
			var basis := Basis(Vector3.UP, _hash(x + 3, y + 37) * TAU).scaled(Vector3.ONE * scale)
			transforms.append(Transform3D(basis, Vector3(x + 0.5, _top_height(x, y), y + 0.5)))
	return _multimesh(_crystal_mesh(), transforms)


static func _multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	return multimesh


static func _boulder_mesh() -> ArrayMesh:
	var cached := MeshBuilder.cached("terrain:boulder")
	if cached:
		return cached
	var builder := MeshBuilder.new()
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 1.6
	rock.radial_segments = 6
	rock.rings = 3
	builder.add(rock, Transform3D.IDENTITY, SNOW_SHADE, BOULDER)
	return MeshBuilder.store("terrain:boulder", builder.commit(_terrain_material()))


static func _crystal_mesh() -> ArrayMesh:
	var cached := MeshBuilder.cached("terrain:crystal")
	if cached:
		return cached
	var builder := MeshBuilder.new()
	for shard in range(4):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07 + shard * 0.015
		cone.height = 0.55 + shard * 0.18
		cone.radial_segments = 5
		cone.rings = 0
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(12.0 + shard * 7.0)).rotated(Vector3.UP, shard * TAU / 4.0)
		var offset := Vector3(cos(shard * 1.7), 0.0, sin(shard * 1.7)) * 0.12
		builder.add(cone, Transform3D(tilt, offset + tilt * Vector3(0, cone.height * 0.5, 0)), ICE, ICE.darkened(0.25))
	return MeshBuilder.store("terrain:crystal", builder.commit(_terrain_material()))


static func _pine_mesh() -> ArrayMesh:
	var cached := MeshBuilder.cached("terrain:pine")
	if cached:
		return cached
	var builder := MeshBuilder.new()
	builder.add_cylinder(0.05, 0.35, Vector3(0, 0.17, 0), TRUNK, 6)
	# Tall, narrow Northrend pine: four stacked cones, snow on the upper tiers.
	for tier in range(4):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.34 - tier * 0.065
		cone.height = 0.62 - tier * 0.06
		cone.radial_segments = 7
		cone.rings = 0
		var color := PINE.lerp(PINE_SNOW, 0.15 * tier)
		builder.add(cone, Transform3D(Basis.IDENTITY, Vector3(0, 0.55 + tier * 0.34, 0)), color, PINE.darkened(0.3))
	return MeshBuilder.store("terrain:pine", builder.commit(_terrain_material()))


static func _add_face(vertices: PackedVector3Array, colors: PackedColorArray, top_a: Vector3, top_b: Vector3, direction: Vector2i, variant: int) -> void:
	var outward := Vector3(direction.x, 0.0, direction.y)
	var bottom_a := Vector3(top_a.x, 0.0, top_a.z)
	var bottom_b := Vector3(top_b.x, 0.0, top_b.z)
	var mid_a := (top_a + bottom_a) * 0.5 + outward * CLIFF_BULGE * (0.6 + _hash(variant, 1) * 0.8)
	var mid_b := (top_b + bottom_b) * 0.5 + outward * CLIFF_BULGE * (0.6 + _hash(variant, 2) * 0.8)
	var rock := ROCK.lerp(ROCK_DARK, _hash(variant, 3))
	# Upper band catches a little snow; lower band is bare rock.
	_add_quad(vertices, colors, top_a, top_b, mid_b, mid_a, rock.lerp(SNOW_SHADE, 0.18), outward + Vector3.UP * 0.3)
	_add_quad(vertices, colors, mid_a, mid_b, bottom_b, bottom_a, rock.darkened(0.12), outward - Vector3.UP * 0.3)


## Adds two flat-shaded triangles a-b-c, a-c-d facing `outward`. Godot treats
## a triangle as front-facing when cross(b - a, c - a) points away from the
## viewer, so each triangle is flipped until its cross product points inward.
static func _add_quad(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	for triangle: Array[Vector3] in [[a, b, c] as Array[Vector3], [a, c, d] as Array[Vector3]]:
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(outward) > 0.0:
			triangle.reverse()
		vertices.append_array(PackedVector3Array(triangle))
		for _index in range(3):
			colors.append(color)


static func _commit(vertices: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(0, vertices.size(), 3):
		# Front faces wind so the cross product points inward; the normal is its opposite.
		var normal := -(vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		normals[index] = normal
		normals[index + 1] = normal
		normals[index + 2] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _terrain_material())
	return mesh


## Lit vertex colours authored as sRGB (Godot assumes linear by default,
## which would wash the snow out to white).
static func _terrain_material() -> StandardMaterial3D:
	var material := MeshPalette.vertex_color_material().duplicate() as StandardMaterial3D
	material.vertex_color_is_srgb = true
	return material


static func _top_vertex(vx: int, vy: int) -> Vector3:
	return Vector3(vx, _top_height(vx, vy), vy)


## Cliff-top height at a grid vertex; shared by neighbouring cells so the
## top surface has no cracks.
static func _top_height(vx: int, vy: int) -> float:
	return CLIFF_HEIGHT + _hash(vx, vy) * CLIFF_TOP_JITTER


## Deterministic 0..1 hash of two integers (shared with the ground bake).
static func hash_2d(a: int, b: int) -> float:
	return _hash(a, b)


static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0
