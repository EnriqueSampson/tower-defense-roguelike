class_name ClassicWintermaulLayout
extends RefCounted

## Stylized Wintermaul battlefield. Authored on a 72x80 design grid and
## scaled by SCALE (2) to 144x160 cells = 72x80 two-by-two towers, close to
## classic Wintermaul's ~82x84-tower playable area (lanes ~15 towers wide and
## ~31 long versus ~10 and ~33 there). Design rects scale directly; design
## points map to the centre of their scaled block.
##
##   Top:    three hedge lanes (Positions 1, 2, 3) open to the sky.
##   Middle: side entrances (6 left, 4 right) and twin pockets owned by
##           Position 5, which spawns from both pockets.
##   Bottom: the "face" - two brow boxes (7 left, 8 right) above a mouth that
##           Position 9 spawns from through two spawners - then the exit.
## Every spawner of a position shares that position's creep budget.

enum Terrain {
	VOID,
	WALL,
	OPEN,
	SPAWN_PAD,
	EXIT_PAD,
}

const SCALE := 2
const _HALF := Vector2i(SCALE / 2, SCALE / 2)
const DESIGN_GRID_SIZE := Vector2i(72, 80)
const GRID_SIZE := DESIGN_GRID_SIZE * SCALE
const FINAL_GATE := Vector2i(35, 77) * SCALE + _HALF
## Shared relay every upstream position passes before the gate.
const FINAL_CHECKPOINT := Vector2i(35, 70) * SCALE + _HALF
const PLAYER_COUNT := 9
const SPATIAL_PLAYER_ORDER: Array[int] = [
	1, 2, 3,
	6, 5, 4,
	7, 9, 8,
]
const PLAYER_COLORS: Array[Color] = [
	Color("ef5753"),
	Color("4f75e6"),
	Color("36c9bd"),
	Color("a65bd4"),
	Color("e0cf45"),
	Color("e79243"),
	Color("42bd69"),
	Color("ed82b5"),
	Color("aab4b2"),
]
const WAVE_MULTIPLIERS: Array[float] = [2.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.6]

## Design-grid geometry (scaled at use). Ground enclosed by the outer hedge
## is x 10-61, y 0-73.
const DESIGN_INTERIOR := Rect2i(10, 0, 52, 74)
const DESIGN_WALLS: Array[Rect2i] = [
	Rect2i(8, 0, 2, 76),     # left outer hedge
	Rect2i(62, 0, 2, 76),    # right outer hedge
	Rect2i(8, 74, 56, 2),    # bottom hedge (exit pad carves the gap)
	Rect2i(25, 0, 2, 29),    # lane divider 1|2
	Rect2i(45, 0, 2, 29),    # lane divider 2|3
	Rect2i(10, 29, 5, 2),    # left shelf stub (lane 1 exits at x 15-19)
	Rect2i(58, 29, 4, 2),    # right shelf stub (lane 3 exits at x 53-57)
	Rect2i(20, 29, 14, 2),   # left pocket roof
	Rect2i(20, 31, 2, 11),   # left pocket outer leg
	Rect2i(32, 31, 2, 11),   # left pocket inner leg (lane 2 exits at x 34-38)
	Rect2i(39, 29, 14, 2),   # right pocket roof
	Rect2i(39, 31, 2, 11),   # right pocket inner leg
	Rect2i(51, 31, 2, 11),   # right pocket outer leg
	Rect2i(22, 45, 29, 2),   # brow
	Rect2i(35, 47, 2, 6),    # nose (splits the two brow boxes)
	Rect2i(22, 51, 29, 2),   # mouth ceiling
	Rect2i(17, 56, 39, 2),   # chin (mouth drains around both ends)
	Rect2i(25, 62, 2, 12),   # bottom stub left
	Rect2i(45, 62, 2, 12),   # bottom stub right
]
## Openings carved through walls that stay buildable.
const DESIGN_GAPS: Array[Rect2i] = [
	Rect2i(8, 34, 2, 6),     # left side entrance
	Rect2i(62, 34, 2, 6),    # right side entrance
]
const DESIGN_EXIT_PAD := Rect2i(33, 74, 6, 4)

static var _scaled_walls: Array[Rect2i] = []
static var _scaled_gaps: Array[Rect2i] = []


static func setup_map_coordinates() -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	for design in _design_positions():
		var pads: Array[Rect2i] = []
		for pad: Rect2i in design["spawn_pads"]:
			pads.append(scale_rect(pad))
		var spawns: Array[Vector2i] = []
		for spawn: Vector2i in design["spawns"]:
			spawns.append(scale_point(spawn))
		positions.append(_position(
			int(design["player_id"]), scale_rect(design["macro_bounds"]), pads, spawns,
			scale_point(design["checkpoint"]), scale_point(design["label_anchor"])))
	return positions


## Design rect -> grid rect.
static func scale_rect(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position * SCALE, rect.size * SCALE)


## Design cell -> centre cell of its scaled block.
static func scale_point(point: Vector2i) -> Vector2i:
	return point * SCALE + _HALF


static func _design_positions() -> Array[Dictionary]:
	return [
		_position(1, Rect2i(10, 0, 15, 31), [Rect2i(11, 0, 13, 7)], [Vector2i(17, 3)], Vector2i(17, 30), Vector2i(11, 8)),
		_position(2, Rect2i(27, 0, 18, 31), [Rect2i(28, 0, 16, 7)], [Vector2i(35, 3)], Vector2i(36, 30), Vector2i(28, 8)),
		_position(3, Rect2i(47, 0, 15, 31), [Rect2i(48, 0, 13, 7)], [Vector2i(54, 3)], Vector2i(55, 30), Vector2i(48, 8)),
		_position(4, Rect2i(53, 31, 19, 14), [Rect2i(64, 33, 7, 8)], [Vector2i(67, 36)], Vector2i(57, 44), Vector2i(54, 32)),
		_position(5, Rect2i(20, 31, 33, 14), [Rect2i(22, 31, 10, 7), Rect2i(41, 31, 10, 7)], [Vector2i(26, 34), Vector2i(45, 34)], Vector2i(36, 44), Vector2i(31, 43)),
		_position(6, Rect2i(0, 31, 20, 14), [Rect2i(1, 33, 7, 8)], [Vector2i(4, 36)], Vector2i(14, 44), Vector2i(10, 32)),
		_position(7, Rect2i(10, 45, 17, 29), [Rect2i(24, 47, 11, 4)], [Vector2i(29, 48)], Vector2i(13, 59), Vector2i(11, 46)),
		_position(8, Rect2i(47, 45, 15, 29), [Rect2i(37, 47, 12, 4)], [Vector2i(43, 48)], Vector2i(58, 59), Vector2i(51, 46)),
		_position(9, Rect2i(27, 45, 20, 33), [Rect2i(22, 53, 29, 3)], [Vector2i(30, 54), Vector2i(42, 54)], Vector2i(35, 70), Vector2i(28, 59)),
	]


static func get_position(position_index: int) -> Dictionary:
	var positions := setup_map_coordinates()
	return positions[position_index] if position_index >= 0 and position_index < positions.size() else {}


static func get_wave_multiplier(position_index: int) -> float:
	return WAVE_MULTIPLIERS[position_index] if position_index >= 0 and position_index < PLAYER_COUNT else 0.0


static func is_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


static func terrain_at(cell: Vector2i, positions: Array[Dictionary] = []) -> int:
	if not is_in_grid(cell):
		return Terrain.VOID
	if _scaled_walls.is_empty():
		for wall in DESIGN_WALLS:
			_scaled_walls.append(scale_rect(wall))
		for gap in DESIGN_GAPS:
			_scaled_gaps.append(scale_rect(gap))
	if scale_rect(DESIGN_EXIT_PAD).has_point(cell):
		return Terrain.EXIT_PAD
	var resolved_positions := positions if not positions.is_empty() else setup_map_coordinates()
	for position_data in resolved_positions:
		for pad: Rect2i in position_data["spawn_pads"]:
			if pad.has_point(cell):
				return Terrain.SPAWN_PAD
	for gap in _scaled_gaps:
		if gap.has_point(cell):
			return Terrain.OPEN
	for wall in _scaled_walls:
		if wall.has_point(cell):
			return Terrain.WALL
	return Terrain.OPEN if scale_rect(DESIGN_INTERIOR).has_point(cell) else Terrain.VOID


static func is_traversable(terrain: int) -> bool:
	return terrain in [Terrain.OPEN, Terrain.SPAWN_PAD, Terrain.EXIT_PAD]


## Index of the position whose territory contains the cell, or -1.
static func position_index_at(cell: Vector2i, positions: Array[Dictionary] = []) -> int:
	var resolved_positions := positions if not positions.is_empty() else setup_map_coordinates()
	for position_index in range(resolved_positions.size()):
		if (resolved_positions[position_index]["macro_bounds"] as Rect2i).has_point(cell):
			return position_index
	return -1


static func _position(
	player_id: int,
	macro_bounds: Rect2i,
	spawn_pads: Array[Rect2i],
	spawns: Array[Vector2i],
	checkpoint: Vector2i,
	label_anchor: Vector2i
) -> Dictionary:
	return {
		"player_id": player_id,
		"macro_bounds": macro_bounds,
		"spawn_pads": spawn_pads,
		"spawns": spawns,
		"spawn": spawns[0],
		"checkpoint": checkpoint,
		"label_anchor": label_anchor,
		"color": PLAYER_COLORS[player_id - 1],
		"wave_multiplier": WAVE_MULTIPLIERS[player_id - 1],
	}
