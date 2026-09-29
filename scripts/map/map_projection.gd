class_name MapProjection
extends RefCounted

## Bridges the orthogonal 2D simulation ("sim pixels", one tile = TILE_SIZE)
## to the 3D presentation where one tile is one unit on the XZ ground plane.

const TILE_SIZE := 28.0
const UNITS_PER_PIXEL := 1.0 / TILE_SIZE


static func to_3d(plane: Vector2, height := 0.0) -> Vector3:
	return Vector3(plane.x * UNITS_PER_PIXEL, height, plane.y * UNITS_PER_PIXEL)


static func to_plane(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) * TILE_SIZE


static func units(pixels: float) -> float:
	return pixels * UNITS_PER_PIXEL
